#!/bin/sh
set -eu

# The coupled power/CPU/clock factorial campaign
# evidence/power-factorial/README.md registers, run one checkpoint at a time.
#
# The campaign is one mirrored, control-bracketed sequence rather than one
# pairwise comparison at a time, generalizing the mirrored quadruple
# run-power-envelope-campaign.sh runs (control, 20 W, 25 W, control) to the
# campaign's own nine-arm ladder: the uncontrolled baseline opens and closes
# the sequence, and P1 through P4 plus the three factor-pair alternates run
# between them in registered order. The closing control's agreement with the
# opening one is what licenses reading every arm between them as an effect of
# its own compute state rather than as position in a sequence, the same
# licensing rule evidence/decode-bound-analysis.md and
# evidence/model-admission/runtime-class-throughput.md apply to their own
# sweeps. remote/summarize-power-factorial.py reads pairwise comparisons out
# of this one sequence rather than requiring each pair to run as its own
# bracket: P1 against the opening control, P2 against P1, P3 against P2, P4
# against P3, and each factor-pair alternate against P4, all inside the one
# sweep this script runs.
#
# Every arm is one compute-state-lease.sh transaction running
# run-power-factorial-arm.sh as its command, so the graphics clock, the
# fabric clock, the memory scanner, the process priority, the CPU frequency
# cap, and the package budget are one reversible state per arm.
# run-power-factorial-arm.sh's `served` instrument runs
# run-power-envelope-arm.sh, which measures decode through
# measure-served-decode.sh -- therefore qwen-launch.sh, therefore
# monitor-qwen-runtime.sh, which unconditionally renices itself to 0 and
# exits `reason=monitor_exited` where it cannot. Every arm P0 through P4 and
# the ksm/cap factor-pair alternates therefore carries a `serve-*` profile
# (nice 0), the same constraint serve-fixed-package-* is already built
# against. The nice factor-pair alternate is the one exception: nice 19
# cannot run through the served harness at all, so it carries
# `measure-fixed-cpu-capped-fclk-range-package-25w` (nice 19) and this
# script's fourth run_one_arm argument selects run-power-factorial-arm.sh's
# `bench` instrument for it, which measures decode with a direct llama-bench
# invocation outside the guarded launch chain instead -- the scope cut
# evidence/power-factorial/README.md registers ahead of any run.
#
# The served runner validates an execution proof at
# `$QWEN_RESULT_DIRECTORY/../../campaign-inputs.tsv`, so the campaign
# directory holds that proof and every arm directory sits two levels below
# it, the same layout run-power-envelope-campaign.sh keeps. A second
# invocation into the same campaign directory reuses the proof and refuses a
# byte difference, because a proof rewritten between checkpoints would leave
# the arms measured under two contracts.

usage() {
    printf 'usage: %s MODEL_ID CAMPAIGN_DIRECTORY\n' "$0" >&2
    exit 2
}

if [ "$#" -ne 2 ]; then
    usage
fi

model_id=$1
campaign_directory=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
runtime_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
lease_command=${QWEN_COMPUTE_STATE_LEASE:-$script_directory/compute-state-lease.sh}
arm_command=${QWEN_POWER_FACTORIAL_ARM:-$script_directory/run-power-factorial-arm.sh}
registry_reader=$script_directory/model-registry.sh
state_directory=${QWEN_STATE_DIRECTORY:-"$qwen_home_state"}
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
envelope_snapshot=${QWEN_POWER_ENVELOPE_SNAPSHOT:-$state_directory/power-envelope-snapshot.tsv}
cpu_cap_snapshot=${QWEN_CPU_FREQUENCY_CAP_SNAPSHOT:-$state_directory/cpu-frequency-cap-snapshot.tsv}
cooldown_seconds=${QWEN_POWER_FACTORIAL_COOLDOWN_S:-30}
# The sustained arm exists to span the 200 s STAPM/PPT averaging window, and
# a token count states a duration only against a rate. 2400 tokens clears that
# window at 12 tok/s and falls short of it above them: the 0.8B class decodes
# at 15 to 19 tok/s, where 2400 tokens is about 125 to 160 s. The count is
# therefore a request rather than a proof, and the arm records the count it
# ran so summarize-power-factorial.py divides it by that arm's own measured
# rate and refuses a package receipt whose window the run did not span.
sustained_generate_tokens=${QWEN_POWER_FACTORIAL_SUSTAINED_GENERATE:-2400}
# The horizon the sustained arm must span, from the stock envelope's own
# STAPM averaging window.
sustained_window_seconds=${QWEN_POWER_FACTORIAL_SUSTAINED_WINDOW_S:-200}
export QWEN_POWER_FACTORIAL_SUSTAINED_WINDOW_S=$sustained_window_seconds
campaign_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

