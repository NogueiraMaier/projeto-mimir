#!/usr/bin/env python3
"""Repository-only tests for the RSK-P0-003 static validator."""

from __future__ import annotations

import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
VALIDATOR = REPO / "tools/security/validate-rsk-p0-003-privacy-governance.py"
SPEC = importlib.util.spec_from_file_location("privacy_validator", VALIDATOR)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in (
            MODULE.GOVERNANCE,
            MODULE.INVENTORY,
            MODULE.RETENTION,
            MODULE.INCIDENT,
            MODULE.INCIDENT_MODEL,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO / relative, target)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def rewrite(self, relative: Path, old: str, new: str, count: int = 1) -> None:
        path = self.root / relative
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, count), encoding="utf-8")

    def errors(self) -> list[str]:
        return MODULE.validate(self.root)

    def test_01_valid_package_passes(self) -> None:
        self.assertEqual([], self.errors())

    def test_02_missing_governance_fails(self) -> None:
        (self.root / MODULE.GOVERNANCE).unlink()
        self.assertTrue(self.errors())

    def test_03_missing_required_section_fails(self) -> None:
        self.rewrite(MODULE.GOVERNANCE, "## Authority", "## Authority removed")
        self.assertTrue(self.errors())

    def test_04_missing_activity_field_fails(self) -> None:
        self.rewrite(MODULE.INVENTORY, "- Purpose:", "- Purpose removed:")
        self.assertTrue(self.errors())

    def test_05_invalid_lifecycle_fails(self) -> None:
        self.rewrite(MODULE.INVENTORY, "- Lifecycle state: CURRENT_V1_ACTIVE", "- Lifecycle state: PRODUCTION")
        self.assertTrue(self.errors())

    def test_06_automatic_legal_basis_fails(self) -> None:
        self.rewrite(MODULE.INVENTORY, "- Legal-basis decision state: PENDING_COMPETENT_REVIEW", "- Legal-basis decision state: CONSENT")
        self.assertTrue(self.errors())

    def test_07_missing_or_invalid_transfer_state_fails(self) -> None:
        self.rewrite(MODULE.INVENTORY, "- International-transfer state: NOT_PROVEN", "- International-transfer state: NO")
        self.assertTrue(self.errors())

    def test_08_real_compliance_overclaim_fails(self) -> None:
        path = self.root / MODULE.GOVERNANCE
        path.write_text(path.read_text(encoding="utf-8") + "\nLGPD_COMPLIANT=true\n", encoding="utf-8")
        self.assertTrue(any("overclaim" in error for error in self.errors()))

    def test_09_negated_marker_passes(self) -> None:
        path = self.root / MODULE.GOVERNANCE
        path.write_text(path.read_text(encoding="utf-8") + "\nnão declarar LGPD_COMPLIANT automaticamente\n", encoding="utf-8")
        self.assertEqual([], self.errors())

    def test_10_invalid_dpo_state_fails(self) -> None:
        self.rewrite(MODULE.GOVERNANCE, "DPO_STATE: `PENDING_COMPETENT_REVIEW`", "DPO_STATE: `AUTOMATICALLY_APPROVED`")
        self.assertTrue(self.errors())


if __name__ == "__main__":
    unittest.main(verbosity=2)
