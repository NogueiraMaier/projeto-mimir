#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
import time
import uuid
from pathlib import Path
from typing import Any

SESSION_NAME_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-"
    r"[0-9a-f]{4}-[0-9a-f]{12}\.jsonl$",
    re.IGNORECASE,
)

SECRET_RE = re.compile(
    r"(?:"
    r"-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|"
    r"nvapi-[A-Za-z0-9_-]{20,}|"
    r"sk-[A-Za-z0-9_-]{20,}|"
    r"authorization\s*:\s*bearer\s+\S{20,}|"
    r"(?:api[_-]?key|password|senha|token|secret)"
    r"\s*[:=]\s*\S{8,}"
    r")",
    re.IGNORECASE,
)

ALLOWED_INDEX_STATUS = {"done"}
ALLOWED_ROLES = {"user", "assistant"}


class CaptureError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Analisa sessões concluídas do OpenClaw em dry run. "
            "Não exibe mensagens e não grava no PostgreSQL."
        )
    )
    parser.add_argument(
        "--sessions-dir",
        type=Path,
        default=Path(
            "/var/lib/openclaw/.openclaw/agents/main/sessions"
        ),
    )
    parser.add_argument(
        "--max-source-chars",
        type=int,
        default=60000,
    )
    parser.add_argument(
        "--min-age-seconds",
        type=int,
        default=120,
    )
    return parser.parse_args()


def load_index(root: Path) -> dict[str, dict[str, Any]]:
    index_path = root / "sessions.json"

    try:
        with index_path.open("r", encoding="utf-8") as stream:
            data = json.load(stream)
    except OSError as error:
        raise CaptureError(
            f"falha ao ler sessions.json: {error}"
        ) from error
    except json.JSONDecodeError as error:
        raise CaptureError(
            f"sessions.json inválido: linha {error.lineno}"
        ) from error

    if not isinstance(data, dict):
        raise CaptureError("sessions.json não possui raiz objeto")

    result: dict[str, dict[str, Any]] = {}

    for entry in data.values():
        if not isinstance(entry, dict):
            continue

        session_file = entry.get("sessionFile")
        session_id = entry.get("sessionId")
        status_value = entry.get("status")

        if not isinstance(session_file, str):
            continue

        name = Path(session_file).name

        result[name] = {
            "session_id": (
                str(session_id)
                if session_id is not None
                else name.removesuffix(".jsonl")
            ),
            "status": (
                str(status_value)
                if status_value is not None
                else "unknown"
            ),
        }

    return result


def extract_text(message: dict[str, Any]) -> str:
    content = message.get("content")

    if isinstance(content, str):
        return content.strip()

    if not isinstance(content, list):
        return ""

    parts: list[str] = []

    for item in content:
        if not isinstance(item, dict):
            continue

        if item.get("type") != "text":
            continue

        text_value = item.get("text")

        if isinstance(text_value, str) and text_value.strip():
            parts.append(text_value.strip())

    return "\n".join(parts)


def parse_session(
    path: Path,
    max_source_chars: int,
) -> dict[str, Any]:
    transcript: list[str] = []
    line_count = 0
    user_count = 0
    assistant_count = 0

    try:
        with path.open(
            "r",
            encoding="utf-8",
            errors="strict",
        ) as stream:
            for line_number, line in enumerate(stream, start=1):
                if not line.strip():
                    continue

                line_count += 1

                try:
                    record = json.loads(line)
                except json.JSONDecodeError as error:
                    raise CaptureError(
                        f"{path.name}: JSON inválido na linha "
                        f"{line_number}: {error.msg}"
                    ) from error

                if not isinstance(record, dict):
                    continue

                if record.get("type") != "message":
                    continue

                message = record.get("message")

                if not isinstance(message, dict):
                    continue

                role = message.get("role")

                if role not in ALLOWED_ROLES:
                    continue

                if role == "user":
                    owner_data = message.get("__openclaw")

                    if not isinstance(owner_data, dict):
                        continue

                    if owner_data.get("senderIsOwner") is not True:
                        continue

                text_value = extract_text(message)

                if not text_value:
                    continue

                timestamp = (
                    message.get("timestamp")
                    or record.get("timestamp")
                    or "unknown"
                )

                transcript.append(
                    f"[{timestamp}] {str(role).upper()}\n{text_value}"
                )

                if role == "user":
                    user_count += 1
                else:
                    assistant_count += 1

    except UnicodeDecodeError as error:
        raise CaptureError(
            f"{path.name}: conteúdo fora de UTF-8"
        ) from error
    except OSError as error:
        raise CaptureError(
            f"{path.name}: falha de leitura: {error}"
        ) from error

    content = "\n\n".join(transcript).strip()

    result: dict[str, Any] = {
        "line_count": line_count,
        "user_messages": user_count,
        "assistant_messages": assistant_count,
        "message_count": user_count + assistant_count,
        "content_chars": len(content),
        "content_sha256": None,
        "capture_status": "ready",
        "reason": None,
    }

    if not content:
        result["capture_status"] = "blocked"
        result["reason"] = "nenhuma mensagem elegível"
        return result

    if SECRET_RE.search(content):
        result["capture_status"] = "blocked"
        result["reason"] = "possível segredo ou credencial"
        return result

    if len(content) > max_source_chars:
        result["capture_status"] = "blocked"
        result["reason"] = (
            f"conteúdo excede {max_source_chars} caracteres"
        )
        return result

    result["content_sha256"] = hashlib.sha256(
        content.encode("utf-8")
    ).hexdigest()

    return result


