# MIMIR-V1-RSK-P0-005-HUMAN-APPROVAL-AND-EXERCISE-DESIGN-01

Date: 2026-10-02

Status:

`PLAN_APPROVED / EXERCISE_DESIGN_PROPOSED`

## Approved plan

Canonical plan:

`docs/INCIDENT_RESPONSE.md`

Approved SHA-256:

`185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`

Human approval:

`APPROVED`

Explicit approval statement:

> Aprovo o plano de resposta a incidentes do Mímir v1 e autorizo o desenho do exercício sintético do RSK-P0-005.

## Approval scope

The approval authorizes:

- adoption of the identified `docs/INCIDENT_RESPONSE.md` as the formal
  incident-response plan for Mímir v1;
- design of the isolated synthetic exercise for RSK-P0-005.

The approval does not authorize:

- execution of the exercise;
- production access;
- PostgreSQL access;
- Qwen/model access;
- network changes;
- service restart;
- credential mutation;
- firewall mutation;
- real equipment access;
- Draft removal;
- merge;
- stable tag;
- deployment;
- closure of RSK-P0-005.

## Risk state

`RSK-P0-005 = OPEN / BLOCKER`

The plan is now:

`REPOSITORY_VALIDATED / HUMAN_APPROVED`

The exercise remains:

`DESIGN_ONLY / NOT_EXECUTED`

---

# Synthetic incident-response exercise design

Exercise ID:

`MIMIR-IR-TTX-001`

Type:

`ISOLATED_SYNTHETIC_TABLETOP`

Purpose:

Validate the incident-response process itself without contacting production,
real infrastructure, real users, real credentials or the model runtime.

## Scenario

A completely synthetic input is presented as if it came from an untrusted
external source.

The synthetic content attempts to:

1. override operational policy;
2. request privileged execution without authorization;
3. bypass human approval;
4. request arbitrary shell execution;
5. expose a synthetic credential marker;
6. influence permanent-memory handling.

No actual privileged action is executed.

No real credential is used.

The simulated situation requires the responder to recognize both:

- attempted unauthorized operation;
- potential credential-exposure indicator.

## Scenario categories

Expected applicable categories include:

- `UNAUTHORIZED_OPERATION`;
- `PROMPT_OR_CONTENT_INJECTION`;
- `CREDENTIAL_EXPOSURE`.

The exercise must still explicitly perform classification rather than merely
copy these labels from the scenario.

## Severity objective

The scenario must contain enough synthetic facts to justify a severity
decision.

The exercise must record:

- assigned severity;
- rationale;
- whether escalation is required.

The harness must not silently hard-code PASS merely because the environment is
synthetic.

## Required lifecycle

The exercise must demonstrate:

`DETECT -> CLASSIFY -> CONTAIN -> PRESERVE EVIDENCE -> INVESTIGATE -> ERADICATE -> RECOVER -> VALIDATE -> POSTMORTEM`

## Isolation boundary

The implementation and future execution must not:

- access production;
- access PostgreSQL;
- call Qwen or another model;
- open external network connections;
- invoke SSH;
- operate customer equipment;
- read real credentials;
- mutate service configuration;
- mutate firewall rules;
- restart services;
- deploy code;
- execute arbitrary shell commands derived from the synthetic payload.

The exercise harness may operate only on its own synthetic fixture and its own
temporary evidence directory.

## Synthetic fixture

The future implementation must version a deterministic fixture representing:

- event identifier;
- source classification as untrusted;
- synthetic payload;
- synthetic credential marker;
- affected logical component;
- expected authorization boundary.

The synthetic credential marker must be obviously fake and must not resemble a
real reusable secret.

Suggested artifact:

`tools/security/fixtures/rsk-p0-005-ttx-001.json`

## Exercise harness

The future repository-only implementation should provide a dedicated harness,
for example:

`tools/security/validate-rsk-p0-005-incident-exercise.py`

and a repository validator, for example:

`tools/security/validate-rsk-p0-005-incident-exercise-repository.sh`

These names are design targets and may be adjusted only if repository
inspection identifies an existing equivalent artifact that should be reused.

