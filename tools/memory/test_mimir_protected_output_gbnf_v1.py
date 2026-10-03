#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent

BUILDER_PATH = (
    ROOT
    / "mimir_protected_output_gbnf_v1.py"
)

CONSOLIDATOR_PATH = (
    ROOT
    / "mimir-consolidate-protected-v1.py"
)

EVENT_ID = (
    "11111111-1111-4111-8111-111111111111"
)

CONTENT_SHA256 = "a" * 64


def load_module(name: str, path: Path):
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
    spec.loader.exec_module(module)
    return module


BUILDER = load_module(
    "mimir_protected_output_gbnf_v1",
    BUILDER_PATH,
)

CONSOLIDATOR = load_module(
    "mimir_consolidate_protected_v1_for_gbnf",
    CONSOLIDATOR_PATH,
)


def grammar(
    max_candidates: int = 3,
) -> str:
    return BUILDER.build_protected_output_grammar(
        event_id=EVENT_ID,
        content_sha256=CONTENT_SHA256,
        max_candidates=max_candidates,
    )


def rule_line(
    value: str,
    rule_name: str,
) -> str:
    prefix = f"{rule_name} ::= "

    matches = [
        line
        for line in value.splitlines()
        if line.startswith(prefix)
    ]

    if len(matches) != 1:
        raise AssertionError(
            f"regra {rule_name!r} "
            f"esperada exatamente uma vez"
        )

    return matches[0]


