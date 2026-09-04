#!/bin/sh
set -eu

# Run one immutable, balanced served-decode denominator for the three active
# throughput targets. Two forward blocks followed by two reverse blocks give
# every model four slots with mean ordinal position 6.5 while limiting a
# same-model block-boundary adjacency to one. A failed run stays retained under
# its claimed path and a later invocation must use a new path: resuming after a
# machine-state discontinuity would no longer measure one balanced window.

if [ "$#" -ne 1 ]; then
    printf 'usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

output_directory=$1
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
runner_source=${QWEN_SERVED_CAMPAIGN_RUNNER:-$script_directory/measure-served-decode.sh}
summarizer_source=${QWEN_SERVED_CAMPAIGN_SUMMARIZER:-$script_directory/summarize-fixed64-served-campaign.py}
registry_reader_source=${QWEN_MODEL_REGISTRY_SCRIPT:-$script_directory/model-registry.sh}
model_registry_source=${QWEN_MODEL_REGISTRY:-$script_directory/models.tsv}
artifact_reader_source=${QWEN_MODEL_ARTIFACT_SCRIPT:-$script_directory/model-artifact-identity.sh}
artifact_ledger_source=${QWEN_MODEL_ARTIFACTS:-$script_directory/model-artifacts.tsv}
target_ledger_source=${QWEN_THROUGHPUT_TARGETS:-$script_directory/throughput-targets.tsv}
quarantine_source=${QWEN_QUARANTINE_REGISTRY:-$script_directory/quarantine.tsv}
validated_tuples_source=${QWEN_VALIDATED_TUPLES:-$script_directory/validated-tuples.tsv}
ctx_checkpoints_source=${QWEN_CTX_CHECKPOINT_LEDGER:-$script_directory/ctx-checkpoints.tsv}
launch_source=${QWEN_SERVED_CAMPAIGN_LAUNCH_SCRIPT:-$script_directory/qwen-launch.sh}
teardown_source=${QWEN_SERVED_CAMPAIGN_TEARDOWN_SCRIPT:-$script_directory/qwen-teardown.sh}
signal_process_group_source=${QWEN_SERVED_CAMPAIGN_SIGNAL_PROCESS_GROUP:-$script_directory/signal-process-group.py}
campaign_lock_descriptor_helper=$script_directory/open-verified-lock-descriptor.py
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
state_directory=${QWEN_SERVED_CAMPAIGN_STATE_DIRECTORY:-"$qwen_home_state"}
cooldown_seconds=${QWEN_SERVED_CAMPAIGN_COOLDOWN_S:-30}
radv_icd=${QWEN_SERVED_CAMPAIGN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
expected_workload_lock=$state_directory/vulkan-workload.lock
workload_lock=${QWEN_VULKAN_WORKLOAD_LOCK:-$expected_workload_lock}
expected_campaign_lock=$state_directory/fixed64-served-campaign.lock
campaign_lock=${QWEN_SERVED_CAMPAIGN_CONTROL_LOCK:-$expected_campaign_lock}
campaign_server_port=8080
require_clean_source=${QWEN_SERVED_CAMPAIGN_REQUIRE_CLEAN_SOURCE:-1}
orchestrator_source=$(readlink -f -- "$0")
lease_inherited=${QWEN_SERVED_CAMPAIGN_LEASE_INHERITED:-0}
campaign_lock_inherited=${QWEN_FIXED64_CONTROL_LOCK_INHERITED:-0}
campaign_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
default_runner_source=$script_directory/measure-served-decode.sh
if [ "$runner_source" = "$default_runner_source" ]; then
    runner_mode=retained-git
    latency_probe_mode=bound
else
    runner_mode=explicit
    latency_probe_mode=not-applicable
fi

# The fixed-64 denominator belongs to an inherited SSH execution surface on
# hp14-dk1xxx. Scheduler policy differs on local and Edge surfaces, so a
# campaign must prove its host and transport markers before claiming an evidence
# directory. The markers identify the execution surface; the SSH client and
# host-key policy remain the authentication authority outside this process.
# Test fixtures may replace the hostname observation only when the caller also
# selects an explicit non-production runner and disables the clean-source gate.
hostname_observation=${QWEN_TEST_FIXED64_HOST_SHORTNAME:-}
if [ -n "$hostname_observation" ]; then
    if [ "$runner_mode" != explicit ] || [ "$require_clean_source" != 0 ]; then
        printf 'fixed-64 hostname fixture requires an explicit non-production runner\n' \
            >&2
        exit 2
    fi
else
    hostname_observation=$(hostname -s 2>/dev/null || true)
fi
host_shortname=$(printf '%s' "$hostname_observation" | \
    LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
case $host_shortname in
    '' | -* | *- | *[!a-z0-9-]*)
        printf 'fixed-64 campaign host shortname is malformed\n' >&2
        exit 2
        ;;
esac
if [ "${#host_shortname}" -gt 63 ] || [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'fixed-64 campaign requires measured host hp14-dk1xxx: observed=%s\n' \
        "$host_shortname" >&2
    exit 2
fi
if ! python3 - "${SSH_CONNECTION:-}" <<'PY'
import ipaddress
import sys

fields = sys.argv[1].split()
if len(fields) != 4:
    raise SystemExit(1)
for address in (fields[0], fields[2]):
    try:
        ipaddress.ip_address(address)
    except ValueError:
        raise SystemExit(1) from None
for port in (fields[1], fields[3]):
    if not port.isascii() or not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise SystemExit(1)
PY
then
    printf 'fixed-64 campaign requires a structurally valid inherited SSH session\n' \
        >&2
    exit 2
fi
execution_surface=hp14-ssh
ssh_session=present

case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac
output_parent=$(dirname -- "$output_directory")
output_basename=$(basename -- "$output_directory")
canonical_output_parent=$(readlink -f -- "$output_parent" 2>/dev/null || true)
canonical_output_directory=$canonical_output_parent/$output_basename
if [ -z "$canonical_output_parent" ] || \
   [ "$output_directory" != "$canonical_output_directory" ]; then
    printf 'output directory must use one canonical absolute spelling: %s\n' \
        "$output_directory" >&2
    exit 2
fi
case $cooldown_seconds in
    '' | *[!0-9]*)
        printf 'campaign cooldown must be a non-negative integer: %s\n' \
            "$cooldown_seconds" >&2
        exit 2
        ;;
esac
if [ -z "$workload_lock" ] || [ "${workload_lock#/}" = "$workload_lock" ]; then
    printf 'QWEN_VULKAN_WORKLOAD_LOCK must name an absolute shared lease\n' >&2
    exit 2
fi
if [ "$workload_lock" != "$expected_workload_lock" ]; then
    printf 'Vulkan workload lease differs from the server-owned path: %s != %s\n' \
        "$workload_lock" "$expected_workload_lock" >&2
    exit 2
fi
case $lease_inherited in
    0 | 1) ;;
    *)
        printf 'campaign lease inheritance marker must be 0 or 1: %s\n' \
            "$lease_inherited" >&2
        exit 2
        ;;
esac
case $campaign_lock_inherited in
    0 | 1) ;;
    *)
        printf 'campaign lock inheritance marker must be 0 or 1: %s\n' \
            "$campaign_lock_inherited" >&2
        exit 2
        ;;
esac
if [ "$campaign_lock" != "$expected_campaign_lock" ]; then
    printf 'campaign control lease differs from the session-owned path: %s != %s\n' \
        "$campaign_lock" "$expected_campaign_lock" >&2
    exit 2
fi
case $require_clean_source in
    0 | 1) ;;
    *)
        printf 'clean-source policy must be 0 or 1: %s\n' \
            "$require_clean_source" >&2
        exit 2
        ;;
esac
umask 077
tab=$(printf '\t')
for required_command in awk chmod cmp cp env find flock git hostname mkdir mv \
    python3 readlink rm sha256sum sleep sort stat tar tr xargs; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'required campaign command is absent: %s\n' "$required_command" >&2
        exit 2
    fi
