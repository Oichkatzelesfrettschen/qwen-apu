#!/bin/sh
set -eu

# The two cache key derivations under fixture inputs, driven as functions so
# every field is moved one at a time. A key is only worth the artifacts it
# substitutes, so the test states both directions: content decides the value
# and location does not.
#
# The fixtures stand in for a shader tree, a generator source, and glslc, which
# keeps the run hermetic; a real Vulkan toolchain is what the build itself
# exercises.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

# shellcheck source=remote/build-cache-keys.sh
. "$script_directory/build-cache-keys.sh"

checks=0
failures=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}
expect_equal() {
    report "$1" "$([ "$2" = "$3" ] && echo same || echo differs)"
    if [ "$2" != "$3" ]; then
        printf 'expected equal keys for %s: %s and %s\n' "$1" "$2" "$3" >&2
        failures=$((failures + 1))
    fi
}
expect_differs() {
    report "$1" "$([ "$2" = "$3" ] && echo same || echo differs)"
    if [ "$2" = "$3" ]; then
        printf 'expected different keys for %s: both %s\n' "$1" "$2" >&2
        failures=$((failures + 1))
    fi
}

# One shader tree, planted at two prefixes whose names differ in length so a
# leaked absolute path would move the digest visibly.
plant_shader_tree() {
    mkdir -p "$1/feature-tests"
    printf 'void main() { gl_Position = vec4(0.0); }\n' >"$1/add.comp"
    printf 'void main() { /* mul */ }\n' >"$1/mul_mm.comp"
    printf '#define QUANT_K 256\n' >"$1/dequant_head.glsl"
    printf 'void main() {}\n' >"$1/feature-tests/coopmat.comp"
    printf 'cmake_minimum_required(VERSION 3.19)\n' >"$1/CMakeLists.txt"
}
tree_a=$work_directory/a/vulkan-shaders
tree_b=$work_directory/a-much-longer-prefix/vulkan-shaders
mkdir -p "$work_directory/a" "$work_directory/a-much-longer-prefix"
plant_shader_tree "$tree_a"
plant_shader_tree "$tree_b"

generator_a=$work_directory/a/vulkan-shaders-gen.cpp
generator_b=$work_directory/a-much-longer-prefix/vulkan-shaders-gen.cpp
printf 'int main() { return 0; }\n' >"$generator_a"
cp "$generator_a" "$generator_b"

# A glslc stand-in whose digest and version report are both fields of the key.
glslc_a=$work_directory/a/glslc
cat >"$glslc_a" <<'FIXTURE'
#!/bin/sh
printf 'shaderc fixture\n1.0.0\n'
FIXTURE
chmod 0755 "$glslc_a"
glslc_b=$work_directory/a-much-longer-prefix/glslc
cp "$glslc_a" "$glslc_b"

commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
options='-DGGML_VULKAN=ON -DGGML_VULKAN_PIPELINE_CENSUS=ON'

key_a=$(qwen_shader_pack_key "$tree_a" "$generator_a" "$commit" "$options" "$glslc_a")
key_b=$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")
expect_equal shader_pack_key_across_paths "$key_a" "$key_b"

# One byte inside one shader source, which is the change the pack exists to
# notice.
sed -i 's/vec4(0.0)/vec4(1.0)/' "$tree_b/add.comp"
key_byte=$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")
expect_differs shader_pack_key_on_shader_byte "$key_a" "$key_byte"
sed -i 's/vec4(1.0)/vec4(0.0)/' "$tree_b/add.comp"
expect_equal shader_pack_key_restored "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")"

# A file added under the tree, which no digest of the previous members covers.
printf 'void main() {}\n' >"$tree_b/sub.comp"
expect_differs shader_pack_key_on_added_shader "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")"
rm -f "$tree_b/sub.comp"

# The generator writes the embed sources and drives glslc, so its own content
# is a field beside the shaders it reads.
printf 'int main() { return 1; }\n' >"$generator_b"
expect_differs shader_pack_key_on_generator "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")"
cp "$generator_a" "$generator_b"

# The options CMake forwards into the generator sub-build, and the whitespace
# spelling that must not move the value.
expect_differs shader_pack_key_on_options "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" \
        '-DGGML_VULKAN=ON' "$glslc_b")"
expect_equal shader_pack_key_on_flag_whitespace "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" \
        '  -DGGML_VULKAN=ON
    -DGGML_VULKAN_PIPELINE_CENSUS=ON  ' "$glslc_b")"

# glslc decides the SPIR-V, so a replacement toolchain invalidates the pack
# through both its digest and its version report.
printf '#!/bin/sh\nprintf "shaderc fixture\\n1.0.0\\n"\nexit 0\n' >"$glslc_b"
chmod 0755 "$glslc_b"
expect_differs shader_pack_key_on_glslc_digest "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")"
cat >"$glslc_b" <<'FIXTURE'
#!/bin/sh
printf 'shaderc fixture\n2.0.0\n'
FIXTURE
chmod 0755 "$glslc_b"
expect_differs shader_pack_key_on_glslc_version "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" "$commit" "$options" "$glslc_b")"
cp "$glslc_a" "$glslc_b"

