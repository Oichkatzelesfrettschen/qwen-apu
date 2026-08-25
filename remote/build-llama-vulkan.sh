#!/bin/sh
set -eu

renice -n 19 -p $$ >/dev/null
taskset -pc 0 $$ >/dev/null
ionice -c 3 -p $$

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
source_directory=${1:-"${HOME:?}/src/llama.cpp-qwen-apu"}
build_directory=${2:-$source_directory/build-qwen-vulkan}
expected_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
ui_dist_directory=$build_directory/tools/ui/dist

if [ ! -d "$source_directory/.git" ]; then
    printf 'llama.cpp checkout is missing: %s\n' "$source_directory" >&2
    exit 1
fi

actual_commit=$(git -C "$source_directory" rev-parse HEAD)
if [ "$actual_commit" != "$expected_commit" ]; then
    printf 'unexpected llama.cpp commit: expected %s, found %s\n' \
        "$expected_commit" "$actual_commit" >&2
    exit 1
fi

for required_command in cmake ninja glslc cc c++; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'missing build command: %s\n' "$required_command" >&2
        exit 1
    fi
done

# LLAMA_BUILD_UI disables the npm build, while LLAMA_USE_PREBUILT_UI controls
# the independent Hugging Face asset path.  Remove prior build-tree assets so
# an incremental configure cannot embed a stale Web UI in the server binary.
if [ -d "$ui_dist_directory" ]; then
    cmake -E remove_directory "$ui_dist_directory"
fi

if [ ! -r /usr/include/spirv/unified1/spirv.hpp ] && \
   [ ! -r /usr/include/spirv-headers/spirv.hpp ] && \
   [ ! -r /usr/include/spirv.hpp ]; then
    printf 'SPIR-V C++ headers are missing\n' >&2
    exit 1
fi

cmake -S "$source_directory" -B "$build_directory" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_FATAL_WARNINGS=ON \
    -DLLAMA_BUILD_APP=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=ON \
    -DLLAMA_BUILD_TESTS=ON \
    -DLLAMA_BUILD_TOOLS=ON \
    -DLLAMA_BUILD_UI=OFF \
    -DLLAMA_USE_PREBUILT_UI=OFF \
    -DLLAMA_OPENSSL=OFF \
    -DGGML_BLAS=OFF \
    -DGGML_CCACHE=OFF \
    -DGGML_CPU=ON \
    -DGGML_CUDA=OFF \
    -DGGML_FATAL_WARNINGS=ON \
    -DGGML_HIP=OFF \
    -DGGML_LLAMAFILE=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_OPENCL=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_RPC=OFF \
    -DGGML_SYCL=OFF \
    -DGGML_VULKAN=ON

cmake --build "$build_directory" --parallel 1 --target llama-server llama-cli
"$script_directory/test-vulkan-pacing-math.sh" "$source_directory"
"$script_directory/test-vulkan-submit-limit.sh" "$source_directory"

printf 'build_commit=%s build_directory=%s cpu_backend=required vulkan_backend=enabled duty_cycle_test=accepted submit_limit_test=accepted parallel_jobs=1\n' \
    "$actual_commit" "$build_directory"
