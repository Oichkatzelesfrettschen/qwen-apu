#!/bin/sh
set -eu

# The runtime-tree identity check over fixture trees: a manifest-consistent
# copy verifies, an edited file, a missing file, and a stray file each read
# divergent, a consistent copy of the wrong head reads stale against an
# intended head, and a tree without a manifest passes as unmanifested so the
# fixture harnesses that copy scripts into bare directories keep launching.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

checker=$script_directory/check-runtime-tree.sh
checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

tree=$work_directory/tree
mkdir -p "$tree/remote" "$tree/patches"
printf 'echo serving\n' >"$tree/remote/serve.sh"
printf 'patch body\n' >"$tree/patches/repair.patch"

write_manifest() {
    {
        printf 'git_head\t%s\n' "$1"
        (
            cd "$tree"
            find remote patches -type f | LC_ALL=C sort | \
                while IFS= read -r file; do
                    printf '%s\t%s\n' "$file" \
                        "$(sha256sum "$file" | cut -d ' ' -f 1)"
                done
        )
    } >"$tree/runtime-tree-manifest.tsv"
}

write_manifest 1111111111111111111111111111111111111111

if "$checker" "$tree" | grep -q 'runtime_tree=verified'; then
    report consistent_tree_verified accepted
else
    printf 'a manifest-consistent tree failed to verify\n' >&2
    exit 1
fi

if "$checker" "$tree" 1111111111111111111111111111111111111111 \
    >/dev/null 2>&1; then
    report intended_head_match accepted
else
    printf 'the matching intended head was refused\n' >&2
    exit 1
fi

if "$checker" "$tree" 2222222222222222222222222222222222222222 \
    >/dev/null 2>"$work_directory/stale.stderr"; then
    printf 'a stale head escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree=stale' "$work_directory/stale.stderr"; then
    printf 'the stale refusal lost its reason\n' >&2
    exit 1
fi
report stale_head_refused accepted

printf 'git_head\t1111111111111111111111111111111111111111\nmalformed\n' \
    >"$tree/runtime-tree-manifest.tsv"
if "$checker" "$tree" >/dev/null 2>"$work_directory/malformed.stderr"; then
    printf 'a malformed manifest escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'malformed runtime tree manifest row' \
    "$work_directory/malformed.stderr"; then
    printf 'the malformed-manifest refusal lost its reason\n' >&2
    exit 1
fi
report malformed_manifest_refused accepted
write_manifest 1111111111111111111111111111111111111111

printf 'echo edited\n' >>"$tree/remote/serve.sh"
if "$checker" "$tree" >/dev/null 2>"$work_directory/edited.stderr"; then
    printf 'an edited file escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree_divergent=remote/serve.sh' \
    "$work_directory/edited.stderr"; then
    printf 'the divergent refusal lost the file it names\n' >&2
    exit 1
fi
report edited_file_refused accepted
write_manifest 1111111111111111111111111111111111111111

rm "$tree/patches/repair.patch"
if "$checker" "$tree" >/dev/null 2>"$work_directory/missing.stderr"; then
    printf 'a missing file escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree_missing=patches/repair.patch' \
    "$work_directory/missing.stderr"; then
    printf 'the missing refusal lost the file it names\n' >&2
    exit 1
fi
report missing_file_refused accepted
printf 'patch body\n' >"$tree/patches/repair.patch"
write_manifest 1111111111111111111111111111111111111111

printf 'left by an old sync\n' >"$tree/remote/stale-helper.sh"
if "$checker" "$tree" >/dev/null 2>"$work_directory/stray.stderr"; then
    printf 'a stray file escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree_stray=remote/stale-helper.sh' \
    "$work_directory/stray.stderr"; then
    printf 'the stray refusal lost the file it names\n' >&2
    exit 1
fi
report stray_file_refused accepted
rm "$tree/remote/stale-helper.sh"

rm "$tree/runtime-tree-manifest.tsv"
if "$checker" "$tree" | grep -q 'runtime_tree=unmanifested'; then
    report unmanifested_tree_passes accepted
else
    printf 'a manifest-free tree failed to pass as unmanifested\n' >&2
    exit 1
fi

if "$checker" "$tree" 1111111111111111111111111111111111111111 \
    >/dev/null 2>"$work_directory/unmanifested-intended.stderr"; then
    printf 'an intended head admitted an unmanifested tree\n' >&2
    exit 1
fi
if ! grep -q 'runtime tree manifest is required for intended git head' \
    "$work_directory/unmanifested-intended.stderr"; then
    printf 'the intended-head manifest refusal lost its reason\n' >&2
    exit 1
fi
report intended_head_requires_manifest accepted

# The launch chain consults the check ahead of the control chain, so the
# refusal lands before anything spawns.
if ! grep -q 'check-runtime-tree.sh' "$script_directory/qwen-launch.sh"; then
    printf 'the launcher no longer consults the runtime-tree check\n' >&2
    exit 1
fi
report launcher_consults_check accepted

printf 'check_runtime_tree=accepted checks=%s\n' "$checks"
