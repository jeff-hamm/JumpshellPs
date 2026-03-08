$ErrorActionPreference = "Stop"

function Read-Source {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing source file: $Path"
  }

  $raw = Get-Content -LiteralPath $Path -Raw
  return $raw.TrimEnd("`r", "`n")
}

function Normalize-Content {
  param([string]$Text)

  return ($Text -replace "`r`n", "`n").TrimEnd("`n")
}

function Expand-TemplateTokens {
  param(
    [string]$Content,
    [hashtable]$TemplateMap
  )

  $expanded = $Content
  foreach ($token in $TemplateMap.Keys) {
    $expanded = $expanded.Replace($token, $TemplateMap[$token])
  }

  return $expanded
}

function Expand-FileTokens {
  param(
    [string]$Content,
    [string]$SrcDir
  )

  # Match {{filename.ext}} — tokens containing a dot (filenames), not plain ALL_CAPS tokens
  $pattern = '\{\{([a-zA-Z0-9._-]+\.[a-zA-Z0-9]+)\}\}'
  $tokens = [regex]::Matches($Content, $pattern) |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

  foreach ($token in $tokens) {
    $filePath = Join-Path $SrcDir $token
    if (Test-Path -LiteralPath $filePath) {
      $fileContent = Read-Source -Path $filePath
      $Content = $Content.Replace("{{$token}}", $fileContent)
    }
  }

  return $Content
}

function Get-RelativePathNormalized {
  param(
    [string]$FullPath,
    [string]$BasePath
  )

  $relative = [System.IO.Path]::GetRelativePath($BasePath, $FullPath)
  return ($relative -replace "\\", "/")
}

function Unquote-Value {
  param([string]$Value)

  $trimmed = $Value.Trim()
  if (($trimmed.StartsWith("'") -and $trimmed.EndsWith("'")) -or ($trimmed.StartsWith('"') -and $trimmed.EndsWith('"'))) {
    return $trimmed.Substring(1, $trimmed.Length - 2)
  }

  return $trimmed
}

function Get-SkillMetadataFromContent {
  param([string]$Content)

  $name = $null
  $description = $null

  if ($Content -match "(?s)^---\s*\n(.*?)\n---\s*\n") {
    $frontmatter = $Matches[1]
    foreach ($line in ($frontmatter -split "`n")) {
      if (-not $name -and $line -match "^\s*name:\s*(.+?)\s*$") {
        $name = Unquote-Value -Value $Matches[1]
      }

      if (-not $description -and $line -match "^\s*description:\s*(.+?)\s*$") {
        $description = Unquote-Value -Value $Matches[1]
      }
    }
  }

  return [PSCustomObject]@{
    Name = $name
    Description = $description
  }
}

