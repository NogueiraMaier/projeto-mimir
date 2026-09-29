#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


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
