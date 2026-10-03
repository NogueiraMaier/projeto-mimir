#!/bin/bash
set -euo pipefail
umask 077

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="${DB:-mimir_memory}"
DATA="$LAB_ROOT/data"
PG_IDENT="$DATA/pg_ident.conf"

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.."
    pwd
)"

MIGRATION="$ROOT_DIR/tools/memory/migrations/016_operational_memory_handoff.sql"
CONSUMER="$ROOT_DIR/tools/memory/mimir-consume-memory-handoff.py"
GENERATOR="$ROOT_DIR/tools/memory/mimir-generate-embeddings.mjs"
SEARCH="$ROOT_DIR/tools/memory/mimir-semantic-search.mjs"

PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"
NODE="${NODE:-/usr/bin/node}"
PYTHON="${PYTHON:-/usr/bin/python3}"

OPENCLAW_ENTRY="/opt/openclaw/openclaw.mjs"

MODEL_ID="hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf"
LLAMA_MODEL_ID="embeddinggemma-300m-qat-q8_0"
EMBEDDING_BASE_URL="http://127.0.0.1:8601/v1"

INTERVENTION_ID="98888888-8888-4888-8888-888888888891"
DEVICE_ID="98888888-8888-4888-8888-888888888892"

MEMORY_KEY="ops.intervention.$INTERVENTION_ID"

QUERY_TEXT="Qual evidencia operacional registra Atlas Handoff 9163 no dispositivo de laboratorio?"

HUMAN_OS_USER="nogueiramaier"
LAB_ACCESS_GROUP="$(id -gn openclaw)"

TMP=""
IDENT_BACKUP=""

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

psql_postgres() {
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        "$@"
}

cleanup() {
    RC=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "=== CLEANUP MEMORY_HANDOFF LAB ==="

    if [[ -n "${IDENT_BACKUP:-}" && -s "$IDENT_BACKUP" ]]; then
        install \
            -o postgres \
            -g postgres \
            -m 0600 \
            "$IDENT_BACKUP" \
            "$PG_IDENT"

        runuser -u postgres -- "$PSQL" \
            -X -w \
            -h "$PGHOST" \
            -p "$PGPORT" \
            -d postgres \
            -At \
            -v ON_ERROR_STOP=1 \
            -c "SELECT pg_reload_conf();" \
            >/dev/null 2>&1

        echo "pg_ident_restored=PASS"
    fi

    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -q \
        -v ON_ERROR_STOP=1 \
        -v eid="$INTERVENTION_ID" >/dev/null <<'SQL'
BEGIN;

DELETE FROM mimir.memory_audit
WHERE object_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id=:'eid'::uuid
);

DELETE FROM mimir.memory_reviews
WHERE memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id=:'eid'::uuid
);

DELETE FROM mimir.memory_relations
WHERE from_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id=:'eid'::uuid
)
OR to_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id=:'eid'::uuid
);

DELETE FROM mimir.memory_records
WHERE source_event_id=:'eid'::uuid;

DELETE FROM mimir.memory_events
WHERE event_id=:'eid'::uuid
   OR (
       source_type='ops-memory-handoff-v1'
       AND source_ref='ops:' || :'eid'
   );

COMMIT;
SQL

    RESIDUE="$(
        runuser -u postgres -- "$PSQL" \
            -X -w \
            -h "$PGHOST" \
            -p "$PGPORT" \
            -d "$DB" \
            -At \
            -v ON_ERROR_STOP=1 \
            -v eid="$INTERVENTION_ID" <<'SQL'
SELECT
      (
        SELECT count(*)
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
           OR source_ref='ops:' || :'eid'
      )
    + (
        SELECT count(*)
        FROM mimir.memory_records
        WHERE source_event_id=:'eid'::uuid
      );
SQL
    )"

    echo "synthetic_residue=${RESIDUE:-unknown}"

    [[ "${RESIDUE:-unknown}" == "0" ]] || {
        echo "FAIL: cleanup deixou residuo" >&2
        exit 1
    }

    [[ -z "${TMP:-}" ]] || rm -rf -- "$TMP"

    exit "$RC"
}

trap cleanup EXIT INT TERM

[[ $EUID -eq 0 ]] || fail "execute como root"

