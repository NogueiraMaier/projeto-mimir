\set ON_ERROR_STOP on

-- Operational memory_handoff v1 ingestion.
--
-- This bridge receives only the already-sanitized confidential handoff emitted
-- by ops_workflow.memory_handoff(). It does not review, approve, promote or
-- generate embeddings. Permanent promotion remains exclusively human.
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '3min';
SET LOCAL idle_in_transaction_session_timeout = '3min';

LOCK TABLE
    mimir.schema_version,
    mimir.memory_events
IN SHARE ROW EXCLUSIVE MODE;

DO $preconditions$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 15
          AND description =
              'Detecção determinística de duplicidade e contradição entre candidate e active'
    ) THEN
        RAISE EXCEPTION
            'memory migration 015 required';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mimir.schema_version
        WHERE version = 16
    ) THEN
        RAISE EXCEPTION
            'migration 016 already applied';
    END IF;
END
$preconditions$;

SET LOCAL ROLE mimir_owner;
SET LOCAL search_path = pg_catalog, mimir, public;

CREATE OR REPLACE FUNCTION mimir.ingest_operational_handoff_v1(
    p_event_id        uuid,
    p_content         text,
    p_content_sha256  text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, mimir, public
AS $function$
DECLARE
    v_document       jsonb;
    v_actual_hash    text;
    v_source_ref     text;
    v_device_id      text;
    v_occurred_at    timestamptz;
    v_event_id       uuid;
    v_existing_hash  text;
    v_existing_text  text;
BEGIN
    IF session_user IS DISTINCT FROM 'mimir_app' THEN
        RAISE EXCEPTION
            'sessão não autorizada para memory_handoff: %',
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

    IF p_content IS NULL
       OR btrim(p_content) = ''
       OR octet_length(p_content) > 1048576
    THEN
        RAISE EXCEPTION
            'conteúdo do handoff vazio ou acima de 1 MiB';
    END IF;

    IF p_content_sha256 IS NULL
       OR p_content_sha256 !~ '^[0-9a-f]{64}$'
    THEN
        RAISE EXCEPTION
            'SHA-256 do handoff inválido';
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
            'SHA-256 do handoff não corresponde ao conteúdo';
    END IF;

    BEGIN
        v_document := p_content::jsonb;
    EXCEPTION
        WHEN others THEN
            RAISE EXCEPTION
                'memory_handoff não contém JSON válido';
    END;

    IF jsonb_typeof(v_document) <> 'object' THEN
        RAISE EXCEPTION
            'memory_handoff deve ser objeto JSON';
    END IF;

    IF NOT (
        v_document ?& ARRAY[
            'schema_version',
            'integration',
            'state',
            'source_ref',
            'client_id',
            'site_id',
            'device_id',
            'project',
            'classification',
            'record_type',
            'occurred_at',
            'confidence',
            'found_state',
            'changes',
            'validation',
            'inventory_updated',
            'deduplication_key',
            'requires',
            'automatic_promotion'
        ]
    ) THEN
        RAISE EXCEPTION
            'memory_handoff incompleto';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_object_keys(v_document) AS item(key)
        WHERE item.key NOT IN (
            'schema_version',
            'integration',
            'state',
            'source_ref',
            'client_id',
            'site_id',
            'device_id',
            'project',
            'classification',
            'record_type',
            'occurred_at',
            'confidence',
            'found_state',
            'changes',
            'validation',
            'inventory_updated',
            'deduplication_key',
            'requires',
            'automatic_promotion'
        )
    ) THEN
        RAISE EXCEPTION
            'memory_handoff v1 contém campo desconhecido';
    END IF;

    IF v_document -> 'schema_version'
       IS DISTINCT FROM '1'::jsonb
    THEN
        RAISE EXCEPTION 'schema_version inválida';
    END IF;

    IF v_document ->> 'integration' <> 'PARCIAL'
       OR v_document ->> 'state' <> 'pending_human_review'
    THEN
        RAISE EXCEPTION
            'estado de integração inválido';
    END IF;

    IF v_document ->> 'project' <> 'projeto-mimir'
       OR v_document ->> 'classification' <> 'confidential'
       OR v_document ->> 'record_type' <> 'evidence'
       OR v_document ->> 'confidence'
          <> 'collected_not_independently_reviewed'
    THEN
        RAISE EXCEPTION
            'contrato de classificação do handoff inválido';
    END IF;

    IF v_document -> 'automatic_promotion'
       IS DISTINCT FROM 'false'::jsonb
    THEN
        RAISE EXCEPTION
            'automatic_promotion deve permanecer false';
    END IF;

    IF v_document -> 'inventory_updated'
       IS DISTINCT FROM 'true'::jsonb
    THEN
        RAISE EXCEPTION
            'inventário não confirmado';
    END IF;

    IF jsonb_typeof(v_document -> 'validation') <> 'object'
       OR v_document #> '{validation,performed}'
          IS DISTINCT FROM 'true'::jsonb
       OR v_document #> '{validation,passed}'
          IS DISTINCT FROM 'true'::jsonb
    THEN
        RAISE EXCEPTION
            'validação operacional não aprovada';
    END IF;

    IF jsonb_typeof(v_document -> 'found_state') <> 'array'
       OR jsonb_array_length(
           v_document -> 'found_state'
       ) < 1
    THEN
        RAISE EXCEPTION
            'found_state inválido';
    END IF;

    IF jsonb_typeof(v_document -> 'changes') <> 'array' THEN
        RAISE EXCEPTION
            'changes deve ser array';
    END IF;

    IF jsonb_typeof(v_document -> 'requires') <> 'array'
       OR jsonb_array_length(
           v_document -> 'requires'
       ) <> 4
       OR NOT (
           (v_document -> 'requires') @>
           '[
             "review",
             "deduplication",
             "contradiction_check",
             "version_preservation"
           ]'::jsonb
       )
    THEN
        RAISE EXCEPTION
            'requisitos de revisão do handoff inválidos';
    END IF;

    v_source_ref := v_document ->> 'source_ref';
    v_device_id := v_document ->> 'device_id';

    IF v_source_ref IS DISTINCT FROM
       'ops:' || p_event_id::text
    THEN
        RAISE EXCEPTION
            'source_ref não corresponde ao intervention_id';
    END IF;

    IF v_document ->> 'deduplication_key'
       IS DISTINCT FROM p_event_id::text
    THEN
        RAISE EXCEPTION
            'deduplication_key não corresponde ao intervention_id';
    END IF;

    IF v_device_id IS NULL
       OR btrim(v_device_id) = ''
       OR length(v_device_id) > 128
    THEN
        RAISE EXCEPTION
            'device_id inválido';
    END IF;

    BEGIN
        PERFORM v_device_id::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION
                'device_id deve ser UUID';
    END;

    BEGIN
        v_occurred_at :=
            (v_document ->> 'occurred_at')::timestamptz;
    EXCEPTION
        WHEN others THEN
            RAISE EXCEPTION
                'occurred_at inválido';
    END;

    IF v_occurred_at >
       clock_timestamp() + interval '5 minutes'
    THEN
        RAISE EXCEPTION
            'occurred_at está no futuro';
    END IF;

    INSERT INTO mimir.memory_events (
        event_id,
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
        p_event_id,
        v_occurred_at,
        'system',
        'mimir',
        'operational_memory_handoff',
        'ops-memory-handoff-v1',
        v_source_ref,
        'mimir-ops-handoff',
        'confidential',
        p_content,
        p_content_sha256,
        jsonb_build_object(
            'schema_version', 1,
            'intervention_id', p_event_id,
            'device_id', v_device_id,
            'deduplication_key',
                v_document ->> 'deduplication_key',
            'handoff_sha256', p_content_sha256,
            'requires_human_review', true,
            'automatic_promotion', false
        )
    )
    ON CONFLICT DO NOTHING
    RETURNING event_id
    INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT
            event_id,
            content_sha256,
            content
        INTO
            v_event_id,
            v_existing_hash,
            v_existing_text
        FROM mimir.memory_events
        WHERE source_type = 'ops-memory-handoff-v1'
          AND source_ref = v_source_ref
          AND content_sha256 = p_content_sha256
        ORDER BY ingested_at
        LIMIT 1;

        IF NOT FOUND
           OR v_event_id IS DISTINCT FROM p_event_id
           OR v_existing_hash IS DISTINCT FROM p_content_sha256
           OR v_existing_text IS DISTINCT FROM p_content
        THEN
            RAISE EXCEPTION
                'intervention_id já existe com conteúdo diferente';
        END IF;
    END IF;

    RETURN v_event_id;
END;
$function$;

REVOKE ALL
ON FUNCTION mimir.ingest_operational_handoff_v1(
    uuid,
    text,
    text
)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION mimir.ingest_operational_handoff_v1(
    uuid,
    text,
    text
)
TO mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    16,
    'Ingestão controlada do memory_handoff operacional v1'
);

RESET ROLE;

COMMIT;
