# E4b-A, the global sum4 sideplane: implemented, byte-identical, reuse measured at 1.93

The candidate holds on the workstation's Vulkan device. One pre-pass writes the Q4_K
activation group sums that every output-row workgroup of every projection consuming that
activation reads, the 64-token greedy output is byte-identical to E4 on the 2B Q4_K_M and
the 4B i1-Q5_K_M, and a poisoned pre-pass diverges under the flag while the same binary
reproduces E4 with the flag clear. The reuse the graph actually offers is 1.93 consumer
dispatches per pre-pass over the whole graph and 2.63 over the pre-passes that serve more
than one consumer, not the 23.1 an address-keyed cache reported before the key was
corrected, and that correction is the run's first finding: keying the sideplane by
`(buffer, offset)` is a correctness bug, not a tuning choice.

`patches/llama-vulkan-q4k-activation-sideplane.patch` carries the change and stacks on
`patches/llama-vulkan-q4k-activation-group-sums.patch` (E4). Its `mul_mat_vec_q4_k.comp`
preimage is the E4 result at blob `48778a3e8`, and it takes a `candidate` row in
`remote/llama-patch-series.tsv` after E4's, so `prepare-llama-census-source.sh` applies
E4 then this one and `verify-llama-patch-series.sh` replays both in ledger order. E4's own
form survives verbatim as the `Q4K_SIDEPLANE`-clear branch, which is what makes a
flag-clear arm equal to the E4 control. The sideplane patch names no
`mul_mat_vec_q5_k.comp` hunk, so E4's Q5_K hoist is E4's alone under either selection.
Its SHA-256 is
`234a41deddbdf7b1e50d86de15ea21e90f16a175d536977431de0100499c442f`.
The runs on this page were made against the earlier pristine-preimage form of the same
change; the mechanism, the key, and the shaders are the ones the stacked patch carries.
`evidence/e4b-summary-producer/` carries the gfx902 ISA receipts and the appliance arm
order.

## The mechanism

`mul_mat_vec_q4_k.comp` forms four activation partial sums per lane per 256-element
superblock, and the 16 lanes of one cohort tile that superblock's 256 elements exactly, so
one superblock and token column carries 64 four-element sums. E4 forms them once per column
inside each workgroup; each of the `stride_d / NUM_ROWS` row-block workgroups of each
projection consuming that activation forms the same 64 again.

`mul_mat_vec_q4_k_prepass.comp` writes them once. The sideplane element type is the
mat-vec's own activation type on this path, f32, because the served pipeline is
`mul_mat_vec_q4_k_f32_f32` whose `B_TYPE` is `float` and whose `FLOAT_TYPE` is `float`
from the generator's `base_dict`. Four f32 activation elements produce one f32 sum, so the
sideplane costs **4 bytes per sum, K bytes per token column per K**, one quarter of the
column's own 4K bytes.

Bit-exactness is by construction over one relation rather than by tolerance. The pre-pass
writes the same four left-associated chains the consumer's `by_group_sum` lines write, cast
the same way, and a stored f32 reloaded is the value the consumer would have built in
registers. The layout agrees because the two shaders are inverses rather than two
permutations that happen to match: the consumer computes
`SIDEPLANE_CHUNK(y_offset) = 8*v_im + 2*ir + v_in` from the `y_offset` it already has, and
the pre-pass walks `chunk` directly and inverts it as
`y_offset = 64*(chunk/8) + 4*(chunk%8)`. A first draft indexed the write by `itid` and the
read by `y_offset`; both are bijections of the lane and they are different permutations, so
the two disagreed on 14 of 16 chunks. The check that settles it, over the shader's own
expressions:

```python
chunks = set()
for chunk in range(16):
    y = 64 * (chunk // 8) + 4 * (chunk % 8)
    assert (y >> 6) * 8 + ((y & 63) >> 2) == chunk
    for base in (y, y + 32, y + 128, y + 160):
        chunks.update(range(base, base + 4))
assert len(chunks) == 256 and min(chunks) == 0 and max(chunks) == 255
```

`Q4K_SIDEPLANE` selects the reading branch, so one source builds the E4 variant and the
E4b-A variant, and the served pipeline keeps its specialization constants 0:64 1:4 2:1.
Scope is the Q4_K dequantize-then-dot mat-vec with an f32 contiguous activation, outside
`MUL_MAT_ID`, outside q8_1 quantization, and outside the 64-bit indexing substitution.
Every other tuple keeps the pipeline it already had, and the Q5_K and Q6_K kernels are
untouched.

