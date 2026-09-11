/* A conversation is a durable record with a URL, and this module is the whole
   authority for what reaches a browser store.

   Three stores answer in order. IndexedDB holds a keyed record per
   conversation; localStorage holds the same records under one key each beside
   an index; an in-memory Map serves the page whose browser refuses both, so a
   denial costs the reload rather than the panel. Every access sits inside a
   try/catch and a refusal falls to the next store. A Temporary conversation
   takes `temporary.js`'s memory store instead of the chain, from the moment it
   opens.

   What is written is a projection rather than a live object: role, content, the
   served model id, the tool call ids and arguments the transcript re-sends, and
   an artifact's digest, provenance route, seed, and geometry. Search content
   and fetch proposals carry short handles; their signed Result IDs remain in
   the live turn table. An approval grant, a session secret, and the session
   cookie reach no projection here, so the record a later reader restores
   authorizes nothing. Image bytes stay out too: a restored card refetches the
   artifact by its digest over the gateway's own route.

   `history` is rebuilt from the record, so a restored conversation continues
   against the same transcript the server already read. `exportBrowserHistory()`
   hands the reader every record verbatim under one schema key, which is the one
   way a record leaves this browser. */

import {
  $,
  logElement,
  prefixAtWholeCodePoint,
  probeBrowserStorageWrite,
  readBrowserStorage,
  writeBrowserStorage
} from './api.js';
import { attachments, renderAttached } from './attachments.js';
import {
  chatState,
  history,
  openRoundInTurn,
  turn
} from './chat.js';
import { appendModelBadge } from './models.js';
import { clearWebResultHandles } from './tools.js';
import {
  loadArtifactBlobUrl,
  registeredReviewModel,
  runImageReview
} from './artifacts.js';
import { endTemporary, isTemporary, startTemporary, temporaryStore } from './temporary.js';

/* The live conversation, its generation, and the store resolution behind it.
   The generation is what every awaited mutation compares against: a Clear, a
   switch, or a delete-all during an in-flight turn moves it, and a result
   arriving afterwards is discarded rather than written into the transcript the
   page now holds. */
export const conversationState = {
  generation: 0,
  id: null,
  title: '',
  messages: [],
  activeAssistantEntry: null,
  activeAssistantGeneration: -1,
  storeRead: null,
  mutationTail: Promise.resolve(),
  deletionEpoch: 0
};

// The document schema `exportBrowserHistory()` writes: a version key beside the
// records the store holds, verbatim.
export const HISTORY_EXPORT_SCHEMA = 'qwen_apu_browser_history_export';
export const HISTORY_EXPORT_VERSION = 1;

const CONVERSATION_DATABASE_NAME = 'qwen-apu-conversations';
const CONVERSATION_DATABASE_VERSION = 1;
const CONVERSATION_OBJECT_STORE = 'conversations';
const CONVERSATION_INDEX_KEY = 'qwen-apu-conversation-index';
const CONVERSATION_RECORD_PREFIX = 'qwen-apu-conversation:';
const CONVERSATION_SELECTED_KEY = 'qwen-apu-conversation-selected';
const CONVERSATION_TITLE_CHARACTER_CAP = 60;
const CONVERSATION_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

// A live card revokes its own blob URL from its remove button; a restored card
// carries none, so the reset that clears the log owns the revocation and a
// conversation switched away from releases every image it drew.
const restoredArtifactBlobUrls = new Set();
// A restored artifact fetch still in flight when a reset or switch happens
// is aborted here, so it cannot add a blob URL to the set above or insert an
// image into a card the reset already detached; the generation check inside
// renderRestoredArtifactCard covers the fetch that was already past its
// abort point when the signal fired.
const restoredArtifactControllers = new Set();


function conversationSummary(record) {
  return {
    id: record.id,
    title: record.title || 'untitled',
    updated: Number.isFinite(record.updated) ? record.updated : 0
  };
}

function newConversationId() {
  try {
    if (typeof crypto !== 'undefined' && crypto && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID().replace(/-/g, '');
    }
  } catch { /* the clock and Math.random name the conversation instead */ }
  return `c${Date.now().toString(36)}${Math.floor(Math.random() * 1e9).toString(36)}`;
}

function conversationRequestAsPromise(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('the store refused the request'));
  });
}

async function openConversationDatabase() {
  if (typeof indexedDB === 'undefined' || !indexedDB) {
    throw new Error('this browser exposes no IndexedDB');
  }
  const request = indexedDB.open(CONVERSATION_DATABASE_NAME, CONVERSATION_DATABASE_VERSION);
  request.onupgradeneeded = () => {
    const database = request.result;
    if (!database.objectStoreNames.contains(CONVERSATION_OBJECT_STORE)) {
      database.createObjectStore(CONVERSATION_OBJECT_STORE, { keyPath: 'id' });
    }
  };
  return conversationRequestAsPromise(request);
}

