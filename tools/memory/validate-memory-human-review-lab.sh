#!/bin/bash
set -euo pipefail
umask 077

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="${DB:-mimir_memory}"
PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"

DATA="$LAB_ROOT/data"
PG_IDENT="$DATA/pg_ident.conf"

HUMAN_OS_USER="nogueiramaier"
HUMAN_DB_ROLE="mimir_human"
REVIEW_ROLE="mimir_reviewer"
EXPECTED_SYSTEM_USER="peer:nogueiramaier"
EXPECTED_REVIEWER="Nogueira Maier"

EVENT_APPROVE="96666666-6666-4666-8666-666666666661"
EVENT_REJECT="96666666-6666-4666-8666-666666666662"
EVENT_CONFLICT="96666666-6666-4666-8666-666666666663"

KEY_APPROVE="lab.review.primary"
KEY_REJECT="lab.review.rejected"

CONTENT_APPROVE="Synthetic approved human-review memory."
CONTENT_REJECT="Synthetic rejected human-review memory."
CONTENT_CONFLICT="Synthetic conflicting human-review memory."

ACTOR="mimir-human-review-lab"

TMP=""
IDENT_BACKUP=""

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    RC=$?

    trap - EXIT INT TERM
    set +e

    echo
    echo "=== CLEANUP HUMAN REVIEW LAB ==="

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
        -v ON_ERROR_STOP=1 \
        -v ea="$EVENT_APPROVE" \
        -v er="$EVENT_REJECT" \
        -v ec="$EVENT_CONFLICT" \
        -v actor="$ACTOR" >/dev/null <<'SQL'
BEGIN;

DELETE FROM mimir.memory_audit
WHERE actor = :'actor'
   OR object_id IN (
       SELECT memory_id
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ec'::uuid
       )
   );

DELETE FROM mimir.memory_reviews
WHERE memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ec'::uuid
    )
);

DELETE FROM mimir.memory_relations
WHERE from_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ec'::uuid
    )
)
OR to_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ec'::uuid
    )
);

DELETE FROM mimir.memory_records
WHERE source_event_id IN (
    :'ea'::uuid,
    :'er'::uuid,
    :'ec'::uuid
);

DELETE FROM mimir.memory_events
WHERE event_id IN (
    :'ea'::uuid,
    :'er'::uuid,
    :'ec'::uuid
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
            -v ea="$EVENT_APPROVE" \
            -v er="$EVENT_REJECT" \
            -v ec="$EVENT_CONFLICT" \
            -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ec'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ec'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor = :'actor');
SQL
    )"

    echo "synthetic_residue=${RESIDUE:-unknown}"

    [[ "${RESIDUE:-unknown}" == "0" ]] || {
        echo "FAIL: cleanup deixou residuo sintetico" >&2
        exit 1
    }

    [[ -z "${TMP:-}" ]] || rm -rf -- "$TMP"

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
        -qAt \
        -v ON_ERROR_STOP=1 \
        -v eid="$event_id" \
        -v mkey="$memory_key" \
        -v mcontent="$content" <<'SQL'
SELECT mimir.propose_memory(
    :'eid'::uuid,
    :'mkey',
    'preference',
    'Human review LAB',
    'Synthetic authenticated human review',
    :'mcontent',
    0.850,
    0.600,
    false,
    '{"synthetic":true,"lab":"human-review"}'::jsonb,
    'mimir-human-review-lab'
)::text;
SQL
}

review() {
    local memory_id="$1"
    local decision="$2"
    local reason="$3"

    runuser -u "$HUMAN_OS_USER" -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U "$HUMAN_DB_ROLE" \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -v mid="$memory_id" \
        -v decision="$decision" \
        -v reason="$reason" <<'SQL'
BEGIN;
SET LOCAL ROLE mimir_reviewer;

SELECT mimir.review_memory(
    :'mid'::uuid,
    :'decision',
    nullif(:'reason', ''),
    '{"synthetic":true,"lab":"human-review"}'::jsonb
)::text;

COMMIT;
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
[[ -s "$PG_IDENT" ]] \
    || fail "pg_ident.conf do LAB ausente"
id "$HUMAN_OS_USER" >/dev/null 2>&1 \
    || fail "usuario Linux humano ausente"

echo "=== MIMIR AUTHENTICATED HUMAN REVIEW / LAB ==="

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

[[ "$LAB_DATA" == "$DATA" ]] \
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

[[ "$LAB_VERSIONS" == \
   "1,2,3,4,5,6,7,8,9,10,11,12,14,15" ]] \
    || fail "schema LAB inesperado: $LAB_VERSIONS"

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
    || fail "producao saiu de 1..12"

echo "lab_versions=$LAB_VERSIONS"
echo "production_versions=$PROD_VERSIONS"
echo "environment_guard=PASS"

echo
echo "--- 2. REVIEWER CONTRACT ---"

REVIEWER_CONTRACT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 <<'SQL'
SELECT
    db_role::text
    || '|'
    || display_name
    || '|'
    || expected_system_user
    || '|'
    || enabled::text
FROM mimir.reviewer_identities
WHERE db_role='mimir_human';
SQL
)"

