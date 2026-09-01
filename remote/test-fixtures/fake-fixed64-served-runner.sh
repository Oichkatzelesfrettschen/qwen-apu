#!/bin/sh
set -eu

# Supply one deterministic served-decode arm without starting a server, model,
# GPU, or remote workload. Test controls live beside the campaign output under
# OUTPUT_DIRECTORY.control, so the production runner can launch this fixture
# through an empty environment without admitting ambient test variables.

if [ "$#" -ne 3 ]; then
    printf 'usage: %s LABEL MODEL_PATH PROFILE\n' "$0" >&2
    exit 2
fi

label=$1
model_path=$2
profile=$3
result_directory=${QWEN_RESULT_DIRECTORY:?}
campaign_directory=$(dirname -- "$(dirname -- "$result_directory")")
control_directory=$campaign_directory.control
slot=${label%%-*}

read_control() {
    control_name=$1
    control_default=$2
    control_path=$control_directory/$control_name
    if [ -r "$control_path" ]; then
        sed -n '1p' "$control_path"
    else
        printf '%s\n' "$control_default"
    fi
}

mkdir -p -- "$control_directory"
printf '%s\t%s\t%s\t%s\n' "$slot" "$label" "$model_path" "$profile" \
    >>"$control_directory/invocations.tsv"
mkdir -- "$result_directory"

signal_child_pid=''
finish_teardown() {
    if [ -n "$signal_child_pid" ]; then
        kill "$signal_child_pid" 2>/dev/null || true
        wait "$signal_child_pid" 2>/dev/null || true
        signal_child_pid=''
    fi
    printf 'fake teardown\n' >"$result_directory/teardown.txt"
    printf 'completed\n' >"$control_directory/teardown-$slot"
}
terminate_runner() {
    signal_status=$1
    trap - HUP INT TERM
    if [ "$(read_control signal-teardown-fail-slot '')" = "$slot" ]; then
        trap - EXIT
        printf 'fake signal teardown failure at slot %s\n' "$slot" >&2
        exit "$signal_status"
    fi
    exit "$signal_status"
}
trap finish_teardown EXIT
trap 'terminate_runner 129' HUP
trap 'terminate_runner 130' INT
trap 'terminate_runner 143' TERM

printf 'label=%s\nmodel=%s\nprofile=%s\ncache_type_k=%s\ncache_type_v=%s\nflash_attention=%s\nctx_checkpoints=%s\ncheckpoint_min_step=%s\ngenerate_tokens=%s\n' \
    "$label" "$model_path" "$profile" "${QWEN_CACHE_TYPE_K:?}" \
    "${QWEN_CACHE_TYPE_V:?}" "${QWEN_FLASH_ATTN:?}" \
    "${QWEN_CTX_CHECKPOINTS:?}" "${QWEN_CHECKPOINT_MIN_STEP:?}" \
    "${QWEN_BENCH_GENERATE:?}" >"$result_directory/inputs.txt"
printf 'fake launch model=%s context=%s batch=%s ubatch=%s\n' "$model_path" \
    "${QWEN_CONTEXT_SIZE:?}" "${QWEN_BATCH_SIZE:?}" \
    "${QWEN_UBATCH_SIZE:?}" >"$result_directory/launch.txt"
printf 'state=running server_pid=1234 monitor_pid=1235 latency_watchdog_pid=1236 kernel_hazard_watchdog_pid=1237 profile=%s host=127.0.0.1 port=8080 context=%s latency_mode=observe utc=2026-09-01T00:00:00Z\n' \
    "$profile" "$QWEN_CONTEXT_SIZE" >"$result_directory/session.status"
printf 'speculation spec_type=%s draft_backend_sampling=%s backend_sampling=%s\n' \
    "${QWEN_SPEC_TYPE:-off}" "${QWEN_SPEC_BACKEND_SAMPLING:?}" \
    "${QWEN_BACKEND_SAMPLING:?}" >>"$result_directory/session.status"
printf 'cache cache_type_k=%s cache_type_v=%s flash_attention=%s\n' \
    "$QWEN_CACHE_TYPE_K" "$QWEN_CACHE_TYPE_V" "$QWEN_FLASH_ATTN" \
    >>"$result_directory/session.status"
