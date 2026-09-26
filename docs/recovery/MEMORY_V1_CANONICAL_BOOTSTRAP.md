# Bootstrap canônico da memória v1

Data: 2026-09-24
Status: reconstrução versionada e validada em laboratório isolado

## Conclusão

A migration histórica 001 não foi localizada no Git nem no diretório local de recuperação. Por isso o projeto não cria um arquivo 001 retroativo.

O artefato canônico novo é:

`tools/memory/bootstrap/memory_v1_canonical.sql`

Ele reconstrói o estado necessário antes da migration 002 usando o schema observado em leitura e os deltas explícitos das migrations 002–012.

## Núcleo v1 reconstruído

- `mimir.schema_version`
- `mimir.memory_events`
- `mimir.memory_records`
- `mimir.memory_relations`
- `mimir.memory_audit`
- roles base `mimir_owner` e `mimir_app`
- extensões `pgcrypto` e `vector`
- índices, constraints, FKs e coluna gerada `search_document`

A descrição registrada da versão 1 é:

`Estrutura temporal inicial da memória do Mimir`

## Objetos posteriores excluídos

O bootstrap não contém objetos que as migrations versionadas adicionam depois, incluindo:

- índice de hash de events da 002;
- `memory_records.content_sha256` e índice associado da 003;
- `memory_reviews` e índice active da 004;
- `reviewer_identities` da 005;
- roles posteriores de review/embedding/search;
- `session_sources` e índice de sessão da 008.

## Privilégios reconstruídos

Para permitir replay fiel das migrations posteriores, o baseline concede:

- SELECT nas cinco tabelas base;
- INSERT em events, records, relations e audit;
- USAGE no schema;
- CONNECT/TEMPORARY no banco.

Isso é compatível com as revogações explícitas posteriores nas migrations 002, 003 e 009. UPDATE e DELETE não são concedidos.

## Segurança

O bootstrap recusa execução fora de um banco chamado `mimir_memory` e recusa banco que já possua schema `mimir`.

Não aplicar esse bootstrap sobre produção existente.

## Validação obrigatória

O P0 só fecha após replay em banco descartável:

1. bootstrap v1;
2. migrations 002–012 sem edição;
3. versões finais 1–12;
4. comparação de objetos e privilégios relevantes;
5. testes estáticos;
6. confirmação de produção intacta.


## Validação runtime concluída

Checkpoint: `MIMIR-V1-MEMORY-BOOTSTRAP-01`.

O bootstrap canônico foi validado em banco descartável dentro do cluster
PostgreSQL temporário em `gentoo-Dragon_vm`, sem alterar produção.

Resultado:

- teste estático local: 9 testes, OK;
- bootstrap v1 aplicado com sucesso em banco vazio `mimir_memory` do cluster temporário;
- após bootstrap: `schema_versions=1`;
- migrations 002–012 aplicadas sem edição e em ordem;
- estado final: `schema_versions=1,2,3,4,5,6,7,8,9,10,11,12`;
- tabelas finais: `memory_audit`, `memory_events`, `memory_records`,
  `memory_relations`, `memory_reviews`, `reviewer_identities`,
  `schema_version`, `session_sources`;
- funções finais: ingestão de documento/sessão, proposta, consolidação,
  revisão humana, busca semântica e armazenamento de embedding;
- `search_document` e `content_sha256` confirmados como colunas geradas;
- `mimir_app` terminou sem SELECT/INSERT/UPDATE/DELETE direto nas cinco tabelas base;
- USAGE no schema preservado;
- EXECUTE de `ingest_document`, `ingest_session` e `propose_memory` preservado;
- produção permaneceu em versões 1–12;
- produção permaneceu sem schema_version 13;
- produção permaneceu sem role `mimir_ops`.

Conclusão: o Git agora possui um caminho reprodutível de bootstrap da memória v1
até a versão 12. A lacuna histórica continua documentada corretamente: o SQL
original da migration 001 não foi recuperado, mas existe um bootstrap canônico
equivalente validado para reconstrução.
