# MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-TREATMENT-DESIGN-01

Date: 2026-10-02

Status:

`PROPOSED`

## Risk

`RSK-P0-003 — governança LGPD`

Current state:

`OPEN / BLOCKER`

Risk acceptance:

`NOT USED`

## Source state

Source HEAD:

`f9b2ad20dd58e43cafb4550eb288b036816ac516`

The current repository inspection established:

- privacy/LGPD controls exist, but are partial and distributed;
- controller/operator concepts are present;
- privacy-governance ownership concepts are present;
- purpose and minimization concepts are present;
- legal-basis concepts are present;
- data-subject-rights concepts are present;
- retention controls are present;
- personal-data incident handling is present;
- third-party/operator governance concepts are present;
- RIPD/DPIA concepts are present;
- data-inventory concepts are present;
- approval authority concepts are present;
- review-cadence concepts are present;
- international-transfer governance was NOT PROVEN;
- no canonical formal privacy-governance document was found;
- a named/accepted competent privacy-governance authority was NOT PROVEN.

Presence of terminology is not treated as proof of formal governance.

## Historical criterion

The historical P0 baseline requires:

`governança aprovada e comprovada`

for technical treatment of RSK-P0-003.

This design follows the treatment path, not risk acceptance.

## Decision

Implement a small, repository-first privacy-governance package for Mímir v1.

The package must consolidate existing controls rather than duplicate them.

Target artifacts:

1. `docs/PRIVACY_GOVERNANCE.md`
2. `docs/DATA_INVENTORY_LGPD.md`
3. `tools/security/validate-rsk-p0-003-privacy-governance.py`

The exact validator language or filename may change only if repository
inspection proves that an equivalent reusable validator already exists.

## 1. Canonical privacy-governance document

`docs/PRIVACY_GOVERNANCE.md` will be the canonical governance document for
privacy-related technical and organizational decisions in Mímir v1.

It must not declare legal compliance.

It must define at least:

- scope;
- systems and processing boundary;
- governance objectives;
- roles;
- authority;
- approval model;
- conflicts of interest;
- escalation;
- treatment-register ownership;
- review triggers;
- review cadence;
- exception handling;
- evidence requirements;
- relationship to incident response;
- relationship to retention;
- relationship to third-party processing;
- closure/approval state.

## 2. Role and authority model

The design requires explicit roles for:

- Project / System Owner;
- Privacy Governance Owner;
- Security Owner;
- Processing Activity Owner;
- Privacy / Governance Escalation Owner;
- Independent Reviewer when compensating review is required.

Controller, operator/processor and third-party roles must be recorded per
processing activity when applicable.

A role reference alone is insufficient.

Before RSK-P0-003 can close, the competent privacy-governance approval role
must be explicitly identified and its authority recorded.

This design does not infer that any current person automatically has that
authority.

No government identifier, credential or unnecessary personal data belongs in
Git.

## 3. Encarregado / DPO decision

The governance document must contain an explicit decision state:

- `APPOINTED`;
- `NOT_APPOINTED_WITH_COMPETENT_JUSTIFICATION`;
- `PENDING_COMPETENT_REVIEW`.

The repository validator must not decide which state is legally correct.

When a communication channel is required by the approved governance decision,
the channel must be recorded without committing secrets.

## 4. Processing register

`docs/DATA_INVENTORY_LGPD.md` must contain only sanitized metadata about
processing activities.

It must never contain raw personal data, credentials, customer records,
session contents or confidential evidence.

Every processing activity in scope must have a stable activity ID and fields
for at least:

- activity name;
- activity owner;
- current lifecycle state;
- purpose;
- categories of data;
- categories of data subjects;
- source;
- systems/repositories involved;
- controller role;
- operator/processor/third party when applicable;
- legal-basis decision state;
- competent decision/evidence reference;
- minimization controls;
- access roles;
- sharing/recipients;
- retention rule;
- retention trigger;
- deletion/disposal rule;
- security controls;
- data-subject-rights route;
- incident-response route;
- third-party dependency;
- international-transfer state;
- review date/state;
- approval state.

## 5. No automatic legal-basis inference

The system, validator, LLM and automation must not select or infer a legal
basis.

Each processing activity must use one of:

- `APPROVED_BY_COMPETENT_REVIEW`;
- `PENDING_COMPETENT_REVIEW`;
- `NOT_APPLICABLE_WITH_JUSTIFICATION`.

When approved, the record must reference the competent human decision and its
evidence.

No automatic mapping from technical purpose to legal basis is allowed.

## 6. International transfer / external processing

Current inspection did not prove the international-transfer state.

Therefore every relevant activity must explicitly record one of:

- `PROVEN`;
- `NOT_PROVEN`;
- `NOT_APPLICABLE_WITH_JUSTIFICATION`.

`NOT_PROVEN` must never be silently converted to `NO`.

Where an external provider is involved, the record must additionally cover,
when applicable:

- provider;
- operator/processor role;
- data categories;
- purpose;
- minimization;
- processing/storage location status;
- subprocessor status;
- contractual/DPA review state;
- incident-notification obligation state;
- retention/deletion state;
- exit/offboarding state;
- competent approval.

## 7. Data-subject-rights process

The governance document must define a controlled process for requests
concerning data-subject rights.

At minimum:

`receive -> identify/verify -> classify -> competent review -> execute
authorized action -> preserve evidence -> close`

No fixed legal deadline will be invented by the repository documents unless it
is explicitly sourced and approved for the applicable context.

