# The schema-bound prefix checkpoint's hit rate

`evidence/tool-prefix-checkpoint/README.md` reads
`patches/llama-server-prefix-checkpoint.patch` from source and states a
measurement design that has not run. This directory holds the workstation half
of that design: `remote/measure-prefix-checkpoint-hits.sh` drives the scripted
request sequence against a served router and reads whether the pin hit from
the server's own log, and `remote/summarize-prefix-checkpoint-hits.py` turns
the resulting ledger into a hit-rate table and a verdict over the five claims
the design exists to check. Both are proved against
`remote/test-fixtures/fake-prefix-checkpoint-server.py`, a fixture that
reproduces the patch's admission rule at the level the harness reads it --
capture on the first eligible request, restore on a reproduced head, neither on
a divergent one -- and both are unrun against the patched server itself, since
the laptop stays off-limits to this work.

## What the harness reads, and from where

Every request goes to `POST /v1/chat/completions` on the router origin the
caller names, except the `template_change` phase's one request, which goes to
`POST /completion` instead. Four fields come from the response body's own
`timings` object, the same object `run-prefill-ladder.sh`'s request client
already requires whole: `prompt_n` is how many prompt tokens the request was
charged, `prompt_ms` is the wall time the server's own instrument attributes
to the fill, and both are required present and finite or the arm fails with
`missing_timings`, since a rate of nothing pairs as a measurement the way it
does in the ladder.

Two more fields come from the server's own log, read as the exact bytes
appended between the request leaving and the reply returning -- the window
`server-context.cpp`'s call sites and `server-prefix-checkpoint.h` would print
into, at the two lines the patch adds:

```
restored prefix checkpoint, n_past = %d, size = %.3f MiB, took %.2f ms, key = %s
captured prefix checkpoint, n_tokens = %d, size = %.3f MiB, took %.2f ms, key = %s
```

A `restored` line inside a request's own window is a hit; a `captured` line is
the pinning event, which only the first eligible request of a process ever
produces; neither line is a miss, whether the miss is a divergent head or a
raw-route request the mechanism never sees. The `size = ... MiB` field is the
memory the checkpoint holds, the `took ... ms` field is the operation's own
cost, and the `key = ...` field is the server's own identity for the pinned
prefix, read back verbatim rather than recomputed, since the harness has no
access to the model, template, runtime, and build fields that make up the
real key and states only what it sent, not what the server derived from it.

`GET /slots` (or `/metrics`, named by
`QWEN_PREFIX_CHECKPOINT_HITS_SLOTS_ROUTE`) is fetched once per request and
retained verbatim under each request's own directory. Neither route's schema
is pinned anywhere in this tree, so nothing beyond "the route answered" is
asserted from it; a caller who confirms which fields a served appliance's
`/slots` actually carries can extend the reader once that is established
rather than guessed.

`lifetime_s` -- the child process's own age -- is read from `/proc/PID/stat`
and `/proc/uptime` exactly the way `qwen-teardown.sh` reads a guarded child's
identity: field 22 of `/proc/PID/stat` (field 20 after the `sed` that strips
the `pid (comm) ` prefix the way every other reader of that file in this
repository strips it) is the process's start time in clock ticks since boot,
`getconf CLK_TCK` is the ticks-per-second divisor, and `/proc/uptime`'s first
field is the machine's own uptime; the difference is the process age in
seconds. It is read only where `QWEN_PREFIX_CHECKPOINT_HITS_SERVER_PID` names
a PID, since the harness has no other way to learn which process is serving
the router origin it was pointed at -- a router runs a section's own child
under a PID the harness is never handed by the API -- and every row reads
`lifetime_s` `-` otherwise rather than a value nothing produced.

