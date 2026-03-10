---
name: create-jumpskill
description: 'Create a new Jumpshell skill in the workspace skills directory by following the system /create-skill workflow, then rebuild and install the Jumpshell extension and validate the skill is packaged.'
argument-hint: 'Describe the skill outcome, scope, and workflow to package'
---

# Create Jumpshell Skill

Create or update a workspace-scoped jumpshell skill under `skills/` using the same methodology as the system `/create-skill` workflow, then rebuild, install, and validate the extension package.

## When to Use

- User asks to create a new Jumpshell skill for this repository
- User wants skill creation plus extension rebuild/install in one workflow
- User wants to verify the new skill is included in packaged extension assets

## Target Output

- Required location: `skills/<skill-name>/SKILL.md`
- Skill name in frontmatter must match `<skill-name>` directory name
- Skill should follow the same extraction/clarification/iteration pattern used by `/create-skill`

## Workflow

1. Load and follow the system `/create-skill` guidance.
   - Reuse its extraction pattern: workflow steps, decision points, and completion checks.
   - Reuse its clarification pattern when the request is underspecified.

2. Lock scope to this repository's workspace skill path.
   - Do not create the skill in user-profile folders.
   - Always write the skill in `skills/<skill-name>/SKILL.md`.

3. Draft the skill content.
   - Include YAML frontmatter (`name`, `description`, optional `argument-hint`).
   - Include concrete procedure steps, branching logic, and quality gates.
   - Keep discovery keywords in the description so slash-command invocation is reliable.

4. Do a quality pass before packaging.
   - Confirm folder name and frontmatter `name` match exactly.
   - Confirm procedural steps are actionable and testable.
   - Confirm references use relative paths when linking local resources.

5. Rebuild and install the extension.
   - From repository root, run:
       - `pwsh ./extensions/Build.ps1 -Install`
   - This should increment extension version, package VSIX, and install into the active editor.

6. Validate packaging and basic extension health.
   - Confirm `<skill-name>` appears in `extensions/jumpshell/assets/skills-manifest.json`.
   - Confirm skill files are copied under `extensions/jumpshell/assets/skills/<skill-name>/`.
   - Run a TypeScript sanity check:
     - `npm --prefix ./extensions/jumpshell run check`

7. Report result.
   - Summarize created/updated files.
   - Summarize build/install/test outcomes.
   - If any validation fails, provide exact failing step and next fix.

## Clarification Prompts

Ask only if needed:
- What exact outcome should the new skill produce?
- Should this be a quick checklist or a full multi-step workflow?
- Should the skill also include helper scripts/resources, or SKILL.md only?

## Completion Criteria

- Skill file exists at `skills/<skill-name>/SKILL.md`
- Frontmatter is valid and discoverable
- `extensions/Build.ps1 -Install` completes successfully
- Packaged assets include the new skill
- `npm --prefix ./extensions/jumpshell run check` passes