---
name: maintain-readme
description: 'Keep extensions/jumpshell/README.md accurate and up to date. Use when skills are added/removed, the MCP server changes, ai-backends adds backends, the PowerShell module API changes, or the docs site changes.'
argument-hint: 'Describe what changed (e.g., "added a new skill", "new MCP commands", "new ai-backends provider")'
---

# Maintain README

Keep `extensions/jumpshell/README.md` accurate when any of the four core Jumpshell components change.

## README Location and Purpose

- **File:** `extensions/jumpshell/README.md`
- **Purpose:** Primary user-facing README for the extension marketplace and GitHub. Focuses on the four components (Skills, MCP, AI Backends, PowerShell Module) and links to full docs.
- **Docs site:** `https://jeff-hamm.github.io/jumpshell/` — built from `docs/` using GitHub Pages.

## README Structure

The README has five top-level sections in order:

1. **AI Skills** — skill table with name + description; install path; link to docs
2. **MCP Server** — setup options, runtime commands; link to `docs/pwsh/MCP-Server.md`
3. **AI Backends (`ai-backends` / `ai-cli`)** — provider table, install commands, quick usage; link to `docs/ai/AI-Backends.md`
4. **PowerShell Module** — import commands, installer flags; link to `docs/pwsh/PowerShell-Module.md`
5. **VS Code Extension** — commands table, configuration table (extension is the delivery vehicle, not the focus)

## Source of Truth for Each Section

### AI Skills
- **Skill directories:** `skills/` (each subdirectory is one distributed skill)
- **Skill names and descriptions:** read each `skills/<name>/SKILL.md` frontmatter `name` and `description`
- **Install path:** configured by `jumpshell.skillsPath`, default `~/.agents/skills`
- **Extension packaging manifest:** `extensions/jumpshell/assets/skills-manifest.json`

### MCP Server
- **Config template:** `mcps/jumpshellps.json`
- **Runtime server:** `src/pwsh/mcp/server.ps1`
- **MCP installer script:** `src/pwsh/mcp/Install-Mcp.ps1`
- **Module MCP commands:** `src/pwsh/Mcp.ps1`
- **Full docs:** `docs/pwsh/MCP-Server.md`

### AI Backends
- **Package source:** `src/python/ai-backends/`
- **Module:** `src/python/ai-backends/ai_backends/`
- **Backend list:** `src/python/ai-backends/ai_backends/_backend_config.py` (or `_core.py`)
- **PyPI metadata:** `src/python/ai-backends/pyproject.toml`
- **Full docs:** `docs/ai/AI-Backends.md`

### PowerShell Module
- **Source manifest:** `src/pwsh/Jumpshell.psd1`
- **Source loader:** `src/pwsh/Jumpshell.psm1`
- **Feature scripts:** `src/pwsh/*.ps1`
- **Installer:** `src/pwsh/Install.ps1`
- **Full docs:** `docs/pwsh/PowerShell-Module.md`

### VS Code Extension
- **Extension source:** `extensions/jumpshell/src/`
- **Package manifest:** `extensions/jumpshell/package.json` — `contributes.commands` and `contributes.configuration` are the authoritative lists of commands and settings
- **Full docs:** `docs/extension/VSCode-Extension.md`

## Update Workflow

1. **Identify what changed.** Determine which component section needs updating.

2. **Read the source of truth** for that component (files listed above).

3. **Check the docs page** for that component (`docs/<section>/<Page>.md`) for any prose that should stay in sync.

4. **Edit `extensions/jumpshell/README.md`** — update only the affected section(s).
   - Skill table: one row per skill dir in `skills/`, columns `Skill | Description`
   - Provider table for ai-backends: one row per backend in `_backend_config.py`
   - Commands/Settings tables: source from `package.json` `contributes.commands` / `contributes.configuration`

5. **Verify links** — all section doc links use the pattern `https://jeff-hamm.github.io/jumpshell/<path-without-.md>`.

6. **Do not add new top-level sections** without also updating `docs/index.md`.

## Quality Gates

- Every skill dir in `skills/` has a row in the Skills table
- All backends listed in `_backend_config.py` appear in the Backends table
- Extension commands in `package.json` match the Commands table
- Extension settings in `package.json` match the Configuration table
- All four section doc links resolve correctly on `https://jeff-hamm.github.io/jumpshell/`
- README opens with the component overview, not with extension-wizard onboarding
