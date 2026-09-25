# Mímir — Capability Routing, Model Routing e Inferência

Status: **PLANEJADO / PÓS-v1**  
Escopo: evolução arquitetural; este documento não autoriza alteração de runtime, provider, modelo, credencial ou política.

## Objetivo

Evoluir o Mímir para uma arquitetura independente de modelo, provedor e runtime de inferência.

O Mímir permanece responsável por:

- identidade;
- intenção;
- planejamento;
- políticas;
- risco;
- memória;
- contexto;
- seleção de agentes;
- seleção de ferramentas;
- aprovação;
- auditoria;
- consolidação da resposta.

Modelos de linguagem, provedores externos e coding harnesses são componentes substituíveis.

Princípio:

`Mímir -> capacidade necessária -> política -> engine apropriada`

O Mímir não deve ser definido por `Qwen`, `Nemotron`, `Codex`, `Claude Code`, `OpenCode` ou qualquer outro componente específico.

## 1. Separação de conceitos

A arquitetura deve distinguir explicitamente:

| Camada | Exemplos |
|---|---|
| Domínio/agente | Redes, SOC, Developer, Operações, OSINT |
| Capacidade | fast, reasoning, coding, vision, embedding, classification |
| Modelo | Qwen, Nemotron, outro modelo futuro |
| Runtime | llama.cpp |
| Provider | local, NVIDIA, OpenAI, Anthropic, outro autorizado |
| Harness/agente externo | Codex, Claude Code, OpenCode |
| Memória | PostgreSQL + pgvector + relações/grafo |
| Embedding | EmbeddingGemma ou substituto aprovado |
| Ferramenta | adapters, SSH, Zabbix, APIs, CMDB |

`network` não é capacidade de modelo; é domínio. Um agente de Redes pode solicitar `fast`, `reasoning` ou `vision` conforme a tarefa.

## 2. Capability Router

Prioridade: **ALTA após baseline e conclusão da v1**.

O Mímir deve identificar a capacidade necessária antes de selecionar engine.

Capacidades candidatas iniciais:

- `fast`;
- `reasoning`;
- `coding`;
- `vision`;
- `embedding`;
- `classification`;
- `summarization`.

Exemplo conceitual:

```json
{
  "capability": "reasoning",
  "domain": "network",
  "privacy": "confidential",
  "tools_required": true,
  "vision_required": false,
  "latency_class": "normal",
  "external_provider_allowed": false
}
```

O schema definitivo deve ser mínimo e guiado por uso real.

## 3. Engine Registry

Prioridade: **ALTA**.

Criar catálogo controlado das engines disponíveis sem hardcode de endpoint/modelo espalhado pelo projeto.

Campos candidatos:

- `engine_id`;
- `provider`;
- `runtime`;
- `model`;
- `version`;
- `quantization`;
- `location`;
- `capabilities`;
- `context_limit`;
- `tool_support`;
- `vision_support`;
- `privacy_class`;
- `health`;
- `benchmark_status`.

O registry não deve armazenar senhas, tokens, chaves privadas ou segredos.

## 4. Engine, Provider e Harness

### Engine

Executa inferência.

Exemplos:

- Qwen local;
- outro GGUF;
- modelo multimodal;
- modelo de embedding.

### Provider

Disponibiliza uma ou mais engines.

Exemplos:

- runtime local;
- NVIDIA;
- OpenAI;
- Anthropic;
- outros provedores previamente autorizados.

### Harness ou agente externo especializado

Executa fluxo complexo sobre modelo, ferramentas e workspace.

Exemplos:

- Codex;
- Claude Code;
- OpenCode.

Esses componentes não devem ser tratados apenas como nomes de modelos.

## 5. Policy-Aware Routing

Prioridade: **CRÍTICA antes de fallback externo automático**.

Antes da seleção de engine:

1. classificar a tarefa;
2. determinar classificação dos dados;
3. determinar ferramentas necessárias;
4. determinar risco;
5. determinar se saída externa é permitida;
6. selecionar somente engines elegíveis;
7. verificar saúde;
8. consultar benchmark;
9. executar;
10. registrar a decisão.

Princípio:

`engine disponível != engine autorizada`

A taxonomia de dados deve reutilizar as classificações já existentes no projeto; não criar taxonomia paralela sem necessidade.

## 6. Routing por capacidade versus fallback por falha

