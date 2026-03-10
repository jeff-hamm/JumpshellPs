---
layout: default
title: VS Code Extension
---

# VS Code and Cursor Extension Guide

The extension source is in `extensions/jumpshell`.

It manages Jumpshell skill installation, MCP configuration, and optional Python backend sync.

## Capabilities

- Installs bundled skills into `~/.agents/skills`
- Updates extension-managed skills on hash changes
- Optionally installs/updates `ai-backends` Python source
- Installs/updates Jumpshell MCP server config
- Performs startup auto-setup once per extension version

## Commands

- `Jumpshell: Update Skills`
- `Jumpshell: Install MCP Configuration`

## Settings

| Setting | Default | Purpose |
|---|---|---|
| `jumpshell.skillsPath` | `~/.agents/skills` | Skill install target |
| `jumpshell.installAiBackendsOnSkillsInstall` | `true` | Install/update bundled ai-backends when skills update |
| `jumpshell.aiBackendsPath` | empty | Optional explicit ai-backends target path |
| `jumpshell.installMcpOnSkillsInstall` | `false` | Also run MCP config install during skill update |
| `jumpshell.mcpConfigScope` | `user` | MCP config write target (`user` or `workspace`) |
| `jumpshell.workspaceMcpDirectory` | `auto` | Workspace MCP location when scope is `workspace` (`auto`, `vscode`, or `cursor`) |
| `jumpshell.moduleRootPath` | empty | Optional explicit Jumpshell module/repo root |

## Build and Package

From repository root:

```powershell
# Build VSIX (increments extension patch version)
pwsh ./extensions/Build.ps1

# Build and install VSIX into active editor
pwsh ./extensions/Build.ps1 -Install

# Install existing VSIX directly
pwsh ./extensions/Install.ps1 -VsixPath ./extensions/jumpshell.vsix
```

Inside extension folder:

```powershell
cd ./extensions/jumpshell
npm install
npm run check
npm run build
npm run package
```

## Editor Support Notes

VSIX install automation targets:

- VS Code
- VS Code Insiders
- Cursor

The installer chooses a target editor from environment/process hints and available CLI commands.

## Asset Sources

- Primary bundled skills source: `extensions/jumpshell/assets/skills`
- Bundled MCP templates: `extensions/jumpshell/assets/mcps`
- Development fallback source: top-level `skills` and `mcps` folders

Manifest file:

- `extensions/jumpshell/assets/skills-manifest.json`

## MCP Install Behavior

The extension installs MCP config by:

1. Resolving module source root (`src/pwsh`)
2. Loading template `jumpshellps.json`
3. Replacing placeholders for:
- `${moduleRoot}`
- `${serverScript}`
4. Writing merged config into:
- user profile `mcp.json`, or
- workspace `.vscode/mcp.json`

When scope is `workspace`, directory selection is controlled by `jumpshell.workspaceMcpDirectory`:

- `auto`: choose by active editor and existing files
- `vscode`: force `.vscode/mcp.json`
- `cursor`: force `.cursor/mcp.json`

## Troubleshooting

1. Skills did not update
- Run `Jumpshell: Update Skills`
- Check extension output channel `Jumpshell`

2. MCP install cannot find module root
- Set `jumpshell.moduleRootPath`
- Re-run `Jumpshell: Install MCP Configuration`

3. TypeScript issues before package
- Run `npm --prefix ./extensions/jumpshell run check`

## Related Docs

- [../pwsh/MCP-Server.md](../pwsh/MCP-Server.md)
- [../pwsh/Repository-Layout.md](../pwsh/Repository-Layout.md)
- [../pwsh/PowerShell-Module.md](../pwsh/PowerShell-Module.md)
