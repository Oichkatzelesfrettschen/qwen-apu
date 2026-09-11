// Retired: the artifact origin assertions this file carried no longer apply,
// because the gateway reads an artifact on the page's own origin.
//
// remote/test-fallback-webui-image-review.mjs required the review path to
// resolve `?artifacts=` and the `qwen-image-artifacts` meta tag through
// `trustedArtifactOrigin` before sending a credential to it. static/js/
// artifacts.js reads `/api/artifacts/<sha256>.png` as a same-origin path, so no
// origin is configured and none is validated. What survives is the digest rule:
// the bytes are hashed after they arrive and the Open and Download links are
// filled only from bytes that matched, which tests/webui/test-image-review.mjs
// asserts.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

test('the artifact read names one same-origin route', () => {
  const source = fs.readFileSync(new URL('../../static/js/artifacts.js', import.meta.url), 'utf8');
  const literals = [...source.matchAll(/fetch\(\s*[`'"]([^`'"$]*)/g)].map(match => match[1]);
  assert.ok(literals.length > 0, 'artifacts.js reaches the network through no literal route');
  for (const literal of literals) {
    assert.ok(literal.startsWith('/api/'), `artifacts.js fetches ${literal}`);
  }
  assert.ok(source.includes('/api/artifacts/'),
    'artifacts.js reads no artifact route at all');
});
