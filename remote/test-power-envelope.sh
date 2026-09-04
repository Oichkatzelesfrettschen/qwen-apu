#!/bin/sh
set -eu

# power-envelope.sh writes the SMU through a privileged binary, so its whole
# term is driven here against a fake ryzenadj on PATH with no privilege at all.
#
# The fake models the firmware rather than the command line. It keeps the power
# limits in a state file, answers `--info` by printing that state in the
# markdown table `main.c` emits at `%9.3lf` in watts, and applies a set option
# in the milliwatts `README.md` documents, so the factor of a thousand between
# the read direction and the write direction is exercised rather than assumed. A
# control file decides whether the firmware honors a write, which is what turns
# the read-back verification into a test rather than a restatement of the
# writer's exit status. Every invocation is recorded, so the argv the term built
# is provable and a profile that names no field is provably silent.
#
# The sudo stub stands for the credential rather than for the privilege: it
# answers `-n true` from its own control file and otherwise runs the command it
# was handed, so the absent-credential refusal and the ordinary path differ in
# that one answer.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
power_envelope=$script_directory/power-envelope.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    if [ "${QWEN_TEST_KEEP_OUTPUT:-0}" = 1 ]; then
        printf 'power_envelope_fixture_directory=%s\n' "$temporary_directory" >&2
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

state_fixture=$temporary_directory/state
stub_directory=$temporary_directory/stubs
firmware_state=$temporary_directory/firmware.tsv
controls=$temporary_directory/controls.tsv
invocation_log=$temporary_directory/invocations.log
snapshot_file=$state_fixture/power-envelope-snapshot.tsv
mkdir -p "$state_fixture" "$stub_directory"

set_control() {
    printf '%s\t%s\n' "$1" "$2" >>"$controls"
}

reset_fixture() {
    : >"$controls"
    : >"$invocation_log"
    rm -f -- "$snapshot_file"
    {
        printf 'stapm_limit_mw\t15000\n'
        printf 'fast_limit_mw\t15000\n'
        printf 'slow_limit_mw\t15000\n'
        printf 'vrm_current_ma\t30000\n'
        printf 'vrmmax_current_ma\t45000\n'
        printf 'tctl_limit_c\t95\n'
    } >"$firmware_state"
    set_control honor_writes 1
}

firmware_field() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$firmware_state"
}

{
    printf '#!/bin/sh\nset -eu\n'
    printf 'firmware_state=%s\n' "$firmware_state"
    printf 'controls=%s\n' "$controls"
    printf 'invocation_log=%s\n' "$invocation_log"
    cat <<'RYZENADJ'
control() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' "$controls"
}
field() {
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$firmware_state"
}
set_field() {
    LC_ALL=C awk -F'\t' -v key="$1" -v new="$2" '
        $1 == key { print key "\t" new; found = 1; next }
        { print }
        END { if (!found) print key "\t" new }' "$firmware_state" >"$firmware_state.new"
    mv -- "$firmware_state.new" "$firmware_state"
}
printf 'ryzenadj' >>"$invocation_log"
for invocation_argument in "$@"; do
    printf ' %s' "$invocation_argument" >>"$invocation_log"
done
printf '\n' >>"$invocation_log"

if [ "${1:-}" = --info ]; then
    if [ "$(control refuse_info)" = 1 ]; then
        printf 'Unable to init ryzenadj\n' >&2
        exit 1
    fi
    printf 'CPU Family: Dali\n'
    printf 'SMU BIOS Interface Version: 15\n'
    printf 'PM Table Version: 1e0004\n'
    printf '|        Name         |   Value   |     Parameter      |\n'
    printf '|---------------------|-----------|--------------------|\n'
    row() { printf '| %-19s | %9s | %-18s |\n' "$1" "$2" "$3"; }
    milliwatts_to_units() {
        LC_ALL=C awk -v raw="$1" 'BEGIN { printf "%.3f\n", raw / 1000 }'
    }
    row 'STAPM LIMIT' "$(milliwatts_to_units "$(field stapm_limit_mw)")" stapm-limit
    row 'STAPM VALUE' "$(milliwatts_to_units 7250)" ''
    row 'PPT LIMIT FAST' "$(milliwatts_to_units "$(field fast_limit_mw)")" fast-limit
    row 'PPT VALUE FAST' "$(milliwatts_to_units 8100)" ''
    row 'PPT LIMIT SLOW' "$(milliwatts_to_units "$(field slow_limit_mw)")" slow-limit
    row 'PPT VALUE SLOW' "$(milliwatts_to_units 7600)" ''
    row 'PPT LIMIT APU' nan apu-slow-limit
    row 'TDC LIMIT VDD' "$(milliwatts_to_units "$(field vrm_current_ma)")" vrm-current
    row 'EDC LIMIT VDD' "$(milliwatts_to_units "$(field vrmmax_current_ma)")" vrmmax-current
    row 'THM LIMIT CORE' "$(field tctl_limit_c)" tctl-temp
    row 'THM VALUE CORE' 71.125 ''
    exit 0
