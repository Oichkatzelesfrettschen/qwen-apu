/* The web surface: what the gateway lists, what one human approval admits, and
   what a result is allowed to say to the model.

   Three boundaries live here. A search result's signed Result ID never reaches
   the model: one accepted user turn owns one random handle table, the reply the
   model reads carries `r_<24 hex>` handles instead, and a proposed fetch
   redeems a handle through that table alone, so a transcript re-sent on every
   later request carries no capability. A proposed search opens the approval
   dialog with the exact arguments it would run under, and `/api/tools/grant`
   signs over those fields alone. A result is capped at
   `TOOL_RESULT_CHARACTER_CAP` without cutting an untrusted-content frame's own
   end marker, so the model always reads where attacker-controlled text ends.

   Nothing here touches the document at module evaluation; `initToolToggles()`
   is what sets the two per-turn toggles. */

import {
  $,
  prefixAtWholeCodePoint,
  recordSessionStatus,
  requestGrant
} from './api.js';
import { modelState, modelStateMatches } from './models.js';
import { conversationState } from './conversations.js';

/* The composed listing belongs to one model selection the way the context
   length does: a router roster change replaces both, so the cache carries the
   model id and the selection generation that produced it. The handle registry
   belongs to one accepted user turn, and every boundary that can replace its
   model or transcript revokes it. */
export const toolState = {
  handleRegistry: null,
  matrix: null,
  model: null,
  generation: -1
};

// The gateway executes both tools itself (`src/qwen_apu/tools/web.py`) and
// names them as `GET /api/tools` lists them, so one identifier spans the
// matrix row, the request body, and the executor's own dispatch. The per-turn
// toggle decides whether these reach the request at all, so a turn with the
// toggle off offers the model no web surface to propose.
export const WEB_SEARCH_TOOL_NAME = 'web_search';
export const WEB_FETCH_TOOL_NAME = 'read_url';
export const WEB_TOOL_NAMES = [WEB_SEARCH_TOOL_NAME, WEB_FETCH_TOOL_NAME];
// The matrix rows those names execute are the same two identifiers, since the
// executor dispatches on the row id the matrix states: `web_search` runs one
// approved query and `read_url` redeems one signed Result ID that query
// issued. The alias stays so a reader of either surface finds the name it
// uses, and one edit moves both.
export const WEB_MATRIX_TOOL_IDS = WEB_TOOL_NAMES;
const WEB_RESULT_HANDLE_PATTERN = /^r_[0-9a-f]{24}$/;

export function clearWebResultHandles() {
  toolState.handleRegistry = null;
}

export function randomWebResultHandle() {
  if (typeof crypto === 'undefined' || !crypto ||
      typeof crypto.getRandomValues !== 'function') {
    throw new Error('the browser exposes no cryptographic random source for result handles');
  }
  const words = crypto.getRandomValues(new Uint32Array(3));
  return 'r_' + Array.from(words, word => word.toString(16).padStart(8, '0')).join('');
}

export function beginWebResultHandleTurn(model, generation) {
  clearWebResultHandles();
  const turnNonce = randomWebResultHandle();
  toolState.handleRegistry = {
    turnNonce,
    model,
    generation,
    handles: new Map(),
    originals: new Map()
  };
  return turnNonce;
}

export function matchingWebResultRegistry(turnNonce, model, generation) {
  const registry = toolState.handleRegistry;
  return registry && registry.turnNonce === turnNonce && registry.model === model &&
    registry.generation === generation && conversationState.generation === generation
    ? registry : null;
}

export function handleForWebResult(registry, resultId) {
  const existing = registry.originals.get(resultId);
  if (existing) return existing;
  for (let attempt = 0; attempt < 8; attempt++) {
    const handle = randomWebResultHandle();
    if (registry.handles.has(handle)) continue;
    registry.handles.set(handle, resultId);
    registry.originals.set(resultId, handle);
    return handle;
  }
  throw new Error('the browser could not allocate a unique result handle');
}

