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

Last completed laboratory:
MIMIR-V1-013-LAB-08

LAB-08 status:
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

LAB-07 validated the complete synthetic EXECUTE workflow without contacting real equipment.

Validated state machine:

PRECHECK -> SNAPSHOT -> BACKUP -> EXECUTE -> VALIDATE -> DONE

The durable journal contains exactly ten ordered events: intent/result for each stage. A deliberate out-of-order SNAPSHOT intent was rejected before any action was persisted.

LAB-07 terminal state:

status=validated
requested_mode=EXECUTE
workflow_stage=DONE
workflow_state=complete
final_validation=true
inventory_updated=true
actions=10
reports=1
evidence=1

The synthetic device became verified and collected, with last_change_at populated.

LAB-08 validated backup and restore of the isolated operational PostgreSQL laboratory.

Source and restored inventory matched:

schema versions 1..13
15 ops tables
3 clients
3 sites
3 devices
3 interventions
14 actions
3 reports
3 evidence records
temporal guard present

The restored LAB-07 intervention remained validated with ten actions, one report and one evidence.

Backup SHA-256:

5989dd1dcc21e6767563a531d1da6c3424cedfe08b9b7db434e06aecbb6d8273

Production remained unchanged throughout:

schema_version 13 = false
mimir_ops role = false

## NEXT_ACTION

Define and validate the interrupted-intervention reconciliation procedure before any real equipment homologation.

Use only the isolated PostgreSQL laboratory and synthetic data.

The validation must simulate an EXECUTE intervention interrupted after an EXECUTE intent but before a durable EXECUTE result.

Required properties:

1. a second EXECUTE on the same device remains blocked while the first intervention is running;
2. history/report expose enough durable state for human reconciliation;
3. reconciliation must finalize the interrupted intervention as failed without inventing a successful result;
4. because an EXECUTE intent occurred without confirmed result, the device must remain or become unverified and require manual verification;
5. the reconciled intervention must preserve the journal and audit history;
6. production must remain untouched.

Working name:

MIMIR-V1-013-LAB-09

Do not contact real equipment.

## Planned sequence

1. Create a new synthetic generic-linux device with permission_mode=EXECUTE
2. Start an approved synthetic EXECUTE intervention
3. Complete PRECHECK, SNAPSHOT and BACKUP with synthetic doubles
4. Persist EXECUTE intent only, then simulate interruption
5. Confirm a second EXECUTE is blocked
6. Inspect history/report for the running intervention
7. Reconcile the original intervention to failed using only durable journal facts
8. Confirm device is unverified and the original journal is preserved
9. Confirm the intervention is terminal failed with completed_at set
10. Restore synthetic identity
11. Confirm production remains version13=false and mimir_ops=false
12. Record whether the existing API is sufficient or whether additional reconciliation hardening is required

## Expected next laboratory

MIMIR-V1-013-LAB-09

Purpose:

Validate fail-closed reconciliation of an interrupted synthetic EXECUTE intervention.

## PostgreSQL laboratory

Host:
gentoo-Dragon_vm

Temporary cluster:
/var/tmp/mimir-pg13-lab

Database:
mimir_lab

Port:
55432

The temporary laboratory must not be removed until required evidence and backup/restore validation are complete.

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

## Do not repeat

Do not repeat LAB-01 through LAB-08 unless a later code change affects their validated assumptions.

Do not redo historical migration reconstruction 009 through 012.

Do not renumber migration 013.

Do not merge PR #1 yet.

Do not apply migration 013 to production.

Do not alter /var/lib/openclaw/workspace for validation experiments.

Do not provision the final Linux mimir-ops identity in production yet.

## Remaining major work after migration 013 validation

Historical migration 001 resolution or canonical bootstrap documentation

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
