#!/bin/bash
set -euo pipefail
umask 077

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.."
    pwd
)"

PYTHON="${PYTHON:-/usr/bin/python3}"
UNSHARE="${UNSHARE:-/usr/bin/unshare}"
SSHD="${SSHD:-/usr/sbin/sshd}"

LAB_INITIAL="mimir-generic-origin"
LAB_CHANGED="mimir-generic-changed"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || {
    fail "execute este LAB como root"
}

[[ -x "$PYTHON" ]] || fail "python ausente"
[[ -x "$UNSHARE" ]] || fail "unshare ausente"
[[ -x "$SSHD" ]] || fail "sshd ausente"

HOST_BEFORE="$(/bin/hostname)"

[[ -n "$HOST_BEFORE" ]] || {
    fail "hostname real vazio"
}

LAB_ROOT="$(
    mktemp -d /run/mimir-generic-linux-ssh-lab.XXXXXX
)"

chmod 0700 "$LAB_ROOT"

HOSTKEY="$LAB_ROOT/ssh_host_ed25519_key"
CLIENTKEY="$LAB_ROOT/client_ed25519"
AUTHORIZED="$LAB_ROOT/authorized_keys"
KNOWN_HOSTS="$LAB_ROOT/known_hosts"
CONFIG="$LAB_ROOT/sshd_config"
LOG="$LAB_ROOT/sshd.log"

SSHD_WRAPPER_PID=""
SSHD_CHILD_PID=""

stop_lab_sshd() {
    local pid=""
    local cmdline=""
    local stopped=0

    if [[ -n "${SSHD_CHILD_PID:-}" ]]; then
        pid="$SSHD_CHILD_PID"

        if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
            echo "FAIL: PID filho inválido: $pid" >&2
            return 1
        fi

        if kill -0 "$pid" 2>/dev/null; then
            [[ -r "/proc/$pid/cmdline" ]] || {
                echo "FAIL: cmdline do sshd LAB indisponível" >&2
                return 1
            }

            cmdline="$(
                tr '\0' ' ' < "/proc/$pid/cmdline"
            )"

            [[ "$cmdline" == *"$CONFIG"* ]] || {
                echo "FAIL: PID filho não pertence ao sshd LAB" >&2
                return 1
            }

            kill -TERM "$pid"

            for _ in $(seq 1 50); do
                if ! kill -0 "$pid" 2>/dev/null; then
                    stopped=1
                    break
                fi
                sleep 0.1
            done

            if [[ "$stopped" != "1" ]] &&
               kill -0 "$pid" 2>/dev/null
            then
                echo "sshd_term_timeout=OBSERVED"
                kill -KILL "$pid"

                for _ in $(seq 1 20); do
                    if ! kill -0 "$pid" 2>/dev/null; then
                        stopped=1
                        break
                    fi
                    sleep 0.1
                done
            fi

            if kill -0 "$pid" 2>/dev/null; then
                echo "FAIL: sshd LAB não encerrou" >&2
                return 1
            fi
        fi
    fi

    if [[ -n "${SSHD_WRAPPER_PID:-}" ]]; then
        pid="$SSHD_WRAPPER_PID"

        if [[ "$pid" =~ ^[0-9]+$ ]] &&
           kill -0 "$pid" 2>/dev/null
        then
            for _ in $(seq 1 20); do
                if ! kill -0 "$pid" 2>/dev/null; then
                    break
                fi
                sleep 0.1
            done

            if kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null || true

                for _ in $(seq 1 20); do
                    if ! kill -0 "$pid" 2>/dev/null; then
                        break
                    fi
                    sleep 0.1
                done
            fi

            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi

        wait "$pid" 2>/dev/null || true
    fi

    SSHD_CHILD_PID=""
    SSHD_WRAPPER_PID=""

    return 0
}

