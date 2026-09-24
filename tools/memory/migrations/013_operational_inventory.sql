\set ON_ERROR_STOP on
-- Development revision of unapplied 013. Deliberately refuses reapplication.
-- PostgreSQL 17 (system_user); existing memory schema and pgcrypto required.
-- Cluster-global role provisioning is intentionally separate in 013_operational_role.sql.
BEGIN;
DO $migration$
BEGIN
    IF NOT EXISTS (SELECT FROM mimir.schema_version WHERE version = 12) THEN
        RAISE EXCEPTION 'migration 012 required';
    END IF;
    IF EXISTS (SELECT FROM mimir.schema_version WHERE version = 13) THEN
        RAISE EXCEPTION '013 already applied: stop and review schema; do not overwrite';
    END IF;
END
$migration$;
SET ROLE mimir_owner;
SET search_path = pg_catalog, mimir;

CREATE TABLE mimir.ops_identities (
    db_role name PRIMARY KEY,
    authentication_identity text NOT NULL UNIQUE CHECK (authentication_identity ~ '^peer:[a-z_][a-z0-9_-]*$'),
    enabled boolean NOT NULL DEFAULT false
);
-- Deliberately disabled. Administrator must provision peer mapping + OS operator,
-- inspect grants and explicitly enable. Never reuse the OpenClaw app identity.
INSERT INTO mimir.ops_identities VALUES ('mimir_ops', 'peer:mimir-ops', false);

