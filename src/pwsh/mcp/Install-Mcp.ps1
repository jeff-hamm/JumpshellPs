param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),

    [ValidateSet('User', 'Workspace')]
    [string]$Scope = 'User',

    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),

    [string]$ServerName = 'jumpshell'
)

$ErrorActionPreference = 'Stop'

function Resolve-ModuleSourceRoot {
    param([string]$RequestedRoot)

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $candidates += $RequestedRoot
    }

    $candidates += (Split-Path -Parent $PSScriptRoot)

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        $sourceCandidate = Join-Path $candidate 'src\pwsh'
        $manifestAtSource = Join-Path $sourceCandidate 'Jumpshell.psd1'
        if (Test-Path -LiteralPath $manifestAtSource) {
            return $sourceCandidate
        }

        $manifestAtRoot = Join-Path $candidate 'Jumpshell.psd1'
        if (Test-Path -LiteralPath $manifestAtRoot) {
            return $candidate
        }
    }

    return $RequestedRoot
}

function ConvertTo-Hashtable {
    param([object]$InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [hashtable]) {
        $copy = @{}
        foreach ($key in $InputObject.Keys) {
            $copy[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }

        return $copy
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[[string]$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }

        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-Hashtable -InputObject $item
        }

        return $items
    }

    if ($InputObject -is [psobject] -and $InputObject.PSObject.Properties.Count -gt 0) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }

        return $result
    }

    return $InputObject
}

function Get-ActiveProfilePath {
    param([string]$BasePath)

    $storagePath = Join-Path $BasePath 'User\globalStorage\storage.json'
    if (-not (Test-Path $storagePath)) {
        return $null
    }

    try {
        $storage = Get-Content -Raw $storagePath | ConvertFrom-Json -AsHashtable
    }
    catch {
        return $null
    }

    $profileId = $storage['userDataProfiles.profile']
    if ([string]::IsNullOrWhiteSpace([string]$profileId)) {
        return $null
    }

    $profilePath = Join-Path $BasePath ("User\\profiles\\$profileId")
    if (Test-Path $profilePath) {
        return $profilePath
    }

    return $null
}