export function modelVisibleSearchResult(text, turnNonce, model, generation) {
  /* Replace only Result ID fields in complete blocks emitted by
     render_search_results. Highlight text follows Highlights:, so an
     attacker-authored line that resembles a Result ID never matches this
     prefix and reaches no capability table. */
  const registry = matchingWebResultRegistry(turnNonce, model, generation);
  if (!registry) {
    throw new Error('the result handle turn is stale for this model');
  }
  const resultField = /(^|\n---\n)(Title: [^\n]*\nURL: [^\n]*\nPublished: [^\n]*\nAuthor: [^\n]*\nResult ID: )([^\n]+)(\nTrust: untrusted-web-result\n(?:Sources: [^\n]*\n)?Highlights:)/g;
  const visible = text.replace(resultField, (whole, separator, prefix, resultId, suffix) =>
    separator + prefix + handleForWebResult(registry, resultId) + suffix);
  if (/(^|\n)Result ID: [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\n|$)/.test(visible)) {
    throw new Error('the search result carries a signed identifier outside its result field');
  }
  return visible;
}

export function resolveWebResultHandle(handle, turnNonce, model, generation) {
  const registry = matchingWebResultRegistry(turnNonce, model, generation);
  if (!registry || !WEB_RESULT_HANDLE_PATTERN.test(handle) || !registry.handles.has(handle)) {
    throw new Error('result_id is unknown or expired for this turn and model');
  }
  return registry.handles.get(handle);
}

// The composed list belongs to one model selection the way the context length
// does: a router roster change replaces both, so the cache carries the model
// id and the selection generation that produced it.

export function webToolDefinition(entry) {
  /* Return the request-body tool definition for one matrix row that carries one.

     A row's `definition` is the OpenAI function object whichever executor runs
     the tool declares, and it travels as that executor emits it with one field
     removed: `web_search` advertises an `authorization` property, the gateway
     is the only issuer of a grant, and a model that reads the property can
     only author a token the served path refuses. A row that carries no
     definition composes nothing, which is how a state that admits no call
     reaches the turn as an absent tool rather than as a schema. */
  const definition = entry && entry.definition;
  if (!definition || definition.type !== 'function') return null;
  const fn = definition.function;
  if (!fn || typeof fn.name !== 'string') return null;
  const parameters = fn.parameters && typeof fn.parameters === 'object'
    ? { ...fn.parameters } : { type: 'object', properties: {} };
  if (parameters.properties && typeof parameters.properties === 'object') {
    const { authorization, ...offered } = parameters.properties;
    parameters.properties = offered;
  }
  if (Array.isArray(parameters.required)) {
    parameters.required = parameters.required.filter(name => name !== 'authorization');
  }
  return { type: 'function', function: { ...fn, parameters } };
}

const TOOLS_LISTING_RETRY_DELAY_MS = 300;

/* The five states `GET /api/tools` closes over, and the two that admit a call.
   `available` runs inside the gateway and `available_through_helper` runs in a
   named second process or against a named second checkpoint; the other three
   each state a different party's refusal, which the page renders rather than
   discovering after a proposal. */
export const TOOL_STATES = [
  'available',
  'available_through_helper',
  'temporarily_unavailable',
  'not_installed',
  'policy_refused'
];
const EXECUTING_TOOL_STATES = ['available', 'available_through_helper'];

export const TOOL_STATE_LABELS = {
  available: 'available',
  available_through_helper: 'available through',
  temporarily_unavailable: 'temporarily unavailable',
  not_installed: 'not installed',
  policy_refused: 'refused by policy'
};

export function toolStateExecutes(state) {
  return EXECUTING_TOOL_STATES.includes(state);
}

