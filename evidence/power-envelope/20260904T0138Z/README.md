# The package-budget campaign, run

Twelve arms on the appliance: three checkpoints in the class policy's order,
each taking control, 20 W, 25 W, control as one `compute-state-lease.sh`
transaction per arm around one fixed-64 served decode. Every arm delivered 1100
MHz GFXCLK with FCLK at 933, every arm's `restoration=held`, and every arm's
`--info` read the same limits at its end as at its start. `summary.tsv` carries
the table this document reads and `arm-status.tsv` the lease status of each arm.

## What the arms measured

| Checkpoint | Arm | STAPM/slow/fast | decode tok/s | package W | core W | GFXCLK | FCLK | Tctl peak |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| qwen38-2b-distill | control | 15/20/25 | 9.834 | 17.25 | 1.58 | 1100 | 933 | 59.2 C |
| qwen38-2b-distill | 20 W | 20/20/25 | 9.802 | 17.30 | 1.56 | 1100 | 933 | 62.5 C |
| qwen38-2b-distill | 25 W | 25/25/25 | 9.826 | 17.30 | 1.57 | 1100 | 933 | 63.2 C |
| qwen38-2b-distill | control | 15/20/25 | 9.843 | 17.52 | 1.59 | 1100 | 933 | 62.8 C |
| qwen35-08b | control | 15/20/25 | 18.715 | 17.08 | 1.82 | 1100 | 933 | 67.0 C |
| qwen35-08b | 20 W | 20/20/25 | 18.856 | 17.28 | 1.87 | 1100 | 933 | 59.6 C |
| qwen35-08b | 25 W | 25/25/25 | 18.874 | 17.17 | 1.89 | 1100 | 933 | 63.4 C |
| qwen35-08b | control | 15/20/25 | 18.761 | 17.28 | 1.90 | 1100 | 933 | 64.6 C |
| qwen38-4b-distill | control | 15/20/25 | 3.384 | 16.16 | 1.29 | 1100 | 933 | 74.0 C |
| qwen38-4b-distill | 20 W | 20/20/25 | 3.379 | 16.16 | 1.31 | 1100 | 933 | 66.2 C |
| qwen38-4b-distill | 25 W | 25/25/25 | 3.380 | 16.19 | 1.32 | 1100 | 933 | 77.8 C |
| qwen38-4b-distill | control | 15/20/25 | 3.380 | 16.19 | 1.31 | 1100 | 933 | 75.8 C |

The watts are the inner bracket, whose whole interval lies inside the request
window. The outer bracket, which contains the request window, reads within 0.5%
of it on every arm, so the sampling period rather than the reading is what
separates the two.

## The verdict

The package budget is not a lever on this part for this workload, and the
reason registered for that outcome is refuted. The prediction was that the 20 W
and 25 W arms would deliver no additional sustained package watts because the
part is already thermally bound. The first half holds exactly: package draw
spans 16.16 to 17.52 W across all twelve arms, and inside one checkpoint the
budget moves it by 0.27 W at most while STAPM moves 10 W. The second half does
not: Tctl peaked between 59.2 and 77.8 C against the platform's own 90 C limit,
so no arm approached the thermal ceiling either. Neither the power ceiling nor
the temperature ceiling was the binding constraint. The part draws about 17 W
under a 15 W STAPM and declines to draw more under a 25 W one, which places the
constraint in the workload rather than in either budget the campaign can move.

The three registered falsifiers read as follows.

`no additional sustained package watts` -- met, and its stated mechanism
refuted. A budget raised by 10 W bought 0.27 W at most on any checkpoint, at
temperatures 12 to 31 degrees below the thermal limit.

`delivered graphics clock does not move` -- met on every arm. All twelve
arms deliver a 1100.0 MHz mean from the amdgpu hwmon `freq1_input`, and no arm
exceeded it, so nothing refutes the firmware-query section of the parent
document.

`CPU boost residency rises before decode does` -- not run. This campaign
retained no per-core delivered-frequency record, and the core-domain watts it
did retain move by under 0.05 W between budgets inside a checkpoint while moving
0.6 W across checkpoints, which orders the checkpoints rather than the budgets.
A boost-residency claim needs `scaling_cur_freq` sampled beside the window.

The promotion gate is therefore unmet and closed rather than pending: no gain
holds across every checkpoint, and the campaign is retained as the measurement
that closes the package budget as a lever on this part.

