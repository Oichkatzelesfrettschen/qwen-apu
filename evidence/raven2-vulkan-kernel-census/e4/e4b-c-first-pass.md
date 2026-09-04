# E4b-C, the shared-workgroup activation brick: refuted before implementation

The candidate rests on a decomposition the shader does not have. In
`mul_mat_vec_q4_k.comp` the output row is a workgroup property and the lanes
partition K, so the workgroup holds no independent row waves to share an
activation between and the lanes of one workgroup read disjoint slices of the
activation column. A shared-memory brick therefore saves zero operations and
zero global loads while adding 4096 bytes of LDS, one barrier per superblock
iteration, and a write-then-read round trip. It is implemented as neither a
patch nor a build, and this record carries the refutation, the op-count table
the campaign asked for, and the arm the redundancy actually lives in.

## The mechanism the shader has

Three statements in the pinned source settle it.

`main()` sets `first_row = NUM_ROWS * (gl_WorkGroupID.x + gl_NumWorkGroups.x *
gl_WorkGroupID.z)`, so the row block is chosen by workgroup identity and every
lane of the workgroup serves the same `NUM_ROWS` rows.

`FLOAT_TYPE temp[NUM_COLS][NUM_ROWS]` is a per-lane accumulator over all
`NUM_ROWS` rows, and `reduce_result` sums `temp[j][n]` across the whole
`BLOCK_SIZE` of lanes into one output element per row. The lane is a partial
over K, not a row.

`compute_outputs()` derives `itid = tid % 16` and `ix = tid / 16`, walks the
superblock loop as `for (i = ix; i < num_blocks_per_row; i += it_size)` with
`it_size = gl_WorkGroupSize.x / 16`, and forms `y_offset = 64 * v_im + l0` from
`itid` alone. The 16 lanes of one `ix` cohort tile one superblock; the cohorts
walk different superblocks.

The served pipeline is `mul_mat_vec_q4_k_f32_f32` at `constants=64,4,1` and
`subgroup=64`, which the accepted I1 decode ledger names. `ggml-vulkan.cpp`
produces it from `rm_kq = 4` on the `AMD_GCN` branch and
`wg_size_subgroup16 = subgroup_size16` for the `DMMV_WG_SIZE_SUBGROUP`
variant, so `BLOCK_SIZE` equals the wave width. One workgroup is one wave64.
The premise of a barrier between row waves has no referent: there is one wave,
and the alternate `DMMV_WG_SIZE_LARGE` variant at `BLOCK_SIZE = 256` gives four
waves that still share one row block and partition K four ways further.

## The check

Enumerating the read set of each lane over one `it` iteration, from the same
expressions the shader uses:

```python
QUANT_K, BLOCK_SIZE = 256, 64
reads = {}
for tid in range(BLOCK_SIZE):
    itid, ix = tid % 16, tid // 16
    il = itid // 4
    ir = itid - 4 * il
    v_im, v_in = il // 2, il % 2
    l0 = 4 * (2 * ir + v_in)
    y_offset = 64 * v_im + l0
    y1 = ix * QUANT_K + y_offset
    s = set()
    for base in (y1, y1 + 32, y1 + 128, y1 + 160):
        s.update(range(base, base + 4))
    reads[tid] = s
```

The 64 lanes read 1024 elements and 1024 distinct elements, so the overlap is
empty, and the union of the 16 lanes with `ix == 0` is exactly
`range(0, 256)`, so that cohort tiles superblock 0 without repetition. A
workgroup touches four superblocks per iteration rather than one, which is a
second sign the one-superblock staging model was drawn from a different
kernel.

Because the overlap is empty, the staged value each lane would read back from
shared memory is the value that lane wrote, and the four group sums each lane
holds are its own 4-element partials. E4b-C changes the producer of nothing.

## Op count per lane per superblock, minimum term only

Counted over the GLSL at the served `NUM_ROWS = 4`, `NUM_COLS = 1`. The
control is the pinned shader's 16-term `smin`, 15 `fma` and one multiply per
row. E4 forms three adds per group ahead of the row loop and leaves three
`fma` and one multiply per row.

| arm | ops per lane per superblock | LDS bytes | barriers per superblock | activation loads per lane per superblock |
| --- | ---: | ---: | ---: | ---: |
| control (pinned) | 64 | 0 | 0 | 16 vec4 |
| E4 (row-local hoist) | 28 | 0 | 0 | 20 vec4 |
| E4b-C (shared brick) | 28 | 4096 | 1 | 4 vec4 plus 4 LDS writes and 4 LDS reads |
| E4b (per-token pre-pass) | 16 plus 4 scalar loads | 0 | 0 | 4 vec4 amortized over `stride_d / NUM_ROWS` workgroups |

