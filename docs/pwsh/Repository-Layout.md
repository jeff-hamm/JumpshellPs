---
layout: default
title: Repository Layout
---

# Repository Layout

This repository now has a split architecture with root compatibility shims and canonical source under `src`.

## Top-Level Structure

| Path | Purpose |
|---|---|
| `JumpShellPs.psd1` | Root module manifest shim that points to `src/pwsh/JumpShellPs.psm1` |
| `JumpShellPs.psm1` | Root module shim that imports the source manifest |
| `Install.ps1` | Root extension install entrypoint (delegates to `extensions/Install.ps1`) |
| `src/pwsh` | Canonical PowerShell module implementation |
| `src/python` | Python sources, including `ai-backends` |
| `extensions/jumpshell` | VS Code/Cursor extension source and assets |
| `skills` | Source skills bundled by extension and linked by module installer |
| `mcps` | MCP config templates bundled into extension assets |
| `docs` | Repository documentation set |

## Canonical Source Paths

- PowerShell module source: `src/pwsh`
- Module installer orchestration: `src/pwsh/Install.ps1`
- Module dependency installer internals: `src/pwsh/Install/Install.ps1`
- MCP runtime and installer: `src/pwsh/mcp/server.ps1`, `src/pwsh/mcp/Install-Mcp.ps1`
- VS Code chat/storage tooling: `src/pwsh/vscode`
- Layout presets: `src/pwsh/vscode-workspaces`

## Refactor Mapping (Old -> New)

| Old location | New canonical location |
|---|---|
| `*.ps1` module scripts at repo root | `src/pwsh/*.ps1` |
| `Install/*` | `src/pwsh/Install/*` |
| `mcp/*` | `src/pwsh/mcp/*` |
| `vscode/*` | `src/pwsh/vscode/*` |
| `vscode-workspaces/*` | `src/pwsh/vscode-workspaces/*` |

## Entry Point Matrix

| Goal | Entry point |
|---|---|
| Import module from repo checkout | `Import-Module .\JumpShellPs.psd1 -Force` |
| Install/update extension VSIX | `pwsh ./Install.ps1 -Build` or `pwsh ./extensions/Build.ps1 -Install` |
| Install module dependencies/skills/MCP/apps | `pwsh ./src/pwsh/Install.ps1` |
| Manage MCP from module | `Install-JumpShellMcp`, `Start-JumpShellMcpServer`, `Get-JumpShellMcp` |

## Notes

- Root files remain for compatibility and tooling convenience.
- New implementation work should target `src/pwsh`, `src/python`, and `extensions/jumpshell`.
- Documentation and scripts should prefer canonical source paths over legacy root paths.
