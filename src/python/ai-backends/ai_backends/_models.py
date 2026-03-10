"""ai_backends._models — Pattern-based model inference, quality tiers, and registry cache."""

import json
import re
import subprocess
import logging
import tempfile
from pathlib import Path
from datetime import datetime

from . import _config
from . import _core

log = logging.getLogger("ai_backends")

# Flat list of (pattern, quality, cost, vision, reasoning) loaded from cache.
# Populated by _set_model_rules_from_available().
_MODEL_RULES: list[tuple[str, int, float, bool, bool]] = []


def _set_model_rules_from_available(
    available_by_backend: dict[str, list[dict]],
) -> None:
    """Rebuild the flat _MODEL_RULES lookup from available_models dict."""
    global _MODEL_RULES
    rules: list[tuple[str, int, float, bool, bool]] = []
    for backend in list(_core.BACKENDS.keys()) + sorted(
        b for b in available_by_backend if b not in _core.BACKENDS
    ):
        for m in available_by_backend.get(backend, []):
            if not isinstance(m, dict):
                continue
            name = str(m.get("name", "")).strip()
            if not name:
                continue
            try:
                pattern = f"^{re.escape(name)}$"
                quality = max(0, min(100, int(m.get("quality", _config.UNKNOWN_MODEL_DEFAULT_QUALITY))))
                cost = max(0.0, float(m.get("cost_multiplier", _config.UNKNOWN_MODEL_DEFAULT_COST_MULTIPLIER)))
                vision = bool(m.get("vision", _config.UNKNOWN_MODEL_DEFAULT_VISION))
                reasoning = bool(m.get("reasoning", _config.UNKNOWN_MODEL_DEFAULT_REASONING))
                rules.append((pattern, quality, cost, vision, reasoning))
            except (TypeError, ValueError):
                continue
    _MODEL_RULES = rules


def _coerce_float(raw_value: object) -> float | None:
    if raw_value is None:
        return None
    if isinstance(raw_value, (int, float)):
        return float(raw_value)
    if isinstance(raw_value, str):
        cleaned = raw_value.strip().replace("$", "").replace(",", "")
        if not cleaned or cleaned.lower() in {"none", "null", "n/a", "na"}:
            return None
        numeric_match = re.search(r"-?\d+(?:\.\d+)?", cleaned)
        if numeric_match:
            try:
                return float(numeric_match.group(0))
            except ValueError:
                return None
        try:
            return float(cleaned)
        except ValueError:
            return None
    return None


def _coerce_int(raw_value: object) -> int | None:
    parsed = _coerce_float(raw_value)
    if parsed is None:
        return None
    return int(round(parsed))


def _coerce_bool(raw_value: object) -> bool | None:
    if isinstance(raw_value, bool):
        return raw_value
    if isinstance(raw_value, (int, float)):
        return bool(raw_value)
    if isinstance(raw_value, str):
        normalized = raw_value.strip().lower()
        if normalized in {"true", "1", "yes", "y", "on"}:
            return True
        if normalized in {"false", "0", "no", "n", "off"}:
            return False
    return None


def _first_float(values: list[object]) -> float | None:
    for value in values:
        parsed = _coerce_float(value)
        if parsed is not None:
            return parsed
    return None


def _estimate_cost_multiplier(
    input_price_per_1m: float | None,
    output_price_per_1m: float | None,
) -> int | None:
    prices = [
        p for p in (input_price_per_1m, output_price_per_1m)
        if p is not None and p >= 0
    ]
    if not prices:
        return None
    average_price = sum(prices) / len(prices)
    if average_price <= _config.PRICE_BUCKET_FREE_MAX_USD_PER_1M:
        return 0
    if average_price <= _config.PRICE_BUCKET_STANDARD_MAX_USD_PER_1M:
        return 1
    return 3


