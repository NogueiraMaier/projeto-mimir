# Plano Mestre de Execução — Mímir v1

Data de consolidação: 2026-09-24

Este documento é a lista mestre de atividades do Projeto Mímir v1. Ele existe para evitar perda de contexto, repetição de trabalho e mudanças fora de ordem. O estado detalhado de cada etapa deve ser atualizado aqui antes de avançar para a próxima fase.

## Regras de execução

1. Desenvolvimento e correção ficam na máquina local `gentoo-Dragon_IA`, usuário `jarvisdev`.
2. O VPS `gentoo-Dragon_vm` é usado para validação isolada, integração e futura implantação controlada.
3. O workspace ativo `/var/lib/openclaw/workspace` não deve receber `checkout`, `reset`, `clean`, `stash` ou troca de branch durante experimentos.
4. Validações no VPS devem usar checkout isolado em `/var/tmp` quando possível.
5. Nenhuma migration pode ser aplicada em ambiente persistente antes de existir versionada no Git.
6. Nenhuma alteração em produção deve ser feita sem autorização explícita e sem plano de rollback/restauração.
7. Cada etapa precisa registrar: precondições, ação, evidência, resultado, impacto e próximo passo.
8. PRs permanecem Draft até revisão final. Não fazer merge automaticamente.
9. Segredos, chaves privadas e credenciais não entram no Git.
10. Equipamentos reais começam em READ; EXECUTE só depois de homologação e aprovação específica.

## Origem desta rodada de correções

Durante uma atualização de documentação relacionada ao Maestro foi identificado que o estado documentado do Mímir não correspondia integralmente ao estado real do runtime e do banco. A partir daí foi aberta uma revisão técnica completa do Mímir antes de retomar a documentação superior.

A documentação do Maestro deve ser retomada somente após a estabilização dos marcos P0/P1 abaixo, para que descreva o Mímir real e não um estado histórico.

## Estado consolidado

### P0 — Integridade histórica e versionamento

- [x] Recuperar migrations de memória 009–012 a partir das fontes históricas.
- [x] Conferir SHA-256 das oito fontes apply/dry-run recuperadas.
- [x] Versionar 009–012 no repositório.
- [x] Renumerar a migration operacional conflitante de 009 para 013.
- [x] Fazer a 013 exigir versão 12 e recusar reaplicação silenciosa.
- [x] Registrar regra: nenhuma migration em ambiente persistente antes de existir no Git.
- [x] Resolver a ausência histórica da migration 001 no Git ou documentar bootstrap canônico equivalente.

### P0 — Validador e segurança da branch operacional

- [x] Corrigir o validador para respeitar least privilege de `mimir_app` em `schema_version`.
- [x] Tratar `dist/index.js` ausente em source checkout como PARTIAL quando `dist/` for artefato de build ignorado/não versionado.
- [x] Testes locais aprovados.
- [x] Validação read-only no VPS concluída com 0 failed checks.
- [x] Produção permaneceu sem migration 013 e sem role `mimir_ops`.

### P0 — Runtime real do OpenClaw / memória nativa

- [x] Confirmar OpenClaw 2026.9.5 ativo via OpenRC.
- [x] Confirmar configuração válida.
- [x] Confirmar plugin `mimir-memory` carregado em runtime.
- [x] Confirmar versão runtime do plugin 0.2.6.
- [x] Aceitar explicitamente as capacidades atuais do plugin.
- [x] Identificar que embeddings locais antigos estavam incompatíveis com o runtime atual.
- [x] Configurar provider oficial `llama-cpp` em modo Managed local server para embeddings.
- [x] Manter o modelo de chat atual inalterado durante essa configuração.
- [x] Confirmar `embeddingProbe.ok=true`, runtime ready e 768 dimensões.
- [x] Fazer backup consistente do SQLite antes de reconstruir o índice.
- [x] Reindexar memória nativa com sucesso.
- [x] Confirmar 9/9 arquivos, 77 chunks, `dirty=false`, índice vetorial complete, `semanticAvailable=true` e `indexIdentity.status=valid`.
- [x] Corrigir metadata drift do plugin: runtime 0.2.6 versus Recorded version 0.1.0, sem reinstalação cega.
- [x] Definir `plugins.allow` explicitamente para plugins confiáveis atualmente habilitados, preservando o conjunto runtime.

### P0 — Migration operacional 013 em laboratório isolado

- [x] Confirmar produção em versões 1–12, sem versão 13.
- [x] Confirmar `mimir_ops` ausente em produção.
- [x] Confirmar extensões `pgcrypto` e `vector`.
- [x] Criar cluster PostgreSQL 17 temporário em `/var/tmp/mimir-pg13-lab`.
- [x] Restaurar somente schema real + `schema_version`, sem copiar memórias/sessões.
- [x] Aplicar `013_operational_inventory.sql` somente no laboratório.
- [x] Confirmar versões 1–13 no laboratório.
- [x] Confirmar 15 tabelas `ops_*`.
- [x] Confirmar `mimir.ops_api(jsonb)`.
- [x] Confirmar identidade `mimir_ops` criada no schema como desabilitada.
- [x] Confirmar role cluster-global `mimir_ops` ainda ausente.
- [x] Confirmar novamente produção intacta: versão 13=false, role `mimir_ops`=false.
- [x] Aplicar e validar `013_operational_role.sql` somente no cluster temporário.
- [x] Verificar grants mínimos efetivos da role `mimir_ops`.
- [x] Verificar ausência de SELECT/INSERT/UPDATE/DELETE direto nas tabelas ops.
- [x] Validar autenticação/identidade peer de laboratório sem reutilizar a identidade do OpenClaw.
- [x] Testar a API `mimir.ops_api(jsonb)` com dados sintéticos.
- [x] Testar constraints e rejeições de segurança com casos negativos.
- [x] Testar fluxo READ sintético completo.
- [x] Implementar hardening temporal de `completed_at >= started_at`.
- [x] Validar hardening temporal no `MIMIR-V1-013-LAB-06B`.
- [x] Testar fluxo EXECUTE somente com dublês/simulação, sem equipamento real.
- [x] Testar backup/restauração do laboratório.
- [x] Desligar e remover o cluster temporário somente após coleta de evidências.

### P1 — Memória permanente PostgreSQL

- [x] Fechar escrita controlada do cliente de ingestão de sessões, hoje ainda parcial/dry-run.
- [x] Validar consolidação local de sessões de ponta a ponta.
- [x] Validar deduplicação.
- [x] Validar detecção de contradições.
- [x] Validar revisão humana.
- [x] Validar fluxo candidate → active.
- [x] Validar geração de embedding e recuperação semântica após promoção.
- [x] Validar auditoria/proveniência.
- [x] Integrar `memory_handoff` operacional com o fluxo humano de memória, sem promoção automática.

### P1 — Camada operacional

- [x] Canal secundário Telegram: conversa remota e notificações controladas do Mímir, conforme `docs/TELEGRAM_INTEGRATION.md`.
- [x] Demonstrar backup/restauração real por adapter.
- [x] Definir reconciliação de intervenção interrompida.
- [x] Definir política de retenção de evidências/relatórios.
- [x] Homologar primeiro equipamento de laboratório em READ.
- [x] Homologar `set-hostname` transitório no adapter generic-linux em laboratório.
- [x] Manter MikroTik inicialmente em diagnóstico/READ.
- [x] Delimitar a v1: MikroTik permanece READ e `generic-linux` EXECUTE restrito; MikroTik EXECUTE, FiberHome, H3C, Intelbras e outros ficam para pós-v1.

### P1 — Reprodutibilidade e release

- [ ] Atualizar STATUS/ROADMAP/OPERATIONS/RUNBOOK conforme cada marco concluído.
- [x] Adicionar CI para testes de memória, operações, validador, plugin e lint/syntax.
- [x] Executar suíte completa em checkout limpo.
- [x] Testar restauração a partir dos artefatos/versionamento disponíveis.
- [x] Criar checklist final de segurança.
- [x] Revisar PR #1.
- [ ] Retirar Draft somente após validação final.
- [ ] Merge somente com autorização explícita.
- [ ] Criar tag estável da v1.
- [ ] Retomar e concluir a documentação do Maestro usando o estado final validado do Mímir.

## Checkpoint atual

**MIMIR-V1-RSK-P0-003-HUMAN-APPROVAL-AND-RECONCILIATION-01 — LOCAL_RECONCILIATION_COMPLETE / REMOTE_GUARD_PENDING em 2026-10-03.**

- source HEAD: `0574ab8e6c15eb62fd74c066a18b508b576c32e9`;
- approved implementation commit:
  `34f78b80cd77e675a699001e43e0cf556ad091c0`;
- approved repository-validation checkpoint:
  `0574ab8e6c15eb62fd74c066a18b508b576c32e9`;
- human approval: `APPROVED` for internal Project Mímir governance;
- approver identity reference: `Nogueira Maier`;
- roles: Project/System Owner and Privacy Governance Owner;
- `ROLE_OVERLAP = PRESENT`; `DECLARED_CONFLICT = NO_KNOWN_CONFLICT`;
- independent review explicitly required: `NO`, under the documented
  conflict-triggered compensating-review rule;
