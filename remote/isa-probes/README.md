# E2, E2b, and E7: the inner product, its operands, and its type, through ACO

`evidence/raven2-vulkan-kernel-census/decode-decomposition.md` registers E2 as
the second experiment in its ladder: whether ACO, RADV's shader compiler,
selects the full-rate `v_mad_u32_u24` or `v_mad_i32_i24` instruction gfx902
carries for a masked-nibble times int8-activation product, or falls back to
the quarter-rate `v_mul_lo_u32` a general 32-bit multiply takes. The document
derives its 2.6-operations-per-weight estimate for an integer Q4_K kernel from
the GLSL source of that product alone; E2 is what replaces the estimate with
the instruction the compiler actually emits, read from a
`RADV_DEBUG=shaders` disassembly on the appliance's own gfx902 device. A
`v_mul_lo_u32` selection refutes the 2.6 estimate for a GLSL-sourced kernel and
the document's own remedy is NIR range hints through
`GL_EXT_shader_explicit_arithmetic_types_int8` operands or a SPIR-V post-pass,
both measured the same way this probe is.

E2b is the second question the same disassembly answers: whether the packed
byte operands reach that multiply still packed. gfx902 carries SDWA on VOP1
and VOP2, which selects byte 0 to 3 of a 32-bit source at no extra
instruction, and `v_perm_b32`, which lays four arbitrary bytes of two sources
into one dword. A compiler that widens each field to 32 bits at extraction
spends a shift and a mask per value instead, and the two outcomes separate in
a receipt's mechanism counts: `v_lshrrev_b32` and `v_and_b32` rising together
with `sdwa_operand_uses` and `v_perm_b32` at zero is early widening, and byte
selection carried in the operands is the packed path.

## The six files this settles

All six probes share one buffer layout -- a
Q4_K-shaped weight buffer of packed nibbles, an int8 activation buffer packed
four per dword, and a per-workgroup accumulator -- and the same nibble
extraction and workgroup reduction, mirroring
`ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec_q4_k.comp`'s own
`calc_superblock` and `reduce_result` structure over one dword of eight
nibbles per lane. The E2 pair varies the accumulator: `q4k-integer-dot.comp` accumulates the
product in `int` where `q4k-float-dot.comp` converts both operands to float
first and accumulates through `fma`, the way the pinned kernel's
`sx`/`sy`/`sz`/`sw` terms do. The E2b pair varies the operand width alone:
`q4k-packed-u8-dot.comp` holds both nibble planes and the activation vector
in the 8-bit types `GL_EXT_shader_explicit_arithmetic_types_int8` declares,
so `unpack8` produces one `u8vec4` and one `i8vec4` and every component keeps
an 8-bit type until the multiply widens it, where `q4k-widen-early-dot.comp`
extracts each field into its own 32-bit local by shift and mask before any
multiply reads it. The E7 pair varies the arithmetic type against the same
float control, and the section below states it. Holding every other structural
choice fixed across the six files -- workgroup size, dword per lane, buffer
layout, reduction shape -- is what makes a difference in the compiled ISA
attributable to the one dimension each pair varies.

## Compiling the probes

```sh
for probe in q4k-integer-dot q4k-float-dot q4k-packed-u8-dot q4k-widen-early-dot \
             q4k-packed-f16-dot q4k-mixed-f16-dot; do
    glslc --target-env=vulkan1.3 -O -fshader-stage=compute "$probe.comp" -o "$probe.spv"
done
```

All six compiled clean on the workstation with `glslc` from
`shaderc/2026.3` (`glslc --version` reports `1:1.4.357.0`). `--target-env=vulkan1.3` puts the modules at SPIR-V 1.6, which their
`spirv-dis` headers state. `q4k-packed-u8-dot.spv` declares `OpCapability
Int8` beside `Shader` and needs `shaderInt8` enabled at device creation, the
two E7 modules declare `OpCapability Float16` and need `shaderFloat16`, and the
remaining three declare `Shader` alone. `shader-lab.c` walks each module's own
capability list and enables exactly the matching feature bits.
`glslangValidator -V` is the fallback this repository's other build scripts
reach for when `glslc` is absent; it was not needed here because `glslc` is
installed.

## Reading the result on the appliance

A `vulkaninfo`-style device query reports capabilities and creates no shader
module, so it never asks RADV to compile a `.spv`. Creating one compute
pipeline is the whole measurement: RADV compiles SPIR-V to native ISA inside
`vkCreateComputePipelines` and prints the dumps from within that call, before
it returns.

