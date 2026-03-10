"""ai_backends._core — Backend registry, callers, and availability checks."""

import os
import sys
import re
import base64
import subprocess
import logging
from pathlib import Path

log = logging.getLogger("ai_backends")

SHELL = sys.platform == "win32"

MIME_MAP = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
    ".tiff": "image/tiff", ".tif": "image/tiff", ".bmp": "image/bmp",
    ".webp": "image/webp",
}


def load_dotenv(path: Path) -> None:
    """Load a .env file into os.environ."""
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip().strip('"').strip("'")
        if k:
            os.environ[k] = v


def b64_encode(path: Path) -> str:
    """Base64-encode file contents."""
    return base64.b64encode(path.read_bytes()).decode()


def mime_type(path: Path) -> str:
    """Get MIME type for a file by extension."""
    return MIME_MAP.get(path.suffix.lower(), "application/octet-stream")


def has_images(files: list[Path] | None) -> bool:
    """Check if any files in the list are images (by extension)."""
    if not files:
        return False
    return any(f.suffix.lower() in MIME_MAP for f in files)


def _normalize_files(context_files) -> list[Path]:
    """Normalize context_files to a list of Path objects."""
    if context_files is None:
        return []
    if isinstance(context_files, (str, Path)):
        return [Path(context_files)]
    return [Path(f) for f in context_files]


def _build_content_parts_openai(prompt: str, files: list[Path]) -> list[dict]:
    """Build OpenAI-compatible message content parts (text + inline images)."""
    parts: list[dict] = [{"type": "text", "text": prompt}]
    for f in files:
        if f.suffix.lower() in MIME_MAP:
            parts.append({"type": "image_url", "image_url": {
                "url": f"data:{mime_type(f)};base64,{b64_encode(f)}",
                "detail": "high",
            }})
    return parts


# ── LLM API callers ──────────────────────────────────────────────────────────

def _call_gemini(prompt: str, context_files: list[Path], model_name: str) -> str:
    import google.generativeai as genai

    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Set GEMINI_API_KEY or GOOGLE_API_KEY. "
            "Free -> https://aistudio.google.com/apikey"
        )
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_name)
    parts: list = [prompt]
    for f in context_files:
        if f.suffix.lower() in MIME_MAP:
            parts.append({"mime_type": mime_type(f), "data": f.read_bytes()})
    resp = model.generate_content(
        parts,
        generation_config=genai.types.GenerationConfig(temperature=0),
    )
    return resp.text


def _call_openai(prompt: str, context_files: list[Path], model_name: str) -> str:
    from openai import OpenAI

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("Set OPENAI_API_KEY")
    client = OpenAI(api_key=api_key)
    resp = client.chat.completions.create(
        model=model_name, temperature=0, max_tokens=4096,
        messages=[{"role": "user", "content":
                   _build_content_parts_openai(prompt, context_files)}],
    )
    return resp.choices[0].message.content


def _call_anthropic(prompt: str, context_files: list[Path], model_name: str) -> str:
    import anthropic

    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError("Set ANTHROPIC_API_KEY")
    client = anthropic.Anthropic(api_key=api_key)
    content: list[dict] = []
    for f in context_files:
        if f.suffix.lower() in MIME_MAP:
            content.append({"type": "image", "source": {
                "type": "base64",
                "media_type": mime_type(f),
                "data": b64_encode(f),
            }})
    content.append({"type": "text", "text": prompt})
    resp = client.messages.create(
        model=model_name, max_tokens=4096, temperature=0,
        messages=[{"role": "user", "content": content}],
    )
    return resp.content[0].text


