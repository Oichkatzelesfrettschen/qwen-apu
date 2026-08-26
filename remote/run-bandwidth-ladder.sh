#!/bin/sh
set -eu

# Measure achieved streaming rate per checkpoint, in bytes rather than tokens.
#
# Decode reads every weight once per token, so tokens per second and streamed
# bytes per token give an achieved GB/s that is comparable across checkpoints of
# different sizes. The 2B reaches 11.95 GB/s where the 4B reaches 8.28, so the
# lower figure is not a device ceiling, and what separates them is 24 layers
# against 32 rather than any property of the memory system.
#
# Each checkpoint runs twice, once in each direction of the model order. A
# repeat of identical flags ten minutes apart already measured 4.2% of spread on
# this part, which exceeds several of the differences being resolved, so a
# single pass would let position stand in for the result.
#
# Streamed bytes come from the census rather than from the file size, because
# decode skips the multi-token-prediction block and reads a tied embedding once
# for the lookup and once for the projection.

if [ "$#" -lt 1 ]; then
    printf 'usage: %s MODEL_PATH [MODEL_PATH...]\n' "$0" >&2
    printf 'output directory comes from QWEN_BANDWIDTH_OUTPUT\n' >&2
    exit 2
fi

output_directory=${QWEN_BANDWIDTH_OUTPUT:-"${HOME:?}/qwen-bandwidth-ladder"}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
census=$script_directory/gguf-tensor-census.py
generate_tokens=${QWEN_BENCH_GENERATE:-64}
repetitions=${QWEN_BENCH_REPETITIONS:-3}

if [ ! -x "$bench" ]; then
    printf 'llama-bench is not built at %s\n' "$bench" >&2
    exit 2
fi
for model_path in "$@"; do
    if [ ! -f "$model_path" ]; then
        printf 'model file is absent: %s\n' "$model_path" >&2
        exit 2
    fi
done
if pgrep -x llama-server >/dev/null 2>&1 || pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'another llama process holds the device\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/bandwidth-summary.tsv
printf 'pass\tmodel\tstreamed_bytes\tdecode_tok_s\tachieved_gb_s\tmclk_modal\ttemp_c_max\n' \
    >"$summary"

run_model() {
    pass_label=$1
    model_path=$2
    model_name=$(basename "$model_path" .gguf)
    arm_label=$pass_label-$model_name
    arm_log=$output_directory/$arm_label.log
    arm_samples=$output_directory/$arm_label.clocks.tsv

    streamed=$(nice -n 19 python3 "$census" --skip-hash "$model_path" 2>/dev/null |
        awk -F'\t' '$1 == "streamed_bytes_per_token" { print $2 }')
    case $streamed in
        '' | *[!0-9]*)
            printf 'census reported no streamed byte count for %s\n' \
                "$model_path" >&2
            return 1
            ;;
    esac

    printf 'arm_start_utc=%s label=%s streamed_bytes=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$streamed"
    "$script_directory/sample-gpu-clocks.sh" "$arm_samples" 1 &
    sampler_pid=$!
    set +e
    nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
        -ngl 99 -t 2 -r "$repetitions" -p 0 -n "$generate_tokens" -o md \
        >"$arm_log" 2>&1
    arm_status=$?
    set -e
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true

    decode=n/a
    if [ "$arm_status" -eq 0 ]; then
        decode=$(awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                                split($(NF - 1), parts, /[^0-9.]+/)
                                for (i = 1; i <= 3; i++) {
                                    if (parts[i] != "") { rate = parts[i]; break }
                                }
                            }
                            END { print (rate == "" ? "n/a" : rate) }' "$arm_log")
    fi
    achieved=n/a
    case $decode in
        n/a) ;;
        *) achieved=$(awk -v r="$decode" -v b="$streamed" \
            'BEGIN { printf "%.2f", r * b / 1000000000 }') ;;
    esac
    clock_report=$(awk -F'\t' '
        { count[$1]++; samples++
          if ($3 + 0 > temp_max) { temp_max = $3 + 0 } }
        END {
            for (step in count) {
                if (count[step] > best) { best = count[step]; modal = step }
            }
            printf "%s\t%.1f", (samples ? modal : "n/a"), temp_max / 1000
        }' "$arm_samples")

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pass_label" "$model_name" "$streamed" \
        "$decode" "$achieved" "$clock_report" >>"$summary"
    printf 'arm_stop_utc=%s label=%s decode=%s achieved_gb_s=%s clocks=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$decode" "$achieved" \
        "$(printf '%s' "$clock_report" | tr '\t' ' ')"
}

for model_path in "$@"; do
    run_model forward "$model_path" || true
done

# The reverse pass gives every checkpoint an early slot and a late one, so a
# difference that survives both is not a position effect.
reversed=''
for model_path in "$@"; do
    reversed="$model_path${reversed:+ }$reversed"
done
for model_path in $reversed; do
    run_model reverse "$model_path" || true
done

printf 'bandwidth_ladder=completed output_directory=%s\n' "$output_directory"
cat "$summary"
