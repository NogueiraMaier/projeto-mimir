# Runbook operacional

## Estado do serviço

    rc-service openclaw status

## Reinício autorizado

    rc-service openclaw restart

Não administrar o gateway pelo comando openclaw gateway restart.

## Validar configuração

    su - openclaw -s /bin/bash -c '
    cd /opt/openclaw &&
    node openclaw.mjs config validate
    '

## Inspecionar o plugin

    su - openclaw -s /bin/bash -c '
    cd /opt/openclaw &&
    node openclaw.mjs plugins inspect mimir-memory --runtime
    '

## Verificar memória nativa

    su - openclaw -s /bin/bash -c '
    cd /opt/openclaw &&
    node openclaw.mjs memory status --agent main --json
    '

## Estado do Git

    su - openclaw -s /bin/bash -c '
    cd /var/lib/openclaw/workspace &&
    git status --short --branch &&
    git log --oneline --decorate -10 &&
    git tag --list
    '

## Publicação no GitHub

Repositório remoto:

    git@github-projeto-mimir:NogueiraMaier/projeto-mimir.git

Branch principal:

    main

Enviar alterações validadas:

    cd /var/lib/openclaw/workspace
    git push origin main

Comparar os hashes local e remoto:

    cd /var/lib/openclaw/workspace
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(
        git ls-remote origin refs/heads/main |
        awk '{print $1}'
    )
    printf 'Local:  %s\n' "$local_commit"
    printf 'Remoto: %s\n' "$remote_commit"
    test "$local_commit" = "$remote_commit"


## Validar ingestão protegida

Versão do esquema:

    psql -X -d mimir_memory -c         "SELECT version, description FROM mimir.schema_version WHERE version = 8;"

Privilégios da fonte:

    psql -X -d mimir_memory -c         "SELECT has_table_privilege('mimir_app', 'mimir.session_sources', 'SELECT');"

A resposta esperada para SELECT é false.

Nenhuma sessão deve ser importada sem execução explícita do cliente de ingestão.

## Regra de alteração

1. Criar backup de configurações externas ao Git.
2. Alterar somente o componente necessário.
3. Validar a sintaxe.
4. Executar o teste funcional.
5. Conferir os logs.
6. Atualizar a documentação relacionada.
7. Auditar segredos e dados sensíveis.
8. Revisar o diff.
9. Adicionar somente os arquivos da etapa.
10. Criar o commit.
11. Criar uma tag para marcos estáveis.
12. Enviar ao repositório remoto público.
13. Comparar os hashes local e remoto.

## Validação operacional antes de implantação da 013

Estado: IMPLEMENTADO localmente, NÃO VALIDADO EM PRODUÇÃO. Os procedimentos
históricos de reinício e publicação acima não fazem parte da revisão local.
Nenhuma migration, configuração, reinício ou push foi executado nessa etapa.

Primeiro comando posterior, já no VPS e sob identidade peer autorizada:

```bash
cd /var/lib/openclaw/workspace
bash tools/validation/validate-vps-readonly.sh --db-user mimir_app
```

O validador não aplica SQL de alteração, não executa scripts de serviço, não
reinicia OpenClaw, não muda branch, não acessa equipamentos e não lê configuração
com segredos. Use `--skip-db` para excluir conexão PostgreSQL. Falhas devem ser
revisadas antes de qualquer correção. Presença de artefatos não confirma plugin
carregado; versão 13 registrada não identifica a revisão aplicada da migration.
Antes de consultar o histórico, o validador verifica SELECT em `schema_version`.
Sem esse privilégio, emite PARTIAL e exige inspeção administrativa read-only
separada para confirmar versões. Isso é esperado para `mimir_app` após a 009;
não conceder SELECT para eliminar o PARTIAL. Com leitura autorizada, verifica
a presença das versões 1–12 e informa separadamente a presença da 013.

O schema é separado do provisionamento cluster-global: `013_operational_inventory.sql`
cria apenas objetos; `013_operational_role.sql` cria `mimir_ops`, concede CONNECT
no banco corrente e aplica os grants mínimos. A role permanece inicialmente
desabilitada; revisão de schema, backup/restauração, grants e peer precisa
preceder a habilitação.
Não aplicar 013 sobre versão 13 existente: ela recusa reexecução deliberadamente.
A migration operacional exige a versão 12; as versões 009–012 pertencem à memória.

Consulta posterior de intervenção sob identidade operacional habilitada:

```bash
python3 tools/ops/mimir-ops.py ops history DEVICE_UUID
python3 tools/ops/mimir-ops.py ops report INTERVENTION_UUID --format markdown
```

Após timeout, perda de auditoria ou confirmação incerta da transação, não
repetir EXECUTE. Consultar o diário pelo UUID, verificar o dispositivo sob
nova autorização e registrar reconciliação administrativa preservando evidências.
Rollback é manual; backup implementado cobre apenas hostname em execução.
Procedimentos, simulações e requisitos: [OPERATIONS.md](OPERATIONS.md).

## Versionamento de migrations

Nenhuma migration pode ser aplicada a um ambiente persistente antes de
existir como arquivo versionado no repositório.

Recuperação histórica: [migrations 009–012](recovery/MEMORY_MIGRATIONS_009_012_RECOVERY.md).
