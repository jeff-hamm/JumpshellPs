param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('User', 'Workspace')]
    [string]$Scope = 'User',
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ServerName = 'jumpshell'
)

$sourceScript = Join-Path $PSScriptRoot '..\src\pwsh\mcp\Install-Mcp.ps1'
$sourceScript = [System.IO.Path]::GetFullPath($sourceScript)
if (-not (Test-Path -LiteralPath $sourceScript)) {
    throw "Jumpshell source MCP install script not found: $sourceScript"
}

& $sourceScript @PSBoundParameters
