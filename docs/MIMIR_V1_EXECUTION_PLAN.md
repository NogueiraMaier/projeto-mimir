# Plano Mestre de Execução — Mímir v1

Data de consolidação: 2026-09-24

Este documento é a lista mestre de atividades do Projeto Mímir v1. Ele existe para evitar perda de contexto, repetição de trabalho e mudanças fora de ordem. O estado detalhado de cada etapa deve ser atualizado aqui antes de avançar para a próxima fase.

## Regras de execução

1. Desenvolvimento e correção ficam na máquina local `gentoo-Dragon_IA`, usuário `jarvisdev`.
2. O VPS `gentoo-Dragon_vm` é usado para validação isolada, integração e futura implantação controlada.
3. O workspace ativo `/var/lib/openclaw/workspace` não deve receber `checkout`, `reset`, `clean`, `stash` ou troca de branch durante experimentos.
4. Validações no VPS devem usar checkout isolado em `/var/tmp` quando possível.
5. Nenhuma migration pode ser aplicada em ambiente persistente antes de existir versionada no Git.
6. Nenhuma alteração em produção deve ser feita sem autorização explícita e sem plano de rollback/restauração.
7. Cada etapa precisa registrar: precondições, ação, evidência, resultado, impacto e próximo passo.
8. PRs permanecem Draft até revisão final. Não fazer merge automaticamente.
9. Segredos, chaves privadas e credenciais não entram no Git.
10. Equipamentos reais começam em READ; EXECUTE só depois de homologação e aprovação específica.

## Origem desta rodada de correções

Durante uma atualização de documentação relacionada ao Maestro foi identificado que o estado documentado do Mímir não correspondia integralmente ao estado real do runtime e do banco. A partir daí foi aberta uma revisão técnica completa do Mímir antes de retomar a documentação superior.

A documentação do Maestro deve ser retomada somente após a estabilização dos marcos P0/P1 abaixo, para que descreva o Mímir real e não um estado histórico.

## Estado consolidado

### P0 — Integridade histórica e versionamento

- [x] Recuperar migrations de memória 009–012 a partir das fontes históricas.
- [x] Conferir SHA-256 das oito fontes apply/dry-run recuperadas.
- [x] Versionar 009–012 no repositório.
- [x] Renumerar a migration operacional conflitante de 009 para 013.
- [x] Fazer a 013 exigir versão 12 e recusar reaplicação silenciosa.
- [x] Registrar regra: nenhuma migration em ambiente persistente antes de existir no Git.
- [ ] Resolver a ausência histórica da migration 001 no Git ou documentar bootstrap canônico equivalente.

### P0 — Validador e segurança da branch operacional

- [x] Corrigir o validador para respeitar least privilege de `mimir_app` em `schema_version`.
- [x] Tratar `dist/index.js` ausente em source checkout como PARTIAL quando `dist/` for artefato de build ignorado/não versionado.
- [x] Testes locais aprovados.
- [x] Validação read-only no VPS concluída com 0 failed checks.
- [x] Produção permaneceu sem migration 013 e sem role `mimir_ops`.

### P0 — Runtime real do OpenClaw / memória nativa

- [x] Confirmar OpenClaw 2026.9.5 ativo via OpenRC.
- [x] Confirmar configuração válida.
- [x] Confirmar plugin `mimir-memory` carregado em runtime.
- [x] Confirmar versão runtime do plugin 0.2.6.
- [x] Aceitar explicitamente as capacidades atuais do plugin.
- [x] Identificar que embeddings locais antigos estavam incompatíveis com o runtime atual.
- [x] Configurar provider oficial `llama-cpp` em modo Managed local server para embeddings.
- [x] Manter o modelo de chat atual inalterado durante essa configuração.
- [x] Confirmar `embeddingProbe.ok=true`, runtime ready e 768 dimensões.
- [x] Fazer backup consistente do SQLite antes de reconstruir o índice.
- [x] Reindexar memória nativa com sucesso.
- [x] Confirmar 9/9 arquivos, 77 chunks, `dirty=false`, índice vetorial complete, `semanticAvailable=true` e `indexIdentity.status=valid`.
- [ ] Corrigir metadata drift do plugin: runtime 0.2.6 versus Recorded version 0.1.0, sem reinstalação cega.
- [ ] Definir `plugins.allow` explicitamente para plugins externos confiáveis, eliminando autoload implícito.

### P0 — Migration operacional 013 em laboratório isolado

