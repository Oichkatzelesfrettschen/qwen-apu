# Context checkpoint sweep, three runtime classes

`remote/run-ctx-checkpoint-sweep.sh` ran the design registered in
`evidence/ctx-checkpoint-sweep-design.md` against the 2B distill, the 0.8B,
and the 4B distill in that order, each at its row's `validated_filled_depth`
of 32768 with a 30725-token first prompt, the arm order 0 2 4 8 8 4 2 0,
32 greedy tokens per turn, and the `low-async` profile. `provenance.txt`
binds the binary, the three GGUFs, the scripts, the kernel, Mesa, and the
boot. Each class directory holds `summary.tsv`, `divergence.txt`,
`inputs.txt`, both prompts, and per arm the launch record, session status,
both replies, and both token arrays; server logs and request bodies are
omitted because the prompts and replies carry the same content.

## Result

| class | c>0 turn-2 prefill | c0 turn-2 prefill | prompt-only reduction | token identity, c0 against c>0 |
| --- | ---: | ---: | ---: | --- |
| 2B distill | 3.0 to 5.1 s | 1400 and 1510 s | 275x to 500x | identical, both turns, both c0 arms |
| 0.8B | 2.2 s | 740 and 907 s | 330x to 410x | turn 1 differs at index 25; turn 2 identical |
| 4B distill | 7.7 to 9.0 s | 3134 s | 350x to 405x | identical, both turns, one c0 arm |

Zero checkpoints force turn 2 to reconstruct the recurrent state from the
prompt boundary, charging 30748 tokens; every positive count restores the
prompt-boundary checkpoint and charges 27. Counts 2, 4, and 8 are
indistinguishable in this two-request shape, so 2 is the smallest tested
sufficient count and 1 is untested. The reduction figures describe prompt
evaluation; with the 32-token decode included the 4B's request gain is about
114x (3534.7 s against 31.1 s).

Decode at depth is read within a class and not across arms: the 2B spans
3.15 to 5.71 tok/s over eight arms of one configuration, the 0.8B 5.7 to 8.6,
the 4B 1.44 (first arm) and 1.93 to 2.01. The spread is the machine's, as
`evidence/decode-bound-analysis.md` records, and no decode effect of the
count is resolved.

## 0.8B, two verdicts

```text
performance_effect=accepted
turn2_restore_equivalence=accepted_for_32_token_witness
turn1_token_identity=refuted
overall_registered_admission=failed
condition_boundary=c0 versus c1_or_greater
count_effect_above_zero=none_resolved
first_divergence_index_zero_based=25
first_divergence_token_ordinal=26
semantic_observation=continuations retain the same apparent reasoning
mechanism_status=forced_tail_prefill_partition_supported_by_source
near_tie_status=unmeasured
```

All six positive arms emit one turn-1 array and both zero arms emit the
other; the split follows checkpoint enablement rather than count, position,
or drift. Common prefix through index 24: `... 264 1248 1103 314 4105`
("a long list of words"). Index 25 onward at c0: `85957 25717 318 13873 264
10031 314` ("/phrases (likely a dataset of"); at c>0: `318 13873 264 10031
314 4105 466` (" (likely a dataset of words or"). The two decoded strings
are retained in each arm's `turn1.json`. Turn 1 restores nothing, so
restoration is excluded as the cause. `tools/server/server-context.cpp:3449`
at the pinned commit declares `checkpoint_offsets[] = {4 + n_ubatch, 4}` and
forms the prefill tail into a 32-token chunk and a 4-token chunk whenever
checkpoints are armed, which the zero path never does; that execution-shape
change is the source-supported mechanism, and the logit margin at ordinal 26
is unmeasured because the sweep requested no `n_probs`.

## 4B, one censored arm

Arm 1 (c0) ended with curl status 28: the harness's `QWEN_CTX_REQUEST_SECONDS`
of 3600 expired during a 59-minute first prefill, so `turn1.json` is empty and
the sweep reports `failed_arms=1`. Arm 8 (c0) completed both turns inside the
deadline (3133.6 s and 3134.1 s) and supplies the c0 witness; `divergence.txt`
takes arm 2 as its reference and reads `none` for all twelve comparisons.
The 4B therefore has one c0 witness per turn rather than the opening and
closing pair the design asked for; the sweep's own verdict stays `failed`
under its registered rule, and the token identity it establishes rests on
one witness.

## Policy

Per row rather than process-wide, because the 0.8B fired the fidelity
falsifier while the other two classes did not:

```text
qwen38-2b-distill    ctx_checkpoints=2
qwen35-08b           ctx_checkpoints=0    fidelity baseline
qwen38-4b-distill    ctx_checkpoints=2    one c0 witness
process fallback     ctx_checkpoints=0
```

`remote/ctx-checkpoints.tsv` carries those rows and `qwen-capacity-policy.sh`
reads them. Host cost: each checkpoint copies the recurrent state through
`llama_state_seq_get_data_ext`; the per-class size is unmeasured here and is
read from the server's checkpoint log lines in a later arm.

## Harness defects the run exposed

1. Token files and summary rows are written only after both turns succeed, so
   a turn-1 reply that outlives a timed-out turn 2 leaves no token file.
2. A request timeout is reported as a failed arm; it belongs to its own class,
   censored at the configured deadline, apart from model, device, launch, and
   fidelity failures.
3. `divergence.txt` falls back to the first surviving arm as reference, which
   serves partial analysis and must not satisfy a required c0 comparison by
   itself.

## Open arms

A `0,2,2,0` first-turn sequence on the 0.8B with `n_probs` retaining the two
leading candidates at ordinal 26 under host sampling; the same arm against
`qwen35-08b-f16`; an experimental server that keeps checkpoint capture and
removes the forced tail splits, admitted where turn 1 matches stock c0 and
turn 2 still restores; a second full 4B c0 arm at a 7200 s deadline for
replicated turn-2 closure.
