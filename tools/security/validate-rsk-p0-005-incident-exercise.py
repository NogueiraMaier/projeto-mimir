#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

EXERCISE_ID = "MIMIR-IR-TTX-001"

EXPECTED_CATEGORIES = [
    "UNAUTHORIZED_OPERATION",
    "PROMPT_OR_CONTENT_INJECTION",
    "CREDENTIAL_EXPOSURE",
]

EXPECTED_ROLES = [
    "Incident Coordinator",
    "Technical Responder",
    "Evidence Custodian",
    "System / Service Owner",
    "Privacy / Governance Escalation Owner",
]

EXPECTED_LIFECYCLE = [
    "DETECT",
    "CLASSIFY",
    "CONTAIN",
    "PRESERVE_EVIDENCE",
    "INVESTIGATE",
    "ERADICATE",
    "RECOVER",
    "VALIDATE",
    "POSTMORTEM",
]

EXPECTED_NO_ACCESS_KEYS = {
    "production",
    "postgresql",
    "model_runtime",
    "external_network",
    "ssh",
    "real_equipment",
    "service_restart",
    "firewall_mutation",
}

TIMESTAMP_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
)


class ExerciseError(RuntimeError):
    pass


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ExerciseError(
            f"cannot read JSON fixture: {exc}"
        ) from exc


def require_exact_keys(
    value: dict[str, Any],
    expected: set[str],
    label: str,
) -> None:
    actual = set(value)
    if actual != expected:
        raise ExerciseError(
            f"{label} keys mismatch: "
            f"expected={sorted(expected)} actual={sorted(actual)}"
        )


def validate_fixture(data: Any) -> None:
    if not isinstance(data, dict):
        raise ExerciseError("fixture must be an object")

    require_exact_keys(
        data,
        {
            "schema_version",
            "exercise_id",
            "incident_id",
            "source",
            "affected_component",
            "payload",
            "expected_categories",
            "expected_roles",
            "expected_lifecycle",
            "expected_boundaries",
            "expected_no_access",
            "expected_residue",
        },
        "fixture",
    )

    if data["schema_version"] != 1:
        raise ExerciseError("schema_version must be 1")

    if data["exercise_id"] != EXERCISE_ID:
        raise ExerciseError("unexpected exercise_id")

    incident_id = data["incident_id"]
    if (
        not isinstance(incident_id, str)
        or not incident_id.endswith("-SYNTHETIC")
    ):
        raise ExerciseError(
            "incident_id must be explicitly synthetic"
        )

    source = data["source"]
    if not isinstance(source, dict):
        raise ExerciseError("source must be an object")

    require_exact_keys(
        source,
        {"kind", "trust_class"},
        "source",
    )

    if source != {
        "kind": "external_content",
        "trust_class": "UNTRUSTED_SYNTHETIC",
    }:
        raise ExerciseError(
            "fixture source must remain untrusted synthetic content"
        )

    if data["affected_component"] != "mimir-operational-boundary":
        raise ExerciseError("unexpected affected_component")

    payload = data["payload"]
    if not isinstance(payload, dict):
        raise ExerciseError("payload must be an object")

    require_exact_keys(
        payload,
        {
            "summary",
            "instructions",
            "synthetic_credential_marker",
        },
        "payload",
    )

    instructions = payload["instructions"]
    if (
        not isinstance(instructions, list)
        or len(instructions) < 4
        or not all(
            isinstance(item, str)
            and item.startswith("SYNTHETIC:")
            for item in instructions
        )
    ):
        raise ExerciseError(
            "all fixture instructions must be explicitly synthetic"
        )

    if (
        payload["synthetic_credential_marker"]
        != "NOT_A_REAL_SECRET_TTX_001"
    ):
        raise ExerciseError(
            "synthetic credential marker changed"
        )

    if data["expected_categories"] != EXPECTED_CATEGORIES:
        raise ExerciseError("expected_categories changed")

    if data["expected_roles"] != EXPECTED_ROLES:
        raise ExerciseError("expected_roles changed")

    if data["expected_lifecycle"] != EXPECTED_LIFECYCLE:
        raise ExerciseError("expected_lifecycle changed")

    boundaries = data["expected_boundaries"]
    if not isinstance(boundaries, dict):
        raise ExerciseError(
            "expected_boundaries must be an object"
        )

    require_exact_keys(
        boundaries,
        {
            "human_approval_required",
            "arbitrary_shell_allowed",
            "automatic_memory_promotion_allowed",
            "real_credential_allowed",
        },
        "expected_boundaries",
    )

    if boundaries != {
        "human_approval_required": True,
        "arbitrary_shell_allowed": False,
        "automatic_memory_promotion_allowed": False,
        "real_credential_allowed": False,
    }:
        raise ExerciseError(
            "authorization boundaries are not fail-closed"
        )

    no_access = data["expected_no_access"]
    if not isinstance(no_access, dict):
        raise ExerciseError(
            "expected_no_access must be an object"
        )

    require_exact_keys(
        no_access,
        EXPECTED_NO_ACCESS_KEYS,
        "expected_no_access",
    )

    if not all(value is True for value in no_access.values()):
        raise ExerciseError(
            "all external/runtime access must be forbidden"
        )

    if data["expected_residue"] != "ZERO_UNEXPLAINED":
        raise ExerciseError("unexpected residue contract")

    serialized = canonical_json_bytes(data).decode("utf-8")

    forbidden = (
        "-----BEGIN PRIVATE KEY-----",
        "-----BEGIN OPENSSH PRIVATE KEY-----",
        "AKIA",
        "ghp_",
        "github_pat_",
    )

    for marker in forbidden:
        if marker in serialized:
            raise ExerciseError(
                f"fixture contains forbidden secret-like marker: {marker}"
            )


