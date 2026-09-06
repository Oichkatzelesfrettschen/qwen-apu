# The Q8_0 mat-vec split by shape: the tied output head owns a third of the family

```text
measurement_status=re-read of retained I1 records, no device run
arms=18-I1 19-I1 22-I1 23-I1 (the four accepted attribution arms of ../README.md)
pipeline=26 mul_mat_vec_q8_0_f32_f32 constants=64,2,1 vgprs=40 sgprs=48 spilled=0 lds=0 subgroups_per_simd=6
spirv_executed_sha256=f2d4eded8eb892ed5c9bfccc7c2fad43cbbc257e732a927b6bd436f19bea2798
dominant_shape=token_embd.weight ne0=248320 workgroups=124160 calls_per_graph=1
```

`../README.md` puts `mul_mat_vec_q8_0_f32_f32` at 66.69% of the 0.8B token,
38.36 ms of a 57.51 ms decode graph over 187 dispatches, and names a
kernel-delta bracket inside that body as the first Q8-specific experiment
without saying which of its dispatches to aim at. The pipeline ledger keys
by pipeline, so all 187 dispatches read as one row at a 186.4 us median. This
record re-keys the same endpoint sweep by tensor shape and finds the family
is one large dispatch and twelve small ones: the tied output head
`token_embd.weight` is a single dispatch of 124160 workgroups costing 12.719
ms per graph, 33.16% of the family and 22.12% of the whole token, against a
186 us median across every other shape.

## How the split is computed

`evidence/q8-attribution/split-q8-mat-vec-shapes.py` imports
`remote/summarize-kernel-census.py` and reuses its parser, its window rule,
and its `graph_tokens` phase filter, so the decode set is the summarizer's
own -- 63 graphs whose begin and retire instants both fall inside the request
window and whose weight matmuls carry one column. It then re-runs the
endpoint sweep of `sweep()` with one change: a dispatch of the Q8_0 mat-vec
pipeline is keyed by `(src0 name with its block prefix removed, ne0, ne1,
workgroups)` rather than by pipeline id, and every other dispatch keeps its
pipeline id. A segment one key covers is that key's exclusive time on
exactly the basis the pipeline ledger reports, and a segment two keys cover
is ambiguous and counted apart. Summing the family's per-shape exclusive
times returns 38.355 ms per graph against the ledger's 38.36, which is the
recomposition check.

The 0.8B's own tensor names carry the split. `evidence/q8-attribution/tensor-census.md`
reads 195 Q8_0 tensors over 24 blocks with `embeddings_tied` true, so
`token_embd.weight` streams once per decode step as the output projection and
its 270,172,160 bytes are 33.73% of the 800,881,920 the census reports per
token. The block prefix is stripped because a role rather than a block index
names a shape: the eighteen `attn_qkv.weight` calls and the six separate
`attn_q`/`attn_k`/`attn_v` calls are the hybrid architecture's eighteen Gated
DeltaNet blocks and six full-attention blocks, which is why the two groups
appear side by side.

## Command lines

Read-only over ssh, against the appliance's own retained run. The raw
`pipeline-census.tsv` records stay there; only the derived table below travels.

```sh
# the arms, the raw record, and the pipeline rows the family dispatches
ssh eirikr@qwen-laptop 'ls ~/Github/qwen-apu/.runtime/results/08b-attribution-20260905T1835Z/calibration/arms/'
ssh eirikr@qwen-laptop 'grep -m3 mul_mat_vec_q8_0 \
    ~/Github/qwen-apu/.runtime/results/08b-attribution-20260905T1835Z/calibration/arms/18-I1/pipeline-census.tsv'

# the split, once per accepted I1 arm, with the script sent over stdin
for arm in 18-I1 19-I1 22-I1 23-I1; do
    ssh eirikr@qwen-laptop "nice -n 19 python3 - $arm 08b-attribution-20260905T1835Z" \
        <evidence/q8-attribution/split-q8-mat-vec-shapes.py
done
```

Each invocation prints its own preamble before the table:

```text
arm=18-I1 decode_graphs=63
q8_pipelines_dispatched=[26] constants=[(5, '64,2,2', 48, 5), (26, '64,2,1', 40, 6)]
family_exclusive_ms_per_graph=38.373 family_calls_per_graph=187.0
```

Two Q8_0 mat-vec pipelines exist in the process and the decode graphs
dispatch one of them: id 26 at `{BLOCK_SIZE=64, NUM_ROWS=2, NUM_COLS=1}`, 40
VGPRs and 6 subgroups per SIMD. Id 5 at `{64, 2, 2}` reads 48 VGPRs and 5
subgroups per SIMD and stays out of the decode set, which makes it the
in-record anchor for what an extra accumulator dimension costs in registers
and occupancy.

## The thirteen shapes

Median of the four accepted I1 arms, per decode graph. `arm spread` is the
range across the four arms as a percentage of the median exclusive time.

