// The shell: one rail selecting Chat or Image, one pairing view, and two
// wrappers over native surfaces. `GET /api/status` is the single read the
// shell makes on its own, so its refusal opens pairing, its answer frames the
// second listener the report names, and the image studio reads the matrix and
// the artifact store on the first opening of its pane.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  IMAGE_BOUNDS, IMAGE_TOOL_MATRIX, awaitRequest, flushPromises, install, jsonResponse,
  newHarness
} from './page.mjs';

let shellCounter = 0;

const STATUS_REPORT = {
  gateway: {
    pid: 1,
    llama_ui_origin: 'http://127.0.0.1:42072',
    approvals: { profile: 'web-open', image_profile: 'image-sdxs-512-a', provider: 'searxng' }
  },
  upstream: { reachable: true, serving: true },
  runtime: { router_state: 'ready', served_models: ['qwen38-2b-distill', 'qwen38-4b-distill'] }
};

async function bootShell(options = {}) {
  const harness = newHarness(options);
  install(harness);
  shellCounter += 1;
  const page = shellCounter;
  const shell = await import(`../../static/js/shell.js?page=shell${page}`);
  const studio = await import(`../../static/js/studio.js?page=shell${page}`);
  return {
    harness, shell, studio,
    element: selector => harness.document.querySelector(selector),
    take: (predicate, description) => awaitRequest(harness, predicate, description),
    pending: harness.pending
  };
}

function answer(request, payload, status = 200) {
  request.resolve(jsonResponse(payload, status));
}

test('a refused status read opens pairing and a pairing admits the shell', async () => {
  const page = await bootShell();
  const first = await page.take(entry => entry.url === '/api/status', 'the status read');
  answer(first, { error: 'no session' }, 403);
  await flushPromises();
  assert.equal(page.element('#view-pair').hidden, false, 'pairing stayed closed');
  assert.equal(page.element('#view-chat').hidden, true, 'the chat pane stayed open unpaired');
  assert.equal(page.element('#rail-status').getAttribute('data-state'), 'unpaired');

  page.element('#pair-code').value = ' code-1 ';
  page.element('#pair-form').onsubmit({ preventDefault() {} });
  const pairing = await page.take(entry => entry.url === '/api/pair', 'the pairing post');
  assert.equal(pairing.options.method, 'POST');
  assert.deepEqual(JSON.parse(pairing.options.body), { code: 'code-1' });
  answer(pairing, { paired: true });
  const second = await page.take(entry => entry.url === '/api/status', 'the status re-read');
  answer(second, STATUS_REPORT);
  await flushPromises();

  assert.equal(page.element('#view-pair').hidden, true, 'pairing stayed open after the cookie');
  assert.equal(page.element('#view-chat').hidden, false, 'the chat pane did not open');
  assert.equal(page.element('#chat-frame').getAttribute('src'), 'http://127.0.0.1:42072/',
    'the chat frame does not point at the listener the status route names');
  assert.equal(page.element('#chat-absent').hidden, true);
  assert.equal(page.element('#plain-ui-link').href, 'http://127.0.0.1:42072/');
  assert.equal(page.element('#plain-ui-link').hidden, false);
  assert.equal(page.element('#rail-status').getAttribute('data-state'), 'ready');
  assert.equal(page.element('#status-text').textContent, 'ready, 2 models');
});

test('a wrong code stays on the pairing view with the refusal', async () => {
  const page = await bootShell();
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), {}, 401);
  await flushPromises();
  page.element('#pair-code').value = 'wrong';
  page.element('#pair-form').onsubmit({ preventDefault() {} });
  const pairing = await page.take(entry => entry.url === '/api/pair', 'the pairing post');
  answer(pairing, { error: 'the pairing code does not match' }, 403);
  await flushPromises();
  assert.equal(page.element('#view-pair').hidden, false);
  assert.equal(page.element('#pair-note').textContent, 'the pairing code does not match');
  assert.equal(page.pending.length, 0, 'a refused pairing re-read the status');
});

test('a launch that binds no second listener says so in the chat pane', async () => {
  const page = await bootShell();
  const status = await page.take(entry => entry.url === '/api/status', 'the status read');
  answer(status, { ...STATUS_REPORT, gateway: { ...STATUS_REPORT.gateway, llama_ui_origin: '' } });
  await flushPromises();
  assert.equal(page.element('#chat-frame').hidden, true);
  assert.equal(page.element('#chat-absent').hidden, false);
  assert.equal(page.element('#plain-ui-link').hidden, true);
});

