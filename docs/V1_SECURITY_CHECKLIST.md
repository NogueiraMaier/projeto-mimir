# Mímir v1 — checklist final de segurança

Data: 2026-09-30

Checkpoint de entrada:

`4abc383b468e0aaeb7cf20b4cb3402e376309945`

Estado inicial:

`SECURITY_REVIEW_REQUIRED`

Este documento é um gate técnico de release da v1.

Ele não declara conformidade geral, conformidade LGPD, validação de produção,
aceite de riscos ou autorização de merge/tag/deploy.

## Regra de classificação

Estados permitidos:

- `PASS` — enforcement/evidência atual suficiente para o escopo v1;
- `PARTIAL` — parte importante validada, mas existe lacuna explícita;
- `PENDING` — exige verificação nesta revisão;
- `DEFERRED` — fora do escopo da v1, com restrição explícita;
- `BLOCKER` — impede fechamento do checklist/release até decisão ou tratamento.

Não converter documentação proposta em controle implementado.

## 1. Integridade do repositório e reprodução

- [x] CI repository-only validado.
  Estado: `PASS`.

- [x] Suíte completa validada em checkout limpo.
  Estado: `PASS`.

- [x] Restore independente por custom dump validado.
  Estado: `PASS`.

- [x] Reconstrução por bootstrap Git + migrations 002..012 validada.
  Estado: `PASS`.

- [x] RESTORE-A x RESTORE-B estruturalmente equivalentes.
  Estado: `PASS`.

- [x] Confirmar novamente branch/HEAD/worktree antes da decisão final.
  Estado: `PASS`.

## 2. PostgreSQL e memória permanente

- [x] Produção observada em `schema_version 1..12`.
  Estado: `PASS`.

- [x] `mimir_ops` ausente em produção.
  Estado: `PASS`.

- [x] Migrations 014/015/016 permanecem fora de produção.
  Estado: `PASS`.

- [x] `mimir_app` sem leitura direta ampla das tabelas protegidas.
  Estado: `PASS`.

- [x] Escrita/promoção de memória separadas.
  Estado: `PASS`.

- [x] Promoção automática para `active` bloqueada.
  Estado: `PASS`.

- [x] Revisão humana autenticada antes de promoção.
  Estado: `PASS`.

- [x] Embedding/visibilidade semântica somente após promoção.
  Estado: `PASS`.

## 3. Operações e equipamentos

- [x] Operações remotas usam catálogo fechado.
  Estado: `PASS`.

- [x] EXECUTE `generic-linux` permanece restrito ao caminho homologado.
  Estado: `PASS`.

- [x] EXECUTE exige controles de autorização/ChangePermit no fluxo validado.
  Estado: `PASS`.

- [x] MikroTik permanece READ-only na v1.
  Estado: `PASS`.

- [x] MikroTik EXECUTE permanece pós-v1.
  Estado: `DEFERRED`.

- [x] FiberHome, H3C, Intelbras e adapters adicionais permanecem pós-v1.
  Estado: `DEFERRED`.

- [x] SSH real MikroTik utilizou chave pública e host key verificada.
  Estado: `PASS`.

- [x] Shell arbitrário não foi adicionado como API operacional.
  Estado: `PASS`.

- [x] Falha/resultado incerto de EXECUTE exige reconciliação e não repetição
  automática.
  Estado: `PASS`.

## 4. Backup, restore e continuidade

- [x] Backup/restauração do estado suportado pelo adapter generic-linux foi
  demonstrado em LAB.
  Estado: `PASS`.

- [x] Restore do baseline PostgreSQL 1..12 foi reproduzido por dois caminhos.
  Estado: `PASS`.

- [ ] Backup completo de dados reais de produção não foi demonstrado.
  Estado: `PARTIAL`.

- [ ] RPO e RTO formais não estão comprovados.
  Estado: `BLOCKER`.

A evidência atual não deve ser descrita como plano completo de continuidade de
produção.

## 5. Segredos, dados e evidências

- [x] Tokens, chaves privadas, senhas e backups reais permanecem fora do Git por
  política.
  Estado: `PASS`.
  Limite: enforcement existente é específico; não equivale a DLP geral.

- [x] Evidência operacional real é classificada como confidencial e permanece
  fora do Git.
  Estado: `PASS`.

- [x] Retenção ops v1 proíbe purge automático.
  Estado: `PASS`.

- [x] Histórico failed/interrupted deve ser preservado.
  Estado: `PASS`.

- [x] Executar verificação final do conteúdo versionado para padrões óbvios de
  segredo antes do fechamento.
  Estado: `PASS`.
  Evidência: 142 arquivos versionados; nenhum achado real; 1 fixture
  sintético conhecido validado por caminho e conteúdo.

