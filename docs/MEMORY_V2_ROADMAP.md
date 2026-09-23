# Mímir Memory v2 — Roadmap de evolução

Status: **PLANEJADO**  
Objetivo: registrar a próxima fase de evolução da memória do Projeto Mímir para implementação **após a conclusão da fundação operacional atual**.

## Princípio

A evolução da memória deve preservar a arquitetura já adotada no Mímir:

- PostgreSQL como fonte de verdade persistente;
- pgvector para recuperação vetorial;
- proveniência e evidência;
- estados controlados de memória;
- revisão humana antes de promoção;
- auditoria;
- segregação por escopo;
- nenhuma promoção irrestrita;
- nenhum armazenamento de segredos.

A proposta **não** é substituir a memória do Mímir por Mem0, Letta, Zep/Graphiti, Cognee ou outro framework. Esses projetos servem como referências arquiteturais. O objetivo é incorporar os conceitos úteis mantendo controle local e compatibilidade com o desenho atual.

## Modelo de memória proposto

A memória deve ser tratada como um ciclo:

`write -> manage -> read`

com separação entre diferentes classes de contexto.

### Working memory

Contexto temporário da tarefa ou sessão atual.

Características:

- pequeno;
- descartável;
- não é fonte de verdade;
- pode ser reconstruído;
- não deve ser promovido automaticamente para memória durável.

### Memória episódica

Registra o que aconteceu.

Exemplos:

- intervenções;
- incidentes;
- alterações;
- decisões;
- sessões;
- resultados de execução.

### Memória semântica

Registra fatos consolidados.

Exemplos:

- cliente possui determinado equipamento;
- site utiliza determinada VLAN;
- endereço IP vigente;
- firmware conhecido;
- relação entre serviços e dispositivos.

### Memória procedural

Registra procedimentos validados.

Exemplos:

- runbooks;
- sequência segura de alteração;
- validação pós-mudança;
- rollback;
- procedimentos de troubleshooting.

### Core/context memory

Conjunto pequeno de fatos e políticas que devem estar disponíveis com alta prioridade para um agente, projeto, cliente, site ou dispositivo.

## P1 — Temporalidade, supersession e identidade de entidades

Prioridade: **ALTA**

### Temporalidade

Adicionar suporte explícito a:

- `valid_from`;
- `valid_to`;
- `observed_at`;
- `last_verified_at`;
- `superseded_by`.

Objetivo:

Distinguir:

1. quando o fato era verdadeiro;
2. quando o Mímir tomou conhecimento;
3. quando ele foi verificado;
4. quando deixou de ser vigente.

Memórias antigas não devem ser apagadas silenciosamente.

### Estados adicionais

Avaliar expansão dos estados atuais para:

- `candidate`;
- `active`;
- `superseded`;
- `stale`;
- `rejected`;
- `expired`.

`superseded` deve preservar histórico e apontar para o registro substituto.

`stale` representa informação ainda preservada, mas cuja validade precisa ser reavaliada.

`expired` não significa exclusão física.

### Identidade de entidades

Criar identidade canônica para evitar duplicação lógica.

Campos esperados:

- `entity_id`;
- `canonical_name`;
- aliases;
- `entity_type`;
- `scope`.

Exemplo:

`Protec`, `Protec Monitoramento`, `Protec_Samuel` e `site Protec Samuel` não devem virar automaticamente quatro clientes distintos.

## P2 — Grafo de entidades e relações dentro do PostgreSQL

Prioridade: **ALTA**

Manter PostgreSQL/pgvector como base principal.

Não introduzir banco de grafo separado sem necessidade comprovada.

Entidades iniciais esperadas:

- client;
- project;
- site;
- device;
- interface;
- network;
- subnet;
- vlan;
- service;
- tunnel;
- endpoint;
- incident;
- intervention;
- memory;
- evidence.

Relações esperadas:

- possui;
- pertence_a;
- depende_de;
- conecta_a;
- usa;
- substitui;
- valida;
- originou;
- relacionado_a.

Exemplo de resolução:

`cliente -> site -> equipamento -> WireGuard -> peer -> VPS -> endereço atual`

A relação deve possuir proveniência, temporalidade e escopo quando aplicável.

## P3 — Retrieval híbrido e Memory Context Builder

Prioridade: **ALTA**

A recuperação futura não deve depender apenas de similaridade vetorial.

Combinar, quando disponível:

- similaridade vetorial;
- busca textual;
- relações do grafo;
- recência;
- importância;
- confiança;
- estado temporal;
- verificação;
- escopo.

Modelo conceitual de ranking:

`retrieval_score = semantic_similarity x confidence x freshness x importance x verification`

A fórmula final deve ser definida e validada por benchmark; não deve ser adotada literalmente sem testes.