[[ "$LAB_ROOT" == /var/tmp/mimir-* ]] \
    || fail "LAB_ROOT fora do laboratorio"

[[ "$PGHOST" == "$LAB_ROOT/socket" ]] \
    || fail "socket fora do laboratorio"

[[ "$PGPORT" != "5432" ]] \
    || fail "porta de producao recusada"

[[ "$PGHOST" != "/run/postgresql" ]] \
    || fail "socket de producao recusado"

[[ -S "$PGHOST/.s.PGSQL.$PGPORT" ]] \
    || fail "socket PostgreSQL LAB ausente"

[[ -s "$PG_IDENT" ]] \
    || fail "pg_ident.conf ausente"

[[ -s "$MIGRATION" ]] \
    || fail "migration 016 ausente"

[[ -s "$CONSUMER" ]] \
    || fail "consumer ausente"

[[ -s "$GENERATOR" ]] \
    || fail "generator ausente"

[[ -s "$SEARCH" ]] \
    || fail "semantic search ausente"

echo "=== MIMIR MEMORY_HANDOFF OPERATIONAL INTEGRATION LAB ==="

echo
echo "--- 1. ENVIRONMENT / PRODUCTION GUARDS ---"

LAB_DATA="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d postgres \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SHOW data_directory;"
)"

[[ "$LAB_DATA" == "$DATA" ]] \
    || fail "data_directory inesperado: $LAB_DATA"

LAB_VERSIONS_BEFORE="$(
    psql_postgres \
        -c "
            SELECT string_agg(version::text, ',' ORDER BY version)
            FROM mimir.schema_version;
        "
)"

case "$LAB_VERSIONS_BEFORE" in
    "1,2,3,4,5,6,7,8,9,10,11,12,14,15" | \
    "1,2,3,4,5,6,7,8,9,10,11,12,14,15,16")
        ;;
    *)
        fail "schema LAB inesperado: $LAB_VERSIONS_BEFORE"
        ;;
esac

PROD_VERSIONS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT string_agg(version::text, ',' ORDER BY version)
            FROM mimir.schema_version;
        "
)"

[[ "$PROD_VERSIONS" == \
   "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "produção fora de 1..12: $PROD_VERSIONS"

echo "lab_versions_before=$LAB_VERSIONS_BEFORE"
echo "production_versions=$PROD_VERSIONS"
echo "environment_guard=PASS"

echo
echo "--- 2. MIGRATION 016 IN LAB ONLY ---"

HAS_16="$(
    psql_postgres \
        -c "
            SELECT count(*)
            FROM mimir.schema_version
            WHERE version=16;
        "
)"

if [[ "$HAS_16" == "0" ]]; then
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        < "$MIGRATION"
fi

LAB_VERSIONS="$(
    psql_postgres \
        -c "
            SELECT string_agg(version::text, ',' ORDER BY version)
            FROM mimir.schema_version;
        "
)"

[[ "$LAB_VERSIONS" == \
   "1,2,3,4,5,6,7,8,9,10,11,12,14,15,16" ]] \
    || fail "migration 016 nao consolidou: $LAB_VERSIONS"

echo "migration_016_lab=PASS"
echo "lab_versions=$LAB_VERSIONS"

echo
echo "--- 3. NO PREEXISTING SYNTHETIC/PENDING RESIDUE ---"

SYNTHETIC_BEFORE="$(
    psql_postgres \
        -v eid="$INTERVENTION_ID" <<'SQL'
SELECT
      (
        SELECT count(*)
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
           OR source_ref='ops:' || :'eid'
      )
    + (
        SELECT count(*)
        FROM mimir.memory_records
        WHERE source_event_id=:'eid'::uuid
      );
SQL
)"

[[ "$SYNTHETIC_BEFORE" == "0" ]] \
    || fail "residuo sintetico anterior: $SYNTHETIC_BEFORE"

PENDING_BASELINE="$(
    psql_postgres \
        -c "
            SELECT count(*)
            FROM mimir.pending_embeddings;
        "
)"

[[ "$PENDING_BASELINE" == "0" ]] || {
    echo "pending_embeddings_baseline=$PENDING_BASELINE"
    fail "LAB possui embeddings pendentes anteriores; nao tocar automaticamente"
}

