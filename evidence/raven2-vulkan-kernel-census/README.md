# Raven2 Vulkan pipeline census: design and registered falsifiers

This directory is the home of Stage A of the execution ladder in
`evidence/vulkan-tensor-paths/gfx902-execution-ladder.md`. It states the
instrument, the execution states, the identity a measurement is keyed by,
the accounting rules, and the falsifiers ahead of any run, so a later number
is read against a claim registered before the number existed. Subdirectories
named by UTC stamp retain runs; this file carries no result.

## The denominator the census attributes

The sealed fixed-64 served scoreboard in
`evidence/fixed64-served-campaign/20260901T2011Z/` is the token time the
census divides. A census arm reproduces that arm's tuple exactly: model
bytes, context allocation, batch and ubatch, cache types, Flash Attention
state, checkpoint count and minimum step, the low-async submission profile,
a 64-token greedy request on one slot, strict Vulkan0 placement, nice 19,
and idle I/O. Sixty-three timed decode steps follow the first predicted
token, which comes from the prompt logits and is absent from
`predicted_ms`.

| Class | governing rate | target | token time | time to remove |
| --- | ---: | ---: | ---: | ---: |
| 0.8B, slowest retained arm | 16.233 | 20 | 61.60 ms | 18.84% |
| 0.8B, clean-state minimum | 18.790 | 20 | 53.22 ms | 6.05% |
| 2B, slowest arm | 9.831 | 10 | 101.72 ms | 1.69% |
| 4B, slowest arm | 3.331 | 5.25 | 300.18 ms | 36.55% |

The 2B's promotion rule is stricter than its target gap: a candidate must
gain at least 5% in every paired comparison, which is at least 4.762% of
token time removed. The 4B cannot be carried by one family below a 2x local
speedup: a family at 2x must own 73.1% of the token, at 3x 54.8%, at 4x
48.7%. The census exists to state which families own what, and it states
ownership only where the instrument can distinguish ownership from
residency.

## Five execution states

```text
P            the promoted production binary, the scoreboard's own bytes,
             with the clock sidecar sampling beside it
P-nosidecar  the same binary with the sidecar off
I0           the census binary, instrumentation compiled in, collection off
I1           the same census binary, collection on
S            the same census binary under the diagnostic profile with the
             pinned vk_perf_logger armed: the serialized identity control
```

Every state, S included, runs through `measure-served-decode.sh`, so the
workload lease, the process identity capture against the approved
executable, the kernel-hazard watch, the graphics-latency record, the
telemetry record, and the teardown proof hold for each arm alike.

Three controls separate three effects, and `summarize-census-controls.py`
assigns a bound to those three quadruples alone:

```text
P-nosidecar P P P-nosidecar   sidecar bound   0.65%   what the sampler costs
P I0 I0 P                     compile bound   0.65%   what compiling the instrument did
I0 I1 I1 I0                   collect bound   2%      what collection costs under the sampler
```

The sidecar runs during P, I0, and I1, so `I0 I1 I1 I0` measures collection
under a common sampler load and the sampler's own cost is a separate
control ahead of it. Each quadruple yields two paired deltas, `b/a - 1`
and `c/d - 1`, whose second reverses the first's queue position, and a
control repeats its own quadruple until it holds `QWEN_CENSUS_REPLICATES`
paired deltas. The verdict is over the whole set: the mean paired delta,
the sample standard deviation, and a nominal 95% interval from Student's t
at n-1 degrees of freedom, with the critical values for n of 2 through 8
written into `summarize-census-controls.py` rather than imported. Any other
quadruple matching the `a b c d` pattern keeps its own row and is printed
`unclassified` with no bound, since `P I1 I1 P` conflates compile and
collection effects and `I1 S S I1` compares two submission shapes; S stays
outside the pair parser. The 2B calibrates because its four scoreboard
arms span 0.65%; that span is the registered compile bound, a descriptive
figure adopted as a tripwire rather than a confidence interval.

The interval rather than a per-replicate comparison decides the verdict
because two replicates disagreeing in sign report the machine's own
arm-to-arm scatter. The calibration of 20260902T0819Z completed all
fourteen arms with every sidecar accepted and read the sidecar control at
-1.20% and +0.96% and the compile control at +2.40% and -1.00%: opposite
signs at magnitudes this tree already documents as about 4% of uncontrolled
spread on a repeated depth-0 rate. A 0.65% bound tested against each
replicate separately called both of those refutations, which measured queue
position, and `evidence/research-claim-methodology.md` already names the
state a direction takes while its interval crosses its threshold.

A control is therefore `accepted` where the whole interval sits inside
`[-bound, +bound]`, `refuted` where the whole interval sits outside the
bound on one side -- a cost where every point is below `-bound`, a speedup
where every point is above `+bound`, and the `detail` column names which --
and `unresolved` where the interval spans the bound. `summary.tsv` carries
one row per registered control with `replicates`, `mean_delta`, `sd_delta`,
`ci_low`, `ci_high`, and `deltas` beside the first quadruple's own
`first_*` and `second_*` columns, so a reader compares one replicate
against the set that judged it.

The interval is taken over the pairs whose two arms met one execution
state, and two appliance calibrations in a row reproduced one regime change
that decides what "one state" means. d490a39 and b7a3612 each read 1100 MHz
over the first nine slots -- about five minutes of arms -- and then settled
between 762 and 857 MHz for the rest of the campaign, with die temperature
falling and decode falling from about 9.5 to about 7.2 tok/s with it. The
served appliance lives in the sustained regime, so that regime is the one a
calibration measures.

Under it the selected clock hovers across fine-grained values -- 775, 787,
800, 812, 825, 837, 857 -- rather than resting on a table step, so an exact
comparison read all four collect pairs of 20260902T1302Z as governor steps
-- `825/837 787/762 775/800 812/825` -- although all eight arms ran in one
regime. Two modes are therefore one state where they lie within
`QWEN_CENSUS_SCLK_BAND` of each other, relative to the larger of the two.
The default 0.06 admits the widest of those pairs at 3.18% and keeps the
boost regime out: 1100 against 800 sits 27.27% apart and stays
`state-changed`. `validate-clock-sidecar.py` states each arm's modal
selected graphics clock over its request window on a `clock_state=` line
beside its verdict lines, `arms.tsv` carries it as `sclk_mode_mhz` with
`sclk_share`, and `summary.tsv` lists each pair's `inner/outer` modes in
`sclk_modes` and takes `--sclk-band` for the comparison. A `-` is an
unknown state -- the sampler runs off on `P-nosidecar`, and a ledger
predating the columns carries it on every row -- so it takes whatever state
its partner held and the retained campaigns replay unchanged. A control
left with fewer than two comparable pairs reads `state-changed`, which
`terminal-state.tsv` counts as `control_state_changed` and which ends the
campaign `unresolved` with exit 4 the way an interval spanning its bound
does. The broker reads `/proc/loadavg` and
`/sys/kernel/mm/ksm/pages_sharing` on its own 1 s channel and emits them as
`# host` lines, so a clock step is read beside the host load at that
instant.

