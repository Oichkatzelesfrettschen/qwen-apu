#!/bin/sh
set -eu

# Runs lab.sh and depth.py over the served-shape Q8_0 mat-vec pipeline, the
# way evidence/raven2-vulkan-kernel-census/e1/ ran the pinned Q4_K and Q6_K
# pair, so a Q8_0 receipt.tsv and depth.tsv join that directory's naming and
# a reader can diff the three side by side.
#
# The spec constants below are the ggml-vulkan.cpp Q8_0 dispatch geometry at
# decode (GGML_TYPE_Q8_0, one token, AMD_GCN device classification):
# BLOCK_SIZE=64, NUM_ROWS=2 (rm_stdq, not the K-quant family's rm_kq=4),
# NUM_COLS=1, subgroup 64 -- see remote/compile-q8-mat-vec-spv.sh for the
# ggml-vulkan.cpp lines this reads. --per-superblock states 32, Q8_0's
# QUANT_K, where the K-quant receipts state 256; a per-superblock figure
# read off this receipt with the retained divisor is comparing 32 weights
# against 256 and is wrong by 8x before any instruction count is read.
#
# --num-rows states NUM_ROWS and --num-cols states NUM_COLS, the two constants
# a candidate arm moves.
# `mul_mat_vec_base.glsl` declares them `layout (constant_id = 1) const uint
# NUM_ROWS = 1` and `layout (constant_id = 2) const uint NUM_COLS = 1`, so one
# SPIR-V module serves every row and column count and each value
# reaches ACO through the pipeline's specialization rather than through the
# glslc frontend. A pair therefore can differ by this argument alone, which is
# a prerequisite on the caller rather than a property this script enforces:
# each invocation reads whatever SPV_DIRECTORY and variant selection it is
# given, so a control and a candidate share a module digest exactly where the
# caller names one directory and one variant set for both, and the retained
# receipts' own digest fields are what a reader checks. That also bounds where
# an arm runs. lab.sh applies no
# specialization under --spirv-only, so two --spirv-only receipts taken at
# different row or column counts are the same bytes under two arm labels, and a
# --num-rows away from the served 2 or a --num-cols away from the served 1
# requires --allow-device rather than producing a receipt that looks like a
# measurement and holds none. A column count above 1 is the verification pass a
# speculative step submits, where the target scores the drafted tokens beside
# the accepted one through the same GEMV pipeline at a wider NUM_COLS.
#
# This script defaults to --spirv-only. lab.sh's device mode creates a real
# Vulkan pipeline against whatever GPU the host exposes, and a host that is
# not the Raven2 appliance has no gfx902 part to ask: running it there
# would not fail, it would silently produce another vendor's ISA under a
# receipt that looks like this one. --allow-device opts into that mode
# for the one host where it answers the intended question, and the
# resulting receipt's own device_name and driver_name fields are what a
# reader checks before trusting it.

usage() {
    printf 'usage: %s SPV_DIRECTORY OUT_DIRECTORY [--allow-device] [--subgroup-only] [--num-rows N] [--num-cols N]\n' "$0" >&2
    printf '\nSPV_DIRECTORY is a remote/compile-q8-mat-vec-spv.sh output directory.\n' >&2
    printf 'Without --allow-device, both variants run through lab.sh --spirv-only.\n' >&2
    printf 'With --allow-device, both variants run a live pipeline creation; use\n' >&2
    printf 'this only on the Raven2 appliance.\n' >&2
    printf 'Without --subgroup-only, both the base and the subgroup-reduction\n' >&2
    printf 'variant run; --subgroup-only runs the variant this device actually\n' >&2
    printf 'dispatches at decode.\n' >&2
    printf '%s\n' '--num-rows N sets NUM_ROWS, specialization constant 1, and' >&2
    printf 'defaults to 2, the served value. A value away from 2 requires\n' >&2
    printf '%s\n' '--allow-device, since --spirv-only applies no specialization.' >&2
    printf '%s\n' '--num-cols N sets NUM_COLS, specialization constant 2, and' >&2
    printf 'defaults to 1, the served value. A value away from 1 requires\n' >&2
    printf '%s\n' '--allow-device under the same rule, and states the width of a' >&2
    printf 'speculative verification pass.\n' >&2
    exit 2
}

[ "$#" -ge 2 ] || usage

spv_directory=$1
out_directory=$2
shift 2

allow_device=0
subgroup_only=0
served_num_rows=2
num_rows=$served_num_rows
served_num_cols=1
num_cols=$served_num_cols
while [ "$#" -gt 0 ]; do
    case $1 in
    --allow-device)
        allow_device=1
        shift
        ;;
    --subgroup-only)
        subgroup_only=1
        shift
        ;;
    --num-rows)
        [ "$#" -ge 2 ] || usage
        num_rows=$2
        shift 2
        ;;
    --num-cols)
        [ "$#" -ge 2 ] || usage
        num_cols=$2
        shift 2
        ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        usage
        ;;
    esac
done

