#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from dataclasses import asdict, replace
from pathlib import Path
from unittest.mock import Mock, patch

from mimir_ops import (ADAPTERS, ActionResult, Adapter, Device, MikroTikAdapter, PolicyError,
                       SSHExecutor, enforce, enforce_operation, is_destructive, make_plan,
                       redact, render_report, write_report)
from ops_security import ProcessResult, StoreError, bounded_run, digest, sanitize
from ops_store import PostgresStore, normalize_inventory
from ops_workflow import InterventionRunner, LocalJournal, effective_os_identity

DID = '11111111-1111-4111-8111-111111111111'
SID = '22222222-2222-4222-8222-222222222222'
CID = '33333333-3333-4333-8333-333333333333'
DEVICE = Device(DID, SID, 'lab', 'server', '192.0.2.10', 'mimir', 'generic-linux', permission_mode='EXECUTE')
ACCESS_ID = '99999999-9999-4999-8999-999999999999'


def inventory_device():
    value = asdict(DEVICE)
    for field in ('management_host', 'management_port', 'ssh_user', 'credential_ref'):
        value.pop(field)
    value['primary_access_id'] = ACCESS_ID
    value['accesses'] = [{'access_id': ACCESS_ID, 'method': 'ssh', 'host': DEVICE.management_host,
                          'port': DEVICE.management_port, 'username': DEVICE.ssh_user,
                          'credential_ref': DEVICE.credential_ref}]
    return value


class FakeStore:
    durable = True

    def __init__(self):
        self.events = []
        self.begun = []
        self.finished = []

    def begin(self, report):
        self.begun.append(report)

    def event(self, iid, event):
        self.events.append(event)

    def finish(self, payload):
        self.finished.append(payload)


class FakeSSH:
    def __init__(self, fail=None, invalid=False, backup_drift=False):
        self.calls = []
        self.fail = fail
        self.invalid = invalid
        self.backup_drift = backup_drift

    def run(self, device, name, **options):
        # Real policy still exercised by fake transport.
        op = enforce_operation(device, name, options['mode'], options.get('parameters'), options.get('approved'))
        self.calls.append(name)
        i = len(self.calls)
        output = 'lab-old\n' if name == 'hostname' else 'diagnostic\n'
        if name == 'hostname' and 'set-hostname' in self.calls:
            output = 'lab-new\n' if not self.invalid else 'unexpected\n'
        if self.backup_drift and i == 4:
            output = 'drift\n'
        return ActionResult(op.render(options.get('parameters')), op.classification,
                            1 if self.fail == i else 0, output, '', '2026-09-22T00:00:00Z',
                            '2026-09-22T00:00:01Z', False, name)


def run_change(store=None, executor=None, **kwargs):
    store = store or FakeStore()
    executor = executor or FakeSSH()
    record = asdict(DEVICE)
    plan = make_plan(DEVICE, 'set-hostname', {'hostname': 'lab-new'})
    args = {'mode': 'EXECUTE', 'operation': 'set-hostname', 'parameters': {'hostname': 'lab-new'},
            'approval': plan['plan_sha256'], 'approval_ref': 'change-001'}
    args.update(kwargs)
    return InterventionRunner(store, executor).run(record, **args), store, executor


