
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
- Detect whether this script was already installed
- If detected, run an in-place upgrade:
  - Keep existing git history and user-created files.
  - Replace only the files defined in this setup file with current contents.
  - Install or update user-profile skills under the skills directory from the embedded sections below.
  - Preserve user-created instructions, skills, and settings that are not explicitly listed in this setup file.
- If not detected, continue normal setup flow.

- If the instructions directory (resolve with `--rules`) does not contain `global.readonly.instructions.md`, create it and copy the full contents from the section below, preserving the `applyTo: "**"` header
- Update settings (resolve with `--settings setting`). Use careful string manipulation that accounts for JSON escaping requirements. Read the existing JSON, parse it, modify the object, and write it back (using ConvertFrom-Json and ConvertTo-Json). If a setting key is unsupported in the current editor, skip it and report that in your summary.
  - Set `github.copilot.chat.codeGeneration.useInstructionFiles` to `true`
  - If it doesn't already exist, append the instructions path (resolve with `--rules`) to `github.copilot.chat.codeGeneration.instructions` and `chat.instructionsFilesLocations` lists
