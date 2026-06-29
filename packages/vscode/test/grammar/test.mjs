import { spawn } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const grammarDir = resolve(__dirname, '../../syntaxes');
const dummyGrammarDir = resolve(__dirname, './dummy');

const grammars = [
  ...readdirSync(grammarDir)
    .filter((file) => file.endsWith('.json'))
    .map((file) => join(grammarDir, file)),
  ...readdirSync(dummyGrammarDir)
    .filter((file) => file.endsWith('.json'))
    .map((file) => join(dummyGrammarDir, file)),
];

const extraArgs = process.argv.slice(2);
const args = [
  'vscode-tmgrammar-snap',
  '-s',
  'source.astral',
  './test/grammar/fixtures/**/*.astral',
  ...grammars.flatMap((grammar) => ['-g', grammar]),
  ...extraArgs,
];

const child = spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['exec', '--', ...args], {
  cwd: resolve(__dirname, '../..'),
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

child.on('exit', (code) => {
  process.exit(code ?? 1);
});

child.on('error', (error) => {
  console.error(error);
  process.exit(1);
});
