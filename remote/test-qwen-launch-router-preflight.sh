#!/bin/sh
set -eu

# Router preflight consumes every model path from one unique preset snapshot.
# The fixture proves malformed sections fail closed and source replacement
# cannot change the snapshot handed to the session.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT INT TERM
fixture_remote=$temporary_directory/remote
fixture_bin=$temporary_directory/bin
mkdir -p "$fixture_remote" "$fixture_bin"
cp "$script_directory/qwen-launch.sh" "$fixture_remote/qwen-launch.sh"
cp "$script_directory/qwen-teardown.sh" "$fixture_remote/qwen-teardown.sh"

cat >"$fixture_bin/pgrep" <<'PGREP'
#!/bin/sh
exit 1
PGREP

chmod +x "$fixture_remote"/*.sh "$fixture_bin"/*
state_directory=$temporary_directory/custom-state
source_router_presets=$state_directory/router-presets.ini
mkdir -p "$state_directory"
printf '%s\n' '[broken]' 'LLAMA_ARG_CTX_SIZE = 4096' \
    >"$source_router_presets"
set +e
HOME=$temporary_directory QWEN_ROUTER=1 \
QWEN_MODEL_PATH=$temporary_directory/models/Normal/small.gguf \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/launch.stdout" \
    2>"$temporary_directory/launch.stderr"
launch_status=$?
set -e

if [ "$launch_status" -eq 0 ]; then
    printf 'launcher accepted a preset section without a model path: %s\n' \
        "$launch_status" >&2
    exit 1
fi
grep -F 'router preflight section broken requires exactly one LLAMA_ARG_MODEL' \
    "$temporary_directory/launch.stderr" >/dev/null
for leftover_snapshot in "$state_directory"/.router-presets.active.*; do
    if [ -e "$leftover_snapshot" ]; then
        printf 'failed preflight retained a router snapshot: %s\n' \
            "$leftover_snapshot" >&2
        exit 1
    fi
done

missing_model=$temporary_directory/models/Missing/large.gguf
printf '%s\n' '[missing]' "LLAMA_ARG_MODEL = $missing_model" \
    >"$source_router_presets"
set +e
HOME=$temporary_directory QWEN_ROUTER=1 \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/missing-model.stdout" \
    2>"$temporary_directory/missing-model.stderr"
missing_model_status=$?
set -e
if [ "$missing_model_status" -eq 0 ]; then
    printf 'launcher omitted a missing preset model from preflight\n' >&2
    exit 1
fi
grep -F "router preflight model is not a regular file: $missing_model" \
    "$temporary_directory/missing-model.stderr" >/dev/null

# A durable research marker expands the preflight denominator before the
# launcher selects the largest installed model. The quarantined checkpoint is
# larger than the normal row and therefore becomes the weight-size subject.
cat >"$fixture_remote/select-projector.sh" <<'PROJECTOR'
#!/bin/sh
exit 0
PROJECTOR
cat >"$fixture_remote/qwen-webui-control.sh" <<'CONTROL'
#!/bin/sh
if [ "$1" = stop ]; then
    exit 0
fi
mkdir -p "$QWEN_WEBUI_STATE_DIRECTORY"
measured_identity=$(sha256sum "$QWEN_ROUTER_PRESETS")
measured_sha256=${measured_identity%% *}
printf 'presets=%s\nexpected_sha256=%s\nmeasured_sha256=%s\n' \
    "$QWEN_ROUTER_PRESETS" "$QWEN_ROUTER_PRESET_SHA256" "$measured_sha256" \
    >"$FIXTURE_CONTROL_LOG"
sed -n '1p' "$QWEN_ROUTER_PRESETS" >>"$FIXTURE_CONTROL_LOG"
printf 'state=running fixture=1\n' >"$QWEN_WEBUI_STATE_DIRECTORY/session.status"
if [ -n "${QWEN_TEST_CONTROL_WAIT_MARKER:-}" ]; then
    : >"$QWEN_TEST_CONTROL_WAIT_MARKER"
    while [ ! -e "$QWEN_TEST_CONTROL_RELEASE" ]; do
        sleep 0.01
    done
fi
exit 0
CONTROL
cat >"$fixture_bin/curl" <<'CURL'
#!/bin/sh
[ -z "${QWEN_TEST_CURL_MARKER:-}" ] || : >"$QWEN_TEST_CURL_MARKER"
exit 0
CURL
cat >"$fixture_bin/tmux" <<'TMUX'
#!/bin/sh
exit 1
TMUX
cat >"$fixture_bin/ss" <<'SS'
#!/bin/sh
exit 0
SS
cat >"$fixture_bin/stat" <<'STAT'
#!/bin/sh
case ${FIXTURE_STAT_MODE:-success}:$* in
    fail:*Quarantine/large.gguf)
        exit 9
        ;;
esac
if [ ! -e "$FIXTURE_MUTATION_MARKER" ]; then
    printf '%s\n' '# qwen_router_include_quarantine=0' \
        >"$FIXTURE_SOURCE_PRESET"
    : >"$FIXTURE_MUTATION_MARKER"
fi
exec "$FIXTURE_REAL_STAT" "$@"
STAT
chmod +x "$fixture_remote"/*.sh "$fixture_bin"/*

mkdir -p "$temporary_directory/models/Normal" \
    "$temporary_directory/models/Quarantine"
printf 'x' >"$temporary_directory/models/Normal/small.gguf"
printf 'larger' >"$temporary_directory/models/Quarantine/large.gguf"
printf '%s\n' \
    '# qwen_router_include_quarantine=1' \
    '[normal]' \
    "LLAMA_ARG_MODEL = $temporary_directory/models/Normal/small.gguf" \
    '[quarantine]' \
    "LLAMA_ARG_MODEL = $temporary_directory/models/Quarantine/large.gguf" \
    >"$source_router_presets"
set +e
HOME=$temporary_directory QWEN_ROUTER=1 \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
FIXTURE_STAT_MODE=fail FIXTURE_SOURCE_PRESET=$source_router_presets \
FIXTURE_MUTATION_MARKER=$temporary_directory/stat-failure-no-mutation \
FIXTURE_REAL_STAT=$(command -v stat) PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/stat-failure.stdout" \
    2>"$temporary_directory/stat-failure.stderr"
stat_failure_status=$?
set -e
if [ "$stat_failure_status" -eq 0 ]; then
    printf 'launcher omitted an unstatable preset model from preflight\n' >&2
    exit 1
fi
grep -F 'router preflight cannot measure model bytes:' \
    "$temporary_directory/stat-failure.stderr" >/dev/null

# Restore the source preset after the stat fixture exercises its mutation hook.
printf '%s\n' \
    '# qwen_router_include_quarantine=1' \
    '[normal]' \
    "LLAMA_ARG_MODEL = $temporary_directory/models/Normal/small.gguf" \
    '[quarantine]' \
    "LLAMA_ARG_MODEL = $temporary_directory/models/Quarantine/large.gguf" \
    >"$source_router_presets"
HOME=$temporary_directory QWEN_ROUTER=1 \
QWEN_MODEL_PATH=$temporary_directory/models/Normal/small.gguf \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
FIXTURE_SOURCE_PRESET=$source_router_presets \
FIXTURE_MUTATION_MARKER=$temporary_directory/source-mutated \
FIXTURE_REAL_STAT=$(command -v stat) \
FIXTURE_CONTROL_LOG=$temporary_directory/control.log \
PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/override-launch.stdout" \
    2>"$temporary_directory/override-launch.stderr"
grep -Fx 'router_preflight_subject=large.gguf bytes=6' \
    "$temporary_directory/override-launch.stdout" >/dev/null
preset_snapshot=$(sed -n 's/^presets=//p' \
    "$temporary_directory/control.log")
case $preset_snapshot in
    "$state_directory"/.router-presets.active.*) ;;
    *)
        printf 'control received a non-unique preset snapshot: %s\n' \
            "$preset_snapshot" >&2
        exit 1
        ;;
esac
expected_sha256=$(sed -n 's/^expected_sha256=//p' \
    "$temporary_directory/control.log")
measured_sha256=$(sed -n 's/^measured_sha256=//p' \
    "$temporary_directory/control.log")
[ "$expected_sha256" = "$measured_sha256" ]
grep -Fx '# qwen_router_include_quarantine=1' \
    "$temporary_directory/control.log" >/dev/null
grep -Fx '[quarantine]' "$preset_snapshot" >/dev/null
grep -Fx '# qwen_router_include_quarantine=0' \
    "$source_router_presets" >/dev/null

# A terminating signal transfers control to a handler that removes the owned
# snapshot and exits with the signal status before readiness polling begins.
printf '%s\n' \
    '# qwen_router_include_quarantine=0' \
    '[normal]' \
    "LLAMA_ARG_MODEL = $temporary_directory/models/Normal/small.gguf" \
    >"$source_router_presets"
cancellation_mutation_marker=$temporary_directory/cancellation-no-mutation
: >"$cancellation_mutation_marker"
cancellation_control_log=$temporary_directory/cancellation-control.log
cancellation_wait_marker=$temporary_directory/cancellation-control-waiting
cancellation_release=$temporary_directory/cancellation-control-release
cancellation_curl_marker=$temporary_directory/cancellation-curl-ran
HOME=$temporary_directory QWEN_ROUTER=1 \
QWEN_MODEL_PATH=$temporary_directory/models/Normal/small.gguf \
QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
QWEN_TEST_CONTROL_WAIT_MARKER=$cancellation_wait_marker \
QWEN_TEST_CONTROL_RELEASE=$cancellation_release \
QWEN_TEST_CURL_MARKER=$cancellation_curl_marker \
FIXTURE_SOURCE_PRESET=$source_router_presets \
FIXTURE_MUTATION_MARKER=$cancellation_mutation_marker \
FIXTURE_REAL_STAT=$(command -v stat) \
FIXTURE_CONTROL_LOG=$cancellation_control_log \
PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-launch.sh" \
    >"$temporary_directory/cancellation.stdout" \
    2>"$temporary_directory/cancellation.stderr" &
cancellation_pid=$!
cancellation_attempt=0
while [ ! -e "$cancellation_wait_marker" ] && \
      [ "$cancellation_attempt" -lt 100 ]; do
    cancellation_attempt=$((cancellation_attempt + 1))
    sleep 0.01
done
if [ ! -e "$cancellation_wait_marker" ]; then
    kill -TERM "$cancellation_pid" 2>/dev/null || true
    wait "$cancellation_pid" 2>/dev/null || true
    printf 'launcher did not reach the cancellable control boundary\n' >&2
    exit 1
fi
kill -TERM "$cancellation_pid"
: >"$cancellation_release"
set +e
wait "$cancellation_pid"
cancellation_status=$?
set -e
if [ "$cancellation_status" -ne 143 ]; then
    printf 'terminated launcher returned %s instead of 143\n' \
        "$cancellation_status" >&2
    exit 1
fi
cancellation_snapshot=$(sed -n 's/^presets=//p' "$cancellation_control_log")
if [ -e "$cancellation_snapshot" ] || [ -L "$cancellation_snapshot" ]; then
    printf 'terminated launcher retained its router snapshot: %s\n' \
        "$cancellation_snapshot" >&2
    exit 1
fi
if [ -e "$cancellation_curl_marker" ]; then
    printf 'terminated launcher entered readiness polling\n' >&2
    exit 1
fi

dangling_snapshot=$state_directory/.router-presets.active.dangling
ln -s "$state_directory/absent-snapshot-target" "$dangling_snapshot"
HOME=$temporary_directory QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
PATH="$fixture_bin:$PATH" \
    "$fixture_remote/qwen-teardown.sh" \
    >"$temporary_directory/teardown.stdout" \
    2>"$temporary_directory/teardown.stderr"
if [ -e "$preset_snapshot" ]; then
    printf 'forced teardown retained router snapshot: %s\n' \
        "$preset_snapshot" >&2
    exit 1
fi
if [ -L "$dangling_snapshot" ]; then
    printf 'forced teardown retained dangling router snapshot: %s\n' \
        "$dangling_snapshot" >&2
    exit 1
fi
printf 'qwen_launch_router_preflight=accepted\n'
