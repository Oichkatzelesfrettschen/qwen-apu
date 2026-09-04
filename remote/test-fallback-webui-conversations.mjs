#!/usr/bin/env node

// The fallback page keeps a conversation as a durable record, and this harness
// runs the page's own inline script against a fake DOM, a fake IndexedDB, a
// fake localStorage, and a deferred fetch -- the vehicle
// remote/test-fallback-webui-model-state.mjs already uses -- because the
// assertions are what the store holds and what a restore rebuilds rather than
// how a browser implements either.
//
// Four properties decide the feature. A store answers in the declared order,
// IndexedDB first and an in-memory Map where both browser stores refuse. The
// serialized record holds the transcript and the artifact digest and holds no
// grant, session secret, or API key while the page's own globals carry all
// three. A restore rebuilds `history` and refetches the artifact by digest over
// the listener's credentialed route rather than reading bytes out of the store.
// The `#/c/<id>` route selects the conversation a second page load opens.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const FIXTURE_API_KEY = 'fixture-api-key-2f0f41';
const FIXTURE_SESSION_SECRET = 'fixture-session-secret-91abcd';
const FIXTURE_GRANT = 'fixture-grant-token-77cdef';
const FIXTURE_SHA256 =
  '9f2c4b7a1d3e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8';
const ARTIFACT_ORIGIN = 'http://127.0.0.1:9711';

class FakeElement {
  constructor() {
    this.alt = '';
    this.checked = false;
    this.children = [];
    this.className = '';
    this.dataset = {};
    this.hidden = false;
    this.id = '';
    this.listeners = new Map();
    this.onclick = null;
    this.scrollHeight = 0;
    this.scrollTop = 0;
    this.src = '';
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

  // The restore path places a reasoning block ahead of the answer body, so the
  // double keeps the child order a reader would see.
  insertBefore(node, reference) {
    const position = this.children.indexOf(reference);
    if (position === -1) this.children.push(node);
    else this.children.splice(position, 0, node);
    return node;
  }

  focus() {}
}

function collectText(element) {
  // A turn renders its speaker, its badge, and its body as separate children,
  // so a whole-turn read joins them rather than reading one.
  const parts = [];
  const walk = node => {
    if (typeof node === 'string') {
      parts.push(node);
      return;
    }
    if (node.children.length) node.children.forEach(walk);
    else parts.push(node.textContent);
  };
  walk(element);
  return parts.join(' ');
}

function makeFakeIndexedDatabase() {
  /* A minimal IndexedDB over the four calls the page makes: open with one
     upgrade, getAll, get, put, and delete inside a named transaction. The
     databases map outlives one page context, so a second page load reads what
     the first one wrote, which is what the hash route test needs. */
  const databases = new Map();
  const settle = (request, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
      }
    });
    return request;
  };
  const newRequest = () => ({ result: undefined, error: null, onsuccess: null, onerror: null });
  return {
    databases,
    open(name) {
      const request = newRequest();
      const fresh = !databases.has(name);
      if (fresh) databases.set(name, new Map());
      const stores = databases.get(name);
      const database = {
        name,
        objectStoreNames: { contains: storeName => stores.has(storeName) },
        createObjectStore(storeName) {
          stores.set(storeName, new Map());
          return {};
        },
        transaction(storeName) {
          const transaction = { error: null, onabort: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), () => [...records.values()]),
              get: key => settle(newRequest(), () => records.get(key)),
              put: value => settle(newRequest(), () => {
                records.set(value.id, value);
                return value.id;
              }),
              delete: key => settle(newRequest(), () => {
                records.delete(key);
                return undefined;
              })
            };
          };
          return transaction;
        }
      };
      request.result = database;
      setImmediate(() => {
        if (fresh && request.onupgradeneeded) request.onupgradeneeded({ target: request });
        if (request.onsuccess) request.onsuccess({ target: request });
      });
      return request;
    }
  };
}

function makeFakeStorage() {
  const values = new Map();
  return {
    values,
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, String(value)); },
    removeItem(key) { values.delete(key); }
  };
}

function makeDeniedStorage() {
  return {
    getItem() { throw new Error('storage denied'); },
    setItem() { throw new Error('storage denied'); },
    removeItem() { throw new Error('storage denied'); }
  };
}

