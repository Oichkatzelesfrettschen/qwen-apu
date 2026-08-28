#!/bin/sh
set -eu

# Generate the web-enabled router preset file from remote/web-profiles.tsv,
# joined against remote/models.tsv for the tuple each profile's model_id
# serves at.
#
# llama-server reads a router preset whose section keys are LLAMA_ARG_* option
# names, which is the format build-router-presets.sh emits and the format
# qwen-capacity-policy.sh validates. This generator emits the same key
# spelling, so one validator covers both files.
#
# Router mode overlays every per-model preset key with its own CLI argument
# (server-models.cpp ends its preset assembly with preset.merge(base_preset),
# and common_preset::merge overwrites), so an absent key falls through to a
# llama.cpp default a section never chose. Every emitted section therefore
# carries all six geometry keys -- LLAMA_ARG_CTX_SIZE, LLAMA_ARG_BATCH,
# LLAMA_ARG_UBATCH, LLAMA_ARG_CACHE_TYPE_K, LLAMA_ARG_CACHE_TYPE_V, and
# LLAMA_ARG_FLASH_ATTN -- read from the model_id's own registry row rather
# than left to inherit one. LLAMA_ARG_ALIAS carries the profile_id, so the
# served name states the profile the request ran under rather than the
# checkpoint several profiles share.
#
# A section is named for its profile_id and several profiles may name one
# checkpoint, so the section name resolves no registry row. The head marker
# `# qwen_web_presets=1` tells qwen-capacity-policy.sh to resolve each section
# through its LLAMA_ARG_MODEL path instead, and to bound LLAMA_ARG_CTX_SIZE by
# the row's context_ceiling rather than pin it to context_default, which is the
# depth freedom a profile exists to express.
#
# The run writes to a temporary preset file and a temporary configuration
# directory and moves both into place after the last row is emitted and the
# assembled file passes its own structural check. A refusal anywhere -- an
# unknown execution_policy, a malformed number, a ledger field diverging from
# the registry, a ledger whose every row withholds an executing policy -- leaves
# a previously generated preset tree exactly as it was, so an operator who
# regenerates after editing the ledger keeps a serving preset when the edit is
# wrong. The EXIT trap removes the temporaries on every path, so a failed run
# leaves neither a partial preset nor a stray directory.
#
# The generator's own check reads the assembled file back and requires each
# section to carry the keys its execution_policy calls for.
# qwen-capacity-policy.sh remains the authority on a complete admitted tuple,
# because that check needs the model registry, the quarantine registry, and the
# model root the launch resolves; remote/test-web-presets.sh drives the real
# policy over this generator's output for that reason.
#
# The generator writes one MCP server configuration per emitting profile at
# <output-dir>/web-mcp-configs/<profile_id>.json and points that profile's
# LLAMA_ARG_MCP_SERVERS_CONFIG at it. Per-profile budgets are what make the
# files differ: max_results, max_fetches, and max_chars_per_fetch are ledger
# columns, so one shared configuration would serve every profile the widest
# row's budget. QWEN_WEB_MCP_SERVER names the server program and carries no
# default, because a tool-bearing section misconfigured by omission is the
# state the requirement exists to prevent.
#
# A generated configuration carries key-file paths and never key contents. The
# MCP server reads the file itself, so the path is the whole grant the
# configuration needs to express, and a preset file that persists in
# $HOME/qwen-webui-state stays free of credential material. QWEN_WEB_SEARCH_AUTH
# is written as `required` rather than read from the environment, since the
# configuration a guarded generator emits is the one that authenticates.
#
# Paths reach the configuration as JSON string values, so a path holding a
# double quote or a backslash refuses the run rather than emitting a file whose
# escaping decides what the server reads.
#
# execution_policy decides whether a row emits at all and what it emits, because
# it names what is authorized now where web_mode names the intended path.
# `refused` emits nothing and prints the skipped profile, which is the state
# every checked-in row carries: tool-08 in
# evidence/model-admission/vision-and-tool-sweep.md carried an injected
# instruction into the tool call on all six measured checkpoints.
# `validator-gated` emits a tool-bearing section only under
# QWEN_WEB_AUTHORIZER_READY=1, the marker asserting that a runtime comparing
# emitted tool arguments against the user's own authorization exists and runs;
# absent that marker the row is skipped exactly as a refused row is.
# `ui-mediated` emits a section carrying no LLAMA_ARG_MCP_SERVERS_CONFIG,
# because the web UI performs the retrieval and the server reaches no network.
# Any other value stops the run: the ledger states a policy the generator has
# no rule for, which is a data error rather than a row to skip.
#
# No environment variable converts a `refused` row into a network-capable
# profile. The override that exists admits an unvalidated depth, which is a
# capacity claim; an execution grant is a security boundary and the ledger is
# its only authority.
#
# A run that emits zero sections fails rather than writing a section-free file.
# qwen-capacity-policy.sh refuses a preset carrying no model section, so an
# empty file defers the same refusal to launch time and reports it as a router
# fault instead of naming the ledger rows that withheld every section.
#
# remote/models.tsv is the authority for validated_filled_depth,
# vision_allowed, and tool_selection, and the ledger repeats all three so a
# reader sees one row whole. A copy that drifts from its authority is worse than
# an absent field, because the ledger would state a depth or a vision grant the
# runtime never honours, so the generator compares each against the registry row
# and stops on divergence. vision_allowed reads the projector column, where
# `required` is yes and `none` is no; tool_selection reads raw_tool_selection,
# the graded score unaided by any execution guard.
#
# A profile_id names an INI section, an MCP configuration file, and a served
# alias, so it is restricted to a leading alphanumeric followed by
# alphanumerics, underscores, and hyphens. A path separator or a `..` component
# would place the configuration outside the temporary tree and overwrite an
# unrelated JSON file before the run's final validation, and a bracket or a
# newline would spell a section header the preset reader parses differently
# than the generator wrote it. Two rows sharing one profile_id write two
# sections of one name and one configuration file that the second row's budgets
# own, so the ledger carries each id once and the run stops on a repeat.
#
# Every numeric field is validated before it is compared. A shell numeric
# comparison against a malformed operand raises an error the surrounding
# `2>/dev/null` would swallow, leaving the test false and admitting the row, so
# a depth field holding a typo would read as within bounds. `-` is the one
# admitted non-numeric value and it stands only where the registry defines it as
# the unmeasured state, which is validated_filled_depth; every other field
# requires a canonical positive decimal integer, since a leading zero makes two
# spellings of one depth and the runtime builds exact string tuple keys.
#
# The generator refuses a profile whose model_id is not tiered production or
# candidate, and refuses a profile whose context exceeds the registry row's
# context_ceiling: a context above the depth the policy admits requests an
# allocation the row was never measured to support.
#
# Unknown is not permission. The default rule is context <= numeric
# validated_filled_depth, so a `-` field, which states that no depth has been
# filled and decoded on that row, refuses the profile exactly as an
# over-numeric context does. QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 admits a
# profile that fails that rule regardless of the model_id's own tier -- a
# production-tiered model is exactly the one an experimental web profile
# should be able to run. What the override withholds is the emitted
# profile's own claim to that tier: the section carries no `default` tag,
# carries `experimental` in `tags`, the run prints a stderr line naming the
# unknown state or the numeric gap, and the output file's head carries the
# marker `# qwen-web-presets: unvalidated-depth-override`, mirroring how
# build-router-presets.sh records QWEN_ROUTER_INCLUDE_QUARANTINE in its own
# preamble so a later reader can force the listener to loopback the same way
# qwen-capacity-policy.sh does for an exposed quarantine section.

