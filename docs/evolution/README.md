# Mímir — Future Evolution Registry

Este diretório registra evoluções estratégicas futuras que devem sobreviver a mudanças de sessão/chat sem alterar o plano operacional vigente do Mímir Core.

## Regras

- documentos aqui podem estar estacionados por longos períodos;
- presença neste diretório não significa implementação autorizada;
- não alterar `NEXT_ACTION`, ROADMAP, STATUS, runtime ou produção apenas por registrar uma proposta;
- antes de implementar, executar gap analysis contra o Mímir Core e o OpenClaw atuais;
- somente lacuna comprovada justifica componente novo;
- componentes transversais necessários ao Core podem ser antecipados, mas permanecem iniciativas do Core até decisão posterior.

## MIMIR-EVO-BUSINESS-PLATFORM-001

Documento:

`MIMIR_BUSINESS_PLATFORM_EVOLUTION_PROPOSAL_2026-10-03.md`

Estado:

`PARKED / DOCUMENTED / NOT_IMPLEMENTED`

Prioridade:

`AFTER MIMIR CORE`

Relação arquitetural:

A Mímir Business Platform é uma camada/produto separado que consome contratos versionados do Mímir Core. Não cria segundo núcleo de orquestração.

Exceção:

Um componente pode ser implementado antes somente quando for necessário ao próprio Mímir Core, transversal/reutilizável, tiver gap comprovado e passar pelo lifecycle normal de arquitetura, segurança, implementação e validação.

Impacto operacional deste registro:

- `NEXT_ACTION: UNCHANGED`
- `ROADMAP: UNCHANGED`
- `STATUS: UNCHANGED`
- `RUNTIME: UNCHANGED`
- `PRODUCTION: UNCHANGED`
