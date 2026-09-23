-- Recuperada de mimir_migration_009_apply.sh; não executar automaticamente.
-- Proveniência e exclusões de testes operacionais: docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md
BEGIN;

SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
SET LOCAL search_path = pg_catalog;

SET ROLE mimir_owner;

LOCK TABLE mimir.schema_version
    IN SHARE ROW EXCLUSIVE MODE;

DO $validation$
DECLARE
    v_latest_version integer;
BEGIN
    SELECT max(version)
      INTO v_latest_version
      FROM mimir.schema_version;

    IF v_latest_version IS DISTINCT FROM 8 THEN
        RAISE EXCEPTION
            'versão mais recente inesperada: %',
            v_latest_version;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 9
    ) THEN
        RAISE EXCEPTION
            'migração 009 já registrada';
    END IF;

    RAISE NOTICE
        'pré-condições da migração: aprovadas';
END;
$validation$;

REVOKE SELECT
ON TABLE
    mimir.memory_audit,
    mimir.memory_events,
    mimir.memory_records,
    mimir.memory_relations,
    mimir.schema_version
FROM mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    9,
    'Restrição da leitura direta pelo papel de ingestão'
);

DO $validation$
BEGIN
    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_audit',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT permaneceu em memory_audit';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_events',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT permaneceu em memory_events';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_records',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT permaneceu em memory_records';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_relations',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT permaneceu em memory_relations';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.schema_version',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT permaneceu em schema_version';
    END IF;

    IF NOT has_schema_privilege(
        'mimir_app',
        'mimir',
        'USAGE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app perdeu USAGE no esquema';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.ingest_document(text,text,text,text,text,text,jsonb,timestamptz)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'EXECUTE de ingest_document foi perdido';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'EXECUTE de ingest_session foi perdido';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.propose_memory(uuid,text,text,text,text,text,numeric,numeric,boolean,jsonb,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'EXECUTE de propose_memory foi perdido';
    END IF;

    IF NOT has_function_privilege(
        'mimir_search',
        'mimir.search_active_memory(public.vector,integer,double precision)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'consulta semântica foi afetada';
    END IF;

    RAISE NOTICE
        'SELECTs diretos: revogados';

    RAISE NOTICE
        'funções de ingestão: preservadas';

    RAISE NOTICE
        'consulta semântica: preservada';

    RAISE NOTICE
        'migração 009: validada';
END;
$validation$;

COMMIT;
