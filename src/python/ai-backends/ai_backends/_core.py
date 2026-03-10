"""ai_backends._core — Backend registry, callers, and availability checks."""

import os
import re
import base64
import subprocess
import logging
import shutil
from pathlib import Path

from . import _config
from ._backend_config import get_config

log = logging.getLogger("ai_backends")

# Use direct process execution for argv lists. On Windows, shell=True routes
# through cmd.exe and can mangle multiline prompt arguments.
SHELL = False

MIME_MAP = _config.MIME_MAP


def _resolve_command(command: str) -> str:
    """Resolve an executable name to an absolute path when possible."""
    resolved = shutil.which(command)
    if resolved:
        return resolved

    if os.name == "nt" and "." not in Path(command).name:
        for ext in (".cmd", ".exe", ".bat"):
            resolved = shutil.which(command + ext)
            if resolved:
                return resolved

    return command


def _prepare_command(cmd: list[str]) -> list[str]:
    """Normalize command argv and resolve the executable path."""
    if not cmd:
        return cmd
    prepared = [str(part) for part in cmd]
    prepared[0] = _resolve_command(prepared[0])
    return prepared


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

    api_key = get_config().gemini_api_key
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

    api_key = get_config().openai_api_key
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

    api_key = get_config().anthropic_api_key
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
    """Get GitHub token from env, config, or gh CLI."""
    token = get_config().github_token
    if token:
        return token
    try:
        cmd = _prepare_command(["gh", "auth", "token"])
        r = subprocess.run(
            cmd,
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
    base_url = get_config().github_models_base_url
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
    """Strip copilot CLI tool execution traces from output.

    Tool traces (● tool:, └ result, ✔ done, etc.) can appear anywhere in the
    output, not just at the top. Strip them throughout so that JSON extraction
    only sees the model's actual response.
    """
    lines = text.splitlines()
    cleaned: list[str] = []
    found_content = False
    for line in lines:
        stripped = line.lstrip()
        # Strip tool-trace lines throughout (not just at the top).
        if stripped.startswith(_config.COPILOT_OUTPUT_PREFIXES):
            continue
        # Skip leading blank lines before any real content.
        if not found_content and not stripped:
            continue
        found_content = True
        cleaned.append(line)
    return "\n".join(cleaned).strip()


_COPILOT_DEFAULT_ALLOW_TOOLS: tuple[str, ...] = ("read",)
_COPILOT_DEFAULT_DENY_TOOLS: tuple[str, ...] = ("shell", "write", "edit")


def _call_copilot(
    prompt: str,
    context_files: list[Path],
    model_name: str,
    allow_tools: list[str] | None = None,
    deny_tools: list[str] | None = None,
) -> str:
    """GitHub Copilot CLI — uses -p (prompt) with --add-path for context files."""
    full_prompt = (
        f"{prompt}\n\n"
        "STRICT OUTPUT REQUIREMENTS. "
        "Return only the requested final output. "
        "No preface text. No confirmations. No questions. "
        "If JSON is requested, return valid JSON only. "
        "NON-INTERACTIVE TASK. Do not ask questions. "
        "Do not provide options. Do not explain anything. "
        "Return only the requested output. "
        "No shell commands. No file edits."
    )

    effective_allow = allow_tools if allow_tools is not None else list(_COPILOT_DEFAULT_ALLOW_TOOLS)
    effective_deny = deny_tools if deny_tools is not None else list(_COPILOT_DEFAULT_DENY_TOOLS)

    cmd = ["copilot", "-p", full_prompt]
    for tool in effective_allow:
        cmd.extend(["--allow-tool", tool])
    for tool in effective_deny:
        cmd.extend(["--deny-tool", tool])
    web_fetch_allowed = "web_fetch" in effective_allow
    if web_fetch_allowed:
        cmd.append("--allow-all-urls")
    else:
        # --silent suppresses permission grants; only safe to use when
        # web_fetch is not needed (--no-ask-user also prevents prompts).
        cmd.append("--silent")
        cmd.append("--no-ask-user")
    if model_name and model_name != "default":
        cmd.extend(["--model", model_name])
    for f in context_files:
        cmd.extend(["--add-path", str(f.resolve())])

    cmd = _prepare_command(cmd)

    # Run in the directory of the first context file so that @filename
    # references in the prompt resolve correctly.
    cwd = str(context_files[0].parent) if context_files else None

    log.info(
        "copilot prompt stats: chars=%d lines=%d",
        len(full_prompt),
        full_prompt.count("\n") + 1,
    )
    log.info("copilot prompt:\n%s", full_prompt)
    log.info("copilot cmd (cwd=%s): %s", cwd, cmd)

    try:
        r = subprocess.run(
            cmd, capture_output=True, timeout=300, shell=SHELL, cwd=cwd,
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

    preamble = re.match(_config.COPILOT_PREAMBLE_REGEX, text, re.IGNORECASE)
    if preamble:
        text = text[preamble.end():]
        log.debug("copilot stripped preamble (%d chars removed)", preamble.end())

    low = text.lower()
    if "how can i assist" in low or "would you like me to" in low:
        log.warning("copilot returned generic reply (model=%s). Full output:\n%s",
                    model_name, text[:1000])
        raise RuntimeError(
            "copilot returned a generic assistant reply instead of task output; "
            "use a different backend/model"
        )
    if "i'm ready to assist" in low or "i am ready to assist" in low:
        log.warning("copilot returned generic ready-to-assist reply (model=%s). Full output:\n%s",
                    model_name, text[:1000])
        raise RuntimeError(
            "copilot returned a generic assistant readiness reply instead of task output; "
            "use a different backend/model"
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

    cmd = _prepare_command(cmd)

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
        **_config.BACKEND_SPECS["gemini"],
    },
    "openai": {
        "call": _call_openai,
        **_config.BACKEND_SPECS["openai"],
    },
    "anthropic": {
        "call": _call_anthropic,
        **_config.BACKEND_SPECS["anthropic"],
    },
    "github-api": {
        "call": _call_github,
        **_config.BACKEND_SPECS["github-api"],
    },
    "copilot-cli": {
        "call": _call_copilot,
        **_config.BACKEND_SPECS["copilot-cli"],
    },
    "cursor": {
        "call": _call_cursor,
        **_config.BACKEND_SPECS["cursor"],
    },
}

LLM_TYPES = _config.LLM_TYPES


def get_backend_default_model(backend_name: str, cache: dict | None = None) -> str:
    """Resolve backend default model from cached/generated model selection."""
    from . import _models

    return _models.resolve_backend_default_model(backend_name, cache=cache)


def call_backend(
    backend_name: str,
    prompt: str,
    context_files: list[Path] | Path | None = None,
    model: str | None = None,
    allow_tools: list[str] | None = None,
    deny_tools: list[str] | None = None,
    reasoning: bool | None = None,
) -> str:
    """Call a backend with a prompt and optional context files.

    Context files are attached using the mechanism for each backend type:
    - API backends: images are base64-encoded inline in the request; text files
      are prepended to the prompt.
    - CLI backends: files are provided via --add-path.

    ``allow_tools`` / ``deny_tools`` are forwarded to CLI backends that support
    tool restrictions (currently copilot-cli). API backends ignore them.

    ``reasoning`` is used at the call site only for model selection (via
    :func:`resolve_quality`); it is not forwarded to any backend.
    """
    if backend_name not in BACKENDS:
        raise ValueError(
            f"Unknown backend: {backend_name}. Available: {', '.join(BACKENDS)}"
        )
    files = _normalize_files(context_files)
    be = BACKENDS[backend_name]
    m = model or get_backend_default_model(backend_name)

    # API backends: inline text file contents into the prompt.
    # CLI backends pass files via their native mechanism (e.g. --add-path).
    if be.get("type") == "api" and files:
        text_parts: list[str] = []
        image_only: list[Path] = []
        for f in files:
            if f.suffix.lower() in MIME_MAP:
                image_only.append(f)
            elif f.exists():
                text_parts.append(f.read_text(encoding="utf-8"))
        if text_parts:
            prompt = "\n\n".join(text_parts) + "\n\n" + prompt
        files = image_only

    log.info("request %s/%s prompt:\n%s", backend_name, m, prompt)
    if files:
        log.info(
            "request %s/%s context_files: %s",
            backend_name,
            m,
            ", ".join(str(f.resolve()) for f in files),
        )

    if backend_name == "copilot-cli":
        response_text = be["call"](prompt, files, m,
                                   allow_tools=allow_tools, deny_tools=deny_tools)
    else:
        response_text = be["call"](prompt, files, m)

    log.info("response %s/%s:\n%s", backend_name, m, response_text)
    return response_text


def is_available(name: str) -> tuple[bool, str]:
    """Check if a backend is available. Returns (ok, reason_if_not)."""
    cfg = get_config()
    if name == "gemini":
        ok = bool(cfg.gemini_api_key)
        return (True, "") if ok else (False, "set GEMINI_API_KEY")
    if name == "openai":
        return (True, "") if cfg.openai_api_key else (False, "set OPENAI_API_KEY")
    if name == "anthropic":
        return (True, "") if cfg.anthropic_api_key else (False, "set ANTHROPIC_API_KEY")
    if name == "github-api":
        return (True, "") if get_github_token() else (False, "set GITHUB_TOKEN or gh auth login")
    if name == "copilot-cli":
        try:
            cmd = _prepare_command(["copilot", "--version"])
            r = subprocess.run(
                cmd,
                capture_output=True, text=True, timeout=15, shell=SHELL,
            )
            return (True, "") if r.returncode == 0 else (False, "copilot CLI not working")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return (False, "copilot CLI not installed")
    if name == "cursor":
        try:
            cmd = _prepare_command(["agent", "--version"])
            r = subprocess.run(
                cmd,
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
        cmd = _prepare_command(["copilot", "--help"])
        r = subprocess.run(
            cmd,
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
            base_url=get_config().github_models_base_url,
            api_key=token,
            max_retries=0,
            timeout=15.0,
        )
        candidates = _config.GITHUB_API_MODEL_CANDIDATES
        available = []
        for model in candidates:
            try:
                client.chat.completions.create(
                    model=model, max_tokens=1,
                    messages=[{"role": "user", "content": "hi"}],
                )
                available.append(model)
            except Exception as exc:
                message = str(exc).lower()
                if "429" in message or "rate limit" in message:
                    log.info("github-api probe rate-limited; stopping further model probes")
                    break
                continue
        return available
    except Exception:
        return []


def _list_gemini_models() -> list[str]:
    """Discover available Gemini models."""
    api_key = get_config().gemini_api_key
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
    api_key = get_config().openai_api_key
    if not api_key:
        return []
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        all_models = [m.id for m in client.models.list().data]
        known_prefixes = _config.OPENAI_MODEL_PREFIXES
        return sorted(m for m in all_models if any(m.startswith(p) for p in known_prefixes))
    except Exception:
        return []


def _list_anthropic_models() -> list[str]:
    """Return known Anthropic models (no list endpoint)."""
    if not get_config().anthropic_api_key:
        return []
    return _config.ANTHROPIC_KNOWN_MODELS


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
        return [_config.CURSOR_BOOTSTRAP_MODEL]
    return None


def print_model_catalog() -> None:
    """Print available models for every accessible backend."""
    for name in BACKENDS:
        try:
            ok, reason = is_available(name)
        except Exception:
            ok, reason = False, "check failed"
        if not ok:
            print(f"\n{name}:  (unavailable — {reason})")
            continue
        try:
            default = get_backend_default_model(name)
        except Exception:
            default = "(unresolved)"
        models = list_models(name)
        if models is None:
            print(f"\n{name}:  default={default}  (no live catalog)")
        elif not models:
            print(f"\n{name}:  default={default}  (catalog query failed)")
        else:
            print(f"\n{name}:  (* = default)")
            for m in models:
                print(f"  {m} *" if m == default else f"  {m}")
