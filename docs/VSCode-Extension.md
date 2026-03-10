# VS Code and Cursor Extension Guide

The extension source is in `extensions/jumpshell`.

It manages JumpShell skill installation, MCP configuration, and optional Python backend sync.

## Capabilities

- Installs bundled skills into `~/.agents/skills`
- Updates extension-managed skills on hash changes
- Optionally installs/updates `ai-backends` Python source
- Installs/updates JumpShell MCP server config
- Performs startup auto-setup once per extension version

## Commands

- `JumpShell: Update Skills`
- `JumpShell: Install MCP Configuration`

## Settings

| Setting | Default | Purpose |
|---|---|---|
| `jumpshell.skillsPath` | `~/.agents/skills` | Skill install target |
| `jumpshell.installAiBackendsOnSkillsInstall` | `true` | Install/update bundled ai-backends when skills update |
| `jumpshell.aiBackendsPath` | empty | Optional explicit ai-backends target path |
| `jumpshell.installMcpOnSkillsInstall` | `false` | Also run MCP config install during skill update |
| `jumpshell.mcpConfigScope` | `user` | MCP config write target (`user` or `workspace`) |
| `jumpshell.moduleRootPath` | empty | Optional explicit JumpShell module/repo root |

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

## Troubleshooting

1. Skills did not update
- Run `JumpShell: Update Skills`
- Check extension output channel `JumpShell`

2. MCP install cannot find module root
- Set `jumpshell.moduleRootPath`
- Re-run `JumpShell: Install MCP Configuration`

3. TypeScript issues before package
- Run `npm --prefix ./extensions/jumpshell run check`

## Related Docs

- [MCP-Server.md](MCP-Server.md)
- [Repository-Layout.md](Repository-Layout.md)
- [PowerShell-Module.md](PowerShell-Module.md)
