# 2B calibration on 34de93f: the first census records, under a failed calibration

```text
measurement_status=diagnostic
acquisition_head=34de93f10ff439b86ae17e084051a994d078c74a
analysis_head=the commit that adds this file; its reader computed the ledgers here
instrument_version=pipeline-census-v3
calibration_verdict=failed
merge_authority=no
ownership_authority=provisional
```

The thirteen-arm calibration ran on the appliance with the runner at
`34de93f` and the runtime tree at the same head. Every arm launched, every
rate was measured, and the campaign still terminated `failed` with eleven
failed arms and three incomplete controls, for three reasons that are each
a harness defect rather than a device result. The raw records stay on the
appliance under `$HOME/raven2-kernel-census-20260902T0426Z-2b-calibration-v5/`;
the two I1 census files are 10 MB each and are retained by digest:

```text
arms/10-I1/pipeline-census.tsv  4a92daa7cc485f58a3cadc3b38159ee63fa6f68067f9bd8ec4da81555f10ed17
arms/11-I1/pipeline-census.tsv  f919ded18b5e6bb469a643a32e778cf1cd680aee6aa2f1900bee926029cc5ffa
```

## Why the calibration failed

- **Sidecar gaps.** Every sampled arm refused on `gaps`: the median gap held
  5.0 ms and the p99 7.3 ms, while the maximum reached 58 ms with ten gaps
  above the 10 ms bound and four to ten inside each request window
  (`arms/*/clock-sidecar-verdict.txt`). The sampler ran at nice 10 on core
  1 and the holes are the scheduler preempting it for a nice-0 burst, since
  the sample cost itself stayed near 600 microseconds. The sampler now runs
  at the appliance's mandatory nice 19, every 10 ms, under a 20 ms bound.
- **The reader refused the record.** The pinned server opens two backend
  contexts and the first runs no graph, so each I1 file carries two
  `census_queue` headers and the reader at the acquisition head refused it
  on cardinality. The reader at the analysis head reads the file as context
  sections and selects the one the request window intersects.
- **The reader classified every graph as prefill.** An f32 matmul in a
  decode graph is a Gated DeltaNet chunk product whose column count is 2,
  8, or 32, so the largest `MUL_MAT` column was never 1. The token column is
  now read over weight matmuls alone, those whose source type is other than
  f32, the rule the perf-logger parser already applied.
- **The S arm never ran its request.** `monitor-qwen-runtime.sh` refused
  the `diagnostic` profile by name, the session ended the server with
  `reason=monitor_exited` two seconds after readiness, and the diagnostic
  server then hung at exit in `futex_do_wait` after "cleaning up before
  exit", which left the relaunch refusing on a running server until it was
  killed. The monitor now admits the profile under the serialized gate; the
  exit hang under the perf logger is unexplained and is watched for on the
  next S arm.

## What the rates say on their own

| slot | arm | tok/s | status |
| ---: | --- | ---: | --- |
| 1 | P-nosidecar | 8.410 | completed, cold opener |
| 2 | P | 9.877 | sidecar refused |
| 3 | P | 9.889 | sidecar refused |
| 4 | P-nosidecar | 9.909 | completed |
| 5 | P | 9.903 | sidecar refused |
| 6 | I0 | 9.856 | sidecar refused |
| 7 | I0 | 9.884 | sidecar refused |
| 8 | P | 9.880 | sidecar refused |
| 9 | I0 | 9.907 | sidecar refused |
| 10 | I1 | 9.670 | sidecar refused; census read below |
| 11 | I1 | 9.635 | sidecar refused; census read below |
| 12 | I0 | 9.889 | sidecar refused |
| 13 | S | - | monitor_exited |

