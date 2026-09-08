# shellcheck shell=sh
# A baseline arm retains launch-to-readiness, first-content latency, a completed
# streamed warmup, and repeated ordinary decode requests in one served session.
# Server decode timing excludes model load; startup can influence later cache,
# clock and thermal state. Acquisition and reader identities remain separate.
#
# This file is sourced and runs nothing. Every function reads its arguments and
# the paths they name and writes into the arm directory it is given.

# The field separator the callers split a binding on. shellcheck reads this file
# alone and sees no reader, so the assignment states its consumer here.
# shellcheck disable=SC2034  # read by run-checkpoint-baseline.sh
baseline_tab=$(printf '\t')

# The lease this campaign runs under is the caller's rather than this shell's.
# compute-state-lease.sh holds the shared Vulkan lock on descriptor 8 for the
# whole transaction and forwards QWEN_VULKAN_EXTERNAL_LEASE_PROOF, so an arm
# proves it inherited that descriptor and lets llama-server take the lock the
# campaign is not holding against it. Taking a second exclusive lock here would
# wedge the first decode pass of every arm.
#
# baseline_require_inherited_lease STATE_DIRECTORY PROOF VERIFIER
baseline_require_inherited_lease() {
    baseline_lease_state=$1
    baseline_lease_proof=$2
    baseline_lease_verifier=$3
    if [ -z "$baseline_lease_proof" ]; then
        printf 'a baseline arm runs under compute-state-lease.sh, which forwards QWEN_VULKAN_EXTERNAL_LEASE_PROOF\n' >&2
        return 1
    fi
    if [ ! -x "$baseline_lease_verifier" ]; then
        printf 'the external Vulkan lease verifier is absent: %s\n' \
            "$baseline_lease_verifier" >&2
        return 1
    fi
    baseline_lease_expected=$baseline_lease_state/vulkan-workload.lock
    baseline_lease_inherited=$(readlink -f -- "/proc/$$/fd/8" 2>/dev/null || true)
    if [ "$baseline_lease_inherited" != "$baseline_lease_expected" ]; then
        printf 'descriptor 8 names another lease: %s against %s\n' \
            "${baseline_lease_inherited:--}" "$baseline_lease_expected" >&2
        return 1
    fi
    "$baseline_lease_verifier" "$baseline_lease_proof" \
        "$baseline_lease_expected" >/dev/null || return 1
}

