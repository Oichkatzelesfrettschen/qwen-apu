// One gateway serves the whole roster, so `GET /api/tools?model=ID` answers a
// matrix for every id: the tool-free ids read their refusals from the ledgers
// and the one web profile reads an executing lane. The assertions here are
// what the per-turn Web toggle composes into `body.tools` for each id and what
// the tool panel renders beside it.
//
// Four properties decide it. A row in an executing state that carries a
// function schema yields a tool definition with the gateway-issued
// `authorization` property stripped. A row in any other state yields nothing
// and reaches no alert, so the toggle is inert rather than an error. A row
// that executes and carries no schema yields nothing either, because the
// origin that states the state is the origin that would have to run the call.
// Selecting between two ids re-resolves rather than serving the previous id's
// answer, since the cache is keyed by model and selection generation.

import assert from 'node:assert/strict';
import test from 'node:test';

import { install, jsonResponse, newHarness, toolMatrix, toolRow } from './page.mjs';

const TOOL_FREE_MODEL = 'qwen38-2b-distill';
const WEB_PROFILE = 'web-open';

// The function object the executor declares. `web_search` advertises an
// `authorization` property the gateway alone issues, so a model that read it
// could only author a token the served path refuses.
function definitionFor(name) {
  return {
    type: 'function',
    function: {
      name,
      description: name,
      parameters: {
        type: 'object',
        properties: { query: { type: 'string' }, authorization: { type: 'string' } },
        required: ['query', 'authorization']
      }
    }
  };
}

const WEB_MATRIX = toolMatrix([
  toolRow('web_search', 'available_through_helper',
    { helper: 'searxng', definition: definitionFor('web_search') }),
  toolRow('read_url', 'available_through_helper',
    { helper: 'searxng', definition: definitionFor('read_url') }),
  toolRow('calculator', 'available')
]);

// The state this gateway reports today: the approval and grant routes are
// mounted and no tool executor is, so the web rows name the missing executor
// rather than offering a schema the page cannot run.
const NO_EXECUTOR_MATRIX = toolMatrix([
  toolRow('web_search', 'temporarily_unavailable',
    { helper: 'searxng', reason: 'this origin mounts no tool executor' }),
  toolRow('read_url', 'temporarily_unavailable',
    { helper: 'searxng', reason: 'this origin mounts no tool executor' }),
  toolRow('calculator', 'available')
]);

async function listingHarness() {
  /* One arm, answering every matrix read from a settable responder.

     `resolveWebTools` is called directly rather than through a turn, because
     the claim is what the matrix composes rather than how a turn reaches it.
     The modules are imported under one page query so `toolState` and
     `modelState` are the pair the resolution actually reads. */
  const harness = newHarness();
  const requests = [];
  const alerts = [];
  let nextResponse = null;
  harness.fetch = (url, options = {}) => {
    requests.push({ url, options });
    return nextResponse
      ? Promise.resolve(nextResponse())
      : Promise.reject(new Error('the arm named no response'));
  };
  harness.window.alert = message => alerts.push(message);
  install(harness);
  const suffix = `?page=mixed-${Math.random().toString(16).slice(2)}`;
  const tools = await import(`../../static/js/tools.js${suffix}`);
  const models = await import(`../../static/js/models.js${suffix}`);
  return {
    requests,
    alerts,
    answerWith(responder) { nextResponse = responder; },
    // resolveWebTools writes its cache only where modelStateMatches agrees, so
    // the selected model and the generation are set the way a completed
    // selection leaves them.
    select(modelId, generation) {
      models.modelState.requestModel = modelId;
      models.modelState.generation = generation;
    },
    resolve: (modelId, generation) => tools.resolveWebTools(modelId, generation),
    matrix: (modelId, generation) => tools.resolveToolMatrix(modelId, generation),
    row: (matrix, toolId) => tools.toolMatrixRow(matrix, toolId),
    executes: state => tools.toolStateExecutes(state),
    render: (container, matrix) => tools.renderToolMatrix(container, matrix),
    document: harness.document
  };
}

test('an executing web row composes its tool and strips authorization', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(WEB_MATRIX));
  arm.select(WEB_PROFILE, 1);
  const webTools = await arm.resolve(WEB_PROFILE, 1);
  assert.equal(webTools.length, 2,
    'the web profile composed no tool definitions from its matrix');
  assert.equal(arm.requests.length, 1, 'the web profile matrix took more than one request');
  assert.ok(arm.requests[0].url.startsWith('/api/tools?'),
    'the matrix named a route other than the gateway tool route');
  assert.ok(arm.requests[0].url.includes(`model=${encodeURIComponent(WEB_PROFILE)}`),
    'the matrix did not name the selected model');
  for (const tool of webTools) {
    assert.ok(!('authorization' in tool.function.parameters.properties),
      'a web tool definition offered the model the authorization property');
    assert.ok(!tool.function.parameters.required.includes('authorization'),
      'a web tool definition required the authorization property');
  }
});

test('a row that executes and carries no schema composes nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(toolMatrix([
    toolRow('web_search', 'available_through_helper', { helper: 'searxng' }),
    toolRow('read_url', 'available')
  ])));
  arm.select(WEB_PROFILE, 1);
  const composed = await arm.resolve(WEB_PROFILE, 1);
  assert.equal(composed.length, 0,
    'a row carrying no function schema reached the turn as a tool');
});

