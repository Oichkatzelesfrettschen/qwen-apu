// Retired: the broker origin this test validated no longer exists, because the
// gateway serves the approval routes on the page's own origin.
//
// remote/test-fallback-webui-broker-origin.mjs held `trustedListenerOrigin` to
// its admitted-host rule, which existed because the page derived a sibling
// origin from a `qwen-web-broker` meta tag or a `?broker=` query parameter and
// attached the appliance bearer to it. static/js/api.js posts
// `/api/tools/session`, `/api/tools/grant`, and `/api/tools/grant-image` as
// same-origin paths under a cookie the browser scopes to this origin itself, so
// there is no configured origin left to validate and no credential a foreign
// host could receive. tests/test_static_page.py asserts the replacement: every
// `fetch(` URL literal the page carries begins with `/api/`.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

test('no module derives an origin of its own', () => {
  const directory = new URL('../../static/js/', import.meta.url);
  for (const name of fs.readdirSync(directory)) {
    const source = fs.readFileSync(new URL(name, directory), 'utf8');
    for (const token of ['qwen-web-broker', 'qwen-image-artifacts', 'trustedListenerOrigin',
      'BROKER_ORIGIN_FALLBACK', 'window.location.hostname']) {
      assert.ok(!source.includes(token), `${name} still derives an origin through ${token}`);
    }
  }
});
