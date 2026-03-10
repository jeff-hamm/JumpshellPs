# JumpShell

JumpShell is a VS Code extension scaffold for installing and updating the JumpShell Copilot skill pack into the user `.agents/skills` directory.

## What It Does

- Installs the bundled JumpShell skills into `~/.agents/skills` by default.
- Updates existing extension-managed skill folders when the bundled hashes change.
- Removes only the skill folders previously installed by the extension.
- Falls back to the repository's top-level `skills/` folder during development if bundled assets have not been generated yet.
- Installs JumpShell MCP server configuration into user or workspace `mcp.json`.

## Commands

- `JumpShell: Install Skills`
- `JumpShell: Update Skills`
- `JumpShell: Install MCP Configuration`
- `JumpShell: Remove Managed Skills`
- `JumpShell: Open Skills Folder`
- `JumpShell: Check GitHub VSIX Updates`

## Configuration

- `jumpshell.skillsPath` - target folder for managed skills.
- `jumpshell.installMcpOnSkillsInstall` - optionally install MCP config when skills are installed or updated.
- `jumpshell.mcpConfigScope` - write MCP config to `user` or `workspace`.
- `jumpshell.moduleRootPath` - optional explicit JumpShell module path (auto-detected when blank).
- `jumpshell.extensionReleaseRepo` - GitHub repo slug for VSIX update checks.
- `jumpshell.includePreReleaseUpdates` - include pre-release tags when checking updates.

## Development

```bash
npm install
npm run build
```

`npm run build` does two things:

1. Copies the repository's top-level `skills/` folder into `assets/skills/`.
2. Compiles the extension from `src/` to `dist/`.

For local extension-host development, the extension can install directly from the repo's `skills/` folder even before `assets/skills/` exists.

## Packaging

```bash
npm run package
```

`vsce` will run `npm run build` through `vscode:prepublish`, so the packaged VSIX includes the current skill bundle.

## GitHub VSIX Updates

If JumpShell is installed from a VSIX instead of the VS Code Marketplace, run `JumpShell: Check GitHub VSIX Updates`.

The command will:

1. Query the configured GitHub releases repository.
2. Compare the newest release tag with the currently installed extension version.
3. Download the newest `.vsix` asset and install it when a newer version is available.
