# Per-checkpoint baseline over the runtime-root epoch

The kernel program compares serving builds against each other, and every such
comparison rests on a denominator that is one number per checkpoint. This
registers the runner that produces that denominator as four separate quantities
under one bound identity, states what would falsify each, and names the device
command that measures it. No arm has run; every figure below is a prediction or
a rule, and the record that carries the answers is
`evidence/kernel-program/<timestamp>/` beside this file.

## Three quantities exist only inside one session

`remote/measure-served-decode.sh` loads a checkpoint, sends exactly one 64-token
request, and tears the server down, so its rate carries the cold load beside it
and its reply retains no token array. `remote/run-checkpoint-baseline.sh`
separates what that shape leaves entangled: one launch, one readiness poll, one
streamed request whose first content delta stamps the time to first token, and a
block of identical 64-token requests inside the warm session.

| Quantity | Mechanism | Record |
| --- | --- | --- |
| Load wall time | the interval from the launch call to the first `GET /health` that answers, over the whole guarded chain | `arms/NN-ROLE/load.tsv` |
| First-token latency | the wall interval from the streamed request leaving to its first content delta, which a non-streamed reply cannot report because its `prompt_ms` is prefill alone | `arms/NN-ROLE/ttft.tsv` |
| Steady decode | `predicted_per_second` over each of `QWEN_BASELINE_REPEATS` identical requests, default 4, inside one warm session | `arms/NN-ROLE/decode-rows.tsv` |
| Token identity | the SHA-256 over each repeat's newline-joined token-id array, compared repeat against repeat | the `tokens_sha256` column, resolved in `summary.tsv` |

`measure-served-decode.sh` keeps the behavior its retained fixed-64 receipts
were written under, so the session driver lives in
`remote/checkpoint-baseline-lib.sh` and that runner is left alone. That is a
stated scope cut: two runners now launch servers through the same chain.

## What the identity binds

`identity.tsv` is written before the device is touched and carries the model
bytes and SHA-256, the server bytes and SHA-256 for each role, the manifest
digest beside each server, the `checkpoint_patch_series_sha256` each build
declares, the digest of each of the two request bodies, and the registry tuple
the policy read. Each arm then writes `served-tuple.tsv` from the argv of the
process the session recorded as `server_pid`, because
`qwen-capacity-policy.sh` is what builds the tuple and the registry is its
input: a preset section, a cache override, or a validated-depth bound would
leave a registry read stating a tuple no process served.

The resolved checkpoint is held to `remote/model-artifacts.tsv` at preflight, so
a file replaced, truncated, or re-fetched under a row that still resolves
refuses rather than being measured under the identity the receipt would claim.

## What runs it

The campaign runs inside one `compute-state-lease.sh measure-fixed`
transaction, which holds the shared Vulkan lease on descriptor 8, pins GFXCLK
1100 with FCLK 933, proves the delivered clock before the command, and verifies
the restore after it. The runner therefore takes no lock and writes no DPM
level: it proves it inherited descriptor 8 through
`verify-external-vulkan-lease.py` and refuses outright otherwise, and it holds
every arm's clock record to the forced-policy invariant -- gap bound 250 ms
rather than the governor's 100 ms, fabric floor 933 MHz, and the highest
graphics step `pp_dpm_sclk` lists required on every window sample. A run that
takes a second exclusive lock wedges the first decode pass of every arm, which
is why the inherited descriptor is the only admitted form.

## Falsifiers

- **Token identity is a claim about the machine.** Every repeat decodes one
  fixed request at temperature 0, `top_k` 1, a fixed seed, `ignore_eos`, and
  `cache_prompt` off, so the arrays must agree. A `token_identity diverged`
  summary refutes the assumption that a served rate on this backend measures one
  computation, and the retained arrays name where the divergence starts. That is
  the finding rather than a harness fault.
- **The repeats must be tighter than the sweeps.** `evidence/decode-bound-analysis.md`
  measures 30.6% of spread on one checkpoint across sweeps and
  `evidence/measurement-state-and-memory-clock.md` about 4% on a repeated
  depth-0 rate. A `decode_spread` above 0.04 inside one warm session under a
  pinned clock refutes the claim that the pinned state removes the governor term,
  and moves the campaign back to the paired mirrored shape for every comparison.
- **Load and decode must separate.** If load wall time correlates with the same
  arm's decode mean across arms of one role, the session is not reaching a steady
  state inside the repeat count and the count is too small; the falsifier is a
  rank correlation over the four bracket arms, and the response is to raise
  `QWEN_BASELINE_REPEATS` rather than to read the mean.
- **The clock record is required rather than reported.** An arm whose sidecar
  retained no record, or whose window violates the invariant, fails as
  `clock_invariant` and contributes nothing. A summary computed over an
  unsampled arm would give an unpinned rate the standing of a pinned one, so
  `summarize-checkpoint-baseline.py` refuses the absent record too.
- **The bracket isolates one binary.** `--bracket` refuses two roles that are one
  executable and refuses two servers whose manifests yield different base build
  identities, so a `candidate_over_control` ratio that moves cannot be attributed
  to an optimization level, a target, or a commit.

## The device command

The DEVICE-WINDOW agent runs this on the appliance with the router torn down,
from the synced runtime tree, under one lease transaction per checkpoint:

```sh
remote/compute-state-lease.sh measure-fixed \
    remote/run-checkpoint-baseline.sh qwen38-2b-distill \
    "$QWEN_HOME/results/kernel-program/baseline-2b"
```

`QWEN_LLAMA_SERVER` names the serving build the arm measures, and
`QWEN_COMPUTE_STATE_FORWARD` carries it and `QWEN_BASELINE_REPEATS` across the
closed environment `census_arm_exec` applies. The class policy orders the
checkpoints: the 2B first, the 0.8B second, the 4B third. The bracket form takes
the same transaction with two servers:

```sh
QWEN_COMPUTE_STATE_FORWARD='QWEN_BASELINE_REPEATS=4' \
    remote/compute-state-lease.sh measure-fixed \
    remote/run-checkpoint-baseline.sh --bracket CONTROL_SERVER CANDIDATE_SERVER \
    qwen38-2b-distill "$QWEN_HOME/results/kernel-program/bracket-2b"
```

## What has not run

Every arm. `remote/test-run-checkpoint-baseline.sh` drives the whole runner and
the summarizer over `remote/test-fixtures/fake-llama-server.sh` on the
workstation with the launch chain, the clock sampler, the clock validator, and
the Vulkan lease verifier replaced by stubs, so the request shapes, the
identity refusals, the arm ledger, the token comparison, and the summary
recomputation are exercised and no rate on this hardware is measured. The
appliance numbers are `not run`.
