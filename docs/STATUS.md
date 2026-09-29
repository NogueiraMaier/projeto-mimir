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
- **COLETOR V2 READ-PATH — PASS:** checkout isolado em `/var/tmp` validou `py_compile`, 2 testes sintéticos e dry-run contra o Gateway real. Resultado: 18 sessões consideradas, 12 ready, 0 blocked, 6 skipped (`status=unknown`), 0 errors; sem escrita PostgreSQL, sem staging, sem exposição de conteúdo e sem SQL direto no SQLite. As 12 ready coincidem com o survey anterior e preservam owner provenance.
- **WRITE-PATH V2 — CONTRATO REPOSITÓRIO IMPLEMENTADO:** `014_api_session_ingestion_v2.sql` define proveniência `openclaw-chat-history-v2`, cria `ingest_session_v2`, preserva fonte confidential/protegida e revoga o ingresso legado de `mimir_app`. A 013 operacional permanece reservada e não foi renumerada. Nada foi aplicado em produção.
- **VALIDAÇÃO 014 PREPARADA:** `validate-session-ingestion-v2-lab.sh` exige banco `mimir_lab*`, faz dump pré-014 e testa ACL, peer, idempotência, protected read, rejeições e ausência de resíduo sintético.
- **CAPTURE V2 / 014 PREFLIGHT — PASS:** checkout isolado no HEAD `700f640fb0a2e92be90de7a02459cb2eb02f104c` passou source guard, py_compile, 2 testes sintéticos e live dry-run. Resultado permaneceu 18 consideradas / 12 ready / 0 blocked / 6 skipped / 0 errors; os 12 ready passaram `v2_provenance_guard` com os novos metadados seguros.
- **LAB 014 — RECONSTRUÇÃO NECESSÁRIA:** não existe `mimir_lab*` no cluster de produção; o laboratório anterior foi limpo intencionalmente. Foi adicionado `prepare-session-ingestion-v2-lab.sh` para recriar um PostgreSQL 17 isolado em `/var/tmp/mimir-pg14-lab` a partir do bootstrap canônico + migrations 002..012, sem clonar produção. O validador 014 agora rejeita explicitamente socket/porta de produção e verifica o `data_directory` temporário.
- **LAB 014 SOCKET — CAUSA EXATA CONFIRMADA:** o retry falhou porque `unix_socket_group=openclaw` exigia que o processo PostgreSQL mudasse o grupo do socket para `openclaw`, mas a conta `postgres` não pertence a esse grupo; o kernel retornou `Operation not permitted`. A 014 não foi aplicada e produção permaneceu intacta.
- **CORREÇÃO VERSIONADA:** LAB_ROOT permanece `postgres:openclaw 0710` e socket dir `postgres:openclaw 0770`; o socket fica `postgres:postgres 0777`. O diretório restringe quem alcança o socket e peer/pg_ident continua impondo `openclaw -> mimir_app`, sem alteração persistente de grupos do host.
- **LAB 014 BASELINE — PASS:** rebuild limpo no commit `7815cb4b9d8b62c4d7e64e6e5c2decf15564cfa3` confirmou cluster isolado, socket `postgres:postgres 0777` atrás de diretórios restritos, bootstrap v1 + migrations 002..012, schema 1..12, peer `mimir_app|peer:openclaw` e produção intacta.
- **MIMIR-V1-MEMORY-014-LAB-01 — PASS:** migration 014 aplicada somente no lab isolado com dump pré-014 SHA-256 `82c9ecc10835f47555ee4770bb7f7533e14b32b6876b6bc3a0dcbb92ffd0e2f4`. ACL, peer, idempotência, protected read, rejeição de classe/hash e rollback sem resíduo passaram. Lab ficou em 1..12,14; produção permaneceu 1..12, sem v14 e sem `mimir_ops`.
- **WRITER V2 — IMPLEMENTADO NO REPOSITÓRIO, NÃO VALIDADO:** `mimir-ingest-session-v2.py` reutiliza a captura in-process, exige hashes esperados, emite approval digest em dry-run e requer `--write --approve` para escrita local via socket Unix. Conteúdo vai ao psql somente por stdin, sem staging/argv/stdout. Foram adicionados testes sintéticos e validador end-to-end de laboratório.
- **WRITER V2 PREFLIGHT — PASS:** syntax, capture regression, 4 testes sintéticos do writer e live capture regression passaram no commit `91309ff92dea041f03a66910402bb4fdcc0328c4`; live permaneceu 12 ready / 0 blocked / 6 skipped / 0 errors sem serializar conteúdo interno.
- **WRITER LAB — HARNESS BUG CORRIGIDO:** o primeiro end-to-end parou no residue precheck antes de qualquer write porque placeholders `:'sid'` enviados via `psql -c` chegaram literais ao servidor. O harness foi corrigido para usar stdin/heredoc em todas as consultas com variáveis psql. Lab 1..12,14 permanece reutilizável e sem sessão sintética inserida.
- **MIMIR-V1-MEMORY-WRITER-V2-LAB-01 — PASS:** writer dry-run/aprovação/write sintético/idempotência/proveniência/protected read/zero promoção automática/cleanup passaram no lab 1..12,14. Resíduo final: 0. Produção permaneceu 1..12, sem v14 e sem `mimir_ops`.
- **LOCAL MODEL INVENTORY — DRIFT IDENTIFICADO:** o VPS está executando `mimir-llama`/Qwen3-4B-Q4_K_M em `127.0.0.1:8080`, mas 8080 não é a porta canônica do fallback VPS. Mapa estabelecido: PcIA CUDA=18781, VPS CPU fallback=18782, OpenClaw Gateway=18789. Logo 8080 é drift/configuração a diagnosticar, não novo padrão. Produção continuou 1..12 sem v14.
- **PROBE 8080 — PARCIAL:** `/health` e `/v1/models` responderam, porém o teste de chat foi inconclusivo por erro do comando de validação (pipe + Python heredoc disputando stdin), não por falha comprovada da API.
- **AI/CONVERSATIONAL SECURITY — PROPOSTA VERSIONADA:** `CONVERSATIONAL_SECURITY.md` formaliza conteúdo externo como dado não confiável e separa identidade/autorização de conteúdo; `AI_SECURITY_TEST_MATRIX.md` registra T-AI-001..035. Não declarar a camada como implementada sem enforcement e evidência.
- **GAP DE MODELAGEM:** as classes de memória de segurança propostas não correspondem diretamente aos `memory_type` atuais; requer decisão explícita de mapping/extension antes de alterar schema.
- **LLAMA PORT DRIFT — CAUSA CONFIRMADA:** `/etc/init.d/mimir-llama` usa `--port ${listen_port}` e `/etc/conf.d/mimir-llama` define explicitamente `listen_port="8080"`. A porta canônica VPS continua 18782; 8080 é drift de configuração. Nenhuma alteração foi feita.
- **LLAMA PORT CORRECTION — APLICADA:** `listen_port` foi corrigido para 18782 e somente `mimir-llama` foi reiniciado. Processo/listener confirmaram `127.0.0.1:18782`; 8080 não apareceu mais. OpenClaw Gateway permaneceu em 18789.
- **LLAMA 18782 READINESS/API — PARCIAL PASS:** `/health` retornou 200/ok e `/v1/models` identificou Qwen3-4B-Q4_K_M. Chat sintético retornou HTTP 200/`chat.completion`, porém `finish_reason=length` com `content` vazio; logo transporte/API estão validados, mas resposta textual útil ainda não.
- **PORT/PRODUCTION GUARDS — PASS:** 18782 permanece listener canônico, 8080 fechado, 18789 Gateway; PostgreSQL produção segue 1..12 sem v14.
- **MIMIR-V1-LOCAL-LLAMA-18782-CHAT-01 — PASS:** modo normal retornou content=36 chars + reasoning_content=947 chars, 236 completion tokens; com `enable_thinking=false`, retornou somente content=36 chars, JSON sintético válido, em 11 completion tokens. Endpoint canônico 18782 permanece estável.
- **DECISÃO PARA CONSOLIDATOR:** usar `enable_thinking=false` por request, aceitar/persistir somente `message.content`, rejeitar conteúdo vazio/JSON inválido e nunca persistir/expor `reasoning_content`.
- **AI SECURITY GAP INVENTORY — VERSIONADO:** `AI_SECURITY_GAP_INVENTORY.md` classifica controles atuais como EXISTING_VALIDATED/PARTIAL/PROPOSED/MISSING/OUT_OF_SCOPE_NOW e fixa os gaps do consolidator protected-source.
- **DECISÃO DE MODELAGEM AINDA PENDENTE:** não sobrecarregar `memory_type`; avaliar dimensão separada de trust/validation por ADR antes de qualquer mudança de schema.
- **PROTECTED SESSION CONSOLIDATOR CONTRACT — VERSIONADO:** `PROTECTED_SESSION_CONSOLIDATOR_V1.md` fixa endpoint 18782, `enable_thinking=false`, source untrusted, output `UNTRUSTED_OBSERVATION`, schema fechado, secret gate externo ao LLM e dry-run sem promoção.
- **PROTECTED CONSOLIDATOR REPOSITORY-ONLY — REPOSITORY_VALIDATED:** `MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01 = PASS` no HEAD `3d119d4a8308c1dbaf9744c9f3c7f3b77a5a8c64`. Checkout limpo, 8/8 testes aprovados e RC=0. O fake model foi isolado em network namespace e o llama.cpp real permaneceu ativo em `127.0.0.1:18782` antes e depois. Nenhum acesso ao PostgreSQL de produção, migration ou deployment ocorreu.
- **T-AI PRIORITÁRIOS — REPOSITORY_VALIDATED:** T-AI-002/005/023/024/032/033/034 possuem enforcement repository-only validado pelo harness sintético no checkpoint `MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01`. Isso não constitui validação de runtime/produção.
- **PRÓXIMO P1:** validar o protected consolidator contra PostgreSQL lab isolado 1..12,14 + Qwen real `127.0.0.1:18782`, somente com conteúdo sintético. Sessão real e PostgreSQL de produção continuam fora de escopo.
- **NÃO AUTORIZADO AINDA:** equipamento real em EXECUTE.

