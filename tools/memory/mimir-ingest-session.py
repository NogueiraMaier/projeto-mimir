#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pwd
import re
import stat
import sys
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import NoReturn


SESSIONS_DIR = Path(
    "/var/lib/openclaw/.openclaw/agents/main/sessions"
)
INDEX_NAME = "sessions.json"
NORMALIZATION_VERSION = "openclaw-text-v1"
MAX_INDEX_BYTES = 4 * 1024 * 1024
MAX_SOURCE_BYTES = 10 * 1024 * 1024
MAX_CONTENT_BYTES = 8 * 1024 * 1024
MAX_JSONL_LINES = 100_000
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-"
    r"[0-9a-f]{4}-"
    r"[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-"
    r"[0-9a-f]{12}$"
)


class ClientError(Exception):
    pass


@dataclass(frozen=True)
class Snapshot:
    content: bytes
    size: int
    mtime_ns: int
    mode: int
    uid: int
    device: int
    inode: int


@dataclass(frozen=True)
class Transcript:
    content: str
    line_count: int
    user_messages: int
    assistant_messages: int
    excluded_tool_results: int
    excluded_tool_calls: int


def reject(message: str) -> NoReturn:
    raise ClientError(message)


def validate_session_id(value: str) -> str:
    if not UUID_PATTERN.fullmatch(value):
        reject("session_id fora do padrão UUID autorizado.")

    try:
        parsed = uuid.UUID(value)
    except ValueError:
        reject("session_id inválido.")

    if str(parsed) != value:
        reject("session_id não está em formato canônico.")

    return value


def validate_sha256(value: str) -> str:
    normalized = value.lower()

    if not SHA256_PATTERN.fullmatch(normalized):
        reject("SHA-256 esperado inválido.")

    return normalized


def validate_directory(path: Path, expected_uid: int) -> Path:
    try:
        source_stat = path.lstat()
    except OSError:
        reject("diretório de sessões indisponível.")

    if not stat.S_ISDIR(source_stat.st_mode):
        reject("caminho de sessões não é diretório.")

    if path.is_symlink():
        reject("diretório de sessões é link simbólico.")

    try:
        resolved = path.resolve(strict=True)
    except OSError:
        reject("falha ao resolver o diretório de sessões.")

    if resolved != path:
        reject("diretório de sessões possui redirecionamento.")

    if source_stat.st_uid != expected_uid:
        reject("proprietário do diretório de sessões inválido.")

    return resolved


def read_secure_file(
    path: Path,
    expected_uid: int,
    maximum_bytes: int,
) -> Snapshot:
    try:
        path_stat = path.lstat()
    except OSError:
        reject("arquivo protegido indisponível.")

    if not stat.S_ISREG(path_stat.st_mode):
        reject("fonte não é arquivo regular.")

    if path.is_symlink():
        reject("fonte é link simbólico.")

    mode = stat.S_IMODE(path_stat.st_mode)

    if mode & 0o077:
        reject("fonte possui permissões excessivas.")

    if path_stat.st_uid != expected_uid:
        reject("proprietário da fonte inválido.")

    if path_stat.st_size <= 0:
        reject("fonte vazia.")

    if path_stat.st_size > maximum_bytes:
        reject("fonte excede o limite de tamanho.")

    flags = os.O_RDONLY | os.O_CLOEXEC

    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW

    try:
        descriptor = os.open(path, flags)
    except OSError:
        reject("falha na abertura protegida da fonte.")

    try:
        before = os.fstat(descriptor)

        if not stat.S_ISREG(before.st_mode):
            reject("descritor não representa arquivo regular.")

        if (
            before.st_dev != path_stat.st_dev
            or before.st_ino != path_stat.st_ino
        ):
            reject("fonte mudou antes da leitura.")

        chunks: list[bytes] = []
        total = 0

        while True:
            chunk = os.read(descriptor, 1024 * 1024)

            if not chunk:
                break

            total += len(chunk)

            if total > maximum_bytes:
                reject("fonte excedeu o limite durante a leitura.")

            chunks.append(chunk)

        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)

    try:
        final_stat = path.lstat()
    except OSError:
        reject("fonte desapareceu após a leitura.")

    immutable_fields = (
        before.st_dev == after.st_dev == final_stat.st_dev,
        before.st_ino == after.st_ino == final_stat.st_ino,
        before.st_size == after.st_size == final_stat.st_size,
        before.st_mtime_ns
        == after.st_mtime_ns
        == final_stat.st_mtime_ns,
    )

    if not all(immutable_fields):
        reject("fonte mudou durante a leitura.")

    content = b"".join(chunks)

    if len(content) != after.st_size:
        reject("tamanho lido diverge do tamanho registrado.")

    return Snapshot(
        content=content,
        size=after.st_size,
        mtime_ns=after.st_mtime_ns,
        mode=stat.S_IMODE(after.st_mode),
        uid=after.st_uid,
        device=after.st_dev,
        inode=after.st_ino,
    )


