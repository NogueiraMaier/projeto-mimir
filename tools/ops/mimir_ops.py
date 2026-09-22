#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

MODES = {"READ", "PLAN", "EXECUTE"}
READ_PREFIXES = (
    "show ", "print ", "display ", "ip address", "ip route", "ip link",
    "ss ", "uname", "uptime", "df ", "free ", "rc-status", "rc-service ",
)
DESTRUCTIVE_PATTERNS = (
    r"\bfactory[- ]?reset\b", r"\breset configuration\b", r"\bformat\b",
    r"\breboot\b", r"\bshutdown\b", r"\brm\s+-rf\b",
    r"\b/system\s+reset-configuration\b",
)
SECRET_PATTERNS = [
    re.compile(r"(?i)(password|passwd|token|secret|api[_-]?key)\s*[=:]\s*\S+"),
    re.compile(r"(?i)authorization:\s*\S+"),
]


class PolicyError(RuntimeError):
    pass


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def redact(text: str) -> str:
    result = text
    for pattern in SECRET_PATTERNS:
        result = pattern.sub("<redacted>", result)
    return result


def is_destructive(command: str) -> bool:
    return any(re.search(p, command, re.IGNORECASE) for p in DESTRUCTIVE_PATTERNS)


def classify_command(command: str) -> str:
    lowered = command.strip().lower()
    return "read" if any(lowered.startswith(p) for p in READ_PREFIXES) else "change"


def enforce(mode: str, command: str, approved: bool = False) -> str:
    mode = mode.upper()
    if mode not in MODES:
        raise PolicyError(f"modo inválido: {mode}")
    if is_destructive(command):
        raise PolicyError("ação destrutiva bloqueada por política")
    classification = classify_command(command)
    if mode == "READ" and classification != "read":
        raise PolicyError("READ permite somente diagnóstico")
    if mode == "EXECUTE" and classification == "change" and not approved:
        raise PolicyError("EXECUTE exige aprovação explícita para alterações")
    return classification


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
    permission_mode: str = "READ"
    credential_ref: str = "ssh-agent"
    vendor: str | None = None
    model: str | None = None
    firmware: str | None = None


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


class SSHExecutor:
    def __init__(self, timeout: int = 30, known_hosts: str | None = None):
        self.timeout = timeout
        self.known_hosts = known_hosts or str(Path.home() / ".ssh" / "known_hosts")

    def command(self, device: Device, remote_command: str, *, mode: str, approved: bool = False, dry_run: bool = False) -> ActionResult:
        classification = enforce(mode, remote_command, approved)
        started = now_iso()
        if dry_run or mode.upper() == "PLAN":
            return ActionResult(remote_command, classification, None, "", "", started, now_iso(), True)

        ssh_cmd = [
            "/usr/bin/ssh",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", f"UserKnownHostsFile={self.known_hosts}",
            "-o", f"ConnectTimeout={self.timeout}",
            "-p", str(device.management_port),
            f"{device.ssh_user}@{device.management_host}",
            "--", remote_command,
        ]
        completed = subprocess.run(
            ssh_cmd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=self.timeout,
            check=False,
            env={**os.environ, "LC_ALL": "C"},
        )
        return ActionResult(
            remote_command,
            classification,
            completed.returncode,
            redact(completed.stdout),
            redact(completed.stderr),
            started,
            now_iso(),
            False,
        )


class Adapter:
    name = "generic-linux"

    def inventory_commands(self) -> list[str]:
        return ["uname -a", "uptime", "ip address", "ip route", "ss -lntup", "df -h", "free -m"]

    def backup_command(self) -> str | None:
        return None


class MikroTikAdapter(Adapter):
    name = "mikrotik-routeros"

    def inventory_commands(self) -> list[str]:
        return [
            "/system resource print without-paging",
            "/system routerboard print without-paging",
            "/interface print detail without-paging",
            "/ip address print detail without-paging",
            "/ip route print detail without-paging",
            "/interface vlan print detail without-paging",
        ]

    def backup_command(self) -> str:
        return "/export terse"


ADAPTERS = {Adapter.name: Adapter, MikroTikAdapter.name: MikroTikAdapter}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_report(report_dir: Path, intervention_id: str, payload: dict) -> tuple[Path, Path, str, str]:
    report_dir.mkdir(parents=True, exist_ok=True)
    json_path = report_dir / f"{intervention_id}.json"
    md_path = report_dir / f"{intervention_id}.md"

    json_bytes = (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()
    json_path.write_bytes(json_bytes)

    lines = [
        f"# Intervenção {intervention_id}",
        "",
        f"- Cliente: {payload.get('client', 'não informado')}",
        f"- Site: {payload.get('site', 'não informado')}",
        f"- Equipamento: {payload.get('device', 'não informado')}",
        f"- Objetivo: {payload.get('objective', '')}",
        f"- Modo: {payload.get('mode', '')}",
        f"- Estado final: {payload.get('status', '')}",
        f"- Início: {payload.get('started_at', '')}",
        f"- Fim: {payload.get('completed_at', '')}",
        "",
        "## Ações",
        "",
    ]
    for action in payload.get("actions", []):
        lines += [
            f"### {action.get('command','')}",
            "",
            f"- Classificação: {action.get('classification','')}",
            f"- Exit code: {action.get('exit_code')}",
            f"- Dry-run: {action.get('dry_run')}",
            "",
            "    " + action.get("stdout", "").replace("\n", "\n    "),
            "",
        ]

    md_bytes = ("\n".join(lines) + "\n").encode()
    md_path.write_bytes(md_bytes)
    return json_path, md_path, sha256_bytes(json_bytes), sha256_bytes(md_bytes)


def new_id() -> str:
    return str(uuid.uuid4())
