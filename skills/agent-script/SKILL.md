---
name: agent-script
description: 'Create terminal-based AI skill scripts using the ai_backends module. Use for "new AI script", "LLM CLI tool", "terminal AI skill", "python AI script", or any task needing a script that calls LLM APIs. Provides the ai_backends import recipe, quality-tier integration, and argparse patterns.'
argument-hint: 'Describe what the new script should do (e.g., "extract tables from screenshots")'
---

# Agent Script — Create Terminal-Based AI Skills

## When to Use

- User wants a new Python script that calls LLM APIs
- Building a CLI tool that processes content with AI
- Creating a skill that needs backend selection and quality tiers
- Any terminal-based workflow that sends prompts to LLMs

## Prerequisites

This skill depends on:
- **`ai_backends` package** — installed via `pip` by the Jumpshell extension (or `pip install -e src/python/ai-backends` for repo development). Provides backend calling, model discovery, and quality-based model selection.
- **`/agent-customization` skill** — reference for creating the SKILL.md wrapper (frontmatter, structure, conventions)

## The `ai_backends` Module

Lives in this repository at `src/python/ai-backends`. The Jumpshell extension runs `pip install` (regular for VSIX users, editable for developers) so it's available as a normal Python package. It provides a unified interface to 6 AI backends:

| Backend | Type | Cost |
|---------|------|------|
| `gemini` | API | Free tier |
| `openai` | API | Paid |
| `anthropic` | API | Paid |
| `github-api` | API | Free tier |
| `copilot-cli` | CLI | Free (subscription) |
| `cursor` | CLI | Free (subscription) |

Backend cost is declared in `BACKENDS[name]["cost"]` (`"free"` or `"paid"`).

### Import Recipe

`ai_backends` is pip-installed (the Jumpshell extension handles this automatically), so the import is a single line:

```python
import ai_backends
```

Since `ai_backends` is a normal pip-installed package, no special path setup is needed in requirements.txt — just list `ai-backends`.

### Key API

```python
# Call a specific backend with prompt only (text-only)
text = ai_backends.call_backend("gemini", "Summarize this topic")

# Call with context files (images, documents)
text = ai_backends.call_backend("gemini", "Describe this image",
                                context_files=[Path("image.jpg")])

# Call with explicit model
text = ai_backends.call_backend("openai", "Extract text",
                                context_files=[Path("img.jpg")], model="gpt-4o")

# Quality-based selection (auto-picks best backend+model for the tier)
cache = ai_backends.ensure_registry()
backend, model = ai_backends.resolve_quality("normal", cache)
text = ai_backends.call_backend(backend, "Extract text",
                                context_files=[Path("img.jpg")], model=model)

# Vision-aware quality (ensures model can handle images)
backend, model = ai_backends.resolve_quality("normal", cache, vision=True)

# Infer model attributes from name (quality, cost_multiplier, vision)
info = ai_backends.infer_model_info("claude-sonnet-4.5")
# -> {"quality": 92, "cost_multiplier": 1, "vision": True}

# Check backend availability
ok, reason = ai_backends.is_available("gemini")

# List available models for a backend
models = ai_backends.list_models("copilot-cli")

# Load .env file (for API keys)
ai_backends.load_dotenv(Path(__file__).parent / ".env")

# Force-refresh the model registry
ai_backends.refresh_registry(reference_doc_path=Path("refs/models.md"))

# Override quality tier selection (import-level, highest priority)
ai_backends.set_quality_overrides({
    "low":    {"backend": "gemini", "model": "gemini-2.0-flash"},
    "normal": {"backend": "copilot-cli"},
})
# User config at ~/.config/ai_backends/quality.json provides the same
# capability without code changes (lower priority than set_quality_overrides).
```

### Quality Tiers

| Tier | Synonym | Strategy |
|------|---------|----------|
| `low` | `fast` | Best quality among 0x cost models (included/free) |
| `normal` | `default` | Best quality where cost ≤ 1x |
| `high` | `slow` | Best model at any cost (including 3x premium) |

Cost multipliers follow GitHub Copilot's 0x/1x/3x pricing tiers. Model attributes
(quality score, cost multiplier, vision capability) are inferred from model names
via `infer_model_info()` and cached per-backend.

