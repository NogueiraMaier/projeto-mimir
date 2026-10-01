# Costa de Itapema ↔ Mímir — Contrato de Integração

Status: **CONTRATO ALVO / NÃO IMPLEMENTADO**  
Contract ID: `COSTA-ITAPEMA-MIMIR-API-V1`

Este documento é a fronteira entre:

- implementação do site/API;
- implementação do agente imobiliário no Mímir.

Nenhum lado deve depender de detalhes internos do outro.

---

## 1. Responsabilidades

### Site/API

Responsável por:

- dados oficiais do empreendimento;
- catálogo;
- disponibilidade;
- preço;
- regras comerciais;
- clientes;
- documentos;
- reservas;
- persistência;
- validação;
- autorização de dados;
- auditoria de operações comerciais.

### Mímir

Responsável por:

- conversa;
- intenção;
- classificação;
- seleção de ferramenta;
- memória conversacional permitida;
- STT/TTS;
- WhatsApp;
- human handoff;
- política do agente;
- explicação ao cliente.

---

## 2. Fonte de verdade

```text
dados comerciais atuais
  -> Site/API

dados pessoais/documentos
  -> Site/API privada

contexto conversacional permitido
  -> Mímir Memory

canal
  -> WhatsApp/HUD
```

O Mímir não deve transformar memória em fonte de verdade para preço, disponibilidade ou reserva.

---

## 3. Regra de freshness

Antes de responder sobre:

- preço;
- disponibilidade;
- financiamento;
- condição comercial;
- reserva;

o Mímir deve consultar a API atual.

Dados antigos de memória podem servir como contexto histórico, nunca como confirmação atual.

---

## 4. Identificadores

Preferir IDs opacos:

- `client_id`;
- `lot_id`;
- `document_id`;
- `reservation_id`;
- `interest_id`;
- `request_id`;
- `correlation_id`.

Não usar CPF, telefone ou e-mail como identificador interno principal.

---

## 5. Envelope de resposta

Formato candidato:

```json
{
  "data": {},
  "meta": {
    "request_id": "...",
    "correlation_id": "...",
    "generated_at": "...",
    "source_version": "..."
  }
}
```

Erros:

```json
{
  "error": {
    "code": "LOT_NOT_AVAILABLE",
    "message": "Lot is not available",
    "retryable": false,
    "correlation_id": "..."
  }
}
```

---

## 6. Tool mapping no Mímir

| Tool Mímir | API do site |
|---|---|
| `itapema.info` | `GET /api/v1/itapema/info` |
| `itapema.faq` | `GET /api/v1/itapema/faq` |
| `itapema.lot.search` | `GET /api/v1/itapema/lots` |
| `itapema.lot.get` | `GET /api/v1/itapema/lots/{lot_id}` |
| `itapema.lot.availability` | `GET /api/v1/itapema/lots/{lot_id}/availability` |
| `itapema.lot.price` | `GET /api/v1/itapema/lots/{lot_id}/price` |
| `itapema.lot.financing` | `GET /api/v1/itapema/lots/{lot_id}/financing` |
| `realestate.client.lookup` | client lookup privado |
| `realestate.client.create` | create client |
| `realestate.client.update` | update client |
| `itapema.interest.create` | create interest |
| `itapema.document.upload` | document upload |
| `itapema.document.status` | document status |
| `itapema.reservation.prepare` | reservation prepare |
| `itapema.reservation.submit` | reservation request |

---

## 7. Segurança

Requisitos:

- TLS;
- autenticação de serviço;
- autorização por operação;
- timeouts;
- retries limitados;
- idempotência;
- masking;
- audit;
- secrets fora do Git;
- payload mínimo.

---

## 8. Política de retry

GET idempotente:

- retry limitado em falha transitória.

POST/PATCH:

- usar `Idempotency-Key`;
- não repetir cegamente;
- respeitar conflito.

---

## 9. Timeouts

Definir timeouts explícitos por ferramenta.

O agente deve preferir:

`não consegui confirmar agora`

a inventar resultado quando a API falhar.

---

## 10. Confiança e linguagem ao cliente

### Confirmado pela API

Pode usar linguagem factual:

`O sistema informa que o lote está disponível neste momento.`

### API indisponível

Usar:

`Não consegui confirmar a disponibilidade agora.`

Nunca:

`Está disponível`

com base em memória/cache quando a política exige consulta ao vivo.

---

## 11. Operações irreversíveis

O contrato não deve expor ao agente de atendimento:

- confirmar venda;
- mudar preço;
- cancelar contrato;
- excluir cliente;
- apagar documento;
- marcar lote vendido.

Se futuramente necessárias, usar outro perfil administrativo com autorização explícita e workflow separado.

---

## 12. Dados pessoais

O Mímir deve receber, por padrão:

- client_id;
- nome;
- contato necessário;
- preferências;
- status;
- PII mascarada;
- document status.

Não receber por padrão:

- imagem de documento;
- CPF completo;
- RG completo;
- endereço integral;
- contrato completo.

---

## 13. Memória

Pode virar memória candidata:

- preferência por bairro/região;
- orçamento aproximado;
- tipo de lote;
- preferência de financiamento;
- lote de interesse;
- visita;
- resultado do atendimento;
- preferência de contato.

Não deve virar memória permanente:

- documento;
- CPF completo;
- RG;
- comprovante;
- tokens;
- dados de autenticação.

---

## 14. Observabilidade

O mesmo `correlation_id` deve acompanhar, quando possível:

```text
WhatsApp event
  -> Mímir request
  -> tool call
  -> Site API
  -> result
  -> response
```

Isso permite investigar sem guardar conteúdo sensível em labels.

---

## 15. Compatibility rule

O site pode trocar:

`JSON -> PostgreSQL`

sem alterar o Mímir, desde que mantenha a API.

O Mímir pode trocar:

`llama.cpp -> vLLM/outro`

sem alterar o site, desde que mantenha as tools.

---

## 16. Critério de pronto

Contrato V1 pronto quando:

- tool names congeladas para V1;
- endpoints V1 implementados;
- schemas versionados;
- auth validada;
- erros estruturados;
- idempotência validada;
- masking validado;
- test suite comum aprovada;
- exemplos reais sanitizados registrados;
- nenhuma dependência direta de arquivo JSON existir no Mímir.
