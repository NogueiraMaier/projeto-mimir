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

## HISTORICAL NEXT_ACTION — TELEGRAM

Validate the Telegram channel as an operational surface for the Mímir main
agent using read-only requests first.

Sequence:

1. test a runtime status query from Telegram;
2. test a memory lookup from Telegram;
3. document which automated notification classes will be used;
4. keep the existing production boundaries unchanged.

Working checkpoint:

MIMIR-V1-TELEGRAM-02

Checkpoint status: CONCLUÍDO — Telegram explicit memory-tool path validated end to end on 2026-09-26.

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

Telegram-02 evidence capture attempted after the 0.2.7 direct-invoke PASS,
but the captured grep output did not include a new post-deploy Telegram inbound
turn or a current `mimir_memory_search` execution. It only showed historical
Telegram activity from earlier on 2026-09-25, the old pre-0.2.7
`node-llama-cpp` failure, the 21:52 Gateway/Telegram restart, and the 22:33
managed embedding service start associated with the already-validated direct
invocation.

Therefore `MIMIR-V1-TELEGRAM-02` remains OPEN; do not infer success from that
capture.

Telegram-02 fresh post-deploy test failed on 2026-09-25.

Observed:

- Telegram ingress is healthy: the new 173-character direct message from
  Telegram user 242921698 reached `@MimirAssistenteBot` at 22:41:46;
- Telegram egress is healthy: the bot sent one text reply at 22:41:59;
- the visible bot reply was exactly
  `TOOL_UNAVAILABLE: mimir_memory_search`;
- no `tool_execution_started`, current `mimir_memory_search` execution, or
  new managed-embedding event appeared for that turn;
- therefore the 0.2.7 explicit tool implementation itself remains validated by
  direct Gateway `tools.invoke`, but the normal Telegram agent-turn tool
  projection/selection path still does not expose the optional plugin tool to
  the model;
- `MIMIR-V1-TELEGRAM-02` remains BLOCKED and must not be closed.

OpenClaw 2026.9.5 source inspection relevant to this blocker:

- `mimir_memory_search` is registered by the plugin as an optional tool;
- restricted profiles do not automatically select optional plugin tools;
- direct Gateway `tools.invoke` explicitly injects the requested non-core
  tool into `gatewayRequestedTools`, which explains why direct invocation can
  succeed even when a normal Telegram agent turn does not receive that tool;
- the next diagnostic must compare the saved/current `tools.effective`
  projection with the actual configured profile/allow/alsoAllow/runtime
  restrictions for the Telegram turn before changing policy.

Additional Telegram-02 policy evidence:

- no `toolsAllow` field was found anywhere in the inspected configuration;
- around the failed 22:41 Telegram turn, Gateway repeatedly reported that agent
  `main` uses tool profile `minimal`;
- global tools already include `alsoAllow` for
  `exec, process, read, write, edit`;
- `agents.entries.main.tools.alsoAllow` already contains exactly
  `mimir_memory_search` and `web_search`;
- current `tools.effective` for
  `agent:main:telegram:direct:242921698` lists both `web_search` and
  `mimir_memory_search`, with the latter sourced from plugin
  `mimir-memory`;
- nevertheless a real Telegram agent turn still returned
  `TOOL_UNAVAILABLE: mimir_memory_search` and did not emit a tool-execution
  event.

This disproves the earlier hypothesis that the blocker was a missing
`alsoAllow` grant. Do not add or widen tool permissions as a fix.

OpenClaw 2026.9.5 documentation describes `tools.effective` as a
server-derived session inventory projection. It is useful evidence, but the
remaining discrepancy is now between that projection and the concrete
model-facing tool set of the actual Telegram run.

Active-run and trajectory diagnostics for the failed Telegram memory turn:

- the 23:02:24-23:02:44 -03 Telegram turn maps to the trajectory run beginning
  at 02:02:25 in the session tail;
- that run has `session.started -> context.compiled -> prompt.submitted ->
  model.completed -> trace.artifacts -> session.ended success` and contains no
  `tool.call` / `tool.result` event;
- therefore the visible `TOOL_UNAVAILABLE: mimir_memory_search` response for
  that turn was generated as model text; it was not a runtime rejection of an
  attempted `mimir_memory_search` invocation;
- the provider/model for the turn was
  `mimir-gpu//var/lib/mimir/models/Qwen3-4B-Q4_K_M.gguf`, using the
  OpenAI-compatible chat-completions transport;
- no global `tools.byProvider` override is configured and
  `agents.entries.main.tools.alsoAllow` still contains
  `mimir_memory_search` and `web_search`;
- immediately before provider submission OpenClaw logged
  `route=compact_only`, `estimatedPromptTokens=15955` and
  `promptBudgetBeforeReserve=12288`;
- trajectory export under
  `/var/tmp/mimir-telegram02-trajectory.ejS31N` produced 84 runtime events and
  31 transcript events, but the 02:02:25 `context.compiled` event exposed no
  `tools` or `providerVisibleTools`, and no `tools.json` was exported;
- that absence is not yet proof that the provider received zero tools:
  OpenClaw 2026.9.5 can truncate oversized trajectory events and explicitly
  drop `tools`, recording `truncated=true`,
  `reason=trajectory-event-size-limit` and `droppedFields`; this must be
  checked before interpreting the missing fields as an actual provider
  boundary condition.

Trajectory payload projection follow-up for the failed 23:02 Telegram turn:

- target `context.compiled` event remains
  `2026-09-26T02:02:25.474Z`;
- the outer event is not oversized/truncated, but `data.tools` materializes as
  the literal diagnostic sentinel `"[Truncated]"`;
- OpenClaw 2026.9.5 `sanitizeDiagnosticPayload()` uses
  `projectDiagnosticValue()` with a shared 64-node projection budget; when
  that budget is exhausted a nested value is replaced by `"[Truncated]"`.
  Therefore this sentinel is diagnostic-projection truncation, not evidence
  that the provider received zero tools;
- the prior `route=compact_only` log is also diagnostic-only in this code
  path: OpenClaw explicitly logs that this pressure estimate does not compact
  or discard history before the admitted provider attempt.

The current long Telegram session could not prove the concrete provider-facing
tool-name set from its retained trajectory alone, so a fresh-session
reproduction was executed.

Fresh-session Telegram validation on 2026-09-26:

- user-driven `/new` reproduction created a low-context Telegram turn without
  changing tool policy, plugin registration, Telegram policy or model routing;
- the fresh trajectory recorded `context.compiled (2 tools)`;
- the model emitted a real `tool.call` for `mimir_memory_search`;
- OpenClaw recorded `tool.result ... mimir_memory_search ok`;
- the run then completed on
  `mimir-gpu//var/lib/mimir/models/Qwen3-4B-Q4_K_M.gguf` with
  `session.ended ... success`;
- therefore the complete explicit Telegram path is production-validated:
  Telegram ingress -> main-agent tool projection -> local Qwen tool selection ->
  `mimir_memory_search` -> managed local embedding -> PostgreSQL semantic
  lookup -> tool result -> Telegram response;
- `MIMIR-V1-TELEGRAM-02` is CLOSED / PASS;
- the earlier long-session `TOOL_UNAVAILABLE` response is classified as a
  session/model-behavior artifact, not as a plugin-registration, policy,
  embedding-provider or PostgreSQL failure;
- the bot's fresh semantic answer did not correctly answer the requested
  migration/LAB facts, despite successful tool execution. Retrieval relevance
  / memory-corpus freshness remains a separate P1 memory-quality issue and must
  not be conflated with Telegram tool availability.

Permanent-memory production corpus and pipeline diagnosis completed.

Corpus evidence:

- production schema remains versions 1..12 only;
- exactly five active memory records exist and all five have embeddings;
- all five active records were created on 2026-07-30 and all derive from
  `MEMORY.md`;
- the active keys are limited to project identity/title, execution platform,
  principal model and critical-security principle;
- none of the five active memories contains migration 013, LAB-01..LAB-09,
  `mimir_ops` or `schema_version`;
- therefore the Telegram semantic miss is a corpus-coverage failure, not an
  embedding-generation or ranking failure.

Pipeline evidence from the read-only production inventory:

- `memory_events` contains only three source events total: two
  `workspace-markdown` document imports and one protected OpenClaw session
  import;
- the only Markdown sources ever ingested are `MEMORY.md` and
  `memory/2026-07-30.md`, both from 2026-07-30;
- `session_sources` contains exactly one captured session, also from
  2026-07-30, with 13 user and 29 assistant messages;
- that protected session contains none of the migration-013/LAB/`mimir_ops`/
  `schema_version` terms;
- there are zero candidate memories, zero pending-review records and zero
  pending embeddings;
- the only five reviews are the original 2026-07-30 approvals of the five
  currently active memories;
- recent operational knowledge therefore never reached the ingestion layer at
  all. The current blocker precedes consolidation/review/promotion/embedding;
- repository `MEMORY.md` is stale relative to the validated project state;
- the current Markdown importer intentionally reads only `MEMORY.md` plus
  top-level `memory/*.md`; operational truth under `docs/` is outside that
  source set;
- the runbook explicitly states that no session should be imported without an
  explicit ingestion-client execution, so absence of recent sessions may be an
  unimplemented/unscheduled workflow rather than a failed daemon. This must be
  confirmed before adding automation.

Read-only ingestion-runtime inventory partially completed.

Evidence:

- OpenRC has `postgresql-17`, `mimir-llama`, `openclaw` and `cronie`
  started; `mimir-hud` is stopped;
- no OpenRC init/conf file references the memory ingestion scripts;
- root crontab contains one line matching the broad ingestion-related search,
  but its exact command still needs safe inspection before classifying it;
- no ingestion-related process was running during the inventory;
- deployed memory ingestion/consolidation scripts are all still the 2026-07-30
  versions;
- `mimir-ingest-session.py` explicitly rejects every mode except
  `--dry-run`, confirming the write client was never completed;
- the inventory aborted when it attempted to read
  `/var/lib/openclaw/.openclaw/agents/main/sessions/sessions.json`, which no
  longer exists.

