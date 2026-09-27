#!/bin/bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "=== protected consolidator: syntax ==="

"$PYTHON_BIN" -m py_compile \
    "$ROOT/mimir-consolidate-protected-v1.py" \
    "$ROOT/test_mimir_consolidate_protected_v1.py"

echo "=== protected consolidator: isolated network namespace ==="

unshare --user --map-root-user --net sh -c '
set -eu

ip link set lo up

if ss -ltnH | grep -q ":18782"; then
    echo "ERRO: porta 18782 inesperadamente ocupada dentro do namespace" >&2
    exit 90
fi

echo "TEST-NETNS: loopback ativo"
echo "TEST-NETNS: 127.0.0.1:18782 livre"

exec "$1" "$2"
' sh \
    "$PYTHON_BIN" \
    "$ROOT/test_mimir_consolidate_protected_v1.py"

echo "MIMIR-PROTECTED-CONSOLIDATOR-V1-REPOSITORY: PASS"