def build_incident_record(
    fixture: dict[str, Any],
    fixture_sha256: str,
    timestamp: str,
) -> dict[str, Any]:
    if not TIMESTAMP_RE.fullmatch(timestamp):
        raise ExerciseError(
            "timestamp must use YYYY-MM-DDTHH:MM:SSZ"
        )

    return {
        "schema_version": 1,
        "exercise_id": fixture["exercise_id"],
        "incident_id": fixture["incident_id"],
        "timestamp_utc": timestamp,
        "synthetic": True,
        "source": fixture["source"],
        "affected_component": fixture["affected_component"],
        "severity": {
            "level": "SEV-2",
            "rationale": (
                "Synthetic scenario combines attempted privileged-policy "
                "bypass with a credential-exposure indicator; no real "
                "compromise or production impact is asserted."
            ),
        },
        "categories": list(fixture["expected_categories"]),
        "roles": {
            "Incident Coordinator": "synthetic-coordinator",
            "Technical Responder": "synthetic-responder",
            "Evidence Custodian": "synthetic-evidence-custodian",
            "System / Service Owner": "synthetic-service-owner",
            "Privacy / Governance Escalation Owner": (
                "synthetic-governance-owner"
            ),
        },
        "detection": {
            "recorded": True,
            "fact": (
                "Synthetic untrusted content requested privileged "
                "policy bypass."
            ),
        },
        "classification": {
            "recorded": True,
            "source_trust": "UNTRUSTED_SYNTHETIC",
            "production_incident": False,
        },
        "containment": {
            "recorded": True,
            "privileged_execution_denied": True,
            "human_approval_preserved": True,
            "arbitrary_shell_denied": True,
            "automatic_memory_promotion_denied": True,
            "synthetic_credential_indicator_escalated": True,
        },
        "evidence": {
            "recorded": True,
            "fixture_sha256": fixture_sha256,
            "real_secret_present": False,
        },
        "investigation": {
            "observed_fact": (
                "The versioned synthetic fixture contains requests to "
                "bypass authorization boundaries."
            ),
            "hypothesis": (
                "Equivalent real untrusted content could attempt to "
                "influence privileged behavior."
            ),
            "simulated_impact": (
                "Potential unauthorized action or credential exposure "
                "if controls failed."
            ),
            "confirmed_outcome": (
                "Exercise-only evaluation; no real compromise asserted."
            ),
        },
        "eradication": {
            "decision_recorded": True,
            "runtime_mutation_required": False,
            "decision": (
                "No runtime eradication is performed in a synthetic "
                "tabletop; production remediation would require "
                "separate authorization."
            ),
        },
        "recovery": {
            "decision_recorded": True,
            "scope": "exercise_state_only",
            "production_restore_performed": False,
        },
        "validation": {
            "performed": True,
            "authorization_boundary_preserved": True,
            "real_credential_used": False,
            "production_accessed": False,
            "postgresql_accessed": False,
            "model_runtime_accessed": False,
            "external_network_accessed": False,
            "ssh_used": False,
            "real_equipment_accessed": False,
            "service_restarted": False,
            "firewall_mutated": False,
            "unauthorized_shell_executed": False,
        },
        "postmortem": {
            "produced": True,
            "summary": (
                "Synthetic tabletop validated the documented response "
                "decision path without external or production access."
            ),
        },
        "corrective_actions": [
            {
                "action": (
                    "Preserve human approval and fail-closed boundaries."
                ),
                "owner": "synthetic-service-owner",
                "status": "RECORDED",
            }
        ],
        "residue": "ZERO_UNEXPLAINED",
        "lifecycle": list(EXPECTED_LIFECYCLE),
    }


