#!/bin/sh
set -eu

# One reversible compute-state transaction around one command.
#
# The appliance's decode rate is a property of the machine state a command runs
# under rather than of the command alone. `power_dpm_force_performance_level`
# under the amdgpu device decides which graphics and fabric steps the SMU10 part
# selects, `/sys/kernel/mm/ksm/run` decides whether ksmd scans while the decode
# streams weights, and the server's nice level, CPU affinity, and I/O class
# decide how the two Zen+ cores are shared. Each of those is a machine-wide
# authority: a write reaches every workload on the device, so a run that leaves
# one applied leaves the next measurement reading this transaction's state under
# another campaign's name. This script takes the shared Vulkan lease first,
# snapshots every authority it will write, applies one named profile, proves the
# delivered clocks reached what the profile states, runs COMMAND, and restores
# and verifies the whole snapshot on every exit path including a terminating
# signal. A value that fails to return is reported as `restoration=failed` and
# ends the transaction non-zero, because a machine left on a forced level is an
# incident rather than a warning.
#
# Eight profiles are defined below the census and package-envelope campaigns'
# own, plus the power/CPU/clock factorial campaign's nine profiles documented
# where they are declared in resolve_profile and registered in
# evidence/power-factorial/README.md. The first two rest on the measurements
# evidence/raven2-vulkan-kernel-census/dpm-authority/ retains on this part, and
# the six package arms on the campaign evidence/power-envelope/ registers:
#
#   measure-fixed                manual, pp_dpm_sclk level 2, pp_dpm_mclk level
#                                2, delivered GFXCLK 1100 MHz, FCLK held at 933
#                                MHz, child at nice 19, I/O class idle, cores
#                                0,1, ksmd stopped. One execution state for a
#                                measurement arm.
#   serve-performance-candidate  the same graphics pin with pp_dpm_mclk written
#                                as the range `2 3`, so the firmware selects 933
#                                or 1067 MHz, and the child at nice 0. The
#                                serving candidate that trades desktop headroom
#                                for decode.
#   measure-fixed-package-default   measure-fixed's execution state with the
#                                power term arming on the platform's own budget:
#                                it writes no limit, snapshots the baseline, and
#                                proves the thermal ceiling. The campaign's
#                                control arm.
#   measure-fixed-package-20w    the same state with STAPM and PPT slow at
#                                20000 mW and PPT fast held at the platform's
#                                25000 mW.
#   measure-fixed-package-25w    the same state at 25000 mW, the top of the
#                                3050U's published 12 to 25 W cTDP range.
#   serve-fixed-package-default, serve-fixed-package-20w,
#   serve-fixed-package-25w      the same three budgets under the same clocks
#                                with the child at nice 0 and I/O class
#                                best-effort, for a command that drives the
#                                guarded launch chain. That chain owns the
#                                served process priorities itself:
#                                qwen-capacity-policy.sh puts llama-server on
#                                core 0 at nice 19, while
#                                monitor-qwen-runtime.sh renices itself to 0 and
#                                exits where it cannot, so a served command
#                                started at nice 19 ends its own session with
#                                reason=monitor_exited ahead of the first
#                                request.
#
# Three prohibitions are encoded rather than documented. `high` and
# `profile_peak` pin the delivered graphics clock at 1100 MHz and collapse the
# starred pp_dpm_mclk fabric state to 400 MHz, which measured 6.3 to 7.0 tok/s
# against `auto`'s 6.8 to 8.2, so neither is a profile name here and each is
# refused by name. A hard minimum of 1067 MHz on pp_dpm_mclk is accepted by the
# kernel and capped by the firmware at 933, so no profile requires it and the
# fabric expectation is a set rather than a floor. `/sys/kernel/mm/ksm/run`
# takes 2 to unmerge every merged page, which costs the host the sharing it
# already paid for, so this transaction writes 0 alone and refuses to start
# against a snapshot reading 2 rather than writing that value back at restore.
#
# The package budget is the one authority the SMU rather than the kernel owns.
# `/sys/class/powercap` creates no `constraint_*` file on this part and the
# amdgpu hwmon carries a `PPT` label with no `power1_cap` beside it, so a
# sustained-power arm reaches the firmware through power-envelope.sh and its
# ryzenadj binary. A profile that names no envelope leaves that term out of the
# transaction entirely, which is what keeps the clock profiles runnable on a
# machine where the binary is absent.
#
# `pp_dpm_mclk` is a misleading sysfs name on SMU10: the kernel obtains its
# value with PPSMC_MSG_GetFclkFrequency, so its states are dynamic fabric clocks
# and the DRAM is trained at DDR4-2133.33 whichever one is selected. The
# delivered graphics clock is read from the amdgpu hwmon `freq1_input` rather
# than from the starred pp_dpm_sclk step, because that file reports the selected
# state and not what the part delivers.
#
# The device exclusion is the lane's own. census-arm-lib.sh takes
# ~/qwen-webui-state/vulkan-workload.lock on descriptor 8 ahead of the first
# write and publishes a proof of that holding, which
# verify-external-vulkan-lease.py reads back against the live /proc entry and
# qwen-capacity-policy.sh answers by unsetting QWEN_VULKAN_WORKLOAD_LOCK for the
# server it assembles. A served COMMAND therefore runs inside this transaction's
# exclusion instead of blocking in `update_slots` against a lock this shell
# holds. The proof travels to the child through the closed arm environment.
#
# Every sysfs path resolves through QWEN_SYSFS_ROOT and the three leaf overrides
# below, so remote/test-compute-state-lease.sh drives the whole transaction
# against a fixture tree under mktemp with no privilege.

usage() {
    printf 'usage: %s PROFILE COMMAND [ARG...]\n' "$0" >&2
    printf '       %s status\n' "$0" >&2
    printf 'profiles: serve-baseline-fixed measure-fixed serve-performance-candidate\n' >&2
    printf '          measure-fixed-package-default measure-fixed-package-20w measure-fixed-package-25w\n' >&2
    printf '          serve-fixed-package-default serve-fixed-package-20w serve-fixed-package-25w\n' >&2
    printf '          serve-auto-baseline serve-fixed-cpu-capped serve-fixed-cpu-capped-fclk-range\n' >&2
    printf '          serve-fixed-cpu-capped-fclk-range-ksm-running serve-fixed-fclk-range\n' >&2
    printf '          measure-fixed-cpu-capped-fclk-range\n' >&2
    printf '          serve-fixed-cpu-capped-fclk-range-package-25w\n' >&2
    exit 2
}

if [ "$#" -lt 1 ]; then
    usage
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"

