# Qwen APU

Local chat, image understanding, web retrieval, and image generation on a small
AMD laptop, powered by **llama.cpp and Vulkan**.

The target machine is an Athlon Silver 3050U: two CPU cores, two Vega compute
units, and 29 GiB of shared memory. The project keeps inference on the laptop
and provides a browser interface with model selection, saved conversations,
image attachments, and approval controls for tools. Web retrieval needs an
Internet connection; installed language and image models run locally.

**Start here:** [User guide](docs/USER-GUIDE.md) ·
[Installation](docs/INSTALL.md) · [Operator reference](WEBUI.md)
· [Models and tools](docs/MODELS-AND-TOOLS.md)

![Chat page with model picker, tool toggles, saved conversations, and attachment control](docs/images/chat-overview.png)

Actual appliance page in Firefox. Credential and service-address fields are
hidden for publication; the screenshot uses an empty disposable history.

## What you can do

| Task | How to use it | Practical limit |
| --- | --- | --- |
| Chat and coding | Choose a text model and send a message. | Larger models respond more slowly on this hardware. |
| Understand an image | Choose a vision model, attach an image, and ask about it. | Recognition works, but small text, counts, and measurements need checking. |
| Search or read the web | Choose a web-enabled model, enable **web**, and approve the requested operation. | Retrieval can fail; search snippets are different from a fetched page. |
| Read Wikipedia | Ask the web-enabled model to retrieve the specific Wikipedia source. | Wikipedia uses the web retrieval path; a failed fetch does not establish a sourced answer. |
| Generate an image | Enable **image**, describe the result, and inspect the approval dialog. | The admitted SDXS profile produces 512-pixel images with limited visual fidelity. |
| Review a generated image | Use the image card's review action. | A completed review can still make an incorrect visual judgment. |
| Keep conversations | Use the sidebar to reopen saved chats. | History belongs to that browser profile and origin; image pixels are omitted. |

The custom **Chat** page coordinates approvals, tools, and saved history.
The **llama.cpp UI** tab exposes the bundled upstream interface; its controls
and tool integration differ. Use Chat for the combined workflows in the guide.

## Use an installed laptop

The appliance is one Python supervisor that owns the router, the approval
gateway, the image service, and the search instance, records them in
`state/appliance.json` under the runtime root, and ends them together. Three
words drive it:

```sh
qwen up         # derive the launch, detach it, print the addresses it serves
qwen status     # the record the running appliance publishes
qwen down       # stop it and prove every recorded identity absent
qwen restart    # down, then up on the same derived defaults
```

`up` returns when the record reads `ready`, which is the router reporting a
served model rather than a socket answering, and prints what a browser opens:

```text
state=ready
home http://<lan address>:42069
chat http://<lan address>:42072
image http://<lan address>:42073
serving=qwen38-2b-distill
deployment=python-prod-32k
```

Two of those fields are facts about the machine rather than decisions, so `up`
reads them off the machine: the address comes from the interface carrying the
default route, so a new DHCP lease leaves the command unchanged, and the
documentation root the file lane serves comes from the checkout. `--local`
serves this machine alone, `--bind-host ADDRESS` publishes one rather than
deriving it, and `--no-lan-open` asks every peer on the network for a pairing
code. A machine with no default route refuses the launch and names both flags
rather than publishing a page at an address no browser reaches.

`qwen` is a four-verb view of one command. `qwen-apu appliance serve` is the
whole statement of a launch, which `up` composes and every other operation
keeps its own spelling of:

```sh
qwen-apu appliance serve --router --both --bind-host <lan address> \
    --port 8080 --gateway-port 42069 --llama-ui-port 42072 \
    --image-profile image-sdxs-512-a --web-profile web-open
```

That form holds the terminal it runs in. `up` detaches the same argv as a
session leader with its output in `logs/appliance.log`, so the shell that
started it closes without reaching it, and no unit file, crontab entry, or
login hook is involved: the appliance starts and stops through these commands
alone, and a reboot leaves the laptop with nothing listening.

### Put it on the operator's own PATH

`qwen` is a console script of the installed package, so one symlink from a
directory already on the operator's PATH reaches it and no shell profile
changes:

