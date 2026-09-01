#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s start [paced-60|low-serialized|low-async]|status|stop|key\n' \
        "$0" >&2
    exit 2
fi

action=$1
# The submission sweep measured low-async at 2.718 decode tok/s against 1.348
# serialized on a chat request, with zero deadline breaches and 100.00% of probe
# submissions inside one 60 Hz frame in both. Serialization costs half the
# decode rate and buys nothing back under this workload. low-serialized remains
# for sustained long-context prefill, where the depth ladder measured async
# raising probe p90 8.6-fold.
profile=${2:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
campaign_lock_descriptor_helper=$script_directory/open-verified-lock-descriptor.py
tmux_socket=qwen-runtime
tmux_session=qwen-webui
# qwen-runtime was created from a fresh SSH login after render/video group
# repair. Reusing its separate tmux server preserves offscreen Vulkan access
# without inheriting the older qwen-admin server's supplementary group set.
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
# The served depth is the operational ceiling, admitted by the measured 24K
# allocation of 2,974 MiB against this gate. QWEN_BIND_HOST and
# QWEN_LATENCY_MODE reach the session script, so `start` reproduces the
# deployed listener instead of a loopback server the documentation would then
# contradict.
context_size=${QWEN_CONTEXT_SIZE:-24576}
required_vulkan_mib=${QWEN_REQUIRED_VULKAN_MIB:-4608}
bind_host=${QWEN_BIND_HOST:-127.0.0.1}
latency_mode=${QWEN_LATENCY_MODE:-observe}
server_port=${QWEN_SERVER_PORT:-8080}
# llama-ui is a SvelteKit build produced on a machine with Node and copied here
# as static files, so the laptop serves it without a build toolchain or a second
# process. QWEN_STATIC_PATH selects it against the hand-written diagnostic page.
# The distill and the base model share the Qwen3.5-4B architecture, so a model
# swap is an argument rather than an edit. The distill is the text default: it
# reasons in 43.3% of the base model's tokens and reaches an answer 2.71 times
# faster across the five-prompt suite. It ships text-only, so the vision profile
# names the base checkpoint, whose projector travels beside it.
model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf"}
# remote/promote-llama-build.sh gates a preset and points build-appliance-current
# at it in one rename, so switching build arms or rolling one back leaves this
# script untouched. The named directory is what the appliance was built with
# before presets existed, and it serves until a promotion happens.
llama_source_directory=${QWEN_LLAMA_SOURCE_DIRECTORY:-"${HOME:?}/src/llama.cpp-qwen-apu"}
llama_server=${QWEN_LLAMA_SERVER:-}
# An activated deployment bundle binds the server and the checkpoint ledger
# it was verified against, so deployment-current outranks the build symlinks
# and carries its own ledger into the capacity policy; an explicit
# QWEN_LLAMA_SERVER or QWEN_CTX_CHECKPOINT_LEDGER still wins, and a machine
# without a deployment root keeps the promote-chain defaults unchanged.
deployment_current=${QWEN_DEPLOYMENT_ROOT:-"${HOME:?}/qwen-deployments"}/deployment-current
if [ -z "$llama_server" ] && { [ -e "$deployment_current" ] || \
    [ -L "$deployment_current" ]; }; then
    # A deployment link that exists names the selected release, so a dangling
    # link, a missing server, or an unreadable ledger refuses the start rather
    # than silently serving whatever the build symlinks name instead.
    if [ ! -x "$deployment_current/llama-server" ]; then
        printf 'deployment-current exists but its llama-server is not executable: %s\n' \
            "$deployment_current/llama-server" >&2
        exit 1
    fi
    if [ ! -r "$deployment_current/ctx-checkpoints.tsv" ]; then
        printf 'deployment-current exists but its ctx-checkpoints.tsv is unreadable: %s\n' \
            "$deployment_current/ctx-checkpoints.tsv" >&2
        exit 1
    fi
    llama_server=$deployment_current/llama-server
    if [ -z "${QWEN_CTX_CHECKPOINT_LEDGER:-}" ]; then
        QWEN_CTX_CHECKPOINT_LEDGER=$deployment_current/ctx-checkpoints.tsv
        export QWEN_CTX_CHECKPOINT_LEDGER
    fi
fi
if [ -z "$llama_server" ]; then
    llama_server=$llama_source_directory/build-appliance-current/bin/llama-server
    if [ ! -x "$llama_server" ]; then
        llama_server=$llama_source_directory/build-qwen-vulkan/bin/llama-server
    fi
fi
static_path=${QWEN_STATIC_PATH:-"$script_directory/../webui-llama-ui"}
if [ ! -f "$static_path/index.html" ]; then
    static_path=$script_directory/../webui
fi
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status
campaign_control_lock=$state_directory/fixed64-served-campaign.lock
ordinary_lease_record=$state_directory/ordinary-session-control-lease.tsv

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

process_start_time() {
    process_identity_pid=$1
    sed 's/^.*) //' "/proc/$process_identity_pid/stat" 2>/dev/null |
        awk '{ print $20 }'
}

run_child_without_ordinary_lease_descriptor() (
    # Dash saves a simple-command redirection in the calling shell, which can
    # move descriptor 9 until the child exits. A subshell keeps the holder's
    # descriptor number stable while the child receives a closed copy.
    exec 9>&-
    exec "$@"
)

hold_ordinary_session_lease() {
    holder_ready_path=$1
    holder_identity_path=$2
    holder_record_path=$3
    holder_controller_pid=$4
    holder_controller_start_time=$5
    holder_tmux_socket=$6
    holder_tmux_session=$7

    cleanup_ordinary_session_lease() {
        run_child_without_ordinary_lease_descriptor rm -f -- \
            "$holder_ready_path" "$holder_identity_path" "$holder_record_path"
    }
    trap cleanup_ordinary_session_lease EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    printf 'ready\n' >"$holder_ready_path.new"
    run_child_without_ordinary_lease_descriptor \
        chmod 0600 "$holder_ready_path.new"
    run_child_without_ordinary_lease_descriptor \
        mv -- "$holder_ready_path.new" "$holder_ready_path"

    while [ ! -s "$holder_identity_path" ]; do
        observed_controller_start_time=$(
            exec 9>&-
            sed 's/^.*) //' "/proc/$holder_controller_pid/stat" \
                2>/dev/null | awk '{ print $20 }'
        )
        if [ "$observed_controller_start_time" != "$holder_controller_start_time" ]; then
            exit 1
        fi
        run_child_without_ordinary_lease_descriptor sleep 0.05
    done
    expected_tmux_identity=$(
        exec 9>&-
        sed -n '1p' "$holder_identity_path"
    )
    case $expected_tmux_identity in
        *:*) ;;
        *) exit 1 ;;
    esac

    while :; do
        observed_tmux_identity=$(
            exec 9>&-
            tmux -L "$holder_tmux_socket" display-message -p \
                -t "$holder_tmux_session" \
                '#{session_id}:#{session_created}' 2>/dev/null
        ) || break
        [ "$observed_tmux_identity" = "$expected_tmux_identity" ] || break
        run_child_without_ordinary_lease_descriptor sleep 0.05
    done
}

