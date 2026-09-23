"""Journal before each action; fail closed if durable audit is unavailable."""
from __future__ import annotations

import getpass
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from ops_security import canonical

from mimir_ops import (ADAPTERS, Device, PolicyError, SSHExecutor, StoreError, digest,
                       enforce_operation, make_plan, new_id, now_iso, render_report,
                       safe_text, sanitize, write_report)


@dataclass(frozen=True)
class ChangePermit:
    intervention_id: str
    device_id: str
    operation: str
    parameters_sha256: str


class LocalJournal:
    """Legacy JSON diagnostics only. Not a PostgreSQL substitute for EXECUTE."""
    durable = False

    def __init__(self, directory):
        self.directory = Path(directory)

    def begin(self, report):
        write_report(self.directory, report['intervention_id'] + '-begin', report)

    def event(self, iid, event):
        write_report(self.directory, new_id(), {'intervention_id': iid, **event})

    def finish(self, report):
        return report


def memory_handoff(report):
    """Versioned, confidential review interface; does not call memory functions."""
    return sanitize({
        'schema_version': 1, 'integration': 'PARCIAL', 'state': 'pending_human_review',
        'source_ref': 'ops:' + report['intervention_id'],
        'client_id': report['client'].get('client_id'), 'site_id': report['site'].get('site_id'),
        'device_id': report['device']['device_id'], 'project': 'projeto-mimir',
        'classification': 'confidential', 'record_type': 'evidence',
        'occurred_at': report['completed_at'], 'confidence': 'collected_not_independently_reviewed',
        'found_state': report['before'], 'changes': [a for a in report['actions'] if a['classification'] == 'change'],
        'validation': report['validation'], 'inventory_updated': report['inventory_updated'],
        'deduplication_key': report['intervention_id'],
        'requires': ['review', 'deduplication', 'contradiction_check', 'version_preservation'],
        'automatic_promotion': False,
    })


