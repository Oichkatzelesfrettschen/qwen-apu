/* Image generation, the artifact card it ends at, and the vision review that
   reads the card back.

   One approval carries the whole lane. The dialog shows the exact proposed
   arguments, `/api/tools/grant-image` signs a `qwen-image-generate-v1` grant
   over a hash of each prompt, the aspect, the max dimension, the step count,
   and the seed, and `POST /api/tools/image/generate` spends that grant once.
   The seed the grant binds is generated here where the model omitted one,
   because randomness is never chosen after authorization.

   An artifact link is the one `href` this page sets from a route rather than
   from markup, and it is set from bytes this page already verified:
   `loadArtifactBlobUrl` reads `/api/artifacts/<sha256>.png`, hashes what
   arrived, and refuses where the digest disagrees, so Open and Download name a
   blob URL over bytes this page proved. Every other URL a model writes stays inert text,
   because the whole transcript renders through `textContent`.

   A review runs from idle and returns to idle: `chatState.busy` gates it the
   way it gates a chat turn, so the appliance keeps one active workload. The
   verdict is one JSON object against a closed schema, and the correction it may
   propose opens the same approval dialog over the first approval's seed. */

import {
  $,
  randomSeed,
  recordSessionStatus,
  requestImageGrant,
  sha256Bytes,
  bytesToHex,
  sha256Hex
} from './api.js';
import { chatState } from './chat.js';
import {
  modelState,
  modelStateMatches,
  registryRowFor,
  registryProperties
} from './models.js';
import { resolveToolMatrix, toolMatrixRow, toolStateExecutes } from './tools.js';
import {
  conversationState,
  forgetArtifact,
  rememberArtifact,
  saveConversation
} from './conversations.js';

/* The image lane reads one row of the shared matrix. `resolveToolMatrix` owns
   the read and its cache, so the row here and the web rows beside it come from
   one document and a selection change replaces both at once. */
export const imageToolState = {
  definition: null,
  bounds: null,
  state: null,
  helper: null,
  reason: null,
  model: null,
  generation: -1
};

// The name the model proposes and `chat.js` dispatches on, composed the way
// llama-server composes an MCP server's tools: the `image` server's
// `generate_image`. The gateway executes the call through
// `POST /api/tools/image/generate` rather than through an MCP child, and the
// name stays the composed one so a transcript carrying an earlier proposal
// still dispatches.
const IMAGE_MCP_SERVER_NAME = 'image';
const IMAGE_MCP_TOOL_NAME = 'generate_image';
export const IMAGE_TOOL_NAME = `${IMAGE_MCP_SERVER_NAME}_${IMAGE_MCP_TOOL_NAME}`;
export const IMAGE_MATRIX_TOOL_ID = 'image_generation';

export function imageSchemaBounds(row) {
  /* Return the served profile and the maxima one matrix row states.

     `remote/image-profiles.tsv` is the authority: `max_dimension` and
     `max_steps` are what an authorization grant is checked against before a
     runtime argv is built, and the matrix carries them from the armed
     profile's own row. A row that states no bounds leaves each field null and
     the proposal's own value stands, because a bound nothing states refuses
     nothing. */
  const bounds = row && row.bounds;
  if (!bounds || typeof bounds !== 'object') {
    return { profile: null, width: null, height: null, steps: null };
  }
  const positive = value => (Number.isInteger(value) && value > 0 ? value : null);
  return {
    profile: typeof bounds.profile_id === 'string' && bounds.profile_id
      ? bounds.profile_id : null,
    width: positive(bounds.max_dimension),
    height: positive(bounds.max_dimension),
    steps: positive(bounds.max_steps)
  };
}

export function imageToolDefinition(bounds) {
  /* The function object one turn offers the model for an approved generation.

     Every bound here comes from the matrix row, which carries the armed
     profile's own `max_dimension` and `max_steps`. The schema is a prompt
     rather than a boundary: `remote/image_signed_verifier.py` compares each
     argument against the grant a human approved and
     `remote/image_protocol.py` re-checks the frame at the worker, so a
     proposal outside these numbers is refused by both whatever this object
     says. `authorization` is absent, because the gateway is the only issuer
     of a grant. */
  if (!bounds || !bounds.profile) return null;
  const integer = (maximum, minimum) => {
    const property = { type: 'integer', minimum };
    if (Number.isInteger(maximum) && maximum > 0) property.maximum = maximum;
    return property;
  };
  return {
    type: 'function',
    function: {
      name: IMAGE_TOOL_NAME,
      description:
        'Generate one image from an approved prompt. One human approval mints one '
        + 'single-use grant over the exact arguments, and the appliance runs one job '
        + 'with no queue.',
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          profile_id: { type: 'string', enum: [bounds.profile] },
          prompt: { type: 'string' },
          negative_prompt: { type: 'string' },
          seed: integer(SEED_MAXIMUM, 0),
          width: integer(bounds.width, IMAGE_DIMENSION_MINIMUM),
          height: integer(bounds.height, IMAGE_DIMENSION_MINIMUM),
          steps: integer(bounds.steps, 1)
        },
        required: ['prompt']
      }
    }
  };
}

export function forgetImageTools() {
  imageToolState.definition = null;
  imageToolState.bounds = null;
  imageToolState.state = null;
  imageToolState.helper = null;
  imageToolState.reason = null;
  imageToolState.model = null;
  imageToolState.generation = -1;
}

