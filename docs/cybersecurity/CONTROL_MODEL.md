# Modelo de controles de Cybersecurity

## Uso e ressalvas

O modelo organiza 20 macrocontroles proporcionais a pequenas empresas. As funções **Govern, Identify, Protect, Detect, Respond e Recover** seguem a organização de alto nível do NIST CSF 2.0. As relações com CIS Controls v8.1 IG1 e LGPD são apenas temáticas.

Todos os mapeamentos desta versão são **preliminares**: o repositório não contém matriz oficial validada. Não se atribuem números de salvaguardas CIS, categorias/subcategorias NIST ou artigos/requisitos específicos da LGPD. Atendimento a um macrocontrole não implica conformidade com qualquer referencial.

## Regras de avaliação proporcional

A avaliação mantém quatro eixos independentes, definidos de forma canônica em `EVIDENCE_AND_FINDINGS.md`: natureza da informação; estado técnico; estado do achado; e resultado do controle. **Confirmado** expressa validação ou confiança na constatação e não representa estado técnico nem resultado de controle.

O resultado do controle usa exclusivamente:

- **Atendido:** evidência mínima íntegra, atual, aplicável ao escopo e aprovada pela função competente; critério proporcional cumprido.
- **Parcialmente atendido:** parte do critério foi cumprida, mas há lacuna de cobertura, governança, validação ou evidência.
- **Não atendido:** o critério proporcional não foi cumprido.
- **Não verificado:** não foi possível avaliar o controle com evidência autorizada suficiente.
- **Não aplicável com justificativa:** o controle está comprovadamente fora do escopo; exige fundamento, aprovador competente e validade e nunca substitui ausência de evidência.

A proporcionalidade admite documentos e rotinas simples, acumulação consciente de papéis e ferramentas de baixo custo, desde que conflitos, risco e aprovação sejam registrados. Não admite ignorar ativos críticos, dados pessoais, incidentes relevantes ou obrigações aplicáveis.

## Registro obrigatório de avaliação

Cada avaliação de macrocontrole deve registrar: proprietário do controle; responsável pela implementação; aprovador competente; revisor; data da avaliação; escopo; validade; evidência vinculada; resultado do controle; limitações; e justificativa quando não aplicável.

A aprovação é definida por função, conforme o tema e a autoridade formal: proprietário do processo ou sistema para escopo e risco de negócio; segurança para controles técnicos; privacidade/LGPD para tratamento de dados pessoais; e especialista técnico responsável quando a decisão exigir competência específica. O nome da pessoa que exerce a função e sua autoridade devem constar no registro.

Em pequenas empresas, uma pessoa pode acumular funções somente quando a acumulação estiver documentada. Se houver conflito de interesses — especialmente autoaprovação da própria implementação — deve existir medida compensatória registrada, como revisão independente, aprovação externa competente ou segunda validação proporcional. Sem aprovador competente e compensação necessária, o resultado não pode ser classificado como atendido.

## Matriz dos 20 macrocontroles