The band decides which pairs a control keeps and settles nothing about
which regime the campaign ran in, so the regime is a precondition the
campaign meets before its first named arm. Warmup arms `W` run the
production server under the sampler at slots 0a through 0p, ahead of slot
1, until two consecutive warmups hold modes inside the band and each holds
a modal share inside `[QWEN_CENSUS_REGIME_MIN_SHARE,
QWEN_CENSUS_REGIME_MAX_SHARE]`, default 0.05 and 0.30. Their mean joins
`inputs.tsv` as `regime_sclk_mhz` beside `regime_arms` and the run prints
`census_regime=reached sclk_mhz=.. arms=..`.
`QWEN_CENSUS_REGIME_MAX_ARMS`, default 16, caps the spend; a cap reached
prints `census_regime=unreached`, records `regime_sclk_mhz` as `-`, and
runs the named arms against their own pair comparability alone. Every named
arm records `regime_delta`, its distance from that regime on the same
larger-of-two denominator the band uses, and `summary.tsv` counts the arms
of each control that exceed the band as `off_regime_arms`: a pair of arms
that agree with each other while both sit off the regime is comparable and
still reports a campaign that drifted, which the pair comparison cannot
say. A calibration and an attribution each run the precondition; a canary
judges chain structure at eight tokens and asserts no rate, so it runs
none. The measured value stays out of `acquisition-contract.tsv` -- an
attribution settles its own regime and would refuse against the
calibration's -- while the band and both share bounds sit in it beside the
bounds they act with, since each decides a verdict.

The modal share is what sets those two bounds, and
`20260902T1417Z/arms.tsv` is the measurement: it carries the `sclk_share`
column `20260902T1302Z` lacks, and it separates the regimes by share as
sharply as by clock. The boost arms at slots 2 through 7 hold 0.5518 to
0.6803, slot 9 reads 0.2503 across the fall, and every sustained arm from
slot 10 through 24 holds 0.1206 to 0.1615. Boost pins one clock and the
sustained regime hovers across seven, so a high share is the pinned
signature and hovering is the served one. Two boost warmups agree at
1100 MHz inside any band and would settle the precondition on its second
arm, so the 0.30 ceiling rather than the band is what declines them; the
0.05 floor is a sanity bound under a window whose samples name no mode at
all. Both campaign tests run that pair of shapes: two warmups at 1100 MHz
with shares of 0.60 and 0.66 read `census_regime=unreached`, the same
agreement at 0.13 reads `census_regime=reached sclk_mhz=806.0 arms=2`, and
a census run that raises the ceiling to 0.7 settles the boost pair the
default refused, which is what makes the ceiling the deciding rule rather
than the comparison.

One falsifier stands against the ceiling. A sustained regime whose modal
share rises above 0.30 on this device leaves the precondition unreached at
the cap, and the campaign reports that as `census_regime=unreached` with
`regime_sclk_mhz` `-` rather than serving a regime it never settled. The
share range rests on one campaign, so a second reproduction is what would
move the ceiling; the cap is what bounds the cost of being wrong about it.

The precondition costs the campaign its own warmup arms, and the cap
follows the regime it waits out: boost held for about nine arms in both
retained calibrations, so a cap short of that would report `unreached` on
the machine's ordinary behavior. Sixteen admits the fall and the pair that
has to follow it. A calibration at two replicates ran fourteen arms and now
runs between fifteen and twenty-nine, and one at four replicates between
twenty-seven and forty-one. A warmup costs about 23 s with the converged
cooldown, so a precondition that settles in two arms adds about 46 s and
one that spends the cap about 368 s. `predicted_campaign_duration_s` takes
the cap against the per-arm ceiling of 19 s plus the quiescence deadline --
49 s at the default 30 s cooldown, giving 1421 s at two replicates and 2009
at four -- since a prediction that assumed the floor would understate every
run that pays more.

`QWEN_CENSUS_REPLICATES` sets the count, defaults to 4, and is even and
between 2 and 8, since every two replicates are one mirrored quadruple and
the t table covers those degrees of freedom. Two replicates generate the
thirteen arms the retained runs recorded, which is what keeps a replay of
their summaries valid, and they resolve nothing at these bounds: one degree
of freedom carries a critical value of 12.706, and the half-width of a
two-value interval is 6.353 times the gap between them, so the interval
spans a 0.65% bound unless the two deltas agree to about 0.1%. Four replicates give a
half-width of 1.591 standard deviations, so a 0.65% bound accepts only
where the four agree to about 0.4%, which this tree's documented scatter
does not promise. An unresolved campaign at four replicates is a reportable
result stated ahead of the run rather than a defect of it.

The campaign has four terminal states and the exit status follows them: a
failed arm, an incomplete control, or an unclassified quadruple ends it
`failed` with exit 1, a refuted registered control ends it `refuted` with
exit 3 even where every arm completed, an unresolved control with no
refutation ends it `unresolved` with exit 4, and `accepted` alone exits 0.
An unresolved control neither accepts nor refutes, so its branch precedes
the accepted-count test that an unresolved control would otherwise leave
short. `terminal-state.tsv` gains `control_unresolved` beside the counts it
already carried. `QWEN_CENSUS_MODE` names the contract the counts are held
to. A `calibration`, the default, runs exactly the arm list its replicate
count generates and accepts on exactly three accepted controls, so a
reordered arm list or a fourth quadruple fails the run rather than passing
beside the three. An
`attribution` runs any registered arm list, `I1` alone included, and
requires `QWEN_CENSUS_CALIBRATION_RECEIPT` to name the output directory of
an accepted calibration whose `inputs.tsv` bound the same production and
instrumented digests, since the bounds a calibration accepted belong to
those two binaries. `terminal-state.tsv` carries the state, the mode, the
five counts, and the required count, so a chain reading the exit status
reads the calibration verdict rather than the request count.

The replicate count, the generated arm list, and the predicted wall clock
are campaign shape rather than acquisition settings, so they reach
`inputs.tsv` and the `QWEN_CENSUS_PRINT_CONTRACT` output while
`acquisition-contract.tsv` keeps the digest an attribution is held to. An
attribution runs `I1` alone against its calibration's own digest, and a
replicate count inside that file would refuse every attribution; a brick's
input closure already hashes its arm list, so a prior calibration at
another replicate count offers nothing to reuse. The prediction bounds the
run from the per-arm ceiling the scoreboard measured -- about 9 seconds to
readiness, 9 seconds of request, 1 second of teardown -- plus the
`QWEN_CENSUS_COOLDOWN_S` quiescence deadline, over every arm the generated
list names plus the precondition's cap of warmups: 1421 seconds at two
replicates and 2009 at four under the default 30-second cooldown, against
686 and 1274 before the precondition. It is a ceiling on the whole list, so
a run whose precondition settles in two arms, or one reusing bricks,
executes fewer arms and costs less. The print also states
the brick partition, one `census_brick` row per brick carrying its control
name, its first slot, and its slot count, from the same functions the run
indexes with: C3 lands at slot 13 at two replicates and at 25 at four.

An attribution is bound to the whole calibration rather than to its two
digests. The runner writes `calibration-contract.tsv` in fixed row order:
the model tuple and artifact digest, both server digests, the base-build
identity digest, the request shape, the low-async profile, nice and I/O
class, the sidecar period, tolerance, cost limit, maximum gap, CPU,
niceness, DRM device, and allowed unavailable sensor, the three bounds, the
overlap threshold, the latency probe digest, and the synced runtime tree's
git head and two payload digests from the manifest the sync writes beside
`remote/`, since the arms launch through that tree and a resync between
calibration and attribution would otherwise pass both launches through
trees that each satisfy their own check. Each arm's server is hashed after
the arm and compared with the digest the preflight bound to its role, so a
binary replaced mid-campaign fails the arm it served. Its SHA-256 is recorded as
`calibration_contract_sha256` in `inputs.tsv`, an attribution computes its
own contract the same way and requires the receipt's digest to equal it,
and a changed sidecar period or bound refuses by that one comparison
rather than by a list of field checks that a new knob would fall outside.
`QWEN_CENSUS_PRINT_CONTRACT=1` prints the contract an invocation would run
under and ends ahead of the host check. A terminating signal ends the
served runner and the sidecar together: the served runner runs as a job
under `wait`, which a trap interrupts, and `cleanup_children` on EXIT,
TERM, INT, and HUP signals and waits for both, so a runner ended mid-arm
leaves no sampler writing into its arm directory.

