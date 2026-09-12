/* The image studio: one prompt, one grant, one job, one gallery.

   The human writes the prompt here, so the click on Generate is the approval
   the grant records: `POST /api/tools/grant-image` binds the prompt digests,
   the seed, the aspect, the dimension bound, and the step count under the
   language profile and image profile `GET /api/status` reports as
   `gateway.approvals`, and `POST /api/tools/image/generate` spends that grant
   once. `GET /api/tools?model=<language profile>` carries the served image
   profile's frame as the `image_generation` row's bounds, which is what the
   size chip and the step ceiling read. The gallery is `GET /api/artifacts`,
   the store the worker publishes into, so a reload shows what the appliance
   holds rather than what this tab remembers. */

import {
  $, randomSeed, recordSessionStatus, requestImageGrant, sha256Hex
} from './api.js';

const IMAGE_GRANT_CONTEXT = 'qwen-image-generate-v1';
const IMAGE_TOOL_ID = 'image_generation';
const MATRIX_ROUTE = '/api/tools';
const GENERATE_ROUTE = '/api/tools/image/generate';
const STATUS_ROUTE = '/api/tools/image/status';
const CANCEL_ROUTE = '/api/tools/image/cancel';
const REMOVE_ROUTE = '/api/tools/image/remove';
const ARTIFACTS_ROUTE = '/api/artifacts';
const STATUS_POLL_MS = 2000;
const GENERATION_TIMEOUT_MS = 330000;

export const studioState = {
  initialized: false,
  languageProfile: '',
  bounds: null,
  offerState: '',
  running: null,
  artifacts: []
};

function aspectRatio(width, height) {
  const gcd = (a, b) => (b === 0 ? a : gcd(b, a % b));
  const divisor = gcd(width, height) || 1;
  return `${width / divisor}:${height / divisor}`;
}

function setState(text, tone = '') {
  const element = $('#image-state');
  element.textContent = text;
  element.setAttribute('data-tone', tone);
}

function setNote(text) {
  const note = $('#image-note');
  note.hidden = !text;
  note.textContent = text || '';
}

function probeRequestId() {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return `p${[...bytes].map(byte => byte.toString(16).padStart(2, '0')).join('')}`;
}

async function postJson(route, body, signal) {
  const response = await fetch(route, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal
  });
  recordSessionStatus(response.status);
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload) {
    const stated = payload && typeof payload.error === 'string' ? payload.error : `HTTP ${response.status}`;
    throw new Error(stated);
  }
  if (typeof payload.error === 'string') throw new Error(payload.error);
  return payload;
}

// -- the profile ----------------------------------------------------------

export async function readBounds(languageProfile) {
  const response = await fetch(`${MATRIX_ROUTE}?model=${encodeURIComponent(languageProfile)}`);
  recordSessionStatus(response.status);
  if (!response.ok) throw new Error(`the tool matrix answered HTTP ${response.status}`);
  const matrix = await response.json();
  const rows = Array.isArray(matrix.tools) ? matrix.tools : [];
  const row = rows.find(entry => entry && entry.tool_id === IMAGE_TOOL_ID);
  if (!row) throw new Error(`the matrix for ${languageProfile} carries no ${IMAGE_TOOL_ID} row`);
  return { state: String(row.state || ''), reason: String(row.reason || ''), bounds: row.bounds || null };
}

function applyBounds(offer) {
  studioState.offerState = offer.state;
  studioState.bounds = offer.bounds;
  const profileLine = $('#image-profile');
  const size = $('#image-size');
  const steps = $('#image-steps');
  const generate = $('#image-generate');
  const bounds = offer.bounds;
  if (!bounds || !bounds.profile_id) {
    profileLine.textContent = offer.reason || 'this launch serves no image profile';
    size.textContent = 'size unknown';
    generate.disabled = true;
    return;
  }
  const width = Number(bounds.width);
  const height = Number(bounds.height);
  const maxSteps = Number(bounds.max_steps) || 1;
  profileLine.textContent = `${bounds.profile_id} on this appliance, one job at a time`;
  size.textContent = `${width} x ${height}`;
  steps.setAttribute('max', String(maxSteps));
  const current = Number(steps.value) || 0;
  if (current < 1 || current > maxSteps) steps.value = String(Math.min(maxSteps, 4));
  const executes = offer.state === 'available' || offer.state === 'available_through_helper';
  generate.disabled = !executes;
  if (!executes) setNote(offer.reason || `the image lane is ${offer.state}`);
  else setNote('');
}

// -- the gallery ----------------------------------------------------------

