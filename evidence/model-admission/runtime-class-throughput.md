# Runtime-class throughput: three unmeasured classes against three in-sweep anchors

`evidence/model-admission/static-admission.md` collapses fourteen load-admitted
candidates into four runtime classes by architecture, embedding width,
feed-forward width, and head counts. One class holds a measured reference at the
format its members publish and three do not. This sweep measures those three,
each beside anchors measured in the same queue, because the same checkpoint
under identical flags spans up to 30.6% on this machine between sweeps and a
comparison is only readable within one.

## Subjects and anchors

Streamed bytes come from `remote/gguf-tensor-census.py`, which is what
`run-bandwidth-ladder.sh` reads rather than the file size, since an ordinary
load skips the multi-token-prediction block.

| role | checkpoint | class | streamed bytes/token |
| --- | --- | --- | ---: |
| anchor | Qwen3.8-4B Distill Q4_K_M | qwen35 / 3072 / 9728 | 2,698,000,000 |
| anchor | Qwen3.8-2B Distill Q4_K_M | qwen35 / 2048 / 6144 / 8 / 2 | 1,263,435,008 |
| anchor | Qwen3.5-0.8B Q8_0 | qwen35 / 1024 / 3584 / 8 / 2 | 800,881,920 |
| subject | Qwen3.5-0.8B Q4_K_M (bartowski) | qwen35 / 1024 / 3584 / 8 / 2 | 546,905,344 |
| subject | Qwen3-Zero-Coder-Reasoning-0.8B Q4_K_M | qwen3 / 1024 / 3072 / 16 / 8 | 477,341,696 |
| subject | Qwen2-VL-2B-Instruct-Platinum Q4_K_M | qwen2vl / 1536 / 8960 / 12 / 2 | 980,097,536 |

The class of eight rows at 2048/6144 already holds its reference and contributes
one anchor rather than a second subject: those eight span 0.83% in streamed
bytes, which is below the roughly 4% of uncontrolled spread this machine carries
on a repeated depth-0 rate, so a second arm inside that class measures queue
position.

Three anchors rather than one, because the sweep-level offset is the term that
made every absolute band in the retained seven-checkpoint sweep read low. The 4B
distill is the low-variance member of that sweep at 0.3% forward against
reverse, where the 2B distill and the 0.8B Q8_0 spanned 7.2 and 7.5%, so the
offset estimate rests on the quietest row rather than on the two noisiest.

The 0.8B Q8_0 anchor and the 0.8B Q4_K_M subject are the same checkpoint in two
value formats. `universal-candidate-ladder.md` names that pair as the arm its
own Q8_0 finding needs: "Separating them needs a Q8_0 and a Q4_K_M of the same
checkpoint in one sweep." The bartowski conversion supplies it, so this sweep
closes a registered open question as a by-product of the class work.

## Registered before the sweep runs

A prediction band on this machine states a ratio against a checkpoint measured
in the same sweep. Every band below is a decode ratio `R` against the Qwen3.8-2B
Distill arm of this sweep, and the achieved-rate ratio it implies follows from
`R = (achieved_subject / achieved_2B) x (streamed_2B / streamed_subject)`.

### The 0.8B format pair discriminates size against format

Two accounts predict opposite outcomes and the arm separates them.

The size account reads the retained sweep's ordering, where achieved GB/s rises
as the trunk shrinks across the 4B, 3B, and 2B classes. At 0.547 GB against the
Q8_0's 0.801 GB, it predicts the Q4_K_M exceeds the Q8_0's achieved rate, which
was 1.278 times the 2B distill's in the retained sweep.

The format account reads the unpacking cost. Q4_K decodes hierarchical
super-block scales where Q8_0 applies one scale multiply, and the retained
sweep's Q4_K trunk reached 11.6 to 12.5 GB/s against Q8_0's 14.84. It predicts
the Q4_K_M lands in the Q4_K trunk band, at roughly the 2B distill's achieved
rate with a small rise for the smaller trunk.

```text
size account:      R above 2.95   (achieved ratio above 1.28)
format account:    R 2.31 to 2.54 (achieved ratio 1.00 to 1.10)
discriminator:     R below 2.70 supports format
                   R above 2.95 supports size
                   between 2.70 and 2.95 resolves neither
falsifier:         R outside 2.0 to 3.6
```

### Deep and narrow tests the per-dispatch account

Qwen3-Zero-Coder-Reasoning-0.8B runs 42 blocks at 1024 embedding width against
the 0.8B class's 24, which is 1.75 times the dispatch count at 87% of the bytes.
The retained sweep inferred a per-layer or per-dispatch cost from LFM2 breaking
the size ordering, and this row tests that account inside the Qwen family at one
value format.

