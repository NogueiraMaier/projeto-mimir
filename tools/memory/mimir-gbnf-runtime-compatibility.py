#!/usr/bin/env python3

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import io
import json
import re
import socket
import sys
import urllib.error
import urllib.request
from collections.abc import Callable
from typing import Any

MODEL_ENDPOINT = "http://127.0.0.1:18782/v1/chat/completions"
MODEL_ID = "/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf"
MAX_RESPONSE_BYTES = 1_048_576
DEFAULT_TIMEOUT_SECONDS = 30

PASS = "PASS"
HTTP_REJECT = "HTTP_REJECT"
TIMEOUT = "TIMEOUT"
TRANSPORT_ERROR = "TRANSPORT_ERROR"
STRUCTURE_REJECT = "STRUCTURE_REJECT"
ALLOWED_STATUSES = {
    PASS,
    HTTP_REJECT,
    TIMEOUT,
    TRANSPORT_ERROR,
    STRUCTURE_REJECT,
}


class HarnessError(RuntimeError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


@dataclasses.dataclass(frozen=True)
class GrammarCase:
    case_id: str
    description: str
    grammar: str
    prompt: str
    validator: Callable[[str], bool]


@dataclasses.dataclass(frozen=True)
class CaseResult:
    case_id: str
    status: str
    grammar_sha256: str
    grammar_bytes: int
    request_sha256: str
    http_status: int | None = None
    response_sha256: str | None = None
    response_bytes: int | None = None
    content_sha256: str | None = None
    content_chars: int | None = None
    finish_reason: str | None = None
    structure_marker: str | None = None
    error_marker: str | None = None


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_text(text: str) -> str:
    return sha256_bytes(text.encode("utf-8"))


def _fullmatch(pattern: str) -> Callable[[str], bool]:
    regex = re.compile(pattern, re.ASCII)
    return lambda value: regex.fullmatch(value) is not None


def _json_value_validator(value: str) -> bool:
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return False
    return (
        isinstance(parsed, dict)
        and set(parsed) == {"value"}
        and isinstance(parsed["value"], str)
        and re.fullmatch(r"[a-z]{1,8}", parsed["value"], re.ASCII) is not None
    )


def _json_items_validator(value: str) -> bool:
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return False
    if not isinstance(parsed, dict) or set(parsed) != {"items"}:
        return False
    items = parsed["items"]
    return (
        isinstance(items, list)
        and 1 <= len(items) <= 3
        and all(
            isinstance(item, str)
            and re.fullmatch(r"[a-z]{1,8}", item, re.ASCII) is not None
            for item in items
        )
    )


CASES = (
    GrammarCase(
        "G00",
        "literal",
        'root ::= "OK"\n',
        "Return exactly OK.",
        lambda value: value == "OK",
    ),
    GrammarCase(
        "G01",
        "alternation",
        'root ::= "YES" | "NO"\n',
        "Return exactly YES.",
        lambda value: value in {"YES", "NO"},
    ),
    GrammarCase(
        "G02",
        "rule-reference",
        'root ::= value\nvalue ::= "OK"\n',
        "Return exactly OK.",
        lambda value: value == "OK",
    ),
    GrammarCase(
        "G03",
        "character-class-plus",
        'root ::= [a-z]+\n',
        "Return one lowercase ASCII word only.",
        _fullmatch(r"[a-z]+"),
    ),
    GrammarCase(
        "G04",
        "bounded-repetition",
        'root ::= [a-z]{1,8}\n',
        "Return one lowercase ASCII word of at most eight letters.",
        _fullmatch(r"[a-z]{1,8}"),
    ),
    GrammarCase(
        "G05",
        "fixed-json",
        'root ::= "{\\"ok\\":true}"\n',
        'Return exactly {"ok":true}.',
        lambda value: value == '{"ok":true}',
    ),
    GrammarCase(
        "G06",
        "json-string-rule",
        'root ::= "{\\"value\\":\\"" word "\\"}"\nword ::= [a-z]{1,8}\n',
        'Return a JSON object with only key "value" and a lowercase ASCII word.',
        _json_value_validator,
    ),
    GrammarCase(
        "G07",
        "nested-bounded-json",
        'root ::= "{\\"items\\":[" item ("," item){0,2} "]}"\n'
        'item ::= "\\"" [a-z]{1,8} "\\""\n',
        'Return a JSON object with only key "items" and one to three lowercase ASCII words.',
        _json_items_validator,
    ),
)


def validate_endpoint(raw: str) -> str:
    if raw != MODEL_ENDPOINT:
        raise HarnessError("endpoint fora da allowlist")
    return raw


def validate_model(raw: str) -> str:
    if raw != MODEL_ID:
        raise HarnessError("model id fora da allowlist")
    return raw


def validate_cases(cases: tuple[GrammarCase, ...] = CASES) -> None:
    ids = [case.case_id for case in cases]
    if len(ids) != len(set(ids)):
        raise HarnessError("case_id duplicado")
    if ids != sorted(ids):
        raise HarnessError("case_id fora de ordem")
    for case in cases:
        if not re.fullmatch(r"G\d{2}", case.case_id):
            raise HarnessError("case_id inválido")
        if not case.grammar.startswith("root ::="):
            raise HarnessError(f"{case.case_id} sem root ::=")
        if not case.grammar.endswith("\n"):
            raise HarnessError(f"{case.case_id} grammar sem LF final")
        if not case.prompt.strip():
            raise HarnessError(f"{case.case_id} prompt vazio")


def build_request(case: GrammarCase, model: str) -> dict[str, Any]:
    validate_model(model)
    return {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Follow the user request. Return only text accepted by the "
                    "provided grammar. Do not call tools and do not add commentary."
                ),
            },
            {
                "role": "user",
                "content": case.prompt,
            },
        ],
        "temperature": 0.0,
        "max_tokens": 128,
        "stream": False,
        "grammar": case.grammar,
        "chat_template_kwargs": {"enable_thinking": False},
    }


