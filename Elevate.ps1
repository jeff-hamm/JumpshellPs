<#
.SYNOPSIS
    Tests if the current user is running as administrator

.DESCRIPTION
    Returns $true if the current PowerShell session is running with administrator privileges.

.EXAMPLE
    if (Test-Admin) { Write-Host "Running as admin" }
#>
function Test-Admin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

<#
.SYNOPSIS
    Elevates and runs a command, scriptblock, or script file as administrator

.DESCRIPTION
    Executes a command, scriptblock, or script file with administrator privileges. 
    If already running as admin, executes directly in the current shell.
    Otherwise, spawns an elevated PowerShell process.

.PARAMETER Command
    The command to execute. Can be a string or scriptblock.

.PARAMETER File
    The path to a PowerShell script file to execute.

.PARAMETER ArgumentList
    Arguments to pass to the command or script.

.PARAMETER WorkingDirectory
    The working directory for the elevated process. Defaults to current directory.

.PARAMETER NoExit
    Keep the elevated PowerShell window open after completion.

.PARAMETER NoWait
    Don't wait for the elevated process to complete.

.PARAMETER NoExitKey
    Skip the "Press Enter to exit" prompt (default behavior waits for keypress).
    Only applies to Command parameter set when elevation is needed.

.EXAMPLE
    Invoke-Elevated -Command { Set-Service -Name "wuauserv" -StartupType Automatic }

.EXAMPLE
    Invoke-Elevated -Command "netsh advfirewall set allprofiles state on" -NoWait

.EXAMPLE
    Invoke-Elevated -File ".\Install.ps1" -ArgumentList @("-Force")

.EXAMPLE
    Invoke-Elevated { Get-Process } -NoExitKey
