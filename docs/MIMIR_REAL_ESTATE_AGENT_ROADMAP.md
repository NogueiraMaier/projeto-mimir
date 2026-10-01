# Mímir Real Estate Agent / WhatsApp Roadmap

Status: **FILA / PLANEJADO / NÃO IMPLEMENTADO**  
Queue ID: `MIMIR-REAL-ESTATE-01`  
Data do registro: 2026-10-01

Objetivo: criar um agente imobiliário especializado sob orquestração do Mímir para atendimento de clientes via WhatsApp, com texto, áudio, consulta ao Costa de Itapema, cadastro de clientes, qualificação de leads, documentos, reservas controladas e human handoff.

Este roadmap trata somente do **lado Mímir**.

Implementação do site/API:

- `docs/integrations/COSTA_ITAPEMA_SITE_AI_API_SPEC.md`

Contrato compartilhado:

- `docs/integrations/COSTA_ITAPEMA_MIMIR_API_CONTRACT.md`

Este documento não altera o `NEXT_ACTION` atual da v1 e não autoriza implementação imediata.

---

## 1. Papel do agente

O agente imobiliário será um especialista subordinado ao Mímir.

```text
CLIENTE
  |
WhatsApp
  |
Mímir
  |
Real Estate Agent
  |
Tools
  |
Costa de Itapema API / CRM / agenda
```

O agente não é a fonte de verdade comercial.

---

## 2. Identidade

O agente deve se apresentar de forma transparente como assistente virtual da operação imobiliária.

Não fingir ser o corretor humano.

Quando ocorrer human handoff, informar que o atendimento foi transferido para uma pessoa.

---

## 3. Canais

### V1

- WhatsApp texto;
- WhatsApp áudio recebido;
- WhatsApp áudio enviado;
- imagens;
- documentos;
- links;
- notificações permitidas pela política do canal.

### Fase futura

- WhatsApp Calling / voz em tempo real;
- streaming STT/TTS;
- transferência de chamada.

A chamada ao vivo não é requisito para o primeiro MVP.

---

## 4. Pipeline de áudio

```text
WhatsApp audio
   |
media adapter
   |
STT
   |
texto normalizado
   |
Mímir
   |
Real Estate Agent
   |
resposta
   |
TTS
   |
WhatsApp voice message
```

STT e TTS devem ser capacidades separadas do LLM.

---

## 5. Capability model

Capacidades candidatas:

- `realestate`;
- `fast`;
- `reasoning`;
- `speech_to_text`;
- `text_to_speech`;
- `vision`, quando necessário;
- `document_classification`, quando autorizado.

O agente não deve ficar acoplado a Qwen, llama.cpp, vLLM ou outro runtime.

---

## 6. Fonte de verdade

Hierarquia:

1. Costa de Itapema API para dados atuais do empreendimento;
2. sistema/CRM para cliente/histórico;
3. Mímir Memory para contexto conversacional permitido;
4. site público para informação institucional quando não existir endpoint estruturado;
5. inferência do modelo somente para linguagem/raciocínio.

Preço, disponibilidade, financiamento e reserva exigem ferramenta/API atual.

---

## 7. Catálogo de tools

### Produto

- `itapema.info`
- `itapema.faq`
- `itapema.amenities`
- `itapema.location`

### Lotes

- `itapema.lot.search`
- `itapema.lot.get`
- `itapema.lot.availability`
- `itapema.lot.price`
- `itapema.lot.financing`

### Cliente

- `realestate.client.lookup`
- `realestate.client.create`
- `realestate.client.update`

### Interesse

- `itapema.interest.create`
- `itapema.interest.list`

### Documento

- `itapema.document.request`
- `itapema.document.upload`
- `itapema.document.status`

### Reserva

- `itapema.reservation.prepare`
- `itapema.reservation.submit`
- `itapema.reservation.status`

### Atendimento

- `realestate.visit.request`
- `realestate.visit.schedule`
- `realestate.handoff`

---

## 8. Política de tools

### READ automático quando autorizado

- produto;
- FAQ;
- lote;
- preço;
- disponibilidade;
- financiamento;
- client lookup limitado;
- histórico permitido.

### WRITE de baixo risco

Pode futuramente ser autorizado por policy:

- create lead/client;
- update preference;
- create interest.

### Confirmação do cliente

Exigir antes de:

- enviar reserva;
- enviar documento;
- agendar visita;
- registrar proposta.

### Não permitido ao agente

- confirmar venda;
- alterar preço;
- conceder desconto;
- apagar cliente;
- apagar documentos;
- marcar lote vendido;
- cancelar contrato;
- executar operação administrativa irreversível.

---

