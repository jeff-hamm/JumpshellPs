## Recreate instructions and user-profile skills

> **Do NOT write a script to parse or extract sections from this file.** Install each file directly by reading its section content below and writing it to disk using your file-write tool (or a terminal here-string). Scripted extraction is unnecessary and error-prone.

The **setup manifest** below lists every file to create. Read each `### path/to/file` section, copy the content inside the outermost fenced block verbatim, and write it to the resolved path. Route each file by its scope:
- `scope: profile` — base path: `$(pwsh resolve-editor.ps1 --profile)` / `$(bash resolve-editor.sh --profile)`
- `scope: user` — base path: `~/` (home directory)
- `scope: common` — install at each target listed in the **Common scripts** section

**Mechanical steps for each file:**
1. Find the `### <path>` heading in this file.
2. Copy the content inside the ` ```` ` fenced block that immediately follows it (strip the fence lines themselves).
3. Write that content verbatim to the resolved destination path.
4. Move to the next file in the manifest.

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
