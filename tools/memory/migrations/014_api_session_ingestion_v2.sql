\set ON_ERROR_STOP on

-- Session ingestion v2 for OpenClaw 2026.9.5 canonical SQLite-backed sessions.
-- Version 013 is intentionally reserved for the independent operational layer.
-- This migration depends on memory version 012 and may be applied before or
-- after the operational 013, but it never applies or enables the operational
-- schema/role.
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
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 12
          AND description =
              'Leitura controlada de fontes para consolidação'
    ) THEN
        RAISE EXCEPTION
            'memory migration 012 required';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 14
    ) THEN
        RAISE EXCEPTION
            'migration 014 already applied';
    END IF;

    -- 013 belongs to the independent operational track. If present, require
    -- the exact reviewed identity so 014 never legitimizes an unknown 013.
    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 13
    )
       AND NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 13
          AND description =
              'Inventário operacional e intervenções por API peer controlada; memória preservada'
    ) THEN
        RAISE EXCEPTION
            'unexpected schema_version 13; stop and review';
    END IF;
END
$preconditions$;

SET LOCAL ROLE mimir_owner;
SET LOCAL search_path = pg_catalog, mimir, public;

ALTER TABLE mimir.session_sources
    ADD COLUMN source_kind text,
    ADD COLUMN source_key text,
    ADD COLUMN source_fingerprint_sha256 text,
    ADD COLUMN source_updated_at timestamptz,
    ADD COLUMN collector_version text,
    ADD COLUMN message_count integer;

UPDATE mimir.session_sources AS source
SET
    source_kind = 'legacy-jsonl',
    source_key = event.source_ref,
    source_updated_at = source.source_mtime,
    collector_version = 'legacy-jsonl-v1',
    message_count =
        source.user_messages + source.assistant_messages
FROM mimir.memory_events AS event
WHERE event.event_id = source.event_id;

ALTER TABLE mimir.session_sources
    ALTER COLUMN source_kind SET NOT NULL,
    ALTER COLUMN source_key SET NOT NULL,
    ALTER COLUMN source_updated_at SET NOT NULL,
    ALTER COLUMN collector_version SET NOT NULL,
    ALTER COLUMN message_count SET NOT NULL,
    ALTER COLUMN source_mtime DROP NOT NULL,
    ALTER COLUMN line_count DROP NOT NULL;

ALTER TABLE mimir.session_sources
    DROP CONSTRAINT session_sources_line_count_check;

ALTER TABLE mimir.session_sources
    ADD CONSTRAINT session_sources_source_kind_check
        CHECK (
            source_kind IN (
                'legacy-jsonl',
                'openclaw-chat-history-v2'
            )
        ),
    ADD CONSTRAINT session_sources_source_key_check
        CHECK (
            length(btrim(source_key)) BETWEEN 1 AND 1024
        ),
    ADD CONSTRAINT session_sources_source_fingerprint_check
        CHECK (
            (
                source_kind = 'legacy-jsonl'
                AND source_fingerprint_sha256 IS NULL
            )
            OR
            (
                source_kind = 'openclaw-chat-history-v2'
                AND source_fingerprint_sha256
                    ~ '^[0-9a-f]{64}$'
            )
        ),
    ADD CONSTRAINT session_sources_collector_version_check
        CHECK (
            length(btrim(collector_version)) BETWEEN 1 AND 128
        ),
    ADD CONSTRAINT session_sources_total_message_count_check
        CHECK (
            message_count >=
                user_messages + assistant_messages
            AND message_count > 0
        ),
    ADD CONSTRAINT session_sources_source_shape_check
        CHECK (
            (
                source_kind = 'legacy-jsonl'
                AND source_mtime IS NOT NULL
                AND line_count IS NOT NULL
                AND line_count >=
                    user_messages + assistant_messages
            )
            OR
            (
                source_kind = 'openclaw-chat-history-v2'
                AND source_mtime IS NULL
                AND line_count IS NULL
            )
        );

