$sourceManifestPath = Join-Path $PSScriptRoot 'src\pwsh\JumpShellPs.psd1'

if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
    throw "JumpShell source manifest not found: $sourceManifestPath"
}

Import-Module $sourceManifestPath -Force -Global
