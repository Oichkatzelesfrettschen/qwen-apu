#!/usr/bin/env node

// A /#key=<bearer> link hands the page its API key once: the page stores the
// key the way a paste does, rewrites the address bar without the fragment, and
// sends the bearer on its first roster request. A page loaded without the
// fragment keeps whatever the browser remembered and stores nothing new.

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

function loadPage({ hash, remembered }) {
  const elements = new Map();
  const document = {
    createElement() { return new FakeElement(); },
    querySelector(selector) {
      if (!elements.has(selector)) elements.set(selector, new FakeElement());
      return elements.get(selector);
    },
  };
  const stored = new Map(remembered ? [['qwen-apu-api-key', remembered]] : []);
  const localStorage = {
    getItem(key) { return stored.has(key) ? stored.get(key) : null; },
    setItem(key, value) { stored.set(key, String(value)); },
    removeItem(key) { stored.delete(key); },
  };
  const requests = [];
  const replaced = [];
  const location = {
    hash, hostname: '10.0.0.170', protocol: 'http:', port: '42069',
    pathname: '/', search: '',
    get href() { return `http://10.0.0.170:42069/${this.search}${this.hash}`; },
  };
  const context = vm.createContext({
    console,
    document,
    fetch(url, options = {}) {
      requests.push({ url: String(url), headers: options.headers || {} });
      return new Promise(() => {});
    },
    window: {
      alert() {},
      localStorage,
      sessionStorage: localStorage,
      location,
      history: { replaceState(state, title, url) { replaced.push(url); } },
    },
  });
  vm.runInContext(inlineScript[1], context, { filename: webuiPath.pathname });
  return { stored, requests, replaced, elements };
}

{
  const page = loadPage({ hash: '#key=abc%2F123', remembered: null });
  assert.equal(page.stored.get('qwen-apu-api-key'), 'abc/123', 'the fragment key is stored');
  assert.deepEqual(page.replaced, ['/'], 'the address bar loses the fragment');
  assert.equal(page.elements.get('#api-key').value, 'abc/123', 'the field shows the key');
  const roster = page.requests.find(request => request.url.endsWith('v1/models'));
  assert.ok(roster, 'the page asks for the roster');
  assert.equal(roster.headers.Authorization, 'Bearer abc/123', 'the roster request carries the bearer');
  console.log('fragment_key_stored_and_sent=accepted');
}

{
  const page = loadPage({ hash: '', remembered: 'kept-key' });
  assert.equal(page.stored.get('qwen-apu-api-key'), 'kept-key', 'a remembered key survives');
  assert.deepEqual(page.replaced, [], 'no fragment, no rewrite');
  const roster = page.requests.find(request => request.url.endsWith('v1/models'));
  assert.equal(roster.headers.Authorization, 'Bearer kept-key');
  console.log('remembered_key_reused=accepted');
}

{
  const page = loadPage({ hash: '#/c/some-conversation', remembered: null });
  assert.equal(page.stored.has('qwen-apu-api-key'), false, 'a route fragment stores no key');
  assert.deepEqual(page.replaced, [], 'a route fragment is left alone');
  console.log('route_fragment_untouched=accepted');
}

console.log('fallback_webui_fragment_key=accepted');