| ID | Macrocontrole | Funções NIST CSF 2.0 aplicáveis | Relação temática CIS IG1 | Relação temática LGPD | Evidência mínima | Critério proporcional de atendimento |
|---|---|---|---|---|---|---|
| MC-01 | Contexto e responsáveis | Govern | Governança, papéis e responsabilidades | Agentes de tratamento, prestação de contas e canal | Escopo aprovado, proprietário, suplente e matriz simples de responsabilidades | Componentes, decisões críticas e contatos têm responsáveis e autoridade aprovados |
| MC-02 | Requisitos legais e LGPD | Govern, Identify | Governança de dados e obrigações aplicáveis | Finalidade, base legal, direitos, registros e segurança | Inventário de tratamentos e decisão jurídica/administrativa registrada | Cada tratamento no escopo tem finalidade, base, dados, titular, retenção, acesso e canal definidos |
| MC-03 | Inventário de ativos | Identify | Inventário e controle de ativos empresariais | Localização e responsabilidade sobre dados pessoais | Lista datada de ativos com dono, criticidade, localização e estado | Todos os ativos críticos e os que tratam dados pessoais estão cadastrados e revisados |
| MC-04 | Inventário de software | Identify, Protect | Inventário e controle de software | Segurança dos sistemas usados no tratamento | Lista de software, versão, origem, suporte e responsável | Software autorizado e crítico é conhecido; exceções e fim de suporte têm tratamento |
| MC-05 | Classificação e retenção de dados | Govern, Identify, Protect | Proteção e ciclo de vida de dados | Minimização, necessidade, retenção e descarte | Política simples e inventário por repositório/tabela/log | Cada conjunto relevante tem classificação, acesso, prazo, evento inicial e destino final |
| MC-06 | Riscos | Govern, Identify | Priorização baseada em risco | Avaliação de riscos e responsabilização | Registro com probabilidade, impacto, dono, tratamento e residual | Riscos altos têm prazo e aprovação; aceites são explícitos e revisáveis |
| MC-07 | Configuração segura | Protect | Configuração segura de ativos e software | Medidas técnicas e administrativas de segurança | Baseline versionada, resultado datado e exceções | Configurações críticas têm valor esperado, verificação e aprovação de desvios |
| MC-08 | Contas e credenciais | Govern, Protect | Gestão de contas | Controle de acesso e prevenção de acesso não autorizado | Inventário de contas, finalidade, dono, privilégio e revisão | Contas são individuais quando cabível, mínimas, revogáveis e periodicamente revistas |
| MC-09 | Acessos e MFA | Protect | Gestão de acesso | Acesso necessário e seguro aos dados | Matriz de acesso e evidência de autenticação/recertificação | Administração usa MFA quando suportado ou compensação aprovada; acessos são registrados |
| MC-10 | Vulnerabilidades e atualizações | Identify, Protect, Detect | Gestão contínua de vulnerabilidades | Segurança e prevenção | Política, fonte de avisos, achados, SLA e exceções | Ativos críticos são avaliados com método autorizado; correções seguem prazo por risco |
| MC-11 | Logs | Protect, Detect, Respond | Gestão de logs de auditoria | Registro seguro, minimização e retenção | Catálogo de eventos, fonte, tempo, acesso, retenção e teste de recuperação | Eventos críticos são íntegros, acessíveis aos autorizados, retidos e revisados |
| MC-12 | E-mail e web | Protect, Detect | Proteções de e-mail, navegador e rede | Segurança em comunicações e compartilhamentos | Inventário de canais, filtros, destinos permitidos e incidentes | Canais usados têm proteção mínima, destino conhecido e procedimento contra fraude/phishing |
| MC-13 | Proteção de endpoints | Protect, Detect | Defesas contra malware e proteção de dispositivos | Segurança dos dispositivos que tratam dados | Inventário, baseline, proteção, criptografia quando aplicável e estado | Endpoints críticos têm configuração aprovada, atualização e resposta a alertas |
| MC-14 | Backup e continuidade | Govern, Protect, Recover | Recuperação de dados | Disponibilidade, integridade e continuidade do tratamento | Escopo, RPO/RTO, cópias, retenção e relatório de restauração | Dados críticos têm cópia protegida e restauração periodicamente demonstrada |
| MC-15 | Infraestrutura de rede | Identify, Protect, Detect | Gestão e defesa da infraestrutura de rede | Segurança dos fluxos de dados | Diagrama e matriz origem/destino/porta/protocolo/justificativa | Fluxos críticos são mínimos, autorizados, segmentados quando necessário e revisados |
| MC-16 | Monitoramento | Detect, Respond | Monitoramento e defesa | Detecção e resposta a eventos que afetem dados | Eventos prioritários, alertas, responsável, prazo e teste | Cenários críticos geram alerta verificável com escalonamento compatível com o porte |
| MC-17 | Treinamento | Govern, Protect | Conscientização e capacitação | Boas práticas e responsabilidades no tratamento | Conteúdo, público, data, presença e reciclagem | Pessoas com acesso recebem orientação inicial e periódica conforme seu risco |
| MC-18 | Terceiros | Govern, Identify, Protect | Gestão de prestadores e serviços | Operadores, compartilhamentos, contratos e transferências | Cadastro, dados envolvidos, avaliação, contrato e saída | Terceiro crítico é aprovado antes do uso e tem obrigações de segurança e encerramento |
| MC-19 | Resposta a incidentes | Govern, Detect, Respond | Gestão de resposta a incidentes | Incidente com dados pessoais e comunicações | Plano, contatos, severidade, registros, evidências e exercício | Incidentes têm triagem, autoridade, contenção e comunicação; dados pessoais seguem fluxo próprio |
| MC-20 | Recuperação com melhoria | Govern, Respond, Recover | Recuperação e aprendizado | Mitigação, prestação de contas e prevenção de recorrência | Plano de recuperação, causa raiz, ações, responsáveis e validação | Serviço retorna com integridade verificada e ações pós-incidente são acompanhadas até fechar |

## Validação futura dos mapeamentos

Na P1, pessoa competente deve comparar esta matriz com as publicações oficiais vigentes, registrar versão, data, fonte e decisão, e substituir a marca **preliminar** somente onde o cruzamento estiver demonstrado. Divergências devem permanecer visíveis e versionadas; nenhum identificador normativo deve ser preenchido por aproximação.
