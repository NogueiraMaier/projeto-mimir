# Mímir Business Platform
## Proposta de evolução para fábrica de atendentes virtuais humanizados

Data: 2026-10-03

Status: PARKED_FOR_FUTURE_ANALYSIS

Natureza: documento aditivo, não autoritativo, sem alteração do estado atual do Projeto Mímir

Identificador sugerido:

MIMIR-EVO-BUSINESS-PLATFORM-001

## 0. Decisão de governança registrada

Classificação:

`STRATEGIC_FUTURE_EVOLUTION`

Estado canônico desta evolução:

`PARKED / DOCUMENTED / NOT_IMPLEMENTED`

Prioridade de execução:

`AFTER MIMIR CORE`

Decisão arquitetural:

A **Mímir Business Platform** será tratada como camada/produto separado que consome contratos versionados do **Mímir Core**. Ela não cria um segundo núcleo de orquestração e não transforma o Core em CRM, frontend, licenciamento ou lógica comercial específica.

Regra padrão:

A implementação da Business Platform não deve ser antecipada enquanto o Mímir Core estiver em evolução funcional e de segurança.

Exceção controlada:

Um componente desta proposta pode ser antecipado somente quando for necessário ao próprio Mímir Core, for transversal e reutilizável, tiver gap comprovado no Core e passar pelo ciclo normal de arquitetura, segurança, implementação e validação. Essa antecipação não significa início da Business Platform.

Continuidade:

A criação de um índice em `docs/evolution/README.md` e de uma referência curta em `docs/MIMIR_HANDOFF.md` é exclusivamente uma exceção de **descoberta/continuidade** autorizada para que esta evolução não seja perdida entre sessões. Essas referências não ativam a proposta e não alteram o `NEXT_ACTION`, ROADMAP, STATUS, runtime ou produção.

## 1. Regra de preservação

Este documento registra uma proposta de evolução futura do Projeto Mímir para criação de uma plataforma comercial de atendentes virtuais humanizados.

Esta proposta não altera e não autoriza alteração em:

- NEXT_ACTION
- ROADMAP
- STATUS
- HANDOFF
- ADRs existentes
- migrations
- PostgreSQL de produção
- OpenClaw runtime
- OpenRC
- firewall
- serviços ativos
- branches
- PRs
- merges
- tags
- deploys
- agentes existentes
- memória existente
- schemas existentes
- políticas de segurança existentes
- documentos históricos

Nenhum arquivo existente deve ser apagado, sobrescrito ou reescrito para incorporar esta proposta.

A proposta deve permanecer separada até que seja executada uma análise formal de compatibilidade com a arquitetura vigente do Mímir.

## 2. Objetivo

Avaliar a criação de uma plataforma comercial construída sobre o Mímir para gerar, configurar, testar e operar atendentes virtuais humanizados para empresas de diferentes segmentos.

A plataforma deve permitir que uma empresa adquira um servidor privado com seu próprio ambiente de atendimento, agentes, memória, base de conhecimento, WhatsApp, Telegram e painel administrativo.

O produto não deve ser tratado como um chatbot de menu.

O objetivo é criar um sistema conversacional multiagente, com um único interlocutor visível ao cliente e especialistas internos trabalhando de forma transparente.

## 3. Premissa arquitetural

O Mímir deve permanecer como núcleo de inteligência, supervisão e segurança.

A nova camada comercial não deve substituir nem duplicar mecanismos existentes do Mímir.

A arquitetura proposta deve reutilizar, quando tecnicamente adequado e validado:

- Mímir Supervisor
- OpenClaw runtime
- agentes especializados
- Tasks
- Task Flow
- Subagents
- Standing Orders
- automações
- skills
- tools
- memória
- pgvector
- PostgreSQL
- capability model
- model routing
- auditoria
- approval gates
- segurança conversacional
- políticas de conteúdo não confiável
- incident response
- controles de memória protegida

Antes de criar qualquer componente novo, deve existir gap analysis formal para verificar se o recurso já existe no Mímir ou no OpenClaw.

## 4. Separação proposta

