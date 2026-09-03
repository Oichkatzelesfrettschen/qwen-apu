#!/usr/bin/env node

// trustedBrokerOrigin and trustedArtifactOrigin share one host-admission rule
// (admittedOriginHosts): the loopback pair, or the exact host this page was
// served from. brokerOrigin() used to return $('#broker-origin').value
// unchecked, so a `?broker=` query parameter naming a foreign host became the
// destination brokerSession() and postGrant() attach the page's bearer to.
// These checks prove the shared validator admits the same hosts for both
// listeners and refuses everything else, and that brokerOrigin() now applies
// it before a caller ever fetches.

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
  getAttribute() {
    return null;
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
  }
  focus() {}
}

const elements = new Map();
const document = {
  createElement() {
    return new FakeElement();
  },
  querySelector(selector) {
    if (!elements.has(selector)) elements.set(selector, new FakeElement());
    return elements.get(selector);
  },
};

const deniedStorage = {
  getItem() {
    throw new Error('storage denied');
  },
  removeItem() {
    throw new Error('storage denied');
  },
  setItem() {
    throw new Error('storage denied');
  },
};

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const testInterface = `
globalThis.brokerOriginTest = {
  trustedBrokerOrigin,
  trustedArtifactOrigin,
  brokerOrigin,
  setBrokerOriginField(value) {
    $('#broker-origin').value = value;
  },
};
`;

const browserContext = vm.createContext({
  console,
  document,
  fetch() {
    throw new Error('unexpected fetch');
  },
  URL,
  window: {
    alert() {},
    localStorage: deniedStorage,
    sessionStorage: deniedStorage,
    location: {
      hostname: 'qwen-test.local',
      protocol: 'http:',
      port: '8080',
      href: 'http://qwen-test.local:8080/',
    },
  },
});
vm.runInContext(`${inlineScript[1]}\n${testInterface}`, browserContext, {
  filename: webuiPath.pathname,
});

const api = browserContext.brokerOriginTest;

// The loopback pair is admitted for both listeners regardless of page host.
assert.equal(api.trustedBrokerOrigin('http://127.0.0.1:8571'), 'http://127.0.0.1:8571');
assert.equal(api.trustedArtifactOrigin('http://127.0.0.1:8572'), 'http://127.0.0.1:8572');
assert.equal(api.trustedBrokerOrigin('http://[::1]:8571'), 'http://[::1]:8571');

// The exact host this page was served from is admitted for both listeners.
assert.equal(
  api.trustedBrokerOrigin('http://qwen-test.local:8571'), 'http://qwen-test.local:8571');
assert.equal(
  api.trustedArtifactOrigin('http://qwen-test.local:8572'), 'http://qwen-test.local:8572');

// A foreign host is refused for both listeners, by the same rule.
assert.throws(
  () => api.trustedBrokerOrigin('https://attacker.example:443'),
  /must be a literal loopback address, or the literal address this page was served from/,
  'a foreign broker host must be refused');
assert.throws(
  () => api.trustedArtifactOrigin('https://attacker.example:443'),
  /must be a literal loopback address, or the literal address this page was served from/,
  'a foreign artifact host must be refused');

// Userinfo, a trailing path, and a missing port each fail the same literal
// admitted-host-with-port pattern the query-parameter attack fails, on an
// otherwise admitted host.
for (const malformed of [
  'http://user@qwen-test.local:8571',
  'http://qwen-test.local:8571/grant',
  'http://qwen-test.local',
]) {
  assert.throws(() => api.trustedBrokerOrigin(malformed),
    /must be a literal loopback address, or the literal address this page was served from/,
    `malformed origin must be refused: ${malformed}`);
}

// brokerOrigin() applies the same rule to whatever $('#broker-origin') holds,
// which is exactly where a `?broker=` query parameter's value ends up (via
// BROKER_ORIGIN_DEFAULT) and where a user-typed or localStorage-restored
// value ends up too.
api.setBrokerOriginField('http://qwen-test.local:8571');
assert.equal(api.brokerOrigin(), 'http://qwen-test.local:8571');
api.setBrokerOriginField('https://attacker.example');
assert.throws(() => api.brokerOrigin(),
  /must be a literal loopback address, or the literal address this page was served from/,
  'brokerOrigin() must refuse a foreign origin rather than returning it');

console.log('webui-broker-origin=accepted');
