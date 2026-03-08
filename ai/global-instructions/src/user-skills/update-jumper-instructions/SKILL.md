---
name: update-jumper-instructions
description: 'Bootstrap or refresh this instruction-and-skill pack by downloading and running dist/initial-setup.readonly.prompt.md from GitHub. Use for requests like "update jumper instructions", "refresh global instructions", "reinstall bootstrap", "pull latest initial setup", or "run new install".'
argument-hint: 'Optional: branch=<branch>(default:main)'
---

# Update Jumper Instructions

Download and run this repo's bootstrap setup file from raw GitHub.
## Use When
- You need a quick bootstrap/update entrypoint for this repo.
- You want to fetch and run `dist/initial-setup.readonly.prompt.md` without relying on local profile setup.
- You want a platform-agnostic update flow.

## Required Workflow
1. Build the raw URL using this repo path template:
  - `https://raw.githubusercontent.com/jeff-hamm/copilot-instructions/<branch>/dist/initial-setup.readonly.prompt.md`
  - Default `<branch>` is `main`.
2. If `resources/initial-setup.readonly.prompt.md` exists, compute it's hash and save it.
3. Download the raw file `resources/initial-setup.readonly.prompt.md`
4. If the downloaded filed does not start with `# Initial Copilot Setup`, or if the hash matches the previously saved hash, inform the user and ask if they want to run it anyways. If they say no, stop the flow. If they say yes, continue to the next step.
5. Run the downloaded file as a prompt
6. Summarize the update and include the raw URL and path used.

## Safety Rules
- If download fails, surface the exact URL and error.
- Do not modify files outside this update flow unless explicitly requested.
- Keep the workflow platform-agnostic (no shell-specific temp environment syntax).