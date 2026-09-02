#!/bin/sh
# The build-graph cache key derivations, as functions a builder sources and a
# unit test drives directly.
#
# A key answers one question: may the artifacts stored under it be substituted
# for the work that would produce them. Every input that changes an artifact is
# a field, and nothing else is, so two checkouts of the same content at two
# paths derive one key while a single changed byte derives another. Each key is
# the SHA-256 of a canonical block of tab-separated name and value lines, which
# keeps field association inside the digest rather than concatenating bare
# hashes whose order a reader has to trust.
#
# The file defines functions and touches no state, so sourcing it is safe from
# a builder that has already parsed its own arguments.

# The store both key spaces live under. QWEN_BUILD_CACHE_DIR moves it whole,
# which is what a test uses to keep its packs out of the real cache.
qwen_build_cache_directory() {
    printf '%s\n' "${QWEN_BUILD_CACHE_DIR:-${HOME:?}/.cache/qwen-apu-build}"
}

# A flag string reaches a key through one spelling: interior runs of blanks and
# newlines collapse to one space and the ends are trimmed, so a continuation
# line in a preset and its single-line equivalent hash alike.
qwen_normalize_flags() {
    printf '%s' "$1" | tr -s ' \t\n' ' ' | sed 's/^ //; s/ $//'
}

qwen_sha256_file() {
    sha256sum "$1" | cut -d ' ' -f 1
}

qwen_sha256_stream() {
    sha256sum | cut -d ' ' -f 1
}

# The shader tree digest: repository-relative path, byte count, and content
# digest of every regular file under vulkan-shaders/, in LC_ALL=C path order.
# Paths are relative to that directory, so the same tree unpacked at two
# prefixes digests alike while a renamed or added file moves the value.
qwen_shader_tree_digest() {
    qwen_shader_tree_directory=$1
    (
        cd -- "$qwen_shader_tree_directory" || exit 1
        find . -type f | LC_ALL=C sort |
        while IFS= read -r shader_tree_member; do
            printf '%s\t%s\t%s\n' \
                "${shader_tree_member#./}" \
                "$(wc -c <"$shader_tree_member" | tr -d ' ')" \
                "$(sha256sum "$shader_tree_member" | cut -d ' ' -f 1)"
        done
    ) | qwen_sha256_stream
}

# The pack key. glslc decides the SPIR-V a shader source compiles to, so its
# executable digest and its own version report are fields beside the sources;
# ggml/src/ggml-vulkan/CMakeLists.txt forwards the GGML_VULKAN* options into
# the generator sub-build, so the options in force are a third.
#
# usage: qwen_shader_pack_key SHADER_TREE GENERATOR_SOURCE COMMIT OPTIONS GLSLC
qwen_shader_pack_key() {
    qwen_pack_shader_tree=$1
    qwen_pack_generator_source=$2
    qwen_pack_commit=$3
    qwen_pack_options=$4
    qwen_pack_glslc=$5
    {
        printf 'schema\tqwen-shader-pack-v1\n'
        printf 'llama_commit\t%s\n' "$qwen_pack_commit"
        printf 'shader_tree_sha256\t%s\n' \
            "$(qwen_shader_tree_digest "$qwen_pack_shader_tree")"
        printf 'shader_generator_sha256\t%s\n' \
            "$(qwen_sha256_file "$qwen_pack_generator_source")"
        printf 'vulkan_options\t%s\n' "$(qwen_normalize_flags "$qwen_pack_options")"
        printf 'glslc_sha256\t%s\n' "$(qwen_sha256_file "$qwen_pack_glslc")"
        printf 'glslc_version\t%s\n' \
            "$(qwen_normalize_flags "$("$qwen_pack_glslc" --version 2>&1)")"
    } | qwen_sha256_stream
}

