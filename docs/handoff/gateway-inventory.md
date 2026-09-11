# Gateway inventory: the services one origin replaces

The browser reaches three origins today: the router (llama-server, port
42069 on the LAN launch), the approval broker (`remote/web-mcp/
authorize-broker.py`, broker port, default 8571), and the artifact listener
inside `remote/image-service.py` (broker port plus one). Phase 5 puts them
behind one Python gateway and keeps every rule below.

| Service | Listener | Auth | State under `state/` |
| --- | --- | --- | --- |
| `web-mcp/server.py` | stdio MCP child of llama-server | HMAC grant per call, single use in the ledger; `fetch` takes a signed `result_id`, never a model URL | `web-mcp-state.sqlite3` |
| `web-mcp/authorize-broker.py` | TCP, loopback by default | Host set, bearer on exposure, per-client buckets, Origin allowlist, session secret, `profile_id` match | `authorize-session.secret`, the ledger |
| `image-service.py` control | Unix socket `image-service.sock` | socket ownership; the grant was verified upstream | `vulkan-workload.lock`, `.status`, `image-service.pid`, `images/` |
| `image-service.py` artifacts | TCP | Host set, bearer before existence, bucket, digest-pattern name, publication check | `artifacts/<sha256>.png|json` |
| `image-review.py` | client | bearer to router and artifact origin; provenance binds PNG digest to prompt digest | -- |

Invariants the port carries, by authority:

- One approval issues one grant with one use (`authorize-broker.py:52`,
  `image_grant.py:262`, `server.py:910`, `server.py:2192`).
- Host check first and constant-cost, bearer before rate buckets
  (`authorize-broker.py:1038-1058`, `image-service.py:2249`).
- Origin allowlist gates `/session`; a page outside it gets no secret
  (`authorize-broker.py:959-961`).
- Bearer before existence on artifact reads, so 401 never reads as 404
  (`image-service.py:2270-2276`).
- Fetched addresses resolve to public ranges before connecting
  (`server.py:629-652`, `server.py:683`).
- Artifact names are content digests matched by pattern, never normalized
  (`image-service.py`, `send_artifact`).

## The tool matrix

`GET /api/tools?model=ID` answers one row per tool for one selected
conversation model. `qwen_apu.tools.registry` states what a tool is and which
artifact executes it, which is a property of the tree; `qwen_apu.tools.matrix`
joins that table against `remote/models.tsv`, `remote/web-profiles.tsv`,
`remote/image-profiles.tsv`, the approval settings, and the filesystem, which
is what a call would actually meet. The selector is required: an absent
`model` answers 400 and an id no ledger carries answers 404.

| State | What it says |
| --- | --- |
| `available` | the gateway serves the route and runs the call itself |
| `available_through_helper` | a second process or checkpoint runs it, named in `helper` |
| `temporarily_unavailable` | the path and the policy admit it and something this launch needs is absent |
| `not_installed` | no artifact executes it for this selection, or its asset was never fetched |
| `policy_refused` | a ledger or AGENTS.md denies the execution outright |

