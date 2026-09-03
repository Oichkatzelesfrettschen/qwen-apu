# E4b traffic balance: the pre-pass clears break-even by three orders of magnitude and cannot reach its registered band

The arithmetic balance for a per-token activation group-sum pre-pass is not
close. The duplicated work is 192 additions per superblock per workgroup, the
pre-pass that removes it costs 192 or 248 additions once per superblock per
token, and the smallest activation the 2B's Q4_K mat-vecs share is consumed by
512 output-row workgroups, so the pre-pass clears break-even by a factor of 396
at the worst point and 3072 at the best. The byte term is a rounding error
against the checkpoint's own stream.

The size of the prize is the constraint. `spirv-comparison.md` measures E4's
per-superblock float arithmetic at 124 operations per lane against the control's
160, and the floor under an E4b variant is 16 of the minimum term's remaining 28
for the layout-preserving sideplane and 4 for the reassociated one. E4b's own
return is therefore at most 12 to 24 of E4's 116 shader float operations, 10.3%
to 20.7%, and 2.6% to 5.2% of the 459 SPIR-V instructions the per-superblock
body issues. `decode-decomposition.md` registers E4b at a 35 to 45% fall in the
family's exclusive bracket. That band is unreachable from the minimum term at
either floor, and the deviation is this document's finding.

## What the numbers are read from

The activation is FP32. `vulkan-shaders-gen.cpp` sets `B_TYPE=float` for the
`_f32_f32` variant, and the accepted decode ledger names
`mul_mat_vec_q4_k_f32_f32` at `constants=64,4,1` as the pipeline the appliance
dispatches, 162 calls and 121,232 workgroups per decode graph on the 2B distill
at batch 128, ubatch 32.

`QUANT_K` is 256, so a superblock covers 256 activation elements and 1024 bytes.
A workgroup is one wave64 and its 16-lane cohort tiles one superblock with empty
overlap. The 2B's dimensions come from
`evidence/model-admission/qwen38-distill-tensor-census.txt` -- `embedding_length`
2048, `feed_forward_length` 6144, `head_count` 8, `head_count_kv` 2, `key_length`
256, `ssm.state_size` 128, `ssm.group_count` 16, `ssm.time_step_rank` 16 -- and
the projection shapes from `load_arch_tensors` and `create_tensor_qkv` in
`$HOME/src/llama.cpp-census/src/models/qwen35.cpp` and `src/llama-model.cpp`.
Consumer counts come from the graph builder in the same file.

## Saved per superblock per lane

E4 forms four four-element partials ahead of the row loop at three additions
each, twelve `OpFAdd` per lane per superblock at `NUM_COLS = 1`. Their
addressing is free: after the served specialization is frozen, the private
`by_group_sum` array scalarizes away and `OpAccessChain`, `OpLoad`, `OpStore`,
`OpVariable`, and `OpTypeArray` are equal between the control and E4 modules.
Those twelve additions are recomputed identically in every workgroup that reads
the same activation column, and they are the whole of what E4b removes.

The remaining minimum term is four operations per row -- three `Fma` and one
`FMul` against the four scale-minimum pairs `sc2`, `sc3`, `sc6`, `sc7`, which
are per-row quantities read from the weight block. What the floor under them is
depends on the sideplane's shape, and the two shapes differ by a factor of four.

Under the layout-preserving shape a lane reads its own four partials and must
apply all four itself, because they are its own chunk's contributions and
applying them in that order is what buys byte-identity with E4. The floor is
4 x `NUM_ROWS` = 16 float operations per lane per superblock.

Under the reassociated shape the sideplane holds eight true 32-element group
sums per superblock and four of them belong to a lane's `v_im`, so the eight
lanes sharing that `v_im` can take one group each with half of them masked. The
wave issues one `Fma` per row rather than four and the floor is 4. That is a
data-parallel split rather than predication, so the wave64 issue cost falls with
it. Its cost is selecting one of `sc2`, `sc3`, `sc6`, `sc7` by lane index; every
lane already computes all eight scales for the dot products, so the selection is
a register select chain rather than a reload, and whether that chain costs less
than the three `Fma` it removes is the discriminator. The floor is therefore 4
to 16 and the low end is unproven.

| arm | float ops per lane per superblock | minimum term | sideplane loads |
| --- | ---: | ---: | ---: |
| control | 152 | 64 | 0 |
| E4 | 116 | 28 | 0 |
| E4b, layout-preserving | 104 | 16 | 4 scalars |
| E4b, reassociated | 92 to 104 | 4 to 16 | 1 to 4 scalars |

E4b over E4 is 12 to 24 of 116 float operations, 10.3% to 20.7%, and 12 to 24 of
459 per-superblock SPIR-V instructions, 2.6% to 5.2%. E4 and E4b together are 48
to 60 of 152 float operations, 31.6% to 39.5%, and 48 to 60 of 496 instructions,
9.7% to 12.1%. The registered 35 to 45% band for E4b alone exceeds both ends.

## Added for E4b-A, and the two sideplane shapes it can take

