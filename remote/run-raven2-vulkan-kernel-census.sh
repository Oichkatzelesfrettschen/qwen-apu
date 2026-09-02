#!/bin/sh
set -eu

# The pipeline census runner: one model, one ordered list of arms, each arm a
# fixed-64 served decode through measure-served-decode.sh under the model's
# registered tuple and the low-async serving profile, which is the tuple the
# fixed-64 scoreboard measured. Four execution states are admitted by name:
# P is the promoted production server, I0 the census build with collection
# off, I1 the same census build with GGML_VK_PIPELINE_CENSUS naming the
# arm's output file, and S the same build under the serialized diagnostic
# profile with the pinned vk_perf_logger armed, which is the identity
# control: every node behind a barrier, every graph ending in a host wait,
# op names and call counts per graph retained from the logger's own print.
# QWEN_CENSUS_ARMS orders them; the default is the two calibration controls
# of evidence/raven2-vulkan-kernel-census/README.md, P I0 I0 P then
# I0 I1 I1 I0, then one S, and a census proper names I1 alone.
#
# The instrumented server is required to sit beside an artifact manifest
# declaring exactly one instrumentation pipeline-census-v2 row and exactly
# one serving_eligible no row, so the binary that measures is the diagnostic
# one and never a serving one renamed; both binaries are digested into
# arms.tsv.
#
# An I1 arm completes only when the summarizer accepts its census: the
# request window measure-served-decode.sh retained on CLOCK_MONOTONIC
# selects the graphs, the expected decode count is predicted_n - 1, and
# every overflow, unavailable query, unbound dispatch, fallback read, or
# count mismatch is terminal for the arm and therefore for the run. A clock
# sidecar samples the DPM state at 5 ms across every arm on the same clock.
#
# usage: run-raven2-vulkan-kernel-census.sh MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_PRODUCTION_SERVER    path of P (required where an arm names P)
#   QWEN_CENSUS_INSTRUMENTED_SERVER  path of I0/I1/S (required where an arm names one)
#   QWEN_CENSUS_ARMS                 space-separated arm names, default
#                                    "P I0 I0 P I0 I1 I1 I0 S"
#   QWEN_CENSUS_COOLDOWN_S           idle seconds between arms, default 30
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms
#   QWEN_CENSUS_RUNTIME_REMOTE       synced runtime tree the arms launch through,
#                                    default ~/qwen-laptop-setup/remote
#   QWEN_CENSUS_COMPILE_BOUND        admitted |delta| for a P/I0 pair, default 0.0065
#   QWEN_CENSUS_COLLECT_BOUND        admitted |delta| for an I0/I1 pair, default 0.02
#   QWEN_CENSUS_SIDECAR_PERIOD_MS    clock sidecar period, default 5

if [ "$#" -ne 2 ]; then
    printf 'usage: %s MODEL_ID OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

model_id=$1
output_directory=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_reader=$script_directory/model-registry.sh
runner=$script_directory/measure-served-decode.sh
summarizer=$script_directory/summarize-kernel-census.py
sidecar=$script_directory/sample-clock-sidecar.py
arms=${QWEN_CENSUS_ARMS:-"P I0 I0 P I0 I1 I1 I0 S"}
cooldown_s=${QWEN_CENSUS_COOLDOWN_S:-30}
production_server=${QWEN_CENSUS_PRODUCTION_SERVER:-}
instrumented_server=${QWEN_CENSUS_INSTRUMENTED_SERVER:-}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
compile_bound=${QWEN_CENSUS_COMPILE_BOUND:-0.0065}
collect_bound=${QWEN_CENSUS_COLLECT_BOUND:-0.02}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-5}
# The launch chain runs from the synced runtime tree alone, and a git
# worktree is refused at launch, so the arms launch and tear down through
# that tree while this runner and its summarizer come from wherever the
# operator checked out.
runtime_remote=${QWEN_CENSUS_RUNTIME_REMOTE:-"${HOME:?}/qwen-laptop-setup/remote"}
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    if [ ! -x "$runtime_remote/$runtime_script" ]; then
        printf 'runtime tree script is not executable: %s\n' \
            "$runtime_remote/$runtime_script" >&2
        exit 2
    fi
done

if [ -e "$output_directory" ]; then
    printf 'output directory exists and a census never appends to one: %s\n' \
        "$output_directory" >&2
    exit 2
fi

