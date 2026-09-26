# Mímir — Security Governance, Risk e Control Assurance Roadmap

Status: **PLANEJADO / PÓS-v1 / NÃO IMPLEMENTADO**  
Escopo: evolução de segurança, governança, risco, evidência, detecção, resposta e recuperação.

Este documento registra melhorias arquiteturais derivadas do estudo de fundamentos de defesa cibernética, gestão de riscos, NIST CSF 2.0, Zero Trust, MITRE ATT&CK, defesa em profundidade, resposta a incidentes e continuidade.

Este documento **não autoriza alteração de produção**, não muda o `NEXT_ACTION` atual e não amplia permissões do agente `main`.

## Fora de escopo nesta revisão

A capacidade de acesso/análise do desktop ou endpoint, incluindo qualquer `mimir-desktopd`, permanece **FORA DE ESCOPO** neste documento.

Esse tema será discutido separadamente antes de qualquer documentação arquitetural ou implementação.

---

## 1. Princípio de segurança orientada por evidência

O Projeto Mímir deve tratar segurança como capacidade contínua e mensurável.

Princípio:

`CONFIGURED != EFFECTIVE`

Um controle não deve ser considerado efetivo apenas porque existe em configuração.

Sempre que aplicável, um controle deve possuir evidência de:

- configuração;
- cobertura;
- operação;
- validação;
- resultado;
- última verificação;
- responsável;
- limitações conhecidas.

Estados candidatos para controles:

- `declared`;
- `configured`;
- `observed`;
- `tested`;
- `verified`;
- `degraded`;
- `failed`;
- `unknown`.

A promoção entre estados deve depender de evidência, não de afirmação do LLM.

---

# S1 — AI Asset & Data Flow Registry

Prioridade: **ALTA após baseline e conclusão da v1**.

Objetivo:

Inventariar formalmente os componentes de IA e seus fluxos de dados antes de ampliar providers, engines, tools e integrações.

O registry deve complementar, e não substituir, o futuro Engine Registry.

Campos candidatos:

- `asset_id`;
- `asset_type`;
- `provider`;
- `runtime`;
- `model`;
- `version`;
- `capabilities`;
- `owner`;
- `dependencies`;
- `tools_available`;
- `permissions`;
- `data_classes_allowed`;
- `data_classes_denied`;
- `external_data_flow`;
- `destination_class`;
- `retention_expectation`;
- `credential_reference`;
- `risk_class`;
- `last_reviewed_at`;
- `status`.

Não armazenar segredo no registry.

Credenciais devem permanecer fora do Git e ser referenciadas por identificador controlado.

### Casos de uso

Antes de usar provider externo, o Mímir deve poder responder:

- quais dados sairão do ambiente?;
- para qual provider?;
- qual classificação?;
- quais permissões a integração possui?;
- quais dependências são criadas?;
- existe política permitindo o fluxo?;
- existe alternativa local?

### Integração

Relacionar com:

- `MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`;
- Policy Engine;
- Engine Registry;
- classificação de dados;
- auditoria.

---

# S2 — Zero-Trust Authorization Context

Prioridade: **ALTA**.

Objetivo:

Evoluir as decisões de autorização para considerar identidade, recurso, ação, contexto, tempo, risco e política.

A localização de rede, por si só, não deve conceder confiança implícita.

Modelo conceitual:

```text
WHO
  operator
  agent
  service identity

WHAT
  operation

RESOURCE
  device
  file
  memory
  provider
  tool

CONTEXT
  client
  site
  project
  classification
  source

TIME
  granted_at
  expires_at

RISK
  low
  medium
  high
  critical

APPROVAL
  required
  approval_ref
```

### Princípios

- mínimo privilégio;
- autorização por ação;
- duração limitada;
- revisão de permissões efetivas;
- separação de identidades administrativas;
- expiração explícita para acessos temporários;
- deny-by-default quando a política não resolver de forma segura.

### Just-in-Time / Just-Enough Access

Status: **PLANEJADO**.

Avaliar autorizações temporárias e limitadas por operação.

Exemplo conceitual:

```text
agent=network
operation=mikrotik.read
device=X
client=Y
mode=READ
expires=+30min
```

Não implementar acesso temporário sem mecanismo confiável de revogação/expiração.

---

# S3 — Risk Engine

Prioridade: **ALTA**.

Objetivo:

Apoiar priorização e decisões com contexto de risco, evitando tratar severidade técnica como sinônimo de risco.

Entradas candidatas:

- ativo;
- criticidade;
- serviço/processo relacionado;
- exposição;
- ameaça relevante;
- vulnerabilidade;
- sinais observados;
- controles existentes;
- eficácia dos controles;
- impacto;
- dependências;
- evidência;
- incerteza.

Saída:

`Risk Context`

