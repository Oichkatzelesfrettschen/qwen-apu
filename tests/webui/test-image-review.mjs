// The Review button, the two-correction cap, and the verified-digest artifact
// link are three claims evidence/image-appliance/vision-review-design.md states
// and static/js/artifacts.js implements: the button appears only where the
// roster registers a reviewer for the artifact's image profile and the live
// registry row confirms that reviewer's projector pairing, a correction runs
// only where the verdict names a failed constraint, asks to regenerate, and
// states a delta together, the composed prompt meets the tool schema's own
// maxima before the approval dialog opens, and the counter that bounds two
// corrections per original request travels on the shared lineage object a
// correction's own card inherits.
//
// The artifact-origin cascade the predecessor asserted is retired with the
// sibling origins it resolved; tests/webui/test-artifact-origin.mjs carries the
// note. What replaces it is the digest: the bytes are hashed after they arrive
// and Open and Download are filled only from bytes that matched.
//
// None of this ever writes into `history`, which is the boundary that keeps a
// vision model's reading of an image out of the transcript a later chat request
// re-sends.

import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import test from 'node:test';

import {
  FIXTURE_PNG_SHA256,
  FakeElement,
  bootPage,
  flushPromises,
  jsonResponse,
  pngResponse,
  registryRow,
  newPage
} from './page.mjs';

const VISION_MODEL = 'vision-model';
const IMAGE_PROFILE = 'p';

function rosterWithReviewer(reviewModel) {
  /* The roster the page decorates with, carrying the image-profile pairing.

     `GET /api/models` states the tier and the projector pairing and carries no
     image-profile row, so a page reading the gateway alone registers no
     reviewer. The pairing is assigned here directly, which is what keeps the
     review path under test while the route that would serve it is absent. */
  return {
    schema: 'qwen-feature-roster/1',
    features: [],
    models: [{ id: VISION_MODEL, tier: 'production', tags: ['production', 'vision'],
               features: [] }],
    image_profiles: reviewModel ? [{ id: IMAGE_PROFILE, review_model: reviewModel }] : []
  };
}

async function reviewPage({ reviewModel = VISION_MODEL, projector = 'required' } = {}) {
  const page = await bootPage({
    rows: [registryRow(VISION_MODEL, { projector })]
  });
  page.modules.models.modelState.roster = rosterWithReviewer(reviewModel);
  page.modules.conversations.rememberAssistantMessage(
    { role: 'assistant', content: '' }, VISION_MODEL, '');
  return page;
}

function fields(overrides = {}) {
  return {
    prompt: 'a red bicycle',
    negative_prompt: '',
    profile: IMAGE_PROFILE,
    width: 512,
    height: 512,
    steps: 20,
    seed: 111,
    seedGenerated: false,
    ...overrides
  };
}

function artifactResult(sha256 = FIXTURE_PNG_SHA256) {
  return { sha256, provenanceUrl: `/api/artifacts/${sha256}.json` };
}

async function renderCard(page, container, cardFields, lineage = null) {
  const rendering = page.modules.artifacts.renderImageArtifactCard(
    container, cardFields, artifactResult(), lineage, undefined);
  await flushPromises();
  (await page.take(request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
    'artifact display read')).resolve(pngResponse(200));
  await flushPromises();
  await rendering;
  return container.children[container.children.length - 1];
}

test('a profile with no registered reviewer leaves the review button hidden', async () => {
  const page = await reviewPage({ reviewModel: null });
  const container = new FakeElement();
  const card = await renderCard(page, container, fields());
  assert.equal(page.pending.length, 0,
    'artifact rendering issued a model-loading registry request');
  const reviewButton = card.querySelector('.image-review-button');
  assert.ok(reviewButton, 'the card carries a review button element');
  assert.equal(reviewButton.hidden, true,
    'an image profile with no registered reviewer must leave the review button hidden');
});

