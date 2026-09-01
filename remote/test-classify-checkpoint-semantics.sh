#!/bin/sh
set -eu

# Every branch of the checkpoint-semantics classifier under fixture digests,
# so the three-name decision is proven by direct execution rather than
# inferred from a whole build. The fixture digests stand in for the pinned
# constants through the classifier's optional arguments; the production
# defaults stay untested here because no fixture can hash to them, which is
# the property that makes the pins worth pinning.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

classifier=$script_directory/classify-checkpoint-semantics.sh
checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

# Fixture sources: the repaired file omits the partition array, the stock file
# carries it, and a third file resembles neither digest.
repaired_source=$work_directory/repaired.cpp
printf 'void fill_loop() { /* natural n_batch boundaries */ }\n' >"$repaired_source"
stock_source=$work_directory/stock.cpp
printf 'int checkpoint_offsets[] = {4 + n_ubatch, 4};\n' >"$stock_source"
foreign_source=$work_directory/foreign.cpp
printf 'void some_later_upstream_shape() {}\n' >"$foreign_source"
fixture_patch=$work_directory/repair.patch
printf -- '--- a/tools/server/server-context.cpp\n' >"$fixture_patch"

repaired_sha256=$(sha256sum "$repaired_source" | cut -d ' ' -f 1)
stock_sha256=$(sha256sum "$stock_source" | cut -d ' ' -f 1)
patch_sha256=$(sha256sum "$fixture_patch" | cut -d ' ' -f 1)

classify() {
    "$classifier" "$1" "$2" "$repaired_sha256" "$patch_sha256" "$stock_sha256" |
        awk -F= '$1 == "checkpoint_semantics" { print $2 }'
}

# Matching patch, matching repaired source, partition absent.
if [ "$(classify "$repaired_source" "$fixture_patch")" = natural-boundary-v1 ]; then
    report natural_boundary_earned accepted
else
    printf 'the repaired fixture failed to earn natural-boundary-v1\n' >&2
    exit 1
fi

# The pinned stock source with the partition present.
if [ "$(classify "$stock_source" "$fixture_patch")" = forced-tail-v1 ]; then
    report forced_tail_earned accepted
else
    printf 'the stock fixture failed to earn forced-tail-v1\n' >&2
    exit 1
fi

# A source resembling neither digest.
if [ "$(classify "$foreign_source" "$fixture_patch")" = unknown ]; then
    report foreign_source_unknown accepted
else
    printf 'a foreign source escaped the unknown name\n' >&2
    exit 1
fi

# The repaired source under an absent patch: the repository no longer holds
# the member the declaration names, so the claim is unearnable.
if [ "$(classify "$repaired_source" "$work_directory/absent.patch")" = unknown ]; then
    report absent_patch_unknown accepted
else
    printf 'an absent patch still earned natural-boundary-v1\n' >&2
    exit 1
fi

# A source whose digest matches the repaired pin while carrying the partition
# is a contradiction between digest and content; the contradiction reads
# unknown. The digest argument is set to the stock file's own so the content
# check is what decides.
if [ "$("$classifier" "$stock_source" "$fixture_patch" \
    "$stock_sha256" "$patch_sha256" "$repaired_sha256" |
    awk -F= '$1 == "checkpoint_semantics" { print $2 }')" = unknown ]; then
    report partition_contradiction_unknown accepted
else
    printf 'a partition-carrying source under the repaired digest escaped unknown\n' >&2
    exit 1
fi

# The stock digest without the partition reads unknown for the same reason.
if [ "$("$classifier" "$repaired_source" "$fixture_patch" \
    "$stock_sha256" "$patch_sha256" "$repaired_sha256" |
    awk -F= '$1 == "checkpoint_semantics" { print $2 }')" = unknown ]; then
    report absent_partition_contradiction_unknown accepted
else
    printf 'a partition-free source under the stock digest escaped unknown\n' >&2
    exit 1
fi

# An unreadable source refuses with the reason rather than classifying.
if "$classifier" "$work_directory/missing.cpp" "$fixture_patch" \
    >/dev/null 2>"$work_directory/unreadable.stderr"; then
    printf 'an unreadable source still classified\n' >&2
    exit 1
fi
if ! grep -q 'checkpoint semantics are unreadable' \
    "$work_directory/unreadable.stderr"; then
    printf 'the unreadable refusal lost its reason\n' >&2
    exit 1
fi
report unreadable_source_refused accepted

# The production caller consumes this classifier rather than restating it, so
# a branch fixed here is fixed in the build.
if ! grep -q 'classify-checkpoint-semantics.sh' \
    "$script_directory/build-llama-preset.sh"; then
    printf 'the build no longer consumes the classifier\n' >&2
    exit 1
fi
report build_consumes_classifier accepted

printf 'classify_checkpoint_semantics=accepted checks=%s\n' "$checks"
