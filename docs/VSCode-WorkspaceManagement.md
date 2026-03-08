# VS Code Workspace Management Functions

Functions for managing VS Code workspace layouts, settings, and storage.

## Table of Contents

- [Overview](#overview)
- [Path Functions](#path-functions)
- [Workspace Storage Functions](#workspace-storage-functions)
- [Layout Management Functions](#layout-management-functions)
- [Examples](#examples)

## Overview

VS Code stores workspace-specific data in workspace storage folders. These functions help you:

- Find VS Code user directories and profiles
- Locate workspace storage for specific folders
- Export and apply workspace layouts (panel positions, sidebar state, etc.)
- Manage workspace settings across multiple workspaces

## Path Functions

### `Get-VSCodeUserPath`

Gets the VS Code user settings directory path.

**Syntax:**
```powershell
Get-VSCodeUserPath [-ProfileName <string>]
```

**Parameters:**
- `-ProfileName` - Optional. Name of VS Code profile (default: current active profile)

**Returns:** String path to VS Code User directory

**Handles:**
- Regular VS Code installations
- Portable mode (`$env:VSCODE_PORTABLE`)
- Custom app data (`$env:VSCODE_APPDATA`)
- Multiple profiles
- VS Code Insiders
- VSCodium

**Examples:**
```powershell
# Get default user path
Get-VSCodeUserPath
# Returns: C:\Users\YourName\AppData\Roaming\Code\User

# Get specific profile path
Get-VSCodeUserPath -ProfileName "Work"
# Returns: C:\Users\YourName\AppData\Roaming\Code\User\profiles\abc123

# Use in other commands
$settingsFile = Join-Path (Get-VSCodeUserPath) "settings.json"
```

---

## Workspace Storage Functions

### `Get-VSCodeWorkspaceStorage`

Gets the workspace storage folder(s) for a given workspace path or URI.

**Syntax:**
```powershell
Get-VSCodeWorkspaceStorage -Path <string> [-UserPath <string>] [-All]
Get-VSCodeWorkspaceStorage -Uri <string> [-UserPath <string>]
```

**Parameters:**
- `-Path` - Local workspace folder path
- `-Uri` - Workspace URI (for remote workspaces)
- `-UserPath` - Optional. VS Code User path
- `-All` - Returns all storage folders for this path (useful if folder was recreated)

**Returns:** DirectoryInfo object(s) for workspace storage folder(s)

**How it Works:**
VS Code generates workspace storage IDs using:
- **Local paths**: MD5(lowercase_path + creation_time_ms)
- **Remote URIs**: MD5(uri_string)

The `-All` switch finds all storage folders by checking `workspace.json` files instead of calculating the creation time.

**Examples:**
```powershell
# Get workspace storage for current directory
Get-VSCodeWorkspaceStorage -Path $PWD

# Get storage for specific project
Get-VSCodeWorkspaceStorage -Path "C:\Projects\MyProject"

# Get all storage folders (if workspace was reopened multiple times)
Get-VSCodeWorkspaceStorage -Path "C:\Projects\MyProject" -All

# Remote workspace
Get-VSCodeWorkspaceStorage -Uri "vscode-remote://dev-container+..."

# Use the result
$storage = Get-VSCodeWorkspaceStorage -Path $PWD
$dbPath = Join-Path $storage.FullName "state.vscdb"
```

---

### `Get-VSCodeWorkspaceStorageFromGlobal`

Gets workspace storage folders for all workspaces found in global storage.

**Syntax:**
```powershell
Get-VSCodeWorkspaceStorageFromGlobal [-UserPath <string>]
```

**Parameters:**
- `-UserPath` - Optional. VS Code User path

**Returns:** Array of storage folders with `WorkspaceUri` property added

**Examples:**
```powershell
# Get all workspace storage folders
Get-VSCodeWorkspaceStorageFromGlobal | 
    Select-Object Name, WorkspaceUri

# Find recently used workspaces
Get-VSCodeWorkspaceStorageFromGlobal | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5
```

---

### `Get-MD5Hash`

Internal helper function. Computes MD5 hash of a string (used for workspace ID calculation).

**Syntax:**
```powershell
Get-MD5Hash -InputString <string>
```

---

## Layout Management Functions

### `Apply-WorkspaceLayout`

Applies a saved workspace layout to a VS Code workspace database.

**Syntax:**
```powershell
Apply-WorkspaceLayout -WorkspaceDbPath <string> [-LayoutJsonPath <string>] [-WhatIf]
Apply-WorkspaceLayout -WorkspacePath <string> [-LayoutJsonPath <string>] [-WhatIf]
```

**Parameters:**
- `-WorkspaceDbPath` - Direct path to `state.vscdb` file
- `-WorkspacePath` - Workspace folder path (automatically finds database)
- `-LayoutJsonPath` - Path to layout JSON file (default: `vscode-workspaces/default.json`)
- `-WhatIf` - Preview changes without applying them

**What it Does:**
- Reads layout configuration from JSON file
- Updates VS Code's SQLite database (`state.vscdb`)
- Modifies panel positions, visibility, activity bar order, etc.
- Shows summary of changes (updated, inserted, skipped)

**Requirements:**
- `sqlite3` command-line tool must be installed
- VS Code should be closed (or reload window after changes)

**Examples:**
```powershell
# Apply default layout to current workspace
Apply-WorkspaceLayout -WorkspacePath $PWD

# Apply specific layout
Apply-WorkspaceLayout -WorkspacePath $PWD -LayoutJsonPath ".\layouts\minimal.json"

# Preview changes without applying
Apply-WorkspaceLayout -WorkspacePath "C:\Projects\MyProject" -WhatIf

# Direct database path
$dbPath = "C:\Users\...\workspaceStorage\abc123\state.vscdb"
Apply-WorkspaceLayout -WorkspaceDbPath $dbPath
```

**Output Example:**
```
Found workspace database: C:\Users\...\state.vscdb
Loading layout from: vscode-workspaces\default.json
Applying layout to: C:\Users\...\state.vscdb

  [UPDATE] workbench.panel.position
  [INSERT] workbench.panel.height
  [SKIP] workbench.activityBar.visible (already set)
  ...

Summary:
  Updated: 12
  Inserted: 3
  Skipped: 8

Layout applied successfully! Restart VS Code or reload the workspace to see changes.
```

---

### `Export-WorkspaceLayout`

Exports the current workspace layout to a JSON file.

**Syntax:**
```powershell
Export-WorkspaceLayout -Name <string> [-WorkspacePath <string>]
```

**Parameters:**
- `-Name` - Layout name (filename without .json extension) **[Required]**
- `-WorkspacePath` - Workspace folder path (default: current directory)

**What it Exports:**
- Panel positions and sizes
- Sidebar visibility and position
- Activity bar configuration
- Editor layout
- View states
- And other `workbench.*` settings

**What it Excludes:**
- Editor history
- Recent files
- Session-specific data
- Chat history

**Examples:**
```powershell
# Export current workspace layout
Export-WorkspaceLayout -Name "my-layout"
# Creates: vscode-workspaces/my-layout.json

# Export layout from specific workspace
Export-WorkspaceLayout -Name "project-layout" -WorkspacePath "C:\Projects\MyProject"

# Export and apply to another workspace
Export-WorkspaceLayout -Name "dev-setup" -WorkspacePath "C:\Dev\ProjectA"
Apply-WorkspaceLayout -WorkspacePath "C:\Dev\ProjectB" -LayoutJsonPath "vscode-workspaces\dev-setup.json"
```

**Output Example:**
```
Finding workspace database for: C:\Projects\MyProject
Found database: C:\Users\...\state.vscdb
Extracting layout settings...

Layout exported successfully!
  Keys exported: 45
  File: C:\...\vscode-workspaces\my-layout.json
```

---

## Examples

### Example 1: Clone Workspace Layout

```powershell
# Export layout from source workspace
cd C:\Projects\SourceProject
Export-WorkspaceLayout -Name "source-layout"

# Apply to target workspace
cd C:\Projects\TargetProject
Apply-WorkspaceLayout -WorkspacePath $PWD -LayoutJsonPath "..\SourceProject\vscode-workspaces\source-layout.json"
```

### Example 2: Backup All Workspace Layouts

```powershell
# Create backup directory
$backupDir = "C:\Backups\VSCode-Layouts\$(Get-Date -Format 'yyyy-MM-dd')"
New-Item -ItemType Directory -Path $backupDir -Force

# Get all workspace storage folders
$workspaces = Get-VSCodeWorkspaceStorageFromGlobal

# Export each layout
foreach ($ws in $workspaces) {
    $wsPath = $ws.WorkspaceUri -replace '^file:///', '' -replace '%20', ' '
    if (Test-Path $wsPath) {
        $name = (Split-Path $wsPath -Leaf) -replace '[^\w-]', '_'
        try {
            Export-WorkspaceLayout -Name $name -WorkspacePath $wsPath
            Write-Host "Exported: $name" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to export $name: $_"
        }
    }
}
```

### Example 3: Standardize Team Workspaces

```powershell
# Create team standard layout
$teamLayout = @{
    "workbench.panel.position" = "bottom"
    "workbench.sideBar.location" = "left"
    "workbench.activityBar.visible" = $true
    "workbench.panel.opensMaximized" = "never"
    "workbench.editor.showTabs" = "multiple"
}

$teamLayout | ConvertTo-Json | Out-File "vscode-workspaces\team-standard.json"

# Apply to all projects
$projects = Get-ChildItem "C:\Projects" -Directory

foreach ($project in $projects) {
    Write-Host "Applying to: $($project.Name)"
    Apply-WorkspaceLayout -WorkspacePath $project.FullName `
        -LayoutJsonPath "vscode-workspaces\team-standard.json" `
        -WhatIf
}
```

### Example 4: Find Workspace Storage for Path

```powershell
function Find-WorkspaceData {
    param([string]$Path = $PWD)
    
    $storage = Get-VSCodeWorkspaceStorage -Path $Path -All
    
    if ($storage) {
        Write-Host "Found $($storage.Count) workspace storage folder(s)" -ForegroundColor Green
        
        foreach ($folder in $storage) {
            Write-Host "`nStorage Folder: $($folder.Name)" -ForegroundColor Yellow
            Write-Host "Full Path: $($folder.FullName)"
            Write-Host "Size: $((Get-ChildItem $folder.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) MB"
            Write-Host "Last Modified: $($folder.LastWriteTime)"
            
            # Check for specific data
            $hasState = Test-Path (Join-Path $folder.FullName "state.vscdb")
            $hasChat = Test-Path (Join-Path $folder.FullName "chatSessions")
            $hasEditing = Test-Path (Join-Path $folder.FullName "chatEditingSessions")
            
            Write-Host "Has State DB: $hasState"
            Write-Host "Has Chat Sessions: $hasChat"
            Write-Host "Has Editing Sessions: $hasEditing"
        }
    } else {
        Write-Warning "No workspace storage found for: $Path"
    }
}

# Usage
Find-WorkspaceData
Find-WorkspaceData -Path "C:\Projects\MyProject"
```

### Example 5: Clean Old Workspace Storage

```powershell
function Remove-OldWorkspaceStorage {
    param(
        [int]$DaysOld = 90,
        [switch]$WhatIf
    )
    
    $userPath = Get-VSCodeUserPath
    $storagePath = Join-Path $userPath "workspaceStorage"
    
    if (-not (Test-Path $storagePath)) {
        Write-Warning "Workspace storage not found: $storagePath"
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    $folders = Get-ChildItem $storagePath -Directory | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    Write-Host "Found $($folders.Count) folders older than $DaysOld days"
    
    foreach ($folder in $folders) {
        $size = (Get-ChildItem $folder.FullName -Recurse | 
            Measure-Object -Property Length -Sum).Sum / 1MB
        
        if ($WhatIf) {
            Write-Host "[WOULD DELETE] $($folder.Name) - $([math]::Round($size, 2)) MB - Last: $($folder.LastWriteTime)"
        } else {
            Write-Host "[DELETING] $($folder.Name) - $([math]::Round($size, 2)) MB"
            Remove-Item $folder.FullName -Recurse -Force
        }
    }
}

# Preview deletions
Remove-OldWorkspaceStorage -DaysOld 90 -WhatIf

# Actually delete
Remove-OldWorkspaceStorage -DaysOld 90
```

### Example 6: Create Layout Profiles

```powershell
# Minimal layout (focus mode)
$minimal = @{
    "workbench.activityBar.visible" = $false
    "workbench.sideBar.location" = "right"
    "workbench.statusBar.visible" = $true
    "workbench.panel.defaultLocation" = "bottom"
    "workbench.editor.showTabs" = "single"
}

# Full layout (exploration mode)
$full = @{
    "workbench.activityBar.visible" = $true
    "workbench.sideBar.location" = "left"
    "workbench.statusBar.visible" = $true
    "workbench.panel.defaultLocation" = "right"
    "workbench.editor.showTabs" = "multiple"
}

# Save layouts
$minimal | ConvertTo-Json | Out-File "vscode-workspaces\minimal.json"
$full | ConvertTo-Json | Out-File "vscode-workspaces\full.json"

# Quick switch function
function Set-VSCodeLayoutProfile {
    param(
        [ValidateSet('minimal', 'full')]
        [string]$Profile
    )
    
    Apply-WorkspaceLayout -WorkspacePath $PWD `
        -LayoutJsonPath "vscode-workspaces\$Profile.json"
}

# Usage
Set-VSCodeLayoutProfile -Profile minimal
Set-VSCodeLayoutProfile -Profile full
```

---

## Storage Structure

### User Directory
```
%APPDATA%\Code\User\
├── settings.json          # User settings
├── keybindings.json       # Key bindings
├── snippets/              # User snippets
├── globalStorage/         # Global state
│   └── storage.json       # Active profile, etc.
└── workspaceStorage/      # Workspace-specific data
    └── {hash}/
        ├── state.vscdb    # Workspace state (SQLite)
        ├── workspace.json # Workspace info
        ├── chatSessions/  # Copilot chat history
        └── chatEditingSessions/  # File edit history
```

### Workspace Storage Hash Format
```
For path: c:\projects\myproject
Created: 2024-01-15 10:30:45 UTC (1705318245000ms)

Hash input: "c:\projects\myproject1705318245000"
MD5: "abc123def456..."
Folder: abc123def456...
```

---

## Requirements

### sqlite3 Tool
Required for layout management functions.

**Install:**
```powershell
winget install SQLite.SQLite
```

Or download from: https://www.sqlite.org/download.html

**Verify:**
```powershell
sqlite3 --version
```

---

## Tips and Best Practices

1. **Close VS Code Before Layout Changes**
   - Changes to `state.vscdb` while VS Code is running may be overwritten
   - Or use "Developer: Reload Window" command after changes

2. **Backup Before Bulk Operations**
   ```powershell
   $storage = Get-VSCodeWorkspaceStorage -Path $PWD
   Copy-Item $storage.FullName "backup_$(Get-Date -Format 'yyyyMMdd')" -Recurse
   ```

3. **Use -WhatIf for Testing**
   ```powershell
   Apply-WorkspaceLayout -WorkspacePath $PWD -WhatIf
   ```

4. **Multiple Storage Folders**
   - Use `-All` switch if you've recreated the workspace folder
   - The most recent folder is usually the active one

5. **Profile Management**
   - Export layouts per profile if using VS Code profiles
   - Profile paths: `%APPDATA%\Code\User\profiles\{hash}`

6. **Version Control**
   - Consider versioning your layout JSON files
   - Share team layouts via Git repository

---

## Troubleshooting

### "Workspace storage not found"
- Ensure the folder has been opened in VS Code at least once
- Try using `-All` switch to find all storage folders
- Check that the path is exactly as it appears in VS Code

### "sqlite3 not found"
- Install SQLite command-line tools
- Ensure `sqlite3.exe` is in your PATH
- Restart PowerShell after installation

### Layout changes not visible
- Reload the VS Code window: `Ctrl+R` or "Developer: Reload Window"
- Or completely close and reopen VS Code
- Check if changes were actually applied (use `-WhatIf` first)

### Multiple storage folders for same path
- This happens when the folder is deleted and recreated
- Use `-All` to see all folders
- The most recent one is usually the active workspace
- Clean up old folders manually if needed
