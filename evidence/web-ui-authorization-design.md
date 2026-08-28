# Extending the pinned llama-ui permission gate to exact arguments

The pinned llama-ui stores a tool permission as `{toolName, serverLabel}` and
offers four grades: ALWAYS, ALWAYS_SERVER, ONCE, and DENY. That state answers
whether a tool may run and holds nothing about what it would run with, so an
ALWAYS entry for `web_search_exa` under the server label `web` admits every
later call of that tool whatever arguments it carries. `evidence/model-admission`
records `tool-08` carrying an injected city into a tool call in place of the
authorized one in all six measured arms, so the argument is where the
substitution happens and the tool name is where the gate looks. A remembered
grade over a tool name therefore records an approval of a call the user read
and applies it to calls nobody reads.

`remote/web-mcp/server.py` closes that gap at the wrapper rather than in the
front end: `search_exa` verifies an HMAC-signed grant over the query, both
domain lists, the publication window, `max_age_hours`, `max_results`, and an
expiry, and `enforce_search_authorization` compares the presented arguments
against the claim field by field. The front end's part is to obtain a grant
over the arguments a human read, which is what this design records.

## The gate state carries the arguments and a risk class

The extension is one shape:

```ts
{ toolName: string, serverLabel: string, arguments: string,
  riskClass: 'network-search' }
```

`arguments` is the exact JSON argument string the model emitted, retained
verbatim rather than re-serialized, because the grant is signed over a
canonical form derived from the parsed fields and a re-serialization that
reorders keys would leave the stored state describing a different byte string
than the one approved. `riskClass` states what the approval spends: a
`network-search` call reaches a third-party provider, spends metered budget
under `QWEN_WEB_DAILY_BUDGET`, and returns attacker-controlled text into the
context, which is a different class of grant from a read-only local tool.

The class decides the grades the gate offers. A tool with no risk class keeps
the four existing grades. `network-search` offers ONCE and DENY alone, because
the grant `authorize-broker.py` signs carries `max_uses` of one and the ledger
spends it under `grant_id` as a primary key: a remembered ALWAYS would produce
a UI state promising a standing permission that the serving path refuses on the
second call, which is worse than the absent grade because it reads as working.

A stored entry is therefore keyed on all four fields. A call whose `toolName`
and `serverLabel` match a stored entry while its `arguments` differ misses the
lookup and prompts, which is the whole content of the extension: argument
equality rather than name equality decides whether an approval applies.

## The patch outline

Four changes, in the order a reader follows them.

The permission state type gains `arguments` and `riskClass`, and every lookup
that currently compares `toolName` and `serverLabel` compares all four. A
persisted entry written by an earlier build carries neither new field and is
read as matching no call, so an upgrade prompts rather than applying a stored
grade to an argument set that was never part of it.

The risk class is resolved where the MCP tool list is received. A tool whose
composed name is `web_search_exa` -- the server named `web` in
`--mcp-servers-config` composed with the tool name -- takes
`riskClass: 'network-search'`. Resolving it from the tool list rather than from
the call keeps a model-authored name from selecting its own class.

The permission dialog renders the parsed arguments for a `network-search` call:
the query, the publication interval from `published_after` and
`published_before`, both domain lists, `max_results`, and `max_age_hours` with
0 named as a forced live crawl rather than printed as a number. It offers ONCE
and DENY, and the two ALWAYS buttons are absent for that class rather than
disabled, since a disabled control still tells the reader a standing grade
exists.

ONCE posts the parsed fields to the broker's `POST /grant` with the per-launch
session secret in the `X-Qwen-Web-Session` header, receives the signed grant,
and merges it into the dispatched call's `authorization` argument. The grant
enters the dispatched arguments alone: the conversation store keeps the
proposal it was signed over, so a transcript re-sent on a later turn carries no
token and a single-use grant is presented once. DENY returns a tool result
stating that the search did not run.

## Scope cut: the UI source lives outside this tree

The change is unimplemented here. `remote/build-llama-ui.sh` reads the front end
from `${QWEN_UI_SOURCE:-src/llama.cpp-qwen-apu/tools/ui}` on the appliance and
rsyncs the built `dist/` back, and this repository holds no `src/` directory and
no vendored copy of that source. The files that would change are
`src/llama.cpp-qwen-apu/tools/ui/` on the appliance, which reaches a clone of
this repository through a patch under `patches/` the way the four Vulkan
patches do.

`webui/index.html`, the fallback UI this tree does control, implements the same
approval path against the same broker and executes the approved call, so the
mechanism runs end to end and the pinned UI carries the outline alone.

