/* The gateway's own origin, and the helpers every other module reaches it
   through.

   One listener carries the page, the chat proxy, the approval grants, the
   artifact reads, and the session that admits them, so every request here is a
   same-origin `/api/*` path. The credential is an HttpOnly SameSite=Strict
   cookie `POST /api/pair` mints (src/qwen_apu/web/auth.py), which script cannot
   read and a same-origin fetch carries by itself: no Authorization header, no
   remembered bearer, and no value of the credential in any browser store.

   Nothing here touches the document or a browser store at module evaluation.
   `initLanBounds()` reads the two meta tags and every other read happens inside
   a call, so importing this module in a test context installs no requirement on
   the order the modules load in. */

export const $ = selector => document.querySelector(selector);

// The log container is read per call rather than captured at load, so this
// module binds no element before the document exists.
export function logElement() {
  return $('#log');
}

export function readBrowserStorage(storageName, key) {
  try { return window[storageName].getItem(key); } catch { return null; }
}

export function writeBrowserStorage(storageName, key, value) {
  try {
    if (value === null) window[storageName].removeItem(key);
    else window[storageName].setItem(key, value);
  } catch { /* storage denial leaves the live page state authoritative */ }
}

export function probeBrowserStorageWrite(storageName, key) {
  // A store-selection probe wants the denial to throw, where the caller's
  // own catch selects the next store, so this reaches the storage through
  // one indirection rather than the swallowing helpers above, which exist
  // for callers that want a denial absorbed instead of propagated.
  window[storageName].setItem(key, '1');
  window[storageName].removeItem(key);
}

export function prefixAtWholeCodePoint(text, maximumUnits) {
  // JavaScript slices UTF-16 units, so an offset can split an astral code
  // point into an unpaired surrogate. Build the largest prefix whose complete
  // code points fit under the same rendered-unit budget.
  let units = 0;
  const points = [];
  for (const point of text) {
    if (units + point.length > maximumUnits) break;
    points.push(point);
    units += point.length;
  }
  return points.join('');
}

/* The pairing session. `null` until a guarded route answers: `true` once a
   request passed the gate, `false` once one came back 401. The page reads this
   to decide whether the pairing controls belong on screen, and nothing here
   holds the session token, which lives in a cookie script cannot read. */
export const session = { paired: null };

export function recordSessionStatus(status) {
  // 401 is the one status auth.py answers a sessionless guarded request with,
  // so it is the only one that retires a session; every other answer proves a
  // request reached its handler.
  if (status === 401) session.paired = false;
  else if (status >= 200 && status < 500) session.paired = true;
  return status;
}

export function applySessionModeToUi() {
  /* Reveal the pairing entry exactly where a guarded route proved the session
     absent. A paired browser, and a browser that has not yet asked, both leave
     the controls off: a field asking for a code nobody needs is a field a
     reader fills in for no reason.

     The function sits beside `session` rather than in the entry point because
     `boot()` calls it the moment its first read answers, and a page module that
     imported the entry point for it would re-enter the start it performs. */
  const wants = session.paired === false;
  $('#pair-code').hidden = !wants;
  $('#pair').hidden = !wants;
  $('#pair-hint').hidden = !wants;
  // The card is the surface the three controls sit in, so it follows the same
  // fact. A page that carries the controls without the card leaves the card
  // lookup empty, and the guard keeps that page working.
  const card = $('#pair-card');
  if (card) card.hidden = !wants;
}

export async function pairWithCode(code) {
  /* Spend one pairing attempt and return what the gateway answered.

     `SessionGate.pair` meters per client address ahead of the comparison,
     answers 403 on a wrong or spent code and 429 on an exhausted window, and
     sets the session cookie on the one attempt that matches. The code travels
     in the body rather than in the URL, so it stays out of the browser history
     and the Referer header. */
  const response = await fetch('/api/pair', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    session.paired = false;
    throw new Error(payload.error || `the gateway refused the pairing: HTTP ${response.status}`);
  }
  session.paired = true;
  return payload;
}

