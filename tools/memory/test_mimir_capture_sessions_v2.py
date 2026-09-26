#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = (
    Path(__file__).resolve().parent
    / "mimir-capture-sessions-v2.py"
)


def user_message(
    text: str,
    *,
    owner: bool | None = True,
    seq: int = 1,
    message_id: str = "u1",
) -> dict:
    metadata = {
        "id": message_id,
        "seq": seq,
        "recordTimestampMs": 1000 + seq,
        "senderId": "operator",
        "transport": "test",
        "transcriptPosition": seq,
    }

    if owner is not None:
        metadata["senderIsOwner"] = owner

    return {
        "role": "user",
        "content": text,
        "timestamp": 1000 + seq,
        "__openclaw": metadata,
    }


def assistant_message(
    text: str,
    *,
    seq: int = 2,
    message_id: str = "a1",
) -> dict:
    return {
        "role": "assistant",
        "content": [
            {
                "type": "thinking",
                "thinking": "internal thought",
            },
            {
                "type": "text",
                "text": text,
            },
            {
                "type": "toolCall",
                "name": "internal_tool",
                "arguments": {"x": 1},
            },
        ],
        "timestamp": 1000 + seq,
        "__openclaw": {
            "id": message_id,
            "seq": seq,
            "recordTimestampMs": 1000 + seq,
            "transcriptPosition": seq,
        },
    }