[[ "$REVIEWER_CONTRACT" == \
   "mimir_human|Nogueira Maier|peer:nogueiramaier|true" ]] \
    || fail "reviewer identity inesperada: $REVIEWER_CONTRACT"

ROLE_CONTRACT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 <<'SQL'
SELECT
    (SELECT rolcanlogin
     FROM pg_roles
     WHERE rolname='mimir_human')
    AND NOT
    (SELECT rolinherit
     FROM pg_roles
     WHERE rolname='mimir_human')
    AND pg_has_role(
        'mimir_human',
        'mimir_reviewer',
        'SET'
    );
SQL
)"

[[ "$ROLE_CONTRACT" == "t" ]] \
    || fail "role contract de revisao invalido"

echo "reviewer_identity_contract=PASS"
echo "reviewer_role_contract=PASS"

echo
echo "--- 3. TEMPORARY LAB PEER MAP ---"

runuser -u "$HUMAN_OS_USER" -- test -x "$LAB_ROOT" \
    || fail "$HUMAN_OS_USER nao atravessa LAB_ROOT"

runuser -u "$HUMAN_OS_USER" -- test -x "$PGHOST" \
    || fail "$HUMAN_OS_USER nao atravessa socket dir"

TMP="$(mktemp -d /var/tmp/mimir-human-review-lab.XXXXXX)"
IDENT_BACKUP="$TMP/pg_ident.conf.orig"

cp -a "$PG_IDENT" "$IDENT_BACKUP"

if ! grep -Eq \
    '^mimir_lab_map[[:space:]]+nogueiramaier[[:space:]]+mimir_human([[:space:]]|$)' \
    "$PG_IDENT"
then
    printf '%-19s %-17s %s\n' \
        "mimir_lab_map" \
        "nogueiramaier" \
        "mimir_human" \
        >> "$PG_IDENT"
fi

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
    || fail "reload do LAB falhou"

PEER_IDENTITY="$(
    runuser -u "$HUMAN_OS_USER" -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U "$HUMAN_DB_ROLE" \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 <<'SQL'
SELECT
    session_user
    || '|'
    || current_user
    || '|'
    || system_user;
SQL
)"

[[ "$PEER_IDENTITY" == \
   "mimir_human|mimir_human|peer:nogueiramaier" ]] \
    || fail "peer identity inesperada: $PEER_IDENTITY"

ELEVATED_IDENTITY="$(
    runuser -u "$HUMAN_OS_USER" -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U "$HUMAN_DB_ROLE" \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
SET LOCAL ROLE mimir_reviewer;

SELECT
    session_user
    || '|'
    || current_user
    || '|'
    || system_user;

ROLLBACK;
SQL
)"

[[ "$ELEVATED_IDENTITY" == \
   "mimir_human|mimir_reviewer|peer:nogueiramaier" ]] \
    || fail "elevated identity inesperada: $ELEVATED_IDENTITY"

echo "peer_identity=PASS"
echo "reviewer_elevation=PASS"

echo
echo "--- 4. UNAUTHORIZED REVIEW GUARDS ---"

set +e

APP_DIRECT_ERROR="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        2>&1 <<'SQL'
SELECT mimir.review_memory(
    '00000000-0000-4000-8000-000000000001'::uuid,
    'approve',
    NULL,
    '{}'::jsonb
);
SQL
)"
APP_DIRECT_RC=$?

HUMAN_DIRECT_ERROR="$(
    runuser -u "$HUMAN_OS_USER" -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U "$HUMAN_DB_ROLE" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        2>&1 <<'SQL'
SELECT mimir.review_memory(
    '00000000-0000-4000-8000-000000000001'::uuid,
    'approve',
    NULL,
    '{}'::jsonb
);
SQL
)"
HUMAN_DIRECT_RC=$?

set -e

[[ "$APP_DIRECT_RC" -ne 0 ]] \
    || fail "mimir_app executou review_memory"

[[ "$HUMAN_DIRECT_RC" -ne 0 ]] \
    || fail "mimir_human executou sem SET ROLE"

grep -Fqi "permission denied" <<<"$APP_DIRECT_ERROR" \
    || fail "rejeicao de mimir_app inesperada"

grep -Fqi "permission denied" <<<"$HUMAN_DIRECT_ERROR" \
    || fail "rejeicao sem elevacao inesperada"

