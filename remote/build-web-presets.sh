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
# <output-dir>/web-mcp-configs-<version>/<profile_id>.json and points that
# profile's LLAMA_ARG_MCP_SERVERS_CONFIG at it. The version is a digest of the
# emitted file names and their contents, so a directory of that name holds
# exactly those files and any change writes a new directory and leaves the old
# one whole. The digest reads the written files rather than the inputs that
# produced them because the emitted set follows the weights and projectors this
# machine holds as well as the two authorities, and fetching a checkpoint
# between runs adds a configuration without touching either registry. A section
# carries a marker where the directory belongs until the land step resolves it,
# since the name exists only once the last row has emitted. What the versioning
# buys:
# qwen-launch.sh snapshots the INI alone, its sections keep naming the paths they
# were generated with, and llama-server reads an MCP configuration when its child
# starts, so replacing a stable directory would hand a running session new
# provider credentials and budgets, or remove a file it still names, without
# changing the guarded preset hash. Retired directories stay on disk, because
# removing one asks which sessions still name it and no launcher owns that
# answer. Per-profile budgets are what make the
# files differ: max_results, max_fetches, and max_chars_per_fetch are ledger
# columns, so one shared configuration would serve every profile the widest
# row's budget. QWEN_WEB_MCP_SERVER names the server program and carries no
# default, because a tool-bearing section misconfigured by omission is the state
# the requirement exists to prevent. The requirement runs at the first row that
# writes a configuration rather than at startup, so a ledger of refused and
# ui-mediated rows -- which name no configuration and reach no network --
# generates from the ledger alone, and the refusal still names the profile whose
# section would have carried the omission.
#
# A generated configuration carries key-file paths and never key contents. The
# MCP server reads the file itself, so the path is the whole grant the
# configuration needs to express, and a preset file that persists in
# $HOME/qwen-webui-state stays free of credential material. QWEN_WEB_SEARCH_AUTH
# is written as `required` rather than read from the environment, since the
# configuration a guarded generator emits is the one that authenticates.
#
# Paths reach the configuration as JSON string values, so the run refuses a path
# holding any character JSON leaves outside a raw string. RFC 8259 section 7
# admits unescaped characters above U+001F apart from the quotation mark and the
# reverse solidus, so a POSIX path carrying a newline, a tab, or another control
# character would emit a file no JSON parser accepts, which llama-server reports
# as an MCP child startup failure long after the listener is up and the
# generator's own INI check never sees.
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
# remote/image-profiles.tsv is the second execution grant this generator reads
# and it takes the same two rules: a `refused` row emits nothing under every
# setting, which is what every checked-in row carries, and a `validator-gated`
# row emits only under QWEN_WEB_AUTHORIZER_READY=1. An emitting image row adds
# an `image` server to every section's configuration, naming
# remote/image-mcp/server.py with the section's own profile_id as
# QWEN_IMAGE_LANGUAGE_PROFILE, because the grant binds the language profile and
# the image profile together. It also names QWEN_IMAGE_PROFILES_JSON, the
# validated parameter file image-service.py runs a job under, because the child
# states that profile's geometry and ceilings in its own tool schema and the
# advertised maximum and the enforced maximum are then one number. Its
# timeout_ms of 360000 sits above the image
# service's 330 s and the runtime's 300 s, so a stalled generation is ended by
# the process that owns it.
#
# An image row's `review_model` names the vision checkpoint that reviews what
# that row generates, and the generator emits one review-only section for it.
# The page reads `GET /v1/models` for its roster and asks `GET /props?model=`
# which row reports a vision modality, so a second section is what puts the
# Review button on an artifact card; a preset holding the language section
# alone leaves the review to remote/image-review.py on a second launch. The
# section is named for the model_id rather than for a profile, because the
# reviewer is a checkpoint at its own validated tuple rather than a served
# policy: remote/models.tsv supplies the depth, the cache triple, the flash
# setting, and the submission geometry, remote/validated-tuples.tsv is required
# to carry a `validated` row at that exact tuple with `projector_state=loaded`,
# and select-projector.sh resolves the projector inside the model file's own
# directory. It names no LLAMA_ARG_MCP_SERVERS_CONFIG and carries the tags
# `vision-review,review-only`, so it holds no execution grant of any kind and
# the review request the page posts offers the model no tool.
#
# No environment variable converts a `refused` row into a network-capable
# profile. The override that exists admits an unvalidated depth, which is a
# capacity claim; an execution grant is a security boundary and the ledger is
# its only authority.
#
# A row whose registry projector reads `required` carries LLAMA_ARG_MMPROJ in its
# own section, because router mode reads each section's key and leaves the
# standalone QWEN_MMPROJ path unread; a vision profile emitted without it loads
# its text GGUF alone and answers an image request from nothing while the ledger
# grants it vision. remote/select-projector.sh resolves the file inside the model
# file's own directory, where a foreign projector of matching dimensions would
# load cleanly and place image tokens the language model reads nothing from, and
# it prints nothing for both the absent and the ambiguous case, so an empty
# result is the discriminator and the profile is skipped and named.
#
# A row whose weights are absent from the model root is skipped and named. Router
# preflight rejects a section whose model file is absent before the single-model
# fetch path runs, so emitting one unfetched checkpoint would block every web
# profile on a machine that holds the rest. The skip counts separately from the
# policy skips, which is what lets the zero-section refusal name absent weights
# rather than reporting a ledger that withheld every executing policy.
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
# Every row meets the registry, the tier rule, and the ceiling rule before the
# emission gate reads its execution_policy. The ledger is one claimed policy
# document, so a row that emits nothing today still states a depth and a vision
# grant a reader trusts, and validating the emitting rows alone left checked-in
# drift standing until a later edit to one row's execution_policy turned a
# previously successful ledger into an error.
#
# multi_source and max_fetches state one retrieval budget twice, and the
# generator holds them as a biconditional: multi_source reads yes exactly where
# max_fetches exceeds one. The emitted MCP configuration carries max_fetches
# alone, so a `no` row above one fetch grants multi-source retrieval the ledger
# denies while the ledger still reads as the policy authority.
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
    printf 'model root comes from QWEN_MODEL_ROOT, default models/ under the runtime root (QWEN_HOME)\n' >&2
    printf 'MCP server program path is required in QWEN_WEB_MCP_SERVER\n' >&2
    printf 'QWEN_WEB_PROVIDER exa (default) requires a search key file path in QWEN_WEB_SEARCH_KEY_FILE, emitted as QWEN_WEB_EXA_KEY_FILE\n' >&2
    printf 'QWEN_WEB_PROVIDER fake requires a fixture file path in QWEN_WEB_FAKE_FIXTURES, emitted unchanged, and reads no search key file\n' >&2
    printf 'QWEN_WEB_PROVIDER searxng reads the instance URL and the category policy from the profile row and reads no search key file\n' >&2
    printf 'optional QWEN_WEB_SEARXNG_LANGUAGE, QWEN_WEB_SEARXNG_SAFESEARCH, QWEN_WEB_SEARXNG_ALLOW_REMOTE\n' >&2
    printf 'optional QWEN_WEB_TOKEN_KEY_FILE, QWEN_WEB_STATE_DIR\n' >&2
    printf 'QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=1 admits an unknown or over-depth profile as experimental\n' >&2
    printf 'QWEN_WEB_AUTHORIZER_READY=1 asserts the argument-authorization validator runs, admitting validator-gated rows\n' >&2
    printf 'image profile ledger comes from QWEN_IMAGE_PROFILES, default remote/image-profiles.tsv\n' >&2
    printf 'a validator-gated image row adds an image server to every emitted section under QWEN_WEB_AUTHORIZER_READY=1\n' >&2
    printf 'that row requires QWEN_IMAGE_MCP_SERVER (remote/image-mcp/server.py), QWEN_IMAGE_TOKEN_KEY_FILE, QWEN_IMAGE_STATE_DIR, QWEN_IMAGE_SERVICE_SOCKET, QWEN_IMAGE_PROFILES_JSON\n' >&2
    printf 'QWEN_IMAGE_PROFILES_JSON names the validated parameter file whose geometry and ceilings the MCP tool schema states\n' >&2
    printf 'optional QWEN_IMAGE_MCP_TIMEOUT_MS, default 360000\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# The row rules and the MCP configuration writer live in one file, because
