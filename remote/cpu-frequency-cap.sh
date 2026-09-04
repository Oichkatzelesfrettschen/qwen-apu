#!/bin/sh
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

# One reversible CPU-frequency term for the compute-state transaction.
#
# `acpi-cpufreq` enumerates the `_PSS` table at 1.4, 1.7, and 2.3 GHz and the
# schedutil governor picks among those states, but core performance boost sits
# above the table entirely: CLAUDE.md's own measured read shows a core at
# 3.169 GHz against a 2.3 GHz cpufreq ceiling, so the table alone never bounds
# what a core delivers while boost is armed. `cpupower frequency-set -u` writes
# the per-policy scaling ceiling every governor including schedutil respects,
# and `/sys/devices/system/cpu/cpufreq/boost` is the second and separate
# authority: a policy capped at 2.3 GHz with boost still at 1 lets CPB raise
# the core past that ceiling anyway, so a cap profile writes both.
# `cpupower frequency-set -u 2.3GHz` and `-g GOVERNOR` are the only cpupower
# writes this term issues; the governor stays schedutil on every profile
# defined here, so `-g` is exercised only where a profile's own field asks for
# it.
#
# The term is reversible the way power-envelope.sh's is. `apply` snapshots the
# live scaling ceiling, governor, and boost state per core before the first
# write, `restore` writes that snapshot back through the same cpupower/sysfs
# path and reads every value back, and a value that fails to return ends the
# term non-zero rather than silently. The snapshot file is the ownership
# token: `set -C` opens it O_EXCL, so a second concurrent apply is refused by
# name rather than racing the first to the same cores, and `QWEN_CPU_FREQUENCY_
# CAP_OWNER` lets a wrapping transaction restore only the snapshot it claimed.
#
# `cpupower` writes system-wide policy and this term verifies through direct
# sysfs reads per core, the same split compute-state-lease.sh keeps between a
# sudo-only writer and an unprivileged reader: `remote/test-cpu-frequency-cap.sh`
# fakes the sysfs tree under QWEN_SYSFS_ROOT and the cpupower binary under
# QWEN_CPUPOWER, so the whole apply/restore/status contract runs without a GPU,
# a CPU, or a credential.

usage() {
    printf 'usage: %s apply PROFILE\n' "$0" >&2
    printf '       %s restore\n' "$0" >&2
    printf '       %s status\n' "$0" >&2
    printf 'profiles: base-clock-cap\n' >&2
    exit 2
}

if [ "$#" -lt 1 ]; then
    usage
fi

cpupower_command=${QWEN_CPUPOWER:-cpupower}
sysfs_root=${QWEN_SYSFS_ROOT:-/sys}
cpu_root=$sysfs_root/devices/system/cpu
boost_node=${QWEN_CPU_BOOST_NODE:-$cpu_root/cpufreq/boost}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
snapshot_file=${QWEN_CPU_FREQUENCY_CAP_SNAPSHOT:-$state_directory/cpu-frequency-cap-snapshot.tsv}
cpu_list=${QWEN_CPU_FREQUENCY_CAP_CPU_LIST:-0 1}
# A wrapping transaction (compute-state-lease.sh) names its own per-run
# token explicitly on both `apply` and `restore`, so two concurrent
# transactions never restore each other's claim. A direct, standalone
# invocation names neither: `apply` and `restore` are two separate processes
# with two separate PIDs, so a PID-derived default here would make
# `cpu-frequency-cap.sh restore` fail its own owner check against the
# snapshot its own `apply` just claimed -- codex flagged exactly that defect
# in power-envelope.sh's identical `power-envelope.$$` default. The fixed
# literal below is what a standalone round trip needs; it carries no PID and
# names no transaction, so it never collides with a wrapping transaction's own
# random token.
owner_token=${QWEN_CPU_FREQUENCY_CAP_OWNER:-cpu-frequency-cap.standalone}

# A profile names the upper-bound frequency in kilohertz, the cpupower argument
# that requests it, and the boost value the cap requires. `base-clock-cap` pins
# the ceiling at the `_PSS` table's own top entry rather than below it, so the
# profile measures boost's contribution alone rather than also taking a step
# off the governed table.
resolve_cpu_profile() {
    case $1 in
        base-clock-cap)
            profile_upper_khz=2300000
            profile_upper_argument=2300MHz
            profile_governor=''
            profile_boost=0
            ;;
        *)
            printf 'unknown CPU frequency profile: %s\n' "$1" >&2
            usage
            ;;
    esac
}

