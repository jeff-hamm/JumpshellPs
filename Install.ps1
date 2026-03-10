param(
    [switch]$Build,

    [string]$VsixPath
)

$extensionInstallScript = Join-Path $PSScriptRoot 'extensions\Install.ps1'
if (-not (Test-Path -LiteralPath $extensionInstallScript)) {
    throw "Jumpshell extension installer not found: $extensionInstallScript"
}

& $extensionInstallScript @PSBoundParameters
