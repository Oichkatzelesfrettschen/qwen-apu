#!/bin/sh
set -eu

# run-power-factorial-arm.sh's `bench` instrument is what this drives: it is
# the one instrument that needs no served harness, no launch chain, and no
# monitor process, so it is the whole factorial runner reachable without a
# device. The clock, memory-scanner, CPU-cap, and power-envelope writes it
# runs under are compute-state-lease.sh's and cpu-frequency-cap.sh's own, so
# this test drives them against the fake sysfs, fake cpupower, and fake
# ryzenadj fixtures under remote/test-fixtures/ the same way
# remote/test-compute-state-lease.sh and remote/test-cpu-frequency-cap.sh do,
# and proves the three properties this harness owns beyond either of those
# scripts' own tests: every write compute-state-lease.sh's transaction and
# cpu-frequency-cap.sh's term make is restored after a clean bench arm, a
# refused cpu-frequency-cap restore still ends the whole transaction with
# exit 4, and run-power-factorial-arm.sh itself refuses to run outside a
# compute-state-lease.sh transaction rather than assuming one.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
transaction=$script_directory/compute-state-lease.sh
arm_command=$script_directory/run-power-factorial-arm.sh
# shellcheck source=test-fixtures/fake-sysfs-lib.sh
. "$script_directory/test-fixtures/fake-sysfs-lib.sh"

temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'power_factorial_fixture_directory=%s\n' "$temporary_directory" >&2
    else
        rm -rf -- "$temporary_directory"
    fi
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

sysfs_fixture=$temporary_directory/sys
state_fixture=$temporary_directory/state
stub_directory=$temporary_directory/stubs
models_fixture=$temporary_directory/models
campaign_directory=$temporary_directory/campaign
controls=$temporary_directory/controls.tsv
ryzenadj_state=$temporary_directory/ryzenadj-state.tsv
ryzenadj_log=$temporary_directory/ryzenadj.log
cpupower_log=$temporary_directory/cpupower.log
lease_fixture=$state_fixture/vulkan-workload.lock

mkdir -p "$stub_directory" "$state_fixture" "$models_fixture"
chmod 700 "$state_fixture"
fake_sysfs_create "$sysfs_fixture"

set_control() {
    printf '%s\t%s\n' "$1" "$2" >>"$controls"
}
reset_fixture() {
    fake_sysfs_reset "$sysfs_fixture"
    : >"$controls"
    rm -f -- "$ryzenadj_state" "$ryzenadj_log" "$cpupower_log"
    rm -rf -- "$campaign_directory"
    : >"$lease_fixture"
}
reset_fixture

# The registry names one fixture checkpoint whose model_file resolves under
# models_fixture; model-registry.sh runs unstubbed, since it is a pure reader
# over this one row.
registry_fixture=$temporary_directory/models.tsv
printf 'fake-model\trole\tfake-model.gguf\tfetch.sh\t4096\t8192\t16384\tf16\tf16\ton\tnone\t-\t1.0\t1.0\t0/0\tcandidate\t128\t32\t-\t-\t-\trefused\n' \
    >"$registry_fixture"
: >"$models_fixture/fake-model.gguf"

# The bench instrument's markdown table carries a `tgN` row this fixture
# writes at a fixed rate, so the runner's own parser is exercised against the
# same table shape llama-bench emits.
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'log=%s\n' "$temporary_directory/llama-bench.invocations"
    cat <<'BENCH'
printf '%s\n' "$*" >>"$log"
generate=64
previous=''
for argument in "$@"; do
    if [ "$previous" = -n ]; then
        generate=$argument
    fi
    previous=$argument
done
printf '| model | size | params | backend | ngl | threads | test | t/s |\n'
printf '| --- | --- | --- | --- | --- | --- | --- | --- |\n'
printf '| fake | 1B | 1B | Vulkan | 99 | 2 | pp0 | 100.00 |\n'
printf '| fake | 1B | 1B | Vulkan | 99 | 2 | tg%s | 12.34 |\n' "$generate"
BENCH
} >"$stub_directory/llama-bench"

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'QWEN_FAKE_CPUPOWER_SYSFS_ROOT=%s\n' "$sysfs_fixture"
    printf 'QWEN_FAKE_CPUPOWER_CONTROLS=%s\n' "$controls"
    printf 'QWEN_FAKE_CPUPOWER_LOG=%s\n' "$cpupower_log"
    printf 'export QWEN_FAKE_CPUPOWER_SYSFS_ROOT QWEN_FAKE_CPUPOWER_CONTROLS QWEN_FAKE_CPUPOWER_LOG\n'
    printf 'exec %s "$@"\n' "$script_directory/test-fixtures/fake-cpupower.sh"
} >"$stub_directory/cpupower"

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'QWEN_FAKE_RYZENADJ_STATE=%s\n' "$ryzenadj_state"
    printf 'QWEN_FAKE_RYZENADJ_CONTROLS=%s\n' "$controls"
    printf 'QWEN_FAKE_RYZENADJ_LOG=%s\n' "$ryzenadj_log"
    printf 'export QWEN_FAKE_RYZENADJ_STATE QWEN_FAKE_RYZENADJ_CONTROLS QWEN_FAKE_RYZENADJ_LOG\n'
    printf 'exec %s "$@"\n' "$script_directory/test-fixtures/fake-ryzenadj.sh"
} >"$stub_directory/ryzenadj-wrapper"

