# Q8 scheduler replacement wrapper readiness

## Decision

The workstation repair is ready for review. The repair reaches the unchanged
census runner only after the authorization record round-trips through the
execution reader, every registered source identity matches, and the scheduler
prerequisite checker reads the current Python task's own procfs record. The
focused integration fixture reached that runner boundary exactly once without
executing an appliance arm.

The repair establishes wrapper behavior on workstation fixtures. It establishes
neither the appliance scheduler prerequisite state nor a calibration result.
Q8 candidate timing remains withheld. The stopped acquisition under
`q8-scheduler-replacement-20260910-01` remains closed and unchanged.

## Repair and scientific identities

| Role | Path | SHA-256 |
| --- | --- | --- |
| Repaired wrapper | `remote/run-q8-scheduler-replacement.py` | `42604d28c00c67594620f0c7c9a2af5473f68bf9ec278a8c813ded7d8f237b1a` |
| Focused regression | `remote/test-run-q8-scheduler-replacement.py` | `4e708090a2a3f88d2730327d3bd07379114f838db19d237b7daf4c9a545c15bb` |
| Proposed scientific tuple | `evidence/q8-attribution/sampler-cost-attribution/proposed-acquisition-tuple.tsv` | `8b90eca504bf02017999a26eb47eea0f2cd148edc955548733f06f056a31a3e1` |
| Refused scientific tuple | `evidence/q8-attribution/sampler-cost-attribution/refused-acquisition-tuple.tsv` | `f3daaf6efe5a1b20abbf849720183969a1b37cd574050300f4fbd2728e7155c9` |
| Census runner | `remote/run-raven2-vulkan-kernel-census.sh` | `e78585678ea3fce7689175d1aa65822ce5381f90b8459d83ef457afb79da5f5a` |
| Broker source | `remote/telemetry-broker.c` | `bfc8867fcb314a375465ee0027016799522022e5f9704a8e6d6eceb470ae9b58` |
| Sidecar validator | `remote/validate-clock-sidecar.py` | `698a6711d1761479ff1e552498ebab5999b5740d076bca8b24176db2d5b35f72` |

The wrapper identity is execution provenance. The proposed tuple retains the
scientific mechanism, cadence, affinity, niceness, full-row denominator, and
`1,000,000 ns` admission limit. The wrapper repair changes none of those tuple
fields.

## Focused regression result

`python3 remote/test-run-q8-scheduler-replacement.py` completed with exit status
0. `regression-results.tsv` retains each bounded result. The fixtures reproduced
the mixed parent/child procfs failure without classifying the scheduler facility,
read the same Python process's task record, distinguished prerequisite states,
refused malformed authorization records, retained a complete pre-calibration
terminal record with zero child starts, reached the runner boundary once in an
accepted integration fixture, and stopped an owned runner process group at its
deadline.

Ruff formatting and lint, strict mypy, and the pull-request routing fixture also
completed with exit status 0. The new files select the existing
`q8-sampler-attribution` route. The routing registration adds no gate and changes
no exhaustive-gate rule.

## Next operation and stopping rule

After review and merge, an operator may prepare one new closed-schema
authorization record with the merged wrapper and then execute one fresh
authorization-named result directory through the same wrapper. The execution
first validates and consumes the record, verifies all five source identities,
and reads `kernel.sched_schedstats` plus the Python reader's own task schedstat.

An absent, unreadable, disabled, or malformed prerequisite stops before the
census runner starts. An identity, record, lifecycle, deadline, runner, or
restoration failure stops the acquisition and leaves Q8 candidate timing
withheld. A calibration refusal closes that proposed tuple against an identical
retry. A calibration pass admits only the registered calibration result and
does not start candidate timing.

The workstation repair contacted no appliance and changed no serving bundle,
executable, page, VM, access boundary, kernel setting, hardware policy, or
n-gram decision.