class TestUrl extends URL {}
TestUrl.createObjectURL = () => 'blob:qwen-apu/fixture';
TestUrl.revokeObjectURL = () => {};

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const testInterface = `
globalThis.webuiConversationTest = {
  async storeName() {
    return (await conversationStore()).name;
  },
  state() {
    return {
      conversationId,
      conversationTitle,
      messages: JSON.parse(JSON.stringify(conversationMessages)),
      history: JSON.parse(JSON.stringify(history)),
      toolCallSequence,
      requestModel,
    };
  },
  secretsHeld() {
    return { apiKey, brokerSessionSecret };
  },
  async runFixtureTurn(fixture) {
    // The page's own credentials are live while the record is written, which is
    // what makes their absence from the store a property of the projection
    // rather than of an empty page.
    apiKey = fixture.apiKey;
    brokerSessionSecret = fixture.sessionSecret;
    history.push({ role: 'user', content: fixture.userContent });
    rememberUserMessage(fixture.userContent, fixture.userShown);
    const message = {
      role: 'assistant',
      content: fixture.assistantContent,
      tool_calls: [{
        id: 'call_0',
        type: 'function',
        function: { name: IMAGE_TOOL_NAME, arguments: fixture.callArguments },
      }],
    };
    history.push(message);
    rememberAssistantMessage(message, fixture.servedModel, fixture.reasoning);
    // imageRequestParams() is what carries the grant to the served path, so it
    // is built here exactly as the dispatch path builds it and never handed to
    // the record.
    const params = imageRequestParams(fixture.fields, fixture.grant);
    if (params.authorization !== fixture.grant) throw new Error('the grant did not reach the params');
    rememberArtifact(fixture.fields, fixture.result);
    history.push({
      role: 'tool', tool_call_id: 'call_0', name: IMAGE_TOOL_NAME,
      content: fixture.toolContent,
    });
    rememberToolMessage('call_0', IMAGE_TOOL_NAME, fixture.toolContent);
    await saveConversation();
    return conversationId;
  },
  async appendFollowUp(text, servedModel) {
    // The round that reads the tool result is a second assistant message of the
    // same turn, which is what the restore has to group under one speaker.
    const message = { role: 'assistant', content: text };
    history.push(message);
    rememberAssistantMessage(message, servedModel, '');
    await saveConversation();
  },
  async list() {
    return (await conversationStore()).list();
  },
  read(id) {
    return readConversationRecord(id);
  },
  setBusy(value) { busy = value; },
  restoredBlobUrls() { return restoredArtifactBlobUrls.size; },
  startNewConversation,
  switchConversation,
  renameConversation,
  deleteConversation,
  renderConversationList,
  initConversations,
  transcript() {
    return logEl.children.map(child => globalThis.collectText(child));
  },
  panelRows() {
    return document.querySelector('#conversation-list').children
      .map(child => ({ className: child.className, text: child.textContent }));
  },
  clickNew() {
    document.querySelector('#conversation-new').onclick();
  },
  fireHashChange() {
    const listener = globalThis.hashListeners.get('hashchange');
    if (!listener) throw new Error('the page registered no hashchange listener');
    listener();
  },
  sendUserTurn(text) {
    // Drives the page's own send() path rather than the fixture's manual
    // rememberUserMessage()+saveConversation() pair, so the assertion covers
    // what a keystroke and a click actually run. The call is fired and left
    // unawaited: send() suspends on the chat/completions fetch this harness
    // leaves pending, which is the interruption the test reads the store
    // across.
    $('#input').value = text;
    $('#send').onclick().catch(error => { console.error('sendUserTurn failed', error); });
  },
};
`;

const sharedIndexedDatabase = makeFakeIndexedDatabase();

