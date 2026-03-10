"""
OCR handwritten scanned notes to Markdown.

Uses the ai_backends module for multi-provider LLM access with quality-based
model selection.

Usage:
  python ocr_scan.py                            # default backend (copilot-cli)
  python ocr_scan.py -q normal "scan.jpg"       # quality-based model selection
  python ocr_scan.py -q high "scans/"           # best model, whole directory
  python ocr_scan.py -b copilot-cli "scan.jpg"  # explicit backend
  python ocr_scan.py --resume                   # skip files with existing output
  python ocr_scan.py --force                    # regenerate everything
  python ocr_scan.py --refresh-models           # refresh model registry cache

Quality tiers (--quality / -q):
  low  / fast    : best free, vision-capable model
  normal / default : best standard-cost model
  high / slow    : best possible model at any cost
"""

import os
import sys
import re
import argparse
import logging
import time
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import Sequence

import ai_backends

log = logging.getLogger("ocr_scan")


# ── Local easyocr backend (OCR-specific, not in ai_backends) ────────────────

_easyocr_reader = None


def _ocr_easyocr(image_path: Path, model_name: str) -> str:
    """EasyOCR local backend — traditional OCR, no LLM."""
    global _easyocr_reader
    try:
        import easyocr
    except ImportError:
        raise RuntimeError("pip install easyocr  (first run downloads ~100 MB model)")
    if _easyocr_reader is None:
        langs = model_name.split("+") if model_name else ["en"]
        print(f"       Loading EasyOCR ({'+'.join(langs)}) ...")
        _easyocr_reader = easyocr.Reader(langs, gpu=False)
    results = _easyocr_reader.readtext(str(image_path), detail=0, paragraph=True)
    return "\n\n".join(results)


def _is_easyocr_available() -> tuple[bool, str]:
    try:
        import easyocr  # noqa: F401
        return True, ""
    except ImportError:
        return False, "pip install easyocr"


_LOCAL_BACKENDS = {
    "easyocr": {"default_model": "en", "type": "traditional"},
}
ALL_BACKENDS = {**ai_backends.BACKENDS, **_LOCAL_BACKENDS}


APP_VERSION = "3.3.0"

SCRIPT_DIR = Path(__file__).parent
DEFAULT_INPUT_DIR = Path.cwd()
INPUT_DIR = Path(os.getenv("OCR_INPUT_DIR", str(DEFAULT_INPUT_DIR))).expanduser()

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".tiff", ".tif", ".bmp", ".webp"}

_REFERENCE_DOC_PATH = SCRIPT_DIR / ".." / "references" / "available-models.md"


# ── Load .env ─────────────────────────────────────────────────────────────────

ai_backends.load_dotenv(SCRIPT_DIR / ".env")


# ── OCR-specific prompts ──────────────────────────────────────────────────────

TRANSCRIPTION_PROMPT = """\
You are an expert forensic document transcriber specializing in handwritten text.

Produce a faithful, complete transcription of ALL handwritten text in this scanned \
document image, formatted as clean Markdown.

Rules:
1. ACCURACY -- Transcribe every word exactly as written. Preserve original spelling, \
abbreviations, punctuation, and capitalization.
2. STRUCTURE -- Maintain the document's visual layout using Markdown:
   - Titles or headers become # or ## headings
   - Dashed / bulleted / numbered lists become Markdown list syntax
   - Addresses, datelines: preserve line breaks
   - Paragraphs: separate with blank lines
3. EMPHASIS -- Underlined text becomes **bold**. Circled or boxed text becomes **bold**.
4. SIGNATURES -- Transcribe as *[Signature: Best-reading-of-name]* when partially \
readable, or *[Signature: illegible]* when not.
5. UNCERTAINTY -- If a word is unclear, give your best reading followed by [?]. \
Example: "recieved [?]"
6. CROSSED-OUT TEXT -- Render as ~~strikethrough~~. Interlinear additions in \
(parentheses with note).
7. COMPLETENESS -- Include ALL text: headers, footers, dates, addresses, margin \
notes, page numbers, "cc:" lines, everything.

Output ONLY the transcription. No commentary, no code blocks, no preamble.\
"""

NAME_PROMPT = """\
You are naming a scanned handwritten legal note file.

Given the image and OCR transcript, propose:
1) A concise descriptive filename title (3-8 words max)
2) The document date if clearly present in the note

Rules:
- Return STRICT JSON only: {"title":"...","document_date":"YYYY-MM-DD or null"}
- "title" must be filesystem-safe words only (letters, numbers, spaces, hyphen)
- No punctuation except hyphen in title words
- Prefer a specific topic like "Move Out Notice" instead of generic "Handwritten Note"
- document_date must be YYYY-MM-DD if visible; otherwise null

OCR transcript context:
{transcript}
"""


