# Baseline FASE-P0 de Cybersecurity

## Propósito, método e taxonomia

Esta baseline consolida o estado documental observado e validado em 2026-08-04. A fonte primária é `docs/review/cybersecurity/2026-08-04/AUDITORIA_CONSOLIDADA.md`; declarações históricas permanecem declarações e não são convertidas retroativamente em evidência. Ausência de evidência no repositório não prova ausência fora do escopo. Este documento não declara conformidade.

Cada registro usa quatro eixos independentes:

| Eixo | Valores permitidos | Significado |
|---|---|---|
| Natureza da informação | Evidência; declaração; inferência; ausência de evidência | Base probatória da afirmação. |
| Estado técnico | Implementado; parcialmente implementado; não implementado; não verificado; não aplicável com justificativa | Condição da capacidade no escopo e data. |
| Estado do achado | Aberto; em tratamento; mitigado; risco aceito; encerrado | Situação do ciclo do achado. |
| Resultado do controle | Atendido; parcialmente atendido; não atendido; não verificado; não aplicável com justificativa | Resultado da avaliação do critério do controle. |

**Confirmado** representa validação ou confiança na constatação. Não é natureza da informação, estado técnico, estado do achado nem resultado do controle. Os valores “não aplicável com justificativa” exigem fundamento, escopo, aprovador e validade; não substituem ausência de evidência.

## Rastreabilidade das afirmações materiais

As linhas da auditoria referem-se à versão preservada de 658 linhas. “Arquivo-fonte” identifica conteúdo original quando existente; “não localizado” registra ausência, sem criar evidência positiva.

