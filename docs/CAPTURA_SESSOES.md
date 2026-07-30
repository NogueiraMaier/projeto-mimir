# Captura segura de sessões do OpenClaw

Data da implementação: 30 de julho de 2026

## Objetivo

Identificar sessões concluídas aptas para o pipeline de memória sem exibir mensagens e sem gravar no PostgreSQL.

## Fonte autorizada

Diretório ativo:

    /var/lib/openclaw/.openclaw/agents/main/sessions

Arquivo aceito:

    UUID.jsonl

Arquivos excluídos:

- sessions.json como fonte de conteúdo
- trajectory.jsonl
- trajectory-path.json
- probe
- skills-prompts
- links simbólicos
- sessões sem status done

## Conteúdo aceito

- Mensagens do proprietário com role user
- Mensagens com role assistant
- Blocos de conteúdo com type text

## Conteúdo excluído

- toolResult
- toolCall
- mensagens de outros remetentes
- dados de trajetória
- configuração interna
- prompts de sistema
- metadados de ferramentas

## Controles de segurança

- Dry run como modo único desta etapa
- Nenhum conteúdo de mensagem na saída
- Nenhuma escrita no PostgreSQL
- Nenhuma escrita em staging
- Detecção de padrões de credenciais
- Bloqueio de conteúdo acima do limite configurado
- Validação do UUID da sessão
- Rejeição de links simbólicos
- Processamento restrito a arquivos regulares

## Validações

- Compilação Python
- Testes com sessões sintéticas
- Exclusão de trajectory
- Exclusão de toolResult
- Exclusão de remetente não proprietário
- Bloqueio de credencial sintética
- Dry run sobre o diretório ativo
- Verificação de saída sem conteúdo

## Limites desta etapa

O capturador ainda não grava eventos de memória.

O capturador ainda não envia conteúdo para API externa.

O capturador ainda não cria registros candidate.

Nenhuma promoção para active foi implementada.

## Próxima etapa

Criar a ingestão idempotente de sessões em área protegida e integrar o evento ao consolidador em dry run.

## Rastreabilidade

Comando para localizar o commit:

    git log -1 --oneline -- tools/memory/mimir-capture-sessions.py
