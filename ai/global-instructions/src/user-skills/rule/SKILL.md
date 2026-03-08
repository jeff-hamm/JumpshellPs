---
name: rule
description: 'Create, edit, or refactor instruction/rules files for workspace or user. Use for requests like "global (rules|instructions)", "my (rules|instructions)", "your (rules|instructions)", "project (rules|instructions)", "workspace (rules|instructions)", "user (rules|instructions)", "coding standards", "guardrails", "policy".'
argument-hint: 'scope=[workspace|user](default:user) name=<instruction-name>'
---

# Create Instruction or Rule

Create or update instruction files (VS Code) or rules files (Cursor) for user or workspace targets.

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

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})


## Workflow

{{SCRIPT_PATHS_NOTE}}

1. Resolve the target directory and derive the target file path:
   ```sh
   target_file=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --rules)/<instruction-name>.md
   # For workspace scope: ... --rules --workspace ...
   ```
   > **Note:** These scripts run in a child process — they output the path directly to stdout.

2. If the file already exists (update scenario), back it up before editing:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase before --file "$target_file"
   ```
   Skip this step when creating a new file.

3. Create or update the target instruction/rule file. Keep wording concise and non-duplicative.

4. Review the diff and approve or reject:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file" --approve --message "rules: <description>"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file" --reject
   ```

## Safety Rules

- Never edit `*.readonly.*.md` files.
- Prefer updating an existing instruction file before creating a new one.
