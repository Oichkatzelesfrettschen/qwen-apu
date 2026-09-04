#!/bin/sh
set -eu

# Admit the web router on the appliance against the live SearXNG instance: the
# production llama-server, a real router child, the approval broker, the MCP
# child, and one local metasearch instance all run, and the searches reach the
# engines that instance holds. The harness owns one outage: it records the
# ordinary router, tears it down, launches one profile from a ledger it writes
# under its own output directory, replays every request the page makes, drives
# the served page itself, tears the test router down, proves absence, and
# restores the ordinary router.
#
# The ledger copy is the checked-in row of remote/web-profiles.tsv with
# execution_policy alone moved to validator-gated, so the model, depth, cache
# tuple, budgets, provider, categories, and minimum_results are the ones the
# repository already validates. The checked-in row stays at refused: it moves
# to validator-gated by an operator edit after a run of this harness is
# retained under evidence/, and nothing here edits the repository.
#
# remote/admit-web-router-fake.sh is the boundary twin of this run and stays
# the authority for the refusals: a replayed grant, a fetch past the allowance,
# a fetch naming a URL, a foreign Origin, a wrong session header, a wrong
# profile_id, an absent or unknown model, and a routing key inside the tool
# arguments are each provoked there against fixtures that answer instantly. The
# structure is shared by shape rather than by a sourced library, because the
# fake run's fixture deadlines, eviction arm, and provider-specific text belong
# to it alone. This run measures what only a live instance can show: which
# engines answer, how many results survive canonicalization, what a query
# costs, and what the instance costs in memory and CPU while it serves.
#
# Every check lands in OUTPUT_DIR/summary.tsv as `check<TAB>result<TAB>detail`.
#
# usage: admit-web-router-live.sh OUTPUT_DIR [PROFILE_ID]
#   QWEN_ADMISSION_QUERY      the one query every arm sends
#   QWEN_SERVER_PORT          router port, default 8080
#   QWEN_WEB_BROKER_PORT      broker port, default 8571
#   QWEN_ADMISSION_RESTORE    0 leaves the appliance down after the run

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s OUTPUT_DIR [PROFILE_ID]\n' "$0" >&2
    exit 2
fi

output_directory=$1
profile_id=${2:-${QWEN_ADMISSION_PROFILE:-web-compact}}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
server_port=${QWEN_SERVER_PORT:-8080}
broker_port=${QWEN_WEB_BROKER_PORT:-8571}
restore=${QWEN_ADMISSION_RESTORE:-1}
registry=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
model_root=${QWEN_MODEL_ROOT:-"$qwen_home_models"}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
checked_in_ledger=${QWEN_WEB_PROFILES:-$script_directory/web-profiles.tsv}
query=${QWEN_ADMISSION_QUERY:-'vulkan compute shader subgroup size'}

# One admission owns the appliance at a time, the rule the fake run applies:
# the script re-executes itself under flock(1), which holds the claim for as
# long as the run lives and releases it with the process on every exit path.
# --close drops the locked descriptor before the run starts, so the servers the
# run launches inherit no lock.
admission_lock=$state_directory/web-admission.lock
if [ "${QWEN_ADMISSION_LOCKED:-}" != "$admission_lock" ]; then
    for lock_tool in flock setsid ps; do
        if ! command -v "$lock_tool" >/dev/null 2>&1; then
            printf '%s is required\n' "$lock_tool" >&2
            exit 2
        fi
    done
    mkdir -p "$state_directory"
    QWEN_ADMISSION_LOCKED=$admission_lock
    export QWEN_ADMISSION_LOCKED
    lock_child_pid=0
    forward_lock_signal() {
        signal_name=$1
        signal_status=$2
        trap - HUP INT TERM
        if [ "$lock_child_pid" -gt 0 ]; then
            kill -s "$signal_name" -- "-$lock_child_pid" 2>/dev/null ||
                kill -s "$signal_name" "$lock_child_pid" 2>/dev/null || true
            wait "$lock_child_pid" 2>/dev/null || true
        fi
        exit "$signal_status"
    }
    trap 'forward_lock_signal HUP 129' HUP
    trap 'forward_lock_signal INT 130' INT
    trap 'forward_lock_signal TERM 143' TERM
    setsid flock -n --close -E 75 "$admission_lock" "$0" "$@" &
    lock_child_pid=$!
    lock_status=0
    wait "$lock_child_pid" || lock_status=$?
    trap - HUP INT TERM
    if [ "$lock_status" -eq 75 ]; then
        printf 'another admission run holds %s\n' "$admission_lock" >&2
    fi
    exit "$lock_status"
fi

router_origin=http://127.0.0.1:$server_port
broker_origin=http://127.0.0.1:$broker_port

for tool in python3 curl jq sha256sum ss pgrep; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '%s is required\n' "$tool" >&2
        exit 2
    fi
done

umask 077
# The harness runs python3 from the runtime tree -- the page driver, the audit
# reader, the key generator -- and an import there writes bytecode the manifest
# never names, which the next launch reads as a stray.
PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE
# A reused directory would combine this run's authorization state and
# measurements with a prior one: only summary.tsv is truncated below, so
# keys/token.key, the web-mcp grant and rate database, and query-timing.tsv
# from an earlier run would otherwise survive into a freshly reported pass.
if [ -e "$output_directory" ] && \
    find "$output_directory" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    printf 'output directory must be empty: %s\n' "$output_directory" >&2
    exit 2
