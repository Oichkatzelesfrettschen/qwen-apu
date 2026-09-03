#!/bin/sh
set -eu

# compute-state-lease.sh writes kernel power and memory-management interfaces
# through sudo, so its whole transaction is driven here against a fixture sysfs
# tree under mktemp with no privilege at all. Every path the script reads
# resolves through QWEN_SYSFS_ROOT, so the fixture supplies one root and the
# script derives the drm device, the hwmon root, and the KSM run node from it.
#
# One stub stands for the privileged writer and models the part's firmware: a
# level index written to pp_dpm_sclk or pp_dpm_mclk moves that table's star,
# a graphics selection moves the hwmon freq1_input the profile expectation is
# read from, and a fabric level above the fixture's cap is clamped the way the
# SMU10 firmware clamps a 1067 MHz hard minimum to 933. A control file switches
# the firmware's behavior per case, so the stub itself never reads the invoking
# environment the closed arm environment removes.
#
# The command is an observer rather than a placeholder: it records the live
# fixture values, its own nice level, its own affinity, and its own environment
# into a log, which is what makes the applied profile provable while the command
# runs rather than only before and after it.
#
# The lease, its published proof, and verify-external-vulkan-lease.py are the
# tree's own and run unstubbed against a real flock on a fixture lock file.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
transaction=$script_directory/compute-state-lease.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'compute_state_fixture_directory=%s\n' "$temporary_directory" >&2
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
drm_fixture=$sysfs_fixture/class/drm/card1/device
hwmon_fixture=$sysfs_fixture/class/hwmon
ksm_fixture=$sysfs_fixture/kernel/mm/ksm
state_fixture=$temporary_directory/state
stub_directory=$temporary_directory/stubs
controls=$temporary_directory/firmware-controls.tsv
observer_log=$temporary_directory/observer.log
mkdir -p "$drm_fixture" "$hwmon_fixture/hwmon0" "$hwmon_fixture/hwmon1" \
    "$ksm_fixture" "$state_fixture" "$stub_directory"
chmod 700 "$state_fixture"

lease_fixture=$state_fixture/vulkan-workload.lock
: >"$lease_fixture"
: >"$controls"

# The snapshot state is `manual` with the middle graphics step and the 400 MHz
# fabric step selected, so both profiles move every authority they write and a
# restore that missed one is visible in the table rather than only in a level
# word. census_engine_clock_restore writes the two selections back under a
# `manual` snapshot alone, which is the snapshot this fixture takes by default;
# one case below replaces the level word with the appliance's own `auto` and
# reads the other restore path.
reset_fixture() {
    printf 'manual\n' >"$drm_fixture/power_dpm_force_performance_level"
    printf '0: 200Mhz\n1: 400Mhz *\n2: 1100Mhz\n' >"$drm_fixture/pp_dpm_sclk"
    printf '0: 0Mhz\n1: 400Mhz *\n2: 933Mhz\n3: 1067Mhz\n' >"$drm_fixture/pp_dpm_mclk"
    printf '400000000\n' >"$hwmon_fixture/hwmon1/freq1_input"
    printf '1\n' >"$ksm_fixture/run"
    : >"$controls"
    : >"$observer_log"
}

printf 'nvme\n' >"$hwmon_fixture/hwmon0/name"
printf '41000\n' >"$hwmon_fixture/hwmon0/temp1_input"
printf 'amdgpu\n' >"$hwmon_fixture/hwmon1/name"
printf '75000\n' >"$hwmon_fixture/hwmon1/temp1_input"
reset_fixture

set_control() {
    printf '%s\t%s\n' "$1" "$2" >>"$controls"
}

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'controls=%s\n' "$controls"
    printf 'sclk_table=%s\n' "$drm_fixture/pp_dpm_sclk"
    printf 'gfxclk_node=%s\n' "$hwmon_fixture/hwmon1/freq1_input"
    cat <<'STUB'
control() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; found = 1 }
        END { if (found) print value }' "$controls"
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
    *) exit 1 ;;
esac

