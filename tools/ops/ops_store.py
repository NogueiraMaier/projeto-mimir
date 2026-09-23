"""Controlled PostgreSQL API, matching existing peer/socket/psql conventions."""
from __future__ import annotations

import base64
import ipaddress
import json
import re

from mimir_ops import Device
from ops_security import (PolicyError, StoreError, bounded_run, canonical, new_id,
                          safe_text, sanitize, uuid_text)

FIELDS = {
    'client': {'client_id', 'slug', 'name'},
    'site': {'site_id', 'client_id', 'slug', 'name', 'location_note', 'vlans', 'networks'},
    'device': set(Device.__dataclass_fields__) | {'interfaces', 'addresses', 'accesses', 'dependencies'},
}


def object_fields(value, allowed, required=()):
    if not isinstance(value, dict) or set(value) - set(allowed) or not set(required) <= set(value):
        raise PolicyError('campos desconhecidos ou obrigatórios ausentes')
    return value


def normalize_inventory(kind, value):
    if kind not in FIELDS:
        raise PolicyError('tipo de inventário inválido')
    object_fields(value, FIELDS[kind])
    if sanitize(value) != value:
        raise PolicyError('inventário contém possível segredo ou controle inválido')
    value = json.loads(canonical(value))
    key = kind + '_id'
    value.setdefault(key, new_id())
    uuid_text(value[key])
    safe_text(value.get('name'))
    if kind in ('client', 'site'):
        if not isinstance(value.get('slug'), str) or not re.fullmatch(r'[a-z0-9][a-z0-9._-]{0,63}', value['slug']):
            raise PolicyError('slug inválido')
    if kind == 'site':
        uuid_text(value.get('client_id'))
        if value.get('location_note') is not None:
            safe_text(value['location_note'], 1000)
    if kind == 'device':
        accesses = value.get('accesses')
        if not isinstance(accesses, list) or not accesses:
            raise PolicyError('equipamento exige um acesso primário')
        if not value.get('primary_access_id') and not accesses[0].get('access_id'):
            accesses[0]['access_id'] = new_id()
        primary = value.get('primary_access_id') or accesses[0].get('access_id')
        value['primary_access_id'] = primary
        uuid_text(primary)
    specs = {
        'vlans': ({'vlan_id', 'tag', 'name'}, {'tag', 'name'}, 'vlan_id'),
        'networks': ({'network_id', 'prefix', 'vlan_id', 'name'}, {'prefix', 'name'}, 'network_id'),
        'interfaces': ({'interface_id', 'name', 'mac', 'mtu', 'role', 'vlan_id'}, {'name'}, 'interface_id'),
        'addresses': ({'address_id', 'interface_id', 'address', 'network_id'}, {'interface_id', 'address'}, 'address_id'),
        'accesses': ({'access_id', 'method', 'host', 'port', 'username', 'credential_ref'},
                     {'method', 'host', 'port', 'username', 'credential_ref'}, 'access_id'),
        'dependencies': ({'depends_on_device_id', 'relation'}, {'depends_on_device_id', 'relation'}, None),
    }
    canonical_access = None
    for field, (allowed, required, identity) in specs.items():
        if field not in FIELDS[kind]:
            continue
        items = value.setdefault(field, [])
        if not isinstance(items, list) or len(items) > 256:
            raise PolicyError('lista de inventário inválida ou excessiva')
        for item in items:
            object_fields(item, allowed, required)
            if identity:
                item.setdefault(identity, new_id())
            for k, v in item.items():
                if k.endswith('_id') and v is not None:
                    uuid_text(v)
                elif k in ('name', 'role', 'relation'):
                    safe_text(v)
            if field == 'vlans' and (type(item['tag']) is not int or not 1 <= item['tag'] <= 4094):
                raise PolicyError('VLAN fora de 1..4094')
            if field == 'networks':
                try:
                    item['prefix'] = str(ipaddress.ip_network(item['prefix'], strict=True))
                except ValueError:
                    raise PolicyError('sub-rede inválida') from None
            if field == 'addresses':
                try:
                    item['address'] = str(ipaddress.ip_interface(item['address']))
                except ValueError:
                    raise PolicyError('IP inválido') from None
            if field == 'interfaces':
                if item.get('mac') and not re.fullmatch(r'(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}', item['mac']):
                    raise PolicyError('MAC inválido')
                if 'mtu' in item and (type(item['mtu']) is not int or not 68 <= item['mtu'] <= 65535):
                    raise PolicyError('MTU inválido')
            if field == 'accesses':
                if item['method'] != 'ssh':
                    raise PolicyError('somente acesso SSH implementado')
                if item['access_id'] == value['primary_access_id']:
                    canonical_access = item
    if kind == 'device':
        if canonical_access is None:
            raise PolicyError('acesso primário não encontrado')
        for field, expected in {
            'management_host': canonical_access['host'],
            'management_port': canonical_access['port'],
            'ssh_user': canonical_access['username'],
            'credential_ref': canonical_access['credential_ref'],
        }.items():
            if field in value and value[field] != expected:
                raise PolicyError('campos de acesso duplicados não coincidem')
            value[field] = expected
        device = Device.from_record(value)
        from dataclasses import asdict
        value.update(asdict(device))
    return value


