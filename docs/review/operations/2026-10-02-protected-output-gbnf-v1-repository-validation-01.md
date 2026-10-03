# MIMIR-V1-PROTECTED-OUTPUT-GBNF-V1-REPOSITORY-VALIDATION-01

Date: 2026-10-02

Status:

`REPOSITORY_VALIDATED_RUNTIME_VALIDATION_PENDING`

Branch:

`feat/mimir-operational-foundation`

Implementation HEAD:

`c3afe5e0dcdbe6f8728a437a002b06c4112bba4a`

## Scope

Repository-only implementation and validation of the versioned protected
output GBNF v1 contract.

No protected consolidator transport was changed.

No production deployment occurred.

## Implementation identities

Builder:

`tools/memory/mimir_protected_output_gbnf_v1.py`

SHA-256:

`d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`

Repository tests:

`tools/memory/test_mimir_protected_output_gbnf_v1.py`

SHA-256:

`2ba1129fc7ce5f4218d150e73bffd046d1683efe4879cd1cfa6516a047ac5657`

Repository validator:

`tools/memory/validate-protected-output-gbnf-v1-repository.sh`

SHA-256:

`91504127a5ab5e159602edfaad5ef17238bf5c40a2f0d55ba18c17782e90b764`

## Repository validation result

`REPOSITORY_CONTRACT_VALIDATION=PASS`

Validation includes:

- 18/18 unit tests PASS;
- deterministic grammar generation;
- exact event binding;
- exact content-SHA binding;
- max_candidates boundaries 1 and 10;
- invalid max_candidates rejection;
- malformed/non-lowercase SHA rejection;
- candidate cardinality 0..max_candidates;
- exact current memory_type enum;
- raw source_excerpt/excerpt structure;
- absence of source_session_id from generated grammar;
- absence of source_excerpt_hash from generated grammar;
- fixed UNTRUSTED_OBSERVATION trust class;
- mandatory requires_human_review=true;
- candidate empty-array preservation;
- evidence one-or-more representation;
- no invented evidence maximum;
- fail-closed builder input handling;
- builder import policy;
- syntax validation;
- text/EOF policy.

## Trusted-validator boundary

GBNF remains a syntax/transport constraint.

The trusted validator remains authoritative for:

- source-content hash verification;
- decoded closed-key checks;
- summary trim/non-empty/maximum length;
- secret/output gate;
- confidence type/range;
- evidence excerpt trim/non-empty/maximum length;
- exact excerpt/source substring binding;
- trusted evidence SHA-256 generation;
- canonical output construction;
- final canonical secret/output gate.

## Runtime boundary

The repository tests do not prove acceptance of this complete grammar by the
real llama.cpp parser/runtime.

Current state:

`LLAMA_GBNF_RUNTIME_VALIDATION=PENDING`

This is intentionally distinct from the earlier incremental G00..G07 runtime
compatibility matrix.

## Failure history preserved

### Validator false positive

Initial repository validator failed with:

`FAIL: source_session_id found in builder`

Evidence SHA-256:

`6bf562f40a4ca41f48346a243c915cdeac4aa36cb51fbc783d4f996c8c21f9a5`

Root cause:

The validator scanned the builder source, where source_session_id appeared
only inside defensive rejection guards, instead of inspecting the generated
grammar.

Correction:

Only the validator was changed to inspect generated grammar output.

Builder and tests remained unchanged.

### First final-review false positive

Initial final review failed with:

`FAIL:max_candidates=3 representation`

Failed-review evidence SHA-256:

`4f15be4ea3081015e30cde972a9533504206aec6f03318465851fa899d1b5a0e`

Root cause:

The review counted the substring `candidate` across the complete rule line,
which also counted the left-hand rule name `candidates`.

Corrected read-only review:

`CORRECTED_RHS_COUNT=6`

Expected:

`6`

Implementation change required:

`NO`

Corrected-review evidence SHA-256:

`dca76997174dc2d748aaf1e64250f1cec6b5978c922cd68e1a510ffb94e5296e`

## Security and production state

Protected consolidator:

`UNCHANGED / NOT_DEPLOYED`

FINDING-05:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

Qwen:

`NOT_ACCESSED`

PostgreSQL:

`NOT_ACCESSED`

Production:

`UNCHANGED`

PR:

`REMAINS_DRAFT`

Push:

`NOT_PERFORMED`

Still prohibited:

- Draft removal;
- merge;
- stable tag;
- production deployment;
- production migrations 014/015/016;
- production mimir_ops;
- implicit risk acceptance.

## NEXT_ACTION

Projetar e executar uma validação controlada da grammar protected-output GBNF v1 contra o parser/runtime real do llama.cpp usando apenas dados sintéticos, sem PostgreSQL e sem alterar o protected consolidator. A validação deve usar a grammar produzida pelo builder commitado, preservar source_event_id/source_content_sha256 sintéticos, não usar dados protegidos e distinguir parser/runtime PASS de protected-consolidator real-model validation. Não alterar ainda mimir-consolidate-protected-v1.py.
