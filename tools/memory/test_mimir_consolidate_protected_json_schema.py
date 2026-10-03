#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import uuid
from pathlib import Path


SCRIPT = (
    Path(__file__).resolve().parent
    / "mimir-consolidate-protected-v1.py"
)

SPEC = importlib.util.spec_from_file_location(
    "mimir_consolidate_protected_v1",
    SCRIPT,
)

if SPEC is None or SPEC.loader is None:
    raise RuntimeError("falha ao carregar consolidator")

MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def main() -> int:
    event_id = uuid.UUID(
        "11111111-1111-4111-8111-111111111111"
    )

    content_sha256 = "a" * 64

    source = {
        "source_type": "openclaw-session",
        "source_ref": "synthetic://json-schema-test",
        "source_kind": "openclaw-chat-history-v2",
        "content": "synthetic protected source",
    }

    request = MODULE.build_request(
        source=source,
        content_sha256=content_sha256,
        event_id=event_id,
        max_candidates=3,
    )

    assert "response_format" not in request

    grammar = request["grammar"]

    expected_grammar = (
        MODULE.build_protected_output_grammar(
            event_id=event_id,
            content_sha256=content_sha256,
            max_candidates=3,
        )
    )

    assert grammar == expected_grammar
    assert grammar.endswith("\n")
    assert grammar.count(str(event_id)) == 1
    assert grammar.count(content_sha256) == 1

    assert "source_session_id" not in grammar
    assert "source_excerpt_hash" not in grammar

    schema = MODULE.build_response_schema(
        event_id=event_id,
        content_sha256=content_sha256,
        max_candidates=3,
    )

    assert schema["additionalProperties"] is False

    assert set(schema["required"]) == {
        "schema_version",
        "source_event_id",
        "source_content_sha256",
        "candidates",
    }

    properties = schema["properties"]

    assert properties["schema_version"]["enum"] == [1]

    assert properties["source_event_id"]["enum"] == [
        str(event_id)
    ]

    assert properties[
        "source_content_sha256"
    ]["enum"] == [content_sha256]

    candidates = properties["candidates"]

    assert candidates["maxItems"] == 3

    candidate = candidates["items"]

    assert candidate["additionalProperties"] is False

    assert set(candidate["required"]) == {
        "memory_type",
        "summary",
        "confidence",
        "evidence",
        "trust_class",
        "requires_human_review",
    }

    assert set(
        candidate["properties"]["memory_type"]["enum"]
    ) == MODULE.ALLOWED_MEMORY_TYPES

    assert (
        candidate["properties"]["summary"]["maxLength"]
        == MODULE.MAX_SUMMARY_CHARS
    )

    assert candidate[
        "properties"
    ]["trust_class"]["enum"] == [
        "UNTRUSTED_OBSERVATION"
    ]

    assert candidate[
        "properties"
    ]["requires_human_review"]["enum"] == [True]

    evidence = candidate[
        "properties"
    ]["evidence"]["items"]

    assert evidence["additionalProperties"] is False

    assert set(evidence["required"]) == {
        "kind",
        "excerpt",
    }

    assert evidence[
        "properties"
    ]["kind"]["enum"] == [
        "source_excerpt"
    ]

    assert (
        evidence["properties"]["excerpt"]["maxLength"]
        == MODULE.MAX_EVIDENCE_EXCERPT_CHARS
    )

    assert "sha256" not in evidence["properties"]

    prompt = request["messages"][0]["content"]

    assert "requested source bindings" not in prompt
    assert "source_event_id" in prompt
    assert "source_content_sha256" in prompt

    serialized = json.dumps(
        request,
        sort_keys=True,
    )

    assert '"source_bindings"' not in serialized

    print("JSON_SCHEMA_REPOSITORY_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
