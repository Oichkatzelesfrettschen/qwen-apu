#!/bin/sh
set -eu

# Reproduce the seven successor lanes of PR #105 from a base ref.
#
# The split is a path partition. docs/split-plan/lanes.tsv assigns every path
# the source branch touches to one lane, to `shared` where several lanes each
# own part of one file, or to `dropped` where the work belongs to neither. Each
# lane branch replays the source commits in their original order, restricted to
# the paths that lane owns: a commit whose whole file set lands in one lane is
# cherry-picked so its authorship and message travel unchanged, and a commit
# that spans lanes is re-committed per lane from `git checkout <commit> --
# <paths>` under the original subject and body with a `Split-from:` trailer
# naming the commit it came from. A lane's share of a shared file arrives from
# docs/split-plan/shared/<lane>/, whose patches apply against the base version,
# and evidence/SHA256SUMS is regenerated per lane so each manifest describes the
# tree that lane actually carries.
#
# Three lanes stack rather than branching from the base, because
# run-raven2-vulkan-kernel-census.sh introduces census-arm-lib.sh,
# telemetry-broker.c, the two clock-sidecar readers, and
# summarize-census-controls.py, and dpm-telemetry, correctness-witnesses, and
# served-ab-harness each change or source those files rather than introducing
# them. Rebasing the stack onto main after PR #106 merges therefore rebases
# census-timing first and the three onto its new tip.
#
# The script rewrites the seven lane/* branches and leaves the checkout on the
# last one. It writes nothing to any remote.

usage() {
    printf 'usage: %s [BASE_REF] [SOURCE_REF]\n' "$0" >&2
    exit 2
}

[ "$#" -le 2 ] || usage
base_ref=${1:-origin/main}
source_ref=${2:-origin/stage-a-census-brackets}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/../.." && pwd)
lane_map=$script_directory/lanes.tsv
shared_root=$script_directory/shared

[ -r "$lane_map" ] || { printf 'lane map is unreadable: %s\n' "$lane_map" >&2; exit 1; }

cd "$repository_root"

if [ -n "$(git status --porcelain)" ]; then
    printf 'the working tree carries changes; the split rewrites it\n' >&2
    exit 1
fi

base_commit=$(git rev-parse --verify "$base_ref^{commit}")
source_commit=$(git rev-parse --verify "$source_ref^{commit}")
commits=$(git rev-list --reverse "$base_commit..$source_commit")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

# The lane branches are checked out into this same working tree, and the branch
# carrying docs/split-plan/ is not among them, so the map and the shared slices
# are copied out of the tree before the first checkout removes them.
cp "$lane_map" "$work/lanes.tsv"
lane_map=$work/lanes.tsv
if [ -d "$shared_root" ]; then
    cp -R "$shared_root" "$work/shared"
    shared_root=$work/shared
fi

# lane_paths COMMIT LANE prints the paths that commit touches which the lane
# owns, one per line, each prefixed by its status letter.
lane_paths() {
    git diff --name-status --no-renames "$1^" "$1" |
        LANE=$2 MAP=$lane_map python3 -c '
import fnmatch, os, sys
rows = []
for line in open(os.environ["MAP"]):
    line = line.rstrip("\n")
    if not line or line.startswith("#") or line.startswith("lane\t"):
        continue
    lane, pattern = line.split("\t", 1)
    rows.append((lane, pattern))
want = os.environ["LANE"]
for line in sys.stdin:
    status, path = line.rstrip("\n").split("\t", 1)
    for lane, pattern in rows:
        if fnmatch.fnmatch(path, pattern):
            if lane == want:
                print(status[0] + "\t" + path)
            break
'
}

# commit_is_pure COMMIT LANE succeeds where every path the commit touches
# belongs to the lane, which is the condition a cherry-pick preserves.
commit_is_pure() {
    total=$(git diff --name-only --no-renames "$1^" "$1" | wc -l)
    mine=$(lane_paths "$1" "$2" | wc -l)
    [ "$total" -eq "$mine" ]
}

replay_lane() {
    lane=$1
    lane_base=$2
    printf '=== lane %s from %s\n' "$lane" "$lane_base"
    git checkout -q -B "lane/$lane" "$lane_base"
    for commit in $commits; do
        lane_paths "$commit" "$lane" >"$work/paths"
        [ -s "$work/paths" ] || continue
        if commit_is_pure "$commit" "$lane"; then
            if git cherry-pick -x "$commit" >/dev/null 2>&1; then
                printf '  %s cherry-pick\n' "$(git rev-parse --short "$commit")"
                continue
            fi
            git cherry-pick --abort >/dev/null 2>&1 || true
        fi
        while IFS='	' read -r status path; do
            if [ "$status" = D ]; then
                git rm -q --ignore-unmatch -- "$path"
            else
                git checkout -q "$commit" -- "$path"
                git add -- "$path"
            fi
        done <"$work/paths"
        if git diff --cached --quiet; then
            continue
        fi
        git log -1 --format=%B "$commit" >"$work/message"
        printf '\nSplit-from: %s\n' "$(git rev-parse "$commit")" >>"$work/message"
        GIT_AUTHOR_NAME=$(git log -1 --format=%an "$commit") \
        GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$commit") \
        GIT_AUTHOR_DATE=$(git log -1 --format=%aD "$commit") \
            git commit -q --file="$work/message" --cleanup=verbatim
        printf '  %s split\n' "$(git rev-parse --short "$commit")"
    done
    if [ -d "$shared_root/$lane" ]; then
        # A shared slice is stored as the whole file the lane carries rather
        # than as a patch, because three lanes stack and a patch against the
        # base version would then apply over a file the lane below already
        # changed. A stacked lane's slice holds census-timing's content with
        # its own hunks on top, and copying states that directly.
        (cd "$shared_root/$lane" && find . -type f -print) |
            sed 's|^\./||' |
            while read -r shared_path; do
                cp "$shared_root/$lane/$shared_path" "$repository_root/$shared_path"
            done
        if ! git diff --quiet; then
            git add -A
            git commit -q -m "$lane: carry this lane's share of the files every lane touches

CLAUDE.md, remote/repository-quality-gates.sh,
evidence/raven2-vulkan-kernel-census/README.md, remote/build-llama-preset.sh,
remote/radv-low-priority-env.sh, and remote/check-text-policy.py each carry
paragraphs, gate cells, or hunks belonging to several successor lanes. This
commit applies the hunks that describe $lane's own files, from
docs/split-plan/shared/$lane/ in the split-plan branch.

Split-from: $source_commit"
            printf '  shared slice\n'
        fi
    fi
    remote/refresh-evidence-manifest.sh
    if ! git diff --quiet -- evidence/SHA256SUMS; then
        git add evidence/SHA256SUMS
        git commit -q -m "evidence: regenerate the manifest over this lane's tree

remote/refresh-evidence-manifest.sh hashes the tracked evidence tree, so a lane
carrying a subset of PR #105's evidence needs its own manifest for
\`--check\` to pass on the lane alone."
        printf '  manifest\n'
    fi
    printf '  tip %s\n' "$(git rev-parse --short HEAD)"
}

replay_lane census-timing "$base_commit"
replay_lane build-cache-identity "$base_commit"
replay_lane dpm-telemetry lane/census-timing
replay_lane shader-e4 "$base_commit"
replay_lane correctness-witnesses lane/census-timing
replay_lane served-ab-harness lane/census-timing
replay_lane retained-evidence "$base_commit"
