# MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-CONTROLLED-VALIDATION-01

Date: 2026-10-02

Status:

`VALIDATED`

Base HEAD:

`2a321ec6b353d86214f20912d223939743183a44`

## Result

`FULL_GBNF_RUNTIME_VALIDATION=PASS`

The committed full protected-output GBNF v1 was exercised once against the
real allowlisted local llama.cpp/Qwen endpoint using synthetic data only.

## Execution

Endpoint:

`http://127.0.0.1:18782/v1/chat/completions`

Model:

`/var/lib/openclaw/models/Qwen3-4B-Q4_K_M.gguf`

Request count:

`1`

Timeout:

`120`

HTTP status:

`200`

finish_reason:

`stop`

Harness result:

`PASS`

Automatic retry:

`NO`

Second request:

`NOT_PERFORMED`

## Evidence

Runtime evidence SHA-256:

`40b6fd7dabc5bf9174f2c469f37678f014fc668553aea245de3d1624b16cbdfb`

Harness SHA-256:

`da6e0f0e7bdcbd6e5ca0237df29c5e47feb171bdcb703bca8228a95b85676498`

Builder SHA-256:

`d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`

Grammar SHA-256:

`cda50abd374699110f57d663410d928026882f09801004ef92ae52246ffc17d4`

Request SHA-256:

`16d63d904cbf4f805af1f1e9ca42870df8488f43e60960b9e0ac8503941521e0`

Response SHA-256:

`230f240eda0024395bcd1ea01a72fe2b98002c149320535adc154e0ae9ec3bb9`

Generated content SHA-256:

`d191bc259d7e8d1fffe597dda207caae5119ce83da5f2493745c5f24efcdfcd9`

## Validation boundary

This establishes that the complete committed protected-output grammar is
accepted by the installed real llama.cpp/Qwen runtime for the committed
synthetic case.

It does not validate the protected consolidator end-to-end.

The mandatory distinction remains:

`FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`

## Protected systems

Protected consolidator:

`UNCHANGED / NOT EXECUTED`

PostgreSQL:

`NOT ACCESSED`

Production:

`UNCHANGED`

PR:

`REMAINS_DRAFT`

Push:

`NOT_PERFORMED`

FINDING-05 remains:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

## NEXT_ACTION

`IMPLEMENT_PROTECTED_CONSOLIDATOR_GBNF_TRANSPORT_REPOSITORY_ONLY`

The next phase is repository-only integration of the validated GBNF transport
into the protected consolidator path.

No production deployment is authorized.
