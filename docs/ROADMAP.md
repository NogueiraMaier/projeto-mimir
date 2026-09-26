# Roadmap

## Próxima etapa

Completar a escrita do cliente de ingestão protegida, atualmente restrito a dry-run, e o fluxo local de consolidação de sessões, sem promoção automática e sem API externa.

## Pipeline planejado

1. Capturar novas sessões em registro diário.
2. Extrair fatos, decisões e restrições.
3. Executar consolidação em dry run.
4. Consultar memórias active.
5. Detectar duplicidades.
6. Detectar contradições.
7. Gerar arquivo reviewed com identificador único.
8. Calcular SHA-256.
9. Exigir revisão humana.
10. Enviar registros aprovados como candidate.
11. Aprovar com a role humana.
12. Promover para active.
13. Gerar embedding local.
14. Testar recuperação semântica.
15. Conferir eventos e auditoria.

## Etapas posteriores

- Agente auditor de memória
- Controle de proveniência
- Política de expiração e substituição
- Backup e restauração testados
- Agente desenvolvedor isolado
- Observabilidade com Grafana e Zabbix
- Navegador e OSINT isolados
- SOC e SIEM
- Cyber-Lab em máquina separada

## Fundação operacional — situação em 2026-09-22

IMPLEMENTADO localmente: CMDB/CLI/API PostgreSQL, política por operação, executor
SSH, fluxo de intervenção, relatórios e testes sintéticos. NÃO VALIDADO EM
PRODUÇÃO. Escopo detalhado em [OPERATIONS.md](OPERATIONS.md).

Próximos marcos, cada um com autorização própria:

1. Executar o validador somente leitura no VPS; resolver divergências sem aplicar mudanças automaticamente.
2. Validar 013, grants/peer e constraints em banco descartável com o schema real de memória preservado.
3. Demonstrar backup/restauração e provisionar a identidade operacional dedicada.
4. Autorizar um equipamento de laboratório em READ, conferindo host key independentemente.
5. Homologar a operação de hostname transitório e recuperação manual antes de ampliar EXECUTE.
6. Completar o consumidor de `memory_handoff` com revisão humana e proveniência; integração atual PARCIAL.
7. Planejar backups completos, reconciliação assistida, topologia automática e novos adapters.

Esses marcos não encerram os riscos históricos PRIO-P0 nem alteram as decisões
documentais de governança. A autorização desta etapa foi restrita ao desenvolvimento local.


## Controle mestre da conclusão v1 — 2026-09-24

A sequência canônica de trabalho passou a ser mantida em
[MIMIR_V1_EXECUTION_PLAN.md](MIMIR_V1_EXECUTION_PLAN.md).

Checkpoint atual: `MIMIR-V1-013-LAB-09` e
`MIMIR-V1-OPS-RETENTION-01` concluídos. A migration 013 foi validada em
laboratório isolado com grants/peer, READ, EXECUTE sintético, hardening temporal,
backup/restore e reconciliação fail-closed de execução interrompida. A política
v1 de retenção operacional também foi versionada.

Produção permanece em versões 1–12 e sem `mimir_ops`. Nenhum equipamento real
foi usado nos LABs EXECUTE.

Próxima etapa: fechar as lacunas P0 remanescentes, começando pela ausência
histórica da migration 001 ou por um bootstrap canônico equivalente sustentado
por evidência. Depois corrigir metadata drift do plugin e definir
`plugins.allow` explicitamente. A documentação do Maestro deve ser retomada
depois da estabilização dos marcos P0/P1 do Mímir.


## Evolução arquitetural documentada — pós-v1

Foram adicionados documentos específicos para separar duas evoluções que não devem ser misturadas com o fechamento da v1.

### Migração do plano de controle para o PcIA

Documento:

- [GATEWAY_PCIA_MIGRATION_PLAN.md](GATEWAY_PCIA_MIGRATION_PLAN.md)

Escopo:

- estudar e preparar a migração do OpenClaw Gateway, agente `main`, Telegram e integração do HUD para o nó local com GPU;
- manter PostgreSQL/pgvector e infraestrutura auxiliar na VPS;
- exigir preflight, backup, rollback e cutover controlado;
- não executar dois consumidores Telegram em polling simultâneo;
- tratar disponibilidade do PcIA como novo risco arquitetural;
- validar novamente tools e memória após a migração.

