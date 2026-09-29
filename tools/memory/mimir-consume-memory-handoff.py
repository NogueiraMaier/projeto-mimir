#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import pwd
import stat
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any


PSQL = os.environ.get(
    "PSQL",
    "/usr/lib64/postgresql-17/bin/psql",
)

MAX_REPORT_BYTES = 2 * 1024 * 1024

EXPECTED_REQUIRES = [
    "review",
    "deduplication",
    "contradiction_check",
    "version_preservation",
]

HANDOFF_KEYS = {
    "schema_version",
    "integration",
    "state",
    "source_ref",
    "client_id",
    "site_id",
    "device_id",
    "project",
    "classification",
    "record_type",
    "occurred_at",
    "confidence",
    "found_state",
    "changes",
    "validation",
    "inventory_updated",
    "deduplication_key",
    "requires",
    "automatic_promotion",
}


def fail(message: str) -> None:
    raise SystemExit(f"ERRO: {message}")


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def validate_file_security(path: Path) -> None:
    info = path.lstat()
    mode = stat.S_IMODE(info.st_mode)

    if path.is_symlink() or not stat.S_ISREG(info.st_mode):
        fail("arquivo deve ser regular e não pode ser symlink")

    if info.st_uid != os.geteuid():
        fail(
            "arquivo não pertence ao usuário que executa "
            "o consumidor"
        )

    if mode != 0o600:
        fail(
            f"permissões inseguras: {mode:o}; esperado 600"
        )


def require_dict(
    source: dict[str, Any],
    field: str,
) -> dict[str, Any]:
    value = source.get(field)

    if not isinstance(value, dict):
        fail(f"{field} deve ser objeto")

    return value


def require_text(
    source: dict[str, Any],
    field: str,
    maximum: int = 1024,
) -> str:
    value = source.get(field)

    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > maximum
    ):
        fail(f"{field} inválido")

    return value.strip()


def load_and_validate(
    path: Path,
    expected_report_sha256: str,
) -> dict[str, Any]:
    if not path.is_file():
        fail(f"arquivo inexistente: {path}")

    validate_file_security(path)

    raw = path.read_bytes()

    if len(raw) > MAX_REPORT_BYTES:
        fail("relatório excede 2 MiB")

    actual_report_sha256 = sha256_bytes(raw)

    if actual_report_sha256 != expected_report_sha256:
        fail(
            "SHA-256 do relatório diverge\n"
            f"Esperado: {expected_report_sha256}\n"
            f"Obtido:   {actual_report_sha256}"
        )

    try:
        report = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"relatório JSON inválido: {exc}")

    if not isinstance(report, dict):
        fail("relatório deve ser objeto JSON")

    if report.get("schema_version") != 1:
        fail("schema_version do relatório inválida")

    try:
        intervention_id = str(
            uuid.UUID(
                require_text(
                    report,
                    "intervention_id",
                    64,
                )
            )
        )
    except ValueError:
        fail("intervention_id inválido")

    status = require_text(report, "status", 32)

    if status not in {"collected", "validated"}:
        fail(
            "somente intervenções collected/validated "
            "podem entrar no handoff"
        )

    if report.get("closure_ready") is not True:
        fail("closure_ready deve ser true")

    if report.get("closed") is not False:
        fail("closed deve permanecer false")

    if report.get("inventory_updated") is not True:
        fail("inventory_updated deve ser true")

    validation = require_dict(report, "validation")

    if (
        validation.get("performed") is not True
        or validation.get("passed") is not True
    ):
        fail("validação operacional não aprovada")

    completed_at = require_text(
        report,
        "completed_at",
        128,
    )

    device = require_dict(report, "device")

    try:
        device_id = str(
            uuid.UUID(
                require_text(
                    device,
                    "device_id",
                    64,
                )
            )
        )
    except ValueError:
        fail("device.device_id inválido")

    handoff = require_dict(report, "memory_handoff")

    if set(handoff) != HANDOFF_KEYS:
        missing = sorted(HANDOFF_KEYS - set(handoff))
        extra = sorted(set(handoff) - HANDOFF_KEYS)
        fail(
            "campos do memory_handoff v1 divergentes; "
            f"missing={missing}; extra={extra}"
        )

    if handoff.get("schema_version") != 1:
        fail("memory_handoff.schema_version inválida")

    if handoff.get("integration") != "PARCIAL":
        fail("memory_handoff.integration deve ser PARCIAL")

    if handoff.get("state") != "pending_human_review":
        fail(
            "memory_handoff.state deve ser "
            "pending_human_review"
        )

    if handoff.get("project") != "projeto-mimir":
        fail("project inválido")

    if handoff.get("classification") != "confidential":
        fail("classification deve ser confidential")

    if handoff.get("record_type") != "evidence":
        fail("record_type deve ser evidence")

    if handoff.get("confidence") != (
        "collected_not_independently_reviewed"
    ):
        fail("confidence descritivo inválido")

    if handoff.get("automatic_promotion") is not False:
        fail("automatic_promotion deve permanecer false")

    if handoff.get("inventory_updated") is not True:
        fail("handoff sem inventário confirmado")

    if handoff.get("requires") != EXPECTED_REQUIRES:
        fail("requires do handoff v1 inválido")

    if not isinstance(handoff.get("found_state"), list):
        fail("found_state deve ser lista")

    if not handoff["found_state"]:
        fail("found_state não pode ser vazio")

    if not isinstance(handoff.get("changes"), list):
        fail("changes deve ser lista")

    if handoff.get("validation") != validation:
        fail(
            "validation do handoff diverge "
            "do relatório"
        )

    if handoff.get("occurred_at") != completed_at:
        fail(
            "occurred_at do handoff diverge "
            "de completed_at"
        )

    if handoff.get("device_id") != device_id:
        fail("device_id do handoff diverge do relatório")

    if handoff.get("source_ref") != (
        f"ops:{intervention_id}"
    ):
        fail("source_ref inválido")

    if handoff.get("deduplication_key") != intervention_id:
        fail("deduplication_key inválida")

    handoff_text = canonical_json(handoff)
    handoff_sha256 = sha256_bytes(
        handoff_text.encode("utf-8")
    )

    return {
        "report": report,
        "report_sha256": actual_report_sha256,
        "intervention_id": intervention_id,
        "device_id": device_id,
        "status": status,
        "completed_at": completed_at,
        "handoff": handoff,
        "handoff_text": handoff_text,
        "handoff_sha256": handoff_sha256,
        "source_ref": handoff["source_ref"],
        "deduplication_key":
            handoff["deduplication_key"],
    }


