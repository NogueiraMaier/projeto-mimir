# MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-PG-E2E-DESIGN-01

Date: 2026-10-02

Status:

`PROPOSED`

Source HEAD:

`c76b443a51aea0c47ae25aa93efd1fae6e0022d4`

## Requirement

Validate the protected consolidator through the complete isolated integration
path:

`CLI -> PostgreSQL LAB -> protected read -> Qwen -> trusted validation`

without touching production and without automatic memory promotion.

## Inspection

The current versioned
`tools/memory/validate-protected-consolidator-real-model-lab.sh`
already implements this path.

Creating another harness would be redundant.

The existing harness already performs:

1. versioned source staging;
2. LAB environment guards;
3. synthetic residue precheck;
4. synthetic fixture generation;
5. capture;
6. writer dry-run;
7. writer into PostgreSQL LAB;
8. protected read;
9. protected consolidator CLI plus real local Qwen;
10. output-contract validation;
11. zero-automatic-promotion validation;
12. targeted synthetic database cleanup.

## Isolation boundary

LAB root:

`/var/tmp/mimir-pg14-lab`

LAB PostgreSQL port:

`55433`

The harness verifies that PostgreSQL's `data_directory` belongs to the LAB
and that TCP 55433 is not exposed.

The production PostgreSQL socket is not authorized.

## Safety finding in the harness

The cleanup contains:

`rm -rf -- "$RUN"`

This must not be executed under the project operational discipline.

The run directory already uses `mktemp` under `/var/tmp` and contains
synthetic/restricted artifacts useful for audit evidence.

## Decision

Do not create a new E2E harness.

Minimally harden the existing harness:

- preserve targeted SQL cleanup of synthetic rows;
- preserve the synthetic residue check;
- remove recursive filesystem deletion;
- leave the run directory intact;
- report the preserved run directory path;
- keep permissions restrictive;
- make no protected-consolidator semantic change.

## Progression

1. repository-only safety hardening;
2. isolated repository validation;
3. commit code;
4. continuity checkpoint;
5. separately authorize E2E LAB execution;
6. one Qwen request through the CLI;
7. PASS/FAIL evidence;
8. continuity checkpoint.

No E2E execution is authorized by this design checkpoint.

## Finding boundary

FINDING-05 is already:

`CLOSED / REAL_MODEL_REVALIDATED`

The planned E2E validates integration with PostgreSQL LAB and the CLI. It does
not redefine the already closed finding.

## NEXT_ACTION

`HARDEN_EXISTING_PROTECTED_CONSOLIDATOR_REAL_MODEL_LAB_CLEANUP_REPOSITORY_ONLY`
