# Initial Copilot Setup

Use this prompt when global instructions or skills are missing, or when preparing a fresh environment.

> **Important:** Write this file to a local path first (e.g. `resources/initial-setup.readonly.prompt.md`) before running it as a prompt. Do not pass a raw URL to a web-fetch tool — those tools truncate or summarize remote content. The `/jumpdate` skill handles this automatically.


## Environment preparation
- Install git if it is not already installed.
- Install the **resolve-editor** scripts from the **Common Scripts** section below — these handle all path resolution for the active editor (VS Code, VS Code Insiders, Cursor, or Claude).
  - Windows: `pwsh resolve-editor.ps1 <mode>`
  - macOS/Linux: `bash resolve-editor.sh <mode>`
- Use these modes throughout the rest of setup:
  | Mode | Returns |
  |------|---------|
  | `--profile` | Editor profile path (settings & instructions live here) |
  | `--user` | User customization root (`~/.agents`, `~/.cursor`, etc.) |
  | `--skills` | User skills directory (`~/.agents/skills`) |
  | `--settings setting` | Path to `settings.json` |
  | `--rules` | Instructions/rules directory |
  | `--name` | Editor name string |
- If the profile path (`--profile`) is not a git repository, initialize a new git repository there
  - If you create it, the .gitignore should be
    ```
    *
    !.gitignore
    !instructions/
    !instructions/**
    !jumpshell.md
    !/*.json
    ```
- Ensure the user skills directory exists (resolve with `--skills`).
- If the instructions directory (resolve with `--rules`) does not contain `global.readonly.instructions.md`, create it and copy the full contents from the section below, preserving the `applyTo: "**"` header
- Update settings (resolve with `--settings setting`). Use careful string manipulation that accounts for JSON escaping requirements. Read the existing JSON, parse it, modify the object, and write it back (using ConvertFrom-Json and ConvertTo-Json). If a setting key is unsupported in the current editor, skip it and report that in your summary.
  - Set `github.copilot.chat.codeGeneration.useInstructionFiles` to `true`
  - If it doesn't already exist, append the instructions path (resolve with `--rules` and with `--workspace --rules --relative`) to and `chat.instructionsFilesLocations` list.

## Upgrade existing installs
- Detect whether this script was already installed
- If detected, run an in-place upgrade:
  - Keep existing git history and user-created files.
  - Replace only the files defined in this setup file with current contents.
  - Install or update user-profile skills under the skills directory from the embedded sections below.
  - Preserve user-created instructions, skills, and settings that are not explicitly listed in this setup file.
- If not detected, continue normal setup flow.

## Recreate instructions and user-profile skills

> **Do NOT write a script to parse or extract sections from this file.** Install each file directly by reading its section content below and writing it to disk using your file-write tool (or a terminal here-string). Scripted extraction is unnecessary and error-prone.

The **setup manifest** below lists every file to create. Read each `### path/to/file` section, copy the content inside the outermost fenced block verbatim, and write it to the resolved path. Route each file by its scope:
- `scope: profile` — base path: `$(pwsh resolve-editor.ps1 --profile)` / `$(bash resolve-editor.sh --profile)`
- `scope: user` — base path: `~/` (home directory)
- `scope: common` — install at each target listed in the **Common scripts** section

**Mechanical steps for each file:**
1. Find the `### <path>` heading in this file.
2. Copy the content inside the ` ```` ` fenced block that immediately follows it (strip the fence lines themselves).
3. Write that content verbatim to the resolved destination path.
4. Move to the next file in the manifest.

**Immediately after writing all SKILL.md files**, expand shell template placeholders in one pass.
Locate the `### expand-templates.ps1` and `### expand-templates.sh` sections in this file, write their fenced content to the paths below, run, then delete:
```powershell
# Windows — write expand-templates.ps1 content to this path, then run:
pwsh "$env:TEMP\jumpshell\expand-templates.ps1"
Remove-Item "$env:TEMP\jumpshell\expand-templates.ps1"
```
```bash
# macOS/Linux — write expand-templates.sh content to this path, then run:
bash /tmp/jumpshell/expand-templates.sh
rm /tmp/jumpshell/expand-templates.sh
```
> If the expand-templates sections are not yet in scope, replace `{{SHELL_NAME}}` with `pwsh`/`bash` and `{{SHELL_EXT}}` with `.ps1`/`.sh` manually in every SKILL.md you wrote.

<!-- setup-manifest: machine-readable file index — scan this first to plan your work -->
```yaml
schema: jumpshell/manifest/v1
files:
  # scope: profile — base path: $(pwsh resolve-editor.ps1 --profile) | $(bash resolve-editor.sh --profile)
  - path: instructions/global.readonly.instructions.md
  # scope: user — base path: ~/ (e.g. .agents/skills/... installs to ~/.agents/skills/...)
  - path: .agents/skills/git-workflow/scripts/git-workflow.ps1
  - path: .agents/skills/git-workflow/scripts/git-workflow.sh
  - path: .agents/skills/git-workflow/SKILL.md
  - path: .agents/skills/jumpdate/SKILL.md
  - path: .agents/skills/rule/SKILL.md
  - path: .agents/skills/setting/references/known-settings.md
  - path: .agents/skills/setting/scripts/patch-json.ps1
  - path: .agents/skills/setting/scripts/patch-json.sh
  - path: .agents/skills/setting/SKILL.md
  - path: .agents/skills/skill/references/specification.md
  - path: .agents/skills/skill/references/using-scripts.md
  - path: .agents/skills/skill/SKILL.md
  # scope: temp — expand-templates helpers are written to <TEMP_DIR>/jumpshell/ and deleted after use
  # scope: common — install at each referencing skill's scripts/ dir (see 'Common scripts' section)
  - path: common/scripts/resolve-editor.ps1
  - path: common/scripts/resolve-editor.sh
  - path: common/scripts/change-control.ps1
  - path: common/scripts/change-control.sh
```


### instructions/global.readonly.instructions.md
````markdown
---
applyTo: "**"
---
# NEVER EDIT THIS FILE
## Included User Skills (Generated)
- `/git-workflow`: Handle work on copilot branches with consistent branch checks, worktree usage for copilot commits, and high-quality commit messages that explain both what changed and why. Use when the user asks to use a separate branch or worktree or if they ask to keep your changes separate.
- `/jumpdate`: Bootstrap or refresh this instruction-and-skill pack by downloading and running ai/global-instructions/dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "update jumper skills", "reinstall jumper skills", "reinstall global rules", "update jumper's stuff", or "run new install".
- `/rule`: Create, edit, or refactor instruction/rules files for workspace or user. Use for requests like "global (rules|instructions)", "my (rules|instructions)", "your (rules|instructions)", "project (rules|instructions)", "workspace (rules|instructions)", "user (rules|instructions)", "coding standards", "guardrails", "policy".
- `/setting`: Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".
- `/skill`: Create, edit, or refactor skills for workspace/profile/global scope. Use for requests like "global skills", "user skills", "my skills", "your skills", "slash commands", "reusable workflows", "automation skill", "agent skill", "SKILL.md", "new skill", or "skill updates". Best for repeatable multi-step tasks and integrations.