fi

for invocation_argument in "$@"; do
    case $invocation_argument in
        --stapm-limit=*) written_field=stapm_limit_mw ;;
        --fast-limit=*) written_field=fast_limit_mw ;;
        --slow-limit=*) written_field=slow_limit_mw ;;
        --vrm-current=*) written_field=vrm_current_ma ;;
        --vrmmax-current=*) written_field=vrmmax_current_ma ;;
        *)
            printf 'unknown option: %s\n' "$invocation_argument" >&2
            exit 1
            ;;
    esac
    if [ "$(control refuse_writes)" = 1 ] ||
        [ "$(control refuse_write_field)" = "$written_field" ]; then
        printf 'Failed to set the value\n' >&2
        exit 1
    fi
    if [ "$(control honor_writes)" = 1 ]; then
        written_value=${invocation_argument#*=}
        # A sticky field models a platform that latches a raised limit and
        # accepts the lowering write without applying it, which is the state a
        # rollback has to report rather than assume.
        if [ "$(control sticky_field)" = "$written_field" ] &&
            [ "$written_value" -lt "$(field "$written_field")" ]; then
            continue
        fi
        set_field "$written_field" "$written_value"
    fi
done
exit 0
RYZENADJ
} >"$stub_directory/ryzenadj"

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
exec "$@"
SUDO
} >"$stub_directory/sudo"

chmod +x "$stub_directory/ryzenadj" "$stub_directory/sudo"

run_term() {
    run_ryzenadj=${QWEN_TEST_RYZENADJ:-$stub_directory/ryzenadj}
    set +e
    env PATH="$stub_directory:$PATH" \
        QWEN_RYZENADJ="$run_ryzenadj" \
        QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
        QWEN_POWER_ENVELOPE_SNAPSHOT="$snapshot_file" \
        QWEN_POWER_ENVELOPE_OWNER="${QWEN_TEST_OWNER:-power-envelope-test}" \
        "$power_envelope" "$@" >"$temporary_directory/stdout" 2>"$temporary_directory/stderr"
    run_status=$?
    set -e
}

record_owner() {
    LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' "$snapshot_file" 2>/dev/null || true
}

stdout_carries() {
    grep -q -- "$1" "$temporary_directory/stdout"
}
stderr_carries() {
    grep -q -- "$1" "$temporary_directory/stderr"
}

# An applied candidate arm writes each of the three package limits once, proves
# the read-back, and leaves a snapshot naming the platform's own baseline.
reset_fixture
run_term apply package-20w
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope_applied=package-20w' || case_status=1
stdout_carries 'stapm_limit_mw=20000' || case_status=1
stdout_carries 'tctl_limit_c=95' || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 20000 ] || case_status=1
[ "$(firmware_field fast_limit_mw)" = 25000 ] || case_status=1
[ "$(firmware_field slow_limit_mw)" = 20000 ] || case_status=1
grep -q -- '--stapm-limit=20000' "$invocation_log" || case_status=1
grep -q 'snapshot_field	stapm_limit_mw	15000' "$snapshot_file" || case_status=1
report "$case_status" 'apply writes the profile fields in milliwatts and snapshots the platform baseline'

# The restore is the same transaction run backwards, and it removes the snapshot
# only after the firmware reads back at the baseline.
run_term restore
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope_restored=held' || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 15000 ] || case_status=1
[ "$(firmware_field slow_limit_mw)" = 15000 ] || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'restore returns every snapshotted limit and removes the snapshot'

# A firmware that accepts the write and keeps its own limit is the platform
# re-assertion the project's own FAQ describes, and the read-back is what names
# it. The snapshot survives, because the machine still needs restoring.
reset_fixture
set_control honor_writes 0
run_term apply package-25w
case_status=0
[ "$run_status" -eq 3 ] || case_status=1
stderr_carries 'power_envelope_applied=unreached' || case_status=1
stderr_carries 'stapm_limit_mw=15000(want=25000)' || case_status=1
stderr_carries 'power_envelope_rollback=held' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a read-back that disagrees with the request refuses the arm and returns the baseline'

