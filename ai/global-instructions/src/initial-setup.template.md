{{initial-setup-header.md}}

{{environment-setup.readonly.prompt.md}}

{{initial-setup-recreate.md}}

{{FILE_MANIFEST}}

### instructions/global.readonly.instructions.md
````markdown
{{GENERATED_GLOBAL}}
````

{{SKILL_SECTIONS}}

### expand-templates.ps1
> **Temp only** — write to `$env:TEMP\jumpshell\expand-templates.ps1` (Windows), run via `pwsh`, then delete. Do not install permanently.
````markdown
{{expand-templates.ps1}}
````

### expand-templates.sh
> **Temp only** — write to `/tmp/jumpshell/expand-templates.sh` (macOS/Linux), run via `bash`, then delete. Do not install permanently.
````markdown
{{expand-templates.sh}}
````

{{COMMON_SCRIPTS}}

## Setup-only references (do not install)

### src/global.bootstrap.readonly.instructions.md
````markdown
{{global.bootstrap.readonly.instructions.md}}
````

{{initial-setup-footer.md}}