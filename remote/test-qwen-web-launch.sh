#!/bin/sh
set -eu

# Tests remote/qwen-web-launch.sh and the unvalidated-depth marker that
# remote/qwen-capacity-policy.sh reads from a web preset file.
#
# The launch arms replace qwen-launch.sh with a recorder, so each one measures
# the environment the wrapper hands the launcher rather than starting a server.
# The policy arms drive the real qwen-capacity-policy.sh with the fake
# llama-server, which is where the loopback restriction is enforced.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

# The busy-port arm below proves the preflight message qwen-web-launch.sh's
# own ss check produces; that check silently admits a busy port where ss is
# absent, so a gate host lacking it would otherwise read the arm as accepted
# rather than as the undeclared dependency it is.
if ! command -v ss >/dev/null 2>&1; then
    printf 'test-qwen-web-launch: ss is required\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
policy=$script_directory/qwen-capacity-policy.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
failures=0

work=$(mktemp -d)
# The launchers resolve the machine's deployment root; the fixture names an
# empty one so the host's own deployments never reach the test.
QWEN_DEPLOYMENT_ROOT=$work/deployments
mkdir -p "$QWEN_DEPLOYMENT_ROOT"
export QWEN_DEPLOYMENT_ROOT
trap 'rm -rf "$work"' EXIT INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

wait_for_path() {
    waited_path=$1
    waited_attempt=0
    while [ ! -e "$waited_path" ] && [ "$waited_attempt" -lt 500 ]; do
        waited_attempt=$((waited_attempt + 1))
        sleep 0.01
    done
    [ -e "$waited_path" ]
}

wait_for_absence() {
    waited_path=$1
    waited_attempt=0
    while [ -e "$waited_path" ] && [ "$waited_attempt" -lt 500 ]; do
        waited_attempt=$((waited_attempt + 1))
        sleep 0.01
    done
    [ ! -e "$waited_path" ]
}

# The context checkpoint ledger joins against the model registry, so the
# fixture registry names an empty ledger and every fixture section carries the
# 0 an absent row admits.
QWEN_CTX_CHECKPOINT_LEDGER=$work/ctx-checkpoints.tsv
printf '# the fixture registry admits no checkpoint count\n' \
    >"$QWEN_CTX_CHECKPOINT_LEDGER"
export QWEN_CTX_CHECKPOINT_LEDGER

# The wrapper runs from a directory holding a recorder in place of
# qwen-launch.sh, so the arms read the forwarded environment out of a file.
harness=$work/harness
mkdir -p "$harness"
cp "$script_directory/qwen-web-launch.sh" "$harness/qwen-web-launch.sh"
# The launcher sources its listener policy from its own directory, so the
# harness carries the tree's file rather than a stand-in.
cp "$script_directory/web-lan-exposure.sh" "$harness/web-lan-exposure.sh"
# An unset QWEN_WEB_LAN_NAME is the question the policy answers from this
# host's own avahi state, so every arm below states an answer: the empty
# default here, and a synthetic name where the arm measures one. Inheriting it
# would resolve a different name on a machine running the daemon and would
# print that machine's hostname into a log.
QWEN_WEB_LAN_NAME=''
export QWEN_WEB_LAN_NAME
# The launcher resolves the active deployment before it reads a preset; the
# harness holds no deployment root, so the resolver reports none and the
# state directory preset applies.
cp "$script_directory/resolve-active-deployment.sh" \
    "$harness/resolve-active-deployment.sh"
cp "$script_directory/open-verified-lock-descriptor.py" \
    "$harness/open-verified-lock-descriptor.py"
cat >"$harness/qwen-launch.sh" <<'EOF'
#!/bin/sh
set -eu
{
    printf 'profile=%s\n' "${1:-unset}"
    printf 'QWEN_ROUTER=%s\n' "${QWEN_ROUTER:-unset}"
    printf 'QWEN_ROUTER_PRESETS=%s\n' "${QWEN_ROUTER_PRESETS:-unset}"
    printf 'QWEN_ROUTER_MAX=%s\n' "${QWEN_ROUTER_MAX:-unset}"
    printf 'QWEN_BIND_HOST=%s\n' "${QWEN_BIND_HOST:-unset}"
    printf 'QWEN_WEB_BROKER=%s\n' "${QWEN_WEB_BROKER:-unset}"
    printf 'QWEN_WEB_BROKER_PORT=%s\n' "${QWEN_WEB_BROKER_PORT:-unset}"
    printf 'QWEN_WEB_STATE_DIR=%s\n' "${QWEN_WEB_STATE_DIR:-unset}"
    printf 'QWEN_WEB_TOKEN_KEY_FILE=%s\n' "${QWEN_WEB_TOKEN_KEY_FILE:-unset}"
    printf 'QWEN_WEB_PROFILE=%s\n' "${QWEN_WEB_PROFILE:-unset}"
    printf 'QWEN_WEB_PROVIDER=%s\n' "${QWEN_WEB_PROVIDER:-unset}"
    printf 'QWEN_WEB_PROFILES=%s\n' "${QWEN_WEB_PROFILES:-unset}"
    printf 'QWEN_WEB_SEARXNG=%s\n' "${QWEN_WEB_SEARXNG:-unset}"
    printf 'QWEN_SEARXNG_PORT=%s\n' "${QWEN_SEARXNG_PORT:-unset}"
    printf 'QWEN_STATIC_PATH=%s\n' "${QWEN_STATIC_PATH:-unset}"
    printf 'QWEN_REQUIRE_API_KEY=%s\n' "${QWEN_REQUIRE_API_KEY:-unset}"
    printf 'QWEN_WEB_LAN=%s\n' "${QWEN_WEB_LAN:-unset}"
    printf 'QWEN_WEB_LAN_ADDRESS=%s\n' "${QWEN_WEB_LAN_ADDRESS:-unset}"
    printf 'QWEN_WEB_LAN_NAME=%s\n' "${QWEN_WEB_LAN_NAME:-unset}"
    printf 'QWEN_WEB_LAN_OPEN=%s\n' "${QWEN_WEB_LAN_OPEN:-unset}"
} >"$QWEN_WEB_LAUNCH_RECORD"
EOF
chmod +x "$harness/qwen-launch.sh"
launcher=$harness/qwen-web-launch.sh
# The wrapper serves the fallback page beside its own directory, so the
# harness carries a page holding the two route shapes the wrapper reads for.
mkdir -p "$work/webui"
# shellcheck disable=SC2016
printf '%s\n' 'fetch(`./tools?model=${encodeURIComponent(selectedModel)}&autoload=true`)' \
    'JSON.stringify({ model, tool: toolName, params, stream: false })' \
    >"$work/webui/index.html"

# The control process crosses a separate tmux server before the session starts.
# A fake tmux records the new-session command and proves the API-key requirement
# and authorizer-readiness decision survive that boundary.
control_harness=$work/control-harness
control_bin=$work/control-bin
mkdir -p "$control_harness" "$control_bin"
cp "$script_directory/qwen-webui-control.sh" \
    "$control_harness/qwen-webui-control.sh"
cp "$script_directory/open-verified-lock-descriptor.py" \
    "$control_harness/open-verified-lock-descriptor.py"
cp "$script_directory/check-runtime-tree.sh" \
    "$control_harness/check-runtime-tree.sh"
cp "$script_directory/resolve-active-deployment.sh" \
    "$control_harness/resolve-active-deployment.sh"
cp "$script_directory/open-verified-lock-descriptor.py" \
    "$control_harness/open-verified-lock-descriptor.py"
cat >"$control_bin/tmux" <<'EOF'
#!/bin/sh
set -eu
case " $* " in
    *" has-session "*) [ -s "$QWEN_FAKE_TMUX_STATE" ] ;;
    *" display-message "*)
        [ -s "$QWEN_FAKE_TMUX_STATE" ] || exit 1
        sed -n '1p' "$QWEN_FAKE_TMUX_STATE"
        ;;
    *" new-session "*)
        for tmux_argument in "$@"; do
            session_command=$tmux_argument
        done
        printf '%s\n' "$session_command" >"$QWEN_TMUX_RECORD"
        printf '%s\n' '$fixture:1700000000' >"$QWEN_FAKE_TMUX_STATE"
        sh -c "$session_command" </dev/null >/dev/null 2>&1 &
        printf '%s\n' "$!" >"$QWEN_FAKE_TMUX_PID"
        printf '%s\n' '$fixture:1700000000'
        ;;
    *" kill-session "*)
        if [ -s "$QWEN_FAKE_TMUX_PID" ]; then
            kill -TERM "$(sed -n '1p' "$QWEN_FAKE_TMUX_PID")" 2>/dev/null || true
        fi
        rm -f -- "$QWEN_FAKE_TMUX_STATE" "$QWEN_FAKE_TMUX_PID"
        ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$control_bin/tmux"
cat >"$control_harness/qwen-webui-session.sh" <<'EOF'
#!/bin/sh
set -eu
cleanup_fake_session() {
    rm -f -- "$QWEN_FAKE_TMUX_STATE" "$QWEN_FAKE_TMUX_PID"
}
trap cleanup_fake_session EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [ -e "/proc/$$/fd/9" ]; then
    campaign_control_fd9=$(readlink -f -- "/proc/$$/fd/9" 2>/dev/null || true)
else
    campaign_control_fd9=absent
fi
{
    printf 'state_directory=%s\n' "$7"
    printf 'server=%s\n' "$1"
    printf 'model=%s\n' "$2"
    printf 'broker_program=%s\n' "${QWEN_WEB_BROKER_PROGRAM:-unset}"
    printf 'broker_state=%s\n' "${QWEN_WEB_STATE_DIR:-unset}"
    printf 'token_key=%s\n' "${QWEN_WEB_TOKEN_KEY_FILE:-unset}"
    printf 'broker_origin=%s\n' "${QWEN_WEB_BROKER_ORIGIN:-unset}"
    printf 'submit_trace=%s\n' "${GGML_VK_SUBMIT_TRACE:-unset}"
    printf 'image_priority_wrapper=%s\n' "${QWEN_IMAGE_PRIORITY_WRAPPER:-unset}"
    printf 'image_lease_wait=%s\n' "${QWEN_IMAGE_LEASE_WAIT_S:-unset}"
    printf 'model_registry=%s\n' "${QWEN_MODEL_REGISTRY:-unset}"
    printf 'quarantine_registry=%s\n' "${QWEN_QUARANTINE_REGISTRY:-unset}"
    printf 'validated_tuples=%s\n' "${QWEN_VALIDATED_TUPLES:-unset}"
    printf 'ctx_checkpoint_ledger=%s\n' "${QWEN_CTX_CHECKPOINT_LEDGER:-unset}"
    printf 'approved_model_id=%s\n' "${QWEN_APPROVED_MODEL_ID:-unset}"
    printf 'approved_model_file=%s\n' "${QWEN_APPROVED_MODEL_FILE:-unset}"
    printf 'approved_model_device=%s\n' "${QWEN_APPROVED_MODEL_DEVICE:-unset}"
    printf 'approved_model_inode=%s\n' "${QWEN_APPROVED_MODEL_INODE:-unset}"
    printf 'approved_model_bytes=%s\n' "${QWEN_APPROVED_MODEL_BYTES:-unset}"
    printf 'batch_size=%s\n' "${QWEN_BATCH_SIZE:-unset}"
    printf 'ubatch_size=%s\n' "${QWEN_UBATCH_SIZE:-unset}"
    printf 'api_key=%s\n' "${QWEN_REQUIRE_API_KEY:-unset}"
    printf 'authorizer=%s\n' "${QWEN_WEB_AUTHORIZER_READY:-unset}"
    printf 'campaign_control_fd9=%s\n' "$campaign_control_fd9"
} >"$QWEN_CONTROL_SESSION_RECORD"
while [ -e "$7/hold-session" ]; do
    sleep 0.01