sysfs_root=${QWEN_SYSFS_ROOT:-/sys}
drm_device=${QWEN_DRM_DEVICE:-$sysfs_root/class/drm/card1/device}
hwmon_root=${QWEN_HWMON_ROOT:-$sysfs_root/class/hwmon}
ksm_run_node=${QWEN_KSM_RUN_NODE:-$sysfs_root/kernel/mm/ksm/run}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
workload_lease=${QWEN_VULKAN_WORKLOAD_LOCK:-$state_directory/vulkan-workload.lock}
lease_verifier=${QWEN_EXTERNAL_LEASE_VERIFIER:-$script_directory/verify-external-vulkan-lease.py}
power_envelope_command=${QWEN_POWER_ENVELOPE_COMMAND:-$script_directory/power-envelope.sh}
power_envelope_snapshot=${QWEN_POWER_ENVELOPE_SNAPSHOT:-$state_directory/power-envelope-snapshot.tsv}
# The envelope snapshot is claimed atomically by whoever creates it, and this
# token is what marks the claim as this transaction's. The restore acts on a
# snapshot carrying this token alone, so a concurrent campaign that claimed the
# envelope between this transaction's preflight and its apply keeps its own
# budget rather than having it returned by a transaction that never wrote it.
power_envelope_owner=compute-state-lease.$$.$(LC_ALL=C od -An -N8 -tx1 /dev/urandom 2>/dev/null |
    tr -d ' \n')
cpu_frequency_cap_command=${QWEN_CPU_FREQUENCY_CAP_COMMAND:-$script_directory/cpu-frequency-cap.sh}
cpu_frequency_cap_snapshot=${QWEN_CPU_FREQUENCY_CAP_SNAPSHOT:-$state_directory/cpu-frequency-cap-snapshot.tsv}
# The cpu-frequency-cap snapshot is claimed the way the power-envelope
# snapshot is: this token marks the claim as this transaction's, so its
# restore acts on a snapshot carrying this token alone.
cpu_frequency_cap_owner=cpu-frequency-cap.$$.$(LC_ALL=C od -An -N8 -tx1 /dev/urandom 2>/dev/null |
    tr -d ' \n')
renice_command=${QWEN_RENICE_COMMAND:-/usr/bin/renice}
ionice_command=${QWEN_IONICE_COMMAND:-/usr/bin/ionice}
taskset_command=${QWEN_TASKSET_COMMAND:-/usr/bin/taskset}
clock_deadline_s=${QWEN_COMPUTE_STATE_CLOCK_DEADLINE_S:-10}
restore_deadline_s=${QWEN_COMPUTE_STATE_RESTORE_DEADLINE_S:-10}
# The delivered graphics clock is a sensor reading rather than a written value,
# so it is compared inside a tolerance. One percent is the band the census
# campaign holds its fabric floor to.
clock_tolerance=${QWEN_COMPUTE_STATE_CLOCK_TOLERANCE:-0.01}

poll_interval_s=0.1

# The pairs are `LEVEL=MHZ`, so the level a profile writes and the frequency its
# expectation is stated against are one declaration. The delivered graphics
# clock is required to equal the graphics level's own frequency; the fabric
# selection is required to land on one of the pairs' frequencies, which is what
# makes the firmware's 1067-to-933 cap a satisfied expectation rather than a
# refusal.
profile_level_field() {
    profile_field_result=''
    for profile_field_pair in $1; do
        case $2 in
            index) profile_field_value=${profile_field_pair%%=*} ;;
            *) profile_field_value=${profile_field_pair#*=} ;;
        esac
        if [ -z "$profile_field_result" ]; then
            profile_field_result=$profile_field_value
        else
            profile_field_result="$profile_field_result $profile_field_value"
        fi
    done
    printf '%s\n' "$profile_field_result"
}

