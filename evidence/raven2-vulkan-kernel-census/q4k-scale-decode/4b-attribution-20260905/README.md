# The 4B attribution: the composed Q4_K path executes and owns 57% of the token

```text
measurement_status=attribution
calibration_verdict=failed (arm_failures=5, controls incomplete)
attribution_arms=18-I1 19-I1 23-I1 (22-I1 refused by the census reader)
production_server=83684f3c... (composed Q4_K candidate serving build)
instrumented_server=4844d0dc... (the same source beneath llama-vulkan-pipeline-census.patch)
engine_clock=applied policy=manual sclk_level=2 mclk_level=2 required_sclk_mhz=1100 required_mclk_mhz=933
cooldown_deadline_s=240
```

`docs/frontier.md` asks why the composed Q4_K candidate moved nothing on
`qwen38-4b-distill` where it moved the 2B by +1.83% (`../served-ab-4b-r2-20260903T2115Z/`,
`refuted mean_delta=-0.0002 ci=[-0.0010,+0.0006]`), and names four admissible
answers: the modified path was not selected; selected with no local improvement
on this shape; improved locally with no graph effect; or its graph ownership is
too small to matter. This record supports exactly the second.

## What ran

A calibration at four replicates on the 4B with P the composed candidate serving
build and I its census twin, under `manual-gfx1100-fclk933` and a 240 s boundary
deadline (the first attempt, `calibration.attempt1-cooldown30` on the appliance,
ended `quiescence_unconverged` at its first boundary under the 30 s default with
`sclk_stable,temp_abs,temp_rate,mem,pswpin` unmet; the second reached the same
boundary in 4.9 s from a cooler machine). All 25 arms executed at 1100/933 with
`clock_invariant=held` on every sampled arm. The calibration's own verdict is
`failed`: four P arms were refused on `window_lost` at 3.01 to 4.70% against
the 3% bound (the sampler held off the CPU under the 4B's decode; their rates,
3.06 to 3.27 tok/s, sit below the accepted P arms' 3.26 to 3.56), and one I1 arm
was refused by `summarize-kernel-census.py` on a dispatch whose interval
disagreed with its endpoints. The three controls read incomplete, which licenses
no instrument bound and changes no standing verdict in `../../README.md`. The
three accepted I1 arms are the attribution record, read against their own I1
graph span with the standing C2 collection term of about 1.1% stated beside
them. `denominator/` retains the fixed-64 sweep on the candidate server that the
census receipt binds.

## The executed path is the composed formulation

`llama-vulkan-q4k-variant-select.patch` compiles the composed formulation
(`e4-scale-licm`, its variant 2) under the plain shader name and gives the
`e4` and `e4-scale` formulations the `v0` and `v1` suffixes; the census build
embeds `mul_mat_vec_q4_k_f32_f32.spv` beside `mul_mat_vec_q4_k_v0_*` and
`mul_mat_vec_q4_k_v1_*`. Every I1 ledger names `mul_mat_vec_q4_k_f32_f32`
with specialization constants `64,4,1` -- subgroup 64 over four rows, the
`/4` row count of the composed key -- and the candidate tree's plain module
hashes to `dfb79f60...` where the production tree's hashes to `a1877c7e...`, so
the plain name in this build is the composed shader and the production shader
is absent from the executable. The `spirv_executed_sha256` column carries the
specialized module (`78a576ff...`), the form the e1 record disassembles as
`e4-spec-64-4-1.spvasm`.

## Ownership on the 4B against the 2B

Exclusive bracket time over the 63 decode graphs of one 64-token reply, the
median of the three accepted I1 arms here and the retained 2B I1 arm 18 of
`../../20260902T2124Z/` (production shader, same instrument revision and clock
pair):

| class | decode ms | Q4_K mat-vec excl ms | share | Q6_K mat-vec excl ms | share | Q4_K calls per graph | Q4_K median us |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4B, composed shader | 18788 | 10712 | 57.0% | 5137 | 27.3% | 216 | 744 |
| 2B, production shader | 6513 | 3226 | 49.5% | 2307 | 35.4% | 162 | 207 |

Ambiguous overlap on the Q4_K row is 118 ms of 10.7 s on the 4B, so the share
is read as a share. Per graph the 4B's Q4_K family takes 170.0 ms and its Q6_K
family 81.5 ms. `remote/gguf-tensor-census.py` reads the 4B at 1.701 GB of
Q4_K and 1.068 GB of Q6_K streamed per token (61.1% and 38.4%; the output head
is tied and streams the Q4_K embedding), which puts the Q4_K family at 10.0 GB/s
inside its own dispatches and the Q6_K family at 13.1 GB/s. The 2B reads 0.642
GB of Q4_K over 51.2 ms per graph, 12.5 GB/s, and 0.657 GB of Q6_K over 36.6 ms,
17.9 GB/s. On both classes the Q4_K family streams 20 to 30% slower than the
Q6_K family on the same die at the same clock, so neither class's Q4_K
dispatches sit at a streaming ceiling the Q6_K dispatches already reach.

## The conclusion, and its correction

Ownership is large and the modified path executes. This record first read the
retained served null (`../served-ab-4b-r2-20260903T2115Z/`, -0.02%) as the
composed stack's, and with the Q4_K family at 57% of the token concluded that
the composed module shortens nothing on the 4B's shapes; it named the
kernel-delta bracket as the confirmation and predicted the Q4_K exclusive
delta inside [-0.2%, +0.2%]. The bracket ran the same day
(`../4b-kernel-delta-20260905/`) and refuted that prediction: the composed
module's exclusive time is 10.4% shorter over the three clean pairs, its
median dispatch 744 us against 820 us, the Q6_K null holds, and the graph
span shortens 6.8%. The retained null belongs to a different candidate --
its `inputs.tsv` names `scale-word-select` and `superblock-loop-licm` alone,
without the two activation patches -- so the composed stack had never been
served on the 4B, and the reading here that rested on that null is
withdrawn. The supported answer to the frontier's question is the third of
its four: **improved locally, with a graph effect**. The ownership figures
above stand, and they now say the opposite of what this record first drew
from them: a 10% shorter dispatch on a 57% owner is worth about 6% of the
token, which is what the bracket's graph span reads.

What the record still does not name is why the 4B's Q4_K family streams at
10.0 GB/s against the same class's Q6_K at 13.1; the composed module moves
that figure to about 11.1 GB/s and leaves the gap to Q6_K open.

## Files

- `calibration/`: the campaign's ledgers (`arms.tsv`, `summary.tsv`,
  `terminal-state.tsv`, `wall-clock.tsv`, the three contracts, `inputs.tsv`,
  `campaign-inputs.tsv`, `bricks/`), and per arm the sidecar verdict, the
  request window, the runtime identity, the served summary, and for the I1
  arms `pipeline-ledger-decode.tsv` and `pipeline-ledger-prefill.tsv`. The
  raw `pipeline-census.tsv` and `clock-sidecar.tsv` records stay on the
  appliance under `results/4b-attribution-20260905T1545Z/`.
- `denominator/`: the candidate server's fixed-64 receipt and summary.
