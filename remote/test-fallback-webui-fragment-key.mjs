#!/usr/bin/env node

// A /#key=<bearer> link hands the page its API key once: the page stores the
// key the way a paste does, rewrites the address bar without the fragment, and
// carries the bearer on an authenticated retry once boot()'s own unauthenticated
// probe of GET /v1/models has proven the backend requires one. A page loaded
// without the fragment keeps whatever the browser remembered and stores
// nothing new. An open backend (QWEN_WEB_LAN_OPEN=1) answers that first probe
// with 200 and no Authorization header, and boot() reads that as proof no key
// is needed: it drops any remembered key from storage rather than trusting it,
// so a bearer from an earlier bearer-mode session on this browser never
// reaches an open listener.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

class FakeElement {
  constructor() {
    this.checked = false;
    this.children = [];
    this.className = '';
    this.dataset = {};
    this.hidden = false;
    this.listeners = new Map();
    this._textContent = '';
    this.value = '';
  }
  getAttribute() { return null; }
  get textContent() { return this._textContent; }
  set textContent(value) { this._textContent = value; if (value === '') this.children = []; }
  addEventListener(eventName, listener) { this.listeners.set(eventName, listener); }
  append(...children) { this.children.push(...children); }
  focus() {}
}

const webuiPath = new URL('../webui/index.html', import.meta.url);
const inlineScript = fs.readFileSync(webuiPath, 'utf8').match(/<script>([\s\S]*?)<\/script>/);
assert.ok(inlineScript, 'the page carries one inline script');

