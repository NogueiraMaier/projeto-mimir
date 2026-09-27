#!/bin/bash
set -euo pipefail

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="mimir_memory"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPTURE="$ROOT_DIR/tools/memory/mimir-capture-sessions-v2.py"
WRITER="$ROOT_DIR/tools/memory/mimir-ingest-session-v2.py"
PSQL="/usr/lib64/postgresql-17/bin/psql"
PYTHON="/usr/bin/python3"

SESSION_ID="91111111-1111-4111-8111-111111111111"
SESSION_KEY="agent:main:hud:writer-v2-lab"
USER_TEXT="Pergunta sintetica writer v2 LAB."
ASSISTANT_TEXT="Resposta sintetica writer v2 LAB."

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || fail "execute como root"
[[ "$LAB_ROOT" == /var/tmp/mimir-* ]] || fail "LAB_ROOT fora de /var/tmp/mimir-*"
[[ "$PGHOST" == "$LAB_ROOT/socket" ]] || fail "socket fora do LAB_ROOT"
[[ "$PGPORT" != "5432" ]] || fail "porta de produção recusada"
[[ "$PGHOST" != "/run/postgresql" ]] || fail "socket de produção recusado"
[[ -S "$PGHOST/.s.PGSQL.$PGPORT" ]] || fail "socket do lab ausente"
[[ -s "$CAPTURE" ]] || fail "capturador v2 ausente"
[[ -s "$WRITER" ]] || fail "writer v2 ausente"

echo "=== MIMIR SESSION WRITER V2 / LAB VALIDATION ==="

echo
echo "--- 1. lab and production guards ---"

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
    || fail "data_directory inesperado: $LAB_DATA"

LAB_VERSIONS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -c "SELECT string_agg(version::text, ',' ORDER BY version) FROM mimir.schema_version;"
)"

[[ "$LAB_VERSIONS" == "1,2,3,4,5,6,7,8,9,10,11,12,14" ]] \
    || fail "lab não está em 1..12,14"

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

[[ "$PROD_VERSIONS" == "1,2,3,4,5,6,7,8,9,10,11,12" ]] \
    || fail "produção saiu de 1..12"

echo "lab_versions=$LAB_VERSIONS"
echo "production_versions=$PROD_VERSIONS"
echo "environment_guard=PASS"

echo
echo "--- 2. synthetic fixture ---"

TMP="$(mktemp -d /var/tmp/mimir-writer-v2-lab.XXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT

chown openclaw:openclaw "$TMP"
chmod 0700 "$TMP"

FIXTURE="$TMP/fixture.json"
FAKE="$TMP/fake_openclaw.py"

cat > "$FIXTURE" <<EOF
{
  "sessions": {
    "path": "/state/openclaw-agent.sqlite",
    "sessions": [
      {
        "key": "$SESSION_KEY",
        "sessionId": "$SESSION_ID",
        "status": "done",
        "updatedAt": 1790400000000
      }
    ]
  },
  "history": {
    "$SESSION_KEY": {
      "0": {
        "sessionKey": "$SESSION_KEY",
        "sessionId": "$SESSION_ID",
        "messages": [
          {
            "role": "user",
            "content": "$USER_TEXT",
            "timestamp": 1790400001000,
            "__openclaw": {
              "id": "u1",
              "seq": 1,
              "recordTimestampMs": 1790400001000,
              "senderIsOwner": true,
              "senderId": "operator",
              "transport": "lab",
              "transcriptPosition": 1
            }
          },
          {
            "role": "assistant",
            "content": [
              {
                "type": "thinking",
                "thinking": "synthetic internal thought"
              },
              {
                "type": "text",
                "text": "$ASSISTANT_TEXT"
              },
              {
                "type": "toolCall",
                "name": "synthetic_tool",
                "arguments": {"x": 1}
              }
            ],
            "timestamp": 1790400002000,
            "__openclaw": {
              "id": "a1",
              "seq": 2,
              "recordTimestampMs": 1790400002000,
              "transcriptPosition": 2
            }
          }
        ],
        "hasMore": false,
        "totalMessages": 2,
        "deltaCursor": "synthetic"
      }
    }
  }
}
EOF

cat > "$FAKE" <<'PY'
import json
import os
import sys

with open(
    os.environ["MIMIR_FAKE_OPENCLAW_FIXTURE"],
    encoding="utf-8",
) as stream:
    fixture = json.load(stream)

args = sys.argv[1:]

if args and args[0] == "sessions":
    print(json.dumps(fixture["sessions"]))
    raise SystemExit(0)

if args[:3] == ["gateway", "call", "chat.history"]:
    params = json.loads(args[args.index("--params") + 1])
    key = params["sessionKey"]
    offset = str(params.get("offset", 0))
    print(json.dumps(fixture["history"][key][offset]))
    raise SystemExit(0)