function indexedDatabaseConversationStore(database) {
  const run = (mode, action) => new Promise((resolve, reject) => {
    let transaction;
    try {
      transaction = database.transaction(CONVERSATION_OBJECT_STORE, mode);
    } catch (error) {
      reject(error);
      return;
    }
    // A write resolves once the transaction commits, not once the request
    // that queued it answers: request.onsuccess fires ahead of the commit,
    // so a reload racing right behind a resolved write() can still read the
    // previous record from disk. transaction.oncomplete fires only after the
    // commit, so every operation here settles on it instead, with the
    // request's own result value carried into that resolution.
    let settled = false;
    let requestResult;
    transaction.onabort = () => {
      if (settled) return;
      settled = true;
      reject(transaction.error || new Error('the transaction aborted'));
    };
    transaction.oncomplete = () => {
      if (settled) return;
      settled = true;
      resolve(requestResult);
    };
    let request;
    try {
      request = action(transaction.objectStore(CONVERSATION_OBJECT_STORE));
    } catch (error) {
      reject(error);
      return;
    }
    request.onsuccess = () => { requestResult = request.result; };
    request.onerror = () => {
      if (settled) return;
      settled = true;
      reject(request.error || new Error('the store refused the request'));
    };
  });
  return {
    name: 'indexeddb',
    async list() {
      const records = await run('readonly', store => store.getAll());
      return (Array.isArray(records) ? records : []).map(conversationSummary);
    },
    async read(id) {
      return (await run('readonly', store => store.get(id))) || null;
    },
    async write(record) { await run('readwrite', store => store.put(record)); },
    async remove(id) { await run('readwrite', store => store.delete(id)); },
    async clear() { await run('readwrite', store => store.clear()); }
  };
}

function browserStorageConversationStore() {
  // writeBrowserStorage swallows a denial by design, for a best-effort cache
  // (the API key, the reasoning toggle) where the live page state stays
  // authoritative regardless. This store's write() is what
  // saveConversation()'s retry loop decides whether to demote and retry
  // from, so a denial here has to reach the caller instead: writing directly
  // against window.localStorage is what lets a quota or a denied transaction
  // surface as a thrown rejection rather than a silently accepted no-op.
  const storage = window['localStorage'];
  const readIndex = () => {
    const raw = readBrowserStorage('localStorage', CONVERSATION_INDEX_KEY);
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) return [];
      return parsed.filter(entry =>
        entry && typeof entry.id === 'string' && CONVERSATION_ID_PATTERN.test(entry.id));
    } catch {
      return [];
    }
  };
  const writeIndexOrThrow = entries => storage.setItem(
    CONVERSATION_INDEX_KEY, JSON.stringify(entries));
  return {
    name: 'localstorage',
    async list() { return readIndex(); },
    async read(id) {
      const raw = readBrowserStorage('localStorage', CONVERSATION_RECORD_PREFIX + id);
      if (!raw) return null;
      try { return JSON.parse(raw); } catch { return null; }
    },
    async write(record) {
      storage.setItem(CONVERSATION_RECORD_PREFIX + record.id, JSON.stringify(record));
      const entries = readIndex().filter(entry => entry.id !== record.id);
      entries.push(conversationSummary(record));
      writeIndexOrThrow(entries);
    },
    async remove(id) {
      storage.removeItem(CONVERSATION_RECORD_PREFIX + id);
      writeIndexOrThrow(readIndex().filter(entry => entry.id !== id));
    },
    async clear() {
      const ownedRecordKeys = [];
      for (let index = 0; index < storage.length; index++) {
        const key = storage.key(index);
        if (typeof key === 'string' && key.startsWith(CONVERSATION_RECORD_PREFIX)) {
          ownedRecordKeys.push(key);
        }
      }
      for (const key of ownedRecordKeys) storage.removeItem(key);
      storage.removeItem(CONVERSATION_INDEX_KEY);
    }
  };
}

function memoryConversationStore() {
  const records = new Map();
  return {
    name: 'memory',
    async list() { return [...records.values()].map(conversationSummary); },
    async read(id) { return records.get(id) || null; },
    async write(record) { records.set(record.id, record); },
    async remove(id) { records.delete(id); },
    async clear() { records.clear(); }
  };
}

// IndexedDB can open and answer its own list() probe while still refusing a
// write -- a quota, a denied transaction -- and re-running the probe alone
// selects the same unwritable store again, since the probe is a read. A name
// entering this set is excluded from its own branch below, and the set
// survives a reload rather than resetting with the page: reselecting a store
// proven unwritable in an earlier session would read whatever it still holds
// from before the demotion, silently reverting a rename or a delete a later
// save committed to the store the demotion moved to instead. The marker
// persists through localStorage regardless of which store the demotion moved
// away from, because the demotion decision is what needs to survive, not the
// conversation data itself.
const CONVERSATION_STORE_DEMOTION_KEY = 'qwen-apu-conversation-store-demoted';
function readDemotedConversationStoreNames() {
  const raw = readBrowserStorage('localStorage', CONVERSATION_STORE_DEMOTION_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter(name => typeof name === 'string') : [];
  } catch {
    return [];
  }
}
let conversationStoreFailedNames = null;
function demotedConversationStoreNames() {
  // Read on first use rather than at module evaluation: importing this module
  // reaches no browser store, which is what lets a test install its own.
  if (!conversationStoreFailedNames) {
    conversationStoreFailedNames = new Set(readDemotedConversationStoreNames());
  }
  return conversationStoreFailedNames;
}
function rememberDemotedConversationStore(name) {
  demotedConversationStoreNames().add(name);
  writeBrowserStorage(
    'localStorage', CONVERSATION_STORE_DEMOTION_KEY,
    JSON.stringify([...demotedConversationStoreNames()]));
}