cleanup() {
    set +e

    stop_lab_sshd >/dev/null 2>&1 || true

    if [[ -n "${LAB_ROOT:-}" &&
          "$LAB_ROOT" == /run/mimir-generic-linux-ssh-lab.* ]]
    then
        rm -rf -- "$LAB_ROOT"
    fi
}

trap cleanup EXIT INT TERM

PORT="$(
"$PYTHON" - <<'PY'
import socket

s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

echo "=== MIMIR GENERIC-LINUX TRANSIENT HOSTNAME LAB ==="

echo
echo "--- 1. REAL HOST BASELINE ---"

echo "host_before=$HOST_BEFORE"
echo "host_baseline=PASS"

echo
echo "--- 2. EPHEMERAL SSH MATERIAL ---"

ssh-keygen \
    -q \
    -t ed25519 \
    -N '' \
    -f "$HOSTKEY"

ssh-keygen \
    -q \
    -t ed25519 \
    -N '' \
    -f "$CLIENTKEY"

cp "$CLIENTKEY.pub" "$AUTHORIZED"

chmod 0600 \
    "$HOSTKEY" \
    "$CLIENTKEY" \
    "$AUTHORIZED"

chmod 0644 \
    "$HOSTKEY.pub" \
    "$CLIENTKEY.pub"

printf '[127.0.0.1]:%s %s\n' \
    "$PORT" \
    "$(cat "$HOSTKEY.pub")" \
    > "$KNOWN_HOSTS"

chmod 0600 "$KNOWN_HOSTS"

echo "ephemeral_ssh_material=PASS"

echo
echo "--- 3. SSHD POLICY ---"

cat > "$CONFIG" <<CFG
Port $PORT
ListenAddress 127.0.0.1
Protocol 2

HostKey $HOSTKEY
PidFile $LAB_ROOT/sshd.pid

AuthorizedKeysFile $AUTHORIZED

PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no

PermitRootLogin prohibit-password
AllowUsers root

UsePAM no
StrictModes yes

AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
GatewayPorts no
PermitTunnel no
PermitUserEnvironment no
PermitUserRC no
PermitTTY no

PrintMotd no
PrintLastLog no
LogLevel VERBOSE
CFG

"$SSHD" -t -f "$CONFIG"

echo "sshd_policy=PASS"

echo
echo "--- 4. START ISOLATED UTS SSHD ---"

LAB_INITIAL="$LAB_INITIAL" \
SSHD="$SSHD" \
CONFIG="$CONFIG" \
"$UNSHARE" \
    --uts \
    --fork \
    -- \
    /bin/bash -c '
        set -euo pipefail
        /bin/hostname "$LAB_INITIAL"
        exec "$SSHD" -D -e -f "$CONFIG"
    ' >"$LOG" 2>&1 &

SSHD_WRAPPER_PID=$!

READY=0

for _ in $(seq 1 50); do
    if ! kill -0 "$SSHD_WRAPPER_PID" 2>/dev/null; then
        echo "--- sshd log ---"
        cat "$LOG" || true
        fail "wrapper unshare/sshd LAB encerrou"
    fi

    if timeout 1 \
        bash -c "</dev/tcp/127.0.0.1/$PORT" \
        2>/dev/null
    then
        READY=1
        break
    fi

    sleep 0.1
done

[[ "$READY" == "1" ]] || {
    echo "--- sshd log ---"
    cat "$LOG" || true
    fail "sshd LAB não ficou acessível"
}

[[ -s "$LAB_ROOT/sshd.pid" ]] || {
    echo "--- sshd log ---"
    cat "$LOG" || true
    fail "pidfile do sshd LAB ausente"
}

SSHD_CHILD_PID="$(
    cat "$LAB_ROOT/sshd.pid"
)"

[[ "$SSHD_CHILD_PID" =~ ^[0-9]+$ ]] || {
    fail "PID filho inválido"
}

kill -0 "$SSHD_CHILD_PID" 2>/dev/null || {
    fail "sshd filho não está ativo"
}