echo "synthetic_precheck=PASS"
echo "pending_embeddings_baseline=0"

echo
echo "--- 4. PRIVATE ARTIFACT STAGING ---"

TMP="$(
    mktemp -d \
        /var/tmp/mimir-memory-handoff-lab.XXXXXX
)"

STAGE="$TMP/stage"
IDENT_BACKUP="$TMP/pg_ident.conf.orig"
REPORT="$TMP/report.json"
BAD_REPORT="$TMP/report-bad.json"
QUERY_JS="$TMP/embed-query.mjs"

chown root:"$LAB_ACCESS_GROUP" "$TMP"
chmod 0710 "$TMP"

mkdir -p "$STAGE"
chown root:"$LAB_ACCESS_GROUP" "$STAGE"
chmod 0710 "$STAGE"

install \
    -o openclaw \
    -g "$LAB_ACCESS_GROUP" \
    -m 0500 \
    "$CONSUMER" \
    "$STAGE/mimir-consume-memory-handoff.py"

install \
    -o openclaw \
    -g "$LAB_ACCESS_GROUP" \
    -m 0500 \
    "$GENERATOR" \
    "$STAGE/mimir-generate-embeddings.mjs"

install \
    -o openclaw \
    -g "$LAB_ACCESS_GROUP" \
    -m 0500 \
    "$SEARCH" \
    "$STAGE/mimir-semantic-search.mjs"

CONSUMER_STAGE="$STAGE/mimir-consume-memory-handoff.py"
GENERATOR_STAGE="$STAGE/mimir-generate-embeddings.mjs"
SEARCH_STAGE="$STAGE/mimir-semantic-search.mjs"

runuser -u openclaw -- test -x "$CONSUMER_STAGE" \
    || fail "openclaw nao acessa consumer staged"

runuser -u openclaw -- test -x "$GENERATOR_STAGE" \
    || fail "openclaw nao acessa generator staged"

runuser -u openclaw -- test -x "$SEARCH_STAGE" \
    || fail "openclaw nao acessa search staged"

cp -a "$PG_IDENT" "$IDENT_BACKUP"

echo "artifact_staging=PASS"

echo
echo "--- 5. TEMPORARY PEER MAPS ---"

for ENTRY in \
    "openclaw mimir_app" \
    "openclaw mimir_embedder" \
    "openclaw mimir_search" \
    "nogueiramaier mimir_human"
do
    SYS_USER="${ENTRY%% *}"
    DB_USER="${ENTRY##* }"

    if ! grep -Eq \
        "^mimir_lab_map[[:space:]]+$SYS_USER[[:space:]]+$DB_USER([[:space:]]|$)" \
        "$PG_IDENT"
    then
        printf '%-19s %-17s %s\n' \
            "mimir_lab_map" \
            "$SYS_USER" \
            "$DB_USER" \
            >> "$PG_IDENT"
    fi
done

chown postgres:postgres "$PG_IDENT"
chmod 0600 "$PG_IDENT"

RELOAD="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d postgres \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT pg_reload_conf();"
)"

[[ "$RELOAD" == "t" ]] \
    || fail "reload pg_ident falhou"

APP_IDENTITY="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -c "SELECT session_user || '|' || system_user;"
)"

EMBED_IDENTITY="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_embedder \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -c "SELECT session_user || '|' || system_user;"
)"

SEARCH_IDENTITY="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_search \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -c "SELECT session_user || '|' || system_user;"
)"

[[ "$APP_IDENTITY" == "mimir_app|peer:openclaw" ]] \
    || fail "mimir_app peer invalido: $APP_IDENTITY"

[[ "$EMBED_IDENTITY" == \
   "mimir_embedder|peer:openclaw" ]] \
    || fail "embedder peer invalido: $EMBED_IDENTITY"

[[ "$SEARCH_IDENTITY" == \
   "mimir_search|peer:openclaw" ]] \
    || fail "search peer invalido: $SEARCH_IDENTITY"

echo "mimir_app_peer_identity=PASS"
echo "embedder_peer_identity=PASS"
echo "search_peer_identity=PASS"

echo
echo "--- 6. PRODUCE REAL memory_handoff() CONTRACT ---"

