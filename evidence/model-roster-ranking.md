# The roster, ranked, and what each tier claims

Ten checkpoints sit on the appliance. Rank and tier answer different questions
and are recorded separately: rank orders how useful a checkpoint is to serve
here, tier states what has been established about running it. A fast checkpoint
with no validated safe tuple ranks above a slow one and still stays out of the
picker.

## The tiers

| tier | claim | occupants |
| --- | --- | --- |
| `production` | a declared serving tuple is measured safe and useful | Qwen3.8-4B Distill, Qwen3.8-2B Distill, Qwen3.5-4B base |
| `candidate` | quality or performance unqualified, no reset or fault under its admitted tuple | empty |
| `quarantine` | a reset, fault, device loss, correctness hazard, or no validated safe tuple | Nanbeige4.2-3B; the Qwen 4B `16384/2048/512` profile |
| `archive` | a valid artifact displaced, or too slow to serve | Qwen3.8-9B Distill, both 27B quants |
| `rejected` | lost admission on measurement without being dangerous | Qwen3.8-4B i1-Q2_K, i1-Q5_K_M, i1-Q6_K |

`candidate` is empty on purpose. It is the tier the four unfetched universal
candidates enter after basic admission, and using it for a checkpoint that has
wedged the ring would make the word mean two things at once.

Two tiers of quarantine exist because the failure unit is not the checkpoint.
Nanbeige is quarantined as a model: no geometry of it has been validated at
depth. The Qwen3.8-4B Distill is not quarantined at all; one tuple of it is,
`16384` at batch 2048 and ubatch 512, and the same checkpoint at the same depth
and cache triple serves at `128/32` and `32/8`.

## The ranking

Decode is quoted in two classes and they are not interchangeable. The single-arm
column is the registry's llama-bench figure; the sweep column is the four-block
mean from `evidence/decode-bound-analysis.md`, where the same checkpoint under
identical flags spans up to 30.6%. A difference below about 20% between the two
columns reports queue position rather than the checkpoint.

| rank | checkpoint | tier | decode single-arm | decode sweep mean | streamed/token | quality | why here |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- |
| 1 | Qwen3.8-2B Distill Q4_K_M | production | 9.46 | 8.24 | 1.263 GB | 4/5 | the only checkpoint that decodes faster than a person reads |
| 2 | Qwen3.8-4B Distill Q4_K_M | production | 3.07 | 3.01 | 2.698 GB | 5/5 | top quality grade at the highest rate that reaches it |
| 3 | Qwen3.5-4B base Q4_K_M | production | 2.84 | - | 2.540 GB | 4/5 | the only checkpoint on disk that sees |
| 4 | Qwen3.8-9B Distill Q4_K_M | archive | 1.76 | - | 5.046 GB | 5/5 | same grade as rank 2 at 57% of its rate |
| 5 | Qwen3.8-4B i1-Q2_K | rejected | - | 2.90 | 1.905 GB | untested | 29.4% fewer bytes buys no tokens |
| 6 | Nanbeige4.2-3B Q4_K_M | quarantine | 2.38 | - | 4.149 GB | untested | nominally 3B, streams like a 6B |
| 7 | Qwen3.8-4B i1-Q6_K | rejected | - | 2.35 | 3.453 GB | untested | more bytes, same achieved rate, fewer tokens |
| 8 | Qwen3.8-4B i1-Q5_K_M | rejected | - | 1.93 | 3.064 GB | untested | the worst achieved rate measured on this machine |
| 9 | Qwen3.8-27B UD-Q2_K_XL | archive | - | - | - | untested | host preflight refuses the load |
| 10 | Qwen3.8-27B UD-IQ3_XXS | archive | - | - | - | untested | host preflight refuses the load |

## What each rank rests on

**1. Qwen3.8-2B Distill.** It decodes three times the 4B and streams faster per
byte doing it, 10.41 GB/s against 8.11 on the mean of four sweeps with the 2B
ahead in all four pairs. It carries 24 layers against 32 and six full-attention
layers against eight, which is 4,992 bytes of KV per token of context against
13,312, so it is also the cheapest checkpoint to run deep. Its quality grade is
4/5 rather than 5/5 and the gap is elementary arithmetic, which is why the
roster separates `fast-text` from `balanced-text` rather than promoting it.

