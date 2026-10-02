# MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-REPOSITORY-VALIDATION-01

Date: 2026-10-02

Status:

`REPOSITORY_VALIDATED_RUNTIME_VALIDATION_PENDING`

Branch:

`feat/mimir-operational-foundation`

Implementation HEAD:

`5ecb2b36b349b52416e347b15b7761801d09036c`

## Scope

Repository-only implementation and validation of the dedicated runtime
harness for the complete protected-output GBNF v1.

No model endpoint request occurred.

No PostgreSQL access occurred.

No protected consolidator execution or modification occurred.

## Implementation identities

Runtime harness:

`tools/memory/mimir_protected_output_gbnf_runtime_v1.py`

SHA-256:

`da6e0f0e7bdcbd6e5ca0237df29c5e47feb171bdcb703bca8228a95b85676498`

Repository tests:

`tools/memory/test_mimir_protected_output_gbnf_runtime_v1.py`

SHA-256:

`16ac4385236108aa5e3f60e8ef56aa35a98d9e06ea08bab81b4ea1ce8ec95e36`

Repository validator:

`tools/memory/validate-protected-output-gbnf-runtime-v1-repository.sh`

SHA-256:

`a3f51af178745e0c87c3c07f01eb65f8b109e51f0cef25f1015af1a20df7f5e1`

Repository validation evidence SHA-256:

`2c3017141d07b7a45090b5096dad316b69a339a03b458b7866641d3ace8b40c9`

## Repository validation

Result:

`REPOSITORY_HARNESS_VALIDATION=PASS`

Tests:

`19/19 PASS`

Validated properties include:

- committed dependency identities;
- exact endpoint allowlist;
- exact model allowlist;
- synthetic-only runtime case;
- deterministic grammar construction;
- exact source_event_id binding;
- exact source_content_sha256 binding;
- deterministic request serialization;
- top-level grammar transport;
- temperature 0.0;
- stream false;
- enable_thinking false;
- timeout boundaries;
- bounded response handling;
- HTTP rejection classification;
- timeout classification;
- transport-error classification;
- malformed OpenAI envelope rejection;
- finish_reason enforcement;
- tool_calls rejection;
- function_call rejection;
- empty-content rejection;
- exact expected synthetic protected-output JSON validation;
- sanitized result-record fields;
- absence of protected source payload.

The repository validator ran tests inside a network-isolated namespace.

Therefore repository validation did not contact the model endpoint.

## Runtime boundary

Current state:

`FULL_GBNF_RUNTIME_VALIDATION=PENDING`

Repository PASS proves the harness itself is versioned and validated.

It does not prove that the complete grammar has yet been accepted by the real
llama.cpp/Qwen runtime.

## Security boundary

Qwen:

`NOT_ACCESSED`

PostgreSQL:

`NOT_ACCESSED`

Protected consolidator:

`UNCHANGED / NOT_DEPLOYED`

Production:

`UNCHANGED`

FINDING-05:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

The following distinction remains mandatory:

`FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`

Even if the next synthetic runtime validation passes, that result alone will
not validate the complete protected consolidator path and will not close
FINDING-05.

PR:

`REMAINS_DRAFT`

Push:

`NOT_PERFORMED`

## NEXT_ACTION

`CONTROLLED_RUNTIME_VALIDATE_PROTECTED_OUTPUT_GBNF_V1_SYNTHETIC`

The next phase may perform one controlled synthetic request to the allowlisted
local llama.cpp endpoint using the committed runtime harness.

It must not access PostgreSQL.

It must not execute or modify the protected consolidator.
