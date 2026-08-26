# ROCm Feasibility on the Raven2 APU

An audit of what a ROCm/HIP path would cost and return against the deployed
RADV Vulkan backend. Every machine fact below is read from the running system.

## Machine identity

| Fact | Value | Source |
| --- | --- | --- |
| Distribution | Linux Mint 22.2 "Zara", `UBUNTU_CODENAME=noble` | `/etc/os-release` |
| Kernel | 7.0.0-28-generic | `uname -r` |
| GPU | `1002:15d8` rev `cd`, driver `amdgpu` | `lspci -nnk` |
| ATOM BIOS | `113-RAVEN2-117` | `dmesg` |
| Mesa device string | `AMD Radeon Graphics (RADV RAVEN2)` | `llama-bench` |
| Memory bus | `RAM width 128bits DDR4` | `dmesg` |
| VRAM carveout | 2,048 MiB | `mem_info_vram_total` |
| GTT | 15,723 MiB | `mem_info_gtt_total` |
| `/dev/kfd` | present | `ls -l` |
| Group membership | `video`, `render` | `groups` |

## The ASIC is gfx909, not gfx902

`113-RAVEN2-117` and RADV's `RAVEN2` both name Raven2, whose LLVM AMDGPU target
is `gfx909`. `gfx902` is Raven and Picasso. PCI ID `1002:15d8` covers both
parts, and the revision and the VBIOS string separate them.

That distinction governs native compilation. `--offload-arch=gfx909` produces
code objects for this device; `--offload-arch=gfx902` produces objects for a
different member of the same family, which is the target-feature mismatch that
the AMDGPU backend documentation names as a cause of incorrect execution.

The compatibility identity is unaffected: `gfx900`, `gfx902`, and `gfx909` are
all GCN5, so `HSA_OVERRIDE_GFX_VERSION=9.0.0` remains the right impersonation
for libraries that ship only `gfx900` kernels. The correct split is native
`gfx909` for code compiled here, `gfx900` impersonation for precompiled
libraries, and the two kept apart per process.

## Memory is already dual-channel

The kernel reports a 128-bit DDR4 bus, which is two 64-bit channels and a
nominal 38.4 GB/s at DDR4-2400. A second DIMM therefore adds nothing.

Measured sequential host read bandwidth reaches 7.97 GB/s on one CPU thread and
15.44 GB/s on two, or 40% of nominal, which is where two Zen+ cores at 2.3 GHz
saturate. Decode moves weights at roughly 7.8 GB/s, so the two compute units
reach the single-thread figure.

## Every prerequisite for the Ubuntu route is already satisfied

The inbox `amdgpu` driver is active, `/dev/kfd` and `/dev/dri/renderD128`
exist, and the user holds `video` and `render`. Ubuntu Noble's `universe`
component carries the whole stack with no third-party repository:

| Package | Candidate |
| --- | --- |
| `rocminfo` | 5.7.1-3build1 |
| `hipcc` | 5.7.1-3 |
| `libamdhip64-5` | 5.7.1-3 |
| `librocblas0` | 5.5.1+dfsg-5 |
| `libhipblas0` | 5.5.1-4 |

`ggml/src/ggml-hip/CMakeLists.txt` requires `hip`, `hipblas`, and `rocblas`,
and all three are present at those versions.

Listing the package contents without installing confirms the device kernels it
carries:

```text
TensileLibrary_gfx803.co   TensileLibrary_gfx900.co   TensileLibrary_gfx906.co
TensileLibrary_gfx908.co   TensileLibrary_gfx90a.co   TensileLibrary_gfx1030.co
TensileLibrary_gfx1100.co  TensileLibrary_gfx1101.co  TensileLibrary_gfx1102.co
```

`gfx900` is present and `gfx909` is absent, which is exactly the condition the
`HSA_OVERRIDE_GFX_VERSION=9.0.0` impersonation addresses.

## The arithmetic bounds what ROCm can return

Nominal FP32 throughput for this GPU:

```text
2 CU x 64 lanes x 2 FLOP/FMA x 1.1 GHz = 281.6 GFLOP/s
```

Prefill is the compute-bound half of inference. `llama-bench` measures 21.2
prompt tok/s on Qwen3.5-4B, so 512 tokens take 24.2 s. Prefill arithmetic is
about `2 x 4.21e9 x 512 = 4.31 TFLOP`, giving:

```text
4.31e12 / 24.2 = 178 GFLOP/s = 63% of nominal FP32 peak
```

The Vulkan backend is already inside a factor of 1.6 of the arithmetic ceiling.
A flawless rocBLAS path is bounded above by that same factor, and `gfx900`
Tensile solutions are tuned for a 64-compute-unit Vega 10, not for two compute
units sharing DDR4 with a desktop.

Decode is the bandwidth-bound half, and ROCm changes no memory bandwidth. The
expected decode return is zero.

Combining both halves: the reachable upside is a fraction of prefill and
nothing on decode, against an unsupported stack, an ISA impersonation, rocBLAS
5.5.1 under a current llama.cpp, and a reported history of this exact 3050U
being enumerated as an 11-compute-unit device followed by application freezes.

## Verdict

RADV Vulkan remains the serving backend. ROCm is a research lane.

The audit found nothing that blocks an experiment, and the prerequisites cost
nothing because they are already met. The experiment is worth running for its
own sake, and its result is decided by one number rather than by argument.

Falsification criterion, stated before the run: a HIP build of `llama-bench`
that measures prefill above 22.0 tok/s or decode above 3.02 tok/s on the same
checkpoint refutes this verdict. Anything at or below those figures confirms
that the Vulkan backend already holds the reachable performance and that the
ROCm stack buys risk alone.

The sequence, in order of what each step falsifies:

1. `sudo apt install rocminfo hipcc libamdhip64-dev librocblas-dev libhipblas-dev`
2. `rocminfo | grep -oE 'gfx[0-9a-z]+'` -- confirms the target this audit
   derives as `gfx909`, and confirms 2 compute units. An 11-compute-unit
   report stops the experiment.
3. A native HIP smoke test at `--offload-arch=gfx909`, which establishes that
   KFD, ROCr, the HIP runtime, queue creation, dispatch, and memory copy all
   function before any library is involved.
4. `cmake -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx900` and
   `HSA_OVERRIDE_GFX_VERSION=9.0.0 llama-bench`, against the Vulkan figures
   above.

Steps 1 through 3 need the user's sudo password, which stays in the
`qwen-admin` tmux session on the laptop.

## What the audit corrects in the proposed plan

The plan's Route 1 package selection, the inbox-driver requirement, the
per-process override discipline, the rejection of PPAs, and the conclusion that
Vulkan is the better llama.cpp path all hold against the machine.

Three inputs differ. The distribution is Mint 22.2 "Zara" rather than 22.3
"Zena", which changes nothing because both carry the `noble` base. The device
is `gfx909` rather than `gfx902`, which changes every native `--offload-arch`
in the plan. The memory bus is already 128-bit, which removes a dual-channel
upgrade from consideration and fixes the nominal ceiling at 38.4 GB/s.

The plan's TheRock route stays secondary for the reason it gives: `gfx900` is
build-passing rather than sanity-tested there, and `gfx909` is absent from the
public device targets, so the newer stack impersonates the same way the older
one does while adding an unstable toolchain. RustiCL remains the OpenCL answer
and supplies no rocBLAS, MIOpen, or HIP.
