#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from mimir_ops import PolicyError, enforce, is_destructive, redact, write_report


class PolicyTests(unittest.TestCase):
    def test_read_allows_diagnostics(self):
        self.assertEqual(enforce("READ", "ip address"), "read")

    def test_read_blocks_change(self):
        with self.assertRaises(PolicyError):
            enforce("READ", "touch /tmp/x")

    def test_execute_requires_approval(self):
        with self.assertRaises(PolicyError):
            enforce("EXECUTE", "touch /tmp/x", approved=False)
        self.assertEqual(
            enforce("EXECUTE", "touch /tmp/x", approved=True),
            "change",
        )

    def test_destructive_is_always_blocked(self):
        self.assertTrue(is_destructive("/system reset-configuration"))
        with self.assertRaises(PolicyError):
            enforce(
                "EXECUTE",
                "/system reset-configuration",
                approved=True,
            )

    def test_redaction(self):
        self.assertNotIn("abc123", redact("token=abc123"))

    def test_report_generation(self):
        with tempfile.TemporaryDirectory() as td:
            payload = {
                "device": "router-01",
                "objective": "teste",
                "mode": "READ",
                "status": "succeeded",
                "started_at": "2026-09-22T00:00:00Z",
                "completed_at": "2026-09-22T00:01:00Z",
                "actions": [
                    {
                        "command": "uptime",
                        "classification": "read",
                        "exit_code": 0,
                        "dry_run": False,
                        "stdout": "ok",
                    }
                ],
            }
            jp, mp, jh, mh = write_report(
                Path(td),
                "id-1",
                payload,
            )
            self.assertTrue(jp.exists())
            self.assertTrue(mp.exists())
            self.assertEqual(len(jh), 64)
            self.assertEqual(len(mh), 64)
            self.assertEqual(
                json.loads(jp.read_text())["device"],
                "router-01",
            )


if __name__ == "__main__":
    unittest.main()