def get_github_token() -> str | None:
    """Get GitHub token from env or gh CLI."""
    token = os.getenv("GITHUB_TOKEN")
    if token:
        return token
    try:
        r = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True, text=True, timeout=15, shell=SHELL,
        )
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def _call_github(prompt: str, context_files: list[Path], model_name: str) -> str:
    from openai import OpenAI

    token = get_github_token()
    if not token:
        raise RuntimeError("Set GITHUB_TOKEN or run: gh auth login")
    base_url = os.getenv("GITHUB_MODELS_BASE_URL", "https://models.github.ai/inference")
    log.debug("github-api: model=%s base_url=%s", model_name, base_url)
    client = OpenAI(base_url=base_url, api_key=token)
    resp = client.chat.completions.create(
        model=model_name, temperature=0, max_tokens=4096,
        messages=[{"role": "user", "content":
                   _build_content_parts_openai(prompt, context_files)}],
    )
    text = resp.choices[0].message.content
    log.info("github-api/%s -> %d chars", model_name, len(text))
    return text


# ── CLI-based backends ────────────────────────────────────────────────────────

def _clean_copilot_output(text: str) -> str:
    """Strip copilot CLI tool execution traces from output."""
    lines = text.splitlines()
    cleaned: list[str] = []
    skip_prefix = True
    for line in lines:
        stripped = line.lstrip()
        if skip_prefix and (
            stripped.startswith("✔ ")
            or stripped.startswith("● ")
            or stripped.startswith("└ ")
            or stripped.startswith("$ ")
            or stripped.startswith("...")
        ):
            continue
        if skip_prefix and not stripped:
            continue
        skip_prefix = False
        cleaned.append(line)
    return "\n".join(cleaned).strip()


def _call_copilot(prompt: str, context_files: list[Path], model_name: str) -> str:
    """GitHub Copilot CLI — uses -p (prompt) with --add-path for context files."""
    full_prompt = (
        f"{prompt}\n\n"
        "NON-INTERACTIVE TASK. Do not ask questions. "
        "Do not provide options. Do not explain anything. "
        "Return only the requested output. "
        "No shell commands. No file edits."
    )

    cmd = [
        "copilot", "-p", full_prompt,
        "--allow-tool", "read",
        "--deny-tool", "shell",
        "--deny-tool", "write",
        "--deny-tool", "edit",
        "--silent",
        "--no-ask-user",
    ]
    if model_name and model_name != "default":
        cmd.extend(["--model", model_name])
    for f in context_files:
        cmd.extend(["--add-path", str(f.resolve())])

    log.info("copilot prompt:\n%s", full_prompt)
    cmd_display = [c if len(c) < 120 else c[:60] + "..." for c in cmd]
    log.debug("copilot cmd: %s", cmd_display)

    try:
        r = subprocess.run(
            cmd, capture_output=True, timeout=300, shell=SHELL,
        )
    except FileNotFoundError:
        raise RuntimeError("copilot CLI not found — install from npm or GitHub")
    except subprocess.TimeoutExpired:
        raise RuntimeError("copilot CLI timed out (5 min)")

    stdout = r.stdout.decode("utf-8", errors="replace")
    stderr = r.stderr.decode("utf-8", errors="replace") if r.stderr else ""

    log.debug("copilot exit=%d  stdout=%d chars  stderr=%d chars",
              r.returncode, len(stdout), len(stderr))
    if stderr:
        log.debug("copilot stderr: %s", stderr[:500])
    log.debug("copilot raw stdout (first 500): %s", stdout[:500])

    if r.returncode != 0:
        raise RuntimeError(
            f"copilot exited {r.returncode}: {(stderr or stdout)[:300]}"
        )

    text = _clean_copilot_output(stdout)
    log.debug("copilot cleaned output (%d chars, first 300): %s",
              len(text), text[:300])

    if text.startswith("```") and text.endswith("```"):
        text = text[text.index("\n") + 1 : text.rindex("```")].strip()
        log.debug("copilot stripped code fences, now %d chars", len(text))

    preamble = re.match(
        r"(?:Here is|Below is)[^\n]*(?:transcription|result|output)[^\n]*:?\s*\n+(?:---\s*\n+)?",
        text, re.IGNORECASE,
    )
    if preamble:
        text = text[preamble.end():]
        log.debug("copilot stripped preamble (%d chars removed)", preamble.end())

    low = text.lower()
    if "how can i assist" in low or "would you like me to" in low:
        log.warning("copilot returned generic reply (model=%s). Full output:\n%s",
                    model_name, text[:1000])
        raise RuntimeError(
            "copilot returned a generic assistant reply instead of task output; "
            "retry or use a different backend"
        )
    if not text:
        log.warning("copilot produced empty output (model=%s, stdout=%d chars)",
                    model_name, len(stdout))
        raise RuntimeError("copilot produced empty output")
    log.info("copilot-cli/%s -> %d chars", model_name, len(text))
    return text