if [ "$#" -ne 1 ]; then
    printf 'usage: %s OUTPUT_INI\n' "$0" >&2
    printf 'model registry comes from QWEN_MODEL_REGISTRY, default remote/models.tsv\n' >&2
    printf 'web profile ledger comes from QWEN_WEB_PROFILES, default remote/web-profiles.tsv\n' >&2
    printf 'model root comes from QWEN_MODEL_ROOT, default $HOME/models\n' >&2
    printf 'MCP server program path is required in QWEN_WEB_MCP_SERVER\n' >&2
    printf 'search key file path is required in QWEN_WEB_SEARCH_KEY_FILE\n' >&2
    printf 'optional QWEN_WEB_TOKEN_KEY_FILE, QWEN_WEB_STATE_DIR, QWEN_WEB_PROVIDER\n' >&2
    printf 'QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 admits an unknown or over-depth profile as experimental\n' >&2
    printf 'QWEN_WEB_AUTHORIZER_READY=1 asserts the argument-authorization validator runs, admitting validator-gated rows\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
web_profiles=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
output_ini=$1
allow_unvalidated_depth=${QWEN_WEB_ALLOW_UNVALIDATED_DEPTH:-0}
case $allow_unvalidated_depth in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_ALLOW_UNVALIDATED_DEPTH must be 0 or 1: %s\n' \
            "$allow_unvalidated_depth" >&2
        exit 2
        ;;
