// A conversation is a durable record with a URL, and this test holds
// static/js/conversations.js to what the record carries and what a restore
// rebuilds from it.
//
// Four properties decide the feature. A store answers in the declared order,
// IndexedDB first and an in-memory Map where both browser stores refuse. The
// serialized record holds the transcript and the artifact digest and holds no
// grant or session secret while the page's own state carries both. A restore
// rebuilds `history` and refetches the artifact by digest over the gateway's
// own route rather than reading bytes out of the store. The `#/c/<id>` route
// selects the conversation a second page load opens.

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bootPage,
  flushPromises,
  jsonResponse,
  makeDeniedStorage,
  makeFakeIndexedDatabase,
  makeFakeStorage,
  makeFlakyStorage,
  pngResponse,
  registryRow,
  FIXTURE_PNG_SHA256
} from './page.mjs';

const SERVED_MODEL = 'image-capable';
const ROW = registryRow(SERVED_MODEL, { context_default: 4096, projector: 'required' });

const FIXTURE = {
  sessionSecret: 'fixture-session-secret-91abcd',
  grant: 'fixture-grant-token-77cdef',
  userContent: 'draw a fox in a snowy field',
  assistantContent: 'Here is the fox.',
  reasoning: 'the request names one subject',
  callArguments: JSON.stringify({
    prompt: 'a fox in a snowy field', profile_id: 'sdxs-512-arm-a',
    width: 512, height: 512, steps: 4
  }),
  fields: {
    prompt: 'a fox in a snowy field', negative_prompt: 'blurry',
    seed: 785835124, width: 512, height: 512, steps: 4, profile: 'sdxs-512-arm-a'
  },
  result: {
    sha256: FIXTURE_PNG_SHA256,
    provenanceUrl: `/api/artifacts/${FIXTURE_PNG_SHA256}.json`
  }
};
FIXTURE.toolContent =
  `Image artifact image-1 is available in this conversation.`;

async function conversationPage(options = {}) {
  return bootPage({ rows: [ROW], ...options });
}

async function runFixtureTurn(page) {
  /* Write one image turn the way the dispatch path writes it.

     The page's own approval session secret is live while the record is
     written, which is what makes its absence from the store a property of the
     projection rather than of an empty page. */
  const { chat, conversations, artifacts } = page.modules;
  chat.history.push({ role: 'user', content: FIXTURE.userContent });
  conversations.rememberUserMessage(FIXTURE.userContent, FIXTURE.userContent);
  const message = {
    role: 'assistant',
    content: FIXTURE.assistantContent,
    tool_calls: [{
      id: 'call_0',
      type: 'function',
      function: { name: artifacts.IMAGE_TOOL_NAME, arguments: FIXTURE.callArguments }
    }]
  };
  chat.history.push(message);
  conversations.rememberAssistantMessage(message, SERVED_MODEL, FIXTURE.reasoning);
  // imageRequestParams() is what carries the grant to the served path, so it is
  // built here exactly as the dispatch path builds it and never handed to the
  // record.
  const params = artifacts.imageRequestParams(FIXTURE.fields, FIXTURE.grant);
  assert.equal(params.authorization, FIXTURE.grant, 'the grant did not reach the params');
  conversations.rememberArtifact(
    conversations.conversationState.activeAssistantEntry,
    conversations.conversationState.activeAssistantGeneration,
    FIXTURE.fields, FIXTURE.result);
  chat.history.push({
    role: 'tool', tool_call_id: 'call_0', name: artifacts.IMAGE_TOOL_NAME,
    content: FIXTURE.toolContent
  });
  conversations.rememberToolMessage('call_0', artifacts.IMAGE_TOOL_NAME, FIXTURE.toolContent);
  await conversations.saveConversation();
  return conversations.conversationState.id;
}

test('IndexedDB answers first and the record carries the projection alone', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  const id = await runFixtureTurn(page);
  await flushPromises();

  assert.equal(page.element('#conversation-storage-status').textContent,
    'Conversation history is saved in this browser.');

  const record = await conversations.readConversationRecord(id);
  assert.ok(record, 'the store holds no record for the conversation just saved');
  assert.equal(record.messages.length, 3);
  assert.equal(record.messages[0].role, 'user');
  assert.equal(record.messages[1].role, 'assistant');
  assert.equal(record.messages[1].model, SERVED_MODEL);
  assert.equal(record.messages[1].reasoning, FIXTURE.reasoning);
  assert.equal(record.messages[1].tool_calls[0].function.arguments, FIXTURE.callArguments);
  assert.equal(record.messages[1].artifacts[0].sha256, FIXTURE.result.sha256);
  assert.equal(record.messages[1].artifacts[0].seed, FIXTURE.fields.seed);
  assert.equal(record.messages[1].artifacts[0].reference, 'image-1');
  assert.equal(record.messages[2].role, 'tool');

  const serialized = JSON.stringify(record);
  for (const secret of [FIXTURE.grant, FIXTURE.sessionSecret]) {
    assert.ok(!serialized.includes(secret), 'a credential reached the conversation record');
  }
  assert.ok(!serialized.includes('image/png'), 'image bytes reached the conversation record');
});

