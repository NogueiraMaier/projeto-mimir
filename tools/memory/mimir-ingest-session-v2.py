#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import json
import os
import pwd
import re
import socket
import stat
import subprocess
import sys
import uuid
from pathlib import Path
from types import ModuleType
from typing import Any, NoReturn


HERE = Path(__file__).resolve().parent
CAPTURE_PATH = HERE / "mimir-capture-sessions-v2.py"
PSQL_DEFAULT = "/usr/lib64/postgresql-17/bin/psql"
PG_USER = "mimir_app"
PG_DB_DEFAULT = "mimir_memory"
PRODUCTION_SOCKET = Path("/run/postgresql")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
MAX_SESSION_KEY_CHARS = 1024


class WriterError(RuntimeError):
    pass


def reject(message: str) -> NoReturn:
    raise WriterError(message)


def load_capture_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "mimir_capture_sessions_v2",
        CAPTURE_PATH,
    )
    if spec is None or spec.loader is None:
        reject("falha ao carregar o capturador v2")

    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_sha256(value: str, label: str) -> str:
    normalized = value.lower()
    if not SHA256_RE.fullmatch(normalized):
        reject(f"{label} inválido")
    return normalized


def canonical_uuid(value: str) -> str:
    try:
        parsed = uuid.UUID(value)
    except (ValueError, AttributeError) as error:
        raise WriterError("session_id inválido") from error
    if str(parsed) != value:
        reject("session_id não canônico")
    return value


