#!/bin/sh
set -eu

# The runtime tree executes from a copy, so a script edited in git changes
# nothing until it is synced and a launch over a stale copy tests the previous
# revision. sync-runtime-tree.sh writes runtime-tree-manifest.tsv beside this
# tree at sync time; this check recomputes every digest and mode class the
# manifest names, compares the file population both ways, and refuses any
# symlink inside the managed roots, which catches a partial sync, a hand
# edit, a stripped execute bit, and a byte-identical file substituted from
# outside the root through a link. A forgotten sync is self-consistent and
# invisible from here, so the manifest carries the git head it was generated
# from and this check prints it: the dispatching side compares that head
# against the one it intends to run, and INTENDED_GIT_HEAD as an argument
# makes this check do the comparison itself.
#
# Source identity and payload identity are two claims. A head mismatch alone
# reads stale, and INTENDED_PAYLOAD_SHA256 -- the sha256 over the two payload
# digest lines, as the success output prints them -- passes a byte-identical
# payload under a head that advanced outside remote/ and patches/.
#
# usage: check-runtime-tree.sh [TREE_ROOT] [INTENDED_GIT_HEAD] [INTENDED_PAYLOAD_SHA256]

if [ "$#" -gt 3 ]; then
    printf 'usage: %s [TREE_ROOT] [INTENDED_GIT_HEAD] [INTENDED_PAYLOAD_SHA256]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tree_root=${1:-$(CDPATH='' cd -- "$script_directory/.." && pwd)}
intended_git_head=${2:-}
intended_payload_sha256=${3:-}
manifest=$tree_root/runtime-tree-manifest.tsv

if [ ! -r "$manifest" ]; then
    if [ -n "$intended_git_head" ] || [ -n "$intended_payload_sha256" ]; then
        printf 'runtime tree manifest is required for an intended identity: %s\n' \
            "$manifest" >&2
        exit 1
    fi
    # A source clone carries .git and no manifest: it is the tree edits land
    # in, not the copy a sync identified, so launching from it would test
    # whatever the working tree happens to hold under no recorded identity.
    # Fixture harnesses copy scripts into bare directories, which carry
    # neither .git nor a manifest and keep passing as unmanifested.
    if [ -e "$tree_root/.git" ]; then
        printf 'runtime_tree=unsynced-source-clone root=%s\n' "$tree_root" >&2
        printf 'a git source clone is not a synced runtime tree; run sync-runtime-tree.sh\n' >&2
        exit 1
    fi
    printf 'runtime_tree=unmanifested manifest=%s\n' "$manifest"
    exit 0
fi

read_unique_header() {
    awk -F'\t' -v key="$1" '
        /^#/ || NF == 0 { next }
        $1 == key {
            if (NF != 2 || seen || $2 == "") exit 1
            seen = 1
            value = $2
        }
        END {
            if (!seen) exit 1
            print value
        }
    ' "$manifest"
}

if ! manifest_git_head=$(read_unique_header git_head); then
    printf 'runtime tree manifest carries an invalid git_head row: %s\n' \
        "$manifest" >&2
    exit 1
fi
if ! manifest_remote_payload=$(read_unique_header remote_payload_tree_sha256) || \
    ! manifest_patches_payload=$(read_unique_header patches_payload_tree_sha256); then
    printf 'runtime tree manifest carries invalid payload digest rows: %s\n' \
        "$manifest" >&2
    exit 1
fi

failure_count=0
manifest_paths=$(mktemp)
present_paths=$(mktemp)
recomputed_rows=$(mktemp)
trap 'rm -f "$manifest_paths" "$present_paths" "$recomputed_rows"' EXIT HUP INT TERM

if ! awk -F'\t' '
    /^#/ || NF == 0 { next }
    $1 == "git_head" { next }
    $1 == "remote_payload_tree_sha256" { next }
    $1 == "patches_payload_tree_sha256" { next }
    NF != 3 || ($3 != "x" && $3 != "-") {
        printf "malformed runtime tree manifest row: %s\n", $0 > "/dev/stderr"
        exit 1
    }
    { print $1 }
' "$manifest" >"$manifest_paths"; then
    exit 1
fi
LC_ALL=C sort -o "$manifest_paths" "$manifest_paths"

# A symlink anywhere in the managed roots resolves content from outside them,
# so it refuses whether or not its target hashes to the manifest's digest.
for population_directory in remote patches; do
    [ -d "$tree_root/$population_directory" ] || continue
    find "$tree_root/$population_directory" -type l | sed "s|^$tree_root/||"
done | while IFS= read -r symlink_path; do
    printf 'runtime_tree_symlink=%s\n' "$symlink_path" >&2
