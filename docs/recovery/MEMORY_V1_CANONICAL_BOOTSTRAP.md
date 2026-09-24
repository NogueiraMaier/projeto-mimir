# Bootstrap canônico da memória v1

Data: 2026-09-24
Status: reconstrução versionada; validação runtime pendente

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
