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
    git status --short &&
    git log --oneline --decorate -10 &&
    git tag --list
    '

## Regra de alteração

1. Criar backup de configurações externas ao Git.
2. Alterar somente o componente necessário.
3. Validar a sintaxe.
4. Executar o teste funcional.
5. Conferir os logs.
6. Revisar o diff.
7. Criar o commit.
8. Criar uma tag para marcos estáveis.
9. Enviar ao repositório remoto privado.