ROOT_DIR_ENV="$ROOT_DIR" \
REPORT_ENV="$REPORT" \
INTERVENTION_ENV="$INTERVENTION_ID" \
DEVICE_ENV="$DEVICE_ID" \
"$PYTHON" - <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
sys.path.insert(0, str(root / "tools" / "ops"))

from ops_workflow import memory_handoff

intervention_id = os.environ["INTERVENTION_ENV"]
device_id = os.environ["DEVICE_ENV"]

validation = {
    "performed": True,
    "passed": True,
    "scope": "diagnostic_commands_exit_zero",
}

before_action = {
    "stage": "READ",
    "operation": "hostname",
    "classification": "read",
    "ok": True,
    "stdout": (
        "Estado operacional sintetico "
        "Atlas Handoff 9163"
    ),
    "stderr": "",
}

report = {
    "schema_version": 1,
    "intervention_id": intervention_id,
    "client": {
        "client_id":
            "98888888-8888-4888-8888-888888888893",
        "name": "LAB",
    },
    "site": {
        "site_id":
            "98888888-8888-4888-8888-888888888894",
        "name": "LAB",
    },
    "device": {
        "device_id": device_id,
        "name": "mimir-handoff-lab",
    },
    "status": "collected",
    "completed_at": "2026-09-29T10:30:00+00:00",
    "before": [before_action],
    "actions": [before_action],
    "validation": validation,
    "inventory_updated": True,
    "closure_ready": True,
    "closed": False,
}

report["memory_handoff"] = memory_handoff(report)

path = Path(os.environ["REPORT_ENV"])

path.write_text(
    json.dumps(
        report,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ) + "\n",
    encoding="utf-8",
)

print("producer_contract=PASS")
print(
    "handoff_integration="
    + report["memory_handoff"]["integration"]
)
print(
    "handoff_state="
    + report["memory_handoff"]["state"]
)
print(
    "automatic_promotion="
    + str(
        report["memory_handoff"][
            "automatic_promotion"
        ]
    ).lower()
)
PY

chown openclaw:"$LAB_ACCESS_GROUP" "$REPORT"
chmod 0600 "$REPORT"

REPORT_SHA="$(
    sha256sum "$REPORT" |
        awk '{print $1}'
)"

echo "report_sha256=$REPORT_SHA"

echo
echo "--- 7. FAIL-CLOSED MALFORMED HANDOFF ---"

REPORT_ENV="$REPORT" \
BAD_REPORT_ENV="$BAD_REPORT" \
"$PYTHON" - <<'PY'
import json
import os
from pathlib import Path

source = Path(os.environ["REPORT_ENV"])
target = Path(os.environ["BAD_REPORT_ENV"])

doc = json.loads(source.read_text(encoding="utf-8"))

doc["memory_handoff"]["automatic_promotion"] = True

target.write_text(
    json.dumps(
        doc,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ) + "\n",
    encoding="utf-8",
)
PY

chown openclaw:"$LAB_ACCESS_GROUP" "$BAD_REPORT"
chmod 0600 "$BAD_REPORT"

BAD_SHA="$(
    sha256sum "$BAD_REPORT" |
        awk '{print $1}'
)"

set +e

BAD_OUTPUT="$(
    runuser -u openclaw -- \
    env \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_app \
        "$PYTHON" "$CONSUMER_STAGE" \
        --file "$BAD_REPORT" \
        --sha256 "$BAD_SHA" \
        2>&1
)"
BAD_RC=$?

set -e

[[ "$BAD_RC" -ne 0 ]] \
    || fail "handoff automatic_promotion=true foi aceito"

grep -Fq \
    "automatic_promotion deve permanecer false" \
    <<<"$BAD_OUTPUT" \
    || fail "falha negativa inesperada"

NEGATIVE_DB="$(
    psql_postgres \
        -v eid="$INTERVENTION_ID" <<'SQL'
SELECT count(*)
FROM mimir.memory_events
WHERE event_id=:'eid'::uuid;
SQL
)"

[[ "$NEGATIVE_DB" == "0" ]] \
    || fail "handoff invalido tocou o banco"

echo "malformed_handoff_fail_closed=PASS"
echo "malformed_handoff_database_write=0"

echo
echo "--- 8. VALID CONSUMER DRY-RUN ---"

