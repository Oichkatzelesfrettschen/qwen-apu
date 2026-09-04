#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
llama_server=${1:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-server"}
model_path=${2:-"${HOME:?}/models/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf"}
static_path=${3:-"$script_directory/../webui"}
# The 4K allocation rung consumes 2,724 MiB of measured Vulkan memory and uses
# the admitted 4,096 MiB preflight gate. Interactive serving starts from that
# measured APU rung instead of importing another host's placement profile.
context_size=${4:-4096}
required_vulkan_mib=${5:-4096}
server_port=${6:-8080}
state_directory=${7:-"${HOME:?}/qwen-webui-state"}
vulkan_profile=${8:-low-serialized}

umask 077
# Every python child of this session imports its modules from the runtime tree,
# and an import writes bytecode beside them, which check-runtime-tree.sh reads
# as a stray at the next launch: the manifest names tracked files alone, so no
# sync ships or removes a .pyc. The session exports the setting for the broker,
# the image service, the search instance, and the capacity server, and
# llama-server passes its own environment to the MCP child it spawns.
PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE
mkdir -p "$state_directory"
mkdir -p "$state_directory/telemetry"
server_log=$state_directory/server.log
# Telemetry is an evidentiary surface, so each session owns a session-unique
# record no later session writes to. A shared telemetry.log erased the triggering
# mem_available_kib sample of a recorded memory_reserve_breached abort, which
# left the enforced invariant correct and its measurement unquotable. The
# symlink keeps the convenience path pointing at the newest record.
telemetry_directory=$state_directory/telemetry
telemetry_symlink=$state_directory/telemetry.log
telemetry_log=$telemetry_symlink
graphics_latency_log=$state_directory/graphics-latency.log
kernel_hazard_log=$state_directory/kernel-hazards.log
pid_file=$state_directory/server.pid
status_file=$state_directory/session.status
api_key_file=$state_directory/api.key
monitor_pid=""
latency_watchdog_pid=""
kernel_hazard_watchdog_pid=""
server_pid=""
broker_pid=""
router_preset_snapshot=''
# The approval broker signs one search grant per human approval and holds no
# device, so it is a guarded child of this session the way the probe, the
# monitor, and the kernel-hazard watcher are. qwen-web-launch.sh sets
# QWEN_WEB_BROKER=1; the ordinary launch leaves it unset and starts no broker.
broker_enabled=${QWEN_WEB_BROKER:-0}
broker_program=${QWEN_WEB_BROKER_PROGRAM:-"$script_directory/web-mcp/authorize-broker.py"}
broker_port=${QWEN_WEB_BROKER_PORT:-8571}
broker_state_directory=${QWEN_WEB_STATE_DIR:-"$state_directory/web-mcp"}
broker_log=$state_directory/authorize-broker.log
# QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS is the operator's explicit decision
# to serve this lane on the network, admitted by remote/web-lan-exposure.sh
# before the launch reached this session. The literal rather than QWEN_BIND_HOST
# is what every derived value reads: the router may bind the wildcard, which
# names no address a browser sends as an Origin and no address a Host header
# comparison can admit. The broker and the artifact listener bind the wildcard
# under the exposure, so the loopback stays reachable for this session's own
# probes and for remote/image-review.py, while their Host and bearer gates
# carry the policy.
#
# QWEN_WEB_LAN_NAME carries the mDNS name beside the literal, and the page is
# reachable at either, so the broker and the artifact listener admit both in a
# Host header and admit both page origins through CORS. QWEN_WEB_LAN_OPEN=1
# removes the Web UI bearer from all three listeners together, which leaves the
# closed Host set, the Origin allowlist, the per-launch session secret, and the
# single-use grant carrying the whole gate.
lan_exposure=${QWEN_WEB_LAN:-0}
lan_address=${QWEN_WEB_LAN_ADDRESS:-}
lan_name=${QWEN_WEB_LAN_NAME:-}
lan_open=${QWEN_WEB_LAN_OPEN:-0}
lan_open_all_interfaces=${QWEN_WEB_LAN_OPEN_ALL_INTERFACES:-0}
lan_ifindex=${QWEN_WEB_LAN_IFINDEX:-}
lan_ifname=${QWEN_WEB_LAN_IFNAME:-}
lan_mac=${QWEN_WEB_LAN_MAC:-}
lan_prefixlen=${QWEN_WEB_LAN_PREFIXLEN:-}
lan_nm_uuid=${QWEN_WEB_LAN_NM_UUID:-}
lan_nm_name=${QWEN_WEB_LAN_NM_NAME:-}
if [ "$lan_exposure" = 1 ] && [ -n "$lan_address" ]; then
    # remote/web-lan-exposure.sh has already resolved QWEN_BIND_HOST to the
    # exposure literal or, under the explicit all-interfaces opt-in, the
    # wildcard; the router, the broker, and the artifact listener share that
    # one bind so a peer and this session's own probes reach all three
    # through the same address.
    lan_listen_host=${QWEN_BIND_HOST:-$lan_address}
    lan_page_host=$lan_address
else
    lan_exposure=0
    lan_address=''
    lan_name=''
    lan_open=0
    lan_open_all_interfaces=0
    lan_ifindex=''
    lan_ifname=''
    lan_mac=''
    lan_prefixlen=''
    lan_nm_uuid=''
    lan_nm_name=''
    lan_listen_host=127.0.0.1
    lan_page_host=127.0.0.1
fi
lan_boundary=lan-authenticated
if [ "$lan_exposure" = 1 ] && [ "$lan_open" = 1 ]; then
    lan_boundary=lan-open-approved
fi
# The host a browser loaded the page from is the Origin it sends, so a launch
# advertising two hosts admits two origins. authorize-broker.py reads
# QWEN_WEB_BROKER_ORIGIN as a comma-separated list and image-service.py takes
# one --origin per entry.
lan_page_origin="http://$lan_page_host:$server_port"
lan_name_origin=''
if [ -n "$lan_name" ]; then
    lan_name_origin="http://$lan_name:$server_port"
fi
# QWEN_WEB_BROKER_ORIGIN and QWEN_IMAGE_PAGE_ORIGIN let a caller replace the
# derived origin, which connect-qwen-webui.sh's own recommended loopback value
# does for its SSH tunnel. Under the LAN exposure that override names a page
# the broker and the artifact listener never admit, since neither reads an
# origin outside the set it was started with: the browser sends the exposed
# host as its Origin, the listener answers 403, and no approval can complete.
# The comparison is the exact origin string rather than the bare host, because
# a scheme or port that departs from $lan_page_origin or $lan_name_origin --
# `https://` in place of `http://`, or a port other than $server_port --
# recreates the same 403 the derived origin never triggers. An override is
# refused here rather than left to fail at the first request, and the check
# runs only where the exposure is active, since a loopback launch has no
# conflicting origin to name.
require_lan_admitted_origin() {
    if [ "$2" = "$lan_page_origin" ]; then
        return 0
    fi
    if [ -n "$lan_name_origin" ] && [ "$2" = "$lan_name_origin" ]; then
        return 0
    fi
    printf '%s names an origin the LAN exposure does not admit: %s\n' \
        "$1" "$2" >&2
    printf 'admitted origins: %s%s\n' \
        "$lan_page_origin" "${lan_name_origin:+, $lan_name_origin}" >&2
    printf 'set %s to one of them, or leave it unset so the session derives it\n' \
        "$1" >&2
    exit 2
}
if [ "$lan_exposure" = 1 ] && [ -n "${QWEN_WEB_BROKER_ORIGIN:-}" ]; then
    lan_broker_origin_rest=$QWEN_WEB_BROKER_ORIGIN
    while [ -n "$lan_broker_origin_rest" ]; do
        lan_broker_origin_entry=${lan_broker_origin_rest%%,*}
        case $lan_broker_origin_rest in
            *,*) lan_broker_origin_rest=${lan_broker_origin_rest#*,} ;;
            *) lan_broker_origin_rest='' ;;
        esac
        require_lan_admitted_origin QWEN_WEB_BROKER_ORIGIN "$lan_broker_origin_entry"
    done