O Risk Engine não deve produzir uma falsa precisão matemática quando os dados forem qualitativos.

### Fluxo

```text
Asset
  |
Threat / Exposure
  |
Vulnerability
  |
Current Controls
  |
Business / Operational Impact
  |
Risk Context
  |
Policy / Prioritization
```

### Uso

- priorização de vulnerabilidades;
- priorização de incidentes;
- autorização contextual;
- seleção de controles;
- planejamento de correção;
- avaliação de risco residual.

### Tratamento de risco

Registrar, quando aplicável:

- reduzir;
- evitar;
- transferir/compartilhar;
- aceitar.

Aceitação deve ser consciente, autorizada, registrada e revisável.

---

# S4 — Attack Surface & Drift Registry

Prioridade: **ALTA/MÉDIA**.

Objetivo:

Evoluir o CMDB para representar superfície de ataque e desvios entre estado esperado e observado.

Itens candidatos:

- portas;
- serviços;
- APIs;
- identidades;
- contas privilegiadas;
- integrações;
- túneis;
- providers;
- interfaces administrativas;
- endpoints publicados;
- dependências;
- caminhos de administração;
- exposição externa/interna.

### Estado esperado versus observado

```text
EXPECTED STATE
      |
      v
comparison
      ^
      |
OBSERVED STATE
```

Eventos candidatos:

- `attack_surface_drift`;
- `unexpected_service`;
- `unexpected_port`;
- `unexpected_identity`;
- `unexpected_external_dependency`;
- `management_path_drift`.

Drift não deve gerar EXECUTE automático.

O Mímir deve primeiro:

1. observar;
2. correlacionar;
3. avaliar risco;
4. produzir evidência;
5. propor plano;
6. exigir autorização quando aplicável.

---

# S5 — Security Control Assurance

Prioridade: **ALTA**.

Objetivo:

Manter catálogo de controles com evidência de efetividade.

Categorias funcionais:

- preventivo;
- detectivo;
- corretivo.

Um mesmo controle pode cumprir múltiplas funções.

Exemplos:

- MFA;
- hardening;
- segmentação;
- firewall;
- IDS/SIEM;
- backups;
- gestão de vulnerabilidades;
- logs;
- monitoramento;
- resposta a incidentes.

### Modelo conceitual

```text
CONTROL
  |
  +-- declared
  +-- configured
  +-- coverage
  +-- test
  +-- observed result
  +-- evidence
  +-- last_verified
  +-- owner
  +-- residual limitations
```

### Perguntas obrigatórias

- o controle está configurado?;
- onde está coberto?;
- está operando?;
- foi testado?;
- qual evidência sustenta isso?;
- qual resultado foi observado?;
- qual risco residual permanece?;
- quando precisa ser revalidado?

---

# S6 — Evidence-Grade Audit

Prioridade: **ALTA**.

Objetivo:

Padronizar eventos de auditoria para permitir reconstrução técnica e correlação.

Elementos mínimos, quando aplicável:

- identidade;
- ação;
- objeto;
- timestamp;
- origem/contexto;
- política aplicada;
- decisão;
- resultado;
- correlation/trace id;
- evidência relacionada.

Exemplo conceitual:

```json
{
  "trace_id": "...",
  "timestamp": "...",
  "identity": {
    "operator": "...",
    "agent": "...",
    "service": "..."
  },
  "action": "mikrotik.read",
  "resource": {
    "type": "device",
    "id": "..."
  },
  "context": {
    "client": "...",
    "project": "...",
    "classification": "confidential"
  },
  "decision": {
    "policy": "allow",
    "risk": "low"
  },
  "result": "success"
}
```

Não registrar segredos.

Logs devem ser:

- pertinentes;
- correlacionáveis;
- protegidos;
- preserváveis;
- utilizáveis em investigação.

Quantidade de logs não deve ser tratada como sinônimo de cobertura.

---

# S7 — Detection Engineering e MITRE ATT&CK

Prioridade: **MÉDIA / FUTURA FASE SOC**.

Objetivo:

Usar MITRE ATT&CK como linguagem de comportamento adversário para apoiar detecção, hunting, investigação e cobertura.

ATT&CK não substitui:

- gestão de riscos;
- NIST CSF;
- Zero Trust;
- catálogo de controles.

### Fluxo conceitual

```text
telemetry
   |
detection
   |
ATT&CK technique / behavior
   |
case
   |
asset + context + evidence
   |
Risk Engine
   |
priority / response
```

### Casos de uso

- mapear regra de detecção para técnica;
- medir cobertura;
- identificar lacunas;
- organizar threat hunting;
- estruturar investigação;
- apoiar exercícios defensivos.

### Regra

Não criar detecção apenas para aumentar contagem de regras.

Cada detecção deve declarar:

