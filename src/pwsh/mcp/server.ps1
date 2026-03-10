param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ModuleName = 'JumpShellPs',
    [string]$ProtocolVersion = '2025-06-18'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'

$env:JUMPSHELL_MCP_DISABLE_AUTOSTART = '1'
$env:JUMPSHELL_MCP_SERVER_MODE = '1'
$env:TERM_PROGRAM = 'mcp'

$script:ProtocolVersion = $ProtocolVersion
$script:ModuleName = $ModuleName
$script:ModuleRoot = $ModuleRoot
$script:ToolDefinitions = $null
$script:CommandCatalog = $null
$script:ToolNameToCommand = @{}

# --- Logging ---

function Write-ServerLog {
    param([string]$Message)
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        [Console]::Error.WriteLine("[jumpshell-mcp] $Message")
    }
}

# --- JSON-RPC helpers ---

function ConvertTo-Hashtable {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [hashtable]) {
        $copy = @{}
        foreach ($key in $InputObject.Keys) { $copy[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key] }
        return $copy
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) { $result[[string]$key] = ConvertTo-Hashtable -InputObject $InputObject[$key] }
        return $result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) { $items += ConvertTo-Hashtable -InputObject $item }
        return $items
    }
    if ($InputObject -is [psobject] -and $InputObject.PSObject.Properties.Count -gt 0) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) { $result[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value }
        return $result
    }
    return $InputObject
}

function New-JsonRpcResponse {
    param([object]$Id, [hashtable]$Result)
    return @{ jsonrpc = '2.0'; id = $Id; result = $Result }
}

function New-JsonRpcError {
    param([object]$Id, [int]$Code, [string]$Message, [object]$Data)
    $errorObject = @{ code = $Code; message = $Message }
    if ($null -ne $Data) { $errorObject['data'] = $Data }
    return @{ jsonrpc = '2.0'; id = $Id; error = $errorObject }
}

function Write-JsonRpcMessage {
    param([hashtable]$Payload)
    $json = $Payload | ConvertTo-Json -Depth 30 -Compress
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

# --- Output conversion ---

function Convert-ObjectToText {
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Management.Automation.ErrorRecord]) { return "ERROR: $($Value.Exception.Message)" }
    if ($Value -is [System.Management.Automation.WarningRecord]) { return "WARNING: $($Value.Message)" }
    if ($Value -is [System.Management.Automation.VerboseRecord]) { return "VERBOSE: $($Value.Message)" }
    if ($Value -is [System.Management.Automation.DebugRecord]) { return "DEBUG: $($Value.Message)" }
    if ($Value -is [System.Management.Automation.InformationRecord]) {
        if ($null -ne $Value.MessageData) { return [string]$Value.MessageData }
        return ''
    }
    try { return ($Value | Out-String).TrimEnd() } catch { return [string]$Value }
}

function Convert-InvocationResultToText {
    param([object[]]$Items)
    if (-not $Items -or $Items.Count -eq 0) { return '' }
    $lines = @()
    foreach ($item in $Items) {
        $line = Convert-ObjectToText -Value $item
        if (-not [string]::IsNullOrWhiteSpace($line)) { $lines += $line }
    }
    return ($lines -join "`n").Trim()
}

# --- Module introspection ---

$script:CommonParameters = @(
    'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
    'ErrorVariable', 'WarningVariable', 'InformationVariable',
    'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction',
    'WhatIf', 'Confirm'
)

function Get-FunctionFileMap {
    $mapVar = Get-Variable -Name 'JumpShell_FunctionFileMap' -Scope Global -ErrorAction SilentlyContinue
    if ($mapVar -and $mapVar.Value) { return $mapVar.Value }
    return @{}
}

function Get-JumpShellCommandCatalog {
    if ($script:CommandCatalog) { return $script:CommandCatalog }

    $fileMap = Get-FunctionFileMap
    $commands = Get-Command -Module $script:ModuleName -CommandType Function | Sort-Object Name
    $catalog = foreach ($command in $commands) {
        $parameterNames = @($command.Parameters.Keys | Where-Object { $_ -notin $script:CommonParameters } | Sort-Object)
        [pscustomobject]@{
            name = $command.Name
            sourceFile = if ($fileMap.ContainsKey($command.Name)) { "$($fileMap[$command.Name]).ps1" } else { $null }
            parameters = $parameterNames
        }
    }
    $script:CommandCatalog = @($catalog)
    return $script:CommandCatalog
}

