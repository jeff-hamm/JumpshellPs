param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),

    [ValidateSet('User', 'Workspace')]
    [string]$Scope = 'User',

    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),

    [string]$ServerName = 'jumpshellPs'
)

$ErrorActionPreference = 'Stop'

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

function Resolve-UserMcpPath {
    $baseCandidates = @()

    if ($env:VSCODE_APPDATA) {
        $baseCandidates += $env:VSCODE_APPDATA
    }

    if ($env:VSCODE_PORTABLE) {
        $baseCandidates += (Join-Path $env:VSCODE_PORTABLE 'user-data')
    }

    $baseCandidates += @(
        (Join-Path $env:APPDATA 'Code - Insiders'),
        (Join-Path $env:APPDATA 'Code'),
        (Join-Path $env:APPDATA 'Cursor'),
        (Join-Path $env:APPDATA 'VSCodium')
    )

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

    return (Join-Path (Join-Path $env:APPDATA 'Code\User') 'mcp.json')
}

function Resolve-McpConfigPath {
    param(
        [ValidateSet('User', 'Workspace')]
        [string]$TargetScope
    )

    if ($TargetScope -eq 'Workspace') {
        return (Join-Path $WorkspaceRoot '.vscode\mcp.json')
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

$config['servers'] = ConvertTo-Hashtable -InputObject $config['servers']
$serverConfig = Get-ServerConfig -ResolvedModuleRoot $ModuleRoot
$config['servers'][$ServerName] = $serverConfig

$config | ConvertTo-Json -Depth 30 | Set-Content -Path $targetPath -Encoding UTF8

[pscustomobject]@{
    Scope = $Scope
    ServerName = $ServerName
    Path = $targetPath
    ModuleRoot = $ModuleRoot
    ServerScript = (Join-Path $ModuleRoot 'mcp\server.ps1')
}
