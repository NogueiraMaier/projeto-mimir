#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import uuid
from collections import Counter
from dataclasses import dataclass
from typing import Any


NORMALIZATION_VERSION = "openclaw-chat-history-v2"
ALLOWED_CLASSES = {"telegram", "hud", "acp-bridge", "maestro", "main"}
ALLOWED_ROLES = {"user", "assistant"}

SECRET_RE = re.compile(
    r"(?:"
    r"-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|"
    r"nvapi-[A-Za-z0-9_-]{20,}|"
    r"sk-[A-Za-z0-9_-]{20,}|"
    r"authorization\s*:\s*bearer\s+\S{20,}|"
    r"(?:api[_-]?key|password|senha|token|secret)\s*[:=]\s*\S{8,}"
    r")",
    re.IGNORECASE,
)

TRUNCATION_MARKERS = (
    "…(truncated)…",
    "[chat.history omitted:",
    "[sessions_history omitted:",
    "[Input omitted;",
)


class CaptureError(RuntimeError):
    pass


@dataclass(frozen=True)
class Config:
    node_bin: str
    openclaw_entry: str
    agent: str
    page_limit: int
    max_pages: int
    max_chars_per_message: int
    max_source_chars: int
    timeout_seconds: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Dry-run de captura de sessoes OpenClaw via APIs suportadas. "
            "Nao exibe mensagens e nao grava no PostgreSQL."
        )
    )
    parser.add_argument("--node-bin", default="node")
    parser.add_argument(
        "--openclaw-entry",
        default="/opt/openclaw/openclaw.mjs",
    )
    parser.add_argument("--agent", default="main")
    parser.add_argument("--page-limit", type=int, default=500)
    parser.add_argument("--max-pages", type=int, default=20)
    parser.add_argument(
        "--max-chars-per-message",
        type=int,
        default=60000,
    )
    parser.add_argument(
        "--max-source-chars",
        type=int,
        default=60000,
    )
    parser.add_argument("--timeout-seconds", type=int, default=30)
    return parser.parse_args()


def build_config(args: argparse.Namespace) -> Config:
    if not args.agent.strip():
        raise CaptureError("--agent invalido")
    if not 1 <= args.page_limit <= 1000:
        raise CaptureError("--page-limit deve ficar entre 1 e 1000")
    if not 1 <= args.max_pages <= 100:
        raise CaptureError("--max-pages deve ficar entre 1 e 100")
    if args.max_chars_per_message < 1000:
        raise CaptureError("--max-chars-per-message deve ser >= 1000")
    if args.max_source_chars < 1000:
        raise CaptureError("--max-source-chars deve ser >= 1000")
    if not 1 <= args.timeout_seconds <= 120:
        raise CaptureError("--timeout-seconds deve ficar entre 1 e 120")

    return Config(
        node_bin=args.node_bin,
        openclaw_entry=args.openclaw_entry,
        agent=args.agent.strip(),
        page_limit=args.page_limit,
        max_pages=args.max_pages,
        max_chars_per_message=args.max_chars_per_message,
        max_source_chars=args.max_source_chars,
        timeout_seconds=args.timeout_seconds,
    )