- fonte;
- comportamento;
- contexto;
- falso positivo conhecido;
- severidade;
- evidência;
- resposta esperada;
- responsável.

---

# S8 — Incident Response State Machine

Prioridade: **MÉDIA/ALTA antes de automação SOC ativa**.

Objetivo:

Criar workflow explícito de resposta a incidentes integrado à governança existente.

Modelo candidato:

```text
DETECTED
   |
TRIAGE
   |
CONFIRMED
   |
CONTAINMENT_PLAN
   |
HUMAN_APPROVAL
   |
CONTAIN
   |
REMEDIATE
   |
VALIDATE
   |
RECOVER
   |
POST_INCIDENT
   |
LEARN
```

Estados e transições devem ser versionados e testados.

### Requisitos

- responsabilidades;
- severidade;
- critérios de escalonamento;
- comunicação;
- evidência;
- aprovação;
- contenção;
- validação;
- recuperação;
- lições aprendidas.

Não autorizar contenção destrutiva automática sem política explícita.

### Integração com memória

Lições aprendidas podem gerar candidato de memória, nunca promoção automática.

---

# S9 — RPO, RTO e Recovery Assurance

Prioridade: **ALTA antes de considerar resiliência consolidada**.

Objetivo:

Definir metas de recuperação por componente crítico e provar que a capacidade real atende ao objetivo.

Componentes a classificar futuramente:

- PostgreSQL `mimir_memory`;
- CMDB;
- OpenClaw state;
- Gateway configuration;
- plugin state;
- evidence;
- operational reports;
- secrets/config references;
- HUD;
- modelos locais reconstruíveis;
- documentação/Git.

Para cada componente, quando aplicável:

- criticidade;
- backup;
- frequência;
- RPO;
- RTO;
- dependências;
- procedimento de restore;
- último teste;
- resultado do teste.

Não definir RPO/RTO apenas por conveniência técnica.

Devem refletir impacto operacional real.

Princípio:

`backup existente != serviço recuperável`

---

# S10 — Security Maturity e Continuous Improvement

Prioridade: **MÉDIA**.

Objetivo:

Avaliar maturidade por evidência e consistência operacional.

Dimensões candidatas:

- governança;
- inventário;
- identidade;
- vulnerabilidades;
- superfície de ataque;
- controles;
- monitoramento;
- detecção;
- resposta;
- recuperação;
- métricas;
- melhoria contínua.

Estados didáticos candidatos:

- `initial`;
- `structured`;
- `managed`;
- `optimized`.

Os nomes são apenas rótulos internos; o valor está nos critérios verificáveis.

### Métricas candidatas

- cobertura de inventário;
- cobertura de controles verificados;
- contas privilegiadas com proteção adequada;
- tempo de detecção;
- tempo de resposta;
- tempo de correção;
- vulnerabilidades críticas por exposição;
- taxa de restauração validada;
- incidentes sem evidência suficiente;
- drift de superfície de ataque;
- controles vencidos para revalidação.

Métricas só devem existir se suportarem decisão real.

---

# S11 — Vulnerability Management Loop

Prioridade: **MÉDIA/ALTA**.

Objetivo:

Formalizar o ciclo:

```text
DISCOVER
   |
PRIORITIZE
   |
PLAN
   |
REMEDIATE
   |
VALIDATE
   |
EVIDENCE
```

O fechamento de ticket não comprova eliminação da exposição.

A prioridade deve combinar, quando disponível:

- severidade;
- exploitability;
- exposição;
- criticidade;
- sinais observados;
- controles compensatórios;
- impacto;
- dependências.

A validação pós-correção é obrigatória para marcar a exposição como efetivamente reduzida.

---

# S12 — NIST CSF 2.0 como mapa de cobertura

Prioridade: **MÉDIA**.

Objetivo:

Usar as funções do NIST CSF 2.0 como visão de cobertura e governança, sem transformar o framework em implementação rígida.

Funções:

- Govern;
- Identify;
- Protect;
- Detect;
- Respond;
- Recover.

Exemplo de mapeamento conceitual:

```text
Govern
  -> policy / risk / approvals / accountability

Identify
  -> CMDB / assets / dependencies / risk / attack surface

Protect
  -> least privilege / segmentation / hardening / controls

Detect
  -> telemetry / detection engineering / SOC

Respond
  -> incident state machine / approvals / containment

Recover
  -> backup / restore / RPO / RTO / validation
```

O mapeamento deve apontar evidências, não apenas nomes de componentes.

---

# Relação com a arquitetura TARGET

A evolução de segurança não cria um novo cérebro paralelo.

Ela complementa o desenho já documentado:

```text
                      MÍMIR
                        |
             +----------+----------+
             |                     |
      Capability Router         Risk Engine
             |                     |
             +----------+----------+
                        |
                   Policy Engine
                        |
              Zero-Trust Decision
                        |
        +---------------+---------------+
        |               |               |
      Agent            Tool           Engine
        |               |               |
        +---------------+---------------+
                        |
                     Evidence
                        |
                 Control Assurance
                        |
               Audit / SOC / Memory
```

