#!/usr/bin/env node

// One router serves the whole roster, so `GET /v1/models` returns tool-free
// registry ids beside the one web profile that carries an MCP configuration.
// llama-server registers the `/tools` route per child from that section's own
// configuration, so a tool-free child answers `403 feature_disabled`
// (evidence/web-admission-router-tools.md) where the web child answers a JSON
// array.
//
// This harness runs the page's own inline script against a fake DOM and a
// deferred fetch, the vehicle remote/test-fallback-webui-model-state.mjs uses,
// and calls resolveWebTools directly: the assertion is what the per-turn Web
// toggle composes into `body.tools` for each id, which is the whole claim the
// merged preset rests on.
//
// Three properties decide it. A tool-carrying id yields the two web tool
// definitions. A tool-free id yields an empty list and reaches no alert, so the
// toggle is inert rather than an error. Selecting between the two re-resolves
// rather than serving the previous id's answer, since the cache is keyed by
// model and selection generation.

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
    this.scrollHeight = 0;
    this.scrollTop = 0;
    this._textContent = '';
    this.title = '';
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
    for (const child of children) {
      this._textContent += typeof child === 'string' ? child : child.textContent;
    }
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

// Every request the page makes is recorded and answered here, so the arm reads
// which model each listing named as well as what the page did with the answer.
const requests = [];
let nextResponse = null;
function recordingFetch(url, options = {}) {
  requests.push({ url, options });
  const responder = nextResponse;
  if (!responder) return Promise.reject(new Error('no response staged'));
  return Promise.resolve(responder(url));
}

const alerts = [];

function jsonResponse(payload, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() {
      return payload;
    },
  };
}

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const browserContext = vm.createContext({
  console,
  document,
  fetch: recordingFetch,
  setTimeout,
  clearTimeout,
  window: {
    alert(message) {
      alerts.push(message);
    },
    localStorage: deniedStorage,
    sessionStorage: deniedStorage,
  },
});
vm.runInContext(inlineScript[1], browserContext, { filename: webuiPath.pathname });

// resolveWebTools writes its cache only where modelStateMatches agrees, so the
// selected model and the selection generation are set the way a completed
// selection leaves them.
function selectModel(modelId, generation) {
  vm.runInContext(
    `requestModel = ${JSON.stringify(modelId)}; ` +
      `modelStateGeneration = ${generation};`,
    browserContext);
}

function resolve(modelId, generation) {
  return vm.runInContext(
    `resolveWebTools(${JSON.stringify(modelId)}, ${generation})`,
    browserContext);
}

const toolFreeModel = 'qwen38-2b-distill';
const webProfile = 'web-open';
// llama-server renders each tool as `{tool, definition}` where `definition`
// is the OpenAI function object it builds from the MCP input schema
// (server-tools.cpp:75-85 and 1823-1834), and `search_exa` advertises an
// `authorization` property the broker alone issues.
function listedTool(name) {
  return {
    tool: name,
    definition: {
      type: 'function',
      function: {
        name,
        description: name,
        parameters: {
          type: 'object',
          properties: { query: { type: 'string' }, authorization: { type: 'string' } },
          required: ['query', 'authorization'],
        },
      },
    },
  };
}
const webListing = [listedTool('web_search_exa'), listedTool('web_fetch_exa')];

// The web profile answers a listing, and the page composes both tools from it.
requests.length = 0;
nextResponse = () => jsonResponse(webListing);
selectModel(webProfile, 1);
const webTools = await resolve(webProfile, 1);
assert.equal(webTools.length, 2,
  'the web profile composed no tool definitions from its listing');
assert.equal(requests.length, 1,
  'the web profile listing took more than one request');
assert.ok(
  requests[0].url.includes(`model=${encodeURIComponent(webProfile)}`),
  'the listing did not name the selected model');
assert.ok(requests[0].url.includes('autoload=true'),
  'the listing withheld autoload, so discovery depended on the router default');
// The broker is the only issuer of a grant, so the property a model could
// author is removed before the definition reaches the request body.
for (const tool of webTools) {
  assert.ok(!('authorization' in tool.function.parameters.properties),
    'a web tool definition offered the model the authorization property');
  assert.ok(!tool.function.parameters.required.includes('authorization'),
    'a web tool definition required the authorization property');
}

// A tool-free registry id answers 403 feature_disabled, which leaves the turn
// carrying no web tool rather than raising at the caller. The retry is what
// separates a build serving no tool route from a transient failure, so the
// tool-free id spends both attempts and still yields an empty list.
requests.length = 0;
alerts.length = 0;
nextResponse = () => jsonResponse({ error: 'feature_disabled' }, 403);
selectModel(toolFreeModel, 2);
// The list comes from the page realm, so its prototype is that context's
// Array and a deep-equality comparison against a harness literal would fail on
// the prototype rather than on the contents.
const toolFreeTools = await resolve(toolFreeModel, 2);
assert.equal(toolFreeTools.length, 0,
  'a tool-free model offered the turn a web tool');
assert.equal(alerts.length, 0,
  'a tool-free listing reached the operator as an alert');
assert.equal(requests.length, 2,
  'the tool-free listing spent other than its one retry');
for (const request of requests) {
  assert.ok(request.url.includes(`model=${encodeURIComponent(toolFreeModel)}`),
    'a listing named a model other than the selected one');
}

// A refused listing writes no cache, so a later turn on that same id asks
// again rather than being held at empty until a reselect.
requests.length = 0;
const toolFreeAgain = await resolve(toolFreeModel, 2);
assert.equal(toolFreeAgain.length, 0,
  'a repeated tool-free listing composed a tool');
assert.equal(requests.length, 2,
  'a refused listing was cached, so a recovered endpoint would stay unread');

// Selecting back to the web profile re-resolves rather than serving the
// tool-free answer, because the cache is keyed by model and generation.
requests.length = 0;
nextResponse = () => jsonResponse(webListing);
selectModel(webProfile, 3);
const webToolsAgain = await resolve(webProfile, 3);
assert.equal(webToolsAgain.length, 2,
  'reselecting the web profile lost its tools');
assert.equal(requests.length, 1,
  'reselecting the web profile did not re-read the listing');

// The listing a model actually answered is cached for that model and
// generation, so a second turn on it makes no request at all.
requests.length = 0;
nextResponse = null;
const webToolsCached = await resolve(webProfile, 3);
assert.equal(webToolsCached.length, 2,
  'a successful listing was not cached for the turn that follows it');
assert.equal(requests.length, 0,
  'a cached listing was re-read');

// A body that is not an array leaves the caller unable to read a web tool, so
// it takes the empty path rather than reaching the turn as a crash.
requests.length = 0;
nextResponse = () => jsonResponse({ tools: webListing });
selectModel(webProfile, 4);
const malformed = await resolve(webProfile, 4);
assert.equal(malformed.length, 0,
  'a listing body that is not an array reached the turn as a tool');

// A listing naming a tool outside the web set contributes nothing, so an image
// section on the same router offers the web turn no surface of its own.
requests.length = 0;
nextResponse = () => jsonResponse([listedTool('image_generate_image')]);
selectModel(webProfile, 5);
const foreignTools = await resolve(webProfile, 5);
assert.equal(foreignTools.length, 0,
  'a listing outside the web tool set composed a web tool');

console.log('test-fallback-webui-mixed-roster: all checks passed');