# ── Resume helpers ────────────────────────────────────────────────────────────

def _read_signature(md_path: Path) -> dict[str, str | None]:
    result: dict[str, str | None] = {
        "app_version": None, "backend": None, "model": None,
    }
    if not md_path.exists():
        return result
    text = md_path.read_text(encoding="utf-8")
    for key, tag in [
        ("app_version", "APP_VERSION"), ("backend", "BACKEND"),
        ("model", "MODEL"),
    ]:
        m = re.search(rf"<!--\s*{tag}:\s*(.+?)\s*-->", text)
        if m:
            result[key] = m.group(1).strip()
    return result


def _should_skip(
    output: Path, resume: bool, force: bool, backend: str, model: str,
) -> tuple[bool, str]:
    if force:
        return False, "force"
    if not output.exists():
        return False, "missing"
    if resume:
        return True, "resume"
    sig = _read_signature(output)
    if (
        sig["app_version"] == APP_VERSION
        and sig["backend"] == backend
        and sig["model"] == model
    ):
        return True, "up-to-date"
    return False, "stale"


# ── Output helpers ────────────────────────────────────────────────────────────

def _build_output(
    stem: str, img_name: str, transcript: str, backend: str, model: str,
) -> str:
    def _yaml_quote(value: str) -> str:
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'

    def _default_title(value: str) -> str:
        cleaned = re.sub(r"[_.-]+", " ", value).strip()
        cleaned = re.sub(r"\s+", " ", cleaned)
        return cleaned or "OCR Document"

    page_title = _default_title(stem)
    for line in transcript.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        m = re.match(r"^#{1,6}\s+(.+)$", stripped)
        if m and m.group(1).strip():
            page_title = m.group(1).strip()
            break

    return "\n".join([
        "---",
        f"title: {_yaml_quote(page_title)}",
        "layout: page-two-col",
        "parent: \"Notes from Cheri\"",
        "---",
        "",
        f"# {stem}",
        "",
        f"**Source:** `{img_name}`  ",
        f"![Source image](./{img_name})",
        f"**OCR Backend:** {backend} (`{model}`)  ",
        f"**Transcribed:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  ",
        f"<!-- APP_VERSION: {APP_VERSION} -->",
        f"<!-- BACKEND: {backend} -->",
        f"<!-- MODEL: {model} -->",
        "",
        "---",
        "",
        transcript.strip(),
        "",
    ])


# ── OCR dispatch ──────────────────────────────────────────────────────────────

def _run_ocr(image_path: Path, backend: str, model: str) -> str:
    log.info("OCR start: %s/%s on %s", backend, model, image_path.name)
    t0 = time.monotonic()
    if backend == "easyocr":
        text = _ocr_easyocr(image_path, model)
    else:
        text = ai_backends.call_backend(
            backend, TRANSCRIPTION_PROMPT, [image_path], model,
        )
    elapsed = time.monotonic() - t0
    log.info("OCR done: %s/%s -> %d chars in %.1fs", backend, model, len(text), elapsed)
    return text


# ── Processing helpers ────────────────────────────────────────────────────────

def _extract_json_object(text: str) -> dict:
    raw = text.strip()
    if raw.startswith("```") and raw.endswith("```"):
        raw = raw[raw.index("\n") + 1 : raw.rindex("```")].strip()
    start = raw.find("{")
    end = raw.rfind("}")
    if start >= 0 and end > start:
        raw = raw[start : end + 1]
    return json.loads(raw)


def _slugify_filename_title(title: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9 -]+", " ", title)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    cleaned = cleaned.replace(" ", "-")
    cleaned = re.sub(r"-{2,}", "-", cleaned).strip("-")
    if not cleaned:
        return "handwritten-note"
    return cleaned.lower()[:80]


def _scan_date_from_image(image_path: Path) -> str:
    # Example: scan-2026.02.28-6U34BER.jpg
    m = re.search(r"(\d{4})[._-](\d{2})[._-](\d{2})", image_path.name)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"
    return datetime.fromtimestamp(image_path.stat().st_mtime).strftime("%Y-%m-%d")


