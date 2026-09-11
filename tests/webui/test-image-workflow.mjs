// The three control routes the page drives beside the generation, and the two
// buttons that reach them.
//
// A cancel names the running job by the identifier the worker reports as
// `job_request_id`, never by one this page chose, which is what makes
// `remote/image-service.py`'s `handle_cancel` refuse every other job. A remove
// retracts the publication and states that the payload stays with the worker's
// retention sweep. A status read carries a correlation identifier inside the
// protocol's own set and reports the observation the worker answers with.

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  FIXTURE_PNG_SHA256,
  FakeElement,
  bootPage,
  flushPromises,
  jsonResponse,
  pngResponse,
  registryRow
} from './page.mjs';

const MODEL = 'model-A';
const IMAGE_PROFILE = 'image-sdxs-512-a';
const RUNNING_JOB = 'a1b2c3d4e5f60718';

function fields(overrides = {}) {
  return {
    prompt: 'a red bicycle',
    negative_prompt: '',
    profile: IMAGE_PROFILE,
    width: 512,
    height: 512,
    steps: 4,
    seed: 111,
    seedGenerated: false,
    ...overrides
  };
}

async function workflowPage() {
  const page = await bootPage({ rows: [registryRow(MODEL)] });
  page.modules.conversations.rememberAssistantMessage(
    { role: 'assistant', content: '' }, MODEL, '');
  return page;
}

async function renderCard(page, container) {
  const rendering = page.modules.artifacts.renderImageArtifactCard(
    container,
    fields(),
    { sha256: FIXTURE_PNG_SHA256, provenanceUrl: `/api/artifacts/${FIXTURE_PNG_SHA256}.json` },
    { state: { correctionsUsed: 0 }, model: MODEL, bounds: null, authorization: 'grant-token' },
    undefined);
  await flushPromises();
  (await page.take(request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
    'artifact display read')).resolve(pngResponse(200));
  await flushPromises();
  await rendering;
  return container.children[container.children.length - 1];
}

test('a status read carries an identifier the protocol admits', async () => {
  const page = await workflowPage();
  const reading = page.modules.artifacts.readImageJobStatus();
  await flushPromises();
  const request = await page.take(
    request => request.url === '/api/tools/image/status', 'the status read');
  assert.equal(request.options.method, 'POST');
  const body = JSON.parse(request.options.body);
  assert.match(body.request_id, /^p[0-9a-f]{16}$/,
    'the status read named an identifier outside the protocol set');
  assert.equal(Object.keys(body).length, 1,
    'the status read described a generation rather than naming a job');
  request.resolve(jsonResponse({
    status: 'accepted', state: 'running', job_request_id: RUNNING_JOB, lease_held: true }));
  const observed = await reading;
  assert.equal(observed.state, 'running');
  assert.equal(observed.lease_held, true);
});

test('a cancel names the job the worker reports rather than one this page chose', async () => {
  const page = await workflowPage();
  const cancelling = page.modules.artifacts.cancelRunningImageJob();
  await flushPromises();
  const status = await page.take(
    request => request.url === '/api/tools/image/status', 'the status read before the cancel');
  const probeId = JSON.parse(status.options.body).request_id;
  status.resolve(jsonResponse({
    status: 'accepted', state: 'running', job_request_id: RUNNING_JOB, lease_held: true }));
  await flushPromises();
  const cancel = await page.take(
    request => request.url === '/api/tools/image/cancel', 'the cancel');
  const body = JSON.parse(cancel.options.body);
  assert.equal(body.request_id, RUNNING_JOB,
    'the cancel named an identifier other than the running job');
  assert.notEqual(body.request_id, probeId,
    'the cancel named this page own probe identifier, which stops no job');
  cancel.resolve(jsonResponse({
    request_id: RUNNING_JOB, status: 'accepted', reason: '', cancelled: true,
    lease_held: false, state: 'idle' }));
  const outcome = await cancelling;
  assert.equal(outcome.cancelled, true);
  assert.equal(outcome.lease_held, false,
    'the cancel reported a lease the worker no longer holds as held');
});

test('a worker holding no job is answered rather than sent a cancel', async () => {
  const page = await workflowPage();
  const cancelling = page.modules.artifacts.cancelRunningImageJob();
  await flushPromises();
  (await page.take(request => request.url === '/api/tools/image/status', 'the status read'))
    .resolve(jsonResponse({ status: 'accepted', state: 'idle', lease_held: false }));
  const outcome = await cancelling;
  assert.equal(outcome.cancelled, false);
  assert.equal(outcome.reason, 'no_job_running');
  assert.equal(page.pending.filter(request => request.url === '/api/tools/image/cancel').length, 0,
    'a worker holding no job was sent a cancel');
});