class PostgresStore:
    durable = True

    def __init__(self, runner=bounded_run):
        self.runner = runner

    def call(self, method, **values):
        allowed = {'inventory.add', 'inventory.list', 'inventory.show',
                   'intervention.begin', 'intervention.event', 'intervention.finish', 'history', 'report'}
        if method not in allowed:
            raise PolicyError('método desconhecido')
        request = sanitize({'method': method, **values})
        raw = canonical(request).encode()
        if len(raw) > 4 * 1024 * 1024:
            raise StoreError('requisição excede limite')
        # Base64 contains no SQL delimiters; payload goes on stdin, never argv.
        encoded = base64.b64encode(raw).decode('ascii')
        read_only = method in {'inventory.list', 'inventory.show', 'history', 'report'}
        sql = ("BEGIN" + (" READ ONLY" if read_only else '') + ";\n"
               "SET LOCAL statement_timeout='15s'; SET LOCAL lock_timeout='3s';\n"
               "SELECT mimir.ops_api(convert_from(decode('" + encoded + "','base64'),'UTF8')::jsonb)::text;\nCOMMIT;\n")
        env = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C.UTF-8',
               'PGCONNECT_TIMEOUT': '5', 'PGAPPNAME': 'mimir-ops', 'PGPASSFILE': '/dev/null',
               'PGSYSCONFDIR': '/nonexistent',
               'PGOPTIONS': '-c statement_timeout=15000 -c lock_timeout=3000'}
        from pathlib import Path
        psql = '/usr/bin/psql'
        if not Path(psql).is_file() and Path('/usr/lib64/postgresql-17/bin/psql').is_file():
            psql = '/usr/lib64/postgresql-17/bin/psql'
        args = [psql, '-X', '-w', '-qAt', '-h', '/run/postgresql', '-p', '5432',
                '-U', 'mimir_ops', '-d', 'mimir_memory', '-v', 'ON_ERROR_STOP=1']
        try:
            result = self.runner(args, input_data=sql.encode(), env=env, timeout=30, limit=8*1024*1024)
            if result.exit_code != 0 or result.error:
                raise StoreError('PostgreSQL indisponível, identidade negada ou requisição rejeitada')
            payload = json.loads(result.stdout)
        except (OSError, ValueError):
            raise StoreError('resposta PostgreSQL indisponível ou inválida') from None
        return sanitize(payload)

    def add(self, kind, payload):
        return self.call('inventory.add', kind=kind, payload=normalize_inventory(kind, payload))

    def list(self, kind, *, offset=0):
        if kind not in FIELDS or type(offset) is not int or not 0 <= offset <= 1000000:
            raise PolicyError('consulta inválida')
        return self.call('inventory.list', kind=kind, offset=offset)

    def show(self, kind, identity):
        if kind not in FIELDS:
            raise PolicyError('tipo inválido')
        result = self.call('inventory.show', kind=kind, id=uuid_text(identity))
        if result is None:
            raise StoreError('registro não encontrado')
        return result

    def begin(self, report):
        return self.call('intervention.begin', payload=report)

    def event(self, iid, event):
        return self.call('intervention.event', id=uuid_text(iid), payload=event)

    def finish(self, report):
        return self.call('intervention.finish', payload=report)

    def history(self, device_id, offset=0):
        if type(offset) is not int or not 0 <= offset <= 1000000:
            raise PolicyError('offset inválido')
        return self.call('history', id=uuid_text(device_id), offset=offset)

    def report(self, iid):
        result = self.call('report', id=uuid_text(iid))
        if result is None:
            raise StoreError('intervenção não encontrada')
        return result