class InterventionRunner:
    def __init__(self, store, executor=None):
        self.store = store
        self.executor = executor or SSHExecutor()

    def run(self, record, *, mode='READ', operation='inventory', parameters=None,
            objective='inventário/diagnóstico', approval=None, approval_ref=None, dry_run=False):
        device = Device.from_record(record)
        adapter = ADAPTERS[device.adapter]()
        plan = make_plan(device, operation, parameters, objective)
        parameters = parameters or {}
        if mode not in ('READ', 'PLAN', 'EXECUTE'):
            raise PolicyError('modo inválido')
        if mode == 'EXECUTE':
            if not self.store.durable and not dry_run:
                raise PolicyError('EXECUTE exige inventário e auditoria PostgreSQL')
            if approval != plan['plan_sha256'] or not approval_ref:
                raise PolicyError('aprovação explícita deve corresponder ao SHA-256 do plano')
            safe_text(approval_ref, 200)
            enforce_operation(device, operation, 'EXECUTE', parameters, approved=True)
        elif mode == 'READ':
            for item in plan['actions']:
                enforce_operation(device, item['operation'], 'READ', parameters)
        report = {
            'schema_version': 1, 'intervention_id': new_id(),
            'client': record.get('client', {'name': 'não informado'}),
            'site': record.get('site', {'site_id': device.site_id, 'name': 'não informado'}),
            'device': asdict(device), 'objective': objective, 'mode': mode,
            'status': 'running', 'dry_run': dry_run,
            'approval': {'plan_sha256': approval, 'reference': approval_ref, 'operator': getpass.getuser(),
                         'approved_at': now_iso()} if mode == 'EXECUTE' else None,
            'plan': plan, 'before': [], 'actions': [], 'results': [], 'snapshots': [],
            'backup': {'supported': adapter.backup_operation is not None,
                       'scope': adapter.backup_scope, 'status': 'not_performed'},
            'validation': {'passed': False, 'performed': False}, 'evidence': [],
            'rollback': {'mode': 'manual', 'performed': False, 'required': False,
                         'instructions': adapter.rollback_instructions},
            'errors': [], 'final_state': 'unknown', 'inventory_updated': False,
            'started_at': now_iso(), 'completed_at': None, 'closed': False,
        }
        iid = report['intervention_id']
        # Simulation has no store calls, SSH calls, local reports or inventory writes.
        if mode == 'PLAN' or dry_run:
            report.update(status='planned' if mode == 'PLAN' else 'simulated', completed_at=now_iso())
            report['memory_handoff'] = {'integration': 'PARCIAL', 'state': 'not_applicable'}
            return sanitize(report)
        self.store.begin(sanitize(report))
        changed = False

        def collect(stage, name, values=None, change=False):
            nonlocal changed
            intent = {'stage': stage, 'event': 'intent', 'operation': name,
                      'timestamp': now_iso()}
            self.store.event(iid, intent)
            permit = ChangePermit(iid, device.device_id, name, digest(values or {})) if change else None
            if change:
                # Even timeout/nonzero status can mean a partially applied change.
                changed = True
            result = self.executor.run(device, name, mode='EXECUTE' if change else 'READ',
                                       parameters=values, approved=change, permit=permit)
            action = sanitize(asdict(result))
            action['stage'] = stage
            report['actions'].append(action)
            report['results'].append({'operation': name, 'ok': result.ok})
            self.store.event(iid, {'stage': stage, 'event': 'result', 'action': action, 'timestamp': now_iso()})
            if not result.ok:
                raise PolicyError('ação falhou em ' + stage)
            evidence = {'evidence_id': new_id(), 'kind': stage, 'sha256': digest(action),
                        'data': action, 'canonical_data': canonical(action), 'collected_at': result.completed_at}
            report['evidence'].append(evidence)
            return result, action

        try:
            if mode == 'READ':
                for item in plan['actions']:
                    _, action = collect('READ', item['operation'], parameters)
                    report['before'].append(action)
                report['validation'] = {'performed': True, 'passed': True, 'scope': 'diagnostic_commands_exit_zero'}
                report['status'] = 'collected'
                report['final_state'] = 'diagnostics_collected'
            else:
                precheck, _ = collect('PRECHECK', adapter.validation_operation)
                # /bin/hostname returning an empty/secret-bearing name is not usable for recovery.
                from mimir_ops import HOSTNAME
                if not HOSTNAME.fullmatch(precheck.stdout.strip()):
                    raise PolicyError('estado anterior inválido para recuperação manual')
                for name in adapter.snapshot_operations:
                    _, action = collect('SNAPSHOT', name)
                    report['before'].append(action)
                    report['snapshots'].append(action)
                if adapter.backup_operation:
                    backup, action = collect('BACKUP', adapter.backup_operation)
                    if backup.stdout.strip() != precheck.stdout.strip():
                        raise PolicyError('estado mudou durante a preparação')
                    report['backup'].update(status='captured', evidence_sha256=digest(action), data=action)
                else:
                    report['backup']['status'] = 'unsupported'
                collect('EXECUTE', operation, parameters, change=True)
                validation, action = collect('VALIDATE', adapter.validation_operation)
                passed = adapter.validate(operation, parameters, validation)
                report['validation'] = {'performed': True, 'passed': passed, 'data': action,
                                        'expected': parameters}
                if not passed:
                    raise PolicyError('validação final divergente')
                report['status'] = 'validated'
                report['final_state'] = {'hostname': parameters['hostname']}
            report['inventory_updated'] = self.store.durable
        except (PolicyError, StoreError, OSError):
            # No raw exception text; drivers and device messages may contain secrets.
            report['status'] = 'failed'
            report['errors'].append('intervenção interrompida; verificar ações e diário persistido')
            report['rollback']['required'] = changed
            report['final_state'] = 'unknown_requires_manual_verification' if changed else 'no_change_requested'
            report['inventory_updated'] = False
        report['completed_at'] = now_iso()
        report['memory_handoff'] = memory_handoff(report)
        report['closure_requirements'] = {
            'found_state': bool(report['before']),
            'changes_recorded': bool(report['actions']),
            'validation': report['validation']['passed'],
            'inventory_updated': report['inventory_updated'],
            'audit_history': self.store.durable, 'report': True,
        }
        report['closure_ready'] = all(report['closure_requirements'].values())
        report = sanitize(report)
        raw, markdown = render_report(report)
        # PostgreSQL atomically persists report + inventory observation. Failure
        # leaves the prior running journal, never a falsely completed intervention.
        try:
            self.store.finish({'report': report, 'json_text': raw.decode(), 'markdown': markdown.decode()})
        except (StoreError, OSError):
            raise StoreError('finalização não confirmada; consulte intervenção ' + iid + '; não repetir EXECUTE') from None
        return report