done
EOF
chmod +x "$control_harness/qwen-webui-session.sh"

# The control lock opener rejects a final symlink through O_NOFOLLOW. The
# retained target bytes prove the refusal happens before shell redirection can
# follow the link and truncate another file.
control_link_state=$work/control-link-state
control_link_target=$work/control-link-target
control_link_expected=$work/control-link-expected
control_link_tmux_state=$work/control-link-tmux.state
mkdir "$control_link_state"
printf 'retained control lock target bytes\n' >"$control_link_target"
cp -- "$control_link_target" "$control_link_expected"
ln -s "$control_link_target" \
    "$control_link_state/fixed64-served-campaign.lock"
set +e
PATH="$control_bin:$PATH" \
QWEN_FAKE_TMUX_STATE=$control_link_tmux_state \
QWEN_WEBUI_STATE_DIRECTORY=$control_link_state \
QWEN_LLAMA_SERVER=$work/control-link-server \
QWEN_MODEL_PATH=$work/control-link-model \
    "$control_harness/qwen-webui-control.sh" start custom \
    >"$work/control-link.log" 2>"$work/control-link.err"
control_link_status=$?
set -e
control_link_outcome=ok
[ "$control_link_status" -eq 2 ] || \
    control_link_outcome="status-$control_link_status"
cmp -s "$control_link_expected" "$control_link_target" || \
    control_link_outcome=target-bytes-changed
[ -L "$control_link_state/fixed64-served-campaign.lock" ] || \
    control_link_outcome=link-replaced
grep -F 'verified_lock_descriptor=rejected' \
    "$work/control-link.err" >/dev/null || control_link_outcome=reason-absent
report control_final_lock_symlink_preserves_target_bytes \
    "$control_link_outcome"

control_record=$work/control-tmux.record
control_session_record=$work/control-session.record
control_tmux_state=$work/control-tmux.state
control_tmux_pid=$work/control-tmux.pid
if PATH="$control_bin:$PATH" QWEN_TMUX_RECORD=$control_record \
    QWEN_CONTROL_SESSION_RECORD=$control_session_record \
    QWEN_FAKE_TMUX_STATE=$control_tmux_state \
    QWEN_FAKE_TMUX_PID=$control_tmux_pid \
    QWEN_WEBUI_STATE_DIRECTORY="$work/control state" \
    QWEN_LLAMA_SERVER="$work/fake server" QWEN_MODEL_PATH="$work/fake model" \
    QWEN_WEB_BROKER_PROGRAM="$work/broker program.py" \
    QWEN_WEB_STATE_DIR="$work/broker state" \
    QWEN_WEB_TOKEN_KEY_FILE="$work/token key" \
    QWEN_WEB_BROKER_ORIGIN=http://127.0.0.1:18080 \
    GGML_VK_SUBMIT_TRACE=1 \
    QWEN_IMAGE_PRIORITY_WRAPPER="$work/image priority wrapper" \
    QWEN_IMAGE_LEASE_WAIT_S=7.25 \
    QWEN_MODEL_REGISTRY="$work/models snapshot.tsv" \
    QWEN_QUARANTINE_REGISTRY="$work/quarantine snapshot.tsv" \
    QWEN_VALIDATED_TUPLES="$work/tuples snapshot.tsv" \
    QWEN_CTX_CHECKPOINT_LEDGER="$work/checkpoints snapshot.tsv" \
    QWEN_APPROVED_MODEL_ID=fixture-model \
    QWEN_APPROVED_MODEL_FILE='Fixture Models/model.gguf' \
    QWEN_APPROVED_MODEL_DEVICE=2049 QWEN_APPROVED_MODEL_INODE=8675309 \
    QWEN_APPROVED_MODEL_BYTES=2783446304 \
    QWEN_BATCH_SIZE=128 QWEN_UBATCH_SIZE=32 \
    QWEN_REQUIRE_API_KEY=1 QWEN_WEB_AUTHORIZER_READY=1 \
    "$control_harness/qwen-webui-control.sh" start custom \
    >"$work/control.log" 2>"$work/control.err"; then
    outcome=ok
    wait_for_path "$control_session_record" || outcome=session_record_absent
    grep -qx 'api_key=1' "$control_session_record" ||
        outcome=api_key_requirement_dropped
    grep -qx 'authorizer=1' "$control_session_record" ||
        outcome=authorizer_readiness_dropped
    grep -Fqx "state_directory=$work/control state" "$control_session_record" ||
        outcome=state_directory_split
    grep -Fqx "server=$work/fake server" "$control_session_record" ||
        outcome=server_path_split
    grep -Fqx "model=$work/fake model" "$control_session_record" ||
        outcome=model_path_split
    grep -Fqx "broker_program=$work/broker program.py" "$control_session_record" ||
        outcome=broker_program_split
    grep -Fqx "broker_state=$work/broker state" "$control_session_record" ||
        outcome=broker_state_split
    grep -Fqx "token_key=$work/token key" "$control_session_record" ||
        outcome=token_key_split
    grep -qx 'broker_origin=http://127.0.0.1:18080' "$control_session_record" ||
        outcome=broker_origin_dropped
    grep -qx 'submit_trace=1' "$control_session_record" ||
        outcome=submit_trace_dropped
    grep -Fqx "image_priority_wrapper=$work/image priority wrapper" "$control_session_record" ||
        outcome=image_priority_wrapper_dropped
    grep -qx 'image_lease_wait=7.25' "$control_session_record" ||
        outcome=image_lease_wait_dropped
    grep -Fqx "model_registry=$work/models snapshot.tsv" \
        "$control_session_record" || outcome=model_registry_split
    grep -Fqx "quarantine_registry=$work/quarantine snapshot.tsv" \
        "$control_session_record" || outcome=quarantine_registry_split
    grep -Fqx "validated_tuples=$work/tuples snapshot.tsv" \
        "$control_session_record" || outcome=validated_tuples_split
    grep -Fqx "ctx_checkpoint_ledger=$work/checkpoints snapshot.tsv" \
        "$control_session_record" || outcome=ctx_checkpoint_ledger_split
    grep -qx 'approved_model_id=fixture-model' "$control_session_record" ||
        outcome=approved_model_id_dropped
    grep -qx 'approved_model_file=Fixture Models/model.gguf' \
        "$control_session_record" || outcome=approved_model_file_dropped
    grep -qx 'approved_model_device=2049' "$control_session_record" ||
        outcome=approved_model_device_dropped
    grep -qx 'approved_model_inode=8675309' "$control_session_record" ||
        outcome=approved_model_inode_dropped
    grep -qx 'approved_model_bytes=2783446304' "$control_session_record" ||
        outcome=approved_model_bytes_dropped
    grep -qx 'batch_size=128' "$control_session_record" ||
        outcome=batch_size_dropped
    grep -qx 'ubatch_size=32' "$control_session_record" ||
        outcome=ubatch_size_dropped
    grep -qx 'campaign_control_fd9=absent' "$control_session_record" ||
        outcome=campaign_control_fd9_inherited
    report control_forwards_web_authority "$outcome"
else
    report control_forwards_web_authority failed
    cat "$work/control.err" >&2
fi

# The controller locks descriptor 9 before removing session.status. A fake
# flock blocks after the kernel grants that lock, which makes the former race
# window deterministic: another campaign claimant must fail while the sentinel
# status line still proves the first shared-state mutation has not run.
cat >"$control_bin/flock" <<'EOF'
#!/bin/sh
set -eu
if [ -n "${QWEN_FLOCK_GATE_READY:-}" ]; then
    /usr/bin/flock "$@"
    : >"$QWEN_FLOCK_GATE_READY"
    while [ ! -e "$QWEN_FLOCK_GATE_RELEASE" ]; do
        sleep 0.01
    done
    exit 0
fi
exec /usr/bin/flock "$@"
EOF
chmod +x "$control_bin/flock"

# Dash applies a simple-command descriptor close in the calling shell while a
# child runs. The delayed first holder sleep gives the controller a stable
# interval in which to verify that descriptor 9 remains installed in the holder.
cat >"$control_bin/sleep" <<'EOF'
#!/bin/sh
set -eu
if [ "${1:-}" = 0.05 ] && \
   [ -n "${QWEN_HOLDER_SLEEP_DELAY_READY:-}" ] && \
   [ ! -e "$QWEN_HOLDER_SLEEP_DELAY_READY" ]; then
    : >"$QWEN_HOLDER_SLEEP_DELAY_READY"
    exec /usr/bin/sleep 1
fi
exec /usr/bin/sleep "$@"
EOF
chmod +x "$control_bin/sleep"

# The controller accepts a state-directory alias while binding the holder to
# the same lock inode that the alias names.
lease_state_directory_target=$work/lease-control-state-target
lease_state_directory=$work/lease-control-state-alias
lease_tmux_state=$work/lease-tmux.state
lease_tmux_pid=$work/lease-tmux.pid
lease_tmux_record=$work/lease-tmux.record
lease_session_record=$work/lease-session.record
lease_gate_ready=$work/lease-flock.ready
lease_gate_release=$work/lease-flock.release
lease_holder_sleep_delay_ready=$work/lease-holder-sleep-delay.ready
lease_control_status=$work/lease-control.status
lease_control_lock=$lease_state_directory/fixed64-served-campaign.lock
lease_record=$lease_state_directory/ordinary-session-control-lease.tsv
mkdir -p "$lease_state_directory_target"
ln -s "$lease_state_directory_target" "$lease_state_directory"
printf 'state=sentinel\n' >"$lease_state_directory/session.status"
: >"$lease_state_directory/hold-session"
(umask 077; : >"$lease_control_lock")
lease_posix_shell=$(command -v dash || true)
if [ -z "$lease_posix_shell" ]; then
    printf 'test-qwen-web-launch: dash is required for descriptor-stability coverage\n' >&2
    exit 2