def _call_cursor(prompt: str, context_files: list[Path], model_name: str) -> str:
    """Cursor Agent CLI — uses -p (print/non-interactive) mode."""
    full_prompt = prompt
    if context_files:
        file_refs = "\n".join(str(f.resolve()) for f in context_files)
        full_prompt = f"{prompt}\n\nContext files:\n{file_refs}"

    cmd = ["agent", "-p", "--output-format", "text", full_prompt]
    if model_name and model_name != "default":
        cmd.extend(["--model", model_name])

    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300, shell=SHELL)
    except FileNotFoundError:
        raise RuntimeError(
            "cursor agent CLI not found — install: "
            "irm 'https://cursor.com/install?win32=true' | iex"
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("cursor agent CLI timed out (5 min)")

    if r.returncode != 0:
        raise RuntimeError(
            f"cursor agent exited {r.returncode}: {(r.stderr or r.stdout)[:300]}"
        )

    text = r.stdout.strip()
    if not text:
        raise RuntimeError("cursor agent produced empty output")
    return text


# ── Backend registry ──────────────────────────────────────────────────────────

BACKENDS: dict[str, dict] = {
    "gemini": {
        "call": _call_gemini,
        "default_model": "gemini-2.0-flash",
        "type": "api",
        "cost": "free",
    },
    "openai": {
        "call": _call_openai,
        "default_model": "gpt-4o",
        "type": "api",
        "cost": "paid",
    },
    "anthropic": {
        "call": _call_anthropic,
        "default_model": "claude-sonnet-4-20250514",
        "type": "api",
        "cost": "paid",
    },
    "github-api": {
        "call": _call_github,
        "default_model": "gpt-4o",
        "type": "api",
        "cost": "free",
    },
    "copilot-cli": {
        "call": _call_copilot,
        "default_model": "gemini-3-pro-preview",
        "type": "cli",
        "cost": "free",
    },
    "cursor": {
        "call": _call_cursor,
        "default_model": "default",
        "type": "cli",
        "cost": "free",
    },
}

LLM_TYPES = {"api", "cli"}


def call_backend(
    backend_name: str,
    prompt: str,
    context_files: list[Path] | Path | None = None,
    model: str | None = None,
) -> str:
    """Call a backend with a prompt and optional context files.

    Context files are attached using the mechanism for each backend type:
    - API backends: images are base64-encoded inline in the request
    - CLI backends: files are provided via --add-path

    If context_files includes images, ensure the model supports vision
    (use resolve_quality with vision=True, or check MODEL_KNOWLEDGE).
    """
    if backend_name not in BACKENDS:
        raise ValueError(
            f"Unknown backend: {backend_name}. Available: {', '.join(BACKENDS)}"
        )
    files = _normalize_files(context_files)
    be = BACKENDS[backend_name]
    m = model or be["default_model"]
    return be["call"](prompt, files, m)


def is_available(name: str) -> tuple[bool, str]:
    """Check if a backend is available. Returns (ok, reason_if_not)."""
    if name == "gemini":
        ok = bool(os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"))
        return (True, "") if ok else (False, "set GEMINI_API_KEY")
    if name == "openai":
        return (True, "") if os.getenv("OPENAI_API_KEY") else (False, "set OPENAI_API_KEY")
    if name == "anthropic":
        return (True, "") if os.getenv("ANTHROPIC_API_KEY") else (False, "set ANTHROPIC_API_KEY")
    if name == "github-api":
        return (True, "") if get_github_token() else (False, "set GITHUB_TOKEN or gh auth login")
    if name == "copilot-cli":
        try:
            r = subprocess.run(
                ["copilot", "--version"],
                capture_output=True, text=True, timeout=15, shell=SHELL,
            )
            return (True, "") if r.returncode == 0 else (False, "copilot CLI not working")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return (False, "copilot CLI not installed")
    if name == "cursor":
        try:
            r = subprocess.run(
                ["agent", "--version"],
                capture_output=True, text=True, timeout=15, shell=SHELL,
            )
            return (True, "") if r.returncode == 0 else (False, "cursor agent CLI not working")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return (False, "cursor agent CLI not installed")
    return False, "unknown backend"


# ── Model listing ─────────────────────────────────────────────────────────────

def _list_copilot_models() -> list[str]:
    """Parse available models from copilot --help output."""
    try:
        r = subprocess.run(
            ["copilot", "--help"],
            capture_output=True, text=True, timeout=15, shell=SHELL,
        )
        if r.returncode != 0:
            return []
        text = r.stdout + (r.stderr or "")
        models = re.findall(r'"((?:claude|gpt|gemini|o\d)[\w.+-]+)"', text)
        if models:
            return models
        models = re.findall(
            r"\b(claude-[\w.-]+|gpt-[\w.-]+|gemini-[\w.-]+|o\d[\w.-]*)\b", text,
        )
        return sorted(set(models))
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []


def _list_github_api_models() -> list[str]:
    """Probe GitHub Models API for known models."""
    token = get_github_token()
    if not token:
        return []
    try:
        from openai import OpenAI
        client = OpenAI(
            base_url=os.getenv(
                "GITHUB_MODELS_BASE_URL", "https://models.github.ai/inference"
            ),
            api_key=token,
        )
        candidates = [
            "gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano",
            "Llama-3.2-11B-Vision-Instruct", "Llama-3.2-90B-Vision-Instruct",
            "Llama-3.3-70B-Instruct",
            "Phi-4-multimodal-instruct",
            "Mistral-Large",
        ]
        available = []
        for model in candidates:
            try:
                client.chat.completions.create(
                    model=model, max_tokens=1,
                    messages=[{"role": "user", "content": "hi"}],
                )
                available.append(model)
            except Exception:
                pass
        return available
    except Exception:
        return []


def _list_gemini_models() -> list[str]:
    """Discover available Gemini models."""
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return []
    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        models = []
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                models.append(m.name.replace("models/", ""))
        return sorted(models)
    except Exception:
        return []


def _list_openai_models() -> list[str]:
    """Discover available OpenAI models."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return []
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        all_models = [m.id for m in client.models.list().data]
        known_prefixes = ("gpt-4o", "gpt-4.1", "gpt-4-turbo", "gpt-3.5", "o4", "o3", "o1")
        return sorted(m for m in all_models if any(m.startswith(p) for p in known_prefixes))
    except Exception:
        return []


def _list_anthropic_models() -> list[str]:
    """Return known Anthropic models (no list endpoint)."""
    if not os.getenv("ANTHROPIC_API_KEY"):
        return []
    return [
        "claude-opus-4-20250514",
        "claude-sonnet-4.5-20250514",
        "claude-sonnet-4-20250514",
        "claude-haiku-3.5-20241022",
    ]


def list_models(name: str) -> list[str] | None:
    """Return available models for a backend, or None if unsupported."""
    if name == "copilot-cli":
        return _list_copilot_models()
    if name == "github-api":
        return _list_github_api_models()
    if name == "gemini":
        return _list_gemini_models()
    if name == "openai":
        return _list_openai_models()
    if name == "anthropic":
        return _list_anthropic_models()
    if name == "cursor":
        return ["default"]
    return None


def print_model_catalog() -> None:
    """Print available models for every accessible backend."""
    for name in BACKENDS:
        try:
            ok, reason = is_available(name)
        except Exception:
            ok, reason = False, "check failed"
        default = BACKENDS[name]["default_model"]
        if not ok:
            print(f"\n{name}:  (unavailable — {reason})")
            continue
        models = list_models(name)
        if models is None:
            print(f"\n{name}:  default={default}  (no live catalog)")
        elif not models:
            print(f"\n{name}:  default={default}  (catalog query failed)")
        else:
            print(f"\n{name}:  (* = default)")
            for m in models:
                print(f"  {m} *" if m == default else f"  {m}")