export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export async function fetchToolMatrix(selectedModel) {
  /* Return the parsed matrix document for one model, or throw.

     `GET /api/tools?model=ID` joins the tool table against
     remote/models.tsv, remote/web-profiles.tsv, remote/image-profiles.tsv, the
     approval settings, and the filesystem, so the answer is a property of the
     selected model rather than of the server. A non-2xx status, a body that is
     not an object, a foreign `schema`, and a `tools` field that is not an
     array all leave the caller unable to read a state, so each raises here and
     `resolveToolMatrix` treats every throw the same way. */
  const response = await fetch(
    `/api/tools?model=${encodeURIComponent(selectedModel)}`);
  recordSessionStatus(response.status);
  if (!response.ok) {
    throw new Error(`GET /api/tools returned HTTP ${response.status}`);
  }
  const document_ = await response.json();
  if (!document_ || typeof document_ !== 'object' || Array.isArray(document_)) {
    throw new Error('GET /api/tools returned a body that is not an object');
  }
  if (document_.schema !== 'qwen.tool-matrix' || !Array.isArray(document_.tools)) {
    throw new Error('GET /api/tools returned no tool matrix');
  }
  return document_;
}

export async function resolveToolMatrix(selectedModel, generation) {
  /* Return the matrix for one model selection, or null where none was read.

     A transient failure -- a dropped connection, a 5xx during restart, a
     response cut short mid-body -- retries once after a short delay rather
     than being read the same as a gateway that serves no matrix at all. Only a
     document this loop actually parsed reaches the cache: caching a failure
     would leave every later turn on this model and generation reading no
     matrix until a reselect or a reload, even once the route recovered. */
  if (toolState.model === selectedModel && toolState.generation === generation) {
    return toolState.matrix;
  }
  let matrix = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      matrix = await fetchToolMatrix(selectedModel);
      break;
    } catch {
      if (attempt === 0) await sleep(TOOLS_LISTING_RETRY_DELAY_MS);
    }
  }
  if (matrix === null) return null;
  if (modelStateMatches(selectedModel, generation)) {
    toolState.matrix = matrix;
    toolState.model = selectedModel;
    toolState.generation = generation;
  }
  return matrix;
}

export function toolMatrixRow(matrix, toolId) {
  /* One row by its identifier, or null where the matrix carries none. */
  if (!matrix || !Array.isArray(matrix.tools)) return null;
  return matrix.tools.find(row => row && row.tool_id === toolId) || null;
}

export function renderToolMatrix(container, matrix) {
  /* Write one row per tool: its title, its state, the helper that runs it,
     and the authority the state comes from.

     Every field is written through `textContent`, because a reason names a
     ledger row and a helper names a checkpoint, both of which are text this
     appliance treats as content. A helper is shown only where the state is
     `available_through_helper`, since that is the state whose whole content is
     that a second party runs the call. */
  container.textContent = '';
  const rows = (matrix && Array.isArray(matrix.tools)) ? matrix.tools : [];
  for (const row of rows) {
    const entry = document.createElement('div');
    entry.className = `tool-row tool-${row.state}`;
    const title = document.createElement('span');
    title.className = 'tool-title';
    title.textContent = row.title;
    entry.append(title);
    const state = document.createElement('span');
    state.className = 'tool-state';
    const label = TOOL_STATE_LABELS[row.state] || row.state;
    state.textContent = row.state === 'available_through_helper' && row.helper
      ? `${label} ${row.helper}`
      : label;
    entry.append(state);
    const reason = document.createElement('span');
    reason.className = 'tool-reason meta';
    reason.textContent = row.reason;
    entry.append(reason);
    container.append(entry);
  }
  return rows.length;
}

export async function refreshToolMatrix(selectedModel, generation) {
  /* Read the matrix for the selected model and render it into the page.

     A read that failed after its one retry leaves the panel stating that
     rather than leaving the previous model's rows on screen, since a stale
     row would report a state for a checkpoint the reader is no longer on. */
  const panel = $('#tool-matrix');
  const body = $('#tool-matrix-body');
  if (!panel || !body) return null;
  const matrix = await resolveToolMatrix(selectedModel, generation);
  if (!modelStateMatches(selectedModel, generation)) return matrix;
  if (!matrix) {
    body.textContent = '';
    $('#tool-matrix-summary').textContent = 'tool support unread';
    panel.hidden = false;
    return null;
  }
  const count = renderToolMatrix(body, matrix);
  const offered = matrix.tools.filter(row => toolStateExecutes(row.state)).length;
  $('#tool-matrix-summary').textContent =
    `tool support: ${offered} of ${count} available for ${selectedModel}`;
  panel.hidden = false;
  return matrix;
}

