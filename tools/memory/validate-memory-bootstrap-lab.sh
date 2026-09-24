#!/bin/bash
set -euo pipefail

LAB_ROOT=/var/tmp/mimir-pg13-lab
SOCK="$LAB_ROOT/socket"
PORT=55432
DB=mimir_memory

REPO="${1:-/var/tmp/mimir-validation-5c7ec3e}"

fail() {
    echo "ERRO: $*" >&2
    exit 1
}

test "$(id -u)" -eq 0 || fail "execute como root"
test -S "$SOCK/.s.PGSQL.$PORT" || fail "socket do laboratorio ausente"
test -f "$REPO/tools/memory/bootstrap/memory_v1_canonical.sql" ||
    fail "bootstrap canonico nao encontrado"

echo "=== BOOTSTRAP LAB / 1. SEGURANCA ==="

PROD_V13=$(
    runuser -u postgres -- psql       -X -h /run/postgresql -p 5432 -d mimir_memory -At       -c "SELECT EXISTS (SELECT 1 FROM mimir.schema_version WHERE version=13);"
)

PROD_OPS=$(
    runuser -u postgres -- psql       -X -h /run/postgresql -p 5432 -d mimir_memory -At       -c "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='mimir_ops');"
)

echo "production_version13=$PROD_V13"
echo "production_mimir_ops=$PROD_OPS"

test "$PROD_V13" = "f" || fail "producao possui version 13 inesperada"
test "$PROD_OPS" = "f" || fail "producao possui mimir_ops inesperado"

echo
echo "=== BOOTSTRAP LAB / 2. BANCO DESCARTAVEL ==="

runuser -u postgres -- dropdb     -h "$SOCK" -p "$PORT"     --if-exists --force "$DB"

runuser -u postgres -- createdb     -h "$SOCK" -p "$PORT"     -T template0     --encoding=UTF8     "$DB"

echo
echo "=== BOOTSTRAP LAB / 3. BOOTSTRAP V1 ==="

runuser -u postgres -- psql     -X -h "$SOCK" -p "$PORT" -d "$DB"     -v ON_ERROR_STOP=1     -f "$REPO/tools/memory/bootstrap/memory_v1_canonical.sql"

V1=$(
    runuser -u postgres -- psql       -X -h "$SOCK" -p "$PORT" -d "$DB" -At       -c "SELECT string_agg(version::text,',' ORDER BY version) FROM mimir.schema_version;"
)

echo "versions_after_bootstrap=$V1"
test "$V1" = "1" || fail "bootstrap nao terminou somente na versao 1"

echo
echo "=== BOOTSTRAP LAB / 4. REPLAY 002-012 ==="

for version in 002 003 004 005 006 007 008 009 010 011 012; do
    file=$(find "$REPO/tools/memory/migrations"         -maxdepth 1 -type f -name "${version}_*.sql" -print)

    test -n "$file" || fail "migration $version nao localizada"

    count=$(printf '%s\n' "$file" | sed '/^$/d' | wc -l)
    test "$count" -eq 1 || fail "migration $version ambigua"

    echo "--- applying $(basename "$file")"

    runuser -u postgres -- psql         -X -h "$SOCK" -p "$PORT" -d "$DB"         -v ON_ERROR_STOP=1         -f "$file"
done

echo
echo "=== BOOTSTRAP LAB / 5. VERSOES ==="

VERSIONS=$(
    runuser -u postgres -- psql       -X -h "$SOCK" -p "$PORT" -d "$DB" -At       -c "SELECT string_agg(version::text,',' ORDER BY version) FROM mimir.schema_version;"
)

echo "schema_versions=$VERSIONS"

test "$VERSIONS" = "1,2,3,4,5,6,7,8,9,10,11,12" ||
    fail "cadeia de migrations incompleta"

echo
echo "=== BOOTSTRAP LAB / 6. OBJETOS FINAIS ==="

