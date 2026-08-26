#!/bin/sh
set -eu

# Separate the compute-ring wedge at 16384 tokens into depth and submission
# geometry, and record what each arm did to the device.
#
# llama-bench prefills a depth rung with its own batch defaults. The guarded
# server runs `--batch-size 128 --ubatch-size 32`, which breaks the same prefill
# into submissions two orders of magnitude smaller, and that pacing is the
# reason those settings exist. Both wedges this tree has recorded were found
# under llama-bench at its defaults, so depth and submission size are confounded
# and neither has been separated from the other.
#
# Three geometries per depth resolve the direction. The harness default
# establishes that the wedge reproduces. The served geometry decides whether the
# shipped configuration is exposed. A geometry below the served one decides
# which way to move if it is: a pass there attributes the wedge to submission
# size and leaves depth viable, while a wedge there indicts the graph at that
# depth under every practical geometry and the admitted ceiling comes down.
#
# A configured context allocation is not a validated depth. A server that loads
# a 24576-token allocation has proven it can reserve the memory; it has not
# proven a near-full cache executes. What this probe measures is the filled and
# decoded depth, which is the capability the registry ceiling claims.
#
# Each arm ends with a shallow control at the served geometry. A ring reset that
# recovers leaves the control passing, and the wedge is one rejected graph; a
# control that fails establishes persistent device corruption instead, and the
# probe stops rather than measuring a broken device.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s MODEL_PATH [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'depths from QWEN_WEDGE_DEPTHS, default "8192 16384"\n' >&2
    printf 'geometries from QWEN_WEDGE_GEOMETRIES as batch:ubatch pairs,\n' >&2
    printf 'default "2048:512 128:32 32:8"\n' >&2
    exit 2
fi

model_path=$1
output_directory=${2:-"${HOME:?}/qwen-depth-wedge"}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
clock_sampler=${QWEN_CLOCK_SAMPLER:-"$script_directory/sample-gpu-clocks.sh"}
depths=${QWEN_WEDGE_DEPTHS:-"8192 16384"}
geometries=${QWEN_WEDGE_GEOMETRIES:-"2048:512 128:32 32:8"}
cache_type_k=${QWEN_CACHE_TYPE_K:-q8_0}
cache_type_v=${QWEN_CACHE_TYPE_V:-q4_0}
flash_attention=${QWEN_FLASH_ATTN:-on}
control_tokens=${QWEN_WEDGE_CONTROL_TOKENS:-16}

if [ ! -x "$bench" ] || [ ! -f "$model_path" ]; then
    printf 'llama-bench and the model must both exist\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/wedge-summary.tsv
printf 'arm\tdepth\tbatch\tubatch\tcache_k\tcache_v\tflash_attn\tstatus\tring_resets\tgpu_faults\twall_s\tdecode_tok_s\tvram_peak_mib\tgtt_peak_mib\tcontrol_status\tcontrol_tok_s\tmclk_modal\ttemp_c_max\n' \
    >"$summary"

# A killed run leaves its sampler writing once a second into a file the next run
# recreates, which contaminates that run and hides the orphan behind a plausible
# name. The trap ends the sampler with the script that started it.
sampler_pid=''
stop_sampler() {
    [ -n "$sampler_pid" ] || return 0
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
    sampler_pid=''
}
trap 'stop_sampler' EXIT
trap 'stop_sampler; exit 130' INT
trap 'stop_sampler; exit 143' TERM

kernel_line_count() {
    if dmesg >/dev/null 2>&1; then
        dmesg | wc -l
    else
        printf 'unavailable\n'
    fi
}

# The lines the kernel emitted during one arm, retained verbatim. The ring
# reset count and the fault count are grepped from these rather than from the
# whole buffer, so a reset that predates the probe stays out of the delta.
kernel_delta_lines() {
    delta_before=$1
    delta_file=$2
    [ "$delta_before" != unavailable ] || return 0
    dmesg | tail -n "+$((delta_before + 1))" >"$delta_file" 2>/dev/null || true
}

parse_decode_rate() {
    awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                   split($(NF - 1), parts, /[^0-9.]+/)
                   for (i = 1; i <= 3; i++) {
                       if (parts[i] != "") { rate = parts[i]; break }
                   }
               }
               END { print (rate == "" ? "n/a" : rate) }' "$1"
}

run_bench() {
    bench_log=$1
    bench_depth=$2
    bench_batch=$3
    bench_ubatch=$4
    bench_tokens=$5
    set +e
    if [ "$bench_depth" -eq 0 ]; then
        nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
            -ngl 99 -t 2 -r 1 -p 0 -n "$bench_tokens" \
            -b "$bench_batch" -ub "$bench_ubatch" \
            -ctk "$cache_type_k" -ctv "$cache_type_v" -fa "$flash_attention" \
            -o md >"$bench_log" 2>&1
    else
        nice -n 19 ionice -c 3 "$bench" -m "$model_path" \
            -ngl 99 -t 2 -r 1 -p 0 -n "$bench_tokens" -d "$bench_depth" \
            -b "$bench_batch" -ub "$bench_ubatch" \
            -ctk "$cache_type_k" -ctv "$cache_type_v" -fa "$flash_attention" \
            -o md >"$bench_log" 2>&1
    fi
    bench_status=$?
    set -e
    return "$bench_status"
}

