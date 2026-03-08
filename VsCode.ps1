# VsCode.ps1
# Thin loader that composes VS Code functions from the vscode/ folder.
$vsCodeScriptsPath = Join-Path $PSScriptRoot 'vscode'

if (Test-Path -LiteralPath $vsCodeScriptsPath) {
    Get-ChildItem -LiteralPath $vsCodeScriptsPath -Filter '*.ps1' -File |
        Sort-Object Name |
        ForEach-Object {
            . $_.FullName
        }
}
