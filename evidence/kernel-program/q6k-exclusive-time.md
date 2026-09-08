# Q6_K on Raven2: exclusive time, unpacking cost, and register use

The Q6_K mat-vec accounts for 37.0% of the 2B distill's raw decode
bracket sum and 29.3% of the 4B distill's raw sum. These denominators are
interval sums, not complete token latency. The corresponding file-byte shares
are 50.08% and 38.36%; different tensor shapes, unused MTP tensors and different
Q4_K implementations prevent those shares from establishing an intrinsic
format ranking. Q6_K's source arithmetic remains a useful candidate mechanism:
21 FMA-class operations per 16 products against Q4_K's 38, with no
per-superblock minimum term. Source counts alone establish neither compiled
instruction cost nor delivered performance.

The tied `token_embd.weight` output projection is the first candidate subject.
Its 62,080 of 83,840 workgroups represent 74.0% of the family population;
23.7 to 25.4 ms against 36.7 ms represents approximately 65 to 69% of family
time. Workgroup share and time share answer different questions.

The family reader derives the totals from retained census ledgers. Shader
source supplies the arithmetic counts, and retained dispatch records identify
tensor shapes. No device run was made for this analysis revision.

## What the reader accepts

`remote/summarize-kernel-census.py` ranks pipelines individually.
`remote/summarize-pipeline-family.py` groups its output by the value format
each pipeline name's own type tokens state, quantized format before float, so
`set_rows_f32_q4_0_i64` reads Q4_0 rather than Q4_K and every f32-only
pipeline reads `other` with its members enumerated.

An arm is accepted where its ledger carries exactly one well-formed `graphs`
row stating a valid whole-overlap ownership verdict whose
`cross_pipeline_overlap_fraction` stays inside the row's own `overlap_threshold`. The cross-pipeline half rather
than the whole overlap is the gate, because same-pipeline overlap between two
dispatches of one shader stays inside the family a merge forms while overlap
against a foreign pipeline is time the instrument attributes to neither. Every
other ledger is refused whole. The output preserves `pipeline_ownership` and
states `family_ownership` separately; a whole-overlap inconclusive row can
satisfy family admission when only same-pipeline overlap exceeds the threshold.
Unsupported IQ, TQ, MXFP and NVFP source types stay enumerated in `other`, including
when a later activation operand names Q8 or F16. Numeric fields must be finite and nonnegative,
fractions lie in [0, 1], graph counts are canonical positive integers, and
interval lower/union/upper bounds must agree within ledger rounding. Each
pipeline union partitions into exclusive and ambiguous time. Pipeline raw and
exclusive totals match the corresponding graph totals within rounding slack,
and the summed pipeline unions bound the graph union and stay below the raw
total. Pipeline IDs are unique and duration quantiles stay ordered. Missing
pipeline time beyond rounding slack therefore refuses before family shares emit. Local
ownership admission does not establish a compatible global instrument
calibration. The retained
`q4k-scale-decode/4b-attribution-20260905/calibration/arms/22-I1` ledger is
empty and refuses on that rule, which is the same arm the campaign's own
`arms.tsv` marks `status=failed`.

The aggregate arithmetic is bounded rather than exact. A sum of
`total_bracket_upper_bound_ms` over a family is additive and stays an upper
bound; a sum of `exclusive_bracket_ms` is additive and stays a lower bound; a
sum of `pipeline_bracket_union_ms` is an upper bound on the family union.
An exact family union requires the actual intervals; this reader reports
conservative totals. The share denominator is
`raw_bracket_sum_ms_per_graph` times the graph count, because interval-sum numerators partition that denominator exactly and
would sum above one against the union.

## Per accepted I1 arm

Mat-vec pipelines alone, `--family-prefix mul_mat_vec`, decode phase, 63
graphs per arm, `overlap_threshold=0.0500`. Every ledger below reads
`ownership=conclusive`.

