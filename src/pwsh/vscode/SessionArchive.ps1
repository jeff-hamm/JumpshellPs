function Convert-VSCodeWorkspaceUriToPath {
    [CmdletBinding()]
    param(
        [string]$WorkspaceUri
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceUri)) {
        return $null
    }

    if ($WorkspaceUri -notmatch '^file:///') {
        return $null
    }

    $decoded = $WorkspaceUri -replace '^file:///', ''
    $decoded = [System.Uri]::UnescapeDataString($decoded)
    $decoded = $decoded.Replace('/', '\')

    if ($decoded.Length -ge 2 -and $decoded[1] -eq ':' -and [char]::IsLetter($decoded[0])) {
        $decoded = $decoded.Substring(0, 1).ToLowerInvariant() + $decoded.Substring(1)
    }

    if ($decoded.Length -gt 3) {
        $decoded = $decoded.TrimEnd('\\')
    }

    return $decoded
}

function Resolve-VSCodeSessionWorkspaceInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$StorageFolder
    )

    $workspaceJsonPath = Join-Path $StorageFolder.FullName 'workspace.json'
    $workspaceJson = $null

    if (Test-Path -LiteralPath $workspaceJsonPath) {
        try {
            $workspaceJson = Get-Content -LiteralPath $workspaceJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $workspaceJson = $null
        }
    }

    $workspaceUri = $null
    $workspacePath = $null

    if ($workspaceJson) {
        if ($workspaceJson.folder) {
            $workspaceUri = [string]$workspaceJson.folder
        }
        elseif ($workspaceJson.workspace) {
            $workspaceUri = [string]$workspaceJson.workspace
        }
    }

    $workspacePath = Convert-VSCodeWorkspaceUriToPath -WorkspaceUri $workspaceUri
    if (-not $workspacePath) {
        $workspacePath = $workspaceUri
    }
    if (-not $workspacePath) {
        $workspacePath = '(unknown)'
    }

    [PSCustomObject]@{
        WorkspaceUri = $workspaceUri
        WorkspacePath = $workspacePath
    }
}

function ConvertTo-VSCodeSafeFolderName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputName
    )

    $safe = $InputName -replace '[^a-zA-Z0-9._-]', '_'
    $safe = $safe.Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'workspace'
    }

    return $safe
}

function Resolve-VSCodeNormalizeScriptPath {
    [CmdletBinding()]
    param(
        [string]$NormalizeScriptPath
    )

    if (-not [string]::IsNullOrWhiteSpace($NormalizeScriptPath)) {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NormalizeScriptPath)
        if (Test-Path -LiteralPath $resolvedPath) {
            return $resolvedPath
        }
        throw "Normalize script not found: $NormalizeScriptPath"
    }

    $candidates = @(
        (Join-Path $PSScriptRoot 'extract_copilot_chat_context.py'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'analysis_tools\extract_copilot_chat_context.py')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw 'Could not locate extract_copilot_chat_context.py. Provide -NormalizeScriptPath explicitly.'
}

