#!/bin/sh
set -eu

# Separate the served KV cache policy into the two mechanisms it changes. The
# served path runs `--flash-attn on --cache-type-k q8_0 --cache-type-v q4_0`
# while llama-bench defaults to an f16 cache, so a rate measured under one and
# compared against the other confounds cache traffic, the attention kernel, and
# the harness. This crosses cache type against flash attention inside one
# harness at one depth at a time, which leaves the harness as the only residual
# and names it rather than absorbing it.
#
# Each cell is its own invocation. A quantized V cache is refused on backends
# without a flash-attention path, and an oversized attention submission timed
# the amdgpu compute ring out once already, so a cell that fails costs one cell
# rather than the run. The compute-ring reset counter is sampled around every
# cell, so a recovered wedge is recorded next to the arm that caused it rather
# than inferred later from the journal.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s MODEL_PATH [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'depths come from QWEN_FACTORIAL_DEPTHS, default "0 4096 16384 24000"\n' >&2
    exit 2
fi

model_path=$1
output_directory=${2:-"${HOME:?}/qwen-kv-cache-factorial"}
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
depths=${QWEN_FACTORIAL_DEPTHS:-"0 4096 16384"}
generate_tokens=${QWEN_BENCH_GENERATE:-64}
# A rung reprocesses its whole prefix before each repetition, so at 23 tok/s of
# prefill a 16384 rung costs 12 minutes per repetition against 21 seconds of
# generation. Depth 0 repeats three times and every deeper rung once, and the
# summary records which, because a single-repetition rate carries no spread.
shallow_repetitions=${QWEN_BENCH_REPETITIONS:-3}
deep_repetitions=${QWEN_BENCH_DEEP_REPETITIONS:-1}

if [ ! -x "$bench" ]; then
    printf 'llama-bench is not built at %s\n' "$bench" >&2
    exit 2
fi
if [ ! -f "$model_path" ]; then
    printf 'model file is absent: %s\n' "$model_path" >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'a llama-server is running and would contend for the device\n' >&2
    exit 2
fi
for depth in $depths; do
    case $depth in
        '' | *[!0-9]*)
            printf 'depth must be a non-negative integer: %s\n' "$depth" >&2
            exit 2
            ;;
    esac
done

mkdir -p "$output_directory"
summary=$output_directory/factorial-summary.tsv
printf 'depth\tcache_type_k\tcache_type_v\tflash_attn\trepetitions\tdecode_tok_s\tstatus\tring_resets\n' \
    >"$summary"

# amdgpu logs one line per ring reset and this kernel leaves dmesg readable at
# `kernel.dmesg_restrict=0`, so counting those lines around a cell separates an
# arm that wedged the ring and recovered from one that merely failed to launch.
# The sysfs `reset_count` attribute this would otherwise read is absent on this
# kernel.
read_reset_count() {
    if dmesg >/dev/null 2>&1; then
        dmesg | grep -c 'ring reset\|ring_reset\|Ring .* reset\|device wedged' || true
    else
        printf 'unavailable\n'
    fi
}

run_cell() {
    cell_depth=$1
    cell_type_k=$2
    cell_type_v=$3
    cell_flash=$4
    if [ "$cell_depth" -eq 0 ]; then
        cell_repetitions=$shallow_repetitions
    else
        cell_repetitions=$deep_repetitions
    fi
    cell_label=d$cell_depth-k$cell_type_k-v$cell_type_v-fa$cell_flash
    cell_log=$output_directory/$cell_label.log
    reset_before=$(read_reset_count)

    printf 'cell_start_utc=%s label=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$cell_label"
    set +e
    nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
        -ngl 99 -t 2 -r "$cell_repetitions" -p 0 -n "$generate_tokens" \
        -d "$cell_depth" -ctk "$cell_type_k" -ctv "$cell_type_v" \
        -fa "$cell_flash" -o md >"$cell_log" 2>&1
    cell_status=$?
    set -e
    reset_after=$(read_reset_count)

    if [ "$cell_status" -eq 0 ]; then
        # The markdown row carries the rate in its second-to-last column as
        # `value +/- error`, so the first field of that column is the rate and
        # the second is its spread. Stripping every non-digit joins the two into
        # one number that looks like a rate and is not one.
        decode=$(awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                                split($(NF - 1), parts, /[^0-9.]+/)
                                for (i = 1; i <= 3; i++) {
                                    if (parts[i] != "") { rate = parts[i]; break }
                                }
                                spread = parts[i + 1]
                            }
                            END {
                                if (rate == "") { print "n/a" }
                                else { printf "%s+/-%s\n", rate, (spread == "" ? "0" : spread) }
                            }' "$cell_log")
    else
        decode=n/a
    fi
    if [ "$reset_before" = unavailable ] || [ "$reset_after" = unavailable ]; then
        resets=unavailable
    else
        resets=$((reset_after - reset_before))
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell_depth" "$cell_type_k" "$cell_type_v" "$cell_flash" \
        "$cell_repetitions" "$decode" "$cell_status" "$resets" >>"$summary"
    printf 'cell_stop_utc=%s label=%s status=%s decode=%s ring_resets=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$cell_label" "$cell_status" \
        "$decode" "$resets"
}

# The quantized cells run before the f16 cells at every depth. f16 holds the
# most cache bytes and produced the one measured ring timeout, so the ordering
# puts the cells most likely to complete ahead of the cell most likely to stall
# the desktop.
for depth in $depths; do
    run_cell "$depth" q8_0 q4_0 on
    run_cell "$depth" q8_0 q4_0 off
    run_cell "$depth" q8_0 f16 off
    run_cell "$depth" f16 f16 on
    run_cell "$depth" f16 f16 off
done

printf 'kv_cache_factorial=completed output_directory=%s\n' "$output_directory"
cat "$summary"