function newPage({ indexedDatabase, localStorage, sessionStorage, hash = '' }) {
  const elements = new Map();
  const document = {
    createElement() { return new FakeElement(); },
    querySelector(selector) {
      if (!elements.has(selector)) elements.set(selector, new FakeElement());
      return elements.get(selector);
    }
  };
  const pendingRequests = [];
  const hashListeners = new Map();
  const location = { href: `http://127.0.0.1:8080/${hash}`, hash, hostname: '127.0.0.1', origin: 'http://127.0.0.1:8080' };
  const context = {
    AbortController,
    URL: TestUrl,
    clearTimeout,
    collectText,
    console,
    crypto: { getRandomValues: array => { array[0] = 42; return array; } },
    document,
    performance: { now: () => Date.now() },
    hashListeners,
    fetch(url, options = {}) {
      return new Promise((resolve, reject) => {
        pendingRequests.push({ url, options, resolve, reject });
      });
    },
    setTimeout,
    window: {
      addEventListener(eventName, listener) { hashListeners.set(eventName, listener); },
      alert() {},
      localStorage,
      location,
      prompt: () => 'renamed conversation',
      sessionStorage
    }
  };
  if (indexedDatabase) context.indexedDB = indexedDatabase;
  const browserContext = vm.createContext(context);
  vm.runInContext(`${inlineScript[1]}\n${testInterface}`, browserContext,
    { filename: webuiPath.pathname });
  return { api: browserContext.webuiConversationTest, elements, pendingRequests, location, document };
}