CREATE TABLE mimir.ops_clients (
    client_id uuid PRIMARY KEY,
    slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE mimir.ops_sites (
    site_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES mimir.ops_clients ON DELETE RESTRICT,
    slug text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    location_note text CHECK (length(location_note) <= 1000),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (client_id, slug)
);
CREATE TABLE mimir.ops_vlans (
    vlan_id uuid PRIMARY KEY,
    site_id uuid NOT NULL REFERENCES mimir.ops_sites,
    tag integer NOT NULL CHECK (tag BETWEEN 1 AND 4094),
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    UNIQUE (site_id, tag), UNIQUE (site_id, vlan_id)
);
CREATE TABLE mimir.ops_networks (
    network_id uuid PRIMARY KEY,
    site_id uuid NOT NULL REFERENCES mimir.ops_sites,
    prefix cidr NOT NULL,
    vlan_id uuid,
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    UNIQUE (site_id, prefix), UNIQUE (site_id, network_id),
    FOREIGN KEY (site_id, vlan_id) REFERENCES mimir.ops_vlans(site_id, vlan_id)
);
CREATE TABLE mimir.ops_devices (
    device_id uuid PRIMARY KEY,
    site_id uuid NOT NULL REFERENCES mimir.ops_sites ON DELETE RESTRICT,
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    device_type text NOT NULL CHECK (length(btrim(device_type)) BETWEEN 1 AND 64),
    role text NOT NULL DEFAULT 'unspecified' CHECK (length(btrim(role)) BETWEEN 1 AND 64),
    vendor text CHECK (length(vendor) <= 200), model text CHECK (length(model) <= 200),
    firmware text CHECK (length(firmware) <= 200),
    management_host text NOT NULL CHECK (management_host ~ '^[a-zA-Z0-9:][a-zA-Z0-9.:-]{0,252}$'),
    management_port integer NOT NULL DEFAULT 22 CHECK (management_port BETWEEN 1 AND 65535),
    ssh_user text NOT NULL CHECK (ssh_user ~ '^[a-zA-Z_][a-zA-Z0-9._-]{0,63}$'),
    adapter text NOT NULL CHECK (adapter IN ('generic-linux', 'mikrotik-routeros')),
    permission_mode text NOT NULL DEFAULT 'READ' CHECK (permission_mode IN ('READ', 'PLAN', 'EXECUTE')),
    credential_ref text NOT NULL DEFAULT 'ssh-agent' CHECK (credential_ref ~ '^(ssh-agent|file-ref:[a-zA-Z0-9._-]{1,64})$'),
    primary_access_id uuid NOT NULL,
    verification_state text NOT NULL DEFAULT 'unverified' CHECK (verification_state IN ('unverified', 'verified')),
    verified_at timestamptz, last_collected_at timestamptz, last_change_at timestamptz,
    observed_state jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (site_id, name), UNIQUE (site_id, device_id),
    CHECK ((verification_state = 'verified') = (verified_at IS NOT NULL))
);
CREATE TABLE mimir.ops_interfaces (
    interface_id uuid PRIMARY KEY, site_id uuid NOT NULL, device_id uuid NOT NULL,
    name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    mac macaddr, mtu integer CHECK (mtu BETWEEN 68 AND 65535), role text, vlan_id uuid,
    FOREIGN KEY (site_id, vlan_id) REFERENCES mimir.ops_vlans(site_id, vlan_id),
    UNIQUE (device_id, name), UNIQUE (site_id, device_id, interface_id),
    FOREIGN KEY (site_id, device_id) REFERENCES mimir.ops_devices(site_id, device_id)
);
CREATE TABLE mimir.ops_addresses (
    address_id uuid PRIMARY KEY, site_id uuid NOT NULL, device_id uuid NOT NULL,
    interface_id uuid NOT NULL, address inet NOT NULL, network_id uuid,
    UNIQUE (interface_id, address),
    FOREIGN KEY (site_id, device_id, interface_id) REFERENCES mimir.ops_interfaces(site_id, device_id, interface_id),
    FOREIGN KEY (site_id, network_id) REFERENCES mimir.ops_networks(site_id, network_id)
);
CREATE TABLE mimir.ops_accesses (
    access_id uuid PRIMARY KEY, device_id uuid NOT NULL REFERENCES mimir.ops_devices,
    method text NOT NULL CHECK (method = 'ssh'),
    host text NOT NULL CHECK (host ~ '^[a-zA-Z0-9:][a-zA-Z0-9.:-]{0,252}$'),
    port integer NOT NULL CHECK (port BETWEEN 1 AND 65535),
    username text NOT NULL CHECK (username ~ '^[a-zA-Z_][a-zA-Z0-9._-]{0,63}$'),
    credential_ref text NOT NULL CHECK (credential_ref ~ '^(ssh-agent|file-ref:[a-zA-Z0-9._-]{1,64})$'),
    UNIQUE (access_id, device_id)
);
ALTER TABLE mimir.ops_devices
    ADD CONSTRAINT ops_devices_primary_access_fk
    FOREIGN KEY (primary_access_id, device_id)
    REFERENCES mimir.ops_accesses(access_id, device_id)
    DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE mimir.ops_dependencies (
    site_id uuid NOT NULL, device_id uuid NOT NULL, depends_on_device_id uuid NOT NULL,
    relation text NOT NULL CHECK (length(btrim(relation)) BETWEEN 1 AND 200),
    PRIMARY KEY (device_id, depends_on_device_id, relation),
    CHECK (device_id <> depends_on_device_id),
    FOREIGN KEY (site_id, device_id) REFERENCES mimir.ops_devices(site_id, device_id),
    FOREIGN KEY (depends_on_device_id) REFERENCES mimir.ops_devices(device_id)
);
CREATE TABLE mimir.ops_interventions (
    intervention_id uuid PRIMARY KEY,
    device_id uuid NOT NULL REFERENCES mimir.ops_devices ON DELETE RESTRICT,
    objective text NOT NULL CHECK (length(btrim(objective)) BETWEEN 1 AND 2000),
    requested_mode text NOT NULL CHECK (requested_mode IN ('READ', 'EXECUTE')),
    status text NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'collected', 'validated', 'failed')),
    plan jsonb NOT NULL, approval jsonb,
    initial_report jsonb NOT NULL, final_validation boolean NOT NULL DEFAULT false,
    inventory_updated boolean NOT NULL DEFAULT false,
    rollback_mode text NOT NULL DEFAULT 'manual' CHECK (rollback_mode = 'manual'),
    workflow_stage text NOT NULL CHECK (workflow_stage IN ('READ','PRECHECK','SNAPSHOT','BACKUP','EXECUTE','VALIDATE','DONE')),
    workflow_state text NOT NULL CHECK (workflow_state IN ('ready','intent','failed','complete')),
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(), completed_at timestamptz,
    created_by name NOT NULL DEFAULT session_user,
    authentication_identity text NOT NULL DEFAULT system_user,
    CHECK (requested_mode <> 'EXECUTE' OR approval IS NOT NULL),
    CHECK (status <> 'validated' OR (requested_mode = 'EXECUTE' AND final_validation AND inventory_updated AND completed_at IS NOT NULL)),
    CHECK (status <> 'collected' OR (requested_mode = 'READ' AND final_validation AND inventory_updated AND completed_at IS NOT NULL))
);
-- One outstanding execution per device; interrupted runs require reconciliation.
CREATE UNIQUE INDEX ops_one_execution ON mimir.ops_interventions(device_id)
    WHERE requested_mode = 'EXECUTE' AND status = 'running';
