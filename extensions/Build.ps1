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

function Get-LatestInputWriteTime {
    param([string[]]$InputPaths)

    $latest = [DateTime]::MinValue

    foreach ($inputPath in $InputPaths) {
        if (-not (Test-Path -LiteralPath $inputPath)) {
            continue
        }

        $item = Get-Item -LiteralPath $inputPath
        if (-not $item.PSIsContainer) {
            if ($item.LastWriteTimeUtc -gt $latest) {
                $latest = $item.LastWriteTimeUtc
            }
            continue
        }

        $files = Get-ChildItem -LiteralPath $inputPath -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($file.LastWriteTimeUtc -gt $latest) {
                $latest = $file.LastWriteTimeUtc
            }
        }
    }

    return $latest
}

function Get-LatestVsixPath {
    param(
        [string]$ExtensionsRoot,
        [string]$ExtensionName
    )

    $pattern = "{0}*.vsix" -f $ExtensionName
    $latest = Get-ChildItem -LiteralPath $ExtensionsRoot -Filter $pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        return $null
    }

    return $latest.FullName
}

$extensionsRoot = $PSScriptRoot
$extensionRoot = Join-Path $extensionsRoot 'jumpshell'
$packageJsonPath = Join-Path $extensionRoot 'package.json'
$repoRoot = Split-Path -Parent $extensionsRoot

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

$stableVsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
$currentVersionedVsixPath = Join-Path $extensionsRoot ("{0}-{1}.vsix" -f $extensionName, $currentVersion)

$inputPaths = @(
    (Join-Path $extensionRoot 'package.json'),
    (Join-Path $extensionRoot 'tsconfig.json'),
    (Join-Path $extensionRoot '.vscodeignore'),
    (Join-Path $extensionRoot 'README.md'),
    (Join-Path $extensionRoot 'src'),
    (Join-Path $extensionRoot 'assets'),
    (Join-Path $extensionRoot 'scripts'),
    (Join-Path $repoRoot 'skills'),
    (Join-Path $repoRoot 'mcps'),
    (Join-Path $repoRoot 'src\python\ai-backends')
)

$latestInputWriteTime = Get-LatestInputWriteTime -InputPaths $inputPaths
$latestVsixPath = Get-LatestVsixPath -ExtensionsRoot $extensionsRoot -ExtensionName $extensionName

$isStale = $true
if (-not [string]::IsNullOrWhiteSpace($latestVsixPath) -and (Test-Path -LiteralPath $latestVsixPath -PathType Leaf)) {
    $latestVsixWriteTime = (Get-Item -LiteralPath $latestVsixPath).LastWriteTimeUtc
    $isStale = $latestInputWriteTime -gt $latestVsixWriteTime
}

$vsixPath = $null
if ($isStale) {
    $newVersion = Get-IncrementedBuildVersion -Version $currentVersion
    Set-PackageVersion -PackageJsonPath $packageJsonPath -NewVersion $newVersion

    Write-Host "Version: $currentVersion -> $newVersion" -ForegroundColor Green

    $newVersionedVsixPath = Join-Path $extensionsRoot ("{0}-{1}.vsix" -f $extensionName, $newVersion)
    $vsixPath = if ($VersionedFileName) { $newVersionedVsixPath } else { $stableVsixPath }

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
}
else {
    Write-Host "No extension input changes detected. Skipping version bump and package." -ForegroundColor DarkCyan

    if ($VersionedFileName -and (Test-Path -LiteralPath $currentVersionedVsixPath -PathType Leaf)) {
        $vsixPath = $currentVersionedVsixPath
    }
    elseif (Test-Path -LiteralPath $stableVsixPath -PathType Leaf) {
        $vsixPath = $stableVsixPath
    }
    elseif (-not [string]::IsNullOrWhiteSpace($latestVsixPath) -and (Test-Path -LiteralPath $latestVsixPath -PathType Leaf)) {
        $vsixPath = $latestVsixPath
    }
}

if ([string]::IsNullOrWhiteSpace($vsixPath) -or -not (Test-Path -LiteralPath $vsixPath -PathType Leaf)) {
    $latestVsixPath = Get-LatestVsixPath -ExtensionsRoot $extensionsRoot -ExtensionName $extensionName
    if ([string]::IsNullOrWhiteSpace($latestVsixPath) -or -not (Test-Path -LiteralPath $latestVsixPath -PathType Leaf)) {
        throw "No VSIX file is available in $extensionsRoot"
    }

    $vsixPath = $latestVsixPath
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
