#!/bin/sh
set -eu

# Build one RADV carrying Mesa merge request 2115's target-aware ACO lowering
# into a prefix of its own, and write the environment fragment that hands it to
# the launch chain. The system driver stays where it is: meson's
# `radeon_devenv_icd.x86_64.json` target names the build directory in its own
# `library_path`, so the ICD is selected by an environment variable and nothing
# is installed over `vulkan-radeon`.
#
# The pin is the mechanism rather than a label.
# `70949d3d4846e809f38549eac6e2f942300de0ad` sets `has_accelerated_dot_product`
# false for Raven, Raven2, Vega10, and Renoir and lowers
# `nir_op_sdot_4x8_iadd` in `emit_soft_idot_4x8` to four byte-extract-folded
# 24-bit multiplies feeding two `v_add3_u32` reductions, six arithmetic
# instructions against the generic expansion's seven. It reached the fork as
# merge `f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb`, so a revision that does not
# carry that merge as an ancestor produces E5-S0's ISA under E5-S1's name and
# the build refuses it here rather than after the receipt is written.
#
# `-Dllvm=enabled` is required for the disassembler rather than for ACO:
# `radv_shader.c` reaches LLVM's disassembler component even though ACO compiles,
# and a `-Dllvm=disabled` driver prints ACO's pre-RA IR instead, which the shader
# lab's mnemonic counter reads as zero in every field. `-Dtools=drm-shim` builds
# `libamdgpu_noop_drm_shim.so`, the interposer that supplies a RAVEN2 device node
# on a host owning no AMD part; `ac_gpu_info.c` refuses a node below DRM 3.54.0,
# so the shim and the ICD come from this one build rather than from two releases.
#
# The build reads the checkout and writes nothing into it. A source tree whose
# HEAD is another revision is refused rather than moved, because the tree may be
# a working copy someone else holds.
#
# usage: build-isolated-radv.sh SOURCE_DIRECTORY [PREFIX_ROOT]
#   SOURCE_DIRECTORY  a Mesa checkout whose HEAD is the pinned revision
#   PREFIX_ROOT       directory the prefix is created under, default ~/.local
#
#   QWEN_RADV_REVISION       the pinned revision, default the E5-S1 receipt's
#   QWEN_RADV_LOWERING_MERGE the merge every admitted revision descends from
#   QWEN_MESON, QWEN_NINJA, QWEN_GIT   the three programs the build runs

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s SOURCE_DIRECTORY [PREFIX_ROOT]\n' "$0" >&2
    exit 2
fi

source_directory=$1
prefix_root=${2:-"${HOME:?}/.local"}

# The revision E5-S1's isa-post-2115 receipt was measured through, three merges
# past the lowering, and the merge it must descend from.
pinned_revision=${QWEN_RADV_REVISION:-9ae8ce550453b9e19f14dc1c9a41b913a9005e48}
lowering_merge=${QWEN_RADV_LOWERING_MERGE:-f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb}

meson_program=${QWEN_MESON:-meson}
ninja_program=${QWEN_NINJA:-ninja}
git_program=${QWEN_GIT:-git}

for required_program in "$meson_program" "$ninja_program" "$git_program"; do
    if ! command -v "$required_program" >/dev/null 2>&1; then
        printf 'the isolated driver build requires %s\n' "$required_program" >&2
        exit 1
    fi
done

if [ ! -d "$source_directory/.git" ]; then
    printf 'the source directory is a Mesa git checkout: %s\n' "$source_directory" >&2
    exit 1
fi
source_root=$(CDPATH='' cd -- "$source_directory" && pwd)

case $pinned_revision in
    *[!0-9a-f]* | '')
        printf 'the pinned revision is a full lowercase hexadecimal object name: %s\n' \
            "$pinned_revision" >&2
        exit 1
        ;;
esac

head_revision=$("$git_program" -C "$source_root" rev-parse HEAD)
if [ "$head_revision" != "$pinned_revision" ]; then
    printf 'the checkout is at %s where the pin names %s\n' \
        "$head_revision" "$pinned_revision" >&2
    printf 'check the pinned revision out yourself; this build writes nothing into the tree\n' >&2
    exit 1
fi

# The ancestry test is what makes the revision an E5-S1 driver rather than a
# second E5-S0 one: without the merge, ACO answers with the generic expansion.
if ! "$git_program" -C "$source_root" merge-base --is-ancestor \
    "$lowering_merge" "$pinned_revision" >/dev/null 2>&1; then
    printf 'the revision %s does not descend from the lowering merge %s\n' \
        "$pinned_revision" "$lowering_merge" >&2
    printf 'a driver without it lowers nir_op_sdot_4x8_iadd generically, which is the E5-S0 arm\n' >&2
    exit 1
fi