The "avoided prompt time" is a comparison against the run's own cold arm
rather than an absolute figure, the same discipline `run-prefill-ladder.sh`
applies to a rate: the first stable-phase conversation is the baseline, every
later request's `avoided_prompt_tokens` and `avoided_prompt_ms` are that
baseline's `prompt_n` and `prompt_ms` minus its own, and every stable-phase
user message is built to the same fixed word count so the difference is
readable as the head's own reuse rather than as two differently sized
requests. A hit should report an avoided count near the head's own token
count; a miss should report one near zero, since nothing was reused; the
summarizer states neither prediction as a formula, so the reader's own eyes
are what confirm the shape, and `evidence/prefix-checkpoint-hits/` retains no
run where they have.

## The checkpoint identity the record binds

The task the retained README already states: bind the checkpoint identity the
patch defines into the record, so an invalidation on schema or template
change is a checked outcome rather than an assumption. The server's own key
covers five fields the harness cannot see from outside one process --
`model`, `template`, `runtime`, `build`, and the two token digests -- so the
harness computes its own identity instead: `identity_sha256` is the SHA-256
of the system prompt joined to the canonicalized JSON of the tool-schema
array the request carried, over `\x00` as the join byte. Two requests sharing
this digest sent the same rendering input; two that differ sent a different
one. The check is then read against the server's own log rather than assumed
from the digest alone: a schema-change or template-change request is
confirmed invalidating only where its own log window carries neither a
`restored` nor a `captured` line, and a recovery request is confirmed
surviving only where it restores under the exact key the run's own capture
line named, not merely under any key. `remote/summarize-prefix-checkpoint-hits.py`
states both as `refuted` rather than `confirmed` where the log disagrees with
the identity story, which is the outcome a leaking mechanism would produce.

## The five checks, and their falsifiers

1. **`stable_reuse`.** The cold conversation captures and every later
   stable-phase conversation restores under the same key. *Falsifier:* the
   cold conversation itself restores (case: the process was not actually
   fresh when this run's first request landed, so it inherited a foreign
   pin -- `evidence/tool-prefix-checkpoint/README.md`'s own falsifier for arm
   ordering), the cold conversation captures nothing, or a later conversation
   fails to restore or restores under a different key.
2. **`schema_invalidation`.** The `schema_change` request, under the altered
   tool-schema set, neither restores nor recaptures. *Falsifier:* it restores
   (the `covers()` token comparison accepted a divergent head) or it captures
   (the fill-once gate is not exact and a second capture ran inside one
   process, which is `evidence/tool-prefix-checkpoint/README.md`'s own listed
   falsifier for that gate).
3. **`recovery_after_schema_change`.** The request immediately after the
   schema change, sharing the original system prompt and tool-schema set,
   restores under the pin's original key. *Falsifier:* it misses, or it
   restores under a different key -- either would mean the schema-change
   request evicted or replaced the pin rather than leaving it standing, which
   contradicts the fill-once design `evidence/tool-prefix-checkpoint/README.md`
   states for it.
4. **`template_invalidation`.** The `template_change` request, sent to
   `/completion` rather than `/v1/chat/completions`, neither restores nor
   recaptures. *Falsifier:* either line appears, which would mean the raw
   route somehow reached the message-span machinery the mechanism depends on,
   contradicting the patch's own admission predicate.
5. **`recovery_after_template_change`.** The same recovery check, run against
   the other disruptor.

A verdict reads `inconclusive` rather than `confirmed` or `refuted` wherever a
phase is absent from the ledger, a required request failed, or fewer than two
stable-phase conversations ran -- there is nothing to compare a lone cold
conversation against. `remote/test-summarize-prefix-checkpoint-hits.py` proves
each of the five checks against a hand-built ledger, including a leaking
schema-change row that must read `refuted` and a too-short stable phase that
must read `inconclusive`, so a change to the verdict logic that would silently
turn either into a false `confirmed` fails there before it ever reaches a
served router.

## What the harness assumes and does not verify

- `/v1/chat/completions`'s non-streaming reply carries a `timings` object the
  way `/completion`'s does. `run-prefill-ladder.sh` reads that object off the
  raw `/completion` route exclusively; this harness is the first reader in
  this tree to require it off the OAI-compatible chat route, and no run
  against the patched server has confirmed the field survives that path.
