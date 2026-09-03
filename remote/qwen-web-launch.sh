#!/bin/sh
set -eu

# Start the appliance in router mode against the web preset file that
# remote/build-web-presets.sh produces, on the loopback by default.
#
# A web preset section reaches a network the appliance otherwise never touches:
# a validator-gated section carries LLAMA_ARG_MCP_SERVERS_CONFIG, and the
# configured server performs searches and fetches on the model's behalf. The
# appliance binds 0.0.0.0 by default so the laptop serves the LAN, which would
# put that retrieval capability on every host of that network. This wrapper
# therefore sets QWEN_BIND_HOST=127.0.0.1 by default and refuses a caller who
# asked for any other listener without the opt-in below, rather than forcing the
# value silently: the operator who typed 0.0.0.0 wants an exposure the default
# declines to provide, and a refusal says so where a rewrite would leave the
# request looking honoured.
#
# QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal is
# that exposure, granted deliberately. remote/web-lan-exposure.sh holds the six
# conditions it requires; the router, the approval broker, and the artifact
# listener then reach the named address with the Web UI bearer required on every
# route of each, and the single-use grant and the approval dialog stay the whole
# execution gate.
#
# The wrapper reads every path its sections name, because a preset persists
# across the generation that resolved it: an MCP configuration llama-server
# cannot read fails the child at startup, and a projector that has moved since
# generation leaves the vision child answering an image request from nothing.
#
# qwen-capacity-policy.sh forces the same loopback for a preset carrying the
# unvalidated-depth marker, so the restriction survives a launch that reaches
# the policy another way.
#
# QWEN_ROUTER_MAX is 1. The 4B alone peaks at 2029 MiB of a 2048 MiB VRAM
# carve-out, so a second resident model competes for a pool one model already
# saturates. qwen-webui-control.sh forwards QWEN_ROUTER_MAX inside the tmux
# command string, so the value reaches qwen-capacity-policy.sh across the tmux
# boundary that a plain export stops at.
#
# QWEN_WEB_REVIEW_SECTION raises both numbers by one. qwen-image-launch.sh sets
# it to the review-only vision section build-web-presets.sh emits beside the
# language one, having proved that pair fits the Vulkan budget the memory
# preflight reports; the page then reads two ids from `GET /v1/models` and its
# Review button reaches the vision row. The name is required to be a section the
# preset actually carries, so a marker that survived a regeneration refuses the
# launch rather than raising the model limit for a section that left.
#
# The wrapper reports the preset's marker state and the QWEN_WEB_AUTHORIZER_READY
# setting before it launches, because those two decide what the running server
# can do: the marker says a section serves a depth no run has filled and
# decoded, and the authorizer setting says whether the generator admitted
# validator-gated rows at all.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    printf 'web preset file comes from QWEN_WEB_PRESETS, default $HOME/qwen-webui-state/web-presets.ini\n' >&2
    printf 'the listener is 127.0.0.1; QWEN_BIND_HOST set to any other value refuses the launch\n' >&2
    printf 'QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal serves the network instead, with the Web UI bearer required on every route\n' >&2
    exit 2
fi