export async function resolveImageTools(selectedModel, generation) {
  /* Return { definition, bounds, state, helper, reason } for one selection.

     A definition is composed only where the matrix row admits a call, so a
     profile whose `execution_policy` reads `refused`, a launch that armed no
     image lane, and a worker whose control socket is unbound each leave the
     turn with no image tool and the row's own reason on the panel. */
  if (imageToolState.model === selectedModel && imageToolState.generation === generation) {
    return {
      definition: imageToolState.definition,
      bounds: imageToolState.bounds,
      state: imageToolState.state,
      helper: imageToolState.helper,
      reason: imageToolState.reason
    };
  }
  const matrix = await resolveToolMatrix(selectedModel, generation);
  const row = toolMatrixRow(matrix, IMAGE_MATRIX_TOOL_ID);
  const bounds = row && toolStateExecutes(row.state) ? imageSchemaBounds(row) : null;
  const resolved = {
    definition: bounds ? imageToolDefinition(bounds) : null,
    bounds,
    state: row ? row.state : null,
    helper: row ? row.helper : null,
    reason: row ? row.reason : null
  };
  if (modelStateMatches(selectedModel, generation)) {
    Object.assign(imageToolState, resolved,
      { model: selectedModel, generation });
  }
  return resolved;
}
// ==== end image generation: tool discovery ==================================


// ==== Image generation (PR D, UI half): proposal parsing and grant =========
const IMAGE_GRANT_CONTEXT = 'qwen-image-generate-v1';
// The frame bounds `remote/image_protocol.py` freezes, restated here for the
// schema a turn offers the model. The worker re-checks both, so these two
// numbers steer a proposal rather than admitting one.
const SEED_MAXIMUM = 4294967295;
const IMAGE_DIMENSION_MINIMUM = 64;
export const IMAGE_GENERATE_BUDGET_PER_TURN = 1;
// The 660 s bound is this page's own wait on the generation fetch; it names
// no runtime, image-service, MCP, or router deadline, each of which owns its
// own timeout on its own side of the call.
const IMAGE_GENERATION_TIMEOUT_MS = 660000;

export function aspectRatio(width, height) {
  const gcd = (a, b) => (b === 0 ? a : gcd(b, a % b));
  const divisor = gcd(width, height) || 1;
  return `${width / divisor}:${height / divisor}`;
}

export function proposedImageFields(argumentText) {
  /* Parse one proposed generate_image call into its dialog fields, or throw.

     A missing or malformed field cannot be shown to a human meaningfully, so
     this fails closed rather than substituting a value nobody proposed. The
     seed is the one exception: the brief assigns this page the authority to
     generate one when the model omits it, and the dialog names that case. */
  const parsed = JSON.parse(argumentText);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('the proposed arguments are not an object');
  }
  if (typeof parsed.prompt !== 'string' || !parsed.prompt) {
    throw new Error('prompt must be a non-empty string');
  }
  // The advertised schema names this argument profile_id, which is what a
  // model reading the listing emits; `profile` is read after it because the
  // dialog and the request both spell one field and a proposal that used the
  // shorter name would otherwise fail closed on a name the tool would accept.
  const proposedProfile = typeof parsed.profile_id === 'string' && parsed.profile_id
    ? parsed.profile_id
    : parsed.profile;
  if (typeof proposedProfile !== 'string' || !proposedProfile) {
    throw new Error('profile_id must be a non-empty string');
  }
  const requirePositiveInteger = key => {
    if (!Number.isInteger(parsed[key]) || parsed[key] <= 0) {
      throw new Error(`${key} must be a positive integer`);
    }
    return parsed[key];
  };
  const width = requirePositiveInteger('width');
  const height = requirePositiveInteger('height');
  const steps = requirePositiveInteger('steps');
  const negativePrompt = typeof parsed.negative_prompt === 'string' ? parsed.negative_prompt : '';
  let seed, seedGenerated;
  if ('seed' in parsed) {
    if (!Number.isInteger(parsed.seed) || parsed.seed < 0) {
      throw new Error('seed must be a non-negative integer');
    }
    seed = parsed.seed;
    seedGenerated = false;
  } else {
    seed = randomSeed();
    seedGenerated = true;
  }
  return { prompt: parsed.prompt, negative_prompt: negativePrompt, profile: proposedProfile,
           width, height, steps, seed, seedGenerated };
}

export function applyImageSchemaBounds(fields, bounds) {
  /* Return the fields the dialog shows and the grant is signed over, with the
     served profile in place of the proposed one, or throw the bound a
     dimension or step count exceeds.

     The proposal is a model's suggestion and the schema is what the section
     serves, so the two disagree in one direction: an argument above a stated
     maximum is refused here, ahead of the dialog and ahead of the per-turn
     budget, and the model reads the bound in its tool message and may propose
     again. `profile_id` takes the enum's one value rather than a refusal,
     because the section serves that profile whatever the model named and the
     broker signs for it alone; the dialog names the substitution so the human
     approving reads what will run. */
  const proposedProfile = fields.profile;
  if (fields.prompt.length > IMAGE_PROMPT_CHARACTER_CAP) {
    throw new Error(
      `prompt states ${fields.prompt.length} characters; ` +
      `the image service admits ${IMAGE_PROMPT_CHARACTER_CAP}`);
  }
  if (!bounds) return { ...fields, proposedProfile, profileReplaced: false };
  for (const key of ['width', 'height', 'steps']) {
    const ceiling = bounds[key];
    if (ceiling !== null && fields[key] > ceiling) {
      throw new Error(`${key} ${fields[key]} exceeds the ${ceiling} this image profile admits`);
    }
  }
  const served = bounds.profile;
  return {
    ...fields,
    profile: served || proposedProfile,
    proposedProfile,
    profileReplaced: Boolean(served) && served !== proposedProfile
  };
}

