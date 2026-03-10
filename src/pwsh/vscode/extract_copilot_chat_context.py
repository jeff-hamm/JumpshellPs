#!/usr/bin/env python3
"""Extract VS Code Copilot chat archives into AI-friendly datasets.

This script normalizes both legacy chat session JSON files and newer JSONL files,
then writes compact outputs suitable for downstream AI analysis.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

NOISE_KINDS = {
    "thinking",
    "mcpServersStarting",
    "prepareToolInvocation",
    "toolInvocationSerialized",
    "inlineReference",
    "codeblockUri",
    "textEditGroup",
    "undoStop",
    "confirmation",
}

STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "this",
    "that",
    "from",
    "into",
    "your",
    "you",
    "are",
    "can",
    "could",
    "would",
    "should",
    "have",
    "has",
    "was",
    "were",
    "not",
    "let",
    "please",
    "also",
    "just",
    "need",
    "want",
    "about",
    "make",
    "using",
    "used",
    "use",
    "what",
    "when",
    "where",
    "how",
    "why",
    "any",
    "all",
    "more",
    "than",
    "then",
    "there",
    "their",
    "them",
    "they",
    "will",
    "our",
    "out",
    "over",
    "under",
    "after",
    "before",
    "between",
    "because",
    "which",
    "while",
    "like",
    "some",
    "each",
    "other",
    "these",
    "those",
    "help",
    "code",
    "file",
    "files",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Root folder containing copied chat session archives.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("analysis_export"),
        help="Output directory for normalized artifacts (relative to --root if not absolute).",
    )
    parser.add_argument(
        "--max-turn-chars",
        type=int,
        default=4000,
        help="Maximum characters retained per user/assistant turn in compact outputs.",
    )
    parser.add_argument(
        "--max-chunk-chars",
        type=int,
        default=9000,
        help="Maximum characters per context chunk record.",
    )
    return parser.parse_args()


def to_iso_utc(epoch_ms: Any) -> Optional[str]:
    if epoch_ms is None:
        return None
    if isinstance(epoch_ms, str):
        if not epoch_ms.strip().isdigit():
            return None
        epoch_ms = int(epoch_ms)
    if not isinstance(epoch_ms, (int, float)):
        return None
    if epoch_ms <= 0:
        return None
    try:
        dt = datetime.fromtimestamp(float(epoch_ms) / 1000.0, tz=timezone.utc)
        return dt.isoformat()
    except Exception:
        return None


def normalize_text(text: str) -> str:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    normalized = re.sub(r"\n{3,}", "\n\n", normalized)
    return normalized.strip()


def shorten(text: str, max_chars: int) -> str:
    if max_chars <= 0:
        return ""
    if len(text) <= max_chars:
        return text
    if max_chars <= 3:
        return text[:max_chars]
    return text[: max_chars - 3] + "..."


def load_manifest_workspace_map(root: Path) -> Dict[str, List[str]]:
    manifest_path = root / "_manifest.json"
    if not manifest_path.exists():
        return {}

    try:
        raw = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        return {}

    workspace_map: Dict[str, set[str]] = defaultdict(set)
    if isinstance(raw, list):
        for item in raw:
            if not isinstance(item, dict):
                continue
            safe = item.get("SafeFolderName")
            workspace = item.get("WorkspacePath")
            if isinstance(safe, str) and safe and isinstance(workspace, str) and workspace:
                workspace_map[safe].add(workspace)

    return {k: sorted(v) for k, v in workspace_map.items()}


def discover_session_files(root: Path) -> List[Path]:
    files: List[Path] = []
    for pattern in ("**/*.json", "**/*.jsonl"):
        for path in root.glob(pattern):
            if not path.is_file():
                continue
            if path.name == "_manifest.json":
                continue
            if path.parent.name != "chatSessions":
                continue
            files.append(path)
    return sorted(files)


def extract_message_text(message_obj: Any) -> str:
    if isinstance(message_obj, str):
        return normalize_text(message_obj)

    if isinstance(message_obj, dict):
        text = message_obj.get("text")
        if isinstance(text, str) and text.strip():
            return normalize_text(text)

        parts = message_obj.get("parts")
        if isinstance(parts, list):
            values: List[str] = []
            for part in parts:
                if isinstance(part, dict):
                    ptext = part.get("text")
                    if isinstance(ptext, str) and ptext.strip():
                        values.append(ptext)
            if values:
                return normalize_text("\n".join(values))

    return ""


def extract_assistant_text_and_tools(response_obj: Any) -> Tuple[str, List[str]]:
    if not isinstance(response_obj, list):
        return "", []

    text_pieces: List[str] = []
    tools: List[str] = []

    for item in response_obj:
        if not isinstance(item, dict):
            continue

        kind = item.get("kind")

        if kind == "prepareToolInvocation":
            tool_name = item.get("toolName")
            if isinstance(tool_name, str) and tool_name:
                tools.append(tool_name)
            continue

        if kind == "toolInvocationSerialized":
            tool_id = item.get("toolId")
            if isinstance(tool_id, str) and tool_id:
                tools.append(tool_id)
            tool_name = item.get("toolName")
            if isinstance(tool_name, str) and tool_name:
                tools.append(tool_name)
            continue

        if isinstance(kind, str) and kind in NOISE_KINDS:
            continue

        value = item.get("value")
        if isinstance(value, str) and value.strip():
            text_pieces.append(value)

    return normalize_text("".join(text_pieces)), tools


def load_session_from_json(path: Path) -> Tuple[Optional[Dict[str, Any]], Dict[str, Any]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return None, {"error": str(exc)}

    if not isinstance(raw, dict):
        return None, {"error": "JSON root is not an object"}

    if not isinstance(raw.get("requests"), list):
        return None, {"error": "Missing requests array"}

    return raw, {}


def load_session_from_jsonl(path: Path) -> Tuple[Optional[Dict[str, Any]], Dict[str, Any]]:
    session: Optional[Dict[str, Any]] = None
    line_count = 0
    parse_errors = 0
    kind_counter: Counter[str] = Counter()

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            line_count += 1
            try:
                obj = json.loads(line)
            except Exception:
                parse_errors += 1
                continue

            if not isinstance(obj, dict):
                continue

            kind = obj.get("kind")
            if kind is not None:
                kind_counter[str(kind)] += 1

            if kind == 0 and isinstance(obj.get("v"), dict):
                candidate = obj["v"]
                if isinstance(candidate.get("requests"), list):
                    session = candidate
            elif isinstance(obj.get("requests"), list):
                # Fallback for files that directly store session-shaped JSON lines.
                session = obj

    metadata = {
        "line_count": line_count,
        "parse_errors": parse_errors,
        "kind_counts": dict(kind_counter),
    }

    if session is None:
        return None, metadata

    return session, metadata


def extract_workspace_safe_folder(root: Path, file_path: Path) -> str:
    relative = file_path.relative_to(root)
    return relative.parts[0] if relative.parts else ""


def iter_words(text: str) -> Iterable[str]:
    for word in re.findall(r"[A-Za-z][A-Za-z0-9_-]{2,}", text.lower()):
        if word in STOPWORDS:
            continue
        yield word


def build_context_chunks(
    session_id: str,
    title: str,
    workspace_safe: str,
    workspace_path: Optional[str],
    turns: List[Dict[str, Any]],
    max_chunk_chars: int,
) -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    if max_chunk_chars <= 0:
        return chunks

    header = [
        f"SessionId: {session_id}",
        f"Title: {title or '(untitled)'}",
        f"WorkspaceSafeFolder: {workspace_safe}",
    ]
    if workspace_path:
        header.append(f"WorkspacePath: {workspace_path}")
    header_text = "\n".join(header) + "\n\n"

    buffer_blocks: List[Tuple[int, str]] = []
    buffer_chars = len(header_text)

    def flush() -> None:
        nonlocal buffer_blocks, buffer_chars
        if not buffer_blocks:
            return
        start_turn = buffer_blocks[0][0]
        end_turn = buffer_blocks[-1][0]
        body = "\n\n".join(block for _, block in buffer_blocks)
        text = header_text + body
        chunks.append(
            {
                "session_id": session_id,
                "title": title,
                "workspace_safe_folder": workspace_safe,
                "workspace_path_original": workspace_path,
                "chunk_index": len(chunks) + 1,
                "start_turn": start_turn,
                "end_turn": end_turn,
                "char_count": len(text),
                "text": text,
            }
        )
        buffer_blocks = []
        buffer_chars = len(header_text)

    for turn in turns:
        user_text = turn.get("user_text", "")
        assistant_text = turn.get("assistant_text", "")
        if not user_text and not assistant_text:
            continue

        block_parts: List[str] = [f"Turn {turn['turn_index']}"]
        if user_text:
            block_parts.append("User:\n" + user_text)
        if assistant_text:
            block_parts.append("Assistant:\n" + assistant_text)

        block = "\n\n".join(block_parts)
        block_len = len(block) + (2 if buffer_blocks else 0)

        if buffer_blocks and buffer_chars + block_len > max_chunk_chars:
            flush()

        if len(header_text) + len(block) > max_chunk_chars:
            truncated = shorten(block, max(256, max_chunk_chars - len(header_text)))
            chunks.append(
                {
                    "session_id": session_id,
                    "title": title,
                    "workspace_safe_folder": workspace_safe,
                    "workspace_path_original": workspace_path,
                    "chunk_index": len(chunks) + 1,
                    "start_turn": turn["turn_index"],
                    "end_turn": turn["turn_index"],
                    "char_count": len(header_text) + len(truncated),
                    "text": header_text + truncated,
                }
            )
            continue

        buffer_blocks.append((turn["turn_index"], block))
        buffer_chars += block_len

    flush()
    return chunks


def write_jsonl(path: Path, records: Iterable[Dict[str, Any]]) -> int:
    count = 0
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=True) + "\n")
            count += 1
    return count


def format_top_counter(counter: Counter[str], top_n: int = 15) -> List[str]:
    rows: List[str] = []
    for key, value in counter.most_common(top_n):
        label = key.replace("|", "\\|")
        rows.append(f"| `{label}` | {value} |")
    return rows


def main() -> int:
    args = parse_args()

    root = args.root.resolve()
    out_dir = args.out if args.out.is_absolute() else (root / args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest_map = load_manifest_workspace_map(root)
    files = discover_session_files(root)

    sessions_out: List[Dict[str, Any]] = []
    turns_out: List[Dict[str, Any]] = []
    chunks_out: List[Dict[str, Any]] = []

    format_counter: Counter[str] = Counter()
    model_counter: Counter[str] = Counter()
    tool_counter: Counter[str] = Counter()
    keyword_counter: Counter[str] = Counter()
    workspace_session_counter: Counter[str] = Counter()
    workspace_request_counter: Counter[str] = Counter()

    timestamp_values: List[int] = []
    parse_failures: List[Dict[str, Any]] = []

    for file_path in files:
        suffix = file_path.suffix.lower()
        format_counter[suffix] += 1

        if suffix == ".json":
            session, load_meta = load_session_from_json(file_path)
        else:
            session, load_meta = load_session_from_jsonl(file_path)

        if session is None:
            parse_failures.append(
                {
                    "file": str(file_path.relative_to(root).as_posix()),
                    "format": suffix,
                    "meta": load_meta,
                }
            )
            continue

        requests = session.get("requests") or []
        if not isinstance(requests, list):
            requests = []

        workspace_safe = extract_workspace_safe_folder(root, file_path)
        original_workspace_paths = manifest_map.get(workspace_safe) or []
        original_workspace_path = original_workspace_paths[0] if original_workspace_paths else None

        session_id = str(session.get("sessionId") or file_path.stem)
        title = str(session.get("customTitle") or "").strip()
        if not title:
            title = "(untitled)"

        creation_ms = session.get("creationDate")
        last_ms = session.get("lastMessageDate")
        creation_iso = to_iso_utc(creation_ms)
        last_iso = to_iso_utc(last_ms)
        if isinstance(creation_ms, (int, float)):
            timestamp_values.append(int(creation_ms))
        if isinstance(last_ms, (int, float)):
            timestamp_values.append(int(last_ms))

        turns: List[Dict[str, Any]] = []
        session_models: Counter[str] = Counter()
        session_tools: Counter[str] = Counter()

        user_chars = 0
        assistant_chars = 0

        for turn_index, request in enumerate(requests, start=1):
            if not isinstance(request, dict):
                continue

            user_text = extract_message_text(request.get("message"))
            assistant_text, used_tools = extract_assistant_text_and_tools(request.get("response"))

            user_text = shorten(user_text, args.max_turn_chars)
            assistant_text = shorten(assistant_text, args.max_turn_chars)

            user_chars += len(user_text)
            assistant_chars += len(assistant_text)

            model_id = request.get("modelId")
            model_id_str = str(model_id).strip() if model_id is not None else ""
            if model_id_str:
                session_models[model_id_str] += 1
                model_counter[model_id_str] += 1

            ts = request.get("timestamp")
            if isinstance(ts, (int, float)):
                timestamp_values.append(int(ts))
            timestamp_iso = to_iso_utc(ts)

            normalized_tools: List[str] = []
            for tool_name in used_tools:
                clean_name = tool_name.strip()
                if not clean_name:
                    continue
                normalized_tools.append(clean_name)
                session_tools[clean_name] += 1
                tool_counter[clean_name] += 1

            for word in iter_words(user_text):
                keyword_counter[word] += 1

            turn_record = {
                "session_id": session_id,
                "turn_index": turn_index,
                "timestamp_utc": timestamp_iso,
                "workspace_safe_folder": workspace_safe,
                "workspace_path_original": original_workspace_path,
                "source_file": str(file_path.relative_to(root).as_posix()),
                "model_id": model_id_str or None,
                "tool_names": sorted(set(normalized_tools)),
                "user_text": user_text,
                "assistant_text": assistant_text,
            }

            turns.append(turn_record)
            turns_out.append(turn_record)

        chunks = build_context_chunks(
            session_id=session_id,
            title=title,
            workspace_safe=workspace_safe,
            workspace_path=original_workspace_path,
            turns=turns,
            max_chunk_chars=args.max_chunk_chars,
        )
        chunks_out.extend(chunks)

        prompt_digest = "\n".join(
            f"U{t['turn_index']}: {t['user_text']}" for t in turns if t.get("user_text")
        )

        sessions_out.append(
            {
                "session_id": session_id,
                "title": title,
                "workspace_safe_folder": workspace_safe,
                "workspace_path_original": original_workspace_path,
                "source_file": str(file_path.relative_to(root).as_posix()),
                "source_format": suffix,
                "creation_utc": creation_iso,
                "last_message_utc": last_iso,
                "request_count": len(turns),
                "models": [k for k, _ in session_models.most_common()],
                "top_tools": [k for k, _ in session_tools.most_common(20)],
                "user_chars": user_chars,
                "assistant_chars": assistant_chars,
                "prompt_digest": shorten(prompt_digest, 12000),
                "jsonl_meta": load_meta if suffix == ".jsonl" else None,
            }
        )

        workspace_session_counter[workspace_safe] += 1
        workspace_request_counter[workspace_safe] += len(turns)

    sessions_out.sort(
        key=lambda x: (
            x.get("last_message_utc") or "",
            x.get("creation_utc") or "",
            x.get("session_id") or "",
        ),
        reverse=True,
    )

    sessions_count = len(sessions_out)
    turns_count = len(turns_out)
    chunks_count = len(chunks_out)

    sessions_jsonl = out_dir / "sessions_normalized.jsonl"
    turns_jsonl = out_dir / "turns_compact.jsonl"
    chunks_jsonl = out_dir / "context_chunks.jsonl"
    parse_fail_jsonl = out_dir / "parse_failures.jsonl"
    report_md = out_dir / "report.md"

    write_jsonl(sessions_jsonl, sessions_out)
    write_jsonl(turns_jsonl, turns_out)
    write_jsonl(chunks_jsonl, chunks_out)
    write_jsonl(parse_fail_jsonl, parse_failures)

    ts_min_iso = to_iso_utc(min(timestamp_values)) if timestamp_values else None
    ts_max_iso = to_iso_utc(max(timestamp_values)) if timestamp_values else None

    report_lines: List[str] = [
        "# Copilot Chat Usage Extraction",
        "",
        f"Generated UTC: {datetime.now(timezone.utc).isoformat()}",
        f"Source root: `{root}`",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|---|---:|",
        f"| Session files discovered | {len(files)} |",
        f"| Sessions parsed | {sessions_count} |",
        f"| Parse failures | {len(parse_failures)} |",
        f"| Turns extracted | {turns_count} |",
        f"| Context chunks | {chunks_count} |",
        f"| Date range (UTC) | {ts_min_iso or 'n/a'} -> {ts_max_iso or 'n/a'} |",
        "",
        "## Output Files",
        "",
        f"- `sessions_normalized.jsonl`: one normalized record per session.",
        f"- `turns_compact.jsonl`: one normalized user/assistant turn per request.",
        f"- `context_chunks.jsonl`: chunked session text for direct AI context ingestion.",
        f"- `parse_failures.jsonl`: files that could not be parsed.",
        "",
        "## Session Formats",
        "",
        "| Format | Files |",
        "|---|---:|",
    ]

    for fmt, count in sorted(format_counter.items()):
        report_lines.append(f"| `{fmt}` | {count} |")

    report_lines.extend(
        [
            "",
            "## Top Workspaces By Sessions",
            "",
            "| Workspace Safe Folder | Sessions | Requests |",
            "|---|---:|---:|",
        ]
    )

    for workspace, count in workspace_session_counter.most_common(25):
        report_lines.append(
            f"| `{workspace}` | {count} | {workspace_request_counter.get(workspace, 0)} |"
        )

    report_lines.extend(
        [
            "",
            "## Top Models By Request Count",
            "",
            "| Model | Requests |",
            "|---|---:|",
        ]
    )

    model_rows = format_top_counter(model_counter, top_n=25)
    report_lines.extend(model_rows if model_rows else ["| `(none)` | 0 |"])

    report_lines.extend(
        [
            "",
            "## Top Tool Calls",
            "",
            "| Tool | Count |",
            "|---|---:|",
        ]
    )

    tool_rows = format_top_counter(tool_counter, top_n=30)
    report_lines.extend(tool_rows if tool_rows else ["| `(none)` | 0 |"])

    report_lines.extend(
        [
            "",
            "## Top User Keywords",
            "",
            "| Keyword | Count |",
            "|---|---:|",
        ]
    )

    keyword_rows = format_top_counter(keyword_counter, top_n=40)
    report_lines.extend(keyword_rows if keyword_rows else ["| `(none)` | 0 |"])

    report_lines.extend(
        [
            "",
            "## Suggested AI Ingestion Order",
            "",
            "1. Load `report.md` for global usage shape.",
            "2. Load `sessions_normalized.jsonl` for per-session metadata and prompt digests.",
            "3. Load `context_chunks.jsonl` for chunked conversational context.",
            "4. Load `turns_compact.jsonl` when you need turn-level drill-down.",
            "",
        ]
    )

    report_md.write_text("\n".join(report_lines), encoding="utf-8", newline="\n")

    print(f"Parsed sessions: {sessions_count}/{len(files)}")
    print(f"Turns: {turns_count}")
    print(f"Chunks: {chunks_count}")
    print(f"Parse failures: {len(parse_failures)}")
    print(f"Output directory: {out_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