A redaction atual é heurística e não deve ser descrita como DLP geral.

## 6. Runtime e canais atuais

- [x] `plugins.allow` foi explicitamente definido no marco P0 runtime.
  Estado: `PASS`.
  Limite: sustentado pela evidência versionada do marco correspondente.

- [x] Telegram foi validado com DM allowlist e grupos desabilitados.
  Estado: `PASS`.
  Limite: sustentado pela evidência versionada do marco correspondente.

- [x] Revalidar de forma read-only o baseline atual do VPS antes da decisão
  final de release.
  Estado: `PASS`.
  Evidência: validator RC 0; PostgreSQL administrativo com
  `transaction_read_only=on`, versões 1..12 e `mimir_ops=false`.

- [x] WhatsApp permanece fora do runtime v1 atual.
  Estado: `DEFERRED`.

- [x] Webchat público permanece fora do runtime v1 atual.
  Estado: `DEFERRED`.

- [x] Voice/STT administrativo permanece fora do runtime v1 atual.
  Estado: `DEFERRED`.

## 7. Segurança conversacional / IA

Referências:

- `docs/SECURITY.md`;
- `docs/CONVERSATIONAL_SECURITY.md`;
- `docs/AI_SECURITY_TEST_MATRIX.md`;
- `docs/AI_SECURITY_GAP_INVENTORY.md`.

O repositório classifica a arquitetura conversacional ampla como ainda
incompleta. Portanto:

- [x] Conteúdo protegido não promove memória automaticamente.
  Estado: `PASS`.

- [x] Protected consolidator validou controles adversariais prioritários no
  escopo repository/LAB já documentado.
  Estado: `PASS`.
  Limite: somente no escopo repository/LAB já validado.

- [ ] Não existe policy/PDP transversal para toda tool call.
  Estado: `PARTIAL`.

- [ ] Não existe output DLP/exposure gate geral para todos os canais.
  Estado: `PARTIAL`.

- [ ] Não existe envelope universal de principal/tenant/scope/trust.
  Estado: `PARTIAL`.

- [ ] Cross-user/cross-tenant isolation genérica não está comprovada.
  Estado: `DEFERRED`.
  Limite: não habilitar escopo multiusuário/multitenant na v1.

- [ ] Rate limiting geral por canal/tool/principal não está comprovado.
  Estado: `PARTIAL`.
  Limite: não ampliar canais públicos enquanto o controle geral estiver ausente.

- [ ] A suíte completa T-AI-001..035 não está validada como enforcement global.
  Estado: `PARTIAL`.

Esses gaps não podem ser apresentados como controles implementados.

Para a v1 restrita, qualquer funcionalidade que dependa desses controles deve
permanecer desabilitada ou fora de escopo.

## 8. Riscos históricos P0 que exigem reconciliação

Os documentos históricos de cybersecurity registraram:

- `RSK-P0-001` — migration 001/schema reproduzível;
- `RSK-P0-002` — confiança indevida no antigo "22/22";
- `RSK-P0-003` — governança LGPD;
- `RSK-P0-004` — backup/restauração;
- `RSK-P0-005` — resposta a incidentes.

Eles foram registrados como abertos e não aceitos.

Estado observado em 2026-09-30:

### RSK-P0-001

Bootstrap canônico + migrations 002..012 e RESTORE-A x RESTORE-B demonstraram
reprodução do baseline 1..12.

Disposição técnica proposta para reconciliação:

`TREATED_BY_LATER_EVIDENCE`

O SQL histórico 001 continua não recuperado, mas sua ausência não impede mais
a reconstrução técnica demonstrada.

### RSK-P0-002

A declaração histórica "22/22" continua sem ser usada como evidência da release
atual.

Disposição para reconciliação:

`HISTORICAL_UNCERTAINTY_PRESERVED`

A decisão final da v1 deve se apoiar nas evidências atuais, não no "22/22".

### RSK-P0-003

Governança LGPD formal continua sem tratamento comprovado no repositório
observado.

Estado:

`BLOCKER`

Nenhuma conclusão jurídica é produzida por este checklist.

### RSK-P0-004

Backup/restore recebeu evidência posterior relevante, incluindo adapter e
reconstrução PostgreSQL, porém backup completo de produção e RPO/RTO não estão
demonstrados.

Disposição técnica para reconciliação:

`PARTIALLY_TREATED`

### RSK-P0-005

Existe reconciliação técnica de falhas operacionais, mas um plano formal de
resposta a incidentes e exercício correspondente não estão comprovados.

