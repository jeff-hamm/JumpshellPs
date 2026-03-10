# Network utilities for JumpShellPs

function Add-WSLPortForward {
    <#
    .SYNOPSIS
        Forwards a port from the host to WSL via localhost
    
    .DESCRIPTION
        Creates a port proxy rule to forward traffic from the Windows host to WSL.
        Useful for exposing WSL services to the local network when using NAT mode.
        Requires administrator privileges.
    
    .PARAMETER Port
        The port number to forward (both listen and connect port by default)
    
    .PARAMETER ListenPort
        The port to listen on (defaults to Port parameter)
    
    .PARAMETER ConnectPort
        The port to connect to on WSL (defaults to Port parameter)
    
    .PARAMETER ListenAddress
        The address to listen on (default: 0.0.0.0 for all interfaces)
    
    .PARAMETER ConnectAddress
        The address to connect to (default: 127.0.0.1 for localhost/WSL)
    
    .EXAMPLE
        Add-WSLPortForward -Port 8080
        Forwards port 8080 from all interfaces to WSL localhost:8080
    
    .EXAMPLE
        Add-WSLPortForward -ListenPort 80 -ConnectPort 8080
        Forwards port 80 on host to port 8080 on WSL
    
    .EXAMPLE
        Add-WSLPortForward -Port 3000 -ListenAddress 192.168.1.140
        Forwards port 3000 only on specific IP to WSL
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [int]$ListenPort,

        [Parameter(Mandatory = $false)]
        [int]$ConnectPort,

        [Parameter(Mandatory = $false)]
        [string]$ListenAddress = "0.0.0.0",

        [Parameter(Mandatory = $false)]
        [string]$ConnectAddress = "127.0.0.1"
    )

    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This command requires administrator privileges. Run PowerShell as Administrator."
        return
    }

    # Handle port parameter logic
    if ($Port) {
        if (-not $ListenPort) { $ListenPort = $Port }
        if (-not $ConnectPort) { $ConnectPort = $Port }
    }

    if (-not $ListenPort -or -not $ConnectPort) {
        Write-Error "Either -Port or both -ListenPort and -ConnectPort must be specified"
        return
    }

    try {
        # Add the port proxy rule
        $cmd = "netsh interface portproxy add v4tov4 listenport=$ListenPort listenaddress=$ListenAddress connectport=$ConnectPort connectaddress=$ConnectAddress"
        Write-Verbose "Executing: $cmd"
        
        Invoke-Expression $cmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Port forward added: ${ListenAddress}:${ListenPort} -> ${ConnectAddress}:${ConnectPort}" -ForegroundColor Green
        } else {
            Write-Error "Failed to add port forward (exit code: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Error "Failed to add port forward: $_"
    }
}

function Remove-WSLPortForward {
    <#
    .SYNOPSIS
        Removes a WSL port forwarding rule
    
    .DESCRIPTION
        Removes a port proxy rule created by Add-WSLPortForward.
        Requires administrator privileges.
    
    .PARAMETER Port
        The listen port to remove
    
    .PARAMETER ListenAddress
        The listen address (default: 0.0.0.0)
    
    .EXAMPLE
        Remove-WSLPortForward -Port 8080
        Removes the port forward for port 8080 on all interfaces
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [string]$ListenAddress = "0.0.0.0"
    )

    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This command requires administrator privileges. Run PowerShell as Administrator."
        return
    }

    try {
        $cmd = "netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=$ListenAddress"
        Write-Verbose "Executing: $cmd"
        
        Invoke-Expression $cmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Port forward removed: ${ListenAddress}:${Port}" -ForegroundColor Green
        } else {
            Write-Error "Failed to remove port forward (exit code: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Error "Failed to remove port forward: $_"
    }
}

function Get-WSLPortForward {
    <#
    .SYNOPSIS
        Lists all active WSL port forwarding rules
    
    .DESCRIPTION
        Shows all port proxy rules currently configured on the system.
    
    .EXAMPLE
        Get-WSLPortForward
        Displays all active port forwarding rules
    #>
    [CmdletBinding()]
    param()

    Write-Host "`nActive Port Forwarding Rules:" -ForegroundColor Cyan
    netsh interface portproxy show v4tov4
}
