// Every WebUI module test, in one entry point.
//
// `node --test tests/webui/` resolves a directory argument through CommonJS
// directory resolution rather than searching it, so the package.json beside
// this file names it as the directory's own entry and these imports are what
// the runner then discovers. Each file also runs by itself -- `node --test
// tests/webui/test-roster.mjs` -- and the enrollment check below is what keeps
// a new test from passing by never being run.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import './test-artifact-origin.mjs';
import './test-broker-origin.mjs';
import './test-conversations.mjs';
import './test-image-review.mjs';
import './test-lan-bounds.mjs';
import './test-mixed-roster.mjs';
import './test-model-state.mjs';
import './test-pair.mjs';
import './test-roster.mjs';
import './test-sha256.mjs';
import './test-temporary.mjs';
import './test-ui-switch.mjs';

const ENROLLED = [
  'test-artifact-origin.mjs',
  'test-broker-origin.mjs',
  'test-conversations.mjs',
  'test-image-review.mjs',
  'test-lan-bounds.mjs',
  'test-mixed-roster.mjs',
  'test-model-state.mjs',
  'test-pair.mjs',
  'test-roster.mjs',
  'test-sha256.mjs',
  'test-temporary.mjs',
  'test-ui-switch.mjs'
];

test('every test file in this directory is enrolled', () => {
  const present = fs.readdirSync(new URL('.', import.meta.url))
    .filter(name => name.startsWith('test-') && name.endsWith('.mjs'))
    .sort();
  assert.deepEqual(present, [...ENROLLED].sort(),
    'a test file in tests/webui/ is not imported by all.mjs');
});
