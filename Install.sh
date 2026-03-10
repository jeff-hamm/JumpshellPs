#!/usr/bin/env bash
set -euo pipefail

if ! command -v pwsh &>/dev/null; then
    echo "ERROR: pwsh (PowerShell 7+) is required but was not found." >&2
    echo "Install it from: https://aka.ms/install-powershell" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pwsh -NoLogo -NonInteractive -File "$SCRIPT_DIR/Install.ps1" "$@"