prefix_directory=$prefix_root/qwen-radv-$(printf '%.12s' "$pinned_revision")
if [ -e "$prefix_directory" ]; then
    printf 'the prefix already exists, so the build would write over a driver a receipt may name: %s\n' \
        "$prefix_directory" >&2
    exit 1
fi
mkdir -p "$prefix_directory"
build_directory=$prefix_directory/build

printf 'radv_build=start revision=%s prefix=%s\n' \
    "$pinned_revision" "$prefix_directory"

# One invocation, stated here and recorded in the receipt, so a second build of
# the same revision is comparable to this one by its arguments rather than by
# whoever ran it.
"$meson_program" setup "$build_directory" "$source_root" \
    -Dvulkan-drivers=amd \
    -Dgallium-drivers= \
    -Dplatforms= \
    -Dglx=disabled \
    -Degl=disabled \
    -Dgbm=disabled \
    -Dllvm=enabled \
    -Dtools=drm-shim
"$ninja_program" -C "$build_directory" \
    src/amd/vulkan/libvulkan_radeon.so \
    src/amd/vulkan/radeon_devenv_icd.x86_64.json \
    src/amd/drm-shim/libamdgpu_noop_drm_shim.so

driver_library=$build_directory/src/amd/vulkan/libvulkan_radeon.so
driver_icd=$build_directory/src/amd/vulkan/radeon_devenv_icd.x86_64.json
drm_shim_library=$build_directory/src/amd/drm-shim/libamdgpu_noop_drm_shim.so
for built_artifact in "$driver_library" "$driver_icd" "$drm_shim_library"; do
    if [ ! -f "$built_artifact" ]; then
        printf 'the build produced no %s\n' "$built_artifact" >&2
        exit 1
    fi
done

# The devenv ICD is the whole isolation: its library_path names this build
# directory, so a json pointing at the system driver would serve the system
# driver under this prefix's name.
icd_library_path=$(sed -n 's/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$driver_icd" | head -n 1)
if [ "$icd_library_path" != "$driver_library" ]; then
    printf 'the ICD names %s where this build produced %s\n' \
        "$icd_library_path" "$driver_library" >&2
    exit 1
fi

environment_fragment=$prefix_directory/radv-experiment-env.sh
{
    printf '#!/bin/sh\n'
    printf '# Sourceable handoff for the isolated RADV built from Mesa %s.\n' \
        "$pinned_revision"
    printf '#\n'
    printf '# radv-low-priority-env.sh reads QWEN_RADV_ICD and exports it as both\n'
    printf '# VK_DRIVER_FILES and VK_ICD_FILENAMES, and its scrub removes GGML_VK_*\n'
    printf '# names alone, so both names below cross into the served process. The ICD\n'
    printf '# carries an absolute library_path, so the loader resolves the driver from\n'
    printf '# the json; LD_LIBRARY_PATH covers a dependency built beside it.\n'
    printf 'QWEN_RADV_ICD=%s\n' "$driver_icd"
    printf 'QWEN_AMDGPU_DRM_SHIM=%s\n' "$drm_shim_library"
    # The braces reach the fragment as text, so sourcing it appends rather than
    # replacing whatever LD_LIBRARY_PATH the caller already holds.
    # shellcheck disable=SC2016
    printf 'LD_LIBRARY_PATH=%s${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\n' \
        "$build_directory/src/amd/vulkan"
    printf 'export QWEN_RADV_ICD QWEN_AMDGPU_DRM_SHIM LD_LIBRARY_PATH\n'
} >"$environment_fragment"
chmod 0755 "$environment_fragment"

build_receipt=$prefix_directory/radv-build.tsv
{
    printf 'key\tvalue\n'
    printf 'schema\tisolated-radv-v1\n'
    printf 'revision\t%s\n' "$pinned_revision"
    printf 'lowering_merge\t%s\n' "$lowering_merge"
    printf 'meson_version\t%s\n' "$("$meson_program" --version | head -n 1)"
    printf 'ninja_version\t%s\n' "$("$ninja_program" --version | head -n 1)"
    printf 'meson_options\t%s\n' \
        '-Dvulkan-drivers=amd -Dgallium-drivers= -Dplatforms= -Dglx=disabled -Degl=disabled -Dgbm=disabled -Dllvm=enabled -Dtools=drm-shim'
    printf 'driver_sha256\t%s\n' "$(sha256sum "$driver_library" | cut -d ' ' -f 1)"
    printf 'drm_shim_sha256\t%s\n' "$(sha256sum "$drm_shim_library" | cut -d ' ' -f 1)"
    printf 'icd_sha256\t%s\n' "$(sha256sum "$driver_icd" | cut -d ' ' -f 1)"
} >"$build_receipt"

printf 'radv_build=installed revision=%s environment=%s receipt=%s\n' \
    "$pinned_revision" "$environment_fragment" "$build_receipt"