OpenClaw 2026.9.5 uses SQLite as the canonical session store. Runtime session
rows/transcripts live by default at
`~/.openclaw/agents/<agentId>/agent/openclaw-agent.sqlite`; legacy
`sessions.json`/JSONL files are migration sources only. Therefore the current
Mímir session-capture code is structurally obsolete for the installed OpenClaw:
it hardcodes the legacy `sessions.json` + JSONL layout and cannot enumerate the
current canonical sessions.

This is now the primary P1 ingestion blocker. Do not work around it by recreating
legacy `sessions.json` files or reading SQLite internals ad hoc.

SQLite session inventory completed on 2026-09-26.

Evidence:

- canonical main-agent session store:
  `/var/lib/openclaw/.openclaw/agents/main/agent/openclaw-agent.sqlite`,
  owner `openclaw:openclaw`, mode 0600;
- OpenClaw CLI reports 18 canonical session rows, with 12 currently
  `status=done`;
- current store contains direct, HUD, ACP bridge, Maestro, Telegram and cron
  session keys; the latest Telegram direct session is visible through the
  canonical store;
- the only root-crontab line matching the earlier broad search is
  `mimir-security-audit --scheduled` every six hours; it is unrelated to
  memory ingestion, so no scheduled memory-ingestion job has been identified;
- no ingestion-related process was running;
- legacy collector compatibility check is explicit:
  `references_sessions_json=true`,
  `references_jsonl=true`,
  `references_openclaw_agent_sqlite=false`;
- conclusion:
  `RESULT=LEGACY_SESSION_COLLECTOR_INCOMPATIBLE`;
- therefore current session knowledge is available in OpenClaw 2026.9.5, but
  the Mímir capture client cannot reach it because it targets the retired
  file-backed session layout.

Read-only structural probe of the supported OpenClaw 2026.9.5
`chat.history` boundary completed successfully for the canonical Telegram
owner-DM session.

Evidence:

- `chat.history` returned the expected canonical `sessionKey` and
  `sessionId`;
- response exposed pagination/state metadata including `hasMore`,
  `totalMessages` and `deltaCursor`;
- all five returned messages had stable `__openclaw.id` and `seq`, and all
  five had timestamp information;
- the single user message carried
  `__openclaw.senderIsOwner=true` with no missing owner marker;
- user metadata also exposed sender/transport identity fields without requiring
  direct SQLite access;
- roles observed were system, user, assistant and toolResult; assistant content
  also contained thinking/toolCall blocks, confirming the replacement collector
  must explicitly keep only user/assistant text and exclude system, toolResult,
  thinking and toolCall material;
- result:
  `CHAT_HISTORY_SUITABLE_FOR_COLLECTOR_DESIGN`.

This validates the supported API boundary for the Telegram session and removes
the need for direct reads of OpenClaw's private SQLite schema. Before
implementation, the same structural rules must be surveyed across the other
completed main-agent session classes (HUD, ACP bridge, Maestro/main) so the
owner-only policy can fail closed where provenance differs.

Batch structural survey over all canonical `status=done` main-agent
sessions completed successfully on 2026-09-26.

Evidence:

- canonical store reported 18 total rows and 12 `status=done` sessions;
- all 12 completed sessions were readable through the supported
  `chat.history` boundary;
- all 12 returned positive owner provenance for every user message:
  `senderIsOwner=true`, with zero false and zero missing owner markers;
- covered session classes were Telegram, HUD, ACP bridge, Maestro and
  `agent:main:main`;
- every surveyed message had stable id/seq/timestamp metadata;
- pagination metadata was present for every surveyed session;
- no truncation/omission signal was observed;
- Telegram additionally demonstrated system/toolResult roles and
  thinking/toolCall blocks, which must remain excluded from memory capture;
- result summary:
  `OWNER_PROVENANCE_PASS=12`, `sessions_read=12`.

The supported API boundary is therefore suitable for a fail-closed v2
collector across the currently observed completed session classes. This does
not authorize production ingestion or memory writes.

Repository-only v2 capture implementation created on the development
branch without touching the production workspace.

New files:

- `tools/memory/mimir-capture-sessions-v2.py`
  (commit `c9369a163266bbea83e2fa693ca4ebdee259a013`);
- `tools/memory/test_mimir_capture_sessions_v2.py`
  (commit `5bf6d25b1468433a61bcdc3a6911f7b1a767b3f0`).

Design implemented:

- source boundary is only supported OpenClaw CLI/API:
  `sessions --json` + `gateway call chat.history`;
- no direct SQLite access, PostgreSQL write, staging write or message-content
  output;
- legacy July collector remains unchanged;
- only surveyed session classes are eligible: Telegram, HUD, ACP bridge,
  Maestro and main;
- non-done sessions and unsupported classes are skipped;
- every user message must carry positive `senderIsOwner=true`; foreign or
  missing provenance blocks the session;
- only user/assistant text enters the normalized candidate transcript;
  system, toolResult, thinking and toolCall material is excluded;
- canonical session UUID/key consistency, bounded pagination, secret scanning,
  truncation/omission detection, source fingerprint and normalized-content
  SHA-256 are implemented;
- synthetic tests cover pagination/owner pass, foreign-owner block,
  missing-owner block, secret block, unsupported/running skip, exclusion of
  internal blocks and truncation block.

Collector v2 isolated validation completed successfully on the VPS without
copying files into the production workspace and without PostgreSQL writes.

Validation evidence:

- isolated checkout:
  `/var/tmp/mimir-capture-v2-validation`;
- exact source guard passed at
  `b8c020805bdf358d5211d8e1cb6b74aed9d2bc96`;
- Python `py_compile`: PASS;
- synthetic suite: 2 tests, PASS;
- live Gateway dry-run completed successfully;
- collector reported:
  `database_write=false`,
  `staging_write=false`,
  `content_exposed=false`,
  `direct_sqlite_access=false`;
- canonical store remained
  `/var/lib/openclaw/.openclaw/agents/main/agent/openclaw-agent.sqlite`;
- 18 session rows were considered;
- result: 12 ready, 0 blocked, 6 skipped, 0 errors;
- all 12 ready sessions correspond exactly to the previously surveyed
  `status=done` set across Telegram, HUD, ACP bridge, Maestro and main;
- the six skipped sessions all had non-eligible `status=unknown`; current
  classes among all rows also include cron and recovered, which are not promoted
  by this result;
- every ready session preserved positive owner provenance with no false/missing
  owner markers, pagination available and no truncation signal;
- Telegram filtering correctly excluded one system message, one toolResult,
  thinking blocks and one toolCall from normalized capture;
- production workspace guard passed: validation checkout was outside
  `/var/lib/openclaw/workspace`.

Checkpoint result:
`MIMIR-CAPTURE-V2-READ-PATH = PASS`.

The v2 collector read path is now validated in isolation against production
OpenClaw data. It is not deployed or scheduled and no write path is authorized.

Post-validation write-path review found an important schema-contract gap
that must be resolved before implementing a production writer.

Existing production function
`mimir.ingest_session(uuid,text,text,integer,integer,integer,bigint,timestamptz)`
is still coupled to the legacy file-backed session model:

- it constructs `source_ref` as
  `agents/main/sessions/<session_id>.jsonl`;
- it requires `p_source_mtime`, which represented the JSONL file mtime;
- its event payload describes the protected source using the legacy ingestion
  contract;
- the validated v2 collector now obtains canonical source data through
  `sessions --json` + `chat.history`, with no JSONL source file and no
  filesystem mtime.

Using the existing function unchanged would therefore create misleading
provenance even though the normalized content itself could be valid. Do not
paper over this by inventing a JSONL path or fake mtime.

A second implementation detail is intentional: the v2 dry-run collector never
prints normalized transcript content, so a future writer must reuse/refactor the
capture logic in-process rather than consume a plaintext transcript from stdout
or an unprotected staging file.

Repository-only v2 ingestion contract has now been implemented but remains
unapplied to production.

New artifacts:

- `docs/SESSION_INGESTION_V2.md`
  defines the API-based provenance model and versioning decision;
- `tools/memory/migrations/014_api_session_ingestion_v2.sql`
  adds explicit source metadata, `mimir.ingest_session_v2(...)`, updates
  `read_consolidation_source` and revokes `mimir_app` EXECUTE on the legacy
  JSONL ingress;
- `tools/memory/validate-session-ingestion-v2-lab.sh`
  is a guarded lab-only validation harness that refuses production database
  names, creates a pre-014 dump, applies/validates 014, tests peer identity,
  idempotency, protected read, class/hash rejection and rollback residue;
- capture v2 now also emits safe provenance metadata
  `source_ref`, `source_updated_at_ms`,
  `source_fingerprint_sha256` and `content_bytes` without exposing content.

Migration numbering decision:

- production remains versions 1..12;
- 013 remains reserved for the independent operational inventory and is not
  renumbered;
- session-ingestion v2 uses version 014 with explicit dependency on memory 012;
- 014 may be validated with or without the reviewed operational 013, but if 13
  is present its description must match the known operational revision exactly;
- 014 never applies/enables `mimir_ops`.

Capture-v2 provenance preflight revalidation completed successfully at the
current branch checkpoint `700f640fb0a2e92be90de7a02459cb2eb02f104c`.

Evidence:

- fresh isolated checkout:
  `/var/tmp/mimir-capture-v2-validation-014-preflight`;
- exact source guard: PASS;
- Python syntax: PASS;
- synthetic suite: 2 tests, PASS;
- live Gateway dry-run: PASS;
- mode remained `dry-run`;
- `database_write=false`;
- `staging_write=false`;
- `content_exposed=false`;
- `direct_sqlite_access=false`;
- 18 canonical session rows considered;
- 12 ready, 0 blocked, 6 skipped, 0 errors;
- ready classes:
  Telegram=1, HUD=3, ACP bridge=6, Maestro=1, main=1;
- all 12 ready sessions carried the new v2 provenance fields and passed
  `v2_provenance_guard`;
- the six skipped sessions remained `status=unknown`;
- production workspace guard passed.

