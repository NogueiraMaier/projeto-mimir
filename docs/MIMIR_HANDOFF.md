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

Checkpoint status: BLOCKED — custom memory tool runtime defect identified.

Observed from the Telegram direct session on 2026-09-25:

- effective tool profile is `minimal`;
- `session_status` is absent because `tools.deny` includes `group:sessions`;
- `mimir_memory_search` is present in `tools.effective` for the Telegram session;
- direct `tools.invoke` reaches `mimir_memory_search` but returns
  `internal_error: tool execution failed`;
- the custom semantic-search helper still resolves the removed in-process
  `node-llama-cpp` package and fails with `MODULE_NOT_FOUND`;
- OpenClaw 2026.9.5 native memory is using the managed llama.cpp local service
  at `http://127.0.0.1:8601/v1`;
- native embedding probe succeeds with 768 dimensions using
  EmbeddingGemma through managed `llama-server`;
- the native memory status observed during this diagnosis reports `dirty=true`
  and must be reconciled separately before declaring a clean memory baseline;
- Telegram transport remains healthy and bidirectional;
- no production authorization boundary has been widened.

Code fix versioned on 2026-09-25:

- commit `eff3f90f46f9dd54c8c27210ca3051a932d13cd2`;
- plugin version advanced to `mimir-memory 0.2.7`;
- explicit `mimir_memory_search` now resolves the OpenClaw registered local
  embedding provider and supplies `api.runtime.llm.acquireLocalService()`, so
  OpenClaw owns the managed `llama-server` lifecycle;
- the PostgreSQL helper no longer loads `node-llama-cpp`; it receives a
  validated 768-dimensional vector over stdin and performs only the controlled
  `mimir.search_active_memory(...)` lookup;
- PostgreSQL transport defaults remain local but can be overridden only through
  dedicated `MIMIR_MEMORY_PG*` service environment variables, preparing a
  future PcIA -> VPS path without inheriting arbitrary Gateway PG variables;
- the evidence-shadow path is separate and was intentionally not declared fixed
  by this patch.

Runtime status of this fix: VERSIONED, NOT YET DEPLOYED OR VALIDATED.

Next executable action:

1. validate commit `eff3f90f46f9dd54c8c27210ca3051a932d13cd2` on the
   development checkout with plugin tests, TypeScript build and helper syntax;
2. only after those pass, prepare a controlled VPS deployment/rollback of
   `mimir-memory 0.2.7`;
3. re-run direct `tools.invoke` for `mimir_memory_search`;
4. only after direct invocation passes, repeat the Telegram memory request;
5. keep tool permissions, Telegram policy, production PostgreSQL schema and
   migration 013 unchanged throughout this validation.

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
