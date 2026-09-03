#!/bin/sh
set -eu

# Start the guarded Web UI and return only once it answers HTTP. The service
# exists for as long as this script's session lives in tmux and no longer: no
# unit file, no crontab entry, and no login hook starts it, so a reboot leaves
# the laptop with nothing listening until someone runs this again.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    exit 2
fi

profile=${1:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
control=$script_directory/qwen-webui-control.sh
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
bind_host=${QWEN_BIND_HOST:-127.0.0.1}
server_port=${QWEN_SERVER_PORT:-8080}
ready_attempts=${QWEN_READY_ATTEMPTS:-3000}
# The readiness probe reaches the listener the server actually bound. A server
# bound to one literal answers on that address alone, so a loopback probe
# against a LAN bind waits out its whole budget and tears down a session that
# came up correctly. The wildcard bind answers everywhere, which leaves the
# loopback the shortest path to it.
if [ "${QWEN_WEB_LAN:-0}" = 1 ] && [ -n "${QWEN_WEB_LAN_ADDRESS:-}" ] &&
    [ "$bind_host" != 0.0.0.0 ]; then
    health_probe_host=$QWEN_WEB_LAN_ADDRESS
else
    health_probe_host=127.0.0.1
fi

if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server is already running; run qwen-teardown.sh first\n' >&2
    exit 2
fi

# The runtime tree is a synced copy, so a divergent or stale copy refuses here
# rather than launching the previous revision under the current name. A tree
# without a manifest predates sync-runtime-tree.sh and passes as unmanifested;
# QWEN_INTENDED_GIT_HEAD additionally requires the manifest's recorded head,
# and QWEN_INTENDED_PAYLOAD_SHA256 passes a byte-identical payload under a
# head that advanced outside remote/ and patches/. The control script repeats
# this check ahead of tmux creation, so a direct control start is covered;
# this early copy refuses with a clearer operator error before anything else
# runs.
"$script_directory/check-runtime-tree.sh" "$script_directory/.." \
    "${QWEN_INTENDED_GIT_HEAD:-}" "${QWEN_INTENDED_PAYLOAD_SHA256:-}"

# The activated deployment is resolved once for the whole launch. The router
# preset here, and the server and ledger the control script selects, all come
# from the one bundle directory this resolution retains, so an activation that
# moves deployment-current while the launch is between two reads changes
# nothing the launch consumes. Exit 3 states that the root holds no
# deployment at all, which keeps the promote-chain defaults; any other
# refusal is a corrupt or tampered bundle and stops the launch here.
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
        printf 'active_deployment=%s directory=%s\n' \
            "$(printf '%s\n' "$deployment_resolution" |
                sed -n 's/^active_deployment_name=//p')" \
            "$active_deployment_directory"
        ;;
    3) ;;
    *)
        printf '%s\n' "$deployment_resolution" >&2
        printf 'the activated deployment failed resolution; the launch stops\n' >&2
        # An explicit QWEN_LLAMA_SERVER outranks the deployment, so naming the
        # server and the preset reads no bundle at all. That is the recovery
        # form for a bundle whose verification refuses while the artifacts
        # inside it are the ones the operator means to serve.
        printf 'recovery form, which reads no bundle:\n' >&2
        printf '  QWEN_LLAMA_SERVER=%s/llama-server \\\n' \
            "${deployment_root%/}/<bundle>" >&2
        printf '  QWEN_ROUTER_PRESETS=<merged.ini> \\\n' >&2
        printf '      %s %s\n' "$0" "$profile" >&2
        exit 1
        ;;
esac

model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf"}
router_snapshot_owned=''
control_start_entered=0
cleanup_router_snapshot() {
    if [ -n "$router_snapshot_owned" ]; then
        rm -f -- "$router_snapshot_owned"
        router_snapshot_owned=''
    fi
}
terminate_router_launch() {
    signal_status=$1
    if [ "$control_start_entered" = 1 ]; then
        QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_SERVER_PORT=$server_port \
            "$script_directory/qwen-teardown.sh" >/dev/null 2>&1 || true
    fi
    cleanup_router_snapshot
    trap - EXIT HUP INT TERM
    exit "$signal_status"
}