# sudo -n true answers the credential probe; sudo -n tee models the same DPM
# firmware remote/test-compute-state-lease.sh's own stub does -- a table
# takes a level index, stars the highest survivor, and the graphics table
# moves the delivered frequency hwmon reports -- since compute-state-lease.sh
# writes pp_dpm_sclk/pp_dpm_mclk through this same path and reads the star
# back before the command runs.
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'controls=%s\n' "$controls"
    printf 'sclk_table=%s\n' "$sysfs_fixture/class/drm/card1/device/pp_dpm_sclk"
    printf 'gfxclk_node=%s\n' "$sysfs_fixture/class/hwmon/hwmon1/freq1_input"
    cat <<'SUDO'
control() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}
if [ "${1:-}" = -n ]; then
    shift
fi
case ${1:-} in
    true)
        [ "$(control refuse_credential)" = 1 ] && exit 1
        exit 0
        ;;
    tee) ;;
    *) exec "$@" ;;
esac
target=$2
content=$(cat)
leaf=${target##*/}
select_level() {
    selected=''
    for level in $content; do
        if [ -z "$selected" ] || [ "$level" -gt "$selected" ]; then
            selected=$level
        fi
    done
    [ -n "$selected" ] || exit 1
    awk -v want="$selected" '{
            entry = $1
            sub(/:$/, "", entry)
            line = $0
            sub(/[[:space:]]*\*$/, "", line)
            if (entry == want) { print line " *" } else { print line }
        }' "$target" >"$target.new"
    mv -- "$target.new" "$target"
    printf '%s\n' "$selected"
}
case $leaf in
    pp_dpm_sclk)
        selected=$(select_level)
        awk -v want="$selected" 'match($0, /[0-9]+[Mm][Hh]z/) {
                entry = $1
                sub(/:$/, "", entry)
                if (entry == want) {
                    printf "%d\n", substr($0, RSTART, RLENGTH) * 1000000
                }
            }' "$sclk_table" >"$gfxclk_node"
        ;;
    pp_dpm_mclk) select_level >/dev/null ;;
    *) printf '%s\n' "$content" >"$target" ;;
esac
printf '%s\n' "$content"
SUDO
} >"$stub_directory/sudo"

chmod +x "$stub_directory/llama-bench" "$stub_directory/cpupower" \
    "$stub_directory/ryzenadj-wrapper" "$stub_directory/sudo"

run_arm() {
    arm_profile=$1
    arm_name=$2
    campaign_setup_status=0
    mkdir -p "$campaign_directory/arms" 2>/dev/null || true
    printf 'schema\tfixed64-served-campaign-v2\n' >"$campaign_directory/campaign-inputs.tsv" 2>/dev/null || \
        campaign_setup_status=1
    [ "$campaign_setup_status" -eq 0 ] || return 1
    set +e
    env PATH="$stub_directory:$PATH" \
        QWEN_SYSFS_ROOT="$sysfs_fixture" \
        QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
        QWEN_COMPUTE_STATE_REVISION=0123456789abcdef0123456789abcdef01234567 \
        QWEN_COMPUTE_STATE_CLOCK_DEADLINE_S=1 \
        QWEN_COMPUTE_STATE_RESTORE_DEADLINE_S=1 \
        QWEN_RYZENADJ="$stub_directory/ryzenadj-wrapper" \
        QWEN_CPUPOWER=cpupower \
        QWEN_COMPUTE_STATE_FORWARD="QWEN_POWER_FACTORIAL_INSTRUMENT=bench QWEN_BENCH_GENERATE=64 QWEN_LLAMA_BENCH=$stub_directory/llama-bench QWEN_MODEL_REGISTRY=$registry_fixture QWEN_MODELS_DIRECTORY=$models_fixture" \
        "$transaction" "$arm_profile" \
        "$arm_command" "$campaign_directory" "$arm_name" fake-model \
        >"$temporary_directory/run.stdout" 2>"$temporary_directory/run.stderr"
    run_status=$?
    set -e
}