export async function resolveWebTools(selectedModel, generation) {
  /* Return the web tool definitions this turn may offer the model.

     The matrix is the authority for what the browser may later invoke, and it
     carries a function schema only for a row this origin can execute. An
     assembly that resolved a SearXNG instance mounts `src/qwen_apu/tools/web.py`
     on `POST /api/tools`, so the matrix states both web rows as available and
     carries the schema that executor advertises; one that resolved none states
     them temporarily unavailable and carries no schema. Composing a schema the
     page cannot run would put the refusal after the proposal, which is the
     ordering the matrix exists to reverse, so a turn under that state carries
     no web tool and the panel shows the row's own reason.

     The composition returns on its own the moment a row carries a definition,
     because this filter reads the state and the definition rather than a name
     kept here. */
  const matrix = await resolveToolMatrix(selectedModel, generation);
  if (!matrix) return [];
  return matrix.tools
    .filter(row => WEB_MATRIX_TOOL_IDS.includes(row.tool_id) && toolStateExecutes(row.state))
    .map(webToolDefinition)
    .filter(Boolean);
}

export function forgetWebTools() {
  toolState.matrix = null;
  toolState.model = null;
  toolState.generation = -1;
}


// A tool result enters the context as a message, so its length is prompt the
// next round pays for at this machine's prefill rate. The cap truncates a
// long page rather than refusing it, which keeps the reply readable.
const TOOL_RESULT_CHARACTER_CAP = 8000;


export function truncateToolResult(text) {
  /* Cap a tool result without cutting off an untrusted-content frame's own
     end marker.

     `wrap_untrusted` (remote/web-mcp/server.py) closes a fetched page's text
     with `END UNTRUSTED WEB CONTENT [nonce]` so the model can tell where
     attacker-controlled text ends, and a plain `.slice(0, cap)` can land
     inside the window or drop the footer line outright, handing the model an
     unterminated untrusted block. When the result carries that footer, the
     cap truncates the frame body instead and keeps the footer line, with a
     notice between them naming the cut so the model reads it as a harness
     limit rather than as the page's own content. A result without the
     footer -- a refusal message, a plain fetch error -- is sliced as before. */
  if (text.length <= TOOL_RESULT_CHARACTER_CAP) return text;
  const footerMatch = text.match(/\n(END UNTRUSTED WEB CONTENT \[[^\]\n]*\])\s*$/);
  if (footerMatch) {
    const fetchTruncated = truncateFetchResult(text, footerMatch);
    if (fetchTruncated !== null) return fetchTruncated;
    const footerLine = footerMatch[1];
    const noticeLine = `Truncated by the client at ${TOOL_RESULT_CHARACTER_CAP} characters.`;
    const suffix = `\n${noticeLine}\n${footerLine}`;
    const bodyCap = Math.max(0, TOOL_RESULT_CHARACTER_CAP - suffix.length);
    return text.slice(0, bodyCap) + suffix;
  }
  const searchTruncated = truncateSearchResult(text);
  if (searchTruncated !== null) return searchTruncated;
  return prefixAtWholeCodePoint(text, TOOL_RESULT_CHARACTER_CAP);
}

