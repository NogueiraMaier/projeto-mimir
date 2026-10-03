#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


CONTRACT_VERSION = "protected-output-gbnf-runtime-v1"

TOOLS_DIR = Path(__file__).resolve().parent

BUILDER_PATH = (
    TOOLS_DIR
    / "mimir_protected_output_gbnf_v1.py"
)

COMPAT_PATH = (
    TOOLS_DIR
    / "mimir-gbnf-runtime-compatibility.py"
)

BUILDER_SHA256_EXPECTED = (
    "d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f"
)

COMPAT_SHA256_EXPECTED = (
    "edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc"
)

MODEL_ENDPOINT_EXPECTED = (
    "http://127.0.0.1:18782/v1/chat/completions"
)

MODEL_ID_EXPECTED = (
    "/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf"
)

FULL_GBNF_RUNTIME_VALIDATION_DEFAULT = "PENDING"

SYNTHETIC_EVENT_ID = (
    "11111111-1111-4111-8111-111111111111"
)

SYNTHETIC_CONTENT_SHA256 = "a" * 64

SYNTHETIC_MAX_CANDIDATES = 1

SYNTHETIC_OUTPUT: dict[str, Any] = {
    "schema_version": 1,
    "source_event_id": SYNTHETIC_EVENT_ID,
    "source_content_sha256": SYNTHETIC_CONTENT_SHA256,
    "candidates": [
        {
            "memory_type": "semantic",
            "summary": "s",
            "confidence": 0.5,
            "evidence": [
                {
                    "kind": "source_excerpt",
                    "excerpt": "x",
                }
            ],
            "trust_class": "UNTRUSTED_OBSERVATION",
            "requires_human_review": True,
        }
    ],
}

SYNTHETIC_CONTENT = json.dumps(
    SYNTHETIC_OUTPUT,
    ensure_ascii=False,
    separators=(",", ":"),
)


class RuntimeHarnessError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    return hashlib.sha256(
        path.read_bytes()
    ).hexdigest()


