/* One user turn: the request it composes, the stream it renders, the tools it
   dispatches, and the continuation rounds it bounds.

   `history` is the transcript every request re-sends, so what enters it is what
   the model reads again on every later turn. A search result enters with short
   handles in place of its signed Result IDs, a grant and a session secret enter
   nowhere, and a review verdict enters nowhere either. The array is a `const`
   the whole page shares and `length = 0` is what empties it, so no module holds
   a stale binding.

   `CONTINUATION_CAP` bounds the rounds one turn runs and the per-turn budgets
   bound what each round may spend: one approved search, two fetches, one
   generation. A round that meets a spent budget answers its own call with a
   tool message, because an assistant message carrying `tool_calls` is a legal
   request only once every call it names has been answered.

   Every render writes through `textContent`, so a URL a model authors is inert
   text. The artifact card owns the one `href` this page sets, and it sets it
   from bytes `verifiedDigest` already proved. */

import {
  $,
  lanBounds,
  logElement,
  readBrowserStorage,
  recordSessionStatus,
  serverTokenCount,
  writeBrowserStorage
} from './api.js';
import { attachments, composeUserContent, renderAttached } from './attachments.js';
import { modelState } from './models.js';
import { appendModelBadge } from './models.js';
import {
  IMAGE_TOOL_NAME,
  IMAGE_GENERATE_BUDGET_PER_TURN,
  applyImageSchemaBounds,
  approveImageGeneration,
  executeImageGeneration,
  imageRequestParams,
  openImageState,
  proposedImageFields,
  renderImageState,
  resolveImageTools
} from './artifacts.js';
import {
  WEB_FETCH_BUDGET_PER_TURN,
  WEB_FETCH_TOOL_NAME,
  WEB_SEARCH_BUDGET_PER_TURN,
  WEB_SEARCH_TOOL_NAME,
  WEB_TOOL_NAMES,
  approveWebSearch,
  beginWebResultHandleTurn,
  clearWebResultHandles,
  executeWebTool,
  proposedFetchParams,
  proposedSearchFields,
  resolveWebTools,
  searchRequestParams,
  webToolFailure
} from './tools.js';
import {
  conversationState,
  conversationsReady,
  rememberAssistantMessage,
  rememberToolMessage,
  rememberUserMessage,
  saveConversation,
  startNewConversation
} from './conversations.js';

// The transcript every request re-sends. One array, emptied in place.
export const history = [];

/* The turn's own flags. `busy` gates a chat turn and a vision review against
   each other, so the appliance keeps one active workload; `toolCallSequence`
   stays unique across the whole conversation, because a per-round counter
   starting at 0 collides across turns and pairs a result with the earlier call
   sharing its id. */
export const chatState = {
  busy: false,
  toolCallSequence: 0,
  imageSendBusySequence: 0,
  imageSendBusyOwner: 0
};

// One completion can propose several rounds of tools; this bounds the rounds
// one user turn runs.
const CONTINUATION_CAP = 4;

export function turn(who, cls) {
  const d = document.createElement('div');
  d.className = 'turn' + (cls ? ' ' + cls : '');
  const w = document.createElement('div');
  w.className = 'who'; w.textContent = who;
  const b = document.createElement('div');
  b.className = 'body';
  d.append(w, b);
  logElement().append(d);
  logElement().scrollTop = logElement().scrollHeight;
  // `who` travels with the turn because the model badge writes into it: an
  // assistant message names the served id beside the speaker rather than in a
  // second row the reader has to pair up.
  return { root: d, body: b, who: w };
}

export function openRoundInTurn(root) {
  // A continuation round appends its own speaker line and answer body to a turn
  // that already holds an earlier round, so each round keeps its own model
  // badge and its own timings while the reader sees one turn.
  const w = document.createElement('div');
  w.className = 'who';
  w.textContent = 'qwen';
  const b = document.createElement('div');
  b.className = 'body';
  root.append(w, b);
  logElement().scrollTop = logElement().scrollHeight;
  return { root, body: b, who: w };
}

