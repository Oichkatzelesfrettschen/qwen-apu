# Q8 calibration sampler-cost analysis

## Conclusion

Arm `09-P` refused the registered sidecar acquisition-quality contract because the 748 retained `sample_cost_ns` values sum to 776,487,760 ns. Integer floor division produces 1,038,085 ns, which exceeds the registered 1,000,000 ns mean-cost bound by 38,085 ns. The raw distribution is strongly right-skewed: its median is 61,647.5 ns, while 42 samples exceed 1,000,000 ns and contribute 643,939,112 ns, or 82.93% of the total measured sampling cost.

The refusal establishes an instrumentation/acquisition failure. The metric measures elapsed host time spent in each broker sampling iteration. Every iteration reads GPU busy; scheduled multirate iterations also read DPM clocks and delivered SCLK, temperature, memory, and host surfaces. The metric does not measure a Vulkan kernel duration. Arm `09-P` completed its request with status 0 at 16.2112 decode tokens/s, held the registered 1100/933 MHz clock state throughout the request window, and retained zero in-window lost gaps. Those observations cannot admit the calibration because the unchanged acquisition contract refused.

## Exact raw samples above the registered bound

The validator applies the 1,000,000 ns bound to the aggregate mean rather than to each row. The following table enumerates every raw row whose individual sampling cost exceeds that bound, in acquisition order. `GPU busy` and temperature are values carried on the same row; they do not identify which sensor read consumed the elapsed time.

| Monotonic ns | Phase | Sample cost ns | GPU busy % | Temperature C |
| ---: | --- | ---: | ---: | ---: |
| 910114122040801 | pre-request | 2,983,533 | 4 | 72 |
| 910114300390941 | pre-request | 1,768,527 | 3 | 81 |
| 910115060339650 | pre-request | 1,143,560 | 0 | 81 |
| 910115780606119 | pre-request | 1,465,181 | 0 | 80 |
| 910115840334317 | pre-request | 8,710,571 | 0 | 80 |
| 910116241736452 | pre-request | 35,905,424 | 0 | 80 |
| 910116368702218 | pre-request | 1,491,651 | 0 | 80 |
| 910116546842238 | pre-request | 8,754,274 | 0 | 79 |
| 910116606850464 | pre-request | 56,597,404 | 0 | 79 |
| 910116746887243 | pre-request | 23,304,629 | 0 | 79 |
| 910116905019495 | pre-request | 5,064,522 | 0 | 79 |
| 910117424571057 | pre-request | 44,877,792 | 0 | 78 |
| 910118110019298 | pre-request | 28,269,370 | 0 | 77 |
| 910119050021436 | pre-request | 5,058,730 | 0 | 77 |
| 910119489794070 | pre-request | 19,021,088 | 0 | 77 |
| 910119549988536 | pre-request | 18,138,803 | 0 | 77 |
| 910119589921580 | pre-request | 12,169,394 | 0 | 77 |
| 910119990025889 | pre-request | 68,366,733 | 0 | 77 |
| 910121339035340 | pre-request | 1,999,364 | 0 | 77 |
| 910121378475366 | pre-request | 5,294,107 | 0 | 77 |
| 910122240035884 | pre-request | 2,256,723 | 0 | 78 |
| 910122351037641 | pre-request | 31,994,716 | 0 | 78 |
| 910123043102869 | pre-request | 1,363,257 | 20 | 77 |
| 910124124547829 | pre-request | 66,589,522 | 4 | 76 |
| 910124214756972 | pre-request | 56,771,191 | 4 | 76 |
| 910124312014110 | pre-request | 4,323,915 | 3 | 76 |
| 910124931600488 | request | 5,029,965 | 71 | 76 |
| 910125831808935 | request | 3,227,354 | 79 | 76 |
| 910125971648749 | request | 2,384,745 | 83 | 76 |
| 910126035041761 | request | 1,911,137 | 86 | 76 |
| 910126091714190 | request | 2,747,584 | 83 | 76 |
| 910126351704156 | request | 30,915,103 | 85 | 76 |
| 910126433037561 | request | 1,023,412 | 85 | 76 |
| 910128111605611 | request | 1,713,051 | 83 | 76 |
| 910128171595351 | request | 3,190,494 | 88 | 76 |
| 910128936615629 | post-request | 19,702,625 | 2 | 85 |
| 910128956341849 | post-request | 12,257,668 | 2 | 85 |
| 910129052015666 | post-request | 12,939,923 | 0 | 85 |
| 910129112837042 | post-request | 17,178,105 | 0 | 85 |
| 910129152016473 | post-request | 8,020,379 | 0 | 85 |
| 910129172014529 | post-request | 4,014,177 | 0 | 85 |
| 910129232018604 | post-request | 3,999,409 | 0 | 85 |

