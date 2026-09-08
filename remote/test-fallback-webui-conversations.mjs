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

  // resolveVisionModel() reads $('#model-picker').options the way a real
  // HTMLOptionsCollection mirrors the <option> children boot() appended.
  get options() {
    return this.children;
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

  // The remove-image button removes the card from its own container; this
  // harness does not track a parent reference, and the store update is what
  // the artifact-removal check reads.
  remove() {}

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
     the first one wrote, which is what the hash route test needs.

     A real transaction commits, and fires oncomplete, on its own task after
     every request inside it has answered -- never inside the same task as a
     request's own onsuccess. `settle()` reproduces that separation with a
     second setImmediate hop rather than firing oncomplete synchronously
     alongside onsuccess, which is what proves
     indexedDatabaseConversationStore()'s run() waits for the commit instead
     of resolving on the request alone. */
  const databases = new Map();
  const settle = (request, transaction, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
        setImmediate(() => {
          if (transaction.oncomplete) transaction.oncomplete({ target: transaction });
        });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
        setImmediate(() => {
          if (transaction.onabort) transaction.onabort({ target: transaction });
        });
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
          const transaction = { error: null, onabort: null, oncomplete: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), transaction, () => [...records.values()]),
              get: key => settle(newRequest(), transaction, () => records.get(key)),
              put: value => settle(newRequest(), transaction, () => {
                records.set(value.id, value);
                return value.id;
              }),
              delete: key => settle(newRequest(), transaction, () => {
                records.delete(key);
                return undefined;
              }),
              clear: () => settle(newRequest(), transaction, () => {
                records.clear();
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
    get length() { return values.size; },
    key(index) { return [...values.keys()][index] ?? null; },
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, String(value)); },
    removeItem(key) { values.delete(key); }
  };
}

function makeDeniedStorage() {
  return {
    get length() { throw new Error('storage denied'); },
    key() { throw new Error('storage denied'); },
    getItem() { throw new Error('storage denied'); },
    setItem() { throw new Error('storage denied'); },
    removeItem() { throw new Error('storage denied'); }
  };
}

function makeClearFailStorage() {
  const storage = makeFakeStorage();
  const removeItem = storage.removeItem.bind(storage);
  storage.removeItem = key => {
    if (key === 'qwen-apu-conversation-index') throw new Error('clear transaction failed');
    removeItem(key);
  };
  return storage;
}

