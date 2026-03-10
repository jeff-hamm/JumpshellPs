# Install-PowerShellModules.ps1
# Install required PowerShell modules from manifest with caching

param(
    [string]$ModuleRoot,
    [string]$CacheFilePath
)

$manifestPath = Join-Path $ModuleRoot 'JumpshellPs.psd1'
& (Join-Path $PSScriptRoot 'Install-HomeAssistantModule.ps1') -ModulePath (Split-Path $ModuleRoot)

if (Test-Path $manifestPath) {
    # Check if we can skip processing based on manifest file timestamp and cache
    if ((Test-Path $CacheFilePath)) {
        try {
            $cache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            $manifestLastWrite = (Get-Item $manifestPath).LastWriteTime
            
            # If cache is valid and manifest hasn't been modified since last check, skip processing
            if ($cache.CheckDate -and $manifestLastWrite -le $cache.CheckDate -and $cache.CheckDate -gt (Get-Date).AddDays(-7) -and $cache.Hash) {
                Write-Debug "Manifest '$manifestPath' hasn't changed since last check ($($cache.CheckDate)). Skipping module check."
                return
            }
            else {
                Write-Debug "Manifest '$manifestPath' was modified at $manifestLastWrite, cache date is $($cache.CheckDate). Will process modules."
            }
        }
        catch {
            Write-Debug "Could not read cache or manifest timestamp, will process modules."
        }
    }
    
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $requiredModules = $manifest.RequiredModules
    
    if ($requiredModules -and $requiredModules.Count -gt 0) {
        # Normalize required modules to just names
        $requiredModuleNames = @()
        foreach ($module in $requiredModules) {
            $moduleName = if ($module -is [string]) { $module } else { $module.ModuleName }
            $requiredModuleNames += $moduleName
        }
        
        $moduleHash = ($requiredModuleNames | Sort-Object | ConvertTo-Json -Compress | Get-FileHash -Algorithm SHA256).Hash
        $installedModules = @()
        $needsCheck = $true
        
        # Check if cache file exists and is valid
        if (Test-Path $CacheFilePath) {
            try {
                $cache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
                if ($cache.Hash -eq $moduleHash -and $cache.CheckDate -gt (Get-Date).AddDays(-7)) {
                    $installedModules = if ($cache.InstalledModules) { $cache.InstalledModules } else { @() }
                    $needsCheck = $false
                    Write-Debug "Using cached module list (valid until $($cache.CheckDate.AddDays(7)))"
                } else {
                    Write-Debug "Cache file outdated or hash mismatch, will regenerate"
                }
            }
            catch {
                # Cache file corrupted, will regenerate
                Write-Debug "Cache file corrupted, will regenerate"
            }
        }
        
        if ($needsCheck) {
            Write-Debug "Checking available modules..."
            # Get list of actually available modules
            $installedModules = @()
            foreach ($moduleName in $requiredModuleNames) {
                if (Get-Module -ListAvailable -Name $moduleName) {
                    $installedModules += $moduleName
                }
            }
        }
        
        # Find missing modules by comparing required vs installed
        $missingModules = $requiredModuleNames | Where-Object { $_ -notin $installedModules }
        
        if ($missingModules.Count -gt 0) {
            Write-Warning "Missing required modules: $($missingModules -join ', ')"
            Write-Host "Installing missing modules..." -ForegroundColor Yellow
            
            foreach ($moduleName in $missingModules) {
                try {
                    Write-Host "Installing $moduleName..." -ForegroundColor Cyan
                    Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
                    Write-Host "✓ $moduleName installed successfully" -ForegroundColor Green
                    # Add to installed list
                    $installedModules += $moduleName
                }
                catch {
                    Write-Error "Failed to install $moduleName`: $_"
                }
            }
        }
        
        # Update cache with current state (preserve existing application data)
        if (Test-Path $CacheFilePath) {
            $existingCache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            $cacheData = @{
                Hash = $moduleHash
                AppHash = if ($existingCache.AppHash) { $existingCache.AppHash } else { "" }
                CheckDate = Get-Date
                InstalledModules = $installedModules | Sort-Object
                InstalledApplications = if ($existingCache.InstalledApplications) { $existingCache.InstalledApplications } else { @() }
            }
        } else {
            $cacheData = @{
                Hash = $moduleHash
                AppHash = ""
                CheckDate = Get-Date
                InstalledModules = $installedModules | Sort-Object
                InstalledApplications = @()
            }
        }
        $cacheData | ConvertTo-Json | Set-Content $CacheFilePath -Force
        
        if ($missingModules.Count -eq 0) {
            Write-Debug "All required modules are available"
        }
    }
}
