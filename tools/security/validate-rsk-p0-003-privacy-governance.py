#!/usr/bin/env python3
"""Static, repository-only validation for the RSK-P0-003 treatment package."""

from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


GOVERNANCE = Path("docs/PRIVACY_GOVERNANCE.md")
INVENTORY = Path("docs/DATA_INVENTORY_LGPD.md")
RETENTION = Path("docs/OPERATIONS_RETENTION.md")
INCIDENT = Path("docs/INCIDENT_RESPONSE.md")
INCIDENT_MODEL = Path("docs/cybersecurity/INCIDENT_REPORT_MODEL.md")

EXPECTED = {
    "PA-V1-001": "CURRENT_V1_ACTIVE",
    "PA-V1-002": "CURRENT_V1_ACTIVE",
    "PA-V1-003": "CURRENT_V1_ACTIVE",
    "PA-V1-004": "CURRENT_V1_AVAILABLE_NOT_ACTIVE",
    "PA-V1-005": "CURRENT_V1_AVAILABLE_NOT_ACTIVE",
    "PA-V1-006": "CURRENT_V1_LAB_OR_VALIDATION_ONLY",
    "PA-V1-007": "CURRENT_V1_LAB_OR_VALIDATION_ONLY",
    "PA-V1-008": "CURRENT_V1_LAB_OR_VALIDATION_ONLY",
    "PA-V1-009": "CURRENT_V1_LAB_OR_VALIDATION_ONLY",
    "PA-V1-010": "HISTORICAL_OR_LEGACY",
    "PA-V1-011": "HISTORICAL_OR_LEGACY",
    "PA-V1-012": "PLANNED_NOT_IMPLEMENTED",
}

GOVERNANCE_SECTIONS = {
    "Scope",
    "Systems and processing boundary",
    "Governance objectives",
    "Roles",
    "Authority",
    "Approval model",
    "Conflicts of interest",
    "Escalation",
    "Treatment-register ownership",
    "Data-subject rights",
    "Review triggers",
    "Review cadence",
    "Exception handling",
    "Evidence requirements",
    "Relationship to incident response",
    "Relationship to retention",
    "Relationship to third-party processing",
    "Closure / approval state",
}

REQUIRED_ROLES = {
    "Project / System Owner",
    "Privacy Governance Owner",
    "Security Owner",
    "Processing Activity Owner",
    "Privacy / Governance Escalation Owner",
    "Independent Reviewer",
}

REQUIRED_FIELDS = {
    "Activity ID",
    "Activity name",
    "Activity owner",
    "Lifecycle state",
    "Purpose",
    "Categories of data",
    "Categories of data subjects",
    "Source",
    "Systems/repositories involved",
    "Controller role",
    "Operator/processor/third party",
    "Legal-basis decision state",
    "Competent decision/evidence reference",
    "Minimization controls",
    "Access roles",
    "Sharing/recipients",
    "Retention rule",
    "Retention trigger",
    "Duration or decision state",
    "Exceptions",
    "Deletion/disposal rule",
    "Backup interaction",
    "Hold state",
    "Competent approval state",
    "Security controls",
    "Data-subject-rights route",
    "Incident-response route",
    "Third-party dependency",
    "International-transfer state",
    "Review date/state",
    "Approval state",
    "Supporting repository evidence",
}

LEGAL_STATES = {
    "APPROVED_BY_COMPETENT_REVIEW",
    "PENDING_COMPETENT_REVIEW",
    "NOT_APPLICABLE_WITH_JUSTIFICATION",
}
TRANSFER_STATES = {
    "PROVEN",
    "NOT_PROVEN",
    "NOT_APPLICABLE_WITH_JUSTIFICATION",
}
DPO_STATES = {
    "APPOINTED",
    "NOT_APPOINTED_WITH_COMPETENT_JUSTIFICATION",
    "PENDING_COMPETENT_REVIEW",
}


def headings(text: str) -> set[str]:
    return set(re.findall(r"^## (.+?)\s*$", text, re.MULTILINE))


def activities(text: str) -> dict[str, dict[str, str]]:
    matches = list(re.finditer(r"^## (PA-V1-\d{3})\s*$", text, re.MULTILINE))
    result: dict[str, dict[str, str]] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end() : end]
        fields: dict[str, str] = {}
        for field_match in re.finditer(r"^- ([^:\n]+):\s*(.+?)\s*$", body, re.MULTILINE):
            fields[field_match.group(1)] = field_match.group(2)
        result[match.group(1)] = fields
    return result


