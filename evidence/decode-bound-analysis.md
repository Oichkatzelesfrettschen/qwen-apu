# Byte count does not predict decode on this device

The 4B distill decodes near 3 tok/s and the active interactive target is 5.25.
The superseded analysis priced two levers against 4.5 tok/s, and both came in
far under: the
levers were priced before this measurement and both came in far under: the
embedded multi-token-prediction head returns 1.13 to 1.16 at one draft token,
and the served KV cache policy costs 1.9% at depth 0 rather than the 7% it was
credited with. The remaining published lever was byte count, and
`evidence/model-admission/qwen38-4b-low-bit-ladder.md` registered proportional
scaling before the file existed: Q2_K streaming 0.7059 of Q4_K_M's bytes was
recorded as 4.34 tok/s, with a two-sided falsifier at 3.5 and 5.5. Recomputing
the displayed 3.07 tok/s and exact byte ratio gives 4.348830 tok/s, which rounds
to 4.35; the correction changes neither falsifier.

## The measurement

The result table reports five checkpoints across four alternating-order blocks.
The current `remote/run-bandwidth-ladder.sh` runs each checkpoint twice per
invocation, once forward and once in reverse, so four blocks require two
invocations.
Streamed bytes come from `remote/gguf-tensor-census.py`, which excludes the
multi-token-prediction block decode skips and counts a tied embedding once for
the lookup and once for the projection. Every arm ran at nice 19 with the
logger's `pp_dpm_mclk` field at 933 MHz, on a live desktop under load averages
between 4.26 and 6.89. [Linux v7.0 SMU10](https://github.com/torvalds/linux/blob/v7.0/drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c#L1061-L1063)
resolves that legacy field through `PPSMC_MSG_GetFclkFrequency`, so 933 MHz
names selected FCLK rather than trained DRAM rate. The
[retained clock and UMC record](measurement-state-and-memory-clock.md#memory-is-trained-at-ddr4-2133-the-reported-steps-are-dynamic-fclk)
keeps those surfaces separate.

The checkout retains neither invocation records nor the five-checkpoint
`bandwidth-summary.tsv`, per-arm benchmark logs, and clock TSVs behind the four
blocks. The retained 4B tensor census also records `sha256` as `not computed`,
so its counts bind the report rather than exact GGUF bytes. The table remains a
reported measurement whose arithmetic and decision boundaries can be checked;
the checkout cannot independently reconstruct its execution. A repeat must
admit both invocation command lines, executed source identities, the summary,
every arm and clock file, and hash-bound census outputs.

Achieved GB/s per block, and the mean of the four:

| checkpoint | streamed/token | A | B | C | D | mean GB/s | mean tok/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-2B Q4_K_M | 1263435008 | 12.13 | 8.95 | 9.63 | 10.92 | 10.41 | 8.24 |
| Qwen3.8-4B Q4_K_M | 2697836544 | 8.85 | 7.90 | 7.23 | 8.44 | 8.11 | 3.01 |
| Qwen3.8-4B i1-Q6_K | 3453087744 | 8.63 | 8.05 | 7.67 | 8.15 | 8.13 | 2.35 |
| Qwen3.8-4B i1-Q5_K_M | 3064018944 | 6.40 | 5.73 | 5.55 | 6.01 | 5.92 | 1.93 |
| Qwen3.8-4B i1-Q2_K | 1904502784 | 6.06 | 5.09 | 4.99 | 5.96 | 5.53 | 2.90 |

## A repeated arm spans up to 30% and no logged covariate orders it

The same checkpoint under the same flags at the same priority spans 11.9% of its
mean for Q6_K and 30.6% for the 2B. That exceeds most of the differences the
sweep exists to resolve, so a rate quoted from one arm reports its position in
the queue as much as its flags.

The 2B settles what the spread is not. Three of its four arms ran at 88 C with
the logged FCLK state at 933 MHz and produced 8.95, 9.63, and 10.92 GB/s, a 22%
span at fixed die temperature and fixed reported FCLK. Load average fails on the
same data from the other side: Q6_K rises monotonically with load across all four
arms, 7.67 GB/s at 5.08 up to 8.63 at 5.77, which is the opposite sign to the 2B
and to Q4_K_M.
Four repeats against three logged covariates support no mechanism, and the
magnitude is the finding.

Every comparison below is therefore read within a block, where both checkpoints
met the same machine minutes apart, rather than between block means.

## Proportional scaling is falsified, and by more than the first pass showed

Q2_K carries 29.4% fewer bytes per token than Q4_K_M and decodes no faster in any
block:

| block | Q4_K_M tok/s | i1-Q2_K tok/s | difference |
| --- | ---: | ---: | ---: |
| A | 3.28 | 3.18 | +0.10 |
| B | 2.93 | 2.67 | +0.26 |
| C | 2.68 | 2.62 | +0.06 |
| D | 3.13 | 3.13 | 0.00 |

The registered falsifier was a rate below 3.5 and the highest Q2_K arm measured
3.18. Achieved streaming fell from 8.11 GB/s to 5.53, a 31.8% drop that cancels
the byte saving. The paired difference is small -- 3.6% of the mean, against a
within-checkpoint spread of 19% -- and these four blocks do not establish
equivalence. They establish the decision-relevant direction: Q2_K trails in
three blocks, ties in one, and never reaches the registered 3.5 tok/s floor.

**The tested Q2_K route to 4.5 tok/s is closed.** Its smaller byte count buys no
measured decode gain on this device. IQ and other kernel families remain
separate measurements rather than consequences of this result.

## The route upward is closed as well

Q6_K and Q5_K_M were fetched to extend the series above Q4_K_M. Q4_K_M leads
both in every block:

| block | Q4_K_M | i1-Q6_K | i1-Q5_K_M |
| --- | ---: | ---: | ---: |
| A | 3.28 | 2.50 | 2.09 |
| B | 2.93 | 2.33 | 1.87 |
| C | 2.68 | 2.22 | 1.81 |
| D | 3.13 | 2.36 | 1.96 |

Q4_K_M runs 28% above Q6_K and 55% above Q5_K_M on paired means, with no block
reversing either sign. **Q4_K_M beats all three tested 4B alternative
K-quantizations.** The measured K-quant ladder closes in both directions around
the deployed file; IQ and other reconstruction kernels remain outside it.

## Achieved streaming forms two observed groups that bit width does not order

`remote/gguf-tensor-census.py` reports the byte share of each ggml type, and a
Q4_K_M label names a recipe rather than a layout. Every 4B file spends the same
1,067,673,600 bytes on a Q6_K tied vocabulary projection except the pure Q6_K
build, so the share that varies is the bulk of the trunk:

| checkpoint | bulk format | bulk share | Q6_K share | mean GB/s |
| --- | --- | ---: | ---: | ---: |
| Qwen3.8-4B i1-Q6_K | Q6_K | 99.58% | 99.58% | 8.13 |
| Qwen3.8-4B Q4_K_M | Q4_K | 61.11% | 38.36% | 8.11 |
| Qwen3.8-4B i1-Q5_K_M | Q5_K | 65.76% | 33.77% | 5.92 |
| Qwen3.8-4B i1-Q2_K | Q2_K/Q3_K/Q4_K | 72.63% | 26.62% | 5.53 |

Q4_K_M and Q6_K differ by +0.22, -0.15, -0.44, and +0.29 GB/s across the four
blocks, with a mean of -0.02. Q5_K_M and Q2_K sit about 30% below both. The bulk
format tracks the two observed groups: a Q4_K trunk and a Q6_K trunk reach about
8.1 GB/s, while a Q5_K trunk reaches 5.9 and a Q2_K/Q3_K trunk reaches 5.5.
Four points establish the grouping and leave its mechanism conjectural.

The four points do sort by Q6_K share, and the shape refuses to be read as one.
A 4.59 point rise from 33.77% to 38.36% carries a 37% rate change while the 61.22
points from 38.36% to 99.58% carry 0.2%. That is two groups that happen to order,
rather than a response to the share.

An earlier revision of this file read a three-point series as monotonic in Q6_K
share and concluded that reconstruction arithmetic bounds decode. The prediction
that carried it registered its own falsifier -- a Q6_K achieved rate at or below
Q4_K_M's -- and the two measure within 0.3% of each other. Both readings are
withdrawn.

What separates the groups stays conjecture. Q4_K and Q6_K each reconstruct a
weight from one contiguous quantized field plus block scales, while Q5_K adds a
separate high-bit plane and Q2_K/Q3_K add per-weight indirection, which would put
the cost in the number of memory operations per weight rather than in their
width. The discriminating measurement is an IQ4_XS or Q3_K_M arm: either landing
in the 8 GB/s group breaks the reading.

## The 2B difference remains architectural and unattributed

The 2B streams 10.41 GB/s against the deployed 4B's 8.11, and its 30.6% spread
overlaps the 4B's range in block B. It carries 24 layers against 32 and also
changes hidden width and tensor shapes under the same Q4_K_M recipe. The paired
ordering therefore survives while attribution to depth, width, or shape remains
open. `evidence/qwen38-2b-distill-candidate.md` holds the refutation of the
linear size-cost model that this supports.

## The 3.01 tok/s mean requires 42.67% total time removal

The 3.01 tok/s reference spends 332.226 ms per token. The 5.25 tok/s target
allows 190.476 ms, so the target removes 141.750 ms per token and requires a
1.7442x end-to-end speedup. Amdahl's law gives the minimum accelerated fraction
for a mechanism with speedup `s`:

```text
required_fraction = (1 - 3.01 / 5.25) / (1 - 1 / s)
```

| mechanism speedup | minimum share of current token time |
| ---: | ---: |
| 2x | 85.33% |
| 4x | 56.89% |
| 31/19 | 110.22%, impossible |
| unbounded | 42.67% |

The 42.67% floor belongs to the 3.01 tok/s four-block mean. The individual
Q4_K_M arms span 2.68 to 3.28 tok/s, so their required time reductions span
48.95% to 37.52% and their end-to-end speedups span 1.959x to 1.601x. A matched
control beside a candidate selects the applicable coefficient; the mean does
not erase the reported run-order variation.

The tied Q6_K output projection carries 19.33% of the 4B logical streamed
bytes. That byte share does not establish its time share. A tied-projection-only
route reaches the target only if successful-run timing shows that the projection
owns at least 42.67% of token time and the candidate removes nearly all of that
cost. The logical byte share alone cannot meet the bound.

At unchanged Q4_K_M bytes, 5.25 tok/s requires 14.1636 logical GB/s. The exact
3.01-rate product equals 8.12049 GB/s, while the table's rounded block mean is
8.11 GB/s. Q2_K at the Q4_K_M achieved streaming rate would reach only
4.26 tok/s; Q2_K requires 9.9986 logical GB/s for 5.25 and currently reaches
5.53. The missing coefficient is therefore kernel efficiency as well as bytes.

The [AMD processor catalogue](https://www.amd.com/en/products/specifications/processors.html)
lists DDR4-2400 as the Athlon Silver 3050U's maximum memory speed. The
[retained UMC measurement](measurement-state-and-memory-clock.md#memory-is-trained-at-ddr4-2133-the-reported-steps-are-dynamic-fclk)
reports 2133.33 MT/s on both populated channels. Their counterfactual ratio is
`2400 / 2133.33 = 1.125`. A model that assigns all token time to DRAM rate moves
3.01 only to 3.386 tok/s. That model cannot close the target gap and does not
predict the hardware response; matched UMC and decode measurements remain the
falsifier for nonlinear interactions.

The N=1 MTP arm exposes the same structural limit from another direction. A
two-column target pass costs 463.1 ms and one draft pass costs 66.4 ms, or 1.432
and 0.205 one-column target passes. Even perfect acceptance and a free draft can
emit at most two tokens per 463.1 ms, which is 4.319 tok/s. The free-draft bound
requires the two-column target pass to drop below 380.952 ms. Retaining the
reported 66.4 ms draft pass tightens that target-pass bound to 314.552 ms. These
are whole-pass coefficients; successful-run timestamps remain necessary before
assigning either value to a shader. Acceptance alone cannot cross the target.

Perfect N=1 acceptance at both measured pass costs reaches
`2 / (0.4631 + 0.0664) = 3.777` tok/s. The retained draft cost therefore makes
the target pass remove 148.548 ms, or 32.08% of its measured latency, before the
pair reaches 5.25 tok/s. A `31/19` local speedup must own 82.87% of the target
pass to remove that much time. The one-column target pass costs 323.4 ms, and
even recovering that cost with perfect acceptance reaches only 5.1308 tok/s at
the reported 66.4 ms draft cost. The 4B route therefore also reduces draft cost
or drives the target pass below the historical one-column cost. This coupling orders the search: successful-run timing
first identifies target-pass time that a kernel or submission change can remove;
draft and acceptance changes then multiply a target pass that already satisfies
the 314.552 ms bound. `evidence/throughput-target-analysis/` retains the exact
rational coefficients and the supersession of the 4.5 tok/s calculations.
