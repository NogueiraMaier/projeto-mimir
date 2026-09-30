# Mímir v1 — validação de restauração — 2026-09-30

Checkpoint:

`MIMIR-V1-P1-RESTORE-01`

Status:

`PASS / CLOSED`

Branch:

`feat/mimir-operational-foundation`

Validated/base HEAD:

`181a859e952a7111da2efe72b9a90d8678d1ef98`

## Objetivo

Validar, em PostgreSQL 17 isolado, a recuperação do baseline de memória v1
até `schema_version 12` por dois caminhos independentes:

1. custom-format dump PostgreSQL disponível;
2. reconstrução exclusiva pelos artefatos versionados no Git.

Nenhum restore foi executado sobre produção.

## Artefatos versionados

Bootstrap:

`tools/memory/bootstrap/memory_v1_canonical.sql`

Migrations:

`002..012`

Manifest SHA-256 bootstrap/migrations:

`034253f6f6e36b1758d567e020e3d9c2839355fc40a3c150293833c879ca3164`

## Dump histórico pré-014

Arquivo disponível durante a validação:

`/var/tmp/mimir_memory-pre014-20260927T025520Z.dump`

SHA-256 validado:

`82c9ecc10835f47555ee4770bb7f7533e14b32b6876b6bc3a0dcbb92ffd0e2f4`

Archive PostgreSQL:

- `pg_restore --list`: PASS;
- entradas observadas: 88.

## RESTORE-A — custom-format dump

LAB descartável:

`/var/tmp/mimir-pg17-restore-lab`

Porta lógica:

`55434`

TCP:

desabilitado.

### Falhas esperadas preservadas

Primeira tentativa:

`role "mimir_owner" does not exist`

Segunda tentativa após provisionamento parcial:

`role "mimir_reviewer" does not exist`

Conclusão:

o custom-format dump é válido, porém não inclui as roles cluster-global
necessárias ao banco.

Pré-requisitos globais identificados:

- `mimir_owner`;
- `mimir_app`;
- `mimir_reviewer`;
- `mimir_human`;
- `mimir_embedder`;
- `mimir_search`;
- membership `mimir_reviewer -> mimir_human`.

Após provisionamento fiel das roles no LAB:

- `pg_restore`: RC 0;
- schema versions: `1..12`;
- schema owner: `mimir_owner`;
- tables: 8;
- views: 2;
- functions: 7;
- `mimir_app` schema USAGE: true;
- SELECT direto de `mimir_app` em `session_sources`: false;
- EXECUTE de `mimir_app` em `ingest_session`: true;
- `reviewer_identities`: 1;
- `session_sources`: 0;
- `memory_events`: 0;
- `memory_records`: 0.

Resultado:

`RESTORE-A = PASS`

## RESTORE-B — reconstrução pelo Git

LAB descartável:

`/var/tmp/mimir-pg17-git-restore-lab`

Porta lógica:

`55435`

Fonte:

`181a859e952a7111da2efe72b9a90d8678d1ef98`

Guard:

`HEAD == origin/feat/mimir-operational-foundation`

Resultado:

`PASS`

Procedimento:

1. banco novo `mimir_memory`;
2. bootstrap canônico v1;
3. migrations `002..012` em sequência.

Resultado final:

`schema_version = 1,2,3,4,5,6,7,8,9,10,11,12`

Resultado:

`RESTORE-B = PASS`

## Falhas/correções do RESTORE-B

O primeiro source guard Git foi executado por identidade diferente de
`jarvisdev` e foi corretamente recusado com `dubious ownership`.

Correção:

Git foi executado pela identidade proprietária correta. Nenhum
`safe.directory` foi adicionado.

O primeiro bootstrap com `psql -f` falhou porque `postgres` não podia
atravessar `/home/jarvisdev`.

Correção:

as permissões do checkout não foram ampliadas. Root abriu os arquivos SQL e
os forneceu ao `psql` por stdin.

## RESTORE-A x RESTORE-B

Resultado:

`PASS`

Schema completo, owners e ACLs:

`d99b7f5d020965c1dd82ab5efe9131a7808610056631caa3031fc2e1c9bb4bae`

Schema-version semantics:

`04f7c267b005a107097210a35af1a56a004e197201a8247b3280514c7cf74f86`

Seed/data contract:

`a817b1581df8550dd1245c9afe130b75f5622a51e238371ec7fd5afd5d3cc008`

Cluster-global role contract:

`b4ba2051cf0a44fee838eb19f0c3a52f3a9bcb64701078fe1561ca3cac2e2e2c`

Database owner / role settings:

`e8d6e59f1006acbdd5bbf77e2ad6d34b8ed8dc1b7eb7ea19bc5a9a755a1b55d5`

Todos os pares RESTORE-A/RESTORE-B comparados tiveram conteúdo idêntico.

## Cleanup

Os clusters `55434` e `55435` foram parados de forma controlada e removidos.

Resultado:

`RESTORE LAB CLEANUP = PASS`

## LAB 014 preservado

O laboratório histórico separado permaneceu fora do escopo de alteração.

Path:

`/var/tmp/mimir-pg14-lab`

Porta:

`55433`

Estado observado após o cleanup dos LABs de restore:

`RUNNING`

Data directory:

`/var/tmp/mimir-pg14-lab/data`

Schema versions:

`1,2,3,4,5,6,7,8,9,10,11,12,14,15,16`

O RESTORE-01 não iniciou, parou, reiniciou ou modificou esse LAB.

## Produção

Estado final read-only:

`schema_version = 1..12`

`mimir_ops = false`

Produção permaneceu inalterada.

## Limites

Este checkpoint prova recuperação reprodutível do baseline de memória v1
`1..12` com os artefatos atualmente disponíveis.

Não prova:

- restore da produção;
- recuperação de dados reais de produção;
- deployment;
- migrations 014/015/016 em produção;
- autorização para remover Draft;
- autorização para merge;
- autorização para tag estável.

## NEXT_ACTION

Criar o checklist final de segurança da v1.
