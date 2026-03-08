# *IMPORTANT: NEVER EDIT THIS FILE!*
# Global File Management
Use this file whenever you view, edit or remove my global settings, instructions, or skills.

## Preferred Skills
- Prefer user-profile skills under `~/.agents/skills/`.
- Route requests to these slash commands when applicable:
  - `/setting` for "global settings" or "my settings" (`settings.json`, `tasks.json`, `mcp.json`, `keybindings.json`)
  - `/rule` for "global rules" or "your instructions"
  - `/create-skill-global` for "global skills", "your skills", or "slash skills"
  - `/update-jumper-instructions` to update this module from `origin` by downloading `dist/initial-setup.readonly.prompt.md` from raw content and running it
- Use this file as a fallback only when those skills are missing.

## Paths
- Use the **resolve-editor** scripts (co-located with skills at `scripts/resolve-editor.ps1` / `resolve-editor.sh`) for all path resolution:
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
- If the profile path is not a git repository, clone it from https://github.com/jeff-hamm/copilot-instructions, or if that fails, initialize a new git repository there
  - If you create it, the .gitignore should be
    ```
    *
    !.gitignore
    !instructions/
    !instructions/**
    !copilot-instructions.md
    !/*.json
    ```

## Permissions
- You may view my editor configuration and any paths resolved by the scripts
- If you can't access those files directly, use terminal commands to read them, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in the profile path and user path without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.

## Backup
- Before making a change to any managed file
  - check to see if the target path is in a git repository and has uncommitted changes with `git status`. If so, prompt me to review and commit or stash them first. If I'd like to commit them, create a commit message summarizing the changes and commit them.
  - Create exactly one backup file per change at `<filename>.bak` before modifying any global file. If that file exists, replace its contents with the current pre-change contents of `<filename>`.
- After making changes:
  1. If the target path is in git, show the diff with `git diff <filename>` and summary with `git diff --stat <filename>`
  2. If the target path is not in git, show an equivalent before/after comparison
  3. Explain what changed and why
  4. Ask if I approve
    - if no, revert it by restoring `<filename>` from `<filename>.bak`
    - if yes and target path is in git
      1. Stage the changes with `git add <filename>`
      2. Commit with a descriptive message using `git commit -m "..."`
      3. Confirm the commit was successful

## Global Settings
- Resolve with `--settings setting` (or `task`, `mcp`, `keybinding`)
- I may call these "my settings", "global settings", or "global files"
- Check for an existing setting before adding new values; edit or append as needed
- Validate the file to prevent duplicates before finishing

## Global Instructions
- Resolve with `--rules` for the instructions directory
- Files: `copilot-instructions.md` (all filetypes) or `<NAME>.instructions.md` (file-specific)
- I may call these "global rules", "your instructions", or "your rules"
- Keep wording short and precise. They can significantly reduce my performance if they are too long
- Review the result for clarity and duplication

## Global Skills
- Resolve with `--skills` for the skills directory
- Files: `<SKILL_NAME>/SKILL.md` and optional `scripts/`, `references/`, `assets/`
- I may call these "global skills", "your skills", or "slash skills"
- Ensure `SKILL.md` uses valid frontmatter (`---`, `name`, `description`, optional `argument-hint`, `---`)
- Prefer multiple focused skills over one long procedural workflow
---
# *IMPORTANT: NEVER EDIT THIS FILE!*