# baseline_launch ARM_DIRECTORY LAUNCH_SCRIPT PROFILE ENDPOINT DEADLINE_S
#
# The launch runs in a child shell that closes descriptors 8 and 9 in its own
# table: dash applies a trailing `8>&-` written on the parent side for the
# child's whole runtime, which would empty /proc/$$/fd/8 exactly while a later
# arm proves the inherited lease. The wall interval spans the launch call and
# the readiness poll together, so load_wall_ms is the whole cost of putting the
# checkpoint on the device rather than the launcher's own return.
baseline_launch() {
    baseline_arm=$1
    baseline_launch_script=$2
    baseline_profile=$3
    baseline_endpoint=$4
    baseline_deadline=$5
    python3 - "$baseline_arm" "$baseline_launch_script" "$baseline_profile" \
        "$baseline_endpoint" "$baseline_deadline" <<'PY'
import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

arm, launcher, profile, endpoint, seconds = sys.argv[1:]
begin = time.monotonic_ns()
deadline = time.monotonic() + int(seconds)
with open(f"{arm}/launch.txt", "wb") as log:
    process = subprocess.Popen([launcher, profile], stdout=log, stderr=log,
                               close_fds=True, start_new_session=True)
    try:
        status = process.wait(timeout=max(0.001, deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        raise SystemExit("launch readiness deadline expired")
    if status:
        raise SystemExit(f"launcher exited {status}")

def expired(signum, frame):
    raise TimeoutError("readiness elapsed deadline expired")

signal.signal(signal.SIGALRM, expired)
remaining = deadline - time.monotonic()
if remaining <= 0:
    raise SystemExit("readiness elapsed deadline expired")
signal.setitimer(signal.ITIMER_REAL, remaining)
while time.monotonic() < deadline:
    try:
        with urllib.request.urlopen(f"{endpoint}/health", timeout=min(2, deadline - time.monotonic())) as response:
            if response.status == 200:
                break
    except (urllib.error.URLError, TimeoutError):
        if time.monotonic() >= deadline:
            raise SystemExit("readiness elapsed deadline expired")
    time.sleep(min(0.1, max(0, deadline - time.monotonic())))
else:
    raise SystemExit("readiness elapsed deadline expired")
signal.setitimer(signal.ITIMER_REAL, 0)
ready = time.monotonic_ns()
Path(f"{arm}/load.tsv").write_text(
    f"key\tvalue\nlaunch_begin_ns\t{begin}\nhealth_ready_ns\t{ready}\n"
    f"load_wall_ms\t{(ready-begin)/1e6:.3f}\n")
PY
}

# baseline_request_body OUTPUT PROMPT PREDICT SEED STREAM
#
# One body shape serves both measurements and differs by the stream flag alone,
# so the first-token record and the decode block decode the same prompt at the
# same length under greedy sampling. `cache_prompt` is off because every repeat
# pays its own prefill, `ignore_eos` fixes the generated length the way
# `llama-bench -n` does, and `return_tokens` is what makes the reply an id array
# a later repeat is compared against. The two bodies are digested separately,
# since a run that recorded one digest would leave the streamed request's shape
# unstated.
baseline_request_body() {
    python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json
import sys

output, prompt, predict, seed, stream = sys.argv[1:6]
body = {
    "prompt": prompt,
    "n_predict": int(predict),
    "temperature": 0,
    "top_k": 1,
    "seed": int(seed),
    "ignore_eos": True,
    "cache_prompt": False,
    "return_tokens": True,
    "stream": stream == "1",
}
with open(output, "w", encoding="utf-8") as handle:
    json.dump(body, handle, separators=(",", ":"), sort_keys=True)
PY
}

# baseline_first_token ARM_DIRECTORY ENDPOINT BODY API_KEY
#
# Time to first token is the wall interval from the request leaving to the first
# streamed content delta arriving, which a non-streamed reply cannot report: its
# `prompt_ms` is prefill alone and excludes the first decode pass and the
# server's own dispatch. The stream is read chunk by chunk and the clock is
# stamped at the first event carrying content, so the value covers exactly what a
# reader of the page waits through.
baseline_first_token() {
    baseline_arm=$1
    baseline_endpoint=$2
    baseline_body=$3
    baseline_key=$4
    baseline_ttft_status=0
    python3 - "$baseline_arm" "$baseline_endpoint" "$baseline_body" \
        "$baseline_key" "${QWEN_BASELINE_REQUEST_DEADLINE_S:-900}" <<'PY' || baseline_ttft_status=$?
import json
import sys
import time
import signal
import urllib.request

arm, endpoint, body_path, api_key = sys.argv[1:5]
body = open(body_path, "rb").read()
request = urllib.request.Request(
    f"{endpoint}/completion", data=body,
    headers={"Content-Type": "application/json"},
)
if api_key:
    request.add_header("Authorization", f"Bearer {api_key}")
def expired(signum, frame):
    raise TimeoutError("streamed warmup elapsed deadline expired")

signal.signal(signal.SIGALRM, expired)
signal.setitimer(signal.ITIMER_REAL, int(sys.argv[5]))
begin = time.monotonic_ns()
first = None
terminal = None
tokens = []
with open(f"{arm}/warmup.sse", "wb") as retained:
    with urllib.request.urlopen(request, timeout=int(sys.argv[5])) as response:
        for raw in response:
            retained.write(raw)
            retained.flush()
            line = raw.decode("utf-8").strip()
            if not line.startswith("data: "):
                continue
            payload = line[len("data: "):]
            if payload == "[DONE]":
                break
            event = json.loads(payload)
            tokens.extend(event.get("tokens", []))
            if terminal is not None:
                raise SystemExit("stream carried an event after terminal completion")
            if event.get("content") and first is None:
                first = time.monotonic_ns()
            if event.get("stop") is True:
                terminal = event
end = time.monotonic_ns()
signal.setitimer(signal.ITIMER_REAL, 0)
if terminal is None or not isinstance(terminal.get("timings"), dict):
    raise SystemExit("stream ended before a completed warmup response")
expected = json.loads(body)["n_predict"]
if len(tokens) != expected or terminal["timings"].get("predicted_n") != expected:
    raise SystemExit("streamed warmup token population differs from request")
with open(f"{arm}/warmup-response.json", "w") as retained:
    json.dump(terminal, retained)
if first is None:
    sys.stderr.write("the streamed reply carried no content delta\n")
    raise SystemExit(1)
with open(f"{arm}/ttft.tsv", "w", encoding="utf-8") as handle:
    handle.write("key\tvalue\n")
    handle.write(f"request_begin_ns\t{begin}\n")
    handle.write(f"first_content_ns\t{first}\n")
    handle.write(f"response_end_ns\t{end}\nstatus\tcompleted\n")
    handle.write(f"ttft_ms\t{(first - begin) / 1_000_000:.3f}\n")
PY
    return "$baseline_ttft_status"
}

# baseline_decode_block ARM_DIRECTORY ENDPOINT BODY API_KEY REPEATS PREDICT
#
# The repeats run back to back inside one warm session, so the block measures
# steady decode rather than the load beside it. Each reply is retained whole and
# its token ids are written as one id per line; the digest over that canonical
# form is the row the summary compares repeat against repeat, and a divergent
# arm is recorded rather than aborted, since a checkpoint that answers one fixed
# request two ways is the finding this block exists to surface.
baseline_decode_block() {
    baseline_arm=$1
    baseline_endpoint=$2
    baseline_body=$3
    baseline_key=$4
    baseline_repeats=$5
    baseline_predict=$6
    mkdir -p "$baseline_arm/repeats"
    printf 'repeat\tdecode_tok_per_second\tdecode_ms\tprompt_n\tpredicted_n\ttokens_sha256\n' \
        >"$baseline_arm/decode-rows.tsv"
    baseline_repeat_index=1
    while [ "$baseline_repeat_index" -le "$baseline_repeats" ]; do
        baseline_repeat_label=$(printf '%02d' "$baseline_repeat_index")
        baseline_repeat_directory=$baseline_arm/repeats/$baseline_repeat_label
        mkdir -p "$baseline_repeat_directory"
        baseline_request_begin=$(python3 -c 'import time; print(time.monotonic_ns())')
        if [ -n "$baseline_key" ]; then
            curl --silent --show-error --fail-with-body --max-time "${QWEN_BASELINE_REQUEST_DEADLINE_S:-900}" \
                --header 'Content-Type: application/json' \
                --header "Authorization: Bearer $baseline_key" \
                --data @"$baseline_body" "$baseline_endpoint/completion" \
                >"$baseline_repeat_directory/response.json" || return 1
        else
            curl --silent --show-error --fail-with-body --max-time "${QWEN_BASELINE_REQUEST_DEADLINE_S:-900}" \
                --header 'Content-Type: application/json' \
                --data @"$baseline_body" "$baseline_endpoint/completion" \
                >"$baseline_repeat_directory/response.json" || return 1
        fi
        baseline_request_end=$(python3 -c 'import time; print(time.monotonic_ns())')
        printf 'key\tvalue\nbegin_ns\t%s\nend_ns\t%s\n' \
            "$baseline_request_begin" "$baseline_request_end" \
            >"$baseline_repeat_directory/request-time.tsv"
        # shellcheck disable=SC2154  # script_directory belongs to the sourcing runner
        python3 - "$baseline_repeat_directory" "$baseline_repeat_label" \
            "$baseline_predict" "$script_directory/summarize-checkpoint-baseline.py" \
            >>"$baseline_arm/decode-rows.tsv" <<'PY' || return 1
import hashlib
import runpy
import sys
from pathlib import Path

directory, label, predict, reader = sys.argv[1:]
functions = runpy.run_path(reader)
text, rate, elapsed, prompt_n = functions["response_values"](
    functions["read_json"](Path(directory) / "response.json"), int(predict))
Path(directory, "tokens.txt").write_text(text)
print(label, rate, elapsed, prompt_n, predict,
      hashlib.sha256(text.encode()).hexdigest(), sep="\t")
PY
        baseline_repeat_index=$((baseline_repeat_index + 1))
    done
}

# baseline_retain_runtime_evidence ARM_DIRECTORY STATE_DIRECTORY
#
# The session's own logs are the arm's device record: the graphics latency probe
# states what the frame path did under the decode block, and the kernel hazard
# watcher states whether a ring timeout, a GPU reset, a VM fault, or an
# out-of-memory kill landed inside the window. A hazard makes the arm's rate a
# measurement of a recovering device, so the arm fails on it here.
baseline_retain_runtime_evidence() {
    baseline_arm=$1
    baseline_state=$2
    for baseline_log in server.log graphics-latency.log kernel-hazards.log; do
        baseline_source=$baseline_state/$baseline_log
        if [ ! -f "$baseline_source" ] || [ -L "$baseline_source" ] || \
            [ ! -s "$baseline_source" ]; then
            printf 'served runtime log is absent, linked, or empty: %s\n' \
                "$baseline_source" >&2
            return 1
        fi
        cp -- "$baseline_source" "$baseline_arm/$baseline_log" || return 1
    done
    if grep -Ev '^hazard_pattern=' "$baseline_arm/kernel-hazards.log" | \
        grep -Eai 'ring[^[:cntrl:]]*timeout|GPU reset|amdgpu[^[:cntrl:]]*reset|VM fault|device loss|device lost|out of memory|oom-kill|^hazard_utc=' \
        >/dev/null; then
        printf 'the kernel hazard log records a terminal GPU or memory hazard\n' >&2
        return 1
    fi
    if [ -f "$baseline_state/session.status" ]; then
        cp -- "$baseline_state/session.status" "$baseline_arm/session.status" || return 1
    fi
}

# baseline_served_tuple ARM_DIRECTORY STATE_DIRECTORY
#
# The tuple a comparison rests on is the one the server actually ran, and
# qwen-capacity-policy.sh is what built it: the registry is the policy's input
# rather than its output, so a preset section, a cache override, or a validated
# depth bound would leave a registry read stating a tuple no process served.
# The session records the server pid, the argv is read from that process, and
# the six flags are projected out of it.
baseline_served_tuple() {
    baseline_arm=$1
    baseline_state=$2
    baseline_status_file=$baseline_state/session.status
    if [ ! -f "$baseline_status_file" ]; then
        printf 'the served session recorded no status file: %s\n' \
            "$baseline_status_file" >&2
        return 1
    fi
    baseline_server_pid=$(awk '{ for (field = 1; field <= NF; field++) {
        if ($field ~ /^server_pid=/) { split($field, parts, "="); print parts[2] } } }' \
        "$baseline_status_file" | tail -n 1)
    case $baseline_server_pid in
        '' | *[!0-9]*)
            printf 'the served session names no numeric server_pid: %s\n' \
                "$baseline_status_file" >&2
            return 1
            ;;
    esac
    python3 - "$baseline_server_pid" "$baseline_arm/served-tuple.tsv" <<'PY'
import sys
from pathlib import Path

pid, output = sys.argv[1:3]
argv = Path(f"/proc/{pid}/cmdline").read_bytes().decode("utf-8").split("\0")
argv = [value for value in argv if value]
flags = {
    "--ctx-size": "context",
    "--batch-size": "batch",
    "--ubatch-size": "ubatch",
    "--cache-type-k": "cache_type_k",
    "--cache-type-v": "cache_type_v",
    "--ctx-checkpoints": "ctx_checkpoints",
}
values = {name: "-" for name in flags.values()}
values["flash_attention"] = "-"
for index, entry in enumerate(argv):
    if entry in flags and index + 1 < len(argv):
        values[flags[entry]] = argv[index + 1]
    elif entry == "--flash-attn" and index + 1 < len(argv):
        values["flash_attention"] = argv[index + 1]
with open(output, "w", encoding="utf-8") as handle:
    handle.write("key\tvalue\n")
    handle.write(f"server_pid\t{pid}\n")
    for name in sorted(values):
        handle.write(f"{name}\t{values[name]}\n")
PY
}

