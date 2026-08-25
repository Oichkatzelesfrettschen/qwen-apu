# Raven2 Web UI

## Deployment boundary

The laptop runs one `llama-server` process, the existing runtime monitor, and
no graphical client. Two deployments differ only in the listener address.

An SSH tunnel keeps both endpoints on loopback and serves the operator alone:

```text
local browser -> local 127.0.0.1:8080 -> SSH tunnel
              -> laptop 127.0.0.1:8080 -> guarded llama-server
```

`QWEN_BIND_HOST=0.0.0.0` serves every browser on the network directly:

```text
any browser on the LAN -> hp14-dk1xxx.local:8080 -> guarded llama-server
```

The server fixes one slot, one CPU thread, the LOW RADV queue, and strict
Vulkan model placement. `QWEN_BIND_HOST` sets the listener and defaults to
`127.0.0.1`; `QWEN_CORS_ORIGINS` sets the allowed origins and defaults to
`localhost`. A generated API key lives at `$HOME/qwen-webui-state/api.key` with
mode 0600, and the browser keeps the entered key in tab-scoped session storage.
A loopback listener reaches only local accounts, so the key is optional there.
Any wider bind is refused without one, because a single slot lets an
unauthenticated caller on the network occupy the GPU indefinitely.

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

`QWEN_LATENCY_MODE` selects what a missed deadline does. `terminate` stops the
server on the first late frame and is the default for unattended serving.
`observe` counts the same breaches and lets the run continue. A measurement run
needs `observe`: the retained idle-serving session recorded a 520 us mean fence
across 78,177 samples with exactly one sample at 20,976 us, so a ladder that
saturates the GPU for the better part of an hour would otherwise be ended by a
single outlier and return no timing at all. A fence that returns anything other
than success ends the run in both modes, because that is a device fault rather
than a scheduling delay.

The retained `paced-60` control inserts duty-cycle sleeps and retains the 75%
aggregate busy stop. The `low-async` experiment uses the same 20 ms MEDIUM
service deadline as the serialized profile so it isolates the throughput and
service-latency cost of multiple in-flight LOW jobs.

## Runtime provenance

The laptop does not contain a clone of this repository. Its paths have separate
roles:

- `$HOME/qwen-laptop-setup` is the synchronized deployment mirror;
- `$HOME/src/llama.cpp` is the earlier Git checkout at
  `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`;
- `$HOME/src/llama.cpp-qwen-apu` is a separate checkout at the same commit with
  the four replayed qwen-apu patches;
- `$HOME/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server` is the
  one-job Vulkan build produced from the isolated patched checkout; and
- `$HOME/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf` is the external,
  hash-pinned model.

The pinned binary omits embedded SvelteKit assets but retains `--path`, `--ui`,
OpenAI-compatible routes, API-key files, Web UI configuration, and static-file
serving. `webui/index.html` is an APU-specific adaptation of the MIT-licensed
qwen-lab single-file diagnostic page. It uses the loaded server's `/tokenize`
route, accepts text attachments, exposes reasoning separately, and prefers
server-reported prefill and decode timing. It contains no external resources
and starts no second process on the laptop.

## Start and connect

Replace `TARGET` with the SSH host alias or address.

Start the priority-first 4K profile only when the desktop user is idle:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh start'
```

Run the retained paced control explicitly:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh start paced-60'
```

Read the API key through SSH and enter it in the page:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh key'
```

Keep the tunnel command running on the client workstation:

```sh
./remote/connect-qwen-webui.sh TARGET 8080 8080
```

Open `http://127.0.0.1:8080`. The initial profile uses the measured 4K
allocation rung, a 4,096 MiB Vulkan preflight gate, a 512-token response budget,
and the repository's one-slot `low-serialized` policy.

Inspect status and retained log tails:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh status'
```

Stop the server and its dedicated tmux session:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh stop'
```

The retained `paced-60` transport request completed with 3.79 prompt tok/s and
0.677 decode tok/s. The equal-request priority comparison then measured 11.437
prompt tok/s and 1.316 decode tok/s under `low-serialized`. The admitted
16-node `low-async` experiment measured 14.103 prompt tok/s and 2.713 decode
tok/s while its independent MEDIUM queue stayed below 11.185 ms. The 32-node
async arm is rejected because one fence reached 20.017 ms. The serialized
profile remains the default until the 16-node arm passes an external
desktop-input oracle and a longer thermal soak. Full evidence and percentile
calculations are in
`evidence/benchmarks/qwen35-4b-vulkan-priority-comparison.md`.

## UI selection

| UI | Fit for this APU deployment | Decision |
| --- | --- | --- |
| llama.cpp embedded Web UI | Same-process UI with the widest upstream-tested llama.cpp feature coverage | Preferred after a separately hash-pinned UI-enabled rebuild |
| qwen-apu static panel | Same-process, text-only, exact tokenizer counts, server timing, no remote GUI | Selected for the first guarded test |
| Open WebUI | Strong history, RAG, RBAC, PWA, and OpenAI-compatible integration | Run later on the client workstation and connect through SSH |
| LibreChat | Strong multi-provider, multi-user, MCP, and authentication surface | Excess service and database scope for a one-slot laptop test |
| LobeHub | Polished multi-provider self-hosted application | Excess container and database scope for the first test |

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
