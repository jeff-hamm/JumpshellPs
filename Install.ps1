param(
    [string]$ModuleRoot = $PSScriptRoot
)

# Skip installation checks during module import - only run when explicitly called
if ($global:JumpshellPs_ImportInProgress) {
    return
}

$ModulePath = ($env:PSModulePath -split ';' | select -First 1)
if (-not (Test-Path "$ModulePath\JumpshellPs")) {
    pushd $ModulePath
    try {
        git clone https://github.com/jeff-hamm/JumpshellPs.git
    }
    finally {
        popd
    }
}
# Check if we're already running PowerShell 7, if not launch it
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Launching PowerShell 7..." -ForegroundColor Yellow
    & "C:\Program Files\PowerShell\7\pwsh.exe"
} else {
    Write-Host "Already running PowerShell 7" -ForegroundColor Green
}

& (Join-Path $PSScriptRoot 'Install\Install.ps1') -ModuleRoot $PSScriptRoot

# Import JumpshellPs module if not already imported or being imported
# Skip this during module load (when dot-sourced from .psm1) to avoid recursion
$jumpshellModule = Get-Module -Name "JumpshellPs" -ErrorAction SilentlyContinue
$isCurrentlyImporting = $global:JumpshellPs_ImportInProgress -eq $true

if (-not $isCurrentlyImporting -and -not $jumpshellModule) {
    Write-Host "Importing JumpshellPs module..." -ForegroundColor Cyan
    Import-Module "$ModulePath\JumpshellPs\JumpshellPs.psm1" -Force
} elseif ($jumpshellModule) {
    Write-Debug "JumpshellPs module already imported (version: $($jumpshellModule.Version))"
} else {
    Write-Debug "Module import in progress, skipping duplicate import"
}