test('the hash selects the pane and the rail moves it', async () => {
  const page = await bootShell({ hash: '#image' });
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), STATUS_REPORT);
  await flushPromises();
  assert.equal(page.element('#view-image').hidden, false, 'the hash did not open the image pane');
  assert.equal(page.element('#nav-image').getAttribute('aria-selected'), 'true');
  assert.equal(page.element('#nav-chat').getAttribute('aria-selected'), 'false');

  page.element('#nav-chat').onclick();
  assert.equal(page.harness.window.location.hash, '#chat');
  assert.equal(page.element('#view-chat').hidden, false);
  assert.equal(page.element('#view-image').hidden, true);
});

test('opening the image pane reads the profile bounds and the artifact store', async () => {
  const page = await bootShell();
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), STATUS_REPORT);
  await flushPromises();
  page.element('#nav-image').onclick();
  const matrix = await page.take(entry => entry.url === '/api/tools?model=web-open',
    'the matrix read for the approval profile');
  answer(matrix, IMAGE_TOOL_MATRIX);
  const index = await page.take(entry => entry.url === '/api/artifacts', 'the artifact index');
  answer(index, { artifacts: [
    { job_id: 'j1', png_sha256: 'a'.repeat(64), provenance_sha256: 'b'.repeat(64),
      png_url: `/api/artifacts/${'a'.repeat(64)}.png`,
      provenance_url: `/api/artifacts/${'b'.repeat(64)}.json`,
      published_at: '2026-09-11T20:00:00+00:00' }
  ] });
  await flushPromises();
  assert.equal(page.element('#image-size').textContent, '512 x 512');
  assert.equal(page.element('#image-steps').getAttribute('max'), String(IMAGE_BOUNDS.max_steps));
  assert.equal(page.element('#image-generate').disabled, false, 'an executing lane left Generate off');
  assert.equal(page.element('#gallery-empty').hidden, true);
  const cards = page.element('#image-gallery').children.filter(child => child.className === 'artifact');
  assert.equal(cards.length, 1, 'the store entry did not render');
  assert.equal(cards[0].dataset.sha256, 'a'.repeat(64));
  assert.match(page.element('#image-seed').value, /^\d+$/, 'no seed was drawn');

  // A second opening spends no further reads.
  page.element('#nav-chat').onclick();
  page.element('#nav-image').onclick();
  await flushPromises();
  assert.equal(page.pending.length, 0, 'reopening the pane re-read the matrix or the store');
});

test('a lane that cannot execute leaves Generate off and states why', async () => {
  const page = await bootShell({ hash: '#image' });
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), STATUS_REPORT);
  const matrix = await page.take(entry => entry.url === '/api/tools?model=web-open', 'the matrix read');
  answer(matrix, { ...IMAGE_TOOL_MATRIX, tools: IMAGE_TOOL_MATRIX.tools.map(row => (
    row.tool_id === 'image_generation'
      ? { ...row, state: 'temporarily_unavailable', reason: 'the worker socket is unbound' }
      : row)) });
  answer(await page.take(entry => entry.url === '/api/artifacts', 'the artifact index'), { artifacts: [] });
  await flushPromises();
  assert.equal(page.element('#image-generate').disabled, true);
  assert.equal(page.element('#image-note').textContent, 'the worker socket is unbound');
  assert.equal(page.element('#gallery-empty').hidden, false);
});

