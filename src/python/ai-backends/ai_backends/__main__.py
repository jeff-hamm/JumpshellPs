"""ai_backends CLI — send a prompt to any LLM backend from the terminal.

Usage:
  ai-backends -p "Summarize this topic"
  ai-backends -p "Describe this image" photo.jpg
  ai-backends -q high -p "OCR this scan" scan.png
  ai-backends -b copilot-cli -p "Explain this" doc.txt
  echo "What is 2+2?" | ai-backends
  ai-backends --list-models
  ai-backends --refresh-models
    ai-backends --regenerate-available-models
    ai-backends --refresh-model-rules openai
    ai-backends --refresh-default-models github-api
  ai-backends --configure
  ai-backends --configure --json --stdout
  ai-backends --configure -o ~/.config/ai_backends/config.json --json
"""

import argparse
import getpass
import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

import ai_backends
from ai_backends import _config


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ai-backends",
        description="Send a prompt to any AI backend from the terminal.",
        epilog="""\
Examples:
  ai-backends -p "Summarize this"
  ai-backends -q normal -p "Describe this" photo.jpg
  ai-backends -b copilot-cli -p "What year is this?" scan.png
  echo "Explain quantum entanglement" | ai-backends
  ai-backends --list-models
  ai-backends --regenerate-available-models
    ai-backends --refresh-model-rules openai
    ai-backends --refresh-default-models github-api
""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "files", nargs="*", metavar="FILE",
        help="Context files to attach (images, documents)",
    )
    parser.add_argument(
        "-p", "--prompt", default=None,
        help="Prompt text. Reads from stdin if omitted.",
    )
    parser.add_argument(
        "-b", "--backend", choices=list(ai_backends.BACKENDS), default=None,
        help="Backend to use",
    )
    parser.add_argument(
        "-m", "--model", default=None,
        help="Model override for the chosen backend",
    )
    parser.add_argument(
        "-q", "--quality", "--tier",
        choices=["low", "fast", "normal", "default", "high", "slow"],
        default=None, dest="quality",
        help="Quality tier: low/fast (free), normal/default (standard), high/slow (best)",
    )
    parser.add_argument(
        "--vision", action="store_true",
        help="Force vision-aware quality selection (auto-detected from file extensions)",
    )
    parser.add_argument(
        "--reasoning", action="store_true", default=False,
        help="Select a reasoning-capable model for quality resolution",
    )
    parser.add_argument(
        "--list-models", action="store_true", dest="list_models",
        help="List available models for each backend and exit",
    )
    parser.add_argument(
        "--refresh-models", action="store_true", dest="refresh_models",
        help="Force-refresh the model registry cache and exit",
    )
    parser.add_argument(
        "--regenerate-available-models",
        nargs="?",
        const=_config.DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH,
        metavar="PATH",
        default=None,
        dest="regenerate_available_models",
        help=(
            "Refresh the model registry and regenerate available-models "
            "Markdown for currently available backends. This does not "
            "regenerate prompt-generated model rules or backend default models. "
            "Optional PATH (default: "
            f"{_config.DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH})."
        ),
    )
    parser.add_argument(
        "--refresh-model-rules",
        nargs="*",
        metavar="BACKEND",
        default=None,
        dest="refresh_model_rules",
        help=(
            "Regenerate per-model metadata and scoring by prompting each selected backend. "
            "Provide one or more backend names; omit names to refresh all available backends."
        ),
    )
    parser.add_argument(
        "--refresh-default-models",
        nargs="*",
        metavar="BACKEND",
        default=None,
        dest="refresh_default_models",
        help=(
            "Regenerate backend default_model selections by prompting each selected backend. "
            "Provide one or more backend names; omit names to refresh all available backends."
        ),
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="Increase verbosity (-v info, -vv debug)",
    )
    parser.add_argument(
        "--configure", action="store_true", dest="configure",
        help="Interactively configure backend credentials and CLI tools",
    )
    parser.add_argument(
        "--json", action="store_true", dest="config_json",
        help="With --configure: output JSON instead of .env format",
    )
    parser.add_argument(
        "--stdout", action="store_true", dest="config_stdout",
        help="With --configure: write configuration to stdout instead of a file",
    )
    parser.add_argument(
        "-o", "--output", default=None, dest="config_output", metavar="PATH",
        help="With --configure: write configuration to the specified file path",
    )
    return parser


# ── --configure implementation ────────────────────────────────────────────────

# API backends: (name, env_keys, hint)
_API_BACKENDS = [
    ("gemini", ["GEMINI_API_KEY"], "Get a free key at https://aistudio.google.com/apikey"),
    ("openai", ["OPENAI_API_KEY"], "Get a key at https://platform.openai.com/api-keys"),
    ("anthropic", ["ANTHROPIC_API_KEY"], "Get a key at https://console.anthropic.com/settings/keys"),
    ("github-api", ["GITHUB_TOKEN"], "Run: gh auth login  — or create a PAT at https://github.com/settings/tokens"),
]

# CLI backends: (name, command, install_hint)
_CLI_BACKENDS = [
    ("copilot-cli", "copilot", "npm install -g @anthropic-ai/copilot  (or see GitHub Copilot docs)"),
    ("cursor", "agent", "Install from https://cursor.com"),
]

# Env vars the copilot CLI checks (in precedence order)
_COPILOT_TOKEN_VARS = ("COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN")


def _prompt_secret(prompt_text: str) -> str | None:
    """Prompt for a secret value, hiding input."""
    try:
        value = getpass.getpass(prompt_text).strip()
        return value if value else None
    except (EOFError, KeyboardInterrupt):
        return None


def _prompt_yesno(prompt_text: str, default: bool = True) -> bool:
    """Simple y/n prompt."""
    suffix = " [Y/n]: " if default else " [y/N]: "
    try:
        answer = input(prompt_text + suffix).strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return default
    if not answer:
        return default
    return answer.startswith("y")


def _mask(value: str) -> str:
    """Mask a secret for display."""
    return value[:4] + "..." + value[-4:] if len(value) > 12 else "****"


def _check_cli_installed(command: str) -> tuple[bool, str]:
    """Check if a CLI command is available. Returns (installed, version_info)."""
    resolved = shutil.which(command)
    if resolved:
        try:
            r = subprocess.run(
                [resolved, "--version"],
                capture_output=True, text=True, timeout=15,
            )
            version = r.stdout.strip() or r.stderr.strip() or "installed"
            return True, version
        except Exception:
            return True, "installed (version check failed)"
    return False, "not found"


# ── Copilot CLI auth ──────────────────────────────────────────────────────────

def _check_copilot_auth() -> tuple[bool, str]:
    """Check if copilot CLI has authentication available.

    Returns (is_authed, description) — checks env vars, the copilot
    config.json logged-in users, and the gh CLI token.
    """
    # 1. Env vars the copilot CLI checks
    for var in _COPILOT_TOKEN_VARS:
        if os.environ.get(var):
            return True, f"via ${var}"

    # 2. copilot's own login state: ~/.copilot/config.json → logged_in_users
    config_path = Path.home() / ".copilot" / "config.json"
    if config_path.is_file():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
            users = data.get("logged_in_users", [])
            if users:
                last = data.get("last_logged_in_user", {})
                login = last.get("login", users[0].get("login", ""))
                return True, f"logged in as {login}"
        except (json.JSONDecodeError, OSError):
            pass

    # 3. gh CLI token (copilot can also pick this up)
    try:
        r = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True, text=True, timeout=15,
        )
        if r.returncode == 0 and r.stdout.strip():
            return True, "via gh CLI"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return False, ""


def _configure_copilot(config: dict[str, str]) -> None:
    """Copilot CLI authentication flow."""
    authed, via = _check_copilot_auth()

    if authed:
        print(f"  ✓ Authenticated ({via})")
        if not _prompt_yesno("  Change authentication?", default=False):
            return
    else:
        print("  ✗ Not authenticated")

    # Offer reuse of GITHUB_TOKEN already collected in this session
    if "GITHUB_TOKEN" in config:
        masked = _mask(config["GITHUB_TOKEN"])
        if _prompt_yesno(f"  Reuse GITHUB_TOKEN ({masked}) for copilot?"):
            print("  → Copilot will pick up GITHUB_TOKEN from the environment")
            return

    print()
    print("  Options:")
    print("    1. Enter a GitHub token (fine-grained PAT with 'Copilot Requests' permission)")
    print("    2. Run 'copilot login' (opens browser for OAuth)")
    print()
    token = _prompt_secret("  GitHub token (or press Enter for copilot login): ")

    if token:
        config["COPILOT_GITHUB_TOKEN"] = token
        print("  → Saved COPILOT_GITHUB_TOKEN")
    else:
        print("  Launching 'copilot login' — follow the prompts in your browser...")
        try:
            subprocess.run(["copilot", "login"], timeout=300)
        except subprocess.TimeoutExpired:
            print("  ⚠ Login timed out — run 'copilot login' manually later")
        except FileNotFoundError:
            print("  ⚠ copilot command not found")


# ── Cursor CLI auth ───────────────────────────────────────────────────────────

def _check_cursor_auth() -> tuple[bool, str]:
    """Check if the Cursor agent CLI works (it uses the Cursor app session)."""
    try:
        r = subprocess.run(
            ["agent", "--version"],
            capture_output=True, text=True, timeout=15,
        )
        if r.returncode == 0:
            return True, "Cursor session active"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return False, "Cursor session not detected"


def _configure_cursor(config: dict[str, str]) -> None:
    """Cursor CLI authentication flow — delegates to the Cursor app."""
    authed, via = _check_cursor_auth()
    if authed:
        print(f"  ✓ {via}")
        print("  (Cursor authenticates via the desktop app — no token needed)")
    else:
        print(f"  ✗ {via}")
        print("  Log in through the Cursor desktop app, then re-run configure")


# ── Main configure flow ──────────────────────────────────────────────────────

# Backend-specific configure dispatchers
_CLI_CONFIGURE = {
    "copilot-cli": _configure_copilot,
    "cursor": _configure_cursor,
}


def run_configure(
    *,
    as_json: bool = False,
    to_stdout: bool = False,
    output_path: str | None = None,
) -> None:
    """Interactively configure backends, then write config file or stdout."""
    config: dict[str, str] = {}
    enabled: list[str] = []

    print("=" * 60)
    print("  ai-backends: Interactive Configuration")
    print("=" * 60)
    print()

    # ── API backends ──────────────────────────────────────────────────────
    for backend_name, env_keys, hint in _API_BACKENDS:
        print(f"── {backend_name} ──")
        print(f"  {hint}")

        # Show existing values
        existing = {k: v for k in env_keys if (v := ai_backends.get_config().get(k))}
        if existing:
            masked = {k: _mask(v) for k, v in existing.items()}
            print(f"  Current: {masked}")

        if not _prompt_yesno(f"  Enable {backend_name}?"):
            print()
            continue

        enabled.append(backend_name)

        for key in env_keys:
            value = _prompt_secret(f"  {key}: ")
            if value:
                config[key] = value
            else:
                # Preserve existing if user skips
                val = ai_backends.get_config().get(key)
                if val:
                    config[key] = val
                    print(f"    (kept existing {key})")
        print()

    # ── CLI backends ──────────────────────────────────────────────────────
    for backend_name, cli_command, install_hint in _CLI_BACKENDS:
        print(f"── {backend_name} ──")
        installed, info = _check_cli_installed(cli_command)

        if not installed:
            print(f"  ✗ {cli_command}: {info}")
            print(f"  Install: {install_hint}")
            print()
            continue

        print(f"  ✓ {cli_command}: {info}")

        if not _prompt_yesno(f"  Enable {backend_name}?"):
            print()
            continue

        enabled.append(backend_name)

        # Run backend-specific auth configuration
        configure_fn = _CLI_CONFIGURE.get(backend_name)
        if configure_fn:
            configure_fn(config)
        print()

    if not config and not enabled:
        print("No backends enabled.")
        return

    # ── Output ────────────────────────────────────────────────────────────
    from ai_backends._backend_config import ENABLED_BACKENDS_KEY

    if as_json:
        output = dict(config)
        output[ENABLED_BACKENDS_KEY] = enabled
        output_text = json.dumps(output, indent=2) + "\n"
        default_ext = ".json"
    else:
        lines: list[str] = []
        for k, v in sorted(config.items()):
            safe = v.replace('"', '\\"')
            lines.append(f'{k}="{safe}"')
        lines.append(f'{ENABLED_BACKENDS_KEY}="{",".join(enabled)}"')
        output_text = "\n".join(lines) + "\n"
        default_ext = ".env"

    if to_stdout:
        sys.stdout.write(output_text)
        return

    if output_path:
        dest = Path(output_path).expanduser()
    else:
        dest = Path.cwd() / f"ai-backends{default_ext}"

    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(output_text, encoding="utf-8")
    print(f"Configuration written to {dest}")


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    log_level = [logging.WARNING, logging.INFO, logging.DEBUG][min(args.verbose, 2)]
    logging.basicConfig(
        level=log_level,
        format="%(levelname)s [%(name)s] %(message)s",
        force=True,
    )
    logging.getLogger("ai_backends").setLevel(log_level)

    mode_flags = [
        args.list_models,
        args.refresh_models,
        args.regenerate_available_models is not None,
        args.refresh_model_rules is not None,
        args.refresh_default_models is not None,
        args.configure,
    ]
    if sum(bool(flag) for flag in mode_flags) > 1:
        parser.error(
            "Choose only one of: --list-models, --refresh-models, "
            "--regenerate-available-models, --refresh-model-rules, "
            "--refresh-default-models, --configure"
        )

    if args.configure:
        run_configure(
            as_json=args.config_json,
            to_stdout=args.config_stdout,
            output_path=args.config_output,
        )
        return

    if args.list_models:
        ai_backends.print_model_catalog()
        return

    if args.regenerate_available_models is not None:
        doc_path = Path(args.regenerate_available_models).expanduser()
        ai_backends.refresh_registry(reference_doc_path=doc_path)
        print(f"Regenerated {doc_path.resolve()}")
        return

    if args.refresh_models:
        ai_backends.refresh_registry(
            reference_doc_path=Path(_config.DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH),
        )
        return

    if args.refresh_model_rules is not None:
        backends = []
        for backend in args.refresh_model_rules:
            if backend not in ai_backends.BACKENDS:
                parser.error(
                    f"Unknown backend '{backend}'. "
                    f"Available: {', '.join(ai_backends.BACKENDS)}"
                )
            if backend not in backends:
                backends.append(backend)
        ai_backends.refresh_model_rules(
            backends=backends,
            reference_doc_path=Path(_config.DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH),
        )
        if backends:
            print(f"Refreshed model rules for: {', '.join(backends)}")
        else:
            print("Refreshed model rules for all available backends")
        return

    if args.refresh_default_models is not None:
        backends = []
        for backend in args.refresh_default_models:
            if backend not in ai_backends.BACKENDS:
                parser.error(
                    f"Unknown backend '{backend}'. "
                    f"Available: {', '.join(ai_backends.BACKENDS)}"
                )
            if backend not in backends:
                backends.append(backend)
        ai_backends.refresh_backend_default_models(
            backends=backends,
            reference_doc_path=Path(_config.DEFAULT_REGENERATE_AVAILABLE_MODELS_PATH),
        )
        if backends:
            print(f"Refreshed backend defaults for: {', '.join(backends)}")
        else:
            print("Refreshed backend defaults for all available backends")
        return

    if args.quality and (args.backend or args.model):
        parser.error("--quality cannot be combined with -b/--backend or -m/--model")

    # ── Resolve prompt ────────────────────────────────────────────────────────
    prompt = args.prompt
    if prompt is None:
        if sys.stdin.isatty():
            parser.error("Provide a prompt via -p/--prompt or stdin")
        prompt = sys.stdin.read().strip()
        if not prompt:
            parser.error("Prompt is empty")

    # ── Resolve context files ─────────────────────────────────────────────────
    context_files = [Path(f) for f in args.files] if args.files else None

    # ── Auto-detect vision need ───────────────────────────────────────────────
    vision = args.vision or (
        context_files is not None and ai_backends.has_images(context_files)
    )
    reasoning = args.reasoning

    # ── Resolve backend / model ───────────────────────────────────────────────
    if args.quality:
        cache = ai_backends.ensure_registry()
        backend, model = ai_backends.resolve_quality(args.quality, cache, vision=vision, reasoning=reasoning)
        logging.getLogger("ai_backends").info(
            "Quality '%s' -> %s/%s", args.quality, backend, model
        )
    elif args.backend:
        backend = args.backend
        model = args.model or ai_backends.resolve_backend_default_model(backend)
    else:
        cache = ai_backends.ensure_registry()
        backend, model = ai_backends.resolve_quality("normal", cache, vision=vision, reasoning=reasoning)
        logging.getLogger("ai_backends").info(
            "Auto-selected %s/%s", backend, model
        )

    # ── Call ──────────────────────────────────────────────────────────────────
    result = ai_backends.call_backend(backend, prompt,
                                      context_files=context_files, model=model,
                                      reasoning=reasoning)
    print(result)


if __name__ == "__main__":
    main()