device_corrupt=0

run_arm() {
    arm_depth=$1
    arm_batch=$2
    arm_ubatch=$3
    arm_label=d$arm_depth-b$arm_batch-ub$arm_ubatch
    arm_log=$output_directory/$arm_label.log
    arm_samples=$output_directory/$arm_label.clocks.tsv
    arm_kernel=$output_directory/$arm_label.dmesg.txt
    control_log=$output_directory/$arm_label.control.log
    kernel_before=$(kernel_line_count)
    arm_started=$(date +%s)

    printf 'arm_start_utc=%s label=%s cache=%s/%s fa=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$cache_type_k" \
        "$cache_type_v" "$flash_attention"
    "$clock_sampler" "$arm_samples" &
    sampler_pid=$!
    set +e
    run_bench "$arm_log" "$arm_depth" "$arm_batch" "$arm_ubatch" 32
    arm_status=$?
    set -e
    stop_sampler
    arm_wall=$(($(date +%s) - arm_started))
    kernel_delta_lines "$kernel_before" "$arm_kernel"

    resets=unavailable
    faults=unavailable
    if [ -f "$arm_kernel" ]; then
        resets=$(grep -c 'ring reset\|Ring .* reset\|device wedged\|GPU reset' \
            "$arm_kernel" || true)
        faults=$(grep -c 'page fault\|VM_L2_PROTECTION_FAULT\|PROTECTION_FAULT' \
            "$arm_kernel" || true)
    fi

    decode=n/a
    [ "$arm_status" -ne 0 ] || decode=$(parse_decode_rate "$arm_log")

    # The memory the arm actually held, read from amdgpu's accounting during the
    # arm rather than parsed from the log: llama-bench prints no buffer sizes at
    # default verbosity, and an arm that wedges prints nothing at all. The peak
    # of each is reported because the KV cache grows through the prefill.
    memory_report=$(awk -F'\t' '
        $5 ~ /^[0-9]+$/ {
          if ($5 + 0 > vram_peak) { vram_peak = $5 + 0 }
          vram_samples++
        }
        $6 ~ /^[0-9]+$/ {
          if ($6 + 0 > gtt_peak) { gtt_peak = $6 + 0 }
          gtt_samples++
        }
        END {
            printf "%s\t%s",
                (vram_samples ? sprintf("%.0f", vram_peak / 1048576) : "unavailable"),
                (gtt_samples ? sprintf("%.0f", gtt_peak / 1048576) : "unavailable")
        }' "$arm_samples")

    # A ring reset needs the device quiet to finish recovering; the control
    # starting into a recovering device measures the recovery rather than the
    # device.
    if [ "$resets" != unavailable ] && [ "$resets" -gt 0 ]; then
        printf 'recovery_pause_utc=%s seconds=60 resets=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$resets"
        sleep 60
    fi

    set +e
    run_bench "$control_log" 0 128 32 "$control_tokens"
    control_status=$?
    set -e
    control_decode=n/a
    [ "$control_status" -ne 0 ] || control_decode=$(parse_decode_rate "$control_log")

    clock_report=$(awk -F'\t' '
        $1 ~ /^[0-9]+([.][0-9]+)?$/ { count[$1]++; clock_samples++ }
        $3 ~ /^[0-9]+([.][0-9]+)?$/ {
          if ($3 + 0 > temp_max) { temp_max = $3 + 0 }
          temperature_samples++
        }
        END {
            for (step in count) {
                if (count[step] > best) { best = count[step]; modal = step }
            }
            printf "%s\t%s", (clock_samples ? modal : "unavailable"),
                (temperature_samples ? sprintf("%.1f", temp_max / 1000) : "unavailable")
        }' "$arm_samples")

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm_label" "$arm_depth" "$arm_batch" "$arm_ubatch" "$cache_type_k" \
        "$cache_type_v" "$flash_attention" "$arm_status" "$resets" "$faults" \
        "$arm_wall" "$decode" "$memory_report" "$control_status" \
        "$control_decode" "$clock_report" >>"$summary"
    printf 'arm_stop_utc=%s label=%s status=%s decode=%s resets=%s faults=%s wall_s=%s peak_vram_gtt_mib=%s control=%s control_tok_s=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$arm_status" "$decode" \
        "$resets" "$faults" "$arm_wall" \
        "$(printf '%s' "$memory_report" | tr '\t' '/')" "$control_status" \
        "$control_decode"

    if [ "$control_status" -ne 0 ]; then
        printf 'control_failed label=%s: the device did not recover, so the remaining arms would measure a corrupt device\n' \
            "$arm_label" >&2
        device_corrupt=1
    fi
}

for depth in $depths; do
    for geometry in $geometries; do
        [ "$device_corrupt" -eq 0 ] || break
        run_arm "$depth" "${geometry%%:*}" "${geometry##*:}"
    done
    [ "$device_corrupt" -eq 0 ] || break
done

if [ "$device_corrupt" -ne 0 ]; then
    printf 'depth_wedge=halted output_directory=%s\n' "$output_directory"
    cat "$summary"
    exit 1
fi

printf 'depth_wedge=completed output_directory=%s\n' "$output_directory"
cat "$summary"
