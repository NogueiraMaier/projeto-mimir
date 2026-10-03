#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &&
    pwd
)"

cd "$ROOT"

FIXTURE=tools/security/fixtures/rsk-p0-005-ttx-001.json
HARNESS=tools/security/validate-rsk-p0-005-incident-exercise.py
SELF=tools/security/validate-rsk-p0-005-incident-exercise-repository.sh

echo "=== RSK-P0-005 repository validation ==="
echo "TABLETOP_EXECUTION=NO"
echo "NETWORK_ACCESS=NO"
echo "QWEN_ACCESS=NO"
echo "POSTGRESQL_ACCESS=NO"
echo "PRODUCTION_ACCESS=NO"

test -f "$FIXTURE"
test -f "$HARNESS"
test -f "$SELF"

python3 - "$HARNESS" <<'PY'
from pathlib import Path
import ast
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")

compile(
    source,
    str(path),
    "exec",
)

tree = ast.parse(
    source,
    filename=str(path),
)

forbidden_import_roots = {
    "subprocess",
    "socket",
    "urllib",
    "http",
    "requests",
    "psycopg",
    "psycopg2",
    "paramiko",
}

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            root = alias.name.split(".", 1)[0]
            if root in forbidden_import_roots:
                raise SystemExit(
                    f"FAIL:FORBIDDEN_IMPORT:{alias.name}"
                )

    if isinstance(node, ast.ImportFrom):
        if node.module:
            root = node.module.split(".", 1)[0]
            if root in forbidden_import_roots:
                raise SystemExit(
                    f"FAIL:FORBIDDEN_IMPORT:{node.module}"
                )

print("PYTHON_SYNTAX=PASS")
print("FORBIDDEN_EXTERNAL_IMPORTS=ABSENT")
PY

python3 - "$FIXTURE" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])

data = json.loads(
    path.read_text(encoding="utf-8")
)

if data.get("exercise_id") != "MIMIR-IR-TTX-001":
    raise SystemExit(
        "FAIL:FIXTURE_EXERCISE_ID"
    )

if (
    data.get("payload", {})
    .get("synthetic_credential_marker")
    != "NOT_A_REAL_SECRET_TTX_001"
):
    raise SystemExit(
        "FAIL:SYNTHETIC_CREDENTIAL_MARKER"
    )

print("FIXTURE_JSON=PASS")
print("FIXTURE_SYNTHETIC_MARKER=PASS")
PY

bash -n "$SELF"

python3 "$HARNESS" \
    --fixture "$FIXTURE" \
    --validate-fixture-only

echo "TABLETOP_EXECUTION_CONFIRMED=NO"
echo "RSK_P0_005_EXERCISE_REPOSITORY_VALIDATION=PASS"
