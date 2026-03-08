---
name: setting
description: 'Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".'
argument-hint: 'scope=[workspace|profile](default:profile) type=[setting|task|mcp|keybinding](default:setting) key=<setting-key>'
---

# Setting

Edit VS Code or Cursor setting/config files using scope-aware path resolution and safe change controls.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target file path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

1. Resolve the target file path. `--git-commit` also backs up the current file before editing:
   ```{{SHELL_NAME}}
   file_path=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --settings task --git-commit)
   # For workspace scope: ... --settings task --workspace --git-commit ...
   ```
   > **Note:** Script outputs the path directly to stdout.
   >
   > Valid types: `setting` → `settings.json` ⬦ `task` → `tasks.json` ⬦ `mcp` → `mcp.json` ⬦ `keybinding` → `keybindings.json`
   >
   > `--git-commit` is a no-op if the file doesn't exist yet.

2. Read, parse, and modify the JSON file at the resolved path without duplicating existing values.

3. Review the diff and approve or reject:
   ```{{SHELL_NAME}}
   # Review only (returns diff JSON, does not commit):
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path"
   # Approve — git add + commit + remove backup:
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --approve --message "settings: update <key>"
   # Reject — restore from backup:
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Keep settings changes minimal and idempotent.