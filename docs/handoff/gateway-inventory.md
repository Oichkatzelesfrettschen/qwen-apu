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

The gateway modules: `web/app.py` and `web/auth.py` (server, closed Host and
Origin sets, HttpOnly session cookie from a one-time pairing), `web/chat.py`
and `engines/llama.py` (streaming proxy to the router on loopback),
`tools/approvals.py` and `tools/ledger.py` (the broker's gate chain and the
shared ledger), `web/artifacts.py`, `engines/image.py`, and `tools/images.py`
(the artifact rules and the worker's control socket). The MCP child
`server.py` stays the router's stdio tool child until the router tools proxy
is replaced by the gateway's own tool execution.