Lista mestre de execução: [MIMIR_V1_EXECUTION_PLAN.md](MIMIR_V1_EXECUTION_PLAN.md).
Evidência da rodada: [review/operations/2026-09-24.md](review/operations/2026-09-24.md).

## Atualização operacional — Protected Consolidator Real-Model LAB — 2026-09-27

- **REPOSITORY REGRESSION — PASS:** após normalização do wrapping Base64 PostgreSQL, 8/8 testes do protected consolidator passaram com RC=0.
- **CORREÇÃO VERSIONADA:** commit `9e2e1c13e76cc60e4b383cc0898b54aeef2bcef0`.
- **LAB 014 RECUPERADO:** PostgreSQL isolado voltou operacional após WAL recovery, preservando schema `1..12,14`, Unix socket 55433 e sem TCP.
- **REAL-MODEL LAB #1:** falhou antes do modelo por wrapping Base64 PostgreSQL; causa confirmada e corrigida; cleanup=0.
- **REAL-MODEL LAB #2:** avançou além da leitura protegida e terminou em `TimeoutError: timed out` durante interação com Qwen local `127.0.0.1:18782`.
- **FAIL-CLOSED PRESERVADO:** nenhuma promoção automática, nenhum deployment e nenhum conteúdo real utilizados.
- **CLEANUP:** `synthetic_residue=0`.
- **PRODUÇÃO INTACTA:** PostgreSQL permanece 1..12, sem migration 014 e sem deployment do writer/consolidator.
- **BLOQUEADOR ATUAL:** tratamento explícito e diagnóstico de latência/timeout do Qwen.
- **PRÓXIMO P1:** adicionar timeout handling + regression test, medir latência real e somente então repetir o LAB integrado.