function Copy-VsCodeChatSessions {
    <#
    .SYNOPSIS
    Copies VS Code/Copilot chat and editing sessions for a path into an archive folder.

    .DESCRIPTION
    Finds all related workspaceStorage folders for the provided path, copies chatSessions
    files and chatEditingSessions directories into a destination archive, and writes:
    - _manifest.json (machine-readable)
    - MANIFEST.md (human-readable)

    When -Normalize is specified, runs the Python extractor:
    extract_copilot_chat_context.py --root . --out <NormalizeOutput>

    .PARAMETER Path
    Source path used to resolve related VS Code workspace storage folders.

    .PARAMETER DestinationPath
    Destination folder for copied sessions and manifest files.

    .PARAMETER UserPath
    Optional explicit VS Code User path to scope workspaceStorage lookup.

    .PARAMETER Normalize
    Runs Python normalization after copy/manifest generation.

    .PARAMETER NormalizeScriptPath
    Optional path to extract_copilot_chat_context.py. If omitted, common defaults are used.

    .PARAMETER NormalizeOutput
    Output folder argument passed to the Python script's --out option.

    .EXAMPLE
    Copy-VsCodeSessions -Path 'C:\Users\Jumper\mips' -DestinationPath 'C:\Users\Jumper\mips\chatSessions'

    .EXAMPLE
    Copy-VsCodeSessions -Path 'C:\Users\Jumper\mips' -DestinationPath 'C:\Users\Jumper\mips\chatSessions' -Normalize
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = $PWD.Path,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [string]$UserPath,

        [switch]$Normalize,

        [string]$NormalizeScriptPath,

        [string]$NormalizeOutput = 'analysis_export'
    )

    $sourcePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Path not found: $Path"
    }

    $destinationFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    New-Item -ItemType Directory -Path $destinationFullPath -Force | Out-Null

    Write-Verbose "Finding workspace storage folders for source path: $sourcePath"
    $storageFolders = if ($PSBoundParameters.ContainsKey('UserPath') -and $UserPath) {
        Get-VSCodeWorkspaceStorage -Path $sourcePath -All -UserPath $UserPath
    }
    else {
        Get-VSCodeWorkspaceStorage -Path $sourcePath -All
    }

    if (-not $storageFolders) {
        Write-Warning "No workspace storage folders found for: $sourcePath"
        return
    }

    $manifest = [System.Collections.Generic.List[object]]::new()
    $workspaceToSafeFolder = @{}
    $usedSafeFolderNames = @{}

    $totalChatFiles = 0
    $totalEditingDirs = 0

    foreach ($storageFolder in @($storageFolders)) {
        $workspaceInfo = Resolve-VSCodeSessionWorkspaceInfo -StorageFolder $storageFolder

        $workspaceKey = $workspaceInfo.WorkspacePath
        if (-not $workspaceToSafeFolder.ContainsKey($workspaceKey)) {
            $leafName = Split-Path -Path $workspaceInfo.WorkspacePath -Leaf
            if ([string]::IsNullOrWhiteSpace($leafName)) {
                $leafName = 'workspace'
            }

            $baseSafeName = ConvertTo-VSCodeSafeFolderName -InputName $leafName
            $candidate = $baseSafeName

            # Keep folder names deterministic while avoiding collisions between different workspaces.
            if ($usedSafeFolderNames.ContainsKey($candidate) -and $usedSafeFolderNames[$candidate] -ne $workspaceKey) {
                $candidate = "{0}_{1}" -f $baseSafeName, $storageFolder.Name.Substring(0, [Math]::Min(8, $storageFolder.Name.Length))
            }

            $suffix = 2
            while ($usedSafeFolderNames.ContainsKey($candidate) -and $usedSafeFolderNames[$candidate] -ne $workspaceKey) {
                $candidate = "{0}_{1}" -f $baseSafeName, $suffix
                $suffix++
            }

            $workspaceToSafeFolder[$workspaceKey] = $candidate
            $usedSafeFolderNames[$candidate] = $workspaceKey
        }

        $safeFolderName = $workspaceToSafeFolder[$workspaceKey]
        $destinationWorkspaceRoot = Join-Path $destinationFullPath $safeFolderName
        New-Item -ItemType Directory -Path $destinationWorkspaceRoot -Force | Out-Null

        $copiedChatFiles = 0
        $copiedEditingDirs = 0

        $sourceChatPath = Join-Path $storageFolder.FullName 'chatSessions'
        if (Test-Path -LiteralPath $sourceChatPath) {
            $destinationChatPath = Join-Path $destinationWorkspaceRoot 'chatSessions'
            New-Item -ItemType Directory -Path $destinationChatPath -Force | Out-Null

            foreach ($chatFile in Get-ChildItem -LiteralPath $sourceChatPath -File) {
                $targetChatFile = Join-Path $destinationChatPath $chatFile.Name
                if (Test-Path -LiteralPath $targetChatFile) {
                    $targetChatFile = Join-Path $destinationChatPath ("{0}_{1}" -f $storageFolder.Name.Substring(0, [Math]::Min(8, $storageFolder.Name.Length)), $chatFile.Name)
                }

                if ($PSCmdlet.ShouldProcess($targetChatFile, "Copy $($chatFile.FullName)")) {
                    Copy-Item -LiteralPath $chatFile.FullName -Destination $targetChatFile -Force
                    $copiedChatFiles++
                    $totalChatFiles++
                }
            }
        }

        $sourceEditingPath = Join-Path $storageFolder.FullName 'chatEditingSessions'
        if (Test-Path -LiteralPath $sourceEditingPath) {
            $destinationEditingPath = Join-Path $destinationWorkspaceRoot 'chatEditingSessions'
            New-Item -ItemType Directory -Path $destinationEditingPath -Force | Out-Null

            foreach ($editingDir in Get-ChildItem -LiteralPath $sourceEditingPath -Directory) {
                $targetEditingDir = Join-Path $destinationEditingPath $editingDir.Name
                if (Test-Path -LiteralPath $targetEditingDir) {
                    $targetEditingDir = Join-Path $destinationEditingPath ("{0}_{1}" -f $storageFolder.Name.Substring(0, [Math]::Min(8, $storageFolder.Name.Length)), $editingDir.Name)
                }

                if ($PSCmdlet.ShouldProcess($targetEditingDir, "Copy $($editingDir.FullName)")) {
                    Copy-Item -LiteralPath $editingDir.FullName -Destination $targetEditingDir -Recurse -Force
                    $copiedEditingDirs++
                    $totalEditingDirs++
                }
            }
        }

        $manifest.Add([PSCustomObject]@{
            StorageHash = $storageFolder.Name
            SafeFolderName = $safeFolderName
            WorkspacePath = $workspaceInfo.WorkspacePath
            WorkspaceUri = $workspaceInfo.WorkspaceUri
            ChatSessionFiles = $copiedChatFiles
            EditingSessionDirs = $copiedEditingDirs
            SourceStoragePath = $storageFolder.FullName
            DestinationFolder = $destinationWorkspaceRoot
        })
    }

    $manifestPath = Join-Path $destinationFullPath '_manifest.json'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    $manifestMarkdownPath = Join-Path $destinationFullPath 'MANIFEST.md'
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# VS Code Session Copy Manifest')
    $lines.Add('')
    $lines.Add("Generated: $(Get-Date -Format o)")
    $lines.Add("Source Path: $sourcePath")
    $lines.Add("Destination Path: $destinationFullPath")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add("- Workspace storage folders processed: $(@($storageFolders).Count)")
    $lines.Add("- Chat session files copied: $totalChatFiles")
    $lines.Add("- Chat editing session directories copied: $totalEditingDirs")
    $lines.Add('')
    $lines.Add('## Workspace Mapping')
    $lines.Add('')
    $lines.Add('| Safe Folder | Storage Hash | Workspace Path (Original) | Chat Files | Editing Dirs |')
    $lines.Add('|---|---|---|---:|---:|')

    foreach ($entry in $manifest) {
        $safe = ([string]$entry.SafeFolderName).Replace('|', '\|')
        $hash = ([string]$entry.StorageHash).Replace('|', '\|')
        $workspace = ([string]$entry.WorkspacePath).Replace('|', '\|')
        $lines.Add("| $safe | $hash | $workspace | $($entry.ChatSessionFiles) | $($entry.EditingSessionDirs) |")
    }

    Set-Content -LiteralPath $manifestMarkdownPath -Encoding UTF8 -Value ($lines -join "`n")

    $normalizeOutputPath = $null
    if ($Normalize) {
        $normalizeScript = Resolve-VSCodeNormalizeScriptPath -NormalizeScriptPath $NormalizeScriptPath
        $python = Get-Command python -ErrorAction SilentlyContinue
        if (-not $python) {
            throw 'Python executable not found in PATH. Install Python or run without -Normalize.'
        }

        Push-Location $destinationFullPath
        try {
            if ($PSCmdlet.ShouldProcess($destinationFullPath, "Normalize copied sessions via $normalizeScript")) {
                & $python.Source $normalizeScript --root . --out $NormalizeOutput
                if ($LASTEXITCODE -ne 0) {
                    throw "Normalization failed with exit code $LASTEXITCODE"
                }
            }
        }
        finally {
            Pop-Location
        }

        $normalizeOutputPath = Join-Path $destinationFullPath $NormalizeOutput
    }

    return [PSCustomObject]@{
        SourcePath = $sourcePath
        DestinationPath = $destinationFullPath
        WorkspaceStorageFolders = @($storageFolders).Count
        CopiedChatSessionFiles = $totalChatFiles
        CopiedEditingSessionDirs = $totalEditingDirs
        ManifestPath = $manifestPath
        ManifestMarkdownPath = $manifestMarkdownPath
        Normalized = [bool]$Normalize
        NormalizedOutputPath = $normalizeOutputPath
    }
}

