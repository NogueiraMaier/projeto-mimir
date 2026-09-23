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