function renderArtifact(entry, extra = {}) {
  const card = document.createElement('article');
  card.className = 'artifact';
  card.dataset.sha256 = entry.png_sha256;
  const link = document.createElement('a');
  link.href = entry.png_url;
  link.target = '_blank';
  link.rel = 'noopener';
  const image = document.createElement('img');
  image.setAttribute('src', entry.png_url);
  image.setAttribute('alt', extra.prompt ? extra.prompt : 'generated image');
  image.setAttribute('loading', 'lazy');
  link.append(image);
  const meta = document.createElement('div');
  meta.className = 'meta';
  if (extra.prompt) {
    const prompt = document.createElement('div');
    prompt.className = 'prompt';
    prompt.textContent = extra.prompt;
    meta.append(prompt);
  }
  const facts = document.createElement('div');
  const parts = [];
  if (extra.seed !== undefined) parts.push(`seed ${extra.seed}`);
  if (extra.seconds !== undefined) parts.push(`${Number(extra.seconds).toFixed(1)} s`);
  if (entry.published_at) parts.push(String(entry.published_at).replace('T', ' ').replace('+00:00', 'Z'));
  facts.textContent = parts.join(' / ');
  meta.append(facts);
  const tools = document.createElement('div');
  tools.className = 'tools';
  const provenance = document.createElement('a');
  provenance.href = entry.provenance_url;
  provenance.target = '_blank';
  provenance.rel = 'noopener';
  provenance.textContent = 'provenance';
  const remove = document.createElement('button');
  remove.type = 'button';
  remove.textContent = 'remove';
  remove.onclick = async () => {
    remove.disabled = true;
    try {
      await postJson(REMOVE_ROUTE, { sha256: entry.png_sha256 });
      card.remove();
      studioState.artifacts = studioState.artifacts.filter(item => item.png_sha256 !== entry.png_sha256);
      $('#gallery-empty').hidden = studioState.artifacts.length > 0;
    } catch (error) {
      remove.disabled = false;
      setNote(`remove failed: ${error.message || error}`);
    }
  };
  tools.append(provenance, remove);
  meta.append(tools);
  card.append(link, meta);
  return card;
}

export async function loadGallery() {
  const response = await fetch(ARTIFACTS_ROUTE);
  recordSessionStatus(response.status);
  if (!response.ok) throw new Error(`the artifact index answered HTTP ${response.status}`);
  const payload = await response.json();
  const entries = Array.isArray(payload.artifacts) ? payload.artifacts : [];
  const gallery = $('#image-gallery');
  for (const card of [...gallery.children]) {
    if (typeof card !== 'string' && card.className === 'artifact') card.remove();
  }
  studioState.artifacts = entries;
  $('#gallery-empty').hidden = entries.length > 0;
  for (const entry of entries) gallery.append(renderArtifact(entry));
  return entries;
}

function prependArtifact(result, fields) {
  const entry = {
    png_sha256: result.sha256,
    png_url: result.artifact_url,
    provenance_url: result.provenance_url || '',
    published_at: ''
  };
  studioState.artifacts.unshift(entry);
  $('#gallery-empty').hidden = true;
  const gallery = $('#image-gallery');
  gallery.prepend(renderArtifact(entry, { prompt: fields.prompt, seed: fields.seed, seconds: result.seconds }));
}

// -- the job --------------------------------------------------------------

function readFields() {
  const bounds = studioState.bounds;
  const prompt = String($('#image-prompt').value || '').trim();
  const negative = String($('#image-negative').value || '').trim();
  const steps = Number($('#image-steps').value);
  const seedValue = String($('#image-seed').value || '').trim();
  const seed = seedValue === '' ? randomSeed() : Number(seedValue);
  if (!prompt) throw new Error('the prompt is empty');
  if (!Number.isInteger(steps) || steps < 1 || steps > Number(bounds.max_steps)) {
    throw new Error(`steps must be an integer from 1 to ${bounds.max_steps}`);
  }
  if (!Number.isInteger(seed) || seed < 0 || seed > 4294967295) {
    throw new Error('the seed must be an integer from 0 to 4294967295');
  }
  $('#image-seed').value = String(seed);
  return {
    profile_id: bounds.profile_id,
    prompt,
    negative_prompt: negative,
    seed,
    width: Number(bounds.width),
    height: Number(bounds.height),
    steps
  };
}

