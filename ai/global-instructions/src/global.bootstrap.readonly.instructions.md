---
applyTo: "**"
---
# NEVER EDIT THIS FILE

## Path Resolution
Use the **resolve-editor** scripts for all path resolution:
- Windows: `pwsh scripts/resolve-editor.ps1 <mode>`
- macOS/Linux: `bash scripts/resolve-editor.sh <mode>`

| Mode | Returns |
|------|---------|
| `--profile` | Editor profile path (settings, instructions) |
| `--rules` | Instructions/rules directory |
| `--skills` | Skills directory |
| `--settings [type]` | Specific settings file (`setting`, `task`, `mcp`, `keybinding`) |

## Your Editable Directories

| resolve-editor Mode | Contents | File Pattern |
|---------------------|----------|--------------|
| `--settings setting` | VS Code/Cursor & Copilot settings | `settings.json` |
| `--rules` | Rules applied to all chats | `*.instructions.md` |
| `--skills` | User-profile slash skills | `*/SKILL.md` |

**Exception:** Never edit `*.readonly.*.md` files.

## Terminology
- "global settings", "my settings" → `settings.json`, `tasks.json`, `mcp.json`
- "global rules", "your instructions" → files in the instructions directory (resolve with `--rules`)
- "global skills", "your skills" → files under skills directory (resolve with `--skills`)

## Workspace Customization Path Preference
- For workspace-level customizations, prefer `.agents/` over `.copilot/` or `.github/`.
- Prefer `.agents/skills/<name>/` for workspace skills.

## User Skill Commands
- Prefer user-profile skills in `~/.agents/skills/` for global file edits.
- Preferred commands:
  - `/setting`
  - `/rule`
  - `/create-skill-global`
  - `/update-jumper-instructions`
- Use `global.readonly.instructions.md` as fallback guidance when those skills are not available.

## What To Do
1. **Explore** skills directory (resolve with `--skills`) for existing skills
2. **Use** preferred user skills (`/setting`, `/rule`, `/create-skill-global`, `/update-jumper-instructions`) for global edits
3. **Check** settings.json for existing values before adding
4. **Use** `global.readonly.instructions.md` for fallback editing guidance
5. **Run** `initial-setup.readonly.prompt.md` if core files are missing

---

⚠️ **STOP: Before editing ANY file listed above, you MUST first read `global.readonly.instructions.md` in the instructions directory (resolve with `--rules`) for required permissions, backup procedures, and editing rules.**
