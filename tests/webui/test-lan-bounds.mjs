// The page reads QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS from
// a meta tag alone. A LAN token bound is a resource ceiling the launch sets
// against every peer on the network, and a query parameter is exactly the input
// the peer being bounded controls from their own address bar, so the tag the
// served page carries is what stays out of that peer's reach.
//
// `initLanBounds()` reads the tags once per page, so each arm boots its own
// page with its own tags rather than mutating a value a previous arm resolved.

import assert from 'node:assert/strict';
import test from 'node:test';

import { bootPage, flushPromises, jsonResponse, registryRow } from './page.mjs';

const ROW = registryRow('model-A', { context_default: 24576 });
// An image turn is admitted against the registry's own projector pairing, so
// the image arms below boot a row the registry pairs with one.
const VISION_ROW = registryRow('model-A', { context_default: 24576, projector: 'required' });

function imageAttachment(modules) {
  modules.attachments.attachments.length = 0;
  modules.attachments.attachments.push({
    name: 'fixture.png', kind: 'image', mime: 'image/png',
    dataUrl: 'data:image/png;base64,aW1hZ2U=', tokens: null,
    tokenModel: modules.models.modelState.requestModel
  });
}

async function sendText(page, text) {
  page.element('#input').value = text;
  return page.modules.chat.send();
}

function logTexts(page) {
  return page.element('#log').children.map(child => child.textContent);
}

test('an ordinary launch names neither bound', async () => {
  const page = await bootPage({ rows: [ROW] });
  const { lanBounds } = page.modules.api;
  assert.equal(lanBounds.prompt, null);
  assert.equal(lanBounds.output, null);
  const body = await page.modules.chat.buildRequestBody(
    [{ role: 'user', content: 'hi' }], false, false);
  assert.equal(body.max_tokens, 512, 'no LAN bound leaves the page default');
});

test('the output bound narrows max_tokens and never widens it', async () => {
  const narrowed = await bootPage({
    rows: [ROW],
    meta: { 'qwen-lan-max-prompt-tokens': '1000', 'qwen-lan-max-output-tokens': '100' }
  });
  assert.equal(narrowed.modules.api.lanBounds.prompt, 1000);
  assert.equal(narrowed.modules.api.lanBounds.output, 100);
  const narrowBody = await narrowed.modules.chat.buildRequestBody(
    [{ role: 'user', content: 'hi' }], false, false);
  assert.equal(narrowBody.max_tokens, 100, 'the LAN output bound narrows max_tokens');

  const widened = await bootPage({
    rows: [ROW], meta: { 'qwen-lan-max-output-tokens': '800' }
  });
  const wideBody = await widened.modules.chat.buildRequestBody(
    [{ role: 'user', content: 'hi' }], false, false);
  assert.equal(wideBody.max_tokens, 512, 'a bound above the page default leaves it unchanged');
});

test('a malformed or non-positive value reads as no bound at all', async () => {
  const page = await bootPage({
    rows: [ROW],
    meta: { 'qwen-lan-max-prompt-tokens': 'not-a-number', 'qwen-lan-max-output-tokens': '0' }
  });
  assert.equal(page.modules.api.lanBounds.prompt, null);
  assert.equal(page.modules.api.lanBounds.output, null);
});

test('a prompt above the bound is refused ahead of any completion', async () => {
  const page = await bootPage({ rows: [ROW], meta: { 'qwen-lan-max-prompt-tokens': '10' } });
  const sent = sendText(page, 'a prompt the fixture will count as oversized');
  await flushPromises();
  (await page.take(request => request.url === '/api/models/tokenize', 'prompt tokenization'))
    .resolve(jsonResponse({ tokens: new Array(20).fill(1) }));
  await sent;
  assert.equal(page.modules.chat.history.length, 0,
    'the oversized prompt never enters history');
  const texts = logTexts(page);
  assert.ok(texts.some(text => text.includes('at least 20 tokens') &&
    text.includes('10-token bound')),
    `no oversized-prompt refusal in the transcript: ${JSON.stringify(texts)}`);
  assert.ok(!page.pending.some(request => request.url === '/api/chat'),
    'the refused turn still reached the chat route');
});