export function renderImageApprovalFields(fields) {
  const list = $('#image-approval-args');
  list.textContent = '';
  const row = (label, value, live) => {
    const term = document.createElement('dt');
    term.textContent = label;
    const detail = document.createElement('dd');
    detail.textContent = value;
    if (live) detail.className = 'live';
    list.append(term, detail);
  };
  row('prompt', fields.prompt);
  row('negative prompt', fields.negative_prompt || '(none)');
  row('seed', fields.seedGenerated
    ? `${fields.seed} -- generated by this page; the model proposed no seed`
    : String(fields.seed), fields.seedGenerated);
  row('width', String(fields.width));
  row('height', String(fields.height));
  row('steps', String(fields.steps));
  row('profile', fields.profile);
}


export async function imageGrantFields(fields, languageProfile, conversationGenerationValue) {
  /* Build the qwen-image-generate-v1 grant request. The grant binds a hash
     of each stripped prompt, the spelling image_grant.prompt_digest hashes on
     the broker side, rather than the prompt text, an aspect ratio and a single
     max-dimension bound rather than the exact pixel size, and the step count
     and conversation generation the dialog showed -- never the image bytes,
     which do not exist yet when this grant is requested. */
  const [promptHash, negativePromptHash] = await Promise.all([
    sha256Hex(fields.prompt.trim()), sha256Hex(fields.negative_prompt.trim())
  ]);
  return {
    context: IMAGE_GRANT_CONTEXT,
    language_profile: languageProfile,
    image_profile: fields.profile,
    prompt_hash: promptHash,
    negative_prompt_hash: negativePromptHash,
    seed: fields.seed,
    aspect: aspectRatio(fields.width, fields.height),
    max_dimension: Math.max(fields.width, fields.height),
    max_steps: fields.steps,
    conversation_generation: conversationGenerationValue
  };
}

export function approveImageGeneration(fields, proposalModel, correctionNote = '') {
  // Mirrors approveWebSearch(): one approval or a refusal, a single-use
  // grant, and an abort of the in-flight grant request on denial or
  // dismissal so a late click cannot spend the rate bucket for a dialog the
  // human already closed.
  return new Promise(resolve => {
    const dialog = $('#image-approval');
    const note = $('#image-approval-note');
    note.hidden = true;
    note.textContent = '';
    renderImageApprovalFields(fields);
    if (correctionNote) {
      // A correction is a second approval over the first approval's seed, so
      // the dialog says which correction this is and where the seed came
      // from before the human reads the changed prompt.
      note.hidden = false;
      note.textContent = correctionNote;
    }
    if (fields.profileReplaced) {
      // The profile row shows what runs, and this line shows what the model
      // asked for, so the human approves the substitution rather than meeting
      // it in the broker's refusal after the click.
      note.hidden = false;
      note.textContent = (correctionNote ? correctionNote + '; ' : '') +
        `the model proposed profile ${fields.proposedProfile}; ` +
        `this appliance serves ${fields.profile}, and the grant names the served profile`;
    }
    const once = $('#image-approve-once');
    const deny = $('#image-approve-deny');
    let settled = false;
    const controller = new AbortController();
    const finish = outcome => {
      if (settled) return;
      settled = true;
      once.onclick = null;
      deny.onclick = null;
      dialog.onclose = null;
      once.disabled = false;
      dialog.close();
      resolve(outcome);
    };
    once.onclick = async () => {
      once.disabled = true;
      try {
        if (modelState.requestModel !== proposalModel) {
          finish({
            decision: 'deny',
            reason: `it was proposed by model ${proposalModel}, ` +
                    `the current model is ${modelState.requestModel}`
          });
          return;
        }
        const grantFields = await imageGrantFields(fields, modelState.requestModel, conversationState.generation);
        const authorization = await requestImageGrant(grantFields, controller.signal);
        finish({ decision: 'once', authorization });
      } catch (error) {
        // Every throw in this handler ends the dialog: the digest, the session
        // read, and the broker's own refusal all land here, and a dialog left
        // open holds `chatState.busy` for the whole turn while the model waits on a tool
        // message that never arrives. The caller answers the call with this
        // reason, so a refused grant reaches the model instead of the page.
        finish({ decision: 'failed', reason: String(error.message || error) });
      }
    };
    deny.onclick = () => {
      controller.abort();
      finish({ decision: 'deny' });
    };
    dialog.onclose = () => {
      controller.abort();
      finish({ decision: 'deny' });
    };
    dialog.showModal();
  });
}
// ==== end image generation: proposal parsing and grant ======================

// ==== Image review (PR F, UI half) ==========================================
// A completed generation ends at an artifact card, and a review is the next
// transition through idle: the page reads the artifact once more through the
// credentialed route, sends it to a vision model that is offered no tool at
// all, and renders the verdict beside the image. `chatState.busy` gates the whole span,
// so a chat turn and a review never run together and the appliance keeps one
// active workload.
//
// The verdict is one JSON object against a closed schema, parsed here the way
// remote/image-review.py parses it: prose, an extra key, a missing key, a
// `passed` that is not a boolean, and a constraint list naming anything other
// than what this page declared are each refused, because a tolerant parse
// would render a verdict the model did not state.
//
// A correction is a proposal rather than an execution. The page composes the
// original prompt with the review's own delta, carries the seed the first
// approval bound, and opens the same approval dialog; two corrections per
// original request are the whole allowance, and the counter travels on the
// card so a correction's own review inherits it.
const REVIEW_TIMEOUT_MS = 300000;
const IMAGE_CORRECTION_CAP = 2;
const IMAGE_PROMPT_CHARACTER_CAP = 2000;

