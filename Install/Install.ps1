# Install-Requirements.ps1
# Check for required modules by reading from the manifest (with caching)

param(
    [string]$ModuleRoot = $PSScriptRoot
)
# Install HomeAssistant module wrapper
$cacheFilePath = Join-Path $PSScriptRoot '.module-deps-cache'
& (Join-Path $PSScriptRoot 'Install-ApplicationDeps.ps1') -ModuleRoot $ModuleRoot -CacheFilePath $cacheFilePath
# Install PowerShell modules from manifest
& (Join-Path $PSScriptRoot 'Install-PowerShellModules.ps1') -ModuleRoot $ModuleRoot -CacheFilePath $cacheFilePath