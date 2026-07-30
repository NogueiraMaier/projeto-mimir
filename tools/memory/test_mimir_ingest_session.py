#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


CLIENT_PATH = Path(__file__).with_name(
    "mimir-ingest-session.py"
)

SPEC = importlib.util.spec_from_file_location(
    "mimir_ingest_session",
    CLIENT_PATH,
)

if SPEC is None or SPEC.loader is None:
    raise RuntimeError("falha ao carregar o cliente")

client = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = client
SPEC.loader.exec_module(client)


def encode_event(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        + b"\n"
    )


def nested_message(role: str, content: object) -> bytes:
    return encode_event(
        {
            "type": "message",
            "message": {
                "role": role,
                "content": content,
            },
        }
    )


class ValidationTests(unittest.TestCase):
    def test_session_id_validation(self) -> None:
        value = "00bf9ebc-02ff-4bac-a869-e81ba309df70"

        self.assertEqual(
            client.validate_session_id(value),
            value,
        )

        for invalid in (
            "",
            "../sessao",
            "00BF9EBC-02FF-4BAC-A869-E81BA309DF70",
            "00000000-0000-0000-0000-000000000000",
        ):
            with self.subTest(invalid=invalid):
                with self.assertRaises(client.ClientError):
                    client.validate_session_id(invalid)

    def test_sha256_validation(self) -> None:
        valid = "a" * 64

        self.assertEqual(
            client.validate_sha256(valid),
            valid,
        )

        for invalid in (
            "",
            "a" * 63,
            "g" * 64,
            "../" + "a" * 64,
        ):
            with self.subTest(invalid=invalid):
                with self.assertRaises(client.ClientError):
                    client.validate_sha256(invalid)

    def test_tool_content_is_excluded(self) -> None:
        raw = b"".join(
            (
                encode_event(
                    {
                        "type": "session",
                        "version": 3,
                    }
                ),
                nested_message(
                    "user",
                    "  primeira\r\nlinha  ",
                ),
                nested_message(
                    "assistant",
                    [
                        {
                            "type": "text",
                            "text": " resposta ",
                        },
                        {
                            "type": "toolCall",
                            "name": "teste",
                        },
                    ],
                ),
                nested_message(
                    "toolResult",
                    "conteúdo que não deve entrar",
                ),
                nested_message(
                    "assistant",
                    [
                        {
                            "type": "toolCall",
                            "name": "segundo-teste",
                        },
                    ],
                ),
            )
        )

        transcript = client.build_transcript(raw)

        self.assertEqual(transcript.line_count, 5)
        self.assertEqual(transcript.user_messages, 1)
        self.assertEqual(transcript.assistant_messages, 2)
        self.assertEqual(transcript.excluded_tool_results, 1)
        self.assertEqual(transcript.excluded_tool_calls, 2)
        self.assertEqual(
            transcript.content,
            (
                "user:\n"
                "primeira\n"
                "linha\n\n"
                "assistant:\n"
                "resposta\n"
            ),
        )
        self.assertNotIn(
            "conteúdo que não deve entrar",
            transcript.content,
        )

    def test_top_level_message_format(self) -> None:
        raw = b"".join(
            (
                encode_event(
                    {
                        "type": "message",
                        "role": "user",
                        "content": "pergunta",
                    }
                ),
                nested_message(
                    "assistant",
                    [
                        {
                            "type": "text",
                            "text": "resposta",
                        },
                    ],
                ),
            )
        )

        transcript = client.build_transcript(raw)

        self.assertEqual(transcript.user_messages, 1)
        self.assertEqual(transcript.assistant_messages, 1)
        self.assertEqual(
            transcript.content,
            "user:\npergunta\n\nassistant:\nresposta\n",
        )

    def test_invalid_json_is_rejected(self) -> None:
        raw = b'{"type":"message"\n'

        with self.assertRaises(client.ClientError):
            client.build_transcript(raw)

    def test_both_roles_are_required(self) -> None:
        raw = nested_message("user", "pergunta")

        with self.assertRaisesRegex(
            client.ClientError,
            "assistant",
        ):
            client.build_transcript(raw)

    def test_null_character_is_rejected(self) -> None:
        raw = b"".join(
            (
                nested_message("user", "pergunta"),
                nested_message(
                    "assistant",
                    "resposta\u0000inválida",
                ),
            )
        )

        with self.assertRaises(client.ClientError):
            client.build_transcript(raw)

    def test_content_size_limit(self) -> None:
        original_limit = client.MAX_CONTENT_BYTES

        try:
            client.MAX_CONTENT_BYTES = 8

            raw = b"".join(
                (
                    nested_message("user", "pergunta"),
                    nested_message("assistant", "resposta"),
                )
            )

            with self.assertRaises(client.ClientError):
                client.build_transcript(raw)
        finally:
            client.MAX_CONTENT_BYTES = original_limit

    def test_secure_file_read(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "source.jsonl"
            content = b'{"type":"session"}\n'

            path.write_bytes(content)
            path.chmod(0o600)

            snapshot = client.read_secure_file(
                path,
                os.getuid(),
                1024,
            )

            self.assertEqual(snapshot.content, content)
            self.assertEqual(snapshot.size, len(content))
            self.assertEqual(snapshot.mode, 0o600)

    def test_excessive_permission_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "source.jsonl"

            path.write_bytes(b'{"type":"session"}\n')
            path.chmod(0o640)

            with self.assertRaises(client.ClientError):
                client.read_secure_file(
                    path,
                    os.getuid(),
                    1024,
                )

    def test_symbolic_link_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            target = directory / "target.jsonl"
            link = directory / "source.jsonl"

            target.write_bytes(b'{"type":"session"}\n')
            target.chmod(0o600)
            link.symlink_to(target)

            with self.assertRaises(client.ClientError):
                client.read_secure_file(
                    link,
                    os.getuid(),
                    1024,
                )

    def test_index_requires_unique_done_entry(self) -> None:
        session_id = (
            "00bf9ebc-02ff-4bac-a869-e81ba309df70"
        )

        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary).resolve()
            source = directory / f"{session_id}.jsonl"

            source.write_bytes(b'{"type":"session"}\n')

            entry = {
                "status": "done",
                "endedAt": "2026-07-30T14:13:08Z",
                "sessionFile": str(source),
            }

            raw_index = json.dumps(
                {"primeira": entry}
            ).encode("utf-8")

            selected, selected_path = client.parse_index(
                raw_index,
                session_id,
                directory,
            )

            self.assertEqual(selected, entry)
            self.assertEqual(selected_path, source)

            duplicate_index = json.dumps(
                {
                    "primeira": entry,
                    "segunda": dict(entry),
                }
            ).encode("utf-8")

            with self.assertRaises(client.ClientError):
                client.parse_index(
                    duplicate_index,
                    session_id,
                    directory,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