done
canonical_models_directory=$(readlink -f -- "$models_directory" 2>/dev/null || true)
if [ -z "$canonical_models_directory" ] || \
   [ ! -d "$canonical_models_directory" ]; then
    printf 'campaign models directory is absent: %s\n' "$models_directory" >&2
    exit 2
fi
models_directory=$canonical_models_directory
for executable_source in "$runner_source" "$registry_reader_source" \
    "$artifact_reader_source" \
    "$launch_source" "$teardown_source" "$signal_process_group_source" \
    "$campaign_lock_descriptor_helper"; do
    if [ ! -x "$executable_source" ]; then
        printf 'campaign executable is absent: %s\n' "$executable_source" >&2
        exit 2
    fi
done
if ! "$signal_process_group_source" --check >/dev/null; then
    printf 'campaign host lacks identity-bound process-group signaling\n' >&2
    exit 2
fi
if [ ! -f "$summarizer_source" ]; then
    printf 'campaign summarizer is absent: %s\n' "$summarizer_source" >&2
    exit 2
fi
for configuration_source in "$model_registry_source" "$artifact_ledger_source" \
    "$target_ledger_source" \
    "$quarantine_source" "$validated_tuples_source" "$ctx_checkpoints_source"; do
    if [ ! -f "$configuration_source" ] || [ -L "$configuration_source" ]; then
        printf 'campaign configuration is absent or linked: %s\n' \
            "$configuration_source" >&2
        exit 2
    fi
