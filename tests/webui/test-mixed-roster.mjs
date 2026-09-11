// One gateway serves the whole roster, so `GET /api/tools` answers tool-free
// registry ids beside the one web profile that carries an MCP configuration. A
// tool-free child answers `403 feature_disabled`
// (evidence/web-admission-router-tools.md) where the web child answers a JSON
// array, and the assertion here is what the per-turn Web toggle composes into
// `body.tools` for each id.
//
// Three properties decide it. A tool-carrying id yields the two web tool
// definitions. A tool-free id yields an empty list and reaches no alert, so the
// toggle is inert rather than an error. Selecting between the two re-resolves
// rather than serving the previous id's answer, since the cache is keyed by
// model and selection generation.

import assert from 'node:assert/strict';
import test from 'node:test';

import { install, jsonResponse, newHarness } from './page.mjs';

const TOOL_FREE_MODEL = 'qwen38-2b-distill';
const WEB_PROFILE = 'web-open';

// llama-server renders each tool as `{tool, definition}` where `definition` is
// the OpenAI function object it builds from the MCP input schema
// (server-tools.cpp:75-85 and 1823-1834), and `search_exa` advertises an
// `authorization` property the gateway alone issues.
function listedTool(name) {
  return {
    tool: name,
    definition: {
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
    }
  };
}

const WEB_LISTING = [listedTool('web_search_exa'), listedTool('web_fetch_exa')];

async function listingHarness() {
  /* One arm, answering every listing from a settable responder.

     `resolveWebTools` is called directly rather than through a turn, because
     the claim is what the listing composes rather than how a turn reaches it.
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
    resolve: (modelId, generation) => tools.resolveWebTools(modelId, generation)
  };
}

test('a web profile listing composes both tools and strips authorization', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse(WEB_LISTING));
  arm.select(WEB_PROFILE, 1);
  const webTools = await arm.resolve(WEB_PROFILE, 1);
  assert.equal(webTools.length, 2,
    'the web profile composed no tool definitions from its listing');
  assert.equal(arm.requests.length, 1, 'the web profile listing took more than one request');
  assert.ok(arm.requests[0].url.startsWith('/api/tools?'),
    'the listing named a route other than the gateway tool route');
  assert.ok(arm.requests[0].url.includes(`model=${encodeURIComponent(WEB_PROFILE)}`),
    'the listing did not name the selected model');
  assert.ok(arm.requests[0].url.includes('autoload=true'),
    'the listing withheld autoload, so discovery depended on the router default');
  for (const tool of webTools) {
    assert.ok(!('authorization' in tool.function.parameters.properties),
      'a web tool definition offered the model the authorization property');
    assert.ok(!tool.function.parameters.required.includes('authorization'),
      'a web tool definition required the authorization property');
  }
});

test('a tool-free id spends its one retry and caches nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse({ error: 'feature_disabled' }, 403));
  arm.select(TOOL_FREE_MODEL, 2);
  const toolFree = await arm.resolve(TOOL_FREE_MODEL, 2);
  assert.equal(toolFree.length, 0, 'a tool-free model offered the turn a web tool');
  assert.equal(arm.alerts.length, 0, 'a tool-free listing reached the operator as an alert');
  assert.equal(arm.requests.length, 2, 'the tool-free listing spent other than its one retry');
  for (const request of arm.requests) {
    assert.ok(request.url.includes(`model=${encodeURIComponent(TOOL_FREE_MODEL)}`),
      'a listing named a model other than the selected one');
  }

  arm.requests.length = 0;
  const again = await arm.resolve(TOOL_FREE_MODEL, 2);
  assert.equal(again.length, 0, 'a repeated tool-free listing composed a tool');
  assert.equal(arm.requests.length, 2,
    'a refused listing was cached, so a recovered endpoint would stay unread');
});

test('the cache is keyed by model and generation', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse({ error: 'feature_disabled' }, 403));
  arm.select(TOOL_FREE_MODEL, 2);
  await arm.resolve(TOOL_FREE_MODEL, 2);

  arm.requests.length = 0;
  arm.answerWith(() => jsonResponse(WEB_LISTING));
  arm.select(WEB_PROFILE, 3);
  const webAgain = await arm.resolve(WEB_PROFILE, 3);
  assert.equal(webAgain.length, 2, 'reselecting the web profile lost its tools');
  assert.equal(arm.requests.length, 1, 'reselecting the web profile did not re-read the listing');

  arm.requests.length = 0;
  arm.answerWith(null);
  const cached = await arm.resolve(WEB_PROFILE, 3);
  assert.equal(cached.length, 2,
    'a successful listing was not cached for the turn that follows it');
  assert.equal(arm.requests.length, 0, 'a cached listing was re-read');
});

test('a body that is not an array and a foreign tool both compose nothing', async () => {
  const arm = await listingHarness();
  arm.answerWith(() => jsonResponse({ tools: WEB_LISTING }));
  arm.select(WEB_PROFILE, 4);
  const malformed = await arm.resolve(WEB_PROFILE, 4);
  assert.equal(malformed.length, 0,
    'a listing body that is not an array reached the turn as a tool');

  arm.answerWith(() => jsonResponse([listedTool('image_generate_image')]));
  arm.select(WEB_PROFILE, 5);
  const foreign = await arm.resolve(WEB_PROFILE, 5);
  assert.equal(foreign.length, 0, 'a listing outside the web tool set composed a web tool');
});
