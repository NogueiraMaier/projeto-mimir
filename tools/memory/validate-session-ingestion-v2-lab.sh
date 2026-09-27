#!/bin/bash
set -euo pipefail

DB="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT_DIR/tools/memory/migrations/014_api_session_ingestion_v2.sql"

PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"
PG_DUMP="${PG_DUMP:-/usr/lib64/postgresql-17/bin/pg_dump}"
PGHOST="${PGHOST:-/run/postgresql}"
PGPORT="${PGPORT:-5432}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    fail "execute como root para alternar entre postgres e openclaw"
fi

if [[ -z "$DB" ]]; then
    fail "uso: $0 mimir_lab..."
fi

case "$DB" in
    mimir_lab*)
        ;;
    *)
        fail "banco recusado: use somente banco descartável com prefixo mimir_lab"
        ;;
esac

[[ "$DB" != "mimir_memory" ]] || fail "produção explicitamente proibida"
[[ -s "$MIGRATION" ]] || fail "migration 014 não encontrada"

echo "=== MIMIR SESSION INGESTION V2 / LAB VALIDATION ==="
echo "database=$DB"
echo "migration=$MIGRATION"

echo
echo "--- 1. baseline guard ---"

BASELINE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT string_agg(version::text, ',' ORDER BY version)
            FROM mimir.schema_version;
        "
)"

echo "schema_versions=$BASELINE"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -At \
    -c "
        SELECT CASE
            WHEN EXISTS (
                SELECT 1
                FROM mimir.schema_version
                WHERE version = 12
                  AND description =
                      'Leitura controlada de fontes para consolidação'
            )
            THEN 'memory_012=PASS'
            ELSE 'memory_012=FAIL'
        END;
    " | grep -qx 'memory_012=PASS'

UNKNOWN_13="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT count(*)
            FROM mimir.schema_version
            WHERE version = 13
              AND description <>
                  'Inventário operacional e intervenções por API peer controlada; memória preservada';
        "
)"

[[ "$UNKNOWN_13" == "0" ]] || fail "schema_version 13 desconhecida"

echo "baseline_guard=PASS"

echo
echo "--- 2. lab backup ---"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP="/var/tmp/${DB}-pre014-${STAMP}.dump"

runuser -u postgres -- "$PG_DUMP" \
    -Fc \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -f "$BACKUP"

test -s "$BACKUP"

BACKUP_SHA="$(
    sha256sum "$BACKUP" | awk '{print $1}'
)"

echo "backup=$BACKUP"
echo "backup_sha256=$BACKUP_SHA"

echo
echo "--- 3. apply/verify migration 014 ---"

HAS_14="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT count(*)
            FROM mimir.schema_version
            WHERE version = 14;
        "
)"

if [[ "$HAS_14" == "0" ]]; then
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -v ON_ERROR_STOP=1 \
        -f "$MIGRATION"

    echo "migration_014_apply=PASS"
else
    EXACT_14="$(
        runuser -u postgres -- "$PSQL" \
            -X -w \
            -h "$PGHOST" \
            -p "$PGPORT" \
            -d "$DB" \
            -At \
            -v ON_ERROR_STOP=1 \
            -c "
                SELECT count(*)
                FROM mimir.schema_version
                WHERE version = 14
                  AND description =
                      'Ingestão protegida de sessões via OpenClaw chat.history v2';
            "
    )"

    [[ "$EXACT_14" == "1" ]] \
        || fail "versão 14 existente não corresponde à revisão esperada"

    echo "migration_014_apply=SKIPPED_ALREADY_PRESENT"
fi

echo
echo "--- 4. schema/ACL validation ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -P pager=off \
    -c "
        SELECT
            version,
            description
        FROM mimir.schema_version
        WHERE version IN (12,13,14)
        ORDER BY version;

        SELECT
            has_function_privilege(
                'mimir_app',
                'mimir.ingest_session_v2(uuid,text,text,text,text,integer,integer,integer,bigint,timestamptz,text,integer,integer,integer,integer)',
                'EXECUTE'
            ) AS v2_execute,
            has_function_privilege(
                'mimir_app',
                'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
                'EXECUTE'
            ) AS legacy_execute,
            has_table_privilege(
                'mimir_app',
                'mimir.session_sources',
                'SELECT'
            ) AS direct_source_select;
    "

