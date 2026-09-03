# The prefill ladder: what a prompt costs before the first token

The served campaigns of this tree read decode. `run-served-binary-ab.sh` runs a
fixed 64-token generation and promotes on tok/s, `measure-served-decode.sh`
retains that window, and the submission profile the appliance serves under is
chosen by decode: `low-async` exports `GGML_VK_MAX_NODES_PER_SUBMIT=16` alone
and carries a 1.348 to 2.718 decode tok/s difference against `low-serialized`.
That leaves prefill measured once, at depth 0, inside a placement sweep.

`remote/run-prefill-ladder.sh` measures it on its own. It reads time to first
token, `prompt_n`, `prompt_ms`, and prompt tokens per second at 512, 4096,
16384, and 32768 prompt tokens with one thread, and
`remote/summarize-prefill-ladder.py` turns each depth into a ratio of the
candidate against the control with a paired interval over the replicates.
`remote/test-run-prefill-ladder.sh` and
`remote/test-summarize-prefill-ladder.py` run both without the device and both
are cells of `remote/repository-quality-gates.sh`.

## What one rung measures

Each admitted depth carries two mirrored quadruples, and each states exactly one
difference.

`C K K C` is the control server against the candidate server, both at the one
production thread the audit names. A ratio it reports is the binary.

`C T T C` is the control server at one thread against the control server at the
thread count `remote/validated-tuples.tsv` states for this row's own depth,
submission geometry, and cache triple. Exactly one validated row states it and
zero or two refuse ahead of the first server start, which is the discipline
`check-validated-tuples.sh` applies: `qwen38-2b-distill`, `qwen35-08b`, and
`qwen38-4b-distill` each carry one `validated` row at 32768/128/32 over
`q8_0`/`q4_0` with Flash Attention on, and each reads 2 threads there. A ratio
it reports is the CPU-side share
of a prefill at that depth: the two Zen+ cores read the load/store path at 7.97
GB/s on one thread and 15.44 GB/s on two, so a prefill that scales with the
second thread is spending its time where that bandwidth is consumed, and one
that does not is spending it on the two Vega compute units. The quadruple is
mirrored rather than a single arm because a difference below about 20% quoted
from single arms on this machine reports queue position; two paired replicates
are what let the interval state how much of the mean it supports.

The mirrored order puts each pair's two arms adjacent in the queue, so the
subject arm's first replicate pairs with the control's first and the second with
the second. Both quadruples run at every admitted depth, and the arm order
reaches `arms.tsv` row by row.

## The two clocks the ratio is read under

The device is held under `power_dpm_force_performance_level=manual` with the
highest graphics level selected and the highest fabric level written, which
delivers 1100 MHz GFXCLK and holds FCLK at 933 MHz as a hard minimum on this
device; `inputs.tsv`'s `operating_point` names the confirmed selections rather
than a fixed label, so a different device or a different requested level reads
its own values there instead of this device's own 1100/933. `high` and
`profile_peak` are invalid here -- both drop delivered FCLK to 400 MHz through
`SMU10_UMD_PSTATE_PEAK_FCLK`, and the 2B decodes 6 to 7 tok/s under either
against 9 to 9.6 under `manual` level 2. The lease at
`~/qwen-webui-state/vulkan-workload.lock` is taken before the first DPM write,
since the write moves the clock every workload on this machine runs at, and the
restore trap is armed before the write so a run that dies between the two leaves
the governor where it found it.

Each arm carries its own clock record, sampled at the census campaign's geometry
and read by `validate-clock-sidecar.py`. An arm whose invariant reads `violated`
ran off the pinned step, and a pair whose two modal graphics clocks lie further
apart than `--sclk-band` measures the governor step between them; each is
excluded from the mean and the interval and named in the summary's `ratios`
column.

## The prompt is built and verified rather than assumed

A rung is a token count. The runner repeats a deterministic filler word and
adjusts the count against `POST /tokenize` on the served path until that route
returns exactly the requested depth, bounded by
`QWEN_PREFILL_LADDER_ATTEMPTS` adjustments; a tokenizer that merges across the
space boundary oscillates rather than settling and the exhausted budget is
`prompt_length_unconverged`. Every arm re-tokenizes the same prompt bytes on its
own server and refuses where the count moved, so two binaries that tokenize this
depth differently are separated rather than paired under one label.

