# Arquitetura do Projeto Mimir

## Agente central

O agente main possui a identidade Mimir.

Ele coordena tarefas, consulta memória e direciona agentes especializados.

## Agentes especializados

O repositório documenta especializações futuras para SOC, OSINT, Cyber-Lab, redes, operações, desenvolvimento, negócios e auditoria de memória/segurança. A documentação não deve inferir implantação somente pela ausência de evidência.

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

As sessões concluídas são armazenadas em mimir.session_sources.

A tabela contém a transcrição original e não permite acesso direto para mimir_app.

A função mimir.ingest_session executa a escrita com identidade peer validada.

memory_events recebe somente o evento de proveniência e os metadados estruturais.

A classificação inicial é confidential.

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


## Arquitetura atual versus arquitetura alvo

Esta seção foi acrescentada para evitar que documentação futura seja interpretada como estado já implantado.

Nada nesta seção substitui o conteúdo anterior deste arquivo.

### CURRENT — arquitetura efetivamente validada/documentada

O estado CURRENT deve ser inferido somente a partir de:

- `MIMIR_HANDOFF.md`;
- `MIMIR_V1_EXECUTION_PLAN.md`;
- `STATUS.md`;
- evidências de revisão e validação;
- runtime efetivamente inspecionado.

Componentes futuros não devem ser promovidos para CURRENT apenas porque aparecem em roadmap ou diagrama.

### TARGET — arquitetura futura planejada

A direção arquitetural planejada é:

```text
CANAIS
Telegram / HUD / outros
        |
        v
      MÍMIR
identidade / policy / memória
planejamento / auditoria
        |
        v
 Capability Router
        |
        v
   Policy Engine
        |
        v
   Engine Registry
   /      |       \
  v       v        v
local   provider   coding harness
engine  autorizado Codex/Claude/etc.
  |        |         |
  +--------+---------+
           |
 ferramentas / evidências
           |
 PostgreSQL / pgvector / CMDB
```

Esse desenho representa responsabilidades conceituais, não implantação confirmada.

### Separação de responsabilidades

O Mímir continua sendo o núcleo de:

- identidade;
- contexto;
- memória;
- policy;
- planejamento;
- auditoria;
- coordenação de agentes e ferramentas.

O Capability Router decide **qual capacidade** é necessária.

O Policy Engine decide **quais opções são permitidas**.

O Engine Registry descreve **quais engines/providers/harnesses estão disponíveis e elegíveis**.

Modelos/providers/harnesses continuam substituíveis.

Ferramentas e evidências pertencem ao plano de orquestração do Mímir e não a uma única engine.

Portanto, a arquitetura não deve ser interpretada como:

`Qwen -> ferramentas -> memória`

mas como:

`Mímir -> evidências/ferramentas + seleção de capacidade -> engine autorizada`

### Documentos de evolução relacionados

- [GATEWAY_PCIA_MIGRATION_PLAN.md](GATEWAY_PCIA_MIGRATION_PLAN.md)
- [MODEL_ROUTING_AND_INFERENCE_ROADMAP.md](MODEL_ROUTING_AND_INFERENCE_ROADMAP.md)
- [review/architecture/2026-09-25-gateway-model-routing.md](review/architecture/2026-09-25-gateway-model-routing.md)

A Memory v2 permanece em linha documental própria e não é substituída por esta arquitetura.

### Regra de transição

A existência da arquitetura TARGET não autoriza implementação.

A sequência documentada permanece:

```text
estado atual validado
        ->
concluir checkpoint operacional corrente
        ->
migração física quando autorizada
        ->
validação e novo baseline
        ->
evolução de model routing
```

Não misturar mudança de host, mudança de modelo, mudança de provider, mudança de tool policy e mudança de governança de memória na mesma etapa sem decisão explícita.