fi
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)
summary=$output_directory/summary.tsv
: >"$summary"
failures=0
restoration_required=0
restoration_finished=0
record() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$summary"
    printf '%s=%s %s\n' "$1" "$2" "$3"
    case $2 in
        pass | observed | skipped) ;;
        *) failures=$((failures + 1)) ;;
    esac
}
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Every request the page would make is retained as a numbered pair, request
# body beside response body, so a failed check names the exchange.
exchange=0
mkdir -p "$output_directory/http"
api_key_curl_config=$output_directory/keys/api-key.curl
api_key_bytes=''
call() {
    exchange=$((exchange + 1))
    call_label=$1
    call_method=$2
    call_url=$3
    call_body=${4:-}
    call_headers_file=$output_directory/http/$exchange-$call_label.headers
    call_out=$output_directory/http/$exchange-$call_label.response
    call_time_file=$output_directory/http/$exchange-$call_label.time
    # dash ends the shell on a shift past $#, so the count is checked first.
    if [ "$#" -ge 4 ]; then
        shift 4
    else
        shift "$#"
    fi
    # The bearer key reaches curl through a config file rather than argv, and
    # the file lives beside the run's own keys at 0600.
    if [ -s "$api_key_curl_config" ] && [ "${call_without_key:-0}" != 1 ]; then
        set -- "$@" --config "$api_key_curl_config"
    fi
    # curl's own %{time_total} carries microsecond precision, so the elapsed
    # time a caller reads off this exchange is the request's actual duration
    # rather than the difference of two whole-second `date +%s` samples taken
    # around it, which for the 180-510 ms searches this instance answers would
    # usually read 0 and could read 1 depending only on whether the call
    # happened to cross a wall-clock second boundary.
    if [ -n "$call_body" ]; then
        printf '%s' "$call_body" >"$output_directory/http/$exchange-$call_label.request"
        curl -sS --max-time 600 -o "$call_out" -D "$call_headers_file" \
            -w '%{time_total}' \
            -X "$call_method" "$call_url" -H 'Content-Type: application/json' \
            --data-binary "@$output_directory/http/$exchange-$call_label.request" \
            "$@" >"$call_time_file" || true
    else
        curl -sS --max-time 60 -o "$call_out" -D "$call_headers_file" \
            -w '%{time_total}' \
            -X "$call_method" "$call_url" "$@" >"$call_time_file" || true
    fi
    call_status=$(sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' "$call_headers_file" 2>/dev/null | tail -1)
    call_status=${call_status:-000}
    call_time_total=$(cat "$call_time_file" 2>/dev/null || true)
    case $call_time_total in
        '' | *[!0-9.]*) call_time_total=0 ;;
    esac
}

remove_api_key_material() {
    rm -f -- "$api_key_curl_config"
    api_key_bytes=''
}
note_exit() {
    exit_status=${1:-$?}
    remove_api_key_material
    if [ "$exit_status" -ne 0 ]; then
        printf 'admission_aborted status=%s utc=%s\n' "$exit_status" "$(utc)" \
            >>"$output_directory/run.log"
    fi
}
trap note_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# 1. The profile row this run serves, read whole from the checked-in ledger.
profile_row=$(awk -F'\t' -v profile="$profile_id" \
    '$1 == profile { print; exit }' "$checked_in_ledger")
if [ -z "$profile_row" ]; then
    printf 'profile %s is absent from %s\n' "$profile_id" "$checked_in_ledger" >&2
    exit 2
fi
profile_field() { printf '%s\n' "$profile_row" | cut -f"$1"; }
model_id=$(profile_field 2)
context=$(profile_field 4)
validated_depth=$(profile_field 5)
max_results=$(profile_field 6)
max_fetches=$(profile_field 7)
provider=$(profile_field 13)
primary_category=$(profile_field 14)
fallback_category=$(profile_field 15)
minimum_results=$(profile_field 16)
searxng_url=$(profile_field 17)
if [ "$provider" != searxng ]; then
    printf 'profile %s names provider %s, and this harness admits the searxng lane\n' \
        "$profile_id" "$provider" >&2
    exit 2
fi
case $searxng_url in
    http://127.0.0.1:[0-9]*) searxng_port=${searxng_url#http://127.0.0.1:} ;;
    *) searxng_port='' ;;
esac
case $searxng_port in
    '' | *[!0-9]*)
        printf 'profile %s names searxng_url %s, and this harness runs the loopback instance\n' \
            "$profile_id" "$searxng_url" >&2
        exit 2
        ;;
esac

record profile_row observed \
    "model=$model_id context=$context max_results=$max_results max_fetches=$max_fetches primary=$primary_category fallback=$fallback_category minimum=$minimum_results url=$searxng_url"

# 2. The ordinary router, as found.
printf 'admission_start utc=%s host=%s profile=%s\n' "$(utc)" "$(uname -n)" \
    "$profile_id" >"$output_directory/run.log"
