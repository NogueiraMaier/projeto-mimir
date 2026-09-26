"""Shared fail-closed input, redaction and bounded subprocess primitives."""
from __future__ import annotations

import hashlib
import json
import os
import re
import selectors
import signal
import stat
import subprocess
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


class PolicyError(RuntimeError):
    pass


class StoreError(RuntimeError):
    pass


# Deliberately discard an entire string containing a secret marker. This also
# covers quoted/multiline values and incomplete PEM blocks after truncation.
SECRET = re.compile(
    r'(?i)(?:password|passwd|senha|passphrase|token|secret|api[_-]?key|'
    r'authorization|cookie|community|private[_ -]?key|preshared[_ -]?key)'
    r'[\s"\']*[:=]|-----BEGIN [A-Z ]*PRIVATE KEY|'
    r'\b(?:nvapi-|sk-|ghp_|github_pat_)[A-Za-z0-9_-]{12,}|'
    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|'
    r'\bbearer\s+[^\s]+|'
    r'\b[a-z][a-z0-9+.-]*://[^\s/@]+:[^\s/@]+@'
)
SECRET_KEY = re.compile(
    r'(?i)(?:password|passwd|senha|passphrase|token|secret|api[_-]?key|'
    r'authorization|cookie|community|private[_-]?key|preshared[_-]?key)'
)


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def new_id():
    return str(uuid.uuid4())


def uuid_text(value):
    try:
        if not isinstance(value, str) or str(uuid.UUID(value)) != value:
            raise ValueError
    except (ValueError, AttributeError):
        raise PolicyError('UUID canônico obrigatório') from None
    return value


def redact(value: str) -> str:
    value = re.sub(r'[\x00-\x08\x0b-\x1f\x7f]', '', value)
    if SECRET.search(value):
        return '<redacted>'
    return value


def sanitize(value):
    if isinstance(value, dict):
        return {redact(str(k)): '<redacted>' if SECRET_KEY.search(str(k)) else sanitize(v)
                for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [sanitize(v) for v in value]
    if isinstance(value, str):
        return redact(value)
    return value


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':'), allow_nan=False)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def digest(value):
    return sha256_bytes(canonical(value).encode())


def safe_text(value, maximum=200):
    if (not isinstance(value, str) or not value.strip() or len(value) > maximum
            or value != redact(value) or any(ord(c) < 32 for c in value)):
        raise PolicyError('texto vazio, inválido ou possível segredo')
    return value


def secure_path(value, *, private=False):
    path = Path(value)
    if not path.is_absolute() or not re.fullmatch(r'/[A-Za-z0-9/._-]+', str(path)):
        raise PolicyError('caminho absoluto simples obrigatório')
    try:
        info = path.lstat()
        if (path.resolve(strict=True) != path or not stat.S_ISREG(info.st_mode)
                or info.st_uid not in (0, os.geteuid()) or info.st_mode & 0o022
                or (private and info.st_mode & 0o077)):
            raise PolicyError('arquivo inseguro: proprietário, link ou permissões')
        # Reject writable parents as well; /tmp is acceptable only with sticky bit.
        for parent in path.parents:
            mode = parent.stat().st_mode
            if mode & 0o022 and not mode & stat.S_ISVTX:
                raise PolicyError('diretório pai permite alteração por terceiros')
    except OSError:
        raise PolicyError('arquivo seguro indisponível') from None
    return str(path)


@dataclass(frozen=True)
class ProcessResult:
    exit_code: int | None
    stdout: str
    stderr: str
    error: str | None = None


def bounded_run(argv, *, timeout=30, limit=262144, env=None, input_data=b''):
    """Bound BOTH streams while reading; never spool unredacted output to disk."""
    if not 0 < timeout <= 120 or not 1 <= limit <= 8 * 1024 * 1024:
        raise PolicyError('limites inválidos')
    proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, shell=False, start_new_session=True,
                            env=env or {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})
    buffers = {'stdout': bytearray(), 'stderr': bytearray()}
    error = None
    deadline = time.monotonic() + timeout
    pending = memoryview(input_data)
    try:
        with selectors.DefaultSelector() as selector:
            for stream, label in ((proc.stdout, 'stdout'), (proc.stderr, 'stderr')):
                os.set_blocking(stream.fileno(), False)
                selector.register(stream, selectors.EVENT_READ, label)
            if pending:
                os.set_blocking(proc.stdin.fileno(), False)
                selector.register(proc.stdin, selectors.EVENT_WRITE, 'stdin')
            else:
                proc.stdin.close()
            total = 0
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    error = 'timeout'
                    break
                for key, _ in selector.select(min(remaining, .1)):
                    if key.data == 'stdin':
                        try:
                            pending = pending[os.write(key.fd, pending[:8192]):]
                        except BrokenPipeError:
                            pending = memoryview(b'')
                        if not pending:
                            selector.unregister(key.fileobj)
                            key.fileobj.close()
                        continue
                    chunk = os.read(key.fd, 8192)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(chunk)
                    if total > limit:
                        error = 'output_limit'
                        break
                    buffers[key.data].extend(chunk)
                if error:
                    break
            if not error:
                try:
                    proc.wait(timeout=max(.001, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    error = 'timeout'
    finally:
        # Kill the group even if the leader exited but a child retained a pipe.
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
        for stream in (proc.stdin, proc.stdout, proc.stderr):
            stream.close()
    if error:
        return ProcessResult(proc.returncode, '', '', error)
    return ProcessResult(proc.returncode,
                         buffers['stdout'].decode('utf-8', 'replace'),
                         buffers['stderr'].decode('utf-8', 'replace'))
