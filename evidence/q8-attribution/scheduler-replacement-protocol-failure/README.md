# Q8 scheduler replacement stopped before prerequisite classification

## Result

Authorization `q8-scheduler-replacement-20260910-01` was consumed by the first
appliance prerequisite attempt and is closed. The attempt stopped before the
registered runner started, so it produced no scheduler-attributed calibration
rows and admits neither the proposed instrument nor Q8 candidate timing.

The failure came from the acquisition wrapper rather than from the registered
broker. The wrapper tried to read `/proc/self/task/$$/schedstat` through a
spawned reader. `/proc/self` then named the reader while `$$` still named the
parent shell, making the composed path invalid. The attempt therefore retained
no valid observation of `kernel.sched_schedstats` or task schedstat. The result
must not be interpreted as a scheduler-facility refusal.

The initial authorization source record also contains literal `\t` and `\n`
characters instead of tab and newline separators. The private source remains
unchanged and is bound by digest. `result.tsv` is the reviewed derivative and
does not present the malformed source as valid TSV.

## Bound identities and stopping rule

The attempt bound proposed tuple
`8b90eca504bf02017999a26eb47eea0f2cd148edc955548733f06f056a31a3e1`.
The appliance copies of the runner, telemetry-broker source, and sidecar
validator matched the preregistered SHA-256 identities before the wrapper
failed. The appliance checkout itself remained intentionally dirty and was not
modified.

The single-use stopping rule closed the authorization on this protocol failure.
The telemetry broker was not built or launched, the registered acquisition
directory remained absent, and every calibration arm remained unstarted. A
later attempt requires a new authorization reference; this record authorizes no
retry.

## Retention and preservation

Private records remain below the declared runtime results root in the
authorization-named wrapper directory. They retain the original malformed
authorization bytes, terminal state, preservation observations, a raw-record
digest manifest, and the reviewed source summary. Credentials, addresses, and
private runtime paths remain outside Git.

The post-stop observations found all seven owned service processes alive with
their recorded start identities. Authenticated router, broker, and artifact
requests returned `200`, while unauthenticated requests returned `401`, `403`,
and `401`. The served page SHA-256 remained
`4539f12f10cd2627383c3bd3ece520273061c7954ae40205668de0d5a8c6a891`,
KSM remained `1`, DPM remained `auto`, and the single QEMU process retained its
recorded identity. These observations cover only the enumerated surfaces.

The authorization covered no model-server rebuild, deployment change,
kernel-setting change, Q8 candidate timing, or n-gram experiment. Q8 remains
held under the unchanged full-row `1,000,000 ns` mean bound.