export async function serverTokenCount(text, selectedModel) {
  if (!selectedModel) throw new Error('no routable model is selected');
  const response = await fetch('/api/models/tokenize', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: selectedModel, content: text, add_special: false })
  });
  recordSessionStatus(response.status);
  if (!response.ok) throw new Error(`tokenizer returned HTTP ${response.status}`);
  const result = await response.json();
  if (!Array.isArray(result.tokens)) throw new Error('tokenizer returned no token array');
  return result.tokens.length;
}

/* An open household-LAN launch bounds prompt and output size through
   qwen-capacity-policy.sh's QWEN_LAN_MAX_PROMPT_TOKENS and
   QWEN_LAN_MAX_OUTPUT_TOKENS, which reach --n-predict (a default the server
   applies only where a request omits max_tokens) and a clamped --ctx-size.
   These two bounds are read from a meta tag alone: a LAN token bound is a
   resource ceiling the launch sets against every peer on the network, and a
   query parameter is exactly the input a peer being bounded controls from
   their own address bar. The meta tag the served page itself carries is what
   stays out of a peer's reach, and remote/stage-webui-page.sh is what writes
   the served values into it. */
export const lanBounds = { prompt: null, output: null };

export function configuredLanBound(metaName) {
  const tag = document.querySelector(`meta[name="${metaName}"]`);
  const configured = ((tag && tag.getAttribute('content')) || '').trim();
  if (!configured) return null;
  const parsed = Number.parseInt(configured, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export function initLanBounds() {
  lanBounds.prompt = configuredLanBound('qwen-lan-max-prompt-tokens');
  lanBounds.output = configuredLanBound('qwen-lan-max-output-tokens');
}

const BROKER_SESSION_HEADER = 'X-Qwen-Web-Session';
const STALE_SESSION_SECRET_CODE = 'stale_session_secret';

// The approval session secret and every issued grant live in this module
// alone. Both stay out of `history`, which is re-sent whole on every request,
// and out of browser storage, which outlives the launch that signed them: a
// retained grant is an authorization nobody read waiting to be spent.
let approvalSessionSecret = null;

export function forgetApprovalSession() {
  approvalSessionSecret = null;
}

async function approvalSession(signal) {
  // The secret reaches the page in a response body rather than a URL, so it
  // stays out of the browser history and the Referer header. It is read once
  // and held in memory for the life of the page.
  if (approvalSessionSecret) return approvalSessionSecret;
  const response = await fetch('/api/tools/session', { method: 'GET', signal });
  recordSessionStatus(response.status);
  if (!response.ok) {
    throw new Error(`the approval broker refused the session request: HTTP ${response.status}`);
  }
  const payload = await response.json();
  if (typeof payload.session_secret !== 'string' || !payload.session_secret) {
    throw new Error('the approval broker returned no session secret');
  }
  approvalSessionSecret = payload.session_secret;
  return approvalSessionSecret;
}

async function postGrantTo(route, fields, secret, signal) {
  const response = await fetch(route, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', [BROKER_SESSION_HEADER]: secret },
    body: JSON.stringify(fields),
    signal
  });
  recordSessionStatus(response.status);
  const payload = await response.json().catch(() => ({}));
  return { response, payload };
}

async function requestGrantFrom(route, fields, signal) {
  /* The posted object is the parsed proposal itself, so the fields the human
     read in the dialog are the fields the grant covers and the served path
     compares against. `signal` aborts every fetch this call makes when a later
     denial or dismissal outruns it, so a click that landed before the dialog
     closed cannot still land a grant after it.

     A gateway restarted on the same port signs a new per-launch secret, so the
     cached one this page still holds is stale rather than wrong. One retry
     against a freshly fetched secret recovers that case without the user
     reloading the page; a second 403 is a genuine refusal and surfaces as one. */
  const secret = await approvalSession(signal);
  let { response, payload } = await postGrantTo(route, fields, secret, signal);
  if (response.status === 403 && payload.code === STALE_SESSION_SECRET_CODE) {
    approvalSessionSecret = null;
    const refreshed = await approvalSession(signal);
    ({ response, payload } = await postGrantTo(route, fields, refreshed, signal));
  }
  if (!response.ok || typeof payload.authorization !== 'string') {
    throw new Error(payload.error || `the approval broker refused: HTTP ${response.status}`);
  }
  return payload.authorization;
}

export function requestGrant(fields, signal) {
  return requestGrantFrom('/api/tools/grant', fields, signal);
}

export function requestImageGrant(fields, signal) {
  return requestGrantFrom('/api/tools/grant-image', fields, signal);
}

export function randomSeed() {
  // crypto.getRandomValues is the browser's cryptographic RNG. A seed
  // generated here is what the approval binds: randomness is never chosen
  // after authorization, so this runs before the dialog opens rather than
  // after the human approves.
  return crypto.getRandomValues(new Uint32Array(1))[0];
}

// WebCrypto's `subtle` is a [SecureContext] interface, so a browser exposes
// it on https and on localhost and leaves `crypto.subtle` undefined on the
// plain-HTTP LAN origin qwen-lan-launch.sh serves, while `getRandomValues`
// stays available everywhere. The image grant is signed over the prompt
// hash, so the page computes SHA-256 in script where the platform withholds
// the primitive: sha256Bytes is FIPS 180-4 over the UTF-8 bytes, and
// test-fallback-webui-sha256.mjs holds it to node's own digest.
const SHA256_ROUND_CONSTANTS = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

export function sha256Bytes(bytes) {
  const state = new Uint32Array([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  // Padding: one 0x80 byte, zeros to 56 mod 64, then the bit length as a
  // 64-bit big-endian integer.
  const paddedLength = Math.ceil((bytes.length + 9) / 64) * 64;
  const padded = new Uint8Array(paddedLength);
  padded.set(bytes);
  padded[bytes.length] = 0x80;
  const view = new DataView(padded.buffer);
  const bitLength = bytes.length * 8;
  view.setUint32(paddedLength - 8, Math.floor(bitLength / 0x100000000));
  view.setUint32(paddedLength - 4, bitLength >>> 0);
  const schedule = new Uint32Array(64);
  const rotr = (value, count) => (value >>> count) | (value << (32 - count));
  for (let offset = 0; offset < paddedLength; offset += 64) {
    for (let i = 0; i < 16; i += 1) schedule[i] = view.getUint32(offset + i * 4);
    for (let i = 16; i < 64; i += 1) {
      const s0 = rotr(schedule[i - 15], 7) ^ rotr(schedule[i - 15], 18) ^ (schedule[i - 15] >>> 3);
      const s1 = rotr(schedule[i - 2], 17) ^ rotr(schedule[i - 2], 19) ^ (schedule[i - 2] >>> 10);
      schedule[i] = (schedule[i - 16] + s0 + schedule[i - 7] + s1) >>> 0;
    }
    let [a, b, c, d, e, f, g, h] = state;
    for (let i = 0; i < 64; i += 1) {
      const s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      const choose = (e & f) ^ (~e & g);
      const t1 = (h + s1 + choose + SHA256_ROUND_CONSTANTS[i] + schedule[i]) >>> 0;
      const s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      const majority = (a & b) ^ (a & c) ^ (b & c);
      const t2 = (s0 + majority) >>> 0;
      h = g; g = f; f = e; e = (d + t1) >>> 0;
      d = c; c = b; b = a; a = (t1 + t2) >>> 0;
    }
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
  }
  const digest = new Uint8Array(32);
  const digestView = new DataView(digest.buffer);
  for (let i = 0; i < 8; i += 1) digestView.setUint32(i * 4, state[i]);
  return digest;
}

export function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}

export function subtleDigestAvailable() {
  return Boolean(typeof crypto !== 'undefined' && crypto && crypto.subtle
    && typeof crypto.subtle.digest === 'function');
}

export async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(text);
  if (subtleDigestAvailable()) {
    return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)));
  }
  return bytesToHex(sha256Bytes(bytes));
}
