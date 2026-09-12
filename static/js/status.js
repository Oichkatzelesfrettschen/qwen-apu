/* The entry point: the pairing entry, the tabs, the health probe, and the one
   order the modules initialize in.

   Every other module declares functions and state and touches the document
   nowhere at evaluation, so this file decides when each one binds its controls.
   The order is the dependency order a first paint needs: the LAN bounds, the
   tool toggles, the conversation panel, the attachment input, the chat
   controls, the picker, then the two network reads -- the conversation store
   and the model registry -- last.

   The credential is the session `POST /api/pair` mints. A guarded route
   answering 401 is the one fact that reveals the pairing field, and a
   successful pairing re-runs `boot()` under the session the gateway just set,
   so a reader who pairs reaches the picker without reloading. The code travels
   in a request body, is never stored, and is cleared from the field the moment
   it is spent. */

import { $, applySessionModeToUi, initLanBounds, pairWithCode } from './api.js';
import { initAttachments } from './attachments.js';
import { initChatControls } from './chat.js';
import {
  exportBrowserHistory,
  historyExportFilename,
  initConversationPanel,
  startConversations
} from './conversations.js';
import { boot, initModelPicker } from './models.js';
import { initToolToggles } from './tools.js';
import { renderTemporaryBanner } from './temporary.js';

async function spendPairingCode() {
  const field = $('#pair-code');
  const code = field.value.trim();
  if (!code) {
    $('#model').textContent = 'enter the pairing code `qwen-apu status` prints';
    return;
  }
  $('#pair').disabled = true;
  try {
    await pairWithCode(code);
  } catch (error) {
    $('#model').textContent = `pairing refused: ${error.message || error}`;
    return;
  } finally {
    // The code is single use and the session is a cookie, so the field holds
    // nothing after the attempt whichever way it went.
    field.value = '';
    $('#pair').disabled = false;
  }
  applySessionModeToUi();
  $('#model').textContent = 'paired; connecting';
  await boot();
  await startConversations();
}

export function initPairing() {
  $('#pair').onclick = () => { void spendPairingCode(); };
  $('#pair-code').addEventListener('keydown', event => {
    if (event.key === 'Enter') $('#pair').click();
  });
  applySessionModeToUi();
}

export function selectTab(name) {
  /* The two tabs name two launches of one binary rather than two routes of one
     listener. `server_http_context::init` mounts a `--path` directory at
     `api_prefix + "/"` where `public_path` carries a value
     (tools/server/server-http.cpp:333-335) and registers the compiled-in UI
     assets under the same prefix in its else branch (:339-427), and
     `--api-prefix` supplies one value to whichever branch runs
     (common/arg.cpp:3352-3356), so the embedded UI reaches no second prefix
     beside a served static path. Router mode leaves that unchanged:
     `ctx_http.init(params)` runs ahead of the router branch
     (tools/server/server.cpp:173 against :188-232). The tab therefore opens a
     notice naming the launch that serves the other page, and the page this
     notice belongs to keeps the surfaces the other one has none of. */
  const chatSelected = name !== 'llama';
  // The address is read when the panel opens rather than at boot: the route
  // passes the session gate, and a page that never opens this tab sends no
  // request for an origin it does not display.
  if (!chatSelected) void initLlamaUiLink();
  $('#workspace').hidden = !chatSelected;
  $('#llama-ui-panel').hidden = chatSelected;
  $('#tab-chat').setAttribute('aria-selected', String(chatSelected));
  $('#tab-llama').setAttribute('aria-selected', String(!chatSelected));
}

export function initTabs() {
  $('#tab-chat').onclick = () => selectTab('chat');
  $('#tab-llama').onclick = () => selectTab('llama');
}

export async function initLlamaUiLink() {
  /* Point the tab at the listener that serves llama.cpp's own page.

     `GET /api/status` reports `gateway.llama_ui_origin`, which the assembly
     derives from the bind host and `--llama-ui-port`; a launch that binds no
     second listener reports the empty string. The route passes the session
     gate, so an unpaired page reads nothing and the markup's own relative root
     stays until a pairing admits the read. */
  const link = $('#llama-ui-link');
  const hint = $('#llama-ui-origin');
  try {
    const response = await fetch('/api/status');
    if (!response.ok) {
      hint.textContent = response.status === 401 ? ' -- pair to read the address' : '';
      return '';
    }
    const report = await response.json();
    const origin = (report && report.gateway && report.gateway.llama_ui_origin) || '';
    if (origin) {
      link.href = `${origin}/`;
      hint.textContent = ` -- ${origin}`;
    } else {
      hint.textContent = ' -- this launch binds no second listener';
    }
    return origin;
  } catch (error) {
    hint.textContent = ` -- the address is unread: ${error.message || error}`;
    return '';
  }
}

export async function probeHealth() {
  /* Report what the gateway says about the model behind it.

     `GET /api/health` is the one route that passes the session gate unpaired
     (`UNGUARDED_PATHS` in web/auth.py), and `StatusService.health` reads the
     upstream's own status field rather than its 200: llama-server answers
     `{"status": "loading model"}` with a 200 while it streams a checkpoint in,
     and `serving` is what separates that from a server holding a model. */
  const line = $('#health');
  try {
    const response = await fetch('/api/health');
    if (!response.ok) {
      // 401 is the session gate rather than the model: the pairing card states
      // what to do about it, so the status line names the state instead of the
      // status code.
      line.textContent = response.status === 401
        ? 'not paired yet'
        : `health returned HTTP ${response.status}`;
      return null;
    }
    const report = await response.json();
    const serving = report && report.upstream && report.upstream.serving === true;
    line.textContent = serving ? 'upstream serving' : 'upstream not serving';
    return report;
  } catch (error) {
    line.textContent = `health unreachable: ${error.message || error}`;
    return null;
  }
}

async function downloadHistoryExport() {
  /* Write every durable record out as one JSON document the reader keeps.

     The document is built in this tab and handed to the browser as a blob URL,
     so the records reach no route and no second origin: an export leaves this
     browser only where the reader saves the file. */
  const note = $('#conversation-export-status');
  const button = $('#conversation-export');
  button.disabled = true;
  try {
    const { document: document_, store, unreadable } = await exportBrowserHistory();
    const count = document_.conversations.length;
    const blob = new Blob([JSON.stringify(document_, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = historyExportFilename(document_);
    link.click();
    // The click is synchronous and the browser has read the blob by the time
    // it returns, so the URL is released on the next task rather than held for
    // the life of the page.
    setTimeout(() => { URL.revokeObjectURL(url); }, 0);
    const missing = unreadable
      ? `; ${unreadable} record${unreadable === 1 ? '' : 's'} unreadable`
      : '';
    note.textContent =
      `exported ${count} conversation${count === 1 ? '' : 's'} from ${store}${missing}`;
  } catch (error) {
    note.className = 'meta bad';
    note.textContent = `the export did not run: ${error.message || error}`;
  } finally {
    button.disabled = false;
  }
}

export function initHistoryExport() {
  $('#conversation-export').onclick = () => { void downloadHistoryExport(); };
}

export async function start() {
  initLanBounds();
  initToolToggles();
  initTabs();
  initPairing();
  initHistoryExport();
  initConversationPanel();
  initAttachments();
  initChatControls();
  initModelPicker();
  renderTemporaryBanner();
  void probeHealth();
  startConversations();
  await boot();
}

// The module is the page's entry point, so the start runs on import. Every
// other module leaves its own evaluation free of the document for exactly
// this reason: one call site owns the order.
void start();
