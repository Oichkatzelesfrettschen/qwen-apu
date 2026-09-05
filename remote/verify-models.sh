#!/bin/sh
set -eu

# Every registry model file under the root against the digest its fetch
# rule pins.
#
# The registry states which checkpoints the appliance admits and the fetch
# scripts state what each one's bytes are: remote/model-artifacts.tsv carries
# one publisher-pinned row per artifact a measured campaign reads, and every
# other download script carries the same pair as `expected_bytes=` and
# `expected_sha256=` literals of its own. This script joins the two and
# reports one row per registry artifact -- the model file, and the projector
# where the row requires one -- as `verified`, `absent`, `bytes-differ`,
# `digest-differs`, or `unpinned`. It fetches nothing: an absent file is a
# state to report rather than a download to start, and the download script the
# row names is what the report prints as the remedy.
#
# The byte count is read before the digest, so a wrong file ends its row at a
# stat rather than at a full read of the 74 GB the models tree holds. A pin
# absent from both sources reads `unpinned`, which is a hole in the fetch
# rules rather than a fault in the file, and an artifact ledger row naming no
# registry row reads `orphan-pin` on the reverse join.
#
# usage: verify-models.sh [MODEL_ID...]
#   QWEN_MODEL_REGISTRY   the registry, default remote/models.tsv
#   QWEN_MODEL_ARTIFACTS  the pin ledger, default remote/model-artifacts.tsv
#   QWEN_MODEL_ROOT       the models tree, default models/ under QWEN_HOME
#   QWEN_MODEL_FETCH_DIR  the directory the fetch scripts live in, default remote/
# Exit 0 where every reported row reads verified, absent, or unpinned; exit 1
# where any row's bytes or digest differ from its pin.

usage() {
    sed -n '25,30p' "$0" >&2
    exit 2
}

case ${1:-} in -h | --help) usage ;; esac

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
artifact_ledger=${QWEN_MODEL_ARTIFACTS:-$script_directory/model-artifacts.tsv}
model_root=${QWEN_MODEL_ROOT:-$qwen_home_models}
fetch_directory=${QWEN_MODEL_FETCH_DIR:-$script_directory}
for required in "$registry" "$artifact_ledger"; do
    [ -r "$required" ] || { printf 'unreadable: %s\n' "$required" >&2; exit 2; }
done

tab=$(printf '\t')

# A download script states its pin as two top-level assignments, so the pin is
# read out of the source rather than by running it; a script that reads the
# artifact ledger instead carries neither and is answered by the join above.
script_pin() {
    script_pin_file=$fetch_directory/$1
    [ -r "$script_pin_file" ] || return 1
    script_pin_bytes=$(sed -n 's/^expected_bytes=//p' "$script_pin_file" | head -n 1)
    script_pin_sha256=$(sed -n 's/^expected_sha256=//p' "$script_pin_file" | head -n 1)
    [ -n "$script_pin_bytes" ] && [ -n "$script_pin_sha256" ]
}

