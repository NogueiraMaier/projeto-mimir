# Mimir Memory 0.2.7

Plugin misto do Projeto Mimir.

Funções:

1. Mantém a ferramenta opcional `mimir_memory_search`.
2. Observa mensagens recebidas pelo hook `message_received`.
3. Executa a camada de evidência v4 em modo sombra.
4. Não modifica prompt, resposta, sessão ou PostgreSQL.
5. Não grava pergunta, resposta, evidência, remetente ou canal.

## Consulta permanente

A ferramenta `mimir_memory_search` usa o provider local de embeddings registrado
pelo OpenClaw 2026.9.5. O embedding da consulta é gerado pelo `llama-server`
gerenciado através do lifecycle nativo do host; o plugin não carrega mais
`node-llama-cpp` em processo.

O helper `tools/memory/mimir-semantic-search.mjs` recebe por `stdin` somente um
request JSON já contendo o vetor validado de 768 dimensões e executa a busca
controlada em `mimir.search_active_memory(...)`.

O processo PostgreSQL recebe ambiente mínimo. Por padrão:

- `PGHOST=/run/postgresql`;
- `PGPORT=5432`;
- `PGDATABASE=mimir_memory`;
- `PGUSER=mimir_search`.

Para uma topologia remota futura, o serviço do Gateway pode definir apenas os
overrides dedicados `MIMIR_MEMORY_PGHOST`, `MIMIR_MEMORY_PGPORT`,
`MIMIR_MEMORY_PGDATABASE` e `MIMIR_MEMORY_PGUSER`. Variáveis PostgreSQL genéricas
do processo do Gateway não são herdadas automaticamente pelo helper. Autenticação
remota continua sendo requisito operacional separado; o plugin não recebe senha,
token ou DSN embutido.

## Evidência em modo sombra

O diagnóstico fica em:

`/var/log/openclaw/mimir-evidence-shadow.jsonl`

Cada registro contém decisão, escopo factual, `memory_key`, similaridade da
memória efetivamente associada, contagem de candidatos, tempos, descartes
agregados e motivo técnico. `observed_at` registra o horário de recebimento.

Controles operacionais:

1. Uma avaliação ativa por vez.
2. Três consultas pendentes no máximo.
3. Expiração da fila após sessenta segundos.
4. Descartes agregados antes da gravação.
5. Ambiente mínimo sem herdar tokens do Gateway.
6. Encerramento do grupo de processos com SIGTERM e SIGKILL.
7. Limite de 64 KiB para a resposta HTTP do verificador.
8. Limite interno de 20 MiB para o JSONL.
9. Logrotate diário ou após 10 MiB em cada execução do Logrotate.
10. Permissão 0600 reaplicada ao arquivo de log.

O classificador bloqueia solicitações de senhas, credenciais, tokens, chaves e
segredos antes do embedding. Termos como `tokenizador` não acionam o bloqueio.

O verificador local recebe a pergunta e as evidências recuperadas. Uma decisão
`supported` exige escopo, chave e evidência coerentes. Perguntas negativas,
históricas, hipotéticas e comparativas não recebem suporte por aproximação.

A atualização 0.2.7 corrige somente o caminho explícito de
`mimir_memory_search`. A avaliação em modo sombra permanece um fluxo separado e
deve ser revalidada independentemente antes de ser considerada saudável.

As tipagens @types/node 24.13.3 e undici-types 7.18.2 ficam locais no plugin.
O Vitest 4.1.9 vem da instalação compartilhada do OpenClaw. Nenhuma dependência
é baixada durante a atualização.

O manifesto declara `activation.onStartup`, `contracts.tools` e
`toolMetadata.mimir_memory_search.optional`. A validação combina testes,
compilação, importação estrutural e `plugins inspect --runtime`.

## Testes no servidor de desenvolvimento

Os scripts `npm test` e `npm run build` procuram Vitest/TypeScript nas dependências
locais, em `/opt/openclaw`, em `/opt/openclaw-release` e no cliente compartilhado
`~/.local/share/openclaw-client/node_modules`. Não executam instalação nem
download. Isso permite compilar no PcIA sem criar `node_modules` no checkout.
Vitest continua obrigatório para `npm test`; se ele não estiver disponível, o
script falha sem instalar nada.

A versão 0.2.7 requer OpenClaw 2026.9.5 ou superior porque depende do registry de
embedding providers e do lifecycle `api.runtime.llm.acquireLocalService()` para
usar o `llama-server` gerenciado.

O pacote OpenClaw 2026.9.5 exporta
`openclaw/plugin-sdk/embedding-providers` em runtime, mas não publica um
`types` mapping para esse subpath. O plugin mantém
`src/openclaw-embedding-providers.d.ts` como shim mínimo, copiado do contrato
estrutural da mesma versão do host, somente para compilação TypeScript. O runtime
continua vindo do OpenClaw instalado; nenhuma implementação é vendorizada.

A revisão offline não comprova carregamento no Gateway nem acesso real ao
PostgreSQL. A implantação no VPS exige validação separada e não altera por si só
as políticas de tools, Telegram ou produção PostgreSQL.
