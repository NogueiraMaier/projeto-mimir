# Evidências e achados de Cybersecurity

## Princípios

Evidências devem ser necessárias, autorizadas, minimizadas, íntegras, rastreáveis e acessíveis somente a quem precisa. O repositório documental deve guardar referências e artefatos sanitizados; segredos, transcrições, dados pessoais desnecessários e dados privados de clientes não devem ser versionados.

## Natureza da informação

- **Evidência:** artefato ou observação reproduzível, com origem, contexto e integridade verificáveis.
- **Declaração:** afirmação de pessoa ou documento sem comprovação independente suficiente; deve identificar autor e data.
- **Inferência:** conclusão analítica derivada de evidências ou declarações; deve expor premissas, grau de confiança e revisor.
- **Ausência de evidência:** material esperado não foi localizado no escopo pesquisado; não prova, isoladamente, que a capacidade inexista fora dele.

**Confirmado** não é uma quinta natureza nem um estado técnico. O termo representa validação ou nível de confiança na constatação, sempre acompanhado do eixo a que a constatação se refere. Uma ausência de evidência pode estar confirmada para o escopo pesquisado sem provar que a capacidade não exista fora dele.

## Quatro eixos independentes

| Eixo | Valores permitidos | Regra |
|---|---|---|
| Natureza da informação | Evidência; declaração; inferência; ausência de evidência | Classifica a base probatória, não a condição técnica. |
| Estado técnico | Implementado; parcialmente implementado; não implementado; não verificado; não aplicável com justificativa | Classifica a capacidade no escopo e na data; não aplicável exige fundamento e aprovação. |
| Estado do achado | Aberto; em tratamento; mitigado; risco aceito; encerrado | Classifica o ciclo do achado; risco aceito requer decisão humana válida e pode coexistir com estado técnico não implementado. |
| Resultado do controle | Atendido; parcialmente atendido; não atendido; não verificado; não aplicável com justificativa | Classifica o cumprimento do critério do controle, sem declarar conformidade normativa. |

Os quatro eixos devem ser registrados separadamente. Nenhum valor de um eixo determina automaticamente valor em outro.

## Registro mínimo de evidência

Cada evidência recebe identificador imutável no formato documental `EVD-AAAA-NNNN` e os campos:

| Campo | Conteúdo obrigatório |
|---|---|
| Identificador | Código único e versão do registro |
| Cliente | Organização a que a evidência pertence; nunca inferir cliente pelo caminho |
| Escopo | Limites organizacionais, técnicos, temporais e autorização associada |
| Ativo | Identificador do ativo, sistema, dado ou processo observado |
| Origem | Sistema, arquivo, pessoa ou processo que produziu o material |
| Coletor | Pessoa ou mecanismo autorizado que realizou a coleta |
| Data | Data civil da coleta em `AAAA-MM-DD` |
| Horário | Horário com segundos quando disponível |
| Fuso | Deslocamento UTC e, se conhecido, nome do fuso, por exemplo `America/Bahia` |
| Hash | Algoritmo e valor; preferencialmente SHA-256 para arquivo estável |
| Método | Procedimento de aquisição, comandos somente leitura quando autorizados e transformações |
| Classificação | `public`, `internal`, `confidential` ou `restricted`, conforme política aprovada |
| Retenção | Prazo, evento inicial, fundamento, destino e exceção de preservação |
| Controle de acesso | Proprietário, pessoas/papéis autorizados e local protegido |
| Mascaramento | Dados removidos, pseudonimizados ou agregados; método e responsável |
| Validação | Quem conferiu integridade, completude, contexto e data da validação |

Campos adicionais recomendados: tamanho, formato, cadeia de custódia, ferramenta/versão, relógio de referência, relação com controle/achado/incidente e limitações. Se o conteúdo mudar legitimamente, criar nova versão e novo hash; não sobrescrever silenciosamente.

## Coleta, preservação e validação

1. Confirmar cliente, escopo, necessidade e autorização antes da coleta.
2. Preferir a fonte original e método somente leitura; registrar qualquer transformação.
3. Minimizar dados pessoais e segredos antes de armazenamento ou compartilhamento.
4. Calcular hash do artefato estável e registrar data, horário e fuso.
5. Armazenar conforme classificação, acesso e retenção; o hash não torna um local inseguro adequado.
6. Validar se a evidência sustenta exatamente a afirmação associada.
7. Registrar transferências de custódia. Sem histórico completo e armazenamento protegido, declarar a cadeia como incompleta.

## Registro de achado

Cada achado usa identificador `FND-AAAA-NNNN` e inclui:

- cliente, escopo, ativos e controles afetados;
- título e descrição factual;
- natureza das fontes: evidência, declaração, inferência ou ausência de evidência;
- referências `EVD-*` e limitações;
- estado técnico: implementado, parcialmente implementado, não implementado, não verificado ou não aplicável com justificativa;
- estado do achado: aberto, em tratamento, mitigado, risco aceito ou encerrado;
- resultado do controle relacionado, quando avaliado: atendido, parcialmente atendido, não atendido, não verificado ou não aplicável com justificativa;
- criticidade e justificativa;
- risco: cenário, ameaça/causa, vulnerabilidade, consequência, probabilidade e impacto;
- responsável pelo tratamento e autoridade de aceite;
- prazo e marcos;
- tratamento escolhido: mitigar, evitar, transferir ou aceitar;
- ações executadas separadas de ações futuras;
- risco residual e aprovador;
- evidência de encerramento e validação independente/proporcional.

## Estados do achado

| Estado | Definição | Entrada/saída mínima |
|---|---|---|
| Aberto | Validado como achado | Risco, criticidade, responsável e prazo atribuídos |
| Em tratamento | Ação aprovada está em curso | Plano, marcos e evidências parciais |
| Mitigado | Tratamento reduziu o risco e aguarda decisão final ou monitoramento | Evidência do tratamento e risco residual avaliados |
| Risco aceito | Risco residual aceito formalmente por autoridade humana competente | Justificativa, escopo, prazo de validade e aprovador |
| Encerrado | Critério de encerramento cumprido e validado | Evidência final, risco residual e aprovação competente |

Estados não devem ocultar a condição técnica. Por exemplo, um achado em **risco aceito** pode continuar tecnicamente **não implementado**; **encerrado** exige que o tratamento definido, inclusive aceite válido quando aplicável, tenha evidência. Registros ainda em qualificação ou aguardando validação são condições de fluxo, não valores adicionais do eixo estado do achado.

## Criticidade e risco

Criticidade do achado não é sinônimo de classificação do dado. Usar escala simples:

- **Crítica:** consequência catastrófica ou exposição imediata que exige decisão emergencial.
- **Alta:** impacto grave ou probabilidade relevante sobre ativo/processo crítico; tratamento prioritário.
- **Média:** impacto material controlável, sem urgência de crise.
- **Baixa:** impacto limitado; pode entrar em melhoria planejada.
- **Informativa:** observação sem risco material demonstrado, útil para governança.

A escala deve considerar contexto do cliente, dados pessoais, dependências, controles existentes e capacidade da pequena empresa. A nota não pode ser reduzida apenas por falta de evidência. Risco residual é reavaliado depois do tratamento e exige aceite humano quando acima do limite aprovado.

## Encerramento

Um achado só encerra quando o critério de aceitação foi testado por método autorizado, a evidência foi validada, o risco residual foi registrado e a autoridade competente aprovou. Documento criado, promessa, captura isolada ou declaração do executor não comprovam, sozinhos, eficácia operacional.
