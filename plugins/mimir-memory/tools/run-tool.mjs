// Prefer project dependencies; retain the existing shared Gentoo installation.
// No package manager invocation and no automatic download.
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const [tool, ...args] = process.argv.slice(2);
const entries = { test: ['vitest', 'vitest.mjs'], build: ['typescript', 'lib/tsc.js'] };
if (!Object.hasOwn(entries, tool)) {
  console.error('Use run-tool.mjs test|build');
  process.exit(2);
}
let entry;
for (const source of [import.meta.url, '/opt/openclaw/package.json']) {
  try {
    const require = createRequire(source);
    const [name, relative] = entries[tool];
    entry = join(dirname(require.resolve(`${name}/package.json`)), relative);
    break;
  } catch { /* Try the shared installation next. */ }
}
if (!entry) {
  console.error('Dependências locais/compartilhadas indisponíveis; nenhum download foi feito.');
  process.exit(2);
}
process.argv = [process.execPath, entry, ...args];
await import(pathToFileURL(entry).href);