target=$2
content=$(cat)
leaf=${target##*/}

# The firmware model: a table takes one or more level indices, clamps each to
# its own cap, and stars the highest survivor. The graphics table then moves
# the delivered frequency hwmon reports.
select_level() {
    cap=$(control "${leaf}_cap")
    selected=''
    for level in $content; do
        case $level in
            '' | *[!0-9]*) exit 1 ;;
        esac
        if [ -n "$cap" ] && [ "$level" -gt "$cap" ]; then
            level=$cap
        fi
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
        if [ "$(control refuse_sclk_write)" = 1 ]; then
            printf 'tee: %s: Invalid argument\n' "$target" >&2
            exit 1
        fi
        selected=$(select_level)
        if [ "$(control gfxclk_stuck)" != 1 ]; then
            awk -v want="$selected" 'match($0, /[0-9]+[Mm][Hh]z/) {
                    entry = $1
                    sub(/:$/, "", entry)
                    if (entry == want) {
                        printf "%d\n", substr($0, RSTART, RLENGTH) * 1000000
                    }
                }' "$sclk_table" >"$gfxclk_node"
        fi
        ;;
    pp_dpm_mclk)
        select_level >/dev/null
        ;;
    run)
        if [ "$(control refuse_ksm_write)" = "$content" ]; then
            printf 'tee: %s: Invalid argument\n' "$target" >&2
            exit 1
        fi
        printf '%s\n' "$content" >"$target"
        ;;
    power_dpm_force_performance_level)
        if [ "$(control refuse_level_write)" = "$content" ]; then
            printf 'tee: %s: Invalid argument\n' "$target" >&2
            exit 1
        fi
        printf '%s\n' "$content" >"$target"
        ;;
    *)
        printf '%s\n' "$content" >"$target"
        ;;
esac
printf '%s\n' "$content"
STUB
} >"$stub_directory/sudo"

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'observer_log=%s\n' "$observer_log"
    printf 'drm_device=%s\n' "$drm_fixture"
    printf 'gfxclk_node=%s\n' "$hwmon_fixture/hwmon1/freq1_input"
    printf 'ksm_run_node=%s\n' "$ksm_fixture/run"
    printf 'controls=%s\n' "$controls"
    cat <<'OBSERVER'
observer_trap_term=$(awk -F'\t' '$1 == "observer_trap_term" { value = $2; found = 1 }
    END { if (found) print value }' "$controls")
# A command that traps SIGTERM and keeps running needs the bounded SIGKILL
# escalation to stop it. The trap and the descriptor-8 close run before
# anything else -- including the log write a caller polls for readiness on --
# so a SIGTERM landing the instant the caller sees that readiness marker is
# already ignored rather than racing the default disposition that would still
# be armed if `trap` ran any later. Descriptor 8 carries the lease and `env -i`
# leaves the descriptor table alone, so this process closes its own copy ahead
# of the loop rather than after: a `sleep 1` forked from inside the loop would
# otherwise inherit the open descriptor, and the SIGKILL that ends this process
# reaches neither that grandchild nor the lease it is still holding, leaving
# the lease held for up to the grandchild's own remaining sleep after this
# process is gone.
if [ "$observer_trap_term" = 1 ]; then
    exec 8>&-
    trap : TERM
fi
starred() {
    awk '/\*/ && match($0, /[0-9]+[Mm][Hh]z/) {
            entry = $1
            sub(/:$/, "", entry)
            printf "%s:%d\n", entry, substr($0, RSTART, RLENGTH)
            exit
        }' "$1"
}
own_nice=$(awk '{ line = $0; sub(/^.*[)] /, "", line); split(line, f, / /); print f[17]; exit }' \
    /proc/self/stat)
{
    printf 'observed_dpm_level\t%s\n' "$(cat "$drm_device/power_dpm_force_performance_level")"
    printf 'observed_sclk\t%s\n' "$(starred "$drm_device/pp_dpm_sclk")"
    printf 'observed_mclk\t%s\n' "$(starred "$drm_device/pp_dpm_mclk")"
    printf 'observed_gfxclk_hz\t%s\n' "$(cat "$gfxclk_node")"
    printf 'observed_ksm_run\t%s\n' "$(cat "$ksm_run_node")"
    printf 'observed_nice\t%s\n' "$own_nice"
    printf 'observed_cpu_list\t%s\n' "$(taskset -p -c $$ | awk '{ print $NF }')"
    printf 'observed_io_class\t%s\n' "$(ionice -p $$ | awk '{ print $1 }' | tr -d ':')"
    printf 'observed_argument\t%s\n' "${1:-none}"
    env | sed 's/^/observed_environment\t/'
} >>"$observer_log"
# The trap and the descriptor close already ran, ahead of the log write above;
# this is the loop that keeps the process alive under it.
if [ "$observer_trap_term" = 1 ]; then
    while :; do
        sleep 1
    done
