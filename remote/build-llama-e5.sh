#!/bin/sh
set -eu

# The E5 serving-and-census binary, built as one command so the laptop window
# runs a build and then a proof rather than assembling a recipe by hand.
#
# Three inputs decide what this binary is, and each one is stated here rather
# than left to the host. The candidate series names
# llama-vulkan-q4k-int24-mmvq.patch, which splits the backend's integer-dot bool
# into four fields so GGML_VK_FORCE_INTEGER_DOT admits the q8_1 mat-vec
# pipelines alone, and llama-vulkan-pipeline-census.patch, whose
# census_spirv_source_sha256 is the one field that states which module the device
# compiled. The preset is raven2-vulkan-census, which carries the production
# flags plus -DGGML_VULKAN_PIPELINE_CENSUS=ON and declares itself a diagnostic
# artifact that bundle assembly refuses. The compiler is the pinned shaderc
# prefix remote/shaderc-toolchain.tsv names, because the appliance's own glslc
# answers `extension not supported: GL_EXT_integer_dot_product` and
# ggml/src/ggml-vulkan/CMakeLists.txt reads that answer at configure time: a
# refusal there leaves GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT off and the build
# emits no q8_1 mat-vec variant at all, quietly, which is the exact absence the
# proof rung exists to detect.
#
# find_package(Vulkan COMPONENTS glslc REQUIRED) caches Vulkan_GLSLC_EXECUTABLE
# as an absolute path in CMakeCache.txt, so prepending a prefix to PATH over an
# existing build directory keeps whichever compiler the first configure found.
# The cached value is therefore compared against the pin before the build and
# again after it, and a directory configured by another compiler is refused with
# the removal named rather than reconfigured in place.
#
# usage: build-llama-e5.sh SOURCE_DIRECTORY [PREFIX_ROOT]
#   SOURCE_DIRECTORY  the llama.cpp checkout the production series is applied to
#   PREFIX_ROOT       where fetch-shaderc-toolchain.sh installed its prefix,
#                     default QWEN_SHADERC_PREFIX_ROOT or the runtime root's own
#                     shaderc directory

