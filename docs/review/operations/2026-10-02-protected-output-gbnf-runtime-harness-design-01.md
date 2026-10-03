# MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-HARNESS-DESIGN-01

Date: 2026-10-02

Status:

`PROPOSED`

Base HEAD:

`1702aff81fcb0d1da36ae0eac8b9c3e03072dd67`

## Objective

Freeze the design boundary for a versioned runtime-validation harness for the
complete protected-output GBNF v1.

The inspection phase is complete.

No further inspection of the existing G00..G07 harness is required while its
source identity remains `edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc`.

## Source identities

Existing GBNF runtime compatibility harness:

`tools/memory/mimir-gbnf-runtime-compatibility.py`

SHA-256:

`edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc`

Protected-output GBNF v1 builder:

`tools/memory/mimir_protected_output_gbnf_v1.py`

SHA-256:

`d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`

## Inspection evidence

Runtime-design inspection SHA-256:

`0e72de241ec6846d550b518cc65c9d9528393f6a987b5f707cab25edb40824f4`

Exact reusable-block inspection SHA-256:

`0a3e9d0c00ac87d5f6f3d739608f989064d735882be6b59844fa7d2f7481028f`

## Reusable runtime mechanism

The existing validated harness establishes the mechanism to reuse:

- endpoint allowlist:
  `http://127.0.0.1:18782/v1/chat/completions`;
- model allowlist remains explicit;
- top-level request field `grammar`;
- deterministic JSON serialization;
- `temperature=0.0`;
- `stream=false`;
- `chat_template_kwargs.enable_thinking=false`;
- bounded response reading;
- HTTP error classification;
- URL/timeout classification;
- transport-error classification;
- OpenAI-compatible response extraction;
- exactly one choice;
- `finish_reason=stop`;
- no tool_calls;
- no function_call;
- non-empty textual content;
- post-generation content validation;
- sanitized result records.

Existing result classes to preserve semantically:

- `PASS`;
- `HTTP_REJECT`;
- `TIMEOUT`;
- `TRANSPORT_ERROR`;
- `STRUCTURE_REJECT`.

## Design decision

Do not modify the existing G00..G07 compatibility harness.

Do not create another manual/ad-hoc runtime probe.

Implement a dedicated, versioned harness specialized for the complete
protected-output GBNF v1.

Planned files:

- `tools/memory/mimir_protected_output_gbnf_runtime_v1.py`;
- `tools/memory/test_mimir_protected_output_gbnf_runtime_v1.py`;
- `tools/memory/validate-protected-output-gbnf-runtime-v1-repository.sh`.

## Repository-only first phase

The new harness must initially be validated without contacting Qwen.

Repository-only tests must cover at least:

- deterministic synthetic runtime-case construction;
- exact endpoint/model allowlists;
- exact committed builder use;
- exact synthetic event-id binding;
- exact synthetic content-SHA binding;
- grammar SHA recording;
- deterministic request serialization;
- top-level grammar transport;
- temperature 0.0;
- stream false;
- enable_thinking false;
- timeout boundaries;
- bounded response handling;
- HTTP rejection classification;
- timeout classification;
- transport error classification;
- malformed OpenAI envelope rejection;
- finish_reason rejection;
- tool/function-call rejection;
- empty-content rejection;
- valid protected-output JSON shape validation;
- absence of protected source data;
- sanitized evidence/result output;
- explicit runtime-validation pending state.

## Controlled runtime phase

Only after the repository harness is validated and committed may one
controlled runtime execution be authorized.

That execution must use synthetic values only.

It must not use PostgreSQL.

It must not execute or modify the protected consolidator.

## Security boundary

`FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`

A future successful parser/runtime test of the complete grammar only proves
that the committed full grammar can be transported and accepted by the real
llama.cpp/Qwen runtime under that synthetic validation.

It does not prove protected-source evidence binding, trusted canonicalization
or the complete protected consolidator path.

Therefore FINDING-05 remains:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

Current runtime state:

`FULL_GBNF_RUNTIME_VALIDATION=PENDING`

Protected consolidator:

`UNCHANGED / NOT_DEPLOYED`

Qwen runtime for this phase:

`NOT_EXECUTED`

PostgreSQL:

`NOT_ACCESSED`

Production:

`UNCHANGED`

PR:

`REMAINS_DRAFT`

Push:

`NOT_PERFORMED`

## NEXT_ACTION

`IMPLEMENT_PROTECTED_OUTPUT_GBNF_RUNTIME_V1_HARNESS_REPOSITORY_ONLY`