# build-router-presets.sh emits the same sections into the merged preset and a
# second copy would let the two generators disagree on what a ledger row means.
# shellcheck source=remote/web-preset-lib.sh
. "$script_directory/web-preset-lib.sh"
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
web_profiles=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
model_root=${QWEN_MODEL_ROOT:-"$qwen_home_models"}
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
search_key_file=${QWEN_WEB_SEARCH_KEY_FILE:-}
fake_fixtures=${QWEN_WEB_FAKE_FIXTURES:-}
searxng_language=${QWEN_WEB_SEARXNG_LANGUAGE:-}
searxng_safesearch=${QWEN_WEB_SEARXNG_SAFESEARCH:-}
searxng_allow_remote=${QWEN_WEB_SEARXNG_ALLOW_REMOTE:-}
token_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
web_state_directory=${QWEN_WEB_STATE_DIR:-"$qwen_home_state/web-mcp"}
# The checked-in profile ledger is the default provider authority. An explicit
# environment value is an assertion that every row below must match, not a
# second default that can drift from the file the generator consumes.
web_provider=${QWEN_WEB_PROVIDER:-}
if [ -z "$web_provider" ]; then
    if [ ! -r "$web_profiles" ]; then
        printf 'web profile ledger is unreadable: %s\n' "$web_profiles" >&2
        exit 1
    fi
    web_provider_values=$(
        awk -F '\t' '!/^#/ && NF { print $13 }' "$web_profiles" |
            LC_ALL=C sort -u
    )
    case $web_provider_values in
        '' | *'