def _load_module(
    name: str,
    path: Path,
):
    spec = importlib.util.spec_from_file_location(
        name,
        path,
    )

    if spec is None or spec.loader is None:
        raise RuntimeHarnessError(
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


BUILDER = _load_module(
    "mimir_protected_output_gbnf_v1_runtime_dependency",
    BUILDER_PATH,
)

COMPAT = _load_module(
    "mimir_gbnf_runtime_compatibility_dependency",
    COMPAT_PATH,
)


def validate_dependency_identities() -> None:
    if (
        sha256_file(BUILDER_PATH)
        != BUILDER_SHA256_EXPECTED
    ):
        raise RuntimeHarnessError(
            "builder SHA-256 inesperado"
        )

    if (
        sha256_file(COMPAT_PATH)
        != COMPAT_SHA256_EXPECTED
    ):
        raise RuntimeHarnessError(
            "compatibility harness SHA-256 inesperado"
        )

    if (
        COMPAT.MODEL_ENDPOINT
        != MODEL_ENDPOINT_EXPECTED
    ):
        raise RuntimeHarnessError(
            "endpoint dependency drift"
        )

    if COMPAT.MODEL_ID != MODEL_ID_EXPECTED:
        raise RuntimeHarnessError(
            "model dependency drift"
        )


def validate_generated_content(
    content: str,
) -> bool:
    if not isinstance(content, str):
        return False

    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        return False

    return parsed == SYNTHETIC_OUTPUT


def build_synthetic_case():
    validate_dependency_identities()

    grammar = (
        BUILDER.build_protected_output_grammar(
            event_id=SYNTHETIC_EVENT_ID,
            content_sha256=SYNTHETIC_CONTENT_SHA256,
            max_candidates=SYNTHETIC_MAX_CANDIDATES,
        )
    )

    prompt = (
        "Return exactly this JSON object and nothing else: "
        + SYNTHETIC_CONTENT
    )

    case = COMPAT.GrammarCase(
        "P00",
        "protected-output-gbnf-v1",
        grammar,
        prompt,
        validate_generated_content,
    )

    validate_case(case)

    return case


def validate_case(case) -> None:
    if case.case_id != "P00":
        raise RuntimeHarnessError(
            "case_id inesperado"
        )

    if (
        not isinstance(case.grammar, str)
        or not case.grammar.endswith("\n")
    ):
        raise RuntimeHarnessError(
            "grammar inválida"
        )

    if (
        case.grammar.count(SYNTHETIC_EVENT_ID)
        != 1
    ):
        raise RuntimeHarnessError(
            "event-id binding inválido"
        )

    if (
        case.grammar.count(
            SYNTHETIC_CONTENT_SHA256
        )
        != 1
    ):
        raise RuntimeHarnessError(
            "content-SHA binding inválido"
        )

    for forbidden in (
        "source_session_id",
        "source_excerpt_hash",
    ):
        if forbidden in case.grammar:
            raise RuntimeHarnessError(
                f"grammar contém {forbidden}"
            )

    if (
        case.prompt
        != (
            "Return exactly this JSON object and nothing else: "
            + SYNTHETIC_CONTENT
        )
    ):
        raise RuntimeHarnessError(
            "prompt sintético inesperado"
        )


def validate_runtime_inputs(
    endpoint: str,
    model: str,
    timeout_seconds: int,
) -> tuple[str, str, int]:
    endpoint = COMPAT.validate_endpoint(
        endpoint
    )

    model = COMPAT.validate_model(
        model
    )

    if (
        isinstance(timeout_seconds, bool)
        or not isinstance(timeout_seconds, int)
        or not 1 <= timeout_seconds <= 180
    ):
        raise RuntimeHarnessError(
            "timeout fora do limite"
        )

    return endpoint, model, timeout_seconds


def build_request(
    case,
    model: str,
) -> dict[str, Any]:
    body = COMPAT.build_request(
        case,
        model,
    )

    if body.get("grammar") != case.grammar:
        raise RuntimeHarnessError(
            "grammar não vinculada ao request"
        )

    if body.get("temperature") != 0.0:
        raise RuntimeHarnessError(
            "temperature inesperada"
        )

    if body.get("stream") is not False:
        raise RuntimeHarnessError(
            "stream inesperado"
        )

    template_kwargs = body.get(
        "chat_template_kwargs"
    )

    if template_kwargs != {
        "enable_thinking": False
    }:
        raise RuntimeHarnessError(
            "enable_thinking inesperado"
        )

    return body


def serialize_request(
    body: dict[str, Any],
) -> bytes:
    return COMPAT.serialize_request(body)


def run_runtime_case(
    *,
    endpoint: str,
    model: str,
    timeout_seconds: int,
):
    validate_dependency_identities()

    endpoint, model, timeout_seconds = (
        validate_runtime_inputs(
            endpoint,
            model,
            timeout_seconds,
        )
    )

    case = build_synthetic_case()

    body = build_request(
        case,
        model,
    )

    expected_request = serialize_request(
        body
    )

    result = COMPAT.run_case(
        case,
        endpoint=endpoint,
        model=model,
        timeout_seconds=timeout_seconds,
    )

    record = COMPAT.result_record(result)

    if (
        record["request_sha256"]
        != hashlib.sha256(
            expected_request
        ).hexdigest()
    ):
        raise RuntimeHarnessError(
            "request SHA-256 drift"
        )

    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Valida em runtime a grammar completa "
            "protected-output GBNF v1 com dados sintéticos."
        )
    )

    parser.add_argument(
        "--endpoint",
        default=MODEL_ENDPOINT_EXPECTED,
    )

    parser.add_argument(
        "--model",
        default=MODEL_ID_EXPECTED,
    )

    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=COMPAT.DEFAULT_TIMEOUT_SECONDS,
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        validate_dependency_identities()

        result = run_runtime_case(
            endpoint=args.endpoint,
            model=args.model,
            timeout_seconds=args.timeout_seconds,
        )

        record = COMPAT.result_record(
            result
        )

        print(
            json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
        )

        print(
            "HARNESS_EXECUTION=PASS"
        )

        print(
            "FULL_GBNF_RUNTIME_STATUS="
            + result.status
        )

        if result.status == COMPAT.PASS:
            print(
                "FULL_GBNF_RUNTIME_VALIDATION=PASS"
            )
            return 0

        print(
            "FULL_GBNF_RUNTIME_VALIDATION=FAIL"
        )
        return 40

    except (
        RuntimeHarnessError,
        COMPAT.HarnessError,
    ) as exc:
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