# The binary key. The commit and the two series digests identify the compiled
# source, the preset and both flag strings identify what the compiler was told,
# the compiler identity identifies what did the telling, and the pack key
# carries every shader input by reference. A tree at another path with the same
# content derives the same value, which is the property that lets a freshly
# prepared candidate tree reuse a binary built from its predecessor.
#
# usage: qwen_instrument_binary_key COMMIT PRODUCTION_SERIES CANDIDATE_SERIES
#            PRESET CMAKE_FLAGS COMPILER_FLAGS COMPILER_IDENTITY SHADER_PACK_KEY
qwen_instrument_binary_key() {
    {
        printf 'schema\tqwen-instrument-binary-v1\n'
        printf 'llama_commit\t%s\n' "$1"
        printf 'patch_series_sha256\t%s\n' "$2"
        printf 'candidate_series_sha256\t%s\n' "$3"
        printf 'preset\t%s\n' "$4"
        printf 'cmake_flags\t%s\n' "$(qwen_normalize_flags "$5")"
        printf 'compiler_flags\t%s\n' "$(qwen_normalize_flags "$6")"
        printf 'compiler_identity\t%s\n' "$(qwen_normalize_flags "$7")"
        printf 'shader_pack_key\t%s\n' "$8"
    } | qwen_sha256_stream
}

# The compiler identity a binary key carries: the first line of the driver's
# own version report, which names the vendor, the release, and the target.
qwen_compiler_identity() {
    "${1:-cc}" --version 2>/dev/null | head -1
}

# The mtime every shader source carries after a pack restore. Ninja decides an
# output dirty by comparing it against each input's mtime, and a freshly
# prepared candidate tree stamps its sources with the checkout time, which is
# later than the packed outputs. Stamping the sources at a constant older than
# any pack restores the ordering the generator would have produced, and the
# direction is safe for every other build directory over the same tree: an
# input moving backwards leaves an existing output current.
QWEN_SHADER_SOURCE_MTIME=200001010000.00

# The build-directory-relative members of a shader pack, printed one per line.
# The generator writes the embed sources, the header, the SPIR-V, and the
# glslc depfiles; ninja's two logs travel with them because they are what
# ninja reads to decide the restored outputs are current.
#
# usage: qwen_shader_pack_members BUILD_DIRECTORY
qwen_shader_pack_members() {
    (
        cd -- "$1" || exit 1
        find ggml/src/ggml-vulkan -maxdepth 1 -type f \
            \( -name 'ggml-vulkan-shaders.hpp' -o -name '*.comp.cpp' \
               -o -name '*.comp.cpp.d' \) 2>/dev/null
        find ggml/src/ggml-vulkan/vulkan-shaders.spv -type f 2>/dev/null
        for ninja_log in .ninja_deps .ninja_log; do
            [ -f "$ninja_log" ] && printf '%s\n' "$ninja_log"
        done
        true
    ) | LC_ALL=C sort
}

# A pack is bound to the absolute source and build directory paths it was
# produced from, because ninja's build log hashes the whole command string and
# its deps log keys outputs by build-directory-relative path; a restore into
# another pair of paths reproduces neither. The binding names a directory below
# the key rather than joining the key, which keeps the key a statement about
# content alone and lets two presets over one source tree hold their own packs
# instead of overwriting each other under one name.
#
# usage: qwen_shader_pack_directory PACK_ROOT KEY BUILD_DIRECTORY SOURCE_DIRECTORY
qwen_shader_pack_directory() {
    printf '%s/%s/%s\n' "$1" "$2" "$(
        printf 'source_directory\t%s\nbuild_directory\t%s\n' "$4" "$3" |
            qwen_sha256_stream
    )"
}

