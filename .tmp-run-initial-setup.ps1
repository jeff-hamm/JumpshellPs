$ErrorActionPreference = 'Stop'

try {
  $promptPath = 'resources/initial-setup.readonly.prompt.md'
  if (-not (Test-Path -LiteralPath $promptPath)) { throw "Prompt file not found: $promptPath" }

  $resolver = 'ai/global-instructions/src/user-skills/common/scripts/resolve-editor.ps1'
  if (-not (Test-Path -LiteralPath $resolver)) { throw "Resolver script not found: $resolver" }

  $VSCODE_PROFILE = (& pwsh -NoProfile -File $resolver --profile).Trim()
  if ([string]::IsNullOrWhiteSpace($VSCODE_PROFILE)) { throw 'Failed to resolve VSCODE_PROFILE' }

  $AGENTS_SKILLS_HOME = Join-Path $HOME '.agents/skills'

  function Get-GitInfo {
    param([string]$Path)
    $result = [ordered]@{
      path = $Path
      inGit = $false
      gitRoot = $null
      dirty = $false
      status = @()
    }

    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]$result }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return [pscustomobject]$result }

    $root = (& git -C $Path rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) {
      $result.inGit = $true
      $result.gitRoot = $root.Trim()
      $status = (& git -C $result.gitRoot status --porcelain=v1 2>$null)
      if ($LASTEXITCODE -eq 0 -and $status) {
        $result.dirty = $true
        $result.status = @($status)
      }
    }

    return [pscustomobject]$result
  }

  $profileGit = Get-GitInfo -Path $VSCODE_PROFILE
  $skillsGit = Get-GitInfo -Path (Join-Path $HOME '.agents')

  if (($profileGit.inGit -and $profileGit.dirty) -or ($skillsGit.inGit -and $skillsGit.dirty)) {
    [ordered]@{
      status = 'blocked-dirty-git'
      VSCODE_PROFILE = $VSCODE_PROFILE
      AGENTS_SKILLS_HOME = $AGENTS_SKILLS_HOME
      profileGit = $profileGit
      skillsGit = $skillsGit
    } | ConvertTo-Json -Depth 8 -Compress
    exit 3
  }

  function Ensure-ParentDir {
    param([string]$FilePath)
    $parent = Split-Path -Parent $FilePath
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
  }

  function Backup-And-Write {
    param(
      [string]$FilePath,
      [string]$Content,
      [System.Collections.Generic.List[string]]$Updated,
      [System.Collections.Generic.List[string]]$Created
    )

    Ensure-ParentDir -FilePath $FilePath
    if (Test-Path -LiteralPath $FilePath) {
      Copy-Item -LiteralPath $FilePath -Destination ($FilePath + '.bak') -Force
      Set-Content -LiteralPath $FilePath -Value $Content -Encoding UTF8
      $Updated.Add($FilePath)
    }
    else {
      Set-Content -LiteralPath $FilePath -Value $Content -Encoding UTF8
      $Created.Add($FilePath)
    }
  }

  $lines = Get-Content -LiteralPath $promptPath
  $start = -1
  $end = -1

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($start -lt 0 -and $lines[$i] -eq '## Recreate instructions and user-profile skills') {
      $start = $i
    }
    if ($start -ge 0 -and $lines[$i] -eq '## Setup-only references') {
      $end = $i
      break
    }
  }

  if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
    throw 'Could not locate recreate block boundaries in prompt.'
  }

  $sections = [ordered]@{}
  $i = $start + 1

  while ($i -lt $end) {
    $line = $lines[$i]
    if ($line -match '^###\s+(.+)$') {
      $title = $Matches[1].Trim()
      $isFileHeading = ($title -like '*/*' -or $title -match '\.(md|ps1|sh)$')
      if (-not $isFileHeading) {
        $i++
        continue
      }

      $j = $i + 1
      while ($j -lt $end -and [string]::IsNullOrWhiteSpace($lines[$j])) { $j++ }
      if ($j -ge $end -or $lines[$j] -notmatch '^`{3,}') {
        $i++
        continue
      }

      $fence = $lines[$j]
      $k = $j + 1
      while ($k -lt $end -and $lines[$k] -ne $fence) { $k++ }
      if ($k -ge $end) { throw "Unclosed fence for section: $title" }

      $content = if ($k -gt ($j + 1)) { ($lines[($j + 1)..($k - 1)] -join "`n") } else { '' }
      $sections[$title] = $content

      $i = $k + 1
      continue
    }

    $i++
  }

  $created = New-Object 'System.Collections.Generic.List[string]'
  $updated = New-Object 'System.Collections.Generic.List[string]'
  $skipped = New-Object 'System.Collections.Generic.List[string]'

  if (-not (Test-Path -LiteralPath $VSCODE_PROFILE)) {
    New-Item -ItemType Directory -Path $VSCODE_PROFILE -Force | Out-Null
  }
  if (-not (Test-Path -LiteralPath $AGENTS_SKILLS_HOME)) {
    New-Item -ItemType Directory -Path $AGENTS_SKILLS_HOME -Force | Out-Null
  }

  $profileNowGit = Get-GitInfo -Path $VSCODE_PROFILE
  if (-not $profileNowGit.inGit) {
    Push-Location $VSCODE_PROFILE
    try {
      & git init | Out-Null
      $gitignore = @(
        '*',
        '!.gitignore',
        '!instructions/',
        '!instructions/**',
        '!copilot-instructions.md',
        '!/*.json'
      ) -join "`n"
      Backup-And-Write -FilePath (Join-Path $VSCODE_PROFILE '.gitignore') -Content $gitignore -Updated $updated -Created $created
    }
    finally {
      Pop-Location
    }
  }

  foreach ($entry in $sections.GetEnumerator()) {
    $title = [string]$entry.Key
    $content = [string]$entry.Value

    if ($title -like 'common/scripts/*') { continue }

    $target = $null
    if ($title -like 'prompts/*' -or $title -like 'instructions/*') {
      $target = Join-Path $VSCODE_PROFILE ($title -replace '/', '\\')
    }
    elseif ($title -like '.agents/*') {
      $relative = $title.TrimStart('.') -replace '^[/\\]+', ''
      $target = Join-Path $HOME ($relative -replace '/', '\\')
    }
    else {
      $skipped.Add($title)
      continue
    }

    Backup-And-Write -FilePath $target -Content $content -Updated $updated -Created $created
  }

  $resolvePs1 = $sections['common/scripts/resolve-editor.ps1']
  $resolveSh = $sections['common/scripts/resolve-editor.sh']
  $changePs1 = $sections['common/scripts/change-control.ps1']
  $changeSh = $sections['common/scripts/change-control.sh']

  if ($null -eq $resolvePs1 -or $null -eq $resolveSh -or $null -eq $changePs1 -or $null -eq $changeSh) {
    throw 'Missing one or more common/scripts sections in prompt file.'
  }

  $skillNames = @('git-workflow', 'new-skill', 'rule', 'setting', 'update-jumper-instructions')
  foreach ($name in $skillNames) {
    $dir = Join-Path $AGENTS_SKILLS_HOME $name
    Backup-And-Write -FilePath (Join-Path $dir 'scripts/resolve-editor.ps1') -Content $resolvePs1 -Updated $updated -Created $created
    Backup-And-Write -FilePath (Join-Path $dir 'scripts/resolve-editor.sh') -Content $resolveSh -Updated $updated -Created $created
  }

  foreach ($name in @('new-skill', 'rule', 'setting')) {
    $dir = Join-Path $AGENTS_SKILLS_HOME $name
    Backup-And-Write -FilePath (Join-Path $dir 'scripts/change-control.ps1') -Content $changePs1 -Updated $updated -Created $created
    Backup-And-Write -FilePath (Join-Path $dir 'scripts/change-control.sh') -Content $changeSh -Updated $updated -Created $created
  }

  $settingsPath = Join-Path $VSCODE_PROFILE 'settings.json'
  $settingsObj = $null
  if (Test-Path -LiteralPath $settingsPath) {
    $raw = Get-Content -LiteralPath $settingsPath -Raw
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      try { $settingsObj = $raw | ConvertFrom-Json -Depth 100 }
      catch { $settingsObj = [pscustomobject]@{} }
    }
  }
  if ($null -eq $settingsObj) { $settingsObj = [pscustomobject]@{} }

  function Set-Prop {
    param([object]$Obj, [string]$Name, [object]$Value)
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) {
      $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
      $p.Value = $Value
    }
  }

  function Ensure-ArrayContains {
    param([object]$Obj, [string]$Name, [string]$Value)
    $existing = $Obj.PSObject.Properties[$Name]
    if ($null -eq $existing -or $null -eq $existing.Value) {
      Set-Prop -Obj $Obj -Name $Name -Value @($Value)
      return
    }

    $arr = @()
    if ($existing.Value -is [System.Array]) { $arr = @($existing.Value) }
    else { $arr = @([string]$existing.Value) }

    $contains = $false
    foreach ($item in $arr) {
      if ([string]$item -ieq $Value) {
        $contains = $true
        break
      }
    }

    if (-not $contains) {
      $arr += $Value
      Set-Prop -Obj $Obj -Name $Name -Value $arr
    }
  }

  Set-Prop -Obj $settingsObj -Name 'github.copilot.chat.codeGeneration.useInstructionFiles' -Value $true
  $instructionsPath = Join-Path $VSCODE_PROFILE 'instructions'
  Ensure-ArrayContains -Obj $settingsObj -Name 'github.copilot.chat.codeGeneration.instructions' -Value $instructionsPath
  Ensure-ArrayContains -Obj $settingsObj -Name 'chat.instructionsFilesLocations' -Value $instructionsPath

  $settingsJson = $settingsObj | ConvertTo-Json -Depth 100
  Backup-And-Write -FilePath $settingsPath -Content $settingsJson -Updated $updated -Created $created

  $shellName = if ($env:OS -eq 'Windows_NT') { 'pwsh' } else { 'bash' }
  $shellExt = if ($env:OS -eq 'Windows_NT') { '.ps1' } else { '.sh' }

  $expanded = New-Object 'System.Collections.Generic.List[string]'
  $skillFiles = Get-ChildItem -LiteralPath $AGENTS_SKILLS_HOME -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue
  foreach ($f in $skillFiles) {
    $text = Get-Content -LiteralPath $f.FullName -Raw
    if ($text -match '\{\{SHELL_NAME\}\}' -or $text -match '\{\{SHELL_EXT\}\}') {
      $newText = $text.Replace('{{SHELL_NAME}}', $shellName).Replace('{{SHELL_EXT}}', $shellExt)
      if ($newText -ne $text) {
        Backup-And-Write -FilePath $f.FullName -Content $newText -Updated $updated -Created $created
        $expanded.Add($f.FullName)
      }
    }
  }

  [ordered]@{
    status = 'ok'
    branch = 'main'
    promptPath = $promptPath
    VSCODE_PROFILE = $VSCODE_PROFILE
    AGENTS_SKILLS_HOME = $AGENTS_SKILLS_HOME
    profileGit = (Get-GitInfo -Path $VSCODE_PROFILE)
    skillsGit = (Get-GitInfo -Path (Join-Path $HOME '.agents'))
    filesCreated = @($created)
    filesUpdated = @($updated)
    sectionsSkipped = @($skipped)
    placeholderExpandedIn = @($expanded)
  } | ConvertTo-Json -Depth 8 -Compress
}
catch {
  [ordered]@{
    status = 'error'
    message = $_.Exception.Message
  } | ConvertTo-Json -Compress
  exit 1
}
