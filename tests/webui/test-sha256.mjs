// The page hashes an approved prompt before it asks the gateway for a grant,
// and WebCrypto's `subtle` is a [SecureContext] interface: a browser leaves
// `crypto.subtle` undefined on the plain-HTTP LAN origin the launch serves.
// api.js therefore carries FIPS 180-4 in script beside the subtle path, and
// this test holds both to node's own digest on the standard vectors, an input
// crossing one and two block boundaries, and UTF-8 outside ASCII.
//
// `subtleDigestAvailable()` reads `crypto` at call time, so one import covers
// all three configurations: the global is swapped between assertions rather
// than the module being re-evaluated under a new context.

import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import test from 'node:test';

import { sha256Hex, subtleDigestAvailable } from '../../static/js/api.js';

const VECTORS = [
  '',
  'abc',
  'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
  'a'.repeat(55),
  'a'.repeat(56),
  'a'.repeat(63),
  'a'.repeat(64),
  'a'.repeat(65),
  'a'.repeat(1000),
  'A fox in a snowy field, winter scene, soft sunlight',
  // The multi-byte vectors stay escaped so the file is ASCII and the bytes
  // under test are still the ones a browser would encode.
  '\u00fcn\u00efc\u00f6d\u00e9 -- \u65e5\u672c\u8a9e -- \u{1F98A}'
];

function withCrypto(value, action) {
  const held = globalThis.crypto;
  if (value === undefined) delete globalThis.crypto;
  else Object.defineProperty(globalThis, 'crypto', { value, configurable: true, writable: true });
  try {
    return action();
  } finally {
    Object.defineProperty(globalThis, 'crypto', { value: held, configurable: true, writable: true });
  }
}

test('the availability probe reads the live crypto object', () => {
  withCrypto(undefined, () => {
    assert.equal(subtleDigestAvailable(), false, 'no crypto at all reads as subtle unavailable');
  });
  withCrypto({ getRandomValues: () => {} }, () => {
    assert.equal(subtleDigestAvailable(), false,
      'an insecure context carries getRandomValues alone');
  });
  withCrypto(webcrypto, () => {
    assert.equal(subtleDigestAvailable(), true, 'node webcrypto reads as subtle available');
  });
});

test('both digest paths answer with node own digest', async () => {
  for (const text of VECTORS) {
    const expected = createHash('sha256').update(Buffer.from(text, 'utf8')).digest('hex');
    const scriptOnly = await withCrypto(undefined, () => sha256Hex(text));
    const insecure = await withCrypto({ getRandomValues: () => {} }, () => sha256Hex(text));
    const subtle = await withCrypto(webcrypto, () => sha256Hex(text));
    const sample = JSON.stringify(text.slice(0, 24));
    assert.equal(scriptOnly, expected, `script path, ${sample}`);
    assert.equal(insecure, expected, `insecure-context path, ${sample}`);
    assert.equal(subtle, expected, `subtle path, ${sample}`);
  }
});

test('the FIPS 180-4 one-block vector', async () => {
  assert.equal(
    await withCrypto(undefined, () => sha256Hex('abc')),
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});