fi
observer_sleep=$(awk -F'\t' '$1 == "observer_sleep" { value = $2; found = 1 }
    END { if (found) print value }' "$controls")
# The wait replaces this process rather than forking one. `env -i` leaves the
# descriptor table alone, so the transaction's lease descriptor reaches the
# command, and a forked grandchild would hold that descriptor past the signal
# that ended its parent.
if [ -n "$observer_sleep" ]; then
    exec sleep "$observer_sleep"
fi
exit 0
OBSERVER
} >"$stub_directory/observer"

chmod +x "$stub_directory/sudo" "$stub_directory/observer"

exec_transaction() {
    exec env PATH="$stub_directory:$PATH" \
        GGML_VK_Q4K_SIDEPLANE=0 \
        QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=65536 \
        QWEN_SYSFS_ROOT="$sysfs_fixture" \
        QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
        QWEN_COMPUTE_STATE_REVISION=0123456789abcdef0123456789abcdef01234567 \
        QWEN_COMPUTE_STATE_CLOCK_DEADLINE_S=1 \
        QWEN_COMPUTE_STATE_RESTORE_DEADLINE_S=1 \
        "$transaction" "$@"
}

run_transaction() {
    ( exec_transaction "$@" )
}

fixture_state() {
    printf '%s %s %s %s %s' \
        "$(cat "$drm_fixture/power_dpm_force_performance_level")" \
        "$(awk '/\*/ { entry = $1; sub(/:$/, "", entry); print entry; exit }' \
            "$drm_fixture/pp_dpm_sclk")" \
        "$(awk '/\*/ { entry = $1; sub(/:$/, "", entry); print entry; exit }' \
            "$drm_fixture/pp_dpm_mclk")" \
        "$(cat "$hwmon_fixture/hwmon1/freq1_input")" \
        "$(cat "$ksm_fixture/run")"
}

snapshot_fixture_state='manual 1 1 400000000 1'

observer_field() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$observer_log"
}

record_field() {
    awk -F'\t' -v key="$2" '$1 == key { print $2; exit }' "$1" 2>/dev/null || true
}

# usage: a bare invocation names both forms and the two profiles.
usage_status=0
"$transaction" >"$temporary_directory/usage.log" 2>&1 || usage_status=$?
if [ "$usage_status" -eq 2 ] &&
    grep -q '^usage: .*PROFILE COMMAND \[ARG...\]$' "$temporary_directory/usage.log" &&
    grep -q 'measure-fixed serve-performance-candidate' "$temporary_directory/usage.log"; then
    report 0 usage_names_both_forms
else
    report 1 usage_names_both_forms
fi

# high and profile_peak are refused by name rather than treated as unknown,
# because each is a level a reader would reasonably reach for and each collapses
# the fabric clock on this part.
prohibition_failures=0
for prohibited_level in high profile_peak; do
    reset_fixture
    prohibited_status=0
    run_transaction "$prohibited_level" "$stub_directory/observer" \
        >"$temporary_directory/prohibited-$prohibited_level.log" 2>&1 ||
        prohibited_status=$?
    if [ "$prohibited_status" -ne 2 ] ||
        ! grep -q 'collapses the starred pp_dpm_mclk fabric state to 400 MHz' \
            "$temporary_directory/prohibited-$prohibited_level.log" ||
        [ "$(fixture_state)" != "$snapshot_fixture_state" ]; then
        prohibition_failures=1
        printf 'prohibited level %s was not refused by name\n' "$prohibited_level" >&2
    fi
done
report "$prohibition_failures" refuses_high_and_profile_peak_by_name

# QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS reaches `$((grace_seconds * 5))` inside
# stop_child, which cleanup calls from the EXIT trap; a non-integer value there
# is a shell arithmetic error that would abort the trap ahead of
# finish_transaction and leave the applied DPM/KSM state unrestored. It is
# refused here, before the first write, instead.
reset_fixture
grace_status=0
QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS=abc run_transaction measure-fixed \
    "$stub_directory/observer" >"$temporary_directory/grace.log" 2>&1 ||
    grace_status=$?