DRY_OUTPUT="$(
    runuser -u openclaw -- \
    env \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_app \
        "$PYTHON" "$CONSUMER_STAGE" \
        --file "$REPORT" \
        --sha256 "$REPORT_SHA"
)"

printf '%s\n' "$DRY_OUTPUT"

grep -Fq "memory_handoff_v1_validation=PASS" \
    <<<"$DRY_OUTPUT" \
    || fail "consumer dry-run nao validou"

grep -Fq "database_write=false" \
    <<<"$DRY_OUTPUT" \
    || fail "dry-run tentou gravar"

DRY_COUNT="$(
    psql_postgres \
        -v eid="$INTERVENTION_ID" <<'SQL'
SELECT count(*)
FROM mimir.memory_events
WHERE event_id=:'eid'::uuid;
SQL
)"

[[ "$DRY_COUNT" == "0" ]] \
    || fail "dry-run gravou no banco"

echo "consumer_dry_run=PASS"

echo
echo "--- 9. SUBMIT -> CONFIDENTIAL EVENT -> CANDIDATE ---"

SUBMIT_OUTPUT="$(
    runuser -u openclaw -- \
    env \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_app \
        "$PYTHON" "$CONSUMER_STAGE" \
        --file "$REPORT" \
        --sha256 "$REPORT_SHA" \
        --submit
)"

printf '%s\n' "$SUBMIT_OUTPUT"

EVENT_ID="$(
    awk -F= '$1=="event_id"{print $2}' \
        <<<"$SUBMIT_OUTPUT"
)"

MEMORY_ID="$(
    awk -F= '$1=="memory_id"{print $2}' \
        <<<"$SUBMIT_OUTPUT"
)"

CANDIDATE_STATE="$(
    awk -F= '$1=="candidate_state"{print $2}' \
        <<<"$SUBMIT_OUTPUT"
)"

CONFLICT="$(
    awk -F= \
        '$1=="conflict_classification"{print $2}' \
        <<<"$SUBMIT_OUTPUT"
)"

[[ "$EVENT_ID" == "$INTERVENTION_ID" ]] \
    || fail "event_id inesperado: $EVENT_ID"

[[ -n "$MEMORY_ID" ]] \
    || fail "memory_id vazio"

[[ "$CANDIDATE_STATE" == "candidate" ]] \
    || fail "estado inesperado: $CANDIDATE_STATE"

[[ "$CONFLICT" == "none" ]] \
    || fail "conflict inesperado: $CONFLICT"

STATE="$(
    psql_postgres \
        -v eid="$EVENT_ID" \
        -v mid="$MEMORY_ID" \
        -v mkey="$MEMORY_KEY" <<'SQL'
SELECT
    (
        SELECT
            source_type
            || '|'
            || classification
            || '|'
            || source_ref
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
    )
    || '|'
    ||
    (
        SELECT
            status
            || '|'
            || memory_type
            || '|'
            || memory_key
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    );
SQL
)"

EXPECTED_STATE="ops-memory-handoff-v1|confidential|ops:$INTERVENTION_ID|candidate|evidence|$MEMORY_KEY"

[[ "$STATE" == "$EXPECTED_STATE" ]] \
    || fail "estado de submissao invalido: $STATE"

echo "confidential_event_ingestion=PASS"
echo "candidate_first_semantics=PASS"
echo "contradiction_inspection=PASS"

echo
echo "--- 10. IDEMPOTENT REPLAY / DEDUP ---"

REPLAY_OUTPUT="$(
    runuser -u openclaw -- \
    env \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_app \
        "$PYTHON" "$CONSUMER_STAGE" \
        --file "$REPORT" \
        --sha256 "$REPORT_SHA" \
        --submit
)"

REPLAY_EVENT="$(
    awk -F= '$1=="event_id"{print $2}' \
        <<<"$REPLAY_OUTPUT"
)"

REPLAY_MEMORY="$(
    awk -F= '$1=="memory_id"{print $2}' \
        <<<"$REPLAY_OUTPUT"
)"

[[ "$REPLAY_EVENT" == "$EVENT_ID" ]] \
    || fail "replay mudou event_id"

[[ "$REPLAY_MEMORY" == "$MEMORY_ID" ]] \
    || fail "replay mudou memory_id"