async function flushPromises(turns = 40) {
  for (let turn = 0; turn < turns; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

function takeRequest(pendingRequests, predicate, description) {
  const index = pendingRequests.findIndex(predicate);
  assert.notEqual(index, -1, `missing request: ${description}`);
  return pendingRequests.splice(index, 1)[0];
}

function jsonResponse(payload, status = 200) {
  return { ok: status >= 200 && status < 300, status, async json() { return payload; } };
}

const fixture = {
  apiKey: FIXTURE_API_KEY,
  sessionSecret: FIXTURE_SESSION_SECRET,
  grant: FIXTURE_GRANT,
  userContent: 'draw a fox in a snowy field',
  userShown: 'draw a fox in a snowy field',
  assistantContent: 'Here is the fox.',
  reasoning: 'the request names one subject',
  servedModel: 'image-capable',
  callArguments: JSON.stringify({
    prompt: 'a fox in a snowy field', profile_id: 'sdxs-512-arm-a',
    width: 512, height: 512, steps: 4
  }),
  fields: {
    prompt: 'a fox in a snowy field', negative_prompt: 'blurry',
    seed: 785835124, width: 512, height: 512, steps: 4, profile: 'sdxs-512-arm-a'
  },
  result: {
    sha256: FIXTURE_SHA256,
    provenanceUrl: `/artifacts/${FIXTURE_SHA256}.json`
  },
  toolContent:
    `Image generated: sha256 ${FIXTURE_SHA256}, provenance /artifacts/${FIXTURE_SHA256}.json.`
};

async function answerBoot(page) {
  await flushPromises();
  const featureRoster = takeRequest(page.pendingRequests,
    request => request.url === './roster.json', 'feature roster');
  featureRoster.resolve(jsonResponse(null, 404));
  const roster = takeRequest(page.pendingRequests,
    request => request.url === './v1/models', 'model roster');
  roster.resolve(jsonResponse({ data: [{ id: 'image-capable' }] }));
  await flushPromises();
  const props = takeRequest(page.pendingRequests,
    request => String(request.url).startsWith('./props?model='), 'model properties');
  props.resolve(jsonResponse({ n_ctx: 4096 }));
  await flushPromises();
}

// ---- the IndexedDB store, the projection, and a restore --------------------

const first = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(first);
first.document.querySelector('#artifact-origin').value = ARTIFACT_ORIGIN;

assert.equal(await first.api.storeName(), 'indexeddb',
  'the page did not select IndexedDB where the browser offers it');

const savedId = await first.api.runFixtureTurn(fixture);
await flushPromises();
assert.ok(savedId, 'the fixture turn produced no conversation id');

const FOLLOW_UP_TEXT = 'The fox stands in fresh snow.';
await first.api.appendFollowUp(FOLLOW_UP_TEXT, 'image-capable');
await flushPromises();

const savedRecord = await first.api.read(savedId);
assert.ok(savedRecord, 'the store holds no record for the saved conversation');
const serialized = JSON.stringify(savedRecord);

// The credentials are live on the page at this moment and absent from the
// record, which is the projection rather than an empty page.
const held = first.api.secretsHeld();
assert.equal(held.apiKey, FIXTURE_API_KEY);
assert.equal(held.brokerSessionSecret, FIXTURE_SESSION_SECRET);
for (const secret of [FIXTURE_API_KEY, FIXTURE_SESSION_SECRET, FIXTURE_GRANT]) {
  assert.equal(serialized.includes(secret), false,
    `the serialized conversation carries ${secret}`);
}
assert.equal(serialized.includes('authorization'), false,
  'the serialized conversation carries an authorization field');

assert.equal(savedRecord.messages.length, 4);
assert.equal(savedRecord.messages[0].role, 'user');
assert.equal(savedRecord.messages[1].role, 'assistant');
assert.equal(savedRecord.messages[3].content, FOLLOW_UP_TEXT);
assert.equal(savedRecord.messages[1].model, 'image-capable',
  'the record does not name the model that answered');
assert.equal(savedRecord.messages[2].role, 'tool');
assert.equal(savedRecord.messages[1].artifacts.length, 1);
assert.equal(savedRecord.messages[1].artifacts[0].sha256, FIXTURE_SHA256);
assert.equal(savedRecord.messages[1].artifacts[0].provenanceUrl,
  `/artifacts/${FIXTURE_SHA256}.json`);
assert.equal(savedRecord.messages[1].artifacts[0].seed, 785835124);
assert.equal(savedRecord.title, 'draw a fox in a snowy field');

// A new conversation leaves the record and empties the live transcript.
first.api.clickNew();
await flushPromises();
const opened = first.api.state();
assert.notEqual(opened.conversationId, savedId);
assert.equal(opened.history.length, 0);
assert.equal(first.api.transcript().length, 0);

// Switching back rebuilds `history` and refetches the artifact by digest.
await first.api.switchConversation(savedId);
await flushPromises();
const restored = first.api.state();
assert.equal(restored.conversationId, savedId);
assert.equal(restored.history.length, 4);
assert.equal(restored.history[0].role, 'user');
assert.equal(restored.history[1].tool_calls[0].id, 'call_0');
assert.equal(restored.history[2].role, 'tool');
assert.equal(restored.history[3].content, FOLLOW_UP_TEXT);
assert.equal(restored.toolCallSequence, 1,
  'a restored conversation reuses a call id an earlier message answered');
assert.equal(first.location.hash, `#/c/${savedId}`,
  'switching a conversation did not route to it');

const artifactRequest = takeRequest(first.pendingRequests,
  request => String(request.url) === `${ARTIFACT_ORIGIN}/artifacts/${FIXTURE_SHA256}.png`,
  'the restored artifact refetch by digest');
assert.equal(artifactRequest.options.headers.Authorization, `Bearer ${FIXTURE_API_KEY}`,
  'the restored artifact read carried no bearer');
artifactRequest.resolve({
  ok: true, status: 200, async blob() { return { size: 4 }; }
});
await flushPromises();

// The badge reads the roster once, on the first assistant message a transcript
// renders, and decorates a served id the roster carries. A launch that serves
// no roster leaves the id alone, which is what every other page here shows by
// leaving this request unanswered.
const rosterRequest = takeRequest(first.pendingRequests,
  request => String(request.url) === './roster.json', 'the feature roster read');
rosterRequest.resolve(jsonResponse({
  schema: 'qwen-feature-roster/1',
  features: [{ feature: 'text-chat', scope: 'model' }],
  models: [{ id: 'image-capable', tier: 'production', tags: ['production'], features: [] }]
}));
await flushPromises();
assert.equal(
  first.pendingRequests.filter(request => String(request.url) === './roster.json').length, 0,
  'the badge read the roster more than once');

const restoredTranscript = first.api.transcript();
assert.equal(restoredTranscript.length, 2, 'the restore rendered no user and assistant turn');
assert.ok(restoredTranscript[0].includes('draw a fox in a snowy field'));
assert.ok(restoredTranscript[1].includes('Here is the fox.'));
assert.ok(restoredTranscript[1].includes('image-capable'),
  'the restored assistant turn names no served model');
assert.ok(restoredTranscript[1].includes('production'),
  'the restored assistant turn carries no tier badge for a rostered model');
assert.ok(restoredTranscript[1].includes(FIXTURE_SHA256),
  'the restored assistant turn carries no artifact digest');
// The image and the answer the model wrote after reading the tool result share
// one turn, and the answer follows the artifact inside it.
assert.ok(restoredTranscript[1].includes(FOLLOW_UP_TEXT),
  'the restored turn holds no follow-up round');
assert.ok(
  restoredTranscript[1].indexOf(FOLLOW_UP_TEXT) >
    restoredTranscript[1].indexOf(FIXTURE_SHA256),
  'the follow-up round renders ahead of the artifact it describes');

// A restored card holds one blob URL the reset owns, because it carries no
// remove button of its own to revoke it.
assert.equal(first.api.restoredBlobUrls(), 1,
  'the restored artifact registered no blob URL for the reset to release');

// A route change during a streaming turn is refused, and the address bar is
// written back to what the page displays rather than left naming a conversation
// it never opened.
first.api.setBusy(true);
const busyOutcome = await first.api.switchConversation('someotherid');
first.api.setBusy(false);
assert.equal(busyOutcome, false, 'a switch during a turn was admitted');
assert.equal(first.api.state().conversationId, savedId);
assert.equal(first.location.hash, `#/c/${savedId}`,
  'a refused switch left the route naming a conversation the page did not open');

// Rename and delete move the panel.
await first.api.renameConversation(savedId);
await flushPromises();
let rows = first.api.panelRows();
assert.equal(rows.length, 1);
assert.ok(rows[0].text.includes('renamed conversation'));
assert.ok(rows[0].className.includes('selected'));

await first.api.deleteConversation(savedId);
await flushPromises();
rows = first.api.panelRows();
assert.equal(rows.length, 1);
assert.equal(rows[0].text, 'this store holds no saved conversation yet');
assert.equal(first.api.restoredBlobUrls(), 0,
  'the conversation that left the log kept its restored blob URLs');

// ---- the hash route selects a conversation on a second load ----------------

const routedSource = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(routedSource);
const routedId = await routedSource.api.runFixtureTurn(fixture);
await flushPromises();

const routedPage = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: `#/c/${routedId}`
});
await answerBoot(routedPage);
await flushPromises();
assert.equal(routedPage.api.state().conversationId, routedId,
  'the hash route did not select its conversation on load');
