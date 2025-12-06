
# Copilot
# Create a PowerShell function named Set-LogLevel that takes a parameter $Level with valid values "Verbose", "Debug", "Information", "Warning", and "Error". The function should set the appropriate log preference variables ($VerbosePreference, $DebugPreference, $InformationPreference, $WarningPreference, and $ErrorActionPreference) based on the specified log level. Ensure that the specified log level and all higher levels are visible by only overwriting the current value if it is set to SilentlyContinue or Ignore. Use the ActionPreference enum values instead of strings.

function From-Shell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        # Replace backslash continuation with backtick continuation
        $newline = "`r`n"
        $result = $InputString -replace '\\\s*\r?\n', " ``$newline"
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function To-Shell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        $result = $InputString -replace '`\s+', " `\r`n"
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function Convert-Multiline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString,
        [switch]$Exec
    )
    
    process {
        $result = $null
        # Check if the string contains shell-style continuation (backslash followed by newline)
        if ($InputString -match '\\[\s]*[\r]?[\n]') {
            # Convert from shell to PowerShell
            $result = From-Shell -InputString $InputString
        }
        # Check if the string contains PowerShell-style continuation (backtick followed by whitespace)
        elseif ($InputString -match '`[\s]+') {
            # Convert from PowerShell to shell
            $result = To-Shell -InputString $InputString
        }
        else {
            # No continuation characters found, return as-is
            $result = $InputString
        }
        
        if ($Exec) {
            Write-Information "Executing: $result" -InformationAction Continue
            Invoke-Expression $result
        } else {
            $result
        }
    }
}

function Exec-Multiline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString
    )
    
    process {
        Convert-Multiline -InputString $InputString -Exec
    }
}

function Set-LogLevel {
    param (
        [ValidateSet("Verbose", "Debug", "Information", "Warning", "Error")]
        [string]$Level
    )

    $prefs = @{
        VerbosePreference = $global:VerbosePreference
        DebugPreference = $global:DebugPreference
        InformationPreference = $global:InformationPreference
        WarningPreference = $global:WarningPreference
        ErrorActionPreference = $global:ErrorActionPreference
    }

    $levels = @("Verbose", "Debug", "Information", "Warning", "Error")
    $index = $levels.IndexOf($Level)

    for ($i = $index; $i -lt $levels.Count; $i++) {
        $key = "$($levels[$i])Preference"
        Write-Debug "Checking $key and index $i"
        if ($prefs[$key] -eq "SilentlyContinue" -or $prefs[$key] -eq "Ignore") {
            Set-Variable -Name $key -Value "Continue" -Scope Global
            Write-Debug "Setting $key to Continue"
        }
    }
    for ($i = 0; $i -lt $index; $i++) {
        $key = "$($levels[$i])Preference"
        Write-Debug "Checking $key and index $i"
        if ($prefs[$key] -ne "SilentlyContinue" -and $prefs[$key] -ne "Ignore") {
            Write-Debug "Setting $key to SilentlyContinue"
            Set-Variable -Name $key -Value "Continue" -Scope Global
        }
    }
}



function Format-Size() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [double]$SizeInBytes
    )
    switch ([math]::Max($SizeInBytes, 0)) {
        { $_ -ge 1PB } { "{0:N2}PB" -f ($SizeInBytes / 1PB); break }
        { $_ -ge 1TB } { "{0:N2}TB" -f ($SizeInBytes / 1TB); break }
        { $_ -ge 1GB } { "{0:N2}GB" -f ($SizeInBytes / 1GB); break }
        { $_ -ge 1MB } { "{0:N2}MB" -f ($SizeInBytes / 1MB); break }
        { $_ -ge 1KB } { "{0:N2}KB" -f ($SizeInBytes / 1KB); break }
        default { "$SizeInBytes" }
    }
}


function ToSplatString([hashtable]$SplatArgs) {
    $SplatArgs.GetEnumerator() | Select -Property @{ expr={"-" + $_.Name + " " + $_.Value}; name="splatted" }  | select -ExpandProperty splatted
}

function Make-Link(
    [string]$Operation = "SymbolicLink",
    [Parameter(Position = 0, Mandatory = $true)]
    $link, 
    [Parameter(Position = 1, Mandatory = $true)]$target) {
    if ($Operation -eq "/D") {
        $Operation = "SymbolicLink"
    }
    elseif ($Operation -eq "/H") {
        $Operation = "HardLink"
    }
    elseif ($Operation -eq "/J") {
        $Operation = "Junction"
    }
    ni -Path $link -ItemType "$Operation"	-Value $target

}

function Make-Ln($Target, $Link, [Alias("s")][switch]$Symbolic, [Alias("f")][switch]$Force) {
    if ($Symbolic) {
        Make-Link -Operation "SymbolicLink" -link $Link -target $Target
    }
    else {
        Make-Link -Operation "HardLink" -link $Link -target $Target
    }   
}

New-Alias -Name "mklink" -Value "Make-Link" -ErrorAction SilentlyContinue

New-Alias -Name "ln" -Value "Make-Ln" -ErrorAction SilentlyContinue

New-Alias -Name "multiline" -Value "Convert-Multiline" -ErrorAction SilentlyContinue
New-Alias -Name "multiline-exec" -Value "Exec-Multiline" -ErrorAction SilentlyContinue

# Export functions and aliases (only when used as a module)
# Export-ModuleMember -Function From-Shell, To-Shell, Convert-Multiline, Exec-Multiline, Set-LogLevel, Format-Size, ToSplatString, Make-Link, Make-Ln
# Export-ModuleMember -Alias mklink, ln, multiline
