#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./resolve-editor.sh [--name|--profile|--user|--rules|--skills|--settings [type]|--workspace] [--workspace] [--git-commit]

Modes:
  --name                 Return editor name (default)
  --profile              Return current editor profile (User config) path
  --user                 Return current editor preferred user path
  --rules                Return user rules/instructions path; add --workspace for workspace-scoped path
  --skills               Return user skills path; add --workspace for workspace-scoped path
  --settings [type]      Return settings dir (default) or a specific file: setting|task|mcp|keybinding
                         e.g. --settings task  ->  .../tasks.json
  --workspace            Workspace-level .agents/.cursor path (standalone or scope modifier)

Flags:
  --git-commit           After resolving path, also run change-control before-phase (backup + git status).
                         No-op when resolved path is not an existing file.
  --relative             When combined with a --workspace path, return only the workspace-relative portion (e.g. .agents/instructions).
EOF
}

first_existing_path() {
  for p in "$@"; do
    if [ -n "$p" ] && [ -d "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  for p in "$@"; do
    if [ -n "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  return 1
}

json_escape() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

export_scope_context() {
  local editor="$1"
  local scope_path="$2"
  EDITOR="$editor"
  SCOPE_PATH="$scope_path"
  export EDITOR
  export SCOPE_PATH
}

write_path_tuple() {
  local editor="$1"
  local scope_path="$2"
  printf '["%s","%s"]\n' "$(json_escape "$editor")" "$(json_escape "$scope_path")"
}

hint_text() {
  printf '%s %s %s %s %s %s' "${TERM_PROGRAM-}" "${TERM_PROGRAM_VERSION-}" "${VSCODE_IPC_HOOK-}" "${VSCODE_GIT_ASKPASS_MAIN-}" "${CLAUDECODE-}" "${CLAUDE_CONFIG_DIR-}"
}

editor_order() {
  local hints
  hints="$(hint_text)"

  if printf '%s' "$hints" | grep -Eiq 'Code - Insiders|code-insiders'; then
    printf '%s\n' "Code - Insiders" "Code" "Cursor" "Claude"
    return
  fi

  if printf '%s' "$hints" | grep -qi 'Cursor'; then
    printf '%s\n' "Cursor" "Code" "Code - Insiders" "Claude"
    return
  fi

  if printf '%s' "$hints" | grep -Eiq 'Claude|claude'; then
    printf '%s\n' "Claude" "Code" "Code - Insiders" "Cursor"
    return
  fi

  printf '%s\n' "Code" "Code - Insiders" "Cursor" "Claude"
}

profile_candidates_for_editor() {
  local editor="$1"
  local os
  os="$(uname -s)"

  case "$os" in
    Darwin)
      case "$editor" in
        "Code") printf '%s\n' "$HOME/Library/Application Support/Code/User" ;;
        "Code - Insiders") printf '%s\n' "$HOME/Library/Application Support/Code - Insiders/User" ;;
        "Cursor") printf '%s\n' "$HOME/Library/Application Support/Cursor/User" ;;
        "Claude") printf '%s\n' "$HOME/Library/Application Support/Claude/User" "$HOME/Library/Application Support/Claude" ;;
      esac
      ;;
    Linux)
      case "$editor" in
        "Code") printf '%s\n' "$HOME/.config/Code/User" ;;
        "Code - Insiders") printf '%s\n' "$HOME/.config/Code - Insiders/User" ;;
        "Cursor") printf '%s\n' "$HOME/.config/Cursor/User" ;;
        "Claude") printf '%s\n' "$HOME/.config/Claude/User" "$HOME/.config/Claude" ;;
      esac
      ;;
    *)
      :
      ;;
  esac
}

resolve_editor_name() {
  local editor
  while IFS= read -r editor; do
    while IFS= read -r candidate; do
      if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        printf '%s\n' "$editor"
        return
      fi
    done < <(profile_candidates_for_editor "$editor")
  done < <(editor_order)

  editor_order | head -n 1
}

resolve_profile_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  mapfile -t candidates < <(profile_candidates_for_editor "$editor")
  first_existing_path "${candidates[@]}"
}

resolve_user_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$HOME/.cursor"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    printf '%s\n' "$HOME/.claude"
    return
  fi

  printf '%s\n' "$HOME/.agents"
}

resolve_rules_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local user_path
  user_path="$(resolve_user_path "$editor")"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$user_path/rules"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    first_existing_path "$user_path/commands" "$user_path/rules" "$user_path"
    return
  fi

  printf '%s\n' "$user_path/instructions"
}

resolve_workspace_root() {
  local start current parent
  start="$PWD"

  if command -v git >/dev/null 2>&1; then
    local git_root
    if git_root="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$git_root" ]; then
      printf '%s\n' "$git_root"
      return
    fi
  fi

  current="$start"
  while :; do
    if [ -e "$current/.git" ] || [ -d "$current/.vscode" ] || [ -d "$current/.cursor" ] || [ -d "$current/.agents" ] || [ -d "$current/.claude" ] || compgen -G "$current/*.code-workspace" >/dev/null; then
      printf '%s\n' "$current"
      return
    fi

    parent="$(dirname "$current")"
    if [ "$parent" = "$current" ]; then
      break
    fi
    current="$parent"
  done

  printf '%s\n' "$start"
}

resolve_workspace_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local workspace_root
  workspace_root="$(resolve_workspace_root)"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$workspace_root/.cursor"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    printf '%s\n' "$workspace_root/.claude"
    return
  fi

  printf '%s\n' "$workspace_root/.agents"
}