ledger_pin() {
    ledger_pin_row=$(awk -F'\t' -v id="$1" '!/^#/ && $1 == id { print $3 "\t" $4; exit }' "$artifact_ledger")
    [ -n "$ledger_pin_row" ] || return 1
    script_pin_bytes=${ledger_pin_row%%"$tab"*}
    script_pin_sha256=${ledger_pin_row#*"$tab"}
    [ -n "$script_pin_bytes" ] && [ -n "$script_pin_sha256" ]
}

# A projector's path lives in the script that fetches it rather than in a
# registry column, as the destination directory and the artifact name it
# writes, so the two literals resolve the file the row requires.
projector_path() {
    projector_script=$fetch_directory/$1
    [ -r "$projector_script" ] || return 1
    projector_directory=$(sed -n 's/^destination_directory=.*qwen_home_models\/\([^"}]*\)".*/\1/p' "$projector_script" | head -n 1)
    projector_name=$(sed -n 's/^artifact_name=//p' "$projector_script" | head -n 1)
    [ -n "$projector_directory" ] && [ -n "$projector_name" ] || return 1
    printf '%s/%s\n' "$projector_directory" "$projector_name"
}

report_artifact() {
    report_id=$1
    report_kind=$2
    report_relative=$3
    report_script=$4
    report_file=$model_root/$report_relative
    if ! ledger_pin "$report_id" && ! script_pin "$report_script"; then
        printf '%s\t%s\t%s\tunpinned\t-\t-\t%s\n' \
            "$report_id" "$report_kind" "$report_relative" "$report_script"
        return 0
    fi
    if [ ! -f "$report_file" ]; then
        printf '%s\t%s\t%s\tabsent\t%s\t%s\t%s\n' \
            "$report_id" "$report_kind" "$report_relative" \
            "$script_pin_bytes" "$script_pin_sha256" "$report_script"
        return 0
    fi
    observed_bytes=$(wc -c <"$report_file" | tr -d ' ')
    if [ "$observed_bytes" != "$script_pin_bytes" ]; then
        printf '%s\t%s\t%s\tbytes-differ\t%s\t%s\t%s\n' \
            "$report_id" "$report_kind" "$report_relative" \
            "$script_pin_bytes" "$observed_bytes" "$report_script"
        return 0
    fi
    observed_sha256=$(sha256sum -- "$report_file" | cut -d ' ' -f 1)
    if [ "$observed_sha256" != "$script_pin_sha256" ]; then
        printf '%s\t%s\t%s\tdigest-differs\t%s\t%s\t%s\n' \
            "$report_id" "$report_kind" "$report_relative" \
            "$script_pin_sha256" "$observed_sha256" "$report_script"
        return 0
    fi
    printf '%s\t%s\t%s\tverified\t%s\t%s\t%s\n' \
        "$report_id" "$report_kind" "$report_relative" \
        "$script_pin_bytes" "$script_pin_sha256" "$report_script"
}

selection=$*
row_selected() {
    [ -z "$selection" ] && return 0
    for selected in $selection; do
        [ "$selected" = "$1" ] && return 0
    done
    return 1
}

printf 'model_id\tkind\tpath\tstatus\texpected\tobserved\tfetch_script\n'
rows_file=$(mktemp "${TMPDIR:-/tmp}/verify-models.XXXXXX")
trap 'rm -f "$rows_file"' EXIT HUP INT TERM
awk -F'\t' '!/^#/ && NF >= 12 { print $1 "\t" $3 "\t" $4 "\t" $11 "\t" $12 }' "$registry" \
    | while IFS="$tab" read -r row_id row_file row_script row_projector row_projector_script; do
    [ -n "$row_id" ] || continue
    row_selected "$row_id" || continue
    report_artifact "$row_id" model "$row_file" "$row_script"
    if [ "$row_projector" = required ]; then
        if projector_relative=$(projector_path "$row_projector_script"); then
            report_artifact "$row_id" projector "$projector_relative" "$row_projector_script"
        else
            printf '%s\tprojector\t-\tunpinned\t-\t-\t%s\n' "$row_id" "$row_projector_script"
        fi
    fi
done >"$rows_file"
cat "$rows_file"
# The row loop runs in a subshell of that pipeline, so the tallies are counted
# from the rows it wrote rather than read back across the subshell boundary.
count_status() {
    awk -F'\t' -v want="$1" '$4 == want { n++ } END { print n + 0 }' "$rows_file"
}
verified=$(count_status verified)
absent=$(count_status absent)
unpinned=$(count_status unpinned)
mismatches=$(($(count_status bytes-differ) + $(count_status digest-differs)))

# The reverse join: a pin the registry names nowhere is a ledger row whose
# artifact no admitted checkpoint reads.
orphans=0
while IFS="$tab" read -r pin_id _rest; do
    case $pin_id in '' | '#'*) continue ;; esac
    if ! awk -F'\t' -v id="$pin_id" '!/^#/ && $1 == id { found = 1 } END { exit found ? 0 : 1 }' "$registry"; then
        printf '%s\tledger\t-\torphan-pin\t-\t-\t%s\n' "$pin_id" "$artifact_ledger"
        orphans=$((orphans + 1))
    fi
done <"$artifact_ledger"

printf 'verify_models=%s verified=%s absent=%s unpinned=%s mismatched=%s orphan_pins=%s models_root=%s\n' \
    "$([ "$mismatches" -eq 0 ] && printf 'passed' || printf 'failed')" \
    "$verified" "$absent" "$unpinned" "$mismatches" "$orphans" "$model_root"
[ "$mismatches" -eq 0 ]