function Get-EditorVariant {
    $hints = @(
        $env:VSCODE_GIT_ASKPASS_MAIN,
        $env:VSCODE_IPC_HOOK,
        $env:VSCODE_CWD,
        $env:TERM_PROGRAM,
        $env:TERM_PROGRAM_VERSION
    )

    if ($env:VSCODE_PID -and ($env:VSCODE_PID -as [int])) {
        try {
            $hostProcess = Get-Process -Id ([int]$env:VSCODE_PID) -ErrorAction Stop
            $hints += $hostProcess.ProcessName
            if ($hostProcess.Path) {
                $hints += $hostProcess.Path
            }
        }
        catch {
            # Ignore process lookup failures.
        }
    }

    $hintText = ($hints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
    if ($hintText -match 'Cursor') {
        return 'Cursor'
    }

    if ($hintText -match 'Code - Insiders|code-insiders') {
        return 'Code - Insiders'
    }

    if ($hintText -match 'VSCodium|Codium') {
        return 'VSCodium'
    }

    return 'Code'
}

function Get-PreferredEditorOrder {
    switch (Get-EditorVariant) {
        'Cursor' { return @('Cursor', 'Code', 'Code - Insiders', 'VSCodium') }
        'Code - Insiders' { return @('Code - Insiders', 'Code', 'Cursor', 'VSCodium') }
        'VSCodium' { return @('VSCodium', 'Code', 'Code - Insiders', 'Cursor') }
        default { return @('Code', 'Code - Insiders', 'Cursor', 'VSCodium') }
    }
}

function Get-EditorBasePath {
    param([string]$Editor)

    if ($IsWindows) {
        if (-not $env:APPDATA) {
            return $null
        }

        return (Join-Path $env:APPDATA $Editor)
    }

    if ($IsMacOS) {
        return (Join-Path (Join-Path $HOME 'Library/Application Support') $Editor)
    }

    return (Join-Path (Join-Path $HOME '.config') $Editor)
}

function Resolve-WorkspaceMcpDirectory {
    $cursorMcpPath = Join-Path $WorkspaceRoot '.cursor\mcp.json'
    $vscodeMcpPath = Join-Path $WorkspaceRoot '.vscode\mcp.json'

    $hasCursorMcp = Test-Path -LiteralPath $cursorMcpPath
    $hasVsCodeMcp = Test-Path -LiteralPath $vscodeMcpPath

    if ($hasCursorMcp -and -not $hasVsCodeMcp) {
        return '.cursor'
    }

    if ($hasVsCodeMcp -and -not $hasCursorMcp) {
        return '.vscode'
    }

    if ((Get-EditorVariant) -eq 'Cursor') {
        return '.cursor'
    }

    return '.vscode'
}

function Resolve-UserMcpPath {
    $baseCandidates = @()

    if ($env:VSCODE_APPDATA) {
        $baseCandidates += $env:VSCODE_APPDATA
    }

    if ($env:VSCODE_PORTABLE) {
        $baseCandidates += (Join-Path $env:VSCODE_PORTABLE 'user-data')
    }

    $editorOrder = Get-PreferredEditorOrder
    foreach ($editor in $editorOrder) {
        $editorBasePath = Get-EditorBasePath -Editor $editor
        if (-not [string]::IsNullOrWhiteSpace($editorBasePath)) {
            $baseCandidates += $editorBasePath
        }
    }

    foreach ($basePath in ($baseCandidates | Select-Object -Unique)) {
        if (-not (Test-Path $basePath)) {
            continue
        }

        $userPath = Join-Path $basePath 'User'
        if (-not (Test-Path $userPath)) {
            continue
        }

        $activeProfilePath = Get-ActiveProfilePath -BasePath $basePath
        if ($activeProfilePath) {
            return (Join-Path $activeProfilePath 'mcp.json')
        }

        return (Join-Path $userPath 'mcp.json')
    }

    $fallbackBase = $null
    foreach ($editor in $editorOrder) {
        $fallbackCandidate = Get-EditorBasePath -Editor $editor
        if (-not [string]::IsNullOrWhiteSpace($fallbackCandidate)) {
            $fallbackBase = $fallbackCandidate
            break
        }
    }

    if ($fallbackBase) {
        return (Join-Path (Join-Path $fallbackBase 'User') 'mcp.json')
    }

    $defaultConfigRoot = Join-Path $HOME '.config'
    return (Join-Path (Join-Path (Join-Path $defaultConfigRoot 'Code') 'User') 'mcp.json')
}

function Resolve-McpConfigPath {
    param(
        [ValidateSet('User', 'Workspace')]
        [string]$TargetScope
    )

    if ($TargetScope -eq 'Workspace') {
        $workspaceMcpDirectory = Resolve-WorkspaceMcpDirectory
        return (Join-Path (Join-Path $WorkspaceRoot $workspaceMcpDirectory) 'mcp.json')
    }

    return Resolve-UserMcpPath
}

function Get-ServerConfig {
    param([string]$ResolvedModuleRoot)

    $serverScript = Join-Path $ResolvedModuleRoot 'mcp\server.ps1'

    return @{
        type = 'stdio'
        command = 'pwsh'
        args = @(
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            $serverScript,
            '-ModuleRoot',
            $ResolvedModuleRoot
        )
        env = @{
            JUMPSHELL_MCP_DISABLE_AUTOSTART = '1'
            TERM_PROGRAM = 'mcp'
        }
    }
}

$targetPath = Resolve-McpConfigPath -TargetScope $Scope
$targetDir = Split-Path -Parent $targetPath
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$config = @{}
if (Test-Path $targetPath) {
    $raw = Get-Content -Raw $targetPath
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $config = ConvertTo-Hashtable -InputObject (ConvertFrom-Json -InputObject $raw)
        }
        catch {
            throw "Could not parse existing MCP config at '$targetPath': $($_.Exception.Message)"
        }
    }
}

if (-not $config) {
    $config = @{}
}

if (-not $config.ContainsKey('servers') -or $null -eq $config['servers']) {
    $config['servers'] = @{}
}

$resolvedModuleRoot = Resolve-ModuleSourceRoot -RequestedRoot $ModuleRoot

$config['servers'] = ConvertTo-Hashtable -InputObject $config['servers']
$serverConfig = Get-ServerConfig -ResolvedModuleRoot $resolvedModuleRoot
$config['servers'][$ServerName] = $serverConfig

$config | ConvertTo-Json -Depth 30 | Set-Content -Path $targetPath -Encoding UTF8

[pscustomobject]@{
    Scope = $Scope
    ServerName = $ServerName
    Path = $targetPath
    ModuleRoot = $resolvedModuleRoot
    ServerScript = (Join-Path $resolvedModuleRoot 'mcp\server.ps1')
}