raise SystemExit(3)
PY

chown openclaw:openclaw "$FIXTURE" "$FAKE"
chmod 0600 "$FIXTURE" "$FAKE"

echo "fixture=PASS"

echo
echo "--- 3. residue precheck ---"

PRECOUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v sid="$SESSION_ID" <<'SQL'
SELECT
    (SELECT count(*)
     FROM mimir.session_sources
     WHERE session_id=:'sid'::uuid)
    +
    (SELECT count(*)
     FROM mimir.memory_events
     WHERE source_ref=
        'openclaw://agent/main/session/' || :'sid');
SQL
)"

[[ "$PRECOUNT" == "0" ]] || fail "sessão sintética já existe no lab"

echo "residue_precheck=PASS"

echo
echo "--- 4. capture metadata only ---"

CAPTURE_JSON="$(
    runuser -u openclaw -- \
    env MIMIR_FAKE_OPENCLAW_FIXTURE="$FIXTURE" \
    "$PYTHON" "$CAPTURE" \
        --node-bin "$PYTHON" \
        --openclaw-entry "$FAKE"
)"

if grep -Fq "$USER_TEXT" <<<"$CAPTURE_JSON" \
   || grep -Fq "$ASSISTANT_TEXT" <<<"$CAPTURE_JSON"
then
    fail "capturador expôs conteúdo"
fi

SOURCE_SHA="$(
    "$PYTHON" -c '
import json,sys
d=json.load(sys.stdin)
x=d["sessions"][0]
assert x["capture_status"]=="ready"
print(x["source_fingerprint_sha256"])
' <<<"$CAPTURE_JSON"
)"

CONTENT_SHA="$(
    "$PYTHON" -c '
import json,sys
d=json.load(sys.stdin)
print(d["sessions"][0]["content_sha256"])
' <<<"$CAPTURE_JSON"
)"

echo "capture_metadata=PASS"

echo
echo "--- 5. writer dry-run ---"

DRY_JSON="$(
    runuser -u openclaw -- \
    env MIMIR_FAKE_OPENCLAW_FIXTURE="$FIXTURE" \
    "$PYTHON" "$WRITER" \
        --session-key "$SESSION_KEY" \
        --session-id "$SESSION_ID" \
        --expected-source-sha256 "$SOURCE_SHA" \
        --expected-content-sha256 "$CONTENT_SHA" \
        --node-bin "$PYTHON" \
        --openclaw-entry "$FAKE"
)"

if grep -Fq "$USER_TEXT" <<<"$DRY_JSON" \
   || grep -Fq "$ASSISTANT_TEXT" <<<"$DRY_JSON"
then
    fail "writer dry-run expôs conteúdo"
fi

APPROVAL="$(
    "$PYTHON" -c '
import json,sys
d=json.load(sys.stdin)
assert d["mode"]=="dry-run"
assert d["database_write"] is False
assert d["content_exposed"] is False
assert d["memory_promotion"] is False
print(d["approval_sha256"])
' <<<"$DRY_JSON"
)"

echo "writer_dry_run=PASS"
echo "approval_sha256=$APPROVAL"

echo
echo "--- 6. controlled writer commit to lab ---"

WRITE_JSON="$(
    runuser -u openclaw -- \
    env MIMIR_FAKE_OPENCLAW_FIXTURE="$FIXTURE" \
    "$PYTHON" "$WRITER" \
        --session-key "$SESSION_KEY" \
        --session-id "$SESSION_ID" \
        --expected-source-sha256 "$SOURCE_SHA" \
        --expected-content-sha256 "$CONTENT_SHA" \
        --node-bin "$PYTHON" \
        --openclaw-entry "$FAKE" \
        --write \
        --approve "$APPROVAL" \
        --pg-host "$PGHOST" \
        --pg-port "$PGPORT"
)"

if grep -Fq "$USER_TEXT" <<<"$WRITE_JSON" \
   || grep -Fq "$ASSISTANT_TEXT" <<<"$WRITE_JSON"
then
    fail "writer write expôs conteúdo"
fi

EVENT_ID="$(
    "$PYTHON" -c '
import json,sys
d=json.load(sys.stdin)
assert d["mode"]=="write"
assert d["database_write"] is True
assert d["content_exposed"] is False
assert d["memory_promotion"] is False
assert d["event_id"]
print(d["event_id"])
' <<<"$WRITE_JSON"
)"

echo "writer_commit=PASS"
echo "event_id=$EVENT_ID"

echo
echo "--- 7. idempotent replay ---"

