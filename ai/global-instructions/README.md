# Copilot Global Setup Prompts

This directory contains the source-of-truth prompt and instruction files used to bootstrap global GitHub Copilot behavior in a VS Code or Cursor user profile.

The main goal is to let a fresh install quickly recreate:
- reusable global prompts,
- reusable global instructions,
- key settings that enable instruction/prompt loading.

## What This Repo Is For

Use this repo when you want a repeatable way to configure global Copilot behavior in your VS Code or Cursor profile (`$VSCODE_PROFILE`) and keep those files under git.

The compiled installer prompts are:
- `dist/initial-setup.readonly.prompt.md`
- `dist/new-install.readonly.prompt.md`

It is built from canonical source files in `src/`.

## Repo Layout

| Path | Purpose | Source of Truth |
|---|---|---|
| `src/edit-global-files.readonly.prompt.md` | Rules for editing global settings/prompts/instructions safely | Yes |
| `src/environment-setup.readonly.prompt.md` | Environment prep and settings initialization steps | Yes |
| `src/global.bootstrap.readonly.instructions.md` | Full setup-time global instruction reference (not installed as always-on file) | Yes |
| `src/global.readonly.instructions.md` | Minimal base for runtime global instruction generation | Yes |
| `src/update-initial-setup.readonly.prompt.md` | Meta-prompt describing how to regenerate initial setup prompt | Yes |
| `src/user-skills/common/profile-resolution.md` | Shared scope and path resolution reference for user skills | Yes |
| `src/user-skills/*/SKILL.md` | Canonical source for user-profile global editing skills | Yes |
| `dist/initial-setup.readonly.prompt.md` | Compiled bootstrap prompt used on fresh installs | No (generated from `src/*`) |
| `dist/new-install.readonly.prompt.md` | Minimal new-install bootstrap prompt | No (generated) |
| `src/prompts/git-workflow.prompt.md` | Reusable prompt source for copilot-branch/worktree workflow | Yes |
| `instructions/copilot-instructions.md` | Lightweight global instruction include | Yes |
| `.agents/skills/regenerate-initial-setup/` | Workspace skill to regenerate compiled initial setup prompt | Yes |
| `.agents/skills/check-initial-setup-drift/` | Workspace skill to detect drift between source and compiled prompt | Yes |
| `.agents/skills/verify-initial-setup/` | Workspace skill to run pre-commit verification checks | Yes |

## Customization Path Preference

This repository prefers `.agents/` for skill/customization placement.

- Workspace scope: `.agents/skills/<name>/`
- User scope: `~/.agents/skills/<name>/`
- Avoid as first choice: `.copilot/` and `.github/`

This keeps conventions consistent for both workspace and user-level agent customizations.

## Workspace Skills

These skills are included under `.agents/skills`:

- `regenerate-initial-setup`: rebuilds `dist/initial-setup.readonly.prompt.md` (and `dist/new-install.readonly.prompt.md`) from `src/*`
- `check-initial-setup-drift`: compares expected compiled content vs current file
- `verify-initial-setup`: runs drift checks, required marker checks, Insiders checks, and prints git status/diff stats

Run them directly with PowerShell:

```powershell
pwsh ./ai/global-instructions/scripts/regenerate-initial-setup/regenerate.ps1
pwsh ./ai/global-instructions/scripts/check-initial-setup-drift/check-drift.ps1
```

## User-Profile Global Edit Skills

The `edit-global-files` concept is now split into multiple focused slash skills (installed under `~/.agents/skills`):

- `/setting`
- `/rule`
- `/create-prompt-global`
- `/create-skill-global`
- `/update-jumper-prompts`

These are sourced from `src/user-skills/*/SKILL.md`, share path logic from `src/user-skills/common/profile-resolution.md`, and are embedded into `dist/initial-setup.readonly.prompt.md` during regeneration.

Profile-level support in VS Code/Cursor:
- Profile-level instruction files are supported via `$VSCODE_PROFILE/prompts/*.instructions.md`.
- Profile-level prompt files are supported via `$VSCODE_PROFILE/prompts/*.prompt.md`.

