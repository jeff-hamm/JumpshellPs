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
