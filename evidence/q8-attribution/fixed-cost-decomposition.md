# A fixed-cost decomposition for the served 0.8B, registered ahead of the census

`evidence/model-admission/runtime-class-throughput.md` measures three 0.8B
checkpoints decoding within 5.2% of each other while streaming 67.9% apart in
bytes per token, at a 63 to 66 ms observed token time. That is the class
`decode-decomposition.md` already reads as exposing a fixed cost the 2B and
4B do not carry at the same relative weight, and this file states the
mechanism account, the census fields that would prove or refute it, and the
attribution arm that reads them, before any I1 ledger on this checkpoint
exists. `device-20260905/README.md` retains that arm and answers all five
questions: the account below is refuted, Q5's additive sum double-counts the
memory service that happens inside the mat-vec bracket it adds a DRAM floor
to, and this file stands as the pre-registration rather than as a standing
claim.

## The account: what does not scale with streamed bytes

`decode-decomposition.md`'s "the fixed cost the 0.8B exposes" section
derives, from the served figures, that 30 to 45 ms of the 0.8B's 63 to 66 ms
token is spent on neither DRAM streaming nor the VALU account for its
heaviest kernel, and names the candidate: 24 transformer blocks each issuing
on the order of fifteen dispatches (two matrix families, norms, the rotary
step, the Gated DeltaNet recurrence), so a decode graph is on the order of
360 dispatches across about 25 submissions of 16 nodes under the low-async
profile. Every dispatch not itself streaming or computing pays queue
placement, barrier, and command-buffer overhead that a smaller weight matrix
does not shrink, because block count and submission count are checkpoint
architecture, not byte count. The 0.8B's own census facts sharpen where that
residue would land for Q8_0 specifically:

- **Per-block dispatch count does not change with value format.** The Q8_0
  and Q4_K_M members of this runtime class (`evidence/model-admission/runtime-class-throughput.md`)
  share the same 24-block, 1024-embedding-width architecture; only the
  weight tensors' byte layout differs. A fixed-cost account predicts their
  `queue_non_dispatch_ms_per_graph` and `residual_ms_per_graph` land close
  together, because neither term reads a tensor's type.