resolve_profile() {
    # The power envelope and the CPU frequency cap are the two terms a profile
    # may leave unnamed. An empty value keeps the transaction to the clocks
    # (and, for the cap, to whatever the platform holds), so a machine without
    # ryzenadj or without cpupower still runs every profile that states no
    # package budget or no cap; a named value makes the binary, the credential,
    # and the read-back preconditions of the whole transaction.
    profile_power_envelope=''
    profile_cpu_frequency_cap=''
    # `auto` leaves the governor selecting among the `_PSS` table on its own and
    # writes no sclk/mclk level, so the clock-pinning writes and the clock-proof
    # deadline both stay out of that profile's transaction; a profile states
    # `profile_write_clock_selection=0` to take that path, and the flag is reset
    # to 1 for every profile below it so a later addition does not inherit it by
    # accident.
    profile_write_clock_selection=1
    case $1 in
        serve-baseline-fixed)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=preserve
            profile_power_envelope=platform-default
            ;;
        measure-fixed)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=19
            profile_child_io_class=idle
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            ;;
        serve-performance-candidate)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            ;;
        # The three package-budget arms share `measure-fixed`'s whole execution
        # state and differ in the SMU's sustained and package power limits
        # alone, so a pair of them measures the budget rather than the machine.
        # The default arm names `platform-default`, which writes no limit and
        # still snapshots the platform's own baseline and proves the thermal
        # ceiling, so the control runs the same code path as the candidates.
        measure-fixed-package-default)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=19
            profile_child_io_class=idle
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=platform-default
            ;;
        measure-fixed-package-20w)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=19
            profile_child_io_class=idle
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=package-20w
            ;;
        measure-fixed-package-25w)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=19
            profile_child_io_class=idle
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=package-25w
            ;;
        # The served package arms carry the same clocks, the same memory
        # scanner, and the same three budgets and leave the child at nice 0,
        # because the guarded launch chain rather than this transaction owns the
        # served process priorities. `qwen-capacity-policy.sh` puts llama-server
        # itself on core 0 at nice 19, and `monitor-qwen-runtime.sh` renices
        # itself to 0 and exits where it cannot, so a served command started at
        # nice 19 ends its own session with `reason=monitor_exited` before the
        # first request. A harness that samples beside the server applies nice
        # 19 to its own samplers rather than inheriting it from the transaction.
        serve-fixed-package-default)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=platform-default
            ;;
        serve-fixed-package-20w)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=package-20w
            ;;
        serve-fixed-package-25w)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=package-25w
            ;;
        # The coupled factorial campaign's P0 through P4, and the factor-pair
        # alternates read against P4 as the campaign's best arm. Every rung
        # that runs through run-power-envelope-arm.sh (measure-served-decode.sh,
        # therefore qwen-launch.sh, therefore monitor-qwen-runtime.sh) carries
        # nice 0: monitor-qwen-runtime.sh unconditionally renices itself to 0
        # and exits where it cannot, and lowering a nice level needs
        # CAP_SYS_NICE this transaction's unprivileged child does not hold, the
        # same constraint serve-fixed-package-* is already built against. P1 is
        # `serve-fixed-package-default` above -- GFX 1100, FCLK 933, no cap, the
        # platform's own package limits, still snapshotted through
        # `platform-default` so the SMU baseline is provable even where nothing
        # is capped. P2 through P4 cap the two Zen+ cores near their `_PSS`
        # base clock through cpu-frequency-cap.sh's `base-clock-cap` profile:
        # `cpupower frequency-set -u 2.3GHz` on both cores plus the boost node
        # written 0, both restored. The hypothesis this campaign runs against
        # is that capping CPU boost during steady decode frees package and
        # thermal budget for GFX/FCLK, registered with its falsifier in
        # evidence/power-factorial/README.md; "CPU maximum plus GPU maximum" is
        # not assumed here; evidence/raven2-vulkan-kernel-census/dpm-authority/
        # already measured the opposite pairing (`high`/`profile_peak` pinning
        # GFXCLK at 1100 MHz) collapse the starred pp_dpm_mclk fabric state to
        # 400 MHz.
        serve-auto-baseline)
            profile_dpm_level=auto
            profile_sclk_levels=''
            profile_mclk_levels=''
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_write_clock_selection=0
            profile_power_envelope=platform-default
            ;;
        serve-fixed-cpu-capped)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_cpu_frequency_cap=base-clock-cap
            profile_power_envelope=platform-default
            ;;
        serve-fixed-cpu-capped-fclk-range)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_cpu_frequency_cap=base-clock-cap
            profile_power_envelope=platform-default
            ;;
        # The KSM factor-pair: P3's own state with the scanner left running
        # (1) instead of paused (0), read against P3 to isolate the scanner
        # term alone. The pairs read against P3 rather than P4, because a
        # package-limit increase is a scope change the operator gates on
        # telemetry (see P4 below): P3 is the strongest arm this campaign
        # runs unconditionally.
        serve-fixed-cpu-capped-fclk-range-ksm-running)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=1
            profile_cpu_frequency_cap=base-clock-cap
            profile_power_envelope=platform-default
            ;;
        # The CPU-cap factor-pair: P3's own state with no cap at all, read
        # against P3 to isolate the cap term alone.
        serve-fixed-fclk-range)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_power_envelope=platform-default
            ;;
        # The nice factor-pair alternate. Nice 19 cannot run through the
        # served harness at all (monitor-qwen-runtime.sh's self-renice would
        # refuse), so this rung is read against P3 through a direct
        # llama-bench command instead of measure-served-decode.sh, the same
        # substitution evidence/raven2-vulkan-kernel-census/dpm-authority/'s
        # own nice-probe makes; run-power-factorial-arm.sh's `bench` instrument
        # is what runs it. It is named with the `measure-` prefix that every
        # other nice-19 profile in this file carries, rather than `serve-`,
        # because nothing here drives the guarded launch chain.
        measure-fixed-cpu-capped-fclk-range)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=19
            profile_child_io_class=idle
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_cpu_frequency_cap=base-clock-cap
            profile_power_envelope=platform-default
            ;;
        # P4: a package-limit increase over P3, run only where an earlier
        # arm's own telemetry shows the platform's stock budget binding (a
        # PPT value at its limit, or the STAPM value converging on 15 W over
        # the 200 s averaging window during a sustained run). It is never a
        # default arm; run-power-factorial-campaign.sh gates it behind
        # QWEN_POWER_FACTORIAL_PACKAGE_RECEIPT and evidence/power-factorial/
        # README.md registers the gate.
        serve-fixed-cpu-capped-fclk-range-package-25w)
            profile_dpm_level=manual
            profile_sclk_levels='2=1100'
            profile_mclk_levels='2=933 3=1067'
            profile_child_nice=0
            profile_child_io_class=best-effort
            profile_child_cpu_list=0,1
            profile_ksm_run=0
            profile_cpu_frequency_cap=base-clock-cap
            profile_power_envelope=package-25w
            ;;
        high | profile_peak)
            printf '%s pins the delivered graphics clock and collapses the starred pp_dpm_mclk fabric state to 400 MHz, which decoded below auto on this part; it is not a profile here\n' \
                "$1" >&2
            exit 2
            ;;
        *)
            printf 'unknown profile: %s\n' "$1" >&2
            usage
            ;;
    esac
    profile_sclk_selection=$(profile_level_field "$profile_sclk_levels" index)
    profile_required_gfxclk_mhz=$(profile_level_field "$profile_sclk_levels" value)
    profile_mclk_selection=$(profile_level_field "$profile_mclk_levels" index)
    profile_required_fclk_mhz=$(profile_level_field "$profile_mclk_levels" value)
}

io_class_number() {
    case $1 in
        realtime) printf '1\n' ;;
        best-effort) printf '2\n' ;;
        idle) printf '3\n' ;;
        *)
            printf 'unknown I/O class: %s\n' "$1" >&2
            exit 2
            ;;
    esac
}

