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

- Processar somente o diretório ativo do agente main
- Excluir arquivos trajectory e prompts de sistema
- Aceitar somente sessões concluídas
- Aceitar mensagens do proprietário e respostas do agente
- Excluir resultados e chamadas de ferramentas
- Bloquear padrões de segredos e credenciais
- Não exibir mensagens durante inventário ou dry run
- Não versionar sessões, transcrições ou arquivos de staging
- Manter qualquer staging futuro fora do workspace Git
- Exigir revisão humana antes de qualquer promoção



## Fonte protegida das sessões

- Armazenar transcrições somente em mimir.session_sources
- Negar SELECT direto para mimir_app
- Gravar somente por mimir.ingest_session
- Exigir autenticação peer do usuário openclaw
- Manter o evento com classification confidential
- Não copiar a transcrição para memory_events
- Bloquear conteúdo divergente para o mesmo session_id
- Não enviar sessões para API externa
- Exigir fluxo humano antes de qualquer liberação

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
