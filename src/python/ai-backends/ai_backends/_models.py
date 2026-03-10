"""ai_backends._models — Pattern-based model inference, quality tiers, and registry cache."""

import json
import re
import subprocess
import logging
from pathlib import Path
from datetime import datetime

from . import _core

log = logging.getLogger("ai_backends")

# ── Pattern-based model inference ─────────────────────────────────────────────
#
# Each rule: (regex_pattern, quality_score, cost_multiplier, vision_capable)
#   quality_score : 0-100, approximates overall model capability
#   cost_multiplier: 0 = included/free, 1 = standard, 3 = premium
#     Matches GitHub Copilot's 0x/1x/3x pricing tiers.
#   vision_capable : True if the model can process images
#
# Rules are checked in order; first match wins.  Add new model families at the
# top of their provider section.  Generic fallback patterns are at the bottom.

_MODEL_RULES: list[tuple[str, int, int, bool]] = [
    # ── Anthropic ──
    (r"claude-opus-\d[\w.]*-fast",  95, 1, True),
    (r"claude-opus-4",              98, 3, True),
    (r"claude-sonnet-4\.5",         92, 1, True),
    (r"claude-sonnet-4",            88, 1, True),
    (r"claude-haiku",               65, 1, True),
    # ── OpenAI gpt-5.x ──
    (r"gpt-5\.\d+-codex-max",      95, 3, True),
    (r"gpt-5\.\d+-codex-mini",     70, 0, True),
    (r"gpt-5\.\d+-codex",          88, 1, True),
    (r"gpt-5\.\d+",                90, 1, True),
    (r"gpt-5-mini",                68, 0, True),
    # ── OpenAI gpt-4.x ──
    (r"gpt-4\.1-mini",             75, 1, True),
    (r"gpt-4\.1-nano",             55, 0, True),
    (r"gpt-4\.1",                  88, 1, True),
    (r"gpt-4o-mini",               68, 0, True),
    (r"gpt-4o",                    85, 1, True),
    (r"gpt-4-turbo",               82, 1, True),
    # ── OpenAI o-series ──
    (r"o4-mini",                   90, 1, True),
    (r"o3-mini",                   85, 1, True),
    # ── Google ──
    (r"gemini-3-pro",              92, 1, True),
    (r"gemini-2\.5-pro",           88, 1, True),
    (r"gemini-2\.5-flash",         72, 1, True),
    (r"gemini-2\.0-flash",         68, 0, True),
    (r"gemini-1\.5-pro",           80, 1, True),
    (r"gemini-1\.5-flash",         65, 0, True),
    # ── Meta (via GitHub Models) ──
    (r"Llama.*Vision.*90B",        70, 0, True),
    (r"Llama.*Vision.*11B",        55, 0, True),
    (r"Llama.*70B",                75, 0, False),
    # ── Microsoft (via GitHub Models) ──
    (r"Phi-4-multimodal",          50, 0, True),
    # ── Other providers ──
    (r"Mistral-Large",             78, 0, False),
    (r"DeepSeek-R1",               82, 0, False),
    # ── Generic fallback patterns ──
    (r"-nano\b",                   45, 0, True),
    (r"-mini\b",                   60, 0, True),
    (r"gpt-3\.5",                  50, 0, False),
]


def infer_model_info(model_name: str) -> dict | None:
    """Infer model attributes from its name using pattern rules.

    Returns ``{"quality": int, "cost_multiplier": int, "vision": bool}``
    where cost_multiplier uses GitHub Copilot's 0x/1x/3x scale,
    or ``None`` if the model doesn't match any known pattern.
    """
    for pattern, quality, cost, vision in _MODEL_RULES:
        if re.search(pattern, model_name, re.IGNORECASE):
            return {"quality": quality, "cost_multiplier": cost, "vision": vision}
    return None

QUALITY_SYNONYMS: dict[str, str] = {
    "fast": "low", "slow": "high", "default": "normal",
}

_DEFAULT_CACHE_PATH = Path(__file__).parent / ".models_cache.json"
_CACHE_MAX_AGE_DAYS = 7

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

