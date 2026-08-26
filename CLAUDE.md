# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`~/AGENTS.md` loads through the user memory and supplies the shared baseline.
This file holds the repository doctrine and wins inside this tree.

## The repository runs on two machines

The Git tree lives on the workstation. The runtime lives on a Raven2 laptop
reached over SSH. `qwen-laptop` stands for that host throughout this
repository, and a working copy substitutes its own name. Editing a script here
changes nothing on the laptop until it is copied:

```sh
rsync -a remote/ eirikr@qwen-laptop:~/qwen-laptop-setup/remote/
```

Every `remote/` script executes from `~/qwen-laptop-setup/remote/` on the
laptop. A change tested without that copy tests the previous revision. Node,
CMake, and any other build toolchain run on the workstation and deliver
artifacts to the laptop, which keeps the two CPU cores for inference and the
desktop.

## Hardware sets every ceiling in this repository

AMD Athlon Silver 3050U, Raven2, two Zen+ cores at 2.3 GHz, two Vega compute
units, 29 GiB of shared DDR4. Measured by `remote/run-placement-sweep.sh`
through `llama-bench`, free of the guarded launch path:

| Placement, Qwen3.5-4B Q4_K_M | prefill tok/s | decode tok/s |
| --- | ---: | ---: |
| All layers on Vulkan | 20.88 | 2.84 |
| 27 of 32 layers on Vulkan | 22.08 | 2.42 |
| CPU only, 2 threads | 16.09 | 2.63 |
| CPU only, 1 thread | 17.17 | 2.02 |

Every tested hybrid placement lost to full Vulkan, and decode rises from the
9-layer minimum through the fully offloaded endpoint. The ladder dips below
CPU-only at its first partial point: a split adds CPU-to-Vulkan synchronization
and activation transfers while both sides draw on the one DDR4 controller, so
the placements share a bandwidth domain instead of combining two.

Sequential host read bandwidth measures 7.97 GB/s on one thread and 15.44 GB/s
on two, while decode moves weights at
roughly 7.8 GB/s, which places the two compute units at the single-thread
figure. The guards cost nothing against this ceiling: 2.86 tok/s unconstrained
against 2.87 tok/s served.

Two decode points fix a linear cost model of 0.158 s per token plus 0.0763 s
per GiB of weights:

| Checkpoint | weights | decode tok/s |
| --- | ---: | ---: |
| Qwen3.8-4B distill Q4_K_M | 2.58 GiB | 3.02 measured |
| Qwen3.5-4B base Q4_K_M | 2.54 GiB | 2.84 measured |
| Qwen3.8-9B distill Q4_K_M | 5.37 GiB | 1.76 measured |
| Qwen3.8-27B UD-Q2_K_XL | 9.15 GiB | 1.17 predicted |

## The launch chain

One command starts the appliance and one ends it. The chain between them
matters because each link adds policy the next link assumes:

```text
qwen-launch.sh            waits for /health, prints reachable addresses
  qwen-webui-control.sh   owns the tmux session, forwards environment
    qwen-webui-session.sh arms probe, monitor, kernel-hazard watcher
      run-qwen-capacity-server.sh
        model-memory-preflight.sh   reports headroom
        qwen-capacity-policy.sh     builds the llama-server argv
          radv-low-priority-env.sh  scrubs env, applies profile, execs
```

Four properties of that chain surprise a reader who meets one file alone.

`radv-low-priority-env.sh` unsets every `GGML_VK_*` variable before its profile
case runs, so an ambient submission setting reaches the server only when the
`custom` profile captures it beforehand. A profile is defined by what it
exports after the scrub: `low-async` exports `GGML_VK_MAX_NODES_PER_SUBMIT=16`
alone, which leaves `GGML_VK_SERIALIZE_SUBMISSIONS` absent rather than zero,
and that absence carries the measured 1.348 to 2.718 decode tok/s difference
against `low-serialized`.

tmux starts a session from its server's environment, so
`qwen-webui-control.sh` forwards variables inside the command string. A
variable exported in the calling shell alone stops at the tmux boundary.

