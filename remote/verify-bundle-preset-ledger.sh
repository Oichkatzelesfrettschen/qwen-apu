#!/bin/sh
set -eu

# A preset section carries LLAMA_ARG_CTX_CHECKPOINTS because common_preset::merge
# would push one router argv value onto every child, so the preset and the
# ledger are two statements of the same count and a bundle carries both. This
# check binds each section to its own model's count: the section's
# LLAMA_ARG_MODEL path resolves through the registry's model_file column to
# exactly one model_id by the raw suffix rule model-registry.sh applies to a
# path selector, refusing a path two rows match rather than taking the first
# as the registry would, and the section's count must equal that row's ledger count, with
# a registry row absent from the ledger reading 0. A draft-pair section names
# its target's file, so the target's count binds it; a web profile names its
# checkpoint's file the same way. A section carrying no model path, a path
# outside the registry, or a path two rows share is refused, as is a count
# that merely appears somewhere in the ledger. A preset generated against
# another ledger therefore fails assembly and activation rather than serving
# a count the bundled ledger never stated for that model.
#
# The Q4_K formulation a section carries is release state where the checkpoint
# count is bundled state, so a fourth input names the authority for it. A
# preset is generated once and outlives every later registry edit, and the
# `q4k_variant` column moves whenever a release promotes a row: reading the
# live column here refuses a preset that agreed with the registry it was
# generated against, in both directions at once. A bundle assembled before that
# column existed carries no key in any section and verifies exactly where no
# row releases a formulation, which is what `-` states; a bundle assembled
# after it carries its own two-column policy, and each section's resolved
# model_id appears in that policy or the bundle is refused. The registry keeps
# every other binding, so a depth or tier revocation still reaches an old
# bundle while its formulation policy stays the one it was built against.
#
# usage: verify-bundle-preset-ledger.sh PRESET_INI CTX_LEDGER [MODEL_REGISTRY]
#            [Q4K_POLICY]
# MODEL_REGISTRY defaults to QWEN_MODEL_REGISTRY, then models.tsv beside this
# script. Q4K_POLICY defaults to QWEN_BUNDLE_Q4K_POLICY; an empty value reads
# the registry column, and `-` releases no formulation on any row.

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    printf 'usage: %s PRESET_INI CTX_LEDGER [MODEL_REGISTRY] [Q4K_POLICY]\n' \
        "$0" >&2
    exit 2
fi
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
preset_path=$1
ledger_path=$2
registry_path=${3:-${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}}
q4k_policy_selector=${4:-${QWEN_BUNDLE_Q4K_POLICY:-}}
for required in "$preset_path" "$ledger_path" "$registry_path"; do
    if [ ! -r "$required" ]; then
        printf 'preset ledger check input is unreadable: %s\n' "$required" >&2
        exit 1
    fi
done
# The awk program reads a policy file at a fixed argument position under every
# mode, so the two modes that name no file read an empty one and the mode word
# rather than the file's emptiness decides what the absence means.
q4k_policy_scratch=''
case $q4k_policy_selector in
    '') q4k_policy_mode='registry' ;;
    -) q4k_policy_mode='none' ;;
    *)
        q4k_policy_mode='file'
        if [ ! -f "$q4k_policy_selector" ] || \
            [ ! -r "$q4k_policy_selector" ]; then
            printf 'Q4_K formulation policy is unreadable: %s\n' \
                "$q4k_policy_selector" >&2
            exit 1
        fi
        ;;
esac
q4k_policy_path=$q4k_policy_selector
if [ "$q4k_policy_mode" != 'file' ]; then
    q4k_policy_scratch=$(mktemp) || exit 1
    trap 'rm -f "$q4k_policy_scratch"' EXIT HUP INT TERM
    q4k_policy_path=$q4k_policy_scratch
fi

