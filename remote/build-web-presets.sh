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
# LLAMA_ARG_MCP_SERVERS_CONFIG names the MCP server configuration a web-enabled
# section runs against. No default path is safe to assume for a tool-bearing
# section, so QWEN_WEB_MCP_CONFIG is required and its absence refuses the run
# rather than emitting a section with tool access misconfigured by omission.
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
    printf 'mcp config path is required in QWEN_WEB_MCP_CONFIG\n' >&2
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

mcp_servers_config=${QWEN_WEB_MCP_CONFIG:-}
if [ -z "$mcp_servers_config" ]; then
    printf 'QWEN_WEB_MCP_CONFIG must name the MCP servers config path\n' >&2
    exit 1
fi

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi
if [ ! -r "$web_profiles" ]; then
    printf 'web profile ledger is unreadable: %s\n' "$web_profiles" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$output_ini")"

{
    printf '# Generated by remote/build-web-presets.sh from remote/web-profiles.tsv.\n'
    printf '# Edit remote/web-profiles.tsv and regenerate; edits here are overwritten.\n'
    printf '# qwen_web_presets=1\n'
    if [ "$allow_unvalidated_depth" = 1 ]; then
        printf '# qwen-web-presets: unvalidated-depth-override\n'
    fi
    printf '\n'
} >"$output_ini"

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

while IFS='	' read -r profile_id model_id web_mode context \
    ledger_validated_filled_depth max_results max_fetches max_chars_per_fetch \
    _multi_source vision_allowed tool_selection execution_policy; do
    case $profile_id in
        '#'* | '') continue ;;
    esac

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
            printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$mcp_servers_config"
        fi
        printf 'LLAMA_ARG_TAGS = web-research,%s%s\n' \
            "$execution_policy" "$tags_suffix"
        printf '\n'
    } >>"$output_ini"

    emitted=$((emitted + 1))
done <"$web_profiles"

if [ "$emitted" -eq 0 ]; then
    printf 'every profile in %s withholds an executing policy, so no section emits\n' \
        "$web_profiles" >&2
    printf 'a validator-gated row emits under QWEN_WEB_AUTHORIZER_READY=1; a refused row emits under no setting\n' >&2
    exit 1
fi

printf 'web_presets=written path=%s profiles=%s\n' "$output_ini" "$emitted"
