#!/bin/sh
set -eu

# Measure the HIP and Vulkan backends from one binary, one phase at a time.
#
# `build-llama-dual.sh` configures both backends against one source commit, so
# `llama-bench --device` selects between them and a difference between two rows
# is a difference between two backends. Prompt processing and token generation
# run as separate invocations with the unused side set to zero, because a
# combined run reports one elapsed time for two mechanisms and a change that
# moves only one of them stays invisible.
#
# Every HIP arm exports HSA_ENABLE_SDMA=0. With the copy engine enabled,
# `llama_model_loader::load_all_data` parks in `hipEventSynchronize` and never
# returns; evidence/rocm-h0-operational-failure.md records that stall and the
# 19-second run that the same binary completes once the variable is set.
#
# Each phase carries a timeout. A backend an order of magnitude outside the
# serving range answers the operational question by exceeding it, and a run that
# cannot finish inside the limit has already lost to the reference.

usage() {
    printf 'usage: %s [OUTPUT]\n' "$0" >&2
    printf '  QWEN_MODEL_PATH     checkpoint under test\n' >&2
    printf '  QWEN_MATRIX_TIMEOUT seconds per phase, default 600\n' >&2
    printf '  QWEN_MATRIX_REPS    repetitions per phase, default 1\n' >&2
    exit 2
}

[ "$#" -le 1 ] || usage

output_path=${1:-"${HOME:?}/qwen-model-comparison/rocm-vulkan-matrix.txt"}
model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf"}
phase_timeout=${QWEN_MATRIX_TIMEOUT:-600}
repetitions=${QWEN_MATRIX_REPS:-1}
binary_directory=${QWEN_DUAL_BIN:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-dual/bin"}
rocm_path=${ROCM_PATH:-"${HOME:?}/.venvs/rocm-gfx900/lib/python3.12/site-packages/_rocm_sdk_devel"}

[ -f "$model_path" ] || { printf 'checkpoint is absent: %s\n' "$model_path" >&2; exit 1; }
[ -x "$binary_directory/llama-bench" ] || {
    printf 'dual-backend llama-bench is absent: %s\n' "$binary_directory" >&2
    printf 'build it with remote/build-llama-dual.sh\n' >&2
    exit 1
}

mkdir -p "$(dirname -- "$output_path")"

model_digest=$(sha256sum "$model_path" | cut -d' ' -f1)
# llama-bench prints its `build:` line with the result table rather than under a
# version flag, so provenance reads from the source tree the binary came from.
# The patch series this repository applies means the revision alone names a
# different tree, and the worktree state travels with it.
source_directory=${QWEN_LLAMA_SOURCE:-"${HOME:?}/src/llama.cpp-qwen-apu"}
source_commit=$(git -C "$source_directory" rev-parse HEAD 2>/dev/null || echo unknown)
source_worktree=clean
if [ -n "$(git -C "$source_directory" status --porcelain 2>/dev/null)" ]; then
    source_worktree=dirty
fi

{
    printf 'matrix_run model=%s\n' "$(basename -- "$model_path")"
    printf 'model_sha256=%s\n' "$model_digest"
    printf 'llama_commit=%s worktree=%s\n' "$source_commit" "$source_worktree"
    printf 'phase_timeout_seconds=%s repetitions=%s\n' "$phase_timeout" "$repetitions"
} | tee "$output_path"

# One arm is a label, a device, and the environment that selects its kernels.
# The phase pair is identical across arms so the rows compare directly.
run_arm() {
    arm_label=$1
    arm_device=$2
    shift 2

    for phase_arguments in '-p 512 -n 0' '-p 0 -n 64'; do
        {
            printf '\n===== %s %s =====\n' "$arm_label" "$phase_arguments"
        } | tee -a "$output_path"

        start_seconds=$(date +%s)
        if env "$@" timeout "$phase_timeout" \
            "$binary_directory/llama-bench" \
            -m "$model_path" --device "$arm_device" -ngl 99 \
            $phase_arguments -t 2 -r "$repetitions" 2>&1 |
            grep -vE '^(ggml_cuda_init|ggml_vulkan|  Device)' | tee -a "$output_path"
        then
            elapsed_seconds=$(( $(date +%s) - start_seconds ))
            printf 'arm=%s phase="%s" state=completed seconds=%s\n' \
                "$arm_label" "$phase_arguments" "$elapsed_seconds" | tee -a "$output_path"
        else
            elapsed_seconds=$(( $(date +%s) - start_seconds ))
            printf 'arm=%s phase="%s" state=timeout seconds=%s\n' \
                "$arm_label" "$phase_arguments" "$elapsed_seconds" | tee -a "$output_path"
        fi
    done
}

hip_library_path=$rocm_path/lib:$rocm_path/lib64:${LD_LIBRARY_PATH:-}

run_arm 'V  RADV Vulkan reference' Vulkan0

run_arm 'H0 gfx900 override, automatic kernels' ROCm0 \
    "ROCM_PATH=$rocm_path" \
    "LD_LIBRARY_PATH=$hip_library_path" \
    HSA_OVERRIDE_GFX_VERSION=9.0.0 \
    HSA_ENABLE_SDMA=0

printf '\nmatrix_run=completed output=%s\n' "$output_path" | tee -a "$output_path"
