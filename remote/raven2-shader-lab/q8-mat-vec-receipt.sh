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
# This script defaults to --spirv-only. lab.sh's device mode creates a real
# Vulkan pipeline against whatever GPU the host exposes, and a host that is
# not the Raven2 appliance has no gfx902 part to ask: running it there
# would not fail, it would silently produce another vendor's ISA under a
# receipt that looks like this one. --allow-device opts into that mode
# for the one host where it answers the intended question, and the
# resulting receipt's own device_name and driver_name fields are what a
# reader checks before trusting it.

usage() {
    printf 'usage: %s SPV_DIRECTORY OUT_DIRECTORY [--allow-device] [--subgroup-only]\n' "$0" >&2
    printf '\nSPV_DIRECTORY is a remote/compile-q8-mat-vec-spv.sh output directory.\n' >&2
    printf 'Without --allow-device, both variants run through lab.sh --spirv-only.\n' >&2
    printf 'With --allow-device, both variants run a live pipeline creation; use\n' >&2
    printf 'this only on the Raven2 appliance.\n' >&2
    printf 'Without --subgroup-only, both the base and the subgroup-reduction\n' >&2
    printf 'variant run; --subgroup-only runs the variant this device actually\n' >&2
    printf 'dispatches at decode.\n' >&2
    exit 2
}

[ "$#" -ge 2 ] || usage

spv_directory=$1
out_directory=$2
shift 2

allow_device=0
subgroup_only=0
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
    *)
        printf 'unknown option: %s\n' "$1" >&2
        usage
        ;;
    esac
done

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
            --spec 0:64 --spec 1:2 --spec 2:1 --subgroup 64 \
            --bindings 5 --push-constants 52 --per-superblock 32
    else
        "$lab_sh" "$spv_path" "$variant_out" --spirv-only \
            --per-superblock 32
    fi
    if [ -r "$variant_out/isa.s" ]; then
        python3 "$depth_py" "$variant_out/isa.s" "$variant_out/depth.tsv"
    fi
done

printf 'wrote receipts under %s for: %s\n' "$out_directory" "$variants" >&2
