# What a depth-0 rate on this machine actually repeats to, and what the memory
# is doing

Two rates for the same cell -- Qwen3.8-4B Distill Q4_K_M, full Vulkan offload,
`-ngl 99 -t 2 -r 3 -p 0 -n 64` on one build and one file -- disagreed by 7.5%:
3.31 tok/s in the Nanbeige depth ladder against 3.08 in the KV cache factorial.
That is larger than every effect the factorial set out to resolve, so it had to
be settled before either could be read.

## The disagreement is state, and it is worth about 4%

`remote/measure-bench-repeatability.sh` runs the ladder's flag set and the
factorial's, hot and then again after ten minutes idle.

| arm | flags | decode tok/s | peak C | modal mclk |
| --- | --- | ---: | ---: | ---: |
| ladder-flags | none passed | 3.20 +/- 0.02 | 85 | 933 |
| hot-f16-fa-off | `-ctk f16 -ctv f16 -fa off` | 3.11 +/- 0.03 | 89 | 933 |
| hot-f16-fa-auto | `-ctk f16 -ctv f16` | 3.18 +/- 0.01 | 90 | 933 |
| cold-f16-fa-off | `-ctk f16 -ctv f16 -fa off` | 3.24 +/- 0.01 | 84 | 933 |
| cold-ladder-flags | none passed | 3.27 +/- 0.00 | 85 | 933 |

Identical flags measure 3.11 hot and 3.24 cold, a 4.2% spread on nothing but
elapsed idle time. The ladder's 3.31 sits 1.2% from the cold repeat of its own
flag set, so an idle machine reproduces the ladder and a loaded one reproduces
the factorial.

Passing `-ctk f16 -ctv f16` changes nothing: 3.20 against 3.18 with the flags
otherwise equal, which is the control working. In the cold block the two flag
settings differ by 0.9% where hot they differed by 2.9%, so the flag effect an
earlier reading took for real is inside the state gradient.

**Consequence.** A depth-0 rate on this part carries about 4% of uncontrolled
spread. Two such rates are comparable when they were measured inside one window
and are not comparable across sessions. Every depth-0 figure in this tree
predates that finding. Deep rungs are less exposed: a 16384 rung is preceded by
about thirteen minutes of prefill that settles the part before decode begins,
and the ladder and the factorial agree to 1.1% there, 2.69 against 2.66.

## Neither clock ladder explains it

`remote/sample-gpu-clocks.sh` recorded the DPM state through every arm above.
`pp_dpm_mclk` reported step 2, 933 MHz, in all five, and `sclk` peaked at
1100 MHz in all five, cold arms at 84 C included. The covariate the sampler was
added to control is constant across the spread it was meant to explain, so it
does not explain it. The sampler stays because a constant that is recorded is a
constant that is known.

## Memory runs at DDR4-1866 and the step above it is unreachable

| property | value | source |
| --- | --- | --- |
| modules | 2 x 16 GiB Crucial CT16G4SFD8213, dual-rank | `dmidecode -t memory` |
| module rating | 2133 MT/s | SPD `Speed`, both DIMMs |
| channels | 2, both banks populated | `RAM width 128bits DDR4`, `P0 CHANNEL A`/`B` |
| operating clock | 933 MHz, which is DDR4-1866 | selected step in `pp_dpm_mclk` |
| theoretical peak | 29.9 GB/s | 2 x 8 bytes x 1866 MT/s |

The 1067 MHz entry at the top of `pp_dpm_mclk` is a capability the SMU never
selects. Writing `high` to `power_dpm_force_performance_level` pins `sclk` to
1100 MHz and leaves `mclk` at 933. Writing `manual` and then the step index 3 is
accepted without error and also leaves it at 933. Reading that entry as evidence
of a trained 2133 MT/s is therefore wrong; the reachable step is the operating
point and it is one grade below what the modules are rated for and two below the
DDR4-2400 the SoC specifies.

Dual-rank population fits: both modules report `Rank: 2`, and Raven2 commonly
derates a dual-rank dual-channel population below its single-rank maximum. A
single-DIMM boot test would separate that from an OEM BIOS cap, and neither is
established here. If rank is the cause, two single-rank DDR4-2400 modules would
raise memory bandwidth by 2400/1866, which is 1.29 times, and that exceeds every
software lever this tree has measured.

`dmidecode` prints `Configured Memory Speed: 2400 MT/s` for both DIMMs. That
exceeds the modules' own SPD rating and the reachable DPM step, so the field is
wrong rather than informative.

## Forcing the governor buys nothing

`remote/measure-dpm-force.sh` alternates `auto` and `high` rather than running a
block of each, because the 4.2% state spread above exceeds the effect being
looked for. The original level is restored from an EXIT trap.

| round | level | decode tok/s |
| ---: | --- | ---: |
| 1 | auto | 3.23 +/- 0.06 |
| 1 | high | 3.23 +/- 0.05 |
| 2 | auto | 3.27 +/- 0.00 |
| 2 | high | 3.22 +/- 0.07 |

The two settings are indistinguishable, which follows from what the ladders do:
`mclk` cannot leave 933 and `sclk` already reaches 1100 under `auto`. The
governor is not a lever on this machine and the appliance keeps `auto`.

## Where the ceiling is not

Host sequential read measures 15.44 GB/s on two threads, 52% of the 29.9 GB/s
controller peak. That figure bounds the two Zen+ cores through the load/store
path and says nothing about the iGPU, which reaches memory through the Data
Fabric on a different path with its own limit. The GPU's achievable streaming
rate is unmeasured, so the fraction of it that decode uses is unknown, and
`evidence/decode-bound-analysis.md` carries what replaced the guess.