test('the unmounted executor leaves the turn with no web tool and a reason', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(NO_EXECUTOR_MATRIX));
  arm.select(WEB_PROFILE, 7);
  const composed = await arm.resolve(WEB_PROFILE, 7);
  assert.equal(composed.length, 0, 'a temporarily unavailable row was offered to the model');
  const matrix = await arm.matrix(WEB_PROFILE, 7);
  const row = arm.row(matrix, 'web_search');
  assert.equal(row.state, 'temporarily_unavailable');
  assert.equal(arm.executes(row.state), false);
  assert.match(row.reason, /no tool executor/);
});

test('a tool-free id spends its one retry and caches nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse({ error: 'feature_disabled' }, 403));
  arm.select(TOOL_FREE_MODEL, 2);
  const toolFree = await arm.resolve(TOOL_FREE_MODEL, 2);
  assert.equal(toolFree.length, 0, 'a tool-free model offered the turn a web tool');
  assert.equal(arm.alerts.length, 0, 'a refused matrix reached the operator as an alert');
  assert.equal(arm.requests.length, 2, 'the refused matrix spent other than its one retry');
  for (const request of arm.requests) {
    assert.ok(request.url.includes(`model=${encodeURIComponent(TOOL_FREE_MODEL)}`),
      'a matrix read named a model other than the selected one');
  }

  arm.requests.length = 0;
  const again = await arm.resolve(TOOL_FREE_MODEL, 2);
  assert.equal(again.length, 0, 'a repeated tool-free read composed a tool');
  assert.equal(arm.requests.length, 2,
    'a refused matrix was cached, so a recovered route would stay unread');
});

test('the cache is keyed by model and generation', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse({ error: 'feature_disabled' }, 403));
  arm.select(TOOL_FREE_MODEL, 2);
  await arm.resolve(TOOL_FREE_MODEL, 2);

  arm.requests.length = 0;
  arm.answerWith(() => jsonResponse(WEB_MATRIX));
  arm.select(WEB_PROFILE, 3);
  const webAgain = await arm.resolve(WEB_PROFILE, 3);
  assert.equal(webAgain.length, 2, 'reselecting the web profile lost its tools');
  assert.equal(arm.requests.length, 1, 'reselecting the web profile did not re-read the matrix');

  arm.requests.length = 0;
  arm.answerWith(null);
  const cached = await arm.resolve(WEB_PROFILE, 3);
  assert.equal(cached.length, 2,
    'a successful matrix was not cached for the turn that follows it');
  assert.equal(arm.requests.length, 0, 'a cached matrix was re-read');
});

test('a body that is not a matrix document composes nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(WEB_MATRIX.tools));
  arm.select(WEB_PROFILE, 4);
  assert.equal((await arm.resolve(WEB_PROFILE, 4)).length, 0,
    'a listing array reached the turn as a tool');

  arm.answerWith(() => jsonResponse({ schema: 'qwen.tool-registry', tools: WEB_MATRIX.tools }));
  arm.select(WEB_PROFILE, 5);
  assert.equal((await arm.resolve(WEB_PROFILE, 5)).length, 0,
    'a foreign schema reached the turn as a tool');
});

test('a foreign tool id composes nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(toolMatrix([
    toolRow('image_generation', 'available_through_helper',
      { helper: 'sdxs-512', definition: definitionFor('image_generate_image') })
  ])));
  arm.select(WEB_PROFILE, 6);
  assert.equal((await arm.resolve(WEB_PROFILE, 6)).length, 0,
    'a row outside the web tool set composed a web tool');
});

test('the panel renders one row per tool, its state, its helper, and its reason', async () => {
  const arm = await listingHarness();
  const container = arm.document.createElement('div');
  const rendered = arm.render(container, toolMatrix([
    toolRow('web_search', 'available_through_helper',
      { title: 'Web search', helper: 'searxng', reason: 'one approval mints one grant' }),
    toolRow('image_generation', 'policy_refused',
      { title: 'Image generation', reason: 'execution_policy refused' }),
    toolRow('calculator', 'available', { title: 'Calculator', reason: 'a closed grammar' })
  ]));
  assert.equal(rendered, 3, 'the panel rendered other than one row per tool');
  const rows = container.children;
  assert.equal(rows.length, 3);
  assert.ok(rows[0].className.includes('tool-available_through_helper'),
    'the state is absent from the row class, so no rule can color it');
  const [title, state, reason] = rows[0].children;
  assert.equal(title.textContent, 'Web search');
  assert.equal(state.textContent, 'available through searxng',
    'the helper is absent from the rendered state');
  assert.equal(reason.textContent, 'one approval mints one grant');
  assert.equal(rows[1].children[1].textContent, 'refused by policy',
    'a refused row rendered no refusal');
  assert.equal(rows[2].children[1].textContent, 'available',
    'an available row named a helper it has none of');
});

test('the panel replaces the previous selection rather than appending to it', async () => {
  const arm = await listingHarness();
  const container = arm.document.createElement('div');
  arm.render(container, toolMatrix([toolRow('calculator', 'available')]));
  arm.render(container, toolMatrix([
    toolRow('web_search', 'policy_refused'),
    toolRow('calculator', 'available')
  ]));
  assert.equal(container.children.length, 2,
    'a second render left the previous model rows on the panel');
});
