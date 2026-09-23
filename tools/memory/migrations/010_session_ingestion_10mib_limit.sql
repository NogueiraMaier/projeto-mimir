-- Recuperada de mimir_migration_010_apply.sh; não executar automaticamente.
-- Proveniência e exclusões de testes operacionais: docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '2min';
SET LOCAL idle_in_transaction_session_timeout = '2min';

LOCK TABLE
    mimir.schema_version,
    mimir.memory_events,
    mimir.session_sources
IN SHARE ROW EXCLUSIVE MODE;

DO $preconditions$
DECLARE
    v_latest_version integer;
BEGIN
    SELECT max(version)
    INTO v_latest_version
    FROM mimir.schema_version;

    IF v_latest_version IS DISTINCT FROM 9 THEN
        RAISE EXCEPTION
            'versão esperada 9, encontrada %',
            coalesce(v_latest_version::text, '<ausente>');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 10
    ) THEN
        RAISE EXCEPTION
            'a versão 10 já está registrada';
    END IF;

    IF pg_get_userbyid(
        (
            SELECT proowner
            FROM pg_catalog.pg_proc
            WHERE oid =
                'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)'::regprocedure
        )
    ) IS DISTINCT FROM 'mimir_owner' THEN
        RAISE EXCEPTION
            'proprietário inesperado de ingest_session';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app perdeu EXECUTE antes da migração';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app possui SELECT direto indevido';
    END IF;

    RAISE NOTICE
        'pré-condições da migração 010: aprovadas';
END;
$preconditions$;

SET LOCAL ROLE mimir_owner;

