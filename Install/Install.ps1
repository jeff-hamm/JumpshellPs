# Install-Requirements.ps1
# Check for required modules by reading from the manifest (with caching)

param(
    [string]$ModuleRoot = $PSScriptRoot
)

function Install-Deps() {

}
function Install-HaModule() {
    cd $ModulePath
    if (!(Test-Path "$ModulePath\HomeAssistantPs")) {
        git clone https://github.com/serialscriptr/HomeAssistantPS.git
    }
    if(!(Test-Path "$ModulePath\HomeAssistantPs\HomeAssistantPs.psm1")) {
    @'
@{
    RootModule = 'HomeAssistantPs.psm1'
    ModuleVersion = '0.1.3'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-123456789abc'
    Author = 'HomeAssistant Module Wrapper'
    Description = 'Wrapper module for HomeAssistant functionality'
    PowerShellVersion = '5.1'
    FunctionsToExport = '*'
    CmdletsToExport = '*'
    VariablesToExport = '*'
    AliasesToExport = '*'
}
'@ | Out-File -FilePath "$ModulePath\HomeAssistantPs\HomeAssistantPs.psm1" -Encoding UTF8
    }
    if(!(Test-Path "$ModulePath\HomeAssistantPs\HomeAssistantPs.psd1")) {
        @'
# HomeAssistantPs.psm1 - Wrapper module that imports the actual HomeAssistant module

# Get the path to the actual HomeAssistant module
$actualModulePath = Join-Path $PSScriptRoot "HomeAssistant\0.1.3\HomeAssistant.psm1"

if (Test-Path $actualModulePath) {
    # Import the actual module
    Import-Module $actualModulePath -Force -Global
    
    # Re-export all functions, cmdlets, variables, and aliases from the imported module
    $importedModule = Get-Module HomeAssistant
    if ($importedModule) {
        if ($importedModule.ExportedFunctions.Count -gt 0) {
            Export-ModuleMember -Function $importedModule.ExportedFunctions.Keys
        }
        if ($importedModule.ExportedCmdlets.Count -gt 0) {
            Export-ModuleMember -Cmdlet $importedModule.ExportedCmdlets.Keys
        }
        if ($importedModule.ExportedVariables.Count -gt 0) {
            Export-ModuleMember -Variable $importedModule.ExportedVariables.Keys
        }
        if ($importedModule.ExportedAliases.Count -gt 0) {
            Export-ModuleMember -Alias $importedModule.ExportedAliases.Keys
        }
    }
} else {
    Write-Error "HomeAssistant module not found at expected path: $actualModulePath"
}
'@ | Out-File -FilePath "$ModulePath\HomeAssistantPs\HomeAssistantPs.psm1" -Encoding UTF8
    }
}
Install-HaModule



$manifestPath = Join-Path $ModuleRoot 'JumpshellPs.psd1'
$cacheFilePath = Join-Path $PSScriptRoot '.module-deps-cache'

if (Test-Path $manifestPath) {
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $requiredModules = $manifest.RequiredModules
    
    if ($requiredModules -and $requiredModules.Count -gt 0) {
        # Normalize required modules to just names
        $requiredModuleNames = @()
        foreach ($module in $requiredModules) {
            $moduleName = if ($module -is [string]) { $module } else { $module.ModuleName }
            $requiredModuleNames += $moduleName
        }
        
        $moduleHash = ($requiredModuleNames | Sort-Object | ConvertTo-Json -Compress | Get-FileHash -Algorithm SHA256).Hash
        $installedModules = @()
        $needsCheck = $true
        
        # Check if cache file exists and is valid
        if (Test-Path $cacheFilePath) {
            try {
                $cache = Get-Content $cacheFilePath -Raw | ConvertFrom-Json
                if ($cache.Hash -eq $moduleHash -and $cache.CheckDate -gt (Get-Date).AddDays(-7)) {
                    $installedModules = if ($cache.InstalledModules) { $cache.InstalledModules } else { @() }
                    $needsCheck = $false
                    Write-Debug "Using cached module list (valid until $($cache.CheckDate.AddDays(7)))"
                }
            }
            catch {
                # Cache file corrupted, will regenerate
                Write-Debug "Cache file corrupted, will regenerate"
            }
        }
        
        if ($needsCheck) {
            Write-Debug "Checking available modules..."
            # Get list of actually available modules
            $installedModules = @()
            foreach ($moduleName in $requiredModuleNames) {
                if (Get-Module -ListAvailable -Name $moduleName) {
                    $installedModules += $moduleName
                }
            }
        }
        
        # Find missing modules by comparing required vs installed
        $missingModules = $requiredModuleNames | Where-Object { $_ -notin $installedModules }
        
        if ($missingModules.Count -gt 0) {
            Write-Warning "Missing required modules: $($missingModules -join ', ')"
            Write-Host "Installing missing modules..." -ForegroundColor Yellow
            
            foreach ($moduleName in $missingModules) {
                try {
                    Write-Host "Installing $moduleName..." -ForegroundColor Cyan
                    Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
                    Write-Host "✓ $moduleName installed successfully" -ForegroundColor Green
                    # Add to installed list
                    $installedModules += $moduleName
                }
                catch {
                    Write-Error "Failed to install $moduleName`: $_"
                }
            }
        }
        
        # Update cache with current state (preserve existing application data)
        if (Test-Path $cacheFilePath) {
            $existingCache = Get-Content $cacheFilePath -Raw | ConvertFrom-Json
            $cacheData = @{
                Hash = $moduleHash
                AppHash = if ($existingCache.AppHash) { $existingCache.AppHash } else { "" }
                CheckDate = Get-Date
                InstalledModules = $installedModules | Sort-Object
                InstalledApplications = if ($existingCache.InstalledApplications) { $existingCache.InstalledApplications } else { @() }
            }
        } else {
            $cacheData = @{
                Hash = $moduleHash
                AppHash = ""
                CheckDate = Get-Date
                InstalledModules = $installedModules | Sort-Object
                InstalledApplications = @()
            }
        }
        $cacheData | ConvertTo-Json | Set-Content $cacheFilePath -Force
        
        if ($missingModules.Count -eq 0) {
            Write-Debug "All required modules are available"
        }
    }
}

# Install required applications via winget
$requiredApplications = & (Join-Path $PSScriptRoot 'Required-Applications.ps1')
& (Join-Path $PSScriptRoot 'Install-ApplicationDeps.ps1') -ModuleRoot $ModuleRoot -RequiredApplications $requiredApplications -CacheFilePath $cacheFilePath
