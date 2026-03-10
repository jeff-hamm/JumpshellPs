param(
    [switch]$Install,

    [switch]$VersionedFileName,

    [string]$Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

$vsixPath = $null
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    # Caller has already resolved the final version; just write it.
    Set-PackageVersion -PackageJsonPath $packageJsonPath -NewVersion $Version
    Write-Host "Version set to $Version" -ForegroundColor Green
    # Re-read after write so the VSIX path uses the new version.
    $packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
}

$stableVsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
$newVersionedVsixPath = Join-Path $extensionsRoot ("{0}-{1}.vsix" -f $extensionName, ([string]$packageJson.version))
$vsixPath = if ($VersionedFileName) { $newVersionedVsixPath } else { $stableVsixPath }

$latestVsixPath = Get-LatestVsixPath -ExtensionsRoot $extensionsRoot -ExtensionName $extensionName
$isStale = $true
if (-not [string]::IsNullOrWhiteSpace($latestVsixPath) -and (Test-Path -LiteralPath $latestVsixPath -PathType Leaf)) {
    $latestInputWriteTime = Get-LatestInputWriteTime -InputPaths $inputPaths
    $latestVsixWriteTime = (Get-Item -LiteralPath $latestVsixPath).LastWriteTimeUtc
    $isStale = $latestInputWriteTime -gt $latestVsixWriteTime
}

if ($isStale -or -not [string]::IsNullOrWhiteSpace($Version)) {
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
    Write-Host "No extension input changes detected. Skipping package." -ForegroundColor DarkCyan

    if (Test-Path -LiteralPath $stableVsixPath -PathType Leaf) {
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