Checkpoint result:
`MIMIR-CAPTURE-V2-014-PREFLIGHT = PASS`.

Migration 014 and its lab harness still have not been executed by this
checkpoint. Production PostgreSQL remains unchanged.

The production-cluster database inventory returned no `mimir_lab*` database.
This is consistent with the archived LAB cleanup: the previous temporary
PostgreSQL cluster was intentionally stopped and removed after LAB-09/bootstrap
validation.

Do not create a lab by cloning production.

Repository-only lab preparation was added instead:

- `tools/memory/prepare-session-ingestion-v2-lab.sh`
  creates a new isolated PostgreSQL 17 cluster under
  `/var/tmp/mimir-pg14-lab`, local Unix socket only, default port 55433;
- it checks production read-only baseline 1..12 and absence of `mimir_ops`;
- it creates an empty `mimir_memory` database inside the isolated cluster;
- it replays the validated canonical memory-v1 bootstrap and migrations
  002..012 from Git;
- it configures only the temporary cluster's peer map so Linux `openclaw`
  authenticates as `mimir_app`;
- it verifies the temporary lab ends at schema versions 1..12 and production
  remains unchanged.

The 014 validator was hardened accordingly:

- default target is the isolated lab database `mimir_memory`;
- default socket is `/var/tmp/mimir-pg14-lab/socket`;
- default port is 55433;
- production socket `/run/postgresql` and port 5432 are explicitly rejected;
- the validator confirms PostgreSQL `data_directory` equals the expected
  `/var/tmp/mimir-pg14-lab/data` before any migration is applied.

First execution of the isolated LAB-014 preparation reached the expected
memory baseline 1..12 but failed at the peer-identity preflight.

Observed result:

- production guard: PASS, versions 1..12 and `mimir_ops=false`;
- isolated PostgreSQL 17 cluster init/start: PASS;
- data directory confirmed:
  `/var/tmp/mimir-pg14-lab/data`;
- empty lab database creation: PASS;
- canonical memory-v1 bootstrap: PASS;
- replay of migrations 002..012: PASS;
- lab schema versions: 1..12;
- failure occurred only when Linux `openclaw` attempted to traverse the Unix
  socket path:
  `Permission denied` on
  `/var/tmp/mimir-pg14-lab/socket/.s.PGSQL.55433`.

Root cause:

- `LAB_ROOT` was mode 0700 owned by postgres;
- although the nested socket directory/socket permissions were broader,
  `openclaw` could not traverse the parent directory;
- this is a filesystem permission issue in the disposable lab only, not a
  PostgreSQL peer/HBA failure and not a production issue.

Repository fix:

- `prepare-session-ingestion-v2-lab.sh` now resolves the Linux primary group of
  `openclaw`;
- `LAB_ROOT` is `postgres:<openclaw-group>` mode 0710;
- the socket directory is `postgres:<openclaw-group>` mode 0770;
- PostgreSQL sets `unix_socket_group` to the openclaw group and
  `unix_socket_permissions=0770`;
- post-start guards verify openclaw traversal and exact socket ownership/mode
  before the peer test.

The failed lab is disposable and stopped progression before migration 014.
Migration 014 has still not been applied anywhere.

Startup diagnosis completed and the exact second-stage socket failure is now
confirmed.

Evidence:

- no lab PostgreSQL server remained running after the failed start;
- PostgreSQL log reported:
  `could not set group of file .../.s.PGSQL.55433: Operation not permitted`;
- `postgres` is uid/gid 70 and belongs only to group `postgres`;
- `openclaw` is uid/gid 998 and belongs only to group `openclaw`;
- LAB_ROOT was already `postgres:openclaw 0710` and the socket directory
  `postgres:openclaw 0770`, so parent traversal was no longer the failure;
- the failing setting was `unix_socket_group=openclaw`: PostgreSQL runs as
  `postgres` and cannot chgrp its socket to a group it does not belong to;
- production remained versions 1..12 and `mimir_ops=false`.

Repository fix:

- no persistent host group membership is changed;
- LAB_ROOT remains `postgres:openclaw 0710`;
- socket directory remains `postgres:openclaw 0770`;
- PostgreSQL socket stays `postgres:postgres` with
  `unix_socket_permissions=0777`;
- access is still restricted by the parent/socket directory boundary, while
  peer + pg_ident enforce `openclaw -> mimir_app`;
- post-start guard now requires `postgres:postgres:777` and verifies
  `openclaw` can access the socket.

Migration 014 has still not been applied anywhere.

Clean rebuild of the isolated LAB-014 baseline completed successfully using
source commit `7815cb4b9d8b62c4d7e64e6e5c2decf15564cfa3`.

Evidence:

- production pre-guard: versions 1..12, `mimir_ops=false`;
- stopped partial lab and stale checkout were removed with exact-path guards;
- fresh checkout source guard: PASS;
- shell syntax: PASS;
- isolated PostgreSQL 17 cluster initialized and started successfully;
- socket permission guard: PASS;
- socket metadata:
  - LAB_ROOT `postgres:openclaw 0710`;
  - socket directory `postgres:openclaw 0770`;
  - Unix socket `postgres:postgres 0777`;
- data directory:
  `/var/tmp/mimir-pg14-lab/data`;
- lab port: 55433;
- canonical memory bootstrap v1: PASS;
- migrations 002..012 replay: PASS;
- lab schema versions: 1..12;
- peer identity:
  `mimir_app|peer:openclaw`;
- independent verification matched the script;
- production post-guard remained versions 1..12.

Checkpoint result:
`MIMIR-V1-MEMORY-014-LAB-BASELINE = PASS`.

The lab is now a disposable production-equivalent memory schema baseline
without production data. Migration 014 has still not been applied anywhere.

LAB-014-01 migration validation completed successfully on the isolated
PostgreSQL lab.

Evidence:

- exact validation source:
  `7815cb4b9d8b62c4d7e64e6e5c2decf15564cfa3`;
- lab baseline before 014: versions 1..12;
- pre-014 custom-format dump created:
  `/var/tmp/mimir_memory-pre014-20260927T025520Z.dump`;
- backup SHA-256:
  `82c9ecc10835f47555ee4770bb7f7533e14b32b6876b6bc3a0dcbb92ffd0e2f4`;
- migration 014 applied with COMMIT in the lab only;
- resulting lab versions: 1..12,14;
- `mimir_app` EXECUTE on `ingest_session_v2`: true;
- `mimir_app` EXECUTE on legacy `ingest_session`: false;
- direct SELECT on `session_sources`: false;
- no-automatic-promotion static guard: PASS;
- peer identity:
  `mimir_app|peer:openclaw`;
- transactional synthetic ingestion: PASS;
- repeated identical ingestion returned the same event: PASS;
- protected consolidation read: PASS;
- unauthorized cron class rejection: PASS;
- content hash mismatch rejection: PASS;
- synthetic rollback residue: zero;
- independent post-014 verification found zero synthetic events/sources;
- production remained versions 1..12, version 14 absent,
  `mimir_ops=false`.

Checkpoint result:
`MIMIR-V1-MEMORY-014-LAB-01 = PASS`.

Migration 014 is validated in an isolated lab but remains unapplied to
production. No writer has been deployed or enabled.

Repository-only controlled writer v2 has now been implemented but has not yet
been executed on the VPS.

New/changed artifacts:

- `mimir-capture-sessions-v2.py` gained an internal-only
  `include_content=True` handoff. Normal CLI behavior remains content-free;
- `mimir-ingest-session-v2.py` implements exact session selection, expected
  source/content fingerprints, dry-run approval digest, explicit
  `--write --approve`, local Unix-socket-only PostgreSQL transport and
  production-socket guard;
- normalized content stays in-process and is base64-encoded only in memory for
  the SQL sent to `psql` via stdin; it is not placed in argv, environment,
  stdout or staging;
- `test_mimir_ingest_session_v2.py` adds synthetic coverage for safe dry-run,
  hash mismatch, owner/secret guard reuse and plaintext-free SQL transport;
- `validate-session-writer-v2-lab.sh` adds an end-to-end synthetic lab path:
  capture metadata → writer dry-run → approval → write → idempotent replay →
  persisted-state/protected-read checks → no automatic memory record → cleanup.

Writer-v2 validation preflight at
`91309ff92dea041f03a66910402bb4fdcc0328c4` passed syntax, the capture-v2
synthetic regression, all four writer-v2 synthetic tests and a live read-only
capture regression (18 considered / 12 ready / 0 blocked / 6 skipped /
0 errors, with no internal content serialized).

The end-to-end writer lab test then stopped before any synthetic write at the
residue precheck. PostgreSQL received the psql placeholder `:'sid'` literally
from a `psql -c` invocation and returned a syntax error. The failure was in
the lab harness, not in the writer, migration 014 or database state.

Repository fix:

- all lab-harness queries that use psql variables for synthetic UUID/hash/key
  values now feed SQL through stdin/heredoc, matching the already working
  psql-variable paths elsewhere in the validators;
- the affected guards are residue precheck, persisted-state boolean guard,
  protected-read guard and post-cleanup residue guard;
- the failure occurred before writer dry-run/write, so no synthetic session
  was inserted and the existing 1..12,14 lab can be reused.

The corrected writer-v2 end-to-end lab validation completed successfully.

Evidence:

- source guard at `a0d3234905143a34dbd407af281cfd7433484ad0`: PASS;
- lab baseline remained versions 1..12,14;
- production baseline remained versions 1..12;
- synthetic residue precheck: zero;
- capture metadata path: PASS;
- writer dry-run: PASS;
- approval digest generated:
  `2b244312ca6fb6df8cdf094e65a7495a05351f8630f0bc495d95d161fb2ad1dc`;
- controlled synthetic writer commit: PASS;
- synthetic event id:
  `79342b0e-8490-4ce6-8976-8c7adf07e247`;
- idempotent replay returned the same event id: PASS;
- persisted source provenance: PASS;
- persisted event classification/protection flags: PASS;
- automatic memory records: zero;
- protected consolidation read: PASS;
- synthetic cleanup deleted exactly one source and one event;
- independent residue verification after cleanup: zero sources/events;
- final production guard:
  versions 1..12, version14=false, `mimir_ops=false`.

