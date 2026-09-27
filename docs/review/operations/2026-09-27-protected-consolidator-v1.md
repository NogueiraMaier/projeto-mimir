# Mímir — Protected Session Consolidator v1 — Repository Checkpoint

Data: 2026-09-27

Escopo: exclusivo do Projeto Mímir.

Estado: REPOSITORY_VALIDATED

## Branch e commits

Branch:

`feat/mimir-operational-foundation`

HEAD após os artefatos repository-only:

`6b2801bfa2f71375940ac28f643fad3a4344e712`

Commits desta implementação:

- `354aef9bf8a5381c5c7b5e0ee3f9baa1e3cd3ca5` — consolidator protected-source v1;
- `4753941c846fa2b35893c38dfb4c1383b37e28c4` — harness adversarial sintético;
- `6b2801bfa2f71375940ac28f643fad3a4344e712` — validator repository-only.

## Artefatos

- `tools/memory/mimir-consolidate-protected-v1.py`
- `tools/memory/test_mimir_consolidate_protected_v1.py`
- `tools/memory/validate-protected-consolidator-v1-repository.sh`

O consolidator NVIDIA legado não foi alterado. Ele continua separado e não é
autorizado para fontes `confidential/protected_source`.

## Controles implementados

O novo consolidator:

- opera somente em dry-run;
- não possui caminho de escrita em `candidate` ou `active`;
- lê a fonte por `mimir.read_consolidation_source(event_id)`;
- rejeita acesso ao socket de produção sem `--allow-production` explícito;
- aceita somente endpoint `http://127.0.0.1:18782/v1/chat/completions`;
- rejeita host, porta, path, credencial em URL, query e fragment divergentes;
- desativa proxy no cliente HTTP;
- rejeita redirects;
- fixa o model id do Qwen local validado;
- envia `chat_template_kwargs.enable_thinking=false`;
- não envia definição de tools;
- rejeita `tool_calls` e `function_call` na resposta;
- processa somente `choices[0].message.content`;
- ignora `reasoning_content` e não o inclui na saída;
- separa a fonte em envelope JSON marcado `UNTRUSTED_CONTENT`;
- fixa `CONFIDENTIAL`, `tool_use_allowed=false` e
  `memory_promotion_allowed=false`;
- valida binding de `event_id` e SHA-256 da fonte;
- usa schema de saída fechado;
- rejeita campos desconhecidos;
- fixa `trust_class=UNTRUSTED_OBSERVATION`;
- exige `requires_human_review=true`;
- aplica secret/output gate fora do LLM;
- limita tamanho de fonte, resposta, resumo e número de candidatos;
- emite somente metadados seguros e candidatos filtrados em stdout.

## Harness adversarial

O harness cobre:

- T-AI-002 — indirect prompt injection;
- T-AI-005 — secret extraction;
- T-AI-023 — memory poisoning;
- T-AI-024 — unauthorized memory promotion;
- T-AI-032 — output secret leakage;
- T-AI-033 — data minimization violation;
- T-AI-034 — unauthorized external-model disclosure.

Também cobre:

- campo desconhecido na saída;
- tool call indevida;
- presença de `reasoning_content` sem persistência/exposição.

## Evidência preliminar antes do versionamento

Os artefatos foram construídos e executados em workspace isolado da sessão antes
do versionamento.

Resultado observado:

```text
8 tests
OK
MIMIR-PROTECTED-CONSOLIDATOR-V1-REPOSITORY: PASS
```

Essa execução não é tratada como validação formal do HEAD Git, porque ainda não
foi repetida a partir de um checkout limpo do commit
`6b2801bfa2f71375940ac28f643fad3a4344e712`.

Por isso:

- componente = IMPLEMENTED_NOT_VALIDATED;
- casos T-AI acima = IMPLEMENTED_NOT_VALIDATED no registro canônico;
- nenhum checkpoint de laboratório foi declarado PASS nesta etapa.

## Produção

Nenhum runtime de produção foi alterado.

Não foram executados:

- migration 014;
- writer v2 em produção;
- consolidator em produção;
- sessão real;
- PostgreSQL de produção;
- alteração no OpenClaw Gateway;
- alteração no llama.cpp;
- alteração em equipamento real.

Produção permanece, conforme o último estado validado:

- schema_version 1..12;
- migration 014 ausente;
- role `mimir_ops` ausente.

## NEXT_ACTION

1. preparar ou revalidar o PostgreSQL lab isolado em schema 1..12,14;
2. provar que socket, porta e `data_directory` do lab não correspondem à produção;
3. validar o protected consolidator contra o lab e o Qwen real
   `127.0.0.1:18782`;
4. usar somente conteúdo sintético;
5. não usar sessão real;
6. não acessar PostgreSQL de produção;
7. não implantar migration 014, writer v2 ou protected consolidator.

## Validação formal repository-only

Checkpoint:

`MIMIR-V1-PROTECTED-CONSOLIDATOR-REPO-01 = PASS`

HEAD validado:

`3d119d4a8308c1dbaf9744c9f3c7f3b77a5a8c64`

Data: 2026-09-27

Condições observadas:

- checkout isolado;
- working tree limpo antes da execução;
- 8 testes executados;
- 8 testes aprovados;
- `CHECKPOINT_RC=0`;
- fake model isolado em network namespace;
- `127.0.0.1:18782` livre dentro do namespace de teste;
- llama.cpp real permaneceu em `127.0.0.1:18782` antes e depois;
- working tree permaneceu limpo após a execução;
- nenhuma sessão real foi utilizada;
- PostgreSQL de produção não foi acessado;
- migration 014 não foi aplicada em produção;
- writer v2 e protected consolidator continuam não implantados.

Próximo checkpoint permitido:

validar o consolidator contra PostgreSQL lab isolado 1..12,14 e Qwen real
`127.0.0.1:18782`, somente com conteúdo sintético.