esac

authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
case $authorizer_ready in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_AUTHORIZER_READY must be 0 or 1: %s\n' \
            "$authorizer_ready" >&2
        exit 2
        ;;
esac

mcp_server_program=${QWEN_WEB_MCP_SERVER:-}
if [ -z "$mcp_server_program" ]; then
    printf 'QWEN_WEB_MCP_SERVER must name the MCP server program\n' >&2
    exit 1
fi
search_key_file=${QWEN_WEB_SEARCH_KEY_FILE:-}
if [ -z "$search_key_file" ]; then
    printf 'QWEN_WEB_SEARCH_KEY_FILE must name the provider key file path\n' >&2
    exit 1
fi
token_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
web_state_directory=${QWEN_WEB_STATE_DIR:-"${HOME:?}/qwen-webui-state/web-mcp"}
web_provider=${QWEN_WEB_PROVIDER:-exa}

# A JSON string value carries the path verbatim, so a quote or a backslash in it
# would change the parsed value. Refusing the character keeps the emitted file
# a faithful record of the path the operator named.
require_json_safe_path() {
    json_path_name=$1
    json_path_value=$2
    case $json_path_value in
        *'"'* | *'\'*)
            printf '%s holds a double quote or backslash, which JSON escaping would reinterpret: %s\n' \
                "$json_path_name" "$json_path_value" >&2
            exit 1
            ;;
    esac
}
require_json_safe_path QWEN_WEB_MCP_SERVER "$mcp_server_program"
require_json_safe_path QWEN_WEB_SEARCH_KEY_FILE "$search_key_file"
require_json_safe_path QWEN_WEB_STATE_DIR "$web_state_directory"
if [ -n "$token_key_file" ]; then
    require_json_safe_path QWEN_WEB_TOKEN_KEY_FILE "$token_key_file"
fi
case $web_provider in
    '' | *[!a-z0-9-]*)
        printf 'QWEN_WEB_PROVIDER must hold lowercase letters, digits, and hyphens: %s\n' \
            "$web_provider" >&2
        exit 1
        ;;
esac

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi
if [ ! -r "$web_profiles" ]; then
    printf 'web profile ledger is unreadable: %s\n' "$web_profiles" >&2
    exit 1
fi

output_directory=$(dirname -- "$output_ini")
mcp_config_directory=$output_directory/web-mcp-configs
output_ini_temporary=$output_ini.tmp.$$
mcp_config_directory_temporary=$mcp_config_directory.tmp.$$
mkdir -p "$output_directory"
trap 'rm -rf -- "$output_ini_temporary" "$mcp_config_directory_temporary"' \
    EXIT HUP INT TERM
rm -rf -- "$mcp_config_directory_temporary"
mkdir -p "$mcp_config_directory_temporary"

{
    printf '# Generated by remote/build-web-presets.sh from remote/web-profiles.tsv.\n'
    printf '# Edit remote/web-profiles.tsv and regenerate; edits here are overwritten.\n'
    printf '# qwen_web_presets=1\n'
    if [ "$allow_unvalidated_depth" = 1 ]; then
        printf '# qwen-web-presets: unvalidated-depth-override\n'
    fi
    printf '\n'
} >"$output_ini_temporary"

emitted=0

# A canonical positive decimal integer carries no leading zero and no sign.
# require_canonical_integer names the field and the profile on failure, so a
# malformed ledger or registry value stops the run where it is read rather than
# reaching a comparison that would coerce it.
require_canonical_integer() {
    require_field_name=$1
    require_field_value=$2
    require_sentinel=$3
    require_profile=$4
    if [ "$require_sentinel" = sentinel-admitted ] &&
        [ "$require_field_value" = '-' ]; then
        return 0
    fi
    case $require_field_value in
        '' | *[!0-9]*)
            printf 'profile %s carries non-numeric %s: %s\n' \
                "$require_profile" "$require_field_name" \
                "$require_field_value" >&2
            exit 1
            ;;
        0*)
            printf 'profile %s carries %s outside canonical positive decimal form: %s\n' \
                "$require_profile" "$require_field_name" \
                "$require_field_value" >&2
            exit 1
            ;;
    esac
}