function Resolve-VSCodeWorkspaceStorageById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [string]$UserPath
    )

    $workspaceIdNormalized = $WorkspaceId.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($workspaceIdNormalized)) {
        return @()
    }

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
            (Join-Path $env:APPDATA 'Code\User'),
            (Join-Path $env:APPDATA 'Code - Insiders\User'),
            (Join-Path $env:APPDATA 'Cursor\User'),
            (Join-Path $env:APPDATA 'VSCodium\User')
        )

        foreach ($candidate in $defaultUserCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                $userPathsToSearch += $candidate
            }

            $profilesRoot = Join-Path $candidate 'profiles'
            if (Test-Path -LiteralPath $profilesRoot) {
                $userPathsToSearch += (Get-ChildItem -LiteralPath $profilesRoot -Directory | ForEach-Object { $_.FullName })
            }
        }
    }

    $found = [System.Collections.Generic.List[object]]::new()
    foreach ($userPathCandidate in ($userPathsToSearch | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $workspaceStoragePath = Join-Path $userPathCandidate 'workspaceStorage'
        if (-not (Test-Path -LiteralPath $workspaceStoragePath)) {
            continue
        }

        $candidatePath = Join-Path $workspaceStoragePath $workspaceIdNormalized
        if (Test-Path -LiteralPath $candidatePath -PathType Container) {
            [void]$found.Add((Get-Item -LiteralPath $candidatePath))
        }
    }

    return @($found | Group-Object FullName | ForEach-Object { $_.Group[0] })
}