'*)
            printf 'web profile ledger must name exactly one provider: %s\n' \
                "$web_profiles" >&2
            exit 1
            ;;
        *) web_provider=$web_provider_values ;;
    esac
fi
# llama-server reads timeout_ms from the MCP configuration as the per-call
# deadline for the child (server-mcp.cpp, server_mcp_server_config). The
# three deadlines on a call are ordered so the innermost fires first: the
# provider request times out at 20 s inside server.py, this per-call limit
# at 30 s, and the router's proxy read timeout at the 3600 s llama-server
# default, so a slow provider answers with the child's own error text rather
# than the router abandoning a call the child is still executing.
mcp_timeout_ms=${QWEN_WEB_MCP_TIMEOUT_MS:-30000}
case $mcp_timeout_ms in
    '' | 0* | *[!0-9]*)
        printf 'QWEN_WEB_MCP_TIMEOUT_MS must be a positive decimal integer: %s\n' \
            "$mcp_timeout_ms" >&2
        exit 2
        ;;
esac

# The image lane reaches the device rather than the network, and its deadline
# is the generation's rather than a provider request's: the runtime is bounded
# at 300 s, image-service.py at 330 s, and this per-call limit at 360 s, so a
# stalled generation is ended by the process that owns it. remote/image-mcp
# reads QWEN_IMAGE_MCP_TIMEOUT_S from the same emitted configuration, and
# qwen-image-launch.sh verifies the whole stack before it starts anything.
image_profiles=${QWEN_IMAGE_PROFILES:-$script_directory/image-profiles.tsv}
image_quarantine=${QWEN_IMAGE_QUARANTINE:-$script_directory/image-quarantine.tsv}
image_mcp_server=${QWEN_IMAGE_MCP_SERVER:-}
image_token_key_file=${QWEN_IMAGE_TOKEN_KEY_FILE:-}
# image-service.py always derives its images directory and its
# image-service.sock name from --state-dir, and qwen-webui-session.sh always
# passes the session's own state directory there regardless of what this
# generator was told, so the default here follows QWEN_WEBUI_STATE_DIRECTORY
# rather than assuming $HOME: a deployment with a nondefault session state
# directory then generates a preset the launch verifier's rejoin admits by
# default, without needing QWEN_IMAGE_STATE_DIR named explicitly. An explicit
# QWEN_IMAGE_STATE_DIR or QWEN_IMAGE_SERVICE_SOCKET still overrides the
# default; the runtime never reads either, so a value that diverges from the
# launch's own derivation is caught at launch rather than served.
image_state_directory=${QWEN_IMAGE_STATE_DIR:-"${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}/images"}
image_service_socket=${QWEN_IMAGE_SERVICE_SOCKET:-$image_state_directory/image-service.sock}
# The MCP child states the served profile's geometry and ceilings in its own
# tool schema, and it reads them from the parameter file image-service.py runs
# a job under, so the maximum a model is offered and the maximum the service
# enforces are one number. The path travels; the file is read by the child at
# every start, which is what keeps a preset that persists across a registry
# edit from advertising a ceiling the ledger has since lowered.
image_profiles_json=${QWEN_IMAGE_PROFILES_JSON:-}
image_mcp_timeout_ms=${QWEN_IMAGE_MCP_TIMEOUT_MS:-360000}
case $image_mcp_timeout_ms in
    '' | 0* | *[!0-9]*)
        printf 'QWEN_IMAGE_MCP_TIMEOUT_MS must be a positive decimal integer: %s\n' \
            "$image_mcp_timeout_ms" >&2
        exit 2
        ;;
