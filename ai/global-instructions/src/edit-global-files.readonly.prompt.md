# *IMPORTANT: NEVER EDIT THIS FILE!*
# Global File Management
Use this file whenever you view, edit or remove my global settings, instructions, or skills.

## Preferred Skills
- Prefer user-profile skills under `~/.agents/skills/`.
- Route requests to these slash commands when applicable:
  - `/setting` for "global settings" or "my settings" (`settings.json`, `tasks.json`, `mcp.json`, `keybindings.json`)
  - `/create-instruction` for "global rules" or "your instructions"
  - `/create-skill-global` for "global skills", "your skills", or "slash skills"
  - `/update-jumper-instructions` to update this module from `origin` by downloading `dist/initial-setup.readonly.prompt.md` from raw content and running it
- Use this file as a fallback only when those skills are missing.

## Paths
- I will refer to my editor profile path as `$VSCODE_PROFILE`. To find the location
  1. Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path.
  2. If the active profile path cannot be determined from settings/profiles metadata, use editor and channel fallback candidates:
    - powershell (Stable): `$Env:AppData\\Code\\User\\`
    - powershell (Insiders): `$Env:AppData\\Code - Insiders\\User\\`
    - powershell (Cursor): `$Env:AppData\\Cursor\\User\\`
    - cmd.exe (Stable): `%APPDATA%/Code/User/`
    - cmd.exe (Insiders): `%APPDATA%/Code - Insiders/User/`
    - cmd.exe (Cursor): `%APPDATA%/Cursor/User/`
    - macOS (Stable): `~/Library/Application Support/Code/User/`
    - macOS (Insiders): `~/Library/Application Support/Code - Insiders/User/`
    - macOS (Cursor): `~/Library/Application Support/Cursor/User/`
    - Linux (Stable): `$HOME/.config/Code/User/`
    - Linux (Insiders): `$HOME/.config/Code - Insiders/User/`
    - Linux (Cursor): `$HOME/.config/Cursor/User/`
  3. Once you have that path, make sure it is a git repository.
    - If `$VSCODE_PROFILE` is not a git repository, clone it from https://github.com/jeff-hamm/copilot-instructions, or, if that fails, initialize a new git repository there
      - If you create it, the .gitignore should be
        ```
        *
        !.gitignore
        !instructions/
        !instructions/**
        !copilot-instructions.md
        !/*.json
        ```
- I will refer to my user-profile skill path as `$AGENTS_SKILLS_HOME`
  - powershell (Windows): `$HOME\.agents\skills\`
  - cmd.exe (Windows): `%USERPROFILE%/.agents/skills/`
  - macOS: `$HOME/.agents/skills/`
  - Linux: `$HOME/.agents/skills/`
  - Prefer `.agents/` over `.copilot/` or `.github/` for user-level skills.
## Permissions
- You may view my editor configuration and any paths and files specified below
- If you can't access those files directly, use terminal commands to read those files, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in `$VSCODE_PROFILE` and `$AGENTS_SKILLS_HOME` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands to read those files, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly 
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      - Example:
        ```powershell
        @'
        <paste the markdown block verbatim>
        '@ | Set-Content -Path "$VSCODE_PROFILE\instructions\global.readonly.instructions.md" -Encoding UTF8
        ```        
## Backup
- Before making a change to any file in `$VSCODE_PROFILE` or `$AGENTS_SKILLS_HOME`
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
- Files: `$VSCODE_PROFILE/settings.json`, `$VSCODE_PROFILE/tasks.json`, `$VSCODE_PROFILE/mcp.json`, `$VSCODE_PROFILE/keybindings.json`
- I may call these "my settings", "global settings", or "global files"
- Check for an existing setting before adding new values; edit or append as needed
- Validate the file to prevent duplicates before finishing

## Global Instructions
- Locations:
  - global: `$VSCODE_PROFILE/instructions`
  - profile: `$VSCODE_PROFILE/instructions/*.instructions.md`
- Files: `copilot-instructions.md` (all filetypes) or `<NAME>.instructions.md` (file-specific)
- I may call these "global rules", "your instructions", or "your rules"
- Keep wording short and precise. They can significantly reduce my performance if they are too long
- Review the result for clarity and duplication

## Global Skills
- Location (profile default): `$AGENTS_SKILLS_HOME`
- Files: `<SKILL_NAME>/SKILL.md` and optional `scripts/`, `references/`, `assets/`
- I may call these "global skills", "your skills", or "slash skills"
- Ensure `SKILL.md` uses valid frontmatter (`---`, `name`, `description`, optional `argument-hint`, `---`)
- Prefer multiple focused skills over one long procedural workflow
---
# *IMPORTANT: NEVER EDIT THIS FILE!*
