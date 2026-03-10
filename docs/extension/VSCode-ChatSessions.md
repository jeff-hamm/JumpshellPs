---
layout: default
title: Chat Sessions
---

# VS Code and Cursor Chat Session Functions

Jumpshell includes analysis utilities for chat history, edit sessions, and workspace storage correlation.

Primary implementation lives under `src/pwsh/vscode`.

## Quick Start

```powershell
Import-Module .\Jumpshell.psd1 -Force

Get-VSCodeChatSessions -Path . | Select-Object -First 5 Title, MessageCount, LastModified
Get-VSCodeChatEditingSessions -Path . | Select-Object -First 5 SessionId, FileCount, OperationCount
```

## Core Commands

### Session discovery

- `Get-VSCodeChatSessions`
- `Get-VSCodeChatSessionHistory`

### Editing correlation

- `Get-VSCodeChatEditingSessions`
- `Get-VSCodeChatEditingFiles`
- `Get-VSCodeChatEditingOperations`
- `Find-VSCodeChatEditingSessionByMessage`

### Search and archive

- `Search-VsCodeChat`
- `Copy-VsCodeChatSessions`

## Common Object Methods

```powershell
$session = Get-VSCodeChatSessions -Path . | Select-Object -First 1
$messages = $session.GetMessages()
$editSession = $session.GetEditingSession()

$messages[0].GetFileEdits()
$editSession.GetFiles()
$editSession.GetOperations()
```

## Alias Compatibility

Jumpshell auto-creates `-Ai-` aliases for many `-VSCodeChat-` commands.

Examples:

- `Get-AiEditingSessions` -> alias for `Get-VSCodeChatEditingSessions`
- `Search-AiSessions` -> alias for `Search-VsCodeChat`
- `Search-Ai` -> alias for `Search-VsCodeChat`

## Typical Workflows

### 1. Find messages that changed files

```powershell
$session = Get-VSCodeChatSessions -Path . | Select-Object -First 1
$session.GetMessages() | ForEach-Object {
    $edits = $_.GetFileEdits()
    if ($edits) {
        [PSCustomObject]@{
            Request = ($_.Request.Substring(0, [Math]::Min(80, $_.Request.Length)))
            FilesChanged = $edits.FileCount
            Files = ($edits.FilesModified | ForEach-Object { Split-Path $_ -Leaf }) -join ', '
        }
    }
}
```

### 2. Search across sessions

```powershell
Search-VsCodeChat -Query "workspaceStorage" -Path .
Search-VsCodeChat -Query "Install-JumpshellMcp" -Path .
Search-VsCodeChat -Query "Get-VSCode.*" -Regex -Path .
```

### 3. Archive for analysis

```powershell
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive -Normalize
```

Archive output includes:

- `_manifest.json`
- `MANIFEST.md`
- copied `chatSessions/` and `chatEditingSessions/`
- optional normalized datasets from `extract_copilot_chat_context.py`

## Storage Paths

Actual storage root depends on editor variant/profile.

Pattern:

- `%APPDATA%\<Editor>\User\workspaceStorage\{hash}\chatSessions\`
- `%APPDATA%\<Editor>\User\workspaceStorage\{hash}\chatEditingSessions\`

Common `<Editor>` values:

- `Code`
- `Code - Insiders`
- `Cursor`
- `VSCodium`

Resolve active location through:

- `Resolve-VscodeProfile`
- `Get-VSCodeWorkspaceStorage`

## Related Docs

- [VSCode-WorkspaceManagement.md](VSCode-WorkspaceManagement.md)
- [VSCode-QuickReference.md](VSCode-QuickReference.md)
- [../pwsh/PowerShell-Module.md](../pwsh/PowerShell-Module.md)