The largest row occurs at monotonic instant 910119990025889, before the request, and costs 68,366,733 ns. The unmodified aggregate exceeds its allowance by 28,487,760 ns (`776,487,760 - 748 x 1,000,000`). A leave-one-out sensitivity calculation that removes only that largest row leaves 707,121,027 ns across 747 rows, or 947,953.18 ns per row. This calculation shows that the largest row is sufficient to change the binary verdict under deletion. The registered evidence contains the row, so the calculation does not authorize deleting, trimming, winsorizing, or reclassifying it; all 748 rows remain the denominator.

## Distribution and phase

| Statistic | Retained value |
| --- | ---: |
| Samples | 748 |
| Total cost | 776,487,760 ns |
| Minimum | 16,431 ns |
| Median | 61,647.5 ns |
| P90, linearly interpolated | 617,460 ns |
| P95, linearly interpolated | 1,482,386 ns |
| P99, linearly interpolated | 29,671,608 ns |
| Maximum | 68,366,733 ns |
| Samples above 1 ms | 42 |
| Samples above 5 ms | 24 |
| Samples above 10 ms | 17 |
| Samples above 20 ms | 10 |
| Samples above 40 ms | 5 |
| Samples above 60 ms | 2 |

| Phase | Definition | Samples | Mean cost ns | Median cost ns | Maximum cost ns | Samples above 1 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Pre-request | `t < 910124319223991` | 494 | 1,221,744 | 76,375 | 68,366,733 | 26 |
| Request | `910124319223991 <= t <= 910128468816516` | 207 | 427,521 | 54,363 | 30,915,103 | 9 |
| Post-request | `t > 910128468816516` | 47 | 1,796,792 | 114,307 | 19,702,625 | 7 |

The pre-request and post-request means exceed the contract while the request-window mean is 427,521 ns. The largest seven samples all occur before the request; the largest in-request sample is 30,915,103 ns at monotonic instant 910126351704156 with GPU busy 85%. The phase split argues against attributing the aggregate refusal specifically to kernel execution. The retained rows cannot identify scheduler delay, filesystem/sysfs latency, or the cost of an individual sensor read.

The cadence checks supply a separate acquisition observation. The sidecar achieved 20,577,442 ns against the 20,000,000 ns requested period; its median gap is 20,000,008 ns, P95 gap 27,334,157 ns, P99 gap 54,304,782 ns, and maximum gap 90,209,143 ns. The validator accepted cadence, request-window coverage, and a 0.0000 in-window lost fraction. These accepted checks do not override the failed mean-cost check.

## Retained host and arm records

The clock sidecar retains eight host snapshots. `pswpin` is the cumulative counter recorded by the sampler, rather than an interval delta inferred here.

| Monotonic ns | Load1 | MemAvailable KiB | pswpin | KSM pages sharing |
| ---: | ---: | ---: | ---: | ---: |
| 910114020262230 | 3.85 | 13691896 | 551934 | 690267 |
| 910116024242614 | 3.85 | 13690336 | 551934 | 690364 |
| 910118189529013 | 3.78 | 13688924 | 551936 | 690722 |
| 910120260059165 | 3.78 | 13689364 | 551936 | 691141 |
| 910122258467021 | 3.80 | 13798188 | 551936 | 691128 |
| 910124451611312 | 3.80 | 13730692 | 551936 | 691149 |
| 910126451615073 | 3.80 | 13727920 | 551936 | 691035 |
| 910128453039089 | 3.81 | 13721340 | 551936 | 690948 |

The request-window snapshots fall at 910124451611312, 910126451615073, and 910128453039089. They record load1 3.80 to 3.81, available memory declining from 13,730,692 to 13,721,340 KiB, unchanged `pswpin=551936`, and KSM pages sharing from 691,149 to 690,948. The retained per-second arm telemetry records zero swap-in bytes for its five shown samples, GPU busy from 4% to 84%, temperatures from 76.625 C to 78 C, and the selected 1100 MHz SCLK and 933 MHz MCLK surface. The sidecar validator derives 207 request-window samples, actual SCLK at 1100 MHz for every fresh clock observation, MCLK at 933 MHz for every fresh clock observation, mean GPU busy 79.86%, mean temperature 76.0 C, and maximum temperature 76.0 C.

