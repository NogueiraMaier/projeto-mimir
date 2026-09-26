#!/usr/bin/env python3
"""Operational model and exact adapter policy. No arbitrary remote shell API."""
from __future__ import annotations

import ipaddress
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from types import MappingProxyType

from ops_security import (PolicyError, StoreError, bounded_run, canonical, digest,
                          new_id, now_iso, redact, safe_text, sanitize,
                          secure_path, sha256_bytes, uuid_text)

MODES = {'READ', 'PLAN', 'EXECUTE'}
HOSTNAME = re.compile(r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*')


def validate_host(value):
    if not isinstance(value, str) or len(value) > 253 or '%' in value:
        raise PolicyError('host inválido')
    try:
        ipaddress.ip_address(value)
    except ValueError:
        if not HOSTNAME.fullmatch(value):
            raise PolicyError('host inválido') from None
    return value


@dataclass(frozen=True)
class Device:
    device_id: str
    site_id: str
    name: str
    device_type: str
    management_host: str
    ssh_user: str
    adapter: str
    management_port: int = 22
    permission_mode: str = 'READ'
    credential_ref: str = 'ssh-agent'
    vendor: str | None = None
    model: str | None = None
    firmware: str | None = None
    role: str = 'unspecified'
    primary_access_id: str | None = None

    def __post_init__(self):
        uuid_text(self.device_id)
        uuid_text(self.site_id)
        if self.primary_access_id is not None:
            uuid_text(self.primary_access_id)
        validate_host(self.management_host)
        safe_text(self.name)
        safe_text(self.device_type, 64)
        safe_text(self.role, 64)
        for value in (self.vendor, self.model, self.firmware):
            if value is not None:
                safe_text(value)
        if (type(self.management_port) is not int or not 1 <= self.management_port <= 65535
                or not re.fullmatch(r'[a-zA-Z_][a-zA-Z0-9._-]{0,63}', self.ssh_user)
                or self.permission_mode not in MODES or self.adapter not in ADAPTERS
                or not re.fullmatch(r'ssh-agent|file-ref:[a-zA-Z0-9._-]{1,64}', self.credential_ref)):
            raise PolicyError('acesso ou adapter inválido')

    @classmethod
    def from_record(cls, value):
        return cls(**{k: v for k, v in value.items() if k in cls.__dataclass_fields__})


@dataclass(frozen=True)
class Operation:
    name: str
    classification: str
    command: str
    parameters: tuple[str, ...] = ()

    def render(self, values=None):
        values = values or {}
        if set(values) != set(self.parameters):
            raise PolicyError('parâmetros não correspondem à operação')
        if self.parameters == ('hostname',):
            value = values['hostname']
            if not isinstance(value, str) or len(value) > 63 or not HOSTNAME.fullmatch(value):
                raise PolicyError('hostname inválido')
            return self.command + ' ' + value
        return self.command


class Adapter:
    name = 'generic-linux'
    operations = MappingProxyType({
        'system': Operation('system', 'read', 'uname -a'),
        'uptime': Operation('uptime', 'read', 'uptime'),
        'addresses': Operation('addresses', 'read', 'ip address'),
        'routes': Operation('routes', 'read', 'ip route'),
        'sockets': Operation('sockets', 'read', 'ss -lntup'),
        'disk': Operation('disk', 'read', 'df -h'),
        'memory': Operation('memory', 'read', 'free -m'),
        'hostname': Operation('hostname', 'read', '/bin/hostname'),
        'set-hostname': Operation('set-hostname', 'change', '/bin/hostname', ('hostname',)),
    })
    read_operations = ('system', 'uptime', 'addresses', 'routes', 'sockets', 'disk', 'memory', 'hostname')
    plan_operations = read_operations + ('set-hostname',)
    execute_operations = ('set-hostname',)
    snapshot_operations = ('system', 'hostname')
    backup_operation = 'hostname'
    backup_scope = 'hostname em execução; não é backup completo do equipamento'
    validation_operation = 'hostname'
    rollback_mode = 'manual'
    rollback_instructions = 'Operador autorizado deve restaurar o hostname anterior e validar; sem rollback automático.'
    forbidden_operations = ('arbitrary-command', 'reboot', 'shutdown', 'reset', 'format', 'delete', 'firewall', 'credentials')

    def inventory_commands(self):
        return [self.operations[n].render() for n in self.read_operations]

    def backup_command(self):
        return self.operations[self.backup_operation].render() if self.backup_operation else None

    def describe(self):
        return {k: getattr(self, k) for k in (
            'name', 'read_operations', 'plan_operations', 'execute_operations',
            'snapshot_operations', 'backup_operation', 'backup_scope',
            'validation_operation', 'rollback_mode', 'rollback_instructions', 'forbidden_operations')}

    def validate(self, operation, parameters, result):
        return (operation == 'set-hostname' and result.ok
                and result.stdout.strip() == parameters['hostname'])


class MikroTikAdapter(Adapter):
    name = 'mikrotik-routeros'
    operations = MappingProxyType({
        'system': Operation('system', 'read', '/system resource print without-paging'),
        'board': Operation('board', 'read', '/system routerboard print without-paging'),
        # Avoid detail/export: interfaces can carry credentials and scripts.
        'interfaces': Operation('interfaces', 'read', '/interface print without-paging'),
        'addresses': Operation('addresses', 'read', '/ip address print without-paging'),
        'routes': Operation('routes', 'read', '/ip route print without-paging'),
        'vlans': Operation('vlans', 'read', '/interface vlan print without-paging'),
    })
    read_operations = tuple(operations)
    plan_operations = read_operations
    execute_operations = ()
    snapshot_operations = read_operations
    backup_operation = None
    backup_scope = 'não suportado no MVP; export pode conter segredos e não garante restauração'
    validation_operation = None
    forbidden_operations = Adapter.forbidden_operations + ('export', 'backup-save', 'set', 'add', 'remove', 'scripts')


ADAPTERS = {Adapter.name: Adapter, MikroTikAdapter.name: MikroTikAdapter}


def resolve_operation(adapter, name, parameters=None):
    try:
        op = adapter.operations[name]
    except (KeyError, TypeError):
        raise PolicyError('operação não permitida neste adapter') from None
    op.render(parameters)
    return op


def enforce_operation(device, name, mode='READ', parameters=None, approved=False):
    if mode not in MODES:
        raise PolicyError('modo inválido')
    adapter = ADAPTERS[device.adapter]()
    op = resolve_operation(adapter, name, parameters)
    if mode == 'PLAN':
        if name not in adapter.plan_operations:
            raise PolicyError('operação não planejável')
        return op
    if device.permission_mode == 'PLAN':
        raise PolicyError('equipamento restrito a PLAN')
    if mode == 'READ' and name not in adapter.read_operations:
        raise PolicyError('READ permite somente diagnóstico')
    if mode == 'EXECUTE':
        if device.permission_mode != 'EXECUTE' or not approved or name not in adapter.execute_operations:
            raise PolicyError('EXECUTE exige permissão do equipamento, operação suportada e aprovação do plano')
    return op


def is_destructive(command):
    return bool(re.search(r'(?i)(?:^|[\s/])(reset[- ]configuration|factory[- ]?reset|reset-configuration|reboot|shutdown|format|rm)(?:\s|$)', command))


def classify_command(command):
    for adapter_type in ADAPTERS.values():
        for op in adapter_type.operations.values():
            if not op.parameters and command == op.command:
                return op.classification
    raise PolicyError('comando fora do catálogo; use uma operação nomeada')


def enforce(mode, command, approved=False):
    # Compatibility helper. String input never authorizes a change.
    if mode not in MODES or (mode == 'EXECUTE' and not approved):
        raise PolicyError('modo ou aprovação inválidos')
    return classify_command(command)


@dataclass
class ActionResult:
    command: str
    classification: str
    exit_code: int | None
    stdout: str
    stderr: str
    started_at: str
    completed_at: str
    dry_run: bool
    operation: str = ''
    error: str | None = None

    @property
    def ok(self):
        return self.exit_code == 0 and not self.error and not self.dry_run


class SSHExecutor:
    def __init__(self, timeout=30, known_hosts=None, key_refs=None, runner=bounded_run):
        if type(timeout) is not int or not 1 <= timeout <= 120:
            raise PolicyError('timeout inválido')
        self.timeout = timeout
        self.known_hosts = known_hosts or str(Path.home() / '.ssh' / 'known_hosts')
        self.key_refs = key_refs or {}
        self.runner = runner

    def argv(self, device, command):
        known = secure_path(self.known_hosts)
        args = ['/usr/bin/ssh', '-F', '/dev/null', '-T',
                '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
                '-o', f'UserKnownHostsFile={known}', '-o', 'GlobalKnownHostsFile=/dev/null',
                '-o', 'UpdateHostKeys=no', '-o', 'PasswordAuthentication=no',
                '-o', 'KbdInteractiveAuthentication=no', '-o', 'PreferredAuthentications=publickey',
                '-o', 'ForwardAgent=no', '-o', 'ClearAllForwardings=yes',
                '-o', 'ControlMaster=no', '-o', 'ControlPath=none',
                '-o', 'PermitLocalCommand=no', '-o', 'ProxyCommand=none', '-o', 'ProxyJump=none',
                '-o', 'ConnectionAttempts=1', '-o', f'ConnectTimeout={self.timeout}']
        if device.credential_ref == 'ssh-agent':
            agent = os.environ.get('SSH_AUTH_SOCK')
            if not agent or not os.path.isabs(agent):
                raise PolicyError('SSH Agent indisponível')
            args += ['-o', 'IdentityFile=none']
        else:
            path = self.key_refs.get(device.credential_ref)
            if not path:
                raise PolicyError('referência de chave não resolvida externamente')
            args += ['-o', 'IdentitiesOnly=yes', '-o', 'IdentityAgent=none',
                     '-i', secure_path(path, private=True)]
        # -- belongs BEFORE destination. Following destination it becomes part
        # of the remote shell command in OpenSSH.
        return args + ['-p', str(device.management_port), '-l', device.ssh_user,
                       '--', device.management_host, command]

    def run(self, device, name, *, mode='READ', parameters=None, approved=False, dry_run=False, permit=None):
        op = enforce_operation(device, name, mode, parameters, approved)
        if mode == 'EXECUTE' and not dry_run:
            from ops_workflow import ChangePermit
            if (not isinstance(permit, ChangePermit) or permit.device_id != device.device_id
                    or permit.operation != name or permit.parameters_sha256 != digest(parameters or {})):
                raise PolicyError('EXECUTE exige preparação e diário de intervenção')
        command = op.render(parameters)
        started = now_iso()
        if dry_run or mode == 'PLAN':
            return ActionResult(command, op.classification, None, '', '', started, now_iso(), True, name)
        args = self.argv(device, command)
        env = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'}
        if device.credential_ref == 'ssh-agent':
            env['SSH_AUTH_SOCK'] = os.environ['SSH_AUTH_SOCK']
        try:
            result = self.runner(args, timeout=self.timeout, limit=16384, env=env)
            return ActionResult(command, op.classification, result.exit_code,
                                redact(result.stdout), redact(result.stderr), started,
                                now_iso(), False, name, result.error)
        except OSError:
            return ActionResult(command, op.classification, None, '', '', started,
                                now_iso(), False, name, 'transport_unavailable')

    def command(self, device, remote_command, *, mode='READ', approved=False, dry_run=False):
        adapter = ADAPTERS[device.adapter]()
        names = [n for n in adapter.read_operations if adapter.operations[n].command == remote_command]
        if len(names) != 1 or mode == 'EXECUTE':
            raise PolicyError('comando não autorizado; EXECUTE requer fluxo de intervenção')
        return self.run(device, names[0], mode=mode, dry_run=dry_run)


def make_plan(device, operation='inventory', parameters=None, objective='inventário/diagnóstico'):
    safe_text(objective, 2000)
    adapter = ADAPTERS[device.adapter]()
    parameters = parameters or {}
    if operation == 'inventory':
        if parameters:
            raise PolicyError('inventário não aceita parâmetros')
        names = adapter.read_operations
    else:
        names = (operation,)
    actions = []
    for name in names:
        op = enforce_operation(device, name, 'PLAN', parameters)
        actions.append({'operation': name, 'command': op.render(parameters), 'classification': op.classification})
    plan = {'schema_version': 1, 'device': asdict(device), 'objective': objective,
            'operation': operation, 'parameters': parameters, 'actions': actions,
            'capabilities': adapter.describe(),
            'flow': ['PRECHECK', 'SNAPSHOT', 'BACKUP', 'EXECUTE', 'VALIDATE', 'REPORT']
                    if operation in adapter.execute_operations else ['READ', 'REPORT']}
    plan_text = canonical(plan)
    plan['plan_sha256'] = sha256_bytes(plan_text.encode())
    plan['canonical_plan'] = plan_text
    return plan


def render_report(payload):
    clean = sanitize(payload)
    raw = (canonical(clean) + '\n').encode()
    # JSON indentation in Markdown prevents untrusted device text creating HTML,
    # links, headings or breaking a fenced block. All fields remain visible.
    sections = ('client', 'site', 'device', 'objective', 'mode', 'status', 'before',
                'plan', 'actions', 'results', 'snapshots', 'backup', 'validation',
                'evidence', 'rollback', 'errors', 'final_state', 'inventory_updated',
                'memory_handoff', 'started_at', 'completed_at', 'intervention_id')
    lines = ['# Relatório de intervenção', '']
    import json
    for key in sections:
        lines += ['## ' + key, '']
        lines.extend('    ' + line for line in json.dumps(clean.get(key), ensure_ascii=False, indent=2).splitlines())
        lines.append('')
    return raw, ('\n'.join(lines) + '\n').encode()


def write_report(report_dir, intervention_id, payload):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', intervention_id):
        raise PolicyError('identificador de relatório inválido')
    report_dir = Path(report_dir).absolute()
    report_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    if report_dir.resolve() != report_dir or report_dir.stat().st_uid != os.geteuid() or report_dir.stat().st_mode & 0o077:
        raise PolicyError('diretório de relatórios deve pertencer ao operador e ter modo 0700')
    raw, md = render_report(payload)
    paths = (report_dir / f'{intervention_id}.json', report_dir / f'{intervention_id}.md')
    # Immutable local evidence: never replace a report or follow a symlink.
    for path, data in zip(paths, (raw, md)):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    return *paths, sha256_bytes(raw), sha256_bytes(md)