## The key

The invalidation key is the activation tensor, its buffer, its offset, K, the token column
count, and a graph epoch. It names no layer and no token number: two mat-vecs share a
pre-pass exactly when they read the same activation tensor at the same K and column count
inside one graph.

The tensor rather than its address is the identity. ggml's graph allocator hands one buffer
offset to many tensors in turn, and the log of the address-keyed first draft shows the
collision directly on a 2B decode graph: `attn_norm-1`, `final_output-1`,
`attn_post_norm-1`, and `attn_norm-3` all live at offset 0 of one buffer. That key reported
7 distinct activations where the graph holds 84, folded 162 consumers onto 60 pre-passes,
and produced fluent nonsense from a greedy decode. The offset-keyed reuse figure of 23.1
was an artifact of reading a superseded activation's sums as current.

The two size fields read alike in the struct and are not equally exercised. `k` takes 2048
and 6144 across the measured graph and discriminates there; `columns` reads 1 on every arm
of this run, because a decode graph carries one token column, so that field is correct and
untested and no claim here rests on it.

The sideplane holds one activation at a time. A consumer whose key differs from the
resident one pays a fresh pre-pass between two full memory barriers: one before the write,
for the readers of the sums it overwrites, and one after, for the consumer that reads them.
That one-slot policy is a lower bound on what a multi-slot arena could capture, and the log
reports both figures so the gap is measured.

## The commands, as run

```sh
# E4 control: $HOME/src/llama.cpp-e4 at 18b5adbfe with the E4 patch, build-e4.
# E4b-A: $HOME/src/llama.cpp-e4b, a worktree of that repository at the same commit,
# carrying the sideplane patch, whose Q4K_SIDEPLANE-clear branch is E4's own form,
# build-e4b. Both configured
# -DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DGGML_NATIVE=OFF -DLLAMA_CURL=OFF.

arm() {   # arm BINDIR MODEL OUT
    GGML_VK_DISABLE_MMVQ=1 ${QWEN_ENV:-} "$1/llama-completion" \
        -m "$2" -ngl 99 \
        -p "Explain in one paragraph why memory bandwidth limits decode." \
        -n 64 --top-k 1 --temp 0 --seed 1 \
        -c 512 -b 512 -ub 512 -t 4 \
        --no-warmup --simple-io -no-cnv > "$3"
}

M2B=$HOME/models/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf
M4B=$HOME/models/Qwen3.8-4B-Distill-Q5_K_M-GGUF/Qwen3.8-4B-i1-Q5_K_M.gguf

arm $HOME/src/llama.cpp-e4/build-e4   $M2B  e4-2b.txt
arm $HOME/src/llama.cpp-e4/build-e4   $M4B  e4-4b.txt
arm $HOME/src/llama.cpp-e4b/build-e4b $M2B  e4b-off-2b.txt
QWEN_ENV=GGML_VK_Q4K_SIDEPLANE=1 arm $HOME/src/llama.cpp-e4b/build-e4b $M2B e4b-on-2b.txt

# The reuse log, one decode graph of the 2B.
GGML_VK_Q4K_SIDEPLANE=1 GGML_VK_Q4K_SIDEPLANE_LOG=1 GGML_VK_DISABLE_MMVQ=1 \
    $HOME/src/llama.cpp-e4b/build-e4b/bin/llama-completion -m $M2B -ngl 99 \
    -p "Explain in one paragraph why memory bandwidth limits decode." -n 4 \
    --top-k 1 --temp 0 --seed 1 -c 512 -b 512 -ub 512 -t 4 \
    --no-warmup --simple-io -no-cnv 2> sideplane-log.txt
```

`GGML_VK_DISABLE_MMVQ=1` forces the dequantize-then-dot family Raven2 executes, because
RADV reports every integer-dot acceleration bit false and llama.cpp builds no `_q8_1`
pipeline there. The workstation's ICD is NVIDIA, so these runs prove token identity and
dispatch structure and report nothing about ACO or RADV.

## Identity

