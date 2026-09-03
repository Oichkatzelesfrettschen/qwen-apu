# 2B calibration on e4c148a: deferred emission moves collect inside bound, the sampler still loses on both cores

```text
measurement_status=diagnostic
acquisition_head=e4c148a0e78eb55fd4a67dc93921d3cb8429dc66
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
```

The third thirteen-arm calibration, runner and runtime tree both at
`e4c148a`, with the v7 instrument's per-graph emission deferred into a
preallocated binary buffer drained at context close, and the sampler at
nice 19 every 10 ms under a 20 ms gap bound confined to both cores
(`cpu_affinity=0,1`). The raw records stay on the appliance under
`$HOME/raven2-kernel-census-20260902T0617Z-2b-calibration-v7/`, retained
here by digest in `raw-digests.txt`.

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 1 | P-nosidecar | 6.783 | completed, cold opener |
| 2 | P | 8.984 | sidecar gaps |
| 3 | P | 9.428 | sidecar gaps |
| 4 | P-nosidecar | 9.561 | completed |
| 5 | P | 9.422 | sidecar gaps |
| 6 | I0 | 9.472 | sidecar gaps |
| 7 | I0 | 9.395 | sidecar gaps |
| 8 | P | 9.472 | sidecar gaps |
| 9 | I0 | 9.412 | sidecar gaps |
| 10 | I1 | 9.312 | completed, ownership conclusive |
| 11 | I1 | 9.330 | sidecar gaps; census rows retained |
| 12 | I0 | 9.489 | sidecar gaps |
| 13 | S | 2.333 | sidecar gaps; 64 logger blocks retained |

Every failed arm failed on `sidecar=refused` with `failures=gaps` alone;
`terminal-state.tsv` reads `arm_failures=10 control_incomplete=3
control_accepted=0`.

## The sampler still yields on both cores

The sampler moved from core 1 alone to `cpu_affinity=0,1` between 0525Z and
this run, which was meant to let a guard burst on one core push the sampler
onto the other. It still refuses on gaps in every sampled arm.
`arms/02-P/clock-sidecar-verdict.txt` through `arms/12-I0/clock-sidecar-verdict.txt`
each carry a `window_lost_fraction`, and the five arms whose window holds
three to five gaps over the 20 ms bound (02-P, 06-I0, 08-P, 09-I0, 11-I1)
span 0.0122 to 0.0147; the S arm's window holds three such gaps at
0.0027, over its longer 27.0 s request. Their maxima span 60.8 ms
(11-I1) to 119.0 ms (06-I0).

The over-bound gaps do not coincide with slow sysfs reads as a rule.
Reading `clock-sidecar.tsv` for the eight P and I0 records directly (not
retained here, since it is a raw file outside the retention list) finds 25
gaps over the 20 ms bound inside the request window. Fourteen of those 25
are preceded by a sample that cost 0.2 to 1.0 ms, ordinary cadence, and two
are preceded by a sample that cost 29 to 37 ms, a slow `pp_dpm_*` read
reported directly in `sample_cost_ns`. The remaining nine are preceded by
costs outside both bands, from 0.19 ms to 49.0 ms, so the sampler is held
off the CPU by something other than its own read latency for most of these
gaps -- consistent with CFS sharing the two cores between the sampler and
the server's own nice-19 threads, and now with no third core to move to.
Mean sample cost across the eight P and I0 records spans 0.762 to 0.912 ms;
the 02-P record alone carries 32 samples above 5 ms of its 1654, and every
one of those slow samples is a `pp_dpm_*` read, the same firmware round
trip on SMU10 the 0525Z run reported.

## The sidecar cost, still unpriced