DEDUP_STATE="$(
    psql_postgres \
        -v eid="$EVENT_ID" \
        -v mid="$MEMORY_ID" <<'SQL'
SELECT
    (
        SELECT count(*)
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
    )
    || '|'
    ||
    (
        SELECT count(*)
        FROM mimir.memory_records
        WHERE source_event_id=:'eid'::uuid
    )
    || '|'
    ||
    (
        SELECT count(*)
        FROM mimir.memory_audit
        WHERE object_id=:'mid'::uuid
          AND action='propose'
    );
SQL
)"

[[ "$DEDUP_STATE" == "1|1|1" ]] \
    || fail "dedup/replay invalido: $DEDUP_STATE"

echo "handoff_replay_idempotency=PASS"
echo "handoff_deduplication=PASS"

echo
echo "--- 11. PROVENANCE BEFORE REVIEW ---"

PROVENANCE="$(
    psql_postgres \
        -v eid="$EVENT_ID" \
        -v mid="$MEMORY_ID" \
        -v report_sha="$REPORT_SHA" <<'SQL'
SELECT
    (
        SELECT
            payload->>'requires_human_review'
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
    )
    || '|'
    ||
    (
        SELECT
            metadata->>'submission_type'
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    )
    || '|'
    ||
    (
        SELECT
            metadata->>'report_sha256'
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    )
    || '|'
    ||
    (
        SELECT
            embedding IS NULL
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    );
SQL
)"

[[ "$PROVENANCE" == \
   "true|ops-memory-handoff-v1|$REPORT_SHA|true" ]] \
    || fail "proveniencia pre-review invalida: $PROVENANCE"

PENDING_BEFORE_REVIEW="$(
    psql_postgres \
        -v mid="$MEMORY_ID" <<'SQL'
SELECT count(*)
FROM mimir.pending_embeddings
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$PENDING_BEFORE_REVIEW" == "0" ]] \
    || fail "candidate tornou-se embedding elegivel"

echo "handoff_provenance=PASS"
echo "embedding_before_human_review=BLOCKED"

echo
echo "--- 12. ENSURE MANAGED EMBEDDING PROVIDER ---"

if ! ss -ltn | grep -q '127.0.0.1:8601'; then
    PARAMS='{
      "name": "mimir_memory_search",
      "agentId": "main",
      "args": {
        "query": "Projeto Mimir memoria permanente",
        "limit": 1,
        "min_similarity": 0.95
      }
    }'

    ACQUIRE="$(
        runuser -u openclaw -- \
        env \
            HOME=/var/lib/openclaw \
            USER=openclaw \
            LOGNAME=openclaw \
            "$NODE" "$OPENCLAW_ENTRY" \
            gateway call tools.invoke \
            --params "$PARAMS" \
            --json
    )"

    printf '%s' "$ACQUIRE" |
        "$PYTHON" -c '
import json,sys
x=json.load(sys.stdin)
assert x["ok"] is True
assert x["output"]["details"]["dimensions"] == 768
'
fi

ss -ltn | grep -q '127.0.0.1:8601' \
    || fail "managed embedding listener ausente"

echo "managed_embedding_provider=PASS"

echo
echo "--- 13. GENERATE QUERY EMBEDDING ONCE ---"

cat > "$QUERY_JS" <<'JS'
const model =
    "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/" +
    "embeddinggemma-300m-qat-Q8_0.gguf";

const runtimeModel =
    "embeddinggemma-300m-qat-q8_0";

const query = process.env.MIMIR_LAB_QUERY;
const baseUrl = process.env.MIMIR_EMBEDDING_BASE_URL;

if (!query || !baseUrl) {
    throw new Error("query/baseUrl ausente");
}

const response = await fetch(
    `${baseUrl.replace(/\/+$/, "")}/embeddings`,
    {
        method: "POST",
        headers: {
            "content-type": "application/json",
        },
        body: JSON.stringify({
            model: runtimeModel,
            input: [
                `task: search result | query: ${query}`
            ],
            dimensions: 768,
        }),
        signal: AbortSignal.timeout(60_000),
    }
);

const raw = await response.text();

if (!response.ok) {
    throw new Error(
        `embedding HTTP ${response.status}: ` +
        raw.slice(0, 512)
    );
}

const payload = JSON.parse(raw);
const embedding = payload?.data?.[0]?.embedding;

