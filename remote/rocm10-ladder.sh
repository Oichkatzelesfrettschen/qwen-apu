#!/bin/sh
set -eu

# ROCm 10 (TheRock nightly) gfx902 ladder: a bounded compiler and runtime
# falsifier run against an isolated prefix, never against the working ROCm
# 6.4.4 install or /opt/rocm. RADV Vulkan stays the serving backend
# (CLAUDE.md, "The HIP backend needs one variable to load a model at all");
# this ladder measures whether a current TheRock build changes any of the
# facts that keep it that way, and evidence/rocm10-ladder/README.md pins
# where that nightly comes from.
#
# Seven rungs run in order and the first failure ends the ladder: a later
# rung would measure a machine state a prior rung already disproved.
#
#   compile           gfx902 offload of a small mixed-precision kernel, read
#                      back through --save-temps to answer whether LLVM
#                      selects v_mad_mix_f32 for a fp16-dot2/fp32-accumulate
#                      loop. hp14-raven2-gpu/docs/raven2-capability-decomposition.md
#                      records that stock clang-19 does not select it on this
#                      target (49 VALU against the 33 a selected v_mad_mix_f32
#                      would cost), and that gap is native-LLVM-codegen rather
#                      than RADV's own ACO backend, so an ACO fix to
#                      integer-dot selection does not touch it.
#   enumerate          rocminfo, or a HIP runtime device query when rocminfo
#                      is absent from the prefix, reporting the gfx902 agent.
#   vector-add         a HIP kernel launch and readback, checked for
#                      arithmetic correctness rather than only for a device
#                      accepting the submission.
#   wave64-lds         an LDS reduction sized to one wavefront (64 lanes),
#                      checked against the host-computed sum.
#   device-libraries   `-###` dry-run compilation, read for the device-library
#                      bitcode paths the compiler resolved for gfx902 (ocml,
#                      ockl, oclc_isa_version_902, and neighbors).
#   blas-call          one hipBLAS SGEMM. hp14-raven2-gpu/docs/rocm-gfx902-support.md
#                      records that neither 6.4.4 nor 7.2 ships a gfx902
#                      Tensile logic file, so this rung is where the ladder is
#                      expected to stop on real hardware.
#   llama-bench        a minimal dual-backend llama-bench decode row, run only
#                      when every rung above passed, since a HIP row is
#                      meaningless once BLAS or a lower rung has already
#                      failed the checkpoint's own weight-multiply path.
#
# HSA_ENABLE_SDMA=0 is exported once, script-wide, ahead of every rung.
# evidence/rocm-h0-operational-failure.md: without it,
# llama_model_loader::load_all_data parks in hipEventSynchronize and never
# returns, so a rung that runs HIP runtime code without this setting would
# measure a hang rather than the mechanism the rung names.
#
# The isolated prefix is read from the PREFIX argument alone. ROCM_PATH is
# overwritten from it regardless of the caller's own environment, and the
# script refuses outright when PREFIX/bin/hipcc is absent rather than
# resolving hipcc through PATH or falling back to /opt/rocm, because a silent
# fallback would measure the working 6.4.4 install under a ROCm-10 label.

usage() {
    printf 'usage: %s PREFIX OUTPUT_DIR\n' "$0" >&2
    printf '  PREFIX      isolated ROCm SDK root; PREFIX/bin/hipcc must exist\n' >&2
    printf '  OUTPUT_DIR  ladder.tsv, per-rung logs, and generated kernel sources\n' >&2
    printf '\n' >&2
    printf '  QWEN_ROCM10_TARGET           offload arch, default gfx902\n' >&2
    printf '  QWEN_ROCM10_COMPILE_TIMEOUT  seconds per compile, default 120\n' >&2
    printf '  QWEN_ROCM10_RUN_TIMEOUT      seconds per executed rung, default 60\n' >&2
    printf '  QWEN_ROCM10_LLAMA_BENCH      dual-backend llama-bench for the final rung\n' >&2
    printf '  QWEN_ROCM10_MODEL            checkpoint for the final rung\n' >&2
    exit 2
}

[ "$#" -eq 2 ] || usage

prefix=$1
output_directory=$2
target=${QWEN_ROCM10_TARGET:-gfx902}
compile_timeout=${QWEN_ROCM10_COMPILE_TIMEOUT:-120}
run_timeout=${QWEN_ROCM10_RUN_TIMEOUT:-60}