### Memory Context Builder

Criar componente que monte contexto pequeno e orientado à tarefa.

Estrutura sugerida:

- **WHO** — cliente, site, equipamento, agentes envolvidos;
- **NOW** — estado vigente e verificado;
- **HISTORY** — mudanças relevantes;
- **POLICY** — restrições, procedimentos e controles;
- **TASK** — contexto específico da tarefa atual.

O agente não deve receber simplesmente os top-N embeddings sem estrutura.

## P4 — MIMIR-MEM-EVAL

Prioridade: **ALTA**

Criar benchmark próprio do domínio operacional do Mímir.

Categorias mínimas:

- recuperação factual;
- atualização de conhecimento;
- temporalidade;
- single-hop;
- multi-hop;
- contradição;
- abstention;
- histórico;
- relação entre entidades;
- recuperação procedural.

Exemplos de perguntas:

- Qual é o roteador atual do cliente?
- Qual era o IP anterior?
- Quando ele mudou?
- Por que mudou?
- Qual site utiliza determinada VLAN?
- Qual equipamento depende desse túnel?
- Qual configuração foi substituída?
- Existe evidência para esse fato?
- O Mímir deve responder "não sei" quando não houver registro?

Métricas candidatas:

- Recall@k;
- Precision;
- Fact accuracy;
- Temporal accuracy;
- Multi-hop accuracy;
- Contradiction resolution;
- Abstention accuracy;
- retrieval latency;
- tokens/query.

Uma alteração na memória não deve ser considerada melhoria apenas porque "parece lembrar melhor". Deve existir medição reproduzível.

## P5 — Consolidação contínua e decay controlado

Prioridade: **MÉDIA**

Pipeline alvo:

`session/event -> extraction -> candidate -> deduplication -> conflict detection -> consolidation -> review -> active`

Processamento periódico deve detectar:

- duplicatas;
- contradições;
- fatos substituídos;
- registros obsoletos;
- relações novas;
- fatos de alta importância;
- registros que precisam de reverificação.

### Decay

Decay deve inicialmente afetar **ranking e prioridade**, não exclusão automática.

Informação antiga pode ser essencial para:

- troubleshooting;
- auditoria;
- explicação causal;
- reconstrução histórica.

Nenhum processo de consolidação pode reescrever ou apagar história sem registro de auditoria.

## P6 — Memória compartilhada entre agentes com ACL

Prioridade: **MÉDIA**

Ao ampliar agentes especializados, evitar:

1. cada agente manter uma realidade divergente;
2. todos os agentes terem acesso irrestrito à mesma memória.

Escopos candidatos:

- global;
- client;
- project;
- site;
- device;
- agent.

Controles:

- readers;
- writers;
- classification;
- source;
- provenance.

Exemplo conceitual:

- agente de redes: leitura de cliente/site/device/network;
- agente de negócios: leitura de cliente/project/commercial, sem acesso a credenciais;
- agente SOC: leitura de security/events/network.

Segredos e credenciais continuam fora da memória durável.

## Integração com a fundação operacional

A Memory v2 deve aproveitar a camada operacional em desenvolvimento.

Uma intervenção somente deve ser considerada completamente encerrada quando houver:

1. estado encontrado;
2. alterações realizadas;
3. validação;
4. inventário atualizado;
5. histórico/auditoria;
6. relatório.

Na Memory v2, esses artefatos passam a alimentar memória episódica, relações entre entidades e fatos semânticos revisáveis.

## Restrições

A implementação futura deve:

- permanecer compatível com Gentoo/OpenRC;
- preservar PostgreSQL/pgvector;
- não exigir containers;
- não exigir serviço cloud;
- não introduzir banco de grafo externo sem justificativa;
- preservar proveniência;
- preservar história;
- não apagar informação silenciosamente;
- não armazenar senha, token ou chave privada;
- manter aprovação humana para promoção de memória crítica;
- permitir modo shadow/dry-run antes de qualquer automação de consolidação.

## Referências para estudo

Referências arquiteturais, não dependências obrigatórias:

- Memory for Autonomous LLM Agents — arXiv 2603.07670
- Mem0 — State of AI Agent Memory 2026
- Awesome Agent Memory
- Mem0
- Letta / MemGPT
- Zep / Graphiti
- Cognee
- LoCoMo
- LongMemEval

Vídeo que motivou esta anotação:

- https://www.youtube.com/watch?v=6VwIeBI1JZw

## Ordem de implementação

Após a conclusão e validação da fundação operacional atual:

1. **P1** — temporalidade + supersession + identidade de entidades;
2. **P2** — relações/grafo no PostgreSQL;
3. **P3** — retrieval híbrido + Memory Context Builder;
4. **P4** — MIMIR-MEM-EVAL;
5. **P5** — consolidação/decay controlado;
6. **P6** — memória compartilhada entre agentes com ACL.

## Critério de início

Esta fase não deve começar antes de:

- fundação operacional concluída;
- testes locais concluídos;
- validação do ambiente real do VPS;
- migration operacional validada;
- estado da memória atual documentado;
- baseline de benchmark inicial capturado.

## Critério de conclusão

Memory v2 somente poderá ser considerada concluída quando:

- migrations forem aplicadas e auditadas;
- temporalidade for testada;
- histórico for preservado;
- entity resolution possuir testes;
- retrieval híbrido superar ou igualar o baseline sem regressão crítica;
- abstention continuar segura;
- consolidação não realizar autopromoção irrestrita;
- ACL entre agentes estiver testada;
- documentação refletir o estado real;
- MIMIR-MEM-EVAL possuir resultados reproduzíveis.


## Visualização — Mímir Memory Graph Explorer

Status: **PLANEJADO**

O Mímir deve possuir uma visualização gráfica inspirada na experiência de graph view de ferramentas de knowledge management, mas a visualização não será a fonte de verdade.

A fonte de verdade continuará sendo PostgreSQL/pgvector.

### Objetivo

Permitir explorar visualmente:

- memórias;
- entidades;
- relações;
- clientes;
- projetos;
- sites;
- equipamentos;
- interfaces;
- redes;
- VLANs;
- túneis;
- intervenções;
- incidentes;
- evidências;
- agentes.

Exemplo conceitual:

`cliente -> site -> equipamento -> interface -> VLAN -> serviço -> intervenção -> evidência`

### Requisitos da primeira versão

A primeira versão deve ser **somente leitura**.

O grafo deve permitir:

- zoom e pan;
- pesquisa de nó;
- filtros por tipo de memória;
- filtros por cliente/projeto/site/device;
- filtros por agente;
- filtros por estado;
- filtros por classificação;
- filtros temporais;
- exibição e ocultação de tipos de relação;
- expansão de vizinhança de um nó;
- painel lateral de detalhes;
- navegação entre evidência, memória e entidade;
- indicação de proveniência;
- indicação de confiança;
- indicação de última verificação;
- indicação de memória superseded/stale;
- linha do tempo ou controle temporal em fase posterior.

### Representação visual sugerida

A semântica visual deve ser estável e documentada.

Exemplo:

- cor do nó = tipo;
- borda = status;
- tamanho = importância;
- opacidade = freshness/estado;
- linha sólida = relação vigente;
- linha tracejada = relação histórica ou não verificada;
- ícone/marker = evidência disponível.

A visualização nunca deve esconder que uma memória é:

- não verificada;
- stale;
- superseded;
- histórica;
- candidate.

### Segurança

O Graph Explorer não deve:

- exibir senha, token ou chave;
- consultar tabelas protegidas diretamente no navegador;
- conceder escrita no PostgreSQL;
- permitir promoção de memória por clique na primeira versão;
- expor conteúdo confidential sem autorização;
- substituir controles de ACL existentes.

Arquitetura sugerida:

`PostgreSQL -> API/consulta read-only -> Graph Explorer`

O frontend recebe somente os campos necessários à visualização e ao contexto autorizado.

### Bibliotecas candidatas para visualização

#### Sigma.js + Graphology

Uso sugerido: candidato principal para uma experiência semelhante a graph view com grande número de nós.

Pontos de interesse:

- Sigma.js usa WebGL;
- projetado para visualização de grafos com milhares de nós e arestas;
- Graphology fornece a estrutura de dados e algoritmos;
- apropriado para exploração visual fluida.

Documentação:

- https://www.sigmajs.org/
- https://github.com/jacomyal/sigma.js
- https://graphology.github.io/

#### Cytoscape.js

Uso sugerido: alternativa ou complemento quando precisarmos de maior capacidade de análise, seletores e layouts.

Pontos de interesse:

- biblioteca de teoria de grafos e visualização;
- MIT;
- layouts;
- seletores;
- filtros;
- algoritmos de grafo;
- uso no browser ou headless em Node.js.

Documentação:

- https://js.cytoscape.org/
- https://github.com/cytoscape/cytoscape.js

### Ferramentas de knowledge management como referência de UX

Estas ferramentas devem ser estudadas principalmente como referência de navegação, organização e visualização. Não são dependências obrigatórias do Mímir.

#### Logseq

Referência:

- knowledge graph;
- links e referências;
- organização em blocos;
- consultas e views;
- privacidade/local-first;
- ecossistema de plugins.

Documentação/código:

- https://github.com/logseq/logseq
- https://github.com/logseq/docs