| arm | model | SHA-256 of the 64-token greedy output |
| --- | --- | --- |
| E4, build-e4 | 2B Q4_K_M | `0851ccf4...c704a` |
| E4b-A, flag clear | 2B Q4_K_M | `0851ccf4...c704a` |
| E4b-A, `GGML_VK_Q4K_SIDEPLANE=1` | 2B Q4_K_M | `0851ccf4...c704a` |
| E4, build-e4 | 4B i1-Q5_K_M | `fbb246a7...3b979` |
| E4b-A, flag clear | 4B i1-Q5_K_M | `fbb246a7...3b979` |
| E4b-A, `GGML_VK_Q4K_SIDEPLANE=1` | 4B i1-Q5_K_M | `fbb246a7...3b979` |

The 2B arm is the identity measurement. The 4B i1-Q5_K_M arm is a scope control rather than
a second identity measurement: `remote/gguf-tensor-census.py` reads that file as 65.76%
Q5_K and 33.77% Q6_K by byte and **no Q4_K at all**, so the feature declines on every one of
its mat-vecs and the arm proves that the Q5_K and Q6_K paths and the decline itself leave
the token stream where E4 put it. A Q4_K identity claim rests on the 2B row alone. The
Q5_K hoist itself is a property of each tree rather than of the sideplane patch, which
names no `mul_mat_vec_q5_k.comp` hunk, so the 4B row states that the two trees agree on
that model, and the Q5_K form each tree carried is read from its preparation rather than
from this row.

The flag-clear rows are the control arm the same binary serves. They also close the
question the three extra SPIR-V modules raise, since the sideplane pipelines are created at
load time whether or not the flag is set.

## Negative control

The control has to prove the sideplane binding is the source, which a doubled `smin` in the
consumer does not: that diverges whether the value arrived from the sideplane or from a
locally recomputed sum. The poison goes in the producer instead. One temporary line in
`mul_mat_vec_q4_k_prepass.comp`, applied after the clean identity run and reverted after
this one:

```diff
-    sums.x = float(by10.x)  + float(by10.y)  + float(by10.z)  + float(by10.w);
+    sums.x = float(by10.x)  + float(by10.y)  + float(by10.z)  + float(by10.w) + 1.0;
```

| arm | SHA-256 | verdict |
| --- | --- | --- |
| poisoned pre-pass, `GGML_VK_Q4K_SIDEPLANE=1` | `29432319...9b892` | diverges at the first generated token; the reply degenerates to a repeated token |
| poisoned pre-pass, flag clear | `0851ccf4...c704a` | equals the E4 control, so the poison reaches nothing but the sideplane |
| reverted, `GGML_VK_Q4K_SIDEPLANE=1` | `0851ccf4...c704a` | the revert is proven, not asserted |

The consumer reads the sideplane. The identity result and the reuse table are therefore
about the sideplane rather than about a dispatch that never happened.

## Reuse, from the running graph

One decode graph of the 2B distill, 1374 nodes, 24 layers, one token column:

```text
distinct_keys=84  prepass_dispatches=84  consumer_dispatches=162
hits=78  misses=84  achieved_reuse=1.93  offered_reuse=1.93
```

| activation | K | consumers per key | keys | consumer dispatches |
| --- | ---: | ---: | ---: | ---: |
| `attn_norm` | 2048 | 4 | 8 | 32 |
| `attn_norm` | 2048 | 3 | 14 | 42 |
| `attn_norm` | 2048 | 2 | 2 | 4 |
| `attn_post_norm` | 2048 | 2 | 24 | 48 |
| `attn_gated` | 2048 | 1 | 6 | 6 |
| `final_output` | 2048 | 1 | 18 | 18 |
| `ffn_swiglu` | 6144 | 1 | 12 | 12 |
| total | | | 84 | 162 |

Three facts come out of that table.

The FFN gate and up pair shares one pre-pass, and it does so in every layer: 24 keys named
`attn_post_norm` at 2 consumers each, which is 24 of the 2B's 24 layers. The attention
projections share one too, at 3 or 4 consumers per key across all 24 `attn_norm` keys.
Those two classes carry 126 of the 162 consumer dispatches against 48 of the 84 pre-passes.

