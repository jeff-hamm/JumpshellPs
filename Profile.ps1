function View-PsHistory() {
    notepad (Get-PSReadlineOption).HistorySavePath
}
function Edit-PsHistory() {
    View-PsHistory
}
function View-PsProfile([switch]$File) {
    Edit-Profile -File:$File
}

function Edit-Profile([switch]$File) {
    if($File) {
        notepad $Profile
    } else {
        code (Split-Path $Profile -Resolve -Parent)
    }
}
function Set-Prompt {
    <#
    .SYNOPSIS
    Sets the PowerShell prompt to minimal or default style.
    
    .DESCRIPTION
    Configures the PowerShell prompt. Use -Minimal for a compact prompt with custom path replacements,
    or -Default to restore the standard PowerShell prompt.
    
    .PARAMETER Minimal
    Sets a minimal prompt that replaces the home directory with ~ and removes the "PS " prefix.
    Supports custom path replacements using drive-style notation (e.g., OD:\path).
    
    .PARAMETER Default
    Restores the default PowerShell prompt.
    
    .PARAMETER Replacements
    Hashtable of path replacements where key is the path and value is the drive letter.
    
    .PARAMETER Location
    Single path to replace (use with Alias parameter).
    
    .PARAMETER Alias
    Drive letter for the path replacement (use with Location parameter).
    
    .EXAMPLE
    Set-Prompt -Minimal
    
    .EXAMPLE
    Set-Prompt -Minimal -Replacements @{"C:\OneDrive" = "OD"; "C:\Projects" = "PRJ"}
    
    .EXAMPLE
    Set-Prompt -Minimal -Location "C:\OneDrive" -Alias "OD"
    
    .EXAMPLE
    Set-Prompt -Default
    #>
    param(
        [Parameter(ParameterSetName = "MinimalHashtable", Mandatory=$true)]
        [Parameter(ParameterSetName = "MinimalString", Mandatory=$true)]
        [switch]$Minimal,
        
        [Parameter(ParameterSetName = "Default", Mandatory=$true)]
        [switch]$Default,
        
        [Parameter(ParameterSetName = "MinimalHashtable", Mandatory=$true)]
        [hashtable]$Replacements,
        
        [Parameter(ParameterSetName = "MinimalString")]
        [string]$Location,
        
        [Parameter(ParameterSetName = "MinimalString")]
        [string]$Alias,
        [Parameter(ParameterSetName = "MinimalHashtable")]
        [Parameter(ParameterSetName = "MinimalString")]
        $AliasStyle = "$($PSStyle.Italic)$($PSStyle.Foreground.Cyan)"
    )
    
    if ($Default) {
        function global:prompt {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        }
        return
    }
    
    if (!($Replacements -is [hashtable])) {
        $Replacements = @{}
    }
    if($Location -and $Alias) {
        $Replacements[$Location] = $Alias
    }
    
    # Store alias color globally for the prompt function
    $global:promptAliasStyle = $AliasStyle
    
    # Build replacement array
    $global:replaceMents = @($Replacements.GetEnumerator() | 
        % { 
            @{ 
                Key = $_.Key.TrimEnd('\'); 
                Value = "$($_.Value.TrimEnd(':'))" 
            }
        } | 
        sort { $_.Key.Length } -Descending)
    
    # Add home directory replacement
    $global:replaceMents += @{ Key = $env:USERPROFILE.TrimEnd('\'); Value = "~" }
    
    function global:prompt {
        $location = Get-Location
        $path = $location.Path
        # Apply custom replacements first
        foreach ($replacement in $global:replaceMents) {
            $targetPath = $replacement.Key
            $alias = $replacement.Value
            
            if ($path -like "$targetPath*") {
                $relativePath = $path.Substring($targetPath.Length).TrimStart('\')
                $path = "$global:promptAliasStyle${alias}$($PSStyle.Reset)"
                if ($relativePath) {
                    $path += "\$relativePath"
                }
                return "$path> "
            }
        }
        # Return prompt without "PS " prefix
        "$path> "
    }
}



function Configure-Profile($Name) {
    $Env:ProfilePath = $global:ProfilePath = (Split-Path $PROFILE)
    $global:ProfileHistory = (Get-PSReadlineOption).HistorySavePath
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
    Set-PSReadLineOption -MaximumHistoryCount 32767 
    if ($Name -eq "vscode") {
        $Env:WorkspacePath = $global:WS = $global:WorkspacePath = $PWD
        Write-Host "$($PSStyle.Foreground.Cyan)`$ws$($PSStyle.Reset) = $WS"
        Set-Prompt -Minimal -Location "$PWD" -Alias "`ws"
    }
}
