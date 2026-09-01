#!/bin/sh
set -eu

# The runtime tree executes from a copy, so a script edited in git changes
# nothing until it is synced and a launch over a stale copy tests the previous
# revision. sync-runtime-tree.sh writes runtime-tree-manifest.tsv beside this
# tree at sync time; this check recomputes every digest the manifest names and
# compares the file population both ways, which catches a partial sync and a
# hand edit. A forgotten sync is self-consistent and invisible from here, so
# the manifest carries the git head it was generated from and this check
# prints it: the dispatching side compares that head against the one it
# intends to run, and INTENDED_GIT_HEAD as an argument makes this check do
# the comparison itself.
#
# usage: check-runtime-tree.sh [TREE_ROOT] [INTENDED_GIT_HEAD]

if [ "$#" -gt 2 ]; then
    printf 'usage: %s [TREE_ROOT] [INTENDED_GIT_HEAD]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tree_root=${1:-$(CDPATH='' cd -- "$script_directory/.." && pwd)}
intended_git_head=${2:-}
manifest=$tree_root/runtime-tree-manifest.tsv

if [ ! -r "$manifest" ]; then
    if [ -n "$intended_git_head" ]; then
        printf 'runtime tree manifest is required for intended git head %s: %s\n' \
            "$intended_git_head" "$manifest" >&2
        exit 1
    fi
    printf 'runtime_tree=unmanifested manifest=%s\n' "$manifest"
    exit 0
fi

if ! manifest_git_head=$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    $1 == "git_head" {
        if (NF != 2 || seen_head || $2 == "") exit 1
        seen_head = 1
        git_head = $2
    }
    END {
        if (!seen_head) exit 1
        print git_head
    }
' "$manifest"); then
    printf 'runtime tree manifest carries an invalid git_head row: %s\n' \
        "$manifest" >&2
    exit 1
fi

failure_count=0
manifest_paths=$(mktemp)
present_paths=$(mktemp)
trap 'rm -f "$manifest_paths" "$present_paths"' EXIT HUP INT TERM

if ! awk -F'\t' '
    /^#/ || NF == 0 { next }
    $1 == "git_head" { next }
    NF != 2 { printf "malformed runtime tree manifest row: %s\n", $0 > "/dev/stderr"; exit 1 }
    { print $1 }
' "$manifest" >"$manifest_paths"; then
    exit 1
fi
LC_ALL=C sort -o "$manifest_paths" "$manifest_paths"

while IFS= read -r relative_path; do
    expected_sha256=$(awk -F'\t' -v p="$relative_path" \
        '$1 == p { print $2; exit }' "$manifest")
    if [ ! -r "$tree_root/$relative_path" ]; then
        printf 'runtime_tree_missing=%s\n' "$relative_path" >&2
        failure_count=$((failure_count + 1))
        continue
    fi
    actual_sha256=$(sha256sum "$tree_root/$relative_path" | cut -d ' ' -f 1)
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        printf 'runtime_tree_divergent=%s expected=%s found=%s\n' \
            "$relative_path" "$expected_sha256" "$actual_sha256" >&2
        failure_count=$((failure_count + 1))
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
done | sort >"$present_paths"
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

if [ -n "$intended_git_head" ] && \
    [ "$manifest_git_head" != "$intended_git_head" ]; then
    printf 'runtime_tree=stale manifest_git_head=%s intended_git_head=%s\n' \
        "$manifest_git_head" "$intended_git_head" >&2
    exit 1
fi

printf 'runtime_tree=verified git_head=%s files=%s\n' \
    "$manifest_git_head" "$(grep -c . "$manifest_paths")"
