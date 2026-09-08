#!/bin/sh
set -eu

# One served launch separates readiness, completed warmup and repeated decode.
# The ordinary-appliance fixed-clock cell preserves KSM as found, leaves the
# standing VM running and uses stock package power. The lease orchestrator and
# monitor run at nice 0; serving policy assigns inference priority independently.
# A bracket supplies two launches per role and reports a descriptive ratio.
#
# usage: run-checkpoint-baseline.sh MODEL_ID OUTPUT_DIRECTORY
#        run-checkpoint-baseline.sh --bracket CONTROL_SERVER CANDIDATE_SERVER \
#            MODEL_ID OUTPUT_DIRECTORY
#   QWEN_LLAMA_SERVER            the server the single-checkpoint form measures
#   QWEN_BASELINE_REPEATS        fixed-64 requests per arm, default 4, 2 through 16
#   QWEN_BENCH_GENERATE          tokens each request decodes, default 64
#   QWEN_BASELINE_PROFILE        submission profile the arms launch under,
#                                default low-async
#   QWEN_BASELINE_READY_DEADLINE_S  readiness deadline per arm, default 300
#   QWEN_BASELINE_COOLDOWN_S     seconds between arms, default 30
#   QWEN_CENSUS_SIDECAR_*        the sampler geometry the census calibrated
#   QWEN_CENSUS_MCLK_FLOOR_MHZ   fabric floor the clock invariant holds, default 933

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# The manifest binding, the base-build identity, and the closed arm environment
# are the census campaigns' own, and a rule tightened for either reaches here.
# shellcheck source=remote/census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"
# shellcheck source=remote/checkpoint-baseline-lib.sh
. "$script_directory/checkpoint-baseline-lib.sh"

usage() {
    printf 'usage: %s MODEL_ID OUTPUT_DIRECTORY\n' "$0" >&2
    printf '       %s --bracket CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIRECTORY\n' \
        "$0" >&2
    exit 2
}

mode=single
control_server=''
candidate_server=''
if [ "${1:-}" = --bracket ]; then
    [ "$#" -eq 5 ] || usage
    mode=bracket
    control_server=$2
    candidate_server=$3
    model_id=$4
    output_directory=$5
else
    [ "$#" -eq 2 ] || usage
    model_id=$1
    output_directory=$2
    control_server=${QWEN_LLAMA_SERVER:-}
    if [ -z "$control_server" ]; then
        printf 'the single-checkpoint form measures the server QWEN_LLAMA_SERVER names\n' >&2
        exit 2
    fi
fi

case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac
if [ -e "$output_directory" ]; then
    printf 'output directory exists and a baseline never appends to one: %s\n' \
        "$output_directory" >&2
    exit 2
fi

repeats=${QWEN_BASELINE_REPEATS:-4}
case $repeats in
    '' | *[!0-9]* | 0* | 1 | ??????????*) usage_repeats=1 ;;
    *) usage_repeats=0 ;;
esac
if [ "$usage_repeats" -eq 1 ] || [ "$repeats" -gt 16 ]; then
    printf 'QWEN_BASELINE_REPEATS is a count from 2 through 16: %s\n' "$repeats" >&2
    exit 2
fi
generate_tokens=${QWEN_BENCH_GENERATE:-64}
case $generate_tokens in
    '' | *[!0-9]* | 0* | 1 | ??????????*)
        printf 'QWEN_BENCH_GENERATE covers at least one decode transition: %s\n' \
            "$generate_tokens" >&2
        exit 2
        ;;
esac
profile=${QWEN_BASELINE_PROFILE:-low-async}
request_deadline=${QWEN_BASELINE_REQUEST_DEADLINE_S:-900}
export QWEN_BASELINE_REQUEST_DEADLINE_S=$request_deadline
ready_deadline=${QWEN_BASELINE_READY_DEADLINE_S:-300}
cooldown_s=${QWEN_BASELINE_COOLDOWN_S:-30}
for bounded_value in "$ready_deadline" "$request_deadline" "$cooldown_s" "$generate_tokens"; do
    case $bounded_value in '' | *[!0-9]* | 0* | ??????*)
        printf 'baseline deadlines and counts require bounded positive decimal integers: %s\n' "$bounded_value" >&2
        exit 2 ;;
    esac
    [ "$bounded_value" -le 32768 ] || exit 2