# The amdgpu hwmon number moves across boots, so the directory is resolved by
# its name attribute the way every other harness in this tree resolves it.
resolve_hwmon_device() {
    resolved_hwmon=''
    for hwmon_entry in "$hwmon_root"/*; do
        [ -d "$hwmon_entry" ] || continue
        [ -r "$hwmon_entry/name" ] || continue
        if [ "$(cat "$hwmon_entry/name")" = amdgpu ]; then
            resolved_hwmon=$hwmon_entry
            break
        fi
    done
    printf '%s\n' "$resolved_hwmon"
}

# hwmon reports the delivered graphics frequency in hertz. The reading is
# rounded to the nearest megahertz so a comparison against a DPM table's own
# megahertz is a comparison of like units.
read_delivered_gfxclk_mhz() {
    if [ -z "${hwmon_device:-}" ] || [ ! -r "$hwmon_device/freq1_input" ]; then
        printf 'unavailable\n'
        return 0
    fi
    awk 'NR == 1 {
            if ($1 ~ /^[0-9]+$/) { printf "%d\n", ($1 + 500000) / 1000000 }
            else { print "unavailable" }
            found = 1
        }
        END { if (!found) print "unavailable" }' "$hwmon_device/freq1_input"
}

read_selected_field() {
    read_selected_line=$(census_engine_clock_selected "$1" 2>/dev/null) || {
        printf 'unavailable\n'
        return 0
    }
    case $2 in
        index) printf '%s\n' "${read_selected_line%% *}" ;;
        *) printf '%s\n' "${read_selected_line#* }" ;;
    esac
}

read_ksm_run() {
    if [ ! -r "$1" ]; then
        printf 'unavailable\n'
        return 0
    fi
    read_ksm_value=$(tr -d ' \t' <"$1" | head -n 1)
    case $read_ksm_value in
        '' | *[!0-9]*) printf 'unavailable\n' ;;
        *) printf '%s\n' "$read_ksm_value" ;;
    esac
}

read_dpm_level() {
    if [ ! -r "$1" ]; then
        printf 'unavailable\n'
        return 0
    fi
    read_dpm_value=$(tr -d ' \t' <"$1" | head -n 1)
    printf '%s\n' "${read_dpm_value:-unavailable}"
}

read_sclk_index() {
    read_selected_field "$1/pp_dpm_sclk" index
}

read_mclk_index() {
    read_selected_field "$1/pp_dpm_mclk" index
}

read_process_nice() {
    LC_ALL=C awk '
        {
            stat_line = $0
            sub(/^.*[)] /, "", stat_line)
            field_count = split(stat_line, fields, /[[:space:]]+/)
            if (field_count >= 17) print fields[17]
            exit
        }' "/proc/$1/stat" 2>/dev/null || true
}

read_process_cpu_list() {
    "$taskset_command" -p -c "$1" 2>/dev/null | awk '{ print $NF }' || true
}

read_process_io_class() {
    "$ionice_command" -p "$1" 2>/dev/null | awk '{ print $1 }' | tr -d ':' || true
}

within_tolerance() {
    awk -v observed="$1" -v required="$2" -v tolerance="$3" 'BEGIN {
        if (observed !~ /^[0-9]+$/ || required + 0 <= 0) exit 1
        difference = observed - required
        if (difference < 0) difference = -difference
        exit (difference / required <= tolerance + 0) ? 0 : 1 }'
}

value_in_set() {
    for candidate_value in $2; do
        [ "$1" = "$candidate_value" ] && return 0
    done
    return 1
}

lease_is_free() {
    [ -e "$workload_lease" ] || return 0
    flock -n -x "$workload_lease" true 2>/dev/null
}

# status reads and writes nothing. It takes no credential and probes the lease
# without taking it, so it answers while a transaction, a served router, or an
# image generation holds the device.
if [ "$1" = status ]; then
    if [ "$#" -ne 1 ]; then
        usage
    fi
    hwmon_device=$(resolve_hwmon_device)
    if lease_is_free; then
        lease_state=free
    else
        lease_state=held
    fi
    # caller_nice is the invoking shell's own level, which this subcommand never
    # changes; a profile's term is named on the transaction's own record.
    if [ -x "$power_envelope_command" ]; then
        power_envelope_line=$(QWEN_POWER_ENVELOPE_SNAPSHOT="$power_envelope_snapshot" \
            "$power_envelope_command" status 2>/dev/null) || power_envelope_line=''
    else
        power_envelope_line=''
    fi
    if [ -x "$cpu_frequency_cap_command" ]; then
        cpu_frequency_cap_line=$(QWEN_CPU_FREQUENCY_CAP_SNAPSHOT="$cpu_frequency_cap_snapshot" \
            "$cpu_frequency_cap_command" status 2>/dev/null) || cpu_frequency_cap_line=''
    else
        cpu_frequency_cap_line=''
    fi
    printf 'compute_state=live dpm_level=%s sclk_level=%s sclk_mhz=%s mclk_level=%s mclk_mhz=%s gfxclk_delivered_mhz=%s ksm_run=%s lease=%s caller_nice=%s\n' \
        "$(read_dpm_level "$drm_device/power_dpm_force_performance_level")" \
        "$(read_sclk_index "$drm_device")" \
        "$(read_selected_field "$drm_device/pp_dpm_sclk" value)" \
        "$(read_mclk_index "$drm_device")" \
        "$(read_selected_field "$drm_device/pp_dpm_mclk" value)" \
        "$(read_delivered_gfxclk_mhz)" \
        "$(read_ksm_run "$ksm_run_node")" \
        "$lease_state" \
        "$(read_process_nice "$$")"
    printf '%s\n' "${power_envelope_line:-power_envelope=unavailable reason=term_absent}"
    printf '%s\n' "${cpu_frequency_cap_line:-cpu_frequency_cap=unavailable reason=term_absent}"
    exit 0
fi

if [ "$#" -lt 2 ]; then
    usage
fi

profile_name=$1
shift
resolve_profile "$profile_name"

# Every refusal that needs no write runs here, ahead of the lease and ahead of
# the first sysfs write, so a transaction that cannot complete costs the machine
# no state change at all. stop_child reads this setting again inside the EXIT
# trap, where `$((grace_seconds * 5))` on a non-integer value is a shell
# arithmetic error that would abort the trap ahead of finish_transaction and
# leave the applied DPM/KSM state unrestored, so it is validated here rather
# than trusted at the point cleanup can no longer refuse. The upper bound holds
# the same promise: a merely large value is valid arithmetic but turns the
# bounded shutdown this setting exists to provide into an effectively unbounded
# one. The nearest comparable settings in this tree are far smaller --
# image-service.py's own TERMINATION_GRACE_SECONDS is 5, and its
# QWEN_IMAGE_LEASE_WAIT_S default is 60 -- so an hour is a generous ceiling
# rather than one measured against a peer.
stop_grace_seconds_maximum=3600
case ${QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS:-10} in
    '' | *[!0-9]*)
        printf 'QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS is not a non-negative integer: %s\n' \
            "${QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS:-10}" >&2
        exit 2
        ;;
esac
if [ "${QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS:-10}" -gt "$stop_grace_seconds_maximum" ]; then
    printf 'QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS exceeds the %s second maximum: %s\n' \
        "$stop_grace_seconds_maximum" "${QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS:-10}" >&2
    exit 2
fi

for required_command in flock "$renice_command" "$ionice_command" "$taskset_command"; do
    case $required_command in
        /*)
            if [ ! -x "$required_command" ]; then
                printf 'a required command is not executable: %s\n' "$required_command" >&2
                exit 2
            fi
            ;;
        *)
            if ! command -v "$required_command" >/dev/null 2>&1; then
                printf 'a required command is absent: %s\n' "$required_command" >&2
                exit 2
            fi
            ;;
    esac
done

if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
    printf 'this transaction writes %s and %s through sudo -n and never prompts; run `sudo -v` first\n' \
        "$drm_device/power_dpm_force_performance_level" "$ksm_run_node" >&2
    exit 2
fi

# A profile that names a package budget makes the power term a precondition of
# the whole transaction rather than a step inside it. The writer, the credential
# it needs, and a readable power-metrics table are proven here, ahead of the
# lease and ahead of the first clock write, so a machine that cannot carry the
# budget costs no state change at all.
if [ -n "$profile_power_envelope" ]; then
    if [ ! -f "$power_envelope_command" ] || [ ! -x "$power_envelope_command" ]; then
        printf 'profile %s names power envelope %s and the term is not executable: %s\n' \
            "$profile_name" "$profile_power_envelope" "$power_envelope_command" >&2
        exit 2
    fi
    power_envelope_preflight=$(QWEN_POWER_ENVELOPE_SNAPSHOT="$power_envelope_snapshot" \
        "$power_envelope_command" status 2>&1) || power_envelope_preflight=''
    case $power_envelope_preflight in
        'power_envelope=live'*' snapshot=absent') ;;
        'power_envelope=live'*' snapshot=present')
            printf 'profile %s names power envelope %s and a snapshot from an earlier apply is still live: restore it with `%s restore` before starting another transaction (%s)\n' \
                "$profile_name" "$profile_power_envelope" "$power_envelope_command" \
                "$power_envelope_snapshot" >&2
            exit 2
            ;;
        *)
            printf 'profile %s names power envelope %s and the term answers: %s\n' \
                "$profile_name" "$profile_power_envelope" \
                "${power_envelope_preflight:-nothing}" >&2
            exit 2
            ;;
    esac
fi

# A profile that names a CPU frequency cap makes the same kind of precondition
# of the cap term: the writer, the credential, and the read-back preconditions
# are proven here, ahead of the lease and ahead of the first clock write.
if [ -n "$profile_cpu_frequency_cap" ]; then
    if [ ! -f "$cpu_frequency_cap_command" ] || [ ! -x "$cpu_frequency_cap_command" ]; then
        printf 'profile %s names CPU frequency cap %s and the term is not executable: %s\n' \
            "$profile_name" "$profile_cpu_frequency_cap" "$cpu_frequency_cap_command" >&2
        exit 2
    fi
    cpu_frequency_cap_preflight=$(QWEN_CPU_FREQUENCY_CAP_SNAPSHOT="$cpu_frequency_cap_snapshot" \
        "$cpu_frequency_cap_command" status 2>&1) || cpu_frequency_cap_preflight=''
    case $cpu_frequency_cap_preflight in
        'cpu_frequency_cap=live'*' snapshot=absent') ;;
        'cpu_frequency_cap=live'*' snapshot=present')
            printf 'profile %s names CPU frequency cap %s and a snapshot from an earlier apply is still live: restore it with `%s restore` before starting another transaction (%s)\n' \
                "$profile_name" "$profile_cpu_frequency_cap" "$cpu_frequency_cap_command" \
                "$cpu_frequency_cap_snapshot" >&2
            exit 2
            ;;
        *)
            printf 'profile %s names CPU frequency cap %s and the term answers: %s\n' \
                "$profile_name" "$profile_cpu_frequency_cap" \
                "${cpu_frequency_cap_preflight:-nothing}" >&2
            exit 2
            ;;
    esac
fi

for required_surface in power_dpm_force_performance_level pp_dpm_sclk pp_dpm_mclk; do
    if [ ! -r "$drm_device/$required_surface" ]; then
        printf 'drm surface is unreadable: %s\n' "$drm_device/$required_surface" >&2
        exit 2
    fi
done

hwmon_device=$(resolve_hwmon_device)
if [ -z "$hwmon_device" ] || [ ! -r "$hwmon_device/freq1_input" ]; then
    printf 'no amdgpu hwmon directory under %s carries freq1_input; the delivered graphics clock is what the profile is stated against\n' \
        "$hwmon_root" >&2
    exit 2
fi

# The profile names level indices, so a device whose table carries other
# frequencies at those indices is refused rather than written and read back as
# something else.
for required_pair in $profile_sclk_levels; do
    required_index=${required_pair%%=*}
    required_mhz=${required_pair#*=}
    observed_mhz=$(census_engine_clock_level_mhz "$drm_device/pp_dpm_sclk" \
        "$required_index" 2>/dev/null) || observed_mhz=absent
    if [ "$observed_mhz" != "$required_mhz" ]; then
        printf 'pp_dpm_sclk level %s reads %s MHz where profile %s states %s MHz: %s\n' \
            "$required_index" "$observed_mhz" "$profile_name" "$required_mhz" \
            "$drm_device/pp_dpm_sclk" >&2
        exit 2
    fi
done
for required_pair in $profile_mclk_levels; do
    required_index=${required_pair%%=*}
    required_mhz=${required_pair#*=}
    observed_mhz=$(census_engine_clock_level_mhz "$drm_device/pp_dpm_mclk" \
        "$required_index" 2>/dev/null) || observed_mhz=absent
    if [ "$observed_mhz" != "$required_mhz" ]; then
        printf 'pp_dpm_mclk level %s reads %s MHz where profile %s states %s MHz: %s\n' \
            "$required_index" "$observed_mhz" "$profile_name" "$required_mhz" \
            "$drm_device/pp_dpm_mclk" >&2
        exit 2
    fi
done

snapshot_ksm_run=$(read_ksm_run "$ksm_run_node")
if [ "$snapshot_ksm_run" = unavailable ]; then
    printf 'the KSM run state is unreadable: %s\n' "$ksm_run_node" >&2
    exit 2
fi
# 2 unmerges every merged page. The restore writes the snapshot back, so a
# snapshot of 2 is refused here rather than written back later: this transaction
# writes 0 and 1 alone.
if [ "$snapshot_ksm_run" = 2 ]; then
    printf 'the KSM run state reads 2, which unmerges every merged page and is never written by this transaction: %s\n' \
        "$ksm_run_node" >&2
    exit 2
fi

# The served baseline retains the observed KSM switch through the transaction.
if [ "$profile_ksm_run" = preserve ]; then
    profile_ksm_run=$snapshot_ksm_run
fi

# The child inherits the harness's priority terms, so they are applied to this
# shell and read back from the kernel before anything is written. Lowering a
# nice level requires CAP_SYS_NICE, so a compute-performance profile started
# from an already-niced shell is refused here rather than discovered after the
# performance level is written.
snapshot_harness_nice=$(read_process_nice "$$")
if ! "$renice_command" --priority "$profile_child_nice" --pid "$$" >/dev/null 2>&1; then
    printf 'profile %s states nice %s and renice refused it for pid %s\n' \
        "$profile_name" "$profile_child_nice" "$$" >&2
    exit 2
fi
harness_nice=$(read_process_nice "$$")
if [ "${harness_nice:-unreadable}" != "$profile_child_nice" ]; then
    printf 'profile %s states nice %s and the kernel reads %s; lowering a nice level requires CAP_SYS_NICE\n' \
        "$profile_name" "$profile_child_nice" "${harness_nice:-unreadable}" >&2
    exit 2
fi
snapshot_harness_io_class=$(read_process_io_class "$$")
snapshot_harness_cpu_list=$(read_process_cpu_list "$$")
if ! "$ionice_command" -c "$(io_class_number "$profile_child_io_class")" \
    -p "$$" >/dev/null 2>&1; then
    printf 'profile %s states I/O class %s and ionice refused it for pid %s\n' \
        "$profile_name" "$profile_child_io_class" "$$" >&2
    exit 2
fi
if ! "$taskset_command" -p -c "$profile_child_cpu_list" "$$" >/dev/null 2>&1; then
    printf 'profile %s states cores %s and taskset refused them for pid %s\n' \
        "$profile_name" "$profile_child_cpu_list" "$$" >&2
    exit 2
fi
harness_cpu_list=$(read_process_cpu_list "$$")
harness_io_class=$(read_process_io_class "$$")

if [ ! -d "$state_directory" ]; then
    printf 'the state directory is absent: %s\n' "$state_directory" >&2
    exit 2
fi

# The lease proof names this pid, this descriptor, and a revision the verifier
# validates in its 40-hex form. The runtime tree carries its own manifest on the
# appliance, where this tree is a copy rather than a checkout.
# `sync-runtime-tree.sh` writes that manifest beside `remote/` rather than
# inside it, so the parent is read as well as the script's own directory and a
# runtime copy answers with the head it was synced from.
transaction_revision=${QWEN_COMPUTE_STATE_REVISION:-}
for manifest_candidate in "$script_directory/runtime-tree-manifest.tsv" \
    "$script_directory/../runtime-tree-manifest.tsv"; do
    if [ -n "$transaction_revision" ] || [ ! -r "$manifest_candidate" ]; then
        continue
    fi
    transaction_revision=$(awk -F'\t' '$1 == "git_head" { print $2; exit }' \
        "$manifest_candidate")
done
if [ -z "$transaction_revision" ]; then
    transaction_revision=$(git -C "$script_directory" rev-parse HEAD 2>/dev/null) || \
        transaction_revision=''
fi
case $transaction_revision in
    ????????????????????????????????????????)
        case $transaction_revision in
            *[!0-9a-f]*)
                printf 'the transaction revision is not 40 hexadecimal characters: %s\n' \
                    "$transaction_revision" >&2
                exit 2
                ;;
        esac
        ;;
    *)
        printf 'the transaction revision is not 40 hexadecimal characters: %s; name QWEN_COMPUTE_STATE_REVISION\n' \
            "${transaction_revision:-absent}" >&2
        exit 2
        ;;
esac

# The device belongs to this transaction from here. A write moves the clock
# every workload on the part runs at, so the lease is taken ahead of the first
# write rather than at the command.
census_workload_lease_take "$workload_lease"
lease_proof=$state_directory/.compute-state-external-lease.$$.tsv
census_workload_lease_publish "$workload_lease" "$lease_proof" \
    "$transaction_revision" "$lease_verifier"
printf 'compute_state_lease=held path=%s proof=%s\n' "$workload_lease" "$lease_proof"

state_record=${QWEN_COMPUTE_STATE_RECORD:-$state_directory/compute-state-record.tsv}
arm_environment_record=${QWEN_COMPUTE_STATE_ARM_ENVIRONMENT:-$state_directory/compute-state-arm-environment.tsv}

snapshot_state=$(census_engine_clock_snapshot "$drm_device")
snapshot_dpm_level=${snapshot_state%% *}
snapshot_rest=${snapshot_state#* }
snapshot_sclk_index=${snapshot_rest%% *}
snapshot_mclk_index=${snapshot_rest##* }
snapshot_sclk_mhz=$(read_selected_field "$drm_device/pp_dpm_sclk" value)
snapshot_mclk_mhz=$(read_selected_field "$drm_device/pp_dpm_mclk" value)

# The process terms leave with the process, so the record states what the child
# ran under and the restore covers the two machine-persistent authorities: the
# performance level with its two selections, and the KSM run state.
state_record_new=$state_record.new
{
    printf 'key\tvalue\n'
    printf 'schema\tcompute-state-lease-v1\n'
    printf 'profile\t%s\n' "$profile_name"
    printf 'holder_pid\t%s\n' "$$"
    printf 'drm_device\t%s\n' "$drm_device"
    printf 'hwmon_device\t%s\n' "$hwmon_device"
    printf 'ksm_run_node\t%s\n' "$ksm_run_node"
    printf 'workload_lease\t%s\n' "$workload_lease"
    printf 'lease_proof\t%s\n' "$lease_proof"
    printf 'snapshot_dpm_level\t%s\n' "$snapshot_dpm_level"
    printf 'snapshot_sclk_level\t%s\n' "$snapshot_sclk_index"
    printf 'snapshot_sclk_mhz\t%s\n' "$snapshot_sclk_mhz"
    printf 'snapshot_mclk_level\t%s\n' "$snapshot_mclk_index"
    printf 'snapshot_mclk_mhz\t%s\n' "$snapshot_mclk_mhz"
    printf 'snapshot_ksm_run\t%s\n' "$snapshot_ksm_run"
    printf 'snapshot_harness_nice\t%s\n' "${snapshot_harness_nice:-unreadable}"
    printf 'snapshot_harness_cpu_list\t%s\n' "${snapshot_harness_cpu_list:-unreadable}"
    printf 'snapshot_harness_io_class\t%s\n' "${snapshot_harness_io_class:-unreadable}"
    printf 'applied_dpm_level\t%s\n' "$profile_dpm_level"
    printf 'applied_sclk_selection\t%s\n' "$profile_sclk_selection"
    printf 'applied_mclk_selection\t%s\n' "$profile_mclk_selection"
    printf 'applied_ksm_run\t%s\n' "$profile_ksm_run"
    printf 'power_envelope\t%s\n' "${profile_power_envelope:--}"
    printf 'power_envelope_owner\t%s\n' "${power_envelope_owner:--}"
    printf 'power_envelope_snapshot\t%s\n' "$power_envelope_snapshot"
    printf 'cpu_frequency_cap\t%s\n' "${profile_cpu_frequency_cap:--}"
    printf 'cpu_frequency_cap_owner\t%s\n' "${cpu_frequency_cap_owner:--}"
    printf 'cpu_frequency_cap_snapshot\t%s\n' "$cpu_frequency_cap_snapshot"
    printf 'applied_child_nice\t%s\n' "${harness_nice:-unreadable}"
    printf 'applied_child_cpu_list\t%s\n' "${harness_cpu_list:-unreadable}"
    printf 'applied_child_io_class\t%s\n' "${harness_io_class:-unreadable}"
    printf 'required_gfxclk_mhz\t%s\n' "$profile_required_gfxclk_mhz"
    printf 'required_fclk_mhz\t%s\n' "$profile_required_fclk_mhz"
} >"$state_record_new"
chmod 0600 "$state_record_new"
mv -- "$state_record_new" "$state_record"
printf 'compute_state_record=%s profile=%s snapshot_dpm_level=%s snapshot_sclk_level=%s snapshot_mclk_level=%s snapshot_ksm_run=%s\n' \
    "$state_record" "$profile_name" "$snapshot_dpm_level" "$snapshot_sclk_index" \
    "$snapshot_mclk_index" "$snapshot_ksm_run"

child_pid=''
apply_started=0
restoration_finished=0
restoration_failed=0
clock_expectation=not_reached
child_stop=''
command_status=''
command_name=''

stop_child() {
    [ -n "$child_pid" ] || return 0
    grace_seconds=${QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS:-10}
    kill -TERM "$child_pid" 2>/dev/null || true
    child_stop=term
    stop_attempt=0
    while [ "$stop_attempt" -lt $((grace_seconds * 5)) ]; do
        kill -0 "$child_pid" 2>/dev/null || {
            wait "$child_pid" 2>/dev/null || true
            child_pid=''
            return 0
        }
        stop_attempt=$((stop_attempt + 1))
        sleep 0.2 || true
    done
    kill -KILL "$child_pid" 2>/dev/null || true
    child_stop='kill'
    stop_attempt=0
    while [ "$stop_attempt" -lt 25 ]; do
        kill -0 "$child_pid" 2>/dev/null || {
            wait "$child_pid" 2>/dev/null || true
            child_pid=''
            return 0
        }
        stop_attempt=$((stop_attempt + 1))
        sleep 0.2 || true
    done
    # kill -0 still found the child alive after SIGKILL and the 5-second poll,
    # which is a process the kernel cannot yet reap -- most likely uninterruptible
    # I/O sleep -- rather than one that will exit shortly. `wait` blocks until the
    # child is reaped, so calling it here would trade the bounded shutdown this
    # function exists to provide for an unbounded one in exactly the case it is
    # supposed to cover. Restoration runs over the leftover descendant instead;
    # init reparents and eventually reaps it once it does exit.
    child_stop=unreaped
}

remove_lease_proof() {
    if [ -n "${lease_proof:-}" ]; then
        rm -f -- "$lease_proof"
        lease_proof=''
    fi
}

# One restored authority, polled because the firmware moves a starred level
# after the write returns. Prints nothing and reports through its status, so the
# caller names the field.
await_restored_value() {
    await_reader=$1
    await_reader_argument=$2
    await_expected=$3
    await_attempt=0
    while :; do
        await_observed=$("$await_reader" "$await_reader_argument")
        [ "$await_observed" != "$await_expected" ] || return 0
        await_attempt=$((await_attempt + 1))
        if [ "$await_attempt" -ge "$((restore_deadline_s * 10))" ]; then
            printf '%s\n' "$await_observed"
            return 1
        fi
        sleep "$poll_interval_s"
    done
}

# The restore acts once, survives a failed write, and reports each authority it
# read back. census_engine_clock_restore owns the performance level and its two
# selections and returns 0 whatever it observed, so the verification is stated
# here: a value that fails to return names itself on a `restoration=failed` line
# and ends the transaction non-zero.
finish_transaction() {
    [ "$restoration_finished" -eq 0 ] || return 0
    restoration_finished=1
    [ "$apply_started" -eq 1 ] || return 0

    restoration_failures=''
    # The reversal runs in the reverse of the application order, so the package
    # budget the SMU holds is returned ahead of the memory scanner and the
    # performance level. power-envelope.sh owns its own snapshot and verifies
    # its own read-back, so its status is the whole claim here; an apply that
    # refused before writing the snapshot leaves nothing to reverse.
    if [ -n "$profile_power_envelope" ] &&
        [ "$(LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' \
            "$power_envelope_snapshot" 2>/dev/null)" = "$power_envelope_owner" ]; then
        if ! QWEN_POWER_ENVELOPE_SNAPSHOT="$power_envelope_snapshot" \
            QWEN_POWER_ENVELOPE_OWNER="$power_envelope_owner" \
            "$power_envelope_command" restore >&2; then
            restoration_failures="${restoration_failures}power_envelope=unreturned(profile=$profile_power_envelope) "
        fi
    fi

    # The CPU cap returns ahead of the memory scanner and the performance
    # level, the same position the package budget holds: cpu-frequency-cap.sh
    # owns its own snapshot and read-back, so its status is the whole claim
    # here.
    if [ -n "$profile_cpu_frequency_cap" ] &&
        [ "$(LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' \
            "$cpu_frequency_cap_snapshot" 2>/dev/null)" = "$cpu_frequency_cap_owner" ]; then
        if ! QWEN_CPU_FREQUENCY_CAP_SNAPSHOT="$cpu_frequency_cap_snapshot" \
            QWEN_CPU_FREQUENCY_CAP_OWNER="$cpu_frequency_cap_owner" \
            "$cpu_frequency_cap_command" restore >&2; then
            restoration_failures="${restoration_failures}cpu_frequency_cap=unreturned(profile=$profile_cpu_frequency_cap) "
        fi
    fi

    if [ "$snapshot_ksm_run" != "$profile_ksm_run" ]; then
        printf '%s\n' "$snapshot_ksm_run" | sudo -n tee "$ksm_run_node" \
            >/dev/null 2>&1 || true
    fi
    census_engine_clock_restore "$drm_device" "$snapshot_state"

    if ! restore_observed=$(await_restored_value read_dpm_level \
        "$drm_device/power_dpm_force_performance_level" "$snapshot_dpm_level"); then
        restoration_failures="${restoration_failures}dpm_level=${restore_observed:-unreadable}(want=$snapshot_dpm_level) "
    fi
    # census_engine_clock_restore writes the two selections back only under a
    # `manual` snapshot, because a governor moves the star under every other
    # level and comparing it there reports the governor rather than the restore.
    # Under every other snapshot the level word carries the whole claim:
    # amdgpu_set_power_dpm_force_performance_level hands the level back to the
    # governor, which owns both bounds from that point, and no sysfs surface
    # reports a residual restriction beside the star the governor is moving. The
    # restore line names which of the two it verified rather than printing a
    # star it did not compare.
    restored_selections=governor-owned
    if [ "$snapshot_dpm_level" = manual ]; then
        restored_selections=verified
        if [ "$snapshot_sclk_index" != - ] &&
            ! restore_observed=$(await_restored_value read_sclk_index "$drm_device" \
                "$snapshot_sclk_index"); then
            restoration_failures="${restoration_failures}sclk_level=${restore_observed:-unreadable}(want=$snapshot_sclk_index) "
        fi
        if [ "$snapshot_mclk_index" != - ] &&
            ! restore_observed=$(await_restored_value read_mclk_index "$drm_device" \
                "$snapshot_mclk_index"); then
            restoration_failures="${restoration_failures}mclk_level=${restore_observed:-unreadable}(want=$snapshot_mclk_index) "
        fi
    fi
    if ! restore_observed=$(await_restored_value read_ksm_run "$ksm_run_node" \
        "$snapshot_ksm_run"); then
        restoration_failures="${restoration_failures}ksm_run=${restore_observed:-unreadable}(want=$snapshot_ksm_run) "
    fi

    if [ -n "$restoration_failures" ]; then
        restoration_failed=1
        printf 'restoration=failed profile=%s fields=%s\n' "$profile_name" \
            "${restoration_failures% }" >&2
        printf 'restoration=failed profile=%s fields=%s record=%s\n' \
            "$profile_name" "${restoration_failures% }" "$state_record"
    else
        printf 'restoration=held profile=%s dpm_level=%s selections=%s sclk_level=%s mclk_level=%s ksm_run=%s power_envelope=%s cpu_frequency_cap=%s\n' \
            "$profile_name" "$snapshot_dpm_level" "$restored_selections" \
            "$snapshot_sclk_index" "$snapshot_mclk_index" "$snapshot_ksm_run" \
            "${profile_power_envelope:--}" "${profile_cpu_frequency_cap:--}"
    fi
}

# The lease is released last: the descriptor closes when this shell exits, and
# the proof that names it is removed ahead of that so no file outlives the
# holding it describes.
cleanup() {
    cleanup_status=$?
    stop_child
    finish_transaction
    remove_lease_proof
    if [ -n "$command_name" ]; then
        printf 'compute_state_command=%s status=%s profile=%s child_stop=%s\n' \
            "$command_name" "${command_status:-interrupted}" "$profile_name" "$child_stop"
    fi
    if [ "$restoration_failed" -eq 1 ]; then
        exit 4
    fi
    exit "$cleanup_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

apply_started=1
census_engine_clock_write_level "$profile_dpm_level" "$drm_device"
if [ "$profile_write_clock_selection" -eq 1 ]; then
    applied_sclk=$(census_engine_clock_select pp_dpm_sclk "$drm_device" \
        "$profile_sclk_selection" 1)
    # The fabric selection is written and read back rather than required: the
    # firmware caps a 1067 MHz hard minimum at 933 and stars what it chose, so
    # the expectation below is the set of frequencies the profile's levels
    # name.
    applied_mclk=$(census_engine_clock_select pp_dpm_mclk "$drm_device" \
        "$profile_mclk_selection" 0)
else
    # `auto` writes the level word alone and leaves the governor to move the
    # star on its own schedule, so neither table is written here.
    applied_sclk=auto
    applied_mclk=auto
fi
if [ "$snapshot_ksm_run" != "$profile_ksm_run" ]; then
    census_engine_clock_write "$profile_ksm_run" "$ksm_run_node"
fi
# The CPU cap is applied ahead of the package budget and the clock proof, so
# both terms are live before the delivered graphics clock is read. A refusal
# here ends the transaction through the trap, which returns the cap the apply
# had already written.
if [ -n "$profile_cpu_frequency_cap" ]; then
    QWEN_CPU_FREQUENCY_CAP_SNAPSHOT="$cpu_frequency_cap_snapshot" \
        QWEN_CPU_FREQUENCY_CAP_OWNER="$cpu_frequency_cap_owner" \
        "$cpu_frequency_cap_command" apply "$profile_cpu_frequency_cap"
fi
# The package budget is applied ahead of the clock proof, so the delivered
# graphics clock is read under the profile's whole state rather than under its
# clock half. A refusal here ends the transaction through the trap, which
# returns the budget the apply had already written.
if [ -n "$profile_power_envelope" ]; then
    QWEN_POWER_ENVELOPE_SNAPSHOT="$power_envelope_snapshot" \
        QWEN_POWER_ENVELOPE_OWNER="$power_envelope_owner" \
        "$power_envelope_command" apply "$profile_power_envelope"
fi
printf 'compute_state_applied=%s dpm_level=%s sclk=%s mclk=%s ksm_run=%s power_envelope=%s cpu_frequency_cap=%s\n' \
    "$profile_name" "$profile_dpm_level" "$applied_sclk" "$applied_mclk" \
    "$profile_ksm_run" "${profile_power_envelope:--}" "${profile_cpu_frequency_cap:--}"

# The profile is a claim about what the part delivers, so it is proven before
# the command runs, except under `auto`: the governor there is free to move
# the star on its own schedule and no fixed frequency is a met or unmet
# expectation, so the observed values are recorded rather than gated. The
# graphics half reads hwmon and the fabric half reads the starred pp_dpm_mclk
# step, and each is named separately so a refusal states which one missed.
clock_attempt=0
observed_gfxclk=unavailable
observed_fclk=unavailable
if [ "$profile_write_clock_selection" -eq 0 ]; then
    observed_gfxclk=$(read_delivered_gfxclk_mhz)
    observed_fclk=$(read_selected_field "$drm_device/pp_dpm_mclk" value)
    clock_expectation=unverified
    printf 'clock_expectation=unverified profile=%s gfxclk_mhz=%s fclk_mhz=%s\n' \
        "$profile_name" "$observed_gfxclk" "$observed_fclk"
else
    while :; do
        observed_gfxclk=$(read_delivered_gfxclk_mhz)
        observed_fclk=$(read_selected_field "$drm_device/pp_dpm_mclk" value)
        gfxclk_ok=0
        fclk_ok=0
        if within_tolerance "$observed_gfxclk" "$profile_required_gfxclk_mhz" \
            "$clock_tolerance"; then
            gfxclk_ok=1
        fi
        if value_in_set "$observed_fclk" "$profile_required_fclk_mhz"; then
            fclk_ok=1
        fi
        if [ "$gfxclk_ok" -eq 1 ] && [ "$fclk_ok" -eq 1 ]; then
            clock_expectation=reached
            break
        fi
        clock_attempt=$((clock_attempt + 1))
        if [ "$clock_attempt" -ge "$((clock_deadline_s * 10))" ]; then
            break
        fi
        sleep "$poll_interval_s"
    done
fi

if [ "$profile_write_clock_selection" -eq 1 ] && [ "$clock_expectation" != reached ]; then
    printf 'clock_expectation=unreached profile=%s gfxclk_mhz=%s required_gfxclk_mhz=%s fclk_mhz=%s required_fclk_mhz=%s deadline_s=%s\n' \
        "$profile_name" "$observed_gfxclk" "$profile_required_gfxclk_mhz" \
        "$observed_fclk" "$profile_required_fclk_mhz" "$clock_deadline_s" >&2
    exit 3
fi
if [ "$profile_write_clock_selection" -eq 1 ]; then
    printf 'clock_expectation=reached profile=%s gfxclk_mhz=%s fclk_mhz=%s\n' \
        "$profile_name" "$observed_gfxclk" "$observed_fclk"
fi

# The command runs under the closed environment census_arm_exec applies, so an
# ambient GGML_VK_*, RADV_*, VK_*, LLAMA_*, or QWEN_* setting reaches no
# transaction and the record states what did. The lease proof is forwarded
# because a served command reads it to skip taking the lock this shell holds;
# QWEN_COMPUTE_STATE_FORWARD names whatever else one needs, as space-separated
# NAME=VALUE assignments, which is the whole vocabulary because census_arm_exec
# refuses a value carrying a tab or a newline and a space separates the list.
#
# The subshell forks and execs, so $! is the command itself and a terminating
# signal reaches it rather than a wrapper that would leave it running.
#
# `env -i` replaces the environment and leaves the descriptor table alone, so
# the command inherits descriptor 8 and the lease it carries. This shell
# signals the command it started and closes its own descriptor at exit; a
# grandchild the command forked and left behind holds the inherited descriptor
# until it exits, which is what a caller passing a command that backgrounds
# work is choosing.
command_name=$1
(
    # shellcheck disable=SC2086  # the forward list is word-split by design
    census_arm_exec "$arm_environment_record" \
        QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
        QWEN_COMPUTE_STATE_PROFILE="$profile_name" \
        QWEN_COMPUTE_STATE_RECORD="$state_record" \
        ${QWEN_COMPUTE_STATE_FORWARD:-} \
        -- \
        "$@"
) &
child_pid=$!
set +e
wait "$child_pid"
command_status=$?
set -e
child_pid=''

exit "$command_status"