- Phase A: validator PASS, tests 10/10 PASS, `git diff --check` PASS;
- no lifecycle, legal-basis, international-transfer, `NOT_PROVEN`, DPO or
  production state was promoted;
- local technical state: `CLOSED / TECHNICALLY_TREATED /
  PRIVACY_GOVERNANCE_APPROVED`;
- `RISK_ACCEPTANCE = NOT_USED`; `DPO_STATE = PENDING_COMPETENT_REVIEW`;
- `LEGAL_CONCLUSION = NO`; `LGPD_COMPLIANCE_CLAIM = NO`;
- `PRODUCTION_VALIDATION = NO`;
- RSK-P0-004 remains an independent blocker;
- no fetch, commit or push in this phase.

**NEXT_ACTION atual:** `FRESH_FETCH_GUARD_BEFORE_COMMIT_RSK_P0_003_HUMAN_APPROVAL_AND_RECONCILIATION`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-REPOSITORY-VALIDATION-01

**MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED / HUMAN_APPROVAL_PENDING em 2026-10-03.**

- implementation commit: `34f78b80cd77e675a699001e43e0cf556ad091c0`;
- repository-only validation PASS; tests 10/10 PASS; activities 12/12;
- `RSK-P0-003 = OPEN / BLOCKER` at that checkpoint;
- competent human approval was still pending.

**NEXT_ACTION histórico:** `REQUEST_HUMAN_APPROVAL_RSK_P0_003_PRIVACY_GOVERNANCE_PACKAGE`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-TREATMENT-DESIGN-01

**MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-TREATMENT-DESIGN-01 — PROPOSED em 2026-10-02.**

- source HEAD: `f9b2ad20dd58e43cafb4550eb288b036816ac516`;
- tratamento repository-first definido sem aceite de risco;
- governança canônica, inventário sanitizado e validator repository-only
  definidos como artefatos-alvo;
- aprovação humana competente definida como etapa separada;
- `RSK-P0-003 = OPEN / BLOCKER`.

**NEXT_ACTION histórico:** `IMPLEMENT_RSK_P0_003_PRIVACY_GOVERNANCE_REPOSITORY_ONLY`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-005-SYNTHETIC-TABLETOP-RECONCILIATION-01

**MIMIR-V1-RSK-P0-005-SYNTHETIC-TABLETOP-RECONCILIATION-01 — CLOSED / TECHNICALLY_TREATED / SYNTHETIC_TABLETOP_VALIDATED em 2026-10-02.**

- source HEAD at execution: `80f0c42330ce6bf3365c974d4f3896234098b70f`;
- exercise ID: `MIMIR-IR-TTX-001`;
- execution timestamp: `2026-10-02T15:40:38Z`;
- invocation count: `1`;
- single-execution authorization: `CONSUMED`;
- result: `PASS`;
- failed requirements: `0`;
- residue: `ZERO_UNEXPLAINED`;
- automatic retry: `NO`;
- execution log SHA-256: `90d203a5d36629c6da7e112f50c7abce82e04ce665df7338558d4fbef8d7489d`;
- incident record SHA-256: `fe75525cb14f2a7e041e62ba1a34dd7d348032b1f4333c49601fd474fd5c56bf`;
- evidence manifest SHA-256: `063f58968d453b47305fcd2525116c178022de5ed5555963f4c014e62cd0be79`;
- formal approved incident-response plan remains unchanged:
  `185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`;
- fixture SHA-256: `2c93342f96bc6e925e5a15d6b8e8fe85d36a051921a3644050dd31bd36f7ecec`;
- harness SHA-256: `affc32a869d9a5f97eb2fd1567cf601c8fe6c8e5bfc033551e81cda150bccd94`;
- validator SHA-256: `d8c1218cfd787879c03c81b41f4c24bea00b2e74fb1c047afeb36cbf6a5673a0`;
- no Qwen, PostgreSQL, network, SSH, production or real-equipment access;
- no real credential, service mutation, firewall mutation or unauthorized shell;
- `RSK-P0-005 = CLOSED / TECHNICALLY_TREATED / SYNTHETIC_TABLETOP_VALIDATED`;
- closure is technical treatment, not risk acceptance;
- production validation / legal compliance are not claimed;
- historical OPEN/BLOCKER records remain preserved;
- RSK-P0-003 and RSK-P0-004 continue to block release;
- Draft removal / merge / tag / deploy remain blocked.

`TABLETOP_PASS + FINAL_RECONCILIATION = RSK-P0-005_TECHNICAL_TREATMENT_CLOSED`

**NEXT_ACTION atual:** `INSPECT_RSK_P0_003_CURRENT_GOVERNANCE_STATE`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-005-TABLETOP-HARNESS-REPOSITORY-VALIDATION-01

**MIMIR-V1-RSK-P0-005-TABLETOP-HARNESS-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED em 2026-10-02.**

- implementation HEAD: `392810da4c1529ca365e8b38cfb78132fb8558d8`;
- exercise ID: `MIMIR-IR-TTX-001`;
- fixture SHA-256: `2c93342f96bc6e925e5a15d6b8e8fe85d36a051921a3644050dd31bd36f7ecec`;
- harness SHA-256: `affc32a869d9a5f97eb2fd1567cf601c8fe6c8e5bfc033551e81cda150bccd94`;
- repository validator SHA-256: `d8c1218cfd787879c03c81b41f4c24bea00b2e74fb1c047afeb36cbf6a5673a0`;
- repository-only validation PASS;
- validation used only `--validate-fixture-only`;
- tabletop execution path absent from repository validator;
- validation evidence SHA-256: `7e56f47342b874db48783cd2774758923213ddd3cc1c0e06bcb2554e375a8157`;
- prior partial-write recovery manifest SHA-256: `80c08c8ca9e113eb1134f11e17ace6700ba8c583608d3b3347775b3d7885dc88`;
- tabletop NOT executed;
- execution NOT authorized;
- no Qwen, PostgreSQL, network, production or real-equipment access;
- `RSK-P0-005` remains `OPEN / BLOCKER`;
- Draft removal / merge / tag / deploy remain blocked.

`HARNESS_REPOSITORY_VALIDATED != TABLETOP_EXECUTED`

**NEXT_ACTION atual:** `REQUEST_AUTHORIZATION_EXECUTE_RSK_P0_005_SYNTHETIC_TABLETOP_ONCE`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-005-HUMAN-APPROVAL-AND-EXERCISE-DESIGN-01

**MIMIR-V1-RSK-P0-005-HUMAN-APPROVAL-AND-EXERCISE-DESIGN-01 — PLAN_APPROVED / EXERCISE_DESIGN_PROPOSED em 2026-10-02.**

- source HEAD: `60db0b7ef89963cb95f956a2cf85b473986756fe`;
- incident-response plan SHA-256: `185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`;
- repository validation previously PASS;
- human approval recorded;
- `docs/INCIDENT_RESPONSE.md` accepted as the formal Mímir v1 incident-response plan;
- design of synthetic exercise authorized;
- exercise `MIMIR-IR-TTX-001` designed as isolated/repository-first;
- exercise execution not authorized;
- no Qwen, PostgreSQL, production, network or real equipment access;
- `RSK-P0-005` remains `OPEN / BLOCKER`;
- Draft removal / merge / tag / deploy remain blocked.

`PLAN_APPROVED != INCIDENT_EXERCISE_VALIDATED`

**NEXT_ACTION atual:** `IMPLEMENT_RSK_P0_005_SYNTHETIC_EXERCISE_HARNESS_REPOSITORY_ONLY`.

## Checkpoint histórico — MIMIR-V1-RSK-P0-005-INCIDENT-RESPONSE-PLAN-REPOSITORY-VALIDATION-01

**MIMIR-V1-RSK-P0-005-INCIDENT-RESPONSE-PLAN-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED em 2026-10-02.**

- design commit: `16ddf1361c9ce4f53cca37953dfb1bcbef6d90f3`;
- implementation HEAD: `51908050a4b20203e8fbd0cde49ce2381b4347d3`;
- canonical plan: `docs/INCIDENT_RESPONSE.md`;
- plan SHA-256: `185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`;
- repository-only validation completed;
- structural contract PASS;
- non-overclaim boundaries PASS;
- design -> implementation traceability PASS;
- existing security/runbook/retention/checklist alignment PASS;
- sensitive-value scan and repository hygiene PASS;
- initial validator false negative preserved without changing source documents;
- initial evidence SHA-256: `be3685c5502c3404c8ec04f5cdb68da61c9c20aac321fe6ffd8a0868b9915c2e`;
- continuation evidence SHA-256: `082ab72c99e5fb8471190ecf1cdfe43c186dca6120960ececf10fffa883267c9`;
- human approval remains PENDING;
- isolated incident exercise remains PENDING;
- `RSK-P0-005` remains `OPEN / BLOCKER`;
- production unchanged;
- Draft removal / merge / tag / deploy remain blocked.