## Atualização — timeout do protected consolidator — 2026-09-27

- VALIDADO: TimeoutError do modelo local agora é tratado explicitamente.
- VALIDADO: teste repository-only específico de timeout.
- VALIDADO: suite 9/9 PASS, VALIDATOR_RC=0.
- ISOLAMENTO: Qwen real em 127.0.0.1:18782 permaneceu ativo e fora do namespace de teste.
- COMMIT TÉCNICO: 28be68ea1dcccb74e74d16fe49a4943a1d316947.
- PRODUÇÃO: permanece inalterada.
- PRÓXIMO: medir latência do Qwen real antes de qualquer mudança no timeout.


## Atualização — timeout do protected consolidator — 2026-09-27

- VALIDADO: TimeoutError do modelo local agora é tratado explicitamente.
- VALIDADO: teste repository-only específico de timeout.
- VALIDADO: suite 9/9 PASS, VALIDATOR_RC=0.
- ISOLAMENTO: Qwen real em 127.0.0.1:18782 permaneceu ativo e fora do namespace de teste.
- COMMIT TÉCNICO: e62b2eed018fb3c9d5c9b499abce15ce66828667.
- PRODUÇÃO: permanece inalterada.
- PRÓXIMO: medir latência do Qwen real antes de qualquer mudança no timeout.