A arquitetura conceitual deve separar dois domínios.

### 4.1 Mímir Core

Responsabilidades:

- inteligência
- supervisão
- orquestração
- memória
- agentes
- capabilities
- skills
- tools
- model routing
- policy enforcement
- segurança
- auditoria
- approvals
- evidência
- observabilidade

### 4.2 Mímir Business Platform

Responsabilidades:

- fábrica de atendentes
- onboarding empresarial
- configuração por segmento
- perfil comercial de clientes
- CRM conversacional
- atendimento
- vendas
- prospecção
- negociação
- follow-up
- pós-venda
- experiência comercial
- treinamento sintético
- verticais de mercado
- WhatsApp
- Telegram
- frontend
- provisionamento
- licenciamento
- atualização comercial

A Business Platform não deve introduzir um segundo núcleo de orquestração.

## 5. Fábrica de atendentes

Criar futuramente um módulo chamado conceitualmente Mímir Factory.

Função:

Permitir que o cliente empresarial descreva sua empresa em linguagem natural e seja orientado por uma IA consultiva durante a criação do ambiente.

Fluxo conceitual:

CLIENTE EMPRESARIAL
→ FACTORY CONSULTANT
→ BUSINESS ARCHITECT
→ DETECTOR DE MERCADO
→ VERTICAL KNOWLEDGE
→ CONFIGURATION ENGINE
→ AGENT GENERATOR
→ CAPABILITY GENERATOR
→ PROFILE GENERATOR
→ POLICY GENERATOR
→ TEST LAB
→ PUBLICATION

## 6. Factory Consultant Agent

Agente visível ao cliente durante o onboarding.

Responsabilidades:

- conversar de forma natural
- entender o negócio
- identificar segmento
- identificar atividades
- compreender produtos
- compreender serviços
- identificar fluxos comerciais
- identificar setores internos
- identificar regras
- identificar atendimento técnico
- identificar atendimento comercial
- identificar necessidade de especialistas
- evitar menus robotizados
- evitar perguntas repetidas
- explicar recomendações
- manter contexto
- produzir configuração estruturada

O cliente não deve precisar editar prompts técnicos.

## 7. Business Architect Agent

Agente interno.

Não conversa diretamente com o cliente.

Responsabilidades:

- interpretar o negócio
- sugerir agentes necessários
- sugerir capabilities
- sugerir skills
- sugerir ferramentas
- sugerir estrutura de atendimento
- sugerir perfil comercial
- sugerir fluxo de vendas
- sugerir integrações
- sugerir regras de segurança
- sugerir requisitos de privacidade
- sugerir isolamento

O resultado deve ser entregue ao Factory Consultant.

## 8. Regra contra proliferação de agentes

A plataforma deve respeitar a arquitetura do Mímir.

Agente representa:

- identidade
- limite de confiança
- memória isolada
- credencial própria
- política própria
- autonomia própria
- observabilidade própria

Capability representa competência específica.

Skill representa conhecimento e procedimento.

Tool representa uma ação concreta.

Task representa uma unidade de trabalho.

Não criar um novo agente quando uma capability ou skill resolver o requisito.

## 9. Agente de Relacionamento

O cliente final deve conversar com um único agente principal.

Responsabilidades:

- manter a identidade conversacional
- preservar contexto
- adaptar linguagem
- responder de forma profissional
- consultar especialistas internos
- consolidar respostas
- conduzir venda consultiva
- respeitar limites de privacidade
- encaminhar para humano quando necessário

Os especialistas não devem disputar diretamente a conversa com o cliente.

## 10. Especialistas internos

Exemplos de domínios:

- imobiliário
- informática
- redes
- telecom
- fibra óptica
- segurança eletrônica
- energia solar
- automação
- hotelaria
- varejo
- serviços profissionais
- atendimento técnico
- financeiro
- documentação
- pós-venda

Cada vertical deve ser um pacote configurável.

## 11. Perfil comercial 360

Criar um serviço estruturado separado da memória cognitiva.

O Profile Service deve armazenar dados determinísticos do relacionamento comercial.

