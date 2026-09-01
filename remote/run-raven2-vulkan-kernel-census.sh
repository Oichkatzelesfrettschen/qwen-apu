#!/bin/sh
set -eu

# The pipeline census runner: one model, one ordered list of arms, each arm a
# fixed-64 served decode through measure-served-decode.sh under the model's
# registered tuple and the low-async serving profile, which is the tuple the
# fixed-64 scoreboard measured. Three execution states are admitted by name:
# P is the promoted production server, I0 the census build with collection
# off, and I1 the same census build with GGML_VK_PIPELINE_CENSUS naming the
# arm's output file. QWEN_CENSUS_ARMS orders them; the default is the two
# calibration controls of evidence/raven2-vulkan-kernel-census/README.md,
# P I0 I0 P then I0 I1 I1 I0, and a census proper names I1 alone.
#
# The instrumented server is required to sit beside an artifact manifest
# declaring instrumentation pipeline-census-v1 and serving_eligible no, so
# the binary that measures is the diagnostic one and never a serving one
# renamed; both binaries are digested into arms.tsv.
#
# usage: run-raven2-vulkan-kernel-census.sh MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_PRODUCTION_SERVER    path of P (required where an arm names P)
#   QWEN_CENSUS_INSTRUMENTED_SERVER  path of I0/I1 (required where an arm names either)
#   QWEN_CENSUS_ARMS                 space-separated arm names, default
#                                    "P I0 I0 P I0 I1 I1 I0"
#   QWEN_CENSUS_COOLDOWN_S           idle seconds between arms, default 30
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms

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
arms=${QWEN_CENSUS_ARMS:-"P I0 I0 P I0 I1 I1 I0"}
cooldown_s=${QWEN_CENSUS_COOLDOWN_S:-30}
production_server=${QWEN_CENSUS_PRODUCTION_SERVER:-}
instrumented_server=${QWEN_CENSUS_INSTRUMENTED_SERVER:-}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}

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
        I0 | I1) needs_instrumented=1 ;;
        *)
            printf 'arm name must be P, I0, or I1: %s\n' "$arm" >&2
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
    declared_instrumentation=$(awk -F'\t' '$1 == "instrumentation" { print $2; exit }' \
        "$instrumented_manifest")
    declared_eligibility=$(awk -F'\t' '$1 == "serving_eligible" { print $2; exit }' \
        "$instrumented_manifest")
    if [ "$declared_instrumentation" != pipeline-census-v1 ] || \
        [ "$declared_eligibility" != no ]; then
        printf 'the instrumented server declares instrumentation %s and serving_eligible %s; pipeline-census-v1 and no are required\n' \
            "${declared_instrumentation:--}" "${declared_eligibility:--}" >&2
        exit 2
    fi
    instrumented_sha256=$(sha256sum "$instrumented_server" | cut -d ' ' -f 1)
    instrumented_bytes=$(wc -c <"$instrumented_server" | tr -d ' ')
    if ! awk -F'\t' -v bytes="$instrumented_bytes" -v digest="$instrumented_sha256" '
        $1 == "executable" && $2 == "llama-server" && $3 == bytes && $4 == digest { found = 1 }
        END { exit found ? 0 : 1 }' "$instrumented_manifest"; then
        printf 'the instrumented server is not the executable its manifest describes\n' >&2
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

mkdir -p "$output_directory/arms"
arms_ledger=$output_directory/arms.tsv
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tstatus\n' >"$arms_ledger"
{
    printf 'model_id\t%s\nmodel_path\t%s\ncontext\t%s\nbatch\t%s\nubatch\t%s\n' \
        "$model_id" "$model_path" "$context" "$batch" "$ubatch"
    printf 'cache_k\t%s\ncache_v\t%s\nflash_attention\t%s\nctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' \
        "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
    printf 'arms\t%s\nprofile\tlow-async\ngenerate\t64\n' "$arms"
    [ -n "$production_server" ] && printf 'production_server\t%s\t%s\n' \
        "$production_server" "$(sha256sum "$production_server" | cut -d ' ' -f 1)"
    [ -n "$instrumented_server" ] && printf 'instrumented_server\t%s\t%s\n' \
        "$instrumented_server" "$(sha256sum "$instrumented_server" | cut -d ' ' -f 1)"
    printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output_directory/inputs.tsv"

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
    set +e
    env \
        QWEN_LLAMA_SERVER="$server" \
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
        QWEN_BENCH_GENERATE=64 \
        "$runner" "$arm_label" "$model_path" low-async \
        >"$arm_directory/runner.stdout" 2>"$arm_directory/runner.stderr"
    runner_status=$?
    set -e
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
        if [ -r "$census_file" ]; then
            census_rows=$(grep -c '^census_dispatch' "$census_file" || true)
        else
            census_rows=0
        fi
    fi
    status=completed
    if [ "$runner_status" -ne 0 ] || [ "$tok_s" = - ]; then
        status=failed
        failed=$((failed + 1))
    elif [ "$arm" = I1 ] && [ "$census_rows" = 0 ]; then
        status=failed
        failed=$((failed + 1))
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" "$server_sha256" \
        "$predicted_n" "$predicted_ms" "$tok_s" "$census_rows" "$status" >>"$arms_ledger"
    printf 'census_arm=%s slot=%s arm=%s tok_s=%s census_rows=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$census_rows"
    if [ -n "$census_file" ] && [ -r "$census_file" ] && [ "$status" = completed ]; then
        python3 "$summarizer" "$census_file" --phase decode \
            >"$arm_directory/pipeline-ledger-decode.tsv" 2>"$arm_directory/summarize.stderr" || \
            printf 'census_summary=failed slot=%s see %s\n' "$slot" "$arm_directory/summarize.stderr"
    fi
    sleep "$cooldown_s"
done

# Paired controls: consecutive arms of one state against the arms around
# them, as the design registers. Each pair reports the ratio of the inner
# mean to the outer mean; a spread the reader compares against the class's
# scoreboard span.
python3 - "$arms_ledger" <<'PY' >"$output_directory/summary.tsv"
import sys
rows = [line.rstrip("\n").split("\t") for line in open(sys.argv[1])][1:]
arms = [(r[1], float(r[5]) if r[5] != "-" else None, r[7]) for r in rows]
print("pair\touter\tinner\touter_mean\tinner_mean\tinner_over_outer")
i = 0
while i + 3 < len(arms):
    a, b, c, d = arms[i:i + 4]
    if a[0] == d[0] and b[0] == c[0] and a[0] != b[0] and all(x[1] for x in (a, b, c, d)):
        outer = (a[1] + d[1]) / 2
        inner = (b[1] + c[1]) / 2
        print(f"{i // 4 + 1}\t{a[0]}\t{b[0]}\t{outer:.3f}\t{inner:.3f}\t{inner / outer:.4f}")
        i += 4
    else:
        i += 1
PY
printf 'census=%s model=%s arms=%s failed=%s output=%s\n' \
    "$([ "$failed" -eq 0 ] && echo completed || echo failed)" \
    "$model_id" "$slot" "$failed" "$output_directory"
[ "$failed" -eq 0 ]
