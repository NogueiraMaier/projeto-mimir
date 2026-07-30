# Documentação do Projeto Mimir

## Objetivo

O Mimir é o agente central de inteligência do Projeto Jarvis.

O projeto integra OpenClaw, modelos de linguagem, memória operacional local e memória permanente controlada.

## Ambiente

- Gentoo Linux com OpenRC
- OpenClaw instalado em /opt/openclaw
- Serviço executado pelo usuário openclaw
- Workspace em /var/lib/openclaw/workspace
- PostgreSQL 17
- pgvector
- Embeddings locais com 768 dimensões

## Documentos

- ARCHITECTURE.md: arquitetura e fluxo de memória
- SECURITY.md: controles e limites de segurança
- STATUS.md: estado técnico confirmado
- RUNBOOK.md: procedimentos operacionais
- ROADMAP.md: etapas planejadas

## Regra principal

A memória permanente usa PostgreSQL como fonte de verdade.

A promoção para active exige revisão e aprovação humana.