if (
    !Array.isArray(embedding) ||
    embedding.length !== 768 ||
    !embedding.every(Number.isFinite)
) {
    throw new Error("query embedding invalido");
}

process.stdout.write(
    JSON.stringify({
        query,
        model,
        embedding,
        limit: 10,
        min_similarity: 0.2,
    })
);
JS

chown openclaw:"$LAB_ACCESS_GROUP" "$QUERY_JS"
chmod 0600 "$QUERY_JS"

REQUEST_JSON="$(
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        MIMIR_LAB_QUERY="$QUERY_TEXT" \
        MIMIR_EMBEDDING_BASE_URL="$EMBEDDING_BASE_URL" \
        "$NODE" "$QUERY_JS"
)"

QUERY_DIMS="$(
    printf '%s' "$REQUEST_JSON" |
        "$PYTHON" -c '
import json,sys
print(len(json.load(sys.stdin)["embedding"]))
'
)"

[[ "$QUERY_DIMS" == "768" ]] \
    || fail "query embedding != 768"

echo "query_embedding_768d=PASS"

echo
echo "--- 14. SEMANTIC INVISIBILITY BEFORE REVIEW ---"

SEARCH_BEFORE="$(
    printf '%s' "$REQUEST_JSON" |
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_search \
        "$NODE" "$SEARCH_STAGE" \
        --json
)"

BEFORE_VISIBLE="$(
    printf '%s' "$SEARCH_BEFORE" |
        "$PYTHON" -c '
import json,sys
doc=json.load(sys.stdin)
target=sys.argv[1]
ids=[
    str(item["memory_id"])
    for item in doc["results"]
]
print("yes" if target in ids else "no")
' "$MEMORY_ID"
)"

[[ "$BEFORE_VISIBLE" == "no" ]] \
    || fail "candidate apareceu na busca semantica"

echo "semantic_visibility_before_review=BLOCKED"

echo
echo "--- 15. AUTHENTICATED HUMAN REVIEW ---"

REVIEW_RESULT="$(
    runuser \
        -u "$HUMAN_OS_USER" \
        -g "$LAB_ACCESS_GROUP" \
        -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_human \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -v mid="$MEMORY_ID" <<'SQL'
BEGIN;
SET LOCAL ROLE mimir_reviewer;

SELECT mimir.review_memory(
    :'mid'::uuid,
    'approve',
    NULL,
    '{
      "source":"ops-memory-handoff-v1",
      "lab":true
    }'::jsonb
)::text;

COMMIT;
SQL
)"

[[ -n "$REVIEW_RESULT" ]] \
    || fail "review result vazio"

ACTIVE_STATE="$(
    psql_postgres \
        -v mid="$MEMORY_ID" <<'SQL'
SELECT status
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$ACTIVE_STATE" == "active" ]] \
    || fail "candidate nao virou active"

echo "authenticated_human_review=PASS"
echo "candidate_to_active=PASS"

echo
echo "--- 16. EMBEDDING ONLY AFTER PROMOTION ---"

PENDING_AFTER_REVIEW="$(
    psql_postgres \
        -v mid="$MEMORY_ID" <<'SQL'
SELECT count(*)
FROM mimir.pending_embeddings
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$PENDING_AFTER_REVIEW" == "1" ]] \
    || fail "active nao ficou embedding elegivel"

TOTAL_PENDING="$(
    psql_postgres \
        -c "
            SELECT count(*)
            FROM mimir.pending_embeddings;
        "
)"

[[ "$TOTAL_PENDING" == "1" ]] \
    || fail "LAB possui pendentes inesperados: $TOTAL_PENDING"

EMBED_OUTPUT="$(
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_embedder \
        MIMIR_EMBEDDING_BASE_URL="$EMBEDDING_BASE_URL" \
        "$NODE" "$GENERATOR_STAGE" \
        --limit 1 \
        --write
)"

grep -Fq "Embeddings gravados: 1" \
    <<<"$EMBED_OUTPUT" \
    || fail "embedding nao foi gravado"

EMBED_STATE="$(
    psql_postgres \
        -v mid="$MEMORY_ID" \
        -v model="$MODEL_ID" <<'SQL'
