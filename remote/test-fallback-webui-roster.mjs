#!/usr/bin/env node

// The fallback page decorates the ids GET /v1/models returned with the tier and
// the feature statuses webui/roster.json carries, and the roster contributes no
// id of its own. This harness runs the page's own inline script against a fake
// DOM and a deferred fetch, the vehicle remote/test-fallback-webui-model-state.mjs
// already uses, because the assertion is what the picker option and the matrix
// cell render rather than which request the page made.
//
// Three properties decide the feature. A served id the roster carries renders
// its tier badge, its option tags, and one matrix row. A roster id the listener
// withheld renders nothing, so the decoration can never route a request. A
// served id the roster omits keeps its option and its routing, so an
// incompletely seeded ledger costs a matrix row rather than a model.

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

const pendingRequests = [];
function deferredFetch(url, options = {}) {
  return new Promise((resolve, reject) => {
    pendingRequests.push({ url, options, resolve, reject });
  });
}

function takeRequest(predicate, description) {
  const requestIndex = pendingRequests.findIndex(predicate);
  assert.notEqual(requestIndex, -1, `missing request: ${description}`);
  return pendingRequests.splice(requestIndex, 1)[0];
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

function newPage() {
  elements.clear();
  pendingRequests.length = 0;
  const browserContext = vm.createContext({
    console,
    document,
    fetch: deferredFetch,
    window: {
      alert() {},
      localStorage: deniedStorage,
      sessionStorage: deniedStorage,
    },
  });
  vm.runInContext(inlineScript[1], browserContext, { filename: webuiPath.pathname });
  return browserContext;
}

const servedProduction = 'qwen38-2b-distill';
const servedCandidate = 'qwen35-2b';
const servedUnrostered = 'unrostered-section';
const withheldByListener = 'qwen38-4b-distill';

const fixtureRoster = {
  schema: 'qwen-feature-roster/1',
  features: [
    { feature: 'text-chat', scope: 'model' },
    { feature: 'vision', scope: 'model' },
    { feature: 'web-search', scope: 'web-profile' },
  ],
  models: [
    {
      id: servedProduction,
      role: 'fast-text',
      tier: 'production',
      class_rank: 1,
      tags: ['production'],
      features: [
        {
          feature: 'text-chat',
          status: 'production',
          evidence: 'evidence/model-admission/roster-quality-sweep.md',
          note: 'graded 40 of 55 with thinking off',
        },
        { feature: 'vision', status: 'unsupported', evidence: '-', note: '-' },
      ],
    },
    {
      id: servedCandidate,
      role: 'compact-vision',
      tier: 'candidate',
      class_rank: 1,
      tags: ['candidate', 'vision', 'experimental'],
      features: [
        {
          feature: 'vision',
          status: 'candidate',
          evidence: 'evidence/depth-validation-32k-projector/qwen35-2b/',
          note: 'the revision-matched projector loads',
        },
      ],
    },
    {
      id: withheldByListener,
      role: 'balanced-text',
      tier: 'production',
      class_rank: 3,
      tags: ['production'],
      features: [
        {
          feature: 'text-chat',
          status: 'production',
          evidence: 'evidence/model-admission/roster-quality-sweep.md',
          note: 'graded 47 of 55 with thinking off',
        },
      ],
    },
  ],
  draft_pairs: [],
  web_profiles: [],
  image_profiles: [],
};

async function bootPage(rosterAnswer, servedIds) {
  newPage();
  const rosterRequest = takeRequest(
    request => request.url === './roster.json', 'feature roster');
  rosterRequest.resolve(rosterAnswer);
  const modelsRequest = takeRequest(
    request => request.url === './v1/models', 'model roster');
  modelsRequest.resolve(jsonResponse({ data: servedIds.map(id => ({ id })) }));
  await flushPromises();
  for (const servedId of servedIds) {
    if (servedIds.length === 1) break;
    const probe = takeRequest(
      request => request.url === `./tools?model=${encodeURIComponent(servedId)}`,
      `tool probe for ${servedId}`);
    probe.resolve(jsonResponse([{
      tool: 'web_search_exa',
      definition: { function: { name: 'web_search_exa' } },
    }], 200));
    await flushPromises();
  }
  // The remaining props and tokenize traffic belongs to the selected model and
  // says nothing about the roster, so it is drained rather than asserted.
  while (pendingRequests.length) {
    pendingRequests.shift().resolve(jsonResponse({ n_ctx: 8192 }));
    await flushPromises();
  }
}

function optionLabels() {
  return elements.get('#model-picker').children.map(option => option.textContent);
}

function matrixRows() {
  const container = elements.get('#roster-matrix-body');
  assert.equal(container.children.length, 1, 'the matrix holds one table');
  const table = container.children[0];
  return table.children.map(row => row.children.map(cell => ({
    text: cell.textContent,
    className: cell.className,
    title: cell.title,
  })));
}

// A roster served beside the page decorates every id the listener returned and
// contributes none of its own.
await bootPage(jsonResponse(fixtureRoster),
  [servedProduction, servedCandidate, servedUnrostered]);

assert.deepEqual(optionLabels(), [
  `${servedProduction} [production]`,
  `${servedCandidate} [candidate vision experimental]`,
  servedUnrostered,
], 'the picker labels carry the roster tags and leave an unrostered id bare');

const badge = elements.get('#model-tier');
assert.equal(badge.textContent, 'production', 'the badge names the selected tier');
assert.equal(badge.className, 'tier-badge production');
assert.equal(badge.hidden, false);

const panel = elements.get('#roster-matrix');
assert.equal(panel.hidden, false, 'the matrix panel opens where the roster decorates a row');
assert.match(elements.get('#roster-summary').textContent,
  /feature support for 2 of 3 routable models/);

const rows = matrixRows();
assert.deepEqual(rows[0].map(cell => cell.text), ['model', 'text-chat', 'vision'],
  'the header names the model-scope features alone, so web-search stays out');
assert.equal(rows.length, 3, 'the matrix holds a header and one row per rostered served id');
assert.equal(rows[1][0].text, `${servedProduction} (production)`);
assert.equal(rows[1][1].className, 'production');
assert.match(rows[1][1].text, /^production/);
assert.match(rows[1][1].text, /evidence\/model-admission\/roster-quality-sweep\.md/);
assert.equal(rows[1][1].title, 'graded 40 of 55 with thinking off');
assert.equal(rows[1][2].className, 'unsupported', 'an unsupported claim renders its own class');
assert.equal(rows[1][2].text, 'unsupported', 'an evidence of - adds no path to the cell');
assert.equal(rows[2][0].text, `${servedCandidate} (candidate)`);
assert.equal(rows[2][1].className, 'unclaimed',
  'a feature the row claims nothing for reads unclaimed');
assert.equal(rows[2][2].className, 'candidate');
assert.ok(rows.every(row => row.every(cell => !cell.text.includes(withheldByListener))),
  'a roster id the listener withheld reaches no matrix row');
assert.ok(!optionLabels().some(label => label.includes(withheldByListener)),
  'a roster id the listener withheld reaches no picker option');

// An absent roster leaves the picker routing and both decorations off.
await bootPage(jsonResponse({ error: 'not found' }, 404),
  [servedProduction, servedCandidate]);
assert.deepEqual(optionLabels(), [servedProduction, servedCandidate],
  'an absent roster leaves every option at its routing id');
assert.equal(elements.get('#model-picker').hidden, false,
  'an absent roster leaves the picker visible');
assert.equal(elements.get('#model-tier').hidden, true);
assert.equal(elements.get('#roster-matrix').hidden, true);

// A roster of another schema is read as absent rather than rendered.
await bootPage(jsonResponse({ schema: 'qwen-feature-roster/99', models: [], features: [] }),
  [servedProduction, servedCandidate]);
assert.deepEqual(optionLabels(), [servedProduction, servedCandidate]);
assert.equal(elements.get('#roster-matrix').hidden, true);

// A transport failure on the roster is read as absent for the same reason.
newPage();
const failedRoster = takeRequest(
  request => request.url === './roster.json', 'feature roster');
failedRoster.reject(new Error('roster unavailable'));
const modelsAfterFailure = takeRequest(
  request => request.url === './v1/models', 'model roster');
modelsAfterFailure.resolve(jsonResponse({ data: [{ id: servedProduction }] }));
await flushPromises();
while (pendingRequests.length) {
  pendingRequests.shift().resolve(jsonResponse({ n_ctx: 8192 }));
  await flushPromises();
}
assert.deepEqual(optionLabels(), [servedProduction],
  'a roster transport failure leaves the picker routing');
assert.equal(elements.get('#roster-matrix').hidden, true);

console.log('fallback_webui_roster=accepted');
