// The landing page chooses a surface and holds the pending approvals. It
// makes one read of its own, `GET /api/status`, which names the address of
// each surface the launch bound; a surface the launch did not bind leaves its
// card disabled and saying so.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { awaitRequest, flushPromises, install, jsonResponse, newHarness } from './page.mjs';

let counter = 0;

const STATUS_REPORT = {
  gateway: {
    llama_ui_origin: 'http://10.0.0.170:42072',
    image_ui_origin: 'http://10.0.0.170:42073',
    approvals: { profile: 'web-open', image_profile: 'image-sdxs-512-a' }
  },
  runtime: { router_state: 'ready', served_models: ['a', 'b', 'c'] }
};

async function bootLauncher(options = {}) {
  const harness = newHarness(options);
  install(harness);
  globalThis.setInterval = (callback, ms) => ({ callback, ms });
  globalThis.clearInterval = () => {};
  counter += 1;
  const launcher = await import(`../../static/js/launcher.js?page=launch${counter}`);
  const approvals = await import(`../../static/js/approvals.js?page=launch${counter}`);
  return {
    harness, launcher, approvals,
    element: (selector) => harness.document.querySelector(selector),
    take: (predicate, description) => awaitRequest(harness, predicate, description),
    pending: harness.pending
  };
}

test('each card carries the address the status route names', async () => {
  const page = await bootLauncher();
  const status = await page.take((entry) => entry.url === '/api/status', 'the status read');
  status.resolve(jsonResponse(STATUS_REPORT));
  await flushPromises();
  assert.equal(page.element('#choice-chat').href, 'http://10.0.0.170:42072/');
  assert.equal(page.element('#choice-image').href, 'http://10.0.0.170:42073/');
  assert.equal(page.element('#chat-where').textContent, '10.0.0.170:42072');
  assert.equal(page.element('#image-where').textContent, '10.0.0.170:42073');
  assert.equal(page.element('#landing-status').hidden, true,
    'the resting page shows a status line');
});

test('a surface the launch bound none of says so rather than linking nowhere', async () => {
  const page = await bootLauncher();
  const status = await page.take((entry) => entry.url === '/api/status', 'the status read');
  status.resolve(jsonResponse({
    gateway: { llama_ui_origin: '', image_ui_origin: '' },
    runtime: { router_state: 'ready', served_models: [] }
  }));
  await flushPromises();
  for (const id of ['chat', 'image']) {
    assert.equal(page.element(`#choice-${id}`).getAttribute('aria-disabled'), 'true');
    assert.match(page.element(`#${id}-where`).textContent, /binds no .* listener/);
  }
});

test('an unreachable gateway states that rather than a model count', async () => {
  const page = await bootLauncher();
  const status = await page.take((entry) => entry.url === '/api/status', 'the status read');
  status.reject(new Error('connection refused'));
  await flushPromises();
  assert.equal(page.element('#landing-status').getAttribute('data-state'), 'down');
  assert.equal(page.element('#landing-status').textContent, 'the gateway is unreachable');
});

test('the landing page shows a parked tool call and posts the click', async () => {
  const page = await bootLauncher();
  const status = await page.take((entry) => entry.url === '/api/status', 'the status read');
  status.resolve(jsonResponse(STATUS_REPORT));
  const listing = await page.take((entry) => entry.url === '/api/tools/pending', 'the pending read');
  listing.resolve(jsonResponse({ pending: [
    { id: 'c1', tool: 'web_search_exa', kind: 'search', model: 'web-open', age_seconds: 2,
      params: { query: 'raven2 fclk states', max_results: 3 } }
  ] }));
  await flushPromises();
  const cards = page.element('#approvals').children.filter((child) => child.className === 'approval');
  assert.equal(cards.length, 1, 'the parked call did not render');
  assert.ok(cards[0].textContent.includes('search: raven2 fclk states'));
  cards[0].children[3].children[0].onclick();
  const decision = await page.take((entry) => entry.url === '/api/tools/pending/c1', 'the decision');
  assert.deepEqual(JSON.parse(decision.options.body), { decision: 'approve' });
  decision.resolve(jsonResponse({ id: 'c1', decision: 'approve' }));
  await flushPromises();
  assert.equal(
    page.element('#approvals').children.filter((child) => child.className === 'approval').length, 0
  );
});

test('the landing markup holds two choices and no client of its own', () => {
  const markup = fs.readFileSync(new URL('../../static/index.html', import.meta.url), 'utf8');
  assert.ok(!/<script>|<style>/.test(markup), 'the landing page carries an inline block');
  for (const id of ['choice-chat', 'choice-image', 'approvals']) {
    assert.ok(markup.includes(`id="${id}"`), `the landing page lacks #${id}`);
  }
  for (const absent of ['id="chat-frame"', 'id="image-form"', 'iframe']) {
    assert.ok(!markup.includes(absent), `the landing page still carries ${absent}`);
  }
  // The resting page is the two names and nothing else: no rail, no card
  // copy, no address, no legacy link.
  assert.equal(markup.match(/class="name"/g).length, 2);
  assert.ok(!markup.includes('class="note"'), 'the landing page carries card copy');
  assert.ok(!markup.includes('href="legacy/"'), 'the landing page carries a legacy link');
  assert.ok(!markup.includes('class="rail"'), 'the landing page carries a rail');
  assert.ok(markup.includes('Image Generation'), 'the image choice is unnamed');
  assert.ok(markup.includes('src="js/launcher.js"'));
  const image = fs.readFileSync(new URL('../../static/image/index.html', import.meta.url), 'utf8');
  assert.ok(image.includes('id="image-form"'), 'the image surface lost its composer');
  assert.ok(image.includes('src="../js/image-page.js"'));
});
