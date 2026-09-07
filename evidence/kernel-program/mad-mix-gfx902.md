# MAD-mix on gfx902: where the multiplies are, and what the opcode could absorb

`v_mad_mix_f32` is the GFX9 VOP3P-MAI multiply-add that reads each source
either as a 32-bit float or as one 16-bit half of a register, selected per
operand by `op_sel`/`op_sel_hi`, and accumulates in f32. Its whole value on
this part is absorption: a conversion that would otherwise issue as
`v_cvt_f32_f16` disappears into the operand encoding of a multiply-add that
issues anyway. It buys nothing where both factors are already f32, and gfx902
supplies no separate rate for it, so a MAD-mix arm is an instruction-count
argument rather than a throughput-class change.

The question this record answers is which multiplies of the shipped Q4_K
mat-vec formulations MAD-mix could reach. It is answered from retained gfx902
ISA rather than from a re-run: `evidence/raven2-vulkan-kernel-census/e4/`
holds the appliance's own ACO disassembly of the executed Q4_K mat-vec, and
`evidence/q4k-isa-attribution/` holds gfx902 receipts for the mixed-precision
form itself. Neither reading needed a device.

## The measured ISA, and what it is

`e4/e1-isa-e4-20260903T0140Z/isa/031.s`
(SHA-256 `f2496cb4...`) is pipeline 31 of the census+E4 binary's own shader
dump, bound to the executed module `180da20e...` by
`e4/kernel-delta-20260902T2312Z/README.md`. It is the **post-E4 control**: the
formulation `patches/llama-vulkan-q4k-variant-select.patch` names `e4` and
compiles as `Q4K_VARIANT 0`. The row the registry releases today is
`qwen38-4b-distill  e4-scale-licm/4`, which is `Q4K_VARIANT 2`, and no
disassembly of that module is retained in this tree; the served comparison
that promoted it reports the whole shader at 810 VALU falling by 24
(`evidence/raven2-vulkan-kernel-census/q4k-scale-decode/README.md`), so the
released formulation is about 786 VALU. The variant arms edit the scale read
and the superblock loop and leave the `dm` decode line untouched, so every
count below that concerns `dm` carries onto the released module unchanged;
that carry is inference from the patch text and its falsifier is one `lab.sh`
run over the released module.

`isa/009.s` (`893ba0bd...`) carries the `q4k` signature at VGPR 128 and VALU
1154 against 031's 64 and 810. `isa-index.tsv` records `pipeline_name` as `-`
for every row, so 009's role is unidentified and its numbers appear here only
as a second instance of the same shape rather than as the decode kernel's.

`remote/raven2-shader-lab/recount-isa.sh` over 031.s, the fixture-tested
reader:

| mnemonic | 031.s |
| --- | ---: |
| `v_mac_f32` | 152 |
| `v_cvt_f32_f16` | 16 |
| `v_cvt_f32_ubyte0` | 48 |
| `v_mad_mix_f32` | 0 |
| `v_pk_fma_f16` | 0 |
| `v_fma_f32` | 0 |
| `v_mul_lo_u32`, `v_mul_u32_u24`, `v_mad_u32_u24`, `v_mad_i32_i24` | 0 |
| `sdwa_operand_uses` | 16 |

Beside them, by `grep -c` over the same file: 54 `v_mul_f32`, 8 `v_mad_f32`
of which 8 carry a negated first source, 88 `v_add_f32` of which 32 carry a
DPP row modifier, and 6 `v_rcp_f32`.

## 1. Which multiplies exist, and which are terminal

Every product in this kernel is single-precision. The nibble reaches f32 in
one `v_cvt_f32_ubyte`, the activation is already f32, and the only f16 values
in the shader are the superblock `dm` pair, which arrives as
`FLOAT_TYPEV2(data_a[ib0 + i].dm)` and is widened by the 16 `v_cvt_f32_f16`.

The 54 `v_mul_f32` split by first consumer of the destination register, walking
the listing in order and stopping at the first later instruction that reads it:

| first consumer | count | role |
| --- | ---: | --- |
| `v_cvt_u32_f32` | 6 | unsigned integer division lowering: `v_cvt_f32_u32`, `v_rcp_f32`, `v_mul_f32 v, 0x4f7ffffe, v` (031.s:16-18, :24-29, :44-50), the reciprocal-magic sequence for the push-constant divisions |
| `v_mac_f32` | 32 | the head of an accumulation chain, e.g. 031.s:234 opening the chain 031.s:239 and :245 accumulate into |
| `v_mul_f32` | 8 | a running sum rescaled by a scale byte before the next chain, e.g. 031.s:282 over the sum built at :260 |
| `v_mad_f32` | 8 | the same rescale feeding the negated minimum-term accumulate |