| arm | family | bracket upper bound ms | exclusive lower bound ms | ambiguous ms | share of raw sum |
| --- | --- | ---: | ---: | ---: | ---: |
| 2B `20260902T2124Z/18-I1` | Q4_K | 3289.449 | 3225.840 | 44.335 | 0.5272 |
| 2B `20260902T2124Z/18-I1` | Q6_K | 2310.078 | 2307.476 | 2.602 | 0.3702 |
| 2B `20260902T2124Z/19-I1` | Q4_K | 3301.578 | 3237.611 | 44.614 | 0.5260 |
| 2B `20260902T2124Z/19-I1` | Q6_K | 2324.843 | 2322.241 | 2.602 | 0.3704 |
| 2B `20260902T2124Z/22-I1` | Q4_K | 3294.593 | 3230.834 | 44.421 | 0.5263 |
| 2B `20260902T2124Z/22-I1` | Q6_K | 2318.246 | 2315.623 | 2.623 | 0.3703 |
| 2B `20260902T2124Z/23-I1` | Q4_K | 3289.354 | 3225.873 | 44.169 | 0.5272 |
| 2B `20260902T2124Z/23-I1` | Q6_K | 2310.310 | 2307.712 | 2.598 | 0.3703 |
| 4B `4b-attribution-20260905/calibration/18-I1` | Q4_K | 10885.061 | 10712.008 | 118.590 | 0.6203 |
| 4B `4b-attribution-20260905/calibration/18-I1` | Q6_K | 5147.344 | 5136.636 | 10.708 | 0.2933 |
| 4B `4b-attribution-20260905/calibration/19-I1` | Q4_K | 10852.504 | 10679.847 | 118.208 | 0.6221 |
| 4B `4b-attribution-20260905/calibration/19-I1` | Q6_K | 5100.273 | 5089.683 | 10.590 | 0.2924 |
| 4B `4b-attribution-20260905/calibration/23-I1` | Q4_K | 10886.710 | 10713.614 | 118.513 | 0.6204 |
| 4B `4b-attribution-20260905/calibration/23-I1` | Q6_K | 5146.880 | 5136.180 | 10.700 | 0.2927 |
| 0.8B `q8-attribution/device-20260905/calibration/18-I1` | Q8_0 | 2441.184 | 2417.500 | 18.927 | 0.7948 |

The ambiguous overlap that would block attribution is small on every Q6_K row:
2.60 ms of a 2310 ms upper bound on the 2B, 0.11%, and 10.7 ms of 5147 ms on
the 4B, 0.21%. The upper and lower bounds differ by that much, so the Q6_K
share is bounded rather than estimated.

Two ledger properties bound how far these numbers travel. The 4B campaign's
own calibration verdict is `failed` -- four P arms lost more than 3% of their
sidecar window under the 4B's decode -- which withdraws that campaign's P/I
comparison and leaves each I1 arm's own family accounting standing, since the
accounting reads one arm's brackets rather than a pair. The 4B's
`mul_mat_vec_q4_k_f32_f32` module is the composed Q4_K candidate
(`78a576ff...`) rather than the production module the 2B arms executed
(`a9ac07dd...`), so the two classes' Q4_K columns are two shaders. Their Q6_K
modules are byte-identical at `d584d6b4...`, which is what makes the Q6_K rows
one shader measured on two shapes.

## Raw bracket shares against file-byte shares

| checkpoint | Q4_K file bytes | Q4_K raw sum | Q6_K file bytes | Q6_K raw sum | Q6_K share ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8-2B distill | 48.91% | 52.72% | 50.08% | 37.02% | 0.74 |
| Qwen3.8-4B distill | 61.11% | 62.03% | 38.36% | 29.33% | 0.76 |

Byte shares come from `evidence/qwen38-distill-tensor-census.md`; raw
bracket shares are the `18-I1` rows above. Dividing file-byte totals by these
brackets gives diagnostic normalizations: approximately 17.7 versus 12.2 GB/s
on the 2B, and 13.0 versus 9.8 GB/s on the 4B. Those values describe the
retained workloads' file-byte normalization, not executed bandwidth.

