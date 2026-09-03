# E4 correctness witness: every token id held, log-probabilities moved by reassociation

```text
control=census v7 (addcae10...), Vulkan0
candidate=census+E4 (741a0d76...), Vulkan0
prompts=6, order C K K C, 2 runs per start, 128 tokens, temperature 0, top_k 1, seed 1, ignore_eos, cache_prompt off
registered_logprob_bound=1e-3 nat
witness=differs on the log-probability bound; id_identity=held on every prompt and sample
```

`run-kernel-delta-witness.sh` reads the token-id array and the selected
token's log-probability from `/completion` with `return_tokens` and
`n_probs 1`, so the comparison is over what the model chose and how sure
it was, where the kernel-delta reader compares reply content and count
alone.

## Result

| prompt | self-consistency C, K | candidate vs control ids | first divergence | max abs logprob delta | median | p90 |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| accumulator | held, held | held (4 of 4) | - | 2.65e-3 | 9.5e-7 | 4.2e-4 |
| constraints | held, held | held | - | 2.42e-2 | 8.5e-5 | 2.4e-3 |
| list-transform | held, held | held | - | 1.01e-2 | 6.7e-6 | 1.8e-3 |
| stack | held, held | held | - | 1.00e-2 | 1.8e-5 | 2.2e-3 |
| state-machine | held, held | held | - | 2.40e-2 | 6.5e-5 | 4.1e-3 |
| variable-trace | held, held | held | - | 1.45e-2 | 1.2e-5 | 9.2e-4 |

Both binaries are exactly self-consistent across starts and runs (every
self delta 0). The candidate returned the control's token-id array on all
six prompts, four samples each, 768 generated tokens with the argmax
unmoved. Its selected log-probabilities differ from the control's by a
median of 1e-6 to 1e-4 nat, a p90 of 1e-3 to 4e-3, and a maximum of 1e-2 to
2.4e-2, from the first tokens on rather than growing with position (the
maxima sit at positions 25, 118, 12, 25, 39, 127). The registered 1e-3
bound is exceeded on every prompt, so the witness reads `differs` as
registered.

## Two references for what the movement means

| pair | ids | max abs logprob delta | what it bounds |
| --- | --- | ---: | --- |
| `../witness-calibration-20260903T0203Z/`: production bundle vs census v7, both Vulkan0 | held, 6 of 6 | 0.0 on every token | compile-to-compile movement of the same shader source: none |
| `../witness-cpu-reference-20260903T0220Z/`: census v7 Vulkan0 vs the same binary on the CPU backend | differ on 4 of 6, first divergence at 59, 11, 96, 16 | 8.9e-2 to 3.75e-1 over the identical prefix, medians 1e-5 to 2.8e-2 | a different backend the appliance already serves as equivalent |

The first reference says the E4 movement is E4's arithmetic and nothing
else: two builds of the same source are bit-identical on this device. The
second says the movement is an order of magnitude inside what a backend
change costs, and a backend change moves the argmax where E4 does not. The
CPU path is a coarser reference than a pure reordering, since it quantizes
the activation to Q8 before its dot product, so the bound a pure
reassociation deserves lies between the two references and this tree holds
no run that pins it. The 1e-3 registration was a guess ahead of any
reference and is superseded by the two rows above; a re-registration needs
a Vulkan-only reference that changes accumulation order alone.

## Reading

E4 computes the same argmax on every generated token of six state-carrying
prompts and moves the selected log-probability by at most 2.4e-2 nat, with
a median four orders of magnitude smaller. That is the signature of a
floating-point reassociation, which is what hoisting the activation group
sums is, and it is far inside the movement the appliance already accepts
between its two backends. The witness as registered reads `differs`; the
finding is that the registered bound had no reference, and the two
references now retained are what the next registration is written against.

## Files

| file | content |
| --- | --- |
| `summary.tsv` | per-prompt identity, first divergence, max delta, verdict |
| `inputs.tsv`, `prompts.tsv` | the binaries, the tuple, the sampling, the prompts |
| `arms/*/<prompt>/tokens-run-N.tsv` | one line per token: id and selected log-probability |
| `arms/*/<prompt>/response-run-N.json` | the replies as the server returned them |
