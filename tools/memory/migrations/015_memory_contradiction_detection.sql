\set ON_ERROR_STOP on

-- Deterministic candidate conflict classification.
--
-- The semantic identity of a memory is:
--   scope_type + scope_key + memory_key
--
-- Against the currently active memory for that identity:
--   no active record     -> none
--   same content hash    -> duplicate
--   different hash       -> contradiction
--
-- No memory content is returned by this function.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '3min';
SET LOCAL idle_in_transaction_session_timeout = '3min';

LOCK TABLE mimir.schema_version
IN SHARE ROW EXCLUSIVE MODE;

DO $preconditions$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 14
          AND description =
              'Ingestão protegida de sessões via OpenClaw chat.history v2'
    ) THEN
        RAISE EXCEPTION
            'memory migration 014 required';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 15
    ) THEN
        RAISE EXCEPTION
            'migration 015 already applied';
    END IF;

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

CREATE OR REPLACE FUNCTION mimir.inspect_candidate_conflict (
    p_memory_id uuid
)
RETURNS TABLE (
    classification              text,
    candidate_memory_id         uuid,
    active_memory_id            uuid,
    scope_type                  text,
    scope_key                   text,
    memory_key                  text,
    candidate_content_sha256    text,
    active_content_sha256       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_candidate mimir.memory_records%ROWTYPE;
    v_active    mimir.memory_records%ROWTYPE;
    v_result    text;
BEGIN
    IF p_memory_id IS NULL THEN
        RAISE EXCEPTION
            'memory_id obrigatório';
    END IF;

    SELECT *
    INTO v_candidate
    FROM mimir.memory_records
    WHERE memory_id = p_memory_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'memória não encontrada: %',
            p_memory_id;
    END IF;

    IF v_candidate.status <> 'candidate' THEN
        RAISE EXCEPTION
            'somente candidate pode ser inspecionada; status atual: %',
            v_candidate.status;
    END IF;

    SELECT *
    INTO v_active
    FROM mimir.memory_records
    WHERE scope_type = v_candidate.scope_type
      AND scope_key = v_candidate.scope_key
      AND memory_key = v_candidate.memory_key
      AND status = 'active'
      AND memory_id <> v_candidate.memory_id
    LIMIT 1;

    IF NOT FOUND THEN
        v_result := 'none';

        RETURN QUERY
        SELECT
            v_result,
            v_candidate.memory_id,
            NULL::uuid,
            v_candidate.scope_type,
            v_candidate.scope_key,
            v_candidate.memory_key,
            v_candidate.content_sha256,
            NULL::text;

        RETURN;
    END IF;

    IF v_active.content_sha256 =
       v_candidate.content_sha256
    THEN
        v_result := 'duplicate';
    ELSE
        v_result := 'contradiction';
    END IF;

    RETURN QUERY
    SELECT
        v_result,
        v_candidate.memory_id,
        v_active.memory_id,
        v_candidate.scope_type,
        v_candidate.scope_key,
        v_candidate.memory_key,
        v_candidate.content_sha256,
        v_active.content_sha256;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.inspect_candidate_conflict(uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION mimir.inspect_candidate_conflict(uuid)
TO
    mimir_app,
    mimir_reviewer;

COMMENT ON FUNCTION mimir.inspect_candidate_conflict(uuid)
IS
'Classifica candidate contra a memória active da mesma identidade sem expor conteúdo: none, duplicate ou contradiction.';

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    15,
    'Detecção determinística de duplicidade e contradição entre candidate e active'
);

RESET ROLE;

COMMIT;
