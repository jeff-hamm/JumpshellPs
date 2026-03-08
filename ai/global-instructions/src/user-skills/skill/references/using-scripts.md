# Using Scripts in Skills

Source: https://agentskills.io/skill-creation/using-scripts

## Referencing scripts from `SKILL.md`

Use relative paths from the skill directory root. List available scripts so the agent knows they exist, then instruct it how to run them:

```markdown
## Available scripts

- **`scripts/validate.sh`** — Validates configuration files
- **`scripts/process.py`** — Processes input data

## Workflow

1. Run the validation script:
   ```bash
   bash scripts/validate.sh "$INPUT_FILE"
   ```

2. Process the results:
   ```bash
   python3 scripts/process.py --input results.json
   ```
```

The same relative-path convention applies in `references/*.md` files — script paths in code blocks are relative to the skill directory root.

## Designing scripts for agentic use

### Avoid interactive prompts (hard requirement)

Agents run in non-interactive shells. They cannot respond to TTY prompts, password dialogs, or confirmation menus — a script that blocks on interactive input will hang indefinitely.

Accept all input via command-line flags, environment variables, or stdin:

```
# Bad: hangs waiting for input
$ python scripts/deploy.py
Target environment: _

# Good: clear error with guidance
$ python scripts/deploy.py
Error: --env is required. Options: development, staging, production.
Usage: python scripts/deploy.py --env staging --tag v1.2.3
```

### Document usage with `--help`

`--help` output is the primary way an agent learns your script's interface. Include a brief description, available flags, and usage examples. Keep it concise — it enters the agent's context window.

```
Usage: scripts/process.py [OPTIONS] INPUT_FILE

Process input data and produce a summary report.

Options:
  --format FORMAT    Output format: json, csv, table (default: json)
  --output FILE      Write output to FILE instead of stdout
  --verbose          Print progress to stderr

Examples:
  scripts/process.py data.csv
  scripts/process.py --format csv --output report.csv data.csv
```

### Write helpful error messages

An opaque `Error: invalid input` wastes an agent turn. Say what went wrong, what was expected, and what to try:

```
Error: --format must be one of: json, csv, table.
       Received: "xml"
```

### Use structured output

Prefer JSON, CSV, or TSV over free-form text. Structured formats can be consumed by both the agent and standard tools (`jq`, `cut`, `awk`).

**Send structured data to stdout; diagnostics to stderr.** This lets the agent capture clean, parseable output while still having access to diagnostic information.

```
# Bad: whitespace-aligned — hard to parse programmatically
NAME          STATUS    CREATED
my-service    running   2025-01-15

# Good: structured
{"name": "my-service", "status": "running", "created": "2025-01-15"}
```

## Further design considerations

| Concern | Guidance |
|---------|----------|
| **Idempotency** | "Create if not exists" is safer than "create and fail on duplicate." Agents may retry commands. |
| **Input constraints** | Reject ambiguous input with a clear error. Use enums and closed sets where possible. |
| **Dry-run support** | Add `--dry-run` for destructive or stateful operations so the agent can preview what will happen. |
| **Meaningful exit codes** | Use distinct codes for different failure types and document them in `--help`. |
| **Safe defaults** | Consider `--confirm` / `--force` flags for destructive operations. |
| **Predictable output size** | Default to a summary for large output; support `--offset` for pagination. If output may be large and is not paginatable, require an `--output` flag. |