Campos conceituais:

- tenant_id
- customer_id
- nome
- canal
- origem
- segmento de interesse
- necessidade principal
- necessidades secundárias
- objetivo
- prazo
- faixa de investimento
- critérios de decisão
- produtos considerados
- serviços considerados
- objeções
- estágio comercial
- sinais de compra
- próxima ação
- data de follow-up
- consentimentos
- base legal
- flags de privacidade
- data da última atualização

O Profile Service não deve ser confundido com pgvector ou memória semântica.

## 12. Memória

A memória do Mímir deve continuar responsável por contexto e conhecimento elegível.

O perfil comercial estruturado deve continuar no banco relacional.

Integração conceitual:

PROFILE SERVICE
↔ MÍMIR MEMORY

A memória não deve receber automaticamente qualquer informação da conversa.

Promoção de informação deve obedecer política de elegibilidade.

## 13. Experiência comercial

Criar futuramente um módulo chamado conceitualmente Mímir Experience.

Objetivo:

Permitir que agentes de venda ganhem experiência sem compartilhar dados pessoais ou segredos comerciais entre empresas.

Regra central:

O sistema aprende o método, não transporta o cliente.

Fluxo conceitual:

CONVERSA PRIVADA
→ ANÁLISE LOCAL
→ CANDIDATO A EXPERIÊNCIA
→ SANITIZAÇÃO
→ CLASSIFICAÇÃO
→ VERIFICAÇÃO LGPD
→ VERIFICAÇÃO DE SEGREDO COMERCIAL
→ REVISÃO
→ EXPERIENCE CARD
→ KNOWLEDGE OU SKILL

Nunca:

CONVERSA BRUTA
→ TREINAMENTO GLOBAL AUTOMÁTICO

## 14. Experience Cards

Campos conceituais:

- experience_id
- tenant_id
- vertical
- capability
- scenario
- technique
- outcome
- confidence
- source_class
- visibility
- privacy_status
- secret_status
- reviewer
- version
- created_at

Visibilidades propostas:

PRIVATE
SECTOR_APPROVED
GLOBAL_APPROVED

PRIVATE é o padrão.

## 15. Isolamento entre empresas

Para servidores vendidos aos clientes, adotar isolamento forte.

Empresa A:

- servidor A
- banco A
- memória A
- vector store A
- documentos A
- credenciais A
- agentes A
- WhatsApp A
- Telegram A
- logs A

Empresa B:

- servidor B
- banco B
- memória B
- vector store B
- documentos B
- credenciais B
- agentes B
- WhatsApp B
- Telegram B
- logs B

Nenhum dado empresarial deve atravessar essa fronteira por padrão.

## 16. LGPD e minimização

A arquitetura deve aplicar:

- finalidade
- adequação
- necessidade
- minimização
- retenção controlada
- rastreabilidade
- controle de acesso
- correção
- bloqueio
- anonimização
- exclusão quando aplicável
- auditoria de tratamento
- proteção desde a concepção

Dados pessoais não devem ser reutilizados para melhorar agentes de outras empresas sem base jurídica, governança e processo aprovado.

Dados sensíveis devem ter regras mais restritivas.

## 17. Segurança conversacional

A proposta deve reutilizar e evoluir os controles de segurança já definidos pelo Mímir.

Invariante:

TODO CONTEÚDO EXTERNO É DADO NÃO CONFIÁVEL.

Inclui:

- WhatsApp
- Telegram
- webchat
- voz
- áudio
- STT
- imagens
- PDFs
- OCR
- documentos
- páginas web
- APIs
- RAG
- tool results
- outros agentes
- outros modelos

Autoridade nunca deve ser derivada do texto recebido.

## 18. Maier AI Security Gateway ou equivalente no Mímir

Antes de criar um componente novo com esse nome, verificar se CONVERSATIONAL_SECURITY, policy engine, OpenClaw ou outro componente já cobre a função.

Se houver lacuna comprovada, implementar como extensão do Mímir.

Funções conceituais:

