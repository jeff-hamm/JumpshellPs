$ErrorActionPreference = "Stop"

function Get-Usage {
  @"
Usage:
  ./patch-json.ps1 --type <setting|task|mcp|keybinding> --action <add|edit|remove> [--path <json.path>] [--value <json>] [--match <json>] [--file <path>] [--workspace] [--dry-run]

Purpose:
  Safely patch VS Code/Cursor JSON config files after intent parsing.

Options:
  --type       Target JSON file type: setting, task, mcp, keybinding.
  --action     Patch operation: add, edit, remove.
  --path       Dot path for object targets (example: editor.tabSize). Use '$' for root.
               Ignored for keybinding mode.
  --value      JSON value used by add/edit operations.
  --match      JSON matcher used by keybinding edit/remove (optional for add).
  --file       Explicit file path. If omitted, resolve-editor is used.
  --workspace  Resolve workspace-scoped file when --file is not provided.
  --dry-run    Do not write file; return planned change summary.
"@
}

function ConvertFrom-JsonInput {
  param(
    [string]$JsonText,
    [string]$FieldName
  )

  if ([string]::IsNullOrWhiteSpace($JsonText)) {
    throw "Missing JSON input for $FieldName"
  }

  try {
    return ($JsonText | ConvertFrom-Json -AsHashtable -Depth 100)
  }
  catch {
    throw ('Invalid JSON for {0}: {1}' -f $FieldName, $_.Exception.Message)
  }
}

function ConvertTo-CompactJson {
  param([object]$Value)

  try {
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
  }
  catch {
    return [string]$Value
  }
}

function Test-ValuesEqual {
  param(
    [object]$A,
    [object]$B
  )

  return (ConvertTo-CompactJson -Value $A) -eq (ConvertTo-CompactJson -Value $B)
}