fi
(
    set +e
    exec 9<>"$lease_control_lock"
    PATH="$control_bin:$PATH" \
    QWEN_FIXED64_CONTROL_LOCK_INHERITED=1 \
    QWEN_FLOCK_GATE_READY=$lease_gate_ready \
    QWEN_FLOCK_GATE_RELEASE=$lease_gate_release \
    QWEN_HOLDER_SLEEP_DELAY_READY=$lease_holder_sleep_delay_ready \
    QWEN_TMUX_RECORD=$lease_tmux_record \
    QWEN_CONTROL_SESSION_RECORD=$lease_session_record \
    QWEN_FAKE_TMUX_STATE=$lease_tmux_state \
    QWEN_FAKE_TMUX_PID=$lease_tmux_pid \
    QWEN_WEBUI_STATE_DIRECTORY=$lease_state_directory \
    QWEN_LLAMA_SERVER=$work/lease-server \
    QWEN_MODEL_PATH=$work/lease-model \
        "$lease_posix_shell" "$control_harness/qwen-webui-control.sh" \
        start custom \
        >"$work/lease-control.log" 2>"$work/lease-control.err"
    printf '%s\n' "$?" >"$lease_control_status"
) &
lease_control_pid=$!

lease_interleaving_outcome=ok
if ! wait_for_path "$lease_gate_ready"; then
    lease_interleaving_outcome=lock_gate_unreached
else
    set +e
    /usr/bin/flock -n -E 75 "$lease_control_lock" true
    lease_competitor_status=$?
    set -e
    [ "$lease_competitor_status" -eq 75 ] ||
        lease_interleaving_outcome=competing_campaign_admitted
    grep -qx 'state=sentinel' "$lease_state_directory/session.status" ||
        lease_interleaving_outcome=status_mutated_before_lock
fi
report ordinary_lease_precedes_shared_state_mutation \
    "$lease_interleaving_outcome"

: >"$lease_gate_release"
wait "$lease_control_pid"
lease_dash_descriptor_outcome=ok
if [ ! -e "$lease_holder_sleep_delay_ready" ]; then
    lease_dash_descriptor_outcome=holder_child_delay_unreached
elif [ "$(sed -n '1p' "$lease_control_status")" -ne 0 ]; then
    lease_dash_descriptor_outcome=control_start_failed
fi
report ordinary_lease_dash_child_close_preserves_holder \
    "$lease_dash_descriptor_outcome"
lease_alias_outcome=ok
if [ "$(sed -n '1p' "$lease_control_status")" -ne 0 ]; then
    lease_alias_outcome=control_start_failed
fi
report ordinary_lease_accepts_state_directory_symlink_alias \
    "$lease_alias_outcome"
lease_lifetime_outcome=ok
if [ "$(sed -n '1p' "$lease_control_status")" -ne 0 ]; then
    lease_lifetime_outcome=control_start_failed
elif ! wait_for_path "$lease_session_record"; then
    lease_lifetime_outcome=session_record_absent
elif [ ! -s "$lease_record" ]; then
    lease_lifetime_outcome=lease_record_absent
else
    lease_holder_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
        "$lease_record")
    lease_holder_start=$(awk -F '\t' \
        '$1 == "holder_start_time_ticks" { print $2 }' "$lease_record")
    case $lease_holder_pid:$lease_holder_start in
        :* | *: | *[!0-9:]*) lease_lifetime_outcome=holder_record_malformed ;;
        *)
            lease_holder_observed_start=$(
                sed 's/^.*) //' "/proc/$lease_holder_pid/stat" 2>/dev/null |
                    awk '{ print $20 }'
            )
            [ "$lease_holder_observed_start" = "$lease_holder_start" ] ||
                lease_lifetime_outcome=holder_identity_changed
            ;;
    esac
    if [ "$lease_lifetime_outcome" = ok ] && \
       ! awk -F '\t' '$1 == "state" && $2 == "session-bound" { found = 1 }
           END { exit !found }' "$lease_record"; then
        lease_lifetime_outcome=session_identity_unbound
    fi
    if [ "$lease_lifetime_outcome" = ok ] && \
       ! awk -F '\t' '$1 == "tmux_identity" && $2 == "$fixture:1700000000" {
               found = 1
           }
           END { exit !found }' "$lease_record"; then
        lease_lifetime_outcome=wrong_tmux_identity
    fi
    set +e
    /usr/bin/flock -n -E 75 "$lease_control_lock" true
    lease_held_probe_status=$?
    set -e
    [ "$lease_lifetime_outcome" != ok ] || \
        [ "$lease_held_probe_status" -eq 75 ] ||
        lease_lifetime_outcome=lease_released_while_session_running
fi
report ordinary_lease_held_for_exact_tmux_identity "$lease_lifetime_outcome"

rm -f -- "$lease_state_directory/hold-session"
lease_release_outcome=ok
wait_for_absence "$lease_tmux_state" || lease_release_outcome=tmux_state_retained
wait_for_absence "$lease_record" || lease_release_outcome=lease_record_retained
# The holder unlinks its record before it exits and the kernel drops the
# flock at exit, so the record's absence precedes the release by the
# holder's own teardown; the probe polls over the same window the absence
# waits take rather than reading the lock once at that instant.
lease_released_attempt=0
lease_released_probe_status=75
while [ "$lease_released_probe_status" -ne 0 ] && \
      [ "$lease_released_attempt" -lt 500 ]; do
    set +e
    /usr/bin/flock -n "$lease_control_lock" true
    lease_released_probe_status=$?
    set -e
    [ "$lease_released_probe_status" -eq 0 ] || sleep 0.01
    lease_released_attempt=$((lease_released_attempt + 1))
done
[ "$lease_released_probe_status" -eq 0 ] ||
    lease_release_outcome=lease_retained_after_session
report ordinary_lease_released_after_exact_tmux_identity "$lease_release_outcome"

# The campaign owns descriptor 9 in its orchestrator. The launcher closes that
# descriptor before qwen-webui-control starts, and the controller also closes 9
# on the tmux client boundary. This arm supplies a real inherited descriptor to
# catch either layer accidentally carrying it into the ordinary session.
campaign_state_directory=$work/campaign-child-state
campaign_tmux_state=$work/campaign-child-tmux.state
campaign_tmux_pid=$work/campaign-child-tmux.pid
campaign_tmux_record=$work/campaign-child-tmux.record
campaign_session_record=$work/campaign-child-session.record
mkdir -p "$campaign_state_directory"
set +e
(
    PATH="$control_bin:$PATH" \
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF=$work/campaign-external-proof.tsv \
    QWEN_TMUX_RECORD=$campaign_tmux_record \
    QWEN_CONTROL_SESSION_RECORD=$campaign_session_record \
    QWEN_FAKE_TMUX_STATE=$campaign_tmux_state \
    QWEN_FAKE_TMUX_PID=$campaign_tmux_pid \
    QWEN_WEBUI_STATE_DIRECTORY=$campaign_state_directory \
    QWEN_LLAMA_SERVER=$work/campaign-server \
    QWEN_MODEL_PATH=$work/campaign-model \
        "$control_harness/open-verified-lock-descriptor.py" open \
        "$campaign_state_directory/fixed64-served-campaign.lock" 9 \
        sh -c '/usr/bin/flock -n 9; exec "$@"' sh \
        "$control_harness/qwen-webui-control.sh" start custom \
        >"$work/campaign-child.log" 2>"$work/campaign-child.err"
)
campaign_control_status=$?
set -e
campaign_fd9_outcome=ok
[ "$campaign_control_status" -eq 0 ] || campaign_fd9_outcome=control_start_failed
wait_for_path "$campaign_session_record" || campaign_fd9_outcome=session_record_absent
grep -qx 'campaign_control_fd9=absent' "$campaign_session_record" ||
    campaign_fd9_outcome=campaign_fd9_inherited
report post_campaign_session_fd9_absent "$campaign_fd9_outcome"

cat >"$control_bin/ssh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" >"$QWEN_SSH_RECORD"
EOF
chmod +x "$control_bin/ssh"
ssh_record=$work/connect-ssh.record
if PATH="$control_bin:$PATH" QWEN_SSH_RECORD=$ssh_record \
    "$script_directory/connect-qwen-webui.sh" fixture-host 18080 8080 \
    >"$work/connect.log" 2>"$work/connect.err"; then
    outcome=ok
    grep -Fqx '127.0.0.1:18080:127.0.0.1:8080' "$ssh_record" ||
        outcome=server_tunnel_absent
    grep -Fqx '127.0.0.1:8571:127.0.0.1:8571' "$ssh_record" ||
        outcome=broker_tunnel_absent
    grep -Fq 'QWEN_WEB_BROKER_ORIGIN=http://127.0.0.1:18080' \
        "$work/connect.log" || outcome=browser_origin_unreported
    report connect_forwards_server_and_broker "$outcome"
else
    report connect_forwards_server_and_broker failed
    cat "$work/connect.err" >&2
fi

# Every launch below carries a usable signing key, because the wrapper requires
# one before it forwards anything; the arms that test the key rules override
# this path with their own.
token_key_file=$work/token.key
printf 'fixture-signing-key\n' >"$token_key_file"
chmod 600 "$token_key_file"
QWEN_WEB_TOKEN_KEY_FILE=$token_key_file
export QWEN_WEB_TOKEN_KEY_FILE
QWEN_WEB_AUTHORIZER_READY=1
export QWEN_WEB_AUTHORIZER_READY

state_directory=$work/state
mkdir -p "$state_directory/web-mcp-configs"
mcp_config=$state_directory/web-mcp-configs/web-fixture.json
printf '{}\n' >"$mcp_config"

web_profiles=$work/web-profiles.tsv
write_web_profiles() {
    printf '# profile_id\tmodel_id\tweb_mode\tcontext\tvalidated_filled_depth\tmax_results\tmax_fetches\tmax_chars_per_fetch\tmulti_source\tvision_allowed\ttool_selection\texecution_policy\tprovider\tprimary_category\tfallback_category\tminimum_results\tsearxng_url\n' \
        >"$2"
    printf 'web-fixture\tfixture-production\tvalidator-gated\t8192\t16384\t5\t2\t12000\tyes\tno\t9/10\t%s\texa\t-\t-\t-\t-\n' \
        "$1" >>"$2"
}
write_web_profiles validator-gated "$web_profiles"

validated_tuples=$work/validated-tuples.tsv
cat >"$validated_tuples" <<'EOF'
# tuple_id	model_id	runtime_mode	context	batch	ubatch	cache_k	cache_v	flash_attention	threads	parallel	projector_state	backend	status	evidence	llama_commit	runner_sha256	kernel	mesa	amdgpu	measured_at
vision-fixture-router-child	vision-fixture	router-child	8192	128	32	q8_0	q4_0	on	1	1	loaded	vulkan	validated	evidence/fixture.md	-	-	-	-	-	2026-08-29
EOF