def _normalize_rule_entry(raw_rule: object) -> tuple[str, int, float, bool, bool] | None:
    pattern: str | None = None
    quality: int | None = None
    cost: float | None = None
    vision: bool | None = None
    reasoning: bool | None = None

    if isinstance(raw_rule, dict):
        model_name = str(raw_rule.get("model", "")).strip()
        if model_name:
            pattern = f"^{re.escape(model_name)}$"
        else:
            # Legacy support for prior schema that supplied regex patterns directly.
            pattern = str(raw_rule.get("pattern", "")).strip()

        if "quality" in raw_rule:
            quality = _coerce_int(raw_rule.get("quality"))

        if "cost_multiplier" in raw_rule:
            cost = _coerce_float(raw_rule.get("cost_multiplier"))

        pricing = raw_rule.get("pricing")
        pricing_input = None
        pricing_output = None
        if isinstance(pricing, dict):
            pricing_input = _first_float([
                pricing.get("input_usd_per_1m"),
                pricing.get("input_per_1m_usd"),
                pricing.get("input_cost_per_million"),
            ])
            pricing_output = _first_float([
                pricing.get("output_usd_per_1m"),
                pricing.get("output_per_1m_usd"),
                pricing.get("output_cost_per_million"),
            ])

        if pricing_input is None:
            pricing_input = _first_float([
                raw_rule.get("input_usd_per_1m"),
                raw_rule.get("input_per_1m_usd"),
                raw_rule.get("input_cost_per_million"),
            ])
        if pricing_output is None:
            pricing_output = _first_float([
                raw_rule.get("output_usd_per_1m"),
                raw_rule.get("output_per_1m_usd"),
                raw_rule.get("output_cost_per_million"),
            ])

        if cost is None:
            cost = _estimate_cost_multiplier(pricing_input, pricing_output)

        if "vision" in raw_rule:
            vision = _coerce_bool(raw_rule.get("vision"))

        if "reasoning" in raw_rule:
            reasoning = _coerce_bool(raw_rule.get("reasoning"))
    elif isinstance(raw_rule, (list, tuple)) and len(raw_rule) >= 4:
        pattern = str(raw_rule[0]).strip()
        quality = int(raw_rule[1])
        cost = float(raw_rule[2])
        vision = bool(raw_rule[3])
        reasoning = bool(raw_rule[4]) if len(raw_rule) >= 5 else None
    else:
        return None

    if quality is None:
        quality = _config.UNKNOWN_MODEL_DEFAULT_QUALITY
    if cost is None:
        cost = float(_config.UNKNOWN_MODEL_DEFAULT_COST_MULTIPLIER)
    if vision is None:
        vision = _config.UNKNOWN_MODEL_DEFAULT_VISION
    if reasoning is None:
        reasoning = _config.UNKNOWN_MODEL_DEFAULT_REASONING

    if not pattern:
        return None

    try:
        re.compile(pattern)
    except re.error:
        return None

    quality = max(0, min(100, quality))
    cost = max(0.0, cost)

    return (pattern, quality, cost, vision, reasoning)


def _normalize_model_rules_by_backend(
    raw_rules: object,
) -> dict[str, list[tuple[str, int, float, bool, bool]]]:
    normalized: dict[str, list[tuple[str, int, float, bool, bool]]] = {}
    if not isinstance(raw_rules, dict):
        return normalized

    for backend, backend_rules in raw_rules.items():
        if not isinstance(backend, str) or not isinstance(backend_rules, list):
            continue
        parsed_rules: list[tuple[str, int, float, bool, bool]] = []
        for rule in backend_rules:
            parsed_rule = _normalize_rule_entry(rule)
            if parsed_rule:
                parsed_rules.append(parsed_rule)
        if parsed_rules:
            normalized[backend] = parsed_rules

    return normalized


def _set_model_rules_by_backend(raw_rules: object) -> None:
    # Legacy shim: called by old load_cache paths; now a no-op since rules
    # live in available_models. We keep the name to avoid breaking callers
    # until we delete it in a follow-up.
    pass


