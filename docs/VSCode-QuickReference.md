# JumpShell Quick Reference

## Load Module

```powershell
Import-Module .\JumpShellPs.psd1 -Force
```

## Extension Workflows

```powershell
# Build and package extension from repo root
pwsh ./extensions/Build.ps1

# Build and install into active editor (Code/Insiders/Cursor)
pwsh ./extensions/Build.ps1 -Install

# Install existing VSIX
pwsh ./extensions/Install.ps1 -VsixPath ./extensions/jumpshell.vsix
```

## MCP Workflows

```powershell
# Module-managed config
Install-JumpShellMcp -Scope User
Install-JumpShellMcp -Scope Workspace

# Process lifecycle
Get-JumpShellMcp
Start-JumpShellMcpServer
Stop-JumpShellMcpServer -Force
```

## Chat and Editing Analysis

```powershell
Get-VSCodeChatSessions -Path . | Select-Object -First 5 Title, MessageCount
Get-VSCodeChatSessionHistory -SessionId "<session-guid>"

Get-VSCodeChatEditingSessions -Path . | Select-Object -First 5 SessionId, FileCount, OperationCount
Get-AiEditingSessions | Select-Object -First 5 SessionId, FileCount, OperationCount
```

```powershell
Search-VsCodeChat -Query "workspaceStorage" -Path .
Search-VsCodeChat -Query "Install-JumpShellMcp" -Path .
Search-VsCodeChat -Query "Get-VSCode.*" -Regex -Path .
```

```powershell
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive
Copy-VsCodeChatSessions -Path . -DestinationPath .\chat-archive -Normalize
```

## Workspace and Profile Utilities

```powershell
Get-VSCodeVariant
Resolve-VscodeProfile
Resolve-EditorPath -Mode Workspace

Get-VSCodeWorkspaceStorage -Path .
Get-VSCodeWorkspaceStorage -Path . -All
Get-VSCodeWorkspaceStorageFromGlobal
```

## Layout Export and Apply

```powershell
# Layout files are stored under src/pwsh/vscode-workspaces
Export-WorkspaceLayout -Name "my-layout" -WorkspacePath .

Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\src\pwsh\vscode-workspaces\default.json -WhatIf
Apply-WorkspaceLayout -WorkspacePath . -LayoutJsonPath .\src\pwsh\vscode-workspaces\default.json
```

## Installer Entry Points

```powershell
# Root install script targets extension install workflow
pwsh ./Install.ps1 -Build

# Module dependency installer (skills/modules/apps/MCP)
pwsh ./src/pwsh/Install.ps1 -Skills -Modules -Applications -Mcps
```

## Related Docs

- [Repository-Layout.md](Repository-Layout.md)
- [PowerShell-Module.md](PowerShell-Module.md)
- [VSCode-Extension.md](VSCode-Extension.md)
- [MCP-Server.md](MCP-Server.md)
- [VSCode-ChatSessions.md](VSCode-ChatSessions.md)
- [VSCode-WorkspaceManagement.md](VSCode-WorkspaceManagement.md)