printf 'router enabled=%s\n' "$QWEN_ROUTER" >>"$result_directory/session.status"

static_path=$campaign_directory/configuration/runtime-source/remote/../webui
python3 - "$model_path" "$QWEN_LLAMA_SERVER" "$static_path" \
    "$QWEN_MODEL_ARTIFACTS" "$QWEN_MODELS_DIRECTORY" \
    "$QWEN_EXECUTION_SURFACE" "$QWEN_HOST_SHORTNAME" "$QWEN_SSH_SESSION" \
    "$QWEN_CHECKPOINT_MIN_STEP" "$QWEN_CTX_CHECKPOINTS" \
    "$QWEN_CONTEXT_SIZE" "$QWEN_BATCH_SIZE" "$QWEN_UBATCH_SIZE" \
    "$QWEN_FLASH_ATTN" "$QWEN_CACHE_TYPE_K" "$QWEN_CACHE_TYPE_V" \
    "$result_directory/runtime-inputs.json" \
    "$result_directory/server-process.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

(
    model_text,
    server_text,
    static_text,
    artifact_ledger_text,
    models_directory_text,
    execution_surface,
    host_shortname,
    ssh_session,
    checkpoint_min_step,
    ctx_checkpoints,
    context_size,
    batch_size,
    ubatch_size,
    flash_attention,
    cache_type_k,
    cache_type_v,
    runtime_inputs_text,
    server_process_text,
) = sys.argv[1:]


def file_identity(path):
    status = path.stat()
    return {
        "path": str(path.resolve(strict=True)),
        "device": status.st_dev,
        "inode": status.st_ino,
        "bytes": status.st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


model_path = Path(model_text)
server_path = Path(server_text)
models_directory = Path(models_directory_text).resolve(strict=True)
model_identity = file_identity(model_path)
model_file = Path(model_identity["path"]).relative_to(models_directory).as_posix()
artifact_rows = [
    line.split("\t")
    for line in Path(artifact_ledger_text).read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#") and line.split("\t")[1] == model_file
]
if len(artifact_rows) != 1:
    raise SystemExit(f"fake runner found {len(artifact_rows)} rows for {model_file}")
runner_pid = 4321
model_identity.update(
    {
        "descriptor_path": f"/proc/{runner_pid}/fd/7",
        "artifact_model_id": artifact_rows[0][0],
        "artifact_model_file": model_file,
    }
)
server_identity = file_identity(server_path)
server_identity["descriptor_path"] = f"/proc/{runner_pid}/fd/6"
runtime_inputs = {
    "schema": "served-runtime-inputs-v1",
    "model": model_identity,
    "executable": server_identity,
}
Path(runtime_inputs_text).write_text(
    json.dumps(runtime_inputs, indent=2) + "\n", encoding="utf-8"
)

server_process = {
    "schema": "served-decode-process-v3",
    "execution_surface": execution_surface,
    "host_shortname": host_shortname,
    "ssh_session": ssh_session,
    "pid": 1234,
    "start_time_ticks": 5678,
    "executable": server_identity["path"],
    "executable_proc_link": server_identity["path"],
    "executable_device": server_identity["device"],
    "executable_inode": server_identity["inode"],
    "executable_bytes": server_identity["bytes"],
    "executable_sha256": server_identity["sha256"],
    "argv": [
        server_identity["path"],
        "--model",
        model_identity["descriptor_path"],
        "--host",
        "127.0.0.1",
        "--port",
        "8080",
        "--alias",
        "qwen-apu",
        "--cors-origins",
        "localhost",
        "--path",
        static_text,
        "--ui",
        "--log-verbosity",
        "4",
        "--device",
        "Vulkan0",
        "--split-mode",
        "none",
        "--n-gpu-layers",
        "all",
        "--override-tensor",
        ".*=Vulkan0",
        "--fit",
        "off",
        "--parallel",
        "1",
        "--threads",
        "1",
        "--threads-batch",
        "1",
        "--cache-ram",
        "0",
        "--no-context-shift",
        "--offline",
        "--checkpoint-min-step",
        checkpoint_min_step,
        "--ctx-checkpoints",
        ctx_checkpoints,
        "--ctx-size",
        context_size,
        "--batch-size",
        batch_size,
        "--ubatch-size",
        ubatch_size,
        "--flash-attn",
        flash_attention,
        "--cache-type-k",
        cache_type_k,
        "--cache-type-v",
        cache_type_v,
    ],
    "nice": 19,
    "cpus_allowed_list": "0",
    "io_class": "idle",
}
Path(server_process_text).write_text(
    json.dumps(server_process, indent=2) + "\n", encoding="utf-8"
)
PY

printf 'fake server log\n' >"$result_directory/server.log"
printf 'fake telemetry log\n' >"$result_directory/telemetry.log"
printf 'fake graphics latency log\n' >"$result_directory/graphics-latency.log"
printf 'fake kernel hazard log\n' >"$result_directory/kernel-hazards.log"
printf 'QWEN_ROUTER=%s\nQWEN_SPEC_TYPE=%s\nQWEN_MMPROJ=%s\nQWEN_SERVER_PORT=%s\nQWEN_BIND_HOST=%s\nQWEN_READY_ATTEMPTS=%s\nGGML_VK_MAX_NODES_PER_SUBMIT=%s\nGGML_VK_SERIALIZE_SUBMISSIONS=%s\nGGML_VK_SUBMIT_TRACE=%s\nGGML_VK_DUTY_CYCLE_PERCENT=%s\n' \
    "${QWEN_ROUTER-unset}" "${QWEN_SPEC_TYPE-unset}" \
    "${QWEN_MMPROJ-unset}" "${QWEN_SERVER_PORT-unset}" \
    "${QWEN_BIND_HOST-unset}" "${QWEN_READY_ATTEMPTS-unset}" \
    "${GGML_VK_MAX_NODES_PER_SUBMIT-unset}" \
    "${GGML_VK_SERIALIZE_SUBMISSIONS-unset}" \
    "${GGML_VK_SUBMIT_TRACE-unset}" \
    "${GGML_VK_DUTY_CYCLE_PERCENT-unset}" \
    >"$result_directory/environment.txt"

failure_slot=$(read_control fail-slot '')
if [ "$failure_slot" = "$slot" ]; then
    printf 'fake runner failure at slot %s\n' "$slot" >&2
    exit 37
fi

case $model_path in
    *Qwen3.5-0.8B*) rate=21; predicted_ms=3000 ;;
    *Qwen3.8-2B*) rate=10.5; predicted_ms=6000 ;;
    *Qwen3.8-4B*) rate=5.25; predicted_ms=12000 ;;
    *) printf 'unknown fake model: %s\n' "$model_path" >&2; exit 2 ;;
