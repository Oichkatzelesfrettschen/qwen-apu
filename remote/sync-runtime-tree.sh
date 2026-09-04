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
# Source-repository identity and runtime-payload identity are two claims. The
# git_head row is provenance; remote_payload_tree_sha256 and
# patches_payload_tree_sha256 digest the canonical row serialization of each
# payload directory, so a commit outside remote/ and patches/ advances the
# head while both payload digests hold, and the checker can pass a
# byte-identical payload under a newer documentation-only head.
#
# Each payload row carries path, sha256, and mode class (x for executable, -
# for plain), and a symlink inside either payload directory refuses the sync:
# a symlink resolves content from outside the managed root, so a byte-identical
# target would otherwise satisfy the digest while executing foreign bytes.
#
# usage: sync-runtime-tree.sh DESTINATION
# DESTINATION is USER@HOST:PATH, the tree the appliance runs from; under the
# runtime-root doctrine that is the appliance's own checkout, whose .runtime
# sits beside the payload this sync writes.

if [ "$#" -ne 1 ]; then
    printf 'usage: %s DESTINATION\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
destination=$1

symlink_population=$(cd "$repository_directory" && find remote patches -type l)
if [ -n "$symlink_population" ]; then
    printf 'the runtime payload holds symlinks, which resolve outside the managed root:\n%s\n' \
        "$symlink_population" >&2
    exit 1
fi

git_head=$(git -C "$repository_directory" rev-parse HEAD)
worktree_state=clean
if [ -n "$(git -C "$repository_directory" status --porcelain -- remote patches)" ]; then
    worktree_state=dirty
fi

