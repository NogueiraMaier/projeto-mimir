# Mímir Security Assessment & SOC Coordinator

Status: evolução planejada, não implementada.

Data de registro: 2026-10-03.

## Objetivo

Evoluir o Mímir para coordenador defensivo de avaliação de segurança, OSINT autorizado, gestão de vulnerabilidades e análise SOC.

Mímir coordena ferramentas especializadas, correlaciona evidências e produz achados rastreáveis. Mímir não recebe shell arbitrário, alvo livre, credencial administrativa permanente ou autorização geral para varredura.

A capacidade deve respeitar as regras já existentes em `AGENTS.md`, `docs/SECURITY.md` e no módulo `docs/cybersecurity/`.

## Estado observado antes desta evolução

O repositório já prevê:

- agente SOC;
- agente OSINT;
- agente Cyber-Lab;
- análise defensiva de segurança;
- SOC e SIEM;
- navegador e OSINT isolados;
- governança de vulnerabilidades no macrocontrole MC-10.

Não foi localizada implementação operacional que componha essas capacidades como um coordenador único com catálogo de ferramentas, escopo autorizado, normalização de identidade de rede, enriquecimento CVE, correlação, modelo de findings, perfis de scan seguro e reteste.

Esta especificação preenche essa lacuna documental. Ela não declara implementação.

## Princípios de arquitetura

1. Mímir coordena. Ferramentas especializadas executam.
2. Deny by default para alvo, porta, protocolo, credencial e ação.
3. Todo alvo ativo deve existir no inventário e possuir autorização.
4. O agente recebe `asset_id`, não endereço arbitrário fornecido em texto livre.
5. O backend resolve endereço, tenant, escopo e política a partir do inventário confiável.
6. Toda avaliação gera `request_id`, `trace_id`, evidência e trilha de auditoria.
7. Observação, suspeita e confirmação são estados diferentes.
8. Banner, versão ou porta aberta não provam vulnerabilidade isoladamente.
9. Ações corretivas sensíveis exigem aprovação humana.
10. Reteste deve comprovar a correção antes do encerramento do finding.

## Componentes planejados

### 1. Security Assessment Orchestrator

Responsável por:

- receber objetivo de avaliação;
- resolver ativo e escopo;
- consultar política;
- selecionar ferramentas permitidas;
- impor orçamento de requisições;
- registrar execução;
- consolidar evidências;
- solicitar correlação;
- produzir finding;
- solicitar reteste.

Não executa shell arbitrário.

### 2. Security Scope Registry

Registro mínimo por ativo:

```text
asset_id
tenant_id
owner
assessment_allowed
passive_osint_allowed
active_scan_allowed
authenticated_scan_allowed
allowed_protocols
allowed_ports
max_rate
maintenance_window
approval_required
expires_at
```

Alvo fora do registro resulta em negação.

### 3. Tool Policy Engine

Decide se uma ferramenta pode ser chamada considerando:

- identidade do agente;
- tenant;
- ativo;
- tipo de teste;
- janela;
- protocolo;
- porta;
- intensidade;
- credencial;
- autorização humana;
- risco de indisponibilidade.

A política deve ser aplicada antes da chamada da ferramenta e novamente no executor.

### 4. Evidence Collector

Toda ferramenta devolve evidência estruturada, sem transformar inferência em fato.

Campos mínimos:

```text
evidence_id
assessment_id
asset_id
source
collector
collector_version
observed_at
raw_reference
sha256
sanitized_summary
confidence
request_id
trace_id
```

Payload bruto sensível não deve entrar na memória do Mímir.

### 5. Security Correlator

Correlaciona observações por:

- ativo;
- interface;
- endereço;
- serviço;
- usuário;
- sessão;
- request_id;
- trace_id;
- janela temporal;
- fingerprint;
- CVE;
- regra de detecção.

O correlator deve preservar as evidências individuais.

### 6. Finding Manager

Estados planejados:

```text
OBSERVED
SUSPECTED
CONFIRMED
MITIGATED
FALSE_POSITIVE
ACCEPTED_RISK
CLOSED
```

Campos mínimos:

```text
finding_id
tenant_id
asset_id
interface_id
title
category
severity
confidence
state
first_seen
last_seen
evidence_ids
cve_ids
cpe
cvss
kev
internet_exposed
business_criticality
compensating_controls
remediation
validation_required
owner
request_id
trace_id
```

Severidade e confiança são campos diferentes.

## Famílias de ferramentas

### OSINT autorizado

Ferramentas planejadas:

```text
security.osint.domain
security.osint.dns
security.osint.tls
security.osint.http
security.osint.services
security.osint.exposure
security.osint.cve_lookup
security.osint.kev_lookup
```

Fluxo:

```text
ativo autorizado
-> domínio/IP do inventário
-> exposição observada
-> produto/versão
-> CPE quando identificável
-> CVE
-> CVSS
-> KEV
-> evidência
-> finding
```

OSINT não autoriza teste ativo por consequência.

### Vulnerability Assessment

Perfis planejados:

```text
PASSIVE
SAFE_DISCOVERY
SAFE_TLS
SAFE_HTTP
SAFE_NETWORK
AUTHENTICATED_HOST
```

Cada perfil deve ter limites próprios de taxa, portas, timeout e efeitos permitidos.

Funções genéricas como `run_nmap(target, args)` não devem ser expostas ao agente.

Preferir funções restritas, por exemplo:

```text
security.scan.host_discovery(asset_id)
security.scan.tcp_services(asset_id)
security.scan.tls(asset_id)
security.scan.web_headers(asset_id)
security.scan.web_proxy_trust(asset_id)
security.scan.vulnerability_safe(asset_id)
```

### SOC

Fontes previstas:

- Zabbix;
- Grafana como visualização;
- syslog;
- Windows Event Log;
- Linux journal;
- MikroTik;
- firewall;
- IDS/IPS;
- Suricata;
- Zeek;
- Nginx ou proxy reverso;
- aplicações;
- OpenClaw;
- eventos do sistema-os quando a integração estiver autorizada.

Fluxo:

```text
evento
-> normalização
-> enriquecimento
-> correlação
-> regra de detecção
-> finding
-> ocorrência
-> investigação
-> recomendação
-> aprovação humana quando houver ação
```

## Identidade de rede canônica

Criar um modelo único para evitar que cada módulo interprete IP de forma diferente.

```text
SecurityNetworkIdentity
  peer_ip
  client_ip
  claimed_ip
  proxy_chain
  trusted_proxy
  source_port
  destination_ip
  destination_port
  protocol
  tls_fingerprint
  request_id
  session_id
  user_id
  device_id
```

Definições:

- `peer_ip`: endereço observado na conexão com o processo ou proxy.
- `claimed_ip`: endereço apresentado por header ou campo controlável externamente.
- `client_ip`: endereço resultante da política de proxies confiáveis.
- `proxy_chain`: cadeia interpretada após validação.
- `trusted_proxy`: indica se o hop que forneceu a informação está autorizado.

Nenhum `claimed_ip` deve substituir `peer_ip` sem validação da cadeia de confiança.

## Caso obrigatório: spoofing de IP por headers HTTP

Este cenário nasce da análise de 2026-10-03 e deve virar teste de segurança obrigatório.

Headers relevantes:

```text
X-Forwarded-For
Forwarded
X-Real-IP
CF-Connecting-IP
True-Client-IP
```

### security.web.proxy_trust_check

Objetivo:

Verificar se a aplicação aceita IP alegado pelo cliente sem validar o proxy anterior.

Teste controlado:

1. Manter o mesmo peer de rede.
2. Enviar requisição com um valor controlado em `X-Forwarded-For`.
3. Repetir com valor diferente.
4. Observar o endereço considerado pela aplicação.
5. Verificar se o hop anterior pertence à allow-list de proxies.
6. Registrar divergência entre `peer_ip`, `claimed_ip` e `client_ip`.

Finding sugerido:

```text
WEB.TRUSTED_PROXY.IP_SPOOFING
```

Condição de confirmação:

A aplicação altera sua identidade canônica de cliente em função de header não confiável.

### security.web.rate_limit_identity_check

Objetivo:

Verificar se o rate limit usa IP controlável pelo cliente.

Condição de finding:

O contador ou bucket muda quando somente o header de IP alegado é alterado, sem alteração válida da identidade de rede.

Finding sugerido:

```text
WEB.RATE_LIMIT.SPOOFABLE_CLIENT_IP
```

### security.web.audit_ip_integrity_check

Objetivo:

Verificar se a auditoria registra como IP confiável um valor controlável pelo cliente.

Comparar:

```text
peer_ip
claimed_ip
client_ip
audit_ip
```

Finding sugerido:

```text
AUDIT.NETWORK_IDENTITY.SPOOFABLE
```

### security.web.session_ip_semantics_check

Objetivo:

Verificar como IP participa da sessão.

O IP não deve ser tratado isoladamente como identidade forte de usuário. Mudanças de rede, CGNAT, IPv6 temporário, VPN e rede móvel devem ser consideradas.

O teste deve identificar uso indevido de IP em autenticação, autorização ou revogação.

## Correlação SOC para o ataque de IP alegado falso

Exemplo de sequência:

```text
mesmo peer_ip
mesma session_id
mesmo tls_fingerprint
mesmo user_agent
muitos claimed_ip diferentes
rate limiter tratando cada claimed_ip como origem distinta
```