profile=${1:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
launcher=$script_directory/qwen-launch.sh
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
# The activated deployment bundle's web preset outranks the state directory's
# for the same reason its router preset does in qwen-launch.sh: the sections'
# checkpoint counts were generated against the bundled ledger. The bundle is
# resolved once here and handed to the launcher as
# QWEN_ACTIVE_DEPLOYMENT_DIRECTORY, so the preset read here and the server
# and ledger read beyond the launcher come from one bundle.
deployment_root=${QWEN_DEPLOYMENT_ROOT:-"${HOME:?}/qwen-deployments"}
# An explicit QWEN_LLAMA_SERVER outranks the deployment, the rule
# qwen-webui-control.sh applies, so a launch naming its server reads no
# bundle at all.
if [ -n "${QWEN_LLAMA_SERVER:-}" ]; then
    deployment_resolution=''
    deployment_resolution_status=3
else
    deployment_resolution=$("$script_directory/resolve-active-deployment.sh" \
        "$deployment_root" 2>&1) && deployment_resolution_status=0 || \
        deployment_resolution_status=$?
fi
active_deployment_directory=''
case $deployment_resolution_status in
    0)
        active_deployment_directory=$(printf '%s\n' "$deployment_resolution" |
            sed -n 's/^active_deployment_directory=//p')
        QWEN_ACTIVE_DEPLOYMENT_DIRECTORY=$active_deployment_directory
        export QWEN_ACTIVE_DEPLOYMENT_DIRECTORY
        ;;
    3) ;;
    *)
        printf '%s\n' "$deployment_resolution" >&2
        printf 'the activated deployment failed resolution; the launch stops\n' >&2
        exit 1
        ;;
esac
deployment_web_presets=$active_deployment_directory/web-presets.ini
if [ -z "${QWEN_WEB_PRESETS:-}" ] && [ -n "$active_deployment_directory" ] && \
    [ -f "$deployment_web_presets" ]; then
    web_presets=$deployment_web_presets
    printf 'web_presets_source=active-deployment path=%s\n' "$web_presets"
else
    web_presets=${QWEN_WEB_PRESETS:-$state_directory/web-presets.ini}
fi

# QWEN_WEB_LAN=1 is the operator's explicit decision to serve this lane on the
# network; remote/web-lan-exposure.sh states what the decision requires and
# admits it against the preset and the API key below, once both are resolved.
# The caller's own listener request is read before it is replaced, so an
# explicit LAN bind under the default refuses rather than serving retrieval on
# the loopback while the operator believes the LAN is listening.
web_lan_policy=$script_directory/web-lan-exposure.sh
if [ ! -r "$web_lan_policy" ]; then
    printf 'the LAN exposure policy is unreadable: %s\n' "$web_lan_policy" >&2
    exit 2
fi
# shellcheck source=remote/web-lan-exposure.sh
. "$web_lan_policy"
# The policy reads both decisions, so a loopback launch carrying the open
# opt-in refuses here rather than at the listener it never widens.
resolve_web_lan_mode
web_lan_exposure=${QWEN_WEB_LAN:-0}
web_lan_open=${QWEN_WEB_LAN_OPEN:-0}
if [ "$web_lan_exposure" = 0 ]; then
    requested_bind_host=${QWEN_BIND_HOST:-127.0.0.1}
    if [ "$requested_bind_host" != 127.0.0.1 ]; then
        printf 'web router mode serves the loopback alone, and QWEN_BIND_HOST requests %s\n' \
            "$requested_bind_host" >&2
        printf 'a web preset section reaches the network through its MCP server; unset QWEN_BIND_HOST or set it to 127.0.0.1, or set QWEN_WEB_LAN=1 to serve the network deliberately\n' >&2
        exit 2
    fi
fi

if [ ! -r "$web_presets" ]; then
    printf 'web presets are unreadable: %s\n' "$web_presets" >&2
    printf 'generate them with remote/build-web-presets.sh\n' >&2
    exit 2
fi

if ! grep -qx '# qwen_web_presets=1' "$web_presets"; then
    printf 'preset file carries no web provenance marker: %s\n' "$web_presets" >&2
    printf 'remote/build-web-presets.sh writes `# qwen_web_presets=1`; regenerate the file\n' >&2
    exit 2
fi

# The preset binds the complete web-policy ledger used to generate its
# sections. The ledger identity markers define the launch authority and reject
# callers naming a different ledger.
preset_web_profiles=$(sed -n 's/^# qwen_web_profiles_path=//p' "$web_presets")
preset_web_profiles_sha256=$(sed -n \
    's/^# qwen_web_profiles_sha256=//p' "$web_presets")
