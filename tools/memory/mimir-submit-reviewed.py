#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any


PSQL = [
    "psql",
    "-X",
    "-w",
    "-q",
    "-A",
    "-t",
    "-h",
    "/run/postgresql",
    "-U",
    "mimir_app",
    "-d",
    "mimir_memory",
    "-v",
    "ON_ERROR_STOP=1",
]

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

REQUIRED_TEXT_FIELDS = (
    "memory_key",
    "memory_type",
    "title",
    "summary",
    "content",
    "evidence",
    "reason",
)

EXPECTED_PROMPT = "consolidator-v1"
EXPECTED_MODEL = "nvidia/nemotron-3-super-120b-a12b"
EXPECTED_REVIEWER = "Nogueira Maier"
EXPECTED_REVIEW_STATUS = "approved_for_candidate_submission"


def fail(message: str) -> None:
    raise SystemExit(f"ERRO: {message}")


def run_psql(sql: str) -> str:
    process = subprocess.run(
        PSQL,
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )

    if process.returncode != 0:
        if process.stderr:
            sys.stderr.write(process.stderr)
        fail(f"psql terminou com código {process.returncode}")

    return process.stdout.strip()


def require_text(
    source: dict[str, Any],
    field: str,
    context: str,
) -> str:
    value = source.get(field)

    if not isinstance(value, str) or not value.strip():
        fail(f"{context}: campo {field!r} inválido")

    return value.strip()


def require_score(
    source: dict[str, Any],
    field: str,
    context: str,
) -> float:
    value = source.get(field)

    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
    ):
        fail(f"{context}: campo {field!r} não é numérico")

    score = float(value)

    if score < 0 or score > 1:
        fail(f"{context}: campo {field!r} fora do intervalo 0–1")

    return score


def validate_file_security(path: Path) -> None:
    info = path.stat()
    mode = stat.S_IMODE(info.st_mode)

    if info.st_uid != os.geteuid():
        fail(
            "o arquivo revisado não pertence ao usuário que está "
            "executando o importador"
        )

    if mode & 0o077:
        fail(
            f"permissões inseguras no arquivo: {mode:o}; "
            "esperado 600"
        )


