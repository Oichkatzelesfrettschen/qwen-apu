# Q8 sampler-cost scheduler attribution preregistration

## Decision

Q8 remains held. Calibration arm `09-P` retained 748 rows whose
`sample_cost_ns` values sum to `776,487,760 ns`; integer floor division gives
`1,038,085 ns`, which exceeds the unchanged `1,000,000 ns` full-row bound by
`38,085 ns` or 3.8085%. The request-window diagnostic mean of `427,521 ns`
does not replace that denominator, and the refusal does not measure a 3.8085%
inference slowdown.

The retained rows time one complete broker iteration with `CLOCK_MONOTONIC`.
They cannot distinguish sensor work from time the host scheduler kept the
sampler runnable but off-CPU. The successor tuple adds that missing
observation through an explicit `schedstat` mode. The default broker mode and
every existing acquisition contract keep their legacy eight-column shape.

## Bound tuple identities

| Tuple | Canonical file | SHA-256 | State |
| --- | --- | --- | --- |
| Refused | `refused-acquisition-tuple.tsv` | `f3daaf6efe5a1b20abbf849720183969a1b37cd574050300f4fbd2728e7155c9` | `09-P` refused |
| Proposed | `proposed-acquisition-tuple.tsv` | `58b21ffa2ead66490c513001cbe3160efe82f528c3012c59b48bd81556c35afc` | preregistered, not run |

The refused tuple binds the retained sidecar digest and the broker, validator,
and runner source identities available at the acquisition revision. The
proposed tuple binds the reviewed source candidates. A later appliance
preflight must build the broker, write its executable digest and complete
acquisition-contract digest into the fresh result directory, and prove that
the executable source record equals the proposed broker source digest before
an arm starts. A workstation-built ELF digest cannot substitute for that
appliance build identity.

## Mechanism and row semantics

`QWEN_CENSUS_SCHEDULER_ATTRIBUTION=schedstat` adds
`sidecar_scheduler_attribution=schedstat` to the acquisition contract and
passes `--scheduler-attribution schedstat` to the broker. The broker requires
`kernel.sched_schedstats=1` and opens its own
`/proc/self/task/<pid>/schedstat`. The runner and broker both refuse a disabled
or unreadable facility; neither changes the kernel setting.

For each row, the broker performs these bounded operations:

1. Record the `CLOCK_MONOTONIC` beginning.
2. Read the task's cumulative runnable-but-unscheduled counter.
3. Read the scheduled sensor surfaces at their unchanged cadence.
4. Read the counter again and record the `CLOCK_MONOTONIC` ending.
5. Emit `sample_cost_ns`, the counter delta as
   `scheduler_runqueue_delay_ns`, and their exact difference as
   `non_scheduler_elapsed_ns`.

The residual includes sensor service, parsing, and both schedstat reads. It is
not a pure sensor latency. A long wall-clock row with a zero scheduler delta
remains a long residual and receives no scheduler attribution. Counter
regression, read failure, a delay larger than its enclosing wall interval, an
arithmetic mismatch, a stale footer, or a schema/format mismatch refuses the
record.

## Causal prediction and falsifiers

The change adds two schedstat reads per iteration, so it has a small positive
cost rather than an assumed speed benefit. Its causal purpose is to determine
whether the long right tail comes from runnable host descheduling. If scheduler
delay caused a retained tail row, that row will carry a nonzero delay bounded
by `sample_cost_ns`; if the delay remains zero, the row stays in the
non-scheduler residual. A long wall row alone never satisfies the scheduler
prediction.

The replacement calibration admits its instrument only when every retained
row passes the schema and partition checks and the integer-floor mean of every
row's unchanged `sample_cost_ns` is at most `1,000,000 ns`. Scheduler
attribution explains a row but does not remove it, discount it, move it to
another phase, or change the admission calculation. The following outcomes
falsify or stop the proposed tuple:

- `sched_schedstats` is absent, unreadable, or disabled;
- either per-row counter read fails or the cumulative counter regresses;
- any row fails `scheduler_delay <= sample_cost` or the residual identity;
- any attribution footer aggregate differs from its rows;
- the complete full-row mean exceeds `1,000,000 ns`;
- lifecycle, control, restoration, or retained-output closure fails.

Any refusal closes this proposed tuple. It authorizes neither Q8 candidate
timing nor an identical retry. A passing instrument admits only the one
registered calibration and does not itself admit the Q8 candidate.

## Focused fixture closure

The workstation fixtures completed with exit status 0 on 2026-09-10:

| Command | Bounded result |
| --- | --- |
| `sh remote/test-telemetry-broker.sh` | 28 checks passed, including disabled and malformed preflight refusals, attributed partition closure, and legacy default shape |
| `python3 remote/test-census-controls.py` | accepted legacy and attributed records; refused schema, row arithmetic, counter-bound, and footer defects; retained a long wall row with zero scheduler delay as residual |
| `sh remote/test-run-raven2-vulkan-kernel-census.sh` | 60 preflight cases passed; the attributed contract changed identity, print mode stayed device-free, and disabled schedstats refused before output creation |

The broker source also compiled with `-O2 -Wall -Wextra -Werror -std=c11`.
These fixtures establish producer/reader and preflight behavior on synthetic
surfaces. They establish no appliance availability, acquisition cost, Q8
performance, or hardware result.

The mechanism-scoped pull-request route selected
`q8-sampler-attribution` over the 13-file workstation diff. Two complete local
route executions passed all 11 registered checks in 125.486 and 127.863
seconds. The universal repository gate did not run. Scheduled full validation
and the final merge-ready exhaustive check keep their existing roles;
incremental Q8 sampler work uses this bounded route.

## One authorized replacement and retention

The successor uses a fresh result directory and the existing bounded census
wrapper with `QWEN_CENSUS_SCHEDULER_ATTRIBUTION=schedstat`. It preserves the
model, servers, sampled surfaces, cadences, CPU affinity, niceness, control
bounds, full-row denominator, and `1,000,000 ns` admission limit from the
proposed tuple. The operator must provide separate named execution authority.

The result directory retains the printed acquisition and analysis contracts,
broker source record and executable digest, complete `clock-sidecar.tsv` and
stderr for every arm, request windows, arm environments, server and request
records, controls, brick receipts, terminal state, restoration evidence, and
the final admission verdict. A protocol or restoration failure stops the run
and leaves later arms `not_run`. Private paths and raw runtime records remain
under the declared runtime root; a public derivative may expose identities,
criteria, and bounded observations only.

The following actions remain outside this preregistration: threshold changes,
row deletion, phase exclusion, model rebuilds, unchanged calibration repeats,
Q8 candidate timing, sudo, kernel-setting changes, authentication changes,
VM changes, and appliance deployment changes.
