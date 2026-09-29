#!/bin/bash
set -euo pipefail
umask 077

LAB_ROOT="${MIMIR_LAB_ROOT:-/var/tmp/mimir-pg14-lab}"
PGHOST="${PGHOST:-$LAB_ROOT/socket}"
PGPORT="${PGPORT:-55433}"
DB="${DB:-mimir_memory}"
DATA="$LAB_ROOT/data"
PG_IDENT="$DATA/pg_ident.conf"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GENERATOR="$ROOT_DIR/tools/memory/mimir-generate-embeddings.mjs"
SEARCH="$ROOT_DIR/tools/memory/mimir-semantic-search.mjs"

PSQL="${PSQL:-/usr/lib64/postgresql-17/bin/psql}"
NODE="${NODE:-/usr/bin/node}"

MODEL_PATH="/var/lib/openclaw/.node-llama-cpp/models/hf_ggml-org_embeddinggemma-300m-qat-Q8_0.gguf"
MODEL_ID="hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf"

HUMAN_OS_USER="nogueiramaier"
LAB_ACCESS_GROUP="$(id -gn openclaw)"

EVENT_ACTIVE="97777777-7777-4777-8777-777777777771"
EVENT_REJECT="97777777-7777-4777-8777-777777777772"
EVENT_PENDING="97777777-7777-4777-8777-777777777773"

KEY_ACTIVE="lab.semantic.maintenance-window"
KEY_REJECT="lab.semantic.rejected"
KEY_PENDING="lab.semantic.pending"

CONTENT_ACTIVE="Memoria sintetica de laboratorio: o codigo Aurora-Lotus-731 identifica a janela de manutencao semantica das 03:17."
CONTENT_REJECT="Memoria sintetica rejeitada: o codigo descartado e Nebula-999."
CONTENT_PENDING="Memoria sintetica ainda candidata: o codigo pendente e Delta-555."

QUERY_TEXT="Qual codigo identifica a janela de manutencao semantica das 03:17?"

ACTOR="mimir-embedding-semantic-lab"

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
    echo "=== CLEANUP EMBEDDING/SEMANTIC LAB ==="

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
        -v ea="$EVENT_ACTIVE" \
        -v er="$EVENT_REJECT" \
        -v ep="$EVENT_PENDING" \
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
           :'ep'::uuid
       )
   );

DELETE FROM mimir.memory_reviews
WHERE memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ep'::uuid
    )
);

DELETE FROM mimir.memory_relations
WHERE from_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ep'::uuid
    )
)
OR to_memory_id IN (
    SELECT memory_id
    FROM mimir.memory_records
    WHERE source_event_id IN (
        :'ea'::uuid,
        :'er'::uuid,
        :'ep'::uuid
    )
);

DELETE FROM mimir.memory_records
WHERE source_event_id IN (
    :'ea'::uuid,
    :'er'::uuid,
    :'ep'::uuid
);