def _normalize_doc_date(value: str | None) -> str | None:
    if not value:
        return None
    v = value.strip()
    if not v or v.lower() == "null":
        return None
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", v):
        return v
    for fmt in ("%m/%d/%y", "%m/%d/%Y", "%b %d, %Y", "%B %d, %Y"):
        try:
            return datetime.strptime(v, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None


def _fallback_title_from_transcript(transcript: str) -> str:
    lines = [ln.strip() for ln in transcript.splitlines() if ln.strip()]
    for ln in lines:
        if ln.startswith("#"):
            return _slugify_filename_title(ln.lstrip("# ").strip())
    if lines:
        return _slugify_filename_title(lines[0][:80])
    return "handwritten-note"


def _suggest_filename_metadata(
    image_path: Path,
    transcript: str,
    backend: str,
    model: str,
) -> tuple[str, str | None]:
    prompt = NAME_PROMPT.replace("{transcript}", transcript[:3000])
    try:
        raw = ai_backends.call_backend(backend, prompt, [image_path], model)
        obj = _extract_json_object(raw)
        title = _slugify_filename_title(str(obj.get("title", "")).strip())
        doc_date = _normalize_doc_date(
            None if obj.get("document_date", None) is None else str(obj.get("document_date"))
        )
        if not title:
            title = _fallback_title_from_transcript(transcript)
        return title, doc_date
    except Exception:
        # Heuristic fallback keeps run robust if naming pass fails.
        return _fallback_title_from_transcript(transcript), None


def _find_unique_destination(dest: Path) -> Path:
    if not dest.exists():
        return dest
    base = dest.stem
    suffix = dest.suffix
    parent = dest.parent
    i = 2
    while True:
        cand = parent / f"{base}-{i}{suffix}"
        if not cand.exists():
            return cand
        i += 1


def _rename_pair(
    src_img: Path,
    src_md: Path,
    dst_img: Path,
    dst_md: Path,
) -> tuple[Path, Path]:
    dst_img_unique = _find_unique_destination(dst_img) if src_img != dst_img else src_img
    # Keep md stem aligned with final image filename.
    intended_md = dst_img_unique.with_name(f"{dst_img_unique.name}.ocr.md")
    dst_md_unique = _find_unique_destination(intended_md) if src_md != intended_md else src_md
    src_img.rename(dst_img_unique)
    src_md.rename(dst_md_unique)
    return dst_img_unique, dst_md_unique


def _process_images(
    images: Sequence[Path],
    be_name: str,
    model: str,
    resume: bool,
    force: bool,
    no_rename: bool = False,
) -> tuple[int, int]:
    """Run OCR on all images. Output is colocated next to each source. Returns (ok, fail)."""
    ok = fail = 0
    n = len(images)
    pending_renames: list[dict] = []
    for idx, img in enumerate(images, 1):
        tag = f"[{idx}/{n}]"
        out = img.with_name(f"{img.name}.ocr.md")
        skip, reason = _should_skip(out, resume, force, be_name, model)

        if skip:
            print(f"{tag} SKIP ({reason}): {img.name}")
            continue
        if not img.exists():
            print(f"{tag} SKIP (not found): {img.name}")
            continue

        print(f"{tag} {img.name}")
        try:
            t0 = time.monotonic()
            transcript = _run_ocr(img, be_name, model)
            elapsed = time.monotonic() - t0
            md = _build_output(img.stem, img.name, transcript, be_name, model)
            out.write_text(md, encoding="utf-8")
            print(f"{tag}   {len(transcript)} chars in {elapsed:.1f}s")
            if not no_rename:
                title_slug, doc_date = _suggest_filename_metadata(img, transcript, be_name, model)
                prefix_date = doc_date or _scan_date_from_image(img)
                pending_renames.append(
                    {
                        "idx": idx,
                        "date": prefix_date,
                        "title": title_slug,
                        "img": img,
                        "md": out,
                        "tag": tag,
                    }
                )
            ok += 1
        except Exception as exc:
            print(f"{tag}   ERROR: {exc}")
            fail += 1

    if not no_rename and pending_renames:
        grouped: dict[str, list[dict]] = defaultdict(list)
        for entry in pending_renames:
            grouped[entry["date"]].append(entry)

        for date_key, entries in grouped.items():
            entries.sort(key=lambda e: e["idx"])
            include_order = len(entries) > 1
            for order, entry in enumerate(entries, 1):
                if include_order:
                    base_name = f"{date_key}-{order:02d}_{entry['title']}"
                else:
                    base_name = f"{date_key}_{entry['title']}"
                dst_img = entry["img"].with_name(f"{base_name}{entry['img'].suffix.lower()}")
                dst_md = dst_img.with_name(f"{dst_img.name}.ocr.md")
                final_img, final_md = _rename_pair(entry["img"], entry["md"], dst_img, dst_md)
                print(f"{entry['tag']}   -> {final_img.name}")
                print(f"{entry['tag']}   -> {final_md.name}")

    return ok, fail


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OCR handwritten scanned notes to Markdown.",
    )
    parser.add_argument(
        "paths", nargs="*", metavar="PATH",
        help="Image files or directories to scan (default: all images in cwd)",
    )
    parser.add_argument(
        "-b", "--backend", choices=list(ALL_BACKENDS), default=None,
        help="Backend for OCR (env: OCR_BACKEND, default: copilot-cli)",
    )
    parser.add_argument(
        "-m", "--model", default=None,
        help="Override model for the chosen backend",
    )
    parser.add_argument(
        "-q", "--quality",
        choices=["low", "fast", "normal", "default", "high", "slow"],
        default=None,
        help="Quality tier: low/fast (best free), normal/default (standard), high/slow (best)",
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Skip any file that already has output",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Overwrite all existing output",
    )
    parser.add_argument(
        "--no-rename", action="store_true", dest="no_rename",
        help="Skip auto-renaming files after OCR; write output next to source as-is",
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="Increase verbosity (-v info, -vv debug)",
    )
    parser.add_argument(
        "--list-models", action="store_true", dest="list_models",
        help="List available models for each backend and exit",
    )
    parser.add_argument(
        "--refresh-models", action="store_true", dest="refresh_models",
        help="Force-refresh the model registry cache and exit",
    )
    args = parser.parse_args()

    # ── Configure logging ────────────────────────────────────────────
    level = logging.WARNING
    if args.verbose >= 2:
        level = logging.DEBUG
    elif args.verbose >= 1:
        level = logging.INFO
    logging.basicConfig(
        level=level,
        format="%(levelname)s [%(name)s] %(message)s",
    )

    if args.list_models:
        ai_backends.print_model_catalog()
        return

    if args.refresh_models:
        ai_backends.refresh_registry(reference_doc_path=_REFERENCE_DOC_PATH)
        return

    if args.resume and args.force:
        parser.error("--resume and --force are mutually exclusive")

    if args.quality and (args.backend or args.model):
        parser.error("--quality cannot be combined with -b/--backend or -m/--model")

    # ── Resolve backend / model ──────────────────────────────────────
    cache = ai_backends.ensure_registry(reference_doc_path=_REFERENCE_DOC_PATH)

    if args.quality:
        be_name, model = ai_backends.resolve_quality(args.quality, cache, vision=True)
        tier = ai_backends.QUALITY_SYNONYMS.get(args.quality, args.quality)
        print(f"Quality '{tier}' -> {be_name}/{model}\n")
    else:
        be_name = args.backend or os.getenv("OCR_BACKEND", "copilot-cli")
        model = args.model or ALL_BACKENDS[be_name]["default_model"]

    # ── Gather images (files and/or directories) ─────────────────────
    if args.paths:
        images: list[Path] = []
        for p_str in args.paths:
            p = Path(p_str) if Path(p_str).is_absolute() else INPUT_DIR / p_str
            if p.is_dir():
                dir_imgs = sorted(
                    f for f in p.iterdir()
                    if f.suffix.lower() in IMAGE_EXTENSIONS
                )
                images.extend(dir_imgs)
                if dir_imgs:
                    print(f"Found {len(dir_imgs)} image(s) in {p}")
            elif p.suffix.lower() in IMAGE_EXTENSIONS:
                images.append(p)
            else:
                print(f"Skipping non-image: {p}")
    else:
        images = sorted(
            f for f in INPUT_DIR.iterdir()
            if f.suffix.lower() in IMAGE_EXTENSIONS
        )

    if not images:
        print("No images found.")
        sys.exit(1)

    print(f"Found {len(images)} image(s) total.\n")

    # ── Check backend availability ───────────────────────────────────────
    if be_name == "easyocr":
        ok, reason = _is_easyocr_available()
    else:
        ok, reason = ai_backends.is_available(be_name)
    if not ok:
        print(f"ERROR: {be_name} unavailable ({reason})")
        sys.exit(1)

    print(f"Backend: {be_name} ({model})\n")
    ok_n, fail_n = _process_images(
        images, be_name, model, args.resume, args.force,
        no_rename=args.no_rename,
    )
    print(f"\n{ok_n} transcribed, {fail_n} error(s).")
    print("OCR files were written next to each source image as '*.ocr.md'.")


if __name__ == "__main__":
    main()