def create_psql_env() -> dict[str, str]:
    return {
        "HOME": "/var/lib/openclaw",
        "USER": "openclaw",
        "LOGNAME": "openclaw",
        "PATH": (
            "/usr/local/sbin:/usr/local/bin:"
            "/usr/sbin:/usr/bin:/sbin:/bin"
        ),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "PGHOST": os.environ.get(
            "PGHOST",
            "/run/postgresql",
        ),
        "PGPORT": os.environ.get(
            "PGPORT",
            "5432",
        ),
        "PGDATABASE": os.environ.get(
            "PGDATABASE",
            "mimir_memory",
        ),
        "PGUSER": os.environ.get(
            "PGUSER",
            "mimir_app",
        ),
        "PGAPPNAME": os.environ.get(
            "PGAPPNAME",
            "mimir-memory-handoff-v1",
        ),
        "PGCONNECT_TIMEOUT": "5",
        "PGOPTIONS": (
            "-c statement_timeout=60000 "
            "-c lock_timeout=5000"
        ),
    }


def run_psql(
    sql: str,
    variables: dict[str, str],
) -> str:
    args = [
        PSQL,
        "-X",
        "-w",
        "-q",
        "-A",
        "-t",
        "-v",
        "ON_ERROR_STOP=1",
    ]

    for key, value in variables.items():
        args.extend(["-v", f"{key}={value}"])

    process = subprocess.run(
        args,
        input=sql,
        text=True,
        capture_output=True,
        env=create_psql_env(),
        check=False,
    )

    if process.returncode != 0:
        detail = (
            process.stderr.strip()
            or process.stdout.strip()
            or f"rc={process.returncode}"
        )
        fail(f"PostgreSQL rejeitou handoff: {detail}")

    return process.stdout.strip()


