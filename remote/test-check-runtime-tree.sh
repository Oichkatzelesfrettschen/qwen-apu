#!/bin/sh
set -eu

# The runtime-tree identity check over fixture trees: a manifest-consistent
# copy verifies, an edited file, a missing file, a stray file, a stripped
# execute bit, and a symlink substitution each read divergent, a consistent
# copy of the wrong head reads stale against an intended head unless the
# intended payload digest matches, and a tree without a manifest passes as
# unmanifested so the fixture harnesses that copy scripts into bare
# directories keep launching -- while a git source clone without a manifest
# refuses, which is the incident shape a direct control start reproduces.

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
chmod 755 "$tree/remote/serve.sh"
printf 'patch body\n' >"$tree/patches/repair.patch"
chmod 644 "$tree/patches/repair.patch"
# Underscore and hyphen collate differently between C and locale order, the
# pair that made comm refuse a correctly synced 277-file tree, so the fixture
# carries both and the first verification runs under a UTF-8 locale.
printf 'protocol module\n' >"$tree/remote/image_protocol.py"
chmod 644 "$tree/remote/image_protocol.py"
printf 'echo fetch\n' >"$tree/remote/image-fetch.sh"
chmod 755 "$tree/remote/image-fetch.sh"

write_manifest() {
    payload_rows=$work_directory/payload-rows
    (
        cd "$tree"
        find remote patches -type f | LC_ALL=C sort | \
            while IFS= read -r file; do
                mode_class=-
                [ -x "$file" ] && mode_class=x
                printf '%s\t%s\t%s\n' "$file" \
                    "$(sha256sum "$file" | cut -d ' ' -f 1)" "$mode_class"
            done
    ) >"$payload_rows"
    remote_digest=$(grep '^remote/' "$payload_rows" | sha256sum | cut -d ' ' -f 1)
    patches_digest=$(grep '^patches/' "$payload_rows" | sha256sum | cut -d ' ' -f 1)
    {
        printf 'git_head\t%s\n' "$1"
        printf 'remote_payload_tree_sha256\t%s\n' "$remote_digest"
        printf 'patches_payload_tree_sha256\t%s\n' "$patches_digest"
        cat "$payload_rows"
    } >"$tree/runtime-tree-manifest.tsv"
    combined_payload_sha256=$(printf 'remote_payload_tree_sha256=%s\npatches_payload_tree_sha256=%s\n' \
        "$remote_digest" "$patches_digest" | sha256sum | cut -d ' ' -f 1)
}

write_manifest 1111111111111111111111111111111111111111

if LC_ALL=en_US.UTF-8 "$checker" "$tree" | grep -q 'runtime_tree=verified'; then
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

# A head that advanced outside remote/ and patches/ leaves the payload digest
# unchanged, so the intended payload digest passes the byte-identical tree.
if "$checker" "$tree" 2222222222222222222222222222222222222222 \
    "$combined_payload_sha256" | grep -q 'head_divergence=payload-neutral'; then
    report payload_neutral_head_passes accepted
else
    printf 'a byte-identical payload was refused under a newer head\n' >&2
    exit 1
fi

# A wrong payload digest beside a wrong head keeps the stale refusal.
if "$checker" "$tree" 2222222222222222222222222222222222222222 \
    0000000000000000000000000000000000000000000000000000000000000000 \
    >/dev/null 2>&1; then
    printf 'a foreign payload digest admitted a stale head\n' >&2
    exit 1
fi
report foreign_payload_digest_refused accepted

printf 'git_head\t1111111111111111111111111111111111111111\nmalformed\n' \
    >"$tree/runtime-tree-manifest.tsv"
if "$checker" "$tree" >/dev/null 2>"$work_directory/malformed.stderr"; then
    printf 'a malformed manifest escaped refusal\n' >&2
    exit 1
fi
if ! grep -Eq 'malformed runtime tree manifest row|invalid payload digest rows' \
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
printf 'echo serving\n' >"$tree/remote/serve.sh"
write_manifest 1111111111111111111111111111111111111111

