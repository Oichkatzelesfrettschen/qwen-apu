#!/bin/sh
set -eu

# remote/rocm10-ladder.sh drives a real hipcc and a real device, so its own
# gates are checked here against remote/test-fixtures/rocm10-fake-hipcc.sh and
# remote/test-fixtures/rocm10-fake-rocminfo.sh instead: the prefix refusal
# ahead of any rung, HSA_ENABLE_SDMA=0 exported on every recorded invocation,
# the stop-at-first-failure rule leaving every rung past the failure absent
# from the ledger, and the two device-library-resolution paths (rocminfo
# present, and the HIP-runtime fallback when it is absent).

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ladder=$script_directory/rocm10-ladder.sh
fake_hipcc=$script_directory/test-fixtures/rocm10-fake-hipcc.sh
fake_rocminfo=$script_directory/test-fixtures/rocm10-fake-rocminfo.sh

temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'rocm10_ladder_fixture_directory=%s\n' "$temporary_directory" >&2
    else
        rm -rf -- "$temporary_directory"
    fi
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

make_prefix() {
    # make_prefix DIRECTORY [with-rocminfo] [with-hipblas]
    prefix_directory=$1
    mkdir -p "$prefix_directory/bin"
    cp "$fake_hipcc" "$prefix_directory/bin/hipcc"
    chmod +x "$prefix_directory/bin/hipcc"
    if [ "${2:-}" = with-rocminfo ]; then
        cp "$fake_rocminfo" "$prefix_directory/bin/rocminfo"
        chmod +x "$prefix_directory/bin/rocminfo"
    fi
    if [ "${3:-}" = with-hipblas ]; then
        mkdir -p "$prefix_directory/include/hipblas"
        : > "$prefix_directory/include/hipblas/hipblas.h"
    fi
}

# --- prefix refusal --------------------------------------------------------
bare_prefix=$temporary_directory/bare-prefix
mkdir -p "$bare_prefix/bin"
refusal_output=$temporary_directory/refusal-output
refusal_log=$temporary_directory/refusal.log
if "$ladder" "$bare_prefix" "$refusal_output" >"$refusal_log" 2>&1; then
    refusal_status=0
else
    refusal_status=$?
fi
if [ "$refusal_status" != 0 ] && grep -q 'no hipcc under the isolated prefix' "$refusal_log" &&
    grep -q '/opt/rocm' "$refusal_log" && [ ! -e "$refusal_output/ladder.tsv" ]
then
    report 0 'a prefix without bin/hipcc is refused, names the reason, and runs no rung'
else
    report 1 'a prefix without bin/hipcc is refused, names the reason, and runs no rung'
fi

# An ambient ROCM_PATH pointing elsewhere must not rescue a bad prefix, since
# the isolated PREFIX argument is the sole source of ROCm identity.
ambient_output=$temporary_directory/ambient-output
if ROCM_PATH=/opt/rocm "$ladder" "$bare_prefix" "$ambient_output" >/dev/null 2>&1; then
    ambient_status=0
else
    ambient_status=$?
fi
if [ "$ambient_status" != 0 ] && [ ! -e "$ambient_output/ladder.tsv" ]; then
    report 0 'an ambient ROCM_PATH does not rescue a prefix missing bin/hipcc'
else
    report 1 'an ambient ROCM_PATH does not rescue a prefix missing bin/hipcc'
fi

# --- everything passes, rocminfo present -----------------------------------
full_prefix=$temporary_directory/full-prefix
make_prefix "$full_prefix" with-rocminfo with-hipblas
full_output=$temporary_directory/full-output
full_log=$temporary_directory/full.log
QWEN_ROCM10_FAKE_LOG=$full_log "$ladder" "$full_prefix" "$full_output" >/dev/null 2>&1
recorded_rungs=$(cut -f1 "$full_output/ladder.tsv" | tail -n +2 | tr '\n' ' ')
if [ "$recorded_rungs" = 'compile enumerate vector-add wave64-lds device-libraries blas-call llama-bench ' ]
then
    report 0 'every rung runs in order when nothing refuses'
else
    report 1 "every rung runs in order when nothing refuses (got: $recorded_rungs)"
fi

if grep -q 'llama-bench	.*	n/a	skip' "$full_output/ladder.tsv"; then
    report 0 'llama-bench is skipped rather than failed when its binary and model are unset'
else
    report 1 'llama-bench is skipped rather than failed when its binary and model are unset'
fi

if grep -q '^compile	.*v_mad_mix_f32_selected=no' "$full_output/ladder.tsv"; then
    report 0 'the compile rung reports v_mad_mix_f32 selection as a fact, not as pass/fail'
else
    report 1 'the compile rung reports v_mad_mix_f32 selection as a fact, not as pass/fail'
fi