case $preset_web_profiles in
    /*) ;;
    *)
        printf 'web presets omit an absolute web profile ledger path: %s\n' \
            "$web_presets" >&2
        exit 2
        ;;
esac
if [ "${#preset_web_profiles_sha256}" -ne 64 ]; then
    printf 'web preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
    exit 2
fi
case $preset_web_profiles_sha256 in
    *[!0-9a-f]*)
        printf 'web preset ledger SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
        exit 2
        ;;
esac
if [ -n "${QWEN_WEB_PROFILES:-}" ] &&
    [ "$QWEN_WEB_PROFILES" != "$preset_web_profiles" ]; then
    printf 'QWEN_WEB_PROFILES names %s where the preset binds %s\n' \
        "$QWEN_WEB_PROFILES" "$preset_web_profiles" >&2
    exit 2
fi
if ! preset_web_profiles_identity=$(sha256sum -- "$preset_web_profiles"); then
    printf 'web profile ledger identity cannot be measured: %s\n' \
        "$preset_web_profiles" >&2
    exit 2
fi
preset_web_profiles_actual_sha256=${preset_web_profiles_identity%% *}
if [ "$preset_web_profiles_actual_sha256" != "$preset_web_profiles_sha256" ]; then
    printf 'web profile ledger identity changed: expected %s, measured %s\n' \
        "$preset_web_profiles_sha256" "$preset_web_profiles_actual_sha256" >&2
    exit 2
fi
QWEN_WEB_PROFILES=$preset_web_profiles
export QWEN_WEB_PROFILES

authorizer_ready=${QWEN_WEB_AUTHORIZER_READY:-0}
case $authorizer_ready in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_AUTHORIZER_READY must be 0 or 1: %s\n' \
            "$authorizer_ready" >&2
        exit 2
        ;;
esac
if grep -E '^[[:space:]]*LLAMA_ARG_TAGS[[:space:]]*=([[:space:]]*[^,]+,)*[[:space:]]*validator-gated([[:space:]]*,|[[:space:]]*$)' \
    "$web_presets" >/dev/null && [ "$authorizer_ready" != 1 ]; then
    printf 'validator-gated web presets require QWEN_WEB_AUTHORIZER_READY=1\n' >&2
    exit 2
fi

# Every artifact a section names is read here, because llama-server reports an
# unreadable mcp-servers-config as a child startup failure well after the
# listener is up, and reads a section's projector only when a request selects
# that child, so an absent projector answers an image request from nothing while
# the listener has already reported ready. A preset persists across the
# generation that resolved both paths, so a file deleted or moved since then is
# found before the launch rather than by the request that needs it.
#
# The named paths reach the loop one line at a time through a file rather than
# through command substitution, which field-splits a path holding a space into
# several unreadable fragments; $HOME, QWEN_WEBUI_STATE_DIRECTORY, and
# QWEN_WEB_PRESETS each place one in the generated tree. The loop reads from a
# redirection rather than a pipeline so its count survives the loop, since a
# pipeline runs the body in a subshell and leaves the count at zero.
named_artifact_list=$(mktemp)
trap 'rm -f -- "$named_artifact_list"' EXIT HUP INT TERM
missing_named_artifacts=0
count_missing_named_artifacts() {
    artifact_key=$1
    artifact_description=$2
    sed -n "s/^[[:space:]]*${artifact_key}[[:space:]]*=[[:space:]]*//p" \
        "$web_presets" >"$named_artifact_list"
    while IFS= read -r named_artifact; do
        [ -n "$named_artifact" ] || continue
        if [ ! -f "$named_artifact" ]; then
            printf 'preset names %s: %s\n' \
                "$artifact_description" "$named_artifact" >&2
            missing_named_artifacts=$((missing_named_artifacts + 1))
        fi
    done <"$named_artifact_list"
}
count_missing_named_artifacts LLAMA_ARG_MCP_SERVERS_CONFIG \
    'an unreadable MCP configuration'