usage() {
    printf 'usage: %s SOURCE_DIRECTORY [PREFIX_ROOT]\n' "$0" >&2
    exit 2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

source_directory=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
prefix_root=${2:-${QWEN_SHADERC_PREFIX_ROOT:-"$qwen_home_shaderc_root"}}
toolchain_ledger=${QWEN_SHADERC_LEDGER:-$script_directory/shaderc-toolchain.tsv}
# The preset builder is resolved beside this script; the override is the seam
# remote/test-build-llama-e5.sh drives every refusal through without a compiler,
# a checkout, or a device.
preset_script=${QWEN_E5_PRESET_SCRIPT:-$script_directory/build-llama-preset.sh}

e5_preset=raven2-vulkan-census
e5_candidate_series='llama-vulkan-pipeline-census.patch llama-vulkan-q4k-int24-mmvq.patch'
e5_q8_1_pipeline=mul_mat_vec_q4_k_q8_1_f32

if [ ! -d "$source_directory" ]; then
    printf 'the llama.cpp checkout is not a directory: %s\n' "$source_directory" >&2
    exit 1
fi
if [ ! -x "$preset_script" ]; then
    printf 'the preset builder is not executable: %s\n' "$preset_script" >&2
    exit 1
fi
if [ ! -r "$toolchain_ledger" ]; then
    printf 'the shaderc toolchain ledger is unreadable: %s\n' "$toolchain_ledger" >&2
    exit 1
fi

# The ledger reader is fetch-shaderc-toolchain.sh's own, so the prefix this
# build compiles under is the prefix that fetch installed rather than a second
# derivation of the same name.
read_ledger_value() {
    awk -F'\t' -v key="$1" '
        /^#/ || NF == 0 { next }
        NF != 2 { printf "malformed shaderc toolchain row: %s\n", $0 > "/dev/stderr"; exit 1 }
        $1 == key { print $2; found = 1 }
        END { exit found ? 0 : 1 }
    ' "$2"
}

for ledger_key in revision prefix; do
    if ! read_ledger_value "$ledger_key" "$toolchain_ledger" >/dev/null; then
        printf 'the shaderc toolchain ledger names no %s\n' "$ledger_key" >&2
        exit 1
    fi
done
toolchain_revision=$(read_ledger_value revision "$toolchain_ledger")
toolchain_prefix_name=$(read_ledger_value prefix "$toolchain_ledger")
case $toolchain_prefix_name in
    */* | '' | .*)
        printf 'the prefix name is one plain directory component: %s\n' \
            "$toolchain_prefix_name" >&2
        exit 1
        ;;
esac

glslc_program=$prefix_root/$toolchain_prefix_name/bin/glslc
if [ ! -x "$glslc_program" ]; then
    printf 'the pinned glslc is missing: %s\n' "$glslc_program" >&2
    printf 'run remote/fetch-shaderc-toolchain.sh %s first\n' "$prefix_root" >&2
    exit 1
fi

# The extension is the whole reason this prefix exists, so the build proves the
# installed compiler accepts it before any configure spends minutes deciding the
# same thing silently. The probe is the fetcher's own, kept identical so a
# compiler that passes there passes here.
probe_directory=$(mktemp -d)
trap 'rm -rf -- "$probe_directory"' EXIT HUP INT TERM
cat >"$probe_directory/extension-probe.comp" <<'PROBE'
#version 450
#extension GL_EXT_integer_dot_product : require
layout(local_size_x = 1) in;
layout(binding = 0) buffer Result { int value; } result;
void main() {
    result.value = dotPacked4x8EXT(0x01020304, 0x05060708);
}
PROBE
if ! "$glslc_program" --target-env=vulkan1.2 -fshader-stage=compute \
    -o "$probe_directory/extension-probe.spv" \
    "$probe_directory/extension-probe.comp" >"$probe_directory/probe.log" 2>&1
then
    printf 'the pinned glslc rejects GL_EXT_integer_dot_product, so this build would emit no q8_1 variant\n' >&2
    cat "$probe_directory/probe.log" >&2
    exit 1
fi
glslc_version=$("$glslc_program" --version | head -n 1)
glslc_sha256=$(sha256sum "$glslc_program" | cut -d ' ' -f 1)
printf 'e5_glslc=accepted version=%s sha256=%s\n' "$glslc_version" "$glslc_sha256"

# build-llama-preset.sh derives the build directory from the preset name, so the
# cache comparison reads the same path the build will configure.
build_directory=$source_directory/build-$e5_preset
cmake_cache=$build_directory/CMakeCache.txt
cached_glslc() {
    if [ -r "$cmake_cache" ]; then
        sed -n 's/^Vulkan_GLSLC_EXECUTABLE:[^=]*=//p' "$cmake_cache" | head -n 1
    fi
}
existing_glslc=$(cached_glslc)
if [ -n "$existing_glslc" ] && [ "$existing_glslc" != "$glslc_program" ]; then
    printf 'the build directory is configured against another compiler: cached=%s pinned=%s\n' \
        "$existing_glslc" "$glslc_program" >&2
    printf 'GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT is decided at configure time and the cache keeps it, so remove %s and build again\n' \
        "$build_directory" >&2
    exit 1
fi

build_log=$(mktemp)
build_status_file=$(mktemp)
trap 'rm -rf -- "$probe_directory"; rm -f -- "$build_log" "$build_status_file"' \
    EXIT HUP INT TERM
# A POSIX shell reports the last command of a pipeline, so the builder's own
# status is written to a file inside the pipeline rather than read from `$?`
# after `tee`. The build runs long enough that its progress belongs on the
# terminal while it runs, which is what keeps the pipeline here.
printf '0\n' >"$build_status_file"
{
    PATH=$prefix_root/$toolchain_prefix_name/bin:$PATH \
    QWEN_LLAMA_CANDIDATE_PATCHES=1 \
    QWEN_LLAMA_CANDIDATE_SELECT="$e5_candidate_series" \
        "$preset_script" "$e5_preset" "$source_directory" 2>&1 ||
        printf '%s\n' "$?" >"$build_status_file"
} | tee "$build_log"
build_status=$(cat "$build_status_file")
if [ "$build_status" -ne 0 ]; then
    printf 'the E5 preset build failed with status %s\n' "$build_status" >&2
    exit 1
fi

observed_glslc=$(cached_glslc)
if [ "$observed_glslc" != "$glslc_program" ]; then
    printf 'the configured compiler is not the pin: configured=%s pinned=%s\n' \
        "${observed_glslc:--}" "$glslc_program" >&2
    exit 1
fi

server_executable=$build_directory/bin/llama-server
if [ ! -x "$server_executable" ]; then
    printf 'the build produced no server: %s\n' "$server_executable" >&2
    exit 1
fi

# The q8_1 mat-vec variant reaches the binary as a named pipeline only where the
# shader generator emitted it, which happens only where the configure step read
# the extension as supported. Its absence is the silent failure the pinned
# compiler exists to remove, so it is checked in the artifact rather than
# inferred from the compiler that produced it.
if ! LC_ALL=C grep -a -q -- "$e5_q8_1_pipeline" "$server_executable"; then
    printf 'the built server names no %s pipeline, so the extension never reached the shader generator\n' \
        "$e5_q8_1_pipeline" >&2
    exit 1
fi

manifest_path=$(sed -n 's/.*[[:space:]]manifest=\([^[:space:]]*\).*/\1/p' "$build_log" | tail -n 1)
if [ -z "$manifest_path" ]; then
    printf 'the preset build named no manifest\n' >&2
    exit 1
fi

# One receipt beside the binary, so run-e5-module-proof.sh binds the compiler
# and the candidate series from the build rather than from the caller's memory.
build_receipt=$build_directory/e5-build.tsv
{
    printf 'key\tvalue\n'
    printf 'schema\te5-build-v1\n'
    printf 'preset\t%s\n' "$e5_preset"
    printf 'candidate_series\t%s\n' "$(printf '%s' "$e5_candidate_series" | tr ' ' ',')"
    printf 'source_directory\t%s\n' "$source_directory"
    printf 'source_commit\t%s\n' "$(git -C "$source_directory" rev-parse HEAD)"
    printf 'shaderc_revision\t%s\n' "$toolchain_revision"
    printf 'glslc\t%s\n' "$glslc_program"
    printf 'glslc_version\t%s\n' "$glslc_version"
    printf 'glslc_sha256\t%s\n' "$glslc_sha256"
    printf 'manifest\t%s\n' "$manifest_path"
    printf 'server\t%s\n' "$server_executable"
    printf 'server_sha256\t%s\n' "$(sha256sum "$server_executable" | cut -d ' ' -f 1)"
    printf 'server_bytes\t%s\n' "$(wc -c <"$server_executable" | tr -d ' ')"
    printf 'q8_1_pipeline_named\t%s\n' "$e5_q8_1_pipeline"
} >"$build_receipt"

printf 'e5_build=accepted server=%s manifest=%s receipt=%s\n' \
    "$server_executable" "$manifest_path" "$build_receipt"
