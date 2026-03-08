function Get-VSCodeChatEditingSessions {
    <#
    .SYNOPSIS
    Gets all chat editing sessions for a workspace path.
    
    .DESCRIPTION
    Searches all workspace storage folders associated with a path and returns information
    about each chat editing session found in the chatEditingSessions directory.
    Chat editing sessions track file modifications made during Copilot chat interactions.
    
    .PARAMETER Path
    The workspace folder path. Defaults to current directory ($pwd).
    
    .PARAMETER SessionId
    Optional. Filter to a specific session ID (matches chat session ID).
    
    .EXAMPLE
    Get-VSCodeChatEditingSessions
    # Gets all editing sessions for current workspace
    
    .EXAMPLE
    Get-VSCodeChatEditingSessions | Where-Object FileCount -gt 3
    # Filter sessions that modified more than 3 files
    
    .EXAMPLE
    $chatSession = Get-VSCodeChatSessions | Select-Object -First 1
    Get-VSCodeChatEditingSessions -SessionId $chatSession.SessionId
    # Find editing session matching a chat session
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = $pwd.Path,
        
        [Parameter(Mandatory=$false)]
        [string]$SessionId
    )
    
    # Get all workspace storage folders for this path
    Write-Verbose "Finding workspace storage folders for: $Path"
    $storageFolders = Get-VSCodeWorkspaceStorage -Path $Path -All
    
    if (-not $storageFolders) {
        Write-Warning "No workspace storage folders found for: $Path"
        return
    }
    
    $sessions = @()
    
    foreach ($folder in $storageFolders) {
        $editingSessionsPath = Join-Path $folder.FullName "chatEditingSessions"
        
        if (-not (Test-Path $editingSessionsPath)) {
            Write-Verbose "No chatEditingSessions folder in: $($folder.Name)"
            continue
        }
        
        $sessionDirs = Get-ChildItem -Path $editingSessionsPath -Directory
        
        # Filter by SessionId if specified
        if ($SessionId) {
            $sessionDirs = $sessionDirs | Where-Object { $_.Name -eq $SessionId }
        }
        
        foreach ($sessionDir in $sessionDirs) {
            $stateFile = Join-Path $sessionDir.FullName "state.json"
            
            if (-not (Test-Path $stateFile)) {
                Write-Verbose "No state.json in session: $($sessionDir.Name)"
                continue
            }
            
            try {
                $stateInfo = Get-Item $stateFile
                
                # Parse state.json for metadata
                $state = Get-Content $stateFile -Raw | ConvertFrom-Json
                
                # Get unique files from operations
                $modifiedFiles = @()
                if ($state.timeline.operations) {
                    $modifiedFiles = $state.timeline.operations | 
                        Select-Object -ExpandProperty uri -ErrorAction SilentlyContinue | 
                        Select-Object -ExpandProperty fsPath -ErrorAction SilentlyContinue -Unique
                }
                
                # Get unique request IDs (correlate to chat messages)
                $requestIds = @()
                if ($state.timeline.operations) {
                    $requestIds = $state.timeline.operations | 
                        Select-Object -ExpandProperty requestId -Unique
                }
                
                # Count content files (file snapshots)
                $contentsPath = Join-Path $sessionDir.FullName "contents"
                $contentFileCount = 0
                if (Test-Path $contentsPath) {
                    $contentFileCount = (Get-ChildItem $contentsPath -File).Count
                }
                
                $session = [PSCustomObject]@{
                    SessionId       = $sessionDir.Name
                    StatePath       = $stateFile
                    SessionPath     = $sessionDir.FullName
                    StorageFolder   = $folder.Name
                    WorkspacePath   = $Path
                    LastModified    = $stateInfo.LastWriteTime
                    StateFileSize   = $stateInfo.Length
                    FileCount       = $modifiedFiles.Count
                    OperationCount  = $state.timeline.operations.Count
                    SnapshotCount   = $contentFileCount
                    RequestCount    = $requestIds.Count
                    Version         = $state.version
                    CurrentEpoch    = $state.timeline.currentEpoch
                }
                
                # Add methods
                $session | Add-Member -MemberType ScriptMethod -Name GetFiles -Value {
                    Get-VSCodeChatEditingFiles -Session $this
                }
                
                $session | Add-Member -MemberType ScriptMethod -Name GetOperations -Value {
                    param([string]$FilePath, [string]$RequestId)
                    Get-VSCodeChatEditingOperations -Session $this -FilePath $FilePath -RequestId $RequestId
                }
                
                $session | Add-Member -MemberType ScriptMethod -Name GetChatSession -Value {
                    Get-VSCodeChatSessions -Path $this.WorkspacePath | 
                        Where-Object { $_.SessionId -eq $this.SessionId } | 
                        Select-Object -First 1
                }
                
                $sessions += $session
            }
            catch {
                Write-Verbose "Failed to parse editing session: $($sessionDir.FullName) - $_"
            }
        }
    }
    
    return $sessions | Sort-Object LastModified -Descending
}

