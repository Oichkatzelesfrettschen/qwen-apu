# The ROCm 10 gfx902 ladder

`remote/rocm10-ladder.sh` is the eight-step ladder
`evidence/raven2-vulkan-kernel-census/dpm-authority-design.md` registers under
"ROCm 10 and the gfx902 target: registered as a bounded ladder, not a plan,"
minus its own eighth step. RADV Vulkan stays the serving backend either way:
`evidence/rocm-h0-operational-failure.md` and
`evidence/rocm-vulkan-backend-matrix.md` already show HIP losing the
falsification criterion on prefill and decode alike, and this ladder is a
bounded compiler and runtime check against a current TheRock build, run in an
isolated prefix that never touches the working ROCm 6.4.4 install or
`/opt/rocm`. Its purpose is narrower than a performance claim: it asks whether
a current nightly changes any fact the earlier evidence rests on, and it stops
at the first rung that says no.

## The rungs and their falsifiers

| Rung | What it proves | Falsifier |
| --- | --- | --- |
| `compile` | `hipcc --offload-arch=gfx902` accepts a small mixed-precision kernel (fp16 pairs in, one fp32 accumulator out, the `fp16_dot2_acc_fp32` shape from `hp14-raven2-gpu/evidence/isa/quant-battery.cl`) and, read back through `--save-temps`, the generated ISA either does or does not carry `v_mad_mix_f32`. `hp14-raven2-gpu/docs/raven2-capability-decomposition.md` records that stock clang-19 does not select it here, costing 16 extra `v_cvt_f32_f16` conversions (49 VALU against the 33 a selected instruction would cost) on exactly the fp16-in/fp32-accumulate pattern quantized inference uses most; `hp14-raven2-gpu/evidence/isa/quant-mix-feature-experiment.tsv` shows the omission holds even under an explicit `+mad-mix-insts` target feature and clears only under the foreign `+fma-mix-insts` gfx906 feature, which is a target-feature/pattern-selection gap in LLVM's AMDGPU backend rather than a missing encoding. A rung reporting `v_mad_mix_f32_selected=yes` under the plain `--offload-arch=gfx902` compile falsifies that gap and is the one result worth escalating, because it would mean a current LLVM fixed the selection pattern independent of any RADV work: RADV compiles through ACO, a separate backend, and the ACO integer-dot-product selection improvement referenced in this repository's Vulkan work does not touch clang's AMDGPU instruction-selection DAG at all. A compile refusal (the object step failing outright) fails the rung and stops the ladder before the question is even reached. |
| `enumerate` | The prefix's `rocminfo`, or a HIP runtime device query when the prefix ships no `rocminfo`, names a `gfx902` agent. | Neither route reports `gfx902` in its output, or both are unreachable. |
| `vector-add` | A HIP kernel launch and readback compute `1024` elements correctly, checked against a host computation rather than only against a successful submission. | The kernel launch, synchronization, or readback fails, or any element diverges from the host sum. |
| `wave64-lds` | A shared-memory tree reduction sized to one wavefront (64 lanes) returns the host-computed sum of `0..63` (`2016`). | The kernel fails to launch, or the reduced sum diverges. |
| `device-libraries` | A `-###` dry-run compilation at `--offload-arch=gfx902` (no `gfx900` override) names the device-library bitcode files the compiler resolved for this target, read from the `-mlink-builtin-bitcode` job arguments the dry run prints without running one. | No bitcode path resolves for `gfx902` at all, or resolution silently falls back to a `gfx900` bitcode set under a plain `gfx902` request -- the latter would mean the toolchain is serving a compatibility shim rather than native `gfx902` support, and the dpm-authority design document names this exact failure mode as the reason the rung asks for no override. |
| `blas-call` | One `hipBLAS` SGEMM (a 2x2 identity multiply, checked against the expected product) succeeds against the prefix's own `hipblas.h` and library. | `hipblas.h` is absent from the prefix, `hipblasCreate` or `hipblasSgemm` returns a non-success status, or the computed product diverges. `hp14-raven2-gpu/docs/rocm-gfx902-support.md` records that neither ROCm 6.4.4 nor the newest 7.2 release ships a `gfx900`, `gfx902`, or `gfx909` Tensile logic file for rocBLAS, so this is the rung the ladder is expected to stop at on real hardware; a TheRock nightly that clears it is exactly the falsifier this rung exists to catch. |
| `llama-bench` | A minimal dual-backend `llama-bench` decode row (`-p 0 -n 16`) runs against a real checkpoint through `--device ROCm0`, once every rung above has passed. | The binary or checkpoint path named by `QWEN_ROCM10_LLAMA_BENCH` / `QWEN_ROCM10_MODEL` is absent, the run times out or exits non-zero, or it emits no decode row. Unset either variable and the rung is recorded `skip` rather than `fail`, since the ladder cannot demand an artifact this repository's own build scripts do not own. |

