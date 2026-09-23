#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import stat
import sys
from pathlib import Path

from mimir_ops import ADAPTERS, Device, SSHExecutor, PolicyError, render_report, sanitize, write_report
from ops_security import StoreError
from ops_store import PostgresStore
from ops_workflow import InterventionRunner, LocalJournal


def read_json(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > 1048576:
            raise PolicyError('JSON deve ser arquivo regular de até 1 MiB')
        data = stream.read(1048577)
        if len(data) > 1048576:
            raise PolicyError('JSON excedeu limite')
    result = json.loads(data)
    if not isinstance(result, dict):
        raise PolicyError('JSON deve conter objeto')
    return result


def device_from_json(path):
    # Keep the original entry point, but reject unexpected keys and secrets.
    from ops_store import normalize_inventory
    return Device.from_record(normalize_inventory('device', read_json(path)))


def operation_parser(sub, name):
    p = sub.add_parser(name)
    p.add_argument('target', help='UUID persistido ou arquivo JSON para plano/diagnóstico legado')
    p.add_argument('--operation', default='inventory')
    p.add_argument('--hostname')
    p.add_argument('--objective', default='inventário/diagnóstico')
    p.add_argument('--approve', metavar='PLAN_SHA256', help='confirma o hash exato emitido por plan')
    p.add_argument('--approval-ref', help='referência externa de autorização, sem segredo')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--known-hosts')
    p.add_argument('--key-map', help='JSON externo: file-ref:ID -> caminho absoluto da chave')
    p.add_argument('--timeout', type=int, default=30)
    p.add_argument('--reports', default='reports/ops')
    return p


def build_parser():
    p = argparse.ArgumentParser(description='Mímir: inventário PostgreSQL e operações controladas')
    sub = p.add_subparsers(dest='verb', required=True)
    inventory = sub.add_parser('inventory').add_subparsers(dest='kind', required=True)
    for kind in ('client', 'site', 'device'):
        verbs = inventory.add_parser(kind).add_subparsers(dest='action', required=True)
        verbs.add_parser('add').add_argument('--file', required=True)
        verbs.add_parser('list').add_argument('--offset', type=int, default=0)
        verbs.add_parser('show').add_argument('id')
    ops = sub.add_parser('ops').add_subparsers(dest='action', required=True)
    for name in ('inspect', 'plan', 'execute'):
        operation_parser(ops, name)
        operation_parser(sub, name)  # Original CLI verbs remain available.
    h = ops.add_parser('history')
    h.add_argument('device')
    h.add_argument('--offset', type=int, default=0)
    r = ops.add_parser('report')
    r.add_argument('id')
    r.add_argument('--format', choices=('json', 'markdown'), default='json')
    ops.add_parser('adapters')
    return p


def main(argv=None, store=None, executor=None):
    args = build_parser().parse_args(argv)
    store = store or PostgresStore()
    if args.verb == 'inventory':
        if args.action == 'add':
            output = store.add(args.kind, read_json(args.file))
        elif args.action == 'list':
            output = store.list(args.kind, offset=args.offset)
        else:
            output = store.show(args.kind, args.id)
    elif args.verb == 'ops' and args.action == 'history':
        output = store.history(args.device, args.offset)
    elif args.verb == 'ops' and args.action == 'report':
        output = store.report(args.id)
        if args.format == 'markdown':
            sys.stdout.write(render_report(output)[1].decode())
            return 0
    elif args.verb == 'ops' and args.action == 'adapters':
        output = {k: v().describe() for k, v in ADAPTERS.items()}
    else:
        action = args.action if args.verb == 'ops' else args.verb
        # A UUID selects the DB. JSON is an explicit offline/legacy diagnostic input.
        if args.target.endswith('.json'):
            from ops_store import normalize_inventory
            record = normalize_inventory('device', read_json(args.target))
            actual_store = LocalJournal(args.reports)
        else:
            # Dry-run with UUID needs a read of inventory; use JSON for fully offline simulation.
            record = store.show('device', args.target)
            actual_store = store
        key_refs = read_json(args.key_map) if args.key_map else {}
        actual_executor = executor or SSHExecutor(args.timeout, args.known_hosts, key_refs)
        output = InterventionRunner(actual_store, actual_executor).run(
            record, mode={'inspect': 'READ', 'plan': 'PLAN', 'execute': 'EXECUTE'}[action],
            operation=args.operation, parameters={'hostname': args.hostname} if args.hostname else {},
            objective=args.objective, approval=args.approve, approval_ref=args.approval_ref,
            dry_run=args.dry_run)
        if action != 'plan' and not args.dry_run:
            try:
                write_report(Path(args.reports), output['intervention_id'], output)
            except (OSError, PolicyError):
                # DB report remains available. Never re-execute to regenerate a file.
                print('ERRO: exportação local falhou; intervenção ' + output['intervention_id'], file=sys.stderr)
                return 2
        print(json.dumps(sanitize(output), ensure_ascii=False, indent=2))
        return 2 if output['status'] == 'failed' else 0
    print(json.dumps(sanitize(output), ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (PolicyError, StoreError) as exc:
        print('ERRO: ' + str(exc), file=sys.stderr)
        raise SystemExit(3)
    except (OSError, ValueError, TypeError, KeyError):
        print('ERRO: entrada inválida ou recurso local indisponível', file=sys.stderr)
        raise SystemExit(3)