The ordinary load skips MTP tensors, `get_rows` touches selected embedding
rows, and the families execute different projection shapes. The two classes
also execute different Q4_K modules. Establish actual executed bytes and group
by tensor shape before comparing throughput. These records identify a
concentrated Q6_K optimization subject; they leave a universal Q4_K/Q6_K
format ranking unresolved. Previous union-based or whole-token percentages
carry different denominators and require a separate reconciliation.

## Where the Q6_K time sits

Per workgroup the two mat-vecs are close on the 2B and separated on the 4B:

| checkpoint | family | ms per graph | workgroups per call | ns per workgroup |
| --- | --- | ---: | ---: | ---: |
| 2B | Q4_K | 52.213 | 748.3 | 430.7 |
| 2B | Q6_K | 36.668 | 3353.6 | 437.4 |
| 4B | Q4_K | 172.779 | 1144.3 | 699.0 |
| 4B | Q6_K | 81.704 | 2967.3 | 834.4 |
| 0.8B | Q8_0 | 38.749 | 1733.3 | 119.5 |

The Q4_K and Q6_K workgroups cover 4 output rows at `64,4,1`; the Q8_0
comparison covers 2 rows at `64,2,1`. A four-row workgroup
covers `4 * ncols` weights and the byte count behind one workgroup rises with
both `ncols` and the format's bits per weight. The 4B comparison also crosses
two Q4_K shaders. Neither column is a per-workgroup cost model.

The distribution mixes tensor shapes; it does not establish random scheduling
stalls. Group dispatch observations by tensor shape before testing tail behavior.
Every 2B arm reads a Q6_K median of 580 to 589 us with a p99 of 23707 to 23758 us, a 40-fold tail
where Q4_K's p99 sits 2.9 times its median; every 4B arm reads the same shape
at a median of 1282 to 1286 us and a p99 of 38665 to 39062 us. The retained
raw census in `evidence/raven2-vulkan-kernel-census/replay-corpus/10-I1/`
names the dispatch directly: `token_embd.weight` issues `62080x1x1`
workgroups against `blk.N.ffn_down.weight`'s `512x1x1` and
`blk.N.attn_qkv.weight`'s `1536x1x1`, one dispatch per graph, at a mean
interval of 23588 us. That is 74.0% of the family's 83,840 workgroups per
graph and about 64% of its 36.67 ms, so the tied vocabulary projection alone
corresponds to roughly 23.7% of the 2B raw bracket sum. The 23.588 ms replay
mean is a separate observation from the 23.7 to 25.4 ms range above; comparing
it with 36.67 ms is a descriptive cross-record normalization.

## Unpacking cost from the shader source

Counted from the pinned commit `f280b269983ad0fdb705a0d9ebf0503e76f2899b0`,
per thread per 256-weight superblock at `NUM_COLS=1`, where 16 threads
cooperate on one superblock and each thread produces 16 weight-activation
products. Source digests:
`mul_mat_vec_q4_k.comp` `02f84c2fc3ca217773bc281e34704965517728b8acb38c2bbd1163b8e0df54a8`,
`mul_mat_vec_q5_k.comp` `175bd27fc8281f8ec72087f9c36ed51266c74f8bfca0f01719ec66d899324c70`,
`mul_mat_vec_q6_k.comp` `bc785a2457aa5b04d416e18f5ae2304da267e35cea7b54ac67b5d20987e450af`.

| operation class | Q4_K | Q5_K | Q6_K |
| --- | ---: | ---: | ---: |
| scale loads | 3 packed u16 | 3 packed u16 | 1 int8 array element |
| scale decode integer ALU | 9 | 9 | 0 |
| scale decode `unpack8` | 2 | 2 | 0 |
| scale staging | none | none | 1 LDS store, 1 `barrier()`, 4 LDS loads per row |
| quantized-field loads | 2 u32 | 4 u16 | 4 u16 |
| field assembly and masking ALU | 6 | 10 | 10 |
| bit-plane merge ALU | 0 | 12 | 13 |
| bias arithmetic | 0 | 4 integer adds | 4 `vec4` subtractions of 32 |
| `unpack8` on quantized fields | 4 | 4 | 4 |
| activation loads | 4 `vec4` | 8 `vec2` | 4 `vec4` |
| FMA-class operations, products | 16 | 16 | 16 |
| FMA-class operations, minimum term | 16 | 16 | 0 |
| FMA-class operations, scale combine | 6 | 6 | 5 |
| FMA-class operations, total | 38 | 38 | 21 |