- The log lines this harness greps are copied verbatim from
  `patches/llama-server-prefix-checkpoint.patch`'s own `SLT_INF` and `SLT_WRN`
  calls, but `SLT_INF` and `SLT_WRN` prepend a slot and task identifier this
  harness's pattern match does not anchor against; a served log carrying two
  slots' interleaved lines inside one request's window would need the harness
  extended to bind a line to its own slot rather than to accept the first
  match, since the appliance runs `--parallel 1` and this gap is invisible
  there but not in a general router section.
- `QWEN_PREFIX_CHECKPOINT` is not one of the environment names
  `remote/qwen-webui-control.sh` forwards across the tmux boundary --
  `forwarded_name` there lists `QWEN_MMPROJ`, `QWEN_SPEC_TYPE`, and the
  `GGML_VK_*` submission variables, and the prefix-checkpoint variable is in
  neither list. Exporting it in the shell that runs `qwen-launch.sh` does
  nothing today; arming it on a served appliance needs either a change to
  that forwarding list (out of scope here: `remote/qwen-webui-control.sh` is
  not an owned file of this work) or the explicit `QWEN_LLAMA_SERVER`
  recovery path that reads no bundle and forwards the whole calling
  environment, the same path `evidence/tool-prefix-checkpoint/README.md`
  names for reaching a candidate build at all. The command block below uses
  that path.
- No arm has run against a device. Every number in this directory's own test
  fixtures is a constant the fixture chose, not a measured megabyte or
  millisecond, so `checkpoint_size_mib`, `operation_ms`, and every
  `prompt_ms` derived rate in a fixture run states the accounting is correct,
  not what a served appliance would report.

## The appliance command

This harness owns no device and takes no Vulkan lease: it drives a router
that is already serving, so the sequence below restores ordinary appliance
service first and runs the harness against it afterward, the reverse order
from `evidence/prefill-ladder/README.md`'s teardown-window command, which
first takes the device for itself.

```sh
rsync -a remote/ eirikr@qwen-laptop:~/qwen-laptop-setup/remote/

ssh eirikr@qwen-laptop
# QWEN_PREFIX_CHECKPOINT does not reach the ordinary launch chain today (see
# the forwarding gap above), so the candidate build is launched through the
# explicit-server recovery path, which forwards the whole calling
# environment and reads no deployment bundle.
QWEN_LLAMA_SERVER=~/builds/CANDIDATE/bin/llama-server \
QWEN_PREFIX_CHECKPOINT=1 \
QWEN_MODEL_PATH=$HOME/models/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf \
QWEN_BIND_HOST=127.0.0.1 \
    ~/qwen-laptop-setup/remote/qwen-launch.sh

# confirm the pin actually armed before spending a request on it
grep -F 'prefix checkpoint is armed by QWEN_PREFIX_CHECKPOINT' \
    ~/qwen-webui-state/server.log
# a launch that logs neither this line nor a refusal line ran an unpatched
# server; a launch that logs a refusal line names the reason on the same line

out=~/evidence/prefix-checkpoint-hits/$(date -u +%Y%m%dT%H%MZ)
mkdir -p "$(dirname "$out")"
~/qwen-laptop-setup/remote/measure-prefix-checkpoint-hits.sh \
    http://127.0.0.1:8080 ~/qwen-webui-state/server.log "$out"
cat "$out/summary.tsv"

~/qwen-laptop-setup/remote/qwen-teardown.sh
```

A router-mode launch serves each section from a distinct child process rather
than the one `~/qwen-webui-state/server.log` the single-model path writes;
this command block targets the single-model path because the child log a
router section writes to is not established anywhere in this tree, and a
caller who finds it can point `SERVER_LOG` there directly without a harness
change -- the ledger's `server_log` field in `inputs.tsv` records exactly the
path a run read.

Class order follows the repository's own: the 2B distill first, the 0.8B
second, the 4B third, and a result becomes a Raven2-wide default only where
the classes agree. Every command above names the 2B; a run against the 0.8B or
the 4B repeats it with `QWEN_MODEL_PATH` changed and a fresh output directory.