export function registeredReviewModel(imageProfileId) {
  /* Return the reviewer assigned to one image profile where /v1/models also
     names it. The feature roster selects the pairing, and the live picker
     remains the authority for model ids the router can serve. */
  const imageProfiles = modelState.roster && Array.isArray(modelState.roster.image_profiles)
    ? modelState.roster.image_profiles : [];
  const profile = imageProfiles.find(row => row && row.id === imageProfileId);
  const reviewModel = profile && typeof profile.review_model === 'string'
    ? profile.review_model : '';
  if (!reviewModel || reviewModel === '-') return null;
  const served = [...$('#model-picker').options]
    .some(option => option.value === reviewModel);
  return served ? reviewModel : null;
}

export async function confirmVisionReviewModel(reviewModel, generation, signal) {
  /* Confirm the registered reviewer through one live registry read after the
     review click. A generation change or a model the registry no longer
     carries refuses the review before its artifact or completion request
     begins, and the projector pairing the row states is what proves the
     reviewer reads an image at all. */
  if (!reviewModel || generation !== modelState.generation ||
      ![...$('#model-picker').options].some(option => option.value === reviewModel)) {
    return null;
  }
  const row = await registryRowFor(reviewModel, signal);
  if (generation !== modelState.generation ||
      ![...$('#model-picker').options].some(option => option.value === reviewModel)) {
    return null;
  }
  if (!row) {
    throw new Error(`the registry carries no row for the registered review model ${reviewModel}`);
  }
  return registryProperties(row).modalities.vision === true ? reviewModel : null;
}

export function reviewHardConstraints(fields) {
  /* Name what this review judges, from the fields the human already approved.

     The generation prompt reaches the vision model here rather than in the
     request's own prompt slot: a hard constraint is a named requirement the
     verdict answers one entry for, and the grant already bound this text. A
     negative prompt adds its own constraint exactly where the approval carried
     one. */
  const constraints = [{
    name: 'prompt_subject',
    description: `the image shows what this generation prompt describes: ${fields.prompt}`
  }];
  const negative = (fields.negative_prompt || '').trim();
  if (negative) {
    constraints.push({
      name: 'negative_prompt_absent',
      description: `the image shows none of what this negative prompt names: ${negative}`
    });
  }
  return constraints;
}

export function reviewCorrectionAdmitted(verdict) {
  /* Three facts admit a correction: a constraint the model marked failed, the
     regenerate flag, and a delta stating what to change. Any other combination
     is reported with the fact it lacks, which is what the card renders. */
  const failed = verdict.hard_constraints.filter(entry => !entry.passed);
  if (!verdict.regenerate) {
    return { admitted: false, reason: 'the verdict asks for no regeneration' };
  }
  if (!failed.length) {
    return { admitted: false,
             reason: 'the verdict asks to regenerate with every hard constraint passed' };
  }
  if (!verdict.prompt_delta.trim()) {
    return { admitted: false,
             reason: 'the verdict asks to regenerate and states no prompt delta' };
  }
  return { admitted: true,
           reason: 'the verdict names a failed hard constraint and states its correction' };
}

export function reviewResultFromFindings(findings, requestedModel) {
  /* The card's own record, built from the three findings the gateway reports.

     `remote/image-review.py`'s strict parser ran on the server, so the verdict
     here is one that already passed the closed four-key schema; this function
     restates the transport facts the card renders beside it and reads the
     reviewer the gateway named rather than the one the click asked for, since
     a served model other than the registered one is itself a finding. */
  const validity = findings.schema_validity || {};
  const completion = findings.completion || {};
  return {
    verdict: validity.verdict,
    requested_model: requestedModel,
    response_model: typeof findings.model === 'string' && findings.model
      ? findings.model : null,
    finish_reason: completion.answered ? 'stop' : 'none',
    usage: null,
    completion_tokens: null,
    reasoning_present: Boolean(completion.reasoning_emitted),
    reasoning_content: null
  };
}

export function renderReviewChecklist(card, reviewResult) {
  const verdict = reviewResult.verdict;
  const existing = card.querySelector('.image-review');
  if (existing) existing.remove();
  const block = document.createElement('div');
  block.className = 'image-review';
  const heading = document.createElement('div');
  heading.className = 'meta';
  const responseModel = reviewResult.response_model
    ? `; response model ${reviewResult.response_model}` : '';
  const completionTokens = reviewResult.completion_tokens === null
    ? '; completion tokens unreported'
    : `; completion tokens ${reviewResult.completion_tokens}`;
  heading.textContent = `reviewed by ${reviewResult.requested_model}`;
  block.append(heading);
  const diagnostics = document.createElement('div');
  diagnostics.className = 'review-diagnostics meta';
  diagnostics.textContent = `finish ${reviewResult.finish_reason}${completionTokens}${responseModel}`;
  block.append(diagnostics);
  // The structured result remains attached to the live card for diagnosis.
  // Conversation persistence never reads the card, so reasoning text and
  // response usage reach neither saved history nor later model requests.
  block.reviewResult = reviewResult;
  const list = document.createElement('ul');
  for (const entry of verdict.hard_constraints) {
    const item = document.createElement('li');
    item.className = entry.passed ? 'pass' : 'fail';
    // textContent: an observation is text a model wrote after reading an image
    // whose own text this appliance treats as content, so it renders as text
    // and never as markup.
    item.textContent = `${entry.passed ? 'pass' : 'fail'} ${entry.name}: ${entry.observation}`;
    list.append(item);
  }
  block.append(list);
  const composition = document.createElement('div');
  composition.className = 'meta';
  composition.textContent =
    `composition change required: ${verdict.composition_change_required ? 'yes' : 'no'}`;
  block.append(composition);
  card.append(block);
  return block;
}

export function appendReviewNote(card, text, bad) {
  const note = document.createElement('div');
  note.className = bad ? 'meta image-review-note bad' : 'meta image-review-note';
  note.textContent = text;
  card.append(note);
  return note;
}

