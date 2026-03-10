$script:JumpshellMcpServerName = 'jumpshell'

function _Get-JumpshellModuleRoot {
    if ($global:JumpshellRepoRoot) {
        return $global:JumpshellRepoRoot
    }
    if ($env:JumpshellPath) {
        return $env:JumpshellPath
    }
    return Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function _Get-JumpshellSourceRoot {
    if ($global:JumpshellSourcePath) {
        return $global:JumpshellSourcePath
    }

    $moduleRoot = _Get-JumpshellModuleRoot
    $sourceCandidate = Join-Path $moduleRoot 'src\pwsh'
    if (Test-Path -LiteralPath (Join-Path $sourceCandidate 'Jumpshell.psd1')) {
        return $sourceCandidate
    }

    if (Test-Path -LiteralPath (Join-Path $moduleRoot 'Jumpshell.psd1')) {
        return $moduleRoot
    }

    return $PSScriptRoot
}

function _Test-JumpshellMcpAutoStartEnabled {
    if ($env:JUMPSHELL_MCP_DISABLE_AUTOSTART -eq '1') {
        return $false
    }

    $setting = $env:JUMPSHELL_MCP_AUTOSTART
    if ([string]::IsNullOrWhiteSpace($setting)) {
        return $true
    }

    switch ($setting.ToLowerInvariant()) {
        '0' { return $false }
        'false' { return $false }
        'off' { return $false }
        'no' { return $false }
        default { return $true }
    }
}

function _Get-JumpshellMcpDirectory {
    if (Get-Command -Name Get-JumpDir -ErrorAction SilentlyContinue) {
        $jumpDir = Get-JumpDir
    }
    else {
        $jumpDir = Join-Path $HOME '.jumpshell'
        if (-not (Test-Path $jumpDir)) {
            New-Item -ItemType Directory -Path $jumpDir -Force | Out-Null
        }
    }

    $mcpDir = Join-Path $jumpDir 'mcp'
    if (-not (Test-Path $mcpDir)) {
        New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
    }

    return $mcpDir
}

function _Get-JumpshellMcpServerScriptPath {
    $sourceRoot = _Get-JumpshellSourceRoot
    $scriptPath = Join-Path $sourceRoot 'mcp\server.ps1'
    if (Test-Path -LiteralPath $scriptPath) {
        return $scriptPath
    }

    throw "Jumpshell MCP server script is missing under source root '$sourceRoot': $scriptPath"
}

function _Get-JumpshellMcpStatePath {
    return Join-Path (_Get-JumpshellMcpDirectory) 'server-state.json'
}

function _Read-JumpshellMcpState {
    $statePath = _Get-JumpshellMcpStatePath
    if (-not (Test-Path $statePath)) {
        return $null
    }

    try {
        return Get-Content -Raw $statePath | ConvertFrom-Json -AsHashtable
    }
    catch {
        Remove-Item -Path $statePath -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function _Write-JumpshellMcpState {
    param([hashtable]$State)

    $statePath = _Get-JumpshellMcpStatePath
    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath -Encoding UTF8
}

function _Remove-JumpshellMcpState {
    $statePath = _Get-JumpshellMcpStatePath
    Remove-Item -Path $statePath -Force -ErrorAction SilentlyContinue
}

function Get-JumpshellMcp {
    [CmdletBinding()]
    param()

    $moduleRoot = _Get-JumpshellSourceRoot
    $serverScript = _Get-JumpshellMcpServerScriptPath
    $mcpDir = _Get-JumpshellMcpDirectory
    $state = _Read-JumpshellMcpState

    $process = $null
    if ($state -and $state.pid) {
        $process = Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    }

    $isRunning = $null -ne $process -and -not $process.HasExited
    if (-not $isRunning -and $state) {
        _Remove-JumpshellMcpState
    }

    return [pscustomobject]@{
        ServerName = $script:JumpshellMcpServerName
        IsRunning = $isRunning
        ProcessId = if ($isRunning) { $process.Id } else { $null }
        StartedAt = if ($state) { $state.startedAt } else { $null }
        ModuleRoot = $moduleRoot
        ServerScript = $serverScript
        StdOutLog = if ($state -and $state.stdoutLog) { $state.stdoutLog } else { Join-Path $mcpDir 'server.stdout.log' }
        StdErrLog = if ($state -and $state.stderrLog) { $state.stderrLog } else { Join-Path $mcpDir 'server.stderr.log' }
        StatePath = _Get-JumpshellMcpStatePath
    }
}

function Stop-JumpshellMcpServer {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $status = Get-JumpshellMcp
    if ($status.IsRunning -and $status.ProcessId) {
        Stop-Process -Id $status.ProcessId -Force:$Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 100
    }

    _Remove-JumpshellMcpState
    return Get-JumpshellMcp
}

function Start-JumpshellMcpServer {
    [CmdletBinding()]
    param(
        [switch]$Force,

        [switch]$OnImport,

        [switch]$Quiet
    )

    if ($OnImport) {
        if ($env:JUMPSHELL_MCP_SERVER_MODE -eq '1') {
            return Get-JumpshellMcp
        }

        if (-not (_Test-JumpshellMcpAutoStartEnabled)) {
            return Get-JumpshellMcp
        }
    }

    $status = Get-JumpshellMcp
    if ($status.IsRunning -and -not $Force) {
        return $status
    }

    if ($status.IsRunning -and $Force) {
        Stop-JumpshellMcpServer -Force | Out-Null
    }

    $moduleRoot = _Get-JumpshellSourceRoot
    $serverScript = _Get-JumpshellMcpServerScriptPath
    if (-not (Test-Path $serverScript)) {
        throw "Jumpshell MCP server script is missing: $serverScript"
    }

    $pwsh = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pwsh) {
        throw 'pwsh executable was not found in PATH. Install PowerShell 7 to run the MCP server.'
    }

    $mcpDir = _Get-JumpshellMcpDirectory
    $stdoutLog = Join-Path $mcpDir 'server.stdout.log'
    $stderrLog = Join-Path $mcpDir 'server.stderr.log'

    $serverArgs = @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $serverScript,
        '-ModuleRoot',
        $moduleRoot
    )

    $startParams = @{
        FilePath = $pwsh.Source
        ArgumentList = $serverArgs
        WorkingDirectory = $moduleRoot
        RedirectStandardOutput = $stdoutLog
        RedirectStandardError = $stderrLog
        WindowStyle = 'Hidden'
        PassThru = $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $startParams['Environment'] = @{
            JUMPSHELL_MCP_DISABLE_AUTOSTART = '1'
            JUMPSHELL_MCP_SERVER_MODE = '1'
            TERM_PROGRAM = 'mcp'
        }
    }

    $process = Start-Process @startParams
    if (-not $process) {
        throw 'Failed to start Jumpshell MCP server process.'
    }

    _Write-JumpshellMcpState -State @{
        pid = $process.Id
        startedAt = (Get-Date).ToString('o')
        moduleRoot = $moduleRoot
        serverScript = $serverScript
        stdoutLog = $stdoutLog
        stderrLog = $stderrLog
    }

    Start-Sleep -Milliseconds 250
    $latest = Get-JumpshellMcp

    if (-not $Quiet -and -not $latest.IsRunning) {
        Write-Warning "Jumpshell MCP server process started but did not report as running. Check logs at '$stderrLog'."
    }

    return $latest
}

function Install-JumpshellMcp {
    [CmdletBinding()]
    param(
        [ValidateSet('User', 'Workspace')]
        [string]$Scope = 'User'
    )

    $moduleRoot = _Get-JumpshellModuleRoot
    $moduleSourceRoot = _Get-JumpshellSourceRoot
    $installScript = Join-Path $moduleSourceRoot 'mcp\Install-Mcp.ps1'
    if (-not (Test-Path $installScript)) {
        throw "Jumpshell MCP install script not found: $installScript"
    }

    return & $installScript -ModuleRoot $moduleSourceRoot -Scope $Scope -WorkspaceRoot $moduleRoot
}