The expensive measurement and the reader that interprets it are two heads.
A run is bound to the head that acquired it, and a later reader fix may
reinterpret the retained raw records where it changes no measured byte,
the new reader is gated, and the run's README records both the
acquisition SHA and the analysis SHA.

The runner states those two heads as two files. `acquisition-contract.tsv`
carries every row the calibration contract already carried -- the model
tuple and artifact digest, both server digests, the base-build identity, the
request shape, the profile pair, nice and I/O class, the sidecar geometry,
the three bounds, the overlap threshold, the probe digest, and the runtime
tree's head and payload digests -- and each of them changes an observed
byte, so the file gains nothing in the split. `analysis-contract.tsv`
carries the SHA-256 of the four readers that interpret the retained records,
in the fixed order `summarize-kernel-census.py`,
`validate-clock-sidecar.py`, `summarize-perf-logger-slice.py`,
`summarize-census-controls.py`. `inputs.tsv` records both as
`acquisition_contract_sha256` and `analysis_contract_sha256`, and
`calibration_contract_sha256` remains an alias of the acquisition digest for
one release so a receipt written before the split still answers the
attribution comparison. An attribution requires acquisition equality alone.
A receipt read by another reader generation is recorded as
`receipt_analysis_contract_sha256` beside `analysis_contract_match` over
`yes`, `no`, and `unrecorded`, and the run proceeds, since a reader fix
reinterprets bytes the calibration already acquired.

The warmup arms carry a second job beside the regime. The first server
after a build loads cold and the cold arm would sit inside control pair 1:
chain seven measured slot 1 at 6.783 tok/s against slot 4 at 9.561 and the
three P arms at 9.428, 9.422, and 9.472, and chain six read the same opener
at 8.166, so the sidecar control would take its first outer rate from a
cold load and compare it against a warm one. W absorbs that load whether
the precondition settles in two arms or eight. Each executed warmup takes
its own `arms.tsv` row at its lettered slot, its own `wall-clock.tsv` rows,
and its own sidecar verdict, and a verdict the validator refuses costs the
precondition that arm's reading rather than failing the campaign -- the cap
is what bounds a sampler that refuses every warmup. A warmup's rate enters
no pair and no census record: `summarize-census-controls.py` drops W beside
S before the quadruple walk, and `acquisition-contract.tsv` states
`warmup_arm`, `warmup_sampler`, `warmup_precondition`,
`warmup_excluded_from_pairs`, and `warmup_excluded_from_census` rather than
leaving a reader to infer any of it from the slot lettering. The lettering
is what keeps the registered arms at slots 1 upward, so every brick,
receipt, and quadruple is stated in the numbers it always was;
`QWEN_CENSUS_ARMS` still names exactly the generated list; and a
calibration whose four bricks all reuse skips the warmups outright, since a
warmup warms the arms that follow it, there are none, and a regime binds
nothing the run measures.

Coverage rather than the widest gap is what a sidecar record owes an arm,
and the gap criterion is refuted as a coverage measure at nice 19 on both
cores. Chain seven failed calibration with ten arm failures, every one of
them `sidecar=refused` on `gaps` alone. With the sampler confined to both
cores at nice 19 and the server's own threads at nice 19, CFS shares the two
cores fairly and holds the sampler off for scheduler slices: 3 to 5 gaps
over 20 ms per window, a 60 to 119 ms maximum, and a `window_lost_fraction`
of 0.0122 to 0.0147, with the S arm at 3 gaps and 0.0027. A slow sysfs read
does not order them -- the preceding sample cost 0.2 to 1.0 ms at almost
every over-bound gap, and two of twenty-four followed a 29 to 37 ms
`pp_dpm` read. Acceptance is therefore
`window_lost_fraction <= sidecar_max_lost_fraction`, default 0.03, measured
as the window-clipped duration of every gap wider than two sampling periods,
which is a gap that missed at least one scheduled sample. That default is a
coverage criterion for a clock-state record rather than a safety ceiling: at
the 20 ms period 0.03 of a window is under 15 samples of 400, and the clock
invariant counts every sample the record does hold. Arm 06-P of the
20260902T2011Z calibration is where 0.02 cost a record that answered its
question -- both clocks held and the window lost 0.0214 to a nice-19 sampler
sharing two cores with the server's own nice-19 threads, which is the CFS
share this bound prices rather than a sampler defect.
`sidecar_max_gap_ns` survives as a stall bound alone, default ten periods or
100 ms, and refuses a sampler that stopped rather than one that was
descheduled; the `gaps` line keeps reporting its distribution, maximum, and
counts as observations. Both bounds are contract rows, so a calibration and
its attributions are held to the same pair.
`remote/test-census-replay-corpus.py` reads the change against retained
device bytes: the corpus `02-P` record, whose widest gap is 42.0 ms and
whose lost fraction is 0.0047, now reads accepted where it read
`clock_sidecar=refused failures=gaps`, and the same record still refuses
under a 0.004 coverage bound, so the verdict follows the fraction rather
than the maximum.

The sidecar's own cost is a separate open question this change leaves open.
Chain seven measured P-nosidecar at 9.561 against P at 9.428, 9.422, and
9.472, about 1.0 to 1.4%, above the registered 0.0065 sidecar bound. The
bound stands and the next chain measures the cost under the C broker; a
refuted control now carries the direction and the interval that cleared the
bound in its own `detail` column, so the row states what refuted it and by
how much.

The registered arms are four control bricks, and a brick rather than a
campaign is the unit a verdict and a reuse belong to. C0 is the sidecar
control, C1 the compile control, C2 the collect control, and C3 the
identity arm. Each control brick holds twice the replicate count in slots,
so at two replicates C0 takes slots 1 through 4, C1 5 through 8, C2 9
through 12, and C3 slot 13, and at four replicates each control brick takes
eight slots and C3 lands at 25. Each writes `bricks/CN.receipt.tsv`
carrying its id and control name, its slots and arms, its verdict --
`accepted`, `refuted`, `unresolved`, or `incomplete` for C0 through C2 from
the summary's own column, `completed` or `failed` for C3 from the arm's
state -- its arm rates, its input-closure digest, and the
SHA-256 of every file its arm directories retained. The input closure is
what the brick's arms consumed and what a later run can state before it
launches: the acquisition contract digest, the brick id, its arm list, and,
for the two bricks that execute the census build, that binary's digest. C3
also retains the diagnostic profile's env set, which exists only once the
arm has run, so its receipt records `observed_env_set_sha256` from
`arms/13-S/server-effective-env.tsv` beside the closure rather than inside
it. `calibration-root.tsv` hashes the acquisition digest together with the
four receipt digests, and `terminal-state.tsv` carries the result as
`calibration_root_sha256`, so one value names the whole calibration.

