# Inventário sanitizado de atividades de tratamento — Mímir v1

Data: 2026-10-02
Escopo: metadados sanitizados; nenhum dado pessoal bruto, registro de cliente,
credencial, segredo ou conteúdo de sessão está incluído.
Estado: `PENDING_COMPETENT_REVIEW`
Risco: `RSK-P0-003 = OPEN / BLOCKER`

## Regras do registro

`Legal-basis decision state` não é inferido da finalidade e permanece
`PENDING_COMPETENT_REVIEW` sem decisão humana versionada. `International-transfer
state: NOT_PROVEN` representa ausência de prova, nunca “não”. Retenção referencia
`docs/OPERATIONS_RETENTION.md`; direitos e incidentes seguem
`docs/PRIVACY_GOVERNANCE.md`, `docs/INCIDENT_RESPONSE.md` e
`docs/cybersecurity/INCIDENT_REPORT_MODEL.md`. Não há purge automático.

## PA-V1-001

- Activity ID: PA-V1-001
- Activity name: OpenClaw conversational interaction through Telegram
- Activity owner: Processing Activity Owner — conversational channels; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_ACTIVE
- Purpose: Receive and return authorized conversational interactions through the configured channel.
- Categories of data: Message metadata and content supplied in an authorized interaction; authentication/channel identifiers.
- Categories of data subjects: Authorized operators and conversation participants.
- Source: Telegram channel through OpenClaw.
- Systems/repositories involved: Telegram; OpenClaw Gateway; conversational session store; repository contains metadata only.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Telegram/provider role NOT_PROVEN; OpenClaw local role PENDING_COMPETENT_REVIEW
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Allowlist, channel identity separation, least context, no raw content in Git.
- Access roles: Authorized channel operator; OpenClaw service role; administrators under least privilege.
- Sharing/recipients: Telegram/provider involvement NOT_PROVEN; authorized Mímir components.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; conversational duration decision PENDING_COMPETENT_REVIEW
- Retention trigger: Receipt/creation of the authorized interaction.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved; any exception requires competent review.
- Deletion/disposal rule: No automatic action; authorized reviewed procedure required.
- Backup interaction: NOT_PROVEN; backup does not independently authorize deletion.
- Hold state: NOT_PROVEN; preserve when an authorized hold applies.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Allowlist, fail-closed identity, output inspection and no secrets in Git.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: Provider Telegram; evidence and approval state NOT_PROVEN.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/TELEGRAM_INTEGRATION.md; docs/ARCHITECTURE.md; docs/CONVERSATIONAL_SECURITY.md; docs/STATUS.md
- Third-party provider: Telegram
- Third-party role: NOT_PROVEN
- Third-party data categories: Conversation and channel metadata; exact scope NOT_PROVEN
- Third-party purpose: Channel transport; competent confirmation PENDING_COMPETENT_REVIEW
- Third-party minimization: Allowlist and minimum channel scope; provider behavior NOT_PROVEN
- Processing/storage location status: NOT_PROVEN
- Subprocessor status: NOT_PROVEN
- DPA/contract review state: NOT_PROVEN
- Incident notification obligation state: NOT_PROVEN
- Third-party retention/deletion state: NOT_PROVEN
- Exit/offboarding state: NOT_PROVEN
- Third-party competent approval state: PENDING_COMPETENT_REVIEW

## PA-V1-002

- Activity ID: PA-V1-002
- Activity name: Semantic memory search with local embedding and PostgreSQL
- Activity owner: Processing Activity Owner — memory search; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_ACTIVE
- Purpose: Retrieve relevant governed memory for authorized interactions.
- Categories of data: Search query, embeddings, memory metadata and governed memory content.
- Categories of data subjects: Users and persons referenced in governed memory.
- Source: Authorized conversational query and permanent-memory records.
- Systems/repositories involved: OpenClaw mimir-memory plugin; local embedding; PostgreSQL.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local components; external processing NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Semantic top-k retrieval, scoped API, least privilege and no direct broad read.
- Access roles: Authorized user context; mimir_app; database administrators under least privilege.
- Sharing/recipients: Authorized Mímir components; external recipient NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; memory-specific decision PENDING_COMPETENT_REVIEW
- Retention trigger: Memory creation/promotion and search audit creation.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved; governed exception required.
- Deletion/disposal rule: No automatic purge; competent authorized process required.
- Backup interaction: Database backups may retain records; exact state NOT_PROVEN.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Local embedding, PostgreSQL least privilege, scoped retrieval and provenance.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — documented current path is local; deployment verification remains outside this package.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/ARCHITECTURE.md; docs/STATUS.md; docs/CONVERSATIONAL_SECURITY.md