Arm identity and lifecycle evidence is present: `inputs.txt`, `arm-environment.tsv`, `runtime-identity.tsv`, `runtime-inputs.json`, `request-window.tsv`, `summary.json`, server and request logs, latency and kernel-hazard logs, teardown output, and the C1 brick receipt. The C1 receipt hashes the arm artifacts and marks the compile control `incomplete`. The clock-sidecar stderr records sampler PID 2200625, period 20,000,000 ns, niceness 19, CPU affinity `0,1`, 748 drained samples, mean 1,038,085 ns, maximum 68,366,733 ns, zero rejected marks, and zero ring-full events.

## Metric interpretation and bounded claim

The retained C broker records a monotonic `begin`, reads `gpu_busy_percent` on every iteration, and conditionally reads DPM clocks plus delivered SCLK every tenth iteration, temperature every tenth, memory every hundredth, and load/KSM every hundredth. It then records a monotonic `end` and stores `sample_cost_ns = end - begin`. The broker reported a separate fast-path mean of 851,467 ns over 673 GPU-busy-only iterations, but the validator applies the registered bound to the mean across all 748 rows. The validator independently recomputes `sum(costs) // len(costs)` and rejects when that value exceeds `--cost-bound-ns`.

Therefore the failure belongs to the sidecar's observational overhead and scheduling surface. Host descheduling during an iteration would be included in the cost, as would slow sysfs or procfs reads. The record supplies neither per-read timestamps nor scheduler events, so the evidence cannot distinguish those mechanisms. Vulkan kernel execution can contend with the host or device paths that expose these surfaces, but the retained metric does not time or attribute a kernel. The request-window mean being below the bound and most extreme samples occurring outside the request further withhold a kernel-performance attribution.

Other retained arms show that large maxima alone do not trigger refusal: `07-P` passed with maximum 83,206,544 ns and mean 512,382 ns, and all other sidecar-bearing arms passed with means from 226,361 to 869,556 ns. Arm `09-P` is the only retained sidecar verdict whose mean exceeds the contract. This comparison supports a localized acquisition-quality refusal; it does not establish why arm `09-P` accumulated more host-side cost.

## Smallest supported next workstation action

Keep arm `09-P` and the compile-control brick refused. The smallest next workstation-only action is a read-only retained-byte reduction across every sidecar-bearing arm that emits the same phase split and tail statistics used here, then compares arm `09-P` with its neighboring `P`, `I0`, and `I1` arms. The reduction should consume the existing TSV files, bind each output row to the input SHA-256 already present in the brick receipts, and leave the registered mean and verdict unchanged. That action tests whether the pre/post concentration is unique to `09-P` without contacting the device, rerunning acquisition, changing source, or relaxing the threshold.

## Missing evidence

The acquisition lacks the evidence needed to assign a root cause:

- Per-surface start/end timestamps cannot distinguish latency in GPU-busy, SCLK, MCLK, FCLK, delivered-SCLK, temperature, memory, load, or KSM reads. The periodic schedule identifies which set was due, but not which read consumed the cost.
- Scheduler trace data cannot distinguish active sysfs work from descheduling, interrupt handling, CPU contention, or wake-up latency on CPUs 0 and 1.
- Per-sample CPU identity, run-queue depth, context-switch counters, and IRQ/softirq activity are absent.
- The 2-second host records are too coarse to align short cost spikes with transient host activity.
- The raw record carries a sample instant and total cost but no explicit end instant; the end can only be derived as `instant + cost` under the reader's documented semantics.
- The sidecar rows provide contemporaneous GPU busy and temperature values but no causal attribution between those values and read cost.
- Independent GPU timestamp queries joined to dispatched kernel identity are outside this calibration sidecar record, so kernel duration and kernel-specific slowdown remain unmeasured by this failure.
- A retained explanation for why `arm09-P` differs from the other accepted sidecar arms is absent.

The missing evidence prevents a mechanism-level diagnosis. The existing evidence is sufficient to preserve the acquisition refusal and to prevent the refused arm from supporting Q8 calibration or kernel-performance claims.