async function grantFor(fields, signal) {
  const [promptHash, negativePromptHash] = await Promise.all([
    sha256Hex(fields.prompt), sha256Hex(fields.negative_prompt)
  ]);
  return requestImageGrant({
    context: IMAGE_GRANT_CONTEXT,
    language_profile: studioState.languageProfile,
    image_profile: fields.profile_id,
    prompt_hash: promptHash,
    negative_prompt_hash: negativePromptHash,
    seed: fields.seed,
    aspect: aspectRatio(fields.width, fields.height),
    max_dimension: Math.max(fields.width, fields.height),
    max_steps: fields.steps,
    conversation_generation: 0
  }, signal);
}

async function pollStatus(running) {
  while (running.active) {
    await new Promise(resolve => setTimeout(resolve, STATUS_POLL_MS));
    if (!running.active) return;
    try {
      const observed = await postJson(STATUS_ROUTE, { request_id: probeRequestId() }, running.controller.signal);
      if (typeof observed.job_request_id === 'string' && observed.job_request_id) {
        running.jobRequestId = observed.job_request_id;
      }
      const phase = observed.state || observed.status || 'running';
      const elapsed = ((Date.now() - running.startedAt) / 1000).toFixed(0);
      setState(`${phase}, ${elapsed} s`, 'busy');
    } catch (error) {
      if (error.name === 'AbortError') return;
    }
  }
}

export async function generate(event) {
  if (event && typeof event.preventDefault === 'function') event.preventDefault();
  if (studioState.running || !studioState.bounds) return null;
  setNote('');
  let fields;
  try {
    fields = readFields();
  } catch (error) {
    setNote(error.message || String(error));
    return null;
  }
  const controller = new AbortController();
  const running = { active: true, controller, jobRequestId: '', startedAt: Date.now(), cancelled: false };
  studioState.running = running;
  const generateButton = $('#image-generate');
  const cancelButton = $('#image-cancel');
  generateButton.disabled = true;
  cancelButton.hidden = false;
  const timeout = setTimeout(() => controller.abort(), GENERATION_TIMEOUT_MS);
  try {
    setState('approving', 'busy');
    const authorization = await grantFor(fields, controller.signal);
    setState('generating', 'busy');
    const poller = pollStatus(running);
    let result;
    try {
      result = await postJson(GENERATE_ROUTE, { ...fields, authorization }, controller.signal);
    } finally {
      running.active = false;
      await poller;
    }
    if (typeof result.sha256 !== 'string' || !result.artifact_url) {
      throw new Error('the generation answered no artifact');
    }
    prependArtifact(result, fields);
    setState(`done in ${Number(result.seconds || 0).toFixed(1)} s`, 'done');
    return result;
  } catch (error) {
    const reason = running.cancelled
      ? 'cancelled'
      : error.name === 'AbortError'
        ? `timed out after ${GENERATION_TIMEOUT_MS / 1000} s`
        : (error.message || String(error));
    setState(`failed: ${reason}`, 'failed');
    return null;
  } finally {
    clearTimeout(timeout);
    running.active = false;
    studioState.running = null;
    cancelButton.hidden = true;
    generateButton.disabled = false;
  }
}

export async function cancel() {
  const running = studioState.running;
  if (!running) return;
  running.cancelled = true;
  // The grant is spent at dispatch, so the cancel ends the worker's job and
  // the abort ends this tab's wait; a retry takes a fresh approval.
  if (running.jobRequestId) {
    try {
      await postJson(CANCEL_ROUTE, { request_id: running.jobRequestId });
    } catch {
      // The abort below still ends the wait; the worker reports its own state
      // on the next status read.
    }
  }
  running.controller.abort();
}

// -- the entry ------------------------------------------------------------

export async function initStudio(shell) {
  if (studioState.initialized) return;
  const approvals = shell && shell.approvals;
  const languageProfile = approvals && typeof approvals.profile === 'string' ? approvals.profile : '';
  if (!languageProfile) {
    $('#image-profile').textContent = 'the gateway reports no approval profile, so no grant can be minted';
    $('#image-generate').disabled = true;
    return;
  }
  studioState.initialized = true;
  studioState.languageProfile = languageProfile;
  $('#image-form').onsubmit = generate;
  $('#image-cancel').onclick = cancel;
  $('#image-reseed').onclick = () => { $('#image-seed').value = String(randomSeed()); };
  if (!String($('#image-seed').value || '').trim()) $('#image-seed').value = String(randomSeed());
  try {
    applyBounds(await readBounds(languageProfile));
  } catch (error) {
    $('#image-profile').textContent = error.message || String(error);
    $('#image-generate').disabled = true;
  }
  try {
    await loadGallery();
  } catch (error) {
    setNote(error.message || String(error));
  }
}
