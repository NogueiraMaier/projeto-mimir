# Mímir Field Assessment / SOC-OSINT Roadmap

Status: **FILA / PLANEJADO / NÃO IMPLEMENTADO**  
Queue ID: `MIMIR-FIELD-ASSESSMENT-01`  
Escopo: kit de avaliação técnica de campo, OSINT, SOC, diagnóstico de host/rede, NIST CSF 2.0, evidências, risco, relatório e remediação controlada.

Este documento registra o projeto futuro de uma ferramenta portátil de avaliação assistida pelo Mímir.

Ele **não altera o NEXT_ACTION atual**, não amplia permissões do agente `main`, não autoriza execução em equipamento real e não modifica a v1 corrente.

## 1. Objetivo

Criar um fluxo no qual o operador possa:

1. conectar um pendrive/Field Probe autorizado ao equipamento sob avaliação;
2. iniciar uma sessão controlada;
3. estabelecer túnel WireGuard efêmero;
4. registrar a sessão de assessment;
5. abrir o HUD do Mímir;
6. conversar com o Mímir durante a avaliação;
7. executar coleta inicial automática e não destrutiva;
8. analisar host, rede, logs, exposição e controles;
9. executar OSINT externo autorizado;
10. correlacionar evidências em fluxo SOC;
11. mapear resultados ao NIST CSF 2.0;
12. gerar checklist de enquadramento;
13. registrar findings, riscos, evidências e recomendações no sistema;
14. gerar relatório técnico e executivo;
15. permitir intervenções apenas mediante catálogo, política e autorização.

O produto não deve ser tratado como um simples scanner nem como um shell remoto para a IA.

---

# 2. Topologia conceitual

```text
CLIENTE / AMBIENTE AUTORIZADO
           |
     conecta Field Probe
           |
           v
     Mímir Field Probe
           |
   WireGuard efêmero
           |
           v
      VPS / WG Hub
           |
     túnel restrito
           |
           v
    PcIA / Mímir Gateway
           |
   +-------+---------+
   |       |         |
  HUD    OSINT      SOC
   |       |         |
   +-------+---------+
           |
      Evidence Engine
           |
   +-------+---------+
   |                 |
Risk Engine      NIST CSF Mapper
   |                 |
   +--------+--------+
            |
      Assessment Engine
            |
   sistema / banco / relatório
```

A VPS atua como concentrador/relay WireGuard e infraestrutura de acesso controlado.

O PcIA continua sendo o nó de inteligência previsto na arquitetura alvo.

O Field Probe não deve expor diretamente o PcIA à Internet.

---

# 3. Identidade e ciclo da sessão

Cada assessment deve possuir identidade própria.

Campos candidatos:

- `assessment_id`;
- `client_id`;
- `site_id`;
- `operator_id`;
- `probe_id`;
- `host_id`;
- `wg_public_key`;
- `created_at`;
- `expires_at`;
- `scope`;
- `authorization_ref`;
- `status`.

A chave WireGuard do Field Probe deve ser:

- específica da sessão ou do probe;
- revogável;
- não administrativa;
- limitada ao necessário;
- removível após encerramento.

Nunca colocar no pendrive chave administrativa permanente do Mímir, VPS ou infraestrutura do cliente.

---

# 4. Experiência operacional

Fluxo desejado:

```text
CONNECT PROBE
   |
VERIFY INTEGRITY
   |
CREATE ASSESSMENT
   |
WIREGUARD CONNECT
   |
REGISTER SESSION
   |
OPEN HUD
   |
PASSIVE BASELINE
   |
SECURITY POSTURE
   |
OSINT / SOC
   |
RISK + NIST
   |
REPORT / FINDINGS
```

O HUD deve mostrar, no mínimo:

- assessment;
- cliente/site;
- host;
- modo atual;
- túnel;
- estado da coleta;
- risco;
- ações pendentes;
- autorizações;
- evidências;
- relatório.

Estados candidatos:

- `INIT`;
- `CONNECTED`;
- `READ_ONLY`;
- `COLLECTING`;
- `ANALYZING`;
- `PLAN_READY`;
- `WAITING_APPROVAL`;
- `EXECUTING`;
- `VALIDATING`;
- `COMPLETED`;
- `DEGRADED`;
- `ABORTED`.