def _extract_json_payload(text: str) -> object | None:
    content = text.strip()
    if not content:
        return None

    fenced = re.search(r"```(?:json)?\s*(.*?)```", content, re.IGNORECASE | re.DOTALL)
    if fenced:
        content = fenced.group(1).strip()

    for candidate in (content,):
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    for opener, closer in (("{", "}"), ("[", "]")):
        start = content.find(opener)
        end = content.rfind(closer)
        if start == -1 or end == -1 or end <= start:
            continue
        candidate = content[start:end + 1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue

    return None


def _extract_model_names(model_entries: object) -> list[str]:
    if not isinstance(model_entries, list):
        return []
    names: list[str] = []
    for entry in model_entries:
        if isinstance(entry, str):
            name = entry.strip()
        elif isinstance(entry, dict):
            name = str(entry.get("name", "")).strip()
        else:
            name = ""
        if name and name not in names:
            names.append(name)
    return names


def _enrich_model_names(model_names: list[str]) -> list[dict]:
    enriched: list[dict] = []
    for model_name in model_names:
        info = infer_model_info(model_name)
        if info:
            enriched.append({"name": model_name, **info})
        else:
            enriched.append(
                {
                    "name": model_name,
                    "quality": _config.UNKNOWN_MODEL_DEFAULT_QUALITY,
                    "cost_multiplier": _config.UNKNOWN_MODEL_DEFAULT_COST_MULTIPLIER,
                    "vision": _config.UNKNOWN_MODEL_DEFAULT_VISION,
                    "reasoning": _config.UNKNOWN_MODEL_DEFAULT_REASONING,
                }
            )
    return enriched


def _bootstrap_generation_model(backend_name: str, model_names: list[str]) -> str | None:
    if not model_names:
        if backend_name == "cursor":
            return _config.CURSOR_BOOTSTRAP_MODEL
        return None
    # Prefer the low-tier reasoning model from the current cache if available.
    try:
        cache = load_cache()
        if cache:
            backend_data = cache.get(backend_name, {})
            reasoning_assignments = backend_data.get("quality", {}).get("reasoning", {})
            low_reasoning = reasoning_assignments.get("low", {})
            if low_reasoning.get("backend") == backend_name:
                candidate = low_reasoning.get("model")
                if candidate and candidate in model_names:
                    return candidate
    except Exception:
        pass
    if backend_name == "copilot-cli":
        for preferred_model in _config.COPILOT_GENERATION_MODEL_CANDIDATES:
            if preferred_model in model_names:
                return preferred_model
    if backend_name == "cursor" and _config.CURSOR_BOOTSTRAP_MODEL in model_names:
        return _config.CURSOR_BOOTSTRAP_MODEL
    return model_names[0]


def _fill_template(template_path: Path, replacements: dict[str, str]) -> str:
    """Read a .prompt.md template and perform placeholder substitution."""
    text = template_path.read_text(encoding="utf-8")
    for key, value in replacements.items():
        text = text.replace(f"{{{key}}}", value)
    return text


def _write_filled_template(template_path: Path, replacements: dict[str, str]) -> Path:
    """Fill a template into an isolated temp directory. Caller must cleanup.

    Returns the path to the filled file. The file sits inside a fresh
    subdirectory so that CLI backends (copilot --add-path) only index
    the single file, not the entire system temp directory.
    """
    filled = _fill_template(template_path, replacements)
    tmp_dir = Path(tempfile.mkdtemp(prefix="ai_backends_"))
    out_path = tmp_dir / template_path.name
    out_path.write_text(filled, encoding="utf-8")
    return out_path


def build_model_rules_generation_prompt(backend_name: str, model_names: list[str]) -> str:
    provider_hint = _config.BACKEND_PROVIDER_HINTS.get(backend_name, backend_name)
    models_json = json.dumps(model_names, indent=2)
    return _fill_template(
        _config.MODEL_RULES_TEMPLATE_PATH,
        {"provider_hint": provider_hint, "models_json": models_json},
    )


def build_default_model_selection_prompt(backend_name: str, model_names: list[str]) -> str:
    provider_hint = _config.BACKEND_PROVIDER_HINTS.get(backend_name, backend_name)
    models_json = json.dumps(model_names, indent=2)
    return _fill_template(
        _config.DEFAULT_MODEL_SELECTION_TEMPLATE_PATH,
        {"provider_hint": provider_hint, "models_json": models_json},
    )


def _generate_model_rules_for_backend(
    backend_name: str,
    model_names: list[str],
) -> list[tuple[str, int, float, bool]]:
    generation_model = _bootstrap_generation_model(backend_name, model_names)
    if not generation_model:
        return []

    provider_hint = _config.BACKEND_PROVIDER_HINTS.get(backend_name, backend_name)
    models_json = json.dumps(model_names, indent=2)
    tmp_path = _write_filled_template(
        _config.MODEL_RULES_TEMPLATE_PATH,
        {"provider_hint": provider_hint, "models_json": models_json},
    )
    try:
        instruction = _config.GENERATION_INSTRUCTION.format(
            filename=tmp_path.name,
        )
        response_text = _core.call_backend(
            backend_name,
            instruction,
            context_files=[tmp_path],
            model=generation_model,
            allow_tools=["read", "web_fetch"],
            deny_tools=["shell", "write", "edit"],
        )
    except Exception as exc:
        log.warning(
            "Model-rule generation for %s via %s failed: %s",
            backend_name,
            generation_model,
            exc,
        )
        return []
    finally:
        import shutil
        shutil.rmtree(tmp_path.parent, ignore_errors=True)

    payload = _extract_json_payload(response_text)
    if not isinstance(payload, dict):
        log.warning(
            "Model-rule generation for %s via %s returned non-object payload: %s",
            backend_name,
            generation_model,
            type(payload).__name__,
        )
        return []

    raw_rules = payload.get("rules")
    if not isinstance(raw_rules, list):
        log.warning(
            "Model-rule generation for %s via %s returned no rules list",
            backend_name,
            generation_model,
        )
        return []

    generated_rules: list[tuple[str, int, float, bool]] = []
    for raw_rule in raw_rules:
        parsed_rule = _normalize_rule_entry(raw_rule)
        if parsed_rule:
            generated_rules.append(parsed_rule)

    if generated_rules:
        log.info(
            "Model-rule generation for %s via %s produced %d usable rules",
            backend_name,
            generation_model,
            len(generated_rules),
        )
        return generated_rules

    log.warning(
        "Model-rule generation for %s via %s produced zero usable rules",
        backend_name,
        generation_model,
    )
    return []


def _generate_default_model_for_backend(
    backend_name: str,
    model_names: list[str],
) -> str | None:
    generation_model = _bootstrap_generation_model(backend_name, model_names)
    if not generation_model:
        return None

    provider_hint = _config.BACKEND_PROVIDER_HINTS.get(backend_name, backend_name)
    models_json = json.dumps(model_names, indent=2)
    tmp_path = _write_filled_template(
        _config.DEFAULT_MODEL_SELECTION_TEMPLATE_PATH,
        {"provider_hint": provider_hint, "models_json": models_json},
    )
    try:
        instruction = _config.GENERATION_INSTRUCTION.format(
            filename=tmp_path.name,
        )
        response_text = _core.call_backend(
            backend_name,
            instruction,
            context_files=[tmp_path],
            model=generation_model,
            allow_tools=["read", "web_fetch"],
            deny_tools=["shell", "write", "edit"],
        )
    except Exception as exc:
        log.warning(
            "Default-model generation for %s via %s failed: %s",
            backend_name,
            generation_model,
            exc,
        )
        return None
    finally:
        import shutil
        shutil.rmtree(tmp_path.parent, ignore_errors=True)

    payload = _extract_json_payload(response_text)
    if isinstance(payload, dict):
        candidate = str(payload.get("default_model", "")).strip()
        if candidate in model_names:
            return candidate
    if isinstance(payload, str) and payload in model_names:
        return payload

    return None


def infer_model_info(model_name: str) -> dict | None:
    """Infer model attributes from its name using pattern rules.

    Returns ``{"quality": int, "cost_multiplier": int, "vision": bool}``
    where cost_multiplier uses GitHub Copilot's 0x/1x/3x scale,
    or ``None`` if the model doesn't match any known pattern.
    """
    for pattern, quality, cost, vision, reasoning in _MODEL_RULES:
        if re.search(pattern, model_name, re.IGNORECASE):
            return {"quality": quality, "cost_multiplier": cost, "vision": vision, "reasoning": reasoning}
    return None

QUALITY_SYNONYMS = _config.QUALITY_SYNONYMS

# ── Quality overrides ─────────────────────────────────────────────────────────
#
# Two layers of override, applied on top of cache-computed assignments:
#   1. User config  (~/.config/ai_backends/quality.json) — lowest priority
#   2. Import-level (set_quality_overrides())             — highest priority
#
# Each tier entry is a partial dict: {"backend": ..., "model": ...}.
# Omitting a key keeps the cache's value for that key.
#
# User config example:
#   {
#     "low":    {"backend": "gemini", "model": "gemini-2.0-flash"},
#     "normal": {"backend": "copilot-cli"}
#   }

_USER_CONFIG_PATH = _config.USER_QUALITY_CONFIG_PATH
_user_config_cache: dict | None = None
_user_config_loaded: bool = False

_quality_overrides: dict[str, dict] = {}


def set_quality_overrides(overrides: dict[str, dict]) -> None:
    """Set import-level quality tier overrides (highest priority).

    Each key is a tier name ("low", "normal", "high") and each value is a
    partial assignment dict with optional "backend" and/or "model" keys.
    These take precedence over both the user config and the cache.

    Example::

        ai_backends.set_quality_overrides({
            "low":    {"backend": "gemini", "model": "gemini-2.0-flash"},
            "normal": {"backend": "copilot-cli"},
        })
    """
    global _quality_overrides
    _quality_overrides = {k: dict(v) for k, v in overrides.items()}


def _load_user_config() -> dict:
    """Load user quality config from ~/.config/ai_backends/quality.json (cached)."""
    global _user_config_cache, _user_config_loaded
    if _user_config_loaded:
        return _user_config_cache or {}
    _user_config_loaded = True
    if _USER_CONFIG_PATH.exists():
        try:
            _user_config_cache = json.loads(
                _USER_CONFIG_PATH.read_text(encoding="utf-8")
            )
            log.debug("Loaded user quality config from %s", _USER_CONFIG_PATH)
        except Exception as exc:
            log.warning("Could not load %s: %s", _USER_CONFIG_PATH, exc)
            _user_config_cache = {}
    return _user_config_cache or {}


def get_cli_version(cmd: str) -> str | None:
    """Get version string for a CLI tool."""
    try:
        command = _core._prepare_command([cmd, "--version"])
        r = subprocess.run(
            command,
            capture_output=True, text=True, timeout=15, shell=_core.SHELL,
        )
        return r.stdout.strip() if r.returncode == 0 else None
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def match_model_knowledge(model_name: str) -> tuple[int, float, bool, bool] | None:
    """Match a model against known patterns.

    Returns (quality_score, cost_multiplier, vision_capable, reasoning) or None.
    """
    info = infer_model_info(model_name)
    if info is None:
        return None
    return info["quality"], info["cost_multiplier"], info["vision"], info["reasoning"]


def get_model_rules_by_backend() -> dict[str, list[tuple[str, int, float, bool, bool]]]:
    """Backwards-compat stub — rules now live in available_models. Returns {}."""
    return {}


def load_cache(cache_path: Path | None = None) -> dict | None:
    """Load models cache. Returns None if missing or corrupt."""
    path = cache_path or _config.DEFAULT_CACHE_PATH
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("format_version") != _config.CACHE_FORMAT_VERSION:
            return None
        # Rebuild _MODEL_RULES from available_models stored per-backend.
        available_by_backend: dict[str, list[dict]] = {}
        for key, val in data.items():
            if isinstance(val, dict) and "available_models" in val:
                models = val["available_models"]
                if isinstance(models, list):
                    available_by_backend[key] = models
        _set_model_rules_from_available(available_by_backend)
        data.setdefault("backend_default_models", dict(_config.DEFAULT_BACKEND_DEFAULT_MODELS))
        return data
    except (json.JSONDecodeError, KeyError):
        return None


def _save_cache(data: dict, cache_path: Path | None = None) -> None:
    path = cache_path or _config.DEFAULT_CACHE_PATH
    payload = dict(data)
    payload["format_version"] = _config.CACHE_FORMAT_VERSION
    payload["updated"] = datetime.now().isoformat()
    # Never persist model_rules_by_backend — rules live in available_models.
    payload.pop("model_rules_by_backend", None)
    payload.setdefault("backend_default_models", dict(_config.DEFAULT_BACKEND_DEFAULT_MODELS))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _current_cli_versions() -> dict[str, str]:
    cli_versions: dict[str, str] = {}
    copilot_ver = get_cli_version("copilot")
    if copilot_ver:
        cli_versions["copilot-cli"] = copilot_ver
    cursor_ver = get_cli_version("agent")
    if cursor_ver:
        cli_versions["cursor"] = cursor_ver
    return cli_versions


def _resolve_refresh_targets(
    backends: list[str] | None,
    available: dict[str, list[dict]],
) -> list[str]:
    if backends is None:
        targets = list(available.keys())
    else:
        targets = []
        for backend in backends:
            if backend in _core.BACKENDS and backend not in targets:
                targets.append(backend)
    return targets


def cache_is_stale(cache: dict) -> tuple[bool, str]:
    """Check if cache needs refresh (CLI version change or age)."""
    updated = cache.get("updated")
    if updated:
        try:
            age = datetime.now() - datetime.fromisoformat(updated)
            if age.days >= _config.CACHE_MAX_AGE_DAYS:
                return True, f"cache is {age.days} days old"
        except ValueError:
            pass

    cached_versions = cache.get("cli_versions", {})
    copilot_ver = get_cli_version("copilot")
    if copilot_ver and copilot_ver != cached_versions.get("copilot-cli"):
        return True, "copilot-cli version changed"
    cursor_ver = get_cli_version("agent")
    if cursor_ver and cursor_ver != cached_versions.get("cursor"):
        return True, "cursor version changed"
    return False, "up-to-date"


def discover_all_models(backends: list[str] | None = None) -> dict[str, list[dict]]:
    """Discover available models with inferred metadata for all accessible backends.

    Returns ``{backend: [{"name": str, "quality": int,
    "cost_multiplier": int, "vision": bool}, ...]}``.
    Models that don't match any pattern get sensible defaults.
    """
    result: dict[str, list[dict]] = {}
    if backends is None:
        backend_sequence = list(_core.BACKENDS.keys())
    else:
        backend_sequence = []
        for backend in backends:
            if backend in _core.BACKENDS and backend not in backend_sequence:
                backend_sequence.append(backend)

    for name in backend_sequence:
        ok, reason = _core.is_available(name)
        if not ok:
            log.info("Skipping %s during model discovery: %s", name, reason or "unavailable")
            continue
        log.info("Discovering models for backend: %s", name)
        model_names = _extract_model_names(_core.list_models(name))
        if not model_names:
            log.info("No models discovered for backend: %s", name)
            continue
        log.info("Discovered %d models for backend: %s", len(model_names), name)
        result[name] = _enrich_model_names(model_names)
    return result


def compute_quality_assignments(
    available: dict[str, list[dict]],
    vision_required: bool = False,
    reasoning_required: bool = False,
) -> dict[str, dict[str, str]]:
    """Compute best backend+model for each quality tier.

    Uses cost_multiplier from model metadata combined with backend cost
    (free/paid) to determine effective cost.
    When vision_required is True, only vision-capable models are considered.
    When reasoning_required is True, only reasoning models are considered.
    Returns ``{"low": {"backend": ..., "model": ...}, ...}``.
    """
    candidates: list[tuple[str, str, int, float]] = []
    for backend, models in available.items():
        is_free = _core.BACKENDS.get(backend, {}).get("cost") == "free"
        for model_info in models:
            quality = model_info["quality"]
            vision = model_info["vision"]
            reasoning = model_info.get("reasoning", False)
            cost_multiplier = model_info["cost_multiplier"]
            if vision_required and not vision:
                continue
            if reasoning_required and not reasoning:
                continue
            effective_cost = cost_multiplier if is_free else cost_multiplier + 1
            candidates.append((backend, model_info["name"], quality, effective_cost))

    assignments: dict[str, dict[str, str]] = {}

    free = [c for c in candidates if c[3] == 0]
    if free:
        best = max(free, key=lambda c: c[2])
        assignments["low"] = {"backend": best[0], "model": best[1]}

    normal = [c for c in candidates if c[3] <= 1]
    if normal:
        best = max(normal, key=lambda c: c[2])
        assignments["normal"] = {"backend": best[0], "model": best[1]}

    if candidates:
        best = max(candidates, key=lambda c: c[2])
        assignments["high"] = {"backend": best[0], "model": best[1]}

    return assignments


def refresh_registry(
    cache_path: Path | None = None,
    reference_doc_path: Path | None = None,
    quiet: bool = False,
    refresh_rules_backends: list[str] | None = None,
    refresh_default_model_backends: list[str] | None = None,
) -> dict:
    """Full refresh: discover models, compute assignments, save cache."""
    if not quiet:
        print("Refreshing model registry...")

    existing_cache = load_cache(cache_path) or {}

    # Seed _MODEL_RULES from existing cache's available_models so
    # _enrich_model_names works correctly during this run.
    existing_available: dict[str, list[dict]] = {}
    for key, val in existing_cache.items():
        if isinstance(val, dict) and "available_models" in val:
            models = val["available_models"]
            if isinstance(models, list):
                existing_available[key] = models
    _set_model_rules_from_available(existing_available)

    discovery_targets: list[str] | None = None
    explicit_targets: list[str] = []
    for group in (refresh_rules_backends, refresh_default_model_backends):
        if not group:
            continue
        for backend in group:
            if backend in _core.BACKENDS and backend not in explicit_targets:
                explicit_targets.append(backend)
    if explicit_targets:
        discovery_targets = explicit_targets

    available = discover_all_models(backends=discovery_targets)
    log.info("Backends with discovered models: %s", ", ".join(sorted(available)) or "none")

    if refresh_rules_backends is not None:
        targets = _resolve_refresh_targets(refresh_rules_backends, available)
        log.info("Model-rule refresh targets: %s", ", ".join(targets) or "none")
        for backend in targets:
            model_names = _extract_model_names(available.get(backend, []))
            if not model_names:
                log.info("Skipping model-rule generation for %s: no model candidates", backend)
                continue
            try:
                generated_rules = _generate_model_rules_for_backend(backend, model_names)
            except Exception as exc:
                log.warning("Failed to generate model rules for %s: %s", backend, exc)
                continue
            if generated_rules:
                # Merge generated rules back into available as enriched dicts.
                rule_map = {}
                for pattern, quality, cost, vision, reasoning in generated_rules:
                    # Strip ^...$  anchors to recover plain model name.
                    name = re.sub(r"^\^|\$$", "", pattern)
                    name = re.sub(r"\\(.)", r"\1", name)
                    rule_map[name] = {
                        "name": name,
                        "quality": quality,
                        "cost_multiplier": cost,
                        "vision": vision,
                        "reasoning": reasoning,
                    }
                available[backend] = [
                    rule_map.get(m["name"], m) if isinstance(m, dict) else m
                    for m in available.get(backend, [])
                ]
                if not quiet:
                    print(f"  rules[{backend}] -> {len(generated_rules)} entries")

        _set_model_rules_from_available(available)

    backend_default_models = dict(
        existing_cache.get("backend_default_models", _config.DEFAULT_BACKEND_DEFAULT_MODELS)
    )

    if refresh_default_model_backends is not None:
        targets = _resolve_refresh_targets(refresh_default_model_backends, available)
        log.info("Default-model refresh targets: %s", ", ".join(targets) or "none")
        for backend in targets:
            model_names = _extract_model_names(available.get(backend, []))
            if not model_names:
                log.info("Skipping default-model generation for %s: no model candidates", backend)
                continue
            try:
                selected_model = _generate_default_model_for_backend(backend, model_names)
            except Exception as exc:
                log.warning("Failed to generate default model for %s: %s", backend, exc)
                continue
            if selected_model:
                backend_default_models[backend] = selected_model
                if not quiet:
                    print(f"  default[{backend}] -> {selected_model}")

    cli_versions = _current_cli_versions()

    # ── Build new per-backend + top-level quality structure ───────────────────
    def _quality_block(av: dict[str, list[dict]]) -> dict:
        return {
            "default": compute_quality_assignments(av),
            "vision": compute_quality_assignments(av, vision_required=True),
            "reasoning": compute_quality_assignments(av, reasoning_required=True),
        }

    top_quality = _quality_block(available)

    # Preserve existing per-backend blobs we didn't touch.
    cache: dict = {"cli_versions": cli_versions, "backend_default_models": backend_default_models}
    for backend, models in available.items():
        per_backend_available = {backend: models}
        cache[backend] = {
            "available_models": models,
            "quality": _quality_block(per_backend_available),
        }
    cache["quality"] = top_quality

    _save_cache(cache, cache_path)

    if reference_doc_path:
        write_reference_doc(cache, reference_doc_path)

    if not quiet:
        assignments = top_quality.get("default", {})
        for tier in ("low", "normal", "high"):
            if tier in assignments:
                a = assignments[tier]
                print(f"  {tier}: {a['backend']}/{a['model']}")
        reasoning_a = top_quality.get("reasoning", {})
        if reasoning_a:
            print("  Reasoning:")
            for tier in ("low", "normal", "high"):
                if tier in reasoning_a:
                    a = reasoning_a[tier]
                    print(f"    {tier}: {a['backend']}/{a['model']}")
        print()
    return cache


def refresh_model_rules(
    backends: list[str] | None = None,
    cache_path: Path | None = None,
    reference_doc_path: Path | None = None,
    quiet: bool = False,
) -> dict:
    """Refresh prompt-generated model rules for selected backends."""
    return refresh_registry(
        cache_path=cache_path,
        reference_doc_path=reference_doc_path,
        quiet=quiet,
        refresh_rules_backends=backends,
    )


def refresh_backend_default_models(
    backends: list[str] | None = None,
    cache_path: Path | None = None,
    reference_doc_path: Path | None = None,
    quiet: bool = False,
) -> dict:
    """Refresh prompt-generated backend default models for selected backends."""
    return refresh_registry(
        cache_path=cache_path,
        reference_doc_path=reference_doc_path,
        quiet=quiet,
        refresh_default_model_backends=backends,
    )


def ensure_registry(
    cache_path: Path | None = None,
    reference_doc_path: Path | None = None,
) -> dict:
    """Load cache; refresh if stale or missing."""
    cache = load_cache(cache_path)
    if cache is None:
        return refresh_registry(cache_path, reference_doc_path)
    stale, reason = cache_is_stale(cache)
    if stale:
        log.info("Cache stale: %s", reason)
        return refresh_registry(cache_path, reference_doc_path)
    return cache


def resolve_backend_default_model(
    backend_name: str,
    cache: dict | None = None,
) -> str:
    """Resolve backend default model from cache, generating it when needed."""
    if backend_name not in _core.BACKENDS:
        raise ValueError(
            f"Unknown backend: {backend_name}. Available: {', '.join(_core.BACKENDS)}"
        )

    active_cache = cache if cache is not None else ensure_registry()
    defaults = dict(active_cache.get("backend_default_models", _config.DEFAULT_BACKEND_DEFAULT_MODELS))
    # available_models now lives inside cache[backend]["available_models"]
    backend_data = active_cache.get(backend_name, {})
    available_models = backend_data.get("available_models", []) if isinstance(backend_data, dict) else []
    model_names = _extract_model_names(available_models)

    selected_model = defaults.get(backend_name)
    if selected_model and (not model_names or selected_model in model_names):
        return selected_model

    if model_names:
        try:
            refreshed = refresh_backend_default_models(backends=[backend_name], quiet=True)
            refreshed_defaults = refreshed.get("backend_default_models", {})
            regenerated = refreshed_defaults.get(backend_name)
            if regenerated and regenerated in model_names:
                return regenerated
        except Exception as exc:
            log.warning("Could not auto-generate default model for %s: %s", backend_name, exc)
        return model_names[0]

    if backend_name == "cursor":
        return _config.CURSOR_BOOTSTRAP_MODEL

    raise RuntimeError(
        f"No model candidates available for backend '{backend_name}'. "
        "Run --refresh-models first."
    )


def resolve_quality(
    quality: str, cache: dict, vision: bool = False, reasoning: bool = False,
) -> tuple[str, str]:
    """Resolve a quality tier name to (backend, model).

    When vision=True, selects among vision-capable models only.
    When reasoning=True, selects among reasoning models only.

    Override priority (highest to lowest):
      1. Import-level overrides set via :func:`set_quality_overrides`
      2. User config at ``~/.config/ai_backends/quality.json``
      3. Cache-computed assignments from :func:`ensure_registry`
    """
    tier = QUALITY_SYNONYMS.get(quality, quality)
    # Pick the right sub-key: reasoning > vision > default
    if reasoning:
        mode = "reasoning"
    elif vision:
        mode = "vision"
    else:
        mode = "default"
    top_quality = cache.get("quality", {})
    assignments = top_quality.get(mode) or top_quality.get("default") or {}
    if tier not in assignments and tier not in _quality_overrides:
        raise RuntimeError(
            f"No model available for quality '{tier}' (mode={mode}). "
            f"Available tiers: {', '.join(assignments.keys()) or 'none'}. "
            "Run with --refresh-models to re-scan."
        )
    assignment: dict = dict(assignments.get(tier, {}))
    user_cfg = _load_user_config()
    if tier in user_cfg:
        assignment.update(user_cfg[tier])
        log.debug("User config override for '%s': %s", tier, user_cfg[tier])
    if tier in _quality_overrides:
        assignment.update(_quality_overrides[tier])
        log.debug("Import-level override for '%s': %s", tier, _quality_overrides[tier])
    backend = assignment.get("backend")
    model = assignment.get("model")
    if not backend or not model:
        raise RuntimeError(
            f"Quality '{tier}' (mode={mode}) override is incomplete: {assignment}. "
            "Provide both 'backend' and 'model', or run --refresh-models to "
            "populate the cache first."
        )
    ok, reason = _core.is_available(backend)
    if not ok:
        raise RuntimeError(
            f"Quality '{tier}' resolved to {backend}/{model}, "
            f"but {backend} is unavailable: {reason}"
        )
    return backend, model


def write_reference_doc(cache: dict, path: Path) -> None:
    """Write the available-models reference Markdown document."""
    from . import __version__

    path.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "# Available Models & Quality Assignments",
        "",
        f"*Auto-generated by ai_backends v{__version__} "
        f"on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
        "",
        "> This file is regenerated when CLI versions change or the cache expires.",
        "> Do not edit manually.",
        "",
    ]

    top_quality = cache.get("quality", {})
    tier_syn = {"low": "fast", "normal": "default", "high": "slow"}

    def _write_tier_table(heading: str, assignments: dict) -> None:
        if not assignments:
            return
        lines.append(f"## {heading}")
        lines.append("")
        lines.append("| Quality | Synonym | Backend | Model |")
        lines.append("|---------|---------|---------|-------|")
        for tier in ("low", "normal", "high"):
            if tier in assignments:
                a = assignments[tier]
                lines.append(
                    f"| `{tier}` | `{tier_syn.get(tier, '')}` "
                    f"| `{a['backend']}` | `{a['model']}` |"
                )
        lines.append("")

    _write_tier_table("Quality Tiers", top_quality.get("default", {}))
    _write_tier_table("Quality Tiers (Vision)", top_quality.get("vision", {}))
    _write_tier_table("Quality Tiers (Reasoning)", top_quality.get("reasoning", {}))

    # Per-backend model listings
    lines += ["## Available Models by Backend", ""]
    for backend in sorted(k for k in cache if k not in ("cli_versions", "backend_default_models", "quality", "format_version", "updated")):
        backend_data = cache.get(backend, {})
        if not isinstance(backend_data, dict):
            continue
        models = backend_data.get("available_models", [])
        if not models:
            continue
        cost = _core.BACKENDS.get(backend, {}).get("cost", "unknown")
        lines.append(f"### {backend} ({cost})")
        lines.append("")
        for model_info in models:
            if isinstance(model_info, dict):
                name = model_info["name"]
                q = model_info["quality"]
                c = model_info["cost_multiplier"]
                v = model_info["vision"]
                r = model_info.get("reasoning", False)
                flags = f"cost: {c}x, vision: {'yes' if v else 'no'}"
                if r:
                    flags += ", reasoning"
                lines.append(f"- `{name}` — quality: {q}, {flags}")
            else:
                info = infer_model_info(str(model_info))
                if info:
                    lines.append(
                        f"- `{model_info}` — quality: {info['quality']}, "
                        f"cost: {info['cost_multiplier']}x, "
                        f"vision: {'yes' if info['vision'] else 'no'}"
                    )
                else:
                    lines.append(f"- `{model_info}` — (unranked)")
        lines.append("")

    cli_versions = cache.get("cli_versions", {})
    if cli_versions:
        lines += ["## CLI Versions (at last refresh)", ""]
        for cli, ver in sorted(cli_versions.items()):
            lines.append(f"- **{cli}**: `{ver}`")
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")