def evaluate_record(record: dict[str, Any]) -> list[str]:
    failures: list[str] = []

    if record.get("exercise_id") != EXERCISE_ID:
        failures.append("exercise_id")

    if record.get("synthetic") is not True:
        failures.append("synthetic")

    if record.get("categories") != EXPECTED_CATEGORIES:
        failures.append("categories")

    if set(record.get("roles", {})) != set(EXPECTED_ROLES):
        failures.append("roles")

    if record.get("lifecycle") != EXPECTED_LIFECYCLE:
        failures.append("lifecycle")

    severity = record.get("severity", {})
    if severity.get("level") not in {
        "SEV-1",
        "SEV-2",
        "SEV-3",
        "SEV-4",
    }:
        failures.append("severity")

    for section in (
        "detection",
        "classification",
        "containment",
        "evidence",
        "investigation",
        "eradication",
        "recovery",
        "validation",
        "postmortem",
    ):
        if not isinstance(record.get(section), dict):
            failures.append(section)

    containment = record.get("containment", {})
    for key in (
        "privileged_execution_denied",
        "human_approval_preserved",
        "arbitrary_shell_denied",
        "automatic_memory_promotion_denied",
        "synthetic_credential_indicator_escalated",
    ):
        if containment.get(key) is not True:
            failures.append(f"containment.{key}")

    validation = record.get("validation", {})

    required_false = (
        "real_credential_used",
        "production_accessed",
        "postgresql_accessed",
        "model_runtime_accessed",
        "external_network_accessed",
        "ssh_used",
        "real_equipment_accessed",
        "service_restarted",
        "firewall_mutated",
        "unauthorized_shell_executed",
    )

    for key in required_false:
        if validation.get(key) is not False:
            failures.append(f"validation.{key}")

    if validation.get("authorization_boundary_preserved") is not True:
        failures.append(
            "validation.authorization_boundary_preserved"
        )

    if record.get("residue") != "ZERO_UNEXPLAINED":
        failures.append("residue")

    if not record.get("corrective_actions"):
        failures.append("corrective_actions")

    if record.get("postmortem", {}).get("produced") is not True:
        failures.append("postmortem.produced")

    return failures


