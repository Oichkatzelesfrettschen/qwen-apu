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

The device is held at `manual-gfx1100-fclk933`:
`power_dpm_force_performance_level=manual` with the highest graphics level
selected and the highest fabric level written, which delivers 1100 MHz GFXCLK
and holds FCLK at 933 MHz as a hard minimum. `high` and `profile_peak` are
invalid here -- both drop delivered FCLK to 400 MHz through
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
   falling monotonically across 512, 4096, 16384, and 32768, or rising at every
   rung with no flattening, refutes the shape. A rung that falls against its
   predecessor by more than the pair interval at that rung refutes it outright.

2. **A candidate reading above 1.0 on time to first token at every admitted
   depth, with every interval excluding 1.0, refutes a prefill regression
   claim.** The direction is stated explicitly because the two metrics carry
   opposite senses: above 1.0 on `ttft_ms` is the candidate taking longer, and
   above 1.0 on `prompt_tok_s` is the candidate filling faster. A claim that a
   candidate leaves prefill unchanged is refuted by the first, and a claim that
   it improves prefill is refuted by intervals that exclude 1.0 on the slow side
   of `prompt_tok_s`. An interval spanning 1.0 refutes neither and is reported
   as `unresolved`, the state `evidence/research-claim-methodology.md` names for
   a direction whose interval still crosses its threshold.

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
than the mean alone, and `QWEN_PREFILL_LADDER_DEPTHS` restricted to one rung is
how a reader spends more replicates where one is worth resolving.

## The deepest rung, and the row that would admit it

The allocation is one context size for the whole ladder, so a rung changes the
prompt and leaves the KV reservation alone. That size is the row's
`validated_filled_depth` bounded by its `context_ceiling`, because the ceiling
alone states an allocation the policy admits rather than one a run has filled
and decoded.

A prompt at or above its own allocation evicts rather than decodes, which is why
`probe-depth-projector.sh` accepts on `DEPTH - 2% <= prompt_n <= DEPTH - 32`. A
depth leaving fewer than the generation length plus
`QWEN_PREFILL_LADDER_TAIL_RESERVE` tokens of the allocation is therefore skipped
with `insufficient_generation_headroom`, and a depth above the row's deepest
measured fill is skipped with `above_validated_filled_depth`. Both leave the
exit status at zero, since a skipped depth is inadmissible rather than failed;
an admitted depth with any failed arm makes it non-zero.

The consequence on the shipped registry is stated rather than worked around.
`qwen38-2b-distill` and `qwen38-4b-distill` both read `context_ceiling` 32768 and
`validated_filled_depth` 32768, so the 32768 rung leaves no room for its own tail
and the ladder records the skip. Measuring that rung needs a row whose ceiling
and validated depth both exceed 32768 by at least the generation length plus the
reserve; the ladder declines to measure an eviction and call it a prefill.

## The appliance command

The ladder owns the device, so it runs in a teardown window with the appliance
down. `sudo -v` on the laptop is what admits the DPM writes, since
`/etc/sudoers.d/90-qwen-agent` sets `timestamp_type=global` with a 60 minute
timeout.

```sh
rsync -a remote/ eirikr@qwen-laptop:~/qwen-laptop-setup/remote/

ssh eirikr@qwen-laptop
sudo -v
~/qwen-laptop-setup/remote/qwen-teardown.sh
QWEN_CENSUS_MCLK_LEVEL=2 \
    ~/qwen-laptop-setup/remote/run-prefill-ladder.sh \
    ~/deployments/CONTROL/llama-server \
    ~/builds/CANDIDATE/bin/llama-server \
    qwen38-2b-distill \
    ~/evidence/prefill-ladder/$(date -u +%Y%m%dT%H%MZ)
```

Both server paths are explicit arguments and the ladder reads no bundle: it
starts each arm directly rather than through `resolve-active-deployment.sh`, so
an activation during a run changes nothing it serves and an operator naming a
path under `deployment-current` gets whatever that link resolved to when the
argument was typed. Naming the bundle directory itself rather than the link is
what keeps the retained digests meaning one binary.

`QWEN_PREFILL_LADDER_PRINT_PLAN=1` prints the admitted depths, the skipped ones
with their reasons, the arm order, the allocation, both thread counts, and both
server digests without touching the device, which is how a run is read before it
is spent. The class order is the repository's own: the current 2B first, the
current 0.8B second, the current 4B third, and a result becomes a Raven2-wide
default only where the classes agree.

## What the run retains

`inputs.tsv` carries both server digests, the model digest and byte count, the
registry tuple, the allocation, both thread counts, the depth plan with its skip
reasons, the clock policy and its operating point, the sampler geometry, and the
lease path. `arms.tsv` carries one row per depth, quadruple, arm, and replicate
with its own server digest, thread count, tokenized count, served `prompt_n`,
time to first token, `prompt_ms`, prompt tokens per second, tail decode rate,
modal graphics clock, clock invariant, status, and reason. Each arm keeps its
sealed environment record, written by `census_arm_exec` from the same positional
list the `env -i` was built from, beside its server log, clock record, and
validator verdict. `summary.tsv` carries the ratio, its interval, and its
verdict per depth, quadruple, and metric.
