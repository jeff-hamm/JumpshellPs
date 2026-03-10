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
- You may edit files returned by `scripts/resolve-editor.ps1` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.

## Available scripts

- **`scripts/resolve-editor.ps1`** — Resolves target file path (pwsh)
- **`scripts/change-control.ps1`** — Before/after safety checks with approve/reject (pwsh)
- **`scripts/patch-json.ps1`** — Applies structured JSON patches for settings/task/mcp/keybinding files (pwsh)

## References

- **`references/known-settings.md`** — Cache of discovered setting keys; you may add rows freely.


## Workflow

{{SCRIPT_PATHS_NOTE}}

1. **Discover the setting key** when the request uses natural-language or a descriptive label instead of an exact dot-notation key.

   **Fast path — consult `references/known-settings.md` first (no filesystem access needed):**

   Read [`references/known-settings.md`](references/known-settings.md) and check whether the user's description matches any row.
   If it does, skip steps b–d and proceed directly to patching.

   **After any slow-path discovery that finds a new broadly-useful key**, add it to `references/known-settings.md` under the appropriate section so future lookups are instant. You may edit that file freely.

   **Slow path — when key is not in references:**

   a. Use the `get_vscode_api` deferred tool (load via `tool_search_tool_regex` first) to search setting IDs by keyword — fastest option when available.

   b. Otherwise use ripgrep against only the most relevant extension directory (scope the search, don't scan all extensions):
      ```pwsh
      # Resolve the extensions root
      $extRoot = if (Test-Path "$env:USERPROFILE\.vscode\extensions") { "$env:USERPROFILE\.vscode\extensions" } else { (pwsh scripts/resolve-editor.ps1 --profile) | Split-Path | Join-Path -ChildPath "..\extensions" }
      # Search only likely extension dirs first (e.g. github.copilot* for Copilot-related terms)
      $hint = "<publisher-prefix>"   # e.g. "github.copilot" for reasoning/copilot queries, "ms-vscode" for core editor
      $dirs = Get-ChildItem $extRoot -Directory | Where-Object Name -like "$hint*" | Select-Object -ExpandProperty FullName
      if (-not $dirs) { $dirs = @($extRoot) }
      rg -l -i "<keyword1>|<keyword2>" $dirs --glob "package.json" --max-depth 2
      ```
      Then read only the matching file(s) and extract the relevant key:
      ```pwsh
      rg -n -i "<keyword1>|<keyword2>" "<matching-package.json-path>"
      ```

   c. If no match is found, grep the active settings file for partial matches:
      ```pwsh
      rg -n -i "<keyword>" (pwsh scripts/resolve-editor.ps1 --settings setting)
      ```

   d. Present the top candidate key(s) with their current value. Auto-confirm if there is exactly one strong match; otherwise ask the user.

2. Parse the prompt to determine the exact JSON intent before editing:
   - Determine target type: `setting`, `task`, `mcp`, or `keybinding`.
   - Determine operation: `add`, `edit`, or `remove`.
   - Determine patch parameters:
     - Object-style edits (`setting`, `task`, `mcp`): `--path` and optional `--value`.
     - Array-style edits (`keybinding`): `--value` and optional `--match`.

3. Use `scripts/patch-json.ps1` to apply the patch when the request maps to a structured JSON change:

   > **`--value` must be valid JSON.** Numbers: `'2'`. Booleans: `'true'`. Strings: `'"value"'` (outer single-quotes, inner double-quotes in pwsh) or `'"value"'` in bash.

   ```pwsh
   # Example: edit a setting (number)
   pwsh scripts/patch-json.ps1 --type setting --action edit --path editor.tabSize --value '2'

   # Example: edit a setting (string) — note inner double-quotes for JSON string encoding
   pwsh scripts/patch-json.ps1 --type setting --action edit --path github.copilot.chat.responsesApiReasoningEffort --value '"high"'

   # Example: add a VS Code task (workspace scoped)
   pwsh scripts/patch-json.ps1 --type task --action edit --path tasks --value '[{"label":"build","type":"shell","command":"npm run build"}]' --workspace

   # Example: remove a keybinding by matcher
   pwsh scripts/patch-json.ps1 --type keybinding --action remove --match '{"key":"ctrl+alt+b","command":"workbench.action.tasks.build"}'
   ```
   > **Note:** `patch-json` resolves the correct file automatically via `resolve-editor` unless `--file` is provided.

4. Review the diff and approve or reject:
   ```pwsh
   # Resolve settings file path first
   pwsh scripts/resolve-editor.ps1 --settings setting
   # Use the returned path as <file_path> in the commands below
   # Review only (returns diff JSON, does not commit)
   pwsh scripts/change-control.ps1 --phase after --file "<file_path>"
   # Approve: git add + commit + remove backup
   pwsh scripts/change-control.ps1 --phase after --file "<file_path>" --approve --message "settings: update <key>"
   # Reject: restore from backup
   pwsh scripts/change-control.ps1 --phase after --file "<file_path>" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Use `scripts/patch-json.ps1` for JSON changes when possible; fall back to manual editing only for unsupported transformations.
- Keep settings changes minimal and idempotent.