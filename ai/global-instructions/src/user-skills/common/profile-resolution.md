# Scope And Profile Resolution

Use this reference from user-profile skills to resolve target scope and paths without duplicating logic across VS Code, Cursor, and Claude.

## Resolve $VSCODE_PROFILE
1. Determine the active editor family and channel first (VS Code Stable, VS Code Insiders, Cursor, or Claude) from active app metadata, and keep that channel when resolving paths.
2. Resolve `$VSCODE_PROFILE` using the active editor profile path for that same family/channel.
3. If the active profile path cannot be determined from settings/profiles metadata, use editor and channel fallback candidates:
  - VS Code Windows Stable: `$Env:AppData\Code\User\`
  - VS Code Windows Insiders: `$Env:AppData\Code - Insiders\User\`
  - VS Code macOS Stable: `$HOME/Library/Application Support/Code/User/`
  - VS Code macOS Insiders: `$HOME/Library/Application Support/Code - Insiders/User/`
  - VS Code Linux Stable: `$HOME/.config/Code/User/`
  - VS Code Linux Insiders: `$HOME/.config/Code - Insiders/User/`
  - Cursor Windows: `$Env:AppData\Cursor\User\`
  - Cursor macOS: `$HOME/Library/Application Support/Cursor/User/`
  - Cursor Linux: `$HOME/.config/Cursor/User/`
  - Claude Windows: `$Env:AppData\Claude\User\`
  - Claude macOS: `$HOME/Library/Application Support/Claude/User/`
  - Claude Linux: `$HOME/.config/Claude/User/`
4. Treat this resolved path as `$VSCODE_PROFILE` for compatibility with existing instruction/skill conventions.

## Scope Modes
- `workspace`: current repository/workspace files.
- `profile`: VS Code or Cursor profile-level user customizations.
- `global`: managed global files under `$VSCODE_PROFILE` used by this setup.

## Path Mapping

### Settings And Config
- `global`:
  - `$VSCODE_PROFILE/settings.json`
  - `$VSCODE_PROFILE/tasks.json`
  - `$VSCODE_PROFILE/mcp.json`
  - `$VSCODE_PROFILE/keybindings.json`
- `workspace`:
  - `.vscode/settings.json`
  - `.vscode/tasks.json`
  - `.vscode/mcp.json` (if used)
  - `.vscode/keybindings.json` (if used)

### Instructions
- `global`, `profile` or `user`:
  - `$VSCODE_PROFILE/instructions/`
- `workspace`:
  - `.github/instructions/*.instructions.md`
  - or workspace-level `copilot-instructions.md` where applicable

### Skills
- `profile` (preferred default):
  - `~/.agents/skills/<name>/SKILL.md`
- `workspace`:
  - `.agents/skills/<name>/SKILL.md`
- Prefer `.agents/` over `.copilot/` or `.github/` for skills.

### Resolver Outputs
- `--user`:
  - VS Code: `~/.agents`
  - Cursor: `~/.cursor`
  - Claude: `~/.claude`
- `--rules`:
  - VS Code: `~/.agents/instructions`
  - Cursor: `~/.cursor/rules`
  - Claude: prefer `~/.claude/commands` (fallbacks: `~/.claude/rules`, `~/.claude`)
- `--workspace`:
  - VS Code: `<workspace-root>/.agents`
  - Cursor: `<workspace-root>/.cursor`
  - Claude: `<workspace-root>/.claude`

## Resolver Return Shape
- For path modes (`--profile`, `--user`, `--rules`, `--workspace`), resolver scripts return a JSON tuple array:
  - `["<EDITOR>", "<SCOPE_PATH>"]`
  - item 1: editor name
  - item 2: resolved path for the requested mode
- `--name` returns only the editor name string.

## Exported Variables
- Resolver scripts also export these variables in-process:
  - `$EDITOR`
  - `$SCOPE_PATH`

## Backup Rule
- Use exactly one `.bak` file per target file per change.
- If `<filename>.bak` already exists, replace its contents with the current pre-change contents of `<filename>`.