def approval_digest(
    session_id: str,
    session_key: str,
    source_sha256: str,
    content_sha256: str,
) -> str:
    encoded = (
        "mimir-session-write-v2\n"
        + session_id
        + "\n"
        + session_key
        + "\n"
        + source_sha256
        + "\n"
        + content_sha256
        + "\n"
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def select_session_row(
    rows: object,
    session_key: str,
    session_id: str,
    capture: ModuleType,
    agent: str,
) -> dict[str, Any]:
    if not isinstance(rows, list):
        reject("OpenClaw sessions não retornou sessions[]")

    matches: list[dict[str, Any]] = []

    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("key") != session_key:
            continue

        candidate = row.get("sessionId") or row.get("id")
        if candidate != session_id:
            continue

        matches.append(row)

    if len(matches) != 1:
        reject("seleção não corresponde a uma única sessão canônica")

    row = matches[0]
    if row.get("status") != "done":
        reject("sessão selecionada não está concluída")

    session_class = capture.session_class(session_key, agent)
    if session_class not in capture.ALLOWED_CLASSES:
        reject("classe de sessão não autorizada")

    updated_at = row.get("updatedAt")
    if (
        not isinstance(updated_at, int)
        or isinstance(updated_at, bool)
        or updated_at <= 0
    ):
        reject("updatedAt canônico ausente ou inválido")

    return row


def capture_selected(
    capture: ModuleType,
    config: Any,
    session_key: str,
    session_id: str,
) -> tuple[dict[str, Any], str]:
    listing = capture.openclaw_json(
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

    row = select_session_row(
        listing.get("sessions"),
        session_key,
        session_id,
        capture,
        config.agent,
    )

    source_updated_at_ms = row["updatedAt"]
    session_class = capture.session_class(
        session_key,
        config.agent,
    )

    messages, paging = capture.read_history(
        config,
        session_key,
        session_id,
    )

    metadata = capture.analyze(
        session_key,
        session_id,
        session_class,
        source_updated_at_ms,
        messages,
        config.max_source_chars,
        include_content=True,
    )
    metadata["index_status"] = "done"
    metadata.update(paging)

    if metadata.get("capture_status") != "ready":
        reason = metadata.get("reason") or "sessão bloqueada"
        reject(str(reason))

    content = metadata.pop("_content", None)
    if not isinstance(content, str) or not content:
        reject("captura pronta sem conteúdo interno")

    return metadata, content


def validate_expected_hashes(
    metadata: dict[str, Any],
    expected_source: str,
    expected_content: str,
) -> None:
    if metadata.get("source_fingerprint_sha256") != expected_source:
        reject("source fingerprint diverge da aprovação")
    if metadata.get("content_sha256") != expected_content:
        reject("content SHA-256 diverge da aprovação")


def build_psql_script(
    metadata: dict[str, Any],
    content: str,
) -> str:
    session_id = canonical_uuid(str(metadata["session_id"]))
    session_key = str(metadata["session_key"])
    source_fp = validate_sha256(
        str(metadata["source_fingerprint_sha256"]),
        "source fingerprint",
    )
    content_sha = validate_sha256(
        str(metadata["content_sha256"]),
        "content SHA-256",
    )

    if len(session_key) > MAX_SESSION_KEY_CHARS:
        reject("session_key excede limite")

    content_bytes = content.encode("utf-8")
    if len(content_bytes) != int(metadata["content_bytes"]):
        reject("content_bytes diverge da captura")

    actual_content_sha = hashlib.sha256(content_bytes).hexdigest()
    if actual_content_sha != content_sha:
        reject("conteúdo interno diverge do hash capturado")

    key_b64 = base64.b64encode(
        session_key.encode("utf-8")
    ).decode("ascii")
    content_b64 = base64.b64encode(content_bytes).decode("ascii")

    numeric_fields = {
        "message_count": int(metadata["message_count"]),
        "user_messages": int(metadata["user_messages"]),
        "assistant_messages": int(metadata["assistant_messages"]),
        "content_bytes": int(metadata["content_bytes"]),
        "source_updated_at_ms": int(metadata["source_updated_at_ms"]),
        "excluded_system_messages": int(
            metadata["excluded_system_messages"]
        ),
        "excluded_tool_results": int(
            metadata["excluded_tool_results"]
        ),
        "excluded_thinking_blocks": int(
            metadata["excluded_thinking_blocks"]
        ),
        "excluded_tool_calls": int(
            metadata["excluded_tool_calls"]
        ),
    }

    if any(value < 0 for value in numeric_fields.values()):
        reject("metadado numérico inválido")

    if numeric_fields["user_messages"] < 1:
        reject("captura sem user_messages")
    if numeric_fields["assistant_messages"] < 1:
        reject("captura sem assistant_messages")
    if numeric_fields["content_bytes"] < 1:
        reject("captura sem conteúdo")
    if numeric_fields["source_updated_at_ms"] < 1:
        reject("source_updated_at_ms inválido")

    return f"""\\set ON_ERROR_STOP on
BEGIN;
SELECT mimir.ingest_session_v2(
    '{session_id}'::uuid,
    convert_from(decode('{key_b64}', 'base64'), 'UTF8'),
    '{source_fp}',
    convert_from(decode('{content_b64}', 'base64'), 'UTF8'),
    '{content_sha}',
    {numeric_fields["message_count"]},
    {numeric_fields["user_messages"]},
    {numeric_fields["assistant_messages"]},
    {numeric_fields["content_bytes"]},
    to_timestamp(
        {numeric_fields["source_updated_at_ms"]}::double precision / 1000.0
    ),
    'openclaw-chat-history-v2',
    {numeric_fields["excluded_system_messages"]},
    {numeric_fields["excluded_tool_results"]},
    {numeric_fields["excluded_thinking_blocks"]},
    {numeric_fields["excluded_tool_calls"]}
);
COMMIT;
"""


def validate_local_socket(host: str, port: int) -> Path:
    path = Path(host)
    if not path.is_absolute():
        reject("pg-host deve ser diretório absoluto de socket Unix")

    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise WriterError("pg-host indisponível") from error

    if not resolved.is_dir():
        reject("pg-host não é diretório")

    socket_path = resolved / f".s.PGSQL.{port}"
    try:
        socket_stat = socket_path.stat()
    except OSError as error:
        raise WriterError("socket PostgreSQL indisponível") from error

    if not stat.S_ISSOCK(socket_stat.st_mode):
        reject("endpoint PostgreSQL não é socket Unix")

    return resolved


def run_psql(
    *,
    psql_bin: str,
    pg_host: str,
    pg_port: int,
    pg_db: str,
    sql: str,
    timeout_seconds: int,
) -> str:
    if not Path(psql_bin).is_absolute():
        reject("psql-bin deve ser caminho absoluto")

    argv = [
        psql_bin,
        "-X",
        "-w",
        "-qAt",
        "-h",
        pg_host,
        "-p",
        str(pg_port),
        "-U",
        PG_USER,
        "-d",
        pg_db,
        "-v",
        "ON_ERROR_STOP=1",
    ]

    env = {
        "PATH": "/usr/bin:/bin",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "HOME": "/nonexistent",
        "PGAPPNAME": "mimir-session-writer-v2",
    }

    try:
        run = subprocess.run(
            argv,
            input=sql,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout_seconds,
            env=env,
        )
    except subprocess.TimeoutExpired as error:
        raise WriterError("PostgreSQL excedeu o timeout") from error
    except OSError as error:
        raise WriterError("falha ao executar psql") from error

    if run.returncode != 0:
        # PostgreSQL errors must not echo the SQL payload or session content.
        reject(f"psql retornou código {run.returncode}")

    lines = [
        line.strip()
        for line in run.stdout.splitlines()
        if line.strip()
    ]

    if len(lines) != 1:
        reject("resposta PostgreSQL inesperada")

    return canonical_uuid(lines[0])


def current_unix_user() -> str:
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except KeyError as error:
        raise WriterError("usuário Unix atual não identificado") from error


def safe_summary(
    metadata: dict[str, Any],
    *,
    mode: str,
    approval_sha256: str,
    event_id: str | None,
) -> dict[str, Any]:
    return {
        "mode": mode,
        "result": "approved" if mode == "dry-run" else "written",
        "session_key": metadata["session_key"],
        "session_id": metadata["session_id"],
        "session_class": metadata["session_class"],
        "source_ref": metadata["source_ref"],
        "source_updated_at_ms": metadata["source_updated_at_ms"],
        "source_fingerprint_sha256": metadata[
            "source_fingerprint_sha256"
        ],
        "content_sha256": metadata["content_sha256"],
        "content_bytes": metadata["content_bytes"],
        "message_count": metadata["message_count"],
        "user_messages": metadata["user_messages"],
        "assistant_messages": metadata["assistant_messages"],
        "excluded_system_messages": metadata[
            "excluded_system_messages"
        ],
        "excluded_tool_results": metadata[
            "excluded_tool_results"
        ],
        "excluded_thinking_blocks": metadata[
            "excluded_thinking_blocks"
        ],
        "excluded_tool_calls": metadata[
            "excluded_tool_calls"
        ],
        "classification": "confidential",
        "normalization": "openclaw-chat-history-v2",
        "approval_sha256": approval_sha256,
        "database_write": mode == "write",
        "staging_write": False,
        "content_exposed": False,
        "external_api": False,
        "memory_promotion": False,
        "event_id": event_id,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Writer controlado de sessão OpenClaw v2. "
            "Dry-run é o padrão; conteúdo nunca é exibido."
        )
    )
    parser.add_argument("--session-key", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument(
        "--expected-source-sha256",
        required=True,
    )
    parser.add_argument(
        "--expected-content-sha256",
        required=True,
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

    parser.add_argument(
        "--write",
        action="store_true",
        help="habilita chamada controlada a ingest_session_v2",
    )
    parser.add_argument(
        "--approve",
        help="SHA-256 de aprovação emitido pelo dry-run",
    )
    parser.add_argument("--psql-bin", default=PSQL_DEFAULT)
    parser.add_argument("--pg-host")
    parser.add_argument("--pg-port", type=int)
    parser.add_argument("--pg-db", default=PG_DB_DEFAULT)
    parser.add_argument(
        "--allow-production",
        action="store_true",
        help=(
            "permite explicitamente /run/postgresql; "
            "não implica autorização operacional"
        ),
    )

    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    capture = load_capture_module()

    session_id = canonical_uuid(arguments.session_id)
    if not arguments.session_key or (
        len(arguments.session_key) > MAX_SESSION_KEY_CHARS
    ):
        reject("session_key inválida")

    expected_source = validate_sha256(
        arguments.expected_source_sha256,
        "expected source SHA-256",
    )
    expected_content = validate_sha256(
        arguments.expected_content_sha256,
        "expected content SHA-256",
    )

    capture_args = argparse.Namespace(
        node_bin=arguments.node_bin,
        openclaw_entry=arguments.openclaw_entry,
        agent=arguments.agent,
        page_limit=arguments.page_limit,
        max_pages=arguments.max_pages,
        max_chars_per_message=arguments.max_chars_per_message,
        max_source_chars=arguments.max_source_chars,
        timeout_seconds=arguments.timeout_seconds,
    )
    config = capture.build_config(capture_args)

    metadata, content = capture_selected(
        capture,
        config,
        arguments.session_key,
        session_id,
    )

    validate_expected_hashes(
        metadata,
        expected_source,
        expected_content,
    )

    approve = approval_digest(
        session_id,
        arguments.session_key,
        expected_source,
        expected_content,
    )

    event_id: str | None = None
    mode = "dry-run"

    if arguments.write:
        mode = "write"

        if arguments.approve != approve:
            reject("aprovação explícita ausente ou divergente")

        if current_unix_user() != "openclaw":
            reject("write exige usuário Unix openclaw")

        if arguments.pg_host is None or arguments.pg_port is None:
            reject("write exige --pg-host e --pg-port")

        if not 1 <= arguments.pg_port <= 65535:
            reject("pg-port inválida")

        if arguments.pg_db != PG_DB_DEFAULT:
            reject("pg-db não autorizada")

        resolved_host = validate_local_socket(
            arguments.pg_host,
            arguments.pg_port,
        )

        if (
            resolved_host == PRODUCTION_SOCKET
            and not arguments.allow_production
        ):
            reject(
                "socket de produção exige --allow-production explícito"
            )

        sql = build_psql_script(metadata, content)
        event_id = run_psql(
            psql_bin=arguments.psql_bin,
            pg_host=str(resolved_host),
            pg_port=arguments.pg_port,
            pg_db=arguments.pg_db,
            sql=sql,
            timeout_seconds=arguments.timeout_seconds,
        )

    summary = safe_summary(
        metadata,
        mode=mode,
        approval_sha256=approve,
        event_id=event_id,
    )

    json.dump(
        summary,
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except WriterError as error:
        print(f"ERRO: {error}", file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("ERRO: execução interrompida.", file=sys.stderr)
        raise SystemExit(130)
    except Exception:
        print(
            "ERRO: falha interna no writer controlado.",
            file=sys.stderr,
        )
        raise SystemExit(1)