done
sampling_seed=1
# One prompt for every arm and every repeat, stated here rather than read from a
# file, so the request digest identifies the campaign's own workload and a
# retained arm names the text it decoded.
baseline_prompt='Write one paragraph about tides.'

registry_reader=$script_directory/model-registry.sh
launch_script=${QWEN_LAUNCH_SCRIPT:-"$script_directory/qwen-launch.sh"}
teardown_script=${QWEN_TEARDOWN_SCRIPT:-"$script_directory/qwen-teardown.sh"}
state_directory=${QWEN_STATE_DIRECTORY:-"$qwen_home_state"}
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
summarizer=$script_directory/summarize-checkpoint-baseline.py
sidecar=${QWEN_CENSUS_BROKER:-"$qwen_home_build_cache/telemetry-broker"}
sidecar_validator=$script_directory/validate-clock-sidecar.py
lease_verifier=$script_directory/verify-external-vulkan-lease.py
quiescence_poller=$script_directory/await-quiescence.sh
endpoint=http://127.0.0.1:${QWEN_SERVER_PORT:-8080}
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}

# Bind delivered frequency and temperature to the selected DRM device.
sidecar_hwmon=''
for hwmon_entry in "${QWEN_HWMON_ROOT:-$drm_device/hwmon}"/*; do
    [ -r "$hwmon_entry/name" ] || continue
    [ "$(cat "$hwmon_entry/name")" = amdgpu ] || continue
    if [ -n "$sidecar_hwmon" ]; then
        printf 'baseline requires one amdgpu hwmon sensor directory\n' >&2
        exit 2
    fi
    sidecar_hwmon=$hwmon_entry
done
if [ -z "$sidecar_hwmon" ] || [ ! -r "$sidecar_hwmon/freq1_input" ] || [ ! -r "$sidecar_hwmon/temp1_input" ]; then
    printf 'baseline requires readable amdgpu hwmon freq1_input and temp1_input before acquisition\n' >&2
    exit 2
fi

sidecar_source_sha256=$(sha256sum "$script_directory/telemetry-broker.c" | cut -d ' ' -f 1)
if [ ! -f "$sidecar.source-sha256" ] || [ "$(cat "$sidecar.source-sha256")" != "$sidecar_source_sha256" ]; then
    printf 'baseline requires a broker built from the recorded source before the window\n' >&2
    exit 2
fi

for required_reader in "$summarizer" "$sidecar" "$sidecar_validator"; do
    if [ ! -r "$required_reader" ]; then
        printf 'reader is absent: %s\n' "$required_reader" >&2
        exit 2
    fi
done

# The sidecar geometry is the census campaign's, read under its own names, since
# one machine carries one acquisition contract. The gap bound is the forced
# policy's 250 ms rather than the governor's 100 ms: serve-baseline-fixed holds one
# level and the samples bracketing a gap state what the firmware held inside it.
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-20}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
sidecar_max_lost=${QWEN_CENSUS_SIDECAR_MAX_LOST:-0.03}
sidecar_cpu=${QWEN_CENSUS_SIDECAR_CPU:-0,1}
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-250}
case $sidecar_max_gap_ms in '' | *[!0-9]* | 0* | ?????*) exit 2 ;; esac
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))
mclk_floor_mhz=${QWEN_CENSUS_MCLK_FLOOR_MHZ:-933}
python3 - "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_max_lost" "$sidecar_cpu" <<'PY'
import math
import re
import sys
period, tolerance, cost, lost, affinity = sys.argv[1:]
for name, raw, low, high in (("period", period, 1, 100), ("tolerance", tolerance, 0, 1), ("lost", lost, 0, 1)):
    value = float(raw)
    if not math.isfinite(value) or not low <= value <= high:
        raise SystemExit(f"sampler {name} is outside its finite bounds")
if not re.fullmatch(r"[1-9][0-9]{0,8}", cost) or affinity != "0,1":
    raise SystemExit("baseline sampler requires a bounded cost and registered affinity 0,1")
PY
case $mclk_floor_mhz in
    0 | 0[0-9]* | '' | *[!0-9]*)
        printf 'QWEN_CENSUS_MCLK_FLOOR_MHZ is a positive megahertz count: %s\n' \
            "$mclk_floor_mhz" >&2
        exit 2
        ;;
esac
# The registered cell requires table level 2 at 1100 MHz.
sclk_path=$drm_device/pp_dpm_sclk
if [ ! -r "$sclk_path" ]; then
    printf 'the clock invariant reads pp_dpm_sclk: %s\n' "$sclk_path" >&2
    exit 2
fi
required_sclk_mhz=$(census_engine_clock_level_mhz "$sclk_path" 2) || {
    printf 'pp_dpm_sclk lists no graphics clock step: %s\n' "$sclk_path" >&2
    exit 2
}

if [ "${QWEN_COMPUTE_STATE_PROFILE:-}" != serve-baseline-fixed ]; then
    printf 'baseline requires compute-state-lease.sh serve-baseline-fixed\n' >&2
    exit 2
fi
if [ "$(ps -o ni= -p "$$" | tr -d ' ')" != 0 ]; then
    printf 'baseline orchestrator requires nice 0\n' >&2
    exit 2
fi
[ "$required_sclk_mhz" = 1100 ] && [ "$mclk_floor_mhz" = 933 ] || exit 2
baseline_require_inherited_lease "$state_directory" \
    "${QWEN_VULKAN_EXTERNAL_LEASE_PROOF:-}" "$lease_verifier" || exit 2

# The registry resolves the row; the served argv later proves what the policy
# built from it, and the two are compared per arm.
"$registry_reader" id "$model_id" >/dev/null
model_file=$("$registry_reader" id "$model_id" model_file)
model_path=$models_directory/$model_file
registry_context=$("$registry_reader" id "$model_id" context_default)
registry_batch=$("$registry_reader" id "$model_id" batch)
registry_ubatch=$("$registry_reader" id "$model_id" ubatch)
registry_cache_k=$("$registry_reader" id "$model_id" cache_type_k)
registry_cache_v=$("$registry_reader" id "$model_id" cache_type_v)
registry_flash=$("$registry_reader" id "$model_id" flash_attention)
ctx_checkpoints=$("$registry_reader" ctx-checkpoint "$model_id")
registry_q4k_variant=$("$registry_reader" id "$model_id" q4k_variant)
[ "$registry_q4k_variant" != - ] || registry_q4k_variant=production/4
registry_q4k_variant=${QWEN_BASELINE_Q4K_VARIANT:-$registry_q4k_variant}
"$registry_reader" validate-q4k-variant "$registry_q4k_variant" || exit 2
if [ ! -r "$model_path" ]; then
    printf 'model file is unreadable: %s\n' "$model_path" >&2
    exit 2
fi
# The checkpoint every arm decodes is bound by its own bytes at preflight. A
# model replaced between two arms would otherwise leave the bracket's roles
# measured on different weights while each arm's own read agreed with itself.
model_bytes=$(wc -c <"$model_path" | tr -d ' ')
model_sha256=$(sha256sum "$model_path" | cut -d ' ' -f 1)
# The registry names a file and the artifact ledger states what that file's
# bytes are, so a checkpoint replaced, truncated, or re-fetched under a row that
# still resolves refuses here rather than being measured under the identity the
# receipt would claim. The ledger is the same publisher-identity authority
# measure-served-decode.sh compares its descriptor-bound read against.
artifact_ledger=${QWEN_MODEL_ARTIFACTS:-"$script_directory/model-artifacts.tsv"}
if [ ! -r "$artifact_ledger" ] || [ -L "$artifact_ledger" ]; then
    printf 'model artifact ledger is unreadable or linked: %s\n' "$artifact_ledger" >&2
    exit 2
fi
ledger_bytes=$(awk -F'\t' -v id="$model_id" '$1 == id { count++; print $3 }
    END { exit count == 1 ? 0 : 1 }' "$artifact_ledger") || {
    printf 'the model artifact ledger resolves no single row for %s\n' "$model_id" >&2
    exit 2
}
ledger_sha256=$(awk -F'\t' -v id="$model_id" '$1 == id { print $4 }' "$artifact_ledger")
if [ "$model_bytes" != "$ledger_bytes" ] || [ "$model_sha256" != "$ledger_sha256" ]; then
    printf 'the resolved checkpoint differs from its publisher identity: %s carries %s bytes at %s where the ledger states %s bytes at %s\n' \
        "$model_path" "$model_bytes" "$model_sha256" "$ledger_bytes" \
        "$ledger_sha256" >&2
    exit 2
fi

# One server per role, each bound to the manifest beside it. census_bind_server
# proves the manifest describes the executable and that its checkpoint semantics
# admit the count this row serves, which is the same rule the served A/B and the
# census runner apply.
bind_role() {
    bind_role_name=$1
    bind_role_server=$2
    bind_role_manifest=$(census_manifest_beside "$bind_role_server" "$bind_role_name")
    set +e
    bind_role_binding=$(census_bind_server "$bind_role_name" "$bind_role_server" \
        "$bind_role_manifest" "$ctx_checkpoints")
    bind_role_status=$?
    set -e
    [ "$bind_role_status" -eq 0 ] || exit "$bind_role_status"
    census_require_binding_fields "$bind_role_name" "$bind_role_binding"
    printf '%s\t%s\n' "$bind_role_binding" "$bind_role_manifest"
}

control_binding=$(bind_role control "$control_server") || exit 2
IFS="$baseline_tab" read -r control_sha256 control_bytes control_manifest_sha256 \
    control_semantics control_series control_manifest <<EOF
$control_binding
EOF
control_patch_series=$(census_manifest_value "$control_manifest" \
    checkpoint_patch_series_sha256 control) || exit 2
candidate_sha256=-
candidate_bytes=-
candidate_manifest_sha256=-
candidate_semantics=-
candidate_series=-
candidate_patch_series=-
if [ "$mode" = bracket ]; then
    candidate_binding=$(bind_role candidate "$candidate_server") || exit 2
    IFS="$baseline_tab" read -r candidate_sha256 candidate_bytes \
        candidate_manifest_sha256 candidate_semantics candidate_series \
        candidate_manifest <<EOF
$candidate_binding
EOF
    candidate_patch_series=$(census_manifest_value "$candidate_manifest" \
        checkpoint_patch_series_sha256 candidate) || exit 2
    if [ "$control_sha256" = "$candidate_sha256" ]; then
        printf 'the control and the candidate are one executable: %s\n' \
            "$control_sha256" >&2
        exit 2
    fi
    # Two binaries compared as a bracket must differ by the candidate alone, so
    # each manifest yields a base build identity and the two are required equal.
    identity_scratch=$(mktemp -d)
    census_base_build_identity "$control_manifest" "$control_server" control \
        "$identity_scratch/control" ''
    census_base_build_identity "$candidate_manifest" "$candidate_server" candidate \
        "$identity_scratch/candidate" ''
    if ! cmp -s "$identity_scratch/control" "$identity_scratch/candidate"; then
        printf 'the control and candidate servers descend from different base builds:\n' >&2
        diff -- "$identity_scratch/control" "$identity_scratch/candidate" >&2 || true
        rm -r -- "$identity_scratch"
        exit 2
    fi
    rm -r -- "$identity_scratch"
fi

# shellcheck disable=SC2154  # qwen-home.sh declares the runtime result root
case $(realpath -m -- "$output_directory") in
    "$qwen_home_results"/*) ;;
    *) printf 'baseline acquisitions belong under the runtime results root\n' >&2; exit 2 ;;
esac
mkdir -p "$output_directory/arms"
cp -- "$control_manifest" "$output_directory/control-manifest.tsv"
if [ "$mode" = bracket ]; then
    cp -- "$candidate_manifest" "$output_directory/candidate-manifest.tsv"
fi
runtime_manifest=$script_directory/runtime-tree-manifest.tsv
[ -f "$runtime_manifest" ] || runtime_manifest=$script_directory/../runtime-tree-manifest.tsv
"$script_directory/check-runtime-tree.sh" "$script_directory/.." >"$output_directory/runtime-check.txt" || exit 2
cp -- "$runtime_manifest" "$output_directory/runtime-tree-manifest.tsv" || exit 2
python3 - "$runtime_manifest" "$script_directory/.." "$output_directory/runtime-source.tar" <<'PY'
import hashlib
import sys
import tarfile
from pathlib import Path
manifest, root, output = sys.argv[1:]
with tarfile.open(output, "w") as archive:
    for line in Path(manifest).read_text().splitlines():
        fields = line.split("\t")
        if len(fields) == 3 and fields[0].startswith(("remote/", "patches/")):
            source = Path(root, fields[0])
            if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != fields[1]:
                raise SystemExit("runtime payload changed before retention")
            archive.add(source, arcname=fields[0], recursive=False)
PY
cp -- "$script_directory/summarize-checkpoint-baseline.py" "$output_directory/acquisition-reader.py"
cp -- "$script_directory/checkpoint-baseline-lib.sh" "$output_directory/acquisition-lib.sh"
cp -- "$0" "$output_directory/acquisition-runner.sh"
cp -- "$sidecar_validator" "$output_directory/acquisition-clock-validator.py"
cp -- "$sidecar" "$output_directory/acquisition-sampler"
cp -- "$script_directory/telemetry-broker.c" "$output_directory/acquisition-sampler.c"
cp -- "$script_directory/compute-state-lease.sh" "$output_directory/acquisition-lease.sh"
cp -- "$QWEN_COMPUTE_STATE_RECORD" "$output_directory/compute-state.tsv"
{
    printf 'key\tvalue\n'
    printf 'period_ms\t%s\nperiod_tolerance\t%s\ncost_bound_ns\t%s\nmax_gap_ns\t%s\nmax_lost_fraction\t%s\n' \
        "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_max_gap_ns" "$sidecar_max_lost"
    printf 'allowed_unavailable\tpp_dpm_fclk_surface_mhz\n'
    printf 'nice\t19\ncpu_affinity\t%s\nsclk_source\tsclk_actual_mhz\n' "$sidecar_cpu"
    printf 'hwmon_path\t%s\n' "$sidecar_hwmon"
} >"$output_directory/sampler-contract.tsv"
ttft_body=$output_directory/request-ttft.json
decode_body=$output_directory/request-decode.json
baseline_request_body "$ttft_body" "$baseline_prompt" "$generate_tokens" \
    "$sampling_seed" 1
baseline_request_body "$decode_body" "$baseline_prompt" "$generate_tokens" \
    "$sampling_seed" 0
ttft_request_sha256=$(sha256sum "$ttft_body" | cut -d ' ' -f 1)
decode_request_sha256=$(sha256sum "$decode_body" | cut -d ' ' -f 1)

{
    printf 'key\tvalue\n'
    printf 'schema\tcheckpoint-baseline-identity-v2\n'
    for identity_file in runtime-tree-manifest.tsv runtime-source.tar acquisition-reader.py \
        acquisition-lib.sh acquisition-runner.sh acquisition-clock-validator.py \
        acquisition-sampler acquisition-sampler.c acquisition-lease.sh compute-state.tsv sampler-contract.tsv; do
        printf '%s_sha256\t%s\n' "$identity_file" "$(sha256sum "$output_directory/$identity_file" | cut -d ' ' -f 1)"
    done
    printf 'mode\t%s\n' "$mode"
    printf 'compute_state_profile\tserve-baseline-fixed\nksm_policy\tpreserve-as-found\n'
    printf 'q4k_variant\t%s\nthreads\t1\nthreads_batch\t1\ndevice\tVulkan0\ngpu_layers\tall\n' "$registry_q4k_variant"
    printf 'model_id\t%s\n' "$model_id"
    printf 'model_file\t%s\n' "$model_file"
    printf 'model_bytes\t%s\n' "$model_bytes"
    printf 'model_sha256\t%s\n' "$model_sha256"
    printf 'registry_context\t%s\n' "$registry_context"
    printf 'registry_batch\t%s\n' "$registry_batch"
    printf 'registry_ubatch\t%s\n' "$registry_ubatch"
    printf 'registry_cache_type_k\t%s\n' "$registry_cache_k"
    printf 'registry_cache_type_v\t%s\n' "$registry_cache_v"
    printf 'registry_flash_attention\t%s\n' "$registry_flash"
    printf 'registry_ctx_checkpoints\t%s\n' "$ctx_checkpoints"
    printf 'control_server_sha256\t%s\n' "$control_sha256"
    printf 'control_server_bytes\t%s\n' "$control_bytes"
    printf 'control_manifest_sha256\t%s\n' "$control_manifest_sha256"
    printf 'control_checkpoint_semantics\t%s\n' "$control_semantics"
    printf 'control_candidate_series\t%s\n' "$control_series"
    printf 'control_patch_series_sha256\t%s\n' "$control_patch_series"
    printf 'candidate_server_sha256\t%s\n' "$candidate_sha256"
    printf 'candidate_server_bytes\t%s\n' "$candidate_bytes"
    printf 'candidate_manifest_sha256\t%s\n' "$candidate_manifest_sha256"
    printf 'candidate_checkpoint_semantics\t%s\n' "$candidate_semantics"
    printf 'candidate_candidate_series\t%s\n' "$candidate_series"
    printf 'candidate_patch_series_sha256\t%s\n' "$candidate_patch_series"
    printf 'ttft_request_sha256\t%s\n' "$ttft_request_sha256"
    printf 'decode_request_sha256\t%s\n' "$decode_request_sha256"
    printf 'generate_tokens\t%s\n' "$generate_tokens"
    printf 'repeats\t%s\n' "$repeats"
    printf 'profile\t%s\n' "$profile"
    printf 'required_sclk_mhz\t%s\n' "$required_sclk_mhz"
    printf 'mclk_floor_mhz\t%s\n' "$mclk_floor_mhz"
} >"$output_directory/identity.tsv"

teardown_arm() {
    timeout --signal=TERM --kill-after=5 60 sh -c 'exec "$0" "$@" 8>&- 9>&-' "$teardown_script" \
        >>"$output_directory/teardown.txt" 2>&1 || return 1
}
sidecar_pid=''
sidecar_status=unrun
arm_directory=''
arm_reason=-
cleanup_status=unrun
stop_sidecar() {
    [ -n "$sidecar_pid" ] || return 0
    kill -TERM "$sidecar_pid" 2>/dev/null || true
    sidecar_status=0
    # The owned child is given a bounded drain; the wait status remains authoritative.
    python3 -c 'import os, signal, sys, time; time.sleep(5); os.kill(int(sys.argv[1]), signal.SIGKILL)' "$sidecar_pid" 2>/dev/null &
    sidecar_guard=$!
    wait "$sidecar_pid" 2>/dev/null || sidecar_status=$?
    kill -TERM "$sidecar_guard" 2>/dev/null || true
    wait "$sidecar_guard" 2>/dev/null || true
    sidecar_pid=''
}
write_terminal() {
    [ -n "$arm_directory" ] || return 0
    printf 'key\tvalue\nstatus\t%s\nreason\t%s\nsidecar_status\t%s\nvalidator_status\t%s\nteardown_status\t%s\nquiescence_status\t%s\n' \
        "$arm_status" "$arm_reason" "$sidecar_status" "${validator_status:-unrun}" \
        "$cleanup_status" "${quiescence_status:-unrun}" >"$arm_directory/terminal.tsv"
}
cleanup() {
    original_status=$?
    trap - EXIT INT TERM
    stop_sidecar
    cleanup_status=0
    teardown_arm || cleanup_status=$?
    if [ "$original_status" -ne 0 ] && [ -n "$arm_directory" ] && [ ! -f "$arm_directory/terminal.tsv" ]; then
        arm_status=incomplete
        [ "$arm_reason" != - ] || arm_reason=interrupted
        write_terminal
        printf '%s\t%s\t%s\t%s\tincomplete\t%s\n' "$arm_slot" "$arm_letter" "$arm_role" "$arm_digest" "$arm_reason" >>"$output_directory/arms.tsv"
    fi
    printf 'key\tvalue\nstatus\t%s\ncleanup_status\t%s\n' \
        "$original_status" "$cleanup_status" >"$output_directory/run-terminal.tsv"
    [ "$original_status" -ne 0 ] || original_status=$cleanup_status
    exit "$original_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

api_key=''
if [ -s "$state_directory/api.key" ]; then
    api_key=$(sed -n '1p' "$state_directory/api.key")
fi

printf 'slot\tarm\trole\tserver_sha256\tstatus\treason\n' >"$output_directory/arms.tsv"

case $mode in
    bracket) arm_list='C K K C' ;;
    *) arm_list=B ;;
esac

run_arm() {
    arm_slot=$1
    arm_letter=$2
    case $arm_letter in
        K) arm_role=candidate; arm_server=$candidate_server; arm_digest=$candidate_sha256 ;;
        C) arm_role=control; arm_server=$control_server; arm_digest=$control_sha256 ;;
        *) arm_role=subject; arm_server=$control_server; arm_digest=$control_sha256 ;;
    esac
    arm_directory=$output_directory/arms/$arm_slot-$arm_role
    mkdir -p "$arm_directory"
    printf 'key\tvalue\nslot\t%s\nrole\t%s\nserver\t%s\nserver_sha256\t%s\n' \
        "$arm_slot" "$arm_role" "$arm_server" "$arm_digest" \
        >"$arm_directory/arm-inputs.tsv"

    arm_reason=-
    arm_status=completed
    sidecar_status=unrun
    validator_status=unrun
    quiescence_status=unrun
    cleanup_status=unrun
    if [ "$arm_slot" = 01 ]; then
        quiescence_status=0
        "$quiescence_poller" --sclk-forced --max-seconds "$cooldown_s" --drm-device "$drm_device" \
            >"$arm_directory/initial-quiescence.txt" 2>&1 || quiescence_status=$?
        if [ "$quiescence_status" -ne 0 ]; then
            arm_status=incomplete
            arm_reason=quiescence
            write_terminal
            printf '%s\t%s\t%s\t%s\tincomplete\tquiescence\n' "$arm_slot" "$arm_letter" "$arm_role" "$arm_digest" >>"$output_directory/arms.tsv"
            return 1
        fi
    fi
    QWEN_SERVER_HOST=127.0.0.1 \
    QWEN_ROUTER=0 \
    QWEN_Q4K_EXPERIMENT_ARM=1 \
    QWEN_Q4K_VARIANT=$registry_q4k_variant \
    QWEN_LLAMA_SERVER=$arm_server \
    QWEN_MODEL_PATH=$model_path \
        baseline_launch "$arm_directory" "$launch_script" "$profile" \
        "$endpoint" "$ready_deadline" || {
        printf '%s\t%s\t%s\t%s\tfailed\tlaunch\n' "$arm_slot" "$arm_letter" "$arm_role" \
            "$arm_digest" >>"$output_directory/arms.tsv"
        arm_reason=launch
        arm_status=failed
        write_terminal
        return 1
    }
    # The load record ends where the readiness poll did, so the slot and role
    # travel with it and the summarizer reads both off the arm's own file.
    printf 'slot\t%s\nrole\t%s\n' "$arm_slot" "$arm_role" >>"$arm_directory/load.tsv"

    if ! baseline_served_tuple "$arm_directory" "$state_directory"; then
        arm_status=failed
        arm_reason=served_tuple
    elif ! baseline_compare_tuple "$arm_directory/served-tuple.tsv" \
        "$registry_context" "$registry_batch" "$registry_ubatch" \
        "$registry_cache_k" "$registry_cache_v" "$registry_flash" \
        "$ctx_checkpoints"; then
        # Recording the served tuple beside the registry row states two claims
        # and settles neither, so the arm requires them equal: a preset section,
        # a cache override, or a validated-depth clamp that moved one of the
        # seven fields serves a checkpoint the identity record does not describe,
        # and the rate it produced belongs to that other tuple.
        arm_status=failed
        arm_reason=tuple_mismatch
    fi
    if [ "$arm_status" = completed ] && ! baseline_process_identity "$arm_directory" \
        "$state_directory" "$arm_server" "$arm_digest" "$model_path" "$registry_q4k_variant" "$endpoint"; then
        arm_status=failed
        arm_reason=process_identity
    fi
    if [ "$arm_status" = completed ] && \
        ! baseline_first_token "$arm_directory" "$endpoint" "$ttft_body" "$api_key"; then
        arm_status=failed
        arm_reason=first_token
    fi

    if [ "$arm_status" = completed ]; then
        # The sidecar covers the decode block alone: the load and the first
        # token are their own quantities and a window spanning them would price
        # a clock the steady rate never ran at.
        "$sidecar" "$arm_directory/clock-samples.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" \
            --drm-device "$drm_device" --hwmon "$sidecar_hwmon" \
            2>"$arm_directory/sidecar.stderr" &
        sidecar_pid=$!
        if ! baseline_await_sampler "$arm_directory/sidecar.stderr" "$sidecar_pid"; then
            arm_status=failed
            arm_reason=clock_invariant
        fi
        window_begin_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
        if [ "$arm_status" = completed ] && ! baseline_decode_block "$arm_directory" "$endpoint" "$decode_body" \
            "$api_key" "$repeats" "$generate_tokens"; then
            arm_status=failed
            arm_reason=decode_block
        fi
        window_end_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
        sleep 0.3
        stop_sidecar
        printf 'key\tvalue\nclock\tCLOCK_MONOTONIC\nbegin_ns\t%s\nend_ns\t%s\n' \
            "$window_begin_ns" "$window_end_ns" \
            >"$arm_directory/decode-window.tsv"
        validator_status=0
        "$sidecar_validator" "$arm_directory/clock-samples.tsv" \
            --sidecar-status "$sidecar_status" --allow-unavailable pp_dpm_fclk_surface_mhz --expected-nice 19 --expected-cpu-affinity "$sidecar_cpu" --period-ms "$sidecar_period_ms" \
            --period-tolerance "$sidecar_tolerance" \
            --cost-bound-ns "$sidecar_cost_ns" \
            --max-gap-ns "$sidecar_max_gap_ns" \
            --max-lost-fraction "$sidecar_max_lost" \
            --window-begin-ns "$window_begin_ns" \
            --window-end-ns "$window_end_ns" \
            --required-sclk-mhz "$required_sclk_mhz" \
            --required-mclk-mhz "$mclk_floor_mhz" \
            >"$arm_directory/clock-validation.txt" 2>&1 || validator_status=$?
        if [ "$sidecar_status" != 0 ] || [ "$validator_status" -ne 0 ] || \
            ! grep -q 'sclk_source=sclk_actual_mhz' "$arm_directory/clock-validation.txt"; then
            arm_status=failed
            [ "$arm_reason" = - ] && arm_reason=clock_invariant
        fi
    fi

    cleanup_status=0
    teardown_arm || {
        cleanup_status=$?
        arm_status=failed
        [ "$arm_reason" = - ] && arm_reason=teardown
    }
    if ! baseline_retain_runtime_evidence "$arm_directory" "$state_directory"; then
        arm_status=failed
        [ "$arm_reason" = - ] && arm_reason=runtime_evidence
    fi
    if [ "$arm_status" = completed ]; then
        quiescence_status=0
        "$quiescence_poller" --sclk-forced --max-seconds "$cooldown_s" --drm-device "$drm_device" \
            >"$arm_directory/quiescence.txt" 2>&1 || quiescence_status=$?
        if [ "$quiescence_status" -ne 0 ]; then
            arm_status=incomplete
            arm_reason=quiescence
        fi
    fi
    write_terminal
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$arm_slot" "$arm_letter" "$arm_role" \
        "$arm_digest" "$arm_status" "$arm_reason" >>"$output_directory/arms.tsv"
    [ "$arm_status" = completed ] || return 1
}

slot_index=0
run_status=0
for arm_letter in $arm_list; do
    slot_index=$((slot_index + 1))
    slot_label=$(printf '%02d' "$slot_index")
    if ! run_arm "$slot_label" "$arm_letter"; then
        run_status=1
        break
    fi
done

stop_sidecar

if [ "$run_status" -ne 0 ]; then
    printf 'checkpoint_baseline=failed model_id=%s output_directory=%s\n' \
        "$model_id" "$output_directory" >&2
    exit 1
fi

"$summarizer" "$output_directory" --write >/dev/null || {
    printf 'checkpoint_baseline=unsummarized model_id=%s output_directory=%s\n' \
        "$model_id" "$output_directory" >&2
    exit 1
}
printf 'checkpoint_baseline=completed model_id=%s mode=%s output_directory=%s\n' \
    "$model_id" "$mode" "$output_directory"