write_web_preset() {
    web_preset_path=$1
    web_preset_marker=$2
    web_preset_provider=${3:-exa}
    {
        printf '# Generated by remote/build-web-presets.sh from remote/web-profiles.tsv.\n'
        printf '# qwen_web_presets=1\n'
        printf '# qwen_web_profiles_path=%s\n' "$web_profiles"
        printf '# qwen_web_profiles_sha256=%s\n' \
            "$(sha256sum "$web_profiles" | cut -d' ' -f1)"
        printf '# qwen_web_provider=%s\n' "$web_preset_provider"
        printf '# qwen_validated_tuples_path=%s\n' "$validated_tuples"
        printf '# qwen_validated_tuples_sha256=%s\n' \
            "$(sha256sum "$validated_tuples" | cut -d' ' -f1)"
        if [ "$web_preset_marker" = marked ]; then
            printf '# qwen-web-presets: unvalidated-depth-override\n'
        fi
        printf '\n'
        printf '[web-fixture]\n'
        printf 'LLAMA_ARG_MODEL = %s\n' "$policy_model_root/Fixture-GGUF/production.gguf"
        printf 'LLAMA_ARG_ALIAS = web-fixture\n'
        printf 'LLAMA_ARG_CTX_SIZE = 8192\n'
        printf 'LLAMA_ARG_CACHE_TYPE_K = q8_0\n'
        printf 'LLAMA_ARG_CACHE_TYPE_V = q4_0\n'
        printf 'LLAMA_ARG_FLASH_ATTN = on\n'
        printf 'LLAMA_ARG_BATCH = 128\n'
        printf 'LLAMA_ARG_UBATCH = 32\n'
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
        printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$mcp_config"
        printf 'LLAMA_ARG_TAGS = web-research,validator-gated\n'
        printf '\n'
    } >"$web_preset_path"
}

policy_model_root=$work/model-root
mkdir -p "$policy_model_root/Fixture-GGUF"
: >"$policy_model_root/Fixture-GGUF/production.gguf"

web_presets=$state_directory/web-presets.ini
write_web_preset "$web_presets" unmarked

record=$work/launch.record

# The wrapper sets router mode, the web preset file, a single resident model,
# and the loopback listener.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" low-async \
    >"$work/launch.log" 2>"$work/launch.err"; then
    outcome=ok
    grep -qx 'QWEN_ROUTER=1' "$record" || outcome=router_unset
    grep -qx "QWEN_ROUTER_PRESETS=$web_presets" "$record" || outcome=wrong_presets
    grep -qx 'QWEN_ROUTER_MAX=1' "$record" || outcome=wrong_models_max
    grep -qx 'QWEN_BIND_HOST=127.0.0.1' "$record" || outcome=wrong_bind_host
    grep -qx 'profile=low-async' "$record" || outcome=profile_dropped
    grep -qx "QWEN_STATIC_PATH=$harness/../webui" "$record" || outcome=static_path_dropped
    grep -qx 'QWEN_REQUIRE_API_KEY=1' "$record" || outcome=api_key_not_required
    report wrapper_forwards_web_router_environment "$outcome"
    broker_outcome=ok
    grep -qx 'QWEN_WEB_BROKER=1' "$record" || broker_outcome=marker_unset
    grep -qx 'QWEN_WEB_BROKER_PORT=8571' "$record" ||
        broker_outcome=wrong_broker_port
    grep -qx "QWEN_WEB_STATE_DIR=$state_directory/web-mcp" "$record" ||
        broker_outcome=wrong_broker_state_dir
    report wrapper_exports_broker_marker "$broker_outcome"
else
    report wrapper_forwards_web_router_environment failed
    cat "$work/launch.err" >&2
fi

if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST -u QWEN_WEB_AUTHORIZER_READY "$launcher" \
    >"$work/authorizer-absent.log" 2>"$work/authorizer-absent.err"; then
    report validator_gated_launch_requires_authorizer accepted
elif grep -q 'validator-gated web presets require QWEN_WEB_AUTHORIZER_READY=1' \
    "$work/authorizer-absent.err"; then
    report validator_gated_launch_requires_authorizer ok
else
    report validator_gated_launch_requires_authorizer missing_message
fi

# The signing key travels as a path the wrapper reads before the launch, and a
# key file the broker cannot read refuses here rather than at the first
# approval a human has already given.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_TOKEN_KEY_FILE=$work/absent-token.key \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/absent-key.log" 2>"$work/absent-key.err"; then
    report unreadable_signing_key_refused accepted
else
    outcome=ok
    grep -q 'grant signing key is not a regular file' "$work/absent-key.err" ||
        outcome=missing_message
    report unreadable_signing_key_refused "$outcome"
fi

if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_BROKER_PORT=18571 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/key.log" 2>"$work/key.err"; then
    outcome=ok
    grep -qx "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" "$record" ||
        outcome=key_path_dropped
    grep -qx 'QWEN_WEB_BROKER_PORT=18571' "$record" || outcome=port_override_dropped
    grep -q 'signing_key=configured' "$work/key.log" || outcome=key_state_unreported
    if grep -q 'fixture-signing-key' "$work/key.log" "$work/key.err"; then
        outcome=key_contents_printed
    fi
    grep -qx 'QWEN_WEB_PROFILE=web-fixture' "$record" || outcome=profile_underived
    grep -qx 'QWEN_WEB_PROVIDER=exa' "$record" || outcome=provider_default_dropped
    grep -q 'profile=web-fixture provider=exa' "$work/key.log" ||
        outcome=profile_unreported
    report signing_key_path_forwarded "$outcome"
else
    report signing_key_path_forwarded refused
    cat "$work/key.err" >&2
fi

# The key rules the broker applies at its own startup refuse here first, where
# the message names the rule; the key contents stay out of every line.
signing_key_arm() {
    arm_name=$1
    arm_key=$2
    arm_message=$3
    if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_WEB_LAUNCH_RECORD=$record \
        QWEN_WEB_TOKEN_KEY_FILE=$arm_key \
        env -u QWEN_BIND_HOST "$launcher" \
        >"$work/$arm_name.log" 2>"$work/$arm_name.err"; then
        report "$arm_name" accepted
    else
        outcome=ok
        grep -q "grant signing key $arm_message" "$work/$arm_name.err" ||
            outcome=missing_message
        report "$arm_name" "$outcome"
    fi
}
if env -u QWEN_WEB_TOKEN_KEY_FILE QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record env -u QWEN_BIND_HOST "$launcher" \
    >"$work/unset-key.log" 2>"$work/unset-key.err"; then
    report unset_signing_key_refused accepted
else
    outcome=ok
    grep -q 'grant signing key is unset' "$work/unset-key.err" || outcome=missing_message
    report unset_signing_key_refused "$outcome"
fi
open_key=$work/open.key
printf 'open-signing-key\n' >"$open_key"
chmod 644 "$open_key"
signing_key_arm group_readable_signing_key_refused "$open_key" 'carries mode 644'
linked_key=$work/linked.key
ln -s "$token_key_file" "$linked_key"
signing_key_arm symlinked_signing_key_refused "$linked_key" 'is a symbolic link'
empty_key=$work/empty.key
: >"$empty_key"
chmod 600 "$empty_key"
signing_key_arm empty_signing_key_refused "$empty_key" 'is empty'

# One broker signs for one profile, so the preset supplies the profile and a
# second section or a contradicting QWEN_WEB_PROFILE refuses the launch.
two_section_presets=$state_directory/web-presets-two.ini
write_web_preset "$two_section_presets" unmarked
sed 's/^\[web-fixture\]$/[web-second]/; s/^LLAMA_ARG_ALIAS = web-fixture$/LLAMA_ARG_ALIAS = web-second/' \
    "$web_presets" | grep -v '^#' >>"$two_section_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$two_section_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/two.log" 2>"$work/two.err"; then
    report two_section_preset_refused accepted
else
    outcome=ok
    grep -q 'carries 2 sections' "$work/two.err" || outcome=missing_message
    report two_section_preset_refused "$outcome"
fi
# QWEN_WEB_REVIEW_SECTION admits exactly one more section, the review-only
# vision row qwen-image-launch.sh proved resident. The broker still signs for
# the one language profile, so the review section is subtracted before the
# profile is read and the router holds two children rather than one.
review_presets=$state_directory/web-presets-review.ini
review_projector=$policy_model_root/Fixture-GGUF/review-mmproj.gguf
: >"$review_projector"
write_web_preset "$review_presets" unmarked
{
    printf '[vision-fixture]\n'
    printf 'LLAMA_ARG_MODEL = %s\n' "$policy_model_root/Fixture-GGUF/production.gguf"
    printf 'LLAMA_ARG_ALIAS = vision-fixture\n'
    printf 'LLAMA_ARG_CTX_SIZE = 8192\n'
    printf 'LLAMA_ARG_CACHE_TYPE_K = q8_0\n'
    printf 'LLAMA_ARG_CACHE_TYPE_V = q4_0\n'
    printf 'LLAMA_ARG_FLASH_ATTN = on\n'
    printf 'LLAMA_ARG_BATCH = 128\n'
    printf 'LLAMA_ARG_UBATCH = 32\n'
    printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
    printf 'LLAMA_ARG_MMPROJ = %s\n' "$review_projector"
    printf 'LLAMA_ARG_TAGS = vision-review,review-only\n'
    printf '\n'
} >>"$review_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$review_presets QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_REVIEW_SECTION=vision-fixture \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/review.log" 2>"$work/review.err"; then
    outcome=ok
    grep -qx 'QWEN_ROUTER_MAX=2' "$record" || outcome=wrong_models_max
    grep -qx 'QWEN_WEB_PROFILE=web-fixture' "$record" || outcome=wrong_profile
    grep -q 'review_section=vision-fixture models_max=2' "$work/review.log" ||
        outcome=unreported
    report review_section_admits_two_sections "$outcome"
else
    report review_section_admits_two_sections refused
    cat "$work/review.err" >&2
fi

review_without_tag=$state_directory/web-presets-review-without-tag.ini
sed 's/LLAMA_ARG_TAGS = vision-review,review-only/LLAMA_ARG_TAGS = vision-review/' \
    "$review_presets" >"$review_without_tag"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$review_without_tag QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_REVIEW_SECTION=vision-fixture \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/review-without-tag.log" 2>"$work/review-without-tag.err"; then
    report untagged_review_section_refused accepted
elif grep -q 'must carry review-only' "$work/review-without-tag.err"; then
    report untagged_review_section_refused ok
else
    report untagged_review_section_refused wrong_refusal
fi

review_with_mcp=$state_directory/web-presets-review-with-mcp.ini
sed "/LLAMA_ARG_TAGS = vision-review,review-only/i LLAMA_ARG_MCP_SERVERS_CONFIG = $mcp_config" \
    "$review_presets" >"$review_with_mcp"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$review_with_mcp QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_REVIEW_SECTION=vision-fixture \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/review-with-mcp.log" 2>"$work/review-with-mcp.err"; then
    report armed_review_section_refused_at_launch accepted
elif grep -q 'must carry review-only' "$work/review-with-mcp.err"; then
    report armed_review_section_refused_at_launch ok
else
    report armed_review_section_refused_at_launch wrong_refusal
fi

validated_tuples_standalone=$work/validated-tuples-standalone.tsv
sed 's/\trouter-child\t/\tstandalone\t/' "$validated_tuples" \
    >"$validated_tuples_standalone"
