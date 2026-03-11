$ErrorActionPreference = "Stop"

function Get-VsEditorUsage {
  @"
Usage:
  ./Resolve-VsEditor.ps1 [--name|--profile|--user|--rules|--skills|--settings [type]|--workspace] [--workspace] [--git-commit]

Modes:
  --name                  Return editor name (default)
  --profile               Return current editor profile (User config) path
  --user                  Return current editor preferred user path
  --rules                 Return user rules/instructions path; add --workspace for workspace-scoped path
  --skills                Return user skills path; add --workspace for workspace-scoped path
  --settings [type]       Return settings dir (default) or a specific file: setting|task|mcp|keybinding
                          e.g. --settings task  ->  .../tasks.json
  --workspace             Workspace-level .agents/.cursor/.claude path (standalone or scope modifier)

Flags:
  --git-commit            After resolving path, also run change-control before-phase (backup + git status).
                          No-op when resolved path is not an existing file.
  --relative              When combined with a --workspace path, return only the workspace-relative portion (e.g. .agents/instructions).
"@
}

function Resolve-VsEditorViaModule {
  param([string]$Flag)

  $modeMap = @{
    '--name'      = 'Name'
    '--profile'   = 'Profile'
    '--user'      = 'User'
    '--rules'     = 'Rules'
    '--workspace' = 'Workspace'
  }

  if (-not $modeMap.ContainsKey($Flag)) {
    return $null
  }

  $command = Get-Command -Name 'Resolve-EditorPath' -ErrorAction SilentlyContinue
  if (-not $command) {
    try {
      Import-Module Jumpshell -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
      $command = Get-Command -Name 'Resolve-EditorPath' -ErrorAction SilentlyContinue
    }
    catch {
      $command = $null
    }
  }

  if (-not $command) {
    return $null
  }

  try {
    $editor = & $command.Name -Mode 'Name'
    if ([string]::IsNullOrWhiteSpace([string]$editor)) {
      return $null
    }

    $scopePath = if ($Flag -eq '--name') {
      ''
    }
    else {
      & $command.Name -Mode $modeMap[$Flag]
    }

    if ($Flag -ne '--name' -and [string]::IsNullOrWhiteSpace([string]$scopePath)) {
      return $null
    }

    return [PSCustomObject]@{
      Editor    = [string]$editor
      ScopePath = [string]$scopePath
    }
  }
  catch {
    return $null
  }

  return $null
}

function Export-VsEditorScopeContext {
  param(
    [string]$Editor,
    [string]$ScopePath
  )

  $resolvedEditor    = [string]$Editor
  $resolvedScopePath = if ($null -eq $ScopePath) { '' } else { [string]$ScopePath }

  Set-Variable -Name 'EDITOR'     -Scope Script -Value $resolvedEditor    -Force
  Set-Variable -Name 'SCOPE_PATH' -Scope Script -Value $resolvedScopePath -Force

  $Env:EDITOR     = $resolvedEditor
  $Env:SCOPE_PATH = $resolvedScopePath
}

function Write-VsEditorPathTuple {
  param(
    [string]$Editor,
    [string]$ScopePath
  )

  $tuple = @([string]$Editor, [string]$ScopePath)
  Write-Output ($tuple | ConvertTo-Json -Compress)
}