Q4_K decodes six-bit scales and four-bit minimums out of a twelve-byte packed
field in registers (`mul_mat_vec_q4_k.comp:19-35`) and merges no bit plane.
Q5_K performs that same decode and adds the fifth bit plane
(`mul_mat_vec_q5_k.comp:45-55`), so it is the only one of the three paying
both, which is the account `evidence/tensor-type-execution-audit.md` gives for
the Q5_K trunk reaching 5.9 GB/s where the Q4_K and Q6_K trunks reach about
8.1. This count states that account's size: the bit-plane merge is 12 to 13
integer operations and 4 bias operations per thread per superblock, added to
an FMA-class total that stays at 38.

Q6_K pays the merge and skips the whole scale decode and the whole minimum
term. Its scales are int8 values read directly and staged in `sccache`
(`mul_mat_vec_q6_k.comp:9,23,55`), and its quantization is symmetric, so the
`-dm.y * smin` correction Q4_K and Q5_K each spend 16 FMA-class operations on
does not exist. The 38-to-21 source ratio motivates a compiled arithmetic
experiment; it does not isolate the cause of the workload-level normalization above.

Q6_K's staging carries a synchronization the other two lack: `barrier()` runs
once per row per superblock inside `calc_superblock`, at `NUM_ROWS=4`, on both
the `all_threads` and the partial-block path.

## Register use

The census ledger carries the RADV statistics of the pipelines that executed
on Raven2, which is the authority for the two formats that ran.

| arm | pipeline | VGPR | SGPR | spilled | LDS | scratch | subgroups per SIMD |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2B `20260902T2124Z/18-I1` | `mul_mat_vec_q4_k_f32_f32` | 64 | 48 | 0 | 0 | 0 | 4 |
| 2B `20260902T2124Z/18-I1` | `mul_mat_vec_q6_k_f32_f32` | 64 | 48 | 0 | 512 | 0 | 4 |
| 4B `4b-attribution/18-I1` | `mul_mat_vec_q4_k_f32_f32` | 48 | 48 | 0 | 0 | 0 | 5 |
| 4B `4b-attribution/18-I1` | `mul_mat_vec_q6_k_f32_f32` | 64 | 48 | 0 | 512 | 0 | 4 |
| 0.8B `q8-attribution/18-I1` | `mul_mat_vec_q8_0_f32_f32` | 40 | 48 | 0 | 0 | 0 | 6 |

All five run the `64,4,1` specialization except the Q8_0 row, which runs
`64,2,1`. Vector registers rather than LDS set the occupancy: 512 bytes per
workgroup against the 64 KiB per compute unit
`evidence/hardware/qwen-laptop-parts.md` records leaves the LDS allocation far
from a limit, while 64 VGPRs of a 256-register file admits 4 waves per SIMD
against the 10 the hardware allows. The composed Q4_K candidate the 4B arms
served reaches 48 VGPRs and 5 waves per SIMD on the same specialization, which
is a measured demonstration that this shader family's occupancy moves with a
source change on this device.

The workstation lab compile remains unrun for these candidates. The general
shader lab reaches ACO through a RADV pipeline, while `--spirv-only` supplies
neither realized specialization nor register statistics. A workstation's live
NVIDIA ICD does not rule out the project's isolated offline RADV compiler/shim.
Use that matched toolchain with explicit module, target and specialization
receipts, and label the result static compilation. Q5_K has no retained
executed register row because these served checkpoints contain no Q5_K tensors.

## Candidates

Each candidate names one mechanism, one lab falsifier reachable without the
device, and one bracket falsifier that a later I1 arm answers. Promotion of
any of them waits on the device baseline of task #55; nothing here is a
promotion, because a bracket is an envelope over a queue rather than a rate,
and this record measures no tok/s.