`QWEN_CENSUS_REUSE_BRICKS` names a prior calibration output directory and
preserves every expensive state whose inputs are unchanged. The directory is
read whole: its `inputs.tsv` must state this run's acquisition digest, since
a brick measured under another contract measures another campaign, and its
`arms.tsv` must rejoin each receipt slot by slot at the rates the receipt
records. A brick whose input-closure digest equals this run's is reused --
its arms are skipped, its receipt is copied into this run's `bricks/`
carrying `reused_from` and the prior campaign's own terminal state as
`reused_from_census`, and its arms are echoed into `arms.tsv` at their own
slots with status `reused` and their measured rates. A brick whose arms
completed inside a refuted calibration is a legitimate reuse target -- the
arms ran, the closure holds, the rates stand -- so the provenance is
recorded on the receipt the root names rather than gating the reuse. The
echoed status is written into the column the prior ledger's header names,
since the pair parser reads that field by name and a positional rewrite
would disagree with it.
`summarize-census-controls.py` reads `reused` as a completed arm, and it
pairs by position rather than by slot number, so the echo at the original
slot is what keeps the three quadruples where the parser finds them. A
calibration whose four bricks all reuse launches no server and still writes
a root; a partial reuse spends device time on the changed cell alone.

`QWEN_CENSUS_MODE=canary` runs `P I0 I1 S` once each at
`QWEN_BENCH_GENERATE=8` and judges the chain's structure rather than any
rate. Eight generated tokens leave seven decode graphs, which is the
cardinality `summarize-kernel-census.py` is asked for at
`--expected-decode-graphs 7` and `summarize-perf-logger-slice.py` at
`--expected-decode-blocks 7`, so both readers run their real check on a
short reply. `canary-structure.tsv` carries one row per arm per check over
the arm's own completion -- which carries the launch, the server identity
comparison, the sidecar validator, and the two parsers -- the served
runner's retained teardown record, and the absence of either child after the
runner's waits. `terminal-state.tsv` reads `census=canary_accepted` or
`census=canary_failed` at exit 0 or 1, assigns no control verdict, and never
reports a refutation. The canary is what the chain runs ahead of a
calibration, since four short arms price a broken link at a fraction of a
whole calibration.

`wall-clock.tsv` prices the campaign phase by phase on CLOCK_REALTIME, one
row per phase per arm as `slot arm phase begin_ns end_ns note` plus one
`campaign` row, stamped with `date +%s%N`, the GNU extension the appliance's
coreutils supplies. The `launch` phase runs from the runner's own stamp to
the request window's begin, since the launch chain writes `launch.txt`
without stamping the instant the server answered `/health`; `request` is the
served runner's own window, `teardown` runs from that window's end to the
served runner's exit, `analysis` covers the summarizers, and `cooldown`
covers the boundary between arms. The request endpoints reach the ledger
through one paired reading of CLOCK_REALTIME and CLOCK_MONOTONIC taken on
the arm that produced the window, rather than once for the campaign, so a
clock step mid-campaign moves one arm's translation instead of smearing
every later row; an endpoint the run never observed reads `-` rather than
borrowing a neighbouring stamp. That boundary is convergence rather than a
constant: `await-quiescence.sh` polls the submission, clock, thermal,
reclaim, and lease predicates and reports the instant they have all held
together, `QWEN_CENSUS_COOLDOWN_S` becomes its deadline, and the cooldown
row's note carries `quiescence=reached|timeout|unreported` with the poller's
own `elapsed_ms`. A deadline reached without convergence is counted in
`cooldown_timeouts` rather than charged to the arm that already completed,
because the state it left belongs to the arm that follows.

## What P stands for and how it is bound

P is bound to the scoreboard it stands for rather than to a path. Its
artifact manifest must name `llama-server` in exactly one `executable` row
and that row must describe this file by byte count and digest, the rule
the bundle verifier and the exec guard apply, so a manifest carrying one
matching row beside a conflicting one is ambiguous here as it is there.
The manifest must name no `instrumentation` row, declare `serving_eligible`
yes or carry no such row, and carry one `checkpoint_semantics` row reading
`natural-boundary-v1` wherever the registry row runs a positive checkpoint
count. `QWEN_CENSUS_PRODUCTION_RECEIPT` names the `identity-check.tsv` of
the fixed-64 sweep, whose one `server` row must carry P's digest and byte
count as both expected and observed, accepted. The denominator is the
tuple beside the binary, so the receipt binds it too: the
`models-resolved.tsv` in the receipt's directory must resolve the model to
the context, batch, ubatch, cache triple, Flash Attention state, checkpoint
count and minimum step, and publisher digest and byte count that the
registry, the checkpoint ledger, and the artifact ledger resolve it to now,
and the `campaign-inputs.tsv` there must state the low-async profile, 64
generated tokens, the fixed sampling, server nice 19, Vulkan placement,
speculation off, and router off, which are the settings every arm runs
under. A registry edit between the scoreboard and the census therefore
refuses the run rather than changing the experiment behind a byte-identical
P. `inputs.tsv` records the server digest and bytes, the manifest digest,
the checkpoint semantics, the `checkpoint_patch_series_sha256`, the receipt
digest, the digests of both receipt-directory files, the scoreboard's own
registry and ledger digests beside the current registry digest, and the
mode with its calibration receipt, so an arbitrary executable path cannot
define production by name.

