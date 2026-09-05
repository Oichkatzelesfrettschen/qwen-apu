# The registered 2B target-closure run, executed twice on 2026-09-05

`../target-closure-preregistration.md` is the registration; this directory is
its result. The run executed as written on the appliance under the named
operating point, once and then once more because the first paired verdict
came back incomplete. Both runs are retained whole. The two verdicts are read
apart, as the registration requires.

| run | candidate arms, tok/s | target closure (lower 95% endpoint above 10) | paired promotion (+5%, one-sided) |
| --- | --- | --- | --- |
| `run1/` (0600Z) | 10.062, 10.170, 10.093, 10.207; mean 10.133, sd 0.067 | **closed**: interval [10.026, 10.240] | incomplete: control slot 1 refused by the sidecar, 3 of 4 pairs survive at +5.71, +4.69, +6.52% |
| `run2/` (0615Z) | 9.811, 10.110, 10.211, 10.308; mean 10.110, sd 0.215 | **unresolved**: interval [9.768, 10.452] spans 10 | incomplete: control slot 5 refused by the sidecar, 3 of 4 pairs survive at +2.57, +5.18, +7.88% |

Every candidate arm in both runs completed with `clock_invariant=held` at
1100/933, so the closure interval in each run reads over all four registered
candidate arms. The registration names no rule that combines two runs, and
neither run is rerun in this window: the first closed and the second left
the interval spanning 10, so the target-closure row of `../README.md` moves
from provisional to **closed once and unresolved on the repeat**, which is a
central value near 10.1 tok/s with a bound that one run supports and the
next does not.

## What refused the paired verdict, twice

`run-served-binary-ab.sh` ends a campaign on any arm failure and reports
`comparable_pairs=0`. In both runs one control arm was refused by
`validate-clock-sidecar.py` on `dpm_marker_cadence`: one 200 ms DPM marker
interval of 306.8 ms (run 1, slot 1) and 309.95 ms (run 2, slot 5) against
the 300 ms bound, with `window_lost_fraction` 0.0001 and the clock invariant
held on every sample of both arms. The rate of each refused arm was measured
(9.658 and 9.611 tok/s) and sits inside the other controls' 9.555 to 9.641.
The three surviving pairs of each run carry paired deltas whose means, +5.64%
and +5.21%, sit above the 5% bound with one pair of six below it, which is
what a four-pair interval would have been read over; the summary's own
`detail` column retains them and no verdict is read from them here, since the
registration admits a paired verdict from four pairs and the harness's own
rule. The cadence bound was the instrument's, and it was re-registered
after these runs (`evidence/raven2-vulkan-kernel-census/README.md`):
`telemetry-broker.c` refreshes the DPM bundle every tenth sampler tick and
re-bases a missed deadline, so a marker gap is the sum of ten row gaps and
one wide gap is the sampler held off the CPU, host time the row-gap and
lost-fraction rules already price; both refused gaps straddle the request
window's start and hold row gaps of 49 to 88 ms with the coverage rules
passing. The re-registered rule reads the median marker gap, and every arm
of both runs reads a median of 200.00 ms.

## The paired verdict, re-read under the re-registered rule

`remote/reread-served-ab-sidecar.sh` re-validated every retained
`clock-sidecar.tsv` of both runs with the arguments each `inputs.tsv` bound
and re-summarized the ledgers; `run1/reread/` and `run2/reread/` retain the
verdicts, the re-read `arms.tsv`, the summary, and the provenance naming both
validator digests. The one refused control arm of each run completes under
the re-read (`arm_moved` in `reread.tsv`), the rate and clock state it
measured once are unchanged, and the paired verdict is then read from four
pairs in both runs:

| run | paired deltas | mean | nominal 95% interval | verdict at +5% one-sided |
| --- | --- | ---: | --- | --- |
| `run1/reread/` | +4.18, +5.71, +4.69, +6.52% | +5.28% | [+3.61, +6.94] | **unresolved** |
| `run2/reread/` | +2.57, +5.18, +6.24, +7.88% | +5.47% | [+1.92, +9.01] | **unresolved** |

Both means sit above the bound and neither lower endpoint clears it, which is
the same reading the four-arm interval gives the absolute target: the
composed candidate's gain over the nine-member production build on the 2B is
near 5% and two whole runs at four replicates cannot separate it from that
bound. Promotion requires the lower endpoint above +5%, so no serving default
moves. What the re-read replaces is the incomplete verdict, not the
registration's arithmetic: the same four-pair paired rule ran over the
retained arms, the measurement head and the analysis head being recorded
apart.

## The identities

The registration binds the control to the epoch's production server and the
fixed-64 scoreboard receipt's server row. Promoting the router patch
(`evidence/router-cancelled-load/`) moved the production series from eight
members (`58e651d7...`) to nine (`a91a215a...`), and the harness refuses two
binaries whose manifests name different series, so the control is the
production build of the nine-member ledger from the runtime root's tree,
`70aa78bc...`, the same bytes bundle `main-7f8f2ed-r1` serves. Its manifest
(`control-artifact-manifest.tsv`) names `candidate_series -` and the
nine-member digest. The denominator was re-measured on that server under
`denominator/`: twelve arms, two forward and two reverse blocks, the 2B at
9.596, 9.514, 9.611, 9.463 tok/s and the receipt `identity-check.tsv`
(`ad69c27c...`) is what `run1/inputs.tsv` and `run2/inputs.tsv` bind as
`production_receipt_sha256`.

The candidate is a serving build of the same tree carrying the candidate
stage from `llama-vulkan-q4k-activation-group-sums.patch` through
`llama-vulkan-q4k-variant-select.patch` (`candidate-artifact-manifest.tsv`:
`serving_eligible yes`, `checkpoint_semantics natural-boundary-v1`,
`q4k_variants` naming all nine keys), `83684f3c...`. Both roles ran unkeyed,
because the harness admits an experiment key on both roles or neither, so the
candidate arm is the build's own default, the composed formulation at the
row count the `AMD_GCN` branch selects, which the registration names
`e4-scale-licm/4`; the executed module is the one the manifest's default
embeds.

The operating point: `manual` clock policy at `pp_dpm_sclk` level 2 and
`pp_dpm_mclk` level 2 with readbacks 1100 and 933 MHz
(`run1/inputs.tsv`), the sidecar on the telemetry broker at 20 ms on both
cores at nice 19, the server at nice 19, package limits at the platform
default 15/25/20 W (`power-envelope-status.txt`), CPU boost 1
(`cpufreq-boost.txt`), the standing guest running and KSM as found
(`compute-state-status.txt`), the model `4aa0fb13...` at the registry tuple.

## What this licenses

A closed run states that the composed candidate decodes the 2B distill's
fixed-64 request above 10 tok/s on this machine under the manual 1100/933
cell in that run; the repeat's interval spanning 10 states that the bound is
not stable run to run at four arms. Neither run moves the promotion row, and
neither establishes any other context depth or a new serving default.