function Split-JsonPath {
  param([string]$PathText)

  if ([string]::IsNullOrWhiteSpace($PathText) -or $PathText -eq '$') {
    return @()
  }

  $normalized = $PathText
  if ($normalized.StartsWith('$.')) {
    $normalized = $normalized.Substring(2)
  }
  elseif ($normalized.StartsWith('$')) {
    $normalized = $normalized.Substring(1)
  }

  $parts = @($normalized -split '\.')
  $parts = @($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  return $parts
}

function Get-DictionaryRoot {
  param([object]$Root)

  if ($null -eq $Root) { return @{} }
  if ($Root -is [System.Collections.IDictionary]) { return $Root }
  throw 'Expected a JSON object as root.'
}

function Get-ArrayRoot {
  param([object]$Root)

  if ($null -eq $Root) {
    return [System.Collections.ArrayList]::new()
  }

  if ($Root -is [System.Collections.IList]) {
    $list = [System.Collections.ArrayList]::new()
    foreach ($item in $Root) {
      [void]$list.Add($item)
    }
    return $list
  }

  throw 'Expected a JSON array as root for keybinding type.'
}

function Get-PathState {
  param(
    [System.Collections.IDictionary]$Root,
    [string[]]$Segments
  )

  if ($Segments.Count -eq 0) {
    return [pscustomobject]@{
      Exists = $true
      Parent = $null
      Leaf = $null
      Value = $Root
    }
  }

  $cursor = $Root
  for ($i = 0; $i -lt ($Segments.Count - 1); $i++) {
    $part = $Segments[$i]
    if (-not $cursor.Contains($part)) {
      return [pscustomobject]@{
        Exists = $false
        Parent = $null
        Leaf = $null
        Value = $null
      }
    }

    $next = $cursor[$part]
    if (-not ($next -is [System.Collections.IDictionary])) {
      return [pscustomobject]@{
        Exists = $false
        Parent = $null
        Leaf = $null
        Value = $null
      }
    }

    $cursor = $next
  }

  $leaf = $Segments[$Segments.Count - 1]
  if ($cursor.Contains($leaf)) {
    return [pscustomobject]@{
      Exists = $true
      Parent = $cursor
      Leaf = $leaf
      Value = $cursor[$leaf]
    }
  }

  return [pscustomobject]@{
    Exists = $false
    Parent = $cursor
    Leaf = $leaf
    Value = $null
  }
}

function Get-PathParent {
  param(
    [System.Collections.IDictionary]$Root,
    [string[]]$Segments
  )

  if ($Segments.Count -eq 0) {
    return [pscustomobject]@{ Parent = $null; Leaf = $null }
  }

  $cursor = $Root
  for ($i = 0; $i -lt ($Segments.Count - 1); $i++) {
    $part = $Segments[$i]
    if (-not $cursor.Contains($part)) {
      $cursor[$part] = @{}
    }

    $next = $cursor[$part]
    if (-not ($next -is [System.Collections.IDictionary])) {
      throw "Cannot create nested key under non-object path segment '$part'"
    }

    $cursor = $next
  }

  return [pscustomobject]@{
    Parent = $cursor
    Leaf = $Segments[$Segments.Count - 1]
  }
}

function Get-KeybindingMatcher {
  param(
    [object]$ValueObject,
    [object]$MatchObject
  )

  if ($null -ne $MatchObject) {
    return $MatchObject
  }

  if ($null -eq $ValueObject) {
    return $null
  }

  if ($ValueObject -is [System.Collections.IDictionary]) {
    if ($ValueObject.Contains('key') -and $ValueObject.Contains('command')) {
      return @{ key = $ValueObject['key']; command = $ValueObject['command'] }
    }

    if ($ValueObject.Contains('command')) {
      return @{ command = $ValueObject['command'] }
    }
  }

  return $ValueObject
}

function Test-KeybindingMatch {
  param(
    [object]$Item,
    [object]$Matcher
  )

  if ($Matcher -is [System.Collections.IDictionary]) {
    if (-not ($Item -is [System.Collections.IDictionary])) { return $false }

    foreach ($entry in $Matcher.GetEnumerator()) {
      if (-not $Item.Contains($entry.Key)) { return $false }
      if (-not (Test-ValuesEqual -A $Item[$entry.Key] -B $entry.Value)) { return $false }
    }

    return $true
  }

  return (Test-ValuesEqual -A $Item -B $Matcher)
}

$validTypes = @('setting', 'task', 'mcp', 'keybinding')
$validActions = @('add', 'edit', 'remove')

$type = $null
$action = $null
$path = $null
$valueJson = $null
$matchJson = $null
$filePath = $null
$workspace = $false
$dryRun = $false

$i = 0
while ($i -lt $args.Count) {
  $arg = $args[$i]

  switch -Regex ($arg) {
    '^--type$' {
      $i++
      if ($i -ge $args.Count) { throw '--type requires a value' }
      $type = $args[$i].ToLower()
      break
    }
    '^--action$' {
      $i++
      if ($i -ge $args.Count) { throw '--action requires a value' }
      $action = $args[$i].ToLower()
      break
    }
    '^--path$' {
      $i++
      if ($i -ge $args.Count) { throw '--path requires a value' }
      $path = $args[$i]
      break
    }
    '^--value$' {
      $i++
      if ($i -ge $args.Count) { throw '--value requires JSON text' }
      $valueJson = $args[$i]
      break
    }
    '^--match$' {
      $i++
      if ($i -ge $args.Count) { throw '--match requires JSON text' }
      $matchJson = $args[$i]
      break
    }
    '^--file$' {
      $i++
      if ($i -ge $args.Count) { throw '--file requires a path' }
      $filePath = $args[$i]
      break
    }
    '^--workspace$' {
      $workspace = $true
      break
    }
    '^--dry-run$' {
      $dryRun = $true
      break
    }
    '^--help$|^-h$' {
      Write-Output (Get-Usage).TrimEnd()
      exit 0
    }
    default {
      throw "Unknown argument: $arg"
    }
  }

  $i++
}

if ([string]::IsNullOrWhiteSpace($type) -or [string]::IsNullOrWhiteSpace($action)) {
  throw "--type and --action are required.`n$(Get-Usage)"
}

if ($validTypes -notcontains $type) {
  throw "Unknown --type '$type'. Valid: $($validTypes -join ', ')"
}

if ($validActions -notcontains $action) {
  throw "Unknown --action '$action'. Valid: $($validActions -join ', ')"
}

if ([string]::IsNullOrWhiteSpace($filePath)) {
  $resolveScript = Join-Path $PSScriptRoot 'resolve-editor.ps1'
  if (-not (Test-Path -LiteralPath $resolveScript)) {
    throw "resolve-editor.ps1 not found next to patch-json script: $resolveScript"
  }

  $resolveArgs = @('--settings', $type)
  if ($workspace) { $resolveArgs += '--workspace' }

  $resolved = & $resolveScript @resolveArgs
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$resolved)) {
    throw 'Failed to resolve target settings file path.'
  }

  $filePath = ([string]$resolved).Trim()
}