```text
prediction:  achieved_zero-coder is below achieved_bartowski, both in this sweep
             R 2.0 to 2.6 (achieved ratio 0.76 to 0.98 against the 2B distill)
falsifier:   achieved_zero-coder at or above achieved_bartowski, which refutes
             the per-dispatch account at this scale and returns the LFM2
             anomaly to the operator-mix explanation alone
             R outside 1.6 to 3.1
```

### The first qwen2vl arm on this device carries the widest band

Qwen2-VL-2B-Instruct-Platinum runs 28 blocks of full attention at 12 heads over
2 KV heads, against the Qwen3.5 hybrid's 3:1 pattern, and no `qwen2vl` operator
has run here.

```text
prediction:  R 1.22 to 1.48 (achieved ratio 0.95 to 1.15)
falsifier:   R outside 1.0 to 1.8
```

### The anchor pair controls the sweep itself

The retained seven-checkpoint sweep put the 4B distill at 0.3634 of the 2B
distill's decode. If this sweep reproduces that ratio within 5%, its ordering
carries no term the retained sweep lacked and the subject ratios read directly.

```text
prediction:  4B/2B decode ratio 0.345 to 0.382
falsifier:   outside that band, which makes every subject ratio conditional on a
             checkpoint-ordering term this sweep introduced
```

## Acceptance criterion, stated before the numbers

The retained sweep ran at one-minute load average 3.5 to 4.6 and produced
forward-against-reverse spans of 0.3% to 7.5%, which it called quiet. A
checkpoint whose two passes span more than 8% here reports its position in the
queue rather than the checkpoint, and that arm is re-run rather than read.

## What this sweep leaves unmeasured

The `qwen2vl` arm runs under `llama-bench`, which loads the language model
alone, so the figure is text-trunk throughput and carries nothing about image
encoding.

The two 9B rows admitted statically -- `qwen35-9b-defiant-fable` at IQ2_M and
`qwen38-9b-distill` at Q4_K_M -- are absent from the appliance and from the
one-token load sweep. Each needs a fetch and a strict Vulkan load before a
throughput arm, and the IQ2_M would be this tree's first IQ-family measurement,
which is a finding of its own rather than a rider on this one.

A rate admits a row to the throughput stage and promotes nothing.
`remote/models.tsv` carries twenty-two fields per row, including a validated
filled depth, a submission geometry, a tier, and the two tool columns, and a
promotion also needs a `download-*.sh` carrying the publisher digest.

## Results

Twelve arms, six checkpoints, forward and reverse, `nice 19` read back from
`/proc` on every arm, `mclk` at 1067 throughout, die temperature 84 to 89 C,
one-minute load average 3.97 to 4.88 with peaks to 5.45.

| checkpoint | streamed/token | decode fwd | decode rev | paired decode | paired prefill | achieved GB/s | span |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3-Zero-Coder-0.8B Q4_K_M | 0.477 GB | 15.75 | 16.17 | 15.96 | 102.18 | 7.62 | 2.6% |
| Qwen3.5-0.8B Q4_K_M | 0.547 GB | 15.21 | 15.12 | 15.17 | 134.91 | 8.30 | 0.6% |
| Qwen3.5-0.8B Q8_0 | 0.801 GB | 15.24 | 15.38 | 15.31 | 146.22 | 12.27 | 0.9% |
| Qwen2-VL-2B Platinum Q4_K_M | 0.980 GB | 8.52 | 8.49 | 8.51 | 63.09 | 8.34 | 0.4% |
| Qwen3.8-2B Distill Q4_K_M | 1.263 GB | 8.46 | 7.72 | 8.09 | 54.28 | 10.22 | **9.2%** |
| Qwen3.8-4B Distill Q4_K_M | 2.698 GB | 3.41 | 2.95 | 3.18 | 21.05 | 8.58 | **14.5%** |

## The acceptance criterion fires on both anchors and on neither subject

The criterion registered before the run admits a span of 8%. The four subject
rows span 0.4 to 2.6%. Both anchors exceed it, the 4B by nearly double, so the
4B-against-2B control and every ratio that divides by the 2B distill wait on a
re-run and the comparisons between rows that each met the criterion stand.

## The spread lives between arms rather than inside them

`llama-bench` reports a standard deviation over the three repetitions of an arm,
and those deviations are an order of magnitude smaller than the disagreement
between an arm and its own reverse:

| checkpoint | forward | reverse | widest within-arm | between-arm |
| --- | --- | --- | ---: | ---: |
| Qwen3.8-4B Distill | 3.41 +/- 0.01 | 2.95 +/- 0.01 | 0.3% | 14.5% |
| Qwen3.8-2B Distill | 8.46 +/- 0.36 | 7.72 +/- 0.04 | 4.3% | 9.2% |
| Qwen2-VL-2B | 8.52 +/- 0.09 | 8.49 +/- 0.04 | 1.1% | 0.4% |
| Qwen3.5-0.8B Q8_0 | 15.24 +/- 0.20 | 15.38 +/- 0.15 | 1.3% | 0.9% |

