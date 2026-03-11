param(
    [string]$Version,
    [switch]$Bump
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageJsonPath = Join-Path $PSScriptRoot 'jumpshell\package.json'

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "Could not find extension package file: $packageJsonPath"
}

$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$currentVersion = [string]$packageJson.version

# Exact 3-digit version: use as-is, no auto-bump.
if ($Version -match '^\d+\.\d+\.\d+$') {
    $resolvedVersion = $Version
}
else {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        $baseVersion = $currentVersion
    }
    else {
        $parts = [System.Collections.Generic.List[string]]($Version -split '\.')
        while ($parts.Count -lt 3) { $parts.Add('0') }
        $baseVersion = $parts -join '.'
    }

    if ($Bump) {
        $match = [regex]::Match($baseVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')
        if (-not $match.Success) {
            throw "Cannot bump version '$baseVersion'. Expected major.minor.patch."
        }
        $resolvedVersion = "$($match.Groups['major'].Value).$($match.Groups['minor'].Value).$([int]$match.Groups['patch'].Value + 1)"
        Write-Host "Bumping version: $currentVersion -> $resolvedVersion" -ForegroundColor Cyan
    }
    else {
        $resolvedVersion = $baseVersion
        Write-Host "Using version $resolvedVersion" -ForegroundColor DarkCyan
    }
}

Write-Output $resolvedVersion