## PA-V1-003

- Activity ID: PA-V1-003
- Activity name: Durable permanent memory storage and governed retrieval
- Activity owner: Processing Activity Owner — permanent memory; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_ACTIVE
- Purpose: Store and retrieve reviewed durable memory with provenance.
- Categories of data: Governed memory content, provenance, classification, hashes and review metadata.
- Categories of data subjects: Users and persons referenced by approved memory records.
- Source: Reviewed memory candidates and authorized handoff.
- Systems/repositories involved: PostgreSQL mimir_memory; memory API; repository metadata only.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local PostgreSQL role; external party NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Human review, deduplication, provenance, classification and no automatic promotion.
- Access roles: Approved memory workflow roles; mimir_app; database administrator.
- Sharing/recipients: Authorized retrieval path only; external recipients NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; permanent-memory duration PENDING_COMPETENT_REVIEW
- Retention trigger: Approved promotion to permanent memory.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved; correction preserves provenance/history.
- Deletion/disposal rule: No automatic purge; explicit competent procedure required.
- Backup interaction: Backup lifecycle is separate and NOT_PROVEN for this activity.
- Hold state: NOT_PROVEN; authorized hold prevents disposal.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Review gate, provenance, least privilege, protected sources and audit trail.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — repository design uses local storage; environment proof is outside scope.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/ARCHITECTURE.md; docs/CONVERSATIONAL_SECURITY.md; docs/STATUS.md

## PA-V1-004

- Activity ID: PA-V1-004
- Activity name: Document ingestion into the memory-event pipeline
- Activity owner: Processing Activity Owner — document ingestion; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_AVAILABLE_NOT_ACTIVE
- Purpose: Stage authorized documents as governed memory events for later review.
- Categories of data: Document content, source reference, hash, classification and ingestion metadata.
- Categories of data subjects: Authors and persons referenced in authorized documents.
- Source: Explicitly authorized local documents.
- Systems/repositories involved: Ingestion tooling; memory_events; PostgreSQL design.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local pipeline; external party NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Source authorization, classification, hashing and review before promotion.
- Access roles: Authorized ingestor, reviewer and least-privilege database role.
- Sharing/recipients: Authorized local pipeline; external recipients NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; ingestion duration PENDING_COMPETENT_REVIEW
- Retention trigger: Authorized document ingestion event.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved.
- Deletion/disposal rule: No automatic purge; competent reviewed action only.
- Backup interaction: NOT_PROVEN; backup retention handled separately.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Classification, provenance, hashes, review gate and protected storage.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — local repository design, not activated.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/ARCHITECTURE.md; docs/STATUS.md; docs/CONVERSATIONAL_SECURITY.md

## PA-V1-005

- Activity ID: PA-V1-005
- Activity name: OpenClaw session capture v2 through supported history interfaces
- Activity owner: Processing Activity Owner — session capture; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_AVAILABLE_NOT_ACTIVE
- Purpose: Capture eligible completed sessions through supported interfaces for governed ingestion.
- Categories of data: Session metadata and eligible user/assistant transcript content.
- Categories of data subjects: Authorized session participants and referenced persons.
- Source: OpenClaw supported sessions/history interface.
- Systems/repositories involved: OpenClaw session API; v2 capture tooling; protected ingestion boundary.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: OpenClaw local runtime role PENDING_COMPETENT_REVIEW
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Completed/owned session eligibility, exclusion rules, dry-run and content hashing.
- Access roles: Authorized capture operator and protected ingestion service role.
- Sharing/recipients: Protected local ingestion path; external recipient NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; session duration PENDING_COMPETENT_REVIEW
- Retention trigger: Eligible session capture/ingestion event.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved; ineligible messages remain excluded.
- Deletion/disposal rule: No automatic purge; competent reviewed action only.
- Backup interaction: OpenClaw/session backup behavior NOT_PROVEN.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Supported interface, owner provenance, filtering, dry-run and protected handoff.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — local supported interface; activation not proven.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/INGESTAO_SESSOES.md; docs/ARCHITECTURE.md; docs/STATUS.md