cp "$state_directory/session.status" "$output_directory/ordinary-session.status" 2>/dev/null || true
# The bind host and the profile are read back from the copy of the ordinary
# session's own status line taken above, rather than assumed, so a router the
# operator bound to the LAN or ran under a non-default profile is probed and
# later restored the way it was found instead of at loopback under
# low-async. Both the as-found probe below and restore_ordinary's own probe
# read this one derivation, so a LAN-only router is never probed at the
# loopback origin its socket never bound.
ordinary_host=$(sed -n '1p' "$output_directory/ordinary-session.status" 2>/dev/null |
    tr ' ' '\n' | sed -n 's/^host=//p')
ordinary_profile=$(sed -n '1p' "$output_directory/ordinary-session.status" 2>/dev/null |
    tr ' ' '\n' | sed -n 's/^profile=//p')
case $ordinary_host in
    '') ordinary_host=127.0.0.1 ;;
esac
case $ordinary_profile in
    paced-60 | low-serialized | low-async) ;;
    *) ordinary_profile=low-async ;;
esac
ordinary_lan=0
case $ordinary_host in
    127.0.0.1 | localhost | 0.0.0.0) ;;
    *) ordinary_lan=1 ;;
esac
ordinary_router_origin=http://$ordinary_host:$server_port
ordinary_running=0
if pgrep -x llama-server >/dev/null 2>&1; then
    ordinary_running=1
    call ordinary-models GET "$ordinary_router_origin/v1/models"
    jq -r '.data[].id' "$call_out" 2>/dev/null | sort >"$output_directory/ordinary-model-ids.txt" || true
    ordinary_server=$(readlink -f "/proc/$(pgrep -x llama-server | head -1)/exe")
else
    ordinary_server=${QWEN_LLAMA_SERVER:-"$qwen_home_llama_server"}
    [ -x "$ordinary_server" ] || \
        ordinary_server=$qwen_home_llama_source/build-qwen-vulkan/bin/llama-server
fi
sha256sum "$ordinary_server" >"$output_directory/ordinary-llama-server.sha256"
record ordinary_router_recorded pass \
    "running=$ordinary_running server=$(cut -c1-16 "$output_directory/ordinary-llama-server.sha256")"

restore_ordinary() {
    if [ "$restoration_finished" = 1 ]; then
        return 0
    fi
    restoration_finished=1
    # The harness's own test router is torn down unconditionally: it is what
    # this run launched, and QWEN_ADMISSION_RESTORE names whether the ordinary
    # router this run found gets relaunched, not whether the test router this
    # run started gets cleaned up. An interrupt before step 13's own teardown
    # reaches only this function, so a restore=0 run that never relaunches must
    # still leave no test llama-server, broker, or search instance behind.
    if pgrep -x llama-server >/dev/null 2>&1; then
        "$script_directory/qwen-teardown.sh" >"$output_directory/pre-restore-teardown.log" 2>&1 || true
    fi
    if [ "$restore" != 1 ]; then
        record ordinary_restore skipped 'QWEN_ADMISSION_RESTORE=0'
        return 0
    fi
    if [ "$ordinary_running" != 1 ]; then
        record ordinary_restore pass 'no ordinary router was running at admission start'
        return 0
    fi
    # ordinary_host, ordinary_profile, and ordinary_lan were derived once,
    # above, from the copy of the ordinary session's own status line taken
    # before this run touched anything, so the restored router is relaunched
    # the way it was found instead of at loopback under low-async.
    #
    # qwen-launch.sh's own readiness probe reaches 127.0.0.1 unless
    # QWEN_WEB_LAN=1 names QWEN_WEB_LAN_ADDRESS, which a plain non-web restore
    # never sets; a server bound to the wildcard or to loopback still answers
    # there, but one bound to one LAN literal alone does not, so a restored
    # server the operator ran on such a literal would fail its own readiness
    # probe and be torn down, trading a stopped appliance for a failed one.
    # Naming the literal here reaches only that probe: the router-side LAN
    # admission gate at qwen-launch.sh's web-section branch is not reached by
    # a preset carrying none.
    if QWEN_LLAMA_SERVER=$ordinary_server QWEN_ROUTER=1 QWEN_BIND_HOST=$ordinary_host \
        QWEN_WEB_LAN=$ordinary_lan QWEN_WEB_LAN_ADDRESS=$ordinary_host \
        "$script_directory/qwen-launch.sh" "$ordinary_profile" \
        >"$output_directory/ordinary-restore.log" 2>&1; then
        restored_server=$(readlink -f "/proc/$(pgrep -x llama-server | head -1)/exe" 2>/dev/null || true)
        call restored-models GET "$ordinary_router_origin/v1/models"
        jq -r '.data[].id' "$call_out" 2>/dev/null | sort >"$output_directory/restored-model-ids.txt" || true
        if [ "$restored_server" != "$ordinary_server" ]; then
            record ordinary_restore fail \
                "server differs expected=$ordinary_server actual=${restored_server:-absent}"
            return 1
        fi
        if [ -s "$output_directory/ordinary-model-ids.txt" ] && \
           ! cmp -s "$output_directory/ordinary-model-ids.txt" \
                "$output_directory/restored-model-ids.txt"; then
            record ordinary_restore fail 'model roster differs from the one found'
            return 1
        fi
        record ordinary_restore pass \
            "host=$ordinary_host profile=$ordinary_profile models=$(tr '\n' ',' <"$output_directory/restored-model-ids.txt")"
    else
        record ordinary_restore fail "$(tail -1 "$output_directory/ordinary-restore.log")"
        return 1
    fi
}