def affirmative_overclaim(text: str) -> str | None:
    patterns = {
        "affirmative LGPD marker": r"(?im)^\s*LGPD_COMPLIANT\s*[:=]\s*(?:true|yes|sim|1)\s*$",
        "affirmative compliance conclusion": r"(?im)^\s*(?:LGPD compliance|conformidade LGPD)\s*[:=]\s*(?:achieved|approved|compliant|sim|aprovada)\s*$",
        "automatic risk closure": r"(?im)^\s*(?:RSK-P0-003\s*)?[:=]?\s*(?:CLOSED|FECHADO)(?:\s*/.*)?\s*$",
    }
    for label, pattern in patterns.items():
        if re.search(pattern, text):
            return label
    return None


def imported_roots(source: str) -> set[str]:
    tree = ast.parse(source)
    roots: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            roots.add(node.module.split(".")[0])
    return roots


def validate(root: Path) -> list[str]:
    errors: list[str] = []

    def require_file(relative: Path) -> str:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing file: {relative}")
            return ""
        return path.read_text(encoding="utf-8")

    governance = require_file(GOVERNANCE)
    inventory = require_file(INVENTORY)
    require_file(RETENTION)
    require_file(INCIDENT)
    require_file(INCIDENT_MODEL)
    if not governance or not inventory:
        return errors

    missing_sections = sorted(GOVERNANCE_SECTIONS - headings(governance))
    if missing_sections:
        errors.append("missing governance sections: " + ", ".join(missing_sections))

    for role in sorted(REQUIRED_ROLES):
        if role not in governance:
            errors.append(f"missing governance role: {role}")

    dpo = re.search(r"(?m)^DPO_STATE:\s*`?([A-Z_]+)`?\s*$", governance)
    if not dpo or dpo.group(1) not in DPO_STATES:
        errors.append("invalid or missing DPO_STATE")
    elif dpo.group(1) != "PENDING_COMPETENT_REVIEW":
        errors.append("DPO_STATE must remain PENDING_COMPETENT_REVIEW for this package")

    required_governance_markers = {
        "COMPETENT_PRIVACY_AUTHORITY_STATE: `PENDING_COMPETENT_REVIEW`",
        "PACKAGE_APPROVAL_STATE: `PENDING_COMPETENT_REVIEW`",
        "RSK-P0-003 = OPEN / BLOCKER",
        "RISK_ACCEPTANCE: `NOT_USED`",
        "docs/OPERATIONS_RETENTION.md",
        "docs/INCIDENT_RESPONSE.md",
        "docs/cybersecurity/INCIDENT_REPORT_MODEL.md",
        "receive -> identify/verify -> classify -> competent review -> execute authorized action -> preserve evidence -> close",
    }
    for marker in sorted(required_governance_markers):
        if marker not in governance:
            errors.append(f"missing governance marker: {marker}")

    parsed = activities(inventory)
    if set(parsed) != set(EXPECTED):
        missing = sorted(set(EXPECTED) - set(parsed))
        extra = sorted(set(parsed) - set(EXPECTED))
        errors.append(f"activity IDs mismatch; missing={missing}; extra={extra}")

    for activity_id, expected_lifecycle in EXPECTED.items():
        fields = parsed.get(activity_id)
        if fields is None:
            continue
        missing_fields = sorted(REQUIRED_FIELDS - set(fields))
        if missing_fields:
            errors.append(f"{activity_id} missing fields: {', '.join(missing_fields)}")
        if fields.get("Activity ID") != activity_id:
            errors.append(f"{activity_id} Activity ID field mismatch")
        if fields.get("Lifecycle state") != expected_lifecycle:
            errors.append(f"{activity_id} invalid lifecycle state")
        legal = fields.get("Legal-basis decision state")
        if legal not in LEGAL_STATES:
            errors.append(f"{activity_id} invalid legal-basis decision state")
        elif legal != "PENDING_COMPETENT_REVIEW":
            errors.append(f"{activity_id} legal basis must remain pending in this phase")
        transfer = fields.get("International-transfer state")
        if transfer not in TRANSFER_STATES:
            errors.append(f"{activity_id} invalid international-transfer state")
        if not fields.get("Supporting repository evidence"):
            errors.append(f"{activity_id} missing supporting repository evidence")

    combined = governance + "\n" + inventory
    overclaim = affirmative_overclaim(combined)
    if overclaim:
        errors.append(f"overclaim detected: {overclaim}")

    validator_path = Path(__file__)
    source = validator_path.read_text(encoding="utf-8")
    banned_imports = {"socket", "urllib", "http", "requests", "psycopg", "psycopg2", "subprocess"}
    found = sorted(imported_roots(source) & banned_imports)
    if found:
        errors.append("validator has forbidden runtime dependencies: " + ", ".join(found))

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print("PASS: RSK-P0-003 privacy-governance package is structurally valid (repository-only)")
    print("STATE: RSK-P0-003 = OPEN / BLOCKER; approval = PENDING_COMPETENT_REVIEW")
    return 0


if __name__ == "__main__":
    sys.exit(main())