## PA-V1-006

- Activity ID: PA-V1-006
- Activity name: Protected OpenClaw session ingestion v2
- Activity owner: Processing Activity Owner — protected ingestion; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_LAB_OR_VALIDATION_ONLY
- Purpose: Ingest protected session sources with provenance and without broad application read access.
- Categories of data: Protected transcript, session/source identifiers, hashes and event metadata.
- Categories of data subjects: Authorized session participants and referenced persons.
- Source: Approved v2 session capture output.
- Systems/repositories involved: ingest_session_v2 design; session_sources; memory_events; PostgreSQL LAB.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local LAB pipeline; external party NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Protected table, hashes/provenance, revocation of legacy ingress and no raw output.
- Access roles: Dedicated writer, protected reader and administrators under least privilege.
- Sharing/recipients: Protected local components only in LAB/validation.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; protected-session duration PENDING_COMPETENT_REVIEW
- Retention trigger: Authorized protected ingestion.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: Synthetic LAB data may be disposed under canonical laboratory rules.
- Deletion/disposal rule: No production purge; synthetic LAB cleanup only after evidence requirements.
- Backup interaction: LAB backup/restore evidence separate; production interaction NOT_PROVEN.
- Hold state: NOT_PROVEN; hold check required before disposal.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Protected read, least privilege, idempotency, integrity hashes and LAB guards.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — local LAB design.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/INGESTAO_SESSOES.md; docs/ARCHITECTURE.md; docs/STATUS.md

## PA-V1-007

- Activity ID: PA-V1-007
- Activity name: Protected local consolidation with Qwen
- Activity owner: Processing Activity Owner — protected consolidation; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_LAB_OR_VALIDATION_ONLY
- Purpose: Generate constrained memory candidates from protected events for human review.
- Categories of data: Protected source content, event identifiers, hashes and candidate metadata.
- Categories of data subjects: Session participants and persons referenced in protected sources.
- Source: Protected local memory-event pipeline.
- Systems/repositories involved: Protected consolidator; local Qwen/llama.cpp design; PostgreSQL LAB.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local model runtime; software-provider processing NOT_PROVEN and not inferred
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Local constrained inference, schema validation, no automatic promotion and sanitized evidence.
- Access roles: Protected consolidator service role; authorized reviewer; LAB operator.
- Sharing/recipients: Local LAB components; no external recipient proven.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; candidate duration PENDING_COMPETENT_REVIEW
- Retention trigger: Candidate generation or validation event.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: Synthetic LAB cleanup follows canonical rules; no real-session exception approved.
- Deletion/disposal rule: No automatic purge; authorized LAB cleanup only for synthetic data.
- Backup interaction: LAB backup state NOT_PROVEN for this activity.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Local-only boundary, grammar/schema validation, fail closed and human promotion gate.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — inference path is documented as local LAB; software origin does not prove external processing.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/ARCHITECTURE.md; docs/CONVERSATIONAL_SECURITY.md; docs/STATUS.md

## PA-V1-008

- Activity ID: PA-V1-008
- Activity name: Operational inventory and evidence layer
- Activity owner: Processing Activity Owner — operations; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_LAB_OR_VALIDATION_ONLY
- Purpose: Record governed operational inventory, actions, evidence, reports and audit metadata.
- Categories of data: Asset/operation metadata, authorized actor references, evidence metadata and reports.
- Categories of data subjects: Authorized operators and persons referenced in minimized evidence.
- Source: Authorized operational workflow and adapters.
- Systems/repositories involved: ops_* schema/API design; adapters; PostgreSQL LAB; repository metadata.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local operational layer; equipment/provider roles NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Redaction, append-only records, scoped adapters and metadata-only Git evidence.
- Access roles: mimir_ops design, authorized operator, reviewer and database administrator.
- Sharing/recipients: Authorized operational roles; client/equipment recipients NOT_PROVEN.
- Retention rule: docs/OPERATIONS_RETENTION.md is canonical; persistent v1 records have no automatic expiration
- Retention trigger: Creation of operational journal/evidence/report/audit record.
- Duration or decision state: Indefinite during v1 pending later versioned competent policy.
- Exceptions: Synthetic LAB disposal only under docs/OPERATIONS_RETENTION.md.
- Deletion/disposal rule: Automatic purge prohibited; administrative purge not implemented.
- Backup interaction: Backups do not authorize primary deletion; expiration policy separate.
- Hold state: Preserve failed/interrupted and any authorized hold; specific hold NOT_PROVEN.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Append-only design, redaction, least privilege, authorization and evidence integrity.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_PROVEN — adapters/equipment may involve external parties but no deployment is approved here.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/OPERATIONS_RETENTION.md; docs/ARCHITECTURE.md; docs/STATUS.md

