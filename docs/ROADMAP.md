# Roadmap

## Próxima etapa

Criar o cliente de ingestão protegida e o consolidador local de sessões, sem promoção automática e sem API externa.

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