if [ "$grace_status" -eq 2 ] &&
    grep -q '^QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS is not a non-negative integer: abc$' \
        "$temporary_directory/grace.log" &&
    [ ! -s "$observer_log" ] &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 refuses_a_non_integer_stop_grace_before_the_first_write
else
    report 1 refuses_a_non_integer_stop_grace_before_the_first_write
    cat "$temporary_directory/grace.log" >&2
fi

# A merely large grace value is valid arithmetic but defeats the bounded
# shutdown the setting exists to provide, so the ceiling refuses it the same
# way: before the first write, rather than leaving stop_child to poll for it.
reset_fixture
grace_ceiling_status=0
QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS=3601 run_transaction measure-fixed \
    "$stub_directory/observer" >"$temporary_directory/grace-ceiling.log" 2>&1 ||
    grace_ceiling_status=$?
if [ "$grace_ceiling_status" -eq 2 ] &&
    grep -q '^QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS exceeds the 3600 second maximum: 3601$' \
        "$temporary_directory/grace-ceiling.log" &&
    [ ! -s "$observer_log" ] &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 refuses_a_stop_grace_above_the_ceiling_before_the_first_write
else
    report 1 refuses_a_stop_grace_above_the_ceiling_before_the_first_write
    cat "$temporary_directory/grace-ceiling.log" >&2
fi

# The clean transaction: apply, prove the clocks, run, restore, verify.
reset_fixture
clean_status=0
run_transaction measure-fixed "$stub_directory/observer" clean-arm \
    >"$temporary_directory/clean.log" 2>&1 || clean_status=$?
if [ "$clean_status" -eq 0 ] &&
    grep -q '^compute_state_lease=held ' "$temporary_directory/clean.log" &&
    grep -q '^compute_state_applied=measure-fixed dpm_level=manual sclk=2 1100 mclk=2 933 ksm_run=0$' \
        "$temporary_directory/clean.log" &&
    grep -q '^clock_expectation=reached profile=measure-fixed gfxclk_mhz=1100 fclk_mhz=933$' \
        "$temporary_directory/clean.log" &&
    grep -q '^restoration=held profile=measure-fixed dpm_level=manual selections=verified sclk_level=1 mclk_level=1 ksm_run=1$' \
        "$temporary_directory/clean.log" &&
    [ "$(grep -c '^compute_state_command=' "$temporary_directory/clean.log")" -eq 1 ] &&
    grep -q ' status=0 profile=measure-fixed child_stop=$' "$temporary_directory/clean.log" &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 clean_apply_run_restore
else
    report 1 clean_apply_run_restore
    cat "$temporary_directory/clean.log" >&2
fi

# The observer proves the profile while the command ran, which a comparison of
# the state before and after cannot.
if [ "$(observer_field observed_dpm_level)" = manual ] &&
    [ "$(observer_field observed_sclk)" = '2:1100' ] &&
    [ "$(observer_field observed_mclk)" = '2:933' ] &&
    [ "$(observer_field observed_gfxclk_hz)" = 1100000000 ] &&
    [ "$(observer_field observed_ksm_run)" = 0 ] &&
    [ "$(observer_field observed_nice)" = 19 ] &&
    [ "$(observer_field observed_io_class)" = idle ] &&
    [ "$(observer_field observed_argument)" = clean-arm ]; then
    report 0 command_observes_the_applied_profile
else
    report 1 command_observes_the_applied_profile
    cat "$observer_log" >&2
fi

case $(observer_field observed_cpu_list) in
    0,1 | 0-1) report 0 command_inherits_the_profile_affinity ;;
    *)
        report 1 command_inherits_the_profile_affinity
        printf 'observed_cpu_list=%s\n' "$(observer_field observed_cpu_list)" >&2
        ;;
esac

# The KSM run state is stopped for the command and returned afterwards, which is
# the whole round trip: 0 while the decode streams, the snapshot value after.
if [ "$(observer_field observed_ksm_run)" = 0 ] &&
    [ "$(cat "$ksm_fixture/run")" = 1 ]; then
    report 0 ksm_run_round_trips_zero_and_back
