---
name: git-workflow
description: 'Handle work on copilot branches with consistent branch checks, worktree usage for copilot commits, and high-quality commit messages that explain both what changed and why. Use when the user asks to use a separate branch or worktree or if they ask to keep your changes separate.'
argument-hint: 'Optional: mode=[copilot-commit|current-branch](auto)'
---

## Available scripts

- **`scripts/git-workflow{{SHELL_EXT}}`** — Branch/worktree management ({{SHELL_NAME}})

## Required Workflow

{{SCRIPT_PATHS_NOTE}}

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