runuser -u postgres -- psql   -X -h "$SOCK" -p "$PORT" -d "$DB"   -v ON_ERROR_STOP=1 -At <<'SQL'
SELECT 'tables=' || string_agg(tablename,',' ORDER BY tablename)
FROM pg_tables
WHERE schemaname='mimir';

SELECT 'functions=' || string_agg(
    p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
    ',' ORDER BY p.proname, pg_get_function_identity_arguments(p.oid)
)
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mimir';

SELECT 'memory_records_search_generated=' ||
       EXISTS (
         SELECT 1
         FROM pg_attribute a
         JOIN pg_class c ON c.oid=a.attrelid
         JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='mimir'
           AND c.relname='memory_records'
           AND a.attname='search_document'
           AND a.attgenerated='s'
       );

SELECT 'memory_records_hash_generated=' ||
       EXISTS (
         SELECT 1
         FROM pg_attribute a
         JOIN pg_class c ON c.oid=a.attrelid
         JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='mimir'
           AND c.relname='memory_records'
           AND a.attname='content_sha256'
           AND a.attgenerated='s'
       );
SQL

echo
echo "=== BOOTSTRAP LAB / 7. PRIVILEGIOS FINAIS ==="

runuser -u postgres -- psql   -X -h "$SOCK" -p "$PORT" -d "$DB"   -v ON_ERROR_STOP=1 -At <<'SQL'
SELECT
    c.relname ||
    '|select=' ||
      has_table_privilege(
        'mimir_app',
        format('%I.%I', n.nspname, c.relname),
        'SELECT'
      ) ||
    '|insert=' ||
      has_table_privilege(
        'mimir_app',
        format('%I.%I', n.nspname, c.relname),
        'INSERT'
      ) ||
    '|update=' ||
      has_table_privilege(
        'mimir_app',
        format('%I.%I', n.nspname, c.relname),
        'UPDATE'
      ) ||
    '|delete=' ||
      has_table_privilege(
        'mimir_app',
        format('%I.%I', n.nspname, c.relname),
        'DELETE'
      )
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='mimir'
  AND c.relkind='r'
  AND c.relname IN (
      'schema_version',
      'memory_events',
      'memory_records',
      'memory_relations',
      'memory_audit'
  )
ORDER BY c.relname;

SELECT 'schema_usage=' ||
       has_schema_privilege('mimir_app','mimir','USAGE');

SELECT 'ingest_document_execute=' ||
       has_function_privilege(
         'mimir_app',
         'mimir.ingest_document(text,text,text,text,text,text,jsonb,timestamptz)',
         'EXECUTE'
       );

SELECT 'ingest_session_execute=' ||
       has_function_privilege(
         'mimir_app',
         'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
         'EXECUTE'
       );

SELECT 'propose_memory_execute=' ||
       has_function_privilege(
         'mimir_app',
         'mimir.propose_memory(uuid,text,text,text,text,text,numeric,numeric,boolean,jsonb,text)',
         'EXECUTE'
       );
SQL

echo
echo "=== BOOTSTRAP LAB / 8. TESTE ESTATICO ==="

python3 -B "$REPO/tools/memory/test_memory_bootstrap.py"

echo
echo "=== BOOTSTRAP LAB / 9. PRODUCAO CONTINUA INTACTA ==="

runuser -u postgres -- psql   -X -h /run/postgresql -p 5432 -d mimir_memory -At <<'SQL'
SELECT 'production_versions=' ||
       string_agg(version::text,',' ORDER BY version)
FROM mimir.schema_version;

SELECT 'production_version13=' ||
       EXISTS (
         SELECT 1
         FROM mimir.schema_version
         WHERE version=13
       );

SELECT 'production_mimir_ops=' ||
       EXISTS (
         SELECT 1
         FROM pg_roles
         WHERE rolname='mimir_ops'
       );
SQL

echo
echo "=== BOOTSTRAP LAB VALIDADO ==="