# --- HSA_ENABLE_SDMA=0 on every recorded invocation -------------------------
sdma_lines=$(grep -c '^HSA_ENABLE_SDMA=' "$full_log")
sdma_zero_lines=$(grep -c '^HSA_ENABLE_SDMA=0 ' "$full_log")
if [ "$sdma_lines" -gt 0 ] && [ "$sdma_lines" = "$sdma_zero_lines" ]; then
    report 0 "HSA_ENABLE_SDMA=0 on every one of $sdma_lines recorded hipcc and rocminfo invocations"
else
    report 1 "HSA_ENABLE_SDMA=0 on every recorded invocation ($sdma_zero_lines of $sdma_lines)"
fi

if ! grep -q '^run:' "$full_log"; then
    report 1 'the fabricated binaries themselves ran under HSA_ENABLE_SDMA=0'
else
    report 0 'the fabricated binaries themselves ran under HSA_ENABLE_SDMA=0'
fi

# --- v_mad_mix_f32 selected: reported true when the fixture carries it -----
selected_prefix=$temporary_directory/selected-prefix
make_prefix "$selected_prefix" with-rocminfo with-hipblas
selected_output=$temporary_directory/selected-output
QWEN_ROCM10_FAKE_MAD_MIX_PRESENT=1 "$ladder" "$selected_prefix" "$selected_output" >/dev/null 2>&1
if grep -q '^compile	.*v_mad_mix_f32_selected=yes' "$selected_output/ladder.tsv"; then
    report 0 'the compile rung reports v_mad_mix_f32 selection as yes when the ISA carries it'
else
    report 1 'the compile rung reports v_mad_mix_f32 selection as yes when the ISA carries it'
fi

# --- rocminfo absent: falls back to the HIP-runtime enumeration path -------
no_rocminfo_prefix=$temporary_directory/no-rocminfo-prefix
make_prefix "$no_rocminfo_prefix" "" with-hipblas
no_rocminfo_output=$temporary_directory/no-rocminfo-output
"$ladder" "$no_rocminfo_prefix" "$no_rocminfo_output" >/dev/null 2>&1
if grep -q '^enumerate	.*method=hip-runtime' "$no_rocminfo_output/ladder.tsv"; then
    report 0 'enumerate falls back to the HIP runtime when the prefix ships no rocminfo'
else
    report 1 'enumerate falls back to the HIP runtime when the prefix ships no rocminfo'
fi

# --- hipBLAS absent from the prefix: blas-call fails and stops the ladder --
no_blas_prefix=$temporary_directory/no-blas-prefix
make_prefix "$no_blas_prefix" with-rocminfo
no_blas_output=$temporary_directory/no-blas-output
"$ladder" "$no_blas_prefix" "$no_blas_output" >/dev/null 2>&1
no_blas_rungs=$(cut -f1 "$no_blas_output/ladder.tsv" | tail -n +2 | tr '\n' ' ')
if [ "$no_blas_rungs" = 'compile enumerate vector-add wave64-lds device-libraries blas-call ' ] &&
    grep -q '^blas-call	.*	fail	' "$no_blas_output/ladder.tsv"
then
    report 0 'blas-call fails and ends the ladder when the prefix carries no hipBLAS header'
else
    report 1 "blas-call fails and ends the ladder when the prefix carries no hipBLAS header (got: $no_blas_rungs)"
fi

# --- stop at first failure, one rung at a time ------------------------------
# device_enum is the HIP-runtime fallback enumerate uses only when the prefix
# ships no rocminfo, so its own prefix omits rocminfo deliberately.
for fail_at in kernel device_enum vector_add wave64_lds device-libraries blas_call; do
    stage_prefix=$temporary_directory/stage-$fail_at
    if [ "$fail_at" = device_enum ]; then
        make_prefix "$stage_prefix" "" with-hipblas
    else
        make_prefix "$stage_prefix" with-rocminfo with-hipblas
    fi
    stage_output=$temporary_directory/stage-$fail_at-output
    QWEN_ROCM10_FAKE_FAIL_STAGE=$fail_at "$ladder" "$stage_prefix" "$stage_output" >/dev/null 2>&1
    last_rung=$(cut -f1 "$stage_output/ladder.tsv" | tail -n 1)
    last_result=$(cut -f4 "$stage_output/ladder.tsv" | tail -n 1)
    rung_count=$(($(wc -l < "$stage_output/ladder.tsv") - 1))
    if [ "$last_result" = fail ] && [ "$rung_count" -ge 1 ]; then
        report 0 "a failure at $fail_at stops the ladder at $last_rung with no rung after it"
    else
        report 1 "a failure at $fail_at stops the ladder at $last_rung with no rung after it (result=$last_result rungs=$rung_count)"
    fi
done