fi
if [ "$lan_exposure" = 1 ] && [ -n "${QWEN_IMAGE_PAGE_ORIGIN:-}" ]; then
    require_lan_admitted_origin QWEN_IMAGE_PAGE_ORIGIN "$QWEN_IMAGE_PAGE_ORIGIN"
fi
# The open opt-in reaches both listeners as one flag, expanded from a variable
# so an unset value contributes no empty argument under `set -u`.
lan_open_flag=''
if [ "$lan_open" = 1 ]; then
    lan_open_flag=--open-lan
fi
lan_all_interfaces_flag=''
if [ "$lan_open_all_interfaces" = 1 ]; then
    lan_all_interfaces_flag=--open-all-interfaces
fi
# Compose the page URL for one admitted host. The companions are named as
# query parameters over that same host, so a page loaded by name reaches the
# broker and the artifact listener by name and a page loaded by address reaches
# them by address; each stays inside the Host set and the Origin allowlist the
# two listeners were started with.
compose_lan_page_url() {
    compose_lan_host=$1
    compose_lan_url="http://$compose_lan_host:$server_port/?broker=$(printf \
        'http%%3A%%2F%%2F%s%%3A%s' "$compose_lan_host" "$broker_port")"
    if [ -n "$image_service_listener" ]; then
        compose_lan_url="$compose_lan_url&artifacts=$(printf \
            'http%%3A%%2F%%2F%s%%3A%s' "$compose_lan_host" \
            "${image_service_listener##*:}")"
    fi
    printf '%s' "$compose_lan_url"
}
broker_origin=${QWEN_WEB_BROKER_ORIGIN:-"$lan_page_origin${lan_name_origin:+,$lan_name_origin}"}
# The general-search endpoint is one local SearXNG instance, and it holds no
# device and reaches the network only for a search the broker already signed,
# so it is a guarded child of this session beside the broker.
# qwen-web-launch.sh sets QWEN_WEB_SEARXNG=1 for a profile whose provider
# column reads searxng; every other launch leaves it unset and starts none.
searxng_pid=""
searxng_enabled=${QWEN_WEB_SEARXNG:-0}
searxng_program=${QWEN_SEARXNG_PROGRAM:-"$script_directory/searxng-launch.sh"}
searxng_port=${QWEN_SEARXNG_PORT:-8888}
searxng_log=$state_directory/searxng.log
# The instance loads its engine set before it answers, and the same deadline
# bounds remote/searxng-launch.sh's own start path, so one variable states how
# long a launch waits for it.
searxng_start_timeout=${QWEN_SEARXNG_START_TIMEOUT:-120}
case $searxng_start_timeout in
    '' | *[!0-9]*) searxng_start_timeout=120 ;;
esac
# The teardown deadline for the guarded child, the same variable and default
# remote/searxng-launch.sh's own stop path reads.
searxng_stop_timeout=${QWEN_SEARXNG_STOP_TIMEOUT:-15}
case $searxng_stop_timeout in
    '' | *[!0-9]*) searxng_stop_timeout=15 ;;
esac
# The image service owns the Vulkan workload lease and the pinned image
# runtime, and it allocates nothing on the device until a job arrives, so it is
# a guarded child of this session beside the broker. qwen-image-launch.sh sets
# QWEN_IMAGE_SERVICE=1; every other launch leaves it unset and starts none.
image_service_pid=""
image_service_enabled=${QWEN_IMAGE_SERVICE:-0}
image_service_program=${QWEN_IMAGE_SERVICE_PROGRAM:-"$script_directory/image-service.py"}
image_service_profiles_json=${QWEN_IMAGE_PROFILES_JSON:-}
image_service_origin=${QWEN_IMAGE_PAGE_ORIGIN:-"$lan_page_origin"}
# The artifact listener takes an ephemeral port on a loopback launch, where the
# session's own status line is the reader. An exposed launch binds one port
# above the broker unless the caller names another, so the page URL a LAN
# browser keeps stays the same across relaunches and the page derives the
# artifact origin from the address it was loaded over.
if [ "${QWEN_WEB_LAN:-0}" = 1 ]; then
    image_service_http_port=${QWEN_IMAGE_HTTP_PORT:-$((${QWEN_WEB_BROKER_PORT:-8571} + 1))}
else
    image_service_http_port=${QWEN_IMAGE_HTTP_PORT:-0}
fi
image_service_log=$state_directory/image-service.log
case ${QWEN_ROUTER_PRESETS:-} in
    "$state_directory"/.router-presets.active.*)
        router_preset_snapshot=$QWEN_ROUTER_PRESETS
        ;;
esac

cleanup() {
    if [ -n "$monitor_pid" ]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "$latency_watchdog_pid" ]; then
        kill "$latency_watchdog_pid" 2>/dev/null || true
        wait "$latency_watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$kernel_hazard_watchdog_pid" ]; then
        kill "$kernel_hazard_watchdog_pid" 2>/dev/null || true
        wait "$kernel_hazard_watchdog_pid" 2>/dev/null || true
    fi
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    # The broker removes its per-launch session secret while unwinding from
    # SIGTERM, so it is signalled and waited for rather than left to the
    # process group: a killed broker leaves that file for the next launch.
    if [ -n "$broker_pid" ]; then
        kill "$broker_pid" 2>/dev/null || true
        wait "$broker_pid" 2>/dev/null || true
    fi
    # The image service unlinks its socket and releases the workload lease
    # while unwinding from SIGTERM, and a killed one leaves both for the next
    # launch to meet, so it is signalled and waited for the same way.
    if [ -n "$image_service_pid" ]; then
        kill "$image_service_pid" 2>/dev/null || true
        wait "$image_service_pid" 2>/dev/null || true
    fi
    # The instance holds the loopback port the next launch's own health gate
    # reads, so it is signalled and waited for rather than left to the process
    # group. The production session invokes searxng-launch.sh serve directly
    # rather than through its own bounded start/stop actions, so this trap is
    # where an instance stuck handling SIGTERM -- an unhealthy startup, most
    # plausibly -- would otherwise hold the whole session's cleanup open;
    # terminate_guarded_child bounds it the way searxng-launch.sh bounds its
    # own stop and startup-timeout paths.
    if [ -n "$searxng_pid" ]; then
        terminate_guarded_child "$searxng_pid" "$searxng_stop_timeout"
    fi
    if [ -n "$router_preset_snapshot" ]; then
        rm -f -- "$router_preset_snapshot"
        router_preset_snapshot=''
    fi
}
terminate_session() {
    signal_status=$1
    cleanup
    trap - EXIT HUP INT TERM
    exit "$signal_status"
}
trap cleanup EXIT
trap 'terminate_session 129' HUP
trap 'terminate_session 130' INT
trap 'terminate_session 143' TERM