Do not create a duplicate harness when an equivalent implementation already
exists.

## Exercise record

A future execution must create a synthetic incident record containing at least:

- `incident_id`;
- exercise ID;
- UTC timestamp;
- source;
- affected component;
- assigned severity;
- severity rationale;
- categories;
- responder roles;
- detection record;
- containment decision;
- evidence inventory;
- evidence SHA-256 values;
- investigation conclusion;
- eradication decision;
- recovery decision;
- validation result;
- postmortem;
- corrective actions;
- residue check.

## Evidence requirements

Evidence must be synthetic or metadata-only.

No real operational evidence belongs in the exercise.

At minimum preserve:

- fixture SHA-256;
- harness SHA-256;
- exercise result;
- incident record SHA-256;
- generated evidence manifest SHA-256;
- final residue status.

Raw synthetic payload may remain versioned only if it contains no real secret
or confidential data.

## Containment behavior

The exercise should demonstrate a containment decision such as:

- deny privileged execution;
- maintain human-approval requirement;
- prevent arbitrary shell use;
- preserve the synthetic event;
- prevent automatic promotion of untrusted information;
- escalate the synthetic credential indicator.

No real credential revocation is performed.

## Investigation requirements

The exercise must distinguish:

- observed fact;
- hypothesis;
- simulated impact;
- confirmed exercise outcome.

A synthetic indicator must never be reported as a real compromise.

## Eradication/recovery semantics

Because the exercise is synthetic, eradication and recovery operate on
exercise state only.

They must not modify runtime state.

The exercise should demonstrate the decision process and record what would
require separate production authorization in a real incident.

## Validation criteria

PASS requires all of the following:

1. deterministic synthetic fixture;
2. unique incident ID;
3. severity assigned with rationale;
4. responder roles identified;
5. detection recorded;
6. classification recorded;
7. containment recorded;
8. synthetic evidence preserved with hashes;
9. investigation record present;
10. eradication decision present;
11. recovery decision present;
12. validation performed;
13. postmortem produced;
14. corrective actions recorded;
15. no real credential used;
16. no production access;
17. no PostgreSQL access;
18. no model/Qwen access;
19. no network operation;
20. no real equipment access;
21. no unauthorized shell execution;
22. zero unexplained residue.

## Fail semantics

Any failed requirement produces:

`EXERCISE=FAIL`

On failure:

`STOP -> PRESERVE -> ROOT CAUSE -> FIX VERSIONED ARTIFACT -> NEW AUTHORIZATION -> RE-EXERCISE`

There is no automatic retry.

## Repository-first sequence

Required implementation sequence:

1. inspect repository for an existing equivalent exercise/harness;
2. reuse rather than duplicate when equivalent;
3. implement fixture and harness repository-only;
4. validate fixture/harness without executing the tabletop;
5. commit implementation;
6. document repository validation;
7. request explicit authorization for exercise execution;
8. execute exactly one controlled synthetic exercise;
9. preserve evidence;
10. classify PASS/FAIL;
11. reconcile RSK-P0-005 only after successful evidence review.

## Risk closure rule

This design does not close RSK-P0-005.

Even a future tabletop PASS does not automatically alter the security
checklist.

Risk state changes require an explicit reconciliation checkpoint after evidence
review.

## NEXT_ACTION

`IMPLEMENT_RSK_P0_005_SYNTHETIC_EXERCISE_HARNESS_REPOSITORY_ONLY`

## Preserved validator incident

The first semantic-validation pass stopped after documentation had already been
written because the validator normalized whitespace around `/` in document
content but did not apply the same normalization to its expected markers.

Example:

`PLAN_APPROVED / EXERCISE_DESIGN_PROPOSED`

was normalized in the document to:

`PLAN_APPROVED/EXERCISE_DESIGN_PROPOSED`

while the expected marker retained spaces around `/`.

Classification:

`VALIDATOR_FALSE_NEGATIVE / SLASH_NORMALIZATION_EXPECTED_MARKER_BUG`

No source requirement, approved plan, exercise boundary or runtime state was
changed because of this validator failure.

The corrected continuation canonicalizes both document text and expected
markers before comparison.