finish_run() {
    exit_status=$?
    trap - EXIT HUP INT TERM
    if [ "$restoration_required" = 1 ] && [ "$restoration_finished" != 1 ]; then
        restore_ordinary || exit_status=1
    fi
    note_exit "$exit_status"
    exit "$exit_status"
}
trap finish_run EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

restoration_required=1
if [ "$ordinary_running" = 1 ]; then
    if "$script_directory/qwen-teardown.sh" >"$output_directory/ordinary-teardown.log" 2>&1; then
        record ordinary_teardown pass 'no residue'
    else
        record ordinary_teardown fail "$(tail -1 "$output_directory/ordinary-teardown.log")"
        exit 1
    fi
fi

# 3. Test inputs: signing key, state directory, the one-row ledger, the preset.
mkdir -p "$output_directory/keys" "$output_directory/web-mcp"
chmod 700 "$output_directory/keys" "$output_directory/web-mcp"
token_key_file=$output_directory/keys/token.key
if [ ! -s "$token_key_file" ]; then
    python3 -c 'import secrets; print(secrets.token_hex(32))' >"$token_key_file"
fi
chmod 600 "$token_key_file"

# Field 12 alone moves: web_mode in field 3 states the intended path and
# execution_policy in field 12 states what is authorized, and the generator
# reads the second. Every other field stays the checked-in row's, so the
# registry join, the copied-field comparison, the tier rule, and the ceiling
# rule all measure the row an operator would later promote.
ledger=$output_directory/web-profiles.tsv
head -n 1 "$checked_in_ledger" >"$ledger" 2>/dev/null || true
grep '^# profile_id' "$checked_in_ledger" >>"$ledger" || true
printf '%s\n' "$profile_row" |
    awk -F'\t' -v OFS='\t' '{ $12 = "validator-gated"; print }' >>"$ledger"

# The web-only admission owns no image runtime, so an all-refused image ledger
# keeps a checked-in validator-gated image row from turning this preset into an
# image configuration with absent authorities.
image_ledger=$output_directory/image-profiles-refused.tsv
awk -F'\t' -v OFS='\t' '
    /^#/ { print; next }
    { $12 = "refused"; $13 = "-"; $14 = "-"; print }
' "$script_directory/image-profiles.tsv" >"$image_ledger"

# A row requesting a depth its registry row has not filled and decoded needs
# the override, and the generated section then carries the experimental tag and
# the unvalidated-depth marker the launch reads.
allow_unvalidated_depth=0
case $validated_depth in
    '' | -) allow_unvalidated_depth=1 ;;
    *[!0-9]*) allow_unvalidated_depth=1 ;;
    *) [ "$context" -le "$validated_depth" ] || allow_unvalidated_depth=1 ;;
esac
record depth_claim observed \
    "context=$context validated_filled_depth=$validated_depth override=$allow_unvalidated_depth"

web_presets=$output_directory/web-presets.ini
if QWEN_WEB_PROFILES=$ledger QWEN_WEB_MCP_SERVER=$script_directory/web-mcp/server.py \
    QWEN_WEB_PROVIDER=searxng \
    QWEN_WEB_TOKEN_KEY_FILE=$token_key_file QWEN_WEB_STATE_DIR=$output_directory/web-mcp \
    QWEN_WEB_AUTHORIZER_READY=1 QWEN_IMAGE_PROFILES=$image_ledger \
    QWEN_WEB_ALLOW_UNVALIDATED_DEPTH=$allow_unvalidated_depth \
    QWEN_MODEL_REGISTRY=$registry QWEN_MODEL_ROOT=$model_root \
    "$script_directory/build-web-presets.sh" "$web_presets" \
    >"$output_directory/build-web-presets.log" 2>&1; then
    record preset_generated pass "$(grep -c '^\[' "$web_presets") section"
else
    record preset_generated fail "$(tail -1 "$output_directory/build-web-presets.log")"
    restore_ordinary
    exit 1
fi
# The section names its MCP configuration and carries none of the policy
# itself, so the four values are read out of that configuration through the
# section rather than grepped from the INI.
read_policy() {
    "$script_directory/read-mcp-server-env.sh" "$web_presets" "$profile_id" \
        web "$1" 2>/dev/null || printf 'absent\n'
}
emitted_url=$(read_policy QWEN_WEB_SEARXNG_URL)
emitted_primary=$(read_policy QWEN_WEB_SEARXNG_PRIMARY_CATEGORY)
emitted_fallback=$(read_policy QWEN_WEB_SEARXNG_FALLBACK_CATEGORY)
emitted_minimum=$(read_policy QWEN_WEB_SEARXNG_MINIMUM_RESULTS)
if [ "$emitted_url" = "$searxng_url" ] && \
   [ "$emitted_primary" = "$primary_category" ] && \
   [ "$emitted_fallback" = "$fallback_category" ] && \
   [ "$emitted_minimum" = "$minimum_results" ]; then
    record preset_carries_search_policy pass \
        "url=$emitted_url primary=$emitted_primary fallback=$emitted_fallback minimum=$emitted_minimum"