test('the card names its seed and fills both links from verified bytes', async () => {
  const page = await reviewPage({ reviewModel: null });
  const container = new FakeElement();
  const card = await renderCard(page, container, fields());
  const caption = card.children.find(child => (child.textContent || '').includes('sha256'));
  assert.ok(caption.textContent.includes('seed 111'),
    'the card carries the approved seed in its caption');
  const openLink = card.querySelector('.image-artifact-open');
  const downloadLink = card.querySelector('.image-artifact-download');
  assert.ok(openLink.href.startsWith('blob:'), 'Open does not own the verified blob URL');
  assert.ok(downloadLink.href.startsWith('blob:'),
    'Download does not own the verified blob URL');
  assert.equal(downloadLink.href, openLink.href, 'the two links name different bytes');
  assert.equal(downloadLink.download, 'image-1.png',
    'Download does not use the conversation-local artifact reference');
});

test('bytes that disagree with the named digest reach no blob URL', async () => {
  const page = await newPage();
  await flushPromises();
  (await page.take(request => request.url === '/api/health', 'health')).resolve(jsonResponse({}));
  (await page.take(request => request.url === '/api/models', 'registry')).resolve(
    jsonResponse({ models: [] }));
  await flushPromises();
  const wrongDigest = 'a'.repeat(64);
  const reading = page.modules.artifacts.loadArtifactBlobUrl(
    { sha256: wrongDigest, provenanceUrl: `/api/artifacts/${wrongDigest}.json` });
  await flushPromises();
  (await page.take(request => request.url === `/api/artifacts/${wrongDigest}.png`,
    'wrong-digest artifact read')).resolve(pngResponse(200));
  await assert.rejects(reading, /artifact bytes hash to .* not a{64}/,
    'artifact bytes that disagree with the result digest reached a blob URL');
});

test('a reviewer the live registry denies vision reaches no artifact or completion', async () => {
  const page = await reviewPage({ projector: 'none' });
  const container = new FakeElement();
  const card = await renderCard(page, container, fields({ seed: 222 }));
  const reviewButton = card.querySelector('.image-review-button');
  assert.equal(reviewButton.hidden, false,
    'a served reviewer registered for the artifact profile must reveal the review button');
  reviewButton.onclick();
  await flushPromises();
  (await page.take(request => request.url === '/api/models',
    'registered reviewer registry read after click')).resolve(
    jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'none' })] }));
  await flushPromises();
  assert.equal(page.pending.length, 0,
    'a reviewer whose live row denies vision reached the artifact or completion route');
  assert.ok(card.children.some(child => (child.textContent || '').includes('no vision capability')),
    'the card did not report the failed live capability confirmation');
});

test('a correction needs a failed constraint, a regenerate flag, and a delta', async () => {
  const page = await reviewPage();
  const { reviewCorrectionAdmitted } = page.modules.artifacts;
  const passed = [{ name: 'prompt_subject', passed: true, observation: 'ok' }];
  const failed = [{ name: 'prompt_subject', passed: false, observation: 'wrong subject' }];

  assert.equal(reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: false, prompt_delta: 'fix it' }).admitted, false,
    'no regeneration flag admits nothing, whatever else the verdict states');
  assert.equal(reviewCorrectionAdmitted(
    { hard_constraints: passed, regenerate: true, prompt_delta: 'fix it' }).admitted, false,
    'a regenerate request with every constraint passed admits nothing');
  assert.equal(reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: true, prompt_delta: '   ' }).admitted, false,
    'a regenerate request naming a failed constraint but no delta admits nothing');
  assert.equal(reviewCorrectionAdmitted(
    { hard_constraints: failed, regenerate: true, prompt_delta: 'fix it' }).admitted, true,
    'a failed constraint, a regenerate flag, and a stated delta together admit a correction');
});