done
case $radv_icd in
    /*) ;;
    *)
        printf 'campaign RADV ICD path must be absolute: %s\n' "$radv_icd" >&2
        exit 2
        ;;
esac
if [ ! -f "$radv_icd" ] || [ -L "$radv_icd" ] || [ ! -r "$radv_icd" ]; then
    printf 'campaign RADV ICD is absent, linked, or unreadable: %s\n' \
        "$radv_icd" >&2
    exit 2
fi

# The state directory owns both lease namespaces. Every existing component must
# be a real directory; the final component may be absent and this check creates
# it only after validating its canonical parent chain.
if ! python3 - "$state_directory" <<'PY'
import os
import sys
from pathlib import Path

candidate_text = sys.argv[1]
candidate = Path(candidate_text)
if not candidate.is_absolute() or os.path.normpath(candidate_text) != candidate_text:
    raise SystemExit(f"state directory must use one canonical absolute spelling: {candidate}")
if candidate.name in {"", ".", ".."}:
    raise SystemExit(f"state directory basename is invalid: {candidate}")

current = Path(candidate.anchor)
for index, part in enumerate(candidate.parts[1:], start=1):
    current /= part
    if current.is_symlink():
        raise SystemExit(f"state directory contains a symbolic link: {current}")
    is_final_component = index == len(candidate.parts) - 1
    if is_final_component and not current.exists():
        if not current.parent.is_dir():
            raise SystemExit(f"state directory parent is absent: {current.parent}")
        current.mkdir(mode=0o700)
    if not current.is_dir():
        raise SystemExit(f"state directory component is not a directory: {current}")
PY
then
    exit 2
fi
chmod 0700 -- "$state_directory"

# A Python exec wrapper takes the host-wide Vulkan lease on descriptor 8 and
# then replaces itself with this script. Each detached arm runner inherits the
# locked open file description on descriptor 8, which keeps the workload
# serialized if the outer holder dies abruptly. The runner publishes a carrier
# proof for its own PID and descriptor before it closes descriptor 8 for launch
# and teardown children. The tmux server therefore receives a proof path but no
# lease descriptor, and /proc/PID/fdinfo keeps the live runner proof verifiable
# after the historical FLOCK acquirer exits.
if [ "$lease_inherited" -eq 0 ]; then
    exec python3 - "$workload_lock" "$orchestrator_source" \
        "$output_directory" <<'PY'
import errno
import fcntl
import os
import sys

lock_path, script_path, output_directory = sys.argv[1:]
descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
try:
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError as error:
    if error.errno in (errno.EACCES, errno.EAGAIN):
        print(
            f"another Vulkan workload holds the shared lease: {lock_path}",
            file=sys.stderr,
        )
        raise SystemExit(2) from None
    raise
if descriptor != 8:
    os.dup2(descriptor, 8, inheritable=True)
    os.close(descriptor)
else:
    os.set_inheritable(8, True)
environment = os.environ.copy()
environment["QWEN_SERVED_CAMPAIGN_LEASE_INHERITED"] = "1"
os.execve(script_path, [script_path, output_directory], environment)
PY
fi
inherited_lease=$(readlink -f -- "/proc/$$/fd/8" 2>/dev/null || true)
if [ "$inherited_lease" != "$workload_lock" ]; then
    printf 'inherited Vulkan workload lease names another file: %s != %s\n' \
        "$inherited_lease" "$workload_lock" >&2
    exit 2
fi
set +e
flock -n -E 75 "$workload_lock" true
lease_probe_status=$?
set -e
if [ "$lease_probe_status" -ne 75 ]; then
    printf 'inherited Vulkan workload lease is not exclusive: status=%s path=%s\n' \
        "$lease_probe_status" "$workload_lock" >&2
    exit 2
fi

if [ "$campaign_lock_inherited" -eq 0 ]; then
    QWEN_FIXED64_CONTROL_LOCK_INHERITED=1
    export QWEN_FIXED64_CONTROL_LOCK_INHERITED
    exec "$campaign_lock_descriptor_helper" open --normalize-legacy-mode \
        "$campaign_lock" 9 \
        "$orchestrator_source" "$output_directory"
fi
if ! "$campaign_lock_descriptor_helper" verify "$campaign_lock" 9; then
    exit 2
fi
if ! flock -n 9; then
    printf 'another fixed-64 served campaign holds the control lease: %s\n' \
        "$campaign_lock" >&2
    exit 2
fi
unset QWEN_FIXED64_CONTROL_LOCK_INHERITED

# A SIGKILL prevents the prior holder from unlinking its private proof. The
# exclusive kernel lease establishes that no cooperative workload can still
# use any older proof in this private state directory. Remove only regular,
# same-UID proof files before publishing the proof for the new holder.
campaign_effective_uid=$(id -u)
for stale_lease_proof in \
        "$state_directory"/.fixed64-vulkan-external-lease.*.tsv; do
    if [ ! -e "$stale_lease_proof" ] && [ ! -L "$stale_lease_proof" ]; then
        continue
    fi
    stale_lease_proof_uid=$(stat -c %u "$stale_lease_proof" 2>/dev/null || true)
    if [ ! -f "$stale_lease_proof" ] || [ -L "$stale_lease_proof" ] || \
       [ "$stale_lease_proof_uid" != "$campaign_effective_uid" ]; then
        printf 'stale external lease proof is not a same-UID regular file: %s\n' \
            "$stale_lease_proof" >&2
        exit 2
    fi
    rm -f -- "$stale_lease_proof"
    printf 'fixed64_campaign=removed-stale-lease-proof path=%s\n' \
        "$stale_lease_proof"
done

# Reject a linked path component and claim one absent directory with one mkdir.
# The check and mkdir remain adjacent; mkdir is the final race arbiter.
if ! python3 - "$output_directory" <<'PY'
import os
import sys
from pathlib import Path

candidate = Path(sys.argv[1])
if os.path.lexists(candidate):
    raise SystemExit(f"output path must be absent for one immutable campaign: {candidate}")
parent = candidate.parent
if not parent.is_dir():
    raise SystemExit(f"output parent directory is absent: {parent}")
current = Path(candidate.anchor)
for part in parent.parts[1:]:
    current /= part
    if current.is_symlink():
        raise SystemExit(f"output parent contains a symbolic link: {current}")
if candidate.name in {"", ".", ".."}:
    raise SystemExit(f"output directory basename is invalid: {candidate}")
PY
then
    exit 2
fi

if [ -e "$output_directory" ] || [ -L "$output_directory" ]; then
    printf 'output path must be absent for one immutable campaign: %s\n' \
        "$output_directory" >&2
    exit 2
fi
if ! mkdir -- "$output_directory"; then
    printf 'cannot claim campaign output directory: %s\n' "$output_directory" >&2
    exit 2
fi

lease_proof=$state_directory/.fixed64-vulkan-external-lease.$$.tsv
holder_start_time=$(sed 's/^.*) //' "/proc/$$/stat" | awk '{ print $20 }')
printf 'key\tvalue\n' >"$lease_proof"
printf 'schema\tfixed64-vulkan-external-lease-v1\n' >>"$lease_proof"
printf 'lock_path\t%s\n' "$workload_lock" >>"$lease_proof"
printf 'holder_pid\t%s\n' "$$" >>"$lease_proof"
printf 'holder_start_time_ticks\t%s\n' "$holder_start_time" >>"$lease_proof"
printf 'holder_fd\t8\n' >>"$lease_proof"
printf 'source_revision\t%s\n' \
    "$(git -C "$repository_root" rev-parse HEAD)" >>"$lease_proof"
chmod 0600 "$lease_proof"
"$script_directory/verify-external-vulkan-lease.py" "$lease_proof" \
    "$workload_lock" >"$output_directory/external-lease-verification.txt"
cp -- "$lease_proof" "$output_directory/external-vulkan-lease.tsv"

# Every failure after the atomic claim leaves an explicit terminal row. A
# target-unmet campaign exits one after sealing SHA256SUMS, so manifest presence
# prevents the trap from replacing its validated pre-seal state.
failure_terminal_state=$output_directory/terminal-state.tsv
active_child_pid=''
active_child_start_time=''
active_arm_directory=''
completed_arms=0
cleanup_campaign_state() {
    if [ -n "${lease_proof:-}" ]; then
        rm -f -- "$lease_proof"
        lease_proof=''
    fi
}
record_unclassified_failure() {
    failure_status=$?
    trap - EXIT HUP INT TERM
    cleanup_campaign_state
    if [ "$failure_status" -ne 0 ] && \
       [ ! -e "$output_directory/SHA256SUMS" ]; then
        recorded_failure_state=absent
        if [ -r "$failure_terminal_state" ]; then
            recorded_failure_state=$(awk -F '\t' 'NR == 2 { print $1 }' \
                "$failure_terminal_state")
        fi
        if [ "$recorded_failure_state" != failed ] && \
           [ "$recorded_failure_state" != interrupted ]; then
            retained_completed_arms=0
            if [ -r "$output_directory/arm-status.tsv" ]; then
                retained_completed_arms=$(awk -F '\t' \
                    'NR > 1 && $4 == "completed" { count++ } END { print count + 0 }' \
                    "$output_directory/arm-status.tsv")
            fi
            failure_terminal_new=$output_directory/.terminal-state.tsv.new
            printf 'state\texpected_arms\tcompleted_arms\tfailed_arms\ttarget_state\tfailure_scope\n' \
                >"$failure_terminal_new"
            printf 'failed\t12\t%s\t0\tpending\tunclassified\n' \
                "$retained_completed_arms" >>"$failure_terminal_new"
            mv -- "$failure_terminal_new" "$failure_terminal_state"
        fi
    fi
    exit "$failure_status"
}
handle_signal() {
    received_signal=$1
    signal_status=$2
    trap - EXIT HUP INT TERM
    interrupted_arm=0
    signal_runner_status=0
    signal_recovery_status=0
    signal_dispatch_status=0
    if [ -n "$active_child_pid" ]; then
        interrupted_arm=1
        interrupted_child_pid=$active_child_pid
        interrupted_child_start_time=$active_child_start_time
        signal_dispatch_path=$output_directory/.signal-dispatch.txt
        if "$retained_signal_process_group" "$active_child_pid" \
            "$active_child_start_time" "$received_signal" \
            >"$signal_dispatch_path" 2>&1; then
            signal_dispatch_status=0
        else
            signal_dispatch_status=$?
        fi
        set +e
        wait "$active_child_pid" 2>/dev/null
        signal_runner_status=$?
        active_child_pid=''
        active_child_start_time=''
        if [ -n "$active_arm_directory" ] && [ -d "$active_arm_directory" ]; then
            [ ! -e "$active_arm_directory/campaign-runner.stdout" ] || \
                rm -f -- "$output_directory/.arm.stdout"
            [ ! -e "$active_arm_directory/campaign-runner.stderr" ] || \
                rm -f -- "$output_directory/.arm.stderr"
            if [ -e "$output_directory/.arm.stdout" ]; then
                mv -- "$output_directory/.arm.stdout" \
                    "$active_arm_directory/campaign-runner.stdout"
            fi
            if [ -e "$output_directory/.arm.stderr" ]; then
                mv -- "$output_directory/.arm.stderr" \
                    "$active_arm_directory/campaign-runner.stderr"
            fi
            if [ -e "$signal_dispatch_path" ]; then
                mv -- "$signal_dispatch_path" \
                    "$active_arm_directory/signal-dispatch.txt"
            fi
        fi
        if [ "$signal_runner_status" -ne 0 ]; then
            trap '' HUP INT TERM
            if ! emergency_teardown_failed_arm "$((completed_arms + 1))" \
                "$active_arm_directory" "$interrupted_child_pid" \
                "$interrupted_child_start_time" "$signal_runner_status"; then
                signal_recovery_status=1
            fi
        fi
    fi
    signal_failure_scope=signal-$received_signal
    if [ "$signal_recovery_status" -ne 0 ]; then
        signal_failure_scope=signal-$received_signal-lease-invariant
    elif [ "$signal_dispatch_status" -ne 0 ]; then
        signal_failure_scope=signal-$received_signal-pidfd-refused
    fi
    interrupted_terminal_new=$output_directory/.terminal-state.tsv.new
    printf 'state\texpected_arms\tcompleted_arms\tfailed_arms\ttarget_state\tfailure_scope\n' \
        >"$interrupted_terminal_new"
    printf 'interrupted\t12\t%s\t%s\tpending\t%s\n' \
        "$completed_arms" "$interrupted_arm" "$signal_failure_scope" \
        >>"$interrupted_terminal_new"
    mv -- "$interrupted_terminal_new" "$failure_terminal_state"
    cleanup_campaign_state
    exit "$signal_status"
}
trap record_unclassified_failure EXIT
trap 'handle_signal HUP 129' HUP
trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM

configuration_directory=$output_directory/configuration
mkdir -- "$configuration_directory"
cp -- "$model_registry_source" "$configuration_directory/models.tsv"
cp -- "$artifact_ledger_source" "$configuration_directory/model-artifacts.tsv"
cp -- "$target_ledger_source" "$configuration_directory/throughput-targets.tsv"
cp -- "$quarantine_source" "$configuration_directory/quarantine.tsv"
cp -- "$validated_tuples_source" "$configuration_directory/validated-tuples.tsv"
cp -- "$ctx_checkpoints_source" "$configuration_directory/ctx-checkpoints.tsv"
cp -- "$registry_reader_source" "$configuration_directory/model-registry.sh"
cp -- "$artifact_reader_source" "$configuration_directory/model-artifact-identity.sh"
cp -- "$runner_source" "$configuration_directory/measure-served-decode.sh"
cp -- "$summarizer_source" "$configuration_directory/summarize-fixed64-served-campaign.py"
cp -- "$launch_source" "$configuration_directory/qwen-launch.sh"
cp -- "$teardown_source" "$configuration_directory/qwen-teardown.sh"
cp -- "$signal_process_group_source" \
    "$configuration_directory/signal-process-group.py"
chmod 0700 "$configuration_directory/model-registry.sh" \
    "$configuration_directory/model-artifact-identity.sh" \
    "$configuration_directory/measure-served-decode.sh" \
    "$configuration_directory/summarize-fixed64-served-campaign.py" \
    "$configuration_directory/signal-process-group.py"

registry_reader=$configuration_directory/model-registry.sh
artifact_reader=$configuration_directory/model-artifact-identity.sh
retained_registry=$configuration_directory/models.tsv
retained_artifacts=$configuration_directory/model-artifacts.tsv
retained_targets=$configuration_directory/throughput-targets.tsv
retained_quarantine=$configuration_directory/quarantine.tsv
retained_tuples=$configuration_directory/validated-tuples.tsv
retained_checkpoints=$configuration_directory/ctx-checkpoints.tsv
retained_runner=$configuration_directory/measure-served-decode.sh
retained_summarizer=$configuration_directory/summarize-fixed64-served-campaign.py
retained_signal_process_group=$configuration_directory/signal-process-group.py

server_logical=${QWEN_SERVED_CAMPAIGN_SERVER:-${QWEN_LLAMA_SERVER:-}}
if [ -z "$server_logical" ]; then
    llama_source_directory=${QWEN_LLAMA_SOURCE_DIRECTORY:-"$qwen_home_llama_source"}
    server_logical=$llama_source_directory/build-appliance-current/bin/llama-server
    if [ ! -x "$server_logical" ]; then
        server_logical=$llama_source_directory/build-qwen-vulkan/bin/llama-server
    fi
fi
if [ ! -x "$server_logical" ]; then
    printf 'campaign server is absent: %s\n' "$server_logical" >&2
    exit 2
fi
server_path=$(readlink -f -- "$server_logical")
if [ ! -x "$server_path" ]; then
    printf 'resolved campaign server is absent: %s\n' "$server_path" >&2
    exit 2
fi

source_revision=$(git -C "$repository_root" rev-parse HEAD)
source_remote=$(git -C "$repository_root" remote get-url origin 2>/dev/null || printf '%s' absent)
source_tracked_state=clean
if ! git -C "$repository_root" diff --quiet -- || \
   ! git -C "$repository_root" diff --cached --quiet --; then
    source_tracked_state=modified
fi
if [ "$require_clean_source" -eq 1 ] && [ "$source_tracked_state" != clean ]; then
    printf 'campaign source carries tracked modifications: %s\n' \
        "$repository_root" >&2
    exit 2
fi
if [ "$require_clean_source" -eq 0 ] && \
   [ "$runner_source" = "$script_directory/measure-served-decode.sh" ]; then
    printf 'an unclean-source campaign requires an explicit non-production runner\n' \
        >&2
    exit 2
fi

# The extracted Git archive is both retained evidence and the execution root for
# the production launch closure. This removes the time-of-check/time-of-use gap
# between hashing qwen-launch.sh and executing its mutable sibling helpers.
runtime_root=$configuration_directory/runtime-source
runtime_archive=$configuration_directory/runtime-source.tar
mkdir -- "$runtime_root"
git -C "$repository_root" archive --format=tar \
    --output="$runtime_archive" "$source_revision" remote webui
tar -xf "$runtime_archive" -C "$runtime_root"
git -C "$repository_root" ls-tree -r "$source_revision" -- remote webui \
    >"$configuration_directory/runtime-source-tree.tsv"

default_launch_source=$script_directory/qwen-launch.sh
default_teardown_source=$script_directory/qwen-teardown.sh
if [ "$runner_source" = "$default_runner_source" ]; then
    retained_runner=$runtime_root/remote/measure-served-decode.sh
fi
if [ "$launch_source" = "$default_launch_source" ]; then
    retained_launch=$runtime_root/remote/qwen-launch.sh
else
    retained_launch=$configuration_directory/qwen-launch.sh
fi
if [ "$teardown_source" = "$default_teardown_source" ]; then
    retained_teardown=$runtime_root/remote/qwen-teardown.sh
else
    retained_teardown=$configuration_directory/qwen-teardown.sh
fi
latency_probe_source=${QWEN_SERVED_CAMPAIGN_LATENCY_PROBE:-$repository_root/build/vulkan-graphics-service-probe}
if [ "$runner_source" = "$default_runner_source" ]; then
    if [ ! -x "$latency_probe_source" ]; then
        printf 'campaign latency probe is absent: %s\n' "$latency_probe_source" >&2
        exit 2
    fi
    mkdir -- "$runtime_root/build"
    cp -- "$latency_probe_source" \
        "$runtime_root/build/vulkan-graphics-service-probe"
    chmod 0700 "$runtime_root/build/vulkan-graphics-service-probe"
    retained_latency_probe=$runtime_root/build/vulkan-graphics-service-probe
else
    retained_latency_probe=/bin/true
fi

git -C "$repository_root" ls-files -s >"$output_directory/source-index-before.tsv"
git -C "$repository_root" status --porcelain=v1 --untracked-files=no \
    >"$output_directory/source-status-before.txt"
git -C "$repository_root" rev-parse HEAD >"$output_directory/source-head-before.txt"

file_identity() {
    identity_path=$1
    identity_bytes=$(stat -c %s "$identity_path")
    identity_sha256=$(sha256sum "$identity_path")
    identity_sha256=${identity_sha256%% *}
    printf '%s\t%s\n' "$identity_bytes" "$identity_sha256"
}

identity_before=$output_directory/identity-before.tsv
printf 'subject\tpath\tbytes\tsha256\n' >"$identity_before"
record_before() {
    before_subject=$1
    before_path=$2
    before_identity=$(file_identity "$before_path")
    printf '%s\t%s\t%s\n' "$before_subject" "$before_path" \
        "$before_identity" >>"$identity_before"
}
record_before orchestrator "$orchestrator_source"
record_before child_runner "$runner_source"
record_before summarizer "$summarizer_source"
record_before registry_reader "$registry_reader_source"
record_before artifact_reader "$artifact_reader_source"
record_before signal_process_group "$signal_process_group_source"
record_before model_registry "$model_registry_source"
record_before artifact_ledger "$artifact_ledger_source"
record_before target_ledger "$target_ledger_source"
record_before quarantine_registry "$quarantine_source"
record_before validated_tuples "$validated_tuples_source"
record_before ctx_checkpoints "$ctx_checkpoints_source"
record_before launch_script "$launch_source"
record_before teardown_script "$teardown_source"
record_before server "$server_path"
record_before radv_icd "$radv_icd"
if [ "$runner_source" = "$default_runner_source" ]; then
    record_before latency_probe "$latency_probe_source"
fi

canonical_request=$output_directory/request.json
printf '%s' '{"model":"qwen-apu","messages":[{"role":"user","content":"Write one paragraph about tides."}],"max_tokens":64,"temperature":0,"top_k":1,"seed":1,"ignore_eos":true,"chat_template_kwargs":{"enable_thinking":false}}' \
    >"$canonical_request"

models_resolved=$output_directory/models-resolved.tsv
printf 'model_id\trole\tmodel_file\tmodel_path\tcontext\tbatch\tubatch\tcache_k\tcache_v\tflash_attention\tctx_checkpoints\tcheckpoint_min_step\ttarget_tok_s\tpublisher_bytes\tpublisher_sha256\tsource_repository\tsource_revision\tmodel_bytes\tmodel_sha256\n' \
    >"$models_resolved"

resolve_model() {
    resolved_id=$1
    expected_role=$2
    expected_target=$3
    expected_context=$4
    expected_batch=$5
    expected_ubatch=$6
    expected_cache_k=$7
    expected_cache_v=$8
    expected_flash=$9
    QWEN_MODEL_REGISTRY=$retained_registry \
    QWEN_QUARANTINE_REGISTRY=$retained_quarantine \
    QWEN_VALIDATED_TUPLES=$retained_tuples \
    QWEN_CTX_CHECKPOINT_LEDGER=$retained_checkpoints \
        "$registry_reader" id "$resolved_id" >/dev/null
    resolved_role=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" role)
    resolved_file=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" model_file)
    resolved_context=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" context_default)
    resolved_batch=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" batch)
    resolved_ubatch=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" ubatch)
    resolved_cache_k=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" cache_type_k)
    resolved_cache_v=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" cache_type_v)
    resolved_flash=$(QWEN_MODEL_REGISTRY=$retained_registry \
        "$registry_reader" id "$resolved_id" flash_attention)
    resolved_checkpoints=$(QWEN_MODEL_REGISTRY=$retained_registry \
        QWEN_CTX_CHECKPOINT_LEDGER=$retained_checkpoints \
        "$registry_reader" ctx-checkpoint "$resolved_id")
    resolved_checkpoint_min_step=8192
    artifact_row=$(QWEN_MODEL_ARTIFACTS=$retained_artifacts \
        "$artifact_reader" "$resolved_id")
    IFS="$tab" read -r artifact_id artifact_file publisher_bytes \
        publisher_sha256 artifact_source_repository \
        artifact_source_revision <<EOF
$artifact_row
EOF
    if [ "$artifact_id" != "$resolved_id" ] || \
       [ "$artifact_file" != "$resolved_file" ]; then
        printf 'publisher artifact row differs from the model registry: %s\n' \
            "$resolved_id" >&2
        exit 2
    fi
    resolved_target=$(awk -F '\t' -v model_id="$resolved_id" '
        NR == 1 { next }
        $2 == model_id { print $5; count++ }
        END { exit count == 1 ? 0 : 1 }
    ' "$retained_targets") || {
        printf 'throughput target row is absent or duplicated: %s\n' \
            "$resolved_id" >&2
        exit 2
    }
    resolved_tuple="$resolved_role\t$resolved_target\t$resolved_context\t$resolved_batch\t$resolved_ubatch\t$resolved_cache_k\t$resolved_cache_v\t$resolved_flash"
    expected_tuple="$expected_role\t$expected_target\t$expected_context\t$expected_batch\t$expected_ubatch\t$expected_cache_k\t$expected_cache_v\t$expected_flash"
    if [ "$resolved_tuple" != "$expected_tuple" ]; then
        printf 'registered default tuple differs for %s\n' "$resolved_id" >&2
        printf 'expected: %b\nobserved: %b\n' "$expected_tuple" \
            "$resolved_tuple" >&2
        exit 2
    fi
    resolved_path=$models_directory/$resolved_file
    python3 - "$models_directory" "$resolved_path" <<'PY'
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
candidate = Path(sys.argv[2])
if not root.is_absolute() or not candidate.is_absolute():
    raise SystemExit("model root and path must be absolute")
root_resolved = root.resolve(strict=True)
candidate_resolved = candidate.resolve(strict=True)
if root_resolved not in candidate_resolved.parents:
    raise SystemExit(f"model escapes the model root: {candidate}")
if candidate.is_symlink() or not candidate.is_file():
    raise SystemExit(f"model is absent or linked: {candidate}")
current = root
for part in candidate.relative_to(root).parts:
    current /= part
    if current.is_symlink():
        raise SystemExit(f"model path contains a symbolic link: {current}")
PY
    resolved_identity=$(file_identity "$resolved_path")
    observed_bytes=${resolved_identity%%"$tab"*}
    observed_sha256=${resolved_identity#*"$tab"}
    if [ "$observed_bytes" != "$publisher_bytes" ] || \
       [ "$observed_sha256" != "$publisher_sha256" ]; then
        printf 'model artifact differs from publisher identity: %s\n' \
            "$resolved_id" >&2
        printf 'expected bytes=%s sha256=%s\nobserved bytes=%s sha256=%s\n' \
            "$publisher_bytes" "$publisher_sha256" \
            "$observed_bytes" "$observed_sha256" >&2
        exit 2
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$resolved_id" "$resolved_role" "$resolved_file" "$resolved_path" \
        "$resolved_context" "$resolved_batch" "$resolved_ubatch" \
        "$resolved_cache_k" "$resolved_cache_v" "$resolved_flash" \
        "$resolved_checkpoints" "$resolved_checkpoint_min_step" \
        "$resolved_target" "$publisher_bytes" "$publisher_sha256" \
        "$artifact_source_repository" "$artifact_source_revision" \
        "$observed_bytes" \
        "$observed_sha256" \
        >>"$models_resolved"
    record_before "model:$resolved_id" "$resolved_path"
}

resolve_model qwen35-08b compact-text 20 8192 128 32 q8_0 q4_0 on
resolve_model qwen38-2b-distill fast-text 10 24576 128 32 q8_0 q4_0 on
resolve_model qwen38-4b-distill balanced-text 5.25 24576 128 32 q8_0 q4_0 on

campaign_inputs=$output_directory/campaign-inputs.tsv
printf 'key\tvalue\n' >"$campaign_inputs"
printf 'schema\tfixed64-served-campaign-v2\n' >>"$campaign_inputs"
printf 'repository_remote\t%s\n' "$source_remote" >>"$campaign_inputs"
printf 'source_revision\t%s\n' "$source_revision" >>"$campaign_inputs"
printf 'source_tracked_state\t%s\n' "$source_tracked_state" >>"$campaign_inputs"
printf 'require_clean_source\t%s\n' "$require_clean_source" >>"$campaign_inputs"
printf 'runner_mode\t%s\n' "$runner_mode" >>"$campaign_inputs"
printf 'latency_probe_mode\t%s\n' "$latency_probe_mode" >>"$campaign_inputs"
printf 'campaign_output_directory\t%s\n' "$output_directory" >>"$campaign_inputs"
printf 'models_directory\t%s\n' "$models_directory" >>"$campaign_inputs"
printf 'state_directory\t%s\n' "$state_directory" >>"$campaign_inputs"
printf 'server_logical\t%s\n' "$server_logical" >>"$campaign_inputs"
printf 'server_resolved\t%s\n' "$server_path" >>"$campaign_inputs"
printf 'execution_path\t%s\n' "$campaign_path" >>"$campaign_inputs"
printf 'execution_surface\t%s\n' "$execution_surface" >>"$campaign_inputs"
printf 'host_shortname\t%s\n' "$host_shortname" >>"$campaign_inputs"
printf 'ssh_session\t%s\n' "$ssh_session" >>"$campaign_inputs"
printf 'server_nice\t19\n' >>"$campaign_inputs"
printf 'server_io_class\tidle\n' >>"$campaign_inputs"
printf 'vulkan_profile\tlow-async\n' >>"$campaign_inputs"
printf 'radv_icd\t%s\n' "$radv_icd" >>"$campaign_inputs"
printf 'inference_cpu\t0\n' >>"$campaign_inputs"
printf 'server_port\t8080\n' >>"$campaign_inputs"
printf 'bind_host\t127.0.0.1\n' >>"$campaign_inputs"
printf 'latency_mode\tobserve\n' >>"$campaign_inputs"
printf 'router\t0\n' >>"$campaign_inputs"
printf 'speculation\toff\n' >>"$campaign_inputs"
printf 'backend_sampling\t0\n' >>"$campaign_inputs"
printf 'require_api_key\t0\n' >>"$campaign_inputs"
printf 'web_broker\t0\n' >>"$campaign_inputs"
printf 'image_service\t0\n' >>"$campaign_inputs"
printf 'generate_tokens\t64\n' >>"$campaign_inputs"
printf 'sampling\ttemperature=0 top_k=1 seed=1 ignore_eos=true thinking=false\n' \
    >>"$campaign_inputs"
printf 'block_order\tforward,forward,reverse,reverse\n' >>"$campaign_inputs"
printf 'slots_per_model\t4\n' >>"$campaign_inputs"
printf 'cooldown_seconds\t%s\n' "$cooldown_seconds" >>"$campaign_inputs"
printf 'workload_lock\t%s\n' "$workload_lock" >>"$campaign_inputs"
printf 'campaign_lock\t%s\n' "$campaign_lock" >>"$campaign_inputs"
campaign_inputs_sha256=$(sha256sum "$campaign_inputs")
campaign_inputs_sha256=${campaign_inputs_sha256%% *}

schedule=$output_directory/schedule.tsv
printf 'slot\tblock\tdirection\tmodel_id\trole\ttarget_tok_s\tarm_directory\n' \
    >"$schedule"
slot=0
append_schedule_model() {
    schedule_model_id=$1
    schedule_block=$2
    schedule_direction=$3
    schedule_row=$(awk -F '\t' -v model_id="$schedule_model_id" '
        NR > 1 && $1 == model_id { print $2 "\t" $13 }
    ' "$models_resolved")
    schedule_role=${schedule_row%%"$tab"*}
    schedule_target=${schedule_row#*"$tab"}
    slot=$((slot + 1))
    arm_name=$(printf 'arms/%02d-%s-%s' "$slot" "$schedule_direction" \
        "$schedule_model_id")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$schedule_block" \
        "$schedule_direction" "$schedule_model_id" "$schedule_role" \
        "$schedule_target" "$arm_name" >>"$schedule"
}
append_schedule_model qwen35-08b 1 forward
append_schedule_model qwen38-2b-distill 1 forward
append_schedule_model qwen38-4b-distill 1 forward
append_schedule_model qwen35-08b 2 forward
append_schedule_model qwen38-2b-distill 2 forward
append_schedule_model qwen38-4b-distill 2 forward
append_schedule_model qwen38-4b-distill 3 reverse
append_schedule_model qwen38-2b-distill 3 reverse
append_schedule_model qwen35-08b 3 reverse
append_schedule_model qwen38-4b-distill 4 reverse
append_schedule_model qwen38-2b-distill 4 reverse
append_schedule_model qwen35-08b 4 reverse

arm_status=$output_directory/arm-status.tsv
printf 'slot\tmodel_id\trunner_status\tstate\n' >"$arm_status"
terminal_state=$output_directory/terminal-state.tsv
write_terminal_state() {
    terminal_value=$1
    terminal_completed=$2
    terminal_failed=$3
    terminal_target_state=$4
    terminal_failure_scope=$5
    terminal_new=$output_directory/.terminal-state.tsv.new
    printf 'state\texpected_arms\tcompleted_arms\tfailed_arms\ttarget_state\tfailure_scope\n' \
        >"$terminal_new"
    printf '%s\t12\t%s\t%s\t%s\t%s\n' "$terminal_value" \
        "$terminal_completed" "$terminal_failed" "$terminal_target_state" \
        "$terminal_failure_scope" \
        >>"$terminal_new"
    mv -- "$terminal_new" "$terminal_state"
}
write_terminal_state running 0 0 pending none

emergency_teardown_failed_arm() {
    emergency_slot=$1
    emergency_arm_directory=$2
    emergency_runner_pid=$3
    emergency_runner_start_time=$4
    emergency_runner_status=$5
    emergency_evidence_failed=0

    mark_emergency_evidence_failure() {
        printf 'emergency teardown evidence write failed: slot=%s artifact=%s\n' \
            "$emergency_slot" "$1" >&2
        emergency_evidence_failed=1
    }

    if [ ! -e "$emergency_arm_directory" ] && \
       [ ! -L "$emergency_arm_directory" ]; then
        mkdir -- "$emergency_arm_directory" || \
            mark_emergency_evidence_failure arm-directory
    fi
    if [ ! -d "$emergency_arm_directory" ] || \
       [ -L "$emergency_arm_directory" ]; then
        emergency_arm_directory=$output_directory/emergency-arm-$emergency_slot
        if [ ! -e "$emergency_arm_directory" ] && \
           [ ! -L "$emergency_arm_directory" ]; then
            mkdir -- "$emergency_arm_directory" || \
                mark_emergency_evidence_failure fallback-arm-directory
        fi
        if [ ! -d "$emergency_arm_directory" ] || \
           [ -L "$emergency_arm_directory" ]; then
            printf 'cannot retain emergency teardown evidence for slot %s\n' \
                "$emergency_slot" >&2
            emergency_arm_directory=$output_directory
        fi
    fi

    emergency_runner_new=$emergency_arm_directory/.emergency-runner.tsv.new
    if ! {
        printf 'slot\trunner_pid\trunner_start_time_ticks\trunner_status\n' \
            >"$emergency_runner_new" &&
        printf '%s\t%s\t%s\t%s\n' "$emergency_slot" "$emergency_runner_pid" \
            "$emergency_runner_start_time" "$emergency_runner_status" \
            >>"$emergency_runner_new" &&
        mv -- "$emergency_runner_new" \
            "$emergency_arm_directory/emergency-runner.tsv"
    }; then
        mark_emergency_evidence_failure emergency-runner.tsv
    fi

    emergency_snapshot_new=$emergency_arm_directory/.emergency-runtime-snapshot.tsv.new
    if ! printf 'source_name\tstate\tretained_name\n' \
        >"$emergency_snapshot_new"; then
        mark_emergency_evidence_failure emergency-runtime-snapshot.tsv
    fi
    for emergency_source_name in session.status server.pid server.log \
            telemetry.log graphics-latency.log kernel-hazards.log; do
        emergency_source=$state_directory/$emergency_source_name
        emergency_retained_name=emergency-$emergency_source_name
        if [ -f "$emergency_source" ] && [ ! -L "$emergency_source" ]; then
            if cp -- "$emergency_source" \
                "$emergency_arm_directory/$emergency_retained_name"; then
                emergency_source_state=retained
            else
                emergency_source_state=copy-failed
                emergency_retained_name=''
                mark_emergency_evidence_failure "$emergency_source_name"
            fi
        elif [ -e "$emergency_source" ] || [ -L "$emergency_source" ]; then
            emergency_source_state=rejected-nonregular
            emergency_retained_name=''
        else
            emergency_source_state=absent
            emergency_retained_name=''
        fi
        if ! printf '%s\t%s\t%s\n' "$emergency_source_name" \
            "$emergency_source_state" "$emergency_retained_name" \
            >>"$emergency_snapshot_new"; then
            mark_emergency_evidence_failure emergency-runtime-snapshot.tsv
        fi
    done
    if ! mv -- "$emergency_snapshot_new" \
        "$emergency_arm_directory/emergency-runtime-snapshot.tsv"; then
        mark_emergency_evidence_failure emergency-runtime-snapshot.tsv
    fi

    emergency_lock_probes=$emergency_arm_directory/emergency-lock-probes.tsv
    if ! printf 'point\tstatus\texpected_status\n' \
        >"$emergency_lock_probes"; then
        mark_emergency_evidence_failure emergency-lock-probes.tsv
    fi
    if flock -n -E 75 "$workload_lock" true; then
        emergency_lock_before_status=0
    else
        emergency_lock_before_status=$?
    fi
    if ! printf 'before-teardown\t%s\t75\n' "$emergency_lock_before_status" \
        >>"$emergency_lock_probes"; then
        mark_emergency_evidence_failure emergency-lock-probes.tsv
    fi

    emergency_attempts=$emergency_arm_directory/emergency-teardown-attempts.tsv
    if ! printf 'attempt\tteardown_status\n' >"$emergency_attempts"; then
        mark_emergency_evidence_failure emergency-teardown-attempts.tsv
    fi
    emergency_attempt=0
    emergency_teardown_status=1
    while [ "$emergency_teardown_status" -ne 0 ]; do
        emergency_attempt=$((emergency_attempt + 1))
        emergency_attempt_label=$(printf '%03d' "$emergency_attempt")
        emergency_attempt_stdout=$emergency_arm_directory/emergency-teardown-attempt-$emergency_attempt_label.stdout
        emergency_attempt_stderr=$emergency_arm_directory/emergency-teardown-attempt-$emergency_attempt_label.stderr
        # The lease descriptors close inside a child shell: dash applies a
        # trailing `8>&-` in its own descriptor table for the child's whole
        # runtime, which empties /proc/$$/fd/8 exactly while the teardown
        # verifies the holder, so a shell-level closure here can never pass
        # verification and the closure runs in the child instead.
        if env -i \
            HOME="${HOME:?}" QWEN_HOME="${QWEN_HOME:?}" PATH="$campaign_path" TMPDIR=/tmp LC_ALL=C \
            PYTHONDONTWRITEBYTECODE=1 \
            QWEN_WEBUI_STATE_DIRECTORY="$state_directory" \
            QWEN_SERVER_PORT="$campaign_server_port" \
            QWEN_RESULT_DIRECTORY="$emergency_arm_directory" \
            QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
            sh -c 'exec "$0" "$@" 8>&- 9>&-' "$retained_teardown" \
                >"$emergency_attempt_stdout" \
                2>"$emergency_attempt_stderr"; then
            emergency_teardown_status=0
        else
            emergency_teardown_status=$?
        fi
        if ! printf '%s\t%s\n' "$emergency_attempt" "$emergency_teardown_status" \
            >>"$emergency_attempts"; then
            mark_emergency_evidence_failure emergency-teardown-attempts.tsv
        fi
        if ! cp -- "$emergency_attempt_stdout" \
            "$emergency_arm_directory/emergency-teardown.stdout"; then
            mark_emergency_evidence_failure emergency-teardown.stdout
        fi
        if ! cp -- "$emergency_attempt_stderr" \
            "$emergency_arm_directory/emergency-teardown.stderr"; then
            mark_emergency_evidence_failure emergency-teardown.stderr
        fi

        emergency_teardown_state=accepted
        if [ "$emergency_teardown_status" -ne 0 ]; then
            emergency_teardown_state=retrying
        fi
        emergency_status_new=$emergency_arm_directory/.emergency-teardown-status.tsv.new
        if ! {
            printf 'slot\trunner_status\tteardown_status\tstate\n' \
                >"$emergency_status_new" &&
            printf '%s\t%s\t%s\t%s\n' "$emergency_slot" \
                "$emergency_runner_status" "$emergency_teardown_status" \
                "$emergency_teardown_state" >>"$emergency_status_new" &&
            mv -- "$emergency_status_new" \
                "$emergency_arm_directory/emergency-teardown-status.tsv"
        }; then
            mark_emergency_evidence_failure emergency-teardown-status.tsv
        fi

        if [ "$emergency_teardown_status" -ne 0 ]; then
            if ! write_terminal_state failed "$completed_arms" 1 pending \
                arm-emergency-teardown; then
                mark_emergency_evidence_failure terminal-state.tsv
            fi
            # The deferral covers a transient teardown failure; a persistent
            # one re-arms the terminating signals after three attempts, so
            # the operator can end a wedged campaign with SIGTERM instead of
            # the SIGKILL the lease design cannot unwind from.
            if [ "$emergency_attempt" -ge 3 ]; then
                trap 'handle_signal HUP 129' HUP
                trap 'handle_signal INT 130' INT
                trap 'handle_signal TERM 143' TERM
            fi
            sleep 5
        fi
    done

    if flock -n -E 75 "$workload_lock" true; then
        emergency_lock_after_status=0
    else
        emergency_lock_after_status=$?
    fi
    if ! printf 'after-teardown\t%s\t75\n' "$emergency_lock_after_status" \
        >>"$emergency_lock_probes"; then
        mark_emergency_evidence_failure emergency-lock-probes.tsv
    fi

    if [ "$emergency_evidence_failed" -ne 0 ]; then
        printf 'emergency teardown completed without a complete evidence record; the campaign retains the Vulkan lease\n' \
            >&2
        # The hold is deliberate -- the lease outlives the incomplete record
        # -- and the terminating signals are re-armed first, so the operator
        # ends the hold with SIGTERM rather than SIGKILL.
        trap 'handle_signal HUP 129' HUP
        trap 'handle_signal INT 130' INT
        trap 'handle_signal TERM 143' TERM
        while :; do
            sleep 5
        done
    fi

    trap 'handle_signal HUP 129' HUP
    trap 'handle_signal INT 130' INT
    trap 'handle_signal TERM 143' TERM
    if [ "$emergency_lock_before_status" -ne 75 ] || \
       [ "$emergency_lock_after_status" -ne 75 ]; then
        printf 'emergency teardown observed a broken campaign lease: before=%s after=%s\n' \
            "$emergency_lock_before_status" "$emergency_lock_after_status" >&2
        return 1
    fi
    return 0
}

mkdir -- "$output_directory/arms"
while IFS="$tab" read -r arm_slot arm_block arm_direction arm_model_id \
    arm_role arm_target arm_relative; do
    [ "$arm_slot" = slot ] && continue
    arm_row=$(awk -F '\t' -v model_id="$arm_model_id" '
        NR > 1 && $1 == model_id { print }
    ' "$models_resolved")
    IFS="$tab" read -r _model_id _role _model_file arm_model_path \
        arm_context arm_batch arm_ubatch arm_cache_k arm_cache_v arm_flash \
        arm_ctx_checkpoints arm_checkpoint_min_step _target _publisher_bytes \
        _publisher_sha256 _source_repository _source_revision _model_bytes \
        _model_sha256 <<EOF
$arm_row
EOF
    arm_directory=$output_directory/$arm_relative
    arm_label=$(printf '%02d-%s-%s' "$arm_slot" "$arm_direction" \
        "$arm_model_id")
    printf 'fixed64_arm=start slot=%s block=%s direction=%s model=%s role=%s target=%s\n' \
        "$arm_slot" "$arm_block" "$arm_direction" "$arm_model_id" \
        "$arm_role" "$arm_target"
    active_arm_directory=$arm_directory
    set +e
    env -i \
        HOME="${HOME:?}" QWEN_HOME="${QWEN_HOME:?}" PATH="$campaign_path" TMPDIR=/tmp LC_ALL=C \
        PYTHONDONTWRITEBYTECODE=1 \
        QWEN_MODEL_REGISTRY="$retained_registry" \
        QWEN_MODEL_ARTIFACTS="$retained_artifacts" \
        QWEN_QUARANTINE_REGISTRY="$retained_quarantine" \
        QWEN_VALIDATED_TUPLES="$retained_tuples" \
        QWEN_CTX_CHECKPOINT_LEDGER="$retained_checkpoints" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_LLAMA_SERVER="$server_path" \
        QWEN_LAUNCH_SCRIPT="$retained_launch" \
        QWEN_TEARDOWN_SCRIPT="$retained_teardown" \
        QWEN_STATE_DIRECTORY="$state_directory" \
        QWEN_RESULT_DIRECTORY="$arm_directory" \
        QWEN_CONTEXT_SIZE="$arm_context" \
        QWEN_BATCH_SIZE="$arm_batch" \
        QWEN_UBATCH_SIZE="$arm_ubatch" \
        QWEN_CACHE_TYPE_K="$arm_cache_k" \
        QWEN_CACHE_TYPE_V="$arm_cache_v" \
        QWEN_FLASH_ATTN="$arm_flash" \
        QWEN_CTX_CHECKPOINTS="$arm_ctx_checkpoints" \
        QWEN_CHECKPOINT_MIN_STEP="$arm_checkpoint_min_step" \
        QWEN_SPEC_TYPE=off \
        QWEN_BACKEND_SAMPLING=0 QWEN_SPEC_BACKEND_SAMPLING=0 \
        QWEN_ROUTER=0 QWEN_INFERENCE_CPU=0 \
        QWEN_SERVER_PORT="$campaign_server_port" QWEN_BIND_HOST=127.0.0.1 \
        QWEN_LATENCY_MODE=observe QWEN_REQUIRE_API_KEY=0 \
        QWEN_WEB_BROKER=0 QWEN_IMAGE_SERVICE=0 \
        QWEN_RADV_ICD="$radv_icd" \
        QWEN_VULKAN_LATENCY_PROBE="$retained_latency_probe" \
        QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
        QWEN_EXECUTION_SURFACE="$execution_surface" \
        QWEN_HOST_SHORTNAME="$host_shortname" \
        QWEN_SSH_SESSION="$ssh_session" \
        QWEN_EXECUTION_PROOF="$campaign_inputs" \
        QWEN_EXECUTION_PROOF_SHA256="$campaign_inputs_sha256" \
        QWEN_BENCH_GENERATE=64 \
        python3 -c 'import os, sys; os.setsid(); os.execve(sys.argv[1], sys.argv[1:], os.environ)' \
        "$retained_runner" "$arm_label" "$arm_model_path" low-async \
        >"$output_directory/.arm.stdout" 2>"$output_directory/.arm.stderr" &
    active_child_pid=$!
    active_child_start_time=$(sed 's/^.*) //' "/proc/$active_child_pid/stat" \
        2>/dev/null | awk '{ print $20 }')
    [ -n "$active_child_start_time" ] || active_child_start_time=unavailable
    wait "$active_child_pid"
    runner_status=$?
    finished_child_pid=$active_child_pid
    finished_child_start_time=$active_child_start_time
    if [ "$runner_status" -ne 0 ]; then
        # The failed runner may have left a tmux-hosted server whose descriptors
        # deliberately exclude the lease. Defer catchable signals until the
        # state-based teardown proof succeeds, so the outer holder cannot
        # release descriptor 8 while that workload survives.
        trap '' HUP INT TERM
    fi
    active_child_pid=''
    active_child_start_time=''
    emergency_recovery_status=0
    if [ "$runner_status" -ne 0 ]; then
        if ! emergency_teardown_failed_arm "$arm_slot" "$arm_directory" \
            "$finished_child_pid" "$finished_child_start_time" \
            "$runner_status"; then
            emergency_recovery_status=1
        fi
    fi
    set -e
    if [ -d "$arm_directory" ]; then
        mv -- "$output_directory/.arm.stdout" "$arm_directory/campaign-runner.stdout"
        mv -- "$output_directory/.arm.stderr" "$arm_directory/campaign-runner.stderr"
    fi
    arm_state=completed
    [ "$runner_status" -eq 0 ] || arm_state=failed
    arm_status_new=$output_directory/.arm-status.tsv.new
    cp -- "$arm_status" "$arm_status_new"
    printf '%s\t%s\t%s\t%s\n' "$arm_slot" "$arm_model_id" \
        "$runner_status" "$arm_state" >>"$arm_status_new"
    mv -- "$arm_status_new" "$arm_status"
    if [ "$runner_status" -ne 0 ]; then
        failure_scope=arm
        if [ "$emergency_recovery_status" -ne 0 ]; then
            failure_scope=arm-lease-invariant
        fi
        write_terminal_state failed "$completed_arms" 1 pending "$failure_scope"
        printf 'fixed64_campaign=failed slot=%s model=%s status=%s output_directory=%s\n' \
            "$arm_slot" "$arm_model_id" "$runner_status" \
            "$output_directory" >&2
        exit 1
    fi
    completed_arms=$((completed_arms + 1))
    write_terminal_state running "$completed_arms" 0 pending none
    printf 'fixed64_arm=completed slot=%s model=%s\n' "$arm_slot" \
        "$arm_model_id"
    if [ "$arm_slot" -lt 12 ] && [ "$cooldown_seconds" -gt 0 ]; then
        sleep "$cooldown_seconds"
    fi
done <"$schedule"

git -C "$repository_root" ls-files -s >"$output_directory/source-index-after.tsv"
git -C "$repository_root" status --porcelain=v1 --untracked-files=no \
    >"$output_directory/source-status-after.txt"
git -C "$repository_root" rev-parse HEAD >"$output_directory/source-head-after.txt"
if ! cmp -s "$output_directory/source-index-before.tsv" \
        "$output_directory/source-index-after.tsv" || \
   ! cmp -s "$output_directory/source-status-before.txt" \
        "$output_directory/source-status-after.txt" || \
   ! cmp -s "$output_directory/source-head-before.txt" \
        "$output_directory/source-head-after.txt"; then
    write_terminal_state failed 12 0 pending source-drift
    printf 'fixed64_campaign=failed reason=source-drift output_directory=%s\n' \
        "$output_directory" >&2
    exit 1
fi

summary_new=$output_directory/.summary.tsv.new
model_summary_new=$output_directory/.model-summary.tsv.new
rm -f -- "$summary_new" "$model_summary_new"
if ! PYTHONDONTWRITEBYTECODE=1 "$retained_summarizer" "$output_directory" \
    "$summary_new" "$model_summary_new" >"$output_directory/summary-execution.txt"; then
    rm -f -- "$summary_new" "$model_summary_new"
    write_terminal_state failed 12 0 pending invalid-summary
    printf 'fixed64_campaign=failed reason=summary-invalid output_directory=%s\n' \
        "$output_directory" >&2
    exit 1
fi
mv -- "$summary_new" "$output_directory/summary.tsv"
mv -- "$model_summary_new" "$output_directory/model-summary.tsv"
# A target claim needs at least one measured row: an empty table proves
# nothing and reads unmet rather than met.
target_state=$(awk -F '\t' '
    NR > 1 { data_rows++ }
    NR > 1 && $11 != "met" { failed = 1 }
    END { print (data_rows && !failed) ? "met" : "unmet" }
' "$output_directory/model-summary.tsv")

identity_check_new=$output_directory/.identity-check.tsv.new
printf 'subject\tpath\texpected_bytes\tobserved_bytes\texpected_sha256\tobserved_sha256\tstate\n' \
    >"$identity_check_new"
identity_failures=0
while IFS="$tab" read -r identity_subject identity_path expected_bytes \
    expected_sha256; do
    [ "$identity_subject" = subject ] && continue
    observed_identity=$(file_identity "$identity_path")
    observed_bytes=${observed_identity%%"$tab"*}
    observed_sha256=${observed_identity#*"$tab"}
    identity_state=accepted
    if [ "$expected_bytes" != "$observed_bytes" ] || \
       [ "$expected_sha256" != "$observed_sha256" ]; then
        identity_state=rejected
        identity_failures=$((identity_failures + 1))
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$identity_subject" \
        "$identity_path" "$expected_bytes" "$observed_bytes" \
        "$expected_sha256" "$observed_sha256" "$identity_state" \
        >>"$identity_check_new"
done <"$identity_before"
mv -- "$identity_check_new" "$output_directory/identity-check.tsv"
if [ "$identity_failures" -ne 0 ]; then
    write_terminal_state failed 12 0 pending identity-drift
    printf 'fixed64_campaign=failed reason=identity-drift count=%s output_directory=%s\n' \
        "$identity_failures" "$output_directory" >&2
    exit 1
fi

terminal_result=completed
exit_status=0
if [ "$target_state" != met ]; then
    terminal_result=completed-target-unmet
    exit_status=1
fi
write_terminal_state "$terminal_result" 12 0 "$target_state" none

# SHA256SUMS is the terminal artifact. The temporary file lives in the same
# directory, and POSIX rename semantics keep the published name indivisible.
manifest_new=$output_directory/.SHA256SUMS.new
set +e
(
    cd "$output_directory"
    find . -type f ! -name SHA256SUMS ! -name .SHA256SUMS.new -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum
) >"$manifest_new"
manifest_status=$?
set -e
if [ "$manifest_status" -ne 0 ]; then
    rm -f -- "$manifest_new"
    write_terminal_state failed 12 0 "$target_state" manifest-generation
    printf 'fixed64_campaign=failed reason=manifest-generation output_directory=%s\n' \
        "$output_directory" >&2
    exit 1
fi
set +e
(
    cd "$output_directory"
    sha256sum -c .SHA256SUMS.new >/dev/null
)
manifest_check_status=$?
set -e
if [ "$manifest_check_status" -ne 0 ]; then
    rm -f -- "$manifest_new"
    write_terminal_state failed 12 0 "$target_state" manifest-verification
    printf 'fixed64_campaign=failed reason=manifest-verification output_directory=%s\n' \
        "$output_directory" >&2
    exit 1
fi
if ! PYTHONDONTWRITEBYTECODE=1 "$retained_summarizer" --verify-sealed \
    --manifest-path "$manifest_new" "$output_directory" >/dev/null; then
    rm -f -- "$manifest_new"
    write_terminal_state failed 12 0 "$target_state" sealed-manifest-verification
    printf 'fixed64_campaign=failed reason=sealed-manifest-verification output_directory=%s\n' \
        "$output_directory" >&2
    exit 1
fi
mv -- "$manifest_new" "$output_directory/SHA256SUMS"

printf 'fixed64_campaign=%s target_state=%s output_directory=%s\n' \
    "$terminal_result" "$target_state" "$output_directory"
exit "$exit_status"