function Get-UserSkillSources {
  param([string]$WorkspaceRoot)

  $skillRoot = Join-Path $WorkspaceRoot "src/user-skills"
  if (-not (Test-Path -LiteralPath $skillRoot)) {
    return @()
  }

  $commonScriptsPath = (Join-Path $skillRoot "common/scripts") -replace "\\", "/"
  $files = Get-ChildItem -LiteralPath $skillRoot -Recurse -File |
    Where-Object { $_.Extension -match '^\.(md|ps1|sh)$' } |
    Where-Object { ($_.FullName -replace "\\", "/") -notlike "$commonScriptsPath/*" } |
    Sort-Object FullName

  $resolverPs1Path = Join-Path $skillRoot "common/scripts/resolve-editor.ps1"
  if (-not (Test-Path -LiteralPath $resolverPs1Path)) {
    $resolverPs1Path = Join-Path $skillRoot "common/resolve-editor.ps1"
  }

  $resolverShPath = Join-Path $skillRoot "common/scripts/resolve-editor.sh"
  if (-not (Test-Path -LiteralPath $resolverShPath)) {
    $resolverShPath = Join-Path $skillRoot "common/resolve-editor.sh"
  }

  $changeControlPs1Path = Join-Path $skillRoot "common/scripts/change-control.ps1"
  $changeControlShPath  = Join-Path $skillRoot "common/scripts/change-control.sh"
  $resolverPs1Content   = Read-Source -Path $resolverPs1Path
  $resolverShContent    = Read-Source -Path $resolverShPath
  $changeControlPs1Content = $null
  $changeControlShContent  = $null
  if (Test-Path -LiteralPath $changeControlPs1Path) {
    $changeControlPs1Content = Read-Source -Path $changeControlPs1Path
  }
  if (Test-Path -LiteralPath $changeControlShPath) {
    $changeControlShContent = Read-Source -Path $changeControlShPath
  }

  $result = @()
  $resolverTargetDirs = New-Object System.Collections.Generic.HashSet[string]
  $changeControlTargetDirs = New-Object System.Collections.Generic.HashSet[string]
  $scriptPathsNote = '> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.'

  foreach ($file in $files) {
    $relative = Get-RelativePathNormalized -FullPath $file.FullName -BasePath $skillRoot
    $rawContent = Read-Source -Path $file.FullName
    $isScriptFile = $file.Extension -match '^\.(ps1|sh)$'
    $content = $rawContent -replace '\{\{SCRIPT_PATHS_NOTE\}\}', $scriptPathsNote
    $metadata = if (-not $isScriptFile) { Get-SkillMetadataFromContent -Content $content } else { [PSCustomObject]@{ Name = $null; Description = $null } }

    $isSkill = (-not $isScriptFile) -and ($file.Name -ieq "SKILL.md") -and -not [string]::IsNullOrWhiteSpace($metadata.Name)
    $summary = if ($isSkill -and -not [string]::IsNullOrWhiteSpace($metadata.Description)) {
      $metadata.Description
    }
    elseif ($isSkill) {
      "User skill workflow."
    }
    elseif ($isScriptFile) {
      "Skill script file."
    }
    else {
      "Shared skill reference file."
    }

    if ($isSkill -and ($content -match "scripts/resolve-editor(\.(ps1|sh)|{{SHELL_EXT}})")) {
      $skillDir = (Split-Path -Path $relative -Parent) -replace "\\\\", "/"
      if (-not [string]::IsNullOrWhiteSpace($skillDir)) {
        [void]$resolverTargetDirs.Add($skillDir)
      }
    }

    if ($isSkill -and ($content -match "scripts/change-control(\.(ps1|sh)|{{SHELL_EXT}})")) {
      $skillDir = (Split-Path -Path $relative -Parent) -replace "\\", "/"
      if (-not [string]::IsNullOrWhiteSpace($skillDir)) {
        [void]$changeControlTargetDirs.Add($skillDir)
      }
    }

    $result += [PSCustomObject]@{
      SourcePath = $file.FullName
      RelativePath = $relative
      Section = ".agents/skills/$relative"
      Content = $content
      IsSkill = $isSkill
      SkillName = $metadata.Name
      Summary = $summary
    }
  }

  return [PSCustomObject]@{
    Sources                 = $result
    ResolverTargetDirs      = @($resolverTargetDirs | Sort-Object)
    ChangeControlTargetDirs = @($changeControlTargetDirs | Sort-Object)
    ResolverPs1Path         = $resolverPs1Path
    ResolverShPath          = $resolverShPath
    ChangeControlPs1Path    = $changeControlPs1Path
    ChangeControlShPath     = $changeControlShPath
    ResolverPs1Content      = $resolverPs1Content
    ResolverShContent       = $resolverShContent
    ChangeControlPs1Content = $changeControlPs1Content
    ChangeControlShContent  = $changeControlShContent
  }
}

function Build-FileManifest {
  param(
    [array]$SkillSources,
    [bool]$HasResolver,
    [bool]$HasChangeControl
  )

  $lines = @()
  $lines += "<!-- setup-manifest: machine-readable file index — scan this first to plan your work -->"
  $lines += '```yaml'
  $lines += "schema: jumpshell/manifest/v1"
  $lines += "files:"
  $lines += "  # scope: profile — base path: `$(pwsh resolve-editor.ps1 --profile) | `$(bash resolve-editor.sh --profile)"
  $lines += "  - path: instructions/global.readonly.instructions.md"

  $userSources = @($SkillSources | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Section) })
  if ($userSources.Count -gt 0) {
    $lines += "  # scope: user — base path: ~/ (e.g. .agents/skills/... installs to ~/.agents/skills/...)"
    foreach ($src in $userSources) {
      $lines += "  - path: $($src.Section)"
    }
  }

  $lines += "  # scope: temp — expand-templates helpers are written to <TEMP_DIR>/jumpshell/ and deleted after use"

  if ($HasResolver -or $HasChangeControl) {
    $lines += "  # scope: common — install at each referencing skill's scripts/ dir (see 'Common scripts' section)"
    if ($HasResolver) {
      $lines += "  - path: common/scripts/resolve-editor.ps1"
      $lines += "  - path: common/scripts/resolve-editor.sh"
    }
    if ($HasChangeControl) {
      $lines += "  - path: common/scripts/change-control.ps1"
      $lines += "  - path: common/scripts/change-control.sh"
    }
  }

  $lines += '```'
  $lines += ""
  return ($lines -join "`n")
}

