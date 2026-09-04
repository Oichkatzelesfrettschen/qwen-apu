#!/bin/sh
set -eu

# The package-power campaign evidence/power-envelope/README.md registers, run
# one checkpoint at a time.
#
# Each checkpoint takes the mirrored order the tree reads a pair inside:
# control, 20 W, 25 W, control. The closing control's agreement with the opening
# one is what licenses reading the two candidates as budget effects rather than
# as position in a sequence, and a checkpoint is the unit of invocation because
# the SMU credential is time-bounded and a complete checkpoint is worth more
# than four truncated ones.
#
# Every arm is one compute-state-lease.sh transaction, so the graphics clock,
# the fabric clock, the memory scanner, the process priority, and the package
# budget are one reversible state. The three `serve-fixed-package-*` profiles
# carry `measure-fixed`'s clocks, memory scanner, and cores and differ in the
# SMU's sustained and package power limits alone; they leave the child at nice
# 0 because the guarded launch chain sets the served process priorities itself,
# putting llama-server on core 0 at nice 19 while its runtime monitor requires
# nice 0. The arm applies nice 19 to its own samplers rather than inheriting
# it.
#
# The served runner validates an execution proof at
# `$QWEN_RESULT_DIRECTORY/../../campaign-inputs.tsv`, so the campaign directory
# holds that proof and every arm directory sits two levels below it. A second
# invocation into the same campaign directory reuses the proof and refuses a
# byte difference, because a proof rewritten between checkpoints would leave the
# arms measured under two contracts.

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
runtime_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
lease_command=${QWEN_COMPUTE_STATE_LEASE:-$script_directory/compute-state-lease.sh}
arm_command=${QWEN_POWER_ENVELOPE_ARM:-$script_directory/run-power-envelope-arm.sh}
registry_reader=$script_directory/model-registry.sh
state_directory=${QWEN_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
envelope_snapshot=${QWEN_POWER_ENVELOPE_SNAPSHOT:-$state_directory/power-envelope-snapshot.tsv}
cooldown_seconds=${QWEN_POWER_ENVELOPE_COOLDOWN_S:-30}
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
# rather than assumed by the runner two levels down.
host_shortname=$(hostname -s 2>/dev/null || true)
host_shortname=$(printf '%s' "$host_shortname" | \
    LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'the package-power campaign requires measured host hp14-dk1xxx: observed=%s\n' \
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
    printf 'the package-power campaign requires a structurally valid inherited SSH session\n' >&2
    exit 2
fi
if ! sudo -n true 2>/dev/null; then
    printf 'reason=sudo_credential_absent; the SMU writer and the energy reader both need it, so run `sudo -v` first\n' >&2
    exit 2
fi
if [ ! -x "$lease_command" ] || [ ! -x "$arm_command" ]; then
    printf 'the campaign needs both the lease and the arm: %s %s\n' \
        "$lease_command" "$arm_command" >&2
    exit 2
fi
"$registry_reader" id "$model_id" >/dev/null

# The runtime tree is a copy rather than a checkout, so the revision the lease
# proof names comes from the manifest the sync wrote beside remote/.
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
    printf 'campaign\tpower-envelope-v1\n'
    printf 'runtime_revision\t%s\n' "$transaction_revision"
    printf 'campaign_output_directory\t%s\n' "$campaign_directory"
    printf 'models_directory\t%s\n' "$models_directory"
    printf 'state_directory\t%s\n' "$state_directory"
    printf 'execution_path\t%s\n' "$campaign_path"
    printf 'execution_surface\thp14-ssh\n'
    printf 'host_shortname\thp14-dk1xxx\n'
    printf 'ssh_session\tpresent\n'
    printf 'server_nice\t19\n'
    printf 'server_io_class\tidle\n'
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
    printf 'arm_order\tcontrol,package-20w,package-25w,control\n'
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
    arm_name=$model_id-$arm_slot-$arm_role
    if [ -e "$envelope_snapshot" ]; then
        printf 'reason=envelope_snapshot_present path=%s; restore it under its own owner before the next arm\n' \
            "$envelope_snapshot" >&2
        exit 2
    fi
    if ! sudo -n true 2>/dev/null; then
        printf 'reason=sudo_credential_expired arm=%s; the campaign stops with its retained arms intact\n' \
            "$arm_name" >&2
        exit 2
    fi
    printf 'power_envelope_campaign=arm_start model=%s arm=%s profile=%s\n' \
        "$model_id" "$arm_name" "$lease_profile"
    set +e
    env \
        PATH="$campaign_path" LC_ALL=C PYTHONDONTWRITEBYTECODE=1 \
        QWEN_COMPUTE_STATE_REVISION="$transaction_revision" \
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
        printf 'power_envelope_campaign=failed model=%s arm=%s lease_status=%s\n' \
            "$model_id" "$arm_name" "$lease_status" >&2
        # Exit status 4 is the lease's own restoration incident and dominates
        # every other reading, so it is propagated rather than flattened.
        exit "$lease_status"
    fi
    printf 'power_envelope_campaign=arm_completed model=%s arm=%s\n' \
        "$model_id" "$arm_name"
    if [ "$cooldown_seconds" -gt 0 ]; then
        sleep "$cooldown_seconds"
    fi
}

run_one_arm 01 control-open serve-fixed-package-default
run_one_arm 02 package-20w serve-fixed-package-20w
run_one_arm 03 package-25w serve-fixed-package-25w
run_one_arm 04 control-close serve-fixed-package-default

printf 'power_envelope_campaign=completed model=%s campaign_directory=%s\n' \
    "$model_id" "$campaign_directory"