# baseline_compare_tuple SERVED_TUPLE CONTEXT BATCH UBATCH CACHE_K CACHE_V \
#     FLASH CTX_CHECKPOINTS
#
# The seven fields the registry states and qwen-capacity-policy.sh writes into
# the single-model argv under the same spellings: `--flash-attn` carries the
# registry's own `on` or `off` and the cache types carry the registry's own
# names, so the comparison is over literals rather than over a normalization
# that would admit two readings of one field. A difference names the field, the
# served value, and the registry value, because a tuple that moved is read by
# which field moved.
baseline_compare_tuple() {
    baseline_tuple_file=$1
    shift
    baseline_tuple_mismatch=0
    baseline_tuple_names='context batch ubatch cache_type_k cache_type_v flash_attention ctx_checkpoints'
    for baseline_tuple_name in $baseline_tuple_names; do
        baseline_tuple_expected=$1
        shift
        baseline_tuple_served=$(awk -F'\t' -v name="$baseline_tuple_name" \
            '$1 == name { count++; value = $2 }
            END { if (count != 1) exit 1; print value }' "$baseline_tuple_file") || {
            printf 'the served tuple record names %s other than once: %s\n' \
                "$baseline_tuple_name" "$baseline_tuple_file" >&2
            baseline_tuple_mismatch=1
            continue
        }
        if [ "$baseline_tuple_served" != "$baseline_tuple_expected" ]; then
            printf 'the served %s is %s where the registry row states %s\n' \
                "$baseline_tuple_name" "$baseline_tuple_served" \
                "$baseline_tuple_expected" >&2
            baseline_tuple_mismatch=1
        fi
    done
    [ "$baseline_tuple_mismatch" -eq 0 ]
}

