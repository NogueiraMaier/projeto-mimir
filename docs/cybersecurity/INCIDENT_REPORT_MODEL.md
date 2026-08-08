# Modelo de relatório de incidente cibernético

## Regras de uso

Este modelo é exclusivo para incidentes cibernéticos. Não abrange SST nem acidentes de trabalho. Se houver dano físico ou evento ocupacional, abrir e vincular registro separado no processo competente.

O relatório deve ser atualizado sem apagar versões anteriores. Fatos, declarações, inferências e ausências de evidência devem ser identificados conforme `docs/cybersecurity/EVIDENCE_AND_FINDINGS.md`. Ações de contenção, erradicação, recuperação ou comunicação exigem autoridade compatível; o modelo não concede autorização operacional.

# Versão técnica

## 1. Identificação e controle

- ID do incidente:
- Cliente e escopo autorizado:
- Título:
- Estado: suspeito / confirmado / contido / erradicado / em recuperação / encerrado:
- Data, horário e fuso de abertura:
- Coordenador e substituto:
- Classificação do relatório, retenção e acesso:
- Versão, autor, aprovador e histórico de alterações:

## 2. Triagem e severidade

- Fonte da detecção e relato inicial:
- Evento observado:
- Critérios que confirmam ou descartam incidente:
- Severidade: crítica / alta / média / baixa:
- Justificativa da severidade:
- Urgência, prioridade e prazo de escalonamento:
- Hipóteses e lacunas ainda não verificadas:

## 3. Ativos, identidades e dados

- Ativos, serviços, contas e dependências afetados:
- Proprietários e criticidade:
- Ambientes e fronteiras atingidos:
- Dados envolvidos, volume aproximado e classificação:
- Dados pessoais ou dados pessoais sensíveis: sim / não / não verificado:
- Titulares e clientes potencialmente afetados:

## 4. Linha do tempo

Para cada evento registrar data, horário, fuso, fonte, ator, ação, resultado, confiança e evidência `EVD-*`. Diferenciar tempo do evento, tempo da detecção e tempo do registro. Manter eventos corrigidos com vínculo à versão anterior.

## 5. Indicadores e análise

- Indicadores técnicos e contexto, armazenados conforme classificação:
- Comportamentos, técnicas ou padrões observados sem atribuição especulativa:
- Sistemas consultados e limitações de visibilidade:
- Escopo confirmado, potencial e descartado:
- Evidências, hashes, coletor, método e cadeia de custódia:

## 6. Impacto e risco

- Confidencialidade, integridade, disponibilidade e autenticidade:
- Impacto operacional, financeiro, contratual, reputacional e legal:
- Impacto sobre dados pessoais e direitos dos titulares:
- Serviços essenciais interrompidos e duração:
- Probabilidade de propagação ou recorrência:

## 7. Contenção

- Objetivo e estratégia de curto e longo prazo:
- Ações propostas, autorização humana, executor, horário e resultado:
- Efeitos colaterais, preservação de evidências e plano de reversão:
- Critério para declarar contido:

## 8. Erradicação

- Artefatos, acessos, vulnerabilidades e persistências a remover:
- Ações autorizadas e validação:
- Dependências atualizadas ou reconstruídas:
- Critério para declarar erradicado:

## 9. Recuperação

- Ordem de restauração e responsáveis:
- Fonte confiável de backup/reconstrução:
- Verificações de integridade e segurança antes do retorno:
- Monitoramento reforçado, RPO/RTO observado e desvios:
- Aprovação humana para retorno e critério de normalização:

## 10. Comunicações

- Públicos internos, cliente, jurídico/privacidade, fornecedores, seguradora e autoridades:
- Mensagem, canal alternativo, responsável, aprovação, data e horário:
- Restrições de confidencialidade e consistência entre versões:
- Comunicações pendentes e prazo de decisão:

## 11. Avaliação LGPD

- Decisão de acionar o fluxo de dados pessoais e fundamento:
- Controlador, operadores e contato de privacidade:
- Natureza e categorias de dados e titulares:
- Medidas técnicas e administrativas existentes e posteriores:
- Riscos/danos relevantes aos titulares e método de avaliação:
- Decisão sobre comunicação à ANPD e aos titulares, autoridade que decidiu, fundamento, prazo e conteúdo:
- Registro de comunicação, complementação e medidas aos titulares:

Não presumir obrigação, dispensa ou prazo sem validação jurídica e consulta à regra oficial vigente na fase autorizada.

## 12. Autorizações

Registrar cada decisão crítica: ação, escopo, solicitante, aprovador, base de autoridade, data, horário, fuso, condições, validade e revogação. Aprovação genérica não autoriza expansão do escopo.

## 13. Causa raiz

- Método utilizado:
- Causa técnica, organizacional e de processo:
- Fatores contribuintes e controles que falharam ou faltaram:
- Evidências que sustentam a conclusão:
- Alternativas descartadas e limitações:

## 14. Lições aprendidas e ações

- O que funcionou e o que falhou:
- Achados `FND-*` abertos:
- Ação, responsável, prazo, prioridade e evidência esperada:
- Atualizações necessárias em controles, riscos, treinamento e documentação:

## 15. Encerramento

- Critérios técnicos e de negócio cumpridos:
- Evidências finais e risco residual:
- Pendências transferidas e responsáveis:
- Aprovação do cliente/proprietário, segurança e privacidade quando aplicável:
- Data, horário e fuso do encerramento:
- Data da revisão posterior:

# Fluxo separado: incidente com dados pessoais

1. **Sinalização imediata:** marcar “dados pessoais: sim ou não verificado”, restringir acesso e acionar o responsável de privacidade sem aguardar conclusão técnica.
2. **Preservação e minimização:** preservar evidências necessárias sem replicar dados pessoais indiscriminadamente; mascarar relatórios de trabalho.
3. **Qualificação:** confirmar controlador, operadores, titulares, categorias, volume, contexto, proteção aplicada e alcance provável.
4. **Avaliação de risco/dano:** documentar método, gravidade, probabilidade, reversibilidade e grupos vulneráveis, com revisão jurídica/privacidade.
5. **Decisão formal:** autoridade competente decide, com base na norma vigente, sobre ANPD, titulares, clientes e outras partes; registrar fundamento e prazos.
6. **Comunicação controlada:** conteúdo claro, consistente, aprovado e rastreável; complementações preservam a versão anterior.
7. **Direitos e mitigação:** definir canal, orientação e medidas de redução de dano aos titulares.
8. **Encerramento próprio:** privacidade aprova o fechamento dessa trilha mesmo que a recuperação técnica já tenha terminado.

# Versão executiva

## Resumo para decisão

- ID, cliente, data e estado:
- O que aconteceu, em linguagem não técnica:
- O que está confirmado, inferido e não verificado:
- Ativos, operações e dados afetados:
- Impacto atual e pior cenário plausível:
- Severidade e tendência:
- Contenção, erradicação e recuperação realizadas/autorizadas:
- Dados pessoais envolvidos e situação da decisão LGPD:
- Comunicações feitas e pendentes:
- Decisões e recursos humanos/financeiros requeridos:
- Risco residual, próximos marcos e responsável:
- Critérios e aprovação de encerramento:

A versão executiva referencia o relatório técnico; não remove incertezas, não expõe indicadores sensíveis e não substitui registros de evidência ou autorizações.
