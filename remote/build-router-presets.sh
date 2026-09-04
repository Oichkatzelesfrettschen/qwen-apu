#!/bin/sh
set -eu

# Generate the router preset file and the tier directories from the registry.
#
# llama-server in router mode reads an INI whose sections name models and whose
# keys are LLAMA_ARG_* option names. It builds a base preset from its own argv,
# strips the SSL, API key, and models-* keys from it, and cascades the rest onto
# every child it spawns. The guarded argv that qwen-capacity-policy.sh already
# builds therefore reaches each child unchanged, and this file carries only what
# differs per checkpoint: the weights, the projector, the admitted depth, the
# cache triple, and the labels the picker shows.
#
# qwen-capacity-policy.sh refuses ambient LLAMA_ARG_* precisely so the caller's
# environment cannot override the computed argv. An INI the policy generates is
# that computation's output rather than ambient input, so the refusal stands.
#
# The tier field decides both the directory a checkpoint is linked into and the
# tag the picker groups it by. Only production and candidate reach the preset
# file. A row tiered archive or rejected is linked nowhere and named in no
# section, which removes it from the picker while leaving the weights on disk
# and the fetch script that verifies them in the tree. A row tiered quarantine
# is linked into a quarantine directory beside its reason record and reaches the
# preset file only under QWEN_ROUTER_INCLUDE_QUARANTINE=1, which the appliance
# launch never sets.
#
# A profile quarantine removes one tuple rather than a checkpoint, so the preset
# this script emits carries LLAMA_ARG_BATCH and LLAMA_ARG_UBATCH from
# the registry rather than letting them arrive by cascade. That makes each
# section state the full submission geometry it serves at, so a quarantined
# tuple is checkable against one file instead of against a file plus the argv
# that spawned the router.
#
# remote/draft-pairs.tsv adds one section per pairing beside the per-checkpoint
# sections. A pairing is a second serving shape of one target rather than a new
# checkpoint, so its section names the pair_id, carries the target row's whole
# six-key tuple, and adds the draft keys the pinned common/arg.cpp registers.
# The tier field decides emission there the same way it decides it here.
#
# Directories are linked rather than moved. A checkpoint's projector must sit in
# the checkpoint's own directory for remote/select-projector.sh to pair it, and
# linking the directory preserves that pairing while a file move would break a
# reader holding the model open.
#
# One router serves the whole roster, so a validator-gated row of
# remote/web-profiles.tsv joins the file as its own section. The registry
# sections stay tool-free and the web section carries
# LLAMA_ARG_MCP_SERVERS_CONFIG beside the six tuple keys and
# LLAMA_ARG_CTX_CHECKPOINTS, which is what makes the page's per-turn Web toggle
# return tools on that row and nothing on the rest: llama-server registers the
# tool set per child from the section's own configuration, and a child holding
# none answers `403 feature_disabled`. The head marker `# qwen_web_sections=`
# names those sections, so qwen-capacity-policy.sh validates each of them under
# the web rules -- ledger rejoin by profile_id, the emitting execution_policy,
# the tag agreement, and the depth bounded by context_ceiling -- and every other
# section under the router rules, and refuses an ordinary section carrying any
# MCP key. remote/web-preset-lib.sh holds the row rules and the configuration
# writer, so this generator and build-web-presets.sh read one ledger row the
# same way.
#
# QWEN_WEB_AUTHORIZER_READY=1 is what admits a validator-gated row, the marker
# asserting that the approval dialog and the single-use grant run; absent it
# the generator emits the registry sections alone and reports the ledger rows
# it withheld. An unvalidated depth is refused outright rather than admitted
# under a marker, because this preset is the one the appliance binds 0.0.0.0
# with and build-web-presets.sh keeps the experimental path on its own
# loopback-forced file.
#
# remote/image-profiles.tsv is the second execution grant, read under the rules
# the web ledger takes: a `refused` row emits nothing under every setting and a
# `validator-gated` row adds one `image` server to each web section's MCP
# configuration under QWEN_WEB_AUTHORIZER_READY=1, naming
# remote/image-mcp/server.py with the section's own profile_id as
# QWEN_IMAGE_LANGUAGE_PROFILE because the grant binds the language profile and
# the image profile together. The head marker `# qwen_image_profile=` names the
# emitted row, and `-` states that the file arms no generation, so an absent
# marker and a withheld lane stay distinguishable to every later reader.
#
# The reviewer needs no section of its own here. build-web-presets.sh emits a
# review-only section because its file holds one language profile and would
# otherwise return one roster id; this file already serves every vision row of
# the registry at that row's own tuple with its projector, and a second section
# named for the same model_id would be two sections of one name. The marker
# `# qwen_image_review_section=` therefore names the roster section that reviews
# the shape's artifacts, and it is written only where the reviewer resolves
# whole -- a registry row, a projector in the model's own directory, and a
# `validated` router-child tuple with `projector_state=loaded`. An unresolved
# reviewer withholds the marker and names the probe that measures the arm,
# rather than refusing a roster the rest of the appliance serves.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [OUTPUT_INI]\n' "$0" >&2
    printf 'model root comes from QWEN_MODEL_ROOT, default $HOME/models\n' >&2
    printf 'web profile ledger comes from QWEN_WEB_PROFILES, default remote/web-profiles.tsv\n' >&2
    printf 'QWEN_WEB_AUTHORIZER_READY=1 admits its validator-gated rows as tool-bearing sections\n' >&2
    printf 'an admitted row requires QWEN_WEB_MCP_SERVER and, under provider exa, QWEN_WEB_SEARCH_KEY_FILE\n' >&2
    printf 'optional QWEN_WEB_TOKEN_KEY_FILE, QWEN_WEB_STATE_DIR, QWEN_WEB_MCP_TIMEOUT_MS\n' >&2
    printf 'image profile ledger comes from QWEN_IMAGE_PROFILES, default remote/image-profiles.tsv\n' >&2
    printf 'a validator-gated image row adds an image server to every emitted web section under QWEN_WEB_AUTHORIZER_READY=1\n' >&2
    printf 'that row requires QWEN_IMAGE_MCP_SERVER (remote/image-mcp/server.py), QWEN_IMAGE_TOKEN_KEY_FILE, QWEN_IMAGE_STATE_DIR, QWEN_IMAGE_SERVICE_SOCKET, QWEN_IMAGE_PROFILES_JSON\n' >&2
    printf 'optional QWEN_IMAGE_MCP_TIMEOUT_MS, default 360000\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/web-preset-lib.sh
