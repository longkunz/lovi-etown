import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function findTestFiles(dir, matchPattern) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(findTestFiles(fullPath, matchPattern));
    } else if (entry.isFile() && matchPattern(entry.name)) {
      results.push(fullPath);
    }
  }
  return results;
}

const suite = process.argv[2] || 'all';
const baseDir = path.resolve(__dirname, '..', '.test-dist', 'test');

let files = [];
if (suite === 'unit') {
  files = findTestFiles(path.join(baseDir, 'unit'), (name) => name.endsWith('.test.js'));
} else if (suite === 'api') {
  files = findTestFiles(path.join(baseDir, 'integration'), (name) => name.endsWith('.test.js') && !name.includes('repository') && !name.includes('catalog-sync'));
} else if (suite === 'db') {
  files = findTestFiles(path.join(baseDir, 'integration'), (name) => name.endsWith('.test.js') && (name.includes('repository') || name.includes('catalog-sync')));
} else if (suite === 'all') {
  files = findTestFiles(baseDir, (name) => name.endsWith('.test.js'));
} else {
  files = findTestFiles(baseDir, (name) => name.includes(suite) && name.endsWith('.test.js'));
}

if (files.length === 0) {
  console.log(`No test files found for suite '${suite}' in ${baseDir}`);
  process.exit(0);
}

console.log(`Running ${files.length} test file(s) for suite '${suite}':`);
for (const f of files) {
  console.log(` - ${path.relative(path.resolve(__dirname, '..'), f)}`);
}

const result = spawnSync(process.execPath, ['--test', ...files], {
  stdio: 'inherit',
  env: process.env,
});

process.exit(result.status ?? 1);
