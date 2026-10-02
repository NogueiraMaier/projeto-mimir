#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import io
import json
import socket
import sys
import unittest
import urllib.error
from pathlib import Path


SCRIPT = (
    Path(__file__).resolve().parent
    / "mimir-gbnf-runtime-compatibility.py"
)

SPEC = importlib.util.spec_from_file_location(
    "mimir_gbnf_runtime_compatibility",
    SCRIPT,
)

if SPEC is None or SPEC.loader is None:
    raise RuntimeError("falha ao carregar harness GBNF")

MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def case(case_id: str):
    return next(item for item in MODULE.CASES if item.case_id == case_id)


def openai_response(content: str, *, finish_reason: str = "stop") -> bytes:
    return json.dumps(
        {
            "choices": [
                {
                    "finish_reason": finish_reason,
                    "message": {
                        "role": "assistant",
                        "content": content,
                    },
                }
            ]
        },
        separators=(",", ":"),
    ).encode("utf-8")


class GbnfRuntimeCompatibilityTests(unittest.TestCase):
    def test_case_matrix_is_unique_ordered_and_rooted(self) -> None:
        MODULE.validate_cases()

        ids = [item.case_id for item in MODULE.CASES]
        self.assertEqual(
            ids,
            ["G00", "G01", "G02", "G03", "G04", "G05", "G06", "G07"],
        )

        for item in MODULE.CASES:
            self.assertTrue(item.grammar.startswith("root ::="))
            self.assertTrue(item.grammar.endswith("\n"))

    def test_request_uses_explicit_grammar_only(self) -> None:
        item = case("G00")
        request = MODULE.build_request(item, MODULE.MODEL_ID)

        self.assertEqual(request["grammar"], item.grammar)
        self.assertNotIn("response_format", request)
        self.assertNotIn("json_schema", request)
        self.assertEqual(
            request["chat_template_kwargs"],
            {"enable_thinking": False},
        )
        self.assertFalse(request["stream"])
        self.assertEqual(request["temperature"], 0.0)

        serialized = MODULE.serialize_request(request)
        decoded = json.loads(serialized)
        self.assertEqual(decoded["grammar"], item.grammar)
        self.assertNotIn("response_format", decoded)
        self.assertNotIn("json_schema", decoded)

    def test_endpoint_allowlist_is_exact(self) -> None:
        self.assertEqual(
            MODULE.validate_endpoint(MODULE.MODEL_ENDPOINT),
            MODULE.MODEL_ENDPOINT,
        )

        for invalid in (
            "http://localhost:18782/v1/chat/completions",
            "http://127.0.0.1:18781/v1/chat/completions",
            "https://127.0.0.1:18782/v1/chat/completions",
            "http://10.51.1.2:18782/v1/chat/completions",
        ):
            with self.assertRaisesRegex(
                MODULE.HarnessError,
                "endpoint fora da allowlist",
            ):
                MODULE.validate_endpoint(invalid)

    def test_model_allowlist_is_exact(self) -> None:
        self.assertEqual(
            MODULE.validate_model(MODULE.MODEL_ID),
            MODULE.MODEL_ID,
        )

        with self.assertRaisesRegex(
            MODULE.HarnessError,
            "model id fora da allowlist",
        ):
            MODULE.validate_model("/tmp/other.gguf")

    def test_http_grammar_parse_error_is_classified_without_body(self) -> None:
        item = case("G00")
        request_bytes = b'{"synthetic":"request"}'
        raw_body = (
            b'Failed to initialize samplers: '
            b'failed to parse grammar SECRET_BODY'
        )

        exc = urllib.error.HTTPError(
            MODULE.MODEL_ENDPOINT,
            400,
            "bad request",
            {},
            io.BytesIO(raw_body),
        )

        result = MODULE.classify_http_error(
            item,
            request_bytes,
            exc,
        )

        self.assertEqual(result.status, MODULE.HTTP_REJECT)
        self.assertEqual(result.http_status, 400)
        self.assertEqual(
            result.error_marker,
            "GRAMMAR_PARSE_REJECT",
        )
        self.assertEqual(
            result.response_sha256,
            MODULE.sha256_bytes(raw_body),
        )
        self.assertEqual(
            result.response_bytes,
            len(raw_body),
        )

        rendered = json.dumps(
            MODULE.result_record(result),
            sort_keys=True,
        )
        self.assertNotIn("SECRET_BODY", rendered)
        self.assertNotIn("Failed to initialize", rendered)

    def test_http_other_error_is_classified_without_body(self) -> None:
        item = case("G00")
        raw_body = b"SYNTHETIC_PRIVATE_HTTP_BODY"

        exc = urllib.error.HTTPError(
            MODULE.MODEL_ENDPOINT,
            503,
            "unavailable",
            {},
            io.BytesIO(raw_body),
        )

        result = MODULE.classify_http_error(
            item,
            b"request",
            exc,
        )

        self.assertEqual(result.status, MODULE.HTTP_REJECT)
        self.assertEqual(result.error_marker, "HTTP_ERROR_OTHER")

        rendered = json.dumps(MODULE.result_record(result))
        self.assertNotIn(
            "SYNTHETIC_PRIVATE_HTTP_BODY",
            rendered,
        )

    def test_url_timeout_is_classified_fail_closed(self) -> None:
        item = case("G00")
        exc = urllib.error.URLError(
            TimeoutError("synthetic timeout secret")
        )

        result = MODULE.classify_url_error(
            item,
            b"request",
            exc,
        )

        self.assertEqual(result.status, MODULE.TIMEOUT)
        self.assertEqual(result.error_marker, "URL_TIMEOUT")

        rendered = json.dumps(MODULE.result_record(result))
        self.assertNotIn("synthetic timeout secret", rendered)

    def test_url_error_is_classified_fail_closed(self) -> None:
        item = case("G00")
        exc = urllib.error.URLError(
            OSError("synthetic transport secret")
        )

        result = MODULE.classify_url_error(
            item,
            b"request",
            exc,
        )

        self.assertEqual(
            result.status,
            MODULE.TRANSPORT_ERROR,
        )
        self.assertEqual(result.error_marker, "URL_ERROR")

        rendered = json.dumps(MODULE.result_record(result))
        self.assertNotIn("synthetic transport secret", rendered)

    def test_invalid_json_response_is_structure_reject_input(self) -> None:
        with self.assertRaisesRegex(
            MODULE.HarnessError,
            "openai_response_invalid",
        ):
            MODULE.extract_message_content(b"not-json")

    def test_non_stop_finish_reason_is_rejected(self) -> None:
        with self.assertRaisesRegex(
            MODULE.HarnessError,
            "finish_reason_not_stop",
        ):
            MODULE.extract_message_content(
                openai_response(
                    "OK",
                    finish_reason="length",
                )
            )

    def test_tool_calls_are_rejected(self) -> None:
        payload = {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {
                        "content": "OK",
                        "tool_calls": [{"id": "synthetic"}],
                    },
                }
            ]
        }

        with self.assertRaisesRegex(
            MODULE.HarnessError,
            "tool_calls_present",
        ):
            MODULE.extract_message_content(
                json.dumps(payload).encode("utf-8")
            )

    def test_case_validators_are_independent_from_model(self) -> None:
        valid = {
            "G00": "OK",
            "G01": "YES",
            "G02": "OK",
            "G03": "abc",
            "G04": "abcdefgh",
            "G05": '{"ok":true}',
            "G06": '{"value":"alpha"}',
            "G07": '{"items":["a","bc","def"]}',
        }

        invalid = {
            "G00": "NO",
            "G01": "MAYBE",
            "G02": "ok",
            "G03": "ABC",
            "G04": "abcdefghi",
            "G05": '{"ok":false}',
            "G06": '{"value":"ALPHA"}',
            "G07": '{"items":[]}',
        }

        for case_id, value in valid.items():
            self.assertTrue(
                case(case_id).validator(value),
                case_id,
            )

        for case_id, value in invalid.items():
            self.assertFalse(
                case(case_id).validator(value),
                case_id,
            )

    def test_result_record_contains_no_raw_content_fields(self) -> None:
        result = MODULE.CaseResult(
            case_id="G00",
            status=MODULE.PASS,
            grammar_sha256="a" * 64,
            grammar_bytes=13,
            request_sha256="b" * 64,
            http_status=200,
            response_sha256="c" * 64,
            response_bytes=100,
            content_sha256="d" * 64,
            content_chars=2,
            finish_reason="stop",
            structure_marker="OPENAI_CHAT_CONTENT",
        )

        record = MODULE.result_record(result)

        self.assertNotIn("content", record)
        self.assertNotIn("grammar", record)
        self.assertNotIn("request_body", record)
        self.assertNotIn("response_body", record)

    def test_runtime_summary_distinguishes_harness_from_compatibility(self) -> None:
        def result(case_id: str, status: str):
            return MODULE.CaseResult(
                case_id=case_id,
                status=status,
                grammar_sha256="a" * 64,
                grammar_bytes=1,
                request_sha256="b" * 64,
            )

        all_pass = [
            result("G00", MODULE.PASS),
            result("G01", MODULE.PASS),
        ]
        partial = [
            result("G00", MODULE.PASS),
            result("G01", MODULE.HTTP_REJECT),
            result("G02", MODULE.PASS),
        ]
        baseline_fail = [
            result("G00", MODULE.HTTP_REJECT),
            result("G01", MODULE.PASS),
        ]

        self.assertEqual(
            MODULE.contiguous_pass_through(all_pass),
            "G01",
        )
        self.assertEqual(
            MODULE.runtime_compatibility(all_pass),
            "ALL_CASES_PASS",
        )

        self.assertEqual(
            MODULE.contiguous_pass_through(partial),
            "G00",
        )
        self.assertEqual(
            MODULE.runtime_compatibility(partial),
            "PARTIAL_OR_BLOCKED",
        )

        self.assertEqual(
            MODULE.contiguous_pass_through(baseline_fail),
            "NONE",
        )
        self.assertEqual(
            MODULE.runtime_compatibility(baseline_fail),
            "BASELINE_NOT_PROVEN",
        )

    def test_bounded_reader_rejects_oversize_response(self) -> None:
        stream = io.BytesIO(
            b"x" * (MODULE.MAX_RESPONSE_BYTES + 1)
        )

        with self.assertRaisesRegex(
            MODULE.HarnessError,
            "resposta excede limite",
        ):
            MODULE._read_bounded(stream)


if __name__ == "__main__":
    unittest.main(verbosity=2)