CREATE INDEX ops_history ON mimir.ops_interventions(device_id, started_at DESC, intervention_id);
CREATE TABLE mimir.ops_actions (
    action_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    intervention_id uuid NOT NULL REFERENCES mimir.ops_interventions ON DELETE RESTRICT,
    sequence_no integer NOT NULL,
    stage text NOT NULL CHECK (stage IN ('READ','PRECHECK','SNAPSHOT','BACKUP','EXECUTE','VALIDATE')),
    event_type text NOT NULL CHECK (event_type IN ('intent','result')),
    payload jsonb NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (intervention_id, sequence_no)
);
CREATE TABLE mimir.ops_evidence (
    evidence_id uuid PRIMARY KEY,
    intervention_id uuid NOT NULL REFERENCES mimir.ops_interventions ON DELETE RESTRICT,
    kind text NOT NULL, sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    payload jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE mimir.ops_reports (
    intervention_id uuid PRIMARY KEY REFERENCES mimir.ops_interventions ON DELETE RESTRICT,
    payload jsonb NOT NULL, json_text text NOT NULL, markdown text NOT NULL,
    json_sha256 text NOT NULL, markdown_sha256 text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE mimir.ops_audit (
    audit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor name NOT NULL DEFAULT session_user,
    authentication_identity text NOT NULL DEFAULT system_user,
    method text NOT NULL, object_id uuid NOT NULL,
    before_state jsonb, after_state jsonb NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Helpers are not callable by the application; qualified names and locked path.
CREATE FUNCTION mimir.ops_assert_identity() RETURNS void LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, mimir AS $$
BEGIN
    IF session_user IS DISTINCT FROM 'mimir_ops' OR NOT EXISTS (
        SELECT FROM mimir.ops_identities WHERE db_role = session_user AND enabled
        AND authentication_identity = system_user
    ) THEN
        RAISE EXCEPTION 'operational peer identity not authorized';
    END IF;
END $$;

CREATE FUNCTION mimir.ops_assert_object(p jsonb, allowed text[], required text[] DEFAULT '{}')
RETURNS void LANGUAGE plpgsql SET search_path = pg_catalog, mimir AS $$
BEGIN
    IF p IS NULL OR jsonb_typeof(p) <> 'object' THEN RAISE EXCEPTION 'object required'; END IF;
    IF EXISTS (SELECT FROM jsonb_object_keys(p) k WHERE NOT (k = ANY(allowed)))
       OR NOT (p ?& required) THEN RAISE EXCEPTION 'unexpected or missing fields'; END IF;
END $$;

CREATE FUNCTION mimir.ops_device_document(id uuid) RETURNS jsonb LANGUAGE sql
STABLE SET search_path = pg_catalog, mimir AS $$
    SELECT to_jsonb(d) || jsonb_build_object(
        'site', to_jsonb(s), 'client', to_jsonb(c),
        'interfaces', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY interface_id) FROM mimir.ops_interfaces x WHERE device_id=id),'[]'),
        'addresses', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY address_id) FROM mimir.ops_addresses x WHERE device_id=id),'[]'),
        'accesses', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY access_id) FROM mimir.ops_accesses x WHERE device_id=id),'[]'),
        'dependencies', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY depends_on_device_id) FROM mimir.ops_dependencies x WHERE device_id=id),'[]')
    ) FROM mimir.ops_devices d JOIN mimir.ops_sites s USING(site_id)
    JOIN mimir.ops_clients c USING(client_id) WHERE d.device_id=id;
$$;

CREATE FUNCTION mimir.ops_api(r jsonb) RETURNS jsonb LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, mimir AS $api$
DECLARE
    method text := r->>'method'; kind text := r->>'kind'; p jsonb := r->'payload';
    item jsonb; result jsonb; previous jsonb; id uuid; sid uuid; n integer; off integer;
    intervention mimir.ops_interventions%ROWTYPE; report jsonb; body text; md text;
    success boolean; last_action mimir.ops_actions%ROWTYPE;