review_with_standalone_tuple=$state_directory/web-presets-review-standalone.ini
sed -e "s|^# qwen_validated_tuples_path=.*|# qwen_validated_tuples_path=$validated_tuples_standalone|" \
    -e "s|^# qwen_validated_tuples_sha256=.*|# qwen_validated_tuples_sha256=$(sha256sum "$validated_tuples_standalone" | cut -d' ' -f1)|" \
    "$review_presets" >"$review_with_standalone_tuple"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$review_with_standalone_tuple QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_REVIEW_SECTION=vision-fixture \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/review-standalone.log" 2>"$work/review-standalone.err"; then
    report standalone_review_tuple_refused_at_launch accepted
elif grep -q 'no validated router-child Vulkan tuple' \
    "$work/review-standalone.err"; then
    report standalone_review_tuple_refused_at_launch ok
else
    report standalone_review_tuple_refused_at_launch wrong_refusal
fi

# The marker names a section rather than raising the limit on its own, so one
# that survived a regeneration refuses instead of admitting a second child the
# preset never carries.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_REVIEW_SECTION=vision-absent \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/review-absent.log" 2>"$work/review-absent.err"; then
    report absent_review_section_refused accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_REVIEW_SECTION names vision-absent' \
        "$work/review-absent.err" || outcome=missing_message
    report absent_review_section_refused "$outcome"
fi

if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_PROFILE=web-other \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/mismatch.log" 2>"$work/mismatch.err"; then
    report profile_mismatch_refused accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROFILE names web-other where the preset serves web-fixture' \
        "$work/mismatch.err" || outcome=missing_message
    report profile_mismatch_refused "$outcome"
fi
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_PROVIDER=other \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/provider.log" 2>"$work/provider.err"; then
    report unknown_provider_refused accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROVIDER names other where the preset serves exa' \
        "$work/provider.err" ||
        outcome=missing_message
    report unknown_provider_refused "$outcome"
fi
# A page without the model-scoped routes is refused before any launch, since
# the pinned llama UI build is what an unset static path would otherwise serve.
other_page=$work/other-ui
mkdir -p "$other_page"
printf '<html>upstream ui</html>\n' >"$other_page/index.html"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_STATIC_PATH=$other_page \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/static.log" 2>"$work/static.err"; then
    report foreign_page_refused accepted
else
    outcome=ok
    grep -q 'composes no model-scoped /tools request' "$work/static.err" ||
        outcome=missing_message
    report foreign_page_refused "$outcome"
fi
fake_provider_presets=$state_directory/web-presets-fake.ini
write_web_preset "$fake_provider_presets" unmarked fake
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$fake_provider_presets \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_PROFILES=$web_profiles \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/ledger.log" 2>"$work/ledger.err"; then
    outcome=ok
    grep -qx "QWEN_WEB_PROFILES=$web_profiles" "$record" || outcome=ledger_dropped
    grep -qx 'QWEN_WEB_PROVIDER=fake' "$record" || outcome=provider_dropped
    report preset_provider_derived_and_forwarded "$outcome"
else
    report preset_provider_derived_and_forwarded refused
    cat "$work/ledger.err" >&2
fi

# The marker state and the authorizer setting are reported before the launch.
if grep -q 'unvalidated_depth_marker=absent' "$work/launch.log" &&
    grep -q 'authorizer_ready=1' "$work/launch.log"; then
    report wrapper_reports_marker_and_authorizer_state ok
else
    report wrapper_reports_marker_and_authorizer_state missing_report
fi

marked_presets=$state_directory/web-presets-marked.ini
write_web_preset "$marked_presets" marked
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$marked_presets QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_AUTHORIZER_READY=1 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/marked.log" 2>"$work/marked.err"; then
    outcome=ok
    grep -q 'unvalidated_depth_marker=present' "$work/marked.log" ||
        outcome=marker_unreported
    grep -q 'authorizer_ready=1' "$work/marked.log" ||
        outcome=authorizer_unreported
    report wrapper_reports_present_marker "$outcome"
else
    report wrapper_reports_present_marker failed
    cat "$work/marked.err" >&2
fi

# A caller asking for a LAN listener is refused rather than served on the
# loopback while believing the LAN listens.
for lan_bind_host in 0.0.0.0 192.168.1.10; do
    if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_WEB_LAUNCH_RECORD=$record QWEN_BIND_HOST=$lan_bind_host \
        "$launcher" >"$work/lan.log" 2>"$work/lan.err"; then
        report "lan_bind_refused_$lan_bind_host" accepted
    else
        outcome=ok
        grep -q 'serves the loopback alone' "$work/lan.err" ||
            outcome=missing_message
        report "lan_bind_refused_$lan_bind_host" "$outcome"
    fi
done

# An explicit loopback request is honoured rather than refused.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_BIND_HOST=127.0.0.1 \
    "$launcher" >"$work/loopback.log" 2>"$work/loopback.err"; then
    report explicit_loopback_admitted ok
else
    report explicit_loopback_admitted refused
    cat "$work/loopback.err" >&2
fi

# QWEN_WEB_LAN=1 is the operator's explicit exposure. The arms below measure
# the six conditions remote/web-lan-exposure.sh applies, one refusal each, and
# then the admitted launch that exports the address the session binds.
lan_api_key=$state_directory/api.key
printf 'fixture-api-key\n' >"$lan_api_key"
chmod 600 "$lan_api_key"