needs_production=0
needs_instrumented=0
for arm in $arms; do
    case $arm in
        P) needs_production=1 ;;
        I0 | I1 | S) needs_instrumented=1 ;;
        *)
            printf 'arm name must be P, I0, I1, or S: %s\n' "$arm" >&2
            exit 2
            ;;
    esac
done
if [ "$needs_production" = 1 ] && [ ! -x "$production_server" ]; then
    printf 'QWEN_CENSUS_PRODUCTION_SERVER must name an executable: %s\n' \
        "${production_server:--}" >&2
    exit 2
fi
if [ "$needs_instrumented" = 1 ]; then
    if [ ! -x "$instrumented_server" ]; then
        printf 'QWEN_CENSUS_INSTRUMENTED_SERVER must name an executable: %s\n' \
            "${instrumented_server:--}" >&2
        exit 2
    fi
    instrumented_manifest=$(dirname -- "$instrumented_server")/../artifact-manifest.tsv
    if [ ! -r "$instrumented_manifest" ]; then
        printf 'the instrumented server carries no artifact manifest beside it: %s\n' \
            "$instrumented_manifest" >&2
        exit 2
    fi
    # Exactly one row of each declaration: a manifest naming eligibility
    # twice is refused rather than read by its first row.
    declaration_rows=$(awk -F'\t' '
        $1 == "instrumentation" { instrumentation++; declared_instrumentation = $2 }
        $1 == "serving_eligible" { eligible++; declared_eligibility = $2 }
        END { print instrumentation + 0, eligible + 0, declared_instrumentation, declared_eligibility }' \
        "$instrumented_manifest")
    set -- $declaration_rows
    if [ "$1" -ne 1 ] || [ "$2" -ne 1 ]; then
        printf 'the instrumented manifest holds %s instrumentation rows and %s serving_eligible rows, requires exactly one of each\n' \
            "$1" "$2" >&2
        exit 2
    fi
    if [ "${3:-}" != pipeline-census-v2 ] || [ "${4:-}" != no ]; then
        printf 'the instrumented server declares instrumentation %s and serving_eligible %s; pipeline-census-v2 and no are required\n' \
            "${3:--}" "${4:--}" >&2
        exit 2
    fi
    instrumented_sha256=$(sha256sum "$instrumented_server" | cut -d ' ' -f 1)
    instrumented_bytes=$(wc -c <"$instrumented_server" | tr -d ' ')
    if ! awk -F'\t' -v bytes="$instrumented_bytes" -v digest="$instrumented_sha256" '
        $1 == "executable" && $2 == "llama-server" && $3 == bytes && $4 == digest { found++ }
        END { exit found == 1 ? 0 : 1 }' "$instrumented_manifest"; then
        printf 'the instrumented server is not the one executable its manifest describes\n' >&2
        exit 2
    fi
fi

# The tuple is the registry's own, read through the same reader the
# scoreboard campaign used.
"$registry_reader" id "$model_id" >/dev/null
model_file=$("$registry_reader" id "$model_id" model_file)
model_path=$models_directory/$model_file
context=$("$registry_reader" id "$model_id" context_default)
batch=$("$registry_reader" id "$model_id" batch)
ubatch=$("$registry_reader" id "$model_id" ubatch)
cache_k=$("$registry_reader" id "$model_id" cache_type_k)
cache_v=$("$registry_reader" id "$model_id" cache_type_v)
flash=$("$registry_reader" id "$model_id" flash_attention)
ctx_checkpoints=$("$registry_reader" ctx-checkpoint "$model_id")
checkpoint_min_step=8192
if [ ! -r "$model_path" ]; then
    printf 'model file is unreadable: %s\n' "$model_path" >&2
    exit 2
fi

# measure-served-decode.sh admits an arm only under the served execution
# contract the scoreboard campaign established: the measured host is
# hp14-dk1xxx, a structurally valid SSH session is inherited, and a proof
# file at the output root, digested into the arm environment, restates the
# surface, host, session, priority, and I/O class beside the census inputs.
host_shortname=$(hostname -s 2>/dev/null | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'the census runs on the measured host hp14-dk1xxx: observed=%s\n' \
        "${host_shortname:--}" >&2
    exit 2
fi
if ! python3 - "${SSH_CONNECTION:-}" <<'PY'
import ipaddress
import sys

fields = sys.argv[1].split()
if len(fields) != 4:
    raise SystemExit(1)
for address in (fields[0], fields[2]):
    ipaddress.ip_address(address)
for port in (fields[1], fields[3]):
    if not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise SystemExit(1)
PY
then
    printf 'the census requires a structurally valid inherited SSH session\n' >&2
    exit 2
fi
case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac

mkdir -p "$output_directory/arms"
arms_ledger=$output_directory/arms.tsv
execution_proof=$output_directory/campaign-inputs.tsv
{
    printf 'key\tvalue\n'
    printf 'schema\tfixed64-served-campaign-v2\n'
    printf 'campaign_kind\tpipeline-census\n'
    printf 'execution_surface\thp14-ssh\n'
    printf 'host_shortname\t%s\n' "$host_shortname"
    printf 'ssh_session\tpresent\n'
    printf 'server_nice\t19\n'
    printf 'server_io_class\tidle\n'
    printf 'vulkan_profile\tlow-async\n'
    printf 'model_id\t%s\n' "$model_id"
    printf 'arms\t%s\n' "$arms"
    printf 'production_server\t%s\n' "${production_server:--}"
    printf 'instrumented_server\t%s\n' "${instrumented_server:--}"
    printf 'generate_tokens\t64\n'
} >"$execution_proof"
execution_proof_sha256=$(sha256sum "$execution_proof" | cut -d ' ' -f 1)
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tstatus\n' >"$arms_ledger"
{
    printf 'model_id\t%s\nmodel_path\t%s\ncontext\t%s\nbatch\t%s\nubatch\t%s\n' \
        "$model_id" "$model_path" "$context" "$batch" "$ubatch"
    printf 'cache_k\t%s\ncache_v\t%s\nflash_attention\t%s\nctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' \
        "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
    printf 'arms\t%s\nprofile\tlow-async\ngenerate\t64\n' "$arms"
    printf 'compile_bound\t%s\ncollect_bound\t%s\nsidecar_period_ms\t%s\n' \
        "$compile_bound" "$collect_bound" "$sidecar_period_ms"
    [ -n "$production_server" ] && printf 'production_server\t%s\t%s\n' \
        "$production_server" "$(sha256sum "$production_server" | cut -d ' ' -f 1)"
    [ -n "$instrumented_server" ] && printf 'instrumented_server\t%s\t%s\n' \
        "$instrumented_server" "$(sha256sum "$instrumented_server" | cut -d ' ' -f 1)"
    printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output_directory/inputs.tsv"

# The serialized identity arm runs the instrumented server standalone under
# the diagnostic profile of the runtime tree's env wrapper with the pinned
# vk_perf_logger printing after every graph, drives the same request, and
# retains the logger's stderr. It bypasses the launch chain because the
# chain admits the serving profiles alone; it runs inside the same teardown
# window as every other arm, at the same nice level, on the same tuple.
run_serialized_identity_arm() {
    serialized_directory=$1
    serialized_port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
    printf '{"model":"qwen-apu","messages":[{"role":"user","content":"Write one paragraph about tides."}],"max_tokens":64,"temperature":0,"top_k":1,"seed":1,"ignore_eos":true,"chat_template_kwargs":{"enable_thinking":false}}' \
        >"$serialized_directory/request.json"
    env GGML_VK_PERF_LOGGER=1 GGML_VK_PERF_LOGGER_FREQUENCY=1 \
        QWEN_VULKAN_PROFILE=diagnostic \
        nice -n 19 "$runtime_remote/radv-low-priority-env.sh" \
        "$instrumented_server" \
        --model "$model_path" --host 127.0.0.1 --port "$serialized_port" \
        --device Vulkan0 --split-mode none --n-gpu-layers all \
        --override-tensor '.*=Vulkan0' --fit off --parallel 1 \
        --threads 1 --threads-batch 1 --cache-ram 0 --no-context-shift --offline \
        --ctx-checkpoints "$ctx_checkpoints" --checkpoint-min-step "$checkpoint_min_step" \
        --ctx-size "$context" --batch-size "$batch" --ubatch-size "$ubatch" \
        --flash-attn "$flash" --cache-type-k "$cache_k" --cache-type-v "$cache_v" \
        >"$serialized_directory/server.stdout" 2>"$serialized_directory/perf-logger.log" &
    serialized_pid=$!
    ready=0
    for _attempt in $(seq 1 240); do
        if curl --silent --fail "http://127.0.0.1:$serialized_port/health" >/dev/null 2>&1; then
            ready=1
            break
        fi
        if ! kill -0 "$serialized_pid" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    serialized_status=1
    if [ "$ready" = 1 ]; then
        request_begin_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
        if curl --silent --show-error --fail-with-body --max-time 900 \
            --header 'Content-Type: application/json' \
            --data @"$serialized_directory/request.json" \
            "http://127.0.0.1:$serialized_port/v1/chat/completions" \
            >"$serialized_directory/response.json" 2>"$serialized_directory/curl.stderr"; then
            serialized_status=0
        fi
        request_end_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
        printf 'key\tvalue\nclock\tCLOCK_MONOTONIC\nbegin_ns\t%s\nend_ns\t%s\nrequest_status\t%s\n' \
            "$request_begin_ns" "$request_end_ns" "$serialized_status" \
            >"$serialized_directory/request-window.tsv"
    fi
    kill -TERM "$serialized_pid" 2>/dev/null || true
    wait "$serialized_pid" 2>/dev/null || true
    return "$serialized_status"
}

slot=0
failed=0
for arm in $arms; do
    slot=$((slot + 1))
    arm_label=$(printf '%02d-%s' "$slot" "$arm")
    arm_directory=$output_directory/arms/$arm_label
    case $arm in
        P) server=$production_server ;;
        *) server=$instrumented_server ;;
    esac
    census_file=''
    if [ "$arm" = I1 ]; then
        census_file=$arm_directory/pipeline-census.tsv
    fi
    mkdir -p "$arm_directory"
    printf 'census_arm=start slot=%s arm=%s server=%s\n' "$slot" "$arm" "$server"
    python3 "$sidecar" "$arm_directory/clock-sidecar.tsv" --period-ms "$sidecar_period_ms" &
    sidecar_pid=$!
    set +e
    if [ "$arm" = S ]; then
        run_serialized_identity_arm "$arm_directory"
        runner_status=$?
    else
        env \
            QWEN_LLAMA_SERVER="$server" \
            QWEN_LAUNCH_SCRIPT="$runtime_remote/qwen-launch.sh" \
            QWEN_TEARDOWN_SCRIPT="$runtime_remote/qwen-teardown.sh" \
            QWEN_MODELS_DIRECTORY="$models_directory" \
            QWEN_RESULT_DIRECTORY="$arm_directory" \
            QWEN_CONTEXT_SIZE="$context" \
            QWEN_BATCH_SIZE="$batch" \
            QWEN_UBATCH_SIZE="$ubatch" \
            QWEN_CACHE_TYPE_K="$cache_k" \
            QWEN_CACHE_TYPE_V="$cache_v" \
            QWEN_FLASH_ATTN="$flash" \
            QWEN_CTX_CHECKPOINTS="$ctx_checkpoints" \
            QWEN_CHECKPOINT_MIN_STEP="$checkpoint_min_step" \
            QWEN_SPEC_TYPE=off \
            QWEN_BACKEND_SAMPLING=0 QWEN_SPEC_BACKEND_SAMPLING=0 \
            QWEN_ROUTER=0 QWEN_INFERENCE_CPU=0 \
            QWEN_BIND_HOST=127.0.0.1 \
            QWEN_LATENCY_MODE=observe QWEN_REQUIRE_API_KEY=0 \
            QWEN_WEB_BROKER=0 QWEN_IMAGE_SERVICE=0 \
            QWEN_VULKAN_LATENCY_PROBE="${QWEN_CENSUS_LATENCY_PROBE:-}" \
            QWEN_PIPELINE_CENSUS="$census_file" \
            QWEN_EXECUTION_SURFACE=hp14-ssh \
            QWEN_HOST_SHORTNAME="$host_shortname" \
            QWEN_SSH_SESSION=present \
            QWEN_EXECUTION_PROOF="$execution_proof" \
            QWEN_EXECUTION_PROOF_SHA256="$execution_proof_sha256" \
            QWEN_BENCH_GENERATE=64 \
            "$runner" "$arm_label" "$model_path" low-async \
            >"$arm_directory/runner.stdout" 2>"$arm_directory/runner.stderr"
        runner_status=$?
    fi
    set -e
    kill -TERM "$sidecar_pid" 2>/dev/null || true
    wait "$sidecar_pid" 2>/dev/null || true
    server_sha256=$(sha256sum "$server" | cut -d ' ' -f 1)
    predicted_n=-
    predicted_ms=-
    tok_s=-
    if [ -r "$arm_directory/response.json" ]; then
        read -r predicted_n predicted_ms tok_s <<EOF
$(python3 - "$arm_directory/response.json" <<'PY'
import json, sys
timings = json.load(open(sys.argv[1])).get("timings", {})
n = timings.get("predicted_n")
ms = timings.get("predicted_ms")
if n is None or ms is None or n < 2 or ms <= 0:
    print("- - -")
else:
    print(n, f"{ms:.3f}", f"{1000.0 * (n - 1) / ms:.3f}")
PY
)
EOF
    fi
    census_rows=-
    if [ -n "$census_file" ]; then
        census_rows=0
        if [ -r "$census_file" ]; then
            census_rows=$(grep -c '^census_dispatch' "$census_file" || true)
        fi
    elif [ "$arm" = S ]; then
        census_rows=0
        if [ -r "$arm_directory/perf-logger.log" ]; then
            census_rows=$(grep -c '^Vulkan Timings:' "$arm_directory/perf-logger.log" || true)
        fi
    fi
    status=completed
    if [ "$runner_status" -ne 0 ] || [ "$tok_s" = - ]; then
        status=failed
    elif [ "$arm" = I1 ] || [ "$arm" = S ]; then
        [ "$census_rows" -gt 0 ] || status=failed
    fi
    # The summarizer is the authority on an I1 arm: it selects the graphs by
    # the retained request window, requires predicted_n - 1 decode graphs,
    # and refuses every defect, so its exit status decides the arm.
    if [ "$arm" = I1 ] && [ "$status" = completed ]; then
        window_begin=$(awk -F'\t' '$1 == "begin_ns" { print $2 }' "$arm_directory/request-window.tsv")
        window_end=$(awk -F'\t' '$1 == "end_ns" { print $2 }' "$arm_directory/request-window.tsv")
        if ! python3 "$summarizer" "$census_file" \
            --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
            --expected-decode-graphs "$((predicted_n - 1))" --phase decode \
            >"$arm_directory/pipeline-ledger-decode.tsv" 2>"$arm_directory/summarize.stderr"; then
            status=failed
            printf 'census_summary=refused slot=%s reason=%s\n' "$slot" \
                "$(sed -n '1p' "$arm_directory/summarize.stderr")"
        fi
    fi
    [ "$status" = completed ] || failed=$((failed + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" "$server_sha256" \
        "$predicted_n" "$predicted_ms" "$tok_s" "$census_rows" "$status" >>"$arms_ledger"
    printf 'census_arm=%s slot=%s arm=%s tok_s=%s census_rows=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$census_rows"
    sleep "$cooldown_s"
done

# Paired controls, each pair reported on its own. A quadruple a b c d with
# a and d in one state and b and c in another yields two paired deltas,
# b/a - 1 and c/d - 1, and a pair is accepted only where both arms carry
# status completed and both deltas sit inside the registered bound; a fast
# inner arm never compensates a slow one through a mean.
python3 - "$arms_ledger" "$compile_bound" "$collect_bound" <<'PY' >"$output_directory/summary.tsv"
import sys
rows = [line.rstrip("\n").split("\t") for line in open(sys.argv[1])][1:]
compile_bound = float(sys.argv[2])
collect_bound = float(sys.argv[3])
arms = [(r[1], float(r[5]) if r[5] != "-" else None, r[7]) for r in rows]
print("pair\touter\tinner\tfirst_outer\tfirst_inner\tfirst_delta\tsecond_outer\tsecond_inner\tsecond_delta\tbound\tverdict")
i = 0
pair = 0
while i + 3 < len(arms):
    a, b, c, d = arms[i:i + 4]
    if a[0] == d[0] and b[0] == c[0] and a[0] != b[0]:
        pair += 1
        bound = compile_bound if {a[0], b[0]} == {"P", "I0"} else collect_bound
        complete = all(x[2] == "completed" and x[1] for x in (a, b, c, d))
        if complete:
            first = b[1] / a[1] - 1
            second = c[1] / d[1] - 1
            verdict = "accepted" if abs(first) <= bound and abs(second) <= bound else "refuted"
            print(f"{pair}\t{a[0]}\t{b[0]}\t{a[1]:.3f}\t{b[1]:.3f}\t{first:+.4f}\t{d[1]:.3f}\t{c[1]:.3f}\t{second:+.4f}\t{bound}\t{verdict}")
        else:
            print(f"{pair}\t{a[0]}\t{b[0]}\t-\t-\t-\t-\t-\t-\t{bound}\tincomplete")
        i += 4
    else:
        i += 1
PY
printf 'census=%s model=%s arms=%s failed=%s output=%s\n' \
    "$([ "$failed" -eq 0 ] && echo completed || echo failed)" \
    "$model_id" "$slot" "$failed" "$output_directory"
[ "$failed" -eq 0 ]
