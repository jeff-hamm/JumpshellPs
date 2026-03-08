<#
.SYNOPSIS
  Regenerate ai/global-instructions/dist/ from source files.

.DESCRIPTION
  Locates the ai/global-instructions workspace root automatically and delegates
  to the builder. Run from the repository root, or pass -WorkspaceRoot explicitly.

.PARAMETER WorkspaceRoot
  Path to the ai/global-instructions/ directory. Defaults to <cwd>/ai/global-instructions.

.PARAMETER OutputRelativePath
  Relative output path for the compiled installer. Default: dist/initial-setup.readonly.prompt.md

.PARAMETER BootstrapRelativePath
  Relative output path for the bootstrap file. Default: dist/new-install.readonly.prompt.md

.EXAMPLE
  pwsh .agents/skills/regenerate-initial-setup/scripts/regenerate.ps1
#>
param(
  [string]$WorkspaceRoot       = "",
  [string]$OutputRelativePath  = "dist/initial-setup.readonly.prompt.md",
  [string]$BootstrapRelativePath = "dist/new-install.readonly.prompt.md"
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

$builderPath = "$PSScriptRoot/initial-setup-builder.ps1"
. $builderPath

$model = Build-InitialSetupContent -WorkspaceRoot $WorkspaceRoot -EmitTemporaryGlobalInstructions
$content = $model.Content
$bootstrapContent = Build-NewInstallPromptContent -WorkspaceRoot $WorkspaceRoot -CanonicalRelativePath $OutputRelativePath

$outputPath = Join-Path $WorkspaceRoot $OutputRelativePath
$bootstrapPath = Join-Path $WorkspaceRoot $BootstrapRelativePath

$outputDir = Split-Path -Path $outputPath -Parent
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$bootstrapDir = Split-Path -Path $bootstrapPath -Parent
if (-not (Test-Path -LiteralPath $bootstrapDir)) {
  New-Item -ItemType Directory -Path $bootstrapDir -Force | Out-Null
}

Set-Content -LiteralPath $outputPath -Value $content -Encoding utf8
Set-Content -LiteralPath $bootstrapPath -Value $bootstrapContent -Encoding utf8

Write-Host "Regenerated: $outputPath"
Write-Host "Regenerated: $bootstrapPath"
if (-not [string]::IsNullOrWhiteSpace($model.TemporaryGlobalInstructionsPath)) {
  Write-Host "Temporary global instructions: $($model.TemporaryGlobalInstructionsPath)"
}

Write-Host "Included user-skill files: $($model.SkillSources.Count)"
