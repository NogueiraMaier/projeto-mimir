-- Recuperada de mimir_migration_012_apply.sh; não executar automaticamente.
-- Proveniência e exclusões de testes operacionais: docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '2min';
SET LOCAL idle_in_transaction_session_timeout = '2min';

LOCK TABLE
    mimir.schema_version,
    mimir.memory_events,
    mimir.session_sources,
    mimir.memory_records
IN SHARE ROW EXCLUSIVE MODE;

DO $preconditions$
DECLARE
    v_latest_version       integer;
BEGIN
    SELECT max(version)
      INTO v_latest_version
      FROM mimir.schema_version;

    IF v_latest_version IS DISTINCT FROM 11 THEN
        RAISE EXCEPTION
            'versão esperada 11, encontrada %',
            coalesce(v_latest_version::text, '<ausente>');
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM mimir.schema_version
         WHERE version = 11
           AND description =
               'Alinhamento da restrição de conteúdo ao limite de 10 MiB'
    ) THEN
        RAISE EXCEPTION
            'registro esperado da versão 11 não foi localizado';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM mimir.schema_version
         WHERE version = 12
    ) THEN
        RAISE EXCEPTION
            'a versão 12 já está registrada';
    END IF;

    IF to_regprocedure(
        'mimir.read_consolidation_source(uuid)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'read_consolidation_source já existe antes da migração';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_events',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app possui SELECT direto indevido em memory_events';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app possui SELECT direto indevido em session_sources';
    END IF;

    RAISE NOTICE
        'pré-condições da migração 012: aprovadas';
END;
$preconditions$;

SET LOCAL ROLE mimir_owner;

CREATE FUNCTION mimir.read_consolidation_source(
    p_event_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_result      jsonb;
    v_actual_hash text;
    v_stored_hash text;
    v_payload_hash text;
    v_actual_bytes bigint;
    v_stored_bytes bigint;
BEGIN
    IF session_user IS DISTINCT FROM 'mimir_app' THEN
        RAISE EXCEPTION
            'sessão não autorizada para consolidação: %',
            session_user;
    END IF;

    IF system_user IS DISTINCT FROM 'peer:openclaw' THEN
        RAISE EXCEPTION
            'identidade de autenticação não autorizada: %',
            coalesce(system_user, '<ausente>');
    END IF;

    IF p_event_id IS NULL THEN
        RAISE EXCEPTION 'event_id obrigatório';
    END IF;

    SELECT
        jsonb_build_object(
            'event_id', event.event_id,
            'occurred_at', event.occurred_at,
            'scope_type', event.scope_type,
            'scope_key', event.scope_key,
            'event_type', event.event_type,
            'source_type', event.source_type,
            'source_ref', event.source_ref,
            'classification', event.classification,
            'content', source.content
        ),
        encode(
            public.digest(
                convert_to(source.content, 'UTF8'),
                'sha256'
            ),
            'hex'
        ),
        source.content_sha256,
        event.payload ->> 'raw_content_sha256',
        octet_length(source.content),
        source.size_bytes
      INTO
        v_result,
        v_actual_hash,
        v_stored_hash,
        v_payload_hash,
        v_actual_bytes,
        v_stored_bytes
      FROM mimir.memory_events AS event
      JOIN mimir.session_sources AS source
        ON source.event_id = event.event_id
     WHERE event.event_id = p_event_id
       AND event.source_type = 'openclaw-session'
       AND event.event_type = 'session_import'
       AND event.content IS NULL
       AND event.content_sha256 IS NULL
       AND event.payload ->> 'protected_source' = 'true'
       AND event.payload ->> 'content_exposed' = 'false';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'fonte de consolidação não encontrada ou não autorizada';
    END IF;

    IF v_actual_hash IS DISTINCT FROM v_stored_hash
       OR v_actual_hash IS DISTINCT FROM v_payload_hash
    THEN
        RAISE EXCEPTION
            'integridade SHA-256 da fonte não confirmada';
    END IF;

    IF v_actual_bytes IS DISTINCT FROM v_stored_bytes THEN
        RAISE EXCEPTION
            'tamanho armazenado da fonte não corresponde ao conteúdo';
    END IF;

    RETURN v_result;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.read_consolidation_source(uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION mimir.read_consolidation_source(uuid)
TO mimir_app;

RESET ROLE;

DO $function_validation$
DECLARE
    v_function_def    text;
    v_function_owner  text;
    v_security_definer boolean;
    v_volatility      "char";
    v_runtime_config  text[];
    v_postgres_blocked boolean := false;
BEGIN
    SELECT
        pg_get_functiondef(function_data.oid),
        pg_get_userbyid(function_data.proowner),
        function_data.prosecdef,
        function_data.provolatile,
        function_data.proconfig
      INTO
        v_function_def,
        v_function_owner,
        v_security_definer,
        v_volatility,
        v_runtime_config
      FROM pg_catalog.pg_proc AS function_data
     WHERE function_data.oid =
           'mimir.read_consolidation_source(uuid)'::regprocedure;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'a nova função não foi localizada';
    END IF;

    IF v_function_owner IS DISTINCT FROM 'mimir_owner' THEN
        RAISE EXCEPTION
            'proprietário inesperado: %',
            v_function_owner;
    END IF;

    IF v_security_definer IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'SECURITY DEFINER não está ativo';
    END IF;

    IF v_volatility IS DISTINCT FROM 's'::"char" THEN
        RAISE EXCEPTION
            'volatilidade esperada STABLE, encontrada %',
            v_volatility;
    END IF;

    IF v_runtime_config IS DISTINCT FROM
       ARRAY['search_path=pg_catalog, mimir, public']::text[]
    THEN
        RAISE EXCEPTION
            'search_path protegido está diferente: %',
            v_runtime_config;
    END IF;

    IF position(
        'session_user IS DISTINCT FROM ''mimir_app'''
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de session_user não foi localizada';
    END IF;

    IF position(
        'system_user IS DISTINCT FROM ''peer:openclaw'''
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de system_user não foi localizada';
    END IF;

    IF position(
        'event.source_type = ''openclaw-session'''
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION
            'restrição de source_type não foi localizada';
    END IF;

    IF position(
        'event.payload ->> ''protected_source''::text = ''true''::text'
        IN v_function_def
    ) = 0
       AND position(
        'event.payload ->> ''protected_source'' = ''true'''
        IN v_function_def
    ) = 0
    THEN
        RAISE EXCEPTION
            'restrição protected_source não foi localizada';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.read_consolidation_source(uuid)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app não recebeu EXECUTE';
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
               'mimir.read_consolidation_source(uuid)'::regprocedure
           AND acl_entry.grantee = 0
           AND acl_entry.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'PUBLIC possui EXECUTE indevido';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.memory_events',
        'SELECT'
    ) OR has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'SELECT direto foi concedido indevidamente';
    END IF;

    BEGIN
        PERFORM mimir.read_consolidation_source(
            '2dbe20ed-053d-46e6-bf1d-2934dbaf7cad'::uuid
        );
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_postgres_blocked := true;
        WHEN OTHERS THEN
            IF SQLERRM LIKE
               'sessão não autorizada para consolidação:%'
            THEN
                v_postgres_blocked := true;
            ELSE
                RAISE;
            END IF;
    END;

    IF v_postgres_blocked IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'a identidade postgres não foi bloqueada';
    END IF;

    RAISE NOTICE
        'função estreita, ACL, identidade e menor privilégio: aprovados';
END;
$function_validation$;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    12,
    'Leitura controlada de fontes para consolidação'
);

DO $version_validation$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM mimir.schema_version
         WHERE version = 12
           AND description =
               'Leitura controlada de fontes para consolidação'
    ) THEN
        RAISE EXCEPTION
            'versão 12 não foi registrada';
    END IF;

    RAISE NOTICE
        'registro da versão 12: aprovado';
END;
$version_validation$;

COMMIT;
