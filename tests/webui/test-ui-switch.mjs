// The tab bar names two launches of one binary. `server_http_context::init`
// mounts a `--path` directory at `api_prefix + "/"` where `public_path` carries
// a value (tools/server/server-http.cpp:333-335) and registers the compiled-in
// llama.cpp UI under the same prefix in its else branch (:339-427), with one
// `--api-prefix` reaching whichever branch runs (common/arg.cpp:3352-3356), so
// a listener serving this page serves no second copy of that UI. The tab
// therefore opens a notice rather than a link into the served origin, and this
// test asserts what the notice states and what the switch moves.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { bootPage, flushPromises } from './page.mjs';

const PAGE_ORIGIN = 'http://127.0.0.1:8090';

test('the notice names the listener this page came from', async () => {
  const page = await bootPage();
  assert.equal(page.element('#llama-ui-link').href, `${PAGE_ORIGIN}/`,
    'the notice does not link to the root of this listener');
  assert.equal(page.element('#llama-ui-origin').textContent, ` -- ${PAGE_ORIGIN}`,
    'the notice does not name the origin it links to');
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
  const markup = fs.readFileSync(new URL('../../static/index.html', import.meta.url), 'utf8');
  const notice = markup.slice(
    markup.indexOf('<section class="notice" id="llama-ui-panel"'),
    markup.indexOf('</section>')).replace(/\s+/g, ' ');
  for (const phrase of ['qwen-apu gateway', '/api/chat', 'web search', 'image generation',
    'feature roster']) {
    assert.ok(notice.includes(phrase), `the notice states nothing about ${phrase}`);
  }
});

test('the bearer copy control leaves with the bearer', () => {
  // The page holds no API key: `POST /api/pair` mints an HttpOnly cookie
  // script cannot read, so there is nothing for a copy button to copy and the
  // llama.cpp UI reaches the router under its own launch.
  const markup = fs.readFileSync(new URL('../../static/index.html', import.meta.url), 'utf8');
  for (const id of ['copy-api-key', 'api-key', 'set-key', 'key-hint', 'lan-key-hint']) {
    assert.ok(!markup.includes(`id="${id}"`), `the page still carries #${id}`);
  }
});
