param(
    [string]$VsixPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

$extensionsRoot = $PSScriptRoot
$extensionRoot  = Join-Path $extensionsRoot 'jumpshell'
$repoRoot       = Split-Path -Parent $extensionsRoot
$packageJsonPath = Join-Path $extensionRoot 'package.json'
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$extensionName = [string]$packageJson.name
if (!$VsixPath) {
    $VsixPath = Join-Path $extensionsRoot ("{0}.vsix" -f $extensionName)
}

if (-not (Test-Path -LiteralPath $VsixPath -PathType Leaf)) {
    Write-Output $true
    return
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
    (Join-Path $repoRoot 'mcps')
)
$latestInputWriteTime = Get-LatestInputWriteTime -InputPaths $inputPaths

$buildStartedPath = Join-Path $extensionsRoot '.build-started'
$buildRefTime = if (Test-Path -LiteralPath $buildStartedPath -PathType Leaf) {
    (Get-Item -LiteralPath $buildStartedPath).LastWriteTimeUtc
} else {
    (Get-Item -LiteralPath $VsixPath).LastWriteTimeUtc
}

Write-Output ($latestInputWriteTime -gt $buildRefTime)