P and I differ by the census instrumentation alone, and the runner proves
it rather than naming it. Each manifest yields a base-build identity from
the rows both carry: the llama.cpp commit, the production patch series
digest, the checkpoint patch and source digests, the compiler flags, and
the CMake flags with `-DGGML_VULKAN_PIPELINE_CENSUS=ON` removed; the
compiler identity is read from each executable's own `.comment` section,
since the manifest records flags rather than the toolchain. The two
identities must be equal, I's CMake delta against P must be exactly that
one flag, and I's manifest must name `candidate_series
llama-vulkan-pipeline-census.patch`, so `P I0 I0 P` measures compiled
instrumentation rather than a different commit, compiler, patch prefix, or
configuration. `inputs.tsv` records both identity digests and the delta.
The shader compiler identity is recorded as `unrecorded`, since the
manifest at the promoted build carries no such row; a manifest row for it
is the change that would bind it. Manifest declaration values are compared
inside `awk` over the whole tab-delimited field, so `serving_eligible
yes extra` is the literal it is and refuses rather than word-splitting to
`yes`.

The census binary is a diagnostic artifact and never a serving one. Its
artifact manifest carries `instrumentation	pipeline-census-v3`,
`build_role	diagnostic`, and `serving_eligible	no`, each exactly once.
`build-deployment-bundle.sh` and `verify-deployment-bundle.sh` apply one
grammar: zero eligibility rows beside zero instrumentation rows is the
legacy shape and assembles; one eligibility row must read exactly `yes`,
so an empty value is refused by name; more than one row of either kind is
refused on cardinality; and any `instrumentation` row refuses the manifest
whatever the eligibility spelling, so deleting the `no` row from a
diagnostic manifest leaves nothing a bundle admits. The contract stops
there: an explicit `QWEN_LLAMA_SERVER` launch is the bundle layer's
recovery mode and reads no bundle, so it is also the one path a diagnostic
binary reaches the device through, and the census runner is its caller.

`QWEN_CENSUS_ENGINE_CLOCK_POLICY` retires that taxonomy by removing what
it classifies. The kernel's `power_dpm_force_performance_level` takes
`high` for the highest power state, `profile_peak` for peak clocks with
gating disabled, and `manual` for the level indices written to
`pp_dpm_sclk` and `pp_dpm_mclk`, and `auto` is the governor everything
above measures: the clock read 1100 MHz for nine arms, then 750 to 857,
then 658 after a CPU build, and decode followed it linearly, a 97 ms GPU
bracket scaled by 1100/658 plus 3.4 ms of host time predicting 6.04 tok/s
against 5.7 to 6.1 measured. E4's whole-token effect is about 4% where that
nuisance is 67%, so a campaign that can pin the clock pins it.

Which level to pin is a measurement rather than a choice, and the first
answer was wrong. Under `high` and `profile_peak` the starred graphics step
and the hwmon `freq1_input` frequency both read exactly 1100 MHz for whole
arms and decode still fell, to 6.3 to 7.0 tok/s against `auto`'s 6.8 to
8.2, because both levels left the starred `pp_dpm_mclk` fabric state at
400 MHz where the governor selected 933 to 1067. The delivered graphics
clock is not the operating point; the fabric clock decides more of decode
than it does. `manual` with the graphics level selected decoded 9.58, 8.91,
and 9.23 tok/s across three arms against interleaved `auto` arms at 8.22
and 7.94, so `manual` is the campaign policy and `high` and `profile_peak`
remain admitted names that measure the fabric fall. The fabric selection
itself is inert: the starred `pp_dpm_mclk` level read 933 MHz whether
level 3 at 1067 or level 2 at 933 was written, and every arm ran there, so
the write is recorded with its readback and 933 is the floor the invariant
holds the fabric to.

Both campaigns therefore require `sudo -n true` and name `sudo -v` where it
fails, snapshot the level and its two selections, write the policy through
`sudo -n tee`, require the readback to equal it, and under `manual` write
`QWEN_CENSUS_SCLK_LEVEL` -- the highest level `pp_dpm_sclk` lists where the
caller names none, level 2 at 1100 MHz on this device -- requiring the
starred level to be the one written, and `QWEN_CENSUS_MCLK_LEVEL` where one
is named, recording its readback. The snapshot is restored under the same
cleanup trap the sampler and served child unwind through, on EXIT and on
TERM, INT, or HUP, a `manual` snapshot restoring its own level selections
after the level, and the restore prints the level it read back as
`dpm_restore=`. The regime precondition becomes exactly one priming warmup,
sampled and outside every pair, and the run prints `census_regime=retired
policy=.. required_sclk_mhz=.. mclk_floor_mhz=.. arms=1`.

The invariant is over delivered clocks rather than the DPM state, which is
what the `high` arms make necessary. `telemetry-broker.c` reads hwmon
`freq1_input` on the same 100 ms channel as the DPM steps and writes it as
`sclk_actual_mhz`, an eighth column after `sample_cost_ns`;
`validate-clock-sidecar.py` accepts the seven-column and eight-column
records alike, so the replay corpus reads unchanged, and
`--required-sclk-mhz N` counts over `sclk_actual_mhz` where the record
carries it and over the selected step otherwise while `--required-mclk-mhz
M` counts over `pp_dpm_mclk_surface_mhz` as a floor. The line reads
`clock_invariant=held|violated samples_at_required=..
samples_below_required=.. below_required_fraction=..` with the source and
the fabric counts beside it, and `held` requires both. An arm whose
invariant is violated fails with reason `clock_invariant`, `arms.tsv`
carries `clock_invariant` and `below_required_fraction`, and
`summarize-census-controls.py` drops that arm's pair as `clock-violated`
the way it drops a governor step as `state-changed`. The policy, the two
level selections, the required graphics step, the fabric floor, the
admitted `clock_below_required_fraction` of 0, and the admitted
`clock_below_mclk_floor_fraction` of 0.01 enter `inputs.tsv` on every run
and `acquisition-contract.tsv` only where a policy is forced, since a
governor run applied no control and a row stating that would be a default
rather than a setting.

The two clocks carry two admitted shares because they answer a forced
policy differently. A pinned graphics step reports one value on every
sample, so its share stays 0 and a sample below it is the governor moving
under a policy that states it cannot. The fabric hovers: arm 03-P of the
20260902T2011Z calibration read 933 MHz on 356 of 358 window samples, with
excursions to 1067 above its selection and two samples below, while the
graphics clock held the pinned 1100 on all 358, and a floor admitting
nothing refused that arm as `clock_invariant` violated.
`--max-below-mclk-floor-fraction`, 0.01 by default and carried as the
`clock_below_mclk_floor_fraction` contract row, prices that hover and
leaves a fabric that spent a tenth of a window below its floor refused. The
line keeps printing `samples_at_mclk_floor`, `samples_below_mclk_floor`,
and `below_mclk_floor_fraction` whatever the bound admits.

The invariant is a verdict over one column, so an arm states which column
it was counted over. Under a forced policy the delivered frequency is the
only answer: `pp_dpm_sclk_selected_mhz` repeats the selection the campaign
itself wrote, so an arm reading it held has agreed with the campaign rather
than measured the device. Both runners refuse such an arm with reason
`clock_source`, ahead of `clock_invariant`, which is a verdict over the
same disqualified reading. The 20260902T2011Z calibration is what makes the
condition necessary: it ran `sclk_source=pp_dpm_sclk_selected_mhz` on every
arm because the broker beside it predated the eighth column, and the
preflight built a broker only where the executable was absent.
`build-telemetry-broker.sh` records the source digest it compiled as
`<broker>.source-sha256`, and `census_prepare_broker` in
`census-arm-lib.sh` rebuilds wherever the executable is absent, that record
is absent, or the digest it holds differs from the tree's own, then reads
the record again so a builder that compiled without recording is refused
rather than rebuilt on every run. `sidecar_binary_sha256` and
`sidecar_source_sha256` stay the two `inputs.tsv` rows naming the
instrument a record was acquired with.

The eighth column retires the retained receipts by itself, and that is the
right outcome rather than a cost of the conditional rows.
`sidecar_binary_sha256` and `sidecar_source_sha256` are acquisition-contract
rows, so a change to `telemetry-broker.c` moves the digest of every contract
the tree computes, `auto` runs included: no calibration retained under
`20260902*/` answers an attribution across this change, and
`QWEN_CENSUS_REUSE_BRICKS` reuses no brick across it. A brick measured under
the seven-column sampler was measured under a different instrument, which is
what the digest comparison exists to catch.

The calibration brackets retire them a second time, and each of the three
moves the digest on its own. `clock_below_mclk_floor_fraction` is a new
contract row, `sidecar_max_lost_fraction` carries 0.03 where it carried
0.02, and a rebuilt broker carries a `sidecar_binary_sha256` its stale
predecessor never had. No calibration retained under `20260902*/` answers
an attribution across this change and `QWEN_CENSUS_REUSE_BRICKS` reuses no
brick across it, which is the same outcome for the same reason: the arms
those receipts hold were acquired under another instrument and judged
against other bounds.

One falsifier stands against the mechanism the policy assumes. A forced
level that still reads 658 MHz after a CPU build falsifies the governor as
the cause of the fall and moves the investigation to package power, where a
shared thermal and current budget rather than a DPM decision sets the
clock; the run reports it as a refusal at the `pp_dpm_sclk` confirmation or
as `clock_invariant=violated` on every arm, both of which name the
observation rather than absorbing it. The `high` arms are that falsifier
half met already: the level held its graphics clock and lost the throughput
anyway, which is why the invariant reads two clocks rather than one.

## What the pinned build already carries, and why it is the serialized arm

At f280b269 `ggml-vulkan.cpp` holds `vk_perf_logger`, armed by
`GGML_VK_PERF_LOGGER` at device creation, which allocates a timestamp query
pool of `n_nodes + 100` entries per graph and writes one timestamp after
every enqueued node. It also changes execution: after each timestamp it
calls `ggml_vk_sync_buffers`, which records a full pipeline barrier, and at
graph end it ends the command buffer, submits against the device fence, and
waits on it before reading the pool. Every node therefore runs behind a
barrier and every graph ends in a host wait. That is the serialized
attribution arm the ladder names: exact per-node intervals, dispatch
identity, and compile-time resource statistics, under an execution shape
the serving profile never runs. The census patch leaves that logger as it
is and adds a separate facility beside it.

The S arm reaches that logger through the launch chain rather than around
it. `qwen-webui-control.sh` admits the `diagnostic` profile only with an
explicit `QWEN_LLAMA_SERVER` and a loopback listener, forwards
`QWEN_PERF_LOGGER` across the tmux boundary, and
`radv-low-priority-env.sh` turns a positive `QWEN_PERF_LOGGER` into
`GGML_VK_PERF_LOGGER=1` at that frequency inside the diagnostic branch
alone; under a serving profile the variable refuses the launch. The
profile's environment follows from that one number: after the scrub it
exports `GGML_VK_SERIALIZE_SUBMISSIONS=1`,
`GGML_VK_MAX_NODES_PER_SUBMIT=32`, `GGML_VK_PERF_LOGGER=1`, and
`GGML_VK_PERF_LOGGER_FREQUENCY`, restates the unsets for
`GGML_VK_PERF_LOGGER_CONCURRENT`, `GGML_VK_PIPELINE_STATS`,
`GGML_VK_MEMORY_LOGGER`, `GGML_VK_SUBMIT_TRACE`, and `RADV_DEBUG`, and
refuses a diagnostic launch that names no frequency, so an ambient
diagnostic setting in the calling shell or the tmux server reaches no arm.
`measure-served-decode.sh` retains the result rather than the intent:
it reads `/proc/PID/environ` while the server's identity is pinned and
writes the `GGML_VK_`, `RADV_`, `VK_`, and `QWEN_PERF_LOGGER` names into
`server-effective-env.tsv` beside `server-process.json`, with one
`environ=unreadable` line where the read is refused. The logger
prints to the server's stderr, which the session writes to `server.log`,
and `measure-served-decode.sh` records that file's byte count as the
request window opens and closes and cuts `server-log-request.slice` from
the retained copy, so the blocks the identity record reads are the ones
the timed request appended. `summarize-perf-logger-slice.py` classifies
each complete block before it aggregates anything: the token column is
the largest `n` over `MUL_MAT` and `MUL_MAT_VEC` rows naming a source type
other than `f32`, since an f32 matmul multiplies two activations, the
Gated DeltaNet chunk products, and its `n` is a chunk dimension that
scales with the token count (2, 8, and 32 in a decode block against 38,
152, and 608 in a 19-token prompt block of the retained 0222Z log) rather
than the token count itself, while every other source type names a stored
weight whose column count is the graph's token count. A block whose
token column is 1 is `decode`, above 1 `prefill`, and a block with no such
row is `unknown` and refuses. The parser requires exactly `predicted_n -
1` decode blocks and folds calls per block per ggml op over those blocks
alone, reporting the prefill and unknown counts beside them; the retained
0222Z log reads 63 decode and 3 prefill, where blocks 1 and 2 are the
load-time reserve graphs ahead of `model loaded` and block 3 is the
prompt. The inventory sits beside the I1 ledger; the op-count comparison
between the two is a reader step over two retained files, and S is
serialized identity evidence rather than a throughput comparator.

The pinned tree's `vk_pipeline_struct` keeps one resource field,
`register_count`, filled from the NVIDIA-named `Register Count` statistic
alone. RADV publishes `VGPRs`, `SGPRs`, `Spilled VGPRs`, `LDS size`,
`Scratch size`, and `Subgroups per SIMD` through
`vkGetPipelineExecutableStatisticsKHR`, which the pinned backend already
calls wherever the extension is supported; the census stores those names
and validates each statistic's format before reading the union. They are
compiler resource statistics and occupancy inputs, and a residency figure
comes from combining them with wave size, workgroup geometry, and a
measured interval rather than from any one of them.

The production `llama-vulkan-submit-trace.patch` records, per dispatch,
the pipeline name, workgroup counts, and workgroup denominators into a ring
under `GGML_VK_SUBMIT_TRACE=1`, and refuses to arm without serialization.
Its dispatch record is the seed of the census dispatch row.

## The asynchronous timing arm

The serving profile runs `low-async`, which exports
`GGML_VK_MAX_NODES_PER_SUBMIT=16` and leaves `GGML_VK_SERIALIZE_SUBMISSIONS`
absent. Attribution under that shape needs timestamps that add no barrier
and no host wait. The census writes one top-of-pipe timestamp at graph
start and brackets every `vkCmdDispatch` with a top-of-pipe timestamp
immediately ahead of it, written when the command processor reaches the
dispatch, and an all-commands timestamp immediately after it, written when
the dispatch and everything ahead of it have completed. The bracket is a
queue-residency envelope: it runs from the pre-dispatch timestamp's
execution to the completion of the dispatch and everything preceding the
post-dispatch timestamp, equals something close to the isolated dispatch
latency only where the preceding work had already retired, and is an upper
bound wherever the queue lets neighbours overlap. The row therefore
carries `dispatch_bracket` figures and never a kernel duration. Every
query is written inside the command buffer the graph already records, into
a pool per backend context that the record store is reserved against ahead
of arming, so recording allocates nothing and a graph that outgrows the
pool is marked overflowed and refused whole.

The pool is read where the graph's own fence has retired: in
`ggml_vk_synchronize` after `ggml_vk_wait_for_fence` on the asynchronous
path and at graph end on the serialized path. Both reads ask the device for
availability and never wait, and a query the device had not written is
counted on the graph row and refuses the graph. A graph never read at
either point is read at the next graph start or at cleanup with a wait,
since its pool is reset there; the row names that read point and the
summarizer refuses the graph, so a host wait the instrument added is a
defect the run reports rather than a rate it publishes. Timestamp
differences are taken modulo the compute family's `timestampValidBits` and
convert through `timestampPeriod`. Host instants come from
`clock_gettime(CLOCK_MONOTONIC)` directly, the clock the record names.

Host phases are kept apart. `record_ns` is what
`ggml_backend_vk_graph_compute` spent recording and submitting.
`retire_span_ns` runs from graph start to the moment the reader knew the
fence had retired and precedes every census read and write, so it is the
host-side bound on the graph that the residual is taken against.
`readback_ns` is the query read. The emission is deferred: at graph end
the instrument appends fixed-size binary records, one per dispatch and one
per graph, into a buffer reserved once at context creation (51840
dispatch records and 128 graph records, 14.3 MiB, 78 decode graphs of the
2B between drains), and formats and writes the text rows in one drain at
context close or where the buffer fills, in the same order the rows would
have been written per graph. `dispatch_row_emit_ns` is the time to append
the dispatch records, and the `census_emit` row carries the graph record's
append as `graph_row_ns`, the drain's write and flush as `flush_ns` where
a drain fell inside this graph's emit and zero otherwise, and
`total_emit_ns` as their sum from readback end; all of them follow
retirement and are the instrument's own cost inside the token, which the
`I0 I1 I1 I0` pair measures. The first two served I1 arms at the
per-graph text write ran 2.4 to 2.6% under their I0 neighbors against the
2% bound, and the workstation smoke of the deferral moved the per-graph
path from 878 to 86 microseconds with byte-identical rows.

Ownership is stated from what the brackets can distinguish. Summing one
pipeline's bracket durations over a graph and dividing by the union of all
brackets counts overlapping time once in the denominator and repeatedly in
the numerators, so two fully overlapping pipelines would each own the
whole graph; no such share exists in the ledger. The summarizer sweeps the
bracket endpoints of each graph instead: a segment covered by exactly one
bracket is that pipeline's exclusive time, a lower bound on what it owns;
the union of a pipeline's own brackets is its upper bound; a segment
covered by two or more brackets goes to an ambiguous-overlap bucket, both
globally and under every pipeline whose bracket covers it. Per graph
`overlap_ns` is the raw bracket sum minus the union and
`overlap_fraction` is that over the union; a ledger whose mean fraction
exceeds the preregistered threshold of 0.05 reads `ownership=inconclusive`
on its `graphs` row and still prints every bound. The verdict reads the
whole overlap, which withholds attribution rather than manufacturing it,
and the `graphs` row carries a derived reading beside it: an ambiguous
segment whose covering brackets all belong to one pipeline is
`same_pipeline_overlap`, still that family's at the family level while
dispatch ownership inside it stays open, and a segment two pipelines cover
is `cross_pipeline_overlap`, the kind that blocks family ownership;
`cross_pipeline_overlap_fraction` is the second over the union. The S
arm's serialized ordering tests whether the low-async upper-bound ranking
preserves the same major pipeline order.

The summarizer trusts nothing the instrument aggregated. It recomputes the
raw sum, the union, the queue time outside every bracket, the completion
span, the unavailable and unbound counts, and the distinct submission
count from the dispatch rows and requires exact agreement with the graph
row; it requires every query index distinct within a graph with the reach
index below the completion index, each interval equal to its endpoints'
difference, every dispatch on the census queue's family, one `census_emit`
row per graph consistent with the graph row, a `census_selftest` row
reading `sha256=ok`, and `census_close` counts equal to the parsed graph,
pipeline, and dispatch counts. Every graph inside the request window is
validated ahead of the phase filter, so a defective prefill graph fails a
decode ledger, and a graph that begins before the window and retires
inside it, or begins inside and retires after it, is refused as ambiguous
membership rather than sorted either way. The interval rule rests on the
device's timestamp period: the instrument converts the two endpoints and
the tick distance through `timestampPeriod` separately, so a non-integral
period could truncate the two conversions one nanosecond apart. RADV
reports `timestampPeriod = 40` for RAVEN2 (`vulkaninfo` on the appliance),
and an integer period makes the two products agree exactly, so the rule
holds on this device and a later device with a fractional period would
need the interval derived from the converted endpoints.

Each dispatch is bound to its submission at the submit: `ggml_vk_submit`
allocates the serial for the compute queue of the owning context and
assigns it to every recorded dispatch whose command buffer and use counter
it carries, and a dispatch left unbound refuses its graph. The row carries
the queue family and the command buffer identity beside the serial.

Graphs are selected by request membership rather than by shape alone.
Every graph row carries its begin and retire instants on `CLOCK_MONOTONIC`,
`measure-served-decode.sh` retains the monotonic window of the one
completion request it timed, and the summarizer selects the graphs inside
that window, requires exactly `predicted_n - 1` decode graphs contiguous
in serial, and reports prefill separately. A warm-up graph, a cache
operation, or a second request therefore cannot enter the ledger unnamed.

## The identity a row is keyed by

A pipeline name is one symbol compiled under several specialization
constants, so the same name at different `NUM_ROWS`, `NUM_COLS`, subgroup
policy, or accumulation mode is a different performance object. The census
key is:

```text
spirv_source_sha256    spirv_executed_sha256    entry_point
specialization_constants   required_subgroup_size   full_subgroups
parameter_count        push_constant_size        wg_denoms
ggml_op                dst and src0 names        src0 src1 dst types
ne0..ne3  src1_ne1     workgroups                phase
```

The executed digest covers the module bytes `vkCreateShaderModule`
received after the float-controls and driver-specific rewrites, which is
the module the device ran; the source digest covers the embedded module a
variant was built from. The digest comes from a SHA-256 embedded in the
instrument, and that implementation is held to two checks rather than
trusted: the binary hashes three known vectors at census initialization
and refuses to open a census on a mismatch, writing `census_selftest`
into the file it passed, and `remote/test-census-sha256.sh` compiles the
function out of the patch on the workstation and compares it with
`sha256sum` over the known vectors, every padding boundary from 55 to 65
bytes, and a random mebibyte. `GGML_VK_PIPELINE_CENSUS_DUMP` names a
directory the executed modules are written to as `<digest>.spv`, so one
dumped module is cross-checked against `sha256sum` by its file name. The
pipeline id is local to one census file, assigned on first dispatch, since
one pipeline object serves every backend context on the device.
`wg_denoms` is a dispatch denominator and the local workgroup size lives
in the specialization constants where the shader declares it there.

Per dispatch the row retains the dispatch count, grid and workgroup
dimensions, workgroups launched, queue identity, submission serial, the
two bracket instants and their interval, and the bytes the tensor census
attributes to the weights it read. Per pipeline variant the aggregate
retains the bracket upper bound, the pipeline's own union, its exclusive
and ambiguous time, median, p90, p99, and maximum interval, calls per
token, workgroups per token, and the six RADV statistics. A Vulkan
dispatch and a workgroup stay separate quantities: one graph node issues
one dispatch of thousands of workgroups, and command overhead and shader
geometry are told apart by carrying both.

## The clock sidecar

The one-second runtime monitor is adequate for safety and too coarse to
place a 52 to 62 ms token. `remote/telemetry-broker.c`, built by
`remote/build-telemetry-broker.sh` into `build/telemetry-broker` beside
`remote/`, is the sampler `QWEN_CENSUS_SAMPLER` selects by default: it opens
every surface once at startup, reads `gpu_busy_percent` at the requested
period into a preallocated ring, reads the three DPM attributes and the die
temperature on a tenth-period channel that lands at 100 ms under the
registered 10 ms period, and formats the whole record after SIGTERM, so the
sample itself opens, allocates, and writes nothing. Nice 19 is a constant of
the program rather than an option, `--cpu` carries the runner's both-core
confinement, and one `telemetry_broker=ready` line on stderr states that
every surface is open and the termination handler is installed, which the
runner waits for before the request starts and fails the arm on with
`sidecar_start`. `QWEN_CENSUS_SAMPLER=python`
runs `remote/sample-clock-sidecar.py` instead; both emit the record
`validate-clock-sidecar.py` reads, and the acquisition contract carries
`sidecar_implementation` beside the broker's executable and source digests
so a record is attributed to the program that produced it.

`remote/sample-clock-sidecar.py` samples
`pp_dpm_sclk`, `pp_dpm_mclk`, `pp_dpm_fclk`, `gpu_busy_percent`, and
`temp1_input` every 10 ms on `CLOCK_MONOTONIC`, the clock the census stamps
every graph with and the runner stamps its request window with, so a clock
step is placed against a graph rather than against a minute. The columns
name what they read: `pp_dpm_sclk_selected_mhz` is the selected graphics
step, and `pp_dpm_mclk_surface_mhz` and `pp_dpm_fclk_surface_mhz` are the
sysfs surfaces, which on this SMU10 path are fabric-clock states rather
than the trained DRAM speed, as the header line states. The sampler is
confined to both cores at nice 19, the priority the appliance runs every
measurement process at, the server on core 0 included, and it records its
pid, niceness, and affinity in the header. Pinned to core 1 it lost about
40 ms once a second to the guards, which sample on that core at nice 0, so
it floats to whichever core is free and the sidecar control prices what it
takes from the server's core. The priority is a constant of
the runner rather than an option, so a hole the scheduler opens at that
priority is reported by the gap validator rather than closed by a higher
one.

A sidecar record is evidence only where `validate-clock-sidecar.py`
accepts it: exit status 0, one footer, a sample count above one equal to
the rows, an achieved period within 25% of the requested one, a mean
sample cost under 1 ms, every sensor read on every sample, footer
instants equal to the first and last rows, the request window covered on
both sides, a `window_lost_fraction` at or below
`sidecar_max_lost_fraction`, default 0.03, and no adjacent sample gap
above `sidecar_max_gap_ns`, default ten periods or 100 ms and raised to
250 ms by the runner under a forced clock policy, overlapping the request
window. Coverage rather than the widest gap is what the record
owes the arm: the fraction prices every gap wider than two periods against
the window it clips, and the stall bound refuses a sampler that stopped
rather than one the scheduler descheduled. The validator reports the
median, p95, p99, and maximum gap and the counts above 1.5 periods and
above the bound as observations beside both verdicts. The first calibration on 34de93f
refuted a 5 ms period with a 10 ms bound at nice 10: the median gap held
5.0 ms and the p99 7.3 ms while the maximum reached 58 ms with ten gaps
above the bound and four inside a 6.4 s request window, which is the
scheduler preempting a nice-10 sampler for a nice-0 burst on the same core
rather than the sampler's own cost, so the period doubled and the bound
follows it. The SMU10 kernel path exposes
`pp_dpm_fclk` as an empty file and reports the fabric clock through
`pp_dpm_mclk`, so the runner allows the FCLK column to read `unavailable`
where a read of that attribute succeeds and returns nothing at campaign
start, records the allowance in `inputs.tsv`, and requires every other
column on every sample. The read decides it because sysfs reports every
attribute at one page in `stat`, and only the readable-empty state earns
the allowance: an absent attribute, an unreadable one, or a failing read
is another telemetry state and refuses the run. Any refusal fails the arm.
At a 5 ms cadence the measured 603 microsecond read cost is about 12% of
one core's interval, which is why the sampler control stays mandatory. The
`P-nosidecar P P P-nosidecar` control runs ahead of the other two and
bounds what the sampler itself costs the served rate, because two hundred
sysfs opens per second are a real load on a two-core machine even where
each sample is cheap; the `I0 I1 I1 I0` pair then measures collection
under the sampler both arms share. The graphics probe's latency log keeps
its own clock and is read beside the sidecar rather than joined to it.
Clock selection is an execution-shape axis here, because a faster or more
fragmented shader can lower apparent demand and select a lower state that
cancels part of its own gain.

`validate-clock-sidecar.py` refuses a malformed cadence claim rather than
reading it under a silent default. `--expected-nice` and
`--expected-cpu-affinity` hold the header's own reported priority and CPU set
to what the launcher configured, closing the gap between a header naming a
niceness (`sampler_identity`) and a header naming the niceness the launcher
asked for (`sampler_nice`, `sampler_affinity`). `channel_cadence` and
`cadence_values` hold a `# sample_rates:` header to completeness --
`gpu_busy_percent_period_ns` and `pp_dpm_period_ns` present -- and to
arithmetic -- each declared cadence a positive multiple of the requested
period, with the busy channel's equal to it exactly, since that channel is
read on every sample. Where the header also carries `# dpm_read=` markers,
`dpm_marker_cadence` compares the widest marker gap overlapping the request
window against 1.5 times the declared DPM cadence, catching a sampler whose
own freshness stamps drifted past what it declared -- the marker half of
what keeps a cached value from being counted as a fresh observation; the row
half already reads `dpm_period_multiple` over reads rather than rows and now
carries a `temp1_period_multiple` beside it for the temperature channel.
`sampler_format`, sample-clock-sidecar.py's own `native-fresh-v1` claim that
every column here is read fresh on every sample, refuses an unrecognized
value rather than reading a future record shape under today's rules. A
window is supplied whole or not at all, each bound nonnegative, and
`--cost-bound-ns`, `--max-gap-ns`, `--required-sclk-mhz`, and
`--required-mclk-mhz` are positive where supplied, each checked where it is
parsed ahead of any read of the record.