## Fallback
- Run `initial-setup.readonly.prompt.md` when global instructions or skills are missing.
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

> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.

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

### .agents/skills/jumpdate/SKILL.md
````markdown
---
name: jumpdate
description: 'Bootstrap or refresh this instruction-and-skill pack by downloading and running ai/global-instructions/dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "update jumper skills", "reinstall jumper skills", "reinstall global rules", "update jumper's stuff", or "run new install".'
argument-hint: 'Optional: branch=<branch>(default:main), full (use full installer instead of slim)'
---

# Update Jumper Instructions

Download and run this repo's bootstrap setup file from raw GitHub.

Two installer variants are available:
- **slim** (default) — `initial-setup-slim.readonly.prompt.md`: downloads all files via shell commands; small context footprint.
- **full** — `initial-setup.readonly.prompt.md`: all file contents embedded inline; use when the agent cannot execute shell commands or when `full` is explicitly requested.

## Use When
- You need a quick bootstrap/update entrypoint for this repo.
- You want to fetch and run the installer without relying on local profile setup.
- You want a platform-agnostic update flow.

## Required Workflow
1. Resolve the skill directory: the directory containing this `SKILL.md` file (e.g. `~/.agents/skills/jumpdate/`). All relative paths below are under that directory.
2. Choose the installer variant:
   - Default: **slim** → filename `initial-setup-slim.readonly.prompt.md`
   - If the user passed `full` or the agent cannot run shell commands: **full** → filename `initial-setup.readonly.prompt.md`
3. Build the raw URL:
   - `https://raw.githubusercontent.com/jeff-hamm/jumpshell/<branch>/ai/global-instructions/dist/<filename>`
   - Default `<branch>` is `main`.
4. If step 3 returns 404 and the variant is **full**, try the legacy fallback path:
   - `https://raw.githubusercontent.com/jeff-hamm/jumpshell/<branch>/dist/initial-setup.readonly.prompt.md`
5. Download the raw file to `<skill-dir>/resources/<filename>` (create the `resources/` directory if needed).
6. Run the downloaded file as a prompt.

## Safety Rules
- If download fails, surface the exact URL and error.
- Do not modify files outside this update flow unless explicitly requested.
- Keep the workflow platform-agnostic (no shell-specific temp environment syntax).
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

## Permissions
- You may view my editor configuration and any paths resolved by the scripts and skills below
- If you can't access files directly, use terminal commands — do not prompt for permission.
- *NEVER* Edit or remove a file with a `.readonly.*.md*` file extension. You may read them though.
- You may edit files returned by `scripts/resolve-editor{{SHELL_EXT}}` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})


## Workflow

> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.

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

### .agents/skills/setting/references/known-settings.md
````markdown
# Known VS Code / Cursor Setting Keys

This file is maintained by the `setting` skill. When the slow-path discovery finds a new key
that is broadly useful, add a row here so future lookups are instant.

**Format:** `| natural-language description(s) | dot-notation key | allowed values / type |`

## Copilot

| Description | Setting key | Allowed values |
|---|---|---|
| reasoning effort / thinking effort | `github.copilot.chat.responsesApiReasoningEffort` | `default` `low` `medium` `high` `xhigh` |
| copilot chat model / default model | `github.copilot.chat.defaultModel` | model ID string |

## Editor

| Description | Setting key | Allowed values |
|---|---|---|
| editor font size | `editor.fontSize` | number |
| editor tab size / indent size | `editor.tabSize` | number |
| word wrap | `editor.wordWrap` | `off` `on` `wordWrapColumn` `bounded` |
| format on save | `editor.formatOnSave` | `true` / `false` |
| auto save | `files.autoSave` | `off` `afterDelay` `onFocusChange` `onWindowChange` |

## Terminal

| Description | Setting key | Allowed values |
|---|---|---|
| terminal font size | `terminal.integrated.fontSize` | number |
````

### .agents/skills/setting/scripts/patch-json.ps1
````markdown
$ErrorActionPreference = "Stop"

function Get-Usage {
  @"
Usage:
  ./patch-json.ps1 --type <setting|task|mcp|keybinding> --action <add|edit|remove> [--path <json.path>] [--value <json>] [--match <json>] [--file <path>] [--workspace] [--dry-run]

Purpose:
  Safely patch VS Code/Cursor JSON config files after intent parsing.

Options:
  --type       Target JSON file type: setting, task, mcp, keybinding.
  --action     Patch operation: add, edit, remove.
  --path       Dot path for object targets (example: editor.tabSize). Use '$' for root.
               Ignored for keybinding mode.
  --value      JSON value used by add/edit operations.
  --match      JSON matcher used by keybinding edit/remove (optional for add).
  --file       Explicit file path. If omitted, resolve-editor is used.
  --workspace  Resolve workspace-scoped file when --file is not provided.
  --dry-run    Do not write file; return planned change summary.
"@
}

function ConvertFrom-JsonInput {
  param(
    [string]$JsonText,
    [string]$FieldName
  )

  if ([string]::IsNullOrWhiteSpace($JsonText)) {
    throw "Missing JSON input for $FieldName"
  }

  try {
    return ($JsonText | ConvertFrom-Json -AsHashtable -Depth 100)
  }
  catch {
    throw ('Invalid JSON for {0}: {1}' -f $FieldName, $_.Exception.Message)
  }
}

function ConvertTo-CompactJson {
  param([object]$Value)

  try {
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
  }
  catch {
    return [string]$Value
  }
}

function Test-ValuesEqual {
  param(
    [object]$A,
    [object]$B
  )

  return (ConvertTo-CompactJson -Value $A) -eq (ConvertTo-CompactJson -Value $B)
}

