# 2B calibration on 59c03c8: S runs, one I1 accepts, the sampler still loses to the guards

```text
measurement_status=diagnostic
acquisition_head=59c03c8096dee98f03a0805d3f7c715ef7158d6d
analysis_head=the commit that adds this file
instrument_version=pipeline-census-v3
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
```

The second thirteen-arm calibration, runner and runtime tree both at
`59c03c8`, with the sampler at nice 19 every 10 ms under a 20 ms bound and
pinned to core 1. The raw records stay on the appliance under
`$HOME/raven2-kernel-census-20260902T0525Z-2b-calibration-v6/`, retained
here by digest in `raw-digests.txt`.

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 1 | P-nosidecar | 8.166 | completed, cold opener |
| 2 | P | 9.864 | sidecar gaps |
| 3 | P | 9.926 | sidecar gaps |
| 4 | P-nosidecar | 9.919 | completed |
| 5 | P | 9.877 | sidecar gaps |
| 6 | I0 | 9.879 | sidecar gaps |
| 7 | I0 | 9.822 | sidecar gaps |
| 8 | P | 9.908 | sidecar gaps |
| 9 | I0 | 9.877 | sidecar gaps |
| 10 | I1 | 9.631 | completed, ownership conclusive |
| 11 | I1 | 9.657 | sidecar gaps; census rows retained |
| 12 | I0 | 9.843 | sidecar gaps |
| 13 | S | 2.458 | sidecar gaps; 64 logger blocks retained |

## What moved and what stayed

The runtime monitor admitted the diagnostic profile, so the S arm ran its
request at 2.458 tok/s, its server exited cleanly, and the relaunch
succeeded. `arms/13-S/server-effective-env.tsv` is the served process's
own environment: `GGML_VK_LOW_PRIORITY=1`, `GGML_VK_MAX_NODES_PER_SUBMIT=32`,
`GGML_VK_PERF_LOGGER=1`, `GGML_VK_PERF_LOGGER_FREQUENCY=1`,
`GGML_VK_SERIALIZE_SUBMISSIONS=1`, the two ICD names, and `QWEN_PERF_LOGGER=1`,
and nothing else in those families, which is the closed profile as
declared. The reader at the acquisition head read the I1 record for the
first time in a served arm: slot 10 accepted whole with 63 decode graphs,
`ownership=conclusive`, a cross-pipeline overlap fraction of 0.0070, a
97.29 ms bracket union, 2.14 ms of queue time outside every bracket, and a
1.52 ms residual, within 0.4% of the 0426Z readings on every figure.

The sampler at nice 19 pinned to core 1 still refused on gaps in every
sampled arm: median 10.0 ms, p99 12.7 to 14.0 ms, maximum 41 to 42 ms,
with one to ten over-bound gaps inside a window. The holes recur about once
a second, which is the cadence of the runtime monitor and the two
watchdogs that sample on core 1 at nice 0 by design, so a nice-19 sampler
on that core yields to them for the length of each sample. The sampler is
now confined to both cores, so a guard burst on core 1 moves it to core 0,
and the sidecar control prices what it then takes from the server's core.

The two I1 arms sat 2.5% and 1.9% under their I0 neighbors, one outside
the 2% collection bound. The instrument's per-graph text formatting of
658 dispatch rows is the cost, and the emission is now deferred into a
preallocated binary buffer drained at context close, which the workstation
smoke measured at 86 microseconds per graph on the path against 878.

## The S inventory, read offline

`arms/13-S/perf-logger-inventory.tsv` folds the retained slice under the
analysis head's parser: 64 complete blocks, 63 decode and 1 prefill, 19
ops. Per decode block the serialized identity control counts 181 `MUL_MAT`
and 30 `MUL_MAT_ADD` calls, 211 matmul-family dispatches, which equals the
I1 census's 162 Q4_K, 25 Q6_K, and 24 f32 matmul dispatches per decode
graph; `RMS_NORM_MUL` 79, `GET_ROWS` 38, `GATED_DELTA_NET` 18, `MUL` 42,
`CPY` 36, `L2_NORM` 36 agree with the census families the same way. Under
serialization a `MUL_MAT` averages 1127 microseconds against the 206
microsecond Q4_K median under low-async, so the serialized profile's four
times slower token is per-dispatch host waiting rather than device time,
and S is an identity control alone.

## Retention

Retained: `arms.tsv`, `inputs.tsv`, `terminal-state.tsv`, `summary.tsv`,
`calibration-contract.tsv`, `campaign-inputs.tsv`, every sidecar verdict,
the slot 10 decode and prefill ledgers, the S slice with its inventory and
effective environment, and the request windows. Paths are rewritten to
`$HOME` and the host to `qwen-laptop`.
