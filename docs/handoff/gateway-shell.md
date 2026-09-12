# The gateway shell: two native surfaces behind one rail

The page the gateway serves at `/` is a shell. A rail on the left selects a
domain, Chat or Image, and each pane wraps a surface that exists on its own
rather than composing one: Chat frames llama.cpp's built-in page from the
gateway's second listener, and Image drives the gateway's own generation
routes. The single-page client that carried chat, tools, artifacts, and
conversations in one document stays served under `/legacy/` and receives no
further features. `static/index.html`, `static/shell.css`,
`static/js/shell.js`, and `static/js/studio.js` are the shell;
`tests/webui/test-shell.mjs` drives it.

## Why the split falls this way

The llama.cpp page at the pinned commit carries the model picker over the
router's `/models` stream, image and document attachments, the reasoning fold,
tool-call rendering, an MCP client, and saved conversations in IndexedDB. The
legacy page re-implemented each of those against the same routes, and every
one of its Phase 8 acceptance gaps was a divergence between the two
implementations. The shell keeps the one thing llama.cpp's page has no route
for, image generation under a human approval, and hands everything else to the
page that already does it.

The build under `.runtime/opt/llama-ui/dist` uses relative asset paths and a
hash router (`tools/ui/svelte.config.js`: `paths.relative: true`,
`router.type: 'hash'`), so it serves from any path. Its API constants mix
relative (`./v1/chat/completions`) and absolute (`/v1/models`, `/tools`) paths,
which is why the shell frames the second listener at its own origin rather than
mounting the bundle under a prefix on the chat port: mounting would split the
API between two prefixes, and the frame keeps every request on the origin the
bundle was built for.

## What one pairing covers

`POST /api/pair` on the shell's port mints the `qwen_apu_session` cookie with
`SameSite=Strict`, `HttpOnly`, `Path=/`, and no port, so a document framed
from the sibling port on the same host presents the same session. The gateway
sends `frame-src <second listener origin>` on the shell page
(`web/app.py: content_security_policy`), and the second listener sends
`frame-ancestors <shell origin>` on the page, its assets, and every proxied
answer (`web/llama_ui.py: content_security_policy`); a listener assembled
without a framer keeps `frame-ancestors 'none'`. Both origins come from the
same `GatewayRequest`, so a bind host change moves both directives at once.

## The bundle's own script decides the listener's policy

`bundle_script_sources` reads the served `index.html` at assembly and hashes
each inline script block, so `script-src` names those digests rather than
`'unsafe-inline'`. The built page carries exactly one such block. A launch
that serves no bundle leaves the router serving its own page, whose bytes
never reach this process, and the empty tuple keeps the keyword for it.

`style-src` keeps `'unsafe-inline'` on the evidence: the built page's markup
carries one `style` attribute and its bundle calls `setAttribute("style",
...)` in five places, and CSP's `style-src-attr` falls back to `style-src`
and governs both, so a digest list would refuse the page's own layout. The
falsifier is direct: a build whose markup and bundle set no style attribute
takes style digests the same way the script sources are taken.

## The listener refuses the bundle's service worker

A registered service worker precaches the page and replays the response it
stored, headers included. The listener served `frame-ancestors 'none'` before
the shell existed, so a browser that opened the plain page then holds a
precached copy carrying that directive and refuses to be framed afterward,
whatever the listener now sends. Firefox reports it as the embedding refusal
it is.

`REFUSED_ASSET_PATHS` answers `/sw.js` with 404, so no registration is made
and a browser holding one drops it at its next update check. The appliance
serves one LAN origin behind a pairing cookie and has no offline case, so the
worker is refused rather than versioned. A browser that already registered
one clears it by opening the listener directly and reloading, or through the
site's stored data.

## The image studio

The human types the prompt, so the click on Generate is the approval. The
studio reads `gateway.approvals.profile` from `GET /api/status` as the language
profile a grant joins, `GET /api/tools?model=<that profile>` for the
`image_generation` row's bounds (profile id, frame, step ceiling, and the
state that decides whether Generate is live), then per job: `GET
/api/tools/session`, `POST /api/tools/grant-image` over the prompt digests,
seed, aspect, dimension bound, and step count, and `POST
/api/tools/image/generate` with the grant. `POST /api/tools/image/status` polls
the worker every two seconds while the synchronous generation runs, Cancel
ends the worker's job by the identifier status reports and aborts the wait,
and the gallery is `GET /api/artifacts`, with `POST /api/tools/image/remove`
retracting one publication. The studio holds no state a reload loses.

## Native tools in the chat pane: the approval gate

llama.cpp's page runs the tool loop itself: `GET /tools?model=` lists the
router's tools, the page offers them to the model, and each `tool_calls` entry
executes through `POST /tools` with `tool`, `params`, and the model name. The
router forwards the call to the child serving that model, whose MCP manager
hands it over stdio to `remote/web-mcp/server.py` or
`remote/image-mcp/server.py`. Both servers require an `authorization` grant
signed with the gateway's token key over the exact arguments, which the model
cannot produce, and the web server runs with `QWEN_WEB_SEARCH_AUTH=required`.

`src/qwen_apu/web/tool_gate.py` sits at the first link. The second listener's
proxy admits `/tools` through the gate alone: the listing passes through, and
a call whose tool name ends in `_search_exa` or `_generate_image` parks as a
pending approval. The shell's rail polls `GET /api/tools/pending` and shows
each parked call with its query or its frame; the operator's click posts
`approve` or `deny` to `POST /api/tools/pending/<id>`. Approval signs the
grant through the same `issue_search_grant` and `issue_image_grant` the custom
page's grant routes use, with the same key and profile names, and injects it
into `params` before the call goes to the router; denial, or a wait past 120
seconds, answers the page `{"error": ...}` in the `/tools` shape, so the model
reads why the call did not run. `fetch_exa` passes untouched under its
result identifier. A listener assembled without a gate answers 404 on both
`/tools` methods, so a page there is offered no tool it cannot run.

The human approval therefore stays where the doctrine puts it, one click per
network-reaching or device-reaching call, and llama.cpp's page, the MCP
servers, and the router are unchanged.

## What moved and what stayed

- `static/index.html` is the shell; the previous page is
  `static/legacy/index.html` with its two asset references made relative to
  the subdirectory. `tests/webui/test-ui-switch.mjs` reads the legacy markup.
- The README's laptop section names the Python supervisor, the pairing code,
  the two ports, and the legacy chain as recovery.
- `GatewayConfig.frame_sources` and `LlamaUiSettings.frame_ancestors` are the
  two new fields; the assembly fills both from the bind host and the two ports.
- `LlamaUiSettings.tool_gate` carries the approval gate the assembly builds
  from the approval settings; `Gateway.tool_gate` hands it from the chat page's
  gateway to the second listener.