---

# 5. Princípio de catálogo fechado

O Field Probe não deve fornecer:

`arbitrary shell`

como capacidade primária do Mímir.

Operações devem existir em catálogo versionado com:

- operation id;
- platform;
- preconditions;
- risk class;
- required evidence;
- approval policy;
- timeout;
- backup requirement;
- rollback requirement;
- validation;
- allowed targets;
- supported versions.

Fluxo:

```text
OBSERVE
  |
DIAGNOSE
  |
PLAN
  |
PREPARE
  |
APPROVE
  |
EXECUTE
  |
VALIDATE
  |
EVIDENCE
```

---

# 6. Classes de operação

## READ

Pode incluir, conforme escopo:

- inventário;
- sistema operacional;
- hardware;
- saúde;
- rede;
- serviços;
- processos;
- logs;
- configurações sanitizadas;
- segurança;
- updates;
- portas;
- estado de controles.

READ não significa acesso irrestrito ao sistema de arquivos.

## EXECUTE controlado

Operações futuras candidatas:

- `install`;
- `delete`;
- `patch`;
- `disable`;
- `change_firewall`;
- `kill_process`.

Esses verbos genéricos não serão expostos diretamente.

Devem virar operações específicas, por exemplo:

- `host.package.install`;
- `host.package.patch`;
- `host.file.quarantine`;
- `host.file.delete`;
- `host.service.disable`;
- `host.process.kill`;
- `network.firewall.add`;
- `network.firewall.remove`.

---

# 7. Classificação inicial de risco das intervenções

| Operação | Classe inicial | Requisitos mínimos |
|---|---|---|
| package install | HIGH | origem confiável, compatibilidade, rollback quando aplicável |
| patch | HIGH | build compatível, backup/snapshot, validação |
| file quarantine | HIGH | hash/evidência, destino controlado |
| file delete | CRITICAL | alvo explícito, evidência, confirmação |
| service disable | HIGH | dependências, impacto, recuperação |
| process kill | HIGH | árvore/processo validado, evidência |
| firewall change | CRITICAL | diff, recovery path, rollback, pós-teste |

A classificação final deve considerar também:

- criticidade do ativo;
- contexto;
- dependências;
- impacto;
- janela;
- risco residual.

---

# 8. Autorização temporária

O projeto deve suportar, futuramente, autorização por:

- operação;
- host;
- cliente;
- sessão;
- tempo;
- quantidade;
- risco.

Exemplo conceitual:

```text
assessment = ACME-2026-0041
host = SRV-01
permission = windows.patch
valid_until = 11:00
max_actions = 2
approval_required = true
rollback_required = true
```

Permissão temporária expirada deve voltar automaticamente para deny.

---

# 9. Quarentena antes de exclusão

Para conteúdo suspeito, preferir:

```text
detect
 |
collect evidence
 |
hash
 |
quarantine
 |
validate
 |
delete only if authorized
```

Não destruir evidência antes da coleta quando isso puder prejudicar investigação.

---

# 10. Processo suspeito

Fluxo candidato:

```text
process observed
   |
process tree
   |
network connections
   |
executable path
   |
hash
   |
related logs
   |
risk
   |
containment plan
   |
approval
   |
kill if authorized
   |
validate
```

---

# 11. Firewall

Mudanças de firewall exigem proteção adicional.

Fluxo candidato:

```text
current rules
   |
sanitized export / snapshot
   |
hash
   |
management path validation
   |
candidate diff
   |
rollback prepared
   |
approval
   |
apply
   |
connectivity validation
   |
commit
```

Abortar se:

- não existir recovery path;
- WireGuard puder ser perdido sem alternativa;
- regra atual não puder ser reconstruída;
- impacto não estiver entendido.

---

# 12. Platform Fingerprint

Antes de diagnóstico específico, identificar a plataforma.

Para Windows:

- product name;
- edition;
- version;
- build;
- architecture;
- patch level;
- roles/features;
- domain role;
- PowerShell version;
- drivers relevantes;
- security products;
- hardware.