SSHD_CMDLINE="$(
    tr '\0' ' ' < "/proc/$SSHD_CHILD_PID/cmdline"
)"

[[ "$SSHD_CMDLINE" == *"$CONFIG"* ]] || {
    fail "pidfile não referencia o sshd LAB esperado"
}

echo "uts_namespace=PASS"
echo "isolated_sshd=PASS"
echo "sshd_child_pid_guard=PASS"

echo
echo "--- 5. REAL SSHExecutor / ADAPTER PATH ---"

ROOT_DIR_ENV="$ROOT_DIR" \
PORT_ENV="$PORT" \
KNOWN_HOSTS_ENV="$KNOWN_HOSTS" \
CLIENTKEY_ENV="$CLIENTKEY" \
LAB_INITIAL_ENV="$LAB_INITIAL" \
LAB_CHANGED_ENV="$LAB_CHANGED" \
"$PYTHON" - <<'PY'
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
sys.path.insert(0, str(root / "tools" / "ops"))

from mimir_ops import (
    Adapter,
    Device,
    HOSTNAME,
    PolicyError,
    SSHExecutor,
    digest,
    make_plan,
)
from ops_workflow import ChangePermit

port = int(os.environ["PORT_ENV"])
known_hosts = os.environ["KNOWN_HOSTS_ENV"]
client_key = os.environ["CLIENTKEY_ENV"]
initial = os.environ["LAB_INITIAL_ENV"]
changed = os.environ["LAB_CHANGED_ENV"]

device = Device(
    device_id="98888888-8888-4888-8888-888888888911",
    site_id="98888888-8888-4888-8888-888888888912",
    name="generic-linux-transient-lab",
    device_type="server",
    management_host="127.0.0.1",
    ssh_user="root",
    adapter="generic-linux",
    management_port=port,
    permission_mode="EXECUTE",
    credential_ref="file-ref:lab",
    vendor="Linux",
    role="isolated-uts-lab",
)

adapter = Adapter()

assert adapter.name == "generic-linux"
assert adapter.execute_operations == ("set-hostname",)
assert adapter.backup_operation == "hostname"
assert adapter.validation_operation == "hostname"
assert adapter.rollback_mode == "manual"

print("adapter_contract=PASS")

executor = SSHExecutor(
    timeout=10,
    known_hosts=known_hosts,
    key_refs={
        "file-ref:lab": client_key,
    },
)

# PRECHECK
precheck = executor.run(
    device,
    "hostname",
    mode="READ",
)

assert precheck.ok
assert precheck.stdout.strip() == initial
assert HOSTNAME.fullmatch(precheck.stdout.strip())

print("precheck=PASS")

# SNAPSHOT
snapshot_hashes = {}

for name in adapter.snapshot_operations:
    result = executor.run(
        device,
        name,
        mode="READ",
    )

    assert result.ok

    snapshot_hashes[name] = hashlib.sha256(
        result.stdout.encode("utf-8")
    ).hexdigest()

print("snapshot=PASS")

# BACKUP
backup = executor.run(
    device,
    adapter.backup_operation,
    mode="READ",
)

assert backup.ok

backup_hostname = backup.stdout.strip()

assert backup_hostname == initial
assert backup_hostname == precheck.stdout.strip()
assert HOSTNAME.fullmatch(backup_hostname)

print("backup_capture=PASS")

# PLAN
parameters = {
    "hostname": changed,
}

plan = make_plan(
    device,
    "set-hostname",
    parameters,
    "transient hostname isolated lab",
)

assert plan["operation"] == "set-hostname"
assert plan["parameters"] == parameters
assert plan["flow"] == [
    "PRECHECK",
    "SNAPSHOT",
    "BACKUP",
    "EXECUTE",
    "VALIDATE",
    "REPORT",
]

print("plan=PASS")
print("change_plan_sha256=" + plan["plan_sha256"])