## The client dispatches the tool call

At the pinned commit f280b269, llama-server executes no tool call of its own.
`server_mcp` (`tools/server/server-mcp.h:132-176`) spawns each configured
child and forwards one RPC per `call_tool`; nothing in `server-mcp.cpp` or
`server.cpp` reads a completion's `tool_calls` and calls it. The wrapped MCP
tools (`server-tools.cpp:1802-1839`) are reachable through two standalone
routes registered at `server.cpp:347-348`: `GET /tools` lists them and
`POST /tools` (`server-tools.cpp:2076-2081`) invokes the named tool with the
`params` object taken verbatim from the caller's request body. The chat path
never touches that registry: `oaicompat_chat_params_parse`
(`server-common.cpp:1127-1136`) reads `tools` from the client body alone, so a
completion streams the proposal and stops. The pinned UI's own
`ToolsService.executeTool` (`tools/ui/src/lib/services/tools.service.ts:22-45`)
is the executor: after the proposal it posts `{tool, params}` to `/tools`
behind its permission dialog.

Three consequences follow. The client composes the tool list: MCP schemas
reach the model only when the client fetches `GET /tools` and places them in
its own `body.tools`, which is what makes the per-turn Web toggle a boundary.
The server holds no pre-execution seam: `POST /tools` strips `cwd`, `runtime`,
and `resp_type` from headers (`server-tools.cpp:2085-2107`) and calls
`tool.invoke(params)` at once, with no callback, signature check, or stored
grant to compare against, so argument authorization happens before the browser
sends that request or not at all. And the fallback UI's design is therefore the
reachable one.

## The fallback UI executes the approved call

`webui/index.html` runs that executor. The Web toggle fetches `GET /tools` and
composes `body.tools` from the returned `web_search_exa` and `web_fetch_exa`
definitions, cached against the model id and selection generation the way the
context length is, and strips the `authorization` property the wrapper
advertises so the model reads a schema it holds no field of. An approved search
posts the parsed fields to the broker, receives the signed grant, and posts
`{tool: "web_search_exa", params: {...approved fields, authorization}}` to
`POST /tools`; the reply text becomes the `role: 'tool'` message that pairs the
`tool_calls` entry, truncated at 8000 characters. The grant lives in that one
request body: `history` retains the proposal and the result, so the transcript
every later request re-sends presents no token, and browser storage holds
neither the grant nor the session secret. A `web_fetch_exa` call runs through
the same route without a grant, because the wrapper enforces the signed Result
ID and its own fetch allowance; the page bounds it by the continuation cap and
by two fetches per turn, the wrapper publishing its per-search allowance in the
ledger row `open_search` writes rather than in `tools/list` or `/props`.

The response shape decides how a refusal reads. `mcp_result_to_response`
(`server-mcp.cpp:196-212`) maps an MCP `isError` result onto an `error` key and
the handler sends it at HTTP 200, so a spent grant, a refused grant, and an
argument outside the claim all arrive as successful HTTP. The page therefore
reads the body before the status: an `error` at any status becomes a tool
message naming what refused, a non-2xx or an unreadable body becomes one naming
the status, and `plain_text_response` is the only success.

`remote/test-web-tools-roundtrip.sh` measures that path end to end without the
appliance. `remote/test-fixtures/fake-llama-tools-server.py` serves both routes
over one `server.py` child on stdio and reproduces the `error`-at-200 mapping;
the broker signs one grant over the approved fields, the exact `{tool, params}`
body the page builds returns the fixture result, and the replay of the same
token comes back as an HTTP 200 whose `error` names the spent grant.

Two claims remain unmeasured. The executor is exercised against the fixture
rather than against llama-server itself: a real child under
`--mcp-servers-config` with the fake provider would measure the composition and
the verbatim `params` forwarding in the binary that serves, and building that
binary needs the appliance. And a server-side hook stays architecturally absent
rather than unimplemented; patching one in would thread a grant through
`server_mcp_tool::invoke` at `server-tools.cpp:1837-1839` or gate the `/tools`
handler, which is a new channel rather than an interception.

## Scope cut: the broker's lifetime is manual

`authorize-broker.py` runs for as long as a caller runs it. The launch chain
starts it nowhere: `qwen-webui-session.sh` arms the probe, the monitor, and the
kernel-hazard watcher, and `qwen-teardown.sh` proves guard absence on exit,
which are the two files an automatic lifetime would change. The chain also
wires `--mcp-servers-config` into no launch, so the broker would presently
outlive and underlie a web router that the appliance never starts; binding the
two lifetimes belongs with the change that starts the router.
