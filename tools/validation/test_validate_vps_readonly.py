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
