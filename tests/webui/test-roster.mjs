// The picker decorates the ids `GET /api/models` returned with the tier and the
// projector pairing the registry row states, and contributes no id of its own.
// Under the one-origin gateway that route is both the request-model authority
// and the roster: `src/qwen_apu/web/chat.py` answers it from remote/models.tsv,
// so the decoration and the routing read one ledger.
//
// Three properties decide the feature. A served id carrying a tier renders its
// badge and its option tags. A registry row is the only source of an option, so
// a decoration can never route a request. A read that refuses leaves the picker
// off and names the refusal rather than rendering an empty roster as a roster.

import assert from 'node:assert/strict';
import test from 'node:test';

import { bootPage, jsonResponse, registryRow } from './page.mjs';

const PRODUCTION = registryRow('qwen38-2b-distill', { role: 'fast-text', tier: 'production' });
const CANDIDATE = registryRow('qwen35-2b',
  { role: 'compact-vision', tier: 'candidate', projector: 'required' });
const UNTIERED = registryRow('unrostered-section', { tier: '' });

function optionLabels(page) {
  return page.element('#model-picker').children.map(option => option.textContent);
}

test('every registry row reaches the picker with its own tags', async () => {
  const page = await bootPage({ rows: [PRODUCTION, CANDIDATE, UNTIERED] });
  assert.deepEqual(optionLabels(page), [
    `${PRODUCTION.id} [production]`,
    `${CANDIDATE.id} [candidate vision]`,
    UNTIERED.id
  ], 'the picker labels carry the row tags and leave an untiered id bare');

  const badge = page.element('#model-tier');
  assert.equal(badge.textContent, 'production', 'the badge names the selected tier');
  assert.equal(badge.className, 'tier-badge production');
  assert.equal(badge.hidden, false);
});

test('the support matrix stays closed while no route serves a feature claim', async () => {
  // A feature claim is a separate ledger, and no gateway route carries it, so
  // the composed roster states no feature and the matrix renders nothing rather
  // than a header over no columns.
  const page = await bootPage({ rows: [PRODUCTION, CANDIDATE] });
  assert.equal(page.element('#roster-matrix').hidden, true);
  assert.equal(page.element('#roster-matrix-body').children.length, 0);
});

// The claim ledger a route would serve, assigned directly: the matrix renders
// one row per served id the roster carries and one column per model-scope
// feature, which is the contract a later route has to meet.
const CLAIM_ROSTER = {
  schema: 'qwen-feature-roster/1',
  features: [
    { feature: 'text-chat', scope: 'model' },
    { feature: 'vision', scope: 'model' },
    { feature: 'web-search', scope: 'web-profile' }
  ],
  models: [
    {
      id: PRODUCTION.id,
      tier: 'production',
      tags: ['production'],
      features: [
        { feature: 'text-chat', status: 'production',
          evidence: 'evidence/model-admission/roster-quality-sweep.md',
          note: 'graded 40 of 55 with thinking off' },
        { feature: 'vision', status: 'unsupported', evidence: '-', note: '-' }
      ]
    },
    {
      id: CANDIDATE.id,
      tier: 'candidate',
      tags: ['candidate', 'vision'],
      features: [
        { feature: 'vision', status: 'candidate',
          evidence: 'evidence/depth-validation-32k-projector/qwen35-2b/',
          note: 'the revision-matched projector loads' }
      ]
    },
    {
      id: 'withheld-by-the-registry',
      tier: 'production',
      tags: ['production'],
      features: [{ feature: 'text-chat', status: 'production', evidence: '-', note: '-' }]
    }
  ],
  image_profiles: []
};

function matrixRows(page) {
  const container = page.element('#roster-matrix-body');
  assert.equal(container.children.length, 1, 'the matrix holds other than one table');
  return container.children[0].children.map(row => row.children.map(cell => ({
    text: cell.textContent,
    className: cell.className,
    title: cell.title
  })));
}

test('the matrix decorates served ids and contributes none', async () => {
  const page = await bootPage({ rows: [PRODUCTION, CANDIDATE, UNTIERED] });
  page.modules.models.modelState.roster = CLAIM_ROSTER;
  page.modules.models.renderSupportMatrix([PRODUCTION.id, CANDIDATE.id, UNTIERED.id]);

  assert.equal(page.element('#roster-matrix').hidden, false,
    'the matrix stayed closed over a roster that decorates a row');
  assert.match(page.element('#roster-summary').textContent,
    /feature support for 2 of 3 routable models/);

  const rows = matrixRows(page);
  assert.deepEqual(rows[0].map(cell => cell.text), ['model', 'text-chat', 'vision'],
    'the header names other than the model-scope features, so web-search leaked in');
  assert.equal(rows.length, 3,
    'the matrix holds other than a header and one row per decorated served id');
  assert.equal(rows[1][0].text, `${PRODUCTION.id} (production)`);
  assert.equal(rows[1][1].className, 'production');
  assert.match(rows[1][1].text, /^production/);
  assert.match(rows[1][1].text, /evidence\/model-admission\/roster-quality-sweep\.md/);
  assert.equal(rows[1][1].title, 'graded 40 of 55 with thinking off');
  assert.equal(rows[1][2].className, 'unsupported',
    'an unsupported claim renders another class');
  assert.equal(rows[1][2].text, 'unsupported', 'an evidence of - added a path to the cell');
  assert.equal(rows[2][0].text, `${CANDIDATE.id} (candidate)`);
  assert.equal(rows[2][1].className, 'unclaimed',
    'a feature the row claims nothing for reads other than unclaimed');
  assert.equal(rows[2][2].className, 'candidate');
  assert.ok(rows.every(row => row.every(cell => !cell.text.includes('withheld-by-the-registry'))),
    'a roster id the registry withheld reached a matrix row');
});

test('an untiered row keeps its option and hides the badge', async () => {
  const page = await bootPage({ rows: [UNTIERED] });
  assert.deepEqual(optionLabels(page), [UNTIERED.id]);
  assert.equal(page.element('#model-picker').hidden, false,
    'a row carrying no tier left the picker closed');
  assert.equal(page.element('#model-tier').hidden, true);
});

test('a refused registry read names the refusal and routes nothing', async () => {
  const page = await bootPage({ rows: [PRODUCTION], registryStatus: 500 });
  assert.match(page.element('#model').textContent, /cannot load model roster.*HTTP 500/);
  assert.equal(page.element('#model-picker').hidden, true);
  assert.equal(page.element('#roster-matrix').hidden, true);
});

test('a registry carrying no row says so', async () => {
  const page = await bootPage({ rows: [] });
  assert.equal(page.element('#model').textContent, 'server reports no routable model');
  assert.equal(page.element('#model-picker').hidden, true);
});
