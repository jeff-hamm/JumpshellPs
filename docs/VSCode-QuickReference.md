# VS Code Functions - Quick Reference

Quick reference guide for all VS Code-related functions in the JumpShellPs module.

## Chat & History Functions

| Function | Purpose | Quick Example |
|----------|---------|---------------|
| `Get-VSCodeChatSessions` | List all chat sessions | `Get-VSCodeChatSessions \| ft Title, MessageCount` |
| `Get-VSCodeChatSessionHistory` | Get conversation messages | `Get-VSCodeChatSessions \| Select -First 1 \| Get-VSCodeChatSessionHistory` |
| `Get-VSCodeChatEditingSessions` | List file editing sessions | `Get-VSCodeChatEditingSessions \| ft FileCount, OperationCount` |
| `Get-VSCodeChatEditingFiles` | List files modified in session | `$session.GetFiles()` |
| `Get-VSCodeChatEditingOperations` | Get individual edits | `$session.GetOperations()` |
| `Find-VSCodeChatEditingSessionByMessage` | Find edits for a message | `Find-VSCodeChatEditingSessionByMessage -RequestId "request_abc"` |

## Workspace Management Functions

| Function | Purpose | Quick Example |
|----------|---------|---------------|
| `Get-VSCodeUserPath` | Get VS Code user directory | `Get-VSCodeUserPath` |
| `Get-VSCodeWorkspaceStorage` | Find workspace storage folder | `Get-VSCodeWorkspaceStorage -Path $PWD` |
| `Get-VSCodeWorkspaceStorageFromGlobal` | List all workspace storage | `Get-VSCodeWorkspaceStorageFromGlobal` |
| `Export-WorkspaceLayout` | Save current layout | `Export-WorkspaceLayout -Name "my-layout"` |
| `Apply-WorkspaceLayout` | Apply saved layout | `Apply-WorkspaceLayout -WorkspacePath $PWD` |

## Object Methods

### Chat Session Object
```powershell
$session = Get-VSCodeChatSessions | Select-Object -First 1

$session.GetMessages()              # Get all messages
$session.GetMessages($true)         # Include thinking
$session.GetMessages($true, $true)  # Include thinking + metadata
$session.GetEditingSession()        # Get file editing session
```

### Chat Message Object
```powershell
$messages = $session.GetMessages()
$message = $messages[0]

$message.GetFileEdits()  # Get files modified by this message
```

### Editing Session Object
```powershell
$editSession = Get-VSCodeChatEditingSessions | Select-Object -First 1

$editSession.GetFiles()                          # List modified files
$editSession.GetOperations()                     # Get all operations
$editSession.GetOperations($filePath)            # Filter by file
$editSession.GetOperations($null, $requestId)    # Filter by request
$editSession.GetChatSession()                    # Get chat session
```

### File Object
```powershell
$files = $editSession.GetFiles()
$file = $files[0]

$file.GetOperations()  # Get edit operations for this file
```

## Common One-Liners

### Find recent chats
```powershell
Get-VSCodeChatSessions | Select-Object -First 5 | ft Title, MessageCount, LastModified
```

### Read a conversation
```powershell
(Get-VSCodeChatSessions | Select -First 1).GetMessages() | ft Request, Response
```

### Find which messages changed files
```powershell
$session = Get-VSCodeChatSessions | Select -First 1
$session.GetMessages() | % { if ($e = $_.GetFileEdits()) { [PSCustomObject]@{Q=$_.Request.Substring(0,50); Files=$e.FileCount} } }
```

### See all modified files
```powershell
(Get-VSCodeChatEditingSessions | Select -First 1).GetFiles() | ft FileName, OperationCount
```

### Export current layout
```powershell
Export-WorkspaceLayout -Name "backup-$(Get-Date -Format 'yyyyMMdd')"
```

### Apply layout
```powershell
Apply-WorkspaceLayout -WorkspacePath $PWD -LayoutJsonPath ".\vscode-workspaces\default.json" -WhatIf
```

### Find workspace storage
```powershell
Get-VSCodeWorkspaceStorage -Path $PWD | select FullName
```

## Filter Examples

### Chat sessions by date
```powershell
Get-VSCodeChatSessions | Where-Object { $_.Created -gt (Get-Date).AddDays(-7) }
```

### Sessions with many messages
```powershell
Get-VSCodeChatSessions | Where-Object MessageCount -gt 20
```

### Editing sessions by file count
```powershell
Get-VSCodeChatEditingSessions | Where-Object FileCount -gt 5
```

### Files by operation count
```powershell
$session.GetFiles() | Where-Object OperationCount -gt 10
```

