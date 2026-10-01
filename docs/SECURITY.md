# Segurança do Projeto Mimir

## Princípios

- Menor privilégio
- Separação de funções
- Aprovação humana
- Auditoria
- Proveniência
- Isolamento
- Backup testado
- Reversão documentada

## Segurança conversacional e conteúdo não confiável — proposta

A especificação arquitetural completa está em
[CONVERSATIONAL_SECURITY.md](CONVERSATIONAL_SECURITY.md) e a matriz adversarial
em [AI_SECURITY_TEST_MATRIX.md](AI_SECURITY_TEST_MATRIX.md).

Invariante de projeto:

> Todo conteúdo externo é DADO NÃO CONFIÁVEL.

Isso inclui mensagens de canais, voz/STT, documentos, OCR, web, APIs, RAG,
resultados de ferramentas e conteúdo gerado por outros agentes/modelos.

Confiança de origem não equivale a autorização. O modelo não autoriza a própria
ação, prompt não amplia capability e controles críticos precisam continuar
efetivos mesmo se o LLM estiver comprometido.

Status: **PROPOSTA PARA IMPLEMENTAÇÃO**. Não declarar prompt-injection defense,
output DLP, policy engine, cross-channel identity, model-routing enforcement ou
a suíte T-AI-001..035 como implementados até existir evidência reproduzível.

## Controle da memória

O agente main possui consulta controlada à memória permanente.

O agente main não possui escrita direta nas tabelas do PostgreSQL.

Nenhuma memória candidate recebe promoção automática.

Somente registros revisados e aprovados recebem status active.

Os embeddings são gerados localmente.

## Restrições do agente principal

Não liberar ao agente main:

- Shell arbitrário
- Execução arbitrária de processos
- Leitura irrestrita do sistema
- Escrita irrestrita
- Edição irrestrita
- Credenciais administrativas
- Acesso direto às tabelas da memória


## Captura de sessões

- Usar somente interfaces suportadas do OpenClaw para sessões atuais:
  `sessions --json` + `chat.history`
- Não acessar diretamente o schema SQLite privado do OpenClaw
- Aceitar somente sessões concluídas de classes explicitamente validadas
- Exigir `senderIsOwner=true` em toda mensagem user; ausência ou false bloqueia
- Exigir `id`, `seq` e timestamp em toda mensagem user/assistant elegível
- Exigir IDs únicos nas mensagens elegíveis
- Exigir `seq` único e estritamente crescente nas mensagens elegíveis
- Aceitar somente texto user/assistant
- Excluir system, toolResult, thinking e toolCall
- Bloquear padrões de segredos e credenciais
- Bloquear histórico truncado/omitido e paginação inconsistente
- Exigir que a quantidade final corresponda exatamente a `totalMessages`
- Não exibir mensagens durante inventário ou dry run
- Não versionar sessões, transcrições ou arquivos de staging
- Manter qualquer staging futuro fora do workspace Git
- Exigir revisão humana antes de qualquer promoção



## Fonte protegida das sessões

- Armazenar transcrições somente em `mimir.session_sources`
- Negar SELECT direto para `mimir_app`
- Para sessões atuais, gravar somente por `mimir.ingest_session_v2`
- Manter `mimir.ingest_session` apenas como legado sem EXECUTE para
  `mimir_app` após a migration 014
- Exigir autenticação peer do usuário `openclaw`
- Manter o evento com `classification=confidential`
- Não copiar a transcrição para `memory_events`
- Bloquear conteúdo/proveniência divergentes para o mesmo `session_id`
- Ler conteúdo para consolidação somente por
  `mimir.read_consolidation_source(uuid)`
- Não enviar sessões para API externa
- Consolidação confidential deve usar somente modelo local/loopback
- Exigir fluxo humano antes de candidate/active

## Dados fora do Git

Não versionar:

- Tokens
- Chaves de API
- Senhas
- Certificados privados
- Arquivos de ambiente
- Bancos SQLite
- Backups de configuração
- Dados privados de clientes

Arquivos protegidos:

- /etc/openclaw/gateway.env
- /var/lib/openclaw/.openclaw/openclaw.json
- Bancos locais dos agentes
- Arquivos de revisão contendo dados privados

## Cyber-Lab

O Cyber-Lab ficará isolado do servidor principal e da infraestrutura da Protec.

Toda ação exigirá:

1. Alvo formalmente autorizado.
2. Escopo definido.
3. Comandos limitados.
4. Aprovação humana.
5. Registro de execução.
6. Evidências.
7. Relatório técnico.

## Camada operacional — revisão local 2026-09-22

IMPLEMENTADO no repositório; NÃO VALIDADO EM PRODUÇÃO. A execução operacional
não é exposta pelo plugin de memória nem concedida permanentemente ao agente
main. CLI administrativo separado, identidade peer dedicada inicialmente
desabilitada, sem grants diretos nas tabelas ops e sem novos grants em memória.

A autorização vincula hash do plano, equipamento, operação, parâmetros e
objetivo. Não é assinatura criptográfica nem prova independente de aprovação
por duas pessoas. A conta Linux operacional e seu SSH Agent são fronteiras de
confiança; não compartilhar essa conta com entradas não confiáveis de agentes.

Operações remotas são um catálogo fechado. Configuração SSH do usuário é
ignorada; verificação de host é obrigatória; não há senha, forwarding, proxy ou
shell local. Há timeouts e limites durante a leitura de stdout/stderr. Não há
export de configuração MikroTik, comandos arbitrários ou rollback automático.

Falha na auditoria impede continuar; falha após alteração exige reconciliação
manual. O banco não permite finalização validada sem validação e observação de
inventário. Intentos/resultados e revisões de inventário são preservados; a API
não oferece exclusão de histórico. Retenção e proteção operacional do banco
precisam ser aprovadas antes de produção.

Redaction é recursiva, mas padrões não detectam todo segredo sem marcação.
Não cadastrar segredos em campos livres e não ampliar coleta para backups ou
configurações completas. Relatórios são confidenciais, com diretório local
0700 e arquivos 0600. `memory_handoff` é PARCIAL e exige revisão antes de
qualquer promoção; nenhum dado é enviado a API externa por esta camada.