for lan_case in unset:'' loopback:127.0.0.1 wildcard:0.0.0.0 name:qwen-laptop \
    short:192.168.1 wide:192.168.1.300; do
    lan_case_name=${lan_case%%:*}
    lan_case_address=${lan_case#*:}
    if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
        QWEN_WEB_LAN_ADDRESS=$lan_case_address \
        env -u QWEN_BIND_HOST "$launcher" \
        >"$work/lan-address.log" 2>"$work/lan-address.err"; then
        report "lan_exposure_address_refused_$lan_case_name" accepted
    else
        outcome=ok
        grep -q 'not a routable IPv4 literal' "$work/lan-address.err" ||
            outcome=missing_message
        report "lan_exposure_address_refused_$lan_case_name" "$outcome"
    fi
done

# The bind host is the exposure literal or the wildcard; a third address is a
# launch that would print one listener and bind another.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=192.168.1.11 \
    "$launcher" >"$work/lan-bind.log" 2>"$work/lan-bind.err"; then
    report lan_exposure_refuses_a_third_bind_host accepted
else
    outcome=ok
    grep -q 'QWEN_BIND_HOST is that literal or 0.0.0.0' "$work/lan-bind.err" ||
        outcome=missing_message
    report lan_exposure_refuses_a_third_bind_host "$outcome"
fi

# The bearer is what stands between a LAN reader and every route, so an absent
# API key file refuses the exposure rather than being minted alongside it.
mv "$lan_api_key" "$work/api.key.held"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-key.log" 2>"$work/lan-key.err"; then
    report lan_exposure_requires_an_existing_api_key accepted
else
    outcome=ok
    grep -q 'finds no Web UI API key file' "$work/lan-key.err" ||
        outcome=missing_message
    report lan_exposure_requires_an_existing_api_key "$outcome"
fi
mv "$work/api.key.held" "$lan_api_key"

# A key a group or the world can read is a credential on a shared machine.
chmod 644 "$lan_api_key"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-mode.log" 2>"$work/lan-mode.err"; then
    report lan_exposure_requires_a_private_api_key accepted
else
    outcome=ok
    grep -q 'at mode 644 rather than 0600' "$work/lan-mode.err" ||
        outcome=missing_message
    report lan_exposure_requires_a_private_api_key "$outcome"
fi
chmod 600 "$lan_api_key"

# qwen-capacity-policy.sh forces the loopback for either research override, so
# an exposure combined with one would print an address it never binds. Both are
# refused here instead.
lan_marked_presets=$state_directory/web-presets-lan-marked.ini
write_web_preset "$lan_marked_presets" marked
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$lan_marked_presets QWEN_WEB_LAUNCH_RECORD=$record \
    QWEN_WEB_LAN=1 QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-marked.log" 2>"$work/lan-marked.err"; then
    report lan_exposure_refuses_the_unvalidated_depth_override accepted
else
    outcome=ok
    grep -q 'a depth no run has filled and decoded' "$work/lan-marked.err" ||
        outcome=missing_message
    report lan_exposure_refuses_the_unvalidated_depth_override "$outcome"
fi

if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_ROUTER_INCLUDE_QUARANTINE=1 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-quarantine.log" 2>"$work/lan-quarantine.err"; then
    report lan_exposure_refuses_the_quarantine_override accepted
else
    outcome=ok
    grep -q 'recorded device failure serves the loopback' \
        "$work/lan-quarantine.err" || outcome=missing_message
    report lan_exposure_refuses_the_quarantine_override "$outcome"
fi

# The admitted exposure exports the literal and the bind host the session
# reads, and names every listener before the model loads.
for lan_bind_case in literal:192.168.1.10 wildcard:0.0.0.0; do
    lan_bind_name=${lan_bind_case%%:*}
    lan_bind_value=${lan_bind_case#*:}
    if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
        QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=$lan_bind_value \
        "$launcher" >"$work/lan-ok.log" 2>"$work/lan-ok.err"; then
        outcome=ok
        grep -qx 'QWEN_WEB_LAN=1' "$record" || outcome=marker_dropped
        grep -qx 'QWEN_WEB_LAN_ADDRESS=192.168.1.10' "$record" ||
            outcome=address_dropped
        grep -qx "QWEN_BIND_HOST=$lan_bind_value" "$record" ||
            outcome=wrong_bind_host
        grep -qx 'QWEN_REQUIRE_API_KEY=1' "$record" || outcome=api_key_not_required
        grep -q 'exposure=lan address=192.168.1.10' "$work/lan-ok.log" ||
            outcome=exposure_unreported
        grep -q 'bearer=required' "$work/lan-ok.log" || outcome=bearer_unreported
        grep -q 'broker=' "$work/lan-ok.log" || outcome=broker_address_unreported
        report "lan_exposure_admitted_$lan_bind_name" "$outcome"
    else
        report "lan_exposure_admitted_$lan_bind_name" refused
        cat "$work/lan-ok.err" >&2
    fi
done

# A bare LAN page URL derives the broker and artifact origins as
# router_port+1 and router_port+2, so this wrapper matches that derivation on
# a LAN exposure rather than fixing 8571: a router port of 8080 pairing with
# a fixed broker 8571 would leave every web approval and artifact load
# targeting a port the advertised URL never names.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=0.0.0.0 \
    "$launcher" >"$work/lan-broker-port.log" 2>"$work/lan-broker-port.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_BROKER_PORT=8081' "$record" || outcome=wrong_broker_port
    report lan_exposure_derives_the_broker_port "$outcome"
else
    report lan_exposure_derives_the_broker_port refused
    cat "$work/lan-broker-port.err" >&2
fi

# An explicit QWEN_WEB_BROKER_PORT names its own value and is not derived, so
# it still overrides the LAN derivation where it agrees with what a bare LAN
# page URL would derive on its own.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=0.0.0.0 \
    QWEN_SERVER_PORT=9000 QWEN_WEB_BROKER_PORT=9001 \
    "$launcher" >"$work/lan-broker-port-override.log" \
    2>"$work/lan-broker-port-override.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_BROKER_PORT=9001' "$record" || outcome=override_dropped
    report lan_exposure_broker_port_override_wins "$outcome"
else
    report lan_exposure_broker_port_override_wins refused
    cat "$work/lan-broker-port-override.err" >&2
fi

# webui/index.html derives the broker and artifact origins from the loaded
# port at fixed offsets whenever the page was reached at a bare LAN URL, and
# the bare URL is exactly what this launch advertises, so an override that
# disagrees with that derivation would serve a broker the advertised page
# cannot reach.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=0.0.0.0 \
    QWEN_WEB_BROKER_PORT=19000 \
    "$launcher" >"$work/lan-broker-port-mismatch.log" \
    2>"$work/lan-broker-port-mismatch.err"; then
    report lan_exposure_broker_port_mismatch_refused admitted
elif grep -q 'names 19000 where the advertised page URL derives 8081' \
    "$work/lan-broker-port-mismatch.err"; then
    report lan_exposure_broker_port_mismatch_refused ok
else
    report lan_exposure_broker_port_mismatch_refused wrong_reason
    cat "$work/lan-broker-port-mismatch.err" >&2
fi

# A derived broker port at or beyond the top of the valid TCP range overflows
# when the session derives the artifact port one higher again, the same
# overflow remote/qwen-lan-launch.sh's own 65533 cap on QWEN_SERVER_PORT
# exists to keep out of its wrapper path.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_BIND_HOST=0.0.0.0 \
    QWEN_SERVER_PORT=65535 \
    "$launcher" >"$work/lan-broker-port-overflow.log" \
    2>"$work/lan-broker-port-overflow.err"; then
    report lan_exposure_broker_port_overflow_refused admitted
elif grep -q 'leaves room for the broker and artifact ports above it' \
    "$work/lan-broker-port-overflow.err"; then
    report lan_exposure_broker_port_overflow_refused ok
else
    report lan_exposure_broker_port_overflow_refused wrong_reason
    cat "$work/lan-broker-port-overflow.err" >&2
fi

# The mDNS name is a second admitted host rather than a replacement, so the
# wrapper forwards it beside the literal and names it on its own report line.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local \
    QWEN_BIND_HOST=0.0.0.0 \
    "$launcher" >"$work/lan-named.log" 2>"$work/lan-named.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_LAN_NAME=qwen-test.local' "$record" || outcome=name_dropped
    grep -qx 'QWEN_WEB_LAN_ADDRESS=192.168.1.10' "$record" ||
        outcome=address_dropped
    grep -q 'name=qwen-test.local' "$work/lan-named.log" || outcome=name_unreported
    grep -q 'bearer=required' "$work/lan-named.log" || outcome=bearer_unreported
    report lan_exposure_admits_the_mdns_name "$outcome"
else
    report lan_exposure_admits_the_mdns_name refused
    cat "$work/lan-named.err" >&2
fi

# One spelling reaches every reader: a browser lowercases the host in the Origin
# it sends and both children compare an origin exactly, so a mixed-case name
# would configure an allowlist entry no request presents.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=QWEN-Test.LOCAL \
    QWEN_BIND_HOST=0.0.0.0 \
    "$launcher" >"$work/lan-case.log" 2>"$work/lan-case.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_LAN_NAME=qwen-test.local' "$record" || outcome=name_not_lowercased
    grep -q 'name=qwen-test.local' "$work/lan-case.log" || outcome=name_misreported
    report lan_exposure_name_is_lowercased "$outcome"
else
    report lan_exposure_name_is_lowercased refused
    cat "$work/lan-case.err" >&2
fi

# A name outside the letter-digit-hyphen set names no host a browser resolves.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME='qwen test.local' \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-badname.log" 2>"$work/lan-badname.err"; then
    report lan_exposure_name_refused admitted
else
    outcome=ok
    grep -q 'not a hostname a browser resolves on the link' \
        "$work/lan-badname.err" || outcome=missing_message
    report lan_exposure_name_refused "$outcome"
fi

# A name outside the .local namespace resolves through the recursive
# resolver like any other DNS name, so an attacker who controls its zone can
# rebind it to this address; web_lan_name_is_valid() refuses it on syntax
# alone rather than admitting it into the Host and Origin sets QWEN_WEB_LAN_
# OPEN=1 would then serve with no bearer behind them.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=attacker.example \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-foreign-namespace.log" 2>"$work/lan-foreign-namespace.err"; then
    report lan_exposure_name_outside_local_refused admitted
else
    outcome=ok
    grep -q 'not a hostname a browser resolves on the link' \
        "$work/lan-foreign-namespace.err" || outcome=missing_message
    report lan_exposure_name_outside_local_refused "$outcome"
fi

# QWEN_WEB_LAN_OPEN=1 removes a bearer from a listener the operator exposed, so
# a loopback launch carrying it refuses rather than serving an authenticated
# listener while the operator believes the credential is gone.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN_OPEN=1 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-open-alone.log" 2>"$work/lan-open-alone.err"; then
    report lan_open_refused_without_exposure admitted
else
    outcome=ok
    grep -q 'removes the bearer from a LAN listener, and this launch exposes none' \
        "$work/lan-open-alone.err" || outcome=missing_message
    report lan_open_refused_without_exposure "$outcome"
fi

# The admitted open exposure carries QWEN_REQUIRE_API_KEY=0 across the tmux
# boundary and reports the removed bearer where the bearer mode reports a
# required one. The API key file stays unread, so the arm holds it away.
mv "$lan_api_key" "$work/api.key.open"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local \
    QWEN_WEB_LAN_OPEN=1 QWEN_BIND_HOST=0.0.0.0 \
    "$launcher" >"$work/lan-open.log" 2>"$work/lan-open.err"; then
    outcome=ok
    grep -qx 'QWEN_REQUIRE_API_KEY=0' "$record" || outcome=key_still_required
    grep -qx 'QWEN_WEB_LAN_OPEN=1' "$record" || outcome=open_marker_dropped
    grep -q 'lan_open=1' "$work/lan-open.log" || outcome=open_unreported
    grep -q 'bearer=removed' "$work/lan-open.log" || outcome=bearer_state_unreported
    report lan_open_admitted "$outcome"
else
    report lan_open_admitted refused
    cat "$work/lan-open.err" >&2
fi
mv "$work/api.key.open" "$lan_api_key"

# An open exposure that also asked for the bearer states two policies, so the
# launch refuses rather than serving one of them.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=1 \
    QWEN_REQUIRE_API_KEY=1 QWEN_BIND_HOST=0.0.0.0 \
    "$launcher" >"$work/lan-open-key.log" 2>"$work/lan-open-key.err"; then
    report lan_open_refuses_a_requested_bearer admitted
else
    outcome=ok
    grep -q 'removes the bearer, and QWEN_REQUIRE_API_KEY names 1' \
        "$work/lan-open-key.err" || outcome=missing_message
    report lan_open_refuses_a_requested_bearer "$outcome"
fi

# The open opt-in meets both research overrides on the exposure's own terms.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=1 \
    QWEN_ROUTER_INCLUDE_QUARANTINE=1 \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/lan-open-quarantine.log" 2>"$work/lan-open-quarantine.err"; then
    report lan_open_refuses_the_quarantine_override admitted
else
    outcome=ok
    grep -q 'recorded device failure serves the loopback' \
        "$work/lan-open-quarantine.err" || outcome=missing_message
    report lan_open_refuses_the_quarantine_override "$outcome"
fi

# The default launch prints the loopback exposure and refuses a LAN bind with
# the message it already carried.
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/loopback-report.log" 2>"$work/loopback-report.err"; then
    outcome=ok
    grep -q 'exposure=loopback router=127.0.0.1' "$work/loopback-report.log" ||
        outcome=exposure_unreported
    grep -qx 'QWEN_BIND_HOST=127.0.0.1' "$record" || outcome=wrong_bind_host
    grep -qx 'QWEN_WEB_LAN=1' "$record" && outcome=marker_leaked
    report default_launch_reports_loopback_exposure "$outcome"
else
    report default_launch_reports_loopback_exposure refused
    cat "$work/loopback-report.err" >&2
fi

# A section naming an MCP configuration the launch cannot read refuses before
# the listener comes up, where llama-server would report a child startup fault.
absent_mcp_presets=$state_directory/web-presets-absent-mcp.ini
write_web_preset "$absent_mcp_presets" unmarked
sed -i 's|^LLAMA_ARG_MCP_SERVERS_CONFIG = .*|LLAMA_ARG_MCP_SERVERS_CONFIG = /nonexistent/web-mcp.json|' \
    "$absent_mcp_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$absent_mcp_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/absent-mcp.log" 2>"$work/absent-mcp.err"; then
    report absent_mcp_config_refused accepted
else
    outcome=ok
    grep -q 'unreadable MCP configuration' "$work/absent-mcp.err" ||
        outcome=missing_message
    report absent_mcp_config_refused "$outcome"
fi

# A vision section names its projector in LLAMA_ARG_MMPROJ, which router mode
# reads when the request selects that child. A preset persists across the
# generation that resolved the file, so a projector deleted or moved since then
# refuses the launch rather than leaving the listener ready and the image
# request answered from nothing.
projector_path=$policy_model_root/Fixture-GGUF/mmproj-F16.gguf
: >"$projector_path"
present_projector_presets=$state_directory/web-presets-projector.ini
write_web_preset "$present_projector_presets" unmarked
printf 'LLAMA_ARG_MMPROJ = %s\n' "$projector_path" >>"$present_projector_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$present_projector_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/projector-present.log" 2>"$work/projector-present.err"; then
    report present_projector_admitted ok
else
    report present_projector_admitted refused
    cat "$work/projector-present.err" >&2
fi

absent_projector_presets=$state_directory/web-presets-absent-projector.ini
write_web_preset "$absent_projector_presets" unmarked
printf 'LLAMA_ARG_MMPROJ = %s\n' "$policy_model_root/Fixture-GGUF/absent-mmproj.gguf" \
    >>"$absent_projector_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$absent_projector_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/absent-projector.log" 2>"$work/absent-projector.err"; then
    report absent_projector_refused accepted
else
    outcome=ok
    grep -q 'projector that is not a regular file' \
        "$work/absent-projector.err" || outcome=missing_message
    report absent_projector_refused "$outcome"
fi

# A projector path holding a space reaches the check whole, the way the MCP
# configuration path does.
mkdir -p "$policy_model_root/Fixture Vision GGUF"
spaced_projector_path="$policy_model_root/Fixture Vision GGUF/mmproj-F16.gguf"
: >"$spaced_projector_path"
spaced_projector_presets=$state_directory/web-presets-spaced-projector.ini
write_web_preset "$spaced_projector_presets" unmarked
printf 'LLAMA_ARG_MMPROJ = %s\n' "$spaced_projector_path" \
    >>"$spaced_projector_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$spaced_projector_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/spaced-projector.log" 2>"$work/spaced-projector.err"; then
    report spaced_projector_path_admitted ok
else
    report spaced_projector_path_admitted refused
    cat "$work/spaced-projector.err" >&2
fi

# A preset file carrying no web provenance marker refuses, since the policy
# would resolve its sections as registry ids.
plain_presets=$state_directory/plain-presets.ini
sed '/^# qwen_web_presets=1$/d' "$web_presets" >"$plain_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$plain_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/plain.log" 2>"$work/plain.err"; then
    report unmarked_preset_refused accepted
else
    report unmarked_preset_refused ok
fi

# The policy enforces the same loopback from the file itself. A marked preset
# launched at 0.0.0.0 reaches llama-server bound to 127.0.0.1.
model_registry=$work/models.tsv
{
    printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tprojector_fetch_script\tdecode_tok_s\tprefill_tok_s\tquality\ttier\tbatch\tubatch\tvalidated_filled_depth\tvalidation_evidence\traw_tool_selection\tguarded_tool_execution\n'
    printf 'fixture-production\tfixture-role\tFixture-GGUF/production.gguf\tdownload-fixture.sh\t8192\t16384\t32768\tq8_0\tq4_0\ton\tnone\t-\t1.00\t1.00\tuntested\tproduction\t128\t32\t16384\tevidence/fixture.md\t9/10\trefused\n'
} >"$model_registry"

quarantine_registry=$work/quarantine.tsv
printf '# reason_id\tscope\tsubject\tconsumers\tdepth\tbatch\tubatch\tcache_type_k\tcache_type_v\tflash_attention\n' \
    >"$quarantine_registry"

# Every policy arm uses the ledger identity written into the fixture preset.

fake_icd=$work/radeon_icd.x86_64.json
: >"$fake_icd"
policy_output=$work/policy.out

run_policy() {
    QWEN_MODEL_REGISTRY=$model_registry QWEN_MODEL_ROOT=$policy_model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry QWEN_RADV_ICD=$fake_icd \
    QWEN_WEB_PROFILES=${QWEN_WEB_PROFILES:-$web_profiles} \
    QWEN_POLICY_TEST_OUTPUT=$policy_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$1 QWEN_ROUTER_MAX=1 QWEN_BIND_HOST=$2 \
        "$policy" "$fake_server" \
        "$policy_model_root/Fixture-GGUF/production.gguf" 8192 18080
}

policy_host_argument() {
    sed -n 's/^argument=//p' "$policy_output" |
        awk '/^--host$/ { getline; print; exit }'
}

if run_policy "$marked_presets" 0.0.0.0 \
    >"$work/policy-marked.log" 2>"$work/policy-marked.err"; then
    if [ "$(policy_host_argument)" = 127.0.0.1 ]; then
        report policy_forces_loopback_on_marked_preset ok
    else
        report policy_forces_loopback_on_marked_preset "$(policy_host_argument)"
    fi
else
    report policy_forces_loopback_on_marked_preset failed
    cat "$work/policy-marked.err" >&2
fi

# An unmarked web preset leaves the requested listener in place, so the arm
# above measures the marker rather than router mode.
if run_policy "$web_presets" 0.0.0.0 \
    >"$work/policy-unmarked.log" 2>"$work/policy-unmarked.err"; then
    if [ "$(policy_host_argument)" = 0.0.0.0 ]; then
        report policy_keeps_listener_without_marker ok
    else
        report policy_keeps_listener_without_marker "$(policy_host_argument)"
    fi
else
    report policy_keeps_listener_without_marker failed
    cat "$work/policy-unmarked.err" >&2
fi

if QWEN_WEB_AUTHORIZER_READY=0 run_policy "$web_presets" 127.0.0.1 \
    >"$work/policy-authorizer-absent.log" \
    2>"$work/policy-authorizer-absent.err"; then
    report policy_requires_authorizer_for_validator_gated accepted
elif grep -q 'web preset section web-fixture requires QWEN_WEB_AUTHORIZER_READY=1' \
    "$work/policy-authorizer-absent.err"; then
    report policy_requires_authorizer_for_validator_gated ok
else
    report policy_requires_authorizer_for_validator_gated missing_message
fi

# The policy reads every tuple key out of a web section, so an absent
# LLAMA_ARG_UBATCH and a diverging cache V type each refuse the launch.
missing_ubatch_presets=$state_directory/web-presets-missing-ubatch.ini
sed '/^LLAMA_ARG_UBATCH =/d' "$web_presets" >"$missing_ubatch_presets"
if run_policy "$missing_ubatch_presets" 127.0.0.1 \
    >"$work/missing-ubatch.log" 2>"$work/missing-ubatch.err"; then
    report policy_refuses_missing_ubatch accepted
else
    report policy_refuses_missing_ubatch ok
fi

wrong_cache_v_presets=$state_directory/web-presets-wrong-cache-v.ini
sed 's/^LLAMA_ARG_CACHE_TYPE_V = .*/LLAMA_ARG_CACHE_TYPE_V = q8_0/' \
    "$web_presets" >"$wrong_cache_v_presets"
if run_policy "$wrong_cache_v_presets" 127.0.0.1 \
    >"$work/wrong-cache-v.log" 2>"$work/wrong-cache-v.err"; then
    report policy_refuses_diverging_cache_v accepted
else
    report policy_refuses_diverging_cache_v ok
fi

absent_cache_v_presets=$state_directory/web-presets-absent-cache-v.ini
sed '/^LLAMA_ARG_CACHE_TYPE_V =/d' "$web_presets" >"$absent_cache_v_presets"
if run_policy "$absent_cache_v_presets" 127.0.0.1 \
    >"$work/absent-cache-v.log" 2>"$work/absent-cache-v.err"; then
    report policy_refuses_absent_cache_v accepted
else
    report policy_refuses_absent_cache_v ok
fi

# A web section requesting a depth above its row's context_ceiling refuses,
# which is the bound that replaces the context_default equality a router
# section carries.
over_ceiling_presets=$state_directory/web-presets-over-ceiling.ini
sed 's/^LLAMA_ARG_CTX_SIZE = .*/LLAMA_ARG_CTX_SIZE = 32768/' \
    "$web_presets" >"$over_ceiling_presets"
if run_policy "$over_ceiling_presets" 127.0.0.1 \
    >"$work/over-ceiling.log" 2>"$work/over-ceiling.err"; then
    report policy_refuses_context_above_ceiling accepted
else
    report policy_refuses_context_above_ceiling ok
fi

# A depth inside the ceiling and above context_default is admitted, which is the
# depth freedom a profile exists to express.
inside_ceiling_presets=$state_directory/web-presets-inside-ceiling.ini
sed 's/^LLAMA_ARG_CTX_SIZE = .*/LLAMA_ARG_CTX_SIZE = 16384/' \
    "$web_presets" >"$inside_ceiling_presets"
if run_policy "$inside_ceiling_presets" 127.0.0.1 \
    >"$work/inside-ceiling.log" 2>"$work/inside-ceiling.err"; then
    report policy_admits_context_inside_ceiling ok
else
    report policy_admits_context_inside_ceiling refused
    cat "$work/inside-ceiling.err" >&2
fi

# A generated tree under a path holding a space names one readable
# configuration, and the launch admits it. Field splitting over command
# substitution would report each fragment of that one path as unreadable.
spaced_state_directory="$work/state with space"
mkdir -p "$spaced_state_directory/web mcp configs"
spaced_mcp_config="$spaced_state_directory/web mcp configs/web-fixture.json"
printf '{}\n' >"$spaced_mcp_config"
spaced_presets="$spaced_state_directory/web-presets.ini"
write_web_preset "$spaced_presets" unmarked
sed -i "s|^LLAMA_ARG_MCP_SERVERS_CONFIG = .*|LLAMA_ARG_MCP_SERVERS_CONFIG = $spaced_mcp_config|" \
    "$spaced_presets"
if QWEN_WEBUI_STATE_DIRECTORY="$spaced_state_directory" \
    QWEN_WEB_PRESETS="$spaced_presets" QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/spaced.log" 2>"$work/spaced.err"; then
    report spaced_mcp_config_path_admitted ok
else
    report spaced_mcp_config_path_admitted refused
    cat "$work/spaced.err" >&2
fi

# The count of unreadable configurations survives the loop, which a pipeline
# would leave at zero by running the body in a subshell. A preset naming one
# readable and one absent configuration refuses.
mixed_presets=$state_directory/web-presets-mixed-mcp.ini
write_web_preset "$mixed_presets" unmarked
{
    printf '[web-fixture-second]\n'
    printf 'LLAMA_ARG_MODEL = %s\n' "$policy_model_root/Fixture-GGUF/production.gguf"
    printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = /nonexistent/second-web-mcp.json\n'
    printf '\n'
} >>"$mixed_presets"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$mixed_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST "$launcher" \
    >"$work/mixed-mcp.log" 2>"$work/mixed-mcp.err"; then
    report absent_mcp_config_beside_readable_refused accepted
else
    outcome=ok
    grep -q '/nonexistent/second-web-mcp.json' "$work/mixed-mcp.err" ||
        outcome=missing_message
    report absent_mcp_config_beside_readable_refused "$outcome"
fi

# A preset persists across a registry edit, so the launch rechecks the depth
# against the registry it reads now. build-web-presets.sh admits a context above
# validated_filled_depth only under the marker, and a registry that later lowers
# that field, or sets it to `-`, leaves an unmarked section serving a depth no
# run has filled and decoded.
write_lowered_registry() {
    {
        printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tprojector_fetch_script\tdecode_tok_s\tprefill_tok_s\tquality\ttier\tbatch\tubatch\tvalidated_filled_depth\tvalidation_evidence\traw_tool_selection\tguarded_tool_execution\n'
        printf 'fixture-production\tfixture-role\tFixture-GGUF/production.gguf\tdownload-fixture.sh\t8192\t16384\t32768\tq8_0\tq4_0\ton\tnone\t-\t1.00\t1.00\tuntested\tproduction\t128\t32\t%s\tevidence/fixture.md\t9/10\trefused\n' \
            "$1"
    } >"$2"
}

# A router preset joins the draft-pair ledger against the model registry, so a
# fabricated registry names its own ledger. An empty one admits no pairing,
# which is what the plain-router depth rule below is measured against.
fixture_draft_pairs=$work/draft-pairs.tsv
printf '# the web-launch fixture admits no draft pairing\n' \
    >"$fixture_draft_pairs"
run_policy_with_registry() {
    QWEN_MODEL_REGISTRY=$1 QWEN_MODEL_ROOT=$policy_model_root \
    QWEN_DRAFT_PAIRS=$fixture_draft_pairs \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry QWEN_RADV_ICD=$fake_icd \
    QWEN_WEB_PROFILES=${QWEN_WEB_PROFILES:-$web_profiles} \
    QWEN_POLICY_TEST_OUTPUT=$policy_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$2 QWEN_ROUTER_MAX=1 QWEN_BIND_HOST=127.0.0.1 \
        "$policy" "$fake_server" \
        "$policy_model_root/Fixture-GGUF/production.gguf" 8192 18080
}

depth_presets=$state_directory/web-presets-depth.ini
sed 's/^LLAMA_ARG_CTX_SIZE = .*/LLAMA_ARG_CTX_SIZE = 16384/' \
    "$web_presets" >"$depth_presets"
marked_depth_presets=$state_directory/web-presets-depth-marked.ini
sed 's/^LLAMA_ARG_CTX_SIZE = .*/LLAMA_ARG_CTX_SIZE = 16384/' \
    "$marked_presets" >"$marked_depth_presets"

for lowered_depth in 8192 -; do
    lowered_registry=$work/models-lowered-$lowered_depth.tsv
    write_lowered_registry "$lowered_depth" "$lowered_registry"
    case $lowered_depth in
        -) lowered_case=unmeasured ;;
        *) lowered_case=lowered ;;
    esac
    if run_policy_with_registry "$lowered_registry" "$depth_presets" \
        >"$work/depth-$lowered_case.log" 2>"$work/depth-$lowered_case.err"; then
        report "policy_refuses_${lowered_case}_filled_depth" accepted
    else
        outcome=ok
        grep -q 'web-fixture' "$work/depth-$lowered_case.err" ||
            outcome=missing_section
        report "policy_refuses_${lowered_case}_filled_depth" "$outcome"
    fi

    # The marker is the claim the generator recorded when it admitted an
    # unvalidated depth, so a marked preset still launches and reaches the
    # loopback the marker forces.
    if run_policy_with_registry "$lowered_registry" "$marked_depth_presets" \
        >"$work/depth-marked-$lowered_case.log" \
        2>"$work/depth-marked-$lowered_case.err"; then
        report "policy_admits_marked_${lowered_case}_filled_depth" ok
    else
        report "policy_admits_marked_${lowered_case}_filled_depth" refused
        cat "$work/depth-marked-$lowered_case.err" >&2
    fi
