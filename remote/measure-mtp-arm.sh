#!/bin/sh
set -eu

# One temporal-amortization mechanism measured against a same-session control
# at each admitted draft length.
#
# Temporal amortization emits more than one token per traversal of the target's
# weights. Two mechanisms reach it at the pinned build. `--spec-type draft-mtp`
# clears the TENSOR_SKIP that src/models/qwen35.cpp applies to the distill's
# appended prediction block and builds a draft context against the target model
# itself, so one checkpoint stays resident. `--spec-type draft-simple` loads a
# second checkpoint through common_base_params_to_speculative and drafts with
# it. Both verify N + 1 columns in one target pass, and
# evidence/4b-temporal-amortization/README.md prices that pass by column count.
#
# The arm order inside each draft length is control, mechanism, mechanism,
# control. This machine measures the same checkpoint under identical flags
# spanning 30.6% between sweeps, so a mechanism is read against controls that
# met the same machine minutes earlier and the mirrored order charges drift
# within the session to both halves. Each draft length carries its own
# quadruple, so a comparison between two depths is also a comparison inside one
# invocation.
#
# Two surfaces carry the speculation counters and the summary treats them
# differently. server_slot_stats::to_json in tools/server/server-common.cpp adds
# timings.draft_n and timings.draft_n_accepted to a completion response where
# that request drafted anything, and every count the summary scores comes from
# there: the verification step count is predicted_n - draft_n_accepted - 1
# exactly, since each round emits one target token beside the drafts it accepts
# and the first token arrives from the prompt logits.
#
# /metrics under --metrics carries the cumulative
# spec_decode_num_draft_tokens_total, spec_decode_num_accepted_tokens_total, and
# spec_decode_num_drafts_total, and this harness brackets each request with a
# read of it. That delta is a second route to the same three numbers rather than
# an authority over them: update_slots calls send_final_response(slot) ahead of
# slot.release(), and release() is where callback_on_reset runs
# metrics_on_prediction, so the response leaves the inference thread before the
# fold and a read taken once curl returns is unordered against it. The summary
# reports the comparison on its steps_agreement line.
#
# The harness owns the device for its whole run, so it refuses to start while a
# server answers on either the appliance or measurement port.

if [ "$#" -ne 3 ]; then
    printf 'usage: %s MECHANISM SUBJECT OUTPUT_DIRECTORY\n' "$0" >&2
    printf '  MECHANISM draft-mtp reads SUBJECT as a models.tsv model_id whose\n' >&2
    printf '    GGUF states nextn_predict_layers at one or more; a checkpoint\n' >&2
    printf '    without the block reports draft_absent after its four loads\n' >&2
    printf '  MECHANISM draft-simple reads SUBJECT as a draft-pairs.tsv pair_id\n' >&2
    printf '  QWEN_PRODUCTION_BUILD_DIR names the promoted build (required)\n' >&2
    printf '  QWEN_VULKAN_WORKLOAD_LOCK names the absolute shared lease (required)\n' >&2
    printf '  QWEN_MTP_ARM_N_MAX lists the draft lengths, default "1 2 3"\n' >&2
    printf '  QWEN_MODELS_DIRECTORY names the model root, default models/ under the runtime root (QWEN_HOME)\n' >&2
    exit 2
fi

mechanism=$1
subject=$2
output_directory=$3
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
registry_source=$script_directory/model-registry.sh
model_registry_source=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
draft_pair_registry_source=${QWEN_DRAFT_PAIRS:-$script_directory/draft-pairs.tsv}
quarantine_registry_source=${QWEN_QUARANTINE_REGISTRY:-$script_directory/quarantine.tsv}
priority_wrapper=${QWEN_MTP_ARM_PRIORITY_WRAPPER:-"$script_directory/qwen-exec-idle-priority.sh"}
vulkan_profile_wrapper=${QWEN_MTP_ARM_VULKAN_WRAPPER:-"$script_directory/radv-low-priority-env.sh"}
vulkan_profile=${QWEN_MTP_ARM_VULKAN_PROFILE:-low-async}
measurement_runner_source=$script_directory/measure-mtp-arm.sh
summarizer_source=$script_directory/summarize-speculation-breakeven.py
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
production_build_directory=${QWEN_PRODUCTION_BUILD_DIR:-}
server_relative_path=${QWEN_MTP_ARM_SERVER_RELATIVE:-bin/llama-server}
server_port=${QWEN_MTP_ARM_PORT:-8099}
predict_tokens=${QWEN_MTP_ARM_PREDICT:-128}
sampling_seed=${QWEN_MTP_ARM_SEED:-42}
thread_count=${QWEN_MTP_ARM_THREADS:-1}
readiness_seconds=${QWEN_MTP_ARM_READY_SECONDS:-180}
request_seconds=${QWEN_MTP_ARM_REQUEST_SECONDS:-1800}
draft_length_list=${QWEN_MTP_ARM_N_MAX:-1 2 3}
target_rate=${QWEN_MTP_ARM_TARGET_RATE:-5.25}
appliance_port=${QWEN_SERVER_PORT:-8080}
workload_lock=${QWEN_VULKAN_WORKLOAD_LOCK:-}

case $mechanism in
    draft-mtp | draft-simple) ;;
    *)
        printf 'MECHANISM must be draft-mtp or draft-simple: %s\n' "$mechanism" >&2
        exit 2
        ;;
esac

