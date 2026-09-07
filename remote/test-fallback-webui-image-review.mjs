#!/usr/bin/env node

// The Review button, the two-correction cap, and the artifact-origin cascade
// are three claims evidence/image-appliance/vision-review-design.md states
// and webui/index.html implements: the button appears only where GET
// /props?model= reports a vision modality for some served row, a correction
// runs only where the verdict names a failed constraint, asks to regenerate,
// and states a delta together, the composed prompt is checked against the
// tool schema's own maxima before the approval dialog opens, the counter
// that bounds two corrections per original request travels on the shared
// lineage object a correction's own card inherits, and the artifact origin
// resolves through one order of a query parameter, a meta tag, and the
// on-page field, refusing to fall back to the router when none names a
// listener. Every check below drives the page's own functions rather than
// re-deriving the rule, and none of it ever writes into `history`, which is
// the boundary that keeps a vision model's reading of an image out of the
// transcript a later chat request re-sends.

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
    this.disabled = false;
    this.isConnected = true;
    this.listeners = new Map();
    this._textContent = '';
    this.value = '';
    this._attributes = {};
  }

  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this._attributes, name)
      ? this._attributes[name] : null;
  }

  setAttribute(name, value) {
    this._attributes[name] = String(value);
  }

  get textContent() {
    return this._textContent;
  }

  set textContent(value) {
    this._textContent = value;
    if (value === '') this.children = [];
  }

  get options() {
    return this.children;
  }

  addEventListener(eventName, listener) {
    this.listeners.set(eventName, listener);
  }

  append(...children) {
    this.children.push(...children);
  }

  after() { /* sibling placement is not read by anything this harness checks */ }
  before() { /* same */ }
  insertBefore(node) { this.children.push(node); }

  remove() {
    this.isConnected = false;
  }

  querySelector(selector) {
    if (!selector.startsWith('.')) return null;
    const wantedClass = selector.slice(1);
    const search = nodes => {
      for (const node of nodes) {
        if (node.className && node.className.split(' ').includes(wantedClass)) return node;
        if (node.children) {
          const found = search(node.children);
          if (found) return found;
        }
      }
      return null;
    };
    return search(this.children);
  }

  showModal() { /* the approval dialog opens; the test drives its buttons directly */ }
  close() { /* the page calls this once it has resolved the approval */ }

  focus() {}
}

function makeDocument() {
  const elements = new Map();
  return {
    elements,
    document: {
      createElement() {
        return new FakeElement();
      },
      querySelector(selector) {
        if (!elements.has(selector)) elements.set(selector, new FakeElement());
        return elements.get(selector);
      },
    },
  };
}

const workingStorage = () => {
  const store = new Map();
  return {
    getItem(key) { return store.has(key) ? store.get(key) : null; },
    setItem(key, value) { store.set(key, String(value)); },
    removeItem(key) { store.delete(key); },
  };
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
    async json() { return payload; },
  };
}

function pngResponse(status = 200) {
  const bytes = new TextEncoder().encode('fake-png-bytes');
  return {
    ok: status >= 200 && status < 300,
    status,
    async blob() { return { size: bytes.length }; },
    async arrayBuffer() { return bytes.buffer; },
  };
}

async function flushPromises() {
  for (let turn = 0; turn < 8; turn += 1) {
    await new Promise(resolve => setImmediate(resolve));
  }
}

const webuiPath = new URL('../webui/index.html', import.meta.url);
const webuiHtml = fs.readFileSync(webuiPath, 'utf8');
const inlineScript = webuiHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(inlineScript, 'fallback Web UI has no inline script');