done

# A plain router preset carries no web provenance, and its depth rule stays the
# context_default equality; the fixture row's `-` filled depth leaves it
# admitted, so the new bound reaches web sections alone.
router_presets_plain=$state_directory/router-presets-plain.ini
{
    printf '# Generated by remote/build-router-presets.sh from the model registry.\n'
    printf '# qwen_router_include_quarantine=0\n'
    printf '\n'
    printf '[fixture-production]\n'
    printf 'LLAMA_ARG_MODEL = %s\n' "$policy_model_root/Fixture-GGUF/production.gguf"
    printf 'LLAMA_ARG_ALIAS = fixture-production\n'
    printf 'LLAMA_ARG_CTX_SIZE = 8192\n'
    printf 'LLAMA_ARG_CACHE_TYPE_K = q8_0\n'
    printf 'LLAMA_ARG_CACHE_TYPE_V = q4_0\n'
    printf 'LLAMA_ARG_FLASH_ATTN = on\n'
    printf 'LLAMA_ARG_BATCH = 128\n'
    printf 'LLAMA_ARG_UBATCH = 32\n'
    printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
    printf 'LLAMA_ARG_TAGS = production,fixture-role,default\n'
    printf '\n'
} >"$router_presets_plain"
unmeasured_registry=$work/models-lowered---.tsv
write_lowered_registry - "$unmeasured_registry"
if run_policy_with_registry "$unmeasured_registry" "$router_presets_plain" \
    >"$work/router-plain.log" 2>"$work/router-plain.err"; then
    report router_preset_keeps_context_default_rule ok
