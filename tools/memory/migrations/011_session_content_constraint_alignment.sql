-- Recuperada de mimir_migration_011_apply.sh; não executar automaticamente.
-- Proveniência e exclusões de testes operacionais: docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '3min';
SET LOCAL idle_in_transaction_session_timeout = '3min';

LOCK TABLE
    mimir.schema_version,
    mimir.memory_events,
    mimir.session_sources
IN SHARE ROW EXCLUSIVE MODE;

DO $preconditions$
DECLARE
    v_latest_version       integer;
    v_constraint_count     integer;
    v_constraint_validated boolean;
    v_constraint_def       text;
    v_function_def         text;
    v_function_owner       text;
    v_security_definer     boolean;
    v_runtime_config       text[];
    v_session_sources      bigint;
    v_session_events       bigint;
BEGIN
    SELECT max(version)
    INTO v_latest_version
    FROM mimir.schema_version;

    IF v_latest_version IS DISTINCT FROM 10 THEN
        RAISE EXCEPTION
            'versão esperada 10, encontrada %',
            coalesce(v_latest_version::text, '<ausente>');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 10
          AND description =
              'Limite de 10 MiB e validação de tamanho na ingestão de sessões'
    ) THEN
        RAISE EXCEPTION
            'registro esperado da versão 10 não foi localizado';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 11
    ) THEN
        RAISE EXCEPTION
            'a versão 11 já está registrada';
    END IF;

    SELECT
        count(*),
        bool_and(con.convalidated),
        min(pg_get_constraintdef(con.oid, true))
    INTO
        v_constraint_count,
        v_constraint_validated,
        v_constraint_def
    FROM pg_catalog.pg_constraint AS con
    WHERE con.conrelid = 'mimir.session_sources'::regclass
      AND con.conname = 'session_sources_content_check'
      AND con.contype = 'c';

    IF v_constraint_count IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            'quantidade inesperada da restrição antiga: %',
            v_constraint_count;
    END IF;

    IF v_constraint_validated IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'a restrição antiga não está validada';
    END IF;

    IF position(
        'length(btrim(content)) > 0'
        IN v_constraint_def
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de conteúdo não vazio não foi localizada';
    END IF;

    IF position(
        'char_length(content) <= 60000'
        IN v_constraint_def
    ) = 0 THEN
        RAISE EXCEPTION
            'limite antigo de 60000 caracteres não foi localizado';
    END IF;

    SELECT
        pg_get_functiondef(function_data.oid),
        pg_get_userbyid(function_data.proowner),
        function_data.prosecdef,
        function_data.proconfig
    INTO
        v_function_def,
        v_function_owner,
        v_security_definer,
        v_runtime_config
    FROM pg_catalog.pg_proc AS function_data
    WHERE function_data.oid =
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)'::regprocedure;

    IF v_function_owner IS DISTINCT FROM 'mimir_owner' THEN
        RAISE EXCEPTION
            'proprietário inesperado de ingest_session';
    END IF;

    IF v_security_definer IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'SECURITY DEFINER não está ativo';
    END IF;

    IF v_runtime_config IS DISTINCT FROM
       ARRAY['search_path=pg_catalog, mimir, public']::text[]
    THEN
        RAISE EXCEPTION
            'search_path protegido está diferente: %',
            v_runtime_config;
    END IF;

    IF position(
        'v_actual_size_bytes > 10485760'
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION
            'limite de 10 MiB não foi localizado na função';
    END IF;

    IF position(
        'p_size_bytes <> v_actual_size_bytes'
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de size_bytes não foi localizada na função';
    END IF;

    IF position(
        'char_length(p_content) > 60000'
        IN v_function_def
    ) > 0 THEN
        RAISE EXCEPTION
            'limite antigo ainda está presente na função';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app perdeu EXECUTE';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS function_acl
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            coalesce(
                function_acl.proacl,
                pg_catalog.acldefault(
                    'f',
                    function_acl.proowner
                )
            )
        ) AS acl_entry
        WHERE function_acl.oid =
            'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)'::regprocedure
          AND acl_entry.grantee = 0
          AND acl_entry.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'PUBLIC possui EXECUTE indevido';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app possui SELECT direto indevido';
    END IF;

    SELECT count(*)
    INTO v_session_sources
    FROM mimir.session_sources;

    SELECT count(*)
    INTO v_session_events
    FROM mimir.memory_events
    WHERE source_type = 'openclaw-session';

    IF v_session_sources IS DISTINCT FROM 0
       OR v_session_events IS DISTINCT FROM 0
    THEN
        RAISE EXCEPTION
            'estado inesperado: % sessões e % eventos',
            v_session_sources,
            v_session_events;
    END IF;

    RAISE NOTICE
        'pré-condições da migração 011: aprovadas';
END;
$preconditions$;

SET LOCAL ROLE mimir_owner;

ALTER TABLE mimir.session_sources
    DROP CONSTRAINT session_sources_content_check;

ALTER TABLE mimir.session_sources
    ADD CONSTRAINT session_sources_content_check
    CHECK (
        length(btrim(content)) > 0
        AND octet_length(content) <= 10485760
    )
    NOT VALID;

ALTER TABLE mimir.session_sources
    VALIDATE CONSTRAINT session_sources_content_check;

RESET ROLE;

DO $validation$
DECLARE
    v_constraint_count     integer;
    v_constraint_validated boolean;
    v_constraint_def       text;
BEGIN
    SELECT
        count(*),
        bool_and(con.convalidated),
        min(pg_get_constraintdef(con.oid, true))
    INTO
        v_constraint_count,
        v_constraint_validated,
        v_constraint_def
    FROM pg_catalog.pg_constraint AS con
    WHERE con.conrelid = 'mimir.session_sources'::regclass
      AND con.conname = 'session_sources_content_check'
      AND con.contype = 'c';

    IF v_constraint_count IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            'quantidade inesperada da nova restrição: %',
            v_constraint_count;
    END IF;

    IF v_constraint_validated IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'a nova restrição não foi validada';
    END IF;

    IF position(
        'length(btrim(content)) > 0'
        IN v_constraint_def
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de conteúdo não vazio foi perdida';
    END IF;

    IF position(
        'octet_length(content) <= 10485760'
        IN v_constraint_def
    ) = 0 THEN
        RAISE EXCEPTION
            'limite de 10 MiB não foi localizado na restrição';
    END IF;

    IF position(
        'char_length(content) <= 60000'
        IN v_constraint_def
    ) > 0 THEN
        RAISE EXCEPTION
            'limite antigo permaneceu na restrição';
    END IF;

END;
$validation$;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    11,
    'Alinhamento da restrição de conteúdo ao limite de 10 MiB'
);

DO $version_validation$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 11
          AND description =
              'Alinhamento da restrição de conteúdo ao limite de 10 MiB'
    ) THEN
        RAISE EXCEPTION
            'versão 11 não foi registrada';
    END IF;

    RAISE NOTICE
        'registro da versão 11: aprovado';
END;
$version_validation$;

COMMIT;
