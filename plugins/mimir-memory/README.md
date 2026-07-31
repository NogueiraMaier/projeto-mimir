# Mimir Memory 0.2.6

Plugin misto do Projeto Mimir.

Funções:

1. Mantém a ferramenta opcional `mimir_memory_search`.
2. Observa mensagens recebidas pelo hook `message_received`.
3. Executa a camada de evidência v4 em modo sombra.
4. Não modifica prompt, resposta, sessão ou PostgreSQL.
5. Não grava pergunta, resposta, evidência, remetente ou canal.

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

O PostgreSQL usa a role `mimir_search`, socket local, transação somente leitura,
`statement_timeout=60000` e `lock_timeout=5000`. O cliente `psql` recebe um
ambiente restrito e um limite externo de 75 segundos.

As tipagens @types/node 24.13.3 e undici-types 7.18.2 ficam locais no plugin.
O Vitest 4.1.9 vem da instalação compartilhada do OpenClaw. Nenhuma dependência
é baixada durante a atualização.

O manifesto declara `activation.onStartup`, `contracts.tools` e
`toolMetadata.mimir_memory_search.optional`. A validação combina testes,
compilação, importação estrutural e `plugins inspect --runtime`.
