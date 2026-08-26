# Whether the 16384 wedge indicts depth or submission geometry

`evidence/kv-cache-policy-factorial.md` records a compute-ring wedge: at 16384
tokens with the served cache triple, a submission failed to retire before the
amdgpu timeout, the driver reset the ring, and the subsequent control passed.
The exact kernel-level cause remains unisolated. Both wedges this tree has
recorded were found under `llama-bench` at its own batch defaults, `-b 2048
-ub 512`, while the guarded server runs `--batch-size 128 --ubatch-size 32`.
Depth and submission size are therefore confounded, and the 4B's 24576
interactive ceiling rests on which one is responsible.

## Configured allocation is not validated depth

```text
configured context capacity:        24,576
filled and decoded depth validated: not established
```

A server that loads a 24576-token allocation has proven it can reserve the
memory. It has not proven that a near-full cache executes. The registry field
the ceiling lives in is a scalar, and the capability being measured is a tuple:

```text
(model, cache policy, flash-attention policy, batch, ubatch, validated filled depth)
```

## The arms

`remote/probe-depth-wedge.sh` crosses two depths with three submission
geometries at the served cache triple, `q8_0`/`q4_0` with Flash Attention on.

| geometry | batch | ubatch | role |
| --- | ---: | ---: | --- |
| harness default | 2048 | 512 | establishes that the wedge reproduces |
| served | 128 | 32 | decides whether the shipped configuration is exposed |
| below served | 32 | 8 | decides which way to move if it is |

Each arm ends with a shallow control at the served geometry. A ring reset that
recovers leaves the control passing and the wedge is one rejected graph; a
control that fails establishes persistent device corruption, and the probe halts
rather than measuring a broken device.

Each arm retains its batch and microbatch, its evaluated depth, the cache types
and Flash Attention state it ran under, its peak device memory, arm wall time,
steady-state decode, the kernel lines the arm emitted verbatim with ring-reset
and fault counts grepped from that delta rather than from the whole buffer, the
control status and rate, and the modal memory clock and peak die temperature.

Device memory comes from amdgpu's own accounting sampled at 1 Hz through the
arm, `mem_info_vram_used` against the 2 GiB carve-out and `mem_info_gtt_used`
against the system memory the driver maps, and the peak of each is reported
because the KV cache grows through the prefill. Reading the driver rather than
the log is what makes the field survive the case it exists for: `llama-bench`
prints no buffer sizes at default verbosity, and an arm that wedges prints
nothing at all. The device holds far more in GTT than in the carve-out -- 2626
MiB against 2024 MiB under load, against 467 and 367 at idle -- so a ceiling
argued from the 2 GiB figure alone describes the smaller of the two pools.

Prefill wall time and first-decode latency are not separable under `llama-bench`,
which reports steady-state rates and a single arm duration. Separating them
requires the served path, and this probe records arm wall time and steady-state
decode in their place.

## Registered interpretation

Fixed before the run:

| 8192 served | 16384 served | 16384 below served | conclusion |
| --- | --- | --- | --- |
| pass | pass | pass | the wedge is a large-batch harness artefact; the served policy stands and 24576 full occupancy is tested separately |
| pass | wedge | pass | ubatch 32 crosses a Raven2 submission threshold at 16K; reduce the served microbatch and depth stays viable |
| pass | wedge | wedge | the q8_0/q4_0 Flash-Attention graph is unsafe at 16K under both practical geometries; the admitted filled-depth ceiling comes below 16K pending a backend fix |
| pass | pass | wedge | run state or ordering, because a smaller microbatch should not uniquely fail with nothing else changed; repeat in reversed order before concluding |
| wedge | - | - | the deep-context policy is unsafe below its published operating point; stop and re-establish the highest stable depth from below |

No ceiling moves before the two 16384 arms land.

## Results

Pending.
