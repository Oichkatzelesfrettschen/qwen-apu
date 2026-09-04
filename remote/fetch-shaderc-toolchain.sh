#!/bin/sh
set -eu

# Fetch and build the pinned SPIR-V producer into a prefix of its own, so the
# E5-S shader pack is compiled by a stated compiler rather than by whichever
# glslc a host happens to carry. The system toolchain stays where it is: nothing
# here installs outside the prefix, and build-spirv-shader-pack.sh reaches this
# one through QWEN_SHADER_PACK_GLSLC alone.
#
# remote/shaderc-toolchain.tsv is the one authority for the revision, the
# archive, and its digest. A row reading `-` refuses the fetch, because an
# archive downloaded against no expectation pins nothing and a digest recalled
# rather than read from the publisher is a fabricated pin.
#
# usage: fetch-shaderc-toolchain.sh [PREFIX_ROOT]
#   PREFIX_ROOT   directory the prefix is created under, default ~/opt

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [PREFIX_ROOT]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
prefix_root=${1:-"${HOME:?}/opt"}
toolchain_ledger=${QWEN_SHADERC_LEDGER:-$script_directory/shaderc-toolchain.tsv}

if [ ! -r "$toolchain_ledger" ]; then
    printf 'the shaderc toolchain ledger is unreadable: %s\n' "$toolchain_ledger" >&2
    exit 1
fi

read_ledger_value() {
    awk -F'\t' -v key="$1" '
        /^#/ || NF == 0 { next }
        NF != 2 { printf "malformed shaderc toolchain row: %s\n", $0 > "/dev/stderr"; exit 1 }
        $1 == key { print $2; found = 1 }
        END { exit found ? 0 : 1 }
    ' "$toolchain_ledger"
}

for ledger_key in project revision archive_url archive_sha256 prefix minimum_glslc_version; do
    if ! read_ledger_value "$ledger_key" >/dev/null; then
        printf 'the shaderc toolchain ledger names no %s\n' "$ledger_key" >&2
        exit 1
    fi
done

toolchain_project=$(read_ledger_value project)
toolchain_revision=$(read_ledger_value revision)
toolchain_archive_url=$(read_ledger_value archive_url)
toolchain_archive_sha256=$(read_ledger_value archive_sha256)
toolchain_prefix_name=$(read_ledger_value prefix)
toolchain_minimum_version=$(read_ledger_value minimum_glslc_version)

for pinned_field in "$toolchain_revision" "$toolchain_archive_url" "$toolchain_archive_sha256"; do
    if [ "$pinned_field" = - ] || [ -z "$pinned_field" ]; then
        printf 'the shaderc toolchain ledger carries no pin: revision=%s archive_url=%s archive_sha256=%s\n' \
            "$toolchain_revision" "$toolchain_archive_url" "$toolchain_archive_sha256" >&2
        printf 'record the upstream release archive and its published SHA-256 in %s before fetching\n' \
            "$toolchain_ledger" >&2
        exit 1
    fi
done

case $toolchain_prefix_name in
    */* | '' | .* )
        printf 'the prefix name is one plain directory component: %s\n' \
            "$toolchain_prefix_name" >&2
        exit 1
        ;;
esac

prefix_directory=$prefix_root/$toolchain_prefix_name
if [ -e "$prefix_directory" ]; then
    printf 'the prefix already exists, so the fetch would build over a toolchain a pack may name: %s\n' \
        "$prefix_directory" >&2
    exit 1
fi

# git and python3 are the two utils/git-sync-deps runs on: it reads the
# revision's own DEPS with python3 and clones each dependency with git, so their
# absence fails after the archive is verified rather than before the fetch.
for required_program in curl cmake ninja sha256sum tar git python3; do
    if ! command -v "$required_program" >/dev/null 2>&1; then
        printf 'the toolchain build requires %s\n' "$required_program" >&2
        exit 1
    fi
done

work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT HUP INT TERM

archive_path=$work_directory/shaderc-archive.tar.gz
printf 'shaderc_fetch=start project=%s revision=%s\n' \
    "$toolchain_project" "$toolchain_revision"
curl --fail --location --silent --show-error --output "$archive_path" \
    "$toolchain_archive_url"
observed_archive_sha256=$(sha256sum "$archive_path" | cut -d ' ' -f 1)
if [ "$observed_archive_sha256" != "$toolchain_archive_sha256" ]; then
    printf 'the archive digest differs from the pin: expected %s observed %s\n' \
        "$toolchain_archive_sha256" "$observed_archive_sha256" >&2
    exit 1
fi
printf 'shaderc_archive=verified sha256=%s\n' "$observed_archive_sha256"

mkdir -p "$work_directory/source"
tar -xzf "$archive_path" -C "$work_directory/source" --strip-components=1

# shaderc vendors its own dependency revisions through this script, so the
# build pins glslang and SPIRV-Tools by the shaderc revision rather than by the
# host's packages.
( cd "$work_directory/source" && ./utils/git-sync-deps )

cmake -S "$work_directory/source" -B "$work_directory/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix_directory" \
    -DSHADERC_SKIP_TESTS=ON \
    -DSHADERC_SKIP_EXAMPLES=ON
cmake --build "$work_directory/build"
cmake --install "$work_directory/build"

glslc_program=$prefix_directory/bin/glslc
if [ ! -x "$glslc_program" ]; then
    printf 'the build installed no glslc under %s\n' "$prefix_directory" >&2
    exit 1
fi
glslc_version=$("$glslc_program" --version | head -n 1)
printf 'shaderc_prefix=installed glslc_version=%s glslc_sha256=%s minimum=%s\n' \
    "$glslc_version" "$(sha256sum "$glslc_program" | cut -d ' ' -f 1)" \
    "$toolchain_minimum_version"
# The extension is what the pack exists to reach, so the fetch proves the
# installed compiler accepts it rather than leaving that to the first pack.
extension_probe=$work_directory/extension-probe.comp
cat >"$extension_probe" <<'PROBE'
#version 450
#extension GL_EXT_integer_dot_product : require
layout(local_size_x = 1) in;
layout(binding = 0) buffer Result { int value; } result;
void main() {
    result.value = dotPacked4x8EXT(0x01020304, 0x05060708);
}
PROBE
if ! "$glslc_program" --target-env=vulkan1.2 -fshader-stage=compute \
    -o "$work_directory/extension-probe.spv" "$extension_probe"; then
    printf 'the installed glslc rejects GL_EXT_integer_dot_product, which is the whole reason for the prefix\n' >&2
    exit 1
fi
printf 'shaderc_extension=accepted name=GL_EXT_integer_dot_product\n'
