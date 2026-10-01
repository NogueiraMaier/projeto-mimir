# Costa de Itapema — Site/API para integração com IA

Status: **ESPECIFICAÇÃO PARA IMPLEMENTAÇÃO NO SITE**  
Work ID: `SITE-COSTA-ITAPEMA-AI-API-01`  
Executor previsto: **OpenCode**  
Consumidor principal previsto: **Mímir Real Estate Agent**

Este documento é o handoff técnico para a IA que implementará a camada de integração no site `costadeitapemaba.com.br`.

Ele trata somente do **lado do site/backend**.

A implementação do agente, memória, WhatsApp, STT/TTS e políticas do Mímir é documentada separadamente em:

- `docs/MIMIR_REAL_ESTATE_AGENT_ROADMAP.md`

O contrato compartilhado é documentado em:

- `docs/integrations/COSTA_ITAPEMA_MIMIR_API_CONTRACT.md`

---

## 1. Premissa atual

Os dados do Costa de Itapema já são mantidos em arquivos JSON utilizados pelo site.

A primeira versão da integração **não precisa migrar imediatamente para PostgreSQL**.

O objetivo é criar uma camada de serviço/API sobre a fonte atual, preservando o funcionamento do site e permitindo futura migração de armazenamento sem alterar o contrato consumido pelo Mímir.

Princípio:

```text
JSON atual
   |
Service Layer
   |
Private/Public API
   |
Mímir / outros consumidores autorizados
```

Não permitir que o Mímir escreva diretamente nos arquivos JSON.

---

## 2. Regra de preservação

Antes de alterar qualquer arquivo:

1. identificar todos os JSONs atualmente utilizados;
2. identificar consumidores frontend/backend de cada JSON;
3. registrar schemas reais observados;
4. registrar caminhos reais;
5. registrar quais arquivos são públicos e quais são privados;
6. gerar backup;
7. criar testes de regressão;
8. não renomear campos ou arquivos sem migração explícita;
9. não apagar dados existentes;
10. não sobrescrever estruturas sem diff/revisão.

OpenCode deve **inspecionar o código e os JSONs reais antes de assumir nomes de campos**.

Os exemplos deste documento são contratos desejados, não prova do schema atual.

---

## 3. Separação obrigatória de dados

### 3.1 Dados públicos/comerciais

Podem ser expostos por API pública ou endpoint de leitura, se não contiverem dados pessoais ou internos.

Exemplos:

- informações do empreendimento;
- FAQ;
- localização pública;
- estrutura/lazer;
- fotos aprovadas;
- quadras/lotes públicos;
- metragem;
- tipo;
- disponibilidade pública;
- valor quando a política comercial permitir publicação;
- condições comerciais públicas;
- financiamento público;
- material comercial.

### 3.2 Dados privados

Devem ficar atrás de autenticação e autorização.

Exemplos:

- clientes;
- telefone;
- e-mail;
- CPF;
- RG/CNH;
- endereço;
- documentos enviados;
- histórico de atendimento;
- interesses;
- reservas;
- propostas;
- observações internas;
- origem do lead;
- status de validação documental;
- trilha de auditoria.

### 3.3 Dados que não podem ficar em URL pública

Nunca expor diretamente em `/public`, assets estáticos ou JSON acessível sem autenticação:

- CPF completo;
- RG/CNH;
- endereço particular;
- documentos;
- hashes de autenticação;
- tokens;
- chaves;
- notas internas;
- dados de reserva privados;
- logs administrativos.

---

## 4. Arquitetura alvo do lado do site

```text
Frontend atual
     |
JSON atuais
     |
+----+------------------------------+
|                                   |
site público                   AI/API Service
                                    |
                           +--------+---------+
                           |                  |
                       Public API         Private API
                           |                  |
                       catálogo           clientes
                       produto            reservas
                       lotes              documentos
                       FAQ                histórico
                       fotos              operações
                           |                  |
                           +--------+---------+
                                    |
                           Auth / Policy / Audit
                                    |
                                  Mímir
```

---

## 5. API versionada

Criar API versionada.

Base sugerida:

`/api/v1`

Não acoplar o contrato ao caminho físico dos JSONs.

---

## 6. Endpoints públicos candidatos

### Produto

- `GET /api/v1/itapema/info`
- `GET /api/v1/itapema/faq`
- `GET /api/v1/itapema/amenities`
- `GET /api/v1/itapema/location`