assert.equal(routedPage.api.state().history.length, 3,
  'the routed conversation restored no transcript');

// A route change inside one page switches the conversation.
const secondId = routedPage.api.startNewConversation();
await flushPromises();
assert.notEqual(secondId, routedId);
routedPage.location.hash = `#/c/${routedId}`;
routedPage.api.fireHashChange();
await flushPromises();
assert.equal(routedPage.api.state().conversationId, routedId,
  'a hashchange did not switch the conversation');

// A route naming no stored conversation opens an empty one rather than failing.
const unroutedPage = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: '#/c/absent0000'
});
await answerBoot(unroutedPage);
await flushPromises();
assert.equal(unroutedPage.api.state().history.length, 0);
assert.ok(unroutedPage.api.state().conversationId,
  'an unrouted load opened no conversation');

// ---- localStorage carries the record where IndexedDB is absent -------------

const browserStorage = makeFakeStorage();
const localPage = newPage({
  indexedDatabase: null,
  localStorage: browserStorage,
  sessionStorage: makeFakeStorage()
});
await answerBoot(localPage);
assert.equal(await localPage.api.storeName(), 'localstorage');
const localId = await localPage.api.runFixtureTurn(fixture);
await flushPromises();
const rawStorage = [...browserStorage.values.entries()]
  .map(([key, value]) => `${key}=${value}`).join('\n');
assert.ok(rawStorage.includes(localId), 'localStorage holds no record for the conversation');
assert.ok(rawStorage.includes(FIXTURE_SHA256), 'the stored record carries no artifact digest');
for (const secret of [FIXTURE_API_KEY, FIXTURE_SESSION_SECRET, FIXTURE_GRANT]) {
  assert.equal(rawStorage.includes(secret), false, `localStorage carries ${secret}`);
}

// ---- both browser stores denied leaves the page on its own memory ----------

const deniedPage = newPage({
  indexedDatabase: null,
  localStorage: makeDeniedStorage(),
  sessionStorage: makeDeniedStorage()
});
await answerBoot(deniedPage);
assert.equal(await deniedPage.api.storeName(), 'memory',
  'a denied browser store did not fall through to memory');
