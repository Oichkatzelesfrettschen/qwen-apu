# Web router admission against the live SearXNG instance, web-open

`remote/admit-web-router-live.sh` ran on the appliance against the `web-open`
profile under the repaired harness: the promoted `llama-server`, a real router
child, the approval broker, the MCP child, and one local SearXNG instance the
launch started and stopped. The run replayed the page's requests with curl on
the router port and then drove the served page through
`remote/web-mcp/drive-fallback-page.py`. The checked-in
`remote/web-profiles.tsv` row stayed at `execution_policy=refused` for the
duration; the harness wrote its own one-row ledger under the output directory
with that field alone moved to `validator-gated`.

29 rows: 25 pass, 3 observed, 1 fail. The failure is a fetch the provider's own
deadline ended, which is the timeout stack answering rather than a defect in
the harness or the serving path.

`evidence/web-live/20260903T0724Z/` is the first run, against `web-compact`
under the harness before its two repairs. This one carries both of the checks
that failed there: `preset_carries_search_policy` passes by reading the four
values out of the configuration the section names, and `ordinary_restore`
passes because the runtime-tree comparison now runs under `LC_ALL=C`.

## What the run measured

| Check | Result | Value |
| --- | --- | --- |
| profile row | observed | `qwen38-4b-distill`, context 32768, max_results 5, max_fetches 2, primary `qwen-open`, fallback `-`, minimum 1 |
| depth claim | observed | context 32768 against `validated_filled_depth=32768`, so no override applied and the preset carries no unvalidated-depth marker |
| preset carries the search policy | pass | url `http://127.0.0.1:8888`, primary `qwen-open`, fallback `-`, minimum 1 |
| search instance recorded | pass | `searxng_pid` on the running line, port 8888, loopback listener alone |
| `GET /healthz` | pass | 200 ahead of the capacity server |
| router roster | pass | `web-open` alone |
| tool enumeration | pass | `web_fetch_exa,web_search_exa` on the router port |
| grant | pass | 444 bytes, one single-use grant from the broker |
| search | pass | 5 results, 5 `Sources:` lines against `minimum_results` 1, engines bing and google, 1 s |
| fetch by Result ID | fail | HTTP 200 carrying `the provider request exceeded 20 seconds` |
| audit row | pass | names `category=qwen-open` and holds no query text, 15 rows |
| page turn | pass | grant from the broker, search on the router, every request on those two origins, Result ID in the transcript, an assistant answer |
| secret hygiene | pass | key, grant, and session secret absent from process images, logs, and status |
| teardown and absence | pass | router, child, broker, search instance, secret, and all three ports |
| ordinary router restored | pass | the 15-row roster the run found, back as it was |

Two engines answered where the first run drew five results from bing alone:
bing returned `vulkan.org`, `en.wikipedia.org`, and a `vulkan.org` news page,
google returned `khronos.org` and `docs.vulkan.org`. The reply names the engine
per result because a metasearch answer states which index found it.

## What the instance cost

| Sample | RSS KiB | peak RSS KiB | threads | CPU ticks |
| --- | ---: | ---: | ---: | ---: |
| before queries | 66,104 | 66,180 | 2 | 80 |
| after search | 78,104 | 78,104 | 5 | 92 |
| after fetch | 78,104 | 78,104 | 5 | 92 |
| after the page turn | 78,720 | 78,720 | 5 | 101 |

The shape matches the first run: two threads and 66 MB before the first query,
five threads and 78 MB after it, and 21 ticks of CPU over the whole run against
80 spent on startup. The stalled fetch cost the instance nothing, because a
SearXNG answer holds result metadata alone and the retrieval runs in the MCP
child against the source itself.

## The fetch the provider's deadline ended

`search_response.json` names `https://www.vulkan.org/` as the first result, and
the Result ID the harness redeemed carries that same canonical URL in its
`canonical_url` claim. `query-timing.tsv` records the call at 20 seconds, and
the reply is `{"error":"the provider request exceeded 20 seconds"}` at HTTP 200.
`REQUEST_TIMEOUT_SECONDS` in `remote/web-mcp/server.py` is 20.0, and the same
POSIX timer bounds DNS, connect, headers, and body, so the origin stalled
somewhere inside that window and the provider ended the call itself.

Each layer above it was still waiting: the emitted configuration gives the
child 30,000 ms and the router proxies with llama-server's 3600 s read timeout.
The innermost deadline answered first, which is the order
`remote/qwen-image-launch.sh` proves for the image lane and the fake admission
exercises with its 40-second fixture query. `mcp_result_to_response` maps the
refusal onto an `error` key at HTTP 200, which is why the status line reads 200
and the outcome is read from the body.

The outcome depends on the origin rather than on the appliance: the harness
redeems the first Result ID the search returned, and which host that names
changes with the query and the engines that answered. The page turn completed
regardless, because the model answered from the search results and proposed no
fetch of its own. A fetch arm that must pass whatever the network does needs a
fixture origin, which is what `remote/admit-web-router-fake.sh` provides.

## Retention

The output directory is copied whole except for the material that authorizes a
request. `keys/` held the run's own HMAC signing key and `web-mcp/` held the
grant ledger database; neither is retained. Inside the retained exchanges the
grant value in `http/6-grant.response` and `http/7-search.request` reads
`<redacted-grant>` and the session secret in `http/5-session.response` reads
`<redacted-session-secret>`. `browser-turn.json` reaches the tree as the harness
wrote it, which strips the grant from every request body it logs. The bearer API
key travels in a curl configuration file the harness removes on exit and appears
in nothing here.

`PRE_SANITIZATION_SHA256SUMS` digests the 49 files as they stood after that
redaction and after the `http/*.headers` were normalized to the LF git stores,
and before the identifier pass, which replaces the appliance hostname with
`qwen-laptop` and `/home/eirikr` with `$HOME` and touched 18 files.