$absPath = [System.IO.Path]::GetFullPath($filePath)
$parentDir = Split-Path -Parent $absPath
if (-not (Test-Path -LiteralPath $parentDir)) {
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

$defaultRoot = if ($type -eq 'keybinding') { [System.Collections.ArrayList]::new() } else { @{} }

$existing = $null
if (Test-Path -LiteralPath $absPath) {
  $raw = Get-Content -LiteralPath $absPath -Raw
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
      $existing = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
      throw "Target file is not valid JSON: $absPath"
    }
  }
}

if ($null -eq $existing) {
  $existing = $defaultRoot
}

$changed = $false
$valueObject = $null
$matchObject = $null

if (-not [string]::IsNullOrWhiteSpace($valueJson)) {
  $valueObject = ConvertFrom-JsonInput -JsonText $valueJson -FieldName '--value'
}
if (-not [string]::IsNullOrWhiteSpace($matchJson)) {
  $matchObject = ConvertFrom-JsonInput -JsonText $matchJson -FieldName '--match'
}

if ($type -eq 'keybinding') {
  $doc = Get-ArrayRoot -Root $existing

  if (($action -eq 'add' -or $action -eq 'edit') -and $null -eq $valueObject) {
    throw "--value is required for keybinding $action"
  }

  $matcher = Get-KeybindingMatcher -ValueObject $valueObject -MatchObject $matchObject
  if (($action -eq 'edit' -or $action -eq 'remove') -and $null -eq $matcher) {
    throw "--match or a matchable --value is required for keybinding $action"
  }

  $indexes = New-Object System.Collections.Generic.List[int]
  for ($idx = 0; $idx -lt $doc.Count; $idx++) {
    if (Test-KeybindingMatch -Item $doc[$idx] -Matcher $matcher) {
      [void]$indexes.Add($idx)
    }
  }

  if ($action -eq 'add') {
    if ($indexes.Count -eq 0) {
      [void]$doc.Add($valueObject)
      $changed = $true
    }
  }
  elseif ($action -eq 'edit') {
    if ($indexes.Count -gt 0) {
      $first = $indexes[0]
      if (-not (Test-ValuesEqual -A $doc[$first] -B $valueObject)) {
        $doc[$first] = $valueObject
        $changed = $true
      }
    }
    else {
      [void]$doc.Add($valueObject)
      $changed = $true
    }
  }
  elseif ($action -eq 'remove') {
    if ($indexes.Count -gt 0) {
      $descending = @($indexes | Sort-Object -Descending)
      foreach ($index in $descending) {
        $doc.RemoveAt($index)
      }
      $changed = $true
    }
  }

  $existing = $doc
}
else {
  $doc = Get-DictionaryRoot -Root $existing
  $segments = Split-JsonPath -PathText $path

  if ($segments.Count -eq 0) {
    throw "--path is required for type '$type' (for example: editor.tabSize)"
  }

  if (($action -eq 'add' -or $action -eq 'edit') -and $null -eq $valueObject) {
    throw "--value is required for $action"
  }

  $state = Get-PathState -Root $doc -Segments $segments

  if ($action -eq 'add') {
    if (-not $state.Exists) {
      $target = Get-PathParent -Root $doc -Segments $segments
      $target.Parent[$target.Leaf] = $valueObject
      $changed = $true
    }
  }
  elseif ($action -eq 'edit') {
    $target = Get-PathParent -Root $doc -Segments $segments
    $current = $null
    $hasCurrent = $target.Parent.Contains($target.Leaf)
    if ($hasCurrent) { $current = $target.Parent[$target.Leaf] }

    if (-not $hasCurrent -or -not (Test-ValuesEqual -A $current -B $valueObject)) {
      $target.Parent[$target.Leaf] = $valueObject
      $changed = $true
    }
  }
  elseif ($action -eq 'remove') {
    if ($state.Exists) {
      [void]$state.Parent.Remove($state.Leaf)
      $changed = $true
    }
  }

  $existing = $doc
}

if ($changed -and -not $dryRun) {
  $jsonOutput = ($existing | ConvertTo-Json -Depth 100)
  Set-Content -LiteralPath $absPath -Value $jsonOutput -Encoding UTF8
}

[pscustomobject]@{
  status  = 'ok'
  changed = $changed
  dryRun  = $dryRun
  file    = $absPath
  type    = $type
  action  = $action
  path    = $path
} | ConvertTo-Json -Depth 5 -Compress
