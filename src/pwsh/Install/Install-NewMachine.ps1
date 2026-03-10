# # Install-NewMachine.ps1
# # Install applications for new machine setup

# param(
#     [string]$ModuleRoot = $PSScriptRoot,
#     [string]$CacheFilePath = (Join-Path $ModuleRoot '.module-deps-cache')
# )

# # Get required applications for new machine setup
# $requiredApplications = & (Join-Path $PSScriptRoot 'Required-Applications.ps1')
# Ensure-Applications -RequiredApplications $requiredApplications -CacheFilePath $CacheFilePath

# function Install-NewMachine {
#     [CmdletBinding()]
#     param(
#         [string]$ModuleRoot = $PSScriptRoot,
#         [string]$CacheFilePath = (Join-Path $ModuleRoot '.module-deps-cache')
#     )
    
#     Write-Host "Installing new machine applications..." -ForegroundColor Green
    
#     # Get the new machine applications list
#     $newMachineApplications = & (Join-Path $PSScriptRoot 'New-MachineApplications.ps1') -NewMachine
    
#     if ($newMachineApplications.Count -gt 0) {
#         Write-Host "New machine applications to install: $($newMachineApplications -join ', ')" -ForegroundColor Cyan
        
#         # Use the same logic as Install-ApplicationDeps but for new machine apps
#         Install-Applications -RequiredApplications $newMachineApplications -CacheFilePath $CacheFilePath -CachePrefix "NewMachine"
#     }
#     else {
#         Write-Host "No new machine applications to install" -ForegroundColor Yellow
#     }
# }

# function Install-Applications {
#     [CmdletBinding()]
#     param(
#         [string[]]$RequiredApplications,
#         [string]$CacheFilePath,
#         [string]$CachePrefix = "App"
#     )
    
#     if ($RequiredApplications.Count -gt 0) {
#         $appHash = ($RequiredApplications | Sort-Object | ConvertTo-Json -Compress | Get-FileHash -Algorithm SHA256).Hash
#         $installedApplications = @()
#         $needsAppCheck = $true
        
#         # Check if cache file exists and load installed applications
#         if (Test-Path $CacheFilePath) {
#             try {
#                 $cache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
#                 $cacheHashKey = "${CachePrefix}Hash"
#                 $cacheAppsKey = "Installed${CachePrefix}Applications"
                
#                 if ($cache.$cacheHashKey -eq $appHash -and $cache.CheckDate -gt (Get-Date).AddDays(-7)) {
#                     $installedApplications = if ($cache.$cacheAppsKey) { $cache.$cacheAppsKey } else { @() }
#                     $needsAppCheck = $false
#                     Write-Debug "Using cached $CachePrefix application list (valid until $($cache.CheckDate.AddDays(7)))"
#                 }
#             }
#             catch {
#                 Write-Debug "Cache file corrupted, will regenerate"
#             }
#         }
        
#         if ($needsAppCheck) {
#             Write-Debug "Checking installed $CachePrefix applications..."
#             $installedApplications = @()
#             foreach ($appId in $RequiredApplications) {
#                 try {
#                     $result = winget list --id $appId --exact 2>$null
#                     if ($LASTEXITCODE -eq 0 -and $result -match $appId) {
#                         $installedApplications += $appId
#                     }
#                 }
#                 catch {
#                     # Application not found, will be installed
#                 }
#             }
#         }
        
#         # Find missing applications
#         $missingApplications = $RequiredApplications | Where-Object { $_ -notin $installedApplications }
        
#         if ($missingApplications.Count -gt 0) {
#             Write-Warning "Missing $CachePrefix applications: $($missingApplications -join ', ')"
#             Write-Host "Installing missing $CachePrefix applications..." -ForegroundColor Yellow
            
#             foreach ($appId in $missingApplications) {
#                 try {
#                     Write-Host "Installing $appId..." -ForegroundColor Cyan
#                     winget install -e --id $appId --silent --accept-package-agreements --accept-source-agreements
#                     if ($LASTEXITCODE -eq 0) {
#                         Write-Host "✓ $appId installed successfully" -ForegroundColor Green
#                         $installedApplications += $appId
#                     }
#                     else {
#                         Write-Warning "Failed to install $appId (exit code: $LASTEXITCODE)"
#                     }
#                 }
#                 catch {
#                     Write-Error "Failed to install $appId`: $_"
#                 }
#             }
#         }
        
#         # Update cache
#         if (Test-Path $CacheFilePath) {
#             $existingCache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
#         }
#         else {
#             $existingCache = @{}
#         }
        
#         $cacheHashKey = "${CachePrefix}Hash"
#         $cacheAppsKey = "Installed${CachePrefix}Applications"
        
#         $existingCache.$cacheHashKey = $appHash
#         $existingCache.CheckDate = Get-Date
#         $existingCache.$cacheAppsKey = $installedApplications | Sort-Object
        
#         # Preserve other cache data
#         if (-not $existingCache.Hash) { $existingCache.Hash = "" }
#         if (-not $existingCache.AppHash) { $existingCache.AppHash = "" }
#         if (-not $existingCache.InstalledModules) { $existingCache.InstalledModules = @() }
#         if (-not $existingCache.InstalledApplications) { $existingCache.InstalledApplications = @() }
        
#         $existingCache | ConvertTo-Json | Set-Content $CacheFilePath -Force
        
#         if ($missingApplications.Count -eq 0) {
#             Write-Debug "All required $CachePrefix applications are available"
#         }
#     }
# }

# # Export the function for use by other scripts
# Export-ModuleMember -Function Install-NewMachine, Install-Applications
