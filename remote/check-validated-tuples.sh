#!/bin/sh
set -eu

# Every models.tsv row that claims a numeric validated_filled_depth must own a
# validated row in remote/validated-tuples.tsv naming the same model, depth,
# and geometry. models.tsv holds one validated_filled_depth/batch/ubatch/cache
# triple per row and the ledger holds every measured arm, so the two files
# drift apart unless this check derives the tuple models.tsv already claims
# and requires the ledger to carry it.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
model_registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
tuple_ledger=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}

if [ ! -r "$model_registry" ]; then
    printf 'model registry is unreadable: %s\n' "$model_registry" >&2
    exit 1
fi
if [ ! -r "$tuple_ledger" ]; then
    printf 'validated tuple ledger is unreadable: %s\n' "$tuple_ledger" >&2
    exit 1
fi

awk -F'\t' '
    FILENAME == ARGV[1] {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) { next }
        if (NF != 21) { next }
        if ($14 != "validated") { next }
        # model_id, context, batch, ubatch, cache_k, cache_v, flash_attention
        key = $2 SUBSEP $4 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP $8 SUBSEP $9
        validated_tuples[key] = 1
        next
    }
    $0 ~ /^#/ || $0 ~ /^[[:space:]]*$/ { next }
    {
        if (NF != 22) { next }
        # id, context_default..., batch, ubatch, validated_filled_depth,
        # validation_evidence, cache_type_k, cache_type_v, flash_attention.
        if ($19 == "-") { next }
        checked++
        key = $1 SUBSEP $19 SUBSEP $17 SUBSEP $18 SUBSEP $8 SUBSEP $9 SUBSEP $10
        if (!(key in validated_tuples)) {
            printf "%s: models.tsv claims validated_filled_depth %s at batch %s, ubatch %s, cache %s/%s, flash attention %s, and no validated row in %s matches\n", \
                $1, $19, $17, $18, $8, $9, $10, "'"$tuple_ledger"'" > "/dev/stderr"
            gaps++
        }
    }
    END {
        if (gaps + 0 > 0) {
            printf "check_validated_tuples=rejected gaps=%d checked=%d\n", \
                gaps, checked > "/dev/stderr"
            exit 1
        }
        printf "check_validated_tuples=accepted checked=%d\n", checked
    }
' "$tuple_ledger" "$model_registry"
