// The browser's only credential is the session `POST /api/pair` mints. The
// predecessor of this test drove a `/#key=<bearer>` link, which handed the page
// a bearer it then wrote to localStorage and replayed on every request; the
// gateway replaces that with a pairing code spent once for an HttpOnly
// SameSite=Strict cookie script cannot read.
//
// Four properties decide the feature. A guarded route answering 401 is the one
// fact that reveals the pairing field. A code travels in a request body, so it
// reaches no URL and no store. A successful pairing re-runs boot under the
// session the gateway just set. A refused pairing says so and leaves the field
// where a person can correct it.

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  flushPromises,
  jsonResponse,
  newPage,
  registryResponse,
  registryRow
} from './page.mjs';

const ROW = registryRow('model-A');

async function unpairedPage() {
  const page = await newPage();
  await flushPromises();
  (await page.take(request => request.url === '/api/health', 'health probe'))
    .resolve(jsonResponse({ upstream: { serving: false } }));
  (await page.take(request => request.url === '/api/models', 'model registry'))
    .resolve(jsonResponse({ error: 'the request carries no live session' }, 401));
  await flushPromises();
  return page;
}

test('a 401 from a guarded route reveals the pairing entry', async () => {
  const page = await unpairedPage();
  assert.equal(page.modules.api.session.paired, false);
  assert.equal(page.element('#pair-code').hidden, false, 'the pairing field stayed hidden');
  assert.equal(page.element('#pair').hidden, false);
  assert.equal(page.element('#pair-hint').hidden, false);
  assert.match(page.element('#model').textContent, /pairing/);
  assert.equal(page.element('#model-picker').hidden, true,
    'an unpaired page offered a model to route to');
});

test('a paired page never shows the pairing entry', async () => {
  const page = await newPage();
  await flushPromises();
  (await page.take(request => request.url === '/api/health', 'health probe'))
    .resolve(jsonResponse({ upstream: { serving: true } }));
  (await page.take(request => request.url === '/api/models', 'model registry'))
    .resolve(registryResponse([ROW]));
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'selection registry read'))
    .resolve(registryResponse([ROW]));
  await flushPromises();
  assert.equal(page.modules.api.session.paired, true);
  assert.equal(page.element('#pair-code').hidden, true);
  assert.equal(page.element('#pair').hidden, true);
});

test('the code travels in the body and reaches no store', async () => {
  const page = await unpairedPage();
  page.element('#pair-code').value = '  a-pairing-code  ';
  page.element('#pair').click();
  await flushPromises();
  const attempt = (await page.take(request => request.url === '/api/pair', 'pairing attempt'));
  assert.equal(attempt.options.method, 'POST');
  assert.deepEqual(JSON.parse(attempt.options.body), { code: 'a-pairing-code' },
    'the pairing request did not carry the trimmed code alone');
  assert.ok(!attempt.url.includes('a-pairing-code'),
    'the pairing code reached the request URL');

  attempt.resolve(jsonResponse({ paired: true, expires_in: 43200 }));
  await flushPromises();
  const stored = [...page.harness.window.localStorage.store.entries()]
    .concat([...page.harness.window.sessionStorage.store.entries()]);
  assert.ok(!stored.some(([, value]) => String(value).includes('a-pairing-code')),
    'the pairing code reached a browser store');
  assert.equal(page.element('#pair-code').value, '',
    'the spent code stayed in the field');
});

test('a successful pairing re-runs boot under the new session', async () => {
  const page = await unpairedPage();
  page.element('#pair-code').value = 'a-pairing-code';
  page.element('#pair').click();
  await flushPromises();
  (await page.take(request => request.url === '/api/pair', 'pairing attempt'))
    .resolve(jsonResponse({ paired: true, expires_in: 43200 }));
  await flushPromises();
  assert.equal(page.element('#pair-code').hidden, true,
    'the pairing entry stayed on screen after a successful pairing');
  (await page.take(request => request.url === '/api/models', 'model registry after pairing'))
    .resolve(registryResponse([ROW]));
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'selection registry read'))
    .resolve(registryResponse([ROW]));
  await flushPromises();
  assert.equal(page.element('#model').textContent, '1 model available');
  assert.equal(page.modules.models.modelState.requestModel, ROW.id);
});

test('a refused pairing names the refusal and keeps the entry', async () => {
  const page = await unpairedPage();
  page.element('#pair-code').value = 'wrong-code';
  page.element('#pair').click();
  await flushPromises();
  (await page.take(request => request.url === '/api/pair', 'pairing attempt'))
    .resolve(jsonResponse({ error: 'the pairing code does not match' }, 403));
  await flushPromises();
  assert.match(page.element('#model').textContent, /pairing refused.*does not match/);
  assert.equal(page.modules.api.session.paired, false);
  assert.equal(page.element('#pair-code').hidden, false,
    'a refused pairing removed the field a person corrects it in');
  assert.equal(page.element('#pair').disabled, false,
    'a refused pairing left the button disabled');
});

test('an empty field spends no attempt', async () => {
  const page = await unpairedPage();
  page.element('#pair-code').value = '   ';
  page.element('#pair').click();
  await flushPromises();
  assert.ok(!page.pending.some(request => request.url === '/api/pair'),
    'an empty field spent a pairing attempt');
  assert.match(page.element('#model').textContent, /enter the pairing code/);
});
