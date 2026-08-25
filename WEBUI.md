# Raven2 Web UI

## Deployment boundary

The browser runs on the SSH client workstation. The laptop runs one
`llama-server` process, the existing runtime monitor, and no graphical client:

```text
local browser -> local 127.0.0.1:8080 -> SSH tunnel
              -> laptop 127.0.0.1:8080 -> guarded llama-server
```

The server fixes `--host 127.0.0.1`, `--cors-origins localhost`, one slot, one
CPU thread, the LOW RADV queue, and strict Vulkan model placement. A generated
API key lives at `$HOME/qwen-webui-state/api.key` with mode 0600. The browser
keeps the entered key in tab-scoped session storage. The tunnel binds only the
client loopback address, so neither HTTP endpoint is exposed to the LAN.

The native Vulkan backend synchronizes each bounded intra-graph submission and
inserts idle time for a 60 percent model duty cycle. LOW queue priority gives
the compositor precedence between submissions, and 32-token microbatches
shorten prompt bursts. The runtime monitor independently terminates the server
on the first aggregate Raven2 busy value above 75 percent.

## Runtime provenance

The laptop does not contain a clone of this repository. Its paths have separate
roles:

- `$HOME/qwen-laptop-setup` is the synchronized deployment mirror;
- `$HOME/src/llama.cpp` is the Git checkout at
  `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`;
- `$HOME/src/llama.cpp/build-qwen-vulkan/bin/llama-server` is the one-job Vulkan
  build produced from that checkout and the retained patches; and
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

Start the guarded 4K profile only when the desktop user is idle:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh start'
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
and the repository's fixed one-slot, 60 percent model-duty policy.

Inspect status and retained log tails:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh status'
```

Stop the server and its dedicated tmux session:

```sh
ssh TARGET '$HOME/qwen-laptop-setup/remote/qwen-webui-control.sh stop'
```

The real 4K Qwen3.5-4B request completed with 3.79 prompt tok/s, 0.677 decode
tok/s, 49.65% mean aggregate GPU busy, and 72% maximum aggregate GPU busy. The
16-token response ended during hidden reasoning and produced no user-visible
answer. The profile proves the guarded transport but remains too slow for daily
interactive use.

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