echo "mimir_app_review_rejection=PASS"
echo "human_without_elevation_rejection=PASS"

echo
echo "--- 5. RESIDUE PRECHECK ---"

PRECOUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v ea="$EVENT_APPROVE" \
        -v er="$EVENT_REJECT" \
        -v ec="$EVENT_CONFLICT" \
        -v actor="$ACTOR" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ec'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ec'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_audit
       WHERE actor=:'actor');
SQL
)"

[[ "$PRECOUNT" == "0" ]] \
    || fail "residuo sintetico anterior detectado"

echo "residue_precheck=PASS"

echo
echo "--- 6. SYNTHETIC SOURCES ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v ea="$EVENT_APPROVE" \
    -v er="$EVENT_REJECT" \
    -v ec="$EVENT_CONFLICT" <<'SQL'
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
    'mimir-human-review-lab',
    'human_review_lab_source',
    'synthetic',
    'lab://human-review/approve',
    'mimir-human-review-lab',
    'internal',
    'Synthetic approve source.',
    '{"synthetic":true}'::jsonb
),
(
    :'er'::uuid,
    'system',
    'mimir-human-review-lab',
    'human_review_lab_source',
    'synthetic',
    'lab://human-review/reject',
    'mimir-human-review-lab',
    'internal',
    'Synthetic reject source.',
    '{"synthetic":true}'::jsonb
),
(
    :'ec'::uuid,
    'system',
    'mimir-human-review-lab',
    'human_review_lab_source',
    'synthetic',
    'lab://human-review/conflict',
    'mimir-human-review-lab',
    'internal',
    'Synthetic conflict source.',
    '{"synthetic":true}'::jsonb
);
SQL

echo "synthetic_sources=PASS"

echo
echo "--- 7. CREATE CANDIDATES ---"

APPROVE_ID="$(
    propose \
        "$EVENT_APPROVE" \
        "$KEY_APPROVE" \
        "$CONTENT_APPROVE"
)"

REJECT_ID="$(
    propose \
        "$EVENT_REJECT" \
        "$KEY_REJECT" \
        "$CONTENT_REJECT"
)"

CONFLICT_ID="$(
    propose \
        "$EVENT_CONFLICT" \
        "$KEY_APPROVE" \
        "$CONTENT_CONFLICT"
)"

[[ -n "$APPROVE_ID" ]] || fail "approve candidate vazio"
[[ -n "$REJECT_ID" ]] || fail "reject candidate vazio"
[[ -n "$CONFLICT_ID" ]] || fail "conflict candidate vazio"

echo "candidate_creation=PASS"

echo
echo "--- 8. HUMAN APPROVE / CANDIDATE -> ACTIVE ---"

APPROVE_REVIEW_ID="$(
    review \
        "$APPROVE_ID" \
        "approve" \
        ""
)"

[[ -n "$APPROVE_REVIEW_ID" ]] \
    || fail "approve review_id vazio"

APPROVE_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$APPROVE_ID" <<'SQL'
SELECT status
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$APPROVE_STATE" == "active" ]] \
    || fail "candidate nao virou active"

echo "candidate_to_active=PASS"

echo
echo "--- 9. APPROVE IDEMPOTENCY ---"

APPROVE_REPLAY_ID="$(
    review \
        "$APPROVE_ID" \
        "approve" \
        ""
)"

[[ "$APPROVE_REPLAY_ID" == "$APPROVE_REVIEW_ID" ]] \
    || fail "approve replay gerou review_id diferente"

echo "approve_idempotency=PASS"

echo
echo "--- 10. HUMAN REJECT ---"

REJECT_REVIEW_ID="$(
    review \
        "$REJECT_ID" \
        "reject" \
        "Synthetic rejection reason"
)"

[[ -n "$REJECT_REVIEW_ID" ]] \
    || fail "reject review_id vazio"

REJECT_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$REJECT_ID" <<'SQL'
SELECT status
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$REJECT_STATE" == "rejected" ]] \
    || fail "candidate nao virou rejected"

REJECT_REPLAY_ID="$(
    review \
        "$REJECT_ID" \
        "reject" \
        "Synthetic rejection reason"
)"

[[ "$REJECT_REPLAY_ID" == "$REJECT_REVIEW_ID" ]] \
    || fail "reject replay gerou review_id diferente"

echo "human_reject=PASS"
echo "reject_idempotency=PASS"

echo
echo "--- 11. OPPOSITE DECISION NEGATIVE TEST ---"

set +e

OPPOSITE_ERROR="$(
    review \
        "$REJECT_ID" \
        "approve" \
        "" \
        2>&1
)"
OPPOSITE_RC=$?

set -e

[[ "$OPPOSITE_RC" -ne 0 ]] \
    || fail "decisao oposta foi aceita"

