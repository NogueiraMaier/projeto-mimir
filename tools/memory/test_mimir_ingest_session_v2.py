#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CAPTURE = ROOT / "mimir-capture-sessions-v2.py"
WRITER = ROOT / "mimir-ingest-session-v2.py"

SPEC = importlib.util.spec_from_file_location(
    "mimir_ingest_session_v2",
    WRITER,
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("falha ao carregar writer v2")
writer = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = writer
SPEC.loader.exec_module(writer)


def user_message(text: str, owner: bool | None = True) -> dict:
    meta = {
        "id": "u1",
        "seq": 1,
        "recordTimestampMs": 1001,
        "senderId": "operator",
        "transport": "test",
        "transcriptPosition": 1,
    }
    if owner is not None:
        meta["senderIsOwner"] = owner

    return {
        "role": "user",
        "content": text,
        "timestamp": 1001,
        "__openclaw": meta,
    }


def assistant_message(text: str) -> dict:
    return {
        "role": "assistant",
        "content": [
            {
                "type": "thinking",
                "thinking": "pensamento sintético interno",
            },
            {
                "type": "text",
                "text": text,
            },
            {
                "type": "toolCall",
                "name": "internal_test",
                "arguments": {"x": 1},
            },
        ],
        "timestamp": 1002,
        "__openclaw": {
            "id": "a1",
            "seq": 2,
            "recordTimestampMs": 1002,
            "transcriptPosition": 2,
        },
    }


class WriterV2Tests(unittest.TestCase):
    SESSION_ID = "11111111-1111-4111-8111-111111111111"
    SESSION_KEY = "agent:main:hud:writer-test"

    def prepare_fake(
        self,
        root: Path,
        *,
        user_text: str = "Pergunta sintética segura.",
        assistant_text: str = "Resposta sintética segura.",
        owner: bool | None = True,
    ) -> tuple[Path, Path]:
        fixture = {
            "sessions": {
                "path": "/state/openclaw-agent.sqlite",
                "sessions": [
                    {
                        "key": self.SESSION_KEY,
                        "sessionId": self.SESSION_ID,
                        "status": "done",
                        "updatedAt": 1790400000000,
                    }
                ],
            },
            "history": {
                self.SESSION_KEY: {
                    "0": {
                        "sessionKey": self.SESSION_KEY,
                        "sessionId": self.SESSION_ID,
                        "messages": [
                            user_message(user_text, owner),
                            assistant_message(assistant_text),
                        ],
                        "hasMore": False,
                        "totalMessages": 2,
                        "deltaCursor": "synthetic",
                    }
                }
            },
        }

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

    def capture_metadata(
        self,
        fake: Path,
        fixture: Path,
    ) -> dict:
        env = os.environ.copy()
        env["MIMIR_FAKE_OPENCLAW_FIXTURE"] = str(fixture)

        run = subprocess.run(
            [
                sys.executable,
                str(CAPTURE),
                "--node-bin",
                sys.executable,
                "--openclaw-entry",
                str(fake),
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=env,
        )
        self.assertEqual(run.returncode, 0, run.stderr)

        result = json.loads(run.stdout)
        self.assertEqual(result["ready"], 1)
        return result["sessions"][0]

    def run_writer(
        self,
        fake: Path,
        fixture: Path,
        source_sha: str,
        content_sha: str,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["MIMIR_FAKE_OPENCLAW_FIXTURE"] = str(fixture)

        return subprocess.run(
            [
                sys.executable,
                str(WRITER),
                "--session-key",
                self.SESSION_KEY,
                "--session-id",
                self.SESSION_ID,
                "--expected-source-sha256",
                source_sha,
                "--expected-content-sha256",
                content_sha,
                "--node-bin",
                sys.executable,
                "--openclaw-entry",
                str(fake),
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=env,
        )

    def test_dry_run_is_content_free_and_bound_to_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            user_text = "Pergunta sintética segura."
            assistant_text = "Resposta sintética segura."
            fake, fixture = self.prepare_fake(
                root,
                user_text=user_text,
                assistant_text=assistant_text,
            )
            metadata = self.capture_metadata(fake, fixture)

            run = self.run_writer(
                fake,
                fixture,
                metadata["source_fingerprint_sha256"],
                metadata["content_sha256"],
            )

            self.assertEqual(run.returncode, 0, run.stderr)
            result = json.loads(run.stdout)

            self.assertEqual(result["mode"], "dry-run")
            self.assertFalse(result["database_write"])
            self.assertFalse(result["staging_write"])
            self.assertFalse(result["content_exposed"])
            self.assertFalse(result["external_api"])
            self.assertFalse(result["memory_promotion"])
            self.assertRegex(
                result["approval_sha256"],
                r"^[0-9a-f]{64}$",
            )

            for forbidden in (
                user_text,
                assistant_text,
                "pensamento sintético interno",
            ):
                self.assertNotIn(forbidden, run.stdout)
                self.assertNotIn(forbidden, run.stderr)

    def test_hash_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake, fixture = self.prepare_fake(root)
            metadata = self.capture_metadata(fake, fixture)

            run = self.run_writer(
                fake,
                fixture,
                metadata["source_fingerprint_sha256"],
                "f" * 64,
            )

            self.assertNotEqual(run.returncode, 0)
            self.assertIn(
                "content SHA-256 diverge",
                run.stderr,
            )

    def test_owner_and_secret_guards_are_reused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            fake, fixture = self.prepare_fake(
                root,
                owner=False,
            )

            env = os.environ.copy()
            env["MIMIR_FAKE_OPENCLAW_FIXTURE"] = str(fixture)

            run = subprocess.run(
                [
                    sys.executable,
                    str(WRITER),
                    "--session-key",
                    self.SESSION_KEY,
                    "--session-id",
                    self.SESSION_ID,
                    "--expected-source-sha256",
                    "a" * 64,
                    "--expected-content-sha256",
                    "b" * 64,
                    "--node-bin",
                    sys.executable,
                    "--openclaw-entry",
                    str(fake),
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                env=env,
            )

            self.assertNotEqual(run.returncode, 0)
            self.assertIn("nao proprietario", run.stderr)

            secret = "tok" + "en=" + "A" * 32
            fake, fixture = self.prepare_fake(
                root,
                user_text=secret,
            )
            env["MIMIR_FAKE_OPENCLAW_FIXTURE"] = str(fixture)

            run = subprocess.run(
                [
                    sys.executable,
                    str(WRITER),
                    "--session-key",
                    self.SESSION_KEY,
                    "--session-id",
                    self.SESSION_ID,
                    "--expected-source-sha256",
                    "a" * 64,
                    "--expected-content-sha256",
                    "b" * 64,
                    "--node-bin",
                    sys.executable,
                    "--openclaw-entry",
                    str(fake),
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                env=env,
            )

            self.assertNotEqual(run.returncode, 0)
            self.assertNotIn(secret, run.stdout)
            self.assertNotIn(secret, run.stderr)
            self.assertIn(
                "possivel segredo ou credencial",
                run.stderr,
            )

    def test_psql_payload_uses_stdin_without_plaintext(self) -> None:
        content = (
            "user:\ntexto sintético privado\n\n"
            "assistant:\nresposta sintética privada"
        )
        metadata = {
            "session_id": self.SESSION_ID,
            "session_key": self.SESSION_KEY,
            "source_fingerprint_sha256": "a" * 64,
            "content_sha256": writer.hashlib.sha256(
                content.encode("utf-8")
            ).hexdigest(),
            "message_count": 2,
            "user_messages": 1,
            "assistant_messages": 1,
            "content_bytes": len(content.encode("utf-8")),
            "source_updated_at_ms": 1790400000000,
            "excluded_system_messages": 0,
            "excluded_tool_results": 0,
            "excluded_thinking_blocks": 1,
            "excluded_tool_calls": 1,
        }

        sql = writer.build_psql_script(metadata, content)

        self.assertIn("mimir.ingest_session_v2", sql)
        self.assertNotIn(content, sql)
        self.assertNotIn("texto sintético privado", sql)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            argv_log = root / "argv.json"
            stdin_log = root / "stdin.txt"
            fake_psql = root / "fake-psql"

            fake_psql.write_text(
                "#!/usr/bin/python3\n"
                "import json, sys\n"
                f"open({str(argv_log)!r}, 'w').write("
                "json.dumps(sys.argv[1:]))\n"
                f"open({str(stdin_log)!r}, 'w').write("
                "sys.stdin.read())\n"
                f"print({self.SESSION_ID!r})\n",
                encoding="utf-8",
            )
            fake_psql.chmod(0o700)

            event_id = writer.run_psql(
                psql_bin=str(fake_psql),
                pg_host="/tmp/fake-socket-dir",
                pg_port=55433,
                pg_db="mimir_memory",
                sql=sql,
                timeout_seconds=5,
            )

            self.assertEqual(event_id, self.SESSION_ID)

            argv = argv_log.read_text(encoding="utf-8")
            stdin = stdin_log.read_text(encoding="utf-8")

            self.assertNotIn(content, argv)
            self.assertNotIn(content, stdin)
            self.assertNotIn("texto sintético privado", argv)
            self.assertNotIn("texto sintético privado", stdin)


if __name__ == "__main__":
    unittest.main(verbosity=2)