### Lotes

- `GET /api/v1/itapema/lots`
- `GET /api/v1/itapema/lots/{lot_id}`
- `GET /api/v1/itapema/lots/{lot_id}/availability`
- `GET /api/v1/itapema/lots/{lot_id}/price`
- `GET /api/v1/itapema/lots/{lot_id}/financing`

Filtros candidatos para listagem:

- quadra;
- status;
- tipo;
- metragem mínima/máxima;
- valor mínimo/máximo;
- faixa de entrada quando existir;
- financiamento;
- etapa;
- origem;
- promoção.

OpenCode deve mapear os filtros aos campos reais existentes.

---

## 7. API privada de clientes

Endpoints candidatos:

- `GET /api/v1/private/clients/by-phone/{phone}`
- `GET /api/v1/private/clients/{client_id}`
- `POST /api/v1/private/clients`
- `PATCH /api/v1/private/clients/{client_id}`
- `GET /api/v1/private/clients/{client_id}/interests`
- `POST /api/v1/private/clients/{client_id}/interests`

Regras:

- normalizar telefone;
- não retornar PII além do necessário;
- mascarar CPF/RG por padrão;
- não permitir consulta livre por CPF ao agente conversacional sem política específica;
- registrar quem consultou;
- registrar finalidade/operação;
- usar IDs internos em vez de PII como chave de integração.

---

## 8. Cadastro de cliente

Operação candidata:

`POST /api/v1/private/clients`

Campos lógicos desejados, ajustados ao schema real:

- nome;
- telefone;
- e-mail;
- origem;
- consentimento/contexto;
- empreendimento de interesse;
- observações permitidas;
- data de criação.

Não exigir CPF/RG para simples criação de lead se o processo comercial não exigir.

Separar:

`lead/customer profile`

de:

`formal reservation identity data`.

---

## 9. Interesse por lote

Operações candidatas:

- `POST /api/v1/private/clients/{client_id}/interests`
- `GET /api/v1/private/clients/{client_id}/interests`

Campos candidatos:

- lot_id;
- timestamp;
- source_channel;
- status;
- note;
- current_price_snapshot;
- availability_snapshot.

Snapshots servem para auditoria da conversa, mas não substituem consulta atual de preço/disponibilidade.

---

## 10. Reservas

Separar claramente:

```text
INTEREST
  !=
RESERVATION REQUEST
  !=
RESERVATION CONFIRMED
  !=
SALE
```

Endpoints candidatos:

- `POST /api/v1/private/reservations/prepare`
- `POST /api/v1/private/reservations`
- `GET /api/v1/private/reservations/{reservation_id}`

`prepare` deve validar:

- lote existe;
- status atual;
- valor atual;
- dados mínimos;
- documentos necessários;
- conflitos;
- regras comerciais.

A IA não deve possuir endpoint capaz de marcar venda como concluída.

Venda/baixa definitiva deve permanecer em fluxo administrativo autorizado.

---

## 11. Preço e disponibilidade

Preço e disponibilidade são dados dinâmicos.

Toda operação que dependa deles deve ler o estado corrente.

Evitar respostas baseadas em cache antigo.

Resposta candidata:

```json
{
  "lot_id": "F1-134",
  "status": "available",
  "price": 140000,
  "currency": "BRL",
  "updated_at": "2026-10-01T08:00:00-03:00",
  "requires_human_confirmation": false
}
```

O campo e valores reais devem ser definidos após inspeção do sistema.

---

## 12. Simulação financeira

Criar, somente se houver regra comercial determinística:

- `POST /api/v1/itapema/financing/simulate`

Entrada candidata:

- lot_id;
- entrada;
- prazo;
- modalidade.

Saída deve declarar:

- simulação;
- data/hora;
- regras aplicadas;
- validade;
- necessidade de confirmação;
- não equivalência a proposta contratual.

Nunca deixar o LLM calcular regras comerciais não fornecidas pelo sistema.

---

## 13. Documentos

Endpoints candidatos:

- `POST /api/v1/private/clients/{client_id}/documents`
- `GET /api/v1/private/clients/{client_id}/documents`
- `GET /api/v1/private/documents/{document_id}/status`

O upload deve:

1. validar tamanho;
2. validar MIME real;
3. restringir extensões;
4. gerar nome interno;
5. calcular hash;
6. armazenar fora do webroot;
7. registrar metadados;
8. executar verificação de segurança quando disponível;
9. não expor caminho físico;
10. não retornar o conteúdo para o LLM por padrão.

