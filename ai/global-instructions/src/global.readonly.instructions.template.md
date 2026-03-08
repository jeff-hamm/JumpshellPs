---
applyTo: "**"
---
# NEVER EDIT THIS FILE

## Global Edit Routing
- Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path. E.g:
  - Cursor macOS: `$HOME/Library/Application Support/Cursor/User/`
  - VS Code Windows Stable: `$Env:AppData\Code\User\`
  - and so on
- Resolve `$USER_PROFILE_SETTING` for VS Code or Cursor using the active editor's preferred user-scoped settings folder. E.g:
  - Cursor: ~/.cursor
  - vscode: ~/.agents

## Permissions
- You may view my editor configuration and any paths and files specified above
- If you can't access those files directly, use terminal commands to read those files, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in `$VSCODE_PROFILE` and `$USER_PROFILE_SETTING` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands to read those files, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > ...` so the shell copies it exactly
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      - Example:
        ```powershell
        @'
        <paste the markdown block verbatim>
        '@ | Set-Content -Path "$VSCODE_PROFILE\instructions\global.readonly.instructions.md" -Encoding UTF8
        ```

## Included User Skills (Generated)
{{GENERATED_SKILL_ITEMS}}

## Fallback
      - Before editing global files, read `$VSCODE_PROFILE/instructions/global.readonly.instructions.md`.
      - Run `initial-setup.readonly.prompt.md` when global instructions or skills are missing.