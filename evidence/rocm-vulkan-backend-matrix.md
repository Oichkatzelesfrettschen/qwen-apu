# HIP against Vulkan from one binary, one phase at a time

`build-qwen-dual` carries both backends against llama.cpp `f280b26`, so
`llama-bench --device` selects between them and the rows below differ by the
backend alone. Prompt processing and token generation run as separate
invocations with the unused side set to zero, because a combined run reports one
elapsed time for two mechanisms.

Checkpoint: Qwen3.8-4B Distill Q4_K_M, 2.58 GiB,
`dec96e8cf2e11b613bb46513dec485377f9ca5a351e71712ee0e244f287c6790`.
Full offload, `-ngl 99`, two threads, one repetition, 600 s per phase.

## Rows

| Arm | prefill tok/s | decode tok/s | prefill seconds | decode seconds |
| --- | ---: | ---: | ---: | ---: |
| V, RADV Vulkan | 21.49 | 3.10 | 52 | 26 |
| H0, `gfx900` under override, automatic kernels | 14.06 | 2.22 | 80 | 33 |

HIP reaches 65.4% of the Vulkan prefill rate and 71.6% of its decode rate. The
falsification criterion recorded in `evidence/rocm-feasibility-audit.md` asks
for a HIP row above 22.00 prefill or 3.02 decode on this checkpoint. Both rows
fall below both figures, so the criterion is tested and unmet, and RADV Vulkan
holds the serving backend on measurement rather than on default.

The Vulkan phase-split rows differ slightly from the combined-run figures they
replace, 21.49 against 22.00 prefill and 3.10 against 3.02 decode. Splitting the
phases removes the shared warmup and the alternation between them, which moves
each figure by about 2.5% in opposite directions. The combined figures remain
the ones the README quotes for serving, because serving alternates the phases.

## Every HIP arm requires HSA_ENABLE_SDMA=0

With the copy engine enabled, `llama_model_loader::load_all_data` parks in
`hipEventSynchronize` and never returns; the run above completes in 80 seconds
where the same binary hung for 51 minutes.
`evidence/rocm-h0-operational-failure.md` carries the backtrace, the flat
counters, and the termination.

This narrows what TheRock 10.1 repairs. The runtime returns the correct result
from a small-buffer smoke test where Ubuntu 5.7.1 hangs, and a 2.58 GiB tensor
upload reaches the same wait state on both. The copy engine still requires the
variable on this silicon.

## What the split shows about the mechanism

The deficit is larger on prefill than on decode, 34.6% against 28.4%. Prefill is
the compute-bound half and the half that enters rocBLAS, so a `gfx900` Tensile
solution set tuned for a 64-compute-unit Vega 10 running on two compute units is
consistent with the larger gap.

It does not account for the decode gap. Decode is bandwidth-bound and moves
weights at a rate the backend does not change, so a 28.4% decode deficit points
at per-token overhead outside the matrix multiplications: dispatch frequency,
short-kernel synchronization, and the host wait state that `BusyWaitSignal`
spins in while holding one of this machine's two cores.

Two arms separate those. `GGML_CUDA_FORCE_MMQ` is a compile-time option that
routes quantized matrix multiplication through ggml's own kernels instead of
rocBLAS, which moves prefill if Tensile selection is the prefill term and leaves
decode where it is. A native `gfx902` build without the override tests whether
the impersonation costs anything on top.