# A profile writes several limits in turn, so a refusal on the second leaves the
# first raised. The rollback returns it before the refusal is reported.
reset_fixture
set_control refuse_write_field fast_limit_mw
run_term apply package-20w
case_status=0
[ "$run_status" -eq 3 ] || case_status=1
stderr_carries 'reason=smu_write_refused profile=package-20w field=fast_limit_mw' || case_status=1
stderr_carries 'power_envelope_rollback=held' || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 15000 ] || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a refusal part way through a profile rolls the earlier limits back'

# A rollback the platform will not take is the incident, so it keeps the
# snapshot and raises the failure to the restoration status.
reset_fixture
set_control refuse_write_field slow_limit_mw
set_control sticky_field stapm_limit_mw
run_term apply package-20w
case_status=0
[ "$run_status" -eq 4 ] || case_status=1
stderr_carries 'power_envelope_rollback=failed' || case_status=1
stderr_carries 'stapm_limit_mw=20000(want=15000)' || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 20000 ] || case_status=1
[ -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a rollback the platform refuses keeps the snapshot and is an incident'
run_term restore || true

# A restore whose read-back disagrees is an incident rather than a warning, so
# it ends non-zero and leaves the snapshot for the operator.
reset_fixture
run_term apply package-20w
set_control honor_writes 0
run_term restore
case_status=0
[ "$run_status" -eq 4 ] || case_status=1
stderr_carries 'power_envelope_restored=failed' || case_status=1
[ -e "$snapshot_file" ] || case_status=1
report "$case_status" 'a restore that fails to return a limit ends the term non-zero'

# The control arm proves the ceiling and records the baseline while writing
# nothing, so a candidate arm differs from it in the package budget alone.
reset_fixture
run_term apply platform-default
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope_applied=platform-default fields=none' || case_status=1
if grep -q -- '--stapm-limit' "$invocation_log"; then case_status=1; fi
if grep -q 'snapshot_field' "$snapshot_file"; then case_status=1; fi
report "$case_status" 'the control profile records the baseline and writes no limit'

run_term restore
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope_restored=held profile=platform-default fields=none' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'restoring a control arm removes the snapshot and writes nothing'

# A second apply over a live snapshot would record this term's own writes as the
# platform baseline.
reset_fixture
run_term apply package-20w
run_term apply package-25w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_present' || case_status=1
report "$case_status" 'an apply over a live snapshot is refused'

# The thermal limit bounds the term and is never written by it.
reset_fixture
LC_ALL=C awk -F'\t' '$1 == "tctl_limit_c" { print $1 "\t100"; next } { print }' \
    "$firmware_state" >"$firmware_state.edited"
mv -- "$firmware_state.edited" "$firmware_state"
run_term apply package-20w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=thermal_limit_above_ceiling' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
if grep -q -- '--tctl-temp' "$invocation_log"; then case_status=1; fi
report "$case_status" 'a thermal limit above the ceiling refuses the term before any write'

# An absent binary and an absent credential are named refusals rather than a
# prompt or a stack trace.
reset_fixture
QWEN_TEST_RYZENADJ=$temporary_directory/absent-ryzenadj
run_term apply package-20w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=ryzenadj_absent' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'an absent ryzenadj refuses the apply by name'

run_term status
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope=unavailable reason=ryzenadj_absent' || case_status=1
report "$case_status" 'status answers without a binary rather than refusing'
unset QWEN_TEST_RYZENADJ

reset_fixture
set_control refuse_credential 1
run_term apply package-20w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=sudo_credential_absent' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
if grep -q ryzenadj "$invocation_log"; then case_status=1; fi
report "$case_status" 'an absent sudo credential refuses the apply before the binary runs'

run_term status
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope=unavailable reason=sudo_credential_absent' || case_status=1
report "$case_status" 'status names the absent credential rather than prompting'

# status reads and writes nothing, so it answers while a profile is applied.
reset_fixture
run_term apply package-20w
run_term status
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope=live' || case_status=1
stdout_carries 'stapm_limit_mw=20000' || case_status=1
stdout_carries 'tctl_limit_c=95' || case_status=1
stdout_carries 'snapshot=present' || case_status=1
report "$case_status" 'status reports the live limits and the snapshot state'
run_term restore

# A firmware whose power-metrics table cannot be read refuses ahead of any
# write, because the snapshot is what makes the term reversible.
reset_fixture
set_control refuse_info 1
run_term apply package-20w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=metrics_read_failed' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
report "$case_status" 'an unreadable power-metrics table refuses the term before any write'

# An unknown profile and a malformed invocation exit on the usage status.
reset_fixture
run_term apply no-such-profile
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'unknown power profile' || case_status=1
report "$case_status" 'an unknown profile is refused'

run_term restore
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_absent' || case_status=1
report "$case_status" 'a restore with no snapshot to reverse is refused'

# The claim is the file's creation, so a snapshot another process holds refuses
# this apply whatever wrote it, and no SMU write is attempted.
reset_fixture
printf 'schema\tpower-envelope-snapshot-v1\towner\n' >"$snapshot_file"
run_term apply package-20w
case_status=0
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_present' || case_status=1
if grep -q ryzenadj "$invocation_log"; then case_status=1; fi
report "$case_status" 'a snapshot another process holds refuses the apply before the binary runs'
rm -f -- "$snapshot_file"

# A claim that never reached its baseline record means the apply died ahead of
# the first write, so the reversal is the removal rather than a set of writes.
reset_fixture
: >"$snapshot_file"
run_term restore
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
stdout_carries 'power_envelope_restored=held profile=unclaimed fields=none' || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
if grep -q ryzenadj "$invocation_log"; then case_status=1; fi
report "$case_status" 'an unfilled claim is reversed by removing it and writes nothing'

# A restore acts on its own claim alone, so a caller naming another owner is
# refused rather than returning a budget a second campaign is running under.
reset_fixture
QWEN_TEST_OWNER=first-campaign
run_term apply package-20w
case_status=0
[ "$run_status" -eq 0 ] || case_status=1
[ "$(record_owner)" = first-campaign ] || case_status=1
QWEN_TEST_OWNER=second-campaign
run_term restore
[ "$run_status" -eq 2 ] || case_status=1
stderr_carries 'reason=snapshot_owner_mismatch owner=first-campaign caller=second-campaign' ||
    case_status=1
[ -e "$snapshot_file" ] || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 20000 ] || case_status=1
QWEN_TEST_OWNER=first-campaign
run_term restore
[ "$run_status" -eq 0 ] || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 15000 ] || case_status=1
report "$case_status" 'a restore naming another owner is refused and the owner still returns the baseline'
unset QWEN_TEST_OWNER

