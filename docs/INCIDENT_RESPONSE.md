# Plano de Resposta a Incidentes — Mímir v1

Data: 2026-10-02

Status:

`IMPLEMENTED / EXERCISE_PENDING`

Risco relacionado:

`RSK-P0-005 — resposta a incidentes`

Este documento define o processo técnico e operacional de resposta a incidentes
do Projeto Mímir v1.

Ele não declara conformidade legal, conformidade LGPD, aceite de risco,
validação de produção ou encerramento de RSK-P0-005.

RSK-P0-005 permanece:

`OPEN / BLOCKER`

até que este plano seja aprovado pelo responsável competente e um exercício
isolado reproduzível seja executado, evidenciado e aprovado.

## 1. Objetivos

O processo de resposta a incidentes deve:

1. reduzir impacto sem introduzir nova alteração insegura;
2. preservar evidência suficiente para investigação;
3. impedir repetição automática de operações de resultado incerto;
4. proteger credenciais, dados confidenciais e memória permanente;
5. manter ações mutáveis sob autorização humana;
6. recuperar o serviço de forma verificável;
7. produzir registro técnico e ações corretivas;
8. distinguir restauração operacional de encerramento do incidente.

Regra:

`SERVICE_RESTORED != INCIDENT_CLOSED`

## 2. Escopo

Este plano cobre os componentes v1 do Mímir e suas fronteiras de confiança:

- OpenClaw Gateway e runtime;
- plugin `mimir-memory`;
- memória permanente PostgreSQL;
- ingestão e consolidação de sessões;
- runtime local de modelos;
- protected consolidator;
- adapters operacionais;
- identidade operacional `mimir_ops`;
- interfaces administrativas;
- Telegram e outros canais integrados;
- repositório Git;
- workflows/CI;
- artefatos de build/release;
- evidências e relatórios operacionais;
- hosts que executam componentes do projeto.

Equipamentos de clientes e outros ambientes externos só entram no escopo de uma
resposta quando estiverem formalmente autorizados para aquela intervenção.

## 3. Princípios obrigatórios

### 3.1 Fail closed

Quando identidade, autorização, integridade, estado de execução ou resultado
externo estiverem incertos:

`STOP`

Não continuar uma operação mutável para "ver se funciona".

### 3.2 Não repetir operação mutável incerta

Após timeout, perda de auditoria, desconexão ou resultado externo incerto:

`NO AUTOMATIC RETRY`

O estado deve ser reverificado por caminho READ autorizado antes de qualquer
nova tentativa.

### 3.3 Evidência antes de remediação destrutiva

Quando tecnicamente e operacionalmente possível, preservar evidência antes de:

- remover artefatos;
- rotacionar logs;
- reiniciar componentes;
- revogar identidades;
- substituir arquivos;
- restaurar dados;
- alterar configuração.

A preservação de evidência não autoriza manter um sistema comprometido exposto
quando contenção imediata for necessária.

### 3.4 Produção exige autorização explícita

Este plano não concede autorização automática para:

- restart de serviço;
- alteração de firewall;
- migration;
- alteração de banco;
- revogação ou criação de credencial;
- mudança de permissões;
- deploy;
- operação em equipamento real;
- restore de produção.

Cada ação mutável de produção continua sujeita ao mecanismo de autorização
aplicável.

### 3.5 Evidência real não entra no Git

Não versionar:

- tokens;
- senhas;
- chaves privadas;
- cookies;
- dumps reais;
- logs confidenciais brutos;
- exports operacionais reais;
- conteúdo protegido de usuários/clientes.

No Git devem permanecer somente metadados sanitizados, hashes, resultados,
procedimentos e evidências adequadas ao repositório.

## 4. Papéis

Os papéis são responsabilidades lógicas. Em uma operação pequena, uma mesma
pessoa pode acumular mais de um papel, mas as responsabilidades não devem ser
confundidas.

### Incident Coordinator

Responsável por:

- abrir o incidente;
- definir o estado corrente;
- coordenar decisões;
- manter o timeline;
- declarar passagem entre fases;
- propor encerramento.

### Technical Responder

Responsável por:

- coleta técnica;
- contenção autorizada;
- investigação;
- erradicação;
- recuperação;
- validação técnica.

### Evidence Custodian

Responsável por:

- identificar evidências;
- registrar origem;
- calcular hashes;
- preservar cadeia técnica mínima;
- garantir classificação e armazenamento adequados.

### System / Service Owner

Responsável por:

- determinar impacto operacional;
- aprovar ações sob sua competência;
- validar retorno do serviço;
- decidir sobre indisponibilidade aceitável.

### Privacy / Governance Escalation Owner

Responsável por receber incidentes que possam envolver:

- dados pessoais;
- confidencialidade de clientes;
- exposição regulatória;
- necessidade de avaliação jurídica ou contratual.

O Mímir não determina automaticamente obrigação legal de notificação.

## 5. Identidade do incidente

Todo incidente deve receber identificador único.

Formato recomendado:

`MIMIR-IR-YYYYMMDD-NNN`

O registro mínimo contém:

- `incident_id`;
- data/hora UTC de abertura;
- fonte da detecção;
- componente afetado;
- categoria;
- severidade;
- estado;
- Incident Coordinator;
- Technical Responder;
- Evidence Custodian;
- decisões de contenção;
- autorizações relevantes;
- evidências e hashes;
- ações executadas;
- resultado da recuperação;
- pendências;
- decisão de fechamento.

## 6. Categorias

Categorias mínimas:

- `CREDENTIAL_EXPOSURE`;
- `UNAUTHORIZED_ACCESS`;
- `UNAUTHORIZED_OPERATION`;
- `PROMPT_OR_CONTENT_INJECTION`;
- `MEMORY_INTEGRITY`;
- `DATABASE_INTEGRITY`;
- `EVIDENCE_INTEGRITY`;
- `SERVICE_COMPROMISE`;
- `SUPPLY_CHAIN`;
- `DATA_EXPOSURE`;
- `AVAILABILITY`;
- `EQUIPMENT_CONTROL_PLANE`;
- `OTHER`.

Uma ocorrência pode possuir múltiplas categorias.

## 7. Severidade

### SEV-1 — Critical

Exemplos:

- alteração não autorizada confirmada em produção;
- credencial privilegiada com comprometimento confirmado;
- execução arbitrária com impacto relevante;
- corrupção ativa de memória/dados críticos;
- impacto real em equipamento/control-plane;
- exposição grave em andamento.

Resposta:

- contenção prioritária;
- escalonamento humano imediato;
- preservar evidências;
- nenhuma ação mutável adicional sem coordenação explícita, exceto medida
  emergencial já autorizada por política externa aplicável.

### SEV-2 — High

Exemplos:

- tentativa de acesso privilegiado com evidência forte;
- credencial potencialmente exposta;
- integridade de componente crítico questionada;
- incidente com impacto relevante, mas sem comprometimento ativo confirmado.

Resposta:

- contenção controlada;
- investigação prioritária;
- decisão humana antes de recuperação mutável.

### SEV-3 — Medium

Exemplos:

- violação de política bloqueada;
- comportamento anômalo sem alteração persistente;
- incidente limitado a laboratório ou ambiente não produtivo.

Resposta:

- preservar evidência;
- investigar;
- corrigir causa antes de promover mudança.

### SEV-4 — Low

Exemplos:

- evento suspeito sem impacto;
- falso positivo ainda não classificado;
- desvio documental/processual sem impacto técnico imediato.

Resposta:

- registrar;
- analisar;
- corrigir processo se necessário.

Se houver dúvida entre duas severidades, usar inicialmente a maior até
reclassificação explícita.

## 8. Estados

Estados permitidos:

- `DETECTED`;
- `TRIAGED`;
- `CONTAINED`;
- `INVESTIGATING`;
- `ERADICATING`;
- `RECOVERING`;
- `VALIDATING`;
- `POSTMORTEM`;
- `CLOSED`.

Não saltar diretamente de detecção para fechamento.

## 9. Lifecycle obrigatório

Fluxo:

`DETECT -> CLASSIFY -> CONTAIN -> PRESERVE EVIDENCE -> INVESTIGATE -> ERADICATE -> RECOVER -> VALIDATE -> POSTMORTEM`

### 9.1 Detect

Registrar:

- timestamp;
- fonte;
- componente;
- marcador inicial;
- operador que observou.

Não assumir causa raiz nesta fase.

### 9.2 Classify

Definir:

- categoria;
- severidade inicial;
- escopo conhecido;
- produção versus laboratório;
- possibilidade de dados pessoais/confidenciais;
- necessidade de escalonamento.

### 9.3 Contain

Objetivo:

interromper ou limitar impacto sem destruir desnecessariamente a evidência.

Possíveis medidas, somente quando autorizadas:

- bloquear caminho operacional;
- desabilitar integração;
- revogar credencial;
- isolar serviço;
- restringir rede;
- colocar componente em modo read-only;
- suspender deploy;
- congelar operação mutável.

### 9.4 Preserve evidence

Registrar evidência antes de modificar o estado quando isso for seguro.

Campos mínimos por evidência:

- `incident_id`;
- `evidence_id`;
- timestamp UTC;
- origem;
- componente;
- classificação;
- caminho/local de armazenamento;
- SHA-256 quando aplicável;
- coletor;
- observação de integridade.

### 9.5 Investigate

A investigação deve separar:

- fato observado;
- inferência;
- hipótese;
- causa confirmada.

Não transformar hipótese em fato no relatório.

### 9.6 Eradicate

Remover ou corrigir a causa apenas por mudança autorizada.

Toda correção permanente deve preferencialmente ser:

- versionada;
- revisável;
- reproduzível;
- validada fora de produção antes da promoção.

### 9.7 Recover

Restaurar serviço/dado/configuração por procedimento autorizado.

Quando restore estiver envolvido:

- validar fonte;
- validar identidade/hash quando aplicável;
- registrar alvo;
- registrar operador;
- preservar evidência do resultado.

### 9.8 Validate

A recuperação não é considerada concluída apenas porque o serviço iniciou.

Validar, conforme o componente:

- integridade;
- identidade;
- disponibilidade;
- comportamento esperado;
- ausência de alteração não autorizada;
- ausência de resíduo conhecido;
- controles de segurança relevantes.

### 9.9 Postmortem

O postmortem deve conter:

- resumo do incidente;
- impacto;
- timeline;
- detecção;
- contenção;
- causa raiz ou causa ainda não confirmada;
- evidências;
- ações tomadas;
- o que funcionou;
- o que falhou;
- ações corretivas;
- owner de cada ação;
- estado residual.

## 10. Credencial potencialmente comprometida

Se houver indicação de exposição de credencial:

1. classificar a credencial;
2. identificar escopo de acesso;
3. preservar evidência sem registrar o segredo bruto;
4. bloquear novo uso quando autorizado;
5. rotacionar/revogar por procedimento autorizado;
6. verificar uso indevido;
7. atualizar dependências de forma controlada;
8. validar credencial antiga como inválida quando possível;
9. registrar conclusão.

Nunca inserir a credencial comprometida no Git como evidência.

## 11. Prompt injection / conteúdo não confiável

Conteúdo proveniente de:

- usuário;
- site;
- documento;
- mensagem;
- modelo;
- ferramenta;
- agente externo;

não ganha autoridade operacional por estar dentro do contexto do modelo.

Se conteúdo não confiável tentar:

- alterar policy;
- promover memória;
- chamar ferramenta;
- remover revisão humana;
- obter segredo;
- executar ação privilegiada;

tratar o evento como dado não confiável e aplicar os controles existentes.

Tentativa bloqueada pode ser classificada como incidente ou evento de segurança
de acordo com impacto e contexto.

## 12. Memória permanente

Suspeita de comprometimento da memória exige distinguir:

- conteúdo incorreto;
- conteúdo não confiável;
- corrupção;
- promoção indevida;
- quebra de proveniência.

Não apagar registros automaticamente.

Preservar:

- source/event identity;
- hashes;
- estado candidate/active;
- revisão humana;
- evidência de proveniência;
- ações administrativas relacionadas.

## 13. PostgreSQL

Em suspeita de incidente no banco:

- não aplicar migration corretiva diretamente em produção;
- preservar schema/version/role state;
- preferir inspeção read-only inicial;
- não aumentar privilégios para facilitar diagnóstico;
- usar laboratório para reproduzir correção quando possível;
- manter restore como operação separadamente autorizada.

## 14. Operações e equipamentos

Após uma operação mutável com resultado incerto:

`DO NOT RETRY`

Executar reconciliação:

