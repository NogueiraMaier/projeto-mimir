#!/bin/bash
set -euo pipefail
umask 077

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="${DB:-mimir_memory}"
PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"

EVENT_A="93333333-3333-4333-8333-333333333331"
EVENT_B="93333333-3333-4333-8333-333333333332"

KEY_A="lab.dedup.preference"
KEY_B="lab.dedup.preference.other"

CONTENT_A="Synthetic dedup content A."
CONTENT_B="Synthetic dedup content B."

ACTOR="mimir-dedup-lab"

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
        -v event_a="$EVENT_A" \
        -v event_b="$EVENT_B" \
        -v actor="$ACTOR" >/dev/null <<'SQL'
BEGIN;

DELETE FROM mimir.memory_audit
WHERE actor = :'actor'
   OR object_id IN (
       SELECT memory_id
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'event_a'::uuid,
           :'event_b'::uuid
       )
   );

DELETE FROM mimir.memory_reviews
WHERE memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'event_a'::uuid,
        :'event_b'::uuid
    )
);

DELETE FROM mimir.memory_relations
WHERE from_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'event_a'::uuid,
        :'event_b'::uuid
    )
)
OR to_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'event_a'::uuid,
        :'event_b'::uuid
    )
);

DELETE FROM mimir.memory_records
WHERE source_event_id IN (
    :'event_a'::uuid,
    :'event_b'::uuid
);

DELETE FROM mimir.memory_events
WHERE event_id IN (
    :'event_a'::uuid,
    :'event_b'::uuid
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
            -v event_a="$EVENT_A" \
            -v event_b="$EVENT_B" \
            -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'event_a'::uuid,
           :'event_b'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'event_a'::uuid,
           :'event_b'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor = :'actor');
SQL
    )"

    echo "synthetic_residue=${RESIDUE:-unknown}"

    if [[ "${RESIDUE:-unknown}" != "0" ]]; then
        echo "FAIL: cleanup deixou residuo sintetico" >&2
        exit 1
    fi

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
    'Deduplication LAB',
    'Synthetic deduplication validation',
    :'mcontent',
    0.800,
    0.500,
    false,
    '{"lab":"deduplication","synthetic":true}'::jsonb,
    'mimir-dedup-lab'
)::text;
SQL
}

trap cleanup EXIT INT TERM

[[ $EUID -eq 0 ]] || fail "execute como root"
[[ "$LAB_ROOT" == /var/tmp/mimir-* ]] \
    || fail "LAB_ROOT fora de /var/tmp/mimir-*"
[[ "$PGHOST" == "$LAB_ROOT/socket" ]] \
    || fail "socket fora do LAB_ROOT"
[[ "$PGPORT" != "5432" ]] \
    || fail "porta de producao recusada"
[[ "$PGHOST" != "/run/postgresql" ]] \
    || fail "socket de producao recusado"
[[ -S "$PGHOST/.s.PGSQL.$PGPORT" ]] \
    || fail "socket do LAB ausente"

echo "=== MIMIR MEMORY DEDUPLICATION / LAB ==="

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

LAB_VERSIONS="$(
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

case "$LAB_VERSIONS" in
    "1,2,3,4,5,6,7,8,9,10,11,12,14"|"1,2,3,4,5,6,7,8,9,10,11,12,14,15")
        ;;
    *)
        fail "schema LAB inesperado: $LAB_VERSIONS"
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

[[ "$PROD_VERSIONS" == "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "producao saiu de 1..12"

DEDUP_INDEX="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "
            SELECT to_regclass(
                'mimir.memory_records_source_key_hash_uq'
            ) IS NOT NULL;
        "
)"

[[ "$DEDUP_INDEX" == "t" ]] \
    || fail "indice de deduplicacao ausente"

echo "lab_versions=$LAB_VERSIONS"
echo "production_versions=$PROD_VERSIONS"
echo "dedup_index=PASS"
echo "environment_guard=PASS"

echo
echo "--- 2. RESIDUE PRECHECK ---"

PRECOUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v event_a="$EVENT_A" \
        -v event_b="$EVENT_B" \
        -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'event_a'::uuid,
           :'event_b'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'event_a'::uuid,
           :'event_b'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor = :'actor');
SQL
)"

[[ "$PRECOUNT" == "0" ]] \
    || fail "residuo sintetico anterior detectado"

echo "residue_precheck=PASS"

echo
echo "--- 3. SYNTHETIC SOURCE EVENTS ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v event_a="$EVENT_A" \
    -v event_b="$EVENT_B" <<'SQL'
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
    :'event_a'::uuid,
    'system',
    'mimir-dedup-lab',
    'dedup_lab_source',
    'synthetic',
    'lab://dedup/source-a',
    'mimir-dedup-lab',
    'internal',
    'Synthetic source A.',
    '{"synthetic":true,"lab":"deduplication"}'::jsonb
),
(
    :'event_b'::uuid,
    'system',
    'mimir-dedup-lab',
    'dedup_lab_source',
    'synthetic',
    'lab://dedup/source-b',
    'mimir-dedup-lab',
    'internal',
    'Synthetic source B.',
    '{"synthetic":true,"lab":"deduplication"}'::jsonb
);
SQL

