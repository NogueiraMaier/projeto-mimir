#!/bin/bash
set -euo pipefail
umask 077

ENV_FILE="/etc/openclaw/gateway.env"
PYTHON_SCRIPT="/var/lib/openclaw/workspace/tools/memory/mimir-consolidate-dryrun.py"

if [ ! -r "$ENV_FILE" ]; then
    echo "ERRO: arquivo de ambiente não pode ser lido: $ENV_FILE" >&2
    exit 1
fi

# Exporta somente as variáveis declaradas no arquivo protegido.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${NVIDIA_API_KEY:-}" ]; then
    echo "ERRO: NVIDIA_API_KEY não definida em $ENV_FILE" >&2
    exit 1
fi

exec /usr/bin/python3 "$PYTHON_SCRIPT" "$@"
