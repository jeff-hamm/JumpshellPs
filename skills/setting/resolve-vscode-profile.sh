#!/usr/bin/env bash
set -euo pipefail

pick_first_existing() {
  for p in "$@"; do
    if [ -d "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  printf '%s\n' "$1"
}

stable_macos="$HOME/Library/Application Support/Code/User"
insiders_macos="$HOME/Library/Application Support/Code - Insiders/User"
cursor_macos="$HOME/Library/Application Support/Cursor/User"

stable_linux="$HOME/.config/Code/User"
insiders_linux="$HOME/.config/Code - Insiders/User"
cursor_linux="$HOME/.config/Cursor/User"

hints="${TERM_PROGRAM-} ${TERM_PROGRAM_VERSION-} ${VSCODE_IPC_HOOK-} ${VSCODE_GIT_ASKPASS_MAIN-}"

if [ "$(uname -s)" = "Darwin" ]; then
  if printf '%s' "$hints" | grep -q "Code - Insiders"; then
    pick_first_existing "$insiders_macos" "$stable_macos" "$cursor_macos"
  elif printf '%s' "$hints" | grep -q "Cursor"; then
    pick_first_existing "$cursor_macos" "$stable_macos" "$insiders_macos"
  else
    pick_first_existing "$stable_macos" "$insiders_macos" "$cursor_macos"
  fi
else
  if printf '%s' "$hints" | grep -q "Code - Insiders"; then
    pick_first_existing "$insiders_linux" "$stable_linux" "$cursor_linux"
  elif printf '%s' "$hints" | grep -q "Cursor"; then
    pick_first_existing "$cursor_linux" "$stable_linux" "$insiders_linux"
  else
    pick_first_existing "$stable_linux" "$insiders_linux" "$cursor_linux"
  fi
fi