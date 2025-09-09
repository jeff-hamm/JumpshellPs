$ModulePath=($env:PSModulePath -split ';' | Where-Object { $_ -like "$HOME*" })

function InitialSetup() {
    winget install Git.Git
    cd $ModulePath
    git clone https://github.com/jeff-hamm/JumpshellPs.git
    & "$ModulePath\JumpshellPs\Install.ps1"
    & "C:\Program Files\PowerShell\7\pwsh.exe"
    Import-Module .\JumpshellPs\JumpShellPs.psm1
}