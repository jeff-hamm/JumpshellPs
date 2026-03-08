# Agent Skills Specification

Source: https://agentskills.io/specification

## Directory structure

A skill is a directory containing at minimum a `SKILL.md` file:

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable scripts agents can run
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: static templates, data, images
```

## SKILL.md format

### Frontmatter (required)

```yaml
---
name: skill-name
description: A description of what this skill does and when to use it.
---
```

With optional fields:

```yaml
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents.
license: Apache-2.0
compatibility: Requires git and Node.js 18+
metadata:
  author: example-org
  version: "1.0"
allowed-tools: Bash(git:*) Read Write
---
```

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Max 64 chars. Lowercase letters, numbers, hyphens only. Must not start or end with a hyphen. Must match directory name. |
| `description` | Yes | Max 1024 chars. Non-empty. Describes what the skill does and when to use it. |
| `license` | No | License name or reference to a bundled license file. |
| `compatibility` | No | Max 500 chars. Environment requirements: intended product, system packages, network access, etc. |
| `metadata` | No | Arbitrary key-value mapping for additional metadata. |
| `allowed-tools` | No | Space-delimited pre-approved tools (experimental). |

#### `name` field rules

- 1–64 characters
- Only unicode lowercase alphanumeric + hyphens
- Must not start or end with `-`
- Must not contain consecutive hyphens (`--`)
- **Must match the parent directory name**

#### `description` field guidance

- Describe both what the skill does and when to use it
- Include keywords that help agents identify relevant tasks

### Body content

No format restrictions — write whatever helps agents perform the task. Recommended sections: step-by-step workflow, examples, edge cases.

Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

## Optional directories

### `scripts/`

Executable scripts the agent can run. Scripts should:
- Be self-contained or clearly document dependencies
- Include helpful `--help` output
- Handle edge cases gracefully
- Accept all input via flags (never interactive prompts)
- Output structured data (JSON/CSV) to stdout; diagnostics to stderr

Supported languages depend on the agent implementation. Common options: Python, Bash, PowerShell, JavaScript.

### `references/`

Additional documentation loaded on demand:
- `REFERENCE.md` — Detailed technical reference
- `FORMS.md` — Form templates or structured data formats
- Domain-specific files (`finance.md`, `legal.md`, etc.)

Keep individual reference files focused. Agents load these on demand, so smaller files mean less context use.

### `assets/`

Static resources: templates, images, data files (lookup tables, schemas).

## File references

Use relative paths from the skill directory root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

Keep file references one level deep from `SKILL.md`. Avoid deeply nested reference chains.

## Progressive disclosure

1. **Metadata (~100 tokens):** `name` and `description` loaded at startup for all skills.
2. **Instructions (< 5000 tokens recommended):** Full `SKILL.md` body loaded when skill is activated.
3. **Resources (as needed):** Files in `scripts/`, `references/`, `assets/` loaded only when required.