Receitas de correção devem declarar compatibilidade explícita.

Não aplicar receita apenas porque o sistema pertence à mesma família geral.

---

# 13. Catálogo de saúde

## Storage

Operações READ candidatas:

- `health.storage.inventory`;
- `health.storage.smart`;
- `health.storage.nvme`;
- `health.storage.temperature`;
- `health.storage.filesystem`;
- `health.storage.performance`.

Evidências possíveis:

- modelo;
- firmware;
- power-on hours;
- reallocated sectors;
- pending sectors;
- uncorrectable;
- NVMe percentage used;
- media errors;
- critical warning;
- temperatura;
- espaço;
- I/O latency.

## Memory

- total;
- available;
- commit;
- pagefile;
- hard faults;
- pressure;
- WHEA/ECC quando disponível;
- processos consumidores.

Testes que exigem reboot devem ser tratados como EXECUTE/maintenance, não READ.

## CPU

- uso;
- load/queue;
- temperatura quando disponível;
- throttling;
- WHEA;
- clock;
- erros relevantes.

## GPU

- modelo;
- driver;
- VRAM;
- temperatura;
- uso;
- erros do driver/runtime.

---

# 14. Windows Event Analysis

Criar família:

`windows.events.*`

Fontes candidatas:

- System;
- Application;
- Security, quando autorizado;
- Setup;
- Windows Defender;
- Windows Update;
- WHEA;
- Kernel-Power;
- Service Control Manager;
- Disk;
- Ntfs;
- StorNVMe;
- DNS Client;
- GroupPolicy;
- Schannel;
- TerminalServices.

O collector deve:

1. limitar janela temporal;
2. filtrar fontes relevantes;
3. normalizar eventos;
4. correlacionar timestamps;
5. deduplicar;
6. preservar IDs;
7. produzir Evidence Pack.

Não enviar logs completos ao LLM sem necessidade.

---

# 15. Investigação de reboot/crash

Perguntas típicas:

- reboot planejado?;
- update?;
- crash?;
- hardware?;
- storage?;
- driver?;
- serviço?;
- energia?;
- intervenção administrativa?

Correlacionar:

- Kernel-Power;
- BugCheck;
- WHEA;
- Windows Update;
- EventLog;
- Service Control Manager;
- storage;
- driver events.

---

# 16. BSOD e Windows Error Reporting

Criar:

- `windows.crash.inspect`;
- `windows.wer.inspect`;
- `windows.minidump.metadata`.

Fase inicial:

- metadados;
- BugCheck;
- drivers;
- patches recentes;
- WHEA;
- storage;
- correlação temporal.

Debug avançado pode futuramente usar ferramenta isolada, com processo separado de validação.

---

# 17. Windows Integrity

READ/diagnóstico:

- `windows.integrity.sfc_verify`;
- `windows.integrity.dism_checkhealth`;
- `windows.integrity.dism_scanhealth`;
- `windows.integrity.component_store`.

EXECUTE/remediação:

- `windows.integrity.sfc_repair`;
- `windows.integrity.dism_restorehealth`.

Diagnóstico e reparo devem permanecer operações distintas.

---

# 18. Windows Update e bugs conhecidos

Coletar:

- KBs instaladas;
- falhas;
- histórico;
- pending reboot;
- component store;
- update services;
- build.

Criar catálogo futuro de `remediation recipes`.

Cada recipe deve declarar:

- `recipe_id`;
- plataforma;
- build;
- sintomas;
- checks;
- causa conhecida;
- remediação;
- rollback;
- reboot;
- risco;
- evidência;
- validação.

Só disponibilizar recipe quando precondições forem satisfeitas.

---

# 19. Base operacional de correções validadas

O sistema poderá acumular experiência operacional validada.

Modelo:

```text
SYMPTOM
  |
EVIDENCE
  |
ROOT CAUSE
  |
REMEDIATION
  |
VALIDATION
  |
SUPPORTED ENVIRONMENTS
```

Uma correção bem-sucedida em um host não se torna regra universal.

Reuso exige compatibilidade de:

- OS;
- build;
- role;
- software;
- sintomas;
- evidências;
- precondições.

---