# --- Search (meta-tool) ---

function Search-JumpShellCommands {
    param(
        [Parameter(Mandatory)] [string]$Query,
        [int]$Limit = 20,
        [switch]$IncludeParameters
    )

    $trimmedQuery = $Query.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedQuery)) { return @() }

    $queryLower = $trimmedQuery.ToLowerInvariant()
    $tokens = @($queryLower -split '[^a-z0-9]+' | Where-Object { $_ })
    $catalog = Get-JumpShellCommandCatalog

    $results = foreach ($entry in $catalog) {
        $nameLower = $entry.name.ToLowerInvariant()
        $fileLower = ([string]$entry.sourceFile).ToLowerInvariant()
        $parameterLookup = @($entry.parameters | ForEach-Object { $_.ToLowerInvariant() })

        $score = 0
        if ($nameLower -like "*$queryLower*") { $score += 8 }
        if ($fileLower -like "*$queryLower*") { $score += 3 }
        foreach ($token in $tokens) {
            if ($nameLower -like "*$token*") { $score += 2 }
            if ($fileLower -like "*$token*") { $score += 1 }
            if (($parameterLookup | Where-Object { $_ -like "*$token*" } | Select-Object -First 1)) { $score += 1 }
        }
        if ($score -le 0) { continue }

        [pscustomobject]@{
            name = $entry.name
            sourceFile = $entry.sourceFile
            parameters = if ($IncludeParameters) { @($entry.parameters) } else { @() }
            score = $score
        }
    }

    return @($results | Sort-Object score, name -Descending | Select-Object -First $Limit)
}

# --- Parameter name resolution ---

function Resolve-CommandParameterName {
    param(
        [System.Management.Automation.CommandInfo]$Command,
        [string]$RequestedName
    )
    if ($null -eq $Command.Parameters) { return $null }
    foreach ($parameter in $Command.Parameters.Values) {
        if ($parameter.Name -ieq $RequestedName) { return $parameter.Name }
    }
    return $null
}

# --- Command invocation ---

function Invoke-JumpShellCommand {
    param(
        [Parameter(Mandatory)] [string]$CommandName,
        [hashtable]$Arguments
    )

    $command = Get-Command -Name $CommandName -Module $script:ModuleName -CommandType Function -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Command '$CommandName' was not found in module '$($script:ModuleName)'."
    }

    $splat = @{}
    $unknownParameters = @()

    if ($Arguments) {
        foreach ($key in $Arguments.Keys) {
            $resolvedName = Resolve-CommandParameterName -Command $command -RequestedName ([string]$key)
            if (-not $resolvedName) { $unknownParameters += [string]$key; continue }

            $parameter = $command.Parameters[$resolvedName]
            $value = $Arguments[$key]

            if ($parameter.ParameterType -eq [switch]) {
                if ([bool]$value) { $splat[$resolvedName] = $true }
                continue
            }
            $splat[$resolvedName] = $value
        }
    }

    if ($unknownParameters.Count -gt 0) {
        throw "Unknown parameter(s) for command '$CommandName': $($unknownParameters -join ', ')."
    }

    $results = & { & $CommandName @splat } *>&1
    $text = Convert-InvocationResultToText -Items $results

    return @{
        command = $CommandName
        parameters = $splat
        text = $text
        streamCount = $results.Count
    }
}

# --- Dynamic tool schema generation ---