export async function buildRequestBody(messages, webPermission, imagePermission,
                                requireImageTool = false) {
  // The server applies --n-predict only where a request's own max_tokens is
  // absent (server-context.cpp reads task.params.n_predict verbatim
  // otherwise), so an explicit request value is what actually bounds output
  // under a LAN launch; this page's own default of 512 already sits under
  // most configured bounds, and the LAN bound only narrows it further.
  const maxTokens = lanBounds.output != null
    ? Math.min(512, lanBounds.output) : 512;
  const body = { model: modelState.requestModel, stream: true, temperature: 0.7,
                 stream_options: { include_usage: true },
                 max_tokens: maxTokens, messages };
  const reasoningOn = $('#reasoning').checked;
  // Qwen3 emits its <think> block from the chat template, so the switch is a
  // template argument. reasoning_budget 0 ends the block immediately on builds
  // that read the OpenAI-side field instead, and both are ignored by a
  // template that does not offer the option.
  body.chat_template_kwargs = { enable_thinking: reasoningOn };
  if (!reasoningOn) body.reasoning_budget = 0;
  const tools = [];
  // `send` snapshots and resets the Web toggle at the turn boundary. A
  // permission snapshot carries the tool through continuation rounds;
  // the next user turn starts denied until the user selects Web again.
  if (webPermission) {
    tools.push(...await resolveWebTools(modelState.requestModel, modelState.generation));
  }
  // Image generation is a second, independent per-turn permission: the toggle
  // decides only whether generate_image is offered, and it composes into the
  // same tools array the web and demo tools already build.
  if (imagePermission) {
    const { definition } = await resolveImageTools(modelState.requestModel, modelState.generation);
    if (definition) tools.push(definition);
  }
  if (tools.length) {
    body.tools = tools;
    // Selecting Image for an image-only turn is an explicit request to run
    // the sole admitted generator. Requiring one call prevents earlier
    // conversation text from steering the model into describing parameters
    // as prose. A Web+Image turn keeps automatic selection because requiring
    // a tool on every continuation would prevent the final sourced answer.
    if (requireImageTool && imagePermission && !webPermission && tools.length === 1 &&
        tools[0]?.function?.name === IMAGE_TOOL_NAME) {
      body.tool_choice = 'required';
    }
  }
  return body;
}

export async function streamCompletion(messages, view, webPermission, imagePermission,
                                requireImageTool = false) {
  const t0 = performance.now();
  let first = null, streamChunks = 0, completionTokens = null;
  let serverTimings = null, answer = '', reasoning = '', finish = null;
  // Every chat.completion.chunk carries the id of the child that answered
  // (`oaicompat_model`, tools/server/server-task.cpp:481), so the badge and the
  // conversation record name the model that produced the tokens rather than the
  // one the picker holds when the stream ends.
  let servedModel = null;
  const toolCalls = {};
  const resp = await fetch('/api/chat', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(await buildRequestBody(
      messages, webPermission, imagePermission, requireImageTool))
  });
  recordSessionStatus(resp.status);
  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`HTTP ${resp.status}. ${detail.slice(0, 300)}`);
  }
  const reader = resp.body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    const lines = buf.split('\n');
    buf = lines.pop();
    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      if (line === 'data: [DONE]') continue;
      let d; try { d = JSON.parse(line.slice(6)); } catch { continue; }
      if (typeof d.model === 'string' && d.model) servedModel = d.model;
      if (d.usage?.completion_tokens !== undefined) completionTokens = d.usage.completion_tokens;
      if (d.timings) serverTimings = d.timings;
      const ch = d.choices?.[0]; if (!ch) continue;
      if (ch.finish_reason) finish = ch.finish_reason;
      const delta = ch.delta || {};
      for (const tc of delta.tool_calls || []) {
        const k = tc.index ?? 0;
        toolCalls[k] ||= { name: '', args: '' };
        if (tc.function?.name) toolCalls[k].name += tc.function.name;
        if (tc.function?.arguments) toolCalls[k].args += tc.function.arguments;
      }
      if (delta.reasoning_content) {
        if (first === null) first = performance.now();
        streamChunks++; reasoning += delta.reasoning_content; view.thinkBody.textContent = reasoning;
        if (!view.sourceEvidence && !view.thinkShown) { view.turn.root.insertBefore(view.think, view.turn.body); view.thinkShown = true; }
      }
      if (delta.content) {
        if (first === null) first = performance.now();
        streamChunks++; answer += delta.content;
        if (!view.sourceEvidence && !view.deferAnswer) view.turn.body.textContent = answer;
      }
      logElement().scrollTop = logElement().scrollHeight;
    }
  }

  const calls = Object.values(toolCalls);
  if (calls.length) {
    const pre = document.createElement('pre');
    pre.className = 'tool';
    pre.textContent = calls.map(c => `${c.name}(${c.args})`).join('\n');
    view.turn.root.insertBefore(pre, view.meta);
  }

  const total = (performance.now() - t0) / 1000;
  const ttft = first ? (first - t0) / 1000 : null;
  const browserDecodeSeconds = first ? (performance.now() - first) / 1000 : null;
  const rate = serverTimings?.predicted_per_second ??
    (browserDecodeSeconds && completionTokens ? completionTokens / browserDecodeSeconds : null);
  const bits = [];
  if (serverTimings?.prompt_per_second !== undefined) {
    bits.push(`${serverTimings.prompt_per_second.toFixed(1)} tok/s prefill`);
  } else if (ttft !== null) {
    bits.push(`time to first token ${ttft.toFixed(2)}s`);
  }
  if (rate !== null) bits.push(`${rate.toFixed(1)} tok/s decode`);
  if (completionTokens !== null) {
    bits.push(`${completionTokens} generated tokens in ${total.toFixed(1)}s`);
  } else {
    bits.push(`${streamChunks} streamed chunks in ${total.toFixed(1)}s`);
  }
  // A non-stop finish is a budget or a tool hand-off, not a wrong answer, and
  // saying so is the difference between reading a truncation as a model failure
  // and reading it as a harness limit.
  if (finish && finish !== 'stop') bits.push(`ended on ${finish}`);
  if (!answer && reasoning) bits.push('the answer is empty; the model spent the budget reasoning');
  view.meta.textContent = bits.join(' | ');
  // A chunk without the key leaves the picker's own value, so the badge names
  // a model on every completed stream.
  const model = servedModel || modelState.requestModel;
  void appendModelBadge(view.turn.who, model);
  return { answer, reasoning, calls, model };
}

