\set ON_ERROR_STOP on

-- Canonical reconstruction of Mímir memory schema version 1.
-- This is NOT the recovered historical migration 001.
-- It is a reproducible bootstrap derived from:
--   * the production schema observed read-only on 2026-09-24;
--   * the known deltas in versioned migrations 002..012;
--   * the recorded version-1 description.
--
-- Safety: intended only for an empty mimir_memory database.

BEGIN;

DO $bootstrap$
BEGIN
    IF current_database() <> 'mimir_memory' THEN
        RAISE EXCEPTION
            'canonical bootstrap requires database mimir_memory; current=%',
            current_database();
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_namespace
        WHERE nspname = 'mimir'
    ) THEN
        RAISE EXCEPTION
            'canonical bootstrap requires an empty database without schema mimir';
    END IF;
END
$bootstrap$;

DO $roles$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'mimir_owner'
    ) THEN
        CREATE ROLE mimir_owner
            NOLOGIN
            INHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'mimir_app'
    ) THEN
        CREATE ROLE mimir_app
            LOGIN
            INHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS;
    END IF;
END
$roles$;

ALTER ROLE mimir_owner
    NOLOGIN
    INHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

ALTER ROLE mimir_app
    LOGIN
    INHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

ALTER ROLE mimir_app PASSWORD NULL;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

ALTER DATABASE mimir_memory OWNER TO mimir_owner;

REVOKE ALL ON DATABASE mimir_memory FROM PUBLIC;
GRANT CONNECT, TEMPORARY
ON DATABASE mimir_memory
TO mimir_app;

ALTER ROLE mimir_app
IN DATABASE mimir_memory
SET search_path = mimir, public;

CREATE SCHEMA mimir AUTHORIZATION mimir_owner;
REVOKE ALL ON SCHEMA mimir FROM PUBLIC;
GRANT USAGE ON SCHEMA mimir TO mimir_app;

SET ROLE mimir_owner;
SET search_path = mimir, public;