process_running() {
    process_pid=$1
    [ -n "$process_pid" ] || return 1
    kill -0 "$process_pid" 2>/dev/null || return 1
    [ -r "/proc/$process_pid/stat" ] || return 1
    process_state=$(sed 's/^.*) //' "/proc/$process_pid/stat" | awk '{ print $1 }')
    [ "$process_state" != Z ] && [ "$process_state" != X ]
}

# A guarded child that ignores or is stuck handling SIGTERM must not hold the
# EXIT trap open indefinitely, so termination is bounded by a deadline with a
# SIGKILL escalation past it, the same shape searxng-launch.sh's own `stop`
# and startup-timeout paths apply to the process it owns directly.
terminate_guarded_child() {
    terminate_pid=$1
    terminate_timeout=${2:-15}
    kill "$terminate_pid" 2>/dev/null || true
    terminate_waited=0
    while [ "$terminate_waited" -lt "$terminate_timeout" ] && \
        process_running "$terminate_pid"; do
        sleep 1
        terminate_waited=$((terminate_waited + 1))
    done
    if process_running "$terminate_pid"; then
        kill -KILL "$terminate_pid" 2>/dev/null || true
    fi
    wait "$terminate_pid" 2>/dev/null || true
}

require_broker_running() {
    if [ "$broker_enabled" = 1 ] && ! process_running "$broker_pid"; then
        printf 'state=failed reason=authorization_broker_exited broker_pid=%s utc=%s\n' \
            "$broker_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    if [ "$image_service_enabled" = 1 ] && \
        ! process_running "$image_service_pid"; then
        printf 'state=failed reason=image_service_exited image_service_pid=%s utc=%s\n' \
            "$image_service_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    if [ "$searxng_enabled" = 1 ] && ! process_running "$searxng_pid"; then
        printf 'state=failed reason=searxng_exited searxng_pid=%s utc=%s\n' \
            "$searxng_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
}

if [ -s "$pid_file" ]; then
    prior_pid=$(sed -n '1p' "$pid_file")
    case $prior_pid in
        '' | *[!0-9]*) prior_pid=0 ;;
    esac
    if [ "$prior_pid" -gt 0 ] && kill -0 "$prior_pid" 2>/dev/null; then
        printf 'qwen Web UI server is already running with PID %s\n' "$prior_pid" >&2
        exit 2
    fi
fi

# QWEN_REQUIRE_API_KEY=1 mints a key and makes llama-server demand it. The
# default serves without one, because this deployment is a local model on a
# trusted network and a key there only stands between a reader and the page.
if [ "${QWEN_REQUIRE_API_KEY:-0}" = 1 ]; then
    if [ ! -s "$api_key_file" ]; then
        if ! command -v openssl >/dev/null 2>&1; then
            printf 'openssl is required to create the Web UI API key\n' >&2
            exit 1
        fi
        openssl rand -hex 32 >"$api_key_file"
    fi
    chmod 600 "$api_key_file"
else
    api_key_file=''
fi

printf 'state=starting utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"

# The broker starts ahead of the capacity server because model loading occupies
# the readiness loop for up to 120 seconds and the broker allocates nothing on
# the device: starting it first bounds the window in which the page is reachable
# while the endpoint that signs its approvals is absent. Every failure path
# below leaves through the EXIT trap, which stops it.
#
# The listener is the loopback literal the broker itself admits, and the page
# that reads the session secret is named by Origin rather than by another
# setting: the served page is the one this session binds, so its origin comes
# from QWEN_BIND_HOST and the served port. The signing key travels as a path in
# the environment and its contents stay in the broker's own address space.
# The search instance starts ahead of the broker and the capacity server for
# the reason the broker does, and it needs the head start most: it loads its
# engine set over the two cores this machine has, in about 1.3 CPU-seconds
# measured over startup and six queries.
#
# Readiness is the two facts together. `GET /healthz` proves a socket answers
# on the port the profile row names, and process liveness proves the socket
# belongs to this launch's own child: a foreign instance already on the port
# answers the route while the child leaves on EADDRINUSE, and the pair refuses
# that launch rather than recording a PID nothing owns. qwen-web-launch.sh
# requires the port free before it reaches this session, so the race is
# ordinarily a refusal one link earlier.
searxng_start_time=''
searxng_url="http://127.0.0.1:$searxng_port"
if [ "$searxng_enabled" = 1 ]; then
    if [ ! -x "$searxng_program" ]; then
        printf 'state=failed reason=searxng_unavailable path=%s utc=%s\n' \
            "$searxng_program" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    : >"$searxng_log"
    chmod 600 "$searxng_log"
    QWEN_SEARXNG_PORT=$searxng_port \
        "$searxng_program" serve "$state_directory" \
        >"$searxng_log" 2>&1 &
    searxng_pid=$!
    if ! process_running "$searxng_pid"; then
        printf 'state=failed reason=searxng_exited searxng_pid=%s utc=%s\n' \
            "$searxng_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    searxng_start_time=$(sed 's/^.*) //' "/proc/$searxng_pid/stat" |
        awk '{ print $20 }')
    # The identity is recorded before the readiness wait rather than after it,
    # so a teardown that arrives while this loop is still polling reads the
    # pid, start time, and port off this file instead of finding only the
    # generic `state=starting` line the broker block below would otherwise
    # leave in place until health succeeds.
    {
        printf 'state=starting searxng_pid=%s utc=%s\n' \
            "$searxng_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'searxng_identity pid=%s start_time=%s port=%s url=%s\n' \
            "$searxng_pid" "$searxng_start_time" "$searxng_port" "$searxng_url"
    } >"$status_file"
    searxng_ready=0
    # The loop is bounded by elapsed wall-clock time rather than by attempt
    # count: each curl below can consume its own --max-time before the loop
    # sleeps and counts an attempt, so an attempt-counted loop against a
    # stalling connection can run for the timeout multiplied by the curl
    # budget instead of the timeout itself. The deadline is computed once and
    # each request's own timeout is capped to what remains of it.
    searxng_deadline=$(($(date +%s) + searxng_start_timeout))
    while [ "$(date +%s)" -lt "$searxng_deadline" ]; do
        if ! kill -0 "$searxng_pid" 2>/dev/null; then
            break
        fi
        searxng_remaining=$((searxng_deadline - $(date +%s)))
        [ "$searxng_remaining" -gt 0 ] || break
        searxng_curl_timeout=$searxng_remaining
        [ "$searxng_curl_timeout" -le 5 ] || searxng_curl_timeout=5
        # `curl -f` reads the status line: an instance that binds its port and
        # answers 503 is one the launch waits out rather than admits.
        if curl -fsS --max-time "$searxng_curl_timeout" -o /dev/null \
            "$searxng_url/healthz" 2>/dev/null; then
            searxng_ready=1
            break
        fi
        sleep 0.1
    done
    if [ "$searxng_ready" -ne 1 ]; then
        printf 'state=failed reason=searxng_not_answering port=%s utc=%s\n' \
            "$searxng_port" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
