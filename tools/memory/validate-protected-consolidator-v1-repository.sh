#!/bin/bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

"$PYTHON_BIN" -m py_compile \
    "$ROOT/mimir-consolidate-protected-v1.py" \
    "$ROOT/test_mimir_consolidate_protected_v1.py"

"$PYTHON_BIN" "$ROOT/test_mimir_consolidate_protected_v1.py"

echo "MIMIR-PROTECTED-CONSOLIDATOR-V1-REPOSITORY: PASS"
