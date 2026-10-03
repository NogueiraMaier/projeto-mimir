# MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-CLEANUP-HARDENING-REPOSITORY-VALIDATION-01

Date: 2026-10-02

Status:

`REPOSITORY_VALIDATED`

Implementation HEAD:

`f01eb9126ff4ab5c23157c293e354249f5ae618d`

## Objective

Harden the existing isolated protected-consolidator E2E LAB harness before
authorizing an execution that touches PostgreSQL LAB and the real local Qwen
runtime.

## Scope

Changed file:

`tools/memory/validate-protected-consolidator-real-model-lab.sh`

No protected-consolidator code changed.

No new E2E harness was created.

## Change

Removed:

`rm -rf -- "$RUN"`

Added preservation markers:

`preserved_run_dir=$RUN`

`preserved_run_artifacts=YES`

The run directory is intentionally retained as restricted evidence instead of
being recursively deleted.

## Database cleanup

The change does not remove or weaken targeted cleanup of synthetic LAB data.

The harness still deletes only its synthetic rows from:

- `mimir.memory_records`;
- `mimir.session_sources`;
- `mimir.memory_events`.

The synthetic residue check remains.

## LAB boundary

The versioned harness continues to bind the test to:

`/var/tmp/mimir-pg14-lab`

PostgreSQL port:

`55433`

Existing guards for LAB data directory and no TCP listener remain.

## Repository-only validation

Result:

`PASS`

Observed markers:

- `BASH_SYNTAX=PASS`
- `TARGETED_DB_CLEANUP=RETAINED`
- `FILESYSTEM_RECURSIVE_DELETE=ABSENT`
- `RUN_ARTIFACT_PRESERVATION=PASS`
- `LAB_BOUNDARY=RETAINED`
- `STATIC_CLEANUP_CONTRACT=PASS`
- `MINIMAL_DIFF_SHAPE=PASS`
- `REPOSITORY_ONLY_CLEANUP_HARDENING=PASS`

Diff shape:

`2 insertions / 1 deletion`

## Artifact identities

Harness SHA-256:

`d0bd88ca46fdf8cc5e09f4d29f87ce33c9c06a217b332aaeb644400dd71c219c`

Protected consolidator SHA-256:

`d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`

Repository-validation evidence SHA-256:

`959160371e1bc2be112cf293b84b360592d44d387bd3b31c07f70f5fa6d0747f`

## Execution boundary

The LAB harness was not executed in this phase.

No Qwen request was performed.

No PostgreSQL access was performed.

Production was not touched.

FINDING-05 remains:

`CLOSED / REAL_MODEL_REVALIDATED`

The future CLI/PostgreSQL E2E is additional integration validation, not a
revalidation of FINDING-05.

## Progression

Current completed progression:

`DESIGN -> REPOSITORY HARDENING -> REPOSITORY VALIDATION -> COMMIT`

Remaining progression:

`CONTINUITY -> REMOTE SYNC -> SEPARATE E2E AUTHORIZATION -> LAB EXECUTION`

## NEXT_ACTION

`FRESH_FETCH_GUARD_THEN_PUSH_CLEANUP_HARDENING_CHECKPOINT`