function Split-JsonPath {
  param([string]$PathText)

  if ([string]::IsNullOrWhiteSpace($PathText) -or $PathText -eq '$') {
    return @()
  }

  $normalized = $PathText
  if ($normalized.StartsWith('$.')) {
    $normalized = $normalized.Substring(2)
  }
  elseif ($normalized.StartsWith('$')) {
    $normalized = $normalized.Substring(1)
  }

  $parts = @($normalized -split '\.')
  $parts = @($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  return $parts
}

function Get-DictionaryRoot {
  param([object]$Root)

  if ($null -eq $Root) { return @{} }
  if ($Root -is [System.Collections.IDictionary]) { return $Root }
  throw 'Expected a JSON object as root.'
}

function Get-ArrayRoot {
  param([object]$Root)

  if ($null -eq $Root) {
    return [System.Collections.ArrayList]::new()
  }

  if ($Root -is [System.Collections.IList]) {
    $list = [System.Collections.ArrayList]::new()
    foreach ($item in $Root) {
      [void]$list.Add($item)
    }
    return $list
  }

  throw 'Expected a JSON array as root for keybinding type.'
}

function Get-PathState {
  param(
    [System.Collections.IDictionary]$Root,
    [string[]]$Segments
  )

  if ($Segments.Count -eq 0) {
    return [pscustomobject]@{
      Exists = $true
      Parent = $null
      Leaf = $null
      Value = $Root
    }
  }

  $cursor = $Root
  for ($i = 0; $i -lt ($Segments.Count - 1); $i++) {
    $part = $Segments[$i]
    if (-not $cursor.Contains($part)) {
      return [pscustomobject]@{
        Exists = $false
        Parent = $null
        Leaf = $null
        Value = $null
      }
    }

    $next = $cursor[$part]
    if (-not ($next -is [System.Collections.IDictionary])) {
      return [pscustomobject]@{
        Exists = $false
        Parent = $null
        Leaf = $null
        Value = $null
      }
    }

    $cursor = $next
  }

  $leaf = $Segments[$Segments.Count - 1]
  if ($cursor.Contains($leaf)) {
    return [pscustomobject]@{
      Exists = $true
      Parent = $cursor
      Leaf = $leaf
      Value = $cursor[$leaf]
    }
  }

  return [pscustomobject]@{
    Exists = $false
    Parent = $cursor
    Leaf = $leaf
    Value = $null
  }
}

function Get-PathParent {
  param(
    [System.Collections.IDictionary]$Root,
    [string[]]$Segments
  )

  if ($Segments.Count -eq 0) {
    return [pscustomobject]@{ Parent = $null; Leaf = $null }
  }

  $cursor = $Root
  for ($i = 0; $i -lt ($Segments.Count - 1); $i++) {
    $part = $Segments[$i]
    if (-not $cursor.Contains($part)) {
      $cursor[$part] = @{}
    }

    $next = $cursor[$part]
    if (-not ($next -is [System.Collections.IDictionary])) {
      throw "Cannot create nested key under non-object path segment '$part'"
    }

    $cursor = $next
  }

  return [pscustomobject]@{
    Parent = $cursor
    Leaf = $Segments[$Segments.Count - 1]
  }
}

function Get-KeybindingMatcher {
  param(
    [object]$ValueObject,
    [object]$MatchObject
  )

  if ($null -ne $MatchObject) {
    return $MatchObject
  }

  if ($null -eq $ValueObject) {
    return $null
  }

  if ($ValueObject -is [System.Collections.IDictionary]) {
    if ($ValueObject.Contains('key') -and $ValueObject.Contains('command')) {
      return @{ key = $ValueObject['key']; command = $ValueObject['command'] }
    }

    if ($ValueObject.Contains('command')) {
      return @{ command = $ValueObject['command'] }
    }
  }

  return $ValueObject
}

function Test-KeybindingMatch {
  param(
    [object]$Item,
    [object]$Matcher
  )

  if ($Matcher -is [System.Collections.IDictionary]) {
    if (-not ($Item -is [System.Collections.IDictionary])) { return $false }

    foreach ($entry in $Matcher.GetEnumerator()) {
      if (-not $Item.Contains($entry.Key)) { return $false }
      if (-not (Test-ValuesEqual -A $Item[$entry.Key] -B $entry.Value)) { return $false }
    }

    return $true
  }

  return (Test-ValuesEqual -A $Item -B $Matcher)
}

$validTypes = @('setting', 'task', 'mcp', 'keybinding')
$validActions = @('add', 'edit', 'remove')

$type = $null
$action = $null
$path = $null
$valueJson = $null
$matchJson = $null
$filePath = $null
$workspace = $false
$dryRun = $false

$i = 0
while ($i -lt $args.Count) {
  $arg = $args[$i]

  switch -Regex ($arg) {
    '^--type$' {
      $i++
      if ($i -ge $args.Count) { throw '--type requires a value' }
      $type = $args[$i].ToLower()
      break
    }
    '^--action$' {
      $i++
      if ($i -ge $args.Count) { throw '--action requires a value' }
      $action = $args[$i].ToLower()
      break
    }
    '^--path$' {
      $i++
      if ($i -ge $args.Count) { throw '--path requires a value' }
      $path = $args[$i]
      break
    }
    '^--value$' {
      $i++
      if ($i -ge $args.Count) { throw '--value requires JSON text' }
      $valueJson = $args[$i]
      break
    }
    '^--match$' {
      $i++
      if ($i -ge $args.Count) { throw '--match requires JSON text' }
      $matchJson = $args[$i]
      break
    }
    '^--file$' {
      $i++
      if ($i -ge $args.Count) { throw '--file requires a path' }
      $filePath = $args[$i]
      break
    }
    '^--workspace$' {
      $workspace = $true
      break
    }
    '^--dry-run$' {
      $dryRun = $true
      break
    }
    '^--help$|^-h$' {
      Write-Output (Get-Usage).TrimEnd()
      exit 0
    }
    default {
      throw "Unknown argument: $arg"
    }
  }

  $i++
}

if ([string]::IsNullOrWhiteSpace($type) -or [string]::IsNullOrWhiteSpace($action)) {
  throw "--type and --action are required.`n$(Get-Usage)"
}

if ($validTypes -notcontains $type) {
  throw "Unknown --type '$type'. Valid: $($validTypes -join ', ')"
}

if ($validActions -notcontains $action) {
  throw "Unknown --action '$action'. Valid: $($validActions -join ', ')"
}

if ([string]::IsNullOrWhiteSpace($filePath)) {
  $resolveScript = Join-Path $PSScriptRoot 'resolve-editor.ps1'
  if (-not (Test-Path -LiteralPath $resolveScript)) {
    throw "resolve-editor.ps1 not found next to patch-json script: $resolveScript"
  }

  $resolveArgs = @('--settings', $type)
  if ($workspace) { $resolveArgs += '--workspace' }

  $resolved = & $resolveScript @resolveArgs 2>$null
  if ([string]::IsNullOrWhiteSpace([string]$resolved)) {
    throw 'Failed to resolve target settings file path.'
  }

  $filePath = ([string]$resolved).Trim()
}

$absPath = [System.IO.Path]::GetFullPath($filePath)
$parentDir = Split-Path -Parent $absPath
if (-not (Test-Path -LiteralPath $parentDir)) {
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

$defaultRoot = if ($type -eq 'keybinding') { [System.Collections.ArrayList]::new() } else { @{} }

$existing = $null
if (Test-Path -LiteralPath $absPath) {
  $raw = Get-Content -LiteralPath $absPath -Raw
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
      $existing = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
      throw "Target file is not valid JSON: $absPath"
    }
  }
}

