# Mimir Memory

Plugin local tipado para consulta controlada da memória semântica
permanente do Mimir.

## Ferramenta

`mimir_memory_search`

Parâmetros:

- `query`: pergunta ou assunto pesquisado;
- `limit`: máximo de resultados, entre 1 e 10;
- `min_similarity`: similaridade mínima, entre 0.2 e 0.95.

## Segurança

- não oferece shell arbitrário;
- executa somente o cliente fixo de consulta semântica;
- conecta ao PostgreSQL pela role `mimir_search`;
- autentica por `peer:openclaw`;
- não possui leitura direta das tabelas;
- não grava nem altera memórias;
- gera embeddings localmente em CPU;
- possui limite de execução e tamanho de saída;
- permanece opcional até autorização explícita em `tools.alsoAllow`.

## Dependências locais

- OpenClaw em `/opt/openclaw`;
- Node.js em `/usr/bin/node`;
- PostgreSQL pelo socket `/run/postgresql`;
- EmbeddingGemma local;
- função `mimir.search_active_memory(...)`.