test('Generate mints one grant over the typed prompt, spends it, and shows the artifact', async () => {
  const page = await bootShell({ hash: '#image' });
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), STATUS_REPORT);
  answer(await page.take(entry => entry.url === '/api/tools?model=web-open', 'the matrix read'),
    IMAGE_TOOL_MATRIX);
  answer(await page.take(entry => entry.url === '/api/artifacts', 'the artifact index'), { artifacts: [] });
  await flushPromises();

  page.element('#image-prompt').value = '  a lighthouse at dusk  ';
  page.element('#image-negative').value = 'text';
  page.element('#image-steps').value = '2';
  page.element('#image-seed').value = '77';
  const finished = page.studio.generate({ preventDefault() {} });

  const session = await page.take(entry => entry.url === '/api/tools/session', 'the session read');
  answer(session, { session_secret: 's3cret' });
  const grant = await page.take(entry => entry.url === '/api/tools/grant-image', 'the grant post');
  assert.equal(grant.options.headers['X-Qwen-Web-Session'], 's3cret');
  const claim = JSON.parse(grant.options.body);
  assert.equal(claim.context, 'qwen-image-generate-v1');
  assert.equal(claim.language_profile, 'web-open');
  assert.equal(claim.image_profile, 'image-sdxs-512-a');
  assert.equal(claim.seed, 77);
  assert.equal(claim.aspect, '1:1');
  assert.equal(claim.max_dimension, 512);
  assert.equal(claim.max_steps, 2);
  assert.equal(claim.conversation_generation, 0);
  assert.match(claim.prompt_hash, /^[0-9a-f]{64}$/);
  assert.match(claim.negative_prompt_hash, /^[0-9a-f]{64}$/);
  answer(grant, { authorization: 'grant.token' });

  const generate = await page.take(entry => entry.url === '/api/tools/image/generate', 'the generation');
  const job = JSON.parse(generate.options.body);
  assert.deepEqual(job, {
    profile_id: 'image-sdxs-512-a', prompt: 'a lighthouse at dusk', negative_prompt: 'text',
    seed: 77, width: 512, height: 512, steps: 2, authorization: 'grant.token'
  });
  assert.equal(page.element('#image-cancel').hidden, false, 'Cancel stayed hidden during the job');
  assert.equal(page.element('#image-generate').disabled, true, 'Generate stayed live during the job');
  answer(generate, {
    sha256: 'c'.repeat(64), artifact_url: `/api/artifacts/${'c'.repeat(64)}.png`,
    provenance_url: `/api/artifacts/${'d'.repeat(64)}.json`, job_id: 'j2', bytes: 10, seconds: 3.25,
    profile_id: 'image-sdxs-512-a'
  });
  const result = await finished;
  assert.equal(result.sha256, 'c'.repeat(64));
  assert.equal(page.element('#image-state').textContent, 'done in 3.3 s');
  assert.equal(page.element('#image-cancel').hidden, true);
  assert.equal(page.element('#image-generate').disabled, false);
  const cards = page.element('#image-gallery').children.filter(child => child.className === 'artifact');
  assert.equal(cards.length, 1);
  assert.equal(cards[0].dataset.sha256, 'c'.repeat(64));
  assert.ok(cards[0].textContent.includes('a lighthouse at dusk'), 'the card carries no prompt');
  assert.ok(cards[0].textContent.includes('seed 77'), 'the card carries no seed');
});

test('a refused grant ends the job with the refusal and spends nothing', async () => {
  const page = await bootShell({ hash: '#image' });
  answer(await page.take(entry => entry.url === '/api/status', 'the status read'), STATUS_REPORT);
  answer(await page.take(entry => entry.url === '/api/tools?model=web-open', 'the matrix read'),
    IMAGE_TOOL_MATRIX);
  answer(await page.take(entry => entry.url === '/api/artifacts', 'the artifact index'), { artifacts: [] });
  await flushPromises();
  page.element('#image-prompt').value = 'x';
  const finished = page.studio.generate({ preventDefault() {} });
  answer(await page.take(entry => entry.url === '/api/tools/session', 'the session read'),
    { session_secret: 's' });
  answer(await page.take(entry => entry.url === '/api/tools/grant-image', 'the grant post'),
    { error: 'the image lane is metered: retry after 30 s' }, 429);
  assert.equal(await finished, null);
  assert.equal(page.element('#image-state').textContent,
    'failed: the image lane is metered: retry after 30 s');
  assert.equal(page.pending.length, 0, 'a refused grant still dispatched a generation');
});

test('the shell markup carries no bearer, no inline block, and the legacy link', () => {
  const markup = fs.readFileSync(new URL('../../static/index.html', import.meta.url), 'utf8');
  for (const id of ['copy-api-key', 'api-key', 'set-key']) {
    assert.ok(!markup.includes(`id="${id}"`), `the shell carries #${id}`);
  }
  assert.ok(!/<script>|<style>/.test(markup), 'the shell carries an inline block');
  assert.ok(markup.includes('href="legacy/"'), 'the legacy page is unreachable from the rail');
  assert.ok(markup.includes('id="chat-frame"'));
  assert.ok(markup.includes('src="js/shell.js"'));
  const legacy = fs.readFileSync(new URL('../../static/legacy/index.html', import.meta.url), 'utf8');
  assert.ok(legacy.includes('href="../app.css"') && legacy.includes('src="../js/status.js"'),
    'the legacy page does not resolve its assets from its subdirectory');
});
