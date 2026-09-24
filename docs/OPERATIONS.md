# Operações controladas do Mímir

Revisão local: 2026-09-22. **IMPLEMENTADO no repositório; NÃO VALIDADO EM PRODUÇÃO.**
Esta camada estende a fundação `eb2e166`; não recria o projeto, não altera as
migrations 002–008 e não concede ferramentas de execução ao agente OpenClaw.

## Escopo e estados

| Capacidade | Estado e limite |
|---|---|
| CMDB, API PostgreSQL e CLI | IMPLEMENTADO; validação Python e transporte PostgreSQL testados com mocks. SQL não aplicado nesta revisão. |
| READ / PLAN / EXECUTE | IMPLEMENTADO por catálogo explícito de operações e parâmetros. |
| SSH | IMPLEMENTADO e testado sem rede, com transporte simulado. |
| generic-linux | Diagnóstico e `set-hostname` do hostname **em execução**, sem persistência após reboot. Comando `/bin/hostname`; disponibilidade e privilégio precisam ser validados em laboratório. |
| mikrotik-routeros | Inventário/diagnóstico. EXECUTE e export de configuração bloqueados. Compatibilidade por versão: NÃO VALIDADO EM PRODUÇÃO. |
| Snapshot e backup de hostname | IMPLEMENTADO: coleta anterior e cópia do valor necessário para recuperação manual; não é backup completo do Linux. |
| Rollback | PARCIAL: somente procedimento manual, nunca executado automaticamente. |
| Extração automática da topologia | PARCIAL: coleta evidências sanitizadas; interfaces/IPs/VLANs normalizados são cadastrados pelo operador. Não infere firmware ou topologia. |
| Memória permanente | PARCIAL: contrato `memory_handoff` v1 para revisão humana; nenhuma chamada a funções de memória ou promoção automática. |
| Novos fabricantes, backup completo, rollback automático | PLANEJADO; sem comandos FiberHome/H3C/Intelbras. |

## Inventário / CMDB

A migration operacional **013** exige a versão 12 e foi renumerada após a
recuperação das migrations de memória 009–012. Ela recusa reaplicação quando
a versão 13 já existe, para impedir
sobreposição silenciosa de um schema diferente. A role é tratada separadamente.

Entidades: clientes; sites; equipamentos; interfaces (MAC, MTU, função e VLAN);
endereços IPv4/IPv6; sub-redes CIDR; VLANs; métodos SSH e referências de credencial;
dependências entre equipamentos do mesmo cliente, inclusive em sites diferentes.
Chaves estrangeiras compostas impedem IP/interface, rede/VLAN e equipamento/site
incoerentes. IP associado a sub-rede deve pertencer a ela. Há identificação de
fabricante/modelo/firmware/função, verificação, coleta e alteração mais recentes.

`ops_accesses` é a fonte canônica de conexão. Cada equipamento exige
`primary_access_id` apontando para um acesso SSH; host, porta, usuário e referência
de credencial são derivados desse acesso. Os campos equivalentes do documento de
equipamento são apenas uma projeção de leitura e, quando presentes na entrada,
precisam coincidir exatamente.

O cadastro nasce `unverified`. Coleta concluída registra `verified` com escopo
`diagnostic_observation`: isso confirma a observação registrada, não toda a CMDB,
segurança do equipamento ou atualidade indefinida. Os dados declarados pelo
operador e as observações coletadas permanecem distintos. Atualizações de
observações preservam antes/depois em `ops_audit`. Não há edição ou exclusão
arbitrária pelo CLI neste MVP; correções cadastrais exigem procedimento
administrativo revisado, preservando auditoria.

JSON de entrada aceita apenas campos conhecidos. Nunca colocar senhas, tokens,
chaves privadas ou conteúdo de configuração nos campos livres. Referências
permitidas: `ssh-agent` e `file-ref:IDENTIFICADOR`; `file-ref` é resolvida por um
arquivo de mapeamento externo ao Git. Apenas método `ssh` é executável.

Exemplos sintéticos completos estão em `tools/ops/examples/`. Os arquivos reais
de clientes devem ficar em diretório protegido fora do repositório.

Após provisionamento autorizado do banco, sob a identidade operacional:

```bash
python3 tools/ops/mimir-ops.py inventory client add --file /diretorio-protegido/client.json
python3 tools/ops/mimir-ops.py inventory client list
python3 tools/ops/mimir-ops.py inventory client show CLIENT_UUID
python3 tools/ops/mimir-ops.py inventory site add --file /diretorio-protegido/site.json
python3 tools/ops/mimir-ops.py inventory site list
python3 tools/ops/mimir-ops.py inventory site show SITE_UUID
python3 tools/ops/mimir-ops.py inventory device add --file /diretorio-protegido/device.json
python3 tools/ops/mimir-ops.py inventory device list --offset 0
python3 tools/ops/mimir-ops.py inventory device show DEVICE_UUID
```

Listagens têm páginas de 100 registros e offset explícito. A listagem de
equipamentos omite evidências volumosas; `show` retorna detalhes. A identidade
operacional é administrativa para os clientes cadastrados; não é uma API
multiusuário com isolamento por cliente. Acesso de clientes externos: PLANEJADO.

## PostgreSQL e privilégios

O cliente usa `psql -X -w`, socket `/run/postgresql`, porta 5432, banco
`mimir_memory`, role dedicada **mimir_ops**, ambiente mínimo, sem senha/DSN,
sem arquivos de serviço, timeouts de conexão/statement/lock e limite de saída.
O payload é codificado em base64 e enviado pelo stdin, nunca interpolado como SQL
livre ou colocado nos argumentos do processo. Consultas usam `BEGIN READ ONLY`.

`mimir_ops` recebe apenas CONNECT, USAGE no schema e EXECUTE em
`mimir.ops_api(jsonb)`. Não recebe SELECT/INSERT/UPDATE/DELETE nas tabelas, acesso
às sequências, role de owner nem permissões na memória. As funções usam nomes
qualificados, `search_path` fixo e checam `session_user` e `system_user`.
`mimir_app` não recebe os grants operacionais amplos de uma revisão anterior da migration operacional.

A identidade esperada é `peer:mimir-ops`, **desabilitada por padrão** em
`ops_identities`. A instalação futura requer revisão humana de:

1. schema real e migrations anteriores, incluindo a ausência da 001 no Git;
2. backup/restauração do banco e teste da 013 em ambiente descartável;
3. conta Linux dedicada, regras existentes de `pg_hba.conf`/`pg_ident.conf` e
   mapeamento peer local; preservar as regras de memória existentes;
4. grants efetivos, defaults e identidade retornada pelo PostgreSQL 17;
5. habilitação explícita da identidade somente depois dessas verificações.

O schema é instalado por `013_operational_inventory.sql`; criação da role,
CONNECT e grants específicos ficam separados em `013_operational_role.sql`.
A aplicação das migrations e essas configurações **não foram realizadas**.
O provisionamento não é feito pelo CLI ou pelo validador. Não executar a 013
cegamente: um `schema_version=13` não comprova qual revisão da 013 foi aplicada.

## Política e aprovação

`ops adapters` publica capacidades READ, PLAN, EXECUTE, snapshot, backup,
validação, rollback e proibições de cada adapter. Não existe classificação de
segurança por prefixo. Apenas comandos exatos do catálogo podem ser enviados.
Parâmetros adicionais, shell metacharacters, opções injetadas e operações
arbitrárias são rejeitados.

- **READ**: padrão; somente operações diagnósticas. Respeita equipamento limitado a PLAN.
- **PLAN**: gera plano e SHA-256, sem SSH nem escrita no banco.
- **EXECUTE**: exige equipamento cadastrado com `permission_mode=EXECUTE`, operação
  suportada, `--approve SHA256` igual ao plano e `--approval-ref` explícita.
  O hash vincula equipamento, acesso, adapter, operação, parâmetros, objetivo e
  capacidades. Alterar qualquer um desses itens invalida a aprovação.

A aprovação é a confirmação do operador autenticado no host; não é assinatura
criptográfica nem prova independente de dupla aprovação. Referência e usuário
local são registrados, junto da identidade peer no banco. Não expor este CLI
como shell do agente main. O banco revalida o dispositivo na abertura da
intervenção e recusa plano com inventário de acesso divergente.

