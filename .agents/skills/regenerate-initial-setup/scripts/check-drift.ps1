<#
.SYNOPSIS
  Check for drift between source files and the compiled installer.

.DESCRIPTION
  Locates the ai/global-instructions workspace root automatically and delegates
  to the builder. Run from the repository root, or pass -WorkspaceRoot explicitly.
  Exit code: 0 = no drift, 1 = drift detected, 2 = error.

.PARAMETER WorkspaceRoot
  Path to the ai/global-instructions/ directory. Defaults to <cwd>/ai/global-instructions.

.PARAMETER CompiledRelativePath
  Relative path to the compiled installer file. Default: dist/initial-setup.readonly.prompt.md

.EXAMPLE
  pwsh .agents/skills/regenerate-initial-setup/scripts/check-drift.ps1
#>
param(
  [string]$WorkspaceRoot      = "",
  [string]$CompiledRelativePath = "dist/initial-setup.readonly.prompt.md"
)
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $candidate = Join-Path (Get-Location).Path "ai/global-instructions"
  if (Test-Path -LiteralPath $candidate) {
    $WorkspaceRoot = $candidate
  } else {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $git) {
      $root = (& git rev-parse --show-toplevel 2>$null)
      if (-not [string]::IsNullOrWhiteSpace($root)) {
        $candidate = Join-Path $root.Trim() "ai/global-instructions"
        if (Test-Path -LiteralPath $candidate) { $WorkspaceRoot = $candidate }
      }
    }
  }
  if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    throw "Cannot locate ai/global-instructions. Run from the workspace root or pass -WorkspaceRoot."
  }
}

$ErrorActionPreference = "Stop"

$builderPath = Join-Path $WorkspaceRoot "scripts/regenerate-initial-setup/initial-setup-builder.ps1"
. $builderPath

$compiledPath = Join-Path $WorkspaceRoot $CompiledRelativePath
if (-not (Test-Path -LiteralPath $compiledPath)) {
  Write-Error "Compiled prompt not found: $compiledPath"
  exit 2
}

$expectedModel = Build-InitialSetupContent -WorkspaceRoot $WorkspaceRoot
$expected = Normalize-Content -Text $expectedModel.Content
$actual = Normalize-Content -Text (Get-Content -LiteralPath $compiledPath -Raw)

if ($actual -eq $expected) {
  Write-Host "No drift detected."
  exit 0
}

Write-Host "Drift detected between source files and compiled prompt."
$expectedLines = $expected -split "`n"
$actualLines = $actual -split "`n"
Compare-Object -ReferenceObject $expectedLines -DifferenceObject $actualLines -SyncWindow 3 |
  Select-Object -First 80

exit 1