#!/bin/sh
set -eu

# One reversible power-envelope term for the compute-state transaction.
#
# The two Zen+ cores and the two Vega compute units draw from one package
# budget, and the SMU rather than the kernel owns it: `/sys/class/powercap`
# creates no `constraint_*` file on this part and the amdgpu hwmon names a `PPT`
# label with no `power1_cap` beside it, so every writable limit reaches the
# firmware through the MP1 mailbox. RyzenAdj is the writer this term uses.
# `lib/api.c` sends `stapm-limit` as MP1 message 0x1a, `fast-limit` as 0x1b, and
# `slow-limit` as 0x1c under `FAM_DALI`, which `lib/cpuid.c` selects for CPUID
# family 0x17 model 32, and `_do_adjust` maps the mailbox reply onto a distinct
# status for `PPSMC_Result_UnknownCmd` and for a rejection, so a refused write is
# a named failure rather than a silent one.
#
# Three properties make the term reversible. The snapshot is taken from the
# firmware's own power-metrics table through `ryzenadj --info` ahead of the first
# write, so the baseline is what the platform set rather than what a document
# expects. A profile names the fields it writes and this script writes no other,
# so an unnamed limit keeps whatever the platform holds. `restore` writes the
# snapshot back and re-reads it, and a value that fails to return ends the term
# non-zero, because a machine left on a raised package budget is an incident.
# The firmware exposes no reset-to-default message, so the snapshot is the whole
# reversal and a power cycle is the only authority above it.
#
# The thermal limit is read and bounded rather than written. Raising `tctl-temp`
# moves the temperature the part is allowed to reach, which is a different risk
# class from moving the power it is allowed to draw, so every profile here
# leaves `THM LIMIT CORE` where the platform set it and the term refuses to run
# against a reading above the stated ceiling. The ceiling gates `apply` and
# never `restore`: refusing to return a raised budget because the part grew hot
# would leave the raised budget applied, which is the state the term exists to
# end.
#
# The snapshot path is the term's ownership token as well as its baseline. A
# claim opens it under `set -C`, which is an O_EXCL create, so exactly one
# concurrent `apply` creates it and every other is refused; the claim precedes
# the power-metrics read and therefore precedes every SMU write, so a claimed
# file that carries no schema row means no limit was written and the reversal is
# to remove it. `QWEN_POWER_ENVELOPE_OWNER` names the transaction that claimed
# it, and `restore` refuses a snapshot another owner claimed rather than
# returning a budget a second campaign is still running under.
#
# Units differ between the two directions and the difference is a factor of a
# thousand. `main.c` prints the power-metrics table with `%9.3lf` in watts and
# amperes, while `README.md` documents every set option in milliwatts and
# milliamperes, so each field below carries the scale that converts the printed
# reading into the unit its write takes.
#
# Every invocation of the binary runs under `sudo -n`. RyzenAdj reaches the SMN
# index and data registers through PCI configuration space and the power-metrics
# table through `/dev/mem`, both of which need root, and `-n` never prompts, so
# an absent credential is a named refusal here rather than a password prompt
# inside a measurement arm. The user grants the credential with `sudo -v`.

usage() {
    printf 'usage: %s apply PROFILE\n' "$0" >&2
    printf '       %s restore\n' "$0" >&2
    printf '       %s status\n' "$0" >&2
    printf 'profiles: platform-default package-20w package-25w\n' >&2
    exit 2
}

if [ "$#" -lt 1 ]; then
    usage
fi

ryzenadj_command=${QWEN_RYZENADJ:-"${HOME:?}/.local/bin/ryzenadj"}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
snapshot_file=${QWEN_POWER_ENVELOPE_SNAPSHOT:-$state_directory/power-envelope-snapshot.tsv}
tctl_ceiling_c=${QWEN_POWER_ENVELOPE_TCTL_CEILING_C:-95}
# The power-metrics table holds floats, so a read-back is compared inside an
# absolute band in the field's own write unit. A tenth of a watt is two orders
# below the smallest step any registered profile moves.
readback_tolerance=${QWEN_POWER_ENVELOPE_TOLERANCE:-100}
# A caller that owns a wider transaction names itself here, so its restore acts
# on its own claim alone. A direct invocation owns its snapshot by process.
owner_token=${QWEN_POWER_ENVELOPE_OWNER:-power-envelope.$$}

