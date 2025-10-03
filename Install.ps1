param(
    [string]$ModuleRoot = $PSScriptRoot
)

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
$jumpshellModule = Get-Module -Name "JumpshellPs" -ErrorAction SilentlyContinue
$isCurrentlyImporting = $global:JumpshellPs_ImportInProgress -eq $true

if (-not $jumpshellModule -and -not $isCurrentlyImporting) {
    Write-Host "Importing JumpshellPs module..." -ForegroundColor Cyan
    Import-Module "$ModulePath\JumpshellPs\JumpshellPs.psm1" -Force
} elseif ($jumpshellModule) {
    Write-Debug "JumpshellPs module already imported (version: $($jumpshellModule.Version))"
} else {
    Write-Debug "Module import in progress, skipping duplicate import"
}