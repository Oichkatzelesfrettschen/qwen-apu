# Context checkpoints on a second turn at depth 32K

`remote/run-ctx-checkpoint-sweep.sh` is the first arm of the 32K performance
queue. It measures what `--ctx-checkpoints` buys a hybrid recurrent model on
a second turn that shares a 30K-token prefix with the first, through the
served launch chain, on the three runtime classes in the order
`remote/models.tsv` serves them: `qwen38-2b-distill` first, `qwen35-08b`
second, `qwen38-4b-distill` third. This document registers the mechanism, the
arms, the prediction, and the falsifiers ahead of any device run. No arm has
run on the appliance; every number below is a registered expectation.

## Mechanism

Qwen3.5 and Qwen3.8 blocks are Gated DeltaNet layers interleaved with full
attention, and the recurrent state of a DeltaNet layer is one tensor per
sequence rather than one entry per position. `tools/server/server-context.cpp`
at f280b269 cannot roll that state back to an earlier position, so a request
whose prompt shares a prefix with the slot's cache and then diverges takes one
of two paths: it restores the newest checkpoint whose position is at or below
the divergence point and re-prefills from there, or, where the slot holds no
checkpoint, it re-prefills from position zero. Checkpoints are created only
for hybrid recurrent contexts, at prompt boundaries and qualifying user-message
boundaries, spaced by `--checkpoint-min-step` (default 8192) and capped per
slot by `--ctx-checkpoints`; each holds the recurrent state in host memory
under `LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` with the attention KV left in place
(`evidence/checkpoint-cache-context-semantics.md`,
`evidence/qwen38-checkpoint-memory.md`).

The served argv pins `--ctx-checkpoints 0 --cache-ram 0 --no-context-shift`,
so the appliance pays the second path on every follow-up turn at depth.
`QWEN_CTX_CHECKPOINTS` in `remote/qwen-capacity-policy.sh` raises the count
for one launch and `QWEN_CHECKPOINT_MIN_STEP` names the spacing;
`remote/qwen-webui-control.sh` forwards both across the tmux boundary, and the
default of zero leaves the served argv unchanged. Each arm launches at the
row's `validated_filled_depth` through `QWEN_CONTEXT_SIZE`, since the
single-model default of 24576 sits below the 30720 target, and the harness
keeps the caller's ordinary priority: `qwen-webui-control.sh` runs the server
at nice 19 and `monitor-qwen-runtime.sh` normalizes its own guard to nice 0
with `renice -n 0`, which cannot be reached from above zero without privilege.
The first appliance run reniced the harness to 19 and the session recorded
`monitor_exited` one second after `state=running`; that arm also left the
server alive through two SIGTERMs until a SIGKILL, which the session's
post-loop `wait` does not bound.

## Arms

Each arm is one fresh launch through `qwen-launch.sh` under
`QWEN_CTX_CHECKPOINTS=N`, at the registry row's own cache triple, Flash
Attention state, batch, and ubatch, and one teardown. The harness composes a
deterministic filler from a thirty-word list through an exact 16-bit Lehmer
walk, sizes it through `POST /tokenize` to land inside 2% of
`QWEN_CTX_TARGET_DEPTH` (default 30720), and sends two greedy
`POST /completion` requests of `n_predict` 32 with `cache_prompt` on: turn 1
is the prompt, turn 2 is the same prompt with a short appended question. The
registry ceiling of 32768 leaves room for the suffix and both replies.

| arm | ctx_checkpoints | checkpoint-min-step |
| ---: | ---: | --- |
| 1 | 0 | default |
| 2 | 2 | default |
| 3 | 4 | default |
| 4 | 8 | default |
| 5 | 8 | default |
| 6 | 4 | default |
| 7 | 2 | default |
| 8 | 0 | default |

The mirrored order puts every setting on both sides of the sweep's drift, the
same reason `remote/run-representation-arm.sh` runs control, subject, subject,
control. `QWEN_CTX_CHECKPOINT_ARMS` overrides the list.

Retained per run: `summary.tsv` with `arm ctx_checkpoints turn prompt_n
prompt_ms predicted_n predicted_ms prompt_tok_s decode_tok_s
prefill_saved_ms`, where `prefill_saved_ms` on a turn-2 row is turn 1's
`prompt_ms` minus turn 2's; per arm, both request and response bodies, the
greedy token ids, the server log, and the session status; `divergence.txt`
with the first index at which any arm's ids depart from arm 1's, per turn;
`prompt-depth.txt` with the tokenized depth and the number of sizing passes.
`prompt_n` is what the server reports, and the server charges the full prompt
length on a cached prefix (`evidence/model-admission/roster-quality-sweep.md`: every arithmetic row
reports the same `prompt_n` warm and cold), so the saving is read from
`prompt_ms` rather than from a token count.

## Prediction

At zero checkpoints turn 2 re-prefills the whole prefix: its `prompt_ms` is
at or above turn 1's, since the prompt is longer by the suffix. At 2, 4, and 8
the newest checkpoint at or below the prompt end survives, and turn 2's
`prompt_ms` falls toward the cost of the suffix plus the span from that
checkpoint to the divergence point. With the default 8192-token spacing at
depth 30720, the checkpoint nearest the prompt end is the prompt-end
checkpoint itself, so the re-prefill span is expected small and the three
non-zero arms are expected to agree with each other inside the sweep's own
scatter. A count of 2 is predicted sufficient, because the prompt-end
checkpoint and one interior checkpoint cover this two-turn shape; 4 and 8
measure whether a larger allowance costs anything at all.

Decode rate is predicted unchanged across arms: a checkpoint is a host copy
taken at a boundary, and decode runs the same graph whatever the count.

## Falsifiers

- Turn 2 `prompt_ms` inside 10% of turn 1 under any checkpoint count above
  zero refutes the mechanism as implemented on this backend, and the arm's
  server log is where the reason lives: a checkpoint pruned before turn 2, a
  boundary the server declined to checkpoint, or a divergence point below the
  newest checkpoint.
- Any token-id divergence between arms on either turn refutes the correctness
  claim that a restored checkpoint continues the same sequence, and the
  harness exits non-zero on it. Greedy decoding on this backend is
  deterministic inside a fixed request sequence
  (`evidence/model-admission/roster-quality-sweep.md`), so a divergence is attributable to the
  checkpoint path rather than to sampling.
- A turn-1 `prompt_n` outside 2% of the target fails the arm rather than
  measuring a different depth.
- Decode rate differing by more than the sweep's own zero-arm pair spread
  between counts reopens the claim that a checkpoint costs nothing at decode.

## Class order and what a result changes

The 2B distill runs first as the primary performance target, the 0.8B second,
the 4B third. A saving that agrees across the three classes moves the served
`--ctx-checkpoints` default; a saving on one class alone becomes that class's
profile setting. Host memory per checkpoint is the cost side
(`evidence/qwen38-checkpoint-memory.md`), so a default of 2 rather than 8 is
the expected shape of an admission unless 8 measures the same and the host
reserve carries it.

## Workstation admission

`remote/test-run-ctx-checkpoint-sweep.sh` drives the harness against
`remote/test-fixtures/fake-ctx-checkpoint-server.py`, whose prefill cost
depends on the checkpoint count each launch received, and proves the mirrored
order, the forwarded environment, a positive saving on every non-zero arm and
none at zero, the divergence index on a shifted arm, the argument errors, and
the refusal beside a running `llama-server`.
`remote/test-qwen-capacity-policy.sh` proves the override reaches the argv as
an integer, the minimum step follows it only when named, and a non-integer in
either is refused.