# The profile_id becomes a path component, an INI section name, and the served
# alias. The vocabulary admits what all three read the same way, which also
# leaves `/`, `.`, `[`, `]`, and every control character outside it.
require_canonical_profile_id() {
    case $1 in
        '' | [!A-Za-z0-9]* | *[!A-Za-z0-9_-]*)
            printf 'profile_id %s lies outside the admitted vocabulary\n' "$1" >&2
            printf 'a profile_id starts with a letter or digit and holds letters, digits, underscores, and hyphens\n' >&2
            exit 1
            ;;
    esac
}

# One id per ledger. The seen list is a space-delimited string because the
# generator runs under POSIX sh, which holds no associative array.
seen_profile_ids=' '
require_unique_profile_id() {
    case $seen_profile_ids in
        *" $1 "*)
            printf 'ledger repeats profile_id %s\n' "$1" >&2
            printf 'two rows of one id write two sections of one name and one MCP configuration the second row owns\n' >&2
            exit 1
            ;;
    esac
    seen_profile_ids="$seen_profile_ids$1 "
}

# The ledger repeats three registry fields so a profile row reads whole, and the
# registry stays their authority. A divergence names the profile, the field, and
# both values, because either side may be the stale one and the reader decides.
require_ledger_matches_registry() {
    compare_field_name=$1
    compare_ledger_value=$2
    compare_registry_value=$3
    if [ "$compare_ledger_value" != "$compare_registry_value" ]; then
        printf 'profile %s carries %s %s where model %s carries %s\n' \
            "$profile_id" "$compare_field_name" "$compare_ledger_value" \
            "$model_id" "$compare_registry_value" >&2
        printf 'remote/models.tsv is the authority for this field; correct remote/web-profiles.tsv\n' >&2
        exit 1
    fi
}

registry_field() {
    registry_field_row=$1
    registry_field_name=$2
    printf '%s\n' "$registry_field_row" | sed -n "s/^$registry_field_name=//p"
}