resolve_workspace_rules_path() {
  local editor="${1:-}"
  if [ -z "$editor" ]; then
    editor="$(resolve_editor_name)"
  fi

  local workspace_path
  workspace_path="$(resolve_workspace_path "$editor")"

  if [ "$editor" = "Cursor" ]; then
    printf '%s\n' "$workspace_path/rules"
    return
  fi

  if [ "$editor" = "Claude" ]; then
    first_existing_path "$workspace_path/commands" "$workspace_path/rules" "$workspace_path"
    return
  fi

  printf '%s\n' "$workspace_path/instructions"
}

resolve_skills_path() {
  local workspace_scope="${1:-false}"
  local editor
  editor="$(resolve_editor_name)"

  if [ "$workspace_scope" = "true" ]; then
    local workspace_path
    workspace_path="$(resolve_workspace_path "$editor")"
    printf '%s\n' "$workspace_path/skills"
    return
  fi

  local user_path
  user_path="$(resolve_user_path "$editor")"
  printf '%s\n' "$user_path/skills"
}

resolve_settings_path() {
  local workspace_scope="${1:-false}"
  local subtype="${2:-}"

  local dir_path
  if [ "$workspace_scope" = "true" ]; then
    local editor workspace_root
    editor="$(resolve_editor_name)"
    workspace_root="$(resolve_workspace_root)"
    if [ "$editor" = "Cursor" ]; then dir_path="$workspace_root/.cursor"
    elif [ "$editor" = "Claude" ]; then dir_path="$workspace_root/.claude"
    else dir_path="$workspace_root/.vscode"
    fi
  else
    local editor
    editor="$(resolve_editor_name)"
    dir_path="$(resolve_profile_path "$editor")"
  fi

  if [ -z "$subtype" ]; then
    printf '%s\n' "$dir_path"
    return
  fi

  local file_name
  case "${subtype,,}" in
    setting)    file_name="settings.json" ;;
    task)       file_name="tasks.json" ;;
    mcp)        file_name="mcp.json" ;;
    keybinding) file_name="keybindings.json" ;;
    *) printf 'Unknown settings subtype \'%s\'. Valid types: setting, task, mcp, keybinding\n' "$subtype" >&2; exit 2 ;;
  esac

  printf '%s/%s\n' "$dir_path" "$file_name"
}

invoke_before_phase() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return
  # Only run when the resolved path is an existing file
  [[ ! -f "$file_path" ]] && return

  local cc_script
  cc_script="$(dirname "$0")/change-control.sh"
  if [[ ! -f "$cc_script" ]]; then
    printf '[resolve-editor] change-control.sh not found: %s\n' "$cc_script" >&2
    return
  fi

  bash "$cc_script" --phase before --file "$file_path" >&2
}

make_relative() {
  local path="$1"
  local workspace_root
  workspace_root="$(resolve_workspace_root)"
  printf '%s\n' "${path#"$workspace_root/"}"
}

# Parse arguments
MODE=""
WORKSPACE_FLAG=false
GIT_COMMIT_FLAG=false
RELATIVE_FLAG=false
SETTINGS_SUBTYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|--profile|--user|--rules|--skills|--workspace)
      if [ -n "$MODE" ] && [ "$1" != "--workspace" ]; then
        printf 'Multiple mode flags supplied.\n' >&2; usage >&2; exit 2
      fi
      if [ "$1" = "--workspace" ] && [ -n "$MODE" ]; then
        WORKSPACE_FLAG=true
      else
        MODE="$1"
      fi
      shift
      ;;
    --settings)
      if [ -n "$MODE" ]; then
        printf 'Multiple mode flags supplied.\n' >&2; usage >&2; exit 2
      fi
      MODE="--settings"
      shift
      # Check if next arg is a subtype (not a flag)
      if [[ $# -gt 0 && "$1" != --* ]]; then
        SETTINGS_SUBTYPE="$1"
        shift
      fi
      ;;
    --git-commit)
      GIT_COMMIT_FLAG=true
      shift
      ;;
    --relative)
      RELATIVE_FLAG=true
      shift
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2
      ;;
  esac
done

# --workspace alone retains legacy standalone behaviour
if [ -z "$MODE" ] && [ "$WORKSPACE_FLAG" = "true" ]; then MODE="--workspace"; WORKSPACE_FLAG=false; fi
if [ -z "$MODE" ]; then MODE="--name"; fi
mode="$MODE"

case "$mode" in
  --name)
    editor="$(resolve_editor_name)"
    export_scope_context "$editor" ""
    printf '%s\n' "$editor"
    ;;
  --profile)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_profile_path "$editor")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --user)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_user_path "$editor")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --rules)
    editor="$(resolve_editor_name)"
    if [ "$WORKSPACE_FLAG" = "true" ]; then
      scope_path="$(resolve_workspace_rules_path "$editor")"
    else
      scope_path="$(resolve_rules_path "$editor")"
    fi
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --skills)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_skills_path "$WORKSPACE_FLAG")"
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --settings)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_settings_path "$WORKSPACE_FLAG" "$SETTINGS_SUBTYPE")"
    [ "$RELATIVE_FLAG" = "true" ] && [ "$WORKSPACE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  --workspace)
    editor="$(resolve_editor_name)"
    scope_path="$(resolve_workspace_path "$editor")"
    [ "$RELATIVE_FLAG" = "true" ] && scope_path="$(make_relative "$scope_path")"
    export_scope_context "$editor" "$scope_path"
    printf '%s\n' "$scope_path"
    [[ "$GIT_COMMIT_FLAG" == "true" ]] && invoke_before_phase "$scope_path"
    ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    usage >&2
    exit 2
    ;;
esac