else
    record preset_carries_search_policy fail \
        "url=$emitted_url/$searxng_url primary=$emitted_primary/$primary_category fallback=$emitted_fallback/$fallback_category minimum=$emitted_minimum/$minimum_results"
fi

# 4. Launch the test router. The launcher reads the row's searxng_url, refuses
# a busy port, and hands QWEN_WEB_SEARXNG=1 to the session, which starts the
# instance and proves GET /healthz ahead of the capacity server.
if QWEN_WEB_PRESETS=$web_presets QWEN_WEB_PROFILES=$ledger QWEN_WEB_PROVIDER=searxng \
    QWEN_WEB_TOKEN_KEY_FILE=$token_key_file QWEN_WEB_STATE_DIR=$output_directory/web-mcp \
    QWEN_WEB_BROKER_PORT=$broker_port QWEN_WEB_AUTHORIZER_READY=1 \
    QWEN_MODEL_REGISTRY=$registry \
    "$script_directory/qwen-web-launch.sh" low-async \
    >"$output_directory/web-launch.log" 2>&1; then
    record web_launch pass \
        "$(grep '^web_launch' "$output_directory/web-launch.log" | tr '\n' ';')"
    api_key_file=$state_directory/api.key
    if [ -s "$api_key_file" ] && [ "$(stat -c %a "$api_key_file")" = 600 ]; then
        api_key_bytes=$(sed -n '1p' "$api_key_file")
        printf 'header = "Authorization: Bearer %s"\n' "$api_key_bytes" >"$api_key_curl_config"
        chmod 600 "$api_key_curl_config"
        record api_key_minted pass "mode=600 path=$api_key_file"
    else
        record api_key_minted fail "absent, empty, or not 0600: $api_key_file"
    fi
else
    record web_launch fail "$(tail -2 "$output_directory/web-launch.log" | tr '\n' ';')"
    for retained in session.status authorize-broker.log server.log searxng.log; do
        cp "$state_directory/$retained" \
            "$output_directory/failed-$retained" 2>/dev/null || true
    done
    restore_ordinary
    exit 1
fi
cp "$state_directory/session.status" "$output_directory/web-session.status"
cp "$state_directory/searxng.log" "$output_directory/searxng.log" 2>/dev/null || true
broker_pid=$(sed -n '1p' "$output_directory/web-session.status" | tr ' ' '\n' |
    sed -n 's/^broker_pid=//p')
secret_file=$(sed -n 's/^broker secret_file=//p' "$output_directory/web-session.status")

# 5. The instance the session started, and what it costs while it serves. The
# receipts come from /proc rather than from any report the instance makes about
# itself: VmRSS and VmHWM in status, and utime plus stime in stat.
searxng_pid=$(sed -n '1p' "$output_directory/web-session.status" | tr ' ' '\n' |
    sed -n 's/^searxng_pid=//p')
searxng_start_time=$(sed -n 's/^searxng_identity .*start_time=\([0-9]*\) .*/\1/p' \
    "$output_directory/web-session.status")
case $searxng_pid in
    '' | *[!0-9]*)
        record searxng_child_recorded fail "searxng_pid=$searxng_pid"
        ;;
    *)
        record searxng_child_recorded pass \
            "searxng_pid=$searxng_pid start_time=$searxng_start_time port=$searxng_port"
        ;;
esac
searxng_listener=$(ss -ltn 2>/dev/null | grep -o "127\.0\.0\.1:$searxng_port" |
    sort -u | tr '\n' ',')
if [ "$searxng_listener" = "127.0.0.1:$searxng_port," ]; then
    record searxng_listener_loopback pass "$searxng_listener"
else
    record searxng_listener_loopback fail "${searxng_listener:-absent}"
fi
call searxng-health GET "http://127.0.0.1:$searxng_port/healthz"
if [ "$call_status" = 200 ]; then
    record searxng_health pass "status=$call_status"
else
    record searxng_health fail "status=$call_status"
fi
sample_instance_cost() {
    sample_label=$1
    [ -r "/proc/$searxng_pid/status" ] || return 0
    sample_rss=$(awk '$1 == "VmRSS:" { print $2 }' "/proc/$searxng_pid/status")
    sample_peak=$(awk '$1 == "VmHWM:" { print $2 }' "/proc/$searxng_pid/status")
    sample_threads=$(awk '$1 == "Threads:" { print $2 }' "/proc/$searxng_pid/status")
    sample_ticks=$(sed 's/^.*) //' "/proc/$searxng_pid/stat" |
        awk '{ print $12 + $13 }')
    printf '%s\trss_kib=%s\tpeak_rss_kib=%s\tthreads=%s\tcpu_ticks=%s\tutc=%s\n' \
        "$sample_label" "$sample_rss" "$sample_peak" "$sample_threads" \
        "$sample_ticks" "$(utc)" >>"$output_directory/searxng-cost.tsv"
}
: >"$output_directory/searxng-cost.tsv"
sample_instance_cost before-queries

