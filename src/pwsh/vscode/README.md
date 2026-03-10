# VS Code Utilities

This folder contains the PowerShell and Python utilities used by `JumpShellPs` to inspect VS Code/Copilot chat history, correlate chat to file edits, manage workspace storage/layout state, and archive sessions for analysis.

## Quick Start

Import the module from the repo root:

```powershell
Import-Module .\JumpShellPs.psd1 -Force
```

Common first commands:

```powershell
Get-VSCodeChatSessions -Path .
Get-VSCodeChatEditingSessions -Path .
Search-VsCodeChat -Query "workspace" -Path .
```

## File Map

| File | Purpose | Main Commands |
|---|---|---|
| `EditorContext.ps1` | Detect editor variant and resolve profile/user/rules/workspace paths across VS Code, Cursor, Claude, and VSCodium. | `Get-VSCodeVariant`, `Is-VsCode`, `Resolve-VscodeProfile`, `Resolve-EditorPath`, `Get-VSCodeUserPath` |
| `WorkspaceStorage.ps1` | Locate workspace storage folders from local paths or remote URIs. Supports related-folder matching and `-All` discovery. | `Get-VSCodeWorkspaceStorage`, `Get-VSCodeWorkspaceStorageFromGlobal`, `Get-MD5Hash` |
| `ChatSessions.ps1` | Read Copilot chat session metadata and conversation history from both `.json` and `.jsonl` session formats. | `Get-VSCodeChatSessions`, `Get-VSCodeChatSessionHistory` |
| `ChatEditing.ps1` | Read chat editing sessions and per-file/per-operation edits from `chatEditingSessions/state.json`. | `Get-VSCodeChatEditingSessions`, `Get-VSCodeChatEditingFiles`, `Get-VSCodeChatEditingOperations`, `Find-VSCodeChatEditingSessionByMessage` |
| `SessionArchive.ps1` | Archive chat + editing sessions, generate manifests, search chat text/regex, and provide compatibility aliases. | `Copy-VsCodeChatSessions`, `Search-VsCodeChat`, `Resolve-VSCodeWorkspaceStorageById` |
| `WorkspaceLayout.ps1` | Export/import workspace layout state (`state.vscdb`) and selected `.vscode/settings.json` layout keys. | `Export-WorkspaceLayout`, `Apply-WorkspaceLayout` |
| `extract_copilot_chat_context.py` | Normalize archived sessions into AI-friendly JSONL datasets and markdown report. | Python CLI script |

## Key Workflows

### 1. Inspect Chat Sessions

```powershell
Get-VSCodeChatSessions -Path . | Select-Object -First 5 Title, MessageCount, LastModified

$session = Get-VSCodeChatSessions -Path . | Select-Object -First 1
$session.GetMessages() | Select-Object -First 3 Request, Response
```

### 2. Correlate Chat to File Edits

```powershell
$editSession = Get-VSCodeChatEditingSessions -Path . | Select-Object -First 1
$editSession.GetFiles() | Select-Object FileName, OperationCount, RequestCount

$history = Get-VSCodeChatSessionHistory -Session $session
Find-VSCodeChatEditingSessionByMessage -RequestId $history[0].RequestId -Path .
```

### 3. Search Chat Content

```powershell
Search-VsCodeChat -Query "workspaceStorage" -Path .
Search-VsCodeChat -Query "Get-VSCode.*" -Regex -Path .
Search-VsCodeChat -Query "manifest" -WorkspaceId "<workspaceStorageHash>"
```

Notes:
- `Search-VsCodeChat` is the primary command.
- Compatibility aliases are provided: `Search-VsCodeChatSessions`, `Search-AiSessions`, and `Search-Ai`.

### 4. Archive and Normalize Sessions

```powershell
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive -Normalize
```

Archive output includes:
- `_manifest.json`
- `MANIFEST.md`
- copied `chatSessions/` and `chatEditingSessions/`
- optional normalized output from `extract_copilot_chat_context.py`

### 5. Export or Apply Workspace Layout

```powershell
Export-WorkspaceLayout -Name "my-layout" -WorkspacePath .
Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\vscode-workspaces\my-layout.json -WhatIf
Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\vscode-workspaces\my-layout.json
```

## Requirements

- PowerShell 7+
- `sqlite3` CLI for layout apply/export operations
- Python (optional) for `-Normalize` archive processing

## Notes

- Chat readers support both legacy `.json` and newer `.jsonl` session file formats.
- Workspace storage lookup handles direct matches and related paths/workspaces.
- Some helper functions in these files are internal utilities used by the main commands.
