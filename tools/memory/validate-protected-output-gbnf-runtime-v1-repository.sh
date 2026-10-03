#!/usr/bin/env bash

set -euo pipefail

REPO="$(
    git rev-parse --show-toplevel
)"

cd "$REPO"

HARNESS=tools/memory/mimir_protected_output_gbnf_runtime_v1.py
TEST=tools/memory/test_mimir_protected_output_gbnf_runtime_v1.py

BUILDER=tools/memory/mimir_protected_output_gbnf_v1.py
COMPAT=tools/memory/mimir-gbnf-runtime-compatibility.py
CONSOLIDATOR=tools/memory/mimir-consolidate-protected-v1.py

BUILDER_SHA=d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f
COMPAT_SHA=edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc
CONSOLIDATOR_SHA=af8cb69c5f2b2df62ebcef1022eb3a329442252d2bbf152285c1106ffd92dd66

echo "=== PROTECTED OUTPUT GBNF RUNTIME V1 / REPOSITORY VALIDATOR ==="

for FILE in \
    "$HARNESS" \
    "$TEST" \
    "$BUILDER" \
    "$COMPAT" \
    "$CONSOLIDATOR"
do
    test -f "$FILE"
done

echo "files_present=PASS"

echo
echo "=== DEPENDENCY IDENTITY ==="

test "$(
    sha256sum "$BUILDER" |
    awk '{print $1}'
)" = "$BUILDER_SHA"

test "$(
    sha256sum "$COMPAT" |
    awk '{print $1}'
)" = "$COMPAT_SHA"

test "$(
    sha256sum "$CONSOLIDATOR" |
    awk '{print $1}'
)" = "$CONSOLIDATOR_SHA"

echo "dependency_identity=PASS"

echo
echo "=== PYTHON SYNTAX ==="

env \
    HARNESS="$HARNESS" \
    TEST="$TEST" \
    python3 - <<'PY'
from pathlib import Path
import os

for name in (
    "HARNESS",
    "TEST",
):
    path = Path(
        os.environ[name]
    )

    source = path.read_text(
        encoding="utf-8"
    )

    compile(
        source,
        str(path),
        "exec",
    )

    print(
        f"{name}_SYNTAX=PASS"
    )
PY

echo
echo "=== HARNESS IMPORT POLICY ==="

env HARNESS="$HARNESS" python3 - <<'PY'
from pathlib import Path
import ast
import os

path = Path(os.environ["HARNESS"])

tree = ast.parse(
    path.read_text(encoding="utf-8"),
    filename=str(path),
)

allowed = {
    "__future__",
    "argparse",
    "hashlib",
    "importlib",
    "json",
    "sys",
    "pathlib",
    "typing",
}

imports = set()

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            imports.add(
                alias.name.split(".", 1)[0]
            )

    elif isinstance(node, ast.ImportFrom):
        if node.module:
            imports.add(
                node.module.split(".", 1)[0]
            )

unexpected = imports - allowed

if unexpected:
    raise SystemExit(
        "FAIL:unexpected imports:"
        + ",".join(
            sorted(unexpected)
        )
    )

for forbidden in (
    "socket",
    "urllib",
    "requests",
    "httpx",
    "subprocess",
    "psycopg",
    "psycopg2",
):
    if forbidden in imports:
        raise SystemExit(
            f"FAIL:direct network/db import:{forbidden}"
        )

print(
    "HARNESS_IMPORT_POLICY=PASS"
)
PY

echo
echo "=== STATIC SECURITY / RUNTIME BOUNDARY ==="

grep -F \
    'FULL_GBNF_RUNTIME_VALIDATION_DEFAULT = "PENDING"' \
    "$HARNESS" >/dev/null

grep -F \
    'http://127.0.0.1:18782/v1/chat/completions' \
    "$HARNESS" >/dev/null

grep -F \
    '/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf' \
    "$HARNESS" >/dev/null

grep -F \
    'SYNTHETIC_EVENT_ID' \
    "$HARNESS" >/dev/null

grep -F \
    'SYNTHETIC_CONTENT_SHA256' \
    "$HARNESS" >/dev/null

if grep -E \
    'psycopg|postgres|subprocess' \
    "$HARNESS" >/dev/null
then
    echo "FAIL: prohibited runtime dependency found" >&2
    exit 1
fi

echo "static_runtime_boundary=PASS"

echo
echo "=== REPOSITORY TESTS IN NETWORK-ISOLATED NAMESPACE ==="

unshare \
    --user \
    --map-root-user \
    --net \
    env \
        PYTHONDONTWRITEBYTECODE=1 \
        python3 "$TEST"

echo
echo "=== TEXT / EOF POLICY ==="

env \
    HARNESS="$HARNESS" \
    TEST="$TEST" \
    VALIDATOR="$0" \
    python3 - <<'PY'
from pathlib import Path
import os

for name in (
    "HARNESS",
    "TEST",
    "VALIDATOR",
):
    path = Path(
        os.environ[name]
    )

    data = path.read_bytes()

    if not data.endswith(b"\n"):
        raise SystemExit(
            f"FAIL:{name}:missing final LF"
        )

    if (
        len(data)
        - len(data.rstrip(b"\n"))
        != 1
    ):
        raise SystemExit(
            f"FAIL:{name}:trailing LF count"
        )

    for number, line in enumerate(
        data.splitlines(),
        start=1,
    ):
        if line.rstrip(b" \t") != line:
            raise SystemExit(
                f"FAIL:{name}:trailing whitespace:{number}"
            )

print("TEXT_POLICY=PASS")
PY

echo
echo "REPOSITORY_HARNESS_VALIDATION=PASS"
echo "FULL_GBNF_RUNTIME_VALIDATION=PENDING"
echo "MODEL_ENDPOINT_REQUEST=NOT_PERFORMED"
echo "QWEN_INFERENCE=NOT_PERFORMED"
echo "POSTGRESQL=NOT_ACCESSED"
echo "PROTECTED_CONSOLIDATOR=NOT_EXECUTED"
echo "PROTECTED_OUTPUT_GBNF_RUNTIME_V1_REPOSITORY=PASS"
