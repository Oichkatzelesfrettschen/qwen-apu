#!/bin/sh
set -eu

# One sync carries remote/, patches/, and the manifest that identifies them,
# so the runtime tree can answer which git head it is a copy of and a launch
# over a stale or partial copy refuses instead of testing the previous
# revision. The manifest digests the workstation working tree at sync time --
# the bytes that actually travel -- and records the git head with a dirty
# marker where the working tree differs from it, since a manifest claiming a
# clean head over edited files would identify a tree nobody has.
#
# usage: sync-runtime-tree.sh [DESTINATION]
# DESTINATION defaults to eirikr@qwen-laptop:~/qwen-laptop-setup

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [DESTINATION]\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
destination=${1:-eirikr@qwen-laptop:~/qwen-laptop-setup}

git_head=$(git -C "$repository_directory" rev-parse HEAD)
worktree_state=clean
if [ -n "$(git -C "$repository_directory" status --porcelain -- remote patches)" ]; then
    worktree_state=dirty
fi

manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT HUP INT TERM
{
    printf '# path<TAB>sha256 over the synced runtime tree; git_head names the\n'
    printf '# commit the workstation working tree stood on when it was digested.\n'
    printf 'git_head\t%s' "$git_head"
    if [ "$worktree_state" = dirty ]; then
        printf -- '-dirty'
    fi
    printf '\n'
    (
        cd "$repository_directory"
        find remote patches -type f | LC_ALL=C sort | while IFS= read -r file; do
            printf '%s\t%s\n' "$file" "$(sha256sum "$file" | cut -d ' ' -f 1)"
        done
    )
} >"$manifest"

rsync -a "$repository_directory/remote/" "$destination/remote/"
rsync -a --delete "$repository_directory/patches/" "$destination/patches/"
rsync -a "$manifest" "$destination/runtime-tree-manifest.tsv"

# The check runs on the destination over the bytes rsync actually left, so a
# partial transfer or a concurrent edit is caught here rather than at the
# next launch.
destination_host=${destination%%:*}
destination_path=${destination#*:}
ssh "$destination_host" \
    "sh '$destination_path/remote/check-runtime-tree.sh' '$destination_path'"