```bash
# Local, sem rede ou banco:
python3 tools/ops/mimir-ops.py plan tools/ops/examples/device-mikrotik.json
python3 tools/ops/mimir-ops.py ops adapters

# Após instalação e autorização específicas; plan consulta apenas o inventário:
python3 tools/ops/mimir-ops.py ops plan DEVICE_UUID --operation set-hostname --hostname lab-new --objective 'Ajustar hostname em execução'
# Repetir exatamente objetivo/operação/parâmetros do plano revisado:
python3 tools/ops/mimir-ops.py ops execute DEVICE_UUID --operation set-hostname --hostname lab-new --objective 'Ajustar hostname em execução' --approve PLAN_SHA256 --approval-ref CHANGE_ID --dry-run
```

Retirar `--dry-run` é a ação real e exige autorização específica do equipamento.
**Nenhum desses comandos de acesso real foi executado nesta revisão.** Dry-run
com UUID faz somente a leitura do inventário; para simulação totalmente offline,
usar JSON sintético. Dry-run não inicia intervenção, não escreve arquivos,
não coleta snapshot/backup e nunca retorna status de sucesso executado.

Verbos originais `inspect`, `plan` e `execute` continuam como aliases. JSON local
permanece disponível para planos e diagnóstico legado, com diário e relatórios
locais; EXECUTE real exige PostgreSQL. Comando arbitrário com `--approve` booleano
foi substituído deliberadamente por operação nomeada e aprovação de plano.

## SSH e dados sensíveis

SSH usa `-F /dev/null`, `BatchMode=yes`, `StrictHostKeyChecking=yes`, known_hosts
explícito, `UpdateHostKeys=no`, nenhuma autenticação por senha, nenhum forward,
proxy, multiplexação ou comando local. `--` precede o destino. Não usa
`shell=True`; a string remota provém apenas do catálogo/validação do adapter.

`--known-hosts` deve indicar arquivo confiável, existente, sem symlinks, pertencente
a root/operador e sem escrita de grupo/outros. Provisionar host keys por canal
independente; o CLI nunca aceita uma host key nova automaticamente.
`--key-map` resolve `file-ref:ID` para caminho absoluto de chave externa; a chave
não é lida pelo Python, nem copiada, registrada ou incluída em relatório. Ela
precisa de permissões privadas. Para SSH Agent, apenas `SSH_AUTH_SOCK` é herdada.

Timeout padrão 30 s (máximo 120 s); limite combinado de stdout/stderr de 16 KiB
por comando. Captura é limitada durante a leitura, não após buffer ilimitado.
Timeout/estouro encerram o grupo de processos e descartam saídas incompletas.
Falhas remotas preservam exit code e saídas sanitizadas; falhas locais usam
códigos genéricos, sem propagar detalhes de drivers.

Redaction recursiva ocorre antes de auditoria, evidência e relatório, incluindo
campos livres, Authorization/Bearer, cookies, assignments, URLs com credenciais,
chaves identificáveis e blocos PEM. Uma string suspeita é descartada inteira.
Regex não reconhece todo segredo sem marcação: manter coleta restrita e nunca
usar exports, scripts livres ou backups completos nesta interface. Dados de
inventário e relatórios são confidenciais mesmo após sanitização.

## Intervenção, falhas e recuperação

Fluxo de alteração:

```text
PRECHECK -> SNAPSHOT -> BACKUP (quando suportado) -> EXECUTE -> VALIDATE -> REPORT
```

O diário persiste intenção e resultado de cada ação antes de seguir. Qualquer
falha de preparação impede a alteração. O backup Linux guarda o hostname
anterior; inconsistência entre precheck e backup também bloqueia EXECUTE.
Validação compara uma nova leitura com o hostname solicitado, além do exit code.

A finalização transacional grava relatório JSON/Markdown, evidências/hash,
validação, histórico e observação do inventário. O banco impede `validated`
sem validação final e inventário atualizado. Uma falha após tentativa de
alteração torna a observação do dispositivo não verificada. Nenhum rollback é
inventado: `rollback.mode=manual`, `performed=false` e, quando necessário,
`required=true`.

Resultados: `planned`, `simulated`, `running`, `collected`, `validated`, `failed`.
`collected`/`validated` não significam integração concluída na memória permanente;
`closed` permanece false. Os seis requisitos de encerramento ficam explícitos:
estado encontrado, ações, validação, inventário atualizado, histórico e relatório.
`closure_ready` sinaliza que esses requisitos operacionais foram satisfeitos;
não promove memória nem autoriza encerramento humano automático.

