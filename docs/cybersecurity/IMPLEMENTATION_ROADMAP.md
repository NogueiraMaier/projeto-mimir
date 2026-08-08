# Roadmap de implementação do módulo Cybersecurity

## Regras gerais

As fases são cumulativas, proporcionais ao contexto de pequenas empresas e dependem de aprovação humana. Para evitar ambiguidade, **FASE-P0** designa exclusivamente a fase documental deste roadmap; **PRIO-P0** designa criticidade ou prioridade de tratamento de um achado. Nenhuma fase autoriza implantação automática em produção, acesso a clientes, varredura, alteração de firewall, coleta não autorizada ou tratamento novo de dados pessoais. Entregável documental não deve ser descrito como capacidade operacional.

## FASE-P0 — documentação e estado real

**Objetivo:** estabelecer linguagem canônica, registrar o estado comprovado e criar modelos mínimos de controle, evidência, achado, incidente e evolução.

**Entregáveis:** seis documentos funcionais e um manifesto de integridade, totalizando sete componentes do pacote; uma auditoria-fonte externa aos componentes, totalizando oito arquivos revisados; 20 macrocontroles; quatro eixos taxonômicos independentes; riscos e critérios de saída. `REVISAO_P0.md` é parecer independente e não integra os sete componentes originais.

**Dependências:** auditoria consolidada; leitura dos documentos internos; definições obrigatórias de arquitetura; autorização para criar somente documentação.

**Riscos:** cristalizar informação desatualizada, confundir declaração com evidência, inventar correspondência normativa ou sugerir conformidade.

**Evidências:** arquivos criados, referências internas válidas, SHA-256/linhas da auditoria, revisão de conteúdo e `git status` sem alterações fora do escopo.

**Critério de aceitação:** todos os critérios de encerramento de `docs/cybersecurity/BASELINE_P0.md` são atendidos e nenhuma alegação de implementação/conformidade excede a evidência.

**Ponto de aprovação humana:** são decisões separadas e atualmente pendentes: aprovação ou reprovação documental; aceite ou rejeição dos riscos residuais; autorização ou proibição de iniciar FASE-P1. O encerramento da FASE-P0 não encerra, rebaixa, mitiga nem aceita automaticamente achados PRIO-P0.

## FASE-P1 — governança, esquemas e mapeamentos oficiais

**Objetivo:** transformar os modelos P0 em governança aprovada e recuperar a reprodutibilidade documental/técnica necessária, sem implantação automática.

**Entregáveis:** glossário e RACI; inventários de ativos, software, dados/LGPD, contas, terceiros e riscos; políticas proporcionais de retenção, acesso, vulnerabilidades, logging, continuidade e incidentes; recuperação ou reconstrução governada da migração `001`/baseline equivalente; esquema dos registros de controles/evidências/achados; mapeamentos oficiais validados contra as versões aplicáveis dos referenciais; decisão sobre modo sombra, HUD V6 e ambiente `jarvisdev`.

**Dependências:** aprovação documental da FASE-P0, aceite ou rejeição explícita dos riscos residuais e autorização humana separada para iniciar FASE-P1; responsáveis de negócio, segurança, privacidade e banco; acesso autorizado às publicações oficiais; decisão jurídica quando aplicável; ambiente isolado futuro para validar esquema.

**Riscos:** reconstrução incorreta do esquema, exposição de dados em inventários, conflito de papéis, interpretação normativa inadequada e atualização documental parcial.

**Evidências:** atas de aprovação; matriz oficial com fonte/versão/data; inventários versionados e sanitizados; revisão do esquema; plano de teste e reversão; registros de risco e privacidade.

**Critério de aceitação:** papéis e ativos críticos possuem dono; tratamentos de dados estão inventariados; mapeamentos deixam de ser preliminares somente onde validados; esquema é reprodutível em ambiente isolado por teste autorizado e documentado; lacunas remanescentes têm responsável e prazo.