# Store one pack. Assembly happens under a sibling staging name and lands by
# rename, so a reader either sees a complete pack or none.
#
# usage: qwen_shader_pack_store PACK_ROOT KEY BUILD_DIRECTORY SOURCE_DIRECTORY COMMIT
qwen_shader_pack_store() {
    qwen_store_root=$1
    qwen_store_key=$2
    qwen_store_build=$3
    qwen_store_source=$4
    qwen_store_commit=$5
    qwen_store_members=$(qwen_shader_pack_members "$qwen_store_build")
    if [ -z "$qwen_store_members" ]; then
        return 1
    fi
    # Ninja reads the two logs to decide a restored output is current, so a
    # member set missing either one restores files that are regenerated
    # anyway. Refusing the store keeps the key free for a completed build
    # rather than filling it with a pack that reads restored and rebuilds.
    for qwen_store_required in .ninja_deps .ninja_log; do
        case "
$qwen_store_members
" in
            *"
$qwen_store_required
"*) ;;
            *) return 1 ;;
        esac
    done
    qwen_store_pack=$(qwen_shader_pack_directory "$qwen_store_root" \
        "$qwen_store_key" "$qwen_store_build" "$qwen_store_source")
    qwen_store_staging=$qwen_store_root/.staging-$$-$qwen_store_key
    rm -rf "$qwen_store_staging"
    mkdir -p "$qwen_store_staging/files"
    printf '%s\n' "$qwen_store_members" |
    while IFS= read -r qwen_store_member; do
        mkdir -p "$qwen_store_staging/files/$(dirname -- "$qwen_store_member")"
        cp -a "$qwen_store_build/$qwen_store_member" \
            "$qwen_store_staging/files/$qwen_store_member" || exit 1
    done || { rm -rf "$qwen_store_staging"; return 1; }
    (
        cd -- "$qwen_store_staging/files" &&
        printf '%s\n' "$qwen_store_members" | xargs -r sha256sum
    ) >"$qwen_store_staging/SHA256SUMS" || {
        rm -rf "$qwen_store_staging"
        return 1
    }
    {
        printf 'schema\tqwen-shader-pack-v1\n'
        printf 'shader_pack_key\t%s\n' "$qwen_store_key"
        printf 'llama_commit\t%s\n' "$qwen_store_commit"
        printf 'source_directory\t%s\n' "$qwen_store_source"
        printf 'build_directory\t%s\n' "$qwen_store_build"
        printf 'source_mtime\t%s\n' "$QWEN_SHADER_SOURCE_MTIME"
        printf 'member_count\t%s\n' "$(printf '%s\n' "$qwen_store_members" | wc -l)"
    } >"$qwen_store_staging/manifest.tsv"
    rm -rf "${qwen_store_pack:?}"
    mkdir -p "$(dirname -- "$qwen_store_pack")"
    mv "$qwen_store_staging" "$qwen_store_pack"
}

# Restore one pack, or report why it cannot be used. Every member is verified
# against the pack's own SHA256SUMS before a byte reaches the build directory,
# the copy preserves mtimes because ninja's deps log records the output mtime
# it stored dependencies for, and the shader sources are stamped at the
# constant so each restored output stays newer than every input it reads.
#
# usage: qwen_shader_pack_restore PACK_ROOT KEY BUILD_DIRECTORY SOURCE_DIRECTORY
qwen_shader_pack_restore() {
    qwen_restore_root=$1
    qwen_restore_key=$2
    qwen_restore_build=$3
    qwen_restore_source=$4
    qwen_restore_pack=$(qwen_shader_pack_directory "$qwen_restore_root" \
        "$qwen_restore_key" "$qwen_restore_build" "$qwen_restore_source")
    [ -r "$qwen_restore_pack/manifest.tsv" ] || return 1
    [ -r "$qwen_restore_pack/SHA256SUMS" ] || return 1
    qwen_restore_field() {
        awk -F'\t' -v key="$1" '$1 == key { count++; value = $2 }
            END { if (count != 1) exit 1; print value }' \
            "$qwen_restore_pack/manifest.tsv"
    }
    [ "$(qwen_restore_field shader_pack_key)" = "$qwen_restore_key" ] || return 1
    [ "$(qwen_restore_field build_directory)" = "$qwen_restore_build" ] || return 1
    [ "$(qwen_restore_field source_directory)" = "$qwen_restore_source" ] || return 1
    ( cd -- "$qwen_restore_pack/files" &&
      sha256sum --quiet -c "$qwen_restore_pack/SHA256SUMS" ) >/dev/null 2>&1 ||
        return 1
    while IFS= read -r qwen_restore_member; do
        mkdir -p "$qwen_restore_build/$(dirname -- "$qwen_restore_member")" || return 1
        cp -a "$qwen_restore_pack/files/$qwen_restore_member" \
            "$qwen_restore_build/$qwen_restore_member" || return 1
    done <<PACK_MEMBERS
$(cut -d ' ' -f 3- <"$qwen_restore_pack/SHA256SUMS")
PACK_MEMBERS
    find "$qwen_restore_source/ggml/src/ggml-vulkan/vulkan-shaders" -type f \
        -exec touch -t "$(qwen_restore_field source_mtime)" {} + || return 1
}
