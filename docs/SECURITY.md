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