export function openCorrectionState(card) {
  const el = document.createElement('div');
  el.className = 'meta image-state';
  el.textContent = 'Approved';
  card.after(el);
  return el;
}

export async function proposeImageCorrection(card, fields, lineage, verdict) {
  /* Open one approval over the corrected prompt, and run the generation only
     where the human approves it.

     The seed is the first approval's, carried rather than regenerated, so the
     correction changes the prompt alone against the same sample. The composed
     prompt meets the schema's own bounds before the dialog opens, the way a
     model's proposal does, so a correction outside them is answered on the
     card rather than refused after the click. */
  const correctionNumber = lineage.state.correctionsUsed + 1;
  const delta = verdict.prompt_delta.trim();
  const corrected = { ...fields, prompt: `${fields.prompt} ${delta}`, seedGenerated: false };
  let bounded;
  try {
    bounded = applyImageSchemaBounds(corrected, lineage.bounds);
  } catch (error) {
    appendReviewNote(card, `The correction did not run: ${error.message || error}.`, true);
    return;
  }
  const note = `correction ${correctionNumber} of ${IMAGE_CORRECTION_CAP}; ` +
    `seed ${fields.seed} is carried from the first approval and the prompt gains ` +
    'the review\'s delta';
  // `imageOutcome` rather than `outcome`: the image grant and the web search
  // grant are separate single-use tokens, and the dispatch path already spells
  // the image one this way.
  const imageOutcome = await approveImageGeneration(bounded, lineage.model, note);
  if (imageOutcome.decision !== 'once') {
    appendReviewNote(card, imageOutcome.reason
      ? `The correction did not run: ${imageOutcome.reason}.`
      : 'The user refused this correction. It did not run.');
    return;
  }
  // The approval spends one lineage slot even when the runtime later refuses
  // or fails. Every card shares this object, so revisiting an earlier card
  // cannot reopen an already spent correction number.
  lineage.state.correctionsUsed = correctionNumber;
  const stateEl = openCorrectionState(card);
  const params = imageRequestParams(bounded, imageOutcome.authorization);
  const execution = await executeImageGeneration(
    stateEl, lineage.container, bounded, params,
    { state: lineage.state, model: lineage.model, bounds: lineage.bounds,
      authorization: imageOutcome.authorization,
      entry: lineage.entry, entryGeneration: lineage.entryGeneration });
  if (!execution.ok) {
    appendReviewNote(card, execution.text, true);
  }
}

export async function runImageReview(card, fields, lineage) {
  /* Run one review of one artifact from idle and return the page to idle.

     `chatState.busy` is the same flag a chat turn holds, so a review starts only where
     no turn is running and a turn starts only where no review is. The verdict,
     its observations, and any correction stay out of `history`: the language
     model that proposed the generation never reads what a vision model saw in
     the image, which keeps image-derived text out of the transcript every
     later request re-sends. */
  if (chatState.busy) return;
  chatState.busy = true;
  $('#send').disabled = true;
  const button = card.querySelector('.image-review-button');
  if (button) button.disabled = true;
  // One controller covers every awaited fetch in this span -- the props
  // reads, the artifact read, and the completion -- because a stalled listener
  // on any of them would hold `chatState.busy` and the send button for the session.
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REVIEW_TIMEOUT_MS);
  const reviewGeneration = conversationState.generation;
  const reviewModelGeneration = modelState.generation;
  const reviewIsCurrent = () => reviewGeneration === conversationState.generation &&
    reviewModelGeneration === modelState.generation && card.isConnected;
  try {
    const visionModel = await confirmVisionReviewModel(
      lineage.reviewModel, reviewModelGeneration, controller.signal);
    if (!reviewIsCurrent()) return;
    if (!visionModel) {
      appendReviewNote(card,
        'The registered review model is unavailable or reports no vision capability, ' +
        'so no review ran.', true);
      return;
    }
    const constraints = reviewHardConstraints(fields);
    if (!lineage.authorization) {
      appendReviewNote(card,
        'The grant that approved this generation is no longer held by this page, ' +
        'so no review ran.', true);
      return;
    }
    const findings = await requestArtifactReview({
      sha256: lineage.sha256,
      model: visionModel,
      authorization: lineage.authorization,
      constraints
    }, controller.signal);
    if (!reviewIsCurrent()) return;
    if (!findings.completion || !findings.completion.answered) {
      const code = (findings.completion && findings.completion.refusal_code) || 'no reply';
      appendReviewNote(card, `The reviewer returned no completion: ${code}.`, true);
      return;
    }
    if (!findings.schema_validity || !findings.schema_validity.valid) {
      const code = (findings.schema_validity && findings.schema_validity.refusal_code)
        || 'the reply left the verdict schema';
      appendReviewNote(card,
        `The reviewer completed and its reply failed the verdict schema: ${code}.`, true);
      return;
    }
    const reviewResult = reviewResultFromFindings(findings, visionModel);
    const verdict = reviewResult.verdict;
    renderReviewChecklist(card, reviewResult);
    const judgment = findings.judgment || {};
    if (!judgment.correction_admitted) {
      appendReviewNote(card,
        `No correction is proposed: ${judgment.correction_reason || 'the verdict admits none'}.`);
      return;
    }
    if (lineage.state.correctionsUsed >= IMAGE_CORRECTION_CAP) {
      appendReviewNote(card,
        `The ${IMAGE_CORRECTION_CAP} approved corrections for this request are spent, ` +
        'so this verdict proposes none.');
      return;
    }
    await proposeImageCorrection(card, fields, lineage, verdict);
  } catch (error) {
    const reason = error.name === 'AbortError'
      ? `the review timed out after ${REVIEW_TIMEOUT_MS / 1000}s`
      : (error.message || String(error));
    appendReviewNote(card, `The review did not complete: ${reason}.`, true);
  } finally {
    clearTimeout(timeoutId);
    if (button) button.disabled = false;
    chatState.busy = false;
    $('#send').disabled = false;
  }
}
// ==== end image review ======================================================

