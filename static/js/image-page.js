/* The image surface's own entry.

   The studio reads its bounds from the tool matrix under the approval profile
   `GET /api/status` names, so this module makes that one read and hands the
   answer to `initStudio`. The shell that once framed this pane is gone: the
   surface is a page at its own address and nothing wraps it.
*/

import { $ } from './api.js';
import { startApprovalPolling } from './approvals.js';
import { initStudio } from './studio.js';

export const pageState = { approvals: null };

export async function start() {
  let response;
  try {
    response = await fetch('/api/status');
  } catch {
    $('#image-profile').textContent = 'the gateway is unreachable';
    return null;
  }
  if (!response.ok) {
    $('#image-profile').textContent =
      response.status === 401 || response.status === 403
        ? 'this launch pairs every peer; pair on the landing page first'
        : `status answered HTTP ${response.status}`;
    return null;
  }
  const report = await response.json();
  const gateway = (report && report.gateway) || {};
  pageState.approvals = gateway.approvals && typeof gateway.approvals === 'object'
    ? gateway.approvals
    : null;
  await initStudio(pageState);
  return report;
}

void start();
startApprovalPolling();
