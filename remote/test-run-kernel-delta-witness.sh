#!/bin/sh
set -eu

# run-kernel-delta-witness.sh loads a model four times on the Vulkan device, so
# what a workstation checks is the argument contract it applies before the first
# server start. Every case below is refused ahead of the executable test at the
# top of the script, and the closing case proves the defaults still reach that
# test rather than being caught by a validation pattern of their own.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
witness=$script_directory/run-kernel-delta-witness.sh
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

absent_server=$temporary_directory/absent-server
output_directory=$temporary_directory/out

# Each case names the variable, the value, and the phrase the refusal carries.
refuses() {
    case_name=$1
    expected_phrase=$2
    shift 2
    case_log=$temporary_directory/$case_name.log
    case_status=0
    env "$@" "$witness" "$absent_server" "$absent_server" model-id "$output_directory" \
        >"$case_log" 2>&1 || case_status=$?
    if [ "$case_status" -eq 2 ] && grep -q "$expected_phrase" "$case_log" &&
        [ ! -e "$output_directory" ]; then
        report 0 "$case_name"
    else
        report 1 "$case_name"
        printf 'status=%s log:\n' "$case_status" >&2
        cat "$case_log" >&2
    fi
}

# A run count the while loop never enters leaves every arm without a sample and
# still exits 0 through the analyzer, so zero and every non-integer spelling is
# refused where the count is read. An empty value takes the default through
# `${QWEN_WITNESS_RUNS:-2}`, so the pattern answers a written value alone.
refuses runs_zero 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=0
refuses runs_negative 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=-2
refuses runs_word 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=two

# float() reads inf and nan, and the verdict rests on `delta <= bound`: inf
# admits every difference and nan refuses every one.
refuses bound_infinite 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=inf
refuses bound_not_a_number 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=nan
refuses bound_negative 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=-0.001
refuses bound_double_point 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=0.0.1

# The defaults and a plain decimal reach the executable test, which is the
# refusal that follows both validation blocks.
refuses defaults_reach_the_executable_test 'server is not executable'
refuses decimal_bound_reaches_the_executable_test 'server is not executable' \
    QWEN_WITNESS_RUNS=3 QWEN_WITNESS_LOGPROB_BOUND=0.5

if [ "$failures" -ne 0 ]; then
    printf 'run_kernel_delta_witness_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'run_kernel_delta_witness_tests=passed\n'
