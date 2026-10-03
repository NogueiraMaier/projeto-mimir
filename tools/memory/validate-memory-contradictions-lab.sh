#!/bin/bash
set -euo pipefail
umask 077

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="${DB:-mimir_memory}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION="$ROOT_DIR/tools/memory/migrations/015_memory_contradiction_detection.sql"

PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"

EVENT_ACTIVE="94444444-4444-4444-8444-444444444441"
EVENT_DUP="94444444-4444-4444-8444-444444444442"
EVENT_CONTRA="94444444-4444-4444-8444-444444444443"
EVENT_NONE="94444444-4444-4444-8444-444444444444"

ACTIVE_ID="95555555-5555-4555-8555-555555555551"

KEY_MAIN="lab.preference.maintenance-window"
KEY_OTHER="lab.preference.backup-window"

CONTENT_ACTIVE="Synthetic maintenance window is 03:00."
CONTENT_CONTRA="Synthetic maintenance window is 04:00."
CONTENT_NONE="Synthetic backup window is 05:00."

ACTOR="mimir-contradiction-lab"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    RC=$?

    trap - EXIT INT TERM
    set +e

    echo
    echo "=== CLEANUP SINTETICO ==="

    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -v ON_ERROR_STOP=1 \
        -v ea="$EVENT_ACTIVE" \
        -v ed="$EVENT_DUP" \
        -v ec="$EVENT_CONTRA" \
        -v en="$EVENT_NONE" \
        -v actor="$ACTOR" >/dev/null <<'SQL'
BEGIN;

DELETE FROM mimir.memory_audit
WHERE actor = :'actor'
   OR object_id IN (
       SELECT memory_id
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'ed'::uuid,
           :'ec'::uuid,
           :'en'::uuid
       )
   );

DELETE FROM mimir.memory_reviews
WHERE memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'ed'::uuid,
        :'ec'::uuid,
        :'en'::uuid
    )
);

DELETE FROM mimir.memory_relations
WHERE from_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'ed'::uuid,
        :'ec'::uuid,
        :'en'::uuid
    )
)
OR to_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'ed'::uuid,
        :'ec'::uuid,
        :'en'::uuid
    )
);

DELETE FROM mimir.memory_records
WHERE source_event_id IN (
    :'ea'::uuid,
    :'ed'::uuid,
    :'ec'::uuid,
    :'en'::uuid
);

DELETE FROM mimir.memory_events
WHERE event_id IN (
    :'ea'::uuid,
    :'ed'::uuid,
    :'ec'::uuid,
    :'en'::uuid
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
            -v ea="$EVENT_ACTIVE" \
            -v ed="$EVENT_DUP" \
            -v ec="$EVENT_CONTRA" \
            -v en="$EVENT_NONE" \
            -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'ea'::uuid,
           :'ed'::uuid,
           :'ec'::uuid,
           :'en'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'ed'::uuid,
           :'ec'::uuid,
           :'en'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor = :'actor');
SQL
    )"

    echo "synthetic_residue=${RESIDUE:-unknown}"

    [[ "${RESIDUE:-unknown}" == "0" ]] || {
        echo "FAIL: cleanup deixou residuo" >&2
        exit 1
    }

    exit "$RC"
}

propose() {
    local event_id="$1"
    local memory_key="$2"
    local content="$3"

    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v eid="$event_id" \
        -v mkey="$memory_key" \
        -v mcontent="$content" <<'SQL'
SELECT mimir.propose_memory(
    :'eid'::uuid,
    :'mkey',
    'preference',
    'Contradiction LAB',
    'Synthetic conflict classification',
    :'mcontent',
    0.800,
    0.500,
    false,
    '{"synthetic":true,"lab":"contradiction"}'::jsonb,
    'mimir-contradiction-lab'
)::text;
SQL
}

inspect() {
    local memory_id="$1"

    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$memory_id" <<'SQL'
SELECT
    classification,
    candidate_memory_id,
    coalesce(active_memory_id::text, ''),
    scope_type,
    scope_key,
    memory_key,
    candidate_content_sha256,
    coalesce(active_content_sha256, '')
FROM mimir.inspect_candidate_conflict(:'mid'::uuid);
SQL
}

