# Initial Copilot Setup (Slim)

> Lightweight installer for resource-constrained agents. Downloads all files from GitHub instead of embedding them — no content scanning required.
> Run the block matching your OS in a terminal, then verify at the bottom.

```powershell
#!/usr/bin/env pwsh
# ── Windows / pwsh ────────────────────────────────────────────────────────────
$B = "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions"
$T = "$env:TEMP\jumpshell"; New-Item -Force -ItemType Directory $T | Out-Null

# 1 — bootstrap resolve-editor
iwr "$B/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile "$T\resolve-editor.ps1"
$P   = & pwsh "$T\resolve-editor.ps1" --profile
$S   = & pwsh "$T\resolve-editor.ps1" --skills
$R   = & pwsh "$T\resolve-editor.ps1" --rules
$SET = & pwsh "$T\resolve-editor.ps1" --settings setting

# 2 — create directories
New-Item -Force -ItemType Directory $R | Out-Null
New-Item -Force -ItemType Directory "$S\git-workflow\scripts" | Out-Null
New-Item -Force -ItemType Directory "$S\git-workflow" | Out-Null
New-Item -Force -ItemType Directory "$S\jumpdate" | Out-Null
New-Item -Force -ItemType Directory "$S\rule" | Out-Null
New-Item -Force -ItemType Directory "$S\setting\scripts" | Out-Null
New-Item -Force -ItemType Directory "$S\setting" | Out-Null
New-Item -Force -ItemType Directory "$S\skill\references" | Out-Null
New-Item -Force -ItemType Directory "$S\skill" | Out-Null

# 3 — download files
iwr "$B/dist/global.readonly.instructions.md" -OutFile "$R\global.readonly.instructions.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/scripts/git-workflow.ps1" -OutFile "$S\git-workflow\scripts\git-workflow.ps1"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/scripts/git-workflow.sh" -OutFile "$S\git-workflow\scripts\git-workflow.sh"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/SKILL.md" -OutFile "$S\git-workflow\SKILL.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/jumpdate/SKILL.md" -OutFile "$S\jumpdate\SKILL.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/rule/SKILL.md" -OutFile "$S\rule\SKILL.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/scripts/patch-json.ps1" -OutFile "$S\setting\scripts\patch-json.ps1"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/scripts/patch-json.sh" -OutFile "$S\setting\scripts\patch-json.sh"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/SKILL.md" -OutFile "$S\setting\SKILL.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/references/specification.md" -OutFile "$S\skill\references\specification.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/references/using-scripts.md" -OutFile "$S\skill\references\using-scripts.md"
iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/SKILL.md" -OutFile "$S\skill\SKILL.md"

# 4 — common scripts
foreach ($d in @("rule","setting","skill")) {
  New-Item -Force -ItemType Directory "$S\$d\scripts" | Out-Null
  iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile "$S\$d\scripts\resolve-editor.ps1"
  iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/resolve-editor.sh"  -OutFile "$S\$d\scripts\resolve-editor.sh"
}

foreach ($d in @("rule","setting","skill")) {
  New-Item -Force -ItemType Directory "$S\$d\scripts" | Out-Null
  iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/change-control.ps1" -OutFile "$S\$d\scripts\change-control.ps1"
  iwr "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/change-control.sh"  -OutFile "$S\$d\scripts\change-control.sh"
}

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
B="https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions"
T=/tmp/jumpshell; mkdir -p "$T"

# 1 — bootstrap resolve-editor
curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.sh" -o "$T/resolve-editor.sh"
P=$(bash "$T/resolve-editor.sh" --profile)
S=$(bash "$T/resolve-editor.sh" --skills)
R=$(bash "$T/resolve-editor.sh" --rules)
SET=$(bash "$T/resolve-editor.sh" --settings setting)

# 2 — create directories
mkdir -p "$R"
mkdir -p "$S/git-workflow/scripts"
mkdir -p "$S/git-workflow"
mkdir -p "$S/jumpdate"
mkdir -p "$S/rule"
mkdir -p "$S/setting/scripts"
mkdir -p "$S/setting"
mkdir -p "$S/skill/references"
mkdir -p "$S/skill"

# 3 — download files
curl -fsSL "$B/dist/global.readonly.instructions.md" -o "$R/global.readonly.instructions.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/scripts/git-workflow.ps1" -o "$S/git-workflow/scripts/git-workflow.ps1"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/scripts/git-workflow.sh" -o "$S/git-workflow/scripts/git-workflow.sh"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/git-workflow/SKILL.md" -o "$S/git-workflow/SKILL.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/jumpdate/SKILL.md" -o "$S/jumpdate/SKILL.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/rule/SKILL.md" -o "$S/rule/SKILL.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/scripts/patch-json.ps1" -o "$S/setting/scripts/patch-json.ps1"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/scripts/patch-json.sh" -o "$S/setting/scripts/patch-json.sh"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/setting/SKILL.md" -o "$S/setting/SKILL.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/references/specification.md" -o "$S/skill/references/specification.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/references/using-scripts.md" -o "$S/skill/references/using-scripts.md"
curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/skill/SKILL.md" -o "$S/skill/SKILL.md"

# 4 — common scripts
for d in "rule" "setting" "skill"; do
  mkdir -p "$S/$d/scripts"
  curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/resolve-editor.ps1" -o "$S/$d/scripts/resolve-editor.ps1"
  curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/resolve-editor.sh"  -o "$S/$d/scripts/resolve-editor.sh"
done

for d in "rule" "setting" "skill"; do
  mkdir -p "$S/$d/scripts"
  curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/change-control.ps1" -o "$S/$d/scripts/change-control.ps1"
  curl -fsSL "https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions/src/user-skills/common/scripts/change-control.sh"  -o "$S/$d/scripts/change-control.sh"
done

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