esac
# emit_web_mcp_configuration converts this to QWEN_IMAGE_MCP_TIMEOUT_S by
# integer division at /1000, so a value that is not an exact multiple of 1000
# would let generation succeed while read-image-mcp-server.py's own
# millisecond/second agreement check then refuses the configuration it wrote.
case $((image_mcp_timeout_ms % 1000)) in
    0) ;;
    *)
        printf 'QWEN_IMAGE_MCP_TIMEOUT_MS must be an exact multiple of 1000 (whole seconds): %s\n' \
            "$image_mcp_timeout_ms" >&2
        exit 2
        ;;
esac



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

# Each generated preset names its exact policy authority. The absolute path
# prevents a later working directory from selecting another file
# with the same relative spelling, and the digest binds every row rather than
# only the emitted profile's execution_policy fields.
web_profiles_directory=$(dirname -- "$web_profiles")
web_profiles_directory=$(CDPATH='' cd -- "$web_profiles_directory" && pwd)
web_profiles=$web_profiles_directory/$(basename -- "$web_profiles")
case $web_profiles in
    *[[:cntrl:]]*)
        printf 'web profile ledger path carries a control character: %s\n' \
            "$web_profiles" >&2
        exit 1
        ;;
esac
web_profiles_identity=$(sha256sum -- "$web_profiles")
web_profiles_sha256=${web_profiles_identity%% *}

# The image lane is a second execution grant over the same sections, so it is
# resolved once before any section emits. The emission rule mirrors the web one
# exactly -- `refused` emits nothing under every setting and every checked-in
# row carries it, `validator-gated` emits only under QWEN_WEB_AUTHORIZER_READY=1
# -- because an image generation reaches the device through the same
# argument-authorizing runtime a search reaches the network through, and
# remote/web-preset-lib.sh holds that rule for both generators.
resolve_image_profile
bind_image_profiles_identity

# A persisted review section remains authorized only while the exact
# validated-tuple ledger used to generate it remains unchanged. Canonicalize
# and bind that authority before consulting model-registry.sh, so both the
# emitted marker and the tuple query name the same file.
validated_tuples=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}
validated_tuples_directory=$(dirname -- "$validated_tuples")
validated_tuples_directory=$(CDPATH='' cd -- "$validated_tuples_directory" && pwd)
validated_tuples=$validated_tuples_directory/$(basename -- "$validated_tuples")
if [ ! -r "$validated_tuples" ]; then
    printf 'validated-tuple ledger is unreadable: %s\n' "$validated_tuples" >&2
    exit 1
fi
validated_tuples_identity=$(sha256sum -- "$validated_tuples")
validated_tuples_sha256=${validated_tuples_identity%% *}
QWEN_VALIDATED_TUPLES=$validated_tuples
export QWEN_VALIDATED_TUPLES

# Each section's checkpoint count is a separate model-registry.sh query, so an
# edit between two of them would write one section from the old ledger and the
# next from the new one, and the launch rejoins every section to whichever
# ledger it then reads. The path is canonicalized and bound the way the tuple
# ledger is, and its identity is compared again before the file lands.
ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
ctx_checkpoint_ledger_directory=$(dirname -- "$ctx_checkpoint_ledger")
ctx_checkpoint_ledger_directory=$(CDPATH='' cd -- "$ctx_checkpoint_ledger_directory" && pwd)
ctx_checkpoint_ledger=$ctx_checkpoint_ledger_directory/$(basename -- "$ctx_checkpoint_ledger")
if [ ! -r "$ctx_checkpoint_ledger" ]; then
    printf 'context checkpoint ledger is unreadable: %s\n' \
        "$ctx_checkpoint_ledger" >&2
    exit 1