# A standalone caller names no owner at all: apply and restore are separate
# processes with separate PIDs, so the default owner must be a fixed literal
# rather than PID-derived, or a bare `restore` would always mismatch the
# `apply` that claimed the snapshot.
reset_fixture
case_status=0
set +e
env PATH="$stub_directory:$PATH" \
    QWEN_RYZENADJ="$stub_directory/ryzenadj" \
    QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
    QWEN_POWER_ENVELOPE_SNAPSHOT="$snapshot_file" \
    "$power_envelope" apply package-20w >"$temporary_directory/standalone-apply.log" 2>&1
standalone_apply_status=$?
env PATH="$stub_directory:$PATH" \
    QWEN_RYZENADJ="$stub_directory/ryzenadj" \
    QWEN_WEBUI_STATE_DIRECTORY="$state_fixture" \
    QWEN_POWER_ENVELOPE_SNAPSHOT="$snapshot_file" \
    "$power_envelope" restore >"$temporary_directory/standalone-restore.log" 2>&1
standalone_restore_status=$?
set -e
[ "$standalone_apply_status" -eq 0 ] || case_status=1
[ "$standalone_restore_status" -eq 0 ] || case_status=1
grep -q 'power_envelope_restored=held profile=package-20w' \
    "$temporary_directory/standalone-restore.log" || case_status=1
[ ! -e "$snapshot_file" ] || case_status=1
[ "$(firmware_field stapm_limit_mw)" = 15000 ] || case_status=1
report "$case_status" 'a standalone apply and a separate standalone restore round-trip without an explicit owner'
if [ "$case_status" -ne 0 ]; then
    cat "$temporary_directory/standalone-apply.log" "$temporary_directory/standalone-restore.log" >&2
fi

if [ "$failures" -ne 0 ]; then
    printf 'power_envelope_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'power_envelope_tests=passed\n'
