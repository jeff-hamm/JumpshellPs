param(
    [string]$Version,

    [switch]$NoBuild,

    [switch]$Publish,

    [string]$Message
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$extensionsRoot = $PSScriptRoot
$extensionRoot = Join-Path $extensionsRoot 'jumpshell'
$packageJsonPath = Join-Path $extensionRoot 'package.json'
$repoRoot = Split-Path -Parent $extensionsRoot
$envFilePath = Join-Path $extensionsRoot '.env'

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $lines = Get-Content -LiteralPath $Path
    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        $splitIndex = $line.IndexOf('=')
        if ($splitIndex -lt 1) {
            continue
        }

        $name = $line.Substring(0, $splitIndex).Trim()
        $value = $line.Substring($splitIndex + 1).Trim().Trim('"').Trim("'")

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [Environment]::SetEnvironmentVariable($name, $value)
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

function Resolve-VsixPath {
    param(
        [string]$ExtensionsRoot,
        [string]$ExtensionName,
        [string]$ReleaseVersion
    )

    $candidates = @(
        (Join-Path $ExtensionsRoot ("{0}-{1}.vsix" -f $ExtensionName, $ReleaseVersion)),
        (Join-Path $ExtensionsRoot ("{0}.vsix" -f $ExtensionName))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $latest = Get-ChildItem -LiteralPath $ExtensionsRoot -Filter ("{0}*.vsix" -f $ExtensionName) -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -ne $latest) {
        return $latest.FullName
    }

    throw "No VSIX file is available in $ExtensionsRoot"
}

function Get-IncrementedPatchVersion {
    param([string]$Version)

    $match = [regex]::Match($Version, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')
    if (-not $match.Success) {
        throw "Cannot increment version '$Version'. Expected major.minor.patch."
    }

    $major = [int]$match.Groups['major'].Value
    $minor = [int]$match.Groups['minor'].Value
    $patch = [int]$match.Groups['patch'].Value
    return "$major.$minor.$($patch + 1)"
}

function Test-SrcChangedSinceLastTag {
    param([string]$RepoRoot)

    $lastTag = git -C $RepoRoot describe --tags --abbrev=0 2>$null
    if ([string]::IsNullOrWhiteSpace($lastTag)) {
        # No prior tag — treat everything as changed.
        return $true
    }

    $changedFiles = git -C $RepoRoot diff --name-only $lastTag HEAD 2>$null
    if ($changedFiles | Where-Object {
        $_ -match '^src/' -or
        $_ -match '^skills/' -or
        $_ -match '^mcps/' -or
        $_ -match '^extensions/jumpshell/'
    }) {
        return $true
    }

    return $false
}

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "Could not find extension package file: $packageJsonPath"
}

# ── Determine version to build ────────────────────────────────────────────────
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$currentVersion = [string]$packageJson.version
if ([string]::IsNullOrWhiteSpace($currentVersion)) {
    throw "Extension version is missing from $packageJsonPath"
}

# Detect whether the caller specified an explicit 3-digit version (e.g. 1.2.3).
$isThreeDigitVersion = $false
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $isThreeDigitVersion = $Version -match '^\d+\.\d+\.\d+$'
}

$resolvedVersion = $currentVersion
if ($isThreeDigitVersion) {
    # Exact 3-digit version: use as-is, no auto-bump.
    $resolvedVersion = $Version
}
else {
    # Resolve a partial version spec (e.g. "1" or "1.0") into a base, then bump patch if src changed.
    $baseVersion = $currentVersion
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        # Expand partial version against the current one.
        $parts = $Version -split '\.'
        $curParts = $currentVersion -split '\.'
        while ($parts.Count -lt 3) { $parts += $curParts[$parts.Count] }
        $baseVersion = $parts -join '.'
    }

    $srcChanged = Test-SrcChangedSinceLastTag -RepoRoot $repoRoot
    if ($srcChanged) {
        $resolvedVersion = Get-IncrementedPatchVersion -Version $baseVersion
        Write-Host "Src changed since last tag — bumping version: $currentVersion -> $resolvedVersion" -ForegroundColor Cyan
    }
    else {
        $resolvedVersion = $baseVersion
        Write-Host "No src changes since last tag. Using version $resolvedVersion" -ForegroundColor DarkCyan
    }
}


$builtVsixPath = $null
if (-not $NoBuild) {
    $buildArgs = @{ Version = $resolvedVersion }

    $buildScript = Join-Path $extensionsRoot 'Build.ps1'
    $builtVsixPath = & $buildScript @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Build.ps1 failed with exit code $LASTEXITCODE"
    }

    if ($builtVsixPath -is [array]) {
        $builtVsixPath = $builtVsixPath[-1]
    }
}

