function Apply-WorkspaceLayout {
    <#
    .SYNOPSIS
    Apply saved workspace layout to a VS Code workspace.

    .DESCRIPTION
    Reads a workspace layout configuration and applies it to a target VS Code workspace.
    - Database settings (workbench.*) are written to state.vscdb
    - Settings.json settings are compared with user settings and written to workspace .vscode/settings.json if different

    .PARAMETER WorkspaceDbPath
    Path to the target workspace's state.vscdb file. Usually located at:
    $env:APPDATA\Code\User\workspaceStorage\<hash>\state.vscdb

    .PARAMETER WorkspacePath
    Path to the workspace folder. The function will automatically find the workspace storage database.

    .PARAMETER LayoutJsonPath
    Path to the layout JSON file. Defaults to default.json in the vscode-workspaces directory.

    .PARAMETER WhatIf
    Show what would be changed without actually making changes.

    .EXAMPLE
    Apply-WorkspaceLayout -WorkspaceDbPath "C:\Users\...\workspaceStorage\abc123\state.vscdb"

    .EXAMPLE
    Apply-WorkspaceLayout -WorkspacePath "C:\Projects\MyProject"

    .EXAMPLE
    Apply-WorkspaceLayout -WorkspacePath $PWD -WhatIf
    #>
    [CmdletBinding(DefaultParameterSetName='WorkspacePath')]
    param(
        [Parameter(ParameterSetName='DbPath', Mandatory=$true)]
        [string]$WorkspaceDbPath,
        
        [Parameter(ParameterSetName='WorkspacePath')]
        [string]$WorkspacePath,
        
        [string]$LayoutJsonPath = "$PSScriptRoot\vscode-workspaces\default.json",
        
        [switch]$WhatIf
    )

    # Determine workspace path if not specified
    if ($PSCmdlet.ParameterSetName -eq 'WorkspacePath' -and -not $WorkspacePath) {
        # Try to detect VS Code workspace root
        $detectedPath = $null
        
        # Check if we're in VS Code integrated terminal
        if (Is-VsCode) {
            # Look for workspace indicators going up the directory tree
            $currentPath = $PWD.Path
            $maxDepth = 5
            $depth = 0
            
            while ($currentPath -and $depth -lt $maxDepth) {
                # Check for .vscode folder
                if (Test-Path (Join-Path $currentPath ".vscode")) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Check for .code-workspace file
                if (Get-ChildItem $currentPath -Filter "*.code-workspace" -File) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Check for .git folder (common workspace root indicator)
                if (Test-Path (Join-Path $currentPath ".git")) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Move up one directory
                $parent = Split-Path $currentPath -Parent
                if ($parent -eq $currentPath) { break }  # Reached root
                $currentPath = $parent
                $depth++
            }
        }
        
        # Use detected path or fall back to $PWD
        $WorkspacePath = if ($detectedPath) { 
            Write-Verbose "Detected workspace root: $detectedPath"
            $detectedPath 
        } else { 
            $PWD.Path 
        }
    }

    # If WorkspacePath provided, find the database
    if ($PSCmdlet.ParameterSetName -eq 'WorkspacePath') {
        $storageFolder = Get-VSCodeWorkspaceStorage -Path $WorkspacePath
        if (-not $storageFolder) {
            Write-Error "Could not find workspace storage for: $WorkspacePath"
            return
        }
        
        # Get the first folder if multiple returned
        if ($storageFolder -is [Array]) {
            $storageFolder = $storageFolder[0]
        }
        
        $WorkspaceDbPath = Join-Path $storageFolder.FullName "state.vscdb"
        
        if (-not (Test-Path $WorkspaceDbPath)) {
            Write-Error "Workspace storage found but state.vscdb not found: $WorkspaceDbPath"
            return
        }
        
        Write-Host "Found workspace database: $WorkspaceDbPath" -ForegroundColor Cyan
    }

    # Verify sqlite3 is available
    if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
        Write-Error "sqlite3 is not installed. Install with: winget install SQLite.SQLite"
        return
    }

    # Verify paths
    if (-not (Test-Path $WorkspaceDbPath)) {
        Write-Error "Workspace database not found: $WorkspaceDbPath"
        return
    }

    if (-not (Test-Path $LayoutJsonPath)) {
        Write-Error "Layout JSON not found: $LayoutJsonPath"
        return
    }

    # Load the layout configuration
    Write-Host "Loading layout from: $LayoutJsonPath" -ForegroundColor Cyan
    $layout = Get-Content $LayoutJsonPath -Raw | ConvertFrom-Json

    # Detect layout format version
    $isV2Format = $null -ne $layout.database -or $null -ne $layout.'_version'
    
    if ($isV2Format) {
        Write-Host "Detected v2 layout format (database + settings)" -ForegroundColor Gray
        $databaseSettings = $layout.database
        $jsonSettings = $layout.settings
    } else {
        Write-Host "Detected v1 layout format (database only)" -ForegroundColor Gray
        $databaseSettings = $layout
        $jsonSettings = $null
    }

    # Function to escape single quotes for SQL
    function Escape-Sql($text) {
        if ($text -is [string]) {
            return $text.Replace("'", "''")
        }
        return $text
    }

    # Count operations
    $updated = 0
    $inserted = 0
    $skipped = 0

    # Apply database settings
    if ($databaseSettings) {
        Write-Host ""
        Write-Host "Applying database settings to: $WorkspaceDbPath" -ForegroundColor Cyan
        Write-Host ""

        foreach ($property in $databaseSettings.PSObject.Properties) {
            $key = $property.Name
            $value = $property.Value
            
            # Convert value to JSON string if it's an object/array
            if ($value -is [PSCustomObject] -or $value -is [Array]) {
                $valueStr = $value | ConvertTo-Json -Depth 15 -Compress
            } else {
                $valueStr = $value.ToString()
            }
            
            # Escape for SQL
            $keyEscaped = Escape-Sql $key
            $valueEscaped = Escape-Sql $valueStr
            
            # Check if key exists
            $existing = sqlite3 $WorkspaceDbPath "SELECT value FROM ItemTable WHERE key = '$keyEscaped'"
            
            if ($existing) {
                if ($existing -eq $valueStr) {
                    Write-Host "  [SKIP] $key (already set)" -ForegroundColor Gray
                    $skipped++
                } else {
                    if ($WhatIf) {
                        Write-Host "  [WOULD UPDATE] $key" -ForegroundColor Yellow
                    } else {
                        sqlite3 $WorkspaceDbPath "UPDATE ItemTable SET value = '$valueEscaped' WHERE key = '$keyEscaped'" | Out-Null
                        Write-Host "  [UPDATE] $key" -ForegroundColor Green
                    }
                    $updated++
                }
            } else {
                if ($WhatIf) {
                    Write-Host "  [WOULD INSERT] $key" -ForegroundColor Yellow
                } else {
                    sqlite3 $WorkspaceDbPath "INSERT INTO ItemTable (key, value) VALUES ('$keyEscaped', '$valueEscaped')" | Out-Null
                    Write-Host "  [INSERT] $key" -ForegroundColor Green
                }
                $inserted++
            }
        }
    }

    # Apply settings.json settings
    $settingsUpdated = 0
    $settingsSkipped = 0
    
    if ($jsonSettings -and $jsonSettings.PSObject.Properties.Count -gt 0) {
        Write-Host ""
        Write-Host "Processing settings.json settings..." -ForegroundColor Cyan
        
        # Load user settings to compare
        $userPath = Get-VSCodeUserPath
        $userSettingsPath = Join-Path $userPath "settings.json"
        $userSettings = @{}
        
        if (Test-Path $userSettingsPath) {
            try {
                $userSettings = Get-Content $userSettingsPath -Raw | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Warning "Failed to parse user settings.json: $_"
            }
        }
        
        # Load existing workspace settings
        $workspaceSettingsPath = Join-Path $WorkspacePath ".vscode\settings.json"
        $workspaceSettings = @{}
        
        if (Test-Path $workspaceSettingsPath) {
            try {
                $workspaceSettings = Get-Content $workspaceSettingsPath -Raw | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Warning "Failed to parse workspace settings.json: $_"
            }
        }
        
        # Compare and determine what needs to be added to workspace settings
        $settingsToApply = @{}
        
        foreach ($prop in $jsonSettings.PSObject.Properties) {
            $key = $prop.Name
            $desiredValue = $prop.Value
            
            # Convert to JSON for comparison
            $desiredJson = if ($desiredValue -is [PSCustomObject] -or $desiredValue -is [Array]) {
                $desiredValue | ConvertTo-Json -Depth 10 -Compress
            } else {
                "$desiredValue"
            }
            
            $userValue = $userSettings[$key]
            $userJson = if ($null -ne $userValue) {
                if ($userValue -is [PSCustomObject] -or $userValue -is [Array]) {
                    $userValue | ConvertTo-Json -Depth 10 -Compress
                } else {
                    "$userValue"
                }
            } else {
                $null
            }
            
            # If desired value differs from user settings, add to workspace settings
            if ($desiredJson -ne $userJson) {
                # Check if workspace already has this value
                $workspaceValue = $workspaceSettings[$key]
                $workspaceJson = if ($null -ne $workspaceValue) {
                    if ($workspaceValue -is [PSCustomObject] -or $workspaceValue -is [Array]) {
                        $workspaceValue | ConvertTo-Json -Depth 10 -Compress
                    } else {
                        "$workspaceValue"
                    }
                } else {
                    $null
                }
                
                if ($desiredJson -eq $workspaceJson) {
                    Write-Host "  [SKIP] $key (already in workspace settings)" -ForegroundColor Gray
                    $settingsSkipped++
                } else {
                    $settingsToApply[$key] = $desiredValue
                    if ($WhatIf) {
                        Write-Host "  [WOULD SET] $key = $desiredJson" -ForegroundColor Yellow
                    } else {
                        Write-Host "  [SET] $key = $desiredJson" -ForegroundColor Green
                    }
                    $settingsUpdated++
                }
            } else {
                Write-Host "  [SKIP] $key (matches user settings)" -ForegroundColor Gray
                $settingsSkipped++
            }
        }
        
        # Write workspace settings if there are changes
        if ($settingsToApply.Count -gt 0 -and -not $WhatIf) {
            # Merge with existing workspace settings
            foreach ($key in $settingsToApply.Keys) {
                $workspaceSettings[$key] = $settingsToApply[$key]
            }
            
            # Ensure .vscode directory exists
            $vscodeDir = Join-Path $WorkspacePath ".vscode"
            if (-not (Test-Path $vscodeDir)) {
                New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
            }
            
            # Write settings.json
            $workspaceSettings | ConvertTo-Json -Depth 100 | Set-Content -Path $workspaceSettingsPath -Encoding UTF8
            Write-Host ""
            Write-Host "Workspace settings written to: $workspaceSettingsPath" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Database - Updated: $updated, Inserted: $inserted, Skipped: $skipped" -ForegroundColor Green
    if ($jsonSettings) {
        Write-Host "  Settings - Updated: $settingsUpdated, Skipped: $settingsSkipped" -ForegroundColor Green
    }

    if ($WhatIf) {
        Write-Host ""
        Write-Host "WhatIf mode - no changes were made" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Layout applied successfully! Restart VS Code or reload the workspace to see changes." -ForegroundColor Green
    }
}

function Export-WorkspaceLayout {
    <#
    .SYNOPSIS
    Exports the current workspace layout to a JSON file.
    
    .DESCRIPTION
    Extracts the workspace layout configuration from VS Code's SQLite database AND
    layout-related settings from settings.json. Saves both to a combined JSON file.
    
    .PARAMETER Name
    The name of the layout file to create (without .json extension).
    The file will be saved to vscode-workspaces/{Name}.json
    
    .PARAMETER WorkspacePath
    Optional. Path to the workspace folder. Defaults to current directory ($pwd).
    
    .EXAMPLE
    Export-WorkspaceLayout -Name "my-layout"
    # Exports current workspace layout to vscode-workspaces/my-layout.json
    
    .EXAMPLE
    Export-WorkspaceLayout -Name "project-layout" -WorkspacePath "C:\Projects\MyProject"
    # Exports layout for specific workspace
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$WorkspacePath
    )
    
    # Layout-related settings keys to extract from settings.json
    $layoutSettingsKeys = @(
        'workbench.panel.defaultLocation',
        'workbench.sideBar.location',
        'workbench.activityBar.location',
        'workbench.statusBar.visible',
        'workbench.editor.showTabs',
        'workbench.editor.tabSizing',
        'workbench.editor.labelFormat',
        'workbench.editor.tabCloseButton',
        'workbench.editor.enablePreview',
        'workbench.editor.openPositioning',
        'workbench.startupEditor',
        'terminal.integrated.defaultLocation',
        'terminal.integrated.tabs.enabled',
        'terminal.integrated.tabs.location',
        'explorer.openEditors.visible',
        'editor.minimap.enabled',
        'editor.minimap.side',
        'breadcrumbs.enabled',
        'window.menuBarVisibility',
        'zenMode.fullScreen',
        'zenMode.centerLayout',
        'zenMode.hideLineNumbers',
        'zenMode.hideStatusBar',
        'zenMode.hideTabs'
    )
    
    # Determine workspace path if not specified
    if (-not $WorkspacePath) {
        # Try to detect VS Code workspace root
        $detectedPath = $null
        
        # Check if we're in VS Code integrated terminal
        if (Is-VsCode) {
            # Look for workspace indicators going up the directory tree
            $currentPath = $PWD.Path
            $maxDepth = 5
            $depth = 0
            
            while ($currentPath -and $depth -lt $maxDepth) {
                # Check for .vscode folder
                if (Test-Path (Join-Path $currentPath ".vscode")) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Check for .code-workspace file
                if (Get-ChildItem $currentPath -Filter "*.code-workspace" -File) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Check for .git folder (common workspace root indicator)
                if (Test-Path (Join-Path $currentPath ".git")) {
                    $detectedPath = $currentPath
                    break
                }
                
                # Move up one directory
                $parent = Split-Path $currentPath -Parent
                if ($parent -eq $currentPath) { break }  # Reached root
                $currentPath = $parent
                $depth++
            }
        }
        
        # Use detected path or fall back to $PWD
        $WorkspacePath = if ($detectedPath) { 
            Write-Verbose "Detected workspace root: $detectedPath"
            $detectedPath 
        } else { 
            $PWD.Path 
        }
    }
    
    # Ensure vscode-workspaces directory exists
    $layoutsDir = Join-Path $PSScriptRoot "vscode-workspaces"
    if (-not (Test-Path $layoutsDir)) {
        New-Item -ItemType Directory -Path $layoutsDir -Force | Out-Null
    }
    
    # Find workspace storage database
    Write-Host "Finding workspace database for: $WorkspacePath" -ForegroundColor Cyan
    $storageFolder = Get-VSCodeWorkspaceStorage -Path $WorkspacePath
    
    if (-not $storageFolder) {
        Write-Error "Could not find workspace storage for path: $WorkspacePath"
        return
    }
    
    $dbPath = Join-Path $storageFolder.FullName "state.vscdb"
    if (-not (Test-Path $dbPath)) {
        Write-Error "Workspace database not found at: $dbPath"
        return
    }
    
    Write-Host "Found database: $dbPath" -ForegroundColor Green
    
    # Extract all layout-related settings from database
    Write-Host "Extracting database layout settings..." -ForegroundColor Cyan
    
    $query = "SELECT key, value FROM ItemTable WHERE key LIKE 'workbench.%'"
    $results = sqlite3 $dbPath $query
    
    $databaseSettings = @{}
    foreach ($line in $results) {
        if ($line -match '^([^|]+)\|(.+)$') {
            $key = $matches[1]
            $value = $matches[2]
            
            # Skip workspace-specific keys
            $skipKeys = @(
                'workbench.editor.historyTracker',
                'workbench.grid.resourceWorkingCopies',
                'workbench.panel.chatEditing.view.copilotEditing.chatHistory',
                'workbench.panel.chat.view.copilot.chatdata',
                'workbench.sidebar.chatHistory'
            )
            
            $shouldSkip = $false
            foreach ($skipKey in $skipKeys) {
                if ($key -like "$skipKey*") {
                    $shouldSkip = $true
                    break
                }
            }
            
            if (-not $shouldSkip) {
                try {
                    $databaseSettings[$key] = $value | ConvertFrom-Json
                } catch {
                    # If not valid JSON, store as string
                    $databaseSettings[$key] = $value
                }
            }
        }
    }
    
    # Extract layout settings from user settings.json
    Write-Host "Extracting user settings.json layout settings..." -ForegroundColor Cyan
    
    $userPath = Get-VSCodeUserPath
    $userSettingsPath = Join-Path $userPath "settings.json"
    $jsonSettings = @{}
    
    if (Test-Path $userSettingsPath) {
        try {
            $userSettings = Get-Content $userSettingsPath -Raw | ConvertFrom-Json -AsHashtable
            
            foreach ($key in $layoutSettingsKeys) {
                if ($userSettings.ContainsKey($key)) {
                    $jsonSettings[$key] = $userSettings[$key]
                }
            }
            
            Write-Host "  Found $($jsonSettings.Count) layout settings in settings.json" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Failed to parse user settings.json: $_"
        }
    }
    
    # Also check workspace settings.json for overrides
    $workspaceSettingsPath = Join-Path $WorkspacePath ".vscode\settings.json"
    if (Test-Path $workspaceSettingsPath) {
        try {
            $wsSettings = Get-Content $workspaceSettingsPath -Raw | ConvertFrom-Json -AsHashtable
            
            foreach ($key in $layoutSettingsKeys) {
                if ($wsSettings.ContainsKey($key)) {
                    $jsonSettings[$key] = $wsSettings[$key]
                    Write-Verbose "  Workspace override: $key"
                }
            }
        }
        catch {
            Write-Warning "Failed to parse workspace settings.json: $_"
        }
    }
    
    # Create combined layout structure
    $layout = [ordered]@{
        '_version' = 2
        '_description' = 'VS Code layout export - includes database state and settings.json'
        'settings' = $jsonSettings
        'database' = $databaseSettings
    }
    
    # Save to file
    $outputPath = Join-Path $layoutsDir "$Name.json"
    $layout | ConvertTo-Json -Depth 100 | Set-Content -Path $outputPath -Encoding UTF8
    
    Write-Host ""
    Write-Host "Layout exported successfully!" -ForegroundColor Green
    Write-Host "  Database keys: $($databaseSettings.Count)" -ForegroundColor Cyan
    Write-Host "  Settings keys: $($jsonSettings.Count)" -ForegroundColor Cyan
    Write-Host "  File: $outputPath" -ForegroundColor Cyan
    
    return $outputPath
}

