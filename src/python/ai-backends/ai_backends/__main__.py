"""ai_backends CLI — send a prompt to any LLM backend from the terminal.

Usage:
  ai-backends -p "Summarize this topic"
  ai-backends -p "Describe this image" photo.jpg
  ai-backends -q high -p "OCR this scan" scan.png
  ai-backends -b copilot-cli -p "Explain this" doc.txt
  echo "What is 2+2?" | ai-backends
  ai-backends --list-models
  ai-backends --refresh-models
"""

import argparse
import logging
import sys
from pathlib import Path

import ai_backends


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
        "--list-models", action="store_true", dest="list_models",
        help="List available models for each backend and exit",
    )
    parser.add_argument(
        "--refresh-models", action="store_true", dest="refresh_models",
        help="Force-refresh the model registry cache and exit",
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="Increase verbosity (-v info, -vv debug)",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    logging.basicConfig(
        level=[logging.WARNING, logging.INFO, logging.DEBUG][min(args.verbose, 2)],
        format="%(levelname)s [%(name)s] %(message)s",
    )

    if args.list_models:
        ai_backends.print_model_catalog()
        return

    if args.refresh_models:
        ai_backends.refresh_registry()
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

    # ── Resolve backend / model ───────────────────────────────────────────────
    if args.quality:
        cache = ai_backends.ensure_registry()
        backend, model = ai_backends.resolve_quality(args.quality, cache, vision=vision)
        logging.getLogger("ai_backends").info(
            "Quality '%s' -> %s/%s", args.quality, backend, model
        )
    elif args.backend:
        backend = args.backend
        model = args.model or ai_backends.BACKENDS[backend]["default_model"]
    else:
        cache = ai_backends.ensure_registry()
        backend, model = ai_backends.resolve_quality("normal", cache, vision=vision)
        logging.getLogger("ai_backends").info(
            "Auto-selected %s/%s", backend, model
        )

    # ── Call ──────────────────────────────────────────────────────────────────
    result = ai_backends.call_backend(backend, prompt,
                                      context_files=context_files, model=model)
    print(result)


if __name__ == "__main__":
    main()