# A stripped execute bit leaves the bytes identical and the launch broken, so
# the mode class refuses on its own.
chmod 644 "$tree/remote/serve.sh"
if "$checker" "$tree" >/dev/null 2>"$work_directory/mode.stderr"; then
    printf 'a stripped execute bit escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree_mode=remote/serve.sh' "$work_directory/mode.stderr"; then
    printf 'the mode refusal lost the file it names\n' >&2
    exit 1
fi
report stripped_mode_refused accepted
chmod 755 "$tree/remote/serve.sh"

# A symlink to a byte-identical file outside the managed root resolves foreign
# bytes at execution time, so the link itself refuses regardless of content.
printf 'echo serving\n' >"$work_directory/outside-copy.sh"
chmod 755 "$work_directory/outside-copy.sh"
rm "$tree/remote/serve.sh"
ln -s "$work_directory/outside-copy.sh" "$tree/remote/serve.sh"
if "$checker" "$tree" >/dev/null 2>"$work_directory/symlink.stderr"; then
    printf 'a symlink substitution escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree_symlink=remote/serve.sh' \
    "$work_directory/symlink.stderr"; then
    printf 'the symlink refusal lost the link it names\n' >&2
    exit 1
fi
report symlink_substitution_refused accepted
rm "$tree/remote/serve.sh"
printf 'echo serving\n' >"$tree/remote/serve.sh"
chmod 755 "$tree/remote/serve.sh"

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

# A manifest whose payload digest rows contradict its own verified file rows
# was assembled by something other than the sync.
awk -F'\t' 'BEGIN { OFS = "\t" }
    $1 == "remote_payload_tree_sha256" {
        print $1, "0000000000000000000000000000000000000000000000000000000000000000"
        next
    }
    { print }
' "$tree/runtime-tree-manifest.tsv" >"$work_directory/contradicted.tsv"
mv "$work_directory/contradicted.tsv" "$tree/runtime-tree-manifest.tsv"
if "$checker" "$tree" >/dev/null 2>"$work_directory/inconsistent.stderr"; then
    printf 'a contradicted payload digest escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree=inconsistent' "$work_directory/inconsistent.stderr"; then
    printf 'the inconsistency refusal lost its reason\n' >&2
    exit 1
fi
report contradicted_payload_digest_refused accepted
write_manifest 1111111111111111111111111111111111111111

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
if ! grep -q 'runtime tree manifest is required for an intended identity' \
    "$work_directory/unmanifested-intended.stderr"; then
    printf 'the intended-head manifest refusal lost its reason\n' >&2
    exit 1
fi
report intended_head_requires_manifest accepted

# The incident shape: a git source clone carries remote/ and no manifest, and
# a start from it refuses rather than serving whatever the working tree holds.
mkdir "$tree/.git"
if "$checker" "$tree" >/dev/null 2>"$work_directory/clone.stderr"; then
    printf 'a source clone without a manifest escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'runtime_tree=unsynced-source-clone' "$work_directory/clone.stderr"; then
    printf 'the source-clone refusal lost its reason\n' >&2
    exit 1
fi
report unsynced_source_clone_refused accepted
rmdir "$tree/.git"

# Both start boundaries consult the check: qwen-launch.sh for the clearer
# early operator error, and qwen-webui-control.sh ahead of tmux creation so a
# direct control start refuses before the session, the server, the PID file,
# and the workload lease exist.
if ! grep -q 'check-runtime-tree.sh' "$script_directory/qwen-launch.sh"; then
    printf 'the launcher no longer consults the runtime-tree check\n' >&2
    exit 1
fi
report launcher_consults_check accepted
if ! awk '/check-runtime-tree.sh/ { seen = 1 } /new-session/ && !seen { exit 1 }' \
    "$script_directory/qwen-webui-control.sh" || \
    ! grep -q 'check-runtime-tree.sh' "$script_directory/qwen-webui-control.sh"; then
    printf 'the control script no longer checks the runtime tree before tmux\n' >&2
    exit 1
fi
report control_checks_before_tmux accepted

printf 'check_runtime_tree=accepted checks=%s\n' "$checks"