def load_and_validate(
    path: Path,
    expected_hash: str,
    expected_event_id: str,
    max_candidates: int,
) -> tuple[bytes, dict[str, Any], list[dict[str, Any]]]:
    if not path.is_file():
        fail(f"arquivo não encontrado: {path}")

    validate_file_security(path)

    raw = path.read_bytes()
    actual_hash = hashlib.sha256(raw).hexdigest()

    if actual_hash != expected_hash:
        fail(
            "SHA-256 divergente\n"
            f"Esperado: {expected_hash}\n"
            f"Obtido:   {actual_hash}"
        )

    try:
        document = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"JSON inválido: {exc}")

    if not isinstance(document, dict):
        fail("a raiz do JSON deve ser um objeto")

    if document.get("mode") != "dry-run":
        fail("mode deve ser dry-run")

    if document.get("database_write") is not False:
        fail("database_write deve ser false")

    if document.get("event_id") != expected_event_id:
        fail("event_id do arquivo não corresponde ao informado")

    if document.get("prompt_version") != EXPECTED_PROMPT:
        fail(
            "prompt_version inesperado: "
            f"{document.get('prompt_version')!r}"
        )

    if document.get("model") != EXPECTED_MODEL:
        fail(f"modelo inesperado: {document.get('model')!r}")

    source_ref = require_text(
        document,
        "source_ref",
        "documento",
    )

    review = document.get("human_review")

    if not isinstance(review, dict):
        fail("human_review ausente ou inválido")

    if review.get("status") != EXPECTED_REVIEW_STATUS:
        fail("status da revisão humana não autorizado")

    if review.get("reviewed_by") != EXPECTED_REVIEWER:
        fail("identidade do revisor não corresponde ao esperado")

    candidates = document.get("candidates")

    if not isinstance(candidates, list):
        fail("candidates deve ser uma lista")

    if not candidates:
        fail("nenhum candidato encontrado")

    if len(candidates) > max_candidates:
        fail(
            f"quantidade de candidatos excede o limite "
            f"de {max_candidates}"
        )

    if document.get("candidate_count") != len(candidates):
        fail("candidate_count não corresponde à lista")

    normalized: list[dict[str, Any]] = []
    keys: set[str] = set()

    for index, candidate in enumerate(candidates, start=1):
        context = f"candidato {index}"

        if not isinstance(candidate, dict):
            fail(f"{context}: deve ser um objeto")

        for field in REQUIRED_TEXT_FIELDS:
            require_text(candidate, field, context)

        memory_key = candidate["memory_key"].strip()
        memory_type = candidate["memory_type"].strip()

        if memory_type not in ALLOWED_TYPES:
            fail(
                f"{context}: memory_type inválido: "
                f"{memory_type}"
            )

        if memory_key in keys:
            fail(f"{context}: memory_key duplicada: {memory_key}")

        if not re.fullmatch(
            r"[a-z0-9][a-z0-9._-]{2,199}",
            memory_key,
        ):
            fail(
                f"{context}: formato inválido de memory_key: "
                f"{memory_key}"
            )

        keys.add(memory_key)

        confidence = require_score(
            candidate,
            "confidence",
            context,
        )

        importance = require_score(
            candidate,
            "importance",
            context,
        )

        pinned = candidate.get("pinned", False)

        if not isinstance(pinned, bool):
            fail(f"{context}: pinned deve ser booleano")

        normalized.append(
            {
                **candidate,
                "memory_key": memory_key,
                "memory_type": memory_type,
                "confidence": confidence,
                "importance": importance,
                "pinned": pinned,
            }
        )

    document["source_ref"] = source_ref
    document["candidates"] = normalized

    return raw, document, normalized


def validate_source_event(
    document: dict[str, Any],
    candidates: list[dict[str, Any]],
) -> None:
    event_id = str(uuid.UUID(document["event_id"]))

    sql = f"""
SELECT json_build_object(
    'event_id', event_id,
    'source_type', source_type,
    'source_ref', source_ref,
    'classification', classification,
    'content', content
)::text
FROM mimir.memory_events
WHERE event_id = '{event_id}'::uuid;
"""

    output = run_psql(sql)

    if not output:
        fail(f"evento não encontrado no PostgreSQL: {event_id}")

    try:
        source = json.loads(output)
    except json.JSONDecodeError as exc:
        fail(f"resposta inválida do PostgreSQL: {exc}")

    if source.get("source_type") != "workspace-markdown":
        fail(
            "source_type não autorizado: "
            f"{source.get('source_type')!r}"
        )

    if source.get("source_ref") != document["source_ref"]:
        fail("source_ref diverge do evento armazenado")

    if source.get("classification") not in {"public", "internal"}:
        fail(
            "classificação não permitida para consolidação externa"
        )

    source_content = source.get("content")

    if not isinstance(source_content, str):
        fail("evento não possui conteúdo textual")

    for index, candidate in enumerate(candidates, start=1):
        evidence = candidate["evidence"].strip()

        if evidence not in source_content:
            fail(
                f"candidato {index}: evidência literal não foi "
                "encontrada na fonte"
            )


