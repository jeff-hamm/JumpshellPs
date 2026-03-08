# Initial Copilot Setup

Use this prompt when global instructions or skills are missing, or when preparing a fresh environment.

# *IMPORTANT: NEVER EDIT THIS FILE!*
# Global File Management
Use this file whenever you view, edit or remove my global settings, instructions, or skills.

## Preferred Skills
- Prefer user-profile skills under `~/.agents/skills/`.
- Route requests to these slash commands when applicable:
  - `/setting` for "global settings" or "my settings" (`settings.json`, `tasks.json`, `mcp.json`, `keybindings.json`)
  - `/rule` for "global rules" or "your instructions"
  - `/create-skill-global` for "global skills", "your skills", or "slash skills"
  - `/update-jumper-instructions` to update this module from `origin` by downloading `dist/initial-setup.readonly.prompt.md` from raw content and running it
- Use this file as a fallback only when those skills are missing.

## Paths
- I will refer to my editor profile path as `$VSCODE_PROFILE`. To find the location
  1. Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path.
  2. If the active profile path cannot be determined from settings/profiles metadata, use editor and channel fallback candidates:
    - powershell (Stable): `$Env:AppData\\Code\\User\\`
    - powershell (Insiders): `$Env:AppData\\Code - Insiders\\User\\`
    - powershell (Cursor): `$Env:AppData\\Cursor\\User\\`
    - cmd.exe (Stable): `%APPDATA%/Code/User/`
    - cmd.exe (Insiders): `%APPDATA%/Code - Insiders/User/`
    - cmd.exe (Cursor): `%APPDATA%/Cursor/User/`
    - macOS (Stable): `~/Library/Application Support/Code/User/`
    - macOS (Insiders): `~/Library/Application Support/Code - Insiders/User/`
    - macOS (Cursor): `~/Library/Application Support/Cursor/User/`
    - Linux (Stable): `$HOME/.config/Code/User/`
    - Linux (Insiders): `$HOME/.config/Code - Insiders/User/`
    - Linux (Cursor): `$HOME/.config/Cursor/User/`
  3. Once you have that path, make sure it is a git repository.
    - If `$VSCODE_PROFILE` is not a git repository, clone it from https://github.com/jeff-hamm/copilot-instructions, or, if that fails, initialize a new git repository there
      - If you create it, the .gitignore should be
        ```
        *
        !.gitignore
        !instructions/
        !instructions/**
        !copilot-instructions.md
        !/*.json
        ```