function ConvertTo-JsonSchemaType {
    param([Type]$ParameterType)

    if ($null -eq $ParameterType) {
        return @{ type = 'string' }
    }
    if ($ParameterType -eq [switch] -or $ParameterType -eq [bool]) {
        return @{ type = 'boolean' }
    }
    if ($ParameterType -eq [int] -or $ParameterType -eq [int32] -or $ParameterType -eq [int64] -or $ParameterType -eq [long]) {
        return @{ type = 'integer' }
    }
    if ($ParameterType -eq [double] -or $ParameterType -eq [float] -or $ParameterType -eq [decimal]) {
        return @{ type = 'number' }
    }
    if ($ParameterType -eq [string[]]) {
        return @{ type = 'array'; items = @{ type = 'string' } }
    }
    if ($ParameterType -eq [int[]]) {
        return @{ type = 'array'; items = @{ type = 'integer' } }
    }
    if ($ParameterType.IsArray) {
        return @{ type = 'array'; items = @{ type = 'string' } }
    }
    # Default: treat as string (covers [object], [string], [PSCredential] etc.)
    return @{ type = 'string' }
}

function New-ToolDefinitionFromCommand {
    param([System.Management.Automation.CommandInfo]$Command, [string]$SourceFile)

    $properties = [ordered]@{}
    $required = @()

    if ($null -ne $Command.Parameters) {
        foreach ($paramEntry in $Command.Parameters.GetEnumerator()) {
            $paramName = $paramEntry.Key
            if ($paramName -in $script:CommonParameters) { continue }

            $param = $paramEntry.Value
            $schema = ConvertTo-JsonSchemaType -ParameterType $param.ParameterType
            $schema['description'] = $paramName

            # Check if mandatory
            $paramAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | Select-Object -First 1
            if ($paramAttr -and $paramAttr.Mandatory) {
                $required += $paramName
            }

            $properties[$paramName] = $schema
        }
    }

    $inputSchema = @{
        type = 'object'
        properties = $properties
    }
    if ($required.Count -gt 0) {
        $inputSchema['required'] = $required
    }

    # Determine annotations from source file / naming conventions
    $readOnly = $false
    $destructive = $false
    $nameL = $Command.Name.ToLowerInvariant()
    $fileL = ([string]$SourceFile).ToLowerInvariant()

    # Read-only patterns
    if ($nameL -match '^(get-|find-|test-|search-|list-|show-|format-|convert|measure-)' -or
        $nameL -match '^(view-|read-|resolve-)') {
        $readOnly = $true
    }
    # Destructive patterns
    if ($nameL -match '^(remove-|delete-|clear-|reset-)' -or
        $nameL -match 'delete|remove|uninstall|drop') {
        $destructive = $true
    }

    $description = "$($Command.Name) from $SourceFile"
    if ($properties.Count -gt 0) {
        $paramList = ($properties.Keys | Select-Object -First 6) -join ', '
        if ($properties.Count -gt 6) { $paramList += ', ...' }
        $description += " ($paramList)"
    }

    # Tool name: lowercase, hyphens to underscores for JSON-friendliness
    $toolName = $Command.Name.ToLowerInvariant() -replace '-', '_'

    return @{
        toolName = $toolName
        commandName = $Command.Name
        definition = @{
            name = $toolName
            title = $Command.Name
            description = $description
            inputSchema = $inputSchema
            annotations = @{
                readOnlyHint = $readOnly
                destructiveHint = $destructive
                idempotentHint = $readOnly
                openWorldHint = (-not $readOnly)
            }
        }
    }
}

function Get-ToolDefinitions {
    if ($script:ToolDefinitions) { return $script:ToolDefinitions }

    # Meta-tool: search (always available)
    $searchTool = @{
        name = 'jumpshell_search'
        title = 'Search JumpShell commands'
        description = 'Search all JumpShell functions by name, source file, or parameter keywords. Returns matching commands with parameter lists. Use this when you are unsure which command to call.'
        inputSchema = @{
            type = 'object'
            properties = @{
                query = @{ type = 'string'; description = 'Free-text query to match command names, source files, and parameters.' }
                limit = @{ type = 'integer'; description = 'Max results (default 20).'; minimum = 1; maximum = 100; default = 20 }
                includeParameters = @{ type = 'boolean'; description = 'Include parameter names in results.'; default = $true }
            }
            required = @('query')
        }
        annotations = @{ readOnlyHint = $true; destructiveHint = $false; idempotentHint = $true; openWorldHint = $false }
    }

    $fileMap = Get-FunctionFileMap
    $commands = Get-Command -Module $script:ModuleName -CommandType Function | Sort-Object Name

    $dynamicTools = @()
    $script:ToolNameToCommand = @{}

    foreach ($command in $commands) {
        $sourceFile = if ($fileMap.ContainsKey($command.Name)) { "$($fileMap[$command.Name]).ps1" } else { 'unknown' }
        $result = New-ToolDefinitionFromCommand -Command $command -SourceFile $sourceFile
        $dynamicTools += $result.definition
        $script:ToolNameToCommand[$result.toolName] = $result.commandName
    }

    $script:ToolDefinitions = @($searchTool) + $dynamicTools
    Write-ServerLog "Registered $($script:ToolDefinitions.Count) tools ($($dynamicTools.Count) from module + 1 search meta-tool)."
    return $script:ToolDefinitions
}

