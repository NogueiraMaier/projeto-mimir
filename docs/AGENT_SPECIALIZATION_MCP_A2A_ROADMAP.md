# Agentes Especialistas, MCP e A2A — Roadmap de evolução

Status: **PLANEJADO / ADOTAR SOMENTE QUANDO NECESSÁRIO**

Objetivo: registrar como o Projeto Mímir deve evoluir para agentes especialistas, ferramentas padronizadas e eventual comunicação entre agentes, sem adicionar complexidade antes de existir necessidade técnica comprovada.

Referência inicial:

- https://dev.to/halfjust/agentes-de-ia-sabem-trabalhar-em-equipe-com-mcp-e-a2a-sim-4dp1

## Princípio principal

A evolução arquitetural do Mímir deve ser **necessidade dirigida**, não tecnologia dirigida.

Nenhum componente novo deve ser adotado apenas porque existe ou porque é moderno.

Antes de introduzir:

- MCP;
- A2A;
- novos serviços;
- novos runtimes;
- fine-tuning;
- novos bancos;
- novos modelos;
- novos protocolos;

deve existir um problema concreto que a arquitetura atual não resolve de forma satisfatória.

Critério geral:

`problema observado -> medir -> tentar solução simples -> comparar -> adotar somente se melhorar`

Se a solução atual atender com segurança, auditabilidade, desempenho e manutenção aceitáveis, ela deve permanecer.

## 1. Como um agente se torna especialista

O Mímir não deve tratar especialização como sinônimo de treinar um novo modelo.

Especialização deve ser formada pela combinação:

`modelo base + identidade + conhecimento + memória + ferramentas + runbooks + políticas + avaliação`

### Componentes

#### Identidade e função

Cada agente deve declarar:

- domínio;
- responsabilidades;
- limites;
- operações proibidas;
- escalonamento;
- quando deve responder `não sei`.

#### Knowledge base especializada

Conhecimento por:

- fabricante;
- produto;
- versão;
- protocolo;
- tecnologia;
- tipo de operação.

Exemplo MikroTik:

- RouterOS;
- firewall;
- routing;
- WireGuard;
- VLAN;
- QoS;
- API;
- SSH;
- modelos específicos.

Cada fonte deve carregar, quando aplicável:

- vendor;
- produto;
- versão;
- assunto;
- origem;
- data;
- validade;
- confiança;
- evidência.

#### Memória operacional

O agente deve recuperar:

- estado atual do cliente/site/device;
- histórico de alterações;
- decisões anteriores;
- incidentes;
- validações;
- procedimentos já aprovados;
- erros recorrentes.

#### Ferramentas

O agente especialista não deve depender de shell arbitrário como mecanismo principal.

Ferramentas devem ser explícitas, auditáveis e limitadas por política.

#### Runbooks

Procedimentos validados devem registrar:

- pré-condições;
- operação;
- risco;
- backup;
- rollback;
- validação;
- compatibilidade de versão.

## 2. Hierarquia de confiança do conhecimento

Ordem recomendada:

1. documentação oficial do fabricante;
2. runbook interno validado;
3. configuração previamente validada no próprio cliente;
4. documentação técnica externa confiável;
5. fórum/comunidade;
6. inferência do LLM.

Operações críticas não devem ser executadas com base exclusiva no nível 6.

## 3. Fine-tuning não é requisito inicial

O Mímir deve começar com:

- retrieval;
- memória;
- runbooks;
- ferramentas;
- testes;
- contexto especializado.

Fine-tuning, distillation ou treinamento específico somente entram quando benchmark mostrar vantagem real em:

- precisão;
- latência;
- custo;
- especialização;
- robustez.

## 4. Fluxo de uma operação real

Exemplo: configurar VLAN em MikroTik.

`usuário -> Mímir -> classificação -> agente especialista -> READ -> PLAN -> aprovação -> SNAPSHOT/BACKUP -> EXECUTE -> VALIDATE -> relatório -> inventário/memória`

### Regra estrutural

- LLM decide **o que** precisa ser feito;
- adapter decide **como** executar;
- policy decide **se** pode executar.

Sempre que possível, o LLM deve gerar intenção estruturada, não comandos livres.

Exemplo conceitual:

```json
{
  "operation": "create_vlan",
  "vlan_id": 30,
  "name": "CAMERAS",
  "target": "bridge"
}
```

O adapter transforma isso em operações válidas para o equipamento e versão correspondente.

## 5. MCP — papel no Mímir

MCP deve ser tratado como **interface padronizada de ferramentas**, não como cérebro do agente.

### Pode ser útil para

- inventory.read;
- memory.search;
- memory.retrieve;
- mikrotik.inspect;
- mikrotik.snapshot;
- mikrotik.plan;
- mikrotik.execute;
- mikrotik.validate;
- mikrotik.rollback.

### Arquitetura preferida

`agente -> Mímir Ops MCP -> adapter -> transporte -> equipamento`

Não criar um MCP por equipamento.

Preferir um único serviço/fachada operacional com adapters por classe de dispositivo.

Exemplo:

- MikroTik adapter;
- Linux adapter;
- FiberHome adapter;
- H3C adapter.

O dispositivo real vem do CMDB.

### MCP não é obrigatório