export function openTurnView(sharedRoot) {
  /* Open one round's view, inside an existing turn where the caller names one.

     A turn that proposes a tool runs several completion rounds, and each round
     is one assistant message. They share a turn block, so a generated image
     sits between the round that proposed it and the round that describes it:
     the artifact card appends to this root and the next round's speaker line,
     answer, and meta append after it. */
  const t = sharedRoot ? openRoundInTurn(sharedRoot) : turn('qwen');
  const think = document.createElement('details');
  think.className = 'think';
  const sum = document.createElement('summary');
  sum.textContent = 'reasoning';
  const thinkBody = document.createElement('div');
  thinkBody.className = 'body';
  think.append(sum, thinkBody);
  const meta = document.createElement('div');
  meta.className = 'meta';
  t.root.append(meta);
  return { turn: t, think, thinkBody, thinkShown: false, meta };
}

export function missingSourceNotice() {
  return 'Source retrieval is incomplete. No source-grounded answer was produced. ' +
    'Any successful tool results remain in this conversation. Retry or choose another source. ' +
    'For a separate answer from general model knowledge, turn Web off and ask again.';
}

export function answerCall(callId, toolName, content, turnGeneration) {
  // Every assistant message carrying tool_calls needs one tool message per
  // call before the array is a legal request, so each branch of the round
  // answers its own call. A result whose turnGeneration no longer matches
  // conversationState.generation was proposed against a conversation Clear already
  // replaced, and appending it here would land in the wrong transcript.
  if (turnGeneration !== conversationState.generation) return;
  history.push({ role: 'tool', tool_call_id: callId, name: toolName, content });
  rememberToolMessage(callId, toolName, content);
  void saveConversation();
}

