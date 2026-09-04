#!/bin/sh
set -eu

# Compiles the two Q8_0 mat-vec SPIR-V variants ggml-vulkan.cpp builds at the
# served spec constants, from a pinned llama.cpp source tree, on a host that
# holds no gfx902 device. glslc's frontend is the same on any host; only the
# RADV backend that turns this SPIR-V into gfx902 ISA needs the appliance, so
# this script is the workstation half of the Q8_0 shader identity and
# raven2-shader-lab/lab.sh's device or replay mode is the other half.
#
# ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp routes every
# non-K-quant, non-IQ, non-tq2_0 type through mul_mat_vec.comp with
# -DDATA_A_Q8_0=1, and ggml-vulkan.cpp selects, for GGML_TYPE_Q8_0 on a
# device the AMD_GCN branch classifies (subgroup min size == max size == 64,
# vendor AMD): rm_stdq=2, so NUM_ROWS is 2 where the Q4_K/Q5_K/Q6_K family's
# rm_kq=4 makes NUM_ROWS 4; wg_size_subgroup=64, the same BLOCK_SIZE the
# K-quant family runs at; and, at the decode dispatch shape (w ==
# DMMV_WG_SIZE_SUBGROUP, one token), reduc == SHADER_REDUCTION_MODE_SUBGROUP,
# the same reduction mode E1's retained Q4_K and Q6_K receipts record, which
# is what licenses USE_SUBGROUP_ADD=1 as the matching macro here rather than
# an assumption: both the base and the subgroup variant are compiled, and
# the subgroup variant's OpCapability list is checked against the retained
# receipts' spirv_capabilities field.

usage() {
    printf 'usage: %s SOURCE_DIRECTORY OUTPUT_DIRECTORY\n' "$0" >&2
    printf '\nSOURCE_DIRECTORY holds ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec.comp\n' >&2
    printf 'at commit f280b26983ad0fdb705a0d9ebf0503e76f2899b0 (or\n' >&2
    printf 'QWEN_ALLOW_ANY_COMMIT=1 to compile another checkout).\n' >&2
    printf '\nenvironment:\n' >&2
    printf '  QWEN_GLSLC              glslc binary, defaults to "glslc"\n' >&2
    printf '  QWEN_ALLOW_ANY_COMMIT=1 compile a source tree off the pinned commit\n' >&2
    exit 2
}

[ "$#" -eq 2 ] || usage

source_directory=$1
output_directory=$2
expected_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
glslc_binary=${QWEN_GLSLC:-glslc}
allow_any_commit=${QWEN_ALLOW_ANY_COMMIT:-0}

shader_directory="$source_directory/ggml/src/ggml-vulkan/vulkan-shaders"
shader_source="$shader_directory/mul_mat_vec.comp"

[ -f "$shader_source" ] || {
    printf '%s: %s absent\n' "$0" "$shader_source" >&2
    exit 2
}

if [ "$allow_any_commit" != 1 ]; then
    actual_commit=$(git -C "$source_directory" rev-parse HEAD 2>/dev/null || echo "")
    [ "$actual_commit" = "$expected_commit" ] || {
        printf '%s: %s is at %s, expected %s (or set QWEN_ALLOW_ANY_COMMIT=1)\n' \
            "$0" "$source_directory" "${actual_commit:-unreadable}" "$expected_commit" >&2
        exit 2
    }
fi

command -v "$glslc_binary" >/dev/null 2>&1 || {
    printf '%s: %s not found\n' "$0" "$glslc_binary" >&2
    exit 2
}

mkdir -p "$output_directory"

compile() {
    variant_name=$1
    shift
    "$glslc_binary" -fshader-stage=compute --target-env=vulkan1.2 \
        "$shader_source" -o "$output_directory/$variant_name.spv" -O \
        -DFLOAT_TYPE=float -DFLOAT_TYPEV2=vec2 -DDATA_A_Q8_0=1 \
        -DB_TYPE=float -DB_TYPEV2=vec2 -DB_TYPEV4=vec4 -DD_TYPE=float \
        "$@"
}

# SHADER_REDUCTION_MODE_SHMEM: no reduction macro defined.
compile mul_mat_vec_q8_0_f32_f32
# SHADER_REDUCTION_MODE_SUBGROUP: the mode this device selects at decode.
compile mul_mat_vec_q8_0_f32_f32_subgroup -DUSE_SUBGROUP_ADD=1

manifest="$output_directory/manifest.tsv"
{
    printf 'variant\tspec_constants\tblock_size_note\tsha256\tbytes\n'
    for variant_name in mul_mat_vec_q8_0_f32_f32 mul_mat_vec_q8_0_f32_f32_subgroup; do
        spv_path="$output_directory/$variant_name.spv"
        digest=$(sha256sum "$spv_path" | cut -d' ' -f1)
        byte_count=$(wc -c <"$spv_path")
        printf '%s\t0:64,1:2,2:1\tQUANT_K=32, not 256\t%s\t%s\n' \
            "$variant_name" "$digest" "$byte_count"
    done
} >"$manifest"

printf 'wrote %s and %s\n' "$output_directory" "$manifest" >&2
