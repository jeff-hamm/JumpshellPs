---
applyTo: "**"
---
# NEVER EDIT THIS FILE

## Path Resolution
- Use the **resolve-editor** scripts (installed at `~/.agents/skills/*/scripts/`) for all path resolution:
  - Windows: `pwsh scripts/resolve-editor.ps1 <mode>`
  - macOS/Linux: `bash scripts/resolve-editor.sh <mode>`
- Key modes:
  | Mode | Returns |
  |------|---------|
  | `--profile` | Editor profile path (settings, instructions) |
  | `--user` | User customization root (`~/.agents`, `~/.cursor`, etc.) |
  | `--rules` | Instructions/rules directory |
  | `--skills` | Skills directory |
  | `--settings [type]` | Specific settings file (`setting`, `task`, `mcp`, `keybinding`) |
  | `--name` | Editor name |
- The scripts auto-detect VS Code Stable, VS Code Insiders, Cursor, and Claude.

## Permissions
- You may view my editor configuration and any paths resolved by the scripts.
- If you can't access files directly, use terminal commands — do not prompt for permission.
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files under the profile path (`--profile`) and user path (`--user`) without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.

## Included User Skills (Generated)
{{GENERATED_SKILL_ITEMS}}

## Fallback
- Before editing global files, read `global.readonly.instructions.md` in the instructions directory (resolve with `--rules`).
- Run `initial-setup.readonly.prompt.md` when global instructions or skills are missing.