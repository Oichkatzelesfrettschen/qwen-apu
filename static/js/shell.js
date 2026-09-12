/* The shell's rail and panes.

   `GET /api/status` is the one read the shell makes on its own: it passes the
   session gate, so a 401 or 403 is the unpaired state and the pairing view
   opens; a 200 carries `gateway.llama_ui_origin`, which becomes the chat
   frame's source, `gateway.approvals`, which the image studio needs to name
   the profiles a grant joins, and `runtime.router_state`, which the rail dot
   reports. The hash selects the pane, `#chat` or `#image`, so a reload returns
   to the domain the reader left. */

import { $, session } from './api.js';
import { initStudio } from './studio.js';

export const shellState = {
  view: 'chat',
  status: null,
  llamaUiOrigin: '',
  approvals: null
};

const VIEWS = ['chat', 'image'];

function viewFromHash(hash) {
  const name = String(hash || '').replace(/^#\/?/, '');
  return VIEWS.includes(name) ? name : 'chat';
}

export function selectView(name) {
  shellState.view = VIEWS.includes(name) ? name : 'chat';
  for (const view of VIEWS) {
    const pane = $(`#view-${view}`);
    const tab = $(`#nav-${view}`);
    const selected = view === shellState.view;
    pane.hidden = !selected;
    tab.setAttribute('aria-selected', selected ? 'true' : 'false');
  }
  if (shellState.view === 'image') {
    // The studio reads its matrix and gallery on the first opening rather than
    // at page load, so a reader who only chats spends no artifact reads.
    void initStudio(shellState);
  }
}

function setRailStatus(state, text) {
  $('#rail-status').setAttribute('data-state', state);
  $('#status-text').textContent = text;
}

function showPairing(reason) {
  session.paired = false;
  setRailStatus('unpaired', 'not paired');
  $('#view-pair').hidden = false;
  for (const view of VIEWS) $(`#view-${view}`).hidden = true;
  const note = $('#pair-note');
  if (reason) {
    note.hidden = false;
    note.textContent = reason;
  }
}

function hidePairing() {
  $('#view-pair').hidden = true;
  $('#pair-note').hidden = true;
  selectView(shellState.view);
}

export function applyStatus(report) {
  shellState.status = report;
  const gateway = (report && report.gateway) || {};
  const runtime = (report && report.runtime) || {};
  shellState.llamaUiOrigin = typeof gateway.llama_ui_origin === 'string' ? gateway.llama_ui_origin : '';
  shellState.approvals = gateway.approvals && typeof gateway.approvals === 'object' ? gateway.approvals : null;

  const frame = $('#chat-frame');
  const absent = $('#chat-absent');
  const plain = $('#plain-ui-link');
  if (shellState.llamaUiOrigin) {
    const target = `${shellState.llamaUiOrigin}/`;
    if (frame.getAttribute('src') !== target) frame.setAttribute('src', target);
    frame.hidden = false;
    absent.hidden = true;
    plain.href = target;
    plain.hidden = false;
  } else {
    frame.hidden = true;
    absent.hidden = false;
    plain.hidden = true;
  }

  const routerState = typeof runtime.router_state === 'string' ? runtime.router_state : '';
  const upstream = (report && report.upstream) || {};
  if (routerState === 'ready' || upstream.serving === true) {
    const served = Array.isArray(runtime.served_models) ? runtime.served_models.length : 0;
    setRailStatus('ready', served ? `ready, ${served} models` : 'ready');
  } else if (routerState === 'loading' || routerState === 'starting') {
    setRailStatus(routerState, `router ${routerState}`);
  } else if (upstream.reachable === false) {
    setRailStatus('down', 'router unreachable');
  } else {
    setRailStatus('ready', 'paired');
  }
  // A page opened on `#image` selected the pane before the report named the
  // approval profile, so the studio starts once the profile is known.
  if (shellState.view === 'image') void initStudio(shellState);
}

export async function readStatus() {
  let response;
  try {
    response = await fetch('/api/status');
  } catch (error) {
    setRailStatus('down', 'gateway unreachable');
    return null;
  }
  if (response.status === 401 || response.status === 403) {
    showPairing('');
    return null;
  }
  if (!response.ok) {
    setRailStatus('down', `status HTTP ${response.status}`);
    return null;
  }
  const report = await response.json();
  session.paired = true;
  hidePairing();
  applyStatus(report);
  return report;
}

async function pair(event) {
  if (event && typeof event.preventDefault === 'function') event.preventDefault();
  const input = $('#pair-code');
  const submit = $('#pair-submit');
  const note = $('#pair-note');
  const code = String(input.value || '').trim();
  if (!code) {
    note.hidden = false;
    note.textContent = 'enter the pairing code the appliance printed';
    return;
  }
  submit.disabled = true;
  try {
    const response = await fetch('/api/pair', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code })
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      note.hidden = false;
      note.textContent = payload.error || `pairing refused: HTTP ${response.status}`;
      return;
    }
    input.value = '';
    await readStatus();
  } catch (error) {
    note.hidden = false;
    note.textContent = `pairing failed: ${error.message || error}`;
  } finally {
    submit.disabled = false;
  }
}

export function initShell() {
  for (const view of VIEWS) {
    $(`#nav-${view}`).onclick = () => {
      window.location.hash = `#${view}`;
      selectView(view);
    };
  }
  window.addEventListener('hashchange', () => selectView(viewFromHash(window.location.hash)));
  $('#pair-form').onsubmit = pair;
  selectView(viewFromHash(window.location.hash));
  return readStatus();
}

void initShell();
