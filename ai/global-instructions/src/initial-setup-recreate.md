## Recreate instructions and user-profile skills

The **setup manifest** below lists every file to create before you read any content. Route each file by its scope:
- `scope: profile` — base path: `$(pwsh resolve-editor.ps1 --profile)` / `$(bash resolve-editor.sh --profile)`
- `scope: user` — base path: `~/` (home directory)
- `scope: common` — install at each target listed in the **Common scripts** section

Use each `### path/to/file` section heading as the relative filename; copy the fenced content verbatim.

**Immediately after writing all SKILL.md files**, expand shell template placeholders in one pass:
```powershell
# Windows
pwsh ~/.agents/scripts/expand-templates.ps1
```
```bash
# macOS/Linux
bash ~/.agents/scripts/expand-templates.sh
```
> **First-time setup only:** if `~/.agents/scripts/expand-templates.ps1` is not yet present (it is installed later in this file), replace `{{SHELL_NAME}}` with `pwsh`/`bash` and `{{SHELL_EXT}}` with `.ps1`/`.sh` in every SKILL.md you wrote.
