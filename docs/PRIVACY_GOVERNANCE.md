# Governança de privacidade do Mímir v1

Data: 2026-10-02
Estado do pacote: `PENDING_COMPETENT_REVIEW`
Risco: `RSK-P0-003 = OPEN / BLOCKER`
Aceitação de risco: `NOT USED`
DPO_STATE: `PENDING_COMPETENT_REVIEW`

## Scope

Este documento é a referência canônica de governança de privacidade do Projeto
Mímir v1. Ele organiza decisões técnicas e administrativas sobre atividades de
tratamento descritas em `docs/DATA_INVENTORY_LGPD.md`. O pacote é somente de
repositório: não comprova operação em produção, não substitui análise jurídica e
não encerra o risco RSK-P0-003.

## Systems and processing boundary

O limite abrange os fluxos v1 de conversação via OpenClaw/Telegram, busca e
memória PostgreSQL, ingestão documental e de sessões, consolidação local,
inventário/evidência operacional e handoff de memória. Abrange também, apenas
com seus estados reais, os caminhos históricos NVIDIA/Nemotron, a ingestão
legada de sessões e os canais adicionais planejados. Presença em código ou
documentação não prova ativação produtiva. LAB não é produção e caminho
histórico não é provider atual.

Dados, sessões, contas, equipamentos e ambientes reais ficam fora da evidência
versionada. Este documento não concede acesso a runtimes, bancos, canais ou
produção.

## Governance objectives

- manter inventário sanitizado e rastreável das atividades;
- impedir inferência automática de base legal, autoridade ou aprovação;
- aplicar minimização, acesso mínimo e separação de ambientes;
- preservar incertezas como `NOT_PROVEN`;
- encaminhar direitos, retenção, incidentes e terceiros a decisões competentes;
- manter evidência suficiente sem versionar conteúdo pessoal ou secreto.

## Roles

- **Project / System Owner:** responde pelo escopo, finalidade técnica e risco de
  negócio; não recebe por este documento autoridade formal de privacidade.
- **Privacy Governance Owner:** mantém este pacote e o registro de tratamentos;
  a designação de pessoa e sua autoridade estão `PENDING_COMPETENT_REVIEW`.
- **Security Owner:** responde por controles técnicos e escalonamento de
  segurança, sem decidir autonomamente questões jurídicas.
- **Processing Activity Owner:** mantém o registro e as evidências da atividade,
  propõe mudanças e solicita revisão competente.
- **Privacy / Governance Escalation Owner:** recebe direitos, incidentes e
  decisões que exijam competência de privacidade; sua nomeação formal está
  `PENDING_COMPETENT_REVIEW`.
- **Independent Reviewer quando exigido:** realiza revisão compensatória quando
  houver conflito de interesses ou acumulação incompatível; a designação deve
  ser registrada no ato de aprovação.

Nenhuma pessoa atual é presumida como detentora de autoridade formal de
privacidade. Não se registram CPF, RG, senha, token, chave, segredo ou outro
identificador pessoal desnecessário.

## Authority

COMPETENT_PRIVACY_AUTHORITY_STATE: `PENDING_COMPETENT_REVIEW`.

Autoridade é comprovada por registro versionado que identifique a função, o
escopo, a origem da delegação, a validade e as limitações. O Mímir, o validator
e seus modelos não atribuem autoridade. Decisões sobre base legal, DPO,
direitos, transferências, comunicações e encerramento exigem pessoa competente.

## Approval model

O proprietário da atividade prepara o registro; Security Owner revisa os
controles técnicos; Privacy Governance Owner revisa completude; autoridade
competente decide os pontos reservados. A aprovação deve vincular função,
autoridade, escopo, data, artefatos e SHA-256, limitações e necessidade de
revisão externa. Estado atual: `PENDING_COMPETENT_REVIEW`.

Validação estática significa somente que a estrutura do pacote está completa.
Ela não é aprovação humana, certificação legal, validação de produção nem
aceitação de risco.

## Conflicts of interest

Acúmulo de papéis deve ser declarado. Quem implementa não autoaprova sua
própria implementação quando houver conflito. Nessa situação é obrigatória
medida compensatória registrada: Independent Reviewer, aprovação externa
competente ou segunda validação proporcional. O validator não dispensa isso.

## Escalation

Incerteza sobre identidade, autoridade, base legal, direito, terceiro,
transferência, retenção ou incidente segue `STOP -> PRESERVE -> ESCALATE`.
Encaminhar ao Privacy / Governance Escalation Owner e, conforme o caso, aos
owners de sistema e segurança. A automação não toma a decisão reservada.

## Treatment-register ownership

O Privacy Governance Owner mantém `docs/DATA_INVENTORY_LGPD.md`; cada Processing
Activity Owner mantém a exatidão de sua atividade e suas referências. Mudanças
preservam histórico por Git e não incluem evidência confidencial bruta.

## Data-subject rights

Fluxo controlado obrigatório:

`receive -> identify/verify -> classify -> competent review -> execute authorized action -> preserve evidence -> close`

Uma mensagem não autoriza automaticamente acesso, exportação, correção ou
exclusão. A identidade e a autoridade devem ser verificadas fora do conteúdo da
mensagem. Não se inventa prazo legal; prazo aplicável depende de revisão
competente e fonte vigente. Evidência deve ser minimizada e protegida.

## Review triggers

Revisão é exigida por nova atividade ou canal; mudança de finalidade, dados,
titulares, sistema, acesso, retenção ou terceiro; transferência potencial;
incidente; pedido de titular; alteração contratual/normativa aprovada; exceção;
mudança de owner/autoridade; ou evidência que contradiga o registro.