- [x] Confirmar produção em versões 1–12, sem versão 13.
- [x] Confirmar `mimir_ops` ausente em produção.
- [x] Confirmar extensões `pgcrypto` e `vector`.
- [x] Criar cluster PostgreSQL 17 temporário em `/var/tmp/mimir-pg13-lab`.
- [x] Restaurar somente schema real + `schema_version`, sem copiar memórias/sessões.
- [x] Aplicar `013_operational_inventory.sql` somente no laboratório.
- [x] Confirmar versões 1–13 no laboratório.
- [x] Confirmar 15 tabelas `ops_*`.
- [x] Confirmar `mimir.ops_api(jsonb)`.
- [x] Confirmar identidade `mimir_ops` criada no schema como desabilitada.
- [x] Confirmar role cluster-global `mimir_ops` ainda ausente.
- [x] Confirmar novamente produção intacta: versão 13=false, role `mimir_ops`=false.
- [x] Aplicar e validar `013_operational_role.sql` somente no cluster temporário.
- [x] Verificar grants mínimos efetivos da role `mimir_ops`.
- [x] Verificar ausência de SELECT/INSERT/UPDATE/DELETE direto nas tabelas ops.
- [x] Validar autenticação/identidade peer de laboratório sem reutilizar a identidade do OpenClaw.
- [x] Testar a API `mimir.ops_api(jsonb)` com dados sintéticos.
- [ ] Testar constraints e rejeições de segurança com casos negativos.
- [ ] Testar fluxo READ sintético completo.
- [ ] Testar fluxo EXECUTE somente com dublês/simulação, sem equipamento real.
- [ ] Testar backup/restauração do laboratório.
- [ ] Desligar e remover o cluster temporário somente após coleta de evidências.

### P1 — Memória permanente PostgreSQL

- [ ] Fechar escrita controlada do cliente de ingestão de sessões, hoje ainda parcial/dry-run.
- [ ] Validar consolidação local de sessões de ponta a ponta.
- [ ] Validar deduplicação.
- [ ] Validar detecção de contradições.
- [ ] Validar revisão humana.
- [ ] Validar fluxo candidate → active.
- [ ] Validar geração de embedding e recuperação semântica após promoção.
- [ ] Validar auditoria/proveniência.
- [ ] Integrar `memory_handoff` operacional com o fluxo humano de memória, sem promoção automática.

### P1 — Camada operacional

- [ ] Demonstrar backup/restauração real por adapter.
- [ ] Definir reconciliação de intervenção interrompida.
- [ ] Definir política de retenção de evidências/relatórios.
- [ ] Homologar primeiro equipamento de laboratório em READ.
- [ ] Homologar `set-hostname` transitório no adapter generic-linux em laboratório.
- [ ] Manter MikroTik inicialmente em diagnóstico/READ.
- [ ] Só depois ampliar adapters para MikroTik EXECUTE, FiberHome, H3C, Intelbras e outros.

### P1 — Reprodutibilidade e release

- [ ] Atualizar STATUS/ROADMAP/OPERATIONS/RUNBOOK conforme cada marco concluído.
- [ ] Adicionar CI para testes de memória, operações, validador, plugin e lint/syntax.
- [ ] Executar suíte completa em checkout limpo.
- [ ] Testar restauração a partir dos artefatos/versionamento disponíveis.
- [ ] Criar checklist final de segurança.
- [ ] Revisar PR #1.
- [ ] Retirar Draft somente após validação final.
- [ ] Merge somente com autorização explícita.
- [ ] Criar tag estável da v1.
- [ ] Retomar e concluir a documentação do Maestro usando o estado final validado do Mímir.

## Checkpoint atual

**Checkpoint MIMIR-V1-013-LAB-01 — concluído.**

A migration `013_operational_inventory.sql` foi aplicada com sucesso apenas em cluster PostgreSQL temporário. O laboratório ficou em versões 1–13, com 15 tabelas operacionais e `mimir.ops_api(jsonb)` presente. A identidade lógica `mimir_ops` permanece desabilitada e a role cluster-global ainda não foi criada.

Produção continua em versões 1–12, sem `mimir_ops`.

**Próxima atividade autorizável:** validar `013_operational_role.sql` e os grants no mesmo cluster temporário, mantendo produção intocada.

## Evidências relacionadas

- `docs/recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md`
- `docs/review/operations/2026-09-22.md`
- `docs/review/operations/2026-09-24.md`
- `docs/STATUS.md`
- `docs/ROADMAP.md`
- `docs/OPERATIONS.md`
- `docs/RUNBOOK.md`


## Checkpoint MIMIR-V1-013-LAB-02 — concluído

A segunda metade da migration operacional 013 foi validada exclusivamente no cluster PostgreSQL temporário.