class PolicyTests(unittest.TestCase):
    def test_read_allows_diagnostics(self):
        self.assertEqual(enforce('READ', 'ip address'), 'read')

    def test_read_blocks_change(self):
        with self.assertRaises(PolicyError):
            enforce('READ', 'touch /tmp/x')

    def test_execute_requires_approval_and_catalog(self):
        for approved in (False, True):
            with self.assertRaises(PolicyError):
                enforce('EXECUTE', 'touch /tmp/x', approved)
        with self.assertRaises(PolicyError):
            enforce_operation(DEVICE, 'set-hostname', 'EXECUTE', {'hostname': 'test'}, False)

    def test_destructive_is_always_blocked(self):
        self.assertTrue(is_destructive('/system reset-configuration'))
        with self.assertRaises(PolicyError):
            enforce('EXECUTE', '/system reset-configuration', True)

    def test_bypass_inputs_fail_closed(self):
        for command in ('uname; id', 'uname -a\nreboot', 'ip address add 192.0.2.1 dev eth0',
                        'rc-service sshd restart', 'uptime && id', 'uname $(id)',
                        'uname `id`', 'uname -a | sh', 'uname -a > /tmp/x', ' uname -a',
                        '/interface print; /system reboot', 'uname -a\x00'):
            with self.subTest(command=command), self.assertRaises(PolicyError):
                enforce('READ', command)

    def test_hostname_escaping(self):
        for value in ('-a','x;id','x\nid','$(id)','`id`','a b',"a'b",'a"b','a/b','a'*64):
            with self.subTest(value=value), self.assertRaises(PolicyError):
                make_plan(DEVICE, 'set-hostname', {'hostname': value})

    def test_unknown_parameters_modes_and_adapters(self):
        for params in ({}, {'hostname':'lab','shell':'id'}):
            with self.assertRaises(PolicyError):
                make_plan(DEVICE, 'set-hostname', params)
        with self.assertRaises(PolicyError):
            replace(DEVICE, adapter='fiberhome')
        with self.assertRaises(PolicyError):
            enforce_operation(DEVICE, 'hostname', 'execute')

    def test_device_policy_effective(self):
        with self.assertRaises(PolicyError):
            enforce_operation(replace(DEVICE, permission_mode='READ'), 'set-hostname', 'EXECUTE', {'hostname':'lab'}, True)
        with self.assertRaises(PolicyError):
            enforce_operation(replace(DEVICE, permission_mode='PLAN'), 'hostname', 'READ')

    def test_mikrotik_reads_and_no_write(self):
        device = replace(DEVICE, adapter='mikrotik-routeros')
        for name in MikroTikAdapter.read_operations:
            self.assertEqual(enforce_operation(device, name).classification, 'read')
        for name in ('export','set-hostname','reset','backup-save'):
            with self.assertRaises(PolicyError):
                enforce_operation(device, name, 'EXECUTE', approved=True)

    def test_ipv6_and_scoped_address_rejection(self):
        self.assertEqual(replace(DEVICE, management_host='::1').management_host, '::1')
        with self.assertRaises(PolicyError):
            replace(DEVICE, management_host='fe80::1%eth0')

    def test_capabilities_explicit(self):
        for cls in ADAPTERS.values():
            d = cls().describe()
            for key in ('read_operations','plan_operations','execute_operations','snapshot_operations',
                        'backup_operation','validation_operation','rollback_mode','forbidden_operations'):
                self.assertIn(key, d)
            self.assertEqual(d['rollback_mode'], 'manual')

    def test_redaction(self):
        samples = ['token=abc123', 'Authorization: Bearer fake-value', 'password="with spaces"',
                   '-----BEGIN OPENSSH PRIVATE KEY-----\nprivate-content',
                   'https://user:fake-value@host', 'senha: first\nsecond', 'pass\x1bword=abc123', 'Bearer synthetic-value']
        for text in samples:
            self.assertEqual(redact(text), '<redacted>')
        self.assertEqual(sanitize({'nested':[{'password':'abc123'}]}), {'nested':[{'password':'<redacted>'}]})


class SSHTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / 'known_hosts'
        self.path.write_text('synthetic-host-key-placeholder\n')
        self.path.chmod(0o600)
        self.runner = Mock(return_value=ProcessResult(0,'token=synthetic','password=synthetic'))
        self.ssh = SSHExecutor(known_hosts=str(self.path), runner=self.runner)
        self.agent = patch.dict(os.environ, {'SSH_AUTH_SOCK':'/tmp/synthetic-agent', 'SECRET_ENV':'do-not-inherit'})
        self.agent.start()

    def tearDown(self):
        self.agent.stop()
        self.tmp.cleanup()

    def test_command_construction_and_redaction(self):
        result = self.ssh.run(DEVICE, 'hostname')
        args, kw = self.runner.call_args
        argv = args[0]
        for option in ('StrictHostKeyChecking=yes', 'BatchMode=yes', 'ForwardAgent=no',
                       'PasswordAuthentication=no', 'UpdateHostKeys=no', 'IdentityFile=none'):
            self.assertIn(option, argv)
        self.assertEqual(argv[-3:], ['--',DEVICE.management_host,'/bin/hostname'])
        self.assertEqual(argv[1:3], ['-F','/dev/null'])
        self.assertNotIn('SECRET_ENV', kw['env'])
        self.assertEqual(result.stdout, '<redacted>')
        self.assertEqual(result.stderr, '<redacted>')

    def test_no_direct_change_without_workflow(self):
        with self.assertRaises(PolicyError):
            self.ssh.run(DEVICE, 'set-hostname', mode='EXECUTE', parameters={'hostname':'lab'}, approved=True)
        self.runner.assert_not_called()

    def test_host_and_user_injection(self):
        for host in ('-oProxyCommand=id', 'host;id', 'user@host', 'host\noption'):
            with self.assertRaises(PolicyError):
                replace(DEVICE, management_host=host)
        for user in ('-o','user@host','root;id'):
            with self.assertRaises(PolicyError):
                replace(DEVICE, ssh_user=user)

    def test_external_key_reference(self):
        key = Path(self.tmp.name) / 'key'
        key.write_text('synthetic placeholder; no actual private key')
        key.chmod(0o600)
        device = replace(DEVICE, credential_ref='file-ref:lab')
        ssh = SSHExecutor(known_hosts=str(self.path), key_refs={'file-ref:lab':str(key)}, runner=self.runner)
        argv = ssh.argv(device, '/bin/hostname')
        self.assertIn(str(key), argv)
        self.assertIn('IdentityAgent=none', argv)
        key.chmod(0o644)
        with self.assertRaises(PolicyError):
            ssh.argv(device, '/bin/hostname')

    def test_insecure_or_missing_known_hosts(self):
        self.path.chmod(0o666)
        with self.assertRaises(PolicyError):
            self.ssh.run(DEVICE, 'hostname')
        self.path.unlink()
        self.path.symlink_to('/dev/null')
        with self.assertRaises(PolicyError):
            self.ssh.run(DEVICE, 'hostname')
        self.runner.assert_not_called()

    def test_dry_run_needs_no_agent_or_host_file(self):
        ssh = SSHExecutor(known_hosts='/nonexistent', runner=self.runner)
        self.assertTrue(ssh.run(DEVICE, 'hostname', dry_run=True).dry_run)
        self.assertTrue(ssh.run(DEVICE, 'hostname', mode='PLAN').dry_run)
        self.runner.assert_not_called()

    def test_timeout_and_exit_codes_preserved(self):
        self.runner.return_value = ProcessResult(-9,'','', 'timeout')
        self.assertEqual(self.ssh.run(DEVICE,'hostname').error, 'timeout')
        self.runner.return_value = ProcessResult(7,'','failure')
        self.assertEqual(self.ssh.run(DEVICE,'hostname').exit_code, 7)
        self.runner.side_effect = OSError('password=do-not-print')
        self.assertEqual(self.ssh.run(DEVICE,'hostname').error, 'transport_unavailable')

    def test_bounded_process_real_local_streams(self):
        result = bounded_run([sys.executable,'-c',"import sys;print('ok');print('err',file=sys.stderr);sys.exit(7)"], timeout=2)
        self.assertEqual((result.exit_code,result.stdout,result.stderr), (7,'ok\n','err\n'))
        for stream in ('stdout','stderr'):
            result = bounded_run([sys.executable,'-c',f"import sys;sys.{stream}.write('x'*20000)"],timeout=2,limit=1024)
            self.assertEqual(result.error,'output_limit')
            self.assertEqual(result.stdout + result.stderr, '')
        result = bounded_run([sys.executable,'-c','import time;time.sleep(5)'], timeout=.1)
        self.assertEqual(result.error, 'timeout')

    def test_bounded_process_stdin(self):
        result = bounded_run([sys.executable,'-c','import sys;print(len(sys.stdin.buffer.read()))'],input_data=b'x'*200000,timeout=2)
        self.assertEqual(result.stdout, '200000\n')