A migração está **PLANEJADA**. Este registro não autoriza alteração de produção.

### Capability Routing, Model Routing e inferência

Documento:

- [MODEL_ROUTING_AND_INFERENCE_ROADMAP.md](MODEL_ROUTING_AND_INFERENCE_ROADMAP.md)

Escopo:

- desacoplar Mímir de modelo específico;
- introduzir futuramente Capability Router, Engine Registry e policy-aware routing;
- distinguir engine, provider, harness, agente, memória e ferramenta;
- permitir avaliação controlada de Qwen local, providers autorizados, NVIDIA, Codex, Claude Code, OpenCode e outras engines futuras;
- separar routing por capacidade de fallback por falha;
- exigir benchmark e auditoria antes de seleção automática.

Regra de ordem:

**não introduzir a nova lógica de model routing durante a migração física do Gateway.**

Primeiro preservar o comportamento e validar a nova topologia. Depois capturar baseline e evoluir o roteamento.

### Relação com Memory v2 e agentes especialistas

A evolução da memória continua em branch/documento próprio e não é substituída por este trabalho.

O model routing consome contexto e evidência fornecidos pela memória, mas não redefine sua governança.

Agentes especialistas continuam sendo separados de engines: um agente de Redes, SOC ou Desenvolvimento poderá usar capacidades diferentes conforme a tarefa, desde que a política autorize.


## Segurança, governança de risco e control assurance — evolução futura

Documento:

- [SECURITY_GOVERNANCE_AND_ASSURANCE_ROADMAP.md](SECURITY_GOVERNANCE_AND_ASSURANCE_ROADMAP.md)

Status: **PLANEJADO / PÓS-v1 / NÃO IMPLEMENTADO**.

A trilha registra evolução futura para:

- inventário de ativos de IA e fluxos de dados;
- autorização contextual baseada em princípios Zero Trust;
- Risk Engine;
- superfície de ataque e drift entre estado esperado/observado;
- assurance de controles por evidência;
- auditoria correlacionável;
- vulnerability management com validação pós-correção;
- detection engineering orientado por MITRE ATT&CK;
- workflow de resposta a incidentes;
- RPO/RTO e validação de recuperação;
- mapeamento de cobertura pelo NIST CSF 2.0;
- avaliação de maturidade e melhoria contínua.

Essa trilha não altera o fechamento da v1 e não autoriza mudança de runtime.

A capacidade de acesso/análise de desktop ou endpoint permanece explicitamente fora deste escopo até discussão arquitetural específica.


## Fila futura — Mímir Field Assessment / SOC-OSINT

Queue ID:

`MIMIR-FIELD-ASSESSMENT-01`

Documento:

- [FIELD_ASSESSMENT_SOC_OSINT_ROADMAP.md](FIELD_ASSESSMENT_SOC_OSINT_ROADMAP.md)

Status:

**FILA / PLANEJADO / NÃO IMPLEMENTADO**

Objetivo futuro:

- Field Probe em pendrive;
- túnel WireGuard efêmero;
- abertura do HUD;
- inventário e baseline automáticos;
- saúde de hardware;
- diagnóstico Windows;
- análise de Event Logs;
- diagnóstico de rede/TCP;
- portas efêmeras, TIME_WAIT, Auto-Tuning, congestion control, Nagle/ACK, MTU, retransmissões, RSS/RSC/offloads e DNS;
- OSINT externo autorizado;
- fluxo SOC e correlação;
- Risk Engine;
- NIST CSF 2.0 Current/Target Profile;
- checklist de enquadramento baseado em evidência;
- registro estruturado no sistema;
- relatórios HTML/PDF;
- catálogo futuro de remediação autorizada.

O catálogo futuro poderá conter operações controladas como instalação, patch, quarentena/exclusão, disable de serviço, kill de processo e mudança de firewall, sempre sob policy, approval, backup/rollback e validação conforme risco.

**Nota de fila:** quando este projeto for retomado, começar por `FA-0 — especificação`, e não pelo código do pendrive.

Esta fila não altera o `NEXT_ACTION` corrente e não autoriza execução em equipamento real.
