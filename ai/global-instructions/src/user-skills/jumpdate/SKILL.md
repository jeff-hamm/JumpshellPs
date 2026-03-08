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
   - `https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/<branch>/ai/global-instructions/dist/<filename>`
   - Default `<branch>` is `main`.
4. If step 3 returns 404 and the variant is **full**, try the legacy fallback path:
   - `https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/<branch>/dist/initial-setup.readonly.prompt.md`
5. If `<skill-dir>/resources/<filename>` exists, compute its hash and save it.
6. Download the raw file to `<skill-dir>/resources/<filename>` (create the `resources/` directory if needed).
7. If the downloaded file does not start with `# Initial Copilot Setup`, or if the hash matches the previously saved hash, inform the user and ask whether to run it anyway. If they say no, stop the flow. If they say yes, continue.
8. Run the downloaded file as a prompt.
9. Summarize the update and include the variant used, the raw URL, branch, and local path.

## Safety Rules
- If download fails, surface the exact URL and error.
- Do not modify files outside this update flow unless explicitly requested.
- Keep the workflow platform-agnostic (no shell-specific temp environment syntax).