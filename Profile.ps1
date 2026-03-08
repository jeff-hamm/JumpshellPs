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
        
        [Parameter(ParameterSetName = "Default")]
        [switch]$Default,
        
        [Parameter(ParameterSetName = "MinimalHashtable", Mandatory=$true)]
        [hashtable]$Replacements,
        
        [Parameter(ParameterSetName = "MinimalString")]
        [string]$Location,
        
        [Parameter(ParameterSetName = "MinimalString")]
        [string]$Alias,
        [Parameter(ParameterSetName = "MinimalHashtable")]
        [Parameter(ParameterSetName = "MinimalString")]
        $AliasStyle = "$($PSStyle.Italic)$($PSStyle.Foreground.Cyan)",
        [Parameter(ParameterSetName = "Default")]
        $Style = "$($PSStyle.Italic)$($PSStyle.Foreground.Cyan)"
    )
    
    $setPromptImplementation = {
        param([scriptblock]$PromptImpl)

        $hasVsCodePromptWrapper =
            (Test-Path variable:global:__VSCodeState) -and
            ($global:__VSCodeState -is [hashtable]) -and
            $global:__VSCodeState.ContainsKey('OriginalPrompt')

        if ($hasVsCodePromptWrapper) {
            # Preserve VS Code's shell integration wrapper and replace only the original prompt renderer.
            $global:__VSCodeState.OriginalPrompt = $PromptImpl
            return
        }

        Set-Item -Path function:global:prompt -Value $PromptImpl
    }

    if ($Default) {
        & $setPromptImplementation {
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
    $global:promptStyle = $Style
    
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
    
    & $setPromptImplementation {
        $location = Get-Location
        $path = $location.Path

        # Apply custom replacements first
        $promptText = $null
        foreach ($replacement in $global:replaceMents) {
            $targetPath = $replacement.Key
            $alias = $replacement.Value

            if ($path -like "$targetPath*") {
                $relativePath = $path.Substring($targetPath.Length).TrimStart('\')
                $path = "$global:promptAliasStyle${alias}$($PSStyle.Reset)"
                if ($relativePath) {
                    $path += "\$relativePath"
                }
                $promptText = "$path> "
                break
            }
        }
        if (-not $promptText) {
            $promptText = "$global:promptStyle${path}$($PSStyle.Reset)> "
        }

        $promptText
    }
}

function Resolve-WorkspacePath {
    $currentPath = (Get-Location).Path
    if (-not $currentPath) {
        return $null
    }

    $currentPath = $currentPath.TrimEnd('\')
    $workspaceCandidates = @()

    if (Get-Command Get-VSCodeWorkspaceStorage -ErrorAction SilentlyContinue) {
        $storageFolders = @(Get-VSCodeWorkspaceStorage -Path $currentPath -All -ErrorAction SilentlyContinue)

        foreach ($storageFolder in $storageFolders) {
            if (-not $storageFolder.FullName) { continue }
            $workspaceJsonPath = Join-Path $storageFolder.FullName "workspace.json"
            if (-not (Test-Path $workspaceJsonPath)) {
                continue
            }

            try {
                $workspaceJson = Get-Content -LiteralPath $workspaceJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                continue
            }

            if (-not $workspaceJson.folder) {
                continue
            }

            $workspaceUri = [string]$workspaceJson.folder
            if ($workspaceUri -notmatch '^file:///') {
                continue
            }

                $workspacePathSegment = ($workspaceUri -replace '^file:///', '')
                $decodedPath = [System.Uri]::UnescapeDataString($workspacePathSegment)
            $decodedPath = ($decodedPath -replace '/', '\').TrimEnd('\')

            if ($decodedPath.Length -ge 2 -and $decodedPath[1] -eq ':') {
                $decodedPath = $decodedPath.Substring(0, 1).ToUpperInvariant() + $decodedPath.Substring(1)
            }

            if ($decodedPath) {
                $workspaceCandidates += $decodedPath
            }
        }
    }

    $workspaceCandidates = @($workspaceCandidates | Select-Object -Unique)
    $currentLower = $currentPath.ToLowerInvariant()
    $bestMatch = $null
    $bestLength = -1

    foreach ($candidate in $workspaceCandidates) {
        $candidateLower = $candidate.ToLowerInvariant()
        if ($currentLower -eq $candidateLower -or $currentLower.StartsWith("$candidateLower\\")) {
            if ($candidate.Length -gt $bestLength) {
                $bestMatch = $candidate
                $bestLength = $candidate.Length
            }
        }
    }

    if ($bestMatch) {
        return $bestMatch
    }

    $scanPath = $currentPath
    while ($scanPath) {
        if (
            (Test-Path (Join-Path $scanPath ".vscode")) -or
            (Test-Path (Join-Path $scanPath ".git")) -or
            (Get-ChildItem -LiteralPath $scanPath -Filter "*.code-workspace" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        ) {
            return $scanPath
        }

        $parentPath = Split-Path -Path $scanPath -Parent
        if (-not $parentPath -or $parentPath -eq $scanPath) {
            break
        }

        $scanPath = $parentPath
    }

    return $currentPath
}



function Configure-Profile {
    $Env:ProfilePath = $global:ProfilePath = (Split-Path $PROFILE)
    $global:ProfileHistory = (Get-PSReadlineOption).HistorySavePath
    try {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -MaximumHistoryCount 32767 -ErrorAction Stop
    } catch {
        # Ignore PSReadLine prediction errors in non-interactive / non-VT terminals
    }

    $isVsCodeSession = $false
    if (Get-Command Is-VsCode -ErrorAction SilentlyContinue) {
        $isVsCodeSession = Is-VsCode
    }

    if ($isVsCodeSession) {
        $workspacePath = Resolve-WorkspacePath
        $Env:WorkspacePath = $global:WS = $global:WorkspacePath = $workspacePath
        Set-Prompt
    }
}
