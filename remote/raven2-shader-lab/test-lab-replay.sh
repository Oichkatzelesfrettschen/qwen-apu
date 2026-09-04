#!/bin/sh
set -eu

# lab.sh reaches a RADV part on its device path alone, so the replay path is
# what a workstation runs: a recorded pair of streams stands in for pipeline
# creation and the extraction, the statistic reader, and the receipt writer are
# the tree's own. What this test adds to that path is the environment row --
# the RADV, VK, MESA, and GGML_VK names that survived the scrub the run went
# through -- and the refusal receipt-diff.sh states when two receipts disagree
# on it.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
lab=$script_directory/lab.sh
differ=$script_directory/receipt-diff.sh
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

# The module is a stand-in the replay never compiles: the recorded streams
# decide every value the receipt reads past spirv_sha256 and spirv_bytes.
cat >"$temporary_directory/probe.comp" <<'SHADER'
#version 450
layout(local_size_x = 64) in;
layout(binding = 0) buffer Data { float values[]; };
void main() { values[gl_GlobalInvocationID.x] += 1.0; }
SHADER
glslangValidator -V "$temporary_directory/probe.comp" \
    -o "$temporary_directory/probe.spv" >/dev/null

expected_names=$(awk -F= '$1 == "environment_names" { print $2 }' \
    "$fixtures/replay-control/harness.txt")

receipt_field() {
    awk -F'\t' -v key="$2" '$1 == key { print $2; exit }' "$1" 2>/dev/null || true
}

control_output=$temporary_directory/control
replay_status=0
QWEN_SHADER_LAB_REPLAY_DIR=$fixtures/replay-control \
    "$lab" "$temporary_directory/probe.spv" "$control_output" \
    >"$temporary_directory/control.log" 2>&1 || replay_status=$?
if [ "$replay_status" -eq 0 ] &&
    [ "$(receipt_field "$control_output/receipt.tsv" run_mode)" = replay ] &&
    [ "$(receipt_field "$control_output/receipt.tsv" environment_names)" = "$expected_names" ]; then
    report 0 replay_receipt_records_the_surviving_environment
else
    report 1 replay_receipt_records_the_surviving_environment
    cat "$temporary_directory/control.log" >&2
fi

# A second replay whose recording names one further driver setting is the
# ambient environment this scrub exists to remove, and the two receipts then
# describe two runs rather than two sources.
ambient_fixture=$temporary_directory/replay-ambient
mkdir -p "$ambient_fixture"
cp "$fixtures/replay-candidate/radv-debug.log" "$ambient_fixture/radv-debug.log"
sed 's/^environment_names=.*/&,RADV_PERFTEST/' \
    "$fixtures/replay-candidate/harness.txt" >"$ambient_fixture/harness.txt"
ambient_output=$temporary_directory/ambient
QWEN_SHADER_LAB_REPLAY_DIR=$ambient_fixture \
    "$lab" "$temporary_directory/probe.spv" "$ambient_output" \
    >"$temporary_directory/ambient.log" 2>&1
differ_status=0
"$differ" "$control_output" "$ambient_output" \
    >"$temporary_directory/differ.log" 2>&1 || differ_status=$?
if [ "$differ_status" -eq 1 ] &&
    grep -q 'execution contract differs.*environment_names' \
        "$temporary_directory/differ.log"; then
    report 0 receipt_diff_refuses_a_differing_environment
else
    report 1 receipt_diff_refuses_a_differing_environment
    cat "$temporary_directory/differ.log" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'shader_lab_replay_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'shader_lab_replay_tests=passed\n'