fi
# One copy is the whole run's ledger: the digest names the copy's bytes and
# every section's count is resolved from rows read out of that same copy, so
# the emitted file states one ledger state by construction. Live reads of the
# source cannot state that, since a file that changed and changed back between
# the digest and a query answers both digests consistently while the query in
# the middle returns the state neither saw. The comparison before the file
# lands then measures the source against the copy.
ctx_checkpoint_snapshot=$(mktemp "${TMPDIR:-/tmp}/.ctx-checkpoints.XXXXXX")
cleanup_ctx_checkpoint_snapshot() {
    rm -f -- "$ctx_checkpoint_snapshot"
}
trap 'cleanup_ctx_checkpoint_snapshot' EXIT HUP INT TERM
cp -- "$ctx_checkpoint_ledger" "$ctx_checkpoint_snapshot"
ctx_checkpoint_ledger_identity=$(sha256sum -- "$ctx_checkpoint_snapshot")
ctx_checkpoint_ledger_sha256=${ctx_checkpoint_ledger_identity%% *}
QWEN_CTX_CHECKPOINT_LEDGER=$ctx_checkpoint_snapshot
export QWEN_CTX_CHECKPOINT_LEDGER
if ! ctx_checkpoint_rows=$("$script_directory/model-registry.sh" \
    ctx-checkpoints); then
    printf 'context checkpoint ledger refused: %s\n' \
        "$ctx_checkpoint_ledger" >&2
    exit 1
fi
ledger_ctx_checkpoints() {
    printf '%s\n' "$ctx_checkpoint_rows" | awk -F'\t' -v id="$1" '
        $1 == id { count = $2; matched = 1 }
        END { print matched ? count : 0 }
    '
}

if [ -n "$image_profile_id" ]; then
    require_image_mcp_inputs
fi

# The review section is resolved before any section emits, for the reason the
# image profile is: it is one more claim over the whole file, and a run that
# discovered it unusable after writing half the sections would land a preset
# whose Review button reaches a section that never emitted. `-` leaves the
# review to a second launch, which is what every checked-in row reads. This file
# is the one an image launch serves, so an unusable reviewer ends the run rather
# than being withheld: two sections are the whole preset and the operator asked
# for both.
if ! resolve_image_review_model; then
    exit 1
fi

# A section's MCP configuration path is read by qwen-web-launch.sh and by the
# llama-server child, each from its own working directory, so the generator
# resolves the output directory absolutely before it embeds the name. A relative
# OUTPUT_INI such as the documented `web-presets.ini` otherwise names
# `./web-mcp-configs-<version>/<profile_id>.json`, which resolves elsewhere or
# not at all for every later reader.
output_directory=$(dirname -- "$output_ini")
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
output_ini=$output_directory/$(basename -- "$output_ini")

# The configuration directory is named for a digest of the files it holds, which
# the run knows once the last row has emitted. Sections therefore carry
# QWEN_WEB_MCP_CONFIG_DIRECTORY_MARKER where the directory belongs, and the land
# step rewrites the marker to the resolved path.
mcp_config_directory_marker=@QWEN_WEB_MCP_CONFIG_DIRECTORY@
mcp_config_directory=
output_ini_temporary=$output_ini.tmp.$$
mcp_config_directory_temporary=$output_directory/web-mcp-configs.tmp.$$
trap 'cleanup_ctx_checkpoint_snapshot; rm -rf -- "$output_ini_temporary" \
    "$output_ini_temporary.resolved" \
    "$mcp_config_directory_temporary"' EXIT HUP INT TERM
rm -rf -- "$mcp_config_directory_temporary"
mkdir -p "$mcp_config_directory_temporary"

{
    printf '# Generated by remote/build-web-presets.sh from remote/web-profiles.tsv.\n'
    printf '# Edit remote/web-profiles.tsv and regenerate; edits here are overwritten.\n'
    printf '# qwen_web_presets=1\n'
    printf '# qwen_web_profiles_path=%s\n' "$web_profiles"
    printf '# qwen_web_profiles_sha256=%s\n' "$web_profiles_sha256"
    printf '# qwen_web_provider=%s\n' "$web_provider"
    printf '# qwen_image_profiles_path=%s\n' "$image_profiles"
    printf '# qwen_image_profiles_sha256=%s\n' "$image_profiles_sha256"
    printf '# qwen_image_profile=%s\n' "${image_profile_id:--}"
    printf '# qwen_image_model=%s\n' "${image_profile_model:--}"
    printf '# qwen_image_mcp_timeout_ms=%s\n' "$image_mcp_timeout_ms"
    printf '# qwen_image_review_model=%s\n' "${image_profile_review_model:--}"
    printf '# qwen_image_review_section=%s\n' "${review_section:--}"
    printf '# qwen_validated_tuples_path=%s\n' "$validated_tuples"
    printf '# qwen_validated_tuples_sha256=%s\n' "$validated_tuples_sha256"
    if [ "$allow_unvalidated_depth" = 1 ]; then
        printf '# qwen-web-presets: unvalidated-depth-override\n'
    fi
    printf '\n'
} >"$output_ini_temporary"