- I will refer to my user-profile skill path as `$AGENTS_SKILLS_HOME`
  - powershell (Windows): `$HOME\.agents\skills\`
  - cmd.exe (Windows): `%USERPROFILE%/.agents/skills/`
  - macOS: `$HOME/.agents/skills/`
  - Linux: `$HOME/.agents/skills/`
  - Prefer `.agents/` over `.copilot/` or `.github/` for user-level skills.
## Permissions
- You may view my editor configuration and any paths and files specified below
- If you can't access those files directly, use terminal commands to read those files, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in `$VSCODE_PROFILE` and `$AGENTS_SKILLS_HOME` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands to read those files, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly 
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      - Example:
        ```powershell
        @'
        <paste the markdown block verbatim>
        '@ | Set-Content -Path "$VSCODE_PROFILE\instructions\global.readonly.instructions.md" -Encoding UTF8
        ```        
## Backup
- Before making a change to any file in `$VSCODE_PROFILE` or `$AGENTS_SKILLS_HOME`
  - check to see if the target path is in a git repository and has uncommitted changes with `git status`. If so, prompt me to review and commit or stash them first. If I'd like to commit them, create a commit message summarizing the changes and commit them.
  - Create exactly one backup file per change at `<filename>.bak` before modifying any global file. If that file exists, replace its contents with the current pre-change contents of `<filename>`.
- After making changes:
  1. If the target path is in git, show the diff with `git diff <filename>` and summary with `git diff --stat <filename>`
  2. If the target path is not in git, show an equivalent before/after comparison
  3. Explain what changed and why
  4. Ask if I approve
    - if no, revert it by restoring `<filename>` from `<filename>.bak`
    - if yes and target path is in git
      1. Stage the changes with `git add <filename>`
      2. Commit with a descriptive message using `git commit -m "..."`
      3. Confirm the commit was successful

## Global Settings
- Files: `$VSCODE_PROFILE/settings.json`, `$VSCODE_PROFILE/tasks.json`, `$VSCODE_PROFILE/mcp.json`, `$VSCODE_PROFILE/keybindings.json`
- I may call these "my settings", "global settings", or "global files"
- Check for an existing setting before adding new values; edit or append as needed
- Validate the file to prevent duplicates before finishing

## Global Instructions
- Locations:
  - global: `$VSCODE_PROFILE/instructions`
  - profile: `$VSCODE_PROFILE/instructions/*.instructions.md`
- Files: `copilot-instructions.md` (all filetypes) or `<NAME>.instructions.md` (file-specific)
- I may call these "global rules", "your instructions", or "your rules"
- Keep wording short and precise. They can significantly reduce my performance if they are too long
- Review the result for clarity and duplication

## Global Skills
- Location (profile default): `$AGENTS_SKILLS_HOME`
- Files: `<SKILL_NAME>/SKILL.md` and optional `scripts/`, `references/`, `assets/`
- I may call these "global skills", "your skills", or "slash skills"
- Ensure `SKILL.md` uses valid frontmatter (`---`, `name`, `description`, optional `argument-hint`, `---`)
- Prefer multiple focused skills over one long procedural workflow
---
# *IMPORTANT: NEVER EDIT THIS FILE!*


## Environment preparation
- Install git if it is not already installed
- Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path.
- If `$VSCODE_PROFILE` is not a git repository, clone it from https://github.com/jeff-hamm/copilot-instructions, or, if that fails, initialize a new git repository there
  - If you create it, the .gitignore should be
    ```
    *
    !.gitignore
    !instructions/
    !instructions/**
    !copilot-instructions.md
    !/*.json
    ```
- Ensure the user-profile skill directory exists at `~/.agents/skills/`.
  - Prefer `.agents/` over `.copilot/` or `.github/` for user-level skills.

## Upgrade existing installs
- Detect whether this profile was initialized by that legacy setup flow:
  - One or more required user-skill files are missing:
    - `~/.agents/skills/setting/SKILL.md`
    - `~/.agents/skills/rule/SKILL.md`
    - `~/.agents/skills/create-skill-global/SKILL.md`
    - `~/.agents/skills/update-jumper-instructions/SKILL.md`
    - `~/.agents/skills/git-workflow/SKILL.md`
- If detected, run an in-place upgrade:
  - Keep existing git history and user-created files.
  - Replace only the files defined in this setup file with current contents.
  - Install or update user-profile skills under `~/.agents/skills/` from the embedded sections below.
  - Preserve user-created instructions, skills, and settings that are not explicitly listed in this setup file.
- If not detected, continue normal setup flow.

- If `$VSCODE_PROFILE/instructions/global.readonly.instructions.md` file is missing, create it and copy the full contents of `global.readonly.instructions.md` into it, preserving the `applyTo: "**"` header
- Update my settings as below. Use careful string manipulation that accounts for JSON escaping requirements. Read the existing JSON, parse it, modify the object, and write it back (using ConvertFrom-Json and ConvertTo-Json). If a setting key is unsupported in the current editor, skip it and report that in your summary.
  - Set my global `github.copilot.chat.codeGeneration.useInstructionFiles` setting to `true`
  - If it doesn't already exist, append `$VSCODE_PROFILE/instructions` to the global setting `github.copilot.chat.codeGeneration.instructions` and `chat.instructionsFilesLocations` lists

## Co-located Profile Resolver Scripts
- This setup installs per-platform scripts that resolve `$VSCODE_PROFILE`.
- Source these scripts from `src/user-skills/common/` and install generated copies next to each managed user-skill `SKILL.md` file:
  - `resolve-editor.ps1` for PowerShell environments
  - `resolve-editor.sh` for bash/zsh environments
- During skill execution, run the script that matches the current platform from that skill directory and use stdout as `$VSCODE_PROFILE`.
- The resolver scripts automatically prefer the active editor channel (VS Code Stable, VS Code Insiders, Cursor, or Claude) when that metadata is available.

## Recreate instructions and user-profile skills

Create or update these files under `$VSCODE_PROFILE` and `~/.agents/skills`, where each section title is the filename. Use the section's markdown as the file contents (copy verbatim).

> **After recreating all skill files**, expand the shell template placeholders — see the **Post-install** section at the end of this file.

### prompts/edit-global-files.readonly.prompt.md
````markdown
# *IMPORTANT: NEVER EDIT THIS FILE!*
# Global File Management
Use this file whenever you view, edit or remove my global settings, instructions, or skills.

## Preferred Skills
- Prefer user-profile skills under `~/.agents/skills/`.
- Route requests to these slash commands when applicable:
  - `/setting` for "global settings" or "my settings" (`settings.json`, `tasks.json`, `mcp.json`, `keybindings.json`)
  - `/rule` for "global rules" or "your instructions"
  - `/create-skill-global` for "global skills", "your skills", or "slash skills"
  - `/update-jumper-instructions` to update this module from `origin` by downloading `dist/initial-setup.readonly.prompt.md` from raw content and running it
- Use this file as a fallback only when those skills are missing.

## Paths
- I will refer to my editor profile path as `$VSCODE_PROFILE`. To find the location
  1. Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path.
  2. If the active profile path cannot be determined from settings/profiles metadata, use editor and channel fallback candidates:
    - powershell (Stable): `$Env:AppData\\Code\\User\\`
    - powershell (Insiders): `$Env:AppData\\Code - Insiders\\User\\`
    - powershell (Cursor): `$Env:AppData\\Cursor\\User\\`
    - cmd.exe (Stable): `%APPDATA%/Code/User/`
    - cmd.exe (Insiders): `%APPDATA%/Code - Insiders/User/`
    - cmd.exe (Cursor): `%APPDATA%/Cursor/User/`
    - macOS (Stable): `~/Library/Application Support/Code/User/`
    - macOS (Insiders): `~/Library/Application Support/Code - Insiders/User/`
    - macOS (Cursor): `~/Library/Application Support/Cursor/User/`
    - Linux (Stable): `$HOME/.config/Code/User/`
    - Linux (Insiders): `$HOME/.config/Code - Insiders/User/`
    - Linux (Cursor): `$HOME/.config/Cursor/User/`
  3. Once you have that path, make sure it is a git repository.
    - If `$VSCODE_PROFILE` is not a git repository, clone it from https://github.com/jeff-hamm/copilot-instructions, or, if that fails, initialize a new git repository there
      - If you create it, the .gitignore should be
        ```
        *
        !.gitignore
        !instructions/
        !instructions/**
        !copilot-instructions.md
        !/*.json
        ```
- I will refer to my user-profile skill path as `$AGENTS_SKILLS_HOME`
  - powershell (Windows): `$HOME\.agents\skills\`
  - cmd.exe (Windows): `%USERPROFILE%/.agents/skills/`
  - macOS: `$HOME/.agents/skills/`
  - Linux: `$HOME/.agents/skills/`
  - Prefer `.agents/` over `.copilot/` or `.github/` for user-level skills.
## Permissions
- You may view my editor configuration and any paths and files specified below
- If you can't access those files directly, use terminal commands to read those files, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in `$VSCODE_PROFILE` and `$AGENTS_SKILLS_HOME` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands to read those files, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly 
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      - Example:
        ```powershell
        @'
        <paste the markdown block verbatim>
        '@ | Set-Content -Path "$VSCODE_PROFILE\instructions\global.readonly.instructions.md" -Encoding UTF8
        ```        
## Backup
- Before making a change to any file in `$VSCODE_PROFILE` or `$AGENTS_SKILLS_HOME`
  - check to see if the target path is in a git repository and has uncommitted changes with `git status`. If so, prompt me to review and commit or stash them first. If I'd like to commit them, create a commit message summarizing the changes and commit them.
  - Create exactly one backup file per change at `<filename>.bak` before modifying any global file. If that file exists, replace its contents with the current pre-change contents of `<filename>`.
- After making changes:
  1. If the target path is in git, show the diff with `git diff <filename>` and summary with `git diff --stat <filename>`
  2. If the target path is not in git, show an equivalent before/after comparison
  3. Explain what changed and why
  4. Ask if I approve
    - if no, revert it by restoring `<filename>` from `<filename>.bak`
    - if yes and target path is in git
      1. Stage the changes with `git add <filename>`
      2. Commit with a descriptive message using `git commit -m "..."`
      3. Confirm the commit was successful

## Global Settings
- Files: `$VSCODE_PROFILE/settings.json`, `$VSCODE_PROFILE/tasks.json`, `$VSCODE_PROFILE/mcp.json`, `$VSCODE_PROFILE/keybindings.json`
- I may call these "my settings", "global settings", or "global files"
- Check for an existing setting before adding new values; edit or append as needed
- Validate the file to prevent duplicates before finishing

## Global Instructions
- Locations:
  - global: `$VSCODE_PROFILE/instructions`
  - profile: `$VSCODE_PROFILE/instructions/*.instructions.md`
- Files: `copilot-instructions.md` (all filetypes) or `<NAME>.instructions.md` (file-specific)
- I may call these "global rules", "your instructions", or "your rules"
- Keep wording short and precise. They can significantly reduce my performance if they are too long
- Review the result for clarity and duplication

## Global Skills
- Location (profile default): `$AGENTS_SKILLS_HOME`
- Files: `<SKILL_NAME>/SKILL.md` and optional `scripts/`, `references/`, `assets/`
- I may call these "global skills", "your skills", or "slash skills"
- Ensure `SKILL.md` uses valid frontmatter (`---`, `name`, `description`, optional `argument-hint`, `---`)
- Prefer multiple focused skills over one long procedural workflow
---
# *IMPORTANT: NEVER EDIT THIS FILE!*
````

### instructions/global.readonly.instructions.md
````markdown
---
applyTo: "**"
---
# NEVER EDIT THIS FILE

## Global Edit Routing
- Resolve `$VSCODE_PROFILE` for VS Code or Cursor using the active editor profile path. E.g:
  - Cursor macOS: `$HOME/Library/Application Support/Cursor/User/`
  - VS Code Windows Stable: `$Env:AppData\Code\User\`
  - and so on
- Resolve `$USER_PROFILE_SETTING` for VS Code or Cursor using the active editor's preferred user-scoped settings folder. E.g:
  - Cursor: ~/.cursor
  - vscode: ~/.agents

## Permissions
- You may view my editor configuration and any paths and files specified above
- If you can't access those files directly, use terminal commands to read those files, do not prompt for permission
- *NEVER* Edit or remove a file with a `.readonly.*.md` file extension. You may read them though.
- You may edit files in `$VSCODE_PROFILE` and `$USER_PROFILE_SETTING` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands to read those files, do not prompt for permission
    - If a file must be written from the terminal
      - Linux/macOS: wrap the block in `cat <<'EOF' > ...` so the shell copies it exactly
      - Powershell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      - Example:
        ```powershell
        @'
        <paste the markdown block verbatim>
        '@ | Set-Content -Path "$VSCODE_PROFILE\instructions\global.readonly.instructions.md" -Encoding UTF8
        ```

## Included User Skills (Generated)
- `/git-workflow`: Handle work on copilot branches with consistent branch checks, worktree usage for copilot commits, and high-quality commit messages that explain both what changed and why. Use when the user asks to use a separate branch or worktree or if they ask to keep your changes separate.
- `/skill`: Create, edit, or refactor skills for workspace/profile/global scope. Use for requests like "global skills", "user skills", "my skills", "your skills", "slash commands", "reusable workflows", "automation skill", "agent skill", "SKILL.md", "new skill", or "skill updates". Best for repeatable multi-step tasks and integrations.
- `/rule`: Create, edit, or refactor instruction/rules files for workspace or user. Use for requests like "global (rules|instructions)", "my (rules|instructions)", "your (rules|instructions)", "project (rules|instructions)", "workspace (rules|instructions)", "user (rules|instructions)", "coding standards", "guardrails", "policy".
- `/setting`: Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".
- `/update-jumper-instructions`: Bootstrap or refresh this instruction-and-skill pack by downloading and running dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "refresh global instructions", "reinstall bootstrap", "pull latest initial setup", or "run new install".

## Fallback
      - Before editing global files, read `$VSCODE_PROFILE/instructions/global.readonly.instructions.md`.
      - Run `initial-setup.readonly.prompt.md` when global instructions or skills are missing.
````

### .agents/skills/common/profile-resolution.md
````markdown
# Scope And Profile Resolution

Use this reference from user-profile skills to resolve target scope and paths without duplicating logic across VS Code, Cursor, and Claude.

## Resolve $VSCODE_PROFILE
1. Determine the active editor family and channel first (VS Code Stable, VS Code Insiders, Cursor, or Claude) from active app metadata, and keep that channel when resolving paths.
2. Resolve `$VSCODE_PROFILE` using the active editor profile path for that same family/channel.
3. If the active profile path cannot be determined from settings/profiles metadata, use editor and channel fallback candidates:
  - VS Code Windows Stable: `$Env:AppData\Code\User\`
  - VS Code Windows Insiders: `$Env:AppData\Code - Insiders\User\`
  - VS Code macOS Stable: `$HOME/Library/Application Support/Code/User/`
  - VS Code macOS Insiders: `$HOME/Library/Application Support/Code - Insiders/User/`
  - VS Code Linux Stable: `$HOME/.config/Code/User/`
  - VS Code Linux Insiders: `$HOME/.config/Code - Insiders/User/`
  - Cursor Windows: `$Env:AppData\Cursor\User\`
  - Cursor macOS: `$HOME/Library/Application Support/Cursor/User/`
  - Cursor Linux: `$HOME/.config/Cursor/User/`
  - Claude Windows: `$Env:AppData\Claude\User\`
  - Claude macOS: `$HOME/Library/Application Support/Claude/User/`
  - Claude Linux: `$HOME/.config/Claude/User/`
4. Treat this resolved path as `$VSCODE_PROFILE` for compatibility with existing instruction/skill conventions.

## Scope Modes
- `workspace`: current repository/workspace files.
- `profile`: VS Code or Cursor profile-level user customizations.
- `global`: managed global files under `$VSCODE_PROFILE` used by this setup.

## Path Mapping

### Settings And Config
- `global`:
  - `$VSCODE_PROFILE/settings.json`
  - `$VSCODE_PROFILE/tasks.json`
  - `$VSCODE_PROFILE/mcp.json`
  - `$VSCODE_PROFILE/keybindings.json`
- `workspace`:
  - `.vscode/settings.json`
  - `.vscode/tasks.json`
  - `.vscode/mcp.json` (if used)
  - `.vscode/keybindings.json` (if used)

### Instructions
- `global`, `profile` or `user`:
  - `$VSCODE_PROFILE/instructions/`
- `workspace`:
  - `.github/instructions/*.instructions.md`
  - or workspace-level `copilot-instructions.md` where applicable

### Skills
- `profile` (preferred default):
  - `~/.agents/skills/<name>/SKILL.md`
- `workspace`:
  - `.agents/skills/<name>/SKILL.md`
- Prefer `.agents/` over `.copilot/` or `.github/` for skills.

### Resolver Outputs
- `--user`:
  - VS Code: `~/.agents`
  - Cursor: `~/.cursor`
  - Claude: `~/.claude`
- `--rules`:
  - VS Code: `~/.agents/instructions`
  - Cursor: `~/.cursor/rules`
  - Claude: prefer `~/.claude/commands` (fallbacks: `~/.claude/rules`, `~/.claude`)
- `--workspace`:
  - VS Code: `<workspace-root>/.agents`
  - Cursor: `<workspace-root>/.cursor`
  - Claude: `<workspace-root>/.claude`

## Resolver Return Shape
- For path modes (`--profile`, `--user`, `--rules`, `--workspace`), resolver scripts return a JSON tuple array:
  - `["<EDITOR>", "<SCOPE_PATH>"]`
  - item 1: editor name
  - item 2: resolved path for the requested mode
- `--name` returns only the editor name string.

## Exported Variables
- Resolver scripts also export these variables in-process:
  - `$EDITOR`
  - `$SCOPE_PATH`

## Backup Rule
- Use exactly one `.bak` file per target file per change.
- If `<filename>.bak` already exists, replace its contents with the current pre-change contents of `<filename>`.
````

### .agents/skills/git-workflow/scripts/git-workflow.ps1
````markdown
#!/usr/bin/env pwsh
# git-workflow.ps1 — Manage copilot AI branches and worktrees
#
# Usage:
#   pwsh scripts/git-workflow.ps1 --action <action> [options]
#
# Actions:
#   check                          Check current branch state and derive AI branch name
#   create   [--branch <name>]     Create worktree for the AI branch
#   status   [--branch <name>]     Get pending changes on the AI branch worktree
#   merge    --source <branch> --target <branch> [--strategy merge|squash] [--keep-branch]
#   cleanup  [--branch <name>]     Remove worktree and delete branch
#
# Outputs: JSON to stdout, diagnostics to stderr
# Exit codes: 0 success, 1 usage error, 2 git error

param(
  [string]$action,
  [string]$branch,
  [string]$source,
  [string]$target,
  [string]$strategy = "merge",
  [switch]$keepBranch,
  [switch]$help
)

if ($help -or [string]::IsNullOrWhiteSpace($action)) {
  @"
Usage: pwsh scripts/git-workflow.ps1 --action <action> [options]

Actions:
  check                          Check current branch; derive AI branch name (<current>_ai)
  create   [--branch <name>]     Create worktree for the AI branch
  status   [--branch <name>]     List pending changes on the AI branch
  merge    --source <branch> --target <branch> [--strategy merge|squash] [--keepBranch]
  cleanup  [--branch <name>]     Remove worktree and delete AI branch

Exit codes: 0 success, 1 usage error, 2 git error
"@ | Write-Host
  exit 0
}

function Invoke-Git {
  param([string[]]$Args)
  $out = & git @Args 2>&1
  $ec = $LASTEXITCODE
  return [PSCustomObject]@{ Output = ($out -join "`n").Trim(); ExitCode = $ec }
}

function Out-Json {
  param([hashtable]$Data)
  $Data | ConvertTo-Json -Compress -Depth 5 | Write-Output
}

function Fail {
  param([string]$Msg, [int]$Code = 1)
  @{ error = $Msg } | ConvertTo-Json -Compress | Write-Output
  exit $Code
}

# Ensure we are inside a git repo
$repoCheck = Invoke-Git @("rev-parse", "--git-dir")
if ($repoCheck.ExitCode -ne 0) { Fail -Msg "Not a git repository" -Code 2 }

# Resolve current branch
$currentBranchResult = Invoke-Git @("rev-parse", "--abbrev-ref", "HEAD")
$currentBranch = $currentBranchResult.Output

# Derive AI branch name
$aiBranch = if (-not [string]::IsNullOrWhiteSpace($branch)) { $branch } else { "${currentBranch}_ai" }

switch ($action) {

  "check" {
    # Branch existence
    $branchList = Invoke-Git @("branch", "--list", $aiBranch)
    $branchExists = $branchList.Output.Trim().Length -gt 0

    # Worktree existence
    $worktreeList = Invoke-Git @("worktree", "list", "--porcelain")
    $worktreePath = $null
    $worktreeExists = $false
    if ($worktreeList.ExitCode -eq 0) {
      $lines = $worktreeList.Output -split "`n"
      $currentWt = $null
      foreach ($line in $lines) {
        if ($line -match "^worktree\s+(.+)") { $currentWt = $Matches[1].Trim() }
        if ($line -match "^branch\s+refs/heads/$([regex]::Escape($aiBranch))") {
          $worktreeExists = $true
          $worktreePath = $currentWt
        }
      }
    }

    # Pending changes on current branch
    $statusResult = Invoke-Git @("status", "--short")
    $pendingChanges = ($statusResult.Output.Trim() -split "`n" | Where-Object { $_ -ne "" })

    Out-Json @{
      currentBranch  = $currentBranch
      aiBranch       = $aiBranch
      branchExists   = $branchExists
      worktreeExists = $worktreeExists
      worktreePath   = $worktreePath
      pendingChanges = @($pendingChanges)
    }
  }

  "create" {
    # Ensure branch does not already have a worktree
    $worktreeList = Invoke-Git @("worktree", "list", "--porcelain")
    if ($worktreeList.Output -match "refs/heads/$([regex]::Escape($aiBranch))") {
      Fail -Msg "Worktree for branch '$aiBranch' already exists. Use --action status to inspect it."
    }

    # Create branch if needed
    $branchList = Invoke-Git @("branch", "--list", $aiBranch)
    $branchCreated = $false
    if ($branchList.Output.Trim().Length -eq 0) {
      $createBranch = Invoke-Git @("branch", $aiBranch)
      if ($createBranch.ExitCode -ne 0) { Fail -Msg "Failed to create branch: $($createBranch.Output)" -Code 2 }
      $branchCreated = $true
    }

    # Derive worktree path (sibling directory)
    $repoRootResult = Invoke-Git @("rev-parse", "--show-toplevel")
    $repoRoot = $repoRootResult.Output.Trim()
    $parentDir = Split-Path $repoRoot -Parent
    $repoName  = Split-Path $repoRoot -Leaf
    $worktreePath = Join-Path $parentDir "${repoName}_ai"

    $addWorktree = Invoke-Git @("worktree", "add", $worktreePath, $aiBranch)
    if ($addWorktree.ExitCode -ne 0) { Fail -Msg "Failed to create worktree: $($addWorktree.Output)" -Code 2 }

    Out-Json @{
      action        = "create"
      aiBranch      = $aiBranch
      branchCreated = $branchCreated
      worktreePath  = $worktreePath
    }
  }

  "status" {
    # Find the worktree path for the AI branch
    $worktreeList = Invoke-Git @("worktree", "list", "--porcelain")
    $worktreePath = $null
    $lines = $worktreeList.Output -split "`n"
    $currentWt = $null
    foreach ($line in $lines) {
      if ($line -match "^worktree\s+(.+)") { $currentWt = $Matches[1].Trim() }
      if ($line -match "^branch\s+refs/heads/$([regex]::Escape($aiBranch))") { $worktreePath = $currentWt }
    }

    if ($null -eq $worktreePath) {
      Fail -Msg "No worktree found for branch '$aiBranch'. Use --action create first."
    }

    $statusResult = & git -C $worktreePath status --short 2>&1
    $logResult    = & git -C $worktreePath log --oneline "$currentBranch..$aiBranch" 2>&1

    Out-Json @{
      aiBranch     = $aiBranch
      worktreePath = $worktreePath
      pendingChanges = @(($statusResult | Where-Object { $_ -ne "" }))
      commits      = @(($logResult   | Where-Object { $_ -ne "" }))
    }
  }

  "merge" {
    if ([string]::IsNullOrWhiteSpace($source)) { Fail -Msg "--source is required for merge action" }
    if ([string]::IsNullOrWhiteSpace($target)) { Fail -Msg "--target is required for merge action" }

    # Switch to target
    $checkout = Invoke-Git @("checkout", $target)
    if ($checkout.ExitCode -ne 0) { Fail -Msg "Failed to checkout '$target': $($checkout.Output)" -Code 2 }

    # Merge
    if ($strategy -eq "squash") {
      $merge = Invoke-Git @("merge", "--squash", $source)
    } else {
      $merge = Invoke-Git @("merge", "--no-ff", $source)
    }
    if ($merge.ExitCode -ne 0) { Fail -Msg "Merge failed: $($merge.Output)" -Code 2 }

    $cleanupDone = $false
    if (-not $keepBranch) {
      # Remove worktree if present
      $worktreeList = Invoke-Git @("worktree", "list", "--porcelain")
      if ($worktreeList.Output -match "refs/heads/$([regex]::Escape($source))") {
        Invoke-Git @("worktree", "remove", "--force", $source) | Out-Null
      }
      Invoke-Git @("branch", "-D", $source) | Out-Null
      $cleanupDone = $true
    }

    Out-Json @{
      action      = "merge"
      source      = $source
      target      = $target
      strategy    = $strategy
      keepBranch  = [bool]$keepBranch
      cleanupDone = $cleanupDone
      output      = $merge.Output
    }
  }

  "cleanup" {
    # Remove worktree
    $worktreeList = Invoke-Git @("worktree", "list", "--porcelain")
    $worktreeRemoved = $false
    if ($worktreeList.Output -match "refs/heads/$([regex]::Escape($aiBranch))") {
      $rm = Invoke-Git @("worktree", "remove", "--force", $aiBranch)
      $worktreeRemoved = ($rm.ExitCode -eq 0)
    }

    # Delete branch
    $delBranch = Invoke-Git @("branch", "-D", $aiBranch)
    $branchDeleted = ($delBranch.ExitCode -eq 0)

    Out-Json @{
      action         = "cleanup"
      aiBranch       = $aiBranch
      worktreeRemoved = $worktreeRemoved
      branchDeleted  = $branchDeleted
    }
  }

  default {
    Fail -Msg "Unknown action '$action'. Valid actions: check, create, status, merge, cleanup"
  }
}
````

### .agents/skills/git-workflow/scripts/git-workflow.sh
````markdown
#!/usr/bin/env bash
# git-workflow.sh — Manage copilot AI branches and worktrees
#
# Usage:
#   bash scripts/git-workflow.sh --action <action> [options]
#
# Actions:
#   check                          Check current branch state and derive AI branch name
#   create   [--branch <name>]     Create worktree for the AI branch
#   status   [--branch <name>]     Get pending changes on the AI branch worktree
#   merge    --source <branch> --target <branch> [--strategy merge|squash] [--keep-branch]
#   cleanup  [--branch <name>]     Remove worktree and delete branch
#
# Outputs: JSON to stdout, diagnostics to stderr
# Exit codes: 0 success, 1 usage error, 2 git error

set -euo pipefail

ACTION=""
BRANCH=""
SOURCE=""
TARGET=""
STRATEGY="merge"
KEEP_BRANCH=false

usage() {
  cat <<'EOF'
Usage: bash scripts/git-workflow.sh --action <action> [options]

Actions:
  check                          Check current branch; derive AI branch name (<current>_ai)
  create   [--branch <name>]     Create worktree for the AI branch
  status   [--branch <name>]     List pending changes on the AI branch
  merge    --source <branch> --target <branch> [--strategy merge|squash] [--keep-branch]
  cleanup  [--branch <name>]     Remove worktree and delete AI branch

Exit codes: 0 success, 1 usage error, 2 git error
EOF
}

fail() {
  local msg="$1"
  local code="${2:-1}"
  echo "{\"error\":$(json_str "$msg")}" >&1
  exit "$code"
}

json_str() {
  # Escape a string for JSON
  if command -v python3 &>/dev/null; then
    python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"
  else
    printf '"%s"' "$(echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g')"
  fi
}

json_array_of_lines() {
  # Convert newline-separated text into a JSON array of strings
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
print(json.dumps(lines))
"
  else
    echo "[]"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)       ACTION="$2"; shift 2 ;;
    --branch)       BRANCH="$2"; shift 2 ;;
    --source)       SOURCE="$2"; shift 2 ;;
    --target)       TARGET="$2"; shift 2 ;;
    --strategy)     STRATEGY="$2"; shift 2 ;;
    --keep-branch)  KEEP_BRANCH=true; shift ;;
    --help|-h)      usage; exit 0 ;;
    *) fail "Unknown argument: $1" 1 ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  usage
  exit 1
fi

# Ensure we are inside a git repo
if ! git rev-parse --git-dir &>/dev/null; then
  fail "Not a git repository" 2
fi

# Resolve current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Derive AI branch name
AI_BRANCH="${BRANCH:-${CURRENT_BRANCH}_ai}"

case "$ACTION" in

  check)
    BRANCH_EXISTS=false
    if [[ -n "$(git branch --list "$AI_BRANCH")" ]]; then
      BRANCH_EXISTS=true
    fi

    WORKTREE_EXISTS=false
    WORKTREE_PATH=""
    while IFS= read -r line; do
      if [[ "$line" == worktree\ * ]]; then
        CURRENT_WT="${line#worktree }"
      elif [[ "$line" == "branch refs/heads/$AI_BRANCH" ]]; then
        WORKTREE_EXISTS=true
        WORKTREE_PATH="$CURRENT_WT"
      fi
    done < <(git worktree list --porcelain)

    PENDING="$(git status --short)"

    python3 -c "
import json, sys
data = {
  'currentBranch':  sys.argv[1],
  'aiBranch':       sys.argv[2],
  'branchExists':   sys.argv[3] == 'true',
  'worktreeExists': sys.argv[4] == 'true',
  'worktreePath':   sys.argv[5] if sys.argv[5] else None,
  'pendingChanges': [l for l in sys.argv[6].splitlines() if l.strip()],
}
print(json.dumps(data))
" "$CURRENT_BRANCH" "$AI_BRANCH" "$BRANCH_EXISTS" "$WORKTREE_EXISTS" "$WORKTREE_PATH" "$PENDING"
    ;;

  create)
    # Check if worktree already exists
    if git worktree list --porcelain | grep -q "branch refs/heads/$AI_BRANCH"; then
      fail "Worktree for branch '$AI_BRANCH' already exists. Use --action status to inspect it."
    fi

    BRANCH_CREATED=false
    if [[ -z "$(git branch --list "$AI_BRANCH")" ]]; then
      git branch "$AI_BRANCH" || fail "Failed to create branch '$AI_BRANCH'" 2
      BRANCH_CREATED=true
    fi

    REPO_ROOT="$(git rev-parse --show-toplevel)"
    PARENT_DIR="$(dirname "$REPO_ROOT")"
    REPO_NAME="$(basename "$REPO_ROOT")"
    WORKTREE_PATH="${PARENT_DIR}/${REPO_NAME}_ai"

    git worktree add "$WORKTREE_PATH" "$AI_BRANCH" || fail "Failed to create worktree at '$WORKTREE_PATH'" 2

    python3 -c "
import json, sys
print(json.dumps({
  'action':        'create',
  'aiBranch':      sys.argv[1],
  'branchCreated': sys.argv[2] == 'true',
  'worktreePath':  sys.argv[3],
}))
" "$AI_BRANCH" "$BRANCH_CREATED" "$WORKTREE_PATH"
    ;;

  status)
    WORKTREE_PATH=""
    while IFS= read -r line; do
      if [[ "$line" == worktree\ * ]]; then
        CURRENT_WT="${line#worktree }"
      elif [[ "$line" == "branch refs/heads/$AI_BRANCH" ]]; then
        WORKTREE_PATH="$CURRENT_WT"
      fi
    done < <(git worktree list --porcelain)

    if [[ -z "$WORKTREE_PATH" ]]; then
      fail "No worktree found for branch '$AI_BRANCH'. Use --action create first."
    fi

    STATUS_OUT="$(git -C "$WORKTREE_PATH" status --short 2>/dev/null || true)"
    LOG_OUT="$(git -C "$WORKTREE_PATH" log --oneline "$CURRENT_BRANCH..$AI_BRANCH" 2>/dev/null || true)"

    python3 -c "
import json, sys
print(json.dumps({
  'aiBranch':      sys.argv[1],
  'worktreePath':  sys.argv[2],
  'pendingChanges': [l for l in sys.argv[3].splitlines() if l.strip()],
  'commits':        [l for l in sys.argv[4].splitlines() if l.strip()],
}))
" "$AI_BRANCH" "$WORKTREE_PATH" "$STATUS_OUT" "$LOG_OUT"
    ;;

  merge)
    [[ -z "$SOURCE" ]] && fail "--source is required for merge action"
    [[ -z "$TARGET" ]] && fail "--target is required for merge action"

    git checkout "$TARGET" 2>/dev/null || fail "Failed to checkout '$TARGET'" 2

    if [[ "$STRATEGY" == "squash" ]]; then
      MERGE_OUT="$(git merge --squash "$SOURCE" 2>&1)" || fail "Squash merge failed: $MERGE_OUT" 2
    else
      MERGE_OUT="$(git merge --no-ff "$SOURCE" 2>&1)"  || fail "Merge failed: $MERGE_OUT" 2
    fi

    CLEANUP_DONE=false
    if [[ "$KEEP_BRANCH" == "false" ]]; then
      if git worktree list --porcelain | grep -q "branch refs/heads/$SOURCE"; then
        git worktree remove --force "$SOURCE" &>/dev/null || true
      fi
      git branch -D "$SOURCE" &>/dev/null || true
      CLEANUP_DONE=true
    fi

    python3 -c "
import json, sys
print(json.dumps({
  'action':      'merge',
  'source':      sys.argv[1],
  'target':      sys.argv[2],
  'strategy':    sys.argv[3],
  'keepBranch':  sys.argv[4] == 'true',
  'cleanupDone': sys.argv[5] == 'true',
  'output':      sys.argv[6],
}))
" "$SOURCE" "$TARGET" "$STRATEGY" "$KEEP_BRANCH" "$CLEANUP_DONE" "$MERGE_OUT"
    ;;

  cleanup)
    WORKTREE_REMOVED=false
    if git worktree list --porcelain | grep -q "branch refs/heads/$AI_BRANCH"; then
      git worktree remove --force "$AI_BRANCH" &>/dev/null && WORKTREE_REMOVED=true || true
    fi

    BRANCH_DELETED=false
    git branch -D "$AI_BRANCH" &>/dev/null && BRANCH_DELETED=true || true

    python3 -c "
import json, sys
print(json.dumps({
  'action':          'cleanup',
  'aiBranch':        sys.argv[1],
  'worktreeRemoved': sys.argv[2] == 'true',
  'branchDeleted':   sys.argv[3] == 'true',
}))
" "$AI_BRANCH" "$WORKTREE_REMOVED" "$BRANCH_DELETED"
    ;;

  *)
    fail "Unknown action '$ACTION'. Valid actions: check, create, status, merge, cleanup"
    ;;
esac
````

### .agents/skills/git-workflow/SKILL.md
````markdown
---
name: git-workflow
description: 'Handle work on copilot branches with consistent branch checks, worktree usage for copilot commits, and high-quality commit messages that explain both what changed and why. Use when the user asks to use a separate branch or worktree or if they ask to keep your changes separate.'
argument-hint: 'Optional: mode=[copilot-commit|current-branch](auto)'
---

## Available scripts

- **`scripts/git-workflow{{SHELL_EXT}}`** — Branch/worktree management ({{SHELL_NAME}})

## Required Workflow

1. **Check branch state** — determine current branch, derived AI branch name (`<current>_ai`), and whether its worktree already exists:

   ```sh
   {{SHELL_NAME}} scripts/git-workflow{{SHELL_EXT}} --action check
   ```

   Returns JSON: `{currentBranch, aiBranch, branchExists, worktreeExists, worktreePath, pendingChanges}`.

2. **Handle existing branch** — if `branchExists` or `worktreeExists` is true, ask the user which option they prefer:
   - Use the existing branch as-is
   - Commit and merge it first, then re-create for new work (if it has pending changes)
   - Delete it and create a fresh one
   - Choose a different branch name
   - Continue on the current branch (no worktree)

3. **Create worktree** — if the user confirms a new branch/worktree:

   ```sh
   {{SHELL_NAME}} scripts/git-workflow{{SHELL_EXT}} --action create [--branch <name>]
   ```

   Returns: `{aiBranch, branchCreated, worktreePath}`.

4. Use that branch/worktree for the rest of the session unless the user says otherwise.

5. **On commit** — after committing to the AI branch, offer the user this matrix and run the corresponding merge/cleanup:
   - Merge to source branch → delete branch/worktree
   - Merge to source branch → keep branch/worktree
   - Squash-merge → delete branch/worktree
   - Squash-merge → keep branch/worktree
   - Leave separate, continue working

   To merge:
   ```sh
   {{SHELL_NAME}} scripts/git-workflow{{SHELL_EXT}} --action merge --source <ai-branch> --target <source-branch> [--strategy squash] [--keepBranch]
   ```

6. **Cleanup** — remove worktree and delete branch when no longer needed:

   ```sh
   {{SHELL_NAME}} scripts/git-workflow{{SHELL_EXT}} --action cleanup [--branch <name>]
   ```

## Safety Rules
- Do not switch to or create unrelated branches.
- Keep commit messages specific and actionable; avoid vague one-liners.
- Never force-push to the source branch.
````

### .agents/skills/new-skill/references/specification.md
````markdown
# Agent Skills Specification

Source: https://agentskills.io/specification

## Directory structure

A skill is a directory containing at minimum a `SKILL.md` file:

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable scripts agents can run
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: static templates, data, images
```

## SKILL.md format

### Frontmatter (required)

```yaml
---
name: skill-name
description: A description of what this skill does and when to use it.
---
```

With optional fields:

```yaml
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents.
license: Apache-2.0
compatibility: Requires git and Node.js 18+
metadata:
  author: example-org
  version: "1.0"
allowed-tools: Bash(git:*) Read Write
---
```

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Max 64 chars. Lowercase letters, numbers, hyphens only. Must not start or end with a hyphen. Must match directory name. |
| `description` | Yes | Max 1024 chars. Non-empty. Describes what the skill does and when to use it. |
| `license` | No | License name or reference to a bundled license file. |
| `compatibility` | No | Max 500 chars. Environment requirements: intended product, system packages, network access, etc. |
| `metadata` | No | Arbitrary key-value mapping for additional metadata. |
| `allowed-tools` | No | Space-delimited pre-approved tools (experimental). |

#### `name` field rules

- 1–64 characters
- Only unicode lowercase alphanumeric + hyphens
- Must not start or end with `-`
- Must not contain consecutive hyphens (`--`)
- **Must match the parent directory name**

#### `description` field guidance

- Describe both what the skill does and when to use it
- Include keywords that help agents identify relevant tasks

### Body content

No format restrictions — write whatever helps agents perform the task. Recommended sections: step-by-step workflow, examples, edge cases.

Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

## Optional directories

### `scripts/`

Executable scripts the agent can run. Scripts should:
- Be self-contained or clearly document dependencies
- Include helpful `--help` output
- Handle edge cases gracefully
- Accept all input via flags (never interactive prompts)
- Output structured data (JSON/CSV) to stdout; diagnostics to stderr

Supported languages depend on the agent implementation. Common options: Python, Bash, PowerShell, JavaScript.

### `references/`

Additional documentation loaded on demand:
- `REFERENCE.md` — Detailed technical reference
- `FORMS.md` — Form templates or structured data formats
- Domain-specific files (`finance.md`, `legal.md`, etc.)

Keep individual reference files focused. Agents load these on demand, so smaller files mean less context use.

### `assets/`

Static resources: templates, images, data files (lookup tables, schemas).

## File references

Use relative paths from the skill directory root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

Keep file references one level deep from `SKILL.md`. Avoid deeply nested reference chains.

## Progressive disclosure

1. **Metadata (~100 tokens):** `name` and `description` loaded at startup for all skills.
2. **Instructions (< 5000 tokens recommended):** Full `SKILL.md` body loaded when skill is activated.
3. **Resources (as needed):** Files in `scripts/`, `references/`, `assets/` loaded only when required.
````

### .agents/skills/new-skill/references/using-scripts.md
````markdown
# Using Scripts in Skills

Source: https://agentskills.io/skill-creation/using-scripts

## Referencing scripts from `SKILL.md`

Use relative paths from the skill directory root. List available scripts so the agent knows they exist, then instruct it how to run them:

```markdown
## Available scripts

- **`scripts/validate.sh`** — Validates configuration files
- **`scripts/process.py`** — Processes input data

## Workflow

1. Run the validation script:
   ```bash
   bash scripts/validate.sh "$INPUT_FILE"
   ```

2. Process the results:
   ```bash
   python3 scripts/process.py --input results.json
   ```
```

The same relative-path convention applies in `references/*.md` files — script paths in code blocks are relative to the skill directory root.

## Designing scripts for agentic use

### Avoid interactive prompts (hard requirement)

Agents run in non-interactive shells. They cannot respond to TTY prompts, password dialogs, or confirmation menus — a script that blocks on interactive input will hang indefinitely.

Accept all input via command-line flags, environment variables, or stdin:

```
# Bad: hangs waiting for input
$ python scripts/deploy.py
Target environment: _

# Good: clear error with guidance
$ python scripts/deploy.py
Error: --env is required. Options: development, staging, production.
Usage: python scripts/deploy.py --env staging --tag v1.2.3
```

### Document usage with `--help`

`--help` output is the primary way an agent learns your script's interface. Include a brief description, available flags, and usage examples. Keep it concise — it enters the agent's context window.

```
Usage: scripts/process.py [OPTIONS] INPUT_FILE

Process input data and produce a summary report.

Options:
  --format FORMAT    Output format: json, csv, table (default: json)
  --output FILE      Write output to FILE instead of stdout
  --verbose          Print progress to stderr

Examples:
  scripts/process.py data.csv
  scripts/process.py --format csv --output report.csv data.csv
```

### Write helpful error messages

An opaque `Error: invalid input` wastes an agent turn. Say what went wrong, what was expected, and what to try:

```
Error: --format must be one of: json, csv, table.
       Received: "xml"
```

### Use structured output

Prefer JSON, CSV, or TSV over free-form text. Structured formats can be consumed by both the agent and standard tools (`jq`, `cut`, `awk`).

**Send structured data to stdout; diagnostics to stderr.** This lets the agent capture clean, parseable output while still having access to diagnostic information.

```
# Bad: whitespace-aligned — hard to parse programmatically
NAME          STATUS    CREATED
my-service    running   2025-01-15

# Good: structured
{"name": "my-service", "status": "running", "created": "2025-01-15"}
```

## Further design considerations

| Concern | Guidance |
|---------|----------|
| **Idempotency** | "Create if not exists" is safer than "create and fail on duplicate." Agents may retry commands. |
| **Input constraints** | Reject ambiguous input with a clear error. Use enums and closed sets where possible. |
| **Dry-run support** | Add `--dry-run` for destructive or stateful operations so the agent can preview what will happen. |
| **Meaningful exit codes** | Use distinct codes for different failure types and document them in `--help`. |
| **Safe defaults** | Consider `--confirm` / `--force` flags for destructive operations. |
| **Predictable output size** | Default to a summary for large output; support `--offset` for pagination. If output may be large and is not paginatable, require an `--output` flag. |
````

### .agents/skills/new-skill/SKILL.md
````markdown
---
name: skill
description: 'Create, edit, or refactor skills for workspace/profile/global scope. Use for requests like "global skills", "user skills", "my skills", "your skills", "slash commands", "reusable workflows", "automation skill", "agent skill", "SKILL.md", "new skill", or "skill updates". Best for repeatable multi-step tasks and integrations.'
argument-hint: 'scope=[workspace|user](default:profile) name=<skill-name>'
---

# Create Skill Global

Create or update skills for workspace/profile/global targets. Follow the [Agent Skills specification](references/specification.md) and [using scripts guide](references/using-scripts.md) for format compliance.

## Use When

- You want reusable slash workflows.
- You need a dedicated skill for repeated multi-step tasks.
- You need to refactor long procedures into skill instructions.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

1. Resolve the target skills directory and derive the skill path:
   ```sh
   skill_file=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --skills)/<skill-name>/SKILL.md
   # For workspace scope: ... --skills --workspace ...
   ```
   > **Note:** Script outputs the path directly to stdout.

3. If updating an existing `SKILL.md`, back it up first:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase before --file "$skill_file"
   ```
   Skip for new skills.

4. Create or update `SKILL.md` with valid frontmatter and concise procedure steps.
5. Ensure `name` matches the folder name and `description` is keyword-rich.
6. Add `scripts/` or `references/` files as needed; follow [using scripts guide](references/using-scripts.md).
  - If a feature can be written with a shell script, prefer to use a script to increase performance and reproducibility. 

7. Review the diff and approve or reject:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file" --approve --message "skill: <name> updates"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file" --reject
   ```

## Safety Rules

- Do not overwrite unrelated skill folders.
- Keep descriptions keyword-rich so agents can discover the skill.
- Follow the [Agent Skills specification](references/specification.md) for `name`, `description`, and structural constraints.
````

### .agents/skills/rule/SKILL.md
````markdown
---
name: rule
description: 'Create, edit, or refactor instruction/rules files for workspace or user. Use for requests like "global (rules|instructions)", "my (rules|instructions)", "your (rules|instructions)", "project (rules|instructions)", "workspace (rules|instructions)", "user (rules|instructions)", "coding standards", "guardrails", "policy".'
argument-hint: 'scope=[workspace|user](default:user) name=<instruction-name>'
---

# Create Instruction or Rule

Create or update instruction files (VS Code) or rules files (Cursor) for user or workspace targets.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

1. Resolve the target directory and derive the target file path:
   ```sh
   target_file=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --rules)/<instruction-name>.md
   # For workspace scope: ... --rules --workspace ...
   ```
   > **Note:** These scripts run in a child process — they output the path directly to stdout.

2. If the file already exists (update scenario), back it up before editing:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase before --file "$target_file"
   ```
   Skip this step when creating a new file.

3. Create or update the target instruction/rule file. Keep wording concise and non-duplicative.

4. Review the diff and approve or reject:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file" --approve --message "rules: <description>"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$target_file" --reject
   ```

## Safety Rules

- Never edit `*.readonly.*.md` files.
- Prefer updating an existing instruction file before creating a new one.
````

### .agents/skills/setting/SKILL.md
````markdown
---
name: setting
description: 'Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".'
argument-hint: 'scope=[workspace|profile](default:profile) type=[setting|task|mcp|keybinding](default:setting) key=<setting-key>'
---

# Setting

Edit VS Code or Cursor setting/config files using scope-aware path resolution and safe change controls.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target file path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

1. Resolve the target file path. `--git-commit` also backs up the current file before editing:
   ```{{SHELL_NAME}}
   file_path=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --settings task --git-commit)
   # For workspace scope: ... --settings task --workspace --git-commit ...
   ```
   > **Note:** Script outputs the path directly to stdout.
   >
   > Valid types: `setting` → `settings.json` ⬦ `task` → `tasks.json` ⬦ `mcp` → `mcp.json` ⬦ `keybinding` → `keybindings.json`
   >
   > `--git-commit` is a no-op if the file doesn't exist yet.

2. Read, parse, and modify the JSON file at the resolved path without duplicating existing values.

3. Review the diff and approve or reject:
   ```{{SHELL_NAME}}
   # Review only (returns diff JSON, does not commit):
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path"
   # Approve — git add + commit + remove backup:
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --approve --message "settings: update <key>"
   # Reject — restore from backup:
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$file_path" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Keep settings changes minimal and idempotent.
````

### .agents/skills/update-jumper-instructions/SKILL.md
````markdown
---
name: update-jumper-instructions
description: 'Bootstrap or refresh this instruction-and-skill pack by downloading and running dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "refresh global instructions", "reinstall bootstrap", "pull latest initial setup", or "run new install".'
argument-hint: 'Optional: branch=<branch>(default:main)'
---

# Update Jumper Instructions

Download and run this repo's bootstrap setup file from raw GitHub.
## Use When
- You need a quick bootstrap/update entrypoint for this repo.
- You want to fetch and run `dist/initial-setup.readonly.prompt.md` without relying on local profile setup.
- You want a platform-agnostic update flow.

## Required Workflow
1. Build the raw URL using this repo path template:
  - `https://raw.githubusercontent.com/jeff-hamm/copilot-instructions/<branch>/dist/initial-setup.readonly.prompt.md`
  - Default `<branch>` is `main`.
2. If `resources/initial-setup.readonly.prompt.md` exists, compute it's hash and save it.
3. Download the raw file `resources/initial-setup.readonly.prompt.md`
4. If the downloaded filed does not start with `# Initial Copilot Setup`, or if the hash matches the previously saved hash, inform the user and ask if they want to run it anyways. If they say no, stop the flow. If they say yes, continue to the next step.
5. Run the downloaded file as a prompt
6. Summarize the update and include the raw URL and path used.

## Safety Rules
- If download fails, surface the exact URL and error.
- Do not modify files outside this update flow unless explicitly requested.
- Keep the workflow platform-agnostic (no shell-specific temp environment syntax).
````

## Common scripts

The following scripts are shared across multiple skills. Create each file at the path listed, using the content in the section below.

**resolve-editor** — install at:
- `.agents/skills/new-skill/scripts/resolve-editor.ps1`
- `.agents/skills/new-skill/scripts/resolve-editor.sh`
- `.agents/skills/rule/scripts/resolve-editor.ps1`
- `.agents/skills/rule/scripts/resolve-editor.sh`
- `.agents/skills/setting/scripts/resolve-editor.ps1`
- `.agents/skills/setting/scripts/resolve-editor.sh`

**change-control** — install at:
- `.agents/skills/new-skill/scripts/change-control.ps1`
- `.agents/skills/new-skill/scripts/change-control.sh`
- `.agents/skills/rule/scripts/change-control.ps1`
- `.agents/skills/rule/scripts/change-control.sh`
- `.agents/skills/setting/scripts/change-control.ps1`
- `.agents/skills/setting/scripts/change-control.sh`

### common/scripts/resolve-editor.ps1
````powershell
$ErrorActionPreference = "Stop"

function Get-Usage {
  @"
Usage:
  ./resolve-editor.ps1 [--name|--profile|--user|--rules|--skills|--settings [type]|--workspace] [--workspace] [--git-commit]

Modes:
  --name                  Return editor name (default)
  --profile               Return current editor profile (User config) path
  --user                  Return current editor preferred user path
  --rules                 Return user rules/instructions path; add --workspace for workspace-scoped path
  --skills                Return user skills path; add --workspace for workspace-scoped path
  --settings [type]       Return settings dir (default) or a specific file: setting|task|mcp|keybinding
                          e.g. --settings task  ->  .../tasks.json
  --workspace             Workspace-level .agents/.cursor/.claude path (standalone or scope modifier)

Flags:
  --git-commit            After resolving path, also run change-control before-phase (backup + git status).
                          No-op when resolved path is not an existing file.
"@
}

function Resolve-WithModuleIfAvailable {
  param([string]$Flag)

  $modeMap = @{
    '--name' = 'Name'
    '--profile' = 'Profile'
    '--user' = 'User'
    '--rules' = 'Rules'
    '--workspace' = 'Workspace'
  }

  if (-not $modeMap.ContainsKey($Flag)) {
    return $null
  }

  $command = Get-Command -Name 'Resolve-EditorPath' -ErrorAction SilentlyContinue
  if (-not $command) {
    try {
      Import-Module JumpShellPs -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
      $command = Get-Command -Name 'Resolve-EditorPath' -ErrorAction SilentlyContinue
    }
    catch {
      $command = $null
    }
  }

  if (-not $command) {
    return $null
  }

  try {
    $editor = & $command.Name -Mode 'Name'
    if ([string]::IsNullOrWhiteSpace([string]$editor)) {
      return $null
    }

    $scopePath = if ($Flag -eq '--name') {
      ''
    }
    else {
      & $command.Name -Mode $modeMap[$Flag]
    }

    if ($Flag -ne '--name' -and [string]::IsNullOrWhiteSpace([string]$scopePath)) {
      return $null
    }

    return [PSCustomObject]@{
      Editor = [string]$editor
      ScopePath = [string]$scopePath
    }
  }
  catch {
    return $null
  }

  return $null
}

function Export-ScopeContext {
  param(
    [string]$Editor,
    [string]$ScopePath
  )

  $resolvedEditor = [string]$Editor
  $resolvedScopePath = if ($null -eq $ScopePath) { '' } else { [string]$ScopePath }

  Set-Variable -Name 'EDITOR' -Scope Script -Value $resolvedEditor -Force
  Set-Variable -Name 'SCOPE_PATH' -Scope Script -Value $resolvedScopePath -Force

  $Env:EDITOR = $resolvedEditor
  $Env:SCOPE_PATH = $resolvedScopePath
}

function Write-PathTuple {
  param(
    [string]$Editor,
    [string]$ScopePath
  )

  $tuple = @([string]$Editor, [string]$ScopePath)
  Write-Output ($tuple | ConvertTo-Json -Compress)
}

function Select-FirstExisting {
  param([string[]]$Candidates)

  foreach ($candidate in $Candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  return ($Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function Get-HintText {
  $hints = @(
    $Env:VSCODE_IPC_HOOK,
    $Env:VSCODE_GIT_ASKPASS_MAIN,
    $Env:TERM_PROGRAM,
    $Env:TERM_PROGRAM_VERSION,
    $Env:CLAUDECODE,
    $Env:CLAUDE_CONFIG_DIR
  )

  if ($Env:VSCODE_PID -and ($Env:VSCODE_PID -as [int])) {
    try {
      $hostProcess = Get-Process -Id ([int]$Env:VSCODE_PID) -ErrorAction Stop
      $hints += $hostProcess.ProcessName
      if ($hostProcess.Path) {
        $hints += $hostProcess.Path
      }
    }
    catch {
      # Ignore process lookup errors.
    }
  }

  return ($hints | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
}

function Get-EditorOrder {
  $hintText = Get-HintText

  if ($hintText -match 'Code - Insiders|code-insiders') {
    return @('Code - Insiders', 'Code', 'Cursor', 'Claude')
  }

  if ($hintText -match 'Cursor') {
    return @('Cursor', 'Code', 'Code - Insiders', 'Claude')
  }

  if ($hintText -match 'Claude|claude') {
    return @('Claude', 'Code', 'Code - Insiders', 'Cursor')
  }

  return @('Code', 'Code - Insiders', 'Cursor', 'Claude')
}

function Get-ProfileCandidatesForEditor {
  param([string]$Editor)

  if ($IsWindows) {
    $appData = if ($Env:APPDATA) { $Env:APPDATA } else { $Env:AppData }
    if (-not $appData) {
      return @()
    }

    switch ($Editor) {
      'Code' { return @(Join-Path $appData 'Code\User') }
      'Code - Insiders' { return @(Join-Path $appData 'Code - Insiders\User') }
      'Cursor' { return @(Join-Path $appData 'Cursor\User') }
      'Claude' { return @((Join-Path $appData 'Claude\User'), (Join-Path $appData 'Claude')) }
      default { return @() }
    }
  }

  if ($IsMacOS) {
    switch ($Editor) {
      'Code' { return @("$HOME/Library/Application Support/Code/User") }
      'Code - Insiders' { return @("$HOME/Library/Application Support/Code - Insiders/User") }
      'Cursor' { return @("$HOME/Library/Application Support/Cursor/User") }
      'Claude' { return @("$HOME/Library/Application Support/Claude/User", "$HOME/Library/Application Support/Claude") }
      default { return @() }
    }
  }

  switch ($Editor) {
    'Code' { return @("$HOME/.config/Code/User") }
    'Code - Insiders' { return @("$HOME/.config/Code - Insiders/User") }
    'Cursor' { return @("$HOME/.config/Cursor/User") }
    'Claude' { return @("$HOME/.config/Claude/User", "$HOME/.config/Claude") }
    default { return @() }
  }
}

function Resolve-EditorName {
  $ordered = Get-EditorOrder

  foreach ($editor in $ordered) {
    $candidates = Get-ProfileCandidatesForEditor -Editor $editor
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate) {
        return $editor
      }
    }
  }

  return $ordered[0]
}

function Resolve-ProfilePath {
  $editor = Resolve-EditorName
  $candidates = Get-ProfileCandidatesForEditor -Editor $editor
  return (Select-FirstExisting -Candidates $candidates)
}

function Resolve-UserPath {
  $editor = Resolve-EditorName
  if ($editor -eq 'Cursor') {
    return (Join-Path $HOME '.cursor')
  }

  if ($editor -eq 'Claude') {
    return (Join-Path $HOME '.claude')
  }

  return (Join-Path $HOME '.agents')
}

function Resolve-RulesPath {
  $editor = Resolve-EditorName
  $userPath = Resolve-UserPath
  if ($editor -eq 'Cursor') {
    return (Join-Path $userPath 'rules')
  }

  if ($editor -eq 'Claude') {
    $claudeCandidates = @(
      (Join-Path $userPath 'commands'),
      (Join-Path $userPath 'rules'),
      $userPath
    )

    return (Select-FirstExisting -Candidates $claudeCandidates)
  }

  return (Join-Path $userPath 'instructions')
}

function Resolve-WorkspaceRoot {
  $start = (Get-Location).Path

  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($null -ne $git) {
    try {
      $gitRoot = (& git -C $start rev-parse --show-toplevel 2>$null)
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $resolvedGitRoot = $gitRoot.Trim()
        if (Test-Path -LiteralPath $resolvedGitRoot) {
          return $resolvedGitRoot
        }
      }
    }
    catch {
      # Ignore git lookup errors.
    }
  }

  $current = $start
  while (-not [string]::IsNullOrWhiteSpace($current)) {
    $hasWorkspaceFile = @(Get-ChildItem -LiteralPath $current -File -Filter '*.code-workspace' -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0
    $hasMarker =
      (Test-Path -LiteralPath (Join-Path $current '.git')) -or
      (Test-Path -LiteralPath (Join-Path $current '.vscode')) -or
      (Test-Path -LiteralPath (Join-Path $current '.cursor')) -or
      (Test-Path -LiteralPath (Join-Path $current '.agents')) -or
      (Test-Path -LiteralPath (Join-Path $current '.claude')) -or
      $hasWorkspaceFile

    if ($hasMarker) {
      return $current
    }

    $parent = Split-Path -Path $current -Parent
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
      break
    }

    $current = $parent
  }

  return $start
}

function Resolve-WorkspacePath {
  $editor = Resolve-EditorName
  $workspaceRoot = Resolve-WorkspaceRoot

  if ($editor -eq 'Cursor') {
    return (Join-Path $workspaceRoot '.cursor')
  }

  if ($editor -eq 'Claude') {
    return (Join-Path $workspaceRoot '.claude')
  }

  return (Join-Path $workspaceRoot '.agents')
}

function Resolve-WorkspaceRulesPath {
  $editor = Resolve-EditorName
  $workspacePath = Resolve-WorkspacePath

  if ($editor -eq 'Cursor') {
    return (Join-Path $workspacePath 'rules')
  }

  if ($editor -eq 'Claude') {
    $candidates = @(
      (Join-Path $workspacePath 'commands'),
      (Join-Path $workspacePath 'rules'),
      $workspacePath
    )
    return (Select-FirstExisting -Candidates $candidates)
  }

  return (Join-Path $workspacePath 'instructions')
}

function Resolve-SkillsPath {
  param([switch]$Workspace)

  $editor = Resolve-EditorName

  if ($Workspace) {
    $workspacePath = Resolve-WorkspacePath
    return (Join-Path $workspacePath 'skills')
  }

  $userPath = Resolve-UserPath
  return (Join-Path $userPath 'skills')
}

function Resolve-SettingsPath {
  param([switch]$Workspace, [string]$Subtype)

  $fileMap = @{
    'setting'    = 'settings.json'
    'task'       = 'tasks.json'
    'mcp'        = 'mcp.json'
    'keybinding' = 'keybindings.json'
  }

  $dirPath = if ($Workspace) {
    $editor = Resolve-EditorName
    $workspaceRoot = Resolve-WorkspaceRoot
    if ($editor -eq 'Cursor') { Join-Path $workspaceRoot '.cursor' }
    elseif ($editor -eq 'Claude') { Join-Path $workspaceRoot '.claude' }
    else { Join-Path $workspaceRoot '.vscode' }
  } else {
    Resolve-ProfilePath
  }

  if ([string]::IsNullOrWhiteSpace($Subtype)) { return $dirPath }

  $fileName = $fileMap[$Subtype.ToLower()]
  if ($null -eq $fileName) {
    [Console]::Error.WriteLine("Unknown settings subtype '$Subtype'. Valid types: setting, task, mcp, keybinding")
    exit 2
  }

  return (Join-Path $dirPath $fileName)
}

function Invoke-BeforePhase {
  param([string]$FilePath)

  if ([string]::IsNullOrWhiteSpace($FilePath)) { return }
  # Only run before-phase when the resolved path is an existing file
  if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return }

  $ccScript = Join-Path $PSScriptRoot 'change-control.ps1'
  if (-not (Test-Path -LiteralPath $ccScript)) {
    [Console]::Error.WriteLine("[resolve-editor] change-control.ps1 not found: $ccScript")
    return
  }

  $out = & pwsh -NoProfile -File $ccScript --phase before --file $FilePath 2>&1
  $out | ForEach-Object { [Console]::Error.WriteLine([string]$_) }
}

$validModes = @('--name','--profile','--user','--rules','--skills','--settings','--workspace')
$modeArg = $null
$workspaceFlag = $false
$gitCommitFlag = $false
$settingsSubtype = $null

$i = 0
while ($i -lt $args.Count) {
  $a = $args[$i]
  if ($a -eq '--workspace') {
    $workspaceFlag = $true
  }
  elseif ($a -eq '--git-commit') {
    $gitCommitFlag = $true
  }
  elseif ($a -eq '--settings') {
    if ($null -ne $modeArg) {
      [Console]::Error.WriteLine('Multiple mode flags supplied.')
      [Console]::Error.WriteLine((Get-Usage).TrimEnd())
      exit 2
    }
    $modeArg = '--settings'
    # Check if the next arg is a subtype (not a flag)
    if (($i + 1) -lt $args.Count -and -not ($args[$i + 1] -match '^--')) {
      $i++
      $settingsSubtype = $args[$i]
    }
  }
  elseif ($validModes -contains $a) {
    if ($null -ne $modeArg) {
      [Console]::Error.WriteLine('Multiple mode flags supplied.')
      [Console]::Error.WriteLine((Get-Usage).TrimEnd())
      exit 2
    }
    $modeArg = $a
  }
  else {
    [Console]::Error.WriteLine("Unknown argument: $a")
    [Console]::Error.WriteLine((Get-Usage).TrimEnd())
    exit 2
  }
  $i++
}

$mode = if ($null -ne $modeArg) { $modeArg } else { '--name' }
# --workspace alone (no other type) retains legacy behaviour; promote to a mode
if ($null -eq $modeArg -and $workspaceFlag) { $mode = '--workspace'; $workspaceFlag = $false }

$moduleResolved = Resolve-WithModuleIfAvailable -Flag $mode

if ($mode -eq '--name') {
  $editorName = if ($moduleResolved -and -not [string]::IsNullOrWhiteSpace($moduleResolved.Editor)) {
    [string]$moduleResolved.Editor
  }
  else {
    Resolve-EditorName
  }

  Export-ScopeContext -Editor $editorName -ScopePath ''
  Write-Output $editorName
  exit 0
}

# For legacy modes (non-composite), attempt module resolution first
if (-not $workspaceFlag -and $moduleResolved -and -not [string]::IsNullOrWhiteSpace($moduleResolved.Editor) -and -not [string]::IsNullOrWhiteSpace($moduleResolved.ScopePath)) {
  Export-ScopeContext -Editor $moduleResolved.Editor -ScopePath $moduleResolved.ScopePath
  Write-Output $moduleResolved.ScopePath
  exit 0
}

switch ($mode) {
  '--profile' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-ProfilePath
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--user' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-UserPath
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--rules' {
    $editorName = Resolve-EditorName
    $scopePath = if ($workspaceFlag) { Resolve-WorkspaceRulesPath } else { Resolve-RulesPath }
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--skills' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-SkillsPath -Workspace:$workspaceFlag
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--settings' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-SettingsPath -Workspace:$workspaceFlag -Subtype $settingsSubtype
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--workspace' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-WorkspacePath
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  default {
    [Console]::Error.WriteLine("Unknown mode: $mode")
    [Console]::Error.WriteLine((Get-Usage).TrimEnd())
    exit 2
  }
}
````

### common/scripts/resolve-editor.sh
````sh
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./resolve-editor.sh [--name|--profile|--user|--rules|--skills|--settings [type]|--workspace] [--workspace] [--git-commit]

Modes:
  --name                 Return editor name (default)
  --profile              Return current editor profile (User config) path
  --user                 Return current editor preferred user path
  --rules                Return user rules/instructions path; add --workspace for workspace-scoped path
  --skills               Return user skills path; add --workspace for workspace-scoped path
  --settings [type]      Return settings dir (default) or a specific file: setting|task|mcp|keybinding
                         e.g. --settings task  ->  .../tasks.json
  --workspace            Workspace-level .agents/.cursor path (standalone or scope modifier)

Flags:
  --git-commit           After resolving path, also run change-control before-phase (backup + git status).
                         No-op when resolved path is not an existing file.
EOF
}

first_existing_path() {
  for p in "$@"; do
    if [ -n "$p" ] && [ -d "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  for p in "$@"; do
    if [ -n "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  return 1
}

json_escape() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

export_scope_context() {
  local editor="$1"
  local scope_path="$2"
  EDITOR="$editor"
  SCOPE_PATH="$scope_path"
  export EDITOR
  export SCOPE_PATH
}

write_path_tuple() {
  local editor="$1"
  local scope_path="$2"
  printf '["%s","%s"]\n' "$(json_escape "$editor")" "$(json_escape "$scope_path")"
}

hint_text() {
  printf '%s %s %s %s %s %s' "${TERM_PROGRAM-}" "${TERM_PROGRAM_VERSION-}" "${VSCODE_IPC_HOOK-}" "${VSCODE_GIT_ASKPASS_MAIN-}" "${CLAUDECODE-}" "${CLAUDE_CONFIG_DIR-}"
}

editor_order() {
  local hints
  hints="$(hint_text)"

  if printf '%s' "$hints" | grep -Eiq 'Code - Insiders|code-insiders'; then
    printf '%s\n' "Code - Insiders" "Code" "Cursor" "Claude"
    return
  fi

  if printf '%s' "$hints" | grep -qi 'Cursor'; then
    printf '%s\n' "Cursor" "Code" "Code - Insiders" "Claude"
    return
  fi

  if printf '%s' "$hints" | grep -Eiq 'Claude|claude'; then
    printf '%s\n' "Claude" "Code" "Code - Insiders" "Cursor"
    return
  fi

  printf '%s\n' "Code" "Code - Insiders" "Cursor" "Claude"
}

profile_candidates_for_editor() {
  local editor="$1"
  local os
  os="$(uname -s)"

  case "$os" in
    Darwin)
      case "$editor" in
        "Code") printf '%s\n' "$HOME/Library/Application Support/Code/User" ;;
        "Code - Insiders") printf '%s\n' "$HOME/Library/Application Support/Code - Insiders/User" ;;
        "Cursor") printf '%s\n' "$HOME/Library/Application Support/Cursor/User" ;;
        "Claude") printf '%s\n' "$HOME/Library/Application Support/Claude/User" "$HOME/Library/Application Support/Claude" ;;
      esac
      ;;
    Linux)
      case "$editor" in
        "Code") printf '%s\n' "$HOME/.config/Code/User" ;;
        "Code - Insiders") printf '%s\n' "$HOME/.config/Code - Insiders/User" ;;
        "Cursor") printf '%s\n' "$HOME/.config/Cursor/User" ;;
        "Claude") printf '%s\n' "$HOME/.config/Claude/User" "$HOME/.config/Claude" ;;
      esac
      ;;
    *)
      :
      ;;
  esac
}

resolve_editor_name() {
  local editor
  while IFS= read -r editor; do
    while IFS= read -r candidate; do
      if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        printf '%s\n' "$editor"
        return
      fi
    done < <(profile_candidates_for_editor "$editor")
  done < <(editor_order)

  editor_order | head -n 1
}

resolve_profile_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  mapfile -t candidates < <(profile_candidates_for_editor "$editor")
  first_existing_path "${candidates[@]}"
}

resolve_user_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$HOME/.cursor"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    printf '%s\n' "$HOME/.claude"
    return
  fi

  printf '%s\n' "$HOME/.agents"
}

resolve_rules_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local user_path
  user_path="$(resolve_user_path "$editor")"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$user_path/rules"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    first_existing_path "$user_path/commands" "$user_path/rules" "$user_path"
    return
  fi

  printf '%s\n' "$user_path/instructions"
}

resolve_workspace_root() {
  local start current parent
  start="$PWD"

  if command -v git >/dev/null 2>&1; then
    local git_root
    if git_root="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$git_root" ]; then
      printf '%s\n' "$git_root"
      return
    fi
  fi

  current="$start"
  while :; do
    if [ -e "$current/.git" ] || [ -d "$current/.vscode" ] || [ -d "$current/.cursor" ] || [ -d "$current/.agents" ] || [ -d "$current/.claude" ] || compgen -G "$current/*.code-workspace" >/dev/null; then
      printf '%s\n' "$current"
      return
    fi

    parent="$(dirname "$current")"
    if [ "$parent" = "$current" ]; then
      break
    fi
    current="$parent"
  done

  printf '%s\n' "$start"
}

resolve_workspace_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local workspace_root
  workspace_root="$(resolve_workspace_root)"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$workspace_root/.cursor"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    printf '%s\n' "$workspace_root/.claude"
    return
  fi

  printf '%s\n' "$workspace_root/.agents"
}

resolve_workspace_rules_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local workspace_path
  workspace_path="$(resolve_workspace_path "$editor")"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$workspace_path/rules"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    first_existing_path "$workspace_path/commands" "$workspace_path/rules" "$workspace_path"
    return
  fi

  printf '%s\n' "$workspace_path/instructions"
}

resolve_skills_path() {
  local workspace_scope="${1:-false}"
  local editor
  editor="$(resolve_editor_name)"

  if [ "$workspace_scope" = "true" ]; then
    local workspace_path
    workspace_path="$(resolve_workspace_path "$editor")"
    printf '%s\n' "$workspace_path/skills"
    return
  fi

  local user_path
  user_path="$(resolve_user_path "$editor")"
  printf '%s\n' "$user_path/skills"
}

resolve_settings_path() {
  local workspace_scope="${1:-false}"
  local subtype="${2:-}"

  local dir_path
  if [ "$workspace_scope" = "true" ]; then
    local editor workspace_root
    editor="$(resolve_editor_name)"
    workspace_root="$(resolve_workspace_root)"
    if [ "$editor" = "Cursor" ]; then dir_path="$workspace_root/.cursor"
    elif [ "$editor" = "Claude" ]; then dir_path="$workspace_root/.claude"
    else dir_path="$workspace_root/.vscode"
    fi
  else
    local editor
    editor="$(resolve_editor_name)"
    dir_path="$(resolve_profile_path "$editor")"
  fi

  if [ -z "$subtype" ]; then
    printf '%s\n' "$dir_path"
    return
  fi

  local file_name
  case "${subtype,,}" in
    setting)    file_name="settings.json" ;;
    task)       file_name="tasks.json" ;;
    mcp)        file_name="mcp.json" ;;
    keybinding) file_name="keybindings.json" ;;
    *) printf 'Unknown settings subtype \'%s\'. Valid types: setting, task, mcp, keybinding\n' "$subtype" >&2; exit 2 ;;
  esac

  printf '%s/%s\n' "$dir_path" "$file_name"
}

invoke_before_phase() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return
  # Only run when the resolved path is an existing file
  [[ ! -f "$file_path" ]] && return

  local cc_script
  cc_script="$(dirname "$0")/change-control.sh"
  if [[ ! -f "$cc_script" ]]; then
    printf '[resolve-editor] change-control.sh not found: %s\n' "$cc_script" >&2
    return
  fi

  bash "$cc_script" --phase before --file "$file_path" >&2
}

# Parse arguments
MODE=""
WORKSPACE_FLAG=false
GIT_COMMIT_FLAG=false
SETTINGS_SUBTYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|--profile|--user|--rules|--skills|--workspace)
      if [ -n "$MODE" ] && [ "$1" != "--workspace" ]; then
        printf 'Multiple mode flags supplied.\n' >&2; usage >&2; exit 2
      fi
      if [ "$1" = "--workspace" ] && [ -n "$MODE" ]; then
        WORKSPACE_FLAG=true
      else
        MODE="$1"
      fi
      shift
      ;;
    --settings)
      if [ -n "$MODE" ]; then
        printf 'Multiple mode flags supplied.\n' >&2; usage >&2; exit 2
      fi
      MODE="--settings"
      shift
      # Check if next arg is a subtype (not a flag)
      if [[ $# -gt 0 && "$1" != --* ]]; then
        SETTINGS_SUBTYPE="$1"
        shift
      fi
      ;;
    --git-commit)
      GIT_COMMIT_FLAG=true
      shift
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2
      ;;
  esac
done

# --workspace alone retains legacy standalone behaviour
if [ -z "$MODE" ] && [ "$WORKSPACE_FLAG" = "true" ]; then MODE="--workspace"; WORKSPACE_FLAG=false; fi
if [ -z "$MODE" ]; then MODE="--name"; fi
mode="$MODE"

case "$mode" in
  --name)
    editor="$(resolve_editor_name)"
    export_scope_context "$editor" ""
    printf '%s\n' "$editor"
    ;;
  --profile)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_profile_path "$editor")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --user)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_user_path "$editor")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --rules)
    editor="$(resolve_editor_name)"
    if [ "$WORKSPACE_FLAG" = "true" ]; then
      scope_path="$(resolve_workspace_rules_path "$editor")"
    else
      scope_path="$(resolve_rules_path "$editor")"
    fi
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --skills)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_skills_path "$WORKSPACE_FLAG")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --settings)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_settings_path "$WORKSPACE_FLAG" "$SETTINGS_SUBTYPE")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --workspace)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_workspace_path "$editor")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    usage >&2
    exit 2
    ;;
esac
````

### common/scripts/change-control.ps1
````powershell
<#
.SYNOPSIS
  Run before/after file-edit safety checks for skills.

.DESCRIPTION
  Run with --phase before to check git status and snapshot the target file to <file>.bak.
  Run with --phase after to show git diff and git diff --stat for the target file.
  Outputs JSON to stdout; diagnostics to stderr.

.EXAMPLE
  pwsh scripts/change-control.ps1 --phase before --file settings.json
  pwsh scripts/change-control.ps1 --phase after  --file settings.json

.NOTES
  Exit codes:
    0  Success
    1  File not found or required argument missing
#>

param(
  [Parameter(Mandatory, HelpMessage = 'Phase to run: before or after')]
  [ValidateSet('before', 'after')]
  [string]$Phase,

  [Parameter(Mandatory, HelpMessage = 'Path to the file being changed')]
  [string]$File,

  [switch]$Approve,
  [switch]$Reject,
  [string]$Message
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
  param([string[]]$GitArgs)
  & git @GitArgs 2>&1
}

function Get-GitRoot {
  param([string]$Dir)
  $out = Invoke-Git -GitArgs @('-C', $Dir, 'rev-parse', '--show-toplevel')
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($out | Out-String).Trim()
}

$absFile = [System.IO.Path]::GetFullPath($File)

if (-not (Test-Path -LiteralPath $absFile)) {
  Write-Error "File not found: $absFile"
  exit 1
}

$fileDir    = Split-Path -Parent $absFile
$backupPath = "$absFile.bak"
$gitRoot    = Get-GitRoot -Dir $fileDir
$inGit      = -not [string]::IsNullOrEmpty($gitRoot)

if ($Phase -eq 'before') {
  Copy-Item -LiteralPath $absFile -Destination $backupPath -Force

  $gitStatus = $null
  if ($inGit) {
    $gitStatus = (Invoke-Git -GitArgs @('-C', $gitRoot, 'status', '--short', '--', $absFile) | Out-String).Trim()
  }

  [pscustomobject]@{
    phase      = 'before'
    file       = $absFile
    backupPath = $backupPath
    inGit      = $inGit
    gitStatus  = $gitStatus
  } | ConvertTo-Json -Depth 3

  exit 0
}

if ($Phase -eq 'after') {
  if ($Approve -and $Reject) {
    Write-Error '--approve and --reject cannot both be set'
    exit 1
  }

  $diff     = $null
  $diffStat = $null

  if ($inGit) {
    $diff     = (Invoke-Git -GitArgs @('-C', $gitRoot, 'diff', '--', $absFile) | Out-String).Trim()
    $diffStat = (Invoke-Git -GitArgs @('-C', $gitRoot, 'diff', '--stat', '--', $absFile) | Out-String).Trim()
  }
  elseif (Test-Path -LiteralPath $backupPath) {
    $before   = Get-Content -LiteralPath $backupPath -Raw
    $after    = Get-Content -LiteralPath $absFile -Raw
    $diff     = if ($before -eq $after) { '(no changes)' } else { "(not in git — backup exists at $backupPath)" }
    $diffStat = $diff
  }

  $committed = $false
  $restored  = $false

  if ($Approve) {
    if ($inGit) {
      Invoke-Git -GitArgs @('-C', $gitRoot, 'add', '--', $absFile) | Out-Null
      $commitMsg = if (-not [string]::IsNullOrWhiteSpace($Message)) { $Message } else { "chg: update $([IO.Path]::GetFileName($absFile))" }
      Invoke-Git -GitArgs @('-C', $gitRoot, 'commit', '-m', $commitMsg) | Out-Null
    }
    if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
    $committed = $true
  }

  if ($Reject) {
    if (Test-Path -LiteralPath $backupPath) {
      Copy-Item -LiteralPath $backupPath -Destination $absFile -Force
      Remove-Item -LiteralPath $backupPath -Force
    }
    $restored = $true
  }

  [pscustomobject]@{
    phase      = 'after'
    file       = $absFile
    backupPath = $backupPath
    hasBackup  = (Test-Path -LiteralPath $backupPath)
    inGit      = $inGit
    diff       = $diff
    diffStat   = $diffStat
    approved   = $committed
    restored   = $restored
  } | ConvertTo-Json -Depth 3

  exit 0
}
````

### common/scripts/change-control.sh
````sh
#!/usr/bin/env bash
# change-control.sh — Before/after file-edit safety checks for skills.
#
# Usage:
#   bash scripts/change-control.sh --phase before --file <path>
#   bash scripts/change-control.sh --phase after  --file <path>
#
# Outputs JSON to stdout; diagnostics to stderr.
#
# Exit codes:
#   0  Success
#   1  Bad input or file not found

set -euo pipefail

PHASE=""
FILE=""
APPROVE=false
REJECT=false
MESSAGE=""

usage() {
  cat >&2 <<'EOF'
Usage: bash scripts/change-control.sh --phase <before|after> --file <path> [--approve] [--reject] [--message <msg>]

Phases:
  before            Check git status and snapshot the file to <file>.bak.
  after             Show git diff and git diff --stat for the file.
  after --approve   Commit changes (git add + commit) and remove backup.
  after --reject    Restore from <file>.bak and remove backup.

Options:
  --phase    Required. Phase: 'before' or 'after'.
  --file     Required. Path to the file being changed.
  --approve  (after only) Commit the change.
  --reject   (after only) Restore from backup.
  --message  (after --approve) Custom commit message.
  --help     Show this message and exit.
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)   PHASE="$2"; shift 2 ;;
    --file)    FILE="$2";  shift 2 ;;
    --approve) APPROVE=true; shift ;;
    --reject)  REJECT=true;  shift ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage ;;
  esac
done

if [[ -z "$PHASE" || -z "$FILE" ]]; then
  printf '{"error":"--phase and --file are required"}\n' >&2
  exit 1
fi

ABS_FILE="$(realpath "$FILE" 2>/dev/null || echo "$FILE")"
BACKUP="$ABS_FILE.bak"
FILE_DIR="$(dirname "$ABS_FILE")"

if [[ ! -f "$ABS_FILE" ]]; then
  printf '{"error":"file not found","file":"%s"}\n' "$ABS_FILE" >&2
  exit 1
fi

# Detect git root
IN_GIT=false
GIT_ROOT=""
if command -v git &>/dev/null && git -C "$FILE_DIR" rev-parse --show-toplevel &>/dev/null 2>&1; then
  IN_GIT=true
  GIT_ROOT="$(git -C "$FILE_DIR" rev-parse --show-toplevel)"
fi

# JSON-safe string enclosing — prefer python3, fall back to sed
json_str() {
  if command -v python3 &>/dev/null; then
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
  else
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ')"
  fi
}

if [[ "$PHASE" == "before" ]]; then
  cp "$ABS_FILE" "$BACKUP"

  GIT_STATUS=""
  if $IN_GIT; then
    GIT_STATUS="$(git -C "$GIT_ROOT" status --short -- "$ABS_FILE" 2>&1 || true)"
  fi

  printf '{"phase":"before","file":%s,"backupPath":%s,"inGit":%s,"gitStatus":%s}\n' \
    "$(json_str "$ABS_FILE")" \
    "$(json_str "$BACKUP")" \
    "$IN_GIT" \
    "$(json_str "$GIT_STATUS")"

  exit 0
fi

if [[ "$PHASE" == "after" ]]; then
  if $APPROVE && $REJECT; then
    printf '{"error":"--approve and --reject cannot both be set"}\n' >&2
    exit 1
  fi

  DIFF_OUTPUT=""
  DIFF_STAT=""

  if $IN_GIT; then
    DIFF_OUTPUT="$(git -C "$GIT_ROOT" diff -- "$ABS_FILE" 2>&1 || true)"
    DIFF_STAT="$(git -C "$GIT_ROOT" diff --stat -- "$ABS_FILE" 2>&1 || true)"
  elif [[ -f "$BACKUP" ]]; then
    DIFF_OUTPUT="$(diff "$BACKUP" "$ABS_FILE" 2>&1 || true)"
    DIFF_STAT="(not in git — backup exists at $BACKUP)"
  fi

  COMMITTED=false
  RESTORED=false

  if $APPROVE; then
    if $IN_GIT; then
      git -C "$GIT_ROOT" add -- "$ABS_FILE"
      COMMIT_MSG="${MESSAGE:-chg: update $(basename "$ABS_FILE")}"
      git -C "$GIT_ROOT" commit -m "$COMMIT_MSG"
    fi
    [[ -f "$BACKUP" ]] && rm -f "$BACKUP"
    COMMITTED=true
  fi

  if $REJECT; then
    if [[ -f "$BACKUP" ]]; then
      cp "$BACKUP" "$ABS_FILE"
      rm -f "$BACKUP"
    fi
    RESTORED=true
  fi

  HAS_BACKUP=false
  [[ -f "$BACKUP" ]] && HAS_BACKUP=true

  printf '{"phase":"after","file":%s,"backupPath":%s,"hasBackup":%s,"inGit":%s,"diff":%s,"diffStat":%s,"approved":%s,"restored":%s}\n' \
    "$(json_str "$ABS_FILE")" \
    "$(json_str "$BACKUP")" \
    "$HAS_BACKUP" \
    "$IN_GIT" \
    "$(json_str "$DIFF_OUTPUT")" \
    "$(json_str "$DIFF_STAT")" \
    "$COMMITTED" \
    "$RESTORED"

  exit 0
fi

printf '{"error":"unknown phase %s — use before or after"}\n' "$PHASE" >&2
exit 1
````

## Setup-only references (do not install)

### src/global.bootstrap.readonly.instructions.md
````markdown
---
applyTo: "**"
---
# NEVER EDIT THIS FILE

## Your Editable Directories
You can read, create, and edit files in these `$VSCODE_PROFILE` locations:

| Location | Contents | File Pattern |
|----------|----------|--------------|
| `/settings.json` | VS Code/Cursor & Copilot settings | - |
| `/instructions/` | Rules applied to all chats | `*.instructions.md` |
| `~/.agents/skills/` | User-profile slash skills | `*/SKILL.md` |

**Exception:** Never edit `*.readonly.*.md` files.

## Terminology
- "global settings", "my settings" -> `settings.json`, `tasks.json`, `mcp.json`
- "global rules", "your instructions" -> files in `/instructions/`
- "global skills", "your skills" -> files in `~/.agents/skills/`

## Workspace Customization Path Preference
- For workspace-level customizations, prefer `.agents/` over `.copilot/` or `.github/`.
- Prefer `.agents/skills/<name>/` for workspace skills.

## User Skill Commands
- Prefer user-profile skills in `~/.agents/skills/` for global file edits.
- Preferred commands:
  - `/setting`
  - `/rule`
  - `/create-skill-global`
  - `/update-jumper-instructions`
- Use `global.readonly.instructions.md` as fallback guidance when those skills are not available.

## Finding $VSCODE_PROFILE
- Windows (Stable): `$Env:AppData\Code\User\`
- Windows (Insiders): `$Env:AppData\Code - Insiders\User\`
- Windows (Cursor): `$Env:AppData\Cursor\User\`
- macOS (Stable): `$HOME/Library/Application Support/Code/User/`
- macOS (Insiders): `$HOME/Library/Application Support/Code - Insiders/User/`
- macOS (Cursor): `$HOME/Library/Application Support/Cursor/User/`
- Linux (Stable): `$HOME/.config/Code/User/`
- Linux (Insiders): `$HOME/.config/Code - Insiders/User/`
- Linux (Cursor): `$HOME/.config/Cursor/User/`

## What To Do
1. **Explore** `~/.agents/skills/` for existing skills
2. **Use** preferred user skills (`/setting`, `/rule`, `/create-skill-global`, `/update-jumper-instructions`) for global edits
3. **Check** settings.json for existing values before adding
4. **Use** `global.readonly.instructions.md` for fallback editing guidance
5. **Run** `initial-setup.readonly.prompt.md` if core files are missing

---

⚠️ **STOP: Before editing ANY file listed above, you MUST first read `$VSCODE_PROFILE/instructions/global.readonly.instructions.md` for required permissions, backup procedures, and editing rules.**
````

## Post-install: expand shell templates

After recreating all skill files above, replace the shell template placeholders in every installed `SKILL.md` file under `~/.agents/skills/` (recursively).

Detect the target operating system and substitute accordingly:

| Placeholder | Windows (PowerShell) | macOS / Linux (bash) |
|-------------|----------------------|----------------------|
| `{{SHELL_NAME}}` | `pwsh` | `bash` |
| `{{SHELL_EXT}}` | `.ps1` | `.sh` |

**Detection:** Use `$env:OS -eq 'Windows_NT'` (PowerShell) or `uname -s` (bash). If running on Windows, apply the PowerShell substitutions; otherwise apply the bash substitutions.

**Replacement scope:** Apply to all `SKILL.md` files under `~/.agents/skills/` that contain either placeholder token. Update them in-place.
