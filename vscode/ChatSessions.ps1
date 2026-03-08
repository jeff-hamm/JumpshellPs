function Get-VSCodeChatSessions {
    <#
    .SYNOPSIS
    Gets a summary of all GitHub Copilot chat sessions for a workspace path.
    
    .DESCRIPTION
    Searches all workspace storage folders associated with a path and returns summary
    information about each chat session file found in the chatSessions directory.
    
    .PARAMETER Path
    The workspace folder path. Defaults to current directory ($pwd).
    
    .EXAMPLE
    Get-VSCodeChatSessions
    # Gets all chat sessions for current workspace
    
    .EXAMPLE
    Get-VSCodeChatSessions -Path "C:\Projects\MyProject"
    # Gets all chat sessions for specific workspace
    
    .EXAMPLE
    Get-VSCodeChatSessions | Where-Object MessageCount -gt 5
    # Filter sessions with more than 5 messages
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = $pwd.Path
    )
    
    # Get all workspace storage folders for this path
    Write-Verbose "Finding workspace storage folders for: $Path"
    $storageFolders = Get-VSCodeWorkspaceStorage -Path $Path -All
    
    if (-not $storageFolders) {
        Write-Warning "No workspace storage folders found for: $Path"
        return
    }
    
    $sessions = @()

    function Get-JsonlSessionMetadata {
        param([string]$FilePath)

        $metadata = @{
            sessionId = $null
            customTitle = $null
            creationDate = $null
            lastMessageDate = $null
            requesterUsername = $null
            responderUsername = $null
            isImported = $null
            version = $null
            requestsCount = 0
        }

        foreach ($line in Get-Content -Path $FilePath) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            if ($line -notmatch '"kind"\s*:\s*[0-9]') {
                continue
            }

            try {
                $entry = $line | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                continue
            }

            if ($entry.kind -eq 0 -and $entry.v) {
                $root = $entry.v

                if ($root.sessionId) { $metadata.sessionId = $root.sessionId }
                if ($null -ne $root.customTitle) { $metadata.customTitle = $root.customTitle }
                if ($root.creationDate) { $metadata.creationDate = $root.creationDate }
                if ($root.lastMessageDate) { $metadata.lastMessageDate = $root.lastMessageDate }
                if ($root.requesterUsername) { $metadata.requesterUsername = $root.requesterUsername }
                if ($root.responderUsername) { $metadata.responderUsername = $root.responderUsername }
                if ($null -ne $root.isImported) { $metadata.isImported = $root.isImported }
                if ($root.version) { $metadata.version = $root.version }
                if ($root.requests) { $metadata.requestsCount = @($root.requests).Count }

                continue
            }

            if (-not $entry.k) {
                continue
            }

            $keyPath = @($entry.k) -join '.'
            switch ($keyPath) {
                'sessionId' { if ($entry.v) { $metadata.sessionId = $entry.v } }
                'customTitle' { $metadata.customTitle = $entry.v }
                'creationDate' { if ($entry.v) { $metadata.creationDate = $entry.v } }
                'lastMessageDate' { if ($entry.v) { $metadata.lastMessageDate = $entry.v } }
                'requesterUsername' { if ($entry.v) { $metadata.requesterUsername = $entry.v } }
                'responderUsername' { if ($entry.v) { $metadata.responderUsername = $entry.v } }
                'isImported' { $metadata.isImported = $entry.v }
                'version' { if ($entry.v) { $metadata.version = $entry.v } }
                'requests' { $metadata.requestsCount = @($entry.v).Count }
            }
        }

        return [PSCustomObject]$metadata
    }

    function Convert-SessionTimestamp {
        param([object]$Timestamp)

        if ($null -eq $Timestamp -or $Timestamp -eq '') {
            return $null
        }

        if ($Timestamp -is [DateTime]) {
            return [DateTime]$Timestamp
        }

        try {
            return ([DateTime]'1970-01-01').AddMilliseconds([double]$Timestamp)
        }
        catch {
            return $null
        }
    }
    
    foreach ($folder in $storageFolders) {
        $chatSessionsPath = Join-Path $folder.FullName "chatSessions"
        
        if (-not (Test-Path $chatSessionsPath)) {
            Write-Verbose "No chatSessions folder in: $($folder.Name)"
            continue
        }
        
        $sessionFiles = Get-ChildItem -Path $chatSessionsPath -File |
            Where-Object { $_.Extension -in @('.json', '.jsonl') }
        
        foreach ($file in $sessionFiles) {
            try {
                $metadata = $null

                if ($file.Extension -ieq '.jsonl') {
                    $metadata = Get-JsonlSessionMetadata -FilePath $file.FullName
                }
                else {
                    # Extract metadata using JsonDocument — ~7x faster than ConvertFrom-Json
                    $metadata = ConvertFrom-JsonStream -Path $file.FullName `
                        -CountArrayProperty "requests" `
                        -Properties @("sessionId", "customTitle", "creationDate", "lastMessageDate", 
                                      "requesterUsername", "responderUsername", "isImported", "version")
                }

                if (-not $metadata) {
                    continue
                }
                
                # Convert epoch timestamps
                $creationDate = Convert-SessionTimestamp $metadata.creationDate
                $lastMessageDate = Convert-SessionTimestamp $metadata.lastMessageDate
                
                $session = [PSCustomObject]@{
                    SessionId      = $metadata.sessionId ?? $file.BaseName
                    FileName       = $file.Name
                    FilePath       = $file.FullName
                    StorageFolder  = $folder.Name
                    WorkspacePath  = $Path
                    Created        = $creationDate ?? $file.CreationTime
                    LastModified   = $lastMessageDate ?? $file.LastWriteTime
                    FileSize       = $file.Length
                    MessageCount   = $metadata.requestsCount ?? 0
                    Title          = $metadata.customTitle
                    Requester      = $metadata.requesterUsername
                    Responder      = $metadata.responderUsername
                    IsImported     = $metadata.isImported
                    Version        = $metadata.version
                }
                
                # Add GetMessages method
                $session | Add-Member -MemberType ScriptMethod -Name GetMessages -Value {
                    param([switch]$IncludeThinking, [switch]$IncludeMetadata)
                    Get-VSCodeChatSessionHistory -Session $this -IncludeThinking:$IncludeThinking -IncludeMetadata:$IncludeMetadata
                }
                
                # Add GetEditingSession method
                $session | Add-Member -MemberType ScriptMethod -Name GetEditingSession -Value {
                    Get-VSCodeChatEditingSessions -Path $this.WorkspacePath -SessionId $this.SessionId
                }
                
                $sessions += $session
            }
            catch {
                Write-Verbose "Failed to parse chat session: $($file.FullName) - $_"
            }
        }
    }
    
    return $sessions | Sort-Object LastModified -Descending
}