fi

broker_start_time=''
broker_signing_key_sha256=''
if [ "$broker_enabled" = 1 ]; then
    if [ ! -x "$broker_program" ]; then
        printf 'state=failed reason=authorization_broker_unavailable path=%s utc=%s\n' \
            "$broker_program" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    # One broker signs for one profile, and a grant it signs names that
    # profile, so the session refuses to start a broker for no profile rather
    # than for `default`, a name no preset section carries. The signing key is
    # read here as a digest alone: the broker reports the digest of the key it
    # loaded on /health, and the comparison below proves the child signs with
    # the file this launch named.
    if [ -z "${QWEN_WEB_PROFILE:-}" ]; then
        printf 'state=failed reason=authorization_broker_profile_unset utc=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    if [ ! -f "${QWEN_WEB_TOKEN_KEY_FILE:-}" ] || [ ! -r "$QWEN_WEB_TOKEN_KEY_FILE" ]; then
        printf 'state=failed reason=authorization_broker_signing_key_unreadable utc=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    broker_signing_key_sha256=$(sha256sum "$QWEN_WEB_TOKEN_KEY_FILE" | cut -c1-64)
    mkdir -p "$broker_state_directory"
    chmod 700 "$broker_state_directory"
    : >"$broker_log"
    chmod 600 "$broker_log"
    QWEN_WEB_STATE_DIR=$broker_state_directory \
    QWEN_WEB_BROKER_ORIGIN=$broker_origin \
        "$broker_program" --host "$lan_listen_host" --port "$broker_port" \
        ${lan_address:+--lan-exposure "$lan_address"} \
        ${lan_name:+--lan-name "$lan_name"} \
        ${lan_open_flag:+"$lan_open_flag"} \
        ${lan_all_interfaces_flag:+"$lan_all_interfaces_flag"} \
        --state-dir "$broker_state_directory" \
        --profile "$QWEN_WEB_PROFILE" \
        --image-profile "${QWEN_IMAGE_PROFILE:-}" \
        --provider "${QWEN_WEB_PROVIDER:-exa}" \
        --api-key-file "$api_key_file" \
        >"$broker_log" 2>&1 &
    broker_pid=$!
    if ! process_running "$broker_pid"; then
        printf 'state=failed reason=authorization_broker_exited broker_pid=%s utc=%s\n' \
            "$broker_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    broker_start_time=$(sed 's/^.*) //' "/proc/$broker_pid/stat" | awk '{ print $20 }')
    {
        printf 'state=starting broker_pid=%s utc=%s\n' \
            "$broker_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'broker secret_file=%s\n' \
            "$broker_state_directory/authorize-session.secret"
        printf 'broker_identity pid=%s start_time=%s profile=%s image_profile=%s provider=%s signing_key_sha256=%s\n' \
            "$broker_pid" "$broker_start_time" "$QWEN_WEB_PROFILE" \
            "${QWEN_IMAGE_PROFILE:--}" \
            "${QWEN_WEB_PROVIDER:-exa}" "$broker_signing_key_sha256"
    } >"$status_file"

    broker_ready=0
    attempt=0
    while [ "$attempt" -lt 300 ]; do
        if grep -F "listening $lan_listen_host $broker_port" "$broker_log" \
            >/dev/null 2>&1; then
            broker_ready=1
            break
        fi
        if ! kill -0 "$broker_pid" 2>/dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    if [ "$broker_ready" -ne 1 ]; then
        printf 'state=failed reason=authorization_broker_not_listening port=%s utc=%s\n' \
            "$broker_port" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    # The `listening` line proves a socket; `GET /health` proves the process
    # behind it is this launch's broker, serving this profile and provider and
    # signing with this key. A stale broker on the same port from an earlier
    # launch answers the line's grep and fails the pid comparison here.
    # The wildcard bind answers everywhere, so the loopback is the shortest
    # path to it; a single-address bind answers on that address alone, and
    # that address is not the loopback authorize-broker.py's own peer-address
    # exemption reads. The probe therefore presents the Web UI bearer the same
    # way a LAN reader would, through a curl config file on stdin rather than
    # argv, so the key never reaches this process's own `/proc/PID/cmdline`.
    # An unauthenticated launch (`api_key_file` empty) sends the same request
    # with no config, which is the loopback probe's own request shape.
    if [ "$lan_listen_host" = 0.0.0.0 ]; then
        broker_probe_host=127.0.0.1
    else
        broker_probe_host=$lan_listen_host
    fi
    broker_health=$(
        if [ -n "$api_key_file" ] && [ -s "$api_key_file" ]; then
            printf 'header = "Authorization: Bearer %s"\n' "$(cat "$api_key_file")"
        fi |
            curl -sS --max-time 5 -H "Host: $broker_probe_host" -K - \
                "http://$broker_probe_host:$broker_port/health" \
                2>>"$broker_log" || true
    )
    health_field() {
        printf '%s' "$broker_health" | tr -d '\n' |
            sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p"
    }
    health_pid=$(health_field pid)
    health_profile=$(health_field profile)
    health_image_profile=$(health_field image_profile)
    health_provider=$(health_field provider)
    health_key=$(health_field signing_key_sha256)
    health_start_time=$(health_field start_time)
    health_mismatch=''
    [ "$health_pid" = "$broker_pid" ] || health_mismatch="pid=$health_pid"
    [ "$health_profile" = "$QWEN_WEB_PROFILE" ] || \
        health_mismatch="$health_mismatch profile=$health_profile"
    # The image lane the launch armed is the lane the broker signs for. A
    # broker that loaded another image profile, or none, would refuse every
    # approved generation at the first grant rather than at startup.
    [ "$health_image_profile" = "${QWEN_IMAGE_PROFILE:-}" ] || \
        health_mismatch="$health_mismatch image_profile=$health_image_profile"
    [ "$health_provider" = "${QWEN_WEB_PROVIDER:-exa}" ] || \
        health_mismatch="$health_mismatch provider=$health_provider"
    [ "$health_key" = "$broker_signing_key_sha256" ] || \
        health_mismatch="$health_mismatch signing_key=mismatch"
    case $health_start_time in
        '' | *[!0-9]*) health_mismatch="$health_mismatch start_time=absent" ;;
        "$broker_start_time") ;;
        *) health_mismatch="$health_mismatch start_time=$health_start_time" ;;
    esac
    if [ -n "$health_mismatch" ]; then
        printf 'state=failed reason=authorization_broker_identity_mismatch port=%s mismatch=%s utc=%s\n' \
            "$broker_port" "$(printf '%s' "$health_mismatch" | sed 's/^ //; s/ /,/g')" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