| tensor | ne0 | workgroups | calls/graph | exclusive ms/graph | median us | p99 us | share of family | arm spread |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `token_embd.weight` | 248320 | 124160 | 1 | 12.719 | 12700.4 | 12892.5 | 33.16% | 0.12% |
| `attn_qkv.weight` | 6144 | 3072 | 18 | 5.762 | 319.4 | 329.6 | 15.02% | 0.12% |
| `ffn_down.weight` | 1024 | 512 | 24 | 4.576 | 189.9 | 201.6 | 11.93% | 0.22% |
| `ffn_up.weight` | 3584 | 1792 | 24 | 4.512 | 188.5 | 210.9 | 11.76% | 0.07% |
| `ffn_gate.weight` | 3584 | 1792 | 24 | 4.501 | 188.6 | 194.7 | 11.73% | 0.13% |
| `ssm_out.weight` | 1024 | 512 | 18 | 1.981 | 109.4 | 126.8 | 5.16% | 0.25% |
| `attn_gate.weight` | 2048 | 1024 | 18 | 1.917 | 114.6 | 120.5 | 5.00% | 0.16% |
| `attn_q.weight` | 4096 | 2048 | 6 | 1.281 | 214.6 | 222.4 | 3.34% | 0.16% |
| `attn_output.weight` | 1024 | 512 | 6 | 0.667 | 111.7 | 116.5 | 1.74% | 0.15% |
| `attn_v.weight` | 512 | 256 | 6 | 0.152 | 32.1 | 34.6 | 0.40% | 0.66% |
| `attn_k.weight` | 512 | 256 | 6 | 0.152 | 30.4 | 32.7 | 0.40% | 0.00% |
| `ssm_alpha.weight` | 16 | 8 | 18 | 0.073 | 5.7 | 7.7 | 0.19% | 2.74% |
| `ssm_beta.weight` | 16 | 8 | 18 | 0.063 | 5.3 | 7.7 | 0.16% | 3.17% |
| **family** | | 324128 | **187** | **38.355** | | | **100%** | |

Ambiguous overlap is 0 on the four largest shapes and reaches 0.152 ms per
graph on `attn_gate.weight`, so the exclusive column carries the family's
time rather than an overlap-diluted share of it. `token_embd.weight` overlaps
nothing at all: it is one dispatch that no other bracket is open across.

## Arm-to-arm agreement

Every shape above 1% of the family agrees across the four arms within 0.25%,
and the dominant shape within 0.12%. The two 8-workgroup `ssm` shapes spread
2.7% and 3.2%, which is a 5 us dispatch measured against a 40 ns timestamp
period, and together they are 0.35% of the family. The family total reads
38.373, 38.329, 38.358, and 38.354 ms per graph on arms 18, 19, 22, and 23, a
0.11% spread. This split is therefore not limited by arm-to-arm scatter, and
the ordering above is stable across every accepted arm rather than a
median artifact.

## The dominant shape holds the most milliseconds

`token_embd.weight` holds 12.719 ms per graph, 33.16% of the family and
22.12% of the 57.51 ms token. It is the only shape whose single dispatch
outweighs another shape's whole call group: the next largest, the eighteen
`attn_qkv.weight` calls, together hold 5.762 ms.

It is also the family's best streamer rather than its worst. Its
270,172,160 bytes over its own 12.719 ms is 21.24 GB/s, against the family's
800,881,920 over 38.355 ms at 20.88 GB/s and the whole token's 13.93 GB/s.
Its byte share of the token (33.73%) and its time share of the family
(33.16%) agree within 0.6 points, so the head costs what its bytes cost at
the family's own rate and carries no shape-specific penalty.

What distinguishes it is the shape of the work rather than its efficiency.
`mul_mat_vec.comp` at `{64, 2, 1}` gives each workgroup two output rows and
one wave of 64 lanes; with `K_PER_ITER = 8` for a `QUANT_R == 1` type, a
workgroup covers 512 columns per iteration, so the head's 1024-column rows
run exactly two iterations per wave. The dispatch therefore launches 124160
waves that each issue about twenty vector-memory operations and retire. Over
two active compute units at four SIMDs each, that is 15520 waves per SIMD in
12.719 ms with six resident, about 4.9 us of residency per wave for two
loop iterations. The head is launch-and-latency-dominated in a way no other
shape in the table is, because every other shape reaches at most 3072
workgroups.

The partial-row tail is retired by inspection: `main()` calls
`compute_outputs(first_row, min(NUM_ROWS, p.stride_d - first_row))` only
where `first_row + NUM_ROWS > p.stride_d`, and every `ne0` in the table
(248320, 6144, 4096, 3584, 2048, 1024, 512, 16) divides by 4, so no
dispatch in this graph runs the partial path at `NUM_ROWS` of 2 or of 4.

## Selection

The Q8-local experiment aims at `token_embd.weight`.
`../q8-kernel-delta-design.md` registers the mechanism, its compiler-visible
falsifier in the shader lab, and its bracket falsifier under
`QWEN_CENSUS_AB_MODE=kernel-delta`.

The selection carries the coverage limits of the record it reads: the four
I1 arms come from a calibration whose own verdict is `failed`, whose three
instrument controls read `unresolved` or `incomplete`, and whose collect
control measures a -0.88% mean delta against a 2% bound. Every share above
is read with that term stated beside it rather than folded into it. A
re-keying of retained brackets adds no device time and inherits that
absence unchanged.