export async function runProposedTools(calls, callIds, view, roundBudgetExhausted, fetchBudget,
                                 searchBudget, turnGeneration, proposalModel,
                                 webPermission, imagePermission, imageBudget, imageCancelToolName, imageBounds,
                                 resultHandleTurn) {
  /* Execute this round's proposed calls and answer each one.

     A proposed `web_search_exa` is shown to a human with the arguments it
     would run under, the broker signs a grant over exactly those fields, and
     the browser posts them to `POST /tools` with the grant inside `params`.
     The grant lives in that one request body: `history` keeps the proposal it
     was signed over, while a search result enters `history` with short handles
     in place of its signed Result IDs. The transcript carries neither token.
     A refusal answers the call with a tool message so the model reads that the
     search did not run. */
  let refused = false;
  let webFailed = false;
  const answerTool = (callId, toolName, content, generation) => {
    if (WEB_TOOL_NAMES.includes(toolName)) {
      const result = typeof content === 'object' && content !== null
        ? content : webToolFailure('page_refused', String(content));
      webFailed ||= result.outcome !== 'success' || !result.evidence.usable;
      if (result.outcome === 'success' && result.evidence.usable &&
          result.evidence.kind === 'fetched_page') (view.sourceEvidence ||= {fetched: false}).fetched = true;
      answerCall(callId, toolName, JSON.stringify(result), generation);
    } else {
      answerCall(callId, toolName, content, generation);
    }
  };
  for (let index = 0; index < calls.length; index++) {
    const toolName = calls[index].name;
    const callId = callIds[index];
    if (!webPermission && WEB_TOOL_NAMES.includes(toolName)) {
      // The permission snapshot governs both advertisement and execution. The
      // visible toggle already names the next turn.
      refused = true;
      answerTool(callId, toolName,
        `The web surface is off for this turn; ${toolName} did not run.`, turnGeneration);
      continue;
    }
    if (roundBudgetExhausted && WEB_TOOL_NAMES.includes(toolName)) {
      // The continuation cap bounds the rounds left to read a result in: the
      // round that just streamed is the last one send() will send again, so a
      // call whose result reaches no request stays unrun rather than spending
      // a grant, a provider budget, and a fetch allowance for a reply nobody
      // reads. The model reads the same refusal shape a denial produces.
      refused = true;
      answerTool(callId, toolName,
        `The round budget is exhausted; ${toolName} did not run.`, turnGeneration);
      continue;
    }
    if (modelState.requestModel !== proposalModel && WEB_TOOL_NAMES.includes(toolName)) {
      // A model switch invalidates every network-reaching proposal before a
      // fetch allowance, search allowance, approval, or provider budget can
      // move. Both web tools use the same proposal-model snapshot.
      refused = true;
      answerTool(callId, toolName,
        `The ${toolName} call did not run: it was proposed by model ${proposalModel}, ` +
        `the current model is ${modelState.requestModel}.`, turnGeneration);
      continue;
    }
    // ==== Image generation (PR D, UI half): dispatch =======================
    if (toolName === IMAGE_TOOL_NAME) {
      if (!imagePermission) {
        refused = true;
        answerTool(callId, toolName,
          `The image surface is off for this turn; ${toolName} did not run.`, turnGeneration);
        continue;
      }
      if (roundBudgetExhausted) {
        refused = true;
        answerTool(callId, toolName,
          `The round budget is exhausted; ${toolName} did not run.`, turnGeneration);
        continue;
      }
      if (modelState.requestModel !== proposalModel) {
        refused = true;
        answerTool(callId, toolName,
          `The ${toolName} call did not run: it was proposed by model ${proposalModel}, ` +
          `the current model is ${modelState.requestModel}.`, turnGeneration);
        continue;
      }
      if (imageBudget.remaining <= 0) {
        refused = true;
        answerTool(callId, toolName,
          `The per-turn budget of ${IMAGE_GENERATE_BUDGET_PER_TURN} image generations is spent; ` +
          'this image did not run.', turnGeneration);
        continue;
      }
      let imageFields;
      try {
        // The schema's own maxima are applied here, above the budget
        // decrement: an out-of-bounds proposal spends no approval and no
        // generation, so the model reads the bound and may propose again
        // inside the CONTINUATION_CAP rounds the turn already allows.
        imageFields = applyImageSchemaBounds(proposedImageFields(calls[index].args), imageBounds);
      } catch (error) {
        refused = true;
        answerTool(callId, toolName, `The image did not run: ${error.message || error}`, turnGeneration);
        continue;
      }
      imageBudget.remaining--;
      const imageOutcome = await approveImageGeneration(imageFields, proposalModel);
      if (imageOutcome.decision === 'failed') {
        // The approval was given and the grant request refused it, so the
        // state line records the failure and the model reads the reason. The
        // turn continues to its next completion rather than holding on a
        // dialog nothing will close.
        refused = true;
        renderImageState(openImageState(view), `Image failed: ${imageOutcome.reason}`, true);
        answerTool(callId, toolName,
          `The image did not run: ${imageOutcome.reason}.`, turnGeneration);
        continue;
      }
      if (imageOutcome.decision === 'once' && modelState.requestModel !== proposalModel) {
        refused = true;
        answerTool(callId, toolName,
          `The image did not run: it was proposed by model ${proposalModel}, ` +
          `the current model is ${modelState.requestModel}.`, turnGeneration);
        continue;
      }
      if (imageOutcome.decision === 'once') {
        const stateEl = openImageState(view);
        const params = imageRequestParams(imageFields, imageOutcome.authorization);
        const execution = await executeImageGeneration(
          stateEl, view.turn.root, imageFields, params,
          { state: { correctionsUsed: 0 }, model: proposalModel,
            cancelToolName: imageCancelToolName, bounds: imageBounds });
        if (!execution.ok) refused = true;
        answerTool(callId, toolName, execution.text, turnGeneration);
      } else {
        refused = true;
        answerTool(callId, toolName, imageOutcome.reason
          ? `The image did not run: ${imageOutcome.reason}.`
          : 'The user refused this image generation. It did not run.', turnGeneration);
      }
      continue;
    }
    // ==== end image generation: dispatch ====================================
    if (toolName === WEB_FETCH_TOOL_NAME) {
      if (fetchBudget.remaining <= 0) {
        refused = true;
        answerTool(callId, toolName,
          `The per-turn budget of ${WEB_FETCH_BUDGET_PER_TURN} fetches is spent; ` +
          'this fetch did not run.', turnGeneration);
        continue;
      }
      let params;
      try {
        params = proposedFetchParams(
          calls[index].args, resultHandleTurn, proposalModel, turnGeneration);
      } catch (error) {
        refused = true;
        answerTool(callId, toolName, `The fetch did not run: ${error.message || error}`, turnGeneration);
        continue;
      }
      if (modelState.requestModel !== proposalModel) {
        // A Result ID is signed by the MCP child of the profile that ran the
        // search, so a fetch posted under a picker value the user moved to
        // mid-stream would route the ID into another child, which refuses
        // the signature. The fetch continues under the proposing model alone
        // and a changed picker is named here rather than surfaced as an
        // opaque signature failure.
        refused = true;
        answerTool(callId, toolName,
          `The fetch did not run: it was proposed by model ${proposalModel}, ` +
          `the current model is ${modelState.requestModel}.`, turnGeneration);
        continue;
      }
      fetchBudget.remaining--;
      answerTool(callId, toolName, await executeWebTool(
        toolName, params, proposalModel, resultHandleTurn, turnGeneration), turnGeneration);
      continue;
    }
    if (toolName !== WEB_SEARCH_TOOL_NAME) {
      // A demo or otherwise advertised call carries no executor here. The
      // page invokes the two web tools it holds an approval path and a budget
      // for, and answers every other call with a tool message rather than
      // posting a name it made no boundary for.
      refused = true;
      answerTool(callId, toolName,
        `The served path executes no tool named ${toolName} in this turn.`, turnGeneration);
      continue;
    }
    if (searchBudget.remaining <= 0) {
      // The cap bounds approval-and-execution rather than proposals, so a
      // call refused here opened no dialog and spent no grant.
      refused = true;
      answerTool(callId, toolName,
        `The per-turn budget of ${WEB_SEARCH_BUDGET_PER_TURN} search approvals is spent; ` +
        'this search did not run.', turnGeneration);
      continue;
    }
    let fields;
    try {
      fields = proposedSearchFields(calls[index].args);
    } catch (error) {
      refused = true;
      answerTool(callId, toolName, `The search did not run: ${error.message || error}`, turnGeneration);
      continue;
    }
    searchBudget.remaining--;
    const outcome = await approveWebSearch(fields, proposalModel);
    if (outcome.decision === 'once' && modelState.requestModel !== proposalModel) {
      // The picker stays enabled while the grant request is awaited, so a
      // change landing between the click and the broker's reply would spend
      // the single-use grant and the provider budget on a search whose
      // continuation the turn then refuses. The grant is left unspent; it
      // expires on the broker's own clock.
      refused = true;
      answerTool(callId, toolName,
        `The search did not run: it was proposed by model ${proposalModel}, ` +
        `the current model is ${modelState.requestModel}.`, turnGeneration);
      continue;
    }
    if (outcome.decision === 'once') {
      answerTool(callId, toolName, await executeWebTool(
        toolName, searchRequestParams(fields, outcome.authorization), proposalModel,
        resultHandleTurn, turnGeneration), turnGeneration);
    } else {
      refused = true;
      answerTool(callId, toolName, outcome.reason
        ? `The search did not run: ${outcome.reason}.`
        : 'The user refused this web search. It did not run.', turnGeneration);
    }
  }
  if (refused && !webFailed) {
    const note = document.createElement('div');
    note.className = 'meta bad';
    note.textContent = 'a proposed call went unrun; the model continues without it';
    view.turn.root.append(note);
  }
  return {webFailed};
}

