# Mímir Project Handoff

Updated: 2026-09-24
Status: IN PROGRESS
Handoff version: 1

## Purpose

This file is the operational continuity point for Projeto Mímir.

When a ChatGPT conversation, Codex session or other development session ends, the next session must read this file before deciding what to do.

Do not reconstruct project state from conversational memory when this file and Git are available.

## Source of truth

Priority order:

1. Git repository and current branch
2. docs/MIMIR_HANDOFF.md
3. docs/MIMIR_V1_EXECUTION_PLAN.md
4. docs/review/operations/
5. docs/STATUS.md
6. docs/ROADMAP.md
7. conversation history

If conversational context conflicts with Git or this file, inspect Git and resolve the discrepancy before continuing.

## Repository

Repository: NogueiraMaier/projeto-mimir

Development branch:
feat/mimir-operational-foundation

Pull request:
PR #1

PR state:
Draft
Open
Not merged

LAB-06B validation checkout:
4ef8362c51666124c4c4b39ce181f2b1e9df3e8d

Development host:
gentoo-Dragon_IA

Development user:
jarvisdev

Validation VPS:
gentoo-Dragon_vm

## Production safety state

Production PostgreSQL:

schema_version = 1..12
version13 = false
mimir_ops role = false

Migration 013 has NOT been applied to production.

Do not apply migration 013 to production without explicit authorization.

Do not create the production mimir_ops role without explicit authorization.

Do not use real equipment for EXECUTE until the synthetic EXECUTE workflow and the required safety hardening are validated.

## Current milestone

Milestone:
MIMIR-V1-013

Last completed checkpoint:
MIMIR-V1-TELEGRAM-01

Checkpoint status:
COMPLETED

The persistent READ workflow was validated end to end in the isolated PostgreSQL laboratory.

Validated sequence:

intervention.begin
READ intent
READ result
DONE / complete
intervention.finish
evidence persistence
report persistence
history API
report API
inventory verification update

Synthetic identity was restored after the laboratory.

Production remained unchanged.

## Last code bug fixed

The persisted workflow guard was reading the prior operation from the wrong JSON location.

Incorrect:

last_action.payload->>'operation'

Correct:

last_action.payload#>>'{action,operation}'

Regression fix commit:

148044569dab79a2faa902e1a7b51c691bb43353

LAB-06 subsequently validated the fix.

## Current validation state

LAB-07 validated the complete synthetic EXECUTE state machine without real equipment.

LAB-08 validated backup and restore of the isolated operational PostgreSQL laboratory.

LAB-09 validated fail-closed reconciliation of an interrupted EXECUTE workflow, including mandatory READ reverification before another EXECUTE is accepted.

Hardening code commit:

86cf4a96a176c7ac2fdb9decb9c26dc89ecbac38

The v1 operational retention policy is now versioned in:

docs/OPERATIONS_RETENTION.md

Policy checkpoint:

MIMIR-V1-OPS-RETENTION-01

The v1 policy prohibits automatic purge, preserves failed/interrupted operational history, keeps real evidence/reports out of Git, and allows fully synthetic laboratories to be removed only after required evidence and recovery checkpoints are recorded.

Production remains unchanged:

schema_version 13 = false
mimir_ops role = false

No real equipment has been contacted.

## NEXT_ACTION

Validate the Telegram channel as an operational surface for the Mímir main
agent using read-only requests first.

Sequence:

1. test a runtime status query from Telegram;
2. test a memory lookup from Telegram;
3. document which automated notification classes will be used;
4. keep the existing production boundaries unchanged.

Working checkpoint:

MIMIR-V1-TELEGRAM-02

Checkpoint status: BLOCKED — tool surface diagnosis required.

Observed from the Telegram direct session on 2026-09-25:

- explicit `session_status` request returned `TOOL_UNAVAILABLE: session_status`;
- explicit `mimir_memory_search` request returned
  `TOOL_UNAVAILABLE: mimir_memory_search`;
- Telegram transport itself remains healthy and bidirectional;
- no production authorization boundary has been widened.

Next executable action: inspect the session-scoped effective tool inventory and
the global/per-agent tool policy before changing any configuration.

## PostgreSQL laboratory

Host:
gentoo-Dragon_vm

Temporary cluster:
/var/tmp/mimir-pg13-lab

Database:
mimir_lab

Port:
55432

The temporary PostgreSQL laboratory was stopped and removed after the required evidence, backup/restore and bootstrap validation were completed.

## Completed migration 013 laboratory checkpoints

MIMIR-V1-013-LAB-01:
migration inventory schema validation completed

MIMIR-V1-013-LAB-02:
mimir_ops role and least privilege validation completed

