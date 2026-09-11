/* The routable model set, the picker that selects one, and the registry the
   badge and the support matrix decorate it with.

   `GET /api/models` is the one authority here. `src/qwen_apu/web/chat.py`
   answers it from remote/models.tsv with the id, the role, the tier, the
   interactive depth, and the projector pairing, so the picker, the context
   display, and the vision admission all read one ledger rather than the
   upstream's own roster beside a second properties route. The read is memoized
   per boot: a badge rendered by a restored transcript reads the answer boot
   already holds instead of issuing a request per assistant message.

   Every export here is a function or a state object. Nothing reads the document
   at module evaluation, so `initModelPicker()` is what binds the picker and
   `boot()` is what reaches the network. */

import {
  $,
  applySessionModeToUi,
  readBrowserStorage,
  recordSessionStatus,
  serverTokenCount,
  session,
  writeBrowserStorage
} from './api.js';
import { attachments, renderAttached } from './attachments.js';
import { clearWebResultHandles, forgetWebTools } from './tools.js';
import { forgetImageTools } from './artifacts.js';

/* The selection this page routes under, and the generation that dates it. A
   new selection aborts the browser request the previous one left in flight and
   makes any result from the prior generation stale; backend cancellation
   remains outside the browser's ownership proof. */
export const modelState = {
  requestModel: null,
  generation: 0,
  nctx: null,
  nctxModel: null,
  propertiesRequest: null,
  roster: null,
  rosterRead: null,
  registryRead: null
};

export async function fetchModelRegistry(signal) {
  /* The rows `GET /api/models` answers with, or a throw naming the refusal.

     A 401 states that this browser holds no session, which `recordSessionStatus`
     records and the pairing controls read; every other non-2xx is a fault the
     caller reports where it stands. */
  const response = await fetch('/api/models', signal ? { signal } : {});
  recordSessionStatus(response.status);
  if (!response.ok) {
    throw new Error(`/api/models returned HTTP ${response.status}`);
  }
  const payload = await response.json();
  const rows = payload && Array.isArray(payload.models) ? payload.models : [];
  return rows.filter(row => row && typeof row.id === 'string' && row.id.length > 0);
}

export function modelRegistryOnce() {
  // One read per boot serves the picker, the roster decoration, and the first
  // context display. `boot()` clears it so a re-boot after a pairing reads the
  // registry again under the session that pairing minted.
  if (!modelState.registryRead) modelState.registryRead = fetchModelRegistry();
  return modelState.registryRead;
}

export function registryProperties(row) {
  /* The two facts the page asks a model for, read off its registry row.

     `context_default` is the depth remote/models.tsv admits for the row, which
     is what the launch serves it at, and `projector` states `required` for a
     checkpoint published with a projector -- the pairing
     remote/select-projector.sh resolves and the one fact that decides whether
     an image attachment can reach the model at all. */
  return {
    n_ctx: Number.isFinite(row.context_default) ? row.context_default : null,
    modalities: { vision: row.projector === 'required' }
  };
}

export async function registryRowFor(modelId, signal) {
  const rows = await fetchModelRegistry(signal);
  return rows.find(row => row.id === modelId) ?? null;
}

export function modelStateMatches(selectedModel, generation) {
  return modelState.requestModel === selectedModel && modelState.generation === generation;
}

export function abortModelPropertiesRequest() {
  if (modelState.propertiesRequest) modelState.propertiesRequest.controller.abort();
  modelState.propertiesRequest = null;
}

