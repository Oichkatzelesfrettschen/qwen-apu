# Filled depth to 32768 on the shipped geometry

`remote/probe-depth-wedge.sh` fills a context to a requested depth with
`llama-bench -d`, decodes 32 tokens there, and then decodes a 16-token control
at the shipped geometry, so one arm claims that the cache at that depth both
allocates and executes and that the device answers afterwards. This campaign
runs that arm at 8192, 16384, and 32768 tokens on the five checkpoints the web
policy ledger names, all under the production cache triple and submission
geometry, and every arm passes. The registry therefore reads a validated
filled depth of 32768 for each of them and their ceilings move to the measured
depth.

## Terms

```text
runner:      remote/probe-depth-wedge.sh, sha256 027c4962...6b0a
chain:       run-chain.sh, sha256 5aa15195...f432 (waits on the previous probe PID)
bench:       llama-bench, sha256 51e17400...9c4e7, -ngl 99 -t 2 -r 1 -p 0 -n 32
tuple:       q8_0 K, q4_0 V, Flash Attention on, batch 128, ubatch 32
kernel:      7.0.0-28-generic
device:      RADV RAVEN2, whole device, appliance torn down for the campaign
rescue:      32:8, conditional, runs only after a 128:32 failure at that depth
health:      status 0, ring resets 0, GPU faults 0, control status 0
```

`campaign-identity.txt` in the 4B directory carries every hash in full. The
runner hardcodes two ggml threads where the deployed server runs one; the
tuple ledger records `threads 2` so the claim names the arm that ran.

## Falsification registered before the arms ran

The 4B distill wedged the compute ring at 16384 under 2048/512 and completed
at 128/32, which is why 128/32 is the production geometry. The prediction was
that 128/32 holds to 32768 on the 4B; a wedge, a reset, a fault, or a failed
control at any depth would have lowered the production tuple to the deepest
validated point until a 32/8 rescue passed, and a rescue pass would have
entered the ledger as a separate reduced-geometry tuple rather than replacing
the shipped one. For the four compact checkpoints, the registry carried `-`
and a ceiling of 8192, so any pass raised a claim from unmeasured to measured
and any failure bounded the ceiling.

## Results

Every arm passes health. `wall` is the whole arm in seconds; `decode` is the
32-token rate at depth; `control` is the 16-token rate afterwards at depth 0.

| checkpoint | depth | wall s | decode tok/s | VRAM peak MiB | control tok/s | temp C |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-4B distill Q4_K_M | 24576 | 2774 | 2.12 | 2015 | 3.33 | 85 |
| | 32768 | 3404 | 1.87 | 1958 | 3.34 | 87 |
| Qwen3.8-2B distill Q4_K_M | 8192 | 197 | 7.85 | 1594 | 9.59 | 86 |
| | 16384 | 456 | 7.10 | 1633 | 9.70 | 85 |
| | 32768 | 1175 | 5.62 | 1738 | 9.63 | 87 |
| Qwen3.5-2B Q4_K_M | 8192 | 200 | 7.57 | 1659 | 9.54 | 82 |
| | 16384 | 461 | 6.94 | 1698 | 9.61 | 86 |
| | 32768 | 1186 | 5.60 | 1776 | 9.58 | 87 |
| LFM2.5-VL-1.6B Q4_K_M, text only | 8192 | 146 | 13.27 | 1051 | 15.16 | 82 |
| | 16384 | 363 | 11.93 | 1090 | 15.76 | 84 |
| | 32768 | 1019 | 9.86 | 1168 | 15.48 | 86 |
| Qwen3.5-0.8B Q8_0 | 8192 | 99 | 13.45 | 1162 | 18.84 | 87 |
| | 16384 | 258 | 11.02 | 1253 | 17.73 | 85 |
| | 32768 | 784 | 7.96 | 1320 | 17.55 | 88 |

The 4B's 16384 arm is the retained one in
`evidence/depth-versus-submission-geometry.md`; the campaign started it at
24576 because that was the shipped allocation with the open gap.

Every kernel window is free of amdgpu lines: the 4B 32768 window holds nine
lines of cupsd AppArmor and `userif` link events and the other thirteen
windows are empty. The conditional rule therefore never selected a 32/8 arm.
`mclk` reads 933 in every arm except the 4B at 24576, which selected 1067,
consistent with the dynamic fabric-clock reading in `CLAUDE.md`.

## What the rows establish

A context of 32768 tokens allocates, fills, and decodes on every one of the
five checkpoints at the geometry the appliance serves, on one device, in one
session, with the device answering its control afterwards. The registry now
reads 32768 in `validated_filled_depth` for all five, the four compact
ceilings rise from 8192 to 32768, and `remote/validated-tuples.tsv` carries
the fourteen arms plus the retained 16384 pair. Each `context_default` stays
where it was, because the default is a serving choice and this file measures
capability.

The depth-versus-rate slope is the second reading. Decode at 32768 against
8192 falls to 72% on the 2B distill, 74% on Qwen3.5-2B, 74% on LFM, and 59%
on the 0.8B Q8_0; the 4B reaches 32768 at 1.87 tok/s against a 3.34 control.
A serving profile that requests 32K on the 0.8B pays 41% of its depth-0 rate
for it, which is a policy fact for the web ledger rather than a health fact.

## What the rows leave open

The claim is total context. A profile that offers 32K of source material plus
an answer needs a larger configured allocation, such as 40960, which is a
later arm. LFM2.5-VL ran without its projector, so `projector_state` reads
`none` in its tuple rows and a vision-plus-web profile at depth waits on a
combined arm. The runner ran two threads where the server runs one; a single
confirmation at one thread on the deepest passing arm is the remaining step
before that difference is retired. The 0.8B rung beyond the served Q8_0 --
the Opus reasoning distill, Zero-Coder V2, the bartowski Q4_K_M, and the F16 --
runs in a second chain and its section follows.

Records live under `evidence/depth-validation-32k/<model-id>/`: bench log,
clock series, kernel window, control log per arm, `wedge-summary.tsv`,
`wedge-metadata.tsv`, and the driver log.
