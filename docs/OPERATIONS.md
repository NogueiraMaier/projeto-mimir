# Operações controladas do Mímir

Status: MVP implementado no repositório; não validado em equipamentos de produção.

## Objetivo

A camada operacional adiciona inventário, histórico de intervenções, evidências, relatórios e execução SSH com política explícita. Ela não concede autorização permanente ao agente central.

## Modos

- READ: diagnóstico somente.
- PLAN: gera plano sem executar alteração.
- EXECUTE: alterações exigem aprovação explícita.

Ações destrutivas permanecem bloqueadas mesmo com aprovação no MVP.

## Inventário persistente

A migration 009 cria clientes, sites, equipamentos, intervenções, ações, evidências e relatórios no PostgreSQL. Credenciais não são armazenadas; somente referências como ssh-agent, env:NOME ou file-ref:IDENTIFICADOR.

## Executor SSH

tools/ops/mimir_ops.py usa /usr/bin/ssh com BatchMode, StrictHostKeyChecking, known_hosts obrigatório, timeout, redaction de saída e classificação read/change.

## Adapters

- generic-linux
- mikrotik-routeros

O adapter MikroTik começa com inventário e diagnóstico. Operações de escrita específicas devem ser adicionadas somente com testes e rollback conhecido.

## Relatórios

Cada execução gera JSON estruturado e Markdown em reports/ops/ por padrão. Esse diretório deve permanecer fora do Git.

## Exemplos

Planejar inventário:

    cd tools/ops
    python3 mimir-ops.py plan examples/device-mikrotik.json

Inspecionar equipamento autorizado em READ:

    python3 mimir-ops.py inspect /caminho/device.json

Testar alteração sem executar:

    python3 mimir-ops.py execute /caminho/device.json "comando" --approve --dry-run

## Limites atuais

- nenhuma credencial é provisionada pelo projeto;
- nenhuma configuração de produção foi validada;
- backup e rollback automáticos por fabricante ainda são parciais;
- integração automática com a memória permanente ainda é uma etapa posterior;
- o PostgreSQL recebe o schema, mas o CLI do MVP ainda não persiste inventário diretamente no banco.