## 9. Qualificação de lead

Campos candidatos:

- compra/aluguel quando houver;
- empreendimento;
- faixa de orçamento;
- entrada disponível;
- finalidade;
- tipo de unidade;
- metragem;
- financiamento;
- prazo;
- preferências;
- urgência;
- disponibilidade para visita.

A conversa deve coletar progressivamente, não como questionário obrigatório.

---

## 10. Lookup por WhatsApp

Ao receber mensagem:

```text
phone
  |
normalize
  |
client.lookup
  |
existing?
  +-- yes -> recuperar contexto permitido
  +-- no  -> lead candidate
```

Não usar telefone como ID interno permanente.

---

## 11. Cadastro

Criar cliente/lead somente com campos necessários.

O agente deve evitar solicitar documento no primeiro contato se não houver necessidade comercial.

Separar:

- lead;
- cliente cadastrado;
- cliente com documentação;
- solicitante de reserva.

---

## 12. Fluxo de busca

Exemplo:

```text
cliente:
"quero lote até 150 mil"

intent
  |
itapema.lot.search
  |
resultados atuais
  |
rank por preferências
  |
explicação
```

O ranking é recomendação conversacional; preço/status continuam vindos da API.

---

## 13. Anti-hallucination

Se ferramenta obrigatória falhar:

não inventar.

Resposta candidata:

`Não consegui confirmar o valor/disponibilidade agora. Posso tentar novamente ou encaminhar ao atendimento.`

Nunca usar memória antiga como confirmação atual.

---

## 14. Fotos e mídia

Quando o cliente pedir fotos:

- usar URLs/IDs aprovados pelo sistema;
- não inventar imagens;
- não misturar fotos de lote/empreendimento sem identificação;
- registrar origem.

---

## 15. Documentos

Fluxo:

```text
cliente envia mídia
  |
WhatsApp media
  |
temporary retrieval
  |
validation
  |
Site Document API
  |
document_id/status
  |
Mímir receives metadata only
```

O documento bruto não deve ser armazenado na memória permanente.

---

## 16. Memória permitida

Candidatos:

- orçamento;
- preferências;
- empreendimento;
- lote de interesse;
- forma de pagamento preferida;
- visita;
- resultado anterior;
- canal preferido.

Não promover automaticamente.

---

## 17. Memória proibida/restrita

Não armazenar como memória de agente:

- CPF completo;
- RG/CNH;
- imagem de documento;
- comprovante;
- contrato integral;
- token;
- credencial.

Guardar somente referência/status quando necessário.

---

## 18. Human handoff

Acionar quando:

- cliente pedir pessoa;
- negociação de desconto;
- proposta fora da política;
- problema jurídico;
- documentação complexa;
- conflito de disponibilidade;
- reclamação/escalonamento;
- dúvida que o agente não consegue confirmar;
- fechamento que exige corretor.

Gerar resumo:

- cliente;
- empreendimento;
- lote;
- intenção;
- orçamento;
- pendência;
- últimas ações;
- dados comerciais confirmados;
- correlation_id.

---

## 19. Reserva

Fluxo:

```text
interesse
  |
live availability
  |
live price
  |
reservation.prepare
  |
mostrar condições
  |
client confirmation
  |
reservation.submit
  |
status
  |
human/admin workflow
```

O agente não transforma solicitação em venda.

---

## 20. Voz assíncrona no WhatsApp

MVP de voz:

- receber áudio;
- transcrever;
- processar;
- responder texto ou voice message;
- manter transcript para a sessão conforme política;
- não armazenar áudio bruto indefinidamente sem necessidade.

Métricas:

- STT latency;
- word error/análise amostral;
- LLM latency;
- TTS latency;
- total response time;
- failed media retrieval.

---

## 21. Voz ao vivo — fase futura

Somente após V1 estável.

Componentes:

- call gateway;
- streaming audio;
- VAD;
- STT streaming;
- Mímir;
- TTS streaming;
- interruption/barge-in;
- handoff.

Separar do MVP para não bloquear entrega inicial.

---

## 22. Follow-up

Fase futura, com política:

- lembrar retorno solicitado;
- avisar alteração relevante de lote de interesse;
- confirmar visita;
- follow-up comercial.

Não implementar spam ou disparo indiscriminado.

Respeitar regras do WhatsApp e consentimento aplicável.

---

## 23. Auditoria

Eventos candidatos:

- message_received;
- audio_received;
- stt_complete;
- intent_classified;
- tool_called;
- tool_result;
- client_created;
- interest_created;
- reservation_prepared;
- reservation_submitted;
- handoff_created;
- response_sent.

Usar correlation_id.

Não colocar conteúdo sensível em labels.

