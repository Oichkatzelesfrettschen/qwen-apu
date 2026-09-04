#!/usr/bin/env node

// The page reads QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS
// from a meta tag alone -- unlike the broker and artifact origins, which also
// admit a query-parameter override, these two bounds are a resource ceiling
// against every peer on the network rather than a same-machine location
// convenience, and a query parameter is exactly the input the peer being
// bounded controls from their own address bar. This harness loads the inline
// script once per scenario, since the two bounds are consts resolved once at
// script load from the page's own meta tags.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

class FakeElement {
  constructor(content) {
    this.checked = false;
    this.children = [];
    this.className = '';
    this.dataset = {};
    this.hidden = false;
    this.listeners = new Map();
    this.scrollHeight = 0;
    this.scrollTop = 0;
    this._textContent = '';
    this.value = '';
    this._content = content === undefined ? null : content;
  }

  getAttribute(name) {
    return name === 'content' ? this._content : null;
  }

  // A real DOM node's textContent walks its live children, so a caller that
  // appends a child and mutates that child's own text afterward (the way
  // `turn()` returns a body div this page fills in later) reads the current
  // text rather than a snapshot taken at append time.
  get textContent() {
    if (this.children.length === 0) return this._textContent;
    return this.children
      .map(child => (typeof child === 'string' ? child : child.textContent))
      .join('');
  }

  set textContent(value) {
    this._textContent = value;
    this.children = [];
  }

  addEventListener(eventName, listener) {
    this.listeners.set(eventName, listener);
  }

  append(...children) {
    this.children.push(...children);
  }

  focus() {}
}

function jsonResponse(payload, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() {
      return payload;
    },
  };
}