Checkpoint result:
`MIMIR-V1-MEMORY-WRITER-V2-LAB-01 = PASS`.

The writer v2 is now validated end to end in the isolated lab. It remains
undeployed and migration 014 remains unapplied to production.

Local-model read-only inventory on the VPS completed.

Observed runtime:

- OpenRC `openclaw` service: started;
- local `llama-server` is running as Linux user `openclaw`;
- model:
  `/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf`;
- observed runtime bind:
  `127.0.0.1:8080`;
- this is **not** the canonical VPS fallback port. The established Mímir port
  map is: PcIA CUDA llama.cpp `18781`, VPS CPU fallback `18782`, OpenClaw
  Gateway `18789`;
- therefore the 8080 listener is runtime/configuration drift to diagnose, not
  an endpoint to standardize in the architecture;
- launch parameters include:
  `--ctx-size 4096 --threads 6 --parallel 1 --jinja`;
- OpenClaw Gateway listens on `127.0.0.1:18789`;
- HUD listens on `127.0.0.1:18880`;
- known historical/local-model ports 8601, 18781 and 18782 were closed;
- `/v1/models` on 18789 returned an unexpected/non-model response, confirming
  that 18789 must not be treated as the local model API;
- production PostgreSQL remained versions 1..12 and version14=false.

A later synthetic probe showed `/health` and `/v1/models` responding on the
observed 8080 listener, but that does not make 8080 canonical. The chat probe
itself was inconclusive because the validation command incorrectly combined a
pipe with a Python heredoc, so Python consumed the heredoc as stdin and could
not read the curl response. Do not infer a chat API failure from that result.

Before any consolidator work, diagnose why the VPS `mimir-llama` service is
starting with `--port 8080` instead of the established fallback port 18782.
Do not change production runtime until that drift is understood and explicitly
authorized.

Conversational security architecture is now versioned as a proposal for
Projeto Mímir only:

- `docs/CONVERSATIONAL_SECURITY.md`;
- `docs/AI_SECURITY_TEST_MATRIX.md`;
- no runtime policy or production permission changed.

Design gap: the proposed security-oriented memory classes do not directly match
the current Mímir `memory_type` values. Define an explicit mapping or schema
extension before changing the database.

Port-drift diagnosis completed.

Observed source of the VPS llama.cpp drift:

- `/etc/init.d/mimir-llama` is parameterized and uses
  `--port ${listen_port}`;
- `/etc/conf.d/mimir-llama` explicitly sets
  `listen_port="8080"`;
- the running process therefore receives `--port 8080`;
- the actual listener is `127.0.0.1:8080`;
- canonical Mímir port map remains:
  PcIA CUDA=18781, VPS CPU fallback=18782, OpenClaw Gateway=18789;
- production PostgreSQL remained versions 1..12 and version14=false.

Root cause: configuration drift in `/etc/conf.d/mimir-llama`, not an
architectural decision and not a llama.cpp API limitation.

Runtime port correction completed on the VPS:

- `/etc/conf.d/mimir-llama` changed from `listen_port="8080"` to
  `listen_port="18782"`;
- only `mimir-llama` was restarted via OpenRC;
- service status returned started;
- running `llama-server` now receives `--port 18782`;
- listener `127.0.0.1:18782` is present;
- no 8080 listener appeared in the validation output;
- OpenClaw Gateway remains on 18789;
- the first immediate probes to `/health` and `/v1/models` returned HTTP
  payload `503 Loading model`, so the port correction is complete but model
  readiness has not yet been confirmed.

Canonical VPS llama endpoint validation progressed:

- `/health` on `127.0.0.1:18782`: HTTP 200, `status=ok`;
- `/v1/models`: PASS and identifies
  `/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf`;
- synthetic `/v1/chat/completions`: HTTP 200 with
  `object=chat.completion` and role=assistant;
- however the first synthetic completion ended with
  `finish_reason=length` and `content` length 0, so transport/API shape is
  validated but usable textual completion is not yet proven;
- canonical listener `127.0.0.1:18782`: PASS;
- legacy 8080 listener absent: PASS;
- OpenClaw Gateway remains on 18789;
- production PostgreSQL remained versions 1..12 and version14=false.

The empty content must not be treated as a successful model-answer validation.
Qwen/llama.cpp may be consuming the small token budget in a reasoning field, but
that is only a hypothesis until the synthetic response structure is inspected.

Qwen chat-mode diagnosis completed on the canonical VPS endpoint
`127.0.0.1:18782`.

Evidence:

- normal/default mode: HTTP 200, `finish_reason=stop`;
- response message exposed both `content` and `reasoning_content`;
- normal-mode `content`: 36 chars;
- normal-mode `reasoning_content`: 947 chars;
- normal-mode usage: 24 prompt + 236 completion = 260 total tokens;
- request-local `chat_template_kwargs.enable_thinking=false`: HTTP 200,
  `finish_reason=stop`;
- direct-mode message contained only `content` + `role`;
- direct-mode `content`: 36 chars;
- direct-mode usage: 28 prompt + 11 completion = 39 total tokens;
- direct-mode content was valid JSON exactly matching the synthetic contract:
  `{"status":"ok","source":"synthetic"}`;
- listener guard remained 18782 for llama.cpp and 18789 for OpenClaw Gateway;
- no runtime configuration change was required for thinking mode.

Checkpoint result:
`MIMIR-V1-LOCAL-LLAMA-18782-CHAT-01 = PASS`.

Design decision for the future protected-session consolidator:

- use the canonical VPS endpoint `127.0.0.1:18782`;
- set `chat_template_kwargs.enable_thinking=false` per request for structured
  consolidation;
- parse/persist only assistant `content`;
- never persist, expose or treat `reasoning_content` as candidate memory;
- require strict JSON output and fail closed on empty/invalid content.

Conversational-security current-state gap inventory is now versioned at
`docs/AI_SECURITY_GAP_INVENTORY.md`.

The inventory classifies controls as EXISTING_VALIDATED, PARTIAL, PROPOSED,
MISSING or OUT_OF_SCOPE_NOW and identifies the protected-session consolidator
as the first component that must carry the new untrusted-content contract.

Important design direction recorded, not yet implemented:

- keep semantic memory type separate from trust/validation class;
- do not silently rename current `memory_type` values;
- prefer a separate trust/validation dimension or explicit metadata after ADR;
- no production schema change is authorized.

The protected-session local consolidator contract is now versioned at
`docs/PROTECTED_SESSION_CONSOLIDATOR_V1.md`.

The contract fixes:

- canonical loopback endpoint `127.0.0.1:18782`;
- Qwen structured mode with `enable_thinking=false`;
- `message.content` as the only persistable model field;
- `reasoning_content` never persisted/logged/promoted;
- source read only through `mimir.read_consolidation_source(event_id)`;
- source trust=`UNTRUSTED_CONTENT`;
- output trust starts as `UNTRUSTED_OBSERVATION`;
- strict JSON schema, unknown-field rejection and source/hash binding;
- output secret gate outside the LLM;
- dry-run only, no candidate/active write, no tools, no external API;
- first adversarial set:
  T-AI-002/005/023/024/032/033/034.

No production schema/runtime change was made by this contract.

Historical next executable action, now implemented repository-only:

1. implement the repository-only consolidator in dry-run mode from this contract;
2. add a fake loopback model harness and synthetic protected-source fixture;
3. enforce endpoint allowlist, source/hash binding, strict output schema and
   secret/output checks outside the model;
4. prove no tool use, no external egress, no reasoning persistence and no
   automatic memory promotion;
5. execute the first T-AI battery on the synthetic harness;
6. only after those pass, validate against the isolated PostgreSQL 1..12,14 lab
   and the real local model using synthetic content;
7. production remains schema 1..12; migration 014/writer/consolidator are not
   deployed.


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


## CURRENT CHECKPOINT — PROTECTED CONSOLIDATOR REPOSITORY

Date: 2026-09-27

State: `REPOSITORY_VALIDATED`

Implementation base commits:

- `354aef9bf8a5381c5c7b5e0ee3f9baa1e3cd3ca5` — protected consolidator v1;
- `4753941c846fa2b35893c38dfb4c1383b37e28c4` — adversarial synthetic harness;
- `6b2801bfa2f71375940ac28f643fad3a4344e712` — repository validator.

Evidence document:

`docs/review/operations/2026-09-27-protected-consolidator-v1.md`

Implemented controls:

- protected source read only through
  `mimir.read_consolidation_source(event_id)`;
- confidential source required;
- event/source binding checked;
- local model endpoint fixed to `127.0.0.1:18782`;
- external host/port/path rejected;
- proxy and redirect disabled;
- model id fixed to the validated Qwen local model;
- `enable_thinking=false`;
- only `message.content` is processed;
- `reasoning_content` is ignored and never emitted;
- no tools are supplied and model tool calls are rejected;
- closed output schema;
- source event/hash binding;
- `UNTRUSTED_CONTENT` input;
- `UNTRUSTED_OBSERVATION` output;
- human review cannot be disabled;
- secret/output gate is outside the LLM;
- no candidate/active/database write path exists in this consolidator.

Formal repository validation completed on 2026-09-27.

Validated HEAD:

`3d119d4a8308c1dbaf9744c9f3c7f3b77a5a8c64`

Result:

`MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01 = PASS`

Evidence:

- clean worktree before execution;
- 8/8 adversarial repository tests passed;
- validator returned RC=0;
- test model executed in an isolated network namespace;
- host llama.cpp remained listening on `127.0.0.1:18782` before and after;
- no production PostgreSQL access;
- no migration, deployment or runtime modification occurred.

Repository controls T-AI-002/005/023/024/032/033/034 are validated for this
repository-only checkpoint.

Production remains unchanged:

- PostgreSQL production remains schema 1..12;
- migration 014 remains unapplied in production;
- writer v2 remains undeployed;
- protected consolidator remains undeployed;
- no real session was used;
- no production source was read;
- no equipment authorization was widened.