emitted=0
skipped_absent_weights=0
skipped_unresolved_projector=0


while profile_id=; IFS='	' read -r profile_id model_id _web_mode context \
    ledger_validated_filled_depth max_results max_fetches max_chars_per_fetch \
    multi_source vision_allowed tool_selection execution_policy \
    row_provider primary_category fallback_category minimum_results \
    row_searxng_url || \
    [ -n "$profile_id" ]; do
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

    require_multi_source_matches_fetches "$multi_source" "$max_fetches"
    require_search_policy "$profile_id" "$row_provider" "$primary_category" \
        "$fallback_category" "$minimum_results" "$max_results" \
        "$row_searxng_url"

    case $execution_policy in
        refused | validator-gated | ui-mediated) ;;
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
    # The checkpoint count is the row's rather than the profile's, and it comes
    # from the snapshot the whole run emits against.
    profile_ctx_checkpoints=$(ledger_ctx_checkpoints "$model_id")

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

    # The registry join, the copied-field comparison, the tier rule, and the
    # ceiling rule above run for every row, because the ledger is one claimed
    # policy document and a stale field states a depth or a vision grant the
    # runtime never honours whether or not that row emits today. The emission
    # gate runs here, so changing one row's execution_policy turns a validated
    # ledger into an emitting one rather than into an error.
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
    esac

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

    # Router preflight rejects a section whose model file is absent before the
    # single-model fetch path runs, so one unfetched checkpoint would block
    # every web profile of a machine that holds the rest. The row is skipped and
    # named here, the shape build-router-presets.sh uses, and the profiles whose
    # weights are present still serve.
    model_path=$model_root/$model_file
    if [ ! -f "$model_path" ]; then
        printf 'web_preset_skipped profile=%s reason=weights_absent path=%s\n' \
            "$profile_id" "$model_path" >&2
        skipped_absent_weights=$((skipped_absent_weights + 1))
        continue
    fi

    # Router mode reads a section's own LLAMA_ARG_MMPROJ and leaves the
    # standalone QWEN_MMPROJ path unread, so a vision profile whose section
    # omits the key loads its text GGUF alone and answers an image request from
    # nothing. select-projector.sh resolves the projector inside the model
    # file's own directory and prints nothing for both the absent and the
    # ambiguous case, so an empty result rather than its exit status is what
    # discriminates, and the profile is skipped and named rather than emitted
    # text-only against a ledger that grants it vision.
    profile_projector_path=
    if [ "$projector" = required ]; then
        profile_projector_path=$("$script_directory/select-projector.sh" \
            "$model_path" 2>/dev/null) || profile_projector_path=''
        if [ -z "$profile_projector_path" ]; then
            printf 'web_preset_skipped profile=%s reason=projector_unresolved directory=%s\n' \
                "$profile_id" "$(dirname -- "$model_path")" >&2
            skipped_unresolved_projector=$((skipped_unresolved_projector + 1))
            continue
        fi
    fi

    # A ui-mediated row performs its retrieval in the web UI and its section
    # names no web server, so the run reads none of the MCP inputs a search
    # configuration would carry. An emitting image profile still writes a
    # configuration for that section, because generation runs in the child
    # whatever the page does about search.
    if [ "$execution_policy" = ui-mediated ]; then
        emit_web_server=0
    else
        emit_web_server=1
        require_mcp_inputs
    fi
    emit_image_server=0
    web_server_separator=
    if [ -n "$image_profile_id" ]; then
        emit_image_server=1
        # A second server follows the web object, so the web object closes with
        # the separator JSON requires between two members.
        web_server_separator=,
    fi
    emit_mcp_configuration=0
    if [ "$emit_web_server" = 1 ] || [ "$emit_image_server" = 1 ]; then
        emit_mcp_configuration=1
    fi

    # The tag states what the section carries, so the assembled-file check
    # reads one line rather than reopening the configuration it names.
    image_tag_suffix=
    if [ "$emit_image_server" = 1 ]; then
        image_tag_suffix=,image
    fi

    profile_mcp_config=$mcp_config_directory_marker/$profile_id.json
    profile_mcp_config_temporary=$mcp_config_directory_temporary/$profile_id.json
    emit_web_mcp_configuration "$profile_mcp_config_temporary"



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
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' "$profile_ctx_checkpoints"
        if [ -n "$profile_projector_path" ]; then
            printf 'LLAMA_ARG_MMPROJ = %s\n' "$profile_projector_path"
        fi
        if [ "$emit_mcp_configuration" = 1 ]; then
            printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$profile_mcp_config"
        fi
        printf 'LLAMA_ARG_TAGS = web-research,%s%s%s\n' \
            "$execution_policy" "$image_tag_suffix" "$tags_suffix"
        printf '\n'
    } >>"$output_ini_temporary"

    emitted=$((emitted + 1))
