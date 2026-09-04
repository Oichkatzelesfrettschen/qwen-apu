#!/usr/bin/env node

// The tab bar names two launches of one binary. `server_http_context::init`
// mounts a `--path` directory at `api_prefix + "/"` where `public_path` carries
// a value (tools/server/server-http.cpp:333-335) and registers the compiled-in
// llama.cpp UI under the same prefix in its else branch (:339-427), with one
// `--api-prefix` reaching whichever branch runs (common/arg.cpp:3352-3356), so
// a listener serving this page serves no second copy of that UI. The tab
// therefore opens a notice rather than a link into the served origin, and this
// harness asserts what the notice states and what the switch moves.
//
// It runs the page's own inline script against the fake DOM
// remote/test-fallback-webui-model-state.mjs established, because the claim is
// what the two panels do rather than how a browser paints them.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

class FakeElement {
  constructor() {
    this.attributes = new Map();
    this.checked = false;
    this.children = [];
    this.className = '';
    this.dataset = {};
    this.hidden = false;
    this.href = '';
    this.listeners = new Map();
    this.onclick = null;
    this.scrollHeight = 0;
    this.scrollTop = 0;
    this._textContent = '';
    this.value = '';
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  get textContent() {
    return this._textContent;
  }

  set textContent(value) {
    this._textContent = value;
    if (value === '') this.children = [];
  }

  addEventListener(eventName, listener) {
    this.listeners.set(eventName, listener);
  }

  append(...children) {
    this.children.push(...children);
    for (const child of children) {
      this._textContent += typeof child === 'string' ? child : child.textContent;
    }
  }

  insertBefore(node) {
    this.children.push(node);
    return node;
  }

  focus() {}
}

const deniedStorage = {
  getItem() { throw new Error('storage denied'); },
  setItem() { throw new Error('storage denied'); },
  removeItem() { throw new Error('storage denied'); }
};

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const PAGE_ORIGIN = 'http://127.0.0.1:8080';
const elements = new Map();
const document = {
  createElement() { return new FakeElement(); },
  querySelector(selector) {
    if (!elements.has(selector)) elements.set(selector, new FakeElement());
    return elements.get(selector);
  }
};

let clipboardWrites = [];
let clipboardRefuses = false;

const browserContext = vm.createContext({
  console,
  document,
  fetch() { return new Promise(() => {}); },
  navigator: {
    clipboard: {
      async writeText(text) {
        if (clipboardRefuses) throw new Error('the browser refused the clipboard');
        clipboardWrites.push(text);
      }
    }
  },
  setTimeout,
  clearTimeout,
  window: {
    addEventListener() {},
    alert() {},
    localStorage: deniedStorage,
    location: { href: `${PAGE_ORIGIN}/`, hash: '', hostname: '127.0.0.1', origin: PAGE_ORIGIN },
    sessionStorage: deniedStorage
  }
});
vm.runInContext(inlineScript[1], browserContext, { filename: webuiPath.pathname });

async function flushPromises() {
  for (let turn = 0; turn < 8; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

const workspace = document.querySelector('#workspace');
const panel = document.querySelector('#llama-ui-panel');
const chatTab = document.querySelector('#tab-chat');
const llamaTab = document.querySelector('#tab-llama');

await flushPromises();

// The link names the listener this page came from, which is the address the
// launch without `--path` answers the llama.cpp UI on.
assert.equal(document.querySelector('#llama-ui-link').href, `${PAGE_ORIGIN}/`,
  'the notice does not link to the root of this listener');
assert.equal(document.querySelector('#llama-ui-origin').textContent, ` -- ${PAGE_ORIGIN}`,
  'the notice does not name the origin it links to');

// The Chat panel is what a page load reaches, so the driver's own first wait
// finds the log, the input, and the send button without a click.
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

// The panel names the launch that serves the other page and the surfaces that
// exist on this one alone, which is the whole content of the notice case.
const noticeText = webuiHtml.slice(
  webuiHtml.indexOf('<section class="notice" id="llama-ui-panel"'),
  webuiHtml.indexOf('</section>')).replace(/\s+/g, ' ');
for (const phrase of ['qwen-web-launch.sh', '--path', 'qwen-launch.sh',
  'same address and port', 'web search', 'image generation', 'feature roster']) {
  assert.ok(noticeText.includes(phrase),
    `the notice states nothing about ${phrase}`);
}

// The key travels from the header field alone, and a browser that refuses the
// clipboard says so rather than reporting a copy that never happened.
const copyButton = document.querySelector('#copy-api-key');
const copyNote = document.querySelector('#copy-api-key-note');
document.querySelector('#api-key').value = '   ';
await copyButton.onclick();
assert.equal(copyNote.textContent, ' this page holds no key to copy');
assert.deepEqual(clipboardWrites, []);

document.querySelector('#api-key').value = ' fixture-key-4411 ';
await copyButton.onclick();
assert.deepEqual(clipboardWrites, ['fixture-key-4411'],
  'the copy button did not copy the key the header field holds');
assert.equal(copyNote.textContent, ' copied');

clipboardRefuses = true;
clipboardWrites = [];
await copyButton.onclick();
assert.match(copyNote.textContent, /refused the clipboard/);
assert.deepEqual(clipboardWrites, []);

console.log('fallback_webui_ui_switch=accepted');