The sideplane's shape decides both its size and whether it registers a new
numerical claim.

**Layout-preserving.** Write the 64 four-element partials per superblock in the
shader's own lane-chunk layout. Each lane reads its own four scalars and the
addition order is exactly E4's, so the result is byte-identical to E4 and needs
no identity measurement. Pre-pass cost 64 x 3 = 192 additions per superblock.
Sideplane 64 floats = 256 bytes per superblock, one quarter of the 1024
activation bytes.

**Reassociated.** Write the eight true 32-element group sums per superblock.
Pre-pass cost 8 x 31 = 248 additions. Sideplane 8 floats = 32 bytes per
superblock, 3.125% of the activation bytes. Summing 32 elements before the scale
is a different association from E4's, so this shape states a new numerical claim
and needs its own token-identity measurement, the way E4 itself did.

The layout-preserving shape leaves 16 float operations per lane per superblock;
the reassociated shape leaves 4 to 16, since its lanes can split the eight true
group sums between them. They differ in traffic, in arithmetic at the low end,
and in what each must prove.

## Reuse factors

`W` is output-row workgroups per activation, `stride_d / NUM_ROWS` with
`NUM_ROWS = 4`. `P` counts the Q4_K mat-vecs sharing one activation; a Q6_K
consumer is excluded because Q6_K carries no per-block minimum and reads no
sideplane. The 2B runs 18 Gated DeltaNet layers at indices where
`(il + 1) % 4 != 0` and 6 full-attention layers.

| layer kind | activation | K | Q4_K consumers | W each | P | W x P |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| Gated DeltaNet | `attn_norm` output | 2048 | `wqkv_gate` {2048, 2048}, `ssm_beta` {2048, 16}, `ssm_alpha` {2048, 16} | 512, 4, 4 | 3 | 520 |
| Gated DeltaNet | gated-norm output | 2048 | `ssm_out` {2048, 2048} | 512 | 1 | 512 |
| full attention | `attn_norm` output | 2048 | `wq` {2048, 4096}, `wk` {2048, 512}, `wv` {2048, 512} | 1024, 128, 128 | 3 | 1280 |
| full attention | attention output | 2048 | `wo` {2048, 2048} | 512 | 1 | 512 |
| both | `attn_post_norm` output | 2048 | `ffn_gate`, `ffn_up` {2048, 6144} | 1536, 1536 | 2 | 3072 |
| both | SwiGLU output | 6144 | `ffn_down` {6144, 2048} | 512 | 1 | 512 |

`wqkv` in a Gated DeltaNet layer and the tied `token_embd` LM head are Q6_K and
contribute nothing. `build_layer_attn` takes the gate as a view of `Qcur_full`
rather than through a separate projection, which is why a full-attention layer
shows three consumers of its normed input and no `attn_gate` matmul.

Token columns are 1. `NUM_COLS` is 1 in the served specialization, so a two-token
verification runs the same pipeline twice rather than widening it, and `C = 2`
doubles the number of activations without changing `W` or `P`.

The minimum over shared activations is `W x P = 512` and the maximum is 3072.

## Break-even

Per superblock, in instructions:

```
precompute cost + sideplane traffic  <  duplicate group-sum cost x W x P
              192 (or 248) additions <  192 additions x (W x P)
```

Break-even sits at `W x P > 1.00` for the layout-preserving shape and
`W x P > 1.29` for the reassociated one. The smallest shared activation in the
2B gives `W x P = 512`, so the right side is 98,304 additions against 192 or 248
on the left: a margin of 512-fold at the worst point and 3072-fold at the FFN
input. Nothing in the 2B's shape puts the balance in doubt, and nothing about
the 4B or the 0.8B would either, since both raise `W` rather than lower it.

In bytes there is no term on the right, because the additions the pre-pass
removes cost no memory. The sideplane is a pure addition to traffic:

| | layout-preserving | reassociated |
| --- | ---: | ---: |
| per superblock, read by each workgroup | 256 B against 1024 B of activation, +25% | 32 B, +3.125% |
| written per token, whole 2B | 258,048 B | 32,256 B |
| share of the 1.263 GB the 2B streams per token | 0.020% | 0.0026% |
| read per token by 121,232 workgroups at K = 2048 | about 248 MB | about 31 MB |
| against the 993 MB of activation those workgroups already read | +25% | +3.125% |

The written figure covers 72 activations at K = 2048 and 18 at K = 6144. The
read figure is re-reads of a working set of 252 KiB or 31.5 KiB, which is
L2-resident either way. Both DRAM shares sit far below the 4% of uncontrolled
spread a depth-0 rate carries on this machine
(`evidence/measurement-state-and-memory-clock.md`), so the byte term is
unmeasurable here and the instruction term decides the variant.

## Which variant the balance favors

**B, producer-fused.** A and B return the same arithmetic at whichever sideplane
shape they carry; they differ only in what producing the sums costs.