The control and E4 rows reproduce the file's `32 -> 20` at `NUM_ROWS = 2`:
control is 16 per row and E4 is 12 per column plus 4 per row. The load counts
are as written in the GLSL, before whatever common-subexpression elimination
NIR and ACO apply; lines 85 to 88 reload the four `vec4` that lines 21 to 24
already loaded, once per row, and no receipt from this device says whether the
compiler already removes them.

The 4096 bytes is `4 superblocks x 256 elements x 4 bytes` for the raw
activation the brick would stage, ahead of the 64 group-sum scalars, and it
sits beside `tmpsh` at `NUM_COLS x NUM_ROWS x BLOCK_SIZE x 4 = 1024` bytes. It
stays under the 64 KiB limit and buys nothing.

## Traffic balance in the campaign's terms

Saved: nothing. The brick removes no global load, since each lane's slice is
read by that lane alone, and no arithmetic, since each lane's four partials are
consumed by that lane alone.

Added: 4096 bytes of LDS per workgroup, one `barrier()` per `it` iteration, and
one LDS store plus one LDS load per staged element.

Reuse, output-row waves per workgroup: one. The row block belongs to the
workgroup, so the reuse factor a shared brick could exploit is exactly 1.0, and
that is the arithmetic reason the balance closes negative.

## Acceptance, as run

1. **Negative control.** Not run, because no dispatch path is edited. The
   control exists to prove that an edited shader reaches the device, and there
   is no edited shader. E4's own control -- doubling `smin` and observing
   divergent tokens -- remains the method for the next arm that edits one.
2. **Token identity.** Not run. A brick that changes no arithmetic passes
   identity by construction, so the result would carry no information about the
   candidate's value.
3. **Op count.** Run, from the source; the table above.

No tree was created at `$HOME/src/llama.cpp-e4b` and no build directory
`build-e4b` exists, since neither would compile a candidate. `$HOME/src/llama.cpp-e4`
is untouched.

## Where the redundancy is, and what it costs to reach

Across workgroups. Each of the `stride_d / NUM_ROWS` row-block workgroups
recomputes the same per-superblock group sums over the same activation column,
which is the half E4 does not reach and which `decode-decomposition.md` already
names as E4b: a per-token pre-pass handing every row four scalars. That is a
separate dispatch and a separate arm.

One numerical constraint decides its shape ahead of any build. The
`by_group_sum` entries E4 forms are 4-element partials in the shader's own
lane-chunk layout, and they become full 32-element group sums only after
`reduce_result` sums the cohort. A pre-pass that writes the 64 partials per
superblock in that same layout preserves the addition order and stays
byte-identical to E4. A pre-pass that writes four full group sums per
superblock reassociates the additions and registers a new numerical claim,
which needs its own identity measurement rather than identity by construction.

## Falsifiers still open for the device

- **ACO ISA receipt.** Whether ACO already hoists the four `vec4` reloads at
  lines 85 to 88 out of the row loop, and whether it already forms E4's group
  sums itself. `RADV_DEBUG=shaders` over `mul_mat_vec_q4_k_f32_f32` on the
  appliance answers both, and the workstation cannot: its ICD is NVIDIA, which
  proves token identity and reports nothing about ACO or RADV.
- **VGPR and waves per SIMD.** E4 adds four live scalars per column across the
  unrolled row loop. P5 records 64 VGPRs and 4 waves per SIMD for the pinned
  kernel, which holds at the edge of the band, so a `RADV_DEBUG=shaderstats`
  reading decides whether E4 costs an occupancy step.
- **Barrier cost on RADV.** Unmeasured here and unneeded for this candidate;
  it becomes a question again for any arm that adds a cross-wave dependence,
  where the `DMMV_WG_SIZE_LARGE` variant at `BLOCK_SIZE = 256` gives four waves
  per workgroup.
- **Whether the operation count orders the family at all.** E4's registered
  prediction is a 10 to 16% fall in the family's exclusive bracket and 5 to 9%
  on the token, read against the hoist's own 8% of the family's issue count;
  the ABBA run on the appliance is what settles whether a minimum-term arm of
  any shape is worth device time ahead of E5.
