<#
.SYNOPSIS
  Sync canonical resolve-editor scripts to all distribution locations.
  Run automatically as part of the pre-build step (extensions/Build.ps1).
#>
param()

$ErrorActionPreference = 'Stop'

$srcRoot = $PSScriptRoot
$repoRoot = Join-Path $srcRoot '..'

$copies = @(
    @{
        Src  = Join-Path $srcRoot 'pwsh\vscode\Resolve-VsEditor.ps1'
        Dest = @(
            Join-Path $repoRoot 'skills\setting\scripts\resolve-editor.ps1'
            Join-Path $repoRoot 'ai\global-instructions\src\user-skills\common\scripts\resolve-editor.ps1'
        )
    }
    @{
        Src  = Join-Path $srcRoot 'sh\resolve-editor.sh'
        Dest = @(
            Join-Path $repoRoot 'skills\setting\scripts\resolve-editor.sh'
            Join-Path $repoRoot 'ai\global-instructions\src\user-skills\common\scripts\resolve-editor.sh'
        )
    }
)

foreach ($entry in $copies) {
    $src = [IO.Path]::GetFullPath($entry.Src)
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Error "Source file not found: $src"
        continue
    }
    foreach ($rawDest in $entry.Dest) {
        $dest    = [IO.Path]::GetFullPath($rawDest)
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dest -Force
        Write-Host "  synced -> $([IO.Path]::GetRelativePath($repoRoot, $dest))" -ForegroundColor Cyan
    }
}