## Qwen latency — 2026-09-27

- **MEDIDO:** primeiro request 44.351 s.
- **MEDIDO:** warm runs 32.324 / 30.927 / 32.104 s.
- **ESTÁVEL:** 342 prompt + 190 completion tokens, finish_reason=stop.
- **SEM EVIDÊNCIA DE STALL:** Qwen 18782 responde de forma repetível.
- **TIMEOUT NÃO ALTERADO:** falta medir o payload exato do LAB integrado.

## Protected consolidator timeout — root cause

- **ROOT CAUSE CONFIRMADA:** Qwen CPU após idle pode exceder 60 s.
- **REQUEST EXATO:** HTTP 200 em 71.536 s após 90 s ocioso.
- **HARNESS:** usa `--timeout-seconds 60`.
- **CLEANUP:** synthetic_residue=0.
- **PRÓXIMO:** separar timeout PostgreSQL de timeout de inferência do modelo.


## Protected consolidator timeout split — 2026-09-27

- **IMPLEMENTADO:** timeout PostgreSQL e inferência separados.
- **POSTGRESQL:** máximo 60 s.
- **MODELO:** default 120 s, máximo 180 s.
- **FAIL-CLOSED:** preservado.
- **VALIDADO:** 10/10 testes repository-only PASS.
- **COMMIT:** `8b04510fc693442ae94d0487581d942d5ae9319e`.
- **PRÓXIMO:** repetir LAB integrado sintético com model timeout 120 s.

## REAL MODEL OUTPUT SCHEMA REJECTED — 2026-09-28

- **MODEL TIMEOUT:** 120 s reached Qwen successfully.
- **FAIL-CLOSED:** incompatible output schema rejected.
- **CLEANUP:** `synthetic_residue=0`.
- **CURRENT BLOCKER:** `REAL_MODEL_OUTPUT_SCHEMA_MISMATCH`.
- **PRODUCTION:** unchanged.
- **NEXT P1:** safe structural diagnostic of the Qwen JSON response.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-SCHEMA-DIAG-01 — 2026-09-28