const testInterface = `
globalThis.imageReviewTest = {
  renderImageArtifactCard,
  runImageReview,
  reviewCorrectionAdmitted,
  applyImageSchemaBounds,
  artifactOrigin,
  configuredArtifactOrigin,
  IMAGE_CORRECTION_CAP,
  IMAGE_PROMPT_CHARACTER_CAP,
  historyLength() { return history.length; },
  setBrokerOriginField(value) { $('#broker-origin').value = value; },
  setArtifactOriginField(value) { $('#artifact-origin').value = value; },
  clickApproveOnce() { $('#image-approve-once').onclick(); },
};
`;

function makeContext(hostname = '127.0.0.1', port = '8571', extraHref, artifactMetaContent) {
  const { document, elements } = makeDocument();
  if (artifactMetaContent !== undefined) {
    // ARTIFACT_ORIGIN_DEFAULT is a load-time const, computed once from the
    // meta tag configuredArtifactOrigin() reads at script evaluation, so a
    // meta tag this cascade wants to matter must exist before the script
    // runs -- setting it afterward only changes what a later, live call to
    // configuredArtifactOrigin() itself would see.
    const metaElement = new FakeElement();
    metaElement.setAttribute('content', artifactMetaContent);
    elements.set('meta[name="qwen-image-artifacts"]', metaElement);
  }
  const href = extraHref || `http://${hostname}:${port}/`;
  const context = vm.createContext({
    console,
    document,
    fetch: deferredFetch,
    URL,
    TextEncoder,
    AbortController,
    setTimeout,
    clearTimeout,
    setImmediate,
    btoa: globalThis.btoa || (str => Buffer.from(str, 'binary').toString('base64')),
    window: {
      alert() {},
      localStorage: workingStorage(),
      sessionStorage: workingStorage(),
      history: { replaceState() {} },
      location: {
        hostname, protocol: 'http:', port, href, hash: '', pathname: '/', search: '', origin: `http://${hostname}:${port}`,
      },
    },
  });
  context.URL.createObjectURL = () => 'blob:fake';
  context.URL.revokeObjectURL = () => {};
  vm.runInContext(`${inlineScript[1]}\n${testInterface}`, context, { filename: webuiPath.pathname });
  return context;
}

// ---- boot one roster row and settle its initial props read -----------------

// A context's own top-level `void boot();` fires its roster reads whether or
// not a test cares about the roster, so a test that only wants the page's
// pure functions drains and discards those two requests rather than leaving
// them to accumulate in the shared queue.
function drainBoot() {
  for (const url of ['./roster.json', './v1/models']) {
    const index = pendingRequests.findIndex(request => request.url === url);
    if (index === -1) continue;
    const [request] = pendingRequests.splice(index, 1);
    request.resolve(jsonResponse(url === './roster.json' ? { error: 'not found' } : { data: [] },
      url === './roster.json' ? 404 : 200));
  }
}

async function bootSingleModel(modelId, modalities) {
  const context = makeContext();
  const featureRosterRequest = takeRequest(
    request => request.url === './roster.json', 'feature roster');
  featureRosterRequest.resolve(jsonResponse({ error: 'not found' }, 404));
  const rosterRequest = takeRequest(
    request => request.url === './v1/models', 'initial model roster');
  rosterRequest.resolve(jsonResponse({ data: [{ id: modelId }] }));
  await flushPromises();
  const propsRequest = takeRequest(
    request => request.url === `./props?model=${encodeURIComponent(modelId)}`,
    'boot properties read');
  propsRequest.resolve(jsonResponse({ n_ctx: 8192, modalities }));
  await flushPromises();
  return context;
}

// ==== the Review button appears only where a served row reports vision =====

