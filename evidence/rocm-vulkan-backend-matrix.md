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

The Vulkan row here differs from the figures the README quotes, 21.49 against
22.00 prefill and 3.10 against 3.02 decode. Two things changed at once and this
run separates neither: the protocol split the phases, and the binary is the
dual-backend build rather than the Vulkan-only one, which is why its backend
column reads `ROCm,Vulkan`. Attributing the 2.5% to phase splitting alone would
overstate what the run shows.

The V row is the correct control for H0 regardless, because H0 came from the
same binary in the same protocol. The README figures stay as the serving
numbers, because serving alternates the phases.

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

## Predictions recorded before the arms run

`GGML_CUDA_FORCE_MMQ` is a compile-time option that routes batched quantized
matrix multiplication through ggml's own kernels instead of dequantize plus
rocBLAS. Decode at batch one goes through `mul_mat_vec_q` in `mmvq.cu` whatever
that option says, because the flag governs a choice the batched path makes.

H1 therefore predicts prefill above 14.06 and decode within noise of 2.22. A
decode figure that moves materially falsifies the reading of what the option
controls, and that deviation is the finding rather than a footnote.

Nothing in H1 or a native `gfx902` arm addresses the decode gap, which is the
number the serving verdict rests on. The candidate there is CPU contention:
`BusyWaitSignal` spins a full core while `-t 2` asks ggml for both of them, so
the HIP arm is oversubscribed on a two-core machine in a way the RADV arm is
not. Re-running H0 decode at `-t 1` against the recorded `-t 2` row tests it,
needs no rebuild, and costs about a minute. If `-t 1` recovers decode, the
deficit is the host wait state rather than kernel quality.

## How a partial result is read

The recorded criterion asks for prefill above 22.00 tok/s or decode above 3.02.
A HIP arm that satisfies the prefill half while decode stays near 2.22 refutes
the arithmetic claim that Vulkan holds the reachable prefill performance, and
leaves the serving default where it is: an appliance answering a chat prompt
spends its time in decode, and a backend that loses there loses the deployment
whatever prefill does. The report names which half moved rather than reporting
the disjunction as satisfied.