esac
if [ "$(read_control target-miss 0)" = 1 ] && [ "$rate" = 5.25 ]; then
    rate=5
    predicted_ms=12600
fi
predicted_n=64
if [ "$(read_control short-slot '')" = "$slot" ]; then
    predicted_n=63
fi
reported_rate=$rate
if [ "$(read_control divergent-rate-slot '')" = "$slot" ]; then
    reported_rate=99
fi
printf '{"timings":{"prompt_n":12,"prompt_ms":120,"prompt_per_second":100,"predicted_n":%s,"predicted_ms":%s,"predicted_per_second":%s}}\n' \
    "$predicted_n" "$predicted_ms" "$reported_rate" \
    >"$result_directory/response.json"
printf '{"label":"%s","request_status":0,"teardown_status":0,"prefill_tok_per_second":100,"prefill_ms":120,"decode_tok_per_second":%s,"decode_ms":%s,"prompt_tokens":12,"decode_tokens":%s,"valid":true}\n' \
    "$label" "$reported_rate" "$predicted_ms" "$predicted_n" \
    >"$result_directory/summary.json"
printf '%s' '{"model":"qwen-apu","messages":[{"role":"user","content":"Write one paragraph about tides."}],"max_tokens":64,"temperature":0,"top_k":1,"seed":1,"ignore_eos":true,"chat_template_kwargs":{"enable_thinking":false}}' \
    >"$result_directory/request.json"

if [ "$(read_control teardown-fail-slot '')" = "$slot" ]; then
    printf 'fake teardown failure at slot %s\n' "$slot" >&2
    exit 38
fi
if [ "$(read_control mutate-request-slot '')" = "$slot" ]; then
    printf '\n' >>"$result_directory/request.json"