The single-consumer classes are the other 36 dispatches and 36 pre-passes, and they buy
nothing. `ffn_swiglu` at K=6144 is the FFN down projection, whose activation no second
Q4_K mat-vec reads, and `attn_gated` and `final_output` are the same shape of dead end.
The pre-pass runs for them and its sums are read once, so **43% of the pre-passes on this
graph are pure added cost**, and the whole-graph reuse of 1.93 averages them in at 1.0.
The projection reuse over the classes that share is 126 consumers against 48 pre-passes,
2.63. That is a measured property of this implementation rather than an open question:
declining the feature where the graph offers one consumer needs the consumer count before
the recording pass, which one forward walk over the graph's Q4_K mat-vec nodes supplies,
and this implementation performs no such walk. The scope cut is named rather than made
silently; what the device decides is whether removing those 36 dispatches recovers
measurable time.

`prepass_dispatches` equals `distinct_keys`, 84 against 84, and that equality is the
finding: no key was ever evicted and re-primed, so the one-slot cache captured every
sharing opportunity the graph offered. It holds because each activation's consumers are
adjacent in the node order. A multi-slot arena would buy nothing on this graph and its
complexity is unearned. The `achieved_reuse` and `offered_reuse` figures the log prints
divide 162 by `prepass_dispatches` and by `distinct_keys` respectively, so on this graph
they are the same quotient by construction; the equality of their two denominators is what
carries the information.

The 12 `ffn_swiglu` keys against 24 layers, and the 18 `final_output` plus 6 `attn_gated`
against 24, say what the Q4_K_M recipe does with layer position rather than anything about
the sideplane: half the FFN down projections are Q6_K and take no part.

## Operations and traffic per lane per superblock, minimum term only

Counted over the GLSL at the served `NUM_ROWS = 4`, `NUM_COLS = 1`, `BLOCK_SIZE = 64`. The
minimum term is the only stage any of these three arms touches; the weight dot and its 16
`vec4` activation loads are the same in all of them.

| arm | operations per lane per superblock | activation `vec4` loads for the minimum term | sideplane `vec4` loads |
| --- | ---: | ---: | ---: |
| control, the pinned shader | 64 (15 `fma` + 1 multiply, times 4 rows) | 0 extra, shared with the weight dot | 0 |
| E4, the row-local hoist | 28 (12 adds per column + 4 per row) | 4 | 0 |
| E4b-A consumer | 16 (3 `fma` + 1 multiply, times 4 rows) | 0 | 1 |
| E4b-A pre-pass, per lane chunk | 12 adds, once | 4 | 1 store |

Against E4 the consumer drops 12 adds per lane per superblock; against the pinned shader
it drops 48 of 64 operations and adds one `vec4` load.

The load column is a GLSL count and the ISA refutes its reading.
`evidence/e4b-summary-producer/` measures VMEM rising 56 to 58 across the consumer pair on
gfx902, because the row loop re-reads `by10`, `by132`, `by20`, and `by232` for the weight
dot at `sx` through `sw`; ACO already shares those loads between the two uses, so removing
the group-sum loop removes no load and the sideplane read is additive. The whole consumer
delta there is 13 of 810 VALU, 24 `v_add_f32_e32` removed against 11 address instructions
returned.

Traffic, per token column of K f32 elements and per mat-vec of an `M x K` Q4_K matrix.
A Q4_K superblock is 144 bytes per 256 weights, so the weight stream is `0.5625 * M * K`
bytes. Each consumer workgroup covers `NUM_ROWS = 4` output rows and reads the whole
column's sideplane, `64 lanes x K/1024 iterations x 16 bytes = K` bytes, and there are
`M/4` such workgroups.

| quantity | expression | 2B, K = 2048, M = 2048 |
| --- | --- | ---: |
| sideplane bytes written, per pre-pass | `K` | 2048 |
| sideplane bytes read, per mat-vec | `(M/4) x K` | 1048576 |
| weight bytes streamed, per mat-vec | `0.5625 x M x K` | 2359296 |
| sideplane read against weight bytes | `0.25 / 0.5625` | 44.4% |
| sideplane write against weight bytes | `4 / (0.5625 x M)` | 0.087% |
| E4's group-sum activation re-reads, per mat-vec | `(M/4) x 4K` | 4194304 |
| sideplane read against those re-reads | `1 / 4` | 25% |

The two rows that matter are on different sides of the cache, and a single traffic number
would mislead in both directions.

