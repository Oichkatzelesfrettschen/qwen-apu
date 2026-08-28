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
approval path against the same broker, so the mechanism is exercised and the
pinned UI carries the outline alone.

## Unverified: which side dispatches the tool call

Which process executes an approved `web_search_exa` is unestablished from this
tree. llama-server spawns the MCP child itself under `--mcp-servers-config`,
which would execute the call server-side and leave the browser no seam to
inject an argument into; a client-declared tool in the request body reaches the
client for dispatch instead. Nothing in this repository wires
`--mcp-servers-config` into the launch chain, and the server source is on the
appliance, so both accounts stay open. `src/llama.cpp-qwen-apu/tools/server/`
settles it, and the fallback UI takes the client-declared path: it puts the web
tool schemas in `body.tools` itself, which is also what makes the per-turn Web
toggle a boundary rather than a request. A server-side dispatch would move the
injection point into llama-server and leave the dialog, the broker, and the
grant unchanged.
