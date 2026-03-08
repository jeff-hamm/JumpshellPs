---
name: regenerate-initial-setup
description: 'Regenerate ai/global-instructions/dist/initial-setup.readonly.prompt.md from ai/global-instructions/src source files using dynamic discovery of ai/global-instructions/src/user-skills. Also writes a minimal new-install bootstrap file under ai/global-instructions/dist/ that downloads the raw compiled installer from origin and runs it.'
argument-hint: 'Optional: output relative path; default is dist/initial-setup.readonly.prompt.md'
---

# Regenerate Initial Setup

Rebuild the compiled installer file from canonical source files.

## Available scripts

- **`scripts/regenerate.ps1`** — Scans source files, rebuilds the compiled installer and the bootstrap file. Run from the workspace root.
- **`scripts/initial-setup-builder.ps1`** — Scans source files, rebuilds the compiled installer and the bootstrap file. Run from the workspace root.
- **`scripts/check-drift.ps1`** — Checks for drift between source files and the compiled installer. Run from the workspace root.

## When To Use
- You updated files in `ai/global-instructions/src/` that feed the compiled installer.
- `ai/global-instructions/dist/initial-setup.readonly.prompt.md` is missing sections or has stale content.
- You changed user-profile skill source files under `ai/global-instructions/src/user-skills/`.
- You need deterministic regeneration before review.

## Procedure

1. Run from the workspace root:
   ```powershell
   pwsh scripts/regenerate.ps1
   ```
   This scans `ai/global-instructions/src/user-skills`, regenerates the installer, and also writes `ai/global-instructions/dist/new-install.readonly.prompt.md` with the current `origin` raw GitHub URL.

2. Review changes:
   ```powershell
   git diff ai/global-instructions/dist/initial-setup.readonly.prompt.md
   ```

3. Verify no drift before committing:
   ```powershell
   pwsh ./scripts/check-drift.ps1
   ```