# MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-POSTGRESQL-E2E-LAB-01

Date: 2026-10-02

Status:

`VALIDATED`

Source HEAD:

`b25b9cf7fb3b4c9c37075793678fe1e95f80a953`

## Objective

Validate the complete protected consolidator integration path using only the
isolated PostgreSQL laboratory, synthetic session data, the versioned CLI,
the real local Qwen runtime, and the trusted output validator.

## Execution controls

- synthetic data only;
- PostgreSQL LAB only;
- production access forbidden;
- one Qwen completion request authorized;
- no automatic retry;
- no automatic memory promotion;
- run artifacts preserved.

## Validated chain

`fixture -> capture -> writer dry-run -> writer LAB -> protected read -> CLI -> Qwen -> trusted validation -> zero promotion -> synthetic cleanup`

## PostgreSQL LAB

Root:

`/var/tmp/mimir-pg14-lab`

Port:

`55433`

Observed versions:

`1,2,3,4,5,6,7,8,9,10,11,12,14,15,16`

Observed:

- LAB data-directory guard PASS;
- TCP listener OFF;
- residue precheck PASS;
- synthetic writer PASS;
- protected read PASS;
- cleanup residue `0`.

## Consolidator and Qwen

Protected consolidator CLI:

`PASS`

Real Qwen completion:

`PASS`

Completion request count:

`1`

Automatic retry:

`NO`

Candidate count:

`1`

Candidate memory type:

`evidence`

Trust class:

`UNTRUSTED_OBSERVATION`

Human review:

`true`

Trusted output contract:

`PASS`

FINDING-05 evidence binding:

`PASS`

Canonical evidence:

`source_excerpt_hash`

## Promotion safety

Automatic memory records for the synthetic source event:

`0`

Therefore the E2E did not promote model output automatically.

## Artifact identities

Harness:

`d0bd88ca46fdf8cc5e09f4d29f87ce33c9c06a217b332aaeb644400dd71c219c`

Protected consolidator:

`d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`

Execution log:

`/var/tmp/mimir-protected-consolidator-cli-pg-e2e-b25b9cf.log`

Execution-log SHA-256:

`ad4dfa7c0f544715f333011f2992777cee9fe713fad2985eed67aead9a55c515`

Execution-log size:

`1198 bytes`

Execution-log lines:

`49`

Preserved run directory:

`/var/tmp/mimir-protected-real.qZRac0`

## Finding boundary

FINDING-05 remains:

`CLOSED / REAL_MODEL_REVALIDATED`

The earlier real-model validation closed the finding. This checkpoint adds
CLI/PostgreSQL integration evidence.

## Production boundary

This is laboratory validation only.

`CLI_POSTGRESQL_QWEN_E2E_LAB_VALIDATED != PRODUCTION_VALIDATED`

Production PostgreSQL was not accessed.

Production configuration was not changed.

No deployment occurred.

PR remains Draft.

## NEXT_ACTION

`FRESH_FETCH_GUARD_THEN_PUSH_PROTECTED_CONSOLIDATOR_CLI_PG_E2E_CHECKPOINT`
