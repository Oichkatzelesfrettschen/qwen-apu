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
  const line = element('landing-status');
  line.setAttribute('data-state', state);
  line.textContent = text;
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
  const served = Array.isArray(runtime.served_models) ? runtime.served_models.length : 0;
  const routerState = typeof runtime.router_state === 'string' ? runtime.router_state : '';
  if (routerState === 'ready') setStatus('ready', served ? `ready, ${served} models` : 'ready');
  else if (routerState) setStatus(routerState, `router ${routerState}`);
  else setStatus('ready', 'reachable');
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