class InventoryStoreTests(unittest.TestCase):
    def test_client_site_device_validation(self):
        self.assertEqual(normalize_inventory('client',{'name':'Lab','slug':'lab'})['slug'],'lab')
        self.assertEqual(normalize_inventory('site',{'client_id':CID,'name':'Site','slug':'site','vlans':[{'tag':10,'name':'office'}]})['vlans'][0]['tag'],10)
        self.assertEqual(normalize_inventory('device', inventory_device())['permission_mode'],'EXECUTE')
        self.assertEqual(normalize_inventory('device', inventory_device())['management_host'], DEVICE.management_host)
        with self.assertRaises(PolicyError):
            normalize_inventory('device', {**inventory_device(), 'management_host': '192.0.2.99'})
        for payload in ({'name':'Lab','slug':'BAD'}, {'name':'password=bad','slug':'lab'},
                        {'name':'Lab','slug':'lab','password':'bad'}):
            with self.assertRaises(PolicyError):
                normalize_inventory('client', payload)

    def test_network_and_nested_fields(self):
        for item in ({'prefix':'192.0.2.1/24','name':'net'}, {'prefix':'bad','name':'net'}):
            with self.assertRaises(PolicyError):
                normalize_inventory('site',{'client_id':CID,'name':'Site','slug':'site','networks':[item]})
        for payload in ({'vlans':[{'tag':4095,'name':'bad'}]}, {'vlans':[{'tag':True,'name':'bad'}]}):
            with self.assertRaises(PolicyError):
                normalize_inventory('site',{'client_id':CID,'name':'Site','slug':'site',**payload})
        with self.assertRaises(PolicyError):
            normalize_inventory('device',{**inventory_device(),'interfaces':[{'name':'eth0','password':'bad'}]})

    def test_postgres_input_and_environment_control(self):
        runner = Mock(return_value=ProcessResult(0,'{"name":"Lab"}',''))
        store = PostgresStore(runner)
        store.add('client',{'name':"Lab'); DROP TABLE test;--",'slug':'lab'})
        args, kwargs = runner.call_args
        self.assertNotIn('Lab', ' '.join(args[0]))
        self.assertNotIn('DROP TABLE', kwargs['input_data'].decode())
        self.assertIn('mimir.ops_api', kwargs['input_data'].decode())
        self.assertEqual(kwargs['env']['PGPASSFILE'],'/dev/null')
        self.assertNotIn('PGPASSWORD',kwargs['env'])
        store.list('client')
        self.assertIn(b'BEGIN READ ONLY',runner.call_args.kwargs['input_data'])
        self.assertIn('/run/postgresql',runner.call_args.args[0])

    def test_store_errors_never_expose_driver_output(self):
        runner = Mock(return_value=ProcessResult(1,'','password=should-not-leak'))
        with self.assertRaises(StoreError) as error:
            PostgresStore(runner).history(DID)
        self.assertNotIn('should-not-leak',str(error.exception))
        runner.return_value = ProcessResult(0,'not JSON','')
        with self.assertRaises(StoreError):
            PostgresStore(runner).report(DID)

    def test_all_inventory_methods_use_controlled_api(self):
        runner = Mock(return_value=ProcessResult(0,'{}',''))
        store = PostgresStore(runner)
        examples = Path(__file__).parent / 'examples'
        import base64
        import re
        for kind, filename in (('client','client.json'),('site','site.json'),('device','device-linux.json')):
            payload = json.loads((examples / filename).read_text())
            store.add(kind, payload)
            store.list(kind)
            store.show(kind, payload[kind + '_id'])
        methods = []
        for call in runner.call_args_list:
            encoded = re.search(r"decode\('([^']+)'", call.kwargs['input_data'].decode()).group(1)
            methods.append(json.loads(base64.b64decode(encoded))['method'])
        self.assertEqual(methods, ['inventory.add','inventory.list','inventory.show'] * 3)

    def test_inventory_defaults_to_read_and_unverified(self):
        item = inventory_device()
        del item['permission_mode']
        result = normalize_inventory('device',item)
        self.assertEqual(result['permission_mode'],'READ')
        with self.assertRaises(PolicyError):
            normalize_inventory('device',{**item,'verification_state':'verified'})

    def test_missing_access_id_is_generated_once_as_primary(self):
        item = inventory_device()
        del item['primary_access_id']
        del item['accesses'][0]['access_id']
        result = normalize_inventory('device', item)
        self.assertEqual(result['primary_access_id'], result['accesses'][0]['access_id'])

    def test_history_report_and_pagination(self):
        runner = Mock(return_value=ProcessResult(0,'[]',''))
        store = PostgresStore(runner)
        self.assertEqual(store.history(DID,100),[])
        for call in (lambda:store.history('bad'),lambda:store.list('arbitrary'),lambda:store.list('client',offset=-1)):
            with self.assertRaises(PolicyError): call()
        runner.return_value=ProcessResult(0,'null','')
        with self.assertRaises(StoreError): store.report(DID)


