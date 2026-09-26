# Estado técnico do Projeto Mimir

Data da consolidação original: 2026-07-30
Última atualização documental: 2026-09-24

## Declarações históricas de 2026-07-30

Os itens abaixo preservam o registro anterior; não constituem comprovação do estado atual do VPS.

- OpenClaw instalado
- Serviço administrado pelo OpenRC
- Agente main identificado como Mimir
- PostgreSQL 17 operacional
- pgvector operacional
- Banco mimir_memory criado
- Embedding local operacional
- Vetores com 768 dimensões
- Busca semântica no PostgreSQL validada
- Role mimir_search criada
- Plugin mimir-memory carregado
- Promoção automática bloqueada

## Estado histórico do Git

Os itens abaixo representam o snapshot documentado em 2026-07-30, salvo indicação contrária:

- Branch principal main
- Repositório remoto público NogueiraMaier/projeto-mimir
- Primeiro commit publicado: 3e2e84d46ac57936886389138dce384ae26c8f3a
- Hash local e remoto foram conferidos naquele snapshot
- Árvore de trabalho foi registrada como limpa após o primeiro envio
- Nenhuma tag foi registrada naquele snapshot

Para o estado atual, executar os comandos do RUNBOOK.md.

## Memória permanente

A validação documentada em 30 de julho de 2026 recuperou cinco memórias conhecidas e concluiu 6 testes em 6. Evidência: docs/VALIDACAO_MEMORIA.md.

## Captura e ingestão de sessões

- capturador seguro implementado em dry run;
- migration 008 de ingestão protegida existente;
- cliente tools/memory/mimir-ingest-session.py presente em modo dry run;
- promoção automática para candidate/active continua bloqueada.

## Camada operacional — revisão local de 2026-09-22

- **IMPLEMENTADO:** CMDB com clientes/sites/equipamentos, interfaces, IPs,
  sub-redes, VLANs, acessos por referência e dependências; migration 013 corrigida.
- **IMPLEMENTADO:** CLI PostgreSQL de cadastro/listagem/consulta, histórico e
  relatório, por API controlada e role operacional dedicada inicialmente desabilitada.
- **IMPLEMENTADO:** catálogo por operação/adapter, aprovação por hash de plano,
  SSH limitado, redaction e fluxo precheck/snapshot/backup/execute/validate/report.
- **IMPLEMENTADO:** alteração transitória de hostname Linux e diagnóstico Linux/MikroTik.
- **IMPLEMENTADO:** evidências, diário, relatórios JSON/Markdown e atualização
  transacional da observação de inventário, com estado incerto em falhas de alteração.
- **IMPLEMENTADO:** validador de VPS somente leitura e testes locais sem equipamentos.
- **PARCIAL:** rollback manual, backup somente do estado alterado, normalização
  automática de topologia e integração de intervenção à memória permanente.
- **PLANEJADO:** backup completo/restauração, adapters adicionais, reconciliação
  assistida de intervenções interrompidas e integração humana da memória.
- **NÃO VALIDADO EM PRODUÇÃO:** migration 013, identidade peer operacional,
  PostgreSQL real e comandos SSH em equipamentos.

Código de memória, migrations 002–008 e runtime do plugin foram preservados.
Scripts de teste/build do plugin agora aceitam dependências locais, mantendo a
instalação compartilhada de `/opt/openclaw` como alternativa.

Validação e evidências locais: [revisão operacional](review/operations/2026-09-22.md).
Operação e instalação futura: [OPERATIONS.md](OPERATIONS.md).

## Próximas etapas

Validar primeiro o VPS com `tools/validation/validate-vps-readonly.sh`, sob
identidade peer existente e autorizada. Testar SQL em banco descartável antes
de qualquer implantação, revisar backup/restauração e provisionamento da role,
e somente então autorizar equipamento de laboratório em READ. As lacunas
históricas da memória e de governança não foram encerradas por esta revisão.


## Atualização operacional — 2026-09-24

- **VALIDADO EM RUNTIME:** OpenClaw 2026.9.5 ativo, configuração válida e plugin `mimir-memory` carregado em versão 0.2.6.
- **CORRIGIDO:** provider local de embeddings migrado para o `llama-cpp` Managed local server, sem alterar o modelo de chat atual.
- **VALIDADO:** memória nativa reindexada; 9/9 arquivos, 77 chunks, `dirty=false`, índice vetorial complete, `semanticAvailable=true`, 768 dimensões e `embeddingProbe.ok=true`.
- **VALIDADO EM LAB ISOLADO:** `013_operational_inventory.sql` aplicada em cluster PostgreSQL temporário, com versões 1–13, 15 tabelas ops e `mimir.ops_api(jsonb)`.
- **PRODUÇÃO INTACTA:** `mimir_memory` permanece em versões 1–12 e a role `mimir_ops` continua ausente.
- **PENDENTE:** validar `013_operational_role.sql`, grants mínimos, peer dedicado e API funcional apenas no laboratório.
- **PENDENTE:** corrigir metadata drift do plugin (runtime 0.2.6 versus Recorded version 0.1.0) e definir `plugins.allow` explícito.