def serialize_request(body: dict[str, Any]) -> bytes:
    return json.dumps(
        body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _read_bounded(stream: Any) -> bytes:
    data = stream.read(MAX_RESPONSE_BYTES + 1)
    if len(data) > MAX_RESPONSE_BYTES:
        raise HarnessError("resposta excede limite")
    return data


def _http_error_marker(body: bytes) -> str:
    lowered = body.lower()
    if b"failed to parse grammar" in lowered:
        return "GRAMMAR_PARSE_REJECT"
    if b"failed to initialize samplers" in lowered:
        return "SAMPLER_INIT_REJECT"
    return "HTTP_ERROR_OTHER"


def _base_result(
    case: GrammarCase,
    request_bytes: bytes,
    *,
    status: str,
    **kwargs: Any,
) -> CaseResult:
    if status not in ALLOWED_STATUSES:
        raise HarnessError("status interno inválido")
    grammar_bytes = case.grammar.encode("utf-8")
    return CaseResult(
        case_id=case.case_id,
        status=status,
        grammar_sha256=sha256_bytes(grammar_bytes),
        grammar_bytes=len(grammar_bytes),
        request_sha256=sha256_bytes(request_bytes),
        **kwargs,
    )


def classify_http_error(
    case: GrammarCase,
    request_bytes: bytes,
    exc: urllib.error.HTTPError,
) -> CaseResult:
    body = b""
    if exc.fp is not None:
        try:
            body = _read_bounded(exc.fp)
        except HarnessError:
            return _base_result(
                case,
                request_bytes,
                status=HTTP_REJECT,
                http_status=exc.code,
                error_marker="HTTP_ERROR_BODY_TOO_LARGE",
            )
    return _base_result(
        case,
        request_bytes,
        status=HTTP_REJECT,
        http_status=exc.code,
        response_sha256=sha256_bytes(body),
        response_bytes=len(body),
        error_marker=_http_error_marker(body),
    )


def classify_url_error(
    case: GrammarCase,
    request_bytes: bytes,
    exc: urllib.error.URLError,
) -> CaseResult:
    if isinstance(exc.reason, (TimeoutError, socket.timeout)):
        return _base_result(
            case,
            request_bytes,
            status=TIMEOUT,
            error_marker="URL_TIMEOUT",
        )
    return _base_result(
        case,
        request_bytes,
        status=TRANSPORT_ERROR,
        error_marker="URL_ERROR",
    )


def extract_message_content(response_bytes: bytes) -> tuple[str, str]:
    try:
        response = json.loads(response_bytes)
        if not isinstance(response, dict):
            raise HarnessError("response_not_object")
        choices = response["choices"]
        if not isinstance(choices, list) or len(choices) != 1:
            raise HarnessError("choices_invalid")
        choice = choices[0]
        if not isinstance(choice, dict):
            raise HarnessError("choice_invalid")
        finish_reason = choice.get("finish_reason")
        if finish_reason != "stop":
            raise HarnessError("finish_reason_not_stop")
        message = choice["message"]
        if not isinstance(message, dict):
            raise HarnessError("message_invalid")
        if message.get("tool_calls"):
            raise HarnessError("tool_calls_present")
        if message.get("function_call"):
            raise HarnessError("function_call_present")
        content = message.get("content")
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        raise HarnessError("openai_response_invalid") from exc
    if not isinstance(content, str) or not content:
        raise HarnessError("content_invalid")
    return content, finish_reason


def run_case(
    case: GrammarCase,
    *,
    endpoint: str,
    model: str,
    timeout_seconds: int,
) -> CaseResult:
    endpoint = validate_endpoint(endpoint)
    validate_model(model)
    if not 1 <= timeout_seconds <= 180:
        raise HarnessError("timeout fora do limite")

    body = build_request(case, model)
    request_bytes = serialize_request(body)
    request = urllib.request.Request(
        endpoint,
        data=request_bytes,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "mimir-gbnf-runtime-compatibility/1",
        },
    )
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        NoRedirect(),
    )

    try:
        with opener.open(request, timeout=timeout_seconds) as response:
            http_status = response.status
            response_bytes = _read_bounded(response)
    except urllib.error.HTTPError as exc:
        return classify_http_error(case, request_bytes, exc)
    except (TimeoutError, socket.timeout):
        return _base_result(
            case,
            request_bytes,
            status=TIMEOUT,
            error_marker="DIRECT_TIMEOUT",
        )
    except urllib.error.URLError as exc:
        return classify_url_error(case, request_bytes, exc)
    except OSError:
        return _base_result(
            case,
            request_bytes,
            status=TRANSPORT_ERROR,
            error_marker="OS_ERROR",
        )

    response_hash = sha256_bytes(response_bytes)
    if http_status != 200:
        return _base_result(
            case,
            request_bytes,
            status=HTTP_REJECT,
            http_status=http_status,
            response_sha256=response_hash,
            response_bytes=len(response_bytes),
            error_marker="HTTP_STATUS_OTHER",
        )

    try:
        content, finish_reason = extract_message_content(response_bytes)
    except HarnessError as exc:
        return _base_result(
            case,
            request_bytes,
            status=STRUCTURE_REJECT,
            http_status=http_status,
            response_sha256=response_hash,
            response_bytes=len(response_bytes),
            error_marker=str(exc),
        )

    content_hash = sha256_text(content)
    common = {
        "http_status": http_status,
        "response_sha256": response_hash,
        "response_bytes": len(response_bytes),
        "content_sha256": content_hash,
        "content_chars": len(content),
        "finish_reason": finish_reason,
        "structure_marker": "OPENAI_CHAT_CONTENT",
    }

    if not case.validator(content):
        return _base_result(
            case,
            request_bytes,
            status=STRUCTURE_REJECT,
            error_marker="CONTENT_OUTSIDE_EXPECTED_CASE_SHAPE",
            **common,
        )

    return _base_result(
        case,
        request_bytes,
        status=PASS,
        **common,
    )