## PA-V1-009

- Activity ID: PA-V1-009
- Activity name: Contradiction inspection and operational memory handoff
- Activity owner: Processing Activity Owner — memory governance; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: CURRENT_V1_LAB_OR_VALIDATION_ONLY
- Purpose: Inspect contradictions and hand off reviewed operational knowledge to memory governance.
- Categories of data: Candidate memory metadata, provenance, contradiction findings and operational references.
- Categories of data subjects: Operators and persons referenced in reviewed knowledge.
- Source: Operational records and reviewed candidate-memory workflow.
- Systems/repositories involved: memory_handoff design; contradiction tooling; permanent-memory review path.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local review pipeline; external party NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Metadata handoff, deduplication, contradiction review, provenance and no auto-promotion.
- Access roles: Authorized operations owner, memory reviewer and security reviewer.
- Sharing/recipients: Governed local memory workflow only.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; handoff duration PENDING_COMPETENT_REVIEW
- Retention trigger: Creation of handoff/candidate/review record.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved; superseded facts retain provenance.
- Deletion/disposal rule: No automatic purge; competent reviewed procedure required.
- Backup interaction: NOT_PROVEN; backup policy remains separate.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Human review, contradiction checks, provenance and separation from authorization memory.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — local LAB/validation workflow.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/ARCHITECTURE.md; docs/CONVERSATIONAL_SECURITY.md; docs/STATUS.md; docs/OPERATIONS_RETENTION.md

## PA-V1-010

- Activity ID: PA-V1-010
- Activity name: Historical external NVIDIA/Nemotron consolidation path
- Activity owner: Processing Activity Owner — historical memory pipeline; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: HISTORICAL_OR_LEGACY
- Purpose: Preserve governance metadata about the historical external consolidation design; not a current provider path.
- Categories of data: Historically contemplated protected content and candidate metadata; actual processing state NOT_PROVEN.
- Categories of data subjects: Historical session participants and referenced persons, if the path was used; NOT_PROVEN.
- Source: Historical consolidation design and repository documentation.
- Systems/repositories involved: Historical NVIDIA/Nemotron path; memory-event design.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: NVIDIA/Nemotron historical provider role NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Historical path blocked for confidential sessions; not treated as current.
- Access roles: Historical design roles NOT_PROVEN.
- Sharing/recipients: Historical external provider involvement NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; historical-data state NOT_PROVEN
- Retention trigger: Historical event creation, if any; NOT_PROVEN.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved.
- Deletion/disposal rule: No automatic action; first prove scope and obtain authorization.
- Backup interaction: NOT_PROVEN.
- Hold state: NOT_PROVEN; preserve evidence if discovered under authorized review.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Confidential classification block and historical/non-current designation.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: Historical NVIDIA/Nemotron; all current approval/operation facts NOT_PROVEN.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/INGESTAO_SESSOES.md; docs/ARCHITECTURE.md
- Third-party provider: NVIDIA/Nemotron historical path; current provider status NOT_PROVEN
- Third-party role: NOT_PROVEN
- Third-party data categories: Historical contemplated protected content; actual scope NOT_PROVEN
- Third-party purpose: Historical consolidation; no current purpose approved
- Third-party minimization: Confidential-source block documented; provider controls NOT_PROVEN
- Processing/storage location status: NOT_PROVEN
- Subprocessor status: NOT_PROVEN
- DPA/contract review state: NOT_PROVEN
- Incident notification obligation state: NOT_PROVEN
- Third-party retention/deletion state: NOT_PROVEN
- Exit/offboarding state: NOT_PROVEN
- Third-party competent approval state: PENDING_COMPETENT_REVIEW

## PA-V1-011

