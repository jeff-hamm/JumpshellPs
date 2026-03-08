## Post-install: expand shell templates

After recreating all skill files above, replace the shell template placeholders in every installed `SKILL.md` file under `~/.agents/skills/` (recursively).

Detect the target operating system and substitute accordingly:

| Placeholder | Windows (PowerShell) | macOS / Linux (bash) |
|-------------|----------------------|----------------------|
| `{{SHELL_NAME}}` | `pwsh` | `bash` |
| `{{SHELL_EXT}}` | `.ps1` | `.sh` |

**Detection:** Use `$env:OS -eq 'Windows_NT'` (PowerShell) or `uname -s` (bash). If running on Windows, apply the PowerShell substitutions; otherwise apply the bash substitutions.

**Replacement scope:** Apply to all `SKILL.md` files under `~/.agents/skills/` that contain either placeholder token. Update them in-place.
