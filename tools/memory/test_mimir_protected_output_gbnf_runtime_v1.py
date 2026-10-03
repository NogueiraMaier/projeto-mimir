#!/usr/bin/env python3

from __future__ import annotations

import dataclasses
import importlib.util
import io
import json
import socket
import sys
import unittest
import urllib.error
from pathlib import Path


HERE = Path(__file__).resolve().parent

HARNESS_PATH = (
    HERE
    / "mimir_protected_output_gbnf_runtime_v1.py"
)


def load_module(
    name: str,
    path: Path,
):
    spec = importlib.util.spec_from_file_location(
        name,
        path,
    )

    if spec is None or spec.loader is None:
        raise RuntimeError(
            f"falha ao carregar {path}"
        )

    module = importlib.util.module_from_spec(
        spec
    )

    sys.modules[name] = module

    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(name, None)
        raise

    return module


HARNESS = load_module(
    "mimir_protected_output_gbnf_runtime_v1_test_target",
    HARNESS_PATH,
)

COMPAT = HARNESS.COMPAT


def valid_openai_response(
    *,
    content: str = HARNESS.SYNTHETIC_CONTENT,
    finish_reason: str = "stop",
    extra_message: dict | None = None,
) -> bytes:
    message = {
        "role": "assistant",
        "content": content,
    }

    if extra_message:
        message.update(extra_message)

    body = {
        "choices": [
            {
                "finish_reason": finish_reason,
                "message": message,
            }
        ]
    }

    return json.dumps(
        body,
        separators=(",", ":"),
    ).encode("utf-8")