Estado:

`BLOCKER`

### Atualização 2026-10-02 — RSK-P0-005

O estado histórico acima foi preservado.

Desde aquela reconciliação:

- o plano formal foi implementado em `docs/INCIDENT_RESPONSE.md`;
- o plano possui SHA-256 `185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`;
- a validação repository-only do plano foi concluída em PASS;
- a rastreabilidade com o design e os controles existentes foi validada;
- nenhuma execução de incidente/tabletop ocorreu;
- aprovação humana do plano permanece pendente;
- o exercício sintético isolado permanece pendente.

Estado reconciliado:

`PLAN_REPOSITORY_VALIDATED / OPEN_BLOCKER`

O risco não está encerrado.

`RSK-P0-005` permanece blocker até aprovação humana, exercício isolado PASS e
reconciliação final do risco.

### Atualização 2026-10-02 — aprovação humana e exercício RSK-P0-005

O plano formal de resposta a incidentes:

`docs/INCIDENT_RESPONSE.md`

SHA-256:

`185480f739b1f33800f0fc91760dccbacf612f74fb1826d8a9b7609d3bcc3243`

foi aprovado explicitamente pelo responsável humano.

Estado do plano:

`REPOSITORY_VALIDATED / HUMAN_APPROVED`

Também foi autorizado o desenho do exercício sintético, registrado como:

`MIMIR-IR-TTX-001`

A execução do exercício NÃO está autorizada por esta decisão.

Estado do exercício:

`DESIGN_PROPOSED / NOT_EXECUTED`

Estado do risco:

`RSK-P0-005 = OPEN / BLOCKER`

Ainda são necessários implementação repository-only do exercício, validação do
harness, autorização explícita de execução, exercício controlado e reconciliação
final da evidência.

### Atualização 2026-10-02 — harness repository-only RSK-P0-005

Os artefatos do exercício sintético `MIMIR-IR-TTX-001` foram implementados e
validados no repositório.

Identidades:

- fixture SHA-256: `2c93342f96bc6e925e5a15d6b8e8fe85d36a051921a3644050dd31bd36f7ecec`;
- harness SHA-256: `affc32a869d9a5f97eb2fd1567cf601c8fe6c8e5bfc033551e81cda150bccd94`;
- validator SHA-256: `d8c1218cfd787879c03c81b41f4c24bea00b2e74fb1c047afeb36cbf6a5673a0`.

Resultado:

`HARNESS_REPOSITORY_VALIDATED`

O validator foi executado somente em modo:

`--validate-fixture-only`

O tabletop não foi executado e ainda exige autorização humana explícita
separada.

Evidência repository-only SHA-256:

`7e56f47342b874db48783cd2774758923213ddd3cc1c0e06bcb2554e375a8157`

Estado:

`RSK-P0-005 = OPEN / BLOCKER`

Ainda são necessários:

1. autorização explícita para uma execução controlada do tabletop;
2. execução única do cenário sintético;
3. preservação da evidência;
4. classificação PASS/FAIL;
5. reconciliação final de RSK-P0-005.

### Atualização 2026-10-02 — reconciliação final RSK-P0-005

O exercício sintético isolado `MIMIR-IR-TTX-001` foi executado exatamente uma
vez sob autorização humana explícita.

Resultado:

`PASS`

Falhas de critério:

`0`

Resíduo:

`ZERO_UNEXPLAINED`

Retry automático:

`NO`

Evidências:

- execution log SHA-256: `90d203a5d36629c6da7e112f50c7abce82e04ce665df7338558d4fbef8d7489d`;
- incident record SHA-256: `fe75525cb14f2a7e041e62ba1a34dd7d348032b1f4333c49601fd474fd5c56bf`;
- evidence manifest SHA-256: `063f58968d453b47305fcd2525116c178022de5ed5555963f4c014e62cd0be79`.

A revisão das evidências confirmou preservação das fronteiras de autorização e
ausência de acesso a produção, PostgreSQL, runtime de modelo, rede externa,
SSH, equipamento real ou credencial real.

Os requisitos previamente registrados para tratamento de `RSK-P0-005` foram
satisfeitos:

- plano formal;
- validação repository-only;
- aprovação humana;
- exercício isolado;
- PASS;
- evidência preservada;
- reconciliação final.

Estado técnico atual:

`RSK-P0-005 = CLOSED / TECHNICALLY_TREATED / SYNTHETIC_TABLETOP_VALIDATED`

O fechamento é por tratamento técnico comprovado, não por aceite de risco.

Não há alegação de validação produtiva, conformidade legal ou conformidade
LGPD.