def main() -> int:
    args = parse_args()
    root = args.sessions_dir.resolve()

    if args.max_source_chars < 1000:
        print(
            "ERRO: --max-source-chars deve ser igual ou superior a 1000",
            file=sys.stderr,
        )
        return 2

    if args.min_age_seconds < 0:
        print(
            "ERRO: --min-age-seconds não aceita valor negativo",
            file=sys.stderr,
        )
        return 2

    if not root.is_dir():
        print(
            f"ERRO: diretório inexistente: {root}",
            file=sys.stderr,
        )
        return 2

    try:
        index = load_index(root)
    except CaptureError as error:
        print(f"ERRO: {error}", file=sys.stderr)
        return 1

    results: list[dict[str, Any]] = []
    errors = 0
    now = time.time()

    for path in sorted(root.iterdir(), key=lambda item: item.name):
        if not SESSION_NAME_RE.fullmatch(path.name):
            continue

        try:
            info = path.lstat()
        except OSError as error:
            results.append(
                {
                    "file": path.name,
                    "capture_status": "error",
                    "reason": f"falha ao executar lstat: {error}",
                }
            )
            errors += 1
            continue

        if stat.S_ISLNK(info.st_mode):
            results.append(
                {
                    "file": path.name,
                    "capture_status": "blocked",
                    "reason": "link simbólico rejeitado",
                }
            )
            continue

        if not stat.S_ISREG(info.st_mode):
            continue

        index_entry = index.get(path.name)
        indexed_status = (
            index_entry.get("status")
            if index_entry is not None
            else "unknown"
        )
        session_id = (
            index_entry.get("session_id")
            if index_entry is not None
            else path.stem
        )

        base_result: dict[str, Any] = {
            "file": path.name,
            "session_id": session_id,
            "index_status": indexed_status,
            "size_bytes": info.st_size,
            "capture_status": "skipped",
            "reason": None,
        }

        try:
            uuid.UUID(str(session_id))
        except ValueError:
            base_result["reason"] = "session_id inválido"
            results.append(base_result)
            continue

        if indexed_status not in ALLOWED_INDEX_STATUS:
            base_result["reason"] = (
                f"status não elegível: {indexed_status}"
            )
            results.append(base_result)
            continue

        age_seconds = max(0, int(now - info.st_mtime))

        if age_seconds < args.min_age_seconds:
            base_result["reason"] = (
                f"arquivo recente: {age_seconds} segundos"
            )
            results.append(base_result)
            continue

        try:
            parsed = parse_session(
                path=path,
                max_source_chars=args.max_source_chars,
            )
            base_result.update(parsed)
        except CaptureError as error:
            base_result["capture_status"] = "error"
            base_result["reason"] = str(error)
            errors += 1

        results.append(base_result)

    summary = {
        "mode": "dry-run",
        "database_write": False,
        "staging_write": False,
        "content_exposed": False,
        "sessions_directory": str(root),
        "allowed_index_status": sorted(ALLOWED_INDEX_STATUS),
        "files_considered": len(results),
        "ready": sum(
            item.get("capture_status") == "ready"
            for item in results
        ),
        "blocked": sum(
            item.get("capture_status") == "blocked"
            for item in results
        ),
        "skipped": sum(
            item.get("capture_status") == "skipped"
            for item in results
        ),
        "errors": errors,
        "sessions": results,
    }

    json.dump(
        summary,
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    sys.stdout.write("\n")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