trap cleanup EXIT INT TERM

[[ $EUID -eq 0 ]] || fail "execute como root"
[[ "$LAB_ROOT" == /var/tmp/mimir-* ]] \
    || fail "LAB_ROOT fora de /var/tmp/mimir-*"
[[ "$PGHOST" == "$LAB_ROOT/socket" ]] \
    || fail "socket fora do LAB"
[[ "$PGPORT" != "5432" ]] \
    || fail "porta de producao recusada"
[[ "$PGHOST" != "/run/postgresql" ]] \
    || fail "socket de producao recusado"
[[ -S "$PGHOST/.s.PGSQL.$PGPORT" ]] \
    || fail "socket do LAB ausente"
[[ -s "$MIGRATION" ]] \
    || fail "migration 015 ausente"

echo "=== MIMIR MEMORY CONTRADICTION / LAB ==="

echo
echo "--- 1. ENVIRONMENT GUARDS ---"

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

[[ "$LAB_DATA" == "$LAB_ROOT/data" ]] \
    || fail "data_directory fora do LAB: $LAB_DATA"

BEFORE="$(
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

case "$BEFORE" in
    "1,2,3,4,5,6,7,8,9,10,11,12,14"|"1,2,3,4,5,6,7,8,9,10,11,12,14,15")
        ;;
    *)
        fail "schema LAB inesperado: $BEFORE"
        ;;
esac

PROD_BEFORE="$(
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

[[ "$PROD_BEFORE" == "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "producao saiu de 1..12"

echo "lab_before=$BEFORE"
echo "production_versions=$PROD_BEFORE"
echo "environment_guard=PASS"

echo
echo "--- 2. APPLY / VERIFY MIGRATION 015 ---"

HAS_15="$(
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
            WHERE version=15;
        "
)"

if [[ "$HAS_15" == "0" ]]; then
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -v ON_ERROR_STOP=1 \
        < "$MIGRATION"

    echo "migration_015_apply=PASS"
else
    EXACT_15="$(
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
                WHERE version=15
                  AND description =
                    'Detecção determinística de duplicidade e contradição entre candidate e active';
            "
    )"

    [[ "$EXACT_15" == "1" ]] \
        || fail "migration 015 inesperada"

    echo "migration_015_apply=SKIPPED_ALREADY_PRESENT"
fi

AFTER="$(
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

[[ "$AFTER" == \
   "1,2,3,4,5,6,7,8,9,10,11,12,14,15" ]] \
    || fail "schema LAB pós-015 inesperado: $AFTER"

echo "lab_after=$AFTER"

echo
echo "--- 3. FUNCTION / ACL GUARDS ---"

ACL="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 <<'SQL'
SELECT
    to_regprocedure(
        'mimir.inspect_candidate_conflict(uuid)'
    ) IS NOT NULL
    AND has_function_privilege(
        'mimir_app',
        'mimir.inspect_candidate_conflict(uuid)',
        'EXECUTE'
    )
    AND has_function_privilege(
        'mimir_reviewer',
        'mimir.inspect_candidate_conflict(uuid)',
        'EXECUTE'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_proc AS p
        CROSS JOIN LATERAL aclexplode(
            coalesce(
                p.proacl,
                acldefault('f', p.proowner)
            )
        ) AS a
        WHERE p.oid =
            'mimir.inspect_candidate_conflict(uuid)'::regprocedure
          AND a.grantee = 0
          AND a.privilege_type = 'EXECUTE'
    );
SQL
)"

[[ "$ACL" == "t" ]] \
    || fail "function/ACL guard falhou"

echo "function_acl=PASS"

echo
echo "--- 4. RESIDUE PRECHECK ---"

PRECOUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v ea="$EVENT_ACTIVE" \
        -v ed="$EVENT_DUP" \
        -v ec="$EVENT_CONTRA" \
        -v en="$EVENT_NONE" \
        -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'ea'::uuid,
           :'ed'::uuid,
           :'ec'::uuid,
           :'en'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'ed'::uuid,
           :'ec'::uuid,
           :'en'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor=:'actor');
