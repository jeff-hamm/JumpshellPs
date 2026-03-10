param(
    [string]$ModuleRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$NoPull,
    [switch]$Skills,
    [switch]$Mcps,
    [switch]$Modules,
    [switch]$Applications
)

# Skip installation checks during module import - only run when explicitly called
if ($global:JumpshellPs_ImportInProgress) {
    return
}

# Check if we're already running PowerShell 7, if not launch it
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Launching PowerShell 7..." -ForegroundColor Yellow
    & "C:\Program Files\PowerShell\7\pwsh.exe"
}
else {
    Write-Host "Already running PowerShell 7" -ForegroundColor Green
}

$moduleParentPath = if ($ModulePath) { $ModulePath } else { Split-Path -Parent $ModuleRoot }
if (-not $NoPull -and -not (Test-Path (Join-Path $moduleParentPath 'JumpshellPs'))) {
    Push-Location $moduleParentPath
    try {
        git clone https://github.com/jeff-hamm/JumpshellPs.git
    }
    finally {
        Pop-Location
    }
}

$installArgs = @{ ModuleRoot = $ModuleRoot }
if ($Skills)       { $installArgs['Skills']       = $true }
if ($Mcps)         { $installArgs['Mcps']         = $true }
if ($Modules)      { $installArgs['Modules']      = $true }
if ($Applications) { $installArgs['Applications'] = $true }

& (Join-Path $PSScriptRoot 'Install\Install.ps1') @installArgs

# Import JumpshellPs module if not already imported or being imported
# Skip this during module load (when dot-sourced from .psm1) to avoid recursion
$jumpshellModule = Get-Module -Name "JumpshellPs" -ErrorAction SilentlyContinue
$isCurrentlyImporting = $global:JumpshellPs_ImportInProgress -eq $true

if (-not $isCurrentlyImporting -and -not $jumpshellModule) {
    Write-Host "Importing JumpshellPs module..." -ForegroundColor Cyan
    Import-Module (Join-Path $ModuleRoot 'JumpShellPs.psd1') -Force
} elseif ($jumpshellModule) {
    Write-Debug "JumpshellPs module already imported (version: $($jumpshellModule.Version))"
} else {
    Write-Debug "Module import in progress, skipping duplicate import"
}