test('a prompt inside the bound proceeds to the completion', async () => {
  const page = await bootPage({ rows: [ROW], meta: { 'qwen-lan-max-prompt-tokens': '1000' } });
  const sent = sendText(page, 'a short prompt');
  await flushPromises();
  (await page.take(request => request.url === '/api/models/tokenize', 'prompt tokenization'))
    .resolve(jsonResponse({ tokens: [1, 2, 3] }));
  await flushPromises();
  (await page.take(request => request.url === '/api/chat', 'chat completion'))
    .reject(new Error('the harness ends the turn here'));
  await sent;
  assert.equal(page.modules.chat.history.length, 1, 'the admitted prompt enters history');
});

test('the count covers every prior turn rather than the new message alone', async () => {
  const page = await bootPage({ rows: [ROW], meta: { 'qwen-lan-max-prompt-tokens': '10' } });
  page.modules.chat.history.push({ role: 'user', content: 'an earlier turn' });
  page.modules.chat.history.push({ role: 'assistant', content: 'an earlier reply' });
  const before = page.modules.chat.history.length;
  const sent = sendText(page, 'hi');
  await flushPromises();
  const tokenize = (await page.take(
    request => request.url === '/api/models/tokenize', 'prompt tokenization'));
  const tokenized = JSON.parse(tokenize.options.body).content;
  assert.ok(tokenized.includes('an earlier turn') && tokenized.includes('an earlier reply'),
    `the tokenized text omits accumulated history: ${tokenized}`);
  tokenize.resolve(jsonResponse({ tokens: new Array(15).fill(1) }));
  await sent;
  assert.equal(page.modules.chat.history.length, before,
    'a short new message is admitted once accumulated history exceeds the bound');
});

test('an image send releases busy on both refusal paths', async () => {
  for (const outcome of ['failure', 'over-limit']) {
    const page = await bootPage({
      rows: [VISION_ROW], meta: { 'qwen-lan-max-prompt-tokens': '10' } });
    imageAttachment(page.modules);
    const sent = sendText(page, `image ${outcome}`);
    await flushPromises();
    const tokenize = (await page.take(
      request => request.url === '/api/models/tokenize', `image tokenizer ${outcome}`));
    if (outcome === 'failure') tokenize.reject(new Error('tokenizer unavailable'));
    else tokenize.resolve(jsonResponse({ tokens: new Array(20).fill(1) }));
    await sent;
    assert.equal(page.modules.chat.chatState.busy, false,
      `${outcome} left the image send busy`);

    page.modules.attachments.attachments.length = 0;
    const retry = sendText(page, 'retry');
    await flushPromises();
    (await page.take(request => request.url === '/api/models/tokenize',
      `retry tokenizer after ${outcome}`)).resolve(jsonResponse({ tokens: [1] }));
    await flushPromises();
    (await page.take(request => request.url === '/api/chat', `retry completion after ${outcome}`))
      .reject(new Error('retry reached completion'));
    await retry;
  }
});

test('a conversation reset during tokenization discards the image turn', async () => {
  const page = await bootPage({
    rows: [VISION_ROW], meta: { 'qwen-lan-max-prompt-tokens': '100' } });
  imageAttachment(page.modules);
  const sent = sendText(page, 'stale tokenizer');
  await flushPromises();
  const tokenize = (await page.take(
    request => request.url === '/api/models/tokenize', 'stale image tokenizer'));
  page.modules.conversations.startNewConversation();
  tokenize.resolve(jsonResponse({ tokens: [1] }));
  await sent;
  assert.equal(page.modules.chat.history.length, 0,
    'a stale tokenizer appended the image turn');
  assert.ok(!page.pending.some(request => request.url === '/api/chat'),
    'a stale tokenizer reached chat completion');
  assert.equal(page.modules.chat.chatState.busy, false,
    'a stale tokenizer retained image busy ownership');
});