function Build-CommonScriptsSection {
  param($SkillModel)

  $hasResolver      = $SkillModel.ResolverTargetDirs.Count -gt 0
  $hasChangeControl = $SkillModel.ChangeControlTargetDirs.Count -gt 0

  if (-not $hasResolver -and -not $hasChangeControl) { return "" }

  if ($hasChangeControl) {
    if ([string]::IsNullOrWhiteSpace($SkillModel.ChangeControlPs1Content)) {
      throw "Skills reference scripts/change-control but source is missing: $($SkillModel.ChangeControlPs1Path)"
    }
    if ([string]::IsNullOrWhiteSpace($SkillModel.ChangeControlShContent)) {
      throw "Skills reference scripts/change-control but source is missing: $($SkillModel.ChangeControlShPath)"
    }
  }

  $lines = @()
  $lines += "## Common scripts"
  $lines += ""
  $lines += "The following scripts are shared across multiple skills. Create each file at the path listed, using the content in the section below."
  $lines += ""

  if ($hasResolver) {
    $lines += "**resolve-editor** — install at:"
    foreach ($dir in $SkillModel.ResolverTargetDirs) {
      $lines += "- ``.agents/skills/$dir/scripts/resolve-editor.ps1``"
      $lines += "- ``.agents/skills/$dir/scripts/resolve-editor.sh``"
    }
    $lines += ""
  }

  if ($hasChangeControl) {
    $lines += "**change-control** — install at:"
    foreach ($dir in $SkillModel.ChangeControlTargetDirs) {
      $lines += "- ``.agents/skills/$dir/scripts/change-control.ps1``"
      $lines += "- ``.agents/skills/$dir/scripts/change-control.sh``"
    }
    $lines += ""
  }

  if ($hasResolver) {
    $lines += "### common/scripts/resolve-editor.ps1"
    $lines += "<!-- copy to all paths listed under 'resolve-editor' in the Common scripts section above -->"
    $lines += '````markdown'
    $lines += $SkillModel.ResolverPs1Content
    $lines += '````'
    $lines += ""
    $lines += "### common/scripts/resolve-editor.sh"
    $lines += "<!-- copy to all paths listed under 'resolve-editor' in the Common scripts section above -->"
    $lines += '````markdown'
    $lines += $SkillModel.ResolverShContent
    $lines += '````'
    $lines += ""
  }

  if ($hasChangeControl) {
    $lines += "### common/scripts/change-control.ps1"
    $lines += "<!-- copy to all paths listed under 'change-control' in the Common scripts section above -->"
    $lines += '````markdown'
    $lines += $SkillModel.ChangeControlPs1Content
    $lines += '````'
    $lines += ""
    $lines += "### common/scripts/change-control.sh"
    $lines += "<!-- copy to all paths listed under 'change-control' in the Common scripts section above -->"
    $lines += '````markdown'
    $lines += $SkillModel.ChangeControlShContent
    $lines += '````'
    $lines += ""
  }

  return ($lines -join "`n") + "`n"
}

function Build-DynamicGlobalInstructions {
  param(
    [string]$WorkspaceRoot,
    [array]$SkillSources
  )

  $templatePath = Join-Path $WorkspaceRoot "src/global.readonly.instructions.template.md"
  $template = Read-Source -Path $templatePath

  $skillItems = @($SkillSources | Where-Object { $_.IsSkill })
  $skillItemsText = if ($skillItems.Count -eq 0) {
    '- None detected in `src/user-skills/`.'
  }
  else {
    (@($skillItems | ForEach-Object { '- `/{0}`: {1}' -f $_.SkillName, $_.Summary }) -join "`n")
  }

  if (-not $template.Contains('{{GENERATED_SKILL_ITEMS}}')) {
    throw "Missing template placeholder '{{GENERATED_SKILL_ITEMS}}' in $templatePath"
  }

  $rendered = $template.Replace('{{GENERATED_SKILL_ITEMS}}', $skillItemsText)

  return $rendered
}