fi
if [ "$(read_control mutate-slot '')" = "$slot" ]; then
    mutate_path=$(read_control mutate-path '')
    if [ -z "$mutate_path" ]; then
        printf 'mutate-path is required for slot %s\n' "$slot" >&2
        exit 2
    fi
    printf 'mutated\n' >>"$mutate_path"
fi
if [ "$(read_control missing-log-slot '')" = "$slot" ]; then
    rm -f -- "$result_directory/kernel-hazards.log"
fi
if [ "$(read_control runner-sigkill-slot '')" = "$slot" ]; then
    runner_start_time=$(sed 's/^.*) //' "/proc/$$/stat" | awk '{ print $20 }')
    runner_process_group=$(ps -o pgid= -p "$$" | tr -d ' ')
    runner_session=$(ps -o sid= -p "$$" | tr -d ' ')
    printf 'pid\tstart_time_ticks\tprocess_group\tsession_id\n%s\t%s\t%s\t%s\n' \
        "$$" "$runner_start_time" "$runner_process_group" "$runner_session" \
        >"$control_directory/runner-sigkill-runner-$slot.tsv"

    detached_workload=$control_directory/detached-workload-$slot.tsv
    detached_term=$control_directory/detached-workload-term-$slot.tsv
    python3 - "$detached_workload" "$detached_term" "$$" <<'PY' 8>&- 9>&- &
import os
import signal
import sys
from pathlib import Path

witness_path = Path(sys.argv[1])
term_path = Path(sys.argv[2])
expected_parent = int(sys.argv[3])

os.setsid()


def start_time_ticks() -> int:
    stat_text = Path("/proc/self/stat").read_text(encoding="ascii")
    command_end = stat_text.rfind(")")
    return int(stat_text[command_end + 2 :].split()[19])


def write_atomic(path: Path, contents: str) -> None:
    temporary_path = path.with_name(f".{path.name}.{os.getpid()}.new")
    temporary_path.write_text(contents, encoding="utf-8")
    os.replace(temporary_path, path)


workload_start_time = start_time_ticks()
if os.getppid() != expected_parent:
    raise SystemExit("detached workload parent changed before readiness")
for descriptor in (8, 9):
    try:
        os.fstat(descriptor)
    except OSError:
        continue
    raise SystemExit(f"detached workload inherited descriptor {descriptor}")


def terminate_workload(received_signal: int, _frame: object) -> None:
    signal_name = signal.Signals(received_signal).name
    write_atomic(
        term_path,
        "pid\tstart_time_ticks\tsignal\tstate\n"
        f"{os.getpid()}\t{workload_start_time}\t{signal_name}\tobserved\n",
    )
    raise SystemExit(0)


signal.signal(signal.SIGTERM, terminate_workload)
signal.signal(signal.SIGINT, terminate_workload)
signal.signal(signal.SIGHUP, terminate_workload)
write_atomic(
    witness_path,
    "pid\tstart_time_ticks\tparent_pid\tprocess_group\tsession_id\tfd8_state\tfd9_state\n"
    f"{os.getpid()}\t{workload_start_time}\t{os.getppid()}\t"
    f"{os.getpgrp()}\t{os.getsid(0)}\tclosed\tclosed\n",
)
while True:
    signal.pause()
PY
    signal_child_pid=$!
    sigkill_ready_wait=0
    while [ ! -s "$detached_workload" ] && [ "$sigkill_ready_wait" -lt 250 ]; do
        sleep 0.02
        sigkill_ready_wait=$((sigkill_ready_wait + 1))
    done
    if [ ! -s "$detached_workload" ]; then
        printf 'detached workload did not publish readiness for slot %s\n' \
            "$slot" >&2
        exit 2
    fi
    printf 'ready\n' >"$control_directory/runner-sigkill-ready-$slot"
    wait "$signal_child_pid"
    signal_child_pid=''
fi
if [ "$(read_control delay-slot '')" = "$slot" ]; then
    printf '%s\n' "$$" >"$control_directory/runner.pid"
    sleep "$(read_control delay-seconds 2)" &
    signal_child_pid=$!
    printf '%s\n' "$signal_child_pid" >"$control_directory/descendant.pid"
    wait "$signal_child_pid"
    signal_child_pid=''
fi

printf 'fake_served_decode=completed label=%s\n' "$label"
