# Plano de Migração — OpenClaw Gateway / Mímir para gentoo-Dragon_PcIA

Status: **PLANEJADO / NÃO AUTORIZA EXECUÇÃO**  
Tipo: mudança de topologia e plano de controle  
Objetivo: documentar preparação, riscos, validação e rollback antes de qualquer migração.

## 1. Decisão arquitetural proposta

Mover o plano de controle principal do Mímir atualmente associado à VPS para o nó local com GPU, mantendo a VPS como nó de persistência e infraestrutura auxiliar.

Estado conceitual atual:

```text
Telegram / HUD
      |
      v
gentoo-Dragon_vm
OpenClaw Gateway
      |
   WireGuard
      |
      v
gentoo-Dragon_PcIA
llama.cpp / GPU
```

Arquitetura alvo:

```text
                    INTERNET
                       |
             Telegram Bot API
                       |
                       v
+---------------------------------------------+
| gentoo-Dragon_PcIA                          |
|                                             |
| OpenClaw Gateway                            |
| Mímir / agente main                         |
| Telegram                                    |
| HUD                                         |
| plugins autorizados                         |
| inferência GPU local                        |
+--------------------+------------------------+
                     |
                  WireGuard
                     |
                     v
+---------------------------------------------+
| gentoo-Dragon_vm                            |
|                                             |
| PostgreSQL / pgvector                       |
| backups                                     |
| monitoramento                               |
| serviços auxiliares                         |
| fallback local/remoto conforme política     |
+---------------------------------------------+
```

Papel alvo:

- `gentoo-Dragon_PcIA`: **Primary Mímir Node / Control Plane**;
- `gentoo-Dragon_vm`: **Infrastructure / Persistence Node**.

Essa mudança não autoriza desligamento definitivo do Gateway atual nem alteração de produção antes dos testes e da aprovação específica.

## 2. Motivação

A principal motivação é retirar a VPN do caminho crítico de inferência quando a engine principal estiver no próprio PcIA.

Caminho atual esperado:

```text
canal
 -> VPS / Gateway
 -> WireGuard
 -> PcIA / GPU
 -> WireGuard
 -> VPS
 -> canal
```

Caminho alvo:

```text
canal
 -> PcIA / Gateway
 -> engine local
 -> canal
```

O acesso à memória persistente continua atravessando WireGuard enquanto PostgreSQL/pgvector permanecerem na VPS.

A migração busca:

- menor latência estrutural;
- menor dependência da VPN para inferência local;
- HUD próximo do Gateway;
- simplificação do hot path;
- melhor base para futura arquitetura de Capability Router e Engine Registry.

## 3. Não-objetivos

Esta migração não deve, na mesma janela:

- introduzir Capability Router;
- alterar política de seleção Qwen/NVIDIA;
- habilitar Codex, Claude Code ou OpenCode como rotas automáticas;
- alterar Memory v2;
- aplicar migration 013 em produção;
- ampliar EXECUTE em equipamento real;
- redefinir ACLs operacionais;
- reescrever o HUD;
- alterar política de aprovação;
- adicionar novo provider apenas por causa da mudança de host.

Regra:

**mover primeiro; otimizar e reestruturar depois.**

Isso permite distinguir falhas de migração de falhas de nova lógica de roteamento.

## 4. Observação de nomenclatura do host

Os documentos atuais do repositório usam, em alguns pontos:

`gentoo-Dragon_IA`

A arquitetura discutida para a migração usa:

`gentoo-Dragon_PcIA`

Não assumir que os nomes são equivalentes.

Antes de qualquer execução, registrar evidência do host real:

```bash
hostname
hostnamectl 2>/dev/null || true
uname -a
id
```

Em Gentoo/OpenRC, `hostnamectl` pode não representar a fonte de verdade do hostname; a validação final deve considerar a configuração efetiva do host.

O documento deverá ser atualizado com o nome canônico somente após verificação.

## 5. Estado de runtime que deve ser verificado antes da migração

Antes de copiar configuração ou estado, coletar de forma sanitizada:

- versão do OpenClaw;
- serviço OpenRC ativo;
- diretório real de configuração;
- diretório real de state/session;
- plugins habilitados;
- `plugins.allow`;
- agente `main`;
- modelo principal efetivo;
- fallbacks efetivos;
- endpoint do runtime local;
- política de tools;
- canais;
- Telegram;
- provider de embeddings;
- conexão com PostgreSQL;
- health checks;
- arquivos externos de segredo por referência.

Nenhum token ou segredo deve ser copiado para Git, logs públicos ou documentação.

## 6. Inferência local esperada

O desenho operacional discutido usa no PcIA:

- RTX 2060 12 GB;
- llama.cpp CUDA;
- endpoint local esperado `:18781`;
- Qwen3-4B-Q4_K_M como engine local atual.

Esses valores devem ser tratados como **estado esperado a verificar**, não como verdade documental suficiente para execução.

Executar preflight antes da migração e registrar versão/hash do modelo e parâmetros relevantes.

## 7. HUD

O HUD deve continuar sendo interface do Mímir, e não cliente acoplado diretamente a um modelo específico.

Arquitetura alvo:

```text
HUD
 |
Gateway local
 |
Mímir
 |
seleção de engine vigente
```

Não documentar no repositório público detalhes sensíveis que conflitem com `HUD_V6.md`.

A migração não deve transformar o HUD em:

`HUD -> Qwen`

nem em:

`HUD -> NVIDIA`

O HUD permanece uma superfície do Mímir.

## 8. Telegram

Telegram deve ser migrado por último.

Durante a preparação:

```text
VPS Telegram   ON
PcIA Telegram  OFF
```

Na troca controlada:

```text
VPS Telegram   OFF
PcIA Telegram  ON
```

Não manter o mesmo bot em polling simultâneo nos dois Gateways.

Requisitos:

- token fora do Git;
- allowlist preservada;
- grupos permanecem conforme política vigente;
- nenhuma ampliação de permissão;
- validar conversa bidirecional;
- validar envio proativo;
- validar reinício do serviço;
- validar que apenas o Gateway ativo consome o bot.

### Drift documental identificado

`TELEGRAM_INTEGRATION.md` ainda contém um estado histórico de configuração pendente, enquanto `MIMIR_V1_EXECUTION_PLAN.md` e `STATUS.md` já registram o canal como validado.

Não apagar o histórico.

Ao concluir a reconciliação documental, acrescentar atualização datada distinguindo:

- estado histórico;
- estado validado;
- estado após eventual migração.

## 9. Memória persistente

PostgreSQL/pgvector permanece na VPS nesta migração.

Fluxo alvo:

```text
Mímir no PcIA
    |
mimir-memory
    |
WireGuard
    |
PostgreSQL / pgvector na VPS
```

A migração não deve mover a fonte de verdade da memória.

Se a VPN ou VPS estiver indisponível, o sistema deve tratar memória permanente como degradada/indisponível.

Nunca converter falha de memória em permissão para inventar fatos.

Comportamento esperado:

- capacidades locais independentes da memória podem continuar;
- consultas que exigem memória devem declarar indisponibilidade;
- nenhuma promoção automática;
- nenhuma alteração na governança da Memory v1/v2.

## 10. Tool-calling — observação crítica

A migração de host não corrige automaticamente problemas de tool-calling.

Foi observado no fluxo Telegram que:

- `session_status` esteve indisponível por superfície/política;
- `mimir_memory_search` apareceu na investigação como caso distinto, exigindo validação do modelo/runtime/tool-calling.

Esses problemas devem ser diagnosticados separadamente.

Hipóteses técnicas a validar, sem assumir causa:

- policy de tools;
- profile;
- deny groups;
- schema de tools;
- compatibilidade OpenAI-style;
- chat template;
- compatibilidade llama.cpp;
- comportamento do modelo;
- prompt/runtime do agente.

Critério:

**Gateway local funcionando não significa tool-calling validado.**

Após a migração, repetir os testes de tools de forma controlada.

## 11. Qwen, NVIDIA e outros providers

