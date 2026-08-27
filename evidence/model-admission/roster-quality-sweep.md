# The 55-row graded suite across every servable checkpoint

`remote/run-quality-roster.sh` grades every production and candidate row of
`remote/models.tsv` against `remote/quality-suite.tsv` through the one router
listener the appliance already serves. Rate is measured for seven checkpoints in
`evidence/model-admission/universal-candidate-ladder.md` and quality is graded
for four, so three of the six servable rows carry a `candidate` tier that claims
device safety and leaves quality unqualified. This sweep is what closes that gap.

## Terms

```text
endpoint:      http://127.0.0.1:8080, router mode, --models-max 1
thinking:      off, through chat_template_kwargs.enable_thinking
token budget:  1024
long context:  24000 filler characters, 4216 tokens by the served tokenizer
sampling:      temperature 0, top_k 1, seed 1
geometry:      batch 128, ubatch 32, q8_0/q4_0, Flash Attention on, from the
               preset file rather than the router argv
```

Each arm names its checkpoint in the request body and asserts the id the
response came back with. The router answers 400 for a name it does not hold --
`model 'qwen-apu' not found` for the id the suite runner formerly hardcoded --
so a mis-routed arm fails rather than grading the default preset under another
name.

## What the ordering costs

The arms run model-major. The router holds one child at a time, so row-major
would evict and reload on every request and pay a cold first token 55 times per
checkpoint against six loads for the whole sweep. What that buys in wall time it
gives up in rate comparability: the first and last arms are hours apart, and
this tree reads a rate within a sweep. **The per-row decode figures this sweep
records are incidental to the grade.** Rate comparisons belong to the
seven-checkpoint bandwidth ladder, which met all seven checkpoints inside one
queue in forward and reverse order.

## What a passing long-context column does not establish

Every servable row admits at least 8192 tokens and the padded prompt occupies
4216, so the long-context rows sit well inside every allocation. The 4B distill
reads `validated_filled_depth` 16384 and the other five read `-`. A passing
long-context column measures retrieval past a 4216-token prefix and leaves the
allocation-beyond-validation gap exactly where the registry states it.

## The arithmetic gate

The 10 arithmetic rows ran first across all six checkpoints, as a gate rather
than a warm-up: they check model selection, per-template acceptance of the
thinking keyword, and termination at a small budget for the cost of minutes.

| checkpoint | arithmetic | empty | truncated | wall s |
| --- | ---: | ---: | ---: | ---: |
| LFM2.5-VL-1.6B | 9/10 | 0 | 0 | 10.9 |
| Qwen3.8-4B Distill | 8/10 | 0 | 0 | 35.8 |
| Qwen3.8-2B Distill | 7/10 | 0 | 0 | 14.0 |
| Qwen3.5-4B base | 7/10 | 0 | 0 | 38.0 |
| Qwen3.5-2B | 6/10 | 0 | 0 | 15.2 |
| Qwen3.5-0.8B | 5/10 | 0 | 0 | 7.1 |

The gate passed on the terms it was built to check. Every arm completed every
row with a non-empty, untruncated reply, every served id matched its arm, and
both non-Qwen and Qwen templates accepted `enable_thinking: false` -- LFM2.5-VL
returns an empty reasoning span under it rather than refusing the keyword.

`arith-02`, `floor(1073 / 63)`, fails on all six. A row every checkpoint misses
is the shape of a grader defect, and this one is not: the answer is 17, the six
replies are 16, 16, 16, 10, 1, and 17, and four of them are the same near miss.
`arith-06`, `7 - 3 x 6`, fails on four as an operator-precedence error, and
`arith-10` fails on four as the mean 4.5 rounded to 5.

Thinking state governs this category. `evidence/qwen38-2b-distill-quality.md`
records the 4B base spending 2048 predicted tokens on a reasoning span and
returning an empty answer; with thinking off at 512 tokens the same checkpoint
answers all ten arithmetic rows and gets seven right.

## Registered before the full results are read

The gate is already in hand, so these predictions are registered against a
partially informed prior rather than a blind one, and that is stated rather than
concealed.

| # | prediction | falsifier |
| --- | --- | --- |
| 1 | Total pass rate orders by parameter count inside the Qwen family | the 0.8B outscores either 2B row, or a 2B row outscores a 4B row by more than 3 of 55 |
| 2 | LFM2.5-VL's arithmetic lead does not extend to the whole suite | LFM2.5-VL leads the total by more than 3 rows |
| 3 | Completion stays uniform at a 1024-token budget with thinking off | any arm reports a completion rate below 0.95 |
| 4 | The suite separates Qwen3.5-2B from the 2B distill, which decode measurement left unresolved at 2.6% | the two land within 2 rows of each other |