1. localizar intervenção pelo identificador;
2. revisar journal persistido;
3. verificar equipamento por caminho READ autorizado;
4. comparar estado esperado e observado;
5. classificar resultado;
6. decidir correção ou rollback;
7. registrar a decisão e nova autorização.

## 15. Evidências e retenção

Aplicam-se também as regras canônicas de:

`docs/OPERATIONS_RETENTION.md`

Princípios:

- failed/interrupted devem ser preservados;
- evidência operacional real é confidencial;
- Git recebe somente conteúdo sanitizado;
- purge automático não é permitido na v1;
- evidência não pode ser removida apenas porque o serviço foi recuperado.

## 16. Comunicação

Durante um incidente:

- comunicar fatos confirmados separadamente de hipóteses;
- evitar compartilhar segredos ou dados confidenciais em canais inadequados;
- registrar decisões materiais;
- escalar impacto de cliente/dados pessoais ao responsável competente;
- não produzir conclusão jurídica automática.

Comunicação externa a clientes, fornecedores, titulares, autoridades ou terceiros
exige decisão humana competente fora da automação do Mímir.

## 17. Critérios de recuperação

Um componente pode ser declarado tecnicamente recuperado quando:

- estado esperado foi confirmado;
- validações relevantes passaram;
- credenciais afetadas foram tratadas;
- causa imediata foi contida;
- não existe resíduo conhecido incompatível com operação segura.

Isto produz:

`SERVICE_RESTORED`

Não produz automaticamente:

`INCIDENT_CLOSED`

## 18. Critérios de fechamento

Para `CLOSED`, exigir:

- contenção confirmada;
- investigação suficiente para a decisão;
- recuperação validada;
- evidência preservada;
- ações corretivas/residuais registradas;
- postmortem concluído ou adiamento humano explícito;
- incident owner aprovou fechamento.

Quando houver obrigação de governança, privacidade, contrato ou requisito
externo pendente, o incidente técnico não deve ser tratado como integralmente
encerrado apenas porque o serviço voltou.

## 19. Falha durante resposta

Se uma ação de resposta falhar:

`STOP -> PRESERVE -> ROOT CAUSE -> FIX VERSIONED PROCESS/CODE -> AUTHORIZE -> RETRY`

Não executar loop de tentativa e erro sobre produção.

## 20. Exercícios

Exercícios de resposta devem começar em ambiente isolado.

O exercício inicial de RSK-P0-005 deve:

- usar cenário sintético;
- não usar credencial real;
- não acessar dados reais;
- não alterar produção;
- não operar equipamento real;
- preservar evidência sanitizada;
- produzir postmortem;
- demonstrar zero resíduo inesperado.

Uma execução de exercício não deve ser repetida automaticamente após FAIL.

## 21. Critérios de PASS do primeiro exercício

PASS exige:

- incident ID;
- severidade;
- papéis;
- detecção;
- classificação;
- contenção;
- evidência com hash;
- investigação;
- recuperação/validação;
- zero ação de produção;
- zero segredo real;
- postmortem;
- ações corretivas;
- zero resíduo inesperado.

## 22. Estado de RSK-P0-005

Estado após implementação deste documento:

`IMPLEMENTED_PLAN / EXERCISE_PENDING`

Estado de risco:

`OPEN / BLOCKER`

Este plano sozinho não encerra o risco.

Para propor:

`TREATED_BY_IMPLEMENTATION_AND_EXERCISE`

ainda são necessários:

1. validação repository-only deste documento;
2. aprovação humana do plano;
3. exercício sintético isolado;
4. PASS do exercício;
5. preservação das evidências;
6. reconciliação de `V1_SECURITY_CHECKLIST.md`;
7. checkpoint de continuidade.

## 23. Relações documentais

Este plano deve ser interpretado em conjunto com:

- `docs/SECURITY.md`;
- `docs/RUNBOOK.md`;
- `docs/OPERATIONS.md`;
- `docs/OPERATIONS_RETENTION.md`;
- `docs/V1_SECURITY_CHECKLIST.md`.

Em caso de conflito, controles mais restritivos permanecem vigentes até revisão
explícita e versionada.

## 24. Próxima etapa

`VALIDATE_RSK_P0_005_INCIDENT_RESPONSE_PLAN_REPOSITORY_ONLY`

Nenhum exercício está autorizado por este documento.