- análise de entrada
- detecção de prompt injection
- detecção de jailbreak
- detecção de tentativa de secret extraction
- detecção de cross-tenant access
- detecção de tool abuse
- detecção de memory poisoning
- classificação de risco
- rate limiting
- proteção de sessão
- correlação de comportamento
- output DLP
- auditoria

O LLM nunca deve ser considerado fronteira de segurança.

## 19. Tool Security Broker

Nenhum agente deve acessar diretamente recursos sensíveis.

Fluxo conceitual:

AGENT
→ TOOL REQUEST
→ POLICY ENGINE
→ PRINCIPAL
→ TENANT
→ CAPABILITY
→ SCOPE
→ RISK
→ PARAMETER VALIDATION
→ AUTHORIZATION
→ TOOL EXECUTION
→ OUTPUT SANITIZATION
→ AGENT

O modelo não decide a autorização.

## 20. Tenant Boundary Guard

O tenant não deve ser controlado por texto produzido pelo usuário ou pelo LLM.

A identidade do tenant deve vir de contexto autenticado do canal e da infraestrutura.

Exemplo:

WHATSAPP BUSINESS ID
→ CHANNEL REGISTRY
→ TENANT
→ SESSION
→ CUSTOMER
→ AUTHORIZED AGENT

Solicitação de outro tenant deve resultar em DENY antes da execução.

## 21. Memory Firewall

Antes de gravar memória:

MEMORY CANDIDATE
→ TENANT CHECK
→ CUSTOMER SCOPE
→ DATA CLASSIFICATION
→ PII CHECK
→ PURPOSE CHECK
→ POLICY
→ MEMORY STORE

Antes de consultar:

MEMORY QUERY
→ TENANT CHECK
→ CUSTOMER SCOPE
→ AGENT SCOPE
→ CAPABILITY CHECK
→ DATA CLASSIFICATION
→ AUTHORIZED RETRIEVAL

## 22. RAG Firewall

Documentos devem possuir metadados de segurança.

Campos conceituais:

- tenant
- owner
- classification
- source
- hash
- version
- permissions
- domain
- confidentiality
- ingestion_status

O agente nunca deve consultar documentos de outro tenant.

## 23. File Ingestion Security

A proposta já registrada separadamente para ingestão segura de arquivos deve ser considerada dependência de segurança antes de permitir upload externo generalizado.

Princípios:

- deny by default
- PDF, JPEG e PNG somente
- MIME real
- magic bytes
- parser estrutural
- quarantine
- SHA-256
- malware scan
- re-encode de imagem
- política restritiva para PDF
- conteúdo externo marcado como UNTRUSTED
- nenhuma promoção automática
- kill switch

Não duplicar esse módulo nesta proposta.

## 24. Voz

Áudio não deve possuir confiança adicional.

Fluxo conceitual:

AUDIO
→ FILE SECURITY
→ DECODER
→ STT
→ UNTRUSTED TEXT
→ SECURITY ANALYSIS
→ CONVERSATION ENGINE

Voz não é autenticação.

## 25. Output DLP

Toda resposta deve passar por controle de saída antes do envio.

Verificações:

- secrets
- credentials
- API keys
- tokens
- private keys
- connection strings
- PII
- dados de outro tenant
- segredos comerciais
- margens
- políticas internas
- informações administrativas

Resposta proibida deve ser bloqueada ou sanitizada antes do canal.

## 26. Risk Engine

Cada interação pode receber score interno de risco.

Exemplo conceitual:

0 a 30
atendimento normal

31 a 60
inspeção reforçada

61 a 80
tools sensíveis bloqueadas

81 a 100
sessão restrita ou isolada

Os limites reais devem ser definidos por avaliação de risco e testes.

## 27. Sales Academy AI

Criar futuramente uma academia sintética de vendas.

Objetivo:

Treinar agentes comerciais sem depender de conversas identificáveis de clientes reais.

Componentes:

- Scenario Generator
- Simulated Customer
- Sales Agent
- Sales Evaluator
- Policy Checker
- Experience Extractor

Cenários devem ser sintéticos.

Exemplos:

