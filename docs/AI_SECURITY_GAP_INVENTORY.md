# Mímir — Gap Inventory de Segurança Conversacional

Status: **BASELINE ARQUITETURAL / REVISÃO DE ESTADO**

Escopo: **exclusivo do Projeto Mímir**.

Referências:

- `docs/CONVERSATIONAL_SECURITY.md`
- `docs/AI_SECURITY_TEST_MATRIX.md`
- `docs/SECURITY.md`
- `docs/ARCHITECTURE.md`
- `docs/SESSION_INGESTION_V2.md`
- `docs/OPERATIONS.md`

## Regra de classificação

Este inventário não considera um controle implementado apenas porque o modelo
costuma obedecer a uma instrução.

Estados:

- **EXISTING_VALIDATED** — há enforcement técnico e evidência reproduzível;
- **PARTIAL** — existe parte relevante do controle, mas não cobre todo o
  requisito arquitetural;
- **PROPOSED** — está documentado, sem enforcement suficiente;
- **MISSING** — não há evidência versionada suficiente do controle requerido;
- **OUT_OF_SCOPE_NOW** — requisito válido, mas o componente/canal ainda não
  existe no escopo operacional atual.

## Resumo

| Domínio | Estado | Evidência atual | Gap principal |
|---|---|---|---|
| Conteúdo externo como dado não confiável | PARTIAL | sessões v2 entram como `confidential/protected_source`; captura exclui system/tool/thinking e exige owner provenance | não existe envelope canônico de trust/taint para todos os canais/fontes |
| Identidade separada do conteúdo | PARTIAL | `senderIsOwner` na captura; peer auth PostgreSQL; Telegram runtime com allowlist validada | não existe modelo unificado de principal/tenant/scope entre canais |
| Tool capability / allowlist | PARTIAL | OpenClaw main usa conjunto restrito de tools; camada ops usa catálogo fechado READ/PLAN/EXECUTE | não existe PDP genérico obrigatório antes de toda tool call |
| Autorização fora do LLM | PARTIAL | ops API, peer identity, plan hash e grants controlados; writer exige aprovação ligada a hashes | ainda não é uma camada transversal para todas as tools/agentes/canais |
| Tool parameter validation | PARTIAL | ops rejeita campos/opções inesperadas; writer valida UUID/hash/socket/database | sem contrato tipado uniforme para ferramentas em geral |
| Planner / executor separation | PARTIAL | planejamento e execução ops são fases distintas | não existe executor independente genérico para agentes/tools |
| Sandbox / least privilege | PARTIAL | serviços dedicados, `openclaw`, peer roles, no direct DB DML, llama local | não existe sandbox universal por tool/subagente |
| Proteção de secrets em entrada | PARTIAL | capture v2 bloqueia padrões de segredo; ops redaction | detecção é regex/heurística e não há secret-context gate global |
| Proteção contra exfiltração na saída | MISSING | redaction existe em relatórios ops específicos | não há output exposure/DLP gate geral antes de resposta por canal |
| System/developer prompt extraction | PROPOSED | política documental | falta enforcement arquitetural/egress específico |
| Direct prompt injection | PROPOSED | política documental | falta teste/enforcement externo específico |
| Indirect prompt injection | PARTIAL | sessão/documento não é automaticamente promoção de memória; source protegida | consolidator/context builder ainda precisa preservar taint/instrução como dado |
| Jailbreak / obfuscação | PROPOSED | política documental | sem camada externa validada para Base64/Unicode/multilingual bypass |
| Memory poisoning | PARTIAL | candidate/active não são automáticos; revisão humana; writer não promove; protected consolidator força `UNTRUSTED_OBSERVATION` e evidence binding externo ao LLM | falta policy de trust transversal para outras fontes/canais e etapas fora do consolidator |
| Promoção de memória | EXISTING_VALIDATED | writer e ingestão não criam `memory_records`; fluxo exige revisão/promoção separadas | consolidator futuro deve preservar a mesma invariável |
| Proveniência de sessão | EXISTING_VALIDATED | session id/key, fingerprints, content hash, source ref, updatedAt, collector version, IDs únicos, seq único/estritamente crescente e contagem `totalMessages` exata | ampliar provenance/trust para outras fontes externas |
| Context minimization | PARTIAL | captura remove system/toolResult/thinking/toolCall e não expõe transcript em dry-run | não há context builder universal por classification/scope |
| Dados `CONFIDENTIAL` para modelo externo | PARTIAL | política atual proíbe sessão protected em NVIDIA; fluxo P1 exige loopback | falta policy gate geral de model routing por classificação |
| Modelo local / remoto como autoridade | PROPOSED | arquitetura declara modelo sem autoridade | falta enforcement central que preserve capabilities ao trocar modelo |
| Model routing privilege escalation | MISSING | routing planejado/documentado | sem policy engine validado para capability/secret/scope invariantes |
| Subagent privilege inheritance | MISSING | subagentes são planejados | sem delegation token/capability envelope implementado |
| Telegram channel policy | PARTIAL | DM allowlist numérica e grupos desabilitados no runtime validado | falta perfil de capability formal + principal/scope versionado |
| WhatsApp channel policy | OUT_OF_SCOPE_NOW | integração ainda não implementada no runtime atual | definir identidade, linking e capability antes de habilitar |
| Webchat public policy | OUT_OF_SCOPE_NOW | sem evidência de runtime atual | definir perfil mínimo antes de habilitar |
| Voice/STT trust | OUT_OF_SCOPE_NOW | requisitos documentados | autenticação deve permanecer externa; criar testes antes do canal |
| PDF/OCR/image trust | PROPOSED | requisito documentado | falta envelope de provenance/taint no ingestion/context builder |
| Cross-user isolation | MISSING | nenhum contrato geral versionado | definir principal/scope por consulta, memória e resposta |
| Cross-tenant isolation | MISSING | ops atual explicitamente não é API multiusuário | definir tenant boundary antes de canais externos multi-cliente |
| Audit de prompt injection/jailbreak | MISSING | ops audit existe para operações | falta event taxonomy específica T-AI / security decision |
| Anti-replay | PARTIAL | writer approval é ligado a fingerprints; ops plan hash/idempotência de sessão | falta nonce/expiry/request-id genérico para ações sensíveis |
| Rate limiting | MISSING | sem evidência versionada suficiente | definir por canal/tool/principal |
| Human-in-the-loop | PARTIAL | memória e operações sensíveis possuem aprovação explícita | formalizar matriz única por risk/action |
| Fail-closed | PARTIAL | capture/writer/ops possuem vários guards fail-closed | falta policy transversal para canal/context/tool/model/output |