function Select-VsFirstExistingPath {
  param([string[]]$Candidates)

  foreach ($candidate in $Candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  return ($Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function Get-VsEditorHintText {
  $hints = @(
    $Env:VSCODE_IPC_HOOK,
    $Env:VSCODE_GIT_ASKPASS_MAIN,
    $Env:TERM_PROGRAM,
    $Env:TERM_PROGRAM_VERSION,
    $Env:WINDSURF_IPC_HOOK,
    $Env:CURSOR_TRACE_DIR,
    $Env:CLAUDECODE,
    $Env:CLAUDE_CONFIG_DIR
  )

  if ($Env:VSCODE_PID -and ($Env:VSCODE_PID -as [int])) {
    try {
      $hostProcess = Get-Process -Id ([int]$Env:VSCODE_PID) -ErrorAction Stop
      $hints += $hostProcess.ProcessName
      if ($hostProcess.Path) {
        $hints += $hostProcess.Path
      }
    }
    catch {
      # Ignore process lookup errors.
    }
  }

  return ($hints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
}

function Get-VsEditorOrder {
  $hintText = Get-VsEditorHintText

  if ($hintText -match 'windsurf') {
    return @('Windsurf', 'Code', 'Code - Insiders', 'Cursor', 'VSCodium', 'Claude')
  }

  if ($hintText -match 'Code - Insiders|code-insiders') {
    return @('Code - Insiders', 'Code', 'Cursor', 'Windsurf', 'VSCodium', 'Claude')
  }

  if ($hintText -match '[Cc]ursor') {
    return @('Cursor', 'Code', 'Code - Insiders', 'Windsurf', 'VSCodium', 'Claude')
  }

  if ($hintText -match '[Vv][Ss][Cc]odium|[Cc]odium') {
    return @('VSCodium', 'Code', 'Code - Insiders', 'Cursor', 'Windsurf', 'Claude')
  }

  if ($hintText -match '[Cc]laude') {
    return @('Claude', 'Code', 'Code - Insiders', 'Cursor', 'Windsurf', 'VSCodium')
  }

  return @('Code', 'Code - Insiders', 'Cursor', 'Windsurf', 'VSCodium', 'Claude')
}

function Get-VsEditorProfileCandidates {
  param([string]$Editor)

  if ($IsWindows) {
    $appData = if ($Env:APPDATA) { $Env:APPDATA } else { $Env:AppData }
    if (-not $appData) { return @() }

    switch ($Editor) {
      'Code'            { return @(Join-Path $appData 'Code\User') }
      'Code - Insiders' { return @(Join-Path $appData 'Code - Insiders\User') }
      'Cursor'          { return @(Join-Path $appData 'Cursor\User') }
      'Windsurf'        { return @(Join-Path $appData 'Windsurf\User') }
      'VSCodium'        { return @(Join-Path $appData 'VSCodium\User') }
      'Claude'          { return @((Join-Path $appData 'Claude\User'), (Join-Path $appData 'Claude')) }
      default           { return @() }
    }
  }

  if ($IsMacOS) {
    switch ($Editor) {
      'Code'            { return @("$HOME/Library/Application Support/Code/User") }
      'Code - Insiders' { return @("$HOME/Library/Application Support/Code - Insiders/User") }
      'Cursor'          { return @("$HOME/Library/Application Support/Cursor/User") }
      'Windsurf'        { return @("$HOME/Library/Application Support/Windsurf/User") }
      'VSCodium'        { return @("$HOME/Library/Application Support/VSCodium/User") }
      'Claude'          { return @("$HOME/Library/Application Support/Claude/User", "$HOME/Library/Application Support/Claude") }
      default           { return @() }
    }
  }

  switch ($Editor) {
    'Code'            { return @("$HOME/.config/Code/User") }
    'Code - Insiders' { return @("$HOME/.config/Code - Insiders/User") }
    'Cursor'          { return @("$HOME/.config/Cursor/User") }
    'Windsurf'        { return @("$HOME/.config/Windsurf/User") }
    'VSCodium'        { return @("$HOME/.config/VSCodium/User") }
    'Claude'          { return @("$HOME/.config/Claude/User", "$HOME/.config/Claude") }
    default           { return @() }
  }
}

function Resolve-VsEditorName {
  $ordered = Get-VsEditorOrder

  foreach ($editor in $ordered) {
    $candidates = Get-VsEditorProfileCandidates -Editor $editor
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate) {
        return $editor
      }
    }
  }

  return $ordered[0]
}

function Resolve-VsEditorProfilePath {
  $editor     = Resolve-VsEditorName
  $candidates = Get-VsEditorProfileCandidates -Editor $editor
  return (Select-VsFirstExistingPath -Candidates $candidates)
}

function Resolve-VsEditorUserPath {
  $editor = Resolve-VsEditorName

  if ($editor -eq 'Cursor') { return (Join-Path $HOME '.cursor') }
  if ($editor -eq 'Claude') { return (Join-Path $HOME '.claude') }

  return (Join-Path $HOME '.agents')
}

function Resolve-VsEditorRulesPath {
  $editor   = Resolve-VsEditorName
  $userPath = Resolve-VsEditorUserPath

  if ($editor -eq 'Cursor') { return (Join-Path $userPath 'rules') }

  if ($editor -eq 'Claude') {
    return (Select-VsFirstExistingPath -Candidates @(
      (Join-Path $userPath 'commands'),
      (Join-Path $userPath 'rules'),
      $userPath
    ))
  }

  return (Join-Path $userPath 'instructions')
}

function Resolve-VsWorkspaceRoot {
  $start = (Get-Location).Path

  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($null -ne $git) {
    try {
      $gitRoot = (& git -C $start rev-parse --show-toplevel 2>$null)
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $resolvedGitRoot = $gitRoot.Trim()
        if (Test-Path -LiteralPath $resolvedGitRoot) {
          return $resolvedGitRoot
        }
      }
    }
    catch {
      # Ignore git lookup errors.
    }
  }

  $current = $start
  while (-not [string]::IsNullOrWhiteSpace($current)) {
    $hasWorkspaceFile = @(Get-ChildItem -LiteralPath $current -File -Filter '*.code-workspace' -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0
    $hasMarker =
      (Test-Path -LiteralPath (Join-Path $current '.git'))    -or
      (Test-Path -LiteralPath (Join-Path $current '.vscode')) -or
      (Test-Path -LiteralPath (Join-Path $current '.cursor')) -or
      (Test-Path -LiteralPath (Join-Path $current '.agents')) -or
      (Test-Path -LiteralPath (Join-Path $current '.claude')) -or
      $hasWorkspaceFile

    if ($hasMarker) { return $current }

    $parent = Split-Path -Path $current -Parent
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }

    $current = $parent
  }

  return $start
}

function Resolve-VsWorkspacePath {
  $editor        = Resolve-VsEditorName
  $workspaceRoot = Resolve-VsWorkspaceRoot

  if ($editor -eq 'Cursor') { return (Join-Path $workspaceRoot '.cursor') }
  if ($editor -eq 'Claude') { return (Join-Path $workspaceRoot '.claude') }

  return (Join-Path $workspaceRoot '.agents')
}

function Resolve-VsWorkspaceRulesPath {
  $editor        = Resolve-VsEditorName
  $workspacePath = Resolve-VsWorkspacePath

  if ($editor -eq 'Cursor') { return (Join-Path $workspacePath 'rules') }

  if ($editor -eq 'Claude') {
    return (Select-VsFirstExistingPath -Candidates @(
      (Join-Path $workspacePath 'commands'),
      (Join-Path $workspacePath 'rules'),
      $workspacePath
    ))
  }

  return (Join-Path $workspacePath 'instructions')
}

function Resolve-VsSkillsPath {
  param([switch]$Workspace)

  $editor = Resolve-VsEditorName

  if ($Workspace) {
    return (Join-Path (Resolve-VsWorkspacePath) 'skills')
  }

  return (Join-Path (Resolve-VsEditorUserPath) 'skills')
}

function Resolve-VsSettingsPath {
  param([switch]$Workspace, [string]$Subtype)

  $fileMap = @{
    'setting'    = 'settings.json'
    'task'       = 'tasks.json'
    'mcp'        = 'mcp.json'
    'keybinding' = 'keybindings.json'
  }

  $dirPath = if ($Workspace) {
    $editor        = Resolve-VsEditorName
    $workspaceRoot = Resolve-VsWorkspaceRoot
    if ($editor -eq 'Cursor') { Join-Path $workspaceRoot '.cursor' }
    elseif ($editor -eq 'Claude') { Join-Path $workspaceRoot '.claude' }
    else { Join-Path $workspaceRoot '.vscode' }
  }
  else {
    Resolve-VsEditorProfilePath
  }

  if ([string]::IsNullOrWhiteSpace($Subtype)) { return $dirPath }

  $fileName = $fileMap[$Subtype.ToLower()]
  if ($null -eq $fileName) {
    [Console]::Error.WriteLine("Unknown settings subtype '$Subtype'. Valid types: setting, task, mcp, keybinding")
    exit 2
  }

  return (Join-Path $dirPath $fileName)
}

function Invoke-VsBeforePhase {
  param([string]$FilePath)

  if ([string]::IsNullOrWhiteSpace($FilePath)) { return }
  if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return }

  $ccScript = Join-Path $PSScriptRoot 'change-control.ps1'
  if (-not (Test-Path -LiteralPath $ccScript)) {
    [Console]::Error.WriteLine("[Resolve-VsEditor] change-control.ps1 not found: $ccScript")
    return
  }

  $out = & pwsh -NoProfile -File $ccScript --phase before --file $FilePath 2>&1
  $out | ForEach-Object { [Console]::Error.WriteLine([string]$_) }
}