const memoryId = await deniedPage.api.runFixtureTurn(fixture);
await flushPromises();
const memoryList = await deniedPage.api.list();
assert.equal(memoryList.length, 1);
assert.equal(memoryList[0].id, memoryId);
deniedPage.api.clickNew();
await flushPromises();
assert.equal(deniedPage.api.state().history.length, 0);
await deniedPage.api.switchConversation(memoryId);
await flushPromises();
assert.equal(deniedPage.api.state().history.length, 3,
  'the memory store did not restore its own conversation');

// A second page load under the same denial starts empty, which is what a store
// that outlives nothing means.
const reloadedDeniedPage = newPage({
  indexedDatabase: null,
  localStorage: makeDeniedStorage(),
  sessionStorage: makeDeniedStorage()
});
await answerBoot(reloadedDeniedPage);
await flushPromises();
assert.equal((await reloadedDeniedPage.api.list()).length, 0);
assert.equal(reloadedDeniedPage.api.state().history.length, 0);

// ---- a user turn persists ahead of the assistant's completion --------------

const interruptedPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(interruptedPage);
const INTERRUPTED_TEXT = 'what does the chart on page 4 show';
interruptedPage.api.sendUserTurn(INTERRUPTED_TEXT);
await flushPromises();
const interruptedId = interruptedPage.api.state().conversationId;
assert.ok(interruptedId, 'sending a turn opened no conversation');
takeRequest(interruptedPage.pendingRequests,
  request => request.url === './v1/chat/completions',
  'the chat completion the turn is still awaiting');
const interruptedRecord = await interruptedPage.api.read(interruptedId);
assert.ok(interruptedRecord,
  'a reload before the assistant answered lost the whole conversation');
assert.equal(interruptedRecord.messages.length, 1,
  'the user turn did not persist ahead of the awaited completion');
assert.equal(interruptedRecord.messages[0].role, 'user');
assert.equal(interruptedRecord.messages[0].content, INTERRUPTED_TEXT,
  'the persisted turn does not carry what was sent');

// ---- store selection proves a write, not only a list ----------------------

function makeWriteRefusingIndexedDatabase() {
  /* Answers open, getAll, and get, and rejects every put -- the shape a quota
     or a private-browsing policy leaves: the database opens and reads, and
     every write throws. A store selection that trusts list() alone stops
     here; one that also proves a write falls through to localStorage. */
  const databases = new Map();
  const settle = (request, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
      }
    });
    return request;
  };
  const fail = request => {
    setImmediate(() => {
      request.error = new Error('write refused');
      if (request.onerror) request.onerror({ target: request });
    });
    return request;
  };
  const newRequest = () => ({ result: undefined, error: null, onsuccess: null, onerror: null });
  return {
    databases,
    open(name) {
      const request = newRequest();
      const fresh = !databases.has(name);
      if (fresh) databases.set(name, new Map());
      const stores = databases.get(name);
      const database = {
        name,
        objectStoreNames: { contains: storeName => stores.has(storeName) },
        createObjectStore(storeName) {
          stores.set(storeName, new Map());
          return {};
        },
        transaction(storeName) {
          const transaction = { error: null, onabort: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), () => [...records.values()]),
              get: key => settle(newRequest(), () => records.get(key)),
              put: () => fail(newRequest()),
              delete: () => fail(newRequest())
            };
          };
          return transaction;
        }
      };
      request.result = database;
      setImmediate(() => {
        if (fresh && request.onupgradeneeded) request.onupgradeneeded({ target: request });
        if (request.onsuccess) request.onsuccess({ target: request });
      });
      return request;
    }
  };
}

const writeRefusingPage = newPage({
  indexedDatabase: makeWriteRefusingIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(writeRefusingPage);
assert.equal(await writeRefusingPage.api.storeName(), 'localstorage',
  'a database that opens and lists but refuses every write stayed selected on IndexedDB');

// ---- a route naming an id no store answers for is replaced -----------------

const staleHashPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: '#/c/absent0000'
});
await answerBoot(staleHashPage);
await flushPromises();
const staleOpenedId = staleHashPage.api.state().conversationId;
assert.ok(staleOpenedId, 'an unresolved routed load opened no conversation');
assert.equal(staleHashPage.location.hash, `#/c/${staleOpenedId}`,
  'a stale route was left naming the absent conversation instead of the one now open');

