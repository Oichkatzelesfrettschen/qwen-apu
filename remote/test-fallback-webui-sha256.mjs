#!/usr/bin/env node

// The page hashes an approved prompt before it asks the broker for a grant,
// and WebCrypto's `subtle` is a [SecureContext] interface: a browser leaves
// `crypto.subtle` undefined on the plain-HTTP LAN origin the launch serves.
// This harness lifts the page's SHA-256 block into a context with no
// `crypto` at all, and into one carrying node's webcrypto, and requires both
// paths to produce node's own digest on the FIPS 180-4 vectors, an input
// crossing one and two block boundaries, and UTF-8 outside ASCII.

import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const page = fs.readFileSync(path.join(scriptDirectory, '..', 'webui', 'index.html'), 'utf8');

const blockStart = page.indexOf('const SHA256_ROUND_CONSTANTS');
const blockEnd = page.indexOf('function aspectRatio(');
assert.ok(blockStart > 0 && blockEnd > blockStart, 'the page carries the SHA-256 block ahead of aspectRatio');
const block = page.slice(blockStart, blockEnd);

function load(cryptoValue) {
  const context = { TextEncoder, Math, Uint8Array, Uint32Array, DataView, Array };
  if (cryptoValue !== undefined) context.crypto = cryptoValue;
  vm.createContext(context);
  vm.runInContext(`${block}\nglobalThis.sha256Hex = sha256Hex; globalThis.subtleDigestAvailable = subtleDigestAvailable;`, context);
  return context;
}

const vectors = [
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
  'ünïcödé -- 日本語 -- \u{1F98A}',
];

const scriptOnly = load(undefined);
assert.equal(scriptOnly.subtleDigestAvailable(), false, 'no crypto at all reads as subtle unavailable');
const withRandomOnly = load({ getRandomValues: () => {} });
assert.equal(withRandomOnly.subtleDigestAvailable(), false, 'an insecure context carries getRandomValues alone');
const withSubtle = load(webcrypto);
assert.equal(withSubtle.subtleDigestAvailable(), true, 'node webcrypto reads as subtle available');

for (const text of vectors) {
  const expected = createHash('sha256').update(Buffer.from(text, 'utf8')).digest('hex');
  assert.equal(await scriptOnly.sha256Hex(text), expected, `script path, ${JSON.stringify(text.slice(0, 24))}`);
  assert.equal(await withRandomOnly.sha256Hex(text), expected, `insecure-context path, ${JSON.stringify(text.slice(0, 24))}`);
  assert.equal(await withSubtle.sha256Hex(text), expected, `subtle path, ${JSON.stringify(text.slice(0, 24))}`);
}

assert.equal(
  await scriptOnly.sha256Hex('abc'),
  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
  'the FIPS 180-4 one-block vector',
);

console.log(`fallback_webui_sha256=ok vectors=${vectors.length}`);
