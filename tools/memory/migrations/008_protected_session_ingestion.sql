\set ON_ERROR_STOP on

BEGIN;

SET ROLE mimir_owner;
SET search_path = mimir, public;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 7
    ) THEN
        RAISE EXCEPTION
            'migração 007 não foi localizada';
    END IF;
END
$migration$;

CREATE TABLE IF NOT EXISTS mimir.session_sources (
    session_id         uuid PRIMARY KEY,
    event_id           uuid NOT NULL UNIQUE,
    captured_at        timestamptz NOT NULL DEFAULT now(),
    source_mtime       timestamptz NOT NULL,
    line_count         integer NOT NULL,
    user_messages      integer NOT NULL,
    assistant_messages integer NOT NULL,
    size_bytes         bigint NOT NULL,
    content_sha256     text NOT NULL,
    content            text NOT NULL,

    CONSTRAINT session_sources_event_fk
        FOREIGN KEY (event_id)
        REFERENCES mimir.memory_events(event_id)
        ON DELETE RESTRICT,

    CONSTRAINT session_sources_line_count_check
        CHECK (
            line_count >= user_messages + assistant_messages
        ),

    CONSTRAINT session_sources_message_count_check
        CHECK (
            user_messages >= 0
            AND assistant_messages >= 0
            AND user_messages + assistant_messages > 0
        ),

    CONSTRAINT session_sources_size_check
        CHECK (size_bytes > 0),

    CONSTRAINT session_sources_hash_check
        CHECK (
            content_sha256 ~ '^[0-9a-f]{64}$'
        ),

    CONSTRAINT session_sources_content_check
        CHECK (
            length(btrim(content)) > 0
            AND char_length(content) <= 60000
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS
    memory_events_openclaw_session_uq
ON mimir.memory_events (
    source_type,
    source_ref
)
WHERE source_type = 'openclaw-session';

REVOKE ALL
ON TABLE mimir.session_sources
FROM PUBLIC;

REVOKE ALL
ON TABLE mimir.session_sources
FROM
    mimir_app,
    mimir_embedder,
    mimir_human,
    mimir_reviewer,
    mimir_search;

CREATE OR REPLACE FUNCTION mimir.ingest_session (
    p_session_id         uuid,
    p_content            text,
    p_content_sha256     text,
    p_line_count         integer,
    p_user_messages      integer,
    p_assistant_messages integer,
    p_size_bytes         bigint,
    p_source_mtime       timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_actual_hash       text;
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

    IF char_length(p_content) > 60000 THEN
        RAISE EXCEPTION
            'conteúdo excede 60000 caracteres';
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
            p_size_bytes,
            'source_mtime',
            p_source_mtime,
            'ingestor_version',
            1
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
        p_size_bytes,
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

REVOKE ALL
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
FROM PUBLIC;

REVOKE ALL
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
FROM
    mimir_embedder,
    mimir_human,
    mimir_reviewer,
    mimir_search;

GRANT EXECUTE
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
TO mimir_app;

REVOKE
    SELECT,
    INSERT,
    UPDATE,
    DELETE,
    TRUNCATE,
    REFERENCES,
    TRIGGER
ON mimir.session_sources
FROM mimir_app;

REVOKE INSERT
ON mimir.memory_events
FROM mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    8,
    'Ingestão idempotente e protegida de sessões do OpenClaw'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