- **STATUS:** BLOCKED.
- **BRANCH:** `feat/mimir-operational-foundation`.
- **SOURCE HEAD:** `7d79c02efa92597fb1e927f27b9c7715ef0a4fa8`.
- **REAL MODEL:** reached successfully with 120 s model timeout.
- **OBSERVED OUTPUT:** `schema_version,source_bindings`.
- **REQUIRED OUTPUT:** `schema_version,source_event_id,source_content_sha256,candidates`.
- **FAIL-CLOSED:** PASS.
- **CLEANUP:** `synthetic_residue=0`.
- **JSON SCHEMA CAPABILITY:** validated on the deployed llama.cpp runtime.
- **DECISION:** constrain generation; do not weaken validator.
- **PRODUCTION:** unchanged.
- **NEXT P1:** implement closed JSON Schema + repository-only regressions.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-JSON-SCHEMA-REPO-01 — 2026-09-28

- **STATUS:** `REPOSITORY_ONLY_PASS`.
- **BRANCH:** `feat/mimir-operational-foundation`.
- **TECHNICAL COMMIT:** `39b09e92b2355573105d3613ba84dab9267cf0a1`.
- **JSON SCHEMA GENERATION:** implemented.
- **PYTHON FAIL-CLOSED VALIDATOR:** retained.
- **JSON SCHEMA CONTRACT TEST:** PASS.
- **PROTECTED SUITE:** 10/10 PASS.
- **NETWORK ISOLATION:** PASS.
- **PRODUCTION:** unchanged.
- **DEPLOYED:** no.
- **REAL-MODEL INTEGRATED LAB:** pending.
- **NEXT P1:** integrated synthetic LAB with real Qwen on `127.0.0.1:18782`.
- **REQUIRED CLEANUP RESULT:** `synthetic_residue=0`.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-JSON-SCHEMA-01 — 2026-09-28

- **STATUS:** `FAIL`.
- **TECHNICAL COMMIT:** `39b09e92b2355573105d3613ba84dab9267cf0a1`.
- **REPOSITORY-ONLY:** PASS.
- **INTEGRATED REAL-MODEL LAB:** FAIL.
- **FAILURE:** `timeout ao acessar modelo local`.
- **MODEL TIMEOUT:** 120 s.
- **SCHEMA VALIDATION REACHED:** no.
- **SYNTHETIC CLEANUP:** `synthetic_residue=0`.
- **PRODUCTION:** unchanged.
- **NEXT P1:** Qwen runtime/latency diagnostics before any LAB retry.

### Real-model timeout diagnostic update

- **SMALL JSON SCHEMA PROBE:** PASS.
- **HTTP:** 200.
- **WALL TIME:** 4.392 s.
- **QWEN BASIC RUNTIME:** healthy.
- **JSON SCHEMA BASIC SUPPORT:** healthy.
- **CURRENT BLOCKER:** full integrated request exceeds 120 s.
- **NEXT P1:** full synthetic request size/latency profiling.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-LATENCY-01 — 2026-09-28

- **STATUS:** BLOCKED on timeout policy.
- **REAL MODEL CONTRACT:** PASS.
- **MODEL ELAPSED:** 136.530 s.
- **120 S BUDGET:** insufficient.
- **180 S DIAGNOSTIC RUN:** PASS.
- **OUTPUT CONTRACT:** PASS.
- **CANDIDATES:** 2.
- **AUTOMATIC PROMOTION:** 0.
- **CLEANUP:** `synthetic_residue=0`.
- **SCHEMA CHANGE REQUIRED:** no.
- **VALIDATOR CHANGE REQUIRED:** no.
- **DEPLOY:** not authorized.
- **NEXT P1:** scoped VPS CPU fallback timeout policy.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-TIMEOUT-POLICY-DESIGN-01

- **STATUS:** DESIGN_COMPLETE.
- **DEFAULT MODEL TIMEOUT:** 120 s.
- **MAX MODEL TIMEOUT:** 180 s.
- **VPS CPU FALLBACK LAB:** explicit 180 s required.
- **VERSIONED REAL-MODEL LAB HARNESS:** absent.
- **GLOBAL DEFAULT CHANGE:** no.
- **SCHEMA CHANGE:** no.
- **VALIDATOR CHANGE:** no.
- **PRODUCTION:** unchanged.
- **NEXT P1:** design/version integrated real-model LAB harness.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-LAB-STAGING-DESIGN-01

