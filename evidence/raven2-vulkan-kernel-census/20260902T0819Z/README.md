# 2B calibration on f5f92d8e: cell reuse in the gate, the sampler clears every bound, collect alone accepts

```text
measurement_status=diagnostic
acquisition_head=f5f92d8e61a3a0c46dfe4e17cbe1313cd399da65
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=refuted
merge_authority=no
ownership_authority=provisional
```

The fourth calibration in the chain, runner and runtime tree both at
`f5f92d8e`, adds a warmup arm W at slot 0, moves the sidecar to a
standalone C telemetry broker sampling `pp_dpm_*` on a 100 ms channel
instead of the 10 ms Python sampler the prior three runs shared, and
raises the sidecar's own stall bound from 20 ms to 100 ms while adding a
0.02 window-lost-fraction acceptance criterion beside it. The raw records
stay on the appliance under
`$HOME/raven2-kernel-census-20260902T0819Z-2b-calibration-v8/`, retained
here by digest in `raw-digests.txt`.

The repository gate at `f5f92d8e` is the first in this chain to reuse
cached test cells rather than rerun every check: `cells_run=31
cells_reused=48` against the prior gate root, so 48 of the 79 checks the
gate covers answered from a matching content-addressed cache entry and 31
ran fresh.

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 0 | W | 9.571 | completed |
| 1 | P-nosidecar | 9.590 | completed |
| 2 | P | 9.475 | completed |
| 3 | P | 9.604 | completed |
| 4 | P-nosidecar | 9.513 | completed |
| 5 | P | 9.402 | completed |
| 6 | I0 | 9.628 | completed |
| 7 | I0 | 9.427 | completed |
| 8 | P | 9.522 | completed |
| 9 | I0 | 9.530 | completed |
| 10 | I1 | 9.351 | completed, ownership conclusive |
| 11 | I1 | 9.498 | completed, ownership conclusive |
| 12 | I0 | 9.549 | completed |
| 13 | S | 2.351 | completed, 64 logger blocks retained |

Every one of the fourteen arms completed; `terminal-state.tsv` reads
`arm_failures=0 control_incomplete=0 control_refutations=2
control_unclassified=0 control_accepted=1 control_required=3
cooldown_timeouts=14`. The warmup arm W ran at slot 0 and is excluded from
every pair and from the census, so it appears in `arms.tsv` alone.

## The sidecar accepts on every sampled arm, and window loss stays inside the bound

The C telemetry broker replaces the Python sampler on both this run and
its 20 ms-bound predecessors: constant nice 19 across both cores, a 10 ms
sample period, and `pp_dpm_*` reads moved to a 100 ms channel. Every one of
the eleven sampled arms (02-P through 13-S) reads `sidecar_exit=accepted`
and `clock_sidecar=accepted failures=-` in its
`clock-sidecar-verdict.txt`, and `gaps_in_window=0` against the 100 ms
stall bound on all eleven, so no sampled arm crosses the stall criterion
this run adds.

`window_lost_fraction` against the 0.02 bound spans 0.0000 (02-P, 08-P) to
0.0165 (11-I1) across the eleven sampled arms, every value inside the
bound. Mean sample cost spans 0.229 ms (13-S) to 0.430 ms (12-I0), quoted
from each arm's own `sample_cost=accepted mean_ns=...` line.

## Both bounded controls still refute, on opposite-signed pairs

`summary.tsv` and each control's own `bricks/C*.receipt.tsv` agree:

- **sidecar** (pair 1, P-nosidecar against P): first delta -0.0120,
  second delta +0.0096, against a 0.0065 bound -- refuted.
- **compile** (pair 2, P against I0): first delta +0.0240, second delta
  -0.0100, against the same 0.0065 bound -- refuted.
- **collect** (pair 3, I0 against I1): first delta -0.0188, second delta
  -0.0053, against a 0.02 bound -- accepted.