async function resolveConversationStore() {
  // A store this call opens but does not select still answers list()/read()
  // where the probe below proves only its write refused, so any record it
  // already holds from an earlier session is migrated into whichever store
  // this call does select rather than left stranded off the sidebar and
  // unopenable for the rest of the page session.
  let unselectedIndexedStore = null;
  if (!demotedConversationStoreNames().has('indexeddb')) {
    try {
      const database = await openConversationDatabase();
      const store = indexedDatabaseConversationStore(database);
      unselectedIndexedStore = store;
      // A write-then-delete proves the object store accepts a readwrite
      // transaction, not only a readonly one; a database that opens and
      // lists but refuses every write (quota, private-browsing policy)
      // falls through here rather than silently discarding every later
      // save.
      const probeId = `${CONVERSATION_RECORD_PREFIX}probe`;
      await store.write({ id: probeId, title: '', updated: 0, messages: [] });
      await store.remove(probeId);
      return store;
    } catch { /* the next store answers where IndexedDB refuses */ }
  }
  if (!demotedConversationStoreNames().has('localstorage')) {
    try {
      const probeKey = `${CONVERSATION_RECORD_PREFIX}probe`;
      probeBrowserStorageWrite('localStorage', probeKey);
      const store = browserStorageConversationStore();
      if (unselectedIndexedStore) await migrateReadableRecords(unselectedIndexedStore, store);
      return store;
    } catch { /* a denied localStorage leaves the record in memory for this page */ }
  }
  const store = memoryConversationStore();
  if (unselectedIndexedStore) await migrateReadableRecords(unselectedIndexedStore, store);
  return store;
}


function renderConversationStorageStatus(store) {
  const status = $('#conversation-storage-status');
  if (store.name === 'temporary') {
    status.className = 'meta bad';
    status.textContent =
      'This conversation is temporary: it reaches no browser store and ends with this tab.';
    return;
  }
  if (store.name === 'memory') {
    status.className = 'meta bad';
    status.textContent =
      'Conversation history is temporary and will disappear when this tab closes.';
    return;
  }
  status.className = 'meta';
  status.textContent = 'Conversation history is saved in this browser.';
}

function queueConversationMutation(operation, deletionEpoch = conversationState.deletionEpoch) {
  /* Serialize persistent mutations so delete-all has one ordered boundary.
     Incrementing conversationState.deletionEpoch invalidates every older mutation;
     the queue then lets an already-running store request settle before the
     clear runs, while an older retry cannot migrate or write into a fallback
     after that clear. */
  const run = conversationState.mutationTail.then(
    () => deletionEpoch === conversationState.deletionEpoch
      ? operation(() => deletionEpoch === conversationState.deletionEpoch)
      : false);
  conversationState.mutationTail = run.catch(() => {});
  return run;
}

function conversationStore() {
  // A Temporary conversation writes to memory and reads from memory, so the
  // durable chain is never resolved on its behalf and never demoted by it.
  if (isTemporary()) {
    const store = temporaryStore();
    renderConversationStorageStatus(store);
    return Promise.resolve(store);
  }
  if (!conversationState.storeRead) conversationState.storeRead = resolveConversationStore();
  return conversationState.storeRead.then(store => {
    renderConversationStorageStatus(store);
    return store;
  });
}

function durableConversationStore() {
  // The panel lists what the durable chain holds whatever the live
  // conversation is, so a Temporary conversation hides no saved row. The status
  // line follows the live conversation instead: a Temporary one has already
  // written its own line and the durable chain's name would replace it.
  if (!conversationState.storeRead) conversationState.storeRead = resolveConversationStore();
  return conversationState.storeRead.then(store => {
    if (!isTemporary()) renderConversationStorageStatus(store);
    return store;
  });
}

export async function readConversationRecord(id) {
  try {
    return await (await conversationStore()).read(id);
  } catch {
    return null;
  }
}

function rememberSelectedConversation(id) {
  // A Temporary conversation names itself nowhere a reload reads, so the
  // remembered selection keeps naming the durable conversation it left.
  if (isTemporary()) return;
  writeBrowserStorage('localStorage', CONVERSATION_SELECTED_KEY, id || null);
}

export function rememberUserMessage(content, shown, omittedAttachments = []) {
  const entry = { role: 'user', content, shown };
  if (omittedAttachments.length) {
    entry.omitted_attachments = omittedAttachments.map(attachment => ({
      name: attachment.name,
      mime: attachment.mime
    }));
  }
  conversationState.messages.push(entry);
  if (!conversationState.title) {
    const heading = (shown || content || '').trim().replace(/\s+/g, ' ');
    conversationState.title = heading
      ? prefixAtWholeCodePoint(heading, CONVERSATION_TITLE_CHARACTER_CAP)
      : 'untitled';
  }
  return entry;
}

