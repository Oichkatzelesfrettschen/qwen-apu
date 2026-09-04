#!/bin/sh
set -eu

# The isolated RADV build against fake meson, ninja, and git, so the pin, the
# ancestry test, the ICD comparison, the environment fragment, and every refusal
# are checked without Mesa sources, without a compiler, and without a device.
# The fake ninja writes the three artifacts the real one produces and the fake
# git answers the two queries the build makes, which is the whole interface this
# script has with the toolchain.

if [ "$#" -gt 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
builder=$script_directory/build-isolated-radv.sh

temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

pinned_revision=9ae8ce550453b9e19f14dc1c9a41b913a9005e48
lowering_merge=f1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb

fake_bin=$temporary_directory/bin
mkdir -p "$fake_bin"

# The fake git reads its two answers out of the checkout itself, so a test arm
# moves the head or the ancestry by writing a file rather than by editing this
# script.
cat >"$fake_bin/meson" <<'FAKE'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
    printf '1.9.0\n'
    exit 0
fi
[ "${1:-}" = setup ] || exit 1
mkdir -p "$2"
shift 2
printf '%s\n' "$*" >"$FAKE_MESON_OPTIONS_RECORD"
FAKE
chmod 0755 "$fake_bin/meson"

cat >"$fake_bin/ninja" <<'FAKE'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
    printf '1.13.1\n'
    exit 0
fi
[ "${1:-}" = -C ] || exit 1
fake_build_directory=$2
shift 2
if [ -n "${FAKE_NINJA_FAIL:-}" ]; then
    printf 'fake ninja: the build failed\n' >&2
    exit 1
fi
mkdir -p "$fake_build_directory/src/amd/vulkan" "$fake_build_directory/src/amd/drm-shim"
printf 'fake radv\n' >"$fake_build_directory/src/amd/vulkan/libvulkan_radeon.so"
printf 'fake drm-shim\n' >"$fake_build_directory/src/amd/drm-shim/libamdgpu_noop_drm_shim.so"
fake_icd_library=$fake_build_directory/src/amd/vulkan/libvulkan_radeon.so
if [ -n "${FAKE_NINJA_FOREIGN_ICD:-}" ]; then
    fake_icd_library=$FAKE_NINJA_FOREIGN_ICD
fi
printf '{"ICD":{"library_path":"%s","api_version":"1.4.354"}}\n' "$fake_icd_library" \
    >"$fake_build_directory/src/amd/vulkan/radeon_devenv_icd.x86_64.json"
FAKE
chmod 0755 "$fake_bin/ninja"

cat >"$fake_bin/git" <<'FAKE'
#!/bin/sh
set -eu
[ "${1:-}" = -C ] || exit 1
fake_source_root=$2
shift 2
# A linked worktree carries .git as a file naming its gitdir, so the fake
# resolves either shape the way git does.
fake_git_directory() {
    if [ -d "$fake_source_root/.git" ]; then
        printf '%s\n' "$fake_source_root/.git"
    else
        sed -n 's/^gitdir: //p' "$fake_source_root/.git"
    fi
}
case ${1:-} in
    rev-parse)
        if [ "${2:-}" = --git-dir ]; then
            [ -e "$fake_source_root/.git" ] || exit 1
            fake_git_directory
            exit 0
        fi
        cat "$(fake_git_directory)/fake-head"
        ;;
    merge-base)
        # `merge-base --is-ancestor ANCESTOR REVISION` answers zero where the
        # checkout declares the ancestor, which is what the pin's own file says.
        grep -qxF "$3" "$(fake_git_directory)/fake-ancestors"
        ;;
    *)
        exit 1
        ;;
esac
FAKE
chmod 0755 "$fake_bin/git"

source_directory=$temporary_directory/mesa
mkdir -p "$source_directory/.git"
printf '%s\n' "$pinned_revision" >"$source_directory/.git/fake-head"
printf '%s\n' "$lowering_merge" >"$source_directory/.git/fake-ancestors"

FAKE_MESON_OPTIONS_RECORD=$temporary_directory/meson-options.txt
export FAKE_MESON_OPTIONS_RECORD