- **STATUS:** DESIGN_COMPLETE.
- **OPENCLAW DIRECT CHECKOUT ACCESS:** unavailable.
- **HOME PERMISSIONS CHANGE:** prohibited/unnecessary.
- **LAB EXECUTION MODEL:** root stages selected Git artifacts to private `/var/tmp`.
- **SOURCE OF TRUTH:** Git checkout.
- **VPS CPU FALLBACK TIMEOUT:** explicit 180 s in real-model LAB.
- **PRODUCTION:** unchanged.
- **NEXT P1:** inspect capture/writer dependencies before harness implementation.

## MIMIR-V1-PROTECTED-CONSOLIDATOR-REALMODEL-PASS-01

- **STATUS:** PASS / CLOSED.
- **IMPLEMENTATION:** `072397bd05a0f5e4a806fed4c403a7aab7a4abdb`.
- **REPOSITORY TESTS:** PASS.
- **REAL QWEN LAB:** PASS.
- **OUTPUT CONTRACT:** PASS.
- **CANDIDATES:** 2.
- **HUMAN REVIEW:** required.
- **AUTOMATIC PROMOTION:** 0.
- **SYNTHETIC RESIDUE:** 0.
- **LAB RC:** 0.
- **NEXT:** advance to next incomplete Mímir v1 functional milestone.

## MIMIR-V1-P1-MEMORY-DEDUP-CONTRADICTION-01

- **STATUS:** PASS / CLOSED.
- **CONTROLLED SESSION WRITER:** PASS.
- **PROTECTED LOCAL CONSOLIDATION:** PASS.
- **DEDUPLICATION:** PASS.
- **CONTRADICTION DETECTION:** PASS.
- **DEDUP REPLAY:** same source/key/content returns the existing memory.
- **CONTRADICTION CONTRACT:** `none | duplicate | contradiction`.
- **CONTRADICTION DETECTOR WRITES:** 0.
- **AUTOMATIC PROMOTION:** 0.
- **LAB SCHEMA:** `1..12,14,15`.
- **PRODUCTION SCHEMA:** `1..12`.
- **PRODUCTION MIGRATION 015:** absent.
- **SYNTHETIC RESIDUE:** 0.
- **NEXT:** authenticated human review and `candidate -> active`.

## MIMIR-V1-P1-HUMAN-REVIEW-ACTIVE-01

- **STATUS:** PASS / CLOSED.
- **AUTHENTICATED HUMAN REVIEW:** PASS.
- **PEER IDENTITY:** `peer:nogueiramaier`.
- **LOGIN ROLE:** `mimir_human`.
- **CONTROLLED ELEVATION:** `mimir_reviewer`.
- **UNAUTHORIZED REVIEW:** rejected.
- **CANDIDATE -> ACTIVE:** PASS.
- **HUMAN REJECT:** PASS.
- **REVIEW IDEMPOTENCY:** PASS.
- **ACTIVE-KEY CONFLICT:** rejected.
- **REVIEWER PROVENANCE:** PASS.
- **REVIEW AUDIT:** PASS.
- **AUTOMATIC RELATIONS:** 0.
- **LAB PG_IDENT RESTORED:** PASS.
- **SYNTHETIC RESIDUE:** 0.
- **PRODUCTION:** unchanged at memory schema `1..12`.
- **NEXT:** embedding generation + semantic recovery after human promotion.

## MIMIR-V1-P1-EMBEDDING-SEMANTIC-AUDIT-01