. "$script_directory/web-preset-lib.sh"
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
model_root=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}
reason_source=${QWEN_QUARANTINE_REASONS:-$script_directory/../evidence/quarantine}
output_ini=${1:-"${HOME:?}/qwen-webui-state/router-presets.ini"}
include_quarantine=${QWEN_ROUTER_INCLUDE_QUARANTINE:-0}
case $include_quarantine in
    0 | 1) ;;
    *)
        printf 'QWEN_ROUTER_INCLUDE_QUARANTINE must be 0 or 1: %s\n' \
            "$include_quarantine" >&2
        exit 2
        ;;
esac
# The picker offers every servable row and the operator prefers one of them. The
# tag names that preference; llama-server has no default-model option, so this
# labels the section rather than preselecting it.
default_model_id=${QWEN_DEFAULT_MODEL_ID:-qwen38-2b-distill}

# The web ledger is read only where the authorizer marker admits its rows, so an
# ordinary generation depends on the registry and the two ledgers it always did
# and a machine that never armed the web lane keeps generating.
authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
case $authorizer_ready in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_AUTHORIZER_READY must be 0 or 1: %s\n' \
            "$authorizer_ready" >&2
        exit 2
        ;;
esac
web_profiles=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
# The names below are the interface web-preset-lib.sh reads, so they are set
# here and consumed there.
# shellcheck disable=SC2034
mcp_server_program=${QWEN_WEB_MCP_SERVER:-}
# shellcheck disable=SC2034
search_key_file=${QWEN_WEB_SEARCH_KEY_FILE:-}
# shellcheck disable=SC2034
fake_fixtures=${QWEN_WEB_FAKE_FIXTURES:-}
# shellcheck disable=SC2034
searxng_language=${QWEN_WEB_SEARXNG_LANGUAGE:-}
# shellcheck disable=SC2034
searxng_safesearch=${QWEN_WEB_SEARXNG_SAFESEARCH:-}
# shellcheck disable=SC2034
searxng_allow_remote=${QWEN_WEB_SEARXNG_ALLOW_REMOTE:-}
# shellcheck disable=SC2034
token_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
# shellcheck disable=SC2034
web_state_directory=${QWEN_WEB_STATE_DIR:-"${HOME:?}/qwen-webui-state/web-mcp"}
# llama-server reads timeout_ms from the MCP configuration as the per-call
# deadline for the child. The provider request times out at 20 s inside
# server.py, this limit at 30 s, and the router's proxy read timeout at the
# 3600 s llama-server default, so a slow provider answers with the child's own
# error text rather than the router abandoning a call it is still executing.
mcp_timeout_ms=${QWEN_WEB_MCP_TIMEOUT_MS:-30000}
case $mcp_timeout_ms in
    '' | 0* | *[!0-9]*)
        printf 'QWEN_WEB_MCP_TIMEOUT_MS must be a positive decimal integer: %s\n' \
            "$mcp_timeout_ms" >&2
        exit 2
        ;;
esac
# The image lane reaches the device rather than the network, and its deadline is
# the generation's: the runtime is bounded at 300 s, image-service.py at 330 s,
# and this per-call limit at 360 s, so a stalled generation is ended by the
# process that owns it. remote/image-mcp reads QWEN_IMAGE_MCP_TIMEOUT_S from the
# same emitted configuration.
image_profiles=${QWEN_IMAGE_PROFILES:-$script_directory/image-profiles.tsv}
image_quarantine=${QWEN_IMAGE_QUARANTINE:-$script_directory/image-quarantine.tsv}
# shellcheck disable=SC2034
image_mcp_server=${QWEN_IMAGE_MCP_SERVER:-}
# shellcheck disable=SC2034
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
image_state_directory=${QWEN_IMAGE_STATE_DIR:-"${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}/images"}
# shellcheck disable=SC2034
image_service_socket=${QWEN_IMAGE_SERVICE_SOCKET:-$image_state_directory/image-service.sock}
# shellcheck disable=SC2034
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
# The web loop emits validator-gated rows alone, so every emitted section
# carries the web server and the separator is what the image lane changes: a
# second member of the `mcpServers` object needs the comma JSON requires between
# two members, and its absence writes a file llama-server reports as a child
# startup failure long after the listener is up.
# shellcheck disable=SC2034
emit_web_server=1
# shellcheck disable=SC2034
emit_mcp_configuration=1
emit_image_server=0
web_server_separator=

if [ ! -r "$registry" ]; then
    printf 'model registry is unreadable: %s\n' "$registry" >&2
    exit 1
fi

# Validate every authority before changing tier links or the last known-good
# preset. In particular, a malformed draft-pair ledger must leave both
# generated surfaces untouched rather than producing an ordinary-model-only
# preset that looks complete.
quarantine_rows=$("$script_directory/model-registry.sh" quarantine-rows router-child)
draft_pair_rows=$("$script_directory/model-registry.sh" draft-pairs)
# The context checkpoint count is per row and every section carries it, since
# common_preset::merge would push one router argv value onto every child. The
# ledger identity is retained beside the rows and compared again before the file
# lands, because qwen-capacity-policy.sh rejoins every persisted section to the
# ledger it reads at launch: an edit during generation would otherwise replace
# the last known-good preset with counts the launch refuses.
# One copy is the whole run's ledger: the digest names the copy's bytes and the
# rows are read from the same copy, so the emitted counts and the recorded
# identity describe one state by construction. Two live reads of the source
# cannot state that, since a file that changed and changed back between them
# answers both reads consistently while the query in the middle returns the
# state neither digest saw. The comparison before the rename then measures the
# source against that copy, and a source standing where it stood is what admits
# the preset the launch rejoins to it.
ctx_checkpoint_ledger=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
ctx_checkpoint_snapshot=$(mktemp "${TMPDIR:-/tmp}/.ctx-checkpoints.XXXXXX")
cleanup_ctx_checkpoint_snapshot() {
    rm -f -- "$ctx_checkpoint_snapshot"
}
trap 'cleanup_ctx_checkpoint_snapshot' EXIT HUP INT TERM
cp -- "$ctx_checkpoint_ledger" "$ctx_checkpoint_snapshot"
ctx_checkpoint_ledger_identity=$(sha256sum -- "$ctx_checkpoint_snapshot")
ctx_checkpoint_ledger_sha256=${ctx_checkpoint_ledger_identity%% *}
ctx_checkpoint_rows=$(QWEN_CTX_CHECKPOINT_LEDGER=$ctx_checkpoint_snapshot \
    "$script_directory/model-registry.sh" ctx-checkpoints)
