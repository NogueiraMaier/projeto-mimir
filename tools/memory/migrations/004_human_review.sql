\set ON_ERROR_STOP on

BEGIN;

DO $role$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'mimir_reviewer'
    ) THEN
        CREATE ROLE mimir_reviewer
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS;
    END IF;
END
$role$;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE TABLE IF NOT EXISTS mimir.memory_reviews (
    review_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    memory_id          uuid NOT NULL
        REFERENCES mimir.memory_records(memory_id)
        ON DELETE RESTRICT,

    decision           text NOT NULL
        CHECK (decision IN ('approve', 'reject')),

    reviewer           text NOT NULL,
    reason             text,

    previous_status    text NOT NULL,
    resulting_status   text NOT NULL,

    metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,

    reviewed_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (length(btrim(reviewer)) > 0),
    CHECK (jsonb_typeof(metadata) = 'object'),

    UNIQUE (memory_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS
    memory_records_active_key_uq
ON mimir.memory_records (
    scope_type,
    scope_key,
    memory_key
)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS
    memory_reviews_time_idx
ON mimir.memory_reviews (
    reviewed_at DESC
);

CREATE OR REPLACE FUNCTION mimir.review_memory (
    p_memory_id uuid,
    p_decision  text,
    p_reviewer  text,
    p_reason    text DEFAULT NULL,
    p_metadata  jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_memory            mimir.memory_records%ROWTYPE;
    v_review_id         uuid;
    v_existing_decision text;
    v_resulting_status  text;
    v_active_conflict   uuid;
BEGIN
    IF p_memory_id IS NULL THEN
        RAISE EXCEPTION 'memory_id obrigatório';
    END IF;

    IF p_decision NOT IN ('approve', 'reject') THEN
        RAISE EXCEPTION
            'decisão inválida: %',
            p_decision;
    END IF;

    IF p_reviewer IS NULL OR btrim(p_reviewer) = '' THEN
        RAISE EXCEPTION 'reviewer obrigatório';
    END IF;

    IF p_decision = 'reject'
       AND (p_reason IS NULL OR btrim(p_reason) = '')
    THEN
        RAISE EXCEPTION
            'motivo obrigatório para rejeição';
    END IF;

    IF jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' THEN
        RAISE EXCEPTION
            'metadata deve ser um objeto JSON';
    END IF;

    SELECT
        review_id,
        decision
    INTO
        v_review_id,
        v_existing_decision
    FROM mimir.memory_reviews
    WHERE memory_id = p_memory_id;

    IF FOUND THEN
        IF v_existing_decision = p_decision THEN
            RETURN v_review_id;
        END IF;

        RAISE EXCEPTION
            'memória já revisada com decisão diferente: %',
            v_existing_decision;
    END IF;

    SELECT *
    INTO v_memory
    FROM mimir.memory_records
    WHERE memory_id = p_memory_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'memória não encontrada: %',
            p_memory_id;
    END IF;

    IF v_memory.status <> 'candidate' THEN
        RAISE EXCEPTION
            'somente candidatos podem ser revisados; status atual: %',
            v_memory.status;
    END IF;

    IF p_decision = 'approve' THEN
        SELECT memory_id
        INTO v_active_conflict
        FROM mimir.memory_records
        WHERE scope_type = v_memory.scope_type
          AND scope_key = v_memory.scope_key
          AND memory_key = v_memory.memory_key
          AND status = 'active'
          AND memory_id <> p_memory_id
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION
                'já existe memória ativa para a chave %: %',
                v_memory.memory_key,
                v_active_conflict;
        END IF;

        v_resulting_status := 'active';
    ELSE
        v_resulting_status := 'rejected';
    END IF;

    UPDATE mimir.memory_records
    SET
        status = v_resulting_status,
        valid_from = CASE
            WHEN v_resulting_status = 'active'
                THEN now()
            ELSE valid_from
        END
    WHERE memory_id = p_memory_id;

    INSERT INTO mimir.memory_reviews (
        memory_id,
        decision,
        reviewer,
        reason,
        previous_status,
        resulting_status,
        metadata
    )
    VALUES (
        p_memory_id,
        p_decision,
        p_reviewer,
        nullif(btrim(p_reason), ''),
        v_memory.status,
        v_resulting_status,
        jsonb_build_object(
            'session_user',
            session_user
        ) || coalesce(p_metadata, '{}'::jsonb)
    )
    RETURNING review_id
    INTO v_review_id;

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
        p_reviewer,
        p_decision,
        'memory_record',
        p_memory_id,
        v_memory.scope_type,
        v_memory.scope_key,
        jsonb_build_object(
            'review_id',
            v_review_id,
            'memory_key',
            v_memory.memory_key,
            'previous_status',
            v_memory.status,
            'resulting_status',
            v_resulting_status,
            'reason',
            p_reason,
            'session_user',
            session_user
        )
    );

    RETURN v_review_id;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    text,
    jsonb
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    text,
    jsonb
)
FROM mimir_app;

GRANT USAGE
ON SCHEMA mimir
TO mimir_reviewer;

GRANT SELECT
ON mimir.pending_memory_review
TO mimir_reviewer;

GRANT SELECT
ON mimir.memory_reviews
TO mimir_reviewer;

GRANT EXECUTE
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    text,
    jsonb
)
TO mimir_reviewer;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    4,
    'Revisão humana e aprovação controlada de memórias'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
