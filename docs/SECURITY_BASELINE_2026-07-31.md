# Baseline de segurança do Projeto Mímir

Data do marco: 31 de julho de 2026.

## Resultado

Estado: aprovado.

Modo validado: auditoria agendada.

Controles aprovados: 22 de 22.

Achados críticos: 0.

Achados altos: 0.

## Controles ativos

1. Gateway restrito ao loopback e autenticado por token.
2. SearXNG restrito ao loopback.
3. Mensagens diretas isoladas por canal e remetente.
4. Perfil global minimal.
5. Agente main limitado a mimir_memory_search e web_search.
6. Execução, processos, sistema de arquivos, navegador, automação, sessões, mensageria e acesso elevado negados.
7. web_fetch desativado.
8. Arquivos sensíveis com proprietário, grupo e modo restritivos validados.
9. Integridade da configuração comparada com baseline SHA256.
10. Auditoria automática executada a cada seis horas, no minuto 17.
11. Relatórios mantidos por 90 dias.
12. Falhas registradas no syslog, sem correção automática.

## Exceção controlada

Sandbox: off.

O sandbox permanece desativado. A exceção fica controlada pela ausência das ferramentas de execução, arquivos, navegador, mensageria e acesso elevado.

Nenhuma ferramenta de execução deve ser liberada antes da instalação e validação de isolamento compatível com Gentoo e OpenRC.

## Procedimento operacional

1. Não executar accept-baseline após falha sem revisão humana.
2. Investigar cada controle reprovado antes de alterar configuração ou baseline.
3. Criar backup antes de qualquer mudança crítica.
4. Validar configuração, serviço, plugins, portas e política efetiva após cada mudança.
5. Manter o ambiente Mímir separado da infraestrutura da Protec.

## Publicação

Este registro não contém tokens, credenciais, endereços públicos, hashes internos, PIDs ou conteúdo de mensagens.