SQL
)"

[[ "$PRECOUNT" == "0" ]] \
    || fail "residuo sintetico anterior encontrado"

echo "residue_precheck=PASS"

echo
echo "--- 5. SYNTHETIC SOURCES / ACTIVE BASELINE ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v ea="$EVENT_ACTIVE" \
    -v ed="$EVENT_DUP" \
    -v ec="$EVENT_CONTRA" \
    -v en="$EVENT_NONE" \
    -v active_id="$ACTIVE_ID" \
    -v key_main="$KEY_MAIN" \
    -v content="$CONTENT_ACTIVE" <<'SQL'
INSERT INTO mimir.memory_events (
    event_id,
    scope_type,
    scope_key,
    event_type,
    source_type,
    source_ref,
    actor,
    classification,
    content,
    payload
)
VALUES
(
    :'ea'::uuid,
    'system',
    'mimir-contradiction-lab',
    'contradiction_lab_source',
    'synthetic',
    'lab://contradiction/active',
    'mimir-contradiction-lab',
    'internal',
    'Synthetic active source.',
    '{"synthetic":true}'::jsonb
),
(
    :'ed'::uuid,
    'system',
    'mimir-contradiction-lab',
    'contradiction_lab_source',
    'synthetic',
    'lab://contradiction/duplicate',
    'mimir-contradiction-lab',
    'internal',
    'Synthetic duplicate source.',
    '{"synthetic":true}'::jsonb
),
(
    :'ec'::uuid,
    'system',
    'mimir-contradiction-lab',
    'contradiction_lab_source',
    'synthetic',
    'lab://contradiction/conflict',
    'mimir-contradiction-lab',
    'internal',
    'Synthetic contradiction source.',
    '{"synthetic":true}'::jsonb
),
(
    :'en'::uuid,
    'system',
    'mimir-contradiction-lab',
    'contradiction_lab_source',
    'synthetic',
    'lab://contradiction/none',
    'mimir-contradiction-lab',
    'internal',
    'Synthetic independent source.',
    '{"synthetic":true}'::jsonb
);

INSERT INTO mimir.memory_records (
    memory_id,
    memory_key,
    memory_type,
    status,
    scope_type,
    scope_key,
    title,
    summary,
    content,
    source_event_id,
    confidence,
    importance,
    metadata,
    created_by
)
VALUES (
    :'active_id'::uuid,
    :'key_main',
    'preference',
    'active',
    'system',
    'mimir-contradiction-lab',
    'Synthetic active preference',
    'Synthetic active baseline',
    :'content',
    :'ea'::uuid,
    0.900,
    0.500,
    '{"synthetic":true,"lab":"contradiction"}'::jsonb,
    'mimir-contradiction-lab'
);
SQL

echo "active_baseline=PASS"

echo
echo "--- 6. CREATE CANDIDATES ---"

DUP_ID="$(propose "$EVENT_DUP" "$KEY_MAIN" "$CONTENT_ACTIVE")"
CONTRA_ID="$(propose "$EVENT_CONTRA" "$KEY_MAIN" "$CONTENT_CONTRA")"
NONE_ID="$(propose "$EVENT_NONE" "$KEY_OTHER" "$CONTENT_NONE")"

[[ -n "$DUP_ID" ]] || fail "duplicate candidate vazio"
[[ -n "$CONTRA_ID" ]] || fail "contradiction candidate vazio"
[[ -n "$NONE_ID" ]] || fail "none candidate vazio"

echo "candidate_creation=PASS"

echo
echo "--- 7. DUPLICATE CLASSIFICATION ---"

DUP_RESULT="$(inspect "$DUP_ID")"
DUP_CLASS="$(cut -d'|' -f1 <<<"$DUP_RESULT")"
DUP_ACTIVE="$(cut -d'|' -f3 <<<"$DUP_RESULT")"

[[ "$DUP_CLASS" == "duplicate" ]] \
    || fail "esperado duplicate, obtido: $DUP_CLASS"

[[ "$DUP_ACTIVE" == "$ACTIVE_ID" ]] \
    || fail "duplicate apontou active incorreta"

echo "duplicate_detection=PASS"