export function truncateFetchResult(text, footerMatch) {
  /* Recompute a fetched page's navigation lines after the cap trims its
     window, or return null when the frame carries no such lines to rewrite.

     `wrap_untrusted` (remote/web-mcp/server.py) writes `Start Index`,
     `Returned Characters`, `Next Start Index`, and `Possibly Truncated` ahead
     of the window it frames, so a paging model reads where to resume from
     those lines rather than from arithmetic over a body it cannot measure.
     Slicing the whole frame at a raw character offset left those lines
     describing the server's own window instead of the shorter one this cap
     actually kept, so `Next Start Index` told the model to resume past text
     the cap had already dropped. This finds the window between `Possibly
     Truncated: ...` and the footer, trims it to fit, and rewrites the three
     lines -- with `Possibly Truncated` forced to `yes`, since a window this
     client cut is truncated regardless of what the server reported -- to
     describe the window the model actually receives. The `Content SHA-256`
     line names a digest over the server's window, which a client-side cut
     invalidates the same way, so that line is replaced with a notice rather
     than left to claim a match that no longer holds. */
  const headerMatch = text.match(
    /^([\s\S]*?\nStart Index: )(\d+)\nReturned Characters: \d+\nNext Start Index: [^\n]+\nPossibly Truncated: (?:yes|no)\n/
  );
  if (!headerMatch) return null;
  const startIndex = Number(headerMatch[2]);
  const windowStart = headerMatch[0].length;
  const windowEnd = text.length - footerMatch[0].length;
  const window = text.slice(windowStart, windowEnd);
  const footerLine = footerMatch[1];
  const prefix = headerMatch[1].replace(
    /\nContent SHA-256: [0-9a-f]{64}\n/,
    '\nContent SHA-256: not recomputed; the client truncated this window.\n'
  );
  // `wrap_untrusted` (remote/web-mcp/server.py) computes `Start Index` and
  // `Next Start Index` over Python `len`, which counts Unicode code points; a
  // JavaScript `.length` counts UTF-16 code units and reports one extra unit
  // per astral character (an emoji, for instance), and a raw `.slice` can
  // split the surrogate pair such a character is stored as. `codePoints`
  // iterates by code point so both the counts and the cut this function makes
  // agree with the wrapper's own arithmetic for every character, BMP or not.
  const codePoints = str => Array.from(str);
  const buildFrame = keptWindowPoints => {
    const keptWindow = keptWindowPoints.join('');
    return `${prefix}${startIndex}` +
      `\nReturned Characters: ${keptWindowPoints.length}` +
      `\nNext Start Index: ${startIndex + keptWindowPoints.length}` +
      `\nPossibly Truncated: yes\n${keptWindow}\n${footerLine}`;
  };
  const windowPoints = codePoints(window);
  // Reserved against the original window's own digit counts, which are at
  // least as wide as whatever the trimmed window produces, so the assembled
  // frame never exceeds the cap once the actual (shorter) digits are used.
  const overhead = buildFrame(windowPoints).length - window.length;
  const budget = Math.max(0, TOOL_RESULT_CHARACTER_CAP - overhead);
  // A code point spends one UTF-16 unit inside the BMP and two outside it, so
  // a slice count against `budget` (a unit count) keeps points one at a time
  // until the next one would spend more units than remain, rather than
  // assuming every point is one unit wide and overrunning the cap on an
  // astral window.
  let unitsKept = 0;
  let pointsKept = 0;
  for (const point of windowPoints) {
    if (unitsKept + point.length > budget) break;
    unitsKept += point.length;
    pointsKept++;
  }
  return buildFrame(windowPoints.slice(0, pointsKept));
}

