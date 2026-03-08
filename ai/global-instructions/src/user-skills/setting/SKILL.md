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
- **`scripts/patch-json{{SHELL_EXT}}`** — Applies structured JSON patches for settings/task/mcp/keybinding files ({{SHELL_NAME}})

## Workflow

1. Parse the prompt first to determine the exact JSON intent before editing:
   - Determine target type: `setting`, `task`, `mcp`, or `keybinding`.
   - Determine operation: `add`, `edit`, or `remove`.
   - Determine patch parameters:
     - Object-style edits (`setting`, `task`, `mcp`): `--path` and optional `--value`.
     - Array-style edits (`keybinding`): `--value` and optional `--match`.

2. Use `scripts/patch-json{{SHELL_EXT}}` to apply the patch when the request maps to a structured JSON change:
   ```{{SHELL_NAME}}
   # Example: edit a setting
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type setting --action edit --path editor.tabSize --value '2'

   # Example: add a VS Code task (workspace scoped)
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type task --action edit --path tasks --value '[{"label":"build","type":"shell","command":"npm run build"}]' --workspace

   # Example: remove a keybinding by matcher
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type keybinding --action remove --match '{"key":"ctrl+alt+b","command":"workbench.action.tasks.build"}'
   ```
   > **Note:** `patch-json` resolves the correct file automatically via `resolve-editor` unless `--file` is provided.

3. Review the diff and approve or reject:
   ```{{SHELL_NAME}}
   file_path=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --settings setting)
   # Review only (returns diff JSON, does not commit)
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path"
   # Approve: git add + commit + remove backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --approve --message "settings: update <key>"
   # Reject: restore from backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Use `scripts/patch-json{{SHELL_EXT}}` for JSON changes when possible; fall back to manual editing only for unsupported transformations.
- Keep settings changes minimal and idempotent.