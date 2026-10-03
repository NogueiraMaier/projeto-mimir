# MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-01

Date: 2026-10-01

Status:

`REPOSITORY_VALIDATED / REAL_RUNTIME_VALIDATION_PENDING`

Branch:

`feat/mimir-operational-foundation`

Code HEAD:

`720556e0fad34a3d5d9f3602d094da2bd3c8d20f`

## Objective

Introduce a versioned, synthetic compatibility harness to characterize the
GBNF subset accepted by the real local Qwen/llama.cpp runtime before any
further modification to the protected consolidator.

The harness is diagnostic only.

It does not use PostgreSQL, does not promote memory, does not modify the
protected consolidator and does not perform production writes.

## Versioned implementation

Commit:

`720556e0fad34a3d5d9f3602d094da2bd3c8d20f`

Files added:

- `tools/memory/mimir-gbnf-runtime-compatibility.py`;
- `tools/memory/test_mimir_gbnf_runtime_compatibility.py`;
- `tools/memory/validate-gbnf-runtime-compatibility-repository.sh`.

No pre-existing protected consolidator source, test or LAB harness was
modified by this commit.

## File identity

Harness SHA-256:

`edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc`

Unit-test SHA-256:

`91fbbfbf1d0c521f38d3795fec1cd75e0bdaabf88d7e51adfbba38f2230ee6e1`

Repository-validator SHA-256:

`b37d750f1b024ffafce1abe0ece877799256913e4f2e210e1c6d83ecf7e0fc87`

## Repository validation

Validation was executed against committed HEAD `720556e0fad34a3d5d9f3602d094da2bd3c8d20f`.

Observed results:

- Python syntax: PASS;
- static repository policy: PASS;
- isolated network namespace: PASS;
- loopback active inside namespace;
- `127.0.0.1:18782` free inside namespace;
- unit tests: 15/15 PASS;
- repository validator:
  `MIMIR-GBNF-RUNTIME-COMPATIBILITY-REPOSITORY: PASS`.

The tests cover, among other controls:

- exact endpoint allowlist;
- exact model allowlist;
- unique ordered GBNF case matrix;
- mandatory `root` rules;
- explicit `grammar` request transport;
- absence of JSON-Schema transport from the harness request;
- bounded response reading;
- HTTP grammar-parse rejection classification;
- generic HTTP error classification;
- URLError fail-closed handling;
- TimeoutError fail-closed handling;
- invalid JSON response rejection;
- non-stop finish reason rejection;
- tool-call rejection;
- output record exclusion of raw content fields;
- separation between harness execution and runtime compatibility status.

## Real-runtime state

No request to the real Qwen endpoint was performed during this repository
validation.

Therefore:

`REPOSITORY_VALIDATED != REAL_RUNTIME_VALIDATED`

Current runtime state:

`REAL_RUNTIME_VALIDATION_PENDING`

No claim is made that any GBNF feature is accepted by the installed runtime.

## Protected consolidator state

The existing protected consolidator remains unchanged.

FINDING-05 remains:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

Protected consolidator remains:

`NOT_DEPLOYED`

The new harness does not close FINDING-05 and does not authorize changes to
the consolidator.

## Production impact

None.

During implementation and repository validation:

- Qwen real endpoint was not accessed;
- PostgreSQL was not accessed;
- production was not accessed;
- no deployment occurred;
- no production migration occurred;
- no production role was changed;
- no automatic memory promotion occurred.

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

Executar de forma controlada o harness versionado `tools/memory/mimir-gbnf-runtime-compatibility.py` contra o runtime Qwen local `127.0.0.1:18782`, sem PostgreSQL e usando somente os casos sintéticos G00..G07. Registrar apenas hashes, tamanhos, status HTTP, marcadores estruturais e classificação por caso; não registrar conteúdo bruto do modelo. Não alterar o protected consolidator durante essa execução. O resultado deve distinguir HARNESS_EXECUTION de RUNTIME_COMPATIBILITY e ser documentado antes de qualquer mudança no consolidator.
