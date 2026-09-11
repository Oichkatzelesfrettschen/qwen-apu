// The fake browser every module test runs against.
//
// The page is ten ES modules rather than one inline script, so a test installs
// the globals first and imports second: `document`, `window`, `fetch`, and the
// two storages reach `globalThis` before the first module evaluates, and every
// module's own evaluation touches none of them. `status.js` is the entry point
// and its import is what runs the page, so `newPage()` imports it under a fresh
// query string: the ESM loader keys its cache on the whole specifier, so a new
// counter is what gives the next arm its own module instances and its own state
// objects.
//
// `deferredFetch` resolves nothing by itself. A test takes the request it means
// to answer, answers it, and flushes, which is what makes the order of the
// page's own reads an assertion rather than a race.

import assert from 'node:assert/strict';
import { register } from 'node:module';

// One arm, one module graph: the resolve hook carries the arm's query
// from the entry point onto every module it imports.
register('./isolate-hook.mjs', import.meta.url);

export class FakeElement {
  constructor(tagName = 'div') {
    this.tagName = tagName;
    this.attributes = new Map();
    this.checked = false;
    this.children = [];
    this.className = '';
    this.dataset = {};
    this.disabled = false;
    this.hidden = false;
    this.href = '';
    this.listeners = new Map();
    this.options = [];
    this.scrollHeight = 0;
    this.scrollTop = 0;
    this._textContent = '';
    this.title = '';
    this.value = '';
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  get textContent() {
    // The DOM composes an element's text from its own and its descendants',
    // so a body written after its parent was appended still reads through the
    // parent -- which is what a transcript assertion depends on.
    const own = this._textContent;
    return own + this.children
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

  removeEventListener() {}

  append(...children) {
    this.children.push(...children);
    for (const child of children) {
      if (this.tagName === 'select' && child instanceof FakeElement) this.options.push(child);
    }
  }

  insertBefore(node) {
    this.children.unshift(node);
    return node;
  }

  after() {}

  remove() {}

  querySelector(selector) {
    // One class selector, depth first: the artifact card reaches its own Open,
    // Download, review, and checklist elements this way.
    const wanted = selector.startsWith('.') ? selector.slice(1) : selector;
    for (const child of this.children) {
      if (!(child instanceof FakeElement)) continue;
      if (String(child.className).split(/\s+/).includes(wanted)) return child;
      const found = child.querySelector(selector);
      if (found) return found;
    }
    return null;
  }

  click() {
    const handler = this.onclick;
    if (typeof handler === 'function') handler();
  }

  // The approval dialogs open and close through these two, and `finish()`
  // clears `onclose` before it closes, so a close raises no second outcome.
  showModal() {
    this.open = true;
  }

  close() {
    this.open = false;
  }

  focus() {}

  get isConnected() {
    return true;
  }
}

export function deniedStorage() {
  return {
    getItem() { throw new Error('storage denied'); },
    removeItem() { throw new Error('storage denied'); },
    setItem() { throw new Error('storage denied'); }
  };
}

export function memoryStorage(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    store,
    get length() { return store.size; },
    key(index) { return [...store.keys()][index] ?? null; },
    getItem(key) { return store.has(key) ? store.get(key) : null; },
    setItem(key, value) { store.set(key, String(value)); },
    removeItem(key) { store.delete(key); }
  };
}

export async function flushPromises(turns = 25) {
  for (let turn = 0; turn < turns; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

let pageCounter = 0;

export function newHarness({
  meta = {}, localStorage, sessionStorage, location, hash = '', indexedDatabase = null
} = {}) {
  const elements = new Map();
  const pending = [];
  const listeners = new Map();
  const document = {
    createElement(tagName) {
      return new FakeElement(tagName);
    },
    querySelector(selector) {
      const metaMatch = /^meta\[name="([^"]+)"\]$/.exec(selector);
      if (metaMatch) {
        if (!(metaMatch[1] in meta)) return null;
        const tag = new FakeElement('meta');
        tag.setAttribute('content', String(meta[metaMatch[1]]));
        return tag;
      }
      if (!elements.has(selector)) {
        elements.set(selector, new FakeElement(selector === '#model-picker' ? 'select' : 'div'));
      }
      return elements.get(selector);
    }
  };
  const windowObject = {
    addEventListener(eventName, listener) { listeners.set(eventName, listener); },
    alert(message) { windowObject.alerts.push(message); },
    alerts: [],
    confirm() { return windowObject.confirmAnswer; },
    confirmAnswer: true,
    prompt() { return windowObject.promptAnswer; },
    promptAnswer: null,
    location: location ?? { hash, hostname: '127.0.0.1', origin: 'http://127.0.0.1:8090',
                            href: `http://127.0.0.1:8090/${hash}`,
                            pathname: '/', port: '8090', protocol: 'http:', search: '' },
    localStorage: localStorage ?? memoryStorage(),
    sessionStorage: sessionStorage ?? memoryStorage()
  };
  function fetchStub(url, options = {}) {
    return new Promise((resolve, reject) => {
      const entry = { url, options, resolve, reject };
      pending.push(entry);
      if (options.signal) {
        // An abort removes the request from the queue and rejects it the way a
        // browser does, which is what lets a reset prove it cancelled a read.
        const onAbort = () => {
          const index = pending.indexOf(entry);
          if (index !== -1) pending.splice(index, 1);
          const aborted = new Error('The operation was aborted.');
          aborted.name = 'AbortError';
          reject(aborted);
        };
        if (options.signal.aborted) onAbort();
        else options.signal.addEventListener('abort', onAbort, { once: true });
      }
    });
  }
  return {
    document, elements, pending, listeners, indexedDatabase,
    window: windowObject, fetch: fetchStub
  };
}

export function install(harness) {
  globalThis.document = harness.document;
  globalThis.window = harness.window;
  if (harness.indexedDatabase) globalThis.indexedDB = harness.indexedDatabase;
  else delete globalThis.indexedDB;
  globalThis.localStorage = harness.window.localStorage;
  globalThis.sessionStorage = harness.window.sessionStorage;
  globalThis.fetch = harness.fetch;
  globalThis.Blob = globalThis.Blob ?? class {};
  globalThis.URL.createObjectURL = () => `blob:qwen-apu/${Math.random().toString(16).slice(2)}`;
  globalThis.URL.revokeObjectURL = () => {};
}

const MODULE_NAMES = ['api', 'artifacts', 'attachments', 'chat', 'conversations',
  'models', 'status', 'temporary', 'tools'];

export async function newPage(options = {}) {
  /* Install one arm's fakes, import its page, and hand back the arm's own
     module instances.

     `status.js` acts on import, so the import is the page load. Every sibling
     is imported under the same `page` query the hook propagates, which is what
     makes `modules.chat.history` the array this arm's own `send()` pushes to
     rather than a previous arm's. */
  const harness = newHarness(options);
  install(harness);
  pageCounter += 1;
  const page = pageCounter;
  const modules = {};
  modules.status = await import(`../../static/js/status.js?page=${page}`);
  for (const name of MODULE_NAMES) {
    if (name === 'status') continue;
    modules[name] = await import(`../../static/js/${name}.js?page=${page}`);
  }
  return {
    harness,
    modules,
    element: selector => harness.document.querySelector(selector),
    fireHashChange() {
      const listener = harness.listeners.get('hashchange');
      assert.ok(listener, 'the page registered no hashchange listener');
      listener();
    },
    take: (predicate, description) => awaitRequest(harness, predicate, description),
    pending: harness.pending
  };
}

export function takeRequest(harness, predicate, description) {
  const index = harness.pending.findIndex(predicate);
  assert.notEqual(index, -1, `missing request: ${description}`);
  return harness.pending.splice(index, 1)[0];
}

export async function awaitRequest(harness, predicate, description, turns = 400) {
  /* Take the request this arm is waiting for, once the page has issued it.

     A fixed number of microtask turns is what a fixed `flushPromises()` count
     amounts to, and the page's own awaits vary: a digest over an artifact, an
     `arrayBuffer()`, and a `JSON.parse` each settle on their own tick. Polling
     until the request appears makes the assertion "the page issues this" rather
     than "the page issues this within N turns", and the turn cap is what turns
     a request the page never issues into a named failure instead of a hang. */
  for (let turn = 0; turn < turns; turn += 1) {
    const index = harness.pending.findIndex(predicate);
    if (index !== -1) return harness.pending.splice(index, 1)[0];
    await new Promise(resolve => setImmediate(resolve));
  }
  assert.fail(`missing request: ${description}`);
}

export function jsonResponse(payload, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() { return payload; },
    async text() { return JSON.stringify(payload); }
  };
}

export function registryResponse(rows, status = 200) {
  return jsonResponse({ models: rows }, status);
}

export async function drainPending(harness, answer = () => jsonResponse({ models: [] })) {
  while (harness.pending.length) {
    const request = harness.pending.shift();
    request.resolve(answer(request));
    await flushPromises(3);
  }
}

export const WEB_TOOL_LISTING = [{
  tool: 'web_search_exa',
  definition: { type: 'function', function: { name: 'web_search_exa', parameters: {
    type: 'object', properties: { query: { type: 'string' }, authorization: { type: 'string' } },
    required: ['query'] } } }
}];

export function registryRow(id, overrides = {}) {
  return {
    id,
    role: 'balanced-text',
    tier: 'production',
    context_default: 24576,
    projector: 'none',
    quantization: 'Q4_K_M',
    ...overrides
  };
}

export async function bootPage(options = {}) {
  /* Run one page through its own boot and leave it at idle.

     The order is the page's own: `/api/health` and `/api/models` are in flight
     together, a roster of more than one row probes `/api/tools` per row, and
     the selection then reads `/api/models` once more for the depth and the
     projector pairing its registry row states. Answering each in turn is what
     makes the read order an assertion rather than a race. */
  const {
    rows = [registryRow('model-A')],
    health = { upstream: { serving: true } },
    toolListing = WEB_TOOL_LISTING,
    registryStatus = 200,
    ...rest
  } = options;
  const page = await newPage(rest);
  await flushPromises();
  (await page.take(request => request.url === '/api/health', 'health probe'))
    .resolve(jsonResponse(health));
  (await page.take(request => request.url === '/api/models', 'model registry'))
    .resolve(registryStatus === 200
      ? registryResponse(rows)
      : jsonResponse({ error: 'refused' }, registryStatus));
  await flushPromises();
  if (registryStatus === 200 && rows.length > 1) {
    for (const row of rows) {
      (await page.take(request => request.url === `/api/tools?model=${encodeURIComponent(row.id)}`,
        `tool probe for ${row.id}`)).resolve(
        Array.isArray(toolListing) ? jsonResponse(toolListing) : jsonResponse(toolListing, 403));
      await flushPromises();
    }
  }
  if (registryStatus === 200 && rows.length) {
    (await page.take(request => request.url === '/api/models', 'selection registry read'))
      .resolve(registryResponse(rows));
    await flushPromises();
  }
  return page;
}

export function streamResponse(events, status = 200) {
  /* One `POST /api/chat` answer, as the gateway writes it.

     `streamCompletion` reads `response.body.getReader()` and splits on
     newlines, so each event reaches it as its own `data: ` line and the reader
     ends where the array does. A chunk carries the `model` key every
     chat.completion.chunk carries, which is what the badge and the
     conversation record name the answering model from. */
  const encoder = new TextEncoder();
  const lines = events.map(event => `data: ${JSON.stringify(event)}\n`);
  lines.push('data: [DONE]\n');
  let index = 0;
  return {
    ok: status >= 200 && status < 300,
    status,
    async text() { return lines.join(''); },
    body: {
      getReader() {
        return {
          async read() {
            if (index >= lines.length) return { done: true, value: undefined };
            const value = encoder.encode(lines[index]);
            index += 1;
            return { done: false, value };
          }
        };
      }
    }
  };
}

export function answerEvent(model, content, extra = {}) {
  return { model, choices: [{ delta: { content }, ...extra }] };
}

export function toolCallEvent(model, name, args, index = 0) {
  return {
    model,
    choices: [{ delta: { tool_calls: [{ index, function: { name, arguments: args } }] } }]
  };
}

export function finishEvent(model, reason = 'stop') {
  return { model, choices: [{ delta: {}, finish_reason: reason }] };
}

// The artifact review path hashes what arrives, so a fixture's own digest is
// what a card accepts and any other digest is what it refuses.
export const FIXTURE_PNG_BYTES = new TextEncoder().encode('fake-png-bytes');
export const FIXTURE_PNG_SHA256 =
  '3c6ed5fc41c950bf0db531eb22f945467fb8d999f80d82ba27dcc9fd90add54d';

export function pngResponse(status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async arrayBuffer() { return FIXTURE_PNG_BYTES.buffer; }
  };
}

export function makeFakeIndexedDatabase() {
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

export function makeFakeStorage() {
  const values = new Map();
  return {
    values,
    store: values,
    get length() { return values.size; },
    key(index) { return [...values.keys()][index] ?? null; },
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, String(value)); },
    removeItem(key) { values.delete(key); }
  };
}

export function makeDeniedStorage() {
  return {
    get length() { throw new Error('storage denied'); },
    store: new Map(),
    key() { throw new Error('storage denied'); },
    getItem() { throw new Error('storage denied'); },
    setItem() { throw new Error('storage denied'); },
    removeItem() { throw new Error('storage denied'); }
  };
}

// resolveConversationStore()'s own probe writes and removes one throwaway key
// ahead of any real write, so a storage whose real writes are refused (quota)
// but whose probe still answers looks selectable on every resolution -- the
// shape a real quota-exhausted localStorage takes, and distinct from a total
// refusal, which the probe itself already catches.
export const CONVERSATION_PROBE_KEY = 'qwen-apu-conversation:probe';

export function makeFlakyStorage(failWrites) {
  const values = new Map();
  return {
    values,
    store: values,
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
