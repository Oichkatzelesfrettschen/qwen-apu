#!/bin/sh
set -eu

# Measure decode through the guarded launch path under the same terms
# llama-bench measures it: a fixed generation length, end of sequence ignored,
# greedy sampling, one request against a freshly loaded server. The served
# figures already recorded came from a 13-token reply, where per-request
# transitions occupy a large share of the window, so they are not comparable to
# a 64-token steady-state rate. This makes them comparable, which leaves the
# harness itself as the only difference between the two numbers.
#
# QWEN_CACHE_TYPE_K, QWEN_CACHE_TYPE_V, and QWEN_FLASH_ATTN reach the server
# through qwen-webui-control.sh, so one cache cell of the factorial runs here
# exactly as it runs under llama-bench.

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    printf 'usage: %s LABEL MODEL_PATH [PROFILE]\n' "$0" >&2
    exit 2
fi

label=$1
model_path=$2
profile=${3:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
launch_script=${QWEN_LAUNCH_SCRIPT:-"$script_directory/qwen-launch.sh"}
teardown_script=${QWEN_TEARDOWN_SCRIPT:-"$script_directory/qwen-teardown.sh"}
state_directory=${QWEN_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
result_directory=${QWEN_RESULT_DIRECTORY:-"${HOME:?}/qwen-served-decode/$label"}
external_lease_proof=${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}
external_lease_verifier=$script_directory/verify-external-vulkan-lease.py
endpoint=http://127.0.0.1:${QWEN_SERVER_PORT:-8080}
generate_tokens=${QWEN_BENCH_GENERATE:-64}
execution_surface=${QWEN_EXECUTION_SURFACE:-}
host_shortname=${QWEN_HOST_SHORTNAME:-}
ssh_session=${QWEN_SSH_SESSION:-}
execution_proof=${QWEN_EXECUTION_PROOF:-}
execution_proof_sha256=${QWEN_EXECUTION_PROOF_SHA256:-}
export QWEN_WEBUI_STATE_DIRECTORY=$state_directory

if [ "$execution_surface" != hp14-ssh ] || \
   [ "$host_shortname" != hp14-dk1xxx ] || [ "$ssh_session" != present ]; then
    printf 'served measurement requires the hp14 SSH execution contract\n' >&2
    exit 2
fi
if ! python3 - "$execution_proof" "$execution_proof_sha256" \
    "$result_directory" "$execution_surface" "$host_shortname" \
    "$ssh_session" <<'PY'
import hashlib
import os
import stat
import sys
from pathlib import Path

proof_text, expected_digest, result_text = sys.argv[1:4]
observed_contract = {
    "execution_surface": sys.argv[4],
    "host_shortname": sys.argv[5],
    "ssh_session": sys.argv[6],
}
proof_path = Path(proof_text)
result_path = Path(result_text)
expected_path = result_path.parent.parent / "campaign-inputs.tsv"
if (
    not proof_path.is_absolute()
    or os.path.normpath(proof_text) != proof_text
    or proof_path != expected_path
):
    raise SystemExit(1)
try:
    proof_status = proof_path.lstat()
except OSError:
    raise SystemExit(1) from None
if not stat.S_ISREG(proof_status.st_mode) or proof_path.is_symlink():
    raise SystemExit(1)
proof_bytes = proof_path.read_bytes()
if (
    len(expected_digest) != 64
    or any(character not in "0123456789abcdef" for character in expected_digest)
    or hashlib.sha256(proof_bytes).hexdigest() != expected_digest
):
    raise SystemExit(1)
values = {}
try:
    lines = proof_bytes.decode("utf-8").splitlines()
except UnicodeDecodeError:
    raise SystemExit(1) from None
if not lines or lines[0] != "key\tvalue":
    raise SystemExit(1)
for line in lines[1:]:
    fields = line.split("\t")
    if len(fields) != 2 or not fields[0] or fields[0] in values:
        raise SystemExit(1)
    values[fields[0]] = fields[1]
expected_contract = {
    "schema": "fixed64-served-campaign-v2",
    "execution_surface": "hp14-ssh",
    "host_shortname": "hp14-dk1xxx",
    "ssh_session": "present",
    "server_nice": "19",
    "server_io_class": "idle",
}
if any(values.get(key) != value for key, value in expected_contract.items()):
    raise SystemExit(1)
if any(values.get(key) != value for key, value in observed_contract.items()):
    raise SystemExit(1)
PY
then
    printf 'served measurement execution proof is absent or inconsistent\n' >&2
    exit 2
fi

case $generate_tokens in
    '' | *[!0-9]* | 0)
        printf 'generation length must be a positive integer: %s\n' \
            "$generate_tokens" >&2
        exit 2
        ;;
esac
if [ "$generate_tokens" -lt 2 ]; then
    printf 'generation length must cover at least one decode transition: %s\n' \
        "$generate_tokens" >&2
    exit 2
fi

if [ ! -f "$model_path" ]; then
    printf 'model file is absent: %s\n' "$model_path" >&2
    exit 2
fi

umask 077
mkdir -p "$result_directory"

# Descriptor 7 holds the model inode for the complete arm. The launch receives
# the descriptor path rather than the mutable input pathname, so an atomic
# replace-and-restore of the pathname cannot change the bytes llama-server
# opens. Descriptor 6 holds the executable identity approved before launch;
# the running-process capture later opens /proc/PID/exe itself and compares the
# mapped image to this descriptor-bound identity.
approved_model_path=$model_path
if ! exec 7<"$approved_model_path"; then
    printf 'model file cannot be pinned: %s\n' "$approved_model_path" >&2
    exit 2
fi
model_launch_path=/proc/$$/fd/7
approved_executable_path=${QWEN_LLAMA_SERVER:-}
approved_executable_descriptor=''
if [ -n "$approved_executable_path" ]; then
    if ! exec 6<"$approved_executable_path"; then
        printf 'llama-server executable cannot be pinned: %s\n' \
            "$approved_executable_path" >&2
        exit 2
    fi
    approved_executable_descriptor=/proc/$$/fd/6
fi

runtime_inputs_new=$result_directory/.runtime-inputs.json.new
rm -f -- "$runtime_inputs_new"
if ! python3 - "$approved_model_path" "$model_launch_path" \
    "$approved_executable_path" "$approved_executable_descriptor" \
    "${QWEN_MODEL_ARTIFACTS:-}" "${QWEN_MODELS_DIRECTORY:-}" \
    "$runtime_inputs_new" <<'PY'
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

(
    model_path_text,
    model_descriptor_text,
    executable_path_text,
    executable_descriptor_text,
    artifact_ledger_text,
    models_directory_text,
    output_path_text,
) = sys.argv[1:]


def fail(message):
    raise SystemExit(f"runtime input identity failed: {message}")


def descriptor_identity(logical_path, descriptor_path, require_executable=False):
    try:
        before = os.stat(descriptor_path)
        path_status = os.stat(logical_path)
    except OSError as error:
        fail(f"cannot stat {logical_path}: {error}")
    if not stat.S_ISREG(before.st_mode):
        fail(f"input is not regular: {logical_path}")
    if require_executable and not os.access(descriptor_path, os.X_OK):
        fail(f"input is not executable: {logical_path}")
    if (before.st_dev, before.st_ino) != (path_status.st_dev, path_status.st_ino):
        fail(f"pathname changed while pinning: {logical_path}")
    digest = hashlib.sha256()
    try:
        with open(descriptor_path, "rb", buffering=0) as descriptor_handle:
            for chunk in iter(lambda: descriptor_handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        fail(f"cannot hash {logical_path}: {error}")
    after = os.stat(descriptor_path)
    if (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
    ) != (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
    ):
        fail(f"descriptor identity changed while hashing: {logical_path}")
    return {
        "path": str(Path(logical_path).resolve(strict=True)),
        "descriptor_path": descriptor_path,
        "device": before.st_dev,
        "inode": before.st_ino,
        "bytes": before.st_size,
        "sha256": digest.hexdigest(),
    }


model_identity = descriptor_identity(model_path_text, model_descriptor_text)
if artifact_ledger_text:
    ledger_path = Path(artifact_ledger_text)
    if not ledger_path.is_file() or ledger_path.is_symlink():
        fail(f"model artifact ledger is absent or linked: {ledger_path}")
    if not models_directory_text:
        fail("QWEN_MODELS_DIRECTORY is absent beside the artifact ledger")
    models_directory = Path(models_directory_text).resolve(strict=True)
    model_path = Path(model_identity["path"])
    try:
        model_file = model_path.relative_to(models_directory).as_posix()
    except ValueError:
        fail(f"model escapes QWEN_MODELS_DIRECTORY: {model_path}")
    matches = []
    for line_number, line in enumerate(
        ledger_path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 6:
            fail(f"artifact ledger line {line_number} is malformed")
        if fields[1] == model_file:
            matches.append(fields)
    if len(matches) != 1:
        fail(f"artifact ledger requires one row for {model_file}, found {len(matches)}")
    try:
        expected_bytes = int(matches[0][2])
    except ValueError:
        fail(f"artifact ledger carries malformed bytes for {model_file}")
    expected_sha256 = matches[0][3]
    if (
        model_identity["bytes"] != expected_bytes
        or model_identity["sha256"] != expected_sha256
    ):
        fail(f"descriptor bytes differ from publisher identity: {model_file}")
    model_identity["artifact_model_id"] = matches[0][0]
    model_identity["artifact_model_file"] = model_file

document = {"schema": "served-runtime-inputs-v1", "model": model_identity}
if executable_path_text:
    document["executable"] = descriptor_identity(
        executable_path_text, executable_descriptor_text, require_executable=True
    )
with Path(output_path_text).open("x", encoding="utf-8") as output_handle:
    json.dump(document, output_handle, indent=2)
    output_handle.write("\n")
PY
then
    rm -f -- "$runtime_inputs_new"
    exit 2
fi
mv -- "$runtime_inputs_new" "$result_directory/runtime-inputs.json"
approved_model_identity=$(python3 - "$result_directory/runtime-inputs.json" <<'PY'
import json
import re
import sys
from pathlib import Path

runtime_inputs = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if runtime_inputs.get("schema") != "served-runtime-inputs-v1":
    raise SystemExit("approved runtime input schema differs")
try:
    model = runtime_inputs["model"]
    device = model["device"]
    inode = model["inode"]
    byte_count = model["bytes"]
except (KeyError, TypeError) as error:
    raise SystemExit(f"approved model identity is incomplete: {error}") from None
model_id = model.get("artifact_model_id")
model_file = model.get("artifact_model_file")
if model_id is None and model_file is None:
    raise SystemExit(0)
if model_id is None or model_file is None:
    raise SystemExit("approved publisher identity is incomplete")
if not isinstance(model_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", model_id):
    raise SystemExit("approved model ID is malformed")
if (
    not isinstance(model_file, str)
    or not model_file
    or model_file.startswith("/")
    or "\\" in model_file
    or any(part in ("", ".", "..") for part in model_file.split("/"))
    or any(character in model_file for character in "\t\r\n")
):
    raise SystemExit("approved model file is malformed")
for name, value, minimum in (
    ("device", device, 0),
    ("inode", inode, 1),
    ("bytes", byte_count, 0),
):
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise SystemExit(f"approved model {name} is malformed")
print(model_id, model_file, device, inode, byte_count, sep="\t")
PY
) || exit 2
unset QWEN_APPROVED_MODEL_ID QWEN_APPROVED_MODEL_FILE QWEN_APPROVED_MODEL_DEVICE \
    QWEN_APPROVED_MODEL_INODE QWEN_APPROVED_MODEL_BYTES
if [ -n "$approved_model_identity" ]; then
    IFS="$(printf '\t')" read -r approved_model_id approved_model_file \
        approved_model_device approved_model_inode approved_model_bytes <<EOF
$approved_model_identity
EOF
    QWEN_APPROVED_MODEL_ID=$approved_model_id
    QWEN_APPROVED_MODEL_FILE=$approved_model_file
    QWEN_APPROVED_MODEL_DEVICE=$approved_model_device
    QWEN_APPROVED_MODEL_INODE=$approved_model_inode
    QWEN_APPROVED_MODEL_BYTES=$approved_model_bytes
    export QWEN_APPROVED_MODEL_ID QWEN_APPROVED_MODEL_FILE \
        QWEN_APPROVED_MODEL_DEVICE \
        QWEN_APPROVED_MODEL_INODE QWEN_APPROVED_MODEL_BYTES
fi
printf 'label=%s\nmodel=%s\nprofile=%s\ncache_type_k=%s\ncache_type_v=%s\nflash_attention=%s\nctx_checkpoints=%s\ncheckpoint_min_step=%s\ngenerate_tokens=%s\n' \
    "$label" "$approved_model_path" "$profile" \
    "${QWEN_CACHE_TYPE_K:-registry}" "${QWEN_CACHE_TYPE_V:-registry}" \
    "${QWEN_FLASH_ATTN:-registry}" "${QWEN_CTX_CHECKPOINTS:-registry}" \
    "${QWEN_CHECKPOINT_MIN_STEP:-registry}" "$generate_tokens" \
    >"$result_directory/inputs.txt"

server_started=0
teardown_status=not_run
carrier_lease_proof=''
teardown_server() {
    [ "$server_started" -eq 1 ] || return 0
    # The lease descriptors close inside a child shell: dash applies a
    # trailing `8>&-` in its own table for the child's whole runtime, which
    # would empty /proc/$$/fd/8 exactly while teardown verifies the carrier.
    if sh -c 'exec "$0" "$@" 8>&- 9>&-' "$teardown_script" \
        >"$result_directory/teardown.txt" 2>&1; then
        teardown_status=0
    else
        teardown_status=$?
    fi
    server_started=0
}

cleanup_carrier_lease_proof() {
    if [ -n "$carrier_lease_proof" ]; then
        rm -f -- "$carrier_lease_proof"
        carrier_lease_proof=''
    fi
}

publish_carrier_lease_proof() {
    [ -n "$external_lease_proof" ] || return 0
    expected_lease=$state_directory/vulkan-workload.lock
    inherited_lease=$(readlink -f -- "/proc/$$/fd/8" 2>/dev/null || true)
    if [ "$inherited_lease" != "$expected_lease" ]; then
        printf 'served runner descriptor 8 names another lease: %s != %s\n' \
            "$inherited_lease" "$expected_lease" >&2
        return 1
    fi
    if [ ! -x "$external_lease_verifier" ]; then
        printf 'external lease verifier is absent: %s\n' \
            "$external_lease_verifier" >&2
        return 1
    fi
    "$external_lease_verifier" "$external_lease_proof" "$expected_lease" \
        >/dev/null || return 1
    lease_source_revision=$(awk -F '\t' \
        '$1 == "source_revision" { print $2; count++ }
         END { exit count == 1 ? 0 : 1 }' "$external_lease_proof") || return 1
    holder_start_time=$(sed 's/^.*) //' "/proc/$$/stat" | awk '{ print $20 }')
    carrier_lease_proof=$state_directory/.fixed64-vulkan-external-lease.$$.tsv
    carrier_lease_proof_new=$carrier_lease_proof.new
    if [ -e "$carrier_lease_proof" ] || [ -L "$carrier_lease_proof" ] || \
       [ -e "$carrier_lease_proof_new" ] || [ -L "$carrier_lease_proof_new" ]; then
        printf 'served runner lease proof path is already occupied: %s\n' \
            "$carrier_lease_proof" >&2
        return 1
    fi
    {
        printf 'key\tvalue\n'
        printf 'schema\tfixed64-vulkan-external-lease-v1\n'
        printf 'lock_path\t%s\n' "$expected_lease"
        printf 'holder_pid\t%s\n' "$$"
        printf 'holder_start_time_ticks\t%s\n' "$holder_start_time"
        printf 'holder_fd\t8\n'
        printf 'source_revision\t%s\n' "$lease_source_revision"
    } >"$carrier_lease_proof_new"
    chmod 0600 "$carrier_lease_proof_new"
    mv -- "$carrier_lease_proof_new" "$carrier_lease_proof"
    "$external_lease_verifier" "$carrier_lease_proof" "$expected_lease" \
        >/dev/null || return 1
    cp -- "$carrier_lease_proof" \
        "$result_directory/external-vulkan-lease-carrier.tsv"
    external_lease_proof=$carrier_lease_proof
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF=$carrier_lease_proof
    export QWEN_VULKAN_EXTERNAL_LEASE_PROOF
}

retain_running_process_evidence() {
    status_source=$state_directory/session.status
    if [ ! -f "$status_source" ] || [ -L "$status_source" ] || \
       [ ! -s "$status_source" ]; then
        printf 'served session status is absent, linked, or empty: %s\n' \
            "$status_source" >&2
        return 1
    fi
    cp -- "$status_source" "$result_directory/session.status" || return 1

    process_new=$result_directory/.server-process.json.new
    rm -f -- "$process_new"
    if ! python3 - "$result_directory/session.status" "$process_new" \
        "$result_directory/runtime-inputs.json" \
        "$profile" "${QWEN_CONTEXT_SIZE:-}" \
        "${QWEN_INFERENCE_CPU:-0}" \
        "$execution_surface" "$host_shortname" "$ssh_session" <<'PY'
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

status_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
runtime_inputs_path = Path(sys.argv[3])
expected_profile = sys.argv[4]
expected_context = sys.argv[5]
expected_cpu = sys.argv[6]
execution_surface = sys.argv[7]
host_shortname = sys.argv[8]
ssh_session = sys.argv[9]


def fail(message):
    raise SystemExit(f"served process evidence failed: {message}")


if (
    execution_surface != "hp14-ssh"
    or host_shortname != "hp14-dk1xxx"
    or ssh_session != "present"
):
    fail("execution-surface contract differs from hp14 SSH")


def parse_fields(line, section):
    if section:
        prefix = f"{section} "
        if not line.startswith(prefix):
            fail(f"session status lacks {section}")
        line = line[len(prefix):]
    result = {}
    for token in line.split():
        key, separator, value = token.partition("=")
        if not separator or not key or not value or key in result:
            fail(f"session status carries malformed {section or 'state'} fields")
        result[key] = value
    return result


status_lines = status_path.read_text(encoding="utf-8").splitlines()
if not status_lines:
    fail("session status is empty")
state_fields = parse_fields(status_lines[0], "")
if state_fields.get("state") != "running":
    fail("session status does not declare running")
if state_fields.get("profile") != expected_profile:
    fail("session profile differs from the requested profile")
if expected_context and state_fields.get("context") != expected_context:
    fail("session context differs from QWEN_CONTEXT_SIZE")
try:
    server_pid = int(state_fields["server_pid"])
except (KeyError, ValueError):
    fail("session server_pid is absent or malformed")
if server_pid <= 0:
    fail("session server_pid is not positive")

process_root = Path("/proc") / str(server_pid)
try:
    runtime_inputs = json.loads(runtime_inputs_path.read_text(encoding="utf-8"))
    expected_executable = runtime_inputs["executable"]
except (OSError, KeyError, TypeError, json.JSONDecodeError) as error:
    fail(f"approved executable identity is unreadable: {error}")
if runtime_inputs.get("schema") != "served-runtime-inputs-v1":
    fail("approved runtime input schema differs")


def read_process_stat():
    stat_text = (process_root / "stat").read_text(encoding="utf-8")
    command_end = stat_text.rfind(")")
    if command_end < 0 or command_end + 2 >= len(stat_text):
        fail("/proc stat is malformed")
    fields = stat_text[command_end + 2:].split()
    if len(fields) < 20:
        fail("/proc stat has too few fields")
    try:
        return int(fields[16]), int(fields[19])
    except ValueError:
        fail("/proc stat nice or start time is malformed")


nice_value, start_time_ticks = read_process_stat()
if start_time_ticks <= 0:
    fail("process start time is not positive")
try:
    executable_link = os.readlink(process_root / "exe")
    executable_fd = os.open(process_root / "exe", os.O_RDONLY)
except OSError as error:
    fail(f"cannot open live /proc executable: {error}")
try:
    live_executable_status = os.fstat(executable_fd)
    _, start_time_after_open = read_process_stat()
    if start_time_after_open != start_time_ticks:
        fail("process identity changed while opening /proc executable")
    digest = hashlib.sha256()
    with os.fdopen(executable_fd, "rb", buffering=0, closefd=False) as executable_handle:
        for chunk in iter(lambda: executable_handle.read(1024 * 1024), b""):
            digest.update(chunk)
    _, start_time_after_hash = read_process_stat()
    if start_time_after_hash != start_time_ticks:
        fail("process identity changed while hashing /proc executable")
finally:
    os.close(executable_fd)
live_identity = (
    live_executable_status.st_dev,
    live_executable_status.st_ino,
    live_executable_status.st_size,
    digest.hexdigest(),
)
approved_identity = (
    expected_executable.get("device"),
    expected_executable.get("inode"),
    expected_executable.get("bytes"),
    expected_executable.get("sha256"),
)
if live_identity != approved_identity:
    fail("live /proc executable differs from approved identity")
executable = expected_executable.get("path")
if not isinstance(executable, str) or not Path(executable).is_absolute():
    fail("approved executable path is not absolute")

argv_bytes = (process_root / "cmdline").read_bytes()
if not argv_bytes or not argv_bytes.endswith(b"\0"):
    fail("/proc cmdline lacks its terminal NUL")
try:
    argv = [field.decode("utf-8") for field in argv_bytes[:-1].split(b"\0")]
except UnicodeDecodeError:
    fail("/proc cmdline is not UTF-8")
if not argv or argv[0] != executable:
    fail("process argv[0] differs from the executable")

cpus_allowed_list = ""
for status_line in (process_root / "status").read_text(encoding="utf-8").splitlines():
    if status_line.startswith("Cpus_allowed_list:"):
        cpus_allowed_list = status_line.split(":", 1)[1].strip()
        break
if not cpus_allowed_list:
    fail("Cpus_allowed_list is absent")
ionice_output = subprocess.run(
    ["ionice", "-p", str(server_pid)],
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()
io_class = "idle" if ionice_output == "idle" else ionice_output

nice_after, start_time_after = read_process_stat()
if nice_after != nice_value or start_time_after != start_time_ticks:
    fail("process identity or nice value changed during capture")
if nice_value != 19:
    fail(f"process nice value is {nice_value}, expected 19")
if cpus_allowed_list != expected_cpu:
    fail(
        f"process CPU list is {cpus_allowed_list}, expected {expected_cpu}"
    )
if io_class != "idle":
    fail(f"process I/O class is {io_class}, expected idle")

document = {
    "schema": "served-decode-process-v3",
    "execution_surface": execution_surface,
    "host_shortname": host_shortname,
    "ssh_session": ssh_session,
    "pid": server_pid,
    "start_time_ticks": start_time_ticks,
    "executable": executable,
    "executable_proc_link": executable_link,
    "executable_device": live_executable_status.st_dev,
    "executable_inode": live_executable_status.st_ino,
    "executable_bytes": live_executable_status.st_size,
    "executable_sha256": digest.hexdigest(),
    "argv": argv,
    "nice": nice_value,
    "cpus_allowed_list": cpus_allowed_list,
    "io_class": io_class,
}
with output_path.open("x", encoding="utf-8") as output_handle:
    json.dump(document, output_handle, indent=2)
    output_handle.write("\n")
PY
    then
        rm -f -- "$process_new"
        return 1
    fi
    mv -- "$process_new" "$result_directory/server-process.json" || return 1

}

retain_quiescent_runtime_evidence() {
    for retained_name in server.log telemetry.log graphics-latency.log \
            kernel-hazards.log; do
        retained_source=$state_directory/$retained_name
        # The session publishes telemetry.log as a symlink into the immutable
        # per-session record directory, so that one name follows its link when
        # the target is a regular nonempty file inside telemetry/.
        if [ "$retained_name" = telemetry.log ] && [ -L "$retained_source" ]; then
            retained_target=$(readlink -f -- "$retained_source" || :)
            case $retained_target in
                "$state_directory/telemetry/"*) ;;
                *) retained_target='' ;;
            esac
            if [ -n "$retained_target" ] && [ -f "$retained_target" ] && \
               [ ! -L "$retained_target" ] && [ -s "$retained_target" ]; then
                retained_source=$retained_target
            fi
        fi
        if [ ! -f "$retained_source" ] || [ -L "$retained_source" ] || \
           [ ! -s "$retained_source" ]; then
            printf 'served runtime log is absent, linked, or empty: %s\n' \
                "$retained_source" >&2
            return 1
        fi
        cp -- "$retained_source" "$result_directory/$retained_name" || return 1
    done
    terminal_watch_count=$(grep -Ec \
        '^watch_stop_utc=[^ ]+ reason=server_exited$' \
        "$result_directory/kernel-hazards.log" || true)
    if [ "$terminal_watch_count" -ne 1 ]; then
        printf 'kernel hazard log lacks one terminal server-exit marker\n' >&2
        return 1
    fi
    hazard_pattern='ring[^[:cntrl:]]*timeout|GPU reset|amdgpu[^[:cntrl:]]*reset|VM fault|device loss|device lost|out of memory|oom-kill|^hazard_utc=|^hazard_stream_ended_while_server_running='
    # The watcher opens its log with a `hazard_pattern=` line that spells out
    # the same alternation, so that declaration is removed ahead of the match
    # and only a kernel line or a watcher marker counts as a hazard.
    if grep -Ev '^hazard_pattern=' "$result_directory/kernel-hazards.log" | \
        grep -Eai "$hazard_pattern" >/dev/null; then
        printf 'kernel hazard log records a terminal GPU or memory hazard\n' >&2
        return 1
    fi
}

trap 'teardown_server; cleanup_carrier_lease_proof' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

publish_carrier_lease_proof

QWEN_MODEL_PATH=$model_launch_path \
    sh -c 'exec "$0" "$@" 8>&- 9>&-' "$launch_script" "$profile" \
    >"$result_directory/launch.txt" 2>&1 || {
        cat "$result_directory/launch.txt" >&2
        exit 1
    }
server_started=1

api_key=''
if [ -s "$state_directory/api.key" ]; then
    api_key=$(sed -n '1p' "$state_directory/api.key")
fi

# ignore_eos fixes the generation length, so the rate covers the same number of
# decode steps as `llama-bench -n 64` rather than however many the model chose.
printf '{"model":"qwen-apu","messages":[{"role":"user","content":"Write one paragraph about tides."}],"max_tokens":%s,"temperature":0,"top_k":1,"seed":1,"ignore_eos":true,"chat_template_kwargs":{"enable_thinking":false}}' \
    "$generate_tokens" >"$result_directory/request.json"

set +e
if [ -n "$api_key" ]; then
    curl --silent --show-error --fail-with-body --max-time 900 \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $api_key" \
        --data @"$result_directory/request.json" \
        "$endpoint/v1/chat/completions" >"$result_directory/response.json"
else
    curl --silent --show-error --fail-with-body --max-time 900 \
        --header 'Content-Type: application/json' \
        --data @"$result_directory/request.json" \
        "$endpoint/v1/chat/completions" >"$result_directory/response.json"
fi
request_status=$?
set -e

set +e
retain_running_process_evidence
running_evidence_status=$?
set -e
teardown_server
set +e
retain_quiescent_runtime_evidence
quiescent_evidence_status=$?
set -e

set +e
python3 - "$result_directory" "$label" "$request_status" \
    "$teardown_status" "$generate_tokens" <<'PY'
import json
import math
import os
import sys
from decimal import Decimal

directory = sys.argv[1]
label = sys.argv[2]
request_status = int(sys.argv[3])
teardown_status = int(sys.argv[4])
expected_tokens = int(sys.argv[5])


def reject_nonfinite_constant(value):
    raise ValueError(f'nonfinite JSON constant: {value}')


try:
    with open(os.path.join(directory, 'response.json')) as handle:
        document = json.load(handle, parse_constant=reject_nonfinite_constant)
except Exception as error:
    document = {}
    print(f'served_decode=unreadable label={label} error={error}',
          file=sys.stderr)

timings_value = document.get('timings')
timings = timings_value if isinstance(timings_value, dict) else {}


def is_finite_positive_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(value) and value > 0
    except OverflowError:
        return False


report = {
    'label': label,
    'request_status': request_status,
    'teardown_status': teardown_status,
    'prefill_tok_per_second': timings.get('prompt_per_second'),
    'prefill_ms': timings.get('prompt_ms'),
    'decode_tok_per_second': timings.get('predicted_per_second'),
    'decode_ms': timings.get('predicted_ms'),
    'prompt_tokens': timings.get('prompt_n'),
    'decode_tokens': timings.get('predicted_n'),
}
decode_tokens_are_exact = (
    type(report['decode_tokens']) is int
    and report['decode_tokens'] == expected_tokens
)
prompt_tokens_are_valid = (
    type(report['prompt_tokens']) is int
    and report['prompt_tokens'] > 0
)
prefill_rate_is_valid = is_finite_positive_number(
    report['prefill_tok_per_second']
)
prefill_ms_is_valid = is_finite_positive_number(report['prefill_ms'])
prefill_rate_is_consistent = False
if prompt_tokens_are_valid and prefill_ms_is_valid and prefill_rate_is_valid:
    recomputed_prefill_rate = (
        Decimal(1000)
        * Decimal(report['prompt_tokens'])
        / Decimal(str(report['prefill_ms']))
    )
    reported_prefill_rate = Decimal(str(report['prefill_tok_per_second']))
    relative_prefill_rate_error = (
        abs(reported_prefill_rate - recomputed_prefill_rate)
        / recomputed_prefill_rate
    )
    prefill_rate_is_consistent = (
        relative_prefill_rate_error <= Decimal('0.000001')
    )
decode_ms_is_valid = is_finite_positive_number(report['decode_ms'])
decode_rate_is_valid = is_finite_positive_number(
    report['decode_tok_per_second']
)
decode_rate_is_consistent = False
if decode_tokens_are_exact and decode_ms_is_valid and decode_rate_is_valid:
    recomputed_decode_rate = (
        Decimal(1000)
        * Decimal(report['decode_tokens'] - 1)
        / Decimal(str(report['decode_ms']))
    )
    reported_decode_rate = Decimal(str(report['decode_tok_per_second']))
    relative_decode_rate_error = (
        abs(reported_decode_rate - recomputed_decode_rate)
        / recomputed_decode_rate
    )
    decode_rate_is_consistent = (
        relative_decode_rate_error <= Decimal('0.000001')
    )
valid = (
    request_status == 0
    and teardown_status == 0
    and prompt_tokens_are_valid
    and prefill_ms_is_valid
    and prefill_rate_is_valid
    and prefill_rate_is_consistent
    and decode_tokens_are_exact
    and decode_ms_is_valid
    and decode_rate_is_valid
    and decode_rate_is_consistent
)
report['valid'] = valid
with open(os.path.join(directory, 'summary.json'), 'w') as handle:
    json.dump(report, handle, indent=2)
for key in sorted(report):
    print(f'{key}={report[key]}')
sys.exit(0 if valid else 1)
PY
summary_status=$?
set -e

if [ "$summary_status" -ne 0 ] || [ "$running_evidence_status" -ne 0 ] || \
   [ "$quiescent_evidence_status" -ne 0 ]; then
    printf 'served_decode=failed label=%s result_directory=%s\n' \
        "$label" "$result_directory" >&2
    exit 1
fi

printf 'served_decode=completed label=%s result_directory=%s\n' \
    "$label" "$result_directory"
