# Revisão arquitetural — Gateway no PcIA e model routing

Data: 2026-09-25  
Status: **DOCUMENTAÇÃO / SEM ALTERAÇÃO DE RUNTIME**

## Objetivo

Registrar as observações levantadas antes de qualquer decisão de execução sobre:

- migração do OpenClaw Gateway da VPS para o PcIA;
- proximidade do Gateway com a GPU local;
- papel do Telegram e HUD;
- separação entre Qwen, NVIDIA e futuros engines/providers;
- tool-calling;
- disponibilidade;
- relação com Memory v2.

## Estado documental encontrado

A revisão identificou que:

1. `MIMIR_V1_EXECUTION_PLAN.md` está na linha de trabalho da fundação operacional e permanece a lista mestre da v1;
2. `MEMORY_V2_ROADMAP.md` é mantido em branch própria;
3. o roadmap de agentes/MCP/A2A também está associado à evolução documental futura;
4. não existia documento específico para model routing;
5. não existia plano específico para migração Gateway VPS -> PcIA;
6. `TELEGRAM_INTEGRATION.md` preservava estado histórico anterior à validação registrada posteriormente em STATUS/plano mestre.

Nenhum desses registros deve ser apagado para “corrigir” história. A estratégia adotada foi acrescentar estado novo e referências.

## Documentos criados

- `docs/GATEWAY_PCIA_MIGRATION_PLAN.md`;
- `docs/MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`.

## Observação 1 — mudança de papel dos hosts

A migração proposta não é somente mudança de endereço.

Ela altera a responsabilidade arquitetural:

```text
antes:
VPS  -> plano de controle/Gateway
PcIA -> worker de inferência GPU

alvo:
PcIA -> Primary Mímir Node / plano de controle
VPS  -> persistência e infraestrutura auxiliar
```

Esse trade-off precisa ser aceito porque o PcIA passa a afetar diretamente a disponibilidade do Mímir.

## Observação 2 — latência versus disponibilidade

Mover o Gateway para junto da inferência local remove a VPN do caminho crítico de muitas interações.

Por outro lado, falha/desligamento do PcIA poderá indisponibilizar:

- Gateway;
- Telegram;
- HUD;
- agente main;
- inferência local.

O ganho de latência não elimina a necessidade de estratégia de rollback.

## Observação 3 — memória permanece separada

A migração não move PostgreSQL/pgvector.

A VPS continua sendo fonte de persistência.

Falha de VPN/VPS deve degradar memória de forma explícita e nunca autorizar invenção de fatos.

## Observação 4 — HUD não é modelo

O HUD permanece interface do Mímir.

Não deve ser acoplado diretamente a:

- Qwen;
- NVIDIA;
- Codex;
- qualquer outro modelo/provider.

A seleção de engine é responsabilidade futura da camada de roteamento.

## Observação 5 — routing não é fallback

Separar:

- **routing por capacidade**: escolhe a engine apropriada à tarefa;
- **fallback por falha**: escolhe alternativa compatível quando a engine escolhida falha.

Uma lista linear fixa de modelos não representa a arquitetura final desejada.

## Observação 6 — tool-calling é problema independente

A localização do Gateway não resolve automaticamente tool-calling.

Casos como `session_status` e `mimir_memory_search` precisam ser validados considerando:

- policy/profile;
- tool inventory;
- tool schema;
- compatibilidade do runtime;
- modelo;
- chat template;
- comportamento da API.

A migração deve repetir testes de tools antes e depois do cutover.

## Observação 7 — não misturar duas grandes mudanças

Não executar simultaneamente:

```text
migração do Gateway
+
Capability Router / Engine Registry
+
mudança de política Qwen/NVIDIA
```

Sequência recomendada:

```text
baseline atual
   ->
migração física
   ->
validação
   ->
novo baseline
   ->
model routing
```

## Observação 8 — nomenclatura do host

Existe divergência documental entre `gentoo-Dragon_IA` e `gentoo-Dragon_PcIA`.

Nenhuma correção foi feita por inferência.

O plano exige confirmação do hostname canônico no preflight.

## Observação 9 — publicação e segurança

Os documentos descrevem arquitetura e critérios, não segredos.

Continuam proibidos no Git:

- tokens;
- chaves privadas;
- senhas;
- dumps confidenciais;
- configuração sensível do HUD;
- credenciais de provider.

## Observação 10 — Memory v2

A ideia de GraphRAG não justifica substituir PostgreSQL/pgvector ou introduzir Neo4j/GNN agora.

Memory v2 já prevê:

- entidades e relações;
- temporalidade;
- retrieval híbrido;
- multi-hop;
- explainability;
- benchmark.

A evolução adicional recomendada é primeiro multi-hop determinístico e limitado; GNN/GAT permanece watchlist condicionada a benchmark.

## Resultado

A documentação foi ampliada sem apagar histórico.

A branch documental não autoriza:

- cutover;
- mudança de provider;
- mudança de modelo;
- aplicação de migration em produção;
- ampliação de EXECUTE;
- alteração de credenciais.

Qualquer execução futura deve começar pelo preflight do plano de migração e por autorização específica.
