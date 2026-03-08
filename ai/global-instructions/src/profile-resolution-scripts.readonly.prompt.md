## Co-located Profile Resolver Scripts
- This setup installs per-platform scripts that resolve `$VSCODE_PROFILE`.
- Source these scripts from `src/user-skills/common/` and install generated copies next to each managed user-skill `SKILL.md` file:
  - `resolve-editor.ps1` for PowerShell environments
  - `resolve-editor.sh` for bash/zsh environments
- During skill execution, run the script that matches the current platform from that skill directory and use stdout as `$VSCODE_PROFILE`.
- The resolver scripts automatically prefer the active editor channel (VS Code Stable, VS Code Insiders, Cursor, or Claude) when that metadata is available.