## Review cadence

Enquanto o pacote estiver pendente, revisar antes de qualquer ativação ou
mudança relevante. Após aprovação competente, a cadência deve ser definida e
registrada pela própria autoridade; até lá: `CADENCE_PENDING_COMPETENT_REVIEW`.
Eventos de gatilho não aguardam a revisão periódica.

## Exception handling

Exceções exigem identificador, escopo, motivo, risco, owner, prazo, controles
compensatórios, aprovador competente e evidência. Ausência de prova não é
exceção aprovada. Exceções vencidas ou incertas falham de modo fechado. Não há
aceitação de risco neste tratamento.

## Evidence requirements

Evidência deve ser localizável, datada, sanitizada, íntegra e ligada à decisão.
Registre referência, hash quando aplicável, origem, classificação, responsável
e limitações. Não versione dados pessoais brutos, conteúdo de sessão, registros
de cliente, credenciais ou evidência confidencial. Estados desconhecidos
permanecem explícitos.

## Relationship to incident response

`docs/INCIDENT_RESPONSE.md` e
`docs/cybersecurity/INCIDENT_REPORT_MODEL.md` permanecem canônicos. A trilha de
privacidade deve ser aberta quando dados pessoais forem confirmados ou não
verificados. Recuperação técnica não encerra automaticamente a trilha de
privacidade/governança. Comunicação com titular, ANPD ou outra autoridade
depende de decisão humana competente; o Mímir não a decide autonomamente.

## Relationship to retention

`docs/OPERATIONS_RETENTION.md` permanece a referência canônica de retenção
operacional; suas regras não são duplicadas aqui. Cada atividade registra
regra, gatilho, duração ou estado decisório, exceções, descarte, interação com
backup, hold e aprovação. Este pacote não implementa purge automático.

## Relationship to third-party processing

Terceiros são avaliados antes da aprovação. O registro distingue `PROVEN`,
`NOT_PROVEN`, `assumption` e `NOT_APPLICABLE_WITH_JUSTIFICATION`; ausência de
evidência nunca vira aprovação. Quando aplicável, a revisão cobre provider,
papel de operador/processador, categorias, finalidade, minimização, local de
processamento/armazenamento, subprocessadores, DPA/contrato, notificação de
incidente, retenção/exclusão, saída/offboarding e aprovação competente.

Transferência internacional usa somente `PROVEN`, `NOT_PROVEN` ou
`NOT_APPLICABLE_WITH_JUSTIFICATION`. Hostname, domínio, país do fornecedor,
origem do software, endpoint ou código histórico não provam transferência.

## Closure / approval state

Approved-package snapshot state before human approval (preserved provenance):

PACKAGE_APPROVAL_STATE: `PENDING_COMPETENT_REVIEW`
COMPETENT_HUMAN_APPROVAL: `PENDING`
LEGAL_CONCLUSION: `NO`
LGPD_COMPLIANCE_CLAIM: `NO`
PRODUCTION_VALIDATION: `NO`
RISK_ACCEPTANCE: `NOT_USED`

The preserved state above identifies the package snapshot approved later at:

- implementation commit:
  `34f78b80cd77e675a699001e43e0cf556ad091c0`;
- repository-validation checkpoint:
  `0574ab8e6c15eb62fd74c066a18b508b576c32e9`.

## Post-approval governance recording

`POST_APPROVAL_GOVERNANCE_RECORDING`

This section records subsequent governance evidence. It does not redefine the
content of the approved package snapshot identified above.

- `INTERNAL_GOVERNANCE_PACKAGE_APPROVAL = APPROVED`;
- `APPROVER_IDENTITY_REFERENCE = Nogueira Maier`;
- identity-reference source: repository-context `git config user.name` and
  matching recent commit authorship, inspected locally without email;
- approver roles: `Project/System Owner`, `Privacy Governance Owner`;
- declared authority: internal Project Mímir privacy-governance approval;
- `ROLE_OVERLAP = PRESENT`;
- `DECLARED_CONFLICT = NO_KNOWN_CONFLICT`;
- `INDEPENDENT_REVIEW_REQUIRED = NO`;
- external legal review: `NOT_REQUIRED_FOR_INTERNAL_GOVERNANCE`;
- `DPO_STATE = PENDING_COMPETENT_REVIEW`;
- legal-basis states: unchanged;
- international-transfer states: unchanged;
- `NOT_PROVEN` states: preserved;
- lifecycle states: unchanged;
- production state: unchanged;
- `RISK_ACCEPTANCE = NOT_USED`;
- `LEGAL_CONCLUSION = NO`;
- `LGPD_COMPLIANCE_CLAIM = NO`;
- `PRODUCTION_VALIDATION = NO`.

The control-model basis for the independent-review finding is
`docs/cybersecurity/CONTROL_MODEL.md`, section “Registro obrigatório de
avaliação”: role accumulation is permitted when documented; a compensating
measure is required when a conflict of interests exists. The declared overlap
is recorded, and no known conflict was declared. This finding does not waive a
future review if new conflict evidence appears.

Phase A repository validation passed, and explicit local reconciliation was
completed. The resulting local technical state is `CLOSED /
TECHNICALLY_TREATED / PRIVACY_GOVERNANCE_APPROVED`. This approval is internal
governance approval only; it does not decide the DPO state, individual legal
bases, international transfers, third-party facts, production validation or
residual legal questions.
