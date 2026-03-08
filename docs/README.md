# JumpShellPs Documentation

Documentation for the JumpShellPs PowerShell module.

## VS Code Functions

The module includes comprehensive functions for working with VS Code workspaces, chat sessions, and file editing history.

### Quick Start

```powershell
# Import the module
Import-Module JumpShellPs

# Get recent chat sessions
Get-VSCodeChatSessions | Select-Object -First 5

# Read a conversation
$session = Get-VSCodeChatSessions | Select-Object -First 1
$messages = $session.GetMessages()
$messages | Format-Table Request, Response

# Find file modifications
$editSession = $session.GetEditingSession()
$editSession.GetFiles()
```

### Documentation Files

| File | Description |
|------|-------------|
| [VSCode-ChatSessions.md](VSCode-ChatSessions.md) | Complete guide to chat session and editing session functions with examples |
| [VSCode-WorkspaceManagement.md](VSCode-WorkspaceManagement.md) | Workspace layout and storage management functions |
| [VSCode-QuickReference.md](VSCode-QuickReference.md) | Quick reference with one-liners and common patterns |
| [MCP-Server.md](MCP-Server.md) | JumpShell MCP server architecture, install flow, and lifecycle commands |

### Function Categories

#### Chat Session Analysis
- `Get-VSCodeChatSessions` - List and discover chat sessions
- `Get-VSCodeChatSessionHistory` - Read conversation messages
- Methods for exploring conversations and linking to file edits

#### File Editing Tracking
- `Get-VSCodeChatEditingSessions` - List editing sessions
- `Get-VSCodeChatEditingFiles` - See which files were modified
- `Get-VSCodeChatEditingOperations` - View individual text edits
- `Find-VSCodeChatEditingSessionByMessage` - Link messages to file changes

#### Workspace Management
- `Get-VSCodeUserPath` - Find VS Code user directory
- `Get-VSCodeWorkspaceStorage` - Locate workspace storage folders
- `Export-WorkspaceLayout` - Save workspace layout configuration
- `Apply-WorkspaceLayout` - Apply saved layout to workspaces

## Examples

### Example 1: Find Your Most Active Chat Session
```powershell
Get-VSCodeChatSessions | 
    Sort-Object MessageCount -Descending | 
    Select-Object -First 1 |
    ForEach-Object {
        Write-Host "Most active chat: $($_.Title)" -ForegroundColor Cyan
        Write-Host "Messages: $($_.MessageCount)"
        Write-Host "Created: $($_.Created)"
    }
```

### Example 2: See What Files Copilot Modified Today
```powershell
$today = (Get-Date).Date
Get-VSCodeChatEditingSessions | 
    Where-Object { $_.LastModified.Date -eq $today } |
    ForEach-Object {
        Write-Host "`nSession: $($_.SessionId.Substring(0,8))..." -ForegroundColor Yellow
        $_.GetFiles() | Format-Table FileName, OperationCount
    }
```

### Example 3: Export All Chat History to Text
```powershell
$outputFile = "copilot-history.txt"
Get-VSCodeChatSessions | ForEach-Object {
    "=" * 80 | Out-File $outputFile -Append
    "Session: $($_.Title)" | Out-File $outputFile -Append
    "Date: $($_.Created)" | Out-File $outputFile -Append
    "=" * 80 | Out-File $outputFile -Append
    
    $_.GetMessages() | ForEach-Object {
        "`nUSER:" | Out-File $outputFile -Append
        $_.Request | Out-File $outputFile -Append
        "`nCOPILOT:" | Out-File $outputFile -Append
        $_.Response | Out-File $outputFile -Append
        "`n---`n" | Out-File $outputFile -Append
    }
}
```

### Example 4: Clone Workspace Layout
```powershell
# Export from your perfectly configured workspace
cd C:\Projects\WellConfigured
Export-WorkspaceLayout -Name "perfect-setup"

# Apply to new workspace
cd C:\Projects\NewProject
Apply-WorkspaceLayout -WorkspacePath $PWD -LayoutJsonPath "../WellConfigured/vscode-workspaces/perfect-setup.json"

# Reload VS Code window to see changes
```

### Example 5: Find Messages That Actually Changed Code
```powershell
$session = Get-VSCodeChatSessions | Select-Object -First 1
$messages = $session.GetMessages()

$messagesWithEdits = $messages | ForEach-Object {
    $edits = $_.GetFileEdits()
    if ($edits) {
        [PSCustomObject]@{
            Question = $_.Request.Substring(0, 100) + "..."
            FilesChanged = $edits.FileCount
            Operations = $edits.OperationCount
            Files = ($edits.FilesModified | ForEach-Object { Split-Path $_ -Leaf }) -join ", "
        }
    }
}

$messagesWithEdits | Format-Table -AutoSize
```

## Installation

The module is located at:
```
C:\OneDrive\Documents\PowerShell\Modules\JumpshellPs
```

Import it in your PowerShell profile or manually:
```powershell
Import-Module JumpShellPs
```

## Requirements

- PowerShell 7+
- VS Code with GitHub Copilot
- `sqlite3` command-line tool (for layout management functions)
  ```powershell
  winget install SQLite.SQLite
  ```

## Tips

1. **Use Tab Completion**: All functions support tab completion for parameters
2. **Pipeline Friendly**: All functions work well in pipelines
3. **Object Methods**: Use `.GetMessages()`, `.GetFiles()`, etc. for easy exploration
4. **WhatIf Support**: Use `-WhatIf` with `Apply-WorkspaceLayout` to preview changes
5. **Performance**: Chat session queries are fast due to efficient JSON parsing

## Getting Help

```powershell
# List all VS Code functions
Get-Command -Module JumpShellPs | Where-Object Name -like '*VSCode*'

# Get detailed help
Get-Help Get-VSCodeChatSessions -Full

# See examples
Get-Help Apply-WorkspaceLayout -Examples

# View online docs
code "$env:USERPROFILE\Documents\PowerShell\Modules\JumpshellPs\docs"
```

## Contributing

Found a bug or have a feature request? The module is under active development.

## License

Part of the JumpShellPs module.