`tmux kill-session` ends the session script without running its EXIT trap, so
`qwen-teardown.sh` records the guard PIDs from `session.status` before calling
`stop`, which rewrites that file. The teardown then proves absence and exits
non-zero on residue.

`model-memory-preflight.sh` reports host and Vulkan headroom and admits every
launch. A load that exceeds the machine fails at once and names its reason.

## Commands

```sh
# Start and stop the appliance (run on the laptop)
~/qwen-laptop-setup/remote/qwen-launch.sh [paced-60|low-serialized|low-async]
~/qwen-laptop-setup/remote/qwen-teardown.sh
~/qwen-laptop-setup/remote/qwen-webui-control.sh status

# Select a checkpoint, a listener, and the inference core
QWEN_MODEL_PATH=$HOME/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf \
QWEN_BIND_HOST=0.0.0.0 QWEN_INFERENCE_CPU=1 \
    ~/qwen-laptop-setup/remote/qwen-launch.sh

# Measurement harnesses, each of which owns its own launch and teardown
remote/compare-model-candidate.sh LABEL MODEL_PATH [PROFILE]
remote/run-placement-sweep.sh [OUTPUT]
remote/reasoning-span-probe.sh OUTPUT_JSON     # against a live server
remote/summarize-probe.sh ~/qwen-webui-state/graphics-latency.log

# Rebuild llama.cpp and the static UI
remote/build-llama-vulkan.sh                   # on the laptop
remote/build-llama-ui.sh                       # Node on the workstation

# Hash-pinned model fetches
remote/download-qwen35-4b-q4km.sh
remote/download-qwen35-4b-mmproj.sh
remote/download-qwen38-4b-distill-q4km.sh
```

Tests are standalone POSIX shell scripts that exit non-zero on failure. Run one
directly:

```sh
remote/test-qwen-runtime-guards.sh
remote/test-radv-low-priority-env.sh
remote/verify-llama-patch-series.sh
```

`remote/test-fixtures/fake-llama-server.sh` stands in for the real server so a
guard test runs without a GPU.

## Models and projectors pair by directory

`qwen-launch.sh` searches for `mmproj-F16.gguf` beside the model file. A
projector encodes images into the embedding space of the checkpoint that
exported it, and a foreign projector of matching dimensions loads cleanly while
placing image tokens where the language model reads nothing, which answers
wrongly rather than failing. Binding the search to the model's own directory
makes a checkpoint published without a projector run text-only.

`empero-ai/Qwen3.8-4B-Distill` distills into the Qwen3.5-4B architecture, so
the pinned build loads it unchanged. It is the text default: it reasons in
43.3% of the base model's tokens, reaches an answer 2.71 times faster across
the five-prompt suite, and its chat template still gates `<think>` on
`chat_template_kwargs.enable_thinking`. It ships text-only, so the vision
profile selects the base checkpoint with its revision-matched projector.
Local math accuracy against the base is untested, and the publisher reports a
gsm8k_cot fall from 0.850 to 0.785 alongside an mmlu CoT rise from 0.354 to
0.553.

GGUF weights stay outside Git because their sizes exceed the LFS per-file
limit. Each download script pins a Hugging Face revision, a byte count, and a
SHA-256, and verifies an existing file in place.

## Evidence discipline

`evidence/` holds the measurements that justify every default, and a default
changes when a measurement moves. State the falsification criterion before
running a probe; when a result deviates from prediction, the deviation is the
finding, and the evidence file records it as such. Several results in this tree
exist because a stated hypothesis failed: submission node count moved decode
3.5% where it was predicted to dominate, and asynchronous Vulkan raised probe
p90 8.6-fold under sustained prefill while leaving chat decode at zero frame
breaches.

`evidence/SHA256SUMS` and `ARTIFACTS.md` fix the retention class of every
surface. Git copies replace the private hostname with `qwen-laptop`, the home
prefix with `$HOME`, and MAC addresses with `<mac>`.

`README.md` predates the async default, the keyless listener, the observational
preflight, and the llama-ui deployment. Prefer this file and `evidence/` where
they disagree.