test('the review grammar equals remote/image-review.py build_verdict_schema', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const constraints = [
    { name: 'prompt_subject', description: 'the requested subject is visible' },
    { name: 'negative_prompt_absent', description: 'the excluded subject is absent' }
  ];
  const javascriptSchema = JSON.parse(JSON.stringify(api.buildReviewVerdictSchema(constraints)));
  const program = [
    'import importlib.util, json, pathlib',
    'path = pathlib.Path("remote/image-review.py")',
    'spec = importlib.util.spec_from_file_location("image_review", path)',
    'module = importlib.util.module_from_spec(spec)',
    'spec.loader.exec_module(module)',
    `constraints = ${JSON.stringify(constraints.map(({ name, description }) =>
      [name, description]))}`,
    'print(json.dumps(module.build_verdict_schema(constraints)))'
  ].join('; ');
  const pythonSchema = JSON.parse(childProcess.execFileSync(
    'python3', ['-c', program], { encoding: 'utf8', cwd: new URL('../../', import.meta.url) }));
  assert.deepEqual(javascriptSchema, pythonSchema,
    'the page review schema drifted from remote/image-review.py');
});

test('the review request offers no tool and bounds its own budget', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const constraints = [
    { name: 'prompt_subject', description: 'the requested subject is visible' },
    { name: 'negative_prompt_absent', description: 'the excluded subject is absent' }
  ];
  const request = api.buildReviewRequestBody(
    VISION_MODEL, 'data:image/png;base64,AA==', 'f'.repeat(64), constraints);
  assert.equal(request.max_tokens, 400);
  assert.equal(request.model, VISION_MODEL);
  assert.equal(request.tools, undefined, 'the review offers the vision model a tool');
  assert.equal(request.response_format.type, 'json_schema');
  assert.equal(request.response_format.json_schema.name, 'image_review');
  const schema = request.response_format.json_schema.schema;
  assert.equal(schema.properties.hard_constraints.minItems, 2);
  assert.equal(schema.properties.hard_constraints.maxItems, 2);
  assert.deepEqual(schema.properties.hard_constraints.items.properties.name.enum,
    ['prompt_subject', 'negative_prompt_absent']);
});

test('a verdict outside the schema, or past a terminal status, is refused', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const names = ['prompt_subject', 'negative_prompt_absent'];
  const verdict = {
    hard_constraints: names.map(name => ({ name, passed: true, observation: 'present' })),
    composition_change_required: false,
    prompt_delta: '',
    regenerate: false
  };
  assert.deepEqual(api.parseReviewVerdict(
    { choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(verdict) } }] },
    names), verdict);

  const diagnostic = api.buildReviewResult({
    model: 'loaded-vision-model',
    usage: { prompt_tokens: 900, completion_tokens: 37, total_tokens: 937 },
    choices: [{ finish_reason: 'stop', message: {
      reasoning_content: 'private reasoning diagnostic',
      content: JSON.stringify(verdict)
    } }]
  }, names, VISION_MODEL);
  assert.deepEqual(diagnostic.verdict, verdict,
    'response diagnostics changed the strict verdict fields');
  assert.equal(diagnostic.requested_model, VISION_MODEL);
  assert.equal(diagnostic.response_model, 'loaded-vision-model');
  assert.equal(diagnostic.finish_reason, 'stop');
  assert.equal(diagnostic.completion_tokens, 37);
  assert.equal(diagnostic.usage.total_tokens, 937);
  assert.equal(diagnostic.reasoning_present, true);
  assert.equal(diagnostic.reasoning_content, 'private reasoning diagnostic');

  for (const completionTokens of [-1, 1.5, Infinity]) {
    assert.throws(() => api.buildReviewResult({
      usage: { completion_tokens: completionTokens },
      choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(verdict) } }]
    }, names, VISION_MODEL), /completion_tokens is no finite nonnegative integer/);
  }
  for (const finishReason of ['length', 'tool_calls', 'content_filter']) {
    assert.throws(() => api.parseReviewVerdict({
      choices: [{ finish_reason: finishReason, message: { content: JSON.stringify(verdict) } }]
    }, names), new RegExp(`finish_reason ${finishReason}`));
  }
  assert.throws(() => api.parseReviewVerdict(
    { choices: [{ message: { content: JSON.stringify(verdict) } }] }, names),
    /no terminal finish reason/);
});