count_missing_named_artifacts LLAMA_ARG_MMPROJ \
    'a projector that is not a regular file'
rm -f -- "$named_artifact_list"
trap - EXIT HUP INT TERM
if [ "$missing_named_artifacts" -ne 0 ]; then
    printf 'regenerate the preset tree with remote/build-web-presets.sh\n' >&2
    exit 2
fi

if grep -qx '# qwen-web-presets: unvalidated-depth-override' "$web_presets"; then
    depth_marker_state=present
else
    depth_marker_state=absent
fi
# The exposure is admitted here rather than at the caller's first line because
# it reads the preset's two research markers, and the preset is what the launch
# just proved readable and provenance-marked.
if [ "$web_lan_exposure" = 1 ]; then
    admit_web_lan_exposure "$web_presets" "$state_directory/api.key"
fi
router_bind_host=${QWEN_BIND_HOST:-127.0.0.1}
printf 'web_launch presets=%s unvalidated_depth_marker=%s authorizer_ready=%s bind=%s lan_exposure=%s lan_address=%s lan_name=%s lan_open=%s\n' \
    "$web_presets" "$depth_marker_state" "${QWEN_WEB_AUTHORIZER_READY:-0}" \
    "$router_bind_host" "$web_lan_exposure" "${QWEN_WEB_LAN_ADDRESS:--}" \
    "${QWEN_WEB_LAN_NAME:--}" "$web_lan_open"

# The approval broker's lifetime is this launch's. A section reaching the
# network through its MCP server signs each search from one human approval, and
# `authorize-broker.py` is the only issuer of that signature, so a web router
# running while nothing issues grants serves a tool every call is refused. This
# marker travels to qwen-webui-session.sh through qwen-webui-control.sh, which
# starts the broker as a guarded child; the ordinary qwen-launch.sh path leaves
# the marker unset and starts no broker.
#
# The signing key is required whole before the launch: nonempty path, regular
# file rather than a symlink, owned by the serving user, mode 0600 or tighter,
# readable, and nonempty. A broker that starts without a usable key answers
# `listening` and then refuses the first approval a human has already given, so
# every rule the broker applies at its own startup is applied here first, where
# the refusal names the rule. The path alone crosses into the child; the
# contents stay in the broker's address space.
QWEN_WEB_BROKER=1
# Browser calls and broker approvals share the server API key, and web mode
# creates or reuses it, so a caller cannot downgrade the session to the
# unauthenticated default ordinary local serving takes. QWEN_WEB_LAN_OPEN=1 is
# the one decision that removes it, and it removes it from the router, the
# broker's signing routes, and the artifact listener together, so the three
# listeners state one policy.
if [ "$web_lan_open" = 1 ]; then
    QWEN_REQUIRE_API_KEY=0
else
    QWEN_REQUIRE_API_KEY=1
fi
# A bare LAN page URL derives the broker and artifact origins as
# router_port+1 and router_port+2 (webui/index.html's
# BROKER_LAN_PORT_OFFSET/ARTIFACT_LAN_PORT_OFFSET), the same derivation
# qwen-launch.sh applies to a direct LAN launch, so this wrapper matches it
# rather than fixing 8571: a router port of 8080 pairing with broker 8571
# leaves every web approval and artifact load on this launch targeting a port
# the advertised URL never names.
if [ "$web_lan_exposure" = 1 ]; then
    router_server_port=${QWEN_SERVER_PORT:-8080}
    # A derived pair overflows the valid port range above 65533, the same
    # ceiling remote/qwen-lan-launch.sh caps QWEN_SERVER_PORT at and
    # remote/qwen-launch.sh enforces on its own direct LAN path; this
    # wrapper's own derivation reaches qwen-launch.sh with the value already
    # set, which would otherwise bypass that later check.
    if [ -z "${QWEN_WEB_BROKER_PORT:-}" ] && [ "$router_server_port" -gt 65533 ]; then
        printf 'QWEN_SERVER_PORT leaves room for the broker and artifact ports above it: %s\n' \
            "$router_server_port" >&2
        exit 2
    fi
    QWEN_WEB_BROKER_PORT=${QWEN_WEB_BROKER_PORT:-$((router_server_port + 1))}