`remote/raven2-shader-lab/lab.sh` is the harness these probes run under. It
creates the pipeline with the specialization constants, binding count, push
constant range, and required subgroup size stated on its command line,
enables exactly the device features the module's own `OpCapability` list
names, and retains `spirv.dis`, `final.nir`, `isa.s`, `stats.tsv`, and a
`receipt.tsv` carrying the three digests beside the instruction-class and
named-mechanism counts. `remote/raven2-shader-lab/README.md` states the layer
ladder and the E1 through E4 protocols with their falsifiers.

```sh
for probe in q4k-integer-dot q4k-float-dot q4k-packed-u8-dot q4k-widen-early-dot \
             q4k-packed-f16-dot q4k-mixed-f16-dot; do
    remote/raven2-shader-lab/lab.sh "remote/isa-probes/$probe.spv" "OUT/$probe" \
        --bindings 3 --subgroup 64
done
remote/raven2-shader-lab/receipt-diff.sh OUT/q4k-float-dot OUT/q4k-integer-dot
remote/raven2-shader-lab/receipt-diff.sh OUT/q4k-widen-early-dot OUT/q4k-packed-u8-dot
remote/raven2-shader-lab/receipt-diff.sh OUT/q4k-float-dot OUT/q4k-mixed-f16-dot
remote/raven2-shader-lab/receipt-diff.sh OUT/q4k-float-dot OUT/q4k-packed-f16-dot
```

`run-probe.c` is the same pipeline creation without the options, kept for a
one-line reading of a single module:

```sh
cc run-probe.c -lvulkan -o run-probe
RADV_DEBUG=shaders,shaderstats ./run-probe q4k-integer-dot.spv 2>integer-dot-isa.log
```

Both harnesses compile on the workstation, whose own Vulkan ICD is the wrong
device: compiling these modules with another vendor's compiler answers a
question about that compiler. A shimmed RAVEN2 node supplies the right one.
`evidence/e4b-summary-producer/radv-raven2-shim-env.sh` runs RADV against
`libamdgpu_noop_drm_shim.so`, so ACO compiles for gfx902 on a host carrying no
AMD part, and `evidence/q4k-isa-attribution/` anchors that route by
reproducing the appliance's retained E4 consumer receipt bit for bit. The E2,
E2b, and E7 pairs therefore run on either machine, and every receipt records
`device_name` and `driver_name` so a reading is made against those two fields
first.

E2 is answered by the `v_mad_u32_u24`, `v_mad_i32_i24`, and `v_mul_lo_u32`
rows of the integer probe's receipt against the float probe's: a `v_mad_*`
selection holds the 2.6-operations-per-weight estimate for a GLSL-sourced
kernel and `v_mul_lo_u32` alone refutes it. E2b is answered by
`sdwa_operand_uses`, `v_perm_b32`, `v_lshrrev_b32`, and `v_and_b32` across
the packed and widening pair: the packed arm matching the widening arm's
shift and mask counts with no byte selects refutes the operand-machinery
route and makes a GLSL-sourced integer kernel unable to reach it.

## E7, the half-precision multiply

`q4k-packed-f16-dot.comp` and `q4k-mixed-f16-dot.comp` take the same control,
`q4k-float-dot.comp`, and vary the arithmetic type where E2 varies the
accumulator and E2b the operand width. The packed arm pairs the eight products
into four `f16vec2` fused multiply-adds and accumulates in `f16vec2`, which is
the form `v_pk_fma_f16` expresses; the mixed arm holds both factors as
`float16_t` and keeps the accumulator `float`, which is the form
`v_mad_mix_f32` expresses. The question is whether the packed half-rate path
`CLAUDE.md` names as a candidate for the Q4_K mat-vec is reachable from GLSL on
gfx902 and what its operands cost.

`evidence/q4k-isa-attribution/` carries the answer: ACO forms three
`v_pk_fma_f16` and one `v_pk_mul_f16` in the packed arm and pays twelve
`v_cvt_f16_f32` to bring the operands into half precision, so the arm issues
107 VALU against the control's 96; the mixed arm compiles to the control's own
`isa_sha256`, `v_mad_mix_f32` at zero, which is `receipt-diff.sh`'s
`isa_identical` verdict.

*Falsifier.* A packed arm at or below the control's VALU count makes the packed
formulation a lever for the mat-vec, and a nonzero `v_mad_mix_f32` in the mixed
arm makes half-precision operands with a single-precision accumulator free.
Both are unmet, so the family is closed at the operand conversion rather than
at the multiply.