ledger_ctx_checkpoints() {
    printf '%s\n' "$ctx_checkpoint_rows" | awk -F'\t' -v id="$1" '
        $1 == id { count = $2; matched = 1 }
        END { print matched ? count : 0 }
    '
}

# The web ledger is the fourth authority and it is bound the way the third is:
# the absolute path and the digest travel in the preset head, and
# qwen-capacity-policy.sh rejoins every named section to that exact file at
# launch. The provider is the ledger's own single value, since the head marker
# records one provider for the file and one launch owns one instance.
web_profiles_sha256=-
web_provider=-
web_profiles_marker=-
if [ "$authorizer_ready" = 1 ]; then
    if [ ! -r "$web_profiles" ]; then
        printf 'web profile ledger is unreadable: %s\n' "$web_profiles" >&2
        exit 1
    fi
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
        *[!a-z0-9-]*)
            printf 'web profile ledger provider must hold lowercase letters, digits, and hyphens: %s\n' \
                "$web_provider_values" >&2
            exit 1
            ;;
        *) web_provider=$web_provider_values ;;
    esac
    if [ -n "${QWEN_WEB_PROVIDER:-}" ] &&
        [ "$QWEN_WEB_PROVIDER" != "$web_provider" ]; then
        printf 'QWEN_WEB_PROVIDER names %s where the ledger serves %s\n' \
            "$QWEN_WEB_PROVIDER" "$web_provider" >&2
        exit 1
    fi
    web_profiles_marker=$web_profiles
fi

# The image ledger is the fifth authority and it is read where the web ledger
# is, since an image server reaches a section the web ledger emitted and a
# machine that never armed either lane keeps generating from the registry alone.
# resolve_image_profile leaves image_profile_id empty under an all-refused
# ledger, which is what every checked-in row carries.
image_profile_id=
image_profile_model=
image_profile_review_model=
image_profiles_sha256=-
image_profiles_marker=-
review_section=
image_review_marker=@QWEN_IMAGE_REVIEW_SECTION@
if [ "$authorizer_ready" = 1 ]; then
    resolve_image_profile
    if [ -n "$image_profile_id" ]; then
        require_image_mcp_inputs
        bind_image_profiles_identity
        image_profiles_marker=$image_profiles
        emit_image_server=1
        web_server_separator=,
        # A reviewer this roster cannot serve withholds the marker rather than
        # ending the run, because the generation lane and the review lane are
        # separate claims and the rest of the file serves the whole appliance.
        if ! resolve_image_review_model; then
            printf 'image_review_withheld profile=%s review_model=%s\n' \
                "$image_profile_id" "$image_profile_review_model" >&2
            review_section=
        fi
    fi
fi

output_parent=$(dirname -- "$output_ini")
mkdir -p "$output_parent"
output_directory=$(CDPATH='' cd -- "$output_parent" && pwd)
output_ini=$output_directory/$(basename -- "$output_ini")
output_staging=$(mktemp "$output_directory/.router-presets.XXXXXX")
# Web sections are written to their own staging file and appended after the
# registry and pair sections, because the head marker naming them exists only
# once the last web row has emitted and the file is assembled in one order.
web_staging=$(mktemp "$output_directory/.router-web-sections.XXXXXX")
# The configuration directory is named for a digest of the files it holds, so a
# directory of that name holds exactly those files and a run that changes any of
# them resolves to a different name. A running session keeps reading the
# directory its snapshot named, which is what lets a regeneration land without
# handing that session new provider budgets.
mcp_config_directory_marker=@QWEN_WEB_MCP_CONFIG_DIRECTORY@
web_sections_marker=@QWEN_WEB_SECTIONS@
mcp_config_directory=
mcp_config_directory_temporary=$output_directory/web-mcp-configs.tmp.$$
rm -rf -- "$mcp_config_directory_temporary"
mkdir -p "$mcp_config_directory_temporary"
cleanup_output_staging() {
    cleanup_ctx_checkpoint_snapshot
    [ -n "$output_staging" ] && rm -f -- "$output_staging" \
        "$output_staging.resolved"
    [ -n "$web_staging" ] && rm -f -- "$web_staging"
    [ -n "$mcp_config_directory_temporary" ] &&
        rm -rf -- "$mcp_config_directory_temporary"
    return 0
}
trap 'cleanup_output_staging' EXIT HUP INT TERM
production_directory=$model_root/production
candidate_directory=$model_root/candidates
quarantine_directory=$model_root/quarantine
reason_directory=$model_root/quarantine-reasons
mkdir -p "$production_directory" "$candidate_directory" \
    "$quarantine_directory" "$reason_directory"