The controls are incomplete by rule, since a refused sidecar fails the arm,
and no delta is quoted from them. Read informally, the sampled P arms sit
within 0.3% of the unsampled closing P arm and the I0 arms within 0.5% of
their neighboring P arms, which is inside both registered bounds; the cold
opener at 8.410 is position, as in the 0307Z run, and licenses nothing about
the sampler. The two I1 arms sit 2.4% and 2.6% below their I0 neighbors,
outside the registered 2% collection bound, so a calibration whose sidecar
accepts is expected to refute the collect control on this instrument: the
ledger accounts 1.08 ms of emission per graph inside the instrument and the
rest of the cost sits in the host path the ledger overlaps with execution,
and the remedy the review names, fixed-size rows formatted after the
request with no per-graph flush, is the next instrument change if the
rerun confirms it.

## The census records, read by the analysis head

Both I1 ledgers (`arms/*/pipeline-ledger-decode.tsv`) select the second
context, hold 63 contiguous decode graphs, and read `ownership=conclusive`
at an overlap fraction of 0.0103 with 0.0069 of it cross-pipeline. Per
decode graph, the two arms agree within 0.1%:

| quantity | per graph |
| --- | ---: |
| bracket union | 97.24 ms |
| exclusive time | 96.24 ms |
| queue completion span | 99.08 ms |
| queue time outside every bracket | 1.83 ms |
| host retire span | 100.65 ms |
| residual beyond queue completion | 1.58 ms |
| submissions | 40 |
| dispatches | 658 |
| host record time, overlapped with execution | 17.05 ms |
| emission cost inside the instrument | 1.08 ms |

The families, per graph, from the 63-graph totals:

| pipeline | calls | union ms | exclusive ms | median us | VGPRs | LDS | waves per SIMD |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| mul_mat_vec_q4_k_f32_f32 | 162 | 51.78 | 51.10 | 206.4 | 64 | 0 | 4 |
| mul_mat_vec_q6_k_f32_f32 | 25 | 36.41 | 36.37 | 568.3 | 64 | 512 | 4 |
| get_rows_f32_f32 | 37 | 2.30 | 2.20 | 16.3 | 4 | 0 | 10 |
| gated_delta_net_f32_d128 | 18 | 1.86 | 1.72 | 102.9 | 64 | 0 | 4 |
| contig_cpy_f32_f32 | 18 | 1.32 | 1.31 | 73.0 | 8 | 0 | 10 |
| rms_norm_mul_f32 | 73 | 0.88 | 0.83 | 10.2 | 40 | 2048 | 6 |
| concat_i32 | 18 | 0.60 | 0.54 | 33.0 | 24 | 0 | 10 |
| cpy_f32_f32 | 24 | 0.43 | 0.26 | 21.6 | 16 | 0 | 10 |
| ssm_conv_silu_f32 | 18 | 0.37 | 0.32 | 20.5 | 12 | 0 | 10 |
| l2_norm_f32 | 36 | 0.33 | 0.22 | 9.9 | 8 | 2048 | 10 |
| flash_attn_f32_f16_aligned | 6 | 0.35 | 0.35 | 56.2 | 128 | 29184 | 2 |
| everything else | 241 | about 1.6 | | | | | |

The two mat-vec families hold 88.2 ms of the 97.2 ms union, 91% of the
graph, with 3.4 ms of queue idle and residual and about 9 ms across every
other family. The sidecar, refused as a control, still places the clocks:
inside each I1 request window `pp_dpm_mclk` read 1067 MHz on every one of
about 1420 samples, `pp_dpm_sclk` read 1100 MHz on 89% and 1083 MHz on 8%,
with a ramp from 400 MHz over the first 40 samples that is the prompt
phase, and `gpu_busy_percent` averaged 94.

## Retention

Retained here: `arms.tsv`, `inputs.tsv`, `terminal-state.tsv`,
`summary.tsv`, `calibration-contract.tsv`, `campaign-inputs.tsv`, both
decode ledgers with their request windows, every sidecar verdict, and the
S arm's launch and runner records. The raw census files, the sidecar
records, and the per-arm server records stay on the appliance. Paths are
rewritten to `$HOME` and the host to `qwen-laptop`.
