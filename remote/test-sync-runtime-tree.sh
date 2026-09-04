#!/bin/sh
set -eu

# The sync writes the manifest that the destination's check verifies, so the
# two enumerations have to agree on what the payload is. A python child
# launched from the workstation tree leaves bytecode beside the scripts it
# imported, and a manifest built by walking the directory adopts that bytecode
# as payload: the appliance then reads a row naming a file the exclusion never
# sent, and reads a stray once the file is removed. The payload is what git
# tracks, and bytecode leaves through the same exclusion on both sides.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

syncer=$script_directory/sync-runtime-tree.sh
checker=$script_directory/check-runtime-tree.sh
checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

source_repository=$work_directory/source
destination=$work_directory/destination
mkdir -p "$source_repository/remote/web-mcp" "$source_repository/patches" \
    "$destination"
cp "$syncer" "$source_repository/remote/sync-runtime-tree.sh"
cp "$checker" "$source_repository/remote/check-runtime-tree.sh"
printf 'echo serving\n' >"$source_repository/remote/serve.sh"
chmod 755 "$source_repository/remote/serve.sh"
printf 'protocol module\n' >"$source_repository/remote/image_protocol.py"
printf 'echo teardown\n' >"$source_repository/remote/image-teardown-check.sh"
chmod 755 "$source_repository/remote/image-teardown-check.sh"
printf 'server module\n' >"$source_repository/remote/web-mcp/server.py"
printf 'patch body\n' >"$source_repository/patches/repair.patch"

git -C "$source_repository" init -q
git -C "$source_repository" add -A
git -C "$source_repository" \
    -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q -m 'fixture payload'

# The bytecode a python child wrote while the workstation ran its own tests.
mkdir -p "$source_repository/remote/web-mcp/__pycache__"
printf 'compiled\n' \
    >"$source_repository/remote/web-mcp/__pycache__/server.cpython-314.pyc"

if ! "$source_repository/remote/sync-runtime-tree.sh" "$destination" \
    >"$work_directory/sync.log" 2>&1; then
    printf 'the sync refused a tracked payload beside bytecode\n' >&2
    cat "$work_directory/sync.log" >&2
    exit 1
fi
report sync_completed accepted

if grep -q '\.pyc' "$destination/runtime-tree-manifest.tsv"; then
    printf 'the manifest adopted bytecode as payload\n' >&2
    grep '\.pyc' "$destination/runtime-tree-manifest.tsv" >&2
    exit 1
fi
report manifest_holds_no_bytecode accepted

if find "$destination" -name '*.pyc' -o -name '__pycache__' | grep -q .; then
    printf 'the sync shipped bytecode to the destination\n' >&2
    exit 1
fi
report destination_holds_no_bytecode accepted

if ! LC_ALL=en_US.UTF-8 "$checker" "$destination" \
    >"$work_directory/check.log" 2>&1; then
    printf 'the synced tree failed its own check\n' >&2
    cat "$work_directory/check.log" >&2
    exit 1
fi
report synced_tree_verifies accepted

# An untracked script ships through rsync and carries no manifest row, so the
# destination would read it as a stray. The refusal lands here, where the file
# has a name and an author, rather than on the appliance at the next launch.
printf 'echo new\n' >"$source_repository/remote/untracked-helper.sh"
if "$source_repository/remote/sync-runtime-tree.sh" "$destination" \
    >"$work_directory/untracked.log" 2>&1; then
    printf 'an untracked payload file synced without a manifest row\n' >&2
    exit 1
fi
if ! grep -q 'remote/untracked-helper.sh' "$work_directory/untracked.log"; then
    printf 'the untracked refusal lost the file it names\n' >&2
    cat "$work_directory/untracked.log" >&2
    exit 1
fi
report untracked_payload_refused accepted
rm "$source_repository/remote/untracked-helper.sh"

# An ignored non-bytecode artifact -- *.tmp, *.part, api.key, *.key --
# ships through rsync and carries no manifest row the same way an untracked
# one does, but --exclude-standard hides it from the untracked check the same
# way it hides one from `git status`: the refusal names the file whether or
# not .gitignore also names it.
printf '*.tmp\n*.part\napi.key\n*.key\n' >"$source_repository/.gitignore"
git -C "$source_repository" add .gitignore
git -C "$source_repository" \
    -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q -m 'ignore rules'
printf 'stray\n' >"$source_repository/remote/leftover.tmp"
if "$source_repository/remote/sync-runtime-tree.sh" "$destination" \
    >"$work_directory/ignored.log" 2>&1; then
    printf 'an ignored payload file synced without a manifest row\n' >&2
    exit 1
fi
if ! grep -q 'remote/leftover.tmp' "$work_directory/ignored.log"; then
    printf 'the ignored-file refusal lost the file it names\n' >&2
    cat "$work_directory/ignored.log" >&2
    exit 1
fi
report ignored_payload_refused accepted
rm "$source_repository/remote/leftover.tmp"

# A tracked file removed from the working tree would leave a manifest row
# naming a file the destination never receives, which reads as a partial sync
# there rather than as a deletion here.
rm "$source_repository/remote/serve.sh"
if "$source_repository/remote/sync-runtime-tree.sh" "$destination" \
    >"$work_directory/deleted.log" 2>&1; then
    printf 'a tracked file absent from the working tree synced anyway\n' >&2
    exit 1
fi
if ! grep -q 'remote/serve.sh' "$work_directory/deleted.log"; then
    printf 'the deleted-file refusal lost the file it names\n' >&2
    cat "$work_directory/deleted.log" >&2
    exit 1
fi
report deleted_tracked_file_refused accepted

printf 'sync_runtime_tree=accepted checks=%s\n' "$checks"
