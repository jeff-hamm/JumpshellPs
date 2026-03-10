#!/usr/bin/env bash
# Run ocr_scan.py — OCR handwritten scanned notes to Markdown
# Usage: ./run.sh [options] [paths...]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec python "$DIR/ocr_scan.py" "$@"