if ($null -eq $existing) {
  $existing = $defaultRoot
}

$changed = $false
$valueObject = $null
$matchObject = $null

if (-not [string]::IsNullOrWhiteSpace($valueJson)) {
  $valueObject = ConvertFrom-JsonInput -JsonText $valueJson -FieldName '--value'
}
if (-not [string]::IsNullOrWhiteSpace($matchJson)) {
  $matchObject = ConvertFrom-JsonInput -JsonText $matchJson -FieldName '--match'
}

if ($type -eq 'keybinding') {
  $doc = Get-ArrayRoot -Root $existing

  if (($action -eq 'add' -or $action -eq 'edit') -and $null -eq $valueObject) {
    throw "--value is required for keybinding $action"
  }

  $matcher = Get-KeybindingMatcher -ValueObject $valueObject -MatchObject $matchObject
  if (($action -eq 'edit' -or $action -eq 'remove') -and $null -eq $matcher) {
    throw "--match or a matchable --value is required for keybinding $action"
  }

  $indexes = New-Object System.Collections.Generic.List[int]
  for ($idx = 0; $idx -lt $doc.Count; $idx++) {
    if (Test-KeybindingMatch -Item $doc[$idx] -Matcher $matcher) {
      [void]$indexes.Add($idx)
    }
  }

  if ($action -eq 'add') {
    if ($indexes.Count -eq 0) {
      [void]$doc.Add($valueObject)
      $changed = $true
    }
  }
  elseif ($action -eq 'edit') {
    if ($indexes.Count -gt 0) {
      $first = $indexes[0]
      if (-not (Test-ValuesEqual -A $doc[$first] -B $valueObject)) {
        $doc[$first] = $valueObject
        $changed = $true
      }
    }
    else {
      [void]$doc.Add($valueObject)
      $changed = $true
    }
  }
  elseif ($action -eq 'remove') {
    if ($indexes.Count -gt 0) {
      $descending = @($indexes | Sort-Object -Descending)
      foreach ($index in $descending) {
        $doc.RemoveAt($index)
      }
      $changed = $true
    }
  }

  $existing = $doc
}
else {
  $doc = Get-DictionaryRoot -Root $existing
  # VS Code settings.json stores dotted keys as literal flat keys (e.g. "editor.tabSize").
  # Splitting on '.' would create nested objects instead of matching the existing flat key.
  $segments = if ($type -eq 'setting') { @($path) } else { Split-JsonPath -PathText $path }

  if ($segments.Count -eq 0) {
    throw "--path is required for type '$type' (for example: editor.tabSize)"
  }

  if (($action -eq 'add' -or $action -eq 'edit') -and $null -eq $valueObject) {
    throw "--value is required for $action"
  }

  $state = Get-PathState -Root $doc -Segments $segments

  if ($action -eq 'add') {
    if (-not $state.Exists) {
      $target = Get-PathParent -Root $doc -Segments $segments
      $target.Parent[$target.Leaf] = $valueObject
      $changed = $true
    }
  }
  elseif ($action -eq 'edit') {
    $target = Get-PathParent -Root $doc -Segments $segments
    $current = $null
    $hasCurrent = $target.Parent.Contains($target.Leaf)
    if ($hasCurrent) { $current = $target.Parent[$target.Leaf] }

    if (-not $hasCurrent -or -not (Test-ValuesEqual -A $current -B $valueObject)) {
      $target.Parent[$target.Leaf] = $valueObject
      $changed = $true
    }
  }
  elseif ($action -eq 'remove') {
    if ($state.Exists) {
      [void]$state.Parent.Remove($state.Leaf)
      $changed = $true
    }
  }

  $existing = $doc
}

if ($changed -and -not $dryRun) {
  $jsonOutput = ($existing | ConvertTo-Json -Depth 100)
  Set-Content -LiteralPath $absPath -Value $jsonOutput -Encoding UTF8
}

[pscustomobject]@{
  status  = 'ok'
  changed = $changed
  dryRun  = $dryRun
  file    = $absPath
  type    = $type
  action  = $action
  path    = $path
} | ConvertTo-Json -Depth 5 -Compress
````

### .agents/skills/setting/scripts/patch-json.sh
````markdown
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./patch-json.sh --type <setting|task|mcp|keybinding> --action <add|edit|remove> [--path <json.path>] [--value <json>] [--match <json>] [--file <path>] [--workspace] [--dry-run]

Purpose:
  Safely patch VS Code/Cursor JSON config files after intent parsing.

Options:
  --type       Target JSON file type: setting, task, mcp, keybinding.
  --action     Patch operation: add, edit, remove.
  --path       Dot path for object targets (example: editor.tabSize). Use '$' for root.
               Ignored for keybinding mode.
  --value      JSON value used by add/edit operations.
  --match      JSON matcher used by keybinding edit/remove (optional for add).
  --file       Explicit file path. If omitted, resolve-editor is used.
  --workspace  Resolve workspace-scoped file when --file is not provided.
  --dry-run    Do not write file; return planned change summary.
EOF
}

TYPE=""
ACTION=""
PATH_ARG=""
VALUE_JSON=""
MATCH_JSON=""
FILE_PATH=""
WORKSPACE="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TYPE="${2:-}"
      shift 2
      ;;
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --path)
      PATH_ARG="${2:-}"
      shift 2
      ;;
    --value)
      VALUE_JSON="${2:-}"
      shift 2
      ;;
    --match)
      MATCH_JSON="${2:-}"
      shift 2
      ;;
    --file)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$TYPE" || -z "$ACTION" ]]; then
  printf '%s\n\n' "--type and --action are required." >&2
  usage >&2
  exit 2
fi

if [[ "$TYPE" != "setting" && "$TYPE" != "task" && "$TYPE" != "mcp" && "$TYPE" != "keybinding" ]]; then
  printf 'Unknown --type %s\n' "$TYPE" >&2
  exit 2
fi

if [[ "$ACTION" != "add" && "$ACTION" != "edit" && "$ACTION" != "remove" ]]; then
  printf 'Unknown --action %s\n' "$ACTION" >&2
  exit 2
