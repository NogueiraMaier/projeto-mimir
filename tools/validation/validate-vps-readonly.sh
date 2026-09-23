#!/bin/bash
# Read-only inspection. No configuration reads, migrations, services changes,
# SSH, network TCP, dependency installation, build, or production test fixtures.
set -u
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C
export PYTHONDONTWRITEBYTECODE=1
export GIT_OPTIONAL_LOCKS=0
unset BASH_ENV ENV CDPATH

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P) || exit 2
db_user=mimir_app
skip_db=0
while (($#)); do
    case "$1" in
        --db-user) (($# >= 2)) || exit 2; db_user=$2; shift 2 ;;
        --skip-db) skip_db=1; shift ;;
        --help) echo 'Usage: bash tools/validation/validate-vps-readonly.sh [--db-user ROLE] [--skip-db]'; exit 0 ;;
        *) echo 'FAIL: unknown argument'; exit 2 ;;
    esac
done
[[ $db_user =~ ^[a-z_][a-z0-9_]*$ ]] || exit 2
failures=0
check() {
    local label=$1
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'PASS: %s\n' "$label"
    else
        printf 'FAIL: %s\n' "$label"
        failures=$((failures+1))
    fi
}
check 'Gentoo marker' test -r /etc/gentoo-release
check 'OpenRC binary' command -v rc-status
# rc-service status runs an arbitrary local init script. Only inspect presence;
# service/runtime health is explicitly not claimed by this validator.
check 'OpenClaw OpenRC service file' test -f /etc/init.d/openclaw
check 'OpenClaw installed package' test -r /opt/openclaw/package.json
check 'Python available' command -v python3
check 'Node available' command -v node
python3 --version 2>/dev/null || :
node --version 2>/dev/null || :
python3 -B - /opt/openclaw/package.json <<'PY'
import json,re,sys
try:
    with open(sys.argv[1]) as f: version=json.load(f).get('version','')
    if not re.fullmatch(r'[0-9][0-9A-Za-z.+-]{0,63}',version): raise ValueError()
    print('OpenClaw package version: '+version)
except (OSError,ValueError,TypeError):
    print('PARTIAL: OpenClaw version unavailable')
PY
git_ro() { git -c core.fsmonitor=false -c core.untrackedCache=false -C "$repo" "$@"; }
check 'Git repository' git_ro rev-parse --is-inside-work-tree
# Do not print filenames, URLs, branch names, commit messages or private changes.
if git_state=$(git_ro status --porcelain --untracked-files=normal 2>/dev/null); then
    if [[ -z $git_state ]]; then echo 'PASS: Git working tree clean';
    else echo 'PARTIAL: Git working tree has changes'; fi
else echo 'FAIL: Git state unavailable'; failures=$((failures+1)); fi
check 'Git diff whitespace' git_ro diff --no-ext-diff --no-textconv --check
check 'Plugin manifest/source structure' python3 -B - "$repo" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])/'plugins/mimir-memory'
p=json.loads((root/'openclaw.plugin.json').read_text())
assert p['id']=='mimir-memory'
assert 'mimir_memory_search' in p['contracts']['tools']
assert (root/'src/index.ts').is_file()
PY
check 'Plugin built entry exists' test -f "$repo/plugins/mimir-memory/dist/index.js"
echo 'PARTIAL: plugin runtime loading and services health require separate authorized inspection'

# Pure checks: no unittest TemporaryDirectory, Vitest cache, py_compile or tsc emission.
check 'Python syntax (memory + ops)' python3 -B - "$repo" <<'PY'
import ast,pathlib,sys
root=pathlib.Path(sys.argv[1])
for directory in ('tools/memory','tools/ops','tools/validation'):
    for path in (root/directory).glob('*.py'):
        ast.parse(path.read_text(encoding='utf8'), filename=path.name)
PY
for script in "$repo"/tools/memory/*.mjs; do
    check "Node syntax: ${script##*/}" node --check "$script"
done
check 'Memory classifier synthetic self-test' node "$repo/tools/memory/mimir-evidence-shadow-evaluate.mjs" --self-test-classifier
check 'Ops synthetic policy self-test' python3 -B - "$repo" <<'PY'
import pathlib,sys
sys.path.insert(0,str(pathlib.Path(sys.argv[1])/'tools/ops'))
from mimir_ops import enforce,PolicyError,redact
assert enforce('READ','ip address')=='read'
for command in ('ip address; reboot','rc-service sshd restart','/system reset-configuration'):
    try: enforce('READ',command)
    except PolicyError: pass
    else: raise AssertionError('policy bypass')
assert redact('token=synthetic')=='<redacted>'
PY

if ((skip_db)); then
    echo 'SKIP: PostgreSQL/pgvector/schema checks explicitly disabled'
else
    psql_bin=$(command -v psql || :)
    if [[ -z $psql_bin && -x /usr/lib64/postgresql-17/bin/psql ]]; then
        psql_bin=/usr/lib64/postgresql-17/bin/psql
    fi
    if [[ -z $psql_bin ]]; then
        echo 'FAIL: psql unavailable'; failures=$((failures+1))
    else
        psql_ro() {
            env -i PATH="$PATH" LC_ALL=C PGCONNECT_TIMEOUT=5 PGPASSFILE=/dev/null \
                PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000' \
                timeout 15 "$psql_bin" -X -w -qAt -h /run/postgresql -p 5432 -U "$db_user" \
                -d mimir_memory -v ON_ERROR_STOP=1 -c "$1"
        }
        check 'PostgreSQL local socket / mimir_memory / read-only transaction' psql_ro \
            "BEGIN READ ONLY; SELECT 1 / (current_database()='mimir_memory' AND current_setting('transaction_read_only')='on')::int; ROLLBACK;"
        check 'PostgreSQL >=17' psql_ro \
            "BEGIN READ ONLY; SELECT 1 / (current_setting('server_version_num')::int >= 170000)::int; ROLLBACK;"
        check 'pgvector extension' psql_ro \
            "BEGIN READ ONLY; SELECT 1 / EXISTS(SELECT FROM pg_extension WHERE extname='vector')::int; ROLLBACK;"
        check 'schema_version includes 008' psql_ro \
            "BEGIN READ ONLY; SELECT 1 / EXISTS(SELECT FROM mimir.schema_version WHERE version=8)::int; ROLLBACK;"
        if psql_ro "BEGIN READ ONLY; SELECT 1 / EXISTS(SELECT FROM mimir.schema_version WHERE version=9)::int; ROLLBACK;" >/dev/null 2>&1; then
            echo 'PASS: schema_version 009 present (does not attest migration contents)'
        else
            echo 'PARTIAL: schema_version 009 absent or not readable; no migration applied'
        fi
    fi
fi
printf 'Readonly validation finished: %s failed checks\n' "$failures"
((failures == 0))
