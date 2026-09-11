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

// The review grammar, the request shape, and the strict verdict parser left
// this page with the client-side review: `POST /api/tools/image/review` builds
// the request through `remote/image-review.py`'s own `build_review_request`
// and parses the reply through its own `parse_verdict`, so one reading serves
// both sides and tests/test_web_artifacts.py is where it is proven. What the
// page still owns, and the tests below cover, is the three findings it renders
// and the correction cap it counts.

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

function reviewLineage(container, shared) {
  return {
    sha256: FIXTURE_PNG_SHA256, state: shared, model: VISION_MODEL, bounds: null,
    // The grant the generation ran under. The review route verifies the claim
    // and spends nothing, so the already-spent token still proves which prompt
    // a human approved.
    authorization: 'grant-token',
    reviewModel: VISION_MODEL, entry: null, entryGeneration: 0, container
  };
}

function findingsFor(verdict, overrides = {}) {
  /* The three findings `POST /api/tools/image/review` reports apart. */
  return {
    model: VISION_MODEL,
    artifact_sha256: FIXTURE_PNG_SHA256,
    prompt_hash: 'f'.repeat(64),
    completion: { answered: true, raw_reply: JSON.stringify(verdict),
                  reasoning_emitted: true, refusal_code: null },
    schema_validity: { valid: true, refusal_code: null, verdict },
    judgment: {
      failed: verdict.hard_constraints.filter(entry => !entry.passed)
        .map(entry => entry.name),
      correction_admitted: true,
      correction_reason: 'the verdict names a failed hard constraint and states its correction'
    },
    ...overrides
  };
}

test('an artifact the gateway no longer holds spends no correction', async () => {
  const page = await reviewPage();
  const container = new FakeElement();
  const card = await renderCard(page, container, fields({ seed: 4242 }));
  const shared = { correctionsUsed: 0 };
  const historyBefore = page.modules.chat.history.length;
  const reviewing = page.modules.artifacts.runImageReview(
    card, fields({ seed: 4242 }), reviewLineage(container, shared));
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
    .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
  await flushPromises();
  (await page.take(request => request.url === '/api/tools/image/review', 'the review request'))
    .resolve(jsonResponse({ error: 'no such artifact' }, 404));
  await flushPromises();
  await reviewing;
  assert.equal(shared.correctionsUsed, 0,
    'an artifact the gateway no longer holds must not spend a correction');
  assert.equal(page.modules.chat.history.length, historyBefore,
    'a failed review reached history');
  assert.ok(card.children.some(child => (child.textContent || '').includes('did not complete')),
    'the card states the review did not complete rather than staying silent');
});