fixture_state() {
    printf '%s %s %s %s %s %s %s' \
        "$(cat "$sysfs_fixture/class/drm/card1/device/power_dpm_force_performance_level")" \
        "$(awk '/\*/ { entry = $1; sub(/:$/, "", entry); print entry; exit }' \
            "$sysfs_fixture/class/drm/card1/device/pp_dpm_sclk")" \
        "$(awk '/\*/ { entry = $1; sub(/:$/, "", entry); print entry; exit }' \
            "$sysfs_fixture/class/drm/card1/device/pp_dpm_mclk")" \
        "$(cat "$sysfs_fixture/kernel/mm/ksm/run")" \
        "$(cat "$sysfs_fixture/devices/system/cpu/cpu0/cpufreq/scaling_max_freq")" \
        "$(cat "$sysfs_fixture/devices/system/cpu/cpu1/cpufreq/scaling_max_freq")" \
        "$(cat "$sysfs_fixture/devices/system/cpu/cpufreq/boost")"
}
baseline_fixture_state='manual 1 1 1 3200000 3200000 1'

# A clean bench arm through P2 (cpu-capped, no package envelope) restores the
# DPM level, the KSM run state, and both cores' cpufreq ceiling and the boost
# node.
reset_fixture
run_arm serve-fixed-cpu-capped fake-model-clean-arm
if [ "$run_status" -eq 0 ] &&
    grep -q '^power_factorial_arm=completed arm=fake-model-clean-arm model=fake-model decode_tok_s=12.34$' \
        "$temporary_directory/run.stdout" &&
    grep -q '^restoration=held profile=serve-fixed-cpu-capped ' "$temporary_directory/run.stdout" &&
    [ "$(fixture_state)" = "$baseline_fixture_state" ]; then
    report 0 a_clean_bench_arm_restores_every_write
else
    report 1 a_clean_bench_arm_restores_every_write
    cat "$temporary_directory/run.stdout" "$temporary_directory/run.stderr" >&2
fi

# The arm-summary the runner retains carries the bench instrument's own rate
# and the CPU-side endpoints this script adds beyond run-power-envelope-arm.sh.
arm_summary=$campaign_directory/arms/fake-model-clean-arm/arm-summary.tsv
if [ -r "$arm_summary" ] &&
    grep -q '^instrument	bench$' "$arm_summary" &&
    grep -q '^decode_tok_s	12.34$' "$arm_summary" &&
    [ -r "$campaign_directory/arms/fake-model-clean-arm/cpu-endpoint-start.tsv" ] &&
    [ -r "$campaign_directory/arms/fake-model-clean-arm/cpu-endpoint-end.tsv" ]; then
    report 0 the_bench_arm_retains_its_own_summary_and_cpu_endpoints
else
    report 1 the_bench_arm_retains_its_own_summary_and_cpu_endpoints
    cat "$arm_summary" 2>&1 >&2
fi

# A refused CPU-frequency-cap restore ends the whole transaction non-zero,
# not just cpu-frequency-cap.sh's own restore subcommand: the cap is applied
# through the real writer, and the read-back after a refused restore write
# still disagrees with the snapshot.
reset_fixture
# The restore writes the snapshot's own scaling_max_freq (3200000, from
# fake_sysfs_reset) back with a `KHz` suffix; refusing that exact value
# refuses the restore write alone and leaves the apply write (2300MHz) able
# to proceed.
set_control refuse_upper_value 3200000KHz
run_arm serve-fixed-cpu-capped fake-model-incident-arm
if [ "$run_status" -eq 4 ] &&
    grep -q '^restoration=failed profile=serve-fixed-cpu-capped fields=cpu_frequency_cap=unreturned' \
        "$temporary_directory/run.stdout"; then
    report 0 a_refused_cpu_cap_restore_ends_the_transaction_with_exit_4
else
    report 1 a_refused_cpu_cap_restore_ends_the_transaction_with_exit_4
    printf 'run_status=%s\n' "$run_status" >&2
    cat "$temporary_directory/run.stdout" "$temporary_directory/run.stderr" >&2
fi

# run-power-factorial-arm.sh refuses to run outside a compute-state-lease.sh
# transaction: it is the command a transaction execs, not a standalone
# harness, so it requires the profile and lease-proof names the transaction
# forwards rather than assuming one is live.
reset_fixture
direct_status=0
env PATH="$stub_directory:$PATH" \
    QWEN_MODEL_REGISTRY="$registry_fixture" QWEN_MODELS_DIRECTORY="$models_fixture" \
    QWEN_LLAMA_BENCH="$stub_directory/llama-bench" \
    QWEN_POWER_FACTORIAL_INSTRUMENT=bench \
    "$arm_command" "$campaign_directory" fake-model-direct-arm fake-model \
    >"$temporary_directory/direct.stdout" 2>"$temporary_directory/direct.stderr" ||
    direct_status=$?
if [ "$direct_status" -eq 2 ] &&
    grep -q 'reason=compute_state_profile_absent' "$temporary_directory/direct.stderr" &&
    [ ! -e "$campaign_directory/arms/fake-model-direct-arm" ]; then
    report 0 the_runner_refuses_to_run_without_a_transaction
else
    report 1 the_runner_refuses_to_run_without_a_transaction
    cat "$temporary_directory/direct.stdout" "$temporary_directory/direct.stderr" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'power_factorial_campaign_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'power_factorial_campaign_tests=passed\n'
