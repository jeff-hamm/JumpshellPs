---
layout: default
title: MCP Server
---

# JumpShell MCP Server

JumpShell exposes module functions as MCP tools over stdio so chat agents can call them directly.

## Canonical Paths

- Runtime server script: `src/pwsh/mcp/server.ps1`
- MCP config installer script: `src/pwsh/mcp/Install-Mcp.ps1`
- Module MCP management functions: `src/pwsh/Mcp.ps1`
- MCP template used by extension packaging: `mcps/jumpshellps.json`

Legacy root-level `mcp/` compatibility files were removed.

## Setup Paths

### Option A: VS Code/Cursor Extension (recommended)

Run command:

- `JumpShell: Install MCP Configuration`

Relevant extension settings:

- `jumpshell.installMcpOnSkillsInstall`
- `jumpshell.mcpConfigScope` (`user` or `workspace`)
- `jumpshell.workspaceMcpDirectory` (`auto`, `vscode`, or `cursor`)
- `jumpshell.moduleRootPath` (optional explicit module/repo path)

### Option B: Module command

```powershell
Import-Module .\JumpShellPs.psd1 -Force
Install-JumpShellMcp -Scope User
# or
Install-JumpShellMcp -Scope Workspace
```

### Option C: Direct script

```powershell
pwsh ./src/pwsh/mcp/Install-Mcp.ps1 -ModuleRoot (Resolve-Path .) -Scope User
```

## Runtime Lifecycle Commands

```powershell
Import-Module .\JumpShellPs.psd1 -Force

Get-JumpShellMcp
Start-JumpShellMcpServer
Stop-JumpShellMcpServer -Force
```

## Autostart Behavior

On module import, JumpShell attempts:

- `Start-JumpShellMcpServer -OnImport -Quiet`

Autostart is skipped when:

- `JUMPSHELL_MCP_DISABLE_AUTOSTART=1`
- `JUMPSHELL_MCP_SERVER_MODE=1`

Disable autostart for a session:

```powershell
$env:JUMPSHELL_MCP_AUTOSTART = '0'
```

## Config Shape

Template file `mcps/jumpshellps.json` contains:

- `servers.jumpshellPs.type = stdio`
- `command = pwsh`
- `args` for `-File ${serverScript}` and `-ModuleRoot ${moduleRoot}`
- environment values:
  - `JUMPSHELL_MCP_DISABLE_AUTOSTART=1`
  - `TERM_PROGRAM=mcp`

## Logs and State

State/log paths are written under JumpShell runtime directory:

- `~/.jumpshell/mcp/server-state.json`
- `~/.jumpshell/mcp/server.stdout.log`
- `~/.jumpshell/mcp/server.stderr.log`

## Troubleshooting

1. Validate module path resolution:

```powershell
Import-Module .\JumpShellPs.psd1 -Force
Get-JumpShellMcp | Format-List ModuleRoot,ServerScript,IsRunning
```

2. Reinstall config:

```powershell
Install-JumpShellMcp -Scope User
```

3. Restart process and inspect logs:

```powershell
Stop-JumpShellMcpServer -Force
Start-JumpShellMcpServer
Get-Content ~/.jumpshell/mcp/server.stderr.log -Tail 200
```

4. In editor, verify server entry exists (`jumpshellPs`) and reset cached tools if needed.
