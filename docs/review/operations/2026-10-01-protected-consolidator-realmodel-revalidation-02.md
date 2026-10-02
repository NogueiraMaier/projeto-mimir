# MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-02

Date: 2026-10-01

Status: **BLOCKED**

Branch:

`feat/mimir-operational-foundation`

Implementation/source HEAD:

`b0d69856ce42a4463330d37180cc9a76a3dc507f`

Local commits not yet pushed at checkpoint creation:

1. `93a0a1a15c7639eb182fab6e922ef23fe73a5fee` — `test(memory): harden real-model evidence validation`
2. `b0d69856ce42a4463330d37180cc9a76a3dc507f` — `fix(memory): align llama json schema transport`

Last verified remote branch base before these local commits:

`d4c7d098063fb502a9bda95526272fd216b240d9`

## Objective

Revalidate FINDING-05 in an integrated synthetic LAB against the real local
Qwen endpoint `127.0.0.1:18782`, with:

- synthetic content only;
- PostgreSQL LAB isolated from production;
- zero automatic promotion;
- `synthetic_residue=0`;
- no deployment;
- PR remaining Draft.

## State classification

FINDING-05:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

Protected consolidator:

`REPOSITORY_VALIDATED / REAL_MODEL_BLOCKED / NOT_DEPLOYED`

The repository validation and real-model validation remain separate states.

`REPOSITORY_VALIDATED != REAL_MODEL_VALIDATED`

`REAL_MODEL_BLOCKED != DEPLOYED`

## Versioned implementation evidence

Commit `93a0a1a15c7639eb182fab6e922ef23fe73a5fee` hardened the real-model LAB harness to require:

- at least one candidate;
- canonical evidence containing only `kind` and `sha256`;
- `kind=source_excerpt_hash`;
- no confidential `excerpt` in canonical output;
- 64-character lowercase hexadecimal SHA-256.

Commit `b0d69856ce42a4463330d37180cc9a76a3dc507f` changed only the structured-output transport and
its repository contract test after the previous transport produced HTTP 400
against the real runtime.

Repository validation after `b0d69856ce42a4463330d37180cc9a76a3dc507f`:

- JSON schema repository contract: PASS;
- protected consolidator suite: 12/12 PASS;
- isolated network namespace: PASS;
- repository validator RC=0.

This establishes repository validation only.

## Integrated real-model evidence

The integrated real-model LAB on `b0d69856ce42a4463330d37180cc9a76a3dc507f` reached the Qwen
request and failed closed with:

`candidate 1 viola schema fechado`

Observed safety properties:

- `LAB_RC=1`;
- synthetic cleanup completed;
- `synthetic_residue_after=0`;
- production remained schema `1..12`;
- production `mimir_ops=false`;
- repository remained unchanged;
- FINDING-05 real-model evidence was NOT proven;
- automatic promotion was NOT claimed.

Real-model LAB log:

`/var/tmp/mimir-protected-real-model-finding05-retry-20261001.log`

SHA-256:

`cec1d97c15550ca7b43738964571f31d07f654e016483c41f0372bc5c23b9e0e`

## Structural diagnosis

A synthetic structural probe against the real Qwen runtime showed:

- top-level schema keys were correct;
- source event ID matched;
- source content SHA-256 matched;
- `candidates` was a list;
- each returned candidate contained only `excerpt`;
- required candidate fields were absent;
- trusted validator rejected the response.

Probe log:

`/var/tmp/mimir-qwen-candidate-structure-20261001.log`

SHA-256:

`1d7dc1d891062148cda0c0919e568b929e64db1280dc11a596aa23e110dfb6ef`

## maxLength hypothesis

The exact schema was tested with nested evidence excerpt limits:

- 2048;
- 1999;
- 1024.

All three variants:

- returned HTTP 200;
- produced structurally invalid candidates;
- failed the trusted validator with the same closed-schema rejection.

Therefore changing `maxLength` did not resolve the observed runtime behavior.

Probe log:

`/var/tmp/mimir-qwen-maxlength-matrix-20261001.log`

SHA-256:

`23cd68bdd9dafd4c50ed9a7ffc53299d9f158b0c3f5f0f95bc8b1ca72031910f`

## Structured-output transport matrix

Three real-runtime transports were tested without modifying the repository:

A. `type=json_schema` with direct `schema`
   - HTTP 200;
   - output structurally invalid;
   - trusted validator REJECT.

B. `type=json_object` with direct `schema`
   - HTTP 400;
   - `Failed to initialize samplers: failed to parse grammar`.

C. `type=json_object` plus top-level `json_schema`
   - HTTP 400;
   - `Failed to initialize samplers: failed to parse grammar`.

Probe log:

`/var/tmp/mimir-qwen-structured-transport-matrix-20261001.log`

SHA-256:

`4548a13920ad3c62c383c34eca81e8c4e23eb548e864200726706917a7133ded`

Conclusion:

No tested JSON-Schema transport is currently accepted as a reliable
real-runtime constraint for this full contract.

## Explicit GBNF exploratory diagnostics

These probes were diagnostic only and were NOT committed as implementation.

First explicit GBNF probe:

- HTTP 400;
- sampler initialization rejected the grammar.

Corrected one-production-per-line probe:

Bounded grammar:

- HTTP 400;
- `Failed to initialize samplers: failed to parse grammar`.

Unbounded-string fallback:

- request did not complete inside the probe timeout;
- Python raised an unhandled `TimeoutError`;
- the diagnostic itself therefore failed to produce a controlled verdict.

This timeout is a defect in the exploratory probe, not proof that GBNF is
unsupported.

No GBNF implementation is considered validated.

## Problem statement

The real runtime behavior is not yet characterized sufficiently to select a
safe constrained-generation mechanism.

The observed evidence supports:

- JSON-Schema conversion/enforcement is unreliable for this full contract on
  the currently running runtime;
- direct-schema HTTP 200 is not sufficient evidence of enforcement;
- alternate JSON-Schema transports can fail grammar initialization;
- explicit GBNF still requires a controlled compatibility characterization.

The evidence does NOT yet establish a complete root cause for the runtime
behavior.

## Decision

Stop ad-hoc real-model probes.

Do not relax:

- closed candidate schema;
- evidence membership validation;
- source-bound evidence derivation;
- trusted SHA-256 derivation;
- trust class;
- mandatory human review;
- no-tool policy;
- endpoint allowlist;
- no automatic promotion.

Before changing the protected consolidator again, create a versioned synthetic
runtime-compatibility harness and validate the GBNF subset actually accepted by
the running llama.cpp server.

## Production impact

None.

Production baseline remained:

- schema `1..12`;
- migrations 014/015/016 absent;
- `mimir_ops=false`;
- no deployment;
- no production write.

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

Projetar e implementar no repositório um harness sintético versionado de compatibilidade GBNF para o runtime Qwen em 127.0.0.1:18782, sem PostgreSQL, começando por uma grammar mínima conhecida e expandindo construções incrementalmente. O harness deve tratar HTTPError, URLError e TimeoutError de forma fail-closed, preservar evidência estrutural sem conteúdo confidencial e ser validado antes de qualquer nova alteração no protected consolidator.

No new real-model integration run is authorized before this diagnostic harness
is versioned and validated.
