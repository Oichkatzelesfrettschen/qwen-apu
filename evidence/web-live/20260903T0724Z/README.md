# Web router admission against the live SearXNG instance

`remote/admit-web-router-live.sh` ran on the appliance against the `web-compact`
profile: the promoted `llama-server`, a real router child, the approval broker,
the MCP child, and one local SearXNG instance the launch started and stopped.
The run replayed the page's requests with curl on the router port and then drove
the served page through `remote/web-mcp/drive-fallback-page.py`. The checked-in
`remote/web-profiles.tsv` row stayed at `execution_policy=refused`; the harness
wrote its own one-row ledger under the output directory with that field alone
moved to `validator-gated`.

29 rows: 24 pass, 3 observed, 2 fail. Both failures belong to the harness rather
than to the serving path, and both are repaired in the same branch.

## What the run measured

| Check | Result | Value |
| --- | --- | --- |
| profile row | observed | `qwen35-2b`, context 8192, max_results 5, max_fetches 2, primary `qwen-open`, fallback `-`, minimum 1 |
| depth claim | observed | context 8192 against `validated_filled_depth=-`, so the unvalidated-depth override applied |
| search instance recorded | pass | `searxng_pid` on the running line, port 8888, loopback listener alone |
| `GET /healthz` | pass | 200 ahead of the capacity server |
| router roster | pass | `web-compact` alone |
| tool enumeration | pass | `web_fetch_exa,web_search_exa` on the router port |
| grant | pass | 448 bytes, one single-use grant from the broker |
| search | pass | 5 results, 5 `Sources:` lines against `minimum_results` 1, 1 s |
| fetch by Result ID | pass | 12,347 characters, 1 s |
| audit row | pass | names `category=qwen-open` and holds no query text, 261 rows |
| page turn | pass | grant from the broker, search on the router, every request on those two origins, Result ID in the transcript, an assistant answer |
| secret hygiene | pass | key, grant, and session secret absent from process images, logs, and status |
| teardown and absence | pass | router, child, broker, search instance, secret, and all three ports |

The engines answering were `bing` on all five results. `qwen-open` holds bing,
google, and wikipedia, so this run exercised one of the three rather than the
population the category carries, and the reply names the engine per result
because a metasearch answer states which index found it.

## What the instance cost

| Sample | RSS KiB | peak RSS KiB | threads | CPU ticks |
| --- | ---: | ---: | ---: | ---: |
| before queries | 66,008 | 66,016 | 2 | 83 |
| after search | 75,252 | 75,252 | 5 | 95 |
| after fetch | 75,252 | 75,252 | 5 | 95 |
| after the page turn | 75,576 | 75,576 | 5 | 103 |

The instance reaches its serving shape on the first query: two threads and 66 MB
before it, five threads and 75 MB after, and 20 ticks of CPU over the whole run
against 83 spent on startup. Both queries completed in 1 s at second resolution,
which bounds them rather than resolving the 180 to 510 ms the engine sweep
measured.

## The two failures

`preset_carries_search_policy=fail` reported that the emitted configuration
names no instance URL or primary category, while the search that followed ran
under `category=qwen-open` against `http://127.0.0.1:8888`. The check greps the
preset INI, and a section carries `LLAMA_ARG_MCP_SERVERS_CONFIG` and none of the
policy itself: the four values live in the JSON that path names.
`remote/read-mcp-server-env.sh` now resolves the configuration through the
section and parses it, the harness compares all four against the profile row,
and `remote/test-web-presets.sh` reads a generated searxng preset back through
the same reader.

`ordinary_restore=fail comm: input is not in sorted order` ended the run when
the harness put the ordinary router back. `remote/check-runtime-tree.sh` sorts
both path lists under `LC_ALL=C` and compared them with `comm` under the
invoking locale, which on this appliance is `en_US.UTF-8`: that collation
ignores `-` and `_` at its first level and orders `image_protocol.py` ahead of
`image-teardown-check.sh` where C compares 0x2D below 0x5F and does the reverse.
The disorder only surfaces once the two lists differ, and they differed because
`remote/sync-runtime-tree.sh` had walked the workstation directory and adopted
`remote/web-mcp/__pycache__/server.cpython-314.pyc` as payload. Three repairs
follow: the comparison runs under `LC_ALL=C` and names bytecode as its own stray
class, the sync enumerates `git ls-files` and excludes bytecode on both sides
with `--delete-excluded`, and every python child of the launch chain carries
`PYTHONDONTWRITEBYTECODE=1` -- in the emitted MCP configuration for the web and
image servers, and exported by `remote/qwen-webui-session.sh` for the children
it starts itself. The run had left
`remote/__pycache__/image_protocol*.pyc` and
`remote/web-mcp/__pycache__/{server,image_grant}*.pyc` on the appliance, which
is the population that suppression prevents.

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

`PRE_SANITIZATION_SHA256SUMS` digests the 46 files as they stood after that
redaction and before the identifier pass, because the pre-redaction bytes carry
a grant and a session secret and are retained nowhere. The identifier pass
replaces the appliance hostname with `qwen-laptop` and `/home/eirikr` with
`$HOME`, which touched 16 files. The eight `http/*.headers` files carry the
CRLF an HTTP response line ends with, and git stores them with LF: they are
normalized here so the bytes a clone receives are the bytes
`evidence/SHA256SUMS` names, which is why their digests differ from the ones
recorded above.
