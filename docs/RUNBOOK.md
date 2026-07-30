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