```sh
mkdir -p ~/.local/bin
ln -sfn ~/Github/qwen-apu/.runtime/venv/bin/qwen ~/.local/bin/qwen
command -v qwen
```

The symlink resolves the venv interpreter through the script's own absolute
shebang, so `qwen` works from any directory and needs no activation. A profile
that leaves `~/.local/bin` off PATH takes one line, `PATH="$HOME/.local/bin:$PATH"`.
The account that runs these commands owns the appliance's processes: teardown
signals the recorded pids, and a pid is signalled by the user that started it.

One flag states which peers a launch serves:

- `--local` binds this machine alone and admits it, so a browser on the
  laptop opens `http://127.0.0.1:42069/` with nothing to enter. The kernel
  decides a loopback peer's address, so the caller is a process on the
  appliance, which already reads the state directory the pairing code lives
  in.
- `--lan` binds the address `--bind-host` names and pairs every peer.
- `--both` binds each, so the laptop's own browser needs nothing and a peer
  on the network pairs once. Both addresses share one port and answer the
  same routes.

`--lan-open` adds the other half: it serves the network this appliance sits
on with no pairing code, so a browser anywhere on it opens the page and
chats. Bare, it derives the network of the interface holding the bind
address, so the prefix is the one the machine has; a CIDR block states one
instead and may repeat. A derivation that finds no interface ends the launch
rather than guessing at a boundary.

```sh
qwen up                                   # both, lan-open, all three listeners
qwen up --no-lan-open                     # the same launch, every peer pairing
qwen-apu appliance serve --router --both --lan-open --bind-host <lan address> \
    --llama-ui-port --image-ui-port ...   # the same launch, stated in full
```

That is the operator's explicit decision, and it gives up exactly one thing:
a peer on that network chats and reads without presenting a code. Everything
else still stands. The Host set admits the loopback names and that one
address; the Origin allowlist admits the addresses this launch binds; a peer
outside the named networks still pairs; and every network-reaching and
device-reaching call still takes one human approval in the rail and spends a
single-use signed grant.

Open `http://<lan address>:42069/` in a browser. A peer on the network is
asked for a pairing code once: `qwen status` on the laptop prints it, the
first browser that presents it receives an HttpOnly session cookie, and the
code is spent. There is no key to keep or paste after that; a restart mints a
new code. One pairing admits both ports, because the cookie is scoped to the
host rather than to the port.

The served pages hold no bearer token. llama.cpp's own page offers an API key
field, and this appliance needs nothing in it: the router listens on loopback
without a key and the gateway carries the credential as that cookie. A page
that asks for a key is a page whose session is absent, which pairing answers.

- `42069` is the landing page: two choices, Chat and Image Generation, each
  linking to its own address. It holds nothing else at rest, and a tool call
  waiting for an approval appears on it until it is decided.
- `42072` is Chat, llama.cpp's own page, with its model picker, attachments,
  reasoning display, and saved conversations.
- `42073` is Image, this appliance's generator, which mounts the same routes
  the landing page does so its grant and its artifact reads stay same-origin.

The previous single-page client stays at `42069/legacy/`.

The appliance states its own graphics operating point at every launch and
prints what the part delivered, because the firmware reads a decode as a
low-use workload and clocks down for it. One privileged action enables that
once per machine:

```sh
sudo -v && remote/install-amdgpu-clock-access.sh install
```

It installs a udev rule handing the three amdgpu clock attributes to the
`video` group, so every later launch pins its states with no privilege and a
reboot re-applies the access before anything serves. Without it the appliance
still serves and its `graphics_state=` line says it is running at whatever the
governor chose.

Readiness reports missing runtime inputs before anything listens: the weights
digest, the signing key, and the activated deployment bundle each refuse a
launch on their own. An existing installation needs no rebuild per session.

The shell-script launch chain, `remote/qwen-lan-launch.sh` and
`remote/qwen-teardown.sh`, stays in the tree as the recovery path and is
described in [WEBUI.md](WEBUI.md). Teardown preserves downloaded models,
installed environments, generated artifacts, and saved conversations.
**Uninstall and purge are separate removal operations, not everyday shutdown
commands.**

For a fresh installation, follow [Installation](docs/INSTALL.md). Bootstrap
creates the directory layout; the install and build steps supply the actual
models, dependencies, and deployment.

## Choose a model