grep -Fq \
    "memória já revisada com decisão diferente" \
    <<<"$OPPOSITE_ERROR" \
    || fail "erro de decisao oposta inesperado"

echo "opposite_decision_rejection=PASS"

echo
echo "--- 12. ACTIVE-CONFLICT GUARD ---"

CONFLICT_CLASS="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -qAt \
        -v ON_ERROR_STOP=1 \
        -v mid="$CONFLICT_ID" <<'SQL'
SELECT classification
FROM mimir.inspect_candidate_conflict(
    :'mid'::uuid
);
SQL
)"

[[ "$CONFLICT_CLASS" == "contradiction" ]] \
    || fail "candidate conflitante nao foi classificada"

set +e

ACTIVE_CONFLICT_ERROR="$(
    review \
        "$CONFLICT_ID" \
        "approve" \
        "" \
        2>&1
)"
ACTIVE_CONFLICT_RC=$?

set -e

[[ "$ACTIVE_CONFLICT_RC" -ne 0 ]] \
    || fail "segunda memoria active foi permitida"

grep -Fq \
    "já existe memória ativa para a chave" \
    <<<"$ACTIVE_CONFLICT_ERROR" \
    || fail "erro de active conflict inesperado"

CONFLICT_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$CONFLICT_ID" <<'SQL'
SELECT status
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$CONFLICT_STATE" == "candidate" ]] \
    || fail "candidate conflitante mudou de status"

echo "active_conflict_rejection=PASS"
echo "conflicting_candidate_preserved=PASS"

echo
echo "--- 13. PROVENANCE / AUDIT ---"

PROVENANCE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v approve_id="$APPROVE_ID" \
        -v reject_id="$REJECT_ID" <<'SQL'
SELECT
    count(*)
    || '|'
    || count(*) FILTER (
        WHERE reviewer='Nogueira Maier'
          AND reviewer_role='mimir_human'
          AND authentication_identity='peer:nogueiramaier'
    )
FROM mimir.memory_reviews
WHERE memory_id IN (
    :'approve_id'::uuid,
    :'reject_id'::uuid
);
SQL
)"

[[ "$PROVENANCE" == "2|2" ]] \
    || fail "proveniencia de review invalida: $PROVENANCE"

AUDIT_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v approve_id="$APPROVE_ID" \
        -v reject_id="$REJECT_ID" <<'SQL'
SELECT
    count(*)
    || '|'
    || count(*) FILTER (
        WHERE actor='Nogueira Maier'
          AND details->>'reviewer_role'='mimir_human'
          AND details->>'authentication_identity'='peer:nogueiramaier'
    )
FROM mimir.memory_audit
WHERE object_id IN (
    :'approve_id'::uuid,
    :'reject_id'::uuid
)
AND action IN ('approve', 'reject');
SQL
)"

[[ "$AUDIT_STATE" == "2|2" ]] \
    || fail "auditoria de review invalida: $AUDIT_STATE"

REVIEW_COUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v approve_id="$APPROVE_ID" \
        -v reject_id="$REJECT_ID" <<'SQL'
SELECT count(*)
FROM mimir.memory_reviews
WHERE memory_id IN (
    :'approve_id'::uuid,
    :'reject_id'::uuid
);
SQL
)"

[[ "$REVIEW_COUNT" == "2" ]] \
    || fail "idempotencia criou reviews extras"

echo "reviewer_provenance=PASS"
echo "review_audit=PASS"
echo "review_row_idempotency=PASS"

echo
echo "--- 14. FINAL STATE GUARD ---"

FINAL_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v a="$APPROVE_ID" \
        -v r="$REJECT_ID" \
        -v c="$CONFLICT_ID" <<'SQL'
SELECT
    (SELECT status
     FROM mimir.memory_records
     WHERE memory_id=:'a'::uuid)
    || '|'
    ||
    (SELECT status
     FROM mimir.memory_records
     WHERE memory_id=:'r'::uuid)
    || '|'
    ||
    (SELECT status
     FROM mimir.memory_records
     WHERE memory_id=:'c'::uuid)
    || '|'
    ||
    (SELECT count(*)
     FROM mimir.memory_relations
     WHERE from_memory_id IN (
         :'a'::uuid,
         :'r'::uuid,
         :'c'::uuid
     )
        OR to_memory_id IN (
         :'a'::uuid,
         :'r'::uuid,
         :'c'::uuid
     ));
SQL
)"

[[ "$FINAL_STATE" == "active|rejected|candidate|0" ]] \
    || fail "estado final inesperado: $FINAL_STATE"

echo "final_memory_state=PASS"
echo "automatic_relations=0"

echo
echo "--- 15. PRODUCTION GUARD ---"

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
echo "MIMIR-MEMORY-HUMAN-REVIEW-LAB: PASS"
