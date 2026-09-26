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

Development validation on PcIA found one compile-time packaging mismatch:

- OpenClaw 2026.9.5 runtime exports
  `openclaw/plugin-sdk/embedding-providers`, but its package export omits a
  TypeScript `types` mapping for that subpath;
- TypeScript therefore failed with TS7016 before any runtime smoke test;
- no runtime or production change occurred.

Follow-up fix versioned on 2026-09-25:

- commit `d474eb36464c9b2232ba90584b04a016b4e79714`;
- added a narrow local declaration shim matching the OpenClaw 2026.9.5
  embedding-provider structural contract;
- no OpenClaw implementation code was copied or vendored;
- the plugin still resolves the actual embedding provider from the installed
  OpenClaw runtime;
- the development tool resolver now also checks `/opt/openclaw-release` and
  `~/.local/share/openclaw-client/node_modules` without downloading anything.

Development validation result on PcIA:

- development HEAD: `408533480103ba6208308f8867ff26b777ca31d9`;
- helper syntax check: PASS;
- TypeScript build: PASS;
- structural import: PASS;
- 768-dimension embedding contract smoke test: PASS;
- invalid embedding rejection: PASS;
- dedicated PostgreSQL transport environment isolation: PASS;
- Vitest remains unavailable on PcIA and was not installed;
- no production runtime change occurred.

VPS isolated validation attempted on 2026-09-25 at detached HEAD
`fb0dcdfbe39e2cbbaadd58579dae96d9526b0cac` with Node 24.16.0 and
OpenClaw 2026.9.5.

Result: FAILED / NOT VALIDATED.

Observed:

- helper syntax check passed;
- Vitest was unavailable through the existing resolver, so plugin tests did not
  execute;
- TypeScript was found, but the build failed with TS2688 because the isolated
  checkout could not resolve the `node` type definition library;
- `dist/index.js` must not be treated as proof of a successful build because
  TypeScript may emit output despite diagnostics and the checkout already had a
  prior artifact;
- the structural import command then failed because nested shell/heredoc quoting
  removed the quotes around `./dist/index.js`;
- the final printed `VPS ISOLATED VALIDATION: PASS` was unconditional and is
  therefore a false positive;
- no production plugin deployment or PostgreSQL/tool-policy/Telegram-policy
  change occurred.

VPS shared dependency discovery completed on 2026-09-25:

- `/opt/openclaw` is a symlink to
  `/opt/openclaw-release/node_modules/openclaw`;
- shared `typescript`, `@types/node`, `typebox` and `undici-types` exist
  under `/opt/openclaw-release/node_modules`;
- `vitest` is not present in the inspected OpenClaw, workspace or backup
  dependency roots;
- `createRequire("/opt/openclaw-release/package.json")` resolves TypeScript,
  `@types/node` and `undici-types`, while the package-local
  `/opt/openclaw/package.json` resolver does not;
- the isolated TypeScript failure is therefore a project module-resolution
  issue, not an absent `@types/node` package.

VPS isolated validation V2 completed successfully on 2026-09-25 at
detached HEAD `a7153997a32ab70ee29b035d2ff66ba15d071cdf`, using
Node 24.16.0 and OpenClaw 2026.9.5.

Validated:

- helper syntax: PASS;
- legacy `node-llama-cpp` guard: PASS (absent from explicit tool path);
- managed `acquireLocalService` integration marker: PASS;
- TypeScript build with `--noEmitOnError`: PASS;
- fresh `dist/index.js` generated under the isolated checkout: PASS;
- structural import: PASS;
- plugin id/register/testing exports: PASS;
- 768-dimension embedding contract: PASS;
- invalid vector rejection: PASS;
- dedicated PostgreSQL environment isolation: PASS;
- Vitest remains unavailable and was not installed.

Production remained unchanged.

Production pre-deploy inventory completed on 2026-09-25.

Observed production baseline:

- host `gentoo-Dragon_vm`, Node 24.16.0, OpenClaw 2026.9.5;
- OpenRC `openclaw` service healthy and running;
- production plugin root:
  `/var/lib/openclaw/workspace/plugins/mimir-memory`;
- on-disk and runtime plugin version: `0.2.6`;
- runtime registration is loaded, enabled, explicit, install source `path`,
  accepted tool surface only `mimir_memory_search`, typed hooks
  `gateway_stop` and `message_received`;
- production helper still contains the obsolete in-process
  `node-llama-cpp` path and is therefore the known failing implementation;
- production plugin `node_modules` is a real directory with no broken
  symlinks reported;
- `tools/run-tool.mjs` is absent from the production 0.2.6 plugin;
- shared VPS build dependencies exist in
  `/opt/openclaw-release/node_modules`:
  TypeScript 6.0.3, @types/node 26.6.2, typebox 1.3.30 and
  undici-types 8.9.0.

Recorded production SHA-256 baseline:

- `src/index.ts`:
  `384c37b9243025f25b0f0c07859186c54014e8b54a4991ff52343988d711d399`;
- `dist/index.js`:
  `00e4a9a207ff495695f4ebba269f9afa297005d097b28fe093666bf87fb0bb0e`;
- `package.json`:
  `25a19c5a0d77e5821122526842f8bf7277a64de197bf50aa1e50cff038aea22f`;
- `openclaw.plugin.json`:
  `783e8bf6e521d44930a035cc2aecbc5be2ec9398e126c73b4bdfa944d0f6eaa3`;
