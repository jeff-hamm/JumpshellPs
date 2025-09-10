
# Get-ApplicationsFromFile function
function Get-ApplicationsFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )
    
    if (-not (Test-Path $FileName)) {
        Write-Error "File not found: $FileName"
        return @()
    }
    
    $extension = [System.IO.Path]::GetExtension($FileName).ToLower()
    
    switch ($extension) {
        '.ps1' {
            # Execute PowerShell script and return result
            return & $FileName
        }
        '.json' {
            # Parse JSON array
            $jsonContent = Get-Content $FileName -Raw | ConvertFrom-Json
            if ($jsonContent -is [array]) {
                return $jsonContent
            }
            else {
                Write-Warning "JSON file does not contain an array: $FileName"
                return @()
            }
        }
        default {
            # Parse as newline-delimited list
            return Get-Content $FileName | 
                Where-Object { $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#') } |
                ForEach-Object { $_.Trim() }
        }
    }
}

# Add-ApplicationToFile function
function Add-ApplicationToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string[]]$Applications
    )
    
    if ($Applications.Count -eq 0) {
        return
    }
    
    $extension = [System.IO.Path]::GetExtension($FileName).ToLower()
    
    switch ($extension) {
        '.ps1' {
            # For PowerShell files, we can't easily append since they might have complex logic
            # Instead, we'll warn the user
            Write-Warning "Cannot automatically append to PowerShell script file: $FileName. Applications to add: $($Applications -join ', ')"
        }
        '.json' {
            # Parse existing JSON, add new applications, and save back
            $existingApps = @()
            if (Test-Path $FileName) {
                try {
                    $jsonContent = Get-Content $FileName -Raw | ConvertFrom-Json
                    if ($jsonContent -is [array]) {
                        $existingApps = $jsonContent
                    }
                }
                catch {
                    Write-Warning "Could not parse existing JSON file: $FileName"
                }
            }
            
            # Merge and deduplicate
            $allApps = ($existingApps + $Applications) | Sort-Object -Unique
            $allApps | ConvertTo-Json | Set-Content $FileName -Force
            Write-Debug "Added $($Applications.Count) application(s) to JSON file: $FileName"
        }
        default {
            # For text files, append new applications
            if (Test-Path $FileName) {
                # Add applications to existing file
                $Applications | Add-Content $FileName
            }
            else {
                # Create new file with applications
                $Applications | Set-Content $FileName
            }
            Write-Debug "Added $($Applications.Count) application(s) to file: $FileName"
        }
    }
}