- Activity ID: PA-V1-011
- Activity name: Legacy file-backed sessions.json/JSONL session ingestion
- Activity owner: Processing Activity Owner — legacy ingestion; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: HISTORICAL_OR_LEGACY
- Purpose: Record the superseded file-backed ingestion path for governance and migration traceability.
- Categories of data: Legacy session metadata and transcript content.
- Categories of data subjects: Historical session participants and referenced persons.
- Source: Legacy sessions.json and JSONL files.
- Systems/repositories involved: Legacy collector; ingest_session contract; memory-event pipeline.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Local legacy tooling; external party NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Legacy path is not promoted as current; protected-source classification and provenance.
- Access roles: Historical authorized ingestion roles NOT_PROVEN.
- Sharing/recipients: Historical local pipeline; external recipient NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; legacy-file duration PENDING_COMPETENT_REVIEW
- Retention trigger: Historical file/session ingestion event.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: None approved.
- Deletion/disposal rule: No automatic purge; inventory and competent authorization required.
- Backup interaction: Legacy backups NOT_PROVEN.
- Hold state: NOT_PROVEN; preserve under authorized hold.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Historical designation, protected classification and migration to supported interface.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: NOT_APPLICABLE_WITH_JUSTIFICATION — file-backed local legacy path.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/INGESTAO_SESSOES.md; docs/ARCHITECTURE.md; docs/STATUS.md

## PA-V1-012

- Activity ID: PA-V1-012
- Activity name: Planned additional conversational channels
- Activity owner: Processing Activity Owner — future channels; designation PENDING_COMPETENT_REVIEW
- Lifecycle state: PLANNED_NOT_IMPLEMENTED
- Purpose: Govern future architecture for WhatsApp, webchat, email, voice/audio and other unproven channels before implementation.
- Categories of data: Potential message, identity, channel, voice/audio and attachment data; exact scope NOT_PROVEN.
- Categories of data subjects: Potential authorized users, correspondents and referenced persons; NOT_PROVEN.
- Source: Future channels; no implementation proven.
- Systems/repositories involved: Planned channel adapters and OpenClaw boundary; implementation NOT_PROVEN.
- Controller role: PENDING_COMPETENT_REVIEW
- Operator/processor/third party: Future providers and roles NOT_PROVEN
- Legal-basis decision state: PENDING_COMPETENT_REVIEW
- Competent decision/evidence reference: No competent decision versioned; PENDING_COMPETENT_REVIEW
- Minimization controls: Per-channel identity/profile required before activation; voice never authenticates by itself.
- Access roles: To be defined and approved before implementation.
- Sharing/recipients: Future channel providers/recipients NOT_PROVEN.
- Retention rule: Refer to docs/OPERATIONS_RETENTION.md; channel-specific decision PENDING_COMPETENT_REVIEW
- Retention trigger: To be defined before implementation.
- Duration or decision state: PENDING_COMPETENT_REVIEW
- Exceptions: No activation or exception approved.
- Deletion/disposal rule: Must be defined and competently approved before implementation; no automatic purge.
- Backup interaction: NOT_PROVEN.
- Hold state: NOT_PROVEN; requirement must be defined before implementation.
- Competent approval state: PENDING_COMPETENT_REVIEW
- Security controls: Planned per-channel profile, external identity, input/output controls and human authorization.
- Data-subject-rights route: docs/PRIVACY_GOVERNANCE.md controlled rights flow.
- Incident-response route: docs/INCIDENT_RESPONSE.md and docs/cybersecurity/INCIDENT_REPORT_MODEL.md.
- Third-party dependency: Future providers NOT_PROVEN; presence in architecture is not implementation.
- International-transfer state: NOT_PROVEN
- Review date/state: 2026-10-02 / PENDING_COMPETENT_REVIEW
- Approval state: PENDING_COMPETENT_REVIEW
- Supporting repository evidence: docs/CONVERSATIONAL_SECURITY.md; docs/ARCHITECTURE.md
- Third-party provider: NOT_PROVEN
- Third-party role: NOT_PROVEN
- Third-party data categories: Potential channel/message/identity data; exact scope NOT_PROVEN
- Third-party purpose: Future channel transport; NOT_PROVEN
- Third-party minimization: Must be approved before implementation
- Processing/storage location status: NOT_PROVEN
- Subprocessor status: NOT_PROVEN
- DPA/contract review state: NOT_PROVEN
- Incident notification obligation state: NOT_PROVEN
- Third-party retention/deletion state: NOT_PROVEN
- Exit/offboarding state: NOT_PROVEN
- Third-party competent approval state: PENDING_COMPETENT_REVIEW