## NEXT_ACTION

1. prepare or reuse the isolated PostgreSQL laboratory at schema 1..12,14;
2. confirm the laboratory cannot resolve to the production PostgreSQL socket,
   port or data directory;
3. validate the protected consolidator against that isolated laboratory and
   the real local Qwen endpoint `127.0.0.1:18782`;
4. use only fully synthetic protected content;
5. do not use a real session;
6. do not access production PostgreSQL;
7. do not deploy migration 014, writer v2 or protected consolidator;
8. preserve human review and zero automatic promotion;
9. keep PR #1 Draft and unmerged.

## CURRENT CHECKPOINT — PROTECTED CONSOLIDATOR REAL-MODEL LAB

Date: 2026-09-27

State: `BLOCKED_BY_MODEL_TIMEOUT`

Current technical HEAD:

`9e2e1c13e76cc60e4b383cc0898b54aeef2bcef0`

Current consolidator SHA-256:

`45e68e31df5cf71f8e1253d28d2ef8f08cda39c2e1e0a497cd3940cf935b5a66`

Repository regression after PostgreSQL Base64 normalization:

- 8/8 tests PASS;
- RC=0;
- host llama.cpp remained active on `127.0.0.1:18782`.

The isolated PostgreSQL LAB is operational again after WAL recovery:

- data directory: `/var/tmp/mimir-pg14-lab/data`;
- socket: `/var/tmp/mimir-pg14-lab/socket/.s.PGSQL.55433`;
- schema versions: `1..12,14`;
- TCP disabled;
- peer identity: `openclaw -> mimir_app -> peer:openclaw`.

Real-model LAB attempt 1 exposed PostgreSQL Base64 line wrapping.
That defect was fixed in commit `9e2e1c13...`.

Real-model LAB attempt 2 advanced past protected source decoding and failed
during the local-model interaction.

Diagnostic result:

`TimeoutError: timed out`

Cleanup result:

`synthetic_residue=0`

Production remains unchanged:

- PostgreSQL production remains 1..12;
- migration 014 remains unapplied;
- writer v2 remains undeployed;
- consolidator remains undeployed;
- no real session was used;
- no automatic memory promotion occurred.

Evidence:

- `docs/review/operations/2026-09-27.md`
- `docs/review/operations/2026-09-27-protected-consolidator-real-model-lab.md`

## NEXT_ACTION — MODEL TIMEOUT

1. add explicit HTTP/model timeout handling to the protected consolidator;
2. add repository-only regression coverage for timeout;
3. rerun the repository validator;
4. measure Qwen 18782 latency independently with an equivalent synthetic request;
5. determine whether the cause is cold start, generation latency, context size or stall;
6. do not increase the timeout merely to obtain PASS;
7. only then repeat the integrated LAB;
8. preserve synthetic-only content and `synthetic_residue=0`;
9. keep production and real sessions out of scope.


## CHECKPOINT — MODEL TIMEOUT HANDLING VALIDATED

Date: 2026-09-27

State: REPOSITORY_VALIDATED

Technical HEAD:

28be68ea1dcccb74e74d16fe49a4943a1d316947

Result:

- explicit local-model TimeoutError handling implemented;
- timeout fails closed through controlled consolidator error;
- dedicated timeout regression test added;
- repository validator: 9/9 PASS;
- VALIDATOR_RC=0;
- validation executed in isolated network namespace;
- real Qwen on 127.0.0.1:18782 remained untouched and active;
- PostgreSQL production remains unchanged.

NEXT_ACTION:

Measure Qwen 18782 latency with an equivalent fully synthetic request.
Do not increase the consolidator timeout before obtaining latency evidence.
After measurement, decide whether the issue is cold start, generation latency,
context size or model stall.


## CHECKPOINT — MODEL TIMEOUT HANDLING VALIDATED

Date: 2026-09-27

State: REPOSITORY_VALIDATED

Technical HEAD:

e62b2eed018fb3c9d5c9b499abce15ce66828667

Result:

- explicit local-model TimeoutError handling implemented;
- timeout fails closed through controlled consolidator error;
- dedicated timeout regression test added;
- repository validator: 9/9 PASS;
- VALIDATOR_RC=0;
- validation executed in isolated network namespace;
- real Qwen on 127.0.0.1:18782 remained untouched and active;
- PostgreSQL production remains unchanged.

NEXT_ACTION:

Measure Qwen 18782 latency with an equivalent fully synthetic request.
Do not increase the consolidator timeout before obtaining latency evidence.
After measurement, decide whether the issue is cold start, generation latency,
context size or model stall.

## CHECKPOINT — QWEN LATENCY CHARACTERIZED

Date: 2026-09-27

State: `LATENCY_CHARACTERIZED`

Qwen real `127.0.0.1:18782` respondeu HTTP 200 de forma repetível.

Observed:

- first probe: 44.351 s;
- warm runs: 32.324 / 30.927 / 32.104 s;
- warm average: ~31.78 s;
- prompt: 342 tokens;
- completion: 190 tokens;
- finish_reason=stop;
- enable_thinking=false.

Interpretation:

The local CPU model is slow but stable for this payload. There is no evidence
of a persistent model stall. The current evidence does not justify changing
the consolidator timeout yet.

NEXT_ACTION:

Capture/measure the exact integrated synthetic LAB request and its model
generation characteristics before changing timeout or model policy.

## CHECKPOINT — MODEL TIMEOUT ROOT CAUSE CONFIRMED

Date: 2026-09-27

State: `ROOT_CAUSE_CONFIRMED`

Exact LAB request SHA-256:

`cb0a746384552ad20728a2cf6de5148bcd6045e68d5c5ba29db6c8868426f413`

After 90 seconds idle, Qwen 18782 processed the exact request in:

`71.535960 s`

with HTTP 200.

The integrated harness explicitly uses a 60-second timeout.

Root cause:

Qwen CPU cold/idle inference latency can exceed the current 60-second model
timeout.

NEXT_ACTION:

Design separate PostgreSQL and model timeout budgets. Preserve fail-closed
behavior and do not weaken model/output security policy.


## CHECKPOINT — MODEL TIMEOUT SPLIT VALIDATED

Date: 2026-09-27

State: `REPOSITORY_VALIDATED`

Technical HEAD:

`8b04510fc693442ae94d0487581d942d5ae9319e`

Validated:

- PostgreSQL and model inference timeout budgets separated;
- PostgreSQL maximum remains 60 s;
- model timeout default is 120 s and maximum is 180 s;
- fail-closed timeout handling preserved;
- repository suite: 10/10 PASS.

NEXT_ACTION:

Run the isolated synthetic real-model LAB with
`--model-timeout-seconds 120`.

## CHECKPOINT — REAL MODEL OUTPUT SCHEMA REJECTED

Date: 2026-09-28

State: `OUTPUT_SCHEMA_DIAGNOSTIC_REQUIRED`

The integrated synthetic LAB reached Qwen successfully using the 120-second
model timeout.

Qwen returned, but the protected validator rejected the response fail-closed:

`ERRO[POLICY_REJECT]: schema de saída possui campos ausentes ou desconhecidos`

Cleanup:

`synthetic_residue=0`

VPS Qwen remains the CPU fallback at `127.0.0.1:18782`.

NEXT_ACTION:

Inspect safe structural metadata from the synthetic model response only.
Do not relax the closed schema.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-SCHEMA-DIAG-01

Date: 2026-09-28

Status: `BLOCKED`

Branch:

`feat/mimir-operational-foundation`

Source HEAD:

`7d79c02efa92597fb1e927f27b9c7715ef0a4fa8`

Current blocker:

`REAL_MODEL_OUTPUT_SCHEMA_MISMATCH`

Observed real-model top-level keys:

`schema_version,source_bindings`

Required top-level contract:

`schema_version,source_event_id,source_content_sha256,candidates`

Validated capability:

The deployed `llama-cpp-0_pre9888` endpoint at
`127.0.0.1:18782` supports strict `response_format=json_schema`
with `additionalProperties=false`.

Decision:

- do not relax the existing Python validator;
- replace ambiguous prompt wording;
- constrain generation with a closed JSON Schema;
- keep Python validation as an independent second fail-closed barrier.

Production remains unchanged.

VPS CPU Qwen remains fallback. PcIA GPU remains the planned primary inference
target.

NEXT_ACTION:

Implement the closed JSON Schema and repository-only regression tests.
Do not repeat the integrated LAB until repository-only validation passes.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-JSON-SCHEMA-REPO-01

Date: 2026-09-28

Status:

`REPOSITORY_ONLY_PASS`

Branch:

`feat/mimir-operational-foundation`

Technical commit:

`39b09e92b2355573105d3613ba84dab9267cf0a1`

### Implemented

Protected Qwen generation now uses a closed JSON Schema.

The model-side schema fixes:

- `schema_version=1`;
- exact `source_event_id`;
- exact `source_content_sha256`;
- closed `candidates`;
- closed candidate fields;
- closed evidence fields;
- trust class fixed to `UNTRUSTED_OBSERVATION`;
- human review fixed to `true`.

The ambiguous `requested source bindings` wording was removed.

The existing Python validator remains unchanged as the independent second
fail-closed barrier.

### Repository validation

PASS:

- diff check;
- Python syntax;
- JSON Schema repository contract;
- existing protected suite: 10/10 PASS in isolated network namespace.

### Production

Unchanged.

No deploy, migration, production database change, real content use or memory
promotion occurred.

### Important state distinction

Repository validation is complete.

Integrated real-model LAB validation is NOT complete yet.

### NEXT_ACTION

Run the disposable integrated synthetic LAB against real Qwen on
`127.0.0.1:18782` using technical commit
`39b09e92b2355573105d3613ba84dab9267cf0a1`.

Require `synthetic_residue=0`.

Do not deploy.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-JSON-SCHEMA-01

Date: 2026-09-28

Status:

`FAIL`

Branch:

`feat/mimir-operational-foundation`

Technical commit under validation:

`39b09e92b2355573105d3613ba84dab9267cf0a1`