# A stale link outlives the row that created it, so the tier directories are
# emptied of links before they are rebuilt. A real directory found where a link
# belongs is refused rather than skipped: reconciliation would leave the
# checkpoint inside it in a tier no row claims, and a quarantined model sitting
# in a real production/ directory is exactly the state the tiers exist to
# prevent.
for tier_directory in "$production_directory" "$candidate_directory" \
    "$quarantine_directory"; do
    for existing in "$tier_directory"/*; do
        [ -e "$existing" ] || [ -L "$existing" ] || continue
        if [ -L "$existing" ]; then
            rm -f "$existing"
            continue
        fi
        printf 'tier directory holds a real entry where a symlink belongs: %s\n' \
            "$existing" >&2
        printf 'move it out of the tier tree; reconciliation refuses to touch it\n' >&2
        exit 1
    done
done
for existing in "$reason_directory"/*; do
    [ -f "$existing" ] || continue
    rm -f "$existing"
done

emitted=0
# The emitted ids answer whether the roster serves the image row's reviewer. The
# list is a space-delimited string because the generator runs under POSIX sh,
# which holds no associative array.
emitted_section_ids=' '
skipped_unlisted=0
skipped_absent=0
quarantined=0
deploy_quarantine_reason() {
    quarantine_reason_id=$1
    if [ ! -f "$reason_source/$quarantine_reason_id.md" ]; then
        printf 'quarantine %s carries no reason record at %s\n' \
            "$quarantine_reason_id" "$reason_source/$quarantine_reason_id.md" >&2
        return 1
    fi
    cp -- "$reason_source/$quarantine_reason_id.md" \
        "$reason_directory/$quarantine_reason_id.md"
}

{
    printf '# Generated by remote/build-router-presets.sh from the model registry.\n'
    printf '# Edit remote/models.tsv and regenerate; edits here are overwritten.\n'
    printf '# qwen_router_include_quarantine=%s\n' "$include_quarantine"
    # The section list is resolved at the land step, since a web row emits only
    # where its weights and projector are present. `-` states that the file
    # holds registry sections alone, which is what a generation without the
    # authorizer marker writes.
    printf '# qwen_web_sections=%s\n' "$web_sections_marker"
    printf '# qwen_web_profiles_path=%s\n' "$web_profiles_marker"
    printf '# qwen_web_profiles_sha256=%s\n' "$web_profiles_sha256"
    printf '# qwen_web_provider=%s\n' "$web_provider"
    # The image markers carry the same spelling build-web-presets.sh writes, so
    # one reader serves both files. `-` states a withheld lane rather than an
    # absent marker, which is what lets a launch tell a preset generated before
    # this lane from one that armed nothing.
    printf '# qwen_image_profiles_path=%s\n' "$image_profiles_marker"
    printf '# qwen_image_profiles_sha256=%s\n' "$image_profiles_sha256"
    printf '# qwen_image_profile=%s\n' "${image_profile_id:--}"
    printf '# qwen_image_model=%s\n' "${image_profile_model:--}"
    printf '# qwen_image_mcp_timeout_ms=%s\n' "$image_mcp_timeout_ms"
    printf '# qwen_image_review_model=%s\n' "${image_profile_review_model:--}"
    # The reviewer is a roster section, so the marker resolves at the land step
    # beside the web section list: the registry loop decides whether that row
    # emitted.
    printf '# qwen_image_review_section=%s\n' "$image_review_marker"
    printf '\n'
} >"$output_staging"

while IFS='	' read -r id role model_file _fetch_script context_default \
    _context_ceiling _context_target cache_type_k cache_type_v flash_attention \
    projector _projector_fetch_script _decode_tok_s _prefill_tok_s _quality tier batch ubatch \
    _validated_filled_depth _validation_evidence; do
    case $id in
        '#'* | '') continue ;;
    esac
    [ -n "${tier:-}" ] || continue

    if ! "$script_directory/model-registry.sh" validate-tier "$tier"; then
        printf 'row %s carries tier %s, which is outside the vocabulary\n' \
            "$id" "$tier" >&2
        exit 1
    fi

    # Archive and rejected rows stay outside every preset even when a retained
    # model-scope quarantine record also names them. The research override
    # exposes quarantined serving candidates; it never reverses archival.
    case $tier in
        archive | rejected)
            skipped_unlisted=$((skipped_unlisted + 1))
            continue
            ;;
    esac

    model_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v subject="$id" '$2 == "model" && $3 == subject { print; exit }')
    profile_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v subject="$id" -v depth="$context_default" \
            -v row_batch="$batch" -v row_ubatch="$ubatch" \
            -v cache_k="$cache_type_k" -v cache_v="$cache_type_v" \
            -v flash="$flash_attention" '
            $2 == "profile" && $3 == subject && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == cache_k &&
            $9 == cache_v && $10 == flash { print; exit }')

    if [ "$tier" = quarantine ] && [ -z "$model_quarantine_row" ]; then
        printf 'row %s is tiered quarantine without a router-child quarantine record\n' \
            "$id" >&2
        exit 1
    fi

    effective_tier=$tier
    preset_tier=$tier
    quarantine_row=''
    if [ -n "$model_quarantine_row" ]; then
        effective_tier=quarantine
        preset_tier=quarantine
        quarantine_row=$model_quarantine_row
    elif [ -n "$profile_quarantine_row" ]; then
        preset_tier=quarantine
        quarantine_row=$profile_quarantine_row
    fi

    model_path=$model_root/$model_file
    if [ ! -f "$model_path" ]; then
        printf 'preset_skipped id=%s reason=weights_absent path=%s\n' \
            "$id" "$model_path" >&2
        skipped_absent=$((skipped_absent + 1))
        continue
    fi

    case $effective_tier in
        production) tier_directory=$production_directory ;;
        quarantine) tier_directory=$quarantine_directory ;;
        *) tier_directory=$candidate_directory ;;
    esac
    model_directory=$(dirname -- "$model_path")
    ln -sfn "$model_directory" "$tier_directory/$(basename -- "$model_directory")"

    # The quarantine registry is the exclusion authority. A model-scope row
    # overrides a stale production or candidate tier, while a profile-scope row
    # removes only the exact section tuple. The research override exposes either
    # on a preset marked for loopback enforcement by qwen-capacity-policy.sh.
    if [ -n "$quarantine_row" ]; then
        quarantined=$((quarantined + 1))
        quarantine_reason_id=$(printf '%s\n' "$quarantine_row" | awk -F'\t' '{ print $1 }')
        deploy_quarantine_reason "$quarantine_reason_id"
        if [ "$include_quarantine" != 1 ]; then
            continue
        fi
        printf 'quarantine_exposed id=%s reason=%s\n' \
            "$id" "$reason_directory/$quarantine_reason_id.md" >&2
    fi

    {
        printf '[%s]\n' "$id"
        printf 'LLAMA_ARG_MODEL = %s\n' "$model_path"
        printf 'LLAMA_ARG_ALIAS = %s\n' "$id"
        if [ "$id" = "$default_model_id" ] &&
            [ "$preset_tier" != quarantine ]; then
            printf 'LLAMA_ARG_TAGS = %s,%s,default\n' "$preset_tier" "$role"
        else
            printf 'LLAMA_ARG_TAGS = %s,%s\n' "$preset_tier" "$role"
        fi
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$context_default"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$cache_type_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$cache_type_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$flash_attention"
        printf 'LLAMA_ARG_BATCH = %s\n' "$batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$ubatch"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' "$(ledger_ctx_checkpoints "$id")"
    } >>"$output_staging"

    if [ "$projector" = required ]; then
        projector_path=$("$script_directory/select-projector.sh" "$model_path" \
            2>/dev/null) || projector_path=''
        if [ -n "$projector_path" ]; then
            printf 'LLAMA_ARG_MMPROJ = %s\n' "$projector_path" >>"$output_staging"
        else
            printf 'preset_warning id=%s reason=projector_unresolved\n' "$id" >&2
        fi
    fi
    printf '\n' >>"$output_staging"
    emitted_section_ids="$emitted_section_ids$id "
    emitted=$((emitted + 1))
done <"$registry"

# The Review button appears where `GET /props?model=` reports a vision modality
# for some roster row, so the reviewer this image row names has to be a section
# of this file. A row the registry withheld -- archived, quarantined, or absent
# from this machine -- leaves the generation lane armed and the marker `-`.
image_review_section=-
if [ -n "$review_section" ]; then
    case $emitted_section_ids in
        *" $review_section "*) image_review_section=$review_section ;;
        *)
            printf 'image_review_withheld profile=%s review_model=%s reason=absent_from_roster\n' \
                "$image_profile_id" "$review_section" >&2
            ;;
    esac
fi

# A draft pairing is a second serving shape of one target checkpoint, so it
# reaches the picker as its own section rather than by changing the target's.
# The section carries the target row's whole six-key tuple, because
# server-models.cpp cascades the router argv over every section and an absent
# key falls through to the llama.cpp defaults of batch 2048 and ubatch 512.
#
# The draft keys are the names common/arg.cpp registers at f280b269.
# `--spec-draft-model`, `--spec-type`, `--spec-draft-n-max`,
# `--spec-draft-p-min`, `--spec-draft-type-k`, and `--spec-draft-type-v` each
# carry a set_env, so those six sections keys are LLAMA_ARG_*; draft layers
# breaks the pattern as LLAMA_ARG_N_GPU_LAYERS_DRAFT. `--spec-draft-device` and
# `--spec-draft-override-tensor` carry no set_env at all, and
# common/preset.cpp's get_map_key_opt indexes each option by its dash-stripped
# argument names beside its env names, so the INI reaches them as
# `spec-draft-device` and `spec-draft-override-tensor`.
#
# Placement is explicit on both because common_base_params_to_speculative
# overwrites result.devices, result.n_gpu_layers, and
# result.tensor_buft_overrides with the draft's own values whenever a draft path
# is set. The router argv's `--device Vulkan0`, `--n-gpu-layers all`, and
# `--override-tensor .*=Vulkan0` therefore reach the target and leave the draft
# on the default automatic placement unless the section states it.
#
# The draft context takes no key: common/speculative.cpp assigns
# `cparams.n_ctx = llama_n_ctx(ctx_tgt)` before the draft model loads, so the
# ledger's draft_context records the derived depth and the section states the
# target's.
pairs_emitted=0
pairs_unlisted=0
pairs_absent=0
pairs_quarantined=0
while IFS='	' read -r pair_id target_model_id draft_model_id pair_tier \
    spec_draft_n_max spec_draft_p_min _acceptance_floor _draft_context draft_cache_type_k \
    draft_cache_type_v _validated_evidence pair_notes; do
    [ -n "${pair_id:-}" ] || continue

    case $pair_tier in
        production | candidate) ;;
        *)
            pairs_unlisted=$((pairs_unlisted + 1))
            continue
            ;;
    esac

    target_row=$("$script_directory/model-registry.sh" id "$target_model_id")
    target_model_file=$(printf '%s\n' "$target_row" | sed -n 's/^model_file=//p')
    target_context=$(printf '%s\n' "$target_row" | sed -n 's/^context_default=//p')
    target_cache_k=$(printf '%s\n' "$target_row" | sed -n 's/^cache_type_k=//p')
    target_cache_v=$(printf '%s\n' "$target_row" | sed -n 's/^cache_type_v=//p')
    target_flash=$(printf '%s\n' "$target_row" | sed -n 's/^flash_attention=//p')
    target_batch=$(printf '%s\n' "$target_row" | sed -n 's/^batch=//p')
    target_ubatch=$(printf '%s\n' "$target_row" | sed -n 's/^ubatch=//p')
    target_role=$(printf '%s\n' "$target_row" | sed -n 's/^role=//p')
    target_projector=$(printf '%s\n' "$target_row" | sed -n 's/^projector=//p')
    draft_model_file=$("$script_directory/model-registry.sh" id \
        "$draft_model_id" model_file)

    target_path=$model_root/$target_model_file
    draft_path=$model_root/$draft_model_file
    if [ ! -f "$target_path" ] || [ ! -f "$draft_path" ]; then
        printf 'preset_skipped pair=%s reason=weights_absent target=%s draft=%s\n' \
            "$pair_id" "$target_path" "$draft_path" >&2
        pairs_absent=$((pairs_absent + 1))
        continue
    fi
    target_projector_path=''
    if [ "$target_projector" = required ]; then
        target_projector_path=$("$script_directory/select-projector.sh" \
            "$target_path" 2>/dev/null) || target_projector_path=''
        if [ -z "$target_projector_path" ]; then
            printf 'preset_skipped pair=%s reason=projector_absent target=%s\n' \
                "$pair_id" "$target_path" >&2
            pairs_absent=$((pairs_absent + 1))
            continue
        fi
    fi

    # A pair serves the target tuple and a draft tuple at the target's derived
    # context and geometry. Profile quarantine therefore applies independently
    # to either half; matching only the target would load an explicitly refused
    # draft cache geometry.
    pair_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
        awk -F'\t' -v target="$target_model_id" -v draft="$draft_model_id" \
            -v depth="$target_context" -v row_batch="$target_batch" \
            -v row_ubatch="$target_ubatch" -v cache_k="$target_cache_k" \
            -v cache_v="$target_cache_v" -v flash="$target_flash" \
            -v draft_cache_k="$draft_cache_type_k" \
            -v draft_cache_v="$draft_cache_type_v" '
            $2 == "model" && ($3 == target || $3 == draft) { print; exit }
            $2 == "profile" && $3 == target && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == cache_k &&
            $9 == cache_v && $10 == flash { print; exit }
            $2 == "profile" && $3 == draft && $5 == depth &&
            $6 == row_batch && $7 == row_ubatch && $8 == draft_cache_k &&
            $9 == draft_cache_v && $10 == flash { print; exit }')
    if [ -n "$pair_quarantine_row" ]; then
        pairs_quarantined=$((pairs_quarantined + 1))
        pair_reason_id=$(printf '%s\n' "$pair_quarantine_row" |
            awk -F'\t' '{ print $1 }')
        deploy_quarantine_reason "$pair_reason_id"
        printf 'preset_skipped pair=%s reason=quarantine record=%s\n' \
            "$pair_id" "$reason_directory/$pair_reason_id.md" >&2
        continue
    fi

    {
        printf '[%s]\n' "$pair_id"
        printf 'LLAMA_ARG_MODEL = %s\n' "$target_path"
        printf 'LLAMA_ARG_ALIAS = %s,%s\n' "$pair_id" "$pair_notes"
        printf 'LLAMA_ARG_TAGS = %s,draft-pair,%s\n' "$pair_tier" "$target_role"
        printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$target_context"
        printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$target_cache_k"
        printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$target_cache_v"
        printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$target_flash"
        printf 'LLAMA_ARG_BATCH = %s\n' "$target_batch"
        printf 'LLAMA_ARG_UBATCH = %s\n' "$target_ubatch"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' \
            "$(ledger_ctx_checkpoints "$target_model_id")"
        printf 'LLAMA_ARG_SPEC_TYPE = draft-simple\n'
        printf 'LLAMA_ARG_SPEC_DRAFT_MODEL = %s\n' "$draft_path"
        printf 'LLAMA_ARG_SPEC_DRAFT_N_MAX = %s\n' "$spec_draft_n_max"
        printf 'LLAMA_ARG_SPEC_DRAFT_P_MIN = %s\n' "$spec_draft_p_min"
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K = %s\n' "$draft_cache_type_k"
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V = %s\n' "$draft_cache_type_v"
        printf 'LLAMA_ARG_N_GPU_LAYERS_DRAFT = all\n'
        printf 'spec-draft-device = Vulkan0\n'
        printf 'spec-draft-override-tensor = .*=Vulkan0\n'
        if [ -n "$target_projector_path" ]; then
            printf 'LLAMA_ARG_MMPROJ = %s\n' "$target_projector_path"
        fi
        printf '\n'
    } >>"$output_staging"
    pairs_emitted=$((pairs_emitted + 1))
done <<EOF
$draft_pair_rows
EOF

# A validator-gated row of remote/web-profiles.tsv becomes one more section of
# this file. Every row meets the registry join, the copied-field comparison, the
# search policy, the tier rule, and the ceiling rule whatever its
# execution_policy, so the ledger is validated whole and an edit to one row's
# policy changes what emits rather than turning a validated ledger into an
# error. The emission gate then reads execution_policy: `refused` and
# `ui-mediated` emit nothing here, the first because no grant exists and the
# second because a section reaching no network of its own is a duplicate serving
# shape of a checkpoint this file already offers under its registry id.
web_sections=
web_emitted=0
web_skipped_policy=0
web_skipped_absent=0
web_skipped_projector=0
if [ "$authorizer_ready" = 1 ]; then
    while profile_id=; IFS='	' read -r profile_id model_id _web_mode context \
        ledger_validated_filled_depth max_results max_fetches \
        max_chars_per_fetch multi_source vision_allowed tool_selection \
        execution_policy row_provider primary_category fallback_category \
        minimum_results row_searxng_url || [ -n "$profile_id" ]; do
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

        if ! web_registry_row=$("$script_directory/model-registry.sh" id \
            "$model_id"); then
            printf 'profile %s names unknown model_id %s\n' \
                "$profile_id" "$model_id" >&2
            exit 1
        fi
        web_model_file=$(registry_field "$web_registry_row" model_file)
        web_context_ceiling=$(registry_field "$web_registry_row" context_ceiling)
        web_cache_type_k=$(registry_field "$web_registry_row" cache_type_k)
        web_cache_type_v=$(registry_field "$web_registry_row" cache_type_v)
        web_flash_attention=$(registry_field "$web_registry_row" flash_attention)
        web_tier=$(registry_field "$web_registry_row" tier)
        web_batch=$(registry_field "$web_registry_row" batch)
        web_ubatch=$(registry_field "$web_registry_row" ubatch)
        web_registry_filled_depth=$(registry_field "$web_registry_row" \
            validated_filled_depth)
        web_projector=$(registry_field "$web_registry_row" projector)
        web_raw_tool_selection=$(registry_field "$web_registry_row" \
            raw_tool_selection)
        require_canonical_integer context_ceiling "$web_context_ceiling" \
            sentinel-refused "$profile_id"
        require_canonical_integer batch "$web_batch" sentinel-refused "$profile_id"
        require_canonical_integer ubatch "$web_ubatch" sentinel-refused "$profile_id"
        require_canonical_integer registry_validated_filled_depth \
            "$web_registry_filled_depth" sentinel-admitted "$profile_id"
        case $web_projector in
            required) web_registry_vision_allowed=yes ;;
            none) web_registry_vision_allowed=no ;;
            *)
                printf 'profile %s names model %s whose projector column reads %s, which is outside the vocabulary\n' \
                    "$profile_id" "$model_id" "$web_projector" >&2
                exit 1
                ;;
        esac
        require_ledger_matches_registry validated_filled_depth \
            "$ledger_validated_filled_depth" "$web_registry_filled_depth"
        require_ledger_matches_registry vision_allowed \
            "$vision_allowed" "$web_registry_vision_allowed"
        require_ledger_matches_registry tool_selection \
            "$tool_selection" "$web_raw_tool_selection"
        case $web_tier in
            production | candidate) ;;
            *)
                printf 'profile %s names model %s at tier %s, which is not production or candidate\n' \
                    "$profile_id" "$model_id" "$web_tier" >&2
                exit 1
                ;;
        esac
        if [ "$context" -gt "$web_context_ceiling" ]; then
            printf 'profile %s requests context %s above %s ceiling %s\n' \
                "$profile_id" "$context" "$model_id" "$web_context_ceiling" >&2
            exit 1
        fi

        case $execution_policy in
            validator-gated) ;;
            *)
                printf 'web_preset_skipped profile=%s execution_policy=%s\n' \
                    "$profile_id" "$execution_policy" >&2
                web_skipped_policy=$((web_skipped_policy + 1))
                continue
                ;;
        esac

        # Unknown is not permission. A `-` field states that no depth has been
        # filled and decoded on that row, and this file is the one an ordinary
        # launch binds 0.0.0.0 with, so both the unmeasured and the
        # measured-too-shallow case refuse rather than emitting under a marker.
        if [ "$web_registry_filled_depth" = '-' ]; then
            printf 'profile %s requests context %s against %s validated_filled_depth unknown (-)\n' \
                "$profile_id" "$context" "$model_id" >&2
            printf 'the merged preset admits a measured depth alone; build-web-presets.sh carries the loopback-forced experimental path\n' >&2
            exit 1
        fi
        if [ "$context" -gt "$web_registry_filled_depth" ]; then
            printf 'profile %s requests context %s above %s validated_filled_depth %s\n' \
                "$profile_id" "$context" "$model_id" \
                "$web_registry_filled_depth" >&2
            exit 1
        fi

        # The quarantine authority excludes a web section the way it excludes a
        # registry one: the tuple this section constructs is the subject, and a
        # model-scope row removes the checkpoint outright.
        web_quarantine_row=$(printf '%s\n' "$quarantine_rows" |
            awk -F'\t' -v subject="$model_id" -v depth="$context" \
                -v row_batch="$web_batch" -v row_ubatch="$web_ubatch" \
                -v cache_k="$web_cache_type_k" -v cache_v="$web_cache_type_v" \
                -v flash="$web_flash_attention" '
                $2 == "model" && $3 == subject { print; exit }
                $2 == "profile" && $3 == subject && $5 == depth &&
                $6 == row_batch && $7 == row_ubatch && $8 == cache_k &&
                $9 == cache_v && $10 == flash { print; exit }')
        if [ -n "$web_quarantine_row" ]; then
            web_reason_id=$(printf '%s\n' "$web_quarantine_row" |
                awk -F'\t' '{ print $1 }')
            deploy_quarantine_reason "$web_reason_id"
            printf 'web_preset_skipped profile=%s reason=quarantine record=%s\n' \
                "$profile_id" "$reason_directory/$web_reason_id.md" >&2
            web_skipped_policy=$((web_skipped_policy + 1))
            continue
        fi

        web_model_path=$model_root/$web_model_file
        if [ ! -f "$web_model_path" ]; then
            printf 'web_preset_skipped profile=%s reason=weights_absent path=%s\n' \
                "$profile_id" "$web_model_path" >&2
            web_skipped_absent=$((web_skipped_absent + 1))
            continue
        fi
        # Router mode reads a section's own LLAMA_ARG_MMPROJ, so a vision
        # profile emitted without it loads its text GGUF alone and answers an
        # image request from nothing. select-projector.sh prints nothing for
        # both the absent and the ambiguous case, so an empty result rather
        # than the exit status discriminates.
        web_projector_path=
        if [ "$web_projector" = required ]; then
            web_projector_path=$("$script_directory/select-projector.sh" \
                "$web_model_path" 2>/dev/null) || web_projector_path=''
            if [ -z "$web_projector_path" ]; then
                printf 'web_preset_skipped profile=%s reason=projector_unresolved directory=%s\n' \
                    "$profile_id" "$(dirname -- "$web_model_path")" >&2
                web_skipped_projector=$((web_skipped_projector + 1))
                continue
            fi
        fi

        require_mcp_inputs
        emit_web_mcp_configuration "$mcp_config_directory_temporary/$profile_id.json"

        {
            printf '[%s]\n' "$profile_id"
            printf 'LLAMA_ARG_MODEL = %s\n' "$web_model_path"
            printf 'LLAMA_ARG_ALIAS = %s\n' "$profile_id"
            printf 'LLAMA_ARG_CTX_SIZE = %s\n' "$context"
            printf 'LLAMA_ARG_CACHE_TYPE_K = %s\n' "$web_cache_type_k"
            printf 'LLAMA_ARG_CACHE_TYPE_V = %s\n' "$web_cache_type_v"
            printf 'LLAMA_ARG_FLASH_ATTN = %s\n' "$web_flash_attention"
            printf 'LLAMA_ARG_BATCH = %s\n' "$web_batch"
            printf 'LLAMA_ARG_UBATCH = %s\n' "$web_ubatch"
            printf 'LLAMA_ARG_CTX_CHECKPOINTS = %s\n' \
                "$(ledger_ctx_checkpoints "$model_id")"
            if [ -n "$web_projector_path" ]; then
                printf 'LLAMA_ARG_MMPROJ = %s\n' "$web_projector_path"
            fi
            printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s/%s.json\n' \
                "$mcp_config_directory_marker" "$profile_id"
            printf 'LLAMA_ARG_TAGS = web-research,%s,%s\n' \
                "$execution_policy" "$web_tier"
            printf '\n'
        } >>"$web_staging"
        web_sections="${web_sections:+$web_sections,}$profile_id"
        web_emitted=$((web_emitted + 1))
    done <"$web_profiles"
    cat "$web_staging" >>"$output_staging"
fi

# resolve_image_profile runs ahead of this loop and leaves image_profile_id
# armed independent of whether any web row actually emits, so a ledger whose
# sole validator-gated web row is refused or has its weights absent would
# otherwise land a preset naming an image profile over an empty web section
# list. qwen-capacity-policy.sh refuses exactly that combination at launch,
# so this generator refuses it here rather than replacing the last
# known-good preset with one the launch cannot serve.
if [ -n "$image_profile_id" ] && [ "$web_emitted" -eq 0 ]; then
    printf 'image profile %s is armed and no web section emitted: %s\n' \
        "$image_profile_id" "$web_profiles" >&2
    printf 'qwen-capacity-policy.sh refuses an image marker over an empty web section list; leave one web row validator-gated with its weights present, or clear the image ledger row\n' >&2
    exit 1
fi

# The configuration directory is named for a digest of the emitted file names
# and their contents, so a directory of that name holds exactly these files and
# a session whose snapshot names an earlier version keeps reading the directory
# it started with. Retired directories stay on disk, because removing one asks
# which sessions still name it and no launcher owns that answer.
if [ "$web_emitted" -gt 0 ]; then
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
    if [ -d "$mcp_config_directory" ]; then
        rm -rf -- "$mcp_config_directory_temporary"
    else
        mv -- "$mcp_config_directory_temporary" "$mcp_config_directory"
    fi
    mcp_config_directory_temporary=
fi

# Both head markers become their resolved values here. The replacement is
# positional rather than a sed expression, so a path holding a
# regular-expression or replacement metacharacter reaches the file verbatim.
awk -v config_directory="$mcp_config_directory" \
    -v config_marker="$mcp_config_directory_marker" \
    -v sections="${web_sections:--}" -v sections_marker="$web_sections_marker" \
    -v review_section="$image_review_section" \
    -v review_marker="$image_review_marker" '
    function replace(line, marker, value,   position) {
        position = index(line, marker)
        if (position == 0) return line
        return substr(line, 1, position - 1) value \
            substr(line, position + length(marker))
    }
    {
        $0 = replace($0, config_marker, config_directory)
        $0 = replace($0, sections_marker, sections)
        $0 = replace($0, review_marker, review_section)
        print
    }
' "$output_staging" >"$output_staging.resolved"
mv -- "$output_staging.resolved" "$output_staging"

if [ "$authorizer_ready" = 1 ]; then
    web_profiles_current_identity=$(sha256sum -- "$web_profiles")
    web_profiles_current_sha256=${web_profiles_current_identity%% *}
    if [ "$web_profiles_current_sha256" != "$web_profiles_sha256" ]; then
        printf 'web profile ledger identity changed during generation: expected %s, measured %s\n' \
            "$web_profiles_sha256" "$web_profiles_current_sha256" >&2
        exit 1
    fi
fi

if [ -n "$image_profile_id" ]; then
    image_profiles_current_identity=$(sha256sum -- "$image_profiles")
    image_profiles_current_sha256=${image_profiles_current_identity%% *}
    if [ "$image_profiles_current_sha256" != "$image_profiles_sha256" ]; then
        printf 'image profile ledger identity changed during generation: expected %s, measured %s\n' \
            "$image_profiles_sha256" "$image_profiles_current_sha256" >&2
        exit 1
    fi
fi

ctx_checkpoint_ledger_current_identity=$(sha256sum -- "$ctx_checkpoint_ledger")
ctx_checkpoint_ledger_current_sha256=${ctx_checkpoint_ledger_current_identity%% *}
if [ "$ctx_checkpoint_ledger_current_sha256" != "$ctx_checkpoint_ledger_sha256" ]; then
    printf 'context checkpoint ledger identity changed during generation: expected %s, measured %s\n' \
        "$ctx_checkpoint_ledger_sha256" \
        "$ctx_checkpoint_ledger_current_sha256" >&2
    exit 1
fi

chmod 600 "$output_staging"
mv -f -- "$output_staging" "$output_ini"
output_staging=''
rm -f -- "$web_staging"
web_staging=''

printf 'router_presets=written path=%s models=%s unlisted=%s quarantined=%s absent=%s\n' \
    "$output_ini" "$emitted" "$skipped_unlisted" "$quarantined" "$skipped_absent"
printf 'draft_pairs=written pairs=%s unlisted=%s quarantined=%s absent=%s\n' \
    "$pairs_emitted" "$pairs_unlisted" "$pairs_quarantined" "$pairs_absent"
printf 'tier_directories production=%s candidates=%s quarantine=%s reasons=%s\n' \
    "$production_directory" "$candidate_directory" "$quarantine_directory" \
    "$reason_directory"
if [ "$authorizer_ready" = 1 ]; then
    printf 'web_sections=written profiles=%s withheld=%s absent=%s projector_unresolved=%s mcp_configs=%s sections=%s\n' \
        "$web_emitted" "$web_skipped_policy" "$web_skipped_absent" \
        "$web_skipped_projector" "${mcp_config_directory:--}" \
        "${web_sections:--}"
    printf 'image_sections=written profile=%s ledger=%s review_section=%s\n' \
        "${image_profile_id:--}" "$image_profiles_marker" \
        "$image_review_section"
else
    printf 'web_sections=withheld reason=authorizer_absent ledger=%s\n' \
        "$web_profiles"
    printf 'QWEN_WEB_AUTHORIZER_READY=1 admits the ledger validator-gated rows as tool-bearing sections\n'
fi
if [ "$include_quarantine" = 1 ]; then
    printf 'quarantine_override=on models_exposed=%s\n' "$quarantined"
fi