// resolveConversationStore()'s own probe writes and removes one throwaway
// key ahead of any real write, so a storage whose real writes are refused
// (quota) but whose probe still answers looks selectable on every
// resolution -- the shape a real quota-exhausted localStorage takes, and
// distinct from makeDeniedStorage()'s total refusal, which the probe itself
// already catches.
const CONVERSATION_PROBE_KEY = 'qwen-apu-conversation:probe';
function makeFlakyStorage(failWrites) {
  const values = new Map();
  return {
    values,
    get length() { return values.size; },
    key(index) { return [...values.keys()][index] ?? null; },
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) {
      if (failWrites.active && key !== CONVERSATION_PROBE_KEY) {
        throw new Error('storage denied (quota)');
      }
      values.set(key, String(value));
    },
    removeItem(key) { values.delete(key); }
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
  featureRosterOnce,
  clickSetKey(value) {
    $('#api-key').value = value;
    $('#set-key').onclick();
  },
  state() {
    return {
      conversationId,
      conversationTitle,
      messages: JSON.parse(JSON.stringify(conversationMessages)),
      history: JSON.parse(JSON.stringify(history)),
      toolCallSequence,
      requestModel,
      conversationGeneration,
    };
  },
  secretsHeld() {
    return { apiKey, brokerSessionSecret };
  },
  activeEntry() { return activeAssistantEntry; },
  activeGeneration() { return activeAssistantGeneration; },
  rememberAssistantTurn(content) {
    const message = { role: 'assistant', content };
    history.push(message);
    return rememberAssistantMessage(message, 'image-capable', '');
  },
  async renderArtifactCard(fields, result, lineage) {
    const container = document.createElement('div');
    await renderImageArtifactCard(container, fields, result, lineage || null, null);
    return { card: container.children[0], container };
  },
  clickRemove(card) {
    const removeButton = card.children.find(child => child.textContent === 'remove image');
    if (!removeButton) throw new Error('the card carries no remove button');
    removeButton.onclick();
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
    rememberArtifact(activeAssistantEntry, activeAssistantGeneration, fixture.fields, fixture.result);
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
  isBusy() { return busy; },
  restoredBlobUrls() { return restoredArtifactBlobUrls.size; },
  setRequestModel(id) {
    requestModel = id;
    $('#input').value = '';
  },
  setAttachments(value) { attachments = value; renderAttached(); },
  attachmentCount() { return attachments.length; },
  setInput(text) { $('#input').value = text; },
  send,
  conversationsReadyPromise: conversationsReady,
  imageToolName: IMAGE_TOOL_NAME,
  startNewConversation,
  switchConversation,
  renameConversation,
  deleteConversation,
  deleteAllSavedConversations,
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
    TextDecoder,
    performance,
    clearTimeout,
    collectText,
    console,
    crypto: { getRandomValues: array => { array[0] = 42; return array; } },
    document,
    performance: { now: () => Date.now() },
    hashListeners,
    fetch(url, options = {}) {
      return new Promise((resolve, reject) => {
        const entry = { url, options, resolve, reject };
        pendingRequests.push(entry);
        if (options.signal) {
          const onAbort = () => {
            const index = pendingRequests.indexOf(entry);
            if (index !== -1) pendingRequests.splice(index, 1);
            const abortError = new Error('The operation was aborted.');
            abortError.name = 'AbortError';
            reject(abortError);
          };
          if (options.signal.aborted) onAbort();
          else options.signal.addEventListener('abort', onAbort, { once: true });
        }
      });
    },
    setTimeout,
    window: {
      addEventListener(eventName, listener) { hashListeners.set(eventName, listener); },
      alert() {},
      localStorage,
      location,
      prompt: () => 'renamed conversation',
      confirm: () => true,
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

function sseResponse(events) {
  /* Build a real ReadableStream a genuine streamCompletion() reads through
     resp.body.getReader(), so a turn-ordering check drives send() itself
     rather than a hand-rolled stand-in for it. */
  const encoder = new TextEncoder();
  const body = new ReadableStream({
    start(controller) {
      for (const event of events) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
      }
      controller.enqueue(encoder.encode('data: [DONE]\n\n'));
      controller.close();
    }
  });
  return { ok: true, status: 200, body, async text() { return ''; } };
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

const firstLocalStorage = makeFakeStorage();
const first = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: firstLocalStorage,
  sessionStorage: makeFakeStorage()
});
// boot() and a message badge share one memoized roster read, so this page
// resolves the single request boot() issues with the tier data a later badge
// decorates from -- a second, independent fetch here would be the two-path
// defect the memoized read exists to remove.
await flushPromises();
const bootFeatureRoster = takeRequest(first.pendingRequests,
  request => request.url === './roster.json', 'feature roster');
bootFeatureRoster.resolve(jsonResponse({
  schema: 'qwen-feature-roster/1',
  features: [{ feature: 'text-chat', scope: 'model' }],
  models: [{ id: 'image-capable', tier: 'production', tags: ['production'], features: [] }]
}));
const bootModelRoster = takeRequest(first.pendingRequests,
  request => request.url === './v1/models', 'model roster');
bootModelRoster.resolve(jsonResponse({ data: [{ id: 'image-capable' }] }));
await flushPromises();
const bootProps = takeRequest(first.pendingRequests,
  request => String(request.url).startsWith('./props?model='), 'model properties');
bootProps.resolve(jsonResponse({ n_ctx: 4096 }));
await flushPromises();
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

// The badge reads the roster once, on the first assistant message a
// transcript renders, and decorates a served id the roster carries. It reuses
// the read boot() already resolved above rather than issuing a fetch of its
// own: a restored turn's badge is the second render this page produces (the
// fixture turn's own assistant message was the first), and neither one moves
// the memoized promise off the cached tier data.
await flushPromises();
assert.equal(
  first.pendingRequests.filter(request => String(request.url) === './roster.json').length, 0,
  'the badge issued a roster fetch of its own instead of reusing boot()\'s read');

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

// Delete-all clears durable storage, opens a fresh conversation, and a reload
// cannot resurrect a record from a second tier.
const deleteAllId = await first.api.runFixtureTurn(fixture);
assert.ok(await first.api.read(deleteAllId));
const generationBeforeDeleteAll = first.api.state().conversationGeneration;
first.api.setAttachments([{name: 'private.png', kind: 'image', dataUrl: 'data:image/png;base64,private'}]);
firstLocalStorage.setItem('qwen-apu-conversation:orphan-record', '{"orphan":true}');
firstLocalStorage.setItem('qwen-apu-reasoning', 'on');
assert.equal(await first.api.deleteAllSavedConversations(), true);
assert.equal(first.api.attachmentCount(), 0, 'delete-all retained pending image bytes');
assert.equal(firstLocalStorage.getItem('qwen-apu-conversation:orphan-record'), null,
  'delete-all retained an orphaned owned record key');
assert.equal(firstLocalStorage.getItem('qwen-apu-reasoning'), 'on',
  'delete-all removed an unrelated preference');
assert.equal((await first.api.list()).length, 0);
assert.ok(first.api.state().conversationGeneration > generationBeforeDeleteAll,
  'delete-all did not invalidate an in-flight turn generation');
first.api.setAttachments([{
  name: 'fixture.png', kind: 'image', mime: 'image/png',
  dataUrl: 'data:image/png;base64,iVBORw0KGgo=', tokens: null, tokenModel: 'image-capable'
}]);
first.api.setInput('identify the object');
const multimodalSend = first.api.send();
await flushPromises();
const visionProps = takeRequest(first.pendingRequests,
  request => String(request.url).startsWith('./props?model=image-capable'),
  'vision admission for image send');
visionProps.resolve(jsonResponse({ modalities: { vision: true } }));
await flushPromises();
const multimodalCompletion = takeRequest(first.pendingRequests,
  request => request.url === './v1/chat/completions', 'multimodal completion');
const multimodalBody = JSON.parse(multimodalCompletion.options.body);
const multimodalContent = multimodalBody.messages.at(-1).content;
assert.equal(multimodalContent[0].type, 'text');
assert.deepEqual(multimodalContent[1], {
  type: 'image_url', image_url: { url: 'data:image/png;base64,iVBORw0KGgo=' }
});
multimodalCompletion.resolve(sseResponse([{ choices: [{
  delta: { content: 'a fixture' }, finish_reason: 'stop'
}] }]));
await multimodalSend;
const multimodalRecord = await first.api.read(first.api.state().conversationId);
const serializedMultimodalRecord = JSON.stringify(multimodalRecord);
assert.ok(serializedMultimodalRecord.includes('image attachment omitted from saved conversation'));
assert.ok(!serializedMultimodalRecord.includes('iVBORw0KGgo='),
  'saved history retained image bytes');
const messagesBeforeStaleAdmission = first.api.state().messages.length;
first.api.setRequestModel('image-capable');
first.api.setAttachments([{
  name: 'stale.png', kind: 'image', mime: 'image/png',
  dataUrl: 'data:image/png;base64,c3RhbGU=', tokens: null, tokenModel: 'image-capable'
}]);
first.api.setInput('stale admission');
const staleImageSend = first.api.send();
const duplicateImageSend = first.api.send();
await flushPromises();
const staleVisionProps = takeRequest(first.pendingRequests,
  request => String(request.url).startsWith('./props?model=image-capable'),
  'stale vision admission');
first.api.setRequestModel('text-only');
staleVisionProps.resolve(jsonResponse({ modalities: { vision: true } }));
await Promise.all([staleImageSend, duplicateImageSend]);
assert.equal(first.api.state().messages.length, messagesBeforeStaleAdmission,
  'a stale vision response appended a user turn');
assert.ok(!first.pendingRequests.some(request => request.url === './v1/chat/completions'),
  'a duplicate or stale image send reached chat completion');
assert.equal(await first.api.deleteAllSavedConversations(), true);
const afterDeleteAllReload = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(afterDeleteAllReload);
assert.equal((await afterDeleteAllReload.api.list()).length, 0,
  'a reload resurrected a conversation after confirmed delete-all');
const failedClearPage = newPage({
  indexedDatabase: null,
  localStorage: makeClearFailStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(failedClearPage);
assert.equal(await failedClearPage.api.deleteAllSavedConversations(), false,
  'delete-all claimed completion after a reachable tier failed');

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
     here; one that also proves a write falls through to localStorage.

     indexedDatabaseConversationStore()'s run() settles a successful read on
     transaction.oncomplete rather than the request's own onsuccess, so
     settle() fires that too, on the second setImmediate hop
     makeFakeIndexedDatabase() uses. */
  const databases = new Map();
  const settle = (request, transaction, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
        setImmediate(() => {
          if (transaction.oncomplete) transaction.oncomplete({ target: transaction });
        });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
        setImmediate(() => {
          if (transaction.onabort) transaction.onabort({ target: transaction });
        });
      }
    });
    return request;
  };
  const fail = (request, transaction) => {
    setImmediate(() => {
      request.error = new Error('write refused');
      if (request.onerror) request.onerror({ target: request });
      setImmediate(() => {
        if (transaction.onabort) transaction.onabort({ target: transaction });
      });
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
          const transaction = { error: null, onabort: null, oncomplete: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), transaction, () => [...records.values()]),
              get: key => settle(newRequest(), transaction, () => records.get(key)),
              put: () => fail(newRequest(), transaction),
              delete: () => fail(newRequest(), transaction)
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

const clickNewRaceSourceDatabase = makeFakeIndexedDatabase();
const clickNewRaceSource = newPage({
  indexedDatabase: clickNewRaceSourceDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(clickNewRaceSource);
const racedRoutedId = await clickNewRaceSource.api.runFixtureTurn(fixture);
await flushPromises();

const clickNewRacePage = newPage({
  indexedDatabase: clickNewRaceSourceDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: `#/c/${racedRoutedId}`
});
// initConversations() ran on load and is still awaiting the IndexedDB open
// (the fake settles it on setImmediate, not synchronously), so this click
// lands ahead of that resolution -- exactly the race a user opening a fresh
// tab and immediately pressing New meets.
clickNewRacePage.api.clickNew();
const racedNewId = clickNewRacePage.api.state().conversationId;
assert.ok(racedNewId, 'clicking New during boot opened no conversation');
assert.notEqual(racedNewId, racedRoutedId);
await flushPromises();
assert.equal(clickNewRacePage.api.state().conversationId, racedNewId,
  'the pending route resolution overwrote the conversation the user had already opened');
assert.equal(clickNewRacePage.api.state().history.length, 0,
  'the pending route resolution restored a transcript into the conversation the user opened');
assert.equal(clickNewRacePage.location.hash, `#/c/${racedNewId}`,
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
     use of it across the fake's setImmediate settling.

     indexedDatabaseConversationStore()'s run() settles on transaction.oncomplete
     rather than the request's own onsuccess, so a successful settle() fires
     that too, on the second setImmediate hop makeFakeIndexedDatabase() uses;
     a fail() fires onabort instead, the way a real aborted transaction would. */
  const databases = new Map();
  const state = { failWrites: false };
  const settle = (request, transaction, produce) => {
    setImmediate(() => {
      try {
        request.result = produce();
        if (request.onsuccess) request.onsuccess({ target: request });
        setImmediate(() => {
          if (transaction.oncomplete) transaction.oncomplete({ target: transaction });
        });
      } catch (error) {
        request.error = error;
        if (request.onerror) request.onerror({ target: request });
        setImmediate(() => {
          if (transaction.onabort) transaction.onabort({ target: transaction });
        });
      }
    });
    return request;
  };
  const fail = (request, transaction) => {
    setImmediate(() => {
      request.error = new Error('quota exceeded');
      if (request.onerror) request.onerror({ target: request });
      setImmediate(() => {
        if (transaction.onabort) transaction.onabort({ target: transaction });
      });
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
          const transaction = { error: null, onabort: null, oncomplete: null };
          transaction.objectStore = () => {
            const records = stores.get(storeName);
            if (!records) throw new Error(`no object store named ${storeName}`);
            return {
              getAll: () => settle(newRequest(), transaction, () => [...records.values()]),
              get: key => settle(newRequest(), transaction, () => records.get(key)),
              put: value => state.failWrites
                ? fail(newRequest(), transaction)
                : settle(newRequest(), transaction,
                    () => { records.set(value.id, value); return value.id; }),
              delete: key => state.failWrites
                ? fail(newRequest(), transaction)
                : settle(newRequest(), transaction,
                    () => { records.delete(key); return undefined; })
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

// ---- send() saves the user turn ahead of the completion, and commits a
// tool-call round only once its tool answers exist -------------------------

const turnPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(turnPage);
turnPage.api.setRequestModel('image-capable');
turnPage.api.setInput('draw something');
const sendPromise = turnPage.api.send();

// The user message is durable before the completion request is even
// answered: an HTTP error, a dropped connection, or the page closing during
// a long generation would otherwise leave it only in memory.
await flushPromises();
const turnList = await turnPage.api.list();
assert.equal(turnList.length, 1, 'the user turn was not saved ahead of the completion');
const turnId = turnList[0].id;
let turnRecord = await turnPage.api.read(turnId);
assert.equal(turnRecord.messages.length, 1);
assert.equal(turnRecord.messages[0].role, 'user');

const firstCompletion = takeRequest(turnPage.pendingRequests,
  request => request.url === './v1/chat/completions', 'the first completion request');
firstCompletion.resolve(sseResponse([{
  choices: [{
    delta: { tool_calls: [{ index: 0, function: {
      name: turnPage.api.imageToolName, arguments: '{}'
    } }] },
    finish_reason: 'tool_calls'
  }]
}]));
await flushPromises();

// send() resolves resolveImageTools() before runProposedTools can answer the
// proposed call, and that fetch is the checkpoint: the assistant message
// carrying the unresolved tool_calls must not be durable while it is
// pending, because a reload here would restore an assistant message with no
// matching tool message -- not a valid chat-completion transcript to resend.
const toolsListing = takeRequest(turnPage.pendingRequests,
  request => String(request.url).startsWith('./tools?model='), 'the image tool listing');
turnRecord = await turnPage.api.read(turnId);
assert.equal(turnRecord.messages.length, 1,
  'the assistant message with unresolved tool_calls was saved early');
toolsListing.resolve(jsonResponse([]));
await flushPromises();

// The image surface is off for this turn (the toggle default), so the call
// is answered the moment the listing resolves, with no dialog. That answer
// is what makes the round durable: the assistant message and its tool
// answer land together.
turnRecord = await turnPage.api.read(turnId);
assert.equal(turnRecord.messages.length, 3,
  'the assistant message and its tool answer did not land together');
assert.equal(turnRecord.messages[1].role, 'assistant');
assert.equal(turnRecord.messages[1].tool_calls.length, 1);
assert.equal(turnRecord.messages[2].role, 'tool');
assert.ok(turnRecord.messages[2].content.includes('did not run'),
  'the refusal message is missing from the tool answer');

// The turn ends on a second round with no further tool call.
const secondCompletion = takeRequest(turnPage.pendingRequests,
  request => request.url === './v1/chat/completions', 'the second completion request');
secondCompletion.resolve(sseResponse([{
  choices: [{ delta: { content: 'the image tool is off this turn' }, finish_reason: 'stop' }]
}]));
await sendPromise;
await flushPromises();
turnRecord = await turnPage.api.read(turnId);
assert.equal(turnRecord.messages.length, 4);
assert.equal(turnRecord.messages[3].role, 'assistant');
assert.equal(turnRecord.messages[3].content, 'the image tool is off this turn');

// ---- a write failure demotes the cached store resolution -------------------

function makeFlakyIndexedDatabase(realDatabase, { failWrites }) {
  /* Wrap a real fake IndexedDB so its object store's put() rejects while
     failWrites.active is true. list() and get() still answer normally, the
     way an open connection with a denied or quota-exhausted transaction
     would.

     The real fake's own open() assigns request.result synchronously, ahead
     of the setImmediate that fires onupgradeneeded/onsuccess, so the database
     is already there to patch in place by the time this wrapper's open()
     returns; every later reader (including the page's own
     openConversationDatabase(), which overwrites request.onsuccess) reads
     request.result and gets the same, now-patched, object. */
  return {
    open(name) {
      const request = realDatabase.open(name);
      const database = request.result;
      const originalTransaction = database.transaction.bind(database);
      database.transaction = (...args) => {
        const transaction = originalTransaction(...args);
        const originalObjectStore = transaction.objectStore.bind(transaction);
        transaction.objectStore = (...storeArgs) => {
          const store = originalObjectStore(...storeArgs);
          const originalPut = store.put.bind(store);
          store.put = value => {
            if (failWrites.active) {
              const failedRequest = { onsuccess: null, onerror: null };
              setImmediate(() => {
                failedRequest.error = new Error('the transaction was denied');
                if (failedRequest.onerror) failedRequest.onerror({ target: failedRequest });
              });
              return failedRequest;
            }
            return originalPut(value);
          };
          return store;
        };
        return transaction;
      };
      return request;
    }
  };
}

// failWrites starts false so the write-then-delete selection probe below
// still passes: the point of this arm is a write that starts refusing after
// selection, not one the probe itself would already have caught.
const failWrites = { active: false };
const flakyDatabase = makeFakeIndexedDatabase();
const flakyIndexedDatabase = makeFlakyIndexedDatabase(flakyDatabase, { failWrites });
const flakyLocalStorage = makeFakeStorage();
const flakyPage = newPage({
  indexedDatabase: flakyIndexedDatabase,
  localStorage: flakyLocalStorage,
  sessionStorage: makeFakeStorage()
});
await answerBoot(flakyPage);
assert.equal(await flakyPage.api.storeName(), 'indexeddb');
failWrites.active = true;
// The failed write is retried once against whatever the fallback chain now
// resolves to, in the same saveConversation() call, so the record that
// triggered the demotion is not lost until a later call happens to run.
const flakyId = await flakyPage.api.runFixtureTurn(fixture);
await flushPromises();
assert.equal((await flakyPage.api.list()).length, 1,
  'the record that triggered the demotion was not retried into the fallback');
assert.equal(await flakyPage.api.storeName(), 'localstorage',
  'IndexedDB stayed selected after its write failed');
const flakyRecord = await flakyPage.api.read(flakyId);
assert.ok(flakyRecord, 'the retried save did not reach the fallback store');
assert.equal(flakyRecord.messages.length, 3);

// IndexedDB recovering later does not un-exclude it: the demotion is sticky
// for the rest of the page session, since resolveConversationStore()'s own
// probes cannot distinguish a transient failure from a persistent one and a
// store proven not to write once is not trusted with a second record.
failWrites.active = false;
await flakyPage.api.appendFollowUp('a later save still avoids the demoted store', 'image-capable');
await flushPromises();
assert.equal(await flakyPage.api.storeName(), 'localstorage',
  'a recovered IndexedDB was reselected after its earlier write had failed');
const flakyFollowUp = await flakyPage.api.read(flakyId);
assert.equal(flakyFollowUp.messages.at(-1).content,
  'a later save still avoids the demoted store');

// The demotion survives a reload too: a fresh page sharing the same
// localStorage -- and therefore the same qwen-apu-conversation-store-demoted
// marker -- skips a since-recovered IndexedDB rather than reselecting it and
// reading back whatever it still holds from before the failed write. Without
// the persisted marker this page would read the IndexedDB record the
// demoted write never reached, silently reverting the follow-up message
// that only ever landed in localStorage.
const reloadedFlakyPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(), // a healthy IndexedDB this time
  localStorage: flakyLocalStorage,
  sessionStorage: makeFakeStorage()
});
await answerBoot(reloadedFlakyPage);
assert.equal(await reloadedFlakyPage.api.storeName(), 'localstorage',
  'a reload reselected a since-recovered IndexedDB despite the persisted demotion marker');
const reloadedFlakyRecord = await reloadedFlakyPage.api.read(flakyId);
assert.equal(reloadedFlakyRecord.messages.at(-1).content,
  'a later save still avoids the demoted store',
  'the reload read a stale record instead of the one localStorage actually holds');

// The save loop keeps going past a second failing store: IndexedDB denied,
// then localStorage's real write also refused (its own probe still answers,
// the quota shape above), and only the third attempt -- memory, which never
// throws -- lands the record, all inside the one call that started it.
// Both failWrites flags start false so the write-then-delete selection probe
// below still passes for both stores; this arm's point is a write that
// starts refusing after selection, on both backends in the same call.
const cascadeDatabase = makeFakeIndexedDatabase();
const cascadeIndexedFailWrites = { active: false };
const cascadeIndexedDatabase =
  makeFlakyIndexedDatabase(cascadeDatabase, { failWrites: cascadeIndexedFailWrites });
const cascadeLocalFailWrites = { active: false };
const cascadePage = newPage({
  indexedDatabase: cascadeIndexedDatabase,
  localStorage: makeFlakyStorage(cascadeLocalFailWrites),
  sessionStorage: makeFakeStorage()
});
await answerBoot(cascadePage);
assert.equal(await cascadePage.api.storeName(), 'indexeddb');
cascadeIndexedFailWrites.active = true;
cascadeLocalFailWrites.active = true;
const cascadeId = await cascadePage.api.runFixtureTurn(fixture);
await flushPromises();
assert.equal(await cascadePage.api.storeName(), 'memory',
  'a call that failed on two stores did not reach the third');
const cascadeList = await cascadePage.api.list();
assert.equal(cascadeList.length, 1,
  'the record was lost after two stores refused it in the same call');
const cascadeRecord = await cascadePage.api.read(cascadeId);
assert.ok(cascadeRecord, 'the cascaded save did not reach memory');
assert.equal(cascadeRecord.messages.length, 3);

// A store excluded after a write failure can still answer list()/read(): a
// conversation it already holds from before the failure is migrated into
// the replacement store rather than left invisible in a store nothing reads
// from again for the rest of the page session.
const migrationDatabase = makeFakeIndexedDatabase();
const priorPage = newPage({
  indexedDatabase: migrationDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(priorPage);
const priorId = await priorPage.api.runFixtureTurn(fixture);
await flushPromises();
assert.ok((await priorPage.api.read(priorId)).messages.length,
  'the prior conversation did not save ahead of the migration arm');

// Starts false so the write-then-delete selection probe still passes;
// this arm's point is a write that starts refusing after selection.
const migrationFailWrites = { active: false };
const migrationIndexedDatabase =
  makeFlakyIndexedDatabase(migrationDatabase, { failWrites: migrationFailWrites });
const migrationLocalStorage = makeFakeStorage();
const migrationPage = newPage({
  indexedDatabase: migrationIndexedDatabase,
  localStorage: migrationLocalStorage,
  sessionStorage: makeFakeStorage()
});
await answerBoot(migrationPage);
assert.equal(await migrationPage.api.storeName(), 'indexeddb',
  'the prior conversation was not visible through IndexedDB before the failure');
const migrationPriorList = await migrationPage.api.list();
assert.equal(migrationPriorList.length, 1, 'IndexedDB reported no prior conversation');
migrationFailWrites.active = true;
const newId = await migrationPage.api.runFixtureTurn(fixture);
await flushPromises();
assert.equal(await migrationPage.api.storeName(), 'localstorage',
  'the write failure did not demote IndexedDB');
const migratedList = await migrationPage.api.list();
assert.equal(migratedList.length, 2,
  'the prior conversation disappeared from the sidebar after the demotion');
assert.ok(migratedList.some(entry => entry.id === priorId),
  'the prior conversation was not migrated into the replacement store');
const migratedPriorRecord = await migrationPage.api.read(priorId);
assert.ok(migratedPriorRecord, 'the prior conversation could no longer be opened');
assert.equal(migratedPriorRecord.messages.length, 3);
const migratedNewRecord = await migrationPage.api.read(newId);
assert.ok(migratedNewRecord, 'the conversation that triggered the demotion did not save');

// A newer copy already in the replacement store survives the migration: an
// earlier session that ran entirely on the fallback while this one opened on
// a store that still read as healthy must not have its own newer record
// overwritten by a stale one carried over from the store being left.
const staleDatabase = makeFakeIndexedDatabase();
const staleSourcePage = newPage({
  indexedDatabase: staleDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(staleSourcePage);
const staleId = await staleSourcePage.api.runFixtureTurn(fixture);
await flushPromises();
const staleRecord = await staleSourcePage.api.read(staleId);

// Starts false so the write-then-delete selection probe still passes;
// this arm's point is a write that starts refusing after selection.
const staleFailWrites = { active: false };
const staleIndexedDatabase =
  makeFlakyIndexedDatabase(staleDatabase, { failWrites: staleFailWrites });
const staleLocalStorage = makeFakeStorage();
// A newer record under the same id is already in localStorage before this
// page ever runs, the way a later session that fell back to it would leave
// one.
const newerRecord = {
  ...staleRecord, title: 'a newer session already renamed this',
  updated: staleRecord.updated + 1000
};
staleLocalStorage.setItem(
  'qwen-apu-conversation:' + staleId, JSON.stringify(newerRecord));
staleLocalStorage.setItem(
  'qwen-apu-conversation-index',
  JSON.stringify([{ id: staleId, title: newerRecord.title, updated: newerRecord.updated }]));
const stalePage = newPage({
  indexedDatabase: staleIndexedDatabase,
  localStorage: staleLocalStorage,
  sessionStorage: makeFakeStorage()
});
await answerBoot(stalePage);
assert.equal(await stalePage.api.storeName(), 'indexeddb');
staleFailWrites.active = true;
await stalePage.api.appendFollowUp('a write that triggers the migration', 'image-capable');
await flushPromises();
assert.equal(await stalePage.api.storeName(), 'localstorage');
const survivingRecord = await stalePage.api.read(staleId);
assert.equal(survivingRecord.title, 'a newer session already renamed this',
  'a stale record from the demoted store overwrote the newer fallback record');
assert.equal(survivingRecord.updated, newerRecord.updated);

// rename and delete run through the same demotion-and-retry chain as save:
// a store that refuses the write no longer just leaves the stored title, or
// keeps the deleted row, on a store that answered its own probe but refuses
// this real operation.
const mutationDatabase = makeFakeIndexedDatabase();
const mutationFailWrites = { active: true };
const mutationIndexedDatabase =
  makeFlakyIndexedDatabase(mutationDatabase, { failWrites: mutationFailWrites });
const mutationPage = newPage({
  indexedDatabase: mutationIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(mutationPage);
// The fixture turn itself demotes IndexedDB the way the arms above already
// prove; what this arm adds is the rename and the delete that follow.
const mutationId = await mutationPage.api.runFixtureTurn(fixture);
await flushPromises();
assert.equal(await mutationPage.api.storeName(), 'localstorage');

await mutationPage.api.renameConversation(mutationId);
await flushPromises();
const renamedRecord = await mutationPage.api.read(mutationId);
assert.equal(renamedRecord.title, 'renamed conversation',
  'the rename did not reach the fallback store');

await mutationPage.api.deleteConversation(mutationId);
await flushPromises();
assert.equal(await mutationPage.api.read(mutationId), null,
  'the delete did not reach the fallback store');

// ---- switchConversation rechecks busy after its own await -----------------

const raceSource = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(raceSource);
const raceId = await raceSource.api.runFixtureTurn(fixture);
await flushPromises();

const racePage = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(racePage);
await flushPromises();
const beforeSwitch = racePage.api.state().conversationId;
assert.notEqual(beforeSwitch, raceId);

// busy flips true after switchConversation has already passed its first
// check and started readConversationRecord(id), but before that read
// settles: a send that started in this window now owns the in-flight turn.
const switchPromise = racePage.api.switchConversation(raceId);
racePage.api.setBusy(true);
await flushPromises();
racePage.api.setBusy(false);
const switchOutcome = await switchPromise;
assert.equal(switchOutcome, false,
  'a switch begun before a concurrent send still discarded the in-flight turn');
assert.equal(racePage.api.state().conversationId, beforeSwitch,
  'a switch racing a send moved off the turn it should have left running');
assert.equal(racePage.location.hash, `#/c/${beforeSwitch}`,
  'the route drifted from the conversation actually left on screen');

// ---- a routed id with no record routes the freshly opened conversation ----

const staleRoutePage = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: '#/c/nosuchrecord0'
});
await answerBoot(staleRoutePage);
await flushPromises();
const staleState = staleRoutePage.api.state();
assert.ok(staleState.conversationId, 'a stale route opened no conversation at all');
assert.notEqual(staleState.conversationId, 'nosuchrecord0');
assert.equal(staleRoutePage.location.hash, `#/c/${staleState.conversationId}`,
  'the address bar still names the stale routed id rather than the id this page opened');

// ---- send() awaits initConversations() before it touches conversationId ---

const raceInitSource = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(raceInitSource);
const raceInitId = await raceInitSource.api.runFixtureTurn(fixture);
await flushPromises();

const gatedPage = newPage({
  indexedDatabase: sharedIndexedDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage(),
  hash: `#/c/${raceInitId}`
});
// send() is called in the same tick the page is created, before
// initConversations() has read the routed record, so conversationId is still
// null here: the send has to wait on conversationsReadyPromise rather than
// running against a null id every save() would then no-op against.
gatedPage.api.setRequestModel('image-capable');
gatedPage.api.setInput('a message sent before init settles');
const gatedSendPromise = gatedPage.api.send();
assert.equal(gatedPage.api.state().conversationId, null,
  'conversationId was already set before initConversations() could have settled');

await answerBoot(gatedPage);
await flushPromises();
assert.equal(gatedPage.api.state().conversationId, raceInitId,
  'send() proceeded against a conversation initConversations() had not yet selected');

const gatedCompletion = takeRequest(gatedPage.pendingRequests,
  request => request.url === './v1/chat/completions', 'the gated completion request');
gatedCompletion.resolve(sseResponse([{
  choices: [{ delta: { content: 'joined the routed conversation' }, finish_reason: 'stop' }]
}]));
await gatedSendPromise;
await flushPromises();
const gatedRecord = await gatedPage.api.read(raceInitId);
assert.equal(gatedRecord.messages.length, 5,
  'the gated send did not land in the routed conversation the page settled on');
assert.equal(gatedRecord.messages.at(-1).content, 'joined the routed conversation');

// ---- an artifact card attaches to the message its own lineage names, not
// whichever message the page most recently remembered, and removing a card
// deletes the record it wrote ------------------------------------------------

const artifactPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(artifactPage);
artifactPage.document.querySelector('#artifact-origin').value = ARTIFACT_ORIGIN;
artifactPage.api.setRequestModel('image-capable');

function artifactBlobResponse() {
  return { ok: true, status: 200, async blob() { return { size: 4 }; } };
}

const firstEntry = artifactPage.api.rememberAssistantTurn('the first answer');
const firstGeneration = artifactPage.api.activeGeneration();
// A correction's own lineage carries entry/entryGeneration forward the way
// proposeImageCorrection's reconstructed lineage does, so the test builds
// one explicit lineage object and reuses it for both renders.
const firstLineage = { entry: firstEntry, entryGeneration: firstGeneration };
const firstFields = {
  prompt: 'a first image', seed: 111, width: 512, height: 512, steps: 4,
  profile: 'sdxs-512-arm-a'
};
const firstResult = { sha256: 'a'.repeat(64), provenanceUrl: '/artifacts/aaa.json' };
const firstCardPromise = artifactPage.api.renderArtifactCard(firstFields, firstResult, firstLineage);
takeRequest(artifactPage.pendingRequests,
  request => String(request.url) === `${ARTIFACT_ORIGIN}/artifacts/${firstResult.sha256}.png`,
  'the first artifact fetch').resolve(artifactBlobResponse());
await flushPromises();
const firstCardInfo = await firstCardPromise;

// A second, unrelated assistant message moves activeAssistantEntry forward
// the way a later turn would while the first card is still on screen.
const secondEntry = artifactPage.api.rememberAssistantTurn('a later, unrelated answer');
assert.notEqual(secondEntry, firstEntry);

// A correction of the FIRST card carries firstLineage, so the corrected
// artifact must still land on firstEntry rather than the entry
// activeAssistantEntry now names.
const correctedFields = { ...firstFields, prompt: 'a corrected image' };
const correctedResult = { sha256: 'b'.repeat(64), provenanceUrl: '/artifacts/bbb.json' };
const correctionCardPromise = artifactPage.api.renderArtifactCard(
  correctedFields, correctedResult, firstLineage);
takeRequest(artifactPage.pendingRequests,
  request => String(request.url) === `${ARTIFACT_ORIGIN}/artifacts/${correctedResult.sha256}.png`,
  'the correction artifact fetch').resolve(artifactBlobResponse());
await flushPromises();
const correctionCardInfo = await correctionCardPromise;
await flushPromises();

let artifactState = artifactPage.api.state();
const firstMessage = artifactState.messages.find(m => m.content === 'the first answer');
const secondMessage = artifactState.messages.find(m => m.content === 'a later, unrelated answer');
assert.equal(firstMessage.artifacts.length, 2,
  'the correction did not land on the entry that proposed the original generation');
assert.equal(firstMessage.artifacts[0].sha256, firstResult.sha256);
assert.equal(firstMessage.artifacts[1].sha256, correctedResult.sha256);
assert.equal(secondMessage.artifacts.length, 0,
  'the correction attached to the most recently remembered message instead of its own lineage');

// Removing the corrected card deletes only that record, saved.
artifactPage.api.clickRemove(correctionCardInfo.card);
await flushPromises();
artifactState = artifactPage.api.state();
const afterRemoveMessage = artifactState.messages.find(m => m.content === 'the first answer');
assert.equal(afterRemoveMessage.artifacts.length, 1,
  'removing the card left its record in the live transcript');
assert.equal(afterRemoveMessage.artifacts[0].sha256, firstResult.sha256,
  'removing the corrected card deleted the wrong artifact');
const artifactRecord = await artifactPage.api.read(artifactState.conversationId);
const persistedFirstMessage = artifactRecord.messages.find(m => m.content === 'the first answer');
assert.equal(persistedFirstMessage.artifacts.length, 1,
  'the removed card was not saved out of the persisted record');

// ---- the feature roster cache retries once a key that was missing arrives -

const rosterPage = newPage({
  indexedDatabase: makeFakeIndexedDatabase(),
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await flushPromises();
// The anonymous probe proves the backend requires a bearer, so boot() stops
// there with no candidate key to retry.
takeRequest(rosterPage.pendingRequests,
  request => request.url === './v1/models', 'the anonymous roster probe')
  .resolve(jsonResponse({}, 401));
await flushPromises();

// A badge render before any key is supplied reads the roster and caches its
// 401 as no roster.
void rosterPage.api.featureRosterOnce();
await flushPromises();
const firstRosterFetch = takeRequest(rosterPage.pendingRequests,
  request => request.url === './roster.json', 'the first roster read');
assert.equal(firstRosterFetch.options.headers.Authorization, undefined,
  'the pre-key roster read carried a bearer nothing had supplied yet');
firstRosterFetch.resolve(jsonResponse({}, 401));
await flushPromises();

// A second call ahead of any key change reuses the memoized read: this is
// the caching behaviour the fix leaves alone.
void rosterPage.api.featureRosterOnce();
await flushPromises();
assert.equal(
  rosterPage.pendingRequests.filter(r => r.url === './roster.json').length, 0,
  'a repeated call issued a second roster fetch ahead of any key change');

// Supplying the key clears the memoized promise, so boot() retries the
// roster read under the credential that just arrived rather than carrying
// the pre-key 401 for the rest of the page session. boot() fires that read
// itself, ahead of any badge, since the picker's own labels and support
// matrix wait on the same memoized promise a badge would.
rosterPage.api.clickSetKey('a-fresh-key');
await flushPromises();
const retriedRosterFetch = takeRequest(rosterPage.pendingRequests,
  request => request.url === './roster.json',
  'the roster read did not retry after the key was set');
assert.equal(retriedRosterFetch.options.headers.Authorization, 'Bearer a-fresh-key',
  'the retried roster read carried no bearer even though one was just supplied');
// boot() always opens on an anonymous probe; only the retry carries the key
// this click just supplied.
takeRequest(rosterPage.pendingRequests,
  request => request.url === './v1/models' && request.options.headers?.Authorization === undefined,
  'the anonymous roster probe after the key was set')
  .resolve(jsonResponse({}, 401));
await flushPromises();
takeRequest(rosterPage.pendingRequests,
  request => request.url === './v1/models' &&
    request.options.headers?.Authorization === 'Bearer a-fresh-key',
  'the authenticated roster retry')
  .resolve(jsonResponse({ data: [{ id: 'image-capable' }] }));
await flushPromises();
// boot() awaits the memoized roster read before it builds the picker's
// labels and matrix, so that promise must settle before boot() reaches the
// props fetch below.
retriedRosterFetch.resolve(jsonResponse({
  schema: 'qwen-feature-roster/1', features: [], models: []
}));
await flushPromises();
takeRequest(rosterPage.pendingRequests,
  request => String(request.url).startsWith('./props?model='),
  'model properties after the key was set')
  .resolve(jsonResponse({ n_ctx: 4096 }));
await flushPromises();

// A badge rendered after boot() settles reuses the same memoized read rather
// than retrying it a second time under the same credential.
void rosterPage.api.featureRosterOnce();
await flushPromises();
assert.equal(
  rosterPage.pendingRequests.filter(r => r.url === './roster.json').length, 0,
  'a badge retried the roster read a second time under the same key');

// ---- a reset aborts a restored artifact fetch still in flight -------------

const restoreDatabase = makeFakeIndexedDatabase();
const restoreSourcePage = newPage({
  indexedDatabase: restoreDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(restoreSourcePage);
const restoreId = await restoreSourcePage.api.runFixtureTurn(fixture);
await flushPromises();

const restoreRacePage = newPage({
  indexedDatabase: restoreDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(restoreRacePage);
restoreRacePage.document.querySelector('#artifact-origin').value = ARTIFACT_ORIGIN;

// Switching to the conversation starts restoring its artifact card, which
// issues an artifact fetch this arm holds pending rather than answering.
await restoreRacePage.api.switchConversation(restoreId);
await flushPromises();
assert.equal(restoreRacePage.api.state().conversationId, restoreId);
const pendingArtifactFetch = takeRequest(restoreRacePage.pendingRequests,
  request => String(request.url) === `${ARTIFACT_ORIGIN}/artifacts/${FIXTURE_SHA256}.png`,
  'the restored artifact fetch, held pending');

// A second switch resets state while that fetch is still outstanding: the
// reset aborts it rather than leaving it to complete into a card the reset
// already detached.
restoreRacePage.api.clickNew();
await flushPromises();

// The fetch settling after the reset -- whether the abort already rejected it
// or a slower fake resolves it regardless -- must not register a blob URL a
// live card no longer owns.
pendingArtifactFetch.resolve({ ok: true, status: 200, async blob() { return { size: 4 }; } });
await flushPromises();
assert.equal(restoreRacePage.api.restoredBlobUrls(), 0,
  'a restore fetch that outran its own reset still registered a blob URL');

// ---- a save resolves on the transaction's commit, not on the request ------

function makeDeferredCommitIndexedDatabase(realDatabase, control) {
  /* Wrap a real fake IndexedDB so a readwrite transaction's request answers
     normally -- the record lands in the underlying store -- while
     transaction.oncomplete stays withheld from the fake's own auto-fire
     until the test calls control.release(). indexedDatabaseConversationStore
     ()'s run() must still have an unsettled promise at that point: resolving
     early, on request.onsuccess, is exactly the defect a reload racing a
     write can observe, because the record the request already wrote can
     still roll back if the transaction never commits. The property is
     redefined as a getter/setter rather than a plain field so the fake's
     `if (transaction.oncomplete)` auto-fire check reads null and skips its
     own call, while the real handler run() assigned is retained for
     control.release() to invoke by hand. resolveConversationStore()'s own
     selection probe now proves a write, not only a list(), so it opens a
     readwrite transaction too, ahead of the real save; put()/delete() tag the
     transaction against CONVERSATION_PROBE_KEY as soon as it is called,
     strictly before the fake's own setImmediate hops read the property back,
     and the getter auto-fires that one rather than holding it, so only the
     real save's transaction ever stalls on control.release(). */
  return {
    open(name) {
      const request = realDatabase.open(name);
      const database = request.result;
      const originalTransaction = database.transaction.bind(database);
      database.transaction = (...args) => {
        const transaction = originalTransaction(...args);
        if (args[1] !== 'readwrite') return transaction;
        let heldHandler = null;
        const originalObjectStore = transaction.objectStore.bind(transaction);
        transaction.objectStore = (...storeArgs) => {
          const store = originalObjectStore(...storeArgs);
          const originalPut = store.put.bind(store);
          const originalDelete = store.delete.bind(store);
          store.put = value => {
            if (value && value.id === CONVERSATION_PROBE_KEY) transaction.isProbe = true;
            return originalPut(value);
          };
          store.delete = key => {
            if (key === CONVERSATION_PROBE_KEY) transaction.isProbe = true;
            return originalDelete(key);
          };
          return store;
        };
        Object.defineProperty(transaction, 'oncomplete', {
          get() { return transaction.isProbe ? heldHandler : null; },
          set(handler) {
            heldHandler = handler;
            control.release = () => {
              if (heldHandler) heldHandler({ target: transaction });
            };
          }
        });
        return transaction;
      };
      return request;
    }
  };
}

const commitControl = { release: null };
const deferredDatabase = makeDeferredCommitIndexedDatabase(
  makeFakeIndexedDatabase(), commitControl);
const deferredPage = newPage({
  indexedDatabase: deferredDatabase,
  localStorage: makeFakeStorage(),
  sessionStorage: makeFakeStorage()
});
await answerBoot(deferredPage);
let deferredSaveSettled = false;
const deferredSavePromise = deferredPage.api.runFixtureTurn(fixture)
  .then(id => { deferredSaveSettled = true; return id; });
await flushPromises();
assert.equal(deferredSaveSettled, false,
  'saveConversation() resolved before its IndexedDB transaction committed');
assert.ok(commitControl.release, 'the write transaction never assigned oncomplete');
commitControl.release();
const deferredId = await deferredSavePromise;
assert.equal(deferredSaveSettled, true);
const deferredRecord = await deferredPage.api.read(deferredId);
assert.ok(deferredRecord, 'the committed write is unreadable after the commit fired');
assert.equal(deferredRecord.messages.length, 3);

console.log('fallback_webui_conversations=accepted');