for positive_value in \
    "$predict_tokens" "$thread_count" "$server_port" "$appliance_port"; do
    case $positive_value in
        '' | *[!0-9]* | 0)
            printf 'predict, threads, and port must be positive integers: %s\n' \
                "$positive_value" >&2
            exit 2
            ;;
    esac
done

# A draft length reaches --spec-draft-n-max, and common_speculative_get_output_limits
# sizes the target context for 1 + max(0, n_draft) outputs while the speculative
# decode path requests two, so a zero aborts the server on its first request.
# The occupancy step evidence/mtp-speculation-matrix.md measures at the fifth
# verified column bounds the other end: a draft of 4 verifies five columns and
# both arms past it decoded slower than no speculation at all.
draft_length_count=0
seen_draft_lengths=
for draft_length in $draft_length_list; do
    case $draft_length in
        '' | *[!0-9]* | 0)
            printf 'QWEN_MTP_ARM_N_MAX holds positive integers: %s\n' \
                "$draft_length" >&2
            exit 2
            ;;
    esac
    if [ "$draft_length" -gt 3 ]; then
        printf 'draft length %s verifies past the measured occupancy step at five columns\n' \
            "$draft_length" >&2
        exit 2
    fi
    # An arm directory is named for its draft length, so a repeated length
    # writes its second quadruple over the first while the summary reads the
    # surviving files once per listed occurrence and weights them twice.
    case " $seen_draft_lengths " in
        *" $draft_length "*)
            printf 'QWEN_MTP_ARM_N_MAX repeats draft length %s\n' \
                "$draft_length" >&2
            exit 2
            ;;
    esac
    seen_draft_lengths="$seen_draft_lengths $draft_length"
    draft_length_count=$((draft_length_count + 1))
done
if [ "$draft_length_count" -eq 0 ]; then
    printf 'QWEN_MTP_ARM_N_MAX names no draft length\n' >&2
    exit 2
fi

if [ -z "$production_build_directory" ]; then
    printf 'QWEN_PRODUCTION_BUILD_DIR is required\n' >&2
    exit 2
fi
if ! command -v flock >/dev/null 2>&1; then
    printf 'temporal-amortization measurement requires flock\n' >&2
    exit 2
fi
if ! python3 - <<'PY'
import os
import signal

raise SystemExit(
    0
    if hasattr(os, "pidfd_open") and hasattr(signal, "pidfd_send_signal")
    else 1
)
PY
then
    printf 'temporal-amortization measurement requires Python pidfd signal support\n' >&2
    exit 2
fi
if [ -z "$workload_lock" ] || [ "${workload_lock#/}" = "$workload_lock" ]; then
    printf 'QWEN_VULKAN_WORKLOAD_LOCK must name the absolute shared lease path\n' >&2
    exit 2
fi
if [ ! -d "$(dirname -- "$workload_lock")" ]; then
    printf 'Vulkan workload lease directory is absent: %s\n' \
        "$(dirname -- "$workload_lock")" >&2
    exit 2
fi
for required_wrapper in \
    "$priority_wrapper" "$vulkan_profile_wrapper" "$measurement_runner_source" \
    "$registry_source"; do
    if [ ! -x "$required_wrapper" ]; then
        printf 'temporal-amortization execution wrapper is not executable: %s\n' \
            "$required_wrapper" >&2
        exit 1
    fi
done
if [ ! -f "$summarizer_source" ]; then
    printf 'break-even summarizer is not a regular file: %s\n' \
        "$summarizer_source" >&2
    exit 1
fi
for registry_authority in "$model_registry_source" \
    "$draft_pair_registry_source" "$quarantine_registry_source"; do
    if [ ! -f "$registry_authority" ]; then
        printf 'temporal-amortization registry authority is not a regular file: %s\n' \
            "$registry_authority" >&2
        exit 1
    fi
done
server_program=$production_build_directory/$server_relative_path
if [ ! -x "$server_program" ]; then
    printf 'the promoted build holds no executable server: %s\n' \
        "$server_program" >&2
    exit 1
fi

# The measurement owns the shared Vulkan execution surface from preflight
# through summary publication. The child receives an empty lease variable
# because this parent already holds exclusion across every server lifetime.
exec 9>"$workload_lock"
if ! flock -n 9; then
    printf 'another Vulkan workload holds the shared lease: %s\n' \
        "$workload_lock" >&2
    exit 2
fi

refuse_resident_server() {
    guarded_port=$1
    if curl --silent --fail --max-time 2 \
        "http://127.0.0.1:$guarded_port/health" >/dev/null 2>&1; then
        printf 'a server answers /health on port %s; run %s after qwen-teardown.sh\n' \
            "$guarded_port" "$(basename "$0")" >&2
        return 1
    fi
}
refuse_resident_server "$appliance_port"
if [ "$server_port" != "$appliance_port" ]; then
    refuse_resident_server "$server_port"
fi

# An absent path is claimed with one mkdir before registry lookup or hashing,
# so a failed rerun cannot leave an older summary masquerading as the new one.
umask 077
if ! mkdir -- "$output_directory"; then
    printf 'output path must be absent for one immutable measurement: %s\n' \
        "$output_directory" >&2
    exit 2
fi
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)

if ! source_root=$(git -C "$script_directory" rev-parse --show-toplevel 2>/dev/null) ||
   ! source_revision=$(git -C "$source_root" rev-parse --verify HEAD 2>/dev/null); then
    printf 'temporal-amortization source directory has no readable Git revision: %s\n' \
        "$script_directory" >&2
    exit 1
