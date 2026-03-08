---
name: rule
description: 'Create, edit, or refactor instruction/rules files for workspace or user. Use for requests like "global (rules|instructions)", "my (rules|instructions)", "your (rules|instructions)", "project (rules|instructions)", "workspace (rules|instructions)", "user (rules|instructions)", "coding standards", "guardrails", "policy".'
argument-hint: 'scope=[workspace|user](default:user) name=<instruction-name>'
---

# Create Instruction or Rule

Create or update instruction files (VS Code) or rules files (Cursor) for user or workspace targets.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

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