DELETE FROM mimir.memory_events
WHERE event_id IN (
    :'ea'::uuid,
    :'er'::uuid,
    :'ep'::uuid
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
            -v er="$EVENT_REJECT" \
            -v ep="$EVENT_PENDING" <<'SQL'
SELECT
      (SELECT count(*)
       FROM mimir.memory_events
       WHERE event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ep'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_records
       WHERE source_event_id IN (
           :'ea'::uuid,
           :'er'::uuid,
           :'ep'::uuid
       ))
    + (SELECT count(*)
       FROM mimir.memory_reviews
       WHERE memory_id IN (
           SELECT memory_id
           FROM mimir.memory_records
           WHERE source_event_id IN (
               :'ea'::uuid,
               :'er'::uuid,
               :'ep'::uuid
           )
       ));
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

propose() {
    local event_id="$1"
    local key="$2"
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
        -v mkey="$key" \
        -v mcontent="$content" <<'SQL'
SELECT mimir.propose_memory(
    :'eid'::uuid,
    :'mkey',
    'semantic',
    'Embedding Semantic LAB',
    'Synthetic semantic retrieval validation',
    :'mcontent',
    0.900,
    0.700,
    false,
    '{"synthetic":true,"lab":"embedding-semantic"}'::jsonb,
    'mimir-embedding-semantic-lab'
)::text;
SQL
}

review() {
    local memory_id="$1"
    local decision="$2"
    local reason="$3"

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
        -v mid="$memory_id" \
        -v decision="$decision" \
        -v reason="$reason" <<'SQL'
BEGIN;
SET LOCAL ROLE mimir_reviewer;

SELECT mimir.review_memory(
    :'mid'::uuid,
    :'decision',
    nullif(:'reason', ''),
    '{"synthetic":true,"lab":"embedding-semantic"}'::jsonb
)::text;

COMMIT;
SQL
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
    || fail "socket do LAB ausente"
[[ -s "$PG_IDENT" ]] \
    || fail "pg_ident.conf ausente"
[[ -x "$NODE" ]] \
    || fail "node ausente: $NODE"
[[ -s "$GENERATOR" ]] \
    || fail "gerador de embeddings ausente"
[[ -s "$SEARCH" ]] \
    || fail "semantic search ausente"
[[ -s "$MODEL_PATH" ]] \
    || fail "EmbeddingGemma ausente"

echo "=== MIMIR EMBEDDING + SEMANTIC RECOVERY / LAB ==="

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
    || fail "data_directory inesperado: $LAB_DATA"

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
    || fail "producao fora de 1..12"

echo "lab_versions=$LAB_VERSIONS"
echo "production_versions=$PROD_VERSIONS"
echo "environment_guard=PASS"

echo
echo "--- 2. TEMPORARY PEER MAPS ---"

TMP="$(mktemp -d /var/tmp/mimir-embedding-semantic.XXXXXX)"
IDENT_BACKUP="$TMP/pg_ident.conf.orig"

cp -a "$PG_IDENT" "$IDENT_BACKUP"

for ENTRY in \
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

[[ "$RELOAD" == "t" ]] || fail "reload falhou"

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

[[ "$EMBED_IDENTITY" == \
   "mimir_embedder|peer:openclaw" ]] \
    || fail "identidade embedder invalida: $EMBED_IDENTITY"

[[ "$SEARCH_IDENTITY" == \
   "mimir_search|peer:openclaw" ]] \
    || fail "identidade search invalida: $SEARCH_IDENTITY"

echo "embedder_peer_identity=PASS"
echo "search_peer_identity=PASS"

echo
echo "--- 3. SYNTHETIC SOURCES ---"

runuser -u postgres -- "$PSQL" \
    -X -w \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -d "$DB" \
    -v ON_ERROR_STOP=1 \
    -v ea="$EVENT_ACTIVE" \
    -v er="$EVENT_REJECT" \
    -v ep="$EVENT_PENDING" <<'SQL'
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
    'mimir',
    'embedding_lab_source',
    'synthetic',
    'lab://embedding-semantic/active',
    'mimir-embedding-semantic-lab',
    'internal',
    'Synthetic active semantic source.',
    '{"synthetic":true}'::jsonb
),
(
    :'er'::uuid,
    'system',
    'mimir',
    'embedding_lab_source',
    'synthetic',
    'lab://embedding-semantic/rejected',
    'mimir-embedding-semantic-lab',
    'internal',
    'Synthetic rejected semantic source.',
    '{"synthetic":true}'::jsonb
),
(
    :'ep'::uuid,
    'system',
    'mimir',
    'embedding_lab_source',
    'synthetic',
    'lab://embedding-semantic/pending',
    'mimir-embedding-semantic-lab',
    'internal',
    'Synthetic pending semantic source.',
    '{"synthetic":true}'::jsonb
);
SQL

ACTIVE_ID="$(propose "$EVENT_ACTIVE" "$KEY_ACTIVE" "$CONTENT_ACTIVE")"
REJECT_ID="$(propose "$EVENT_REJECT" "$KEY_REJECT" "$CONTENT_REJECT")"
PENDING_ID="$(propose "$EVENT_PENDING" "$KEY_PENDING" "$CONTENT_PENDING")"

[[ -n "$ACTIVE_ID" ]] || fail "active candidate vazio"
[[ -n "$REJECT_ID" ]] || fail "reject candidate vazio"
[[ -n "$PENDING_ID" ]] || fail "pending candidate vazio"

echo "candidate_creation=PASS"

echo
echo "--- 4. HUMAN PROMOTION / REJECTION ---"

review "$ACTIVE_ID" "approve" "" >/dev/null
review "$REJECT_ID" "reject" "Synthetic semantic reject" >/dev/null

STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v a="$ACTIVE_ID" \
        -v r="$REJECT_ID" \
        -v p="$PENDING_ID" <<'SQL'
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
     WHERE memory_id=:'p'::uuid);