hipcc=$prefix/bin/hipcc
[ -x "$hipcc" ] || {
    printf 'refused: no hipcc under the isolated prefix: %s\n' "$hipcc" >&2
    printf 'ROCM_PATH is read from PREFIX alone; this ladder never falls back to /opt/rocm\n' >&2
    exit 1
}

mkdir -p "$output_directory/work" "$output_directory/logs"
work_directory=$output_directory/work
ladder_path=$output_directory/ladder.tsv
: > "$ladder_path"
printf 'rung\tcommand\texit_status\tresult\tartifact\tlog\n' >> "$ladder_path"

# The prefix is the sole ROCm identity for this process; nothing ambient
# substitutes for it.
unset ROCM_PATH 2>/dev/null || true
ROCM_PATH=$prefix
PATH=$prefix/bin:$PATH
LD_LIBRARY_PATH=$prefix/lib:$prefix/lib64:${LD_LIBRARY_PATH:-}
HSA_ENABLE_SDMA=0
export ROCM_PATH PATH LD_LIBRARY_PATH HSA_ENABLE_SDMA

printf 'rocm10_ladder=starting prefix=%s target=%s output=%s\n' \
    "$prefix" "$target" "$output_directory"

record_row() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$ladder_path"
    printf 'rung=%s result=%s exit_status=%s artifact=%s\n' "$1" "$4" "$3" "$5"
}

tail_lines() {
    tail -n 20 -- "$1" 2>/dev/null | tr '\n' ' | ' || true
}

stopped=0
failed_rung=none

# ---------------------------------------------------------------------------
# Rung 1: compile. A small mixed-precision kernel doubles as the trivial
# gfx902 offload target and as the v_mad_mix_f32 feature-selection probe:
# fp16 pairs in, one fp32 accumulator out, the exact shape
# hp14-raven2-gpu/evidence/isa/quant-battery.cl names fp16_dot2_acc_fp32.
# ---------------------------------------------------------------------------
rung=compile
if [ "$stopped" = 0 ]; then
    kernel_source=$work_directory/kernel.hip
    cat > "$kernel_source" <<'EOF'
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>