function Get-VSCodeChatEditingFiles {
    <#
    .SYNOPSIS
    Gets the list of files modified in a chat editing session.
    
    .DESCRIPTION
    Parses the state.json of a chat editing session and returns information about
    each file that was modified, including operation counts and request associations.
    
    .PARAMETER Session
    A session object from Get-VSCodeChatEditingSessions (accepts pipeline input).
    
    .PARAMETER SessionId
    The session ID to query.
    
    .PARAMETER Path
    The workspace folder path. Defaults to current directory.
    
    .EXAMPLE
    Get-VSCodeChatEditingSessions | Select-Object -First 1 | Get-VSCodeChatEditingFiles
    
    .EXAMPLE
    Get-VSCodeChatEditingFiles -SessionId "f6d02192-d8e0-4ffa-b687-3080be9023a1"
    #>
    
    [CmdletBinding(DefaultParameterSetName='Session')]
    param(
        [Parameter(ParameterSetName='Session', Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject]$Session,
        
        [Parameter(ParameterSetName='SessionId', Mandatory=$true)]
        [string]$SessionId,
        
        [Parameter(ParameterSetName='SessionId')]
        [string]$Path = $pwd.Path
    )
    
    process {
        # Get session if using SessionId
        if ($PSCmdlet.ParameterSetName -eq 'SessionId') {
            $Session = Get-VSCodeChatEditingSessions -Path $Path -SessionId $SessionId
            if (-not $Session) {
                Write-Error "Session not found: $SessionId"
                return
            }
        }
        
        if (-not (Test-Path $Session.StatePath)) {
            Write-Error "State file not found: $($Session.StatePath)"
            return
        }
        
        try {
            $state = Get-Content $Session.StatePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Failed to parse state file: $_"
            return
        }
        
        # Group operations by file
        $fileGroups = @{}
        
        foreach ($op in $state.timeline.operations) {
            $filePath = $op.uri.fsPath
            if (-not $filePath) { continue }
            
            if (-not $fileGroups.ContainsKey($filePath)) {
                $fileGroups[$filePath] = @{
                    Operations = @()
                    RequestIds = @()
                    Epochs = @()
                }
            }
            
            $fileGroups[$filePath].Operations += $op
            if ($op.requestId -and $op.requestId -notin $fileGroups[$filePath].RequestIds) {
                $fileGroups[$filePath].RequestIds += $op.requestId
            }
            if ($op.epoch -and $op.epoch -notin $fileGroups[$filePath].Epochs) {
                $fileGroups[$filePath].Epochs += $op.epoch
            }
        }
        
        # Build output objects
        $files = @()
        foreach ($filePath in $fileGroups.Keys) {
            $group = $fileGroups[$filePath]
            
            # Calculate epoch range safely
            $epochRange = "N/A"
            if ($group.Epochs.Count -gt 0) {
                $minEpoch = ($group.Epochs | Measure-Object -Minimum).Minimum
                $maxEpoch = ($group.Epochs | Measure-Object -Maximum).Maximum
                $epochRange = "$minEpoch-$maxEpoch"
            }
            
            $file = [PSCustomObject]@{
                FilePath        = $filePath
                FileName        = Split-Path $filePath -Leaf
                OperationCount  = $group.Operations.Count
                RequestCount    = $group.RequestIds.Count
                EpochRange      = $epochRange
                RequestIds      = $group.RequestIds
                SessionId       = $Session.SessionId
            }
            
            # Add method to get operations for this file
            $file | Add-Member -MemberType ScriptMethod -Name GetOperations -Value {
                $parentSession = Get-VSCodeChatEditingSessions -SessionId $this.SessionId | Select-Object -First 1
                if ($parentSession) {
                    Get-VSCodeChatEditingOperations -Session $parentSession -FilePath $this.FilePath
                }
            }.GetNewClosure()
            
            $files += $file
        }
        
        return $files | Sort-Object OperationCount -Descending
    }
}

function Get-VSCodeChatEditingOperations {
    <#
    .SYNOPSIS
    Gets the editing operations from a chat editing session.
    
    .DESCRIPTION
    Returns the individual edit operations (text edits) from a chat editing session,
    optionally filtered by file path or request ID.
    
    .PARAMETER Session
    A session object from Get-VSCodeChatEditingSessions.
    
    .PARAMETER FilePath
    Optional. Filter operations to a specific file path.
    
    .PARAMETER RequestId
    Optional. Filter operations to a specific request ID.
    
    .EXAMPLE
    $session = Get-VSCodeChatEditingSessions | Select-Object -First 1
    Get-VSCodeChatEditingOperations -Session $session
    
    .EXAMPLE
    $session.GetOperations() | Where-Object Type -eq 'textEdit'
    
    .EXAMPLE
    $session.GetOperations(-FilePath "C:\Projects\MyFile.ps1")
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject]$Session,
        
        [string]$FilePath,
        
        [string]$RequestId
    )
    
    process {
        if (-not (Test-Path $Session.StatePath)) {
            Write-Error "State file not found: $($Session.StatePath)"
            return
        }
        
        try {
            $state = Get-Content $Session.StatePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Failed to parse state file: $_"
            return
        }
        
        $operations = $state.timeline.operations
        
        # Apply filters
        if ($FilePath) {
            $operations = $operations | Where-Object { $_.uri.fsPath -eq $FilePath }
        }
        
        if ($RequestId) {
            $operations = $operations | Where-Object { $_.requestId -eq $RequestId }
        }
        
        # Transform to friendly output
        foreach ($op in $operations) {
            $editText = $null
            if ($op.edits -and $op.edits.Count -gt 0) {
                $editText = ($op.edits | ForEach-Object { $_.text }) -join ""
            }
            
            [PSCustomObject]@{
                Type        = $op.type
                FilePath    = $op.uri.fsPath
                FileName    = Split-Path $op.uri.fsPath -Leaf
                RequestId   = $op.requestId
                Epoch       = $op.epoch
                EditText    = $editText
                EditCount   = $op.edits.Count
                Range       = if ($op.edits -and $op.edits[0].range) { $op.edits[0].range } else { $null }
                SessionId   = $Session.SessionId
            }
        }
    }
}