fi

if [[ -z "$FILE_PATH" ]]; then
  RESOLVER="$(dirname "$0")/resolve-editor.sh"
  if [[ ! -f "$RESOLVER" ]]; then
    printf 'resolve-editor.sh not found next to patch-json script: %s\n' "$RESOLVER" >&2
    exit 1
  fi

  if [[ "$WORKSPACE" == "true" ]]; then
    FILE_PATH="$(bash "$RESOLVER" --settings "$TYPE" --workspace)"
  else
    FILE_PATH="$(bash "$RESOLVER" --settings "$TYPE")"
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required by patch-json.sh\n' >&2
  exit 1
fi

python3 - "$FILE_PATH" "$TYPE" "$ACTION" "$PATH_ARG" "$VALUE_JSON" "$MATCH_JSON" "$DRY_RUN" <<'PY'
import json
import os
import sys
from pathlib import Path


def fail(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


def parse_json(text: str, label: str):
    if text == "":
        return None
    try:
        return json.loads(text)
    except Exception as exc:
        fail(f"Invalid JSON for {label}: {exc}")


def deep_equal(a, b) -> bool:
    return json.dumps(a, sort_keys=True, separators=(",", ":")) == json.dumps(b, sort_keys=True, separators=(",", ":"))


def split_path(path_text: str):
    if path_text in ("", "$"):
        return []
    if path_text.startswith("$."):
        path_text = path_text[2:]
    elif path_text.startswith("$"):
        path_text = path_text[1:]
    return [part for part in path_text.split(".") if part]


def ensure_parent(root: dict, segments):
    cur = root
    for part in segments[:-1]:
        if part not in cur:
            cur[part] = {}
        if not isinstance(cur[part], dict):
            fail(f"Cannot create nested key under non-object path segment '{part}'")
        cur = cur[part]
    return cur


def derive_match(value_obj, match_obj):
    if match_obj is not None:
        return match_obj
    if value_obj is None:
        return None
    if isinstance(value_obj, dict):
        if "key" in value_obj and "command" in value_obj:
            return {"key": value_obj["key"], "command": value_obj["command"]}
        if "command" in value_obj:
            return {"command": value_obj["command"]}
    return value_obj


def entry_matches(item, matcher):
    if isinstance(matcher, dict):
        if not isinstance(item, dict):
            return False
        for k, v in matcher.items():
            if k not in item or not deep_equal(item[k], v):
                return False
        return True
    return deep_equal(item, matcher)


if len(sys.argv) != 8:
    fail("Internal argument error", 2)

file_path = Path(sys.argv[1]).expanduser().resolve()
file_type = sys.argv[2]
action = sys.argv[3]
path_arg = sys.argv[4]
value_json = sys.argv[5]
match_json = sys.argv[6]
dry_run = sys.argv[7].lower() == "true"

value_obj = parse_json(value_json, "--value")
match_obj = parse_json(match_json, "--match")

default_root = [] if file_type == "keybinding" else {}

if file_path.exists():
    raw = file_path.read_text(encoding="utf-8")
    if raw.strip():
        try:
            document = json.loads(raw)
        except Exception:
            fail(f"Target file is not valid JSON: {file_path}")
    else:
        document = default_root
else:
    document = default_root

changed = False

if file_type == "keybinding":
    if document is None:
        document = []
    if not isinstance(document, list):
        fail("Expected a JSON array as root for keybinding type.")

    if action in ("add", "edit") and value_obj is None:
        fail(f"--value is required for keybinding {action}")

    matcher = derive_match(value_obj, match_obj)
    if action in ("edit", "remove") and matcher is None:
        fail(f"--match or a matchable --value is required for keybinding {action}")

    match_indexes = [idx for idx, entry in enumerate(document) if entry_matches(entry, matcher)]

    if action == "add":
        if not match_indexes:
            document.append(value_obj)
            changed = True
    elif action == "edit":
        if match_indexes:
            first = match_indexes[0]
            if not deep_equal(document[first], value_obj):
                document[first] = value_obj
                changed = True
        else:
            document.append(value_obj)
            changed = True
    elif action == "remove":
        if match_indexes:
            for idx in sorted(match_indexes, reverse=True):
                del document[idx]
            changed = True
else:
    if document is None:
        document = {}
    if not isinstance(document, dict):
        fail("Expected a JSON object as root.")

    segments = split_path(path_arg)
    if not segments:
        fail(f"--path is required for type '{file_type}' (for example: editor.tabSize)")

    if action in ("add", "edit") and value_obj is None:
        fail(f"--value is required for {action}")

    parent = ensure_parent(document, segments)
    leaf = segments[-1]

    if action == "add":
        if leaf not in parent:
            parent[leaf] = value_obj
            changed = True
    elif action == "edit":
        if leaf not in parent or not deep_equal(parent[leaf], value_obj):
            parent[leaf] = value_obj
            changed = True
    elif action == "remove":
        if leaf in parent:
            del parent[leaf]
            changed = True

if changed and not dry_run:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

result = {
    "status": "ok",
    "changed": changed,
    "dryRun": dry_run,
    "file": str(file_path),
    "type": file_type,
    "action": action,
    "path": path_arg,
}
print(json.dumps(result, separators=(",", ":")))
PY
````

### .agents/skills/setting/SKILL.md
````markdown
---
name: setting
description: 'Edit VS Code or Cursor configuration files with scope-aware targeting. Use for requests like "global settings", "my settings", "workspace settings", "vscode settings", "user settings", "settings.json", "tasks.json", "mcp.json", "keybindings", "Copilot settings", or "instruction/skill locations".'
argument-hint: 'scope=[workspace|profile](default:profile) type=[setting|task|mcp|keybinding](default:setting) key=<setting-key-or-description>'
---

# Setting

Edit VS Code or Cursor setting/config files using scope-aware path resolution and safe change controls.

## Permissions
- You may view my editor configuration and any paths resolved by the scripts and skills below
- If you can't access files directly, use terminal commands — do not prompt for permission.
- *NEVER* Edit or remove a file with a `.readonly.*.md*` file extension. You may read them though.
- You may edit files returned by `scripts/resolve-editor{{SHELL_EXT}}` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target file path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})
- **`scripts/patch-json{{SHELL_EXT}}`** — Applies structured JSON patches for settings/task/mcp/keybinding files ({{SHELL_NAME}})

## References

- **`references/known-settings.md`** — Cache of discovered setting keys; you may add rows freely.


## Workflow

> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.