SQL
)"

[[ "$STATE" == "active|rejected|candidate" ]] \
    || fail "estado de review inesperado: $STATE"

echo "human_promotion_state=PASS"

echo
echo "--- 5. EMBEDDING ELIGIBILITY ---"

PENDING_EMBEDDINGS="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v a="$ACTIVE_ID" \
        -v r="$REJECT_ID" \
        -v p="$PENDING_ID" <<'SQL'
SELECT
    count(*)
    || '|'
    ||
    count(*) FILTER (WHERE memory_id=:'a'::uuid)
    || '|'
    ||
    count(*) FILTER (WHERE memory_id=:'r'::uuid)
    || '|'
    ||
    count(*) FILTER (WHERE memory_id=:'p'::uuid)
FROM mimir.pending_embeddings
WHERE memory_id IN (
    :'a'::uuid,
    :'r'::uuid,
    :'p'::uuid
);
SQL
)"

[[ "$PENDING_EMBEDDINGS" == "1|1|0|0" ]] \
    || fail "eligibilidade inesperada: $PENDING_EMBEDDINGS"

echo "active_only_embedding_eligibility=PASS"

echo
echo "--- 6. REAL EMBEDDING DRY-RUN ---"

EMBED_DRY="$(
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_embedder \
        PGAPPNAME=mimir-embedding-lab-dry \
        "$NODE" "$GENERATOR" \
        --limit 10
)"

grep -Fq "Pendentes selecionados: 1" <<<"$EMBED_DRY" \
    || fail "dry-run nao selecionou exatamente uma memoria"

grep -Fq "Embeddings gerados: 1" <<<"$EMBED_DRY" \
    || fail "dry-run nao gerou embedding"

grep -Fq "Banco: não alterado" <<<"$EMBED_DRY" \
    || fail "dry-run tentou alterar banco"

DRY_DB="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" <<'SQL'
SELECT embedding IS NULL
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

[[ "$DRY_DB" == "t" ]] \
    || fail "dry-run gravou embedding"

echo "real_embedding_dry_run=PASS"

echo
echo "--- 7. REAL EMBEDDING CONTROLLED WRITE ---"

EMBED_WRITE="$(
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        PGHOST="$PGHOST" \
        PGPORT="$PGPORT" \
        PGDATABASE="$DB" \
        PGUSER=mimir_embedder \
        PGAPPNAME=mimir-embedding-lab-write \
        "$NODE" "$GENERATOR" \
        --limit 10 \
        --write
)"

grep -Fq "Embeddings gerados: 1" <<<"$EMBED_WRITE" \
    || fail "write nao gerou exatamente um embedding"

grep -Fq "Embeddings gravados: 1" <<<"$EMBED_WRITE" \
    || fail "write nao gravou exatamente um embedding"

