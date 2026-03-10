---
layout: default
title: AI Backends
---

# AI Backends Guide

This guide covers the Python AI backend package used by Jumpshell skills and extension workflows.

## Canonical Paths

- Python package source: `src/python/ai-backends`
- Package module: `src/python/ai-backends/ai_backends`
- Package metadata: `src/python/ai-backends/pyproject.toml`

## What It Provides

The `ai-backends` package provides a unified interface for multiple providers:

- `gemini`
- `openai`
- `anthropic`
- `github-api`
- `copilot-cli`
- `cursor`

It also supports quality-tier selection and model discovery/registry caching.

## Install Options

From repository root:

```powershell
pip install -e ./src/python/ai-backends
```

Optional extras:

```powershell
pip install "ai-backends[openai]"
pip install "ai-backends[anthropic]"
pip install "ai-backends[gemini]"
pip install "ai-backends[all]"
```

## Extension Integration

The Jumpshell extension can install/update bundled ai-backends during skill updates when:

- `jumpshell.installAiBackendsOnSkillsInstall = true`

Related settings:

- `jumpshell.aiBackendsPath`
- `jumpshell.skillsPath`

## Quick Usage

```python
import ai_backends

cache = ai_backends.ensure_registry()
backend, model = ai_backends.resolve_quality("normal", cache, vision=False)
text = ai_backends.call_backend(backend, "Summarize this topic", model=model)
```

## Related Docs

- [../extension/VSCode-Extension.md](../extension/VSCode-Extension.md)
- [../pwsh/PowerShell-Module.md](../pwsh/PowerShell-Module.md)
- [../pwsh/Repository-Layout.md](../pwsh/Repository-Layout.md)
