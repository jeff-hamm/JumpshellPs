# VS Code Chat Session Functions

This module provides comprehensive tools for exploring and analyzing GitHub Copilot chat sessions and editing sessions in VS Code.

## Table of Contents

- [Overview](#overview)
- [Chat Session Functions](#chat-session-functions)
- [Chat Editing Session Functions](#chat-editing-session-functions)
- [Object Methods](#object-methods)
- [Common Workflows](#common-workflows)
- [Examples](#examples)

## Overview

VS Code stores GitHub Copilot chat history and file editing sessions in workspace storage. These functions let you:

- **Discover chat sessions** - Find and summarize all chat conversations
- **Read conversation history** - Extract messages, responses, and thinking processes
- **Track file modifications** - See which files were edited during chat sessions
- **Analyze editing operations** - Review individual text edits made by Copilot
- **Correlate chats and edits** - Link chat messages to actual file changes

## Chat Session Functions

### `Get-VSCodeChatSessions`

Gets a summary of all GitHub Copilot chat sessions for a workspace.

**Syntax:**
```powershell
Get-VSCodeChatSessions [-Path <string>]
```

**Parameters:**
- `-Path` - Workspace folder path (default: current directory)

**Returns:** Array of session objects with properties:
- `SessionId` - Unique identifier (GUID)
- `FileName` - JSON filename
- `FilePath` - Full path to session file
- `StorageFolder` - Workspace storage folder name
- `WorkspacePath` - Workspace root path
- `Created` - Session creation date
- `LastModified` - Last message date
- `FileSize` - Session file size
- `MessageCount` - Number of request/response pairs
- `Title` - Custom session title
- `Requester` - Username of requester
- `Responder` - Username of responder (usually Copilot)
- `IsImported` - Whether session was imported
- `Version` - Session format version

**Methods:**
- `.GetMessages([IncludeThinking], [IncludeMetadata])` - Get conversation history
- `.GetEditingSession()` - Get associated editing session

**Examples:**
```powershell
# Get all chat sessions for current workspace
Get-VSCodeChatSessions

# Get sessions for specific workspace
Get-VSCodeChatSessions -Path "C:\Projects\MyProject"

# Filter sessions with many messages
Get-VSCodeChatSessions | Where-Object MessageCount -gt 10

# View recent sessions
Get-VSCodeChatSessions | Select-Object -First 5 | Format-Table Title, MessageCount, Created
```

---

### `Get-VSCodeChatSessionHistory`

Gets the request/response history from a chat session.

**Syntax:**
```powershell
Get-VSCodeChatSessionHistory [-SessionId <string>]
Get-VSCodeChatSessionHistory [-FilePath <string>]
Get-VSCodeChatSessionHistory [-Session <PSCustomObject>] [-IncludeThinking] [-IncludeMetadata]
```

**Parameters:**
- `-SessionId` - Session ID (GUID)
- `-FilePath` - Direct path to session JSON file
- `-Session` - Session object (from pipeline)
- `-IncludeThinking` - Include AI's thinking process
- `-IncludeMetadata` - Include model ID, citations, timing data

**Returns:** Array of message exchange objects with properties:
- `Timestamp` - Message timestamp
- `RequestId` - Unique request identifier
- `ResponseId` - Unique response identifier
- `Request` - User's message text
- `Response` - AI's response (cleaned, no empty code blocks)
- `Thinking` - AI's thinking process (if `-IncludeThinking`)
- Plus metadata fields if `-IncludeMetadata`

**Methods:**
- `.GetFileEdits()` - Get file modifications from this message

**Examples:**
```powershell
# Get messages from a session
Get-VSCodeChatSessionHistory -SessionId "f6d02192-d8e0-4ffa-b687-3080be9023a1"

# Use pipeline
Get-VSCodeChatSessions | Select-Object -First 1 | Get-VSCodeChatSessionHistory

# Include thinking process
$session = Get-VSCodeChatSessions | Select-Object -First 1
$session.GetMessages($true, $false)

# View conversation
$messages = Get-VSCodeChatSessionHistory -SessionId "abc123"
$messages | ForEach-Object {
    Write-Host "User: $($_.Request)" -ForegroundColor Cyan
    Write-Host "AI: $($_.Response)" -ForegroundColor Green
    Write-Host ""
}
```

---

## Chat Editing Session Functions

### `Get-VSCodeChatEditingSessions`

Gets all chat editing sessions for a workspace. Editing sessions track file modifications made during Copilot chat interactions.

**Syntax:**
```powershell
Get-VSCodeChatEditingSessions [-Path <string>] [-SessionId <string>]
```

**Parameters:**
- `-Path` - Workspace folder path (default: current directory)
- `-SessionId` - Filter to specific session ID

**Returns:** Array of editing session objects with properties:
- `SessionId` - Session identifier (matches chat session ID)
- `StatePath` - Path to state.json file
- `SessionPath` - Session directory path
- `StorageFolder` - Workspace storage folder name
- `WorkspacePath` - Workspace root path
- `LastModified` - Last modification date
- `StateFileSize` - State file size
- `FileCount` - Number of unique files modified
- `OperationCount` - Total edit operations
- `SnapshotCount` - Number of file snapshots stored
- `RequestCount` - Number of unique requests
- `Version` - State format version
- `CurrentEpoch` - Current epoch number

**Methods:**
- `.GetFiles()` - List modified files
- `.GetOperations([FilePath], [RequestId])` - Get edit operations
- `.GetChatSession()` - Get associated chat session

**Examples:**
```powershell
# Get all editing sessions
Get-VSCodeChatEditingSessions

# Find session by ID
Get-VSCodeChatEditingSessions -SessionId "f6d02192-d8e0-4ffa-b687-3080be9023a1"

# Filter sessions by file count
Get-VSCodeChatEditingSessions | Where-Object FileCount -gt 5

# View summary
Get-VSCodeChatEditingSessions | 
    Format-Table SessionId, FileCount, OperationCount, LastModified -AutoSize
```

---

### `Get-VSCodeChatEditingFiles`

Lists files modified in a chat editing session.

**Syntax:**
```powershell
Get-VSCodeChatEditingFiles [-Session <PSCustomObject>]
Get-VSCodeChatEditingFiles [-SessionId <string>] [-Path <string>]
```

**Parameters:**
- `-Session` - Session object (from pipeline)
- `-SessionId` - Session ID
- `-Path` - Workspace folder path

**Returns:** Array of file objects with properties:
- `FilePath` - Full file path
- `FileName` - File name only
- `OperationCount` - Number of edit operations
- `RequestCount` - Number of requests that modified this file
- `EpochRange` - Range of epochs (e.g., "10-45")
- `RequestIds` - Array of request IDs
- `SessionId` - Parent session ID

**Methods:**
- `.GetOperations()` - Get edit operations for this file

**Examples:**
```powershell
# Get files from a session
$session = Get-VSCodeChatEditingSessions | Select-Object -First 1
$session.GetFiles()

# Using session ID
Get-VSCodeChatEditingFiles -SessionId "f6d02192-d8e0-4ffa-b687-3080be9023a1"

# Pipeline usage
Get-VSCodeChatEditingSessions | 
    Select-Object -First 1 | 
    Get-VSCodeChatEditingFiles |
    Format-Table FileName, OperationCount, RequestCount
```

---

### `Get-VSCodeChatEditingOperations`

Gets individual edit operations from a chat editing session.

**Syntax:**
```powershell
Get-VSCodeChatEditingOperations [-Session <PSCustomObject>] [-FilePath <string>] [-RequestId <string>]
```

**Parameters:**
- `-Session` - Session object (required)
- `-FilePath` - Filter to specific file
- `-RequestId` - Filter to specific request

**Returns:** Array of operation objects with properties:
- `Type` - Operation type (usually "textEdit")
- `FilePath` - Full file path
- `FileName` - File name only
- `RequestId` - Associated request ID
- `Epoch` - Operation epoch number
- `EditText` - Text that was inserted/modified
- `EditCount` - Number of edits in this operation
- `Range` - Text range affected
- `SessionId` - Parent session ID

**Examples:**
```powershell
# Get all operations
$session = Get-VSCodeChatEditingSessions | Select-Object -First 1
$session.GetOperations()

# Filter by file
$session.GetOperations() | Where-Object FileName -eq "VsCode.ps1"

# Filter by request
$ops = Get-VSCodeChatEditingOperations -Session $session -RequestId "request_abc123"

# View edit details
$ops | Select-Object FileName, Epoch, EditText | Format-Table
```

---

### `Find-VSCodeChatEditingSessionByMessage`

Finds the editing session and file modifications for a specific chat message.

**Syntax:**
```powershell
Find-VSCodeChatEditingSessionByMessage [-RequestId <string>] [-Path <string>]
```

**Parameters:**
- `-RequestId` - Request ID from chat message (supports pipeline)
- `-Path` - Workspace folder path (default: current directory)

**Returns:** Objects with properties:
- `Session` - The editing session object
- `RequestId` - The request ID searched
- `OperationCount` - Number of operations for this request
- `FilesModified` - Array of file paths modified
- `FileCount` - Number of files modified

**Examples:**
```powershell
# Find edits for a specific message
Find-VSCodeChatEditingSessionByMessage -RequestId "request_f9be0e94-5ec4-4d3b-a411-3704d2ad3a0b"

# Pipeline from chat history
$history = Get-VSCodeChatSessions | Select-Object -First 1 | Get-VSCodeChatSessionHistory
$history[0].RequestId | Find-VSCodeChatEditingSessionByMessage

# Find all messages that resulted in file edits
$messages = Get-VSCodeChatSessionHistory -SessionId "abc123"
$messages | ForEach-Object {
    $edits = Find-VSCodeChatEditingSessionByMessage -RequestId $_.RequestId
    if ($edits) {
        [PSCustomObject]@{
            Request = $_.Request.Substring(0, 60)
            FilesChanged = $edits.FileCount
        }
    }
}
```

---

## Object Methods

### Chat Session Object Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `GetMessages()` | `[switch]$IncludeThinking`<br>`[switch]$IncludeMetadata` | Message array | Gets conversation history |
| `GetEditingSession()` | None | Editing session object | Gets associated editing session |

### Chat Message Object Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `GetFileEdits()` | None | Edit result object | Finds file modifications from this message |

### Editing Session Object Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `GetFiles()` | None | File array | Lists modified files |
| `GetOperations()` | `[string]$FilePath`<br>`[string]$RequestId` | Operation array | Gets edit operations |
| `GetChatSession()` | None | Chat session object | Gets associated chat session |

### File Object Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `GetOperations()` | None | Operation array | Gets operations for this file |

---

## Common Workflows

### Workflow 1: Explore Recent Chat Sessions

```powershell
# Get recent sessions
$sessions = Get-VSCodeChatSessions | Select-Object -First 5

# View summary
$sessions | Format-Table Title, MessageCount, Created, LastModified

# Read most recent conversation
$messages = $sessions[0].GetMessages()
$messages | ForEach-Object {
    Write-Host "`n=== User ===" -ForegroundColor Cyan
    Write-Host $_.Request
    Write-Host "`n=== Copilot ===" -ForegroundColor Green
    Write-Host $_.Response
}
```

### Workflow 2: Find Which Messages Changed Files

```powershell
# Get a chat session
$session = Get-VSCodeChatSessions | Where-Object Title -like "*refactor*" | Select-Object -First 1

# Get messages
$messages = $session.GetMessages()

# Find messages that resulted in file edits
$messagesWithEdits = $messages | ForEach-Object {
    $edits = $_.GetFileEdits()
    if ($edits) {
        [PSCustomObject]@{
            Request = $_.Request.Substring(0, 70) + "..."
            FilesModified = $edits.FileCount
            Files = ($edits.FilesModified | ForEach-Object { Split-Path $_ -Leaf }) -join ", "
        }
    }
}

$messagesWithEdits | Format-Table -AutoSize
```

### Workflow 3: Analyze File Editing History

```powershell
# Get editing session
$editSession = Get-VSCodeChatEditingSessions | Select-Object -First 1

# Get all modified files
$files = $editSession.GetFiles()

# View details for each file
foreach ($file in $files) {
    Write-Host "`n=== $($file.FileName) ===" -ForegroundColor Yellow
    Write-Host "Operations: $($file.OperationCount)"
    Write-Host "Requests: $($file.RequestCount)"
    Write-Host "Epochs: $($file.EpochRange)"
    
    # Show first few operations
    $ops = $file.GetOperations() | Select-Object -First 3
    $ops | Format-Table Epoch, EditText -AutoSize
}
```

### Workflow 4: Correlate Chat and Editing Sessions

```powershell
# Start with a chat session
$chatSession = Get-VSCodeChatSessions | Select-Object -First 1

Write-Host "Chat Session: $($chatSession.Title)" -ForegroundColor Cyan
Write-Host "Messages: $($chatSession.MessageCount)"

# Get associated editing session
$editSession = $chatSession.GetEditingSession()

if ($editSession) {
    Write-Host "`nEditing Session Found!" -ForegroundColor Green
    Write-Host "Files Modified: $($editSession.FileCount)"
    Write-Host "Total Operations: $($editSession.OperationCount)"
    
    # Show modified files
    $files = $editSession.GetFiles()
    $files | Format-Table FileName, OperationCount, RequestCount
}
```

### Workflow 5: Export Chat History

```powershell
# Get a session
$session = Get-VSCodeChatSessions | Where-Object Title -like "*analysis*" | Select-Object -First 1

# Get messages with metadata
$messages = $session.GetMessages($false, $true)

# Export to JSON
$messages | ConvertTo-Json -Depth 5 | Out-File "chat-history.json"

# Export to text
$messages | ForEach-Object {
    "=" * 80
    "Timestamp: $($_.Timestamp)"
    "Request ID: $($_.RequestId)"
    ""
    "USER:"
    $_.Request
    ""
    "COPILOT:"
    $_.Response
    ""
} | Out-File "chat-history.txt"
```

### Workflow 6: Find All Edits to a Specific File

```powershell
# Search across all editing sessions
$targetFile = "VsCode.ps1"

$allSessions = Get-VSCodeChatEditingSessions

foreach ($session in $allSessions) {
    $files = $session.GetFiles() | Where-Object FileName -eq $targetFile
    
    if ($files) {
        Write-Host "`nSession: $($session.SessionId)" -ForegroundColor Yellow
        Write-Host "Date: $($session.LastModified)"
        Write-Host "Operations: $($files.OperationCount)"
        
        # Show sample operations
        $ops = $session.GetOperations($files.FilePath) | Select-Object -First 5
        $ops | Format-Table Epoch, EditText -Wrap
    }
}
```

---

## Examples

### Example 1: Daily Chat Summary

```powershell
function Get-DailyChatSummary {
    param([DateTime]$Date = (Get-Date))
    
    $sessions = Get-VSCodeChatSessions | 
        Where-Object { $_.Created.Date -eq $Date.Date }
    
    Write-Host "=== Chat Summary for $($Date.ToShortDateString()) ===" -ForegroundColor Cyan
    Write-Host "Total Sessions: $($sessions.Count)"
    Write-Host "Total Messages: $(($sessions | Measure-Object -Property MessageCount -Sum).Sum)"
    
    $sessions | Format-Table Title, MessageCount, Created
}
```

### Example 2: Find Long Responses

```powershell
function Get-LongResponses {
    param([int]$MinLength = 1000)
    
    $sessions = Get-VSCodeChatSessions
    
    foreach ($session in $sessions) {
        $messages = $session.GetMessages()
        $long = $messages | Where-Object { $_.Response.Length -gt $MinLength }
        
        if ($long) {
            Write-Host "`nSession: $($session.Title)" -ForegroundColor Yellow
            foreach ($msg in $long) {
                Write-Host "  Request: $($msg.Request.Substring(0, 50))..."
                Write-Host "  Response Length: $($msg.Response.Length) chars"
            }
        }
    }
}
```

### Example 3: File Change Impact Analysis

```powershell
function Get-FileChangeImpact {
    $editSessions = Get-VSCodeChatEditingSessions
    
    # Aggregate by file
    $fileImpact = @{}
    
    foreach ($session in $editSessions) {
        $files = $session.GetFiles()
        foreach ($file in $files) {
            if (-not $fileImpact.ContainsKey($file.FilePath)) {
                $fileImpact[$file.FilePath] = @{
                    TotalOps = 0
                    Sessions = 0
                    LastModified = $session.LastModified
                }
            }
            $fileImpact[$file.FilePath].TotalOps += $file.OperationCount
            $fileImpact[$file.FilePath].Sessions += 1
        }
    }
    
    # Convert to objects
    $fileImpact.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            File = Split-Path $_.Key -Leaf
            TotalOperations = $_.Value.TotalOps
            SessionCount = $_.Value.Sessions
            LastModified = $_.Value.LastModified
        }
    } | Sort-Object TotalOperations -Descending
}

# Usage
Get-FileChangeImpact | Format-Table -AutoSize
```

---

## Performance Notes

- **Efficient JSON Parsing**: Uses `ConvertFrom-JsonStream` (based on System.Text.Json.JsonDocument) for metadata extraction, which is ~7x faster than full JSON deserialization
- **Lazy Loading**: Message history and operations are loaded on-demand via methods
- **Caching**: Consider caching session lists if running multiple queries
- **Large Files**: For sessions with many operations (>1000), consider filtering early

## Storage Locations

Chat sessions are stored in:
```
%APPDATA%\Code\User\workspaceStorage\{hash}\chatSessions\
```

Editing sessions are stored in:
```
%APPDATA%\Code\User\workspaceStorage\{hash}\chatEditingSessions\
```

Each editing session contains:
- `state.json` - Operation timeline and metadata
- `contents/` - Snapshots of file contents at various epochs