{
  const context = await bootSingleModel('text-only-model', { vision: false });
  const api = context.imageReviewTest;
  const container = new FakeElement();
  const sha = 'a'.repeat(64);
  const fields = { prompt: 'a red bicycle', negative_prompt: '', profile: 'p', width: 512, height: 512, steps: 20, seed: 111, seedGenerated: false };
  const result = { sha256: sha, provenanceUrl: `http://127.0.0.1:8572/artifacts/${sha}.json` };
  api.setArtifactOriginField('http://127.0.0.1:8572');
  const renderPromise = api.renderImageArtifactCard(container, fields, result, null, undefined);
  const artifactRead1 = takeRequest(
    request => request.url === `http://127.0.0.1:8572/artifacts/${sha}.png`, 'card 1 artifact display read');
  artifactRead1.resolve(pngResponse(200));
  await flushPromises();
  await renderPromise;
  const visionPropsRequest = takeRequest(
    request => request.url === './props?model=text-only-model', 'resolveVisionModel props read');
  visionPropsRequest.resolve(jsonResponse({ n_ctx: 8192, modalities: { vision: false } }));
  await flushPromises();
  const card = container.children[0];
  const reviewButton = card.querySelector('.image-review-button');
  assert.ok(reviewButton, 'the card carries a review button element');
  assert.equal(reviewButton.hidden, true,
    'a roster with no vision-capable row must leave the review button hidden');
  const caption = card.children.find(child => child.className === undefined || true) &&
    card.children.find(child => (child.textContent || '').includes('sha256'));
  assert.ok(caption.textContent.includes('seed 111'),
    'the card carries the approved seed in its caption');
}

{
  const context = await bootSingleModel('vision-model', { vision: true });
  const api = context.imageReviewTest;
  const container = new FakeElement();
  const sha = 'b'.repeat(64);
  const fields = { prompt: 'a red bicycle', negative_prompt: '', profile: 'p', width: 512, height: 512, steps: 20, seed: 222, seedGenerated: false };
  const result = { sha256: sha, provenanceUrl: `http://127.0.0.1:8572/artifacts/${sha}.json` };
  api.setArtifactOriginField('http://127.0.0.1:8572');
  const renderPromise = api.renderImageArtifactCard(container, fields, result, null, undefined);
  const artifactRead2 = takeRequest(
    request => request.url === `http://127.0.0.1:8572/artifacts/${sha}.png`, 'card 2 artifact display read');
  artifactRead2.resolve(pngResponse(200));
  await flushPromises();
  await renderPromise;
  const visionPropsRequest = takeRequest(
    request => request.url === './props?model=vision-model', 'resolveVisionModel props read');
  visionPropsRequest.resolve(jsonResponse({ n_ctx: 8192, modalities: { vision: true } }));
  await flushPromises();
  const card = container.children[0];
  const reviewButton = card.querySelector('.image-review-button');
  assert.equal(reviewButton.hidden, false,
    'a roster carrying a vision-capable row must reveal the review button');
}

console.log('review_button_visibility=accepted');

// ==== reviewCorrectionAdmitted: the three-fact conjunction ==================
{
  const context = makeContext();
  drainBoot();
  const api = context.imageReviewTest;
  const passed = [{ name: 'prompt_subject', passed: true, observation: 'ok' }];
  const failed = [{ name: 'prompt_subject', passed: false, observation: 'wrong subject' }];

  assert.equal(api.reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: false, prompt_delta: 'fix it' }).admitted, false,
    'no regeneration flag admits nothing, whatever else the verdict states');

  assert.equal(api.reviewCorrectionAdmitted(
    { hard_constraints: passed, regenerate: true, prompt_delta: 'fix it' }).admitted, false,
    'a regenerate request with every constraint passed admits nothing');

  assert.equal(api.reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: true, prompt_delta: '   ' }).admitted, false,
    'a regenerate request naming a failed constraint but no delta admits nothing');

  assert.equal(api.reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: true, prompt_delta: 'fix it' }).admitted, true,
    'a failed constraint, a regenerate flag, and a stated delta together admit a correction');
}
console.log('correction_admission=accepted');

