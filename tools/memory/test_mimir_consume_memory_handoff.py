#!/usr/bin/env python3

from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


SCRIPT = (
    Path(__file__).resolve().parent
    / "mimir-consume-memory-handoff.py"
)

SPEC = importlib.util.spec_from_file_location(
    "mimir_consume_memory_handoff",
    SCRIPT,
)

MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


INTERVENTION_ID = (
    "98888888-8888-4888-8888-888888888881"
)
DEVICE_ID = (
    "98888888-8888-4888-8888-888888888882"
)


def make_report():
    validation = {
        "performed": True,
        "passed": True,
        "scope": "diagnostic_commands_exit_zero",
    }

    completed_at = "2026-09-29T10:00:00+00:00"

    handoff = {
        "schema_version": 1,
        "integration": "PARCIAL",
        "state": "pending_human_review",
        "source_ref": f"ops:{INTERVENTION_ID}",
        "client_id": None,
        "site_id": None,
        "device_id": DEVICE_ID,
        "project": "projeto-mimir",
        "classification": "confidential",
        "record_type": "evidence",
        "occurred_at": completed_at,
        "confidence":
            "collected_not_independently_reviewed",
        "found_state": [
            {
                "stage": "READ",
                "operation": "hostname",
                "ok": True,
                "stdout": "mimir-lab",
            }
        ],
        "changes": [],
        "validation": validation,
        "inventory_updated": True,
        "deduplication_key": INTERVENTION_ID,
        "requires": [
            "review",
            "deduplication",
            "contradiction_check",
            "version_preservation",
        ],
        "automatic_promotion": False,
    }

    return {
        "schema_version": 1,
        "intervention_id": INTERVENTION_ID,
        "status": "collected",
        "closure_ready": True,
        "closed": False,
        "inventory_updated": True,
        "completed_at": completed_at,
        "device": {
            "device_id": DEVICE_ID,
        },
        "validation": validation,
        "memory_handoff": handoff,
    }


class ConsumerValidationTests(unittest.TestCase):
    def write_report(self, report):
        directory = tempfile.TemporaryDirectory()
        path = Path(directory.name) / "report.json"

        raw = (
            json.dumps(
                report,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode()

        path.write_bytes(raw)
        os.chmod(path, 0o600)

        digest = hashlib.sha256(raw).hexdigest()

        return directory, path, digest

    def test_valid_report(self):
        temp, path, digest = self.write_report(
            make_report()
        )
        try:
            result = MODULE.load_and_validate(
                path,
                digest,
            )
        finally:
            temp.cleanup()

        self.assertEqual(
            result["intervention_id"],
            INTERVENTION_ID,
        )
        self.assertEqual(
            result["device_id"],
            DEVICE_ID,
        )
        self.assertFalse(
            result["handoff"][
                "automatic_promotion"
            ]
        )

    def test_hash_mismatch_fails(self):
        temp, path, _ = self.write_report(
            make_report()
        )
        try:
            with self.assertRaises(SystemExit):
                MODULE.load_and_validate(
                    path,
                    "0" * 64,
                )
        finally:
            temp.cleanup()

    def test_not_closure_ready_fails(self):
        report = make_report()
        report["closure_ready"] = False

        temp, path, digest = self.write_report(
            report
        )
        try:
            with self.assertRaises(SystemExit):
                MODULE.load_and_validate(
                    path,
                    digest,
                )
        finally:
            temp.cleanup()

    def test_automatic_promotion_fails(self):
        report = make_report()
        report["memory_handoff"][
            "automatic_promotion"
        ] = True

        temp, path, digest = self.write_report(
            report
        )
        try:
            with self.assertRaises(SystemExit):
                MODULE.load_and_validate(
                    path,
                    digest,
                )
        finally:
            temp.cleanup()

    def test_submit_sql_uses_sequential_plpgsql_visibility(self):
        source = SCRIPT.read_text(encoding="utf-8")

        self.assertIn(
            "CREATE TEMP TABLE handoff_submission_input",
            source,
        )
        self.assertIn(
            "INSERT INTO handoff_submission_input",
            source,
        )
        self.assertIn(
            "CREATE TEMP TABLE handoff_submission_result",
            source,
        )
        self.assertIn(
            "DO $handoff$",
            source,
        )
        self.assertIn(
            "v_memory_id :=\n        mimir.propose_memory(",
            source,
        )
        self.assertNotIn(
            "FROM mimir.memory_records",
            source,
        )
        self.assertIn(
            "mimir.inspect_candidate_conflict(",
            source,
        )
        self.assertIn(
            "v_status := 'candidate';",
            source,
        )

        self.assertNotIn(
            "FROM mimir.pending_memory_review AS pending",
            source,
        )

        do_body = source.split(
            "DO $handoff$",
            1,
        )[1].split(
            "$handoff$;",
            1,
        )[0]

        self.assertNotIn(
            ":'",
            do_body,
            "variavel psql nao pode aparecer dentro de DO $handoff$",
        )


    def test_confidential_handoff_stays_off_process_argv(self):
        report = make_report()
        handoff_text = MODULE.canonical_json(
            report["memory_handoff"]
        )
        handoff_sha256 = MODULE.sha256_bytes(
            handoff_text.encode("utf-8")
        )
        encoded_handoff = base64.b64encode(
            handoff_text.encode("utf-8")
        ).decode("ascii")

        validated = {
            "intervention_id": INTERVENTION_ID,
            "device_id": DEVICE_ID,
            "status": "collected",
            "completed_at": report["completed_at"],
            "handoff_text": handoff_text,
            "handoff_sha256": handoff_sha256,
            "report_sha256": "a" * 64,
            "source_ref": f"ops:{INTERVENTION_ID}",
            "deduplication_key": INTERVENTION_ID,
        }

        pg_result = {
            "event_id": INTERVENTION_ID,
            "memory_id":
                "98888888-8888-4888-8888-888888888883",
            "state": "candidate",
            "conflict_classification": "none",
            "automatic_promotion": False,
        }

        completed = SimpleNamespace(
            returncode=0,
            stdout=json.dumps(pg_result),
            stderr="",
        )

        identity = SimpleNamespace(pw_name="openclaw")

        with patch.object(
            MODULE.pwd,
            "getpwuid",
            return_value=identity,
        ), patch.object(
            MODULE.subprocess,
            "run",
            return_value=completed,
        ) as mocked:
            result = MODULE.submit_handoff(validated)

        self.assertFalse(result["automatic_promotion"])

        argv = mocked.call_args.args[0]
        stdin = mocked.call_args.kwargs["input"]

        command_line = "\n".join(argv)

        self.assertNotIn(
            encoded_handoff,
            command_line,
        )
        self.assertNotIn(
            handoff_text,
            command_line,
        )
        self.assertNotIn(
            "handoff_b64=",
            command_line,
        )

        self.assertIn(
            "\\set handoff_b64 '",
            stdin,
        )
        self.assertIn(
            encoded_handoff,
            stdin,
        )
        self.assertIn(
            "decode(:'handoff_b64', 'base64')",
            stdin,
        )


    def test_unknown_handoff_field_fails(self):
        report = make_report()
        report["memory_handoff"][
            "unexpected"
        ] = "value"

        temp, path, digest = self.write_report(
            report
        )
        try:
            with self.assertRaises(SystemExit):
                MODULE.load_and_validate(
                    path,
                    digest,
                )
        finally:
            temp.cleanup()


if __name__ == "__main__":
    unittest.main()