Cursor support:
- Windows: `$Env:AppData\Cursor\User\`
- macOS: `$HOME/Library/Application Support/Cursor/User/`
- Linux: `$HOME/.config/Cursor/User/`

## VS Code Stable + Insiders Support

The source prompts/instructions now include profile path variants for both channels.

| OS | Stable | Insiders |
|---|---|---|
| Windows | `$Env:AppData\Code\User\` | `$Env:AppData\Code - Insiders\User\` |
| macOS | `$HOME/Library/Application Support/Code/User/` | `$HOME/Library/Application Support/Code - Insiders/User/` |
| Linux | `$HOME/.config/Code/User/` | `$HOME/.config/Code - Insiders/User/` |

## How `initial-setup.readonly.prompt.md` Is Built

The compiled prompt is assembled in this order:
1. Static header (`Initial Copilot Setup`)
2. Full contents of `src/edit-global-files.readonly.prompt.md`
3. Full contents of `src/environment-setup.readonly.prompt.md`
4. "Recreate prompts, instructions, and user-profile skills" section header text
5. Embedded copy of `src/edit-global-files.readonly.prompt.md`
6. Embedded copy of generated `instructions/global.readonly.instructions.md` built dynamically from:
	- `src/global.readonly.instructions.md` (minimal base)
	- discovered files in `src/prompts`
	- discovered files in `src/user-skills`
7. Embedded copy of `src/user-skills/common/profile-resolution.md`
8. Embedded copy of `src/user-skills/setting/SKILL.md`
9. Embedded copy of `src/user-skills/rule/SKILL.md`
10. Embedded copy of `src/user-skills/create-prompt-global/SKILL.md`
11. Embedded copy of `src/user-skills/create-skill-global/SKILL.md`
12. Embedded copy of `src/user-skills/update-jumper-prompts/SKILL.md`
13. Setup-only reference block embedding `src/global.bootstrap.readonly.instructions.md`

This duplication is intentional so the bootstrap prompt can recreate required files without external lookup.

## Regeneration Workflow

When the compiled prompt drifts:
1. Update canonical files in `src/` first.
2. Rebuild `dist/initial-setup.readonly.prompt.md` using `src/update-initial-setup.readonly.prompt.md`.
3. During rebuild, the skill scans `src/prompts` and `src/user-skills` and creates a temporary generated `global.readonly.instructions.md` outside git for embedding.
4. Verify embedded blocks match source content byte-for-byte.
5. Review with `git diff` and `git diff --stat`.

## Fresh Install Workflow

On a new machine/profile:
1. Run the compiled prompt `dist/initial-setup.readonly.prompt.md`.
2. It prepares git/profile basics and required settings.
3. It recreates the key read-only prompt/instruction files in `$VSCODE_PROFILE`.

## Upgrade Legacy Install Workflow

For profiles that were initialized from commit `b9cc57aa67b6b25c5348fe7f807f229b544905c7`:
1. Run the compiled prompt `dist/initial-setup.readonly.prompt.md` again.
2. The environment setup detects legacy markers and performs an in-place upgrade.
3. It updates the managed prompt/instruction files and installs the current user-profile skills under `~/.agents/skills/`.
4. It preserves user-created prompts/instructions/settings not explicitly managed by this setup prompt.

## Should This Be Converted To Skills?

Short answer: yes, as a multi-skill model plus a fallback prompt.

What should stay as prompts/instructions:
- Global bootstrap behavior in user profile directories.
- Fallback guardrails (`edit-global-files.readonly.prompt.md`) for environments where skills are missing.

What should be skills:
- User-profile global edit workflows (`/setting`, `/rule`, `/create-prompt-global`, `/create-skill-global`, `/update-jumper-prompts`).
- Maintainer-only repo workflows (`regenerate-initial-setup`, `check-initial-setup-drift`, `verify-initial-setup`).

Why not remove prompts/instructions entirely:
- Initial bootstrap still needs a prompt/instruction entrypoint that can recreate missing assets.
- Prompt/instruction files remain useful compatibility and safety anchors.

For `edit-global-files.readonly.prompt.md` specifically:
- Keep the prompt for bootstrap and policy-critical guardrails.
- Add a companion user-level skill in `~/.agents/skills/` for day-to-day global file editing workflows.
- Use `.agents/` as the default location for both workspace and user-level skills.

## Maintenance Notes

- Treat `src/*` as canonical.
- Keep wording concise to reduce context overhead.
- Avoid editing generated output directly unless you are intentionally regenerating it.
- Preserve `.readonly.*.md` semantics for bootstrap artifacts.