`PLAN_REPOSITORY_VALIDATED != RSK_P0_005_CLOSED`

**NEXT_ACTION atual:** `REQUEST_HUMAN_APPROVAL_RSK_P0_005_INCIDENT_RESPONSE_PLAN`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-POSTGRESQL-E2E-LAB-01

**MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-POSTGRESQL-E2E-LAB-01 — VALIDATED em 2026-10-02.**

- source HEAD: `b25b9cf7fb3b4c9c37075793678fe1e95f80a953`;
- full isolated protected-consolidator integration path completed;
- synthetic capture PASS;
- writer dry-run PASS;
- synthetic PostgreSQL LAB write PASS;
- protected read PASS;
- protected consolidator CLI PASS;
- exactly one real Qwen completion request;
- no retry;
- trusted output validation PASS;
- one candidate returned;
- candidate trust remained `UNTRUSTED_OBSERVATION`;
- mandatory human review retained;
- `source_excerpt_hash` evidence binding validated;
- automatic memory promotion remained zero;
- targeted synthetic cleanup PASS with residue 0;
- harness SHA-256: `d0bd88ca46fdf8cc5e09f4d29f87ce33c9c06a217b332aaeb644400dd71c219c`;
- consolidator SHA-256: `d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`;
- evidence SHA-256: `ad4dfa7c0f544715f333011f2992777cee9fe713fad2985eed67aead9a55c515`;
- restricted run artifacts preserved at `/var/tmp/mimir-protected-real.qZRac0`;
- FINDING-05 remains `CLOSED / REAL_MODEL_REVALIDATED`;
- production unchanged and not validated;
- PR remains Draft.

`CLI_POSTGRESQL_QWEN_E2E_LAB_VALIDATED != PRODUCTION_VALIDATED`

**NEXT_ACTION atual:** `FRESH_FETCH_GUARD_THEN_PUSH_PROTECTED_CONSOLIDATOR_CLI_PG_E2E_CHECKPOINT`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-CLEANUP-HARDENING-REPOSITORY-VALIDATION-01

**MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-CLEANUP-HARDENING-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED em 2026-10-02.**

- implementation HEAD: `f01eb9126ff4ab5c23157c293e354249f5ae618d`;
- design parent: `6d9c44653ba85e72f3ad724b87078fb37377f5fa`;
- existing LAB harness hardened; no duplicate harness created;
- recursive filesystem deletion of `$RUN` removed;
- restricted run artifacts are now preserved for evidence;
- targeted synthetic PostgreSQL cleanup remains intact;
- LAB isolation `/var/tmp/mimir-pg14-lab:55433` remains intact;
- harness SHA-256: `d0bd88ca46fdf8cc5e09f4d29f87ce33c9c06a217b332aaeb644400dd71c219c`;
- consolidator SHA-256 unchanged: `d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`;
- repository evidence SHA-256: `959160371e1bc2be112cf293b84b360592d44d387bd3b31c07f70f5fa6d0747f`;
- repository-only validation PASS;
- LAB harness was not executed;
- Qwen was not accessed;
- PostgreSQL was not accessed;
- production unchanged;
- FINDING-05 remains `CLOSED / REAL_MODEL_REVALIDATED`.

**NEXT_ACTION atual:** `FRESH_FETCH_GUARD_THEN_PUSH_CLEANUP_HARDENING_CHECKPOINT`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-PG-E2E-DESIGN-01

**MIMIR-V1-PROTECTED-CONSOLIDATOR-CLI-PG-E2E-DESIGN-01 — PROPOSED em 2026-10-02.**

- source HEAD: `c76b443a51aea0c47ae25aa93efd1fae6e0022d4`;
- inspection confirms the existing real-model LAB harness already implements
  the required CLI/PostgreSQL/Qwen E2E chain;
- no duplicate E2E harness will be created;
- PostgreSQL target remains isolated LAB `/var/tmp/mimir-pg14-lab:55433`;
- production access remains prohibited;
- targeted synthetic DB cleanup remains required;
- existing filesystem cleanup `rm -rf -- "$RUN"` is not acceptable;
- before E2E execution, harden the existing versioned harness to preserve
  restricted per-run artifacts instead of recursively deleting them;
- hardening must be validated repository-only before any LAB/Qwen execution;
- FINDING-05 remains `CLOSED / REAL_MODEL_REVALIDATED`;
- no harness, Qwen, or PostgreSQL execution occurred in this design phase.

**NEXT_ACTION atual:** `HARDEN_EXISTING_PROTECTED_CONSOLIDATOR_REAL_MODEL_LAB_CLEANUP_REPOSITORY_ONLY`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-03

**MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-03 — VALIDATED em 2026-10-02.**

- source HEAD: `535d101ce85fcd87d3081788971b21fb35d8df6c`;
- protected consolidator GBNF transport used against the real local model;
- exactly one authorized Qwen request;
- no retry;
- trusted `validate_output()` PASS;
- one candidate returned;
- source-event binding PASS;
- source-content SHA-256 binding PASS;
- literal `source_excerpt` binding PASS;
- trusted conversion to `source_excerpt_hash` PASS;
- raw excerpt absent from canonical output;
- mandatory human review preserved;
- FINDING-05: `CLOSED / REAL_MODEL_REVALIDATED`;
- evidence SHA-256: `72d95e7e58adb6851a5d485f0ea97bd7a209858792fa6f9254ce7238a387fa2f`;
- PostgreSQL not accessed;
- CLI + PostgreSQL E2E not validated in this phase;
- production unchanged;
- remote feature branch was synchronized at `535d101ce85fcd87d3081788971b21fb35d8df6c` before this checkpoint;
- PR remains Draft.

**NEXT_ACTION atual:** `PLAN_PROTECTED_CONSOLIDATOR_CLI_POSTGRESQL_E2E_LAB`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-GBNF-TRANSPORT-REPOSITORY-VALIDATION-01

**MIMIR-V1-PROTECTED-CONSOLIDATOR-GBNF-TRANSPORT-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED_REAL_MODEL_VALIDATION_PENDING em 2026-10-02.**

- implementation HEAD: `79d370a736dba287a7a5cc3d9712b337c7c4cebc`;
- protected consolidator transport migrated from `response_format/json_schema`
  to the versioned protected-output GBNF v1;
- `build_response_schema()` retained;
- trusted `validate_output()` retained as semantic authority;
- consolidator SHA-256: `d699a65b07c58faac5b740492feebc8f0da7c87ab71ea188cb083f1660a046fd`;
- main test SHA-256: `2bba8f585708f1fc88c0e2531edabf901f377463233812e9b69ca48b4c3799f9`;
- contract test SHA-256: `90e6e8e04a68287e4396c832aa82fb012a43129b927f8c15501ffd9f042ab172`;
- validator SHA-256 unchanged: `a6ddef3ca89bf8d97802c3f57865da97a0c4bdeca8b103480900c28c11df00d9`;
- GBNF builder SHA-256 unchanged: `d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`;
- repository evidence SHA-256: `d2a3edbff98f8784c8029b0e3ae6f95ae90bb71dba724149bcdf74aeb4c12044`;
- repository validation PASS;
- 12/12 protected-consolidator tests PASS;
- full GBNF runtime validation was not repeated;
- real Qwen request was not performed in this phase;
- protected consolidator real-model validation remains PENDING;
- FINDING-05 remains open;
- two prior patch attempts are preserved as anchor mismatch / NO_WRITE;
- PostgreSQL not accessed;
- production unchanged;
- PR remains Draft;
- push not performed.

Evidence:

`docs/review/operations/2026-10-02-protected-consolidator-gbnf-transport-repository-validation-01.md`

**NEXT_ACTION atual:** `FRESH_FETCH_GUARD_THEN_PUSH_AFTER_EXPLICIT_AUTHORIZATION`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-CONTROLLED-VALIDATION-01

**MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-CONTROLLED-VALIDATION-01 — VALIDATED em 2026-10-02.**

- base HEAD: `2a321ec6b353d86214f20912d223939743183a44`;
- complete committed protected-output GBNF v1 accepted by real llama.cpp/Qwen runtime;
- exactly one synthetic request;
- HTTP 200;
- finish_reason `stop`;
- runtime status PASS;
- no automatic retry;
- no second request;
- runtime evidence SHA-256: `40b6fd7dabc5bf9174f2c469f37678f014fc668553aea245de3d1624b16cbdfb`;
- runtime harness SHA-256: `da6e0f0e7bdcbd6e5ca0237df29c5e47feb171bdcb703bca8228a95b85676498`;
- builder SHA-256: `d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`;
- protected consolidator unchanged and not executed;
- PostgreSQL not accessed;
- production unchanged;
- `FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`.

Evidence:

`docs/review/operations/2026-10-02-protected-output-gbnf-runtime-v1-controlled-validation-01.md`

**NEXT_ACTION atual:** `IMPLEMENT_PROTECTED_CONSOLIDATOR_GBNF_TRANSPORT_REPOSITORY_ONLY`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-REPOSITORY-VALIDATION-01

**MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-V1-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED_RUNTIME_VALIDATION_PENDING em 2026-10-02.**

- implementation HEAD: `5ecb2b36b349b52416e347b15b7761801d09036c`;
- dedicated full-grammar runtime harness committed;
- harness SHA-256: `da6e0f0e7bdcbd6e5ca0237df29c5e47feb171bdcb703bca8228a95b85676498`;
- test SHA-256: `16ac4385236108aa5e3f60e8ef56aa35a98d9e06ea08bab81b4ea1ce8ec95e36`;
- validator SHA-256: `a3f51af178745e0c87c3c07f01eb65f8b109e51f0cef25f1015af1a20df7f5e1`;
- repository evidence SHA-256: `2c3017141d07b7a45090b5096dad316b69a339a03b458b7866641d3ace8b40c9`;
- 19/19 tests PASS;
- repository validator PASS;
- network-isolated tests PASS;
- synthetic event/content bindings PASS;
- deterministic request construction PASS;
- transport/result classification contract PASS;
- no model endpoint request was made;
- Qwen was not accessed;
- PostgreSQL was not accessed;
- protected consolidator remains UNCHANGED / NOT DEPLOYED;
- full protected-output GBNF runtime validation remains PENDING;
- `FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- production unchanged;
- PR remains Draft;
- push not performed.

Evidence:

`docs/review/operations/2026-10-02-protected-output-gbnf-runtime-v1-repository-validation-01.md`

**NEXT_ACTION atual:** `CONTROLLED_RUNTIME_VALIDATE_PROTECTED_OUTPUT_GBNF_V1_SYNTHETIC`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-HARNESS-DESIGN-01

**MIMIR-V1-PROTECTED-OUTPUT-GBNF-RUNTIME-HARNESS-DESIGN-01 — PROPOSED em 2026-10-02.**

- base HEAD: `1702aff81fcb0d1da36ae0eac8b9c3e03072dd67`;
- compatibility/runtime inspection is COMPLETE;
- do not repeat the inspection while source hashes remain unchanged;
- compatibility harness SHA-256: `edd0552edbf4b79ab9051e47c3ae080736b4e174d89ca5a6ba06e779bee0cffc`;
- protected-output GBNF builder SHA-256: `d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`;
- inspection evidence SHA-256: `0e72de241ec6846d550b518cc65c9d9528393f6a987b5f707cab25edb40824f4`;
- exact reusable-block evidence SHA-256: `0a3e9d0c00ac87d5f6f3d739608f989064d735882be6b59844fa7d2f7481028f`;
- reuse the validated G00..G07 transport and result-classification semantics;
- do not modify the existing G00..G07 harness;
- implement a new dedicated full-grammar runtime harness;
- repository-only validation comes before any Qwen request;
- protected consolidator remains UNCHANGED / NOT DEPLOYED;
- PostgreSQL remains untouched;
- full protected-output GBNF runtime validation remains PENDING;
- `FULL_GBNF_RUNTIME_PASS != PROTECTED_CONSOLIDATOR_REAL_MODEL_VALIDATED`;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- PR remains Draft;
- push not performed.

Evidence:

`docs/review/operations/2026-10-02-protected-output-gbnf-runtime-harness-design-01.md`

**NEXT_ACTION atual:** `IMPLEMENT_PROTECTED_OUTPUT_GBNF_RUNTIME_V1_HARNESS_REPOSITORY_ONLY`.

## Checkpoint histórico — MIMIR-V1-PROTECTED-OUTPUT-GBNF-V1-REPOSITORY-VALIDATION-01

**MIMIR-V1-PROTECTED-OUTPUT-GBNF-V1-REPOSITORY-VALIDATION-01 — REPOSITORY_VALIDATED_RUNTIME_VALIDATION_PENDING em 2026-10-02.**

- implementation HEAD: `c3afe5e0dcdbe6f8728a437a002b06c4112bba4a`;
- three new protected-output GBNF v1 artifacts committed;
- builder SHA-256: `d1c025c49fe14937b3eba2611383baf982a4df2bc542c6c9aa64700a32b1f64f`;
- test SHA-256: `2ba1129fc7ce5f4218d150e73bffd046d1683efe4879cd1cfa6516a047ac5657`;
- repository validator SHA-256: `91504127a5ab5e159602edfaad5ef17238bf5c40a2f0d55ba18c17782e90b764`;
- 18/18 unit tests PASS;
- isolated repository validator PASS;
- generated-grammar contract boundary PASS;
- candidate cardinality 0..max_candidates preserved;
- evidence cardinality 1..unbounded preserved;
- raw evidence remains source_excerpt + excerpt;
- trusted validator remains semantic authority;
- two validation-script false positives were preserved as failure evidence;
- llama.cpp full grammar runtime validation remains PENDING;
- protected consolidator remains UNCHANGED / NOT DEPLOYED;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- Qwen/PostgreSQL/production were not accessed;
- PR remains Draft;
- push not performed.

Evidence:

`docs/review/operations/2026-10-02-protected-output-gbnf-v1-repository-validation-01.md`

**NEXT_ACTION atual:** Projetar e executar uma validação controlada da grammar protected-output GBNF v1 contra o parser/runtime real do llama.cpp usando apenas dados sintéticos, sem PostgreSQL e sem alterar o protected consolidator. A validação deve usar a grammar produzida pelo builder commitado, preservar source_event_id/source_content_sha256 sintéticos, não usar dados protegidos e distinguir parser/runtime PASS de protected-consolidator real-model validation. Não alterar ainda mimir-consolidate-protected-v1.py.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-GBNF-DESIGN-01

**MIMIR-V1-PROTECTED-CONSOLIDATOR-GBNF-DESIGN-01 — PROPOSED em 2026-10-01.**

- base HEAD: `55f668d866557eb2a7736c0d88f2ce2c795bb946`;
- protected-output GBNF design inspected against the trusted schema and
  validator;
- raw binding is `source_event_id`, not `source_session_id`;
- raw evidence remains `source_excerpt` + `excerpt`;
- canonical `source_excerpt_hash` remains trusted post-validation output;
- GBNF will constrain transport/syntax only;
- trusted `validate_output()` remains semantic authority;
- candidates remains 0..max_candidates;
- evidence remains one-or-more with no invented maximum;
- no dedicated llama.cpp GBNF parse/check-only tool was found;
- repository-only grammar tests must not claim runtime-parser validation;
- Qwen/PostgreSQL/production: NOT ACCESSED;
- protected consolidator: NOT MODIFIED / NOT DEPLOYED;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- PR remains Draft;
- no push, merge, stable tag or production deployment is authorized.

Evidence:

`docs/review/operations/2026-10-01-protected-consolidator-gbnf-design-01.md`

**NEXT_ACTION atual:** Implementar no repositório, sem modificar ainda o protected consolidator, os artefatos versionados `tools/memory/mimir_protected_output_gbnf_v1.py`, `tools/memory/test_mimir_protected_output_gbnf_v1.py` e `tools/memory/validate-protected-output-gbnf-v1-repository.sh`. O builder deve gerar GBNF determinística ligada a source_event_id, source_content_sha256 e max_candidates, preservar a estrutura bruta source_excerpt/excerpt e nunca introduzir source_session_id ou source_excerpt_hash. A validação repository-only deve provar o contrato do builder e suas rejeições, mas deve registrar explicitamente que a aceitação da nova grammar pelo parser llama.cpp permanece RUNTIME_VALIDATION_PENDING. Não executar Qwen ou PostgreSQL.

## Checkpoint histórico — MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-02

**MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-02 — VALIDATED em 2026-10-01.**

- base HEAD: `6d238430b95db40e4568ee6c8032b29c2a82a9e8`;
- real Qwen GBNF runtime compatibility matrix G00..G07: 8/8 PASS;
- harness execution: PASS;
- contiguous pass through: G07;
- runtime compatibility: ALL_CASES_PASS;
- all eight cases: HTTP 200 / finish_reason stop;
- PostgreSQL: NOT ACCESSED;
- production: UNCHANGED;
- protected consolidator: NOT MODIFIED / NOT DEPLOYED;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- PR remains Draft;
- no push, merge, stable tag or production deployment is authorized.

Evidence:

`docs/review/operations/2026-10-01-gbnf-runtime-compatibility-02.md`

Evidence log SHA-256:

`9a88a6343ff127716b258c822d0dc7dceac547c0a3c83509a81593a5a458ae1a`

**NEXT_ACTION atual:** Inspecionar e projetar no repositório uma grammar GBNF versionada equivalente ao contrato fechado do protected consolidator, derivada do schema/validator atualmente confiável. A nova grammar deve preservar todos os campos obrigatórios, additionalProperties=false, candidate e evidence structure, source_session_id/source_event_id, evidence kind source_excerpt_hash e SHA-256 lowercase de 64 caracteres. Primeiro validar essa grammar somente em testes de repositório positivos e negativos; não alterar ainda o transporte do protected consolidator, não executar PostgreSQL e não fazer nova chamada ao modelo real.

## Checkpoint histórico — MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-01

**MIMIR-V1-GBNF-RUNTIME-COMPATIBILITY-01 — REPOSITORY_VALIDATED / REAL_RUNTIME_VALIDATION_PENDING em 2026-10-01.**

- code HEAD: `720556e0fad34a3d5d9f3602d094da2bd3c8d20f`;
- GBNF compatibility harness committed;
- repository validation: PASS;
- isolated unit tests: 15/15 PASS;
- Qwen real runtime: NOT RUN;
- PostgreSQL: NOT ACCESSED;
- production: UNCHANGED;
- protected consolidator: NOT MODIFIED / NOT DEPLOYED;
- FINDING-05 remains `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- PR remains Draft;
- no push, merge, stable tag or production deployment is authorized.