fi

file_sha256() {
    sha256sum "$1" | awk '{ print $1 }'
}
file_bytes() {
    wc -c <"$1" | tr -d '[:space:]'
}

# The executable registry reader and all three ledgers become one immutable
# authority snapshot before any field is read. Explicit environment paths point
# every retained-reader query, including its recursive quarantine query, at
# these exact copies.
registry_source_sha256=$(file_sha256 "$registry_source")
model_registry_source_sha256=$(file_sha256 "$model_registry_source")
draft_pair_registry_source_sha256=$(file_sha256 "$draft_pair_registry_source")
quarantine_registry_source_sha256=$(file_sha256 "$quarantine_registry_source")

registry_retained=$output_directory/model-registry.sh
model_registry_retained=$output_directory/models.tsv
draft_pair_registry_retained=$output_directory/draft-pairs.tsv
quarantine_registry_retained=$output_directory/quarantine.tsv
cp -- "$registry_source" "$registry_retained"
cp -- "$model_registry_source" "$model_registry_retained"
cp -- "$draft_pair_registry_source" "$draft_pair_registry_retained"
cp -- "$quarantine_registry_source" "$quarantine_registry_retained"
if [ "$registry_source_sha256" != "$(file_sha256 "$registry_retained")" ] ||
   [ "$model_registry_source_sha256" != \
       "$(file_sha256 "$model_registry_retained")" ] ||
   [ "$draft_pair_registry_source_sha256" != \
       "$(file_sha256 "$draft_pair_registry_retained")" ] ||
   [ "$quarantine_registry_source_sha256" != \
       "$(file_sha256 "$quarantine_registry_retained")" ]; then
    printf 'temporal-amortization registry authority changed while snapshots were copied\n' >&2
    exit 1
fi

registry_query() {
    QWEN_MODEL_REGISTRY=$model_registry_retained \
    QWEN_DRAFT_PAIRS=$draft_pair_registry_retained \
    QWEN_QUARANTINE_REGISTRY=$quarantine_registry_retained \
        "$registry_retained" "$@"
}
registry_field() {
    registry_query id "$1" "$2"
}

# The mechanism decides which ledger names the subject and which artifacts stay
# resident. draft-mtp holds one checkpoint and reads the model registry alone;
# draft-simple holds two and reads the pair ledger for the draft and its cache
# triple. A quarantined subject names a device failure or the absence of any
# safe tuple, and a measurement is the one thing that would construct it again.
draft_model_id=-
draft_path=-
draft_cache_type_k=-
draft_cache_type_v=-
spec_draft_p_min=${QWEN_MTP_ARM_P_MIN:-0.00}
acceptance_floor=-
if [ "$mechanism" = draft-simple ]; then
    pair_row=$(registry_query draft-pair "$subject")
    pair_field() {
        printf '%s\n' "$pair_row" | sed -n "s/^$1=//p"
    }
    target_model_id=$(pair_field target_model_id)
    draft_model_id=$(pair_field draft_model_id)
    pair_tier=$(pair_field tier)
    spec_draft_p_min=$(pair_field spec_draft_p_min)
    acceptance_floor=$(pair_field acceptance_floor)
    draft_cache_type_k=$(pair_field draft_cache_type_k)
    draft_cache_type_v=$(pair_field draft_cache_type_v)
    if [ "$pair_tier" = quarantine ]; then
        printf 'pair %s is tiered quarantine; read evidence/quarantine/ before measuring it\n' \
            "$subject" >&2
        exit 1
    fi
    draft_path=$models_directory/$(registry_field "$draft_model_id" model_file)
else
    target_model_id=$subject
    target_tier=$(registry_field "$target_model_id" tier)
    if [ "$target_tier" = quarantine ]; then
        printf 'model %s is tiered quarantine; read evidence/quarantine/ before measuring it\n' \
            "$subject" >&2
        exit 1
    fi
fi

target_path=$models_directory/$(registry_field "$target_model_id" model_file)
target_context=$(registry_field "$target_model_id" context_default)
target_batch=$(registry_field "$target_model_id" batch)
target_ubatch=$(registry_field "$target_model_id" ubatch)
target_cache_k=$(registry_field "$target_model_id" cache_type_k)
target_cache_v=$(registry_field "$target_model_id" cache_type_v)
target_flash=$(registry_field "$target_model_id" flash_attention)

if [ ! -f "$target_path" ]; then
    printf 'the subject names an artifact this machine holds no file for: %s\n' \
        "$target_path" >&2
    exit 1
fi
if [ "$mechanism" = draft-simple ] && [ ! -f "$draft_path" ]; then
    printf 'the pairing names an artifact this machine holds no file for: %s\n' \
        "$draft_path" >&2
    exit 1
fi

measurement_runner_sha256=$(file_sha256 "$measurement_runner_source")
measurement_runner_bytes=$(file_bytes "$measurement_runner_source")
summarizer_sha256=$(file_sha256 "$summarizer_source")
summarizer_bytes=$(file_bytes "$summarizer_source")
measurement_runner_retained=$output_directory/measure-mtp-arm.sh
summarizer_retained=$output_directory/summarize-speculation-breakeven.py
cp -- "$measurement_runner_source" "$measurement_runner_retained"
cp -- "$summarizer_source" "$summarizer_retained"
summarizer_retained_sha256=$(file_sha256 "$summarizer_retained")
summarizer_retained_bytes=$(file_bytes "$summarizer_retained")
if [ "$measurement_runner_sha256" != \
       "$(file_sha256 "$measurement_runner_retained")" ] ||
   [ "$summarizer_sha256" != "$summarizer_retained_sha256" ] ||
   [ "$summarizer_bytes" != "$summarizer_retained_bytes" ]; then
    printf 'temporal-amortization source changed while the retained tools were copied\n' >&2
    exit 1
