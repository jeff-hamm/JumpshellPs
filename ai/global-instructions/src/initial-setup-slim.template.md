# Initial Copilot Setup (Slim)

> Lightweight installer for resource-constrained agents. Downloads all files from GitHub instead of embedding them — no content scanning required.
> Run the block matching your OS in a terminal, then verify at the bottom.

```powershell
#!/usr/bin/env pwsh
# ── Windows / pwsh ────────────────────────────────────────────────────────────
$B = "{{SLIM_BASE_URL}}"
$T = "$env:TEMP\jumpshell"; New-Item -Force -ItemType Directory $T | Out-Null

# 1 — bootstrap resolve-editor
iwr "$B/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile "$T\resolve-editor.ps1"
$P   = & pwsh "$T\resolve-editor.ps1" --profile
$S   = & pwsh "$T\resolve-editor.ps1" --skills
$R   = & pwsh "$T\resolve-editor.ps1" --rules
$SET = & pwsh "$T\resolve-editor.ps1" --settings setting

# 2 — create directories
New-Item -Force -ItemType Directory $R | Out-Null
{{SLIM_MKDIRS_PS1}}

# 3 — download files
iwr "$B/dist/global.readonly.instructions.md" -OutFile "$R\global.readonly.instructions.md"
{{SLIM_DL_PS1}}

# 4 — common scripts
{{SLIM_COMMON_PS1}}

# 5 — expand shell templates
iwr "$B/src/expand-templates.ps1" -OutFile "$T\expand-templates.ps1"
& pwsh "$T\expand-templates.ps1"; Remove-Item "$T\expand-templates.ps1"

# 6 — settings
$j = Get-Content -Raw $SET | ConvertFrom-Json -AsHashtable
$j["github.copilot.chat.codeGeneration.useInstructionFiles"] = $true
$j | ConvertTo-Json -Depth 20 | Set-Content $SET
```

```bash
#!/usr/bin/env bash
# ── macOS / Linux / bash ──────────────────────────────────────────────────────
B="{{SLIM_BASE_URL}}"
T=/tmp/jumpshell; mkdir -p "$T"

# 1 — bootstrap resolve-editor
curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.sh" -o "$T/resolve-editor.sh"
P=$(bash "$T/resolve-editor.sh" --profile)
S=$(bash "$T/resolve-editor.sh" --skills)
R=$(bash "$T/resolve-editor.sh" --rules)
SET=$(bash "$T/resolve-editor.sh" --settings setting)

# 2 — create directories
mkdir -p "$R"
{{SLIM_MKDIRS_SH}}

# 3 — download files
curl -fsSL "$B/dist/global.readonly.instructions.md" -o "$R/global.readonly.instructions.md"
{{SLIM_DL_SH}}

# 4 — common scripts
{{SLIM_COMMON_SH}}

# 5 — expand shell templates
curl -fsSL "$B/src/expand-templates.sh" -o "$T/expand-templates.sh"
bash "$T/expand-templates.sh"; rm "$T/expand-templates.sh"

# 6 — settings
python3 -c "
import json; p='$SET'
with open(p) as f: j=json.load(f)
j['github.copilot.chat.codeGeneration.useInstructionFiles']=True
with open(p,'w') as f: json.dump(j,f,indent=2); f.write('\n')
"
```

## Verify

```powershell
& pwsh "$T\resolve-editor.ps1" --name
Test-Path "$R\global.readonly.instructions.md"
Get-ChildItem $S
```

```bash
bash "$T/resolve-editor.sh" --name
ls "$R/global.readonly.instructions.md"
ls "$S"
```