test('a composed prompt meets the tool schema maxima ahead of the dialog', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const longPrompt = 'x'.repeat(2000 - 5);
  assert.throws(
    () => api.applyImageSchemaBounds(
      { prompt: `${longPrompt} extra`, width: 512, height: 512, steps: 20 }, null),
    /the image service admits/,
    'a composed prompt above the cap is refused ahead of the approval dialog');
  const bounded = api.applyImageSchemaBounds(
    { prompt: 'a short prompt', width: 512, height: 512, steps: 20, profile: IMAGE_PROFILE },
    { width: 512, height: 512, steps: 20, profile: IMAGE_PROFILE });
  assert.equal(bounded.prompt, 'a short prompt');
  assert.throws(
    () => api.applyImageSchemaBounds(
      { prompt: 'a short prompt', width: 4096, height: 512, steps: 20, profile: IMAGE_PROFILE },
      { width: 512, height: 512, steps: 20, profile: IMAGE_PROFILE }),
    /exceeds the 512 this image profile admits/,
    'a dimension above the served profile ceiling is refused the same way');
});

test('an artifact the gateway no longer holds spends no correction', async () => {
  const page = await reviewPage();
  const container = new FakeElement();
  const card = await renderCard(page, container, fields({ seed: 4242 }));
  const shared = { correctionsUsed: 0 };
  const lineage = {
    sha256: FIXTURE_PNG_SHA256, state: shared, model: VISION_MODEL, cancelToolName: null,
    bounds: null, reviewModel: VISION_MODEL, entry: null, entryGeneration: 0, container
  };
  const historyBefore = page.modules.chat.history.length;
  const reviewing = page.modules.artifacts.runImageReview(card, fields({ seed: 4242 }), lineage);
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
    .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
  await flushPromises();
  (await page.take(request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
    'expired artifact read')).resolve(pngResponse(404));
  await flushPromises();
  await reviewing;
  assert.equal(shared.correctionsUsed, 0,
    'an artifact the gateway no longer holds must not spend a correction');
  assert.equal(page.modules.chat.history.length, historyBefore,
    'a failed review reached history');
  assert.ok(card.children.some(child => (child.textContent || '').includes('did not complete')),
    'the card states the review did not complete rather than staying silent');
});