expect_differs shader_pack_key_on_commit "$key_a" \
    "$(qwen_shader_pack_key "$tree_b" "$generator_b" \
        0000000000000000000000000000000000000000 "$options" "$glslc_b")"

# The binary key, moved one field at a time against a fixed baseline.
production_series=1111111111111111111111111111111111111111111111111111111111111111
candidate_series=2222222222222222222222222222222222222222222222222222222222222222
preset=raven2-vulkan-census
cmake_flags='-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON'
compiler_flags='-march=znver1 -mtune=znver1'
compiler_identity='cc (GCC) 15.2.1 20260101'

binary_key() {
    qwen_instrument_binary_key "${1:-$commit}" "${2:-$production_series}" \
        "${3:-$candidate_series}" "${4:-$preset}" "${5:-$cmake_flags}" \
        "${6:-$compiler_flags}" "${7:-$compiler_identity}" "${8:-$key_a}"
}
binary_baseline=$(binary_key)
expect_equal binary_key_repeats "$binary_baseline" "$(binary_key)"
expect_equal binary_key_across_shader_tree_paths "$binary_baseline" \
    "$(binary_key '' '' '' '' '' '' '' "$key_b")"
expect_differs binary_key_on_candidate_series "$binary_baseline" \
    "$(binary_key '' '' 3333333333333333333333333333333333333333333333333333333333333333)"
expect_differs binary_key_on_production_series "$binary_baseline" \
    "$(binary_key '' 4444444444444444444444444444444444444444444444444444444444444444)"
expect_differs binary_key_on_commit "$binary_baseline" \
    "$(binary_key 0000000000000000000000000000000000000000)"
expect_differs binary_key_on_preset "$binary_baseline" \
    "$(binary_key '' '' '' raven2-vulkan-production)"
expect_differs binary_key_on_cmake_flags "$binary_baseline" \
    "$(binary_key '' '' '' '' '-DCMAKE_BUILD_TYPE=Release')"
expect_differs binary_key_on_compiler_flags "$binary_baseline" \
    "$(binary_key '' '' '' '' '' '-fno-omit-frame-pointer')"
expect_differs binary_key_on_compiler_identity "$binary_baseline" \
    "$(binary_key '' '' '' '' '' '' 'cc (GCC) 14.2.0')"
expect_differs binary_key_on_shader_pack "$binary_baseline" \
    "$(binary_key '' '' '' '' '' '' '' "$key_byte")"

# The store location, which a test and a builder both resolve through one
# function rather than spelling the default twice.
expect_equal cache_directory_override "$work_directory/store" \
    "$(QWEN_BUILD_CACHE_DIR=$work_directory/store qwen_build_cache_directory)"
expect_equal cache_directory_default "${HOME:?}/.cache/qwen-apu-build" \
    "$(QWEN_BUILD_CACHE_DIR='' qwen_build_cache_directory)"

# The pack round trip. A pack answers with its own bytes or refuses, so the
# checks are content restored, a refusal at another build directory, and a
# refusal on a member that no longer matches the digest the pack recorded.
pack_root=$work_directory/packs
pack_source=$work_directory/pack-source
pack_build=$work_directory/pack-build
mkdir -p "$pack_source/ggml/src/ggml-vulkan/vulkan-shaders" \
    "$pack_build/ggml/src/ggml-vulkan/vulkan-shaders.spv"
printf 'void main() {}\n' >"$pack_source/ggml/src/ggml-vulkan/vulkan-shaders/add.comp"
printf 'const unsigned char add_data[] = {0};\n' \
    >"$pack_build/ggml/src/ggml-vulkan/add.comp.cpp"
printf 'add.comp.cpp: add.comp\n' >"$pack_build/ggml/src/ggml-vulkan/add.comp.cpp.d"
printf '#pragma once\n' >"$pack_build/ggml/src/ggml-vulkan/ggml-vulkan-shaders.hpp"
printf 'spv\n' >"$pack_build/ggml/src/ggml-vulkan/vulkan-shaders.spv/add.spv"
printf 'ninja deps\n' >"$pack_build/.ninja_deps"
printf 'ninja log\n' >"$pack_build/.ninja_log"

qwen_shader_pack_store "$pack_root" "$key_a" "$pack_build" "$pack_source" "$commit"
report pack_member_count "$(wc -l <"$(qwen_shader_pack_directory "$pack_root" \
    "$key_a" "$pack_build" "$pack_source")/SHA256SUMS")"
find "$pack_build/ggml" -type f -delete
rm -f "$pack_build/.ninja_deps" "$pack_build/.ninja_log"
touch "$pack_source/ggml/src/ggml-vulkan/vulkan-shaders/add.comp"
pack_shader_source=$pack_source/ggml/src/ggml-vulkan/vulkan-shaders/add.comp
pack_source_mtime_before=$(stat -c %y "$pack_shader_source")
pack_mtime_save=$work_directory/shader-source-mtimes
if qwen_shader_pack_restore "$pack_root" "$key_a" "$pack_build" "$pack_source" \
    "$pack_mtime_save"; then
    report pack_restore accepted