export function truncateSearchResult(text) {
  /* Cap a search-result reply at a whole result block, or return null.

     `render_search_results` (remote/web-mcp/server.py) joins each result as
     one block on `\n---\n`, closes the reply with a trailing `\n---`, and
     appends `\nResults Omitted: N` outside every block when its own cap
     dropped results. A plain `.slice(0, cap)` can land inside a block,
     discarding a Result ID a later fetch needs, and leaves no omission count
     for what the slice itself dropped. This keeps only the blocks that fit
     whole under the cap and rewrites the omission line to add whatever this
     cap newly drops to the count the server already reported. */
  const omittedMatch = text.match(/\nResults Omitted: (\d+)$/);
  const withoutOmitted = omittedMatch ? text.slice(0, -omittedMatch[0].length) : text;
  const serverOmitted = omittedMatch ? Number(omittedMatch[1]) : 0;
  if (!withoutOmitted.endsWith('\n---') || !withoutOmitted.includes('\nResult ID: ')) return null;
  const blocks = withoutOmitted.slice(0, -4).split('\n---\n');
  const maxOmitted = serverOmitted + blocks.length;
  const budget = TOOL_RESULT_CHARACTER_CAP - `\nResults Omitted: ${maxOmitted}`.length;
  const kept = [];
  for (const block of blocks) {
    const rendered = [...kept, block].join('\n---\n') + '\n---';
    if (rendered.length > budget) break;
    kept.push(block);
  }
  if (!kept.length) {
    // The first block alone exceeds `budget`: no whole block fits, so the
    // fallback to a raw `.slice(0, cap)` would cut inside the block and drop
    // its Result ID with no omission count. This truncates that one block
    // inside its own closed frame instead, carrying the client notice and the
    // count of blocks this cap additionally drops, rather than returning null
    // and emitting an empty result set.
    const notice = `Truncated by the client at ${TOOL_RESULT_CHARACTER_CAP} characters.`;
    const additionalOmitted = serverOmitted + (blocks.length - 1);
    const omittedLine = additionalOmitted ? `\nResults Omitted: ${additionalOmitted}` : '';
    const suffix = `\n---\n${notice}${omittedLine}`;
    const blockBudget = Math.max(0, TOOL_RESULT_CHARACTER_CAP - suffix.length);
    return prefixAtWholeCodePoint(blocks[0], blockBudget) + suffix;
  }
  const totalOmitted = serverOmitted + (blocks.length - kept.length);
  let rendered = kept.join('\n---\n') + '\n---';
  if (totalOmitted) rendered += `\nResults Omitted: ${totalOmitted}`;
  return rendered;
}
// The wrapper meters fetches per search in its own ledger row and publishes
// that allowance neither in `tools/list` nor in `/props`, so the page carries
// its own per-turn budget. Two fetches read the pages behind one search and
// leave the round budget for the answer.
export const WEB_FETCH_BUDGET_PER_TURN = 2;

// One completion can emit several `web_search` calls in the same
// assistant response, and CONTINUATION_CAP bounds only the round count, not
// the calls inside one round: an unbounded inner loop would open one
// approval dialog per proposed call and, on approval, spend one broker grant
// and one provider search per call, consuming as many searches as fit in the
// model's output before the round budget is even reached. This bounds that
// inner loop to one approval-and-execution per turn, the way the fetch
// budget bounds pages read rather than rounds run.
export const WEB_SEARCH_BUDGET_PER_TURN = 1;

export function proposedSearchFields(argumentText) {
  // A proposal whose arguments fail to parse is refused rather than repaired:
  // a dialog cannot show a human what a malformed object means, and a grant
  // over a guess authorizes something nobody read.
  const parsed = JSON.parse(argumentText);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('the proposed arguments are not an object');
  }
  const domainList = value => Array.isArray(value)
    ? value.filter(entry => typeof entry === 'string') : [];
  return {
    query: typeof parsed.query === 'string' ? parsed.query : '',
    include_domains: domainList(parsed.include_domains),
    exclude_domains: domainList(parsed.exclude_domains),
    published_after: typeof parsed.published_after === 'string' ? parsed.published_after : '',
    published_before: typeof parsed.published_before === 'string' ? parsed.published_before : '',
    max_age_hours: Number.isInteger(parsed.max_age_hours) ? parsed.max_age_hours : null,
    max_results: Number.isInteger(parsed.max_results) ? parsed.max_results : 5
  };
}

export function renderApprovalFields(fields) {
  const list = $('#approval-args');
  list.textContent = '';
  const row = (label, value, live) => {
    const term = document.createElement('dt');
    term.textContent = label;
    const detail = document.createElement('dd');
    detail.textContent = value;
    if (live) detail.className = 'live';
    list.append(term, detail);
  };
  row('query', fields.query || '(empty)');
  const interval = [
    fields.published_after ? `published after ${fields.published_after}` : '',
    fields.published_before ? `published before ${fields.published_before}` : ''
  ].filter(Boolean).join(', ');
  row('publication interval', interval || 'any publication date');
  row('included domains', fields.include_domains.length
    ? fields.include_domains.join(', ') : 'every domain');
  row('excluded domains', fields.exclude_domains.length
    ? fields.exclude_domains.join(', ') : 'none');
  row('max results', String(fields.max_results));
  // max_age_hours of 0 forces a live crawl, which is the one search parameter
  // that spends provider budget on the model's word, so the dialog names that
  // case rather than printing a bare number.
  row('live crawl',
    fields.max_age_hours === 0
      ? 'yes -- this forces a fresh crawl and spends provider budget'
      : fields.max_age_hours === null
        ? 'the provider decides which cached copy to serve'
        : `a cached copy up to ${fields.max_age_hours} hours old is accepted`,
    fields.max_age_hours === 0);
}

