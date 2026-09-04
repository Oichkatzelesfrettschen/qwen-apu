#!/bin/sh
set -eu

# cpu-frequency-cap.sh writes cpupower and a boost sysfs node through sudo, so
# its whole term is driven here against a fake cpupower on PATH and a fixture
# sysfs tree under mktemp, with no privilege and no CPU at all.
#
# The fake cpupower models the writer rather than the real tool's own parser:
# `--cpu N frequency-set -u FREQ` and `-g GOVERNOR` write the fixture's
# per-core scaling_max_freq and scaling_governor files directly, the way the
# real tool moves the kernel's own cpufreq policy. A control file decides
# whether a write is honored, which is what turns the read-back verification
# in cpu-frequency-cap.sh into a test rather than a restatement of the
# writer's exit status. Every invocation is recorded, so the argv the term
# built is provable.
#
# The boost node is written directly through the sudo/tee path
# cpu-frequency-cap.sh shares with compute-state-lease.sh's own KSM and DPM
# writes, so its fake is the same tee-flavored stub the other fixtures in this
# tree use.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cpu_cap=$script_directory/cpu-frequency-cap.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'cpu_frequency_cap_fixture_directory=%s\n' "$temporary_directory" >&2
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
cpu_root=$sysfs_fixture/devices/system/cpu
state_fixture=$temporary_directory/state
stub_directory=$temporary_directory/stubs
controls=$temporary_directory/controls.tsv
invocation_log=$temporary_directory/invocations.log
snapshot_file=$state_fixture/cpu-frequency-cap-snapshot.tsv
mkdir -p "$cpu_root/cpu0/cpufreq" "$cpu_root/cpu1/cpufreq" "$cpu_root/cpufreq" \
    "$state_fixture" "$stub_directory"

set_control() {
    printf '%s\t%s\n' "$1" "$2" >>"$controls"
}

reset_fixture() {
    : >"$controls"
    : >"$invocation_log"
    rm -f -- "$snapshot_file"
    printf '3200000\n' >"$cpu_root/cpu0/cpufreq/scaling_max_freq"
    printf '3200000\n' >"$cpu_root/cpu1/cpufreq/scaling_max_freq"
    printf 'schedutil\n' >"$cpu_root/cpu0/cpufreq/scaling_governor"
    printf 'schedutil\n' >"$cpu_root/cpu1/cpufreq/scaling_governor"
    printf '1\n' >"$cpu_root/cpufreq/boost"
    set_control honor_writes 1
}

sysfs_field() {
    LC_ALL=C tr -d ' \t\n' <"$1" 2>/dev/null || printf 'unreadable\n'
}

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'cpu_root=%s\n' "$cpu_root"
    printf 'controls=%s\n' "$controls"
    printf 'invocation_log=%s\n' "$invocation_log"
    cat <<'CPUPOWER'
control() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}
printf 'cpupower' >>"$invocation_log"
for invocation_argument in "$@"; do
    printf ' %s' "$invocation_argument" >>"$invocation_log"
done
printf '\n' >>"$invocation_log"

target_cpu=''
subcommand=''
mode=''
value=''
previous=''
for invocation_argument in "$@"; do
    case $previous in
        --cpu) target_cpu=$invocation_argument ;;
        -u) mode=upper; value=$invocation_argument ;;
        -g) mode=governor; value=$invocation_argument ;;
    esac
    case $invocation_argument in
        frequency-set) subcommand=frequency-set ;;
    esac
    previous=$invocation_argument
done

if [ "$subcommand" != frequency-set ] || [ -z "$target_cpu" ] || [ -z "$mode" ]; then
    printf 'unsupported invocation\n' >&2
    exit 1
fi
if [ "$(control refuse_writes)" = 1 ] ||
    [ "$(control refuse_cpu)" = "$target_cpu" ]; then
    printf 'Error setting values\n' >&2
    exit 1
fi
if [ "$(control honor_writes)" = 1 ]; then
    case $mode in
        upper)
            case $value in
                *MHz) khz=$(( ${value%MHz} * 1000 )) ;;
                *KHz) khz=${value%KHz} ;;
                *) khz=$value ;;
            esac
            printf '%s\n' "$khz" >"$cpu_root/cpu$target_cpu/cpufreq/scaling_max_freq"
            ;;
        governor)
            printf '%s\n' "$value" >"$cpu_root/cpu$target_cpu/cpufreq/scaling_governor"
            ;;
    esac
