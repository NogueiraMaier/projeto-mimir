# Protected Consolidator v1 — Real-Model LAB

Data: 2026-09-27

Estado: `BLOCKED_BY_MODEL_TIMEOUT`

## Código sob teste

Branch:

`feat/mimir-operational-foundation`

Commit técnico:

`9e2e1c13e76cc60e4b383cc0898b54aeef2bcef0`

Consolidator SHA-256:

`45e68e31df5cf71f8e1253d28d2ef8f08cda39c2e1e0a497cd3940cf935b5a66`

Repository regression:

- 8/8 PASS;
- RC=0.

## Ambiente

PostgreSQL LAB:

- schema `1..12,14`;
- socket `/var/tmp/mimir-pg14-lab/socket`;
- port `55433`;
- sem listener TCP;
- `openclaw -> mimir_app -> peer:openclaw`.

Modelo:

- Qwen3-4B-Q4_K_M;
- endpoint `127.0.0.1:18782`;
- `/health` = OK.

## Tentativa 1

Resultado:

`POLICY_REJECT: resposta inválida da leitura controlada`

Causa:

wrapping Base64 PostgreSQL.

Cleanup:

`synthetic_residue=0`

## Correção

Commit:

`9e2e1c13e76cc60e4b383cc0898b54aeef2bcef0`

O SQL agora remove somente LF (`chr(10)`) criado pelo Base64 PostgreSQL.

`base64.b64decode(..., validate=True)` permanece estrito.

Regression harness passou 8/8.

## Tentativa 2

Resultado:

`consolidator_rc=1`

Diagnóstico seguro em cópia temporária:

`DEBUG_EXCEPTION_TYPE=TimeoutError`

`DEBUG_EXCEPTION_MSG=timed out`

Cleanup:

`synthetic_residue=0`

## Interpretação

O problema Base64 foi superado.

O bloqueador atual está na chamada HTTP ao modelo local.

O timeout atualmente escapa do tratamento específico e cai no handler genérico:

`ERRO: falha interna no consolidator protegido`

## Próximo teste autorizado

Antes de novo real-model LAB:

1. adicionar tratamento explícito para timeout;
2. adicionar teste repository-only;
3. validar repository-only novamente;
4. medir latência do Qwen separadamente;
5. não relaxar policy;
6. não aumentar timeout sem evidência;
7. continuar usando conteúdo exclusivamente sintético.

## Evidência de latência do modelo

Probe sintético controlado em `127.0.0.1:18782`:

- primeiro total: 44.351 s;
- warm 1: 32.324 s;
- warm 2: 30.927 s;
- warm 3: 32.104 s;
- prompt: 342 tokens;
- completion: 190 tokens;
- finish_reason: stop;
- reasoning_content: vazio.

O modelo não apresenta stall nesse payload. O timeout integrado ainda precisa
ser correlacionado ao request real do LAB antes de qualquer ajuste de limite.

## Root cause do timeout

Request exato do LAB capturado antes do modelo:

SHA-256:
`cb0a746384552ad20728a2cf6de5148bcd6045e68d5c5ba29db6c8868426f413`

Após 90 s de ociosidade do Qwen:

- HTTP 200;
- start transfer: 71.535620 s;
- total: 71.535960 s.

O harness usa timeout explícito de 60 s.

Root cause:

`Qwen CPU cold/idle latency > current 60 s model timeout`.

O modelo responde corretamente, porém pode exceder o orçamento temporal atual.
