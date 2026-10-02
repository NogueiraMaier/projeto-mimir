#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
import uuid
from typing import Final


CONTRACT_VERSION: Final = "protected-output-gbnf-v1"

MIN_CANDIDATES: Final = 1
MAX_CANDIDATES: Final = 10

ALLOWED_MEMORY_TYPES: Final = (
    "decision",
    "entity",
    "evidence",
    "episodic",
    "preference",
    "procedural",
    "semantic",
    "task",
)

HEX64_RE: Final = re.compile(r"^[0-9a-f]{64}$")

LLAMA_GBNF_RUNTIME_VALIDATION: Final = "PENDING"


class GbnfContractError(RuntimeError):
    pass


def normalize_event_id(value: uuid.UUID | str) -> str:
    if isinstance(value, uuid.UUID):
        return str(value)

    if not isinstance(value, str) or not value:
        raise GbnfContractError(
            "source_event_id deve ser UUID válido"
        )

    try:
        parsed = uuid.UUID(value)
    except (ValueError, AttributeError) as exc:
        raise GbnfContractError(
            "source_event_id deve ser UUID válido"
        ) from exc

    return str(parsed)


def validate_content_sha256(value: str) -> str:
    if (
        not isinstance(value, str)
        or HEX64_RE.fullmatch(value) is None
    ):
        raise GbnfContractError(
            "source_content_sha256 deve ser "
            "SHA-256 lowercase hexadecimal"
        )

    return value


def validate_max_candidates(value: int) -> int:
    if (
        isinstance(value, bool)
        or not isinstance(value, int)
        or not MIN_CANDIDATES <= value <= MAX_CANDIDATES
    ):
        raise GbnfContractError(
            "max_candidates deve estar entre 1 e 10"
        )

    return value


def _gbnf_literal(value: str) -> str:
    return json.dumps(
        value,
        ensure_ascii=True,
        separators=(",", ":"),
    )


def _json_string_value_literal(value: str) -> str:
    json_value = json.dumps(
        value,
        ensure_ascii=True,
        separators=(",", ":"),
    )
    return _gbnf_literal(json_value)


def _candidate_cardinality_rule(
    max_candidates: int,
) -> str:
    alternatives = [
        _gbnf_literal("[]"),
    ]

    for count in range(1, max_candidates + 1):
        parts = [
            _gbnf_literal("["),
        ]

        for index in range(count):
            if index:
                parts.append(
                    _gbnf_literal(",")
                )

            parts.append("candidate")

        parts.append(
            _gbnf_literal("]")
        )

        alternatives.append(
            " ".join(parts)
        )

    return (
        "candidates ::= "
        + " | ".join(alternatives)
    )


def build_protected_output_grammar(
    *,
    event_id: uuid.UUID | str,
    content_sha256: str,
    max_candidates: int,
) -> str:
    event = normalize_event_id(event_id)
    content_hash = validate_content_sha256(
        content_sha256
    )
    candidate_limit = validate_max_candidates(
        max_candidates
    )

    root_prefix = (
        '{"schema_version":1,'
        '"source_event_id":'
        + json.dumps(
            event,
            ensure_ascii=True,
            separators=(",", ":"),
        )
        + ',"source_content_sha256":'
        + json.dumps(
            content_hash,
            ensure_ascii=True,
            separators=(",", ":"),
        )
        + ',"candidates":'
    )

    memory_type_rule = (
        "memory-type ::= "
        + " | ".join(
            _json_string_value_literal(value)
            for value in ALLOWED_MEMORY_TYPES
        )
    )

    candidate_rule = (
        "candidate ::= "
        + _gbnf_literal(
            '{"memory_type":'
        )
        + " memory-type "
        + _gbnf_literal(
            ',"summary":'
        )
        + " json-string "
        + _gbnf_literal(
            ',"confidence":'
        )
        + " json-number "
        + _gbnf_literal(
            ',"evidence":'
        )
        + " evidence-array "
        + _gbnf_literal(
            ',"trust_class":'
            '"UNTRUSTED_OBSERVATION",'
            '"requires_human_review":true}'
        )
    )

    evidence_rule = (
        "evidence ::= "
        + _gbnf_literal(
            '{"kind":"source_excerpt",'
            '"excerpt":'
        )
        + " json-string "
        + _gbnf_literal("}")
    )

    rules = [
        (
            "root ::= "
            + _gbnf_literal(root_prefix)
            + " candidates "
            + _gbnf_literal("}")
        ),
        _candidate_cardinality_rule(
            candidate_limit
        ),
        candidate_rule,
        memory_type_rule,
        (
            "evidence-array ::= "
            + _gbnf_literal("[")
            + " evidence-list "
            + _gbnf_literal("]")
        ),
        (
            "evidence-list ::= "
            "evidence | "
            "evidence "
            + _gbnf_literal(",")
            + " evidence-list"
        ),
        evidence_rule,
        r'json-string ::= "\"" json-char* "\""',
        (
            r'json-char ::= [^"\\\x00-\x1F] '
            r'| "\\" json-escape'
        ),
        (
            r'json-escape ::= ["\\/bfnrt] '
            r'| "u" hex hex hex hex'
        ),
        r'hex ::= [0-9a-fA-F]',
        (
            'json-number ::= "-"? '
            '("0" | [1-9] [0-9]*) '
            '("." [0-9]+)? '
            '([eE] [+-]? [0-9]+)?'
        ),
    ]

    grammar = "\n".join(rules) + "\n"

    if "source_session_id" in grammar:
        raise GbnfContractError(
            "grammar contém source_session_id inesperado"
        )

    if "source_excerpt_hash" in grammar:
        raise GbnfContractError(
            "grammar contém source_excerpt_hash inesperado"
        )

    return grammar


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Gera a GBNF v1 do contrato bruto de saída do "
            "protected consolidator. Não executa modelo."
        )
    )

    parser.add_argument(
        "--event-id",
        required=True,
    )

    parser.add_argument(
        "--content-sha256",
        required=True,
    )

    parser.add_argument(
        "--max-candidates",
        type=int,
        default=5,
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        grammar = build_protected_output_grammar(
            event_id=args.event_id,
            content_sha256=args.content_sha256,
            max_candidates=args.max_candidates,
        )
    except GbnfContractError as exc:
        print(
            f"ERRO[CONTRACT_REJECT]: {exc}",
            file=sys.stderr,
        )
        return 2

    sys.stdout.write(grammar)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