# 20. Services

READ:

- `windows.service.list`;
- `windows.service.inspect`;
- `windows.service.dependencies`;
- `windows.service.failure_history`.

EXECUTE:

- `windows.service.restart`;
- `windows.service.stop`;
- `windows.service.disable`;
- `windows.service.start`.

O risco depende do ativo e da dependência, não apenas do verbo.

---

# 21. Windows Security Posture

READ candidato:

- Defender status;
- engine/signatures;
- real-time protection;
- detections;
- quarantine;
- exclusions com tratamento sensível;
- firewall profiles;
- BitLocker;
- Secure Boot;
- TPM;
- RDP;
- SMB;
- PowerShell logging;
- audit policy;
- local admins;
- domain membership.

---

# 22. Active Directory

Quando `domain_role` indicar DC ou função relacionada, habilitar catálogo específico:

- `ad.health`;
- `ad.replication`;
- `ad.dns`;
- `ad.time`;
- `ad.sysvol`;
- `ad.netlogon`;
- `ad.events`;
- `ad.privileged_groups`.

Não executar operações AD de escrita na primeira fase.

---

# 23. Diagnóstico de rede Windows

Criar família:

`windows.network.*`

Submódulos:

- interfaces;
- routes;
- ARP/neighbor;
- DNS;
- connections;
- listening ports;
- firewall;
- TCP parameters;
- NIC driver;
- errors;
- MTU;
- offloads;
- performance.

---

# 24. Portas efêmeras / dynamic ports

Criar:

- `windows.network.tcp.dynamic_ports`;
- `windows.network.tcp.connections`;
- `windows.network.tcp.timewait`.

Coletar:

- range IPv4 TCP;
- range IPv6 TCP;
- ESTABLISHED;
- TIME_WAIT;
- CLOSE_WAIT;
- SYN_SENT;
- LISTEN;
- taxa de novas conexões quando possível.

Não assumir exaustão apenas por TIME_WAIT alto.

Analisar:

- tamanho do range;
- churn;
- aplicação;
- pooling;
- erros de socket;
- destinos recorrentes;
- resets;
- carga.

---

# 25. TCP Receive Auto-Tuning

Criar:

`windows.network.tcp.autotuning`

Coletar estado efetivo e relacionar com:

- build;
- template;
- workload;
- throughput;
- latência;
- perda.

Não alterar automaticamente.

---

# 26. Congestion Control

Criar:

`windows.network.tcp.congestion`

Inspecionar templates e providers efetivos.

Registrar, quando presentes:

- Internet;
- Datacenter;
- Compat;
- InternetCustom;
- DatacenterCustom;
- provider ativo.

Mudança de congestion control exige baseline e pós-teste.

---

# 27. Algoritmo de Nagle e ACK

Criar:

- `windows.network.tcp.nagle`;
- `windows.network.tcp.ack_behavior`;
- `windows.network.tcp.registry_overrides`.

Investigar:

- `TcpNoDelay`;
- `TcpAckFrequency`;
- `TcpDelAckTicks`;
- outros overrides compatíveis com a plataforma.

Regra:

configuração de Registry não é evidência suficiente do comportamento de todos os sockets.

Aplicações podem usar opções próprias como `TCP_NODELAY`.

O diagnóstico deve distinguir:

`OS configuration`

de:

`application socket behavior`.

Não implementar regra universal de “desabilitar Nagle”.

Só considerar ajuste quando existirem:

- aplicação sensível à latência;
- padrão de pequenos segmentos;
- evidência de atraso;
- baseline;
- compatibilidade da plataforma;
- possibilidade de rollback.

---

# 28. MTU / PMTU

Criar:

- `windows.network.mtu`;
- `windows.network.pmtu`.

Considerar:

- Ethernet;
- PPPoE;
- VPN;
- WireGuard;
- túneis;
- fragmentação;
- ICMP relevante.

Testes ativos devem ser explicitamente autorizados.

---

# 29. Retransmissões TCP

Criar:

`windows.network.tcp.retransmissions`

Correlacionar:

- retransmissões;
- connection failures;
- resets;
- interface;
- perda;
- driver;
- link;
- VPN;
- Wi-Fi;
- congestionamento.

