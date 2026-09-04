#!/bin/sh
set -eu

# lab.sh's count_instruction_classes counted v_mul_lo_u32, v_mad_u32_u24,
# v_mad_i32_i24, and v_mul_u32_u24 without counting v_mul_i32_i24 or
# v_add3_u32, so the E5-int24 evidence's own "extension" arm read zero
# multiplies in every counted field of its receipt even though 224 of them
# are v_mul_i32_i24_sdwa (evidence/raven2-vulkan-kernel-census/e5/
# isa-shimmed-raven2/README.md, "A lab defect this run exposes"). This test
# replays a fixture whose disasm block carries a known count of both
# mnemonics -- three v_mul_i32_i24_sdwa and two v_add3_u32, the encodings
# PR #2115's target-aware soft-sdot lowering emits on GFX9 -- and fails if
# the receipt does not read those exact counts back.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
lab=$script_directory/lab.sh
fixtures=$script_directory/test-fixtures

for required_tool in glslangValidator spirv-dis; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$required_tool" >&2
        exit 2
    fi
done

temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

# The module is a stand-in the replay never compiles: the fixture's recorded
# disasm block decides every count this test reads.
cat >"$temporary_directory/probe.comp" <<'SHADER'
#version 450
layout(local_size_x = 64) in;
layout(binding = 0) buffer Data { float values[]; };
void main() { values[gl_GlobalInvocationID.x] += 1.0; }
SHADER
glslangValidator -V "$temporary_directory/probe.comp" \
    -o "$temporary_directory/probe.spv" >/dev/null

receipt_field() {
    awk -F'\t' -v key="$2" '$1 == key { print $2; exit }' "$1" 2>/dev/null || true
}

output_directory=$temporary_directory/out
QWEN_SHADER_LAB_REPLAY_DIR=$fixtures/replay-i24-add3 \
    "$lab" "$temporary_directory/probe.spv" "$output_directory" \
    >"$temporary_directory/lab.log" 2>&1

receipt=$output_directory/receipt.tsv

if [ "$(receipt_field "$receipt" v_mul_i32_i24)" = 3 ]; then
    report 0 receipt_counts_v_mul_i32_i24
else
    report 1 receipt_counts_v_mul_i32_i24
    cat "$temporary_directory/lab.log" >&2
fi

if [ "$(receipt_field "$receipt" v_add3_u32)" = 2 ]; then
    report 0 receipt_counts_v_add3_u32
else
    report 1 receipt_counts_v_add3_u32
    cat "$temporary_directory/lab.log" >&2
fi

# The u32/u24 and lo_u32 fields this test does not exercise stay at their
# fixture value of zero, so the new fields land beside working ones rather
# than displacing them.
if [ "$(receipt_field "$receipt" v_mul_u32_u24)" = 0 ] &&
    [ "$(receipt_field "$receipt" v_mul_lo_u32)" = 0 ]; then
    report 0 unrelated_multiply_fields_stay_zero
else
    report 1 unrelated_multiply_fields_stay_zero
    cat "$temporary_directory/lab.log" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'lab_count_i24_add3_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'lab_count_i24_add3_tests=passed\n'