fi
exit 0
CPUPOWER
} >"$stub_directory/cpupower"

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'controls=%s\n' "$controls"
    cat <<'SUDO'
control() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}
[ "${1:-}" = -n ] || exit 1
shift
if [ "$(control refuse_credential)" = 1 ]; then
    printf 'sudo: a password is required\n' >&2
    exit 1
fi
if [ "${1:-}" = true ] && [ "$#" -eq 1 ]; then
    exit 0
fi
if [ "${1:-}" = tee ]; then
    target=$2
    content=$(cat)
    leaf=${target##*/}
    if [ "$leaf" = boost ] && [ "$(control refuse_boost_write)" = "$content" ]; then
        printf 'tee: %s: Invalid argument\n' "$target" >&2
        exit 1
    fi
    printf '%s\n' "$content" >"$target"
    printf '%s\n' "$content"
    exit 0
fi
exec "$@"
SUDO
} >"$stub_directory/sudo"

chmod +x "$stub_directory/cpupower" "$stub_directory/sudo"

run_term() {
    run_cpupower=${QWEN_TEST_CPUPOWER:-$stub_directory/cpupower}
    set +e
    env PATH="$stub_directory:$PATH" \
        QWEN_CPUPOWER="$run_cpupower" \
        QWEN_SYSFS_ROOT="$sysfs_fixture" \
        QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
        QWEN_CPU_FREQUENCY_CAP_SNAPSHOT="$snapshot_file" \
        QWEN_CPU_FREQUENCY_CAP_OWNER="${QWEN_TEST_OWNER:-cpu-frequency-cap-test}" \
        "$cpu_cap" "$@" >"$temporary_directory/stdout" 2>"$temporary_directory/stderr"
    run_status=$?
    set -e
}

record_owner() {
    LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' "$snapshot_file" 2>/dev/null || true
}

stdout_carries() { grep -q -- "$1" "$temporary_directory/stdout"; }
stderr_carries() { grep -q -- "$1" "$temporary_directory/stderr"; }

# An applied cap writes both cores' ceiling and the boost node, proves the
# read-back, and snapshots the platform baseline.
reset_fixture
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'cpu_frequency_cap_applied=base-clock-cap upper_khz=2300000 boost=0' || case_status=1
[ "$(sysfs_field "$cpu_root/cpu0/cpufreq/scaling_max_freq")" = 2300000 ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpu1/cpufreq/scaling_max_freq")" = 2300000 ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpufreq/boost")" = 0 ] || case_status=1
grep -q -- '--cpu 0 frequency-set -u 2300MHz' "$invocation_log" || case_status=1
grep -q -- '--cpu 1 frequency-set -u 2300MHz' "$invocation_log" || case_status=1
grep -q 'snapshot_max_khz	0	3200000' "$snapshot_file" || case_status=1
grep -q 'snapshot_max_khz	1	3200000' "$snapshot_file" || case_status=1
grep -q 'snapshot_boost	1' "$snapshot_file" || case_status=1
report "$case_status" 'apply caps both cores and the boost node and snapshots the baseline'

# The restore is the same transaction run backwards.
run_term restore
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'cpu_frequency_cap_restored=held profile=base-clock-cap' || case_status=1
[ "$(sysfs_field "$cpu_root/cpu0/cpufreq/scaling_max_freq")" = 3200000 ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpu1/cpufreq/scaling_max_freq")" = 3200000 ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpufreq/boost")" = 1 ] || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'restore returns both cores and the boost node and removes the snapshot'