require_cpupower() {
    case $cpupower_command in
        */*)
            if [ ! -x "$cpupower_command" ]; then
                printf 'reason=cpupower_absent path=%s\n' "$cpupower_command" >&2
                return 1
            fi
            ;;
        *)
            if ! command -v "$cpupower_command" >/dev/null 2>&1; then
                printf 'reason=cpupower_absent path=%s\n' "$cpupower_command" >&2
                return 1
            fi
            ;;
    esac
    return 0
}

require_credential() {
    if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
        printf 'reason=sudo_credential_absent; this term writes cpupower and the boost node through sudo -n and never prompts, so run `sudo -v` first\n' >&2
        return 1
    fi
    return 0
}

read_or_unreadable() {
    if [ -r "$1" ]; then
        LC_ALL=C tr -d ' \t\n' <"$1" 2>/dev/null || printf 'unreadable\n'
    else
        printf 'unreadable\n'
    fi
}

read_scaling_max_khz() {
    read_or_unreadable "$cpu_root/cpu$1/cpufreq/scaling_max_freq"
}

read_governor() {
    read_or_unreadable "$cpu_root/cpu$1/cpufreq/scaling_governor"
}

read_boost() {
    read_or_unreadable "$boost_node"
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
    if ! require_cpupower 2>/dev/null; then
        printf 'cpu_frequency_cap=unavailable reason=cpupower_absent path=%s snapshot=%s\n' \
            "$cpupower_command" "$snapshot_state"
        exit 0
    fi
    if ! require_credential 2>/dev/null; then
        printf 'cpu_frequency_cap=unavailable reason=sudo_credential_absent path=%s snapshot=%s\n' \
            "$cpupower_command" "$snapshot_state"
        exit 0
    fi
    status_fields=''
    for status_cpu in $cpu_list; do
        status_fields="${status_fields}cpu${status_cpu}_max_khz=$(read_scaling_max_khz "$status_cpu") "
        status_fields="${status_fields}cpu${status_cpu}_governor=$(read_governor "$status_cpu") "
    done
    printf 'cpu_frequency_cap=live %sboost=%s snapshot=%s\n' \
        "$status_fields" "$(read_boost)" "$snapshot_state"
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
    if [ ! -s "$snapshot_file" ]; then
        rm -f -- "$snapshot_file"
        printf 'cpu_frequency_cap_restored=held profile=unclaimed fields=none\n'
        exit 0
    fi
    snapshot_schema=$(LC_ALL=C awk -F'\t' '$1 == "schema" { print $2; exit }' "$snapshot_file")
    if [ "$snapshot_schema" != cpu-frequency-cap-snapshot-v1 ]; then
        printf 'reason=snapshot_schema_unknown schema=%s path=%s\n' \
            "${snapshot_schema:-absent}" "$snapshot_file" >&2
        exit 2
    fi
    snapshot_owner=$(LC_ALL=C awk -F'\t' '$1 == "owner" { print $2; exit }' "$snapshot_file")
    if [ "${snapshot_owner:-unowned}" != "$owner_token" ]; then
        printf 'reason=snapshot_owner_mismatch owner=%s caller=%s path=%s; another transaction is running under this cap\n' \
            "${snapshot_owner:-unowned}" "$owner_token" "$snapshot_file" >&2
        exit 2
    fi
    snapshot_profile=$(LC_ALL=C awk -F'\t' '$1 == "profile" { print $2; exit }' "$snapshot_file")
    require_cpupower || exit 2
    require_credential || exit 2

    restore_failures=''
    for restore_cpu in $cpu_list; do
        restore_max=$(LC_ALL=C awk -F'\t' -v cpu="$restore_cpu" \
            '$1 == "snapshot_max_khz" && $2 == cpu { print $3; exit }' "$snapshot_file")
        case ${restore_max:-} in
            '' | *[!0-9]*) continue ;;
        esac
        sudo -n "$cpupower_command" --cpu "$restore_cpu" frequency-set \
            -u "${restore_max}KHz" >/dev/null 2>&1 || true
        restore_observed=$(read_scaling_max_khz "$restore_cpu")
        if [ "$restore_observed" != "$restore_max" ]; then
            restore_failures="${restore_failures}cpu${restore_cpu}_max_khz=${restore_observed}(want=${restore_max}) "
        fi
    done
    snapshot_boost=$(LC_ALL=C awk -F'\t' '$1 == "snapshot_boost" { print $2; exit }' "$snapshot_file")
    if [ -n "${snapshot_boost:-}" ]; then
        printf '%s\n' "$snapshot_boost" | sudo -n tee "$boost_node" >/dev/null 2>&1 || true
        restore_observed_boost=$(read_boost)
        if [ "$restore_observed_boost" != "$snapshot_boost" ]; then
            restore_failures="${restore_failures}boost=${restore_observed_boost}(want=${snapshot_boost}) "
        fi
    fi

    if [ -n "$restore_failures" ]; then
        printf 'cpu_frequency_cap_restored=failed profile=%s fields=%s snapshot=%s\n' \
            "${snapshot_profile:-unknown}" "${restore_failures% }" "$snapshot_file" >&2
        exit 4
    fi
    rm -f -- "$snapshot_file"
    printf 'cpu_frequency_cap_restored=held profile=%s\n' "${snapshot_profile:-unknown}"
    exit 0
fi

if [ "$subcommand" != apply ] || [ "$#" -ne 1 ]; then
    usage
fi

cpu_profile_name=$1
resolve_cpu_profile "$cpu_profile_name"

require_cpupower || exit 2
require_credential || exit 2

if [ ! -d "$state_directory" ]; then
    printf 'reason=state_directory_absent path=%s\n' "$state_directory" >&2
    exit 2
fi

if ! (set -C; : >"$snapshot_file") 2>/dev/null; then
    printf 'reason=snapshot_present path=%s; a CPU frequency cap is already applied, so restore it before applying another\n' \
        "$snapshot_file" >&2
    exit 2
fi
chmod 0600 "$snapshot_file"

release_claim() {
    rm -f -- "$snapshot_file"
}

snapshot_pairs=''
for snapshot_cpu in $cpu_list; do
    snapshot_max=$(read_scaling_max_khz "$snapshot_cpu")
    if [ "$snapshot_max" = unreadable ]; then
        printf 'reason=scaling_max_freq_unreadable cpu=%s\n' "$snapshot_cpu" >&2
        release_claim
        exit 2
    fi
    snapshot_pairs="${snapshot_pairs}${snapshot_cpu}=${snapshot_max} "
done
snapshot_boost=$(read_boost)
if [ "$snapshot_boost" = unreadable ]; then
    printf 'reason=boost_node_unreadable path=%s\n' "$boost_node" >&2
    release_claim
    exit 2
fi

snapshot_file_new=$snapshot_file.new
{
    printf 'key\tvalue\tvalue2\n'
    printf 'schema\tcpu-frequency-cap-snapshot-v1\t-\n'
    printf 'profile\t%s\t-\n' "$cpu_profile_name"
    printf 'owner\t%s\t-\n' "$owner_token"
    printf 'holder_pid\t%s\t-\n' "$$"
    printf 'snapshot_boost\t%s\t-\n' "$snapshot_boost"
    for snapshot_pair in $snapshot_pairs; do
        printf 'snapshot_max_khz\t%s\t%s\n' "${snapshot_pair%%=*}" "${snapshot_pair#*=}"
    done
} >"$snapshot_file_new"
chmod 0600 "$snapshot_file_new"
mv -- "$snapshot_file_new" "$snapshot_file"

apply_failures=''
for apply_cpu in $cpu_list; do
    if ! sudo -n "$cpupower_command" --cpu "$apply_cpu" frequency-set \
        -u "$profile_upper_argument" >/dev/null 2>&1; then
        apply_failures="${apply_failures}cpu${apply_cpu}_max=write_refused "
        continue
    fi
    apply_observed=$(read_scaling_max_khz "$apply_cpu")
    if [ "$apply_observed" != "$profile_upper_khz" ]; then
        apply_failures="${apply_failures}cpu${apply_cpu}_max_khz=${apply_observed}(want=${profile_upper_khz}) "
    fi
done
if [ -n "$profile_governor" ]; then
    for governor_cpu in $cpu_list; do
        sudo -n "$cpupower_command" --cpu "$governor_cpu" frequency-set \
            -g "$profile_governor" >/dev/null 2>&1 || \
            apply_failures="${apply_failures}cpu${governor_cpu}_governor=write_refused "
    done
fi
printf '%s\n' "$profile_boost" | sudo -n tee "$boost_node" >/dev/null 2>&1 || \
    apply_failures="${apply_failures}boost=write_refused "
apply_observed_boost=$(read_boost)
if [ "$apply_observed_boost" != "$profile_boost" ]; then
    apply_failures="${apply_failures}boost=${apply_observed_boost}(want=${profile_boost}) "
fi

if [ -n "$apply_failures" ]; then
    printf 'cpu_frequency_cap_applied=unreached profile=%s fields=%s snapshot=%s\n' \
        "$cpu_profile_name" "${apply_failures% }" "$snapshot_file" >&2
    exit 3
fi

printf 'cpu_frequency_cap_applied=%s upper_khz=%s boost=%s snapshot=%s\n' \
    "$cpu_profile_name" "$profile_upper_khz" "$profile_boost" "$snapshot_file"
exit 0