echo "synthetic_sources=PASS"

echo
echo "--- 4. IDENTICAL PROPOSAL REPLAY ---"

ID_1="$(propose "$EVENT_A" "$KEY_A" "$CONTENT_A")"
ID_1_REPEAT="$(propose "$EVENT_A" "$KEY_A" "$CONTENT_A")"

[[ -n "$ID_1" ]] || fail "primeiro memory_id vazio"
[[ "$ID_1_REPEAT" == "$ID_1" ]] \
    || fail "replay identico retornou memory_id diferente"

IDENTICAL_COUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v eid="$EVENT_A" \
        -v mkey="$KEY_A" \
        -v content="$CONTENT_A" <<'SQL'
SELECT count(*)
FROM mimir.memory_records
WHERE source_event_id=:'eid'::uuid
  AND memory_key=:'mkey'
  AND content_sha256=encode(
      public.digest(
          convert_to(:'content', 'UTF8'),
          'sha256'
      ),
      'hex'
  );
SQL
)"

[[ "$IDENTICAL_COUNT" == "1" ]] \
    || fail "replay identico criou duplicata"

echo "identical_replay_same_id=PASS"
echo "identical_record_count=1"

echo
echo "--- 5. SAME SOURCE / SAME KEY / DIFFERENT CONTENT ---"

ID_2="$(propose "$EVENT_A" "$KEY_A" "$CONTENT_B")"

[[ "$ID_2" != "$ID_1" ]] \
    || fail "conteudo diferente foi colapsado incorretamente"

SAME_SOURCE_COUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v eid="$EVENT_A" \
        -v mkey="$KEY_A" <<'SQL'
SELECT count(*)
FROM mimir.memory_records
WHERE source_event_id=:'eid'::uuid
  AND memory_key=:'mkey';
SQL
)"

[[ "$SAME_SOURCE_COUNT" == "2" ]] \
    || fail "conteudos distintos nao geraram dois candidatos"

echo "different_content_distinct=PASS"

echo
echo "--- 6. DIFFERENT SOURCE / SAME KEY / SAME CONTENT ---"

ID_3="$(propose "$EVENT_B" "$KEY_A" "$CONTENT_A")"

[[ "$ID_3" != "$ID_1" ]] \
    || fail "fontes diferentes foram colapsadas incorretamente"

echo "different_source_distinct=PASS"

echo
echo "--- 7. SAME SOURCE / DIFFERENT KEY / SAME CONTENT ---"

ID_4="$(propose "$EVENT_A" "$KEY_B" "$CONTENT_A")"

[[ "$ID_4" != "$ID_1" ]] \
    || fail "memory_key diferente foi colapsada incorretamente"

echo "different_key_distinct=PASS"

echo
echo "--- 8. AUDIT / CANDIDATE STATE ---"

STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v event_a="$EVENT_A" \
        -v event_b="$EVENT_B" \
        -v actor="$ACTOR" <<'SQL'
SELECT
    (SELECT count(*)
     FROM mimir.memory_records
     WHERE source_event_id IN (
         :'event_a'::uuid,
         :'event_b'::uuid
     ))
    || '|'
    ||
    (SELECT count(*)
     FROM mimir.memory_records
     WHERE source_event_id IN (
         :'event_a'::uuid,
         :'event_b'::uuid
     )
       AND status='candidate')
    || '|'
    ||
    (SELECT count(*)
     FROM mimir.memory_audit
     WHERE actor=:'actor'
       AND action='propose'
       AND object_type='memory_record');
SQL
)"

IFS='|' read -r RECORDS CANDIDATES AUDITS <<<"$STATE"

[[ "$RECORDS" == "4" ]] \
    || fail "quantidade total inesperada: $RECORDS"

[[ "$CANDIDATES" == "4" ]] \
    || fail "houve promocao automatica inesperada"

[[ "$AUDITS" == "4" ]] \
    || fail "auditoria duplicada ou ausente: $AUDITS"

echo "candidate_records=4"
echo "automatic_promotion=0"
echo "audit_propose_records=4"
echo "audit_idempotency=PASS"

echo
echo "--- 9. DUPLICATE GROUP GUARD ---"

DUP_GROUPS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v event_a="$EVENT_A" \
        -v event_b="$EVENT_B" <<'SQL'
SELECT count(*)
FROM (
    SELECT
        source_event_id,
        memory_key,
        content_sha256,
        count(*) AS n
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'event_a'::uuid,
        :'event_b'::uuid
    )
    GROUP BY
        source_event_id,
        memory_key,
        content_sha256
    HAVING count(*) > 1
) AS duplicates;
SQL
)"

[[ "$DUP_GROUPS" == "0" ]] \
    || fail "grupo duplicado encontrado"

echo "duplicate_groups=0"

echo
echo "--- 10. FINAL PRODUCTION GUARD ---"

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
    || fail "producao mudou durante o LAB"

echo "production_unchanged=PASS"

echo
echo "MIMIR-MEMORY-DEDUPLICATION-LAB: PASS"