`/tokenize` reports the text alone where a completion request prepends the
beginning-of-sequence token, so the served `timings.prompt_n` is required to sit
within `QWEN_PREFILL_LADDER_PROMPT_N_SLACK` above the tokenized count and never
below it. A count outside that window is `prompt_n_mismatch`.

Every timing the ledger states is required. A reply whose `timings` object omits
one, or states it as something other than a finite number, fails its arm with
`missing_timings`; a zero would pair as a measurement.

## The two quantities, and what separates them

Time to first token is the wall time from the instant the request leaves the
client to the first streamed chunk carrying content, which is what a client
observes and what the audit asked for. It holds the HTTP round trip and the
first sampling pass beside the prefill. `timings.prompt_ms` and
`timings.prompt_per_second` are the server's own instrument over the same fill.

Both reach the ledger and both reach the summary as their own ratio, because the
pair is what separates the mechanisms: a ratio that moves on time to first token
while `prompt_tok_s` holds reports transport and scheduling, and a ratio that
moves on both reports the fill.

## Registered predictions and their falsifiers

The predictions are stated ahead of the first appliance run. Each names what
would refute it.

1. **Prefill tokens per second rises with depth and then flattens.** A short
   prompt pays the per-request and per-graph costs over few tokens, and a long
   one amortizes them until the DDR4 controller bounds the rate: the theoretical
   dual-channel peak is 34.13 GB/s and the measured achieved streaming on this
   device sits at 8.11 to 10.41 GB/s. *Falsifier:* prompt tokens per second
   falling monotonically across 512, 4096, 16384, and the deepest admitted rung
   (32719 under every row this ladder currently admits, the 32768 request
   clamped to the allocation's own headroom limit), or rising at every rung
   with no flattening, refutes the shape. A rung that falls against its
   predecessor is read against an interval built from both rungs' own
   replicates rather than against either rung's single-depth candidate/control
   ratio interval, which states a different uncertainty: the uncertainty of the
   ratio at one depth, not of the absolute rate between two depths.

2. **A candidate does not regress prefill latency or throughput at any admitted
   depth.** The two metrics carry opposite senses: above 1.0 on `ttft_ms` is
   the candidate taking longer to first token, and above 1.0 on `prompt_tok_s`
   is the candidate filling faster. *Falsifier:* an interval on `ttft_ms`
   sitting wholly above 1.0 at any admitted depth is a latency regression, and
   an interval on `prompt_tok_s` sitting wholly below 1.0 at any admitted depth
   is a throughput regression; either refutes the no-regression claim. An
   interval spanning 1.0 refutes neither and is reported as `unresolved`, the
   state `evidence/research-claim-methodology.md` names for a direction whose
   interval still crosses its threshold.

3. **One thread against the row's own thread count states the CPU-side share.**
   The `C T T C` ratio on `prompt_tok_s` above 1.0 with the interval excluding
   it places part of the prefill on the host cores; a ratio whose interval
   contains 1.0 at every depth places it on the device. *Falsifier:* the
   thread ratio and the binary ratio moving together at every depth, which would
   report a queue effect both quadruples share rather than a thread effect one
   of them isolates.

A ratio rather than an absolute band carries all three, because an absolute band
built from one sweep measures that sweep: four bands built from the four-block
means of `evidence/decode-bound-analysis.md` all read low against the
seven-checkpoint sweep, which ran 11.1 to 11.5% above them on the two
checkpoints common to both. Two replicates carry one degree of freedom and a
critical value of 12.706, so a 22% mean gain whose replicates disagree by 4%
still leaves the interval spanning unity; the summarizer reports that rather
than the mean alone. `run-prefill-ladder.sh` schedules exactly two replicates
per depth, `C K K C` and `C T T C`, regardless of how many depths
`QWEN_PREFILL_LADDER_DEPTHS` names, and it holds no repetition or append
mechanism -- `output_directory` is required absent on every invocation -- so
restricting the list to one rung narrows what a run measures rather than adding
replicates to it. Resolving a rung past two replicates needs a runner change,
not a narrower depth list.

## The deepest rung, and the row that would admit it

The allocation is one context size for the whole ladder, so a rung changes the
prompt and leaves the KV reservation alone. That size is the row's
`validated_filled_depth` bounded by its `context_ceiling`, because the ceiling
alone states an allocation the policy admits rather than one a run has filled
and decoded.

A prompt at or above its own allocation evicts rather than decodes, which is why
`probe-depth-projector.sh` accepts on `DEPTH - 2% <= prompt_n <= DEPTH - 32`. A
requested depth that would leave fewer than the generation length, the tail
reserve, and the prompt-count slack of the allocation clamps to
`model_context - generate_tokens - tail_reserve - prompt_n_slack`, the deepest
count the allocation can still decode from even at the served prompt's own
worst-case overshoot above the tokenized count, and the arm carries that
clamped count as its own identity rather than the requested label: a "32768"
rung on a 32768-token allocation would evict rather than decode, so what runs
is named for the token count it actually is. A requested depth above the row's
deepest measured fill is
skipped with `above_validated_filled_depth`, since no run has proven the
allocation fills and decodes that deep at all, and a requested depth left with
no positive room to clamp into is skipped with `insufficient_generation_headroom`.
Two requested depths that would clamp to the same count refuse the whole
invocation ahead of any server start, since the ledger keys one row set per
depth and a silent merge would pair two rungs' arms as one. A skipped depth
leaves the exit status at zero, since it is inadmissible rather than failed; an
admitted depth with any failed arm makes it non-zero.

The consequence on the shipped registry is stated rather than worked around.
`qwen38-2b-distill`, `qwen38-4b-distill`, `qwen35-08b`, and `qwen35-08b-f16` all
read `context_ceiling` 32768 and `validated_filled_depth` 32768, so at the
ladder's own defaults -- 16 generation tokens, a 32-token reserve, and 1 token
of prompt-count slack -- the requested 32768 rung clamps to 32719. That count
sits inside `probe-depth-projector.sh`'s own acceptance window for a
32768-token allocation, `[32768 - 2% = 32112.64, 32768 - 32 = 32736]`: the
ladder's own headroom formula and the projector probe's independent margin
agree that a 32719-token prompt inside a 32768-token allocation fills rather
than evicts. `inputs.tsv` and
`QWEN_PREFILL_LADDER_PRINT_PLAN=1` both carry the requested-to-actual mapping on
their `depths_admitted_requested_actual` line, so a reader sees the "32768"
rung as the 32719-token prompt it actually ran.

## The appliance command

The ladder owns the device, so it runs in a teardown window with the appliance
down. `sudo -v` on the laptop is what admits the DPM writes, since
`/etc/sudoers.d/90-qwen-agent` sets `timestamp_type=global` with a 60 minute
timeout.

That one `sudo -v` admits the acquire and does not guarantee the restore.
`census_engine_clock_write` exits 2 when its write is unauthorized;
`census_engine_clock_restore` discards its write's status and returns 0, then reads
the node back and prints `dpm_restore=restored`, `dpm_restore=mismatch`, or
`dpm_restore=unreadable`. A restore attempted after the timestamp expires therefore
leaves the device at `manual` with the highest levels selected, says so on that one
line, and exits zero. The closing command reads it back, which is why the run ends by
looking at the device rather than at the exit status.

```sh
rsync -a remote/ eirikr@qwen-laptop:~/qwen-laptop-setup/remote/

ssh eirikr@qwen-laptop
sudo -v
~/qwen-laptop-setup/remote/qwen-teardown.sh
out=~/evidence/prefill-ladder/$(date -u +%Y%m%dT%H%MZ)
set -C; { : >"$out.status" && : >"$out.log"; } || { printf 'output path in use: %s\n' "$out" >&2; exit 1; }; set +C
{ QWEN_CENSUS_MCLK_LEVEL=2 \
    ~/qwen-laptop-setup/remote/run-prefill-ladder.sh \
    ~/deployments/CONTROL/llama-server \
    ~/builds/CANDIDATE/bin/llama-server \
    qwen38-2b-distill \
    "$out"; printf 'ladder_exit=%s\n' "$?" >"$out.status"; } 2>&1 | tee -a "$out.log"
cat "$out.status"

# the clock the next workload inherits, read from the device rather than assumed
grep dpm_restore= "$out.log" | tail -1
cat /sys/class/drm/card1/device/power_dpm_force_performance_level
cat /sys/class/drm/card1/device/pp_dpm_sclk
cat /sys/class/drm/card1/device/pp_dpm_mclk
```

The runner retains `inputs.tsv`, `arms.tsv`, and `summary.tsv` under its output
directory and writes `dpm_restore=` to stdout, which nothing captures on its own, so the
`tee` above is what makes the line readable after the run while it still scrolls. A
pipeline reports its last command's status, so `tee` would report success over a failed
ladder; the braces record the runner's own status into `$out.status` before the pipe
sees it, which is what `cat` reads back. The runner refuses an output path that already
exists, so `$out.log` and `$out.status` are named beside that directory rather than
inside it. The runner's own refusal covers the directory alone: two invocations inside
one UTC minute compose the same `$out`, and the redirection and `tee` would truncate the
first run's sidecars while the runner was still refusing its directory. `set -C` makes
each `: >` an `O_EXCL` create, so a second invocation loses `$out.status` or `$out.log`
atomically and stops before it reaches `tee`; testing the names first and creating them
afterwards would leave both runs past the test. Both sidecars are reserved because
reserving only the status file leaves `tee` truncating a retained `$out.log` that
outlived its status file, and `tee -a` appends into the empty file the reservation just
made rather than truncating it again. The device is claimed twice over
anyway, since the ladder takes the Vulkan workload lease, but the reservation is what
keeps the retained bytes safe rather than the lease.

The line reads `dpm_restore=restored level=X requested=X sclk_level=I mclk_level=J` when
the policy node is back in the policy the run found it in, and `dpm_restore=mismatch`
when it is not. `requested=` is that pre-run policy, which `census_engine_clock_snapshot`
took before the first write, so it is `manual` for a device that was already forced and
`auto` otherwise. Compare the policy read against `requested=` rather than against a
fixed name, and write `requested=`'s value back on a mismatch.

`restored` is necessary and not sufficient. `census_engine_clock_restore` writes the
policy and, under `manual`, the two clock indices, and then compares the policy node
alone. A device whose pre-run policy was already `manual` therefore reads back
`level=manual requested=manual` and prints `restored` even when both index writes were
refused, leaving the campaign's own highest `pp_dpm_sclk` and `pp_dpm_mclk` selections
starred. The two `cat` reads above close that: the starred step in each table is the one
the next workload runs at, and it has to be the `sclk_level=` and `mclk_level=` indices
the same line names. Where it is not, `sudo -v` again and write those indices back to
`pp_dpm_sclk` and `pp_dpm_mclk`.

`../prefill-ladder/device-window-20260903-not-run.md` records the window this
requirement was found in, and the campaign's own wall time is unmeasured, so the
read-back closes the gap whether or not a given run crosses the hour.

Both server paths are explicit arguments and the ladder reads no bundle: it
starts each arm directly rather than through `resolve-active-deployment.sh`, so
an activation during a run changes nothing it serves and an operator naming a
path under `deployment-current` gets whatever that link resolved to when the
argument was typed. Naming the bundle directory itself rather than the link is
what keeps the retained digests meaning one binary.

`QWEN_PREFILL_LADDER_PRINT_PLAN=1` prints the admitted depths, the
requested-to-actual mapping a clamp produced, the skipped ones with their
reasons, the arm order, the allocation, both thread counts, and both server
digests without touching the device, which is how a run is read before it is
spent. The class order is the repository's own: the current 2B first, the
current 0.8B second, the current 4B third, and a result becomes a Raven2-wide
default only where the classes agree.

## What the run retains

`inputs.tsv` carries both server digests, the model digest and byte count, the
registry tuple, the allocation, both thread counts, the depth plan with its skip
reasons and its requested-to-actual clamp mapping, the clock policy and its
operating point, the submission profile and its `GGML_VK_LOW_PRIORITY` and
`GGML_VK_MAX_NODES_PER_SUBMIT` settings, the nice policy every arm's server is
required to run under, the sampler geometry, and the lease path. `arms.tsv`
carries one row per depth, quadruple, arm, and replicate with its own server
digest, thread count, the nice value read back from `/proc` after the renice,
tokenized count, served `prompt_n`, time to first token, `prompt_ms`, prompt
tokens per second, tail decode rate, modal graphics clock, clock invariant,
status, and reason. Each arm keeps its sealed environment record, written by
`census_arm_exec` from the same positional list the `env -i` was built from --
which is where the applied `GGML_VK_LOW_PRIORITY`, `GGML_VK_MAX_NODES_PER_SUBMIT`,
and `QWEN_VULKAN_PROFILE` assignments themselves land -- beside its server log,
clock record, and validator verdict. `summary.tsv` carries the ratio, its
interval, and its verdict per depth, quadruple, and metric.
