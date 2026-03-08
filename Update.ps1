
function Update-Jumpshell {
    [CmdletBinding()]
    param(
        [switch]$NoPull,
        [switch]$Skills,
        [switch]$Mcps,
        [switch]$Modules,
        [switch]$Applications
    )
    $root = $Env:JumpShellPath

    
    $ModulePath = ($env:PSModulePath -split ';' | Select-Object -First 1)
    if (-not $NoPull) {
        Push-Location "$ModulePath\JumpshellPs"
        try {
            git pull
        }
        finally {
            Pop-Location
        }
    }

    $anyExplicit = $PSBoundParameters.ContainsKey('Skills') -or
    $PSBoundParameters.ContainsKey('Mcps') -or
    $PSBoundParameters.ContainsKey('Modules') -or
    $PSBoundParameters.ContainsKey('Applications')

    $runSkills = $Skills.IsPresent
    $runMcps = $Mcps.IsPresent
    $runModules = $Modules.IsPresent
    $runApplications = $Applications.IsPresent

    if (-not $anyExplicit) {
        # Load hash helpers into function scope (not exported to module)
        . (Join-Path $root 'Install\Get-InstallHashes.ps1')

        $cachePath = Join-Path $root 'Install\.module-deps-cache'
        $cache = if (Test-Path $cachePath) {
            try { Get-Content $cachePath -Raw | ConvertFrom-Json } catch { $null }
        }
        else { $null }

        $currentSkillsHash = Get-SkillsHash -ModuleRoot $root
        $currentModulesHash = Get-ModulesManifestHash -ModuleRoot $root
        $cachedSkillsHash = if ($null -ne $cache) { $cache.SkillsHash } else { $null }
        $cachedModulesHash = if ($null -ne $cache) { $cache.ModulesHash } else { $null }

        $runSkills = $currentSkillsHash -ne $cachedSkillsHash
        $runModules = $currentModulesHash -ne $cachedModulesHash
        $runMcps = $true  # lightweight idempotent
        $runApplications = $true  # has its own internal caching
    }

    & (Join-Path $root 'Install.ps1') `
        -ModuleRoot $root `
        -NoPull:$NoPull `
        -Skills:$runSkills `
        -Mcps:$runMcps `
        -Modules:$runModules `
        -Applications:$runApplications
}
