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
        printf 'approval broker at http://%s:%s (bearer required)\n' \
            "$QWEN_WEB_LAN_ADDRESS" "${QWEN_WEB_BROKER_PORT:-8571}"
    else
        printf 'approval broker at http://127.0.0.1:%s (loopback only)\n' \
            "${QWEN_WEB_BROKER_PORT:-8571}"
    fi
fi
printf 'stop it with %s/qwen-teardown.sh\n' "$script_directory"