## Order and falsifiers

Runs go 2B, then 0.8B, then 4B. The 2B validates the instrument, the 0.8B
tests whether the instrument preserves the clock-sensitive path, and the 4B
supplies the scaled structural case. A default becomes Raven2-wide only
where the classes agree. A census proper on any class follows a 2B
calibration in which all three registered controls accepted on the exact
instrument the census runs.

- Either `P-nosidecar P P P-nosidecar` paired delta outside 0.65% refutes
  the claim that the 10 ms sampler leaves the served rate inside the
  class's own spread.
- Either `P I0 I0 P` paired delta outside the 2B's 0.65% scoreboard span
  refutes the claim that compiling the instrumentation leaves the served
  rate inside the class's own spread.
- Either `I0 I1 I1 I0` paired delta outside 2% refutes the claim that the
  asynchronous collection is cheap enough to attribute serving-profile
  time; the serialized arm then remains the only attribution.
- A mean bracket overlap fraction above 0.05 over the selected decode
  graphs makes ownership inconclusive: the ledger keeps its upper and
  lower bounds and states no owner.
- A query the device had not written when its fence retired, a read at
  `next_graph` or `cleanup`, a read that waited, an overflowed pool, or a
  dispatch no submission bound fails the arm.
- A graph aggregate the summarizer cannot reproduce from the dispatch
  rows, a reused query index, an interval disagreeing with its endpoints,
  a missing or inconsistent emit row, a failed self-test, or a close row
  disagreeing with the parsed counts fails the arm.