# Snapshot the exact router preset before deriving the preflight denominator.
# Generation replaces the source file independently; the session receives the
# snapshot path and digest so a later source replacement cannot widen the model
# set after sizing completes.
if [ "${QWEN_ROUTER:-0}" = 1 ]; then
    # An activated deployment bundle carries the preset generated against its
    # own ledger, so a rollback that moves the ledger moves the preset with
    # it; the state directory's file serves a machine with no bundle, and an
    # explicit QWEN_ROUTER_PRESETS still names the file it always did. The
    # preset is read from the bundle directory resolved above rather than
    # through deployment-current a second time.
    deployment_router_presets=$active_deployment_directory/router-presets.ini
    if [ -z "${QWEN_ROUTER_PRESETS:-}" ] && \
        [ -n "$active_deployment_directory" ] && \
        [ -f "$deployment_router_presets" ]; then
        source_router_presets=$deployment_router_presets
        printf 'router_presets_source=active-deployment path=%s\n' \
            "$deployment_router_presets"
    else
        source_router_presets=${QWEN_ROUTER_PRESETS:-"$state_directory/router-presets.ini"}
    fi
    if [ ! -r "$source_router_presets" ]; then
        printf 'router presets are unreadable: %s\n' "$source_router_presets" >&2
        exit 2
    fi
    mkdir -p "$state_directory"
    router_presets=$(mktemp \
        "$state_directory/.router-presets.active.XXXXXX")
    router_snapshot_owned=$router_presets
    trap cleanup_router_snapshot EXIT
    trap 'terminate_router_launch 129' HUP
    trap 'terminate_router_launch 130' INT
    trap 'terminate_router_launch 143' TERM
    cp -- "$source_router_presets" "$router_presets"
    chmod 600 "$router_presets"
    router_preset_identity=$(sha256sum "$router_presets")
    router_preset_sha256=${router_preset_identity%% *}
    QWEN_ROUTER_PRESETS=$router_presets
    QWEN_ROUTER_PRESET_SHA256=$router_preset_sha256
    export QWEN_ROUTER_PRESETS QWEN_ROUTER_PRESET_SHA256

    # The merged preset names the sections carrying an MCP configuration, and
    # the marker is read off the snapshot rather than the source, so an
    # activation between the two reads cannot change what the broker signs
    # for. A section reaching the network needs the approval broker issuing
    # its grants and the search instance answering its queries, and it needs
    # the repository page, since the pinned llama UI build neither scopes
    # `GET /tools` by model nor posts the routing key beside the tool.
    web_sections=$(sed -n 's/^# qwen_web_sections=//p' "$router_presets")
    case $web_sections in
        '-') web_sections='' ;;
    esac
    if [ -n "$web_sections" ]; then
        case $web_sections in
            *,*)
                # One broker signs for one profile: `POST /grant` refuses a
                # profile_id other than its own `--profile`, so a second web
                # section would leave the browser learning that after a human
                # approved the search.
                printf 'the preset carries web sections %s, and one broker signs for one profile\n' \
                    "$web_sections" >&2
                printf 'leave one validator-gated row in the web profile ledger and regenerate\n' >&2
                exit 2
                ;;
        esac
        if [ "${QWEN_WEB_AUTHORIZER_READY:-0}" != 1 ]; then
            printf 'the preset carries the web section %s and QWEN_WEB_AUTHORIZER_READY names %s\n' \
                "$web_sections" "${QWEN_WEB_AUTHORIZER_READY:-0}" >&2
            printf 'the marker asserts that the approval dialog and the single-use grant run\n' >&2
            exit 2
        fi
        QWEN_WEB_PROFILE=$web_sections
        # The listener policy is read here, ahead of the credential decision it
        # governs: QWEN_WEB_LAN_OPEN=1 removes the bearer from all three
        # listeners and requires the exposure it opens, so a loopback launch
        # carrying it refuses before this launch mints a key it would not use.
        web_lan_policy=$script_directory/web-lan-exposure.sh
        if [ ! -r "$web_lan_policy" ]; then
            printf 'the LAN exposure policy is unreadable: %s\n' \
                "$web_lan_policy" >&2
            exit 2
        fi
        # shellcheck source=remote/web-lan-exposure.sh
        . "$web_lan_policy"
        resolve_web_lan_mode
        # Browser calls and broker approvals share the server API key, so a
        # tool-bearing section serves an authenticated listener whatever the
        # caller asked for, and the open opt-in is the one decision that serves
        # the LAN without one.
        if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ]; then
            QWEN_REQUIRE_API_KEY=0
        else
            QWEN_REQUIRE_API_KEY=1
        fi
        QWEN_WEB_BROKER=1
        # An exposed launch places the broker one port above the router, and
        # the session places the artifact listener one above that, so a LAN
        # page derives both from the one address it was loaded over and a
        # router port chosen clear of other services carries its companions
        # with it. A loopback launch keeps the 8571 the meta tags name.
        if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
            QWEN_WEB_BROKER_PORT=${QWEN_WEB_BROKER_PORT:-$((server_port + 1))}
        else
            QWEN_WEB_BROKER_PORT=${QWEN_WEB_BROKER_PORT:-8571}
        fi
        QWEN_WEB_STATE_DIR=${QWEN_WEB_STATE_DIR:-$state_directory/web-mcp}
        export QWEN_WEB_PROFILE QWEN_REQUIRE_API_KEY QWEN_WEB_BROKER \
            QWEN_WEB_BROKER_PORT QWEN_WEB_STATE_DIR

        # The preset binds the ledger it was generated from, so the profile row
        # the launch reads is the row that produced the section.
        web_profiles=$(sed -n 's/^# qwen_web_profiles_path=//p' "$router_presets")
        web_provider=$(sed -n 's/^# qwen_web_provider=//p' "$router_presets")
        case $web_profiles in
            /*) ;;
            *)
                printf 'the merged preset omits an absolute web profile ledger path: %s\n' \
                    "$router_presets" >&2
                exit 2
                ;;
        esac
        if [ ! -r "$web_profiles" ]; then
            printf 'web profile ledger is unreadable: %s\n' "$web_profiles" >&2
            exit 2
        fi
        if [ -n "${QWEN_WEB_PROFILES:-}" ] &&
            [ "$QWEN_WEB_PROFILES" != "$web_profiles" ]; then
            printf 'QWEN_WEB_PROFILES names %s where the preset binds %s\n' \
                "$QWEN_WEB_PROFILES" "$web_profiles" >&2
            exit 2
        fi
        QWEN_WEB_PROFILES=$web_profiles
        export QWEN_WEB_PROFILES
        case $web_provider in
            exa | fake | searxng) ;;
            *)
                printf 'the merged preset provider must be exa, fake, or searxng: %s\n' \
                    "${web_provider:-<absent>}" >&2
                exit 2
                ;;
        esac
        QWEN_WEB_PROVIDER=$web_provider
        export QWEN_WEB_PROVIDER

        # The signing key is required whole before anything launches. A broker
        # that starts without a usable key answers `listening` and then refuses
        # the first approval a human has already given, so every rule the
        # broker applies at its own startup is applied here, where the refusal
        # names the rule. The path alone crosses into the child.
        signing_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-}
        refuse_signing_key() {
            printf 'the grant signing key %s: %s\n' "$1" \
                "${signing_key_file:-<unset>}" >&2
            printf 'QWEN_WEB_TOKEN_KEY_FILE names a regular file at mode 0600, owned by this user, holding the HMAC key\n' >&2
            exit 2
        }
        [ -n "$signing_key_file" ] || refuse_signing_key 'is unset'
        [ ! -L "$signing_key_file" ] || refuse_signing_key 'is a symbolic link'
        [ -f "$signing_key_file" ] || refuse_signing_key 'is not a regular file'
        signing_key_owner=$(stat -c %u "$signing_key_file" 2>/dev/null ||
            echo unknown)
        if [ "$signing_key_owner" != "$(id -u)" ]; then
            refuse_signing_key "is owned by uid $signing_key_owner rather than $(id -u)"
        fi
        [ -r "$signing_key_file" ] || refuse_signing_key 'is unreadable'
        [ -s "$signing_key_file" ] || refuse_signing_key 'is empty'
        signing_key_mode=$(stat -c %a "$signing_key_file" 2>/dev/null ||
            echo unknown)
        case $signing_key_mode in
            400 | 600) ;;
            *) refuse_signing_key "carries mode $signing_key_mode rather than 0600" ;;
        esac
        export QWEN_WEB_TOKEN_KEY_FILE

        # llama-server reports an unreadable mcp-servers-config as a child
        # startup failure well after the listener is up, and reads a section
        # projector only when a request selects that child, so every path a
        # section names is read here. The bundle recorded each configuration
        # by path and digest, and the comparison against that record is what
        # binds the file the child will read to the one the bundle described.
        missing_named_artifacts=0
        named_artifact_list=$(mktemp "$state_directory/.router-artifacts.XXXXXX")
        for artifact_key in LLAMA_ARG_MCP_SERVERS_CONFIG LLAMA_ARG_MMPROJ; do
            sed -n "s/^[[:space:]]*${artifact_key}[[:space:]]*=[[:space:]]*//p" \
                "$router_presets" >"$named_artifact_list"
            while IFS= read -r named_artifact; do
                [ -n "$named_artifact" ] || continue
                if [ ! -f "$named_artifact" ]; then
                    printf 'the preset names %s and this machine holds no file for it: %s\n' \
                        "$artifact_key" "$named_artifact" >&2
                    missing_named_artifacts=$((missing_named_artifacts + 1))
                fi
            done <"$named_artifact_list"
        done
        rm -f -- "$named_artifact_list"
        if [ "$missing_named_artifacts" -ne 0 ]; then
            printf 'regenerate the preset tree with remote/build-router-presets.sh\n' >&2
            exit 2
        fi
        deployment_web_mcp_manifest=$active_deployment_directory/web-mcp-manifest.tsv
        if [ -n "$active_deployment_directory" ] &&
            [ -f "$deployment_web_mcp_manifest" ]; then
            # A record row is profile_id, configuration_path, sha256, and
            # image_server, the four fields build-deployment-bundle.sh writes
            # in its own header line; a row written before the image lane
            # carries the first three and reads image_server as empty. The
            # fourth variable exists so the digest comparison reads the digest:
            # `read` assigns the whole remainder to its last variable, so three
            # variables over a four-field row measured a digest against
            # `<sha256><TAB>image` and refused every image bundle at launch.
            while IFS='	' read -r recorded_section recorded_path \
                recorded_sha256 recorded_image_server; do
                case $recorded_section in
                    '#'* | '') continue ;;
                esac
                # A fifth field would land in the last variable the way the
                # fourth did, so the vocabulary is what proves the row ended
                # where the reader thinks it did.
                case $recorded_image_server in
                    '' | image | -) ;;
                    *)
                        printf 'the MCP record for %s carries image_server %s, which is outside the vocabulary\n' \
                            "$recorded_section" "$recorded_image_server" >&2
                        printf 'a row reads profile_id, configuration_path, sha256, and image_server over image and -\n' >&2
                        exit 2
                        ;;
                esac
                measured_sha256=$(sha256sum -- "$recorded_path" |
                    cut -d ' ' -f 1) || exit 1
                if [ "$measured_sha256" != "$recorded_sha256" ]; then
                    printf 'the MCP configuration for %s changed since the bundle recorded it: expected %s, measured %s\n' \
                        "$recorded_section" "$recorded_sha256" \
                        "$measured_sha256" >&2
                    printf 'regenerate the preset tree and assemble a bundle against it\n' >&2
                    exit 2
                fi
            done <"$deployment_web_mcp_manifest"
            printf 'web_mcp_configurations=verified record=%s\n' \
                "$deployment_web_mcp_manifest"
        fi

        # Provider searxng names one local instance and this launch owns it.
        # The endpoint comes from the ledger row the section was generated
        # from, and the port has to be free here, because the session proves a
        # socket and a child process together one link later, after the model
        # has begun loading.
        if [ "$web_provider" = searxng ]; then
            profile_searxng_url=$(awk -F'\t' -v profile="$QWEN_WEB_PROFILE" \
                '$1 == profile { print $17; exit }' "$web_profiles")
            case $profile_searxng_url in
                http://127.0.0.1:[0-9]*)
                    searxng_port=${profile_searxng_url#http://127.0.0.1:}
                    ;;
                *) searxng_port='' ;;
            esac
            case $searxng_port in
                '' | *[!0-9]*)
                    printf 'profile %s names searxng_url %s, and this launch starts the loopback instance alone\n' \
                        "$QWEN_WEB_PROFILE" \
                        "${profile_searxng_url:-<absent>}" >&2
                    exit 2
                    ;;
            esac
            if command -v ss >/dev/null 2>&1 &&
                ss -ltn "sport = :$searxng_port" 2>/dev/null |
                grep -q ":$searxng_port"; then
                printf 'port %s already carries a listener, and this launch starts its own search instance there\n' \
                    "$searxng_port" >&2
                printf 'stop it with remote/searxng-launch.sh stop, or remote/qwen-teardown.sh\n' >&2
                exit 2
            fi
            QWEN_WEB_SEARXNG=1
            QWEN_SEARXNG_PORT=$searxng_port
            export QWEN_WEB_SEARXNG QWEN_SEARXNG_PORT
        fi

        # The page the router serves is the executor the browser runs, and the
        # two route shapes the approval path depends on are read here so a
        # directory holding some other index.html refuses before the listener
        # exists.
        QWEN_STATIC_PATH=${QWEN_STATIC_PATH:-"$script_directory/../webui"}
        if [ ! -f "$QWEN_STATIC_PATH/index.html" ]; then
            printf 'a web section serves the fallback page and finds no index.html under %s\n' \
                "$QWEN_STATIC_PATH" >&2
            exit 2
        fi
        if ! grep -qF 'tools?model=' "$QWEN_STATIC_PATH/index.html" ||
            ! grep -qF 'model, tool: toolName, params' \
                "$QWEN_STATIC_PATH/index.html"; then
            printf 'the page under %s composes no model-scoped /tools request; a web section serves webui/index.html\n' \
                "$QWEN_STATIC_PATH" >&2
            exit 2
        fi
        export QWEN_STATIC_PATH

        # A section reaching the network serves the loopback unless the
        # operator decided otherwise, so an ordinary launch on 0.0.0.0 with a
        # search section is exactly as guarded as the web launch on the LAN.
        if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
            admit_web_lan_exposure "$router_presets" "$state_directory/api.key"
            bind_host=$QWEN_BIND_HOST
            health_probe_host=$QWEN_WEB_LAN_ADDRESS
            [ "$bind_host" != 0.0.0.0 ] || health_probe_host=127.0.0.1
        elif [ "$bind_host" != 127.0.0.1 ] && [ "$bind_host" != localhost ]; then
            printf 'the preset carries the web section %s and QWEN_BIND_HOST requests %s\n' \
                "$web_sections" "$bind_host" >&2
            printf 'a web section reaches the network through its MCP server; serve 127.0.0.1, or set QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS to serve the network deliberately\n' >&2
            exit 2
        fi
        printf 'web_section=%s provider=%s broker_port=%s searxng=%s static_path=%s bind=%s lan_exposure=%s lan_name=%s lan_open=%s\n' \
            "$web_sections" "$web_provider" "$QWEN_WEB_BROKER_PORT" \
            "${QWEN_WEB_SEARXNG:-0}" "$QWEN_STATIC_PATH" "$bind_host" \
            "${QWEN_WEB_LAN:-0}" "${QWEN_WEB_LAN_NAME:--}" \
            "${QWEN_WEB_LAN_OPEN:-0}"
    fi