1. **Discover the setting key** when the request uses natural-language or a descriptive label instead of an exact dot-notation key.

   **Fast path — consult `references/known-settings.md` first (no filesystem access needed):**

   Read [`references/known-settings.md`](references/known-settings.md) and check whether the user's description matches any row.
   If it does, skip steps b–d and proceed directly to patching.

   **After any slow-path discovery that finds a new broadly-useful key**, add it to `references/known-settings.md` under the appropriate section so future lookups are instant. You may edit that file freely.

   **Slow path — when key is not in references:**

   a. Use the `get_vscode_api` deferred tool (load via `tool_search_tool_regex` first) to search setting IDs by keyword — fastest option when available.

   b. Otherwise use ripgrep against only the most relevant extension directory (scope the search, don't scan all extensions):
      ```{{SHELL_NAME}}
      # Resolve the extensions root
      $extRoot = if (Test-Path "$env:USERPROFILE\.vscode\extensions") { "$env:USERPROFILE\.vscode\extensions" } else { (pwsh scripts/resolve-editor{{SHELL_EXT}} --profile) | Split-Path | Join-Path -ChildPath "..\extensions" }
      # Search only likely extension dirs first (e.g. github.copilot* for Copilot-related terms)
      $hint = "<publisher-prefix>"   # e.g. "github.copilot" for reasoning/copilot queries, "ms-vscode" for core editor
      $dirs = Get-ChildItem $extRoot -Directory | Where-Object Name -like "$hint*" | Select-Object -ExpandProperty FullName
      if (-not $dirs) { $dirs = @($extRoot) }
      rg -l -i "<keyword1>|<keyword2>" $dirs --glob "package.json" --max-depth 2
      ```
      Then read only the matching file(s) and extract the relevant key:
      ```{{SHELL_NAME}}
      rg -n -i "<keyword1>|<keyword2>" "<matching-package.json-path>"
      ```

   c. If no match is found, grep the active settings file for partial matches:
      ```{{SHELL_NAME}}
      rg -n -i "<keyword>" (pwsh scripts/resolve-editor{{SHELL_EXT}} --settings setting)
      ```

   d. Present the top candidate key(s) with their current value. Auto-confirm if there is exactly one strong match; otherwise ask the user.

2. Parse the prompt to determine the exact JSON intent before editing:
   - Determine target type: `setting`, `task`, `mcp`, or `keybinding`.
   - Determine operation: `add`, `edit`, or `remove`.
   - Determine patch parameters:
     - Object-style edits (`setting`, `task`, `mcp`): `--path` and optional `--value`.
     - Array-style edits (`keybinding`): `--value` and optional `--match`.

3. Use `scripts/patch-json{{SHELL_EXT}}` to apply the patch when the request maps to a structured JSON change:

   > **`--value` must be valid JSON.** Numbers: `'2'`. Booleans: `'true'`. Strings: `'"value"'` (outer single-quotes, inner double-quotes in pwsh) or `'"value"'` in bash.

   ```{{SHELL_NAME}}
   # Example: edit a setting (number)
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type setting --action edit --path editor.tabSize --value '2'

   # Example: edit a setting (string) — note inner double-quotes for JSON string encoding
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type setting --action edit --path github.copilot.chat.responsesApiReasoningEffort --value '"high"'

   # Example: add a VS Code task (workspace scoped)
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type task --action edit --path tasks --value '[{"label":"build","type":"shell","command":"npm run build"}]' --workspace

   # Example: remove a keybinding by matcher
   {{SHELL_NAME}} scripts/patch-json{{SHELL_EXT}} --type keybinding --action remove --match '{"key":"ctrl+alt+b","command":"workbench.action.tasks.build"}'
   ```
   > **Note:** `patch-json` resolves the correct file automatically via `resolve-editor` unless `--file` is provided.

4. Review the diff and approve or reject:
   ```{{SHELL_NAME}}
   # Resolve settings file path first
   {{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --settings setting
   # Use the returned path as <file_path> in the commands below
   # Review only (returns diff JSON, does not commit)
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>"
   # Approve: git add + commit + remove backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>" --approve --message "settings: update <key>"
   # Reject: restore from backup
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "<file_path>" --reject
   ```

## Safety Rules

- Never edit files matching `*.readonly.*.md`.
- Use terminal fallback read/write when direct file APIs are unavailable.
- Use `scripts/patch-json{{SHELL_EXT}}` for JSON changes when possible; fall back to manual editing only for unsupported transformations.
- Keep settings changes minimal and idempotent.
````

### .agents/skills/skill/references/specification.md
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

### .agents/skills/skill/references/using-scripts.md
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

### .agents/skills/skill/SKILL.md
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

## Permissions
- You may view my editor configuration and any paths resolved by the scripts and skills below
- If you can't access files directly, use terminal commands — do not prompt for permission.
- *NEVER* Edit or remove a file with a `.readonly.*.md*` file extension. You may read them though.
- You may edit files returned by `scripts/resolve-editor{{SHELL_EXT}}` without the `.readonly.*.md` extension per each section below.
  - If you can't edit those files directly, use terminal commands — do not prompt for permission.
    - If a file must be written from the terminal:
      - Linux/macOS: wrap the block in `cat <<'EOF' > …` so the shell copies it exactly
      - PowerShell: use a literal PowerShell here-string and Set-Content -Encoding UTF8 to avoid quoting problems.
      
## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.

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
  - If the skill references any `scripts/`, `references/`, or `assets/` paths, place `> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.` at the top of the `## Workflow` section. The builder expands it to a blockquote instructing the agent to `cd` to the skill directory first.

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



### expand-templates.ps1
> **Temp only** — write to `$env:TEMP\jumpshell\expand-templates.ps1` (Windows), run via `pwsh`, then delete. Do not install permanently.
````markdown
#!/usr/bin/env pwsh
# expand-templates.ps1 — Expand {{SHELL_NAME}} and {{SHELL_EXT}} placeholders in all SKILL.md files.
#
# Usage:
#   pwsh expand-templates.ps1 [--skills-dir <path>] [--dry-run]
#
# Options:
#   --skills-dir <path>   Explicit skills directory. If omitted, resolved via resolve-editor.ps1 --skills.
#   --dry-run             Report what would change without writing files.
#
# Outputs: JSON to stdout, diagnostics to stderr.
# Exit codes: 0 success, 1 error.

param(
  [string]$SkillsDir = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SkillsDir)) {
  $resolverScript = Join-Path $PSScriptRoot "resolve-editor.ps1"
  if (-not (Test-Path -LiteralPath $resolverScript)) {
    $resolverScript = Get-ChildItem -Path (Join-Path $HOME ".agents/skills") -Recurse -Filter "resolve-editor.ps1" -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not [string]::IsNullOrWhiteSpace($resolverScript) -and (Test-Path -LiteralPath $resolverScript)) {
    $SkillsDir = (& pwsh -NoProfile -File $resolverScript --skills 2>$null).Trim()
  }
}

