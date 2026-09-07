# The prefill ladder on the 2B distill, and what its own null control costs

`remote/run-prefill-ladder.sh` reads what a prompt costs before the first token
appears, at 512, 4096, and 16384 tokens on `qwen38-2b-distill`, against the
production bundle `main-2c1fa9de-r1`. Every arm launches its own server at the
registry tuple with every buffer on Vulkan0, the `low-async` submission profile,
and nice 19, and the prompt is built against `POST /tokenize` until that route
returns exactly the requested depth.

The tree holds no candidate `llama-server` beside the production one, so the
`C K K C` binary quadruple runs the production server against itself. That is a
null control rather than a comparison, and it is what makes the second
quadruple readable: `C T T C` places one thread against the registry row's own
two, and the null quadruple states what the ladder's pairing reports when the
two arms are identical by construction.

## Falsifiers, stated before the numbers

- A null binary quadruple whose interval excludes unity refutes the interval as
  an uncertainty statement, since the two arms execute the same 92015c14 bytes
  on the same model and the true ratio is 1 by construction.
- The thread quadruple resolves the CPU-side share of a prefill only where its
  interval clears unity. An interval spanning unity leaves the direction
  unresolved whatever the mean ratio reads.
- An arm whose clock sidecar refuses is not a slow arm; it reaches the ledger as
  `failed` and its quadruple as `incomplete` rather than pairing a rate the
  instrument could not stand behind.

## The depth curve

One allocation of 32768 tokens serves every rung, so a depth changes the prompt
and leaves the KV allocation alone. Means over the four `C` arms of each rung:

| depth | prompt tok/s | time to first token | decode tok/s |
| ---: | ---: | ---: | ---: |
| 512 | 50.83 | 10.10 s | 9.58 |
| 4096 | 47.89 | 85.58 s | 8.88 |
| 16384 | 36.23 | 452.27 s | 7.01 |

Prefill falls 28.7% from 512 to 16384 and decode falls 26.8% over the same
prompts, so a deep prompt costs the tail of its own turn as well as its fill.

## The null control refutes the narrow interval

At 512 the null quadruple reports `prompt_tok_s` at a mean ratio of 1.0007 with
a 95% interval of [1.0003, 1.0011], which the summarizer reads as `above` unity.
The two arms are one binary, one model, and one tuple, so the true ratio is 1
and the interval excludes it. The falsifier above is met.

The mechanism is the replicate count rather than the instrument: two replicates
that agree to 0.007% produce an interval narrower than the between-arm scatter
the same ladder shows elsewhere, and the 16384 thread quadruple shows that
scatter directly -- its two `C` replicates read 35.40 and 33.29 tok/s, 6.0%
apart, against two `T` replicates at 33.35 and 33.38 that agree to 0.09%. A
prefill ladder interval built on two replicates therefore reports the agreement
inside a pair rather than the agreement between pairs, exactly as this tree's
decode campaigns record for `llama-bench` repetitions.

The consequence is a reading rule: at 512 the ladder resolves a real difference
only above about 0.1%, and at 16384 the same construction leaves a 2.8% mean
difference unresolved, so a prefill claim on this machine states the replicate
count it rests on.

## Threads

`C T T C` places one thread against the registry row's two.

| depth | 1 thread | 2 threads | mean ratio | interval | verdict |
| ---: | ---: | ---: | ---: | --- | --- |
| 512 | 50.84 | 50.61 | 0.9954 | [0.9238, 1.0671] | unresolved |
| 4096 | 47.89 | 47.94 | 1.0010 | [0.9836, 1.0184] | unresolved |
| 16384 | 34.35 | 33.37 | 0.9724 | [0.5898, 1.3549] | unresolved |

The second thread never resolves in either direction. Its mean sign is negative
at 512 and 16384 and positive at 4096, and the 16384 interval is opened by the
one-thread arms' own 6% spread rather than by the thread count. A prefill on
this part is a Vulkan submission whose host side is one dispatch loop, so a
second thread having no measurable effect is the reading the means allow and the
intervals decline to confirm.

## What the instrument refused

Arm 9, the first `4096 binary C` replicate, refused on `gaps`: one 114.99 ms
sampling interval against the 100 ms bound, three intervals above 1.5x the
period, and a window lost fraction of 0.0005. The sampler was descheduled; the
device state is not implicated. Its quadruple therefore reads `incomplete` with
`failed_arms=C1:clock_sidecar` rather than pairing the surviving replicate
against a control it has no partner for, which is the harness declining to
report a number it cannot stand behind.

## Machine state

The graphics clock held its 1100 MHz top step on every admitted arm, and the
fabric surface read 933 MHz throughout, under the governor's own `auto` policy
rather than a forced level. The forced-level path writes
`power_dpm_force_performance_level` through `sudo -n`, which this window holds
no credential for, so `QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY=auto` ran instead
and every arm's own sidecar record carries the step it actually ran at. The
sclk mode is 1100/1100 on every summarized row, so the arms met the same
operating point the forced policy would have commanded.

## Not run

- **32768.** The rung clamps to 32719 tokens and its arms cost about 22 minutes
  each, so its eight arms exceed the device window beside the remaining
  campaigns. The rung is unmeasured rather than failed, and the run was ended
  between the last 16384 arm and the first 32719 arm with the lease released and
  the clock policy restored.
- **`qwen35-08b` and `qwen38-4b-distill`.** The class policy orders the 2B
  first, and its three rungs consumed the ladder's whole share of the window.
  Neither class was measured, so this record states the 2B alone and no
  cross-class prefill comparison follows from it.

## The repair this run required

Every arm of the first attempt failed `clock_sidecar` on
`sensors=refused unavailable_outside_allowance=pp_dpm_fclk_surface_mhz`.
`run-prefill-ladder.sh` decided the SMU10 path's empty `pp_dpm_fclk` with
`[ ! -s ]`, and sysfs reports every attribute at one page in stat, so the test
read the empty attribute as full and withheld `--allow-unavailable` from every
arm. The predicate now reads the attribute, which is what
`run-raven2-vulkan-kernel-census.sh` already did. The retained records above
carry `sensors=accepted ... allowed=pp_dpm_fclk_surface_mhz`.

## Retained files

`qwen38-2b-distill/` holds `inputs.tsv` (both server digests, the model digest,
the tuple), `arms.tsv` (one row per arm), `summary.tsv` (the paired ratios),
`run.log`, and one directory per arm carrying the clock sidecar record, its
verdict, the server log, the request's final chunk, and the arm's environment.
Paths name `$HOME` and the host reads `qwen-laptop`.