# 6. Router identity and the tool listing, on the router port.
call models GET "$router_origin/v1/models"
model_ids=$(jq -r '.data[].id' "$call_out" 2>/dev/null | tr '\n' ',')
if [ "$model_ids" = "$profile_id," ]; then
    record router_roster pass "$model_ids"
else
    record router_roster fail "$model_ids"
fi
call tools GET "$router_origin/tools?model=$profile_id&autoload=true"
tool_names=$(jq -r '.[].tool' "$call_out" 2>/dev/null | sort | tr '\n' ',')
if [ "$tool_names" = "web_fetch_exa,web_search_exa," ]; then
    record tool_enumeration pass "$tool_names via $router_origin"
else
    record tool_enumeration fail "$tool_names status=$call_status"
fi
cp "$call_out" "$output_directory/tools.json"

# 7. One grant, signed over the exact fields the dialog shows. The temporal
# arguments stay off the body: SearXNGProvider carries neither exact date
# bounds nor a freshness window, and refuse_unhonored_arguments ends such a
# call ahead of the ledger transaction that spends the grant.
call session GET "$broker_origin/session" '' -H "Origin: $router_origin" \
    -H "Host: 127.0.0.1:$broker_port"
session_secret=$(jq -r '.session_secret // empty' "$call_out" 2>/dev/null)
if [ "$call_status" = 200 ] && [ -n "$session_secret" ]; then
    record session_secret_issued pass "status=$call_status"
else
    record session_secret_issued fail "status=$call_status"
fi
grant_body=$(jq -cn --arg q "$query" --arg p "$profile_id" \
    --argjson n "$max_results" \
    '{query: $q, profile_id: $p, max_results: $n, include_domains: [], exclude_domains: []}')
call grant POST "$broker_origin/grant" "$grant_body" -H "Origin: $router_origin" \
    -H "Host: 127.0.0.1:$broker_port" -H "X-Qwen-Web-Session: $session_secret"
authorization=$(jq -r '.authorization // empty' "$call_out" 2>/dev/null)
if [ "$call_status" = 200 ] && [ -n "$authorization" ]; then
    record grant_issued pass "status=$call_status bytes=${#authorization}"
else
    record grant_issued fail "status=$call_status"
fi

# 8. The search reaches the instance, the instance reaches its engines, and the
# reply names both. The count required is the row's own minimum_results, since
# that is the number below which the provider queries the fallback category.
tool_body() {
    jq -cn --arg m "$profile_id" --arg t "$1" --argjson p "$2" \
        '{model: $m, tool: $t, params: $p, stream: false}'
}
search_params=$(jq -cn --arg q "$query" --arg a "$authorization" \
    --argjson n "$max_results" \
    '{query: $q, max_results: $n, include_domains: [], exclude_domains: [], authorization: $a}')
call search POST "$router_origin/tools" "$(tool_body web_search_exa "$search_params")"
search_elapsed=$call_time_total
search_text=$(jq -r 'if type == "object" then (.error // .plain_text_response // tostring) else tostring end' \
    "$call_out" 2>/dev/null)
cp "$call_out" "$output_directory/search-response.json"
printf 'search\tseconds=%s\tstatus=%s\tutc=%s\n' "$search_elapsed" "$call_status" \
    "$(utc)" >>"$output_directory/query-timing.tsv"
result_id=$(printf '%s\n' "$search_text" | sed -n 's/^Result ID: //p' | head -1)
source_lines=$(printf '%s\n' "$search_text" | grep -c '^Sources: ' || true)
result_blocks=$(printf '%s\n' "$search_text" | grep -c '^Result ID: ' || true)
engine_names=$(printf '%s\n' "$search_text" | sed -n 's/^Sources: //p' |
    tr ',' '\n' | tr -d ' ' | sort -u | tr '\n' ',')
if [ "$call_status" = 200 ] && [ -n "$result_id" ] && \
   ! jq -e '.error' "$call_out" >/dev/null 2>&1 && \
   [ "$source_lines" -ge "$minimum_results" ]; then
    record search_executed pass \
        "results=$result_blocks sources=$source_lines minimum=$minimum_results engines=$engine_names elapsed=${search_elapsed}s"
else
    record search_executed fail \
        "status=$call_status results=$result_blocks sources=$source_lines minimum=$minimum_results $(printf '%s' "$search_text" | head -c 160)"
fi
sample_instance_cost after-search

# 9. The fetch redeems one Result ID. A SearXNG answer holds result metadata
# alone, so the provider reads the source itself over one GET of the canonical
# URL the Result ID was signed over.
fetch_params=$(jq -cn --arg r "$result_id" '{result_id: $r}')
call fetch POST "$router_origin/tools" "$(tool_body web_fetch_exa "$fetch_params")"
fetch_elapsed=$call_time_total
fetch_text=$(jq -r 'if type == "object" then (.error // .plain_text_response // tostring) else tostring end' \
    "$call_out" 2>/dev/null)
cp "$call_out" "$output_directory/fetch-response.json"
printf 'fetch\tseconds=%s\tstatus=%s\tutc=%s\n' "$fetch_elapsed" "$call_status" \
    "$(utc)" >>"$output_directory/query-timing.tsv"