Não atribuir throughput baixo ao TCP stack antes de excluir problemas inferiores.

---

# 30. NIC / Offloads

Criar:

`windows.network.nic.*`

Inspecionar:

- speed;
- duplex;
- RSS;
- RSC;
- LSO;
- checksum offload;
- interrupt moderation;
- flow control;
- driver;
- date/version;
- errors;
- drops.

---

# 31. DNS

Criar:

`windows.network.dns.*`

Coletar:

- servidores;
- suffixes;
- cache;
- resolução;
- timeouts;
- eventos.

Testes candidatos:

- hostname local;
- gateway;
- DNS interno;
- DNS externo autorizado;
- serviço crítico definido no escopo.

---

# 32. Camadas de diagnóstico de rede

Seguir, sempre que aplicável:

```text
L1 / hardware
  |
NIC / driver / link
  |
L2 / VLAN / ARP
  |
L3 / IP / route / MTU
  |
L4 / TCP / UDP / ports
  |
DNS
  |
TLS
  |
Application
```

Evitar alterar parâmetros TCP antes de excluir falha de camada inferior.

---

# 33. Network Baseline

Na primeira avaliação, registrar baseline.

Campos candidatos:

- NIC;
- driver;
- speed/duplex;
- MTU;
- gateway latency;
- DNS latency;
- RTT externo autorizado;
- packet loss;
- TCP autotuning;
- congestion provider;
- dynamic port range;
- TIME_WAIT;
- retransmission;
- RSS/RSC;
- firewall state.

Avaliações futuras podem detectar drift.

---

# 34. Network Remediation Catalog

Operações futuras candidatas:

- `tcp.autotuning.change`;
- `tcp.congestion.change`;
- `tcp.dynamic_port_range.change`;
- `tcp.nagle.override`;
- `tcp.ack_frequency.change`;
- `winsock.reset`;
- `dns.flush`;
- `nic.restart`;
- `rss.enable`;
- `rsc.enable`;
- `offload.change`;
- `route.add`;
- `route.remove`;
- `mtu.change`;
- `firewall.change`.

Cada operação deve possuir:

- platform match;
- preconditions;
- risk;
- backup;
- rollback;
- reboot;
- approval;
- validation.

---

# 35. OSINT externo

OSINT deve ser distinguido de coleta interna.

Quando autorizado, pesquisar:

- domínio;
- DNS;
- MX;
- SPF;
- DKIM;
- DMARC;
- certificados;
- subdomínios;
- IPs públicos;
- ASN;
- serviços públicos;
- exposições conhecidas;
- vulnerabilidades públicas relacionadas.

A coleta externa deve respeitar o escopo formal do assessment.

---

# 36. SOC Analysis

Pipeline:

```text
EVENTS
  |
NORMALIZE
  |
CORRELATE
  |
DETECT
  |
ENRICH
  |
ATT&CK mapping
  |
ASSET CONTEXT
  |
RISK
  |
CASE
```

O objetivo não é produzir mais alertas.

Cada sinal deve possuir:

- fonte;
- contexto;
- evidência;
- confiança;
- asset;
- impacto potencial;
- ação recomendada.

---

# 37. NIST CSF 2.0

O assessment deve produzir mapeamento para:

- Govern;
- Identify;
- Protect;
- Detect;
- Respond;
- Recover.

O Mímir não deve tratar isso como certificação oficial.

O produto será uma:

`Avaliação / Enquadramento NIST CSF 2.0`

---

# 38. NIST checklist

Cada outcome/subcategory avaliada deve ter estado controlado.

Estados candidatos:

- `NOT_ASSESSED`;
- `NOT_APPLICABLE`;
- `NO_EVIDENCE`;
- `PARTIAL`;
- `IMPLEMENTED`;
- `VERIFIED`.

Campos:

- CSF ID;
- função;
- categoria;
- outcome;
- current status;
- target status;
- evidence;
- gap;
- priority;
- confidence;
- notes;
- owner;
- remediation reference.

Não usar apenas SIM/NÃO.

---

# 39. Evidência do enquadramento

Cada conclusão deve informar sua fonte.