Resposta ao Mímir deve preferir:

```json
{
  "document_id": "DOC-...",
  "type": "CNH",
  "status": "received",
  "validation": "pending"
}
```

e não a imagem/documento bruto.

---

## 14. Armazenamento de documentos

Requisitos:

- fora da pasta pública;
- acesso autenticado;
- sem nome original como caminho de armazenamento;
- hash;
- tamanho;
- MIME;
- owner/client reference;
- created_at;
- retention state;
- audit log.

Não guardar documentos pessoais no Git.

---

## 15. Concorrência com JSON

Enquanto JSON for a fonte gravável:

- usar locking;
- escrever em arquivo temporário;
- fsync quando aplicável;
- rename atômico;
- backup/versionamento;
- schema validation;
- idempotência;
- não editar JSON com string replace;
- não permitir duas gravações simultâneas sem controle.

Exemplo:

```text
read current
   |
validate version
   |
apply mutation in memory
   |
validate schema
   |
write temp
   |
fsync
   |
atomic rename
   |
audit
```

Se o volume/concorrrência ultrapassar o limite seguro, migrar storage para banco mantendo a API.

---

## 16. Idempotência

Operações de criação devem aceitar `Idempotency-Key`.

Obrigatório ou recomendado para:

- create client;
- create interest;
- reservation prepare/submit;
- document registration;
- schedule request.

Evitar duplicidade causada por retry de webhook/WhatsApp.

---

## 17. Autenticação de serviço

O Mímir não deve acessar API privada anonimamente.

Opções aceitáveis a avaliar:

- service token rotacionável;
- mTLS;
- rede privada/WireGuard + credencial;
- combinação.

Não gravar credenciais no repositório.

---

## 18. Autorização por operação

Não criar um único token com poder irrestrito.

Perfis candidatos:

### `mimir-realestate-read`

- produto;
- lotes;
- disponibilidade;
- preço;
- financiamento;
- client lookup limitado.

### `mimir-realestate-write`

- criar cliente;
- atualizar preferências;
- registrar interesse;
- upload/status de documento;
- preparar reserva.

### operações negadas ao agente

- alterar preço;
- apagar cliente;
- apagar documento;
- marcar lote vendido;
- confirmar venda;
- editar regras comerciais;
- conceder desconto;
- alterar reserva administrativa concluída.

---

## 19. Auditoria

Registrar, quando aplicável:

- timestamp;
- service identity;
- operation;
- client_id;
- lot_id;
- request_id;
- idempotency key;
- result;
- HTTP status;
- source/channel;
- correlation_id.

Não registrar:

- token;
- documento bruto;
- CPF completo;
- segredo.

---

## 20. Máscara e minimização

Respostas ao agente devem retornar somente o necessário.

Exemplo:

```json
{
  "client_id": "CLI-451",
  "name": "Carlos Silva",
  "phone_last4": "1234",
  "document_status": "complete",
  "cpf_masked": "***.***.***-42"
}
```

Não retornar dados completos apenas porque existem no JSON.

---

## 21. LGPD / privacidade

A implementação deve prever tecnicamente:

- finalidade;
- minimização;
- consentimento/contexto quando aplicável;
- retenção;
- acesso;
- correção;
- exclusão conforme política autorizada;
- auditoria;
- classificação de dados.

Decisões jurídicas e políticas de retenção devem ser definidas pelo responsável pelo tratamento; a IA não deve inventá-las.

---

## 22. Contrato de erro

Erros devem ser estruturados.

Exemplo:

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

Códigos candidatos:

- `INVALID_REQUEST`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `CLIENT_NOT_FOUND`
- `LOT_NOT_FOUND`
- `LOT_NOT_AVAILABLE`
- `PRICE_CHANGED`
- `DUPLICATE_REQUEST`
- `DOCUMENT_INVALID`
- `CONFLICT`
- `RATE_LIMITED`
- `INTERNAL_ERROR`

---

## 23. Versionamento otimista

Quando atualizar registros graváveis, usar versão/ETag ou equivalente.

Objetivo:

evitar que um atendimento sobrescreva atualização feita por outro.

---

## 24. Rate limiting e proteção

Aplicar ao menos:

- rate limit;
- tamanho máximo;
- timeouts;
- input validation;
- auth failure throttling;
- logs;
- CORS somente onde necessário;
- CSRF para interfaces browser autenticadas;
- headers de segurança;
- sem stack trace público.

---

## 25. Endpoint de health

Criar:

- `GET /api/v1/health`

Deve informar somente saúde mínima.

Não vazar:

- paths;
- versões sensíveis desnecessárias;
- segredos;
- conteúdo dos JSONs.

---

## 26. Contrato com Mímir

Implementar o contrato descrito em:

`docs/integrations/COSTA_ITAPEMA_MIMIR_API_CONTRACT.md`

O site não deve depender do prompt do Mímir.

O Mímir não deve depender da estrutura interna dos JSONs.

---

## 27. Testes mínimos

### Public API

- produto;
- FAQ;
- lote existente;
- lote inexistente;
- filtros;
- preço;
- disponibilidade.

### Private API

- auth válida;
- auth inválida;
- client lookup;
- create client;
- duplicate client/retry;
- update concorrente;
- interest;
- document metadata;
- reservation prepare.

### Segurança

- path traversal;
- upload MIME falso;
- arquivo grande;
- JSON inválido;
- token ausente;
- token expirado;
- operação proibida;
- PII masking.

### Integridade

- rollback;
- JSON original preservado;
- atomic write;
- backup;
- restart.

---

## 28. Observabilidade

Métricas/logs candidatos:

- requests_total;
- errors_total;
- latency;
- auth_failures;
- client_creates;
- reservation_prepare;
- document_upload;
- JSON write failures;
- lock contention.

Evitar PII em labels.

---

## 29. Plano de implementação para OpenCode

### SITE-0 — descoberta

- mapear repositório;
- mapear JSONs;
- mapear schemas;
- mapear frontend;
- identificar dados públicos/privados;
- identificar armazenamento de documentos;
- produzir relatório de impacto.

**Não modificar dados nesta fase.**

### SITE-1 — testes e abstração

- criar validação/schema;
- criar service layer de leitura;
- testes de regressão;
- manter site atual funcionando.

### SITE-2 — Public API

- produto;
- FAQ;
- lotes;
- disponibilidade;
- preço;
- financiamento.

### SITE-3 — Private API read

- service auth;
- client lookup;
- masking;
- audit.

### SITE-4 — Private API write

- create/update client;
- interest;
- locking/atomic write;
- idempotência;
- optimistic concurrency.

### SITE-5 — documentos

- private storage;
- upload;
- hash;
- metadata;
- status.

### SITE-6 — reserva

- prepare;
- submit request;
- conflict handling;
- nenhum endpoint de confirmação de venda para IA.

### SITE-7 — hardening

- security tests;
- rate limit;
- backups;
- logs;
- health;
- rollback.

---

## 30. Critérios de aceite do lado do site

A integração do site só deve ser considerada pronta quando:

- o site atual continuar funcionando;
- nenhum JSON atual tiver sido apagado;
- schemas estiverem documentados;
- dados privados não estiverem públicos;
- API tiver versão;
- autenticação existir;
- masking existir;
- writes forem atômicos;
- idempotência estiver validada;
- auditoria existir;
- documentos ficarem fora do webroot;
- Mímir puder pesquisar lote sem conhecer caminhos internos;
- Mímir puder localizar/criar cliente com mínimo privilégio;
- reserva for solicitação controlada, não confirmação de venda;
- testes de rollback estiverem documentados.

---

## 31. Instruções explícitas para OpenCode

Ao receber este documento:

1. não começar reescrevendo o site;
2. não migrar JSON para banco sem autorização;
3. não alterar campos atuais antes de mapear dependências;
4. não apagar conteúdo;
5. não mover documentos sem plano/backup;
6. implementar por fases;
7. gerar diff claro;
8. testar após cada fase;
9. manter compatibilidade do site;
10. atualizar documentação com o estado real;
11. marcar cada item como `IMPLEMENTED`, `VALIDATED`, `PENDING` ou `BLOCKED`;
12. não declarar pronto sem evidência de teste.

---

## 32. Resultado esperado

Ao final, o Costa de Itapema terá uma camada segura e estável para IA:

```text
site/JSON
   |
API versionada
   |
auth + policy + audit
   |
Mímir Real Estate Agent
```

A API torna a fonte atual utilizável sem acoplar o Mímir à implementação interna e prepara a futura migração de JSON para banco, caso necessária.
