#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$B = "https://raw.githubusercontent.com/jeff-hamm/jumpshell/main/ai/global-instructions"
$T = Join-Path $env:TEMP 'jumpshell'
New-Item -Path $T -ItemType Directory -Force | Out-Null

$resolve = Join-Path $T 'resolve-editor.ps1'
Invoke-WebRequest -Uri "$B/src/user-skills/common/scripts/resolve-editor.ps1" -OutFile $resolve -ErrorAction Stop

$P = (& $resolve --profile).ToString().Trim()
$S = (& $resolve --skills).ToString().Trim()
$R = (& $resolve --rules).ToString().Trim()
$SET = (& $resolve --settings setting).ToString().Trim()

$paths = @(
    $R,
    (Join-Path $S 'git-workflow\scripts'),
    (Join-Path $S 'git-workflow'),
    (Join-Path $S 'jumpdate'),
    (Join-Path $S 'rule'),
    (Join-Path $S 'setting\scripts'),
    (Join-Path $S 'setting'),
    (Join-Path $S 'skill\references'),
    (Join-Path $S 'skill')
)
foreach ($p in $paths) { if (-not [string]::IsNullOrWhiteSpace($p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null } }

$files = @(
    @{Url="$B/dist/global.readonly.instructions.md"; Out=Join-Path $R 'global.readonly.instructions.md'},
    @{Url="$B/src/user-skills/git-workflow/scripts/git-workflow.ps1"; Out=Join-Path $S 'git-workflow\scripts\git-workflow.ps1'},
    @{Url="$B/src/user-skills/git-workflow/scripts/git-workflow.sh"; Out=Join-Path $S 'git-workflow\scripts\git-workflow.sh'},
    @{Url="$B/src/user-skills/git-workflow/SKILL.md"; Out=Join-Path $S 'git-workflow\SKILL.md'},
    @{Url="$B/src/user-skills/jumpdate/SKILL.md"; Out=Join-Path $S 'jumpdate\SKILL.md'},
    @{Url="$B/src/user-skills/rule/SKILL.md"; Out=Join-Path $S 'rule\SKILL.md'},
    @{Url="$B/src/user-skills/setting/scripts/patch-json.ps1"; Out=Join-Path $S 'setting\scripts\patch-json.ps1'},
    @{Url="$B/src/user-skills/setting/scripts/patch-json.sh"; Out=Join-Path $S 'setting\scripts\patch-json.sh'},
    @{Url="$B/src/user-skills/setting/SKILL.md"; Out=Join-Path $S 'setting\SKILL.md'},
    @{Url="$B/src/user-skills/skill/references/specification.md"; Out=Join-Path $S 'skill\references\specification.md'},
    @{Url="$B/src/user-skills/skill/references/using-scripts.md"; Out=Join-Path $S 'skill\references\using-scripts.md'},
    @{Url="$B/src/user-skills/skill/SKILL.md"; Out=Join-Path $S 'skill\SKILL.md'}
)
foreach ($f in $files) {
  $outdir = Split-Path $f.Out -Parent
  New-Item -Path $outdir -ItemType Directory -Force | Out-Null
  try { Invoke-WebRequest -Uri $f.Url -OutFile $f.Out -ErrorAction Stop } catch { Write-Warning "Download failed: $($f.Url)" }
}

$common = @('resolve-editor.ps1','resolve-editor.sh','change-control.ps1','change-control.sh')
foreach ($d in @('rule','setting','skill')) {
  $dir = Join-Path $S "$d\scripts"
  New-Item -Path $dir -ItemType Directory -Force | Out-Null
  foreach ($c in $common) {
    $url = "$B/src/user-skills/common/scripts/$c"
    $out = Join-Path $dir $c
    try { Invoke-WebRequest -Uri $url -OutFile $out -ErrorAction Stop } catch { Write-Warning "Download failed: $url" }
  }
}

$expand = Join-Path $T 'expand-templates.ps1'
Invoke-WebRequest -Uri "$B/src/expand-templates.ps1" -OutFile $expand -ErrorAction Stop
& $expand
Remove-Item $expand -Force

# update settings (works with typical VS Code settings.json structure)
$content = Get-Content -Raw -ErrorAction Stop $SET
try {
  $j = $content | ConvertFrom-Json -AsHashtable
} catch {
  $obj = $content | ConvertFrom-Json
  $j = @{}
  $obj.PSObject.Properties | ForEach-Object { $j[$_.Name] = $_.Value }
}
$j['github.copilot.chat.codeGeneration.useInstructionFiles'] = $true
$j | ConvertTo-Json -Depth 20 | Set-Content -Path $SET
Write-Host "Install complete. Settings updated: $SET"