# Resolve-WingetApplicationId function
function Resolve-WingetApplicationId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationId
    )
    
    Write-Debug "Resolving winget ID for: $ApplicationId"
    
    # First try exact match
    try {
        $exactResult = winget show --id $ApplicationId --exact 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Debug "Found exact match for: $ApplicationId"
            return $ApplicationId
        }
    }
    catch {
        # Continue to search
    }
    
    # If exact match fails, search for similar packages
    try {
        $searchResult = winget search --name "$ApplicationId" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not find any packages matching name: $ApplicationId"
            $searchResult = winget search "$ApplicationId" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Could not find any packages matching: $ApplicationId"
                return $null
            }
        }
        
        # Parse search results to extract package IDs
        $lines = $searchResult -split "`n" | Where-Object { $_ -match '\S' }
        $packages = @()
        
        # Find header line to determine column positions
        $headerIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^Name\s+Id\s+Version') {
                $headerIndex = $i
                break
            }
        }
        
        if ($headerIndex -eq -1) {
            Write-Warning "Could not parse winget search results for: $ApplicationId"
            return $null
        }
        
        # Skip header and separator lines
        $dataLines = $lines[($headerIndex + 2)..($lines.Count - 1)]
        
        foreach ($line in $dataLines) {
            # Skip empty lines and lines that don't contain package data
            if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-+') {
                continue
            }
            
            # Split by multiple spaces to separate columns
            $parts = $line -split '\s{2,}' | Where-Object { $_ -match '\S' }
            
            if ($parts.Count -ge 3) {
                $packageName = $parts[0].Trim()
                $packageId = $parts[1].Trim()
                $version = $parts[2].Trim()
                
                $packages += @{
                    Name    = $packageName
                    Id      = $packageId
                    Version = $version
                }
            }
        }
        
        if ($packages.Count -eq 0) {
            Write-Warning "No packages found for: $ApplicationId"
            return $null
        }
        
        # If exactly one package found, return it
        if ($packages.Count -eq 1) {
            Write-Debug "Found package: $($packages[0].Name) ($($packages[0].Id))"
            return $packages[0].Id
        }
        
        # Multiple packages found - prompt user
        Write-Host "Multiple packages found for '$ApplicationId':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $packages.Count; $i++) {
            Write-Host "  [$($i + 1)] $($packages[$i].Name) ($($packages[$i].Id)) - Version: $($packages[$i].Version)"
        }
        Write-Host "  [0] Skip this application"
        
        do {
            $choice = Read-Host "Select package (1-$($packages.Count)) or 0 to skip"
            if ($choice -eq '0') {
                Write-Debug "Skipping $ApplicationId"
                return $null
            }
            $choiceNum = $choice -as [int]
        } while ($choiceNum -lt 1 -or $choiceNum -gt $packages.Count)
        
        $selectedPackage = $packages[$choiceNum - 1]
        Write-Debug "Selected: $($selectedPackage.Name) ($($selectedPackage.Id))"
        return $selectedPackage.Id
    }
    catch {
        Write-Error "Error searching for package '$ApplicationId': $_"
        return $null
    }
}

# Resolve-WingetApplicationIds function
function Resolve-WingetApplicationIds {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Applications
    )
    
    $resolvedIds = @()
    
    foreach ($app in $Applications) {
        Write-Debug "Resolving: $app"
        $resolvedId = Resolve-WingetApplicationId -ApplicationId $app
        
        if ($resolvedId) {
            $resolvedIds += $resolvedId
        }
    }
    
    return $resolvedIds
}

# Install-Applications function
function Install-Applications {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ApplicationList
    )
    
    $installedApplications = @()
    
    if ($ApplicationList.Count -gt 0) {
        Write-Warning "Missing required applications: $($ApplicationList -join ', ')"
        Write-Host "Installing missing applications..." -ForegroundColor Yellow
        
        foreach ($appId in $ApplicationList) {
            try {
                Write-Debug "Installing $appId..."
                winget install -e --id $appId --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Debug "✓ $appId installed successfully"
                    $installedApplications += $appId
                }
                else {
                    Write-Warning "Failed to install $appId (exit code: $LASTEXITCODE)"
                }
            }
            catch {
                Write-Error "Failed to install $appId`: $_"
            }
        }
    }
    
    return $installedApplications
}

function Add-Application([string[]]$Application, [string]$FileName = (Join-Path $PSScriptRoot, "Install" 'All-Applications.txt'),
    [switch]$NoPersist,
    [switch]$NoCache,
    [switch]$SkipValidation,
    [string]$CacheFilePath = (Join-Path $PSScriptRoot '.module-deps-cache')
) {
    # Resolve and validate winget application IDs (unless SkipValidation is set)
    if (-not $SkipValidation) {
        Write-Debug "Resolving winget application IDs..."
        $Application = Resolve-WingetApplicationIds -Applications $Application
        
        if ($Application.Count -eq 0) {
            Write-Warning "No valid applications found after winget ID resolution"
            return
        }
        
        Write-Debug "Resolved $($Application.Count) valid application(s)"
    }
    else {
        Write-Debug "Skipping winget ID validation"
    }

    Ensure-Applications -Applications $Application -FileName $FileName -Persist:(!$NoPersist) -NoCache:$NoCache -SkipValidation -CacheFilePath $CacheFilePath
}

