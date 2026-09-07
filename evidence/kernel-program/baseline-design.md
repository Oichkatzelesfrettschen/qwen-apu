# Served baseline acquisition contract

A kernel comparison needs an attributable served denominator. The baseline runner
retains launch-to-readiness, first-content latency and repeated ordinary decode
inside one loaded session. A completed acquisition separates five claims:
`within_binary_repeatability`, `cross_binary_token_comparison`,
`acquisition_completeness`, `instrument_admission`, and `performance_result`.
The device baseline remains unrun until a reviewed acquisition supplies its result.

## Registered execution state

`compute-state-lease.sh serve-baseline-fixed` holds the existing Vulkan lease,
selects SCLK=2/FCLK=2 (1100/933 MHz), applies stock package power transactionally,
and preserves KSM as found. The standing VM stays running. The orchestration
process and monitor run at nice 0; serving policy assigns inference nice 19,
one thread, one batch thread, Vulkan0 placement and all GPU layers. The lease
retains observed state and verifies restoration. Broader privileges and root
execution of the whole harness are prohibited.

Prepare the telemetry broker from the exact source before opening the window.
The sampler retains delivered `sclk_actual_mhz`, channel cadence, nice 19 and
CPU affinity 0,1 under the existing clock validator. The first retained sample
precedes the decode marker and a covering sample follows the last request.
The actual wait status and validation status govern admission. Quiescence failure
terminates the acquisition before another arm starts.

## Acquisition and reading

The runner binds model bytes, executable and manifest, runtime payload and source,
actual process argv, thread count, placement, Q4_K selection and the served tuple.
Available manifest variants describe build capability; the process environment
and selection log describe the running selection. The baseline explicitly selects the registry's released variant, with production/4
where the row releases none. `QWEN_BASELINE_Q4K_VARIANT` registers another exact
selection, including the standing bundle's selection when its authority differs
from source main. Record that choice before acquisition; each process must log
that exact variant. The explicit experiment route changes the loopback measurement
arm alone and leaves deployment links and registry rows intact.

One streamed warmup records the first content timestamp and drains through a
validated terminal response. Token IDs come from partial events; terminal timings
complete the record. Four fixed-length, greedy, uncached repeats follow. Each
retains request elapsed timestamps, raw response and canonical token IDs.
Readiness and requests use elapsed deadlines. Every failure retains its primary
reason separately from cleanup outcome.

The reader reparses requests and raw responses, validates finite positive timing
fields and exact integer counts, recomputes token arrays and rates, and requires
the registered unique repeats and ordered arms. The pinned ordinary completion
rate counts `predicted_n - 1` decode transitions; speculative rounds require a
separate population contract. Raw telemetry is reread through the current validator.
Acquisition code and its hashes stay retained independently of the current reader
hash. Reprocessing preserves the original acquisition identity.

Malformed records and incomplete instruments refuse a performance denominator.
Repeat divergence remains a scientific finding. A stable candidate whose token
array differs from control reports cross-binary divergence and withholds its
performance comparison.

## Interpretation and stopping rule

Server decode timing numerically excludes model loading. Startup can influence
later clocks, caches and thermal state. A spread above 4% reports variability;
it does not identify a governor failure. Four-launch correlation does not establish
a warmup defect. The registered four-repeat count stays fixed after observing data.

Single mode measures within-session repeatability. A C K K C bracket has two
candidate launches and two control launches; its candidate/control ratio is
descriptive and supplies neither a confidence interval nor a promotion decision.
A bracket requires distinct, identity-compatible binaries. Same-binary tests use
single mode. A served baseline supplies no census-instrument calibration receipt.

## Bounded device sequence

After focused fixtures and the exact-head repository gate, synchronize once and
freeze source and deployment identities for the window. Keep the serving bundle
`lease-q4k-6b262d93-r1`. Use `run-device-window.sh` for one named 2B single-mode
canary, retaining raw output under `.runtime/results/<run-id>`:

```sh
QWEN_COMPUTE_STATE_FORWARD="QWEN_LLAMA_SERVER=$QWEN_LLAMA_SERVER QWEN_BASELINE_REPEATS=4" \
    remote/compute-state-lease.sh serve-baseline-fixed \
    remote/run-checkpoint-baseline.sh qwen38-2b-distill \
    "$QWEN_HOME/results/baseline-2b-canary"
```

The wrapper supplies teardown and restoration of authenticated service. The canary
requires a completed warmup, four completed repeats, accepted identities and sampler,
bounded teardown, restored machine state and final authenticated health. Stop on
the first infrastructure failure and retain every artifact. Only a passing canary
admits the 0.8B and 4B anchors under matching conditions in bounded windows.
The full portfolio waits for a concrete model-selection or serving decision.
Reviewed sanitized records enter tracked evidence after acquisition.