fi

# The image service starts here for the reason the broker does: it allocates
# nothing on the device until a job arrives, where model loading holds the
# readiness loop for up to 120 seconds, so starting it first bounds the window
# in which the page is reachable and the executor its approvals name is absent.
# The `socket` line the service prints proves it bound the control socket; the
# start time recorded beside its pid is what binds the number to this process,
# since a pid is reused once its process exits.
image_service_start_time=''
image_service_socket=''
image_service_listener=''
if [ "$image_service_enabled" = 1 ]; then
    if [ ! -r "$image_service_program" ]; then
        printf 'state=failed reason=image_service_unavailable path=%s utc=%s\n' \
            "$image_service_program" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            >"$status_file"
        exit 1
    fi
    if [ ! -r "${image_service_profiles_json:-}" ]; then
        printf 'state=failed reason=image_service_profiles_unreadable path=%s utc=%s\n' \
            "${image_service_profiles_json:-<unset>}" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    : >"$image_service_log"
    chmod 600 "$image_service_log"
    python3 "$image_service_program" \
        --state-dir "$state_directory" \
        --profiles-json "$image_service_profiles_json" \
        --verifier image_signed_verifier:verify \
        --api-key-file "$api_key_file" \
        --origin "$image_service_origin" \
        ${lan_name_origin:+--origin "$lan_name_origin"} \
        --http-host "$lan_listen_host" \
        --http-port "$image_service_http_port" \
        ${lan_address:+--lan-exposure "$lan_address"} \
        ${lan_name:+--lan-name "$lan_name"} \
        ${lan_open_flag:+"$lan_open_flag"} \
        ${lan_all_interfaces_flag:+"$lan_all_interfaces_flag"} \
        >"$image_service_log" 2>&1 &
    image_service_pid=$!
    image_service_ready=0
    attempt=0
    while [ "$attempt" -lt 300 ]; do
        if grep '^socket ' "$image_service_log" >/dev/null 2>&1; then
            image_service_ready=1
            break
        fi
        if ! kill -0 "$image_service_pid" 2>/dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    if [ "$image_service_ready" -ne 1 ]; then
        printf 'state=failed reason=image_service_not_listening log=%s utc=%s\n' \
            "$image_service_log" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
        exit 1
    fi
    image_service_start_time=$(sed 's/^.*) //' "/proc/$image_service_pid/stat" |
        awk '{ print $20 }')
    image_service_socket=$(sed -n 's/^socket //p' "$image_service_log" |
        sed -n '1p')
    # The artifact listener binds an ephemeral port by default, so its host and
    # port are read from the line the service printed rather than assumed.
    image_service_listener=$(sed -n 's/^listening //p' "$image_service_log" |
        sed -n '1p' | tr ' ' ':')
fi

# The swap baseline precedes the spawn, so swap-in during the first weight
# mapping lands inside the first sample's delta rather than ahead of it.
loading_page_size=$(getconf PAGESIZE)
loading_previous_pswpin=$(awk '$1 == "pswpin" { print $2 }' /proc/vmstat)

# The session owns the state directory, so it names the one the Vulkan workload
# lease lives in; qwen-capacity-policy.sh derives the lock path from it and
# image-service.py opens the same file under its own --state-dir.
QWEN_VULKAN_PROFILE=$vulkan_profile \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
"$script_directory/run-qwen-capacity-server.sh" \
    "$llama_server" "$model_path" "$context_size" "$required_vulkan_mib" \
    "$server_port" "$static_path" "$api_key_file" >"$server_log" 2>&1 &
server_pid=$!
printf '%s\n' "$server_pid" >"$pid_file"
# Start ticks bind every loading-phase termination to this exact process, so
# a recycled PID after an early server death is left alone. The second PID
# file line carries them for the control script's stop path, which otherwise
# binds its SIGTERM by command name alone.
server_start_ticks=$(sed 's/^.*) //' "/proc/$server_pid/stat" 2>/dev/null |
    awk '{ print $20 }') || :
if [ -n "$server_start_ticks" ]; then
    printf '%s\n' "$server_start_ticks" >>"$pid_file" || :
fi

# The record name carries start time, checkpoint, and server PID, so two
# sessions never collide and an aborted session's samples survive every later
# launch. Naming happens at spawn because the loading phase performs the
# session's one-time Vulkan allocation and transfer peak, which the runtime
# monitor never sees: it arms only after readiness. The readiness loop below
# samples that phase into a session-unique loading record. MemAvailable
# legitimately falls while the model streams in, so the loading phase enforces
# the same reserve floor and swap-in ceiling the serving monitor holds rather
# than any load-shape heuristic: a load that crosses the desktop's 4 GiB
# reserve or swaps past 64 MiB in one sample is the load a larger checkpoint
# must not survive on this machine, and the termination binds to the recorded
# PID and start ticks so a recycled PID is left alone.
telemetry_session_name=$(date -u +%Y%m%dT%H%M%SZ)-$(basename "$model_path" .gguf | tr -c 'A-Za-z0-9._-' '-')-pid$server_pid
telemetry_log=$telemetry_directory/$telemetry_session_name.log
telemetry_loading_log=$telemetry_directory/$telemetry_session_name-loading.log
"$script_directory/preserve-legacy-telemetry.sh" \
    "$telemetry_symlink" "$telemetry_directory" >/dev/null
ln -sfn "telemetry/$telemetry_session_name.log" "$telemetry_symlink"
loading_gpu_device_directory=${QWEN_GPU_DEVICE_DIRECTORY:-/sys/class/drm/card1/device}
printf 'loading_start_utc=%s server_pid=%s model=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$server_pid" \
    "$(basename "$model_path")" >"$telemetry_loading_log"

