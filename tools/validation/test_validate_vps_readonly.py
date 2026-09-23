"""Never connect to a database or equipment, including when testing the validator."""
import os
from pathlib import Path
import subprocess
import unittest

SCRIPT = Path(__file__).with_name('validate-vps-readonly.sh')


class ValidatorTests(unittest.TestCase):
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
