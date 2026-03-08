---
name: new-skill
description: 'Create, edit, or refactor skills for workspace/profile/global scope. Use for requests like "global skills", "user skills", "my skills", "your skills", "slash commands", "reusable workflows", "automation skill", "agent skill", "SKILL.md", "new skill", or "skill updates". Best for repeatable multi-step tasks and integrations.'
argument-hint: 'scope=[workspace|user](default:profile) name=<skill-name>'
---

# Create Skill Global

Create or update skills for workspace/profile/global targets. Follow the [Agent Skills specification](references/specification.md) and [using scripts guide](references/using-scripts.md) for format compliance.

## Use When

- You want reusable slash workflows.
- You need a dedicated skill for repeated multi-step tasks.
- You need to refactor long procedures into skill instructions.

## Available scripts

- **`scripts/resolve-editor{{SHELL_EXT}}`** — Resolves target directory path ({{SHELL_NAME}})
- **`scripts/change-control{{SHELL_EXT}}`** — Before/after safety checks with approve/reject ({{SHELL_NAME}})

## Workflow

1. Resolve the target skills directory and derive the skill path:
   ```sh
   skill_file=$({{SHELL_NAME}} scripts/resolve-editor{{SHELL_EXT}} --skills)/<skill-name>/SKILL.md
   # For workspace scope: ... --skills --workspace ...
   ```
   > **Note:** Script outputs the path directly to stdout.

3. If updating an existing `SKILL.md`, back it up first:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase before --file "$skill_file"
   ```
   Skip for new skills.

4. Create or update `SKILL.md` with valid frontmatter and concise procedure steps.
5. Ensure `name` matches the folder name and `description` is keyword-rich.
6. Add `scripts/` or `references/` files as needed; follow [using scripts guide](references/using-scripts.md).
  - If a feature can be written with a shell script, prefer to use a script to increase performance and reproducibility. 

7. Review the diff and approve or reject:
   ```sh
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file" --approve --message "skill: <name> updates"
   {{SHELL_NAME}} scripts/change-control{{SHELL_EXT}} --phase after --file "$skill_file" --reject
   ```

## Safety Rules

- Do not overwrite unrelated skill folders.
- Keep descriptions keyword-rich so agents can discover the skill.
- Follow the [Agent Skills specification](references/specification.md) for `name`, `description`, and structural constraints.