function Get-VsWorkspaceRelativePath {
  param([string]$ScopePath)
  return [System.IO.Path]::GetRelativePath((Resolve-VsWorkspaceRoot), $ScopePath)
}

# --- Argument parsing ---

$validModes     = @('--name','--profile','--user','--rules','--skills','--settings','--workspace')
$modeArg        = $null
$workspaceFlag  = $false
$gitCommitFlag  = $false
$relativeFlag   = $false
$settingsSubtype = $null

$i = 0
while ($i -lt $args.Count) {
  $a = $args[$i]
  if ($a -eq '--workspace') {
    $workspaceFlag = $true
  }
  elseif ($a -eq '--git-commit') {
    $gitCommitFlag = $true
  }
  elseif ($a -eq '--relative') {
    $relativeFlag = $true
  }
  elseif ($a -eq '--settings') {
    if ($null -ne $modeArg) {
      [Console]::Error.WriteLine('Multiple mode flags supplied.')
      [Console]::Error.WriteLine((Get-VsEditorUsage).TrimEnd())
      exit 2
    }
    $modeArg = '--settings'
    if (($i + 1) -lt $args.Count -and -not ($args[$i + 1] -match '^--')) {
      $i++
      $settingsSubtype = $args[$i]
    }
  }
  elseif ($validModes -contains $a) {
    if ($null -ne $modeArg) {
      [Console]::Error.WriteLine('Multiple mode flags supplied.')
      [Console]::Error.WriteLine((Get-VsEditorUsage).TrimEnd())
      exit 2
    }
    $modeArg = $a
  }
  else {
    [Console]::Error.WriteLine("Unknown argument: $a")
    [Console]::Error.WriteLine((Get-VsEditorUsage).TrimEnd())
    exit 2
  }
  $i++
}

