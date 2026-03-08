---
name: test-install-live
description: 'Post-push end-to-end test. Downloads ai/global-instructions/dist/initial-setup.readonly.prompt.md from GitHub via ai/global-instructions/dist/new-install.readonly.prompt.md, validates outputs, and self-heals generation scripts on failure.'
argument-hint: 'Optional: branch=<branch>(default:main)'
---

# Test Install Live (Post-Push / Download)

Run `ai/global-instructions/dist/new-install.readonly.prompt.md` — this downloads the compiled setup from raw GitHub and executes it. Then validate output files and self-heal on failure.

## When To Use
- After pushing changes to verify the published setup works end-to-end.
- To confirm the raw GitHub download URL resolves and the content is correct.
- As a final gate before announcing a new release.

## Procedure

### Phase 1 — Run the download-based install
1. Run `ai/global-instructions/dist/new-install.readonly.prompt.md`.
   - This creates a temp directory, downloads `ai/global-instructions/dist/initial-setup.readonly.prompt.md` from the raw GitHub URL, validates the download starts with `# Initial Copilot Setup`, and then runs the downloaded file.
2. Record every error, warning, or unexpected behavior encountered during execution.

### Phase 2 — Validate outputs
After install finishes, resolve `$VSCODE_PROFILE` and `~/.agents/skills/` per the setup file's own path rules. Then verify **all** of the following. Collect every failure before reporting.

#### 2a. Directory-based file validation
Use the **downloaded** compiled setup file as the source of truth. Each `###` heading inside its `## Recreate instructions and user-profile skills` block defines a target file path and its expected content.

1. Parse the downloaded setup file and collect every `### <relative-path>` section under the recreate block.
2. For each section, resolve the target path (`$VSCODE_PROFILE/…` or `~/.agents/skills/…`).
3. Confirm the file exists, is non-empty, and its trimmed content matches the embedded section verbatim.

#### 2b. Settings validation
Read `$VSCODE_PROFILE/settings.json` and confirm:
- `github.copilot.chat.codeGeneration.useInstructionFiles` is `true`.
- `github.copilot.chat.codeGeneration.instructions` contains the `$VSCODE_PROFILE/instructions` path.

#### 2c. Generated sections in global instructions
Read the installed `global.readonly.instructions.md` and confirm:
- `## Included User Skills (Generated)` exists and has an entry for every `SKILL.md` found under `ai/global-instructions/src/user-skills/`.

#### 2d. Download integrity
Compare the downloaded temp file against the local `ai/global-instructions/dist/initial-setup.readonly.prompt.md`:
- If they differ, report the exact differences — this indicates the push did not propagate or the local copy has unpushed changes.

### Phase 3 — Handle failures
If **any** validation check fails:

1. **Diagnose** — determine whether the failure is in:
   - The generation scripts (`regenerate.ps1`, `initial-setup-builder.ps1` under `ai/global-instructions/scripts/regenerate-initial-setup/`).
   - Source content in `ai/global-instructions/src/` (user-skills, instructions, or templates).
   - The `ai/global-instructions/dist/new-install.readonly.prompt.md` template logic inside the builder.
   - A push/propagation issue (downloaded content doesn't match local dist).
2. **Fix** — edit the appropriate files in `ai/global-instructions/scripts/regenerate-initial-setup/` and/or `ai/global-instructions/src/`.
3. **Regenerate** — rebuild dist outputs:
   ```powershell
   pwsh .agents/skills/regenerate-initial-setup/scripts/regenerate.ps1
   ```
4. **Verify regeneration** — run the drift check:
   ```powershell
   pwsh .agents/skills/check-initial-setup-drift/scripts/check-drift.ps1
   ```
5. **Commit & push** — stage all changed files, commit with a fix message, and push:
   ```powershell
   git add -A
   git commit -m "fix: <description of what was wrong and what was fixed>"
   git push
   ```
6. **Wait for propagation** — allow a brief delay for GitHub raw content to update.
7. **Restart** — go back to **Phase 1** and re-run the full test. Repeat until all validations pass.

### Phase 4 — Report
When all checks pass, print a summary:
- Raw URL used for download.
- List of files validated and their status.
- Whether downloaded content matched local dist.
- Number of fix-and-retry cycles performed (if any).
- Final commit SHA (if fixes were pushed).

## Safety Rules
- Never edit `*.readonly.*.md` files directly — only fix the generation scripts and source files that produce them.
- Do not push without a successful drift check.
- If a fix cycle repeats more than 3 times, stop and report the unresolved failures instead of looping indefinitely.

