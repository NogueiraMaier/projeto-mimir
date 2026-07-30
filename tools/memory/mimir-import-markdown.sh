#!/bin/bash
set -euo pipefail
umask 027

BASE="/var/lib/openclaw/workspace"

PSQL=(
    psql
    -q
    -X
    -h /run/postgresql
    -U mimir_app
    -d mimir_memory
    -v ON_ERROR_STOP=1
    -At
)

import_file() {
    local file="$1"
    local relative
    local sha256
    local event_id

    relative="${file#${BASE}/}"
    sha256="$(sha256sum "$file" | awk '{print $1}')"

    event_id="$(
        {
            cat <<'SQL'
BEGIN;

CREATE TEMP TABLE mimir_import_stage (
    encoded_content text NOT NULL
) ON COMMIT DROP;

COPY mimir_import_stage(encoded_content) FROM STDIN;
SQL

            base64 -w 0 "$file"
            printf '\n'

            cat <<'SQL'
\.

SELECT mimir.ingest_document(
    'system',
    'mimir',
    :'source_ref',
    'mimir-markdown-importer',
    'internal',
    convert_from(
        decode(encoded_content, 'base64'),
        'UTF8'
    ),
    jsonb_build_object(
        'sha256', :'sha256',
        'source_kind', 'markdown',
        'importer_version', 1
    ),
    now()
)
FROM mimir_import_stage;

COMMIT;
SQL
        } |
        "${PSQL[@]}" \
            -v source_ref="$relative" \
            -v sha256="$sha256"
    )"

    printf 'Importado: %-35s evento=%s\n' \
        "$relative" \
        "$event_id"
}

FILES=()

if [ -s "${BASE}/MEMORY.md" ]; then
    FILES+=("${BASE}/MEMORY.md")
fi

while IFS= read -r -d '' file; do
    FILES+=("$file")
done < <(
    find "${BASE}/memory" \
        -maxdepth 1 \
        -type f \
        -name '*.md' \
        -print0 |
    sort -z
)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Nenhum arquivo de memória encontrado."
    exit 0
fi

for file in "${FILES[@]}"; do
    import_file "$file"
done

echo
echo "Importação concluída."
