#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from mimir_ops import ADAPTERS, Device, SSHExecutor, new_id, now_iso, write_report, PolicyError


def device_from_json(path: Path) -> Device:
    return Device(**json.loads(path.read_text(encoding="utf-8")))


def main() -> int:
    parser = argparse.ArgumentParser(description="Mímir operational MVP")
    sub = parser.add_subparsers(dest="verb", required=True)

    inspect_p = sub.add_parser("inspect")
    inspect_p.add_argument("device_json")
    inspect_p.add_argument("--reports", default="reports/ops")

    plan_p = sub.add_parser("plan")
    plan_p.add_argument("device_json")

    exec_p = sub.add_parser("execute")
    exec_p.add_argument("device_json")
    exec_p.add_argument("remote_command")
    exec_p.add_argument("--approve", action="store_true")
    exec_p.add_argument("--dry-run", action="store_true")
    exec_p.add_argument("--reports", default="reports/ops")

    args = parser.parse_args()
    device = device_from_json(Path(args.device_json))
    adapter = ADAPTERS[device.adapter]()
    executor = SSHExecutor()

    if args.verb == "plan":
        print(json.dumps({
            "device": device.name,
            "adapter": device.adapter,
            "commands": adapter.inventory_commands(),
        }, ensure_ascii=False, indent=2))
        return 0

    if args.verb == "inspect":
        iid = new_id()
        started = now_iso()
        actions = [
            executor.command(device, cmd, mode="READ")
            for cmd in adapter.inventory_commands()
        ]
        payload = {
            "intervention_id": iid,
            "device": device.name,
            "objective": "inventário/diagnóstico",
            "mode": "READ",
            "status": "succeeded" if all(a.exit_code == 0 for a in actions) else "failed",
            "started_at": started,
            "completed_at": now_iso(),
            "actions": [a.__dict__ for a in actions],
        }
        paths = write_report(Path(args.reports), iid, payload)
        print(json.dumps({
            "intervention_id": iid,
            "report_json": str(paths[0]),
            "report_markdown": str(paths[1]),
        }, ensure_ascii=False))
        return 0 if payload["status"] == "succeeded" else 2

    result = executor.command(
        device,
        args.remote_command,
        mode="EXECUTE",
        approved=args.approve,
        dry_run=args.dry_run,
    )
    iid = new_id()
    payload = {
        "intervention_id": iid,
        "device": device.name,
        "objective": "comando controlado",
        "mode": "EXECUTE",
        "status": "succeeded" if result.exit_code in (0, None) else "failed",
        "started_at": result.started_at,
        "completed_at": result.completed_at,
        "actions": [result.__dict__],
    }
    paths = write_report(Path(args.reports), iid, payload)
    print(json.dumps({
        "intervention_id": iid,
        "result": result.__dict__,
        "report_json": str(paths[0]),
        "report_markdown": str(paths[1]),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PolicyError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        raise SystemExit(3)