The 4B's two arms are each internally reproducible to 0.3% over three
repetitions and disagree with each other by 14.5%, so raising the repetition
count cannot narrow it: what varies is the machine's state between arms, and
three more repetitions inside one state measure that state better. The
consequence for this tree is that `llama-bench`'s reported deviation is not the
uncertainty of a rate here, and a rate quoted with it understates its own
spread fiftyfold on the 4B row.

Load does not order the effect. The 0.8B Q8_0 reverse arm ran at the sweep's
highest load peak, 5.45, and landed 0.9% from its forward pass, while the 4B
reverse arm at 5.29 landed 14.5% from its own. The instability instead tracks
checkpoint size, which is what the 0.8B rows below explain: where a per-token
cost the desktop does not contend for sets the rate, the rate is stable.

## Three checkpoints at one rate across a 68% spread in bytes

The three members of the 0.8B runtime classes decode at 15.96, 15.17, and 15.31
tokens per second while streaming 0.477, 0.547, and 0.801 GB per token. The
rates span 5.2% where the byte counts span 67.9%, across two value formats and
two architectures, and every one of those six arms met the span criterion.

Decode at this scale is therefore not bandwidth-bound. A per-token cost near 63
to 66 ms sets the rate and the weight stream is not the term that resolves. The
same device streams 2.698 GB per token at 3.18 tok/s on the 4B, which is 314 ms
per token, so the fixed term is a fifth of the small-model budget and a
fiftieth of the large one.

## The format arm refutes both registered accounts

Qwen3.5-0.8B at Q8_0 and at Q4_K_M is one checkpoint, one trunk, and one
25-block shape in two value formats, measured in adjacent slots of one sweep.
This is the arm `universal-candidate-ladder.md` names as missing.

```text
Q8_0     0.801 GB/token   15.31 tok/s   12.27 GB/s
Q4_K_M   0.547 GB/token   15.17 tok/s    8.30 GB/s
```

The Q8_0 streams 46.4% more bytes and decodes 0.9% faster.

The registered discriminator was expressed as `R` against the 2B distill, and
that anchor failed its own span criterion in this sweep, so `R` is unevaluable
here. The direct pair answers the question without it, because both accounts
predicted the same direction and the measurement runs the other way. The size
account put the Q4_K_M above the Q8_0's achieved rate, which is 22.4 tok/s at
0.547 GB per token; the format account put it at the Q4_K trunk's rate, which is
18.7 to 20.6 tok/s. Both therefore predicted the Q4_K_M decodes faster than the
Q8_0, and it decodes 0.9% slower. Fitting a fixed cost plus a bandwidth term
across the pair gives a negative bandwidth term: more bytes, marginally less
time.

Q4_K_M buys nothing over Q8_0 on this checkpoint. That extends a result this
tree already holds at 4B, where i1-Q2_K streams 29.4% fewer bytes than Q4_K_M
and decodes no faster, down to the 0.8B class, and it means the served
`qwen35-08b` Q8_0 row already occupies the better position of the two. A
promotion of any Q4_K_M rung of this class competes on quality rather than on
throughput.

The prefill halves separate where the decode halves do not: 146.22 against
134.91 tokens per second, an 8.4% advantage to Q8_0 at 46.4% more bytes.
Prefill processes 512 tokens against one weight read, so it is the half where
arithmetic rather than a per-token cost dominates, and Q4_K's super-block scale
decode shows up there.

The span criterion is stated for decode and this claim rests on prefill, so it
is applied to prefill here as well. The Q8_0 arms read 145.69 and 146.75, a 0.7%
span, and the Q4_K_M arms read 134.49 and 135.32, a 0.6% span. Both pass, and
the 8.4% separation is an order of magnitude above either.

## The per-dispatch prediction holds

Qwen3-Zero-Coder-Reasoning-0.8B runs 42 blocks at 1024 embedding width against
the Qwen3.5-0.8B's 24, at 87.3% of its streamed bytes. The registered prediction
was that it achieves below the Qwen3.5-0.8B Q4_K_M in this sweep.

```text
Qwen3-Zero-Coder   0.477 GB/token   7.62 GB/s achieved
Qwen3.5-0.8B       0.547 GB/token   8.30 GB/s achieved
```

Confirmed at 8.2% below. The prefill halves separate it much harder than the
decode halves -- 102.18 against 134.91, a 24.3% deficit -- which is the sign the
per-dispatch account predicts, since prefill issues the same 42-block graph over
a 512-token batch where decode amortizes it against the fixed per-token cost.
Its decode rate is nonetheless the highest in the sweep at 15.96 tok/s, so the
deep-narrow shape costs achieved bandwidth and buys tokens.