São mecanismos diferentes.

### Routing por capacidade

Seleciona a engine mais adequada à tarefa.

Exemplos:

- consulta simples -> engine local rápida;
- raciocínio complexo -> engine de reasoning;
- desenvolvimento -> harness/capacidade de coding;
- análise de imagem -> engine vision.

### Fallback por falha

É acionado somente quando a engine escolhida está indisponível, degradada ou excede limite operacional.

Fallback nunca significa:

`local falhou -> enviar automaticamente conteúdo para qualquer cloud`

O fallback precisa preservar:

- capacidade equivalente;
- classificação;
- política;
- privacidade;
- autorização;
- auditabilidade.

## 7. Circuit Breaker e saúde de engines

Estados candidatos:

- `healthy`;
- `degraded`;
- `unavailable`;
- `cooldown`.

Implementar quando necessário:

- timeout;
- retry limitado;
- backoff;
- cooldown;
- fila limitada;
- health check.

Falhas repetidas não devem gerar tentativas ilimitadas.

## 8. MIMIR-ENGINE-EVAL

Prioridade: **ALTA e anterior à troca automática de engines**.

Criar benchmark próprio do domínio operacional do Mímir.

Categorias iniciais:

- conversação simples;
- raciocínio;
- Linux;
- redes;
- MikroTik;
- análise de logs;
- programação;
- tool calling;
- JSON/schema adherence;
- memória;
- abstention;
- segurança;
- visão, quando aplicável.

Métricas candidatas:

- task accuracy;
- tool selection accuracy;
- structured output accuracy;
- hallucination rate;
- abstention accuracy;
- TTFT;
- tokens/s;
- total latency;
- context tokens;
- RAM;
- VRAM;
- CPU;
- error rate;
- timeout rate;
- custo, quando aplicável.

A seleção não deve depender apenas de benchmark público ou percepção subjetiva.

## 9. Champion / Challenger

Estados candidatos:

- `candidate`;
- `challenger`;
- `approved`;
- `default`;
- `deprecated`;
- `disabled`.

Fluxo:

`candidate -> benchmark -> challenger -> validação -> approved -> default`

Manter rollback quando aplicável.

## 10. Model Manifest e reprodutibilidade

Para modelos locais registrar:

- nome;
- origem;
- versão/revisão;
- arquitetura;
- quantização;
- tamanho;
- hash;
- tokenizer;
- runtime;
- parâmetros relevantes de execução;
- licença;
- data de avaliação;
- benchmark relacionado;
- status.

Não depender apenas do nome do arquivo GGUF.

## 11. Runtime residente e hot path

Prioridade: **ALTA após baseline**.

Avaliar por benchmark:

- modelo principal residente;
- embedding residente;
- warmup;
- HTTP keep-alive;
- conexões persistentes;
- prepared statements;
- pool PostgreSQL controlado;
- prompt/prefix caching;
- KV cache;
- continuous batching;
- filas limitadas.

Toda otimização exige medição antes e depois.

## 12. Context Budget Manager

O Mímir deve controlar explicitamente o orçamento de contexto por origem:

- policy/system;
- tarefa;
- memória;
- evidência;
- documentos;
- ferramentas;
- histórico;
- reserva de saída.

Objetivos:

- reduzir contexto inútil;
- reduzir TTFT;
- preservar evidência crítica;
- evitar truncamento de política;
- evitar enviar documento inteiro quando apenas um trecho é necessário.

Integrar com o Memory Context Builder.

## 13. Evidence Planner

Antes de tarefas complexas, determinar quais fontes precisam ser consultadas.

Fontes candidatas:

- memória;
- CMDB;
- equipamento;
- logs;
- documentação oficial;
- runbooks;
- arquivos;
- banco;
- pesquisa externa autorizada.

Fluxo conceitual:

```text
pergunta
   |
Evidence Planner
   |
   +--> memória
   +--> CMDB
   +--> equipamento
   +--> documentação
   +--> logs
   |
Evidence Pack
   |
engine selecionada
```

A hierarquia de confiança documentada no roadmap de agentes especialistas deve ser reutilizada.

## 14. Streaming fim a fim

Objetivo: reduzir latência percebida.

Fluxo alvo:

```text
entrada -> Mímir -> engine streaming -> HUD -> segmentação segura -> TTS
```

Prever:

- resposta textual progressiva;
- cancelamento;
- interrupção;
- barge-in;
- encerramento de geração;
- encerramento de áudio;
- limpeza de fila.

## 15. Telemetria de inferência

Eventos candidatos:

- request_received;
- routing_start/end;
- memory_start/end;
- tool_start/end;
- llm_request;
- llm_first_token;
- llm_last_token;
- tts_start;
- first_audio;
- playback_end.

Métricas candidatas:

- `mimir_request_duration_seconds`;
- `mimir_llm_ttft_seconds`;
- `mimir_llm_tokens_per_second`;
- `mimir_memory_search_duration_seconds`;
- `mimir_tool_duration_seconds`;
- `mimir_context_tokens`;
- `mimir_provider_failovers_total`;
- `mimir_engine_errors_total`.

Não usar prompt, conteúdo de memória, credenciais, `session_id` ou identificadores de alta cardinalidade como labels de métricas.

## 16. HUD como observador, não como autoridade

O HUD pode exibir:

- listening;
- transcribing;
- routing;
- retrieving;
- tool;
- reasoning;
- streaming;
- speaking;
- approval;
- degraded;
- error.

Pode também mostrar engine/provider/modelo e telemetria operacional sanitizada.

O HUD não ganha permissão operacional adicional por exibir essas informações.

Detalhes sensíveis de implementação do HUD permanecem sujeitos às restrições documentais já existentes em `HUD_V6.md`.

## 17. Shadow Routing

Status: **PLANEJADO PARA AVALIAÇÃO**.

Comparar champion e challenger sem alterar a resposta entregue ao operador.

Somente utilizar:

- corpus sintético;
- benchmark;
- dados sanitizados;
- conteúdo explicitamente autorizado.

Não duplicar conteúdo confidential para provider externo sem autorização.

## 18. Watchlist

Somente avaliar após baseline confiável:

- speculative decoding;
- roteamento por energia/custo;
- GNN/GAT para seleção de contexto;
- fine-tuning;
- LoRA/QLoRA;
- modelos especializados adicionais.

Nenhuma dessas técnicas deve entrar apenas porque existe.

## 19. Integração com agentes

Agent routing e model routing são independentes.

```text
usuário
  |
Mímir
  |
Agente Redes
  |
Capability Router
  |
fast / reasoning / vision
```

O mesmo agente pode usar engines diferentes conforme a tarefa.

## 20. Integração com Memory v2

A memória fornece contexto e evidência; não escolhe a engine final.

```text
tarefa
  |
Mímir
  |
Memory Context Builder
  |
Evidence Pack
  |
Capability Router
  |
Policy
  |
Engine
```

## 21. Integração com a migração do Gateway

A migração do Gateway da VPS para o nó local é tratada separadamente em:

`GATEWAY_PCIA_MIGRATION_PLAN.md`

Regra:

**não introduzir simultaneamente a migração física do Gateway e a nova lógica de model routing.**

Primeiro preservar comportamento e mover o plano de controle. Depois medir e evoluir o roteamento.

## Ordem sugerida pós-v1

1. baseline do MIMIR-ENGINE-EVAL;
2. Engine Registry;
3. Capability Router;
4. Policy-Aware Routing;
5. fallback/circuit breaker;
6. Model Manifest;
7. runtime residente;
8. telemetria;
9. Context Budget Manager;
10. Evidence Planner;
11. streaming;
12. HUD;
13. shadow routing;
14. reavaliar watchlist.

## Critério de conclusão

Esta evolução só será considerada consolidada quando:

- Mímir não depender de modelo específico;
- engines forem registradas por configuração controlada;
- seleção respeitar política de dados;
- fallback não provocar saída externa silenciosa;
- benchmark for reproduzível;
- troca de modelo não exigir mudar identidade do Mímir;
- falha de engine tiver comportamento previsível;
- decisão de roteamento for auditável;
- agentes especialistas permanecerem desacoplados da engine;
- documentação refletir o runtime real.

## Princípio final

O Mímir não precisa ser o melhor modelo.

Ele precisa saber:

- qual capacidade é necessária;
- qual evidência consultar;
- qual engine está autorizada;
- quando usar ferramenta;
- quando não sabe;
- como validar e auditar o resultado.

Modelos e provedores podem mudar. O núcleo do Mímir deve permanecer.
