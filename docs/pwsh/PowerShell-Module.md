---
layout: default
title: PowerShell Module
---

# PowerShell Module Guide

This document covers the JumpShell PowerShell module architecture after the source move to `src/pwsh`.

## Import Paths

### Repository checkout (recommended for development)

```powershell
Import-Module .\JumpShellPs.psd1 -Force
```

### Installed module path

```powershell
Import-Module JumpShellPs -Force
```

## Root Compatibility Shims

- `JumpShellPs.psd1` points root module loading at `src/pwsh/JumpShellPs.psm1`.
- `JumpShellPs.psm1` imports `src/pwsh/JumpShellPs.psd1`.
- `Install.ps1` at root is now extension-focused and calls `extensions/Install.ps1`.

## Source Module Layout

- Source manifest: `src/pwsh/JumpShellPs.psd1`
- Source loader: `src/pwsh/JumpShellPs.psm1`
- Feature scripts: `src/pwsh/*.ps1`
- Installer internals: `src/pwsh/Install/*`
- MCP integration: `src/pwsh/Mcp.ps1`, `src/pwsh/mcp/*`
- VS Code tooling: `src/pwsh/vscode/*`

## Module Load Flow

On import, `src/pwsh/JumpShellPs.psm1`:

1. Sets source/repo globals:
- `JumpShellSourcePath`
- `JumpShellRepoRoot`
- `JumpShellPath`

2. Dot-sources `.ps1` scripts in deterministic order.

3. Scans loaded scripts to build `JumpShell_FunctionFileMap`.

4. Exports public functions and aliases.

5. Runs profile setup and attempts MCP autostart.

## Install and Update Flows

### Module dependency installer

Use source installer for module concerns:

```powershell
pwsh ./src/pwsh/Install.ps1 -Skills -Modules -Applications -Mcps
```

Flags:

- `-Skills`
- `-Modules`
- `-Applications`
- `-Mcps`
- `-NoPull`

### Extension installer

Root `Install.ps1` is for extension install workflow:

```powershell
pwsh ./Install.ps1 -Build
```

## Skills and Python Backends

Module skill installation links top-level `skills/*` into:

- `~/.agents/skills`

The VS Code/Cursor extension can also install/update bundled `ai-backends` Python source when skills are installed.

## MCP Integration in Module

`src/pwsh/Mcp.ps1` provides:

- `Get-JumpShellMcp`
- `Install-JumpShellMcp`
- `Start-JumpShellMcpServer`
- `Stop-JumpShellMcpServer`

Canonical scripts resolve under `src/pwsh/mcp`.

## Useful Verification Commands

```powershell
# Confirm source-root import path
Import-Module .\JumpShellPs.psd1 -Force
(Get-Module JumpShellPs).Path

# Confirm MCP script resolution
Get-JumpShellMcp | Format-List ModuleRoot,ServerScript

# List exported functions
Get-Command -Module JumpShellPs | Sort-Object Name
```

## Related Docs

- [Repository-Layout.md](Repository-Layout.md)
- [MCP-Server.md](MCP-Server.md)
- [../extension/VSCode-Extension.md](../extension/VSCode-Extension.md)
