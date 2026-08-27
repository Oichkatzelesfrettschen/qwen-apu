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
# larger than the normal row and therefore becomes the memory-safety subject.
cat >"$fixture_remote/select-projector.sh" <<'PROJECTOR'
#!/bin/sh
exit 0
PROJECTOR
cat >"$fixture_remote/qwen-webui-control.sh" <<'CONTROL'
#!/bin/sh
mkdir -p "$QWEN_WEBUI_STATE_DIRECTORY"
measured_identity=$(sha256sum "$QWEN_ROUTER_PRESETS")
measured_sha256=${measured_identity%% *}
printf 'presets=%s\nexpected_sha256=%s\nmeasured_sha256=%s\n' \
    "$QWEN_ROUTER_PRESETS" "$QWEN_ROUTER_PRESET_SHA256" "$measured_sha256" \
    >"$FIXTURE_CONTROL_LOG"
sed -n '1p' "$QWEN_ROUTER_PRESETS" >>"$FIXTURE_CONTROL_LOG"
printf 'state=running fixture=1\n' >"$QWEN_WEBUI_STATE_DIRECTORY/session.status"
exit 0
CONTROL
cat >"$fixture_remote/qwen-teardown.sh" <<'TEARDOWN'
#!/bin/sh
exit 0
TEARDOWN
cat >"$fixture_bin/curl" <<'CURL'
#!/bin/sh
exit 0
CURL
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

# Restore the marker after the stat-failure fixture mutates no source content.
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
printf 'qwen_launch_router_preflight=accepted\n'