export function rememberAssistantMessage(message, servedModel, reasoning) {
  const entry = {
    role: 'assistant',
    content: message.content || '',
    model: servedModel || '',
    reasoning: reasoning || '',
    artifacts: []
  };
  if (Array.isArray(message.tool_calls) && message.tool_calls.length) {
    entry.tool_calls = message.tool_calls.map(call => ({
      id: call.id,
      type: 'function',
      function: { name: call.function.name, arguments: call.function.arguments }
    }));
  }
  conversationState.messages.push(entry);
  conversationState.activeAssistantEntry = entry;
  conversationState.activeAssistantGeneration = conversationState.generation;
  return entry;
}

export function rememberToolMessage(callId, toolName, content) {
  conversationState.messages.push({
    role: 'tool', tool_call_id: callId, name: toolName, content
  });
}

export function nextArtifactReference() {
  let highest = 0;
  for (const message of conversationState.messages) {
    for (const artifact of (message && message.artifacts) || []) {
      const match = typeof artifact.reference === 'string' &&
        artifact.reference.match(/^image-([1-9][0-9]*)$/);
      if (match) highest = Math.max(highest, Number(match[1]));
    }
  }
  return `image-${highest + 1}`;
}

export function rememberArtifact(entry, entryGeneration, fields, result) {
  /* Record the two identifying fields the tool result carries and the geometry
     the approval bound, under the message entry the caller names -- the
     card's own lineage.entry rather than whichever assistant message this
     page most recently remembered, so a correction approved after later
     turns still lands on the entry that proposed the original generation.
     The grant is spent inside the request that produced this digest and
     reaches neither the record nor `history`. Returns the array entry this
     card now owns, or null where the entry named a conversation this page no
     longer holds. */
  if (!entry || entryGeneration !== conversationState.generation) return null;
  if (!Array.isArray(entry.artifacts)) entry.artifacts = [];
  const record = {
    reference: nextArtifactReference(),
    sha256: result.sha256,
    provenanceUrl: result.provenanceUrl,
    prompt: fields.prompt,
    seed: fields.seed,
    width: fields.width,
    height: fields.height,
    steps: fields.steps,
    profile: fields.profile
  };
  entry.artifacts.push(record);
  return record;
}

export function forgetArtifact(entry, entryGeneration, record) {
  /* Remove one artifact a card's own remove button released, from the exact
     entry rememberArtifact wrote it into. A conversation Reset or switch
     already cleared conversationState.messages by the time this runs against a
     stale generation, so entryGeneration guards against splicing a record
     into an array that belongs to a different, unrelated transcript now
     sharing the variable name. */
  if (!entry || entryGeneration !== conversationState.generation || !record) return;
  if (!Array.isArray(entry.artifacts)) return;
  const index = entry.artifacts.indexOf(record);
  if (index !== -1) entry.artifacts.splice(index, 1);
}

async function migrateReadableRecords(failedStore, nextStore) {
  /* Carry every record a demoted store can still read into the store that
     replaces it, best effort. A store that refuses a write can still answer
     list()/read() -- the probe that selected it in the first place proved as
     much -- so excluding it from every later operation would otherwise hide
     conversations that saved successfully before the failure: they would
     stay in the failed store, off the sidebar, and unopenable for the rest
     of the page session. One record's own migration failure does not block
     the rest. */
  let entries;
  try {
    entries = await failedStore.list();
  } catch {
    return;
  }
  for (const entry of entries) {
    try {
      const record = await failedStore.read(entry.id);
      if (!record) continue;
      // The store this migrates into can already hold its own copy of the
      // same id -- an earlier session that ran entirely on the fallback
      // while this one opened on a store that read as healthy -- and that
      // copy can be the newer one. A stale record from the store being left
      // must not overwrite it, so only a copy this store lacks or one this
      // record's own `updated` postdates is written.
      let existing = null;
      try { existing = await nextStore.read(entry.id); } catch { /* treated as absent */ }
      if (existing && Number(existing.updated) >= Number(record.updated)) continue;
      await nextStore.write(record);
    } catch { /* this one record stays only in the store that is being left */ }
  }
}

async function writeThroughFallbackStore(operation, mutationIsCurrent = () => true) {
  /* Run one mutating store call -- write() or remove() -- through demotion,
     migration, and retry, so a rename or a delete does not silently fail
     against a store that answered its own probe but refuses this real
     operation, and does not leave that store selected for whatever call
     happens to run next.

     A store that opened and answered its own probe can still refuse a later
     write -- a quota, a denied transaction -- and more than one backend can
     fail this way in the same call: IndexedDB over a denied transaction,
     then localStorage over the same quota. Each failure excludes that
     store's own name and demotes the cached resolution, so the next
     iteration's conversationStore() call re-runs resolveConversationStore()
     past every store that has already failed -- its own list()/setItem()
     probes are reads and would otherwise pass again for a store that permits
     reads and refuses writes -- and retries the same operation rather than
     leaving it to whatever later call happens to run next.
     memoryConversationStore() never throws, so at most three attempts are
     ever needed. */
  for (let attempt = 0; attempt < 3; attempt++) {
    if (!mutationIsCurrent()) return false;
    const activeStore = await conversationStore();
    if (!mutationIsCurrent()) return false;
    try {
      await operation(activeStore);
      return true;
    } catch {
      if (!mutationIsCurrent()) return false;
      rememberDemotedConversationStore(activeStore.name);
      conversationState.storeRead = null;
      const nextStore = await conversationStore();
      if (!mutationIsCurrent()) return false;
      await migrateReadableRecords(activeStore, nextStore);
    }
  }
  return false;
}