export function modelPropertiesForSelection(selectedModel, generation) {
  if (!modelStateMatches(selectedModel, generation)) {
    return Promise.resolve({ state: 'stale' });
  }
  if (modelState.propertiesRequest && modelState.propertiesRequest.model === selectedModel &&
      modelState.propertiesRequest.generation === generation) {
    return modelState.propertiesRequest.promise;
  }
  const controller = new AbortController();
  const request = { model: selectedModel, generation, controller, promise: null };
  const unavailable = detail => {
    if (modelState.propertiesRequest === request) modelState.propertiesRequest = null;
    return { state: 'unavailable', detail };
  };
  modelState.propertiesRequest = request;
  request.promise = (async () => {
    let response;
    try {
      response = await fetch('/api/models', { signal: controller.signal });
      recordSessionStatus(response.status);
    } catch (error) {
      if (controller.signal.aborted || !modelStateMatches(selectedModel, generation)) {
        return { state: 'stale' };
      }
      return unavailable(`model properties request failed: ${error.message || error}`);
    }
    if (!modelStateMatches(selectedModel, generation)) return { state: 'stale' };
    if (!response.ok) {
      return unavailable(`model properties returned HTTP ${response.status}`);
    }
    let payload;
    try {
      payload = await response.json();
    } catch (error) {
      if (!modelStateMatches(selectedModel, generation)) return { state: 'stale' };
      return unavailable(`model properties returned invalid JSON: ${error.message || error}`);
    }
    if (!modelStateMatches(selectedModel, generation)) return { state: 'stale' };
    const rows = payload && Array.isArray(payload.models) ? payload.models : null;
    if (!rows) {
      return unavailable('model properties returned no registry rows');
    }
    const row = rows.find(entry => entry && entry.id === selectedModel);
    if (!row) {
      return unavailable(`the registry carries no row for ${selectedModel}`);
    }
    return { state: 'available', props: registryProperties(row) };
  })();
  return request.promise;
}

export async function refreshModelContext(selectedModel, generation) {
  const result = await modelPropertiesForSelection(selectedModel, generation);
  if (!modelStateMatches(selectedModel, generation)) return;
  if (result.state === 'available') {
    const reportedContext =
      result.props.default_generation_settings?.n_ctx ?? result.props.n_ctx ?? null;
    if (Number.isFinite(reportedContext) && reportedContext > 0) {
      modelState.nctx = reportedContext;
      modelState.nctxModel = selectedModel;
    }
  }
  if (!modelStateMatches(selectedModel, generation)) return;
  $('#ctx').textContent = modelState.nctxModel === selectedModel
    ? modelState.nctx.toLocaleString() + ' token context'
    : 'context unavailable for selected model';
  renderAttached();
}

async function refreshAttachmentTokens(selectedModel, generation) {
  const retainedAttachments = [...attachments];
  await Promise.all(retainedAttachments.map(async attachment => {
    if (attachment.kind === 'image') {
      attachment.tokenModel = selectedModel;
      return;
    }
    let tokens = null;
    try { tokens = await serverTokenCount(attachment.text, selectedModel); }
    catch { /* an explicit unavailable count replaces the prior model's count */ }
    if (!modelStateMatches(selectedModel, generation)) return;
    if (!attachments.includes(attachment)) return;
    attachment.tokens = tokens;
    attachment.tokenModel = selectedModel;
  }));
  if (modelStateMatches(selectedModel, generation)) renderAttached();
}

// ==== feature roster ========================================================
/* remote/build-feature-roster.sh emits webui/roster.json from remote/models.tsv
   and remote/feature-claims.tsv into the directory llama-server serves this
   page from, so the tier badge and the support matrix read the same ledgers
   the launch path reads rather than a second copy written here.

   GET /api/models stays the request-model authority and, under the one-origin
   gateway, is the roster as well: the route answers from remote/models.tsv and
   carries the tier and the projector pairing this decoration reads. A feature
   claim is a separate ledger no gateway route serves, so `features` is empty
   here and the support matrix stays closed until one does. A read that refuses
   leaves both surfaces off and the picker routing. */

const ROSTER_STATUS_ORDER = ['production', 'candidate', 'experimental', 'unstable',
  'unsupported', 'unclaimed'];

