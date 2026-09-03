#!/bin/sh
set -eu

# Two lab.sh output directories read as one mechanism receipt: which compiler
# layer carries a source change through, and which layer erases it.
#
# E4 in evidence/raven2-vulkan-kernel-census/decode-decomposition.md proposes
# hoisting the activation group sums out of mul_mat_vec_q4_k.comp's inner loop
# and predicts the family's exclusive bracket falls 10 to 16%. A served ABBA
# measures whether the token moved and says nothing about whether the hoist
# reached the device: on this machine a repeated depth-0 rate carries about 4%
# of uncontrolled spread and up to 30.6% between sweeps
# (evidence/decode-bound-analysis.md), which is larger than the effect. The
# receipt below settles the mechanism question ahead of the timing question,
# by naming the first layer at which the two builds differ and the last.
#
# The ladder has four rungs, each a different account of a null result:
#   spirv_unchanged   glslangValidator or glslc folded the edit away, so the
#                     two modules are the same bytes and the source change
#                     never reached a compiler that could act on it
#   nir_canonicalized the SPIR-V differs and the final NIR handed to ACO is
#                     identical, so NIR's own optimization passes reduced both
#                     forms to one
#   isa_identical     NIR differs and ACO emitted the same instructions, so the
#                     backend already performed the transformation by itself
#   isa_changed       the device executes different instructions, and a served
#                     ABBA then measures what those instructions cost
#
# A candidate whose SPIR-V matches the control's while its ISA differs is a
# harness fault rather than a finding, since one module compiled twice by one
# driver has no source difference to express; the verdict line names that case
# separately.
#
# The ladder is read from three digests, so a pair of --spirv-only receipts is
# refused rather than placed on it: those receipts carry no NIR and no ISA, and
# a rung reached with two layers unmeasured names a compiler stage that never
# ran. `spirv_unchanged` is a claim about what the later layers received, so it
# is stated from a device receipt too.

usage() {
    printf 'usage: %s CONTROL_DIR CANDIDATE_DIR\n' "$0" >&2
}

if [ "$#" -ne 2 ]; then
    usage
    exit 2
fi

control_directory=$1
candidate_directory=$2

for receipt_directory in "$control_directory" "$candidate_directory"; do
    if [ ! -r "$receipt_directory/receipt.tsv" ]; then
        printf 'not a lab.sh output directory, no readable receipt.tsv: %s\n' "$receipt_directory" >&2
        exit 1
    fi
done

control_receipt=$control_directory/receipt.tsv
candidate_receipt=$candidate_directory/receipt.tsv

read_field() {
    awk -F'\t' -v want="$2" '$1 == want { print $2; found = 1 } END { if (!found) print "-" }' "$1"
}

compare_state() {
    if [ "$1" = "$2" ]; then
        printf 'same'
    else
        printf 'changed'
    fi
}

# The verdict attributes a difference to the source change, which holds only
# where the two pipelines were created the same way. These ten fields are what
# the harness chose rather than what the shader declares: a subgroup size, a
# specialization constant, a robustness setting, or a driver revision that
# differs makes `isa_changed` a statement about the harness. `bindings`,
# `push_constant_bytes`, `spirv_capabilities`, and `features_enabled` are the
# shader's own declaration -- the sideplane variant adds binding 5 -- so they
# are reported below and decide nothing.
contract_refused=0
for contract_field in run_mode device_name driver_name driver_info \
    device_api_version robust_buffer_access spec_constants \
    subgroup_size_requested subgroup_size_min subgroup_size_max \
    environment_names; do
    control_contract=$(read_field "$control_receipt" "$contract_field")
    candidate_contract=$(read_field "$candidate_receipt" "$contract_field")
    if [ "$control_contract" != "$candidate_contract" ]; then
        printf 'execution contract differs, so the comparison attributes nothing: %s control=%s candidate=%s\n' \
            "$contract_field" "$control_contract" "$candidate_contract" >&2
        contract_refused=1
    fi
done

# read_field prints `-` for a row the receipt never wrote, and compare_state
# calls `-` against `-` the same, so a pair of --spirv-only receipts reaches
# nir_canonicalized with no NIR and no ISA ever captured. A layer the receipt
# holds no digest for is unknown rather than equal.
for placeholder_field in nir_sha256 isa_sha256; do
    for placeholder_receipt in "$control_receipt" "$candidate_receipt"; do
        if [ "$(read_field "$placeholder_receipt" "$placeholder_field")" = - ]; then
            printf 'receipt carries no %s, so no layer verdict follows from it: %s\n' \
                "$placeholder_field" "$placeholder_receipt" >&2
            contract_refused=1
        fi
    done
