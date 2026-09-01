# Fixed-64 served decode scoreboard on the promoted binary

`20260901T2011Z/` is the first sealed twelve-arm run of
`remote/run-fixed64-served-campaign.sh` on the appliance. It measures the
three registry classes through the served path at their registry-default
tuples against the 20 / 10 / 5.25 tok/s targets in
`remote/throughput-targets.tsv`, and every class reads `unmet`. The 2B misses
by 1.4% on its mean and 1.7% on its slowest arm, the 0.8B by 8.7% on its mean
and 18.8% on its slowest arm, and the 4B by 36.2%.

This is the Stage 0 throughput baseline. It is the denominator a later
optimization bundle is compared against, and it is a served-path measurement
of the promoted binary rather than a kernel census; the census instruments a
separate binary and retains its evidence elsewhere.

## The window

| Field | Value |
| --- | --- |
| terminal state | `completed-target-unmet`, 12 expected, 12 completed, 0 failed |
| source revision | `7e79435a48295dbd99c836999d3ad4573a874bef`, clean before and after |
| server | `5dd86b90154f6143a5303efd2590b9268a0a5e3e908c4d6791f1fde03a4782c2`, 57735736 bytes |
| Vulkan profile | `low-async`, placement strict Vulkan0, `inference_cpu=0` |
| checkpoint policy | `--ctx-checkpoints 2 --checkpoint-min-step 8192` on every arm |
| execution surface | `hp14-ssh`, server nice 19, idle I/O class |
| sampling | 64 tokens, temperature 0, top_k 1, seed 1, `ignore_eos`, thinking off |
| block order | forward, forward, reverse, reverse; four slots per model; 30 s cooldown |
| latency probe | bound through `QWEN_SERVED_CAMPAIGN_LATENCY_PROBE` and hashed in `identity-before.tsv` |

`identity-check.tsv` accepts every subject after the run: orchestrator,
child runner, summarizer, registry readers, the five ledgers, launch and
teardown scripts, server, RADV ICD, latency probe, and the three model
artifacts. `PRE_SANITIZATION_SHA256SUMS` is the campaign's own sealed
manifest over the original bytes; the Git copy replaces the home prefix with
`$HOME` and the hostname with `qwen-laptop`, and retains the runtime closure
as `configuration/runtime-source-tree.tsv` rather than as the tree itself,
since the source is the tagged revision and the probe binary's digest is on
the identity rows.

## Per-class result

Rates are `recomputed_tok_s = 1000 * (predicted_n - 1) / predicted_ms` from
`summary.tsv`. A class meets its target only when all four arms do, so the
mean, block means, and span are descriptive.

| Class | target | slot rates tok/s | fwd mean | rev mean | mean | min | max | span | mean/target | arms meeting |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `qwen35-08b` | 20 | 18.868, 18.790, 19.138, 16.233 | 18.829 | 17.685 | 18.257 | 16.233 | 19.138 | 17.89% | 0.913 | 0 of 4 |
| `qwen38-2b-distill` | 10 | 9.831, 9.895, 9.849, 9.880 | 9.863 | 9.864 | 9.864 | 9.831 | 9.895 | 0.65% | 0.986 | 0 of 4 |
| `qwen38-4b-distill` | 5.25 | 3.331, 3.351, 3.360, 3.365 | 3.341 | 3.362 | 3.352 | 3.331 | 3.365 | 1.01% | 0.638 | 0 of 4 |

| Class | ms per token, four arms | s per 100 tokens | s per 500 | s per 1000 |
| --- | --- | ---: | ---: | ---: |
| `qwen35-08b` | 53.00, 53.22, 52.25, 61.60 | 5.5 | 27.4 | 54.8 |
| `qwen38-2b-distill` | 101.72, 101.06, 101.54, 101.22 | 10.1 | 50.7 | 101.4 |
| `qwen38-4b-distill` | 300.18, 298.44, 297.61, 297.19 | 29.8 | 149.2 | 298.4 |

In-sweep class ratios on the four-arm means: 2B / 0.8B = 0.540,
4B / 2B = 0.340, 4B / 0.8B = 0.184. These are the ratios a pipeline-time
estimate for one class is stated against.

## Safety verdict

Every arm's kernel hazard log holds zero hazard markers, every telemetry
sample records zero swap-in, host memory available never fell below 12.0 GiB,
the die peaked at 80.5 C on slot 5, `mclk` selected 1067 MHz on every sample,
and the graphics latency probe recorded zero deadline breaches over 7881
samples with a per-arm p90 between 392 and 1749 us. Peak Vulkan residency was
1291 MiB VRAM for the 0.8B, 1812 for the 2B, and 2024 for the 4B, whose
24576-token cache also placed 1749 MiB in GTT.

## What the spread reports

Three of the four 0.8B arms sit inside 1.9% of each other and slot 12 sits
13.6% to 15.2% below them. Its telemetry is the one arm whose `sclk` selection stepped
through 733 and 1050 MHz during decode where every other arm selected 400 and
1100 alone, and its probe p90 is the run's highest at 1749 us. The class span
of 17.89% is therefore one clock-state excursion rather than a property of
the checkpoint, and the 0.8B verdict rests on it: the other three arms are
between 0.94 and 0.96 of target, so a clean fourth arm would still leave the
class unmet. The 2B and 4B spans of 0.65% and 1.01% sit under the 4.4%
four-slot span the runtime-class sweep reported and under the 4% a repeated
depth-0 llama-bench rate carries, so this window held the between-arm state
that ordered the earlier sweeps.

The target verdict and the general inference are two claims. The verdict is
that no class clears its threshold under the registry-default tuple on the
promoted binary in this window. The inference is that the 2B and 4B rates are
stable across position here, and that the machine-state term the tree has
measured at up to 30.6% between sweeps under desktop load appeared as one
0.8B excursion in this idle window. The rates state this window and this
server; they are the denominator, and the next comparison is a ratio against
them inside one sweep rather than an absolute band.

## Reading against earlier surfaces

The registry's reported paired means are 18.53, 9.19, and 3.34. This window
places the 0.8B 1.5% below that figure on its mean, the 2B 7.3% above, and
the 4B 0.4% above, from a hash-bound served path where the registry rows
came from `llama-bench`. The 2B row of `evidence/throughput-target-analysis`
now has its fixed-64 served denominator and its 10 tok/s target is 1.4% away
on the mean; the 4B target needs 1.57 times this rate.