case $campaign_directory in
    /*) ;;
    *)
        printf 'campaign directory must be absolute: %s\n' "$campaign_directory" >&2
        exit 2
        ;;
esac
case $cooldown_seconds in
    '' | *[!0-9]*)
        printf 'campaign cooldown must be a non-negative integer: %s\n' \
            "$cooldown_seconds" >&2
        exit 2
        ;;
esac

# The campaign measures the appliance through the SSH surface the fixed-64
# denominator is measured on, so the markers are proven ahead of the first arm
# rather than assumed by the runner two levels down. This is the same gate
# run-power-envelope-campaign.sh applies, over the same two markers.
host_shortname=$(hostname -s 2>/dev/null || true)
host_shortname=$(printf '%s' "$host_shortname" | \
    LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'the power-factorial campaign requires measured host hp14-dk1xxx: observed=%s\n' \
        "${host_shortname:-absent}" >&2
    exit 2
fi
if ! python3 - "${SSH_CONNECTION:-}" <<'PY'
import ipaddress
import sys

fields = sys.argv[1].split()
if len(fields) != 4:
    raise SystemExit(1)
for address in (fields[0], fields[2]):
    try:
        ipaddress.ip_address(address)
    except ValueError:
        raise SystemExit(1) from None
for port in (fields[1], fields[3]):
    if not port.isascii() or not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise SystemExit(1)
PY
then
    printf 'the power-factorial campaign requires a structurally valid inherited SSH session\n' >&2
    exit 2
fi
if ! sudo -n true 2>/dev/null; then
    printf 'reason=sudo_credential_absent; the SMU writer, cpupower, the boost node, and the energy reader all need it, so run `sudo -v` first\n' >&2
    exit 2
fi
if [ ! -x "$lease_command" ] || [ ! -x "$arm_command" ]; then
    printf 'the campaign needs both the lease and the arm: %s %s\n' \
        "$lease_command" "$arm_command" >&2
    exit 2
fi
"$registry_reader" id "$model_id" >/dev/null

transaction_revision=${QWEN_COMPUTE_STATE_REVISION:-}
if [ -z "$transaction_revision" ] && \
   [ -r "$runtime_root/runtime-tree-manifest.tsv" ]; then
    transaction_revision=$(awk -F'\t' '$1 == "git_head" { print $2; exit }' \
        "$runtime_root/runtime-tree-manifest.tsv")
fi
if [ -z "$transaction_revision" ]; then
    transaction_revision=$(git -C "$script_directory" rev-parse HEAD 2>/dev/null) || \
        transaction_revision=''
fi
case $transaction_revision in
    ????????????????????????????????????????)
        case $transaction_revision in
            *[!0-9a-f]*)
                printf 'the runtime tree revision is not 40 hexadecimal characters: %s\n' \
                    "$transaction_revision" >&2
                exit 2
                ;;
        esac
        ;;
    *)
        printf 'the runtime tree revision is not 40 hexadecimal characters: %s; name QWEN_COMPUTE_STATE_REVISION\n' \
            "${transaction_revision:-absent}" >&2
        exit 2
        ;;
esac

mkdir -p -- "$campaign_directory/arms"
campaign_inputs=$campaign_directory/campaign-inputs.tsv
campaign_inputs_new=$campaign_directory/.campaign-inputs.tsv.new
{
    printf 'key\tvalue\n'
    printf 'schema\tfixed64-served-campaign-v2\n'
    printf 'campaign\tpower-factorial-v1\n'
    printf 'runtime_revision\t%s\n' "$transaction_revision"
    printf 'campaign_output_directory\t%s\n' "$campaign_directory"
    printf 'models_directory\t%s\n' "$models_directory"
    printf 'state_directory\t%s\n' "$state_directory"
    printf 'execution_path\t%s\n' "$campaign_path"
    printf 'execution_surface\thp14-ssh\n'
    printf 'host_shortname\thp14-dk1xxx\n'
    printf 'ssh_session\tpresent\n'
    printf 'vulkan_profile\tlow-async\n'
    printf 'inference_cpu\t0\n'
    printf 'server_port\t8080\n'
    printf 'bind_host\t127.0.0.1\n'
    printf 'latency_mode\tobserve\n'
    printf 'router\t0\n'
    printf 'speculation\toff\n'
    printf 'backend_sampling\t0\n'
    printf 'require_api_key\t0\n'
    printf 'web_broker\t0\n'
    printf 'image_service\t0\n'
    printf 'generate_tokens\t64\n'
    printf 'sampling\ttemperature=0 top_k=1 seed=1 ignore_eos=true thinking=false\n'
    printf 'arm_order\tcontrol-open(P0),P1,P2,P3,P4,P4-ksm-alt,P4-cap-alt,P4-nice-alt(bench),control-close(P0)\n'
    printf 'cooldown_seconds\t%s\n' "$cooldown_seconds"
} >"$campaign_inputs_new"
if [ -e "$campaign_inputs" ]; then
    if ! cmp -s "$campaign_inputs_new" "$campaign_inputs"; then
        rm -f -- "$campaign_inputs_new"
        printf 'reason=campaign_inputs_differ path=%s; a campaign directory carries one contract\n' \
            "$campaign_inputs" >&2
        exit 2
    fi
    rm -f -- "$campaign_inputs_new"
else
    mv -- "$campaign_inputs_new" "$campaign_inputs"
fi

arm_status=$campaign_directory/arm-status.tsv
if [ ! -e "$arm_status" ]; then
    printf 'arm\tmodel_id\tprofile\tlease_status\n' >"$arm_status"
fi

run_one_arm() {
    arm_slot=$1
    arm_role=$2
    lease_profile=$3
    # A fourth argument names the arm's instrument, `served` by default; a
    # fifth names its generation length, 64 tokens by default. The
    # transaction closes the environment its command runs under, so both
    # reach the arm through QWEN_COMPUTE_STATE_FORWARD rather than through
    # this shell's own ambient environment.
    arm_instrument=${4:-served}
    arm_generate=${5:-64}
    arm_name=$model_id-$arm_slot-$arm_role
    if [ -e "$envelope_snapshot" ]; then
        printf 'reason=envelope_snapshot_present path=%s; restore it under its own owner before the next arm\n' \
            "$envelope_snapshot" >&2
        exit 2
    fi
    if [ -e "$cpu_cap_snapshot" ]; then
        printf 'reason=cpu_cap_snapshot_present path=%s; restore it under its own owner before the next arm\n' \
            "$cpu_cap_snapshot" >&2
        exit 2
    fi
    if ! sudo -n true 2>/dev/null; then
        printf 'reason=sudo_credential_expired arm=%s; the campaign stops with its retained arms intact\n' \
            "$arm_name" >&2
        exit 2
    fi
    printf 'power_factorial_campaign=arm_start model=%s arm=%s profile=%s\n' \
        "$model_id" "$arm_name" "$lease_profile"
    set +e
    # Each arm restores the governor before the next one starts, so every arm
    # writes its manual mask onto a device sitting at the 400 MHz idle step;
    # the firmware took 26.8 seconds to raise the delivered clock from there on
    # this part, so the proof deadline is thirty seconds rather than the ten a
    # warm device needs, the same margin run-power-envelope-campaign.sh gives
    # every arm.
    env \
        PATH="$campaign_path" LC_ALL=C PYTHONDONTWRITEBYTECODE=1 \
        QWEN_COMPUTE_STATE_REVISION="$transaction_revision" \
        QWEN_COMPUTE_STATE_CLOCK_DEADLINE_S=30 \
        QWEN_COMPUTE_STATE_FORWARD="QWEN_POWER_FACTORIAL_INSTRUMENT=$arm_instrument QWEN_BENCH_GENERATE=$arm_generate" \
        "$lease_command" "$lease_profile" \
        "$arm_command" "$campaign_directory" "$arm_name" "$model_id" \
        >"$campaign_directory/arms/.$arm_name.stdout" \
        2>"$campaign_directory/arms/.$arm_name.stderr"
    lease_status=$?
    set -e
    mv -- "$campaign_directory/arms/.$arm_name.stdout" \
        "$campaign_directory/arms/$arm_name.lease.stdout"
    mv -- "$campaign_directory/arms/.$arm_name.stderr" \
        "$campaign_directory/arms/$arm_name.lease.stderr"
    printf '%s\t%s\t%s\t%s\n' "$arm_name" "$model_id" "$lease_profile" \
        "$lease_status" >>"$arm_status"
    if [ "$lease_status" -ne 0 ]; then
        printf 'power_factorial_campaign=failed model=%s arm=%s lease_status=%s\n' \
            "$model_id" "$arm_name" "$lease_status" >&2
        # Exit status 4 is the lease's own restoration incident and dominates
        # every other reading, so it is propagated rather than flattened.
        exit "$lease_status"
    fi
    printf 'power_factorial_campaign=arm_completed model=%s arm=%s\n' \
        "$model_id" "$arm_name"
    if [ "$cooldown_seconds" -gt 0 ]; then
        sleep "$cooldown_seconds"
    fi
}

run_one_arm 01 control-open serve-auto-baseline
run_one_arm 02 p1-gfx-fclk-pin serve-fixed-package-default
run_one_arm 03 p2-cpu-capped serve-fixed-cpu-capped
run_one_arm 04 p3-fclk-range serve-fixed-cpu-capped-fclk-range
run_one_arm 05 p3-ksm-alt serve-fixed-cpu-capped-fclk-range-ksm-running
run_one_arm 06 p3-cap-alt serve-fixed-fclk-range
run_one_arm 07 p3-nice-alt measure-fixed-cpu-capped-fclk-range bench
# The sustained arm runs at the stock envelope (P1's own profile) for longer
# than the 200 s STAPM averaging window, so its two `ryzenadj --info`
# snapshots (retained by run-power-envelope-arm.sh's own instrument at the
# arm's start and end, inside its `.served` subdirectory) bracket that window
# rather than a few seconds of it. Its own decode window is what
# evidence/power-factorial/README.md's sustained falsifier reads.
run_one_arm 08 sustained-stock serve-fixed-package-default served "$sustained_generate_tokens"
run_one_arm 09 control-close serve-auto-baseline

# P4 raises the package budget over P3, and this campaign runs it only where
# the sustained arm's own telemetry shows the stock budget binding: PPT VALUE
# FAST or SLOW within package_binding_margin_mw of its own LIMIT, or STAPM
# VALUE within the same margin of 15000 mW, read from the later of the
# sustained arm's two `ryzenadj --info` snapshots. QWEN_POWER_FACTORIAL_
# PACKAGE_RECEIPT names a directory carrying that snapshot directly (an
# operator's own retained arm from an earlier campaign run); its absence
# defaults to this campaign's own sustained arm, so a fresh campaign gates P4
# on the telemetry it just measured rather than on a stale claim.
package_receipt_directory=${QWEN_POWER_FACTORIAL_PACKAGE_RECEIPT:-$campaign_directory/arms/$model_id-08-sustained-stock.served}
package_receipt_snapshot=$package_receipt_directory/ryzenadj-info-end.txt
package_binding_margin_mw=${QWEN_POWER_FACTORIAL_PACKAGE_BINDING_MARGIN_MW:-1000}
package_binding=no
if [ -r "$package_receipt_snapshot" ]; then
    package_binding=$(LC_ALL=C awk -F'|' -v margin="$package_binding_margin_mw" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        function watts_to_mw(s) { return (s + 0) * 1000 }
        NF >= 4 {
            name = trim($2); value = trim($3)
            if (value !~ /^-?[0-9]+([.][0-9]+)?$/) next
            if (name == "STAPM VALUE") { stapm_value = watts_to_mw(value) }
            if (name == "STAPM LIMIT") { stapm_limit = watts_to_mw(value) }
            if (name == "PPT VALUE FAST") { fast_value = watts_to_mw(value) }
            if (name == "PPT LIMIT FAST") { fast_limit = watts_to_mw(value) }
            if (name == "PPT VALUE SLOW") { slow_value = watts_to_mw(value) }
            if (name == "PPT LIMIT SLOW") { slow_limit = watts_to_mw(value) }
        }
        END {
            if (stapm_limit && (stapm_limit - stapm_value) <= margin) { print "yes"; exit }
            if (fast_limit && (fast_limit - fast_value) <= margin) { print "yes"; exit }
            if (slow_limit && (slow_limit - slow_value) <= margin) { print "yes"; exit }
            print "no"
        }' "$package_receipt_snapshot")
fi
printf 'power_factorial_campaign=package_receipt directory=%s snapshot=%s binding=%s margin_mw=%s\n' \
    "$package_receipt_directory" "$package_receipt_snapshot" "$package_binding" \
    "$package_binding_margin_mw"
if [ "$package_binding" = yes ]; then
    run_one_arm 10 p4-package-25w serve-fixed-cpu-capped-fclk-range-package-25w
else
    printf 'power_factorial_campaign=p4_skipped reason=no_binding_receipt path=%s\n' \
        "$package_receipt_snapshot"
fi

printf 'power_factorial_campaign=completed model=%s campaign_directory=%s\n' \
    "$model_id" "$campaign_directory"