def submit_handoff(
    validated: dict[str, Any],
) -> dict[str, Any]:
    if pwd.getpwuid(os.geteuid()).pw_name != "openclaw":
        fail(
            "--submit deve executar como usuário Linux openclaw"
        )

    intervention_id = validated["intervention_id"]
    memory_key = f"ops.intervention.{intervention_id}"

    title = f"Intervenção operacional {intervention_id}"

    summary = (
        "Evidência operacional revisável do dispositivo "
        f"{validated['device_id']}; "
        f"status {validated['status']}; "
        f"concluída em {validated['completed_at']}."
    )

    encoded_handoff = base64.b64encode(
        validated["handoff_text"].encode("utf-8")
    ).decode("ascii")

    sql = """
BEGIN;

SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE handoff_submission_result (
    event_id uuid NOT NULL,
    memory_id uuid NOT NULL,
    candidate_state text NOT NULL,
    conflict_classification text NOT NULL
) ON COMMIT DROP;

DO $handoff$
DECLARE
    v_event_id        uuid;
    v_memory_id       uuid;
    v_status          text;
    v_conflict        text;
BEGIN
    v_event_id :=
        mimir.ingest_operational_handoff_v1(
            :'event_id'::uuid,
            convert_from(
                decode(:'handoff_b64', 'base64'),
                'UTF8'
            ),
            :'handoff_sha256'
        );

    v_memory_id :=
        mimir.propose_memory(
            v_event_id,
            :'memory_key',
            'evidence',
            :'title',
            :'summary',
            convert_from(
                decode(:'handoff_b64', 'base64'),
                'UTF8'
            ),
            0.600,
            0.600,
            false,
            jsonb_build_object(
                'submission_type',
                    'ops-memory-handoff-v1',
                'report_sha256',
                    :'report_sha256',
                'handoff_sha256',
                    :'handoff_sha256',
                'source_ref',
                    :'source_ref',
                'deduplication_key',
                    :'deduplication_key',
                'classification',
                    'confidential',
                'requires_human_review',
                    true,
                'automatic_promotion',
                    false
            ),
            'mimir-memory-handoff-v1'
        );

    SELECT status
    INTO v_status
    FROM mimir.memory_records
    WHERE memory_id = v_memory_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'candidate recém-criada não foi encontrada: %',
            v_memory_id;
    END IF;

    IF v_status <> 'candidate' THEN
        RAISE EXCEPTION
            'status inesperado após propose_memory: %',
            v_status;
    END IF;

    SELECT classification
    INTO v_conflict
    FROM mimir.inspect_candidate_conflict(
        v_memory_id
    );

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'classificação de conflito ausente';
    END IF;

    INSERT INTO handoff_submission_result (
        event_id,
        memory_id,
        candidate_state,
        conflict_classification
    )
    VALUES (
        v_event_id,
        v_memory_id,
        v_status,
        v_conflict
    );
END
$handoff$;

SELECT jsonb_build_object(
    'event_id',
        event_id,
    'memory_id',
        memory_id,
    'state',
        candidate_state,
    'conflict_classification',
        conflict_classification,
    'automatic_promotion',
        false
)::text
FROM handoff_submission_result;

COMMIT;
"""

    output = run_psql(
        sql,
        {
            "event_id": intervention_id,
            "handoff_b64": encoded_handoff,
            "handoff_sha256":
                validated["handoff_sha256"],
            "report_sha256":
                validated["report_sha256"],
            "memory_key": memory_key,
            "title": title,
            "summary": summary,
            "source_ref":
                validated["source_ref"],
            "deduplication_key":
                validated["deduplication_key"],
        },
    )

    try:
        result = json.loads(output)
    except json.JSONDecodeError as exc:
        fail(
            f"resultado PostgreSQL inválido: {exc}"
        )

    if not isinstance(result, dict):
        fail("resultado PostgreSQL não é objeto")

    if result.get("automatic_promotion") is not False:
        fail("PostgreSQL reportou promoção automática")

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Valida e, opcionalmente, envia memory_handoff "
            "operacional v1 como candidate de memória."
        )
    )

    parser.add_argument(
        "--file",
        required=True,
        type=Path,
        help="Relatório operacional JSON.",
    )

    parser.add_argument(
        "--sha256",
        required=True,
        help="SHA-256 autorizado do relatório.",
    )

    parser.add_argument(
        "--submit",
        action="store_true",
        help=(
            "Ingere source + candidate. "
            "Nunca promove para active."
        ),
    )

    args = parser.parse_args()

    expected_hash = args.sha256.strip().lower()

    if (
        len(expected_hash) != 64
        or any(
            c not in "0123456789abcdef"
            for c in expected_hash
        )
    ):
        fail("SHA-256 informado inválido")

    validated = load_and_validate(
        args.file,
        expected_hash,
    )

    print("memory_handoff_v1_validation=PASS")
    print(
        "intervention_id="
        + validated["intervention_id"]
    )
    print(
        "device_id="
        + validated["device_id"]
    )
    print(
        "handoff_sha256="
        + validated["handoff_sha256"]
    )
    print(
        "automatic_promotion=false"
    )

    if not args.submit:
        print("database_write=false")
        return

    result = submit_handoff(validated)

    print("database_write=true")
    print(
        "event_id="
        + str(result.get("event_id"))
    )
    print(
        "memory_id="
        + str(result.get("memory_id"))
    )
    print(
        "candidate_state="
        + str(result.get("state"))
    )
    print(
        "conflict_classification="
        + str(
            result.get(
                "conflict_classification"
            )
        )
    )
    print("human_review_required=true")
    print("automatic_promotion=false")


if __name__ == "__main__":
    main()