ACL_GUARD="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT
                has_function_privilege(
                    'mimir_app',
                    'mimir.ingest_session_v2(uuid,text,text,text,text,integer,integer,integer,bigint,timestamptz,text,integer,integer,integer,integer)',
                    'EXECUTE'
                )
                AND NOT has_function_privilege(
                    'mimir_app',
                    'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
                    'EXECUTE'
                )
                AND NOT has_table_privilege(
                    'mimir_app',
                    'mimir.session_sources',
                    'SELECT'
                );
        "
)"

[[ "$ACL_GUARD" == "t" ]] || fail "ACL guard falhou"

echo "acl_guard=PASS"

echo
echo "--- 5. function static guard ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -At \
    -c "
        DO \$guard\$
        DECLARE
            v_definition text;
        BEGIN
            SELECT pg_get_functiondef(p.oid)
            INTO v_definition
            FROM pg_catalog.pg_proc AS p
            WHERE p.oid =
                'mimir.ingest_session_v2(uuid,text,text,text,text,integer,integer,integer,bigint,timestamptz,text,integer,integer,integer,integer)'::regprocedure;

            IF position('memory_records' IN v_definition) > 0
               OR position('propose_memory' IN v_definition) > 0
               OR position('review_memory' IN v_definition) > 0
            THEN
                RAISE EXCEPTION
                    'ingest_session_v2 tenta promover memória';
            END IF;
        END
        \$guard\$;
    " >/dev/null

echo "no_automatic_promotion=PASS"

echo
echo "--- 6. peer identity guard ---"

IDENTITY="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT session_user || '|' || system_user;
        "
)"

echo "identity=$IDENTITY"

[[ "$IDENTITY" == "mimir_app|peer:openclaw" ]] \
    || fail "identidade peer esperada não confirmada"

echo "peer_identity=PASS"

echo
echo "--- 7. transactional synthetic v2 ingestion ---"

SESSION_ID='71fd5694-cc85-4a2c-8e37-0ff1626f7562'
SESSION_KEY='agent:main:hud:lab-v2'
SOURCE_FP='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
UPDATED_AT='2026-09-26T12:00:00Z'
COLLECTOR='openclaw-chat-history-v2'

CONTENT=$'user:\nPergunta sintética de laboratório.\n\nassistant:\nResposta sintética de laboratório.'
CONTENT_SHA="$(
    printf '%s' "$CONTENT" | sha256sum | awk '{print $1}'
)"
CONTENT_BYTES="$(
    printf '%s' "$CONTENT" | wc -c | tr -d ' '
)"
CONTENT_B64="$(
    printf '%s' "$CONTENT" | base64 -w0
)"

TX_OUT="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v session_id="$SESSION_ID" \
        -v session_key="$SESSION_KEY" \
        -v source_fp="$SOURCE_FP" \
        -v content_sha="$CONTENT_SHA" \
        -v content_bytes="$CONTENT_BYTES" \
        -v content_b64="$CONTENT_B64" \
        -v updated_at="$UPDATED_AT" \
        -v collector="$COLLECTOR" <<'SQL'
BEGIN;

SELECT mimir.ingest_session_v2(
    :'session_id'::uuid,
    :'session_key',
    :'source_fp',
    convert_from(decode(:'content_b64', 'base64'), 'UTF8'),
    :'content_sha',
    2,
    1,
    1,
    :'content_bytes'::bigint,
    :'updated_at'::timestamptz,
    :'collector',
    0,
    0,
    0,
    0
)::text AS event_id
\gset

SELECT mimir.ingest_session_v2(
    :'session_id'::uuid,
    :'session_key',
    :'source_fp',
    convert_from(decode(:'content_b64', 'base64'), 'UTF8'),
    :'content_sha',
    2,
    1,
    1,
    :'content_bytes'::bigint,
    :'updated_at'::timestamptz,
    :'collector',
    0,
    0,
    0,
    0
)::text = :'event_id' AS idempotent;