Every rung that touches the HIP runtime -- `enumerate`'s fallback,
`vector-add`, `wave64-lds`, `blas-call`, and `llama-bench` -- runs under
`HSA_ENABLE_SDMA=0`, exported once for the whole script ahead of any rung.
`evidence/rocm-h0-operational-failure.md` records what happens without it:
`llama_model_loader::load_all_data` parks inside `hipEventSynchronize` and
never returns, so a rung run without the variable would measure a hang rather
than the mechanism it names. `remote/test-rocm10-ladder.sh` proves the export
reaches every recorded invocation, including the ones the fabricated binaries
themselves make, rather than only the `hipcc` compiles.

The ladder stops at the first rung whose result reads `fail`. `ladder.tsv`
under the run's `OUTPUT_DIR` carries one row per rung actually attempted --
command, exit status, pass/fail/skip, the artifact the rung proves, and the
path to its full log -- so a rung absent from the file is a rung the ladder
never reached rather than one that silently passed. A rung stopping the
ladder is data, not a script defect: the script itself always exits `0` once
rungs are underway, and the terminal state lives in `ladder.tsv` and in the
final `rocm10_ladder=stopped rung=...` or `rocm10_ladder=complete` line. The
one hard failure that exits non-zero ahead of any rung is a prefix missing
`PREFIX/bin/hipcc`, since running any rung at all against a distribution
install or an ambient `/opt/rocm` would falsely credit ROCm 10 with a result
the working 6.4.4 install produced.

The design document's eighth step -- an ABBA comparison against the
fixed-clock RADV baseline -- is out of this ladder's scope. It belongs after
every rung here has passed on real hardware, and
`remote/run-rocm-vulkan-matrix.sh` already runs the phase-split HIP-against-
Vulkan comparison this repository's HIP evidence rests on; a `llama-bench`
pass here is the precondition that comparison currently never reaches.

## Where a pinned ROCm 10 nightly would come from

`evidence/therock-sdk-manifest.tsv` pins the nightly this repository's
existing HIP evidence used: `rocm_sdk_version 10.1.0a20260825`, HIP
`7.16.26332`, installed into
`$HOME/.venvs/rocm-gfx900/lib/python3.12/site-packages/_rocm_sdk_devel` by
`pip install --index-url <therock-index> "rocm[libraries,devel,device-gfx900]"`
(`remote/build-llama-dual.sh`). `hp14-raven2-gpu/docs/rocm-gfx902-support.md`
and `evidence/raven2-vulkan-kernel-census/dpm-authority-design.md` agree that
TheRock's own build matrix and AMD's ROCm 10 Core SDK release both list
`gfx900` and `gfx906` device packages and omit `gfx902`; the `device-gfx900`
extra in that install command is the closest published family, and the ladder
runs `--offload-arch=gfx902` against it rather than requesting the `gfx900`
extra's own target, because gfx902 is what `rocminfo` reports natively on
this silicon (`hp14-raven2-gpu/docs/rocm-gfx902-support.md`, "gfx902 is
natively supported by the compiler, not overridden") and an override would
discard the `xnack+` (or, under 10.1, `xnack-`) target ID the runtime already
resolves on its own.

This repository does not commit the literal `--index-url` value; every
reference to it, including `remote/build-llama-dual.sh`, carries
`<therock-index>` as a placeholder rather than a resolved URL, because pip
resolves the actual wheel locations from whatever index is passed and the
identity worth pinning is the installed package's own version strings, not
the transport URL that produced them. A future ROCm-10 run of this ladder
should record a `rocm10-sdk-manifest.tsv` shaped like
`evidence/therock-sdk-manifest.tsv` -- `rocm_sdk_version`, the four
`wheel_rocm*` fields including whichever `wheel_rocm_sdk_device_gfx*` extra
was installed, `python_version`, `rocm_path`, `hip_clang_version`,
`hip_version`, `rocminfo_target`, and the kernel and Mesa identity the run
executed under -- plus the `--index-url` value actually used for that
install, since a nightly index is exactly the kind of transport detail this
repository's evidence discipline requires recording rather than assuming
stable. `remote/rocm10-ladder.sh` reads only `PREFIX/bin/hipcc`; it does not
install TheRock and does not resolve or verify an index URL itself.

## This ladder runs last in the device program

RADV Vulkan is the serving backend and nothing else in this repository's
device queue depends on HIP building at all
(`evidence/raven2-vulkan-kernel-census/dpm-authority-design.md`: "RADV
Vulkan stays this repository's primary compute path on this device; nothing
above depends on HIP building"). The ladder here is a falsifier check against
a moving upstream target -- TheRock nightlies -- not a step on the path to
serving HIP, and it competes for the same laptop and the same GPU every
Vulkan campaign in this repository already queues for. It runs after every
higher-priority Vulkan and appliance experiment already registered, on an
isolated prefix, with the working 6.4.4 install and `/opt/rocm` both
untouched, and a `pass` on every rung here changes nothing about the served
default by itself -- it only replaces "untested" with a dated result in the
row `blas-call` (or whichever rung stops it) is expected to occupy.
