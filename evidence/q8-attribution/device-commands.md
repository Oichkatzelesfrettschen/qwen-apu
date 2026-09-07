# Device command list: what the laptop half runs

This tree's `AGENTS.md` states the two-machine rule: the Git tree lives on the
workstation, the runtime and the gfx902 device live on the laptop, and a
script edited here changes nothing there until it reaches the laptop's own
checkout. Every command below runs on the laptop, in a teardown window (the
appliance server is not serving while `lab.sh` or the census harness holds the
device).

## 0. Bring the laptop's checkout to this branch

The laptop runs from its own checkout of this repository, so the branch
arrives through Git rather than through a copy: the scripts, the patches, and
the evidence a step reads all travel together and
`remote/check-runtime-tree.sh` refuses a launch over a partial tree.

```sh
ssh TARGET 'cd CHECKOUT && git fetch --prune origin && git checkout BRANCH && git pull --ff-only'
```

`remote/sync-runtime-tree.sh DESTINATION` is the other route, and it carries
`remote/` and `patches/` alone. Section 1 below reads a workstation-built
digest (`evidence/q8-attribution/spirv/manifest.tsv`) and Section 2 reads the
retained Q4_K receipt
(`evidence/raven2-vulkan-kernel-census/e1/receipts/q4k-exec-receipt.tsv`), so
a run over a synced tree resolves neither and the Git route is the one this
list assumes.

Every path below is relative to that checkout, and each product goes under the
runtime root `remote/qwen-home.sh` names, so `RESULTS` stands for
`$(remote/qwen-home.sh print qwen_home_results)` on the laptop.

## 1. Reproduce the Q8_0 SPIR-V from the pinned source tree

The workstation compile already retained the module digests this step must
reproduce (`evidence/q8-attribution/spirv/manifest.tsv`); running it again on
the laptop against the same pinned commit is the check that glslc's frontend
is host-independent, ahead of trusting a copied `.spv`:

```sh
remote/compile-q8-mat-vec-spv.sh \
    $(remote/qwen-home.sh print qwen_home_llama_source) RESULTS/q8-spv-laptop
diff RESULTS/q8-spv-laptop/manifest.tsv \
    evidence/q8-attribution/spirv/manifest.tsv
```

A digest mismatch here is the finding, not a discardable warning: it means
this host's glslc, or the source tree at the far end, is not what the
workstation compiled, and every later step reads a different module than the
one `pipeline-selection.md` and `shape-and-receipts.md` describe.

## 2. Compile the pipeline through ACO and retain every layer

```sh
remote/raven2-shader-lab/q8-mat-vec-receipt.sh \
    RESULTS/q8-spv-laptop RESULTS/q8-receipts-laptop --allow-device
```

This creates two live Vulkan pipelines (the `SHMEM` and `SUBGROUP` reduction
variants) against the appliance's own RADV RAVEN2 device, retains
`spirv.dis`, `final.nir`, `isa.s`, `stats.tsv`, `receipt.tsv`, and
`depth.tsv` under `RESULTS/q8-receipts-laptop/mul_mat_vec_q8_0_f32_f32/` and
`.../mul_mat_vec_q8_0_f32_f32_subgroup/`, and touches no model, no server,
and no lease -- the same guarantee `remote/raven2-shader-lab/README.md`
states for the Q4_K and Q6_K runs already retained under
`evidence/raven2-vulkan-kernel-census/e1/`.

Read the receipt's own `device_name` and `driver_name` fields before trusting
anything else in it:

```sh
awk -F'\t' '$1=="device_name" || $1=="driver_name" || $1=="run_mode"' \
    RESULTS/q8-receipts-laptop/mul_mat_vec_q8_0_f32_f32_subgroup/receipt.tsv
```

`device_name` must read `AMD Radeon Graphics (RADV RAVEN2)` and `run_mode`
must read `device`; anything else means this ran against the wrong GPU or
fell back to `--spirv-only` and the comparison in `shape-and-receipts.md`
cannot be closed from it.

## 3. Fill the comparison table