## Prose and comments

Comments, commit messages, durable docs, thinking, replies in session, and
end-of-session summaries share one voice: direct, declarative, indicative
present tense, artifact as subject.

The voice reaches conversation whole. A reply opens on the finding rather than
on a preamble, states the mechanism before the consequence, and gives each
number its evidence class. Length follows the count of decisive facts, so a
one-fact answer is one or two sentences and a measurement table earns its rows.
A result that contradicts a prediction leads, because the deviation is the
finding; a correction states what is true now and continues, since the
narration of an error costs more than the error. Ceremony, restatement of the
request, and summaries of work about to be described all fall away.

Conversation keeps what its purpose requires. A question the user must answer
is asked plainly, uncertainty is named with its falsifier, and a
recommendation carries the reasoning that would change it. Those are content,
so the voice carries them the same way it carries a register fact.

Write the mechanism first. Name the authority that makes the statement true --
the function, register, spec chapter, environment variable, or measured value
-- then the consequence. The count of distinct decisive facts sets the length;
a sentence that paraphrases another is removed.

State what a thing is and does, and let the positive form carry the absence a
negation would spell out. A binary contrast becomes its positive term. A
stacked absence collapses to the category its members share. A boundary becomes
the restriction it imposes (`loopback only`), the home its content belongs in
(`chronology lives in the commit message`), or the mechanism itself (`the
profile exports one variable, so the rest stay absent`). Each positive form
entails what a negation would state, so the negation stays off the page. A
hard-stop safety or security boundary keeps its prohibition, where that is the
whole content.

Mechanism controls comment length. A single local fact takes one sentence; a
connected relation takes a causal sentence; a short block belongs where the
code depends on a driver rule, a measured quirk, and an observed failure
together. Split when the actor, ownership, phase, evidence class, or invariant
changes. Architecture that persists across a file lives at file scope and the
point of use keeps the local link.

Mark evidence class. Documented behavior takes the plain indicative; behavior
reproduced and undocumented names where it was observed; conjecture is marked
or removed.

Chronology lives in commit messages. Task numbers, phase and wave labels,
session dates, reviewer breadcrumbs, agent names, private hostnames, local
absolute paths, and deictic terms such as `currently` stay out of source
comments. Durable names describe target, mechanism, and outcome.

"Load-bearing" is banned; name the dependency instead -- which value, which
caller, which invariant fails, and what breaks when it changes.

Commit subjects carry a component prefix and a mechanism. The body makes the
invariant, the change, and the evidence reviewable in one to five sentences.
AI participation is disclosed as `Assisted-by: TOOL (MODEL)`, or
`Generated-by:` when AI wrote nearly all of it; `Co-authored-by:` stays
reserved for human co-authors.

## Hard rules

- Checked-in text is emoji-free.
- Straight quotes over curly, `--` over an em dash, `...` over an ellipsis
  glyph. Mathematical operators, Greek letters, arrows, box-drawing, degree and
  micro signs, and accented characters in names stay verbatim.
- Secrets, local absolute paths, and private hostnames stay out of commits.
  `api.key` files stay outside the repository and their contents stay unprinted
  and untransmitted.
- `/etc/sudoers.d/90-qwen-agent` sets `timestamp_type=global` with a 60 minute
  timeout, so one `sudo -v` on the laptop covers the SSH sessions that
  administer it. The user types the password; it stays out of SSH command
  lines, scripts, logs, and project files.
- New files carry no copyright line. Existing upstream headers stay verbatim.
- Scripts are POSIX `sh` with `set -eu`, long descriptive variable names, and a
  usage block that exits 2 on argument error.
- `docker compose` (v2) rather than legacy `docker-compose`.
- `--tools all` grants shell execution and file writing to a prompt-injectable
  model. The read-only set is `read_file,file_glob_search,grep_search`, and a
  tool-enabled server stays off the LAN.
- The service starts and stops through the launch and teardown scripts alone.
  No unit file, crontab entry, or login hook starts it, so a reboot leaves the
  laptop with nothing listening.
