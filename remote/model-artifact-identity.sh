#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'usage: %s MODEL_ID\n' "$0" >&2
    exit 2
fi

model_id=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
identity_ledger=${QWEN_MODEL_ARTIFACTS:-$script_directory/model-artifacts.tsv}

if [ ! -f "$identity_ledger" ] || [ -L "$identity_ledger" ]; then
    printf 'model artifact identity ledger is absent or linked: %s\n' \
        "$identity_ledger" >&2
    exit 2
fi

awk -F '\t' -v model_id="$model_id" '
    /^[[:space:]]*($|#)/ { next }
    {
        if (NF != 6 || $1 == "" || $2 == "" || $3 !~ /^[1-9][0-9]*$/ ||
            length($4) != 64 || $4 ~ /[^0-9a-f]/ ||
            $5 !~ /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/ ||
            (length($6) != 40 && length($6) != 64) ||
            $6 ~ /[^0-9a-f]/ || $2 ~ /^\// || $2 ~ /(^|\/)\.\.($|\/)/ ||
            $2 ~ /\/\//) {
            printf "model artifact identity ledger line %d is malformed\n", \
                NR > "/dev/stderr"
            invalid = 1
        }
        if ($1 in first_line_by_model_id) {
            printf "model artifact identity ledger duplicates model ID %s on lines %d and %d\n", \
                $1, first_line_by_model_id[$1], NR > "/dev/stderr"
            invalid = 1
        } else {
            first_line_by_model_id[$1] = NR
        }
        if ($1 == model_id) {
            row = $0
            matches++
        }
    }
    END {
        if (invalid) {
            exit 2
        }
        if (matches != 1) {
            printf "model artifact identity requires one row for %s, found %d\n", \
                model_id, matches > "/dev/stderr"
            exit 2
        }
        print row
    }
' "$identity_ledger"