async function flushPromises(turns = 10) {
  for (let turn = 0; turn < turns; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

// `responses` names the status (and, for a 200, the roster body) each
// successive `./v1/models` call answers with, in order; the last entry
// repeats for any call past the end of the list. Every other route answers a
// harmless empty 200 so a fire-and-forget request boot() issues once a model
// is selected (props, a tool probe) settles without throwing.
function makeStore(initial) {
  const store = new Map(initial ? [['qwen-apu-api-key', initial]] : []);
  return {
    store,
    api: {
      getItem(key) { return store.has(key) ? store.get(key) : null; },
      setItem(key, value) { store.set(key, String(value)); },
      removeItem(key) { store.delete(key); },
    },
  };
}

async function loadPage({ hash, remembered, sessionRemembered, responses }) {
  const elements = new Map();
  const document = {
    createElement() { return new FakeElement(); },
    querySelector(selector) {
      if (!elements.has(selector)) elements.set(selector, new FakeElement());
      return elements.get(selector);
    },
  };
  const local = makeStore(remembered);
  const session = makeStore(sessionRemembered);
  const stored = local.store;
  const sessionStored = session.store;
  const localStorage = local.api;
  const sessionStorage = session.api;
  const requests = [];
  const replaced = [];
  const location = {
    hash, hostname: '10.0.0.170', protocol: 'http:', port: '42069',
    pathname: '/', search: '',
    get href() { return `http://10.0.0.170:42069/${this.search}${this.hash}`; },
  };
  let rosterCall = 0;
  async function fetchMock(url, options = {}) {
    const request = { url: String(url), headers: options.headers || {} };
    requests.push(request);
    if (request.url === './v1/models') {
      const spec = responses[Math.min(rosterCall, responses.length - 1)];
      rosterCall += 1;
      return {
        ok: spec.status >= 200 && spec.status < 300,
        status: spec.status,
        async json() { return spec.body ?? { data: [] }; },
      };
    }
    return { ok: true, status: 200, async json() { return {}; } };
  }
  const context = vm.createContext({
    AbortController,
    console,
    document,
    fetch: fetchMock,
    window: {
      alert() {},
      localStorage,
      sessionStorage,
      location,
      history: { replaceState(state, title, url) { replaced.push(url); } },
    },
  });
  vm.runInContext(inlineScript[1], context, { filename: webuiPath.pathname });
  await flushPromises();
  const rosterRequests = requests.filter(request => request.url === './v1/models');
  return { stored, sessionStored, requests, rosterRequests, replaced, elements };
}

{
  const page = await loadPage({
    hash: '#key=abc%2F123', remembered: null,
    responses: [{ status: 401 }, { status: 200, body: { data: [{ id: 'test-model' }] } }],
  });
  assert.equal(page.stored.get('qwen-apu-api-key'), 'abc/123', 'the fragment key is stored');
  assert.deepEqual(page.replaced, ['/'], 'the address bar loses the fragment');
  assert.equal(page.elements.get('#api-key').value, 'abc/123', 'the field shows the key');
  assert.equal(page.rosterRequests.length, 2, 'a bearer-required backend takes a probe and a retry');
  assert.equal(page.rosterRequests[0].headers.Authorization, undefined,
    'the discovery probe carries no Authorization header');
  assert.equal(page.rosterRequests[1].headers.Authorization, 'Bearer abc/123',
    'the authenticated retry carries the fragment key');
  assert.equal(page.elements.get('#api-key').hidden, true,
    'a working fragment key hides the field rather than asking for it again');
  assert.equal(page.elements.get('#set-key').hidden, true);
  console.log('fragment_key_stored_and_sent=accepted');
}

{
  const page = await loadPage({
    hash: '', remembered: 'kept-key',
    responses: [{ status: 401 }, { status: 200, body: { data: [{ id: 'test-model' }] } }],
  });
  assert.equal(page.stored.get('qwen-apu-api-key'), 'kept-key', 'a remembered key survives');
  assert.deepEqual(page.replaced, [], 'no fragment, no rewrite');
  assert.equal(page.rosterRequests.length, 2);
  assert.equal(page.rosterRequests[0].headers.Authorization, undefined);
  assert.equal(page.rosterRequests[1].headers.Authorization, 'Bearer kept-key');
  console.log('remembered_key_reused=accepted');
}

{
  const page = await loadPage({
    hash: '#/c/some-conversation', remembered: null,
    responses: [{ status: 200, body: { data: [{ id: 'test-model' }] } }],
  });
  assert.equal(page.stored.has('qwen-apu-api-key'), false, 'a route fragment stores no key');
  assert.deepEqual(page.replaced, [], 'a route fragment is left alone');
  assert.equal(page.rosterRequests.length, 1, 'no key means no retry, open or not');
  console.log('route_fragment_untouched=accepted');
}

// The discovery probe answers 200 with no Authorization header sent, so the
// backend is open: a key this browser remembered from an earlier bearer-mode
// session must be dropped from storage and never sent, and every key control
// disappears rather than asking for a credential the backend does not want.
{
  const page = await loadPage({
    hash: '', remembered: 'stale-bearer-mode-key',
    responses: [{ status: 200, body: { data: [{ id: 'test-model' }] } }],
  });
  assert.equal(page.rosterRequests.length, 1, 'an open backend answers the probe alone');
  assert.equal(page.rosterRequests[0].headers.Authorization, undefined,
    'the stale bearer never reaches the open listener');
  assert.equal(page.stored.has('qwen-apu-api-key'), false,
    'the stale bearer is dropped from storage rather than kept for next time');
  assert.equal(page.elements.get('#api-key').hidden, true);
  assert.equal(page.elements.get('#set-key').hidden, true);
  assert.equal(page.elements.get('#key-hint').hidden, true);
  assert.equal(page.elements.get('#lan-key-hint').hidden, true,
    'the llama.cpp UI tab stops naming a bearer the router does not require');
  console.log('open_listener_drops_remembered_key=accepted');
}

// A bearer-required backend with nothing remembered and no fragment key
// reveals the input rather than asking silently: the field, the set-key
// button, and the one-line hint all become visible.
{
  const page = await loadPage({
    hash: '', remembered: null,
    responses: [{ status: 401 }],
  });
  assert.equal(page.rosterRequests.length, 1, 'no candidate key means no retry to spend');
  assert.equal(page.elements.get('#api-key').hidden, false);
  assert.equal(page.elements.get('#set-key').hidden, false);
  assert.equal(page.elements.get('#key-hint').hidden, false);
  assert.equal(page.elements.get('#lan-key-hint').hidden, false);
  console.log('bearer_listener_with_no_key_reveals_input=accepted');
}

// A tab upgraded from an earlier build of this page can still carry the key
// in sessionStorage, the store the old code wrote to and this build only
// reads as a fallback. Setting a fresh key must retire that legacy value
// too, or a reload resurrects it through the same fallback read.
{
  const page = await loadPage({
    hash: '', remembered: null, sessionRemembered: 'legacy-session-key',
    responses: [
      { status: 401 }, { status: 200, body: { data: [{ id: 'test-model' }] } },
      { status: 401 }, { status: 200, body: { data: [{ id: 'test-model' }] } },
    ],
  });
  assert.equal(page.sessionStored.get('qwen-apu-api-key'), 'legacy-session-key',
    'the fixture did not seed the legacy session key');
  page.elements.get('#api-key').value = 'a-fresh-key';
  page.elements.get('#set-key').onclick();
  await flushPromises();
  assert.equal(page.stored.get('qwen-apu-api-key'), 'a-fresh-key',
    'the new key did not reach localStorage');
  assert.equal(page.sessionStored.has('qwen-apu-api-key'), false,
    'the legacy session key survived a fresh key being set');
  console.log('set_key_retires_the_legacy_session_store=accepted');
}

console.log('fallback_webui_fragment_key=accepted');
