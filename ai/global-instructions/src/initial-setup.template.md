{{initial-setup-header.md}}

{{environment-setup.readonly.prompt.md}}

{{initial-setup-recreate.md}}

{{FILE_MANIFEST}}

### instructions/global.readonly.instructions.md
````markdown
{{GENERATED_GLOBAL}}
````

{{SKILL_SECTIONS}}

### <TEMP_DIR>/copilot-instructions/expand-templates.ps1
> Temporary helper — write, run, then delete. Do not install permanently.
````powershell
{{expand-templates.ps1}}
````

### <TEMP_DIR>/copilot-instructions/expand-templates.sh
> Temporary helper — write, run, then delete. Do not install permanently.
````sh
{{expand-templates.sh}}
````

{{COMMON_SCRIPTS}}

## Setup-only references (do not install)

### src/global.bootstrap.readonly.instructions.md
````markdown
{{global.bootstrap.readonly.instructions.md}}
````

{{initial-setup-footer.md}}