else
    QWEN_WEB_BROKER_PORT=${QWEN_WEB_BROKER_PORT:-8571}
fi
QWEN_WEB_STATE_DIR=${QWEN_WEB_STATE_DIR:-$state_directory/web-mcp}
signing_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
refuse_signing_key() {
    printf 'the grant signing key %s: %s\n' "$1" "${signing_key_file:-<unset>}" >&2
    printf 'QWEN_WEB_TOKEN_KEY_FILE names a regular file at mode 0600, owned by this user, holding the HMAC key\n' >&2
    exit 2
}
if [ -z "$signing_key_file" ]; then
    refuse_signing_key 'is unset'
fi
if [ -L "$signing_key_file" ]; then
    refuse_signing_key 'is a symbolic link'
fi
if [ ! -f "$signing_key_file" ]; then
    refuse_signing_key 'is not a regular file'
fi
signing_key_owner=$(stat -c %u "$signing_key_file" 2>/dev/null || echo unknown)
if [ "$signing_key_owner" != "$(id -u)" ]; then
    refuse_signing_key "is owned by uid $signing_key_owner rather than $(id -u)"
fi
if [ ! -r "$signing_key_file" ]; then
    refuse_signing_key 'is unreadable'
fi
if [ ! -s "$signing_key_file" ]; then
    refuse_signing_key 'is empty'
fi
signing_key_mode=$(stat -c %a "$signing_key_file" 2>/dev/null || echo unknown)
case $signing_key_mode in
    400 | 600) ;;
    *) refuse_signing_key "carries mode $signing_key_mode rather than 0600" ;;
esac
export QWEN_WEB_TOKEN_KEY_FILE

# One broker signs for one profile: `POST /grant` refuses a `profile_id` other
# than the `--profile` the broker started with, so a preset holding several
# language sections would leave every section but one with a broker that
# refuses it, and the browser would learn that after a human approved the
# search. The profile is therefore read from the preset rather than typed: the
# launch requires exactly one language section, names it QWEN_WEB_PROFILE, and
# refuses a caller whose own QWEN_WEB_PROFILE names anything else.
#
# A review-only vision section is the one section that joins it, and the broker
# signs nothing for it: the page posts one chat completion to that model and
# the request body omits `tools`, so the reviewer reaches neither the network
# nor the device. The section name is therefore subtracted here before the
# language profile is read, since a second header would otherwise make
# preset_profile two lines and hand the broker a profile spelled across a
# newline.
review_section=${QWEN_WEB_REVIEW_SECTION:-}
case $review_section in
    '' | *[!A-Za-z0-9._-]*)
        if [ -n "$review_section" ]; then
            printf 'QWEN_WEB_REVIEW_SECTION is not a section name: %s\n' \
                "$review_section" >&2
            exit 2
        fi
        ;;
