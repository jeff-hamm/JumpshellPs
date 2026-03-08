## Recreate instructions and user-profile skills

The **setup manifest** below lists every file to create before you read any content. Route each file by its scope:
- `scope: profile` — base path: `$(pwsh resolve-editor.ps1 --profile)` / `$(bash resolve-editor.sh --profile)`
- `scope: user` — base path: `~/` (home directory)
- `scope: common` — install at each target listed in the **Common scripts** section

Use each `### path/to/file` section heading as the relative filename; copy the fenced content verbatim.

**Immediately after writing all SKILL.md files**, expand shell template placeholders in one pass.
Locate the `### expand-templates.ps1` and `### expand-templates.sh` sections in this file, write their fenced content to the paths below, run, then delete:
```powershell
# Windows — write expand-templates.ps1 content to this path, then run:
pwsh "$env:TEMP\jumpshell\expand-templates.ps1"
Remove-Item "$env:TEMP\jumpshell\expand-templates.ps1"
```
```bash
# macOS/Linux — write expand-templates.sh content to this path, then run:
bash /tmp/jumpshell/expand-templates.sh
rm /tmp/jumpshell/expand-templates.sh
```
> If the expand-templates sections are not yet in scope, replace `{{SHELL_NAME}}` with `pwsh`/`bash` and `{{SHELL_EXT}}` with `.ps1`/`.sh` manually in every SKILL.md you wrote.
