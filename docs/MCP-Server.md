# JumpShell MCP Server

The JumpShell module includes a built-in MCP server that **dynamically exposes every exported module function** as a first-class tool for VS Code chat agents.

## How It Works

On startup the server imports `JumpShellPs`, introspects every exported function, and generates an MCP tool definition for each one — complete with typed `inputSchema` built from parameter metadata (mandatory flags, switch→boolean, string[], etc.).

Tool names are the function name lowercased with hyphens replaced by underscores (e.g., `New-SshDrive` → `new_sshdrive`, `Pgp-Encrypt` → `pgp_encrypt`). Arguments map directly to PowerShell parameter names (case-insensitive).

A `jumpshell_search` meta-tool is always available for natural-language discovery when the agent isn't sure which function to call.

## What This Enables

You can issue multi-step natural-language requests and the agent will chain the right tools automatically:

> "Mount an SSH drive to myserver, grab secret.pgp from it, decrypt it to ~/secrets, and add that directory to my backups."

The agent sees `new_sshdrive`, `pgp_decrypt`, `backup_directory` (and 115+ more) as directly-callable tools with full parameter schemas — no intermediate "search then invoke" step needed.

## Available Tools

All exported functions from the module are registered as tools. As of the last count, this includes **~118 functions** organized by source file:

| Source File | Functions |
|---|---|
| Ssh.ps1 | New-SshDrive, Get-SshPort, Get-SshUserName, Get-SshProperty, Next-AvailableDriveLetter, SshValidate |
| pgp.ps1 | Pgp-Encrypt, Pgp-Decrypt, Pgp-List, Pgp-New, Pgp-Add, Pgp-Key, Pgp-Get-Key, Pgp-Key-Delete, Pgp-Address, Pgp-Install, Pgp |
| Backups.ps1 | Backup-Directory, Run-Backup |
| Drives.ps1 | Find-Drive, Find-PsDrives, Get-AvailableDriveLetter, New-NfsDrive, New-RemoteDrive, Get-DriveOrCreate |
| VsCode.ps1 | Get-VSCodeChatSessions, Get-VSCodeWorkspaceStorage, Export-WorkspaceLayout, Apply-WorkspaceLayout, ... |
| Secrets.ps1 | Get-SecretCredential, Ensure-SecretManager, Get-SecretString |
| Network.ps1 | Add-WSLPortForward, Remove-WSLPortForward, Get-WSLPortForward |
| Git.ps1 | Clone-ShallowSubmodule, Push-All, Pull-All |
| ... | (see full list via `jumpshell_search` or `tools/list`) |

Plus the meta-tool:
- `jumpshell_search` — fuzzy search across all functions by name, source file, or parameter keywords.

## Installation Flow

When you run `Install.ps1`, it performs these MCP steps:

1. Runs `mcp/Install-Mcp.ps1`.
2. Resolves your user `mcp.json` path (including active VS Code profile when available).
3. Adds or updates server entry `jumpshellPs`.
4. Imports `JumpShellPs`.
5. Starts the MCP server asynchronously.

## Server Lifecycle

The MCP server process is detached and tracked with state files under:

- `~/.jumpshell/mcp/server-state.json`
- `~/.jumpshell/mcp/server.stdout.log`
- `~/.jumpshell/mcp/server.stderr.log`

Use these commands to manage it:

```powershell
Get-JumpShellMcp
Start-JumpShellMcpServer
Stop-JumpShellMcpServer -Force
```

## Autostart Behavior

On module import, `Start-JumpShellMcpServer -OnImport -Quiet` is called.

Autostart is skipped automatically when either condition is true:

- `JUMPSHELL_MCP_DISABLE_AUTOSTART=1`
- The process is already in MCP server mode (`JUMPSHELL_MCP_SERVER_MODE=1`)

You can disable autostart globally in your shell/session:

```powershell
$env:JUMPSHELL_MCP_AUTOSTART = '0'
```

## Example Agent Prompts

- `Mount an SSH drive to myserver on port 2222, then list the files in /data.`
- `Encrypt "my-secret-value" with PGP key "alice" and show me the armored output.`
- `Search JumpShell for commands related to VS Code workspace storage.`
- `Create a new PGP key for "deploy-key", then export the public key.`
- `Add a WSL port forward for port 8080, then check what forwards are active.`

## Troubleshooting

If tools do not appear in VS Code:

1. Open MCP server list (`MCP: List Servers`) and verify `jumpshellPs` is present.
2. Check server output logs:
   - `~/.jumpshell/mcp/server.stdout.log`
   - `~/.jumpshell/mcp/server.stderr.log`
3. Restart server:
   - `Stop-JumpShellMcpServer -Force`
   - `Start-JumpShellMcpServer`
4. Reset cached tools:
   - Run `MCP: Reset Cached Tools` in VS Code.

## Design Notes

- Transport: stdio with newline-delimited JSON-RPC messages.
- Protocol methods: `initialize`, `ping`, `tools/list`, `tools/call`, `logging/setLevel`.
- Tool generation: fully dynamic from module introspection at startup.
- Tool naming: `function_name` (lowercase, hyphens→underscores).
- Parameter schemas: built from `[Parameter]` attributes — type, mandatory, switch→boolean.
- Annotations: auto-inferred from naming conventions (Get-/Find-/Test- → readOnly, Remove-/Delete- → destructive).
- Server instructions include full function-to-source-file category map so the model understands module organization.
