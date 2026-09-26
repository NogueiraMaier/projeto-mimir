"""Never connect to a database or equipment, including when testing the validator."""
import os
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('validate-vps-readonly.sh')


class ValidatorTests(unittest.TestCase):
    def test_plugin_build_artifact_and_structure(self):
        source = SCRIPT.read_text()
        check = source[source.index('check() {'):source.index("check 'Gentoo marker'")]
        plugin = source[source.index("check 'Plugin manifest/source structure'"):
                        source.index("echo 'PARTIAL: plugin runtime loading")]
        cases = (
            ('present', True, True, False, None, 0, 'PASS: Plugin built entry exists'),
            ('source checkout', False, True, False, None, 0, 'PARTIAL: Plugin built entry absent'),
            ('not ignored', False, False, False, None, 1, 'FAIL: Plugin built entry missing'),
            ('tracked dist', False, True, True, None, 1, 'FAIL: Plugin built entry missing'),
            ('bad manifest', False, True, False, 'manifest', 1, 'FAIL: Plugin manifest/source structure'),
            ('missing source', False, True, False, 'source', 1, 'FAIL: Plugin manifest/source structure'),
            ('bad package', False, True, False, 'package', 1, 'FAIL: Plugin manifest/source structure'),
        )
        for name, present, ignored, tracked, broken, failures, expected in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                plugin_root = root / 'plugins/mimir-memory'
                (plugin_root / 'src').mkdir(parents=True)
                if broken != 'source':
                    (plugin_root / 'src/index.ts').write_text('export {};\n')
                manifest = {'id': 'wrong' if broken == 'manifest' else 'mimir-memory',
                            'contracts': {'tools': ['mimir_memory_search']}}
                (plugin_root / 'openclaw.plugin.json').write_text(json.dumps(manifest))
                package = {'openclaw': {'extensions': [] if broken == 'package' else ['./dist/index.js']}}
                (plugin_root / 'package.json').write_text(json.dumps(package))
                if ignored:
                    (plugin_root / '.gitignore').write_text('dist/\n')
                subprocess.run(['git', 'init', '-q', directory], check=True, capture_output=True)
                if present or tracked:
                    (plugin_root / 'dist').mkdir()
                    entry = plugin_root / 'dist/index.js'
                    entry.write_text('export {};\n')
                    if tracked:
                        subprocess.run(['git', '-C', directory, 'add', '-f',
                                        'plugins/mimir-memory/dist/index.js'], check=True, capture_output=True)
                        entry.unlink()
                script = ('repo=$1\nfailures=0\n'
                          'git_ro() { git -c core.fsmonitor=false -c core.untrackedCache=false -C "$repo" "$@"; }\n'
                          + check + plugin + '\nprintf "failures=%s\\n" "$failures"\n')
                result = subprocess.run(['bash', '-c', script, 'validator-test', directory],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertIn(f'failures={failures}\n', result.stdout)
                if failures == 0:
                    self.assertIn('PASS: Plugin manifest/source structure', result.stdout)
                    self.assertNotIn('FAIL:', result.stdout)

    def test_syntax(self):
        result = subprocess.run(['bash', '-n', str(SCRIPT)], capture_output=True)
        self.assertEqual(result.returncode, 0)

    def test_help_and_rejected_arguments_do_not_probe(self):
        for args, code in ((['--help'], 0), (['--db-user', 'x; SELECT secret'], 2), (['--unknown'], 2)):
            result = subprocess.run(['bash', str(SCRIPT), *args], capture_output=True, timeout=5)
            self.assertEqual(result.returncode, code)
            self.assertNotIn(b'PostgreSQL local socket', result.stdout)

    def test_local_inspection_explicitly_skips_database_and_hides_environment(self):
        env = {**os.environ, 'PGPASSWORD': 'synthetic-private-marker', 'OPENCLAW_TOKEN': 'synthetic-private-marker'}
        result = subprocess.run(['bash', str(SCRIPT), '--skip-db'], capture_output=True, timeout=30, env=env)
        self.assertIn(result.returncode, (0, 1))  # Development host need not have VPS packages.
        self.assertIn(b'SKIP: PostgreSQL/pgvector/schema checks explicitly disabled', result.stdout)
        self.assertIn(b'PASS: Memory classifier synthetic self-test', result.stdout)
        self.assertIn(b'PASS: Ops synthetic policy self-test', result.stdout)
        self.assertNotIn(b'PostgreSQL local socket', result.stdout)
        self.assertNotIn(b'synthetic-private-marker', result.stdout + result.stderr)

    def test_schema_history_with_simulated_privileges(self):
        # Extract only pure shell functions. Never source/run the database branch.
        source = SCRIPT.read_text()
        check = source[source.index('check() {'):source.index("check 'Gentoo marker'")]
        history = source[source.index('validate_schema_history() {'):source.index('if ((skip_db));')]
        mock = r'''psql_ro() {
            case "$1" in
                *has_table_privilege*) echo "$PRIVILEGE"; return "$PROBE_CODE" ;;
                *"BETWEEN 1 AND 12"*) echo history >&3; return "$HISTORY_CODE" ;;
                *"version=13"*) echo operational >&3; return "$OPS_CODE" ;;
                *) return 99 ;;
            esac
        }
        '''
        for privilege, probe, history_code, ops, expected, failures in (
            ('f', 0, 99, 99, 'PARTIAL: schema_version is not directly readable', 0),
            ('t', 0, 0, 0, 'PASS: schema_version 013 present', 0),
            ('t', 0, 0, 1, 'PARTIAL: schema_version 013 absent', 0),
            ('t', 0, 1, 0, 'FAIL: schema_version history 001-012 complete', 1),
            ('', 1, 99, 99, 'FAIL: schema_version privilege inspection failed', 1),
            ('unexpected', 0, 99, 99, 'FAIL: schema_version privilege inspection returned', 1),
        ):
            with self.subTest(privilege=privilege, history=history_code, ops=ops):
                script = (f'failures=0; PRIVILEGE={privilege!r}; PROBE_CODE={probe}; '
                          f'HISTORY_CODE={history_code}; OPS_CODE={ops}\n'
                          + check + mock + history
                          + '\nvalidate_schema_history 3>&2\necho failures=$failures\n')
                result = subprocess.run(['bash', '-c', script], capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0)
                self.assertIn(expected, result.stdout)
                self.assertIn(f'failures={failures}', result.stdout)
                if privilege == 'f':
                    self.assertNotIn('FAIL:', result.stdout)
                    self.assertIn('separate administrative read-only inspection', result.stdout)
                    self.assertNotIn('history', result.stderr)
                    self.assertNotIn('operational', result.stderr)

    def test_no_deployment_mutations(self):
        source = SCRIPT.read_text()
        lines = []
        in_python = False
        for line in source.splitlines():
            if line == 'PY':
                in_python = False
                continue
            if in_python:
                continue
            if "<<'PY'" in line:
                in_python = True
            if not line.lstrip().startswith('#'):
                lines.append(line)
        commands = '\n'.join(lines)
        for forbidden in ('systemctl ', 'rc-service ', 'git switch', 'git checkout', 'git pull',
                          'git push', 'ssh ', 'psql -f', 'npm install', 'npm test', 'py_compile'):
            # Comments are explanatory, not executed instructions.
            self.assertNotIn(forbidden, commands)
        self.assertIn('BEGIN READ ONLY;', source)
        self.assertIn('PGPASSFILE=/dev/null', source)
        self.assertIn('default_transaction_read_only=on', source)


if __name__ == '__main__':
    unittest.main()