_USER_CONFIG_PATH = Path.home() / ".config" / "ai_backends" / "quality.json"
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
        r = subprocess.run(
            [cmd, "--version"],
            capture_output=True, text=True, timeout=15, shell=_core.SHELL,
        )
        return r.stdout.strip() if r.returncode == 0 else None
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def match_model_knowledge(model_name: str) -> tuple[int, int, bool] | None:
    """Match a model against known patterns.

    Returns (quality_score, cost_multiplier, vision_capable) or None.
    """
    info = infer_model_info(model_name)
    if info is None:
        return None
    return info["quality"], info["cost_multiplier"], info["vision"]


def load_cache(cache_path: Path | None = None) -> dict | None:
    """Load models cache. Returns None if missing or corrupt."""
    path = cache_path or _DEFAULT_CACHE_PATH
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("format_version") != 4:
            return None
        return data
    except (json.JSONDecodeError, KeyError):
        return None


def _save_cache(data: dict, cache_path: Path | None = None) -> None:
    path = cache_path or _DEFAULT_CACHE_PATH
    data["format_version"] = 4
    data["updated"] = datetime.now().isoformat()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def cache_is_stale(cache: dict) -> tuple[bool, str]:
    """Check if cache needs refresh (CLI version change or age)."""
    updated = cache.get("updated")
    if updated:
        try:
            age = datetime.now() - datetime.fromisoformat(updated)
            if age.days >= _CACHE_MAX_AGE_DAYS:
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


def discover_all_models() -> dict[str, list[dict]]:
    """Discover available models with inferred metadata for all accessible backends.

    Returns ``{backend: [{"name": str, "quality": int,
    "cost_multiplier": int, "vision": bool}, ...]}``.
    Models that don't match any pattern get sensible defaults.
    """
    result: dict[str, list[dict]] = {}
    for name in _core.BACKENDS:
        ok, _ = _core.is_available(name)
        if not ok:
            continue
        models = _core.list_models(name)
        if not models:
            continue
        enriched: list[dict] = []
        for m in models:
            info = infer_model_info(m)
            if info:
                enriched.append({"name": m, **info})
            else:
                # Unknown model: moderate quality, standard cost, assume vision
                enriched.append(
                    {"name": m, "quality": 60, "cost_multiplier": 1, "vision": True}
                )
        result[name] = enriched
    return result


def compute_quality_assignments(
    available: dict[str, list[dict]],
    vision_required: bool = False,
) -> dict[str, dict[str, str]]:
    """Compute best backend+model for each quality tier.

    Uses cost_multiplier (0x/1x/3x) from model metadata combined with
    backend cost (free/paid) to determine effective cost.
    When vision_required is True, only vision-capable models are considered.
    Returns ``{"low": {"backend": ..., "model": ...}, ...}``.
    """
    candidates: list[tuple[str, str, int, int]] = []
    for backend, models in available.items():
        is_free = _core.BACKENDS.get(backend, {}).get("cost") == "free"
        for model_info in models:
            quality = model_info["quality"]
            vision = model_info["vision"]
            cost_multiplier = model_info["cost_multiplier"]
            if vision_required and not vision:
                continue
            # Free backends: use multiplier directly (0x/1x/3x)
            # Paid backends: add penalty — even 0x on a paid backend costs money
            effective_cost = cost_multiplier if is_free else cost_multiplier + 1
            candidates.append((backend, model_info["name"], quality, effective_cost))

    assignments: dict[str, dict[str, str]] = {}

    # low/fast: best quality among cheapest options (effective_cost == 0)
    free = [c for c in candidates if c[3] == 0]
    if free:
        best = max(free, key=lambda c: c[2])
        assignments["low"] = {"backend": best[0], "model": best[1]}

    # normal/default: best quality where effective_cost <= 1
    normal = [c for c in candidates if c[3] <= 1]
    if normal:
        best = max(normal, key=lambda c: c[2])
        assignments["normal"] = {"backend": best[0], "model": best[1]}

    # high/slow: absolute best quality
    if candidates:
        best = max(candidates, key=lambda c: c[2])
        assignments["high"] = {"backend": best[0], "model": best[1]}

    return assignments


