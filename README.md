# JumpShellPs

JumpShellPs is a multi-surface automation repo with:

- PowerShell module sources in `src/pwsh`
- Python backend sources in `src/python`
- VS Code/Cursor extension sources in `extensions/jumpshell`
- skill sources in `skills`
- MCP template assets in `mcps`

## Quick Start

### 1. Import module from repository checkout

```powershell
Import-Module .\JumpShellPs.psd1 -Force
```

### 2. Build and install extension (optional)

```powershell
pwsh ./extensions/Build.ps1 -Install
```

### 3. Configure MCP

```powershell
Install-JumpShellMcp -Scope User
Get-JumpShellMcp
```

Or run extension command:

- `JumpShell: Install MCP Configuration`

## Important Entry Points

| Entry point | Purpose |
|---|---|
| `JumpShellPs.psd1` | Root module shim to `src/pwsh/JumpShellPs.psm1` |
| `JumpShellPs.psm1` | Root compatibility module shim |
| `Install.ps1` | Root extension install workflow wrapper |
| `src/pwsh/Install.ps1` | Module dependency/skills/apps/MCP installer |
| `extensions/Build.ps1` | Build VSIX (optionally install) |
| `extensions/Install.ps1` | Install existing VSIX into active editor |

## Repository Layout

```text
.
|- README.md
|- docs/
|- src/
|  |- pwsh/
|  |  |- JumpShellPs.psm1
|  |  |- Install/
|  |  |- mcp/
|  |  |- vscode/
|  |  `- vscode-workspaces/
|  `- python/
|     `- ai-backends/
|- extensions/
|  `- jumpshell/
|- skills/
`- mcps/
```

## Documentation

Start with:

- [docs/README.md](docs/README.md)

Key guides:

- [docs/Repository-Layout.md](docs/Repository-Layout.md)
- [docs/PowerShell-Module.md](docs/PowerShell-Module.md)
- [docs/VSCode-Extension.md](docs/VSCode-Extension.md)
- [docs/MCP-Server.md](docs/MCP-Server.md)
- [docs/VSCode-ChatSessions.md](docs/VSCode-ChatSessions.md)
- [docs/VSCode-WorkspaceManagement.md](docs/VSCode-WorkspaceManagement.md)
- [docs/VSCode-QuickReference.md](docs/VSCode-QuickReference.md)

## Notes on the Recent Refactor

- Canonical module scripts moved from repo root to `src/pwsh`.
- Root module files remain as compatibility shims.
- Root `Install.ps1` now delegates to extension install flow.
- MCP runtime and installer scripts now live only in `src/pwsh/mcp`.