write_ordinary_lease_record() {
    lease_record_state=$1
    lease_record_tmux_identity=$2
    lease_record_new=$ordinary_lease_record.new
    {
        printf 'key\tvalue\n'
        printf 'schema\tordinary-session-control-lease-v1\n'
        printf 'state\t%s\n' "$lease_record_state"
        printf 'lock_path\t%s\n' "$campaign_control_lock"
        printf 'holder_pid\t%s\n' "$ordinary_lease_holder_pid"
        printf 'holder_start_time_ticks\t%s\n' \
            "$ordinary_lease_holder_start_time"
        printf 'holder_fd\t9\n'
        printf 'controller_pid\t%s\n' "$$"
        printf 'controller_start_time_ticks\t%s\n' \
            "$ordinary_lease_controller_start_time"
        printf 'tmux_socket\t%s\n' "$tmux_socket"
        printf 'tmux_session\t%s\n' "$tmux_session"
        printf 'tmux_identity\t%s\n' "$lease_record_tmux_identity"
    } >"$lease_record_new"
    chmod 0600 "$lease_record_new"
    mv -- "$lease_record_new" "$ordinary_lease_record"
}

case $action in
    start)
        case $profile in
            paced-60 | low-serialized | low-async | custom) ;;
            *)
                printf 'unknown Vulkan profile: %s\n' "$profile" >&2
                exit 2
                ;;
        esac
        # Every start path funnels through here before the tmux session
        # exists, so a divergent or stale runtime tree refuses ahead of the
        # session, the server, the PID file, and the workload lease --
        # including a direct `qwen-webui-control.sh start` that never ran
        # qwen-launch.sh. A tree without a manifest predates
        # sync-runtime-tree.sh and passes as unmanifested.
        "$script_directory/check-runtime-tree.sh" "$script_directory/.." \
            "${QWEN_INTENDED_GIT_HEAD:-}" "${QWEN_INTENDED_PAYLOAD_SHA256:-}"
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            printf 'tmux session already exists: %s\n' "$tmux_session" >&2
            exit 2
        fi
        mkdir -p "$state_directory"
        ordinary_lease_holder_pid=''
        ordinary_lease_identity=''
        if [ -z "${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}" ]; then
            case ${QWEN_FIXED64_CONTROL_LOCK_INHERITED:-0} in
                0)
                    if [ ! -x "$campaign_lock_descriptor_helper" ]; then
                        printf 'campaign lock descriptor helper is absent: %s\n' \
                            "$campaign_lock_descriptor_helper" >&2
                        exit 2
                    fi
                    QWEN_FIXED64_CONTROL_LOCK_INHERITED=1
                    export QWEN_FIXED64_CONTROL_LOCK_INHERITED
                    exec "$campaign_lock_descriptor_helper" open \
                        "$campaign_control_lock" 9 \
                        "$script_directory/qwen-webui-control.sh" "$@"
                    ;;
                1)
                    if ! "$campaign_lock_descriptor_helper" verify \
                            "$campaign_control_lock" 9; then
                        exit 2
                    fi
                    ;;
                *)
                    printf 'campaign lock inheritance marker must be 0 or 1: %s\n' \
                        "$QWEN_FIXED64_CONTROL_LOCK_INHERITED" >&2
                    exit 2
                    ;;
            esac
            set +e
            flock -n -E 75 9
            campaign_lock_status=$?
            set -e
            if [ "$campaign_lock_status" -ne 0 ]; then
                if [ "$campaign_lock_status" -eq 75 ]; then
                    printf 'a fixed-64 measurement window owns the appliance: %s\n' \
                        "$campaign_control_lock" >&2
                else
                    printf 'campaign control lease is unusable (flock exit %s): %s\n' \
                        "$campaign_lock_status" "$campaign_control_lock" >&2
                fi
                exit 2
            fi
            ordinary_lease_controller_start_time=$(process_start_time "$$")
            if [ -z "$ordinary_lease_controller_start_time" ]; then
                printf 'cannot read ordinary-session controller identity\n' >&2
                exit 2
            fi
            ordinary_lease_identity=$state_directory/.ordinary-session-control-lease.$$.identity
            ordinary_lease_ready=$state_directory/.ordinary-session-control-lease.$$.ready
            rm -f -- "$ordinary_lease_identity" "$ordinary_lease_ready" \
                "$ordinary_lease_ready.new"
            hold_ordinary_session_lease "$ordinary_lease_ready" \
                "$ordinary_lease_identity" \
                "$ordinary_lease_record" "$$" \
                "$ordinary_lease_controller_start_time" \
                "$tmux_socket" "$tmux_session" \
                </dev/null >/dev/null 2>&1 &
            ordinary_lease_holder_pid=$!
            ordinary_lease_holder_start_time=$(
                process_start_time "$ordinary_lease_holder_pid"
            )
            ordinary_lease_tmux_started=0
            ordinary_lease_wait_attempt=0
            while [ ! -s "$ordinary_lease_ready" ] && \
                  [ "$ordinary_lease_wait_attempt" -lt 100 ]; do
                if ! kill -0 "$ordinary_lease_holder_pid" 2>/dev/null; then
                    break
                fi
                ordinary_lease_wait_attempt=$((ordinary_lease_wait_attempt + 1))
                sleep 0.01
            done
            # A state-directory symlink gives the same lock object two valid
            # path spellings, so holder ownership follows device and inode.
            ordinary_lease_holder_lock_identity=$(stat -Lc '%d:%i' \
                "/proc/$ordinary_lease_holder_pid/fd/9" 2>/dev/null || true)
            campaign_control_lock_identity=$(stat -Lc '%d:%i' \
                "$campaign_control_lock" 2>/dev/null || true)
            if [ ! -s "$ordinary_lease_ready" ] || \
               [ -z "$ordinary_lease_holder_start_time" ] || \
               [ -z "$ordinary_lease_holder_lock_identity" ] || \
               [ "$ordinary_lease_holder_lock_identity" != \
                   "$campaign_control_lock_identity" ]; then
                printf 'ordinary-session control lease holder failed to start\n' >&2
                kill -TERM "$ordinary_lease_holder_pid" 2>/dev/null || true
                wait "$ordinary_lease_holder_pid" 2>/dev/null || true
                exit 2
            fi
            cleanup_unbound_ordinary_lease() {
                cleanup_status=$?
                trap - EXIT HUP INT TERM
                if [ "$ordinary_lease_tmux_started" -eq 1 ]; then
                    cleanup_tmux_identity=$(
                        exec 9>&-
                        tmux -L "$tmux_socket" display-message -p \
                            -t "$tmux_session" \
                            '#{session_id}:#{session_created}' 2>/dev/null || true
                    )
                    if [ -z "${tmux_identity:-}" ] || \
                       [ "$cleanup_tmux_identity" = "$tmux_identity" ]; then
                        run_child_without_ordinary_lease_descriptor \
                            tmux -L "$tmux_socket" kill-session \
                            -t "$tmux_session" 2>/dev/null || true
                    fi
                fi
                kill -TERM "$ordinary_lease_holder_pid" 2>/dev/null || true
                wait "$ordinary_lease_holder_pid" 2>/dev/null || true
                rm -f -- "$ordinary_lease_identity" "$ordinary_lease_ready" \
                    "$ordinary_lease_record"
                exit "$cleanup_status"
            }
            trap cleanup_unbound_ordinary_lease EXIT
            trap 'exit 129' HUP
            trap 'exit 130' INT
            trap 'exit 143' TERM
            write_ordinary_lease_record awaiting-session -
        fi
        # A launcher polls this file for the new session's verdict. The previous
        # run's last line would otherwise satisfy that poll before the new
        # session writes anything, reporting a stale failure as this one's.
        rm -f "$status_file"
        # tmux runs the new session from its server's environment, not this
        # shell's, so submission settings must travel in the command itself.
        forwarded_environment=''
        # The projector and its image budget must survive the tmux boundary too.
        # Speculation and backend sampling are policy arguments the capacity
        # script reads from the environment, so they cross this boundary with
        # the projector settings rather than reaching the tmux server's own.
        # A fixed-length measurement carries the descriptor-bound model ID,
        # registry filename, and object tuple through the tmux boundary. The
        # capacity policy re-stats the descriptor before selecting one row.
        # The approval broker's marker, port, program, state directory, signing
        # key path, profile, API-key requirement, and readiness decision cross
        # with them. qwen-web-launch.sh exports the values into the control
        # shell, and the session script starts the broker beyond the boundary.
        # The image service's marker, program, profile parameters, page origin,
        # and the three names its MCP child reads cross the same way, because
        # qwen-image-launch.sh exports them into this shell and the session
        # script starts that service beyond the boundary too. QWEN_RADV_ICD
        # crosses with them: image-service.py pins VK_DRIVER_FILES and
        # VK_ICD_FILENAMES for every runtime it spawns and derives both from
        # that name, and a value that stopped at this boundary would leave the
        # service deriving from the default path instead.
        for forwarded_name in QWEN_MMPROJ QWEN_MMPROJ_OFFLOAD QWEN_IMAGE_MAX_TOKENS \
                              QWEN_INFERENCE_CPU QWEN_SPEC_TYPE \
                              QWEN_SPEC_DRAFT_N_MAX QWEN_SPEC_DRAFT_P_MIN \
                              QWEN_SPEC_BACKEND_SAMPLING QWEN_BACKEND_SAMPLING \
                              QWEN_CTX_CHECKPOINTS QWEN_CHECKPOINT_MIN_STEP \
                              QWEN_APPROVED_MODEL_ID \
                              QWEN_APPROVED_MODEL_FILE \
                              QWEN_APPROVED_MODEL_DEVICE \
                              QWEN_APPROVED_MODEL_INODE \
                              QWEN_APPROVED_MODEL_BYTES \
                              QWEN_MODEL_REGISTRY QWEN_QUARANTINE_REGISTRY \
                              QWEN_VALIDATED_TUPLES QWEN_CTX_CHECKPOINT_LEDGER \
                              QWEN_BATCH_SIZE QWEN_UBATCH_SIZE \
                              QWEN_CACHE_TYPE_K QWEN_CACHE_TYPE_V \
                              QWEN_FLASH_ATTN \
                              QWEN_CACHE_OVERRIDE_CONTEXT_CEILING \
                              QWEN_ROUTER QWEN_ROUTER_PRESETS \
                              QWEN_ROUTER_PRESET_SHA256 \
                              QWEN_ROUTER_INCLUDE_QUARANTINE \
                              QWEN_ROUTER_MAX \
                              QWEN_WEB_BROKER QWEN_WEB_BROKER_PORT \
                              QWEN_WEB_BROKER_PROGRAM QWEN_WEB_STATE_DIR \
                              QWEN_WEB_TOKEN_KEY_FILE QWEN_WEB_PROFILE \
                              QWEN_WEB_PROVIDER QWEN_WEB_PROFILES \
                              QWEN_WEB_BROKER_ORIGIN \
                              QWEN_REQUIRE_API_KEY \
                              QWEN_WEB_AUTHORIZER_READY \
                              QWEN_IMAGE_SERVICE QWEN_IMAGE_SERVICE_PROGRAM \
                              QWEN_IMAGE_PROFILES_JSON QWEN_IMAGE_PAGE_ORIGIN \
                              QWEN_IMAGE_PROFILE QWEN_IMAGE_TOKEN_KEY_FILE \
                              QWEN_IMAGE_STATE_DIR \
                              QWEN_IMAGE_SERVICE_SOCKET \
                              QWEN_IMAGE_PRIORITY_WRAPPER \
                              QWEN_IMAGE_LEASE_WAIT_S \
                              QWEN_RADV_ICD \
                              QWEN_VULKAN_LATENCY_PROBE \
                              QWEN_VULKAN_EXTERNAL_LEASE_PROOF; do
            eval "forwarded_value=\${$forwarded_name:-}"
            if [ -n "$forwarded_value" ]; then
                forwarded_environment="$forwarded_environment $forwarded_name=$(shell_quote "$forwarded_value")"
            fi
        done
        for forwarded_name in GGML_VK_MAX_NODES_PER_SUBMIT \
                              GGML_VK_SERIALIZE_SUBMISSIONS \
                              GGML_VK_ALLOW_GRAPHICS_QUEUE \
                              GGML_VK_SUBMIT_TRACE \
                              GGML_VK_DUTY_CYCLE_PERCENT; do
            eval "forwarded_value=\${$forwarded_name:-}"
            if [ -n "$forwarded_value" ]; then
                forwarded_environment="$forwarded_environment $forwarded_name=$(shell_quote "$forwarded_value")"
            fi
        done
        session_command="env$forwarded_environment"
        session_command="$session_command QWEN_BIND_HOST=$(shell_quote "$bind_host")"
        session_command="$session_command QWEN_LATENCY_MODE=$(shell_quote "$latency_mode")"
        for session_argument in \
            "$script_directory/qwen-webui-session.sh" \
            "$llama_server" "$model_path" "$static_path" \
            "$context_size" "$required_vulkan_mib" "$server_port" \
            "$state_directory" "$profile"; do
            session_command="$session_command $(shell_quote "$session_argument")"
        done
        tmux_identity=$(
            exec 9>&-
            tmux -L "$tmux_socket" new-session -d -P \
                -F '#{session_id}:#{session_created}' -s "$tmux_session" \
                "$session_command"
        )
        if [ -n "$ordinary_lease_holder_pid" ]; then
            ordinary_lease_tmux_started=1
        fi
        case $tmux_identity in
            *:*) ;;
            *)
                printf 'tmux returned a malformed session identity: %s\n' \
                    "$tmux_identity" >&2
                exit 2
                ;;
        esac
        if [ -n "$ordinary_lease_holder_pid" ]; then
            write_ordinary_lease_record session-bound "$tmux_identity"
            printf '%s\n' "$tmux_identity" >"$ordinary_lease_identity.new"
            chmod 0600 "$ordinary_lease_identity.new"
            mv -- "$ordinary_lease_identity.new" "$ordinary_lease_identity"
            trap - EXIT HUP INT TERM
            exec 9>&-
        fi
        printf 'started tmux_socket=%s tmux_session=%s profile=%s host=%s port=%s context=%s latency_mode=%s model=%s server=%s\n' \
            "$tmux_socket" "$tmux_session" "$profile" "$bind_host" \
            "$server_port" "$context_size" "$latency_mode" "$model_path" \
            "$llama_server"
        printf 'speculation spec_type=%s draft_n_max=%s draft_p_min=%s draft_backend_sampling=%s backend_sampling=%s\n' \
            "${QWEN_SPEC_TYPE:-off}" "${QWEN_SPEC_DRAFT_N_MAX:-default}" \
            "${QWEN_SPEC_DRAFT_P_MIN:-default}" \
            "${QWEN_SPEC_BACKEND_SAMPLING:-0}" "${QWEN_BACKEND_SAMPLING:-0}"
        printf 'cache cache_type_k=%s cache_type_v=%s flash_attention=%s override_context_ceiling=%s\n' \
            "${QWEN_CACHE_TYPE_K:-registry}" "${QWEN_CACHE_TYPE_V:-registry}" \
            "${QWEN_FLASH_ATTN:-registry}" \
            "${QWEN_CACHE_OVERRIDE_CONTEXT_CEILING:-registry}"
        ;;
    status)
        if [ "$#" -ne 1 ]; then
            printf 'status does not accept a profile\n' >&2
            exit 2
        fi
        recorded_status=state=not-started
        if [ -r "$status_file" ]; then
            recorded_status=$(sed -n '1p' "$status_file")
        fi
        server_running=0
        if [ -r "$pid_file" ]; then
            status_pid=$(sed -n '1p' "$pid_file")
            case $status_pid in
                '' | *[!0-9]*) status_pid=0 ;;
            esac
            if [ "$status_pid" -gt 0 ] && kill -0 "$status_pid" 2>/dev/null && \
               [ "$(ps -o comm= -p "$status_pid" | tr -d ' ')" = llama-server ]; then
                server_running=1
            fi
        fi
        tmux_running=0
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            tmux_running=1
        fi
        case $recorded_status:$server_running:$tmux_running in
            state=running*:0:0)
                printf 'state=stale recorded_status=%s\n' "$recorded_status"
                ;;
            *)
                printf '%s\n' "$recorded_status"
                ;;
        esac
        if [ "$tmux_running" -eq 1 ]; then
            printf 'tmux=running socket=%s session=%s\n' "$tmux_socket" "$tmux_session"
        else
            printf 'tmux=absent socket=%s session=%s\n' "$tmux_socket" "$tmux_session"
        fi
        if [ -r "$state_directory/server.log" ]; then
            printf 'server_log_tail\n'
            tail -n 10 "$state_directory/server.log"
        fi
        if [ -r "$state_directory/telemetry.log" ]; then
            printf 'telemetry_log_tail\n'
            tail -n 5 "$state_directory/telemetry.log"
        fi
        ;;
    key)
        if [ "$#" -ne 1 ]; then
            printf 'key does not accept a profile\n' >&2
            exit 2
        fi
        api_key_file=$state_directory/api.key
        if [ ! -s "$api_key_file" ]; then
            printf 'API key is unavailable; start the session first\n' >&2
            exit 1
        fi
        sed -n '1p' "$api_key_file"
        ;;
    stop)
        if [ "$#" -ne 1 ]; then
            printf 'stop does not accept a profile\n' >&2
            exit 2
        fi
        if [ -r "$pid_file" ]; then
            server_pid=$(sed -n '1p' "$pid_file")
            case $server_pid in
                '' | *[!0-9]*) server_pid=0 ;;
            esac
            # The session records the server's start ticks on the PID file's
            # second line, so the SIGTERM binds to the exact spawned process
            # rather than to a recycled PID that merely shares the command
            # name. A one-line PID file predates the record and keeps the
            # command-name binding alone.
            recorded_start_ticks=$(sed -n '2p' "$pid_file")
            if [ "$server_pid" -gt 0 ] && kill -0 "$server_pid" 2>/dev/null; then
                server_command=$(ps -o comm= -p "$server_pid" | tr -d ' ')
                live_start_ticks=$(sed 's/^.*) //' "/proc/$server_pid/stat" \
                    2>/dev/null | awk '{ print $20 }') || live_start_ticks=''
                if [ "$server_command" != llama-server ]; then
                    printf 'stale PID file names non-llama process %s; leaving it running\n' \
                        "$server_pid" >&2
                elif [ -n "$recorded_start_ticks" ] && \
                    [ "$live_start_ticks" != "$recorded_start_ticks" ]; then
                    printf 'PID %s start ticks %s differ from recorded %s; leaving it running\n' \
                        "$server_pid" "$live_start_ticks" \
                        "$recorded_start_ticks" >&2
                else
                    kill -TERM "$server_pid"
                fi
            fi
        fi
        wait_attempt=0
        while [ "$wait_attempt" -lt 100 ] && \
              tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; do
            wait_attempt=$((wait_attempt + 1))
            sleep 0.1
        done
        if tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
            tmux -L "$tmux_socket" kill-session -t "$tmux_session"
        fi
        printf 'stopped tmux_socket=%s tmux_session=%s\n' \
            "$tmux_socket" "$tmux_session"
        ;;
    *)
        printf 'usage: %s start [paced-60|low-serialized|low-async]|status|stop|key\n' \
            "$0" >&2
        exit 2
        ;;
esac