function Find-VSCodeChatEditingSessionByMessage {
    <#
    .SYNOPSIS
    Finds the chat editing session associated with a chat message.
    
    .DESCRIPTION
    Given a request ID from a chat message, finds the corresponding chat editing session
    that contains file modifications for that request.
    
    .PARAMETER RequestId
    The request ID from a chat message (e.g., from Get-VSCodeChatSessionHistory).
    
    .PARAMETER Path
    The workspace folder path. Defaults to current directory.
    
    .EXAMPLE
    $history = Get-VSCodeChatSessions | Select-Object -First 1 | Get-VSCodeChatSessionHistory
    $history[0].RequestId | Find-VSCodeChatEditingSessionByMessage
    
    .EXAMPLE
    Find-VSCodeChatEditingSessionByMessage -RequestId "request_f9be0e94-5ec4-4d3b-a411-3704d2ad3a0b"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$RequestId,
        
        [string]$Path = $pwd.Path
    )
    
    begin {
        # Load all editing sessions once
        $allSessions = Get-VSCodeChatEditingSessions -Path $Path
    }
    
    process {
        foreach ($session in $allSessions) {
            try {
                $state = Get-Content $session.StatePath -Raw | ConvertFrom-Json
                
                # Check if this request ID exists in operations
                $matchingOps = $state.timeline.operations | 
                    Where-Object { $_.requestId -eq $RequestId }
                
                if ($matchingOps) {
                    $files = $matchingOps | 
                        Select-Object -ExpandProperty uri | 
                        Select-Object -ExpandProperty fsPath -Unique
                    
                    [PSCustomObject]@{
                        Session         = $session
                        RequestId       = $RequestId
                        OperationCount  = $matchingOps.Count
                        FilesModified   = $files
                        FileCount       = $files.Count
                    }
                }
            }
            catch {
                Write-Verbose "Error checking session $($session.SessionId): $_"
            }
        }
    }
}