class ProtectedOutputGbnfRuntimeV1Tests(
    unittest.TestCase
):
    def test_dependency_identities(
        self,
    ) -> None:
        HARNESS.validate_dependency_identities()

        self.assertEqual(
            HARNESS.sha256_file(
                HARNESS.BUILDER_PATH
            ),
            HARNESS.BUILDER_SHA256_EXPECTED,
        )

        self.assertEqual(
            HARNESS.sha256_file(
                HARNESS.COMPAT_PATH
            ),
            HARNESS.COMPAT_SHA256_EXPECTED,
        )

    def test_exact_endpoint_and_model(
        self,
    ) -> None:
        self.assertEqual(
            HARNESS.MODEL_ENDPOINT_EXPECTED,
            COMPAT.MODEL_ENDPOINT,
        )

        self.assertEqual(
            HARNESS.MODEL_ID_EXPECTED,
            COMPAT.MODEL_ID,
        )

        endpoint, model, timeout = (
            HARNESS.validate_runtime_inputs(
                HARNESS.MODEL_ENDPOINT_EXPECTED,
                HARNESS.MODEL_ID_EXPECTED,
                30,
            )
        )

        self.assertEqual(
            endpoint,
            HARNESS.MODEL_ENDPOINT_EXPECTED,
        )
        self.assertEqual(
            model,
            HARNESS.MODEL_ID_EXPECTED,
        )
        self.assertEqual(timeout, 30)

    def test_runtime_input_rejections(
        self,
    ) -> None:
        with self.assertRaises(
            COMPAT.HarnessError
        ):
            HARNESS.validate_runtime_inputs(
                "http://127.0.0.1:1/v1/chat/completions",
                HARNESS.MODEL_ID_EXPECTED,
                30,
            )

        with self.assertRaises(
            COMPAT.HarnessError
        ):
            HARNESS.validate_runtime_inputs(
                HARNESS.MODEL_ENDPOINT_EXPECTED,
                "/tmp/not-the-model.gguf",
                30,
            )

        for invalid in (
            0,
            181,
            -1,
            True,
            30.0,
        ):
            with self.subTest(
                invalid=invalid
            ):
                with self.assertRaises(
                    HARNESS.RuntimeHarnessError
                ):
                    HARNESS.validate_runtime_inputs(
                        HARNESS.MODEL_ENDPOINT_EXPECTED,
                        HARNESS.MODEL_ID_EXPECTED,
                        invalid,
                    )

    def test_synthetic_case_is_deterministic(
        self,
    ) -> None:
        first = HARNESS.build_synthetic_case()
        second = HARNESS.build_synthetic_case()

        self.assertEqual(
            first.case_id,
            "P00",
        )

        self.assertEqual(
            first.grammar,
            second.grammar,
        )

        self.assertEqual(
            first.prompt,
            second.prompt,
        )

    def test_case_uses_exact_committed_builder(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        expected = (
            HARNESS.BUILDER
            .build_protected_output_grammar(
                event_id=HARNESS.SYNTHETIC_EVENT_ID,
                content_sha256=(
                    HARNESS.SYNTHETIC_CONTENT_SHA256
                ),
                max_candidates=(
                    HARNESS.SYNTHETIC_MAX_CANDIDATES
                ),
            )
        )

        self.assertEqual(
            case.grammar,
            expected,
        )

    def test_synthetic_bindings(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        self.assertEqual(
            case.grammar.count(
                HARNESS.SYNTHETIC_EVENT_ID
            ),
            1,
        )

        self.assertEqual(
            case.grammar.count(
                HARNESS.SYNTHETIC_CONTENT_SHA256
            ),
            1,
        )

        self.assertNotIn(
            "source_session_id",
            case.grammar,
        )

        self.assertNotIn(
            "source_excerpt_hash",
            case.grammar,
        )

    def test_synthetic_content_contract(
        self,
    ) -> None:
        parsed = json.loads(
            HARNESS.SYNTHETIC_CONTENT
        )

        self.assertEqual(
            parsed,
            HARNESS.SYNTHETIC_OUTPUT,
        )

        self.assertEqual(
            parsed["source_event_id"],
            HARNESS.SYNTHETIC_EVENT_ID,
        )

        self.assertEqual(
            parsed["source_content_sha256"],
            HARNESS.SYNTHETIC_CONTENT_SHA256,
        )

        self.assertEqual(
            len(parsed["candidates"]),
            1,
        )

        evidence = (
            parsed["candidates"][0]
            ["evidence"][0]
        )

        self.assertEqual(
            evidence,
            {
                "kind": "source_excerpt",
                "excerpt": "x",
            },
        )

    def test_generated_content_validator(
        self,
    ) -> None:
        self.assertTrue(
            HARNESS.validate_generated_content(
                HARNESS.SYNTHETIC_CONTENT
            )
        )

        rejected = (
            "",
            "not-json",
            "{}",
            json.dumps(
                {
                    **HARNESS.SYNTHETIC_OUTPUT,
                    "source_event_id":
                        "22222222-2222-4222-8222-222222222222",
                },
                separators=(",", ":"),
            ),
            json.dumps(
                {
                    **HARNESS.SYNTHETIC_OUTPUT,
                    "candidates": [],
                },
                separators=(",", ":"),
            ),
        )

        for value in rejected:
            with self.subTest(value=value):
                self.assertFalse(
                    HARNESS.validate_generated_content(
                        value
                    )
                )

    def test_request_contract(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        body = HARNESS.build_request(
            case,
            HARNESS.MODEL_ID_EXPECTED,
        )

        self.assertEqual(
            body["grammar"],
            case.grammar,
        )

        self.assertEqual(
            body["temperature"],
            0.0,
        )

        self.assertIs(
            body["stream"],
            False,
        )

        self.assertEqual(
            body["chat_template_kwargs"],
            {
                "enable_thinking": False
            },
        )

        self.assertEqual(
            body["model"],
            HARNESS.MODEL_ID_EXPECTED,
        )

    def test_request_serialization_deterministic(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        body = HARNESS.build_request(
            case,
            HARNESS.MODEL_ID_EXPECTED,
        )

        first = HARNESS.serialize_request(
            body
        )

        second = HARNESS.serialize_request(
            body
        )

        self.assertEqual(first, second)

        parsed = json.loads(first)

        self.assertEqual(
            parsed["grammar"],
            case.grammar,
        )

    def test_openai_content_extraction_accepts_valid(
        self,
    ) -> None:
        content, finish_reason = (
            COMPAT.extract_message_content(
                valid_openai_response()
            )
        )

        self.assertEqual(
            content,
            HARNESS.SYNTHETIC_CONTENT,
        )

        self.assertEqual(
            finish_reason,
            "stop",
        )

    def test_openai_envelope_rejections(
        self,
    ) -> None:
        bad_payloads = (
            b"not-json",
            b"{}",
            json.dumps(
                {
                    "choices": [],
                }
            ).encode(),
            valid_openai_response(
                finish_reason="length"
            ),
            valid_openai_response(
                extra_message={
                    "tool_calls": [
                        {
                            "id": "x",
                        }
                    ]
                }
            ),
            valid_openai_response(
                extra_message={
                    "function_call": {
                        "name": "x",
                    }
                }
            ),
            valid_openai_response(
                content=""
            ),
        )

        for payload in bad_payloads:
            with self.subTest(
                payload=payload
            ):
                with self.assertRaises(
                    COMPAT.HarnessError
                ):
                    COMPAT.extract_message_content(
                        payload
                    )

    def test_http_reject_classification(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        exc = urllib.error.HTTPError(
            url=HARNESS.MODEL_ENDPOINT_EXPECTED,
            code=400,
            msg="bad request",
            hdrs=None,
            fp=io.BytesIO(
                b'{"error":"synthetic"}'
            ),
        )

        result = COMPAT.classify_http_error(
            case,
            b"{}",
            exc,
        )

        self.assertEqual(
            result.status,
            COMPAT.HTTP_REJECT,
        )

        self.assertEqual(
            result.http_status,
            400,
        )

    def test_timeout_classification(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        result = COMPAT.classify_url_error(
            case,
            b"{}",
            urllib.error.URLError(
                socket.timeout("synthetic")
            ),
        )

        self.assertEqual(
            result.status,
            COMPAT.TIMEOUT,
        )

    def test_transport_error_classification(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        result = COMPAT.classify_url_error(
            case,
            b"{}",
            urllib.error.URLError(
                OSError("synthetic")
            ),
        )

        self.assertEqual(
            result.status,
            COMPAT.TRANSPORT_ERROR,
        )

    def test_bounded_response_handling(
        self,
    ) -> None:
        okay = io.BytesIO(
            b"x" * COMPAT.MAX_RESPONSE_BYTES
        )

        self.assertEqual(
            len(
                COMPAT._read_bounded(
                    okay
                )
            ),
            COMPAT.MAX_RESPONSE_BYTES,
        )

        too_large = io.BytesIO(
            b"x"
            * (
                COMPAT.MAX_RESPONSE_BYTES
                + 1
            )
        )

        with self.assertRaises(
            COMPAT.HarnessError
        ):
            COMPAT._read_bounded(
                too_large
            )

    def test_result_record_is_sanitized(
        self,
    ) -> None:
        fields = {
            field.name
            for field in dataclasses.fields(
                COMPAT.CaseResult
            )
        }

        self.assertEqual(
            fields,
            {
                "case_id",
                "status",
                "grammar_sha256",
                "grammar_bytes",
                "request_sha256",
                "http_status",
                "response_sha256",
                "response_bytes",
                "content_sha256",
                "content_chars",
                "finish_reason",
                "structure_marker",
                "error_marker",
            },
        )

        for forbidden in (
            "content",
            "response_body",
            "prompt",
            "grammar",
        ):
            self.assertNotIn(
                forbidden,
                fields,
            )

    def test_runtime_state_is_pending(
        self,
    ) -> None:
        self.assertEqual(
            HARNESS.FULL_GBNF_RUNTIME_VALIDATION_DEFAULT,
            "PENDING",
        )

    def test_no_protected_source_payload(
        self,
    ) -> None:
        case = HARNESS.build_synthetic_case()

        self.assertIn(
            HARNESS.SYNTHETIC_EVENT_ID,
            case.prompt,
        )

        self.assertIn(
            HARNESS.SYNTHETIC_CONTENT_SHA256,
            case.prompt,
        )

        self.assertIn(
            '"excerpt":"x"',
            case.prompt,
        )

        self.assertNotIn(
            "source_session_id",
            case.prompt,
        )

        self.assertNotIn(
            "source_excerpt_hash",
            case.prompt,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
