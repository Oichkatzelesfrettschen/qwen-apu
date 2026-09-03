# E4 rung 7: the served comparison, its falsifiers registered ahead of the run

`patches/llama-vulkan-q4k-activation-group-sums.patch` removes 72 of the Q4_K
mat-vec's 882 VALU instructions and changes nothing else the compiler reports:
`e1/README.md` measures VGPRs flat at 64, no spill, no scratch, LDS unchanged,
four subgroups per SIMD on both arms, and 36 of those 72 removed inside the
superblock loop body where the shader spends its arithmetic. Rung 4 passed on
that receipt and licensed a device window. Rung 7 asks the only question the
compiler cannot answer: whether a served 64-token decode moves.

`remote/run-served-binary-ab.sh` is that measurement. It runs the mirrored
quadruple `C K K C` -- control, candidate, candidate, control -- once per two
replicates, opened by a warmup arm on the control server with the sampler off,
every arm a fixed-64 served decode through `measure-served-decode.sh` at the
registry tuple, under the production receipt binding the fixed-64 scoreboard
wrote. `summarize-census-controls.py` takes the paired deltas of the candidate
over the control, their mean, their sample standard deviation, and a nominal
95% t interval, and judges the interval against a one-sided promotion bound.

## The verdict rule, and why it is one-sided

The repository promotes a candidate on a paired gain, so there is no admitted
band below the bound: `promoted` where the whole interval sits above
+QWEN_AB_BOUND, `refuted` where the whole interval sits below it, `unresolved`
where the interval spans it. A candidate merely no faster than the control is
refuted the way a slower one is. A pair whose two arms selected different
graphics clocks measured the governor step rather than the binary and leaves
the mean and the interval; a run left with fewer than two comparable pairs
reads `state-changed`. The exits are `promoted` 0, `refuted` 3, `unresolved`
and `state-changed` 4, a failed arm 1.

The bound is 0.05. This machine carries about 4% of uncontrolled spread on a
repeated depth-0 rate (`evidence/measurement-state-and-memory-clock.md`) and up
to 30.6% between sweeps under desktop load
(`evidence/decode-bound-analysis.md`), so a 5% bound sits close to the floor of
what a within-sweep paired comparison resolves here. At four replicates the
interval half-width is `t(3)/sqrt(4) = 1.591` sample standard deviations, so a
verdict of `refuted` at a mean of +4.2% needs the four paired deltas to agree
to about 0.5%. The mean delta is therefore the quantity a reader takes from
this run, and the verdict states how much of it the interval supports.

## The prediction, and its arithmetic

The E4 receipt removes 8.2% of the Q4_K mat-vec's whole-shader VALU issue
(72 of 882) and 9.8% of the superblock loop body's (36 of 366); the 36 removed
per body against the whole shader's 882 is 4.1%, the reading that counts one
call site where the shader has two. `decode-decomposition.md` registers P1, the
mat-vec families' bracket union, at 50 to 65 ms of the 2B's 101 ms token, and
the Q4_K family alone at about 52 of those 101 ms.

The whole-shader 8.2% is the operative denominator, because the shader loses
all 72 instructions on every superblock it executes and the 4.1% reading counts
the same 36 twice-called removals once. An 8.2% issue reduction over a family
owning 52 of 101 ms moves the token 4.2% where that bracket is issue-bound end
to end, and 3.5% where about a sixth of it is memory or queue time the removal
does not touch. The registered band is therefore **+3.5% to +4.2%**, the
registered verdict **`refuted` or `unresolved`**, and 2.1% is the floor the
conservative reading of the receipt would put under the same family share
rather than a value the band admits. `promoted` is the surprise: it needs the
whole interval above +5%, which is more than the family's own issue share can
supply and would say the removal reached something the receipt does not account
for.

| prediction | value | falsifier |
| --- | --- | --- |
| the verdict | `refuted` or `unresolved` at bound 0.05 | `promoted` refutes the operation-count model as an upper bound on this term: the served gain then exceeds what the family's issue share can supply |
| the mean paired delta | +3.5% to +4.2% | a mean below +3% meets the E4 ladder's own falsifier in `decode-decomposition.md` and refutes the operation-count model for this term; a negative mean says the pre-pass costs more than the fused chain it replaces |
| comparable pairs | 4 of 4 at one selected graphics clock | fewer than 4 means the governor stepped inside the run and the surviving pairs carry the verdict; fewer than 2 reads `state-changed` and the run repeats |

## What would raise the mean, and what would lower it

