#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash ./run.sh [-scope workspace|profile|global] [-effort default|low|medium|high|xhigh]

- If --effort is omitted, toggles between default and xhigh.
- workspace scope targets: <cwd>/.vscode/settings.json
- profile/global scope targets: <resolved-profile>/settings.json
EOF
}

scope="profile"
effort=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -scope)
      scope="${2-}"
      shift 2
      ;;
    -effort)
      effort="${2-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$scope" in
  workspace|profile|global)
    ;;
  *)
    echo "Invalid --scope: $scope" >&2
    exit 1
    ;;
esac

if [ -n "$effort" ]; then
  case "$effort" in
    default|low|medium|high|xhigh)
      ;;
    *)
      echo "Invalid --effort: $effort" >&2
      exit 1
      ;;
  esac
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$scope" = "workspace" ]; then
  target_dir="$PWD/.vscode"
else
  target_dir="$(bash "$script_dir/resolve-vscode-profile.sh")"
fi

mkdir -p "$target_dir"
target_file="$target_dir/settings.json"

if [ ! -f "$target_file" ]; then
  printf '{}\n' > "$target_file"
fi

if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  echo "Python is required to update $target_file" >&2
  exit 1
fi

result="$($python_cmd - "$target_file" "${effort:-__TOGGLE__}" <<'PY'
import json
import re
import sys
from pathlib import Path

key = "github.copilot.chat.responsesApiReasoningEffort"
target = Path(sys.argv[1])
requested = sys.argv[2]
raw = target.read_text(encoding="utf-8") if target.exists() else "{}"


def strip_jsonc(text: str) -> str:
    output = []
    i = 0
    in_string = False
    escaped = False
    in_line_comment = False
    in_block_comment = False

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if in_line_comment:
            if ch in "\r\n":
                in_line_comment = False
                output.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_string:
            output.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == '"':
            in_string = True
            output.append(ch)
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue

        output.append(ch)
        i += 1

    cleaned = "".join(output)
    while True:
        next_cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
        if next_cleaned == cleaned:
            break
        cleaned = next_cleaned
    return cleaned

cleaned = strip_jsonc(raw).strip() or "{}"

try:
    data = json.loads(cleaned)
except json.JSONDecodeError as exc:
    print(f"error|Failed to parse JSON from {target}: {exc}")
    sys.exit(2)

if not isinstance(data, dict):
    print(f"error|Expected top-level JSON object in {target}")
    sys.exit(2)

current = data.get(key)
if requested == "__TOGGLE__":
    new_value = "default" if current == "xhigh" else "xhigh"
else:
    new_value = requested

changed = data.get(key) != new_value
data[key] = new_value

target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
status = "changed" if changed else "unchanged"
print(f"ok|{target}|{new_value}|{status}")
PY
)"

status_tag="${result%%|*}"
if [ "$status_tag" = "error" ]; then
  echo "${result#error|}" >&2
  exit 2
fi

payload="${result#ok|}"
target_path="${payload%%|*}"
rest="${payload#*|}"
new_value="${rest%%|*}"
update_status="${rest#*|}"

echo "Updated: $target_path"
echo "github.copilot.chat.responsesApiReasoningEffort=$new_value"
echo "status=$update_status"