test('two approved corrections are the whole allowance, counted on one lineage', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const container = new FakeElement();
  const seed = 4242;
  const originalFields = fields({ seed, prompt: 'a bicycle on a lawn' });
  const firstCard = await renderCard(page, container, originalFields);
  const shared = { correctionsUsed: 0 };
  const lineageFor = () => ({
    sha256: FIXTURE_PNG_SHA256, state: shared, model: VISION_MODEL, cancelToolName: null,
    bounds: null, reviewModel: VISION_MODEL, entry: null, entryGeneration: 0, container
  });

  async function runAdmittedReview(card, reviewFields) {
    const historyBefore = page.modules.chat.history.length;
    const reviewing = api.runImageReview(card, reviewFields, lineageFor());
    await flushPromises();
    (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
      .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
    await flushPromises();
    (await page.take(request => request.url.startsWith('/api/artifacts/'), 'artifact read for review'))
      .resolve(pngResponse(200));
    await flushPromises();
    const completion = (await page.take(request => request.url === '/api/chat',
      'the review completion request'));
    assert.equal(JSON.parse(completion.options.body).tools, undefined,
      'the review offers the vision model no tool');
    completion.resolve(jsonResponse({
      model: VISION_MODEL,
      usage: { prompt_tokens: 800, completion_tokens: 29, total_tokens: 829 },
      choices: [{ finish_reason: 'stop', message: {
        reasoning_content: 'private review reasoning',
        content: JSON.stringify({
          hard_constraints: [
            { name: 'prompt_subject', passed: false, observation: 'missing the lawn' }],
          composition_change_required: false,
          prompt_delta: 'on a green lawn',
          regenerate: true
        })
      } }]
    }));
    await flushPromises();

    const block = card.querySelector('.image-review');
    assert.ok(block, 'the admitted review rendered no checklist');
    assert.equal(block.children[0].textContent, `reviewed by ${VISION_MODEL}`);
    assert.ok(block.children[1].textContent.includes('finish stop; completion tokens 29'),
      'the review diagnostics omitted validated terminal status or completion usage');
    assert.equal(block.reviewResult.completion_tokens, 29);
    assert.equal(block.reviewResult.reasoning_content, 'private review reasoning');

    page.element('#image-approve-once').onclick();
    await flushPromises();
    const sessionIndex = page.pending.findIndex(
      request => request.url === '/api/tools/session');
    if (sessionIndex !== -1) {
      page.pending.splice(sessionIndex, 1)[0].resolve(
        jsonResponse({ session_secret: 'secret' }));
      await flushPromises();
    }
    const grant = (await page.take(request => request.url === '/api/tools/grant-image',
      'the correction image grant'));
    assert.equal(JSON.parse(grant.options.body).seed, reviewFields.seed,
      'the correction grant carries a seed other than the first approval one');
    grant.resolve(jsonResponse({ authorization: 'grant-token' }));
    await flushPromises();

    const generation = (await page.take(request => request.url === '/api/tools/image/generate',
      'the correction generation call'));
    assert.equal(JSON.parse(generation.options.body).seed, reviewFields.seed);
    generation.resolve(jsonResponse({
      sha256: FIXTURE_PNG_SHA256,
      artifact_url: `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
      provenance_url: `/api/artifacts/${FIXTURE_PNG_SHA256}.json`
    }));
    await flushPromises();
    (await page.take(request => request.url === `/api/artifacts/${FIXTURE_PNG_SHA256}.png`,
      'the correction artifact display read')).resolve(pngResponse(200));
    await flushPromises();
    await reviewing;
    assert.equal(page.modules.chat.history.length, historyBefore,
      'the verdict, its observations, and the composed delta entered history');
    return container.children[container.children.length - 1];
  }

  const secondCard = await runAdmittedReview(firstCard, originalFields);
  assert.equal(shared.correctionsUsed, 1,
    'one admitted, approved correction spends the first of the two-correction cap');
  const caption = secondCard.children.find(
    child => (child.textContent || '').includes('sha256'));
  assert.ok(caption.textContent.includes(`seed ${seed}`),
    'the correction own card no longer names the seed the first approval bound');

  const correctedFields = { ...originalFields,
    prompt: `${originalFields.prompt} on a green lawn` };
  const thirdCard = await runAdmittedReview(secondCard, correctedFields);
  assert.equal(shared.correctionsUsed, 2,
    'the correction own review lost the shared counter');

  const pendingBefore = page.pending.length;
  const capped = api.runImageReview(thirdCard, correctedFields, lineageFor());
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'capped reviewer registry read'))
    .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
  await flushPromises();
  (await page.take(request => request.url.startsWith('/api/artifacts/'),
    'artifact read for the capped review')).resolve(pngResponse(200));
  await flushPromises();
  (await page.take(request => request.url === '/api/chat', 'the capped review completion'))
    .resolve(jsonResponse({
      choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({
        hard_constraints: [
          { name: 'prompt_subject', passed: false, observation: 'still wrong' }],
        composition_change_required: false,
        prompt_delta: 'one more change',
        regenerate: true
      }) } }]
    }));
  await flushPromises();
  await capped;
  assert.equal(page.pending.length, pendingBefore,
    'a review against a spent cap opened an approval dialog or sent a grant request');
  assert.equal(shared.correctionsUsed, 2, 'the cap moved past its two-correction ceiling');
  assert.ok(thirdCard.children.some(child => (child.textContent || '').includes('spent')),
    'the card does not state that the two approved corrections are already spent');
});
