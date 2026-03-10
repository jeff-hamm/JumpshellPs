# JumpShell

JumpShell is a VS Code and Cursor extension for managing the JumpShell Copilot skill pack in the user `.agents/skills` directory.

## What It Does

- Automatically installs the bundled JumpShell skills into `~/.agents/skills` when the extension activates for a new extension version.
- Automatically installs/updates `ai_backends` into `~/.agents/src/python/ai-backends` (or a configured override path) during skill install/update.
- Automatically installs JumpShell MCP server configuration on first activation for a new extension version.
- Updates existing extension-managed skill folders when the bundled hashes change.
- Falls back to the repository's top-level `skills/` folder during development if bundled assets have not been generated yet.
- Updates JumpShell MCP server configuration into user or workspace `mcp.json`.
- For workspace scope, resolves `.vscode/mcp.json` or `.cursor/mcp.json` based on host/editor context (or an explicit setting override).

## Commands

- `JumpShell: Update Skills`
- `JumpShell: Install MCP Configuration`

## Configuration

- `jumpshell.skillsPath` - target folder for managed skills.
- `jumpshell.installMcpOnSkillsInstall` - optionally install MCP config when `JumpShell: Update Skills` runs.
- `jumpshell.installAiBackendsOnSkillsInstall` - optionally install/update `ai_backends` when `JumpShell: Update Skills` runs.
- `jumpshell.aiBackendsPath` - optional explicit target path for managed `ai_backends`.
- `jumpshell.mcpConfigScope` - write MCP config to `user` or `workspace`.
- `jumpshell.workspaceMcpDirectory` - when `jumpshell.mcpConfigScope` is `workspace`, choose `auto`, `vscode`, or `cursor` for the workspace config folder.
- `jumpshell.moduleRootPath` - optional explicit JumpShell module path (auto-detected when blank).

## Development

```bash
npm install
npm run build
```

`npm run build` does two things:

1. Copies the repository's top-level `skills/` folder into `assets/skills/`.
2. Copies `mcps/` and `src/python/ai-backends` into extension `assets/`.
3. Compiles the extension from `src/` to `dist/`.

For local extension-host development, the extension can install directly from the repo's `skills/` folder even before `assets/skills/` exists.

## Packaging

```bash
npm run package
```

`vsce` will run `npm run build` through `vscode:prepublish`, so the packaged VSIX includes the current skill bundle.