Evidence:

`docs/review/operations/2026-10-01-gbnf-runtime-compatibility-01.md`

**NEXT_ACTION atual:** Executar de forma controlada o harness versionado `tools/memory/mimir-gbnf-runtime-compatibility.py` contra o runtime Qwen local `127.0.0.1:18782`, sem PostgreSQL e usando somente os casos sintéticos G00..G07. Registrar apenas hashes, tamanhos, status HTTP, marcadores estruturais e classificação por caso; não registrar conteúdo bruto do modelo. Não alterar o protected consolidator durante essa execução. O resultado deve distinguir HARNESS_EXECUTION de RUNTIME_COMPATIBILITY e ser documentado antes de qualquer mudança no consolidator.

## Checkpoint histórico — MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-02

**MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-REVALIDATION-02 — BLOCKED em 2026-10-01.**

- implementation/source HEAD:
  `b0d69856ce42a4463330d37180cc9a76a3dc507f`;
- local implementation commits remained unpushed at checkpoint creation;
- repository validation after the transport change: 12/12 PASS;
- integrated synthetic LAB with real Qwen: FAIL-CLOSED at
  `candidate 1 viola schema fechado`;
- synthetic cleanup: PASS / residue 0;
- production remained schema `1..12`, `mimir_ops=false`;
- FINDING-05: `REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_BLOCKED`;
- explicit GBNF remains unvalidated;
- PR remains Draft;
- release blockers RSK-P0-003/004/005 remain unchanged;
- no merge, tag, deployment or production migration is authorized.

Evidence:

`docs/review/operations/2026-10-01-protected-consolidator-realmodel-revalidation-02.md`

**NEXT_ACTION atual:** Projetar e implementar no repositório um harness sintético versionado de compatibilidade GBNF para o runtime Qwen em 127.0.0.1:18782, sem PostgreSQL, começando por uma grammar mínima conhecida e expandindo construções incrementalmente. O harness deve tratar HTTPError, URLError e TimeoutError de forma fail-closed, preservar evidência estrutural sem conteúdo confidencial e ser validado antes de qualquer nova alteração no protected consolidator.

A revalidação real-model somente poderá continuar depois que o harness
diagnóstico versionado produzir um resultado controlado e reproduzível.

## Checkpoint histórico — MIMIR-V1-P1-PR-REVIEW-01

**MIMIR-V1-P1-PR-REVIEW-01 — REVIEWED / RELEASE_BLOCKED em 2026-10-01.**

- validated/base HEAD:
  `115e39a3650ca5150e27c2326b3c6f7a569df62d`;
- PR #1 permaneceu OPEN / DRAFT;
- sete findings desta rodada foram corrigidos em commits isolados;
- full memory regression mais recente: 50/50 PASS;
- GitHub checks do validated/base HEAD: 6/6 success;
- nenhum merge, Draft removal, tag ou deployment foi autorizado;
- protected consolidator permanece
  `REAL_MODEL_REVALIDATION_PENDING`;
- `RSK-P0-003`, `RSK-P0-004` e `RSK-P0-005` continuam blockers.

**NEXT_ACTION atual:** revalidar o protected consolidator em LAB integrado
sintético com Qwen real após o FINDING-05, mantendo PR Draft e produção
intacta.

A conclusão da revisão do PR não equivale a aprovação da release.

## Checkpoint histórico — RESTORE-01

**MIMIR-V1-P1-RESTORE-01 — VALIDADO em 2026-09-30.**

- validated/base HEAD: `181a859e952a7111da2efe72b9a90d8678d1ef98`;
- custom-format dump restore: PASS;
- Git bootstrap + migrations 002..012: PASS;
- RESTORE-A x RESTORE-B equivalence: PASS;
- schema/owners/ACLs/roles/memberships/settings: equivalent;
- restore LAB cleanup: PASS;
- produção permaneceu `1..12`, sem `mimir_ops`;
- LAB 014 separado foi preservado e permanece RUNNING em `55433`;
- nenhuma validação de produção é inferida desse resultado.

**NEXT_ACTION histórico deste checkpoint:** revisar PR #1 mantendo-o Draft;
blockers de release permaneciam abertos.

Os checkpoints históricos abaixo são preservados por rastreabilidade. Referências
antigas a "Próxima atividade" não substituem o `NEXT_ACTION` mais recente de
`docs/MIMIR_HANDOFF.md`.


**Checkpoint MIMIR-V1-TELEGRAM-01 — concluído.**

O canal Telegram do Mímir foi validado no OpenClaw 2026.9.5:

- bot operacional: `@MimirAssistenteBot`;
- canal enabled/configured/running/connected;
- transporte polling;
- conversa bidirecional validada;
- envio proativo validado;
- `dmPolicy=allowlist`;
- grupos desabilitados;
- token mantido fora do Git por arquivo protegido;
- somente o operador autorizado permanece na allowlist.

**Checkpoint MIMIR-V1-TELEGRAM-02 — concluído.**

Validação em sessão Telegram nova confirmou o caminho explícito de memória:

- `context.compiled (2 tools)`;
- `tool.call mimir_memory_search`;
- `tool.result mimir_memory_search ok`;
- execução final no modelo local Qwen3-4B;
- `session.ended success`;
- plugin `mimir-memory 0.2.7`, embedding local gerenciado pelo OpenClaw e
  consulta PostgreSQL foram validados no caminho ponta a ponta;
- a resposta semântica obtida no teste não cobriu corretamente os fatos
  solicitados de migration/LAB, portanto qualidade de recuperação/cobertura do
  corpus permanece pendência P1 separada;
- o caminho shadow continua separado e não foi declarado saudável.

**Próxima atividade:** fechar primeiro o bloqueador P1 da memória permanente.
O primeiro rebuild do lab temporário confirmou produção intacta, cluster
isolado, bootstrap v1 e replay 002..012, mas parou antes da 014 porque
`openclaw` não conseguia atravessar o diretório pai 0700 até o Unix socket.
O diagnóstico do retry fechou a causa: `unix_socket_group=openclaw` é
inválido para o processo PostgreSQL porque a conta `postgres` não pertence a
esse grupo; o chgrp do socket falhou com `Operation not permitted`. A correção
versionada mantém LAB_ROOT/socket-dir restritos ao grupo `openclaw`, mas deixa
o socket `postgres:postgres 0777`; peer + pg_ident continua controlando a
identidade de banco. O rebuild limpo do lab passou no commit
`7815cb4b9d8b62c4d7e64e6e5c2decf15564cfa3`: cluster isolado, socket e
permissões validados, bootstrap v1 + replay 002..012, schema 1..12, peer
`openclaw -> mimir_app` e produção intacta. A migration 014 passou no LAB-014-01: dump pré-014 criado, COMMIT somente no
lab, ACL e peer corretos, ingestão sintética idempotente, leitura protegida,
negativos de classe/hash e zero resíduo após rollback. O lab terminou em
1..12,14 e produção permaneceu 1..12, sem v14 e sem `mimir_ops`.
O writer v2 já foi implementado somente no repositório. Ele reutiliza a
captura em processo, exige fingerprints esperados, é dry-run por padrão, emite
approval digest e só escreve com `--write --approve` por socket Unix local; o
conteúdo não entra em stdout/staging/argv. Testes sintéticos e um validador
end-to-end de lab também foram adicionados. A revalidação do capture/writer passou: syntax, capture tests, quatro testes
sintéticos do writer e live capture regression mantiveram 12 ready / 0 blocked /
6 skipped / 0 errors sem exposição de conteúdo. O primeiro end-to-end de lab
parou antes do write por um bug do harness: variáveis psql em consultas
`-c` chegaram literais ao servidor. O harness foi corrigido para stdin/heredoc.
O writer end-to-end passou no lab 1..12,14: dry-run/aprovação, write
sintético, replay idempotente, proveniência persistida, protected read, zero
promoção automática e cleanup sem resíduo. Produção permaneceu 1..12, sem 014 e
sem writer. O próximo bloqueador P1 passa a ser a consolidação local das fontes de
sessão confidential. O inventário read-only do VPS encontrou um
`llama-server` local com Qwen3-4B-Q4_K_M em `127.0.0.1:8080`, mas isso
contraria o mapa de portas já definido para o Mímir: PcIA CUDA=18781, VPS CPU
fallback=18782 e OpenClaw Gateway=18789. Portanto 8080 deve ser tratado como
drift/configuração a diagnosticar, não como endpoint canônico. Um probe posterior
confirmou `/health` e `/v1/models` em 8080; o chat probe ficou inconclusivo
por erro no comando de teste (pipe + Python heredoc), não por falha comprovada
da API. O diagnóstico localizou a origem exata do drift:
`/etc/init.d/mimir-llama` usa `--port ${listen_port}` e
`/etc/conf.d/mimir-llama` fixa `listen_port="8080"`. A porta canônica do
fallback VPS continua 18782. A correção de runtime foi executada: `listen_port` passou para 18782,
somente `mimir-llama` foi reiniciado e o processo/listener confirmaram
`127.0.0.1:18782`, sem 8080 na saída. O readiness foi confirmado em 18782: `/health` 200/ok e
`/v1/models` identificou Qwen3-4B-Q4_K_M. O diagnóstico de chat fechou o comportamento do Qwen3. Em modo normal a
resposta trouxe `content` + `reasoning_content` (36 e 947 chars,
respectivamente) e consumiu 236 completion tokens. Com
`chat_template_kwargs.enable_thinking=false`, a mesma tarefa retornou apenas
`content`, JSON sintético válido, em 11 completion tokens. Assim,
`MIMIR-V1-LOCAL-LLAMA-18782-CHAT-01 = PASS`. Para consolidação estruturada,
usar thinking desabilitado por request, processar somente `message.content` e
nunca persistir/expor `reasoning_content`. O próximo passo é o gap inventory
da nova arquitetura de segurança conversacional e o contrato seguro do
consolidator. Então ler por
`read_consolidation_source(uuid)`, usar loopback local, operar em dry-run e
manter revisão/submissão humana separadas. O consolidador NVIDIA existente
continua proibido para essas fontes.
Produção exige autorização separada. Não ampliar permissões nem autorizar
EXECUTE em equipamento real.

