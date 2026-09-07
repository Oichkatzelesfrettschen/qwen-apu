# Raven2 Web UI

## Deployment boundary

The laptop runs one `llama-server` process, the existing runtime monitor, and
no graphical client. Two deployments differ only in the listener address.

The laptop is the whole system. `http://127.0.0.1:8080` is the canonical
address, and the model, the projector, the static UI, and the guards all live
on the machine running the browser, so the appliance answers with the Wi-Fi
off. `qwen-launch.sh` binds loopback by default. The tunnel and the LAN
listener below are conveniences for reaching that appliance from elsewhere,
and neither is on the path a local reader uses.

An SSH tunnel keeps both endpoints on loopback and serves the operator alone:

```text
local browser -> local 127.0.0.1:8080 -> SSH tunnel
              -> laptop 127.0.0.1:8080 -> guarded llama-server
```

`QWEN_BIND_HOST=0.0.0.0` serves every browser on the network directly:

```text
any browser on the LAN -> qwen-laptop:8080 -> guarded llama-server
```

The server fixes one slot, one CPU thread, the LOW RADV queue, and strict
Vulkan model placement. `QWEN_BIND_HOST` sets the listener and defaults to
`127.0.0.1`; `QWEN_CORS_ORIGINS` sets the allowed origins and defaults to
`localhost`. The server runs without an API key at every bind address. A key
authenticates a caller on a shared network and withholds nothing the model
itself protects, so a local model on a trusted network serves the page
directly. `QWEN_REQUIRE_API_KEY=1` mints one at
`$HOME/qwen-webui-state/api.key` with mode 0600 and makes llama-server demand
it; the browser then keeps the entered key in tab-scoped session storage. The
page requests `/v1/models` first, so it reaches a keyless server and prompts
only when a server answers 401. Each roster selection then requests the encoded
`/props?model=<id>` endpoint and tokenizes attachments through the same model
id. A model change marks both values pending until matching responses return.

With `--parallel 1` the slot serves one request at a time. A second person
waits for the first to finish, which at a 24K prompt is minutes. Raising
`--parallel` divides the KV cache between slots and lowers the context each
person gets, so the single slot stands.

The default `low-serialized` profile synchronizes each bounded intra-graph
submission without inserting duty-cycle sleeps. LOW is the lowest distinct
amdgpu scheduler class on Linux 7.0, and the one-job queue depth exposes a
scheduling boundary after each short submission. That priority is what yields
the desktop the machine: the desktop's own queue outranks inference and
preempts it. A MEDIUM-priority graphics-family probe submits every 16 ms and
measures whether the yielding holds, requiring fence service within 20 ms.

`QWEN_LATENCY_MODE` selects what a missed deadline does. `observe`, the
default, counts breaches and keeps serving. `terminate` stops the server on the
first late frame and is retained for deliberately strict runs. The 24K ladder
measured the distribution that sets this default: fence service reached 21,302
us at p99.9 against the 20,000 us deadline, placing the deadline near the
99.56th percentile, so a late frame arrives roughly every 3.6 seconds under
load and `terminate` ends any sustained session within seconds. A fence that
returns anything other than success ends the run in both modes, because that is
a device fault rather than a scheduling delay.

Junction temperature is reported, not enforced. The SMU throttles the DPM clock
ladder and the hardware carries its own shutdown above anything the one-second
sampler observes, so crossing 90,000 millicelsius writes one
`temperature_report` line and the session continues. The memory-reserve and
swap-in aborts remain, because those bound what inference takes from the
desktop rather than from the silicon.

The retained `paced-60` control inserts duty-cycle sleeps and retains the 75%
aggregate busy stop. The `low-async` experiment uses the same 20 ms MEDIUM
service deadline as the serialized profile so it isolates the throughput and
service-latency cost of multiple in-flight LOW jobs.

## Runtime provenance