In DRAM the sideplane is free. A column's sums are K bytes, 2 KiB at K = 2048, against a 1
MiB L2 and a 2.25 MiB weight stream for one projection: 0.087% written and, on first touch,
the same again read. The activation column itself is 4 KiB and is already resident for the
weight dot.

In vector-memory requests the sideplane is a four-fold reduction, not an addition. Each
consumer workgroup reads K bytes of sums where E4 read 4K bytes of raw activation for the
same four group sums, both out of cache. The 44.4% figure is the sideplane read against the
weight stream, and it is large only because the activation traffic per workgroup was
already large relative to four rows of weights.

## The traffic balance in the campaign's terms

The relation every E4b arm is decided by:

```text
precompute cost + sideplane traffic
<
duplicate group-sum cost x output-row reuse x projection reuse
```

Saved: 12 adds and 3 `vec4` loads per lane per superblock, in every one of the `M/4`
output-row workgroups of every consuming projection. At M = 2048 the output-row reuse is
512, and the projection reuse is the measured 1.93 over the whole 2B decode graph or 2.63
over the pre-passes that serve more than one consumer, 2 for the FFN gate/up pair and 3 or
4 for the attention projections.

Added: the pre-pass's 12 adds, 4 `vec4` loads, and 1 `vec4` store per lane chunk, once;
K bytes of sideplane write per pre-pass; one `vec4` sideplane load per lane per superblock
in the consumer, replacing four; and one dispatch plus two memory barriers per miss.

The arithmetic closes positive by about three orders of magnitude: the pre-pass's 192 adds
per superblock per column are the same 192 the duplicated work costs in **one** of 512
workgroups, so the output-row axis alone repays the pre-pass 512-fold before the projection
axis is counted. The whole open cost is the dispatch. A 2B decode graph pays 84 of them
against 40 submits per graph and a measured 52 ms Q4_K bracket, and 36 of the 84 serve a
single consumer. On a device whose Q4_K mat-vec median is 206 microseconds per call, a
pre-pass that costs anything like a mat-vec dispatch erases the arm; a pre-pass that costs a
small fraction of one leaves E4b's registered ceiling of `52 x 0.16 = 8.32` ms in reach.
That number is unmeasured here and the workstation cannot supply it.

## Two falsifiers the ISA receipt answered

`evidence/e4b-summary-producer/` runs both consumers and the pre-pass through
`remote/raven2-shader-lab/lab.sh` on a drm-shimmed RAVEN2 node whose ACO reproduces this
tree's retained E4 receipt exactly, `isa_sha256 29454587...185a1d` at VALU 810 and
`v_mac_f32` 152.

- **ACO ISA receipt.** Answered, and it reads against this page's GLSL count. VALU falls
  810 to 797, 13 instructions of 810, where `v_add_f32_e32` falls 40 to 16 and the
  sideplane's address arithmetic returns 11. VMEM rises 56 to 58, so the four activation
  `vec4` loads are shared with the weight dot and no load is saved. The registered E4b
  ceiling of 2.6 to 5.2% of the body is refuted on the compile side.
- **VGPR and waves per SIMD.** Answered: VGPR 64 to 64, SGPR 48 to 48, LDS and scratch
  zero in both, longest dependent VALU chain 17 in both. The arm moves no occupancy step.

## Falsifiers still open for the device

- **The pre-pass dispatch cost on RADV.** Unmeasured. The 2B graph adds 84 dispatches of
  128 to 384 invocations each, 2 to 6 workgroups of 64, on a 2 CU device where the census
  measured 206 microseconds median per Q4_K mat-vec call and 1.83 ms of queue idle across
  40 submits per graph. A dispatch cost above about 40 microseconds consumes the whole
  E4b ceiling.
- **Whether the sideplane traffic shows in the census bracket.** The pre-pass is a new
  pipeline and the census attributes by pipeline, so its cost lands in its own row rather
  than inside the Q4_K family's exclusive bracket. Reading E4b-A against E4 requires the
  union of the two rows, and a bracket comparison that omits the pre-pass row reports a
  saving the token will not show.
- **Whether declining the single-consumer pre-passes recovers measurable time.** That 36
  of 84 pre-passes serve one consumer is measured above rather than open; what the device
  decides is whether removing those dispatches moves the bracket, which sets whether the
  forward consumer walk is worth writing.