function Search-VsCodeChat {
    <#
    .SYNOPSIS
    Searches VS Code Copilot chat sessions for text or regex matches.

    .DESCRIPTION
    Supports three scope selectors:
    - Path (default: current directory)
    - WorkspaceFile (.code-workspace or workspace path)
    - WorkspaceId (workspaceStorage hash folder)

    Searches matched chat sessions and returns one result object per matching turn.

    .PARAMETER Query
    Search text or regex pattern.

    .PARAMETER Regex
    Treat Query as a regular expression pattern.

    .PARAMETER Path
    Workspace path to resolve matching sessions. Defaults to current directory.

    .PARAMETER WorkspaceFile
    Workspace file path (for example, *.code-workspace) or workspace path.

    .PARAMETER WorkspaceId
    VS Code workspaceStorage folder id (hash) to search directly.

    .PARAMETER CaseSensitive
    Enables case-sensitive matching. Default is case-insensitive.

    .PARAMETER Json
    Returns the result set serialized as JSON.

    .EXAMPLE
    Search-VsCodeChat -Query 'workspaceStorage'

    .EXAMPLE
    Search-VsCodeChat -WorkspaceFile '.\my.code-workspace' -Query 'Get-VSCodeChat' -Regex

    .EXAMPLE
    Search-VsCodeChat -WorkspaceId '4b654f7f4df34f8adf9f0f9f8a123456' -Query 'manifest'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Query,

        [switch]$Regex,

        [Parameter(ParameterSetName = 'Path', Position = 1)]
        [string]$Path = $PWD.Path,

        [Parameter(ParameterSetName = 'WorkspaceFile', Mandatory = $true)]
        [string]$WorkspaceFile,

        [Parameter(ParameterSetName = 'WorkspaceId', Mandatory = $true)]
        [string]$WorkspaceId,

        [switch]$CaseSensitive,

        [switch]$Json
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        throw 'Query cannot be empty.'
    }

    function New-ChatSearchSnippet {
        param(
            [string]$Text,
            [int]$Index,
            [int]$Length,
            [int]$Radius = 90
        )

        if ([string]::IsNullOrEmpty($Text)) {
            return $null
        }

        if ($Index -lt 0) {
            return ($Text.Trim())
        }

        $start = [Math]::Max(0, $Index - $Radius)
        $end = [Math]::Min($Text.Length, $Index + [Math]::Max($Length, 1) + $Radius)
        $slice = $Text.Substring($start, $end - $start).Replace("`r", '').Replace("`n", ' ')

        if ($start -gt 0) {
            $slice = '...' + $slice
        }

        if ($end -lt $Text.Length) {
            $slice = $slice + '...'
        }

        return $slice.Trim()
    }

    function Find-ChatMatches {
        param(
            [AllowNull()]
            [string]$Text,
            [string]$SearchText,
            [switch]$UseRegex,
            [switch]$UseCaseSensitive,
            [AllowNull()]
            [regex]$CompiledRegex
        )

        if ([string]::IsNullOrEmpty($Text)) {
            return [PSCustomObject]@{
                IsMatch = $false
                MatchCount = 0
                FirstIndex = -1
                FirstLength = 0
                FirstValue = $null
            }
        }

        if ($UseRegex) {
            if ($null -eq $CompiledRegex) {
                return [PSCustomObject]@{
                    IsMatch = $false
                    MatchCount = 0
                    FirstIndex = -1
                    FirstLength = 0
                    FirstValue = $null
                }
            }

            $regexMatches = $CompiledRegex.Matches($Text)
            if ($regexMatches.Count -eq 0) {
                return [PSCustomObject]@{
                    IsMatch = $false
                    MatchCount = 0
                    FirstIndex = -1
                    FirstLength = 0
                    FirstValue = $null
                }
            }

            $first = $regexMatches[0]
            return [PSCustomObject]@{
                IsMatch = $true
                MatchCount = $regexMatches.Count
                FirstIndex = $first.Index
                FirstLength = $first.Length
                FirstValue = $first.Value
            }
        }

        $comparison = if ($UseCaseSensitive) {
            [System.StringComparison]::Ordinal
        }
        else {
            [System.StringComparison]::OrdinalIgnoreCase
        }

        $index = $Text.IndexOf($SearchText, $comparison)
        if ($index -lt 0) {
            return [PSCustomObject]@{
                IsMatch = $false
                MatchCount = 0
                FirstIndex = -1
                FirstLength = 0
                FirstValue = $null
            }
        }

        $count = 0
        $searchFrom = 0
        while ($searchFrom -lt $Text.Length) {
            $next = $Text.IndexOf($SearchText, $searchFrom, $comparison)
            if ($next -lt 0) {
                break
            }
            $count++
            $searchFrom = $next + [Math]::Max($SearchText.Length, 1)
        }

        return [PSCustomObject]@{
            IsMatch = $true
            MatchCount = $count
            FirstIndex = $index
            FirstLength = $SearchText.Length
            FirstValue = $SearchText
        }
    }

    $compiledRegex = $null
    if ($Regex) {
        try {
            $regexOptions = if ($CaseSensitive) {
                [System.Text.RegularExpressions.RegexOptions]::None
            }
            else {
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            }

            $compiledRegex = [regex]::new($Query, $regexOptions)
        }
        catch {
            throw "Invalid regex pattern: $Query. $($_.Exception.Message)"
        }
    }

    $sessionCandidates = @()
    if ($PSCmdlet.ParameterSetName -eq 'WorkspaceId') {
        $storageFolders = Resolve-VSCodeWorkspaceStorageById -WorkspaceId $WorkspaceId
        foreach ($storageFolder in @($storageFolders)) {
            $workspaceInfo = Resolve-VSCodeSessionWorkspaceInfo -StorageFolder $storageFolder
            $chatSessionPath = Join-Path $storageFolder.FullName 'chatSessions'
            if (-not (Test-Path -LiteralPath $chatSessionPath)) {
                continue
            }

            foreach ($chatFile in (Get-ChildItem -LiteralPath $chatSessionPath -File | Where-Object { $_.Extension -in @('.json', '.jsonl') })) {
                $sessionCandidates += [PSCustomObject]@{
                    SessionId = $chatFile.BaseName
                    FilePath = $chatFile.FullName
                    FileName = $chatFile.Name
                    StorageFolder = $storageFolder.Name
                    WorkspacePath = $workspaceInfo.WorkspacePath
                    Title = $null
                }
            }
        }
    }
    else {
        $targetPath = if ($PSCmdlet.ParameterSetName -eq 'WorkspaceFile') { $WorkspaceFile } else { $Path }
        $resolvedTargetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($targetPath)

        if (-not (Test-Path -LiteralPath $resolvedTargetPath)) {
            throw "Path not found: $targetPath"
        }

        $sessionCandidates = @(Get-VSCodeChatSessions -Path $resolvedTargetPath)
    }

    if (-not $sessionCandidates -or @($sessionCandidates).Count -eq 0) {
        if ($Json) {
            return '[]'
        }

        return @()
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($session in @($sessionCandidates)) {
        $history = @()
        try {
            $history = @(Get-VSCodeChatSessionHistory -FilePath $session.FilePath)
        }
        catch {
            Write-Verbose "Skipping unreadable session file: $($session.FilePath). $($_.Exception.Message)"
            continue
        }

        foreach ($turn in $history) {
            $requestText = [string]($turn.Request)
            $responseText = [string]($turn.Response)

            $requestMatch = Find-ChatMatches -Text $requestText -SearchText $Query -UseRegex:$Regex -UseCaseSensitive:$CaseSensitive -CompiledRegex $compiledRegex
            $responseMatch = Find-ChatMatches -Text $responseText -SearchText $Query -UseRegex:$Regex -UseCaseSensitive:$CaseSensitive -CompiledRegex $compiledRegex

            if (-not $requestMatch.IsMatch -and -not $responseMatch.IsMatch) {
                continue
            }

            $matchedLocations = @()
            if ($requestMatch.IsMatch) { $matchedLocations += 'Request' }
            if ($responseMatch.IsMatch) { $matchedLocations += 'Response' }

            $results.Add([PSCustomObject]@{
                Query = $Query
                IsRegex = [bool]$Regex
                IsCaseSensitive = [bool]$CaseSensitive
                WorkspacePath = $session.WorkspacePath
                WorkspaceId = $session.StorageFolder
                SessionId = $session.SessionId
                SessionTitle = $session.Title
                SessionFile = $session.FilePath
                FileName = $session.FileName
                RequestId = $turn.RequestId
                Timestamp = $turn.Timestamp
                MatchedIn = ($matchedLocations -join ',')
                RequestMatchCount = $requestMatch.MatchCount
                ResponseMatchCount = $responseMatch.MatchCount
                TotalMatchCount = ($requestMatch.MatchCount + $responseMatch.MatchCount)
                RequestFirstMatch = $requestMatch.FirstValue
                ResponseFirstMatch = $responseMatch.FirstValue
                RequestSnippet = New-ChatSearchSnippet -Text $requestText -Index $requestMatch.FirstIndex -Length $requestMatch.FirstLength
                ResponseSnippet = New-ChatSearchSnippet -Text $responseText -Index $responseMatch.FirstIndex -Length $responseMatch.FirstLength
            }) | Out-Null
        }
    }

    $ordered = @($results | Sort-Object Timestamp, SessionId -Descending)
    if ($Json) {
        return ($ordered | ConvertTo-Json -Depth 8)
    }

    return $ordered
}

