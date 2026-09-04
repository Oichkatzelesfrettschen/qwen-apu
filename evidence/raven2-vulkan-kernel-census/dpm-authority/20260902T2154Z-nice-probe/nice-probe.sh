#!/bin/sh
# Priority probe: llama-bench pinned to core 0 at nice 19 against nice 0,
# under the commanded clock pair (manual, sclk level 2 = 1100, mclk level
# 2 = 933), ABBA twice. A 100 ms host sampler records delivered GFX clock
# and load1 and counts its own stalls, since a stall of the sampler and a
# stall of the bench share one cause: a nice-0 tenant on core 0.
set -u
drm=/sys/class/drm/card1/device
hwmon=$(ls -d $drm/hwmon/hwmon* | head -1)
remote=$HOME/qwen-laptop-setup/remote
model=$HOME/models/$("$remote/model-registry.sh" id qwen38-2b-distill model_file)
bench=$HOME/src/llama.cpp-census-v7/build-raven2-vulkan-census/bin/llama-bench
out=$HOME/raven2-nice-probe-$(date -u +%Y%m%dT%H%MZ)
mkdir -p "$out"
say() { printf '%s %s\n' "$(TZ=America/Los_Angeles date +%H:%M:%S%Z)" "$*"; }
restore() {
    echo auto | sudo -n tee $drm/power_dpm_force_performance_level >/dev/null 2>&1
    say "dpm_restore=$(cat $drm/power_dpm_force_performance_level)"
}
trap restore EXIT TERM INT HUP
sudo -n true 2>/dev/null || { say sudo=expired; exit 9; }
"$remote/qwen-teardown.sh" >/dev/null 2>&1; say "teardown_exit=$?"
echo manual | sudo -n tee $drm/power_dpm_force_performance_level >/dev/null
echo 2 | sudo -n tee $drm/pp_dpm_sclk >/dev/null
echo 2 | sudo -n tee $drm/pp_dpm_mclk >/dev/null
sleep 2
say "readback level=$(cat $drm/power_dpm_force_performance_level) sclk=$(grep '\*' $drm/pp_dpm_sclk | tr -d '\n') mclk=$(grep '\*' $drm/pp_dpm_mclk | tr -d '\n')"
say "tenants: $(ps -o ni=,pcpu=,comm= -C qemu-system-x86_64 | tr -s ' ' | head -1) ksmd_nice=$(ps -o ni= -C ksmd | tr -d ' ') load=$(cut -d' ' -f1-3 /proc/loadavg)"
sampler() {
    # $1 = output file; 100 ms cadence; columns ns freq_mhz load1 busy
    prev=$(date +%s%N)
    while :; do
        now=$(date +%s%N)
        printf '%s\t%s\t%s\t%s\n' "$now" "$(($(cat $hwmon/freq1_input) / 1000000))" \
            "$(cut -d' ' -f1 /proc/loadavg)" "$(cat $drm/gpu_busy_percent)" >>"$1"
        prev=$now
        sleep 0.1
    done
}
for arm in N19-1 N0-1 N0-2 N19-2 N19-3 N0-3 N0-4 N19-3b N0-5 N0-6 N19-4; do
    level=${arm#N}; level=${level%%-*}
    samples=$out/$arm.samples
    : >"$samples"
    ( sampler "$samples" ) &
    sampler_pid=$!
    taskset -cp 1 "$sampler_pid" >/dev/null 2>&1
    taskset -c 0 nice -n "$level" "$bench" -m "$model" -p 0 -n 64 -r 5 -ngl 99 -t 2 -o md \
        >"$out/$arm.md" 2>"$out/$arm.err"
    bench_status=$?
    kill "$sampler_pid" 2>/dev/null; wait "$sampler_pid" 2>/dev/null
    rate=$(awk -F'|' '/tg64/ { gsub(/^ +| +$/, "", $(NF-1)); print $(NF-1) }' "$out/$arm.md" | tail -1)
    stats=$(awk -F'\t' 'NR > 1 { gap = ($1 - prev) / 1e6; if (gap > max) max = gap; if (gap > 250) stalls++ }
        { prev = $1; if ($4 > 20) { n++; f += $2; if (min == 0 || $2 < min) min = $2; if ($3 > load) load = $3 } }
        END { printf "busy_samples=%d freq_min=%d freq_mean=%.0f max_gap_ms=%.0f stalls_gt250ms=%d load1_max=%s", n, min, (n ? f / n : 0), max, stalls, load }' "$samples")
    say "arm=$arm nice=$level status=$bench_status tok_s=$rate $stats"
    sleep 6
done
say "out=$out"