- A request window holding other than `predicted_n - 1` decode graphs,
  decode graphs that are not contiguous in serial, a graph partially
  inside the window, or a defective graph of either phase inside it fails
  the arm.
- A bracket union exceeding the queue completion span, or a completion
  span exceeding the host retire span, refutes the timestamp conversion
  and fails the arm.
- A sidecar record refused by the validator fails the arm.
- An S slice holding other than `predicted_n - 1` decode blocks, or any
  block whose phase cannot be classified, fails the arm.
- A pipeline whose RADV statistics are absent or of an unexpected format is
  recorded with `-` in those fields and never with the NVIDIA register
  count in their place.
- Kernel hazards, swap-in, and probe deadline breaches are read from the
  same watchers the scoreboard used, and any of them fails the arm.

## Files this stage adds

```text
patches/llama-vulkan-pipeline-census.patch    candidate stage of the series
remote/run-raven2-vulkan-kernel-census.sh     the runner, one class per call
remote/summarize-kernel-census.py             rows to the per-pipeline ledger
remote/summarize-census-controls.py           the three registered controls
remote/summarize-perf-logger-slice.py         the S arm's op inventory
remote/sample-clock-sidecar.py                DPM state at 10 ms on CLOCK_MONOTONIC
remote/validate-clock-sidecar.py              whether a sidecar record is evidence
remote/test-census-sha256.sh                  the embedded hash against sha256sum
evidence/raven2-vulkan-kernel-census/<stamp>/ retained runs
```

`measure-served-decode.sh` retains `request-window.tsv` and
`server-log-request.slice` beside every response, the runner's `arms.tsv`
carries one row per arm with its sidecar and ownership state,
`summary.tsv` one row per quadruple with both deltas and a verdict,
`terminal-state.tsv` the campaign state and counts, and the summarizer's
`pipeline-ledger-decode.tsv` ranks pipelines by bracket upper bound over
the selected graphs with a `graphs` row carrying every per-graph
accounting figure and the ownership status.

`radv-low-priority-env.sh` carries the non-serving `diagnostic` profile
that preserves the logger variables the serving profiles scrub, the launch
chain admits that profile for an explicit server on loopback alone, and
`build-llama-preset.sh` gains the `census` preset that writes the three
diagnostic manifest rows.