Tipos:

- `AUTO`;
- `OBSERVED`;
- `DOCUMENT`;
- `INTERVIEW`;
- `MANUAL_VALIDATION`.

Exemplo conceitual:

```text
ID.AM

status:
PARTIAL

AUTO:
43 hosts observed

DOCUMENT:
38 hosts declared

GAP:
5 observed assets absent from inventory

confidence:
HIGH
```

---

# 40. Current Profile, Target Profile e Gap

Estrutura:

```text
CURRENT
  |
TARGET
  |
GAP
  |
ACTION PLAN
```

Percentuais ou scores só podem existir com metodologia própria documentada.

Não apresentar pontuação interna como score oficial NIST.

---

# 41. CSF Tiers

Pode ser considerado como referência de maturidade contextual:

- Tier 1 — Partial;
- Tier 2 — Risk Informed;
- Tier 3 — Repeatable;
- Tier 4 — Adaptive.

Não tratar Tier como certificação.

Atribuição deve exigir evidência suficiente.

---

# 42. Integração com o sistema

O resultado primário deve ser estruturado.

Modelo conceitual:

```text
CLIENT
  |
SITE
  |
ASSESSMENT
  |
ASSETS
  |
EVIDENCE
  |
FINDINGS
  |
RISKS
  |
NIST OUTCOMES
  |
RECOMMENDATIONS
  |
ACTIONS
  |
REPORT
```

Entidades candidatas:

### assessment

- id;
- client_id;
- site_id;
- operator;
- started_at;
- finished_at;
- scope;
- status;
- authorization_ref.

### asset

- id;
- assessment_id;
- type;
- hostname;
- ip;
- platform;
- criticality.

### evidence

- id;
- assessment_id;
- asset_id;
- collector;
- type;
- timestamp;
- hash;
- classification;
- storage_ref.

### finding

- id;
- asset_id;
- title;
- severity;
- risk;
- confidence;
- evidence refs;
- status.

### nist_assessment

- assessment_id;
- csf_id;
- status;
- current_profile;
- target_profile;
- gap;
- priority;
- evidence_count;
- confidence;
- notes.

---

# 43. Finding reutilizável

Modelo:

```text
Finding
  +-- symptom
  +-- platform fingerprint
  +-- evidence
  +-- probable cause
  +-- confidence
  +-- risk
  +-- recommended remediation
  +-- executed remediation
  +-- validation
  +-- rollback
  +-- outcome
```

Com o tempo, isso pode construir uma base operacional de conhecimento validado.

---

# 44. Relatório

Saídas candidatas:

- JSON estruturado;
- HTML;
- PDF.

Estrutura inicial:

1. identificação;
2. escopo/autorização;
3. sumário executivo;
4. metodologia;
5. inventário;
6. saúde de host;
7. rede/TCP;
8. superfície de ataque;
9. OSINT;
10. SOC/log analysis;
11. vulnerabilidades;
12. controles;
13. riscos;
14. NIST CSF Current Profile;
15. NIST CSF Target Profile;
16. Gap Analysis;
17. ATT&CK coverage quando aplicável;
18. recomendações;
19. ações executadas;
20. evidências;
21. limitações;
22. plano de ação.

---

# 45. Segurança e privacidade

Regras mínimas:

- escopo formal;
- autorização;
- mínimo privilégio;
- túnel revogável;
- segredos fora do Git;
- redaction;
- evidência protegida;
- classificação;
- logs de auditoria;
- expiração de permissões;
- nenhum provider externo sem política;
- nenhuma intervenção fora do catálogo.

---

# 46. Integração com o Risk Engine

Toda intervenção futura deve receber Risk Context.

```text
finding
  |
asset criticality
  |
exposure
  |
evidence
  |
current controls
  |
impact
  |
Risk Engine
  |
PLAN / PRIORITY
```

---

# 47. Integração com Control Assurance

Uma configuração observada não significa controle efetivo.

Exemplo:

```text
firewall enabled
    !=
firewall policy verified
```

O Field Assessment deve produzir evidências para os estados do Control Assurance.

---

# 48. Integração com Memory

Somente conclusões aprovadas devem virar memória permanente.