export async function loadFeatureRoster() {
  /* Compose the roster out of the registry rows the gateway serves.

     A tag states what the row itself claims: its tier, and `vision` where the
     registry pairs the checkpoint with a projector. The generator's own
     `experimental` tag rests on a feature claim, which no gateway route
     carries, so it appears where one does rather than being asserted here. */
  try {
    const rows = await modelRegistryOnce();
    return {
      schema: 'qwen-feature-roster/1',
      features: [],
      models: rows.map(row => ({
        id: row.id,
        role: typeof row.role === 'string' ? row.role : '',
        tier: typeof row.tier === 'string' ? row.tier : '',
        tags: [
          typeof row.tier === 'string' ? row.tier : '',
          row.projector === 'required' ? 'vision' : ''
        ].filter(Boolean),
        features: []
      })),
      image_profiles: []
    };
  } catch {
    return null;
  }
}

export function rosterModelRow(modelId) {
  if (!modelState.roster) return null;
  return modelState.roster.models.find(row => row && row.id === modelId) ?? null;
}

// The roster is composed once, on the first badge a transcript renders, and
// the promise rather than its result is memoized: every later badge reads that
// one answer instead of issuing a request per assistant message. A turn that
// generates nothing reads nothing.

export function featureRosterOnce() {
  if (!modelState.rosterRead) {
    modelState.rosterRead = loadFeatureRoster().then(roster => {
      modelState.roster = roster;
      return roster;
    });
  }
  return modelState.rosterRead;
}

export async function appendModelBadge(whoElement, servedModel) {
  /* Name the model that answered one assistant message, with its registry tier
     where the roster carries the row.

     The served id comes from the completion's own `model` key rather than from
     the picker, so a badge states which child answered rather than which one
     the picker names now. A roster the launch omits leaves the id alone. */
  if (!whoElement || !servedModel) return;
  const name = document.createElement('span');
  name.className = 'served-model';
  name.textContent = ` ${servedModel}`;
  whoElement.append(name);
  const roster = await featureRosterOnce();
  if (!roster) return;
  const row = rosterModelRow(servedModel);
  const tier = row && typeof row.tier === 'string' ? row.tier : '';
  if (!tier) return;
  const badge = document.createElement('span');
  badge.className = `tier-badge ${tier}`;
  badge.textContent = tier;
  whoElement.append(badge);
}

/* The tags the generator computed: the registry tier, `vision` where a vision
   claim rests on a run, and `experimental` where some claim still names the run
   that would move it. */
export function rosterTags(modelId) {
  const row = rosterModelRow(modelId);
  if (!row || !Array.isArray(row.tags)) return [];
  return row.tags.filter(tag => typeof tag === 'string' && tag.length > 0);
}

export function rosterOptionLabel(baseLabel, modelId) {
  const tags = rosterTags(modelId);
  return tags.length ? `${baseLabel} [${tags.join(' ')}]` : baseLabel;
}

export function renderTierBadge(modelId) {
  const badge = $('#model-tier');
  const row = rosterModelRow(modelId);
  const tier = row && typeof row.tier === 'string' ? row.tier : '';
  badge.className = `tier-badge ${tier}`;
  badge.textContent = tier;
  badge.hidden = !tier;
}

/* One row per served id, one column per model-scope feature the roster
   declares. A feature the roster carries for another scope -- a draft pair, a
   web profile, an image profile -- names a subject that is no routable model
   id, so it stays out of a matrix keyed by one. */
