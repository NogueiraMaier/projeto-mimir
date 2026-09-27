# Arquitetura do Projeto Mimir

## Agente central

O agente main possui a identidade Mimir.

Ele coordena tarefas, consulta memória e direciona agentes especializados.

## Agentes especializados

O repositório documenta especializações futuras para SOC, OSINT, Cyber-Lab, redes, operações, desenvolvimento, negócios e auditoria de memória/segurança. A documentação não deve inferir implantação somente pela ausência de evidência.

## Camada de segurança conversacional — proposta

A arquitetura-alvo de segurança de entradas, canais, memória, ferramentas e
roteamento de modelos está definida em
[CONVERSATIONAL_SECURITY.md](CONVERSATIONAL_SECURITY.md).

Invariante central: **todo conteúdo externo é dado não confiável**. Autoridade
não é derivada do texto recebido, do canal, da voz ou do comportamento do
modelo.

A camada deverá impor fora do LLM, entre outros controles:

- identidade e scope separados do conteúdo;
- capabilities explícitas por agente/subagente;
- policy gate antes de tool execution;
- validação de parâmetros;
- separação planner/executor para ações sensíveis;
- proteção contra memory poisoning;
- minimização de contexto;
- controle de exposição da saída;
- roteamento de modelos sem ampliação de privilégio;
- auditoria e anti-replay;
- política específica por canal.

Status atual: **PROPOSTA / NÃO IMPLEMENTADO COMO CAMADA COMPLETA**. Os controles
existentes de least privilege, ingestão protegida, revisão humana e execução
operacional separada são compatíveis com a proposta, mas não devem ser usados
como evidência de implementação integral.

A matriz de validação planejada está em
[AI_SECURITY_TEST_MATRIX.md](AI_SECURITY_TEST_MATRIX.md).

## Memória operacional

O memory-core nativo do OpenClaw mantém contexto operacional de curto prazo.

Características do snapshot documentado em 2026-07-30, não revalidadas nesta revisão local:

- Backend builtin
- Banco SQLite local
- Busca híbrida
- FTS habilitado
- Embeddings locais
- Vetores com 768 dimensões

O SQLite não representa a fonte definitiva da memória permanente.

## Memória permanente

O PostgreSQL representa a fonte de verdade.

Componentes:

- Banco mimir_memory
- PostgreSQL 17
- Extensão pgvector
- Evidências e proveniência
- Controle de estado
- Escopo por agente, projeto e cliente
- Registro de eventos
- Auditoria
- Aprovação humana

## Camada operacional

IMPLEMENTADO no repositório, NÃO VALIDADO EM PRODUÇÃO. A camada em `tools/ops`
estende a fundação operacional e permanece separada do plugin e das funções de
memória. A migration de schema 013 modela CMDB e intervenções; o provisionamento
da role dedicada `mimir_ops` fica em script separado.
acessa somente uma API SQL controlada com autenticação peer e identidade
inicialmente desabilitada. `mimir_app` não recebe acesso direto às tabelas ops.

O CLI mantém entradas JSON para plano/diagnóstico legado e adiciona inventário,
histórico e relatórios PostgreSQL. Catálogos por adapter restringem READ, PLAN e
EXECUTE; alteração exige plano aprovado, preparação, auditoria e validação.
Somente `set-hostname` transitório no adapter Linux está implementado para
alteração. MikroTik permanece em diagnóstico. Rollback é manual.

A finalização associa estado encontrado, ações, validação, observação atualizada
do inventário, histórico e relatório. Intervenções técnicas `validated` não são
promovidas à memória automaticamente: `memory_handoff` v1 é interface PARCIAL,
confidential, para revisão humana, duplicidade, contradições e preservação de
versões. `closed` permanece false. Nenhuma ferramenta de shell foi adicionada
ao agente main. Detalhes e limites: [OPERATIONS.md](OPERATIONS.md).

## Ingestão protegida de sessões

O OpenClaw 2026.9.5 usa SQLite canônico por agente, mas o Mímir não lê o schema
privado diretamente. O read-path validado usa `sessions --json` +
`chat.history` e aplica owner-only fail-closed.

As sessões elegíveis continuam destinadas a `mimir.session_sources`, sem
SELECT direto para `mimir_app`. `memory_events` recebe somente proveniência e
metadados estruturais; a classificação inicial permanece `confidential`.

O contrato legado `mimir.ingest_session` representa fonte JSONL e não é
adequado às sessões canônicas atuais. A migration proposta
`014_api_session_ingestion_v2.sql` cria `mimir.ingest_session_v2`, registra
proveniência `openclaw-chat-history-v2` e revoga de `mimir_app` o EXECUTE no
ingresso legado. A 014 ainda não foi aplicada em produção.

Detalhes: [SESSION_INGESTION_V2.md](SESSION_INGESTION_V2.md).

## Consulta semântica

O plugin mimir-memory registra a ferramenta mimir_memory_search.

A ferramenta executa o cliente controlado:

tools/memory/mimir-semantic-search.mjs

O acesso ao banco ocorre pela role mimir_search.

A autenticação local usa peer para o usuário openclaw.

A role não possui SELECT direto nas tabelas.

A consulta ocorre por função controlada do banco.

## Fluxo da memória

1. Captura da sessão.
2. Registro diário.
3. Extração de fatos, decisões e restrições.
4. Consolidação em dry run.
5. Detecção de duplicidades.
6. Detecção de contradições.
7. Geração de arquivo reviewed.
8. Cálculo do SHA-256.
9. Revisão humana.
10. Inclusão como candidate.
11. Aprovação humana.
12. Promoção para active.
13. Geração local do embedding.
14. Teste de recuperação semântica.
15. Auditoria.