Fluxo:

```text
assessment evidence
  |
finding
  |
validated outcome
  |
memory candidate
  |
human review
  |
active
```

Nunca promover automaticamente log bruto ou hipótese.

---

# 49. Fora de escopo inicial

Ainda fora de escopo até discussão específica:

- controle gráfico genérico de desktop;
- mouse/teclado remoto autônomo;
- shell irrestrito;
- persistência oculta;
- execução sem autorização;
- exploração ofensiva não autorizada;
- alteração automática de firewall;
- exclusão automática de evidência;
- alteração AD de escrita;
- correção massiva em múltiplos hosts.

---

# 50. Fases de criação

## FA-0 — especificação

- schema do assessment;
- threat model;
- catálogo READ;
- wire protocol;
- WireGuard lifecycle;
- evidence format;
- NIST schema;
- report schema.

## FA-1 — Field Probe READ-ONLY

- launcher;
- integrity check;
- WireGuard;
- registration;
- HUD;
- platform fingerprint;
- host/network baseline;
- Windows logs;
- health;
- evidence upload.

## FA-2 — Assessment Engine

- asset normalization;
- findings;
- Risk Engine integration;
- attack surface;
- NIST mapping;
- checklist;
- report.

## FA-3 — OSINT/SOC

- external OSINT;
- event correlation;
- ATT&CK;
- detection cases.

## FA-4 — Remediation Catalog

- PLAN;
- PREPARE;
- APPROVAL;
- controlled EXECUTE;
- VALIDATE;
- rollback.

Começar por operações reversíveis e de baixo impacto.

## FA-5 — Operational Knowledge

- remediation recipes;
- environment compatibility;
- outcome tracking;
- reusable validated findings.

---

# 51. Dependências

Antes de iniciar implementação:

- v1 estabilizada;
- tool policy conhecida;
- identity/approval model consolidado;
- evidence/audit primitives estáveis;
- Risk Engine/interface definida;
- Control Assurance/interface definida;
- sistema de assessment com schema planejado;
- branch documental reconciliada com linha operacional.

---

# 52. Critérios para iniciar a fila

Esta fila só deve virar implementação quando houver decisão explícita.

Checklist de start:

- [ ] escopo aprovado;
- [ ] threat model;
- [ ] schema do assessment;
- [ ] modelo de autorização;
- [ ] WireGuard lifecycle;
- [ ] catálogo READ;
- [ ] evidência;
- [ ] NIST checklist schema;
- [ ] sistema de armazenamento;
- [ ] laboratório;
- [ ] plano de rollback;
- [ ] critérios de aceite.

---

# 53. Critério de MVP

O MVP não precisa executar correções.

MVP suficiente:

```text
pendrive
 -> WireGuard
 -> HUD
 -> READ inventory
 -> health
 -> Windows logs
 -> network/TCP assessment
 -> OSINT authorized
 -> findings
 -> risk
 -> NIST checklist
 -> structured storage
 -> HTML/PDF report
```

Remediação pode entrar depois.

---

# 54. Nota de fila

**QUEUE: MIMIR-FIELD-ASSESSMENT-01**

Status:

`READY FOR FUTURE DESIGN / NOT READY FOR IMPLEMENTATION`

Motivo:

A arquitetura funcional está suficientemente definida para não perder o conceito, mas o projeto depende de fechamento da v1, reconciliação documental, threat model, schemas e definição final das ferramentas.

Quando a fila for retomada, começar por `FA-0 — especificação`.

Não iniciar pelo código do pendrive.

---

# Princípio final

O Mímir Field Assessment deve transformar uma avaliação de campo em processo reproduzível:

```text
CONNECT
  |
OBSERVE
  |
COLLECT
  |
CORRELATE
  |
ASSESS
  |
RISK
  |
NIST
  |
PLAN
  |
APPROVE
  |
ACT when authorized
  |
VALIDATE
  |
EVIDENCE
  |
REPORT
  |
LEARN
```

O objetivo é fornecer diagnóstico, SOC/OSINT, enquadramento, evidência e remediação controlada sem transformar o Mímir em um agente com acesso irrestrito ao equipamento.