- **STATUS:** PASS / CLOSED.
- **ACTIVE-ONLY EMBEDDING ELIGIBILITY:** PASS.
- **OPENCLAW MANAGED LLAMA-SERVER:** PASS.
- **EMBEDDINGGEMMA:** real 768D vector validated.
- **CONTROLLED `mimir_embedder` WRITE:** PASS.
- **CONTENT SHA GUARD:** PASS.
- **EMBEDDING NORMALIZATION:** PASS.
- **EMBEDDING AUDIT:** PASS.
- **QUERY EMBEDDING 768D:** PASS.
- **`mimir_search` / `peer:openclaw`:** PASS.
- **PROMOTED MEMORY RETRIEVAL:** PASS.
- **REJECTED MEMORY EXCLUSION:** PASS.
- **CANDIDATE MEMORY EXCLUSION:** PASS.
- **SOURCE PROVENANCE:** PASS.
- **END-TO-END PROVENANCE/AUDIT:** PASS.
- **PRODUCTION:** unchanged at schema `1..12`.
- **PRODUCTION MIGRATION 015:** absent.
- **LAB PG_IDENT RESTORED:** PASS.
- **SYNTHETIC RESIDUE:** 0.
- **NEXT:** integrate `memory_handoff` with the authenticated human memory flow.

## MIMIR-V1-P1-MEMORY-HANDOFF-01

- **STATUS:** PASS / CLOSED.
- **P1 PERMANENT POSTGRESQL MEMORY:** 9/9 COMPLETE.
- **OPERATIONAL HANDOFF PRODUCER:** PASS.
- **CONFIDENTIAL EVENT INGESTION:** PASS.
- **CANDIDATE-FIRST SEMANTICS:** PASS.
- **MALFORMED HANDOFF FAIL-CLOSED:** PASS.
- **IDEMPOTENT REPLAY / DEDUP:** PASS.
- **CONTRADICTION INSPECTION:** PASS.
- **DIRECT `mimir_app` READ OF `memory_records`:** absent.
- **SEMANTIC VISIBILITY BEFORE REVIEW:** blocked.
- **AUTHENTICATED HUMAN REVIEW:** PASS.
- **CANDIDATE -> ACTIVE:** PASS.
- **EMBEDDING ONLY AFTER HUMAN PROMOTION:** PASS.
- **SEMANTIC RECOVERY AFTER REVIEW:** PASS.
- **END-TO-END PROVENANCE/AUDIT:** PASS.
- **AUTOMATIC RELATIONS:** 0.
- **AUTOMATIC PROMOTION:** false.
- **LAB MEMORY SCHEMA:** `1..12,14,15,16`.
- **PRODUCTION MEMORY SCHEMA:** `1..12`.
- **PRODUCTION MIGRATIONS 014/015/016:** absent.
- **LAB PG_IDENT RESTORED:** PASS.
- **SYNTHETIC RESIDUE:** 0.
- **FINAL LAB RC:** 0.
- **NEXT:** demonstrate real backup/restore behavior by adapter in an isolated LAB.

## MIMIR-V1-P1-OPS-BACKUP-RESTORE-01

- **STATUS:** PASS / CLOSED.
- **ADAPTER:** `generic-linux`.
- **BACKUP SCOPE:** runtime hostname only.
- **REAL BACKUP CAPTURE:** PASS.
- **REAL TRANSIENT CHANGE:** PASS.
- **POST-CHANGE VALIDATION:** PASS.
- **REAL RESTORE:** PASS.
- **RESTORE VALIDATION:** PASS.
- **INVALID RESTORE VALUE:** blocked.
- **UTS NAMESPACE ISOLATION:** PASS.
- **REAL VPS HOSTNAME UNCHANGED:** PASS.
- **MIKROTIK BACKUP:** unsupported by policy.
- **MIKROTIK `backup-save`:** blocked.
- **SSH USED:** false.
- **PRODUCTION DB TOUCHED:** false.
- **EXTERNAL EQUIPMENT TOUCHED:** false.
- **AUTOMATIC ROLLBACK ADDED:** false.
- **OPS REGRESSION:** 55/55 PASS.
- **FINAL LAB RC:** 0.
- **NEXT:** homologate first laboratory equipment in READ mode.