# Each field names the power-metrics row it is read from, the set option it is
# written with, and the factor that converts the printed reading into the write
# unit. The printed table is watts and amperes; the options take milliwatts and
# milliamperes.
power_field_row() {
    case $1 in
        stapm_limit_mw) printf 'STAPM LIMIT\tstapm-limit\t1000\n' ;;
        fast_limit_mw) printf 'PPT LIMIT FAST\tfast-limit\t1000\n' ;;
        slow_limit_mw) printf 'PPT LIMIT SLOW\tslow-limit\t1000\n' ;;
        vrm_current_ma) printf 'TDC LIMIT VDD\tvrm-current\t1000\n' ;;
        vrmsoc_current_ma) printf 'TDC LIMIT SOC\tvrmsoc-current\t1000\n' ;;
        vrmmax_current_ma) printf 'EDC LIMIT VDD\tvrmmax-current\t1000\n' ;;
        vrmsocmax_current_ma) printf 'EDC LIMIT SOC\tvrmsocmax-current\t1000\n' ;;
        *) return 1 ;;
    esac
}

# A profile is the list of fields it writes. `platform-default` writes nothing
# and is the campaign's control arm: it still snapshots and still proves the
# thermal ceiling, so a control arm and a candidate arm differ in the package
# budget alone.
resolve_power_profile() {
    case $1 in
        platform-default) profile_fields='' ;;
        package-20w)
            profile_fields='stapm_limit_mw=20000 fast_limit_mw=20000 slow_limit_mw=20000'
            ;;
        package-25w)
            profile_fields='stapm_limit_mw=25000 fast_limit_mw=25000 slow_limit_mw=25000'
            ;;
        *)
            printf 'unknown power profile: %s\n' "$1" >&2
            usage
            ;;
    esac
}