| ID | Afirmação | Auditoria: seção e linha | Arquivo-fonte e linha, quando existir | Natureza da informação | Estado técnico | Limitação | Data da validação |
|---|---|---|---|---|---|---|---|
| MAT-001 | A taxonomia normativa define J.A.R.V.I.S. como sistema completo e Mímir como superagente coordenador, mas o repositório auditado usa os nomes de forma inconsistente. | §4.1, linhas 90–105; §5, 194–204 | `AGENTS.md:139`; `docs/README.md:5`; `docs/ARCHITECTURE.md:1` | Evidência e declaração normativa, mantidas separadas | Parcialmente implementado | A definição normativa do pacote não comprova harmonização dos documentos gerais. | 2026-08-04 |
| MAT-002 | A migração `001` está ausente do repositório e do histórico Git examinado. | §4.2, linhas 107–120 | `tools/memory/migrations/002_document_ingestion.sql:5,8,151,158`; `tools/memory/migrations/003_memory_candidates.sql:8`; arquivo `001` não localizado | Ausência de evidência, confirmada no escopo pesquisado | Não implementado | Não prova se existiu ou existe fora do Git; reconstrução do zero não foi testada. | 2026-08-04 |
| MAT-003 | O resultado histórico “22/22” não está comprovado por evidência auditável suficiente. | §4.3, linhas 122–141 | `docs/SECURITY_BASELINE_2026-07-31.md:7,11,13,19–30` | Declaração histórica; ausência de evidência de suporte | Não verificado | Só 12 controles são enumerados; não houve execução operacional. | 2026-08-04 |
| MAT-004 | A ingestão de sessões está restrita ao `dry-run`; a função SQL existe, mas o fluxo cliente→função não está implementado. | §4.4, linhas 143–151 | `tools/memory/mimir-ingest-session.py:463,470,534`; `tools/memory/mimir-capture-sessions.py:386`; `tools/memory/migrations/008_protected_session_ingestion.sql:86,110–120` | Evidência | Parcialmente implementado | Inspeção estática; nenhuma sessão real ou escrita foi testada. | 2026-08-04 |
| MAT-005 | O modo sombra possui código substancial, mas é incompleto como capacidade operacional governada. | §4.5, linhas 153–171 | `plugins/mimir-memory/src/index.ts:649,907,1117`; `tools/memory/mimir-evidence-shadow-evaluate.mjs:22,56`; `plugins/mimir-memory/src/index.test.ts:12` | Evidência e ausência de evidência, separadas | Parcialmente implementado | Não houve execução; faltam governança, métricas, critérios e cobertura documentada. | 2026-08-04 |
| MAT-006 | Não foi localizada documentação sobre HUD V6 no corpus auditado anterior às correções documentais. | §4.6, linhas 173–177 | Arquivo ou ocorrência `HUD`/`V6` não localizado | Ausência de evidência, confirmada no escopo pesquisado | Não verificado | Não prova inexistência externa. | 2026-08-04 |
| MAT-007 | Não foi localizada documentação sobre o ambiente operacional `jarvisdev` no corpus auditado anterior às correções documentais. | §4.7, linhas 179–190 | Nome presente apenas no caminho local; documentação funcional não localizada | Ausência de evidência, confirmada no escopo pesquisado | Não verificado | Caminho local não comprova usuário, privilégios ou operação. | 2026-08-04 |
| MAT-008 | Não foi localizada documentação sobre Codex CLI 0.146.0 no corpus auditado anterior às correções documentais. | §4.7, linhas 179–188 | Ocorrências `Codex`, `Codex CLI` e `0.146.0` não localizadas | Ausência de evidência, confirmada no escopo pesquisado | Não verificado | Não prova versão ou uso fora do repositório. | 2026-08-04 |
| MAT-009 | PostgreSQL 17 e pgvector são arquitetura declarada como fonte de verdade da memória durável. | §5, linha 201; §7, linhas 436–438 | `docs/ARCHITECTURE.md:24–26`; contradição em `MEMORY.md:33` | Declaração documental | Não verificado | Declaração arquitetural não comprova implantação ou operação; há contradição documental. | 2026-08-04 |
| MAT-010 | Não há governança LGPD formalizada no escopo auditado. | §1, linhas 26,32; §9, linhas 499–520 | `SOUL.md:29`; documentação LGPD completa não localizada | Ausência de evidência, confirmada no escopo pesquisado | Não implementado | Princípios genéricos de privacidade não equivalem à governança exigida. | 2026-08-04 |
| MAT-011 | Backup e restauração não estão comprovados. | §1, linha 33; §6/controle 14, linhas 355–364 | `docs/SECURITY.md:11`; `docs/ROADMAP.md:30` | Declaração e ausência de evidência de suporte | Não verificado | Backup é citado; restauração, RPO/RTO e operação não foram testados. | 2026-08-04 |
| MAT-012 | Resposta a incidentes não está comprovada como capacidade operacional. | §6/controle 19, linhas 410–419; §10, linhas 524–547 | `AGENTS.md:158`; plano e exercício operacionais não localizados | Declaração futura e ausência de evidência | Não implementado | O modelo documental de relatório não constitui plano aprovado ou exercício. | 2026-08-04 |

## Lacunas classificadas individualmente

Cada lacuna abaixo separa condição técnica de natureza probatória; nenhuma ausência documental foi agrupada automaticamente como não implementação.