Artifact SHA-256:

`05f18e59ff35c8d5dca6f4e206771e59c6df9abca9bafd9b341fcb9129c699bd`

Integrated synthetic LAB reached the real-model stage but failed closed with:

`ERRO[POLICY_REJECT]: timeout ao acessar modelo local`

The model timeout budget was 120 seconds.

All stages before inference passed.

Cleanup:

`synthetic_residue=0`

Important:

This run did NOT reach output-schema validation. Therefore it does not prove
that the new JSON Schema succeeds or fails against the integrated request.

The repository-only state remains PASS. Integrated real-model validation
remains FAIL.

Production remains unchanged.

NEXT_ACTION:

Diagnose the Qwen CPU fallback runtime and measure a small strict JSON Schema
request before authorizing another integrated LAB run.

Do not change the validator, JSON Schema or timeout yet.

### Diagnostic update — real-model timeout characterization

Small strict JSON Schema probe against the same Qwen endpoint:

- HTTP 200;
- 4.392 s wall time;
- prompt_tokens=37;
- completion_tokens=7;
- finish_reason=stop;
- valid constrained output.

Conclusion:

The runtime and JSON Schema mechanism are healthy for a small request.
The remaining blocker is specific to the full integrated consolidator request.

NEXT_ACTION:

Profile the exact synthetic integrated request size and latency before changing
the 120-second model budget.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-LATENCY-01

Date: 2026-09-28

Status:

`BLOCKED`

Technical commit:

`39b09e92b2355573105d3613ba84dab9267cf0a1`

### Integrated real-model result

With a diagnostic 180-second budget, the exact protected consolidator flow
completed successfully against real Qwen.

- consolidator: PASS;
- output contract: PASS;
- candidates: 2;
- automatic promotion: 0;
- cleanup: `synthetic_residue=0`.

Full model elapsed time:

`136.530 seconds`

Request size:

`2928 bytes`

JSON Schema size:

`1227 bytes`

### Root cause

The canonical 120-second model budget is insufficient for the current VPS CPU
fallback.

JSON Schema itself is validated against the real model and must not be
relaxed.

### State distinction

- repository-only validation: PASS;
- integrated schema/contract validation: PASS at diagnostic 180 s;
- canonical 120 s runtime policy: FAIL;
- deployment: NOT AUTHORIZED;
- production validation: NOT DONE.

### NEXT_ACTION

Inspect timeout references in the repository and define the scoped CPU
fallback timeout policy before changing code or deployment configuration.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-TIMEOUT-POLICY-DESIGN-01

Date: 2026-09-28

Status: `DESIGN_COMPLETE`

Source HEAD:

`ad0964d8c94e73de0058a142a9d7482efa45ec3f`

Decision:

- keep generic model timeout default at 120 s;
- keep maximum at 180 s;
- use explicit 180 s only for the current VPS CPU fallback real-model LAB.

Repository inspection found no versioned integrated real-model LAB harness and
no executable versioned timeout override for that LAB.

The existing versioned shell validator is repository-only:

`tools/memory/validate-protected-consolidator-v1-repository.sh`

NEXT_ACTION:

Inspect the repository validator and validated disposable LAB harness, then
create a reproducible versioned real-model LAB harness with explicit
`--model-timeout-seconds 180`.

No deploy.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-STAGING-DESIGN-01

Status: `DESIGN_COMPLETE`

Source HEAD:

`e236460bc1c9d3def3f3e3412141887765794792`

`openclaw` cannot traverse `/home/jarvisdev` or
`/home/jarvisdev/projects` because both are private (0700).

Decision:

Do NOT change those permissions.

The versioned real-model LAB harness must run as root and stage only required
Git-controlled artifacts into a private disposable `/var/tmp` directory with
minimal permissions for `openclaw`.

The checkout remains the source of truth. `/var/tmp` is execution staging
only.

NEXT_ACTION:

Inspect capture/writer local dependencies before implementing the staged
real-model LAB harness.

## CHECKPOINT — MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-PASS-01

Date: 2026-09-29

Status: `PASS`

Validated commit:

`072397bd05a0f5e4a806fed4c403a7aab7a4abdb`

The versioned protected real-model LAB completed successfully end-to-end.

Evidence:

- repository regression suite: 10/10 PASS;
- JSON Schema contract: PASS;
- PostgreSQL LAB isolated;
- Qwen VPS CPU fallback healthy;
- real consolidator RC=0;
- output contract PASS;
- candidate_count=2;
- all generated candidates require human review;
- automatic_records=0;
- synthetic_residue=0;
- LAB_RC=0.

Timeout policy remains:

- generic default: 120 s;
- maximum: 180 s;
- explicit VPS CPU fallback LAB: 180 s.

Protected consolidator blocker: CLOSED.

NEXT_ACTION:

Resume the next incomplete functional milestone from
`docs/MIMIR_V1_EXECUTION_PLAN.md`.

Do not continue timeout diagnostics unless a regression appears.

## MIMIR-V1-P1-MEMORY-DEDUP-CONTRADICTION-01

Date: 2026-09-29

Status: `PASS`

The first four P1 permanent-memory milestones are now validated:

- controlled session writer: PASS;
- protected local session consolidation end-to-end: PASS;
- candidate deduplication: PASS;
- deterministic candidate contradiction detection: PASS.

Deduplication evidence:

- validator commit: `540f78fac64a75045d09abd5beba8ea2b12198d8`;
- identical source/key/content replay returned the same `memory_id`;
- identical record count remained 1;
- different content remained distinct;
- different source remained distinct;
- different `memory_key` remained distinct;
- propose audit was not duplicated;
- duplicate groups: 0;
- automatic promotion: 0;
- synthetic residue: 0;
- production unchanged.

Contradiction implementation/evidence:

- implementation commit: `8b47a2161b54f2889f6f3f494fa97486af32ab63`;
- LAB hardening: `d60137fe74d2469be2c9786e63f9c6b7cc8807a2`;
- negative-test fix: `10d3995e6d51329ca00a382bd622e2f545cf8132`;
- migration `015_memory_contradiction_detection.sql`;
- LAB schema: `1..12,14,15`;
- production schema: `1..12`;
- duplicate classification: PASS;
- contradiction classification: PASS;
- no-conflict classification: PASS;
- non-candidate rejection: PASS;
- detector writes: 0;
- candidate status preserved;
- migration 015 absent from production;
- synthetic residue: 0;
- LAB RC: 0.

The contradiction detector is intentionally read-only. It classifies a
candidate against the active memory with the same
`scope_type + scope_key + memory_key` as:

- `none`;
- `duplicate`;
- `contradiction`.

It does not promote, reject, supersede, create relations or expose memory
content.

NEXT_ACTION:

Validate authenticated human review and the controlled
`candidate -> active` transition in the isolated PostgreSQL LAB.

The validation must preserve peer-authenticated reviewer provenance, verify
approve/reject behavior and idempotency, reject unauthorized review, confirm
audit records, and leave production unchanged.

Do not apply migration 015 to production.

## MIMIR-V1-P1-HUMAN-REVIEW-ACTIVE-01

Date: 2026-09-29

Status: `PASS`

Authenticated human review and the controlled
`candidate -> active` transition were validated end-to-end in the isolated
PostgreSQL LAB.

Implementation/evidence:

- validator implementation:
  `4f0b51d2346b25981071fdfccc9dce4a305e327c`;
- LAB socket-context correction:
  `c2a5d877e315bb25b2fcf63b54828e997b25e297`;
- LAB schema: `1..12,14,15`;
- production schema: `1..12`;
- reviewer identity contract: PASS;
- reviewer role contract: PASS;
- Unix LAB access context: PASS;
- peer identity:
  `mimir_human|mimir_human|peer:nogueiramaier`;
- controlled role elevation:
  `mimir_human|mimir_reviewer|peer:nogueiramaier`;
- direct review from `mimir_app`: rejected;
- direct review from `mimir_human` without role elevation: rejected;
- human approve: PASS;
- `candidate -> active`: PASS;
- approve replay idempotency: PASS;
- human reject: PASS;
- reject replay idempotency: PASS;
- opposite-decision replay: rejected;
- second active memory for the same identity: rejected;
- conflicting candidate remained `candidate`;
- reviewer provenance: PASS;
- review audit: PASS;
- review-row idempotency: PASS;
- final synthetic states:
  `active|rejected|candidate`;
- automatic relations: 0;
- production unchanged;
- production migration 015: absent;
- temporary LAB `pg_ident.conf` restored;
- synthetic residue: 0;
- LAB RC: 0.

No persistent Linux user/group change was required. The existing Linux identity
`nogueiramaier` was executed with the LAB socket access group only for the
disposable validation process. PostgreSQL peer authentication still observed
`peer:nogueiramaier`.

NEXT_ACTION:

Validate controlled embedding generation and semantic retrieval after a
human-approved promotion.

The next LAB must prove:

- only `active` memory becomes embedding-eligible;
- 768-dimensional EmbeddingGemma vector is generated locally;
- controlled write uses `mimir_embedder`;
- content SHA guard is enforced;
- embedding audit is persisted;
- semantic query uses `mimir_search` with `peer:openclaw`;
- the promoted synthetic memory is retrieved;
- rejected/candidate memories are not returned;
- production remains unchanged;
- all synthetic records are removed.

Do not apply migrations 014 or 015 to production.

## MIMIR-V1-P1-EMBEDDING-SEMANTIC-AUDIT-01

Date: 2026-09-29

Status: `PASS`

Controlled local embedding generation, semantic retrieval after human
promotion, and end-to-end provenance/audit were validated in the isolated
PostgreSQL LAB.

Technical commits:

- initial embedding/semantic LAB:
  `2bb32d128c430e98a1e88059b8d76ef2c675754a`;
- private LAB artifact staging:
  `a7dd91d85788cb93452471b49d605ee277423fd1`;
- managed embedding service migration:
  `9e88393a4b83fd9b48e8ca3b43d10402db846332`;
- exact managed llama-server embedding contract:
  `11c2fd979c758201d122c4512de3f4b17b94508d`;
