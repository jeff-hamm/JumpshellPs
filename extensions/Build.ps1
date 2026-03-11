param(
    [string]$VsixPath,
    [switch]$Install,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$extensionsRoot = $PSScriptRoot
$extensionRoot = Join-Path $extensionsRoot 'jumpshell'
$packageJsonPath = Join-Path $extensionRoot 'package.json'

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "Could not find extension package file: $packageJsonPath"
}

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$extensionName = [string]$packageJson.name
if ([string]::IsNullOrWhiteSpace($extensionName)) {
    throw "Extension name is missing from $packageJsonPath"
}
if (!$VsixPath) {
    $VsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
}

# Sync canonical resolve-editor scripts to all distribution locations
$syncScript = Join-Path $PSScriptRoot '../src/Sync-Scripts.ps1'
if (Test-Path -LiteralPath $syncScript -PathType Leaf) {
    Write-Host 'Syncing resolve-editor scripts...' -ForegroundColor DarkCyan
    & $syncScript
}

$isStale = [bool](& "$PSScriptRoot/Is-Stale.ps1" -VsixPath $VsixPath)

if ($isStale -or $Clean) {
    $buildStartedPath = Join-Path $extensionsRoot '.build-started'
    Set-Content -LiteralPath $buildStartedPath -Value (Get-Date -Format 'o') -Encoding utf8NoBOM

    Push-Location $extensionRoot
    try {
        & npm run package -- --out $VsixPath
        if ($LASTEXITCODE -ne 0) {
            throw "npm run package failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "No extension input changes detected. Skipping package." -ForegroundColor DarkCyan
}

if (-not (Test-Path -LiteralPath $VsixPath -PathType Leaf)) {
    throw "No VSIX file is available at $VsixPath"
}

Write-Host "Built VSIX: $VsixPath" -ForegroundColor Green

if ($Install) {
    $installScript = Join-Path $extensionsRoot 'Install.ps1'
    if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
        throw "Extension install script not found: $installScript"
    }

    & $installScript -VsixPath $VsixPath
}

Write-Output $VsixPath