The registered `R` band of 2.0 to 2.6 divides by the 2B distill arm that failed
its span criterion, so the magnitude is unevaluable in this sweep while the
directional claim, which compares two rows that each met it, is confirmed.

## Qwen2-VL is the second architecture to break the size ordering

The first `qwen2vl` measurement on this device is also the sweep's steadiest row
at a 0.4% span. It streams 0.980 GB per token, 22.4% below the 2B distill, and
achieves 8.34 GB/s against that checkpoint's 10.22 -- below every Qwen3.5 row in
the sweep except the deep-narrow Zero-Coder, and below the 4B distill's 8.58 at
36% of its byte count.

`evidence/model-admission/universal-candidate-ladder.md` recorded LFM2 breaking
its size ordering and read it as operator mix. A second architecture breaking it
in the same direction, with 28 blocks of full attention at 12 heads over 2 KV
heads against the Qwen3.5 hybrid's 3:1 pattern, supports that reading over a
byte-count account. This row carries into the anchor re-run below, where its `R`
becomes evaluable against an anchor that met the criterion.

The arm runs under `llama-bench`, which loads the language model alone, so this
is text-trunk throughput and carries nothing about image encoding.

## The anchor re-run

The criterion required a re-run of the two anchors, and a re-run in a separate
invocation is a separate queue position, which is the term the within-sweep rule
exists to remove. Both anchors and the one subject whose ratio depends on them
therefore ran again as a single sweep with each checkpoint listed twice, so
every one took four well-separated slots of twelve rather than two of twelve.

| checkpoint | slots | decode mean | span | prefill mean | achieved GB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-4B Distill Q4_K_M | 4 | 2.985 | 4.4% | 20.45 | 8.06 |
| Qwen3.8-2B Distill Q4_K_M | 4 | 7.685 | 1.2% | 50.90 | 9.71 |
| Qwen2-VL-2B Platinum Q4_K_M | 4 | 8.407 | 2.4% | 62.40 | 8.24 |

Every row meets the 8% criterion on decode. The 4B's four slots read 3.08, 2.96,
2.95, and 2.95, which places the first sweep's 3.41 outside the other five
measurements of that checkpoint, and the 2B's read 7.66, 7.73, 7.64, and 7.71
against a first-sweep pair of 8.46 and 7.72. In both anchors the high value came
from an early forward slot of the first sweep, and the settled value is the
lower one.

The 4B's prefill still spans 12.5% while its decode spans 4.4%, so the prefill
half of that row remains unresolved at four slots and no prefill claim rests on
it.

### The anchor control fails, and the way it fails is the finding

```text
retained seven-checkpoint sweep    4B/2B decode ratio 0.3634
this re-run, four slots each       4B/2B decode ratio 0.3884
nominal 95% interval               0.3801 to 0.3968
registered band                    0.345 to 0.382
```

The interval's lower edge touches the band's upper bound, so the control is
violated narrowly rather than decisively. What it exposes is larger than the
margin. Against the retained sweep the 4B fell 10.6% and the 2B fell 16.4%, so
the sweep-level term is not one scalar per sweep: it acts more strongly on the
smaller checkpoint and moves the ratio between two checkpoints by 6.9%.

`universal-candidate-ladder.md` proposed exactly that scalar as the remedy for
its bands reading low, applying one 11.1 to 11.5% offset across four
predictions. This sweep refutes the remedy while leaving the diagnosis intact.
The rule it produced still holds and now holds more narrowly: a ratio against an
in-sweep checkpoint is more stable than an absolute rate and is not invariant
either, so a cross-sweep ratio carries about 7% of uncontrolled term on this
pair and a difference below that reports the sweep.

The same ordering appears inside the pair of sweeps run minutes apart. Against
its own first-sweep paired mean the 4B fell 6.1%, the 2B fell 5.0%, and
Qwen2-VL fell 1.2%, which is the size dependence again at a tenth of the
magnitude.

### Qwen2-VL against an anchor that met the criterion

```text
Qwen2-VL 8.407 tok/s / 2B distill 7.685 tok/s = R 1.094
registered band   1.22 to 1.48
falsifier         outside 1.0 to 1.8
```

Inside the falsifier and below the band. Qwen2-VL streams 22.4% fewer bytes per
token than the 2B distill and decodes 9.4% faster, where a bandwidth-bound
account predicts 28.9% faster. It achieves 8.24 GB/s against the 2B distill's
9.71 in the same sweep, so the size ordering breaks here on rows that both met
the span criterion and the reading stands: the operator mix rather than the byte
count sets achieved rate across architectures.