# The payload is what git tracks. A directory walk adopts whatever a python
# child left beside the scripts it imported: bytecode under __pycache__ entered
# the manifest, rsync's exclusion left it on the workstation, and the appliance
# read a row naming a file it never received. Both sides now exclude bytecode
# and the manifest enumerates tracked paths, so the two populations agree.
payload_exclusions='--exclude=__pycache__/ --exclude=*.pyc --exclude=*.pyo'
payload_rows() {
    (
        cd "$repository_directory"
        git ls-files -z -- "$1" | tr '\0' '\n' | LC_ALL=C sort | \
            while IFS= read -r file; do
                case $file in
                    */__pycache__/* | *.pyc | *.pyo) continue ;;
                esac
                mode_class=-
                [ -x "$file" ] && mode_class=x
                printf '%s\t%s\t%s\n' "$file" \
                    "$(sha256sum "$file" | cut -d ' ' -f 1)" "$mode_class"
            done
    )
}

# A tracked file absent from the working tree would leave a manifest row naming
# a file the destination never receives, which reads there as a partial sync.
# An untracked file is the other direction: rsync ships it and no row names it,
# so the destination reads a stray. Both refuse here, where the path has an
# author.
absent_tracked_files=$(
    cd "$repository_directory"
    git ls-files -z -- remote patches | tr '\0' '\n' | while IFS= read -r file; do
        [ -f "$file" ] || printf '%s\n' "$file"
    done
)
if [ -n "$absent_tracked_files" ]; then
    printf 'tracked payload files are absent from the working tree:\n%s\n' \
        "$absent_tracked_files" >&2
    exit 1
fi
untracked_payload_files=$(
    cd "$repository_directory"
    git ls-files --others --exclude-standard -z -- remote patches |
        tr '\0' '\n' | while IFS= read -r file; do
            case $file in
                */__pycache__/* | *.pyc | *.pyo) continue ;;
            esac
            printf '%s\n' "$file"
        done
)
if [ -n "$untracked_payload_files" ]; then
    printf 'untracked payload files ship through rsync and carry no manifest row:\n%s\n' \
        "$untracked_payload_files" >&2
    printf 'commit them or remove them before syncing\n' >&2
    exit 1
fi
# --exclude-standard above hides an ignored file from the untracked check the
# same way it hides one from `git status`, so a non-bytecode artifact
# .gitignore names -- *.part, *.tmp, api.key, *.key -- is invisible there while
# rsync still copies it: payload_exclusions below names bytecode alone.
# Ignored bytecode is the one population both this check and the rsync
# exclusion agree to leave behind, so it is exempted here the same way.
ignored_payload_files=$(
    cd "$repository_directory"
    git ls-files --others --ignored --exclude-standard -z -- remote patches |
        tr '\0' '\n' | while IFS= read -r file; do
            case $file in
                */__pycache__/* | *.pyc | *.pyo) continue ;;
            esac
            printf '%s\n' "$file"
        done
)
if [ -n "$ignored_payload_files" ]; then
    printf 'ignored payload files ship through rsync and carry no manifest row:\n%s\n' \
        "$ignored_payload_files" >&2
    printf 'commit them, remove them, or exclude them from the sync before syncing\n' >&2
    exit 1
fi

remote_rows=$(mktemp)
patches_rows=$(mktemp)
manifest=$(mktemp)
trap 'rm -f "$remote_rows" "$patches_rows" "$manifest"' EXIT HUP INT TERM
payload_rows remote >"$remote_rows"
payload_rows patches >"$patches_rows"
remote_payload_tree_sha256=$(sha256sum "$remote_rows" | cut -d ' ' -f 1)
patches_payload_tree_sha256=$(sha256sum "$patches_rows" | cut -d ' ' -f 1)

{
    printf '# path<TAB>sha256<TAB>mode over the synced runtime tree; git_head names\n'
    printf '# the commit the workstation working tree stood on when it was digested,\n'
    printf '# and the payload digests identify the rows independently of that head.\n'
    printf 'git_head\t%s' "$git_head"
    if [ "$worktree_state" = dirty ]; then
        printf -- '-dirty'
    fi
    printf '\n'
    printf 'remote_payload_tree_sha256\t%s\n' "$remote_payload_tree_sha256"
    printf 'patches_payload_tree_sha256\t%s\n' "$patches_payload_tree_sha256"
    cat "$remote_rows" "$patches_rows"
} >"$manifest"
runtime_manifest_sha256=$(sha256sum "$manifest" | cut -d ' ' -f 1)

# --delete-excluded removes bytecode the destination already holds, so an
# appliance carrying it from an earlier sync or from a child of its own comes
# back to the tracked population rather than reading strays at the next launch.
# shellcheck disable=SC2086 # the exclusion list is three separate arguments
rsync -a --delete --delete-excluded $payload_exclusions \
    "$repository_directory/remote/" "$destination/remote/"
# shellcheck disable=SC2086 # the exclusion list is three separate arguments
rsync -a --delete --delete-excluded $payload_exclusions \
    "$repository_directory/patches/" "$destination/patches/"
rsync -a "$manifest" "$destination/runtime-tree-manifest.tsv"

printf 'source_commit=%s worktree=%s\n' "$git_head" "$worktree_state"
printf 'remote_payload_tree_sha256=%s\n' "$remote_payload_tree_sha256"
printf 'patches_payload_tree_sha256=%s\n' "$patches_payload_tree_sha256"
printf 'runtime_manifest_sha256=%s\n' "$runtime_manifest_sha256"

# The check runs on the destination over the bytes rsync actually left, so a
# partial transfer or a concurrent edit is caught here rather than at the
# next launch. A destination naming no host is a path on this machine, which
# the check reads directly.
case $destination in
    *:*) ;;
    *)
        sh "$destination/remote/check-runtime-tree.sh" "$destination"
        exit 0
        ;;
esac
destination_host=${destination%%:*}
destination_path=${destination#*:}
# A leading ~/ stays literal inside the quoted remote command, so it becomes a
# path relative to the remote home, which is where an unexpanded tilde points.
# shellcheck disable=SC2088 # the literal two characters are matched, with no expansion intended
case $destination_path in
    '~/'*) destination_path=${destination_path#??} ;;  # appliance-path: named
esac
ssh "$destination_host" \
    "sh '$destination_path/remote/check-runtime-tree.sh' '$destination_path'"
