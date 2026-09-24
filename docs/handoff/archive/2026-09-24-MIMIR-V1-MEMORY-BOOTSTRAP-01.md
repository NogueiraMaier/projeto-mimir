# Handoff archive — MIMIR-V1-MEMORY-BOOTSTRAP-01

Archived: 2026-09-24
Branch: feat/mimir-operational-foundation
Validation environment: isolated PostgreSQL cluster on gentoo-Dragon_vm

## Historical conclusion

The original memory migration 001 was not recovered from Git or the local
recovery directory. The project therefore does not claim a reconstructed file
is the historical migration.

A canonical reconstruction was versioned instead:

- tools/memory/bootstrap/memory_v1_canonical.sql
- tools/memory/test_memory_bootstrap.py
- tools/memory/validate-memory-bootstrap-lab.sh
- docs/recovery/MEMORY_V1_CANONICAL_BOOTSTRAP.md

## Validation result

Local static test:

- 9 tests
- OK

Isolated PostgreSQL replay:

- empty temporary database named mimir_memory;
- canonical bootstrap applied successfully;
- versions after bootstrap: 1;
- migrations 002 through 012 applied unchanged and in order;
- final schema versions: 1,2,3,4,5,6,7,8,9,10,11,12.

Final object validation included:

- all expected memory tables;
- all expected controlled memory functions;
- generated search_document column;
- generated content_sha256 column;
- no direct SELECT/INSERT/UPDATE/DELETE for mimir_app on the five base tables;
- schema USAGE preserved;
- EXECUTE preserved for ingest_document, ingest_session and propose_memory.

Production remained unchanged:

- schema versions 1..12;
- schema version 13 absent;
- mimir_ops role absent.

## Conclusion

The repository now has a reproducible, validated path from an empty PostgreSQL
database to memory schema version 12 without misrepresenting the historical
status of migration 001.

## Next action

Retire the temporary PostgreSQL validation cluster, then address plugin metadata
drift and explicit plugins.allow.