export function approveWebSearch(fields, proposalModel) {
  // The dialog resolves to one approval or a refusal. A standing grade is
  // absent by construction: the broker signs a single-use grant, so admitting
  // one search is the widest outcome this control offers.
  return new Promise(resolve => {
    const dialog = $('#web-approval');
    const note = $('#approval-note');
    note.hidden = true;
    note.textContent = '';
    renderApprovalFields(fields);
    const once = $('#approve-once');
    const deny = $('#approve-deny');
    // A denial or dismissal can land while requestGrant(fields) is still
    // in flight, and the fetches it issued are otherwise still able to
    // complete: a late grant would spend the rate bucket and issue a token
    // nobody reads, and its stale `finish` callback would resolve a second
    // time and clear buttons a newer dialog now owns. `settled` makes
    // completion one-shot and `controller` aborts the pending request the
    // instant denial wins the race.
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
        // The model picker stays enabled while this dialog is open, so a
        // change between the round that proposed this call and this click
        // must be caught here too, not only before the dialog opened: signing
        // against the newly selected model's profile would grant a search the
        // proposing model never gets to read a result for.
        if (modelState.requestModel !== proposalModel) {
          finish({
            decision: 'deny',
            reason: `it was proposed by model ${proposalModel}, ` +
                    `the current model is ${modelState.requestModel}`
          });
          return;
        }
        // `LLAMA_ARG_ALIAS` carries the web profile's own profile_id
        // (`remote/build-web-presets.sh`), and the registry row `GET
        // /api/models` answers with names that same id, so
        // `modelState.requestModel`
        // already names the profile the selected router child serves. The
        // broker signs the grant's `profile_id` from this value and
        // `enforce_search_authorization` on the MCP child rejects a grant
        // naming any other profile, so sending the wrong one here is caught
        // at approval time rather than surfacing as an opaque refusal later.
        const authorization =
          await requestGrant({ ...fields, profile_id: modelState.requestModel }, controller.signal);
        finish({ decision: 'once', authorization });
      } catch (error) {
        if (settled) return;
        once.disabled = false;
        note.hidden = false;
        note.textContent = String(error.message || error);
      }
    };
    deny.onclick = () => {
      controller.abort();
      finish({ decision: 'deny' });
    };
    // A dismissal is a refusal. Treating it as an approval would let a stray
    // keystroke sign a grant over arguments nobody accepted.
    dialog.onclose = () => {
      controller.abort();
      finish({ decision: 'deny' });
    };
    dialog.showModal();
  });
}


export function webToolFailure(status, text) {
  /* Return the record a call that produced no evidence carries.

     `state` and `reason` are the two fields the gateway adds to
     `qwen.web-tool-outcome`, so a failure the page itself decides -- a dropped
     connection, an unreadable body, a handle that resolves to nothing -- reads
     in the transcript exactly as an incomplete retrieval the executor
     reported. */
  return {
    schema: 'qwen.web-tool-outcome', version: 1, outcome: 'failure',
    state: 'incomplete', status, reason: text,
    evidence: {kind: 'none', usable: false}, text
  };
}

