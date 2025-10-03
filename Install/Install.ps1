# Install-Requirements.ps1
# Check for required modules by reading from the manifest (with caching)

param(
    [string]$ModuleRoot = $PSScriptRoot,
    [switch]$All
)

# Source the Applications.ps1 file to load the application management functions
. (Join-Path (Split-Path $PSScriptRoot) 'Applications.ps1')

$cacheFilePath = Join-Path $PSScriptRoot '.module-deps-cache'
# Install required applications
Ensure-Applications -FileName (Join-Path $PSScriptRoot 'Required-Applications.txt') -CacheFilePath $cacheFilePath
# Install PowerShell modules from manifest
& (Join-Path $PSScriptRoot 'Install-PowerShellModules.ps1') -ModuleRoot $ModuleRoot -CacheFilePath $cacheFilePath
if ($All) {
    # Install all applications
    Ensure-Applications -FileName (Join-Path $PSScriptRoot 'All-Applications.txt') -CacheFilePath $cacheFilePath
}