| ID | Lacuna | Natureza da informação | Estado técnico | Estado do achado | Resultado do controle relacionado | Limitação |
|---|---|---|---|---|---|---|
| GAP-001 | Governança LGPD formal | Ausência de evidência | Não implementado | Aberto | Não atendido | Avaliação restrita ao repositório. |
| GAP-002 | Registro formal de riscos e método de aceite residual | Ausência de evidência | Não implementado | Aberto | Não atendido | Um modelo futuro não comprova processo vigente. |
| GAP-003 | Gestão documentada de vulnerabilidades e atualizações | Ausência de evidência | Não implementado | Aberto | Não atendido | Não houve verificação do ambiente. |
| GAP-004 | Backup operacional | Declaração e ausência de evidência de suporte | Não verificado | Aberto | Não verificado | A citação de backup não comprova execução. |
| GAP-005 | Restauração, continuidade, RPO e RTO | Ausência de evidência | Não verificado | Aberto | Não verificado | Não houve teste autorizado. |
| GAP-006 | Plano operacional de resposta a incidentes | Ausência de evidência | Não implementado | Aberto | Não atendido | O modelo P0 não é plano aprovado. |
| GAP-007 | Processo de recuperação com melhoria | Ausência de evidência | Não implementado | Aberto | Não atendido | Não há exercício ou registro de melhoria. |
| GAP-008 | Programa de treinamento | Ausência de evidência | Não implementado | Aberto | Não atendido | Avaliação documental apenas. |
| GAP-009 | Gestão formal de terceiros | Ausência de evidência | Não implementado | Aberto | Não atendido | Existem dependências, mas não governança formal. |
| GAP-010 | Migração `001` ou baseline equivalente com proveniência | Ausência de evidência | Não implementado | Aberto | Não atendido | Existência externa não foi verificada. |
| GAP-011 | HUD V6 documentado | Ausência de evidência | Não verificado | Aberto | Não verificado | Não prova inexistência externa. |
| GAP-012 | Ambiente `jarvisdev` documentado | Ausência de evidência | Não verificado | Aberto | Não verificado | O caminho local não comprova função operacional. |
| GAP-013 | Codex CLI 0.146.0 documentado | Ausência de evidência | Não verificado | Aberto | Não verificado | Não houve consulta externa ou execução. |

## PRIO-P0 e FASE-P0

**PRIO-P0** é criticidade ou prioridade do achado. **FASE-P0** é exclusivamente a fase documental do roadmap. Encerrar a FASE-P0 não encerra, rebaixa, mitiga nem aceita automaticamente um achado PRIO-P0 e não comprova tratamento técnico.

| ID | Risco PRIO-P0 | Estado do achado | Estado técnico | Condição para mudança |
|---|---|---|---|---|
| RSK-P0-001 | Migração `001` ausente e esquema não reproduzível | Aberto | Não implementado | Tratamento comprovado ou aceite humano competente, específico e válido. |
| RSK-P0-002 | Confiança indevida na declaração histórica “22/22” | Aberto | Não verificado | Evidência auditável por controle ou aceite humano específico da incerteza. |
| RSK-P0-003 | Governança LGPD ausente | Aberto | Não implementado | Governança aprovada e comprovada ou aceite competente onde juridicamente admissível. |
| RSK-P0-004 | Backup e restauração não comprovados | Aberto | Não verificado | Teste autorizado e evidenciado ou aceite humano específico. |
| RSK-P0-005 | Resposta a incidentes não comprovada | Aberto | Não implementado | Plano aprovado e exercício evidenciado ou aceite humano específico. |

## Checklist verificável de encerramento da FASE-P0

Versão/hash do pacote candidato: **pendente após correção documental**. Todos os resultados, prazos, revisores e estados permanecem pendentes até nova revisão independente; a presença de evidência documental proposta abaixo não concede aprovação.