export async function saveConversation() {
  if (!conversationState.id) return;
  // The JSON round trip is the projection boundary: the record the store keeps
  // shares no object with the live transcript, so a later mutation of a message
  // reaches the store through a save rather than behind one.
  let record;
  try {
    record = JSON.parse(JSON.stringify({
      id: conversationState.id,
      title: conversationState.title || 'untitled',
      updated: Date.now(),
      messages: conversationState.messages
    }));
  } catch {
    return;
  }
  await queueConversationMutation(async mutationIsCurrent => {
    const written = await writeThroughFallbackStore(
      store => store.write(record), mutationIsCurrent);
    if (written && mutationIsCurrent()) await renderConversationList();
    return written;
  });
}

function restoredCallSequence(messages) {
  /* Continue the call-id counter past every id the record already holds, so a
     new tool call in a restored conversation names an id no earlier message
     answered. */
  let highest = -1;
  for (const entry of messages) {
    for (const call of (entry && entry.tool_calls) || []) {
      const match = typeof call.id === 'string' && call.id.match(/^call_(\d+)$/);
      if (match) highest = Math.max(highest, Number(match[1]));
    }
  }
  return highest + 1;
}

function renderRestoredArtifactCard(container, artifact, entry) {
  /* Rebuild one artifact card from its digest. The card takes its place in the
     turn while this call runs, so a restore that reads several artifacts over
     the network keeps each one between the round that generated it and the
     round that describes it; the bytes arrive into the card that is already
     there.

     The image comes back over the listener's own credentialed route rather
     than out of the record, so a conversation costs the digest and the
     geometry in the store whatever the image weighs. A listener this page
     holds no origin for, or one that refuses the read, leaves the digest and
     the provenance route on the card with the reason beside them. */
  const card = document.createElement('figure');
  card.className = 'image-artifact';
  const caption = document.createElement('figcaption');
  caption.textContent = [
    `sha256 ${artifact.sha256}`,
    `seed ${artifact.seed}`,
    `${artifact.width}x${artifact.height}`,
    `${artifact.steps} steps`,
    artifact.profile
  ].join(' | ');
  card.append(caption);
  container.append(card);
  // A reset or a switch during this fetch detaches the card before the bytes
  // arrive: the controller aborts the fetch where the reset runs first, and
  // this generation check catches a fetch that had already passed its own
  // abort point, so a blob URL never joins the live restoredArtifactBlobUrls
  // set and never gets written into a card no longer in the document.
  const restoreGeneration = conversationState.generation;
  const controller = new AbortController();
  restoredArtifactControllers.add(controller);
  void (async () => {
    let blobUrl = null;
    try {
      blobUrl = await loadArtifactBlobUrl(artifact, controller.signal);
    } catch (error) {
      restoredArtifactControllers.delete(controller);
      if (restoreGeneration !== conversationState.generation) return;
      const note = document.createElement('div');
      note.className = 'meta bad';
      note.textContent = `the artifact did not load: ${error.message || error}; ` +
        `provenance ${artifact.provenanceUrl}`;
      card.append(note);
      return;
    }
    restoredArtifactControllers.delete(controller);
    if (restoreGeneration !== conversationState.generation) {
      try { URL.revokeObjectURL(blobUrl); } catch { /* a released page keeps none */ }
      return;
    }
    restoredArtifactBlobUrls.add(blobUrl);
    const image = document.createElement('img');
    image.alt = artifact.prompt || '';
    image.src = blobUrl;
    card.insertBefore(image, caption);
    const openLink = document.createElement('a');
    openLink.className = 'act image-artifact-open';
    openLink.textContent = 'open';
    openLink.href = blobUrl;
    openLink.target = '_blank';
    openLink.rel = 'noopener';
    card.append(openLink);
    const downloadLink = document.createElement('a');
    downloadLink.className = 'act image-artifact-download';
    downloadLink.textContent = 'download';
    downloadLink.href = blobUrl;
    downloadLink.download = `${artifact.reference}.png`;
    card.append(downloadLink);
    const reviewButton = document.createElement('button');
    reviewButton.className = 'act image-review-button';
    reviewButton.textContent = 'review';
    const reviewModel = registeredReviewModel(artifact.profile);
    reviewButton.hidden = !reviewModel;
    reviewButton.onclick = () => { void runImageReview(card, artifact, {
      sha256: artifact.sha256,
      state: { correctionsUsed: 0 },
      model: entry && entry.model,
      cancelToolName: null,
      bounds: null,
      reviewModel,
      entry,
      entryGeneration: restoreGeneration,
      container
    }); };
    card.append(reviewButton);
  })();
  return card;
}

