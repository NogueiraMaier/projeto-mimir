# MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-03

Date: 2026-10-02

Status:

`VALIDATED`

Source HEAD:

`535d101ce85fcd87d3081788971b21fb35d8df6c`

## Objective

Revalidate FINDING-05 through the committed protected consolidator trusted
path using the real local Qwen/llama.cpp runtime after migration of model
output transport to the protected-output GBNF v1 grammar.

## Evidence identity

`72d95e7e58adb6851a5d485f0ea97bd7a209858792fa6f9254ce7238a387fa2f`

## Code identities

Protected consolidator:

`d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`

Protected-output GBNF v1 builder:

`d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`

## Real-model execution

Authorized request count:

`1`

Retry:

`NO`

Observed markers:

- `REAL_MODEL_HTTP_PATH=PASS`
- `REQUEST_COUNT_EXECUTED=1`
- `TRUSTED_VALIDATE_OUTPUT=PASS`
- `CANDIDATE_COUNT=1`
- `EVIDENCE_COUNT=1`
- `SOURCE_EVENT_BINDING=PASS`
- `SOURCE_CONTENT_SHA256_BINDING=PASS`
- `SOURCE_EXCERPT_LITERAL_BINDING=PASS`
- `TRUSTED_EVIDENCE_CANONICALIZATION=PASS`
- `CANONICAL_EVIDENCE_KIND=source_excerpt_hash`
- `RAW_EXCERPT_IN_CANONICAL_OUTPUT=NO`
- `SOURCE_CONTENT_IN_CANONICAL_OUTPUT=NO`
- `TRUST_CLASS=UNTRUSTED_OBSERVATION`
- `REQUIRES_HUMAN_REVIEW=TRUE`
- `FINDING_05_REAL_MODEL_REVALIDATION=PASS`
- `PROTECTED_CONSOLIDATOR_REAL_MODEL_TRUSTED_PATH_VALIDATION=PASS`

## Finding resolution

FINDING-05 is now:

`CLOSED / REAL_MODEL_REVALIDATED`

The model output was not trusted merely because it matched the GBNF syntax.
The committed trusted validator accepted the output only after semantic and
evidence-binding checks, including literal excerpt membership in the protected
source. Trusted code then derived the canonical `source_excerpt_hash`.

## Boundary

GBNF remains a transport/syntax constraint.

`validate_output()` remains the semantic authority.

This result does not establish CLI + PostgreSQL end-to-end validation.

`REAL_MODEL_TRUSTED_PATH_VALIDATED != CLI_POSTGRESQL_E2E_VALIDATED`

PostgreSQL was not accessed.

Production was not changed.

## Operational evidence preservation

A later shell invocation stopped before execution because the evidence target
already existed. Read-only classification of that file established that the
single authorized real-model request had already completed successfully.

The evidence was not deleted or overwritten.

No second Qwen request was performed.

## Remote state

The feature branch had already been pushed and was synchronized with origin
at source HEAD `535d101ce85fcd87d3081788971b21fb35d8df6c` before this validation checkpoint.

PR remains Draft.

## NEXT_ACTION

`PLAN_PROTECTED_CONSOLIDATOR_CLI_POSTGRESQL_E2E_LAB`