The mean rises where the Q4_K family owns more of the token than 52 ms. P1's
upper end of 65 ms with the 8.2% reading predicts +5.3%, which crosses the
bound, so a bracket measurement placing the family above about 61 ms turns the
prediction into `unresolved` or `promoted` on arithmetic alone. It also rises
where more of the family's bracket is issue-bound than assumed: the census
retains `queue_non_dispatch_ms_per_graph` and the per-pipeline exclusive time,
and a family whose bracket is nearly all exclusive dispatch time converts issue
savings at close to the full ratio.

The mean falls where the decode is bound by memory rather than by issue. This
tree measures the 2B streaming 8.11 to 10.41 GB/s per token against a
theoretical dual-channel peak of 34.13 GB/s and a two-thread host read of
15.44 GB/s, and RADV reports every `shaderIntegerDotProduct` acceleration flag
false, so about 83% of streamed bytes take the FP16-dequantize-then-dot family;
a `v_mac_f32` removed from a wave already waiting on DDR4 returns nothing. It
also falls where the 96 removed `v_mac_f32` were already hidden under VMEM
latency rather than occupying issue slots, which the receipt cannot
distinguish: `longest_valu_chain` falls from 29 to 17, so the removal shortens
a dependency chain, and a chain that was never the critical path pays nothing.

## The chain, on the appliance

Run in a teardown window, with the router down and the qemu tenant idle. The
E4 tree is prepared from the pinned base and built with the production preset
rather than the profile preset: `run-served-binary-ab.sh` requires the control
and candidate manifests to yield one base build identity, and that identity
carries `compiler_flags` and `cmake_flags`, so a `raven2-vulkan-profile` build
-- `RelWithDebInfo` plus `-fno-omit-frame-pointer` -- refuses against a
`raven2-vulkan-production` control before any arm runs. The candidate is
serving-shaped by construction: the production preset writes no
`instrumentation` row and declares `serving_eligible yes`, which is what the
E4 patch needs, since it adds no diagnostic surface.

```sh
cd ~/qwen-laptop-setup

# The candidate tree: the production series onto the pinned commit, then the
# one E4 member on top.
remote/prepare-llama-census-source.sh ~/src/llama.cpp ~/src/llama.cpp-e4 \
    llama-vulkan-q4k-activation-group-sums.patch

# The candidate binary: the serving preset, with the one candidate selected.
# The manifest then reads candidate_series llama-vulkan-q4k-activation-group-sums.patch
# and checkpoint_series_tree verified-candidate, which the harness requires.
QWEN_LLAMA_CANDIDATE_SELECT=llama-vulkan-q4k-activation-group-sums.patch \
    remote/build-llama-preset.sh raven2-vulkan-production ~/src/llama.cpp-e4

# The comparison. CONTROL is the promoted serving build the fixed-64
# scoreboard measured, and QWEN_CENSUS_PRODUCTION_RECEIPT is that sweep's own
# identity-check.tsv; the receipt directory's models-resolved.tsv and
# campaign-inputs.tsv are compared against what the registry resolves now.
QWEN_CENSUS_PRODUCTION_RECEIPT=~/qwen-fixed64/SWEEP/identity-check.tsv \
    QWEN_AB_REPLICATES=4 QWEN_AB_BOUND=0.05 \
    remote/run-served-binary-ab.sh \
    ~/qwen-builds/raven2-vulkan-production/bin/llama-server \
    ~/qwen-builds/raven2-vulkan-production-e4/bin/llama-server \
    qwen38-2b-distill ~/qwen-e4-served-ab/RUN
```

Nine arms at about 19 seconds each plus the quiescence deadline; at the default
30-second deadline the run is bounded at about seven and a half minutes. The
2B is the arm that runs first, because it is the appliance's primary
performance target and the class the E4 receipt was read against; the 0.8B and
the 4B follow only where the 2B moves.

## What the run retains

`arms.tsv` carries the census's own twelve columns, so one reader serves both
campaigns: slot, arm, the digest of the server that arm actually ran,
`predicted_n`, `predicted_ms`, `tok_s`, `census_rows` and `ownership` as `-`,
the sidecar state, the arm status, and the modal selected graphics clock with
its share. `summary.tsv` carries the one `served-ab` row with the mean, the
sample standard deviation, the interval, every paired delta in campaign order,
and the clock modes each pair held. `terminal-state.tsv` carries the verdict,
the mean, the interval, the comparable-pair count, the arm failures, and both
server digests. `inputs.tsv` binds the model tuple, both manifests, the base
build identity, the scoreboard receipt, the sampler, and the runtime tree.
