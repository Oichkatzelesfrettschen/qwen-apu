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

## Native tools in the chat pane: the open decision

The router's `web-open` section carries `LLAMA_ARG_MCP_SERVERS_CONFIG` naming
`remote/web-mcp/server.py` and `remote/image-mcp/server.py` over stdio, and
the deployed `llama-server` carries the tools proxy patch, so a chat on that
model inside llama.cpp's page reaches the same search and image tools the
legacy page did. The web MCP server runs with `QWEN_WEB_SEARCH_AUTH=required`:
a search call carries an `authorization` grant an operator issued outside the
session, and a model's own call is refused. The legacy page supplied that grant
from its approval dialog. Inside llama.cpp's page there is no dialog, so a
native search on `web-open` is refused at the tool boundary until one of these
lands:

1. `QWEN_WEB_SEARCH_AUTH=optional` on the `web-open` section admits the model's
   own search under the paired session. This removes the one-human-approval
   per network call the repository doctrine states for the LAN boundary and is
   the operator's decision, recorded in `remote/web-profiles.tsv` where the
   profile row admits it.
2. An in-flight approval: the MCP server posts the proposed query to the
   gateway's approval service and waits on its verdict up to `timeout_ms`; the
   shell's rail shows the pending approval and the click issues the grant. The
   approval stays with a human and the page stays llama.cpp's own.
3. The gateway serves the web tools over MCP Streamable HTTP to the page's own
   MCP client, with the approval carried as an MCP elicitation. The pinned
   build's elicitation support is unverified.

The shell lands with none of the three. Search in the chat pane on `web-open`
answers the refusal the tool boundary states; every other model chats without
tools, which is the state the appliance served before the shell.

## What moved and what stayed

- `static/index.html` is the shell; the previous page is
  `static/legacy/index.html` with its two asset references made relative to
  the subdirectory. `tests/webui/test-ui-switch.mjs` reads the legacy markup.
- The README's laptop section names the Python supervisor, the pairing code,
  the two ports, and the legacy chain as recovery.
- `GatewayConfig.frame_sources` and `LlamaUiSettings.frame_ancestors` are the
  two new fields; the assembly fills both from the bind host and the two ports.