export function renderSupportMatrix(modelIds) {
  const container = $('#roster-matrix-body');
  const panel = $('#roster-matrix');
  container.textContent = '';
  const modelFeatures = modelState.roster
    ? modelState.roster.features
      .filter(entry => entry && entry.scope === 'model' &&
        typeof entry.feature === 'string')
      .map(entry => entry.feature)
    : [];
  const rows = modelIds.filter(modelId => rosterModelRow(modelId));
  if (!rows.length || !modelFeatures.length) {
    panel.hidden = true;
    return;
  }

  const table = document.createElement('table');
  const head = document.createElement('tr');
  const corner = document.createElement('th');
  corner.textContent = 'model';
  head.append(corner);
  for (const feature of modelFeatures) {
    const heading = document.createElement('th');
    heading.textContent = feature;
    head.append(heading);
  }
  table.append(head);

  for (const modelId of rows) {
    const row = rosterModelRow(modelId);
    const claims = Array.isArray(row.features) ? row.features : [];
    const line = document.createElement('tr');
    const name = document.createElement('th');
    name.textContent = `${modelId} (${row.tier ?? 'unknown'})`;
    line.append(name);
    for (const feature of modelFeatures) {
      const claim = claims.find(entry => entry && entry.feature === feature);
      const status = claim && ROSTER_STATUS_ORDER.includes(claim.status)
        ? claim.status : 'unclaimed';
      const cell = document.createElement('td');
      cell.className = status;
      cell.append(status);
      if (claim && typeof claim.evidence === 'string' && claim.evidence !== '-') {
        const evidence = document.createElement('span');
        evidence.className = 'evidence';
        evidence.textContent = claim.evidence;
        cell.append(evidence);
      }
      if (claim && typeof claim.note === 'string' && claim.note !== '-') {
        cell.title = claim.note;
      }
      line.append(cell);
    }
    table.append(line);
  }
  container.append(table);
  $('#roster-summary').textContent =
    `feature support for ${rows.length} of ${modelIds.length} routable model${modelIds.length === 1 ? '' : 's'}`;
  panel.hidden = false;
}
// ==== end feature roster ====================================================

export function selectRequestModel(selectedModel, persist = true) {
  abortModelPropertiesRequest();
  const generation = ++modelState.generation;
  clearWebResultHandles();
  modelState.requestModel = selectedModel;
  renderTierBadge(selectedModel);
  modelState.nctx = null;
  modelState.nctxModel = null;
  forgetWebTools();
  forgetImageTools();
  attachments.forEach(attachment => {
    attachment.tokens = null;
    attachment.tokenModel = null;
  });
  if (persist) {
    writeBrowserStorage('localStorage', 'qwen-apu-model-id', selectedModel);
  } else {
    writeBrowserStorage('localStorage', 'qwen-apu-model-id', null);
  }
  $('#ctx').textContent = 'context pending for selected model';
  renderAttached();
  void refreshModelContext(selectedModel, generation);
  void refreshAttachmentTokens(selectedModel, generation);
}
export async function probeToolOffering(modelId) {
  /* Return true where `GET /tools` answers 200 for this model, false where it
     answers 403, and null for any other status or a transport failure.

     A review-only section carries no MCP configuration, so its child answers
     `403 feature_disabled` the way `evidence/web-admission-router-tools.md`
     records for an ordinary model with no armed lane; a section with tools
     armed answers 200. The probe needs no new server surface -- it is the
     same request `resolveWebTools` makes once a model is already selected --
     so `boot()` reads it per roster row to pick a default that can act on the
     per-turn Web or image toggle rather than one that can only sit idle
     behind it. */
  try {
    const response = await fetch(`/api/tools?model=${encodeURIComponent(modelId)}`);
    recordSessionStatus(response.status);
    if (response.status === 200) {
      const listing = await response.json();
      if (!Array.isArray(listing)) return null;
      return listing.some(row =>
        row && typeof row.tool === 'string' && row.tool.length > 0 &&
        row.definition && row.definition.function &&
        typeof row.definition.function.name === 'string' &&
        row.definition.function.name === row.tool);
    }
    if (response.status === 403) return false;
    return null;
  } catch {
    return null;
  }
}

