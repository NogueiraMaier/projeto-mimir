#!/usr/bin/env bash

set -euo pipefail

REPO="$(
    git rev-parse --show-toplevel
)"

cd "$REPO"

BUILDER=tools/memory/mimir_protected_output_gbnf_v1.py
TEST=tools/memory/test_mimir_protected_output_gbnf_v1.py
CONSOLIDATOR=tools/memory/mimir-consolidate-protected-v1.py

echo "=== PROTECTED OUTPUT GBNF V1 / REPOSITORY VALIDATOR ==="

for FILE in \
    "$BUILDER" \
    "$TEST" \
    "$CONSOLIDATOR"
do
    test -f "$FILE"
done

echo "files_present=PASS"

echo
echo "=== PYTHON SYNTAX ==="

env \
    BUILDER="$BUILDER" \
    TEST="$TEST" \
    python3 - <<'PY'
from pathlib import Path
import os

for name in ("BUILDER", "TEST"):
    path = Path(os.environ[name])

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
echo "=== BUILDER IMPORT POLICY ==="

env BUILDER="$BUILDER" python3 - <<'PY'
from pathlib import Path
import ast
import os

path = Path(os.environ["BUILDER"])

tree = ast.parse(
    path.read_text(encoding="utf-8"),
    filename=str(path),
)

allowed = {
    "__future__",
    "argparse",
    "json",
    "re",
    "sys",
    "uuid",
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
        + ",".join(sorted(unexpected))
    )

print(
    "BUILDER_IMPORT_POLICY=PASS"
)
PY

echo
echo "=== STATIC CONTRACT BOUNDARIES ==="

grep -F \
    'LLAMA_GBNF_RUNTIME_VALIDATION: Final = "PENDING"' \
    "$BUILDER" >/dev/null

grep -F \
    '"source_event_id":' \
    "$BUILDER" >/dev/null

grep -F \
    '"source_content_sha256":' \
    "$BUILDER" >/dev/null

grep -F \
    '"kind":"source_excerpt"' \
    "$BUILDER" >/dev/null

env BUILDER="$BUILDER" python3 - <<'PYCONTRACT'
import importlib.util
import os
from pathlib import Path

path = Path(os.environ["BUILDER"])

spec = importlib.util.spec_from_file_location(
    "mimir_protected_output_gbnf_v1_validation",
    path,
)

if spec is None or spec.loader is None:
    raise SystemExit(
        "FAIL:unable to import GBNF builder"
    )

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

grammar = module.build_protected_output_grammar(
    event_id="11111111-1111-4111-8111-111111111111",
    content_sha256="a" * 64,
    max_candidates=3,
)

required = (
    "source_event_id",
    "source_content_sha256",
    "source_excerpt",
    "UNTRUSTED_OBSERVATION",
    "requires_human_review",
)

for marker in required:
    if marker not in grammar:
        raise SystemExit(
            f"FAIL:generated grammar missing {marker}"
        )

for forbidden in (
    "source_session_id",
    "source_excerpt_hash",
):
    if forbidden in grammar:
        raise SystemExit(
            f"FAIL:generated grammar contains {forbidden}"
        )

print(
    "GENERATED_GRAMMAR_CONTRACT_BOUNDARY=PASS"
)
PYCONTRACT

echo "static_contract_boundaries=PASS"

echo
echo "=== ISOLATED REPOSITORY TESTS ==="

unshare \
    --user \
    --map-root-user \
    --net \
    env \
        PYTHONDONTWRITEBYTECODE=1 \
        python3 "$TEST"

echo
echo "=== WHITESPACE / EOF POLICY ==="

env \
    BUILDER="$BUILDER" \
    TEST="$TEST" \
    VALIDATOR="$0" \
    python3 - <<'PY'
from pathlib import Path
import os

for name in (
    "BUILDER",
    "TEST",
    "VALIDATOR",
):
    path = Path(os.environ[name])
    data = path.read_bytes()

    if not data.endswith(b"\n"):
        raise SystemExit(
            f"FAIL:{name}:missing final LF"
        )

    if len(data) - len(data.rstrip(b"\n")) != 1:
        raise SystemExit(
            f"FAIL:{name}:unexpected trailing LF count"
        )

    for number, line in enumerate(
        data.splitlines(),
        start=1,
    ):
        if line.rstrip(b" \t") != line:
            raise SystemExit(
                f"FAIL:{name}:trailing whitespace:"
                f"{number}"
            )

print("TEXT_POLICY=PASS")
PY

echo
echo "REPOSITORY_CONTRACT_VALIDATION=PASS"
echo "LLAMA_GBNF_RUNTIME_VALIDATION=PENDING"
echo "QWEN=NOT_ACCESSED"
echo "POSTGRESQL=NOT_ACCESSED"
echo "PROTECTED_OUTPUT_GBNF_V1_REPOSITORY=PASS"