test('a restore rebuilds history and refetches the artifact by digest', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const first = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const id = await runFixtureTurn(first);
  await flushPromises();

  const second = await conversationPage({
    indexedDatabase, localStorage: makeFakeStorage(), hash: `#/c/${id}` });
  await flushPromises();
  const { conversations, chat } = second.modules;
  assert.equal(conversations.conversationState.id, id,
    'the `#/c/<id>` route did not select the conversation it names');
  assert.equal(chat.history.length, 3, 'the restore rebuilt a different transcript');
  assert.equal(chat.history[0].content, FIXTURE.userContent);
  assert.equal(chat.history[1].tool_calls[0].id, 'call_0');
  assert.equal(chat.history[2].role, 'tool');
  assert.equal(chat.chatState.toolCallSequence, 1,
    'the restored call counter would reuse an id the record already holds');

  const artifactRead = await second.take(
    request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
    'the restored artifact read');
  artifactRead.resolve(pngResponse(200));
  await flushPromises();
  assert.equal(conversations.conversationState.messages[1].artifacts[0].sha256,
    FIXTURE.result.sha256);
});

test('localStorage carries the record where IndexedDB is absent', async () => {
  const localStorage = makeFakeStorage();
  const page = await conversationPage({ localStorage });
  const id = await runFixtureTurn(page);
  await flushPromises();
  assert.equal(page.element('#conversation-storage-status').textContent,
    'Conversation history is saved in this browser.');
  const raw = localStorage.getItem(`qwen-apu-conversation:${id}`);
  assert.ok(raw, 'localStorage holds no record where IndexedDB is absent');
  assert.equal(JSON.parse(raw).messages.length, 3);
  const index = JSON.parse(localStorage.getItem('qwen-apu-conversation-index'));
  assert.deepEqual(index.map(entry => entry.id), [id]);
});

test('both browser stores denied leaves the page on its own memory', async () => {
  const page = await conversationPage({
    localStorage: makeDeniedStorage(), sessionStorage: makeDeniedStorage() });
  const id = await runFixtureTurn(page);
  await flushPromises();
  const status = page.element('#conversation-storage-status');
  assert.equal(status.className, 'meta bad');
  assert.match(status.textContent, /temporary and will disappear/);
  const record = await page.modules.conversations.readConversationRecord(id);
  assert.ok(record, 'the memory store lost the record it just wrote');
  assert.equal(record.messages.length, 3);
});

test('a store that answers its probe and refuses a write is demoted once', async () => {
  const failWrites = { active: true };
  const page = await conversationPage({ localStorage: makeFlakyStorage(failWrites) });
  const id = await runFixtureTurn(page);
  await flushPromises();
  // The write refused, so the resolution demoted localstorage and the memory
  // store took the record rather than the save being silently dropped.
  const record = await page.modules.conversations.readConversationRecord(id);
  assert.ok(record, 'a refused write lost the record instead of demoting the store');
  assert.equal(record.messages.length, 3);
  assert.match(page.element('#conversation-storage-status').textContent,
    /temporary and will disappear/);
});

test('the panel lists every saved conversation and marks the open one', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  await runFixtureTurn(page);
  await flushPromises();
  conversations.startNewConversation();
  conversations.rememberUserMessage('a second question', 'a second question');
  await conversations.saveConversation();
  await flushPromises();
  await conversations.renderConversationList();
  await flushPromises();
  const rows = page.element('#conversation-list').children;
  assert.equal(rows.length, 2, 'the panel lists a number of conversations other than two');
  const titles = rows.map(row => row.textContent);
  // The title is the first user message, capped at its own character bound.
  assert.ok(titles.some(text => text.includes(FIXTURE.userContent)));
  assert.ok(titles.some(text => text.includes('a second question')));
  const selected = rows.filter(row => row.className.includes('selected'));
  assert.equal(selected.length, 1, 'the panel marks other than one open conversation');
  assert.ok(selected[0].textContent.includes('a second question'),
    'the panel marks a conversation other than the open one');
});

test('a rename and a delete both reach the store', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  const id = await runFixtureTurn(page);
  await flushPromises();

  page.harness.window.promptAnswer = 'renamed conversation';
  await conversations.renameConversation(id);
  await flushPromises();
  assert.equal((await conversations.readConversationRecord(id)).title, 'renamed conversation');

  await conversations.deleteConversation(id);
  await flushPromises();
  assert.equal(await conversations.readConversationRecord(id), null,
    'a deleted conversation is still readable');
  assert.notEqual(conversations.conversationState.id, id,
    'deleting the open conversation left the page on the record it removed');
});