function renderRestoredAssistantTurn(entry, sharedRoot) {
  const view = sharedRoot ? openRoundInTurn(sharedRoot) : turn('qwen');
  void appendModelBadge(view.who, entry.model);
  view.body.textContent = entry.content || '';
  if (entry.reasoning) {
    const think = document.createElement('details');
    think.className = 'think';
    const summary = document.createElement('summary');
    summary.textContent = 'reasoning';
    const thinkBody = document.createElement('div');
    thinkBody.className = 'body';
    thinkBody.textContent = entry.reasoning;
    think.append(summary, thinkBody);
    view.root.insertBefore(think, view.body);
  }
  if (Array.isArray(entry.tool_calls) && entry.tool_calls.length) {
    const proposal = document.createElement('pre');
    proposal.className = 'tool';
    proposal.textContent = entry.tool_calls
      .map(call => `${call.function.name}(${call.function.arguments})`).join('\n');
    view.root.append(proposal);
  }
  for (const artifact of entry.artifacts || []) {
    if (!artifact.reference) artifact.reference = nextArtifactReference();
    renderRestoredArtifactCard(view.root, artifact, entry);
  }
  return view.root;
}

function restoredUserText(entry) {
  /* Saved image bytes never enter a conversation record. New records carry a
     typed description of each omission, while older records retain the
     omission marker in content. The restored transcript makes both cases
     visible and names the action needed before the image can be used again. */
  const shown = entry.shown ?? entry.content;
  const structuredOmissions = Array.isArray(entry.omitted_attachments)
    ? entry.omitted_attachments.filter(attachment =>
      attachment && typeof attachment.name === 'string')
    : [];
  const legacyOmission = typeof entry.content === 'string' &&
    entry.content.includes('[image attachment omitted from saved conversation:');
  if (!structuredOmissions.length && !legacyOmission) return shown;
  const names = structuredOmissions.map(attachment => attachment.name).join(', ');
  const subject = names ? ' (' + names + ')' : '';
  return shown + '\n[image pixels' + subject +
    ' were omitted from the saved conversation; reattach the image before continuing this request]';
}

export function restoreTranscript() {
  /* Rebuild `history` and the log from the record. A tool message restores into
     `history` and renders nothing, which is what the live path shows: the log
     carries the proposed call and the answer the model wrote after reading the
     result. */
  history.length = 0;
  // A tool-calling assistant message opens a turn its continuation rounds join,
  // the grouping the live path renders, so a restored image keeps the answer
  // that follows it under the same speaker.
  let continuationRoot = null;
  for (const entry of conversationState.messages) {
    if (!entry || typeof entry.role !== 'string') continue;
    if (entry.role === 'user') {
      history.push({ role: 'user', content: entry.content });
      turn('you', 'me').body.textContent = restoredUserText(entry);
      continuationRoot = null;
      continue;
    }
    if (entry.role === 'tool') {
      history.push({
        role: 'tool', tool_call_id: entry.tool_call_id,
        name: entry.name, content: entry.content
      });
      continue;
    }
    const message = { role: 'assistant', content: entry.content };
    if (Array.isArray(entry.tool_calls) && entry.tool_calls.length) {
      message.tool_calls = entry.tool_calls;
    }
    history.push(message);
    const root = renderRestoredAssistantTurn(entry, continuationRoot);
    continuationRoot = message.tool_calls ? root : null;
  }
  chatState.toolCallSequence = restoredCallSequence(conversationState.messages);
}

export function resetConversationState() {
  conversationState.generation++;
  clearWebResultHandles();
  attachments.length = 0;
  renderAttached();
  history.length = 0;
  chatState.toolCallSequence = 0;
  conversationState.messages = [];
  conversationState.activeAssistantEntry = null;
  conversationState.activeAssistantGeneration = -1;
  for (const controller of restoredArtifactControllers) {
    try { controller.abort(); } catch { /* an already-settled fetch ignores this */ }
  }
  restoredArtifactControllers.clear();
  for (const blobUrl of restoredArtifactBlobUrls) {
    try { URL.revokeObjectURL(blobUrl); } catch { /* a released page keeps none */ }
  }
  restoredArtifactBlobUrls.clear();
  logElement().textContent = '';
}