run_builder() {
    QWEN_MESON=$fake_bin/meson QWEN_NINJA=$fake_bin/ninja QWEN_GIT=$fake_bin/git \
        "$builder" "$@"
}

prefix_root=$temporary_directory/prefix-root
run_builder "$source_directory" "$prefix_root" >"$temporary_directory/build.log"
grep -q '^radv_build=installed ' "$temporary_directory/build.log"

prefix_directory=$prefix_root/qwen-radv-9ae8ce550453
build_directory=$prefix_directory/build
[ -f "$build_directory/src/amd/vulkan/libvulkan_radeon.so" ]
[ -f "$build_directory/src/amd/drm-shim/libamdgpu_noop_drm_shim.so" ]

# The build states its own invocation rather than leaving it to whoever ran it,
# and the two options a wrong build silently loses are the ones checked.
grep -q -- '-Dllvm=enabled' "$FAKE_MESON_OPTIONS_RECORD"
grep -q -- '-Dtools=drm-shim' "$FAKE_MESON_OPTIONS_RECORD"
grep -q -- '-Dvulkan-drivers=amd' "$FAKE_MESON_OPTIONS_RECORD"
printf 'meson_invocation=accepted\n'

build_receipt=$prefix_directory/radv-build.tsv
grep -qxF "$(printf 'schema\tisolated-radv-v1')" "$build_receipt"
grep -qxF "$(printf 'revision\t%s' "$pinned_revision")" "$build_receipt"
grep -qxF "$(printf 'lowering_merge\t%s' "$lowering_merge")" "$build_receipt"
grep -qxF "$(printf 'driver_sha256\t%s' \
    "$(sha256sum "$build_directory/src/amd/vulkan/libvulkan_radeon.so" | cut -d ' ' -f 1)")" \
    "$build_receipt"
printf 'build_receipt=accepted\n'

# The environment fragment is the handoff: sourcing it names this build's ICD
# and shim, which radv-low-priority-env.sh reads as QWEN_RADV_ICD and exports as
# both loader names.
environment_fragment=$prefix_directory/radv-experiment-env.sh
[ -x "$environment_fragment" ]
observed_environment=$(
    LD_LIBRARY_PATH=/pre-existing
    export LD_LIBRARY_PATH
    # shellcheck disable=SC1090
    . "$environment_fragment"
    printf '%s\n%s\n%s\n' "$QWEN_RADV_ICD" "$QWEN_AMDGPU_DRM_SHIM" "$LD_LIBRARY_PATH"
)
[ "$(printf '%s\n' "$observed_environment" | sed -n 1p)" \
    = "$build_directory/src/amd/vulkan/radeon_devenv_icd.x86_64.json" ]
[ "$(printf '%s\n' "$observed_environment" | sed -n 2p)" \
    = "$build_directory/src/amd/drm-shim/libamdgpu_noop_drm_shim.so" ]
[ "$(printf '%s\n' "$observed_environment" | sed -n 3p)" \
    = "$build_directory/src/amd/vulkan:/pre-existing" ]
printf 'environment_handoff=accepted\n'

run_refusal() {
    refusal_name=$1
    refusal_expected_status=$2
    refusal_message=$3
    shift 3
    refusal_status=0
    run_builder "$@" >/dev/null 2>"$temporary_directory/$refusal_name.log" \
        || refusal_status=$?
    if [ "$refusal_status" -ne "$refusal_expected_status" ]; then
        printf '%s exited %s where %s was expected\n' \
            "$refusal_name" "$refusal_status" "$refusal_expected_status" >&2
        cat "$temporary_directory/$refusal_name.log" >&2
        exit 1
    fi
    grep -q "$refusal_message" "$temporary_directory/$refusal_name.log"
    printf '%s=accepted\n' "$refusal_name"
}

run_refusal prefix_exists 1 'the prefix already exists' \
    "$source_directory" "$prefix_root"