export async function boot() {
  // The router creates no qwen-apu compatibility alias. Its roster is the
  // authority for request ids, so the fallback page selects only a model that
  // the listener reports instead of assuming the single-model alias exists.
  abortModelPropertiesRequest();
  const generation = ++modelState.generation;
  const modelPicker = $('#model-picker');
  modelState.requestModel = null;
  modelState.nctx = null;
  modelState.nctxModel = null;
  forgetWebTools();
  forgetImageTools();
  attachments.forEach(attachment => {
    attachment.tokens = null;
    attachment.tokenModel = null;
  });
  modelPicker.hidden = true;
  $('#model-tier').hidden = true;
  $('#roster-matrix').hidden = true;
  $('#ctx').textContent = 'context pending';
  renderAttached();

  // A re-boot follows a pairing, so the memoized registry read is dropped
  // here: the retained promise carries the 401 that sent the reader to the
  // pairing field and would answer the request the new session is for.
  modelState.registryRead = null;
  modelState.rosterRead = null;
  try {
    // One route answers the picker and the roster, so the roster decoration
    // costs no second request. featureRosterOnce() rather than a direct
    // loadFeatureRoster() call keeps this the same read a message badge
    // awaits, and both resolve from the memoized registry promise.
    const featureRosterRequest = featureRosterOnce();
    const rows = await modelRegistryOnce().catch(error => error);
    if (generation !== modelState.generation) return;
    applySessionModeToUi();
    if (session.paired === false) {
      $('#model').textContent =
        'this gateway wants one pairing: enter the code `qwen-apu status` prints';
      return;
    }
    if (rows instanceof Error) {
      $('#model').textContent = `cannot load model roster: ${rows.message}`;
      return;
    }
    const modelIds = [...new Set(rows
      .map(model => model?.id)
      .filter(modelId => typeof modelId === 'string' && modelId.length > 0))];
    if (!modelIds.length) {
      $('#model').textContent = 'server reports no routable model';
      return;
    }

    // A row that offers no tool -- a review-only vision section, in the
    // paired image preset -- answers a chat turn with no network-reaching
    // surface behind the per-turn Web or image toggle, so the roster's sort
    // order alone (`/v1/models` returns it sorted) cannot set the default:
    // `evidence/web-admission-router-tools.md` records a router serving that
    // route by model section, and a review row's section carries no MCP
    // configuration. `toolOffering` probes every row once so both the default
    // and each option's own label read the same evidence.
    modelState.roster = await featureRosterRequest;
    if (generation !== modelState.generation) return;

    const toolOffering = {};
    if (modelIds.length > 1) {
      for (const modelId of modelIds) {
        toolOffering[modelId] = await probeToolOffering(modelId);
      }
      if (generation !== modelState.generation) return;
    }
    const storedModel = readBrowserStorage('localStorage', 'qwen-apu-model-id');
    // A probe answers `false` for a section whose child carries no MCP
    // configuration and `null` where the listing states nothing either way, so
    // a row is excluded on proven absence alone and an unproven row still
    // routes and still persists.
    const storedModelUsable = modelIds.includes(storedModel) &&
      (modelIds.length === 1 || toolOffering[storedModel] !== false);
    const selectedModel = storedModelUsable
      ? storedModel
      : (modelIds.find(modelId => toolOffering[modelId] !== false) ?? modelIds[0]);
    const selectionProven = modelIds.length === 1 || toolOffering[selectedModel] !== false;
    modelPicker.textContent = '';
    for (const modelId of modelIds) {
      const option = document.createElement('option');
      option.value = modelId;
      const routingLabel =
        toolOffering[modelId] === false ? `${modelId} (review)` : modelId;
      option.textContent = rosterOptionLabel(routingLabel, modelId);
      option.dataset.toolOffering = String(toolOffering[modelId]);
      modelPicker.append(option);
    }
    modelPicker.value = selectedModel;
    modelPicker.hidden = false;
    renderSupportMatrix(modelIds);
    $('#model').textContent = `${modelIds.length} model${modelIds.length === 1 ? '' : 's'} available`;

    selectRequestModel(selectedModel, selectionProven);
  } catch (error) {
    if (generation !== modelState.generation) return;
    modelState.requestModel = null;
    modelPicker.hidden = true;
    $('#model-tier').hidden = true;
    $('#roster-matrix').hidden = true;
    $('#model').textContent = `cannot load model roster: ${error.message || error}`;
  }
}

export function initModelPicker() {
  $('#model-picker').addEventListener('change', event => {
    selectRequestModel(event.target.value);
  });
}