done
symlink_count=$(
    for population_directory in remote patches; do
        [ -d "$tree_root/$population_directory" ] || continue
        find "$tree_root/$population_directory" -type l
    done | grep -c . || :
)
failure_count=$((failure_count + symlink_count))

while IFS= read -r relative_path; do
    expected_sha256=$(awk -F'\t' -v p="$relative_path" \
        '$1 == p { print $2; exit }' "$manifest")
    expected_mode=$(awk -F'\t' -v p="$relative_path" \
        '$1 == p { print $3; exit }' "$manifest")
    if [ -h "$tree_root/$relative_path" ] || [ ! -f "$tree_root/$relative_path" ]; then
        printf 'runtime_tree_missing=%s\n' "$relative_path" >&2
        failure_count=$((failure_count + 1))
        continue
    fi
    actual_sha256=$(sha256sum "$tree_root/$relative_path" | cut -d ' ' -f 1)
    actual_mode=-
    [ -x "$tree_root/$relative_path" ] && actual_mode=x
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'runtime_tree_divergent=%s expected=%s found=%s\n' \
            "$relative_path" "$expected_sha256" "$actual_sha256" >&2
        failure_count=$((failure_count + 1))
    elif [ "$actual_mode" != "$expected_mode" ]; then
        printf 'runtime_tree_mode=%s expected=%s found=%s\n' \
            "$relative_path" "$expected_mode" "$actual_mode" >&2
        failure_count=$((failure_count + 1))
    else
        printf '%s\t%s\t%s\n' "$relative_path" "$actual_sha256" "$actual_mode" \
            >>"$recomputed_rows"
    fi
done <"$manifest_paths"

# A file present in the tree and absent from the manifest is the other half of
# a partial sync: an old script the --delete a full sync applies would have
# removed, still resolvable by everything that sources its directory.
for population_directory in remote patches; do
    if [ -d "$tree_root/$population_directory" ]; then
        find "$tree_root/$population_directory" -type f | \
            sed "s|^$tree_root/||"
    fi
done | LC_ALL=C sort >"$present_paths"
unmanifested=$(comm -13 "$manifest_paths" "$present_paths")
if [ -n "$unmanifested" ]; then
    printf '%s\n' "$unmanifested" | while IFS= read -r stray_path; do
        printf 'runtime_tree_stray=%s\n' "$stray_path" >&2
    done
    failure_count=$((failure_count + $(printf '%s\n' "$unmanifested" | grep -c .)))
fi

if [ "$failure_count" -gt 0 ]; then
    printf 'runtime_tree=divergent failures=%s git_head=%s\n' \
        "$failure_count" "$manifest_git_head" >&2
    exit 1
fi

# Every per-file row verified, so the payload digests recompute from the rows
# in manifest order per directory; a manifest whose digest rows contradict its
# own file rows was assembled by something other than the sync and refuses.
actual_remote_payload=$(grep '^remote/' "$recomputed_rows" | LC_ALL=C sort | \
    sha256sum | cut -d ' ' -f 1)
actual_patches_payload=$(grep '^patches/' "$recomputed_rows" | LC_ALL=C sort | \
    sha256sum | cut -d ' ' -f 1)
if [ "$actual_remote_payload" != "$manifest_remote_payload" ] || \
    [ "$actual_patches_payload" != "$manifest_patches_payload" ]; then
    printf 'runtime_tree=inconsistent remote_payload=%s/%s patches_payload=%s/%s\n' \
        "$manifest_remote_payload" "$actual_remote_payload" \
        "$manifest_patches_payload" "$actual_patches_payload" >&2
    exit 1
fi
combined_payload_sha256=$(printf 'remote_payload_tree_sha256=%s\npatches_payload_tree_sha256=%s\n' \
    "$actual_remote_payload" "$actual_patches_payload" | sha256sum | cut -d ' ' -f 1)

if [ -n "$intended_git_head" ] && \
    [ "$manifest_git_head" != "$intended_git_head" ]; then
    if [ -n "$intended_payload_sha256" ] && \
        [ "$combined_payload_sha256" = "$intended_payload_sha256" ]; then
        printf 'runtime_tree=verified git_head=%s intended_git_head=%s payload=%s files=%s head_divergence=payload-neutral\n' \
            "$manifest_git_head" "$intended_git_head" \
            "$combined_payload_sha256" "$(grep -c . "$manifest_paths")"
        exit 0
    fi
    printf 'runtime_tree=stale manifest_git_head=%s intended_git_head=%s\n' \
        "$manifest_git_head" "$intended_git_head" >&2
    exit 1
fi

printf 'runtime_tree=verified git_head=%s payload=%s files=%s\n' \
    "$manifest_git_head" "$combined_payload_sha256" \
    "$(grep -c . "$manifest_paths")"
