#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = (
    Path(__file__).resolve().parent
    / "mimir-capture-sessions.py"
)


def write_jsonl(path: Path, records: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        for record in records:
            stream.write(
                json.dumps(record, ensure_ascii=False) + "\n"
            )


def message(role: str, text_value: str, owner: bool = True) -> dict:
    data = {
        "role": role,
        "content": [
            {
                "type": "text",
                "text": text_value,
            }
        ],
        "timestamp": "2026-07-30T12:00:00Z",
    }

    if role == "user":
        data["__openclaw"] = {
            "senderIsOwner": owner,
        }

    return {
        "type": "message",
        "message": data,
    }


class CaptureSessionsTest(unittest.TestCase):
    def run_capture(self, root: Path) -> tuple[int, str, str]:
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--sessions-dir",
                str(root),
                "--min-age-seconds",
                "0",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

        return (
            completed.returncode,
            completed.stdout,
            completed.stderr,
        )

    def test_filters_and_safe_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            ready_id = "11111111-1111-4111-8111-111111111111"
            running_id = "22222222-2222-4222-8222-222222222222"
            blocked_id = "33333333-3333-4333-8333-333333333333"

            index = {
                "ready": {
                    "sessionId": ready_id,
                    "sessionFile": str(root / f"{ready_id}.jsonl"),
                    "status": "done",
                },
                "running": {
                    "sessionId": running_id,
                    "sessionFile": str(root / f"{running_id}.jsonl"),
                    "status": "running",
                },
                "blocked": {
                    "sessionId": blocked_id,
                    "sessionFile": str(root / f"{blocked_id}.jsonl"),
                    "status": "done",
                },
            }

            (root / "sessions.json").write_text(
                json.dumps(index),
                encoding="utf-8",
            )

            write_jsonl(
                root / f"{ready_id}.jsonl",
                [
                    {"type": "session"},
                    message("user", "Defina o serviço técnico."),
                    message("assistant", "Serviço definido."),
                    message(
                        "user",
                        "Mensagem de outro remetente.",
                        owner=False,
                    ),
                    {
                        "type": "message",
                        "message": {
                            "role": "toolResult",
                            "content": [
                                {
                                    "type": "text",
                                    "text": "resultado interno",
                                }
                            ],
                        },
                    },
                ],
            )

            write_jsonl(
                root / f"{running_id}.jsonl",
                [
                    message("user", "Sessão em andamento."),
                ],
            )

            synthetic_secret = (
                "tok" + "en=" + "A" * 32
            )

            write_jsonl(
                root / f"{blocked_id}.jsonl",
                [
                    message("user", synthetic_secret),
                    message("assistant", "Registro recebido."),
                ],
            )

            write_jsonl(
                root / f"{ready_id}.trajectory.jsonl",
                [
                    message("user", "Trajetória ignorada."),
                ],
            )

            code, stdout, stderr = self.run_capture(root)

            self.assertEqual(code, 0, stderr)

            result = json.loads(stdout)

            self.assertFalse(result["database_write"])
            self.assertFalse(result["staging_write"])
            self.assertFalse(result["content_exposed"])
            self.assertEqual(result["files_considered"], 3)
            self.assertEqual(result["ready"], 1)
            self.assertEqual(result["blocked"], 1)
            self.assertEqual(result["skipped"], 1)
            self.assertEqual(result["errors"], 0)

            self.assertNotIn(
                "Defina o serviço técnico.",
                stdout,
            )
            self.assertNotIn(
                synthetic_secret,
                stdout,
            )
            self.assertNotIn(
                "resultado interno",
                stdout,
            )


if __name__ == "__main__":
    unittest.main()