Os registros históricos `OPEN / BLOCKER` permanecem preservados.

`RSK-P0-003` e `RSK-P0-004` continuam bloqueando release, merge, stable tag e
deployment produtivo.

### Atualização 2026-10-02 — desenho de tratamento RSK-P0-003

A inspeção atual confirmou que existem controles e conceitos de privacidade
distribuídos no repositório, porém a governança formal aprovada e comprovada
ainda não está estabelecida.

Estado:

`RSK-P0-003 = OPEN / BLOCKER`

Tratamento proposto:

1. governança canônica de privacidade;
2. registro sanitizado das atividades de tratamento;
3. autoridade e papéis explícitos;
4. controlador/operador por atividade quando aplicável;
5. finalidade e decisão de base legal por revisão humana competente;
6. direitos dos titulares;
7. retenção e descarte governados;
8. integração com resposta a incidentes;
9. governança de terceiros;
10. estado explícito de transferência internacional;
11. revisão periódica/evidência;
12. validator repository-only;
13. aprovação humana competente separada;
14. reconciliação final.

A implementação não poderá inferir automaticamente base legal, necessidade de
encarregado, comunicação à ANPD ou conformidade LGPD.

A presença de termos nos documentos atuais não será considerada prova de
governança formal.

O tratamento proposto não altera os registros históricos P0 e não constitui
aceite de risco.

### Atualização 2026-10-03 — validação repository-only RSK-P0-003

Checkpoint:

`MIMIR-V1-RSK-P0-003-PRIVACY-GOVERNANCE-REPOSITORY-VALIDATION-01`

Estado comprovado no repositório:

- `FORMAL_GOVERNANCE_PACKAGE = REPOSITORY_VALIDATED`;
- `COMPETENT_HUMAN_APPROVAL = PENDING`;
- `COMPETENT_PRIVACY_AUTHORITY = PENDING_COMPETENT_REVIEW`;
- `DPO_STATE = PENDING_COMPETENT_REVIEW`;
- `RSK-P0-003 = OPEN / BLOCKER`;
- `RISK_ACCEPTANCE = NOT_USED`;
- `LEGAL_CONCLUSION = NO`;
- `LGPD_COMPLIANCE_CLAIM = NO`;
- `PRODUCTION_VALIDATION = NO`;
- 12/12 atividades e matriz de lifecycle states validadas;
- validator estático repository-only e testes 10/10 aprovados;
- nenhum dado pessoal bruto, segredo, valor de credencial ou identificador
  governamental presente no pacote.

A primeira tentativa de commit foi interrompida por trailing whitespace. A
correção removeu somente whitespace final, sem mudança semântica, e a
revalidação passou integralmente. Este checkpoint comprova somente
`REPOSITORY_PACKAGE_STRUCTURALLY_VALIDATED`; não comprova aprovação competente,
conclusão legal, validação produtiva ou encerramento do risco.

NEXT_ACTION:

`REQUEST_HUMAN_APPROVAL_RSK_P0_003_PRIVACY_GOVERNANCE_PACKAGE`

### Atualização 2026-10-03 — aprovação humana e reconciliação local RSK-P0-003

Checkpoint:

`MIMIR-V1-RSK-P0-003-HUMAN-APPROVAL-AND-RECONCILIATION-01`

- approved snapshot: implementation
  `34f78b80cd77e675a699001e43e0cf556ad091c0` and repository-validation
  checkpoint `0574ab8e6c15eb62fd74c066a18b508b576c32e9`;
- internal human governance approval: `APPROVED`;
- approver identity reference: `Nogueira Maier`;
- roles: Project/System Owner and Privacy Governance Owner;
- `ROLE_OVERLAP = PRESENT`;
- `DECLARED_CONFLICT = NO_KNOWN_CONFLICT`;
- `INDEPENDENT_REVIEW_REQUIRED = NO` under the versioned conflict-triggered
  compensation rule;
- Phase A repository validation: PASS; tests: 10/10 PASS;
- DPO, legal-basis, international-transfer, `NOT_PROVEN`, third-party,
  lifecycle and production states: unchanged;
- explicit local reconciliation: PASS;
- `RSK-P0-003 = CLOSED / TECHNICALLY_TREATED /
  PRIVACY_GOVERNANCE_APPROVED`;
- `RISK_ACCEPTANCE = NOT_USED`;
- `DPO_STATE = PENDING_COMPETENT_REVIEW`;
- `LEGAL_CONCLUSION = NO`;
- `LGPD_COMPLIANCE_CLAIM = NO`;
- `PRODUCTION_VALIDATION = NO`.

