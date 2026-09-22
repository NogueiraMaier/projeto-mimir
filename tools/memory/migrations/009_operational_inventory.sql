\set ON_ERROR_STOP on

BEGIN;

SET ROLE mimir_owner;
SET search_path = mimir, public;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM mimir.schema_version WHERE version = 8
    ) THEN
        RAISE EXCEPTION 'migração 008 não foi localizada';
    END IF;
END
$migration$;

CREATE TABLE IF NOT EXISTS mimir.ops_clients (
    client_id uuid PRIMARY KEY,
    slug text NOT NULL UNIQUE,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (slug ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    CHECK (length(btrim(name)) BETWEEN 1 AND 200)
);

CREATE TABLE IF NOT EXISTS mimir.ops_sites (
    site_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES mimir.ops_clients(client_id) ON DELETE RESTRICT,
    slug text NOT NULL,
    name text NOT NULL,
    location_note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (client_id, slug),
    CHECK (slug ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    CHECK (length(btrim(name)) BETWEEN 1 AND 200)
);

CREATE TABLE IF NOT EXISTS mimir.ops_devices (
    device_id uuid PRIMARY KEY,
    site_id uuid NOT NULL REFERENCES mimir.ops_sites(site_id) ON DELETE RESTRICT,
    name text NOT NULL,
    device_type text NOT NULL,
    vendor text,
    model text,
    management_host text NOT NULL,
    management_port integer NOT NULL DEFAULT 22,
    ssh_user text NOT NULL,
    adapter text NOT NULL,
    permission_mode text NOT NULL DEFAULT 'READ',
    credential_ref text NOT NULL DEFAULT 'ssh-agent',
    firmware text,
    verified_at timestamptz,
    last_change_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (site_id, name),
    CHECK (management_port BETWEEN 1 AND 65535),
    CHECK (adapter IN ('generic-linux', 'mikrotik-routeros')),
    CHECK (permission_mode IN ('READ', 'PLAN', 'EXECUTE')),
    CHECK (credential_ref ~ '^(ssh-agent|env:[A-Z0-9_]+|file-ref:[A-Za-z0-9._-]+)$'),
    CHECK (ssh_user ~ '^[A-Za-z0-9._-]{1,64}$')
);

CREATE TABLE IF NOT EXISTS mimir.ops_interventions (
    intervention_id uuid PRIMARY KEY,
    device_id uuid NOT NULL REFERENCES mimir.ops_devices(device_id) ON DELETE RESTRICT,
    objective text NOT NULL,
    requested_mode text NOT NULL,
    status text NOT NULL DEFAULT 'planned',
    approved_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    CHECK (requested_mode IN ('READ', 'PLAN', 'EXECUTE')),
    CHECK (status IN ('planned', 'running', 'succeeded', 'failed', 'blocked', 'cancelled')),
    CHECK (length(btrim(objective)) BETWEEN 1 AND 2000)
);

CREATE TABLE IF NOT EXISTS mimir.ops_actions (
    action_id bigserial PRIMARY KEY,
    intervention_id uuid NOT NULL REFERENCES mimir.ops_interventions(intervention_id) ON DELETE CASCADE,
    sequence_no integer NOT NULL,
    command_text text NOT NULL,
    classification text NOT NULL,
    status text NOT NULL DEFAULT 'planned',
    exit_code integer,
    stdout_redacted text,
    stderr_redacted text,
    started_at timestamptz,
    completed_at timestamptz,
    UNIQUE (intervention_id, sequence_no),
    CHECK (classification IN ('read', 'change')),
    CHECK (status IN ('planned', 'running', 'succeeded', 'failed', 'blocked'))
);

CREATE TABLE IF NOT EXISTS mimir.ops_evidence (
    evidence_id uuid PRIMARY KEY,
    intervention_id uuid NOT NULL REFERENCES mimir.ops_interventions(intervention_id) ON DELETE CASCADE,
    kind text NOT NULL,
    sha256 text NOT NULL,
    local_path text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (kind IN ('pre-snapshot', 'post-snapshot', 'backup', 'validation', 'rollback')),
    CHECK (sha256 ~ '^[0-9a-f]{64}$')
);

CREATE TABLE IF NOT EXISTS mimir.ops_reports (
    intervention_id uuid PRIMARY KEY REFERENCES mimir.ops_interventions(intervention_id) ON DELETE CASCADE,
    json_path text NOT NULL,
    markdown_path text NOT NULL,
    json_sha256 text NOT NULL,
    markdown_sha256 text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (json_sha256 ~ '^[0-9a-f]{64}$'),
    CHECK (markdown_sha256 ~ '^[0-9a-f]{64}$')
);

REVOKE ALL ON
    mimir.ops_clients,
    mimir.ops_sites,
    mimir.ops_devices,
    mimir.ops_interventions,
    mimir.ops_actions,
    mimir.ops_evidence,
    mimir.ops_reports
FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON
    mimir.ops_clients,
    mimir.ops_sites,
    mimir.ops_devices,
    mimir.ops_interventions,
    mimir.ops_actions,
    mimir.ops_evidence,
    mimir.ops_reports
TO mimir_app;

GRANT USAGE, SELECT ON SEQUENCE mimir.ops_actions_action_id_seq TO mimir_app;

INSERT INTO mimir.schema_version (version, description)
VALUES (9, 'Inventário operacional, intervenções, evidências e relatórios')
ON CONFLICT (version) DO NOTHING;

RESET ROLE;

COMMIT;
