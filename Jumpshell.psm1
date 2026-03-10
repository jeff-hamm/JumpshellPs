$sourceManifestPath = Join-Path $PSScriptRoot 'src\pwsh\Jumpshell.psd1'

if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
    throw "Jumpshell source manifest not found: $sourceManifestPath"
}

Import-Module $sourceManifestPath -Force -Global
