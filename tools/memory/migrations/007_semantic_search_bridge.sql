\set ON_ERROR_STOP on

BEGIN;

DO $role$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'mimir_search'
    ) THEN
        CREATE ROLE mimir_search
            LOGIN
            NOINHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT 4;
    END IF;
END
$role$;

ALTER ROLE mimir_search
    LOGIN
    NOINHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 4;

ALTER ROLE mimir_search PASSWORD NULL;

REVOKE ALL
ON DATABASE mimir_memory
FROM mimir_search;

GRANT CONNECT
ON DATABASE mimir_memory
TO mimir_search;

ALTER ROLE mimir_search
IN DATABASE mimir_memory
SET search_path = mimir, public;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE OR REPLACE FUNCTION mimir.search_active_memory (
    p_query_embedding public.vector,
    p_limit integer DEFAULT 5,
    p_min_similarity double precision DEFAULT 0.35
)
RETURNS TABLE (
    memory_id       uuid,
    memory_key      text,
    memory_type     text,
    title           text,
    summary         text,
    content         text,
    source_event_id uuid,
    source_ref      text,
    confidence      numeric,
    importance      numeric,
    similarity      double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_query public.vector;
BEGIN
    IF session_user <> 'mimir_search' THEN
        RAISE EXCEPTION
            'sessão não autorizada para consulta semântica: %',
            session_user;
    END IF;

    IF system_user IS DISTINCT FROM 'peer:openclaw' THEN
        RAISE EXCEPTION
            'identidade de autenticação não autorizada: %',
            coalesce(system_user, '<ausente>');
    END IF;

    IF p_query_embedding IS NULL THEN
        RAISE EXCEPTION 'embedding de consulta obrigatório';
    END IF;

    IF public.vector_dims(p_query_embedding) <> 768 THEN
        RAISE EXCEPTION
            'embedding deve possuir 768 dimensões; recebido: %',
            public.vector_dims(p_query_embedding);
    END IF;

    IF public.vector_norm(p_query_embedding) IS NULL
       OR public.vector_norm(p_query_embedding) <= 0
    THEN
        RAISE EXCEPTION
            'embedding de consulta possui norma inválida';
    END IF;

    IF p_limit < 1 OR p_limit > 20 THEN
        RAISE EXCEPTION
            'limite deve estar entre 1 e 20';
    END IF;

    IF p_min_similarity < 0 OR p_min_similarity > 1 THEN
        RAISE EXCEPTION
            'similaridade mínima deve estar entre 0 e 1';
    END IF;

    v_query := public.l2_normalize(p_query_embedding);

    RETURN QUERY
    SELECT
        r.memory_id,
        r.memory_key,
        r.memory_type,
        r.title,
        r.summary,
        r.content,
        r.source_event_id,
        e.source_ref,
        r.confidence,
        r.importance,
        (
            1.0 - (r.embedding <=> v_query)
        )::double precision AS similarity
    FROM mimir.memory_records AS r
    LEFT JOIN mimir.memory_events AS e
      ON e.event_id = r.source_event_id
    WHERE r.status = 'active'
      AND r.scope_type = 'system'
      AND r.scope_key = 'mimir'
      AND r.valid_from <= now()
      AND (
          r.valid_until IS NULL
          OR r.valid_until > now()
      )
      AND (
          r.expires_at IS NULL
          OR r.expires_at > now()
      )
      AND r.embedding IS NOT NULL
      AND r.embedding_model =
          'hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf'
      AND (
          1.0 - (r.embedding <=> v_query)
      ) >= p_min_similarity
    ORDER BY
        r.embedding <=> v_query,
        r.importance DESC,
        r.confidence DESC,
        r.memory_id
    LIMIT p_limit;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.search_active_memory(
    public.vector,
    integer,
    double precision
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION mimir.search_active_memory(
    public.vector,
    integer,
    double precision
)
FROM
    mimir_app,
    mimir_embedder,
    mimir_human,
    mimir_reviewer;

GRANT USAGE
ON SCHEMA mimir
TO mimir_search;

GRANT EXECUTE
ON FUNCTION mimir.search_active_memory(
    public.vector,
    integer,
    double precision
)
TO mimir_search;

REVOKE ALL
ON mimir.memory_records
FROM mimir_search;

REVOKE ALL
ON mimir.memory_events
FROM mimir_search;

REVOKE ALL
ON mimir.memory_audit
FROM mimir_search;

REVOKE ALL
ON mimir.memory_reviews
FROM mimir_search;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    7,
    'Ponte controlada de consulta semântica das memórias ativas'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
