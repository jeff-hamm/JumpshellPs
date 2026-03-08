---
name: setting
description: 'Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".'
argument-hint: 'scope=[workspace|profile](default:profile) type=[setting|task|mcp|keybinding](default:setting) key=<setting-key-or-description>'
---

# Setting

Edit VS Code or Cursor setting/config files using scope-aware path resolution and safe change controls.

## Permissions
- You may view my editor configuration and any paths resolved by the scripts and skills below
- If you can't access files directly, use terminal commands — do not prompt for permission.
- *NEVER* Edit or remove a file with a `.readonly.*.md*` file extension. You may read them though.
- You may edit files returned by `scripts/resolve-editor{{SHELL_EXT}}` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target file path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})
- **`scripts/patch-json{{SHELL_EXT}}`** — Applies structured JSON patches for settings/task/mcp/keybinding files ({{SHELL_NAME}})


## Workflow

{{SCRIPT_PATHS_NOTE}}

1. **Discover the setting key** when the request uses natural-language or a descriptive label instead of an exact dot-notation key (e.g. "reasoning effort", "tab size", "font size"):

   a. Use the `get_vscode_api` deferred tool (load via `tool_search_tool_regex` first if not already available) to search available setting IDs by keyword.

   b. If `get_vscode_api` is unavailable, search installed-extension `package.json` files for matching `contributes.configuration` entries:
      ```{{SHELL_NAME}}
      # Resolve the user profile dir, then derive the extensions dir one level up
      $profile = (pwsh scripts/resolve-editor{{SHELL_EXT}} --settings setting | ConvertFrom-Json)[1]
      $extRoot = Join-Path (Split-Path (Split-Path $profile)) ".vscode\extensions"
      if (-not (Test-Path $extRoot)) { $extRoot = "$env:USERPROFILE\.vscode\extensions" }
      Get-ChildItem $extRoot -Recurse -Filter package.json -Depth 3 |
        Select-String -Pattern '"<keyword>"' |
        Select-Object -First 20
      ```
      Replace `<keyword>` with a relevant term from the user's description (e.g. `reasoning`, `effort`, `thinking`).

   c. If neither approach finds a match, try reading the active settings file and presenting keys that partially match the description.

   d. Present the top candidate key(s) with their current value — then either:
      - Confirm and proceed if exactly one strong match is found, or
      - Ask the user to confirm which candidate key is correct before patching.

2. Parse the prompt to determine the exact JSON intent before editing:
   - Determine target type: `setting`, `task`, `mcp`, or `keybinding`.
   - Determine operation: `add`, `edit`, or `remove`.
   - Determine patch parameters:
     - Object-style edits (`setting`, `task`, `mcp`): `--path` and optional `--value`.
     - Array-style edits (`keybinding`): `--value` and optional `--match`.

3. Use `scripts/patch-json{{SHELL_EXT}}` to apply the patch when the request maps to a structured JSON change:
   ```{{SHELL_NAME}}
   # Example: edit a setting
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type setting --action edit --path editor.tabSize --value '2'

   # Example: add a VS Code task (workspace scoped)
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type task --action edit --path tasks --value '[{"label":"build","type":"shell","command":"npm run build"}]' --workspace

   # Example: remove a keybinding by matcher
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type keybinding --action remove --match '{"key":"ctrl+alt+b","command":"workbench.action.tasks.build"}'
   ```
   > **Note:** `patch-json` resolves the correct file automatically via `resolve-editor` unless `--file` is provided.

4. Review the diff and approve or reject:
   ```{{SHELL_NAME}}
   # Resolve settings file path first
   {{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --settings setting
   # Use the returned path as <file_path> in the commands below
   # Review only (returns diff JSON, does not commit)
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>"
   # Approve: git add + commit + remove backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>" --approve --message "settings: update <key>"
   # Reject: restore from backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Use `scripts/patch-json{{SHELL_EXT}}` for JSON changes when possible; fall back to manual editing only for unsupported transformations.
- Keep settings changes minimal and idempotent.