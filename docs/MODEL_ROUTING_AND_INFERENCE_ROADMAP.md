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


## 22. vLLM como engine challenger

Status: **WATCHLIST / CHALLENGER / BENCHMARK REQUIRED / NÃO IMPLEMENTADO**.

Revisão arquitetural:

- [review/architecture/2026-09-26-vllm-challenger.md](review/architecture/2026-09-26-vllm-challenger.md)

Projeto externo avaliado:

- `vllm-project/vllm`

Snapshot externo de referência desta avaliação:

- `379e9a1ea8a5995464d9bf775bcd36bb03a0995f`, observado em 2026-09-26.

### Papel no Mímir

O vLLM deve ser tratado como runtime/serving engine substituível dentro do futuro Engine Registry.

Ele não substitui:

- Mímir;
- Capability Router;
- Policy Engine;
- agentes especialistas;
- memória;
- ferramentas;
- approval/audit.

Registro candidato:

```text
engine_id = vllm-local-gpu
runtime = vLLM
location = PcIA
status = challenger
benchmark_status = required
```

O `llama.cpp` atual permanece como runtime CURRENT até que evidência de benchmark justifique mudança.

### Motivos para avaliação

Avaliar vLLM para:

- tool calling estruturado;
- structured outputs;
- API OpenAI-compatible;
- reasoning/tool parsers;
- continuous batching;
- PagedAttention/KV-cache management;
- prefix caching;
- streaming;
- múltiplas requisições/agentes;
- serving de modelos Hugging Face;
- quantizações suportadas pelo runtime;
- futuro multi-LoRA, somente se benchmark justificar.

### Compatibilidade de hardware

A documentação CUDA observada no snapshot da avaliação exige compute capability 7.5 ou superior e cita RTX 20xx como família compatível.

A RTX 2060 12 GB do PcIA é, portanto, candidata tecnicamente compatível para laboratório.

Compatibilidade não significa superioridade.

O comportamento real na Turing deve ser medido localmente.

### LAB-VLLM-01

Status:

**FILA / NÃO EXECUTADO**

Objetivo:

comparar `llama.cpp` CURRENT versus vLLM CHALLENGER no mesmo PcIA sem alterar o runtime principal.

Regras:

- preservar `127.0.0.1:18781` para o `llama.cpp` atual;
- executar vLLM em porta separada;
- não trocar modelo principal durante o laboratório;
- não alterar Telegram;
- não alterar tool policy;
- não usar o laboratório como justificativa para mudança de produção;
- manter rollback trivial: parar o challenger.

### MIMIR-ENGINE-EVAL específico

Além das métricas já definidas neste roadmap, medir:

```text
TTFT
tokens/s
latency p50/p95
VRAM
RAM
GPU utilization
cold start
errors
timeouts
stability

concurrency:
1
2
4
8 requests, se tecnicamente viável
```

### Tool calling

O laboratório deve separar:

```text
A. tool-selection
   o modelo decidiu usar a ferramenta correta?

B. tool-serialization
   nome/schema/argumentos foram produzidos corretamente?
```

Corpus sintético/controlado candidato:

- `mimir_memory_search`;
- `system_status`;
- `inventory_lookup`;
- `device_read`.

Métricas:

- tool selection accuracy;
- call success;
- function-name validity;
- argument-schema validity;
- argument correctness;
- false tool calls;
- abstention accuracy.

A existência de tool calling no vLLM não deve ser interpretada como correção automática do checkpoint atual de Telegram/tools.

### Structured outputs

Avaliar aderência de schema para objetos futuros como:

- finding;
- risk;
- evidence metadata;
- NIST outcome;
- routing decision;
- tool arguments.

Essa capacidade é especialmente relevante para:

- SOC;
- Field Assessment;
- NIST CSF 2.0;
- relatórios;
- persistência estruturada.

### Resultado possível

O benchmark pode concluir por:

1. manter `llama.cpp` como default;
2. coexistência por perfil de carga;
3. promover vLLM após validação.

Coexistência conceitual possível:

```text
single request / low-overhead
    -> llama.cpp

multi-agent / concurrent / structured serving
    -> vLLM
```

Esse desenho é hipótese de benchmark, não decisão atual.

### Multi-LoRA

Status: **WATCHLIST**.

O suporte do runtime a múltiplos LoRAs pode ser avaliado futuramente para especialização, mas não autoriza fine-tuning.

Exigir evidência de ganho contra:

- prompt/identity;
- memória/contexto;
- ferramentas/adapters;
- modelo base.

### Decisão atual

```text
vLLM
  -> DOCUMENTADO
  -> WATCHLIST
  -> CHALLENGER
  -> LAB-VLLM-01 PENDENTE
  -> NÃO IMPLEMENTADO
```

Não remover ou substituir `llama.cpp` antes de benchmark reproduzível.