export async function executeWebTool(toolName, params, model, resultHandleTurn = null,
                              turnGeneration = conversationState.generation) {
  let response;
  try {
    response = await fetch('/api/tools', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, tool: toolName, params, stream: false })
    });
    recordSessionStatus(response.status);
  } catch {
    return webToolFailure('transport_error', 'The tool could not reach the server.');
  }
  /* The gateway answers the execution record itself rather than wrapping it in
     a router proxy envelope, so the body is the document. A retrieval that
     failed arrives at HTTP 200 carrying `state: 'incomplete'` and a reason,
     which is what keeps a failed page from reading as a turn that went quiet;
     a refused call arrives at its own status carrying the same shape. */
  let result;
  try { result = await response.json(); } catch {
    return webToolFailure('malformed_response', 'The tool returned an unreadable response.');
  }
  if (result?.schema !== 'qwen.web-tool-outcome' || result.version !== 1 ||
      !['success', 'failure'].includes(result.outcome) ||
      !['complete', 'incomplete'].includes(result.state) ||
      typeof result.status !== 'string' || typeof result.text !== 'string' ||
      typeof result.evidence?.usable !== 'boolean' ||
      !['none', 'search_snippets', 'fetched_page'].includes(result.evidence.kind)) {
    return webToolFailure('malformed_response', 'The tool returned an invalid execution record.');
  }
  if (!response.ok || result.outcome !== 'success' || result.state !== 'complete') {
    return {
      ...result,
      outcome: 'failure',
      state: 'incomplete',
      reason: typeof result.reason === 'string' ? result.reason : result.text,
      evidence: {kind: 'none', usable: false}
    };
  }
  if (toolName === WEB_SEARCH_TOOL_NAME) {
    try {
      result.text = modelVisibleSearchResult(result.text, resultHandleTurn, model, turnGeneration);
    } catch {
      return webToolFailure('invalid_result_handle', 'The search result could not be admitted.');
    }
  }
  return {...result, text: truncateToolResult(result.text)};
}

export function searchRequestParams(fields, authorization) {
  /* Return the `params` object one approved search runs under.

     The grant is signed over the parsed fields and `enforce_search_authorization`
     compares the presented arguments against the claim field by field, so the
     approved fields travel unchanged. An empty date and an absent
     `max_age_hours` are omitted rather than sent as an empty string and a
     null, since `require_iso_date` and `require_optional_integer` read an
     absent key as the same default the broker signed. */
  const params = {
    query: fields.query,
    max_results: fields.max_results,
    include_domains: fields.include_domains,
    exclude_domains: fields.exclude_domains,
    authorization
  };
  if (fields.published_after) params.published_after = fields.published_after;
  if (fields.published_before) params.published_before = fields.published_before;
  if (fields.max_age_hours !== null) params.max_age_hours = fields.max_age_hours;
  return params;
}

export function proposedFetchParams(argumentText, resultHandleTurn, model, turnGeneration) {
  /* Return the three fetch arguments the wrapper reads, from the proposal.

     The model proposes a short handle printed in a prior search reply. The
     page resolves that handle through the active turn's private table, and
     `fetch_exa` redeems the exact signed Result ID stored there. The whitelist
     keeps a model-authored `authorization` or `runtime` key out of the body. */
  const parsed = JSON.parse(argumentText);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('the proposed arguments are not an object');
  }
  const proposedHandle = typeof parsed.result_id === 'string' ? parsed.result_id : '';
  const params = {
    result_id: resolveWebResultHandle(
      proposedHandle, resultHandleTurn, model, turnGeneration)
  };
  for (const key of ['start_index', 'max_chars']) {
    // `require_integer` (remote/web-mcp/server.py) reads an absent key as its
    // own default, so an absent field is left out here to take that default.
    // A present-but-malformed value -- a float, a negative number, a numeric
    // string -- is silently different from absent: passing it through would
    // fetch a different, potentially much larger window than the model
    // proposed with no error and no approval dialog to catch it, so it fails
    // the proposal instead.
    if (!(key in parsed)) continue;
    if (!Number.isInteger(parsed[key]) || parsed[key] < 0) {
      throw new Error(`${key} must be a non-negative integer`);
    }
    params[key] = parsed[key];
  }
  return params;
}


export function initToolToggles() {
  // The web surface is a per-turn choice rather than a remembered one. The
  // toggle governs whether a network-reaching tool is offered at all, and a
  // setting restored from a previous visit would offer it to a turn the user
  // opened with no such intent. The Image toggle is the same choice for
  // generate_image, and neither is written to a store.
  $('#web-tools').checked = false;
  $('#image-tools').checked = false;
}
