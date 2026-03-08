#!/usr/bin/env pwsh
# expand-templates.ps1 — Expand {{SHELL_NAME}} and {{SHELL_EXT}} placeholders in all SKILL.md files.
#
# Usage:
#   pwsh expand-templates.ps1 [--skills-dir <path>] [--dry-run]
#
# Options:
#   --skills-dir <path>   Explicit skills directory. If omitted, resolved via resolve-editor.ps1 --skills.
#   --dry-run             Report what would change without writing files.
#
# Outputs: JSON to stdout, diagnostics to stderr.
# Exit codes: 0 success, 1 error.

param(
  [string]$SkillsDir = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SkillsDir)) {
  $resolverScript = Join-Path $PSScriptRoot "resolve-editor.ps1"
  if (-not (Test-Path -LiteralPath $resolverScript)) {
    $resolverScript = Get-ChildItem -Path (Join-Path $HOME ".agents/skills") -Recurse -Filter "resolve-editor.ps1" -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not [string]::IsNullOrWhiteSpace($resolverScript) -and (Test-Path -LiteralPath $resolverScript)) {
    $SkillsDir = (& pwsh -NoProfile -File $resolverScript --skills 2>$null).Trim()
  }
}

if ([string]::IsNullOrWhiteSpace($SkillsDir)) {
  $SkillsDir = Join-Path $HOME ".agents/skills"
}

$isWin     = ($Env:OS -eq 'Windows_NT') -or ($PSVersionTable.Platform -ne 'Unix')
$shellName = if ($isWin) { "pwsh" } else { "bash" }
$shellExt  = if ($isWin) { ".ps1" } else { ".sh" }

$updated = @()

if (Test-Path -LiteralPath $SkillsDir) {
  $skillFiles = Get-ChildItem -LiteralPath $SkillsDir -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue |
    Where-Object {
      $raw = Get-Content -LiteralPath $_.FullName -Raw
      $raw -match '\{\{SHELL_NAME\}\}' -or $raw -match '\{\{SHELL_EXT\}\}' -or $raw -match '\{\{SCRIPT_PATHS_NOTE\}\}'
    }

  $scriptPathsNote = '> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.'

  foreach ($file in $skillFiles) {
    $content    = Get-Content -LiteralPath $file.FullName -Raw
    $newContent = $content.Replace('{{SHELL_NAME}}', $shellName)
    $newContent = $newContent.Replace('{{SHELL_EXT}}', $shellExt)
    $newContent = $newContent.Replace('{{SCRIPT_PATHS_NOTE}}', $scriptPathsNote)
    if ($newContent -ne $content) {
      if (-not $DryRun) {
        Set-Content -LiteralPath $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
      }
      $updated += $file.FullName
    }
  }
}

[pscustomobject]@{
  status    = "ok"
  dryRun    = [bool]$DryRun
  skillsDir = $SkillsDir
  shellName = $shellName
  shellExt  = $shellExt
  updated   = @($updated)
} | ConvertTo-Json -Depth 3
