#!/usr/bin/env bash
set -euo pipefail

VSIX_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -VsixPath|--vsix-path) VSIX_PATH="${2:-}"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_ROOT="$SCRIPT_DIR/jumpshell"
PACKAGE_JSON="$EXTENSION_ROOT/package.json"

if [[ ! -f "$PACKAGE_JSON" ]]; then
    echo "ERROR: Could not find extension package file: $PACKAGE_JSON" >&2
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "ERROR: node is required but was not found. Install Node.js from https://nodejs.org/" >&2
    exit 1
fi

EXTENSION_NAME="$(node -p "require('$PACKAGE_JSON').name")"
EXTENSION_PUBLISHER="$(node -p "require('$PACKAGE_JSON').publisher")"
EXTENSION_ID="${EXTENSION_PUBLISHER}.${EXTENSION_NAME}"
if [[ -z "$EXTENSION_NAME" ]]; then
    echo "ERROR: Extension name is missing from $PACKAGE_JSON" >&2
    exit 1
fi

if [[ -z "$VSIX_PATH" ]]; then
    VSIX_PATH="$SCRIPT_DIR/${EXTENSION_NAME}.vsix"
fi

# --- Editor detection (name resolution delegated to canonical resolve-editor.sh) ---

RESOLVE_EDITOR_SH="$SCRIPT_DIR/../src/sh/resolve-editor.sh"
if [[ ! -f "$RESOLVE_EDITOR_SH" ]]; then
    echo "ERROR: resolve-editor.sh not found at $RESOLVE_EDITOR_SH" >&2
    exit 1
fi

_editor_cli() {
    case "$1" in
        'Code')            printf 'code' ;;
        'Code - Insiders') printf 'code-insiders' ;;
        'Cursor')          printf 'cursor' ;;
        'Windsurf')        printf 'windsurf' ;;
        'VSCodium')        printf 'codium' ;;
        *) echo "ERROR: Editor '$1' does not support VSIX installation." >&2; exit 1 ;;
    esac
}

EDITOR_NAME="$(bash "$RESOLVE_EDITOR_SH" --name)"
EDITOR_CLI="$(_editor_cli "$EDITOR_NAME")"
if ! command -v "$EDITOR_CLI" &>/dev/null; then
    echo "ERROR: '$EDITOR_CLI' not found in PATH. Ensure $EDITOR_NAME is installed and its CLI is on PATH." >&2
    exit 1
fi

# Try to download the VSIX from the GitHub release that matches package.json version.
# Returns 0 and writes to VSIX_PATH on success, 1 on failure.
_try_download_github_vsix() {
    local vsix_dest="$1"
    if ! command -v git &>/dev/null; then return 1; fi

    local origin
    origin="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null)" || return 1
    # Normalise SSH → HTTPS and strip .git suffix
    origin="$(printf '%s' "$origin" | sed 's|git@github.com:|https://github.com/|; s|\.git$||')"
    if ! printf '%s' "$origin" | grep -qi 'github.com'; then return 1; fi

    local version
    version="$(node -p "require('$PACKAGE_JSON').version" 2>/dev/null)" || return 1
    local vsix_name="${EXTENSION_NAME}-${version}.vsix"
    local url="${origin}/releases/download/v${version}/${vsix_name}"

    echo "Downloading VSIX from GitHub release: $url"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$vsix_dest" "$url" && return 0
    elif command -v wget &>/dev/null; then
        wget -q -O "$vsix_dest" "$url" && return 0
    fi
    return 1
}

# Try to download the VSIX directly from the VS Code Marketplace for the version in package.json.
# URL template: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{name}/{version}/vspackage
_try_download_marketplace_vsix() {
    local vsix_dest="$1"
    local version publisher url
    version="$(node -p "require('$PACKAGE_JSON').version" 2>/dev/null)" || return 1
    publisher="$(node -p "require('$PACKAGE_JSON').publisher" 2>/dev/null)" || return 1
    url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${EXTENSION_NAME}/${version}/vspackage"

    echo "Downloading VSIX from VS Code Marketplace: $url"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$vsix_dest" "$url" && return 0
    elif command -v wget &>/dev/null; then
        wget -q -O "$vsix_dest" "$url" && return 0
    fi
    return 1
}

if [[ -f "$VSIX_PATH" ]]; then
    echo "Installing VSIX into $EDITOR_NAME from $VSIX_PATH..."
    "$EDITOR_CLI" --install-extension "$VSIX_PATH" --force
elif _try_download_github_vsix "$VSIX_PATH"; then
    echo "Installing downloaded VSIX into $EDITOR_NAME..."
    "$EDITOR_CLI" --install-extension "$VSIX_PATH" --force
elif _try_download_marketplace_vsix "$VSIX_PATH"; then
    echo "Installing downloaded VSIX into $EDITOR_NAME..."
    "$EDITOR_CLI" --install-extension "$VSIX_PATH" --force
else
    echo "All download attempts failed. Installing $EXTENSION_ID via marketplace CLI..."
    "$EDITOR_CLI" --install-extension "$EXTENSION_ID" --force
fi
echo "Installed $EXTENSION_ID in $EDITOR_NAME."