SELECT
    embedding IS NOT NULL
    AND public.vector_dims(embedding)=768
    AND abs(public.vector_norm(embedding)-1.0) < 0.0001
    AND embedding_model=:'model'
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$EMBED_STATE" == "t" ]] \
    || fail "embedding final invalido: $EMBED_STATE"

echo "embedding_after_human_promotion=PASS"
echo "embedding_768d=PASS"

echo
echo "--- 17. SEMANTIC VISIBILITY AFTER REVIEW ---"

SEARCH_AFTER="$(
    printf '%s' "$REQUEST_JSON" |
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_search \
        "$NODE" "$SEARCH_STAGE" \
        --json
)"

AFTER_GUARD="$(
    printf '%s' "$SEARCH_AFTER" |
        "$PYTHON" -c '
import json,sys

doc=json.load(sys.stdin)
target=sys.argv[1]
source_ref=sys.argv[2]

matches=[
    item
    for item in doc["results"]
    if str(item["memory_id"]) == target
]

assert len(matches) == 1
assert matches[0]["source_ref"] == source_ref
assert float(matches[0]["similarity"]) >= 0.2

print("PASS")
' "$MEMORY_ID" "ops:$INTERVENTION_ID"
)"

[[ "$AFTER_GUARD" == "PASS" ]] \
    || fail "semantic recovery falhou"

echo "semantic_visibility_after_review=PASS"
echo "operational_handoff_semantic_retrieval=PASS"

echo
echo "--- 18. END-TO-END AUDIT / PROVENANCE ---"

E2E="$(
    psql_postgres \
        -v eid="$EVENT_ID" \
        -v mid="$MEMORY_ID" \
        -v report_sha="$REPORT_SHA" <<'SQL'
SELECT
    (
        SELECT classification='confidential'
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
    )
    || '|'
    ||
    (
        SELECT metadata->>'report_sha256'=:'report_sha'
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    )
    || '|'
    ||
    EXISTS (
        SELECT 1
        FROM mimir.memory_audit
        WHERE object_id=:'mid'::uuid
          AND action='propose'
          AND actor='mimir-memory-handoff-v1'
    )
    || '|'
    ||
    EXISTS (
        SELECT 1
        FROM mimir.memory_reviews
        WHERE memory_id=:'mid'::uuid
          AND decision='approve'
          AND reviewer='Nogueira Maier'
          AND reviewer_role='mimir_human'
          AND authentication_identity='peer:nogueiramaier'
    )
    || '|'
    ||
    EXISTS (
        SELECT 1
        FROM mimir.memory_audit
        WHERE object_id=:'mid'::uuid
          AND action='embedding_set'
          AND actor='mimir-embedder'
    )
    || '|'
    ||
    (
        SELECT status='active'
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
    );
SQL
)"

[[ "$E2E" == \
   "true|true|true|true|true|true" ]] \
    || fail "e2e invalido: $E2E"

RELATIONS="$(
    psql_postgres \
        -v mid="$MEMORY_ID" <<'SQL'
SELECT count(*)
FROM mimir.memory_relations
WHERE from_memory_id=:'mid'::uuid
   OR to_memory_id=:'mid'::uuid;
SQL
)"

[[ "$RELATIONS" == "0" ]] \
    || fail "relacoes automaticas inesperadas"

echo "end_to_end_handoff_provenance=PASS"
echo "end_to_end_handoff_audit=PASS"
echo "automatic_relations=0"
echo "automatic_promotion=false"

echo
echo "--- 19. FINAL PRODUCTION GUARD ---"

PROD_AFTER="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT string_agg(version::text, ',' ORDER BY version)
            FROM mimir.schema_version;
        "
)"

[[ "$PROD_AFTER" == "$PROD_VERSIONS" ]] \
    || fail "produção mudou"

PROD_14_16="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h /run/postgresql \
        -p 5432 \
        -d mimir_memory \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT count(*)
            FROM mimir.schema_version
            WHERE version IN (14,15,16);
        "
)"

[[ "$PROD_14_16" == "0" ]] \
    || fail "migration 14/15/16 apareceu em produção"

echo "production_unchanged=PASS"
echo "production_014_015_016=ABSENT"

echo
echo "MIMIR-MEMORY-HANDOFF-INTEGRATION-LAB: PASS"