record_loading_sample() {
    loading_rss_kib=$(awk '$1 == "VmRSS:" { print $2 }' \
        "/proc/$server_pid/status" 2>/dev/null) || return 0
    loading_peak_rss_kib=$(awk '$1 == "VmHWM:" { print $2 }' \
        "/proc/$server_pid/status" 2>/dev/null) || return 0
    loading_mem_available_kib=$(awk '$1 == "MemAvailable:" { print $2 }' /proc/meminfo)
    loading_vram_used_bytes=-
    loading_gtt_used_bytes=-
    if [ -r "$loading_gpu_device_directory/mem_info_vram_used" ]; then
        loading_vram_used_bytes=$(cat "$loading_gpu_device_directory/mem_info_vram_used")
    fi
    if [ -r "$loading_gpu_device_directory/mem_info_gtt_used" ]; then
        loading_gtt_used_bytes=$(cat "$loading_gpu_device_directory/mem_info_gtt_used")
    fi
    loading_current_pswpin=$(awk '$1 == "pswpin" { print $2 }' /proc/vmstat)
    loading_swapin_bytes=$(( (loading_current_pswpin - loading_previous_pswpin) \
        * loading_page_size ))
    loading_previous_pswpin=$loading_current_pswpin
    printf 'loading_sample_utc=%s rss_kib=%s peak_rss_kib=%s mem_available_kib=%s swapin_bytes=%s vram_used_bytes=%s gtt_used_bytes=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$loading_rss_kib" \
        "$loading_peak_rss_kib" "$loading_mem_available_kib" \
        "$loading_swapin_bytes" \
        "$loading_vram_used_bytes" "$loading_gtt_used_bytes" \
        >>"$telemetry_loading_log" || :
}

# The loading record outlives a load that dies or is terminated before
# readiness, so its terminal classification and seal happen here for every
# pre-readiness exit path rather than in the session finalization the exit
# skips.
finalize_loading_record() {
    printf 'loading_terminal=%s utc=%s\n' "$1" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$telemetry_loading_log" || :
    chmod 444 "$telemetry_loading_log" 2>/dev/null || :
}

# The loading phase holds the serving monitor's own thresholds; the breach
# terminates the exact process the session spawned and leaves a finalized
# loading record carrying the reason.
loading_minimum_mem_available_kib=4194304
loading_maximum_swapin_bytes_per_sample=67108864
terminate_loading_server() {
    printf 'loading_breach=%s phase=loading mem_available_kib=%s swapin_bytes=%s utc=%s\n' \
        "$1" "$loading_mem_available_kib" "$loading_swapin_bytes" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$telemetry_loading_log" || :
    loading_current_ticks=$(sed 's/^.*) //' "/proc/$server_pid/stat" 2>/dev/null |
        awk '{ print $20 }') || :
    if [ -n "$loading_current_ticks" ] && \
        [ "$loading_current_ticks" = "$server_start_ticks" ]; then
        kill "$server_pid" 2>/dev/null || :
    fi
    wait "$server_pid" 2>/dev/null || :
    finalize_loading_record "$1"
    printf 'state=failed reason=%s phase=loading utc=%s\n' \
        "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    server_pid=""
    exit 1
}

ready_for_monitor=0
attempt=0
inference_cpu=${QWEN_INFERENCE_CPU:-0}
# Model loading performs one-time Vulkan allocation and transfer work before the
# HTTP service can accept inference. Arm the service-latency watchdog only after
# llama-server reports itself ready, while still requiring the runtime CPU
# policy before admitting the session.
#
# A router reports readiness differently because it loads nothing at startup: it
# binds the port and waits for a request to name a model. Waiting for the
# single-model marker there times out against a server that is already serving,
# and the session tears down a healthy listener.
readiness_marker='model loaded'
if [ "${QWEN_ROUTER:-0}" = 1 ]; then
    readiness_marker='starting server in router mode'
fi
while [ "$attempt" -lt 1200 ]; do
    require_broker_running
    if ! kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    affinity=$(awk '$1 == "Cpus_allowed_list:" { print $2 }' \
        "/proc/$server_pid/status" 2>/dev/null) || affinity=''
    nice_value=$(sed 's/^.*) //' "/proc/$server_pid/stat" 2>/dev/null |
        awk '{ print $17 }')
    if [ "$affinity" = "$inference_cpu" ] && [ "$nice_value" = 19 ] && \
       grep -F "$readiness_marker" "$server_log" >/dev/null 2>&1; then
        ready_for_monitor=1
        break
    fi
    if [ $((attempt % 10)) = 0 ]; then
        record_loading_sample
        if [ -n "${loading_mem_available_kib:-}" ]; then
            if [ "$loading_mem_available_kib" -lt \
                "$loading_minimum_mem_available_kib" ]; then
                terminate_loading_server memory_reserve_breached
            fi
            if [ "$loading_swapin_bytes" -gt \
                "$loading_maximum_swapin_bytes_per_sample" ]; then
                terminate_loading_server swapin_rate_breached
            fi
        fi
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
record_loading_sample
printf 'loading_end_utc=%s ready=%s attempts=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ready_for_monitor" "$attempt" \
    >>"$telemetry_loading_log" || :

if [ "$ready_for_monitor" -ne 1 ]; then
    loading_terminal_classification=server_policy_not_active
    if ! kill -0 "$server_pid" 2>/dev/null; then
        loading_terminal_classification=server_exited
    fi
    finalize_loading_record "$loading_terminal_classification"
    printf 'state=failed reason=server_policy_not_active utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    wait "$server_pid" 2>/dev/null || true
    server_pid=""
    exit 1
fi

latency_probe=${QWEN_VULKAN_LATENCY_PROBE:-"$script_directory/../build/vulkan-graphics-service-probe"}
# RADV LOW global priority, CPU 0, and nice 19 are what yield the desktop the
# machine; the probe measures whether that yielding actually happens rather
# than enforcing it. The 24K ladder puts p99.9 fence service at 21,302 us
# against the 20,000 us deadline, so the deadline sits near the 99.56th
# percentile and a late frame arrives about every 3.6 seconds under load.
# `terminate` therefore ends any sustained session within seconds and is
# retained only for deliberately strict runs; `observe` counts the same
# breaches, leaves them in the log, and lets the session serve.
latency_probe_mode=${QWEN_LATENCY_MODE:-observe}
case $latency_probe_mode in
    terminate) latency_probe_mode_argument='' ;;
    observe) latency_probe_mode_argument='--observe' ;;
    *)
        printf 'QWEN_LATENCY_MODE must be terminate or observe: %s\n' \
            "$latency_probe_mode" >&2
        exit 2
        ;;
esac
if [ ! -x "$latency_probe" ]; then
    printf 'state=failed reason=graphics_latency_probe_unavailable path=%s utc=%s\n' \
        "$latency_probe" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

: >"$graphics_latency_log"
(
    unset AMD_PRIORITY DISPLAY WAYLAND_DISPLAY
    export VK_DRIVER_FILES=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
    export VK_ICD_FILENAMES=$VK_DRIVER_FILES
    exec taskset -c 1 ionice -c 3 "$latency_probe" \
        --log "$graphics_latency_log" --watch-pid "$server_pid" \
        --interval-ms 16 --deadline-us 20000 $latency_probe_mode_argument
) &
latency_watchdog_pid=$!

latency_ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    require_broker_running
    if grep -F 'probe_start ' "$graphics_latency_log" >/dev/null 2>&1; then
        latency_ready=1
        break
    fi
    if ! kill -0 "$latency_watchdog_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$latency_ready" -ne 1 ]; then
    printf 'state=failed reason=graphics_latency_probe_not_ready utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

