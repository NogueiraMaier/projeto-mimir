\set ON_ERROR_STOP on
-- Cluster-global/privilege provisioning for migration 013.
-- Run only after 013_operational_inventory.sql in the reviewed target database.
-- This file is deliberately separate so disposable schema tests never create or
-- alter the production role or assume a database name.
BEGIN;
DO $role$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'mimir_ops') THEN
        RAISE EXCEPTION 'mimir_ops already exists: inspect before provisioning';
    END IF;
    CREATE ROLE mimir_ops LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE
        NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 3;
END
$role$;
ALTER ROLE mimir_ops PASSWORD NULL;
DO $grant$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO mimir_ops', current_database());
END
$grant$;
SET ROLE mimir_owner;
GRANT USAGE ON SCHEMA mimir TO mimir_ops;
GRANT EXECUTE ON FUNCTION mimir.ops_api(jsonb) TO mimir_ops;
REVOKE ALL ON FUNCTION mimir.ops_assert_identity(), mimir.ops_assert_object(jsonb,text[],text[]),
    mimir.ops_device_document(uuid) FROM mimir_ops;
REVOKE ALL ON mimir.ops_identities, mimir.ops_clients, mimir.ops_sites, mimir.ops_devices,
    mimir.ops_interfaces, mimir.ops_addresses, mimir.ops_networks, mimir.ops_vlans, mimir.ops_accesses,
    mimir.ops_dependencies, mimir.ops_interventions, mimir.ops_actions, mimir.ops_evidence,
    mimir.ops_reports, mimir.ops_audit FROM mimir_ops;
REVOKE ALL ON SEQUENCE mimir.ops_actions_action_id_seq, mimir.ops_audit_audit_id_seq FROM mimir_ops;
RESET ROLE;
COMMIT;
