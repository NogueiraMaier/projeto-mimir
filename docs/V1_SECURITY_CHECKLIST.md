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