#### Joplin

Referência:

- Markdown;
- organização de notas;
- tags;
- pesquisa;
- exportação/importação;
- armazenamento simples e auditável.

Documentação/código:

- https://joplinapp.org/help/
- https://github.com/laurent22/joplin

#### Anytype

Referência de UX:

- objetos;
- tipos;
- relações;
- graph;
- local-first;
- navegação entre entidades.

Observação de licença:

O código atual do cliente Anytype está publicado sob **Any Source Available License 1.0**. Portanto, deve ser tratado como **source-available**, e não assumido automaticamente como FOSS/OSI para reutilização de código.

Documentação/código:

- https://doc.anytype.io/
- https://github.com/anyproto/anytype-ts

#### AFFiNE

Referência:

- documentos;
- canvas;
- blocos;
- organização visual;
- arquitetura local-first.

Documentação/código:

- https://github.com/toeverything/AFFiNE
- https://github.com/toeverything/OctoBase

## Catálogo de projetos open source para estudo de memória

O objetivo deste catálogo é permitir comparação técnica antes de implementar cada etapa da Memory v2.

### Graphiti

Foco:

- temporal knowledge graph;
- entidades e relações;
- provenance;
- validade temporal;
- atualizações incrementais;
- recuperação semântica + keyword + graph.

Partes especialmente relevantes para o Mímir:

- bi-temporalidade;
- episodes como fonte/proveniência;
- relações com janela temporal;
- consultas históricas.

Documentação:

- https://github.com/getzep/graphiti
- https://help.getzep.com/graphiti/getting-started/welcome

### Mem0 OSS

Foco:

- memória persistente de agentes;
- extração de fatos;
- add/search;
- filtros/metadata;
- reranking;
- self-host.

Partes relevantes:

- lifecycle de memória;
- scoping;
- expiration;
- comparação de providers;
- avaliação de custo/contexto.

Observação:

A documentação atual informa que graph memory não faz parte do stack OSS básico; portanto o Mímir não deve assumir paridade entre a versão OSS e recursos da plataforma hospedada.

Documentação:

- https://github.com/mem0ai/mem0
- https://docs.mem0.ai/open-source/overview

### Letta

Foco:

- agentes stateful;
- memória persistente;
- memory blocks;
- contexto gerenciado;
- aprendizado contínuo.

Partes relevantes:

- core/context blocks;
- separação entre contexto sempre carregado e memória recuperável;
- agentes com estado persistente.

Documentação:

- https://github.com/letta-ai/letta
- https://docs.letta.com/

### LangMem

Foco:

- extração e consolidação de memória;
- hot-path memory tools;
- background memory manager;
- integração com stores persistentes.

Partes relevantes:

- formação de memória durante a interação;
- consolidação em background;
- separação entre memória semântica, episódica e procedural;
- uso de PostgreSQL como persistent store.

Documentação:

- https://github.com/langchain-ai/langmem

### Cognee

Foco:

- knowledge graph;
- memória para agentes;
- graph + vector retrieval;
- pipelines de ingestão e organização.

Partes relevantes:

- arquitetura de conhecimento relacional;
- integração entre grafo e vetores;
- desenho de pipeline ECL/ingestão.

Documentação:

- https://github.com/topoteretes/cognee
- https://docs.cognee.ai/

## Regra para adoção de componentes externos

Antes de incorporar biblioteca ou framework externo à Memory v2:

1. verificar licença;
2. verificar manutenção ativa;
3. avaliar compatibilidade com Gentoo/OpenRC;
4. avaliar necessidade de container;
5. avaliar dependências extras;
6. avaliar possibilidade de uso com PostgreSQL/pgvector existente;
7. verificar tratamento de dados sensíveis;
8. executar benchmark local;
9. comparar com implementação própria;
10. documentar motivo da decisão.

Preferência arquitetural:

- reutilizar bibliotecas de visualização e algoritmos quando maduras;
- manter dados e governança no PostgreSQL do Mímir;
- evitar substituir todo o memory stack apenas para obter uma função isolada.

## Prioridade do Graph Explorer

O Graph Explorer deve entrar **depois de P2**, quando entidades e relações já possuírem modelo estável no PostgreSQL.

Ordem sugerida:

1. P1 — temporalidade e entity resolution;
2. P2 — grafo de relações;
3. **Graph Explorer v1 read-only**;
4. P3 — retrieval híbrido + Context Builder;
5. P4 — MIMIR-MEM-EVAL;
6. fases posteriores.

O Graph Explorer poderá também se tornar uma ferramenta importante de auditoria do MIMIR-MEM-EVAL, permitindo visualizar por que uma memória foi recuperada e quais relações sustentaram a resposta.