**C1, vocabulary-projection row tiling.** `token_embd.weight` dispatches
62,080 workgroups over a 248,320-row vocabulary at `NUM_ROWS=4` and
`ncols=2048`, so the 2048-element activation vector is re-read once per
workgroup, 62,080 times per token, for 74.0% of the Q6_K family's workgroups
and about 23.7% of the raw decode bracket sum. Raising `NUM_ROWS` for this shape
alone divides that re-read count by the same factor. Lab falsifier: `temp[]`
is `NUM_COLS * NUM_ROWS` registers, so an ACO compile at the raised row count
that spills, or that drops below 4 waves per SIMD, refutes the candidate
before any device time is spent. Bracket falsifier: the `token_embd.weight`
dispatch's own exclusive bracket in a new accepted I1 arm fails to fall.

**C2, scale staging without the barrier.** Q6_K writes 16 int8 scales into
`sccache` and executes `barrier()` once per row per superblock, at
`NUM_ROWS=4`, where Q4_K decodes its packed scales in registers with no
synchronization at all. The 512-byte LDS allocation is not the constraint --
occupancy is 4 waves per SIMD from 64 VGPRs, and 512 bytes leaves the 64 KiB
per compute unit almost untouched -- so the barrier rather than the storage is
what the staging costs. Each thread reading its own four scales directly
removes both. Lab falsifier: the direct read raises VGPRs above 64 or drops
waves per SIMD below 4 in an ACO compile. Bracket falsifier: the Q6_K family's
exclusive bracket per graph fails to fall in a new accepted I1 arm.

**C3, bit-plane merge width.** The merge is 13 integer operations plus 4
`vec4` bias subtractions per thread per superblock, and the bias could fold
into the `d` scale so that `q - 32` never materializes. The mixed-shape file-byte
normalization cannot establish whether the merge bounds the selected projection. Inspect the consumed ISA and measure the
projection separately; retain the arithmetic and quantization contract.
Lab falsifier: the ACO instruction count over the merge region fails to fall by at least the 4 subtractions the fold removes, or
the fold changes the module's numerics. Bracket falsifier: the same as C2.

## What did not run

- No device run of any kind. Every number is read from a retained ledger or
  from shader source at the pinned commit.
- The matched workstation ACO compile for these Q6_K candidates; the isolated
  offline path remains available for a separately bound static receipt.
- Q5_K register use and Q5_K bracket time, because no served checkpoint holds
  Q5_K tensors and no retained Raven2 pipeline exists for that shader.
- The 0.8B carries no Q6_K or Q4_K mat-vec pipeline at all; its row appears
  here as the Q8_0 comparison and contributes nothing to the Q6_K account.

## Reproduction

```sh
remote/summarize-pipeline-family.py \
    evidence/raven2-vulkan-kernel-census/20260902T2124Z/arms/18-I1/pipeline-ledger-decode.tsv \
    --family-prefix mul_mat_vec
remote/test-summarize-pipeline-family.py
```

## Retained analysis revision

The published draft at `6cb1b9add2aecd31aade1ff652dfdd41244fcf94` remains the
historical analysis revision. Its gate terminated with exit 143 and its later
local rebase stopped at a manifest conflict; neither event establishes landing.
The corrected reader reprocesses eight explicitly listed ledgers: four 2B arms,
three 4B arms and one 0.8B Q8 comparison. The fourteen Q4_K/Q6_K table rows are
family observations from seven arms, not fourteen acquisitions. The empty
4B `22-I1` ledger remains a retained refusal.

`q6k-family-reprocessing/inputs.tsv` binds each input and the reader by digest;
`families.tsv` retains the corrected output and `refusals.tsv` records the empty
arm. Acquisition files retain their original bytes and identities. Reproduce
from the repository root using the paths in `inputs.tsv` with
`--family-prefix mul_mat_vec`; a new reader revision is a separate analysis
identity, not a replacement acquisition.