fi

# Router mode sizes the machine against the largest checkpoint the picker can
# reach rather than against the one this launch names. `--models-max 1` unloads
# the resident model before loading the next, so any servable row can be the one
# holding the device, and a preflight run against the smallest of them reports
# headroom for a load that never happens. Router presets carry their own model
# and projector paths, so the largest registry subject replaces any explicit
# single-model path for fetch and preflight.
#
# A draft-pair section holds two checkpoints at once, since
# common_speculative_init_result loads the draft as a second model beside the
# target rather than reusing the target's buffers. The section's subject is
# therefore the sum of both artifacts, and where that sum wins the selection the
# draft's own bytes are added to the Vulkan requirement the probe measures
# against, the arithmetic qwen-image-launch.sh applies to its two resident
# checkpoints.
if [ "${QWEN_ROUTER:-0}" = 1 ]; then
    largest_servable=''
    largest_draft=''
    largest_draft_bytes=0
    largest_bytes=0
    preset_model_paths=$(awk '
        function finish_section() {
            if (section == "" || section == "*") return
            model_sections++
            if (model_count != 1) {
                printf "router preflight section %s requires exactly one LLAMA_ARG_MODEL, found %d\n", \
                    section, model_count > "/dev/stderr"
                invalid = 1
            } else if (draft_count > 1) {
                printf "router preflight section %s carries %d LLAMA_ARG_SPEC_DRAFT_MODEL keys\n", \
                    section, draft_count > "/dev/stderr"
                invalid = 1
            } else {
                printf "%s\t%s\n", model_path, draft_path
            }
        }
        /^[[:space:]]*($|[#;])/ { next }
        /^[[:space:]]*\[/ {
            finish_section()
            section = $0
            if (section !~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/) {
                printf "router preflight carries malformed section header: %s\n", \
                    section > "/dev/stderr"
                invalid = 1
                section = ""
                model_count = 0
                model_path = ""
                draft_count = 0
                draft_path = ""
                next
            }
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            model_count = 0
            model_path = ""
            draft_count = 0
            draft_path = ""
            next
        }
        {
            if (section == "" || section == "*") next
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MODEL") {
                model_count++
                model_path = value
            } else if (key == "LLAMA_ARG_SPEC_DRAFT_MODEL") {
                draft_count++
                draft_path = value
            }
        }
        END {
            finish_section()
            if (model_sections == 0) {
                print "router preflight carries no model section" > "/dev/stderr"
                invalid = 1
            }
            exit invalid
        }
    ' "$router_presets")
    while IFS='	' read -r servable_path servable_draft_path; do
        if [ -z "$servable_path" ] || [ ! -f "$servable_path" ]; then
            printf 'router preflight model is not a regular file: %s\n' \
                "$servable_path" >&2
            exit 1
        fi
        if ! servable_bytes=$(stat -c %s "$servable_path" 2>/dev/null); then
            printf 'router preflight cannot measure model bytes: %s\n' \
                "$servable_path" >&2
            exit 1
        fi
        servable_draft_bytes=0
        if [ -n "${servable_draft_path:-}" ]; then
            if [ ! -f "$servable_draft_path" ]; then
                printf 'router preflight draft model is not a regular file: %s\n' \
                    "$servable_draft_path" >&2
                exit 1
            fi
            if ! servable_draft_bytes=$(stat -c %s "$servable_draft_path" \
                2>/dev/null); then
                printf 'router preflight cannot measure draft model bytes: %s\n' \
                    "$servable_draft_path" >&2
                exit 1
            fi
        fi
        servable_resident_bytes=$((servable_bytes + servable_draft_bytes))
        if [ "$servable_resident_bytes" -gt "$largest_bytes" ]; then
            largest_bytes=$servable_resident_bytes
            largest_servable=$servable_path
            largest_draft=${servable_draft_path:-}
            largest_draft_bytes=$servable_draft_bytes
        fi
    done <<EOF
$preset_model_paths
EOF
    if [ -n "$largest_servable" ]; then
        if [ -n "$largest_draft" ]; then
            printf 'router_preflight_subject=%s bytes=%s draft=%s draft_bytes=%s\n' \
                "$(basename -- "$largest_servable")" "$largest_bytes" \
                "$(basename -- "$largest_draft")" "$largest_draft_bytes"
            # The probe measures one file for its own report, so the draft's
            # bytes reach the requirement rather than the subject path. Rounding
            # up keeps a partial mebibyte charged rather than dropped.
            mebibyte=1048576
            router_required_vulkan_mib=${QWEN_REQUIRED_VULKAN_MIB:-4608}
            QWEN_REQUIRED_VULKAN_MIB=$((router_required_vulkan_mib +
                (largest_draft_bytes + mebibyte - 1) / mebibyte))
            export QWEN_REQUIRED_VULKAN_MIB
            printf 'router_preflight_requirement mib=%s draft_mib=%s\n' \
                "$QWEN_REQUIRED_VULKAN_MIB" \
                "$(((largest_draft_bytes + mebibyte - 1) / mebibyte))"
        else
            printf 'router_preflight_subject=%s bytes=%s\n' \
                "$(basename -- "$largest_servable")" "$largest_bytes"
        fi
        model_path=$largest_servable
    fi

    # The image lane is armed from the same preset the web lane is, and it is
    # resolved after the subject selection because its cost composes with what
    # that selection charged rather than replacing it.
    # remote/image-launch-lib.sh holds the rules qwen-image-launch.sh applies to
    # the web-only preset, so one reader decides what an armed lane is.
    # shellcheck disable=SC2034  # the library reads it by name
    image_service_program=${QWEN_IMAGE_SERVICE_PROGRAM:-$script_directory/image-service.py}
    # A withheld lane is the state a preset generated before it carries, so the
    # names the library writes start at that reading.
    image_lane_armed=0
    preset_image_profile=
    preset_review_section=-
    image_runtime_resident_mib=0
    # shellcheck source=remote/image-launch-lib.sh
    . "$script_directory/image-launch-lib.sh"
    read_image_preset_markers "$router_presets"
    if [ "${QWEN_IMAGE_SERVICE:-0}" = 1 ]; then
        # qwen-web-launch.sh execs this script, so a launch that came through
        # qwen-image-launch.sh arrives with the lane already resolved: that
        # wrapper read the same markers, ran the same library, and charged the
        # web preset's own two-checkpoint arithmetic. One owner per launch, so
        # this one reports what it inherited rather than resolving a second
        # time against a file whose section list it never wrote.
        printf 'image_launch owner=qwen-image-launch.sh profile=%s required_mib=%s\n' \
            "${QWEN_IMAGE_PROFILE:--}" "${QWEN_REQUIRED_VULKAN_MIB:--}"
    elif [ "$image_lane_armed" = 1 ]; then
        # An image server reaches the device from the section the web ledger
        # emitted, and the grant binds that language profile to the image
        # profile, so a lane armed over a preset naming no web section would
        # sign for a profile this launch never resolved.
        if [ -z "$web_sections" ]; then
            printf 'the preset names image profile %s and carries no web section\n' \
                "$preset_image_profile" >&2
            printf 'regenerate the preset tree with remote/build-router-presets.sh\n' >&2
            exit 2
        fi
        require_image_ledger_row || exit 2
        require_image_signing_key || exit 2
        require_image_parameters || exit 2
        verify_image_deadline_stack "$router_presets" "$web_sections" || exit 2
        read_image_runtime_resident_mib || exit 2
        # `--models-max 1` unloads the resident child before loading the next,
        # so the roster's sections are never co-resident and the reviewer the
        # marker names is the registry row a request selects rather than a
        # second load. What the lane adds to the requirement is the image
        # runtime, which runs while the language child stays loaded.
        router_required_vulkan_mib=${QWEN_REQUIRED_VULKAN_MIB:-4608}
        QWEN_REQUIRED_VULKAN_MIB=$((router_required_vulkan_mib +
            image_runtime_resident_mib))
        export QWEN_REQUIRED_VULKAN_MIB
        run_image_memory_preflight "$model_path" \
            "$QWEN_REQUIRED_VULKAN_MIB" || exit 2
        # model-memory-preflight.sh reports and admits every launch, and this
        # shape is the one section plus the runtime that
        # evidence/image-appliance/served-turn-admission/ ran and passed, so the
        # figure is reported rather than gated on. The pairing refusal belongs
        # to qwen-image-launch.sh, where a second checkpoint is resident.
        printf 'image_launch budget subject_mib=%s runtime_mib=%s required_mib=%s review_section=%s\n' \
            "$router_required_vulkan_mib" "$image_runtime_resident_mib" \
            "$QWEN_REQUIRED_VULKAN_MIB" "${preset_review_section:--}"
        export_image_service_environment
    fi
fi

# GGUF weights live outside Git because their size exceeds what Git LFS carries
# on a free account, so the checkpoint arrives from its pinned Hugging Face
# revision on first launch. The fetch script verifies an existing file against
# the recorded byte count and SHA-256 and exits without downloading when it
# matches, which makes this line a no-op on every launch after the first.
if [ ! -f "$model_path" ]; then
    fetch_script=''
    registry_fetch=$("$script_directory/model-registry.sh" path "$model_path" \
        fetch_script 2>/dev/null) || registry_fetch=''
    if [ -n "$registry_fetch" ]; then
        fetch_script=$script_directory/$registry_fetch
    fi
    if [ -z "$fetch_script" ] || [ ! -x "$fetch_script" ]; then
        printf 'model is absent and remote/models.tsv holds no row for it: %s\n' \
            "$model_path" >&2
        exit 1
    fi
    printf 'model_fetch=starting path=%s\n' "$model_path"
    "$fetch_script" "$(dirname -- "$model_path")" || {
        printf 'model fetch failed for %s\n' "$model_path" >&2
        exit 1
    }
fi

# A mismatched projector loads without error and places image tokens where the
# language model does not read them, so remote/select-projector.sh binds the
# search to the checkpoint's own directory and prints nothing where the pairing
# is absent or ambiguous. remote/test-projector-pairing.sh covers selection and
# remote/test-projector-fetch-dispatch.sh covers registry-directed fetching.
model_directory=$(dirname -- "$model_path")
if [ "${QWEN_MMPROJ+x}" = x ]; then
    mmproj=$QWEN_MMPROJ
else
    mmproj=$("$script_directory/select-projector.sh" "$model_path") || mmproj=''
fi
if [ -z "$mmproj" ] && [ "${QWEN_FETCH_MMPROJ:-0}" = 1 ]; then
    projector_fetch_script=$("$script_directory/model-registry.sh" path \
        "$model_path" projector_fetch_script 2>/dev/null) || projector_fetch_script=''
    case $projector_fetch_script in
        '' | -)
            printf 'model registry holds no projector fetch script for %s\n' \
                "$model_path" >&2
            exit 1
            ;;
    esac
    projector_fetch_path=$script_directory/$projector_fetch_script
    if [ ! -x "$projector_fetch_path" ]; then
        printf 'projector fetch script is not executable: %s\n' \
            "$projector_fetch_path" >&2
        exit 1
    fi
    "$projector_fetch_path" "$model_directory" || {
        printf 'projector fetch failed for %s\n' "$model_path" >&2
        exit 1
    }
    mmproj=$("$script_directory/select-projector.sh" "$model_path") || mmproj=''
    if [ -z "$mmproj" ]; then
        printf 'projector fetch produced no unambiguous match for %s\n' \
            "$model_path" >&2
        exit 1
    fi
fi
[ -n "$mmproj" ] && [ -f "$mmproj" ] || mmproj=''
[ -n "$mmproj" ] && printf 'projector=%s\n' "$(basename -- "$mmproj")"

control_start_entered=1
QWEN_BIND_HOST=$bind_host QWEN_SERVER_PORT=$server_port \
QWEN_MODEL_PATH=$model_path QWEN_MMPROJ=$mmproj \
    "$control" start "$profile"

attempt=0
while [ "$attempt" -lt "$ready_attempts" ]; do
    if grep -q 'state=failed' "$state_directory/session.status" 2>/dev/null; then
        printf 'session reported failure\n' >&2
        sed -n '1p' "$state_directory/session.status" >&2
        [ -r "$state_directory/server.log" ] && tail -n 40 "$state_directory/server.log" >&2
        "$script_directory/qwen-teardown.sh" >/dev/null 2>&1 || true
        exit 1
    fi
    if grep -q 'state=running ' "$state_directory/session.status" 2>/dev/null && \
       curl --silent --fail "http://$health_probe_host:$server_port/health" >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

if [ "$attempt" -ge "$ready_attempts" ]; then
    printf 'server did not answer /health within %s seconds\n' \
        "$((ready_attempts / 10))" >&2
    "$script_directory/qwen-teardown.sh" >/dev/null 2>&1 || true
    exit 1
fi

# The running session now owns the unique snapshot and removes it through its
# EXIT trap. Until this acknowledgement, the launcher trap owns startup errors.
router_snapshot_owned=''
control_start_entered=0

sed -n '1p' "$state_directory/session.status"
# The exposure names the page by the host an operator keeps rather than by the
# whole set of addresses this machine answers on. The mDNS name outlives a DHCP
# lease, so it leads and the leased literal follows it; a launch that resolved
# no name prints the literal alone.
if [ "${QWEN_WEB_LAN:-0}" = 1 ] && [ -n "${QWEN_WEB_LAN_ADDRESS:-}" ]; then
    if [ -n "${QWEN_WEB_LAN_NAME:-}" ]; then
        printf 'the page is at http://%s:%s/ (and http://%s:%s/)\n' \
            "$QWEN_WEB_LAN_NAME" "$server_port" \
            "$QWEN_WEB_LAN_ADDRESS" "$server_port"
        lan_page_link_host=$QWEN_WEB_LAN_NAME
    else
        printf 'the page is at http://%s:%s/\n' \
            "$QWEN_WEB_LAN_ADDRESS" "$server_port"
        lan_page_link_host=$QWEN_WEB_LAN_ADDRESS
    fi
    if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ]; then
        printf 'lan_open=1 every peer on this network can chat, approve a search, and approve a generation\n'
    else
        # The key travels in a fragment, which the browser keeps out of the
        # request line and every server log, and this line prints only where
        # stdout is a terminal, so a launch whose output is redirected or piped
        # leaves the bearer out of the file it wrote.
        if [ -t 1 ] && [ -s "$state_directory/api.key" ]; then
            printf 'the page with the key is at http://%s:%s/#key=%s\n' \
                "$lan_page_link_host" "$server_port" \
                "$(sed -n '1p' "$state_directory/api.key")"
        fi
    fi
fi
if [ "$bind_host" = 127.0.0.1 ] || [ "$bind_host" = localhost ]; then
    printf 'reachable at http://127.0.0.1:%s (loopback only)\n' "$server_port"
else
    printf 'reachable at http://%s:%s\n' "$(hostname)" "$server_port"
    for address in $(hostname -I 2>/dev/null); do
        case $address in
            *:*) continue ;;
        esac
        printf 'reachable at http://%s:%s\n' "$address" "$server_port"
    done
