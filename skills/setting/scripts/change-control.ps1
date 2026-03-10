<#
.SYNOPSIS
  Run before/after file-edit safety checks for skills.

.DESCRIPTION
  Run with --phase before to check git status and snapshot the target file to <file>.bak.
  Run with --phase after to show git diff and git diff --stat for the target file.
  Outputs JSON to stdout; diagnostics to stderr.

.EXAMPLE
  pwsh scripts/change-control.ps1 --phase before --file settings.json
  pwsh scripts/change-control.ps1 --phase after  --file settings.json

.NOTES
  Exit codes:
    0  Success
    1  File not found or required argument missing
#>

param(
  [Parameter(Mandatory, HelpMessage = 'Phase to run: before or after')]
  [ValidateSet('before', 'after')]
  [string]$Phase,

  [Parameter(Mandatory, HelpMessage = 'Path to the file being changed')]
  [string]$File,

  [switch]$Approve,
  [switch]$Reject,
  [string]$Message
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
  param([string[]]$GitArgs)
  & git @GitArgs 2>&1
}

function Get-GitRoot {
  param([string]$Dir)
  $out = Invoke-Git -GitArgs @('-C', $Dir, 'rev-parse', '--show-toplevel')
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($out | Out-String).Trim()
}

$absFile = [System.IO.Path]::GetFullPath($File)

if (-not (Test-Path -LiteralPath $absFile)) {
  Write-Error "File not found: $absFile"
  exit 1
}

$fileDir    = Split-Path -Parent $absFile
$backupPath = "$absFile.bak"
$gitRoot    = Get-GitRoot -Dir $fileDir
$inGit      = -not [string]::IsNullOrEmpty($gitRoot)

if ($Phase -eq 'before') {
  Copy-Item -LiteralPath $absFile -Destination $backupPath -Force

  $gitStatus = $null
  if ($inGit) {
    $gitStatus = (Invoke-Git -GitArgs @('-C', $gitRoot, 'status', '--short', '--', $absFile) | Out-String).Trim()
  }

  [pscustomobject]@{
    phase      = 'before'
    file       = $absFile
    backupPath = $backupPath
    inGit      = $inGit
    gitStatus  = $gitStatus
  } | ConvertTo-Json -Depth 3

  exit 0
}

if ($Phase -eq 'after') {
  if ($Approve -and $Reject) {
    Write-Error '--approve and --reject cannot both be set'
    exit 1
  }

  $diff     = $null
  $diffStat = $null

  if ($inGit) {
    $diff     = (Invoke-Git -GitArgs @('-C', $gitRoot, 'diff', '--', $absFile) | Out-String).Trim()
    $diffStat = (Invoke-Git -GitArgs @('-C', $gitRoot, 'diff', '--stat', '--', $absFile) | Out-String).Trim()
  }
  elseif (Test-Path -LiteralPath $backupPath) {
    $before   = Get-Content -LiteralPath $backupPath -Raw
    $after    = Get-Content -LiteralPath $absFile -Raw
    $diff     = if ($before -eq $after) { '(no changes)' } else { "(not in git — backup exists at $backupPath)" }
    $diffStat = $diff
  }

  $committed = $false
  $restored  = $false

  if ($Approve) {
    if ($inGit) {
      Invoke-Git -GitArgs @('-C', $gitRoot, 'add', '--', $absFile) | Out-Null
      $commitMsg = if (-not [string]::IsNullOrWhiteSpace($Message)) { $Message } else { "chg: update $([IO.Path]::GetFileName($absFile))" }
      Invoke-Git -GitArgs @('-C', $gitRoot, 'commit', '-m', $commitMsg) | Out-Null
    }
    if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
    $committed = $true
  }

  if ($Reject) {
    if (Test-Path -LiteralPath $backupPath) {
      Copy-Item -LiteralPath $backupPath -Destination $absFile -Force
      Remove-Item -LiteralPath $backupPath -Force
    }
    $restored = $true
  }

  [pscustomobject]@{
    phase      = 'after'
    file       = $absFile
    backupPath = $backupPath
    hasBackup  = (Test-Path -LiteralPath $backupPath)
    inGit      = $inGit
    diff       = $diff
    diffStat   = $diffStat
    approved   = $committed
    restored   = $restored
  } | ConvertTo-Json -Depth 3

  exit 0
}
