#!/bin/sh
set -eu

# Validate the shared publisher-identity reader without downloading model bytes.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
reader=$script_directory/model-artifact-identity.sh
ledger=$script_directory/model-artifacts.tsv
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

for model_id in qwen35-08b qwen38-2b-distill qwen38-4b-distill; do
    row=$(QWEN_MODEL_ARTIFACTS=$ledger "$reader" "$model_id")
    field_count=$(printf '%s\n' "$row" | awk -F '\t' '{ print NF }')
    row_id=${row%%	*}
    state=accepted
    [ "$field_count" -eq 6 ] || state=field-count
    [ "$row_id" = "$model_id" ] || state=model-id
    report "publisher_identity_$model_id" "$state"
done

if QWEN_MODEL_ARTIFACTS=$ledger "$reader" absent-model \
    >"$work_directory/absent.stdout" 2>"$work_directory/absent.stderr"; then
    report absent_model_refused rejected
else
    report absent_model_refused accepted
fi

valid_row=$(QWEN_MODEL_ARTIFACTS=$ledger "$reader" qwen35-08b)
malformed_ledger=$work_directory/malformed.tsv
printf '%s\n%s\textra\n' "$valid_row" \
    'qwen38-2b-distill	model.gguf	1	0000000000000000000000000000000000000000000000000000000000000000	owner/repo	0000000000000000000000000000000000000000' \
    >"$malformed_ledger"
if QWEN_MODEL_ARTIFACTS=$malformed_ledger "$reader" qwen35-08b \
    >"$work_directory/malformed.stdout" 2>"$work_directory/malformed.stderr"; then
    report unrelated_malformed_row_refused rejected
else
    report unrelated_malformed_row_refused accepted
fi

unsafe_ledger=$work_directory/unsafe.tsv
printf '%s\n' \
    'qwen35-08b	../model.gguf	1	0000000000000000000000000000000000000000000000000000000000000000	owner/repo	0000000000000000000000000000000000000000' \
    >"$unsafe_ledger"
if QWEN_MODEL_ARTIFACTS=$unsafe_ledger "$reader" qwen35-08b \
    >"$work_directory/unsafe.stdout" 2>"$work_directory/unsafe.stderr"; then
    report unsafe_model_path_refused rejected
else
    report unsafe_model_path_refused accepted
fi

duplicate_ledger=$work_directory/duplicate.tsv
printf '%s\n%s\n' "$valid_row" "$valid_row" >"$duplicate_ledger"
if QWEN_MODEL_ARTIFACTS=$duplicate_ledger "$reader" qwen35-08b \
    >"$work_directory/duplicate.stdout" 2>"$work_directory/duplicate.stderr"; then
    report duplicate_model_refused rejected
else
    report duplicate_model_refused accepted
fi

unrelated_duplicate_ledger=$work_directory/unrelated-duplicate.tsv
other_valid_row=$(QWEN_MODEL_ARTIFACTS=$ledger "$reader" qwen38-2b-distill)
printf '%s\n%s\n%s\n' "$valid_row" "$other_valid_row" "$other_valid_row" \
    >"$unrelated_duplicate_ledger"
if QWEN_MODEL_ARTIFACTS=$unrelated_duplicate_ledger "$reader" qwen35-08b \
    >"$work_directory/unrelated-duplicate.stdout" \
    2>"$work_directory/unrelated-duplicate.stderr"; then
    report unrelated_duplicate_model_refused rejected
else
    report unrelated_duplicate_model_refused accepted
fi

if [ "$failures" -ne 0 ]; then
    printf 'model_artifact_identity=rejected failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'model_artifact_identity=accepted\n'