- boolean assertion correction:
  `41735fe4b1c703fcc21f31f9ab03644daa23bf25`.

Validated runtime contract:

- OpenClaw: `2026.9.5`;
- managed embedding listener:
  `127.0.0.1:8601`;
- embedding runtime model id:
  `embeddinggemma-300m-qat-q8_0`;
- canonical PostgreSQL embedding model identity:
  `hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf`;
- real embedding dimensions: 768;
- real embedding norm: approximately 1.0.

Final LAB evidence:

- LAB schema: `1..12,14,15`;
- production schema: `1..12`;
- `mimir_embedder|peer:openclaw`: PASS;
- `mimir_search|peer:openclaw`: PASS;
- human promotion/rejection state: PASS;
- only `active` memory eligible for embedding: PASS;
- real embedding dry-run: PASS;
- real controlled embedding write: PASS;
- embedding dimensions 768: PASS;
- embedding L2 normalization: PASS;
- rejected memory remained unembedded;
- candidate memory remained unembedded;
- content SHA guard: PASS;
- embedding audit: PASS;
- real query embedding 768D: PASS;
- promoted memory semantic retrieval: PASS;
- rejected memory excluded from semantic results;
- candidate memory excluded from semantic results;
- semantic source provenance: PASS;
- end-to-end provenance: PASS;
- end-to-end audit: PASS;
- production unchanged;
- production migration 015 absent;
- temporary LAB `pg_ident.conf` restored;
- synthetic residue: 0;
- LAB RC: 0.

Failure/correction chronology preserved:

1. The initial LAB could not execute repository artifacts as Linux `openclaw`
   because `/home/jarvisdev` was intentionally not traversable. No host HOME
   permissions were widened. Required versioned scripts were staged privately
   under `/var/tmp` for the disposable LAB.

2. The staged generator exposed a legacy dependency on in-process
   `node-llama-cpp` and failed with `MODULE_NOT_FOUND`. The dependency was not
   installed. The generator was migrated to the OpenClaw managed llama-server
   architecture already used by `mimir-memory 0.2.7`.

3. A direct HTTP attempt initially failed because the managed provider lifecycle
   had not yet been acquired for that runtime moment. Direct
   `tools.invoke(mimir_memory_search)` successfully acquired the provider and
   produced a real 768-dimensional embedding.

4. The first manual managed-server request returned HTTP 400 because it used
   the canonical Hugging Face source URI as the runtime `model` value. Inspection
   of OpenClaw 2026.9.5 showed that the managed llama-server expects runtime id
   `embeddinggemma-300m-qat-q8_0`, an input array and 768 dimensions. The
   canonical HF identity remains the value persisted in PostgreSQL.

5. The first controlled-write retry successfully produced all three expected
   boolean conditions, but PostgreSQL concatenation rendered them as
   `true|true|true` while the harness expected `t|t|t`. The assertion was
   corrected without changing database semantics. The same correction was
   applied proactively to the final end-to-end provenance assertion.

No migration 014 or 015 was applied to production.

NEXT_ACTION:

Integrate `memory_handoff` operationally with the already validated human memory
workflow.

The integration must preserve:

- no automatic promotion;
- candidate-first semantics;
- human-authenticated review;
- deduplication and contradiction checks;
- provenance from handoff source through review;
- embedding only after human promotion;
- semantic visibility only after promotion;
- fail-closed behavior on malformed/untrusted handoff content;
- production unchanged until separately authorized.


## MIMIR-V1-P1-MEMORY-HANDOFF-01

Date: 2026-09-29

Status: `PASS`

The operational `memory_handoff` v1 path is implemented and validated end to
end in the isolated PostgreSQL LAB. This closes the ninth and final item of
P1 — Permanent PostgreSQL Memory.

Technical commit chain since the previous memory checkpoint:

- `071867e209b537defa81b4409edd19cf599851c1` — feat(memory): integrate operational memory handoff
- `f53ebc1043f76009c2e0df43ad61254af3b75d5b` — test(memory): validate operational handoff integration
- `640a77373b4dfe749cc952020098279104e219a9` — fix(memory): use stdin for handoff lab psql vars
- `3b78044c2290484af864015b2568cae03d836b4d` — fix(memory): observe handoff candidate sequentially
- `cdbda3a72784ad5f710b8fde80dd8e5f649340b8` — fix(memory): stage handoff params before plpgsql
- `1df8487475abf67f6a8a1e2cfb5bc6e4e4eedf87` — fix(memory): preserve handoff least privilege boundary

Final LAB topology and guards:

- LAB schema: `1..12,14,15,16`;
- production schema: `1..12`;
- migration 016 applied only to LAB;
- production migrations 014, 015 and 016: absent;
- `mimir_app|peer:openclaw`: PASS;
- `mimir_embedder|peer:openclaw`: PASS;
- `mimir_search|peer:openclaw`: PASS;
- producer: real `ops_workflow.memory_handoff()`;
- handoff contract state: `pending_human_review`;
- handoff classification: `confidential`;
- `automatic_promotion=false`.

Final integrated evidence:

- real producer contract: PASS;
- malformed handoff fail-closed: PASS;
- malformed handoff database writes: 0;
- consumer dry-run: PASS;
- confidential event ingestion: PASS;
- candidate-first semantics: PASS;
- deterministic contradiction inspection: PASS;
- replay idempotency: PASS;
- deduplication: PASS;
- source/report SHA provenance: PASS;
- embedding before human review: BLOCKED;
- semantic visibility before human review: BLOCKED;
- authenticated human review: PASS;
- `candidate -> active`: PASS;
- embedding only after human promotion: PASS;
- EmbeddingGemma dimensions: 768;
- semantic visibility after review: PASS;
- operational handoff semantic retrieval: PASS;
- end-to-end provenance: PASS;
- end-to-end audit: PASS;
- automatic relations: 0;
- automatic promotion: false;
- production unchanged;
- temporary LAB `pg_ident.conf` restored;
- synthetic residue after cleanup: 0;
- final LAB RC: 0.

Synthetic evidence hashes:

- report SHA-256:
  `ae810b4261bc9ba6b269014cbd8bc8ba51a0f9a2b4e79b4d4ef5d619fd3346e1`;
- canonical handoff SHA-256:
  `7067940ba04f0ee8da86db6a102d9dac3c12ee1b2cbbf6ea7b6547780438aaab`.

Failure/correction chronology preserved:

1. The first integrated run exposed psql variable substitution inside `-c`.
   The harness was corrected to feed variable-bearing SQL through stdin.
   Cleanup restored `pg_ident.conf` and left zero synthetic residue.

2. The next run created the memory but the same SQL statement inferred
   `not_pending`. Candidate observation was moved to sequential transactional
   execution rather than relying on same-statement visibility. Cleanup remained
   complete.

3. The following run exposed that psql variables inside a dollar-quoted
   `DO $handoff$` block are not substituted. Inputs were staged in a temporary
   table outside the PL/pgSQL block, preserving one atomic transaction.

4. The next run correctly denied direct SELECT on `mimir.memory_records` to
   `mimir_app`. No grant was widened. The consumer was corrected to use the
   existing SECURITY DEFINER API `mimir.inspect_candidate_conflict(uuid)`,
   which itself requires candidate state.

5. The final retry passed the complete path from operational handoff through
   authenticated human review, embedding and semantic recovery.

Security boundary retained:

- no direct `mimir_app` SELECT on `memory_records`;
- no automatic promotion;
- no automatic memory relation;
- no semantic visibility while status is candidate;
- no production migration/deploy;
- human authenticated review remains mandatory.

P1 — Permanent PostgreSQL Memory: `9/9 COMPLETE`.

NEXT_ACTION:

Advance to the next incomplete P1 operational milestone:
demonstrate real backup/restore behavior by adapter in an isolated laboratory.

## MIMIR-V1-P1-OPS-BACKUP-RESTORE-01

Date: 2026-09-29

Status: `PASS`

The supported backup/restore scope of the `generic-linux` adapter was validated
with real operating-system hostname operations inside an isolated UTS namespace.

Technical commits:

- `59706b58de77117ee31a5a79ea18853222369a6f`
  — `test(ops): validate adapter backup restore lab`;
- `00592833d52c1e7f552f74bb6e91374fd957bce3`
  — `fix(ops): pass python into backup restore namespace`.

Repository regression before LAB:

- operational tests: 55/55 PASS;
- harness shell syntax: PASS.

Final LAB evidence:

- host before LAB: `gentoo-Dragon_vm`;
- adapter: `generic-linux`;
- backup operation: `/bin/hostname`;
- initial namespace hostname: `mimir-backup-origin`;
- backup SHA-256:
  `19fbc334606ac5a0e1006a208c11543585116c069a36127d2a47602201f6210d`;
- real backup capture: PASS;
- real transient hostname change: PASS;
- post-change validation: PASS;
- real restoration from captured value: PASS;
- restoration validation: PASS;
- invalid restore value: BLOCKED;
- namespace final hostname restored to `mimir-backup-origin`;
- namespace restore guard: PASS;
- host after LAB: `gentoo-Dragon_vm`;
- host unchanged: PASS;
- SSH used: false;
- production database touched: false;
- external equipment touched: false;
- automatic rollback added: false;
- MikroTik backup: unsupported by policy;
- MikroTik `backup-save`: blocked;
- final LAB RC: 0.

Scope statement:

This closes the P1 requirement to demonstrate real backup/restore behavior for
the currently supported adapter capability. It does not claim a full Linux
system backup. The validated artifact is the runtime hostname required by the
existing `generic-linux` recovery contract.

Failure/correction chronology:

1. The first run entered the isolated UTS namespace but aborted before Python
   execution because the shell variable `PYTHON` had not been propagated to
   the child environment under `set -u`.
2. No real host state was changed.
3. The harness was corrected to pass `PYTHON` explicitly into the namespace.
4. The retry passed the complete backup/change/restore/validation path.

Security boundary retained:

- no arbitrary shell API was added;
- no automatic rollback was added;
- restore input still passes the adapter hostname validator;
- MikroTik backup remains unsupported;
- no SSH or equipment mutation occurred;
- no production database or memory schema was touched.