CREATE OR REPLACE FUNCTION mimir.ingest_session_v2(
    p_session_id                    uuid,
    p_session_key                   text,
    p_source_fingerprint_sha256     text,
    p_content                       text,
    p_content_sha256                text,
    p_message_count                 integer,
    p_user_messages                 integer,
    p_assistant_messages            integer,
    p_size_bytes                    bigint,
    p_source_updated_at             timestamptz,
    p_collector_version             text,
    p_excluded_system_messages      integer DEFAULT 0,
    p_excluded_tool_results         integer DEFAULT 0,
    p_excluded_thinking_blocks      integer DEFAULT 0,
    p_excluded_tool_calls           integer DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_actual_hash                 text;
    v_actual_size_bytes           bigint;
    v_source_ref                  text;
    v_event_id                    uuid;
    v_existing_event_id           uuid;
    v_existing_source_kind        text;
    v_existing_source_key         text;
    v_existing_source_fingerprint text;
    v_existing_content_hash       text;
    v_event_type                  text;
    v_classification              text;
    v_payload                     jsonb;
BEGIN
    IF session_user IS DISTINCT FROM 'mimir_app' THEN
        RAISE EXCEPTION
            'sessão não autorizada para ingestão v2: %',
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

    IF p_session_key IS NULL
       OR btrim(p_session_key) = ''
       OR length(p_session_key) > 1024
    THEN
        RAISE EXCEPTION 'session_key inválida';
    END IF;

    IF p_session_key !~
       '^agent:main:(telegram:direct:.+|hud:.+|acp-bridge:.+|maestro|main)$'
    THEN
        RAISE EXCEPTION
            'classe de session_key não autorizada';
    END IF;

    IF p_collector_version IS DISTINCT FROM
       'openclaw-chat-history-v2'
    THEN
        RAISE EXCEPTION
            'collector_version não autorizada';
    END IF;

    IF p_source_fingerprint_sha256 IS NULL
       OR p_source_fingerprint_sha256 !~ '^[0-9a-f]{64}$'
    THEN
        RAISE EXCEPTION
            'source fingerprint SHA-256 inválido';
    END IF;

    IF p_content IS NULL OR btrim(p_content) = '' THEN
        RAISE EXCEPTION
            'conteúdo normalizado da sessão vazio';
    END IF;

    IF p_content_sha256 IS NULL
       OR p_content_sha256 !~ '^[0-9a-f]{64}$'
    THEN
        RAISE EXCEPTION
            'content SHA-256 inválido';
    END IF;

    IF p_message_count IS NULL OR p_message_count < 1 THEN
        RAISE EXCEPTION 'message_count inválido';
    END IF;

    IF p_user_messages IS NULL OR p_user_messages < 1 THEN
        RAISE EXCEPTION 'user_messages inválido';
    END IF;

    IF p_assistant_messages IS NULL
       OR p_assistant_messages < 1
    THEN
        RAISE EXCEPTION 'assistant_messages inválido';
    END IF;

    IF p_message_count
       < p_user_messages + p_assistant_messages
    THEN
        RAISE EXCEPTION
            'message_count menor que mensagens elegíveis';
    END IF;

    IF p_excluded_system_messages IS NULL
       OR p_excluded_system_messages < 0
       OR p_excluded_tool_results IS NULL
       OR p_excluded_tool_results < 0
       OR p_excluded_thinking_blocks IS NULL
       OR p_excluded_thinking_blocks < 0
       OR p_excluded_tool_calls IS NULL
       OR p_excluded_tool_calls < 0
    THEN
        RAISE EXCEPTION
            'contagem de exclusões inválida';
    END IF;

    IF p_source_updated_at IS NULL THEN
        RAISE EXCEPTION 'source_updated_at obrigatório';
    END IF;

    IF p_source_updated_at
       > clock_timestamp() + interval '5 minutes'
    THEN
        RAISE EXCEPTION
            'source_updated_at está no futuro';
    END IF;

    v_actual_size_bytes := octet_length(p_content);

    IF v_actual_size_bytes > 10485760 THEN
        RAISE EXCEPTION
            'conteúdo excede 10485760 bytes';
    END IF;

    IF p_size_bytes IS NULL
       OR p_size_bytes <> v_actual_size_bytes
    THEN
        RAISE EXCEPTION
            'size_bytes não corresponde ao conteúdo';
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
            'content SHA-256 não corresponde';
    END IF;

    SELECT
        source.event_id,
        source.source_kind,
        source.source_key,
        source.source_fingerprint_sha256,
        source.content_sha256
    INTO
        v_existing_event_id,
        v_existing_source_kind,
        v_existing_source_key,
        v_existing_source_fingerprint,
        v_existing_content_hash
    FROM mimir.session_sources AS source
    WHERE source.session_id = p_session_id;

    IF FOUND THEN
        IF v_existing_source_kind
               IS DISTINCT FROM 'openclaw-chat-history-v2'
           OR v_existing_source_key
               IS DISTINCT FROM p_session_key
           OR v_existing_source_fingerprint
               IS DISTINCT FROM p_source_fingerprint_sha256
           OR v_existing_content_hash
               IS DISTINCT FROM v_actual_hash
        THEN
            RAISE EXCEPTION
                'session_id já existe com proveniência ou conteúdo diferente';
        END IF;

        RETURN v_existing_event_id;
    END IF;

    v_source_ref :=
        'openclaw://agent/main/session/'
        || p_session_id::text;

    v_payload := jsonb_build_object(
        'session_id',
        p_session_id,
        'session_key',
        p_session_key,
        'status',
        'done',
        'source_kind',
        'openclaw-chat-history-v2',
        'source_api',
        jsonb_build_array(
            'openclaw sessions --json',
            'gateway chat.history'
        ),
        'protected_source',
        true,
        'content_exposed',
        false,
        'source_fingerprint_sha256',
        p_source_fingerprint_sha256,
        'content_sha256',
        v_actual_hash,
        'message_count',
        p_message_count,
        'user_messages',
        p_user_messages,
        'assistant_messages',
        p_assistant_messages,
        'excluded_system_messages',
        p_excluded_system_messages,
        'excluded_tool_results',
        p_excluded_tool_results,
        'excluded_thinking_blocks',
        p_excluded_thinking_blocks,
        'excluded_tool_calls',
        p_excluded_tool_calls,
        'size_bytes',
        v_actual_size_bytes,
        'source_updated_at',
        p_source_updated_at,
        'collector_version',
        p_collector_version,
        'captured_at',
        clock_timestamp()
    );

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
        p_source_updated_at,
        'system',
        'mimir',
        'session_import',
        'openclaw-session',
        v_source_ref,
        'mimir-session-ingestor-v2',
        'confidential',
        NULL,
        NULL,
        v_payload
    )
    ON CONFLICT DO NOTHING
    RETURNING event_id
    INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT
            event.event_id,
            event.event_type,
            event.classification,
            event.payload
        INTO
            v_event_id,
            v_event_type,
            v_classification,
            v_payload
        FROM mimir.memory_events AS event
        WHERE event.source_type = 'openclaw-session'
          AND event.source_ref = v_source_ref;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'evento idempotente v2 não localizado';
        END IF;

        IF v_event_type IS DISTINCT FROM 'session_import'
           OR v_classification IS DISTINCT FROM 'confidential'
           OR v_payload ->> 'session_id'
                IS DISTINCT FROM p_session_id::text
           OR v_payload ->> 'session_key'
                IS DISTINCT FROM p_session_key
           OR v_payload ->> 'source_kind'
                IS DISTINCT FROM 'openclaw-chat-history-v2'
           OR v_payload ->> 'source_fingerprint_sha256'
                IS DISTINCT FROM p_source_fingerprint_sha256
           OR v_payload ->> 'content_sha256'
                IS DISTINCT FROM v_actual_hash
        THEN
            RAISE EXCEPTION
                'evento existente possui proveniência v2 incompatível';
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
        content,
        source_kind,
        source_key,
        source_fingerprint_sha256,
        source_updated_at,
        collector_version,
        message_count
    )
    VALUES (
        p_session_id,
        v_event_id,
        NULL,
        NULL,
        p_user_messages,
        p_assistant_messages,
        v_actual_size_bytes,
        v_actual_hash,
        p_content,
        'openclaw-chat-history-v2',
        p_session_key,
        p_source_fingerprint_sha256,
        p_source_updated_at,
        p_collector_version,
        p_message_count
    )
    ON CONFLICT (session_id) DO NOTHING
    RETURNING event_id
    INTO v_existing_event_id;

    IF v_existing_event_id IS NULL THEN
        SELECT
            source.event_id,
            source.source_kind,
            source.source_key,
            source.source_fingerprint_sha256,
            source.content_sha256
        INTO
            v_existing_event_id,
            v_existing_source_kind,
            v_existing_source_key,
            v_existing_source_fingerprint,
            v_existing_content_hash
        FROM mimir.session_sources AS source
        WHERE source.session_id = p_session_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'fonte v2 idempotente não localizada';
        END IF;

        IF v_existing_event_id IS DISTINCT FROM v_event_id
           OR v_existing_source_kind
                IS DISTINCT FROM 'openclaw-chat-history-v2'
           OR v_existing_source_key
                IS DISTINCT FROM p_session_key
           OR v_existing_source_fingerprint
                IS DISTINCT FROM p_source_fingerprint_sha256
           OR v_existing_content_hash
                IS DISTINCT FROM v_actual_hash
        THEN
            RAISE EXCEPTION
                'fonte concorrente possui estado v2 incompatível';
        END IF;
    END IF;

    RETURN v_event_id;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.ingest_session_v2(
    uuid,
    text,
    text,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz,
    text,
    integer,
    integer,
    integer,
    integer
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION mimir.ingest_session_v2(
    uuid,
    text,
    text,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz,
    text,
    integer,
    integer,
    integer,
    integer
)
FROM
    mimir_embedder,
    mimir_human,
    mimir_reviewer,
    mimir_search;

GRANT EXECUTE
ON FUNCTION mimir.ingest_session_v2(
    uuid,
    text,
    text,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz,
    text,
    integer,
    integer,
    integer,
    integer
)
TO mimir_app;

-- Fail closed on the retired file-backed ingestion entry point.
REVOKE EXECUTE
ON FUNCTION mimir.ingest_session(
    uuid,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz
)
FROM mimir_app;

COMMENT ON FUNCTION mimir.ingest_session(
    uuid,
    text,
    text,
    integer,
    integer,
    integer,
    bigint,
    timestamptz
)
IS
'Legacy JSONL session ingestion. Retained for historical compatibility; EXECUTE revoked from mimir_app by migration 014.';

CREATE OR REPLACE FUNCTION mimir.read_consolidation_source(
    p_event_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_result                     jsonb;
    v_actual_hash                text;
    v_stored_hash                text;
    v_payload_content_hash       text;
    v_actual_bytes               bigint;
    v_stored_bytes               bigint;
    v_source_kind                text;
    v_source_fingerprint         text;
    v_payload_source_fingerprint text;
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
            'source_kind', source.source_kind,
            'source_key', source.source_key,
            'source_updated_at', source.source_updated_at,
            'collector_version', source.collector_version,
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
        coalesce(
            event.payload ->> 'content_sha256',
            event.payload ->> 'raw_content_sha256'
        ),
        octet_length(source.content),
        source.size_bytes,
        source.source_kind,
        source.source_fingerprint_sha256,
        event.payload ->> 'source_fingerprint_sha256'
    INTO
        v_result,
        v_actual_hash,
        v_stored_hash,
        v_payload_content_hash,
        v_actual_bytes,
        v_stored_bytes,
        v_source_kind,
        v_source_fingerprint,
        v_payload_source_fingerprint
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
       OR v_actual_hash IS DISTINCT FROM v_payload_content_hash
    THEN
        RAISE EXCEPTION
            'integridade SHA-256 da fonte não confirmada';
    END IF;

    IF v_actual_bytes IS DISTINCT FROM v_stored_bytes THEN
        RAISE EXCEPTION
            'tamanho armazenado da fonte não corresponde ao conteúdo';
    END IF;

    IF v_source_kind = 'openclaw-chat-history-v2'
       AND (
           v_source_fingerprint IS NULL
           OR v_source_fingerprint IS DISTINCT FROM
              v_payload_source_fingerprint
       )
    THEN
        RAISE EXCEPTION
            'fingerprint da fonte v2 não confirmado';
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

DO $validation$
DECLARE
    v_owner              text;
    v_security_definer   boolean;
    v_runtime_config     text[];
BEGIN
    SELECT
        pg_get_userbyid(function_data.proowner),
        function_data.prosecdef,
        function_data.proconfig
    INTO
        v_owner,
        v_security_definer,
        v_runtime_config
    FROM pg_catalog.pg_proc AS function_data
    WHERE function_data.oid =
        'mimir.ingest_session_v2(uuid,text,text,text,text,integer,integer,integer,bigint,timestamptz,text,integer,integer,integer,integer)'::regprocedure;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'ingest_session_v2 não localizada';
    END IF;

    IF v_owner IS DISTINCT FROM 'mimir_owner'
       OR v_security_definer IS DISTINCT FROM true
       OR v_runtime_config IS DISTINCT FROM
          ARRAY['search_path=pg_catalog, mimir, public']::text[]
    THEN
        RAISE EXCEPTION
            'propriedade/SECURITY DEFINER/search_path inválidos em ingest_session_v2';
    END IF;

    IF NOT has_function_privilege(
        'mimir_app',
        'mimir.ingest_session_v2(uuid,text,text,text,text,integer,integer,integer,bigint,timestamptz,text,integer,integer,integer,integer)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app não recebeu EXECUTE em ingest_session_v2';
    END IF;

    IF has_function_privilege(
        'mimir_app',
        'mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'mimir_app manteve EXECUTE no ingresso legado';
    END IF;

    IF has_table_privilege(
        'mimir_app',
        'mimir.session_sources',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'mimir_app possui SELECT direto indevido em session_sources';
    END IF;
END
$validation$;

INSERT INTO mimir.schema_version(
    version,
    description
)
VALUES (
    14,
    'Ingestão protegida de sessões via OpenClaw chat.history v2'
);

COMMIT;