- `tsconfig.json`:
  `cbc659156f2bc5c4976619a11c9119dab7e4a6d888c92417fa570ea24d208200`;
- semantic helper:
  `e9b54ccedbdf4926fc1cc635c40146561bb384cd4620f6e8eb5cf74614c530ae`.

Production backup/rollback checkpoint completed on 2026-09-25.

Explicit production deployment authorization received on 2026-09-25 for
`mimir-memory 0.2.7` only. This authorization does not widen migration 013,
`mimir_ops`, tool policy, Telegram policy, or PostgreSQL schema boundaries.

Backup:

`/var/backups/mimir-memory-0.2.6-20260925T203923`

Validated:

- all six production baseline SHA-256 guards matched before backup;
- full production `mimir-memory 0.2.6` directory archived;
- semantic-search helper copied separately;
- runtime registration snapshot captured;
- checksum manifest written;
- archive extracted to a temporary restore-check directory;
- source/build/package/manifest/helper comparisons passed;
- explicit rollback instructions written to `ROLLBACK.txt`;
- no production runtime file was replaced and the Gateway remained loaded with
  0.2.6 during this checkpoint.

Controlled production deployment completed successfully on 2026-09-25.

Production runtime result:

- deployed plugin source/build from validated commit
  `a7153997a32ab70ee29b035d2ff66ba15d071cdf`;
- OpenClaw Gateway stopped cleanly before the plugin/helper contract change and
  restarted successfully afterward;
- on-disk package and manifest version: `0.2.7`;
- runtime packageVersion/version: `0.2.7`;
- runtime status: `loaded`;
- runtime activated: true;
- `mimir_memory_search` registered;
- typed hooks remain `gateway_stop` and `message_received`;
- production runtime resolved `typebox` from plugin-local dependencies and
  `openclaw/plugin-sdk/embedding-providers` from OpenClaw 2026.9.5;
- deployment log:
  `/var/backups/mimir-memory-0.2.7-deploy-20260925T215150`;
- rollback backup remains:
  `/var/backups/mimir-memory-0.2.6-20260925T203923`;
- persisted install-record metadata still reports 0.2.6, while the actually
  loaded runtime reports 0.2.7; do not rewrite that install record during this
  checkpoint unless a separate registration-maintenance action is authorized.

Production 0.2.7 SHA-256 baseline:

- `src/index.ts`:
  `06f6e00ae08c97a14afea345eb109538912090c19f23925d9d42c2a9d1449326`;
- `src/openclaw-embedding-providers.d.ts`:
  `d25f8bad1dc48b164e15b718550f12b0d6834a843597a0abd4799a7b9bd45f93`;
- `dist/index.js`:
  `599a316ff4eb6c421f305d8156d0b7d5c3fe5304d691d40943053c5d3ab72c0d`;
- `package.json`:
  `7e30e2c9e302ecf57d2a80d5d7cb1eba5c58adf3bb197448eae50523b4a58e83`;
- `openclaw.plugin.json`:
  `127a0115bb44324d85dac5d9cad393ecc78c414785cc1510cce20c3d699f5144`;
- `tsconfig.json`:
  `36fd3d6138dacde7445cc6571d24540ebfb1d1e870eb5c16922cc38a5e352bde`;
- `tools/run-tool.mjs`:
  `295e53fed105f3aebdfb5d7c66d7cf638829aae2d76f85bb07a39ec7ed4ddfe0`;
- semantic helper:
  `d586ee22a44f53fc08d439c601071db6106efb1671fe851a82ca2ef84a375d79`.

Production runtime deployment checkpoint:

- `mimir-memory 0.2.7` is loaded and activated in production;
- `mimir_memory_search` is registered after Gateway restart;
- runtime deployment itself is complete and must not be rolled back merely
  because the next functional invocation exposes a separate embedding,
  PostgreSQL, policy or session-path defect;
- persisted install-record metadata still reports 0.2.6 while the loaded
  package/runtime reports 0.2.7; this is recorded metadata drift, not a runtime
  version mismatch.

Direct production invocation completed successfully on 2026-09-25.

Evidence:

- `tools.effective` and the direct Gateway `tools.invoke` validation block
  completed under fail-fast semantics and reached
  `=== MIMIR MEMORY DIRECT INVOCATION: PASS ===`;
- direct invocation evidence directory:
  `/var/backups/mimir-memory-0.2.7-direct-20260925T223314`;
- the managed llama.cpp local embedding service was started by OpenClaw at
  22:33:22 and reported ready with pid 6727, spawn 40 ms, ready 306 ms;
- the older `node-llama-cpp` errors visible in the tailed logs are historical
  entries from before the 0.2.7 deployment and are not evidence of the current
  direct invocation failing;
- therefore the explicit `mimir_memory_search` path is now validated through
  Gateway policy, managed local embedding lifecycle and semantic-search
  execution. The shadow path remains a separate validation item.

Next executable action:

1. repeat a memory-recall request through the existing Telegram direct session
   `agent:main:telegram:direct:242921698`;
2. verify from Gateway logs/session output that Telegram can actually select and
   execute `mimir_memory_search`, rather than merely answering from model
   context;
3. if successful, close `MIMIR-V1-TELEGRAM-02` and record the runtime memory
   0.2.7 explicit-tool path as production-validated;
4. keep migration 013, `mimir_ops`, tool permissions and Telegram policy
   unchanged;
5. do not mark the shadow evaluator/generator path healthy; it remains separate.

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