function Get-VSCodeChatSessionHistory {
    <#
    .SYNOPSIS
    Gets the request/response history from a GitHub Copilot chat session.
    
    .DESCRIPTION
    Retrieves and formats the conversation history from a chat session JSON file,
    including user requests, AI responses, thinking process, and metadata.
    
    .PARAMETER SessionId
    The session ID (GUID) of the chat session to retrieve.
    
    .PARAMETER FilePath
    Direct path to the chat session JSON file.
    
    .PARAMETER Session
    A session object from Get-VSCodeChatSessions (accepts pipeline input).
    
    .PARAMETER IncludeThinking
    Include the AI's thinking process in the output.
    
    .PARAMETER IncludeMetadata
    Include detailed metadata like model ID, timestamps, and citations.
    
    .EXAMPLE
    Get-VSCodeChatSessionHistory -SessionId "c0822a92-0948-402b-afd8-be4a05ef87e3"
    
    .EXAMPLE
    Get-VSCodeChatSessions | Select-Object -First 1 | Get-VSCodeChatSessionHistory
    
    .EXAMPLE
    Get-VSCodeChatSessionHistory -SessionId "abc123" -IncludeThinking -IncludeMetadata
    #>
    
    [CmdletBinding(DefaultParameterSetName='SessionId')]
    param(
        [Parameter(ParameterSetName='SessionId', Mandatory=$true, Position=0)]
        [string]$SessionId,
        
        [Parameter(ParameterSetName='FilePath', Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(ParameterSetName='Session', Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject]$Session,
        
        [switch]$IncludeThinking,
        
        [switch]$IncludeMetadata
    )
    
    begin {
        $history = @()
    }
    
    process {
        # Determine the file path based on parameter set
        $chatFilePath = $null
        
        if ($PSCmdlet.ParameterSetName -eq 'Session') {
            $chatFilePath = $Session.FilePath
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'FilePath') {
            $chatFilePath = $FilePath
        }
        else {
            # Find session by ID
            $sessions = Get-VSCodeChatSessions
            $foundSession = $sessions | Where-Object { $_.SessionId -eq $SessionId }
            if (-not $foundSession) {
                Write-Error "Session not found: $SessionId"
                return
            }
            $chatFilePath = $foundSession.FilePath
        }
        
        if (-not (Test-Path $chatFilePath)) {
            Write-Error "Chat session file not found: $chatFilePath"
            return
        }
        
        # Load the session (.json or .jsonl event stream)
        try {
            if ([System.IO.Path]::GetExtension($chatFilePath) -ieq '.jsonl') {
                $requestList = [System.Collections.Generic.List[object]]::new()

                foreach ($line in Get-Content -Path $chatFilePath) {
                    if ([string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }

                    if ($line -notmatch '"kind"\s*:\s*[0-9]') {
                        continue
                    }

                    try {
                        $entry = $line | ConvertFrom-Json -ErrorAction Stop
                    }
                    catch {
                        continue
                    }

                    # Initial snapshot can include full requests array
                    if ($entry.kind -eq 0 -and $entry.v -and $entry.v.requests) {
                        $requestList.Clear()
                        foreach ($request in @($entry.v.requests)) {
                            [void]$requestList.Add($request)
                        }
                        continue
                    }

                    if (-not $entry.k) {
                        continue
                    }

                    $path = @($entry.k)
                    if ($path.Count -eq 0 -or [string]$path[0] -ne 'requests') {
                        continue
                    }

                    # Full requests replacement
                    if ($path.Count -eq 1) {
                        $requestList.Clear()
                        foreach ($request in @($entry.v)) {
                            [void]$requestList.Add($request)
                        }
                        continue
                    }

                    $requestIndex = 0
                    if (-not [int]::TryParse([string]$path[1], [ref]$requestIndex)) {
                        continue
                    }

                    while ($requestList.Count -le $requestIndex) {
                        [void]$requestList.Add($null)
                    }

                    # Replace whole request object
                    if ($path.Count -eq 2) {
                        $requestList[$requestIndex] = $entry.v
                        continue
                    }

                    $request = $requestList[$requestIndex]
                    if ($null -eq $request) {
                        $request = [PSCustomObject]@{}
                    }
                    elseif ($request -is [hashtable]) {
                        $request = [PSCustomObject]$request
                    }

                    $current = $request
                    for ($i = 2; $i -lt ($path.Count - 1); $i++) {
                        $segment = [string]$path[$i]
                        $child = $null

                        if ($current -is [PSCustomObject]) {
                            if ($current.PSObject.Properties[$segment]) {
                                $child = $current.$segment
                            }

                            if ($null -eq $child) {
                                $child = [PSCustomObject]@{}
                                if ($current.PSObject.Properties[$segment]) {
                                    $current.$segment = $child
                                }
                                else {
                                    $current | Add-Member -NotePropertyName $segment -NotePropertyValue $child
                                }
                            }
                        }

                        $current = $child
                    }

                    $leaf = [string]$path[$path.Count - 1]
                    if ($current -is [PSCustomObject]) {
                        if ($current.PSObject.Properties[$leaf]) {
                            $current.$leaf = $entry.v
                        }
                        else {
                            $current | Add-Member -NotePropertyName $leaf -NotePropertyValue $entry.v
                        }
                    }

                    $requestList[$requestIndex] = $request
                }

                $content = [PSCustomObject]@{
                    requests = @($requestList | Where-Object { $null -ne $_ })
                }
            }
            else {
                $content = Get-Content $chatFilePath -Raw | ConvertFrom-Json
            }
        }
        catch {
            Write-Error "Failed to parse chat session: $chatFilePath - $_"
            return
        }

        if (-not $content -or -not $content.requests) {
            Write-Verbose "No requests found in chat session: $chatFilePath"
            return
        }
        
        # Process each request/response pair
        $exchangeNumber = 1
        foreach ($req in $content.requests) {
            # Convert timestamp
            $timestamp = $null
            if ($req.timestamp) {
                $timestamp = ([DateTime]'1970-01-01').AddMilliseconds($req.timestamp)
            }
            
            # Extract user message
            $userMessage = $req.message.text
            
            # Extract AI response parts
            $thinking = @()
            $responseText = @()
            
            foreach ($responsePart in $req.response) {
                if ($responsePart.kind -eq 'thinking' -and $IncludeThinking) {
                    $thinking += $responsePart.value
                }
                elseif ($responsePart.kind -eq 'toolInvocationSerialized') {
                    # Extract terminal commands from tool invocations
                    if ($responsePart.toolSpecificData -and $responsePart.toolSpecificData.commandLine) {
                        $cmd = $responsePart.toolSpecificData.commandLine.original
                        $lang = $responsePart.toolSpecificData.language ?? 'powershell'
                        $fence = '```'
                        $responseText += "$fence$lang`n$cmd`n$fence"
                    }
                }
                elseif (-not $responsePart.kind) {
                    # Main response content
                    $responseText += $responsePart.value
                }
            }
            
            # Join and clean response text
            $cleanedResponse = ($responseText -join "`n")
            # Remove empty code blocks - only blocks with nothing between the fences
            $cleanedResponse = $cleanedResponse -replace '```[a-z]*\s*\r?\n\s*```\r?\n?', ''
            
            $exchange = [PSCustomObject]@{
                Timestamp = $timestamp
                RequestId = $req.requestId
                ResponseId = $req.responseId
                Request = $userMessage
                Response = $cleanedResponse
                Thinking = if ($IncludeThinking) { ($thinking -join "`n") } else { $null }
            }
            
            # Add method to get file edits for this message
            $exchange | Add-Member -MemberType ScriptMethod -Name GetFileEdits -Value {
                Find-VSCodeChatEditingSessionByMessage -RequestId $this.RequestId
            }
            
            if ($IncludeMetadata) {
                $exchange | Add-Member -NotePropertyName 'ModelId' -NotePropertyValue $req.modelId
                $exchange | Add-Member -NotePropertyName 'CodeCitations' -NotePropertyValue $req.codeCitations
                $exchange | Add-Member -NotePropertyName 'ContentReferences' -NotePropertyValue $req.contentReferences
                $exchange | Add-Member -NotePropertyName 'Followups' -NotePropertyValue $req.followups
                $exchange | Add-Member -NotePropertyName 'TimeSpentWaiting' -NotePropertyValue $req.timeSpentWaiting
            }
            
            $history += $exchange
            $exchangeNumber++
        }
    }
    
    end {
        return $history
    }
}