def result_record(result: CaseResult) -> dict[str, Any]:
    record = dataclasses.asdict(result)
    if set(record) != {
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
    }:
        raise HarnessError("record interno inesperado")
    return record


def contiguous_pass_through(results: list[CaseResult]) -> str:
    highest = "NONE"
    for result in results:
        if result.status != PASS:
            break
        highest = result.case_id
    return highest


def runtime_compatibility(results: list[CaseResult]) -> str:
    if results and all(result.status == PASS for result in results):
        return "ALL_CASES_PASS"
    if results and results[0].status == PASS:
        return "PARTIAL_OR_BLOCKED"
    return "BASELINE_NOT_PROVEN"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Harness sintético versionado para caracterizar compatibilidade "
            "GBNF do runtime Qwen local. Não usa PostgreSQL."
        )
    )
    parser.add_argument("--endpoint", default=MODEL_ENDPOINT)
    parser.add_argument("--model", default=MODEL_ID)
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_cases()
        endpoint = validate_endpoint(args.endpoint)
        model = validate_model(args.model)
        if not 1 <= args.timeout_seconds <= 180:
            raise HarnessError("timeout fora do limite")

        results: list[CaseResult] = []
        for case in CASES:
            result = run_case(
                case,
                endpoint=endpoint,
                model=model,
                timeout_seconds=args.timeout_seconds,
            )
            results.append(result)
            print(
                json.dumps(
                    result_record(result),
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                )
            )

        print("HARNESS_EXECUTION=PASS")
        print(
            "CONTIGUOUS_PASS_THROUGH="
            + contiguous_pass_through(results)
        )
        print(
            "RUNTIME_COMPATIBILITY="
            + runtime_compatibility(results)
        )
        return 0
    except HarnessError as exc:
        print(
            "HARNESS_EXECUTION=FAIL",
            file=sys.stderr,
        )
        print(
            "HARNESS_ERROR_MARKER="
            + str(exc),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