# The enumerate-fail case uses rocminfo, which QWEN_ROCM10_FAKE_FAIL_STAGE
# also refuses on its own name.
enumerate_prefix=$temporary_directory/stage-enumerate
make_prefix "$enumerate_prefix" with-rocminfo with-hipblas
enumerate_output=$temporary_directory/stage-enumerate-output
QWEN_ROCM10_FAKE_FAIL_STAGE=enumerate "$ladder" "$enumerate_prefix" "$enumerate_output" >/dev/null 2>&1
enumerate_rungs=$(cut -f1 "$enumerate_output/ladder.tsv" | tail -n +2 | tr '\n' ' ')
if [ "$enumerate_rungs" = 'compile enumerate ' ] &&
    grep -q '^enumerate	.*	fail	' "$enumerate_output/ladder.tsv"
then
    report 0 'a rocminfo failure stops the ladder at enumerate with no rung after it'
else
    report 1 "a rocminfo failure stops the ladder at enumerate with no rung after it (got: $enumerate_rungs)"
fi

# --- llama-bench: an unset environment skips rather than fails, and every
# earlier rung still passed --------------------------------------------------
if grep -q '^compile	.*	pass	' "$full_output/ladder.tsv" &&
    grep -q '^blas-call	.*	pass	' "$full_output/ladder.tsv"
then
    report 0 'llama-bench is reached only after every lower rung passed'
else
    report 1 'llama-bench is reached only after every lower rung passed'
fi

# --- device-libraries: a gfx900 compatibility shim for a gfx902 request must
# fail rather than pass on an unrelated nonempty bitcode list -----------------
shim_prefix=$temporary_directory/shim-prefix
make_prefix "$shim_prefix" with-rocminfo with-hipblas
shim_output=$temporary_directory/shim-output
QWEN_ROCM10_FAKE_BITCODE_SUFFIX=900 "$ladder" "$shim_prefix" "$shim_output" >/dev/null 2>&1
shim_rungs=$(cut -f1 "$shim_output/ladder.tsv" | tail -n +2 | tr '\n' ' ')
if [ "$shim_rungs" = 'compile enumerate vector-add wave64-lds device-libraries ' ] &&
    grep -q '^device-libraries	.*	fail	' "$shim_output/ladder.tsv"
then
    report 0 'device-libraries fails a gfx900 bitcode set resolved for a gfx902 request'
else
    report 1 "device-libraries fails a gfx900 bitcode set resolved for a gfx902 request (got: $shim_rungs)"
fi

# --- LD_LIBRARY_PATH carries no ambient entry -------------------------------
ambient_lib_prefix=$temporary_directory/ambient-lib-prefix
make_prefix "$ambient_lib_prefix" with-rocminfo with-hipblas
ambient_lib_output=$temporary_directory/ambient-lib-output
ambient_lib_log=$temporary_directory/ambient-lib.log
LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64 \
QWEN_ROCM10_FAKE_LOG=$ambient_lib_log \
    "$ladder" "$ambient_lib_prefix" "$ambient_lib_output" >/dev/null 2>&1
if grep -q 'LD_LIBRARY_PATH=/opt/rocm' "$ambient_lib_log"; then
    report 1 'an ambient LD_LIBRARY_PATH entry does not survive into a rung invocation'
else
    report 0 'an ambient LD_LIBRARY_PATH entry does not survive into a rung invocation'
fi

# --- a rerun into an existing OUTPUT_DIR does not read a prior compile's
# stale .s file -------------------------------------------------------------
rerun_prefix=$temporary_directory/rerun-prefix
make_prefix "$rerun_prefix" with-rocminfo with-hipblas
rerun_output=$temporary_directory/rerun-output
QWEN_ROCM10_FAKE_MAD_MIX_PRESENT=1 "$ladder" "$rerun_prefix" "$rerun_output" >/dev/null 2>&1
"$ladder" "$rerun_prefix" "$rerun_output" >/dev/null 2>&1
if grep -q '^compile	.*v_mad_mix_f32_selected=no' "$rerun_output/ladder.tsv"; then
    report 0 'a rerun into the same OUTPUT_DIR reports the current compile, not a stale one'
else
    report 1 'a rerun into the same OUTPUT_DIR reports the current compile, not a stale one'
fi

# --- llama-bench: an absent binary fails and is the terminal rung ----------
absent_bench_prefix=$temporary_directory/absent-bench-prefix
make_prefix "$absent_bench_prefix" with-rocminfo with-hipblas
absent_bench_output=$temporary_directory/absent-bench-output
QWEN_ROCM10_LLAMA_BENCH=$temporary_directory/no-such-llama-bench \
QWEN_ROCM10_MODEL=$temporary_directory/no-such-model.gguf \
    "$ladder" "$absent_bench_prefix" "$absent_bench_output" >/dev/null 2>&1
if grep -q '^llama-bench	.*	fail	' "$absent_bench_output/ladder.tsv"; then
    report 0 'llama-bench fails outright when its named binary does not exist'
else
    report 1 'llama-bench fails outright when its named binary does not exist'
fi

if [ "$failures" -eq 0 ]; then
    printf 'rocm10_ladder_tests=passed\n'
    exit 0
fi
printf 'rocm10_ladder_tests=failed count=%s\n' "$failures" >&2
exit 1