Each row carries `tool_id`, `title`, `lane`, `approval`, `execution_path`,
`state`, `helper`, and `reason`; the `image_generation` row also carries
`bounds` (the armed profile's `max_dimension` and `max_steps`), which the page
checks a proposal against before it opens the approval dialog.

The authorities each derivation reads:

- `web_search`, `read_url`, `wikipedia_profile`: the selected id's
  `remote/web-profiles.tsv` row. A profile other than the one this launch's
  broker signs for is `policy_refused` up front, since `POST /grant-image`
  refuses a foreign `profile_id`; `execution_policy: refused` is
  `policy_refused`; a `searxng` provider with no instance URL and the absent
  tool executor are `temporarily_unavailable`; a checkpoint no web profile
  names is `not_installed`.
- `image_interpretation`: the row's `projector` column. `required` is
  `available` and `none` is `not_installed`, because
  `remote/select-projector.sh` searches the checkpoint's own directory.
- `image_generation`: the armed `remote/image-profiles.tsv` row and the
  worker's control socket. `refused` is `policy_refused`, an unbound socket is
  `temporarily_unavailable`, and the helper is the profile's diffusion bundle.
- `image_review`: that row's `review_model`. `-`, a reviewer absent from
  `remote/models.tsv`, and a reviewer whose `projector` reads `none` are each
  `not_installed`; the helper is the reviewer's own id.
- `documents`, `calculator`: the gateway's own Phase 7 routes, `available`.
- `local_file_search`: `available` where the launch declares a readable
  `--file-root` and `policy_refused` otherwise.
- `code_tools`: `policy_refused` on every checkpoint. Every
  `remote/models.tsv` row reads `guarded_tool_execution: refused` and
  AGENTS.md keeps `--tools all` off every LAN-reaching server.
- A `tier: quarantine` selection refuses every row at once.

## The image workflow routes

| Route | Admitted by | Reaches |
| --- | --- | --- |
| `POST /api/tools/image/generate` | a `qwen-image-generate-v1` grant, spent once | the worker's `image_generate` |
| `POST /api/tools/image/status` | the gateway session | the worker's `status` |
| `POST /api/tools/image/cancel` | the gateway session | the worker's `cancel`, then `status` |
| `POST /api/tools/image/remove` | the gateway session | the publication marker alone |
| `POST /api/tools/image/review` | a `qwen-image-generate-v1` claim, spent by neither side | the router's `/v1/chat/completions` |
| `GET /api/artifacts/<sha256>.png\|.json` | the session or the bearer | the published pair |

Status and cancel name a job and describe no generation, which is what
`remote/image_protocol.py`'s closed schema requires of a control message, so
neither can smuggle a second geometry past the authorization that admitted the
first. A cancel names the running generation's own `request_id`, which
`status` reports as `job_request_id`; `remote/image-service.py`'s
`handle_cancel` answers every other identifier with `not_running`.

Remove reaches the worker at no point. Version 1's `ACTIONS` admits
`image_generate`, `cancel`, and `status`, and the service implements no
artifact deletion, so removal unlinks `.publication-<job_id>.json` -- the
inverse of the worker's atomic publish -- and every later read of either
digest answers 404.

The payload outlives the retraction, and the route says so.
`enforce_artifact_retention` builds its expiry set from
`publication_markers`, which lists `.publication-*.json`, and unlinks a
digest's bytes only while expiring the marker that names it. A pair whose
marker the gateway removed is one that sweep no longer enumerates, whatever
`QWEN_IMAGE_ARTIFACT_MAX_COUNT` and `QWEN_IMAGE_ARTIFACT_MAX_AGE_S` are set
to, so the bytes stay until an operator removes them through
`remote/check-deletion-plan.sh`. The answer carries `payload_removed: false`
and `payload_disposal` naming that script rather than a field implying an
eventual reclamation that never arrives.

The lease and the grant behave differently under failure, and the routes say
so rather than claiming a symmetry they lack. The worker holds the Vulkan
workload lease around one job, so a generation that ends refused, failed, or
without a reply sends one cancel naming its own `request_id` and the cancel
route reports the lease state the following `status` observes. The grant is
single-use and is spent between admission and dispatch, so a job that reaches
no artifact has burned it and the next generation takes a fresh approval; the
review route verifies the claim and spends nothing, which is what lets the
already-spent generation token prove which prompt a human approved.

Recorded gaps. `executeWebTool` posts to `POST /api/tools` and this gateway
mounts no such route, so the web rows read `temporarily_unavailable` and a
turn carries no web tool; restoring the lane means serving the executor, not
widening the matrix. A review of an artifact restored from saved history has
no grant, because a conversation record keeps the digest and the provenance
route rather than the token, so the review button on a restored card stays
hidden. The withheld and swapped review controls still have no route.

The gateway modules: `web/app.py` and `web/auth.py` (server, closed Host and
Origin sets, HttpOnly session cookie from a one-time pairing), `web/chat.py`
and `engines/llama.py` (streaming proxy to the router on loopback),
`tools/approvals.py` and `tools/ledger.py` (the broker's gate chain and the
shared ledger), `web/artifacts.py`, `engines/image.py`, and `tools/images.py`
(the artifact rules and the worker's control socket), and `tools/web.py` (the
search and the page read the router tools proxy previously carried). The MCP
child `server.py` stays the router's stdio tool child for a launch that still
runs the router lane; the gateway executes both web tools itself.

## The web executor: `POST /api/tools`

`tools/web.py` answers one route with two tools, and `tools/registry.py`
answers `GET /api/tools` beside it. Availability is computed rather than
declared: `web_search` and `read_url` read `served` where
`web/assemble.py` resolved a `remote/web-profiles.tsv` row whose provider is
`searxng` and whose `searxng_url` is set, and `planned` otherwise, so a
gateway serving chat alone states the two rows as planned rather than
answering a refusal at the first call.

| Route | Body | Authority | Answer |
| --- | --- | --- | --- |
| `POST /api/tools` `tool: web_search` | `query`, `max_results`, `include_domains`, `exclude_domains`, `authorization` | the `search-authorization` grant `POST /api/tools/grant` signed, rebuilt through `approvals.authorization_claim` and compared field by field, then spent once through `Ledger.consume_grant` | the rendered result blocks, each carrying one signed Result ID |
| `POST /api/tools` `tool: read_url` | `result_id`, `start_index`, `max_chars` | the Result ID the approved search signed, plus one unit of the fetch allowance `Ledger.open_search` opened and `Ledger.spend_fetch` spends | one `wrap_untrusted` frame over the window |

The grant covers a query and signs no URL, so `read_url` carries the search's
own signed reference rather than a second grant: one approval admits one
search and as many of that search's own results as the profile's `max_fetches`
names. A replayed grant meets the `grants` table's primary key, a Result ID
naming a URL its search never returned meets the `search_results` rows, and an
exhausted allowance answers `budget_exhausted`.

Bounds, all ported from `remote/web-mcp/server.py` and carried by the profile
row where the row states one:

| Bound | Value | Authority |
| --- | --- | --- |
| Query | 512 characters | `web.QUERY_CHARACTER_CAP` |
| Results | the profile's `max_results`, at most 10 | `web-profiles.tsv`, `web.RESULT_COUNT_CAP` |
| Fetches per search | the profile's `max_fetches` | `web-profiles.tsv`, `Ledger.spend_fetch` |
| Window | the profile's `max_chars_per_fetch`, at most 24000 | `web-profiles.tsv`, `web.WINDOW_CHARACTER_CAP` |
| Document | 131072 characters | `web.DOCUMENT_CHARACTER_CAP` |
| HTTP body | 4 MiB, read one byte past the cap | `web.HTTP_RESPONSE_BYTE_CAP` |
| Request | 20 seconds on the socket | `web.REQUEST_TIMEOUT_SECONDS` |
| Request body | 16384 bytes | `web.REQUEST_BODY_BYTE_CAP` |
| Content types | `text/html`, `application/xhtml+xml`, `text/plain`, UTF-8 or ASCII | `web.DOCUMENT_CONTENT_TYPES` |

Two properties differ from the predecessor by mechanism rather than by policy.
The deadline lives on the socket rather than in a POSIX interval timer, because
`signal.setitimer` belongs to the main thread and the gateway answers every
request on a worker. Each ledger writer opens its own connection and closes it,
because `sqlite3` binds a connection to its creating thread; `BEGIN IMMEDIATE`
and the 10-second busy timeout serialize the writers.

Every answer carries the one record `qwen.web-tool-outcome` names, with `state`
and `provenance` added: `state` reads `complete` or `incomplete`, and the
provenance names the operation, the query or the URL, the status term from the
ledger's audit vocabulary, the provider bytes, the returned characters, the
SHA-256 of the text the record holds, the UTC instant, and the latency. A
retrieval that reached the network and failed answers HTTP 200 with `state` of
`incomplete` and a reason, so the model reads that the page did not arrive;
`static/js/chat.js` renders that state beside the turn. A refused call -- no
session, an unverified or replayed grant, an argument outside a bound --
answers its own status carrying the same document.

Recorded scope cuts: the `content` snapshot table, so a second window of one
document retrieves the source again rather than reading a stored copy; the Exa
provider, so `searxng` is the one provider this executor reads; and the audit
trail, which `Ledger.record` still serves for the approval routes while the
executor writes no row of its own.
