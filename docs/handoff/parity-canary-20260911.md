# Parity canary receipt: the legacy and Python launch paths in one window

Window `pyctl-canary7` on the laptop, 2026-09-11 daytime under the user's
nice-19 grant, alternated the production LAN launch
(`qwen-lan-launch.sh lan-authenticated low-async`, its own address behind
the Web UI bearer) and `qwen-apu appliance serve --router --port 8080` on
the loopback in the order legacy, python, legacy, python, with production
torn down before and relaunched after. One fixed prompt of 64 tokens against
`qwen38-2b-distill` measured each arm through the server's own `timings`
block, and the rule, registered before the run, holds where the Python
median sits at or above 0.90 of the legacy median for each metric.

The configuration each arm ran under was read from the live process and
the named sysfs files rather than assumed, and the verdict requires the
arms to agree on it: the executable by SHA-256, the router preset by the
digest of its text with each absolute path reduced to its basename, the
policy argv apart from the transport and presentation words (`--host`,
`--port`, `--api-key-file`, `--cors-origins`, `--path`, `--ui`, `--no-ui`),
CPU affinity, niceness, and the marked DPM level.

| Field | Both arms |
| --- | --- |
| executable SHA-256 | `510c0420346ffa4f5104d3f2b28117262a0d30b2907dc21c833d38442c3e49af` |
| CPU affinity, niceness | `[0]`, `19` |
| `power_dpm_force_performance_level` | `auto` |
| `pp_dpm_sclk`, `pp_dpm_mclk` marked level | `1: 620Mhz *` and `2: 933Mhz *` on the first legacy arm; `1: 610Mhz *` and `2: 933Mhz *` on the first Python arm; level indices equal |
| KSM `run` | `1` |

The Python arm holds where its median sits at or above 0.90 of the legacy arm's median on the same window. The arms run ABAB inside one window against one machine state, which is what admits a margin of 10%: a difference below about 20% quoted from single arms across sweeps reports queue position rather than a change in the software. A configuration field that differs between arms refuses the verdict outright.

Verdict: **held**.

Order: `legacy python legacy python`.

| Metric | legacy median | python median | ratio | verdict |
| --- | ---: | ---: | ---: | --- |
| `predicted_per_second` | 5.171 | 5.370 | 1.038 | held |
| `prompt_per_second` | 26.915 | 28.136 | 1.045 | held |

| Arm | ordinal | predicted_per_second | prompt_per_second | failure |
| --- | ---: | ---: | ---: | --- |
| legacy | 1 | 5.951 | 29.615 | - |
| python | 1 | 6.096 | 30.723 | - |
| legacy | 2 | 4.391 | 24.215 | - |
| python | 2 | 4.644 | 25.549 | - |

The machine ran at `auto` DPM rather than the campaign's
`manual-gfx1100-fclk933`, on both arms alike, so the absolute rates stand
below the registry's 9.46 tok/s for the checkpoint; the comparison inside
the window is what the canary reads, and the first-ordinal pair sits above
the second on both arms in the same direction. Six earlier windows the same
day ended on the comparison or launch side and each relaunched production:
a flag-shaped argv value argparse read as an option, the loopback web lane
refusing without an image server, the preset naming production-root model
paths, the canary itself wrapped in nice, the appliance reading the previous
run's terminal record as its own, the LAN listener invisible to a
loopback-only pid lookup, and the executable path, preset prefix, UI words,
and live DPM frequency compared as configuration. Each is closed in code or
in the window script rather than recorded as a lesson.
