#!/bin/bash
set -euo pipefail

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
DATA="$LAB_ROOT/data"
SOCK="$LAB_ROOT/socket"
PORT="${MIMIR_LAB_PORT:-55433}"
DB="mimir_memory"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

INITDB="${INITDB:-/usr/lib64/postgresql-17/bin/initdb}"
PG_CTL="${PG_CTL:-/usr/lib64/postgresql-17/bin/pg_ctl}"
PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"
CREATEDB="${CREATEDB:-/usr/lib64/postgresql-17/bin/createdb}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    fail "execute como root"
fi

[[ "$PORT" != "5432" ]] || fail "porta de produção recusada"
[[ "$LAB_ROOT" == /var/tmp/mimir-* ]] || fail "LAB_ROOT deve ficar sob /var/tmp/mimir-*"
[[ "$LAB_ROOT" != "/var/lib/postgresql" ]] || fail "PGDATA persistente recusado"

for bin in "$INITDB" "$PG_CTL" "$PSQL" "$CREATEDB"; do
    [[ -x "$bin" ]] || fail "binário ausente: $bin"
done

[[ -s "$ROOT_DIR/tools/memory/bootstrap/memory_v1_canonical.sql" ]] \
    || fail "bootstrap canônico ausente"

if [[ -e "$LAB_ROOT" ]]; then
    fail "lab root já existe: $LAB_ROOT"
fi

echo "=== MIMIR SESSION INGESTION V2 / LAB PREPARE ==="
echo "lab_root=$LAB_ROOT"
echo "port=$PORT"
echo "repo=$ROOT_DIR"

echo
echo "--- 1. production read-only guard ---"

PROD_VERSIONS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT string_agg(version::text, ',' ORDER BY version) FROM mimir.schema_version;"
)"

PROD_OPS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='mimir_ops');"
)"

echo "production_versions=$PROD_VERSIONS"
echo "production_mimir_ops=$PROD_OPS"

[[ "$PROD_VERSIONS" == "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "produção fora do baseline 1..12"
[[ "$PROD_OPS" == "f" ]] || fail "mimir_ops existe em produção inesperadamente"

echo "production_guard=PASS"

echo
echo "--- 2. initialize isolated PostgreSQL 17 cluster ---"

mkdir -p "$LAB_ROOT" "$SOCK"
chown postgres:postgres "$LAB_ROOT"
chmod 0700 "$LAB_ROOT"
chown postgres:postgres "$SOCK"
chmod 0777 "$SOCK"

runuser -u postgres -- "$INITDB" \
    -D "$DATA" \
    --encoding=UTF8 \
    --locale=C.UTF-8 \
    --auth-local=peer \
    --auth-host=reject \
    >/dev/null

cat >> "$DATA/postgresql.conf" <<EOF

# Mimir session ingestion v2 disposable lab
listen_addresses = ''
port = $PORT
unix_socket_directories = '$SOCK'
unix_socket_permissions = 0777
max_connections = 30
fsync = on
synchronous_commit = on
full_page_writes = on
EOF

cat > "$DATA/pg_ident.conf" <<'EOF'
# MAPNAME          SYSTEM-USERNAME   PG-USERNAME
mimir_lab_map      postgres          postgres
mimir_lab_map      openclaw          mimir_app
EOF

cat > "$DATA/pg_hba.conf" <<'EOF'
# Disposable local-only lab. No TCP listener.
local   all   all   peer map=mimir_lab_map
EOF

chown postgres:postgres \
    "$DATA/postgresql.conf" \
    "$DATA/pg_hba.conf" \
    "$DATA/pg_ident.conf"

chmod 0600 \
    "$DATA/postgresql.conf" \
    "$DATA/pg_hba.conf" \
    "$DATA/pg_ident.conf"

echo "cluster_init=PASS"

echo
echo "--- 3. start isolated cluster ---"

runuser -u postgres -- "$PG_CTL" \
    -D "$DATA" \
    -l "$LAB_ROOT/postgresql.log" \
    -w \
    start >/dev/null

test -S "$SOCK/.s.PGSQL.$PORT"

LAB_DATA_DIR="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$SOCK" \
        -p "$PORT" \
        -d postgres \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SHOW data_directory;"
)"

[[ "$LAB_DATA_DIR" == "$DATA" ]] || fail "data_directory inesperado: $LAB_DATA_DIR"

echo "cluster_start=PASS"
echo "data_directory=$LAB_DATA_DIR"

echo
echo "--- 4. create canonical lab database ---"

runuser -u postgres -- "$CREATEDB" \
    -h "$SOCK" \
    -p "$PORT" \
    -T template0 \
    --encoding=UTF8 \
    "$DB"

echo "database_create=PASS"

echo
echo "--- 5. bootstrap memory v1 ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$SOCK" \
    -p "$PORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -f "$ROOT_DIR/tools/memory/bootstrap/memory_v1_canonical.sql" \
    >/dev/null

V1="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$SOCK" \
        -p "$PORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT string_agg(version::text, ',' ORDER BY version) FROM mimir.schema_version;"
)"

[[ "$V1" == "1" ]] || fail "bootstrap não terminou em versão 1"

echo "bootstrap_v1=PASS"

echo
echo "--- 6. replay memory migrations 002..012 ---"

for version in 002 003 004 005 006 007 008 009 010 011 012; do
    mapfile -t files < <(
        find "$ROOT_DIR/tools/memory/migrations" \
            -maxdepth 1 \
            -type f \
            -name "${version}_*.sql" \
            -print
    )

    [[ "${#files[@]}" -eq 1 ]] \
        || fail "migration $version ausente ou ambígua"

    file="${files[0]}"
    echo "apply=$(basename "$file")"

    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$SOCK" \
        -p "$PORT" \
        -d "$DB" \
        -v ON_ERROR_STOP=1 \
        -f "$file" \
        >/dev/null
done

VERSIONS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$SOCK" \
        -p "$PORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT string_agg(version::text, ',' ORDER BY version) FROM mimir.schema_version;"
)"

echo "schema_versions=$VERSIONS"

[[ "$VERSIONS" == "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "lab não terminou em 1..12"

echo "memory_1_12=PASS"

echo
echo "--- 7. peer identity preflight ---"

IDENTITY="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$SOCK" \
        -p "$PORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT session_user || '|' || system_user;"
)"

echo "identity=$IDENTITY"

[[ "$IDENTITY" == "mimir_app|peer:openclaw" ]] \
    || fail "peer identity não corresponde ao contrato"

echo "peer_identity=PASS"

echo
echo "--- 8. production unchanged guard ---"

PROD_AFTER="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT string_agg(version::text, ',' ORDER BY version) FROM mimir.schema_version;"
)"

[[ "$PROD_AFTER" == "$PROD_VERSIONS" ]] \
    || fail "baseline de produção mudou"

echo "production_unchanged=PASS"

echo
echo "=== LAB PREPARE: PASS ==="
echo "export MIMIR_LAB_ROOT='$LAB_ROOT'"
echo "export PGHOST='$SOCK'"
echo "export PGPORT='$PORT'"
echo "lab_database='$DB'"
