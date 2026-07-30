\set ON_ERROR_STOP on

BEGIN;

DO $role$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'mimir_human'
    ) THEN
        CREATE ROLE mimir_human
            LOGIN
            NOINHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT 3;
    END IF;
END
$role$;

ALTER ROLE mimir_human
    LOGIN
    NOINHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 3;

ALTER ROLE mimir_human PASSWORD NULL;

ALTER ROLE mimir_reviewer
    NOLOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

GRANT mimir_reviewer
TO mimir_human
WITH INHERIT FALSE, SET TRUE;

REVOKE ALL
ON DATABASE mimir_memory
FROM mimir_human;

GRANT CONNECT
ON DATABASE mimir_memory
TO mimir_human;

ALTER ROLE mimir_human
IN DATABASE mimir_memory
SET search_path = mimir, public;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE TABLE IF NOT EXISTS mimir.reviewer_identities (
    db_role                 name PRIMARY KEY,
    display_name            text NOT NULL,
    expected_system_user    text NOT NULL UNIQUE,
    enabled                 boolean NOT NULL DEFAULT true,
    metadata                jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at              timestamptz NOT NULL DEFAULT now(),

    CHECK (length(btrim(display_name)) > 0),
    CHECK (length(btrim(expected_system_user)) > 0),
    CHECK (jsonb_typeof(metadata) = 'object')
);

INSERT INTO mimir.reviewer_identities (
    db_role,
    display_name,
    expected_system_user,
    enabled,
    metadata
)
VALUES (
    'mimir_human',
    'Nogueira Maier',
    'peer:nogueiramaier',
    true,
    jsonb_build_object(
        'linux_user',
        'nogueiramaier',
        'authentication',
        'peer'
    )
)
ON CONFLICT (db_role)
DO UPDATE SET
    display_name = EXCLUDED.display_name,
    expected_system_user = EXCLUDED.expected_system_user,
    enabled = EXCLUDED.enabled,
    metadata = EXCLUDED.metadata;

ALTER TABLE mimir.memory_reviews
    ADD COLUMN IF NOT EXISTS reviewer_role name;

ALTER TABLE mimir.memory_reviews
    ADD COLUMN IF NOT EXISTS authentication_identity text;

CREATE OR REPLACE FUNCTION mimir.review_memory (
    p_memory_id uuid,
    p_decision  text,
    p_reason    text DEFAULT NULL,
    p_metadata  jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_memory             mimir.memory_records%ROWTYPE;
    v_review_id          uuid;
    v_existing_decision  text;
    v_resulting_status   text;
    v_active_conflict    uuid;

    v_login_role         name := session_user;
    v_auth_identity      text := system_user;
    v_reviewer           text;
BEGIN
    SELECT display_name
    INTO v_reviewer
    FROM mimir.reviewer_identities
    WHERE db_role = v_login_role
      AND enabled = true
      AND expected_system_user = v_auth_identity;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'identidade de revisão não autorizada: role=%, autenticação=%',
            v_login_role,
            coalesce(v_auth_identity, '<não autenticada>');
    END IF;

    IF NOT pg_has_role(
        v_login_role,
        'mimir_reviewer',
        'SET'
    ) THEN
        RAISE EXCEPTION
            'role % não possui elevação autorizada para mimir_reviewer',
            v_login_role;
    END IF;

    IF p_memory_id IS NULL THEN
        RAISE EXCEPTION 'memory_id obrigatório';
    END IF;

    IF p_decision NOT IN ('approve', 'reject') THEN
        RAISE EXCEPTION
            'decisão inválida: %',
            p_decision;
    END IF;

    IF p_decision = 'reject'
       AND (
           p_reason IS NULL
           OR btrim(p_reason) = ''
       )
    THEN
        RAISE EXCEPTION
            'motivo obrigatório para rejeição';
    END IF;

    IF jsonb_typeof(
        coalesce(p_metadata, '{}'::jsonb)
    ) <> 'object'
    THEN
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
        reviewer_role,
        authentication_identity,
        reason,
        previous_status,
        resulting_status,
        metadata
    )
    VALUES (
        p_memory_id,
        p_decision,
        v_reviewer,
        v_login_role,
        v_auth_identity,
        nullif(btrim(p_reason), ''),
        v_memory.status,
        v_resulting_status,
        jsonb_build_object(
            'session_user',
            v_login_role,
            'system_user',
            v_auth_identity
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
        v_reviewer,
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
            'reviewer_role',
            v_login_role,
            'authentication_identity',
            v_auth_identity
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
    jsonb
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    jsonb
)
FROM mimir_app;

REVOKE ALL
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    jsonb
)
FROM mimir_human;

GRANT EXECUTE
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    jsonb
)
TO mimir_reviewer;

REVOKE ALL
ON FUNCTION mimir.review_memory(
    uuid,
    text,
    text,
    text,
    jsonb
)
FROM PUBLIC, mimir_app, mimir_reviewer, mimir_human;

DROP FUNCTION IF EXISTS mimir.review_memory(
    uuid,
    text,
    text,
    text,
    jsonb
);

REVOKE ALL
ON mimir.reviewer_identities
FROM PUBLIC, mimir_app, mimir_human, mimir_reviewer;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    5,
    'Revisor humano autenticado por peer e identidade não falsificável'
)
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