fi
# The approval broker binds the loopback literal on an ordinary launch, so that
# launch reaches it through an SSH forward rather than through the addresses
# above. Under QWEN_WEB_LAN=1 it binds the wildcard and admits the exposure
# literal in a Host header, so the address a page reaches it at is that literal
# and the Web UI bearer is what it requires there. It is reported where the
# marker set it running.
if [ "${QWEN_WEB_BROKER:-0}" = 1 ]; then
    if [ "${QWEN_WEB_LAN:-0}" = 1 ] && [ -n "${QWEN_WEB_LAN_ADDRESS:-}" ]; then
        if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ]; then
            printf 'approval broker at http://%s:%s (session secret, no bearer)\n' \
                "${QWEN_WEB_LAN_NAME:-$QWEN_WEB_LAN_ADDRESS}" \
                "${QWEN_WEB_BROKER_PORT:-8571}"
        else
            printf 'approval broker at http://%s:%s (bearer required)\n' \
                "${QWEN_WEB_LAN_NAME:-$QWEN_WEB_LAN_ADDRESS}" \
                "${QWEN_WEB_BROKER_PORT:-8571}"
        fi
    else
        printf 'approval broker at http://127.0.0.1:%s (loopback only)\n' \
            "${QWEN_WEB_BROKER_PORT:-8571}"
    fi
fi
printf 'stop it with %s/qwen-teardown.sh\n' "$script_directory"