# ── Read the final version from package.json ───────────────────────────────────
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$extensionName = [string]$packageJson.name
$publisher = [string]$packageJson.publisher
$releaseVersion = [string]$packageJson.version
if ([string]::IsNullOrWhiteSpace($releaseVersion)) {
    throw "Extension version is missing from $packageJsonPath"
}

if ([string]::IsNullOrWhiteSpace($extensionName)) {
    throw "Extension name is missing from $packageJsonPath"
}

if ([string]::IsNullOrWhiteSpace($publisher)) {
    throw "Extension publisher is missing from $packageJsonPath"
}

$tag = "v$releaseVersion"
Write-Host "Releasing $tag" -ForegroundColor Cyan

# ── Generate release notes with ai-cli ─────────────────────────────────────────
$lastTag = git -C $repoRoot describe --tags --abbrev=0 2>$null
$commitRange = if ($lastTag) { "$lastTag..HEAD" } else { 'HEAD' }
$commitLog = git -C $repoRoot log $commitRange --pretty=format:'- %s (%h)' -- . 2>$null
if ([string]::IsNullOrWhiteSpace($commitLog)) {
    $commitLog = git -C $repoRoot log -20 --pretty=format:'- %s (%h)' 2>$null
}

$notePrompt = @"
Write concise release notes for Jumpshell extension version $releaseVersion.
The audience is end-users installing the extension from a GitHub Release VSIX.
Use markdown with a heading "## What's Changed" and bullet points.
Keep it short — no more than 15 bullet points.
Do NOT include commit hashes in the output.

Commits since last release:
$commitLog
"@

$releaseNotes = $null
try {
    $releaseNotes = $notePrompt | ai-cli 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($releaseNotes)) {
        $releaseNotes = $null
    }
}
catch {
    Write-Warning "ai-cli failed to generate release notes: $_"
}

if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
    Write-Warning 'Could not generate release notes with ai-cli. Using commit log as fallback.'
    $releaseNotes = "## What's Changed`n`n$commitLog"
}

Write-Host ''
Write-Host '── Release Notes ──' -ForegroundColor Yellow
Write-Host $releaseNotes
Write-Host ''

# ── Optional Marketplace publish ──────────────────────────────────────────────
if ($Publish) {
    Import-DotEnv -Path $envFilePath
    if ([string]::IsNullOrWhiteSpace($env:VSCE_PAT)) {
        throw "VSCE_PAT is not set. Add it to $envFilePath or set VSCE_PAT in your environment."
    }

    if (-not [string]::IsNullOrWhiteSpace($env:VSCE_PUBLISHER) -and $env:VSCE_PUBLISHER -ne $publisher) {
        throw "VSCE_PUBLISHER ($($env:VSCE_PUBLISHER)) does not match package publisher ($publisher) in $packageJsonPath"
    }

    $vsixPath = if (-not [string]::IsNullOrWhiteSpace($builtVsixPath)) {
        [string]$builtVsixPath
    }
    else {
        Resolve-VsixPath -ExtensionsRoot $extensionsRoot -ExtensionName $extensionName -ReleaseVersion $releaseVersion
    }

    if (-not (Test-Path -LiteralPath $vsixPath -PathType Leaf)) {
        throw "VSIX not found: $vsixPath"
    }

    Write-Host "Publishing $publisher.$extensionName v$releaseVersion from $vsixPath" -ForegroundColor Cyan
    Push-Location $extensionRoot
    try {
        & npx @vscode/vsce publish --packagePath $vsixPath
        if ($LASTEXITCODE -ne 0) {
            throw "vsce publish failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

# ── Git: add, commit, push ────────────────────────────────────────────────────
$commitMessage = if (-not [string]::IsNullOrWhiteSpace($Message)) {
    $Message
}
else {
    "release: Jumpshell $tag"
}

Push-Location $repoRoot
try {
    git add -A
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

    # Only commit if there are staged changes.
    $status = git status --porcelain
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        git commit -m $commitMessage
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
    }
    else {
        Write-Host 'No changes to commit.' -ForegroundColor DarkCyan
    }

    git push
    if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

    # ── Tag and push ──────────────────────────────────────────────────────────
    git tag -f $tag
    if ($LASTEXITCODE -ne 0) { throw "git tag -f $tag failed" }

    git push origin $tag --force
    if ($LASTEXITCODE -ne 0) { throw "git push origin $tag --force failed" }

    Write-Host "Pushed tag $tag" -ForegroundColor Green
}
finally {
    Pop-Location
}

Write-Output $tag