function _Initialize-VSCodeChatAliases {
    [CmdletBinding()]
    param()

    # Map <Verb>-VSCodeChat<Rest> to <Verb>-Ai<Rest> for all current chat functions.
    $chatFunctions = Get-Command -CommandType Function | Where-Object {
        $_.Name -notmatch '^_' -and $_.Name -imatch '^(.*)-VSCodeChat(.*)$'
    }

    foreach ($functionCommand in $chatFunctions) {
        $null = $functionCommand.Name -imatch '^(.*)-VSCodeChat(.*)$'
        $aliasName = '{0}-Ai{1}' -f $Matches[1], $Matches[2]

        if ([string]::IsNullOrWhiteSpace($aliasName)) {
            continue
        }

        $aliasPath = "Alias:{0}" -f $aliasName
        $existingAlias = if (Test-Path -LiteralPath $aliasPath) {
            Get-Item -LiteralPath $aliasPath -ErrorAction SilentlyContinue
        }
        else {
            $null
        }
        if ($existingAlias -and $existingAlias.Definition -ieq $functionCommand.Name) {
            continue
        }

        if ($existingAlias -and $existingAlias.Definition -ine $functionCommand.Name) {
            Remove-Item -Path ("Alias:{0}" -f $aliasName) -Force -ErrorAction SilentlyContinue
        }

        Set-Alias -Name $aliasName -Value $functionCommand.Name -Scope Script
    }
}

_Initialize-VSCodeChatAliases

# Backward-compatible aliases for the previous command names.
Set-Alias -Name Search-VsCodeChatSessions -Value Search-VsCodeChat -Scope Script
Set-Alias -Name Search-AiSessions -Value Search-VsCodeChat -Scope Script