Both refuted pairs disagree in sign between their two replicates: the
sidecar's first replicate reads faster-without-sidecar and its second
reads slower-without-sidecar, and the compile pair does the same in the
opposite direction. A pair whose two replicates disagree in sign reports
the machine's own arm-to-arm scatter rather than the mechanism the pair
was built to isolate --
`evidence/measurement-state-and-memory-clock.md` documents about 4% on a
repeated depth-0 rate on this device, well past what a 0.65% bound can
resolve on two replicates. The remedy registered for the next chain link
is replicated pairs read as a paired mean and its interval, refuted only
where the whole interval clears the bound and unresolved where it spans
zero, the same rule `evidence/research-claim-methodology.md` states for
direction.

## Wall clock

`wall-clock.tsv` puts the campaign at 687 s over its fourteen arms, with
launch, request, teardown, and analysis phases summing to 126 s + 123 s +
12 s + 4 s = 265 s and cooldown alone at 421 s (14 arms x
`elapsed_ms` averaging about 30.08 s). Every one of the fourteen cooldowns
reached its 30 s deadline with `quiescence=timeout`: the cooldown's sclk
predicate requires the lowest listed step, 200 MHz, where this device
rests at 400 MHz between arms, so the predicate never resolves and every
cooldown times out rather than exiting early. The predicate is being
changed to a stable step below the highest rather than the lowest listed
one.

## Collect: slot 10 clears ownership again

Slot 10's I1 arm accepted whole, 63 decode graphs,
`ownership=conclusive` in `arms/10-I1/pipeline-ledger-decode.tsv`: a
99.159 ms bracket union per decode graph, a 98.131 ms exclusive bracket,
and a 1.027 ms ambiguous overlap. `raw-digests.txt` carries the digests of
`arms/10-I1/pipeline-census.tsv` and `arms/11-I1/pipeline-census.tsv`; the
retained ledgers are the summarizer's own output against those files, not
a re-derivation here.

## The S inventory, computed on the appliance

Unlike the two prior runs, this run's `arms/13-S/perf-logger-inventory.tsv`
is the appliance's own output rather than a local re-derivation from the
retained slice: 64 complete blocks, 63 decode and 1 prefill, 0 unknown, 19
ops. `arms/13-S/server-effective-env.tsv` carries the served process's own
environment -- `GGML_VK_LOW_PRIORITY=1`, `GGML_VK_MAX_NODES_PER_SUBMIT=32`,
`GGML_VK_PERF_LOGGER=1`, `GGML_VK_PERF_LOGGER_FREQUENCY=1`,
`GGML_VK_SERIALIZE_SUBMISSIONS=1`, `QWEN_PERF_LOGGER=1`, and the two ICD
names -- the same closed profile as declared, and nothing else in those
families.

## The E1 dump did not run

The chain pre-created the run's output directory before invoking
`dump-radv-shader-isa.sh`, and that script refuses to write into a
directory that already exists, so no E1 shader-ISA dump reaches this run.

## Remedies registered for the next chain link

Replicated pairs with a verdict read on the paired mean and its interval
in place of the two-replicate all-or-nothing read this run and its three
predecessors still apply, so a refutation reports a genuine effect rather
than the pair's own arm-to-arm scatter. The cooldown's sclk quiescence
predicate moves from the lowest listed step to a stable step below the
highest, so a cooldown can exit before its 30 s deadline on a device that
rests above the lowest step.

## Retention

Retained: `acquisition-contract.tsv`, `analysis-contract.tsv`, `arms.tsv`,
`calibration-contract.tsv`, `calibration-root.tsv`, `campaign-inputs.tsv`,
`inputs.tsv`, `summary.tsv`, `terminal-state.tsv`, `wall-clock.tsv`,
`bricks/C0.receipt.tsv` through `bricks/C3.receipt.tsv`, every sampled
arm's `clock-sidecar-verdict.txt` (02-P through 13-S; W, and the two
`P-nosidecar` arms run no sidecar), the slot 10 decode and prefill
ledgers, the slot 10, slot 11, and S request windows, and the S slice with
its appliance-computed inventory, effective environment, and
`server-log-request.slice`. Every `await-quiescence.stderr` in this run
came back empty, so none is retained. The full `pipeline-census.tsv`
records for slots 10 and 11 stay off the tree; their digests are in
`raw-digests.txt` beside the S arm's slice digest, computed on the
appliance before copying. Paths are rewritten to `$HOME` and the host to
`qwen-laptop`.