Start with the 2B distill model for ordinary text. Try the 4B distill when you
need stronger formatting or reasoning and can wait longer. Choose an explicitly
vision-capable entry for attachments, and a web-enabled entry for retrieval.
The running picker's feature information is the source for available actions;
installing a model file alone does not qualify every feature.

The router normally loads one model at a time. Switching from chat to image
review can therefore take time. A slow first response after a switch can include
model loading as well as prompt processing.

## Files stay with the installation

Generated appliance files live under **`.runtime/`** in the checkout by default.
`QWEN_HOME` selects another declared runtime root. Models, deployments, service
state, caches, environments, and results live beneath that root. Browser history
is the exception: it lives in the browser profile for the page's origin.

The serving search environment is managed at
`$QWEN_HOME/opt/searxng/venv`; launchers select its interpreter automatically.
There is no requirement to activate one global `.venv` before chatting.
The model and image engines are native executables. Development tools have
separate environments and are not required just to start an installed service.

Inference runs as the ordinary user. Sudo supports declared machine-control
and restoration operations; it is not needed to lower a process to nice 19.
The installed sudo authentication-cache policy is an operator choice and does
not make the inference process root.

## Current limits and deployment status

Attachment ownership, saved-history deletion, image-omission notices, qualitative
vision recognition, image generation, and reviewer completion have passed live
checks. Recognition accuracy and generated-image quality remain imperfect.
A retained Wikipedia attempt failed required retrieval and produced the honest
incomplete-source result. A separate `docs.python.org` search and fetch produced
a grounded answer through `web-open`; the success does not reclassify the
Wikipedia result or establish general source availability.

The source includes explicit incomplete notices after failed web retrieval and
application-owned image controls. The compatibility correction passed CI and the updated page is deployed.
Remote Firefox has confirmed the explicit incomplete outcome after failed
required retrieval. A mixed Wikipedia-to-image sequence then completed one
image call: the verified card remained authoritative and a fabricated URL in
model prose stayed labeled unverified. Generated-image prose can remain
unreliable; Open, Download, Review, and Remove are application-owned controls.
The bounded record is
[`evidence/ui-tool-qualification-20260909/`](evidence/ui-tool-qualification-20260909/).
A separately authorized image-quality successor produced one fox image and one
review, then stopped when the broker refused the cube row's second outstanding
image grant. The exact-text row remained unrun. The bounded quality and
reviewer-correctness result is
[`evidence/image-quality-successor-broker-grant-stop/`](evidence/image-quality-successor-broker-grant-stop/).
A merged change alone does not change the laptop's running page.

The serving bundle and inference executable remain fixed during this UI work.
Q8 timing remains held independently of product qualification: calibration arm
`09-P` measured `1,038,085 ns` across its full 748-row sampler denominator,
above the registered `1,000,000 ns` limit. The unchanged calibration and
candidate timing remain withheld until a registered input changes. The retained
analysis is
[`evidence/q8-attribution/calibration-20260908/`](evidence/q8-attribution/calibration-20260908/).
Historical
throughput figures are observations from particular runs, not promised response
rates for a busy laptop.

Authenticated HTTP controls access but does not encrypt traffic. Use a trusted
connection or an operator-configured encrypted transport. Browser credential
persistence and transport hardening remain separate work; this README does not
claim those changes have shipped.

## For maintainers

- [User guide](docs/USER-GUIDE.md): everyday workflows and troubleshooting.
- [Models and tools](docs/MODELS-AND-TOOLS.md): installed weights, live roster, validation, and guarded capabilities.
- [Installation requirements](docs/INSTALL.md): dependencies and provisioning.
- [Web UI operations](WEBUI.md): serving and deployment controls.
- [Technical background](docs/TECHNICAL-BACKGROUND.md): retained historical tables and analysis.
- [Evidence](evidence/): measurements, methods, and limitations.
- [Agent guide](AGENTS.md): repository rules and hardware constraints.

`static/` contains the shell and the legacy page, `src/qwen_apu/` the appliance,
`remote/` the shell-script services and measurement code,
and `patches/` contains the pinned llama.cpp changes. Model weights and private
runtime records stay outside Git. Use the existing staging and deployment path
to update an appliance; editing the workstation checkout does not deploy it.