def openclaw_json(config: Config, args: list[str]) -> dict[str, Any]:
    try:
        run = subprocess.run(
            [config.node_bin, config.openclaw_entry, *args],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=config.timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        raise CaptureError("OpenClaw excedeu o timeout") from error
    except OSError as error:
        raise CaptureError("falha ao executar OpenClaw") from error

    if run.returncode != 0:
        # Do not surface stderr: provider/channel errors can contain
        # operational data that must not enter reports.
        raise CaptureError(
            f"OpenClaw retornou codigo {run.returncode}"
        )

    try:
        payload = json.loads(run.stdout)
    except json.JSONDecodeError as error:
        raise CaptureError("OpenClaw retornou JSON invalido") from error

    if not isinstance(payload, dict):
        raise CaptureError("OpenClaw retornou raiz JSON inesperada")

    return payload


def canonical_uuid(value: object) -> str:
    if not isinstance(value, str):
        raise CaptureError("session_id ausente")
    try:
        parsed = uuid.UUID(value)
    except ValueError as error:
        raise CaptureError("session_id invalido") from error
    if str(parsed) != value:
        raise CaptureError("session_id nao canonico")
    return value


def session_class(key: str, agent: str) -> str:
    if ":telegram:" in key:
        return "telegram"
    if ":hud:" in key:
        return "hud"
    if ":acp-bridge:" in key:
        return "acp-bridge"
    if key == f"agent:{agent}:maestro":
        return "maestro"
    if key == f"agent:{agent}:main":
        return "main"
    if ":cron:" in key:
        return "cron"
    if ":recovered:" in key:
        return "recovered"
    return "other"


def text_parts(content: object) -> tuple[list[str], Counter[str]]:
    parts: list[str] = []
    block_types: Counter[str] = Counter()

    if isinstance(content, str):
        block_types["string"] += 1
        if content.strip():
            parts.append(content.strip())
        return parts, block_types

    if not isinstance(content, list):
        return parts, block_types

    for block in content:
        if not isinstance(block, dict):
            block_types[type(block).__name__] += 1
            continue

        block_type = str(block.get("type", "<missing>"))
        block_types[block_type] += 1

        if block_type != "text":
            continue

        value = block.get("text")
        if isinstance(value, str) and value.strip():
            parts.append(value.strip())

    return parts, block_types


def has_truncation(content: object) -> bool:
    values: list[str] = []

    if isinstance(content, str):
        values.append(content)
    elif isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            for field in ("text", "thinking", "partialJson"):
                value = block.get(field)
                if isinstance(value, str):
                    values.append(value)

    return any(
        marker in value
        for value in values
        for marker in TRUNCATION_MARKERS
    )


def source_sha256(
    key: str,
    session_id: str,
    messages: list[dict[str, Any]],
) -> str:
    stable: list[dict[str, Any]] = []

    for message in messages:
        meta = message.get("__openclaw")
        stable_meta: dict[str, Any] = {}

        if isinstance(meta, dict):
            for field in (
                "id",
                "seq",
                "recordTimestampMs",
                "senderIsOwner",
                "senderId",
                "transport",
                "transcriptPosition",
            ):
                if field in meta:
                    stable_meta[field] = meta[field]

        stable.append(
            {
                "role": message.get("role"),
                "timestamp": message.get("timestamp"),
                "content": message.get("content"),
                "__openclaw": stable_meta,
            }
        )

    encoded = json.dumps(
        {
            "sessionKey": key,
            "sessionId": session_id,
            "messages": stable,
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

    return hashlib.sha256(encoded).hexdigest()


def read_history(
    config: Config,
    key: str,
    session_id: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    offset = 0
    pages = 0
    expected_total: int | None = None
    pagination = False
    messages: list[dict[str, Any]] = []

    while True:
        pages += 1
        if pages > config.max_pages:
            raise CaptureError("limite de paginas excedido")

        params = json.dumps(
            {
                "sessionKey": key,
                "offset": offset,
                "limit": config.page_limit,
                "maxChars": config.max_chars_per_message,
            },
            separators=(",", ":"),
        )

        page = openclaw_json(
            config,
            [
                "gateway",
                "call",
                "chat.history",
                "--params",
                params,
                "--timeout",
                str(config.timeout_seconds * 1000),
                "--json",
            ],
        )

        if page.get("sessionKey") != key:
            raise CaptureError("sessionKey mudou durante leitura")
        if page.get("sessionId") != session_id:
            raise CaptureError("sessionId mudou durante leitura")

        raw = page.get("messages")
        if not isinstance(raw, list):
            raise CaptureError("chat.history nao retornou messages[]")

        messages.extend(
            item for item in raw if isinstance(item, dict)
        )

        pagination = pagination or any(
            field in page
            for field in (
                "hasMore",
                "nextOffset",
                "totalMessages",
                "deltaCursor",
            )
        )

        total = page.get("totalMessages")
        if isinstance(total, int):
            if expected_total is None:
                expected_total = total
            elif total != expected_total:
                raise CaptureError(
                    "totalMessages mudou durante leitura"
                )

        if not page.get("hasMore"):
            break

        next_offset = page.get("nextOffset")
        if not isinstance(next_offset, int) or next_offset <= offset:
            raise CaptureError("nextOffset invalido")
        offset = next_offset

    if expected_total is not None and len(messages) > expected_total:
        raise CaptureError(
            "mais mensagens retornadas que totalMessages"
        )

    return messages, {
        "pages": pages,
        "pagination_signal": pagination,
        "total_messages": expected_total,
    }


def analyze(
    key: str,
    session_id: str,
    cls: str,
    messages: list[dict[str, Any]],
    max_source_chars: int,
) -> dict[str, Any]:
    roles: Counter[str] = Counter()
    blocks: Counter[str] = Counter()
    transcript: list[str] = []

    user = assistant = 0
    owner_true = owner_false = owner_missing = 0
    excluded_system = excluded_results = 0
    excluded_calls = excluded_thinking = 0
    with_id = with_seq = with_timestamp = 0
    truncation = False

    for message in messages:
        role = str(message.get("role", "<missing>"))
        roles[role] += 1

        meta = message.get("__openclaw")
        if isinstance(meta, dict):
            with_id += isinstance(meta.get("id"), str)
            with_seq += isinstance(meta.get("seq"), int)

        with_timestamp += bool(
            message.get("timestamp") is not None
            or (
                isinstance(meta, dict)
                and meta.get("recordTimestampMs") is not None
            )
        )

        content = message.get("content")
        truncation = truncation or has_truncation(content)

        parts, kinds = text_parts(content)
        blocks.update(kinds)
        excluded_calls += kinds.get("toolCall", 0)
        excluded_thinking += kinds.get("thinking", 0)

        if role == "system":
            excluded_system += 1
            continue
        if role == "toolResult":
            excluded_results += 1
            continue
        if role not in ALLOWED_ROLES:
            continue

        if role == "user":
            user += 1
            if isinstance(meta, dict):
                marker = meta.get("senderIsOwner")
                if marker is True:
                    owner_true += 1
                elif marker is False:
                    owner_false += 1
                else:
                    owner_missing += 1
            else:
                owner_missing += 1
        else:
            assistant += 1

        if parts:
            transcript.append(
                f"{role}:\n" + "\n".join(parts)
            )

    result: dict[str, Any] = {
        "session_key": key,
        "session_id": session_id,
        "session_class": cls,
        "message_count": len(messages),
        "roles": dict(sorted(roles.items())),
        "block_types": dict(sorted(blocks.items())),
        "user_messages": user,
        "assistant_messages": assistant,
        "owner_true": owner_true,
        "owner_false": owner_false,
        "owner_missing": owner_missing,
        "excluded_system_messages": excluded_system,
        "excluded_tool_results": excluded_results,
        "excluded_tool_calls": excluded_calls,
        "excluded_thinking_blocks": excluded_thinking,
        "messages_with_id": with_id,
        "messages_with_seq": with_seq,
        "messages_with_timestamp": with_timestamp,
        "truncation_signal": truncation,
        "source_sha256": source_sha256(key, session_id, messages),
        "content_chars": 0,
        "content_sha256": None,
        "capture_status": "ready",
        "reason": None,
    }

    def block(reason: str) -> dict[str, Any]:
        result["capture_status"] = "blocked"
        result["reason"] = reason
        return result

    if user < 1:
        return block("sessao sem mensagem user elegivel")
    if owner_false:
        return block("mensagem user de remetente nao proprietario")
    if owner_missing:
        return block("proveniencia owner ausente em mensagem user")
    if owner_true != user:
        return block("proveniencia owner inconsistente")
    if assistant < 1:
        return block("sessao sem mensagem assistant elegivel")
    if truncation:
        return block("historico contem sinal de truncamento/omissao")

    content = "\n\n".join(transcript).strip()
    result["content_chars"] = len(content)

    if not content:
        return block("sessao sem conteudo textual elegivel")
    if SECRET_RE.search(content):
        return block("possivel segredo ou credencial")
    if len(content) > max_source_chars:
        return block(
            f"conteudo excede {max_source_chars} caracteres"
        )

    result["content_sha256"] = hashlib.sha256(
        content.encode("utf-8")
    ).hexdigest()
    return result


def main() -> int:
    try:
        config = build_config(parse_args())
        listing = openclaw_json(
            config,
            [
                "sessions",
                "--agent",
                config.agent,
                "--limit",
                "all",
                "--json",
            ],
        )

        rows = listing.get("sessions")
        if not isinstance(rows, list):
            raise CaptureError(
                "OpenClaw sessions nao retornou sessions[]"
            )

        results: list[dict[str, Any]] = []
        errors = 0

        for row in rows:
            if not isinstance(row, dict):
                continue

            key = row.get("key")
            if not isinstance(key, str) or not key:
                continue

            status = row.get("status")
            cls = session_class(key, config.agent)

            base: dict[str, Any] = {
                "session_key": key,
                "session_class": cls,
                "index_status": (
                    str(status) if status is not None else "unknown"
                ),
                "capture_status": "skipped",
                "reason": None,
            }

            if status != "done":
                base["reason"] = (
                    f"status nao elegivel: {base['index_status']}"
                )
                results.append(base)
                continue

            if cls not in ALLOWED_CLASSES:
                base["reason"] = (
                    f"classe de sessao nao elegivel: {cls}"
                )
                results.append(base)
                continue

            try:
                session_id = canonical_uuid(
                    row.get("sessionId") or row.get("id")
                )
                messages, paging = read_history(
                    config,
                    key,
                    session_id,
                )
                item = analyze(
                    key,
                    session_id,
                    cls,
                    messages,
                    config.max_source_chars,
                )
                item["index_status"] = "done"
                item.update(paging)
                results.append(item)
            except CaptureError as error:
                base["capture_status"] = "error"
                base["reason"] = str(error)
                results.append(base)
                errors += 1

        output = {
            "mode": "dry-run",
            "collector_version": 2,
            "normalization": NORMALIZATION_VERSION,
            "database_write": False,
            "staging_write": False,
            "content_exposed": False,
            "direct_sqlite_access": False,
            "source_api": [
                "openclaw sessions --json",
                "gateway chat.history",
            ],
            "agent": config.agent,
            "canonical_store": listing.get("path"),
            "session_rows": len(rows),
            "sessions_considered": len(results),
            "ready": sum(
                x.get("capture_status") == "ready"
                for x in results
            ),
            "blocked": sum(
                x.get("capture_status") == "blocked"
                for x in results
            ),
            "skipped": sum(
                x.get("capture_status") == "skipped"
                for x in results
            ),
            "errors": errors,
            "eligible_session_classes": sorted(ALLOWED_CLASSES),
            "sessions": results,
        }

        json.dump(
            output,
            sys.stdout,
            ensure_ascii=False,
            indent=2,
        )
        sys.stdout.write("\n")
        return 1 if errors else 0

    except CaptureError as error:
        print(f"ERRO: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("ERRO: execucao interrompida.", file=sys.stderr)
        return 130
    except Exception:
        print(
            "ERRO: falha interna durante a captura segura.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
