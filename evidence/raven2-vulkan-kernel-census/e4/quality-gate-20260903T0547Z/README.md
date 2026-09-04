# E4 quality gate: 40 of 65 on every arm, the same 40, and 64 of 65 replies byte-identical

```text
control=census v7 (addcae10...), Vulkan0    candidate=census+E4 (741a0d76...), Vulkan0
model=qwen38-2b-distill under its registry tuple, standalone llama-server aliased to the registry id
suite=remote/quality-suite.tsv text categories: arithmetic, screen, word_problem, termination, format, tool, long_context, code (65 rows)
max_tokens=1024  thinking=off  long_context_characters=24000  order=C K K C  one sweep, 2026-09-03 05:47Z to 06:53Z
verdict=quality_nonregression held
```

## Result

| arm | passed | completion rate | attribution failures | wall seconds |
| --- | ---: | ---: | ---: | ---: |
| 1-C | 40/65 | 0.969 | 0 | 1019 |
| 2-K | 40/65 | 0.969 | 0 | 999 |
| 3-K | 40/65 | 0.969 | 0 | 973 |
| 4-C | 40/65 | 0.969 | 0 | 983 |

The four passed sets are equal row for row. Both binaries answer every one
of the 65 rows identically across their two arms, so the sweep is
deterministic within each binary. Between binaries, 64 of 65 replies are
byte-identical; the one that differs is `screen-04`, a `contains_all` row
on Canberra that both binaries pass, where the replies agree for 186
characters and then close with different clauses ("the de facto capital
before the decision was made" against "the original capital of the colony
of New South Wales"), 49 tokens against 50.

## Reading

E4's arithmetic changes the selected log-probability by up to a few
hundredths of a nat and flips an argmax only at ties below that distance
(`../margin-holdout-20260903T0456Z/`). On the graded suite that produces
one late-reply divergence in 65 rows and moves no grade, which is the
quality line of the correctness matrix: E4 serves the same answers where
the answer is determined and a different wording where the model was
already at a coin toss. The 40 of 65 itself is the 2B distill's grade with
thinking off at this budget and is read against the control inside this
sweep alone; it is not compared with the roster sweep's figures for other
checkpoints, which ran under another sequence.

```text
deterministic                 held
argmax_identity               held on 10 of 12 holdout prompts; flips at ties of 0.0001 and 0.0023 nat
margin_retention              held on every read position, minimum 0.786
numerical_identity            refuted
quality_nonregression         held: same 40 of 65, 64 of 65 replies identical, one wording change in a passing row
```

## Files

| file | content |
| --- | --- |
| `inputs.tsv` | binaries and digests, model digest, tuple, categories, budget, order |
| `arms/*/quality.json` | every row's reply, grade, timings, and served model id |
| `arms/*/suite.console` | the suite's own summary line per arm |

The first attempt of this chain ran the suite with its default request
model name against a standalone server that answers with its own alias, so
every row failed attribution and no grade was produced; the arms above name
the registry id on both sides.