Resultados:

- `013_operational_role.sql` aplicada com COMMIT no laboratório;
- role `mimir_ops` criada no cluster temporário;
- atributos: LOGIN=true, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS, CONNECTION LIMIT 3;
- CONNECT no banco de laboratório: true;
- USAGE no schema `mimir`: true;
- EXECUTE em `mimir.ops_api(jsonb)`: true;
- EXECUTE nas funções internas `ops_assert_identity`, `ops_assert_object` e `ops_device_document`: false;
- tabelas `ops_*` com DML direto efetivo para `mimir_ops`: 0;
- USAGE nas sequences operacionais: false;
- identidade registrada como `peer:mimir-ops`, permanecendo `enabled=false`;
- SELECT direto em `mimir.ops_clients`: bloqueado;
- chamada da API com identidade ainda não habilitada: bloqueada;
- produção permaneceu em schema_version 1–12 e sem role `mimir_ops`.

**Próxima atividade:** validar identidade peer dedicada no laboratório e exercitar `mimir.ops_api(jsonb)` com dados sintéticos, incluindo casos negativos, sem reutilizar a identidade `openclaw`.


## Checkpoint MIMIR-V1-013-LAB-03-PREFLIGHT — concluído

Preflight de autenticação peer no laboratório concluído sem alterações no host de produção:

- usuário Linux `mimir-ops`: ausente;
- HBA do cluster temporário ainda usa `trust` para conexões locais;
- `pg_ident.conf` do laboratório: vazio;
- conexão administrativa atual: `current_user=postgres`, `session_user=postgres`, `system_user=NULL`, conforme esperado sob `trust`;
- identidade operacional cadastrada no schema: `db_role=mimir_ops`, `authentication_identity=peer:mimir-ops`, `enabled=false`.

Decisão de segurança: não criar ainda o usuário Linux persistente `mimir-ops` no VPS apenas para o laboratório. O próximo teste deve validar o mecanismo peer usando uma identidade sintética restrita ao cluster temporário; a identidade definitiva `peer:mimir-ops` só será provisionada no host durante a implantação autorizada.


## Checkpoint MIMIR-V1-013-LAB-03 — concluído

Autenticação peer foi validada exclusivamente no cluster PostgreSQL temporário, sem criação da conta Linux definitiva `mimir-ops`.

Configuração sintética de laboratório:

- usuário Linux usado para o teste: `jarvisdev`;
- role PostgreSQL: `mimir_ops`;
- mapeamento `pg_ident`: `jarvisdev -> mimir_ops`;
- HBA alterado somente no cluster temporário;
- conexão administrativa via peer confirmou `system_user=peer:postgres`;
- conexão operacional confirmou `current_user=mimir_ops`, `session_user=mimir_ops`, `system_user=peer:jarvisdev`;
- API permaneceu bloqueada enquanto a identidade lógica estava desabilitada;
- SELECT direto permaneceu bloqueado.

Conclusão: peer authentication + pg_ident + least privilege funcionam no desenho esperado. A identidade definitiva `peer:mimir-ops` ainda não foi provisionada no host real.

**Próxima atividade:** habilitar temporariamente `peer:jarvisdev` somente no laboratório, exercitar `mimir.ops_api(jsonb)` com dados totalmente sintéticos e depois executar casos negativos.


## Checkpoint MIMIR-V1-013-LAB-04 — concluído

A API operacional foi exercitada com identidade peer sintética habilitada somente no laboratório e com dados totalmente sintéticos.

Fluxo executado sob `set -euo pipefail`:

- identidade temporária do laboratório alterada para `peer:jarvisdev` e habilitada;
- conexão como `mimir_ops` via peer confirmada;
- `inventory.add` de cliente sintético concluído;
- `inventory.add` de site sintético concluído;
- `inventory.add` de dispositivo `generic-linux` em modo READ concluído;
- acesso SSH sintético associado ao dispositivo;
- `inventory.list` de clientes concluído;
- `inventory.show` do dispositivo concluído;
- SELECT direto nas tabelas ops continuou bloqueado;
- `trap` restaurou a identidade lógica para `peer:mimir-ops`, `enabled=false`;
- produção permaneceu com `schema_version=1..12` e sem role `mimir_ops`.

O fato de o script ter alcançado as verificações finais sob `set -e` confirma que as chamadas anteriores da API não retornaram erro SQL.

**Próxima atividade:** executar casos negativos da API no mesmo laboratório: campos desconhecidos/segredos, inconsistência rede/IP, dependência entre clientes, plano adulterado e tentativa de EXECUTE sem autorização.