# EXECUTE must fail without ChangePermit.
try:
    executor.run(
        device,
        "set-hostname",
        mode="EXECUTE",
        parameters=parameters,
        approved=True,
    )
except PolicyError:
    print("execute_without_permit=BLOCKED")
else:
    raise AssertionError(
        "EXECUTE sem ChangePermit foi aceito"
    )

# Invalid hostname must fail before transport.
try:
    adapter.operations["set-hostname"].render(
        {"hostname": "invalid hostname"}
    )
except PolicyError:
    print("invalid_hostname=BLOCKED")
else:
    raise AssertionError(
        "hostname inválido foi aceito"
    )

# CONTROLLED EXECUTE
permit = ChangePermit(
    intervention_id="98888888-8888-4888-8888-888888888913",
    device_id=device.device_id,
    operation="set-hostname",
    parameters_sha256=digest(parameters),
)

changed_result = executor.run(
    device,
    "set-hostname",
    mode="EXECUTE",
    parameters=parameters,
    approved=True,
    permit=permit,
)

assert changed_result.ok

print("controlled_execute=PASS")

# VALIDATE
validation = executor.run(
    device,
    adapter.validation_operation,
    mode="READ",
)

assert validation.ok
assert validation.stdout.strip() == changed

assert adapter.validate(
    "set-hostname",
    parameters,
    validation,
)

print("post_change_validation=PASS")

# MANUAL RESTORE FROM CAPTURED BACKUP
restore_parameters = {
    "hostname": backup_hostname,
}

restore_plan = make_plan(
    device,
    "set-hostname",
    restore_parameters,
    "manual restoration from captured backup",
)

print(
    "restore_plan_sha256="
    + restore_plan["plan_sha256"]
)

restore_permit = ChangePermit(
    intervention_id="98888888-8888-4888-8888-888888888914",
    device_id=device.device_id,
    operation="set-hostname",
    parameters_sha256=digest(restore_parameters),
)

restore = executor.run(
    device,
    "set-hostname",
    mode="EXECUTE",
    parameters=restore_parameters,
    approved=True,
    permit=restore_permit,
)

assert restore.ok

final = executor.run(
    device,
    "hostname",
    mode="READ",
)

assert final.ok
assert final.stdout.strip() == initial

print("manual_restore=PASS")
print("final_validation=PASS")

combined = (
    snapshot_hashes["system"]
    + snapshot_hashes["hostname"]
    + hashlib.sha256(
        backup_hostname.encode("utf-8")
    ).hexdigest()
)

print(
    "evidence_digest="
    + hashlib.sha256(
        combined.encode("ascii")
    ).hexdigest()
)

print("automatic_rollback=false")
print("real_generic_linux_ssh_executor_change=PASS")
PY

echo
echo "--- 6. STOP LAB AND REMOVE EPHEMERAL MATERIAL ---"

stop_lab_sshd || {
    fail "teardown controlado do sshd LAB falhou"
}

echo "controlled_sshd_teardown=PASS"

rm -rf -- "$LAB_ROOT"

[[ ! -e "$LAB_ROOT" ]] || {
    fail "resíduo LAB permaneceu"
}

trap - EXIT INT TERM

echo "synthetic_residue=0"

echo
echo "--- 7. REAL HOST GUARD ---"

HOST_AFTER="$(/bin/hostname)"

echo "host_after=$HOST_AFTER"

[[ "$HOST_AFTER" == "$HOST_BEFORE" ]] || {
    fail "hostname real da VPS foi alterado"
}

echo "real_host_unchanged=PASS"

echo
echo "--- 8. FINAL POLICY ASSERTIONS ---"

echo "production_database_touched=false"
echo "external_equipment_touched=false"
echo "password_authentication_used=false"
echo "automatic_rollback=false"

echo
echo "MIMIR-GENERIC-LINUX-TRANSIENT-HOSTNAME-LAB: PASS"
