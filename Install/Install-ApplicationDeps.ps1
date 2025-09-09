# Install-ApplicationDeps.ps1
# Install required applications via winget

param(
    [string]$ModuleRoot = $PSScriptRoot,
    [string]$CacheFilePath = (Join-Path $ModuleRoot '.module-deps-cache'),
    [string[]]$RequiredApplications = $(& (Join-Path $PSScriptRoot 'Required-Applications.ps1'))
)
if ($RequiredApplications.Count -gt 0) {
    $appHash = ($RequiredApplications | Sort-Object | ConvertTo-Json -Compress | Get-FileHash -Algorithm SHA256).Hash
    $installedApplications = @()
    $needsAppCheck = $true
    
    # Check if cache file exists and load installed applications
    if (Test-Path $CacheFilePath) {
        try {
            $cache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            if ($cache.AppHash -ne $appHash -or $cache.CheckDate -gt (Get-Date).AddDays(-7)) {
                $installedApplications = if ($cache.InstalledApplications) { $cache.InstalledApplications } else { @() }
                $needsAppCheck = $false
                Write-Debug "Using cached application list (valid until $($cache.CheckDate.AddDays(7)))"
            } else {
                Write-Debug "Cache file outdated, will regenerate"
            }
        }
        catch {
            # Cache file corrupted, will regenerate
            Write-Debug "Cache file corrupted, will regenerate"
        }
    }
    
    if ($needsAppCheck) {
        Write-Debug "Checking installed applications..."
        # Check which applications are actually installed
        $installedApplications = @()
        foreach ($appId in $RequiredApplications) {
            try {
                $result = winget list --id $appId --exact 2>$null
                if ($LASTEXITCODE -eq 0 -and $result -match $appId) {
                    $installedApplications += $appId
                }
            }
            catch {
                # Application not found, will be installed
            }
        }
    }
    
    # Find missing applications
    $missingApplications = $RequiredApplications | Where-Object { $_ -notin $installedApplications }
    
    if ($missingApplications.Count -gt 0) {
        Write-Warning "Missing required applications: $($missingApplications -join ', ')"
        Write-Host "Installing missing applications..." -ForegroundColor Yellow
        
        foreach ($appId in $missingApplications) {
            try {
                Write-Host "Installing $appId..." -ForegroundColor Cyan
                winget install -e --id $appId --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ $appId installed successfully" -ForegroundColor Green
                    $installedApplications += $appId
                } else {
                    Write-Warning "Failed to install $appId (exit code: $LASTEXITCODE)"
                }
            }
            catch {
                Write-Error "Failed to install $appId`: $_"
            }
        }
    }
    
    # Update cache with both modules and applications
    if (Test-Path $CacheFilePath) {
        $existingCache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
        $cacheData = @{
            Hash = if ($existingCache.Hash) { $existingCache.Hash } else { "" }
            AppHash = $appHash
            CheckDate = Get-Date
            InstalledModules = if ($existingCache.InstalledModules) { $existingCache.InstalledModules } else { @() }
            InstalledApplications = $installedApplications | Sort-Object
        }
    } else {
        $cacheData = @{
            Hash = ""
            AppHash = $appHash
            CheckDate = Get-Date
            InstalledModules = @()
            InstalledApplications = $installedApplications | Sort-Object
        }
    }
    $cacheData | ConvertTo-Json | Set-Content $CacheFilePath -Force
    
    if ($missingApplications.Count -eq 0) {
        Write-Debug "All required applications are available"
    }
}