# A cpupower that answers a write with success but leaves the ceiling
# unmoved is the platform re-assertion, and the read-back is what names it.
# The snapshot survives, since the machine still needs restoring.
reset_fixture
set_control honor_writes 0
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 3 ] || case_status=1
stderr_carries 'cpu_frequency_cap_applied=unreached' || case_status=1
stderr_carries 'cpu0_max_khz=3200000(want=2300000)' || case_status=1
[ -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a read-back that disagrees with the request refuses the arm and keeps the snapshot for restore'
run_term restore || true

# A restore whose read-back disagrees is an incident rather than a warning.
reset_fixture
run_term apply base-clock-cap
set_control honor_writes 0
run_term restore
case_status=0
[ "$run_status" -eq 4 ] || case_status=1
stderr_carries 'cpu_frequency_cap_restored=failed' || case_status=1
stderr_carries 'cpu0_max_khz=2300000(want=3200000)' || case_status=1
[ -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a restore that fails to return a cap ends the term non-zero'
set_control honor_writes 1
run_term restore || true

# A refused boost restore is named on its own field.
reset_fixture
run_term apply base-clock-cap
set_control refuse_boost_write 1
run_term restore
case_status=0
[ "$run_status" -eq 4 ] || case_status=1
stderr_carries 'boost=0(want=1)' || case_status=1
[ -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a refused boost restore is named and is an incident'
set_control refuse_boost_write 0
run_term restore || true

# A second apply over a live snapshot is refused before any write.
reset_fixture
run_term apply base-clock-cap
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_present' || case_status=1
report "$case_status" 'an apply over a live snapshot is refused'
run_term restore || true

# An absent binary and an absent credential are named refusals.
reset_fixture
QWEN_TEST_CPUPOWER=$temporary_directory/absent-cpupower
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=cpupower_absent' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'an absent cpupower refuses the apply by name'

run_term status
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'cpu_frequency_cap=unavailable reason=cpupower_absent' || case_status=1
report "$case_status" 'status answers without a binary rather than refusing'
unset QWEN_TEST_CPUPOWER

reset_fixture
set_control refuse_credential 1
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=sudo_credential_absent' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
if grep -q cpupower "$invocation_log"; then case_status=1; fi
report "$case_status" 'an absent sudo credential refuses the apply before the binary runs'

# status reads and writes nothing, so it answers while a cap is applied.
reset_fixture
run_term apply base-clock-cap
run_term status
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'cpu_frequency_cap=live' || case_status=1
stdout_carries 'cpu0_max_khz=2300000' || case_status=1
stdout_carries 'boost=0' || case_status=1
stdout_carries 'snapshot=present' || case_status=1
report "$case_status" 'status reports the live caps and the snapshot state'
run_term restore

# An unknown profile and a malformed invocation exit on the usage status.
reset_fixture
run_term apply no-such-profile
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'unknown CPU frequency profile' || case_status=1
report "$case_status" 'an unknown profile is refused'

run_term restore
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_absent' || case_status=1
report "$case_status" 'a restore with no snapshot to reverse is refused'

# The claim is the file's creation, so a snapshot another process holds
# refuses this apply whatever wrote it, and no cpupower write is attempted.
reset_fixture
printf 'schema\tcpu-frequency-cap-snapshot-v1\towner\tstub\n' >"$snapshot_file"
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_present' || case_status=1
if grep -q cpupower "$invocation_log"; then case_status=1; fi
report "$case_status" 'a snapshot another process holds refuses the apply before the binary runs'
rm -f -- "$snapshot_file"

# A claim that never reached its baseline record means the apply died ahead
# of the first write, so the reversal is the removal rather than a write.
reset_fixture
: >"$snapshot_file"
run_term restore
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'cpu_frequency_cap_restored=held profile=unclaimed fields=none' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
if grep -q cpupower "$invocation_log"; then case_status=1; fi
report "$case_status" 'an unfilled claim is reversed by removing it and writes nothing'

# A restore acts on its own claim alone, so a caller naming another owner is
# refused rather than returning a cap a second campaign is running under.
reset_fixture
QWEN_TEST_OWNER=first-campaign
run_term apply base-clock-cap
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
[ "$(record_owner)" = first-campaign ] || case_status=1
QWEN_TEST_OWNER=second-campaign
run_term restore
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_owner_mismatch owner=first-campaign caller=second-campaign' ||
    case_status=1
[ -e "$snapshot_file" ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpu0/cpufreq/scaling_max_freq")" = 2300000 ] || case_status=1
QWEN_TEST_OWNER=first-campaign
run_term restore
[ "$run_status" -eq 0 ] || case_status=1
[ "$(sysfs_field "$cpu_root/cpu0/cpufreq/scaling_max_freq")" = 3200000 ] || case_status=1
report "$case_status" 'a restore naming another owner is refused and the owner still returns the baseline'
unset QWEN_TEST_OWNER

if [ "$failures" -ne 0 ]; then
    printf 'cpu_frequency_cap_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'cpu_frequency_cap_tests=passed\n'