The closure is limited to the defined local technical governance-treatment
gate. It does not resolve the DPO decision, approve individual legal bases,
prove international transfers or third-party facts, validate production or
remove RSK-P0-004.

NEXT_ACTION:

`FRESH_FETCH_GUARD_BEFORE_COMMIT_RSK_P0_003_HUMAN_APPROVAL_AND_RECONCILIATION`

## 9. Restrições obrigatórias da v1

Enquanto gaps não forem tratados em checkpoints próprios:

- não ampliar tools do agente main;
- não disponibilizar shell arbitrário;
- não habilitar MikroTik EXECUTE;
- não habilitar adapters pós-v1;
- não habilitar canais públicos novos;
- não tratar voz como autenticação;
- não enviar conteúdo `CONFIDENTIAL` para modelo externo;
- não permitir promoção automática de memória;
- não implantar migrations 014/015/016 em produção;
- não criar `mimir_ops` em produção;
- não remover PR #1 de Draft;
- não fazer merge;
- não criar tag estável.

## 10. Gates restantes para fechamento

Para marcar este checklist `PASS / CLOSED`, executar no mínimo:

1. validação read-only final do VPS;
2. inspeção final de segredos no conteúdo versionado;
3. confirmar produção `1..12` e ausência de `mimir_ops`;
4. reconciliar formalmente os riscos P0 históricos com evidência posterior;
5. decidir o tratamento/restrição de `RSK-P0-003` e `RSK-P0-005`;
6. registrar riscos residuais/deferred controls sem alegar implementação;
7. somente então atualizar o plano mestre.

## Resultado atual

`SECURITY_CHECKLIST_CREATED`

`FINAL_SECURITY_DECISION = BLOCKED_FOR_RELEASE`

Não autorizado por este documento:

- production deployment;
- Draft removal;
- merge;
- stable tag.

## Histórico de validação do checklist

### Candidato `70a8819`

Resultado:

`NOT_VALIDATED`

A primeira validação após a criação do checklist encontrou dois problemas:

1. `classification_guard` recusou o estado não canônico
   `BLOCKER`;
2. o secret scan sinalizou `tools/ops/test_mimir_ops.py` porque o teste de
   redaction contém deliberadamente o fixture sintético
   `fixture sintético de cabeçalho OpenSSH private-key com conteúdo fictício`.

O segundo achado é um fixture sintético usado para testar redaction e não uma
chave privada real.

O shell interativo continuou após os guards falharem e criou o commit
`70a8819`. Esse commit fica preservado como candidato não validado.

A correção mantém o secret scan fail-closed e permite somente esse fixture
sintético conhecido, por caminho e conteúdo exatos.

## Validação final de 2026-09-30

Validated technical HEAD antes desta atualização:

`cbc90513ee4d1a0978e079bc7d012bafbf77c574`

Resultados:

- classification guard: PASS;
- secret scan: PASS;
- synthetic private-key fixture: exatamente 1, conhecido e controlado;
- VPS/host read-only validator: RC 0;
- PostgreSQL production transaction: read-only;
- production schema: `1..12`;
- production 14/15/16: false;
- production `mimir_ops`: false;
- `pgcrypto`: true;
- `vector`: true;
- `mimir_app` direct session source SELECT: false;
- `mimir_app` legacy ingest EXECUTE: true.

Reconciliação formal:

`docs/review/security/2026-09-30-v1-security-reconciliation.md`

Resultado do gate:

`REVIEWED / BLOCKED_FOR_RELEASE`

PR #1 pode ser revisado enquanto permanece Draft.

Continuam bloqueados:

- Draft removal;
- merge;
- stable tag;
- production deployment.

## Atualização pós-revisão do PR #1 — 2026-10-01

Checkpoint:

`MIMIR-V1-P1-PR-REVIEW-01`

Validated/base HEAD:

`115e39a3650ca5150e27c2326b3c6f7a569df62d`

A revisão técnica do PR #1 foi concluída nesta rodada com sete findings
tratados e versionados.

Isso não altera a decisão deste checklist:

`FINAL_SECURITY_DECISION = BLOCKED_FOR_RELEASE`

O PR permanece Draft.

O protected consolidator exige revalidação integrada com o Qwen real após a
mudança de evidence binding do FINDING-05.

Continuam bloqueados:

- Draft removal;
- merge;
- stable tag;
- production deployment.

Os blockers históricos/residuais permanecem conforme a reconciliação formal,
incluindo RSK-P0-003, RSK-P0-004 e RSK-P0-005.

Evidência detalhada:

`docs/review/security/2026-10-01-pr1-review-reconciliation.md`