// ---- a user action during boot wins over the pending route resolution ------

const raceSourceDatabase = makeFakeIndexedDatabase();
const raceSource = newPage({
  indexedDatabase: raceSourceDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(raceSource);
const racedRoutedId = await raceSource.api.runFixtureTurn(fixture);
await flushPromises();

const racePage = newPage({
  indexedDatabase: raceSourceDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: `#/c/${racedRoutedId}`
});
// initConversations() ran on load and is still awaiting the IndexedDB open
// (the fake settles it on setImmediate, not synchronously), so this click
// lands ahead of that resolution -- exactly the race a user opening a fresh
// tab and immediately pressing New meets.
racePage.api.clickNew();
const racedNewId = racePage.api.state().conversationId;
assert.ok(racedNewId, 'clicking New during boot opened no conversation');
assert.notEqual(racedNewId, racedRoutedId);
await flushPromises();
assert.equal(racePage.api.state().conversationId, racedNewId,
  'the pending route resolution overwrote the conversation the user had already opened');
assert.equal(racePage.api.state().history.length, 0,
  'the pending route resolution restored a transcript into the conversation the user opened');
assert.equal(racePage.location.hash, `#/c/${racedNewId}`,
  'the address bar still names the conversation the pending route resolution opened');

// ---- a write failure after selection falls through to the next store ------

function makeQuotaIndexedDatabase() {
  /* Answers every write until `state.failWrites` is set, the shape a quota
     reached mid-session leaves: the write-verified probe at store selection
     passes on an empty database, and every real write past that point fails
     the same way a later probe would, so a retry has to fall through to the
     next store rather than reselecting the one that just failed. Built from
     scratch rather than wrapping makeFakeIndexedDatabase(), since patching an
     already-open database's transaction() after the fact races the app's own
     use of it across the fake's setImmediate settling. */
  const databases = new Map();
  const state = { failWrites: false };
  const settle = (request, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
      }
    });
    return request;
  };
  const fail = request => {
    setImmediate(() => {
      request.error = new Error('quota exceeded');
      if (request.onerror) request.onerror({ target: request });
    });
    return request;
  };
  const newRequest = () => ({ result: undefined, error: null, onsuccess: null, onerror: null });
  return {
    state,
    databases,
    open(name) {
      const request = newRequest();
      const fresh = !databases.has(name);
      if (fresh) databases.set(name, new Map());
      const stores = databases.get(name);
      const database = {
        name,
        objectStoreNames: { contains: storeName => stores.has(storeName) },
        createObjectStore(storeName) {
          stores.set(storeName, new Map());
          return {};
        },
        transaction(storeName) {
          const transaction = { error: null, onabort: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), () => [...records.values()]),
              get: key => settle(newRequest(), () => records.get(key)),
              put: value => state.failWrites
                ? fail(newRequest())
                : settle(newRequest(), () => { records.set(value.id, value); return value.id; }),
              delete: key => state.failWrites
                ? fail(newRequest())
                : settle(newRequest(), () => { records.delete(key); return undefined; })
            };
          };
          return transaction;
        }
      };
      request.result = database;
      setImmediate(() => {
        if (fresh && request.onupgradeneeded) request.onupgradeneeded({ target: request });
        if (request.onsuccess) request.onsuccess({ target: request });
      });
      return request;
    }
  };
}

const quotaDatabase = makeQuotaIndexedDatabase();
const quotaPage = newPage({
  indexedDatabase: quotaDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(quotaPage);
assert.equal(await quotaPage.api.storeName(), 'indexeddb',
  'the quota fixture did not start selected on IndexedDB');
quotaDatabase.state.failWrites = true;
const quotaId = await quotaPage.api.runFixtureTurn(fixture);
await flushPromises();
assert.equal(await quotaPage.api.storeName(), 'localstorage',
  'a write failure after selection left the page pinned to the backend that refuses every save');
const quotaRecord = await quotaPage.api.read(quotaId);
assert.ok(quotaRecord,
  'the conversation was lost rather than falling through to the next store');
assert.equal(quotaRecord.messages.length, 3);

console.log('fallback_webui_conversations=accepted');
