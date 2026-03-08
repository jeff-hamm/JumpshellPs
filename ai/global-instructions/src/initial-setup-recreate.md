## Recreate instructions and user-profile skills

The **setup manifest** below lists every file to create before you read any content. Route each file by its scope:
- `scope: profile` — base path: `$(pwsh resolve-editor.ps1 --profile)` / `$(bash resolve-editor.sh --profile)`
- `scope: user` — base path: `~/` (home directory)
- `scope: common` — install at each target listed in the **Common scripts** section

Use each `### path/to/file` section heading as the relative filename; copy the fenced content verbatim.

**Immediately after writing all SKILL.md files**, expand shell template placeholders in one pass.
The `expand-templates` scripts are written to `<TEMP_DIR>/copilot-instructions/` earlier in this file — run from there, then delete them.
```powershell
# Windows
pwsh "$env:TEMP/copilot-instructions/expand-templates.ps1"
Remove-Item "$env:TEMP/copilot-instructions/expand-templates.ps1"
```
```bash
# macOS/Linux
bash /tmp/copilot-instructions/expand-templates.sh
rm /tmp/copilot-instructions/expand-templates.sh
```
> If neither temp file is present, replace `{{SHELL_NAME}}` with `pwsh`/`bash` and `{{SHELL_EXT}}` with `.ps1`/`.sh` manually in every SKILL.md you wrote.