require_ryzenadj() {
    case $ryzenadj_command in
        */*) ;;
        *)
            resolved_ryzenadj=$(command -v "$ryzenadj_command" 2>/dev/null) || resolved_ryzenadj=''
            if [ -n "$resolved_ryzenadj" ]; then
                ryzenadj_command=$resolved_ryzenadj
            fi
            ;;
    esac
    if [ ! -f "$ryzenadj_command" ] || [ ! -x "$ryzenadj_command" ]; then
        printf 'reason=ryzenadj_absent path=%s; build it with remote/build-ryzenadj.sh or name QWEN_RYZENADJ\n' \
            "$ryzenadj_command" >&2
        return 1
    fi
    return 0
}

require_credential() {
    if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
        printf 'reason=sudo_credential_absent; this term writes the SMU through sudo -n and never prompts, so run `sudo -v` first\n' >&2
        return 1
    fi
    return 0
}

# The power-metrics table is emitted as a pipe-delimited table whose first
# column is the row name and whose second is the printed value. The row name is
# matched exactly, because `STAPM LIMIT` and `STAPM VALUE` differ in that word
# alone and the limit is the field this term owns.
read_power_metrics() {
    sudo -n "$ryzenadj_command" --info 2>/dev/null
}

metrics_row_value() {
    LC_ALL=C awk -F'|' -v wanted="$2" '
        NF >= 4 {
            name = $2
            value = $3
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            gsub(/^[ \t]+|[ \t]+$/, "", value)
            if (name == wanted && value ~ /^-?[0-9]+([.][0-9]+)?$/) {
                print value
                found = 1
                exit
            }
        }
        END { if (!found) exit 1 }' "$1"
}

# A printed reading is scaled into the write unit and rounded, so a comparison
# between a snapshot and a request is a comparison of like integers.
scaled_row_value() {
    scaled_reading=$(metrics_row_value "$1" "$2") || return 1
    LC_ALL=C awk -v reading="$scaled_reading" -v scale="$3" 'BEGIN {
        value = reading * scale
        printf "%d\n", (value < 0) ? value - 0.5 : value + 0.5 }'
}

within_readback_band() {
    LC_ALL=C awk -v observed="$1" -v required="$2" -v tolerance="$3" 'BEGIN {
        difference = observed - required
        if (difference < 0) difference = -difference
        exit (difference <= tolerance + 0) ? 0 : 1 }'
}

# A failure part way through a profile leaves some limits raised and some at the
# platform's own value, which is the one state this term exists to prevent, so
# both failure paths below return the snapshot before they report. A rollback
# that reads back at the baseline removes the snapshot and leaves the failure a
# refused arm; a rollback that fails keeps the snapshot and raises the failure to
# the restoration-incident status, because the machine is then holding a budget
# nobody chose. `apply` therefore reverses itself whether or not a caller wraps
# it in compute-state-lease.sh.
roll_back_partial_apply() {
    rollback_pairs=$1
    for rollback_pair in $rollback_pairs; do
        rollback_field=${rollback_pair%%=*}
        rollback_value=${rollback_pair#*=}
        rollback_metadata=$(power_field_row "$rollback_field")
        rollback_option=$(printf '%s' "$rollback_metadata" | cut -f2)
        sudo -n "$ryzenadj_command" "--$rollback_option=$rollback_value" \
            >/dev/null 2>&1 || true
    done
    rollback_metrics=$(mktemp)
    rollback_failures=''
    if read_power_metrics >"$rollback_metrics"; then
        for rollback_pair in $rollback_pairs; do
            rollback_field=${rollback_pair%%=*}
            rollback_value=${rollback_pair#*=}
            rollback_metadata=$(power_field_row "$rollback_field")
            rollback_label=$(printf '%s' "$rollback_metadata" | cut -f1)
            rollback_scale=$(printf '%s' "$rollback_metadata" | cut -f3)
            rollback_observed=$(scaled_row_value "$rollback_metrics" "$rollback_label" \
                "$rollback_scale") || rollback_observed=unreadable
            if [ "$rollback_observed" = unreadable ] ||
                ! within_readback_band "$rollback_observed" "$rollback_value" \
                    "$readback_tolerance"; then
                rollback_failures="${rollback_failures}${rollback_field}=${rollback_observed}(want=${rollback_value}) "
            fi
        done
    else
        rollback_failures='metrics=unreadable '
    fi
    rm -f -- "$rollback_metrics"
    if [ -n "$rollback_failures" ]; then
        printf 'power_envelope_rollback=failed profile=%s fields=%s snapshot=%s\n' \
            "$power_profile_name" "${rollback_failures% }" "$snapshot_file" >&2
        return 1
    fi
    rm -f -- "$snapshot_file"
    printf 'power_envelope_rollback=held profile=%s fields=%s\n' \
        "$power_profile_name" "${rollback_pairs% }" >&2
    return 0
}

# The thermal limit bounds the term rather than being written by it. A reading
# above the ceiling means the platform already runs hotter than any profile here
# is registered against, so the term refuses ahead of the first write.
require_thermal_ceiling() {
    thermal_limit=$(metrics_row_value "$1" 'THM LIMIT CORE') || {
        printf 'reason=metrics_row_missing row=%s; the power-metrics table carries no readable thermal limit\n' \
            'THM LIMIT CORE' >&2
        return 1
    }
    if ! LC_ALL=C awk -v observed="$thermal_limit" -v ceiling="$tctl_ceiling_c" \
        'BEGIN { exit (observed + 0 <= ceiling + 0) ? 0 : 1 }'; then
        printf 'reason=thermal_limit_above_ceiling observed_c=%s ceiling_c=%s; this term reads the thermal limit and never writes it\n' \
            "$thermal_limit" "$tctl_ceiling_c" >&2
        return 1
    fi
    printf '%s\n' "$thermal_limit"
    return 0
}

binary_digest() {
    LC_ALL=C sha256sum "$1" 2>/dev/null | awk '{ print $1; exit }' || true
}

subcommand=$1
shift

if [ "$subcommand" = status ]; then
    if [ "$#" -ne 0 ]; then
        usage
    fi
    if [ -e "$snapshot_file" ]; then
        snapshot_state=present
    else
        snapshot_state=absent
    fi
    if ! require_ryzenadj 2>/dev/null; then
        printf 'power_envelope=unavailable reason=ryzenadj_absent path=%s snapshot=%s\n' \
            "$ryzenadj_command" "$snapshot_state"
        exit 0
    fi
    if ! require_credential 2>/dev/null; then
        printf 'power_envelope=unavailable reason=sudo_credential_absent path=%s snapshot=%s\n' \
            "$ryzenadj_command" "$snapshot_state"
        exit 0
    fi
    status_metrics=$(mktemp)
    trap 'rm -f -- "$status_metrics"' EXIT HUP INT TERM
    if ! read_power_metrics >"$status_metrics"; then
        printf 'power_envelope=unavailable reason=metrics_read_failed path=%s snapshot=%s\n' \
            "$ryzenadj_command" "$snapshot_state"
        exit 0
    fi
    status_stapm=$(scaled_row_value "$status_metrics" 'STAPM LIMIT' 1000) || status_stapm=unavailable
    status_fast=$(scaled_row_value "$status_metrics" 'PPT LIMIT FAST' 1000) || status_fast=unavailable
    status_slow=$(scaled_row_value "$status_metrics" 'PPT LIMIT SLOW' 1000) || status_slow=unavailable
    status_tdc=$(scaled_row_value "$status_metrics" 'TDC LIMIT VDD' 1000) || status_tdc=unavailable
    status_edc=$(scaled_row_value "$status_metrics" 'EDC LIMIT VDD' 1000) || status_edc=unavailable
    status_thermal=$(metrics_row_value "$status_metrics" 'THM LIMIT CORE') || status_thermal=unavailable
    printf 'power_envelope=live stapm_limit_mw=%s fast_limit_mw=%s slow_limit_mw=%s vrm_current_ma=%s vrmmax_current_ma=%s tctl_limit_c=%s snapshot=%s\n' \
        "$status_stapm" "$status_fast" "$status_slow" "$status_tdc" "$status_edc" \
        "$status_thermal" "$snapshot_state"
    exit 0
fi

if [ "$subcommand" = restore ]; then
    if [ "$#" -ne 0 ]; then
        usage
    fi
    if [ ! -r "$snapshot_file" ]; then
        printf 'reason=snapshot_absent path=%s; restore reverses an apply and there is none to reverse\n' \
            "$snapshot_file" >&2
        exit 2
    fi
    # A claimed file with no content is an apply that died between its atomic
    # claim and its baseline record. The claim precedes every SMU write, so the
    # machine holds the platform's own budget and the reversal is the removal.
    if [ ! -s "$snapshot_file" ]; then
        rm -f -- "$snapshot_file"
        printf 'power_envelope_restored=held profile=unclaimed fields=none\n'
        exit 0
    fi
    snapshot_schema=$(LC_ALL=C awk -F'\t' '$1 == "schema" { print $2; exit }' "$snapshot_file")
    if [ "$snapshot_schema" != power-envelope-snapshot-v1 ]; then
        printf 'reason=snapshot_schema_unknown schema=%s path=%s\n' \
            "${snapshot_schema:-absent}" "$snapshot_file" >&2
        exit 2
    fi
    snapshot_owner=$(LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' "$snapshot_file")
    if [ "${snapshot_owner:-unowned}" != "$owner_token" ]; then
        printf 'reason=snapshot_owner_mismatch owner=%s caller=%s path=%s; another transaction is running under this envelope\n' \
            "${snapshot_owner:-unowned}" "$owner_token" "$snapshot_file" >&2
        exit 2
    fi
    snapshot_profile=$(LC_ALL=C awk -F'\t' '$1 == "profile" { print $2; exit }' "$snapshot_file")
    snapshot_fields=$(LC_ALL=C awk -F'\t' '$1 == "snapshot_field" { printf "%s=%s ", $2, $3 }' \
        "$snapshot_file")
    if [ -z "$snapshot_fields" ]; then
        rm -f -- "$snapshot_file"
        printf 'power_envelope_restored=held profile=%s fields=none\n' "${snapshot_profile:-unknown}"
        exit 0
    fi
    require_ryzenadj || exit 2
    require_credential || exit 2
    for restore_pair in $snapshot_fields; do
        restore_field=${restore_pair%%=*}
        restore_value=${restore_pair#*=}
        power_field_metadata=$(power_field_row "$restore_field") || {
            printf 'reason=unknown_snapshot_field field=%s path=%s\n' "$restore_field" \
                "$snapshot_file" >&2
            exit 2
        }
        restore_option=$(printf '%s' "$power_field_metadata" | cut -f2)
        # Every field is attempted and the read-back below is the verdict, so a
        # writer that refuses one limit still returns the others rather than
        # leaving the machine part way through a raised budget.
        sudo -n "$ryzenadj_command" "--$restore_option=$restore_value" >/dev/null 2>&1 || true
    done
    restore_metrics=$(mktemp)
    trap 'rm -f -- "$restore_metrics"' EXIT HUP INT TERM
    if ! read_power_metrics >"$restore_metrics"; then
        printf 'power_envelope_restored=failed profile=%s reason=metrics_read_failed\n' \
            "${snapshot_profile:-unknown}" >&2
        exit 4
    fi
    restore_failures=''
    for restore_pair in $snapshot_fields; do
        restore_field=${restore_pair%%=*}
        restore_value=${restore_pair#*=}
        power_field_metadata=$(power_field_row "$restore_field")
        restore_label=$(printf '%s' "$power_field_metadata" | cut -f1)
        restore_scale=$(printf '%s' "$power_field_metadata" | cut -f3)
        restore_observed=$(scaled_row_value "$restore_metrics" "$restore_label" \
            "$restore_scale") || restore_observed=unreadable
        if [ "$restore_observed" = unreadable ] ||
            ! within_readback_band "$restore_observed" "$restore_value" "$readback_tolerance"; then
            restore_failures="${restore_failures}${restore_field}=${restore_observed}(want=${restore_value}) "
        fi
    done
    if [ -n "$restore_failures" ]; then
        printf 'power_envelope_restored=failed profile=%s fields=%s snapshot=%s\n' \
            "${snapshot_profile:-unknown}" "${restore_failures% }" "$snapshot_file" >&2
        exit 4
    fi
    rm -f -- "$snapshot_file"
    printf 'power_envelope_restored=held profile=%s fields=%s\n' \
        "${snapshot_profile:-unknown}" "${snapshot_fields% }"
    exit 0
fi

if [ "$subcommand" != apply ] || [ "$#" -ne 1 ]; then
    usage
fi

power_profile_name=$1
resolve_power_profile "$power_profile_name"

require_ryzenadj || exit 2
require_credential || exit 2

if [ ! -d "$state_directory" ]; then
    printf 'reason=state_directory_absent path=%s\n' "$state_directory" >&2
    exit 2
fi

# A second apply over a live snapshot would record this term's own writes as the
# platform baseline, so the snapshot is the transaction. The claim is the
# creation itself: `set -C` opens with O_EXCL, so two concurrent applies cannot
# both pass, and the loser is refused by name rather than racing the winner to
# the SMU.
if ! (set -C; : >"$snapshot_file") 2>/dev/null; then
    printf 'reason=snapshot_present path=%s; a power envelope is already applied, so restore it before applying another\n' \
        "$snapshot_file" >&2
    exit 2
fi
chmod 0600 "$snapshot_file"

# Every refusal from here to the baseline record releases the claim, because
# each of them happens ahead of the first SMU write and leaves the machine on
# the platform's own budget.
release_claim() {
    rm -f -- "$snapshot_file"
}

apply_metrics=$(mktemp)
trap 'rm -f -- "$apply_metrics"' EXIT HUP INT TERM
if ! read_power_metrics >"$apply_metrics"; then
    printf 'reason=metrics_read_failed path=%s; ryzenadj --info answered nothing readable\n' \
        "$ryzenadj_command" >&2
    release_claim
    exit 2
fi

snapshot_thermal_limit=$(require_thermal_ceiling "$apply_metrics") || {
    release_claim
    exit 2
}

# Every field the profile writes is snapshotted before the first write, so a
# row the table does not carry refuses the term while the machine still holds
# the platform's own budget.
snapshot_pairs=''
for profile_pair in $profile_fields; do
    profile_field=${profile_pair%%=*}
    profile_value=${profile_pair#*=}
    case $profile_value in
        '' | *[!0-9]*)
            printf 'reason=profile_value_not_a_positive_integer profile=%s field=%s value=%s\n' \
                "$power_profile_name" "$profile_field" "$profile_value" >&2
            release_claim
            exit 2
            ;;
    esac
    power_field_metadata=$(power_field_row "$profile_field") || {
        printf 'reason=unknown_profile_field profile=%s field=%s\n' \
            "$power_profile_name" "$profile_field" >&2
        release_claim
        exit 2
    }
    field_label=$(printf '%s' "$power_field_metadata" | cut -f1)
    field_scale=$(printf '%s' "$power_field_metadata" | cut -f3)
    field_snapshot=$(scaled_row_value "$apply_metrics" "$field_label" "$field_scale") || {
        printf 'reason=metrics_row_missing profile=%s field=%s row=%s\n' \
            "$power_profile_name" "$profile_field" "$field_label" >&2
        release_claim
        exit 2
    }
    snapshot_pairs="${snapshot_pairs}${profile_field}=${field_snapshot} "
done

snapshot_file_new=$snapshot_file.new
{
    printf 'key\tvalue\tsnapshot\n'
    printf 'schema\tpower-envelope-snapshot-v1\t-\n'
    printf 'profile\t%s\t-\n' "$power_profile_name"
    printf 'owner\t%s\t-\n' "$owner_token"
    printf 'holder_pid\t%s\t-\n' "$$"
    printf 'ryzenadj\t%s\t-\n' "$ryzenadj_command"
    printf 'ryzenadj_sha256\t%s\t-\n' "$(binary_digest "$ryzenadj_command")"
    printf 'snapshot_tctl_limit_c\t%s\t-\n' "$snapshot_thermal_limit"
    printf 'tctl_ceiling_c\t%s\t-\n' "$tctl_ceiling_c"
    for snapshot_pair in $snapshot_pairs; do
        printf 'snapshot_field\t%s\t%s\n' "${snapshot_pair%%=*}" "${snapshot_pair#*=}"
    done
    for profile_pair in $profile_fields; do
        printf 'applied_field\t%s\t%s\n' "${profile_pair%%=*}" "${profile_pair#*=}"
    done
} >"$snapshot_file_new"
chmod 0600 "$snapshot_file_new"
mv -- "$snapshot_file_new" "$snapshot_file"

if [ -z "$profile_fields" ]; then
    printf 'power_envelope_applied=%s fields=none tctl_limit_c=%s snapshot=%s\n' \
        "$power_profile_name" "$snapshot_thermal_limit" "$snapshot_file"
    exit 0
fi

for profile_pair in $profile_fields; do
    profile_field=${profile_pair%%=*}
    profile_value=${profile_pair#*=}
    power_field_metadata=$(power_field_row "$profile_field")
    field_option=$(printf '%s' "$power_field_metadata" | cut -f2)
    if ! sudo -n "$ryzenadj_command" "--$field_option=$profile_value" >/dev/null 2>&1; then
        printf 'reason=smu_write_refused profile=%s field=%s option=%s value=%s\n' \
            "$power_profile_name" "$profile_field" "$field_option" "$profile_value" >&2
        roll_back_partial_apply "$snapshot_pairs" || exit 4
        exit 3
    fi
done

# The write is a request and the power-metrics table is the answer, so the
# profile is proven by a second read rather than by the exit status of the
# writer. A platform that re-asserts its own limit reports here.
apply_readback=$(mktemp)
trap 'rm -f -- "$apply_metrics" "$apply_readback"' EXIT HUP INT TERM
if ! read_power_metrics >"$apply_readback"; then
    printf 'reason=readback_read_failed profile=%s\n' "$power_profile_name" >&2
    roll_back_partial_apply "$snapshot_pairs" || exit 4
    exit 3
fi

apply_failures=''
applied_report=''
for profile_pair in $profile_fields; do
    profile_field=${profile_pair%%=*}
    profile_value=${profile_pair#*=}
    power_field_metadata=$(power_field_row "$profile_field")
    field_label=$(printf '%s' "$power_field_metadata" | cut -f1)
    field_scale=$(printf '%s' "$power_field_metadata" | cut -f3)
    field_observed=$(scaled_row_value "$apply_readback" "$field_label" "$field_scale") ||
        field_observed=unreadable
    if [ "$field_observed" = unreadable ] ||
        ! within_readback_band "$field_observed" "$profile_value" "$readback_tolerance"; then
        apply_failures="${apply_failures}${profile_field}=${field_observed}(want=${profile_value}) "
    fi
    applied_report="${applied_report}${profile_field}=${field_observed} "
done

if [ -n "$apply_failures" ]; then
    printf 'power_envelope_applied=unreached profile=%s fields=%s snapshot=%s\n' \
        "$power_profile_name" "${apply_failures% }" "$snapshot_file" >&2
    roll_back_partial_apply "$snapshot_pairs" || exit 4
    exit 3
fi

printf 'power_envelope_applied=%s fields=%s tctl_limit_c=%s snapshot=%s\n' \
    "$power_profile_name" "${applied_report% }" "$snapshot_thermal_limit" "$snapshot_file"