CREATE OR REPLACE FUNCTION mimir.ingest_session(
    p_session_id uuid,
    p_content text,
    p_content_sha256 text,
    p_line_count integer,
    p_user_messages integer,
    p_assistant_messages integer,
    p_size_bytes bigint,
    p_source_mtime timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_actual_hash       text;
    v_actual_size_bytes bigint;
    v_source_ref        text;
    v_event_id          uuid;
    v_stored_event_id   uuid;
    v_stored_hash       text;
    v_event_type        text;
    v_classification    text;
BEGIN
    IF session_user IS DISTINCT FROM 'mimir_app' THEN
        RAISE EXCEPTION
            'sessão não autorizada para ingestão: %',
            session_user;
    END IF;

    IF system_user IS DISTINCT FROM 'peer:openclaw' THEN
        RAISE EXCEPTION
            'identidade de autenticação não autorizada: %',
            coalesce(system_user, '<ausente>');
    END IF;

    IF p_session_id IS NULL THEN
        RAISE EXCEPTION 'session_id obrigatório';
    END IF;

    IF p_content IS NULL OR btrim(p_content) = '' THEN
        RAISE EXCEPTION 'conteúdo da sessão vazio';
    END IF;

    v_actual_size_bytes := octet_length(p_content);

    IF v_actual_size_bytes > 10485760 THEN
        RAISE EXCEPTION
            'conteúdo excede 10485760 bytes';
    END IF;

    IF p_content_sha256 IS NULL
       OR p_content_sha256 !~ '^[0-9a-f]{64}$'
    THEN
        RAISE EXCEPTION
            'SHA-256 informado possui formato inválido';
    END IF;

    IF p_line_count IS NULL OR p_line_count < 1 THEN
        RAISE EXCEPTION 'line_count inválido';
    END IF;

    IF p_user_messages IS NULL OR p_user_messages < 0 THEN
        RAISE EXCEPTION 'user_messages inválido';
    END IF;

    IF p_assistant_messages IS NULL
       OR p_assistant_messages < 0
    THEN
        RAISE EXCEPTION 'assistant_messages inválido';
    END IF;

    IF p_user_messages + p_assistant_messages < 1 THEN
        RAISE EXCEPTION
            'sessão sem mensagens elegíveis';
    END IF;

    IF p_line_count
       < p_user_messages + p_assistant_messages
    THEN
        RAISE EXCEPTION
            'line_count menor que a quantidade de mensagens';
    END IF;

    IF p_size_bytes IS NULL OR p_size_bytes < 1 THEN
        RAISE EXCEPTION 'size_bytes inválido';
    END IF;

    IF p_size_bytes <> v_actual_size_bytes THEN
        RAISE EXCEPTION
            'size_bytes informado não corresponde ao conteúdo';
    END IF;

    IF p_source_mtime IS NULL THEN
        RAISE EXCEPTION 'source_mtime obrigatório';
    END IF;

    IF p_source_mtime
       > clock_timestamp() + interval '5 minutes'
    THEN
        RAISE EXCEPTION
            'source_mtime está no futuro';
    END IF;

    v_actual_hash := encode(
        public.digest(
            convert_to(p_content, 'UTF8'),
            'sha256'
        ),
        'hex'
    );

    IF v_actual_hash <> p_content_sha256 THEN
        RAISE EXCEPTION
            'SHA-256 do conteúdo não corresponde';
    END IF;

    SELECT
        event_id,
        content_sha256
    INTO
        v_stored_event_id,
        v_stored_hash
    FROM mimir.session_sources
    WHERE session_id = p_session_id;

    IF FOUND THEN
        IF v_stored_hash <> v_actual_hash THEN
            RAISE EXCEPTION
                'sessão já armazenada com SHA-256 diferente';
        END IF;

        RETURN v_stored_event_id;
    END IF;

    v_source_ref :=
        'agents/main/sessions/'
        || p_session_id::text
        || '.jsonl';

    INSERT INTO mimir.memory_events (
        occurred_at,
        scope_type,
        scope_key,
        event_type,
        source_type,
        source_ref,
        actor,
        classification,
        content,
        content_sha256,
        payload
    )
    VALUES (
        p_source_mtime,
        'system',
        'mimir',
        'session_import',
        'openclaw-session',
        v_source_ref,
        'mimir-session-ingestor',
        'confidential',
        NULL,
        NULL,
        jsonb_build_object(
            'session_id',
            p_session_id,
            'status',
            'done',
            'protected_source',
            true,
            'content_exposed',
            false,
            'raw_content_sha256',
            v_actual_hash,
            'line_count',
            p_line_count,
            'user_messages',
            p_user_messages,
            'assistant_messages',
            p_assistant_messages,
            'message_count',
            p_user_messages + p_assistant_messages,
            'content_chars',
            char_length(p_content),
            'size_bytes',
            v_actual_size_bytes,
            'source_mtime',
            p_source_mtime,
            'ingestor_version',
            2
        )
    )
    ON CONFLICT DO NOTHING
    RETURNING event_id INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT
            event_id,
            event_type,
            classification
        INTO
            v_event_id,
            v_event_type,
            v_classification
        FROM mimir.memory_events
        WHERE source_type = 'openclaw-session'
          AND source_ref = v_source_ref;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'evento idempotente não foi localizado';
        END IF;

        IF v_event_type <> 'session_import'
           OR v_classification <> 'confidential'
        THEN
            RAISE EXCEPTION
                'evento existente possui estado incompatível';
        END IF;
    END IF;

    INSERT INTO mimir.session_sources (
        session_id,
        event_id,
        source_mtime,
        line_count,
        user_messages,
        assistant_messages,
        size_bytes,
        content_sha256,
        content
    )
    VALUES (
        p_session_id,
        v_event_id,
        p_source_mtime,
        p_line_count,
        p_user_messages,
        p_assistant_messages,
        v_actual_size_bytes,
        v_actual_hash,
        p_content
    )
    ON CONFLICT (session_id) DO NOTHING
    RETURNING
        event_id,
        content_sha256
    INTO
        v_stored_event_id,
        v_stored_hash;

    IF v_stored_event_id IS NULL THEN
        SELECT
            event_id,
            content_sha256
        INTO
            v_stored_event_id,
            v_stored_hash
        FROM mimir.session_sources
        WHERE session_id = p_session_id;
    END IF;

    IF v_stored_hash <> v_actual_hash THEN
        RAISE EXCEPTION
            'sessão concorrente possui SHA-256 diferente';
    END IF;

    IF v_stored_event_id <> v_event_id THEN
        RAISE EXCEPTION
            'sessão concorrente possui event_id diferente';
    END IF;

    RETURN v_event_id;
END;
$function$;

REVOKE ALL ON FUNCTION mimir.ingest_session(
    uuid,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION mimir.ingest_session(
    uuid,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz
) TO mimir_app;

RESET ROLE;

DO $validation$
DECLARE
    v_definition       text;
    v_owner            text;
    v_security_definer boolean;
    v_runtime_config   text[];
BEGIN
    SELECT
        pg_get_functiondef(function_data.oid),
        pg_get_userbyid(function_data.proowner),
        function_data.prosecdef,
        function_data.proconfig
    INTO
        v_definition,
        v_owner,
        v_security_definer,
        v_runtime_config
    FROM pg_catalog.pg_proc AS function_data
    WHERE function_data.oid =
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)'::regprocedure;

    IF v_owner IS DISTINCT FROM 'mimir_owner' THEN
        RAISE EXCEPTION
            'proprietário de ingest_session foi alterado';
    END IF;

    IF v_security_definer IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'SECURITY DEFINER foi perdido';
    END IF;

    IF v_runtime_config IS DISTINCT FROM
       ARRAY['search_path=pg_catalog, mimir, public']::text[]
    THEN
        RAISE EXCEPTION
            'search_path protegido foi alterado: %',
            v_runtime_config;
    END IF;

    IF position(
        'v_actual_size_bytes > 10485760'
        IN v_definition
    ) = 0 THEN
        RAISE EXCEPTION
            'novo limite em bytes não foi localizado';
    END IF;

    IF position(
        'p_size_bytes <> v_actual_size_bytes'
        IN v_definition
    ) = 0 THEN
        RAISE EXCEPTION
            'validação de size_bytes não foi localizada';
    END IF;

    IF position(
        'char_length(p_content) > 60000'
        IN v_definition
    ) > 0 THEN
        RAISE EXCEPTION
            'limite antigo de 60000 caracteres permaneceu';
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
            'PUBLIC recebeu EXECUTE indevido';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app recuperou SELECT indevido';
    END IF;

END;
$validation$;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    10,
    'Limite de 10 MiB e validação de tamanho na ingestão de sessões'
);

DO $version_validation$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 10
          AND description =
              'Limite de 10 MiB e validação de tamanho na ingestão de sessões'
    ) THEN
        RAISE EXCEPTION
            'versão 10 não foi registrada';
    END IF;

    RAISE NOTICE
        'registro da versão 10: aprovado';
END;
$version_validation$;

COMMIT;
