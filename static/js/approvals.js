/* The pending tool approvals, and the one click each takes.

   llama.cpp's page runs its own tool loop and has no place for this panel, so
   the gateway parks a guarded call and the surfaces this appliance serves show
   it. `GET /api/tools/pending` lists what the gate holds and
   `POST /api/tools/pending/<id>` settles one, which is the human approval every
   network-reaching and device-reaching call takes before its grant is signed.

   A call nobody decides ends as a refusal at the gate's own deadline, so a
   reader with no surface open answers the model rather than hanging it.
*/

import { $ } from './api.js';

// -- pending tool approvals ---------------------------------------------

const PENDING_ROUTE = '/api/tools/pending';
const PENDING_POLL_MS = 2000;
export const approvalState = { timer: null, shown: new Map() };

function describeCall(call) {
  const params = call.params || {};
  if (call.kind === 'search') {
    const parts = [`search: ${params.query || ''}`];
    if (Array.isArray(params.include_domains) && params.include_domains.length) {
      parts.push(`only ${params.include_domains.join(', ')}`);
    }
    if (Array.isArray(params.exclude_domains) && params.exclude_domains.length) {
      parts.push(`without ${params.exclude_domains.join(', ')}`);
    }
    if (params.max_results !== undefined) parts.push(`${params.max_results} results`);
    return parts.join(' / ');
  }
  if (call.kind === 'image') {
    return `image: ${params.prompt || ''} (${params.width}x${params.height}, ${params.steps} steps, seed ${params.seed})`;
  }
  return `${call.tool}: ${JSON.stringify(params)}`;
}

async function decideCall(id, decision) {
  const response = await fetch('/api/tools/pending/' + encodeURIComponent(id), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ decision })
  });
  const card = approvalState.shown.get(id);
  if (card) {
    card.remove();
    approvalState.shown.delete(id);
  }
  return response.ok;
}

function renderCall(call) {
  const card = document.createElement('article');
  card.className = 'approval';
  card.dataset.id = call.id;
  const kind = document.createElement('div');
  kind.className = 'kind';
  kind.textContent = call.kind === 'image' ? 'image generation' : call.kind === 'search' ? 'web search' : 'tool call';
  const detail = document.createElement('div');
  detail.className = 'detail';
  detail.textContent = describeCall(call);
  const meta = document.createElement('div');
  meta.className = 'meta';
  meta.textContent = `${call.model || 'model'} asked, ${call.age_seconds}s ago`;
  const choices = document.createElement('div');
  choices.className = 'choices';
  const approve = document.createElement('button');
  approve.type = 'button';
  approve.className = 'approve';
  approve.textContent = 'Approve once';
  approve.onclick = () => { approve.disabled = true; void decideCall(call.id, 'approve'); };
  const deny = document.createElement('button');
  deny.type = 'button';
  deny.className = 'deny';
  deny.textContent = 'Deny';
  deny.onclick = () => { deny.disabled = true; void decideCall(call.id, 'deny'); };
  choices.append(approve, deny);
  card.append(kind, detail, meta, choices);
  return card;
}

export async function pollApprovals() {
  /* Show every call the gate holds and drop the cards for calls it no longer
     holds, which is how a decision made in another tab, or a wait that ran
     out, leaves this rail. */
  let response;
  try {
    response = await fetch(PENDING_ROUTE);
  } catch {
    return;
  }
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) return;
    return;
  }
  const payload = await response.json().catch(() => ({}));
  const calls = Array.isArray(payload.pending) ? payload.pending : [];
  const host = $('#approvals');
  const live = new Set();
  for (const call of calls) {
    if (typeof call.id !== 'string') continue;
    live.add(call.id);
    if (!approvalState.shown.has(call.id)) {
      const card = renderCall(call);
      approvalState.shown.set(call.id, card);
      host.append(card);
    }
  }
  for (const [id, card] of [...approvalState.shown]) {
    if (!live.has(id)) {
      card.remove();
      approvalState.shown.delete(id);
    }
  }
}


export function startApprovalPolling() {
  if (approvalState.timer) return;
  void pollApprovals();
  approvalState.timer = setInterval(() => { void pollApprovals(); }, PENDING_POLL_MS);
}