// ==== the composed prompt meets the tool schema's own maxima ================
{
  const context = makeContext();
  drainBoot();
  const api = context.imageReviewTest;
  const longPrompt = 'x'.repeat(api.IMAGE_PROMPT_CHARACTER_CAP - 5);
  assert.throws(
    () => api.applyImageSchemaBounds({ prompt: `${longPrompt} extra`, width: 512, height: 512, steps: 20 }, null),
    /the image service admits/,
    'a composed prompt above the cap is refused ahead of the approval dialog');
  const withinPrompt = 'a short prompt';
  const bounded = api.applyImageSchemaBounds(
    { prompt: withinPrompt, width: 512, height: 512, steps: 20, profile: 'p' },
    { width: 512, height: 512, steps: 20, profile: 'p' });
  assert.equal(bounded.prompt, withinPrompt);
  assert.throws(
    () => api.applyImageSchemaBounds(
      { prompt: withinPrompt, width: 4096, height: 512, steps: 20, profile: 'p' },
      { width: 512, height: 512, steps: 20, profile: 'p' }),
    /exceeds the 512 this image profile admits/,
    'a dimension above the served profile ceiling is refused the same way');
}
console.log('composed_prompt_bounds=accepted');

// ==== history never carries a verdict, an observation, or a delta ===========
// ==== the two-correction cap, and a correction's card inheriting the count =
{
  const context = await bootSingleModel('vision-model', { vision: true });
  const api = context.imageReviewTest;
  api.setBrokerOriginField('http://127.0.0.1:8571');
  api.setArtifactOriginField('http://127.0.0.1:8572');

  const seed = 4242;
  const sha1 = 'c'.repeat(64);
  const container = new FakeElement();
  const fields = { prompt: 'a bicycle on a lawn', negative_prompt: '', profile: 'p', width: 512, height: 512, steps: 20, seed, seedGenerated: false };
  const result1 = { sha256: sha1, provenanceUrl: `http://127.0.0.1:8572/artifacts/${sha1}.json` };
  const renderPromise1 = api.renderImageArtifactCard(container, fields, result1, null, undefined);
  const artifactReadInitial = takeRequest(
    request => request.url === `http://127.0.0.1:8572/artifacts/${sha1}.png`, 'card 1 artifact display read');
  artifactReadInitial.resolve(pngResponse(200));
  await flushPromises();
  await renderPromise1;
  const visionPropsInitial = takeRequest(
    request => request.url === './props?model=vision-model', 'resolveVisionModel for card 1');
  visionPropsInitial.resolve(jsonResponse({ n_ctx: 8192, modalities: { vision: true } }));
  await flushPromises();
  const card1 = container.children[0];
  const sharedState = { correctionsUsed: 0 };
  const cardLineage = sha => ({
    sha256: sha, state: sharedState, model: 'vision-model', cancelToolName: null,
    bounds: null, entry: null, entryGeneration: 0, container,
  });
  const lineage1 = cardLineage(sha1);

  // ---- pass 1: an artifact expired at the listener reads as gone and moves
  //      neither the transcript nor the correction counter.
  // resolveVisionModel() caches by modelStateGeneration, and card 1's own
  // creation already resolved the first read for this generation, so this
  // review reaches the artifact fetch with no further props request.
  const expiredReviewPromise = api.runImageReview(card1, fields, lineage1);
  {
    await flushPromises();
    const artifactRead = takeRequest(
      request => request.url === `http://127.0.0.1:8572/artifacts/${sha1}.png`,
      'expired artifact read');
    artifactRead.resolve(pngResponse(404));
    await flushPromises();
  }
  await expiredReviewPromise;
  assert.equal(sharedState.correctionsUsed, 0,
    'an artifact the listener no longer holds must not spend a correction');
  assert.equal(api.historyLength(), 0, 'a failed review never reaches history');
  const goneNote = card1.children.find(child => (child.textContent || '').includes('did not complete'));
  assert.ok(goneNote, 'the card states the review did not complete rather than staying silent');

  // ---- pass 2: an admitted verdict runs the correction end to end, and the
  //      correction's own card shares the original lineage's counter object.
  async function runAdmittedReview(card, fieldsForReview, lineage, correctionSha) {
    const reviewStart = api.historyLength();
    const reviewPromise = api.runImageReview(card, fieldsForReview, lineage);
    await flushPromises();

    const artifactRead = takeRequest(
      request => request.url.startsWith('http://127.0.0.1:8572/artifacts/'), 'artifact read for review');
    artifactRead.resolve(pngResponse(200));
    await flushPromises();

    const chatRequest = takeRequest(request => request.url === './v1/chat/completions',
      'the review completion request');
    const chatBody = JSON.parse(chatRequest.options.body);
    assert.equal(chatBody.tools, undefined, 'the review offers the vision model no tool');
    chatRequest.resolve(jsonResponse({
      choices: [{ message: {
        content: JSON.stringify({
          hard_constraints: [{ name: 'prompt_subject', passed: false, observation: 'missing the lawn' }],
          composition_change_required: false,
          prompt_delta: 'on a green lawn',
          regenerate: true,
        }),
      } }],
    }));
    await flushPromises();

    api.clickApproveOnce();
    await flushPromises();
    // brokerSession() caches the secret per origin for the life of the page,
    // so only the first approval in this run fetches it.
    const sessionIndex = pendingRequests.findIndex(
      request => request.url === 'http://127.0.0.1:8571/session');
    if (sessionIndex !== -1) {
      const [sessionRequest] = pendingRequests.splice(sessionIndex, 1);
      sessionRequest.resolve(jsonResponse({ session_secret: 'secret' }));
      await flushPromises();
    }

    const grantRequest = takeRequest(request => request.url === 'http://127.0.0.1:8571/grant-image',
      'the correction image grant');
    const grantBody = JSON.parse(grantRequest.options.body);
    assert.equal(grantBody.seed, fieldsForReview.seed,
      'the correction grant carries the first approval\'s seed rather than a new one');
    grantRequest.resolve(jsonResponse({ authorization: 'grant-token' }));
    await flushPromises();

    const toolRequest = takeRequest(request => request.url === './tools',
      'the correction generation call');
    const toolBody = JSON.parse(toolRequest.options.body);
    assert.equal(toolBody.params.seed, fieldsForReview.seed);
    toolRequest.resolve(jsonResponse({
      plain_text_response: JSON.stringify({
        status: 'completed', sha256: correctionSha,
        provenance_url: `http://127.0.0.1:8572/artifacts/${correctionSha}.json`,
      }),
    }));
    await flushPromises();

    const secondArtifactRead = takeRequest(
      request => request.url === `http://127.0.0.1:8572/artifacts/${correctionSha}.png`,
      'the correction artifact display read');
    secondArtifactRead.resolve(pngResponse(200));
    await flushPromises();

    await reviewPromise;
    assert.equal(api.historyLength(), reviewStart,
      'the verdict, its observations, and the composed delta never enter history');
    return container.children[container.children.length - 1];
  }

  const sha2 = 'd'.repeat(64);
  const card2 = await runAdmittedReview(card1, fields, lineage1, sha2);
  assert.equal(sharedState.correctionsUsed, 1,
    'one admitted, approved correction spends the first of the two-correction cap');
  const card2Caption = card2.children.find(child => (child.textContent || '').includes('sha256'));
  assert.ok(card2Caption.textContent.includes(`seed ${seed}`),
    'the correction\'s own card still names the seed the first approval bound');
  assert.ok(card2Caption.textContent.includes(sha2));

  // A second review, run on the correction's own card, shares sharedState:
  // executeImageGeneration threads { state: lineage.state, ... } through to
  // renderImageArtifactCard, whose own cardLineage.state carries that same
  // object forward rather than starting a fresh counter at zero.
  const correctedFields = { ...fields, prompt: `${fields.prompt} on a green lawn` };
  const sha3 = 'e'.repeat(64);
  const card3 = await runAdmittedReview(card2, correctedFields, cardLineage(sha2), sha3);
  assert.equal(sharedState.correctionsUsed, 2,
    'the correction\'s own review inherits the shared counter and spends the second slot');

  // A third review against the now-spent cap proposes nothing and opens no
  // dialog: the note names the cap and no broker or generation request runs.
  const requestCountBeforeCap = pendingRequests.length;
  const cappedReviewPromise = api.runImageReview(card3, correctedFields, cardLineage(sha3));
  await flushPromises();
  const thirdArtifactRead = takeRequest(
    request => request.url === `http://127.0.0.1:8572/artifacts/${sha3}.png`, 'artifact read for the capped review');
  thirdArtifactRead.resolve(pngResponse(200));
  await flushPromises();
  const thirdChatRequest = takeRequest(request => request.url === './v1/chat/completions',
    'the capped review completion request');
  thirdChatRequest.resolve(jsonResponse({
    choices: [{ message: {
      content: JSON.stringify({
        hard_constraints: [{ name: 'prompt_subject', passed: false, observation: 'still wrong' }],
        composition_change_required: false,
        prompt_delta: 'one more change',
        regenerate: true,
      }),
    } }],
  }));
  await flushPromises();
  await cappedReviewPromise;
  assert.equal(pendingRequests.length, requestCountBeforeCap,
    'a review against a spent cap opens no approval dialog and sends no grant request');
  assert.equal(sharedState.correctionsUsed, 2, 'the cap stays at its two-correction ceiling');
  const capNote = card3.children.find(child => (child.textContent || '').includes('spent'));
  assert.ok(capNote, 'the card states that the two approved corrections are already spent');
}
console.log('review_history_and_correction_cap=accepted');

