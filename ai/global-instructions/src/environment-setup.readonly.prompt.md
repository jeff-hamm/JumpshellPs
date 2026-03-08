
## Environment preparation
- Install git if it is not already installed.
- Install the **resolve-editor** scripts from the **Common Scripts** section below — these handle all path resolution for the active editor (VS Code, VS Code Insiders, Cursor, or Claude).
  - Windows: `pwsh resolve-editor.ps1 <mode>`
  - macOS/Linux: `bash resolve-editor.sh <mode>`
- Use these modes throughout the rest of setup:
  | Mode | Returns |
  |------|---------|
  | `--profile` | Editor profile path (settings & instructions live here) |
  | `--user` | User customization root (`~/.agents`, `~/.cursor`, etc.) |
  | `--skills` | User skills directory (`~/.agents/skills`) |
  | `--settings setting` | Path to `settings.json` |
  | `--rules` | Instructions/rules directory |
  | `--name` | Editor name string |
- If the profile path (`--profile`) is not a git repository, clone from https://github.com/jeff-hamm/copilot-instructions, or if that fails, initialize a new git repository there
  - If you create it, the .gitignore should be
    ```
    *
    !.gitignore
    !instructions/
    !instructions/**
    !copilot-instructions.md
    !/*.json
    ```
- Ensure the user skills directory exists (resolve with `--skills`).

## Upgrade existing installs
- Check `~/.agents/.jumpskills-version` to detect a previous install.
  - **File exists** → in-place upgrade:
    - Keep existing git history and user-created files.
    - Replace only the files defined in this setup file with current contents.
    - Install or update user-profile skills under the skills directory from the embedded sections below.
    - Preserve user-created instructions, skills, and settings that are not explicitly listed in this setup file.
  - **File absent** → fresh install: continue normal setup flow.
- After completing setup (fresh or upgrade), write the current date (ISO format, e.g. `2026-03-07`) to `~/.agents/.jumpskills-version`.

- If the instructions directory (resolve with `--rules`) does not contain `global.readonly.instructions.md`, create it and copy the full contents from the section below, preserving the `applyTo: "**"` header
- Update settings using `scripts/patch-json.ps1` / `scripts/patch-json.sh` when the `setting` skill is already installed (upgrade path). For fresh installs where the skill is not yet present, apply changes with `ConvertFrom-Json`/`json.loads()` inline. If a key is unsupported in the current editor, skip it and report that in your summary.
  ```powershell
  # Windows (upgrade — setting skill already installed)
  $settingsFile = pwsh ~/.agents/skills/setting/scripts/resolve-editor.ps1 --settings setting
  pwsh ~/.agents/skills/setting/scripts/patch-json.ps1 --type setting --action edit --path github.copilot.chat.codeGeneration.useInstructionFiles --value 'true'
  ```
  - Set `github.copilot.chat.codeGeneration.useInstructionFiles` to `true`
  - Append the instructions path (resolve with `--rules`) to `github.copilot.chat.codeGeneration.instructions` and `chat.instructionsFilesLocations` lists if not already present