A migração não fixa o HUD nem o Mímir em Qwen.

Também não transforma NVIDIA em fallback obrigatório.

A evolução futura está documentada em:

`MODEL_ROUTING_AND_INFERENCE_ROADMAP.md`

Separar:

- roteamento por capacidade;
- fallback por falha.

Exemplo futuro:

```text
Mímir
 |
Capability Router
 |
Policy
 |
Engine Registry
 |-- local
 |-- NVIDIA
 |-- coding harness
 `-- outros autorizados
```

Não implementar esse roteamento durante a migração física.

## 12. Disponibilidade e novo ponto crítico

Ao mover o Gateway para o PcIA, o PcIA passa a ser dependência direta de:

- Telegram;
- sessões do Gateway;
- HUD;
- plugins;
- inferência local;
- agente `main`.

Se o PcIA estiver desligado ou indisponível, o Mímir pode ficar indisponível mesmo com a VPS saudável.

Esse é o principal trade-off da mudança:

- menor latência;
- maior dependência operacional do PcIA.

A decisão de disponibilidade deve ser aceita explicitamente antes do cutover.

## 13. Separação de usuários e privilégios

Preservar isolamento.

Não executar o Gateway como consequência da sessão gráfica do operador.

Separar, quando aplicável:

- usuário humano;
- usuário de desenvolvimento `jarvisdev`;
- identidade do runtime OpenClaw;
- identidades operacionais PostgreSQL;
- identidades de adapters.

`jarvisdev` não deve receber sudo apenas para viabilizar esta migração.

Serviços devem ser gerenciados por OpenRC conforme política do projeto.

## 14. Bind e exposição

Preferir Gateway em loopback quando o acesso local for suficiente.

Qualquer exposição em interface de rede exige:

- necessidade explícita;
- autenticação;
- firewall;
- escopo;
- documentação;
- teste.

Não abrir porta pública do Gateway para viabilizar Telegram.

## 15. Configuração e state

A migração deve distinguir:

- configuração versionável;
- state operacional;
- sessões;
- caches;
- índices;
- plugins;
- artefatos gerados;
- segredos;
- arquivos externos;
- logs.

Não copiar cegamente diretórios inteiros entre hosts.

Para cada item definir:

- origem;
- destino;
- owner/group;
- mode;
- se é reconstruível;
- se deve ser copiado;
- se deve ser regenerado;
- se contém segredo;
- se exige backup.

## 16. Backup obrigatório antes do cutover

Antes da migração:

1. backup da configuração sanitizável;
2. backup do state necessário;
3. backup consistente de SQLite local, se aplicável;
4. registrar plugins e versões;
5. registrar hashes relevantes;
6. registrar serviço OpenRC;
7. registrar canal Telegram;
8. registrar configuração de modelos sem segredo;
9. registrar estado do banco remoto;
10. testar restauração do que for crítico.

Backup não validado não é rollback.

## 17. Plano de execução em fases

### Fase 0 — inventário e preflight

Somente leitura.

Validar:

- hostname canônico;
- versão OpenClaw nos dois hosts;
- árvore de state/config;
- OpenRC;
- plugins;
- Telegram;
- tools;
- GPU;
- llama.cpp;
- PostgreSQL;
- WireGuard;
- espaço em disco;
- owner/modes.

Não alterar runtime.

### Fase 1 — preparar PcIA

Instalar/configurar o necessário sem assumir produção.

Requisitos:

- serviço OpenRC;
- usuário/permissions corretos;
- config preparada;
- plugins presentes;
- segredos por canal seguro;
- Gateway ainda sem assumir Telegram.

### Fase 2 — validar Gateway local isolado

Testar sem cutover do Telegram:

- start/stop/restart;
- health;
- agente main;
- engine local;
- memória;
- tools;
- logs;
- persistência de sessão;
- reinício do host/serviço quando apropriado.

### Fase 3 — validar HUD local

Validar conexão com o Gateway local preservando as regras de `HUD_V6.md`.

### Fase 4 — cutover Telegram

Ordem:

1. registrar estado da VPS;
2. parar/desabilitar consumo Telegram na VPS;
3. confirmar ausência do poller anterior;
4. habilitar Telegram no PcIA;
5. validar allowlist;
6. testar inbound;
7. testar outbound;
8. testar reinício;
9. registrar evidência.

### Fase 5 — observação pós-cutover

Validar:

- erros;
- latência;
- tools;
- memória;
- sessões;
- reconnect;
- CPU/RAM/VRAM;
- WireGuard;
- chamadas ao PostgreSQL.

Não remover imediatamente a configuração de rollback da VPS.

### Fase 6 — estabilização

Somente depois de período de validação aprovado:

- marcar PcIA como Primary Mímir Node;
- marcar VPS como Infrastructure/Persistence Node;
- atualizar STATUS;
- atualizar ARCHITECTURE;
- atualizar RUNBOOK;
- atualizar ROADMAP;
- atualizar handoff;
- arquivar evidências.

## 18. Rollback

Rollback deve ser possível sem reconstrução improvisada.

Se o PcIA falhar no cutover:

1. desabilitar Telegram no PcIA;
2. parar Gateway local se necessário;
3. restaurar/reativar configuração anterior da VPS;
4. iniciar Gateway da VPS;
5. habilitar Telegram na VPS;
6. validar canal;
7. validar agente;
8. validar tools;
9. registrar falha e evidências.

Nunca manter os dois pollers Telegram ativos como tentativa de redundância.

## 19. Critérios de aceite

A migração somente pode ser considerada concluída se:

- Gateway local inicia via OpenRC;
- reinício é reproduzível;
- agente `main` carrega;
- engine local responde;
- memória remota funciona;
- indisponibilidade da memória falha de forma segura;
- plugins autorizados carregam;
- Telegram recebe e envia;
- allowlist permanece;
- HUD conecta conforme desenho autorizado;
- tool inventory é conhecido;
- tool-calling essencial é testado;
- state necessário sobrevive a restart;
- nenhum segredo entra no Git;
- VPS continua apta ao rollback;
- documentação reflete o estado real.

## 20. Critérios de abort

Abortar o cutover se ocorrer qualquer um destes:

- perda de state não compreendida;
- divergência de identidade do agente;
- token exposto;
- Telegram com conflito de polling;
- tools essenciais ausentes sem causa entendida;
- plugin de memória não carregar;
- memória produzir falha não controlada;
- permissions inseguras;
- Gateway exigir exposição pública inesperada;
- rollback não estiver disponível;
- comportamento diferente do baseline sem explicação.

## 21. Observações para evolução

Após a migração estabilizada, medir o novo baseline antes de qualquer mudança de model routing.

Comparar:

- latência total;
- TTFT;
- tokens/s;
- latência de memória;
- latência de tools;
- uso da VPN;
- estabilidade do Telegram;
- consumo CPU/RAM/VRAM.

Somente depois avaliar:

- Capability Router;
- Engine Registry;
- routing Qwen/NVIDIA;
- coding harnesses;
- streaming;
- runtime residente adicional;
- circuit breaker.

## 22. Documentos relacionados

- `MIMIR_V1_EXECUTION_PLAN.md` — conclusão e checkpoints da v1;
- `MIMIR_HANDOFF.md` — continuidade operacional corrente;
- `TELEGRAM_INTEGRATION.md` — política do canal Telegram;
- `HUD_V6.md` — restrições documentais do HUD;
- `OPERATIONS.md` — operações controladas;
- `MODEL_ROUTING_AND_INFERENCE_ROADMAP.md` — evolução de engines/providers;
- `MEMORY_V2_ROADMAP.md` — evolução futura da memória, mantida em sua branch própria.

## Princípio final

A migração deve reduzir caminho crítico sem misturar mudança de host com mudança de inteligência.

Primeiro:

`VPS Gateway -> PcIA Gateway`

preservando comportamento.

Depois:

`Mímir -> Capability Router -> Policy -> Engine Registry`

com benchmark, segurança e rollback próprios.
