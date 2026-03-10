param(
    [switch]$Install,

    [switch]$VersionedFileName
)

$buildScript = Join-Path $PSScriptRoot 'Build.ps1'
if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Extension build script not found: $buildScript"
}

& $buildScript @PSBoundParameters