test('a review without the generation grant reaches no route', async () => {
  /* A restored card carries no grant, so the review states that rather than
     posting a request the gateway would refuse for want of a claim. */
  const page = await reviewPage();
  const container = new FakeElement();
  const card = await renderCard(page, container, fields());
  const shared = { correctionsUsed: 0 };
  const lineage = { ...reviewLineage(container, shared), authorization: undefined };
  const reviewing = page.modules.artifacts.runImageReview(card, fields(), lineage);
  await flushPromises();
  (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
    .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
  await flushPromises();
  await reviewing;
  assert.equal(page.pending.length, 0, 'a review without a grant reached the review route');
  assert.ok(card.children.some(child =>
    (child.textContent || '').includes('no longer held by this page')),
    'the card did not name the absent grant');
});

test('completion, schema validity, and judgment are reported apart', async () => {
  const page = await reviewPage();
  const container = new FakeElement();
  const shared = { correctionsUsed: 0 };

  async function answerWith(findings) {
    const card = await renderCard(page, container, fields());
    const reviewing = page.modules.artifacts.runImageReview(
      card, fields(), reviewLineage(container, shared));
    await flushPromises();
    (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
      .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
    await flushPromises();
    (await page.take(request => request.url === '/api/tools/image/review', 'the review request'))
      .resolve(jsonResponse(findings));
    await flushPromises();
    await reviewing;
    return card;
  }

  // A router that answered nothing is a completion failure and stops there.
  const unanswered = await answerWith({
    model: VISION_MODEL,
    completion: { answered: false, raw_reply: null, reasoning_emitted: false,
                  refusal_code: 'reply_refused' },
    schema_validity: { valid: false, refusal_code: null, verdict: null },
    judgment: null
  });
  assert.ok(unanswered.children.some(child =>
    (child.textContent || '').includes('no completion: reply_refused')),
    'an unanswered review did not report its refusal code');
  assert.equal(unanswered.querySelector('.image-review'), null,
    'an unanswered review rendered a checklist');

  // A router that answered and left the schema is a second, separate finding.
  const invalid = await answerWith({
    model: VISION_MODEL,
    completion: { answered: true, raw_reply: 'not a verdict', reasoning_emitted: false,
                  refusal_code: null },
    schema_validity: { valid: false, refusal_code: 'verdict_not_json', verdict: null },
    judgment: null
  });
  assert.ok(invalid.children.some(child =>
    (child.textContent || '').includes('failed the verdict schema: verdict_not_json')),
    'a completed reply that left the schema was reported as no completion');
  assert.equal(invalid.querySelector('.image-review'), null,
    'a reply outside the verdict schema rendered a checklist');

  // A verdict the parser admitted, whose judgment proposes nothing.
  const passing = {
    hard_constraints: [{ name: 'prompt_subject', passed: true, observation: 'present' }],
    composition_change_required: false,
    prompt_delta: '',
    regenerate: false
  };
  const judged = await answerWith(findingsFor(passing, {
    judgment: { failed: [], correction_admitted: false,
                correction_reason: 'the verdict asks for no regeneration' }
  }));
  const block = judged.querySelector('.image-review');
  assert.ok(block, 'an admitted verdict rendered no checklist');
  assert.equal(block.children[0].textContent, `reviewed by ${VISION_MODEL}`);
  assert.ok(judged.children.some(child =>
    (child.textContent || '').includes('asks for no regeneration')),
    'the card did not carry the judgment reason the gateway stated');
  assert.equal(shared.correctionsUsed, 0, 'a verdict admitting no correction spent one');
});

test('two approved corrections are the whole allowance, counted on one lineage', async () => {
  const page = await reviewPage();
  const api = page.modules.artifacts;
  const container = new FakeElement();
  const seed = 4242;
  const originalFields = fields({ seed, prompt: 'a bicycle on a lawn' });
  const firstCard = await renderCard(page, container, originalFields);
  const shared = { correctionsUsed: 0 };
  const lineageFor = () => reviewLineage(container, shared);

  async function runAdmittedReview(card, reviewFields) {
    const historyBefore = page.modules.chat.history.length;
    const reviewing = api.runImageReview(card, reviewFields, lineageFor());
    await flushPromises();
    (await page.take(request => request.url === '/api/models', 'reviewer registry read'))
      .resolve(jsonResponse({ models: [registryRow(VISION_MODEL, { projector: 'required' })] }));
    await flushPromises();
    const review = (await page.take(request => request.url === '/api/tools/image/review',
      'the review request'));
    const reviewBody = JSON.parse(review.options.body);
    assert.equal(reviewBody.sha256, FIXTURE_PNG_SHA256,
      'the review named an artifact other than the card own');
    assert.equal(reviewBody.model, VISION_MODEL,
      'the review named a model other than the confirmed reviewer');
    assert.equal(reviewBody.authorization, 'grant-token',
      'the review carried no grant, so the gateway would refuse it for want of a claim');
    assert.ok(Array.isArray(reviewBody.constraints) && reviewBody.constraints.length,
      'the review declared no hard constraint');
    review.resolve(jsonResponse(findingsFor({
      hard_constraints: [
        { name: 'prompt_subject', passed: false, observation: 'missing the lawn' }],
      composition_change_required: false,
      prompt_delta: 'on a green lawn',
      regenerate: true
    })));
    await flushPromises();

    const block = card.querySelector('.image-review');
    assert.ok(block, 'the admitted review rendered no checklist');
    assert.equal(block.children[0].textContent, `reviewed by ${VISION_MODEL}`);
    assert.ok(block.children[1].textContent.includes(`response model ${VISION_MODEL}`),
      'the review diagnostics omitted the model the gateway named');
    assert.equal(block.reviewResult.reasoning_present, true,
      'the reviewer emitted reasoning and the card recorded none');
    assert.equal(block.reviewResult.reasoning_content, null,
      'reasoning text reached the page from a gateway that reports its presence alone');

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
  (await page.take(request => request.url === '/api/tools/image/review',
    'the capped review request')).resolve(jsonResponse(findingsFor({
      hard_constraints: [
        { name: 'prompt_subject', passed: false, observation: 'still wrong' }],
      composition_change_required: false,
      prompt_delta: 'one more change',
      regenerate: true
    })));
  await flushPromises();
  await capped;
  assert.equal(page.pending.length, pendingBefore,
    'a review against a spent cap opened an approval dialog or sent a grant request');
  assert.equal(shared.correctionsUsed, 2, 'the cap moved past its two-correction ceiling');
  assert.ok(thirdCard.children.some(child => (child.textContent || '').includes('spent')),
    'the card does not state that the two approved corrections are already spent');
});
