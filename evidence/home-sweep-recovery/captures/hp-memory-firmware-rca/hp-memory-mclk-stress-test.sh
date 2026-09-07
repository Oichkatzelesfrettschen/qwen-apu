#!/usr/bin/env bash
set -euo pipefail

mclk_state_file=/sys/class/drm/card1/device/pp_dpm_mclk

sample_mclk_state() {
    printf '%s\t' "$(date -u +%FT%T.%3NZ)"
    tr '\n' ';' < "$mclk_state_file"
    printf '\n'
}

printf 'idle_samples_begin\n'
for sample_index in $(seq 1 8); do
    sample_mclk_state
    sleep 0.25
done

printf 'stress_samples_begin\n'
stress-ng \
    --vm 2 \
    --vm-bytes 8G \
    --vm-method all \
    --timeout 15s \
    --metrics-brief &
stress_process_id=$!

for sample_index in $(seq 1 68); do
    sample_mclk_state
    sleep 0.25
done

wait "$stress_process_id"
printf 'stress_complete\n'