## Protocolo de continuidade entre sessões

O arquivo `docs/MIMIR_HANDOFF.md` é o ponto operacional corrente para retomada entre chats, sessões do Codex e outros agentes.

Regras:

1. Toda nova sessão deve ler primeiro `docs/MIMIR_HANDOFF.md` e depois este plano mestre.
2. Git, branch e HEAD devem ser conferidos antes de qualquer alteração.
3. O campo `NEXT_ACTION` do handoff define o ponto exato de retomada.
4. LAB concluído, bug bloqueante, fix relevante, mudança de máquina ou mudança do próximo passo exigem atualização do handoff.
5. Sessões longas devem atualizar e versionar o handoff antes de encerrar.
6. Checkpoints históricos relevantes devem ser preservados em `docs/handoff/archive/`.
7. Se conversa, memória do modelo e Git divergirem, o repositório e o handoff versionado prevalecem após conferência.

## Evidências relacionadas

- `docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md`
- `docs/review/operations/2026-09-22.md`
- `docs/review/operations/2026-09-24.md`
- `docs/STATUS.md`
- `docs/ROADMAP.md`
- `docs/OPERATIONS.md`
- `docs/RUNBOOK.md`


## Checkpoint MIMIR-V1-013-LAB-02 — concluído

A segunda metade da migration operacional 013 foi validada exclusivamente no cluster PostgreSQL temporário.

Resultados:

- `013_operational_role.sql` aplicada com COMMIT no laboratório;
- role `mimir_ops` criada no cluster temporário;
- atributos: LOGIN=true, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS, CONNECTION LIMIT 3;
- CONNECT no banco de laboratório: true;
- USAGE no schema `mimir`: true;
- EXECUTE em `mimir.ops_api(jsonb)`: true;
- EXECUTE nas funções internas `ops_assert_identity`, `ops_assert_object` e `ops_device_document`: false;
- tabelas `ops_*` com DML direto efetivo para `mimir_ops`: 0;
- USAGE nas sequences operacionais: false;
- identidade registrada como `peer:mimir-ops`, permanecendo `enabled=false`;
- SELECT direto em `mimir.ops_clients`: bloqueado;
- chamada da API com identidade ainda não habilitada: bloqueada;
- produção permaneceu em schema_version 1–12 e sem role `mimir_ops`.

**Próxima atividade:** validar identidade peer dedicada no laboratório e exercitar `mimir.ops_api(jsonb)` com dados sintéticos, incluindo casos negativos, sem reutilizar a identidade `openclaw`.


## Checkpoint MIMIR-V1-013-LAB-03-PREFLIGHT — concluído

Preflight de autenticação peer no laboratório concluído sem alterações no host de produção:

- usuário Linux `mimir-ops`: ausente;
- HBA do cluster temporário ainda usa `trust` para conexões locais;
- `pg_ident.conf` do laboratório: vazio;
- conexão administrativa atual: `current_user=postgres`, `session_user=postgres`, `system_user=NULL`, conforme esperado sob `trust`;
- identidade operacional cadastrada no schema: `db_role=mimir_ops`, `authentication_identity=peer:mimir-ops`, `enabled=false`.

Decisão de segurança: não criar ainda o usuário Linux persistente `mimir-ops` no VPS apenas para o laboratório. O próximo teste deve validar o mecanismo peer usando uma identidade sintética restrita ao cluster temporário; a identidade definitiva `peer:mimir-ops` só será provisionada no host durante a implantação autorizada.


## Checkpoint MIMIR-V1-013-LAB-03 — concluído

Autenticação peer foi validada exclusivamente no cluster PostgreSQL temporário, sem criação da conta Linux definitiva `mimir-ops`.

Configuração sintética de laboratório:

- usuário Linux usado para o teste: `jarvisdev`;
- role PostgreSQL: `mimir_ops`;
- mapeamento `pg_ident`: `jarvisdev -> mimir_ops`;
- HBA alterado somente no cluster temporário;
- conexão administrativa via peer confirmou `system_user=peer:postgres`;
- conexão operacional confirmou `current_user=mimir_ops`, `session_user=mimir_ops`, `system_user=peer:jarvisdev`;
- API permaneceu bloqueada enquanto a identidade lógica estava desabilitada;
- SELECT direto permaneceu bloqueado.

Conclusão: peer authentication + pg_ident + least privilege funcionam no desenho esperado. A identidade definitiva `peer:mimir-ops` ainda não foi provisionada no host real.

**Próxima atividade:** habilitar temporariamente `peer:jarvisdev` somente no laboratório, exercitar `mimir.ops_api(jsonb)` com dados totalmente sintéticos e depois executar casos negativos.


## Checkpoint MIMIR-V1-013-LAB-04 — concluído

A API operacional foi exercitada com identidade peer sintética habilitada somente no laboratório e com dados totalmente sintéticos.

Fluxo executado sob `set -euo pipefail`:

- identidade temporária do laboratório alterada para `peer:jarvisdev` e habilitada;
- conexão como `mimir_ops` via peer confirmada;
- `inventory.add` de cliente sintético concluído;
- `inventory.add` de site sintético concluído;
- `inventory.add` de dispositivo `generic-linux` em modo READ concluído;
- acesso SSH sintético associado ao dispositivo;
- `inventory.list` de clientes concluído;
- `inventory.show` do dispositivo concluído;
- SELECT direto nas tabelas ops continuou bloqueado;
- `trap` restaurou a identidade lógica para `peer:mimir-ops`, `enabled=false`;
- produção permaneceu com `schema_version=1..12` e sem role `mimir_ops`.

O fato de o script ter alcançado as verificações finais sob `set -e` confirma que as chamadas anteriores da API não retornaram erro SQL.

**Próxima atividade:** executar casos negativos da API no mesmo laboratório: campos desconhecidos/segredos, inconsistência rede/IP, dependência entre clientes, plano adulterado e tentativa de EXECUTE sem autorização.


## Checkpoint MIMIR-V1-013-LAB-05A — concluído

Primeira bateria de casos negativos da API operacional concluída no laboratório:

- payload com campo sensível foi rejeitado;
- payload com campo desconhecido foi rejeitado;
- nenhum objeto residual foi criado após as rejeições;
- identidade sintética foi restaurada para `peer:mimir-ops`, `enabled=false`.

Resultado: rejeição de conteúdo sensível, rejeição de campos inesperados e ausência de persistência parcial foram confirmadas.

**Próxima atividade:** concluir LAB-05 com inconsistência rede/IP, dependência entre clientes, plano adulterado e tentativa de EXECUTE sem autorização.


## Checkpoint MIMIR-V1-013-LAB-05 — concluído

A bateria completa de casos negativos da API operacional foi concluída no laboratório.

Validações aprovadas:

- payload sensível rejeitado;
- campo desconhecido rejeitado;
- IP fora da rede rejeitado;
- rollback confirmou ausência de device/interface/access inválidos;
- dependência atravessando clientes rejeitada;
- rollback confirmou ausência de device/access inválidos;
- plano adulterado rejeitado;
- tentativa de EXECUTE em equipamento com `permission_mode=READ` rejeitada;
- nenhuma intervenção inválida foi persistida;
- identidade operacional restaurada para `peer:mimir-ops`, `enabled=false`;
- produção permaneceu com `schema_version=1..12` e sem role `mimir_ops`.

