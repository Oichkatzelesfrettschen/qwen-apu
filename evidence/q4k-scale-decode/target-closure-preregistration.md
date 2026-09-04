# Target closure on the 2B: the preregistered run

`README.md` in this directory leaves one of its three verdicts provisional: the composed Q4_K
candidate decoded above 10 tok/s on four arms of one session, and four absolute rates from one
session state a central value rather than a bound. This file states, ahead of the device window
that answers it, what the closure run measures, what statistic decides it, what every arm holds
constant, and which identities the receipt must carry so the answer cannot later be read two
ways. The run itself is `remote/run-served-binary-ab.sh` in its `C K K C` shape, and the
verdict is `remote/summarize-target-closure.py` over the `arms.tsv` that run writes.

## The two verdicts, stated apart

| verdict | statistic | bound | decided by |
| --- | --- | --- | --- |
| target closure | lower endpoint of the nominal two-sided 95% t interval over the candidate arms' absolute `tok_s` | above 10 tok/s | `summarize-target-closure.py --target 10` |
| platform promotion | nominal 95% t interval over the paired deltas, one-sided | above +5% | `summarize-census-controls.py --served-ab-bound 0.05`, unchanged |

Both read the same ledger from the same sweep, so the two verdicts share every arm and differ
only in the question. The closure interval uses the `interval()` the paired summarizer already
carries -- sample standard deviation, the `T_95` table over 2 through 8 replicates, half-width
`t * sd / sqrt(n)` -- applied to rates rather than deltas, which adds no statistic the tree has
not already committed to. The old 9.864 tok/s scoreboard denominator sits 1.38% under the
target and the promotion bound is 5%, so a candidate can close the target and fail promotion,
and the retained run did exactly that: +1.83% paired, refuted at 5%, four candidate arms above
10. Reading the two apart is what keeps a closed target from being called a promotion and a
refused promotion from being called a missed target.

## What the interval admits

Every registered candidate arm enters or the verdict is `incomplete`. A candidate arm whose
`status` is other than `completed`, or whose `clock_invariant` is other than `held`, ends the
verdict rather than narrowing the sample to the arms that finished, because a dropped slow arm
moves the lower bound in the direction the verdict rewards. The minimum is four completed
candidate arms, which is `QWEN_AB_REPLICATES=4` in the harness's `W C K K C C K K C` sequence:
two mirrored quadruples, four pairs, four candidate arms. One quadruple alone carries two
candidate arms and a one-degree-of-freedom interval whose `t` is 12.706, which is a bound over
almost nothing; the retained run used four pairs and this run uses the same.

## The identities each arm holds

Each arm serves the same request under the same state, and the harness records every row
below in `inputs.tsv` or `arms.tsv`; a row that reads differently between the two arms, other
than the server itself, ends the run as a different experiment.

| identity | value | recorded as |
| --- | --- | --- |
| checkpoint | `qwen38-2b-distill`, Q4_K_M, 1312164224 bytes, `4aa0fb13c431514262f259d420ecc95a8714df58ac2a2384514e20b93983f0ff` | `model_file_sha256`, `model_file_bytes` |
| tuple | context 24576, batch 128, ubatch 32, cache q8_0/q4_0, Flash Attention on, 2 checkpoints, min step 8192 | the registry row, copied to `inputs.tsv` |
| request | the fixed-64 scoreboard request: 64 predicted tokens, sampling fixed, `low-async` profile | `generate`, `profile`, `production_receipt_sha256` |
| server priority and affinity | nice 19, the harness's own constant, on the inference core; identical in both arms | `server_nice` |
| sidecar | 20 ms period on cpus 0,1 at nice 19 | `sidecar_*` |
| engine clock | `manual`, `pp_dpm_sclk` level 2 = 1100 MHz, `pp_dpm_mclk` level 2 = 933 MHz, fabric floor 933 | `engine_clock_*`, `clock_invariant` per arm |
| package power | platform default, 15/25/20 W STAPM/PPT-fast/PPT-slow, read back and written nowhere | `remote/power-envelope.sh status` retained beside the run |
| CPU boost | enabled, `cpufreq/boost` reads 1 | retained beside the run |
| host tenants | the standing qemu guest running; KSM as found | `compute-state-lease.sh status` retained beside the run |
| the one difference | the server binary | `control_server_sha256` against `candidate_server_sha256` |

