# Initial Copilot Setup (Slim)

> Lightweight installer — downloads all files from GitHub. No embedded content.

## Step 1 — Bootstrap (run in terminal)

**Windows (pwsh)**
```powershell
$B="{{SLIM_BASE_URL}}"; $T="$env:TEMP\jumpshell"; New-Item -Force -ItemType Directory $T|Out-Null
iwr "$B/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile "$T\resolve-editor.ps1"
$P=& pwsh "$T\resolve-editor.ps1" --profile; $S=& pwsh "$T\resolve-editor.ps1" --skills
$R=& pwsh "$T\resolve-editor.ps1" --rules; $SET=& pwsh "$T\resolve-editor.ps1" --settings setting
```

**macOS/Linux (bash)**
```bash
B="{{SLIM_BASE_URL}}"; T=/tmp/jumpshell; mkdir -p "$T"
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
{{SLIM_FILE_TABLE}}

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