def parse_index(
    raw_index: bytes,
    session_id: str,
    sessions_dir: Path,
) -> tuple[dict[str, object], Path]:
    try:
        decoded = raw_index.decode("utf-8")
    except UnicodeDecodeError:
        reject("sessions.json não está em UTF-8 válido.")

    try:
        index = json.loads(decoded)
    except json.JSONDecodeError:
        reject("sessions.json contém JSON inválido.")

    if not isinstance(index, dict):
        reject("raiz de sessions.json não é objeto.")

    expected_name = f"{session_id}.jsonl"
    matches: list[tuple[dict[str, object], Path]] = []

    for entry in index.values():
        if not isinstance(entry, dict):
            continue

        if entry.get("status") != "done":
            continue

        if entry.get("endedAt") in (None, ""):
            continue

        session_file = entry.get("sessionFile")

        if not isinstance(session_file, str):
            continue

        candidate = Path(session_file)

        if not candidate.is_absolute():
            candidate = sessions_dir / candidate

        try:
            resolved = candidate.resolve(strict=True)
        except OSError:
            continue

        if resolved.parent != sessions_dir:
            continue

        if resolved.name != expected_name:
            continue

        matches.append((entry, candidate))

    if len(matches) != 1:
        reject(
            "sessão não possui uma única entrada done e encerrada."
        )

    entry, source_path = matches[0]

    try:
        resolved_source = source_path.resolve(strict=True)
    except OSError:
        reject("arquivo da sessão indisponível.")

    if resolved_source.parent != sessions_dir:
        reject("arquivo da sessão está fora do diretório autorizado.")

    if resolved_source.name != expected_name:
        reject("nome do arquivo diverge do session_id.")

    if source_path.is_symlink():
        reject("arquivo da sessão é link simbólico.")

    return entry, resolved_source


def extract_text_parts(content: object) -> list[str]:
    if isinstance(content, str):
        return [content]

    if not isinstance(content, list):
        return []

    parts: list[str] = []

    for item in content:
        if not isinstance(item, dict):
            continue

        if item.get("type") != "text":
            continue

        text_value = item.get("text")

        if isinstance(text_value, str):
            parts.append(text_value)

    return parts


def normalize_text(value: str) -> str:
    normalized = value.replace("\r\n", "\n").replace("\r", "\n")

    if "\x00" in normalized:
        reject("texto contém caractere nulo incompatível.")

    return normalized.strip()