NEXT_ACTION:

Homologate the first laboratory equipment in READ mode using the existing
controlled SSH/catalog path. Do not enable EXECUTE as part of that milestone.

## MIMIR-V1-P1-REAL-MIKROTIK-READ-01

Date: 2026-09-29

Status: `PASS`

Technical commit:

- `736e93fced94bb21bc775dc83fe5703d7428330d`
  — `test(ops): validate real mikrotik read path`.

Final evidence:

- real `SSHExecutor`: PASS;
- adapter `mikrotik-routeros`: PASS;
- public-key authentication: PASS;
- password authentication: not used;
- dedicated RouterOS READ identity: PASS;
- catalog READ operations: 6/6 PASS;
- commands outside catalog: BLOCKED;
- EXECUTE: BLOCKED;
- configuration changes: 0;
- database/inventory writes: 0;
- raw device output persisted: false;
- ops regression: 55/55 PASS;
- final LAB RC: 0;
- evidence digest:
  `1df91e1dcd048507573ddd95ab3a5400251d3556ac59e1ccdb3fd11400a7d1bc`.

Host-key provenance:

The initial host-key pin was TOFU. The RouterOS public SSH host key was then
obtained through a separate administrative channel. Its SSH SHA-256 fingerprint
matched the pinned key exactly. The host-key provenance gate is therefore
closed as second-channel verified.

No real target IP, username, password or private key is committed to Git.

Security note:

Absence of post-quantum KEX was observed and remains a separate hardening item.

NEXT_ACTION:

Validate transient `set-hostname` for `generic-linux` in an isolated laboratory.


## MIMIR-V1-P1-GENERIC-LINUX-TRANSIENT-HOSTNAME-01

Date: 2026-09-29

Status: `PASS`

Technical commits:

- `2d7e13fc346a454469908613aa75666ab3168811`
  — `test(ops): validate transient generic linux hostname`;
- `ce416a9447f36156a5ca110df33ecbd262206137`
  — `fix(ops): bound transient lab sshd teardown`.

Final retry:

- real `SSHExecutor`: PASS;
- UTS namespace: PASS;
- PRECHECK / SNAPSHOT / BACKUP: PASS;
- EXECUTE without `ChangePermit`: BLOCKED;
- invalid hostname: BLOCKED;
- controlled EXECUTE: PASS;
- post-change validation: PASS;
- manual restore: PASS;
- final validation: PASS;
- controlled sshd teardown: PASS;
- real VPS hostname unchanged: PASS;
- production database touched: false;
- external equipment touched: false;
- automatic rollback: false;
- synthetic residue: 0;
- final LAB RC: 0.

Evidence digest:

`8d025d5cfe6729910f1c43d29e19833a09b4fcca04c32c2f65b1e2a7af4dce5c`

Failure/correction chronology:

1. First run passed change, validation and manual restore.
2. Teardown blocked because the tracked PID belonged to the `unshare` wrapper,
   not the actual `sshd` child.
3. The ephemeral sshd was terminated through a controlled second session.
4. The real VPS hostname remained unchanged.
5. Commit `ce416a9` corrected child-PID tracking and bounded teardown.
6. The complete LAB was repeated from a clean state.
7. Retry completed with RC 0, no manual intervention and zero residue.

NEXT_ACTION:

Do not expand adapters yet. Decide separately whether MikroTik EXECUTE,
FiberHome, H3C, Intelbras and other adapters belong to v1 or post-v1.


## MIMIR-V1-P1-OPS-SCOPE-FREEZE-01

Date: 2026-09-29

Status: `PASS`

Decision:

The operational scope of v1 is frozen with:

- `generic-linux` EXECUTE restricted to the catalogued and approved path;
- MikroTik validated and retained in READ;
- explicit catalog, `ChangePermit`, audit and manual recovery controls retained.

Deferred to post-v1:

- MikroTik EXECUTE;
- FiberHome adapters;
- H3C adapters;
- Intelbras adapters;
- additional multi-vendor EXECUTE capabilities.

This is a scope decision only. No equipment, PostgreSQL schema, service or
production runtime was changed.

NEXT_ACTION:

Start P1 reproducibility/release. First implementation target: CI for memory,
operations, validators, plugin build/test and syntax/lint checks.

## MIMIR-V1-CONTINUITY-2026-09-29-01

Date: 2026-09-29

Status: `READY_FOR_CONTINUATION`

Branch:

`feat/mimir-operational-foundation`

Validated/base HEAD:

`28ecec6e00b07bb60f63ff507a9cfae49ee4c3a5`
— `docs(ops): freeze v1 adapter scope`

### State

P1 permanent PostgreSQL memory:

- 9/9 items complete in LAB;
- `memory_handoff` integrated through candidate -> human review -> active;
- production migrations 014/015/016 remain undeployed.

P1 operational layer:

- Telegram secondary channel: validated;
- generic-linux backup/restore contract: LAB PASS;
- first real MikroTik READ: PASS;
- MikroTik real READ catalog: 6/6 PASS;
- independent SSH host-key verification: PASS;
- generic-linux transient `set-hostname`: LAB PASS;
- controlled EXECUTE requires catalog + approval + `ChangePermit`;
- manual restore path: PASS;
- transient LAB sshd teardown regression corrected and retry PASS;
- operational v1 adapter scope: frozen.

V1 adapter boundary:

- `generic-linux`: restricted EXECUTE path retained;
- MikroTik: READ only;
- MikroTik EXECUTE: post-v1;
- FiberHome: post-v1;
- H3C: post-v1;
- Intelbras: post-v1;
- additional multi-vendor EXECUTE: post-v1.

### Validation boundary

`IMPLEMENTED != VALIDATED`

`LAB_PASS != production validated`

`DEPLOYED != VALIDATED`

No production deployment, migration promotion, PR merge, Draft removal or
stable tag is authorized by this checkpoint.

Production PostgreSQL remains unchanged by the latest operational LABs.

### Relevant recent commits

- `28ecec6` — `docs(ops): freeze v1 adapter scope`
- `1599950` — `docs(ops): close transient hostname lab milestone`
- `ce416a9` — `fix(ops): bound transient lab sshd teardown`
- `2d7e13f` — `test(ops): validate transient generic linux hostname`
- `6b01958` — `docs(ops): close real mikrotik read milestone`
- `736e93f` — `test(ops): validate real mikrotik read path`
- `d94ecf6` — `docs(ops): close adapter backup restore milestone`

### Repository continuity

Trust order for continuation:

1. current Git branch/HEAD;
2. `docs/MIMIR_HANDOFF.md`;
3. `docs/MIMIR_V1_EXECUTION_PLAN.md`;
4. validation/review evidence;
5. `docs/STATUS.md`;
6. `docs/ROADMAP.md`;
7. chat history.

Do not reconstruct project state from chat when Git and handoff are available.

### NEXT_ACTION

Start `P1 — Reprodutibilidade e release`.

First implementation target:

`Adicionar CI para testes de memória, operações, validador, plugin e lint/syntax.`

Before implementation:

1. inspect the current repository tree and existing test entrypoints;
2. identify exact commands already validated locally;
3. design CI around existing commands rather than inventing parallel test paths;
4. do not modify production runtime;
5. implementation -> repository tests -> technical commit -> CI validation ->
   continuity checkpoint.

Do not start adapter expansion as part of this workstream.


## MIMIR-V1-P1-CI-01

Date: 2026-09-30

Status: `PASS`

Validated technical HEAD:

`32fa5ad75faabc118d79bbc96faa9fcac82a67b5`
— `fix(ci): use published typescript version`

Workflow:

`.github/workflows/repository-ci.yml`

Final GitHub Actions evidence:

- push run `36679922583`: PASS;
- pull_request run `36679925906`: PASS;
- Python repository tests: PASS;
- Shell and Node repository checks: PASS;
- Mimir memory plugin: PASS;
- plugin dependency install: PASS;
- plugin tests: PASS;
- plugin build: PASS;
- repository mutation guard: PASS.

Failure/correction chronology:

1. Commit `8211ebf` introduced the first repository CI.
2. Run `36678758326` failed:
   - generic Ubuntu runner executed a host-specific Gentoo/VPS validator case;
   - plugin dependency installation failed in npm peer resolution.
3. Commit `5e23e3c` isolated the host-specific validator case and adjusted npm
   peer handling.
4. Runs `36679449947` and `36679454330` confirmed Python and Shell/Node PASS,
   but plugin install failed because `typescript@5.9.0` was not published.
5. Registry precheck confirmed `typescript@5.9.3` and the other pinned package
   versions.
6. Commit `32fa5ad` changed only the CI TypeScript pin to `5.9.3`.
7. Final push and pull_request runs completed successfully.

Validation boundary:

- this proves repository CI behavior only;
- it does not validate production PostgreSQL;
- it does not validate OpenClaw production runtime;
- it does not validate OpenRC service state;
- it does not validate external equipment;
- no deployment, migration, service restart or equipment change occurred.

NEXT_ACTION:

Execute the complete v1 repository suite from a fresh clean checkout of
`feat/mimir-operational-foundation`.

The clean-checkout validation must start from the remote branch, preserve the
current production runtime, and produce a separate checkpoint before moving to
artifact/version restoration testing.


## MIMIR-V1-CONTINUITY-2026-09-30-02

Status: `READY_FOR_CONTINUATION`

Branch:

`feat/mimir-operational-foundation`

Validated/base HEAD:

`32fa5ad75faabc118d79bbc96faa9fcac82a67b5`

Current state:

- P1 permanent memory: LAB complete;
- P1 operational layer: v1 scope frozen/complete;
- repository CI: VALIDATED on push and pull_request;
- PR #1 remains Draft;
- production migrations 014/015/016 remain undeployed;
- no merge, Draft removal, production deploy or stable tag is authorized.

NEXT_ACTION:

`Executar suíte completa em checkout limpo.`

Do not begin restoration testing until the clean-checkout suite has its own
PASS/FAIL evidence and continuity checkpoint.
