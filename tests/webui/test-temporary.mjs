// A Temporary conversation is marked before its first message and reaches no
// browser store, and Export history writes every durable record out verbatim.
//
// Three properties decide the temporary lane. The banner and the storage line
// both render when the conversation opens rather than when a message lands, so
// a reader decides what to type from what the page already says. Every write
// goes to a memory store that lives for the tab alone, so neither IndexedDB nor
// localStorage holds the transcript and the remembered selection keeps naming
// the durable conversation the reader left. The panel keeps listing the durable
// chain, so a temporary conversation hides no saved row and appears in none.
//
// The export carries a version key beside the records the store holds, taken
// verbatim, and a temporary conversation is excluded by construction because
// the durable chain never held it.

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bootPage,
  flushPromises,
  makeFakeIndexedDatabase,
  makeFakeStorage,
  registryRow
} from './page.mjs';

const ROW = registryRow('model-A');

async function storePage(options = {}) {
  return bootPage({
    rows: [ROW],
    indexedDatabase: makeFakeIndexedDatabase(),
    localStorage: makeFakeStorage(),
    ...options
  });
}

test('a temporary conversation is marked before its first message', async () => {
  const page = await storePage();
  assert.equal(page.element('#temporary-banner').hidden, true,
    'a durable conversation raised the temporary banner');
  await page.modules.conversations.startTemporaryConversation();
  await flushPromises();
  assert.equal(page.modules.temporary.isTemporary(), true);
  assert.equal(page.element('#temporary-banner').hidden, false,
    'the temporary banner stayed hidden before the first message');
  assert.match(page.element('#conversation-storage-status').textContent,
    /reaches no browser store/);
  assert.equal(page.modules.conversations.conversationState.messages.length, 0,
    'the temporary conversation opened with a message already in it');
});

test('a temporary transcript reaches neither browser store', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const localStorage = makeFakeStorage();
  const page = await storePage({ indexedDatabase, localStorage });
  const { conversations } = page.modules;

  conversations.rememberUserMessage('a durable question', 'a durable question');
  await conversations.saveConversation();
  await flushPromises();
  const durableId = conversations.conversationState.id;

  await conversations.startTemporaryConversation();
  conversations.rememberUserMessage('a temporary question', 'a temporary question');
  await conversations.saveConversation();
  await flushPromises();
  const temporaryId = conversations.conversationState.id;

  assert.notEqual(temporaryId, durableId);
  assert.equal(localStorage.getItem(`qwen-apu-conversation:${temporaryId}`), null,
    'the temporary transcript reached localStorage');
  const indexed = [...indexedDatabase.databases.get('qwen-apu-conversations')
    .get('conversations').keys()];
  assert.ok(!indexed.includes(temporaryId), 'the temporary transcript reached IndexedDB');
  assert.ok(indexed.includes(durableId), 'the durable transcript reached no store');
  assert.equal(localStorage.getItem('qwen-apu-conversation-selected'), durableId,
    'the temporary conversation became the remembered selection');

  // The memory store answers its own reads for the life of the tab, so the
  // transcript is live without being durable.
  const held = await conversations.readConversationRecord(temporaryId);
  assert.ok(held, 'the temporary conversation lost its own transcript');
  assert.equal(held.messages[0].content, 'a temporary question');
});

test('the panel lists the durable chain while a temporary conversation is open', async () => {
  const page = await storePage();
  const { conversations } = page.modules;
  conversations.rememberUserMessage('a durable question', 'a durable question');
  await conversations.saveConversation();
  await flushPromises();
  await conversations.startTemporaryConversation();
  await flushPromises();
  const rows = page.element('#conversation-list').children.map(row => row.textContent);
  assert.equal(rows.length, 1, 'the panel lists a number of conversations other than one');
  assert.ok(rows[0].includes('a durable question'),
    'the panel hid the durable conversation behind the temporary one');
});

test('opening a durable conversation ends the temporary one', async () => {
  const page = await storePage();
  const { conversations, temporary } = page.modules;
  await conversations.startTemporaryConversation();
  assert.equal(temporary.isTemporary(), true);
  conversations.startNewConversation();
  assert.equal(temporary.isTemporary(), false,
    'New conversation left the page temporary');
  assert.equal(page.element('#temporary-banner').hidden, true,
    'New conversation left the temporary banner raised');
});

test('the export carries the version key and the records verbatim', async () => {
  const page = await storePage();
  const { conversations } = page.modules;
  conversations.rememberUserMessage('a durable question', 'a durable question');
  await conversations.saveConversation();
  await flushPromises();
  const durableId = conversations.conversationState.id;
  // Read the durable record while the durable chain is what answers, because a
  // Temporary conversation reads and writes its own memory store.
  const stored = await conversations.readConversationRecord(durableId);

  await conversations.startTemporaryConversation();
  conversations.rememberUserMessage('a temporary question', 'a temporary question');
  await conversations.saveConversation();
  await flushPromises();

  const document_ = await conversations.exportBrowserHistory();
  assert.equal(document_.schema, 'qwen_apu_browser_history_export');
  assert.equal(document_.version, 1);
  assert.equal(document_.unreadable, 0);
  assert.equal(document_.records.length, 1,
    'the export carries a number of records other than the durable one');
  const exported = document_.records[0];
  assert.equal(exported.id, durableId);
  assert.deepEqual(exported, stored,
    'the export projected the record rather than carrying it verbatim');
  assert.ok(!JSON.stringify(document_).includes('a temporary question'),
    'the export carried the temporary conversation');
});

test('the export filename names the document it carries', async () => {
  const page = await storePage();
  const { conversations } = page.modules;
  const name = conversations.historyExportFilename({ exported: '2026-09-11T10:20:30.500Z' });
  assert.equal(name, 'qwen-apu-browser-history-2026-09-11T10-20-30-500Z.json');
  assert.ok(name.endsWith('.json'));
});

test('the export control writes one download and reports what it wrote', async () => {
  const page = await storePage();
  const { conversations } = page.modules;
  conversations.rememberUserMessage('a durable question', 'a durable question');
  await conversations.saveConversation();
  await flushPromises();
  page.element('#conversation-export').onclick();
  await flushPromises();
  assert.match(page.element('#conversation-export-status').textContent,
    /exported 1 conversation from (indexeddb|localstorage|memory)/);
});
