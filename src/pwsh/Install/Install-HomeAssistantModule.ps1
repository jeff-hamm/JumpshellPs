# Install-HomeAssistantModule.ps1
# Install and configure HomeAssistant module wrapper

param(
    [string]$ModulePath = (Split-Path (Get-Module -ListAvailable PowerShell | Select-Object -First 1).ModuleBase)
)

function Install-HaModule() {
    if (!(Test-Path "$ModulePath\HomeAssistantPs")) {
        git clone https://github.com/serialscriptr/HomeAssistantPS.git "$ModulePath\HomeAssistantPs"
    }
    if(!(Test-Path "$ModulePath\HomeAssistantPs\HomeAssistantPs.psd1")) {
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
'@ | Out-File -FilePath "$ModulePath\HomeAssistantPs\HomeAssistantPs.psd1" -Encoding UTF8
    }
    if(!(Test-Path "$ModulePath\HomeAssistantPs\HomeAssistantPs.psm1")) {
        @'
# HomeAssistantPs.psm1 - Wrapper module that imports the actual HomeAssistant module

# Get the path to the actual HomeAssistant module by finding the latest version
$homeAssistantBasePath = Join-Path $PSScriptRoot "HomeAssistant"
if (Test-Path $homeAssistantBasePath) {
    # Get all version directories and sort by semantic version descending
    $versionDirs = Get-ChildItem -Path $homeAssistantBasePath -Directory | 
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } |
        Sort-Object { [System.Version]$_.Name } -Descending
    
    if ($versionDirs.Count -gt 0) {
        $latestVersion = $versionDirs[0].Name
        $actualModulePath = Join-Path $homeAssistantBasePath "$latestVersion\HomeAssistant.psm1"
    } else {
        Write-Error "No valid version directories found in $homeAssistantBasePath"
        return
    }
} else {
    Write-Error "HomeAssistant base directory not found at: $homeAssistantBasePath"
    return
}

if (Test-Path $actualModulePath) {
    Write-Debug "Loading HomeAssistant module from: $actualModulePath (version: $latestVersion)"
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

# Run the installation
Install-HaModule