if ([string]::IsNullOrWhiteSpace($SkillsDir)) {
  $SkillsDir = Join-Path $HOME ".agents/skills"
}

$isWin     = ($Env:OS -eq 'Windows_NT') -or ($PSVersionTable.Platform -ne 'Unix')
$shellName = if ($isWin) { "pwsh" } else { "bash" }
$shellExt  = if ($isWin) { ".ps1" } else { ".sh" }

$updated = @()

if (Test-Path -LiteralPath $SkillsDir) {
  $skillFiles = Get-ChildItem -LiteralPath $SkillsDir -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue |
    Where-Object {
      $raw = Get-Content -LiteralPath $_.FullName -Raw
      $raw -match '\{\{SHELL_NAME\}\}' -or $raw -match '\{\{SHELL_EXT\}\}' -or $raw -match '\{\{SCRIPT_PATHS_NOTE\}\}'
    }

  $scriptPathsNote = '> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`.'

  foreach ($file in $skillFiles) {
    $content    = Get-Content -LiteralPath $file.FullName -Raw
    $newContent = $content.Replace('{{SHELL_NAME}}', $shellName)
    $newContent = $newContent.Replace('{{SHELL_EXT}}', $shellExt)
    $newContent = $newContent.Replace('{{SCRIPT_PATHS_NOTE}}', $scriptPathsNote)
    if ($newContent -ne $content) {
      if (-not $DryRun) {
        Set-Content -LiteralPath $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
      }
      $updated += $file.FullName
    }
  }
}

[pscustomobject]@{
  status    = "ok"
  dryRun    = [bool]$DryRun
  skillsDir = $SkillsDir
  shellName = $shellName
  shellExt  = $shellExt
  updated   = @($updated)
} | ConvertTo-Json -Depth 3
````

### expand-templates.sh
> **Temp only** — write to `/tmp/jumpshell/expand-templates.sh` (macOS/Linux), run via `bash`, then delete. Do not install permanently.
````markdown
#!/usr/bin/env bash
# expand-templates.sh — Expand {{SHELL_NAME}} and {{SHELL_EXT}} placeholders in all SKILL.md files.
#
# Usage:
#   bash expand-templates.sh [--skills-dir <path>] [--dry-run]
#
# Options:
#   --skills-dir <path>   Explicit skills directory. If omitted, resolved via resolve-editor.sh --skills.
#   --dry-run             Report what would change without writing files.
#
# Outputs: JSON to stdout, diagnostics to stderr.
# Exit codes: 0 success, 1 error.

set -euo pipefail

SKILLS_DIR=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    --dry-run)    DRY_RUN="true";  shift ;;
    --help|-h)    printf 'Usage: bash expand-templates.sh [--skills-dir <path>] [--dry-run]\n'; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SKILLS_DIR" ]]; then
  RESOLVER="$(dirname "$0")/resolve-editor.sh"
  if [[ -f "$RESOLVER" ]]; then
    SKILLS_DIR="$(bash "$RESOLVER" --skills)"
  else
    # Fallback: search for resolve-editor.sh in ~/.agents/skills
    RESOLVER_FOUND="$(find "$HOME/.agents/skills" -name "resolve-editor.sh" 2>/dev/null | head -n1 || true)"
    if [[ -n "$RESOLVER_FOUND" ]]; then
      SKILLS_DIR="$(bash "$RESOLVER_FOUND" --skills)"
    fi
  fi
fi

[[ -z "$SKILLS_DIR" ]] && SKILLS_DIR="$HOME/.agents/skills"

SHELL_NAME="bash"
SHELL_EXT=".sh"

UPDATED_PATHS=()