fi

target_model_sha256=$(file_sha256 "$target_path")
target_model_bytes=$(file_bytes "$target_path")
draft_model_sha256=-
draft_model_bytes=-
if [ "$mechanism" = draft-simple ]; then
    draft_model_sha256=$(file_sha256 "$draft_path")
    draft_model_bytes=$(file_bytes "$draft_path")
fi
server_sha256=$(file_sha256 "$server_program")
server_bytes=$(file_bytes "$server_program")
priority_wrapper_sha256=$(file_sha256 "$priority_wrapper")
priority_wrapper_bytes=$(file_bytes "$priority_wrapper")
vulkan_profile_wrapper_sha256=$(file_sha256 "$vulkan_profile_wrapper")
vulkan_profile_wrapper_bytes=$(file_bytes "$vulkan_profile_wrapper")

# Copy an external corpus once, then validate and consume only the retained
# copy. A caller may rewrite the source path after this point without changing
# the requests in the measurement.
prompt_file=$output_directory/prompts.tsv
if [ -n "${QWEN_MTP_ARM_PROMPTS:-}" ]; then
    prompt_source=$QWEN_MTP_ARM_PROMPTS
    if [ ! -f "$prompt_source" ]; then
        printf 'temporal-amortization prompt source is not a regular file: %s\n' \
            "$prompt_source" >&2
        exit 2
    fi
    cp -- "$prompt_source" "$prompt_file"
else
    prompt_source=builtin-v1
    cat >"$prompt_file" <<'PROMPTS'
code	Write a Python function that reads a CSV file of measurements, groups the rows by their first column, and returns the mean of the third column per group. Include the imports, error handling for a missing file, and a short docstring.
prose	Explain, in plain prose, why a laptop integrated GPU that shares its memory with the CPU reaches a different decode rate than a discrete card with the same nominal compute, and what a reader should measure to tell the two limits apart.
arithmetic	Start with 12. Add 7, multiply by 3, subtract 11, divide by 2, add 40, multiply by 2, subtract 19. Show the running value after every single operation on its own line, then state the final value.
PROMPTS
fi
if ! awk -F'\t' '
    NF != 2 || $1 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ || $2 == "" {
        printf "invalid temporal-amortization prompt row %d\n", NR > "/dev/stderr"
        bad = 1
    }
    seen[$1]++ {
        printf "duplicate temporal-amortization prompt name %s\n", $1 > "/dev/stderr"
        bad = 1
    }
    END { exit bad ? 1 : 0 }
' "$prompt_file"; then
    exit 2
fi
prompt_sha256=$(file_sha256 "$prompt_file")
prompt_bytes=$(file_bytes "$prompt_file")

{
    printf 'mechanism=%s\nsubject=%s\n' "$mechanism" "$subject"
    printf 'target_model_id=%s\ndraft_model_id=%s\n' \
        "$target_model_id" "$draft_model_id"
    printf 'draft_length_list=%s\n' "$draft_length_list"
    printf 'spec_draft_p_min=%s\nacceptance_floor=%s\n' \
        "$spec_draft_p_min" "$acceptance_floor"
    printf 'draft_cache_type_k=%s\ndraft_cache_type_v=%s\n' \
        "$draft_cache_type_k" "$draft_cache_type_v"
    printf 'context=%s\nbatch=%s\nubatch=%s\n' \
        "$target_context" "$target_batch" "$target_ubatch"
    printf 'cache_type_k=%s\ncache_type_v=%s\nflash_attention=%s\n' \
        "$target_cache_k" "$target_cache_v" "$target_flash"
    printf 'predict_tokens=%s\nseed=%s\nthreads=%s\n' \
        "$predict_tokens" "$sampling_seed" "$thread_count"
    printf 'target_rate=%s\n' "$target_rate"
    printf 'production_build=%s\n' "$production_build_directory"
    printf 'source_root=%s\nsource_revision=%s\n' \
        "$source_root" "$source_revision"
    printf 'registry_source=%s\nregistry_source_sha256=%s\n' \
        "$registry_source" "$registry_source_sha256"
    printf 'model_registry_source=%s\nmodel_registry_source_sha256=%s\n' \
        "$model_registry_source" "$model_registry_source_sha256"
    printf 'draft_pair_registry_source=%s\ndraft_pair_registry_source_sha256=%s\n' \
        "$draft_pair_registry_source" "$draft_pair_registry_source_sha256"
    printf 'quarantine_registry_source=%s\nquarantine_registry_source_sha256=%s\n' \
        "$quarantine_registry_source" "$quarantine_registry_source_sha256"
    printf 'measurement_runner_source=%s\nmeasurement_runner_sha256=%s\n' \
        "$measurement_runner_source" "$measurement_runner_sha256"
    printf 'measurement_runner_bytes=%s\n' "$measurement_runner_bytes"
    printf 'summarizer_source=%s\nsummarizer_sha256=%s\nsummarizer_bytes=%s\n' \
        "$summarizer_source" "$summarizer_sha256" "$summarizer_bytes"
    printf 'summarizer_retained=%s\nsummarizer_retained_sha256=%s\n' \
        "$summarizer_retained" "$summarizer_retained_sha256"
    printf 'summarizer_execution_check=%s\n' \
        "$output_directory/summarizer-execution-check.tsv"
    printf 'target_model=%s\ntarget_model_sha256=%s\ntarget_model_bytes=%s\n' \
        "$target_path" "$target_model_sha256" "$target_model_bytes"
    printf 'draft_model=%s\ndraft_model_sha256=%s\ndraft_model_bytes=%s\n' \
        "$draft_path" "$draft_model_sha256" "$draft_model_bytes"
    printf 'server_sha256=%s\nserver_bytes=%s\n' \
        "$server_sha256" "$server_bytes"
    printf 'priority_wrapper=%s\npriority_wrapper_sha256=%s\n' \
        "$priority_wrapper" "$priority_wrapper_sha256"
    printf 'priority_wrapper_bytes=%s\n' "$priority_wrapper_bytes"
    printf 'vulkan_profile_wrapper=%s\nvulkan_profile_wrapper_sha256=%s\n' \
        "$vulkan_profile_wrapper" "$vulkan_profile_wrapper_sha256"
    printf 'vulkan_profile_wrapper_bytes=%s\n' "$vulkan_profile_wrapper_bytes"
    printf 'vulkan_profile=%s\n' "$vulkan_profile"
    printf 'vulkan_workload_lock=%s\n' "$workload_lock"
    printf 'server_workload_lease=external-harness\n'
    printf 'prompt_source=%s\nprompt_corpus=%s\n' \
        "$prompt_source" "$prompt_file"
    printf 'prompt_corpus_sha256=%s\nprompt_corpus_bytes=%s\n' \
        "$prompt_sha256" "$prompt_bytes"
} >"$output_directory/inputs.txt"