`arms/01-P-nosidecar` (not retained; its arm is absent a sidecar and carries
no verdict file) opened cold at 6.783 tok/s, the outer slot of the first
sidecar pair, so a warmup arm excluded from every pair remains the
registered fix. Slot 4, the second `P-nosidecar` arm, measured 9.561
against the sampled `P` arms at 9.422 to 9.472 (slots 3, 5, 8; slot 2's
8.984 carries its own cold-adjacent discount and is excluded the way
0525Z excluded it), 0.9 to 1.5% above the 0.0065 sidecar bound. The
pair verdict in `summary.tsv` still reads `incomplete` for all three pairs,
because every sampled arm on both sides of each pair failed on gaps.

## Collect: the deferred-emission arm clears the bound

Slot 10's I1 arm accepted whole, 63 decode graphs, `ownership=conclusive`
in `arms/10-I1/pipeline-ledger-decode.tsv`: a 99.628 ms bracket union per
decode graph, a 0.0069 cross-pipeline overlap fraction, 2.787 ms of queue
time outside every bracket, and a 1.872 ms residual. `raw-digests.txt`
carries `arms/10-I1/pipeline-census.tsv`'s digest; the retained ledger is
the summarizer's own output against that file, not a re-derivation here.

I1 slots 10 and 11 measured 9.312 and 9.330 against their I0 neighbors at
9.412 (slot 9) and 9.489 (slot 12), 0.9 to 1.9% under -- inside the 0.02
collect bound on every pairing for the first time across the three
calibration runs (0525Z read 2.5% and 1.9%; the first of those crossed the
bound and the second sat just under it, so this run is the first to clear
it on both I1 slots at once). The instrument's deferred emission is the
change: the v7 buffer accumulates each graph's dispatch rows in a
preallocated binary region and drains it at context close, replacing the
per-graph text formatting the 0525Z run priced at 86 to 878 microseconds a
graph on the workstation smoke.

## The S inventory, read offline

`arms/13-S/perf-logger-inventory.tsv` folds the retained slice under the
analysis head's parser: 64 complete blocks, 63 decode and 1 prefill, 19
ops. Per decode block the serialized identity control counts 181 `MUL_MAT`
and 30 `MUL_MAT_ADD` calls, matching the family counts the 0525Z run's slice
reported at the same tuple. `arms/13-S/server-effective-env.tsv` is the
served process's own environment: `GGML_VK_LOW_PRIORITY=1`,
`GGML_VK_MAX_NODES_PER_SUBMIT=32`, `GGML_VK_PERF_LOGGER=1`,
`GGML_VK_PERF_LOGGER_FREQUENCY=1`, `GGML_VK_SERIALIZE_SUBMISSIONS=1`, the
two ICD names, and `QWEN_PERF_LOGGER=1`, the same closed profile as
declared, and nothing else in those families.

## Remedies registered for chain eight

A warmup arm W excluded from every pair, so a cold opener never occupies a
pair's outer slot. Acceptance on `window_lost_fraction <= 0.02` with a
100 ms stall bound, rather than the all-or-nothing gap refusal this run
still applies. The `pp_dpm_*` reads moved to a 100 ms channel in a C
telemetry broker, replacing the Python sampler this run and 0525Z both
ran at a 10 ms period; a 100 ms period removes the read frequency that
produces the slow firmware round trips this run still measures inside the
sampler's own critical path.

## Retention

Retained: `arms.tsv`, `inputs.tsv`, `terminal-state.tsv`, `summary.tsv`,
`calibration-contract.tsv`, `campaign-inputs.tsv`, every sidecar verdict
except the two `P-nosidecar` arms (which run no sidecar), the slot 10
decode and prefill ledgers, the slot 10 and 11 request windows, the S
slice with its offline-derived inventory, effective environment, and
request window. `arms/13-S/perf-logger-inventory.tsv` is derived here from
the retained slice with `remote/summarize-perf-logger-slice.py
--expected-decode-blocks 63`, not copied from the appliance. The full
`pipeline-census.tsv` records for slots 10 and 11 stay off the tree; their
digests are in `raw-digests.txt` beside the S arm's slice digest, computed
on the appliance before copying. Paths are rewritten to `$HOME` and the
host to `qwen-laptop`.
