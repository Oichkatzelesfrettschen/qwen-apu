#!/bin/sh
set -eu

# The checkpoint-semantics classifier, runnable on its own so a unit test
# drives every branch directly rather than inferring the decision from a whole
# build. The declaration is earned rather than asserted: natural-boundary-v1
# requires the repository patch at its recorded digest, the compiled source at
# the digest the series replay pins, and the forced partition absent from that
# source; forced-tail-v1 requires the source to hash to the pinned commit's own
# file with the partition present; every other source reads unknown, since a
# later upstream revision may place checkpoints by a rule no digest here
# identifies. Both negative names refuse a positive --ctx-checkpoints count.
#
# The optional digest arguments exist for the unit test, which classifies
# fixture files under fixture digests; a production caller passes the two
# paths alone and the pinned constants decide.

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
    printf 'usage: %s SOURCE_FILE PATCH_FILE [NATURAL_SOURCE_SHA256 NATURAL_PATCH_SHA256 FORCED_SOURCE_SHA256]\n' "$0" >&2
    exit 2
fi

checkpoint_source=$1
checkpoint_patch_path=$2
natural_boundary_source_sha256=${3:-7ef5095ae09986f2d7b244bcf72e0c389a40eab03d8ebf9744f0599218fdbe46}
natural_boundary_patch_sha256=${4:-c9d4010594da1f632be009b934cd045f6625b8baba68d09b7ed6190b02f9ddfc}
forced_tail_source_sha256=${5:-a79cf9e1d4a8d7c1f0ee608aa781628db403e8f59e25e731f997d0952d230e47}

if [ ! -r "$checkpoint_source" ]; then
    printf 'checkpoint semantics are unreadable: %s\n' "$checkpoint_source" >&2
    exit 1
fi
checkpoint_source_sha256=$(sha256sum "$checkpoint_source" | cut -d ' ' -f 1)
checkpoint_patch_sha256=absent
if [ -r "$checkpoint_patch_path" ]; then
    checkpoint_patch_sha256=$(sha256sum "$checkpoint_patch_path" | cut -d ' ' -f 1)
fi

checkpoint_semantics=unknown
if [ "$checkpoint_patch_sha256" = "$natural_boundary_patch_sha256" ] &&
    [ "$checkpoint_source_sha256" = "$natural_boundary_source_sha256" ] &&
    ! grep -q 'checkpoint_offsets' "$checkpoint_source"; then
    checkpoint_semantics=natural-boundary-v1
elif [ "$checkpoint_source_sha256" = "$forced_tail_source_sha256" ] &&
    grep -q 'checkpoint_offsets' "$checkpoint_source"; then
    checkpoint_semantics=forced-tail-v1
fi

printf 'checkpoint_semantics=%s\n' "$checkpoint_semantics"
printf 'checkpoint_source_sha256=%s\n' "$checkpoint_source_sha256"
printf 'checkpoint_patch_sha256=%s\n' "$checkpoint_patch_sha256"