process_starttime() {
    python3 - "$1" <<'PY'
import sys
from pathlib import Path

process_id = int(sys.argv[1])
try:
    stat_fields = Path(f"/proc/{process_id}/stat").read_text(encoding="ascii").rsplit(")", 1)[1].split()
except (IndexError, OSError):
    raise SystemExit(1)
print(stat_fields[19])
PY
}

server_pid=''
server_starttime=''
server_listener_inode=''
clear_server_identity() {
    server_pid=''
    server_starttime=''
    server_listener_inode=''
}

signal_server() {
    python3 - "$server_pid" "$server_starttime" "$1" <<'PY'
import os
import signal
import sys
from pathlib import Path

process_id = int(sys.argv[1])
expected_starttime = sys.argv[2]
signal_number = getattr(signal, f"SIG{sys.argv[3]}")
try:
    process_fd = os.pidfd_open(process_id)
except ProcessLookupError:
    raise SystemExit(1)
try:
    try:
        stat_fields = (
            Path(f"/proc/{process_id}/stat")
            .read_text(encoding="ascii")
            .rsplit(")", 1)[1]
            .split()
        )
    except (IndexError, OSError):
        raise SystemExit(1)
    if stat_fields[19] != expected_starttime:
        raise SystemExit(1)
    try:
        signal.pidfd_send_signal(process_fd, signal_number)
    except ProcessLookupError:
        raise SystemExit(1)
finally:
    os.close(process_fd)
PY
}

stop_server() {
    [ -n "$server_pid" ] || return 0
    if ! signal_server TERM; then
        wait "$server_pid" 2>/dev/null || true
        clear_server_identity
        return 0
    fi
    stop_iteration=0
    while [ "$stop_iteration" -lt 30 ]; do
        # ps failing is not the process being gone: kill -0 from the parent is
        # the existence authority, and an unreadable but live process keeps the
        # loop waiting instead of clearing the identity while the server still
        # holds the port and the carve-out.
        if server_state_line=$(ps -o stat= -p "$server_pid" 2>/dev/null); then
            server_status=$(printf '%s\n' "$server_state_line" |
                awk 'NR == 1 { print $1 }')
        elif kill -0 "$server_pid" 2>/dev/null; then
            server_status=unreadable
        else
            server_status=''
        fi
        case $server_status in
        '' | Z*)
            wait "$server_pid" 2>/dev/null || true
            clear_server_identity
            return 0
            ;;
        esac
        stop_iteration=$((stop_iteration + 1))
        sleep 1
    done
    signal_server KILL || true
    wait "$server_pid" 2>/dev/null || true
    clear_server_identity
}
trap 'stop_server' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Readiness belongs to the launched exec chain only when that exact PID owns
# one stable loopback listener inode. A foreign process or a same-PID rebind
# cannot supply an accepted response between the bracketing observations.
process_loopback_listener_inode() {
    python3 - "$1" "$2" "$3" <<'PY'
import os
import sys
from pathlib import Path

process_id = int(sys.argv[1])
port = int(sys.argv[2])
expected_starttime = sys.argv[3]
socket_inodes = set()
matching_inodes = []
try:
    stat_fields = Path(f"/proc/{process_id}/stat").read_text(encoding="ascii").rsplit(")", 1)[1].split()
    if stat_fields[19] != expected_starttime:
        raise SystemExit(1)
    for descriptor in Path(f"/proc/{process_id}/fd").iterdir():
        try:
            target = os.readlink(descriptor)
        except OSError:
            continue
        if target.startswith("socket:[") and target.endswith("]"):
            socket_inodes.add(target[8:-1])
except OSError:
    raise SystemExit(1)

try:
    lines = Path("/proc/net/tcp").read_text(encoding="ascii").splitlines()[1:]
except OSError:
    raise SystemExit(1)
for line in lines:
    fields = line.split()
    address, port_hex = fields[1].split(":", 1)
    if (
        address == "0100007F"
        and int(port_hex, 16) == port
        and fields[3] == "0A"
        and fields[9] in socket_inodes
    ):
        matching_inodes.append(fields[9])
if len(matching_inodes) != 1:
    raise SystemExit(1)
print(matching_inodes[0])
PY
}

