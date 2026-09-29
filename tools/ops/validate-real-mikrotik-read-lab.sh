#!/bin/bash
set -euo pipefail
umask 077

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.."
    pwd
)"

PYTHON="${PYTHON:-/usr/bin/python3}"

: "${MIMIR_LAB_HOST:?MIMIR_LAB_HOST obrigatório}"
: "${MIMIR_LAB_PORT:?MIMIR_LAB_PORT obrigatório}"
: "${MIMIR_LAB_USER:?MIMIR_LAB_USER obrigatório}"
: "${MIMIR_LAB_KEY:?MIMIR_LAB_KEY obrigatório}"
: "${MIMIR_LAB_KNOWN_HOSTS:?MIMIR_LAB_KNOWN_HOSTS obrigatório}"
: "${MIMIR_LAB_EXPECTED_USERKEY_FP:?fingerprint da user key obrigatório}"
: "${MIMIR_LAB_EXPECTED_HOSTKEY_FP:?fingerprint da host key obrigatório}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ $EUID -ne 0 ]] || {
    fail "execute como operador não-root"
}

[[ "$MIMIR_LAB_PORT" =~ ^[0-9]+$ ]] || {
    fail "porta inválida"
}

(( MIMIR_LAB_PORT >= 1 && MIMIR_LAB_PORT <= 65535 )) || {
    fail "porta fora do intervalo"
}

[[ -f "$MIMIR_LAB_KEY" ]] || {
    fail "chave privada ausente"
}

[[ -f "${MIMIR_LAB_KEY}.pub" ]] || {
    fail "chave pública ausente"
}

[[ -f "$MIMIR_LAB_KNOWN_HOSTS" ]] || {
    fail "known_hosts ausente"
}

echo "=== MIMIR REAL MIKROTIK READ LAB ==="

echo
echo "--- 1. LOCAL CREDENTIAL GUARDS ---"

USER_FP="$(
    ssh-keygen \
        -lf "${MIMIR_LAB_KEY}.pub" \
        -E sha256 |
    awk '{print $2}' |
    sed 's/=*$//'
)"

EXPECTED_USER_FP="$(
    printf '%s\n' "$MIMIR_LAB_EXPECTED_USERKEY_FP" |
    sed 's/=*$//'
)"

[[ "$USER_FP" == "$EXPECTED_USER_FP" ]] || {
    fail "fingerprint da chave de usuário divergiu"
}

echo "user_key_fingerprint=PASS"

mapfile -t HOST_FPS < <(
    ssh-keygen \
        -lf "$MIMIR_LAB_KNOWN_HOSTS" \
        -E sha256 |
    awk '{print $2}' |
    sed 's/=*$//' |
    sort -u
)

EXPECTED_HOST_FP="$(
    printf '%s\n' "$MIMIR_LAB_EXPECTED_HOSTKEY_FP" |
    sed 's/=*$//'
)"

[[ "${#HOST_FPS[@]}" -eq 1 ]] || {
    printf 'host_fingerprints=%s\n' "${HOST_FPS[*]}"
    fail "known_hosts deve conter exatamente uma host key neste LAB"
}

[[ "${HOST_FPS[0]}" == "$EXPECTED_HOST_FP" ]] || {
    fail "host key pinada divergiu do fingerprint esperado"
}

echo "host_key_fingerprint=PASS"
echo "host_key_provenance=TOFU_PINNED_NOT_INDEPENDENTLY_VERIFIED"

echo
echo "--- 2. ISOLATED SSH AGENT ---"

eval "$(ssh-agent -s)" >/dev/null

cleanup() {
    ssh-agent -k >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

ssh-add -D >/dev/null 2>&1 || true

echo "Digite somente a passphrase da chave SSH local se solicitada:"
ssh-add "$MIMIR_LAB_KEY"

IDENTITIES="$(
    ssh-add -l |
    grep -c . || true
)"

[[ "$IDENTITIES" == "1" ]] || {
    ssh-add -l || true
    fail "agente deve conter exatamente uma identidade"
}

echo "isolated_agent_identity_count=1"

echo
echo "--- 3. REAL SSHExecutor / ADAPTER READ ---"

