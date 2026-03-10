function Get-VSCodeWorkspaceStorage {
    <#
    .SYNOPSIS
    Gets the VS Code workspace storage folder(s) for a given workspace path or URI.
    
    .DESCRIPTION
    Calculates the workspace storage ID using the same algorithm VS Code uses:
    - For local paths: MD5(lowercase_path + creation_time_ms)
    - For remote URIs: MD5(uri_string)
    
    Returns the full path(s) to workspace storage folders.
    
    .PARAMETER Path
    The workspace folder path (local file system path).
    
    .PARAMETER Uri
    The workspace folder URI (for remote workspaces, e.g., vscode-remote://...).
    
    .PARAMETER UserPath
    Optional. The VS Code User path. If not specified, uses Get-VSCodeUserPath.
    
    .PARAMETER All
    When set, returns all workspace storage folders for the path, regardless of creation time.
    Useful when a folder has been recreated or opened multiple times.
    
    .EXAMPLE
    Get-VSCodeWorkspaceStorage -Path "C:\Projects\MyProject"
    
    .EXAMPLE
    Get-VSCodeWorkspaceStorage -Uri "vscode-remote://dev-container+..."
    
    .EXAMPLE
    Get-VSCodeWorkspaceStorage -Path $PWD
    
    .EXAMPLE
    Get-VSCodeWorkspaceStorage -Path "C:\Projects\MyProject" -All
    # Returns all workspace storage folders for this path
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Mandatory = $true, Position = 0)]
        [string]$Path,
        
        [Parameter(ParameterSetName = 'Uri', Mandatory = $true)]
        [string]$Uri,
        
        [string]$UserPath,
        
        [Parameter(ParameterSetName = 'Path')]
        [switch]$All
    )
    
    $userPathsToSearch = @()

    if ($PSBoundParameters.ContainsKey('UserPath') -and $UserPath) {
        $userPathsToSearch += $UserPath
    }
    else {
        $detectedUserPath = Resolve-VscodeProfile
        if ($detectedUserPath) {
            $userPathsToSearch += $detectedUserPath
        }

        $defaultUserCandidates = @(
            (Join-Path $env:APPDATA "Code\User"),
            (Join-Path $env:APPDATA "Code - Insiders\User"),
            (Join-Path $env:APPDATA "Cursor\User"),
            (Join-Path $env:APPDATA "VSCodium\User")
        )

        foreach ($candidate in $defaultUserCandidates) {
            if (Test-Path $candidate) {
                $userPathsToSearch += $candidate
            }

            $profilesRoot = Join-Path $candidate "profiles"
            if (Test-Path $profilesRoot) {
                $userPathsToSearch += (Get-ChildItem $profilesRoot -Directory | ForEach-Object { $_.FullName })
            }
        }
    }

    $workspaceStoragePaths = @()
    foreach ($userPathCandidate in ($userPathsToSearch | Select-Object -Unique)) {
        $storagePath = Join-Path $userPathCandidate "workspaceStorage"
        if (Test-Path $storagePath) {
            $workspaceStoragePaths += $storagePath
        }
    }

    if ($workspaceStoragePaths.Count -eq 0) {
        if ($UserPath) {
            Write-Warning "Workspace storage path not found: $(Join-Path $UserPath 'workspaceStorage')"
        }
        else {
            Write-Warning "No workspace storage paths found under VS Code user directories"
        }
        return
    }

    function Normalize-LocalWorkspacePath {
        param([string]$InputPath)

        if (-not $InputPath) { return $null }

        $normalized = $InputPath.Replace('/', '\')

        # VS Code normalizes drive letter to lowercase in many places
        if ($normalized.Length -ge 2 -and $normalized[1] -eq ':' -and [char]::IsLetter($normalized[0])) {
            $normalized = $normalized.Substring(0, 1).ToLowerInvariant() + $normalized.Substring(1)
        }

        # Trim trailing slash for non-root paths
        if ($normalized.Length -gt 3) {
            $normalized = $normalized.TrimEnd('\')
        }

        return $normalized
    }

    function Convert-WorkspaceFileUriToPath {
        param([string]$WorkspaceUri)

        if (-not $WorkspaceUri) { return $null }
        if ($WorkspaceUri -notmatch '^file:///') { return $null }

        $decoded = $WorkspaceUri -replace '^file:///', ''
        $decoded = [System.Uri]::UnescapeDataString($decoded)
        return Normalize-LocalWorkspacePath $decoded
    }

    function Test-IsPathRelated {
        param(
            [string]$CandidatePath,
            [string]$QueryPath,
            [bool]$QueryIsDirectory
        )

        if (-not $CandidatePath -or -not $QueryPath) { return $false }

        $candidate = $CandidatePath.ToLowerInvariant()
        $targetPathLower = $QueryPath.ToLowerInvariant()

        # Exact match
        if ($candidate -eq $targetPathLower) { return $true }

        # Input is inside candidate (input is a subpath of the workspace)
        if ($targetPathLower.StartsWith($candidate + '\')) { return $true }

        # Candidate is inside input (workspace is a subpath of the requested folder)
        if ($QueryIsDirectory -and $candidate.StartsWith($targetPathLower + '\')) { return $true }

        return $false
    }

    function Test-UriRelatedToPath {
        param(
            [string]$WorkspaceUri,
            [string]$QueryPath
        )

        if (-not $WorkspaceUri -or -not $QueryPath) { return $false }

        $uriNorm = [System.Uri]::UnescapeDataString($WorkspaceUri).ToLowerInvariant()
        $inputForward = ($QueryPath -replace '\\', '/').ToLowerInvariant()

        if ($uriNorm.Contains($inputForward)) {
            return $true
        }

        # Also support WSL-style local path projection: C:\foo\bar -> /mnt/c/foo/bar
        if ($QueryPath.Length -gt 3 -and $QueryPath[1] -eq ':' -and $QueryPath[2] -eq '\') {
            $drive = $QueryPath.Substring(0, 1).ToLowerInvariant()
            $rest = ($QueryPath.Substring(3) -replace '\\', '/').ToLowerInvariant()
            $wslPath = "/mnt/$drive/$rest"
            if ($uriNorm.Contains($wslPath)) {
                return $true
            }
        }

        return $false
    }

    function Get-MatchingWorkspaceStorageFolders {
        param(
            [string]$ResolvedPath,
            [bool]$InputIsDirectory,
            [switch]$IncludeRelated
        )

        $allFolders = @()
        foreach ($storagePath in $workspaceStoragePaths) {
            $allFolders += Get-ChildItem $storagePath -Directory
        }

        $allFolders = @($allFolders | Group-Object FullName | ForEach-Object { $_.Group[0] })
        $matchingFolders = @()
        $seen = @{}

        foreach ($folder in $allFolders) {
            $workspaceJsonPath = Join-Path $folder.FullName "workspace.json"
            if (-not (Test-Path $workspaceJsonPath)) {
                continue
            }

            try {
                $workspaceJson = Get-Content $workspaceJsonPath -Raw | ConvertFrom-Json
            }
            catch {
                continue
            }

            $entries = @()
            if ($workspaceJson.folder) { $entries += [string]$workspaceJson.folder }
            if ($workspaceJson.workspace) { $entries += [string]$workspaceJson.workspace }

            $isMatch = $false

            foreach ($entry in $entries) {
                if ([string]::IsNullOrWhiteSpace($entry)) {
                    continue
                }

                $storedLocalPath = Convert-WorkspaceFileUriToPath $entry

                if ($storedLocalPath) {
                    if ($IncludeRelated) {
                        if (Test-IsPathRelated -CandidatePath $storedLocalPath -QueryPath $ResolvedPath -QueryIsDirectory:$InputIsDirectory) {
                            $isMatch = $true
                            break
                        }
                    }
                    elseif ($storedLocalPath -ieq $ResolvedPath) {
                        $isMatch = $true
                        break
                    }
                }
                elseif ($IncludeRelated) {
                    if (Test-UriRelatedToPath -WorkspaceUri $entry -QueryPath $ResolvedPath) {
                        $isMatch = $true
                        break
                    }
                }
            }

            if ($isMatch -and -not $seen.ContainsKey($folder.FullName)) {
                $matchingFolders += $folder
                $seen[$folder.FullName] = $true
            }
        }

        return @($matchingFolders | Sort-Object LastWriteTime -Descending)
    }
    
    # Calculate the workspace ID
    $workspaceId = $null
    
    if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        # Remote workspace: MD5(uri_string)
        $workspaceId = Get-MD5Hash $Uri

        # First try direct ID lookup
        $folders = @()
        foreach ($storagePath in $workspaceStoragePaths) {
            $pattern = Join-Path $storagePath "$workspaceId*"
            $folders += Get-Item $pattern -ErrorAction SilentlyContinue
        }

        $folders = @($folders | Group-Object FullName | ForEach-Object { $_.Group[0] })
        if ($folders) {
            return $folders
        }

        # Fallback: search workspace.json entries for URI match
        $allFolders = @()
        foreach ($storagePath in $workspaceStoragePaths) {
            $allFolders += Get-ChildItem $storagePath -Directory
        }

        $allFolders = @($allFolders | Group-Object FullName | ForEach-Object { $_.Group[0] })
        $uriTarget = [System.Uri]::UnescapeDataString($Uri)
        $uriFolders = @()

        foreach ($folder in $allFolders) {
            $workspaceJsonPath = Join-Path $folder.FullName "workspace.json"
            if (-not (Test-Path $workspaceJsonPath)) { continue }

            try {
                $workspaceJson = Get-Content $workspaceJsonPath -Raw | ConvertFrom-Json
                $entries = @()
                if ($workspaceJson.folder) { $entries += [string]$workspaceJson.folder }
                if ($workspaceJson.workspace) { $entries += [string]$workspaceJson.workspace }

                foreach ($entry in $entries) {
                    if ($entry -eq $Uri -or [System.Uri]::UnescapeDataString($entry) -eq $uriTarget) {
                        $uriFolders += $folder
                        break
                    }
                }
            }
            catch {
                # Ignore parse errors
            }
        }

        if ($uriFolders.Count -gt 0) {
            return @($uriFolders | Sort-Object LastWriteTime -Descending)
        }

        Write-Warning "No workspace storage found for URI: $Uri"
        return $null
    }
    else {
        # Local workspace lookup with related-path support
        try {
            $pathItem = Get-Item -LiteralPath $Path -ErrorAction Stop
        }
        catch {
            Write-Error "Path not found: $Path"
            return $null
        }

        $fullPath = Normalize-LocalWorkspacePath $pathItem.FullName
        $isDirectory = [bool]$pathItem.PSIsContainer

        # If -All switch is set, include all related workspaces (exact, ancestor, descendant, URI-related)
        if ($All) {
            $relatedFolders = Get-MatchingWorkspaceStorageFolders -ResolvedPath $fullPath -InputIsDirectory:$isDirectory -IncludeRelated

            if ($relatedFolders.Count -gt 0) {
                return $relatedFolders
            }

            Write-Warning "No workspace storage folders found for path: $fullPath"
            return $null
        }

        # First try exact workspace.json match (works for .code-workspace paths and changed hashing schemes)
        $exactFolders = Get-MatchingWorkspaceStorageFolders -ResolvedPath $fullPath -InputIsDirectory:$isDirectory
        if ($exactFolders.Count -gt 0) {
            return $exactFolders[0]
        }

        # Fallback to classic local hash: MD5(lowercase_path + ctime_ms)
        $ctimeMs = [Math]::Floor(($pathItem.CreationTimeUtc - [DateTime]'1970-01-01').TotalMilliseconds)
        $hashInput = "$fullPath$ctimeMs"
        $workspaceId = Get-MD5Hash $hashInput
    }
    
    # Find workspace storage folders matching this ID
    $folders = @()
    $searchedPatterns = @()

    foreach ($storagePath in $workspaceStoragePaths) {
        $pattern = Join-Path $storagePath "$workspaceId*"
        $searchedPatterns += $pattern
        $folders += Get-Item $pattern -ErrorAction SilentlyContinue
    }

    $folders = @($folders | Group-Object FullName | ForEach-Object { $_.Group[0] })
    
    if ($folders) {
        return $folders
    }
    else {
        # Final fallback for Path mode: pick best related match (parent/child workspace)
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            try {
                $pathItem = Get-Item -LiteralPath $Path -ErrorAction Stop
                $fullPath = Normalize-LocalWorkspacePath $pathItem.FullName
                $isDirectory = [bool]$pathItem.PSIsContainer

                $relatedFolders = Get-MatchingWorkspaceStorageFolders -ResolvedPath $fullPath -InputIsDirectory:$isDirectory -IncludeRelated
                if ($relatedFolders.Count -gt 0) {
                    return $relatedFolders[0]
                }
            }
            catch {
                # Ignore fallback errors
            }
        }

        Write-Warning "No workspace storage found for ID: $workspaceId"
        Write-Verbose "Searched for patterns: $($searchedPatterns -join ', ')"
        return $null
    }
}

function Get-MD5Hash {
    <#
    .SYNOPSIS
    Computes MD5 hash of a string.
    
    .PARAMETER InputString
    The string to hash.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )
    
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hashBytes = $md5.ComputeHash($bytes)
    
    # Convert to hex string
    $hash = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
    
    return $hash
}

function Get-VSCodeWorkspaceStorageFromGlobal {
    <#
    .SYNOPSIS
    Gets workspace storage folders for all workspaces found in VS Code's global storage.
    
    .DESCRIPTION
    Reads the global storage.json to find all workspace URIs and returns their storage folders.
    
    .PARAMETER UserPath
    Optional. The VS Code User path. If not specified, uses Get-VSCodeUserPath.
    
    .EXAMPLE
    Get-VSCodeWorkspaceStorageFromGlobal | Select-Object Name, @{n='Workspace';e={$_.workspace}}
    #>
    
    param(
        [string]$UserPath
    )
    
    if (-not $UserPath) {
        $UserPath = Get-VSCodeUserPath
    }
    
    $globalStoragePath = Join-Path $UserPath "globalStorage\storage.json"
    if (-not (Test-Path $globalStoragePath)) {
        Write-Warning "Global storage not found: $globalStoragePath"
        return
    }
    
    try {
        $storage = Get-Content $globalStoragePath -Raw | ConvertFrom-Json
        
        # Look for workspace entries
        $storage.PSObject.Properties | Where-Object { $_.Name -like '*folderUri*' -or $_.Name -like '*workspace*' } | ForEach-Object {
            $uri = $_.Value
            if ($uri -and $uri -is [string]) {
                $folders = Get-VSCodeWorkspaceStorage -Uri $uri -UserPath $UserPath
                if ($folders) {
                    $folders | Add-Member -NotePropertyName 'WorkspaceUri' -NotePropertyValue $uri -PassThru
                }
            }
        }
    }
    catch {
        Write-Error "Failed to parse global storage: $_"
    }
}

