# Revisão arquitetural — vLLM como engine challenger

Data: 2026-09-26  
Status: **DOCUMENTAÇÃO / WATCHLIST / NÃO IMPLEMENTADO**

## Objetivo

Registrar a avaliação do projeto `vllm-project/vllm` como possível engine futura de inferência para o Mímir.

Esta revisão não autoriza instalação, alteração de runtime, troca do modelo principal, mudança da porta local existente, provider externo ou alteração do `NEXT_ACTION`.

## Fonte externa avaliada

Repositório:

- `vllm-project/vllm`

Snapshot de referência observado durante esta revisão:

- commit `379e9a1ea8a5995464d9bf775bcd36bb03a0995f`
- data observada: 2026-09-26

O snapshot documentado oferece, entre outros:

- serving de inferência para LLM;
- API compatível com OpenAI;
- Anthropic Messages API;
- gRPC;
- continuous batching;
- PagedAttention;
- prefix caching;
- chunked prefill;
- streaming;
- structured outputs;
- tool calling;
- reasoning parsers;
- múltiplas formas de quantização;
- suporte a diversas arquiteturas Hugging Face;
- suporte a NVIDIA, AMD, Intel e outros backends conforme disponibilidade do projeto.

## Compatibilidade relevante para o PcIA

A documentação CUDA do vLLM observada nesta revisão exige GPU NVIDIA com compute capability 7.5 ou superior e cita a família RTX 20xx como exemplo suportado.

O PcIA documentado utiliza RTX 2060 12 GB.

Isso torna o vLLM um candidato tecnicamente elegível para laboratório, mas não prova que será melhor que `llama.cpp` nesse hardware.

A decisão deve ser por benchmark local.

## Papel arquitetural

O vLLM não deve substituir o Mímir, o Capability Router, o Policy Engine ou o Engine Registry.

Ele deve ser tratado como:

```text
runtime / serving engine
```

e registrado futuramente como engine candidata.

Modelo conceitual:

```text
                    Engine Registry
                         |
            +------------+------------+
            |                         |
       llama.cpp                    vLLM
        champion                  challenger
            |                         |
         local                     local
            |                         |
            +------------+------------+
                         |
                 MIMIR-ENGINE-EVAL
```

## Estado proposto

`vllm-local-gpu`

Status inicial:

`WATCHLIST / CHALLENGER / BENCHMARK REQUIRED`

Não promover para `approved` ou `default` sem laboratório reproduzível.

## Benefícios a avaliar

### 1. Tool calling

O snapshot avaliado possui suporte explícito a:

- auto tool choice;
- tool-call parsers;
- reasoning parsers;
- strictness de function/schema;
- schemas estruturados;
- parsers específicos por famílias de modelos.

Isso é relevante para o Mímir porque tool calling é uma capacidade crítica e já existe um checkpoint operacional separado para diagnosticar a superfície de tools no Telegram.

Esta revisão **não presume** que vLLM resolverá esse checkpoint.

Devem ser distinguidas duas perguntas:

1. o modelo decide chamar a ferramenta?;
2. quando decide, a chamada é serializada e validada corretamente?

O vLLM pode ser avaliado principalmente na segunda dimensão e na confiabilidade fim a fim.

### 2. Structured outputs

Avaliar geração aderente a schemas para objetos como:

- finding;
- risk;
- evidence reference;
- NIST outcome;
- routing decision;
- tool arguments.

Isso pode beneficiar Field Assessment, SOC, relatórios e persistência estruturada.

### 3. Concorrência

Avaliar vantagem quando houver múltiplos consumidores simultâneos:

- HUD;
- Telegram;
- agentes especialistas;
- SOC;
- Field Assessment;
- geração de relatórios;
- tarefas de memória.

Continuous batching e gerenciamento de KV cache devem ser medidos no hardware real.

### 4. Serving padronizado

A API compatível com OpenAI pode simplificar a substituição de runtime dentro do Engine Registry sem acoplar o Mímir à implementação.

### 5. Modelos HF e futuras quantizações

O vLLM deve ser avaliado como caminho alternativo para modelos Hugging Face e quantizações suportadas pelo runtime.

Não assumir que o modelo GGUF atual deve ser migrado.

## Limitações e riscos

### RTX 2060 / Turing

Compatibilidade mínima não implica desempenho ótimo.

O laboratório deve medir:

- VRAM;
- RAM;
- cold start;
- TTFT;
- throughput;
- estabilidade;
- contexto;
- concorrência.

Não usar benchmark de H100/A100/Blackwell como proxy direto para RTX 2060.

### Complexidade operacional

vLLM adiciona dependências e runtime mais pesado que `llama.cpp`.

Avaliar:

- PyTorch;
- CUDA compatibility;
- ambiente Python;
- build/wheel;
- OpenRC service;
- atualização;
- rollback;
- observabilidade;
- isolamento.

### Segurança

A API do laboratório deve ficar em loopback ou rede controlada.

Não expor porta pública.

Ferramentas e schemas continuam sujeitos ao Policy Engine; o runtime de inferência não recebe autoridade adicional.

## LAB-VLLM-01

Status: **FILA / NÃO EXECUTADO**

Objetivo:

Comparar `llama.cpp` atual com vLLM challenger sem alterar o runtime principal.

### Regras

- manter `llama.cpp` atual intacto;
- manter porta `18781` intacta;
- executar vLLM em porta separada;
- não trocar provider/modelo principal;
- não alterar Telegram;
- não mudar tool policy;
- não usar produção como laboratório.

### Benchmark

Medir pelo menos:

- TTFT;
- tokens/s;
- latência total;
- p50/p95;
- VRAM;
- RAM;
- GPU utilization;
- erro/timeout;
- cold start;
- estabilidade.

Concorrência:

- 1 request;
- 2 requests;
- 4 requests;
- 8 requests, se o hardware suportar sem degradação impeditiva.

### Tool calling

Corpus sintético/controlado com ferramentas como:

- `mimir_memory_search`;
- `system_status`;
- `inventory_lookup`;
- `device_read`.

Medir:

- tool selection accuracy;
- call success;
- function-name validity;
- argument-schema validity;
- argument correctness;
- false tool calls;
- abstention.

### Structured outputs

Medir aderência de schema para:

- finding;
- risk;
- NIST mapping;
- evidence metadata;
- routing decision.

## Critério de decisão

Possíveis resultados:

### manter llama.cpp como default

Se vLLM não trouxer ganho suficiente para justificar complexidade/consumo.

### coexistência

Exemplo:

```text
single-request / fast
    -> llama.cpp

multi-agent / concurrent serving / structured tools
    -> vLLM
```

### promover vLLM

Somente se benchmark local, estabilidade, segurança e operação justificarem.

## Multi-LoRA

Status: **WATCHLIST**

O suporte do vLLM a múltiplos LoRAs pode ser relevante no futuro para especialização de capacidades.

Não iniciar fine-tuning ou LoRA apenas porque o runtime suporta.

Exigir benchmark que demonstre ganho sobre:

- prompt/identity;
- memory/context;
- adapters/tools;
- modelo base.

## Conclusão

vLLM é um candidato tecnicamente compatível com a arquitetura de Engine Registry e Capability Routing.

A decisão correta neste momento é:

`DOCUMENTAR -> LABORATÓRIO -> BENCHMARK -> DECIDIR`

Não:

`DOCUMENTAR -> SUBSTITUIR LLAMA.CPP`