# --- Tool result wrapper ---

function New-ToolResult {
    param(
        [string]$Text,
        [object]$StructuredContent,
        [switch]$IsError
    )

    if ([string]::IsNullOrWhiteSpace($Text) -and $null -ne $StructuredContent) {
        $Text = $StructuredContent | ConvertTo-Json -Depth 20
    }
    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = 'Operation completed with no output.'
    }

    $result = @{
        content = @( @{ type = 'text'; text = $Text } )
    }
    if ($null -ne $StructuredContent) { $result['structuredContent'] = $StructuredContent }
    if ($IsError) { $result['isError'] = $true }
    return $result
}

# --- Tool dispatch (fully dynamic) ---

function Invoke-ToolCall {
    param(
        [string]$ToolName,
        [hashtable]$Arguments
    )

    # Meta-tool: search
    if ($ToolName -eq 'jumpshell_search') {
        $query = [string]$Arguments['query']
        if ([string]::IsNullOrWhiteSpace($query)) {
            throw [System.ArgumentException]::new("Tool 'jumpshell_search' requires a non-empty 'query' argument.")
        }

        $limit = 20
        if ($Arguments.ContainsKey('limit') -and $null -ne $Arguments['limit']) {
            $limit = [Math]::Min([Math]::Max([int]$Arguments['limit'], 1), 100)
        }
        $includeParameters = $true
        if ($Arguments.ContainsKey('includeParameters') -and $null -ne $Arguments['includeParameters']) {
            $includeParameters = [bool]$Arguments['includeParameters']
        }

        $matches = Search-JumpShellCommands -Query $query -Limit $limit -IncludeParameters:$includeParameters
        $lines = @()
        foreach ($match in $matches) {
            $line = "- $($match.name)"
            if ($match.sourceFile) { $line += " [$($match.sourceFile)]" }
            if ($includeParameters -and $match.parameters -and $match.parameters.Count -gt 0) {
                $line += ": $($match.parameters -join ', ')"
            }
            $lines += $line
        }

        $text = if ($lines.Count -gt 0) { "Found $($matches.Count) matching command(s):`n$($lines -join "`n")" }
                else { "No JumpShell commands matched query '$query'." }
        return New-ToolResult -Text $text -StructuredContent @{ query = $query; matches = @($matches) }
    }

    # Dynamic dispatch: resolve tool name to module command
    $commandName = $script:ToolNameToCommand[$ToolName]
    if (-not $commandName) {
        throw [System.ArgumentException]::new("Unknown tool: $ToolName. Use jumpshell_search to discover available tools.")
    }

    $invocation = Invoke-JumpShellCommand -CommandName $commandName -Arguments $Arguments
    return New-ToolResult -Text $invocation.text -StructuredContent $invocation
}

# --- Request handler ---

function Build-ServerInstructions {
    $fileMap = Get-FunctionFileMap
    $groups = $fileMap.GetEnumerator() | Group-Object Value | Sort-Object Name

    $categoryLines = foreach ($group in $groups) {
        $funcs = ($group.Group.Key | Sort-Object) -join ', '
        "  $($group.Name).ps1: $funcs"
    }

    $instructions = @"
JumpShell is a PowerShell utility module with $($fileMap.Count) functions organized by source file.
Every function is exposed as a directly-callable tool (tool name = lowercase function name with underscores instead of hyphens).
Use jumpshell_search to discover commands when unsure which to call.

Module categories:
$($categoryLines -join "`n")

To chain operations, call tools sequentially. For example, to mount an SSH drive, copy a file, decrypt it, and add a backup:
1. new_sshdrive — mount a remote filesystem
2. pgp_decrypt — decrypt an armored file
3. backup_directory — add a directory to backups

Tool arguments map directly to PowerShell parameter names (case-insensitive).
Switch parameters accept true/false boolean values.
"@

    return $instructions
}

function Handle-Request {
    param([hashtable]$Message)

    $id = $Message['id']
    $method = [string]$Message['method']
    $params = @{}
    if ($Message.ContainsKey('params') -and $null -ne $Message['params']) {
        $params = ConvertTo-Hashtable -InputObject $Message['params']
    }

    switch ($method) {
        'initialize' {
            $requestedProtocol = if ($params.ContainsKey('protocolVersion')) { [string]$params['protocolVersion'] } else { '' }
            $negotiatedProtocol = if ([string]::IsNullOrWhiteSpace($requestedProtocol)) { $script:ProtocolVersion } else { $requestedProtocol }

            $result = @{
                protocolVersion = $negotiatedProtocol
                capabilities = @{
                    tools = @{ listChanged = $false }
                }
                serverInfo = @{
                    name = 'jumpshell'
                    title = 'JumpShell PowerShell MCP'
                    version = '0.2.0'
                }
                instructions = (Build-ServerInstructions)
            }
            return New-JsonRpcResponse -Id $id -Result $result
        }

        'ping' {
            return New-JsonRpcResponse -Id $id -Result @{}
        }

        'logging/setLevel' {
            return New-JsonRpcResponse -Id $id -Result @{}
        }

        'tools/list' {
            return New-JsonRpcResponse -Id $id -Result @{ tools = (Get-ToolDefinitions) }
        }

        'tools/call' {
            if (-not $params.ContainsKey('name')) {
                return New-JsonRpcError -Id $id -Code -32602 -Message "Missing required 'name' in tools/call request." -Data $null
            }

            $toolName = [string]$params['name']
            $arguments = @{}
            if ($params.ContainsKey('arguments') -and $null -ne $params['arguments']) {
                $arguments = ConvertTo-Hashtable -InputObject $params['arguments']
            }

            try {
                $toolResult = Invoke-ToolCall -ToolName $toolName -Arguments $arguments
                return New-JsonRpcResponse -Id $id -Result $toolResult
            }
            catch [System.ArgumentException] {
                return New-JsonRpcError -Id $id -Code -32602 -Message $_.Exception.Message -Data $null
            }
            catch {
                $toolError = New-ToolResult -Text $_.Exception.Message -StructuredContent @{ tool = $toolName } -IsError
                return New-JsonRpcResponse -Id $id -Result $toolError
            }
        }

        default {
            return New-JsonRpcError -Id $id -Code -32601 -Message "Method not found: $method" -Data $null
        }
    }
}

# --- Main entry point ---

try {
    $manifestPath = Join-Path $script:ModuleRoot "$($script:ModuleName).psd1"
    if (-not (Test-Path $manifestPath)) {
        throw "JumpShell manifest not found: $manifestPath"
    }

    Import-Module $manifestPath -Force -Global -WarningAction SilentlyContinue | Out-Null
    [void](Get-ToolDefinitions)

    Write-ServerLog "JumpShell MCP server ready (protocol $($script:ProtocolVersion))."

    while ($true) {
        $line = [Console]::In.ReadLine()
        if ($null -eq $line) { break }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        try {
            $message = $line | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-ServerLog "Ignoring invalid JSON input: $($_.Exception.Message)"
            continue
        }

        if (-not $message.ContainsKey('method')) { continue }

        if ($message.ContainsKey('id')) {
            $response = Handle-Request -Message $message
            if ($response) { Write-JsonRpcMessage -Payload $response }
        }
    }

    Write-ServerLog 'Input stream closed. Server exiting.'
}
catch {
    Write-ServerLog "Fatal server error: $($_.Exception.Message)"
    exit 1
}