else
    report pack_restore refused
    failures=$((failures + 1))
fi
expect_equal pack_restored_content 'spv' \
    "$(cat "$pack_build/ggml/src/ggml-vulkan/vulkan-shaders.spv/add.spv")"
expect_equal pack_restored_ninja_deps 'ninja deps' "$(cat "$pack_build/.ninja_deps")"
# The stamp is what keeps a restored output newer than a source the checkout
# touched, which is the comparison ninja makes before it declares an edge dirty.
expect_equal pack_source_stamped 2000 \
    "$(date -r "$pack_shader_source" +%Y)"

# The stamp belongs to the build that restored the pack. Every other build
# directory over the same checkout compares its own generated outputs against
# these sources, so the times the checkout held are put back once that build
# exits, to the nanosecond stat reports.
qwen_shader_source_mtimes_apply "$pack_mtime_save"
expect_equal pack_source_mtime_returned "$pack_source_mtime_before" \
    "$(stat -c %y "$pack_shader_source")"
report pack_mtime_save_consumed "$([ -e "$pack_mtime_save" ] && echo present || echo removed)"
if [ -e "$pack_mtime_save" ]; then
    failures=$((failures + 1))
fi

if qwen_shader_pack_restore "$pack_root" "$key_a" "$work_directory/other-build" \
    "$pack_source" 2>/dev/null; then
    report pack_restore_foreign_build_directory accepted
    failures=$((failures + 1))
else
    report pack_restore_foreign_build_directory refused
fi

# Ninja's two logs are what make a restored output current, so a build
# directory holding the generated files alone stores nothing.
rm -f "$pack_build/.ninja_deps"
if qwen_shader_pack_store "$pack_root/logless" "$key_a" "$pack_build" \
    "$pack_source" "$commit"; then
    report pack_store_without_ninja_deps accepted
    failures=$((failures + 1))
else
    report pack_store_without_ninja_deps refused
fi
printf 'ninja deps\n' >"$pack_build/.ninja_deps"

pack_directory=$(qwen_shader_pack_directory "$pack_root" "$key_a" "$pack_build" \
    "$pack_source")
printf 'tampered\n' >"$pack_directory/files/ggml/src/ggml-vulkan/vulkan-shaders.spv/add.spv"
if qwen_shader_pack_restore "$pack_root" "$key_a" "$pack_build" "$pack_source"; then
    report pack_restore_tampered_member accepted
    failures=$((failures + 1))
else
    report pack_restore_tampered_member refused
fi

# The binary key states the compiled source through the commit and the two
# series digests, so a checkout carrying a modification those digests never
# accounted for holds bytes the key attributes to the clean commit. The
# admission is driven over a real checkout, since git status is the authority
# it reads.
keyed_source=$work_directory/keyed-source
mkdir -p "$keyed_source/tools/server"
git -C "$keyed_source" init --quiet
git -C "$keyed_source" config user.email fixture@example.invalid
git -C "$keyed_source" config user.name fixture
printf 'int main() { return 0; }\n' >"$keyed_source/tools/server/server-context.cpp"
printf 'int helper() { return 0; }\n' >"$keyed_source/tools/server/utils.hpp"
git -C "$keyed_source" add -A
git -C "$keyed_source" commit --quiet -m 'fixture commit'
series_paths='tools/server/server-context.cpp'

expect_keyed() {
    if qwen_binary_tree_is_keyed "$keyed_source" "$2" "$3"; then
        report "$1" keyed
    else
        report "$1" unkeyed
    fi
    if [ "$4" = keyed ] && ! qwen_binary_tree_is_keyed "$keyed_source" "$2" "$3"; then
        printf 'expected a keyed tree for %s\n' "$1" >&2
        failures=$((failures + 1))
    fi
    if [ "$4" = unkeyed ] && qwen_binary_tree_is_keyed "$keyed_source" "$2" "$3"; then
        printf 'expected an unkeyed tree for %s\n' "$1" >&2
        failures=$((failures + 1))
    fi
}

expect_keyed binary_tree_clean_checkout verified "$series_paths" keyed
printf 'int main() { return 1; }\n' >"$keyed_source/tools/server/server-context.cpp"
expect_keyed binary_tree_series_path_modified verified "$series_paths" keyed
expect_keyed binary_tree_series_path_unverified divergent "$series_paths" unkeyed
printf 'int helper() { return 1; }\n' >"$keyed_source/tools/server/utils.hpp"
expect_keyed binary_tree_foreign_path_modified verified "$series_paths" unkeyed
git -C "$keyed_source" checkout --quiet -- tools/server/utils.hpp
printf 'int stray() { return 0; }\n' >"$keyed_source/tools/server/stray.cpp"
expect_keyed binary_tree_untracked_path verified "$series_paths" unkeyed
rm -f "$keyed_source/tools/server/stray.cpp"
expect_keyed binary_tree_empty_covered_set verified '' unkeyed

if [ "$failures" -ne 0 ]; then
    printf 'build cache key checks: %s of %s failed\n' "$failures" "$checks" >&2
    exit 1
fi
printf 'build_cache_keys=verified checks=%s\n' "$checks"