function Write-TemporaryGlobalInstructions {
  param([string]$Content)

  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "jumpshell"
  if (-not (Test-Path -LiteralPath $tempRoot)) {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
  }

  $filename = "global.readonly.instructions.generated.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss')).$([guid]::NewGuid().ToString('N')).md"
  $tempPath = Join-Path $tempRoot $filename
  Set-Content -LiteralPath $tempPath -Value $Content -Encoding utf8

  return $tempPath
}

function Resolve-OriginRawUrl {
  param(
    [string]$WorkspaceRoot,
    [string]$CanonicalRelativePath
  )

  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($null -eq $git) {
    throw "git is required to generate dist/new-install.readonly.prompt.md"
  }

  $originUrl = (& git -C $WorkspaceRoot remote get-url origin 2>$null)
  $originUrl = if ($null -eq $originUrl) { "" } else { $originUrl.Trim() }
  if ([string]::IsNullOrWhiteSpace($originUrl)) {
    throw "Unable to resolve git remote 'origin' for $WorkspaceRoot"
  }

  $originHeadRef = (& git -C $WorkspaceRoot symbolic-ref refs/remotes/origin/HEAD 2>$null)
  $originHeadRef = if ($null -eq $originHeadRef) { "" } else { $originHeadRef.Trim() }

  $branch = "main"
  if ($originHeadRef -match "^refs/remotes/origin/(.+)$") {
    $branch = $Matches[1]
  }

  $owner = $null
  $repo = $null

  if ($originUrl -match "^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$") {
    $owner = $Matches['owner']
    $repo = $Matches['repo']
  }
  elseif ($originUrl -match "^git@github\.com:(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
    $owner = $Matches['owner']
    $repo = $Matches['repo']
  }
  elseif ($originUrl -match "^ssh://git@github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$") {
    $owner = $Matches['owner']
    $repo = $Matches['repo']
  }
  else {
    throw "Unsupported origin URL for raw GitHub generation: $originUrl"
  }

  $canonical = ($CanonicalRelativePath -replace "\\", "/").TrimStart('/')
  $repoRoot = (& git -C $WorkspaceRoot rev-parse --show-toplevel 2>$null)
  $repoRoot = if ($null -eq $repoRoot) { "" } else { $repoRoot.Trim() }
  if (-not [string]::IsNullOrWhiteSpace($repoRoot)) {
    $workspaceRelative = Get-RelativePathNormalized -FullPath $WorkspaceRoot -BasePath $repoRoot
    if (-not [string]::IsNullOrWhiteSpace($workspaceRelative) -and $workspaceRelative -ne ".") {
      $canonical = "$workspaceRelative/$canonical"
    }
  }
  $rawUrl = "https://raw.githubusercontent.com/$owner/$repo/$branch/$canonical"

  return [PSCustomObject]@{
    OriginUrl = $originUrl
    Branch = $branch
    RawUrl = $rawUrl
    CanonicalRelativePath = $canonical
  }
}

function Build-NewInstallPromptContent {
  param(
    [string]$WorkspaceRoot,
    [string]$CanonicalRelativePath = "dist/initial-setup.readonly.prompt.md"
  )

  $origin = Resolve-OriginRawUrl -WorkspaceRoot $WorkspaceRoot -CanonicalRelativePath $CanonicalRelativePath
  $templatePath = Join-Path $WorkspaceRoot "src/new-install.template.md"
  $template = Read-Source -Path $templatePath
  return $template.Replace('{{RAW_URL}}', $origin.RawUrl)
}