Se:

`agente -> módulo Python -> mimir_ops -> adapter`

já resolver com segurança e manutenção aceitável, MCP pode esperar.

Adotar MCP quando houver benefício claro, como:

- múltiplos clientes usando a mesma ferramenta;
- OpenClaw, Codex, Claude Code ou outros consumidores;
- necessidade de contrato de ferramentas estável;
- necessidade de interoperabilidade.

## 6. Transporte para MikroTik

A primeira versão pode continuar priorizando:

- SSH;
- chave pública;
- StrictHostKeyChecking;
- known_hosts;
- usuário de privilégio mínimo;
- timeout;
- audit log;
- redaction.

Outros transportes podem ser adicionados depois:

- RouterOS API;
- API-SSL;
- REST/HTTPS.

A escolha deve ser feita por necessidade, compatibilidade e segurança.

## 7. A2A — quando usar

A2A deve ser tratado como protocolo para comunicação entre **agentes independentes**.

Não é necessário apenas porque existem vários agentes lógicos dentro do mesmo Mímir.

### Inicialmente

Preferir orquestração interna simples:

- Mímir;
- agente Redes;
- agente SOC;
- agente OSINT;
- agente Desenvolvimento;
- agente Operações;
- agente Negócios.

### Introduzir A2A somente se houver

- agentes em processos independentes;
- agentes em máquinas diferentes;
- agentes em frameworks diferentes;
- agentes de terceiros;
- necessidade de descoberta dinâmica;
- necessidade de delegação padronizada externa.

## 8. Agente especialista MikroTik — desenho inicial

Exemplo conceitual:

```yaml
agent: network-mikrotik

domain:
  - RouterOS
  - switching
  - routing
  - firewall
  - WireGuard
  - VLAN
  - QoS

knowledge:
  - mikrotik-official
  - maier-runbooks
  - client-memory
  - device-history

tools:
  - inventory.read
  - memory.search
  - mikrotik.read
  - mikrotik.plan
  - mikrotik.snapshot
  - mikrotik.execute
  - mikrotik.validate

execution:
  READ: automatic
  PLAN: automatic
  EXECUTE: human-approval

prohibited:
  - arbitrary-shell
  - expose-credentials
  - factory-reset
  - disable-management
```

## 9. Testes obrigatórios do especialista

Antes de permitir produção:

- criar VLAN sem perder gerenciamento;
- configurar WireGuard;
- adicionar regra de firewall;
- detectar incompatibilidade de versão;
- recusar execução sem pré-condições;
- recusar operação proibida;
- produzir rollback;
- validar resultado;
- responder `não sei` quando não houver evidência;
- não inventar comandos;
- não revelar credenciais.

## 10. Integração com Memory v2

A evolução dos agentes especialistas depende da memória procedural.

O Mímir deve saber não apenas:

- qual equipamento o cliente possui;

mas também:

- qual procedimento validado é aplicável;
- em qual versão;
- com quais pré-condições;
- qual rollback;
- quais validações;
- qual evidência sustentou a decisão.

Portanto, Memory v2 deve contemplar memória procedural versionada e ligada a:

- vendor;
- model;
- firmware;
- device;
- site;
- client;
- intervention;
- evidence.

## 11. Critério para adotar MCP

Adotar MCP se pelo menos um destes problemas aparecer:

- duplicação de integrações;
- múltiplos consumidores precisam das mesmas ferramentas;
- acoplamento forte ao OpenClaw;
- necessidade de contrato estável de tools;
- necessidade de interoperabilidade externa.

Caso contrário, manter chamada direta ao módulo operacional.

## 12. Critério para adotar A2A

Adotar A2A somente quando existir fronteira real entre agentes independentes.

Não adotar para agentes internos apenas por tendência tecnológica.

## 13. Critério para criar novo agente especialista

Criar agente separado quando houver:

- domínio próprio;
- conhecimento específico relevante;
- ferramentas próprias;
- políticas próprias;
- volume suficiente de tarefas;
- necessidade clara de isolamento.

Se essas condições não existirem, manter a função dentro de um agente mais amplo.

## 14. Regra de evolução do projeto

Toda evolução deve passar por:

1. problema real;
2. evidência;
3. baseline;
4. alternativa simples;
5. benchmark;
6. avaliação de risco;
7. teste;
8. decisão documentada.

Tecnologia sem problema associado permanece **PLANEJADA**, não implementada.

## 15. Ordem sugerida

1. concluir fundação operacional;
2. validar adapters atuais;
3. estruturar knowledge base e memória procedural;
4. criar agente Redes/MikroTik em modo READ/PLAN;
5. validar benchmark e segurança;
6. habilitar EXECUTE controlado;
7. avaliar MCP somente se houver ganho;
8. ampliar outros especialistas;
9. avaliar A2A somente quando agentes realmente se tornarem independentes.

## Princípio final

O objetivo do Mímir não é possuir o maior número de agentes, protocolos ou serviços.

O objetivo é executar tarefas com:

- precisão;
- segurança;
- auditabilidade;
- memória;
- rastreabilidade;
- baixo acoplamento;
- manutenção viável.

A arquitetura deve crescer apenas quando o funcionamento real justificar a complexidade adicional.