extern "C" __global__ void fp16_dot2_acc_fp32(float *out, const __half2 *a, const __half2 *b) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    float acc = 0.f;
    for (int k = 0; k < 64; k++) {
        __half2 x = a[i * 64 + k];
        __half2 y = b[i * 64 + k];
        acc += (float)__low2float(x) * (float)__low2float(y)
             + (float)__high2float(x) * (float)__high2float(y);
    }
    out[i] = acc;
}
EOF
    compile_directory=$work_directory/compile-temps
    mkdir -p "$compile_directory"
    log_path=$output_directory/logs/$rung.log
    command_display="hipcc --offload-arch=$target --save-temps -c kernel.hip -o kernel.o"
    if (cd "$compile_directory" && timeout "$compile_timeout" \
            "$hipcc" --offload-arch="$target" --save-temps \
            -c "$kernel_source" -o kernel.o) >"$log_path" 2>&1
    then
        exit_status=0
    else
        exit_status=$?
    fi

    mad_mix_selected=no
    fma_mix_selected=no
    if [ "$exit_status" = 0 ]; then
        if grep -l 'v_mad_mix_f32' "$compile_directory"/*.s >/dev/null 2>&1; then
            mad_mix_selected=yes
        fi
        if grep -l 'v_fma_mix_f32' "$compile_directory"/*.s >/dev/null 2>&1; then
            fma_mix_selected=yes
        fi
    fi

    if [ "$exit_status" = 0 ]; then
        result=pass
        artifact="v_mad_mix_f32_selected=$mad_mix_selected v_fma_mix_f32_selected=$fma_mix_selected isa=$compile_directory"
    else
        result=fail
        artifact="hipcc refused --offload-arch=$target: $(tail_lines "$log_path")"
        stopped=1
        failed_rung=$rung
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 2: enumerate. rocminfo when the prefix ships it, a HIP runtime device
# query otherwise.
# ---------------------------------------------------------------------------
rung=enumerate
if [ "$stopped" = 0 ]; then
    log_path=$output_directory/logs/$rung.log
    rocminfo=$prefix/bin/rocminfo
    if [ -x "$rocminfo" ]; then
        method=rocminfo
        command_display=rocminfo
        if timeout "$run_timeout" "$rocminfo" >"$log_path" 2>&1; then
            exit_status=0
        else
            exit_status=$?
        fi
    else
        method=hip-runtime
        enum_source=$work_directory/device_enum.hip
        cat > "$enum_source" <<'EOF'
#include <hip/hip_runtime.h>
#include <cstdio>

int main(void) {
    int count = 0;
    hipError_t error = hipGetDeviceCount(&count);
    if (error != hipSuccess || count < 1) {
        fprintf(stderr, "device_enum=FAIL count=%d error=%s\n", count, hipGetErrorString(error));
        return 1;
    }
    hipDeviceProp_t properties;
    error = hipGetDeviceProperties(&properties, 0);
    if (error != hipSuccess) {
        fprintf(stderr, "device_enum=FAIL properties error=%s\n", hipGetErrorString(error));
        return 1;
    }
    printf("device_enum=PASS count=%d name=%s gcnArchName=%s\n",
           count, properties.name, properties.gcnArchName);
    return 0;
}
EOF
        enum_binary=$work_directory/device_enum
        compile_log=$output_directory/logs/$rung-compile.log
        command_display="hipcc --offload-arch=$target device_enum.hip -o device_enum && ./device_enum"
        if timeout "$compile_timeout" "$hipcc" --offload-arch="$target" \
                "$enum_source" -o "$enum_binary" >"$compile_log" 2>&1
        then
            if timeout "$run_timeout" env HSA_ENABLE_SDMA=0 "$enum_binary" >"$log_path" 2>&1; then
                exit_status=0
            else
                exit_status=$?
            fi
        else
            exit_status=1
            cat "$compile_log" > "$log_path" 2>/dev/null || true
        fi
    fi

    if [ "$exit_status" = 0 ] && grep -q "$target" "$log_path" 2>/dev/null; then
        result=pass
        artifact="method=$method target=$target agent found"
    else
        result=fail
        artifact="method=$method no $target agent found: $(tail_lines "$log_path")"
        stopped=1
        failed_rung=$rung
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 3: vector-add. Correctness, not just a completed submission.
# ---------------------------------------------------------------------------
rung=vector-add
if [ "$stopped" = 0 ]; then
    add_source=$work_directory/vector_add.hip
    cat > "$add_source" <<'EOF'
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>

#define QWEN_VECTOR_ADD_N 1024

__global__ void vector_add(const float *a, const float *b, float *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

int main(void) {
    float *host_a = (float *)malloc(QWEN_VECTOR_ADD_N * sizeof(float));
    float *host_b = (float *)malloc(QWEN_VECTOR_ADD_N * sizeof(float));
    float *host_c = (float *)malloc(QWEN_VECTOR_ADD_N * sizeof(float));
    for (int i = 0; i < QWEN_VECTOR_ADD_N; i++) {
        host_a[i] = (float)i;
        host_b[i] = (float)(2 * i);
    }

    float *device_a, *device_b, *device_c;
    hipError_t error;
    error = hipMalloc((void **)&device_a, QWEN_VECTOR_ADD_N * sizeof(float));
    if (error != hipSuccess) { fprintf(stderr, "hipMalloc a: %s\n", hipGetErrorString(error)); return 1; }
    error = hipMalloc((void **)&device_b, QWEN_VECTOR_ADD_N * sizeof(float));
    if (error != hipSuccess) { fprintf(stderr, "hipMalloc b: %s\n", hipGetErrorString(error)); return 1; }
    error = hipMalloc((void **)&device_c, QWEN_VECTOR_ADD_N * sizeof(float));
    if (error != hipSuccess) { fprintf(stderr, "hipMalloc c: %s\n", hipGetErrorString(error)); return 1; }

    hipMemcpy(device_a, host_a, QWEN_VECTOR_ADD_N * sizeof(float), hipMemcpyHostToDevice);
    hipMemcpy(device_b, host_b, QWEN_VECTOR_ADD_N * sizeof(float), hipMemcpyHostToDevice);

    hipLaunchKernelGGL(vector_add, dim3(QWEN_VECTOR_ADD_N / 64), dim3(64), 0, 0,
                        device_a, device_b, device_c, QWEN_VECTOR_ADD_N);
    error = hipDeviceSynchronize();
    if (error != hipSuccess) { fprintf(stderr, "sync: %s\n", hipGetErrorString(error)); return 1; }

    hipMemcpy(host_c, device_c, QWEN_VECTOR_ADD_N * sizeof(float), hipMemcpyDeviceToHost);

    for (int i = 0; i < QWEN_VECTOR_ADD_N; i++) {
        float expected = host_a[i] + host_b[i];
        if (host_c[i] != expected) {
            fprintf(stderr, "vector_add=FAIL i=%d expected=%f actual=%f\n", i, expected, host_c[i]);
            return 1;
        }
    }
    printf("vector_add=PASS n=%d\n", QWEN_VECTOR_ADD_N);
    return 0;
}
EOF
    add_binary=$work_directory/vector_add
    compile_log=$output_directory/logs/$rung-compile.log
    log_path=$output_directory/logs/$rung.log
    command_display="hipcc --offload-arch=$target vector_add.hip -o vector_add && ./vector_add"
    if timeout "$compile_timeout" "$hipcc" --offload-arch="$target" \
            "$add_source" -o "$add_binary" >"$compile_log" 2>&1
    then
        if timeout "$run_timeout" env HSA_ENABLE_SDMA=0 "$add_binary" >"$log_path" 2>&1; then
            exit_status=0
        else
            exit_status=$?
        fi
    else
        exit_status=1
        cat "$compile_log" > "$log_path" 2>/dev/null || true
    fi

    if [ "$exit_status" = 0 ] && grep -q 'vector_add=PASS' "$log_path" 2>/dev/null; then
        result=pass
        artifact="1024-element add verified against a host computation"
    else
        result=fail
        artifact="vector add refused or diverged: $(tail_lines "$log_path")"
        stopped=1
        failed_rung=$rung
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 4: wave64-lds. A tree reduction sized to one wavefront, checked
# against the host-computed sum of 0..63.
# ---------------------------------------------------------------------------
rung=wave64-lds
if [ "$stopped" = 0 ]; then
    lds_source=$work_directory/wave64_lds.hip
    cat > "$lds_source" <<'EOF'
#include <hip/hip_runtime.h>
#include <cstdio>

__global__ void wave64_lds_reduce(const int *in, int *out) {
    __shared__ int lane[64];
    int tid = threadIdx.x;
    lane[tid] = in[tid];
    __syncthreads();
    for (int offset = 32; offset > 0; offset >>= 1) {
        if (tid < offset) lane[tid] += lane[tid + offset];
        __syncthreads();
    }
    if (tid == 0) out[0] = lane[0];
}

int main(void) {
    int host_in[64];
    int expected = 0;
    for (int i = 0; i < 64; i++) { host_in[i] = i; expected += i; }

    int *device_in, *device_out;
    hipError_t error;
    error = hipMalloc((void **)&device_in, 64 * sizeof(int));
    if (error != hipSuccess) { fprintf(stderr, "hipMalloc in: %s\n", hipGetErrorString(error)); return 1; }
    error = hipMalloc((void **)&device_out, sizeof(int));
    if (error != hipSuccess) { fprintf(stderr, "hipMalloc out: %s\n", hipGetErrorString(error)); return 1; }

    hipMemcpy(device_in, host_in, 64 * sizeof(int), hipMemcpyHostToDevice);
    hipLaunchKernelGGL(wave64_lds_reduce, dim3(1), dim3(64), 0, 0, device_in, device_out);
    error = hipDeviceSynchronize();
    if (error != hipSuccess) { fprintf(stderr, "sync: %s\n", hipGetErrorString(error)); return 1; }

    int host_out = 0;
    hipMemcpy(&host_out, device_out, sizeof(int), hipMemcpyDeviceToHost);

    if (host_out != expected) {
        fprintf(stderr, "wave64_lds=FAIL expected=%d actual=%d\n", expected, host_out);
        return 1;
    }
    printf("wave64_lds=PASS sum=%d\n", host_out);
    return 0;
}
EOF
    lds_binary=$work_directory/wave64_lds
    compile_log=$output_directory/logs/$rung-compile.log
    log_path=$output_directory/logs/$rung.log
    command_display="hipcc --offload-arch=$target wave64_lds.hip -o wave64_lds && ./wave64_lds"
    if timeout "$compile_timeout" "$hipcc" --offload-arch="$target" \
            "$lds_source" -o "$lds_binary" >"$compile_log" 2>&1
    then
        if timeout "$run_timeout" env HSA_ENABLE_SDMA=0 "$lds_binary" >"$log_path" 2>&1; then
            exit_status=0
        else
            exit_status=$?
        fi
    else
        exit_status=1
        cat "$compile_log" > "$log_path" 2>/dev/null || true
    fi

    if [ "$exit_status" = 0 ] && grep -q 'wave64_lds=PASS sum=2016' "$log_path" 2>/dev/null; then
        result=pass
        artifact="64-lane LDS tree reduction verified, sum=2016"
    else
        result=fail
        artifact="wave64 LDS reduction refused or diverged: $(tail_lines "$log_path")"
        stopped=1
        failed_rung=$rung
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 5: device-libraries. A `-###` dry run names every job clang would run
# without running one, and among them the `-mlink-builtin-bitcode` flags name
# the device-library bitcode files resolved for this target.
# ---------------------------------------------------------------------------
rung=device-libraries
if [ "$stopped" = 0 ]; then
    kernel_source=$work_directory/kernel.hip
    log_path=$output_directory/logs/$rung.log
    command_display="hipcc --offload-arch=$target -### -c kernel.hip -o /dev/null"
    if timeout "$compile_timeout" "$hipcc" --offload-arch="$target" \
            -### -c "$kernel_source" -o /dev/null >"$log_path" 2>&1
    then
        exit_status=0
    else
        exit_status=$?
    fi

    bitcode_paths=""
    if [ "$exit_status" = 0 ]; then
        bitcode_paths=$(grep -o '"[^"]*\.bc"' "$log_path" 2>/dev/null |
            tr -d '"' | sort -u | tr '\n' ',' || true)
    fi

    if [ "$exit_status" = 0 ] && [ -n "$bitcode_paths" ]; then
        result=pass
        artifact="bitcode=$bitcode_paths"
    else
        result=fail
        artifact="no device-library bitcode resolved for $target: $(tail_lines "$log_path")"
        stopped=1
        failed_rung=$rung
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 6: blas-call. hp14-raven2-gpu/docs/rocm-gfx902-support.md: rocBLAS
# ships no gfx900/gfx902/gfx909 Tensile kernels in 6.4.4 or in the newest
# 7.2 release, so this rung is where the ladder is expected to stop on real
# hardware; a TheRock nightly changing that is exactly the falsifier this
# rung exists to catch.
# ---------------------------------------------------------------------------
rung=blas-call
if [ "$stopped" = 0 ]; then
    blas_header=$prefix/include/hipblas/hipblas.h
    [ -f "$blas_header" ] || blas_header=$prefix/include/hipblas.h
    log_path=$output_directory/logs/$rung.log
    if [ ! -f "$blas_header" ]; then
        exit_status=1
        command_display="(no hipblas.h under $prefix/include)"
        printf 'hipblas.h is absent under the prefix\n' > "$log_path"
        result=fail
        artifact="hipBLAS is absent from the isolated prefix"
        stopped=1
        failed_rung=$rung
    else
        blas_source=$work_directory/blas_call.hip
        cat > "$blas_source" <<'EOF'
#include <hip/hip_runtime.h>
#include <hipblas/hipblas.h>
#include <cstdio>

int main(void) {
    hipblasHandle_t handle;
    hipblasStatus_t status = hipblasCreate(&handle);
    if (status != HIPBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "blas=FAIL stage=create status=%d\n", (int)status);
        return 1;
    }

    const int n = 2;
    float host_identity[4] = {1.f, 0.f, 0.f, 1.f};
    float host_b[4] = {1.f, 2.f, 3.f, 4.f};
    float host_c[4] = {0.f, 0.f, 0.f, 0.f};

    float *device_a, *device_b, *device_c;
    hipMalloc((void **)&device_a, sizeof(host_identity));
    hipMalloc((void **)&device_b, sizeof(host_b));
    hipMalloc((void **)&device_c, sizeof(host_c));
    hipMemcpy(device_a, host_identity, sizeof(host_identity), hipMemcpyHostToDevice);
    hipMemcpy(device_b, host_b, sizeof(host_b), hipMemcpyHostToDevice);
    hipMemcpy(device_c, host_c, sizeof(host_c), hipMemcpyHostToDevice);

    float alpha = 1.f, beta = 0.f;
    status = hipblasSgemm(handle, HIPBLAS_OP_N, HIPBLAS_OP_N, n, n, n,
                           &alpha, device_a, n, device_b, n, &beta, device_c, n);
    if (status != HIPBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "blas=FAIL stage=sgemm status=%d\n", (int)status);
        hipblasDestroy(handle);
        return 1;
    }

    hipMemcpy(host_c, device_c, sizeof(host_c), hipMemcpyDeviceToHost);
    hipblasDestroy(handle);

    for (int i = 0; i < 4; i++) {
        if (host_c[i] != host_b[i]) {
            fprintf(stderr, "blas=FAIL stage=verify i=%d expected=%f actual=%f\n", i, host_b[i], host_c[i]);
            return 1;
        }
    }
    printf("blas=PASS backend=hipblas\n");
    return 0;
}
EOF
        blas_binary=$work_directory/blas_call
        compile_log=$output_directory/logs/$rung-compile.log
        command_display="hipcc --offload-arch=$target blas_call.hip -o blas_call -lhipblas && ./blas_call"
        if timeout "$compile_timeout" "$hipcc" --offload-arch="$target" \
                "$blas_source" -o "$blas_binary" -lhipblas >"$compile_log" 2>&1
        then
            if timeout "$run_timeout" env HSA_ENABLE_SDMA=0 "$blas_binary" >"$log_path" 2>&1; then
                exit_status=0
            else
                exit_status=$?
            fi
        else
            exit_status=1
            cat "$compile_log" > "$log_path" 2>/dev/null || true
        fi

        if [ "$exit_status" = 0 ] && grep -q 'blas=PASS' "$log_path" 2>/dev/null; then
            result=pass
            artifact="2x2 SGEMM verified through hipBLAS"
        else
            result=fail
            artifact="hipBLAS SGEMM refused, likely the missing gfx902 Tensile logic: $(tail_lines "$log_path")"
            stopped=1
            failed_rung=$rung
        fi
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

# ---------------------------------------------------------------------------
# Rung 7: llama-bench. Runs only once every rung above passed, since a HIP
# decode row is uninterpretable once the checkpoint's own weight-multiply
# path has already failed at a lower rung.
# ---------------------------------------------------------------------------
rung=llama-bench
if [ "$stopped" = 0 ]; then
    bench_binary=${QWEN_ROCM10_LLAMA_BENCH:-}
    model_path=${QWEN_ROCM10_MODEL:-}
    log_path=$output_directory/logs/$rung.log
    if [ -z "$bench_binary" ] || [ -z "$model_path" ]; then
        exit_status=n/a
        command_display="(skipped)"
        result=skip
        artifact="QWEN_ROCM10_LLAMA_BENCH or QWEN_ROCM10_MODEL is unset; every lower rung passed and this one was not attempted"
        : > "$log_path"
    elif [ ! -x "$bench_binary" ]; then
        exit_status=1
        command_display="$bench_binary"
        result=fail
        artifact="llama-bench binary is absent: $bench_binary"
        stopped=1
        failed_rung=$rung
        printf 'llama-bench binary is absent: %s\n' "$bench_binary" > "$log_path"
    else
        command_display="llama-bench -m $model_path --device ROCm0 -ngl 99 -p 0 -n 16 -t 1 -r 1"
        if timeout "$run_timeout" env HSA_ENABLE_SDMA=0 "$bench_binary" \
                -m "$model_path" --device ROCm0 -ngl 99 -p 0 -n 16 -t 1 -r 1 >"$log_path" 2>&1
        then
            exit_status=0
        else
            exit_status=$?
        fi

        if [ "$exit_status" = 0 ] && grep -q 'tg16\|tg 16' "$log_path" 2>/dev/null; then
            result=pass
            artifact="one decode row emitted at n=16"
        else
            result=fail
            artifact="llama-bench refused, timed out, or emitted no decode row: $(tail_lines "$log_path")"
            stopped=1
            failed_rung=$rung
        fi
    fi
    record_row "$rung" "$command_display" "$exit_status" "$result" "$artifact" "$log_path"
fi

if [ "$stopped" = 1 ]; then
    printf 'rocm10_ladder=stopped rung=%s ladder=%s\n' "$failed_rung" "$ladder_path"
else
    printf 'rocm10_ladder=complete ladder=%s\n' "$ladder_path"
fi

exit 0