"$script_directory/watch-qwen-kernel-hazards.sh" \
    "$server_pid" "$kernel_hazard_log" &
kernel_hazard_watchdog_pid=$!

kernel_watch_ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    require_broker_running
    if grep -F 'watch_ready_utc=' "$kernel_hazard_log" >/dev/null 2>&1; then
        kernel_watch_ready=1
        break
    fi
    if ! kill -0 "$kernel_hazard_watchdog_pid" 2>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if [ "$kernel_watch_ready" -ne 1 ]; then
    printf 'state=failed reason=kernel_hazard_watchdog_not_ready utc=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
    exit 1
fi

# The record was named at spawn beside its loading-phase log. The monitor
# truncates its own argument, which is still a fresh file: loading samples
# live in the -loading record beside it.
"$script_directory/monitor-qwen-runtime.sh" "$server_pid" "$telemetry_log" \
    "$vulkan_profile" "$latency_watchdog_pid" \
    "$kernel_hazard_watchdog_pid" &
monitor_pid=$!
require_broker_running
# The paced profile uses the aggregate busy ceiling. The serialized LOW
# profile uses the MEDIUM graphics-family deadline as its responsiveness gate.
#
# broker_pid appears on this line only where a broker runs, so its absence is
# what the ordinary launch records: qwen-teardown.sh reads the field to signal
# the process and to decide whether the session secret is its own to prove gone.
broker_status_field=''
if [ -n "$broker_pid" ]; then
    broker_status_field=" broker_pid=$broker_pid"
fi
# image_service_pid appears on the same line for the same reason: the teardown
# reads the first line to signal the process and to decide whether the socket,
# the lease, and the partial artifacts are its own to prove gone.
if [ -n "$image_service_pid" ]; then
    broker_status_field="$broker_status_field image_service_pid=$image_service_pid"
fi
# searxng_pid joins them for the same reason: the teardown reads the first line
# to signal the process, and the port it holds is what the next launch's health
# gate meets.
if [ -n "$searxng_pid" ]; then
    broker_status_field="$broker_status_field searxng_pid=$searxng_pid"
fi
# The exposure joins the same line because the status file is what a later
# reader consults for what this launch serves, and the address on the network
# is the one field a teardown, a status query, and an operator all read.
# lan_exposure=0 records the loopback default.
broker_status_field="$broker_status_field lan_exposure=$lan_exposure lan_address=${lan_address:--} lan_name=${lan_name:--} lan_open=$lan_open lan_boundary=$lan_boundary"
printf 'state=running server_pid=%s monitor_pid=%s latency_watchdog_pid=%s kernel_hazard_watchdog_pid=%s%s profile=%s host=%s port=%s context=%s latency_mode=%s utc=%s\n' \
    "$server_pid" "$monitor_pid" "$latency_watchdog_pid" \
    "$kernel_hazard_watchdog_pid" "$broker_status_field" "$vulkan_profile" \
    "${QWEN_BIND_HOST:-127.0.0.1}" "$server_port" "$context_size" \
    "$latency_probe_mode" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
# The speculation settings occupy a second line because the control script and
# the teardown script both read the first line alone, the teardown to recover
# the guard PIDs before `stop` rewrites the file.
printf 'speculation spec_type=%s draft_n_max=%s draft_p_min=%s draft_backend_sampling=%s backend_sampling=%s\n' \
    "${QWEN_SPEC_TYPE:-off}" "${QWEN_SPEC_DRAFT_N_MAX:-default}" \
    "${QWEN_SPEC_DRAFT_P_MIN:-default}" \
    "${QWEN_SPEC_BACKEND_SAMPLING:-0}" "${QWEN_BACKEND_SAMPLING:-0}" >>"$status_file"
# The cache triple lands on a third line for the same reason, and it records
# `registry` where the row supplied the value, so a retained status file
# distinguishes an experiment arm from the served default.
printf 'cache cache_type_k=%s cache_type_v=%s flash_attention=%s override_context_ceiling=%s\n' \
    "${QWEN_CACHE_TYPE_K:-registry}" "${QWEN_CACHE_TYPE_V:-registry}" \
    "${QWEN_FLASH_ATTN:-registry}" \
    "${QWEN_CACHE_OVERRIDE_CONTEXT_CEILING:-registry}" >>"$status_file"
# Router state lands on a fourth line. A router listener serves several
# checkpoints behind one port and spawns a child process per loaded model, so a
# retained status file that named only the default model would describe one of
# the processes running rather than the service.
printf 'router enabled=%s presets=%s preset_sha256=%s models_max=%s\n' \
    "${QWEN_ROUTER:-0}" \
    "${QWEN_ROUTER_PRESETS:-default}" \
    "${QWEN_ROUTER_PRESET_SHA256:-unbound}" \
    "${QWEN_ROUTER_MAX:-1}" >>"$status_file"
# The broker's session secret lands on a fifth line, whole, because
# QWEN_WEB_STATE_DIR reaches this session alone and a teardown run as a bare
# command would otherwise re-derive the default path and prove the absence of a
# file the broker never wrote there. A line of its own carries a directory
# holding a space, which the space-delimited first line splits.
if [ -n "$broker_pid" ]; then
    printf 'broker secret_file=%s\n' \
        "$broker_state_directory/authorize-session.secret" >>"$status_file"
    # The broker's process start time lands on a sixth line, so a teardown
    # signals the process that /health identified rather than whatever
    # process later holds the same number: a PID is reused after the broker
    # exits, and its start time in /proc/PID/stat is what tells the two apart.
    printf 'broker_identity pid=%s start_time=%s profile=%s provider=%s signing_key_sha256=%s\n' \
        "$broker_pid" "$broker_start_time" "$QWEN_WEB_PROFILE" \
        "${QWEN_WEB_PROVIDER:-exa}" "$broker_signing_key_sha256" >>"$status_file"
fi
# The image service's identity lands after the same truncating write the
# broker's does, because `state=running` rewrites this file rather than
# appending to it. The start time is what binds the pid to the process a
# teardown signals, and the socket and listener are what a later reader reaches
# the control channel and the artifact routes through.
if [ -n "$image_service_pid" ]; then
    printf 'image_service_identity pid=%s start_time=%s socket=%s listener=%s\n' \
        "$image_service_pid" "$image_service_start_time" \
        "${image_service_socket:-unrecorded}" \
        "${image_service_listener:-unrecorded}" >>"$status_file"
