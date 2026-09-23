# Recuperação das migrations de memória 009–012

Data: 2026-09-23. Projeto: Mimir. Origem: fontes recuperadas fornecidas pelo
operador e inspeção local do Git. Registro factual de recuperação, sem aplicação.

## Evidência e conclusão

Antes desta recuperação, o Git versionado continha somente as migrations de
memória 002–008; a 001 continua ausente. Havia também uma migration operacional
conflitante numerada 009, distinta da migration 009 real da memória.
O PostgreSQL real tinha `schema_version` 1–12, conforme histórico confirmado
pelo operador nesta tarefa; não houve consulta ao banco durante a recuperação.

A 009 foi recuperada de histórico operacional de shell. As 010–012 foram
recuperadas dos scripts originais de aplicação. Os oito arquivos autoritativos
estão em `/home/jarvisdev/mimir-migrations-recovery`; foram lidos e tiveram seus
SHA-256 conferidos, sem modificação ou execução.

No `git log --all --full-history` examinado, com nomes/status dos caminhos de
migrations e dos arquivos contendo 009–012, não há evidência de que as migrations
de memória 009–012 tenham sido previamente commitadas e depois removidas.
As ocorrências de 009 são da migration operacional. A conclusão suportada é uma
lacuna de consolidação/versionamento entre implantação e Git. A evidência não
estabelece motivo humano nem causa adicional.

Precondições locais confirmadas: branch `feat/mimir-operational-foundation`,
HEAD `8e8d2fd0783988ec0e2ac2dd7c91b456e4e6f8ac` e worktree inicialmente limpa.
A migration operacional conflitante foi deslocada para **013**, com requisito
012, recusa de versão 13 existente e registro 13; seu provisionamento de role
continua separado. Os arquivos de memória 002–008 foram preservados.

## Fontes e SHA-256

| Fonte | SHA-256 |
|---|---|
| `mimir_migration_009_apply.sh` | `45b406f7814b731b200d039989df69cc00f5e046a5127389e0a51c9c5dcee999` |
| `mimir_migration_009_dry_run.sh` | `d7d66a0ad5c108b5fba8feb3089b61aca7e6d6c1e1aaae9ee858f4aeebbb9e72` |
| `mimir_migration_010_apply.sh` | `eef569843856444cfa156c7bd245f4b306f523093b77960c7cd0009b1fa9da60` |
| `mimir_migration_010_dry_run.sh` | `4a2583e97ba2adb1f5ca1f44729e55d2c9d5baab245a639ae11bffdde2705eb1` |
| `mimir_migration_011_apply.sh` | `fe058c3977b6475a28d77eec007d231ece309c026dcad32787844017850fc3a2` |
| `mimir_migration_011_dry_run.sh` | `19683b3aa27c2dbf73d7e6063108df0c857c7a5e163cdaf2046ccf02f721a11a` |
| `mimir_migration_012_apply.sh` | `5a10b4a31dd92e0e7f0f0b6d181bcdd2bc8b5183bb825995740268575499aae8` |
| `mimir_migration_012_dry_run.sh` | `3f8a8fef2b54d63d38b029498a684bce8317f0fa2e3c75f84ce1bd27437f8c3e` |

## SQL reconstruído

Os arquivos canônicos em `tools/memory/migrations/` derivam do primeiro bloco
`BEGIN`–`COMMIT` de cada **apply**, com descriptions e versões literais preservadas.
Os dry-runs são evidência complementar; seus ROLLBACKs não substituem COMMIT.
Não foram incluídos wrappers shell, metacomandos psql, leituras de arquivos,
inspeções de serviço ou verificações operacionais pós-COMMIT.

- **009_restrict_ingestion_role_direct_read.sql**: revoga SELECT de `mimir_app`
  sobre `memory_audit`, `memory_events`, `memory_records`, `memory_relations` e
  `schema_version`. Mantém integralmente o bloco SQL transacional do apply,
  inclusive validações de USAGE, EXECUTE de ingestão/proposição e busca semântica.
  Description: `Restrição da leitura direta pelo papel de ingestão`.
- **010_session_ingestion_10mib_limit.sql**: substitui `ingest_session` com limite
  de 10485760 bytes e comparação de `p_size_bytes` com `octet_length(p_content)`.
  Preserva corpo da função, autenticação peer, owner, SECURITY DEFINER,
  search_path, idempotência e ACL. Description:
  `Limite de 10 MiB e validação de tamanho na ingestão de sessões`.