else
    report 1 ksm_run_round_trips_zero_and_back
fi

# The state record names every snapshot the restore is verified against.
clean_record=$state_fixture/compute-state-record.tsv
if [ "$(record_field "$clean_record" schema)" = compute-state-lease-v1 ] &&
    [ "$(record_field "$clean_record" profile)" = measure-fixed ] &&
    [ "$(record_field "$clean_record" snapshot_dpm_level)" = manual ] &&
    [ "$(record_field "$clean_record" snapshot_sclk_level)" = 1 ] &&
    [ "$(record_field "$clean_record" snapshot_mclk_level)" = 1 ] &&
    [ "$(record_field "$clean_record" snapshot_ksm_run)" = 1 ] &&
    [ "$(record_field "$clean_record" applied_child_nice)" = 19 ] &&
    [ "$(record_field "$clean_record" required_gfxclk_mhz)" = 1100 ] &&
    [ "$(record_field "$clean_record" required_fclk_mhz)" = 933 ]; then
    report 0 state_record_carries_every_snapshot
else
    report 1 state_record_carries_every_snapshot
    cat "$clean_record" >&2
fi

# The command runs under the closed arm environment and reaches the lease
# through the published proof rather than through the lock this shell holds.
clean_proof=$(grep -o 'proof=[^ ]*' "$temporary_directory/clean.log" | head -n 1)
clean_proof=${clean_proof#proof=}
if grep -q '^observed_environment	QWEN_VULKAN_EXTERNAL_LEASE_PROOF=' "$observer_log" &&
    grep -q '^observed_environment	QWEN_COMPUTE_STATE_PROFILE=measure-fixed$' "$observer_log" &&
    ! grep -q '^observed_environment	GGML_VK_Q4K_SIDEPLANE=' "$observer_log" &&
    ! grep -q '^observed_environment	QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=' "$observer_log" &&
    [ -n "$clean_proof" ] && [ ! -e "$clean_proof" ]; then
    report 0 command_environment_is_closed_and_carries_the_lease_proof
else
    report 1 command_environment_is_closed_and_carries_the_lease_proof
    printf 'proof=%s\n' "${clean_proof:-absent}" >&2
fi

# The serving profile writes the fabric range and accepts the level the firmware
# clamps it to, so a 1067 MHz request that lands at 933 is a met expectation.
reset_fixture
set_control pp_dpm_mclk_cap 2
serving_status=0
run_transaction serve-performance-candidate "$stub_directory/observer" \
    >"$temporary_directory/serving.log" 2>&1 || serving_status=$?
if [ "$serving_status" -eq 0 ] &&
    grep -q '^compute_state_applied=serve-performance-candidate dpm_level=manual sclk=2 1100 mclk=2 933 ksm_run=0$' \
        "$temporary_directory/serving.log" &&
    grep -q '^clock_expectation=reached profile=serve-performance-candidate gfxclk_mhz=1100 fclk_mhz=933$' \
        "$temporary_directory/serving.log" &&
    [ "$(observer_field observed_nice)" = 0 ] &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 serving_profile_accepts_the_clamped_fabric_level
else
    report 1 serving_profile_accepts_the_clamped_fabric_level
    cat "$temporary_directory/serving.log" >&2
fi

# The appliance presents an `auto` snapshot, since the launch chain writes no
# performance level. census_engine_clock_restore hands the level back to the
# governor there and writes neither selection, and this transaction verifies
# neither star for the same reason, so the restore line states which of the two
# it verified rather than printing a star it did not compare. The level word
# carries the whole claim on that path, and this case is what proves it runs.
reset_fixture
printf 'auto\n' >"$drm_fixture/power_dpm_force_performance_level"
auto_status=0
run_transaction measure-fixed "$stub_directory/observer" auto-arm \
    >"$temporary_directory/auto.log" 2>&1 || auto_status=$?
if [ "$auto_status" -eq 0 ] &&
    [ "$(observer_field observed_dpm_level)" = manual ] &&
    [ "$(observer_field observed_sclk)" = '2:1100' ] &&
    grep -q '^restoration=held profile=measure-fixed dpm_level=auto selections=governor-owned sclk_level=1 mclk_level=1 ksm_run=1$' \
        "$temporary_directory/auto.log" &&
    [ "$(cat "$drm_fixture/power_dpm_force_performance_level")" = auto ] &&
    [ "$(cat "$ksm_fixture/run")" = 1 ]; then
    report 0 auto_snapshot_restores_the_level_and_names_the_governor
else
    report 1 auto_snapshot_restores_the_level_and_names_the_governor
    cat "$temporary_directory/auto.log" >&2
fi

# The lease: another Vulkan workload holding it means the level this transaction
# would write reaches that workload, so it refuses before the first write.
reset_fixture
lease_flag=$temporary_directory/lease-held
: >"$lease_flag"
(
    exec 7>"$lease_fixture"
    flock 7
    while [ -e "$lease_flag" ]; do
        sleep 0.05
    done
) &
lease_holder_pid=$!
lease_held() {
    lease_probe_status=0
    flock -n -E 75 "$lease_fixture" true || lease_probe_status=$?
    [ "$lease_probe_status" -eq 75 ]
}
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && ! lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
held_status=0
run_transaction measure-fixed "$stub_directory/observer" \
    >"$temporary_directory/held.log" 2>&1 || held_status=$?
rm -f -- "$lease_flag"
wait "$lease_holder_pid" 2>/dev/null || true
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
if [ "$held_status" -eq 2 ] &&
    grep -q 'another Vulkan workload holds the shared lease' "$temporary_directory/held.log" &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ] &&
    [ ! -s "$observer_log" ]; then
    report 0 refuses_while_another_workload_holds_the_lease