def build_transcript(raw_source: bytes) -> Transcript:
    blocks: list[str] = []
    line_count = 0
    user_messages = 0
    assistant_messages = 0
    excluded_tool_results = 0
    excluded_tool_calls = 0

    for raw_line in raw_source.splitlines():
        if not raw_line.strip():
            continue

        line_count += 1

        if line_count > MAX_JSONL_LINES:
            reject("sessão excede o limite de eventos.")

        try:
            decoded_line = raw_line.decode("utf-8")
        except UnicodeDecodeError:
            reject(f"UTF-8 inválido no evento {line_count}.")

        try:
            event = json.loads(decoded_line)
        except json.JSONDecodeError:
            reject(f"JSON inválido no evento {line_count}.")

        if not isinstance(event, dict):
            reject(f"evento {line_count} não é objeto.")

        if event.get("type") != "message":
            continue

        message = event.get("message")

        if not isinstance(message, dict):
            if "role" in event:
                message = event
            else:
                reject(
                    f"mensagem inválida no evento {line_count}."
                )

        role = message.get("role")
        content = message.get("content")

        if role == "toolResult":
            excluded_tool_results += 1
            continue

        if role not in ("user", "assistant"):
            continue

        if role == "user":
            user_messages += 1
        else:
            assistant_messages += 1

        if isinstance(content, list):
            excluded_tool_calls += sum(
                1
                for item in content
                if isinstance(item, dict)
                and item.get("type") == "toolCall"
            )

        parts = extract_text_parts(content)
        cleaned_parts: list[str] = []

        for part in parts:
            cleaned = normalize_text(part)

            if cleaned:
                cleaned_parts.append(cleaned)

        if not cleaned_parts:
            continue

        label = "user" if role == "user" else "assistant"
        blocks.append(
            f"{label}:\n" + "\n".join(cleaned_parts)
        )

    if line_count == 0:
        reject("sessão não possui eventos.")

    if user_messages < 1:
        reject("sessão não possui mensagem user.")

    if assistant_messages < 1:
        reject("sessão não possui mensagem assistant.")

    if not blocks:
        reject("sessão não produziu conteúdo textual.")

    normalized_content = "\n\n".join(blocks) + "\n"
    encoded_content = normalized_content.encode("utf-8")

    if len(encoded_content) > MAX_CONTENT_BYTES:
        reject("transcrição normalizada excede o limite.")

    return Transcript(
        content=normalized_content,
        line_count=line_count,
        user_messages=user_messages,
        assistant_messages=assistant_messages,
        excluded_tool_results=excluded_tool_results,
        excluded_tool_calls=excluded_tool_calls,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Valida uma sessão encerrada do OpenClaw sem exibir "
            "a transcrição."
        )
    )
    parser.add_argument(
        "--session-id",
        required=True,
        help="UUID canônico da sessão selecionada",
    )
    parser.add_argument(
        "--expected-source-sha256",
        required=True,
        help="SHA-256 esperado do arquivo JSONL",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="valida sem escrever no PostgreSQL",
    )

    arguments = parser.parse_args()

    if not arguments.dry_run:
        reject("esta versão aceita somente --dry-run.")

    session_id = validate_session_id(arguments.session_id)
    expected_hash = validate_sha256(
        arguments.expected_source_sha256
    )

    try:
        openclaw_uid = pwd.getpwnam("openclaw").pw_uid
    except KeyError:
        reject("usuário openclaw não localizado.")

    sessions_dir = validate_directory(
        SESSIONS_DIR,
        openclaw_uid,
    )

    index_path = sessions_dir / INDEX_NAME
    index_snapshot = read_secure_file(
        index_path,
        openclaw_uid,
        MAX_INDEX_BYTES,
    )

    _, source_path = parse_index(
        index_snapshot.content,
        session_id,
        sessions_dir,
    )

    lock_paths = (
        Path(str(source_path) + ".lock"),
        source_path.with_suffix(".lock"),
    )

    if any(path.exists() for path in lock_paths):
        reject("sessão possui arquivo de bloqueio.")

    source_snapshot = read_secure_file(
        source_path,
        openclaw_uid,
        MAX_SOURCE_BYTES,
    )

    if any(path.exists() for path in lock_paths):
        reject("sessão foi bloqueada durante a leitura.")

    source_hash = hashlib.sha256(
        source_snapshot.content
    ).hexdigest()

    if source_hash != expected_hash:
        reject("SHA-256 da fonte diverge do valor aprovado.")

    transcript = build_transcript(source_snapshot.content)
    content_bytes = transcript.content.encode("utf-8")
    content_hash = hashlib.sha256(content_bytes).hexdigest()

    source_mtime = datetime.fromtimestamp(
        source_snapshot.mtime_ns / 1_000_000_000,
        tz=timezone.utc,
    ).isoformat()

    results = (
        ("mode", "dry-run"),
        ("result", "approved"),
        ("session_id", session_id),
        (
            "source_ref",
            f"agents/main/sessions/{session_id}.jsonl",
        ),
        ("classification", "confidential"),
        ("normalization", NORMALIZATION_VERSION),
        ("source_bytes", str(source_snapshot.size)),
        ("source_sha256", source_hash),
        ("source_mtime", source_mtime),
        ("line_count", str(transcript.line_count)),
        ("user_messages", str(transcript.user_messages)),
        (
            "assistant_messages",
            str(transcript.assistant_messages),
        ),
        (
            "excluded_tool_results",
            str(transcript.excluded_tool_results),
        ),
        (
            "excluded_tool_calls",
            str(transcript.excluded_tool_calls),
        ),
        ("content_bytes", str(len(content_bytes))),
        ("content_sha256", content_hash),
        ("transcript_displayed", "false"),
        ("database_write", "false"),
        ("external_api", "false"),
        ("memory_promotion", "false"),
    )

    for key, value in results:
        print(f"{key}={value}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ClientError as error:
        print(f"ERRO: {error}", file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("ERRO: execução interrompida.", file=sys.stderr)
        raise SystemExit(130)
    except Exception:
        print(
            "ERRO: falha interna durante a validação segura.",
            file=sys.stderr,
        )
        raise SystemExit(1)
