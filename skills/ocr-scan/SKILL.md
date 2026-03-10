---
name: ocr-scan
description: "OCR images of handwritten or scanned documents to Markdown. Use for requests like 'transcribe image', 'OCR this scan', 'convert handwriting to text', 'read scanned notes', 'extract text from image', or any .jpg/.png/.tiff OCR task. Supports 7 backends including copilot-cli, github-api, gemini, openai, anthropic, cursor, and easyocr. Use --quality to auto-select the best model."
argument-hint: "Path to image file(s) or directory, --quality <low|normal|high>, or leave blank to OCR all images in the current directory"
---

# OCR Scan — Handwritten & Scanned Document Transcription

## When to Use

- User asks to transcribe, OCR, or extract text from a scanned image
- User has handwritten notes (photos, scans) and wants Markdown output
- Bulk transcription of multiple scanned pages or an entire directory
- Combining multiple backend transcriptions into a best-of version
- Listing available OCR models across backends

## Script Location

The OCR script is bundled at [./scripts/ocr_scan.py](./scripts/ocr_scan.py). Copy it to the workspace or run it directly from this skill directory. It depends on the `ai_backends` Python package.

## Quick Start

```powershell
# Single image — auto-select best free model
python path/to/ocr_scan.py -q low "path/to/scan.jpg"

# Best quality, any cost
python path/to/ocr_scan.py -q high "path/to/scan.jpg"

# Entire directory of scans
python path/to/ocr_scan.py -q normal "path/to/scans/"

# Specific backend and model (overrides quality system)
python path/to/ocr_scan.py -b copilot-cli -m claude-sonnet-4.6 "path/to/scan.jpg"

# All images in the current directory (when no paths specified)
python path/to/ocr_scan.py

# Force regenerate existing output
python path/to/ocr_scan.py --force "path/to/scan.jpg"

# Skip already-transcribed files
python path/to/ocr_scan.py --resume

# Refresh model registry (after CLI updates, new API keys, etc.)
python path/to/ocr_scan.py --refresh-models

# Verbose output (-v info, -vv debug)
python path/to/ocr_scan.py -v "path/to/scan.jpg"
```

## Quality Tiers

Instead of specifying exact backend/model combinations (which change frequently),
use `--quality` (`-q`) to let the script auto-select the best available option:

| Quality | Synonym | Strategy |
|---------|---------|----------|
| `low` | `fast` | Best free, vision-capable model (copilot-cli, github-api, gemini free tier) |
| `normal` | `default` | Best standard-cost model (includes free + paid at normal pricing) |
| `high` | `slow` | Absolute best model regardless of cost |

The script maintains a **model registry cache** that maps quality tiers to
specific backend/model pairs based on what's actually available. The cache
auto-refreshes when:
- CLI tool versions change (copilot, cursor)
- The cache is older than 7 days
- You run `--refresh-models`

See [./references/available-models.md](./references/available-models.md) for
current model availability and quality assignments (auto-generated).

## Backends

| Backend | Type | Cost | Requires |
|---------|------|------|----------|
| `copilot-cli` | CLI (default) | Free (subscription) | GitHub Copilot CLI installed |
| `github-api` | API | Free tier | `GITHUB_TOKEN` env var |
| `gemini` | API | Free tier | `GOOGLE_API_KEY` env var, `google-generativeai` package |
| `openai` | API | Paid | `OPENAI_API_KEY` env var, `openai` package |
| `anthropic` | API | Paid | `ANTHROPIC_API_KEY` env var, `anthropic` package |
| `cursor` | CLI | Free (subscription) | Cursor Agent CLI installed |
| `easyocr` | Traditional | Free (local) | `easyocr` package (+ PyTorch) |

Use `--list-models` to see live model availability for each backend.

## Key Flags

| Flag | Description |
|------|-------------|
| `-q QUALITY` | Quality tier: `low`/`fast`, `normal`/`default`, `high`/`slow` |
| `-b BACKEND` | Choose backend explicitly (overrides quality) |
| `-m MODEL` | Override the model for the chosen backend |
| `--force` | Overwrite existing `.ocr.md` output files |
| `--resume` | Skip files that already have output |
| `--no-rename` | Write output next to source file as-is (skip auto-rename) |
| `--all` | Run every available backend on each image |
| `--combine` | Combine existing multi-backend transcripts into a best-of version |
| `--list-models` | List available models for each backend and exit |
| `--refresh-models` | Force-refresh the model registry cache and exit |
| `-v` / `-vv` | Increase verbosity (INFO / DEBUG) |

## Procedure

1. **Locate the script** — use the bundled copy at [./scripts/ocr_scan.py](./scripts/ocr_scan.py). If the workspace already has a copy (e.g. `Scripts/OCR/ocr_scan.py`), prefer that. No special venv is required; system Python is fine. Install API packages as needed (`pip install openai`, `anthropic`, `google-generativeai`).

2. **Identify input** — collect the image path(s) or directory the user wants transcribed. Supported formats: `.jpg`, `.jpeg`, `.png`, `.tiff`, `.tif`, `.bmp`, `.webp`. Directories are scanned recursively for image files.

3. **Choose quality or backend** — prefer `--quality` over explicit `-b`/`-m` since specific model names change frequently. Use `--quality low` for fast/free, `--quality normal` for balanced, `--quality high` for best results. Fall back to explicit `-b`/`-m` only when the user requests a specific backend or model.

4. **Run the script**:
   ```powershell
   python path/to/ocr_scan.py -q normal --force --no-rename "path/to/image.jpg"
   # Or for a whole directory:
   python path/to/ocr_scan.py -q normal "path/to/scans/"
   ```
   - Use `--force` when re-transcribing with a different model.
   - Use `--no-rename` when the user wants output alongside the source file.

5. **Review output** — the script writes a `.ocr.md` file next to each input image. Open it and check for quality.

6. **Multi-backend workflow** (optional):
   ```powershell
   # Run all backends
   python path/to/ocr_scan.py --all "path/to/image.jpg"
   # Then combine into a best-of transcript
   python path/to/ocr_scan.py --combine -b copilot-cli "path/to/image.jpg"
   ```

## Notes

- **Quality tiers are the preferred interface** — they auto-select the best model from what's available, so instructions don't go stale when models are updated or retired.
- **Uses the `ai_backends` module** — backend calling, model discovery, and quality resolution are handled by the `ai_backends` Python package (pip-installed by the Jumpshell extension, or `pip install -e src/python/ai-backends` for repo dev). The OCR script at [./scripts/ocr_scan.py](./scripts/ocr_scan.py) imports it automatically. See the `/agent-script` skill for how to use `ai_backends` in new scripts.
- **Model registry** is cached in the installed package at `ai_backends/.models_cache.json` (shared across all skills using the module) and auto-regenerates [references/available-models.md](./references/available-models.md) on refresh.
- Output files are named `<source>.ocr.md` (single backend) or `<source>.<backend>.ocr.md` (when using `--all`).
- **Environment variables**: `OCR_BACKEND` overrides the default backend, `OCR_INPUT_DIR` sets the default input directory (defaults to cwd), `OCR_OUTPUT_DIR` sets the `--all` transcript output directory.
- **Directory input**: pass a directory path and the script will scan it for all image files automatically.
- For scanned PDFs with no embedded text, use this skill. For PDFs with selectable text, use the `pdf-to-md` skill instead.
- The script is self-contained with no workspace-specific paths. It can be dropped into any project (copy `ocr_scan.py` and `pip install ai-backends`).