# A revision that does not descend from the lowering merge is an E5-S0 driver
# under E5-S1's name, so the ancestry test refuses it.
detached_source=$temporary_directory/mesa-pre-2115
mkdir -p "$detached_source/.git"
printf '%s\n' "$pinned_revision" >"$detached_source/.git/fake-head"
: >"$detached_source/.git/fake-ancestors"
run_refusal lowering_merge_required 1 'does not descend from the lowering merge' \
    "$detached_source" "$temporary_directory/prefix-root-2"

moved_source=$temporary_directory/mesa-moved
mkdir -p "$moved_source/.git"
printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' >"$moved_source/.git/fake-head"
printf '%s\n' "$lowering_merge" >"$moved_source/.git/fake-ancestors"
run_refusal head_matches_pin 1 'the checkout is at' \
    "$moved_source" "$temporary_directory/prefix-root-3"

run_refusal source_is_a_checkout 1 'the source directory is a Mesa git checkout' \
    "$temporary_directory" "$temporary_directory/prefix-root-4"

# A linked worktree carries .git as a file, and it is the layout this repository
# builds every branch in, so the checkout test asks git rather than the layout.
worktree_source=$temporary_directory/mesa-worktree
worktree_gitdir=$temporary_directory/mesa-worktree-gitdir
mkdir -p "$worktree_source" "$worktree_gitdir"
printf 'gitdir: %s\n' "$worktree_gitdir" >"$worktree_source/.git"
printf '%s\n' "$pinned_revision" >"$worktree_gitdir/fake-head"
printf '%s\n' "$lowering_merge" >"$worktree_gitdir/fake-ancestors"
run_builder "$worktree_source" "$temporary_directory/prefix-root-worktree" \
    >"$temporary_directory/worktree.log"
grep -q '^radv_build=installed ' "$temporary_directory/worktree.log"
printf 'linked_worktree=accepted\n'

# A build that fails leaves no prefix behind, so the next attempt reaches the
# build rather than the existence refusal.
failed_prefix_root=$temporary_directory/prefix-root-failed
failed_status=0
FAKE_NINJA_FAIL=1 run_builder "$source_directory" "$failed_prefix_root" \
    >/dev/null 2>"$temporary_directory/ninja-failure.log" || failed_status=$?
[ "$failed_status" -ne 0 ]
[ ! -e "$failed_prefix_root/qwen-radv-9ae8ce550453" ]
run_builder "$source_directory" "$failed_prefix_root" \
    >"$temporary_directory/retry.log"
grep -q '^radv_build=installed ' "$temporary_directory/retry.log"
printf 'failed_build_leaves_no_prefix=accepted\n'

revision_status=0
QWEN_MESON=$fake_bin/meson QWEN_NINJA=$fake_bin/ninja QWEN_GIT=$fake_bin/git \
    QWEN_RADV_REVISION=not-a-revision "$builder" \
    "$source_directory" "$temporary_directory/prefix-root-5" \
    >/dev/null 2>"$temporary_directory/revision-shape.log" || revision_status=$?
[ "$revision_status" -eq 1 ]
grep -q 'the pinned revision is a full lowercase hexadecimal object name' \
    "$temporary_directory/revision-shape.log"
printf 'revision_shape=accepted\n'

# An ICD naming another library serves the system driver under this prefix's
# name, which is the one failure the isolation exists to prevent.
foreign_icd_status=0
FAKE_NINJA_FOREIGN_ICD=/usr/lib/libvulkan_radeon.so \
    QWEN_MESON=$fake_bin/meson QWEN_NINJA=$fake_bin/ninja QWEN_GIT=$fake_bin/git \
    "$builder" "$source_directory" "$temporary_directory/prefix-root-6" \
    >/dev/null 2>"$temporary_directory/foreign-icd.log" || foreign_icd_status=$?
[ "$foreign_icd_status" -eq 1 ]
grep -q 'the ICD names /usr/lib/libvulkan_radeon.so' "$temporary_directory/foreign-icd.log"
printf 'icd_names_this_build=accepted\n'

argument_status=0
"$builder" >/dev/null 2>&1 || argument_status=$?
[ "$argument_status" -eq 2 ]
printf 'usage=accepted\n'

printf 'build_isolated_radv=accepted\n'