$mode = if ($null -ne $modeArg) { $modeArg } else { '--name' }
# --workspace alone retains legacy standalone behaviour
if ($null -eq $modeArg -and $workspaceFlag) { $mode = '--workspace'; $workspaceFlag = $false }

$moduleResolved = Resolve-VsEditorViaModule -Flag $mode

if ($mode -eq '--name') {
  $editorName = if ($moduleResolved -and -not [string]::IsNullOrWhiteSpace($moduleResolved.Editor)) {
    [string]$moduleResolved.Editor
  }
  else {
    Resolve-VsEditorName
  }

  Export-VsEditorScopeContext -Editor $editorName -ScopePath ''
  Write-Output $editorName
  exit 0
}

# For non-composite modes, try module resolution first
if (-not $workspaceFlag -and $moduleResolved -and
    -not [string]::IsNullOrWhiteSpace($moduleResolved.Editor) -and
    -not [string]::IsNullOrWhiteSpace($moduleResolved.ScopePath)) {
  Export-VsEditorScopeContext -Editor $moduleResolved.Editor -ScopePath $moduleResolved.ScopePath
  Write-Output $moduleResolved.ScopePath
  exit 0
}

switch ($mode) {
  '--profile' {
    $editorName = Resolve-VsEditorName
    $scopePath  = Resolve-VsEditorProfilePath
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  '--user' {
    $editorName = Resolve-VsEditorName
    $scopePath  = Resolve-VsEditorUserPath
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  '--rules' {
    $editorName = Resolve-VsEditorName
    $scopePath  = if ($workspaceFlag) { Resolve-VsWorkspaceRulesPath } else { Resolve-VsEditorRulesPath }
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-VsWorkspaceRelativePath -ScopePath $scopePath }
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  '--skills' {
    $editorName = Resolve-VsEditorName
    $scopePath  = Resolve-VsSkillsPath -Workspace:$workspaceFlag
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-VsWorkspaceRelativePath -ScopePath $scopePath }
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  '--settings' {
    $editorName = Resolve-VsEditorName
    $scopePath  = Resolve-VsSettingsPath -Workspace:$workspaceFlag -Subtype $settingsSubtype
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-VsWorkspaceRelativePath -ScopePath $scopePath }
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  '--workspace' {
    $editorName = Resolve-VsEditorName
    $scopePath  = Resolve-VsWorkspacePath
    if ($relativeFlag) { $scopePath = Get-VsWorkspaceRelativePath -ScopePath $scopePath }
    Export-VsEditorScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-VsBeforePhase -FilePath $scopePath }
  }
  default {
    [Console]::Error.WriteLine("Unknown mode: $mode")
    [Console]::Error.WriteLine((Get-VsEditorUsage).TrimEnd())
    exit 2
  }
}