if [[ -d "$SKILLS_DIR" ]]; then
  while IFS= read -r -d '' skill_file; do
    content="$(cat "$skill_file")"
    if printf '%s' "$content" | grep -qE '\{\{SHELL_NAME\}\}|\{\{SHELL_EXT\}\}|\{\{SCRIPT_PATHS_NOTE\}\}'; then
      new_content="${content//\{\{SHELL_NAME\}\}/$SHELL_NAME}"
      new_content="${new_content//\{\{SHELL_EXT\}\}/$SHELL_EXT}"
      script_paths_note='> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`. Use them as relative paths from that directory without `cd`.'
      new_content="${new_content//\{\{SCRIPT_PATHS_NOTE\}\}/$script_paths_note}"
      if [[ "$new_content" != "$content" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
          printf '%s' "$new_content" > "$skill_file"
        fi
        UPDATED_PATHS+=("$skill_file")
      fi
    fi
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null)
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$DRY_RUN" "$SKILLS_DIR" "$SHELL_NAME" "$SHELL_EXT" "${UPDATED_PATHS[@]+"${UPDATED_PATHS[@]}"}" <<'PY'
import json, sys
dry_run    = sys.argv[1] == "true"
skills_dir = sys.argv[2]
shell_name = sys.argv[3]
shell_ext  = sys.argv[4]
updated    = sys.argv[5:] if len(sys.argv) > 5 else []
print(json.dumps({
  "status":    "ok",
  "dryRun":    dry_run,
  "skillsDir": skills_dir,
  "shellName": shell_name,
  "shellExt":  shell_ext,
  "updated":   updated,
}))
PY
else
  printf '{"status":"ok","dryRun":%s,"skillsDir":"%s","shellName":"%s","shellExt":"%s","updated":[]}\n' \
    "$DRY_RUN" "$SKILLS_DIR" "$SHELL_NAME" "$SHELL_EXT"
fi
````

## Common scripts

The following scripts are shared across multiple skills. Create each file at the path listed, using the content in the section below.

**resolve-editor** — install at:
- `.agents/skills/rule/scripts/resolve-editor.ps1`
- `.agents/skills/rule/scripts/resolve-editor.sh`
- `.agents/skills/setting/scripts/resolve-editor.ps1`
- `.agents/skills/setting/scripts/resolve-editor.sh`
- `.agents/skills/skill/scripts/resolve-editor.ps1`
- `.agents/skills/skill/scripts/resolve-editor.sh`

**change-control** — install at:
- `.agents/skills/rule/scripts/change-control.ps1`
- `.agents/skills/rule/scripts/change-control.sh`
- `.agents/skills/setting/scripts/change-control.ps1`
- `.agents/skills/setting/scripts/change-control.sh`
- `.agents/skills/skill/scripts/change-control.ps1`
- `.agents/skills/skill/scripts/change-control.sh`

### common/scripts/resolve-editor.ps1
<!-- copy to all paths listed under 'resolve-editor' in the Common scripts section above -->
````markdown
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
  --relative              When combined with a --workspace path, return only the workspace-relative portion (e.g. .agents/instructions).
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
      Import-Module Jumpshell -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
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

function Get-WorkspaceRelativePath {
  param([string]$ScopePath)
  $workspaceRoot = Resolve-WorkspaceRoot
  return [System.IO.Path]::GetRelativePath($workspaceRoot, $ScopePath)
}

$validModes = @('--name','--profile','--user','--rules','--skills','--settings','--workspace')
$modeArg = $null
$workspaceFlag = $false
$gitCommitFlag = $false
$relativeFlag = $false
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
  elseif ($a -eq '--relative') {
    $relativeFlag = $true
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
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-WorkspaceRelativePath -ScopePath $scopePath }
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--skills' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-SkillsPath -Workspace:$workspaceFlag
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-WorkspaceRelativePath -ScopePath $scopePath }
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--settings' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-SettingsPath -Workspace:$workspaceFlag -Subtype $settingsSubtype
    if ($relativeFlag -and $workspaceFlag) { $scopePath = Get-WorkspaceRelativePath -ScopePath $scopePath }
    Export-ScopeContext -Editor $editorName -ScopePath $scopePath
    Write-Output $scopePath
    if ($gitCommitFlag) { Invoke-BeforePhase -FilePath $scopePath }
  }
  '--workspace' {
    $editorName = Resolve-EditorName
    $scopePath = Resolve-WorkspacePath
    if ($relativeFlag) { $scopePath = Get-WorkspaceRelativePath -ScopePath $scopePath }
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
<!-- copy to all paths listed under 'resolve-editor' in the Common scripts section above -->
````markdown
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
  --relative             When combined with a --workspace path, return only the workspace-relative portion (e.g. .agents/instructions).
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

make_relative() {
  local path="$1"
  local workspace_root
  workspace_root="$(resolve_workspace_root)"
  printf '%s\n' "${path#"$workspace_root/"}"
}

# Parse arguments
MODE=""
WORKSPACE_FLAG=false
GIT_COMMIT_FLAG=false
RELATIVE_FLAG=false
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
    --relative)
      RELATIVE_FLAG=true
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
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --skills)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_skills_path "$WORKSPACE_FLAG")"
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --settings)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_settings_path "$WORKSPACE_FLAG" "$SETTINGS_SUBTYPE")"
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --workspace)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_workspace_path "$editor")"
    [ "$RELATIVE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
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
<!-- copy to all paths listed under 'change-control' in the Common scripts section above -->
````markdown
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
<!-- copy to all paths listed under 'change-control' in the Common scripts section above -->
````markdown
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

## Path Resolution
Use the **resolve-editor** scripts for all path resolution:
- Windows: `pwsh scripts/resolve-editor.ps1 <mode>`
- macOS/Linux: `bash scripts/resolve-editor.sh <mode>`

| Mode | Returns |
|------|---------|
| `--profile` | Editor profile path (settings, instructions) |
| `--rules` | Instructions/rules directory |
| `--skills` | Skills directory |
| `--settings [type]` | Specific settings file (`setting`, `task`, `mcp`, `keybinding`) |

## Your Editable Directories

| resolve-editor Mode | Contents | File Pattern |
|---------------------|----------|--------------|
| `--settings setting` | VS Code/Cursor & Copilot settings | `settings.json` |
| `--rules` | Rules applied to all chats | `*.instructions.md` |
| `--skills` | User-profile slash skills | `*/SKILL.md` |

**Exception:** Never edit `*.readonly.*.md` files.

## Terminology
- "global settings", "my settings" → `settings.json`, `tasks.json`, `mcp.json`
- "global rules", "your instructions" → files in the instructions directory (resolve with `--rules`)
- "global skills", "your skills" → files under skills directory (resolve with `--skills`)

## Workspace Customization Path Preference
- For workspace-level customizations, prefer `.agents/` over `.cursor/` or `.github/`.
- Prefer `.agents/skills/<name>/` for workspace skills.

## User Skill Commands
- Prefer user-profile skills in `~/.agents/skills/` for global file edits.
- Use `global.readonly.instructions.md` as fallback guidance when those skills are not available.

## What To Do
1. **Explore** skills directory (resolve with `--skills`) for existing skills
3. **Check** settings.json for existing values before adding
4. **Use** `global.readonly.instructions.md` for fallback editing guidance
5. **Run** `initial-setup.readonly.prompt.md` if core files are missing

---

⚠️ **STOP: Before editing ANY file listed above, you MUST first read `global.readonly.instructions.md` in the instructions directory (resolve with `--rules`) for required permissions, backup procedures, and editing rules.**
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

**Run the temp helpers** (from the `### expand-templates.ps1` / `### expand-templates.sh` sections in this file), then delete them:
```powershell
# Windows
pwsh "$env:TEMP/jumpshell/expand-templates.ps1"
Remove-Item "$env:TEMP/jumpshell/expand-templates.ps1"
```
```bash
# macOS/Linux
bash /tmp/jumpshell/expand-templates.sh
rm /tmp/jumpshell/expand-templates.sh
```

**Create Symlinks** 
- Create symlinks for copilot, claude and cursor at `~/.github/skills`, `~/.claude/skills` and `~/.cursor/skills` to `resolve-editor.<ext> --skills`. If those paths already exist, ask if the user wants to migrate to the new path, if so, move files there before replacing those paths with symlinks
- Do the same for `~/.github/instructions`, `~/.claude/rules` and `~/.cursor/rules` to `resolve-editor.<ext> --rules`
- 
## Verification

After all steps are complete, confirm each item:

| Item | Check |
|------|-------|
| resolve-editor works | `pwsh resolve-editor.ps1 --name` / `bash resolve-editor.sh --name` returns `Code`, `Cursor`, or similar |
| Instructions installed | `$(resolve-editor --rules)/global.readonly.instructions.md` exists |
| Skills installed | `$(resolve-editor --skills)` contains `skill`, `rule`, `setting`, `jumpdate` |
| Settings updated | `settings.json` contains `"github.copilot.chat.codeGeneration.useInstructionFiles": true` |
| Version stamp written | `~/.agents/.jumpshell-version` exists and contains today's date |
| Templates expanded | No `SKILL.md` files under `~/.agents/skills/` contain `{{SHELL_NAME}}` or `{{SHELL_EXT}}` |

If any check fails, re-run the corresponding section of this setup prompt.