esac
expected_section_count=1
if [ -n "$review_section" ]; then
    if ! grep -qxF "[$review_section]" "$web_presets"; then
        printf 'QWEN_WEB_REVIEW_SECTION names %s, which %s carries no section for\n' \
            "$review_section" "$web_presets" >&2
        printf 'regenerate the preset tree with remote/build-web-presets.sh\n' >&2
        exit 2
    fi
    preset_validated_tuples=$(sed -n \
        's/^# qwen_validated_tuples_path=//p' "$web_presets")
    preset_validated_tuples_sha256=$(sed -n \
        's/^# qwen_validated_tuples_sha256=//p' "$web_presets")
    case $preset_validated_tuples in
        /*) ;;
        *)
            printf 'review preset omits an absolute validated-tuple ledger path: %s\n' \
                "$web_presets" >&2
            exit 2
            ;;
    esac
    if [ "${#preset_validated_tuples_sha256}" -ne 64 ]; then
        printf 'review preset validated-tuple SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
        exit 2
    fi
    case $preset_validated_tuples_sha256 in
        *[!0-9a-f]*)
            printf 'review preset validated-tuple SHA-256 must hold 64 lowercase hexadecimal characters\n' >&2
            exit 2
            ;;
    esac
    if [ -n "${QWEN_VALIDATED_TUPLES:-}" ] && \
       [ "$QWEN_VALIDATED_TUPLES" != "$preset_validated_tuples" ]; then
        printf 'QWEN_VALIDATED_TUPLES names %s where the review preset binds %s\n' \
            "$QWEN_VALIDATED_TUPLES" "$preset_validated_tuples" >&2
        exit 2
    fi
    if ! preset_validated_tuples_identity=$(sha256sum -- \
            "$preset_validated_tuples"); then
        printf 'validated-tuple ledger identity cannot be measured: %s\n' \
            "$preset_validated_tuples" >&2
        exit 2
    fi
    preset_validated_tuples_actual_sha256=${preset_validated_tuples_identity%% *}
    if [ "$preset_validated_tuples_actual_sha256" != \
            "$preset_validated_tuples_sha256" ]; then
        printf 'validated-tuple ledger identity changed: expected %s, measured %s\n' \
            "$preset_validated_tuples_sha256" \
            "$preset_validated_tuples_actual_sha256" >&2
        exit 2
    fi
    QWEN_VALIDATED_TUPLES=$preset_validated_tuples
    export QWEN_VALIDATED_TUPLES

    if ! review_tuple=$(awk -v wanted="$review_section" '
        /^[[:space:]]*\[/ {
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            next
        }
        section != wanted { next }
        {
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_CTX_SIZE") depth = value
            if (key == "LLAMA_ARG_BATCH") batch = value
            if (key == "LLAMA_ARG_UBATCH") ubatch = value
            if (key == "LLAMA_ARG_CACHE_TYPE_K") cache_k = value
            if (key == "LLAMA_ARG_CACHE_TYPE_V") cache_v = value
            if (key == "LLAMA_ARG_FLASH_ATTN") flash = value
            if (key == "LLAMA_ARG_MMPROJ") projector = value
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") configuration = value
            if (key == "LLAMA_ARG_TAGS") tags = value
        }
        END {
            if (projector == "" || configuration != "" ||
                tags !~ /(^|,)review-only(,|$)/) exit 1
            print depth "\t" batch "\t" ubatch "\t" cache_k "\t" cache_v "\t" flash
        }
    ' "$web_presets"); then
        printf 'review section %s must carry review-only, a projector, and no MCP configuration\n' \
            "$review_section" >&2
        exit 2
    fi
    review_tuple_tab=$(printf '\t')
    IFS=$review_tuple_tab read -r review_depth review_batch review_ubatch \
        review_cache_k review_cache_v review_flash <<EOF
$review_tuple
EOF
    if ! awk -F '\t' -v model="$review_section" -v depth="$review_depth" \
        -v batch="$review_batch" -v ubatch="$review_ubatch" \
        -v cache_k="$review_cache_k" -v cache_v="$review_cache_v" \
        -v flash="$review_flash" '
        $2 == model && $3 == "router-child" && $4 == depth &&
        $5 == batch && $6 == ubatch && $7 == cache_k &&
        $8 == cache_v && $9 == flash && $12 == "loaded" &&
        $13 == "vulkan" && $14 == "validated" { found = 1 }
        END { exit !found }
    ' "$preset_validated_tuples"; then
        printf 'review section %s carries no validated router-child Vulkan tuple with its projector loaded\n' \
            "$review_section" >&2
        exit 2
    fi
    expected_section_count=2
fi
preset_section_count=$(grep -c '^\[[^]]*\]$' "$web_presets" || true)
if [ "$preset_section_count" -ne "$expected_section_count" ]; then
    printf 'web router mode starts one broker for one profile, and %s carries %s sections where %s are admitted\n' \
        "$web_presets" "$preset_section_count" "$expected_section_count" >&2
    printf 'generate a preset holding one language section, and one review-only vision section where an image row pairs a review_model\n' >&2
    exit 2
fi
preset_profile=$(sed -n 's/^\[\([^]]*\)\]$/\1/p' "$web_presets" |
    grep -vxF "${review_section:-}" || true)
case $preset_profile in
    '' | *[!A-Za-z0-9._-]*)
        printf 'web preset section name is not a profile id: %s\n' "$preset_profile" >&2
        exit 2
        ;;
esac
if [ -n "${QWEN_WEB_PROFILE:-}" ] && [ "$QWEN_WEB_PROFILE" != "$preset_profile" ]; then
    printf 'QWEN_WEB_PROFILE names %s where the preset serves %s\n' \
        "$QWEN_WEB_PROFILE" "$preset_profile" >&2
    exit 2
fi
QWEN_WEB_PROFILE=$preset_profile
preset_provider=$(sed -n 's/^# qwen_web_provider=//p' "$web_presets")
case $preset_provider in
    exa | fake | searxng) ;;
    *)
        printf 'web preset provider must be exa, fake, or searxng: %s\n' \
            "${preset_provider:-<absent>}" >&2
        exit 2
        ;;
esac
if [ -n "${QWEN_WEB_PROVIDER:-}" ] && \
   [ "$QWEN_WEB_PROVIDER" != "$preset_provider" ]; then
    printf 'QWEN_WEB_PROVIDER names %s where the preset serves %s\n' \
        "$QWEN_WEB_PROVIDER" "$preset_provider" >&2
    exit 2
fi
QWEN_WEB_PROVIDER=$preset_provider
export QWEN_WEB_PROFILE QWEN_WEB_PROVIDER

# Provider searxng names one local instance, and this launch owns it. The
# ledger row the preset was generated from carries the endpoint, so the URL is
# read from the row rather than from an environment default, and the row is
# required to name the loopback instance this chain starts: a remote endpoint
# would put the appliance's searches on a host the launch neither started nor
# tears down. The port has to be free here, because the session's readiness
# gate reads a socket and a child process together and a foreign listener on
# that port turns the launch into a refusal one link later, after the model has
# begun loading.
#
# QWEN_WEB_SEARXNG travels to qwen-webui-session.sh through
# qwen-webui-control.sh, which forwards it inside the tmux command string; the
# session starts remote/searxng-launch.sh as a guarded child, proves GET
# /healthz answers, and only then starts the capacity server, so a dead
# instance ends the launch before any weight reaches the device.
if [ "$preset_provider" = searxng ]; then
    profile_searxng_url=$(awk -F'\t' -v profile="$QWEN_WEB_PROFILE" \
        '$1 == profile { print $17; exit }' "$QWEN_WEB_PROFILES")
    case $profile_searxng_url in
        http://127.0.0.1:[0-9]*)
            searxng_port=${profile_searxng_url#http://127.0.0.1:}
            ;;
        *)
            searxng_port=''
            ;;
    esac
    case $searxng_port in
        '' | *[!0-9]*)
            printf 'profile %s names searxng_url %s, and this launch starts the loopback instance alone\n' \
                "$QWEN_WEB_PROFILE" "${profile_searxng_url:-<absent>}" >&2
            printf 'set searxng_url to http://127.0.0.1:PORT in %s\n' \
                "$QWEN_WEB_PROFILES" >&2
            exit 2
            ;;
    esac
    if command -v ss >/dev/null 2>&1 && \
       ss -ltn "sport = :$searxng_port" 2>/dev/null | grep -q ":$searxng_port"; then
        printf 'port %s already carries a listener, and this launch starts its own search instance there\n' \
            "$searxng_port" >&2
        printf 'stop it with remote/searxng-launch.sh stop, or remote/qwen-teardown.sh\n' >&2
        exit 2
    fi
    QWEN_WEB_SEARXNG=1
    QWEN_SEARXNG_PORT=$searxng_port
    export QWEN_WEB_SEARXNG QWEN_SEARXNG_PORT
    printf 'web_launch searxng=owned url=%s port=%s\n' \
        "$profile_searxng_url" "$searxng_port"
fi
printf 'web_launch broker_port=%s broker_state_dir=%s signing_key=configured profile=%s provider=%s review_section=%s models_max=%s\n' \
    "$QWEN_WEB_BROKER_PORT" "$QWEN_WEB_STATE_DIR" "$QWEN_WEB_PROFILE" \
    "$QWEN_WEB_PROVIDER" "${review_section:--}" "$expected_section_count"

# The page the router serves is the executor the browser runs, and the pinned
# llama UI build neither scopes GET /tools by model nor posts the routing key
# beside the tool, so web mode serves the repository fallback page.
# qwen-webui-control.sh reads QWEN_STATIC_PATH before its own default, and
# the page is read here for the two route shapes the broker path depends on,
# so a directory holding some other index.html refuses before the listener
# exists.
QWEN_STATIC_PATH=${QWEN_STATIC_PATH:-"$script_directory/../webui"}
if [ ! -f "$QWEN_STATIC_PATH/index.html" ]; then
    printf 'web mode serves the fallback page and finds no index.html under %s\n' \
        "$QWEN_STATIC_PATH" >&2
    exit 2
fi
if ! grep -qF 'tools?model=' "$QWEN_STATIC_PATH/index.html" || \
   ! grep -qF 'model, tool: toolName, params' "$QWEN_STATIC_PATH/index.html"; then
    printf 'the page under %s composes no model-scoped /tools request; web mode serves webui/index.html\n' \
        "$QWEN_STATIC_PATH" >&2
    exit 2
fi
export QWEN_STATIC_PATH
printf 'web_launch static_path=%s\n' "$QWEN_STATIC_PATH"

QWEN_ROUTER=1
QWEN_ROUTER_PRESETS=$web_presets
# The router holds one child per admitted section, so a review section raises
# the limit to the pair the launch already proved resident.
QWEN_ROUTER_MAX=$expected_section_count
QWEN_BIND_HOST=$router_bind_host
export QWEN_ROUTER QWEN_ROUTER_PRESETS QWEN_ROUTER_MAX QWEN_BIND_HOST
export QWEN_WEB_BROKER QWEN_WEB_BROKER_PORT QWEN_WEB_STATE_DIR
export QWEN_REQUIRE_API_KEY

# Every listener the exposure moves is named before the model loads, because
# the load holds the readiness loop for up to 120 seconds and an operator who
# reads the addresses after that window has already been serving them. The
# artifact listener takes an ephemeral port, so the session prints its resolved
# address and the page URL beside it once the service has bound.
if [ "$web_lan_exposure" = 1 ]; then
    if [ "$web_lan_open" = 1 ]; then
        web_lan_bearer_state=removed
    else
        web_lan_bearer_state=required
    fi
    printf 'web_launch exposure=lan address=%s name=%s router=%s:%s broker=%s:%s bearer=%s\n' \
        "$QWEN_WEB_LAN_ADDRESS" "${QWEN_WEB_LAN_NAME:--}" \
        "$QWEN_BIND_HOST" "${QWEN_SERVER_PORT:-8080}" \
        "$QWEN_BIND_HOST" "$QWEN_WEB_BROKER_PORT" "$web_lan_bearer_state"
else
    printf 'web_launch exposure=loopback router=127.0.0.1:%s broker=127.0.0.1:%s\n' \
        "${QWEN_SERVER_PORT:-8080}" "$QWEN_WEB_BROKER_PORT"
fi

exec "$launcher" "$profile"