- **The Q8_0 mat-vec's own exclusive bracket should be small relative to
  Q4_K's.** `pipeline-selection.md` reads Q8_0's dequant as one cast and one
  scale multiply per block against Q4_K's nibble split, scale decode, and
  minimum-term fold. If the VALU account in `shape-and-receipts.md` confirms
  Q8_0 costs fewer operations per weight, the served 0.8B's mat-vec families
  should own a smaller fraction of its token than the 2B's Q4_K mat-vec
  families own of the 2B's, even though the 0.8B streams more bytes per
  weight (Q8_0 at 1.0625 bytes/weight against Q4_K's 0.5625).
- **What is left over is where the fixed cost must be.** If the mat-vec
  families own a small share and DRAM bandwidth accounts for another
  (`streamed bytes / 34.13 GB/s` -- 0.801 GB implies 23.5 ms at peak), the
  residue -- `queue_non_dispatch_ms_per_graph + residual_ms_per_graph` plus
  whatever the Gated DeltaNet, norm, rotary, and attention families
  (`decode-decomposition.md`'s P3 group) do not already explain -- is what
  a per-dispatch, per-token cost independent of tensor type would predict,
  and is the reading the served figures already suggest: three checkpoints
  at three byte counts converging on one token time near 63 to 66 ms is the
  signature of a term that saturates rather than one that scales.

## What the census schema reports, and how it reads on this checkpoint

`remote/summarize-kernel-census.py` (as run by
`remote/run-raven2-vulkan-kernel-census.sh`) emits, per accepted decode
window:

| field | what it measures | role in this decomposition |
| --- | --- | --- |
| `queue_non_dispatch_ms_per_graph` | queue time inside the graph's timestamp bracket that no dispatch covers | the between-dispatch fixed cost `decode-decomposition.md` predicts at 25-40 ms for the 2B and measures at 3.4 ms (P2, refuted downward: "the 2B carries no fixed cost worth the name at 40 submits per graph") |
| `residual_ms_per_graph` | host retirement span beyond queue completion (`retire_span_ns - completion_span_ns`) | the host-side sampler, HTTP reply, and graph-construction residue on the same core the server runs on |
| per-family bracket union (mat-vec, Gated DeltaNet, norm, rotary, attention) | the queue-residency envelope each pipeline family owns, upper-bounded, with `ownership` reading `conclusive` below a 0.05 cross-pipeline overlap fraction | separates "the Q8_0 mat-vec costs this much" from "something else costs this much," which per-token totals alone cannot |
| `submits_per_graph`, dispatch count per graph | the shape `decode-decomposition.md`'s E6 reads against P2 | states whether the ~360-dispatch, ~25-submission estimate above is what the 0.8B's own graph actually issues, since block count and dispatch-per-block count are unmeasured for this architecture at this census's resolution |

The 2B's own accepted ledger already refuted P2 at 3.4 ms against a
registered 25-40 ms band, which is the reading that makes this document's
own fixed-cost account a genuinely open question rather than a foregone
conclusion carried over from the 2B: **the 2B's residue was almost entirely
absent, and the 0.8B's is where `decode-decomposition.md`'s P7 -- "a value
near the 2B's in absolute terms confirms the residue is per dispatch rather
than per byte" -- is still unevaluated.** If the 0.8B's
`queue_non_dispatch_ms_per_graph + residual_ms_per_graph` also reads near
zero, the 30-45 ms unexplained by DRAM and the mat-vec VALU account is not
queue or host residue at all, and the remaining candidate is the P3 group
(Gated DeltaNet, norm, rotary, attention) costing disproportionately more per
token on a narrower, more numerous-relative-to-width architecture -- 24
blocks at 1024 embedding width is a smaller per-block matrix and a larger
per-token block-count-to-width ratio than the 2B's 24 blocks at 2048, so the
non-mat-vec families' fixed per-dispatch costs (barrier waits, small-matrix
dispatch overhead) are a larger fraction of a smaller matrix's own compute
time.

## The attribution arm

```sh
QWEN_CENSUS_PRODUCTION_SERVER=P QWEN_CENSUS_PRODUCTION_RECEIPT=IDENTITY_CHECK.tsv \
QWEN_CENSUS_INSTRUMENTED_SERVER=I \
QWEN_CENSUS_MODE=attribution \
QWEN_CENSUS_CALIBRATION_RECEIPT=CALIBRATION_OUTPUT_DIRECTORY \
QWEN_CENSUS_ARMS=I1 \
    remote/run-raven2-vulkan-kernel-census.sh qwen35-08b OUTPUT_DIRECTORY
```

`QWEN_CENSUS_CALIBRATION_RECEIPT` must name an accepted calibration that
bound the same two server digests (`P` and `I`) an accepted 2B or 4B
calibration already produced; the appliance is not rebuilt for this arm, only
re-launched against the 0.8B checkpoint. The summarizer step reads:

```sh
remote/summarize-kernel-census.py OUTPUT_DIRECTORY/arms/NN-I1/pipeline-census.tsv \
    --window-begin-ns B --window-end-ns E \
    --expected-decode-graphs N
remote/summarize-census-controls.py OUTPUT_DIRECTORY/arms.tsv \
    --sidecar-bound 0.0065 --compile-bound 0.0065 --collect-bound 0.02
```

`--expected-decode-graphs` and the window bounds come from
`remote/measure-served-decode.sh`'s own retained request window for the 0.8B
arm, the same binding P1 through P6 used for the 2B.

## Registered before the arm runs

| # | prediction | falsifier |
| --- | --- | --- |
| Q1 | the Q8_0 mat-vec families' bracket union per graph is below the 2B's Q4_K union in absolute terms, and below it as a fraction of the 0.8B's own token, because Q8_0's dequant is one cast and one multiply against Q4_K's nibble-and-scale decode | a Q8_0 mat-vec bracket union at or above the 2B's Q4_K union (51.8 ms) refutes the "trivial dequant, small bracket" reading; the Q8_0 mat-vec is then the first target rather than a fixed-cost candidate |
| Q2 | `queue_non_dispatch_ms_per_graph + residual_ms_per_graph` for the 0.8B reads near the 2B's measured 3.4 ms (P7's "same order" reading fails) or reads materially higher (P7 holds and the residue is per-dispatch) | a value below 1 ms *and* an unexplained 30-45 ms gap together refute both the queue-residue and the mat-vec accounts, and the P3 family group (Gated DeltaNet, norm, rotary, attention) becomes the first target by elimination |
| Q3 | the P3 family group (Gated DeltaNet, norm, rotary, attention) owns a larger share of the 0.8B token than it owns of the 2B's (`decode-decomposition.md` measured about 9 ms of 101 ms on the 2B, roughly 9%) | a P3 share at or below the 2B's 9% refutes the narrower-architecture account and leaves the gap unassigned to any family the census brackets, which would make `submits_per_graph` (Q4/E6) the remaining candidate |
| Q4 | `submits_per_graph` and dispatch count per graph for the 0.8B are close to the ~25 submissions / ~360 dispatches `decode-decomposition.md` estimates by analogy to the 2B's 24 blocks | a dispatch count far outside that estimate (the 0.8B's architecture differs from the 2B's beyond block width -- `attention.head_count_kv=2`, `ssm.group_count=16`, `ssm.inner_size=2048` per the tensor census) means the per-block dispatch estimate itself needs correcting before Q1-Q3 are read against it |
| Q5 | the DRAM floor for the 0.8B, `0.801 GB / 34.13 GB/s = 23.5 ms`, is below the observed 63-66 ms token by a margin the mat-vec VALU account (Q1) plus P3 (Q3) plus residue (Q2) sums to within 15% | a sum outside that band means some family's bracket is double-counted (cross-pipeline overlap, P4's `ownership` check) or a family the ledger does not separately bracket owns the remainder |

Falsifying Q1 and confirming a large Q2 together would overturn this
document's own central claim -- that the served 0.8B's flat rate-across-bytes
signature is dispatch overhead rather than kernel cost -- and redirect the
next arm toward the mat-vec shader itself, the way `decode-decomposition.md`'s
own P1/P2 reversal on the 2B redirected E5 ahead of E6. That reversal is the
recorded precedent for taking this table's falsifiers at face value rather
than reading them as confirmation exercises.