MIMIR-V1-013-LAB-03:
peer authentication mechanism validation completed

MIMIR-V1-013-LAB-04:
controlled API with synthetic inventory completed

MIMIR-V1-013-LAB-05:
negative API and authorization tests completed

MIMIR-V1-013-LAB-06:
persistent synthetic READ workflow completed

MIMIR-V1-013-LAB-06B:
temporal integrity hardening validated in PostgreSQL laboratory

MIMIR-V1-013-LAB-07:
full synthetic EXECUTE state machine validated without real equipment

MIMIR-V1-013-LAB-08:
isolated PostgreSQL laboratory backup and restore validated

MIMIR-V1-013-LAB-09:
interrupted EXECUTE reconciliation and mandatory reverification validated

## Do not repeat

Do not repeat LAB-01 through LAB-09 unless a later code change affects their validated assumptions.

Do not redo historical migration reconstruction 009 through 012.

Do not renumber migration 013.

Do not merge PR #1 yet.

Do not apply migration 013 to production.

Do not alter /var/lib/openclaw/workspace for validation experiments.

Do not provision the final Linux mimir-ops identity in production yet.

## Remaining major work after migration 013 validation

Canonical memory-v1 bootstrap validation completed

Permanent PostgreSQL memory workflow

Operational backup and restore validation

Interrupted intervention reconciliation

Evidence and report retention policy

First real equipment READ homologation

generic-linux transient set-hostname homologation

MikroTik READ homologation

CI

clean checkout validation

release security checklist

PR review

v1 tag

Maestro documentation update after Mímir stabilization

## Documentation roles

docs/MIMIR_HANDOFF.md

Current operational state and exact continuation point.

docs/MIMIR_V1_EXECUTION_PLAN.md

Master execution plan for Mímir v1.

docs/review/operations/

Detailed chronological evidence.

docs/ROADMAP.md

Future evolution beyond the immediate v1 execution sequence.

docs/MEMORY_V2_ROADMAP.md

Future memory v2 work.

## Resume protocol for a new ChatGPT session

The first action in a new session must be:

Read docs/MIMIR_HANDOFF.md from the current Git branch.

Then inspect:

docs/MIMIR_V1_EXECUTION_PLAN.md

Confirm:

git branch --show-current
git status --short --branch
git rev-parse HEAD

Compare the repository state with the handoff.

Do not guess missing state from memory.

Resume from NEXT_ACTION.

If the working tree contains uncommitted changes, inspect them before pulling, resetting or changing anything.

## Handoff update rule

Update this file whenever one of these occurs:

A LAB finishes

A blocking bug is found

A blocking bug is fixed

The next action changes

The development machine changes

The validation environment changes

A commit becomes the new continuation point

A production change is authorized or executed

A long development or ChatGPT session is about to end

The handoff must describe the next executable action, not only historical progress.

Before starting a new major phase, commit the updated handoff.


## Architectural documentation prepared but not active

The following architectural documentation has been prepared on a separate documentation branch:

Branch:

`docs/mimir-gateway-model-routing`

Documents:

- `docs/GATEWAY_PCIA_MIGRATION_PLAN.md`
- `docs/MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`
- `docs/review/architecture/2026-09-25-gateway-model-routing.md`

Status:

**DOCUMENTED / NOT IMPLEMENTED**

These documents record future architecture and migration planning only.

They do **not** replace the current operational continuation point, do not change the current milestone and do not supersede the existing `NEXT_ACTION`.

The current `NEXT_ACTION` in this handoff remains authoritative until the Telegram/tool-surface work is concluded and the handoff is explicitly advanced through the normal project process.

Do not start the Gateway migration or model-routing implementation merely because these documents exist.

When the project reaches the appropriate future phase, inspect the dedicated documentation branch and reconcile it with the then-current operational branch before execution.

### Branch roles recorded for continuity

At the time of this note:

- `feat/mimir-operational-foundation` — current operational/v1 development line;
- `docs/mimir-gateway-model-routing` — future Gateway migration and model-routing documentation;
- `docs/mimir-memory-v2-roadmap` — future Memory v2 documentation.

A file not present on the current branch must not automatically be interpreted as deleted or abandoned. Check the documented branch ownership before drawing that conclusion.

### Current versus target architecture

The target architecture described in the new documents is **not evidence of current implementation**.

Future agents must distinguish:

- **CURRENT** — runtime and checkpoints actually validated;
- **TARGET** — planned Gateway placement, Capability Router, Policy Engine and Engine Registry;
- **WATCHLIST** — techniques/components requiring later benchmark or evidence.

No future agent should mark a TARGET component as implemented without runtime evidence and an explicit project checkpoint.