The process must preserve security boundaries and avoid disclosing data to an
unverified requester.

## 8. Retention and deletion governance

Existing `docs/OPERATIONS_RETENTION.md` remains canonical for operational
evidence.

Privacy governance must reference it rather than duplicate it.

For personal-data processing, each activity must state:

- retention trigger;
- duration or decision state;
- exceptions;
- deletion/disposal behavior;
- backup interaction;
- legal/contractual hold state where applicable;
- competent approval.

No automatic purge is introduced by this treatment.

## 9. Personal-data incident escalation

Existing:

- `docs/INCIDENT_RESPONSE.md`;
- `docs/cybersecurity/INCIDENT_REPORT_MODEL.md`

remain canonical for incident handling.

Privacy governance must link to those documents.

Technical recovery must not automatically close the privacy/governance track.

Communication to data subjects, ANPD or other authorities remains a competent
human decision outside autonomous Mímir behavior.

## 10. Third-party governance

For a third party involved in processing, the governance package must require
a recorded review before approval.

The review must distinguish:

- proven facts;
- pending facts;
- assumptions;
- not-applicable fields.

Absence of evidence must be represented as `NOT_PROVEN`, not as approval.

## 11. Repository validator

The future repository validator must be static/repository-only.

It must verify structure and governance completeness without producing legal
conclusions.

It must check at least:

- canonical document exists;
- processing register exists;
- required sections exist;
- each processing activity has required fields;
- unknown states are explicit;
- legal basis is not auto-inferred;
- international-transfer state is explicit;
- incident-response references are present;
- retention reference is present;
- authority/reviewer model is present;
- no `LGPD_COMPLIANT` or equivalent automatic conclusion exists;
- no raw personal-data fixtures are required;
- no secrets are required;
- no network access;
- no PostgreSQL access;
- no production access.

## 12. Human approval

Repository validation is not sufficient to close RSK-P0-003.

After implementation and repository validation, a separate explicit human
approval is required.

The approval record must establish:

- identity reference of the human approver;
- governance role;
- authority being exercised;
- exact artifacts/hashes approved;
- approval scope;
- unresolved limitations;
- whether external legal review remains required for specific decisions.

The approval is internal governance approval.

It must not be described as legal certification or general LGPD compliance.

## 13. Conflicts of interest

If the same person designs, implements and approves the governance package,
the record must identify the overlap.

Where the existing control model requires compensation, the package must
record an independent review, external competent approval or another explicit
compensating measure.

The validator cannot waive this requirement.

## 14. Treatment lifecycle

The approved implementation sequence is:

1. inspect only the current v1 processing flows needed to populate the register;
2. reuse existing controls;
3. implement `PRIVACY_GOVERNANCE.md`;
4. implement sanitized `DATA_INVENTORY_LGPD.md`;
5. implement repository-only validator;
6. validate the package without network/runtime/production access;
7. commit implementation;
8. record validation checkpoint;
9. request explicit competent human governance approval;
10. preserve approval evidence;
11. reconcile RSK-P0-003.

No step may infer legal compliance.

## 15. Failure semantics

On validation failure:

`STOP -> PRESERVE -> ROOT CAUSE -> FIX VERSIONED ARTIFACT -> REVALIDATE`

No automatic approval.

No automatic risk acceptance.

No mutation of historical P0 documents merely to make a validator pass.

## 16. Historical preservation

These remain historical evidence and must not be rewritten to erase their
then-current findings:

- `docs/cybersecurity/BASELINE_P0.md`;
- August P0 audits/reviews;
- previous security reconciliation reviews.

A later treatment checkpoint supersedes current state operationally without
altering history.

## 17. Closure rule

This design does not close RSK-P0-003.

Current state remains:

`RSK-P0-003 = OPEN / BLOCKER`

Technical closure may be proposed only after:

1. formal privacy-governance package implemented;
2. current v1 processing activities represented by sanitized records;
3. repository validator PASS;
4. unresolved fields explicitly represented;
5. competent human governance approval;
6. evidence of approval preserved;
7. final reconciliation.

Potential future technical state:

`CLOSED / TECHNICALLY_TREATED / PRIVACY_GOVERNANCE_APPROVED`

That state would mean the defined v1 governance-treatment gate was satisfied.

It would NOT mean:

- legal certification;
- general LGPD compliance;
- production validation;
- absence of privacy risk;
- waiver of obligations applicable to a specific real processing activity.

## Release boundary

RSK-P0-003 remains a release blocker.

RSK-P0-004 also remains a production-release blocker.

Therefore this design does not authorize:

- Draft removal;
- merge;
- stable tag;
- production deployment.

## NEXT_ACTION

`IMPLEMENT_RSK_P0_003_PRIVACY_GOVERNANCE_REPOSITORY_ONLY`

## Preserved design-validator incident

The first semantic validation of this design stopped with:

`FAIL:OVERCLAIM:LGPD_COMPLIANT`

Root cause:

`VALIDATOR_FALSE_POSITIVE_NEGATED_MARKER`

The token `LGPD_COMPLIANT` occurred only inside the explicit negative
repository-validator requirement:

`no LGPD_COMPLIANT or equivalent automatic conclusion exists`

The document did not assert LGPD compliance.

The failed validation was preserved and the continuation uses
context-aware overclaim checks instead of rejecting the presence of a
forbidden-state token inside an explicit prohibition.

No historical source, runtime, production system or privacy-governance
implementation was changed because of this validator incident.
