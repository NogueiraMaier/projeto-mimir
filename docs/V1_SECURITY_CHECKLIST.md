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

- [ ] Confirmar novamente branch/HEAD/worktree antes da decisão final.
  Estado: `PENDING`.

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

- [ ] Executar verificação final do conteúdo versionado para padrões óbvios de
  segredo antes do fechamento.
  Estado: `PENDING`.

A redaction atual é heurística e não deve ser descrita como DLP geral.

## 6. Runtime e canais atuais

- [x] `plugins.allow` foi explicitamente definido no marco P0 runtime.
  Estado: `PASS`.
  Limite: sustentado pela evidência versionada do marco correspondente.

- [x] Telegram foi validado com DM allowlist e grupos desabilitados.
  Estado: `PASS`.
  Limite: sustentado pela evidência versionada do marco correspondente.

- [ ] Revalidar de forma read-only o baseline atual do VPS antes da decisão
  final de release.
  Estado: `PENDING`.

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

`BLOCKER_GOVERNANCE_REVIEW`

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

`BLOCKER_GOVERNANCE_REVIEW`

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

`FINAL_SECURITY_DECISION = PENDING`

Não autorizado por este documento:

- production deployment;
- Draft removal;
- merge;
- stable tag.