- **011_session_content_constraint_alignment.sql**: substitui e valida
  `session_sources_content_check`, mantendo conteúdo não vazio e limite de
  10485760 bytes. Preserva pré-condições de versão, função, ACL, constraint
  anterior e ausência de sessões/eventos, como no apply. Description:
  `Alinhamento da restrição de conteúdo ao limite de 10 MiB`.
- **012_consolidation_source_read.sql**: cria `read_consolidation_source(uuid)`
  STABLE/SECURITY DEFINER com identidade `mimir_app`/`peer:openclaw`, filtros de
  fonte protegida e verificações de SHA-256/tamanho. Revoga PUBLIC e concede
  somente EXECUTE a `mimir_app`, sem SELECT direto. Description:
  `Leitura controlada de fontes para consolidação`.

### Separação dos testes operacionais

010 e 011 recebiam uma sessão real via variáveis psql do shell: foram retiradas
as tabelas temporárias de amostra, declarações e verificações dependentes dessa
amostra. Na 011 também foi retirado o teste em tabela temporária que duplicava a
constraint (conteúdo vazio, limite exato e excesso). As validações do objeto real
em catálogo permanecem, assim como locks, timeouts, transação e INSERT de versão.

Na 012, foram retiradas das pré-condições apenas as declarações e consultas
relativas à amostra histórica: existência de um evento UUID específico, tamanho
64874, hash fixo, classificação e ausência de candidatos desse evento. Exigir
essa amostra impediria replay sem os dados operacionais da implantação. As
pré-condições de versão, ausência da função e bloqueio de SELECT permanecem.
O teste transacional de rejeição da identidade administrativa permanece intacto,
inclusive seu UUID literal: a rejeição ocorre antes de consultar qualquer fonte.
Os corpos das funções e as alterações persistentes não foram adaptados.

As consultas de exibição anteriores ao COMMIT da 011/012 foram excluídas.
Nenhuma amostra real foi lida ou criada durante esta recuperação. A 011 mantém
sua pré-condição histórica de tabelas de sessões vazias: estes arquivos não são
um procedimento para reaplicar migrations em um banco já atualizado.
A ausência da 001 continua impedindo afirmar bootstrap completo a partir do Git.

## Comparação apply × dry-run

- 009: dry-run verifica explicitamente `current_user=mimir_owner`; apply usa
  `SET ROLE mimir_owner`, sem a verificação adicional. Mensagens diferem e o
  dry-run mostra ACL/versão antes de ROLLBACK. Foi preservado o apply.
- 010: apply acrescenta pré-condição de ausência de SELECT em `session_sources`
  e validação de ausência de EXECUTE para PUBLIC. A função e seus grants/revokes
  são iguais. Há diferenças de mensagens e exibição de resultados.
- 011 e 012: os blocos transacionais diferem em mensagens de ensaio/aplicação e
  COMMIT versus ROLLBACK; as alterações persistentes coincidem.
- Fora da transação, apply faz verificações permanentes; dry-run verifica a
  restauração. A 012 apply também verifica a identidade e a leitura via openclaw.
  Nada disso foi executado ou incorporado como dependência externa do SQL.

Não foi encontrada ambiguidade material sobre a alteração SQL persistente.

## Least privilege e limites da recuperação

A impossibilidade de `mimir_app` ler diretamente `schema_version` é política
esperada após a 009. O validador primeiro consulta o privilégio efetivo; sem
SELECT, retorna PARTIAL e pede inspeção administrativa read-only separada.
Com SELECT, verifica a presença de 1–12 e informa separadamente a 013 operacional.
Falha na inspeção de privilégio continua FAIL. Nenhum privilégio é concedido e
nenhuma identidade ou credencial adicional é usada.

**Produção NÃO foi modificada durante esta recuperação.** Nenhum banco ou
equipamento foi acessado, nenhuma migration executada, nenhum grant real alterado,
nenhum serviço reiniciado e `/var/lib/openclaw/workspace` não foi alterado.
Não houve commit, push ou troca de branch. A validação é local/estática;
execução SQL, grants efetivos e replay em PostgreSQL não foram testados por segurança.

Regra de engenharia: [versionamento de migrations no RUNBOOK](../RUNBOOK.md#versionamento-de-migrations).