def submit_candidates(
    raw: bytes,
    expected_hash: str,
    event_id: str,
    max_candidates: int,
) -> list[dict[str, Any]]:
    encoded = base64.b64encode(raw).decode("ascii")

    sql = f"""
BEGIN;

SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE reviewed_submission_stage (
    encoded_document text NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE reviewed_submission_result (
    ordinal integer NOT NULL,
    memory_id uuid NOT NULL,
    memory_key text NOT NULL,
    memory_type text NOT NULL
) ON COMMIT DROP;

COPY reviewed_submission_stage(encoded_document) FROM STDIN;
{encoded}
\\.

DO $submission$
DECLARE
    v_encoded          text;
    v_hash             text;
    v_document         jsonb;
    v_candidate        jsonb;
    v_event_id         uuid;
    v_source_ref       text;
    v_classification   text;
    v_source_content   text;
    v_memory_id        uuid;
    v_ordinal          integer := 0;
BEGIN
    SELECT encoded_document
    INTO STRICT v_encoded
    FROM reviewed_submission_stage;

    v_hash := encode(
        digest(
            decode(v_encoded, 'base64'),
            'sha256'
        ),
        'hex'
    );

    IF v_hash <> '{expected_hash}' THEN
        RAISE EXCEPTION
            'SHA-256 do documento revisado não corresponde';
    END IF;

    v_document := convert_from(
        decode(v_encoded, 'base64'),
        'UTF8'
    )::jsonb;

    IF v_document ->> 'mode' <> 'dry-run' THEN
        RAISE EXCEPTION 'modo inválido';
    END IF;

    IF v_document -> 'database_write'
       IS DISTINCT FROM 'false'::jsonb
    THEN
        RAISE EXCEPTION
            'database_write deve ser false';
    END IF;

    IF v_document ->> 'prompt_version'
       <> '{EXPECTED_PROMPT}'
    THEN
        RAISE EXCEPTION
            'versão de prompt não autorizada';
    END IF;

    IF v_document ->> 'model'
       <> '{EXPECTED_MODEL}'
    THEN
        RAISE EXCEPTION
            'modelo não autorizado';
    END IF;

    IF v_document #>> '{{human_review,status}}'
       <> '{EXPECTED_REVIEW_STATUS}'
    THEN
        RAISE EXCEPTION
            'revisão humana não autorizada';
    END IF;

    IF v_document #>> '{{human_review,reviewed_by}}'
       <> '{EXPECTED_REVIEWER}'
    THEN
        RAISE EXCEPTION
            'revisor não autorizado';
    END IF;

    v_event_id := (
        v_document ->> 'event_id'
    )::uuid;

    IF v_event_id <> '{event_id}'::uuid THEN
        RAISE EXCEPTION
            'event_id não corresponde ao autorizado';
    END IF;

    IF jsonb_typeof(v_document -> 'candidates')
       <> 'array'
    THEN
        RAISE EXCEPTION
            'candidates não é uma lista';
    END IF;

    IF jsonb_array_length(
        v_document -> 'candidates'
    ) < 1
       OR jsonb_array_length(
           v_document -> 'candidates'
       ) > {max_candidates}
    THEN
        RAISE EXCEPTION
            'quantidade de candidatos inválida';
    END IF;

    SELECT
        source_ref,
        classification,
        content
    INTO
        v_source_ref,
        v_classification,
        v_source_content
    FROM mimir.memory_events
    WHERE event_id = v_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'evento de origem não encontrado';
    END IF;

    IF v_source_ref
       <> v_document ->> 'source_ref'
    THEN
        RAISE EXCEPTION
            'source_ref divergente';
    END IF;

    IF v_classification
       NOT IN ('public', 'internal')
    THEN
        RAISE EXCEPTION
            'classificação da fonte não autorizada';
    END IF;

    FOR v_candidate IN
        SELECT value
        FROM jsonb_array_elements(
            v_document -> 'candidates'
        )
    LOOP
        v_ordinal := v_ordinal + 1;

        IF coalesce(
            btrim(v_candidate ->> 'evidence'),
            ''
        ) = ''
        THEN
            RAISE EXCEPTION
                'candidato % sem evidência',
                v_ordinal;
        END IF;

        IF position(
            (v_candidate ->> 'evidence')
            IN v_source_content
        ) = 0
        THEN
            RAISE EXCEPTION
                'evidência do candidato % não existe na fonte',
                v_ordinal;
        END IF;

        v_memory_id := mimir.propose_memory(
            v_event_id,
            v_candidate ->> 'memory_key',
            v_candidate ->> 'memory_type',
            v_candidate ->> 'title',
            v_candidate ->> 'summary',
            v_candidate ->> 'content',
            (v_candidate ->> 'confidence')::numeric,
            (v_candidate ->> 'importance')::numeric,
            coalesce(
                (v_candidate ->> 'pinned')::boolean,
                false
            ),
            jsonb_build_object(
                'submission_type',
                'human-reviewed-nemotron',
                'reviewed_file_sha256',
                v_hash,
                'prompt_version',
                v_document ->> 'prompt_version',
                'model',
                v_document ->> 'model',
                'source_ref',
                v_source_ref,
                'evidence',
                v_candidate ->> 'evidence',
                'selection_reason',
                v_candidate ->> 'reason',
                'human_review',
                v_document -> 'human_review'
            ),
            'mimir-consolidator-reviewed'
        );

        INSERT INTO reviewed_submission_result (
            ordinal,
            memory_id,
            memory_key,
            memory_type
        )
        VALUES (
            v_ordinal,
            v_memory_id,
            v_candidate ->> 'memory_key',
            v_candidate ->> 'memory_type'
        );
    END LOOP;
END
$submission$;

SELECT coalesce(
    jsonb_agg(
        jsonb_build_object(
            'ordinal', ordinal,
            'memory_id', memory_id,
            'memory_key', memory_key,
            'memory_type', memory_type
        )
        ORDER BY ordinal
    ),
    '[]'::jsonb
)::text
FROM reviewed_submission_result;

COMMIT;
"""

    output = run_psql(sql)

    try:
        result = json.loads(output)
    except json.JSONDecodeError as exc:
        fail(f"resultado de submissão inválido: {exc}")

    if not isinstance(result, list):
        fail("resultado da submissão não é uma lista")

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Valida e envia candidatos revisados para "
            "mimir.propose_memory()."
        )
    )

    parser.add_argument(
        "--file",
        required=True,
        type=Path,
        help="Arquivo JSON revisado.",
    )

    parser.add_argument(
        "--sha256",
        required=True,
        help="SHA-256 autorizado do arquivo.",
    )

    parser.add_argument(
        "--event-id",
        required=True,
        help="UUID do evento de origem.",
    )

    parser.add_argument(
        "--max-candidates",
        type=int,
        default=5,
    )

    parser.add_argument(
        "--submit",
        action="store_true",
        help="Efetua a submissão. Sem esta opção, apenas valida.",
    )

    args = parser.parse_args()

    expected_hash = args.sha256.lower().strip()

    if not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
        fail("SHA-256 informado possui formato inválido")

    try:
        event_id = str(uuid.UUID(args.event_id))
    except ValueError:
        fail("event-id inválido")

    if args.max_candidates < 1 or args.max_candidates > 20:
        fail("max-candidates deve estar entre 1 e 20")

    raw, document, candidates = load_and_validate(
        args.file,
        expected_hash,
        event_id,
        args.max_candidates,
    )

    validate_source_event(document, candidates)

    print("Validação local e PostgreSQL: APROVADA")
    print("Arquivo:", args.file)
    print("SHA-256:", expected_hash)
    print("Evento:", event_id)
    print("Fonte:", document["source_ref"])
    print("Candidatos:", len(candidates))
    print("Modo de execução:", "SUBMIT" if args.submit else "VALIDAÇÃO")

    if not args.submit:
        print()
        print("Nenhum registro foi gravado.")
        return

    result = submit_candidates(
        raw,
        expected_hash,
        event_id,
        args.max_candidates,
    )

    print()
    print("Candidatos enviados ao PostgreSQL:")

    for item in result:
        print(
            "{ordinal}: {memory_key} | {memory_type} | {memory_id}".format(
                **item
            )
        )

    print()
    print("Submissão concluída.")
    print("Status permitido nesta etapa: candidate")


if __name__ == "__main__":
    main()
