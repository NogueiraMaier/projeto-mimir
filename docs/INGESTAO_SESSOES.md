# Ingestão protegida de sessões

## Estado atual — 26 de setembro de 2026

A implementação abaixo descreve o contrato v1 baseado em arquivo
`UUID.jsonl`. Ele permanece como histórico e não deve ser usado para novas
sessões do OpenClaw 2026.9.5.

O novo contrato API-based está proposto na migration:

```text
tools/memory/migrations/014_api_session_ingestion_v2.sql
```

Ela ainda **não foi aplicada em produção**.

A v2 substitui a proveniência fictícia de arquivo por:

```text
source_kind = openclaw-chat-history-v2
source_ref  = openclaw://agent/main/session/<session_id>
session_key = chave canônica do OpenClaw
```

e mantém a transcrição protegida em `mimir.session_sources`, com
`classification=confidential`, sem promoção automática.

A versão 013 continua reservada para a camada operacional independente. A 014
depende da memory migration 012 e valida explicitamente qualquer 013 presente.

Detalhes:
[SESSION_INGESTION_V2.md](SESSION_INGESTION_V2.md).


Data da implementação: 30 de julho de 2026

## Objetivo

Registrar sessões concluídas do OpenClaw sem liberar a transcrição para consulta direta ou API externa.

## Estrutura protegida

A transcrição fica em:

    mimir.session_sources

A role mimir_app não possui SELECT, INSERT, UPDATE ou DELETE nessa tabela.

## Evento de proveniência

Cada sessão gera um evento em mimir.memory_events com:

- event_type session_import
- source_type openclaw-session
- classification confidential
- content nulo
- metadados estruturais no payload
- referência ao arquivo UUID.jsonl

A transcrição não fica em memory_events.

## Função controlada

A escrita ocorre por:

    mimir.ingest_session()

A função exige:

- session_user igual a mimir_app
- system_user igual a peer:openclaw
- UUID válido
- sessão com mensagens elegíveis
- limite de 60000 caracteres
- SHA-256 correspondente ao conteúdo
- contagens estruturais válidas
- arquivo com data de modificação válida

## Idempotência

O mesmo session_id e o mesmo SHA-256 retornam o event_id existente.

O mesmo session_id com conteúdo diferente gera erro e reverte a transação.

## Bloqueio de API externa

A classificação confidential bloqueia o consolidador NVIDIA.

Nenhuma função de liberação ou reclassificação foi criada nesta etapa.

## Revisão humana

A transcrição não recebe promoção automática.

Uma etapa futura criará o fluxo local de extração, sanitização e autorização humana.

## Validações

- Backup completo do banco
- Aplicação transacional da migração
- Teste sintético com rollback
- Teste de idempotência
- Teste de conflito de SHA-256
- Verificação de privilégios
- Confirmação de ausência de eventos sintéticos
- Nenhuma sessão real importada
