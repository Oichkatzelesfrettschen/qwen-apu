# E4 on the twelve-prompt holdout: ten held, two argmax flips at ties of 0.0001 and 0.0023 nat

```text
contract=margin, registered in ../margin-contract-design.md at 37c3fcb ahead of this run
acquisition_head=a3ed7cb (reader rule for withheld UTF-8 entries), runtime tree verified at that head
control=census v7 (addcae10...), Vulkan0    candidate=census+E4 (741a0d76...), Vulkan0
prompts=remote/witness-prompts/holdout-12.tsv sha256 1b784918...    top_k=10  near_tie=0.1 nat  retention=0.5
order=C K K C, 2 runs per start, 128 tokens, temperature 0, top_k 1, seed 1, ignore_eos, cache_prompt off
witness=differs (registered verdict)    self-repeatability=exact on all 12 prompts, both binaries
```

## Result

| prompt | ids | positions read | near ties | min control margin | min retention | max truncated TV | verdict |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| binary-counter | held | 512 | 8 | 0.035 | 0.961 | 0.009 | held |
| bracket-matching | held | 512 | 20 | 0.014 | 0.843 | 0.017 | held |
| bubble-sort | held | 512 | 0 | 0.218 | 0.786 | 0.026 | held |
| gcd-trace | held | 500 (12 withheld `÷`) | 0 | 0.118 | 0.977 | 0.006 | held |
| grid-walk | differs at 25 | - | - | - | - | - | differs |
| inventory-ledger | held | 512 | 4 | 0.044 | 0.844 | 0.010 | held |
| matrix-rotate | held | 512 | 4 | 0.060 | 0.900 | 0.014 | held |
| modular-counter | held | 512 | 8 | 0.039 | 0.977 | 0.009 | held |
| queue | held | 512 | 8 | 0.019 | 0.949 | 0.007 | held |
| run-length | held | 512 | 4 | 0.022 | 0.835 | 0.013 | held |
| substitution-cipher | held | 512 | 0 | 0.126 | 0.860 | 0.017 | held |
| temperature-log | differs at 15 | - | - | - | - | - | differs |

Every position read on the ten held prompts keeps a positive candidate
margin, and no position with a control margin at or above 0.1 nat falls
below half of it: the smallest retention is 0.786 on bubble-sort. The
largest selected log-probability movement is 0.047 nat (bubble-sort), twice
the discovery run's maximum.

## The two flips

| prompt | position | control top two | candidate top two | control margin |
| --- | ---: | --- | --- | ---: |
| grid-walk | 25 | 15 at -1.1743, 18498 at -1.1745 | 18498 at -1.1664, 15 at -1.1821 | 0.0001 nat |
| temperature-log | 15 | 2250 at -1.0173, 4162 at -1.0196 | 4162 at -1.0180, 2250 at -1.0181 | 0.0023 nat |

Both are ties inside the movement any reassociation produces: the
discovery run measured E4 moving selected log-probabilities by up to 0.024
nat with the argmax unmoved because no discovery position sat within that
distance of its runner-up, and the CPU backend reference flipped four of
six prompts at larger distances. After each flip the two trajectories
diverge for the rest of the reply, as a greedy decode must (grid-walk
writes "facing North (0, 1)" against "facing North (direction 0)"), so the
divergence is a choice at one position and a different continuation, and
the continuation is read in the graded suite rather than here.

## Reading against the registered rule

The contract requires token identity at every position and exempts
near-tie positions from the retention ratio alone, so the registered
verdict is `differs`. The rule's shape rather than E4 is what the two flips
measure: a control margin of 0.0001 nat is below the precision at which
two builds of one shader source agree, and a rule that requires identity
there requires bit-identical arithmetic, which the calibration run already
showed only same-source builds deliver. The design document records this
as a refutation of the identity line's scope; a re-registration that reads
identity where the control margin is at or above the near-tie threshold
and reports flips below it as ties is written there ahead of any further
run, and this run is not re-read under it.

```text
deterministic                 held (exact self-repeatability, 48 samples per binary)
argmax_identity               held on 10 of 12 holdout prompts; two flips at control margins 0.0001 and 0.0023 nat
margin_retention              held on every read position, minimum 0.786
numerical_identity            refuted
quality_nonregression         pending the graded suite
```

## Files

| file | content |
| --- | --- |
| `margin-summary.tsv` | the reader's verdict rows, one per prompt and comparison |
| `summary.tsv` | the retired log-probability bound's rows, retained for continuity |
| `inputs.tsv`, `prompts.tsv` | binaries, tuple, contract constants, prompt digest, the prompts |
| `arms/*/<prompt>/tokens-run-N.tsv` | id, selected log-probability, and top-10 list per token |
| `arms/*/<prompt>/response-run-N.json` | the replies as the server returned them |