export function imageRequestParams(fields, authorization) {
  return {
    prompt: fields.prompt,
    negative_prompt: fields.negative_prompt,
    seed: fields.seed,
    width: fields.width,
    height: fields.height,
    steps: fields.steps,
    // remote/image-mcp/server.py names this argument profile_id, lists it in
    // `required`, and refuses any name outside its schema, so the wire
    // spelling is the tool's rather than the proposal's.
    profile_id: fields.profile,
    authorization
  };
}

export function renderImageState(container, text, isError) {
  container.textContent = text;
  container.className = 'meta image-state' + (isError ? ' bad' : '');
}

export function parseCompletedImageResult(parsed) {
  /* Read the artifact identity out of a completed generation, or throw.

     `POST /api/tools/image/generate` answers a completion with `sha256`,
     `artifact_url`, and `provenance_url` and every refusal with `error`
     (src/qwen_apu/tools/images.py), so a body reaching this function already
     passed that branch. The digest and the provenance route are the only two
     identifying fields this page keeps; the image bytes and the spent grant
     never reach here. */
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('the result body is not a JSON object');
  }
  if (typeof parsed.sha256 !== 'string' || !parsed.sha256) {
    throw new Error('the result carries no sha256');
  }
  if (typeof parsed.provenance_url !== 'string' || !parsed.provenance_url) {
    throw new Error('the result carries no provenance_url');
  }
  return { sha256: parsed.sha256, provenanceUrl: parsed.provenance_url };
}

export function buildImageToolResultSummary(artifactReference) {
  /* The model receives only a conversation-local reference to the verified
     card. The card owns every route and action; model-authored Markdown can
     therefore describe an image but cannot become an artifact control. */
  return `Image artifact ${artifactReference} is available in this conversation.`;
}

// The artifact listener answers a completed generation from disk, and the turn
// waits on that read, so the bound is the page's own and far below the
// generation's: an unresponsive listener ends the turn with a tool message
// rather than holding the send button for the generation timeout.
const ARTIFACT_FETCH_TIMEOUT_MS = 60000;

const ARTIFACT_DIGEST_PATTERN = /^[0-9a-f]{64}$/;

export async function responseBytes(response, subject) {
  if (!response.ok) {
    throw new Error(`the ${subject} fetch returned HTTP ${response.status}`);
  }
  return new Uint8Array(await response.arrayBuffer());
}

export function verifiedDigest(bytes, expected, subject) {
  const observed = bytesToHex(sha256Bytes(bytes));
  if (observed !== expected) {
    throw new Error(`the ${subject} bytes hash to ${observed}, not ${expected}`);
  }
}

