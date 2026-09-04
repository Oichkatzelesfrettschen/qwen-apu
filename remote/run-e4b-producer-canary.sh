#!/bin/sh
set -eu

# Runs one attribution-mode census arm of the E4b-A activation-summary
# producer, I1 alone, against an accepted calibration, then reads the
# producer's own dispatch cost off that arm's census through
# summarize-e4b-producer-canary.py. This script never runs on the
# workstation: it drives remote/run-raven2-vulkan-kernel-census.sh, which
# needs the laptop's RADV device, the served harness, and a calibration
# receipt evidence/raven2-vulkan-kernel-census/e4/README.md registers
# through a completed calibration campaign.
#
# usage: run-e4b-producer-canary.sh MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_CALIBRATION_RECEIPT  output directory of an accepted calibration
#                                    whose production and instrumented servers
#                                    are the two this run binds (required)
#   QWEN_CENSUS_PRODUCTION_SERVER    path of P, the same binary the calibration
#                                    receipt bound (required)
#   QWEN_CENSUS_PRODUCTION_RECEIPT   identity-check.tsv of the fixed-64
#                                    scoreboard sweep (required)
#   QWEN_CENSUS_INSTRUMENTED_SERVER  path of I1, the census build carrying
#                                    llama-vulkan-q4k-activation-sideplane.patch
#                                    with GGML_VK_Q4K_SIDEPLANE=1 armed in its
#                                    served environment (required)
#   QWEN_E4B_CANARY_PRODUCER_PIPELINE_NAME    forwarded to the summarizer's
#                                    --producer-pipeline-name, default
#                                    mul_mat_vec_q4_k_prepass_f32
#   QWEN_E4B_CANARY_Q4K_FAMILY_PREFIX         forwarded to
#                                    --q4k-family-prefix, default
#                                    mul_mat_vec_q4_k
#   QWEN_E4B_CANARY_PREDICTED_GAIN_FRACTION   forwarded to
#                                    --predicted-gain-fraction, default 0.008
#   QWEN_E4B_CANARY_FALLBACK_Q4K_INTERVAL_MS  forwarded to
#                                    --fallback-q4k-interval-ms, default 49.2
#   QWEN_E4B_CANARY_SINGLE_CONSUMER_PRODUCERS forwarded to
#                                    --single-consumer-producers, default 36
#   QWEN_CENSUS_RUNTIME_REMOTE       run-raven2-vulkan-kernel-census.sh's own
#                                    synced runtime tree, forwarded unchanged
#
# Every other QWEN_CENSUS_* variable run-raven2-vulkan-kernel-census.sh reads
# passes through this script's environment unchanged, except QWEN_CENSUS_MODE
# and QWEN_CENSUS_ARMS, which this script sets to attribution and I1 and
# refuses to have overridden, since a canary that ran a different arm list
# would read a census this script's summarizer never validated for.

if [ "$#" -ne 2 ]; then
    printf 'usage: %s MODEL_ID OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

model_id=$1
output_directory=$2
script_directory=$(cd -- "$(dirname -- "$0")" && pwd)

if [ "${QWEN_CENSUS_MODE:-attribution}" != attribution ]; then
    printf 'run-e4b-producer-canary.sh runs attribution mode alone; QWEN_CENSUS_MODE=%s\n' \
        "${QWEN_CENSUS_MODE:-}" >&2
    exit 2
fi
if [ "${QWEN_CENSUS_ARMS:-I1}" != I1 ]; then
    printf 'run-e4b-producer-canary.sh runs arm I1 alone; QWEN_CENSUS_ARMS=%s\n' \
        "${QWEN_CENSUS_ARMS:-}" >&2
    exit 2
fi

calibration_receipt=${QWEN_CENSUS_CALIBRATION_RECEIPT:-}
if [ -z "$calibration_receipt" ]; then
    printf 'QWEN_CENSUS_CALIBRATION_RECEIPT is required: an attribution arm needs the\n' >&2
    printf 'output directory of an accepted calibration binding the same two servers\n' >&2
    exit 2
fi
if [ ! -r "$calibration_receipt/terminal-state.tsv" ]; then
    printf 'refusing to start: %s carries no terminal-state.tsv\n' "$calibration_receipt" >&2
    exit 1