awk -F'\t' -v preset="$preset_path" -v policy_mode="$q4k_policy_mode" '
    FILENAME == ARGV[1] {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) next
        if (NF != 2 || $1 == "") {
            printf "Q4_K policy row is malformed: %s\n", $0 > "/dev/stderr"
            failed = 1
            next
        }
        if ($1 in policy_q4k) {
            printf "Q4_K policy names %s twice\n", $1 > "/dev/stderr"
            failed = 1
            next
        }
        if ($2 !~ /^(-|production\/4|e4\/[248]|e4-scale\/[248]|e4-scale-licm\/[248])$/) {
            printf "Q4_K policy row %s carries an invalid formulation: %s\n", \
                $1, $2 > "/dev/stderr"
            failed = 1
            next
        }
        policy_q4k[$1] = $2
        next
    }
    FILENAME == ARGV[2] {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) next
        if ($1 == "" || $3 == "") {
            printf "registry row is malformed: %s\n", $0 > "/dev/stderr"
            failed = 1
            next
        }
        registry_rows++
        registry_id[registry_rows] = $1
        registry_file[registry_rows] = $3
        registry_q4k[registry_rows] = ($23 == "") ? "-" : $23
        if (registry_q4k[registry_rows] !~ /^(-|production\/4|e4\/[248]|e4-scale\/[248]|e4-scale-licm\/[248])$/) {
            printf "registry row %s carries invalid q4k_variant: %s\n", \
                $1, registry_q4k[registry_rows] > "/dev/stderr"
            failed = 1
        }
        next
    }
    FILENAME == ARGV[3] {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) next
        if (NF < 2 || $2 !~ /^(0|[1-9][0-9]*)$/) {
            printf "ledger row is malformed: %s\n", $0 > "/dev/stderr"
            failed = 1
            next
        }
        ledger[$1] = $2
        next
    }
    /^\[/ {
        if (section != "") close_section()
        section = $0
        sub(/^\[/, "", section)
        sub(/\].*$/, "", section)
        sections++
        keys = 0
        models = 0
        model_value = ""
        q4k_keys = 0
        q4k_value = ""
        next
    }
    /^[[:space:]]*LLAMA_ARG_CTX_CHECKPOINTS[[:space:]]*=/ {
        value = $0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]+$/, "", value)
        keys++
        count = value
        next
    }
    /^[[:space:]]*LLAMA_ARG_VK_Q4K_VARIANT[[:space:]]*=/ {
        value = $0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]+$/, "", value)
        q4k_keys++
        q4k_value = value
        next
    }
    /^[[:space:]]*LLAMA_ARG_MODEL[[:space:]]*=/ {
        value = $0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]+$/, "", value)
        models++
        model_value = value
        next
    }
    # The raw suffix rule of a model-registry.sh path selector: the section
    # path ends in model_file. The registry answers with its first such row;
    # this check refuses a path that more than one row matches, so a
    # registry whose files are suffixes of one another cannot bind a section
    # to whichever row came first.
    function resolve_model(path,    i, file, matches, id) {
        matches = 0
        resolved_q4k = "-"
        for (i = 1; i <= registry_rows; i++) {
            file = registry_file[i]
            if (length(file) <= length(path) &&
                substr(path, length(path) - length(file) + 1) == file) {
                matches++
                id = registry_id[i]
                resolved_q4k = registry_q4k[i]
            }
        }
        if (matches != 1) {
            resolved_matches = matches
            return ""
        }
        return id
    }
    # The mode word decides which authority answers for a section: the registry
    # column where no bundle bound a policy, no formulation at all where the
    # bundle predates the column, and the bundled policy otherwise, where a
    # model the policy never described refuses the bundle rather than reading
    # as unreleased.
    function released_q4k(model_id) {
        if (policy_mode == "registry") return resolved_q4k
        if (policy_mode == "none") return "-"
        if (model_id in policy_q4k) return policy_q4k[model_id]
        policy_gap = 1
        return ""
    }
    function close_section(    model_id, expected, released) {
        if (keys != 1) {
            printf "preset section [%s] carries %d LLAMA_ARG_CTX_CHECKPOINTS keys; exactly one is required\n", section, keys > "/dev/stderr"
            failed = 1
            return
        }
        if (count !~ /^(0|[1-9][0-9]*)$/) {
            printf "preset section [%s] carries a malformed checkpoint count: %s\n", section, count > "/dev/stderr"
            failed = 1
            return
        }
        if (models != 1) {
            printf "preset section [%s] carries %d LLAMA_ARG_MODEL keys; exactly one is required\n", section, models > "/dev/stderr"
            failed = 1
            return
        }
        model_id = resolve_model(model_value)
        if (model_id == "") {
            printf "preset section [%s] carries LLAMA_ARG_MODEL %s that resolves to %d registry rows; exactly one is required\n", section, model_value, resolved_matches > "/dev/stderr"
            failed = 1
            return
        }
        expected = (model_id in ledger) ? ledger[model_id] : 0
        if (count + 0 != expected + 0) {
            printf "preset section [%s] carries checkpoint count %s where the bundled ledger states %s for %s\n", section, count, expected, model_id > "/dev/stderr"
            failed = 1
        }
        policy_gap = 0
        released = released_q4k(model_id)
        if (policy_gap) {
            printf "preset section [%s] serves %s, which the bundled Q4_K policy never names\n", section, model_id > "/dev/stderr"
            failed = 1
        } else if (released == "-") {
            if (q4k_keys != 0) {
                printf "preset section [%s] carries LLAMA_ARG_VK_Q4K_VARIANT %s where %s releases no Q4_K formulation for %s\n", section, q4k_value, policy_authority, model_id > "/dev/stderr"
                failed = 1
            }
        } else if (q4k_keys != 1) {
            printf "preset section [%s] carries %d LLAMA_ARG_VK_Q4K_VARIANT keys where %s releases %s for %s\n", section, q4k_keys, policy_authority, released, model_id > "/dev/stderr"
            failed = 1
        } else if (q4k_value != released) {
            printf "preset section [%s] carries Q4_K formulation %s where %s releases %s for %s\n", section, q4k_value, policy_authority, released, model_id > "/dev/stderr"
            failed = 1
        }
    }
    BEGIN {
        policy_authority = (policy_mode == "registry") ? "the registry" : \
            "the bundled Q4_K policy"
    }
    END {
        if (section != "") close_section()
        if (sections == 0) {
            printf "preset carries no sections: %s\n", preset > "/dev/stderr"
            failed = 1
        }
        if (failed) exit 1
        printf "preset_ledger_agreement=accepted sections=%d q4k_policy=%s\n", \
            sections, policy_mode
    }
' "$q4k_policy_path" "$registry_path" "$ledger_path" "$preset_path"
