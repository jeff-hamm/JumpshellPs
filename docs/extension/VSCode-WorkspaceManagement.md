---
layout: default
title: Workspace Management
---

# VS Code and Cursor Workspace Management

JumpShell ships utilities for editor/profile detection, workspace storage lookup, and layout export/apply.

Implementation lives in `src/pwsh/vscode`.

## Load Module

```powershell
Import-Module .\JumpShellPs.psd1 -Force
```

## Editor Context Functions

### `Get-VSCodeVariant`

Returns current editor variant when detectable:

- `Code`
- `Code - Insiders`
- `Cursor`
- `Claude`
- `VSCodium`

### `Resolve-VscodeProfile`

Resolves active profile path for the current editor installation.

```powershell
Resolve-VscodeProfile
Resolve-VscodeProfile -ProfileName "Work"
```

### `Resolve-EditorPath`

Resolves editor-specific paths by mode:

- `Name`
- `Profile`
- `User`
- `Rules`
- `Workspace`

```powershell
Resolve-EditorPath -Mode Name
Resolve-EditorPath -Mode Profile
Resolve-EditorPath -Mode Workspace
```

### `Get-VSCodeUserPath`

Compatibility wrapper over `Resolve-VscodeProfile`.

## Workspace Storage Functions

### `Get-VSCodeWorkspaceStorage`

Find workspace storage folder(s) for local paths or URIs.

```powershell
Get-VSCodeWorkspaceStorage -Path .
Get-VSCodeWorkspaceStorage -Path . -All
Get-VSCodeWorkspaceStorage -Uri "vscode-remote://..."
```

### `Get-VSCodeWorkspaceStorageFromGlobal`

Enumerate workspace storage entries from global storage metadata.

```powershell
Get-VSCodeWorkspaceStorageFromGlobal | Select-Object Name, WorkspaceUri
```

## Layout Functions

Layout helpers are implemented in `src/pwsh/vscode/WorkspaceLayout.ps1`.

### `Export-WorkspaceLayout`

Export current workspace layout to JSON under module-managed layout directory.

```powershell
Export-WorkspaceLayout -Name "my-layout" -WorkspacePath .
```

### `Apply-WorkspaceLayout`

Apply a saved layout to a workspace database.

```powershell
Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\src\pwsh\vscode-workspaces\default.json -WhatIf
Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\src\pwsh\vscode-workspaces\default.json
```

## Storage Structure

Editor profile roots vary by installation and profile.

Common pattern:

- `%APPDATA%\<Editor>\User\workspaceStorage\{hash}\state.vscdb`
- `%APPDATA%\<Editor>\User\workspaceStorage\{hash}\workspace.json`

Use function-based resolution instead of hardcoding paths:

```powershell
$profile = Resolve-VscodeProfile
$storage = Get-VSCodeWorkspaceStorage -Path .
$dbPath = Join-Path $storage.FullName "state.vscdb"
```

## Requirements

- PowerShell 7+
- `sqlite3` CLI for layout export/apply

Install SQLite on Windows:

```powershell
winget install SQLite.SQLite
```

## Troubleshooting

1. Workspace storage not found
- Open the workspace in the target editor at least once.
- Retry with `-All`.
- Confirm you are resolving against the expected profile via `Resolve-VscodeProfile`.

2. Layout changes not visible
- Reload editor window after apply.
- Close editor before applying to avoid state overwrite.

3. Multiple storage folders for same workspace
- This is normal after recreates/moves.
- Use `Get-VSCodeWorkspaceStorage -Path . -All` and choose the active folder by recency.

## Related Docs

- [VSCode-ChatSessions.md](VSCode-ChatSessions.md)
- [VSCode-QuickReference.md](VSCode-QuickReference.md)
- [../pwsh/Repository-Layout.md](../pwsh/Repository-Layout.md)