require_server_listener() {
    listener_boundary=$1
    if [ -z "$server_pid" ] || ! kill -0 "$server_pid" 2>/dev/null; then
        printf 'launched llama-server process is absent at %s\n' \
            "$listener_boundary" >&2
        return 1
    fi
    if ! observed_listener_inode=$(process_loopback_listener_inode \
        "$server_pid" "$server_port" "$server_starttime"); then
        printf 'launched llama-server process %s owns no loopback listener at %s\n' \
            "$server_pid" "$listener_boundary" >&2
        return 1
    fi
    if [ -n "$server_listener_inode" ] &&
       [ "$observed_listener_inode" != "$server_listener_inode" ]; then
        printf 'launched llama-server listener inode changed at %s: %s -> %s\n' \
            "$listener_boundary" "$server_listener_inode" \
            "$observed_listener_inode" >&2
        return 1
    fi
    printf '%s\n' "$observed_listener_inode"
}

# Placement is pinned the way qwen-capacity-policy.sh pins it for the serving
# path, on both models. common_base_params_to_speculative overwrites
# result.devices, result.n_gpu_layers, and result.tensor_buft_overrides with the
# draft's values, so the target's Vulkan0 placement reaches the draft only where
# the draft options name it. LLAMA_NO_CPU_FALLBACK reaches the
# llama-no-cpu-fallback patch the promoted build carries, so a fallback fails
# the load rather than serving a control and an arm from two devices.
#
# --metrics registers the Prometheus route the verification step count comes
# from, and it is set on every arm so the control's own zeroed counters are
# readable evidence rather than a 404.
#
# The lease descriptor is closed inside a child shell before the exec chain
# starts, because a parent-side close on the background command empties this
# process's own descriptor table entry for the child's whole runtime.
start_server() {
    arm_mode=$1
    arm_draft_length=$2
    arm_log=$3

    server_listener_inode=''
    if [ "$arm_mode" = control ]; then
        (
            exec 9>&-
            exec env LLAMA_NO_CPU_FALLBACK=1 \
                QWEN_VULKAN_PROFILE="$vulkan_profile" \
                QWEN_VULKAN_WORKLOAD_LOCK= \
                "$priority_wrapper" "$vulkan_profile_wrapper" "$server_program" \
                --model "$target_path" \
                --host 127.0.0.1 --port "$server_port" \
                --ctx-size "$target_context" \
                --batch-size "$target_batch" --ubatch-size "$target_ubatch" \
                --cache-type-k "$target_cache_k" \
                --cache-type-v "$target_cache_v" \
                --flash-attn "$target_flash" \
                --device Vulkan0 --split-mode none \
                --override-tensor '.*=Vulkan0' --fit off --n-gpu-layers all \
                --metrics \
                --parallel 1 --threads "$thread_count" \
                --threads-batch "$thread_count" \
                --no-context-shift --offline --log-verbosity 4
        ) >"$arm_log" 2>&1 &
    elif [ "$mechanism" = draft-mtp ]; then
        (
            exec 9>&-
            exec env LLAMA_NO_CPU_FALLBACK=1 \
                QWEN_VULKAN_PROFILE="$vulkan_profile" \
                QWEN_VULKAN_WORKLOAD_LOCK= \
                "$priority_wrapper" "$vulkan_profile_wrapper" "$server_program" \
                --model "$target_path" \
                --host 127.0.0.1 --port "$server_port" \
                --ctx-size "$target_context" \
                --batch-size "$target_batch" --ubatch-size "$target_ubatch" \
                --cache-type-k "$target_cache_k" \
                --cache-type-v "$target_cache_v" \
                --flash-attn "$target_flash" \
                --device Vulkan0 --split-mode none \
                --override-tensor '.*=Vulkan0' --fit off --n-gpu-layers all \
                --metrics \
                --spec-type draft-mtp \
                --spec-draft-n-max "$arm_draft_length" \
                --spec-draft-p-min "$spec_draft_p_min" \
                --parallel 1 --threads "$thread_count" \
                --threads-batch "$thread_count" \
                --no-context-shift --offline --log-verbosity 4
        ) >"$arm_log" 2>&1 &
    else
        (
            exec 9>&-
            exec env LLAMA_NO_CPU_FALLBACK=1 \
                QWEN_VULKAN_PROFILE="$vulkan_profile" \
                QWEN_VULKAN_WORKLOAD_LOCK= \
                "$priority_wrapper" "$vulkan_profile_wrapper" "$server_program" \
                --model "$target_path" \
                --host 127.0.0.1 --port "$server_port" \
                --ctx-size "$target_context" \
                --batch-size "$target_batch" --ubatch-size "$target_ubatch" \
                --cache-type-k "$target_cache_k" \
                --cache-type-v "$target_cache_v" \
                --flash-attn "$target_flash" \
                --device Vulkan0 --split-mode none \
                --override-tensor '.*=Vulkan0' --fit off --n-gpu-layers all \
                --metrics \
                --spec-type draft-simple \
                --spec-draft-model "$draft_path" \
                --spec-draft-n-max "$arm_draft_length" \
                --spec-draft-p-min "$spec_draft_p_min" \
                --spec-draft-type-k "$draft_cache_type_k" \
                --spec-draft-type-v "$draft_cache_type_v" \
                --spec-draft-device Vulkan0 \
                --spec-draft-ngl all \
                --spec-draft-override-tensor '.*=Vulkan0' \
                --parallel 1 --threads "$thread_count" \
                --threads-batch "$thread_count" \
                --no-context-shift --offline --log-verbosity 4
        ) >"$arm_log" 2>&1 &
    fi
    server_pid=$!
    if ! server_starttime=$(process_starttime "$server_pid"); then
        printf 'llama-server process identity is unreadable after launch: %s\n' \
            "$server_pid" >&2
        return 1
    fi

    ready_iteration=0
    while [ "$ready_iteration" -lt "$readiness_seconds" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'llama-server exited before readiness; see %s\n' "$arm_log" >&2
            return 1
        fi
        if curl --silent --fail --max-time 2 \
            "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
            if server_listener_inode=$(require_server_listener \
                'readiness completion'); then
                return 0
            fi
            return 1
        fi
        ready_iteration=$((ready_iteration + 1))
        sleep 1
    done
    printf 'llama-server did not answer /health within %s seconds\n' \
        "$readiness_seconds" >&2
    return 1
}

# The cumulative Prometheus counters bracket each completion. Their delta is the
# per-request drafted, accepted, and verification-step triple, and the third has
# no per-request surface anywhere else.
capture_metrics() {
    curl --silent --fail --max-time 5 \
        "http://127.0.0.1:$server_port/metrics" >"$1" 2>/dev/null || : >"$1"
}

write_listener_row() {
    printf 'pid\tstarttime\tinode_before\tinode_after\tstate\n' >"$1"
    printf '%s\t%s\t%s\t%s\t%s\n' "$server_pid" "$server_starttime" \
        "$2" "$3" "$4" >>"$1"
}

run_arm() {
    arm_label=$1
    arm_mode=$2
    arm_draft_length=$3
    arm_directory=$output_directory/$arm_label
    mkdir -p "$arm_directory"
    printf 'arm_start label=%s mode=%s n_max=%s\n' \
        "$arm_label" "$arm_mode" "$arm_draft_length"
    start_server "$arm_mode" "$arm_draft_length" "$arm_directory/server.log"
    while IFS='	' read -r prompt_name prompt_text; do
        [ -n "$prompt_name" ] || continue
        python3 - "$prompt_text" "$predict_tokens" "$sampling_seed" \
            >"$arm_directory/$prompt_name.request.json" <<'PY'
import json
import sys

print(json.dumps({
    "prompt": sys.argv[1],
    "n_predict": int(sys.argv[2]),
    "temperature": 0,
    "top_k": 1,
    "seed": int(sys.argv[3]),
    "cache_prompt": False,
    "stream": False,
    "return_tokens": True,
    "ignore_eos": True,
}))
PY
        listener_identity_path=$arm_directory/$prompt_name.listener.tsv
        listener_inode_after=unreadable
        if ! listener_inode_before=$(require_server_listener \
            "before completion request $arm_label/$prompt_name"); then
            write_listener_row "$listener_identity_path" unreadable \
                "$listener_inode_after" rejected
            return 1
        fi
        capture_metrics "$arm_directory/$prompt_name.metrics-before.txt"
        if ! curl --silent --show-error --fail-with-body \
            --max-time "$request_seconds" \
            --header 'Content-Type: application/json' \
            --data-binary @"$arm_directory/$prompt_name.request.json" \
            "http://127.0.0.1:$server_port/completion" \
            >"$arm_directory/$prompt_name.json"; then
            printf 'llama-server completion request failed: %s/%s\n' \
                "$arm_label" "$prompt_name" >&2
            listener_inode_after=$(require_server_listener \
                "after failed completion request $arm_label/$prompt_name" ||
                printf 'unreadable\n')
            write_listener_row "$listener_identity_path" \
                "$listener_inode_before" "$listener_inode_after" rejected
            return 1
        fi
        capture_metrics "$arm_directory/$prompt_name.metrics-after.txt"
        listener_identity_state=rejected
        if listener_inode_after=$(require_server_listener \
            "after completion request $arm_label/$prompt_name"); then
            listener_identity_state=accepted
        fi
        write_listener_row "$listener_identity_path" "$listener_inode_before" \
            "$listener_inode_after" "$listener_identity_state"
        [ "$listener_identity_state" = accepted ] || return 1
    done <"$prompt_file"
    require_server_listener "before post-arm health check $arm_label" >/dev/null
    if ! curl --silent --fail --max-time 2 \
        "http://127.0.0.1:$server_port/health" >/dev/null 2>&1; then
        printf 'llama-server failed its post-arm health check: %s\n' \
            "$arm_label" >&2
        return 1
    fi
    require_server_listener "after post-arm health check $arm_label" >/dev/null
    stop_server
    printf 'arm_done label=%s\n' "$arm_label"
}

for draft_length in $draft_length_list; do
    run_arm "n$draft_length-control-open" control "$draft_length"
    run_arm "n$draft_length-spec-first" spec "$draft_length"
    run_arm "n$draft_length-spec-second" spec "$draft_length"
    run_arm "n$draft_length-control-close" control "$draft_length"
done

capture_file_sha256() {
    if [ -f "$1" ]; then
        file_sha256 "$1"
    else
        printf 'absent\n'
    fi
}
capture_file_bytes() {
    if [ -f "$1" ]; then
        file_bytes "$1"
    else
        printf 'absent\n'
    fi
}
identity_failures=0
source_revision_after=unreadable
source_revision_state=rejected
if source_revision_after=$(git -C "$source_root" rev-parse --verify HEAD 2>/dev/null) &&
   [ "$source_revision" = "$source_revision_after" ]; then
    source_revision_state=accepted
else
    identity_failures=$((identity_failures + 1))
fi
{
    printf 'source_root\trevision_before\trevision_after\tstate\n'
    printf '%s\t%s\t%s\t%s\n' "$source_root" "$source_revision" \
        "$source_revision_after" "$source_revision_state"
} >"$output_directory/source-revision-check.tsv"

record_identity() {
    identity_label=$1
    identity_path=$2
    identity_sha256_before=$3
    identity_bytes_before=$4
    identity_sha256_after=$(capture_file_sha256 "$identity_path")
    identity_bytes_after=$(capture_file_bytes "$identity_path")
    identity_state=accepted
    if [ "$identity_sha256_before" != "$identity_sha256_after" ] ||
       [ "$identity_bytes_before" != "$identity_bytes_after" ]; then
        identity_state=rejected
        identity_failures=$((identity_failures + 1))
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$identity_label" "$identity_path" "$identity_sha256_before" \
        "$identity_bytes_before" "$identity_sha256_after" \
        "$identity_bytes_after" "$identity_state"
}
{
    printf 'artifact\tpath\tsha256_before\tbytes_before\tsha256_after\tbytes_after\tstate\n'
    record_identity measurement-runner-source "$measurement_runner_source" \
        "$measurement_runner_sha256" "$measurement_runner_bytes"
    record_identity summarizer-source "$summarizer_source" \
        "$summarizer_sha256" "$summarizer_bytes"
    record_identity summarizer-retained "$summarizer_retained" \
        "$summarizer_retained_sha256" "$summarizer_retained_bytes"
    record_identity prompt-corpus "$prompt_file" "$prompt_sha256" "$prompt_bytes"
    record_identity target-model "$target_path" \
        "$target_model_sha256" "$target_model_bytes"
    if [ "$mechanism" = draft-simple ]; then
        record_identity draft-model "$draft_path" \
            "$draft_model_sha256" "$draft_model_bytes"
    fi
    record_identity server "$server_program" "$server_sha256" "$server_bytes"
    record_identity priority-wrapper "$priority_wrapper" \
        "$priority_wrapper_sha256" "$priority_wrapper_bytes"
    record_identity vulkan-profile-wrapper "$vulkan_profile_wrapper" \
        "$vulkan_profile_wrapper_sha256" "$vulkan_profile_wrapper_bytes"
} >"$output_directory/identity-check.tsv"
if [ "$identity_failures" -ne 0 ]; then
    printf 'temporal-amortization artifact identity changed during measurement\n' >&2
    cat "$output_directory/source-revision-check.tsv" \
        "$output_directory/identity-check.tsv" >&2
    exit 1
fi

# The launcher reads the retained source once, verifies those exact bytes, and
# executes the verified in-memory program. A pathname replacement or in-place
# write between the earlier identity table and this read becomes a terminal
# execution check instead of changing the arithmetic after verification.
python3 - "$summarizer_retained" "$summarizer_retained_sha256" \
    "$summarizer_retained_bytes" \
    "$output_directory/summarizer-execution-check.tsv" \
    "$output_directory" "--target-rate" "$target_rate" <<'PY'
import hashlib
import sys
from pathlib import Path

summarizer_path = Path(sys.argv[1])
expected_sha256 = sys.argv[2]
expected_bytes = int(sys.argv[3])
execution_check_path = Path(sys.argv[4])
summarizer_bytes = summarizer_path.read_bytes()
observed_sha256 = hashlib.sha256(summarizer_bytes).hexdigest()
observed_bytes = len(summarizer_bytes)
execution_state = (
    "accepted"
    if observed_sha256 == expected_sha256 and observed_bytes == expected_bytes
    else "rejected"
)
execution_check_path.write_text(
    "path\texpected_sha256\texpected_bytes\tobserved_sha256\tobserved_bytes\tstate\n"
    f"{summarizer_path}\t{expected_sha256}\t{expected_bytes}\t"
    f"{observed_sha256}\t{observed_bytes}\t{execution_state}\n",
    encoding="utf-8",
)
if execution_state != "accepted":
    print("retained break-even summarizer identity changed before execution", file=sys.stderr)
    raise SystemExit(1)

sys.argv = [str(summarizer_path), *sys.argv[5:]]
exec(
    compile(summarizer_bytes, str(summarizer_path), "exec"),
    {"__name__": "__main__", "__file__": str(summarizer_path)},
)
PY

printf 'temporal_amortization_measurement=completed mechanism=%s subject=%s output_directory=%s\n' \
    "$mechanism" "$subject" "$output_directory"