class ProtectedOutputGbnfV1Tests(
    unittest.TestCase
):
    def test_deterministic_generation(self) -> None:
        first = grammar()
        second = grammar()

        self.assertEqual(first, second)
        self.assertTrue(first.endswith("\n"))
        self.assertEqual(
            BUILDER.CONTRACT_VERSION,
            "protected-output-gbnf-v1",
        )

    def test_exact_event_binding(self) -> None:
        value = grammar()

        root = rule_line(
            value,
            "root",
        )

        self.assertEqual(
            root.count(EVENT_ID),
            1,
        )

        canonicalized = (
            BUILDER.build_protected_output_grammar(
                event_id=uuid.UUID(EVENT_ID),
                content_sha256=CONTENT_SHA256,
                max_candidates=3,
            )
        )

        self.assertEqual(
            value,
            canonicalized,
        )

    def test_invalid_event_id_is_rejected(
        self,
    ) -> None:
        for invalid in (
            "",
            "not-a-uuid",
            123,
            None,
        ):
            with self.subTest(
                invalid=invalid
            ):
                with self.assertRaises(
                    BUILDER.GbnfContractError
                ):
                    BUILDER.build_protected_output_grammar(
                        event_id=invalid,
                        content_sha256=CONTENT_SHA256,
                        max_candidates=3,
                    )

    def test_exact_content_sha_binding(
        self,
    ) -> None:
        root = rule_line(
            grammar(),
            "root",
        )

        self.assertEqual(
            root.count(CONTENT_SHA256),
            1,
        )

    def test_invalid_sha_is_rejected(
        self,
    ) -> None:
        invalid_values = (
            "",
            "a" * 63,
            "A" * 64,
            "g" * 64,
            123,
            None,
        )

        for invalid in invalid_values:
            with self.subTest(
                invalid=invalid
            ):
                with self.assertRaises(
                    BUILDER.GbnfContractError
                ):
                    BUILDER.build_protected_output_grammar(
                        event_id=EVENT_ID,
                        content_sha256=invalid,
                        max_candidates=3,
                    )

    def test_max_candidates_boundaries(
        self,
    ) -> None:
        one_body = rule_line(
            grammar(1),
            "candidates",
        ).split("::=", 1)[1]

        ten_body = rule_line(
            grammar(10),
            "candidates",
        ).split("::=", 1)[1]

        self.assertEqual(
            one_body.count("candidate"),
            1,
        )

        self.assertEqual(
            ten_body.count("candidate"),
            sum(range(1, 11)),
        )

    def test_invalid_max_candidates_rejected(
        self,
    ) -> None:
        for invalid in (
            0,
            11,
            -1,
            True,
            False,
            3.0,
            "3",
            None,
        ):
            with self.subTest(
                invalid=invalid
            ):
                with self.assertRaises(
                    BUILDER.GbnfContractError
                ):
                    BUILDER.build_protected_output_grammar(
                        event_id=EVENT_ID,
                        content_sha256=CONTENT_SHA256,
                        max_candidates=invalid,
                    )

    def test_candidates_preserve_zero_to_dynamic_max(
        self,
    ) -> None:
        body = rule_line(
            grammar(3),
            "candidates",
        ).split("::=", 1)[1]

        self.assertIn(
            '"[]"',
            body,
        )

        self.assertEqual(
            body.count("candidate"),
            1 + 2 + 3,
        )

        self.assertEqual(
            body.count(" | "),
            3,
        )

    def test_top_level_key_order_is_canonical(
        self,
    ) -> None:
        root = rule_line(
            grammar(),
            "root",
        )

        keys = (
            "schema_version",
            "source_event_id",
            "source_content_sha256",
            "candidates",
        )

        positions = [
            root.index(key)
            for key in keys
        ]

        self.assertEqual(
            positions,
            sorted(positions),
        )

    def test_candidate_field_order_is_canonical(
        self,
    ) -> None:
        candidate = rule_line(
            grammar(),
            "candidate",
        )

        fields = (
            "memory_type",
            "summary",
            "confidence",
            "evidence",
            "trust_class",
            "requires_human_review",
        )

        positions = [
            candidate.index(field)
            for field in fields
        ]

        self.assertEqual(
            positions,
            sorted(positions),
        )

    def test_memory_type_enum_is_exact(
        self,
    ) -> None:
        expected = (
            "decision",
            "entity",
            "evidence",
            "episodic",
            "preference",
            "procedural",
            "semantic",
            "task",
        )

        self.assertEqual(
            BUILDER.ALLOWED_MEMORY_TYPES,
            expected,
        )

        memory_rule = rule_line(
            grammar(),
            "memory-type",
        )

        for value in expected:
            self.assertIn(
                value,
                memory_rule,
            )

        self.assertEqual(
            set(expected),
            set(
                CONSOLIDATOR.ALLOWED_MEMORY_TYPES
            ),
        )

    def test_raw_evidence_contract(
        self,
    ) -> None:
        evidence = rule_line(
            grammar(),
            "evidence",
        )

        self.assertIn(
            "source_excerpt",
            evidence,
        )

        self.assertIn(
            "excerpt",
            evidence,
        )

        self.assertNotIn(
            "source_excerpt_hash",
            evidence,
        )

        self.assertNotIn(
            '\\"sha256\\"',
            evidence,
        )

    def test_trust_and_human_review_are_fixed(
        self,
    ) -> None:
        candidate = rule_line(
            grammar(),
            "candidate",
        )

        self.assertIn(
            "UNTRUSTED_OBSERVATION",
            candidate,
        )

        self.assertIn(
            "requires_human_review",
            candidate,
        )

        self.assertIn(
            "true",
            candidate,
        )

    def test_evidence_is_one_or_more_without_max(
        self,
    ) -> None:
        value = grammar()

        evidence_array = rule_line(
            value,
            "evidence-array",
        )

        evidence_list = rule_line(
            value,
            "evidence-list",
        )

        self.assertIn(
            "evidence-list",
            evidence_array,
        )

        self.assertEqual(
            evidence_list,
            (
                'evidence-list ::= '
                'evidence | evidence "," evidence-list'
            ),
        )

        self.assertNotIn(
            '"[]"',
            evidence_array,
        )

    def test_no_wrong_contract_fields(
        self,
    ) -> None:
        value = grammar()

        self.assertNotIn(
            "source_session_id",
            value,
        )

        self.assertNotIn(
            "source_excerpt_hash",
            value,
        )

    def test_json_lexical_rules_exist(
        self,
    ) -> None:
        value = grammar()

        for name in (
            "json-string",
            "json-char",
            "json-escape",
            "hex",
            "json-number",
        ):
            rule_line(
                value,
                name,
            )

        number = rule_line(
            value,
            "json-number",
        )

        self.assertIn(
            '"-"?',
            number,
        )

        self.assertIn(
            "[eE]",
            number,
        )

    def test_matches_trusted_schema_contract(
        self,
    ) -> None:
        event_id = uuid.UUID(EVENT_ID)

        schema = (
            CONSOLIDATOR.build_response_schema(
                event_id=event_id,
                content_sha256=CONTENT_SHA256,
                max_candidates=3,
            )
        )

        self.assertFalse(
            schema["additionalProperties"]
        )

        self.assertEqual(
            set(schema["required"]),
            {
                "schema_version",
                "source_event_id",
                "source_content_sha256",
                "candidates",
            },
        )

        properties = schema["properties"]

        self.assertEqual(
            properties[
                "schema_version"
            ]["enum"],
            [1],
        )

        self.assertEqual(
            properties[
                "source_event_id"
            ]["enum"],
            [EVENT_ID],
        )

        self.assertEqual(
            properties[
                "source_content_sha256"
            ]["enum"],
            [CONTENT_SHA256],
        )

        candidates = properties["candidates"]

        self.assertEqual(
            candidates["maxItems"],
            3,
        )

        self.assertNotIn(
            "minItems",
            candidates,
        )

        candidate = candidates["items"]

        self.assertFalse(
            candidate["additionalProperties"]
        )

        self.assertEqual(
            set(candidate["required"]),
            {
                "memory_type",
                "summary",
                "confidence",
                "evidence",
                "trust_class",
                "requires_human_review",
            },
        )

        evidence_array = candidate[
            "properties"
        ]["evidence"]

        self.assertEqual(
            evidence_array["minItems"],
            1,
        )

        self.assertNotIn(
            "maxItems",
            evidence_array,
        )

        evidence = evidence_array["items"]

        self.assertFalse(
            evidence["additionalProperties"]
        )

        self.assertEqual(
            set(evidence["required"]),
            {
                "kind",
                "excerpt",
            },
        )

        self.assertEqual(
            evidence[
                "properties"
            ]["kind"]["enum"],
            ["source_excerpt"],
        )

        self.assertNotIn(
            "sha256",
            evidence["properties"],
        )

    def test_runtime_validation_remains_pending(
        self,
    ) -> None:
        self.assertEqual(
            BUILDER.LLAMA_GBNF_RUNTIME_VALIDATION,
            "PENDING",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