The laptop runs from its own checkout of this repository, and every generated
byte lives in one declared runtime root beside it. `remote/qwen-home.sh` names
that root as `QWEN_HOME`, defaulting to `.runtime` directly under the tree that
holds `remote/`, and `print NAME` answers with any location derived from it:

```sh
remote/qwen-home.sh print qwen_home qwen_home_models qwen_home_llama_source
```

The llama.cpp source trees, the built binaries, the hash-pinned checkpoints,
the deployment bundles, and the session state all resolve beneath that one
root, so the checkout is the whole declaration and `make bootstrap` expands it.
A served binary reaches the device through an activated deployment bundle
rather than through a build directory a reader has to name.

The pinned binary omits embedded SvelteKit assets but retains `--path`, `--ui`,
OpenAI-compatible routes, API-key files, Web UI configuration, and static-file
serving. `webui/index.html` is an APU-specific adaptation of the MIT-licensed
qwen-lab single-file diagnostic page. It uses the loaded server's `/tokenize`
route, accepts text attachments, exposes reasoning separately, and prefers
server-reported prefill and decode timing. It contains no external resources
and starts no second process on the laptop. `qwen-webui-control.sh` serves
the pinned llama UI build under `webui-llama-ui/` when that directory holds
an `index.html`, and `qwen-web-launch.sh` sets `QWEN_STATIC_PATH` to `webui/`
because the web path's executor is this page: it scopes `GET /tools` by model
and posts the routing key beside the tool, which the pinned build does not.

## Start and connect

Replace `TARGET` with the SSH host alias or address and `CHECKOUT` with the
repository checkout path on that host; the scripts resolve the runtime root
from that tree, so no second path is named. `qwen-webui-control.sh`
runs the session inside the `qwen-webui` tmux session on the `qwen-runtime`
socket, so it outlives the SSH connection that started it.

Serve the network at the 24,576 token ceiling:

```sh
ssh TARGET 'QWEN_BIND_HOST=0.0.0.0 CHECKOUT/remote/qwen-webui-control.sh start'
```

Serve only the operator over loopback, for the SSH tunnel deployment:

```sh
ssh TARGET 'CHECKOUT/remote/qwen-webui-control.sh start'
```

`start` defaults to 24,576 tokens against a 4,608 MiB Vulkan preflight gate,
`observe` latency mode, port 8080, and the one-slot `low-serialized` policy.
`QWEN_CONTEXT_SIZE`, `QWEN_REQUIRED_VULKAN_MIB`, `QWEN_SERVER_PORT`, and
`QWEN_LATENCY_MODE` override each in turn. Run the retained paced control by
naming it: `qwen-webui-control.sh start paced-60`.

Read the API key and enter it in the page:

```sh
ssh TARGET 'CHECKOUT/remote/qwen-webui-control.sh key'
```

A LAN reader opens `http://qwen-laptop:8080` directly. A loopback
deployment instead keeps a tunnel running on the client workstation and opens
`http://127.0.0.1:8080`. The helper forwards the approval broker on port 8571
beside the server:

```sh
./remote/connect-qwen-webui.sh TARGET 8080 8080
```

When the browser-facing server port differs from the remote server port, bind
the broker to that exact browser origin before starting the remote session:

```sh
ssh TARGET 'QWEN_WEB_BROKER_ORIGIN=http://127.0.0.1:18080 QWEN_WEB_PROFILE=web-qwen38-4b-distill QWEN_WEB_PROVIDER=searxng CHECKOUT/remote/qwen-web-launch.sh low-serialized'
./remote/connect-qwen-webui.sh TARGET 18080 8080
```

`QWEN_WEB_BROKER_LOCAL_PORT` and `QWEN_WEB_BROKER_PORT` override the local and
remote broker tunnel endpoints together with the matching Web UI broker
configuration.

Inspect status and retained log tails:

```sh
ssh TARGET 'CHECKOUT/remote/qwen-webui-control.sh status'
```