echo
echo "--- 8. CONTRADICTION CLASSIFICATION ---"

CONTRA_RESULT="$(inspect "$CONTRA_ID")"
CONTRA_CLASS="$(cut -d'|' -f1 <<<"$CONTRA_RESULT")"
CONTRA_ACTIVE="$(cut -d'|' -f3 <<<"$CONTRA_RESULT")"

[[ "$CONTRA_CLASS" == "contradiction" ]] \
    || fail "esperado contradiction, obtido: $CONTRA_CLASS"

[[ "$CONTRA_ACTIVE" == "$ACTIVE_ID" ]] \
    || fail "contradiction apontou active incorreta"

echo "contradiction_detection=PASS"

echo
echo "--- 9. NO-CONFLICT CLASSIFICATION ---"

NONE_RESULT="$(inspect "$NONE_ID")"
NONE_CLASS="$(cut -d'|' -f1 <<<"$NONE_RESULT")"
NONE_ACTIVE="$(cut -d'|' -f3 <<<"$NONE_RESULT")"

[[ "$NONE_CLASS" == "none" ]] \
    || fail "esperado none, obtido: $NONE_CLASS"

[[ -z "$NONE_ACTIVE" ]] \
    || fail "none retornou active inesperada"

echo "no_conflict_detection=PASS"

echo
echo "--- 10. NON-CANDIDATE NEGATIVE TEST ---"

set +e

ACTIVE_ERROR="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" \
        2>&1 <<'SQL'
SELECT *
FROM mimir.inspect_candidate_conflict(
    :'mid'::uuid
);
SQL
)"
ACTIVE_RC=$?

set -e

[[ "$ACTIVE_RC" -ne 0 ]] \
    || fail "active foi aceita como candidate"

grep -Fq \
    "somente candidate pode ser inspecionada" \
    <<<"$ACTIVE_ERROR" \
    || fail "rejeicao de non-candidate inesperada"

echo "non_candidate_rejection=PASS"

echo
echo "--- 11. READ-ONLY DETECTOR GUARD ---"

STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v actor="$ACTOR" \
        -v active_id="$ACTIVE_ID" \
        -v dup_id="$DUP_ID" \
        -v contra_id="$CONTRA_ID" \
        -v none_id="$NONE_ID" <<'SQL'
SELECT
    (SELECT count(*)
     FROM mimir.memory_audit
     WHERE actor=:'actor'
       AND action='propose')
    || '|'
    ||
    (SELECT count(*)
     FROM mimir.memory_relations
     WHERE from_memory_id IN (
         :'active_id'::uuid,
         :'dup_id'::uuid,
         :'contra_id'::uuid,
         :'none_id'::uuid
     )
        OR to_memory_id IN (
         :'active_id'::uuid,
         :'dup_id'::uuid,
         :'contra_id'::uuid,
         :'none_id'::uuid
     ))
    || '|'
    ||
    (SELECT count(*)
     FROM mimir.memory_records
     WHERE memory_id IN (
         :'dup_id'::uuid,
         :'contra_id'::uuid,
         :'none_id'::uuid
     )
       AND status='candidate');
SQL
)"

IFS='|' read -r AUDITS RELATIONS CANDIDATES <<<"$STATE"

[[ "$AUDITS" == "3" ]] \
    || fail "auditoria inesperada: $AUDITS"

[[ "$RELATIONS" == "0" ]] \
    || fail "detector persistiu relacao inesperada"

[[ "$CANDIDATES" == "3" ]] \
    || fail "detector alterou status de candidate"

echo "detector_writes=0"
echo "candidate_status_preserved=PASS"

echo
echo "--- 12. FINAL PRODUCTION GUARD ---"

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

[[ "$PROD_AFTER" == "$PROD_BEFORE" ]] \
    || fail "producao mudou"

PROD_15="$(
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
            WHERE version=15;
        "
)"

[[ "$PROD_15" == "0" ]] \
    || fail "migration 015 apareceu em producao"

echo "production_unchanged=PASS"
echo "production_015=ABSENT"

echo
echo "MIMIR-MEMORY-CONTRADICTION-LAB: PASS"