## Atualização operacional — LAB-07 a LAB-09

- **VALIDADO EM LAB:** fluxo EXECUTE sintético completo `PRECHECK -> SNAPSHOT -> BACKUP -> EXECUTE -> VALIDATE -> DONE`, sem equipamento real.
- **VALIDADO EM LAB:** backup/restore do PostgreSQL operacional temporário com inventário restaurado idêntico.
- **VALIDADO EM LAB:** reconciliação fail-closed de EXECUTE interrompido; novo EXECUTE fica bloqueado até reverificação READ.
- **HARDENING VERSIONADO:** `86cf4a96a176c7ac2fdb9decb9c26dc89ecbac38` bloqueia EXECUTE quando `observed_state.state=unknown_requires_manual_verification`.
- **POLÍTICA v1 DEFINIDA:** retenção operacional sem expurgo automático; failed/interrupted preservados; dados reais confidenciais e fora do Git.
- **PRODUÇÃO INTACTA:** `mimir_memory` segue em versões 1–12 e sem role `mimir_ops`.
- **VALIDADO P0:** bootstrap canônico da memória v1 reproduziu versões 1–12 em banco descartável; o SQL histórico original da migration 001 continua não recuperado e é tratado como lacuna histórica documentada.
- **LAB TEMPORÁRIO REMOVIDO:** `/var/tmp/mimir-pg13-lab` foi parado e removido após evidências, backup/restore e bootstrap; produção permaneceu operacional em 1–12.
- **VALIDADO P0 RUNTIME:** `mimir-memory 0.2.7` carregado/ativado em produção; `mimir_memory_search` registrado; caminho direto `tools.invoke` aprovado com embedding local gerenciado e consulta PostgreSQL; backup/rollback 0.2.6 preservado. O registro histórico de instalação ainda mostra 0.2.6 e não foi reescrito.
- **VALIDADO:** canal Telegram `@MimirAssistenteBot` operacional; entrada, resposta e envio proativo confirmados; DM restrita por allowlist; token fora do Git.
- **VALIDADO TELEGRAM-02:** em sessão nova, o runtime registrou `context.compiled (2 tools)`, `tool.call mimir_memory_search`, `tool.result ... ok` e `session.ended success`; o caminho explícito Telegram -> agente -> memória 0.2.7 -> embedding -> PostgreSQL está aprovado.
- **PENDENTE P1 MEMÓRIA — CAUSA CONFIRMADA:** produção possui apenas 5 memórias ativas, todas embedadas, todas originadas de `MEMORY.md` em 2026-07-30; nenhuma contém migration 013, LAB-01..LAB-09, `mimir_ops` ou `schema_version`. A falha semântica observada no Telegram é de cobertura do corpus, não de embedding/ranking.
- **PIPELINE DE INGESTÃO — GARGALO LOCALIZADO:** `memory_events` tem somente 2 documentos Markdown + 1 sessão protegida, todos de 2026-07-30; não há candidatos, revisões recentes nem embeddings pendentes. O conhecimento operacional atual nunca chegou à ingestão, portanto o bloqueio ocorre antes de consolidação/revisão/promoção.
- **BLOQUEADOR P1 CONFIRMADO:** os scripts de captura/ingestão de sessão ainda são os de 2026-07-30 e esperam o layout legado `agents/main/sessions/sessions.json` + JSONL. O OpenClaw 2026.9.5 usa SQLite canônico em `agents/<agentId>/agent/openclaw-agent.sqlite`; `mimir-ingest-session.py` continua aceitando somente `--dry-run`.
- **STORE ATUAL VALIDADO:** CLI canônica enxerga 18 sessões no SQLite principal, 12 com `status=done`; a única linha de cron encontrada é `mimir-security-audit --scheduled` e não existe evidência de agendamento de ingestão de memória. Compatibilidade do coletor: `sessions.json=true`, JSONL=true, SQLite=false.
- **CHAT.HISTORY VALIDADO:** probe read-only da sessão Telegram confirmou `senderIsOwner=true`, IDs/seq, timestamp, paginação e deltaCursor; a fronteira suportada é suficiente para projetar o coletor sem SQL direto. O payload também contém system/toolResult/thinking/toolCall, que deverão ser excluídos explicitamente.
- **SURVEY DE SESSÕES CONCLUÍDO:** 12/12 sessões `done` (Telegram, HUD, ACP bridge, Maestro e main) passaram com `senderIsOwner=true` para todas as mensagens user, IDs/seq/timestamp presentes, paginação disponível e nenhum sinal de truncamento.
- **PRÓXIMO:** implementar/testar no repositório um coletor v2 dry-run baseado em `sessions --json` + `chat.history`, mantendo o coletor legado intacto e sem deploy/escrita em produção.
- **NÃO AUTORIZADO AINDA:** equipamento real em EXECUTE.

Lista mestre de execução: [MIMIR_V1_EXECUTION_PLAN.md](MIMIR_V1_EXECUTION_PLAN.md).
Evidência da rodada: [review/operations/2026-09-24.md](review/operations/2026-09-24.md).
