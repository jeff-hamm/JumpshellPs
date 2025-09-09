function Ensure-Module($Name, [switch]$Update, $Scope = "CurrentUser", [switch]$Clobber, [switch]$Confirm, [switch]$Force) {
    if ($Update) {
        Update-Module $Name -Force:$(!$Confirm) -AllowClobber:$Clobber -Scope "$Scope"
        Reload-Module "$Name"
    }
    if ($Force -or -not (Get-Module -Name $Name)) {
        Import-Module -Name "$Name" -Force:$Force
    }
}

function Reload-Module($Name) {
    Remove-Module -Name $Name -Force
}

function Command-Exists($command) {
    return (Get-Command $command -ErrorAction SilentlyContinue) -ne $null
}

$global:ValidatedPackages = @{}
function Use-Package(
    [Parameter(Mandatory = $true)]    
    $Package, [switch]$Upgrade) {
    if ($ValidatedPackages[$package]) {
        return
    }
    if (!$Upgrade) {
        winget list --id "$package"
        if ($?) {
            $ValidatedPackages[$package] = $true
            return
        }
    }
    winget install -e --id "$package" -h
}