// ==== the artifact origin cascade: query parameter, meta tag, field =========
{
  // No query parameter, no meta tag, and no on-page field: the page states
  // that it holds no configured listener rather than resolving against the
  // router, which proxies none of the artifact routes.
  const context = makeContext('127.0.0.1', '8571', 'http://127.0.0.1:8571/');
  drainBoot();
  const api = context.imageReviewTest;
  assert.equal(api.configuredArtifactOrigin(), '');
  assert.throws(() => api.artifactOrigin(),
    /no artifact listener origin is configured for this page/,
    'an unconfigured artifact origin must say so rather than resolving the router');
}

{
  // A meta tag names the listener where no query parameter overrides it.
  const context = makeContext('127.0.0.1', '8571', 'http://127.0.0.1:8571/',
    'http://127.0.0.1:8572/');
  drainBoot();
  const api = context.imageReviewTest;
  assert.equal(api.configuredArtifactOrigin(), 'http://127.0.0.1:8572');
  assert.equal(api.artifactOrigin(), 'http://127.0.0.1:8572');

  // The on-page field outranks the load-time default once a person or a
  // restored value has set it, since artifactOrigin() reads the field ahead
  // of ARTIFACT_ORIGIN_DEFAULT.
  api.setArtifactOriginField('http://127.0.0.1:8574');
  assert.equal(api.artifactOrigin(), 'http://127.0.0.1:8574',
    'the field, once set, outranks the query-then-meta default');
}

{
  // A `?artifacts=` query parameter outranks the meta tag.
  const context = makeContext('127.0.0.1', '8571',
    'http://127.0.0.1:8571/?artifacts=http%3A%2F%2F127.0.0.1%3A8573', 'http://127.0.0.1:8572/');
  drainBoot();
  const api = context.imageReviewTest;
  assert.equal(api.configuredArtifactOrigin(), 'http://127.0.0.1:8573',
    'the query parameter must outrank the meta tag');
}
console.log('artifact_origin_cascade=accepted');

assert.equal(pendingRequests.length, 0, 'every issued request was answered by the harness');
console.log('fallback_webui_image_review=accepted');