if [ "$call_status" = 200 ] && [ "${#fetch_text}" -gt 200 ] && \
   ! jq -e '.error' "$call_out" >/dev/null 2>&1; then
    record fetch_by_result_id pass "chars=${#fetch_text} elapsed=${fetch_elapsed}s"
else
    record fetch_by_result_id fail \
        "status=$call_status chars=${#fetch_text} $(printf '%s' "$fetch_text" | head -c 160)"
fi
sample_instance_cost after-fetch

# 10. The audit row the search wrote carries the engine and category fields and
# holds no query text.
python3 - "$output_directory/web-mcp" "$output_directory/audit-rows.tsv" <<'PY' || true
import glob
import os
import sqlite3
import sys

directory, out = sys.argv[1], sys.argv[2]
with open(out, "w") as handle:
    for path in sorted(
        glob.glob(os.path.join(directory, "*.sqlite*"))
        + glob.glob(os.path.join(directory, "*.db"))
    ):
        try:
            connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            for (name,) in connection.execute(
                "select name from sqlite_master where type='table'"
            ):
                for row in connection.execute(f"select * from {name}"):
                    handle.write(name + "\t" + "\t".join(str(v) for v in row) + "\n")
            connection.close()
        except sqlite3.Error as error:
            handle.write(f"unreadable\t{path}\t{error}\n")
PY
if grep -qF "$primary_category" "$output_directory/audit-rows.tsv" 2>/dev/null && \
   ! grep -qF "$query" "$output_directory/audit-rows.tsv" 2>/dev/null; then
    record audit_names_category_and_holds_no_query pass \
        "category=$primary_category rows=$(wc -l <"$output_directory/audit-rows.tsv" | tr -d ' ')"
else
    record audit_names_category_and_holds_no_query fail \
        "rows=$(wc -l <"$output_directory/audit-rows.tsv" 2>/dev/null | tr -d ' ')"
fi

# 11. The browser runs the served page through the same turn, and the checks
# read its own request log rather than the page source.
browser_report=$output_directory/browser-turn.json
if command -v chromium >/dev/null 2>&1; then
    browser_prompt="Search the web with the query $query and summarize what the results state."
    if python3 "$script_directory/web-mcp/drive-fallback-page.py" --origin "$router_origin" \
            --api-key-file "$api_key_file" --broker "$broker_origin" \
            --prompt "$browser_prompt" >"$browser_report" 2>"$output_directory/browser-turn.err"; then
        browser_origin=$(jq -r '.origin // empty' "$browser_report")
        if [ "$browser_origin" = "$router_origin" ]; then
            record browser_page_origin pass \
                "origin=$browser_origin model=$(jq -r '.model' "$browser_report")"
        else
            record browser_page_origin fail "origin=$browser_origin"
        fi
        grant_request=$(jq -r --arg u "$broker_origin/grant" \
            '[.requests[] | select(.method == "POST" and .url == $u)] | length' "$browser_report")
        if [ "$grant_request" -ge 1 ]; then
            record browser_grant_from_broker pass "POST $broker_origin/grant count=$grant_request"
        else
            record browser_grant_from_broker fail 'no grant request in the page log'
        fi
        search_post=$(jq -c --arg u "$router_origin/tools" \
            '[.requests[] | select(.method == "POST" and .url == $u) | (.body | fromjson? // {}) | select(.tool == "web_search_exa")] | first // empty' \
            "$browser_report")
        if [ -n "$search_post" ] && \
           [ "$(printf '%s' "$search_post" | jq -r '.model')" = "$profile_id" ] && \
           [ "$(printf '%s' "$search_post" | jq -r '.params.authorization // empty | length')" -gt 0 ]; then
            record browser_search_via_router pass \
                "POST /tools model=$profile_id tool=web_search_exa grant=present"
        else
            record browser_search_via_router fail \
                "$(printf '%s' "$search_post" | jq -c 'del(.params.authorization)' 2>/dev/null | head -c 300)"
        fi
        off_router=$(jq -r --arg r "$router_origin/" --arg b "$broker_origin/" \
            '[.requests[] | select((.url | startswith($r) | not) and (.url | startswith($b) | not))] | length' \
            "$browser_report")
        if [ "$off_router" -eq 0 ]; then
            record browser_requests_stay_on_router_and_broker pass \
                "every page request names $router_origin or $broker_origin"
        else
            record browser_requests_stay_on_router_and_broker fail \
                "$(jq -c --arg r "$router_origin/" --arg b "$broker_origin/" '[.requests[] | select((.url | startswith($r) | not) and (.url | startswith($b) | not)) | .url]' "$browser_report" | head -c 300)"
        fi
        tool_message=$(jq -r '[.history[] | select(.role == "tool")] | first | .content // empty' \
            "$browser_report")
        if printf '%s' "$tool_message" | grep -q '^Result ID: '; then
            record browser_tool_result_in_transcript pass \
                "$(printf '%s' "$tool_message" | head -c 120 | tr '\n' ' ')"
        else
            record browser_tool_result_in_transcript fail \
                "$(printf '%s' "$tool_message" | head -c 200 | tr '\n' ' ')"
        fi
        browser_answer=$(jq -r '[.history[] | select(.role == "assistant")] | last | .content // empty' \
            "$browser_report")
        if [ -n "$browser_answer" ]; then
            record browser_final_answer pass \
                "$(printf '%s' "$browser_answer" | tr '\n' ' ' | head -c 200)"
        else
            record browser_final_answer fail 'the transcript ends without an assistant answer'
        fi
        # The grant is spent inside the request the browser sent, so the
        # retained log keeps the fields and drops the token.
        jq '.requests |= map(.body |= (if . == null then null else (fromjson? // .) end) | .body |= (if type == "object" and .params? then .params |= del(.authorization) else . end))' \
            "$browser_report" >"$browser_report.tmp" && mv "$browser_report.tmp" "$browser_report"
    else
        if jq -e . "$browser_report" >/dev/null 2>&1; then
            browser_error=$(jq -r \
                '(.error.type // "browser_error") + ": " + (.error.message // "unknown failure")' \
                "$browser_report" | head -c 300 | tr '\n' ' ')
        else
            browser_error=$(tail -c 300 "$output_directory/browser-turn.err" | tr '\n' ' ')
        fi
        record browser_turn_completed fail "${browser_error:-browser driver produced no diagnostic}"
    fi
