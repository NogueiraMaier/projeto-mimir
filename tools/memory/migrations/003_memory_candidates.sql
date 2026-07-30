\set ON_ERROR_STOP on

BEGIN;

SET ROLE mimir_owner;
SET search_path = mimir, public;

ALTER TABLE mimir.memory_records
    ADD COLUMN IF NOT EXISTS content_sha256 text
    GENERATED ALWAYS AS (
        encode(
            digest(content, 'sha256'),
            'hex'
        )
    ) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS
    memory_records_source_key_hash_uq
ON mimir.memory_records (
    source_event_id,
    memory_key,
    content_sha256
)
WHERE source_event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION mimir.propose_memory (
    p_source_event_id uuid,
    p_memory_key      text,
    p_memory_type     text,
    p_title           text,
    p_summary         text,
    p_content         text,
    p_confidence      numeric DEFAULT 0.500,
    p_importance      numeric DEFAULT 0.500,
    p_pinned          boolean DEFAULT false,
    p_metadata        jsonb DEFAULT '{}'::jsonb,
    p_actor           text DEFAULT 'mimir'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $$
DECLARE
    v_memory_id      uuid;
    v_scope_type     text;
    v_scope_key      text;
    v_classification text;
    v_inserted       integer;
    v_combined       text;
BEGIN
    IF p_source_event_id IS NULL THEN
        RAISE EXCEPTION 'source_event_id obrigatório';
    END IF;

    IF p_memory_key IS NULL OR btrim(p_memory_key) = '' THEN
        RAISE EXCEPTION 'memory_key obrigatório';
    END IF;

    IF p_memory_type NOT IN (
        'semantic',
        'episodic',
        'procedural',
        'decision',
        'task',
        'evidence',
        'preference',
        'entity'
    ) THEN
        RAISE EXCEPTION
            'tipo de memória inválido: %',
            p_memory_type;
    END IF;

    IF p_content IS NULL OR btrim(p_content) = '' THEN
        RAISE EXCEPTION 'conteúdo obrigatório';
    END IF;

    IF p_confidence < 0 OR p_confidence > 1 THEN
        RAISE EXCEPTION 'confidence deve estar entre 0 e 1';
    END IF;

    IF p_importance < 0 OR p_importance > 1 THEN
        RAISE EXCEPTION 'importance deve estar entre 0 e 1';
    END IF;

    IF jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' THEN
        RAISE EXCEPTION 'metadata deve ser um objeto JSON';
    END IF;

    SELECT
        scope_type,
        scope_key,
        classification
    INTO
        v_scope_type,
        v_scope_key,
        v_classification
    FROM mimir.memory_events
    WHERE event_id = p_source_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'evento de origem não encontrado: %',
            p_source_event_id;
    END IF;

    v_combined := concat_ws(
        ' ',
        p_title,
        p_summary,
        p_content
    );

    IF v_combined ~* $secret_regex$(nvapi-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{20,}|authorization[[:space:]]*:[[:space:]]*bearer[[:space:]]+[^[:space:]]{20,}|(api[_-]?key|password|senha|token|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})$secret_regex$
    THEN
        RAISE EXCEPTION
            'conteúdo bloqueado: possível segredo ou credencial';
    END IF;

    INSERT INTO mimir.memory_records (
        memory_key,
        memory_type,
        status,
        scope_type,
        scope_key,
        title,
        summary,
        content,
        source_event_id,
        confidence,
        importance,
        pinned,
        metadata,
        created_by
    )
    VALUES (
        p_memory_key,
        p_memory_type,
        'candidate',
        v_scope_type,
        v_scope_key,
        nullif(btrim(p_title), ''),
        nullif(btrim(p_summary), ''),
        p_content,
        p_source_event_id,
        p_confidence,
        p_importance,
        p_pinned,
        jsonb_build_object(
            'source_classification',
            v_classification
        ) || coalesce(p_metadata, '{}'::jsonb),
        p_actor
    )
    ON CONFLICT DO NOTHING
    RETURNING memory_id
    INTO v_memory_id;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    IF v_memory_id IS NULL THEN
        SELECT memory_id
        INTO v_memory_id
        FROM mimir.memory_records
        WHERE source_event_id = p_source_event_id
          AND memory_key = p_memory_key
          AND content_sha256 = encode(
              digest(p_content, 'sha256'),
              'hex'
          )
        ORDER BY created_at
        LIMIT 1;
    END IF;

    IF v_inserted = 1 THEN
        INSERT INTO mimir.memory_audit (
            actor,
            action,
            object_type,
            object_id,
            scope_type,
            scope_key,
            details
        )
        VALUES (
            p_actor,
            'propose',
            'memory_record',
            v_memory_id,
            v_scope_type,
            v_scope_key,
            jsonb_build_object(
                'memory_key',
                p_memory_key,
                'memory_type',
                p_memory_type,
                'source_event_id',
                p_source_event_id
            )
        );
    END IF;

    RETURN v_memory_id;
END;
$$;

REVOKE ALL
ON FUNCTION mimir.propose_memory(
    uuid,
    text,
    text,
    text,
    text,
    text,
    numeric,
    numeric,
    boolean,
    jsonb,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION mimir.propose_memory(
    uuid,
    text,
    text,
    text,
    text,
    text,
    numeric,
    numeric,
    boolean,
    jsonb,
    text
)
TO mimir_app;

REVOKE INSERT
ON mimir.memory_records
FROM mimir_app;

REVOKE INSERT
ON mimir.memory_relations
FROM mimir_app;

REVOKE INSERT
ON mimir.memory_audit
FROM mimir_app;

CREATE OR REPLACE VIEW mimir.pending_memory_review AS
SELECT
    memory_id,
    memory_key,
    memory_type,
    scope_type,
    scope_key,
    title,
    summary,
    content,
    source_event_id,
    confidence,
    importance,
    pinned,
    metadata,
    created_at,
    created_by,
    content_sha256
FROM mimir.memory_records
WHERE status = 'candidate'
ORDER BY
    pinned DESC,
    importance DESC,
    confidence DESC,
    created_at;

GRANT SELECT
ON mimir.pending_memory_review
TO mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    3,
    'Proposição controlada e revisão de candidatos de memória'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