**No `v_mul_f32` destination is first read by a `v_add_f32`, in either
retained listing.** That is the decisive fact for this task: ACO left no
unfused multiply-then-add pair in the Q4_K mat-vec, so the premise "MAD-mix
limited to terminal multiplies" has no unfused multiply to attach to. The 48
non-division multiplies are terminal in the sense that matters here -- each is
either a chain head with no addend in existence yet, or a rescale of a value
that is itself an accumulator -- and a chain head is exactly the multiply a
fused form cannot express, whatever its operand widths.

The 8 `v_mad_f32` all negate their first source. VOP2 `v_mac_f32` encodes no
source modifier, so those eight are the minimum-term accumulates and they are
already fused.

The 88 `v_add_f32` are the reduction and the activation group sums the E4
pre-pass hoisted (031.s:200-214 is the group-sum block: pure adds of
activations, with no multiply feeding them).

## 2. Validated against conjecture

Validated by ISA inspection of retained gfx902 disassembly:

- The executed Q4_K mat-vec issues zero `v_mad_mix_f32`, zero `v_pk_fma_f16`,
  and zero `v_fma_f32`. `recount-isa.sh` over `031.s` and `009.s`.
- No `v_mul_f32` result is consumed by a `v_add_f32`; the first consumer of
  each is one of the four roles tabulated above. Both listings.
- All 16 `v_cvt_f32_f16` results are consumed by a `v_mad_f32` (8) or a
  `v_mac_f32` (8). This is the complete MAD-mix-absorbable set in the kernel:
  16 instructions.
- ACO does not select `v_mad_mix_f32` from GLSL that presents both factors as
  `float16_t` with a `float` accumulator. `evidence/q4k-isa-attribution/`
  Table 3 and `fp16-probe-receipts.tsv`: `q4k-mixed-f16-dot` compiles to the
  f32 control's own `isa_sha256` `b26bab68...`, 96 VALU, `v_mad_mix_f32` 0 --
  `receipt-diff.sh`'s `isa_identical`.
- ACO does select `v_pk_fma_f16` from GLSL, and it costs more than it saves
  here: the packed arm replaces 6 `v_mac_f32` and 1 `v_mul_f32` with 3
  `v_pk_fma_f16` and 1 `v_pk_mul_f16` and pays 12 `v_cvt_f16_f32`, 107 VALU
  against 96. Same receipt.

Conjecture, marked as such:

- That the released `e4-scale-licm/4` module carries the same 16
  `v_cvt_f32_f16` and the same absence of `v_mad_mix_f32`. Inferred from the
  variant patch leaving the `dm` line outside every `#if` arm. Falsified or
  confirmed by one `lab.sh` run over the released module on the appliance.
- That the one mat-vec site ACO was never asked about -- one f16 source
  against one f32 source with an f32 addend -- would select the opcode. E7
  presented both factors as f16, which is a different shape. Mechanism M1
  below asks it.
- That absorbing all 16 conversions would move a served rate. The arithmetic
  in section 4 predicts it would not.

## 3. The portfolio against the registry fields that exist

`remote/models.tsv` carries `q4k_variant` per row, closed over `-`,
`production/4`, and `e4`, `e4-scale`, `e4-scale-licm` crossed with `/2`, `/4`,
`/8`. One row releases a formulation today: `qwen38-4b-distill` at
`e4-scale-licm/4`. Every other row reads `-` and serves the production module.

A MAD-mix formulation is a fourth ALGORITHM name in that sealed key rather
than a new field. Its reach is set by which rows dispatch the shader at all:

| class | row | what the key reaches |
| --- | --- | --- |
| 2B, primary | `qwen38-2b-distill` | the Q4_K mat-vec; the scale-decode candidate read unresolved at +5.3% and +5.5% against the +5% bound on this row |
| 4B, quality fallback | `qwen38-4b-distill` | the Q4_K mat-vec; holds the one released key |
| 0.8B, secondary | `qwen35-08b` | nothing. The row serves Q8_0, and `q4k-scale-decode/README.md` records the 0.8B dispatching the Q4_K shader never |

So a per-class MAD-mix portfolio is a two-class portfolio. The 0.8B class's
own multiply lever is the Q8_0 mat-vec, which `evidence/q8-attribution/`
owns and which this key cannot express.