done

if [ "$contract_refused" -ne 0 ]; then
    exit 1
fi

control_spirv=$(read_field "$control_receipt" spirv_sha256)
candidate_spirv=$(read_field "$candidate_receipt" spirv_sha256)
control_nir=$(read_field "$control_receipt" nir_sha256)
candidate_nir=$(read_field "$candidate_receipt" nir_sha256)
control_isa=$(read_field "$control_receipt" isa_sha256)
candidate_isa=$(read_field "$candidate_receipt" isa_sha256)

spirv_state=$(compare_state "$control_spirv" "$candidate_spirv")
nir_state=$(compare_state "$control_nir" "$candidate_nir")
isa_state=$(compare_state "$control_isa" "$candidate_isa")

printf 'layer\tcontrol\tcandidate\tstate\n'
printf 'spirv_sha256\t%s\t%s\t%s\n' "$control_spirv" "$candidate_spirv" "$spirv_state"
printf 'nir_sha256\t%s\t%s\t%s\n' "$control_nir" "$candidate_nir" "$nir_state"
printf 'isa_sha256\t%s\t%s\t%s\n' "$control_isa" "$candidate_isa" "$isa_state"

printf '\ndeclaration\tcontrol\tcandidate\tstate\n'
for declared_field in bindings push_constant_bytes spirv_capabilities features_enabled; do
    control_declared=$(read_field "$control_receipt" "$declared_field")
    candidate_declared=$(read_field "$candidate_receipt" "$declared_field")
    printf '%s\t%s\t%s\t%s\n' "$declared_field" "$control_declared" \
        "$candidate_declared" "$(compare_state "$control_declared" "$candidate_declared")"
done

printf '\nfield\tbefore\tafter\tdelta\n'
# Every count row and every register allocation figure the two receipts share,
# in the control's own order, so a reader compares the same field on both
# sides rather than two orderings of one file.
awk -F'\t' -v candidate="$candidate_receipt" '
    BEGIN {
        while ((getline line < candidate) > 0) {
            split(line, parts, "\t")
            after[parts[1]] = parts[2]
        }
        close(candidate)
        numeric["vgprs"] = 1; numeric["sgprs"] = 1
        numeric["spilled_vgprs"] = 1; numeric["spilled_sgprs"] = 1
        numeric["lds"] = 1; numeric["scratch"] = 1
        numeric["code_size"] = 1; numeric["waves_per_simd"] = 1
    }
    NR == 1 { next }
    {
        field = $1
        before = $2
        if (!(field in numeric) && $3 == "-") next
        value = (field in after) ? after[field] : "-"
        delta = "-"
        if (before ~ /^-?[0-9]+$/ && value ~ /^-?[0-9]+$/) {
            difference = value - before
            delta = sprintf("%+d", difference)
        }
        printf "%s\t%s\t%s\t%s\n", field, before, value, delta
    }
' "$control_receipt"

# The first divergence names the layer that carried the change; the last names
# the layer that still carries it. Reporting one alone loses the E4 reading
# where SPIR-V and NIR both differ and the ISA is identical, which says ACO
# performed the transformation on its own.
first_divergence=none
last_divergence=none
if [ "$spirv_state" = changed ]; then
    first_divergence=spirv
    last_divergence=spirv
fi
if [ "$nir_state" = changed ]; then
    if [ "$first_divergence" = none ]; then first_divergence=nir; fi
    last_divergence=nir
fi
if [ "$isa_state" = changed ]; then
    if [ "$first_divergence" = none ]; then first_divergence=isa; fi
    last_divergence=isa
fi

harness_alarm=-
if [ "$spirv_state" = same ]; then
    verdict=spirv_unchanged
    if [ "$isa_state" = changed ]; then
        harness_alarm=spirv_identical_isa_changed
    fi
elif [ "$isa_state" = changed ]; then
    verdict=isa_changed
elif [ "$nir_state" = same ]; then
    verdict=nir_canonicalized
else
    verdict=isa_identical
fi

printf '\nverdict\t%s\n' "$verdict"
printf 'first_divergence\t%s\n' "$first_divergence"
printf 'last_divergence\t%s\n' "$last_divergence"
printf 'harness_alarm\t%s\n' "$harness_alarm"