EMBED_STATE="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v a="$ACTIVE_ID" \
        -v r="$REJECT_ID" \
        -v p="$PENDING_ID" \
        -v model="$MODEL_ID" <<'SQL'
SELECT
    (
        SELECT
            embedding IS NOT NULL
            AND public.vector_dims(embedding)=768
            AND abs(public.vector_norm(embedding)-1.0) < 0.0001
            AND embedding_model=:'model'
        FROM mimir.memory_records
        WHERE memory_id=:'a'::uuid
    )
    || '|'
    ||
    (
        SELECT embedding IS NULL
        FROM mimir.memory_records
        WHERE memory_id=:'r'::uuid
    )
    || '|'
    ||
    (
        SELECT embedding IS NULL
        FROM mimir.memory_records
        WHERE memory_id=:'p'::uuid
    );
SQL
)"

[[ "$EMBED_STATE" == "t|t|t" ]] \
    || fail "estado de embedding invalido: $EMBED_STATE"

echo "embedding_768d=PASS"
echo "embedding_normalized=PASS"
echo "rejected_candidate_unembedded=PASS"

echo
echo "--- 8. CONTENT SHA GUARD ---"

STORED_VECTOR="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" <<'SQL'
SELECT embedding::text
FROM mimir.memory_records
WHERE memory_id=:'mid'::uuid;
SQL
)"

set +e

SHA_ERROR="$(
    runuser -u openclaw -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -U mimir_embedder \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" \
        -v vector="$STORED_VECTOR" \
        -v model="$MODEL_ID" \
        2>&1 <<'SQL'
SELECT mimir.store_memory_embedding(
    :'mid'::uuid,
    repeat('0', 64),
    :'vector'::public.vector,
    :'model'
);
SQL
)"
SHA_RC=$?

set -e

[[ "$SHA_RC" -ne 0 ]] \
    || fail "SHA incorreto foi aceito"

grep -Fq \
    "conteúdo alterado desde a geração do embedding" \
    <<<"$SHA_ERROR" \
    || fail "rejeicao de SHA inesperada"

echo "content_sha_guard=PASS"

echo
echo "--- 9. EMBEDDING AUDIT ---"

EMBED_AUDIT="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" <<'SQL'
SELECT
    count(*)
    || '|'
    ||
    count(*) FILTER (
        WHERE actor='mimir-embedder'
          AND action='embedding_set'
          AND details->>'session_user'='mimir_embedder'
          AND details->>'system_user'='peer:openclaw'
          AND details->>'dimensions'='768'
    )
FROM mimir.memory_audit
WHERE object_id=:'mid'::uuid
  AND action='embedding_set';
SQL
)"

[[ "$EMBED_AUDIT" == "1|1" ]] \
    || fail "embedding audit invalido: $EMBED_AUDIT"

echo "embedding_audit=PASS"

echo
echo "--- 10. GENERATE REAL QUERY EMBEDDING ---"

QUERY_JS="$TMP/embed-query.mjs"

cat > "$QUERY_JS" <<'JS'
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const MODEL_PATH =
    "/var/lib/openclaw/.node-llama-cpp/models/" +
    "hf_ggml-org_embeddinggemma-300m-qat-Q8_0.gguf";

const MODEL_ID =
    "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/" +
    "embeddinggemma-300m-qat-Q8_0.gguf";

const query = process.env.MIMIR_LAB_QUERY;

if (!query) {
    throw new Error("MIMIR_LAB_QUERY ausente");
}

const requireFromOpenClaw = createRequire(
    "/opt/openclaw/package.json"
);

const modulePath = requireFromOpenClaw.resolve(
    "node-llama-cpp"
);

const { getLlama } = await import(
    pathToFileURL(modulePath).href
);

let llama;
let model;
let context;