REPLAY_JSON="$(
    runuser -u openclaw -- \
    env MIMIR_FAKE_OPENCLAW_FIXTURE="$FIXTURE" \
    "$PYTHON" "$WRITER" \
        --session-key "$SESSION_KEY" \
        --session-id "$SESSION_ID" \
        --expected-source-sha256 "$SOURCE_SHA" \
        --expected-content-sha256 "$CONTENT_SHA" \
        --node-bin "$PYTHON" \
        --openclaw-entry "$FAKE" \
        --write \
        --approve "$APPROVAL" \
        --pg-host "$PGHOST" \
        --pg-port "$PGPORT"
)"

REPLAY_EVENT="$(
    "$PYTHON" -c '
import json,sys
print(json.load(sys.stdin)["event_id"])
' <<<"$REPLAY_JSON"
)"

[[ "$REPLAY_EVENT" == "$EVENT_ID" ]] || fail "replay não foi idempotente"

echo "writer_idempotency=PASS"

echo
echo "--- 8. persisted-state verification ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v sid="$SESSION_ID" \
    -v eid="$EVENT_ID" \
    -v skey="$SESSION_KEY" \
    -v sfp="$SOURCE_SHA" \
    -v csha="$CONTENT_SHA" \
    -At <<'SQL'
SELECT 'source_ok=' || (
    SELECT
        source_kind='openclaw-chat-history-v2'
        AND source_key=:'skey'
        AND source_fingerprint_sha256=:'sfp'
        AND content_sha256=:'csha'
    FROM mimir.session_sources
    WHERE session_id=:'sid'::uuid
);

SELECT 'event_ok=' || (
    SELECT
        event_type='session_import'
        AND classification='confidential'
        AND content IS NULL
        AND content_sha256 IS NULL
        AND payload->>'protected_source'='true'
        AND payload->>'content_exposed'='false'
    FROM mimir.memory_events
    WHERE event_id=:'eid'::uuid
);

SELECT 'automatic_records=' || count(*)
FROM mimir.memory_records
WHERE source_event_id=:'eid'::uuid;
SQL

STATE_GUARD="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v sid="$SESSION_ID" \
        -v eid="$EVENT_ID" <<'SQL'
SELECT
    EXISTS (
        SELECT 1
        FROM mimir.session_sources
        WHERE session_id=:'sid'::uuid
          AND event_id=:'eid'::uuid
    )
    AND EXISTS (
        SELECT 1
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
          AND classification='confidential'
          AND content IS NULL
    )
    AND NOT EXISTS (
        SELECT 1
        FROM mimir.memory_records
        WHERE source_event_id=:'eid'::uuid
    );
SQL
)"

[[ "$STATE_GUARD" == "t" ]] || fail "estado persistido inválido"

echo "persisted_state=PASS"

echo
echo "--- 9. protected read path ---"

PROTECTED_OK="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_app \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v eid="$EVENT_ID" \
        -v csha="$CONTENT_SHA" <<'SQL'
SELECT
    (mimir.read_consolidation_source(:'eid'::uuid)
        ->> 'source_kind') = 'openclaw-chat-history-v2'
    AND encode(
        public.digest(
            convert_to(
                mimir.read_consolidation_source(:'eid'::uuid)
                    ->> 'content',
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    ) = :'csha';
SQL
)"

[[ "$PROTECTED_OK" == "t" ]] || fail "protected read inválido"

echo "protected_read=PASS"

echo
echo "--- 10. synthetic cleanup ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v sid="$SESSION_ID" \
    -v eid="$EVENT_ID" <<'SQL'
BEGIN;
DELETE FROM mimir.session_sources
WHERE session_id=:'sid'::uuid
  AND event_id=:'eid'::uuid;

DELETE FROM mimir.memory_events
WHERE event_id=:'eid'::uuid;
COMMIT;
SQL

POSTCOUNT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v sid="$SESSION_ID" \
        -v eid="$EVENT_ID" <<'SQL'
SELECT
    (SELECT count(*)
     FROM mimir.session_sources
     WHERE session_id=:'sid'::uuid)
    +
    (SELECT count(*)
     FROM mimir.memory_events
     WHERE event_id=:'eid'::uuid)
    +
    (SELECT count(*)
     FROM mimir.memory_records
     WHERE source_event_id=:'eid'::uuid);
SQL
)"

[[ "$POSTCOUNT" == "0" ]] || fail "resíduo sintético após cleanup"

echo "synthetic_cleanup=PASS"

echo
echo "--- 11. final production guard ---"

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

[[ "$PROD_AFTER" == "$PROD_VERSIONS" ]] || fail "produção mudou"

echo "production_unchanged=PASS"
echo
echo "=== MIMIR SESSION WRITER V2 LAB: PASS ==="