---

## 24. Segurança

Requisitos:

- channel auth;
- webhook verification;
- replay protection quando aplicável;
- secret storage;
- API credentials fora do Git;
- policy per tool;
- rate limits;
- prompt injection awareness para conteúdo externo;
- validation de tool args;
- redaction;
- audit.

---

## 25. Relação com Mímir Memory

O agente deve consultar memória somente quando útil.

Ordem:

```text
current request
  |
live business data
  |
allowed customer context
  |
memory
  |
response
```

Não permitir que memória sobrescreva dado comercial atual.

---

## 26. Relação com Model Routing

O agente solicita capacidades.

Exemplo:

```json
{
  "domain": "realestate",
  "capability": "fast",
  "tools_required": true,
  "privacy": "customer_data",
  "external_provider_allowed": false
}
```

A seleção de engine é responsabilidade futura do Capability Router.

---

## 27. Structured outputs

Para tool calls e persistência, usar schemas.

Objetos candidatos:

- LeadProfile;
- PropertySearch;
- CustomerIntent;
- HandoffSummary;
- ReservationIntent;
- DocumentStatus.

Não persistir texto livre quando estrutura suficiente existir.

---

## 28. Fases de implementação no Mímir

### RE-0 — contrato

- validar API do site;
- congelar tool names V1;
- schemas;
- error mapping;
- auth;
- test fixtures.

### RE-1 — agente READ-only

- identity;
- product/FAQ;
- lot search;
- price;
- availability;
- financing;
- text WhatsApp sandbox.

### RE-2 — CRM/lead

- client lookup;
- create/update;
- interest;
- session context;
- memory boundaries.

### RE-3 — documentos/reserva

- document metadata/upload handoff;
- reservation prepare;
- confirmation;
- submit;
- human handoff.

### RE-4 — áudio assíncrono

- media handling;
- STT;
- TTS;
- voice message;
- latency/quality tests.

### RE-5 — follow-up

- approved notification classes;
- visit reminders;
- explicit follow-up workflows.

### RE-6 — WhatsApp Calling

- somente após estabilidade;
- streaming voice;
- handoff.

---

## 29. Dependências

Antes de implementação:

- site API V1 ou sandbox disponível;
- tool policy do Mímir estabilizada;
- channel policy;
- credential model;
- audit/correlation;
- storage/memory boundaries;
- test customer data sintético;
- webhook sandbox.

---

## 30. Testes mínimos

### Conversa

- FAQ;
- lote;
- preço;
- disponibilidade;
- financiamento;
- nenhuma correspondência;
- API indisponível.

### Tool calling

- ferramenta correta;
- schema correto;
- retry;
- timeout;
- erro de auth;
- erro de conflito.

### Cliente

- existente;
- novo;
- duplicado;
- telefone inválido.

### Segurança

- prompt injection em mensagem;
- pedido de CPF de terceiro;
- pedido de documento alheio;
- tentativa de alterar preço;
- tentativa de marcar vendido.

### Handoff

- negociação;
- dúvida não confirmável;
- conflito;
- pedido explícito.

---

## 31. Critério de MVP

MVP suficiente:

```text
WhatsApp text
  |
Mímir Real Estate Agent
  |
Costa de Itapema API
  |
FAQ + lots + availability + price
  |
client lookup/create
  |
interest
  |
human handoff
```

Áudio pode ser RE-4 se necessário para reduzir risco inicial.

---

## 32. Critério de produção

Não liberar publicamente até:

- sandbox aprovado;
- tool schemas validados;
- preços/status sempre live;
- PII minimizada;
- auth;
- audit;
- rate limit;
- human handoff;
- fallback;
- testes de erro;
- mensagens transparentes de IA;
- procedimento para bloquear o agente.

---

## 33. Nota de fila

**QUEUE: MIMIR-REAL-ESTATE-01**

Status:

`DOCUMENTED / QUEUED / NOT IMPLEMENTED / DOES NOT CHANGE NEXT_ACTION`

Quando retomado:

1. ler este roadmap;
2. ler `COSTA_ITAPEMA_MIMIR_API_CONTRACT.md`;
3. validar que o site implementou ao menos sandbox/API V1;
4. iniciar em `RE-0`;
5. não começar pela chamada de voz ao vivo;
6. não conceder tools de escrita irreversível.

---

## 34. Princípio final

```text
Site/API = fonte de verdade
Mímir = inteligência/orquestração
Real Estate Agent = especialista
WhatsApp = canal
Memory = contexto permitido
Human = fechamento/exceção/autoridade
```

O objetivo é atendimento útil e natural sem transformar o LLM em banco de dados, CRM ou autoridade comercial.