class WorkflowTests(unittest.TestCase):
    def test_persisted_sql_workflow_is_stateful_and_fail_closed(self):
        migration = Path(__file__).parents[1] / 'memory' / 'migrations' / '013_operational_inventory.sql'
        sql = migration.read_text()
        for token in ('workflow_stage', 'workflow_state', 'workflow transition out of order',
                      "workflow_state='failed'", "workflow_stage=CASE workflow_stage",
                      "WHEN 'READ' THEN 'DONE'"):
            self.assertIn(token, sql)
        self.assertNotIn('count(DISTINCT stage)', sql)

        stages = ('PRECHECK', 'SNAPSHOT', 'BACKUP', 'EXECUTE', 'VALIDATE')

        def transition(stage, state, event, success, requested=None):
            expected = stages[0] if stage is None else stage
            if state in ('failed', 'complete'):
                raise PolicyError('terminal')
            if requested is not None and requested != expected:
                raise PolicyError('wrong stage')
            if event == 'intent':
                if state != 'ready':
                    raise PolicyError('duplicate intent')
                return expected, 'intent'
            if event != 'result' or state != 'intent':
                raise PolicyError('result without intent')
            if not success:
                return expected, 'failed'
            index = stages.index(expected)
            return ('DONE', 'complete') if index == len(stages) - 1 else (stages[index + 1], 'ready')

        stage, state = transition(None, 'ready', 'intent', True)
        with self.assertRaises(PolicyError):
            transition(stage, state, 'intent', True)
        with self.assertRaises(PolicyError):
            transition(stage, state, 'result', True, requested='SNAPSHOT')
        stage, state = transition(stage, state, 'result', True)
        stage, state = transition(stage, state, 'intent', True)
        stage, state = transition(stage, state, 'result', False)
        with self.assertRaises(PolicyError):
            transition(stage, state, 'result', True)
        with self.assertRaises(PolicyError):
            transition('EXECUTE', 'ready', 'intent', True, requested='PRECHECK')

    def test_read_workflow_reaches_done_and_complete(self):
        migration = Path(__file__).parents[1] / 'memory' / 'migrations' / '013_operational_inventory.sql'
        sql = migration.read_text()
        self.assertIn("WHEN 'READ' THEN 'DONE'", sql)
        self.assertIn("workflow_stage IN ('VALIDATE','READ')", sql)
        self.assertIn("workflow_state='complete'", sql)
        stage, state = 'READ', 'ready'
        state = 'intent'
        self.assertEqual((stage, state), ('READ', 'intent'))
        stage, state = 'DONE', 'complete'
        self.assertEqual((stage, state), ('DONE', 'complete'))

    def test_read_result_guard_uses_persisted_nested_operation(self):
        migration = Path(__file__).parents[1] / 'memory' / 'migrations' / '013_operational_inventory.sql'
        sql = migration.read_text()
        guard = sql[sql.index("IF method='intervention.event'"):sql.index("IF p->>'stage'='EXECUTE'")]
        self.assertIn("last_action.payload#>>'{action,operation}' IS DISTINCT FROM p#>>'{action,operation}'", guard)
        self.assertNotIn("last_action.payload->>'operation'", guard)

    def test_finish_rejects_completed_at_before_started_at(self):
        migration = Path(__file__).parents[1] / 'memory' / 'migrations' / '013_operational_inventory.sql'
        sql = migration.read_text()
        finish = sql[
            sql.index("report := p->'report'"):
            sql.index("ELSIF method='history'")
        ]
        check = "(report->>'completed_at')::timestamptz < intervention.started_at"
        self.assertIn(check, finish)
        self.assertIn("RAISE EXCEPTION 'completed_at precedes started_at'", finish)
        self.assertLess(
            finish.index(check),
            finish.index("IF success AND intervention.workflow_state")
        )
        self.assertLess(
            finish.index(check),
            finish.index("INSERT INTO mimir.ops_reports")
        )

    def test_schema_migration_keeps_role_and_access_provisioning_separate(self):
        migration_dir = Path(__file__).parents[1] / 'memory' / 'migrations'
        schema = (migration_dir / '013_operational_inventory.sql').read_text()
        role = (migration_dir / '013_operational_role.sql').read_text()
        self.assertIn('WHERE version = 12', schema)
        self.assertIn('WHERE version = 13', schema)
        self.assertIn("VALUES(13,'Inventário", schema)
        self.assertNotIn('CREATE ROLE mimir_ops', schema)
        self.assertNotIn('GRANT CONNECT', schema)
        self.assertIn('GRANT CONNECT ON DATABASE', role)
        self.assertIn('primary_access_id', schema)
        self.assertIn('ops_devices_primary_access_fk', schema)

    def test_approval_records_effective_os_identity(self):
        with patch('ops_workflow.effective_os_identity', return_value='uid:synthetic') as identity:
            report, _, _ = run_change()
        identity.assert_called_once()
        self.assertEqual(report['approval']['operator'], 'uid:synthetic')
        self.assertNotIn('getpass.getuser', Path(__file__).with_name('ops_workflow.py').read_text())

    def test_read(self):
        store=FakeStore(); ssh=FakeSSH()
        report=InterventionRunner(store,ssh).run(asdict(DEVICE))
        self.assertEqual(report['status'],'collected')
        self.assertTrue(report['inventory_updated'])
        self.assertEqual(len(ssh.calls),len(Adapter.read_operations))
        self.assertTrue(all(a['classification']=='read' for a in report['actions']))

    def test_execute_flow(self):
        report,store,ssh=run_change()
        self.assertEqual(report['status'],'validated')
        self.assertTrue(report['validation']['passed'])
        self.assertFalse(report['closed'])
        self.assertTrue(report['closure_ready'])
        self.assertEqual([e['stage'] for e in store.events if e['event']=='intent'],
                         ['PRECHECK','SNAPSHOT','SNAPSHOT','BACKUP','EXECUTE','VALIDATE'])
        self.assertEqual(report['rollback']['mode'],'manual')
        self.assertFalse(report['rollback']['performed'])
        self.assertEqual(report['memory_handoff']['integration'],'PARCIAL')
        self.assertEqual(json.loads(store.finished[0]['json_text']),report)

    def test_no_approval_no_process_no_store(self):
        store=FakeStore(); ssh=FakeSSH()
        for approval in (None,'wrong-hash'):
            with self.assertRaises(PolicyError):
                run_change(store,ssh,approval=approval)
        self.assertEqual(ssh.calls,[])
        self.assertEqual(store.begun,[])

    def test_plan_is_bound_to_target_parameters_and_objective(self):
        base=make_plan(DEVICE,'set-hostname',{'hostname':'a'})
        for plan in (make_plan(replace(DEVICE,management_host='192.0.2.2'),'set-hostname',{'hostname':'a'}),
                     make_plan(DEVICE,'set-hostname',{'hostname':'b'}),
                     make_plan(DEVICE,'set-hostname',{'hostname':'a'},'new objective')):
            self.assertNotEqual(base['plan_sha256'],plan['plan_sha256'])

    def test_all_preparation_failures_block_execute(self):
        for fail in range(1,5):
            report,_,ssh=run_change(executor=FakeSSH(fail=fail))
            self.assertEqual(report['status'],'failed')
            self.assertNotIn('set-hostname',ssh.calls)
        report,_,ssh=run_change(executor=FakeSSH(backup_drift=True))
        self.assertEqual(report['status'],'failed')
        self.assertNotIn('set-hostname',ssh.calls)

    def test_change_and_validation_failures_require_manual_recovery(self):
        for ssh in (FakeSSH(fail=5),FakeSSH(fail=6),FakeSSH(invalid=True)):
            report,_,_=run_change(executor=ssh)
            self.assertEqual(report['status'],'failed')
            self.assertTrue(report['rollback']['required'])
            self.assertFalse(report['inventory_updated'])
            self.assertFalse(report['closure_ready'])

    def test_audit_failure_blocks_changes(self):
        store=FakeStore(); ssh=FakeSSH()
        def event(iid, value):
            if value['stage']=='EXECUTE': raise StoreError('unavailable')
            store.events.append(value)
        store.event=event
        report,_,_=run_change(store,ssh)
        self.assertNotIn('set-hostname',ssh.calls)
        self.assertEqual(report['status'],'failed')

    def test_begin_failure_has_no_ssh(self):
        store=FakeStore(); store.begin=Mock(side_effect=StoreError('unavailable')); ssh=FakeSSH()
        with self.assertRaises(StoreError): run_change(store,ssh)
        self.assertEqual(ssh.calls,[])

    def test_diagnostic_error_cannot_verify_inventory(self):
        store=FakeStore(); ssh=FakeSSH(fail=2)
        report=InterventionRunner(store,ssh).run(asdict(DEVICE))
        self.assertEqual(report['status'],'failed')
        self.assertFalse(report['inventory_updated'])
        self.assertFalse(report['validation']['passed'])

    def test_finish_failure_does_not_claim_completion(self):
        store=FakeStore(); store.finish=Mock(side_effect=StoreError('unavailable'))
        with self.assertRaisesRegex(StoreError,'não repetir EXECUTE'):
            run_change(store)

    def test_plan_and_dry_run_have_no_side_effects(self):
        for mode,dry in (('PLAN',False),('EXECUTE',True)):
            report,store,ssh=run_change(mode=mode,dry_run=dry)
            self.assertIn(report['status'],('planned','simulated'))
            self.assertEqual(store.begun+store.events+store.finished+ssh.calls,[])
            self.assertFalse(report['validation']['passed'])

    def test_json_legacy_cannot_execute(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(PolicyError): run_change(LocalJournal(td))


class ReportTests(unittest.TestCase):
    def test_report_generation_and_secret_scrubbing(self):
        report,_,_=run_change()
        report['errors']=['Authorization: Bearer synthetic-sensitive']
        report['device']['name']='password="two words"'
        with tempfile.TemporaryDirectory() as td:
            jp,mp,jh,mh=write_report(Path(td),report['intervention_id'],report)
            self.assertEqual(len(jh),64);self.assertEqual(len(mh),64)
            for path in (jp,mp):
                self.assertNotIn('synthetic-sensitive',path.read_text())
                self.assertNotIn('two words',path.read_text())
                self.assertEqual(path.stat().st_mode & 0o777,0o600)
            with self.assertRaises(FileExistsError):
                write_report(Path(td),report['intervention_id'],report)
            with self.assertRaises(PolicyError): write_report(Path(td),'../../escape',report)

    def test_markdown_includes_all_required_evidence(self):
        report,_,_=run_change()
        raw,md=render_report(report)
        for field in ('client','site','device','objective','mode','before','plan','actions',
                      'results','validation','backup','rollback','errors','final_state','started_at','completed_at','intervention_id'):
            self.assertIn('## '+field,md.decode())
        self.assertEqual(json.loads(raw),report)

    def test_evidence_hash_and_plan_hash_bind_canonical_bytes(self):
        import hashlib
        report,_,_=run_change()
        plan=report['plan']
        self.assertEqual(hashlib.sha256(plan['canonical_plan'].encode()).hexdigest(),plan['plan_sha256'])
        for evidence in report['evidence']:
            self.assertEqual(json.loads(evidence['canonical_data']),evidence['data'])
            self.assertEqual(hashlib.sha256(evidence['canonical_data'].encode()).hexdigest(),evidence['sha256'])

    def test_report_directory_permissions(self):
        with tempfile.TemporaryDirectory() as td:
            Path(td).chmod(0o755)
            with self.assertRaises(PolicyError):write_report(Path(td),'report',{})
            Path(td).chmod(0o700)


class CLITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec=importlib.util.spec_from_file_location('ops_cli',Path(__file__).with_name('mimir-ops.py'))
        cls.cli=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.cli)

    def test_inventory_list_history_report(self):
        store=Mock()
        store.list.return_value=[];store.history.return_value=[];store.report.return_value={'intervention_id':DID}
        with contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(self.cli.main(['inventory','client','list'],store=store),0)
            self.assertEqual(self.cli.main(['ops','history',DID],store=store),0)
            self.assertEqual(self.cli.main(['ops','report',DID],store=store),0)
        self.assertIn('intervention_id',stream.getvalue())

    def test_offline_plan(self):
        store=Mock()
        with contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(self.cli.main(['plan',str(Path(__file__).parent/'examples/device-mikrotik.json')],store=store),0)
        self.assertEqual(json.loads(stream.getvalue())['status'],'planned')
        self.assertEqual(store.mock_calls,[])

    def test_failure_exit_code(self):
        store=FakeStore()
        store.show=lambda *args:asdict(DEVICE)
        with tempfile.TemporaryDirectory() as td,contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.cli.main(['ops','inspect',DID,'--reports',td],store=store,executor=FakeSSH(fail=1)),2)


if __name__=='__main__': unittest.main()
