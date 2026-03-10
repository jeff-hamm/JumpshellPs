param(
    [switch]$Install,

    [switch]$VersionedFileName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-IncrementedBuildVersion {
    param([string]$Version)

    $pattern = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:\.\d+)*$'
    $match = [regex]::Match($Version, $pattern)

    if (-not $match.Success) {
        throw "Unsupported version format '$Version'. Expected major.minor.patch (optionally with legacy extra numeric segments)"
    }

    $major = [int]$match.Groups['major'].Value
    $minor = [int]$match.Groups['minor'].Value
    $patch = [int]$match.Groups['patch'].Value

    # VS Code extension versions must be strict semver (major.minor.patch).
    return "$major.$minor.$($patch + 1)"
}

function Set-PackageVersion {
    param(
        [string]$PackageJsonPath,
        [string]$NewVersion
    )

    $raw = Get-Content -LiteralPath $PackageJsonPath -Raw
    $pattern = '(?m)^(\s*"version"\s*:\s*")[^"]+(")'
    $regex = [regex]::new($pattern)
    $matchCount = $regex.Matches($raw).Count

    if ($matchCount -ne 1) {
        throw "Expected exactly one top-level version field in $PackageJsonPath, found $matchCount"
    }

    $updated = $regex.Replace(
        $raw,
        { param($m) $m.Groups[1].Value + $NewVersion + $m.Groups[2].Value },
        1
    )

    Set-Content -LiteralPath $PackageJsonPath -Value $updated -Encoding utf8NoBOM
}

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

$currentVersion = [string]$packageJson.version
if ([string]::IsNullOrWhiteSpace($currentVersion)) {
    throw "Extension version is missing from $packageJsonPath"
}

$newVersion = Get-IncrementedBuildVersion -Version $currentVersion
Set-PackageVersion -PackageJsonPath $packageJsonPath -NewVersion $newVersion

Write-Host "Version: $currentVersion -> $newVersion" -ForegroundColor Green

$versionedVsixPath = Join-Path $extensionsRoot ("{0}-{1}.vsix" -f $extensionName, $newVersion)
$stableVsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
$vsixPath = if ($VersionedFileName) { $versionedVsixPath } else { $stableVsixPath }

Push-Location $extensionRoot
try {
    & npm run package -- --out $vsixPath
    if ($LASTEXITCODE -ne 0) {
        throw "npm run package failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $vsixPath -PathType Leaf)) {
    $latestVsix = Get-ChildItem -LiteralPath $extensionsRoot -Filter '*.vsix' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $latestVsix) {
        throw "No VSIX file was produced in $extensionsRoot"
    }

    $vsixPath = $latestVsix.FullName
}

Write-Host "Built VSIX: $vsixPath" -ForegroundColor Green

if ($Install) {
    $installScript = Join-Path $extensionsRoot 'Install.ps1'
    if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
        throw "Extension install script not found: $installScript"
    }

    & $installScript -VsixPath $vsixPath
}

Write-Output $vsixPath