# Both constants take the same value space and the same layer rule, so one
# function states it once for the row count and the column count.
# A specialization constant is a uint32, and a decimal wider than the shell's
# own arithmetic makes `test -gt` fail rather than answer. That failure inside
# an `if` condition returns non-zero without tripping errexit, so an unbounded
# value would read as "no refusal needed" and reach the pipeline; the width is
# checked as a string first and the range only afterward.
#
# lab.sh reaches ACO through pipeline creation, so the specialization exists
# only in device mode. A --spirv-only run at another count writes the control's
# own bytes under a candidate's name, which is a receipt that reads like an arm
# and measures nothing. Every admitted value is a canonical decimal by the rules
# above, so string inequality is numeric inequality and the safety branch needs
# no arithmetic that a malformed value could break.
validate_constant() {
    validate_flag=$1
    validate_id=$2
    validate_value=$3
    validate_served=$4
    case $validate_value in
    '' | *[!0-9]*)
        printf '%s: %s takes a positive decimal integer: %s\n' \
            "$0" "$validate_flag" "$validate_value" >&2
        exit 2
        ;;
    0 | 0*)
        printf '%s: %s takes a positive decimal integer without a leading zero: %s\n' \
            "$0" "$validate_flag" "$validate_value" >&2
        exit 2
        ;;
    esac
    if [ "${#validate_value}" -gt 10 ] || [ "$validate_value" -gt 4294967295 ]; then
        printf '%s: %s exceeds the uint32 a specialization constant holds: %s\n' \
            "$0" "$validate_flag" "$validate_value" >&2
        exit 2
    fi
    if [ "$validate_value" != "$validate_served" ] && [ "$allow_device" -eq 0 ]; then
        printf '%s: %s %s applies specialization constant %s, which reaches the compiler at pipeline creation alone; pass --allow-device on the Raven2 appliance, since --spirv-only would write the served %s receipt under this count\n' \
            "$0" "$validate_flag" "$validate_value" "$validate_id" \
            "$validate_served" >&2
        exit 2
    fi
}

validate_constant --num-rows 1 "$num_rows" "$served_num_rows"
validate_constant --num-cols 2 "$num_cols" "$served_num_cols"

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
lab_sh="$script_directory/lab.sh"
depth_py="$script_directory/depth.py"

[ -x "$lab_sh" ] || {
    printf '%s: %s is not executable\n' "$0" "$lab_sh" >&2
    exit 2
}
[ -d "$spv_directory" ] || {
    printf '%s: %s is not a directory\n' "$0" "$spv_directory" >&2
    exit 2
}
[ -e "$out_directory" ] && {
    printf '%s: %s already exists, refusing to overwrite\n' "$0" "$out_directory" >&2
    exit 1
}

mkdir -p -- "$out_directory"

if [ "$subgroup_only" -eq 1 ]; then
    variants='mul_mat_vec_q8_0_f32_f32_subgroup'
else
    variants='mul_mat_vec_q8_0_f32_f32 mul_mat_vec_q8_0_f32_f32_subgroup'
fi

for variant_name in $variants; do
    spv_path="$spv_directory/$variant_name.spv"
    [ -r "$spv_path" ] || {
        printf '%s: %s is not readable\n' "$0" "$spv_path" >&2
        exit 2
    }
    variant_out="$out_directory/$variant_name"
    if [ "$allow_device" -eq 1 ]; then
        "$lab_sh" "$spv_path" "$variant_out" \
            --spec 0:64 --spec "1:$num_rows" --spec "2:$num_cols" --subgroup 64 \
            --bindings 5 --push-constants 52 --per-superblock 32
    else
        "$lab_sh" "$spv_path" "$variant_out" --spirv-only \
            --per-superblock 32
    fi
    if [ -r "$variant_out/isa.s" ]; then
        python3 "$depth_py" "$variant_out/isa.s" "$variant_out/depth.tsv"
    fi
done

# The arm a directory holds is a property of the run rather than of the module,
# since one SPIR-V serves every row count. The record states it so a retained
# pair is read as a pair rather than by the order it was taken in, and it names
# the layer, because a spirv-only directory carries no specialization at all.
# Every row is written through one %s triple, because a format string opening
# on the `-` that marks a row outside the constant space reads as an option.
if [ "$allow_device" -eq 1 ]; then
    specialization_applied=yes
    specialization_layer=device
else
    specialization_applied=no
    specialization_layer=spirv-only
fi
{
    printf '%s\t%s\t%s\n' constant_id name value
    printf '%s\t%s\t%s\n' 0 BLOCK_SIZE 64
    printf '%s\t%s\t%s\n' 1 NUM_ROWS "$num_rows"
    printf '%s\t%s\t%s\n' 2 NUM_COLS "$num_cols"
    printf '%s\t%s\t%s\n' - subgroup_size 64
    printf '%s\t%s\t%s\n' - served_num_rows "$served_num_rows"
    printf '%s\t%s\t%s\n' - served_num_cols "$served_num_cols"
    printf '%s\t%s\t%s\n' - specialization_applied "$specialization_applied"
    printf '%s\t%s\t%s\n' - layer "$specialization_layer"
} >"$out_directory/specialization.tsv"

printf 'wrote receipts under %s at NUM_ROWS=%s NUM_COLS=%s for: %s\n' \
    "$out_directory" "$num_rows" "$num_cols" "$variants" >&2