def refresh_registry(
    cache_path: Path | None = None,
    reference_doc_path: Path | None = None,
    quiet: bool = False,
) -> dict:
    """Full refresh: discover models, compute assignments, save cache."""
    if not quiet:
        print("Refreshing model registry...")

    available = discover_all_models()
    assignments = compute_quality_assignments(available)
    assignments_vision = compute_quality_assignments(available, vision_required=True)

    cli_versions: dict[str, str] = {}
    copilot_ver = get_cli_version("copilot")
    if copilot_ver:
        cli_versions["copilot-cli"] = copilot_ver
    cursor_ver = get_cli_version("agent")
    if cursor_ver:
        cli_versions["cursor"] = cursor_ver

    cache = {
        "cli_versions": cli_versions,
        "available_models": available,
        "quality_assignments": assignments,
        "quality_assignments_vision": assignments_vision,
    }
    _save_cache(cache, cache_path)

    if reference_doc_path:
        write_reference_doc(cache, reference_doc_path)

    if not quiet:
        for tier in ("low", "normal", "high"):
            if tier in assignments:
                a = assignments[tier]
                print(f"  {tier}: {a['backend']}/{a['model']}")
        if assignments_vision != assignments:
            print("  Vision:")
            for tier in ("low", "normal", "high"):
                if tier in assignments_vision:
                    a = assignments_vision[tier]
                    print(f"    {tier}: {a['backend']}/{a['model']}")
        print()
    return cache


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


def resolve_quality(
    quality: str, cache: dict, vision: bool = False,
) -> tuple[str, str]:
    """Resolve a quality tier name to (backend, model).

    When vision=True, selects among vision-capable models only.

    Override priority (highest to lowest):
      1. Import-level overrides set via :func:`set_quality_overrides`
      2. User config at ``~/.config/ai_backends/quality.json``
      3. Cache-computed assignments from :func:`ensure_registry`
    """
    tier = QUALITY_SYNONYMS.get(quality, quality)
    key = "quality_assignments_vision" if vision else "quality_assignments"
    assignments = cache.get(key) or cache.get("quality_assignments", {})
    if tier not in assignments and tier not in _quality_overrides:
        raise RuntimeError(
            f"No model available for quality '{tier}'. "
            f"Available tiers: {', '.join(assignments.keys()) or 'none'}. "
            "Run with --refresh-models to re-scan."
        )
    # Start from cache, then layer overrides
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
            f"Quality '{tier}' override is incomplete: {assignment}. "
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

    assignments = cache.get("quality_assignments", {})
    if assignments:
        tier_syn = {"low": "fast", "normal": "default", "high": "slow"}
        lines += [
            "## Quality Tiers",
            "",
            "| Quality | Synonym | Backend | Model |",
            "|---------|---------|---------|-------|",
        ]
        for tier in ("low", "normal", "high"):
            if tier in assignments:
                a = assignments[tier]
                lines.append(
                    f"| `{tier}` | `{tier_syn.get(tier, '')}` "
                    f"| `{a['backend']}` | `{a['model']}` |"
                )
        lines.append("")

    assignments_vision = cache.get("quality_assignments_vision", {})
    if assignments_vision and assignments_vision != assignments:
        tier_syn = {"low": "fast", "normal": "default", "high": "slow"}
        lines += [
            "## Quality Tiers (Vision-Only)",
            "",
            "| Quality | Synonym | Backend | Model |",
            "|---------|---------|---------|-------|",
        ]
        for tier in ("low", "normal", "high"):
            if tier in assignments_vision:
                a = assignments_vision[tier]
                lines.append(
                    f"| `{tier}` | `{tier_syn.get(tier, '')}` "
                    f"| `{a['backend']}` | `{a['model']}` |"
                )
        lines.append("")

    available = cache.get("available_models", {})
    if available:
        lines += ["## Available Models by Backend", ""]
        for backend in sorted(available.keys()):
            cost = _core.BACKENDS.get(backend, {}).get("cost", "unknown")
            lines.append(f"### {backend} ({cost})")
            lines.append("")
            for model_info in available[backend]:
                if isinstance(model_info, dict):
                    name = model_info["name"]
                    q = model_info["quality"]
                    c = model_info["cost_multiplier"]
                    v = model_info["vision"]
                    lines.append(
                        f"- `{name}` — quality: {q}, "
                        f"cost: {c}x, vision: {'yes' if v else 'no'}"
                    )
                else:
                    # Legacy plain-string entry (shouldn't happen with v4 cache)
                    info = infer_model_info(model_info)
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
