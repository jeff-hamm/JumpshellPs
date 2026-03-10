#!/usr/bin/env bash
set -euo pipefail
B="https://raw.githubusercontent.com/jeff-hamm/jumpshell/main/ai/global-instructions"
T="/tmp/jumpshell"
mkdir -p "$T"

curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.sh" -o "$T/resolve-editor.sh"
P=$(bash "$T/resolve-editor.sh" --profile)
S=$(bash "$T/resolve-editor.sh" --skills)
R=$(bash "$T/resolve-editor.sh" --rules)
SET=$(bash "$T/resolve-editor.sh" --settings setting)

mkdir -p "$R" "$S/git-workflow/scripts" "$S/jumpdate" "$S/rule" "$S/setting/scripts" "$S/setting" "$S/skill/references" "$S/skill"

curl -fsSL "$B/dist/global.readonly.instructions.md" -o "$R/global.readonly.instructions.md"
curl -fsSL "$B/src/user-skills/git-workflow/scripts/git-workflow.ps1" -o "$S/git-workflow/scripts/git-workflow.ps1"
curl -fsSL "$B/src/user-skills/git-workflow/scripts/git-workflow.sh" -o "$S/git-workflow/scripts/git-workflow.sh"
curl -fsSL "$B/src/user-skills/git-workflow/SKILL.md" -o "$S/git-workflow/SKILL.md"
curl -fsSL "$B/src/user-skills/jumpdate/SKILL.md" -o "$S/jumpdate/SKILL.md"
curl -fsSL "$B/src/user-skills/rule/SKILL.md" -o "$S/rule/SKILL.md"
curl -fsSL "$B/src/user-skills/setting/scripts/patch-json.ps1" -o "$S/setting/scripts/patch-json.ps1"
curl -fsSL "$B/src/user-skills/setting/scripts/patch-json.sh" -o "$S/setting/scripts/patch-json.sh"
curl -fsSL "$B/src/user-skills/setting/SKILL.md" -o "$S/setting/SKILL.md"
curl -fsSL "$B/src/user-skills/skill/references/specification.md" -o "$S/skill/references/specification.md"
curl -fsSL "$B/src/user-skills/skill/references/using-scripts.md" -o "$S/skill/references/using-scripts.md"
curl -fsSL "$B/src/user-skills/skill/SKILL.md" -o "$S/skill/SKILL.md"

for d in rule setting skill; do
  mkdir -p "$S/$d/scripts"
  curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.ps1" -o "$S/$d/scripts/resolve-editor.ps1"
  curl -fsSL "$B/src/user-skills/common/scripts/resolve-editor.sh" -o "$S/$d/scripts/resolve-editor.sh"
  curl -fsSL "$B/src/user-skills/common/scripts/change-control.ps1" -o "$S/$d/scripts/change-control.ps1"
  curl -fsSL "$B/src/user-skills/common/scripts/change-control.sh" -o "$S/$d/scripts/change-control.sh"
done

curl -fsSL "$B/src/expand-templates.sh" -o "$T/expand-templates.sh"
bash "$T/expand-templates.sh"
rm -f "$T/expand-templates.sh"

python3 -c "import json; p='$SET'; j=json.load(open(p)); j['github.copilot.chat.codeGeneration.useInstructionFiles']=True; open(p,'w').write(json.dumps(j,indent=2)+"\n")"
echo "Install complete. Settings updated: $SET"
