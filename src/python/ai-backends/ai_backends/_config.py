"""ai_backends._config - Centralized constants and AI generation prompts."""

from pathlib import Path


# Shared file and backend metadata.
MIME_MAP: dict[str, str] = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".tiff": "image/tiff",
    ".tif": "image/tiff",
    ".bmp": "image/bmp",
    ".webp": "image/webp",
}

BACKEND_SPECS: dict[str, dict[str, str]] = {
    "gemini": {"type": "api", "cost": "free"},
    "openai": {"type": "api", "cost": "paid"},
    "anthropic": {"type": "api", "cost": "paid"},
    "github-api": {"type": "api", "cost": "free"},
    "copilot-cli": {"type": "cli", "cost": "free"},
    "cursor": {"type": "cli", "cost": "free"},
}

BACKEND_PROVIDER_HINTS: dict[str, str] = {
    "gemini": "Google Gemini API",
    "openai": "OpenAI API",
    "anthropic": "Anthropic API",
    "github-api": "GitHub Models API (multi-provider model hosting via GitHub)",
    "copilot-cli": "GitHub Copilot CLI",
    "cursor": "Cursor Agent CLI",
}

LLM_TYPES: set[str] = {"api", "cli"}


# Cache and user config paths.
CACHE_FORMAT_VERSION = 6
DEFAULT_CACHE_PATH = Path(__file__).parent / ".models_cache.json"
CACHE_MAX_AGE_DAYS = 7
USER_QUALITY_CONFIG_PATH = Path.home() / ".config" / "ai_backends" / "quality.json"


# Quality-tier and fallback tuning.
QUALITY_SYNONYMS: dict[str, str] = {
    "fast": "low",
    "slow": "high",
    "default": "normal",
}

# No baked-in backend default models by design. Defaults are generated and cached.
DEFAULT_BACKEND_DEFAULT_MODELS: dict[str, str] = {}

UNKNOWN_MODEL_DEFAULT_QUALITY = 60
UNKNOWN_MODEL_DEFAULT_COST_MULTIPLIER = 1
UNKNOWN_MODEL_DEFAULT_VISION = True
UNKNOWN_MODEL_DEFAULT_REASONING = False

# Estimated USD per 1M-token average-price buckets used to map web pricing
# into the existing 0x/1x/3x multiplier scale.
PRICE_BUCKET_FREE_MAX_USD_PER_1M = 0.5
PRICE_BUCKET_STANDARD_MAX_USD_PER_1M = 8.0


# Static probe lists used only for model discovery helpers.
GITHUB_API_MODEL_CANDIDATES: list[str] = [
    "gpt-4o",
    "gpt-4o-mini",
    "gpt-4.1",
    "gpt-4.1-mini",
    "gpt-4.1-nano",
    "Llama-3.2-11B-Vision-Instruct",
    "Llama-3.2-90B-Vision-Instruct",
    "Llama-3.3-70B-Instruct",
    "Phi-4-multimodal-instruct",
    "Mistral-Large",
]

OPENAI_MODEL_PREFIXES: tuple[str, ...] = (
    "gpt-4o",
    "gpt-4.1",
    "gpt-4-turbo",
    "gpt-3.5",
    "o4",
    "o3",
    "o1",
)

ANTHROPIC_KNOWN_MODELS: list[str] = [
    "claude-opus-4-20250514",
    "claude-sonnet-4.5-20250514",
    "claude-sonnet-4-20250514",
    "claude-haiku-3.5-20241022",
]

CURSOR_BOOTSTRAP_MODEL = "default"

# Prefer a cheap reasoning/codex model for structured generation tasks.
COPILOT_GENERATION_MODEL_CANDIDATES: tuple[str, ...] = (
    "gpt-5.1-codex-mini",
    "gpt-5.3-codex",
    "gpt-5.4",
    "gpt-4.1",
)


# CLI and text-cleaning constants.
DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH = "skills/agent-script/references/available-models.md"
COPILOT_OUTPUT_PREFIXES: tuple[str, ...] = (
    "✔ ",
    "● ",
    "└ ",
    "$ ",
    "...",
)
COPILOT_PREAMBLE_REGEX = (
    r"(?:Here is|Below is)[^\n]*(?:transcription|result|output)[^\n]*:?\s*\n+(?:---\s*\n+)?"
)


# Prompt template file paths.
PROMPTS_DIR = Path(__file__).parent / "prompts"
MODEL_RULES_TEMPLATE_PATH = PROMPTS_DIR / "model-rules-generation.prompt.md"
DEFAULT_MODEL_SELECTION_TEMPLATE_PATH = PROMPTS_DIR / "default-model-selection.prompt.md"

# Short instruction sent as the -p prompt; the real work is in the context file.
# {filename} is filled at call time with the temp file's basename.
GENERATION_INSTRUCTION = (
    "Follow the instructions in @{filename} exactly. "
    "Return only the requested JSON output. No markdown fences. No commentary."
)