ROOT_DIR_ENV="$ROOT_DIR" \
"$PYTHON" - <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
sys.path.insert(0, str(root / "tools" / "ops"))

from mimir_ops import (
    Device,
    MikroTikAdapter,
    PolicyError,
    SSHExecutor,
)

host = os.environ["MIMIR_LAB_HOST"]
port = int(os.environ["MIMIR_LAB_PORT"])
user = os.environ["MIMIR_LAB_USER"]
known_hosts = os.environ["MIMIR_LAB_KNOWN_HOSTS"]

device = Device(
    device_id="98888888-8888-4888-8888-888888888901",
    site_id="98888888-8888-4888-8888-888888888902",
    name="real-mikrotik-read-lab",
    device_type="router",
    management_host=host,
    ssh_user=user,
    adapter="mikrotik-routeros",
    management_port=port,
    permission_mode="READ",
    credential_ref="ssh-agent",
    vendor="MikroTik",
    role="diagnostic-lab",
)

adapter = MikroTikAdapter()

expected_operations = (
    "system",
    "board",
    "interfaces",
    "addresses",
    "routes",
    "vlans",
)

assert adapter.read_operations == expected_operations
assert adapter.execute_operations == ()
assert adapter.backup_operation is None

for forbidden in (
    "export",
    "backup-save",
    "set",
    "add",
    "remove",
    "scripts",
):
    assert forbidden in adapter.forbidden_operations

print("adapter_contract=PASS")
print("permission_mode=READ")
print("execute_operations=0")
print("backup_operation=UNSUPPORTED")

executor = SSHExecutor(
    timeout=30,
    known_hosts=known_hosts,
)

evidence = []
pq_warning = False

for operation in adapter.read_operations:
    result = executor.run(
        device,
        operation,
        mode="READ",
    )

    if not result.ok:
        raise RuntimeError(
            f"{operation}: exit={result.exit_code} "
            f"error={result.error!r} "
            f"stderr={result.stderr[:300]!r}"
        )

    if result.classification != "read":
        raise RuntimeError(
            f"{operation}: classificação inesperada "
            f"{result.classification!r}"
        )

    if not result.stdout.strip():
        raise RuntimeError(
            f"{operation}: stdout vazio"
        )

    if "not using a post-quantum" in result.stderr.lower():
        pq_warning = True

    raw = result.stdout.encode("utf-8")

    evidence.append(
        {
            "operation": operation,
            "exit_code": result.exit_code,
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
        }
    )

    print(
        "read_operation="
        f"{operation}|PASS|bytes={len(raw)}|"
        f"sha256={evidence[-1]['sha256']}"
    )

print(f"read_operations_passed={len(evidence)}/6")

# Negative policy checks. These must fail locally before any SSH command.
for remote_command in (
    "/system reboot",
    "/export",
    "/system backup save",
):
    try:
        executor.command(
            device,
            remote_command,
            mode="READ",
        )
    except PolicyError:
        pass
    else:
        raise AssertionError(
            f"comando proibido aceito: {remote_command}"
        )

try:
    executor.run(
        device,
        "set-hostname",
        mode="EXECUTE",
        parameters={"hostname": "must-not-run"},
        approved=True,
    )
except PolicyError:
    pass
else:
    raise AssertionError(
        "EXECUTE inesperadamente aceito no MikroTik"
    )

print("forbidden_remote_commands=BLOCKED")
print("execute_attempt=BLOCKED")
print("configuration_changes=0")
print(
    "post_quantum_kex_warning="
    + ("OBSERVED" if pq_warning else "NOT_OBSERVED")
)

# Output hashes only. Device output itself is deliberately not persisted.
print(
    "evidence_digest="
    + hashlib.sha256(
        json.dumps(
            evidence,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
)

print("real_mikrotik_ssh_executor_read=PASS")
PY

echo
echo "--- 4. FINAL POLICY ASSERTIONS ---"

echo "database_write=false"
echo "inventory_write=false"
echo "execute_mode=false"
echo "configuration_change=false"
echo "backup_export=false"
echo "raw_device_output_persisted=false"

echo
echo "MIMIR-REAL-MIKROTIK-READ-LAB: PASS"
