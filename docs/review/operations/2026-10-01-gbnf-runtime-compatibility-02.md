# MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-02

Date: 2026-10-01

Status:

`VALIDATED`

Scope:

`REAL_QWEN_GBNF_RUNTIME_COMPATIBILITY_G00_G07`

Branch:

`feat/mimir-operational-foundation`

Checkpoint base HEAD:

`6d238430b95db40e4568ee6c8032b29c2a82a9e8`

## Objective

Characterize the GBNF subset accepted by the installed local Qwen/llama.cpp
runtime using the previously committed, repository-validated synthetic
harness.

No protected consolidator code was changed by this run.

## Runtime target

Endpoint:

`http://127.0.0.1:18782/v1/chat/completions`

Model:

`/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf`

Qwen health:

`HTTP 200`

## Harness result

Process RC:

`0`

Harness execution:

`PASS`

Case results:

- G00 literal: PASS;
- G01 alternation: PASS;
- G02 rule-reference: PASS;
- G03 character-class-plus: PASS;
- G04 bounded-repetition: PASS;
- G05 fixed-json: PASS;
- G06 json-string-rule: PASS;
- G07 nested-bounded-json: PASS.

Summary:

- case count: 8;
- pass count: 8;
- HTTP 200: 8/8;
- finish_reason `stop`: 8/8;
- structure marker `OPENAI_CHAT_CONTENT`: 8/8;
- error marker: none for all cases;
- CONTIGUOUS_PASS_THROUGH: G07;
- RUNTIME_COMPATIBILITY: ALL_CASES_PASS.

## Evidence identity

Runtime evidence log:

`/var/tmp/mimir-gbnf-runtime-compatibility-run-20261001.log`

SHA-256:

`9a88a6343ff127716b258c822d0dc7dceac547c0a3c83509a81593a5a458ae1a`

Size:

`4339 bytes`

Lines:

`11`

The evidence log contains per-case hashes, sizes, HTTP status, finish reason,
structural marker and status. No raw model content is recorded in this
checkpoint.

## Technical conclusion

The installed runtime accepted every grammar construction represented by
the versioned G00..G07 matrix.

In particular, the run demonstrates acceptance of:

- literal productions;
- alternation;
- rule references;
- character-class `+`;
- bounded repetition such as `{1,8}`;
- fixed JSON;
- JSON string rules;
- nested JSON with bounded repetition.

The earlier exploratory suspicion that bounded repetition might be
unsupported is therefore rejected for this runtime and tested matrix.

Earlier ad-hoc probes remain preserved as historical failed or inconclusive
experiments. Their history is not removed.

## Scope limitation

This evidence establishes:

`GBNF_RUNTIME_COMPATIBILITY_VALIDATED`

It does not establish:

`PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`

The production-equivalent closed output contract has not yet been expressed
and validated as GBNF.

The protected consolidator has not yet been switched from its current
transport.

FINDING-05 therefore remains:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

## Production impact

None.

During this runtime compatibility run:

- PostgreSQL was not accessed by the harness;
- production was not accessed;
- protected consolidator was not modified;
- no deployment occurred;
- no migration occurred;
- no production role changed;
- no memory was promoted;
- Git HEAD remained unchanged;
- worktree remained clean;
- index remained clean;
- no commit was made;
- no push was made.

## Release boundary

Still prohibited:

- Draft removal;
- merge;
- stable tag;
- production deployment;
- production migrations 014/015/016;
- production `mimir_ops`;
- implicit risk acceptance.

Existing release blockers remain unchanged:

- RSK-P0-003 — OPEN / BLOCKER;
- RSK-P0-004 — PARTIALLY_TREATED / production-release blocker;
- RSK-P0-005 — OPEN / BLOCKER.

## NEXT_ACTION

Inspecionar e projetar no repositório uma grammar GBNF versionada equivalente ao contrato fechado do protected consolidator, derivada do schema/validator atualmente confiável. A nova grammar deve preservar todos os campos obrigatórios, additionalProperties=false, candidate e evidence structure, source_session_id/source_event_id, evidence kind source_excerpt_hash e SHA-256 lowercase de 64 caracteres. Primeiro validar essa grammar somente em testes de repositório positivos e negativos; não alterar ainda o transporte do protected consolidator, não executar PostgreSQL e não fazer nova chamada ao modelo real.
