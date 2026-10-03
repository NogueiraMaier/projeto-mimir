# MIMIR-V1-PROTECTED-CONSOLIDATOR-GBNF-DESIGN-01

Date: 2026-10-01

Status:

`PROPOSED`

Branch:

`feat/mimir-operational-foundation`

Base HEAD:

`55f668d866557eb2a7736c0d88f2ce2c795bb946`

## Objective

Define the protected-output GBNF boundary before implementation, using the
current trusted schema, trusted validator and installed llama.cpp tooling as
the source of truth.

No consolidator code is changed by this checkpoint.

## Inspection evidence

Static contract inspection:

`/var/tmp/mimir-protected-gbnf-contract-inspect-55f668d.log`

SHA-256:

`abbf0cdbd92d488d321692832c0c96af2e5cc887aaed9577dd24c93c460a3d8c`

Edge-case inspection:

`/var/tmp/mimir-protected-gbnf-edge-inspect-55f668d.log`

SHA-256:

`4897ecc1b82eee273e4bf1738876f42083e83fd80ddc4adcba7685f8bff3d719`

llama.cpp capability inspection:

`/var/tmp/mimir-llama-gbnf-capability-55f668d.log`

SHA-256:

`ecb03bb24fe859c616ee0875ccde78b4f99d3d817214e45eeaca7dbc305c0487`

## Correct raw model contract

The model output consumed by the trusted validator contains exactly these
top-level semantic fields:

- `schema_version`;
- `source_event_id`;
- `source_content_sha256`;
- `candidates`.

`source_session_id` is not part of this v1 model-output contract.

Each raw candidate has exactly:

- `memory_type`;
- `summary`;
- `confidence`;
- `evidence`;
- `trust_class`;
- `requires_human_review`.

Each raw evidence object has exactly:

- `kind`;
- `excerpt`.

Its kind is:

`source_excerpt`

The model does not produce the final evidence hash.

After validating that the excerpt is an exact contiguous substring of the
protected source, the trusted validator replaces raw evidence with canonical:

- `kind=source_excerpt_hash`;
- trusted SHA-256 of the accepted excerpt.

Therefore `source_excerpt_hash` MUST NOT be introduced into the model-output
GBNF.

## Grammar responsibilities

The proposed grammar builder will constrain:

- top-level shape and canonical key order;
- literal `schema_version=1`;
- exact requested `source_event_id`;
- exact trusted `source_content_sha256`;
- candidates cardinality 0..max_candidates;
- exact candidate field order and structure;
- current memory_type enum;
- fixed `trust_class=UNTRUSTED_OBSERVATION`;
- fixed `requires_human_review=true`;
- evidence array with one-or-more raw evidence objects;
- exact evidence field structure;
- fixed evidence kind `source_excerpt`;
- JSON lexical structure for strings and numbers.

Canonical key order is a transport restriction only. It does not change JSON
object semantics and does not weaken the trusted validator.

## Responsibilities deliberately retained by trusted validation

The GBNF is not a replacement for `validate_output()`.

The trusted validator remains responsible for:

- source content hash recomputation;
- exact decoded key-set checks;
- summary trim/non-empty/maximum-length checks;
- secret/output gate;
- confidence Python type check;
- bool exclusion for confidence;
- confidence range [0,1];
- evidence excerpt trim/non-empty/maximum-length checks;
- exact source substring binding;
- trusted evidence SHA-256 derivation;
- canonical-output construction;
- final canonical secret/output gate.

These checks remain authoritative even if the grammar already prevents some
syntactic invalid states.

## Cardinality decisions

Candidates:

`0..max_candidates`

This preserves the current JSON Schema and trusted validator behavior.

Evidence:

`1..unbounded`

No new evidence maximum will be invented because the current contract does
not define one.

## Runtime-parser boundary

Installed tools expose:

- `llama-cli --grammar`;
- `llama-cli --grammar-file`;
- `llama-server --grammar`;
- `llama-server --grammar-file`.

No dedicated `llama-gbnf-validator`, `llama-grammar-validator`, Python
llama_cpp parser module or explicit grammar parse/check-only mode was found
during the inspected capability set.

Therefore:

`REPOSITORY_CONTRACT_VALIDATION != LLAMA_GBNF_RUNTIME_VALIDATION`

Repository-only validation may establish deterministic grammar generation,
input validation, exact bindings and contract mapping.

Actual llama.cpp parser acceptance of the new production-equivalent grammar
must remain:

`RUNTIME_VALIDATION_PENDING`

until a later controlled runtime test.

## Planned repository-only implementation

New files only:

- `tools/memory/mimir_protected_output_gbnf_v1.py`;
- `tools/memory/test_mimir_protected_output_gbnf_v1.py`;
- `tools/memory/validate-protected-output-gbnf-v1-repository.sh`.

The existing protected consolidator will not be modified during this first
implementation step.

Repository tests must cover at least:

- deterministic grammar generation;
- exact event-id binding;
- exact content-SHA binding;
- max_candidates boundaries 1 and 10;
- rejection of invalid max_candidates;
- rejection of malformed/non-lowercase SHA-256;
- candidate cardinality representation;
- exact memory_type enum;
- raw source_excerpt/excerpt structure;
- absence of source_session_id;
- absence of source_excerpt_hash and model-provided evidence sha256;
- fixed trust class;
- mandatory human review true;
- candidate empty-array preservation;
- one-or-more evidence representation;
- absence of invented evidence maximum;
- fail-closed builder input handling.

No repository test may claim real llama.cpp parser compatibility unless it
actually uses the real parser in an isolated controlled validation step.

## Security boundary

This design does not close FINDING-05.

FINDING-05 remains:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`

Protected consolidator remains:

`NOT_DEPLOYED`

Still prohibited:

- Draft removal;
- merge;
- stable tag;
- production deployment;
- production migrations 014/015/016;
- production `mimir_ops`;
- implicit risk acceptance.

## NEXT_ACTION

Implementar no repositório, sem modificar ainda o protected consolidator, os artefatos versionados `tools/memory/mimir_protected_output_gbnf_v1.py`, `tools/memory/test_mimir_protected_output_gbnf_v1.py` e `tools/memory/validate-protected-output-gbnf-v1-repository.sh`. O builder deve gerar GBNF determinística ligada a source_event_id, source_content_sha256 e max_candidates, preservar a estrutura bruta source_excerpt/excerpt e nunca introduzir source_session_id ou source_excerpt_hash. A validação repository-only deve provar o contrato do builder e suas rejeições, mas deve registrar explicitamente que a aceitação da nova grammar pelo parser llama.cpp permanece RUNTIME_VALIDATION_PENDING. Não executar Qwen ou PostgreSQL.
