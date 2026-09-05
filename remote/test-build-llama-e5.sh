#!/bin/sh
set -eu

# remote/build-llama-e5.sh against a fake compiler and a fake preset builder, so
# every refusal is driven with no shaderc prefix, no llama.cpp source, and no
# device. The two facts the script exists to enforce are the ones the fakes make
# observable: the pinned glslc must accept GL_EXT_integer_dot_product, and the
# configured Vulkan_GLSLC_EXECUTABLE must be that same compiler, because
# ggml/src/ggml-vulkan/CMakeLists.txt reads the extension at configure time and
# CMake caches the answer.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
subject=$script_directory/build-llama-e5.sh

work_root=$(mktemp -d)
trap 'rm -rf -- "$work_root"' EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" -eq 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

ledger=$work_root/shaderc-toolchain.tsv
{
    printf '# key\tvalue\n'
    printf 'project\tgoogle/shaderc\n'
    printf 'revision\tv2026.3\n'
    printf 'prefix\tfake-shaderc\n'
} >"$ledger"

prefix_root=$work_root/prefixes
mkdir -p "$prefix_root/fake-shaderc/bin"
glslc=$prefix_root/fake-shaderc/bin/glslc

write_glslc() {
    # $1 is the exit status the extension probe meets.
    cat >"$glslc" <<GLSLC
#!/bin/sh
if [ "\$1" = --version ]; then
    printf 'shaderc v2026.3 fake\n'
    exit 0
fi
exit $1
GLSLC
    chmod 0755 "$glslc"
}

# The fake builder stands where build-llama-preset.sh stands: it writes the
# cache the real configure would write, an executable naming the q8_1 pipeline,
# and the manifest line the caller parses.
preset_fake=$work_root/fake-preset.sh
cat >"$preset_fake" <<'PRESET'
#!/bin/sh
set -eu
source_directory=$2
build_directory=$source_directory/build-$1
mkdir -p "$build_directory/bin"
printf 'Vulkan_GLSLC_EXECUTABLE:FILEPATH=%s\n' "${FAKE_CACHED_GLSLC:-$(command -v glslc)}" \
    >"$build_directory/CMakeCache.txt"
{
    printf '#!/bin/sh\n'
    printf '# %s\n' "${FAKE_PIPELINE_NAME:-mul_mat_vec_q4_k_q8_1_f32}"
} >"$build_directory/bin/llama-server"
chmod 0755 "$build_directory/bin/llama-server"
printf 'candidate_select=%s\n' "$QWEN_LLAMA_CANDIDATE_SELECT"
printf 'preset=%s build=accepted manifest=%s/artifact-manifest.tsv\n' \
    "$1" "$build_directory"
exit "${FAKE_PRESET_STATUS:-0}"
PRESET
chmod 0755 "$preset_fake"

fresh_source() {
    source_directory=$work_root/source-$1
    rm -rf -- "$source_directory"
    mkdir -p "$source_directory"
    git -C "$source_directory" init --quiet
    git -C "$source_directory" -c user.email=t@example.invalid -c user.name=t \
        commit --quiet --allow-empty -m seed
    printf '%s' "$source_directory"
}

run_subject() {
    QWEN_SHADERC_LEDGER=$ledger QWEN_E5_PRESET_SCRIPT=$preset_fake \
        "$subject" "$@" >"$work_root/out.log" 2>&1
}

# An argument count outside one or two is a usage error and exits 2.
status=0
run_subject || status=$?
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'no argument exits 2'

status=0
QWEN_SHADERC_LEDGER=$ledger QWEN_E5_PRESET_SCRIPT=$preset_fake \
    "$subject" "$work_root/absent-source" "$prefix_root" \
    >"$work_root/out.log" 2>&1 || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'an absent checkout exits 1'

# The prefix carries no compiler at all.
source_directory=$(fresh_source missing)
status=0
run_subject "$source_directory" "$work_root/empty-prefixes" || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'an absent pinned glslc exits 1'
report "$(grep -q 'fetch-shaderc-toolchain.sh' "$work_root/out.log" && echo 0 || echo 1)" \
    'the absence names the fetcher'

# A compiler that rejects the extension refuses before any configure runs.
write_glslc 1
source_directory=$(fresh_source rejecting)
status=0
run_subject "$source_directory" "$prefix_root" || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a rejecting glslc exits 1'
report "$(grep -q 'GL_EXT_integer_dot_product' "$work_root/out.log" && echo 0 || echo 1)" \
    'the refusal names the extension'

write_glslc 0

# A build directory configured against another compiler is refused with the
# removal named, since the cached value decides the extension support.
source_directory=$(fresh_source cached)
mkdir -p "$source_directory/build-raven2-vulkan-census"
printf 'Vulkan_GLSLC_EXECUTABLE:FILEPATH=/usr/bin/glslc\n' \
    >"$source_directory/build-raven2-vulkan-census/CMakeCache.txt"
status=0
run_subject "$source_directory" "$prefix_root" || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a foreign cached compiler exits 1'
report "$(grep -q 'GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT' "$work_root/out.log" && echo 0 || echo 1)" \
    'the cache refusal names the configure-time definition'

# A failing preset build ends the recipe.
source_directory=$(fresh_source failing)
status=0
FAKE_CACHED_GLSLC=$glslc FAKE_PRESET_STATUS=7 \
    run_subject "$source_directory" "$prefix_root" || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a failing preset build exits 1'

# A server carrying no q8_1 pipeline name is the silent failure the pin removes.
source_directory=$(fresh_source unnamed)
status=0
FAKE_CACHED_GLSLC=$glslc FAKE_PIPELINE_NAME=mul_mat_vec_q4_k_f16 \
    run_subject "$source_directory" "$prefix_root" || status=$?
report "$([ "$status" -eq 1 ] && echo 0 || echo 1)" 'a server without the q8_1 pipeline exits 1'

# The accepted path writes one receipt binding the compiler and the series.
source_directory=$(fresh_source accepted)
status=0
FAKE_CACHED_GLSLC=$glslc run_subject "$source_directory" "$prefix_root" || status=$?
report "$status" 'the accepted build exits 0'
receipt=$source_directory/build-raven2-vulkan-census/e5-build.tsv
report "$([ -r "$receipt" ] && echo 0 || echo 1)" 'the accepted build writes a receipt'
report "$(grep -qx 'schema	e5-build-v1' "$receipt" && echo 0 || echo 1)" \
    'the receipt declares its schema'
report "$(grep -qx 'candidate_series	llama-vulkan-pipeline-census.patch,llama-vulkan-q4k-int24-mmvq.patch' \
    "$receipt" && echo 0 || echo 1)" 'the receipt names both candidate patches'
report "$(grep -q "^glslc	$glslc\$" "$receipt" && echo 0 || echo 1)" \
    'the receipt names the pinned compiler'
report "$(grep -q 'llama-vulkan-q4k-int24-mmvq.patch' "$work_root/out.log" && echo 0 || echo 1)" \
    'the builder is called with the int24 candidate selected'

if [ "$failures" -ne 0 ]; then
    printf 'build-llama-e5 checks failed: %s\n' "$failures" >&2
    exit 1
fi
printf 'build-llama-e5 checks passed\n'
