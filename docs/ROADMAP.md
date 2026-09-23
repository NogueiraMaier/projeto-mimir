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
2. Validar 009, grants/peer e constraints em banco descartável com o schema real de memória preservado.
3. Demonstrar backup/restauração e provisionar a identidade operacional dedicada.
4. Autorizar um equipamento de laboratório em READ, conferindo host key independentemente.
5. Homologar a operação de hostname transitório e recuperação manual antes de ampliar EXECUTE.
6. Completar o consumidor de `memory_handoff` com revisão humana e proveniência; integração atual PARCIAL.
7. Planejar backups completos, reconciliação assistida, topologia automática e novos adapters.

Esses marcos não encerram os riscos históricos PRIO-P0 nem alteram as decisões
documentais de governança. A autorização desta etapa foi restrita ao desenvolvimento local.
