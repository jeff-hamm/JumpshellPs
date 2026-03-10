[CmdletBinding()]
param(
  [ValidateSet('workspace', 'profile', 'global')]
  [string]$Scope = 'profile',

  [ValidateSet('default', 'low', 'medium', 'high', 'xhigh')]
  [string]$Effort,

  [Alias('h')]
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
  Write-Output 'Usage: pwsh ./run.ps1 [-Scope workspace|profile|global] [-Effort default|low|medium|high|xhigh]'
  Write-Output ''
  Write-Output '- If -Effort is omitted, toggles between default and xhigh.'
  Write-Output '- workspace scope targets: <cwd>/.vscode/settings.json'
  Write-Output '- profile/global scope targets: <resolved-profile>/settings.json'
}

function ConvertFrom-JsonCText {
  param([string]$Text)

  $builder = [System.Text.StringBuilder]::new()
  $inString = $false
  $escaped = $false
  $inLineComment = $false
  $inBlockComment = $false

  for ($index = 0; $index -lt $Text.Length; $index++) {
    $ch = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

    if ($inLineComment) {
      if ($ch -eq "`r" -or $ch -eq "`n") {
        $inLineComment = $false
        [void]$builder.Append($ch)
      }
      continue
    }

    if ($inBlockComment) {
      if ($ch -eq '*' -and $next -eq '/') {
        $inBlockComment = $false
        $index++
      }
      continue
    }

    if ($inString) {
      [void]$builder.Append($ch)
      if ($escaped) {
        $escaped = $false
      }
      elseif ($ch -eq '\\') {
        $escaped = $true
      }
      elseif ($ch -eq '"') {
        $inString = $false
      }
      continue
    }

    if ($ch -eq '"') {
      $inString = $true
      [void]$builder.Append($ch)
      continue
    }

    if ($ch -eq '/' -and $next -eq '/') {
      $inLineComment = $true
      $index++
      continue
    }

    if ($ch -eq '/' -and $next -eq '*') {
      $inBlockComment = $true
      $index++
      continue
    }

    [void]$builder.Append($ch)
  }

  $cleaned = $builder.ToString()
  do {
    $nextCleaned = [regex]::Replace($cleaned, ',(\s*[}\]])', '$1')
    $changed = $nextCleaned -ne $cleaned
    $cleaned = $nextCleaned
  } while ($changed)

  if ([string]::IsNullOrWhiteSpace($cleaned)) {
    return '{}'
  }

  return $cleaned
}

if ($Help) {
  Show-Usage
  exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Scope -eq 'workspace') {
  $targetDir = Join-Path (Get-Location) '.vscode'
}
else {
  $resolver = Join-Path $scriptDir 'resolve-vscode-profile.ps1'
  if (-not (Test-Path -LiteralPath $resolver)) {
    throw "Resolver script not found: $resolver"
  }

  $targetDir = (& $resolver | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($targetDir)) {
    throw 'Failed to resolve profile directory.'
  }
}

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
$targetFile = Join-Path $targetDir 'settings.json'

if (-not (Test-Path -LiteralPath $targetFile)) {
  Set-Content -LiteralPath $targetFile -Value "{}" -Encoding utf8
}

$raw = Get-Content -LiteralPath $targetFile -Raw -Encoding utf8
if ([string]::IsNullOrWhiteSpace($raw)) {
  $raw = '{}'
}

$cleaned = ConvertFrom-JsonCText -Text $raw

try {
  $parsed = $cleaned | ConvertFrom-Json -AsHashtable
}
catch {
  throw "Failed to parse JSON from ${targetFile}: $($_.Exception.Message)"
}

if ($null -eq $parsed) {
  $parsed = @{}
}

if (-not ($parsed -is [System.Collections.IDictionary])) {
  throw "Expected top-level JSON object in $targetFile"
}

$key = 'github.copilot.chat.responsesApiReasoningEffort'
$current = if ($parsed.Contains($key)) { [string]$parsed[$key] } else { $null }

if ([string]::IsNullOrWhiteSpace($Effort)) {
  if ($current -eq 'xhigh') {
    $newValue = 'default'
  }
  else {
    $newValue = 'xhigh'
  }
}
else {
  $newValue = $Effort
}

$wasSame = $parsed.Contains($key) -and ([string]$parsed[$key] -eq $newValue)
$parsed[$key] = $newValue

$json = $parsed | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $targetFile -Value ($json.TrimEnd() + "`n") -Encoding utf8

Write-Output "Updated: $targetFile"
Write-Output "github.copilot.chat.responsesApiReasoningEffort=$newValue"
if ($wasSame) {
  Write-Output 'status=unchanged'
}
else {
  Write-Output 'status=changed'
}