async function flushPromises() {
  for (let turn = 0; turn < 6; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const testInterface = `
globalThis.webuiLanBoundsTest = {
  bounds() {
    return { prompt: LAN_MAX_PROMPT_TOKENS, output: LAN_MAX_OUTPUT_TOKENS };
  },
  async requestBody() {
    return buildRequestBody([{ role: 'user', content: 'hi' }], false, false);
  },
  async send(text) {
    $('#input').value = text;
    await send();
  },
  pushHistory(role, content) {
    history.push({ role, content });
  },
  logTexts() {
    return logEl.children.map(child => child.textContent);
  },
  historyLength() {
    return history.length;
  },
};
`;

// Every scenario boots the page the same way test-fallback-webui-model-state.mjs
// does: the feature roster is absent, one model answers the tool probe, and its
// properties name a 24576-token context. requestModel is model-A once boot
// settles, which is what buildRequestBody and send() below read.
async function loadPage({ metaContents = {} } = {}) {
  const elements = new Map();
  const document = {
    createElement() {
      return new FakeElement();
    },
    querySelector(selector) {
      if (!elements.has(selector)) {
        const match = selector.match(/^meta\[name="([^"]+)"\]$/);
        const content = match ? metaContents[match[1]] : undefined;
        elements.set(selector, new FakeElement(content !== undefined ? content : null));
      }
      return elements.get(selector);
    },
  };
  const pendingRequests = [];
  function deferredFetch(url, options = {}) {
    return new Promise((resolve, reject) => {
      pendingRequests.push({ url, options, resolve, reject });
    });
  }
  function takeRequest(predicate, description) {
    const index = pendingRequests.findIndex(predicate);
    assert.notEqual(index, -1, `missing request: ${description}`);
    return pendingRequests.splice(index, 1)[0];
  }
  const deniedStorage = {
    getItem() { throw new Error('storage denied'); },
    removeItem() { throw new Error('storage denied'); },
    setItem() { throw new Error('storage denied'); },
  };
  const browserContext = vm.createContext({
    console,
    document,
    fetch: deferredFetch,
    URL,
    performance: { now: () => Date.now() },
    window: {
      alert() {},
      localStorage: deniedStorage,
      sessionStorage: deniedStorage,
      // configuredLanBound reads no query parameter at all, so window.location
      // carries none of the LAN bound state this harness varies; it is
      // present only because other resolvers (broker and artifact origin)
      // still read it.
      location: { href: 'http://127.0.0.1:8080/' },
    },
  });
  vm.runInContext(`${inlineScript[1]}\n${testInterface}`, browserContext, {
    filename: webuiPath.pathname,
  });
  const featureRosterRequest = takeRequest(
    request => request.url === './roster.json', 'feature roster');
  featureRosterRequest.resolve(jsonResponse({ error: 'not found' }, 404));
  const rosterRequest = takeRequest(
    request => request.url === './v1/models', 'initial model roster');
  // With one model in the roster, boot() skips the per-row tool probe
  // entirely (`if (modelIds.length > 1)`) and selects it directly.
  rosterRequest.resolve(jsonResponse({ data: [{ id: 'model-A' }] }));
  await flushPromises();
  const propsRequest = takeRequest(
    request => request.url === './props?model=model-A', 'model A properties');
  propsRequest.resolve(jsonResponse({ n_ctx: 24576 }));
  await flushPromises();
  return { testApi: browserContext.webuiLanBoundsTest, pendingRequests, takeRequest };
}

// An ordinary launch names neither bound: the meta tags are absent (the page
// ships none by default), so both consts read null and buildRequestBody
// sends its unmodified default.
{
  const { testApi } = await loadPage();
  { const bounds = testApi.bounds(); assert.equal(bounds.prompt, null); assert.equal(bounds.output, null); }
  const body = await testApi.requestBody();
  assert.equal(body.max_tokens, 512, 'no LAN bound leaves the page default');
}

// A meta tag alone narrows the output bound below the page's own default.
{
  const { testApi } = await loadPage({
    metaContents: {
      'qwen-lan-max-prompt-tokens': '1000',
      'qwen-lan-max-output-tokens': '100',
    },
  });
  { const bounds = testApi.bounds(); assert.equal(bounds.prompt, 1000); assert.equal(bounds.output, 100); }
  const body = await testApi.requestBody();
  assert.equal(body.max_tokens, 100, 'the LAN output bound narrows max_tokens');
}

// A bound above the page's own default leaves that default in place.
{
  const { testApi } = await loadPage({
    metaContents: { 'qwen-lan-max-output-tokens': '800' },
  });
  const body = await testApi.requestBody();
  assert.equal(body.max_tokens, 512, 'a bound above the page default leaves it unchanged');
}

// A malformed or non-positive meta tag value reads as no bound at all.
{
  const { testApi } = await loadPage({
    metaContents: {
      'qwen-lan-max-prompt-tokens': 'not-a-number',
      'qwen-lan-max-output-tokens': '0',
    },
  });
  { const bounds = testApi.bounds(); assert.equal(bounds.prompt, null); assert.equal(bounds.output, null); }
}

// A prompt above the configured bound is refused before any chat completion
// request is sent, and the refusal is visible in the transcript.
{
  const { testApi, takeRequest } = await loadPage({
    metaContents: { 'qwen-lan-max-prompt-tokens': '10' },
  });
  const sendPromise = testApi.send('a prompt the fixture will count as oversized');
  await flushPromises();
  const tokenizeRequest = takeRequest(
    request => request.url === './tokenize', 'prompt tokenization');
  tokenizeRequest.resolve(jsonResponse({ tokens: new Array(20).fill(1) }));
  await sendPromise;
  assert.equal(testApi.historyLength(), 0, 'the oversized prompt never enters history');
  const texts = testApi.logTexts();
  assert.ok(
    texts.some(text => text.includes('at least 20 tokens') && text.includes('10-token bound')),
    `no oversized-prompt refusal in the transcript: ${JSON.stringify(texts)}`
  );
}

// A prompt inside the bound proceeds to the chat completion request as usual.
{
  const { testApi, takeRequest } = await loadPage({
    metaContents: { 'qwen-lan-max-prompt-tokens': '1000' },
  });
  const sendPromise = testApi.send('a short prompt');
  await flushPromises();
  const tokenizeRequest = takeRequest(
    request => request.url === './tokenize', 'prompt tokenization');
  tokenizeRequest.resolve(jsonResponse({ tokens: [1, 2, 3] }));
  await flushPromises();
  const completionRequest = takeRequest(
    request => request.url === './v1/chat/completions', 'chat completion');
  completionRequest.reject(new Error('the harness ends the turn here'));
  await sendPromise;
  assert.equal(testApi.historyLength(), 1, 'the admitted prompt enters history');
}

// A short new message is still refused when the accumulated conversation
// history it joins has already grown past the bound: the count covers every
// prior turn, not the new message alone.
{
  const { testApi, takeRequest } = await loadPage({
    metaContents: { 'qwen-lan-max-prompt-tokens': '10' },
  });
  testApi.pushHistory('user', 'an earlier turn');
  testApi.pushHistory('assistant', 'an earlier reply');
  const historyBefore = testApi.historyLength();
  const sendPromise = testApi.send('hi');
  await flushPromises();
  const tokenizeRequest = takeRequest(
    request => request.url === './tokenize', 'prompt tokenization');
  const tokenizedText = JSON.parse(tokenizeRequest.options.body).content;
  assert.ok(
    tokenizedText.includes('an earlier turn') && tokenizedText.includes('an earlier reply'),
    `the tokenized text omits accumulated history: ${tokenizedText}`
  );
  tokenizeRequest.resolve(jsonResponse({ tokens: new Array(15).fill(1) }));
  await sendPromise;
  assert.equal(
    testApi.historyLength(), historyBefore,
    'a short new message is still refused once accumulated history exceeds the bound'
  );
}

console.log('fallback_webui_lan_bounds=accepted');