Composition is by row and not by build: every formulation compiles into one
executable and `GGML_VK_Q4K_VARIANT` picks the pipeline, so a portfolio is a
set of registry cells rather than a set of binaries. A fourth name touches, in
order: the `#if` arm and the `_v3` module family in the shader and
`vulkan-shaders-gen.cpp`; the `GGML_ABORT` allowlist in the host selector;
`build-llama-preset.sh`'s `q4k_variants` manifest row, which
`qwen-capacity-policy.sh` and `qwen-build-exec-guard.sh` hold every launched
key against; `build-router-presets.sh` and `build-web-presets.sh`, which write
`LLAMA_ARG_VK_Q4K_VARIANT` per section; `qwen-router-exec-guard.sh`, which
re-derives the key set from the verified preset; and the bundled
`q4k-policy.tsv` that `verify-bundle-preset-ledger.sh` reads, where a release
and its rollback must both verify. A name that reaches the registry without
reaching the manifest row refuses every launch, which is the mechanism that
makes a paper release impossible.

## 4. One mechanism, registered

**M1, the `dm` half-operand absorption.** A candidate `mul_mat_vec_q4_k.comp`
arm holds the superblock `dm` pair as `f16vec2` through to its use and
multiplies it against the f32 group sums with the f32 accumulator unchanged,
which is the one shape `v_mad_mix_f32` expresses and the one shape E7 never
presented. Compiled and read in `remote/raven2-shader-lab/lab.sh` on the
appliance at the pinned constants `--spec 0:64 --spec 1:4 --spec 2:1
--subgroup 64 --bindings 5 --push-constants 52`, against the released
`e4-scale-licm` module as control, read with `recount-isa.sh` and
`receipt-diff.sh`. Cost: one lab pair, no device workload, no lease, no
teardown window.

*Lab falsifier.* `v_mad_mix_f32` at 0 with `v_cvt_f32_f16` still 16, or a
`receipt-diff.sh` verdict of `isa_identical` or `nir_canonicalized`, closes
the MAD-mix family for this kernel: GLSL cannot reach the opcode on this
stack from either operand shape, and the remaining route is a SPIR-V or NIR
post-pass, which is a different program.

*Bracket falsifier, and why no served arm is registered.* The absorbable set
is 16 instructions. Against the released module's approximately 786 VALU that
is 2.0%, and it is an upper bound, since it assumes every conversion
disappears and no `v_mad_mix_f32` costs an extra encoding slot. This family's
own measured conversion from instruction count to served rate is 1.83% served
for an 11.6% body reduction on the 2B, so 2.0% of the whole shader predicts a
served effect near 0.3%. That sits under the one-sided +5% `QWEN_AB_BOUND`
`run-served-binary-ab.sh` promotes against and under the 4% of uncontrolled
spread a repeated depth-0 rate on this machine carries, so a served A/B of M1
alone can only read `unresolved`. **MAD-mix cannot promote standalone, and
that is arithmetic rather than a pending measurement.** A served arm is
registered only where M1 enters a composed candidate whose predicted total
clears the bound, which is the portfolio combination the program's task 55
carries.

*Dependency.* Promotion of any MAD-mix formulation into a `q4k_variant` cell
waits on kernel program task 55. M1 produces a compile receipt and a registry
plan; it releases nothing, and no row's `q4k_variant` moves in this record.

## Tooling: the gfx902 target flag is not run

`lab.sh` gains no `--target` flag here. The workstation enumerates
`nvidia_icd.json` alone under `/usr/share/vulkan/icd.d/` and installs no RADV
ICD, so no gfx902 compile can be produced on it and a flag added here would be
untestable by its own fixture. `hipcc` and `rocminfo` are absent too, so
`remote/rocm10-ladder.sh`'s `--offload-arch=gfx902` route -- an LLVM compile
rather than ACO's, and therefore an answer about a different compiler -- runs
nowhere on this host either.

`lab.sh` already serves an RADV-less host in the two ways that are honest:
`--spirv-only` stops at the disassembly, and `QWEN_SHADER_LAB_REPLAY_DIR`
substitutes a recorded driver log so the readers run. Mesa's
`RADV_FORCE_FAMILY` with the null winsys is the documented route to compiling
for another AMD family offline; it is named here as documented behavior and
is unverified on this host, since it needs the RADV ICD this workstation does
not carry. What measures M1 is `lab.sh` on the appliance's own gfx902 part.

```text
gfx902 ISA of the shipped formulations   measured, retained, read here
gfx902 ISA of a MAD-mix candidate        not run, no candidate shader exists
lab.sh gfx902 target flag                not run, no RADV ICD on the workstation
served effect of M1                      not registered, predicted under the bound
```