# A broker's first retained sample precedes the decode window marker.
baseline_await_sampler() {
    python3 - "$1" "$2" <<'PY'
import os
import sys
import time
from pathlib import Path

record, pid = sys.argv[1:]
deadline = time.monotonic() + 5
while time.monotonic() < deadline:
    os.kill(int(pid), 0)
    if Path(record).exists() and "telemetry_broker=sampled " in Path(record).read_text():
        raise SystemExit(0)
    time.sleep(0.02)
raise SystemExit("sampler first-sample deadline expired")
PY
}

# The process supplies the executable, placement, priority and selected variant.
baseline_process_identity() {
    python3 - "$@" <<'PY'
import hashlib
import json
import os
import re
import sys
from pathlib import Path

arm, state, server, digest, model, variant, endpoint = sys.argv[1:]
arm = Path(arm)
pid = dict(line.split("\t", 1) for line in (arm / "served-tuple.tsv").read_text().splitlines()[1:])["server_pid"]
process = Path("/proc") / pid
start = (process / "stat").read_text().rsplit(")", 1)[1].split()[19]
actual_digest = hashlib.file_digest((process / "exe").open("rb"), "sha256").hexdigest()
argv = [value for value in (process / "cmdline").read_bytes().decode().split("\0") if value]
if any(value.startswith("--spec") or value in ("--model-draft", "--mmproj") for value in argv):
    raise SystemExit("ordinary text baseline refuses speculative or projector argv")
environment = dict(entry.split("=", 1) for entry in (process / "environ").read_bytes().decode().split("\0") if "=" in entry)
# The receipt retains the serving argv with credential arguments redacted.
redacted = list(argv)
for index, value in enumerate(argv[:-1]):
    if value in ("--api-key", "--api-key-file"):
        redacted[index + 1] = "<redacted>"
(arm / "server-argv.json").write_text(json.dumps(redacted))
values = {"server_pid": pid, "process_start": start, "server_sha256": actual_digest,
          "executable": os.readlink(process / "exe"),
          "nice": str(os.getpriority(os.PRIO_PROCESS, int(pid))),
          "cpu_affinity": ",".join(str(cpu) for cpu in sorted(os.sched_getaffinity(int(pid))))}
for flag, name in (("--threads", "threads"), ("--threads-batch", "threads_batch"),
                   ("--device", "device"), ("--n-gpu-layers", "gpu_layers"),
                   ("--model", "model"), ("--parallel", "parallel"), ("--port", "port")):
    indices = [index for index, value in enumerate(argv) if value == flag]
    if len(indices) != 1 or indices[0] + 1 >= len(argv):
        raise SystemExit(f"process identity requires exactly one {flag}")
    values[name] = argv[indices[0] + 1]
selected = environment.get("GGML_VK_Q4K_VARIANT", "unobserved")
log = Path(state, "server.log").read_text(errors="replace")
observed = re.findall(r"q4k_variant=(\S+) q4k_rows=(\d+)", log)
if not observed or any(key != variant or rows != variant.split("/")[-1] for key, rows in observed):
    raise SystemExit("server log fails selected Q4_K variant admission")
values["q4k_variant"] = selected
(arm / "process-identity.tsv").write_text("key\tvalue\n" + "".join(f"{key}\t{value}\n" for key, value in values.items()))
if (actual_digest != digest or Path(server).resolve() != (process / "exe").resolve()
        or values["threads"] != "1" or values["threads_batch"] != "1"
        or values["device"] != "Vulkan0" or values["gpu_layers"] != "all"
        or values["port"] != endpoint.rsplit(":", 1)[1]
        or values["parallel"] != "1" or Path(values["model"]).resolve() != Path(model).resolve()
        or values["nice"] != "19" or selected != variant):
    raise SystemExit(f"running process differs from baseline identity: {values}; expected executable={server} digest={digest} model={model} variant={variant}")
if (process / "stat").read_text().rsplit(")", 1)[1].split()[19] != start:
    raise SystemExit("process identity changed during acquisition")
PY
}