**Próxima atividade:** validar o fluxo READ sintético completo, incluindo abertura de intervenção, journal de intent/result, finalização, atualização do inventário e relatório, ainda sem acessar equipamento real.


## Checkpoint MIMIR-V1-013-LAB-06 — bloqueado por bug encontrado

O primeiro teste de fluxo READ persistido encontrou uma falha real na máquina de estados da migration 013.

Sequência observada:

- `intervention.begin`: aceito;
- evento READ `intent`: aceito;
- evento READ `result`: rejeitado com `workflow transition out of order`.

Causa localizada no SQL versionado de `mimir.ops_api(jsonb)`: na validação do evento `result`, a operação anterior é lida como `last_action.payload->>'operation'`, porém o journal persiste o evento completo e a operação está aninhada em `payload.action.operation`. A comparação correta precisa usar o caminho aninhado correspondente.

Consequência: um fluxo READ válido não consegue avançar de `intent` para `result`.

Estado do teste:

- a intervenção sintética LAB-06 ficou aberta/running no laboratório;
- o `trap` restaurou a identidade operacional para o estado desabilitado;
- produção não foi usada para esse fluxo;
- o item “Testar fluxo READ sintético completo” permanece pendente.

**Próxima atividade:** corrigir a migration 013 no desenvolvimento local, adicionar teste de regressão para a transição intent → result e somente depois recriar/revalidar o laboratório a partir de um estado limpo.


## Checkpoint MIMIR-V1-013-LAB-06 — concluído

O fluxo READ sintético persistido foi reexecutado do zero após a correção do guard de transição e concluiu com sucesso.

Resultados:

- `intervention.begin`: aceito;
- `READ intent`: aceito;
- após intent: `stage=READ,state=intent`;
- `READ result`: aceito;
- após result: `stage=DONE,state=complete`;
- journal persistiu exatamente dois eventos: intent e result;
- `intervention.finish`: aceito com status `collected`;
- `final_validation=true`;
- `inventory_updated=true`;
- 1 evidência persistida;
- 1 relatório persistido;
- dispositivo passou para `verification_state=verified`;
- `verified_at` e `last_collected_at` preenchidos;
- `verification_scope=diagnostic_observation`;
- APIs `history` e `report` retornaram o registro esperado;
- identidade restaurada para `peer:mimir-ops`, `enabled=false`;
- produção permaneceu sem schema_version 13 e sem role `mimir_ops`.

A correção validada foi `last_action.payload#>>'{action,operation}'`, commit `148044569dab79a2faa902e1a7b51c691bb43353`.

### Hardening temporal identificado

O teste gerou `completed_at` no arquivo de request antes de executar `intervention.begin`, e por isso o valor persistido ficou alguns milissegundos anterior ao `started_at` registrado pelo banco. A API aceitou essa cronologia impossível porque hoje valida apenas a presença de `completed_at`, não `completed_at >= started_at`.

Esse ponto deve ser corrigido e coberto por teste antes de avançar para o fluxo EXECUTE sintético.


## P1 — Segurança conversacional, conteúdo não confiável e tool-use

Documentos:
- `docs/CONVERSATIONAL_SECURITY.md`
- `docs/AI_SECURITY_TEST_MATRIX.md`

Escopo exclusivo do Projeto Mímir. Não misturar estado ou implementação com
Sistema-OS.

Estado inicial:
- [x] arquitetura de segurança conversacional versionada;
- [x] matriz adversarial T-AI-001..035 versionada;
- [x] mapear controles já existentes versus requisitos propostos
  (`docs/AI_SECURITY_GAP_INVENTORY.md`);
- [ ] definir envelope canônico de provenance/trust para inputs externos;
- [ ] definir identidade, principal, tenant e scope por canal;
- [ ] definir capability model e policy gate externo ao LLM;
- [ ] definir validação tipada de parâmetros de ferramentas;
- [ ] definir delegação de subagentes sem herança automática de privilégio;
- [ ] definir model-routing policy sem ampliação de capability/secret/scope;
- [ ] definir context minimization e output exposure gate;
- [ ] definir eventos de auditoria e anti-replay para ações sensíveis;
- [ ] decidir mapping/extension entre os `memory_type` atuais e as classes
  FACT/PREFERENCE/EPHEMERAL_CONTEXT/OPERATIONAL_STATE/SECURITY_DECISION/
  UNTRUSTED_OBSERVATION;
- [x] versionar contrato fechado do consolidator protected-source
  (`docs/PROTECTED_SESSION_CONSOLIDATOR_V1.md`);
- [x] implementar os controles mínimos necessários ao consolidator confidential em modo repository-only/dry-run;
- [ ] executar primeiro os testes T-AI ligados a conteúdo externo, memória e
  saída;
- [ ] exigir evidência de enforcement fora do LLM para PASS crítico;
- [ ] bloquear novos canais ou capabilities sensíveis até os gates
  correspondentes estarem validados.

Regra de estado: esta seção representa **PROPOSTA VERSIONADA**, não controle
implementado. Cada item precisa de implementação, validação e evidência próprias.


## Checkpoint MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-PREFLIGHT — 2026-09-27

Estado: `REPOSITORY_VALIDATED`.

Checkpoint formal:

`MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01 = PASS`

HEAD validado:

`3d119d4a8308c1dbaf9744c9f3c7f3b77a5a8c64`

A validação formal executou 8/8 testes com RC=0 em checkout limpo.
O fake model foi isolado em network namespace, enquanto o llama.cpp real
permaneceu ativo em `127.0.0.1:18782` antes e depois do teste.

Foram versionados:

- `mimir-consolidate-protected-v1.py`;
- `test_mimir_consolidate_protected_v1.py`;
- `validate-protected-consolidator-v1-repository.sh`.

Controles implementados:

- leitura somente por `mimir.read_consolidation_source(event_id)`;
- endpoint/modelo em allowlist local;
- proxy/redirect bloqueados;
- `enable_thinking=false`;
- somente `message.content`;
- schema fechado e bindings de event/hash;
- `UNTRUSTED_CONTENT -> UNTRUSTED_OBSERVATION`;
- human review obrigatório;
- secret/output gate externo ao modelo;
- tool call rejeitada;
- zero promoção e zero escrita de memória.

A validação formal repository-only passou em checkout limpo do HEAD
`3d119d4a8308c1dbaf9744c9f3c7f3b77a5a8c64`.

Resultado:

`MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01 = PASS`

Próxima atividade:

1. preparar/revalidar PostgreSQL lab 1..12,14;
2. validar consolidator + lab isolado + Qwen real 18782 exclusivamente com
   fonte sintética;
3. manter produção 1..12;
4. manter migration 014, writer v2 e consolidator sem deployment.

## Checkpoint MIMIR-V1-PROTECTED-CONSOLIDATOR-REAL-MODEL-LAB — 2026-09-27

Estado: `BLOCKED_BY_MODEL_TIMEOUT`.

Commit técnico atual:

`9e2e1c13e76cc60e4b383cc0898b54aeef2bcef0`

Resultados:

- PostgreSQL LAB 1..12,14 recuperado e operacional;
- Unix socket 55433 validado;
- produção permaneceu 1..12;
- protected writer/read sintético PASS;
- PostgreSQL Base64 wrapping identificado e corrigido;
- repository regression após correção: 8/8 PASS;
- real-model LAB avançou até a interação com Qwen 18782;
- timeout identificado como `TimeoutError: timed out`;
- cleanup sintético: 0;
- zero promoção automática.

Próxima atividade:

1. tratar timeout explicitamente no consolidator;
2. adicionar regression test repository-only;
3. revalidar repository-only;
4. medir latência do Qwen real separadamente;
5. avaliar tecnicamente o limite atual de 60 s;
6. repetir o LAB somente após a medição;
7. manter produção, sessão real e deployment fora de escopo.


## Protected consolidator timeout regression — 2026-09-27

State: REPOSITORY_VALIDATED

Technical commit: 28be68ea1dcccb74e74d16fe49a4943a1d316947

- explicit TimeoutError handling: implemented;
- timeout regression test: PASS;
- repository suite: 9/9 PASS;
- validator RC=0;
- Qwen real remained isolated from the test;
- production unchanged.

Next: measure real Qwen latency before changing the 60-second upper bound or
repeating the integrated real-model LAB.


## Protected consolidator timeout regression — 2026-09-27

State: REPOSITORY_VALIDATED

Technical commit: e62b2eed018fb3c9d5c9b499abce15ce66828667

- explicit TimeoutError handling: implemented;
- timeout regression test: PASS;
- repository suite: 9/9 PASS;
- validator RC=0;
- Qwen real remained isolated from the test;
- production unchanged.

Next: measure real Qwen latency before changing the 60-second upper bound or
repeating the integrated real-model LAB.

