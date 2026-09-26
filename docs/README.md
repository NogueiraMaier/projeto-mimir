# Documentação do Projeto Mimir

## Objetivo

O Mimir é o agente central de inteligência do Projeto Jarvis.

O projeto integra OpenClaw, modelos de linguagem, memória operacional local e memória permanente controlada.

## Ambiente

- Gentoo Linux com OpenRC
- OpenClaw instalado em /opt/openclaw
- Serviço executado pelo usuário openclaw
- Workspace em /var/lib/openclaw/workspace
- PostgreSQL 17
- pgvector
- Embeddings locais com 768 dimensões

## Documentos

- ARCHITECTURE.md: arquitetura e fluxo de memória
- SECURITY.md: controles e limites de segurança
- STATUS.md: estado técnico confirmado
- RUNBOOK.md: procedimentos operacionais
- ROADMAP.md: etapas planejadas

## Regra principal

A memória permanente usa PostgreSQL como fonte de verdade.

A promoção para active exige revisão e aprovação humana.


## Ordem canônica de leitura para continuidade

Esta seção complementa a lista de documentos acima e não altera o papel dos arquivos existentes.

Uma nova sessão de ChatGPT, Codex, Claude Code ou outro agente que precise retomar o projeto deve começar por:

1. `MIMIR_HANDOFF.md` — estado operacional e próxima ação autorizada;
2. `MIMIR_V1_EXECUTION_PLAN.md` — lista mestre de conclusão da v1;
3. `STATUS.md` — estado técnico consolidado;
4. `ARCHITECTURE.md` — arquitetura corrente e distinção CURRENT/TARGET;
5. `ROADMAP.md` — evolução macro.

Depois, consultar o documento especializado conforme o assunto.

### Migração do Gateway / PcIA

- `GATEWAY_PCIA_MIGRATION_PLAN.md`

### Modelos, providers e inferência

- `MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`

### Memória futura

- `MEMORY_V2_ROADMAP.md` na branch documental correspondente.

### Agentes especialistas / MCP / A2A

- `AGENT_SPECIALIZATION_MCP_A2A_ROADMAP.md` na branch documental correspondente.

## Regra para documentos em branches diferentes

A documentação futura pode existir em branch diferente da linha operacional corrente.

No estado registrado em 2026-09-25:

```text
feat/mimir-operational-foundation
  -> trabalho operacional/v1 corrente

docs/mimir-gateway-model-routing
  -> planejamento da migração Gateway/PcIA
  -> model routing e inferência

docs/mimir-memory-v2-roadmap
  -> evolução futura da memória
  -> documentação relacionada a agentes/MCP/A2A
```

A ausência de um documento na branch corrente não significa automaticamente que ele foi apagado, abandonado ou substituído.

Antes de concluir que documentação está faltando:

1. conferir a branch atual;
2. consultar o handoff;
3. verificar a branch documental indicada;
4. comparar com Git;
5. não reconstruir estado apenas por memória de conversa.

## Regra de estado

Roadmap e arquitetura alvo não representam implementação.

Usar explicitamente:

- **CURRENT** — comprovado por runtime/checkpoint/evidência;
- **TARGET** — planejado e documentado;
- **WATCHLIST** — candidato dependente de benchmark/evidência.

Nunca promover TARGET ou WATCHLIST para CURRENT sem validação documentada.


### Segurança, risco e assurance

- `SECURITY_GOVERNANCE_AND_ASSURANCE_ROADMAP.md` — evolução futura de governança de segurança, Risk Engine, Zero Trust contextual, superfície de ataque, control assurance, auditoria, vulnerabilidades, ATT&CK, resposta e recuperação.

Status: **TARGET / NÃO IMPLEMENTADO**.

A discussão de acesso/análise de desktop ou endpoint não está incluída nesse roadmap e deverá ser tratada separadamente antes de ser documentada como arquitetura.