Se houver interrupção, falha ao gravar resultado ou perda da confirmação da
transação final, **não repetir EXECUTE**. Consultar histórico e relatório pelo
UUID mostrado; o banco pode ter confirmado a transação antes da perda de conexão.
Uma intervenção ainda `running` bloqueia outra execução no mesmo dispositivo.
Consultar o estado por procedimento humano autorizado e reconciliar a intervenção
com evidência preservada. Reabertura/cancelamento automático: PLANEJADO.
A auditoria não torna operações SSH e PostgreSQL uma única transação distribuída.

Recuperação manual de hostname: obter o valor anterior na evidência de BACKUP,
validar seu conteúdo e escopo, aprovar um procedimento de restauração e confirmar
o estado por releitura. Não executar automaticamente textos extraídos de logs.

```bash
python3 tools/ops/mimir-ops.py ops history DEVICE_UUID
python3 tools/ops/mimir-ops.py ops report INTERVENTION_UUID
python3 tools/ops/mimir-ops.py ops report INTERVENTION_UUID --format markdown
```

Relatórios locais usam diretório 0700 e arquivos 0600, criação exclusiva e
recusa de symlinks/sobrescrita. O padrão `reports/ops/` é ignorado pelo Git.
Falha de exportação local não elimina o relatório persistido no PostgreSQL.
Hashes conferem bytes sanitizados, não conteúdo bruto removido pela redaction.
Histórico/auditoria não têm API de alteração/exclusão. A política v1 está
definida em [OPERATIONS_RETENTION.md](OPERATIONS_RETENTION.md): registros
operacionais persistidos não expiram automaticamente, purge automático é
proibido e failed/interrupted devem ser preservados. Laboratórios totalmente
sintéticos podem ser removidos depois que as evidências exigidas forem
versionadas e os checkpoints de recuperação forem concluídos.

## Integração com memória — PARCIAL

`ops_workflow.memory_handoff()` emite contrato v1 com cliente/site/dispositivo,
projeto, origem `ops:UUID`, data, tipo evidence, classificação confidential,
nível de confiança descritivo, estado encontrado, alterações e validação.
`deduplication_key=intervention_id` é estável. O consumidor futuro deve revisar
segredos, duplicidade, contradições, autorização e versões anteriores.
Não enviar esse material ao consolidador externo. Não há escrita em
`memory_records`, `memory_events` ou `session_sources`, nem uso da função de
revisão humana. A promoção permanente continua no fluxo humano existente.

## Validação local e futura

```bash
python3 -B -m unittest discover -s tools/memory -p 'test_*.py' -v
python3 -B -m unittest discover -s tools/ops -p 'test_*.py' -v
python3 -B -m unittest discover -s tools/validation -p 'test_*.py' -v
node tools/memory/mimir-evidence-shadow-evaluate.mjs --self-test-classifier
npm test --prefix plugins/mimir-memory
npm run build --prefix plugins/mimir-memory
bash -n tools/validation/validate-vps-readonly.sh
```

O plugin usa dependências instaladas localmente ou em `/opt/openclaw`, sem baixar
pacotes pelos scripts de teste/build. Testes operacionais usam dublês de SSH e
PostgreSQL; testes de subprocesso usam somente Python local e dados sintéticos.

Posteriormente, **no VPS**, a primeira ação deve ser somente leitura:

```bash
cd /var/lib/openclaw/workspace
bash tools/validation/validate-vps-readonly.sh --db-user mimir_app
```

Executar sob identidade com mapeamento peer já autorizado. Falta de permissão
para ler `schema_version` é resultado inconclusivo/falha, não motivo para ampliar
grants automaticamente. `--skip-db` permite inspeção sem qualquer conexão ao banco.
O script verifica Gentoo/OpenRC, presença/versão de OpenClaw, plugin versionado e
artefato compilado, PostgreSQL/pgvector/mimir_memory/schema_version, Git,
Python/Node, sintaxe e self-tests puros. Não inicia runtime, não executa scripts
de serviço, não imprime configuração, SQL errors, nomes de arquivos Git ou
segredos. Presença do plugin não comprova carregamento no gateway.

Aplicação da 013, peer, backup/restauração, integração SQL real e laboratório SSH
continuam dependentes de autorização e validação posteriores. Não usar o
resultado dos mocks como evidência de implantação ou de compatibilidade real.
