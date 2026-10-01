# Ingestão protegida de sessões v2

Status: proposta implementada no repositório, ainda não aplicada em produção.

Data: 26 de setembro de 2026.

## Contexto

O pipeline de memória criado em julho de 2026 assumia o armazenamento legado de
sessões do OpenClaw em:

\`\`\`text
agents/main/sessions/sessions.json
agents/main/sessions/<session_id>.jsonl
\`\`\`

O OpenClaw 2026.9.5 usa SQLite canônico por agente e expõe a leitura suportada
por CLI/Gateway. O coletor v2 foi validado em produção somente em modo read-only
usando:

\`\`\`text
openclaw sessions --agent main --limit all --json
gateway call chat.history
\`\`\`

A validação isolada retornou 18 sessões, 12 ready, 0 blocked, 6 skipped e
0 errors. As 12 sessões concluídas preservaram \`senderIsOwner=true\`, IDs,
sequência, timestamps e paginação.

## Decisão de arquitetura

A ingestão v2 não acessará diretamente o schema privado do SQLite do OpenClaw.

A fonte lógica passa a ser o par:

\`\`\`text
canonical session listing
+
chat.history
\`\`\`

O SQLite continua sendo implementação interna do OpenClaw. O Mímir consome
somente interfaces suportadas.

O conteúdo normalizado não será escrito em arquivos temporários nem impresso
pelo capturador. O futuro cliente de escrita deverá compartilhar a lógica de
captura em processo e enviar o conteúdo diretamente à função controlada do
PostgreSQL.

## Proveniência v2

Para cada sessão elegível, a proveniência deve registrar:

- \`session_id\`: UUID físico da sessão;
- \`session_key\`: chave canônica retornada pelo OpenClaw;
- \`source_kind=openclaw-chat-history-v2\`;
- \`source_ref=openclaw://agent/main/session/<session_id>\`;
- \`source_updated_at\`: timestamp da sessão fornecido pelo índice canônico;
- \`source_fingerprint_sha256\`: fingerprint estável da estrutura capturada;
- \`content_sha256\`: SHA-256 da transcrição normalizada user/assistant;
- \`collector_version=openclaw-chat-history-v2\`;
- \`id\` não vazio em toda mensagem user/assistant elegível;
- \`seq\` inteiro, único e estritamente crescente nas mensagens elegíveis;
- timestamp presente em toda mensagem elegível;
- \`totalMessages\` exatamente igual ao histórico reconstruído;
- contagens de mensagens e exclusões;
- \`classification=confidential\`;
- \`protected_source=true\`;
- \`content_exposed=false\`.

Não criar uma referência fictícia para \`.jsonl\` e não inventar \`mtime\` de
arquivo.

## Conteúdo elegível

A captura aceita somente:

- sessões \`status=done\`;
- classes explicitamente validadas:
  - Telegram;
  - HUD;
  - ACP bridge;
  - Maestro;
  - \`agent:main:main\`;
- mensagens \`user\` com \`senderIsOwner=true\`;
- mensagens \`assistant\`;
- conteúdo textual.

O processamento é fail-closed.

A sessão é bloqueada se houver:

- mensagem user com \`senderIsOwner=false\`;
- mensagem user sem owner marker;
- segredo/credencial detectável;
- truncamento/omissão de histórico;
- divergência de session key/id;
- \`id\`, \`seq\` ou timestamp ausente em mensagem elegível;
- \`id\` ou \`seq\` duplicado;
- \`seq\` fora de ordem;
- paginação inconsistente;
- divergência entre mensagens reconstruídas e \`totalMessages\`;
- hash divergente;
- conteúdo acima dos limites.

São excluídos:

- \`system\`;
- \`toolResult\`;
- blocos \`thinking\`;
- blocos \`toolCall\`;
- classes não autorizadas;
- sessões não concluídas.

## Contrato PostgreSQL

A migration proposta é:

\`\`\`text
tools/memory/migrations/014_api_session_ingestion_v2.sql
\`\`\`

Ela não foi aplicada em produção.

A migration:

1. preserva registros legados existentes;
2. adiciona metadados explícitos de proveniência à \`mimir.session_sources\`;
3. torna \`source_mtime\` e \`line_count\` campos exclusivos da origem
   \`legacy-jsonl\`;
4. cria \`mimir.ingest_session_v2(...)\`;
5. revoga de \`mimir_app\` o EXECUTE no ingresso legado
   \`mimir.ingest_session(...)\`;
6. mantém a transcrição somente em \`mimir.session_sources\`;
7. mantém \`memory_events.content\` nulo;
8. atualiza \`mimir.read_consolidation_source(uuid)\` para validar fontes
   legadas e v2;
9. não promove automaticamente nenhum registro para \`candidate\` ou
   \`active\`.

## Versionamento 013/014

A produção permanece em \`schema_version 1..12\`.

A versão 013 já está reservada no repositório para a camada operacional:

\`\`\`text
013_operational_inventory.sql
013_operational_role.sql
\`\`\`

Essa 013 permanece não aplicada em produção.

Para não renumerar evidência histórica nem acoplar memória à camada operacional,
a ingestão de sessão v2 usa a versão **014**, com dependência explícita somente
da memory migration 012.

A 014 pode existir com ou sem a 013 operacional. Se a versão 13 estiver presente,
a migration 014 exige que sua descrição corresponda exatamente à revisão
operacional conhecida. Assim, 014 não legitima uma versão 13 desconhecida.

Esse modelo trata \`schema_version\` como conjunto de capabilities versionadas
após a base 012, e não como autorização implícita para executar a 013.

## Idempotência

\`mimir.ingest_session_v2\` usa \`session_id\` como identidade física.

Repetir a mesma sessão com:

- mesma \`session_key\`;
- mesmo source fingerprint;
- mesmo content hash;

retorna o \`event_id\` existente.

O mesmo \`session_id\` com qualquer divergência de proveniência ou conteúdo é
rejeitado e a transação deve reverter.

Uma sessão já armazenada sob proveniência \`legacy-jsonl\` não é silenciosamente
convertida para v2.

## Segurança e privilégios

A função v2 exige:

\`\`\`text
session_user = mimir_app
system_user  = peer:openclaw
\`\`\`

\`mimir_app\` continua sem SELECT/INSERT/UPDATE/DELETE direto em
\`mimir.session_sources\`.

A migration não concede permissões ao agente main, não amplia Telegram,
não cria \`mimir_ops\` e não altera a migration operacional 013.

## Fluxo após ingestão

A ingestão não equivale a memória ativa.

O fluxo permanece:

\`\`\`text
session source
    ↓
memory_event confidential
    ↓
consolidação local
    ↓
candidate
    ↓
revisão humana
    ↓
active
    ↓
embedding local
\`\`\`

Nenhum conteúdo de sessão deve ser promovido automaticamente.

## Writer controlado v2

O writer repository-only está em:

```text
tools/memory/mimir-ingest-session-v2.py
```

Ele reutiliza o capturador v2 no mesmo processo. O capturador somente entrega a
transcrição normalizada internamente quando chamado com o caminho explícito do
writer; o CLI de captura continua sem serializar conteúdo.

Controles do writer:

- seleção exata por `session_key` + UUID canônico;
- sessão obrigatoriamente `done` e classe presente na allowlist validada;
- reuso integral dos guards de owner, segredo, truncamento e normalização;
- `expected-source-sha256` e `expected-content-sha256` obrigatórios;
- dry-run por padrão;
- dry-run emite um `approval_sha256` ligado a session id/key + fingerprints;
- escrita exige simultaneamente `--write` e `--approve <approval_sha256>`;
- escrita exige usuário Unix `openclaw`;
- somente socket Unix local é aceito;
- `/run/postgresql` é bloqueado sem `--allow-production` explícito;
- conteúdo não entra em argv, variável de ambiente ou staging: é codificado
  em memória e enviado ao `psql` somente via stdin;
- stdout contém somente metadados/hashes/event_id;
- nenhuma promoção para candidate/active ocorre pelo writer.

Testes repository-only:

```text
tools/memory/test_mimir_ingest_session_v2.py
tools/memory/validate-session-writer-v2-lab.sh
```

O primeiro cobre dry-run sem vazamento, hash mismatch, owner/secret guards e
transporte SQL sem plaintext. O segundo valida end-to-end no PostgreSQL lab:
dry-run → aprovação → write → replay idempotente → verificação persistida →
protected read → ausência de promoção automática → cleanup sintético.

Esses artefatos ainda precisam ser executados/validados no VPS após o commit
que os introduziu. Eles não estão implantados em produção.

## Validação obrigatória antes de produção

Antes de qualquer aplicação da 014:

1. backup/restauração validado;
2. PostgreSQL lab descartável em schema 1..12;
3. aplicação transacional da 014;
4. verificação de grants e identities;
5. ingestão v2 sintética sob identidade peer equivalente;
6. repetição idempotente;
7. conflito de content hash;
8. conflito de source fingerprint;
9. rejeição de classe não autorizada;
10. validação de segredo no cliente;
11. leitura por \`read_consolidation_source\`;
12. confirmação de ausência de \`candidate\` e \`active\` automáticos;
13. rollback/restore do laboratório.

A produção não deve receber a 014, writer ou agendamento sem autorização
explícita separada.
