# MIMIR-V1-RSK-P0-005-INCIDENT-RESPONSE-DESIGN-01

Date: 2026-10-02

Status:

`PROPOSED`

## Risk

`RSK-P0-005 — resposta a incidentes`

Current state:

`OPEN / BLOCKER`

No risk acceptance is introduced by this checkpoint.

## Existing controls

The project already contains technical controls relevant to incident handling:

- fail-closed execution;
- preservation of operational evidence;
- reconciliation of interrupted or uncertain interventions;
- explicit human approval boundaries;
- no automatic retry after uncertain EXECUTE results;
- restricted production changes;
- versioned security and operational evidence.

These controls are inputs to incident response, but they do not constitute a
formal incident-response program and do not close RSK-P0-005.

## Decision

Treat RSK-P0-005 using two separate deliverables:

1. a versioned formal incident-response plan;
2. a reproducible isolated synthetic/tabletop exercise with preserved evidence.

No production incident simulation is required.

## Required incident-response plan

The plan must define at minimum:

### Scope

Mímir v1 components and trust boundaries, including:

- OpenClaw/Gateway;
- Mímir memory;
- PostgreSQL;
- operational adapters;
- local model runtime;
- communication integrations;
- repository/build/release artifacts.

### Roles

At minimum:

- incident coordinator;
- technical responder;
- evidence custodian;
- system/service owner;
- privacy/governance escalation owner.

One person may currently occupy multiple roles, but the responsibilities must
remain explicitly distinct.

### Severity

Define objective severity classes based on impact to:

- confidentiality;
- integrity;
- availability;
- unauthorized execution;
- credential exposure;
- protected-memory integrity;
- equipment/control-plane impact.

### Lifecycle

The documented lifecycle must include:

`detect -> classify -> contain -> preserve evidence -> investigate -> eradicate -> recover -> validate -> postmortem`

### Mandatory safety rules

- fail closed when execution state is uncertain;
- never automatically repeat potentially mutating actions;
- preserve evidence before destructive remediation where feasible;
- never place credentials or confidential raw evidence in Git;
- production mutation requires explicit authorization;
- compromised credentials require isolation/revocation through an authorized
  operational path;
- suspected personal-data incidents must be escalated to the competent
  governance/privacy owner rather than receiving an automated legal conclusion.

### Evidence

The plan must define evidence identity using, where applicable:

- UTC timestamp;
- incident identifier;
- source;
- affected component;
- action/event classification;
- authorization identity;
- SHA-256;
- disposition;
- recovery validation.

### Recovery

Recovery requires positive validation.

`SERVICE_RESTORED != INCIDENT_CLOSED`

### Closure

An incident may be closed only after:

- containment is verified;
- recovery is validated;
- evidence is preserved;
- residual actions are recorded;
- postmortem/review is completed or explicitly deferred by an authorized human.

## Required isolated exercise

The first exercise must remain synthetic and isolated.

It must not:

- change production;
- use production credentials;
- intentionally expose real secrets;
- operate real customer equipment;
- authorize arbitrary shell execution.

The scenario must exercise a meaningful Mímir-specific incident, such as:

- untrusted content attempting to influence privileged tool behavior;
- synthetic credential-exposure indication;
- attempted unauthorized operation;
- evidence preservation and containment;
- recovery validation.

The exercise validates the process, not only technical rejection.

## Exercise PASS criteria

At minimum:

- incident ID created;
- severity assigned;
- responder roles identified;
- detection recorded;
- containment decision recorded;
- evidence hashes preserved;
- no unauthorized production action;
- recovery/validation decision recorded;
- postmortem generated;
- lessons/actions recorded;
- zero unexplained residue.

## Failure semantics

A failed exercise is evidence.

On FAIL:

`STOP -> PRESERVE -> ROOT CAUSE -> FIX VERSIONED PROCESS/CODE -> NEW AUTHORIZATION -> RE-EXERCISE`

No automatic retry.

## RSK-P0-005 closure rule

This design does not close RSK-P0-005.

Technical closure may be proposed only after:

1. incident-response plan is versioned;
2. plan receives required human approval;
3. isolated exercise executes;
4. exercise evidence is preserved;
5. exercise result is PASS;
6. continuity/security documents are reconciled.

Until then:

`RSK-P0-005 = OPEN / BLOCKER`

## Preserved validator incident

The first design attempt stopped before any write because the semantic guard
looked for the contiguous phrase:

`plano formal de resposta a incidentes`

while the Markdown source wrapped the phrase across two lines.

Classification:

`VALIDATOR_FALSE_NEGATIVE / WHITESPACE_SENSITIVE_MARKER`

No repository mutation occurred in that failed attempt.

The corrected guard normalizes whitespace before semantic matching.

## Release boundary

This checkpoint does not authorize:

- Draft removal;
- merge;
- stable tag;
- production deployment.

## NEXT_ACTION

`IMPLEMENT_RSK_P0_005_INCIDENT_RESPONSE_PLAN_REPOSITORY_ONLY`