export async function send() {
  if (chatState.busy) return;
  // conversationState.id stays null until initConversations() settles, and every
  // save() call silently no-ops against a null id, so a send reached during
  // that window would otherwise drop the turn from the store even though it
  // streamed and rendered normally.
  await conversationsReady;
  if (chatState.busy) return;
  if (!modelState.requestModel) {
    $('#model').textContent = 'no routable model is selected';
    return;
  }
  const text = $('#input').value.trim();
  if (!text && !attachments.length) return;

  const { prompt, images: imageAttachments, content } = composeUserContent(text, attachments);
  const turnModel = modelState.requestModel;
  const turnAdmissionGeneration = conversationState.generation;
  const turnModelGeneration = modelState.generation;
  const imageBusyToken = imageAttachments.length ? ++chatState.imageSendBusySequence : 0;
  const releaseImageBusy = () => {
    if (imageBusyToken && chatState.imageSendBusyOwner === imageBusyToken) {
      chatState.imageSendBusyOwner = 0;
      chatState.busy = false;
      $('#send').disabled = false;
    }
  };
  if (imageBusyToken) {
    chatState.imageSendBusyOwner = imageBusyToken;
    chatState.busy = true;
    $('#send').disabled = true;
  }
  if (imageAttachments.length) {
    const capability = await selectedModelAcceptsImages(
      turnModel, turnAdmissionGeneration, turnModelGeneration);
    if (capability.state === 'stale') {
      releaseImageBusy();
      return;
    }
    if (capability.state === 'unsupported' || capability.state === 'unavailable') {
      releaseImageBusy();
      const note = turn('image', '');
      note.body.className = 'body meta bad';
      note.body.textContent = capability.state === 'unsupported'
        ? `Model ${turnModel} does not report vision capability. ` +
          'Select a vision model and retry the image turn.'
        : `Could not verify model ${turnModel} vision capability: ${capability.detail}. ` +
          'The prompt and attachments remain ready to retry.';
      return;
    }
  }
  // A LAN prompt bound is enforced here rather than left to the server: the
  // server refuses an over-large prompt only once its token count meets the
  // slot's own context (server-context.cpp), which would spend a full
  // prefill pass finding that out. The request llama-server actually
  // processes carries every prior turn `history` already holds beside this
  // one, so the count below concatenates all of it -- not the new turn
  // alone, which a short message could always pass while an accumulated
  // conversation had already grown past the bound. The concatenation omits
  // the chat template and any tool-definition tokens the real request also
  // carries, so it undercounts what the server sees; it is a conservative
  // trigger for this page's own refusal rather than an exact figure, and the
  // server's own slot-context refusal remains the final backstop.
  if (lanBounds.prompt != null) {
    const composedText = [...history, { role: 'user', content }]
      .map(message => {
        if (typeof message.content === 'string') return message.content;
        if (!Array.isArray(message.content)) return '';
        return message.content
          .filter(part => part && part.type === 'text' && typeof part.text === 'string')
          .map(part => part.text).join('\n');
      })
      .join('\n');
    let promptTokens = null;
    let tokenizeFailure = null;
    try {
      promptTokens = await serverTokenCount(composedText, modelState.requestModel);
    } catch (error) {
      // A configured bound this page cannot measure is a bound this page
      // cannot honor, so an unavailable tokenizer refuses the turn rather
      // than sending it unbounded; the server's own slot-context refusal is
      // a backstop for an oversized request, not a substitute for admitting
      // one this launch's own ceiling names.
      tokenizeFailure = error;
    }
    if (imageBusyToken && (modelState.requestModel !== turnModel ||
        conversationState.generation !== turnAdmissionGeneration)) {
      releaseImageBusy();
      return;
    }
    if (tokenizeFailure != null) {
      const note = turn('limit', '');
      note.body.className = 'body meta bad';
      note.body.textContent = 'This launch admits at most ' +
        `${lanBounds.prompt} prompt tokens, and this page could not measure ` +
        `this conversation's length (${tokenizeFailure.message}). Retry, or start a new conversation.`;
      releaseImageBusy();
      return;
    }
    if (promptTokens != null && promptTokens > lanBounds.prompt) {
      const note = turn('limit', '');
      note.body.className = 'body meta bad';
      note.body.textContent = `This conversation is at least ${promptTokens} tokens, above the ` +
        `${lanBounds.prompt}-token bound this launch admits. Shorten this message, ` +
        'remove an attachment, or start a new conversation.';
      releaseImageBusy();
      return;
    }
  }
  // One user turn owns each Web permission snapshot. Reset the control at the
  // boundary; the captured value continues to govern every continuation round
  // and tool call produced by the active turn.
  const webPermission = $('#web-tools').checked;
  let resultHandleTurn = null;
  if (webPermission) {
    try {
      resultHandleTurn = beginWebResultHandleTurn(modelState.requestModel, conversationState.generation);
    } catch (error) {
      const note = turn('web', '');
      note.body.className = 'body meta bad';
      note.body.textContent = `The web turn did not start: ${error.message || error}.`;
      releaseImageBusy();
      return;
    }
  } else {
    clearWebResultHandles();
  }
  $('#web-tools').checked = false;
  // Image generation carries the same per-turn permission snapshot as Web:
  // one user turn owns it, and the visible toggle already names the next.
  const imagePermission = $('#image-tools').checked;
  $('#image-tools').checked = false;

  const shown = text + (attachments.length
    ? '\n' + attachments.map(a => `[${a.name}]`).join(' ') : '');
  turn('you', 'me').body.textContent = shown;
  history.push({ role: 'user', content });
  const durableContent = imageAttachments.length
    ? `${prompt}\n\n${imageAttachments.map(attachment =>
        `[image attachment omitted from saved conversation: ${attachment.name}, ${attachment.mime}]`).join('\n')}`
    : content;
  rememberUserMessage(durableContent, shown, imageAttachments);
  // Saved here rather than after the completion, so an HTTP error, a dropped
  // connection, or the page closing during a long generation leaves the
  // prompt in the store it belongs to instead of only in memory.
  void saveConversation();
  // Every later mutation of `history` in this turn checks against this
  // snapshot, so a Clear during an awaited stream, approval, or fetch
  // discards the turn's result instead of writing it into the conversation
  // Clear just replaced.
  const turnGeneration = conversationState.generation;
  $('#input').value = '';
  attachments = [];
  renderAttached();

  chatState.busy = true; $('#send').disabled = true;
  // The continuation cap bounds one user turn. A model that keeps proposing
  // searches meets a fixed number of approval dialogs rather than an unbounded
  // sequence of them, and the fetch budget bounds the pages one turn reads.
  const fetchBudget = { remaining: WEB_FETCH_BUDGET_PER_TURN };
  const searchBudget = { remaining: WEB_SEARCH_BUDGET_PER_TURN };
  const imageBudget = { remaining: IMAGE_GENERATE_BUDGET_PER_TURN };
  // Every round of this turn renders into one turn block, so a tool result's
  // artifact card and the answer the next round writes about it stay together.
  let turnRoot = null;
  const sourceEvidence = webPermission ? {fetched: false} : null;
  try {
    for (let round = 0; round < CONTINUATION_CAP; round++) {
      const view = openTurnView(turnRoot);
      turnRoot = view.turn.root;
      view.sourceEvidence = sourceEvidence;
      view.deferAnswer = imagePermission;
      // buildRequestBody reads `modelState.requestModel` at request time, so this
      // snapshot names the model that proposed whatever tool_calls the
      // stream returns; the approval and the executor both compare the
      // picker's current value against it rather than against a value read
      // fresh at approval time, which the picker may have already moved past.
      const proposalModel = modelState.requestModel;
      let outcome;
      try {
        outcome = await streamCompletion(
          history, view, webPermission, imagePermission,
          round === 0 && imagePermission && !webPermission);
      } catch (err) {
        view.meta.className = 'meta bad';
        view.meta.textContent = String(err.message || err);
        return;
      }
      // The stream awaited network time a Clear can land inside; a stale
      // generation here means the assistant turn belongs to a conversation
      // this page no longer holds, so it stops rather than appending to a
      // fresh one.
      if (turnGeneration !== conversationState.generation) return;
      const sourceMissing = webPermission && !outcome.calls.length && !sourceEvidence.fetched;
      const answer = sourceMissing ? missingSourceNotice()
        : imagePermission && !outcome.calls.length
          ? 'Use the image card for Open, Download, and Review. Model-written links below are unverified.\n\n' + outcome.answer
          : outcome.answer;
      if (webPermission || imagePermission) view.turn.body.textContent = outcome.calls.length ? '' : answer;
      const msg = { role: 'assistant', content: outcome.calls.length && webPermission ? '' : answer };
      let callIds = [];
      if (outcome.calls.length) {
        callIds = outcome.calls.map(() => `call_${chatState.toolCallSequence++}`);
        msg.tool_calls = outcome.calls.map((c, i) => ({
          id: callIds[i], type: 'function',
          function: { name: c.name, arguments: c.args }
        }));
      }
      history.push(msg);
      const savedAssistant = rememberAssistantMessage(msg, outcome.model,
        webPermission ? '' : outcome.reasoning);
      if (webPermission) savedAssistant.tool_diagnostic = {
        answer: outcome.answer, reasoning: outcome.reasoning,
        source_obtained: sourceEvidence.fetched, completion: sourceMissing ? 'incomplete' : 'pending'
      };
      if (!outcome.calls.length) {
        void saveConversation();
        return;
      }
      // The save waits for runProposedTools below rather than committing here,
      // because this message alone carries unresolved tool_calls: a reload
      // between this line and that call would restore an assistant message
      // proposing calls with no matching tool messages, which is not a valid
      // chat-completion transcript to resend.
      // A cache hit: buildRequestBody() already populated this entry inside
      // streamCompletion() when imagePermission was on, so this call issues
      // no second GET /tools.
      const { cancelToolName: imageCancelToolName, bounds: imageBounds } =
        await resolveImageTools(modelState.requestModel, modelState.generation);
      const toolOutcome = await runProposedTools(
        outcome.calls, callIds, view, round === CONTINUATION_CAP - 1, fetchBudget,
        searchBudget, turnGeneration, proposalModel, webPermission,
        imagePermission, imageBudget, imageCancelToolName, imageBounds, resultHandleTurn);
      if (turnGeneration !== conversationState.generation) return;
      if (toolOutcome.webFailed) {
        const notice = missingSourceNotice();
        const noticeView = openTurnView(turnRoot);
        noticeView.turn.body.textContent = notice;
        history.push({role: 'assistant', content: notice});
        rememberAssistantMessage({content: notice}, 'application', '');
        void saveConversation();
        return;
      }
      void saveConversation();
      if (modelState.requestModel !== proposalModel) {
        // The picker stays enabled while a tool request is in flight, so
        // the next round would otherwise carry this model's call and its
        // result to whichever model the picker now names. The turn ends
        // here with the transcript intact; the next send reads the new
        // model with the whole history, as any later turn does.
        const note = document.createElement('div');
        note.className = 'meta bad';
        note.textContent = `the model changed from ${proposalModel} to ${modelState.requestModel} ` +
          'during the tool call; the turn ends without a continuation';
        view.turn.root.append(note);
        return;
      }
    }
  } finally {
    if (imageBusyToken) chatState.imageSendBusyOwner = 0;
    chatState.busy = false; $('#send').disabled = false;
    $('#input').focus();
  }
}

export function initChatControls() {
  // Clear opens a new conversation. The record the panel already holds keeps
  // the transcript this button leaves, so clearing the log discards nothing.
  $('#clear').onclick = () => { startNewConversation(); };
  $('#input').addEventListener('keydown', event => {
    if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); send(); }
  });
  $('#send').onclick = send;
  // Reasoning costs decode tokens at about one per second on this APU, so the
  // choice persists across reloads rather than resetting to on each visit.
  $('#reasoning').checked = readBrowserStorage('localStorage', 'qwen-apu-reasoning') === 'on';
  $('#reasoning').addEventListener('change', () => {
    writeBrowserStorage(
      'localStorage', 'qwen-apu-reasoning', $('#reasoning').checked ? 'on' : 'off');
  });
}
