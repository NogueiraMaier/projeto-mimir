# Roadmap

## Próxima etapa

A seção P1 de memória permanente está concluída em laboratório: escrita
controlada, consolidação protegida, deduplicação, contradição, revisão humana,
`candidate -> active`, embedding local, recuperação semântica,
auditoria/proveniência e integração operacional de `memory_handoff` foram
validadas sem promoção automática.

A camada operacional também validou backup/restauração real no escopo do
adapter `generic-linux`: o hostname anterior foi capturado, alterado e restaurado
dentro de UTS namespace isolado, sem alterar o host real. O adapter MikroTik
permanece explicitamente sem backup no MVP.

O primeiro equipamento real foi homologado exclusivamente em READ pelo
`SSHExecutor` e pelo catálogo `mikrotik-routeros`. As seis operações
diagnósticas passaram, EXECUTE permaneceu bloqueado e nenhuma configuração foi
alterada. A host key inicialmente pinada por TOFU foi posteriormente conferida
por segundo canal administrativo através da chave pública exportada pelo
RouterOS.

O `set-hostname` transitório do adapter `generic-linux` foi homologado em
laboratório UTS isolado com `SSHExecutor` real. A alteração controlada,
validação, restauração manual e teardown final passaram sem alterar o hostname
real da VPS.

O escopo operacional da v1 fica congelado em `generic-linux` EXECUTE restrito
e MikroTik em READ. MikroTik EXECUTE, FiberHome, H3C, Intelbras e novos adapters
multi-vendor passam para pós-v1.

A workstream P1 — Reprodutibilidade e release já possui CI repository-only
validado em push e pull request no GitHub Actions. O workflow cobre testes
Python de memória/operações/validador, sintaxe Shell/Node e teste/build do
plugin sem declarar validação de produção.

A suíte completa foi executada com PASS em checkout novo criado diretamente
da branch remota no HEAD `fd8e6d9a7a7dd9e9d5a8be7fb6d7ad289fc88644`.

A restauração do baseline de memória v1 `1..12` foi validada por dois
caminhos independentes: custom-format dump PostgreSQL e reconstrução pelo Git
com bootstrap canônico + migrations 002..012. Estrutura, owners, ACLs, roles,
memberships e configurações por banco foram equivalentes. Produção permaneceu
inalterada.

A próxima etapa é criar o checklist final de segurança da v1.

## Gate de segurança conversacional

Antes de ampliar canais externos, ferramentas administrativas, subagentes ou
roteamento dinâmico de modelos, executar a workstream definida em
[CONVERSATIONAL_SECURITY.md](CONVERSATIONAL_SECURITY.md).

O consolidator local de sessões também deve obedecer esse gate desde o início:
conteúdo da sessão continua não confiável, não altera autorização e não pode
promover memória automaticamente.

A validação adversarial canônica será
[AI_SECURITY_TEST_MATRIX.md](AI_SECURITY_TEST_MATRIX.md), T-AI-001..035.

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

Estado P1 validado em 2026-09-29:

- captura/escrita controlada de sessões: concluída;
- consolidação local protegida: concluída;
- deduplicação: concluída;
- detecção determinística de contradições: concluída;
- revisão humana autenticada: concluída;
- fluxo `candidate -> active`: concluído;
- embedding local controlado após promoção: concluído;
- recuperação semântica da memória promovida: concluída;
- auditoria/proveniência ponta a ponta: concluída;
- `memory_handoff` operacional -> candidate -> revisão humana -> active: concluído em LAB;
- embedding e visibilidade semântica somente após promoção humana: confirmado;
- seção P1 — Memória permanente PostgreSQL: 9/9 concluída;
- backup/restauração real do escopo suportado pelo adapter `generic-linux`: concluído em LAB UTS;
- MikroTik backup: explicitamente não suportado/bloqueado no MVP;
- primeiro equipamento real em READ: concluído;
- adapter `mikrotik-routeros` real: 6/6 operações READ concluídas;
- host key: pinada e verificada por segundo canal administrativo;
- MikroTik EXECUTE/configuração: não autorizado e não realizado;
- `generic-linux` `set-hostname` transitório: concluído em LAB UTS;
- escopo operacional da v1: congelado;
- expansão multi-vendor e MikroTik EXECUTE: pós-v1;
- próxima etapa: P1 — Reprodutibilidade e release.

## Etapas posteriores

- Agente auditor de memória
- Controle de proveniência
- Política de expiração e substituição
- Backup completo de produção e recuperação com dados reais
- Agente desenvolvedor isolado
- Observabilidade com Grafana e Zabbix
- Navegador e OSINT isolados
- SOC e SIEM
- Cyber-Lab em máquina separada
- Mímir Security Assessment & SOC Coordinator, com OSINT autorizado, vulnerability assessment, correlação SOC, findings rastreáveis, perfis SAFE de scan e reteste. Especificação: `docs/cybersecurity/MIMIR_SECURITY_ASSESSMENT_SOC.md`

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

## Gate final de segurança v1 — 2026-09-30

O checklist final de segurança foi criado e revisado.

Resultado:

`REVIEWED / BLOCKED_FOR_RELEASE`

A revisão técnica do PR pode continuar mantendo Draft. Remoção de Draft,
merge, tag estável e deployment permanecem bloqueados enquanto os blockers
documentados na reconciliação final estiverem abertos.

Próxima etapa:

revisar PR #1 mantendo Draft.

## OpenCode hard-deny project policy — 2026-10-03

The project-local OpenCode security policy is now implemented and validated
under a deny-by-default model. ASK is not used as a security boundary. Git and
operational mutations remain behind an external human terminal gate.

Checkpoint policy commit:

`6de5b06ae4dd00b4dd00b92ce2135dcdab04699a`

Static validation, controlled IMPLEMENT native-edit validation and QUICK local
Qwen inference validation passed. The long-lived OpenCode daemon predated the
policy, so an explicit configuration reload was performed successfully after
policy creation. Post-reload registry introspection by a temporary parser was
inconclusive because of CLI JSON-shape mismatch and does not override the
runtime enforcement evidence.

Do not repeat the completed policy tests unless the policy or a directly
relevant runtime component changes.

Production remains unchanged. RSK-P0-004 remains a release blocker.

Next:

`COMMIT_OPENCODE_HARD_DENY_CONTINUITY_CHECKPOINT_THEN_FRESH_FETCH_GUARD_AND_PUSH`