try {
    llama = await getLlama({ gpu: false });

    model = await llama.loadModel({
        modelPath: MODEL_PATH,
    });

    context = await model.createEmbeddingContext();

    const result = await context.getEmbeddingFor(
        `query: ${query}`
    );

    const embedding = Array.from(result.vector);

    if (
        embedding.length !== 768 ||
        !embedding.every(Number.isFinite)
    ) {
        throw new Error("embedding de consulta invalido");
    }

    process.stdout.write(
        JSON.stringify({
            query,
            model: MODEL_ID,
            embedding,
            limit: 5,
            min_similarity: 0.2,
        })
    );
} finally {
    try { await context?.dispose?.(); } catch {}
    try { await model?.dispose?.(); } catch {}
    try { await llama?.dispose?.(); } catch {}
}
JS

chown openclaw:openclaw "$QUERY_JS"
chmod 0600 "$QUERY_JS"

REQUEST_JSON="$(
    runuser -u openclaw -- \
    env \
        HOME=/var/lib/openclaw \
        USER=openclaw \
        LOGNAME=openclaw \
        MIMIR_LAB_QUERY="$QUERY_TEXT" \
        "$NODE" "$QUERY_JS"
)"

QUERY_DIMS="$(
    python3 -c '
import json,sys
d=json.load(sys.stdin)
print(len(d["embedding"]))
' <<<"$REQUEST_JSON"
)"

[[ "$QUERY_DIMS" == "768" ]] \
    || fail "query embedding nao possui 768 dimensoes"

echo "query_embedding_768d=PASS"

echo
echo "--- 11. SEMANTIC SEARCH BRIDGE ---"

SEARCH_JSON="$(
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
        PGAPPNAME=mimir-semantic-lab \
        "$NODE" "$SEARCH" \
        --json
)"

SEARCH_GUARD="$(
    python3 -c '
import json,sys
d=json.load(sys.stdin)

active=sys.argv[1]
rejected=sys.argv[2]
pending=sys.argv[3]

results=d["results"]
ids=[str(x["memory_id"]) for x in results]

assert d["dimensions"] == 768
assert active in ids
assert rejected not in ids
assert pending not in ids

match=next(x for x in results if str(x["memory_id"]) == active)

assert match["source_ref"] == "lab://embedding-semantic/active"
assert float(match["similarity"]) >= 0.2

print("PASS|" + str(len(results)))
' "$ACTIVE_ID" "$REJECT_ID" "$PENDING_ID" \
    <<<"$SEARCH_JSON"
)"

[[ "$SEARCH_GUARD" == PASS\|* ]] \
    || fail "semantic search guard falhou"

echo "promoted_memory_retrieved=PASS"
echo "rejected_memory_not_retrieved=PASS"
echo "candidate_memory_not_retrieved=PASS"
echo "semantic_source_provenance=PASS"

echo
echo "--- 12. END-TO-END PROVENANCE / AUDIT ---"

E2E="$(
    runuser -u postgres -- "$PSQL" \
        -X -w \
        -h "$PGHOST" \
        -p "$PGPORT" \
        -d "$DB" \
        -At \
        -v ON_ERROR_STOP=1 \
        -v mid="$ACTIVE_ID" \
        -v eid="$EVENT_ACTIVE" <<'SQL'
SELECT
    (
        SELECT source_event_id=:'eid'::uuid
        FROM mimir.memory_records
        WHERE memory_id=:'mid'::uuid
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
          AND action='approve'
          AND actor='Nogueira Maier'
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
    EXISTS (
        SELECT 1
        FROM mimir.memory_events
        WHERE event_id=:'eid'::uuid
          AND source_ref='lab://embedding-semantic/active'
    );
SQL
)"

[[ "$E2E" == "t|t|t|t|t" ]] \
    || fail "proveniencia ponta a ponta invalida: $E2E"

echo "end_to_end_provenance=PASS"
echo "end_to_end_audit=PASS"

echo
echo "--- 13. FINAL PRODUCTION GUARD ---"

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
echo "MIMIR-MEMORY-EMBEDDING-SEMANTIC-LAB: PASS"