else
    report 1 refuses_while_another_workload_holds_the_lease
    cat "$temporary_directory/held.log" >&2
fi

# The profile is a claim about what the part delivers. A graphics clock that
# never reaches the level's own frequency ends the transaction before the
# command runs, and the restore still holds.
reset_fixture
set_control gfxclk_stuck 1
unreached_status=0
run_transaction measure-fixed "$stub_directory/observer" \
    >"$temporary_directory/unreached.log" 2>&1 || unreached_status=$?
if [ "$unreached_status" -eq 3 ] &&
    grep -q '^clock_expectation=unreached profile=measure-fixed gfxclk_mhz=400 required_gfxclk_mhz=1100 fclk_mhz=933 required_fclk_mhz=933 ' \
        "$temporary_directory/unreached.log" &&
    grep -q '^restoration=held ' "$temporary_directory/unreached.log" &&
    [ ! -s "$observer_log" ] &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 unreached_clock_expectation_refuses_before_the_command
else
    report 1 unreached_clock_expectation_refuses_before_the_command
    cat "$temporary_directory/unreached.log" >&2
fi

# A value that fails to return is a machine-state incident: it dominates the
# command's own status, so a command that exited 0 still ends the transaction
# non-zero and the failing field is named.
reset_fixture
set_control refuse_ksm_write 1
incident_status=0
run_transaction measure-fixed /bin/true \
    >"$temporary_directory/incident.log" 2>&1 || incident_status=$?
printf '1\n' >"$ksm_fixture/run"
if [ "$incident_status" -eq 4 ] &&
    grep -q '^restoration=failed profile=measure-fixed fields=ksm_run=0(want=1) record=' \
        "$temporary_directory/incident.log" &&
    ! grep -q '^restoration=held ' "$temporary_directory/incident.log"; then
    report 0 failed_restoration_is_an_incident_over_a_successful_command
else
    report 1 failed_restoration_is_an_incident_over_a_successful_command
    printf 'status=%s\n' "$incident_status" >&2
    cat "$temporary_directory/incident.log" >&2
fi

# A terminating signal reaches the transaction while the command is live. The
# command is reached by exec rather than through a wrapper, so the signal ends
# the whole transaction and the restore runs from the trap.
reset_fixture
set_control observer_sleep 8
term_output=$temporary_directory/term.log
{ exec_transaction measure-fixed "$stub_directory/observer" term-arm; } \
    >"$term_output" 2>&1 &
term_pid=$!
term_attempt=0
while [ "$term_attempt" -lt 200 ]; do
    if grep -q '^observed_argument	term-arm$' "$observer_log" 2>/dev/null; then
        break
    fi
    term_attempt=$((term_attempt + 1))
    sleep 0.05