SELECT
    (mimir.read_consolidation_source(:'event_id'::uuid)
        ->> 'source_kind')
        = 'openclaw-chat-history-v2'
    AND
    (mimir.read_consolidation_source(:'event_id'::uuid)
        ->> 'source_key')
        = :'session_key'
    AND
    (mimir.read_consolidation_source(:'event_id'::uuid)
        ->> 'content')
        = convert_from(
            decode(:'content_b64', 'base64'),
            'UTF8'
        )
    AS protected_read_ok;

ROLLBACK;
SQL
)"

echo "$TX_OUT"

TRUE_COUNT="$(
    printf '%s\n' "$TX_OUT" | grep -c '^t$' || true
)"

[[ "$TRUE_COUNT" -ge 2 ]] \
    || fail "leitura protegida/idempotência não confirmadas"

echo "transactional_ingestion=PASS"

echo
echo "--- 8. rejection guards ---"

if runuser -u openclaw -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -U mimir_app \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v content_b64="$CONTENT_B64" \
    -v content_sha="$CONTENT_SHA" \
    -v content_bytes="$CONTENT_BYTES" \
    -c "
        SELECT mimir.ingest_session_v2(
            '72fd5694-cc85-4a2c-8e37-0ff1626f7562'::uuid,
            'agent:main:cron:not-allowed',
            '$SOURCE_FP',
            convert_from(
                decode(:'content_b64', 'base64'),
                'UTF8'
            ),
            :'content_sha',
            2,
            1,
            1,
            :'content_bytes'::bigint,
            '$UPDATED_AT'::timestamptz,
            '$COLLECTOR'
        );
    " >/dev/null 2>&1
then
    fail "classe cron indevidamente aceita"
else
    echo "unauthorized_class_rejection=PASS"
fi

BAD_HASH='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'

if runuser -u openclaw -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -U mimir_app \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v content_b64="$CONTENT_B64" \
    -v content_bytes="$CONTENT_BYTES" \
    -c "
        SELECT mimir.ingest_session_v2(
            '73fd5694-cc85-4a2c-8e37-0ff1626f7562'::uuid,
            'agent:main:hud:hash-mismatch',
            '$SOURCE_FP',
            convert_from(
                decode(:'content_b64', 'base64'),
                'UTF8'
            ),
            '$BAD_HASH',
            2,
            1,
            1,
            :'content_bytes'::bigint,
            '$UPDATED_AT'::timestamptz,
            '$COLLECTOR'
        );
    " >/dev/null 2>&1
then
    fail "content hash divergente indevidamente aceito"
else
    echo "content_hash_rejection=PASS"
fi

echo
echo "--- 9. rollback residue guard ---"

RESIDUE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT
                (
                    SELECT count(*)
                    FROM mimir.session_sources
                    WHERE session_id IN (
                        '71fd5694-cc85-4a2c-8e37-0ff1626f7562'::uuid,
                        '72fd5694-cc85-4a2c-8e37-0ff1626f7562'::uuid,
                        '73fd5694-cc85-4a2c-8e37-0ff1626f7562'::uuid
                    )
                )
                +
                (
                    SELECT count(*)
                    FROM mimir.memory_events
                    WHERE source_ref IN (
                        'openclaw://agent/main/session/71fd5694-cc85-4a2c-8e37-0ff1626f7562',
                        'openclaw://agent/main/session/72fd5694-cc85-4a2c-8e37-0ff1626f7562',
                        'openclaw://agent/main/session/73fd5694-cc85-4a2c-8e37-0ff1626f7562'
                    )
                );
        "
)"

[[ "$RESIDUE" == "0" ]] || fail "dados sintéticos persistiram"

echo "synthetic_residue=0"
echo
echo "=== MIMIR SESSION INGESTION V2 LAB: PASS ==="
echo "backup=$BACKUP"
echo "backup_sha256=$BACKUP_SHA"