## Qwen latency characterization — 2026-09-27

State: `MEASURED`.

- first probe: 44.351 s;
- warm average: ~31.78 s;
- warm range: 30.927–32.324 s;
- 342 prompt tokens;
- 190 completion tokens;
- HTTP 200 / finish_reason=stop.

Do not change timeout yet.

Next: measure the exact integrated LAB request before repeating design changes.

## Model timeout root cause — 2026-09-27

State: `ROOT_CAUSE_CONFIRMED`.

- exact LAB request captured;
- synthetic residue: 0;
- 90 s idle before model request;
- Qwen HTTP 200;
- exact request total: 71.536 s;
- current integrated timeout: 60 s.

Next:

separate PostgreSQL timeout from model inference timeout and validate the new
budget repository-only before repeating the integrated LAB.


## Protected consolidator timeout split — 2026-09-27

State: `REPOSITORY_VALIDATED`.

Technical commit: `8b04510fc693442ae94d0487581d942d5ae9319e`

- PostgreSQL timeout remains independently bounded at 60 s maximum;
- model timeout default 120 s, maximum 180 s;
- repository regression 10/10 PASS.

Next: integrated synthetic LAB using model timeout 120 s.

## REAL MODEL OUTPUT SCHEMA REJECTED — 2026-09-28

State: `DIAGNOSTIC_REQUIRED`

Completed:

- PostgreSQL/model timeout split validated;
- integrated LAB exercised model timeout 120 s;
- Qwen real returned;
- fail-closed output schema validation rejected the response;
- synthetic cleanup = 0.

Next:

1. capture top-level output keys;
2. capture candidate count/key sets;
3. do not expose unnecessary synthetic payload content;
4. do not relax validator;
5. validate any correction repository-only before another integrated LAB.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-SCHEMA-DIAG-01

Status: `BLOCKED`

Branch: `feat/mimir-operational-foundation`

Source HEAD: `7d79c02efa92597fb1e927f27b9c7715ef0a4fa8`

Completed diagnostic work:

- model timeout split validated;
- integrated synthetic LAB reached real Qwen;
- schema mismatch reproduced fail-closed;
- observed keys: `schema_version,source_bindings`;
- `synthetic_residue=0`;
- strict llama.cpp JSON Schema capability independently validated.

Decision:

Use a closed JSON Schema during generation and retain the current Python
validator unchanged as the second validation layer.

NEXT_ACTION:

1. implement closed JSON Schema in `mimir-consolidate-protected-v1.py`;
2. remove ambiguous `requested source bindings` wording;
3. add repository-only request/schema regressions;
4. run isolated repository validation;
5. on PASS, commit technical change;
6. update continuity documents with exact technical commit;
7. only then repeat integrated synthetic real-model LAB.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-JSON-SCHEMA-REPO-01

Status:

`REPOSITORY_ONLY_PASS`

Technical commit:

`39b09e92b2355573105d3613ba84dab9267cf0a1`

Completed:

- closed llama.cpp JSON Schema implemented;
- ambiguous source-binding prompt removed;
- Python fail-closed validator retained;
- repository JSON Schema regression added;
- syntax validation PASS;
- JSON Schema contract PASS;
- protected suite 10/10 PASS under isolated network namespace.

Not completed:

- integrated synthetic real-model LAB;
- deployment;
- production validation.

NEXT_ACTION:

Execute the integrated synthetic protected-consolidator LAB against the real
Qwen fallback at `127.0.0.1:18782`.

The run must finish with:

`synthetic_residue=0`

Only after that result may the real-model LAB state move to PASS.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-JSON-SCHEMA-01

Status:

`FAIL`

Technical commit:

`39b09e92b2355573105d3613ba84dab9267cf0a1`

Repository-only validation:

`PASS`

Integrated real-model LAB:

`FAIL`

Reason:

`timeout ao acessar modelo local`

Model timeout budget:

`120 seconds`

Cleanup:

`synthetic_residue=0`

The run stopped before output-schema validation.

NEXT_ACTION:

Perform read-only Qwen runtime/latency diagnostics. Do not alter timeout,
JSON Schema, validator or production before cause characterization.

### Real-model timeout diagnostic refinement

Small strict JSON Schema probe: PASS in 4.392 s.

The integrated timeout is no longer treated as a generic Qwen/runtime outage.

NEXT_ACTION:

Profile the full synthetic consolidator request and measure its inference
latency independently of the current 120-second cutoff.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-LATENCY-01

Status: `BLOCKED`

Integrated real-model contract:

`PASS`

Measured model latency:

`136.530 s`

Canonical model budget:

`120 s — insufficient`

Diagnostic budget:

`180 s — PASS`

Cleanup:

`synthetic_residue=0`

NEXT_ACTION:

Inspect repository timeout references and implement a scoped timeout policy for
the VPS CPU fallback without changing schema or validator semantics.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-TIMEOUT-POLICY-DESIGN-01

Status: `DESIGN_COMPLETE`

Policy:

- generic default: 120 s;
- maximum: 180 s;
- VPS CPU fallback real-model LAB: explicit 180 s.

Repository inspection:

- repository-only validator exists;
- protected Python regressions exist;
- versioned integrated real-model LAB harness does not exist;
- no versioned real-model timeout override exists.

NEXT_ACTION:

Design and add a versioned integrated real-model LAB harness derived from the
validated disposable harness. Validate repository-only before executing it.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-STAGING-DESIGN-01

Status: `DESIGN_COMPLETE`

Finding:

`openclaw` cannot execute the protected LAB scripts directly from the
`jarvisdev` checkout because parent home directories are private.

Decision:

- preserve home permissions;
- version the LAB harness;
- root stages required repository artifacts into disposable `/var/tmp`;
- `openclaw` executes only staged artifacts;
- cleanup remains mandatory.

NEXT_ACTION:

Inspect local dependencies of capture and writer before implementation.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-PASS-01

Status: `PASS`

The protected consolidator real-model workstream is complete.

Validated:

- versioned reproducible LAB harness;
- protected source read;
- real Qwen inference;
- strict JSON Schema;
- independent Python validation;
- human-review requirement;
- zero automatic promotion;
- cleanup with zero synthetic residue.

Validated implementation:

`072397bd05a0f5e4a806fed4c403a7aab7a4abdb`

This blocker is closed.

Next:

Continue with the next incomplete functional milestone in the v1 execution
plan. Do not spend additional work on this timeout path without a regression.

## MIMIR-V1-OPENCODE-HARD-DENY-POLICY-VALIDATION-01

Status: `VALIDATED / LOCAL_POLICY_COMMITTED / PUSH_PENDING`

Policy commit:

`6de5b06ae4dd00b4dd00b92ce2135dcdab04699a`

Policy SHA-256:

`a16de25598a7ade1cb22d493fe3974b46f96b6ac16e4a16234c392d8d4263738`

Security model:

`DENY_BY_DEFAULT + EXPLICIT_ALLOW_ONLY + EXTERNAL_HUMAN_GATE_FOR_GIT_AND_OPS`

Validation:

- static policy contract: PASS;
- ASK security-boundary design: rejected after preserved runtime failure;
- ASK rule count in accepted policy: zero;
- BUILD prohibited shell/edit capability: not exposed;
- ARCHITECT policy read: PASS;
- ARCHITECT prohibited edit/shell capability: not exposed;
- IMPLEMENT native edit: PASS;
- IMPLEMENT exact probe-content verification: PASS;
- IMPLEMENT shell capability: not exposed in validated child session;
- IMPLEMENT subagent delegation: not exposed in validated child session;
- sanitized IMPLEMENT session tool events: `patch`, `read` only;
- QUICK local Qwen inference: PASS;
- QUICK tools: none observed;
- Git mutation by OpenCode: none;
- production: unchanged.

IMPLEMENT evidence session:

`ses_efc702557ffe8ZNP6gKnoBN4Ps`

Session-export SHA-256:

`a89bd835e5ad5df6b1961d060d1e9122f6a85ae6832f04bc959cb27dcb989b71`

QUICK result:

`QUICK_LOCAL_QWEN_RUNTIME_PASS`

Configuration provenance:

- shared OpenCode daemon started before policy creation;
- explicit project-context `opencode reload` after policy creation: PASS;
- command returned `Configuration reloaded`;
- temporary post-reload agent-registry parser was incompatible with the JSON
  list shape returned by the CLI and is recorded as inconclusive;
- no completed permission or Qwen test is to be repeated merely to compensate
  for that inspection-parser mismatch.

Operational rule:

OpenCode does not receive Git mutation or operational shell authority under this
policy. Mutable Git and operational actions remain at the human terminal gate.

Release boundary remains unchanged:

`PRODUCTION_VALIDATION=NO`

`RSK-P0-004=PARTIALLY_TREATED / PRODUCTION_RELEASE_BLOCKER`

NEXT_ACTION:

`COMMIT_OPENCODE_HARD_DENY_CONTINUITY_CHECKPOINT_THEN_FRESH_FETCH_GUARD_AND_PUSH`
