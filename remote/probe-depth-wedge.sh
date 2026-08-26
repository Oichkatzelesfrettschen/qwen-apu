#!/bin/sh
set -eu

# Decide whether the compute-ring wedge at 16384 tokens indicts the served
# configuration or the harness that found it.
#
# llama-bench prefills a depth rung with its own batch defaults. The guarded
# server runs `--batch-size 128 --ubatch-size 32`, which breaks the same prefill
# into submissions two orders of magnitude smaller, and that pacing is the
# reason those settings exist. Both wedges this tree has recorded were found
# under llama-bench at its defaults, so the depth and the submission size are
# confounded and neither has been separated from the other.
#
# Arm one repeats the wedge at the harness defaults, which establishes that it
# reproduces. Arm two repeats it at the served batch settings with everything
# else held. A completion in arm two attributes the wedge to submission size and
# leaves the served depth ceiling standing; a wedge in arm two attributes it to
# the depth and puts the 24576 interactive default in question.
#
# The device recovers through a ring reset and the desktop stalls while it does,
# so each arm runs alone and the kernel line count is recorded around it.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s MODEL_PATH [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'depths come from QWEN_WEDGE_DEPTHS, default "8192 16384"\n' >&2
    exit 2
fi

model_path=$1
output_directory=${2:-"${HOME:?}/qwen-depth-wedge"}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
depths=${QWEN_WEDGE_DEPTHS:-"8192 16384"}
cache_type_k=${QWEN_CACHE_TYPE_K:-q8_0}
cache_type_v=${QWEN_CACHE_TYPE_V:-q4_0}
flash_attention=${QWEN_FLASH_ATTN:-on}

if [ ! -x "$bench" ] || [ ! -f "$model_path" ]; then
    printf 'llama-bench and the model must both exist\n' >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1 || pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'another llama process holds the device\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/wedge-summary.tsv
printf 'arm\tdepth\tbatch\tubatch\tdecode_tok_s\tstatus\tring_resets\tmclk_mhz_modal\n' \
    >"$summary"

count_reset_lines() {
    if dmesg >/dev/null 2>&1; then
        dmesg | grep -c 'ring reset\|Ring .* reset\|device wedged' || true
    else
        printf 'unavailable\n'
    fi
}

run_arm() {
    arm_depth=$1
    arm_batch=$2
    arm_ubatch=$3
    arm_label=d$arm_depth-b$arm_batch-ub$arm_ubatch
    arm_log=$output_directory/$arm_label.log
    arm_samples=$output_directory/$arm_label.clocks.tsv
    reset_before=$(count_reset_lines)

    printf 'arm_start_utc=%s label=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label"
    "$script_directory/sample-gpu-clocks.sh" "$arm_samples" &
    sampler_pid=$!
    set +e
    nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
        -ngl 99 -t 2 -r 1 -p 0 -n 32 -d "$arm_depth" \
        -b "$arm_batch" -ub "$arm_ubatch" \
        -ctk "$cache_type_k" -ctv "$cache_type_v" -fa "$flash_attention" \
        -o md >"$arm_log" 2>&1
    arm_status=$?
    set -e
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
    reset_after=$(count_reset_lines)

    if [ "$arm_status" -eq 0 ]; then
        decode=$(awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                                split($(NF - 1), parts, /[^0-9.]+/)
                                for (i = 1; i <= 3; i++) {
                                    if (parts[i] != "") { rate = parts[i]; break }
                                }
                            }
                            END { print (rate == "" ? "n/a" : rate) }' "$arm_log")
    else
        decode=n/a
    fi
    if [ "$reset_before" = unavailable ] || [ "$reset_after" = unavailable ]; then
        resets=unavailable
    else
        resets=$((reset_after - reset_before))
    fi
    modal_mclk=$(awk -F'\t' '
        { count[$1]++; samples++ }
        END {
            for (step in count) {
                if (count[step] > best) { best = count[step]; modal = step }
            }
            print (samples ? modal : "n/a")
        }' "$arm_samples")

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm_label" "$arm_depth" "$arm_batch" "$arm_ubatch" "$decode" \
        "$arm_status" "$resets" "$modal_mclk" >>"$summary"
    printf 'arm_stop_utc=%s label=%s status=%s decode=%s ring_resets=%s mclk=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$arm_status" "$decode" \
        "$resets" "$modal_mclk"

    # A wedge resets the ring and the driver needs the device quiet to finish
    # recovering; the next arm starting into a recovering device measures the
    # recovery rather than the arm.
    if [ "$resets" != unavailable ] && [ "$resets" -gt 0 ]; then
        printf 'recovery_pause_utc=%s seconds=60\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        sleep 60
    fi
}

for depth in $depths; do
    run_arm "$depth" 2048 512
    run_arm "$depth" 128 32
done

printf 'depth_wedge=completed output_directory=%s\n' "$output_directory"
cat "$summary"
