# Initial Copilot Setup (Slim)

> Lightweight installer — downloads all files from GitHub. No embedded content.

## Step 1 — Bootstrap (run in terminal)

**Windows (pwsh)**
```powershell
$B="https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions"; $T="$env:TEMP\jumpshell"; New-Item -Force -ItemType Directory $T|Out-Null
iwr "$B/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile "$T\resolve-editor.ps1"
$P=& pwsh "$T\resolve-editor.ps1" --profile; $S=& pwsh "$T\resolve-editor.ps1" --skills
$R=& pwsh "$T\resolve-editor.ps1" --rules; $SET=& pwsh "$T\resolve-editor.ps1" --settings setting
```

**macOS/Linux (bash)**
```bash
B="https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/main/ai/global-instructions"; T=/tmp/jumpshell; mkdir -p "$T"
curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.sh" -o "$T/resolve-editor.sh"
P=$(bash "$T/resolve-editor.sh" --profile); S=$(bash "$T/resolve-editor.sh" --skills)
R=$(bash "$T/resolve-editor.sh" --rules); SET=$(bash "$T/resolve-editor.sh" --settings setting)
```

## Step 2 — Download files

Create parent directories as needed. Download each file — append source to `$B`:
- **pwsh:** `iwr "$B/<source>" -OutFile "<dest>"`
- **bash:** `curl -fsSL "$B/<source>" -o "<dest>"`

| Source | Destination |
|--------|-------------|
| `dist/global.readonly.instructions.md` | `$R/global.readonly.instructions.md` |
| `src/user-skills/git-workflow/scripts/git-workflow.ps1` | `$S/git-workflow/scripts/git-workflow.ps1` |
| `src/user-skills/git-workflow/scripts/git-workflow.sh` | `$S/git-workflow/scripts/git-workflow.sh` |
| `src/user-skills/git-workflow/SKILL.md` | `$S/git-workflow/SKILL.md` |
| `src/user-skills/jumpdate/SKILL.md` | `$S/jumpdate/SKILL.md` |
| `src/user-skills/rule/SKILL.md` | `$S/rule/SKILL.md` |
| `src/user-skills/setting/scripts/patch-json.ps1` | `$S/setting/scripts/patch-json.ps1` |
| `src/user-skills/setting/scripts/patch-json.sh` | `$S/setting/scripts/patch-json.sh` |
| `src/user-skills/setting/SKILL.md` | `$S/setting/SKILL.md` |
| `src/user-skills/skill/references/specification.md` | `$S/skill/references/specification.md` |
| `src/user-skills/skill/references/using-scripts.md` | `$S/skill/references/using-scripts.md` |
| `src/user-skills/skill/SKILL.md` | `$S/skill/SKILL.md` |
| `src/user-skills/common/scripts/resolve-editor.ps1` | `$S/rule/scripts/resolve-editor.ps1` |
| `src/user-skills/common/scripts/resolve-editor.sh` | `$S/rule/scripts/resolve-editor.sh` |
| `src/user-skills/common/scripts/resolve-editor.ps1` | `$S/setting/scripts/resolve-editor.ps1` |
| `src/user-skills/common/scripts/resolve-editor.sh` | `$S/setting/scripts/resolve-editor.sh` |
| `src/user-skills/common/scripts/resolve-editor.ps1` | `$S/skill/scripts/resolve-editor.ps1` |
| `src/user-skills/common/scripts/resolve-editor.sh` | `$S/skill/scripts/resolve-editor.sh` |
| `src/user-skills/common/scripts/change-control.ps1` | `$S/rule/scripts/change-control.ps1` |
| `src/user-skills/common/scripts/change-control.sh` | `$S/rule/scripts/change-control.sh` |
| `src/user-skills/common/scripts/change-control.ps1` | `$S/setting/scripts/change-control.ps1` |
| `src/user-skills/common/scripts/change-control.sh` | `$S/setting/scripts/change-control.sh` |
| `src/user-skills/common/scripts/change-control.ps1` | `$S/skill/scripts/change-control.ps1` |
| `src/user-skills/common/scripts/change-control.sh` | `$S/skill/scripts/change-control.sh` |

## Step 3 — Finish (run in terminal)

**Windows (pwsh)**
```powershell
iwr "$B/src/expand-templates.ps1" -OutFile "$T\expand-templates.ps1"
& pwsh "$T\expand-templates.ps1"; Remove-Item "$T\expand-templates.ps1"
$j=Get-Content -Raw $SET|ConvertFrom-Json -AsHashtable
$j["github.copilot.chat.codeGeneration.useInstructionFiles"]=$true
$j|ConvertTo-Json -Depth 20|Set-Content $SET
```

**macOS/Linux (bash)**
```bash
curl -fsSL "$B/src/expand-templates.sh" -o "$T/expand-templates.sh"
bash "$T/expand-templates.sh"; rm "$T/expand-templates.sh"
python3 -c "import json; p='$SET'; d=json.load(open(p)); d['github.copilot.chat.codeGeneration.useInstructionFiles']=True; json.dump(d,open(p,'w'),indent=2)"
```

## Verify

```powershell
& pwsh "$T\resolve-editor.ps1" --name; Test-Path "$R\global.readonly.instructions.md"; Get-ChildItem $S
```
```bash
bash "$T/resolve-editor.sh" --name && ls "$R/global.readonly.instructions.md" && ls "$S"
```