done <"$web_profiles"

# The review section follows the language sections and carries the vision row's
# own tuple, its projector, and nothing else. Its name is the model_id, which
# `GET /v1/models` returns as the roster id and `GET /props?model=` answers a
# vision modality for, so the page finds the reviewer by asking the server what
# each row can read rather than by matching a name. A section header spelled
# like a profile the ledger already emitted would be two sections of one name,
# so a collision refuses here rather than landing a file whose second section
# overwrites the first.
if [ -n "$review_section" ]; then
    case $seen_profile_ids in
        *" $review_section "*)
            printf 'review section %s is spelled like a web profile the ledger emits\n' \
                "$review_section" >&2
            printf 'rename the profile or pair the image row with another review_model\n' >&2
            exit 1
            ;;
    esac
    if [ "$emitted" -eq 0 ]; then
        printf 'the review section %s reviews artifacts of a language section, and none emitted\n' \
            "$review_section" >&2
        exit 1
    fi
    {
        printf '[%s]\n' "$review_section"
        printf 'LLAMA_ARG_MODEL = %s\n' "$review_model_path"
        printf 'LLAMA_ARG_ALIAS = %s\n' "$review_section"
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$review_context"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$review_cache_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$review_cache_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$review_flash"
        printf 'LLAMA_ARG_BATCH = %s\n' "$review_batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$review_ubatch"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' "$review_ctx_checkpoints"
        printf 'LLAMA_ARG_MMPROJ = %s\n' "$review_projector_path"
        printf 'LLAMA_ARG_TAGS = vision-review,review-only\n'
        printf '\n'
    } >>"$output_ini_temporary"
    emitted=$((emitted + 1))
