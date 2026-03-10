# ai-backends

Multi-provider AI backend abstraction for LLMs.

Provides a unified interface to call AI models across Gemini, OpenAI, Anthropic,
GitHub Models API, Copilot CLI, and Cursor. Includes quality-based model selection
with vision-awareness that auto-discovers available models and assigns them to
quality tiers.

## Install

```bash
# Editable install from the JumpshellPs repo root
pip install -e src/python/ai-backends

# Or from this package directory
pip install -e .

# Extension-managed layout (installed by JumpShell extension)
pip install -e ~/.agents/src/python/ai-backends

# Optional: install directly from GitHub
pip install git+https://github.com/jeff-hamm/ai-backends
```

## Optional backend dependencies

```bash
pip install "ai-backends[openai]"
pip install "ai-backends[anthropic]"
pip install "ai-backends[gemini]"
pip install "ai-backends[all]"
```

## Quick start

```python
import ai_backends

# Text-only
text = ai_backends.call_backend("copilot-cli", "Summarize this topic")

# With context files
text = ai_backends.call_backend("gemini", "Describe this",
                                context_files=["image.jpg"])

# Quality-based selection
cache = ai_backends.ensure_registry()
backend, model = ai_backends.resolve_quality("normal", cache, vision=True)
text = ai_backends.call_backend(backend, "OCR this", context_files=["scan.jpg"],
                                model=model)
```