export function conversationHashId() {
  try {
    const match = (window.location.hash || '').match(/^#\/c\/([A-Za-z0-9_-]{1,64})$/);
    return match ? match[1] : null;
  } catch {
    // A context without a location leaves the conversation unrouted and the
    // remembered selection authoritative.
    return null;
  }
}

function setConversationHash(id) {
  try {
    window.location.hash = id ? `#/c/${id}` : '';
  } catch { /* an unrouted page keeps the selection in the store alone */ }
}

export function startNewConversation(route = true) {
  /* Open an empty durable conversation. The record reaches the store on the
     first message rather than here, so a page opened and left alone adds no
     row to the panel. */
  endTemporary();
  resetConversationState();
  conversationState.id = newConversationId();
  conversationState.title = '';
  rememberSelectedConversation(conversationState.id);
  if (route) setConversationHash(conversationState.id);
  void renderConversationList();
  return conversationState.id;
}

export async function startTemporaryConversation() {
  /* Open an empty Temporary conversation and mark it before its first message.

     The banner and the storage line both render here, so a reader who types
     the first message has already read what happens to it. The id is generated
     the way a durable one is and names nothing on disk: `conversationStore()`
     answers with the memory store for the whole life of this conversation and
     `rememberSelectedConversation` writes nothing. */
  endTemporary();
  resetConversationState();
  startTemporary();
  conversationState.id = newConversationId();
  conversationState.title = '';
  setConversationHash('');
  renderConversationStorageStatus(temporaryStore());
  await renderConversationList();
  return conversationState.id;
}

export async function switchConversation(id, route = true) {
  if (chatState.busy || !CONVERSATION_ID_PATTERN.test(id)) {
    // A hashchange lands after the address bar already moved, so a refused
    // switch writes the route back to the conversation on screen rather than
    // leaving the URL naming one this page never opened. The write raises one
    // further hashchange whose id already matches, which ends there.
    setConversationHash(conversationState.id);
    return false;
  }
  const switchGeneration = conversationState.generation;
  const switchDeletionEpoch = conversationState.deletionEpoch;
  const record = await readConversationRecord(id);
  if (chatState.busy || switchGeneration !== conversationState.generation ||
      switchDeletionEpoch !== conversationState.deletionEpoch) {
    // A send started during this read now owns the in-flight turn, so this
    // switch leaves it running rather than discarding it with a reset; the
    // address bar returns to the conversation actually on screen, the way
    // the chatState.busy check above already does when the switch never started.
    setConversationHash(conversationState.id);
    return false;
  }
  endTemporary();
  resetConversationState();
  conversationState.id = id;
  conversationState.title = (record && record.title) || '';
  conversationState.messages = record && Array.isArray(record.messages) ? record.messages : [];
  rememberSelectedConversation(id);
  if (route) setConversationHash(id);
  restoreTranscript();
  await renderConversationList();
  return true;
}

export async function renameConversation(id) {
  const renameDeletionEpoch = conversationState.deletionEpoch;
  const record = await readConversationRecord(id);
  if (!record || renameDeletionEpoch !== conversationState.deletionEpoch) return;
  let proposed = null;
  try {
    proposed = window.prompt('Conversation name', record.title || '');
  } catch {
    proposed = null;
  }
  if (proposed === null) return;
  const title = prefixAtWholeCodePoint(
    proposed.trim().replace(/\s+/g, ' ') || 'untitled', CONVERSATION_TITLE_CHARACTER_CAP);
  record.title = title;
  if (id === conversationState.id) conversationState.title = title;
  await queueConversationMutation(async mutationIsCurrent => {
    const written = await writeThroughFallbackStore(
      store => store.write(record), mutationIsCurrent);
    if (written && mutationIsCurrent()) await renderConversationList();
    return written;
  }, renameDeletionEpoch);
}

export async function deleteConversation(id) {
  const removed = await queueConversationMutation(mutationIsCurrent =>
    writeThroughFallbackStore(store => store.remove(id), mutationIsCurrent));
  if (!removed) return;
  if (id === conversationState.id) startNewConversation();
  await renderConversationList();
}

export async function deleteAllSavedConversations() {
  let confirmed = false;
  try {
    confirmed = window.confirm(
      'Delete every saved conversation from this browser? This cannot be undone.');
  } catch { /* a context without confirmation refuses deletion */ }
  if (!confirmed) return false;
  // Reset first: an in-flight turn keeps running at the transport layer, but
  // its generation can no longer append to or save the conversation removed
  // by the clear. The fresh unsaved conversation receives its identity at
  // confirmation, before any queued clear can yield to a new user turn.
  resetConversationState();
  const deletionEpoch = ++conversationState.deletionEpoch;
  conversationState.id = newConversationId();
  conversationState.title = '';
  rememberSelectedConversation(conversationState.id);
  setConversationHash(conversationState.id);
  return queueConversationMutation(async mutationIsCurrent => {
    const outcomes = [];
    const activeStore = await conversationStore();
    if (activeStore.name === 'memory') {
      try { await activeStore.clear(); outcomes.push('memory=cleared'); }
      catch (error) { outcomes.push(`memory=failed:${error.message || error}`); }
    }
    if (typeof indexedDB === 'undefined' || !indexedDB) {
      outcomes.push('indexeddb=unavailable');
    } else {
      try {
        const database = await openConversationDatabase();
        await indexedDatabaseConversationStore(database).clear();
        outcomes.push('indexeddb=cleared');
      } catch (error) {
        outcomes.push(`indexeddb=failed:${error.message || error}`);
      }
    }
    try {
      const storage = window['localStorage'];
      if (!storage) outcomes.push('localstorage=unavailable');
      else {
        await browserStorageConversationStore().clear();
        outcomes.push('localstorage=cleared');
      }
    } catch (error) {
      outcomes.push(`localstorage=failed:${error.message || error}`);
    }
    if (!mutationIsCurrent()) return false;
    writeBrowserStorage('localStorage', CONVERSATION_SELECTED_KEY, null);
    rememberSelectedConversation(conversationState.id);
    await renderConversationList();
    const failures = outcomes.filter(outcome => outcome.includes('=failed:'));
    if (failures.length) {
      try { window.alert(`Saved conversation deletion is incomplete. ${outcomes.join('; ')}`); }
      catch { /* the returned false remains the programmatic result */ }
      return false;
    }
    return true;
  }, deletionEpoch);
}

export async function renderConversationList() {
  const list = $('#conversation-list');
  let entries = [];
  try {
    entries = await (await durableConversationStore()).list();
  } catch {
    entries = [];
  }
  entries.sort((first, second) => (second.updated || 0) - (first.updated || 0));
  list.textContent = '';
  if (!entries.length) {
    const empty = document.createElement('div');
    empty.id = 'conversation-empty';
    empty.textContent = 'this store holds no saved conversation yet';
    list.append(empty);
    return;
  }
  for (const entry of entries) {
    const row = document.createElement('div');
    row.className = 'conversation-row' + (entry.id === conversationState.id ? ' selected' : '');
    const open = document.createElement('button');
    open.className = 'open';
    open.textContent = entry.title || 'untitled';
    open.onclick = () => { void switchConversation(entry.id); };
    const rename = document.createElement('button');
    rename.className = 'small';
    rename.textContent = 'rename';
    rename.onclick = () => { void renameConversation(entry.id); };
    const remove = document.createElement('button');
    remove.className = 'small';
    remove.textContent = 'delete';
    remove.onclick = () => { void deleteConversation(entry.id); };
    row.append(open, rename, remove);
    list.append(row);
  }
}

export async function initConversations() {
  /* The route names the conversation, the remembered selection names it where
     the route is silent, and a name neither store answers for opens an empty
     conversation instead of an error. */
  // The store lookup below awaits IndexedDB's own async open, which a click on
  // New or a routed switch can land inside; either bumps conversationState.generation
  // through resetConversationState(). This resumption then applies against a
  // generation the page has already left, which would replace the
  // user-opened conversation with the one this boot was resolving.
  const initGeneration = conversationState.generation;
  const routed = conversationHashId();
  const remembered = readBrowserStorage('localStorage', CONVERSATION_SELECTED_KEY);
  const candidate = routed ||
    (remembered && CONVERSATION_ID_PATTERN.test(remembered) ? remembered : null);
  const record = candidate ? await readConversationRecord(candidate) : null;
  if (conversationState.generation !== initGeneration) return;
  if (candidate && record) {
    await switchConversation(candidate, routed === null);
    return;
  }
  // A routed id with no matching record still names the address bar: routing
  // the freshly generated id keeps the URL naming the conversation this page
  // now holds, rather than reloading into an id whose record never existed
  // either. Where no route was present, none is added.
  startNewConversation(routed !== null);
  await renderConversationList();
}

export async function exportBrowserHistory() {
  /* Return every durable record this browser holds, verbatim, under one schema
     key.

     A record travels as the store wrote it: the export names what it is and
     adds nothing, so a reader comparing an exported record against the store
     compares equal values rather than a second projection's idea of them. A
     Temporary conversation is excluded by construction, because the durable
     chain never held it. A record the store refuses to read is left out and
     counted, so an export states what it could not reach rather than implying
     the browser held nothing there. */
  const store = await durableConversationStore();
  const summaries = await store.list();
  const records = [];
  let unreadable = 0;
  for (const summary of summaries) {
    let record = null;
    try {
      record = await store.read(summary.id);
    } catch {
      record = null;
    }
    if (record) records.push(record);
    else unreadable += 1;
  }
  // The document's top level is the shape `web/browser_import.py` reads:
  // the schema key carrying the version, the export instant, and the
  // conversations verbatim. The store name and the unreadable count describe
  // this export rather than the history, so they travel beside the document.
  const document_ = {
    [HISTORY_EXPORT_SCHEMA]: HISTORY_EXPORT_VERSION,
    exported_utc: new Date().toISOString(),
    conversations: records
  };
  return { document: document_, store: store.name, unreadable };
}

export function historyExportFilename(document_) {
  const stamp = String(document_.exported_utc || '').replace(/[:.]/g, '-') || 'export';
  return `qwen-apu-browser-history-${stamp}.json`;
}

export function initConversationPanel() {
  $('#conversation-new').onclick = () => { startNewConversation(); };
  $('#conversation-temporary').onclick = () => { void startTemporaryConversation(); };
  $('#conversation-delete-all').onclick = () => { void deleteAllSavedConversations(); };
  if (typeof window.addEventListener === 'function') {
    window.addEventListener('hashchange', () => {
      const routed = conversationHashId();
      if (routed && routed !== conversationState.id) void switchConversation(routed, false);
    });
  }
}

/* send() awaits this before it reads or mutates conversationState.id, so a send
   that lands during the IndexedDB open window this promise covers joins the
   conversation initConversations() settles on instead of running with
   conversationState.id still null, where every save() call already no-ops and a
   remembered record's own switchConversation() would otherwise discard the
   in-flight turn as a busy conflict. `startConversations()` is what arms it, so
   importing this module opens no database. */
export let conversationsReady = Promise.resolve();

export function startConversations() {
  conversationsReady = initConversations();
  return conversationsReady;
}