while IFS='	' read -r profile_id model_id _web_mode context \
    ledger_validated_filled_depth max_results max_fetches max_chars_per_fetch \
    _multi_source vision_allowed tool_selection execution_policy; do
    case $profile_id in
        '#'* | '') continue ;;
    esac
    require_canonical_profile_id "$profile_id"
    require_unique_profile_id "$profile_id"

    require_canonical_integer context "$context" sentinel-refused "$profile_id"
    require_canonical_integer validated_filled_depth \
        "$ledger_validated_filled_depth" sentinel-admitted "$profile_id"
    require_canonical_integer max_results "$max_results" sentinel-refused \
        "$profile_id"
    require_canonical_integer max_fetches "$max_fetches" sentinel-refused \
        "$profile_id"
    require_canonical_integer max_chars_per_fetch "$max_chars_per_fetch" \
        sentinel-refused "$profile_id"

    case $execution_policy in
        refused)
            printf 'web_preset_skipped profile=%s execution_policy=refused\n' \
                "$profile_id" >&2
            continue
            ;;
        validator-gated)
            if [ "$authorizer_ready" != 1 ]; then
                printf 'web_preset_skipped profile=%s execution_policy=validator-gated authorizer=absent\n' \
                    "$profile_id" >&2
                continue
            fi
            ;;
        ui-mediated) ;;
        *)
            printf 'profile %s carries execution_policy %s, which is outside the vocabulary\n' \
                "$profile_id" "$execution_policy" >&2
            printf 'admitted values are refused, validator-gated, and ui-mediated\n' >&2
            exit 1
            ;;
    esac

    if ! registry_row=$("$script_directory/model-registry.sh" id "$model_id"); then
        printf 'profile %s names unknown model_id %s\n' "$profile_id" "$model_id" >&2
        exit 1
    fi

    model_file=$(registry_field "$registry_row" model_file)
    context_ceiling=$(registry_field "$registry_row" context_ceiling)
    cache_type_k=$(registry_field "$registry_row" cache_type_k)
    cache_type_v=$(registry_field "$registry_row" cache_type_v)
    flash_attention=$(registry_field "$registry_row" flash_attention)
    tier=$(registry_field "$registry_row" tier)
    batch=$(registry_field "$registry_row" batch)
    ubatch=$(registry_field "$registry_row" ubatch)
    registry_validated_filled_depth=$(registry_field "$registry_row" validated_filled_depth)

    require_canonical_integer context_ceiling "$context_ceiling" \
        sentinel-refused "$profile_id"
    require_canonical_integer batch "$batch" sentinel-refused "$profile_id"
    require_canonical_integer ubatch "$ubatch" sentinel-refused "$profile_id"
    require_canonical_integer registry_validated_filled_depth \
        "$registry_validated_filled_depth" sentinel-admitted "$profile_id"

    projector=$(registry_field "$registry_row" projector)
    raw_tool_selection=$(registry_field "$registry_row" raw_tool_selection)
    case $projector in
        required) registry_vision_allowed=yes ;;
        none) registry_vision_allowed=no ;;
        *)
            printf 'profile %s names model %s whose projector column reads %s, which is outside the vocabulary\n' \
                "$profile_id" "$model_id" "$projector" >&2
            exit 1
            ;;
    esac

    require_ledger_matches_registry validated_filled_depth \
        "$ledger_validated_filled_depth" "$registry_validated_filled_depth"
    require_ledger_matches_registry vision_allowed \
        "$vision_allowed" "$registry_vision_allowed"
    require_ledger_matches_registry tool_selection \
        "$tool_selection" "$raw_tool_selection"

    case $tier in
        production | candidate) ;;
        *)
            printf 'profile %s names model %s at tier %s, which is not production or candidate\n' \
                "$profile_id" "$model_id" "$tier" >&2
            exit 1
            ;;
    esac

    if [ "$context" -gt "$context_ceiling" ]; then
        printf 'profile %s requests context %s above %s ceiling %s\n' \
            "$profile_id" "$context" "$model_id" "$context_ceiling" >&2
        exit 1
    fi

    # Unknown is not permission: a `-` field and a numeric field the context
    # exceeds both fail the default rule. The override admits either state
    # from a model_id at any admitted tier; what it withholds is the
    # emitted section's own claim to that tier, via the experimental tag,
    # the withheld default tag, the stderr line, and the file-head marker
    # below.
    depth_state=validated
    if [ "$registry_validated_filled_depth" = '-' ]; then
        depth_state=unknown
    elif [ "$context" -gt "$registry_validated_filled_depth" ]; then
        depth_state=exceeded
    fi

    tags_suffix=
    if [ "$depth_state" != validated ]; then
        if [ "$allow_unvalidated_depth" != 1 ]; then
            if [ "$depth_state" = unknown ]; then
                printf 'profile %s requests context %s against %s validated_filled_depth unknown (-)\n' \
                    "$profile_id" "$context" "$model_id" >&2
            else
                printf 'profile %s requests context %s above %s validated_filled_depth %s\n' \
                    "$profile_id" "$context" "$model_id" "$registry_validated_filled_depth" >&2
            fi
            exit 1
        fi
        if [ "$depth_state" = unknown ]; then
            printf 'web_preset_warning profile=%s validated_filled_depth=unknown model=%s\n' \
                "$profile_id" "$model_id" >&2
        else
            depth_gap=$((context - registry_validated_filled_depth))
            printf 'web_preset_warning profile=%s validated_filled_depth_gap=%s model=%s\n' \
                "$profile_id" "$depth_gap" "$model_id" >&2
        fi
        tags_suffix=,experimental
    fi

    profile_mcp_config=$mcp_config_directory/$profile_id.json
    profile_mcp_config_temporary=$mcp_config_directory_temporary/$profile_id.json
    {
        printf '{\n'
        printf '  "mcpServers": {\n'
        printf '    "web": {\n'
        printf '      "command": "python3",\n'
        printf '      "args": [\n'
        printf '        "%s",\n' "$mcp_server_program"
        printf '        "--provider",\n'
        printf '        "%s"\n' "$web_provider"
        printf '      ],\n'
        printf '      "env": {\n'
        printf '        "QWEN_WEB_PROFILE": "%s",\n' "$profile_id"
        printf '        "QWEN_WEB_PROVIDER": "%s",\n' "$web_provider"
        printf '        "QWEN_WEB_MAX_RESULTS": "%s",\n' "$max_results"
        printf '        "QWEN_WEB_MAX_FETCHES": "%s",\n' "$max_fetches"
        printf '        "QWEN_WEB_MAX_CHARS_PER_FETCH": "%s",\n' \
            "$max_chars_per_fetch"
        printf '        "QWEN_WEB_SEARCH_AUTH": "required",\n'
        printf '        "QWEN_WEB_SEARCH_KEY_FILE": "%s",\n' "$search_key_file"
        if [ -n "$token_key_file" ]; then
            printf '        "QWEN_WEB_TOKEN_KEY_FILE": "%s",\n' "$token_key_file"
        fi
        printf '        "QWEN_WEB_STATE_DIR": "%s"\n' "$web_state_directory"
        printf '      }\n'
        printf '    }\n'
        printf '  }\n'
        printf '}\n'
    } >"$profile_mcp_config_temporary"

    model_path=$model_root/$model_file

    {
        printf '[%s]\n' "$profile_id"
        printf 'LLAMA_ARG_MODEL = %s\n' "$model_path"
        printf 'LLAMA_ARG_ALIAS = %s\n' "$profile_id"
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$context"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$cache_type_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$cache_type_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$flash_attention"
        printf 'LLAMA_ARG_BATCH = %s\n' "$batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$ubatch"
        if [ "$execution_policy" != ui-mediated ]; then
            printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$profile_mcp_config"
        fi
        printf 'LLAMA_ARG_TAGS = web-research,%s%s\n' \
            "$execution_policy" "$tags_suffix"
        printf '\n'
    } >>"$output_ini_temporary"

    emitted=$((emitted + 1))