Resultado planejado:

```text
SECURITY_OCCURRENCE.PROXY_HEADER_SPOOFING
```

O correlator deve anexar as evidências originais e indicar quais regras levaram à conclusão.

## Inteligência de vulnerabilidades

Fontes planejadas:

- NVD para CVE, CPE e métricas;
- CISA KEV para exploração conhecida;
- advisories oficiais dos fabricantes;
- inventário interno de software e firmware.

O Mímir não deve concluir que um ativo é vulnerável somente porque uma versão de banner corresponde a uma faixa vulnerável.

A confirmação deve considerar:

- versão observada;
- método de identificação;
- CPE;
- condição de exploração;
- exposição;
- compensações;
- evidência autenticada quando existir;
- advisories do fabricante.

## Priorização explicável

A prioridade não deve ser uma nota opaca.

Fatores:

```text
CVSS
KEV
internet_exposed
exploit_preconditions
asset_criticality
data_sensitivity
privilege_required
lateral_movement_potential
compensating_controls
confidence
```

O relatório deve mostrar os fatores usados.

## Integração planejada com sistema-os

Quando autorizada, a integração deve ocorrer por API dedicada. Mímir não recebe credencial direta do PostgreSQL do sistema-os.

Mapeamento conceitual:

```text
evidence -> asset_event
finding confirmado -> asset_occurrence ou finding de segurança
asset_id -> inventário do sistema-os
interface_id -> asset_interfaces
correlação -> occurrence_events
recomendação -> rascunho de ação
ação sensível -> approval gate
```

A origem, tenant e ativo vêm de identidade autenticada e inventário. Não inferir tenant a partir de IP, hostname, MAC ou header informado pelo cliente.

## Remediação

Mímir detecta, explica e recomenda.

Ações como estas exigem política e aprovação humana:

```text
patch
install
delete
disable
change_firewall
change_network
change_service
kill_process
rotate_credential
revoke_session
```

Fluxo:

```text
finding
-> proposta de remediação
-> aprovação humana
-> execução por executor restrito
-> validação
-> reteste
-> fechamento
```

O executor deve receber uma ação tipada e limitada. Nunca shell livre.

## Auditoria

Registrar no mínimo:

```text
assessment_id
tool
tool_version
policy_version
asset_id
tenant_id
requested_by
approved_by
started_at
finished_at
result
evidence_ids
finding_ids
request_id
trace_id
```

## Métricas operacionais

- cobertura de ativos;
- ativos sem avaliação;
- findings por estado;
- tempo até triagem;
- tempo até mitigação;
- taxa de falso positivo;
- findings reabertos;
- retestes pendentes;
- CVEs KEV sem tratamento;
- ferramentas bloqueadas por política;
- tentativas de avaliação fora do escopo.

## Fases propostas

### SA-0, especificação

Documentar arquitetura, schema, políticas, ferramentas e casos de teste.

### SA-1, observação passiva

Implementar OSINT passivo e ingestão SOC somente leitura.

### SA-2, enriquecimento

Integrar CPE, CVE, CVSS, KEV e advisories oficiais.

### SA-3, correlação

Implementar Security Correlator e ciclo de findings.

### SA-4, testes ativos seguros

Liberar somente perfis SAFE em Cyber-Lab e ativos explicitamente autorizados.

### SA-5, integração com sistema-os

Publicar evidências e findings por API, mantendo isolamento de credenciais e tenant.

### SA-6, remediação assistida

Produzir propostas tipadas, com aprovação humana e reteste obrigatório.

## Critérios mínimos antes de qualquer scan ativo

- ativo inventariado;
- proprietário identificado;
- autorização válida;
- escopo técnico;
- tenant resolvido;
- portas e protocolos permitidos;
- limite de taxa;
- janela;
- rollback quando aplicável;
- logging ativo;
- armazenamento de evidência preparado;
- contato de incidente;
- mecanismo de interrupção;
- aprovação adicional quando exigida.

## Fora do escopo desta evolução

- varredura indiscriminada da Internet;
- alvos informados livremente pelo modelo;
- exploração destrutiva;
- persistência em sistemas avaliados;
- evasão de controles;
- alteração automática de produção;
- credencial administrativa permanente no agente;
- encerramento automático de finding crítico sem validação.

## Resultado esperado

Mímir passa a ser o coordenador de uma cadeia defensiva:

```text
Detectar
-> Evidenciar
-> Normalizar
-> Enriquecer
-> Correlacionar
-> Diagnosticar
-> Priorizar
-> Recomendar
-> Aprovar
-> Corrigir
-> Retestar
-> Comprovar
```

A implementação somente deve ser declarada concluída após evidência operacional e testes correspondentes.