def execute_tabletop(
    fixture_path: Path,
    output_dir: Path,
    timestamp: str,
) -> int:
    fixture = load_json(fixture_path)
    validate_fixture(fixture)

    if output_dir.exists():
        raise ExerciseError(
            f"output directory already exists: {output_dir}"
        )

    fixture_sha256 = sha256_file(fixture_path)

    record = build_incident_record(
        fixture,
        fixture_sha256,
        timestamp,
    )

    failures = evaluate_record(record)

    result = "PASS" if not failures else "FAIL"

    record["exercise_result"] = result
    record["failed_requirements"] = failures

    output_dir.mkdir(
        parents=True,
        exist_ok=False,
        mode=0o700,
    )

    record_path = output_dir / "incident-record.json"

    record_path.write_bytes(
        canonical_json_bytes(record)
    )
    record_path.chmod(0o600)

    record_sha256 = sha256_file(record_path)

    manifest = {
        "schema_version": 1,
        "exercise_id": EXERCISE_ID,
        "fixture": {
            "path": str(fixture_path),
            "sha256": fixture_sha256,
        },
        "incident_record": {
            "path": str(record_path),
            "sha256": record_sha256,
        },
        "exercise_result": result,
        "automatic_retry": False,
        "production_access": False,
        "postgresql_access": False,
        "model_access": False,
        "network_access": False,
        "real_equipment_access": False,
        "residue": record["residue"],
    }

    manifest_path = output_dir / "evidence-manifest.json"

    manifest_path.write_bytes(
        canonical_json_bytes(manifest)
    )
    manifest_path.chmod(0o600)

    manifest_sha256 = sha256_file(manifest_path)

    print(f"EXERCISE_ID={EXERCISE_ID}")
    print(f"FIXTURE_SHA256={fixture_sha256}")
    print(f"INCIDENT_RECORD_SHA256={record_sha256}")
    print(f"EVIDENCE_MANIFEST_SHA256={manifest_sha256}")
    print(f"EXERCISE_RESULT={result}")
    print("AUTOMATIC_RETRY=NO")
    print("PRODUCTION_ACCESS=NO")
    print("POSTGRESQL_ACCESS=NO")
    print("MODEL_ACCESS=NO")
    print("NETWORK_ACCESS=NO")
    print("REAL_EQUIPMENT_ACCESS=NO")
    print(f"RESIDUE={record['residue']}")

    return 0 if result == "PASS" else 40


def validate_fixture_only(fixture_path: Path) -> int:
    fixture = load_json(fixture_path)
    validate_fixture(fixture)

    print(f"EXERCISE_ID={EXERCISE_ID}")
    print(f"FIXTURE_SHA256={sha256_file(fixture_path)}")
    print("FIXTURE_CONTRACT=PASS")
    print("TABLETOP_EXECUTION=NO")
    print("NETWORK_ACCESS=NO")
    print("QWEN_ACCESS=NO")
    print("POSTGRESQL_ACCESS=NO")
    print("PRODUCTION_ACCESS=NO")

    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Mimir RSK-P0-005 isolated synthetic incident-response "
            "tabletop harness"
        )
    )

    parser.add_argument(
        "--fixture",
        required=True,
        type=Path,
    )

    mode = parser.add_mutually_exclusive_group(
        required=True
    )

    mode.add_argument(
        "--validate-fixture-only",
        action="store_true",
        help=(
            "Validate the synthetic fixture without executing "
            "the tabletop."
        ),
    )

    mode.add_argument(
        "--execute-tabletop",
        action="store_true",
        help=(
            "Execute the isolated synthetic tabletop. "
            "Requires separate human authorization."
        ),
    )

    parser.add_argument(
        "--output-dir",
        type=Path,
    )

    parser.add_argument(
        "--timestamp",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        if args.validate_fixture_only:
            if args.output_dir is not None:
                raise ExerciseError(
                    "--output-dir is forbidden in fixture-only mode"
                )

            if args.timestamp is not None:
                raise ExerciseError(
                    "--timestamp is forbidden in fixture-only mode"
                )

            return validate_fixture_only(
                args.fixture
            )

        if not args.execute_tabletop:
            raise ExerciseError("no execution mode selected")

        if args.output_dir is None:
            raise ExerciseError(
                "--output-dir is required for tabletop execution"
            )

        if args.timestamp is None:
            raise ExerciseError(
                "--timestamp is required for tabletop execution"
            )

        return execute_tabletop(
            args.fixture,
            args.output_dir,
            args.timestamp,
        )

    except ExerciseError as exc:
        print(
            f"ERROR={exc}",
            flush=True,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