# Ensure-Applications function
function Ensure-Applications {
    [CmdletBinding(DefaultParameterSetName = 'ApplicationList')]
    param(
        [string[]]$Applications,
        [string]$FileName,
        [switch]$Persist,
        [switch]$NoCache,
        [switch]$SkipValidation,
        [string]$CacheFilePath = (Join-Path $PSScriptRoot '.module-deps-cache')
    )
    
    # Handle the FileName parameter set
    if ($FileName) {
        $FileApplications = Get-ApplicationsFromFile -FileName $FileName
        
        # If Applications parameter is provided, merge with file applications
        if ($Applications.Count -gt 0) {
            # If Persist flag is set, add new applications to the file
            if ($Persist) {
                $newApplications = $Applications | Where-Object { $_ -notin $FileApplications }
                if ($newApplications.Count -gt 0) {
                    Add-ApplicationToFile -FileName $FileName -Applications $newApplications
                }
            }
            # Combine both lists
            $Applications = ($Applications + $FileApplications) | Sort-Object -Unique
        }
        else {
            # Use only file applications
            $Applications = $FileApplications
        }
        
        if ($Applications.Count -eq 0) {
            return
        }
    }
    
    if ($Applications.Count -eq 0) {
        Write-Debug "No applications to check"
        return
    }
    
    # Resolve and validate winget application IDs (unless SkipValidation is set)
    if (-not $SkipValidation) {
        Write-Debug "Resolving winget application IDs..."
        $Applications = Resolve-WingetApplicationIds -Applications $Applications
        
        if ($Applications.Count -eq 0) {
            Write-Warning "No valid applications found after winget ID resolution"
            return
        }
        
        Write-Debug "Resolved $($Applications.Count) valid application(s)"
    }
    else {
        Write-Debug "Skipping winget ID validation"
    }
    
    $appHash = ($Applications | Sort-Object | ConvertTo-Json -Compress | Get-FileHash -Algorithm SHA256).Hash
    $installedApplications = @()
    $needsAppCheck = $true
    
    # Check if cache file exists and load installed applications (unless NoCache is set)
    if (-not $NoCache -and (Test-Path $CacheFilePath)) {
        try {
            $cache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            if ($cache.AppHash -eq $appHash -and $cache.CheckDate -gt (Get-Date).AddDays(-7)) {
                $installedApplications = if ($cache.InstalledApplications) { $cache.InstalledApplications } else { @() }
                $needsAppCheck = $false
                Write-Debug "Using cached application list (valid until $($cache.CheckDate.AddDays(7)))"
            }
            else {
                Write-Debug "Cache file outdated, will regenerate"
            }
        }
        catch {
            # Cache file corrupted, will regenerate
            Write-Debug "Cache file corrupted, will regenerate"
        }
    }
    elseif ($NoCache) {
        Write-Debug "Cache disabled by NoCache flag"
    }
    
    if ($needsAppCheck) {
        Write-Debug "Checking installed applications..."
        # Check which applications are actually installed
        $installedApplications = @()
        foreach ($appId in $Applications) {
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
    $missingApplications = $Applications | Where-Object { $_ -notin $installedApplications }
    
    if ($missingApplications.Count -gt 0) {
        $installedApplications += Install-Applications -ApplicationList $missingApplications
    }
    
    # Update cache with both modules and applications (unless NoCache is set)
    if (-not $NoCache) {
        if (Test-Path $CacheFilePath) {
            $existingCache = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            $cacheData = @{
                Hash                  = if ($existingCache.Hash) { $existingCache.Hash } else { "" }
                AppHash               = $appHash
                CheckDate             = Get-Date
                InstalledModules      = if ($existingCache.InstalledModules) { $existingCache.InstalledModules } else { @() }
                InstalledApplications = $installedApplications | Sort-Object
            }
        }
        else {
            $cacheData = @{
                Hash                  = ""
                AppHash               = $appHash
                CheckDate             = Get-Date
                InstalledModules      = @()
                InstalledApplications = $installedApplications | Sort-Object
            }
        }
        $cacheData | ConvertTo-Json | Set-Content $CacheFilePath -Force
    }
    else {
        Write-Debug "Cache update skipped due to NoCache flag"
    }
    
    if ($missingApplications.Count -eq 0) {
        Write-Debug "All required applications are available"
    }
}
