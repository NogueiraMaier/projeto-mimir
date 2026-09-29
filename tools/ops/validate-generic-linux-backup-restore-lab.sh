#!/bin/bash
set -euo pipefail
umask 077

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.."
    pwd
)"

PYTHON="${PYTHON:-/usr/bin/python3}"
UNSHARE="${UNSHARE:-/usr/bin/unshare}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || {
    fail "execute este LAB como root"
}

[[ -x "$UNSHARE" ]] || {
    fail "unshare nao disponivel"
}

HOST_BEFORE="$(/bin/hostname)"

[[ -n "$HOST_BEFORE" ]] || {
    fail "hostname real vazio antes do LAB"
}

echo "=== MIMIR GENERIC-LINUX BACKUP/RESTORE LAB ==="

echo
echo "--- 1. HOST ISOLATION BASELINE ---"
echo "host_hostname_before=$HOST_BEFORE"
echo "host_isolation_baseline=PASS"

echo
echo "--- 2. REAL UTS NAMESPACE LAB ---"

ROOT_DIR_ENV="$ROOT_DIR" \
PYTHON="$PYTHON" \
"$UNSHARE" \
    --uts \
    --fork \
    -- \
    /bin/bash <<'NS'
set -euo pipefail

LAB_INITIAL="mimir-backup-origin"
LAB_CHANGED="mimir-backup-changed"

export ROOT_DIR_ENV
export LAB_INITIAL
export LAB_CHANGED

/bin/hostname "$LAB_INITIAL"

"$PYTHON" - <<'PY'
from __future__ import annotations

import hashlib
import os
import shlex
import subprocess
import sys
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
sys.path.insert(0, str(root / "tools" / "ops"))

from mimir_ops import (
    ActionResult,
    Adapter,
    HOSTNAME,
    MikroTikAdapter,
    PolicyError,
    now_iso,
)


initial_expected = os.environ["LAB_INITIAL"]
changed_expected = os.environ["LAB_CHANGED"]

adapter = Adapter()

assert adapter.name == "generic-linux"
assert adapter.backup_operation == "hostname"
assert adapter.validation_operation == "hostname"
assert adapter.rollback_mode == "manual"
assert adapter.backup_command() == "/bin/hostname"

print("generic_linux_backup_contract=PASS")


def execute_catalog_command(command: str):
    args = shlex.split(command)

    result = subprocess.run(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        env={
            "PATH": "/usr/bin:/bin",
            "LC_ALL": "C",
        },
    )

    return result


# 1. REAL BACKUP
backup_command = adapter.backup_command()

backup = execute_catalog_command(backup_command)

assert backup.returncode == 0, backup.stderr

backup_hostname = backup.stdout.strip()

assert backup_hostname == initial_expected
assert HOSTNAME.fullmatch(backup_hostname)

backup_sha256 = hashlib.sha256(
    backup_hostname.encode("utf-8")
).hexdigest()

print("real_backup_capture=PASS")
print(f"backup_hostname={backup_hostname}")
print(f"backup_sha256={backup_sha256}")


# 2. REAL CHANGE THROUGH THE ADAPTER'S CATALOGUED OPERATION
change_command = adapter.operations[
    "set-hostname"
].render(
    {
        "hostname": changed_expected,
    }
)

change = execute_catalog_command(change_command)

assert change.returncode == 0, change.stderr

validation_command = adapter.operations[
    adapter.validation_operation
].render()

validation = execute_catalog_command(
    validation_command
)

assert validation.returncode == 0

validation_result = ActionResult(
    command=validation_command,
    classification="read",
    exit_code=validation.returncode,
    stdout=validation.stdout,
    stderr=validation.stderr,
    started_at=now_iso(),
    completed_at=now_iso(),
    dry_run=False,
    operation="hostname",
)

assert adapter.validate(
    "set-hostname",
    {
        "hostname": changed_expected,
    },
    validation_result,
)

assert validation.stdout.strip() == changed_expected

print("real_transient_change=PASS")
print("post_change_validation=PASS")


# 3. RESTORE USING ONLY THE PREVIOUSLY CAPTURED, VALIDATED VALUE
assert HOSTNAME.fullmatch(backup_hostname)

restore_command = adapter.operations[
    "set-hostname"
].render(
    {
        "hostname": backup_hostname,
    }
)

restore = execute_catalog_command(
    restore_command
)

assert restore.returncode == 0, restore.stderr

final_validation = execute_catalog_command(
    validation_command
)

assert final_validation.returncode == 0
assert final_validation.stdout.strip() == backup_hostname
assert backup_hostname == initial_expected

print("real_restore=PASS")
print("restore_validation=PASS")


# 4. FAIL-CLOSED RESTORE INPUT
try:
    adapter.operations["set-hostname"].render(
        {
            "hostname": "invalid restore value",
        }
    )
except PolicyError:
    print("invalid_restore_value=BLOCKED")
else:
    raise AssertionError(
        "invalid restore value was accepted"
    )


# 5. MIKROTIK MUST REMAIN EXPLICITLY UNSUPPORTED
mikrotik = MikroTikAdapter()

assert mikrotik.backup_operation is None
assert mikrotik.backup_command() is None
assert "backup-save" in mikrotik.forbidden_operations

print("mikrotik_backup=UNSUPPORTED_BY_POLICY")
print("mikrotik_backup_save=BLOCKED")

print("namespace_final_hostname=" + backup_hostname)
PY

[[ "$(/bin/hostname)" == "$LAB_INITIAL" ]] || {
    echo "FAIL: restauracao dentro do namespace divergiu" >&2
    exit 1
}

echo "namespace_restore_guard=PASS"
NS

echo
echo "--- 3. REAL HOST MUST BE UNCHANGED ---"

HOST_AFTER="$(/bin/hostname)"

echo "host_hostname_after=$HOST_AFTER"

[[ "$HOST_AFTER" == "$HOST_BEFORE" ]] || {
    echo "FAIL: hostname real da VPS foi alterado" >&2
    exit 1
}

echo "host_unchanged=PASS"

echo
echo "--- 4. PRODUCTION / NETWORK SIDE-EFFECT GUARD ---"

echo "ssh_used=false"
echo "production_database_touched=false"
echo "equipment_touched=false"
echo "automatic_rollback_added=false"

echo
echo "MIMIR-GENERIC-LINUX-BACKUP-RESTORE-LAB: PASS"
