#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from typing import Any

DB_SOCKET = "/run/postgresql"
DB_NAME = "mimir_memory"
DB_USER = "mimir_app"
API_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
DEFAULT_MODEL = "nvidia/nemotron-3-super-120b-a12b"
PROMPT_FILE = Path(
    "/var/lib/openclaw/workspace/tools/memory/prompts/"
    "consolidator-v1.txt"
)

ALLOWED_TYPES = {
    "semantic",
    "episodic",
    "procedural",
    "decision",
    "task",
    "evidence",
    "preference",
    "entity",
}

KEY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
SECRET_RE = re.compile(
    r"(?:"
    r"nvapi-[A-Za-z0-9_-]{20,}|"
    r"sk-[A-Za-z0-9_-]{20,}|"
    r"authorization\s*:\s*bearer\s+\S{20,}|"
    r"(?:api[_-]?key|password|senha|token|secret)"
    r"\s*[:=]\s*\S{8,}"
    r")",
    re.IGNORECASE,
)


class ConsolidatorError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Extrai candidatos de memória com Nemotron em modo dry-run. "
            "Não grava memory_records."
        )
    )
    parser.add_argument("--event-id", required=True, help="UUID do memory_event")
    parser.add_argument(
        "--max-candidates",
        type=int,
        default=5,
        help="Máximo de candidatos aceitos (1 a 10; padrão: 5)",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Modelo NVIDIA (padrão: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--max-source-chars",
        type=int,
        default=60000,
        help="Limite de caracteres enviados ao modelo (padrão: 60000)",
    )
    return parser.parse_args()


def run_psql(sql: str) -> str:
    cmd = [
        "psql",
        "-X",
        "-w",
        "-h",
        DB_SOCKET,
        "-U",
        DB_USER,
        "-d",
        DB_NAME,
        "-v",
        "ON_ERROR_STOP=1",
        "-Atqc",
        sql,
    ]
    try:
        completed = subprocess.run(
            cmd,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ConsolidatorError("psql não encontrado no PATH") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or "").strip()
        raise ConsolidatorError(f"falha ao consultar PostgreSQL: {detail}") from exc

    return completed.stdout.strip()


def fetch_event(event_id: uuid.UUID) -> dict[str, Any]:
    sql = f"""
SELECT encode(
    convert_to(
        jsonb_build_object(
            'event_id', event_id,
            'occurred_at', occurred_at,
            'scope_type', scope_type,
            'scope_key', scope_key,
            'event_type', event_type,
            'source_type', source_type,
            'source_ref', source_ref,
            'classification', classification,
            'content', content
        )::text,
        'UTF8'
    ),
    'base64'
)
FROM mimir.memory_events
WHERE event_id = '{event_id}'::uuid;
"""
    encoded = run_psql(sql)
    if not encoded:
        raise ConsolidatorError(f"evento não encontrado: {event_id}")

    try:
        raw = base64.b64decode(encoded, validate=False).decode("utf-8")
        event = json.loads(raw)
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ConsolidatorError("resposta inválida ao ler o evento") from exc

    if not isinstance(event, dict):
        raise ConsolidatorError("evento retornado não é um objeto JSON")

    return event


def normalize_space(value: str) -> str:
    return " ".join(value.split())


def require_text(
    candidate: dict[str, Any],
    field: str,
    *,
    minimum: int,
    maximum: int,
) -> str:
    value = candidate.get(field)
    if not isinstance(value, str):
        raise ConsolidatorError(f"campo {field!r} deve ser texto")

    value = value.strip()
    if not minimum <= len(value) <= maximum:
        raise ConsolidatorError(
            f"campo {field!r} deve ter entre {minimum} e {maximum} caracteres"
        )
    return value


def require_score(candidate: dict[str, Any], field: str) -> float:
    value = candidate.get(field)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConsolidatorError(f"campo {field!r} deve ser numérico")

    score = float(value)
    if not 0.0 <= score <= 1.0:
        raise ConsolidatorError(f"campo {field!r} deve estar entre 0 e 1")
    return round(score, 3)


def validate_candidates(
    model_output: Any,
    source_content: str,
    max_candidates: int,
) -> list[dict[str, Any]]:
    if not isinstance(model_output, dict):
        raise ConsolidatorError("saída do modelo deve ser um objeto JSON")

    unknown_top = set(model_output) - {"candidates"}
    if unknown_top:
        raise ConsolidatorError(
            "campos não permitidos na raiz: " + ", ".join(sorted(unknown_top))
        )

    candidates = model_output.get("candidates")
    if not isinstance(candidates, list):
        raise ConsolidatorError("campo 'candidates' deve ser uma lista")

    if len(candidates) > max_candidates:
        raise ConsolidatorError(
            f"modelo retornou {len(candidates)} candidatos; limite é {max_candidates}"
        )

    normalized_source = normalize_space(source_content)
    validated: list[dict[str, Any]] = []
    dedupe: set[tuple[str, str]] = set()

    allowed_fields = {
        "memory_key",
        "memory_type",
        "title",
        "summary",
        "content",
        "confidence",
        "importance",
        "evidence",
        "reason",
    }

    for position, item in enumerate(candidates, start=1):
        if not isinstance(item, dict):
            raise ConsolidatorError(
                f"candidato {position} deve ser um objeto JSON"
            )

        unknown = set(item) - allowed_fields
        if unknown:
            raise ConsolidatorError(
                f"candidato {position} possui campos não permitidos: "
                + ", ".join(sorted(unknown))
            )

        memory_key = require_text(
            item, "memory_key", minimum=3, maximum=128
        ).lower()
        if not KEY_RE.fullmatch(memory_key):
            raise ConsolidatorError(
                f"candidato {position}: memory_key inválida"
            )

        memory_type = require_text(
            item, "memory_type", minimum=3, maximum=32
        ).lower()
        if memory_type not in ALLOWED_TYPES:
            raise ConsolidatorError(
                f"candidato {position}: memory_type inválido"
            )

        title = require_text(item, "title", minimum=3, maximum=200)
        summary = require_text(item, "summary", minimum=10, maximum=1000)
        content = require_text(item, "content", minimum=10, maximum=4000)
        evidence = require_text(item, "evidence", minimum=3, maximum=800)
        reason = require_text(item, "reason", minimum=10, maximum=1000)
        confidence = require_score(item, "confidence")
        importance = require_score(item, "importance")

        if normalize_space(evidence) not in normalized_source:
            raise ConsolidatorError(
                f"candidato {position}: evidence não é trecho literal da fonte"
            )

        combined = " ".join(
            (memory_key, title, summary, content, evidence, reason)
        )
        if SECRET_RE.search(combined):
            raise ConsolidatorError(
                f"candidato {position}: possível segredo ou credencial"
            )

        fingerprint = (
            memory_key,
            hashlib.sha256(content.encode("utf-8")).hexdigest(),
        )
        if fingerprint in dedupe:
            raise ConsolidatorError(
                f"candidato {position}: duplicado na resposta"
            )
        dedupe.add(fingerprint)

        validated.append(
            {
                "memory_key": memory_key,
                "memory_type": memory_type,
                "title": title,
                "summary": summary,
                "content": content,
                "confidence": confidence,
                "importance": importance,
                "evidence": evidence,
                "reason": reason,
            }
        )

    return validated


def extract_json_content(content: Any) -> Any:
    if not isinstance(content, str) or not content.strip():
        raise ConsolidatorError("modelo não retornou conteúdo textual")

    text = content.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ConsolidatorError(
            f"modelo retornou JSON inválido: linha {exc.lineno}, coluna {exc.colno}"
        ) from exc


def call_nvidia(
    api_key: str,
    model: str,
    prompt: str,
) -> tuple[Any, str]:
    request_body = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Você é um extrator conservador de memória. "
                    "Responda somente com JSON válido."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.1,
        "top_p": 0.9,
        "max_tokens": 4096,
        "stream": False,
        "response_format": {"type": "json_object"},
        "chat_template_kwargs": {"enable_thinking": False},
    }

    data = json.dumps(
        request_body, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")

    request = urllib.request.Request(
        API_URL,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "mimir-memory-consolidator/1.0",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            response_bytes = response.read()
            status = response.status
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")[:1200]
        raise ConsolidatorError(
            f"NVIDIA respondeu HTTP {exc.code}: {error_body}"
        ) from exc
    except urllib.error.URLError as exc:
        raise ConsolidatorError(f"falha de rede ao chamar NVIDIA: {exc}") from exc

    if status != 200:
        raise ConsolidatorError(f"NVIDIA respondeu HTTP inesperado: {status}")

    response_hash = hashlib.sha256(response_bytes).hexdigest()

    try:
        response_json = json.loads(response_bytes)
        content = response_json["choices"][0]["message"]["content"]
    except (json.JSONDecodeError, KeyError, IndexError, TypeError) as exc:
        raise ConsolidatorError("estrutura de resposta NVIDIA inválida") from exc

    return extract_json_content(content), response_hash


def main() -> int:
    args = parse_args()

    try:
        event_id = uuid.UUID(args.event_id)
    except ValueError:
        print("ERRO: --event-id não é um UUID válido", file=sys.stderr)
        return 2

    if not 1 <= args.max_candidates <= 10:
        print("ERRO: --max-candidates deve estar entre 1 e 10", file=sys.stderr)
        return 2

    if not 1000 <= args.max_source_chars <= 200000:
        print(
            "ERRO: --max-source-chars deve estar entre 1000 e 200000",
            file=sys.stderr,
        )
        return 2

    api_key = os.environ.get("NVIDIA_API_KEY", "").strip()
    if not api_key:
        print("ERRO: NVIDIA_API_KEY não definida", file=sys.stderr)
        return 2

    try:
        prompt_template = PROMPT_FILE.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"ERRO: não foi possível ler o prompt: {exc}", file=sys.stderr)
        return 2

    try:
        event = fetch_event(event_id)
        classification = str(event.get("classification") or "")

        if classification not in {"public", "internal"}:
            raise ConsolidatorError(
                "evento bloqueado para API externa: "
                f"classificação={classification!r}"
            )

        source_content = event.get("content")
        if not isinstance(source_content, str) or not source_content.strip():
            raise ConsolidatorError("evento não possui conteúdo textual")

        if len(source_content) > args.max_source_chars:
            raise ConsolidatorError(
                f"fonte possui {len(source_content)} caracteres; "
                f"limite é {args.max_source_chars}"
            )

        if SECRET_RE.search(source_content):
            raise ConsolidatorError(
                "fonte bloqueada: possível segredo ou credencial"
            )

        prompt = prompt_template.format(
            max_candidates=args.max_candidates,
            event_id=event_id,
            source_ref=event.get("source_ref") or "",
            source_type=event.get("source_type") or "",
            content=source_content,
        )

        model_output, response_hash = call_nvidia(
            api_key=api_key,
            model=args.model,
            prompt=prompt,
        )

        candidates = validate_candidates(
            model_output=model_output,
            source_content=source_content,
            max_candidates=args.max_candidates,
        )

        output = {
            "mode": "dry-run",
            "database_write": False,
            "event_id": str(event_id),
            "source_ref": event.get("source_ref"),
            "model": args.model,
            "prompt_version": "consolidator-v1",
            "prompt_sha256": hashlib.sha256(
                prompt_template.encode("utf-8")
            ).hexdigest(),
            "response_sha256": response_hash,
            "candidate_count": len(candidates),
            "candidates": candidates,
        }

        json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    except ConsolidatorError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
