"""ai_backends._backend_config — Centralised credential and URL resolution.

Provides a singleton ``BackendConfig`` that resolves credentials from either
a loaded JSON file or ``os.getenv`` (the default).  Every ``os.getenv`` call
that previously lived in ``_core.py`` is routed through :func:`get_config`.

Public helpers
--------------
* ``get_config()``  — return the current singleton
* ``load_config(path)``  — deserialise a JSON config file and install it
* ``reset_config()``  — revert to the env-var default
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

log = logging.getLogger("ai_backends")


# Reserved config key for the list of explicitly-enabled backend names.
ENABLED_BACKENDS_KEY = "enabled_backends"


class BackendConfig:
    """Credential / URL store.  Falls through to ``os.getenv`` for any key
    not explicitly set in a loaded config file."""

    def __init__(self, data: dict[str, Any] | None = None) -> None:
        self._data: dict[str, Any] = data or {}
        # Extract the enabled-backends list (may be absent / None).
        raw = self._data.pop(ENABLED_BACKENDS_KEY, None)
        self._enabled: list[str] | None = list(raw) if isinstance(raw, (list, tuple)) else None

    # ── generic access ────────────────────────────────────────────────────
    def get(self, key: str, default: str | None = None) -> str | None:
        """Look up *key* in loaded config, then ``os.environ``."""
        val = self._data.get(key)
        if val is not None:
            return str(val)
        return os.getenv(key, default)

    # ── enabled backends ──────────────────────────────────────────────────
    def is_enabled(self, backend: str) -> bool:
        """Return whether *backend* was explicitly enabled during configure.

        If no ``enabled_backends`` list was stored (e.g. env-var-only mode),
        returns ``True`` so that legacy / env-only setups are not blocked.
        """
        if self._enabled is None:
            return True
        return backend in self._enabled

    @property
    def enabled_backends(self) -> list[str] | None:
        """The explicit list of enabled backends, or ``None`` if not set."""
        return list(self._enabled) if self._enabled is not None else None

    # ── per-backend convenience properties ────────────────────────────────
    @property
    def gemini_api_key(self) -> str | None:
        return self.get("GEMINI_API_KEY") or self.get("GOOGLE_API_KEY")

    @property
    def openai_api_key(self) -> str | None:
        return self.get("OPENAI_API_KEY")

    @property
    def anthropic_api_key(self) -> str | None:
        return self.get("ANTHROPIC_API_KEY")

    @property
    def github_token(self) -> str | None:
        return self.get("GITHUB_TOKEN")

    @property
    def github_models_base_url(self) -> str:
        return self.get("GITHUB_MODELS_BASE_URL") or "https://models.github.ai/inference"

    # ── serialisation ─────────────────────────────────────────────────────
    def to_dict(self) -> dict[str, Any]:
        """Return only the explicitly-loaded keys (no env vars)."""
        d: dict[str, Any] = dict(self._data)
        if self._enabled is not None:
            d[ENABLED_BACKENDS_KEY] = list(self._enabled)
        return d

    def to_env_lines(self) -> list[str]:
        """Render as ``.env`` compatible lines."""
        lines: list[str] = []
        for k, v in sorted(self._data.items()):
            safe = str(v).replace('"', '\\"')
            lines.append(f'{k}="{safe}"')
        if self._enabled is not None:
            joined = ",".join(self._enabled)
            lines.append(f'{ENABLED_BACKENDS_KEY}="{joined}"')
        return lines


# ── singleton ─────────────────────────────────────────────────────────────────

_config_instance: BackendConfig = BackendConfig()


def get_config() -> BackendConfig:
    """Return the active backend configuration singleton."""
    return _config_instance


def load_config(path: str | Path) -> BackendConfig:
    """Load a JSON configuration file and install it as the active config.

    The file must be a flat JSON object whose keys match the environment
    variable names used by each backend (e.g. ``GEMINI_API_KEY``).
    """
    global _config_instance
    p = Path(path)
    raw = p.read_text(encoding="utf-8")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object in {p}, got {type(data).__name__}")
    _config_instance = BackendConfig(data)
    log.info("Loaded backend config from %s (%d keys)", p, len(data))
    return _config_instance


def reset_config() -> None:
    """Revert to the default env-var–only configuration."""
    global _config_instance
    _config_instance = BackendConfig()
