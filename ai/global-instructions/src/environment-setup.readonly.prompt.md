
## Environment preparation
- Install git if it is not already installed
- Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path.
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
- Ensure the user-profile skill directory exists at `~/.agents/skills/`.
  - Prefer `.agents/` over `.copilot/` or `.github/` for user-level skills.

## Upgrade existing installs
- Detect whether this profile was initialized by that legacy setup flow:
  - One or more required user-skill files are missing:
    - `~/.agents/skills/setting/SKILL.md`
    - `~/.agents/skills/create-instruction/SKILL.md`
    - `~/.agents/skills/create-skill-global/SKILL.md`
    - `~/.agents/skills/update-jumper-instructions/SKILL.md`
    - `~/.agents/skills/git-workflow/SKILL.md`
- If detected, run an in-place upgrade:
  - Keep existing git history and user-created files.
  - Replace only the files defined in this setup file with current contents.
  - Install or update user-profile skills under `~/.agents/skills/` from the embedded sections below.
  - Preserve user-created instructions, skills, and settings that are not explicitly listed in this setup file.
- If not detected, continue normal setup flow.

- If `$VSCODE_PROFILE/instructions/global.readonly.instructions.md` file is missing, create it and copy the full contents of `global.readonly.instructions.md` into it, preserving the `applyTo: "**"` header
- Update my settings as below. Use careful string manipulation that accounts for JSON escaping requirements. Read the existing JSON, parse it, modify the object, and write it back (using ConvertFrom-Json and ConvertTo-Json). If a setting key is unsupported in the current editor, skip it and report that in your summary.
  - Set my global `github.copilot.chat.codeGeneration.useInstructionFiles` setting to `true`
  - If it doesn't already exist, append `$VSCODE_PROFILE/instructions` to the global setting `github.copilot.chat.codeGeneration.instructions` and `chat.instructionsFilesLocations` lists