## 1. Controles já fortes e que devem ser preservados

### 1.1 Memória protegida e promoção separada

O pipeline atual já estabelece uma barreira importante:

```text
external/session content
        ↓
protected source / confidential event
        ↓
local consolidation
        ↓
candidate
        ↓
human review
        ↓
active
```

A ingestão e o writer v2 não promovem automaticamente para `candidate` ou
`active`.

Esse comportamento deve ser tratado como invariante e reutilizado pelos novos
controles de segurança.

### 1.2 Least privilege do PostgreSQL

`mimir_app`, `mimir_search` e a futura `mimir_ops` usam interfaces
controladas em vez de DML direto amplo.

Isso fornece enforcement fora do modelo e é um padrão reutilizável para a nova
policy layer.

### 1.3 Operações por catálogo

A camada operacional já demonstra o padrão desejado:

- operação nomeada;
- parâmetros validados;
- plan hash;
- aprovação explícita;
- identidade separada;
- backend revalida estado/permissão;
- sem shell arbitrário para o agente.

Isso deve servir como referência para o futuro tool-policy envelope.

## 2. Gaps prioritários antes do consolidator protected-source

O consolidator é o primeiro componente que receberá conteúdo
`confidential` não confiável e o entregará diretamente a um LLM local.

Antes de implementá-lo, o contrato mínimo deve impor:

1. fonte lida apenas por `mimir.read_consolidation_source(event_id)`;
2. endpoint somente loopback e porta explicitamente permitida;
3. modelo remoto proibido para essa classificação;
4. conteúdo da sessão marcado internamente como untrusted data;
5. prompt do consolidator separado do conteúdo por estrutura, não por simples
   concatenação sem delimitação;
6. nenhuma instrução presente na sessão pode alterar policy, endpoint,
   tool/capability ou estado de memória;
7. `chat_template_kwargs.enable_thinking=false` para esta tarefa estruturada;
8. resposta aceita somente de `message.content`;
9. `reasoning_content` nunca persistido, logado ou promovido;
10. resposta obrigatoriamente JSON conforme schema fechado;
11. campos desconhecidos rejeitados;
12. tamanho/contagem de candidatos limitados;
13. candidato continua sem autoridade e sem promoção automática;
14. saída contendo padrões de segredo deve ser rejeitada antes de qualquer
    arquivo reviewed/candidate;
15. dry-run por padrão;
16. nenhum write em produção durante validação;
17. hashes/proveniência devem ligar output ao event/source original;
18. erro, JSON inválido, timeout, model drift ou classification inesperada
    resultam em fail-closed.

## 3. Decisão necessária sobre classes de memória

A proposta de segurança usa:

- FACT;
- PREFERENCE;
- EPHEMERAL_CONTEXT;
- OPERATIONAL_STATE;
- SECURITY_DECISION;
- UNTRUSTED_OBSERVATION.

O schema atual usa outra taxonomia de `memory_type`.

Não mapear por nome implicitamente.

Opções para ADR futuro:

1. manter `memory_type` atual e adicionar dimensão separada de
   `trust/validation_class`;
2. estender enum/check atual com novos tipos;
3. mapear classes de segurança para tipos atuais + metadata obrigatória.

Recomendação de desenho a validar: **separar semântica da memória de confiança**.
Ou seja, `memory_type` descreve o que a memória é; um novo campo/metadata
descreve confiança/validation state. Isso evita confundir, por exemplo,
`decision` com `SECURITY_DECISION` ou `semantic` com `FACT`.

Nenhuma alteração de schema é autorizada por este documento.

## 4. Primeira bateria adversarial

Antes de ampliar o consolidator para sessão real, priorizar:

- T-AI-002 indirect prompt injection;
- T-AI-005 secret extraction;
- T-AI-023 memory poisoning;
- T-AI-024 unauthorized memory promotion;
- T-AI-032 output secret leakage;
- T-AI-033 data minimization violation;
- T-AI-034 unauthorized external-model disclosure.

PASS deve demonstrar enforcement no código/harness, não apenas recusa do Qwen.

## 5. Critério para avançar

O consolidator pode avançar de proposta para
`IMPLEMENTED_NOT_VALIDATED` somente quando:

- contrato de input/output estiver versionado;
- endpoint/model routing estiver fechado por allowlist;
- JSON schema estiver fechado;
- taint/untrusted provenance for preservado;
- reasoning não fizer parte da saída persistível;
- secrets/output checks existirem fora do LLM;
- no-auto-promotion permanecer verificável;
- testes sintéticos cobrirem injection + poisoning + exfiltration.

Produção continua fora de escopo até checkpoints separados.
