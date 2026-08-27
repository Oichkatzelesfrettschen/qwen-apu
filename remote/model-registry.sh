#!/bin/sh
set -eu

# Read one field of one row of remote/models.tsv. A checkpoint is identified
# either by its registry id or by the path it is served from, so the launch
# path resolves a row from QWEN_MODEL_PATH without the caller naming an id.

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    printf 'usage: %s id|path SELECTOR [FIELD]\n' "$0" >&2
    printf 'fields: id role model_file fetch_script context_default context_ceiling\n' >&2
    printf '        context_target cache_type_k cache_type_v flash_attention\n' >&2
    printf '        projector decode_tok_s prefill_tok_s quality tier\n' >&2
    printf 'omit FIELD to print the whole row as key=value lines\n' >&2
    exit 2
fi

selector_kind=$1
selector=$2
field=${3:-}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}

case $selector_kind in
    id | path) ;;
    *)
        printf 'selector kind must be id or path: %s\n' "$selector_kind" >&2
        exit 2
        ;;
esac

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi

awk -F'\t' -v kind="$selector_kind" -v selector="$selector" -v field="$field" '
    /^#/ { next }
    NF < 15 { next }
    {
        matched = 0
        if (kind == "id" && $1 == selector) {
            matched = 1
        }
        # A path matches when it ends in the registry file suffix, so the row
        # holds a repository-relative name and the caller holds an absolute one.
        if (kind == "path" && length($3) <= length(selector) &&
            substr(selector, length(selector) - length($3) + 1) == $3) {
            matched = 1
        }
        if (!matched) { next }
        matched_any = 1
        split("id role model_file fetch_script context_default context_ceiling " \
              "context_target cache_type_k cache_type_v flash_attention projector " \
              "decode_tok_s prefill_tok_s quality tier", names, " ")
        if (field == "") {
            for (i = 1; i <= 15; i++) { printf "%s=%s\n", names[i], $i }
        } else {
            for (i = 1; i <= 15; i++) {
                if (names[i] == field) { printf "%s\n", $i; found = 1 }
            }
            if (!found) { exit 3 }
        }
        exit 0
    }
    END {
        if (!matched_any) {
            printf "no registry row matches %s %s\n", kind, selector > "/dev/stderr"
            exit 1
        }
    }
' "$registry"