CREATE TABLE mimir.schema_version (
    version      integer PRIMARY KEY,
    description  text NOT NULL,
    applied_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE mimir.memory_events (
    event_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    occurred_at      timestamptz NOT NULL DEFAULT now(),
    ingested_at      timestamptz NOT NULL DEFAULT now(),
    scope_type       text NOT NULL DEFAULT 'system',
    scope_key        text NOT NULL DEFAULT 'mimir',
    event_type       text NOT NULL,
    source_type      text NOT NULL DEFAULT 'internal',
    source_ref       text,
    actor            text NOT NULL DEFAULT 'mimir',
    classification   text NOT NULL DEFAULT 'internal',
    content          text,
    content_sha256   text,
    payload          jsonb NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT memory_events_scope_type_check
        CHECK (length(btrim(scope_type)) > 0),

    CONSTRAINT memory_events_scope_key_check
        CHECK (length(btrim(scope_key)) > 0),

    CONSTRAINT memory_events_event_type_check
        CHECK (length(btrim(event_type)) > 0),

    CONSTRAINT memory_events_classification_check
        CHECK (
            classification IN (
                'public',
                'internal',
                'confidential',
                'restricted'
            )
        ),

    CONSTRAINT memory_events_payload_check
        CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE mimir.memory_records (
    memory_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    memory_key         text NOT NULL,
    memory_type        text NOT NULL,
    status             text NOT NULL DEFAULT 'candidate',
    scope_type         text NOT NULL DEFAULT 'system',
    scope_key          text NOT NULL DEFAULT 'mimir',
    title              text,
    summary            text,
    content            text NOT NULL,
    source_event_id    uuid,
    valid_from         timestamptz NOT NULL DEFAULT now(),
    valid_until        timestamptz,
    superseded_by      uuid,
    confidence         numeric(4,3) NOT NULL DEFAULT 0.500,
    importance         numeric(4,3) NOT NULL DEFAULT 0.500,
    decay_rate         numeric(6,5) NOT NULL DEFAULT 0.01000,
    pinned             boolean NOT NULL DEFAULT false,
    access_count       bigint NOT NULL DEFAULT 0,
    last_accessed_at   timestamptz,
    expires_at         timestamptz,
    embedding          public.vector(768),
    embedding_model    text,
    metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    created_by         text NOT NULL DEFAULT 'mimir',
    search_document    tsvector GENERATED ALWAYS AS (
        to_tsvector(
            'portuguese'::regconfig,
            (
                (
                    coalesce(title, '') || ' ' ||
                    coalesce(summary, '')
                ) || ' ' || content
            )
        )
    ) STORED,

    CONSTRAINT memory_records_memory_key_check
        CHECK (length(btrim(memory_key)) > 0),

    CONSTRAINT memory_records_memory_type_check
        CHECK (
            memory_type IN (
                'semantic',
                'episodic',
                'procedural',
                'decision',
                'task',
                'evidence',
                'preference',
                'entity'
            )
        ),

    CONSTRAINT memory_records_status_check
        CHECK (
            status IN (
                'candidate',
                'active',
                'superseded',
                'rejected',
                'expired',
                'archived'
            )
        ),

    CONSTRAINT memory_records_content_check
        CHECK (length(btrim(content)) > 0),

    CONSTRAINT memory_records_confidence_check
        CHECK (confidence >= 0 AND confidence <= 1),

    CONSTRAINT memory_records_importance_check
        CHECK (importance >= 0 AND importance <= 1),

    CONSTRAINT memory_records_decay_rate_check
        CHECK (decay_rate >= 0 AND decay_rate <= 1),

    CONSTRAINT memory_records_access_count_check
        CHECK (access_count >= 0),

    CONSTRAINT memory_records_check
        CHECK (valid_until IS NULL OR valid_until > valid_from),

    CONSTRAINT memory_records_check1
        CHECK (expires_at IS NULL OR expires_at > created_at),

    CONSTRAINT memory_records_check2
        CHECK (superseded_by IS NULL OR superseded_by <> memory_id),

    CONSTRAINT memory_records_source_event_id_fkey
        FOREIGN KEY (source_event_id)
        REFERENCES mimir.memory_events(event_id)
        ON DELETE RESTRICT,

    CONSTRAINT memory_records_superseded_by_fkey
        FOREIGN KEY (superseded_by)
        REFERENCES mimir.memory_records(memory_id)
        ON DELETE SET NULL
);

CREATE TABLE mimir.memory_relations (
    relation_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_memory_id    uuid NOT NULL,
    to_memory_id      uuid NOT NULL,
    relation_type     text NOT NULL,
    confidence        numeric(4,3) NOT NULL DEFAULT 0.500,
    valid_from        timestamptz NOT NULL DEFAULT now(),
    valid_until       timestamptz,
    metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),
    created_by        text NOT NULL DEFAULT 'mimir',

    CONSTRAINT memory_relations_check
        CHECK (from_memory_id <> to_memory_id),

    CONSTRAINT memory_relations_check1
        CHECK (valid_until IS NULL OR valid_until > valid_from),

    CONSTRAINT memory_relations_confidence_check
        CHECK (confidence >= 0 AND confidence <= 1),

    CONSTRAINT memory_relations_metadata_check
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT memory_relations_relation_type_check
        CHECK (length(btrim(relation_type)) > 0),

    CONSTRAINT memory_relations_from_memory_id_fkey
        FOREIGN KEY (from_memory_id)
        REFERENCES mimir.memory_records(memory_id)
        ON DELETE RESTRICT,

    CONSTRAINT memory_relations_to_memory_id_fkey
        FOREIGN KEY (to_memory_id)
        REFERENCES mimir.memory_records(memory_id)
        ON DELETE RESTRICT,

    CONSTRAINT memory_relations_from_memory_id_to_memory_id_relation_type__key
        UNIQUE (
            from_memory_id,
            to_memory_id,
            relation_type,
            valid_from
        )
);

CREATE TABLE mimir.memory_audit (
    audit_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recorded_at    timestamptz NOT NULL DEFAULT now(),
    actor          text NOT NULL,
    action         text NOT NULL,
    object_type    text NOT NULL,
    object_id      uuid,
    scope_type     text NOT NULL DEFAULT 'system',
    scope_key      text NOT NULL DEFAULT 'mimir',
    details        jsonb NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT memory_audit_actor_check
        CHECK (length(btrim(actor)) > 0),

    CONSTRAINT memory_audit_action_check
        CHECK (length(btrim(action)) > 0),

    CONSTRAINT memory_audit_object_type_check
        CHECK (length(btrim(object_type)) > 0),

    CONSTRAINT memory_audit_details_check
        CHECK (jsonb_typeof(details) = 'object')
);

CREATE INDEX memory_events_scope_time_idx
ON mimir.memory_events (
    scope_type,
    scope_key,
    occurred_at DESC
);

CREATE INDEX memory_events_type_time_idx
ON mimir.memory_events (
    event_type,
    occurred_at DESC
);

CREATE INDEX memory_records_key_idx
ON mimir.memory_records (
    scope_type,
    scope_key,
    memory_key
);

CREATE INDEX memory_records_scope_status_idx
ON mimir.memory_records (
    scope_type,
    scope_key,
    status,
    valid_from DESC
);

CREATE INDEX memory_records_search_gin_idx
ON mimir.memory_records
USING gin (search_document);

CREATE INDEX memory_records_source_event_idx
ON mimir.memory_records (source_event_id);

CREATE INDEX memory_records_type_idx
ON mimir.memory_records (
    memory_type,
    status
);

CREATE INDEX memory_relations_from_idx
ON mimir.memory_relations (
    from_memory_id,
    relation_type
);

CREATE INDEX memory_relations_to_idx
ON mimir.memory_relations (
    to_memory_id,
    relation_type
);

-- Baseline privileges inferred from the later revocations in migrations 002, 003
-- and 009. UPDATE/DELETE are intentionally never granted.
GRANT SELECT
ON TABLE
    mimir.schema_version,
    mimir.memory_events,
    mimir.memory_records,
    mimir.memory_relations,
    mimir.memory_audit
TO mimir_app;

GRANT INSERT
ON TABLE
    mimir.memory_events,
    mimir.memory_records,
    mimir.memory_relations,
    mimir.memory_audit
TO mimir_app;

INSERT INTO mimir.schema_version (
    version,
    description
)
VALUES (
    1,
    'Estrutura temporal inicial da memória do Mimir'
);

RESET ROLE;

COMMIT;
