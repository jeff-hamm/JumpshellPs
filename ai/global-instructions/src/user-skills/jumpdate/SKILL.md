---
name: jumpdate
description: 'Bootstrap or refresh this instruction-and-skill pack by downloading and running ai/global-instructions/dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "update jumper skills", "reinstall jumper skills", "reinstall global rules", "update jumper's stuff", or "run new install".'
argument-hint: 'Optional: branch=<branch>(default:main)'
---

# Update Jumper Instructions

Download and run this repo's bootstrap setup file from raw GitHub.
## Use When
- You need a quick bootstrap/update entrypoint for this repo.
- You want to fetch and run `ai/global-instructions/dist/initial-setup.readonly.prompt.md` without relying on local profile setup.
- You want a platform-agnostic update flow.

## Required Workflow
1. Resolve the skill directory: the directory containing this `SKILL.md` file (e.g. `~/.agents/skills/jumpdate/`). All relative paths below are under that directory.
2. Build the raw URL using this fixed repo path template:
  - `https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/<branch>/ai/global-instructions/dist/initial-setup.readonly.prompt.md`
  - Default `<branch>` is `main`.
3. If step 2 returns 404, try the legacy fallback path:
  - `https://raw.githubusercontent.com/jeff-hamm/JumpshellPs/<branch>/dist/initial-setup.readonly.prompt.md`
4. If `<skill-dir>/resources/initial-setup.readonly.prompt.md` exists, compute its hash and save it.
5. Download the raw file to `<skill-dir>/resources/initial-setup.readonly.prompt.md` (create the `resources/` directory if needed).
6. If the downloaded file does not start with `# Initial Copilot Setup`, or if the hash matches the previously saved hash, inform the user and ask whether to run it anyway. If they say no, stop the flow. If they say yes, continue.
7. Run the downloaded file as a prompt.
8. Summarize the update and include the raw URL, branch, and local path used.

## Safety Rules
- If download fails, surface the exact URL and error.
- Do not modify files outside this update flow unless explicitly requested.
- Keep the workflow platform-agnostic (no shell-specific temp environment syntax).