| ID | Critério | Resultado | Evidência | Pendência | Responsável por função | Prazo | Revisor independente | Estado |
|---|---|---|---|---|---|---|---|---|
| C-P0-01 | Composição inequívoca: seis documentos funcionais, manifesto e auditoria-fonte. | Pendente | README e roadmap corrigidos | Validar contagem | Responsável documental | Pendente | Revisor independente | Pendente |
| C-P0-02 | SHA-256 e contagem de linhas da auditoria reconfirmados. | Pendente | Manifesto; cálculo local esperado | Reconfirmar 658 linhas e hash | Custodiante documental | Pendente | Revisor independente | Pendente |
| C-P0-03 | Taxonomia harmonizada em todos os documentos. | Pendente | Baseline, modelo de controles e evidências | Revisar quatro eixos | Responsável documental | Pendente | Revisor independente | Pendente |
| C-P0-04 | Cada afirmação material ligada à auditoria e, se aplicável, à fonte original. | Pendente | MAT-001 a MAT-012 | Conferir referências | Responsável documental | Pendente | Revisor independente | Pendente |
| C-P0-05 | Os 20 macrocontroles estão presentes exatamente na sequência definida. | Pendente | `CONTROL_MODEL.md` | Recontar IDs | Responsável por controles | Pendente | Revisor independente | Pendente |
| C-P0-06 | Mapeamentos normativos permanecem preliminares até validação competente. | Pendente | Ressalvas do modelo de controles | Confirmar ausência de alteração | Responsável por controles | Pendente | Revisor independente | Pendente |
| C-P0-07 | Não há equivalência entre macrocontroles documentados, implementação e conformidade. | Pendente | README, baseline e modelo | Revisar alegações | Responsável documental | Pendente | Revisor independente | Pendente |
| C-P0-08 | “22/22” permanece declaração histórica não comprovada. | Pendente | MAT-003 e RSK-P0-002 | Validar linguagem | Responsável por controles | Pendente | Revisor independente | Pendente |
| C-P0-09 | Migração, ingestão, modo sombra, HUD, ambiente e CLI estão classificados sem extrapolação. | Pendente | MAT-002 a MAT-008 | Revisar estados e limites | Responsável técnico documental | Pendente | Revisor independente | Pendente |
| C-P0-10 | Prioridade de risco e fase de implementação estão explicitamente separadas. | Pendente | Seção PRIO-P0/FASE-P0 e roadmap | Revisar terminologia | Responsável por riscos | Pendente | Revisor independente | Pendente |
| C-P0-11 | Evidência, declaração, inferência e ausência de evidência são separadas. | Pendente | Quatro eixos e rastreabilidade | Conferir natureza por item | Custodiante de evidências | Pendente | Revisor independente | Pendente |
| C-P0-12 | Estados técnicos são aplicados individualmente. | Pendente | GAP-001 a GAP-013 | Conferir cada lacuna | Responsável técnico documental | Pendente | Revisor independente | Pendente |
| C-P0-13 | Proporcionalidade não elimina ativos críticos, dados pessoais ou obrigações aplicáveis. | Pendente | Modelo de controles e README | Revisão de escopo | Proprietário do projeto | Pendente | Revisor independente | Pendente |
| C-P0-14 | Limites de autoridade, aprovação humana, reversão e escopo estão registrados. | Pendente | README, roadmap e modelos | Revisão de autoridade | Proprietário do projeto | Pendente | Revisor independente | Pendente |
| C-P0-15 | Cadeia de custódia permanece declarada incompleta. | Pendente | Manifesto | Revalidar redação | Custodiante documental | Pendente | Revisor independente | Pendente |
| C-P0-16 | Fluxo LGPD e incidente com dados pessoais permanecem separados da recuperação técnica. | Pendente | Modelo de incidente preservado | Revisão de privacidade | Responsável por privacidade/LGPD | Pendente | Revisor independente | Pendente |
| C-P0-17 | Incidentes cibernéticos permanecem separados de SST e acidentes de trabalho. | Pendente | Modelo de incidente preservado | Revisão de domínio | Responsável por incidentes | Pendente | Revisor independente | Pendente |
| C-P0-18 | Cada correção obrigatória tem responsável, prazo, evidência esperada e revisor. | Pendente | Tabela RTP0 abaixo | Preencher prazos e validar | Responsável documental | Pendente | Revisor independente | Pendente |
| C-P0-19 | Riscos PRIO-P0 permanecem abertos até tratamento ou aceite competente. | Pendente | RSK-P0-001 a RSK-P0-005 | Decisão humana não concedida | Proprietário dos riscos | Pendente | Revisor independente | Pendente |
| C-P0-20 | Ata/checklist final contém versão/hash, pendências, residuais e decisão humana explícita. | Atendido | DEC-P0-04 e `docs/review/cybersecurity/2026-08-04/ENCERRAMENTO_P0_FINAL.md` | Não existe pendência para o encerramento documental. Permanecem pendentes os tratamentos técnicos de RSK-P0-001 a RSK-P0-005. | Proprietário do projeto | 2026-08-07 | Revisão independente do candidato e decisão humana do proprietário | Atendido |

