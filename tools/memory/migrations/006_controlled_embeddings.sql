\set ON_ERROR_STOP on

BEGIN;

DO $role$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'mimir_embedder'
    ) THEN
        CREATE ROLE mimir_embedder
            LOGIN
            NOINHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT 2;
    END IF;
END
$role$;

ALTER ROLE mimir_embedder
    LOGIN
    NOINHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 2;

ALTER ROLE mimir_embedder PASSWORD NULL;

REVOKE ALL
ON DATABASE mimir_memory
FROM mimir_embedder;

GRANT CONNECT
ON DATABASE mimir_memory
TO mimir_embedder;

ALTER ROLE mimir_embedder
IN DATABASE mimir_memory
SET search_path = mimir, public;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE OR REPLACE VIEW mimir.pending_embeddings
WITH (security_barrier = true)
AS
SELECT
    memory_id,
    content_sha256,
    title,
    summary,
    content
FROM mimir.memory_records
WHERE status = 'active'
  AND embedding IS NULL
ORDER BY created_at;

REVOKE ALL
ON mimir.pending_embeddings
FROM PUBLIC;

GRANT USAGE
ON SCHEMA mimir
TO mimir_embedder;

GRANT SELECT
ON mimir.pending_embeddings
TO mimir_embedder;

CREATE OR REPLACE FUNCTION mimir.store_memory_embedding (
    p_memory_id       uuid,
    p_content_sha256  text,
    p_embedding       public.vector,
    p_embedding_model text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_record       mimir.memory_records%ROWTYPE;
    v_vector_norm  double precision;
BEGIN
    IF session_user <> 'mimir_embedder' THEN
        RAISE EXCEPTION
            'sessão não autorizada para embeddings: %',
            session_user;
    END IF;

    IF p_memory_id IS NULL THEN
        RAISE EXCEPTION 'memory_id obrigatório';
    END IF;

    IF p_content_sha256 IS NULL
       OR p_content_sha256 !~ '^[0-9a-f]{64}$'
    THEN
        RAISE EXCEPTION 'content_sha256 inválido';
    END IF;

    IF p_embedding IS NULL THEN
        RAISE EXCEPTION 'embedding obrigatório';
    END IF;

    IF public.vector_dims(p_embedding) <> 768 THEN
        RAISE EXCEPTION
            'embedding deve possuir 768 dimensões; recebido: %',
            public.vector_dims(p_embedding);
    END IF;

    v_vector_norm := public.vector_norm(p_embedding);

    IF v_vector_norm IS NULL OR v_vector_norm <= 0 THEN
        RAISE EXCEPTION
            'embedding possui norma inválida';
    END IF;

    IF p_embedding_model <>
       'hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf'
    THEN
        RAISE EXCEPTION
            'modelo de embedding não autorizado: %',
            p_embedding_model;
    END IF;

    SELECT *
    INTO v_record
    FROM mimir.memory_records
    WHERE memory_id = p_memory_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'memória não encontrada: %',
            p_memory_id;
    END IF;

    IF v_record.status <> 'active' THEN
        RAISE EXCEPTION
            'somente memória ativa pode receber embedding';
    END IF;

    IF v_record.content_sha256 <> p_content_sha256 THEN
        RAISE EXCEPTION
            'conteúdo alterado desde a geração do embedding';
    END IF;

    IF v_record.embedding IS NOT NULL THEN
        IF v_record.embedding_model = p_embedding_model THEN
            RETURN false;
        END IF;

        RAISE EXCEPTION
            'memória já possui embedding de outro modelo';
    END IF;

    UPDATE mimir.memory_records
    SET
        embedding = public.l2_normalize(p_embedding),
        embedding_model = p_embedding_model
    WHERE memory_id = p_memory_id;

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
        'mimir-embedder',
        'embedding_set',
        'memory_record',
        p_memory_id,
        v_record.scope_type,
        v_record.scope_key,
        jsonb_build_object(
            'embedding_model',
            p_embedding_model,
            'dimensions',
            public.vector_dims(p_embedding),
            'original_norm',
            v_vector_norm,
            'content_sha256',
            p_content_sha256,
            'session_user',
            session_user,
            'system_user',
            system_user
        )
    );

    RETURN true;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.store_memory_embedding(
    uuid,
    text,
    public.vector,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION mimir.store_memory_embedding(
    uuid,
    text,
    public.vector,
    text
)
TO mimir_embedder;

REVOKE ALL
ON mimir.memory_records
FROM mimir_embedder;

REVOKE ALL
ON mimir.memory_audit
FROM mimir_embedder;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    6,
    'Geração e gravação controlada de embeddings locais'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