function Build-InitialSetupContent {
  param(
    [string]$WorkspaceRoot,
    [switch]$EmitTemporaryGlobalInstructions
  )

  $skillModel = Get-UserSkillSources -WorkspaceRoot $WorkspaceRoot
  $skillSources = $skillModel.Sources

  $generatedGlobal = Build-DynamicGlobalInstructions -WorkspaceRoot $WorkspaceRoot -SkillSources $skillSources

  $temporaryGlobalPath = $null
  if ($EmitTemporaryGlobalInstructions.IsPresent) {
    $temporaryGlobalPath = Write-TemporaryGlobalInstructions -Content $generatedGlobal
  }

  # Build skill sections: each block separated by a blank line; result ends with
  # \n\n (blank line) when non-empty so ## Setup-only always has one blank line before it.
  $skillSectionsLines = @()
  foreach ($skill in $skillSources) {
    if ($skillSectionsLines.Count -gt 0) { $skillSectionsLines += "" }
    $skillSectionsLines += "### $($skill.Section)"
    $skillSectionsLines += '````markdown'
    $skillSectionsLines += $skill.Content
    $skillSectionsLines += '````'
  }
  $skillSectionsText = if ($skillSectionsLines.Count -gt 0) {
    ($skillSectionsLines -join "`n") + "`n`n"
  } else { "" }

  $srcDir = Join-Path $WorkspaceRoot "src"
  $setupTemplate = Read-Source -Path (Join-Path $srcDir "initial-setup.template.md")

  $hasResolver      = $skillModel.ResolverTargetDirs.Count -gt 0
  $hasChangeControl = $skillModel.ChangeControlTargetDirs.Count -gt 0
  $commonScriptsText = Build-CommonScriptsSection -SkillModel $skillModel
  $fileManifest      = Build-FileManifest -SkillSources $skillSources -HasResolver $hasResolver -HasChangeControl $hasChangeControl

  $content = Expand-FileTokens -Content $setupTemplate -SrcDir $srcDir
  $content = Expand-TemplateTokens -Content $content -TemplateMap @{
    '{{GENERATED_GLOBAL}}' = $generatedGlobal
    '{{SKILL_SECTIONS}}'   = $skillSectionsText
    '{{COMMON_SCRIPTS}}'   = $commonScriptsText
    '{{FILE_MANIFEST}}'    = $fileManifest
  }

  return [PSCustomObject]@{
    Content = $content
    SkillSources = $skillSources
    GeneratedGlobalInstructions = $generatedGlobal
    TemporaryGlobalInstructionsPath = $temporaryGlobalPath
  }
}

function Get-RawBaseUrl {
  param([string]$WorkspaceRoot)

  $result = Resolve-OriginRawUrl -WorkspaceRoot $WorkspaceRoot -CanonicalRelativePath "__BASE__"
  return $result.RawUrl -replace "/__BASE__$", ""
}

function Build-SlimInstallContent {
  param(
    [string]$WorkspaceRoot,
    [string]$GlobalInstructionsContent,
    [string]$BaseUrl = ""
  )

  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = Get-RawBaseUrl -WorkspaceRoot $WorkspaceRoot
  }

  $skillModel = Get-UserSkillSources -WorkspaceRoot $WorkspaceRoot
  $tableRows  = [System.Collections.Generic.List[string]]::new()

  # global instructions
  $tableRows.Add("| ``dist/global.readonly.instructions.md`` | ```$R/global.readonly.instructions.md`` |")

  # skill sources
  foreach ($src in $skillModel.Sources) {
    $rel = $src.RelativePath
    $tableRows.Add("| ``src/user-skills/$rel`` | ```$S/$rel`` |")
  }

  # common scripts — download each unique file once to $S/common/scripts/, list copy targets separately
  $hasResolver      = $skillModel.ResolverTargetDirs.Count -gt 0
  $hasChangeControl = $skillModel.ChangeControlTargetDirs.Count -gt 0
  $copyTargetDirs   = [System.Collections.Generic.HashSet[string]]::new()

  if ($hasResolver) {
    $tableRows.Add("| ``src/user-skills/common/scripts/resolve-editor.ps1`` | ```$S/common/scripts/resolve-editor.ps1`` |")
    $tableRows.Add("| ``src/user-skills/common/scripts/resolve-editor.sh`` | ```$S/common/scripts/resolve-editor.sh`` |")
    foreach ($dir in $skillModel.ResolverTargetDirs) { [void]$copyTargetDirs.Add($dir) }
  }

  if ($hasChangeControl) {
    $tableRows.Add("| ``src/user-skills/common/scripts/change-control.ps1`` | ```$S/common/scripts/change-control.ps1`` |")
    $tableRows.Add("| ``src/user-skills/common/scripts/change-control.sh`` | ```$S/common/scripts/change-control.sh`` |")
    foreach ($dir in $skillModel.ChangeControlTargetDirs) { [void]$copyTargetDirs.Add($dir) }
  }

  $copyNote = if ($copyTargetDirs.Count -gt 0) {
    ($copyTargetDirs | Sort-Object | ForEach-Object { "- ```$S/$_/scripts/``" }) -join "`n"
  } else { "" }

  $templatePath = Join-Path $WorkspaceRoot "src/initial-setup-slim.template.md"
  $template = Read-Source -Path $templatePath

  $content = Expand-TemplateTokens -Content $template -TemplateMap @{
    '{{SLIM_BASE_URL}}'   = $BaseUrl
    '{{SLIM_FILE_TABLE}}' = ($tableRows -join "`n")
    '{{SLIM_COPY_NOTE}}'  = $copyNote
  }

  return $content
}
