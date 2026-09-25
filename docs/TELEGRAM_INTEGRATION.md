# Integração Telegram — canal secundário do Mímir

Data: 2026-09-25
Status: REQUISITO DEFINIDO / CONFIGURAÇÃO PENDENTE

## Objetivo

Adicionar Telegram como segundo canal operacional do Mímir para:

- conversar com o Mímir fora da interface principal;
- receber notificações operacionais;
- receber alertas de automações e tarefas;
- receber avisos de falha, indisponibilidade e eventos que exijam atenção;
- permitir continuidade básica quando a interface principal não estiver disponível.

Telegram é um canal secundário. Ele não substitui o canal principal nem deve
receber segredos, dumps completos ou evidências operacionais sensíveis.

## Estado atual

O Projeto Mímir não possui configuração Telegram versionada.

O OpenClaw 2026.9.5 instalado no runtime já inclui o canal/plugin Telegram
bundled. Portanto não é necessário instalar um plugin Telegram externo.

A configuração deve ser feita por `channels.telegram`.

## Política de segurança v1

Para uso individual:

- `enabled=true`;
- usar bot próprio criado no BotFather;
- token nunca entra no Git;
- preferir `tokenFile` ou SecretRef em vez de token literal versionado;
- DMs começam em `pairing` para descoberta/validação;
- depois da identificação do operador, preferir `dmPolicy=allowlist` com ID
  numérico do Telegram;
- grupos ficam bloqueados por padrão;
- se grupos forem habilitados, usar allowlist explícita e `requireMention=true`;
- não usar `dmPolicy=open`;
- não usar `allowFrom=["*"]` para o bot pessoal;
- notificações não devem incluir credenciais, tokens, chaves privadas ou dumps
  brutos.

## Allowlist de plugins

Enquanto `plugins.allow` estiver configurado, o ID `telegram` deverá estar
presente antes da ativação do canal Telegram.

Adicionar o ID à allowlist não ativa o canal por si só.

## Fluxo de implantação

1. concluir o P0 atual de metadata/registry do `mimir-memory`;
2. criar o bot no BotFather;
3. armazenar o token fora do Git;
4. adicionar `telegram` à allowlist de plugins;
5. configurar `channels.telegram.enabled=true`;
6. iniciar com `dmPolicy=pairing`;
7. enviar a primeira DM ao bot;
8. aprovar o pairing e obter o Telegram user ID do operador;
9. trocar para `dmPolicy=allowlist` com o ID numérico validado;
10. validar `openclaw channels status --probe`;
11. testar conversa bidirecional;
12. testar envio proativo de notificação;
13. documentar quais classes de alerta podem usar Telegram.

## Notificações previstas

O canal deve suportar, no mínimo:

- falha de serviço importante;
- perda de conectividade de componente monitorado;
- automação/tarefa que terminou com erro;
- intervenção operacional que exige confirmação humana;
- resultado de monitoramento que ultrapassou um limiar configurado;
- lembretes e resumos explicitamente configurados pelo operador.

Notificações devem ser acionadas por regras explícitas. O Mímir não deve enviar
spam nem transformar cada evento técnico em mensagem.

## Pendências

- criar bot e token;
- definir armazenamento seguro do token;
- descobrir/confirmar Telegram user ID do operador;
- configurar canal;
- testar mensagens;
- integrar notificações do Mímir com tarefas/automação;
- registrar política final de severidade e rate limit.