done
kill -TERM "$term_pid" 2>/dev/null || true
term_status=0
wait "$term_pid" || term_status=$?
if [ "$term_status" -eq 143 ] &&
    grep -q '^observed_sclk	2:1100$' "$observer_log" &&
    grep -q '^restoration=held profile=measure-fixed dpm_level=manual selections=verified sclk_level=1 mclk_level=1 ksm_run=1$' \
        "$term_output" &&
    [ "$(grep -c '^compute_state_command=' "$term_output")" -eq 1 ] &&
    grep -q ' status=interrupted profile=measure-fixed child_stop=term$' "$term_output" &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 terminating_signal_still_restores
else
    report 1 terminating_signal_still_restores
    printf 'term_status=%s fixture=%s\n' "$term_status" "$(fixture_state)" >&2
    cat "$term_output" >&2
fi

# A child that traps SIGTERM and sleeps requires SIGKILL to stop. The grace
# period is bounded, so the shutdown sequence is TERM (grace_seconds), KILL
# (5 more seconds), then wait, and the status line records child_stop=kill
# proving the KILL was needed. The fixture closes its own copy of the lease
# descriptor ahead of its sleep loop so a grandchild `sleep 1` never inherits
# it: without that, the grandchild forked at the moment of SIGKILL survives
# its parent and holds the lease open for the rest of its own one-second
# sleep, which is the timing dependency behind the harness's own deferred case.
reset_fixture
set_control observer_trap_term 1
kill_output=$temporary_directory/kill.log
{ QWEN_COMPUTE_STATE_STOP_GRACE_SECONDS=1 \
    exec_transaction measure-fixed "$stub_directory/observer" kill-arm; } \
    >"$kill_output" 2>&1 &
kill_pid=$!
kill_attempt=0
while [ "$kill_attempt" -lt 200 ]; do
    if grep -q '^observed_argument	kill-arm$' "$observer_log" 2>/dev/null; then
        break
    fi
    kill_attempt=$((kill_attempt + 1))
    sleep 0.05
done
kill -TERM "$kill_pid" 2>/dev/null || true
kill_status=0
wait "$kill_pid" || kill_status=$?
if [ "$kill_status" -eq 143 ] &&
    grep -q '^restoration=held profile=measure-fixed dpm_level=manual selections=verified sclk_level=1 mclk_level=1 ksm_run=1$' \
        "$kill_output" &&
    [ "$(grep -c '^compute_state_command=' "$kill_output")" -eq 1 ] &&
    grep -q ' status=interrupted profile=measure-fixed child_stop=kill$' "$kill_output" &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 term_ignoring_child_is_killed_and_still_restores
else
    report 1 term_ignoring_child_is_killed_and_still_restores
    printf 'kill_status=%s fixture=%s\n' "$kill_status" "$(fixture_state)" >&2
    cat "$kill_output" >&2
fi

# The lease outlives neither the killed grandchild nor the transaction itself:
# both close their copy of descriptor 8 by the time this polls free, which is
# what the fd8 closure inside the fixture's own loop is for.
kill_lease_attempt=0
while [ "$kill_lease_attempt" -lt 200 ] && lease_held; do
    kill_lease_attempt=$((kill_lease_attempt + 1))
    sleep 0.05
done
if ! lease_held; then
    report 0 lease_releases_after_the_killed_child_exits
else
    report 1 lease_releases_after_the_killed_child_exits
fi

# status reads and writes nothing, takes no credential, and reports the lease as
# free without taking it. The wait is the transaction's own release: the
# descriptor closes when its shell exits, and a case that read the lock before
# that would report the previous case rather than this one.
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
reset_fixture
set_control refuse_credential 1
status_status=0
run_transaction status >"$temporary_directory/status.log" 2>&1 || status_status=$?
if [ "$status_status" -eq 0 ] &&
    grep -q '^compute_state=live dpm_level=manual sclk_level=1 sclk_mhz=400 mclk_level=1 mclk_mhz=400 gfxclk_delivered_mhz=400 ksm_run=1 lease=free caller_nice=' \
        "$temporary_directory/status.log" &&
    [ "$(fixture_state)" = "$snapshot_fixture_state" ]; then
    report 0 status_reports_live_values_without_a_credential
else
    report 1 status_reports_live_values_without_a_credential
    cat "$temporary_directory/status.log" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'compute_state_lease_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'compute_state_lease_tests=passed\n'