done <"$web_profiles"

# The assembled file is read back before it lands, so a section missing a key
# the emission loop should have written stops the run rather than reaching the
# launch. Sections are counted here too, which catches a row that emitted a
# header and no body.
verify_assembled_sections() {
    awk -v expected_sections="$emitted" '
        function finish_section() {
            if (section == "") return
            sections++
            for (required_index = 1; required_index <= required_count; required_index++) {
                if (!(seen_key[required_keys[required_index]])) {
                    printf "assembled section %s omits %s\n", section, \
                        required_keys[required_index] > "/dev/stderr"
                    rejected = 1
                }
            }
            if (tags_value ~ /(^|,)validator-gated(,|$)/ &&
                !seen_key["LLAMA_ARG_MCP_SERVERS_CONFIG"]) {
                printf "assembled section %s is validator-gated and omits LLAMA_ARG_MCP_SERVERS_CONFIG\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            if (tags_value ~ /(^|,)ui-mediated(,|$)/ &&
                seen_key["LLAMA_ARG_MCP_SERVERS_CONFIG"]) {
                printf "assembled section %s is ui-mediated and carries LLAMA_ARG_MCP_SERVERS_CONFIG\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            delete seen_key
            tags_value = ""
        }
        BEGIN {
            required_count = split("LLAMA_ARG_MODEL LLAMA_ARG_ALIAS " \
                "LLAMA_ARG_CTX_SIZE LLAMA_ARG_CACHE_TYPE_K " \
                "LLAMA_ARG_CACHE_TYPE_V LLAMA_ARG_FLASH_ATTN " \
                "LLAMA_ARG_BATCH LLAMA_ARG_UBATCH LLAMA_ARG_TAGS", \
                required_keys, " ")
        }
        /^[[:space:]]*($|[#;])/ { next }
        /^[[:space:]]*\[/ {
            finish_section()
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            next
        }
        {
            if (section == "") next
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            seen_key[key] = 1
            if (key == "LLAMA_ARG_TAGS") tags_value = value
        }
        END {
            finish_section()
            if (sections != expected_sections) {
                printf "assembled file carries %d sections where %d emitted\n", \
                    sections, expected_sections > "/dev/stderr"
                rejected = 1
            }
            exit rejected
        }
    ' "$output_ini_temporary"
}

if [ "$emitted" -eq 0 ]; then
    printf 'every profile in %s withholds an executing policy, so no section emits\n' \
        "$web_profiles" >&2
    printf 'a validator-gated row emits under QWEN_WEB_AUTHORIZER_READY=1; a refused row emits under no setting\n' >&2
    exit 1
fi

if ! verify_assembled_sections; then
    printf 'the assembled preset file is incomplete, so the previous %s stands\n' \
        "$output_ini" >&2
    exit 1
fi

# Both moves happen after every row and the assembled file pass, so a failure
# above leaves the previous preset tree untouched. The configuration directory
# is replaced rather than merged, which removes the files of a profile the
# ledger no longer carries.
rm -rf -- "$mcp_config_directory"
mv -- "$mcp_config_directory_temporary" "$mcp_config_directory"
mv -- "$output_ini_temporary" "$output_ini"
trap - EXIT HUP INT TERM

printf 'web_presets=written path=%s profiles=%s mcp_configs=%s\n' \
    "$output_ini" "$emitted" "$mcp_config_directory"
