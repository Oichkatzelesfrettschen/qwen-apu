#!/bin/sh
set -eu

# Stand-in for TheRock's hipcc, driven by remote/test-rocm10-ladder.sh. It
# never compiles anything; it recognizes the argv shapes
# remote/rocm10-ladder.sh emits and answers each one the way a real hipcc
# would for the ladder's own purposes: a compile-only object, a --save-temps
# .s file carrying or omitting v_mad_mix_f32, a -### dry run naming bitcode
# paths, and a linked executable that prints the canned line the ladder rung
# greps for.
#
# QWEN_ROCM10_FAKE_LOG, when set, receives one line per invocation carrying
# the full argv and the HSA_ENABLE_SDMA and ROCM_PATH the invocation ran
# under, so a test can confirm the ladder exported the SDMA workaround ahead
# of every compile.
#
# QWEN_ROCM10_FAKE_FAIL_STAGE, when set, names one rung by its recognized
# source basename (kernel, device_enum, vector_add, wave64_lds, blas_call) or
# the literal token "device-libraries" for a -### dry run; that one
# invocation exits 1 and every other invocation still succeeds, which is what
# the stop-at-first-failure test needs.
#
# QWEN_ROCM10_FAKE_MAD_MIX_PRESENT selects whether the fabricated --save-temps
# .s file carries v_mad_mix_f32 (1) or omits it (0, the default, matching
# hp14-raven2-gpu/docs/raven2-capability-decomposition.md's finding that
# stock LLVM does not select it for this kernel shape on gfx902).

if [ -n "${QWEN_ROCM10_FAKE_LOG:-}" ]; then
    {
        printf 'argv:'
        for argument in "$@"; do
            printf ' %s' "$argument"
        done
        printf '\n'
        printf 'HSA_ENABLE_SDMA=%s ROCM_PATH=%s\n' \
            "${HSA_ENABLE_SDMA:-unset}" "${ROCM_PATH:-unset}"
    } >> "$QWEN_ROCM10_FAKE_LOG"
fi

fail_stage=${QWEN_ROCM10_FAKE_FAIL_STAGE:-}
mad_mix_present=${QWEN_ROCM10_FAKE_MAD_MIX_PRESENT:-0}

dry_run=0
save_temps=0
output_path=""
source_basename=""
previous=""
for argument in "$@"; do
    case $argument in
        -###) dry_run=1 ;;
        --save-temps) save_temps=1 ;;
    esac
    case $previous in
        -o) output_path=$argument ;;
    esac
    case $argument in
        *.hip)
            source_basename=$(basename -- "$argument" .hip)
            ;;
    esac
    previous=$argument
done

if [ "$dry_run" = 1 ]; then
    if [ "$fail_stage" = device-libraries ]; then
        printf 'fake hipcc: refusing the device-libraries dry run\n' >&2
        exit 1
    fi
    printf 'clang: "-mlink-builtin-bitcode" "%s/amdgcn/bitcode/ocml.bc"\n' "${ROCM_PATH:-/prefix}"
    printf 'clang: "-mlink-builtin-bitcode" "%s/amdgcn/bitcode/ockl.bc"\n' "${ROCM_PATH:-/prefix}"
    printf 'clang: "-mlink-builtin-bitcode" "%s/amdgcn/bitcode/oclc_isa_version_902.bc"\n' "${ROCM_PATH:-/prefix}"
    exit 0
fi

if [ -n "$source_basename" ] && [ "$source_basename" = "$fail_stage" ]; then
    printf 'fake hipcc: refusing to compile %s (QWEN_ROCM10_FAKE_FAIL_STAGE)\n' "$source_basename" >&2
    exit 1
fi

if [ "$save_temps" = 1 ]; then
    # remote/rocm10-ladder.sh runs this invocation with the compile-temps
    # directory as its own working directory, the same place a real
    # --save-temps run would leave its .s file.
    isa_path=./kernel-hip-amdgcn-amd-amdhsa-gfx902.s
    if [ "$mad_mix_present" = 1 ]; then
        printf '\tv_mad_mix_f32 v0, v1, v2, v0 op_sel:[0,0,0] op_sel_hi:[1,1,0]\n' > "$isa_path"
    else
        printf '\tv_cvt_f32_f16_e32 v0, v1\n\tv_fma_f32 v0, v1, v2, v0\n' > "$isa_path"
    fi
    [ -z "$output_path" ] || : > "$output_path"
    exit 0
fi

case $source_basename in
    kernel|"")
        # A compile-only invocation (-c) with no link step to fabricate.
        [ -z "$output_path" ] || : > "$output_path"
        exit 0
        ;;
    device_enum)
        canned='printf "device_enum=PASS count=1 name=gfx902 gcnArchName=gfx902:xnack+\n"'
        ;;
    vector_add)
        canned='printf "vector_add=PASS n=1024\n"'
        ;;
    wave64_lds)
        canned='printf "wave64_lds=PASS sum=2016\n"'
        ;;
    blas_call)
        canned='printf "blas=PASS backend=hipblas\n"'
        ;;
    *)
        printf 'fake hipcc: unrecognized source %s\n' "$source_basename" >&2
        exit 1
        ;;
esac

if [ -z "$output_path" ]; then
    printf 'fake hipcc: no -o given for a link step\n' >&2
    exit 1
fi

{
    printf '#!/bin/sh\n'
    printf 'set -eu\n'
    if [ -n "${QWEN_ROCM10_FAKE_LOG:-}" ]; then
        printf '{ printf "run:%s\\n"; printf "HSA_ENABLE_SDMA=%%s ROCM_PATH=%%s\\n" "${HSA_ENABLE_SDMA:-unset}" "${ROCM_PATH:-unset}"; } >> "%s"\n' \
            "$source_basename" "$QWEN_ROCM10_FAKE_LOG"
    fi
    printf '%s\n' "$canned"
} > "$output_path"
chmod +x "$output_path"
exit 0