class CaptureSessionsV2Test(unittest.TestCase):
    def prepare_fake(
        self,
        root: Path,
        fixture: dict,
    ) -> tuple[Path, Path]:
        fixture_path = root / "fixture.json"
        fixture_path.write_text(
            json.dumps(fixture, ensure_ascii=False),
            encoding="utf-8",
        )

        fake = root / "fake_openclaw.py"
        fake.write_text(
            textwrap.dedent(
                """
                import json
                import os
                import sys

                with open(
                    os.environ["MIMIR_FAKE_OPENCLAW_FIXTURE"],
                    encoding="utf-8",
                ) as stream:
                    fixture = json.load(stream)

                args = sys.argv[1:]

                if args and args[0] == "sessions":
                    print(json.dumps(fixture["sessions"]))
                    raise SystemExit(0)

                if args[:3] == ["gateway", "call", "chat.history"]:
                    params = json.loads(
                        args[args.index("--params") + 1]
                    )
                    key = params["sessionKey"]
                    offset = str(params.get("offset", 0))
                    print(
                        json.dumps(
                            fixture["history"][key][offset]
                        )
                    )
                    raise SystemExit(0)

                raise SystemExit(3)
                """
            ).lstrip(),
            encoding="utf-8",
        )

        return fake, fixture_path

    def run_capture(
        self,
        fake: Path,
        fixture: Path,
    ) -> tuple[int, str, str]:
        env = os.environ.copy()
        env["MIMIR_FAKE_OPENCLAW_FIXTURE"] = str(fixture)

        run = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--node-bin",
                sys.executable,
                "--openclaw-entry",
                str(fake),
                "--page-limit",
                "2",
                "--max-pages",
                "5",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=env,
        )

        return run.returncode, run.stdout, run.stderr

    def test_filters_and_fail_closed_policy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            telegram_id = (
                "11111111-1111-4111-8111-111111111111"
            )
            foreign_id = (
                "22222222-2222-4222-8222-222222222222"
            )
            missing_id = (
                "33333333-3333-4333-8333-333333333333"
            )
            secret_id = (
                "44444444-4444-4444-8444-444444444444"
            )
            cron_id = (
                "55555555-5555-4555-8555-555555555555"
            )
            running_id = (
                "66666666-6666-4666-8666-666666666666"
            )

            synthetic_secret = "tok" + "en=" + "A" * 32

            fixture = {
                "sessions": {
                    "path": "/state/openclaw-agent.sqlite",
                    "sessions": [
                        {
                            "key":
                                "agent:main:telegram:direct:1",
                            "sessionId": telegram_id,
                            "status": "done",
                        },
                        {
                            "key": "agent:main:hud:foreign",
                            "sessionId": foreign_id,
                            "status": "done",
                        },
                        {
                            "key": "agent:main:hud:missing",
                            "sessionId": missing_id,
                            "status": "done",
                        },
                        {
                            "key": "agent:main:main",
                            "sessionId": secret_id,
                            "status": "done",
                        },
                        {
                            "key": "agent:main:cron:job",
                            "sessionId": cron_id,
                            "status": "done",
                        },
                        {
                            "key": "agent:main:hud:running",
                            "sessionId": running_id,
                            "status": "running",
                        },
                    ],
                },
                "history": {
                    "agent:main:telegram:direct:1": {
                        "0": {
                            "sessionKey":
                                "agent:main:telegram:direct:1",
                            "sessionId": telegram_id,
                            "messages": [
                                {
                                    "role": "system",
                                    "content": "system prompt",
                                    "__openclaw": {
                                        "id": "s1",
                                        "seq": 1,
                                    },
                                },
                                user_message(
                                    "Pergunta segura.",
                                    seq=2,
                                    message_id="u1",
                                ),
                            ],
                            "hasMore": True,
                            "nextOffset": 2,
                            "totalMessages": 4,
                            "deltaCursor": "d1",
                        },
                        "2": {
                            "sessionKey":
                                "agent:main:telegram:direct:1",
                            "sessionId": telegram_id,
                            "messages": [
                                assistant_message(
                                    "Resposta segura.",
                                    seq=3,
                                    message_id="a1",
                                ),
                                {
                                    "role": "toolResult",
                                    "content":
                                        "resultado interno",
                                    "__openclaw": {
                                        "id": "t1",
                                        "seq": 4,
                                    },
                                },
                            ],
                            "hasMore": False,
                            "totalMessages": 4,
                            "deltaCursor": "d2",
                        },
                    },
                    "agent:main:hud:foreign": {
                        "0": {
                            "sessionKey":
                                "agent:main:hud:foreign",
                            "sessionId": foreign_id,
                            "messages": [
                                user_message(
                                    "Mensagem estrangeira.",
                                    owner=False,
                                ),
                                assistant_message("Resposta"),
                            ],
                            "hasMore": False,
                            "totalMessages": 2,
                        }
                    },
                    "agent:main:hud:missing": {
                        "0": {
                            "sessionKey":
                                "agent:main:hud:missing",
                            "sessionId": missing_id,
                            "messages": [
                                user_message(
                                    "Owner ausente.",
                                    owner=None,
                                ),
                                assistant_message("Resposta"),
                            ],
                            "hasMore": False,
                            "totalMessages": 2,
                        }
                    },
                    "agent:main:main": {
                        "0": {
                            "sessionKey": "agent:main:main",
                            "sessionId": secret_id,
                            "messages": [
                                user_message(
                                    synthetic_secret
                                ),
                                assistant_message(
                                    "Registro recebido."
                                ),
                            ],
                            "hasMore": False,
                            "totalMessages": 2,
                        }
                    },
                },
            }

            fake, fixture_path = self.prepare_fake(
                root,
                fixture,
            )
            code, stdout, stderr = self.run_capture(
                fake,
                fixture_path,
            )

            self.assertEqual(code, 0, stderr)

            result = json.loads(stdout)
            self.assertEqual(result["collector_version"], 2)
            self.assertFalse(result["database_write"])
            self.assertFalse(result["staging_write"])
            self.assertFalse(result["content_exposed"])
            self.assertFalse(result["direct_sqlite_access"])
            self.assertEqual(result["ready"], 1)
            self.assertEqual(result["blocked"], 3)
            self.assertEqual(result["skipped"], 2)
            self.assertEqual(result["errors"], 0)

            sessions = {
                item["session_key"]: item
                for item in result["sessions"]
            }

            ready = sessions[
                "agent:main:telegram:direct:1"
            ]
            self.assertEqual(
                ready["capture_status"],
                "ready",
            )
            self.assertEqual(ready["pages"], 2)
            self.assertEqual(
                ready["excluded_system_messages"],
                1,
            )
            self.assertEqual(
                ready["excluded_tool_results"],
                1,
            )
            self.assertEqual(
                ready["excluded_thinking_blocks"],
                1,
            )
            self.assertEqual(
                ready["excluded_tool_calls"],
                1,
            )
            self.assertEqual(ready["owner_true"], 1)

            self.assertEqual(
                sessions[
                    "agent:main:hud:foreign"
                ]["capture_status"],
                "blocked",
            )
            self.assertIn(
                "nao proprietario",
                sessions[
                    "agent:main:hud:foreign"
                ]["reason"],
            )

            self.assertEqual(
                sessions[
                    "agent:main:hud:missing"
                ]["capture_status"],
                "blocked",
            )
            self.assertIn(
                "owner ausente",
                sessions[
                    "agent:main:hud:missing"
                ]["reason"],
            )

            self.assertEqual(
                sessions[
                    "agent:main:main"
                ]["reason"],
                "possivel segredo ou credencial",
            )

            self.assertEqual(
                sessions[
                    "agent:main:cron:job"
                ]["capture_status"],
                "skipped",
            )
            self.assertEqual(
                sessions[
                    "agent:main:hud:running"
                ]["capture_status"],
                "skipped",
            )

            for forbidden in (
                "Pergunta segura.",
                "Resposta segura.",
                "resultado interno",
                "internal thought",
                synthetic_secret,
            ):
                self.assertNotIn(forbidden, stdout)

    def test_blocks_truncated_history(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            key = "agent:main:hud:truncated"
            session_id = (
                "77777777-7777-4777-8777-777777777777"
            )

            fixture = {
                "sessions": {
                    "path": "/state/openclaw-agent.sqlite",
                    "sessions": [
                        {
                            "key": key,
                            "sessionId": session_id,
                            "status": "done",
                        }
                    ],
                },
                "history": {
                    key: {
                        "0": {
                            "sessionKey": key,
                            "sessionId": session_id,
                            "messages": [
                                user_message(
                                    "Texto …(truncated)…"
                                ),
                                assistant_message("Resposta"),
                            ],
                            "hasMore": False,
                            "totalMessages": 2,
                        }
                    }
                },
            }

            fake, fixture_path = self.prepare_fake(
                root,
                fixture,
            )
            code, stdout, stderr = self.run_capture(
                fake,
                fixture_path,
            )

            self.assertEqual(code, 0, stderr)
            result = json.loads(stdout)
            self.assertEqual(result["ready"], 0)
            self.assertEqual(result["blocked"], 1)
            self.assertEqual(
                result["sessions"][0]["reason"],
                "historico contem sinal de truncamento/omissao",
            )


if __name__ == "__main__":
    unittest.main()
