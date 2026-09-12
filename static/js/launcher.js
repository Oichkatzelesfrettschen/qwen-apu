/* The landing page's one read.

   `GET /api/status` names the address of each surface this launch binds, so
   the links carry the ports the launch chose rather than arithmetic on this
   page's own port. A surface the launch did not bind leaves its card disabled
   and saying so, because a link to a socket nobody holds is worse than a card
   that states the launch.

   The read passes the session gate. A launch serving this reader without a
   pairing code answers it, and one that pairs answers 401 until the reader
   pairs on this origin, which the status line states. */

import { startApprovalPolling } from './approvals.js';

const CHOICES = [
  { id: 'chat', field: 'llama_ui_origin', absent: 'this launch binds no chat listener' },
  { id: 'image', field: 'image_ui_origin', absent: 'this launch binds no image listener' }
];

export const launcherState = { status: null, origins: {} };

function element(id) {
  return document.querySelector(`#${id}`);
}

function setStatus(state, text) {
  /* The resting page states nothing: a reader who can see two choices needs
     no line telling them the gateway answered. A line appears only where the
     read failed, which is the case a blank page would leave unexplained. */
  const line = element('landing-status');
  line.setAttribute('data-state', state);
  line.textContent = text;
  line.hidden = state === 'ready';
}

export function applyStatus(report) {
  launcherState.status = report;
  const gateway = (report && report.gateway) || {};
  const runtime = (report && report.runtime) || {};
  for (const choice of CHOICES) {
    const origin = typeof gateway[choice.field] === 'string' ? gateway[choice.field] : '';
    const card = element(`choice-${choice.id}`);
    const where = element(`${choice.id}-where`);
    launcherState.origins[choice.id] = origin;
    if (origin) {
      card.href = `${origin}/`;
      card.removeAttribute('aria-disabled');
      where.textContent = origin.replace(/^https?:\/\//, '');
    } else {
      card.href = '#';
      card.setAttribute('aria-disabled', 'true');
      where.textContent = choice.absent;
    }
  }
  const routerState = typeof runtime.router_state === 'string' ? runtime.router_state : '';
  if (routerState && routerState !== 'ready') setStatus(routerState, `the router is ${routerState}`);
  else setStatus('ready', '');
}

export async function readStatus() {
  let response;
  try {
    response = await fetch('/api/status');
  } catch {
    setStatus('down', 'the gateway is unreachable');
    return null;
  }
  if (response.status === 401 || response.status === 403) {
    setStatus('down', 'this launch pairs every peer; pair on this address first');
    return null;
  }
  if (!response.ok) {
    setStatus('down', `status answered HTTP ${response.status}`);
    return null;
  }
  const report = await response.json();
  applyStatus(report);
  return report;
}

void readStatus();
startApprovalPolling();