## Verificação das correções da revisão

| ID | Responsável por função | Prazo | Evidência esperada | Revisor | Resultado da verificação |
|---|---|---|---|---|---|
| RTP0-001 | Responsável documental e responsável por controles | 2026-08-04 | Quatro eixos harmonizados; lacunas individuais | Revisor independente | Pendente |
| RTP0-002 | Custodiante de evidências | 2026-08-04 | Tabela MAT com auditoria, fonte, natureza, estado, limite e data | Revisor independente | Pendente |
| RTP0-003 | Responsável por riscos e responsável pelo roadmap | 2026-08-04 | Separação PRIO-P0/FASE-P0 e riscos abertos | Revisor independente | Pendente |
| RTP0-004 | Proprietário do projeto e responsável documental | 2026-08-04 | Checklist de 20 critérios e decisões distintas | Revisor independente | Pendente |
| RTP0-005 | Responsável documental | 2026-08-04 | Contagem inequívoca no README e roadmap | Revisor independente | Pendente |
| RTP0-006 | Custodiante documental | 2026-08-04 | Sequência temporal sem horários inventados e custódia incompleta | Revisor independente | Pendente |
| RTP0-007 | Responsável por controles | 2026-08-04 | Campos, funções de aprovação e compensação de conflitos | Revisor independente | Pendente |

## Decisões humanas separadas

| ID | Decisão | Opções formais | Decisão atual | Autoridade por função | Data, justificativa e evidência |
|---|---|---|---|---|---|
| DEC-P0-01 | Aprovação ou reprovação do pacote documental | Aprovar / Reprovar | Aprovar | Proprietário do projeto | 2026-08-05. Aprovação explícita do pacote documental pelo proprietário do projeto, registrada na sessão decisória. Esta aprovação não aceita riscos, não encerra achados técnicos e não libera a FASE-P1. |
| DEC-P0-02 | Aceite ou rejeição dos riscos residuais | Aceitar / Rejeitar | Rejeitar | Proprietário competente de cada risco | 2026-08-05. Rejeição explícita do aceite de RSK-P0-001 a RSK-P0-005 pelo proprietário do projeto, registrada na sessão decisória. Os cinco riscos permanecem abertos e não aceitos. |
| DEC-P0-03 | Autorização ou proibição para iniciar FASE-P1 | Autorizar / Proibir | Proibir | Proprietário do projeto, com funções competentes aplicáveis | 2026-08-05. Proibição explícita do início da FASE-P1 pelo proprietário do projeto, registrada na sessão decisória. A FASE-P1 permanece bloqueada até o tratamento comprovado de RSK-P0-001 a RSK-P0-005. |
| DEC-P0-04 | Encerramento documental da FASE-P0 | Encerrar / Não encerrar | Encerrar | Proprietário do projeto | 2026-08-07. O proprietário confirmou explicitamente o encerramento documental da FASE-P0. RSK-P0-001 a RSK-P0-005 permanecem abertos e não aceitos. A FASE-P1 permanece proibida até o tratamento comprovado dos cinco riscos. |

As decisões permanecem independentes. O pacote documental foi aprovado. O aceite de RSK-P0-001 a RSK-P0-005 foi rejeitado.

A FASE-P0 foi encerrada exclusivamente no âmbito documental em 2026-08-07.

O encerramento não representa conformidade geral.

O encerramento não trata, mitiga, aceita ou encerra riscos técnicos.

RSK-P0-001 a RSK-P0-005 permanecem abertos e não aceitos.

A FASE-P1 permanece proibida até o tratamento comprovado dos cinco riscos.