fi
# The exposure lands as a page URL rather than a list of addresses, because the
# page resolves the broker and the artifact origins from `?broker=` and
# `?artifacts=` before it reads its meta tags, and those tags name the loopback:
# a LAN browser handed the bare router address would point both back at its own
# machine. The artifact listener takes an ephemeral port, so this line is the
# first place all three addresses are known together.
#
# The mDNS name leads where the launch resolved one, because a DHCP lease moves
# the literal and the name a browser bookmarks outlives it. Both hosts are
# admitted, so the literal follows on its own field and each URL names its own
# host in every parameter it carries.
if [ "$lan_exposure" = 1 ]; then
    lan_page_url=$(compose_lan_page_url "$lan_page_host")
    lan_primary_host=$lan_page_host
    lan_primary_page_url=$lan_page_url
    if [ -n "$lan_name" ]; then
        lan_primary_host=$lan_name
        lan_primary_page_url=$(compose_lan_page_url "$lan_name")
    fi
    printf 'lan_exposure address=%s name=%s open=%s boundary=%s router=%s:%s broker=%s:%s artifacts=%s page=%s page_address=%s\n' \
        "$lan_page_host" "${lan_name:--}" "$lan_open" "$lan_boundary" \
        "$lan_primary_host" "$server_port" \
        "$lan_primary_host" "$broker_port" \
        "${image_service_listener:--}" \
        "$lan_primary_page_url" "$lan_page_url" >>"$status_file"
    # The interface carrying the exposure literal identifies the link an
    # operator plugged this appliance into, sanitized to <mac> wherever this
    # line is copied into committed evidence; the NetworkManager fields read
    # `-` where the host runs no NetworkManager connection for the interface.
    printf 'lan_interface ifindex=%s ifname=%s mac=%s prefixlen=%s nm_uuid=%s nm_name=%s all_interfaces=%s\n' \
        "${lan_ifindex:--}" "${lan_ifname:--}" "${lan_mac:--}" \
        "${lan_prefixlen:--}" "${lan_nm_uuid:--}" "${lan_nm_name:--}" \
        "$lan_open_all_interfaces" >>"$status_file"
    if [ "$lan_open" = 1 ]; then
        printf 'lan_open=1 every peer on this network can chat, approve a search, and approve a generation\n' \
            >>"$status_file"
    fi
fi
# The search instance's identity lands after the same truncating write. The
# start time binds the pid to the process a teardown signals, and the port is
# recorded rather than re-derived, so the teardown proves the listener this
# session started is gone rather than whichever port a later default names.
if [ -n "$searxng_pid" ]; then
    printf 'searxng_identity pid=%s start_time=%s port=%s url=%s\n' \
        "$searxng_pid" "$searxng_start_time" "$searxng_port" \
        "$searxng_url" >>"$status_file"
fi

supervised_component=server
while process_running "$server_pid"; do
    if ! process_running "$monitor_pid"; then
        supervised_component=monitor
        break
    fi
    if ! process_running "$latency_watchdog_pid"; then
        supervised_component=latency_watchdog
        break
    fi
    if ! process_running "$kernel_hazard_watchdog_pid"; then
        supervised_component=kernel_hazard_watchdog
        break
    fi
    if [ -n "$broker_pid" ] && ! process_running "$broker_pid"; then
        supervised_component=authorization_broker
        break
    fi
    if [ -n "$searxng_pid" ] && ! process_running "$searxng_pid"; then
        supervised_component=searxng
        break
    fi
    sleep 0.1
done
if [ "$supervised_component" != server ]; then
    printf 'state=failed reason=%s_exited utc=%s\n' \
        "$supervised_component" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status_file"
fi
# The kernel watcher owns the final drain after the server exits. Signalling the
# watcher here can discard a reset already buffered by dmesg --follow-new and
# can suppress its terminal watch_stop marker. Stop every other component, then
# wait for the watcher to observe server exit and finish its own drain.
for supervised_pid in "$server_pid" "$monitor_pid" "$latency_watchdog_pid" \
        "$broker_pid" "$searxng_pid"; do
    [ -n "$supervised_pid" ] || continue
    kill "$supervised_pid" 2>/dev/null || true
done
set +e
wait "$server_pid"
server_status=$?
wait "$monitor_pid"
monitor_status=$?
wait "$latency_watchdog_pid"
latency_status=$?
wait "$kernel_hazard_watchdog_pid"
kernel_hazard_status=$?
broker_status=0
if [ -n "$broker_pid" ]; then
    wait "$broker_pid"
    broker_status=$?
fi
searxng_status=0
if [ -n "$searxng_pid" ]; then
    wait "$searxng_pid"
    searxng_status=$?
fi
set -e
server_pid=""
monitor_pid=""
latency_watchdog_pid=""
kernel_hazard_watchdog_pid=""
broker_pid=""
searxng_pid=""
session_status=$server_status
if [ "$supervised_component" != server ]; then
    session_status=1
fi
if [ "$kernel_hazard_status" -ne 0 ]; then
    session_status=1
fi
# The summary derives from the finished record, which then loses its write bit.
# Mode 0444 seals the record against ordinary rewriting rather than making it
# immutable: the owner restores the bit at will, so the durable guarantee is
# the session-unique name plus the retained digest, and stronger immutability
# would need fs-verity or a hash anchored outside this directory.
#
# Both steps are advisory, because `tmux kill-session` ends this script without
# reaching them. Their outcome is recorded rather than discarded, since a
# swallowed failure leaves finalization status unknowable.
telemetry_summary_status=skipped
telemetry_seal_status=skipped
if QWEN_TELEMETRY_MODEL_PATH=$model_path \
    QWEN_TELEMETRY_MODEL_ID=$(basename "$model_path" .gguf) \
    "$script_directory/summarize-telemetry-session.sh" "$telemetry_log" \
    >/dev/null 2>&1; then
    telemetry_summary_status=written
else
    telemetry_summary_status=failed
fi
if chmod 444 "$telemetry_log" 2>/dev/null; then
    telemetry_seal_status=sealed
else
    telemetry_seal_status=failed
fi
telemetry_loading_seal_status=absent
if [ -n "${telemetry_loading_log:-}" ] && [ -f "$telemetry_loading_log" ]; then
    if chmod 444 "$telemetry_loading_log" 2>/dev/null; then
        telemetry_loading_seal_status=sealed
    else
        telemetry_loading_seal_status=failed
    fi
fi
# The line carries the session name as its own field, so a reader joins a
# finalization outcome to one session without parsing the record path, and the
# guarded append keeps a full or read-only state directory from turning the
# advisory report into a teardown abort under set -e.
# runtime_status carries the server's own verdict beside the advisory
# outcomes, so a failed summary or seal never rewrites a successful service
# result and a reader rejecting incomplete evidence has both facts on one line.
printf 'session=%s telemetry_record=%s summary=%s seal=%s loading_seal=%s runtime_status=%s utc=%s\n' \
    "${telemetry_session_name:-unnamed}" \
    "$telemetry_log" "$telemetry_summary_status" "$telemetry_seal_status" \
    "$telemetry_loading_seal_status" "$session_status" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >>"$state_directory/telemetry-finalization.log" || :
printf 'state=stopped server_status=%s monitor_status=%s latency_status=%s kernel_hazard_status=%s broker_status=%s searxng_status=%s stopped_component=%s profile=%s utc=%s\n' \
    "$server_status" "$monitor_status" "$latency_status" \
    "$kernel_hazard_status" "$broker_status" "$searxng_status" \
    "$supervised_component" \
    "$vulkan_profile" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$status_file"
exit "$session_status"