**A, a global sideplane written by its own dispatch**, adds about 90 dispatches
per token -- 72 activations at K = 2048 and 18 at K = 6144 -- and reads every
activation once more, about 1.03 MB per token. The dispatch floor is measured
rather than assumed: the accepted decode ledger's smallest elementwise
pipelines median 4.2 us (`softplus_f32`, 18 workgroups per graph) and 4.6 us
(`add_f32_f32_f32_norepeat`, 66 workgroups). Ninety dispatches at 4.2 us is
0.378 ms per token against the family's 35.4 ms per graph (162 calls at a 218.6
us median), so A spends 1.07% of the bracket before it saves anything. Set
against E4b's own ceiling of 2.6% to 5.2% of the per-superblock instruction
body, A concedes between a fifth and two fifths of the prize at the launch
boundary alone.

**B fuses the same computation into the operator that already holds the
activation in registers** -- `rms_norm_mul_f32` for the three normed inputs at
73 calls per graph, the gated norm for the `ssm_out` input, and `swiglu_f32` for
the `ffn_down` input at 24 calls -- so it pays no dispatch, no extra activation
read, and returns the identical arithmetic. It is A with the launch cost removed.

**C, LDS-local**, is refuted before implementation and
`evidence/raven2-vulkan-kernel-census/e4/e4b-c-first-pass.md` carries the
refutation: the 64 lanes of a workgroup read 1024 distinct activation elements
with empty overlap, so a shared brick restages values each lane already holds.
Its amortization factor is 1 where A and B reach 512 to 3072, and it adds 4096
bytes of LDS and one barrier per superblock iteration for nothing.

Between the two sideplane shapes, B should take the layout-preserving one. It
is byte-identical to E4 by construction, so the arm carries no second identity
measurement, and its extra traffic -- 0.020% of the per-token stream, 25% of an
L2-resident activation working set -- is below what this machine can measure.

## Falsifier for that choice

**B requires each producer's workgroup to hold whole four-element lane chunks at
the mat-vec's own partition.** The sums are a function of the activation, but
the layout-preserving shape binds them to `l0 = 4 * (2 * ir + v_in)` and
`y_offset = 64 * v_im + l0`, which is the mat-vec's map and not the producer's.
A producer whose workgroup splits a superblock across workgroups, or whose
output reaches the mat-vec through a view rather than a contiguous buffer,
cannot emit the record and B degenerates to A for that activation with A's
dispatch cost returning. The check runs on the workstation and needs no device:
read the workgroup-to-element map of `rms_norm_mul_f32`, `swiglu_f32`, and the
gated-norm producer in `ggml-vulkan.cpp` and confirm each covers whole 32-element
groups of its output. A producer that does not is the falsifier, and A remains
the fallback for that activation alone.

**The whole E4b program has a second falsifier, and it is already partly met.**
The ceiling above says E4b returns at most 2.6% to 5.2% of the per-superblock
SPIR-V instruction body over E4, and 9.7% to 12.1% together with E4. The
registered band is 35 to 45% of the family's exclusive bracket. Those are
reconcilable only if
the bracket is bound by float issue to a degree the instruction mix denies: the
per-superblock body issues 120 `OpCompositeExtract`, 108 integer unpack
operations, 32 `OpLoad`, and 28 `OpAccessChain` beside its 160 float operations,
and E4b touches none of them. If the ABBA run of E4 on the appliance returns
less than its own 22.5% float-arithmetic reduction predicts, E4b's share shrinks
by the same factor and the registered band is refuted outright rather than
narrowly. The measurement that settles it is E4's own device arm, which is
cheaper than building E4b.

**SPIR-V bounds SPIR-V.** These counts are static SPIR-V instructions, not ACO
instructions. `OpCompositeExtract` and the integer unpack may fold into source
modifiers, and ACO may already hoist what E4 hoists. `RADV_DEBUG=shaders` over
`mul_mat_vec_q4_k_f32_f32` on the appliance is the receipt that converts these
bounds into issue counts; the workstation's ICD is NVIDIA and reports nothing
about RADV.

## Scope cut

The per-tensor type and shape map is derived rather than read, and it is wrong
somewhere. Assigning Q6_K to the 18 Gated DeltaNet `wqkv` projections, 6
`ffn_down` projections, and the tied `token_embd` LM head reproduces the
ledger's dispatch counts, 18 + 6 + 1 = 25 for Q6_K and 18 x 6 + 6 x 6 + 18 = 162
for Q4_K. That agreement is a fit rather than a confirmation: which six layers
carry a Q6_K `ffn_down` was free, and it was chosen to reach 162.

The workgroup totals falsify the assignment. Q4_K derives to 112,272 against a
measured 121,232 and Q6_K to 92,800 against a measured 83,840 -- 8,960 low and
8,960 high, the same magnitude with opposite signs. That is one tensor's worth
of 35,840 output rows sitting in the pipeline the assignment did not put it in,
rather than a row-count error in any single projection. Which tensor it is needs
a per-tensor read of the GGUF, which lives on the appliance, and the question is
recorded rather than closed.

It changes no conclusion here. The break-even clears by 396-fold at the smallest
shared activation, and moving 8,960 workgroups between the two pipelines shifts
`W x P` by under 8% at any point in the table.