export async function loadArtifactBlobUrl(result, callerSignal) {
  /* Fetch the artifact PNG under the same session the page sends for chat --
     an <img src> carries no fetch of its own to verify, and the hash never
     substitutes for the session in a query parameter -- and hand back a local
     blob URL the caller owns and must revoke.

     The route is derived from the digest rather than taken from the result:
     image-service.py's provenance_url names the `.json` record and its
     artifact_url names the `.png`, both from the same digest, so the page
     reads the record's identity and composes the image route itself. The
     gateway owns that route beside every other one this page calls. */
  if (!result || !ARTIFACT_DIGEST_PATTERN.test(result.sha256 || '')) {
    throw new Error('the artifact sha256 must be 64 lowercase hexadecimal characters');
  }
  const controller = new AbortController();
  let timedOut = false;
  const abortFromCaller = () => controller.abort();
  if (callerSignal) {
    if (callerSignal.aborted) controller.abort();
    else callerSignal.addEventListener('abort', abortFromCaller, { once: true });
  }
  const timeoutId = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, ARTIFACT_FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(`/api/artifacts/${result.sha256}.png`,
      { signal: controller.signal });
    recordSessionStatus(response.status);
    const bytes = await responseBytes(response, 'artifact');
    verifiedDigest(bytes, result.sha256, 'artifact');
    const blob = new Blob([bytes], { type: 'image/png' });
    return URL.createObjectURL(blob);
  } catch (error) {
    if (error.name === 'AbortError') {
      if (callerSignal && callerSignal.aborted) {
        throw new Error('the artifact fetch was cancelled by the user');
      }
      if (!timedOut) throw error;
      throw new Error(
        `the artifact fetch timed out after ${ARTIFACT_FETCH_TIMEOUT_MS / 1000}s`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
    if (callerSignal) callerSignal.removeEventListener('abort', abortFromCaller);
  }
}

export async function renderImageArtifactCard(container, fields, result, lineage, signal) {
  /* Build the artifact card around a blob URL this call already holds, or
     throw what the fetch refused. The turn ends on the artifact rather than
     ahead of it: a card whose image never arrives would otherwise leave the
     model told the image is present while the page shows an empty frame. */
  const blobUrl = await loadArtifactBlobUrl(result, signal);
  const card = document.createElement('figure');
  card.className = 'image-artifact';
  const img = document.createElement('img');
  img.alt = fields.prompt;
  card.append(img);
  const caption = document.createElement('figcaption');
  const parts = [
    `sha256 ${result.sha256}`,
    `seed ${fields.seed}`,
    `${fields.width}x${fields.height}`,
    `${fields.steps} steps`,
    fields.profile
  ];
  caption.textContent = parts.join(' | ');
  card.append(caption);
  // The card carries what a review and any correction it proposes need: the
  // artifact's own digest, the seed the first approval bound, how many of the
  // two corrections this request has spent, and the section that serves the
  // image child. A correction's card inherits the same counter, so the cap
  // belongs to the original request rather than to one card.
  //
  // entry and entryGeneration name the message this artifact belongs to. A
  // correction's own render call carries them forward from the card that
  // proposed the original generation (lineage.entry, set below on first
  // creation), rather than reading conversationState.activeAssistantEntry again: by the time a
  // human approves a correction, that global may already point at a newer
  // assistant message, and writing there would attach the corrected image to
  // the wrong turn.
  const originEntry = (lineage && lineage.entry) || conversationState.activeAssistantEntry;
  const originGeneration = (lineage && lineage.entry)
    ? lineage.entryGeneration : conversationState.activeAssistantGeneration;
  const cardLineage = {
    sha256: result.sha256,
    state: (lineage && lineage.state) || { correctionsUsed: 0 },
    model: lineage && lineage.model,
    bounds: lineage && lineage.bounds,
    // The grant the generation ran under. `POST /api/tools/image/review`
    // verifies the claim and spends nothing, so the already-spent token still
    // proves which prompt a human approved, and `_bind_provenance` requires
    // its `prompt_hash` to equal the record's own `prompt_sha256`. The token
    // stays in page memory: `rememberArtifact` writes the digest and the
    // provenance route alone, so no grant reaches saved history or a later
    // model request.
    authorization: lineage && lineage.authorization,
    reviewModel: registeredReviewModel(fields.profile),
    entry: originEntry,
    entryGeneration: originGeneration,
    container
  };
  // The conversation record keeps the digest and the provenance route the tool
  // result named, so a later reader refetches these bytes by digest rather than
  // reading them out of a store. The returned record is the exact array entry
  // this card owns, so removing the card can splice that one entry back out.
  const artifactRecord = rememberArtifact(originEntry, originGeneration, fields, result);
  if (!artifactRecord) {
    URL.revokeObjectURL(blobUrl);
    throw new Error('the artifact belongs to a conversation that is no longer active');
  }
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
  downloadLink.download = `${artifactRecord.reference}.png`;
  card.append(downloadLink);
  const removeButton = document.createElement('button');
  removeButton.className = 'act';
  removeButton.textContent = 'remove image';
  removeButton.onclick = () => {
    // The card goes whatever the gateway answers: a reader who asked for the
    // image to leave the page has been served once it does. The retraction is
    // the second half -- it unpublishes the pair so every later read of either
    // digest answers 404 -- and a failure there is reported rather than
    // hidden, since the artifact then still reads through its route.
    if (blobUrl) URL.revokeObjectURL(blobUrl);
    forgetArtifact(originEntry, originGeneration, artifactRecord);
    void saveConversation();
    const container_ = card.parentNode;
    card.remove();
    void removePublishedArtifact(result.sha256).catch(error => {
      if (!container_) return;
      const note = document.createElement('div');
      note.className = 'meta image-review-note bad';
      note.textContent =
        `The image left this page and its publication stands: ${error.message || error}.`;
      container_.append(note);
    });
  };
  card.append(removeButton);
  const reviewButton = document.createElement('button');
  reviewButton.className = 'act image-review-button';
  reviewButton.textContent = 'review';
  reviewButton.hidden = !cardLineage.reviewModel;
  reviewButton.onclick = () => { void runImageReview(card, fields, cardLineage); };
  card.append(reviewButton);
  // Artifact rendering reads the declared pairing alone. The explicit review
  // click confirms that one model's live vision capability before loading the
  // image again, so creating a card never changes router residency.
  img.src = blobUrl;
  container.append(card);
  void saveConversation();
  return artifactRecord;
}

/* The three control routes the gateway serves beside the generation, each
   carrying the session rather than a grant: each names a job or an artifact
   this page already produced and describes no generation. */
const IMAGE_STATUS_ROUTE = '/api/tools/image/status';
const IMAGE_CANCEL_ROUTE = '/api/tools/image/cancel';
const IMAGE_REMOVE_ROUTE = '/api/tools/image/remove';

export function probeRequestId() {
  /* An identifier for one control read, inside the protocol's own set.

     A `status` read observes the worker rather than a job, so the identifier
     it carries is a correlation handle the reply echoes back and nothing
     else; the running job's own identifier comes back as `job_request_id`. */
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return `p${[...bytes].map(byte => byte.toString(16).padStart(2, '0')).join('')}`;
}

async function postImageControl(route, body, signal) {
  const response = await fetch(route, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal
  });
  recordSessionStatus(response.status);
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload) {
    const stated = payload && typeof payload.error === 'string'
      ? payload.error : `HTTP ${response.status}`;
    throw new Error(stated);
  }
  return payload;
}

export function readImageJobStatus(signal) {
  /* Read the worker's observation of itself: phase, job, lease, and pid. */
  return postImageControl(IMAGE_STATUS_ROUTE, { request_id: probeRequestId() }, signal);
}

export async function cancelRunningImageJob(signal) {
  /* End the generation the worker is running, naming it by its own identifier.

     `remote/image-service.py`'s `handle_cancel` refuses every identifier but
     the running job's, which `status` reports as `job_request_id`, so the
     cancel is addressed from the worker's own observation rather than from a
     value this page chose. A worker holding no job reports none, and the call
     answers that rather than sending a cancel nothing would act on. */
  const observed = await readImageJobStatus(signal);
  const jobRequestId = typeof observed.job_request_id === 'string'
    ? observed.job_request_id : '';
  if (!jobRequestId) {
    return { cancelled: false, lease_held: Boolean(observed.lease_held),
             state: observed.state || 'idle', reason: 'no_job_running' };
  }
  return postImageControl(IMAGE_CANCEL_ROUTE, { request_id: jobRequestId }, signal);
}