**Ponto de aprovação humana:** responsáveis por projeto, segurança, privacidade/LGPD e PostgreSQL autorizam, separadamente, qualquer passagem a coleta P2. A aprovação documental não autoriza produção.

## FASE-P2 — coletores defensivos somente leitura

**Objetivo:** obter visibilidade mínima e evidência operacional por mecanismos defensivos, limitados, autorizados e somente leitura.

**Entregáveis:** catálogo de fontes; especificação de coletores; matriz de permissões; retenção e mascaramento; ambiente de homologação; resultados de testes passivos; cobertura e limitações; runbooks de falha/desligamento; integração controlada com registros de evidência e achado.

**Dependências:** P1 aprovado; escopo por cliente/ativo; base legal e finalidade quando houver dados pessoais; contas de leitura mínima; armazenamento protegido; sincronização de tempo; plano de incidente e reversão.

**Riscos:** coleta excessiva, impacto de desempenho, segredo em log, falso positivo, perda de integridade, aumento de superfície e percepção indevida de monitoramento completo.

**Evidências:** autorização por fonte; testes em ambiente isolado; amostras sanitizadas; hashes; logs de acesso; métricas de cobertura, erro e descarte; revisão de privacidade e segurança.

**Critério de aceitação:** cada coletor é somente leitura, mínimo, desligável, testado sem impacto material, vinculado a ativo/controle, com retenção, acesso, erro e lacunas documentados. Scanner ativo não integra esta fase.

**Ponto de aprovação humana:** dono do ativo, segurança e privacidade aprovam individualmente cada coletor e sua fonte antes de qualquer piloto. Sem aprovação, permanece desativado.

## FASE-P3 — piloto controlado em pequena empresa

**Objetivo:** avaliar aplicabilidade, custo, eficácia e proporcionalidade do módulo em uma pequena empresa voluntária e formalmente autorizada.

**Entregáveis:** termo de escopo; inventário mínimo do piloto; plano de comunicação e suporte; critérios de sucesso/pausa/saída; implantação manual controlada dos componentes aprovados; registro de evidências e achados; exercício de incidente e recuperação; relatório final executivo/técnico e plano de desativação.

**Dependências:** P2 aprovado; cliente identificado; contrato/autorizações; avaliação LGPD e de terceiros; responsáveis e contatos; backup e reversão; janela de mudança; suporte; critérios de segregação entre clientes.

**Riscos:** indisponibilidade, coleta indevida, interpretação excessiva de cobertura, conflito com operação do cliente, incidentes durante o piloto e custo desproporcional.

**Evidências:** autorizações assinadas; baseline antes/depois; diário de mudanças; resultados de testes autorizados; métricas; incidentes/desvios; restauração/reversão demonstrada; aceite ou rejeição final do cliente.

**Critério de aceitação:** objetivos mensuráveis são cumpridos sem violação de escopo; riscos residuais e limitações são aceitos; recuperação e desligamento são demonstrados; o cliente recebe relatório compreensível; não há expansão automática para produção ou outros clientes.

**Ponto de aprovação humana:** cliente, proprietário do projeto, segurança e privacidade decidem iniciar, pausar, encerrar ou ampliar. Qualquer produção posterior exige novo plano, nova autorização e controle de mudança próprio.

## Portões entre fases

Uma fase não avança por calendário ou pela simples criação de documentos. O portão exige evidência do critério de aceitação, riscos residuais explícitos e decisão humana registrada. Reprovação mantém a fase aberta; exceção deve ter escopo, justificativa, compensação, aprovador e validade.

Permanecem **abertos e PRIO-P0** até tratamento comprovado ou aceite humano competente e específico: migração `001`; declaração histórica da baseline “22/22”; governança LGPD; backup e restauração; e resposta a incidentes. A conclusão documental da FASE-P0 não altera esses estados e não autoriza FASE-P1.
