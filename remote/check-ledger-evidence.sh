#!/bin/sh
set -eu

# Every evidence path the three ledgers name resolves to a file or directory in
# this tree. The ledgers are read at launch on a host carrying remote/ and
# patches/ alone, so their readers validate row shape -- a property of the row
# -- and existence is a property of the tree, which this gate asserts where the
# tree is. A row naming a path nobody retained is a claim without a
# measurement, and that fails a gate rather than refusing a launch over a
# directory the sync never sent.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
tuple_ledger=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}
draft_pair_ledger=${QWEN_DRAFT_PAIRS:-$script_directory/draft-pairs.tsv}
ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}

failures=0
checked=0

# AWK selects the identifier and evidence columns and the shell tests the
# quoted path with its pathname primitive, so ledger text never becomes
# executable input. A path outside the repository-relative shape is refused
# here as it is by every reader, because this gate resolves it against the tree
# root.
check_ledger() {
    ledger_name=$1
    ledger_path=$2
    identifier_column=$3
    evidence_column=$4
    if [ ! -r "$ledger_path" ]; then
        printf '%s is unreadable: %s\n' "$ledger_name" "$ledger_path" >&2
        failures=$((failures + 1))
        return 0
    fi
    ledger_pairs=$(awk -F'\t' \
        -v identifier_column="$identifier_column" \
        -v evidence_column="$evidence_column" '
        /^[[:space:]]*($|#)/ { next }
        NF >= evidence_column {
            printf "%s\t%s\n", $identifier_column, $evidence_column
        }
    ' "$ledger_path")
    while IFS='	' read -r row_identifier row_evidence; do
        [ -n "$row_identifier" ] || continue
        [ "$row_evidence" = - ] && continue
        [ -n "$row_evidence" ] || continue
        case $row_evidence in
            /* | ../* | */../* | */..)
                printf '%s: %s names evidence outside the tree: %s\n' \
                    "$ledger_name" "$row_identifier" "$row_evidence" >&2
                failures=$((failures + 1))
                continue
                ;;
        esac
        checked=$((checked + 1))
        if [ ! -e "$repository_root/$row_evidence" ]; then
            printf '%s: %s names evidence absent from the tree: %s\n' \
                "$ledger_name" "$row_identifier" "$row_evidence" >&2
            failures=$((failures + 1))
        fi
    done <<EOF
$ledger_pairs
EOF
}

check_ledger 'validated tuple ledger' "$tuple_ledger" 1 15
check_ledger 'draft pair ledger' "$draft_pair_ledger" 1 10
check_ledger 'context checkpoint ledger' "$ctx_checkpoint_ledger" 1 3

if [ "$failures" -eq 0 ]; then
    printf 'ledger_evidence=accepted paths=%s\n' "$checked"
    exit 0
fi
printf 'ledger_evidence=rejected failures=%s\n' "$failures" >&2
exit 1