**2. Qwen3.8-4B Distill.** The default. It reasons in 43.3% of the base model's
tokens and reaches an answer 2.71 times faster across the five-prompt suite at
the same 5/5 grade. It is the one row in the registry carrying a
`validated_filled_depth`: 16384 filled and decoded at `128/32` with `q8_0`/`q4_0`
and Flash Attention on, from `evidence/depth-versus-submission-geometry.md`. Its
24576 interactive default is an allocation and remains unvalidated at occupancy,
which the registry now states as two fields rather than one.

**3. Qwen3.5-4B base.** It ranks third on rate and first on a capability nothing
else has. `remote/select-projector.sh` pairs `mmproj-F16.gguf` from the
checkpoint's own directory, and every distill on disk ships text-only. It also
produced an empty answer at the 2048-token cap, which is the failure mode the
distills exist to avoid, so it holds the vision role rather than a general one.

**4. Qwen3.8-9B Distill.** Archived rather than rejected: it earns the same 5/5
grade as the 4B distill and is a valid artifact. At 1.76 tok/s it takes 1.74
times as long to say the same thing, and 5.046 GB per token against 2.698 is
where that goes. It returns if a task appears whose quality requirement exceeds
what 5/5 on a five-prompt suite resolves.

**5, 7, 8. The i1 ladder.** All three are rejected on the same measurement and
none is dangerous. Q4_K_M leads i1-Q2_K, i1-Q5_K_M, and i1-Q6_K in every one of
four blocks. Q2_K streams 29.4% fewer bytes per token and never reaches the
registered 3.5 tok/s floor, which closes the route downward; Q6_K and Q5_K_M
close it upward. The reason is that achieved streaming groups by bulk format
rather than by bit width -- a Q4_K trunk and a Q6_K trunk both reach about 8.1
GB/s where a Q5_K trunk reaches 5.9 and a Q2_K/Q3_K trunk 5.5 -- so fewer bytes
at a slower kernel is a wash. The tested K-quant ladder is exhausted as a
performance lever. IQ and other reconstruction kernels stay unmeasured.

**6. Nanbeige4.2-3B.** It ranks sixth on a rate it earns honestly and it is
quarantined for what has not been measured. `nanbeige.cpp` reads
`{arch}.num_loops` and runs 22 physical layers twice per token over one copy of
the weights, so a nominal 3B streams 4.149 GB per token, between the 4B and the
9B. Every one of its 44 effective slots keeps its own KV index against eight
full-attention layers in the 32-layer Qwen hybrid, which is 73,216 bytes of
cache per token of context against 13,312, and 1716 MiB against 312 at 24576.
The gap widens exactly where an agent workload lives. Its quarantine ground is
`no-validated-safe-tuple`: every measurement of this checkpoint is at depth 0.
`evidence/quarantine/nanbeige42-3b.md` carries the re-entry gate and records
that the reset attributed to it in prose has no retained arm record.

**9, 10. The 27B pair.** Archived on capacity rather than instability. Neither
has ever been loaded: `model-memory-preflight.sh` returns 3 for both, reporting
15,474,085,888 available host bytes against a 24,861,367,200-byte requirement
for `UD-Q2_K_XL` and 15,480,442,880 against 27,040,988,064 for `UD-IQ3_XXS`. A
rejected preflight is a capacity result, and swap does not convert it into
permission to load. They occupy 20 GB and stay for the comparison, not for the
picker.

## What the ranking does not answer

Quality is graded for four checkpoints and untested for six. The 55-row suite
has never run against Nanbeige, against any i1 rung, or against either 27B
quant, so ranks 5 through 10 are ordered on rate and admission alone. A
checkpoint that answers better at 2.38 tok/s remains a legitimate choice for
work that is not interactive; the measurement sets the price rather than the
verdict.

Tool calling and vision are outside the graded suite entirely. The roster claims
that Qwen3.5-4B base sees, on the strength of a projector that pairs and loads,
and it does not claim how well.

## The four candidates that are not here yet

`remote/download-qwen35-08b-q80.sh`, `download-lfm25-vl-16b-q4km.sh`,
`download-qwen35-2b-q4km.sh`, and `download-ministral3-3b-q4km.sh` pin the
universal-candidate ladder with byte counts and SHA-256 digests verified against
the publishers. They hold no registry row, because `candidate` claims basic
admission and none has been fetched.

Nanbeige is the standing warning against ranking them by parameter count before
they arrive. It is nominally the smallest of the non-Qwen checkpoints on disk
and it streams more per token than the 4B it is smaller than. The two numbers
that predict rank on this machine are streamed bytes per token and KV layer
count, and `remote/gguf-tensor-census.py` reads both from the first 48 MiB of a
file through a range request, so both are available before 7.2 GB is fetched.
