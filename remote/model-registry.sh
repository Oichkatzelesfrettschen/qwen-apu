#!/bin/sh
set -eu

# Read one field of one row of remote/models.tsv. A checkpoint is identified
# either by its registry id or by the path it is served from, so the launch
# path resolves a row from QWEN_MODEL_PATH without the caller naming an id.

validate_cache_type() {
    case $1 in
        f32 | f16 | bf16 | q8_0 | q5_1 | q5_0 | q4_1 | q4_0 | iq4_nl)
            return 0
            ;;
        *) return 1 ;;
    esac
}

# The tier vocabulary is closed because each value carries a different claim and
# a typo would otherwise create a sixth tier that no reader handles. production
# is a serving tuple measured safe and useful; candidate leaves quality or
# performance unqualified with no device failure under its admitted tuple;
# quarantine names a device failure or the absence of any validated safe tuple;
# archive is a valid artifact displaced or too slow to serve; rejected lost
# admission on measurement without being dangerous.
validate_tier() {
    case $1 in
        production | candidate | quarantine | archive | rejected) return 0 ;;
        *) return 1 ;;
    esac
}

if [ "$#" -eq 2 ] && [ "$1" = validate-cache-type ]; then
    validate_cache_type "$2"
    exit $?
fi

if [ "$#" -eq 2 ] && [ "$1" = validate-tier ]; then
    validate_tier "$2"
    exit $?
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
quarantine_registry=${QWEN_QUARANTINE_REGISTRY:-$script_directory/quarantine.tsv}

# The quarantine queries read a second file rather than the tier field alone,
# because a quarantine has two scopes and the model registry has one row per
# checkpoint. A scope `model` row removes a checkpoint entirely; a scope
# `profile` row removes one tuple of a checkpoint that otherwise serves.
if [ "$#" -eq 1 ] && [ "$1" = quarantine-subjects ]; then
    [ -r "$quarantine_registry" ] || exit 0
    awk -F'\t' '/^#/ { next } NF < 13 { next } $2 == "model" { print $3 }' \
        "$quarantine_registry"
    exit 0
fi

if [ "$#" -eq 1 ] && [ "$1" = quarantine-profiles ]; then
    [ -r "$quarantine_registry" ] || exit 0
    awk -F'\t' '/^#/ { next } NF < 13 { next } $2 == "profile" {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $3, $5, $6, $7, $8, $9, $10
    }' "$quarantine_registry"
    exit 0
fi

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    printf 'usage: %s id|path SELECTOR [FIELD]\n' "$0" >&2
    printf '       %s validate-cache-type TYPE\n' "$0" >&2
    printf '       %s validate-tier TIER\n' "$0" >&2
    printf '       %s quarantine-subjects | quarantine-profiles\n' "$0" >&2
    printf 'fields: id role model_file fetch_script context_default context_ceiling\n' >&2
    printf '        context_target cache_type_k cache_type_v flash_attention\n' >&2
    printf '        projector decode_tok_s prefill_tok_s quality tier batch\n' >&2
    printf '        ubatch validated_filled_depth validation_evidence\n' >&2
    printf 'omit FIELD to print the whole row as key=value lines\n' >&2
    exit 2
fi

selector_kind=$1
selector=$2
field=${3:-}
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}

case $selector_kind in
    id | path) ;;
    *)
        printf 'selector kind must be id, path, validate-cache-type, validate-tier, or a quarantine query: %s\n' \
            "$selector_kind" >&2
        exit 2
        ;;
esac

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi

awk -F'\t' -v kind="$selector_kind" -v selector="$selector" -v field="$field" '
    /^#/ { next }
    NF < 19 { next }
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
              "decode_tok_s prefill_tok_s quality tier batch ubatch " \
              "validated_filled_depth validation_evidence", names, " ")
        if (field == "") {
            for (i = 1; i <= 19; i++) { printf "%s=%s\n", names[i], $i }
        } else {
            for (i = 1; i <= 19; i++) {
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