fi

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
            if (tags_value ~ /(^|,)image(,|$)/ &&
                !seen_key["LLAMA_ARG_MCP_SERVERS_CONFIG"]) {
                printf "assembled section %s carries the image tag and omits LLAMA_ARG_MCP_SERVERS_CONFIG\n", \
                    section > "/dev/stderr"
                rejected = 1
            }
            # A review-only section holds no execution grant of any kind, so a
            # configuration reaching it would arm a tool the page never offers
            # the reviewer.
            if (tags_value ~ /(^|,)review-only(,|$)/) {
                if (seen_key["LLAMA_ARG_MCP_SERVERS_CONFIG"]) {
                    printf "assembled section %s is review-only and carries LLAMA_ARG_MCP_SERVERS_CONFIG\n", \
                        section > "/dev/stderr"
                    rejected = 1
                }
                if (!seen_key["LLAMA_ARG_MMPROJ"]) {
                    printf "assembled section %s is review-only and omits LLAMA_ARG_MMPROJ\n", \
                        section > "/dev/stderr"
                    rejected = 1
                }
            }
            # A ui-mediated section reaches no network of its own, so a
            # configuration belongs to it only where the image tag names the
            # generation server it carries.
            if (tags_value ~ /(^|,)ui-mediated(,|$)/ &&
                tags_value !~ /(^|,)image(,|$)/ &&
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
                "LLAMA_ARG_BATCH LLAMA_ARG_UBATCH LLAMA_ARG_CTX_CHECKPOINTS " \
                "LLAMA_ARG_TAGS", \
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
    if [ "$((skipped_absent_weights + skipped_unresolved_projector))" -gt 0 ]; then
        printf 'every emitting profile in %s names an artifact this machine holds no file for, so no section emits\n' \
            "$web_profiles" >&2
        printf 'the web_preset_skipped lines above name each path; fetch them with the model_id fetch script and its projector_fetch_script\n' >&2
    else
        printf 'every profile in %s withholds an executing policy, so no section emits\n' \
            "$web_profiles" >&2
        printf 'a validator-gated row emits under QWEN_WEB_AUTHORIZER_READY=1; a refused row emits under no setting\n' >&2
    fi
    exit 1
fi

if ! verify_assembled_sections; then
    printf 'the assembled preset file is incomplete, so the previous %s stands\n' \
        "$output_ini" >&2
    exit 1
fi

# The version id is the digest of the emitted file names and their contents, so
# a directory of that name holds exactly these files and a run that changes any
# of them resolves to a different name. The emitted set follows the weights and
# projectors this machine holds as well as the two authorities, which is why the
# digest reads the files rather than the inputs that produced them: fetching a
# checkpoint between runs adds a configuration without touching either registry.
mcp_config_version=$(
    cd -- "$mcp_config_directory_temporary" &&
        find . -type f -name '*.json' -print |
        sort |
        while IFS= read -r emitted_config; do
            sha256sum -- "$emitted_config"
        done |
        sha256sum |
        cut -c1-16
)
mcp_config_directory=$output_directory/web-mcp-configs-$mcp_config_version

# Both moves happen after every row and the assembled file pass, so a failure
# above leaves the previous preset tree untouched. A directory already carrying
# this version id holds these files by construction, so the run keeps it and
# discards its own temporary copy; a session whose snapshot names an earlier
# version keeps reading the directory it started with. Directories of retired
# versions stay on disk, because removing one asks which sessions still name it
# and the launcher owns no answer.
if [ -d "$mcp_config_directory" ]; then
    rm -rf -- "$mcp_config_directory_temporary"
else
    mv -- "$mcp_config_directory_temporary" "$mcp_config_directory"
fi

# The marker each section carries becomes the resolved directory here. The
# replacement is positional rather than a sed expression, so a path holding a
# regular-expression or replacement metacharacter reaches the file verbatim.
awk -v config_directory="$mcp_config_directory" \
    -v marker="$mcp_config_directory_marker" '
    {
        marker_position = index($0, marker)
        if (marker_position > 0) {
            $0 = substr($0, 1, marker_position - 1) config_directory \
                substr($0, marker_position + length(marker))
        }
        print
    }
' "$output_ini_temporary" >"$output_ini_temporary.resolved"
mv -- "$output_ini_temporary.resolved" "$output_ini_temporary"
# Every authority is measured against the identity the sections were generated
# from immediately before the file lands, so the window the comparison covers
# ends at the publish rather than at the last emission: assembly verification,
# MCP configuration hashing, and the directory moves all run inside it, and an
# edit during any of them leaves the last known-good preset in place.
web_profiles_current_identity=$(sha256sum -- "$web_profiles")
web_profiles_current_sha256=${web_profiles_current_identity%% *}
if [ "$web_profiles_current_sha256" != "$web_profiles_sha256" ]; then
    printf 'web profile ledger identity changed during generation: expected %s, measured %s\n' \
        "$web_profiles_sha256" "$web_profiles_current_sha256" >&2
    exit 1
fi
validated_tuples_current_identity=$(sha256sum -- "$validated_tuples")
validated_tuples_current_sha256=${validated_tuples_current_identity%% *}
if [ "$validated_tuples_current_sha256" != "$validated_tuples_sha256" ]; then
    printf 'validated-tuple ledger identity changed during generation: expected %s, measured %s\n' \
        "$validated_tuples_sha256" "$validated_tuples_current_sha256" >&2
    exit 1
fi
ctx_checkpoint_ledger_current_identity=$(sha256sum -- "$ctx_checkpoint_ledger")
ctx_checkpoint_ledger_current_sha256=${ctx_checkpoint_ledger_current_identity%% *}
if [ "$ctx_checkpoint_ledger_current_sha256" != "$ctx_checkpoint_ledger_sha256" ]; then
    printf 'context checkpoint ledger identity changed during generation: expected %s, measured %s\n' \
        "$ctx_checkpoint_ledger_sha256" \
        "$ctx_checkpoint_ledger_current_sha256" >&2
    exit 1
fi

mv -- "$output_ini_temporary" "$output_ini"
trap - EXIT HUP INT TERM
cleanup_ctx_checkpoint_snapshot

printf 'web_presets=written path=%s profiles=%s absent=%s projector_unresolved=%s mcp_configs=%s image_profile=%s review_section=%s\n' \
    "$output_ini" "$emitted" "$skipped_absent_weights" \
    "$skipped_unresolved_projector" "$mcp_config_directory" \
    "${image_profile_id:--}" "${review_section:--}"