```sh
awk -F'\t' '
    NR == FNR { q4k_value[$1] = $2; q4k_per_superblock[$1] = $3; next }
    { q8_value[$1] = $2; q8_per_superblock[$1] = $3; seen[$1] = 1 }
    END {
        n = split("vgprs sgprs spilled_vgprs spilled_sgprs lds scratch code_size waves_per_simd valu salu vmem smem lds_instructions waitcnt", field_list, " ")
        printf "field\tq4k_value\tq4k_per_superblock\tq8_value\tq8_per_superblock\n"
        for (i = 1; i <= n; i++) {
            f = field_list[i]
            printf "%s\t%s\t%s\t%s\t%s\n", f, \
                (f in q4k_value ? q4k_value[f] : "-"), (f in q4k_per_superblock ? q4k_per_superblock[f] : "-"), \
                (f in q8_value ? q8_value[f] : "-"), (f in q8_per_superblock ? q8_per_superblock[f] : "-")
        }
    }
' evidence/raven2-vulkan-kernel-census/e1/receipts/q4k-exec-receipt.tsv \
  RESULTS/q8-receipts-laptop/mul_mat_vec_q8_0_f32_f32_subgroup/receipt.tsv
```

joins the two receipts by their `field` column (the first field) rather than
by row position. A positional `paste` is wrong here because the retained
Q4_K receipt predates the `environment_names` row `lab.sh` now writes, so the
two files' row counts and row order already diverge before any field this
table needs; a join on `$1` is what "aligns by field name" actually requires.
Copy the `vgprs`, `sgprs`, `spilled_vgprs`, `spilled_sgprs`, `lds`, `scratch`,
`code_size`, `waves_per_simd`, `valu`, `salu`, `vmem`, `smem`,
`lds_instructions`, and `waitcnt` rows, both raw and `per_superblock`
(divided by 32 for Q8_0, by 256 for Q4_K -- see `shape-and-receipts.md`'s
normalization warning), into that document's pending table, and read
`RESULTS/q8-receipts-laptop/.../depth.tsv` for `longest_valu_chain` (max over
blocks) and the block count for `loop-body count`.

## 4. Run the attribution arm against the served 0.8B

```sh
QWEN_CENSUS_PRODUCTION_SERVER=P QWEN_CENSUS_PRODUCTION_RECEIPT=IDENTITY_CHECK.tsv \
QWEN_CENSUS_INSTRUMENTED_SERVER=I \
QWEN_CENSUS_MODE=attribution \
QWEN_CENSUS_CALIBRATION_RECEIPT=CALIBRATION_OUTPUT_DIRECTORY \
QWEN_CENSUS_ARMS=I1 \
    remote/run-raven2-vulkan-kernel-census.sh \
    qwen35-08b RESULTS/q8-census-attribution

remote/summarize-kernel-census.py \
    RESULTS/q8-census-attribution/arms/*-I1/pipeline-census.tsv \
    --window-begin-ns "$WINDOW_BEGIN_NS" --window-end-ns "$WINDOW_END_NS" \
    --expected-decode-graphs "$EXPECTED_DECODE_GRAPHS"

remote/summarize-census-controls.py \
    RESULTS/q8-census-attribution/arms.tsv \
    --sidecar-bound 0.0065 --compile-bound 0.0065 --collect-bound 0.02
```

`CALIBRATION_OUTPUT_DIRECTORY` names an already-accepted calibration whose
`P` and `I` server digests match this run's -- reuse the 2B or 4B
calibration already on file rather than re-running the thirteen-arm
sequence, since `QWEN_CENSUS_MODE=attribution` only binds server identity,
not model identity, to the calibration receipt. `$WINDOW_BEGIN_NS`,
`$WINDOW_END_NS`, and `$EXPECTED_DECODE_GRAPHS` come from
`remote/measure-served-decode.sh`'s own retained request window for a
`qwen35-08b` arm, read the way every prior I1 arm's window was read.

Read the five fields `fixed-cost-decomposition.md` names --
`queue_non_dispatch_ms_per_graph`, `residual_ms_per_graph`, the mat-vec
family bracket union, the P3 family group's bracket union, and
`submits_per_graph` -- against Q1 through Q5, in that document's own falsifier
order: Q4's dispatch-count check first, since a dispatch count far from the
estimate invalidates reading Q1 through Q3 against it.

## 5. What this document does not cover

Running Section 4's arm needs an accepted calibration binding this build's
`P` and `I` server digests, which this branch does not produce -- it stays
off `remote/run-served-binary-ab.sh` and the census runner by scope, per this
task's owned-files boundary. An operator with a current accepted calibration
on file runs Section 4 directly; one without needs
`remote/run-raven2-vulkan-kernel-census.sh`'s own `QWEN_CENSUS_MODE=calibration`
path first, which is out of scope here and already documented in
`evidence/raven2-vulkan-kernel-census/README.md`.