test('a refused control call reaches the caller as its own reason', async () => {
  const page = await workflowPage();
  const reading = page.modules.artifacts.readImageJobStatus();
  await flushPromises();
  (await page.take(request => request.url === '/api/tools/image/status', 'the status read'))
    .resolve(jsonResponse({ error: 'the image service socket is unreachable' }, 503));
  await assert.rejects(reading, /socket is unreachable/,
    'a refused control call reached the caller without the reason the gateway stated');
});

test('the cancel button ends the worker job beside this page own wait', async () => {
  const page = await workflowPage();
  const root = new FakeElement();
  const stateEl = new FakeElement();
  root.append(stateEl);
  const params = { ...fields(), authorization: 'grant-token' };
  const running = page.modules.artifacts.executeImageGeneration(
    stateEl, root, fields(), params,
    { state: { correctionsUsed: 0 }, model: MODEL, bounds: null,
      authorization: 'grant-token' });
  await flushPromises();
  const generation = await page.take(
    request => request.url === '/api/tools/image/generate', 'the generation');
  const button = root.children.find(child => child.textContent === 'cancel');
  assert.ok(button, 'the generation opened no cancel control');
  button.onclick();
  await flushPromises();
  const status = await page.take(
    request => request.url === '/api/tools/image/status', 'the status read the cancel makes');
  status.resolve(jsonResponse({
    status: 'accepted', state: 'running', job_request_id: RUNNING_JOB, lease_held: true }));
  await flushPromises();
  const cancel = await page.take(
    request => request.url === '/api/tools/image/cancel', 'the cancel the button sends');
  assert.equal(JSON.parse(cancel.options.body).request_id, RUNNING_JOB,
    'the cancel named an identifier other than the running job');
  cancel.resolve(jsonResponse({
    request_id: RUNNING_JOB, status: 'accepted', cancelled: true, lease_held: false,
    state: 'idle' }));
  // The worker answers the abandoned generation with the cancelled outcome,
  // which is what the gateway forwards once the job stops.
  generation.resolve(jsonResponse(
    { error: 'the image service cancelled the generation: cancelled' }, 502));
  await flushPromises();
  const outcome = await running;
  assert.equal(outcome.ok, false, 'a cancelled generation reported success');
  assert.equal(root.children.find(child => child.textContent === 'cancel'), undefined,
    'the cancel control outlived the generation it belongs to');
});

test('the remove control retracts the publication and keeps the payload claim', async () => {
  const page = await workflowPage();
  const removing = page.modules.artifacts.removePublishedArtifact(FIXTURE_PNG_SHA256);
  await flushPromises();
  const request = await page.take(
    request => request.url === '/api/tools/image/remove', 'the remove');
  assert.equal(JSON.parse(request.options.body).sha256, FIXTURE_PNG_SHA256);
  request.resolve(jsonResponse({
    removed: true, png_sha256: FIXTURE_PNG_SHA256, provenance_sha256: 'b'.repeat(64),
    job_id: 'aabbccdd', payload_retained: true }));
  const answer = await removing;
  assert.equal(answer.removed, true);
  assert.equal(answer.payload_retained, true,
    'the gateway claimed a payload removal it does not make');
});

test('the remove button takes the card and retracts the publication', async () => {
  const page = await workflowPage();
  const container = new FakeElement();
  const card = await renderCard(page, container);
  const removeButton = card.children.find(child => child.textContent === 'remove image');
  assert.ok(removeButton, 'the card carries no remove control');
  removeButton.onclick();
  await flushPromises();
  assert.equal(container.children.includes(card), false,
    'the remove control left the card on the page');
  const request = await page.take(
    request => request.url === '/api/tools/image/remove', 'the retraction');
  request.resolve(jsonResponse({
    removed: true, png_sha256: FIXTURE_PNG_SHA256, provenance_sha256: 'b'.repeat(64),
    job_id: 'aabbccdd', payload_retained: true }));
  await flushPromises();
  assert.equal(page.pending.length, 0, 'the retraction left a request outstanding');
});

test('a refused retraction is reported beside the card that left', async () => {
  const page = await workflowPage();
  const container = new FakeElement();
  const card = await renderCard(page, container);
  card.children.find(child => child.textContent === 'remove image').onclick();
  await flushPromises();
  (await page.take(request => request.url === '/api/tools/image/remove', 'the retraction'))
    .resolve(jsonResponse({ error: 'no such artifact' }, 404));
  await flushPromises();
  assert.ok(container.children.some(child =>
    (child.textContent || '').includes('its publication stands')),
    'a refused retraction left the reader believing the artifact was unpublished');
});
