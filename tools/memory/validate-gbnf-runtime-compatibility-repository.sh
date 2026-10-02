#!/bin/bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
HARNESS="$ROOT/mimir-gbnf-runtime-compatibility.py"
TEST="$ROOT/test_mimir_gbnf_runtime_compatibility.py"
PYCACHE="/var/tmp/mimir-gbnf-pycache.$$"

cleanup() {
    rm -rf -- "$PYCACHE"
}
trap cleanup EXIT INT TERM

test -f "$HARNESS"
test -f "$TEST"

echo "=== GBNF harness: syntax ==="

PYTHONPYCACHEPREFIX="$PYCACHE" \
"$PYTHON_BIN" -m py_compile \
    "$HARNESS" \
    "$TEST"

echo "syntax=PASS"

echo "=== GBNF harness: static repository policy ==="

PYTHONDONTWRITEBYTECODE=1 \
"$PYTHON_BIN" - "$HARNESS" <<'PY'
from pathlib import Path
import ast
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
tree = ast.parse(text)

imports = set()

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            imports.add(alias.name.split(".", 1)[0])
    elif isinstance(node, ast.ImportFrom) and node.module:
        imports.add(node.module.split(".", 1)[0])

for forbidden in (
    "psycopg",
    "psycopg2",
    "subprocess",
):
    if forbidden in imports:
        raise SystemExit(
            f"FAIL: forbidden import: {forbidden}"
        )

required = (
    'MODEL_ENDPOINT = "http://127.0.0.1:18782/v1/chat/completions"',
    'MODEL_ID = "/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf"',
    '"grammar": case.grammar',
    '"chat_template_kwargs": {"enable_thinking": False}',
    'HTTP_REJECT = "HTTP_REJECT"',
    'TIMEOUT = "TIMEOUT"',
    'TRANSPORT_ERROR = "TRANSPORT_ERROR"',
    'STRUCTURE_REJECT = "STRUCTURE_REJECT"',
)

for marker in required:
    if marker not in text:
        raise SystemExit(
            f"FAIL: missing required marker: {marker}"
        )

print("static_repository_policy=PASS")
PY

echo "=== GBNF harness: isolated repository tests ==="

unshare --user --map-root-user --net sh -c '
set -eu

ip link set lo up

if ss -ltnH | grep -F ":18782" >/dev/null; then
    echo "FAIL: 127.0.0.1:18782 unexpectedly occupied in test namespace" >&2
    exit 90
fi

echo "TEST-NETNS: loopback active"
echo "TEST-NETNS: 127.0.0.1:18782 free"

PYTHONDONTWRITEBYTECODE=1 \
exec "$1" "$2"
' sh \
    "$PYTHON_BIN" \
    "$TEST"

echo "isolated_repository_tests=PASS"
echo "MIMIR-GBNF-RUNTIME-COMPATIBILITY-REPOSITORY: PASS"