### Messages that resulted in file edits
```powershell
$session.GetMessages() | Where-Object { $_.GetFileEdits() }
```

## Pipeline Patterns

### Chat session → Messages → File edits
```powershell
Get-VSCodeChatSessions | 
    Select-Object -First 1 | 
    Get-VSCodeChatSessionHistory | 
    ForEach-Object { $_.GetFileEdits() } | 
    Where-Object { $_ }
```

### Editing session → Files → Operations
```powershell
Get-VSCodeChatEditingSessions | 
    Select-Object -First 1 | 
    Get-VSCodeChatEditingFiles | 
    ForEach-Object { $_.GetOperations() }
```

### Find edits by request ID
```powershell
Get-VSCodeChatSessionHistory -SessionId "abc123" | 
    Select-Object -ExpandProperty RequestId | 
    Find-VSCodeChatEditingSessionByMessage
```

## Export Examples

### Export chat to JSON
```powershell
$session = Get-VSCodeChatSessions | Select-Object -First 1
$session.GetMessages() | ConvertTo-Json -Depth 5 | Out-File "chat.json"
```

### Export chat to text
```powershell
$session.GetMessages() | ForEach-Object {
    "USER: $($_.Request)`n"
    "AI: $($_.Response)`n"
    "---`n"
} | Out-File "chat.txt"
```

### Export layout
```powershell
Export-WorkspaceLayout -Name "my-layout" -WorkspacePath $PWD
```

### Export file edit summary
```powershell
(Get-VSCodeChatEditingSessions | Select -First 1).GetFiles() | 
    Export-Csv "file-edits.csv" -NoTypeInformation
```

## Property Reference

### Chat Session Properties
```
SessionId, FileName, FilePath, StorageFolder, WorkspacePath
Created, LastModified, FileSize, MessageCount, Title
Requester, Responder, IsImported, Version
```

### Chat Message Properties
```
Timestamp, RequestId, ResponseId, Request, Response, Thinking
ModelId, CodeCitations, ContentReferences, Followups, TimeSpentWaiting (metadata)
```

### Editing Session Properties
```
SessionId, StatePath, SessionPath, StorageFolder, WorkspacePath
LastModified, StateFileSize, FileCount, OperationCount
SnapshotCount, RequestCount, Version, CurrentEpoch
```

### File Object Properties
```
FilePath, FileName, OperationCount, RequestCount
EpochRange, RequestIds, SessionId
```

### Operation Object Properties
```
Type, FilePath, FileName, RequestId, Epoch
EditText, EditCount, Range, SessionId
```

## Switches & Parameters

### Get-VSCodeChatSessionHistory
- `-IncludeThinking` - Show AI's thinking process
- `-IncludeMetadata` - Include model ID, citations, timing

### Get-VSCodeWorkspaceStorage
- `-All` - Find all storage folders (if workspace recreated)
- `-Path` - Local workspace path
- `-Uri` - Remote workspace URI

### Apply-WorkspaceLayout
- `-WhatIf` - Preview changes without applying
- `-WorkspacePath` - Workspace folder (finds DB automatically)
- `-WorkspaceDbPath` - Direct path to state.vscdb

### Export-WorkspaceLayout
- `-Name` - Layout name (required)
- `-WorkspacePath` - Source workspace

## Tips

### Performance
```powershell
# Fast: Uses JsonDocument streaming
Get-VSCodeChatSessions

# Slower: Full JSON parse
$session.GetMessages()

# Cache if running multiple queries
$sessions = Get-VSCodeChatSessions
```

### Formatting
```powershell
# Table view
| Format-Table -AutoSize

# List view
| Format-List

# Wide view
| Format-Wide

# Custom table
| Select Name, Count | ft
```

### Filtering
```powershell
# Where-Object
| Where-Object Property -gt Value

# Select-Object
| Select-Object -First 5
| Select-Object Property1, Property2

# Sort-Object
| Sort-Object Property -Descending
```

## Help

### Get function help
```powershell
Get-Help Get-VSCodeChatSessions -Full
Get-Help Apply-WorkspaceLayout -Examples
Get-Help Get-VSCodeWorkspaceStorage -Parameter All
```

### List all functions
```powershell
Get-Command -Module JumpShellPs | Where-Object Name -like '*VSCode*'
```

### Get function syntax
```powershell
Get-Command Get-VSCodeChatSessions -Syntax
```

## Documentation

- **Full Chat Documentation**: [VSCode-ChatSessions.md](VSCode-ChatSessions.md)
- **Workspace Management**: [VSCode-WorkspaceManagement.md](VSCode-WorkspaceManagement.md)
