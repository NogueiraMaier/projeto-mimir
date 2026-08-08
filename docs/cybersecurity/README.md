# Módulo Cybersecurity do Projeto J.A.R.V.I.S.

## Objetivo

Estabelecer uma base documental proporcional para governança, avaliação de controles, evidências, achados e resposta a incidentes cibernéticos em pequenas empresas. Este pacote P0 descreve o estado conhecido e os critérios para evolução; não declara conformidade nem comprova implantação operacional.

## Taxonomia e arquitetura obrigatórias

- **J.A.R.V.I.S.** é o sistema completo.
- **Mímir** é o superagente coordenador.
- **OpenClaw** é o runtime.
- **PostgreSQL 17 com pgvector** é a fonte de verdade da memória durável.
- **HUD** é somente interface e não contém lógica crítica.
- **Gentoo com OpenRC** é o ambiente padrão.
- O núcleo do projeto não usa Docker.

O HUD apresenta informações e solicita ações, mas decisões críticas, autorização, regras de segurança e persistência devem permanecer fora da interface. Mímir coordena; não recebe autorização permanente para alterações críticas. A arquitetura detalhada existente está em `docs/ARCHITECTURE.md`, com contradições e lacunas registradas em `docs/review/cybersecurity/2026-08-04/AUDITORIA_CONSOLIDADA.md` e consolidadas em `docs/cybersecurity/BASELINE_P0.md`.

## Escopo

O módulo cobre governança de cybersecurity, ativos, software, dados, riscos, configurações, identidades, acessos, vulnerabilidades, logs, comunicações digitais, endpoints, continuidade, rede, monitoramento, treinamento, terceiros, resposta e recuperação. A linha de base combina, de forma proporcional, CIS Controls v8.1 IG1, NIST CSF 2.0, NIST SP 1300, NIST SP 800-61 Rev. 3 e LGPD.

Os cruzamentos normativos deste P0 são temáticos e preliminares quando o mapeamento oficial não está comprovado no repositório. O módulo não inventa salvaguardas, categorias, subcategorias ou requisitos.

## Limites

- Avaliação documental e estática; estado operacional não foi verificado.
- Nenhuma implantação automática, ação em produção, varredura ou teste ativo é autorizada.
- Declarações históricas são diferenciadas de evidência e de validação independente.
- A proporcionalidade reduz complexidade e custo para pequenas empresas, não elimina obrigações legais nem riscos relevantes.
- O conteúdo não é certificação, garantia de segurança ou parecer jurídico.

## Separação de domínios

Cybersecurity trata eventos que afetam confidencialidade, integridade, disponibilidade, autenticidade e tratamento seguro de informações e sistemas. Segurança e Saúde no Trabalho (SST), acidentes de trabalho, doenças ocupacionais e investigações trabalhistas estão fora deste módulo e exigem processos, responsáveis e referenciais próprios. Um incidente cibernético com efeitos físicos deve ser encaminhado também ao processo competente, sem misturar os registros.

## Documentos e ordem de leitura

O conjunto revisado contém inequivocamente **oito arquivos**: **seis documentos funcionais**, **um manifesto de integridade** e **uma auditoria-fonte**. Os sete componentes originais do pacote P0 são os seis documentos funcionais e o manifesto. A auditoria-fonte sustenta o pacote, mas não é um de seus sete componentes.

1. `docs/cybersecurity/README.md` — documento funcional de objetivo, escopo, arquitetura e limites.
2. `docs/cybersecurity/BASELINE_P0.md` — documento funcional de estado real, riscos e saída da fase documental.
3. `docs/cybersecurity/CONTROL_MODEL.md` — documento funcional de macrocontroles e critérios proporcionais.
4. `docs/cybersecurity/EVIDENCE_AND_FINDINGS.md` — documento funcional de evidência e ciclo de achados.
5. `docs/cybersecurity/INCIDENT_REPORT_MODEL.md` — documento funcional com modelos de incidente.
6. `docs/cybersecurity/IMPLEMENTATION_ROADMAP.md` — documento funcional de evolução e aprovações humanas.
7. `docs/review/cybersecurity/2026-08-04/MANIFEST.md` — manifesto de integridade e sétimo componente do pacote P0.
8. `docs/review/cybersecurity/2026-08-04/AUDITORIA_CONSOLIDADA.md` — auditoria-fonte externa aos sete componentes.

`docs/review/cybersecurity/2026-08-04/REVISAO_P0.md` é o parecer técnico independente posterior. Ele não integra os sete componentes originais nem altera o total de oito arquivos revisados naquele parecer.

Documentos gerais relacionados: `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/ROADMAP.md`, `docs/STATUS.md` e `MEMORY.md`.