### Responsabilidades

- Capability Router: qual capacidade é necessária;
- Risk Engine: qual risco/contexto está associado;
- Policy Engine: o que é permitido;
- Engine Registry: quais engines estão disponíveis;
- Control Assurance: quais controles são comprovadamente efetivos;
- Evidence/Audit: o que sustenta a decisão;
- SOC: detecção e investigação;
- Memory: preservação governada do conhecimento aprovado.

---

# Relação com documentos existentes

Este roadmap complementa:

- `SECURITY.md`;
- `ARCHITECTURE.md`;
- `ROADMAP.md`;
- `OPERATIONS.md`;
- `MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`;
- `AGENT_SPECIALIZATION_MCP_A2A_ROADMAP.md`;
- `MEMORY_V2_ROADMAP.md`;
- `GATEWAY_PCIA_MIGRATION_PLAN.md`.

Não substitui nenhum deles.

---

# Ordem sugerida

Após v1 e conforme prioridade operacional:

1. S1 — AI Asset & Data Flow Registry;
2. S6 — Evidence-Grade Audit;
3. S5 — Security Control Assurance;
4. S2 — Zero-Trust Authorization Context;
5. S3 — Risk Engine;
6. S4 — Attack Surface & Drift Registry;
7. S11 — Vulnerability Management Loop;
8. S9 — RPO/RTO e Recovery Assurance;
9. S8 — Incident Response State Machine;
10. S7 — Detection Engineering / ATT&CK;
11. S12 — CSF 2.0 coverage mapping;
12. S10 — maturity and continuous improvement.

A ordem pode mudar por evidência operacional.

---

# Critérios de adoção

Cada melhoria deve seguir os estados já usados no projeto:

- **IMPLEMENTAR AGORA**;
- **PREPARAR INTERFACE**;
- **WATCHLIST**;
- **DESCARTAR / NÃO ADOTAR**.

Nenhum componente entra em runtime apenas porque aparece neste roadmap.

Antes de implementação:

1. definir problema;
2. registrar baseline;
3. definir risco;
4. identificar consumidor;
5. definir evidência esperada;
6. testar em ambiente controlado;
7. medir resultado;
8. documentar rollback;
9. validar segurança;
10. atualizar STATUS apenas após comprovação.

---

# Critério de conclusão desta evolução

A trilha de security governance/assurance estará consolidada quando:

- ativos de IA e fluxos de dados forem inventariados;
- autorização considerar contexto e expiração quando necessário;
- risco não for confundido com severidade isolada;
- superfície de ataque tiver estado esperado/observado;
- controles possuírem evidência de efetividade;
- auditoria permitir reconstrução das decisões;
- vulnerabilidades exigirem validação pós-correção;
- detecções forem orientadas a comportamento e contexto;
- resposta a incidentes possuir workflow testado;
- RPO/RTO forem definidos e testados;
- cobertura CSF puder ser demonstrada por evidência;
- maturidade for medida por critérios, não por quantidade de ferramentas.

## Princípio final

O objetivo não é transformar o Mímir em um conjunto maior de ferramentas de segurança.

O objetivo é fazer com que decisões, controles, acessos, detecções e recuperações sejam:

- contextualizados;
- autorizados;
- mensuráveis;
- verificáveis;
- rastreáveis;
- recuperáveis;
- sustentados por evidência.


---

# Projeto consumidor futuro — Mímir Field Assessment / SOC-OSINT

Queue ID:

`MIMIR-FIELD-ASSESSMENT-01`

Documento:

- [FIELD_ASSESSMENT_SOC_OSINT_ROADMAP.md](FIELD_ASSESSMENT_SOC_OSINT_ROADMAP.md)

Status:

**FILA / NÃO IMPLEMENTADO**

O Field Assessment é um consumidor futuro das capacidades definidas neste roadmap, especialmente:

- Risk Engine;
- Zero-Trust Authorization Context;
- Attack Surface & Drift;
- Security Control Assurance;
- Evidence-Grade Audit;
- Vulnerability Management;
- Detection Engineering;
- Incident Response;
- RPO/RTO;
- NIST CSF 2.0 coverage.

A primeira fase deverá ser READ-ONLY e baseada em evidência.

Intervenções futuras deverão ocorrer exclusivamente por catálogo fechado, com PLAN, PREPARE, APPROVAL, EXECUTE e VALIDATE.

O projeto inclui diagnóstico técnico de host e rede, inclusive Windows Event Logs, integridade, saúde de hardware e análise TCP/NIC.

Controle gráfico genérico de desktop continua fora do escopo inicial.
