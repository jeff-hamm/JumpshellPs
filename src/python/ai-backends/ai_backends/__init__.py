"""ai_backends — Multi-provider AI backend abstraction for LLMs.

Provides a unified interface to call AI models across Gemini, OpenAI, Anthropic,
GitHub Models API, Copilot CLI, and Cursor. Includes quality-based model selection
with vision-awareness that auto-discovers available models and assigns them to
quality tiers.

Backends:
  API : gemini, openai, anthropic, github-api
  CLI : copilot-cli, cursor

Import from a skill script (standard layout: skills/<name>/scripts/script.py):

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "common"))
    import ai_backends

Text-only usage:

    text = ai_backends.call_backend("gemini", "Summarize this topic")

With context files (images, documents):

    text = ai_backends.call_backend("gemini", "Describe this",
                                    context_files=[Path("img.jpg")])

Quality-based usage (auto-selects best backend+model):

    cache = ai_backends.ensure_registry()
    backend, model = ai_backends.resolve_quality("normal", cache)
    text = ai_backends.call_backend(backend, "Describe this", model=model)

Vision-aware quality (ensures model can handle images):

    cache = ai_backends.ensure_registry()
    backend, model = ai_backends.resolve_quality("normal", cache, vision=True)
    text = ai_backends.call_backend(backend, "OCR this",
                                    context_files=[Path("scan.jpg")], model=model)
"""

__version__ = "2.1.0"

from ._core import (  # noqa: F401
    BACKENDS,
    LLM_TYPES,
    MIME_MAP,
    SHELL,
    _COPILOT_DEFAULT_ALLOW_TOOLS,
    _COPILOT_DEFAULT_DENY_TOOLS,
    b64_encode,
    call_backend,
    get_backend_default_model,
    get_github_token,
    has_images,
    is_available,
    list_models,
    load_dotenv,
    mime_type,
    print_model_catalog,
)

from ._models import (  # noqa: F401
    QUALITY_SYNONYMS,
    build_default_model_selection_prompt,
    build_model_rules_generation_prompt,
    cache_is_stale,
    compute_quality_assignments,
    discover_all_models,
    ensure_registry,
    get_cli_version,
    get_model_rules_by_backend,
    infer_model_info,
    load_cache,
    match_model_knowledge,
    refresh_backend_default_models,
    refresh_model_rules,
    refresh_registry,
    resolve_backend_default_model,
    resolve_quality,
    set_quality_overrides,
    write_reference_doc,
)

from ._config import (  # noqa: F401
    DEFAULT_MODEL_SELECTION_TEMPLATE_PATH,
    GENERATION_INSTRUCTION,
    MODEL_RULES_TEMPLATE_PATH,
)
