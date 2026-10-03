# Política v1 de retenção operacional

Data: 2026-09-24
Status: ATIVA PARA O DESENHO v1
Escopo: camada operacional do Projeto Mímir

## Objetivo

Esta política define o tratamento de journal, evidências, relatórios e auditoria da camada operacional antes de qualquer homologação em equipamento real.

Ela não é uma política legal/regulatória e não substitui requisitos contratuais ou legais específicos de um cliente. É a política técnica conservadora do Mímir v1.

## Regra principal

No Mímir v1 não existe expurgo automático de registros operacionais persistidos.

Registros operacionais persistidos são mantidos por tempo indeterminado durante a v1, até que uma política posterior, versionada e revisada, introduza um mecanismo administrativo de ciclo de vida.

Não criar cron, trigger, job SQL, rotina de aplicação ou endpoint que apague automaticamente esses registros na v1.

## Registros cobertos

A política cobre principalmente:

- `mimir.ops_interventions`;
- `mimir.ops_actions`;
- `mimir.ops_evidence`;
- `mimir.ops_reports`;
- `mimir.ops_audit`.

Também se aplica aos campos de observação operacional derivados de intervenções enquanto forem necessários para interpretar o estado atual do equipamento.

## Imutabilidade e modelo de escrita

Na v1:

- journal de ações é append-only;
- evidências são append-only;
- relatórios finais não são substituídos pela API operacional;
- auditoria é append-only;
- intervenções podem avançar apenas conforme a máquina de estados e finalização controlada;
- não há API operacional de DELETE;
- não há API operacional de edição arbitrária do histórico.

Correções administrativas futuras não devem apagar silenciosamente a história anterior. Devem preservar antes/depois e registrar a ação administrativa.

## Intervenções failed e interrompidas

Intervenções com status `failed`, inclusive as reconciliadas após resultado externo incerto, têm a mesma exigência de preservação que intervenções bem-sucedidas.

Elas não podem ser descartadas por serem falhas.

Para uma intervenção interrompida após `EXECUTE intent`, devem permanecer preservados:

- o plano aprovado;
- a identidade/autorização registrada;
- todo o journal já persistido;
- o relatório de reconciliação;
- o estado de reverificação exigida;
- a trilha de auditoria correspondente.

O LAB-09 demonstrou que esses registros são necessários para impedir novo EXECUTE até reverificação.

## Dados sensíveis

Relatórios e evidências operacionais são classificados como confidenciais.

Regras:

- não versionar relatórios/evidências reais no Git público;
- não persistir senha, token, chave privada ou segredo bruto;
- manter redaction antes da persistência;
- manter exports locais em diretório 0700 e arquivos 0600;
- backups que contenham registros operacionais devem receber proteção compatível com a base original;
- não usar evidência operacional como canal para armazenar configuração completa quando o adapter não tiver política específica para isso.

## Backups

Backup não altera a política de retenção lógica.

Enquanto um registro operacional estiver sob retenção, uma cópia de backup que o contenha não deve ser tratada como autorização para apagar o original.

Da mesma forma, eventual exclusão futura do registro primário não implica exclusão automática das cópias de backup.

Qualquer política futura de expiração de backups deve ser definida separadamente e considerar capacidade de restauração, proteção de segredos e obrigações externas.

## Laboratórios sintéticos

Clusters e bancos de laboratório com dados totalmente sintéticos são descartáveis.

Eles podem ser removidos quando:

1. o objetivo do laboratório tiver sido concluído;
2. as evidências necessárias tiverem sido registradas em documentação versionada;
3. o backup/restore exigido para aquele checkpoint tiver sido validado;
4. não houver próximo teste que dependa do mesmo estado.

O dump sintético do laboratório não é tratado como registro operacional de produção.

## Expurgo administrativo futuro

A v1 não implementa expurgo.

Se uma versão futura adicionar purge, o procedimento deve ser administrativo, explícito e fora da role operacional `mimir_ops`.

Antes de qualquer exclusão, o mecanismo futuro deverá no mínimo:

1. identificar exatamente o escopo e a quantidade de registros;
2. rejeitar intervenção running ou estado ainda dependente de reconciliação;
3. preservar integridade referencial;
4. registrar autorização, operador, motivo e intervalo temporal;
5. produzir evidência/auditoria da operação de purge em local que não seja apagado pela própria transação;
6. prever backup/restauração antes da exclusão;
7. executar primeiro em modo de pré-visualização;
8. exigir revisão humana;
9. ser validado em laboratório antes de produção.

Nenhuma dessas capacidades autoriza implementação automática na v1.

## Relação com memória permanente

Evidência operacional e memória permanente são domínios diferentes.

A retenção de `ops_*` não promove dados automaticamente para memória permanente e a promoção para memória não autoriza apagar a evidência operacional de origem.

O contrato `memory_handoff` continua sujeito a revisão humana, deduplicação, contradição e proveniência.

## Estado v1

Política adotada para v1:

- retenção operacional persistente: sem expiração automática;
- purge automático: proibido;
- purge administrativo: não implementado;
- failed/interrupted: preservar;
- dados reais: confidenciais e fora do Git;
- laboratório sintético: descartável após evidência/versionamento;
- política de ciclo de vida com prazo fixo: adiada para versão posterior ou requisito específico de implantação.

Essa escolha privilegia auditabilidade e segurança operacional enquanto o volume real e requisitos de implantação ainda não foram medidos.
