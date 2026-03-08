#!/usr/bin/env bash
# expand-templates.sh — Expand {{SHELL_NAME}} and {{SHELL_EXT}} placeholders in all SKILL.md files.
#
# Usage:
#   bash expand-templates.sh [--skills-dir <path>] [--dry-run]
#
# Options:
#   --skills-dir <path>   Explicit skills directory. If omitted, resolved via resolve-editor.sh --skills.
#   --dry-run             Report what would change without writing files.
#
# Outputs: JSON to stdout, diagnostics to stderr.
# Exit codes: 0 success, 1 error.

set -euo pipefail

SKILLS_DIR=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    --dry-run)    DRY_RUN="true";  shift ;;
    --help|-h)    printf 'Usage: bash expand-templates.sh [--skills-dir <path>] [--dry-run]\n'; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SKILLS_DIR" ]]; then
  RESOLVER="$(dirname "$0")/resolve-editor.sh"
  if [[ -f "$RESOLVER" ]]; then
    SKILLS_DIR="$(bash "$RESOLVER" --skills)"
  else
    # Fallback: search for resolve-editor.sh in ~/.agents/skills
    RESOLVER_FOUND="$(find "$HOME/.agents/skills" -name "resolve-editor.sh" 2>/dev/null | head -n1 || true)"
    if [[ -n "$RESOLVER_FOUND" ]]; then
      SKILLS_DIR="$(bash "$RESOLVER_FOUND" --skills)"
    fi
  fi
fi

[[ -z "$SKILLS_DIR" ]] && SKILLS_DIR="$HOME/.agents/skills"

SHELL_NAME="bash"
SHELL_EXT=".sh"

UPDATED_PATHS=()

if [[ -d "$SKILLS_DIR" ]]; then
  while IFS= read -r -d '' skill_file; do
    content="$(cat "$skill_file")"
    if printf '%s' "$content" | grep -qE '\{\{SHELL_NAME\}\}|\{\{SHELL_EXT\}\}|\{\{SCRIPT_PATHS_NOTE\}\}'; then
      new_content="${content//\{\{SHELL_NAME\}\}/$SHELL_NAME}"
      new_content="${new_content//\{\{SHELL_EXT\}\}/$SHELL_EXT}"
      script_paths_note='> **Script paths** — `scripts/`, `references/`, and `assets/` paths below are relative to the directory containing this `SKILL.md`. Use them as relative paths from that directory without `cd`.'
      new_content="${new_content//\{\{SCRIPT_PATHS_NOTE\}\}/$script_paths_note}"
      if [[ "$new_content" != "$content" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
          printf '%s' "$new_content" > "$skill_file"
        fi
        UPDATED_PATHS+=("$skill_file")
      fi
    fi
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null)
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$DRY_RUN" "$SKILLS_DIR" "$SHELL_NAME" "$SHELL_EXT" "${UPDATED_PATHS[@]+"${UPDATED_PATHS[@]}"}" <<'PY'
import json, sys
dry_run    = sys.argv[1] == "true"
skills_dir = sys.argv[2]
shell_name = sys.argv[3]
shell_ext  = sys.argv[4]
updated    = sys.argv[5:] if len(sys.argv) > 5 else []
print(json.dumps({
  "status":    "ok",
  "dryRun":    dry_run,
  "skillsDir": skills_dir,
  "shellName": shell_name,
  "shellExt":  shell_ext,
  "updated":   updated,
}))
PY
else
  printf '{"status":"ok","dryRun":%s,"skillsDir":"%s","shellName":"%s","shellExt":"%s","updated":[]}\n' \
    "$DRY_RUN" "$SKILLS_DIR" "$SHELL_NAME" "$SHELL_EXT"
fi
