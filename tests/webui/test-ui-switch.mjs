// The tab bar names two listeners of one gateway. `server_http_context::init`
// mounts a `--path` directory at `api_prefix + "/"` where `public_path` carries
// a value (tools/server/server-http.cpp:333-335) and registers the compiled-in
// llama.cpp UI under the same prefix in its else branch (:339-427), so one
// server serves one of the two pages. `web/llama_ui.py` binds a second gateway
// listener that forwards to that server on loopback, and the tab reads its
// origin from `GET /api/status`, so this test asserts what the panel states,
// what the switch moves, and where the link points once the read answers.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { bootPage, flushPromises } from './page.mjs';

const PAGE_ORIGIN = 'http://127.0.0.1:8090';

test('the tab reads the second listener origin from the status route', async () => {
  const page = await bootPage();
  page.element('#tab-llama').onclick();
  const request = page.pending.find((entry) => entry.url === '/api/status');
  assert.ok(request, 'opening the tab read no status route');
  request.resolve({
    ok: true, status: 200,
    json: async () => ({ gateway: { llama_ui_origin: 'http://127.0.0.1:42072' } })
  });
  await flushPromises();
  assert.equal(page.element('#llama-ui-link').href, 'http://127.0.0.1:42072/',
    'the tab does not link to the listener the status route names');
  assert.equal(page.element('#llama-ui-origin').textContent, ' -- http://127.0.0.1:42072',
    'the tab does not name the origin it links to');
});

test('a launch that binds no second listener says so rather than linking', async () => {
  const page = await bootPage();
  page.element('#tab-llama').onclick();
  const request = page.pending.find((entry) => entry.url === '/api/status');
  request.resolve({ ok: true, status: 200, json: async () => ({ gateway: {} }) });
  await flushPromises();
  assert.equal(page.element('#llama-ui-origin').textContent,
    ' -- this launch binds no second listener');
});

test('a page load opens Chat and the tabs move one panel at a time', async () => {
  const page = await bootPage();
  const workspace = page.element('#workspace');
  const panel = page.element('#llama-ui-panel');
  const chatTab = page.element('#tab-chat');
  const llamaTab = page.element('#tab-llama');

  assert.equal(workspace.hidden, false, 'a page load opened something other than Chat');

  llamaTab.onclick();
  assert.equal(workspace.hidden, true, 'the llama.cpp UI tab left the chat workspace open');
  assert.equal(panel.hidden, false, 'the llama.cpp UI tab opened no notice');
  assert.equal(llamaTab.getAttribute('aria-selected'), 'true');
  assert.equal(chatTab.getAttribute('aria-selected'), 'false');

  chatTab.onclick();
  assert.equal(workspace.hidden, false, 'the Chat tab did not reopen the workspace');
  assert.equal(panel.hidden, true, 'the Chat tab left the notice open');
  assert.equal(chatTab.getAttribute('aria-selected'), 'true');
  assert.equal(llamaTab.getAttribute('aria-selected'), 'false');
});

test('the notice states what exists on this page alone', () => {
  const markup = fs.readFileSync(new URL('../../static/legacy/index.html', import.meta.url), 'utf8');
  const notice = markup.slice(
    markup.indexOf('<section class="notice" id="llama-ui-panel"'),
    markup.indexOf('</section>')).replace(/\s+/g, ' ');
  for (const phrase of ['qwen-apu gateway', '/api/chat', 'web search', 'image generation',
    'feature roster', '--llama-ui-port', 'same pairing', 'Host set']) {
    assert.ok(notice.includes(phrase), `the notice states nothing about ${phrase}`);
  }
});

test('the bearer copy control leaves with the bearer', () => {
  // The page holds no API key: `POST /api/pair` mints an HttpOnly cookie
  // script cannot read, so there is nothing for a copy button to copy and the
  // llama.cpp UI reaches the router through the gateway's own proxy.
  const markup = fs.readFileSync(new URL('../../static/legacy/index.html', import.meta.url), 'utf8');
  for (const id of ['copy-api-key', 'api-key', 'set-key', 'key-hint', 'lan-key-hint']) {
    assert.ok(!markup.includes(`id="${id}"`), `the page still carries #${id}`);
  }
});
