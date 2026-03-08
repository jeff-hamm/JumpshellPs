## Post-install: expand shell templates

After recreating all skill files above, replace the shell template placeholders in every installed `SKILL.md` file under `~/.agents/skills/` (recursively).

Detect the target operating system and substitute accordingly:

| Placeholder | Windows (PowerShell) | macOS / Linux (bash) |
|-------------|----------------------|----------------------|
| `{{SHELL_NAME}}` | `pwsh` | `bash` |
| `{{SHELL_EXT}}` | `.ps1` | `.sh` |

**Detection:** Use `$env:OS -eq 'Windows_NT'` (PowerShell) or `uname -s` (bash). If running on Windows, apply the PowerShell substitutions; otherwise apply the bash substitutions.

**Replacement scope:** Apply to all `SKILL.md` files under `~/.agents/skills/` that contain either placeholder token. Update them in-place.

**Preferred:** run the installed helper:
```powershell
# Windows
pwsh ~/.agents/scripts/expand-templates.ps1
```
```bash
# macOS/Linux
bash ~/.agents/scripts/expand-templates.sh
```

**Create Symlinks** Create symlinks for copilot, claude and cursor at ~/.copilot, ~/.claude and ~/.cursor to ~/.agents. If those paths already exist, ask if the user wants to migrate to ~/.agents, if so, move files there before replacing those paths with symlinks

## Verification

After all steps are complete, confirm each item:

| Item | Check |
|------|-------|
| resolve-editor works | `pwsh resolve-editor.ps1 --name` / `bash resolve-editor.sh --name` returns `Code`, `Cursor`, or similar |
| Instructions installed | `$(resolve-editor --rules)/global.readonly.instructions.md` exists |
| Skills installed | `$(resolve-editor --skills)` contains `git-workflow`, `new-skill`, `rule`, `setting`, `update-jumper-instructions` |
| Settings updated | `settings.json` contains `"github.copilot.chat.codeGeneration.useInstructionFiles": true` |
| Version stamp written | `~/.agents/.jumpskills-version` exists and contains today's date |
| Templates expanded | No `SKILL.md` files under `~/.agents/skills/` contain `{{SHELL_NAME}}` or `{{SHELL_EXT}}` |
| expand-templates installed | `~/.agents/scripts/expand-templates.ps1` and `expand-templates.sh` exist |

If any check fails, re-run the corresponding section of this setup prompt.