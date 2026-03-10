# JumpShellPs Documentation

This folder is the primary documentation set for the refactored JumpShellPs repository.

## Start Here

1. Read [../README.md](../README.md) for repository-level onboarding.
2. Read [Repository-Layout.md](Repository-Layout.md) to understand where everything moved.
3. Read [PowerShell-Module.md](PowerShell-Module.md) for module entrypoints, load flow, and install/update behavior.
4. Read [VSCode-Extension.md](VSCode-Extension.md) for extension behavior, settings, packaging, and install workflows.
5. Read [MCP-Server.md](MCP-Server.md) for MCP architecture and operational commands.

## Documentation Map

| File | Focus |
|---|---|
| [Repository-Layout.md](Repository-Layout.md) | Canonical repository structure and old-to-new path mapping after refactor |
| [PowerShell-Module.md](PowerShell-Module.md) | Root shims, source module internals, dependency install/update flows |
| [VSCode-Extension.md](VSCode-Extension.md) | VS Code/Cursor extension commands, settings, skill sync, MCP config install |
| [MCP-Server.md](MCP-Server.md) | MCP server lifecycle, config template, logs, troubleshooting |
| [VSCode-ChatSessions.md](VSCode-ChatSessions.md) | Chat session and edit-session analysis functions |
| [VSCode-WorkspaceManagement.md](VSCode-WorkspaceManagement.md) | Profile detection, workspace storage, and layout export/apply |
| [VSCode-QuickReference.md](VSCode-QuickReference.md) | Copy/paste command reference |

## Scope Notes

- Root-level `JumpShellPs.psd1` and `JumpShellPs.psm1` are compatibility shims.
- Canonical PowerShell implementation now lives in `src/pwsh`.
- Canonical MCP scripts now live in `src/pwsh/mcp`.
- Extension MCP template lives at `mcps/jumpshellps.json` and is bundled into extension assets.
- Root-level `Install.ps1` is now extension-focused and delegates to `extensions/Install.ps1`.
