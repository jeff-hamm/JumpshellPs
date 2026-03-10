"""ai_backends._api — Public-facing API functions.

This module re-exports the functions that form the public contract of the
``ai_backends`` package.  All heavy lifting is delegated to ``_core``.
"""

from __future__ import annotations

from pathlib import Path

from ._core import (
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

from ._backend_config import (
    ENABLED_BACKENDS_KEY,
    BackendConfig,
    get_config,
    load_config,
    reset_config,
)

__all__ = [
    # registry & constants
    "BACKENDS",
    "LLM_TYPES",
    "MIME_MAP",
    "SHELL",
    "_COPILOT_DEFAULT_ALLOW_TOOLS",
    "_COPILOT_DEFAULT_DENY_TOOLS",
    # backend calls
    "call_backend",
    "get_backend_default_model",
    "get_github_token",
    "is_available",
    "list_models",
    "print_model_catalog",
    # file helpers
    "b64_encode",
    "has_images",
    "load_dotenv",
    "mime_type",
    # config
    "ENABLED_BACKENDS_KEY",
    "BackendConfig",
    "get_config",
    "load_config",
    "reset_config",
]