fi
calibration_state=$(awk -F= '$1 == "census" { print $2 }' "$calibration_receipt/terminal-state.tsv")
if [ "$calibration_state" != accepted ]; then
    printf 'refusing to start: %s terminal-state.tsv reads census=%s, not accepted\n' \
        "$calibration_receipt" "${calibration_state:-?}" >&2
    exit 1
fi

for required_var in QWEN_CENSUS_PRODUCTION_SERVER QWEN_CENSUS_PRODUCTION_RECEIPT \
    QWEN_CENSUS_INSTRUMENTED_SERVER; do
    eval "required_value=\${$required_var:-}"
    if [ -z "$required_value" ]; then
        printf '%s is required\n' "$required_var" >&2
        exit 2
    fi
done

if [ -e "$output_directory" ]; then
    printf 'refusing to start: %s already exists\n' "$output_directory" >&2
    exit 1
fi

QWEN_CENSUS_MODE=attribution
QWEN_CENSUS_ARMS=I1
export QWEN_CENSUS_MODE QWEN_CENSUS_ARMS

"$script_directory/run-raven2-vulkan-kernel-census.sh" "$model_id" "$output_directory"

arm_directory=$(find "$output_directory/arms" -maxdepth 1 -type d -name '*-I1' 2>/dev/null \
    | LC_ALL=C sort | head -n 1)
if [ -z "$arm_directory" ]; then
    printf 'the census ran but %s/arms holds no I1 arm directory\n' "$output_directory" >&2
    exit 1
fi
census_file=$arm_directory/pipeline-census.tsv
if [ ! -r "$census_file" ]; then
    printf '%s carries no pipeline-census.tsv\n' "$arm_directory" >&2
    exit 1
fi
if [ ! -r "$arm_directory/request-window.tsv" ]; then
    printf '%s carries no request-window.tsv\n' "$arm_directory" >&2
    exit 1
fi
window_begin=$(awk -F'\t' '$1 == "begin_ns" { print $2 }' "$arm_directory/request-window.tsv")
window_end=$(awk -F'\t' '$1 == "end_ns" { print $2 }' "$arm_directory/request-window.tsv")
if [ -z "$window_begin" ] || [ -z "$window_end" ]; then
    printf '%s/request-window.tsv states no begin_ns/end_ns pair\n' "$arm_directory" >&2
    exit 1
fi
if [ ! -r "$arm_directory/response.json" ]; then
    printf '%s carries no response.json\n' "$arm_directory" >&2
    exit 1
fi
expected_decode_graphs=$(python3 - "$arm_directory/response.json" <<'DECODE_GRAPHS'
import json, sys
n = json.load(open(sys.argv[1])).get("timings", {}).get("predicted_n")
print(n - 1 if isinstance(n, int) and n >= 2 else "-")
DECODE_GRAPHS
)
if [ "$expected_decode_graphs" = - ]; then
    printf '%s/response.json states no usable timings.predicted_n\n' "$arm_directory" >&2
    exit 1
fi

canary_output=$arm_directory/e4b-producer-canary.tsv
python3 "$script_directory/summarize-e4b-producer-canary.py" "$census_file" \
    --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
    --expected-decode-graphs "$expected_decode_graphs" \
    --producer-pipeline-name "${QWEN_E4B_CANARY_PRODUCER_PIPELINE_NAME:-mul_mat_vec_q4_k_prepass_f32}" \
    --q4k-family-prefix "${QWEN_E4B_CANARY_Q4K_FAMILY_PREFIX:-mul_mat_vec_q4_k}" \
    --predicted-gain-fraction "${QWEN_E4B_CANARY_PREDICTED_GAIN_FRACTION:-0.008}" \
    --fallback-q4k-interval-ms "${QWEN_E4B_CANARY_FALLBACK_Q4K_INTERVAL_MS:-49.2}" \
    --single-consumer-producers "${QWEN_E4B_CANARY_SINGLE_CONSUMER_PRODUCERS:-36}" \
    >"$canary_output"
cat "$canary_output"
printf 'e4b_producer_canary=written arm=%s output=%s\n' "$arm_directory" "$canary_output"