## What the rate half can and cannot say

The rate comparison resolves no direction, and the summarizer's own verdict
line overstates what it resolves. The registered readability rule reads a
candidate as a budget effect where it exceeds the same checkpoint's observed
control-to-control spread, and with two control arms that spread collapsed to
0.1 to 0.2%: the 2B's controls agreed to 0.1% and the 0.8B's to 0.2%. Under
that rule a 0.4% difference reads as `slower` and a 0.6% difference as
`faster`, both of which sit an order of magnitude below the roughly 4% of
uncontrolled spread this tree already measures on a repeated depth-0 rate under
identical flags. A two-point control spread is a difference rather than an
uncertainty. The correct reading of the rate half is that every candidate lands
inside the machine's own spread on every checkpoint, and the verdict above
rests on the package watts, which are what a raised budget would have had to
move first.

## The instrument, controlled

`instrument-controls/` holds the check that separates a null result from a dead
counter. The same reader at the same 50 ms period over 19.8 idle seconds reads
2.51 W package and 0.03 W core, against 16 to 17.5 W package and 1.3 to 1.9 W
core in the decode windows, so `intel-rapl:0` on this part tracks the load
rather than incrementing at a fixed rate. The core domain carrying about a
tenth of the package draw under a Vulkan decode is what an APU reports: the two
Vega compute units are inside the package domain and outside the core domain.

`instrument-controls/cold-sclk-selection.tsv` retains the second measurement in
that directory, which is a device property the campaign had to establish before
it could run. From a cold 400 MHz idle, the SMU10 firmware held the idle step
for 18.7 seconds after a manual level-2 mask reached `pp_dpm_sclk` and then
starred level 2 with `freq1_input` at 1100 MHz; a first observation the same
evening took 26.8 seconds. `census_engine_clock_select` polled the starred step
for a hard-coded ten seconds, so three arms in a row refused with `pp_dpm_sclk
selected level 1 where the campaign wrote 2` while the same profile passed
minutes later on a warm device. The starred step follows the clock the part
delivers rather than the mask the write set, so the deadline is now forty-five
seconds.

## Two components refused before the first arm, and both were repairs

`measure-served-decode.sh` hands llama-server a descriptor path and
`qwen-capacity-policy.sh` refuses a descriptor-backed model carrying no
publisher identity, so the first arm ended on `descriptor-backed model path
requires approved model identity` until the arm carried the registry and the
artifact ledger. The same runner pins the approved executable on descriptor 6,
so a later arm completed a valid 64-token decode and then failed on `approved
executable identity is unreadable` until the arm named the active deployment's
server.

The third refusal was a design correction rather than a missing input.
`monitor-qwen-runtime.sh` renices itself to 0 and exits where it cannot, and
`qwen-webui-session.sh` ends the session with `reason=monitor_exited` when it
does, so a served command started under `measure-fixed`'s nice 19 wedges its own
session ahead of the first request: the appliance answered one 19-token prompt
with a six-minute curl against a server already unwinding. The arms therefore
run under `serve-fixed-package-*`, which carries the same clocks, the same
memory scanner, the same cores, and the same three budgets with the child at
nice 0, because `qwen-capacity-policy.sh` puts llama-server itself on core 0 at
nice 19 and the campaign contract already states that. The arm applies nice 19
to its own three samplers rather than inheriting it.

`arms/qwen38-2b-distill-01-control-open.attempt1.lease.stderr` under the earlier
campaign directories is not retained here; the refusals above are recorded in
this document and in the commit history rather than as arms, because an arm that
refused ahead of its first request measured nothing.

## Retained per arm

`arm-summary.tsv` carries the row this document's table is built from.
`energy-samples.tsv` is the 50 ms privileged record and `energy-window.tsv` the
two brackets differenced out of it against `request-window.tsv`.
`clock-samples.tsv` is the 10 ms sidecar and `device-samples.tsv` the one-second
Tctl, edge, and `freq1_input` record. `ryzenadj-info-start.txt` and
`ryzenadj-info-end.txt` are the firmware's own power-metrics table whole at both
ends of the arm. `summary.json`, `request-window.tsv`, `server.log`,
`server-log-request.slice`, `session.status`, and the rest are what
`measure-served-decode.sh` retains for any served arm.
