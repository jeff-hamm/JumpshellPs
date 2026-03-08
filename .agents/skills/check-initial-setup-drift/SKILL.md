---
name: check-initial-setup-drift
description: 'Detect drift between dynamic source discovery (ai/global-instructions/src/user-skills and generated global instructions) and ai/global-instructions/dist/initial-setup.readonly.prompt.md. Use before commit or when troubleshooting missing embedded blocks.'
argument-hint: 'Optional: compiled installer relative path; default is dist/initial-setup.readonly.prompt.md'
---

# Check Initial Setup Drift

Compare the compiled installer file with the content that should be generated from source files.

## Available scripts

- **`scripts/check-drift.ps1`** — Builds expected content from source, compares against the compiled installer, and exits 1 on drift with a diff summary. Run from the workspace root.

## When To Use
- Before committing installer updates.
- After running regeneration to ensure no manual drift remains.
- When debugging mismatches in embedded instruction/skill blocks.

## Procedure

1. Run from the workspace root:
   ```powershell
   pwsh scripts/check-drift.ps1
   ```
   Exit 0 = no drift. Exit 1 = drift detected (diff shown). Exit 2 = error.

2. If drift is detected, regenerate:
   ```powershell
   pwsh .agents/skills/regenerate-initial-setup/scripts/regenerate.ps1
   ```
   Then re-run the drift check to confirm.

