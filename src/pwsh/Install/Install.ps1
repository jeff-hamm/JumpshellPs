# Install-Requirements.ps1
# Check for required modules by reading from the manifest (with caching)

param(
    [string]$ModuleRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))),
    [switch]$All,
    [switch]$Skills,
    [switch]$Mcps,
    [switch]$Modules,
    [switch]$Applications
)

. (Join-Path $PSScriptRoot 'Get-InstallHashes.ps1')

function Update-InstallCache {
    param([string]$CacheFilePath, [hashtable]$Updates)
    $obj = if (Test-Path $CacheFilePath) {
        try { Get-Content $CacheFilePath -Raw | ConvertFrom-Json } catch { [PSCustomObject]@{} }
    } else { [PSCustomObject]@{} }
    foreach ($kv in $Updates.GetEnumerator()) {
        $obj | Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value -Force
    }
    $obj | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $CacheFilePath -Encoding UTF8
}

# When no specific flags given, install everything
$installAll = $All -or -not ($Skills -or $Mcps -or $Modules -or $Applications)
$moduleSourceRoot = Split-Path -Parent $PSScriptRoot

# Source the Applications.ps1 file to load the application management functions
. (Join-Path (Split-Path $PSScriptRoot) 'Applications.ps1')
$cacheFilePath = Join-Path $ModuleRoot '.module-deps-cache'

if ($Applications -or $installAll) {
    Ensure-Applications -FileName (Join-Path $PSScriptRoot 'Required-Applications.txt') -CacheFilePath $cacheFilePath
    if ($All) {
        Ensure-Applications -FileName (Join-Path $PSScriptRoot 'All-Applications.txt') -CacheFilePath $cacheFilePath
    }
}

if ($Modules -or $installAll) {
    & (Join-Path $PSScriptRoot 'Install-PowerShellModules.ps1') -ModuleRoot $ModuleRoot -CacheFilePath $cacheFilePath
    Update-InstallCache -CacheFilePath $cacheFilePath -Updates @{ ModulesHash = (Get-ModulesManifestHash -ModuleRoot $ModuleRoot) }
}

if ($Mcps -or $installAll) {
    $mcpInstallScript = Join-Path $moduleSourceRoot 'mcp\Install-Mcp.ps1'
    if (Test-Path $mcpInstallScript) {
        try {
            $mcpConfig = & $mcpInstallScript -ModuleRoot $moduleSourceRoot -Scope User -WorkspaceRoot $ModuleRoot
            Write-Host "Configured JumpShell MCP server in $($mcpConfig.Path)" -ForegroundColor DarkCyan
        }
        catch {
            Write-Warning "Failed to configure JumpShell MCP server: $($_.Exception.Message)"
        }
    }
}

if ($Skills -or $installAll) {
    $skillsSource = Join-Path $ModuleRoot 'skills'
    if (Test-Path $skillsSource) {
        $agentSkillsDir = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.agents\skills'
        if (-not (Test-Path $agentSkillsDir)) {
            New-Item -ItemType Directory -Path $agentSkillsDir -Force | Out-Null
        }
        foreach ($skillDir in Get-ChildItem -LiteralPath $skillsSource -Directory) {
            $linkPath = Join-Path $agentSkillsDir $skillDir.Name
            $existing = Get-Item -LiteralPath $linkPath -ErrorAction SilentlyContinue
            if ($existing) {
                if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $skillDir.FullName) {
                    Write-Debug "Skill symlink already up-to-date: $linkPath"
                    continue
                }
                Write-Host "Updating skill symlink: $($skillDir.Name)" -ForegroundColor DarkCyan
                Remove-Item -LiteralPath $linkPath -Force -Recurse
            } else {
                Write-Host "Installing skill symlink: $($skillDir.Name)" -ForegroundColor Cyan
            }
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $skillDir.FullName | Out-Null
        }
    }
    Update-InstallCache -CacheFilePath $cacheFilePath -Updates @{ SkillsHash = (Get-SkillsHash -ModuleRoot $ModuleRoot) }
}