- objeção de preço
- comparação com concorrente
- urgência
- falta de orçamento
- resistência
- negociação
- follow-up
- mudança de necessidade
- venda consultiva
- cross-sell
- pós-venda

## 28. Human Handoff

O sistema deve permitir:

IA
→ humano
→ IA

Sem perda de contexto.

O operador deve receber:

- perfil resumido
- histórico
- objetivo
- estágio
- objeções
- proposta
- pendências
- próximo passo sugerido

Quando o humano assumir, respostas automáticas devem ser suspensas conforme política.

## 29. WhatsApp e Telegram

Antes de integração comercial, validar:

- identidade
- tenant
- assinatura de webhook
- anti-replay
- rate limiting
- idempotência
- sessão
- customer binding
- auditoria
- status de entrega
- retry policy
- handoff
- segurança de anexos
- policy enforcement

Nenhum canal deve se conectar diretamente ao agente.

## 30. Frontend

Criar futuramente um painel administrativo para:

- onboarding
- criação de atendente
- configuração de empresa
- configuração de vertical
- produtos
- serviços
- políticas
- base de conhecimento
- agentes
- capabilities
- skills
- canais
- conversas
- CRM
- handoff
- laboratório
- métricas
- segurança
- auditoria
- privacy controls
- atualização
- licenciamento

## 31. Laboratório de atendimento

Antes da publicação, cada instalação deve possuir ambiente de testes.

O administrador deve conseguir testar:

- linguagem
- venda
- objeções
- perguntas técnicas
- segurança
- prompt injection
- tentativa de acesso a segredo
- tentativa de acesso a outro cliente
- handoff
- memória
- profile update
- RAG
- tools

A publicação depende de critérios objetivos de validação.

## 32. Provisionamento

A fábrica deve gerar uma configuração reproduzível para cada cliente.

Conceitualmente:

FACTORY
→ TENANT PACKAGE
→ SIGNED CONFIG
→ CUSTOMER SERVER
→ VALIDATION
→ ACTIVATION

Não transferir dados de outras empresas junto ao pacote.

## 33. Atualizações

Atualizações devem ser assinadas e versionadas.

Separar:

- Mímir Core
- Mímir Business
- verticals
- skills
- policies
- schemas
- frontend

Uma atualização de vertical não deve substituir dados privados do cliente.

## 34. Modelo comercial

Possível produto:

Mímir Business Server

Componentes:

- servidor privado
- Gentoo Linux
- OpenRC
- Mímir
- OpenClaw
- PostgreSQL
- pgvector
- agentes
- frontend
- WhatsApp
- Telegram
- memória
- segurança
- backup
- monitoramento
- atualizações

O desenho comercial deve ser analisado separadamente da arquitetura técnica.

## 35. Gap analysis obrigatório

Antes de implementar qualquer item desta proposta, analisar:

1. existe no Mímir
2. existe parcialmente
3. existe no OpenClaw
4. existe como configuração
5. existe como plugin
6. exige capability
7. exige skill
8. exige agente novo
9. exige serviço novo
10. exige schema novo
11. exige migration
12. exige ADR
13. exige alteração de segurança
14. exige alteração de memória
15. exige alteração de runtime

Somente lacuna comprovada autoriza desenho de componente novo.

## 36. Fases sugeridas

### Fase A

Documentação e gap analysis.

Nenhuma implementação.

### Fase B

Modelo conceitual de Business Platform.

Sem alteração de produção.

### Fase C

Factory Consultant em laboratório isolado.

### Fase D

Vertical piloto.

Sugestão:

imobiliário ou informática.

### Fase E

Profile Service e CRM em laboratório.

### Fase F

Experience Cards privadas.

### Fase G

Sales Academy sintética.

### Fase H

Integração Telegram em laboratório.

### Fase I

Integração WhatsApp em laboratório.

### Fase J

Hardening completo.

### Fase K

Piloto em servidor separado.

### Fase L

Produto replicável.

Cada fase exige checkpoint próprio.

## 37. Critérios de segurança antes de produção

Não liberar atendimento empresarial real enquanto não houver evidência para:

- tenant isolation
- identity binding
- policy enforcement fora do LLM
- prompt injection resistance
- tool authorization
- memory isolation
- RAG isolation
- output DLP
- file ingestion security
- secret protection
- audit trail
- kill switch
- backup
- restore
- incident response
- human handoff
- privacy controls
- retention policy
- negative security tests

## 38. Não autorizado por esta proposta

Este documento não autoriza:

- implementar código
- criar migration
- alterar schema
- instalar serviço
- alterar OpenClaw
- alterar PostgreSQL
- alterar firewall
- alterar runtime
- criar agente em produção
- conectar WhatsApp real
- conectar Telegram real
- alterar memória existente
- alterar HANDOFF
- alterar ROADMAP
- alterar STATUS
- alterar NEXT_ACTION
- alterar ADR existente
- fazer merge
- fazer deploy

Qualquer uma dessas ações exige autorização separada e análise do estado Git vigente.

## 39. Arquivos futuros sugeridos

Somente após aprovação da proposta:

docs/business/BUSINESS_PLATFORM_ARCHITECTURE.md

docs/business/FACTORY_CONSULTANT.md

docs/business/CUSTOMER_PROFILE_MODEL.md

docs/business/EXPERIENCE_CARDS.md

docs/business/SALES_ACADEMY.md

docs/business/TENANT_ISOLATION.md

docs/business/CHANNEL_SECURITY.md

docs/business/WHATSAPP_INTEGRATION.md

docs/business/TELEGRAM_INTEGRATION.md

docs/business/BUSINESS_SECURITY_TEST_MATRIX.md

docs/review/business/<data>-business-platform-gap-analysis.md

Nenhum desses arquivos deve ser criado no repositório somente por causa desta proposta.

## 40. Estado desta evolução

Estado:

PARKED_FOR_FUTURE_ANALYSIS

Prioridade:
ESTRATÉGICA

Implementação:

NÃO AUTORIZADA

Runtime change:

NÃO AUTORIZADO

Production change:

NÃO AUTORIZADO

PostgreSQL change:

NÃO AUTORIZADO

Migration:

NÃO AUTORIZADA

OpenClaw change:

NÃO AUTORIZADO

Firewall change:

NÃO AUTORIZADO

NEXT_ACTION change:

NÃO AUTORIZADA

ROADMAP change:

NÃO AUTORIZADA

HANDOFF change:

NÃO AUTORIZADA

STATUS change:

NÃO AUTORIZADA

## 41. Próxima ação recomendada

Quando o marco operacional vigente do Mímir estiver concluído:

1. confirmar Git limpo
2. identificar HEAD real
3. ler HANDOFF
4. ler EXECUTION PLAN
5. ler STATUS
6. ler ROADMAP
7. revisar ARCHITECTURE
8. revisar SECURITY
9. revisar CONVERSATIONAL_SECURITY
10. revisar AI_SECURITY_TEST_MATRIX
11. revisar Capability evolution
12. revisar File Ingestion Security evolution
13. executar gap analysis desta proposta
14. classificar cada item como EXISTING, PARTIAL, PROPOSED, MISSING ou OUT_OF_SCOPE
15. decidir se a Business Platform será módulo, plugin, conjunto de skills ou camada separada
16. criar ADR somente se necessário
17. implementar primeiro em repositório e laboratório isolado
18. manter produção intacta até validação formal

## 42. Resultado esperado

Se aprovada no futuro, esta evolução deve permitir:

- fabricar atendentes por segmento
- manter conversa humanizada
- operar múltiplos especialistas internos
- isolar empresas
- preservar LGPD
- preservar segredos comerciais
- evoluir experiência de vendas com segurança
- impedir compartilhamento indevido de dados
- proteger contra prompt injection
- proteger tools
- proteger memória
- proteger RAG
- proteger arquivos
- proteger respostas
- integrar WhatsApp
- integrar Telegram
- transferir atendimento entre IA e humano
- instalar ambientes privados nos servidores dos clientes
- manter o Mímir como núcleo comum sem criar arquitetura concorrente

Fim da proposta.