Quality assignments can be overridden at two levels:
- **User config** (`~/.config/ai_backends/quality.json`) — per-machine defaults, no code changes needed
- **Import-level** (`set_quality_overrides({...})`) — highest priority, for scripts that always target a specific backend/model

The registry auto-refreshes when CLI tool versions change or the cache is > 7 days old.

### Module Exports

| Function | Description |
|----------|-------------|
| `call_backend(name, prompt, context_files=None, model=None)` | Call a backend. Returns response text. |
| `is_available(name)` | Check if backend is ready. Returns `(ok, reason)`. |
| `list_models(name)` | List available models. Returns list or None. |
| `ensure_registry(cache_path=None, reference_doc_path=None)` | Load/refresh model cache. |
| `refresh_registry(cache_path=None, reference_doc_path=None)` | Force refresh. |
| `resolve_quality(quality, cache, vision=False)` | Resolve tier to `(backend, model)`. Honours user config and import-level overrides. |
| `set_quality_overrides(overrides)` | Set import-level tier overrides (highest priority). |
| `infer_model_info(model_name)` | Infer quality/cost/vision from model name. |
| `load_dotenv(path)` | Load `.env` file into `os.environ`. |
| `print_model_catalog()` | Print all backends and their models. |
| `has_images(files)` | Check if any files in the list are images. |

Constants: `BACKENDS` (includes `cost` field per backend), `LLM_TYPES`, `MIME_MAP`, `QUALITY_SYNONYMS`

## Procedure

### 1. Create the Skill Directory

Follow the `/agent-customization` skill's conventions:

```
.agents/skills/<skill-name>/
├── SKILL.md              # Required: frontmatter + instructions
├── scripts/
│   ├── <script>.py       # The Python script
│   ├── run.ps1           # PowerShell runner (Windows)
│   ├── run.sh            # Bash runner (macOS/Linux)
│   └── requirements.txt  # pip dependencies
└── references/           # Optional: additional docs
    └── available-models.md  # Optional: auto-generated model reference
```

### 2. Write the Script

Use this template as a starting point:

```python
"""<Description of what the script does>."""

import os
import sys
import argparse
import logging
from pathlib import Path

import ai_backends

log = logging.getLogger(__name__)
SCRIPT_DIR = Path(__file__).parent
_REFERENCE_DOC_PATH = SCRIPT_DIR / ".." / "references" / "available-models.md"

# Load API keys from .env if present
ai_backends.load_dotenv(SCRIPT_DIR / ".env")

# ── Your prompt ───────────────────────────────────────────────────────────────
PROMPT = """\
<Your task-specific prompt here>
"""

def process_file(file_path: Path, backend: str, model: str) -> str:
    """Process a single file."""
    return ai_backends.call_backend(backend, PROMPT,
                                    context_files=[file_path], model=model)

def main() -> None:
    parser = argparse.ArgumentParser(description="<Description>")
    parser.add_argument("paths", nargs="*", metavar="PATH",
                        help="Image files or directories")
    parser.add_argument("-q", "--quality", "--tier",
                        choices=["low", "fast", "normal", "default", "high", "slow"],
                        default="normal", dest="quality",
                        help="Quality tier (default: normal)")
    parser.add_argument("-b", "--backend", choices=list(ai_backends.BACKENDS),
                        default=None, help="Explicit backend override")
    parser.add_argument("-m", "--model", default=None,
                        help="Explicit model override")
    parser.add_argument("--refresh-models", action="store_true",
                        help="Force-refresh model registry and exit")
    parser.add_argument("-v", "--verbose", action="count", default=0)
    args = parser.parse_args()

    logging.basicConfig(
        level=[logging.WARNING, logging.INFO, logging.DEBUG][min(args.verbose, 2)],
        format="%(levelname)s [%(name)s] %(message)s",
    )

    if args.refresh_models:
        ai_backends.refresh_registry(reference_doc_path=_REFERENCE_DOC_PATH)
        return

    cache = ai_backends.ensure_registry(reference_doc_path=_REFERENCE_DOC_PATH)

    if args.backend:
        backend, model = args.backend, args.model or ai_backends.BACKENDS[args.backend]["default_model"]
    else:
        backend, model = ai_backends.resolve_quality(args.quality, cache)

    # Gather input paths...
    for p_str in (args.paths or ["."]):
        p = Path(p_str)
        files = sorted(p.iterdir()) if p.is_dir() else [p]
        for f in files:
            result = process_file(f, backend, model)
            print(result)

if __name__ == "__main__":
    main()
```