export function removePublishedArtifact(sha256, signal) {
  /* Retract one artifact's publication, which unpublishes the pair.

     The gateway unlinks the marker the worker wrote, which unpublishes the
     pair and deletes nothing: the worker's own retention sweep enumerates
     markers, so the bytes behind a retracted one stay until an operator
     disposes of them. The answer states `payload_removed: false` and names
     that disposal path rather than implying a sweep will reach them. */
  return postImageControl(IMAGE_REMOVE_ROUTE, { sha256 }, signal);
}

export function requestArtifactReview(request, signal) {
  /* Run one review of one published artifact through the gateway.

     `POST /api/tools/image/review` reads the artifact through the publication
     marker, sends it to the registered reviewer over the router, and reports
     completion, schema validity, and judgment apart: a router that answered is
     a completion whatever its content says, a reply that parses against the
     closed four-key schema is valid whatever it judges, and a judgment exists
     only where both hold. The page renders the three rather than collapsing
     them, because a grammar-bounded reply that still fails the strict parser
     is itself the finding this appliance measures. */
  return postImageControl('/api/tools/image/review', request, signal);
}

export function openImageState(view) {
  const el = document.createElement('div');
  el.className = 'meta image-state';
  el.textContent = 'Approved';
  view.turn.root.insertBefore(el, view.meta);
  return el;
}

export async function executeImageGeneration(stateEl, artifactContainer, fields, params,
                                       lineage) {
  /* Run one approved generate_image call and drive the synchronous state
     line through Approved -> Generating image... -> Image complete or Image
     failed. `images.generate` answers every refusal -- the grant, the worker,
     the frame -- as `{"error": ...}` with its own status, so that one key
     produces "Image failed:" and reads its reason from the body rather than
     from the HTTP status. */
  renderImageState(stateEl, 'Approved');
  // Yields one microtask so "Approved" paints before "Generating image..."
  // overwrites it; openImageState() already set this text, so this call
  // re-states it rather than skipping straight to the next phase.
  await Promise.resolve();
  renderImageState(stateEl, 'Generating image...');
  const requestController = new AbortController();
  const cancellationController = new AbortController();
  let cancelled = false;
  const cancelButton = document.createElement('button');
  cancelButton.className = 'act';
  cancelButton.textContent = 'cancel';
  cancelButton.onclick = () => {
    cancelled = true;
    // The abort ends this page's own wait and the cancel ends the worker's
    // job: `POST /api/tools/image/generate` is synchronous, so without the
    // second call the runtime would hold the Vulkan workload lease to its own
    // deadline with nobody reading the result. The cancel names the job by the
    // identifier `status` reports, so it reaches this generation alone. The
    // grant is single-use and was spent before dispatch, so it stays spent and
    // a retry takes a fresh approval.
    void cancelRunningImageJob().catch(() => {});
    requestController.abort();
    cancellationController.abort();
  };
  stateEl.after(cancelButton);
  const timeoutId = setTimeout(
    () => requestController.abort(), IMAGE_GENERATION_TIMEOUT_MS);
  try {
    let response;
    try {
      response = await fetch('/api/tools/image/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
        signal: requestController.signal
      });
      recordSessionStatus(response.status);
    } catch (error) {
      const reason = cancelled
        ? 'cancelled by the user'
        : error.name === 'AbortError'
          ? `the request timed out after ${IMAGE_GENERATION_TIMEOUT_MS / 1000}s`
          : (error.message || String(error));
      renderImageState(stateEl, `Image failed: ${reason}`, true);
      return { ok: false, text: `The image did not complete: ${reason}` };
    }
    let payload = null;
    try { payload = await response.json(); } catch { payload = null; }
    if (payload && typeof payload.error === 'string') {
      renderImageState(stateEl, `Image failed: ${payload.error}`, true);
      return { ok: false, text: `The image did not complete: ${payload.error}` };
    }
    if (!response.ok || !payload) {
      const reason = `HTTP ${response.status} with no result body`;
      renderImageState(stateEl, `Image failed: ${reason}`, true);
      return { ok: false, text: `The image did not complete: ${reason}` };
    }
    let result;
    try {
      result = parseCompletedImageResult(payload);
    } catch (error) {
      const reason = error.message || String(error);
      renderImageState(stateEl, `Image failed: ${reason}`, true);
      return { ok: false, text: `The image did not complete: ${reason}` };
    }
    let artifactRecord;
    try {
      artifactRecord = await renderImageArtifactCard(
        artifactContainer, fields, result, lineage, cancellationController.signal);
    } catch (error) {
      // The service holds the artifact and the page failed to read it, so the
      // model is told the identity it can retry against rather than that the
      // generation succeeded.
      const reason = cancelled
        ? 'cancelled by the user'
        : `the artifact did not load: ${error.message || error}`;
      renderImageState(stateEl, `Image failed: ${reason}`, true);
      return {
        ok: false,
        text: `The image generated as sha256 ${result.sha256} and this page could not display it: ${reason}`
      };
    }
    if (cancelled) {
      const reason = 'cancelled by the user';
      renderImageState(stateEl, `Image failed: ${reason}`, true);
      return { ok: false, text: `The image did not complete: ${reason}` };
    }
    renderImageState(stateEl, 'Image complete');
    return { ok: true, text: buildImageToolResultSummary(artifactRecord.reference) };
  } finally {
    clearTimeout(timeoutId);
    cancelButton.remove();
  }
}
// ==== end image generation: execution and rendering =========================
