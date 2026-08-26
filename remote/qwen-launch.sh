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

if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server is already running; run qwen-teardown.sh first\n' >&2
    exit 2
fi

model_path=${QWEN_MODEL_PATH:-"${HOME:?}/models/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf"}

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
# is absent or ambiguous. remote/test-projector-pairing.sh covers its branches.
model_directory=$(dirname -- "$model_path")
mmproj=${QWEN_MMPROJ:-$("$script_directory/select-projector.sh" "$model_path")}
if [ -z "$mmproj" ] && [ "${QWEN_FETCH_MMPROJ:-0}" = 1 ] && \
   [ -x "$script_directory/download-qwen35-4b-mmproj.sh" ]; then
    "$script_directory/download-qwen35-4b-mmproj.sh" "$model_directory" || true
    mmproj=$("$script_directory/select-projector.sh" "$model_path")
fi
[ -n "$mmproj" ] && [ -f "$mmproj" ] || mmproj=''
[ -n "$mmproj" ] && printf 'projector=%s\n' "$(basename -- "$mmproj")"

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
       curl --silent --fail "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
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
printf 'stop it with %s/qwen-teardown.sh\n' "$script_directory"