BEGIN
    PERFORM mimir.ops_assert_identity();
    IF r IS NULL OR jsonb_typeof(r) <> 'object' OR octet_length(r::text) > 4194304 THEN
        RAISE EXCEPTION 'invalid request';
    END IF;
    -- Defense in depth. Never log rejected request contents in exception text.
    IF r::text ~* $secret$(password|passwd|senha|passphrase|token|secret|api[_-]?key|authorization|cookie|community|private[_ -]?key|preshared[_ -]?key)["[:space:]]*[:=]["[:space:]]*[^<]|-----BEGIN [A-Z ]*PRIVATE KEY|\m(nvapi-|sk-|ghp_|github_pat_)[A-Za-z0-9_-]{12,}|[a-z]+://[^ /]+:[^ /]+@$secret$ THEN
        RAISE EXCEPTION 'possible secret rejected';
    END IF;
    IF method IN ('inventory.add','inventory.list','inventory.show') AND
       (kind IS NULL OR kind NOT IN ('client','site','device')) THEN RAISE EXCEPTION 'invalid kind'; END IF;
    IF method = 'inventory.add' THEN
        IF kind = 'client' THEN
            PERFORM mimir.ops_assert_object(p, ARRAY['client_id','slug','name'], ARRAY['client_id','slug','name']);
            INSERT INTO mimir.ops_clients(client_id,slug,name)
            VALUES ((p->>'client_id')::uuid,p->>'slug',p->>'name') RETURNING to_jsonb(ops_clients) INTO result;
            id := (p->>'client_id')::uuid;
        ELSIF kind = 'site' THEN
            PERFORM mimir.ops_assert_object(p, ARRAY['site_id','client_id','slug','name','location_note','vlans','networks'],
                ARRAY['site_id','client_id','slug','name']);
            id := (p->>'site_id')::uuid;
            INSERT INTO mimir.ops_sites(site_id,client_id,slug,name,location_note)
            VALUES (id,(p->>'client_id')::uuid,p->>'slug',p->>'name',p->>'location_note');
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'vlans','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['vlan_id','tag','name'], ARRAY['vlan_id','tag','name']);
                INSERT INTO mimir.ops_vlans VALUES ((item->>'vlan_id')::uuid,id,(item->>'tag')::int,item->>'name');
            END LOOP;
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'networks','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['network_id','prefix','vlan_id','name'], ARRAY['network_id','prefix','name']);
                INSERT INTO mimir.ops_networks VALUES ((item->>'network_id')::uuid,id,(item->>'prefix')::cidr,(item->>'vlan_id')::uuid,item->>'name');
            END LOOP;
            SELECT to_jsonb(s) INTO result FROM mimir.ops_sites s WHERE site_id=id;
        ELSE
            PERFORM mimir.ops_assert_object(p,
                ARRAY['device_id','site_id','name','device_type','adapter','permission_mode','vendor','model','firmware','role','interfaces','addresses','accesses','dependencies','primary_access_id','management_host','management_port','ssh_user','credential_ref'],
                ARRAY['device_id','site_id','name','device_type','adapter','primary_access_id','accesses']);
            id := (p->>'device_id')::uuid; sid := (p->>'site_id')::uuid;
            IF jsonb_array_length(p->'accesses') < 1 OR NOT EXISTS (
                SELECT FROM jsonb_array_elements(p->'accesses') access
                WHERE access->>'access_id' = p->>'primary_access_id'
            ) THEN RAISE EXCEPTION 'primary access must be present in accesses'; END IF;
            IF EXISTS (
                SELECT FROM jsonb_array_elements(p->'accesses') access
                WHERE access->>'access_id' = p->>'primary_access_id'
                  AND ((p ? 'management_host' AND p->>'management_host' IS DISTINCT FROM access->>'host')
                    OR (p ? 'management_port' AND p->>'management_port' IS DISTINCT FROM access->>'port')
                    OR (p ? 'ssh_user' AND p->>'ssh_user' IS DISTINCT FROM access->>'username')
                    OR (p ? 'credential_ref' AND p->>'credential_ref' IS DISTINCT FROM access->>'credential_ref'))
            ) THEN RAISE EXCEPTION 'duplicated access projection does not match primary access'; END IF;
            INSERT INTO mimir.ops_devices(device_id,site_id,name,device_type,role,vendor,model,firmware,
                management_host,management_port,ssh_user,adapter,permission_mode,credential_ref,primary_access_id)
            SELECT id,sid,p->>'name',p->>'device_type',coalesce(p->>'role','unspecified'),p->>'vendor',p->>'model',p->>'firmware',
                access->>'host',coalesce((access->>'port')::int,22),access->>'username',p->>'adapter',
                coalesce(p->>'permission_mode','READ'),access->>'credential_ref',(p->>'primary_access_id')::uuid
            FROM jsonb_array_elements(p->'accesses') access
            WHERE access->>'access_id' = p->>'primary_access_id';
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'interfaces','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['interface_id','name','mac','mtu','role','vlan_id'], ARRAY['interface_id','name']);
                INSERT INTO mimir.ops_interfaces VALUES ((item->>'interface_id')::uuid,sid,id,item->>'name',(item->>'mac')::macaddr,(item->>'mtu')::int,item->>'role',(item->>'vlan_id')::uuid);
            END LOOP;
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'addresses','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['address_id','interface_id','address','network_id'], ARRAY['address_id','interface_id','address']);
                IF item->>'network_id' IS NOT NULL AND NOT EXISTS (
                    SELECT FROM mimir.ops_networks WHERE network_id=(item->>'network_id')::uuid AND site_id=sid
                    AND (item->>'address')::inet <<= prefix
                ) THEN RAISE EXCEPTION 'address outside network/site'; END IF;
                INSERT INTO mimir.ops_addresses VALUES ((item->>'address_id')::uuid,sid,id,(item->>'interface_id')::uuid,(item->>'address')::inet,(item->>'network_id')::uuid);
            END LOOP;
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'accesses','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['access_id','method','host','port','username','credential_ref'], ARRAY['access_id','method','host','port','username','credential_ref']);
                INSERT INTO mimir.ops_accesses VALUES ((item->>'access_id')::uuid,id,item->>'method',item->>'host',(item->>'port')::int,item->>'username',item->>'credential_ref');
            END LOOP;
            FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p->'dependencies','[]')) LOOP
                PERFORM mimir.ops_assert_object(item, ARRAY['depends_on_device_id','relation'], ARRAY['depends_on_device_id','relation']);
                IF NOT EXISTS (
                    SELECT FROM mimir.ops_devices target JOIN mimir.ops_sites ts ON ts.site_id=target.site_id
                    JOIN mimir.ops_sites source ON source.site_id=sid AND source.client_id=ts.client_id
                    WHERE target.device_id=(item->>'depends_on_device_id')::uuid
                ) THEN RAISE EXCEPTION 'dependency crosses client boundary'; END IF;
                INSERT INTO mimir.ops_dependencies VALUES (sid,id,(item->>'depends_on_device_id')::uuid,item->>'relation');
            END LOOP;
            result := mimir.ops_device_document(id);
        END IF;
        INSERT INTO mimir.ops_audit(method,object_id,after_state) VALUES(method,id,p);
        RETURN result;
    ELSIF method IN ('inventory.list','inventory.show') THEN
        off := coalesce((r->>'offset')::int,0);
        IF off NOT BETWEEN 0 AND 1000000 THEN RAISE EXCEPTION 'invalid offset'; END IF;
        id := (r->>'id')::uuid;
        IF method='inventory.show' AND id IS NULL THEN RAISE EXCEPTION 'id required'; END IF;
        IF kind='client' THEN
            SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY client_id),'[]') INTO result FROM
                (SELECT * FROM mimir.ops_clients WHERE id IS NULL OR client_id=id ORDER BY client_id LIMIT 100 OFFSET off) x;
        ELSIF kind='site' THEN
            SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY site_id),'[]') INTO result FROM
                (SELECT * FROM mimir.ops_sites WHERE id IS NULL OR site_id=id ORDER BY site_id LIMIT 100 OFFSET off) x;
            IF id IS NOT NULL AND jsonb_array_length(result)>0 THEN
                result := jsonb_build_array((result->0) || jsonb_build_object(
                    'vlans',coalesce((SELECT jsonb_agg(to_jsonb(v) ORDER BY tag) FROM mimir.ops_vlans v WHERE site_id=id),'[]'),
                    'networks',coalesce((SELECT jsonb_agg(to_jsonb(v) ORDER BY network_id) FROM mimir.ops_networks v WHERE site_id=id),'[]')));
            END IF;
        ELSE
            IF id IS NOT NULL THEN
                result := jsonb_build_array(mimir.ops_device_document(id));
            ELSE
                SELECT coalesce(jsonb_agg(to_jsonb(x)-'observed_state' ORDER BY device_id),'[]') INTO result FROM
                    (SELECT * FROM mimir.ops_devices ORDER BY device_id LIMIT 100 OFFSET off) x;
            END IF;
        END IF;
        RETURN CASE WHEN method='inventory.show' THEN result->0 ELSE result END;
    ELSIF method='intervention.begin' THEN
        id := (p->>'intervention_id')::uuid;
        PERFORM 1 FROM mimir.ops_devices WHERE device_id=(p#>>'{device,device_id}')::uuid FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'device missing'; END IF;
        -- Recheck inventory identity and access policy under lock: stale plans fail.
        SELECT to_jsonb(d) INTO previous FROM mimir.ops_devices d WHERE device_id=(p#>>'{device,device_id}')::uuid;
        IF NOT (previous @> (p->'device')) OR p->>'status' IS DISTINCT FROM 'running'
           OR p->'dry_run' IS DISTINCT FROM 'false'::jsonb OR p->>'mode' NOT IN ('READ','EXECUTE') THEN
            RAISE EXCEPTION 'stale device or invalid intervention';
        END IF;
        IF EXISTS (SELECT FROM mimir.ops_interventions
            WHERE device_id=(p#>>'{device,device_id}')::uuid AND status='running'
            AND (requested_mode='EXECUTE' OR p->>'mode'='EXECUTE')) THEN
            RAISE EXCEPTION 'device has intervention requiring reconciliation';
        END IF;
        IF p#>>'{plan,canonical_plan}' IS NULL
           OR (p#>>'{plan,canonical_plan}')::jsonb IS DISTINCT FROM ((p->'plan')-'plan_sha256'-'canonical_plan')
           OR encode(public.digest(convert_to(p#>>'{plan,canonical_plan}','UTF8'),'sha256'),'hex') IS DISTINCT FROM p#>>'{plan,plan_sha256}'
           OR p#>'{plan,device}' IS DISTINCT FROM p->'device'
           OR p#>>'{plan,objective}' IS DISTINCT FROM p->>'objective' THEN
            RAISE EXCEPTION 'plan digest or binding mismatch';
        END IF;
        IF previous->>'permission_mode'='PLAN' THEN RAISE EXCEPTION 'device restricted to PLAN'; END IF;
        IF p->>'mode'='EXECUTE' AND (
            previous->>'permission_mode' IS DISTINCT FROM 'EXECUTE' OR previous->>'adapter' IS DISTINCT FROM 'generic-linux'
            OR p#>>'{plan,operation}' IS DISTINCT FROM 'set-hostname'
            OR p#>>'{approval,plan_sha256}' IS DISTINCT FROM p#>>'{plan,plan_sha256}'
            OR coalesce(length(p#>>'{approval,reference}'),0)=0
            OR p#>>'{approval,plan_sha256}' IS NULL
        ) THEN RAISE EXCEPTION 'execution not authorized'; END IF;
        INSERT INTO mimir.ops_interventions(intervention_id,device_id,objective,requested_mode,plan,approval,initial_report,
            workflow_stage,workflow_state)
        VALUES(id,(p#>>'{device,device_id}')::uuid,p->>'objective',p->>'mode',p->'plan',nullif(p->'approval','null'),p,
            CASE WHEN p->>'mode'='EXECUTE' THEN 'PRECHECK' ELSE 'READ' END, 'ready');
        INSERT INTO mimir.ops_audit(method,object_id,after_state) VALUES(method,id,p);
        RETURN jsonb_build_object('intervention_id',id);
    ELSIF method IN ('intervention.event','intervention.finish') THEN
        id := CASE WHEN method='intervention.event' THEN (r->>'id')::uuid ELSE (p#>>'{report,intervention_id}')::uuid END;
        SELECT * INTO intervention FROM mimir.ops_interventions WHERE intervention_id=id FOR UPDATE;
        IF NOT FOUND OR intervention.status<>'running' OR intervention.created_by<>session_user THEN
            RAISE EXCEPTION 'intervention unavailable or already finalized';
        END IF;
        IF method='intervention.event' THEN
            IF p->>'event' NOT IN ('intent','result') OR p->>'stage' IS NULL
               OR intervention.workflow_state='failed'
               OR (intervention.workflow_state='complete' AND intervention.requested_mode<>'READ') THEN
                RAISE EXCEPTION 'invalid or already terminal workflow state';
            END IF;
            SELECT * INTO last_action FROM mimir.ops_actions WHERE intervention_id=id ORDER BY sequence_no DESC LIMIT 1;
            IF (p->>'stage' IS DISTINCT FROM intervention.workflow_stage
                    AND NOT (intervention.requested_mode='READ' AND intervention.workflow_stage='DONE'
                        AND p->>'stage'='READ'))
               OR (p->>'event'='intent' AND intervention.workflow_state IS DISTINCT FROM 'ready'
                    AND NOT (intervention.requested_mode='READ' AND intervention.workflow_state='complete'
                        AND p->>'stage'='READ'))
               OR (p->>'event'='result' AND (intervention.workflow_state IS DISTINCT FROM 'intent'
                   OR last_action.event_type IS DISTINCT FROM 'intent'
                   OR last_action.stage IS DISTINCT FROM p->>'stage'
                   OR last_action.payload#>>'{action,operation}' IS DISTINCT FROM p#>>'{action,operation}')) THEN
                RAISE EXCEPTION 'workflow transition out of order';
            END IF;
            IF p->>'stage'='EXECUTE' AND p->>'event'='intent' AND intervention.requested_mode<>'EXECUTE' THEN
                RAISE EXCEPTION 'execution not authorized';
            END IF;
            INSERT INTO mimir.ops_actions(intervention_id,sequence_no,stage,event_type,payload)
            VALUES(id,coalesce(last_action.sequence_no,0)+1,p->>'stage',p->>'event',p);
            IF p->>'event'='intent' THEN
                UPDATE mimir.ops_interventions SET workflow_state='intent' WHERE intervention_id=id;
            ELSIF p#>'{action,exit_code}'='0'::jsonb
                AND p#>'{action,error}'='null'::jsonb
                AND p#>'{action,dry_run}'='false'::jsonb THEN
                UPDATE mimir.ops_interventions SET
                    workflow_stage=CASE workflow_stage
                        WHEN 'READ' THEN 'DONE' WHEN 'DONE' THEN 'DONE' WHEN 'PRECHECK' THEN 'SNAPSHOT'
                        WHEN 'SNAPSHOT' THEN 'BACKUP' WHEN 'BACKUP' THEN 'EXECUTE'
                        WHEN 'EXECUTE' THEN 'VALIDATE' WHEN 'VALIDATE' THEN 'DONE' END,
                    workflow_state=CASE WHEN workflow_stage IN ('VALIDATE','READ')
                        OR (workflow_stage='DONE' AND requested_mode='READ') THEN
                        'complete'
                        ELSE 'ready' END
                WHERE intervention_id=id;
            ELSE
                UPDATE mimir.ops_interventions SET workflow_state='failed' WHERE intervention_id=id;
            END IF;
            RETURN jsonb_build_object('recorded',true);
        END IF;
        report := p->'report'; body := p->>'json_text'; md := p->>'markdown';
        IF body IS NULL OR body::jsonb IS DISTINCT FROM report OR coalesce(length(md),0)=0
           OR report->'plan' IS DISTINCT FROM intervention.plan
           OR report->'approval' IS DISTINCT FROM intervention.initial_report->'approval'
           OR report->'device' IS DISTINCT FROM intervention.initial_report->'device'
           OR report->>'mode' IS DISTINCT FROM intervention.requested_mode
           OR report->'closed' IS DISTINCT FROM 'false'::jsonb THEN
            RAISE EXCEPTION 'invalid report or changed authorization';
        END IF;
        IF (SELECT coalesce(jsonb_agg(payload->'action' ORDER BY sequence_no),'[]')
            FROM mimir.ops_actions WHERE intervention_id=id AND event_type='result') IS DISTINCT FROM report->'actions'
        THEN RAISE EXCEPTION 'report does not match durable journal'; END IF;
        success := report->>'status' IN ('collected','validated');
        IF report->>'status' NOT IN ('collected','validated','failed') OR report->>'completed_at' IS NULL THEN
            RAISE EXCEPTION 'invalid final state';
        END IF;
        IF success AND intervention.workflow_state IS DISTINCT FROM 'complete' THEN
            RAISE EXCEPTION 'workflow not complete';
        END IF;
        IF success THEN
            IF report#>'{validation,passed}' IS DISTINCT FROM 'true'::jsonb
               OR report#>'{validation,performed}' IS DISTINCT FROM 'true'::jsonb
               OR report->'inventory_updated' IS DISTINCT FROM 'true'::jsonb
               OR jsonb_array_length(coalesce(report->'before','[]'))=0
               OR jsonb_array_length(coalesce(report->'actions','[]'))=0
               OR jsonb_array_length(coalesce(report->'evidence','[]'))=0
               OR EXISTS (SELECT FROM mimir.ops_actions WHERE intervention_id=id AND event_type='result'
                   AND (payload#>'{action,exit_code}' IS DISTINCT FROM '0'::jsonb
                     OR payload#>'{action,dry_run}' IS DISTINCT FROM 'false'::jsonb
                     OR payload#>'{action,error}' IS DISTINCT FROM 'null'::jsonb))
            THEN RAISE EXCEPTION 'closure criteria missing'; END IF;
            IF intervention.requested_mode='EXECUTE' THEN
                SELECT * INTO last_action FROM mimir.ops_actions WHERE intervention_id=id ORDER BY sequence_no DESC LIMIT 1;
                IF last_action.stage IS DISTINCT FROM 'VALIDATE' OR last_action.event_type IS DISTINCT FROM 'result'
                   OR btrim(last_action.payload#>>'{action,stdout}', E'\r\n ') IS DISTINCT FROM intervention.plan#>>'{parameters,hostname}'
                   OR report#>>'{backup,status}' IS DISTINCT FROM 'captured'
                   OR jsonb_array_length(coalesce(report->'snapshots','[]'))=0 THEN
                    RAISE EXCEPTION 'final validation or recovery evidence missing';
                END IF;
            END IF;
            SELECT to_jsonb(d) INTO previous FROM mimir.ops_devices d WHERE device_id=intervention.device_id FOR UPDATE;
            UPDATE mimir.ops_devices SET last_collected_at=clock_timestamp(), verified_at=clock_timestamp(),
                verification_state='verified', updated_at=clock_timestamp(),
                last_change_at=CASE WHEN intervention.requested_mode='EXECUTE' THEN clock_timestamp() ELSE last_change_at END,
                observed_state=jsonb_build_object('intervention_id',id,'state',report->'final_state',
                    'evidence',report->'evidence','verification_scope','diagnostic_observation')
            WHERE device_id=intervention.device_id;
            INSERT INTO mimir.ops_audit(method,object_id,before_state,after_state)
            SELECT 'inventory.observation',device_id,previous,to_jsonb(d) FROM mimir.ops_devices d WHERE device_id=intervention.device_id;
        END IF;
        IF NOT success AND intervention.requested_mode='EXECUTE' AND EXISTS (
            SELECT FROM mimir.ops_actions WHERE intervention_id=id AND stage='EXECUTE' AND event_type='intent'
        ) THEN
            SELECT to_jsonb(d) INTO previous FROM mimir.ops_devices d WHERE device_id=intervention.device_id FOR UPDATE;
            UPDATE mimir.ops_devices SET verification_state='unverified',verified_at=NULL,updated_at=clock_timestamp(),
                observed_state=jsonb_build_object('intervention_id',id,'state','unknown_requires_manual_verification')
            WHERE device_id=intervention.device_id;
            INSERT INTO mimir.ops_audit(method,object_id,before_state,after_state)
            SELECT 'inventory.invalidate',device_id,previous,to_jsonb(d) FROM mimir.ops_devices d WHERE device_id=intervention.device_id;
        END IF;
        FOR item IN SELECT value FROM jsonb_array_elements(coalesce(report->'evidence','[]')) LOOP
            IF item->>'canonical_data' IS NULL OR (item->>'canonical_data')::jsonb IS DISTINCT FROM item->'data'
                OR encode(public.digest(convert_to(item->>'canonical_data','UTF8'),'sha256'),'hex') IS DISTINCT FROM item->>'sha256'
            THEN RAISE EXCEPTION 'evidence hash mismatch'; END IF;
            IF NOT EXISTS (SELECT FROM mimir.ops_actions WHERE intervention_id=id AND event_type='result'
                AND payload->'action'=item->'data') THEN RAISE EXCEPTION 'evidence not in journal'; END IF;
            INSERT INTO mimir.ops_evidence(evidence_id,intervention_id,kind,sha256,payload)
            VALUES((item->>'evidence_id')::uuid,id,item->>'kind',item->>'sha256',item->'data');
        END LOOP;
        INSERT INTO mimir.ops_reports(intervention_id,payload,json_text,markdown,json_sha256,markdown_sha256)
        VALUES(id,report,body,md,encode(public.digest(convert_to(body,'UTF8'),'sha256'),'hex'),encode(public.digest(convert_to(md,'UTF8'),'sha256'),'hex'));
        UPDATE mimir.ops_interventions SET status=report->>'status',final_validation=success,
            inventory_updated=success,completed_at=(report->>'completed_at')::timestamptz WHERE intervention_id=id;
        INSERT INTO mimir.ops_audit(method,object_id,after_state) VALUES(method,id,report);
        RETURN jsonb_build_object('intervention_id',id,'status',report->>'status');
    ELSIF method='history' THEN
        id := (r->>'id')::uuid; off := coalesce((r->>'offset')::int,0);
        IF id IS NULL OR off NOT BETWEEN 0 AND 1000000 THEN RAISE EXCEPTION 'invalid history request'; END IF;
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY started_at DESC,intervention_id),'[]') INTO result FROM
            (SELECT intervention_id,device_id,objective,requested_mode,status,started_at,completed_at,rollback_mode
             FROM mimir.ops_interventions WHERE device_id=id ORDER BY started_at DESC,intervention_id LIMIT 100 OFFSET off) x;
        RETURN result;
    ELSIF method='report' THEN
        id := (r->>'id')::uuid;
        SELECT payload INTO result FROM mimir.ops_reports WHERE intervention_id=id;
        IF result IS NULL THEN
            SELECT initial_report || jsonb_build_object('status',status,'actions',coalesce(
                (SELECT jsonb_agg(payload ORDER BY sequence_no) FROM mimir.ops_actions WHERE intervention_id=id),'[]'))
            INTO result FROM mimir.ops_interventions WHERE intervention_id=id;
        END IF;
        RETURN result;
    END IF;
    RAISE EXCEPTION 'unknown operational method';
END
$api$;

REVOKE ALL ON FUNCTION mimir.ops_assert_identity(), mimir.ops_assert_object(jsonb,text[],text[]),
    mimir.ops_device_document(uuid), mimir.ops_api(jsonb) FROM PUBLIC;
REVOKE ALL ON mimir.ops_identities, mimir.ops_clients, mimir.ops_sites, mimir.ops_devices,
    mimir.ops_interfaces, mimir.ops_addresses, mimir.ops_networks, mimir.ops_vlans, mimir.ops_accesses,
    mimir.ops_dependencies, mimir.ops_interventions, mimir.ops_actions, mimir.ops_evidence,
    mimir.ops_reports, mimir.ops_audit FROM PUBLIC;
REVOKE ALL ON SEQUENCE mimir.ops_actions_action_id_seq, mimir.ops_audit_audit_id_seq FROM PUBLIC;
INSERT INTO mimir.schema_version(version,description)
VALUES(13,'Inventário operacional e intervenções por API peer controlada; memória preservada');
RESET ROLE;
COMMIT;
