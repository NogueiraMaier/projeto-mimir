\set ON_ERROR_STOP on

BEGIN;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE UNIQUE INDEX IF NOT EXISTS memory_events_source_hash_uq
    ON mimir.memory_events (
        scope_type,
        scope_key,
        source_type,
        source_ref,
        content_sha256
    )
    WHERE content_sha256 IS NOT NULL;

CREATE OR REPLACE FUNCTION mimir.ingest_document (
    p_scope_type       text,
    p_scope_key        text,
    p_source_ref       text,
    p_actor            text,
    p_classification   text,
    p_content          text,
    p_payload          jsonb DEFAULT '{}'::jsonb,
    p_occurred_at      timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $$
DECLARE
    v_content_hash text;
    v_event_id     uuid;
BEGIN
    IF p_scope_type IS NULL OR btrim(p_scope_type) = '' THEN
        RAISE EXCEPTION 'scope_type obrigatório';
    END IF;

    IF p_scope_key IS NULL OR btrim(p_scope_key) = '' THEN
        RAISE EXCEPTION 'scope_key obrigatório';
    END IF;

    IF p_source_ref IS NULL OR btrim(p_source_ref) = '' THEN
        RAISE EXCEPTION 'source_ref obrigatório';
    END IF;

    IF p_actor IS NULL OR btrim(p_actor) = '' THEN
        RAISE EXCEPTION 'actor obrigatório';
    END IF;

    IF p_content IS NULL OR btrim(p_content) = '' THEN
        RAISE EXCEPTION 'conteúdo vazio';
    END IF;

    IF p_classification NOT IN (
        'public',
        'internal',
        'confidential',
        'restricted'
    ) THEN
        RAISE EXCEPTION
            'classificação inválida: %',
            p_classification;
    END IF;

    IF jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' THEN
        RAISE EXCEPTION 'payload deve ser objeto JSON';
    END IF;

    v_content_hash :=
        encode(
            digest(
                convert_to(p_content, 'UTF8'),
                'sha256'
            ),
            'hex'
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
        p_occurred_at,
        p_scope_type,
        p_scope_key,
        'document_import',
        'workspace-markdown',
        p_source_ref,
        p_actor,
        p_classification,
        p_content,
        v_content_hash,
        coalesce(p_payload, '{}'::jsonb)
    )
    ON CONFLICT DO NOTHING
    RETURNING event_id INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT event_id
          INTO v_event_id
          FROM mimir.memory_events
         WHERE scope_type = p_scope_type
           AND scope_key = p_scope_key
           AND source_type = 'workspace-markdown'
           AND source_ref = p_source_ref
           AND content_sha256 = v_content_hash
         ORDER BY ingested_at DESC
         LIMIT 1;
    END IF;

    RETURN v_event_id;
END;
$$;

REVOKE ALL
    ON FUNCTION mimir.ingest_document(
        text,
        text,
        text,
        text,
        text,
        text,
        jsonb,
        timestamptz
    )
    FROM PUBLIC;

GRANT EXECUTE
    ON FUNCTION mimir.ingest_document(
        text,
        text,
        text,
        text,
        text,
        text,
        jsonb,
        timestamptz
    )
    TO mimir_app;

-- O aplicativo passa a usar a função controlada.
REVOKE INSERT
    ON mimir.memory_events
    FROM mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    2,
    'Ingestão idempotente de documentos Markdown'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
