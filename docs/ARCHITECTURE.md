# Arquitetura do Projeto Mimir

## Agente central

O agente main possui a identidade Mimir.

Ele coordena tarefas, consulta memória e direciona agentes especializados.

## Memória operacional

O memory-core nativo do OpenClaw mantém contexto operacional de curto prazo.

Características confirmadas:

- Backend builtin
- Banco SQLite local
- Busca híbrida
- FTS habilitado
- Embeddings locais
- Vetores com 768 dimensões

O SQLite não representa a fonte definitiva da memória permanente.

## Memória permanente

O PostgreSQL representa a fonte de verdade.

Componentes:

- Banco mimir_memory
- PostgreSQL 17
- Extensão pgvector
- Evidências e proveniência
- Controle de estado
- Escopo por agente, projeto e cliente
- Registro de eventos
- Auditoria
- Aprovação humana

## Consulta semântica

O plugin mimir-memory registra a ferramenta mimir_memory_search.

A ferramenta executa o cliente controlado:

tools/memory/mimir-semantic-search.mjs

O acesso ao banco ocorre pela role mimir_search.

A autenticação local usa peer para o usuário openclaw.

A role não possui SELECT direto nas tabelas.

A consulta ocorre por função controlada do banco.

## Fluxo da memória

1. Captura da sessão.
2. Registro diário.
3. Extração de fatos, decisões e restrições.
4. Consolidação em dry run.
5. Detecção de duplicidades.
6. Detecção de contradições.
7. Geração de arquivo reviewed.
8. Cálculo do SHA-256.
9. Revisão humana.
10. Inclusão como candidate.
11. Aprovação humana.
12. Promoção para active.
13. Geração local do embedding.
14. Teste de recuperação semântica.
15. Auditoria.