else
    record browser_turn_completed fail 'chromium is absent, so the served page was not run'
fi
sample_instance_cost after-browser-turn
record searxng_cost observed \
    "$(awk -F'\t' 'END { print }' "$output_directory/searxng-cost.tsv" | tr '\t' ' ')"

# 12. Secret hygiene: key bytes, grant, session secret, and query text stay out
# of every process image and every retained file.
key_bytes=$(cat "$token_key_file")
hygiene_failures=''
for pid in $(pgrep -x llama-server) $(pgrep -f 'web-mcp/server.py') $broker_pid $searxng_pid; do
    [ -r "/proc/$pid/environ" ] || continue
    for needle in "$key_bytes" "$api_key_bytes" "$authorization" "$session_secret"; do
        [ -n "$needle" ] || continue
        if tr '\0' '\n' <"/proc/$pid/environ" | grep -qF -- "$needle" || \
           tr '\0' '\n' <"/proc/$pid/cmdline" | grep -qF -- "$needle"; then
            hygiene_failures="$hygiene_failures pid=$pid"
        fi
    done
done
for retained in "$state_directory/server.log" "$state_directory/authorize-broker.log" \
    "$state_directory/searxng.log" "$state_directory/session.status"; do
    [ -r "$retained" ] || continue
    for needle in "$key_bytes" "$api_key_bytes" "$authorization" "$session_secret"; do
        [ -n "$needle" ] || continue
        if grep -qF -- "$needle" "$retained"; then
            hygiene_failures="$hygiene_failures file=$(basename "$retained")"
        fi
    done
done
if [ -z "$hygiene_failures" ]; then
    record secret_hygiene pass \
        'key, grant, and session secret absent from process images, logs, and status'
else
    record secret_hygiene fail "$hygiene_failures"
fi
cp "$state_directory/server.log" "$output_directory/web-server.log" 2>/dev/null || true
cp "$state_directory/authorize-broker.log" "$output_directory/web-broker.log" 2>/dev/null || true
cp "$state_directory/searxng.log" "$output_directory/searxng.log" 2>/dev/null || true

# 13. Teardown and absence. The instance is part of what the teardown proves
# gone, since a surviving one holds the port the next launch's health gate
# reads.
if "$script_directory/qwen-teardown.sh" >"$output_directory/web-teardown.log" 2>&1; then
    record web_teardown pass "$(tail -1 "$output_directory/web-teardown.log")"
else
    record web_teardown fail "$(tail -1 "$output_directory/web-teardown.log")"
fi
absence=''
pgrep -x llama-server >/dev/null 2>&1 && absence="$absence llama-server"
pgrep -f 'web-mcp/server.py' >/dev/null 2>&1 && absence="$absence mcp-child"
[ -n "$broker_pid" ] && kill -0 "$broker_pid" 2>/dev/null && absence="$absence broker"
[ -n "$searxng_pid" ] && kill -0 "$searxng_pid" 2>/dev/null && absence="$absence searxng"
[ -n "$secret_file" ] && [ -e "$secret_file" ] && absence="$absence secret"
ss -ltn 2>/dev/null | grep -q ":$server_port " && absence="$absence port-$server_port"
ss -ltn 2>/dev/null | grep -q ":$broker_port " && absence="$absence port-$broker_port"
ss -ltn 2>/dev/null | grep -q ":$searxng_port " && absence="$absence port-$searxng_port"
if [ -z "$absence" ]; then
    record absence_proved pass 'router, child, broker, search instance, secret, and all three ports'
else
    record absence_proved fail "$absence"
fi

# 14. Restore the ordinary router.
restore_ordinary
printf 'admission_end utc=%s failures=%s\n' "$(utc)" "$failures" >>"$output_directory/run.log"
if [ "$failures" -eq 0 ]; then
    printf 'web router admission against the live SearXNG instance: all required checks passed\n'
    exit 0
fi
printf 'web router admission against the live SearXNG instance: %s required checks failed\n' \
    "$failures" >&2
exit 1