`high` and `profile_peak` are excluded by name: both drop the fabric to 400 MHz on this
firmware and decode 6 to 7 tok/s where `manual` level 2 decodes 9 to 9.6.

## Sealing what each server contains

The retained run's `inputs.tsv` names the candidate as two patches over a series whose digest
equals the control's, which reads as if the two arms differed by those two patches alone. The
preimage chain in `README.md` says otherwise: `llama-vulkan-q4k-scale-word-select.patch` applies
onto blob `48778a3e8`, the shader `llama-vulkan-q4k-activation-group-sums.patch` produces from
the pinned commit's `93fbacc62`, so a source tree the scale patch applies to already carries E4.
This run seals the question on both sides rather than inferring it:

- **The control carries no E4.** It is the epoch's production server, built from the
  `production` stage of `remote/llama-patch-series.tsv` -- eight members, series digest
  `58e651d78872c3d2718baee56f6eefb9131961738d8fe8ff1a8f1cab92d43f02` -- none of which touches `mul_mat_vec_q4_k.comp`, so its shader is the
  pinned commit's blob `93fbacc62`. The receipt carries `control_patch_series_sha256` and the
  bundle manifest's `patch_series` list.
- **The candidate carries E4, the scale-word select, and the loop LICM, at `NUM_ROWS = 4`.** It
  is the sealed-key build: the candidate stage through `llama-vulkan-q4k-variant-select.patch`,
  run under `QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4`, with the control under no key.
  The receipt carries the candidate manifest's full `patch_series` list including
  `llama-vulkan-q4k-activation-group-sums.patch`, its `q4k_variants` field, and the SHA-256 of
  `mul_mat_vec_q4_k.comp` in the candidate source tree, so the E4 content is a recorded byte
  identity rather than a sentence.
- **The shader that executed is the shader that was sealed.** The candidate arm's Q4_K ISA
  digest from the build receipt (`138bab50...` for the composed four-row form in `README.md`
  Table 1, or whatever the epoch's own compile prints) is copied beside the served result.

A run whose receipt lacks any of those four fields is retained as a measurement and decides
nothing.

## Falsifiers

- The candidate interval's lower endpoint at or below 10 tok/s refutes closure, and a
  candidate interval that spans 10 leaves it unresolved; neither is rerun in the same window.
- A candidate arm failing or breaking the clock invariant makes the verdict `incomplete`,
  and the run is repeated whole in a later window rather than topped up.
- A control arm outside the retained run's 9.82 to 9.85 tok/s by more than 4%, the
  uncontrolled spread this machine carries on a repeated depth-0 rate, marks a machine state
  the retained run did not see; the closure verdict still reads from its own arms, and the
  paired verdict is what the control drift is read against.
- A token-identity break on any arm under the margin contract ends the run as a
  correctness incident ahead of either verdict.

## What closure would and would not license

A `closed` verdict states that the composed candidate at `e4-scale-licm/4` decodes the 2B
distill's fixed-64 request above 10 tok/s on this machine under the manual 1100/933 clock
cell, and that the 2B target the class policy names is met by a production-candidate build.
It moves the `target closure` row of `README.md` from provisional to passed. It does not move
the promotion row: that row reads the paired bound, and the retained +1.63% to +2.04% lies
whole below 5%. A default that helps one checkpoint and not another of the same quantization
recipe stays a profile setting, so closure would put the sealed key on the 2B's row rather than
on the appliance.
