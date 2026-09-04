# image-sdxs-512-a by phase: the denoise and the VAE decode cost the same, and the load is unattributable

```text
harness=remote/run-image-standalone.sh OUTPUT MODEL_PATH, two invocations of two arms each
runtime=$HOME/src/stable-diffusion.cpp-qwen-apu/build-raven2/bin/sd-cli sha256 4eb6d155...
model=$HOME/models/image/sdxs-512, taesd=vae/diffusion_pytorch_model.safetensors
geometry=512x512, steps 1, euler, cfg 1.0, seed 42, the image-sdxs-512-a profile's own values
backend=te=Vulkan0, vae=Vulkan0, diffusion=Vulkan0; the device-refusal control is accepted on every invocation
post-image control=remote/test-strict-vulkan-placement.sh against the deployed llama-server and Qwen3.5-0.8B Q8_0
clock=power_dpm_force_performance_level auto, mclk modal 933 MHz on every arm
```

## The four arms

| arm | text encode s | denoise s | VAE decode s | generate total s | process wall s | pre-generate residual s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| inv 1 cold | 2.31 | 3.93 | 3.72 | 9.98 | 12.430 | 2.450 |
| inv 1 warm | 1.71 | 3.89 | 3.82 | 9.44 | 11.632 | 2.192 |
| inv 2 cold | 1.88 | 3.85 | 3.75 | 9.50 | 11.935 | 2.435 |
| inv 2 warm | 1.84 | 3.92 | 3.92 | 9.70 | 12.456 | 2.756 |

Only the first arm is page-cache cold. The second invocation's `cold` arm reads a model
the first invocation just streamed, so the four arms are one cold observation and three
warm ones rather than two cold-warm pairs, and its text-encode time (1.88 s) sits with
the warm arms rather than with the cold one (2.31 s). Dropping caches needs a `sudo`
timestamp the appliance did not hold, so a second genuinely cold arm did not run.

`residual_encode_overhead_s` is 0.020 s on all four arms: `generate_image` is text
encode, denoise, and VAE decode and 20 ms of everything else.

## What the numbers say

**The single denoising step and the VAE decode cost the same.** At one euler step the
denoise is 3.85 to 3.93 s and the VAE decode is 3.72 to 3.92 s, so the decode is 96 to
100% of the sampler. A distilled one-step checkpoint moves the cost out of the sampler
and into the autoencoder: a second step would add about 3.9 s where the decode stays
fixed, so the decode dominates only at this step count and the profile's `max_steps` of
4 would put the sampler at roughly four times the decode.

**Denoise is the most repeatable phase and text encode the least.** Denoise spans 2.1%
across four arms, VAE decode 5.4%, and text encode 35% -- and the whole of that text
encode spread is the one cold arm, since the three warm arms span 9.9%. The text encoder
is what the page cache moves.

**Every arm produced a byte-identical artifact.** All four PNGs hash to
`a9491c82599937f9dd5320be4642366a35689c4794f450bb772fa298646ce143` at 440,845 bytes, so
this pipeline is deterministic at a fixed seed across cold and warm state and across two
process lifetimes. The four arms are therefore four timings of one computation, which is
what licenses reading their spread as machine noise rather than as sampling variation.

**Zero ring resets and zero GPU faults on every arm**, with the `amdgpu` edge sensor
peaking at 86 to 88 C, VRAM at 2.027 GB of the 2.048 GB carve-out, and GTT at 1.86 GB.
`MemAvailable` never fell below 11.25 GB with the 16.5 GiB QEMU tenant resident.

## The load phase is bounded rather than measured, and sd-cli's own timers say why

`run-image-standalone.sh` hard-codes `wall_load_s=unavailable` because sd-cli logs no
phase-start timestamp for model loading. The residual `shell_wall_s - total_generate_s`
bounds process start, both tensor loads, the PNG write, and exit together at 2.19 to
2.76 s, which is 18 to 22% of the process lifetime. It cannot be split further from these
records, and the reason is that sd-cli's two loader timers do not fit inside it:

| arm | diffusion load s | tae load s | sum | residual s |
| --- | ---: | ---: | ---: | ---: |
| inv 1 cold | 1.81 | 1.41 | 3.22 | 2.450 |
| inv 1 warm | 1.40 | 0.80 | 2.20 | 2.192 |
| inv 2 cold | 1.63 | 1.02 | 2.65 | 2.435 |
| inv 2 warm | 2.01 | 1.00 | 3.01 | 2.756 |

Three of four arms report loader totals exceeding the wall-clock window those loads must
fit inside, by 0.77, 0.22, and 0.25 s, and the fourth leaves 8 ms for process start,
the PNG write, and exit combined. `shell_wall_s` brackets the sd-cli process exactly --
`date +%s.%N` on either side of the `timeout` that runs it -- so the window is right and
the two loader timers overlap each other or over-report. Their own sub-breakdowns agree:
the cold arm's 1.81 s total carries read 0.74, memcpy 0.00, convert 0.50, and
copy_to_backend 0.17, which sum to 1.41 s and leave 0.40 s untimed inside one timer.

The consequence is stated rather than worked around: **load time and artifact publication
time are not separately measured by this harness**, and a claim about either needs a
per-line timestamp reader or an strace-level bracket that this run did not build. What is
measured is their sum, 2.19 to 2.76 s. The PNG write is inside it and is bounded above by
that figure; a 440,845-byte file on this NVMe does not plausibly hold a measurable share
of it, but this run states no number for it.

A third loader call of 0.20 s appears on every arm between the sampler and the decode.
It is inside `vae_s` rather than in the residual, so the VAE decode figures above already
carry it.

## Falsifier outcomes

| observation | reading |
| --- | --- |
| a ring reset or a GPU fault on any arm | not met: zero on all four |
| the artifacts differ across arms | not met: one digest across all four |
| the post-image language control fails | not met: strict Vulkan placement accepted after both invocations |
| the phase timers close against the process wall clock | refuted: three of four arms over-report, so the load split is unmeasured |
| the second invocation's cold arm behaves like the first | not met: it reads a warm page cache and times like a warm arm |

## What did not run

The pinned clock cell `manual-gfx1100-fclk933` was not applied: the DPM write needs a
`sudo` timestamp the appliance did not hold. The machine ran at `auto`, and the retained
`*.gpu-clocks.tsv` show `mclk` at 933 MHz on every sample with `sclk` stepping through
400, 985, 1050, and 1100 MHz inside an arm. That stepping is exactly what the pinned cell
removes, so the 2.1 to 5.4% spread on the two device-bound phases is an upper bound on
this machine's noise at `auto` and a pinned re-run would tighten it.