#>
function Invoke-Elevated {
    [CmdletBinding(DefaultParameterSetName = 'Command')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Command')]
        $Command,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Alias("Path", "ScriptPath")]
        [string]$File,
        
        [Parameter(Position = 1)]
        [Alias("ScriptArgs", "Args")]
        [object[]]$ArgumentList,
        
        [string]$WorkingDirectory,
        
        [switch]$NoExit,
        
        [switch]$NoWait,
        
        [Parameter(ParameterSetName = 'Command')]
        [switch]$NoExitKey
    )
    
    Write-Verbose "Invoke-Elevated called with ParameterSet: $($PSCmdlet.ParameterSetName)"
    
    # Handle File parameter set
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        $ResolvedFile = Resolve-Path $File -ErrorAction Stop
        
        # If already admin, run directly
        if (Test-Admin) {
            Write-Verbose "Invoke-Elevated: Already admin, running script directly"
            if ($ArgumentList) {
                return & $ResolvedFile @ArgumentList
            }
            else {
                return & $ResolvedFile
            }
        }
        
        # Need to elevate - build args for script file
        $PwshArgs = @("-File", $ResolvedFile)
        if ($ArgumentList) {
            $PwshArgs += $ArgumentList
        }
        
        return Start-ElevatedProcess -PwshArgs $PwshArgs -NoExit:$NoExit -Wait:(-not $NoWait) -WorkingDirectory $WorkingDirectory
    }
    
    # Handle Command parameter set
    Write-Verbose "  Command type: $($Command.GetType().Name)"
    Write-Verbose "  Command value: $Command"
    Write-Verbose "  ArgumentList: $ArgumentList"
    Write-Verbose "  WorkingDirectory: $WorkingDirectory"
    Write-Verbose "  NoExit: $NoExit"
    Write-Verbose "  NoWait: $NoWait"
    Write-Verbose "  NoExitKey: $NoExitKey"
    
    # If already admin, run directly
    if (Test-Admin) {
        Write-Verbose "Invoke-Elevated: Already admin, running command directly"
        
        # Change to working directory if specified
        $OriginalLocation = $null
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory) -and (Test-Path $WorkingDirectory)) {
            $OriginalLocation = $PWD.Path
            Set-Location $WorkingDirectory
        }
        
        try {
            if ($Command -is [scriptblock]) {
                if ($ArgumentList) {
                    return & $Command @ArgumentList
                }
                else {
                    return & $Command
                }
            }
            else {
                # String command - invoke via Invoke-Expression
                return Invoke-Expression $Command
            }
        }
        finally {
            # Restore original location
            if ($OriginalLocation) {
                Set-Location $OriginalLocation
            }
        }
    }
    
    # Need to elevate - build PowerShell arguments
    $PwshArgs = @()
    
    # Convert command to string
    if ($Command -is [scriptblock]) {
        Write-Verbose "  Converting scriptblock to string"
        $CommandString = $Command.ToString()
    }
    elseif ($Command -is [string]) {
        Write-Verbose "  Using string command directly"
        $CommandString = $Command
    }
    else {
        Write-Warning "  Command is neither scriptblock nor string, converting to string"
        $CommandString = $Command.ToString()
    }
    
    # Default behavior is ExitKey (wait for key press), unless NoExitKey is specified
    if (-not $NoExitKey) {
        Write-Verbose "  Default ExitKey behavior - using encoded command with NoExit and programmatic exit"
        
        # Create the wrapped command with error handling and exit prompt
        $WrappedCommand = @"
try {
    $CommandString
} catch {
    Write-Error `$_.Exception.Message
} finally {
    Write-Host ''
    `$null = Read-Host -Prompt 'Press Enter to exit'
}
exit
"@
        
        # Encode the command to avoid parsing issues with special characters
        $EncodedCommand = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($WrappedCommand))
        $PwshArgs += "-NoExit", "-EncodedCommand", $EncodedCommand
        Write-Verbose "  Using encoded command with explicit exit"
    }
    else {
        # NoExitKey specified - use normal command handling
        Write-Verbose "  NoExitKey specified - using normal command handling"
        
        # Add -NoExit if requested
        if ($NoExit) {
            $PwshArgs += "-NoExit"
            Write-Verbose "  Added -NoExit flag"
        }
        
        if (-not $ArgumentList -or $ArgumentList.Count -eq 0) {
            $PwshArgs += "-Command", $CommandString
            Write-Verbose "  Using -Command (no arguments)"
        }
        else {
            # Build the command with arguments inline
            $ArgsString = ($ArgumentList | ForEach-Object { 
                if ($_ -match '\s') { "`"$_`"" } else { $_ }
            }) -join ' '
            $PwshArgs += "-Command", "& { $CommandString } $ArgsString"
            Write-Verbose "  Using -Command with embedded arguments"
        }
    }
    
    Write-Verbose "Final PwshArgs: $($PwshArgs -join ' ')"
    
    return Start-ElevatedProcess -PwshArgs $PwshArgs -Wait:(-not $NoWait) -WorkingDirectory $WorkingDirectory
}

<#
.SYNOPSIS
    Low-level function that spawns an elevated PowerShell process

.DESCRIPTION
    Internal function that handles the actual process elevation using Start-Process
    with the RunAs verb. Prefer using Invoke-Elevated which handles the admin check
    and runs directly when possible.

.PARAMETER PwshArgs
    Arguments to pass to the elevated pwsh.exe process

.PARAMETER WorkingDirectory
    The working directory for the elevated process. Defaults to current directory.

.PARAMETER NoExit
    Keep the elevated PowerShell window open (adds -NoExit to args if not already present)

.PARAMETER Wait
    Wait for the elevated process to complete before returning

.OUTPUTS
    Returns $null after spawning the elevated process
    Returns $false if user cancelled the UAC prompt

.EXAMPLE
    Start-ElevatedProcess -PwshArgs @("-Command", "Get-Process") -Wait
#>
function Start-ElevatedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [object[]]$PwshArgs,
        
        [string]$WorkingDirectory,
        
        [switch]$NoExit,
        
        [switch]$Wait
    )
    
    Write-Verbose "Start-ElevatedProcess: Spawning elevated process"
    
    # Ensure WorkingDirectory is valid
    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $WorkingDirectory = $PWD.Path
    }
    
    # Verify working directory exists
    if (-not (Test-Path $WorkingDirectory -PathType Container)) {
        Write-Warning "Working directory '$WorkingDirectory' does not exist, using current directory"
        $WorkingDirectory = $PWD.Path
    }
    
    # Add -NoExit if requested and not already in args
    if ($NoExit -and $PwshArgs -notcontains "-NoExit") {
        $PwshArgs = @("-NoExit") + $PwshArgs
    }
    
    $StartProcessParams = @{
        FilePath         = "pwsh.exe"
        ArgumentList     = $PwshArgs
        Verb             = "RunAs"
        WorkingDirectory = $WorkingDirectory
        Wait             = $Wait
        PassThru         = $true
    }
    
    Write-Verbose "Calling Start-Process with:"
    Write-Verbose "  FilePath: pwsh.exe"
    Write-Verbose "  WorkingDirectory: '$WorkingDirectory'"
    Write-Verbose "  ArgumentList: $($PwshArgs -join ' ')"
    Write-Verbose "  Wait: $Wait"
    
    try {
        $process = Start-Process @StartProcessParams
        Write-Information "Elevated process started (PID: $($process.Id))"
        
        if ($Wait -and $process.ExitCode -ne 0) {
            Write-Warning "Elevated process exited with code: $($process.ExitCode)"
        }
    }
    catch [System.ComponentModel.Win32Exception] {
        if ($_.Exception.NativeErrorCode -eq 1223) {
            # User cancelled the UAC prompt
            Write-Warning "Elevation was cancelled by the user"
            return $false
        }
        throw
    }
    
    return $null
}