Stop the server and its tmux session:

```sh
ssh TARGET 'CHECKOUT/remote/qwen-webui-control.sh stop'
```

## Measured throughput

The prefill depth ladder served 4,096, 8,192, 16,384, and 24,000 token prompts
from one `low-serialized` load at 12.438, 10.767, 11.347, and 9.979 prompt
tok/s, decoding at 1.195, 1.199, 1.120, and 1.052 tok/s. Prefill is not
monotonic in depth, so those are four measured points rather than a curve.
Every rung retrieved the value planted near the start of its prompt. Evidence
is in `evidence/benchmarks/qwen35-4b-depth-ladder-24k/`.

The earlier equal-request priority comparison measured 11.437 prompt tok/s and
1.316 decode tok/s under `low-serialized`, against 14.103 and 2.713 for the
admitted 16-node `low-async` experiment and 3.79 and 0.677 for the retained
`paced-60` transport request. The 32-node async arm is rejected because one
fence reached 20.017 ms. The serialized profile remains the default until the
16-node arm passes an external desktop-input oracle and a longer thermal soak.
Full evidence and percentile calculations are in
`evidence/benchmarks/qwen35-4b-vulkan-priority-comparison.md`.

## UI selection

| UI | Fit for this APU deployment | Decision |
| --- | --- | --- |
| llama.cpp embedded Web UI | Same-process UI with the widest upstream-tested llama.cpp feature coverage | Preferred after a separately hash-pinned UI-enabled rebuild |
| qwen-apu static panel | Same-process, text-only, exact tokenizer counts, server timing, no remote GUI | Selected for the first guarded test |
| Open WebUI | Strong history, RAG, RBAC, PWA, and OpenAI-compatible integration | Run later on the client workstation and connect through SSH |
| LibreChat | Strong multi-provider, multi-user, MCP, and authentication surface | Excess service and database scope for a one-slot laptop test |
| LobeHub | Polished multi-provider self-hosted application | Excess container and database scope for the first test |

The two UIs are two launches of one binary rather than two routes of one
listener. `server_http_context::init` mounts a `--path` directory at
`api_prefix + "/"` where `public_path` carries a value
(`tools/server/server-http.cpp:333-335`) and registers the compiled-in llama.cpp
UI under the same prefix in its else branch (`:339-427`), and `--api-prefix`
supplies one value to whichever branch runs (`common/arg.cpp:3352-3356`). Router
mode leaves that alone, since `ctx_http.init(params)` runs ahead of the router
branch (`tools/server/server.cpp:173` against `:188-232`) and
`server-models.cpp` registers no UI route. `qwen-web-launch.sh` passes
`--path`, so it serves this page; `qwen-launch.sh` leaves it unset, so the same
address and port answer the llama.cpp UI. The page's `llama.cpp UI` tab states
that and links the listener root rather than a route nothing answers.

The static panel carries the history the table credits to Open WebUI. A
conversation is a record in IndexedDB, in localStorage where IndexedDB refuses,
and in memory where both do, addressed by a `#/c/<id>` route and listed in a
side panel that opens, renames, and deletes one. What is written is a
projection -- role, content, the served model id each assistant message names in
its badge, the tool call ids and arguments the transcript re-sends, and an
artifact's digest, provenance route, seed, and geometry -- so a broker grant,
the session secret, and the API key reach no store and a restored image is
refetched by digest over the artifact listener's own credentialed route.

Primary sources:

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/open-webui/open-webui
- https://github.com/danny-avila/LibreChat
- https://github.com/lobehub/lobehub

The primary-source audit on 2026-08-24 found llama.cpp server support for
localhost binding, static paths, API-key files, OpenAI-compatible chat and
responses routes, and embedded Web UI configuration. Open WebUI v0.11.0
supports OpenAI-compatible backends and offline self-hosting. LibreChat and
LobeHub provide broader multi-user or multi-provider application stacks.
