# Mímir v1 — revisão técnica do PR #1

Data: 2026-10-01

Checkpoint:

`MIMIR-V1-P1-PR-REVIEW-01`

Branch:

`feat/mimir-operational-foundation`

Validated/base HEAD:

`115e39a3650ca5150e27c2326b3c6f7a569df62d`

## Resultado

`REVIEWED / RELEASE_BLOCKED`

A revisão técnica desta rodada foi concluída.

Isso significa que os findings concretos identificados durante esta passada
foram tratados e validados no escopo declarado.

Isso NÃO significa:

- aprovação de release;
- validação de produção;
- aceite de riscos residuais;
- autorização para retirar Draft;
- autorização para merge;
- autorização para tag estável;
- autorização para deployment.

## Estado observado do PR

No HEAD acima:

- PR #1: OPEN;
- PR #1: DRAFT;
- base: `e6785bb6166131b52a2096278f59874a14549c06`;
- changed files: 96;
- commits: 313;
- mergeable state observado: `clean`;
- GitHub checks atuais: 6/6 `success`;
- reviews nativos observados: 0;
- comentários nativos observados: 0.

Ausência de reviews/comentários nativos não é usada como evidência de
segurança. A evidência desta revisão é o código, os testes e os checkpoints
versionados.

## Findings tratados nesta rodada

### FINDING-01

Commit:

`4f08addaa3171b26a86d7412868c852d7b178d19`

Correção:

conteúdo confidential do `memory_handoff` deixou de ser passado em argv do
`psql`; o valor segue por stdin.

Resultado:

repository regression e CI PASS.

### FINDING-02

Commit:

`816c5c375d5fc2ab33a8df1a0c121f5b741b4a80`

Correção:

captura de sessão passou a falhar fechada quando `totalMessages` não
corresponde ao histórico reconstruído ou quando mensagens elegíveis não têm
proveniência mínima de id/seq/timestamp.

Resultado:

repository regression e CI PASS.

### FINDING-03

Commit:

`00dc48173ee7bd83c6da77b5f774d47600daae71`

Correção:

provider local de embedding passou a recusar redirects e deixou de expor body
de erro HTTP em diagnóstico.

Resultado:

testes Node específicos e CI PASS.

### FINDING-04

Commit:

`b1c079266c6a73c97516bbbcb2186ffa6a3ef4c3`

Correção:

proteção do socket PostgreSQL de produção passou de comparação lexical para
resolução canônica, bloqueando aliases/symlinks sem autorização explícita.

Resultado:

11 testes focados e 48 testes de memória PASS antes do commit; CI PASS.

### FINDING-05

Commit:

`23f165d0cc7566003a4b3d4a15cf056595a04e54`

Correção:

o modelo deixou de poder inventar um SHA-256 de evidência e tê-lo aceito apenas
pelo formato. O modelo fornece um excerpt textual; o consolidator confirma que
o excerpt é substring exata da fonte protegida e calcula o SHA-256 no código
confiável. O excerpt não é emitido no resultado canônico.

Resultado:

12 testes focados e 49 testes de memória PASS antes do commit; CI PASS.

Limite preservado:

o vínculo comprova que o excerpt veio da fonte; não transforma a interpretação
do modelo em fato validado. `UNTRUSTED_OBSERVATION` e revisão humana continuam
obrigatórios.

### FINDING-06

Commit:

`1b7a20a202221a87aecbcef0b9f14079d689574d`

Correção:

a proveniência de mensagens elegíveis passou a exigir também IDs únicos,
`seq` único e `seq` estritamente crescente.

Resultado:

5 testes focados e 50 testes de memória PASS antes do commit; CI PASS.

### FINDING-07

Commit:

`115e39a3650ca5150e27c2326b3c6f7a569df62d`

Correção:

contratos e documentação foram sincronizados com os hardenings de
proveniência e evidence binding atuais.

Resultado:

guards documentais PASS e CI PASS.

## Observações não bloqueantes da revisão

Permanecem registradas sem serem confundidas com controles já implementados:

- o harness repository-only do protected consolidator depende de isolamento de
  rede quando a porta canônica 18782 está ocupada pelo runtime real;
- evidence binding prova origem do excerpt, não verdade semântica da conclusão;
- hardening adicional de transporte PostgreSQL pode ser tratado separadamente
  sem reclassificar o caminho atual como escrita autorizada;
- gaps transversais de segurança conversacional permanecem conforme
  `docs/AI_SECURITY_GAP_INVENTORY.md`.

## Validação integrada ainda necessária

O FINDING-05 alterou o contrato entre o modelo e o consolidator.

O estado atual é:

`REPOSITORY_VALIDATED / REAL_MODEL_REVALIDATION_PENDING / NOT_DEPLOYED`

Portanto deve existir nova validação integrada sintética contra o Qwen real
`127.0.0.1:18782` antes de qualquer decisão futura de release relacionada ao
protected consolidator.

Essa revalidação:

- deve usar somente conteúdo sintético;
- deve manter PostgreSQL de produção fora do caminho;
- deve preservar `synthetic_residue=0`;
- deve manter zero promoção automática;
- não autoriza deployment.

## Blockers de release preservados

A revisão não altera a reconciliação de segurança de 2026-09-30.

Continuam:

- `RSK-P0-003` — OPEN / BLOCKER;
- `RSK-P0-004` — PARTIALLY_TREATED / production-release blocker;
- `RSK-P0-005` — OPEN / BLOCKER.

Também permanecem as restrições documentadas para segurança conversacional
transversal.

## Decisão

A atividade:

`Revisar PR #1`

pode ser registrada como concluída.

A atividade:

`Retirar Draft somente após validação final`

permanece pendente e atualmente bloqueada.

Continuam proibidos:

- Draft removal;
- merge;
- stable tag;
- production deployment;
- migrations 014/015/016 em produção;
- criação de `mimir_ops` em produção.

## NEXT_ACTION

Revalidar em LAB integrado sintético o protected consolidator após o
FINDING-05, usando o Qwen real em `127.0.0.1:18782`, mantendo o PR Draft e
produção intacta.

Depois dessa revalidação, retornar aos blockers formais de release; não
inferir autorização para removê-los.