test('delete-all clears every store and opens a fresh conversation', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const localStorage = makeFakeStorage();
  const page = await conversationPage({ indexedDatabase, localStorage });
  const { conversations } = page.modules;
  const id = await runFixtureTurn(page);
  await flushPromises();
  page.harness.window.confirmAnswer = true;
  const cleared = await conversations.deleteAllSavedConversations();
  await flushPromises();
  assert.equal(cleared, true, 'delete-all reported an incomplete clear');
  assert.equal(await conversations.readConversationRecord(id), null);
  assert.notEqual(conversations.conversationState.id, id);
  assert.equal(localStorage.getItem('qwen-apu-conversation-selected'),
    conversations.conversationState.id,
    'the fresh conversation is not the remembered selection');
});

test('a refused confirmation deletes nothing', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  const id = await runFixtureTurn(page);
  await flushPromises();
  page.harness.window.confirmAnswer = false;
  const cleared = await conversations.deleteAllSavedConversations();
  assert.equal(cleared, false);
  assert.ok(await conversations.readConversationRecord(id),
    'a refused confirmation deleted a saved conversation');
});

test('a send saves the user turn ahead of the completion', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { chat, conversations } = page.modules;
  page.element('#input').value = 'a question the completion never answers';
  const sending = chat.send();
  await flushPromises();
  const completion = await page.take(request => request.url === '/api/chat', 'chat completion');
  const id = conversations.conversationState.id;
  const record = await conversations.readConversationRecord(id);
  assert.ok(record, 'the user turn reached no store before the completion');
  assert.equal(record.messages.at(-1).role, 'user');
  assert.equal(record.messages.at(-1).content, 'a question the completion never answers');
  completion.reject(new Error('the test ends the turn here'));
  await sending;
});

test('a hashchange to another conversation switches the page to it', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  const first = await runFixtureTurn(page);
  await flushPromises();
  conversations.startNewConversation();
  const second = conversations.conversationState.id;
  conversations.rememberUserMessage('a second question', 'a second question');
  await conversations.saveConversation();
  await flushPromises();

  page.harness.window.location.hash = `#/c/${first}`;
  page.fireHashChange();
  await flushPromises();
  assert.equal(conversations.conversationState.id, first,
    'a hashchange did not switch to the conversation it named');
  assert.notEqual(conversations.conversationState.id, second);
  const artifactRead = await page.take(
    request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
    'the restored artifact read');
  artifactRead.resolve(pngResponse(404));
  await flushPromises();
});

test('a switch during a running turn is refused', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { chat, conversations } = page.modules;
  const first = await runFixtureTurn(page);
  await flushPromises();
  conversations.startNewConversation();
  const open = conversations.conversationState.id;
  chat.chatState.busy = true;
  const switched = await conversations.switchConversation(first);
  chat.chatState.busy = false;
  assert.equal(switched, false, 'a switch during a running turn was admitted');
  assert.equal(conversations.conversationState.id, open,
    'a refused switch still replaced the open conversation');
});

test('an artifact attaches to the message its own lineage names', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const page = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const { conversations } = page.modules;
  const entry = conversations.rememberAssistantMessage(
    { role: 'assistant', content: 'first' }, SERVED_MODEL, '');
  const generation = conversations.conversationState.generation;
  // A later assistant message moves the page's own active entry; an artifact
  // named against the earlier entry still lands there.
  conversations.rememberAssistantMessage(
    { role: 'assistant', content: 'second' }, SERVED_MODEL, '');
  const record = conversations.rememberArtifact(
    entry, generation, FIXTURE.fields, FIXTURE.result);
  assert.ok(record, 'the artifact reached no entry');
  assert.equal(entry.artifacts.length, 1);
  assert.equal(conversations.conversationState.activeAssistantEntry.artifacts.length, 0,
    'the artifact landed on the message the page most recently remembered');

  conversations.forgetArtifact(entry, generation, record);
  assert.equal(entry.artifacts.length, 0, 'a removed artifact stayed in the record');

  // A generation the page has left names a transcript this page no longer
  // holds, so the digest is dropped rather than written into the record now
  // open.
  assert.equal(conversations.rememberArtifact(
    entry, generation - 1, FIXTURE.fields, FIXTURE.result), null);
});

test('a reset aborts a restored artifact read still in flight', async () => {
  const indexedDatabase = makeFakeIndexedDatabase();
  const first = await conversationPage({ indexedDatabase, localStorage: makeFakeStorage() });
  const id = await runFixtureTurn(first);
  await flushPromises();

  const second = await conversationPage({
    indexedDatabase, localStorage: makeFakeStorage(), hash: `#/c/${id}` });
  await flushPromises();
  const inFlight = second.harness.pending.find(
    request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`);
  assert.ok(inFlight, 'the restore issued no artifact read');
  second.modules.conversations.startNewConversation();
  await flushPromises();
  assert.ok(!second.harness.pending.includes(inFlight),
    'a reset left the restored artifact read in flight');
});