else
    report router_preset_keeps_context_default_rule refused
    cat "$work/router-plain.err" >&2
fi


# execution_policy is the security boundary the ledger states and a preset
# persists across an edit to it, so the launch rejoins each section to the
# current ledger. A row moved to refused, removed outright, or moved to another
# emitting policy than the section's tags claim refuses the launch; an
# unreadable ledger refuses it the way an unreadable quarantine authority does.
revoked_profiles=$work/web-profiles-revoked.tsv
write_web_profiles refused "$revoked_profiles"
if QWEN_WEB_PROFILES=$revoked_profiles run_policy "$web_presets" 127.0.0.1 \
    >"$work/revoked.log" 2>"$work/revoked.err"; then
    report policy_refuses_revoked_execution_policy accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROFILES names .* where the preset binds' \
        "$work/revoked.err" ||
        outcome=missing_message
    report policy_refuses_revoked_execution_policy "$outcome"
fi

vanished_profiles=$work/web-profiles-vanished.tsv
write_web_profiles validator-gated "$vanished_profiles"
sed -i '/^web-fixture\t/d' "$vanished_profiles"
if QWEN_WEB_PROFILES=$vanished_profiles run_policy "$web_presets" 127.0.0.1 \
    >"$work/vanished.log" 2>"$work/vanished.err"; then
    report policy_refuses_vanished_profile accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROFILES names .* where the preset binds' \
        "$work/vanished.err" || outcome=missing_message
    report policy_refuses_vanished_profile "$outcome"
fi

# A row moved between two emitting policies leaves the persisted
# LLAMA_ARG_MCP_SERVERS_CONFIG in a section the ledger now says reaches no
# network, so the section's claimed policy is compared against the ledger's.
moved_profiles=$work/web-profiles-moved.tsv
write_web_profiles ui-mediated "$moved_profiles"
if QWEN_WEB_PROFILES=$moved_profiles run_policy "$web_presets" 127.0.0.1 \
    >"$work/moved.log" 2>"$work/moved.err"; then
    report policy_refuses_moved_execution_policy accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROFILES names .* where the preset binds' \
        "$work/moved.err" ||
        outcome=missing_message
    report policy_refuses_moved_execution_policy "$outcome"
fi

if QWEN_WEB_PROFILES=$work/web-profiles-absent.tsv \
    run_policy "$web_presets" 127.0.0.1 \
    >"$work/ledger-absent.log" 2>"$work/ledger-absent.err"; then
    report policy_refuses_unreadable_ledger accepted
else
    outcome=ok
    grep -q 'QWEN_WEB_PROFILES names .* where the preset binds' \
        "$work/ledger-absent.err" ||
        outcome=missing_message
    report policy_refuses_unreadable_ledger "$outcome"
fi

# The unchanged ledger is the control: the same preset launches where the row
# still carries the policy its section claims.
if run_policy "$web_presets" 127.0.0.1 \
    >"$work/ledger-control.log" 2>"$work/ledger-control.err"; then
    report policy_admits_unchanged_ledger ok
else
    report policy_admits_unchanged_ledger refused
    cat "$work/ledger-control.err" >&2
fi

identity_profiles=$work/web-profiles-identity.tsv
write_web_profiles validator-gated "$identity_profiles"
identity_presets=$state_directory/web-presets-identity.ini
original_web_profiles=$web_profiles
web_profiles=$identity_profiles
write_web_preset "$identity_presets" unmarked
web_profiles=$original_web_profiles
printf '# changed after preset generation\n' >>"$identity_profiles"
if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_WEB_PRESETS=$identity_presets QWEN_WEB_LAUNCH_RECORD=$record \
    env -u QWEN_BIND_HOST -u QWEN_WEB_PROFILES "$launcher" \
    >"$work/ledger-identity.log" 2>"$work/ledger-identity.err"; then
    report wrapper_refuses_changed_ledger_identity accepted
elif grep -q 'web profile ledger identity changed:' \
    "$work/ledger-identity.err"; then
    report wrapper_refuses_changed_ledger_identity ok
else
    report wrapper_refuses_changed_ledger_identity missing_message
fi

# Provider searxng makes the launch the owner of one local instance. The
# endpoint comes off the profile row, and the wrapper admits the loopback
# instance this chain starts: a remote endpoint names a service the launch
# neither starts nor tears down, and a busy port names one it cannot own.
write_searxng_web_profiles() {
    printf '# profile_id\tmodel_id\tweb_mode\tcontext\tvalidated_filled_depth\tmax_results\tmax_fetches\tmax_chars_per_fetch\tmulti_source\tvision_allowed\ttool_selection\texecution_policy\tprovider\tprimary_category\tfallback_category\tminimum_results\tsearxng_url\n' \
        >"$2"
    printf 'web-fixture\tfixture-production\tvalidator-gated\t8192\t16384\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\tsearxng\tqwen-open\tqwen-broad\t3\t%s\n' \
        "$1" >>"$2"
}

searxng_arm() {
    arm_name=$1
    arm_url=$2
    arm_expectation=$3
    arm_message=${4:-}
    arm_profiles=$work/web-profiles-$arm_name.tsv
    arm_presets=$state_directory/web-presets-$arm_name.ini
    write_searxng_web_profiles "$arm_url" "$arm_profiles"
    arm_original_profiles=$web_profiles
    web_profiles=$arm_profiles
    write_web_preset "$arm_presets" unmarked searxng
    web_profiles=$arm_original_profiles
    if QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
        QWEN_WEB_PRESETS=$arm_presets QWEN_WEB_LAUNCH_RECORD=$record \
        env -u QWEN_BIND_HOST -u QWEN_WEB_PROFILES "$launcher" \
        >"$work/$arm_name.log" 2>"$work/$arm_name.err"; then
        if [ "$arm_expectation" = accepted ]; then
            arm_outcome=ok
            grep -qx 'QWEN_WEB_SEARXNG=1' "$record" || arm_outcome=marker_unset
            grep -qx "QWEN_SEARXNG_PORT=${arm_url##*:}" "$record" ||
                arm_outcome=port_underived
            grep -q 'searxng=owned' "$work/$arm_name.log" ||
                arm_outcome=ownership_unreported
            report "$arm_name" "$arm_outcome"
        else
            report "$arm_name" accepted
        fi
    elif [ "$arm_expectation" = refused ]; then
        if grep -q "$arm_message" "$work/$arm_name.err"; then
            report "$arm_name" ok
        else
            report "$arm_name" missing_message
        fi
    else
        report "$arm_name" refused
        cat "$work/$arm_name.err" >&2
    fi
}

searxng_arm searxng_launch_owns_loopback_instance \
    http://127.0.0.1:18888 accepted
searxng_arm searxng_remote_endpoint_refused \
    http://searx.example.org:8888 refused \
    'this launch starts the loopback instance alone'

# The session's readiness gate reads a socket and its own child together, so a
# listener already on the port makes the launch a refusal here rather than a
# failure after the model has begun loading.
python3 -c '
import socket
import sys
import time

listener = socket.socket()
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(("127.0.0.1", 18889))
listener.listen(1)
sys.stdout.write("bound\n")
sys.stdout.flush()
time.sleep(30)
' >"$work/busy-port.marker" 2>/dev/null &
busy_port_pid=$!
wait_for_path "$work/busy-port.marker"
attempt=0
while [ "$attempt" -lt 300 ] && ! grep -q bound "$work/busy-port.marker"; do
    attempt=$((attempt + 1))
    sleep 0.1
done
searxng_arm searxng_busy_port_refused \
    http://127.0.0.1:18889 refused 'already carries a listener'
kill "$busy_port_pid" 2>/dev/null || true
wait "$busy_port_pid" 2>/dev/null || true

if [ "$failures" -ne 0 ]; then
    printf 'test-qwen-web-launch: %d check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-qwen-web-launch: all checks passed\n'