### 3. Add `requirements.txt`

Always create `scripts/requirements.txt`. Use the git URL so the package is
resolvable even without the Jumpshell extension (pip skips the fetch if
`ai-backends` is already installed):

```
# requirements.txt
# Installed automatically by the Jumpshell extension.
# The git URL is a fallback for standalone use.
ai-backends @ git+https://github.com/jeff-hamm/jumpshell.git#subdirectory=src/python/ai-backends

# Add any backend-specific extras:
# openai
# anthropic
# google-generativeai
```

If the script genuinely needs no extras beyond `ai_backends`, a one-liner
still documents the dependency:

```
# requirements.txt
ai-backends @ git+https://github.com/jeff-hamm/jumpshell.git#subdirectory=src/python/ai-backends
```

### 4. Add `run.ps1` and `run.sh`

Always create both runner scripts. They handle path boilerplate so users never need to
remember how to invoke the script:

**`run.ps1`** (PowerShell, Windows):
```powershell
<#
.SYNOPSIS
    Run <script>.py — <one-line description>
.EXAMPLE
    .\run.ps1 path\to\file.jpg
    .\run.ps1 -Quality high path\to\dir\
#>
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Args
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '<script>.py'

if (-not (Test-Path $script)) {
    Write-Error "Script not found: $script"; exit 1
}

python $script @Args
```

**`run.sh`** (Bash, macOS/Linux):
```bash
#!/usr/bin/env bash
# Run <script>.py — <one-line description>
# Usage: ./run.sh [options] [paths...]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec python "$DIR/<script>.py" "$@"
```

Make `run.sh` executable (`chmod +x run.sh`) and remind users in the SKILL.md.

### 5. Write the SKILL.md

Follow the `/agent-customization` skill for frontmatter rules. Key points:

- `name` must match the folder name
- `description` must contain trigger keywords
- Reference the script with `[./scripts/<script>.py](./scripts/<script>.py)`
- Mention the `ai_backends` dependency and `--quality` flag in the procedure
- Include a note that model names change frequently and `--quality` is preferred over specific `-b`/`-m` combinations

### 6. Environment Setup

Install from `requirements.txt`:

```powershell
pip install -r scripts/requirements.txt
```

For local development of `ai_backends` itself, use an editable install from the repo root:

```powershell
pip install -e src/python/ai-backends
```

Common per-backend extras:

```powershell
pip install openai               # openai backend
pip install anthropic            # anthropic backend
pip install google-generativeai  # gemini backend
pip install easyocr              # easyocr (+ PyTorch, first run downloads ~100 MB)
```

## Example Skills Using `ai_backends`

- **`/ocr-scan`** — Transcribes handwritten documents to Markdown. Full reference implementation at [../ocr-scan/scripts/ocr_scan.py](../ocr-scan/scripts/ocr_scan.py).

## Notes

- Always create `run.ps1`, `run.sh`, and `requirements.txt` in `scripts/` alongside the Python file, even for simple scripts.
- `ai_backends` lives at `src/python/ai-backends` in this repo. The Jumpshell extension pip-installs it into site-packages automatically. No `sys.path` manipulation needed.
- Skills should reference it in `requirements.txt` as `ai-backends @ git+https://github.com/jeff-hamm/jumpshell.git#subdirectory=src/python/ai-backends` so standalone use works without the extension.
- Model availability changes frequently. Always prefer `--quality`/`--tier` tiers over hardcoded backend/model names.
- The model registry cache lives inside the installed package at `ai_backends/.models_cache.json` and is shared across all consumers.
- Each skill can optionally write its own `references/available-models.md` by passing `reference_doc_path` to `ensure_registry()` or `refresh_registry()`.
- All backends use the same calling convention: `call_backend(name, prompt, context_files, model)` — the module handles encoding, API differences, and CLI wrapping internally.
- Model knowledge is inferred dynamically from model names using pattern rules (not a static lookup table). Unknown models get sensible defaults.
- Cost multipliers (0x/1x/3x) match GitHub Copilot's pricing tiers and drive quality-tier selection.
