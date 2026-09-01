#!/bin/sh
set -eu

# Exercise the complete campaign contract with tiny model files and a fake
# child runner. The test starts no server, model, GPU, or remote workload.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
work_directory=$(mktemp -d "$repository_root/.test-fixed64-campaign.XXXXXX")
runner_sigkill_cleanup_pid=''
runner_sigkill_cleanup_start=''
cleanup_runner_sigkill_workload() {
    [ -n "$runner_sigkill_cleanup_pid" ] || return 0
    cleanup_observed_start=$(sed 's/^.*) //' \
        "/proc/$runner_sigkill_cleanup_pid/stat" 2>/dev/null | \
        awk '{ print $20 }' || true)
    if [ "$cleanup_observed_start" = "$runner_sigkill_cleanup_start" ]; then
        kill -TERM "$runner_sigkill_cleanup_pid" 2>/dev/null || true
        cleanup_wait=0
        while [ -r "/proc/$runner_sigkill_cleanup_pid/stat" ] && \
              [ "$cleanup_wait" -lt 100 ]; do
            cleanup_state=$(sed 's/^.*) //' \
                "/proc/$runner_sigkill_cleanup_pid/stat" 2>/dev/null | \
                awk '{ print $1 }' || true)
            [ "$cleanup_state" != Z ] || break
            sleep 0.02
            cleanup_wait=$((cleanup_wait + 1))
        done
        cleanup_observed_start=$(sed 's/^.*) //' \
            "/proc/$runner_sigkill_cleanup_pid/stat" 2>/dev/null | \
            awk '{ print $20 }' || true)
        if [ "$cleanup_observed_start" = "$runner_sigkill_cleanup_start" ]; then
            kill -KILL "$runner_sigkill_cleanup_pid" 2>/dev/null || true
        fi
    fi
    runner_sigkill_cleanup_pid=''
    runner_sigkill_cleanup_start=''
}
cleanup_test_workspace() {
    cleanup_status=$?
    trap - EXIT HUP INT TERM
    cleanup_runner_sigkill_workload
    rm -rf -- "$work_directory"
    exit "$cleanup_status"
}
trap cleanup_test_workspace EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
campaign=$script_directory/run-fixed64-served-campaign.sh
summarizer=$script_directory/summarize-fixed64-served-campaign.py
failures=0
checks_run=0

report() {
    checks_run=$((checks_run + 1))
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

models_directory=$work_directory/models
mkdir -p "$models_directory/Qwen3.5-0.8B-GGUF" \
    "$models_directory/Qwen3.8-2B-Distill-GGUF" \
    "$models_directory/Qwen3.8-4B-Distill-GGUF"
printf 'fixture-qwen35-08b\n' \
    >"$models_directory/Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q8_0.gguf"
printf 'fixture-qwen38-2b\n' \
    >"$models_directory/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf"
printf 'fixture-qwen38-4b\n' \
    >"$models_directory/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf"

configuration_directory=$work_directory/source-configuration
mkdir "$configuration_directory"
cp -- "$script_directory/models.tsv" "$configuration_directory/models.tsv"
cp -- "$script_directory/throughput-targets.tsv" \
    "$configuration_directory/throughput-targets.tsv"
cp -- "$script_directory/quarantine.tsv" \
    "$configuration_directory/quarantine.tsv"
cp -- "$script_directory/validated-tuples.tsv" \
    "$configuration_directory/validated-tuples.tsv"
cp -- "$script_directory/ctx-checkpoints.tsv" \
    "$configuration_directory/ctx-checkpoints.tsv"

artifact_reader=$configuration_directory/model-artifact-identity.sh
cp -- "$script_directory/model-artifact-identity.sh" "$artifact_reader"
chmod 0755 "$artifact_reader"
artifact_ledger=$configuration_directory/model-artifacts.tsv
{
    printf '# model_id\tmodel_file\texpected_bytes\texpected_sha256\tsource_repository\tsource_revision\n'
    for artifact_record in \
        'qwen35-08b Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q8_0.gguf' \
        'qwen38-2b-distill Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf' \
        'qwen38-4b-distill Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf'; do
        artifact_id=${artifact_record%% *}
        artifact_file=${artifact_record#* }
        artifact_path=$models_directory/$artifact_file
        artifact_bytes=$(stat -c %s "$artifact_path")
        artifact_sha256=$(sha256sum "$artifact_path")
        artifact_sha256=${artifact_sha256%% *}
        printf '%s\t%s\t%s\t%s\tfixture/repository\t0123456789abcdef0123456789abcdef01234567\n' \
            "$artifact_id" "$artifact_file" "$artifact_bytes" "$artifact_sha256"
    done
} >"$artifact_ledger"

fake_server=$work_directory/llama-server
printf '#!/bin/sh\nexit 0\n' >"$fake_server"
chmod 0755 "$fake_server"

fake_runner=$work_directory/fake-served-runner.sh
cp -- "$script_directory/test-fixtures/fake-fixed64-served-runner.sh" \
    "$fake_runner"
chmod 0755 "$fake_runner"

fake_emergency_teardown=$work_directory/fake-emergency-teardown.sh
cp -- "$script_directory/test-fixtures/fake-fixed64-emergency-teardown.sh" \
    "$fake_emergency_teardown"
chmod 0755 "$fake_emergency_teardown"

fake_icd=$work_directory/radeon_icd.x86_64.json
printf '{}\n' >"$fake_icd"

failing_summarizer=$work_directory/failing-summarizer.py
cat >"$failing_summarizer" <<'PY'
#!/usr/bin/env python3
raise SystemExit(47)
PY
chmod 0755 "$failing_summarizer"

staged_verifier_summarizer=$work_directory/fake-staged-verifier.sh
cp -- "$script_directory/test-fixtures/fake-fixed64-staged-verifier.sh" \
    "$staged_verifier_summarizer"
chmod 0755 "$staged_verifier_summarizer"

state_directory=$work_directory/state
mkdir "$state_directory"
workload_lock=$state_directory/vulkan-workload.lock
campaign_lock=$state_directory/fixed64-served-campaign.lock

run_campaign() {
    run_output=$1
    shift
    env \
        QWEN_SERVED_CAMPAIGN_RUNNER="$fake_runner" \
        QWEN_SERVED_CAMPAIGN_SUMMARIZER="$summarizer" \
        QWEN_SERVED_CAMPAIGN_SERVER="$fake_server" \
        QWEN_SERVED_CAMPAIGN_TEARDOWN_SCRIPT="$fake_emergency_teardown" \
        QWEN_MODEL_ARTIFACT_SCRIPT="$artifact_reader" \
        QWEN_MODEL_ARTIFACTS="$artifact_ledger" \
        QWEN_MODEL_REGISTRY="$configuration_directory/models.tsv" \
        QWEN_THROUGHPUT_TARGETS="$configuration_directory/throughput-targets.tsv" \
        QWEN_QUARANTINE_REGISTRY="$configuration_directory/quarantine.tsv" \
        QWEN_VALIDATED_TUPLES="$configuration_directory/validated-tuples.tsv" \
        QWEN_CTX_CHECKPOINT_LEDGER="$configuration_directory/ctx-checkpoints.tsv" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_SERVED_CAMPAIGN_STATE_DIRECTORY="$state_directory" \
        QWEN_VULKAN_WORKLOAD_LOCK="$workload_lock" \
        QWEN_SERVED_CAMPAIGN_CONTROL_LOCK="$campaign_lock" \
        QWEN_SERVED_CAMPAIGN_RADV_ICD="$fake_icd" \
        QWEN_SERVED_CAMPAIGN_COOLDOWN_S=0 \
        QWEN_SERVED_CAMPAIGN_REQUIRE_CLEAN_SOURCE=0 \
        QWEN_TEST_FIXED64_HOST_SHORTNAME=HP14-DK1XXX \
        SSH_CONNECTION='192.0.2.10 53000 192.0.2.20 22' \
        "$@" "$campaign" "$run_output"
}

control_directory() {
    printf '%s.control\n' "$1"
}

write_control() {
    control_output=$1
    control_name=$2
    control_value=$3
    control_root=$(control_directory "$control_output")
    mkdir -p -- "$control_root"
    printf '%s\n' "$control_value" >"$control_root/$control_name"
}

run_refusal() {
    refusal_name=$1
    refusal_output=$2
    refusal_pattern=$3
    shift 3
    set +e
    run_campaign "$refusal_output" "$@" \
        >"$work_directory/$refusal_name.stdout" \
        2>"$work_directory/$refusal_name.stderr"
    refusal_status=$?
    set -e
    refusal_state=accepted
    [ "$refusal_status" -eq 2 ] || refusal_state="status-$refusal_status"
    [ ! -e "$refusal_output" ] && [ ! -L "$refusal_output" ] || \
        refusal_state='output-claimed'
    grep -F "$refusal_pattern" \
        "$work_directory/$refusal_name.stderr" >/dev/null || \
        refusal_state='reason-absent'
    report "$refusal_name" "$refusal_state"
}

invocation_count() {
    invocation_root=$(control_directory "$1")
    if [ -r "$invocation_root/invocations.tsv" ]; then
        wc -l <"$invocation_root/invocations.tsv"
    else
        printf '0\n'
    fi
}

process_is_running() {
    observed_process_pid=$1
    [ -r "/proc/$observed_process_pid/stat" ] || return 1
    observed_process_state=$(sed 's/^.*) //' "/proc/$observed_process_pid/stat" \
        2>/dev/null | awk '{ print $1 }')
    [ -n "$observed_process_state" ] || return 1
    [ "$observed_process_state" != Z ]
}

process_start_time_ticks() {
    observed_process_pid=$1
    observed_process_start=$(sed 's/^.*) //' "/proc/$observed_process_pid/stat" \
        2>/dev/null | awk '{ print $20 }')
    [ -n "$observed_process_start" ] || return 1
    printf '%s\n' "$observed_process_start"
}

reseal_campaign() {
    reseal_directory=$1
    reseal_manifest=$(mktemp "$work_directory/resealed-manifest.XXXXXX")
    (
        cd "$reseal_directory"
        find . -type f ! -name SHA256SUMS ! -name .SHA256SUMS.new -print0 | \
            LC_ALL=C sort -z | xargs -0 sha256sum
    ) >"$reseal_manifest"
    mv -- "$reseal_manifest" "$reseal_directory/SHA256SUMS"
}

report_resealed_rejection() {
    rejection_name=$1
    rejection_directory=$2
    rejection_pattern=$3
    reseal_campaign "$rejection_directory"
    if PYTHONDONTWRITEBYTECODE=1 "$summarizer" --verify-sealed \
        "$rejection_directory" \
        >"$work_directory/$rejection_name.stdout" \
        2>"$work_directory/$rejection_name.stderr"; then
        report "$rejection_name" rejected
    elif grep -F "$rejection_pattern" \
        "$work_directory/$rejection_name.stdout" >/dev/null; then
        report "$rejection_name" accepted
    else
        report "$rejection_name" wrong-reason
        sed -n '1,80p' "$work_directory/$rejection_name.stdout" >&2
        sed -n '1,80p' "$work_directory/$rejection_name.stderr" >&2
    fi
}

# Host and transport admission runs before the state directory, workload lease,
# or immutable evidence directory can be claimed. Caller labels do not replace
# either kernel-observed hostname evidence or the inherited SSH marker.
missing_ssh_output=$work_directory/missing-ssh-session
run_refusal missing_ssh_session_refused "$missing_ssh_output" \
    'fixed-64 campaign requires a structurally valid inherited SSH session' \
    env -u SSH_CONNECTION

wrong_host_output=$work_directory/wrong-host
run_refusal wrong_host_refused "$wrong_host_output" \
    'fixed-64 campaign requires measured host hp14-dk1xxx:' \
    env QWEN_TEST_FIXED64_HOST_SHORTNAME=edge-workstation

malformed_ssh_output=$work_directory/malformed-ssh-session
run_refusal malformed_ssh_session_refused "$malformed_ssh_output" \
    'fixed-64 campaign requires a structurally valid inherited SSH session' \
    env SSH_CONNECTION='not-an-ssh-connection'

local_label_output=$work_directory/local-label-attempt
run_refusal local_label_cannot_replace_host_evidence "$local_label_output" \
    'fixed-64 campaign requires measured host hp14-dk1xxx:' \
    env QWEN_EXECUTION_SURFACE=local QWEN_HOST_SHORTNAME=hp14-dk1xxx \
    QWEN_SSH_SESSION=present QWEN_TEST_FIXED64_HOST_SHORTNAME=edge-workstation

edge_label_output=$work_directory/edge-label-attempt
run_refusal edge_label_cannot_replace_ssh_evidence "$edge_label_output" \
    'fixed-64 campaign requires a structurally valid inherited SSH session' \
    env -u SSH_CONNECTION QWEN_EXECUTION_SURFACE=edge \
    QWEN_HOST_SHORTNAME=hp14-dk1xxx QWEN_SSH_SESSION=present

production_seam_output=$work_directory/production-hostname-seam
run_refusal production_runner_rejects_hostname_fixture "$production_seam_output" \
    'fixed-64 hostname fixture requires an explicit non-production runner' \
    env -u QWEN_SERVED_CAMPAIGN_RUNNER

# The campaign control lease and ordinary session lease share one exact state
# directory path. An override to another lock must fail before the campaign can
# claim its output directory.
mismatched_lock_output=$work_directory/mismatched-control-lock
mismatched_lock=$work_directory/other-fixed64-served-campaign.lock
run_refusal mismatched_campaign_control_lock_refused "$mismatched_lock_output" \
    'campaign control lease differs from the session-owned path:' \
    env QWEN_SERVED_CAMPAIGN_CONTROL_LOCK="$mismatched_lock"

# The campaign control lock opener rejects a final symlink through O_NOFOLLOW.
# The target comparison proves the refusal preserves pre-existing bytes.
campaign_link_target=$work_directory/campaign-link-target
campaign_link_expected=$work_directory/campaign-link-expected
campaign_link_output=$work_directory/campaign-link-output
printf 'retained campaign lock target bytes\n' >"$campaign_link_target"
cp -- "$campaign_link_target" "$campaign_link_expected"
ln -s "$campaign_link_target" "$campaign_lock"
run_refusal campaign_final_lock_symlink_refused "$campaign_link_output" \
    'verified_lock_descriptor=rejected'
campaign_link_state=accepted
cmp -s "$campaign_link_expected" "$campaign_link_target" || \
    campaign_link_state=target-bytes-changed
[ -L "$campaign_lock" ] || campaign_link_state=link-replaced
report campaign_final_lock_symlink_preserves_target_bytes "$campaign_link_state"
rm -- "$campaign_lock"

# State-directory validation refuses a final symlink before it can create a
# lease, proof, or output directory.
state_final_target=$work_directory/state-final-target
state_final_link=$work_directory/state-final-link
mkdir "$state_final_target"
ln -s "$state_final_target" "$state_final_link"
state_final_output=$work_directory/symlinked-final-state
run_refusal symlinked_final_state_directory_refused "$state_final_output" \
    'state directory contains a symbolic link:' \
    env QWEN_SERVED_CAMPAIGN_STATE_DIRECTORY="$state_final_link" \
    QWEN_VULKAN_WORKLOAD_LOCK="$state_final_link/vulkan-workload.lock" \
    QWEN_SERVED_CAMPAIGN_CONTROL_LOCK="$state_final_link/fixed64-served-campaign.lock"
state_final_mutation_state=accepted
[ ! -e "$state_final_target/vulkan-workload.lock" ] || \
    state_final_mutation_state='workload-lease-created'
report symlinked_final_state_directory_untouched "$state_final_mutation_state"

# The same rule applies when an existing intermediate component is a symlink;
# an absent final state directory under its target stays absent after refusal.
state_intermediate_target=$work_directory/state-intermediate-target
state_intermediate_link=$work_directory/state-intermediate-link
state_intermediate_directory=$state_intermediate_link/new-state
mkdir "$state_intermediate_target"
ln -s "$state_intermediate_target" "$state_intermediate_link"
state_intermediate_output=$work_directory/symlinked-intermediate-state
run_refusal symlinked_intermediate_state_directory_refused \
    "$state_intermediate_output" 'state directory contains a symbolic link:' \
    env QWEN_SERVED_CAMPAIGN_STATE_DIRECTORY="$state_intermediate_directory" \
    QWEN_VULKAN_WORKLOAD_LOCK="$state_intermediate_directory/vulkan-workload.lock" \
    QWEN_SERVED_CAMPAIGN_CONTROL_LOCK="$state_intermediate_directory/fixed64-served-campaign.lock"
state_intermediate_mutation_state=accepted
[ ! -e "$state_intermediate_target/new-state" ] || \
    state_intermediate_mutation_state='final-state-directory-created'
report symlinked_intermediate_state_directory_untouched \
    "$state_intermediate_mutation_state"

success_output=$work_directory/success
set +e
run_campaign "$success_output" \
    >"$work_directory/success.stdout" 2>"$work_directory/success.stderr"
success_status=$?
set -e
success_state=accepted
[ "$success_status" -eq 0 ] || success_state="status-$success_status"
if [ "$success_status" -ne 0 ]; then
    printf 'balanced campaign failed: status=%s\n' "$success_status" >&2
    sed -n '1,200p' "$work_directory/success.stderr" >&2
    if [ -r "$success_output/summary-execution.txt" ]; then
        sed -n '1,200p' "$success_output/summary-execution.txt" >&2
    fi
    if [ -r "$success_output/models-resolved.tsv" ]; then
        sed -n '1,2p' "$success_output/models-resolved.tsv" >&2
    fi
    if [ -r "$success_output/campaign-inputs.tsv" ]; then
        sed -n '1,80p' "$success_output/campaign-inputs.tsv" >&2
    fi
    if [ -r "$success_output/source-status-before.txt" ]; then
        sed -n '1,80p' "$success_output/source-status-before.txt" >&2
    fi
    exit 1
fi
if [ ! -f "$success_output/schedule.tsv" ]; then
    printf 'balanced campaign stopped before schedule publication: status=%s\n' \
        "$success_status" >&2
    sed -n '1,200p' "$work_directory/success.stderr" >&2
    exit 1
fi
expected_order='qwen35-08b
qwen38-2b-distill
qwen38-4b-distill
qwen35-08b
qwen38-2b-distill
qwen38-4b-distill
qwen38-4b-distill
qwen38-2b-distill
qwen35-08b
qwen38-4b-distill
qwen38-2b-distill
qwen35-08b'
actual_order=$(awk -F '\t' 'NR > 1 { print $4 }' "$success_output/schedule.tsv")
[ "$actual_order" = "$expected_order" ] || success_state='schedule-order'
[ "$(invocation_count "$success_output")" -eq 12 ] || \
    success_state='invocation-count'
awk -F '\t' '
    NR == 1 { next }
    { count[$4]++; position[$4] += $1 }
    END {
        for (model in count) {
            if (count[model] != 4 || position[model] / count[model] != 6.5) exit 1
        }
    }
' "$success_output/schedule.tsv" || success_state='position-balance'
[ -f "$success_output/SHA256SUMS" ] || success_state='manifest-absent'
(
    cd "$success_output"
    sha256sum -c SHA256SUMS >/dev/null
) || success_state='manifest-invalid'
find "$success_output" -name '*.new' -o -name '.SHA256SUMS.new' | \
    grep . >/dev/null && success_state='temporary-artifact' || true
awk -F '\t' '
    NR == 1 {
        for (field_index = 1; field_index <= NF; field_index++) {
            if ($field_index == "decode_tokens") decode_column = field_index
            if ($field_index == "target_state") target_column = field_index
            if ($field_index == "ctx_checkpoints") checkpoints_column = field_index
            if ($field_index == "checkpoint_min_step") {
                checkpoint_step_column = field_index
            }
        }
        if (!decode_column || !target_column || !checkpoints_column ||
            !checkpoint_step_column) exit 1
        next
    }
    $decode_column != 64 || $target_column != "met" ||
        $checkpoints_column != 2 || $checkpoint_step_column != 8192 { exit 1 }
' "$success_output/summary.tsv" || success_state='summary-values'
if ! awk -F '\t' 'NR > 1 && ($4 != 4 || $5 != 4 || $11 != "met") { exit 1 }' \
    "$success_output/model-summary.tsv"; then
    success_state='model-summary-values'
    cat "$success_output/model-summary.tsv" >&2
fi
report balanced_complete_campaign "$success_state"

hp14_contract_state=accepted
if ! awk -F '\t' '
    $1 == "execution_surface" && $2 == "hp14-ssh" { surface = 1 }
    $1 == "host_shortname" && $2 == "hp14-dk1xxx" { host = 1 }
    $1 == "ssh_session" && $2 == "present" { ssh = 1 }
    $1 == "server_nice" && $2 == "19" { priority = 1 }
    $1 == "server_io_class" && $2 == "idle" { io = 1 }
    END { exit !(surface && host && ssh && priority && io) }
' "$success_output/campaign-inputs.tsv"; then
    hp14_contract_state='campaign-inputs'
fi
if ! python3 - "$success_output" <<'PY'
import json
import sys
from pathlib import Path

arm_paths = sorted((Path(sys.argv[1]) / "arms").glob("*/server-process.json"))
if len(arm_paths) != 12:
    raise SystemExit(1)
expected = {
    "schema": "served-decode-process-v3",
    "execution_surface": "hp14-ssh",
    "host_shortname": "hp14-dk1xxx",
    "ssh_session": "present",
    "nice": 19,
    "io_class": "idle",
}
for arm_path in arm_paths:
    document = json.loads(arm_path.read_text(encoding="utf-8"))
    if any(document.get(key) != value for key, value in expected.items()):
        raise SystemExit(1)
PY
then
    hp14_contract_state=arm-process-evidence
fi
report binds_hp14_ssh_priority_contract "$hp14_contract_state"

# Re-sealing cannot convert a changed execution identity or scheduling policy
# into valid evidence. The semantic verifier binds every arm record to the
# normalized campaign inputs and the hp14-only nice-19/idle-I/O contract.
run_server_process_contract_mutation() {
    mutation_name=$1
    mutation_field=$2
    mutation_value=$3
    rejection_pattern=$4
    mutation_directory=$work_directory/resealed-$mutation_name
    cp -a -- "$success_output" "$mutation_directory"
    python3 - "$mutation_directory/arms/01-forward-qwen35-08b/server-process.json" \
        "$mutation_field" "$mutation_value" <<'PY'
import json
import sys
from pathlib import Path

process_path = Path(sys.argv[1])
field = sys.argv[2]
value_text = sys.argv[3]
document = json.loads(process_path.read_text(encoding="utf-8"))
if value_text == "increment":
    document[field] += 1
elif field in {"nice", "executable_device", "executable_inode", "executable_bytes"}:
    document[field] = int(value_text)
else:
    document[field] = value_text
process_path.write_text(
    json.dumps(document, separators=(",", ":")) + "\n", encoding="utf-8"
)
PY
    report_resealed_rejection "rejects_$mutation_name" \
        "$mutation_directory" "$rejection_pattern"
}

run_server_process_contract_mutation server_process_local_surface \
    execution_surface local 'execution-surface contract differs'
run_server_process_contract_mutation server_process_wrong_host \
    host_shortname edge-workstation 'execution-surface contract differs'
run_server_process_contract_mutation server_process_missing_ssh \
    ssh_session absent 'execution-surface contract differs'
run_server_process_contract_mutation server_process_nice_zero \
    nice 0 'nice value differs from 19'
run_server_process_contract_mutation server_process_best_effort_io \
    io_class best-effort 'io_class differs from idle'
run_server_process_contract_mutation server_process_executable_inode \
    executable_inode increment 'executable identity differs from runtime-inputs'

run_runtime_input_contract_mutation() {
    mutation_name=$1
    mutation_section=$2
    mutation_field=$3
    mutation_value=$4
    rejection_pattern=$5
    mutation_directory=$work_directory/resealed-$mutation_name
    cp -a -- "$success_output" "$mutation_directory"
    python3 - \
        "$mutation_directory/arms/01-forward-qwen35-08b/runtime-inputs.json" \
        "$mutation_section" "$mutation_field" "$mutation_value" <<'PY'
import json
import sys
from pathlib import Path

runtime_inputs_path = Path(sys.argv[1])
section = sys.argv[2]
field = sys.argv[3]
value = sys.argv[4]
document = json.loads(runtime_inputs_path.read_text(encoding="utf-8"))
document[section][field] = (
    document[section][field] + 1 if value == "increment" else value
)
runtime_inputs_path.write_text(
    json.dumps(document, separators=(",", ":")) + "\n", encoding="utf-8"
)
PY
    report_resealed_rejection "rejects_$mutation_name" \
        "$mutation_directory" "$rejection_pattern"
}

run_runtime_input_contract_mutation runtime_model_path model path \
    /tmp/other-model.gguf 'model identity differs from models-resolved.tsv'
run_runtime_input_contract_mutation runtime_model_descriptor model descriptor_path \
    /proc/04321/fd/7 'descriptor_path must be /proc/<positive-pid>/fd/7'
run_runtime_input_contract_mutation runtime_executable_descriptor executable \
    descriptor_path /proc/4322/fd/6 \
    'model and executable descriptors use different PIDs'
run_runtime_input_contract_mutation runtime_executable_bytes executable bytes \
    increment 'executable bytes differ from identity-before'

run_campaign_input_contract_mutation() {
    mutation_name=$1
    mutation_key=$2
    mutation_value=$3
    rejection_pattern=${4:-fixed v2 policy differs}
    mutation_directory=$work_directory/resealed-$mutation_name
    cp -a -- "$success_output" "$mutation_directory"
    python3 - "$mutation_directory/campaign-inputs.tsv" \
        "$mutation_key" "$mutation_value" <<'PY'
import sys
from pathlib import Path

input_path = Path(sys.argv[1])
target_key = sys.argv[2]
replacement = sys.argv[3]
rows = [line.split("\t", 1) for line in input_path.read_text(encoding="utf-8").splitlines()]
matches = 0
for row in rows:
    if row[0] == target_key:
        row[1] = replacement
        matches += 1
if matches != 1:
    raise SystemExit(f"campaign input mutation matched {matches} rows")
input_path.write_text(
    "".join(f"{key}\t{value}\n" for key, value in rows), encoding="utf-8"
)
PY
    report_resealed_rejection "rejects_$mutation_name" \
        "$mutation_directory" "$rejection_pattern"
}

run_campaign_input_contract_mutation campaign_local_surface \
    execution_surface local
run_campaign_input_contract_mutation campaign_wrong_host \
    host_shortname edge-workstation
run_campaign_input_contract_mutation campaign_missing_ssh \
    ssh_session absent
run_campaign_input_contract_mutation campaign_wrong_control_lock \
    campaign_lock /tmp/other-fixed64-served-campaign.lock \
    'campaign_lock differs from the state directory'

# The campaign summarizer treats prompt timings as measured evidence rather
# than decorative server metadata. Each mutation re-seals the bytes so the
# semantic verifier, rather than the outer hash check, owns the refusal.
run_prompt_timing_mutation_rejection() {
    mutation_name=$1
    mutation_target=$2
    mutation_value=$3
    rejection_pattern=$4
    mutation_directory=$work_directory/resealed-$mutation_name
    cp -a -- "$success_output" "$mutation_directory"
    python3 - "$mutation_directory" "$mutation_target" "$mutation_value" <<'PY'
import json
import sys
from pathlib import Path

campaign_directory = Path(sys.argv[1])
mutation_target = sys.argv[2]
mutation_value = sys.argv[3]
arm_directory = campaign_directory / "arms" / "01-forward-qwen35-08b"
if mutation_target.startswith("response-"):
    document_path = arm_directory / "response.json"
    document = json.loads(document_path.read_text(encoding="utf-8"))
    field = {
        "response-prompt-count": "prompt_n",
        "response-prompt-ms": "prompt_ms",
        "response-prompt-rate": "prompt_per_second",
    }[mutation_target]
    fields = document["timings"]
else:
    document_path = arm_directory / "summary.json"
    document = json.loads(document_path.read_text(encoding="utf-8"))
    field = {
        "child-prompt-count": "prompt_tokens",
        "child-prompt-ms": "prefill_ms",
        "child-prompt-rate": "prefill_tok_per_second",
    }[mutation_target]
    fields = document

if mutation_value == "missing":
    fields.pop(field)
elif mutation_value == "null":
    fields[field] = None
elif mutation_value == "boolean":
    fields[field] = True
elif mutation_value == "zero":
    fields[field] = 0
elif mutation_value == "negative":
    fields[field] = -1
elif mutation_value == "floating":
    fields[field] = 12.5
elif mutation_value == "nan":
    fields[field] = float("nan")
elif mutation_value == "infinity":
    fields[field] = float("inf")
elif mutation_value == "string":
    fields[field] = "12"
elif mutation_value == "mismatch":
    fields[field] = fields[field] + 1
elif mutation_value == "divergent":
    fields[field] = 99
else:
    raise SystemExit(f"unknown mutation value: {mutation_value}")
document_path.write_text(
    json.dumps(document, separators=(",", ":")) + "\n", encoding="utf-8"
)
PY
    report_resealed_rejection "rejects_$mutation_name" \
        "$mutation_directory" "$rejection_pattern"
}

for prompt_count_mutation in missing null boolean floating string; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_count_$prompt_count_mutation" \
        response-prompt-count "$prompt_count_mutation" \
        'field prompt_n must be an integer'
done
for prompt_count_mutation in zero negative; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_count_$prompt_count_mutation" \
        response-prompt-count "$prompt_count_mutation" \
        'field prompt_n must be positive'
done
for prompt_count_mutation in nan infinity; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_count_$prompt_count_mutation" \
        response-prompt-count "$prompt_count_mutation" \
        'not readable JSON: nonfinite JSON constant'
done
for prompt_ms_mutation in missing null boolean string; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_ms_$prompt_ms_mutation" \
        response-prompt-ms "$prompt_ms_mutation" \
        'field prompt_ms must be numeric'
done
for prompt_ms_mutation in zero negative; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_ms_$prompt_ms_mutation" \
        response-prompt-ms "$prompt_ms_mutation" \
        'field prompt_ms must be finite and positive'
done
for prompt_ms_mutation in nan infinity; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_ms_$prompt_ms_mutation" \
        response-prompt-ms "$prompt_ms_mutation" \
        'not readable JSON: nonfinite JSON constant'
done
for prompt_rate_mutation in missing null boolean string; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_rate_$prompt_rate_mutation" \
        response-prompt-rate "$prompt_rate_mutation" \
        'field prompt_per_second must be numeric'
done
for prompt_rate_mutation in zero negative; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_rate_$prompt_rate_mutation" \
        response-prompt-rate "$prompt_rate_mutation" \
        'field prompt_per_second must be finite and positive'
done
for prompt_rate_mutation in nan infinity; do
    run_prompt_timing_mutation_rejection \
        "response_prompt_rate_$prompt_rate_mutation" \
        response-prompt-rate "$prompt_rate_mutation" \
        'not readable JSON: nonfinite JSON constant'
done
run_prompt_timing_mutation_rejection response_prompt_rate_divergent \
    response-prompt-rate divergent 'prompt rate differs from elapsed time'
run_prompt_timing_mutation_rejection child_prompt_count_mismatch \
    child-prompt-count mismatch 'prompt count differs from the response'
run_prompt_timing_mutation_rejection child_prompt_ms_mismatch \
    child-prompt-ms mismatch 'prompt elapsed time differs from the response'
run_prompt_timing_mutation_rejection child_prompt_rate_mismatch \
    child-prompt-rate mismatch 'prompt rate differs from the response'

child_summary_substitution=$work_directory/resealed-child-summary-substitution
cp -a -- "$success_output" "$child_summary_substitution"
python3 - "$child_summary_substitution/arms/01-forward-qwen35-08b/summary.json" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
summary = json.loads(summary_path.read_text(encoding="utf-8"))
summary["undeclared_prompt_evidence"] = 1
summary_path.write_text(
    json.dumps(summary, separators=(",", ":")) + "\n", encoding="utf-8"
)
PY
report_resealed_rejection rejects_child_summary_key_substitution \
    "$child_summary_substitution" 'summary.json field set differs'

# Ambient launcher state cannot alter the fixed campaign tuple or admit debug
# submission controls into any served-decode arm.
ambient_output=$work_directory/ambient-environment
set +e
run_campaign "$ambient_output" \
    QWEN_ROUTER=ambient-router \
    QWEN_SPEC_TYPE=ambient-speculation \
    QWEN_MMPROJ=/ambient/mmproj.gguf \
    QWEN_SERVER_PORT=65535 \
    QWEN_BIND_HOST=0.0.0.0 \
    QWEN_READY_ATTEMPTS=1 \
    GGML_VK_MAX_NODES_PER_SUBMIT=1 \
    GGML_VK_SERIALIZE_SUBMISSIONS=1 \
    GGML_VK_SUBMIT_TRACE=/ambient/submit-trace.tsv \
    GGML_VK_DUTY_CYCLE_PERCENT=1 \
    >"$work_directory/ambient.stdout" 2>"$work_directory/ambient.stderr"
ambient_status=$?
set -e
ambient_state=accepted
[ "$ambient_status" -eq 0 ] || ambient_state="status-$ambient_status"
expected_environment=$work_directory/expected-arm-environment.txt
printf '%s\n' \
    'QWEN_ROUTER=0' \
    'QWEN_SPEC_TYPE=off' \
    'QWEN_MMPROJ=unset' \
    'QWEN_SERVER_PORT=8080' \
    'QWEN_BIND_HOST=127.0.0.1' \
    'QWEN_READY_ATTEMPTS=unset' \
    'GGML_VK_MAX_NODES_PER_SUBMIT=unset' \
    'GGML_VK_SERIALIZE_SUBMISSIONS=unset' \
    'GGML_VK_SUBMIT_TRACE=unset' \
    'GGML_VK_DUTY_CYCLE_PERCENT=unset' \
    >"$expected_environment"
ambient_environment_count=$(find "$ambient_output/arms" -type f \
    -name environment.txt -print | wc -l)
[ "$ambient_environment_count" -eq 12 ] || ambient_state='environment-count'
if ! find "$ambient_output/arms" -type f -name environment.txt -print | \
    LC_ALL=C sort | while IFS= read -r environment_path; do
        cmp -s "$expected_environment" "$environment_path" || exit 1
    done; then
    ambient_state='ambient-variable-admitted'
fi
report sanitizes_ambient_qwen_and_ggml_variables "$ambient_state"

# Publisher-declared bytes and digest remain authoritative even when a local
# file exists at the registered model pathname.
publisher_mismatch_ledger=$configuration_directory/model-artifacts-mismatch.tsv
awk -F '\t' 'BEGIN { OFS = FS }
    /^#/ { print; next }
    !changed { $4 = "0000000000000000000000000000000000000000000000000000000000000000"; changed = 1 }
    { print }
' "$artifact_ledger" >"$publisher_mismatch_ledger"
publisher_mismatch_output=$work_directory/publisher-identity-mismatch
set +e
run_campaign "$publisher_mismatch_output" \
    QWEN_MODEL_ARTIFACTS="$publisher_mismatch_ledger" \
    >"$work_directory/publisher-mismatch.stdout" \
    2>"$work_directory/publisher-mismatch.stderr"
publisher_mismatch_status=$?
set -e
publisher_mismatch_state=accepted
[ "$publisher_mismatch_status" -eq 2 ] || \
    publisher_mismatch_state="status-$publisher_mismatch_status"
[ "$(invocation_count "$publisher_mismatch_output")" -eq 0 ] || \
    publisher_mismatch_state='runner-entered'
[ ! -e "$publisher_mismatch_output/SHA256SUMS" ] || \
    publisher_mismatch_state='manifest-published'
grep -F 'model artifact differs from publisher identity: qwen35-08b' \
    "$work_directory/publisher-mismatch.stderr" >/dev/null || \
    publisher_mismatch_state='refusal-absent'
report rejects_publisher_model_identity_mismatch "$publisher_mismatch_state"

# A digest-valid replacement manifest cannot legitimize a summary row whose
# numerical claim differs from full recomputation over the retained arm data.
resealed_summary_tamper=$work_directory/resealed-summary-tamper
cp -a -- "$success_output" "$resealed_summary_tamper"
awk -F '\t' 'BEGIN { OFS = FS }
    NR == 2 { $17 = "22" }
    { print }
' "$resealed_summary_tamper/summary.tsv" \
    >"$work_directory/summary.tsv.tampered"
mv -- "$work_directory/summary.tsv.tampered" \
    "$resealed_summary_tamper/summary.tsv"
reseal_campaign "$resealed_summary_tamper"
if PYTHONDONTWRITEBYTECODE=1 "$summarizer" --verify-sealed \
    "$resealed_summary_tamper" \
    >"$work_directory/resealed-summary.stdout" \
    2>"$work_directory/resealed-summary.stderr"; then
    report rejects_resealed_semantic_summary_tamper rejected
elif grep -F 'sealed summary differs from full recomputation' \
    "$work_directory/resealed-summary.stdout" >/dev/null; then
    report rejects_resealed_semantic_summary_tamper accepted
else
    report rejects_resealed_semantic_summary_tamper wrong-reason
    sed -n '1,80p' "$work_directory/resealed-summary.stdout" >&2
fi

# The model-level reduction receives the same semantic recomputation gate after
# the arm-level table remains byte-identical and manifest-valid.
resealed_model_summary_tamper=$work_directory/resealed-model-summary-tamper
cp -a -- "$success_output" "$resealed_model_summary_tamper"
awk -F '\t' 'BEGIN { OFS = FS }
    NR == 2 { $6 = "999" }
    { print }
' "$resealed_model_summary_tamper/model-summary.tsv" \
    >"$work_directory/model-summary.tsv.tampered"
mv -- "$work_directory/model-summary.tsv.tampered" \
    "$resealed_model_summary_tamper/model-summary.tsv"
reseal_campaign "$resealed_model_summary_tamper"
if PYTHONDONTWRITEBYTECODE=1 "$summarizer" --verify-sealed \
    "$resealed_model_summary_tamper" \
    >"$work_directory/resealed-model-summary.stdout" \
    2>"$work_directory/resealed-model-summary.stderr"; then
    report rejects_resealed_semantic_model_summary_tamper rejected
elif grep -F 'sealed model summary differs from full recomputation' \
    "$work_directory/resealed-model-summary.stdout" >/dev/null; then
    report rejects_resealed_semantic_model_summary_tamper accepted
else
    report rejects_resealed_semantic_model_summary_tamper wrong-reason
    sed -n '1,80p' "$work_directory/resealed-model-summary.stdout" >&2
fi

sealed_tamper=$work_directory/sealed-tamper
cp -a -- "$success_output" "$sealed_tamper"
printf 'tampered\n' >>"$sealed_tamper/arms/01-forward-qwen35-08b/response.json"
if PYTHONDONTWRITEBYTECODE=1 "$summarizer" --verify-sealed "$sealed_tamper" \
    >"$work_directory/sealed-tamper.stdout" \
    2>"$work_directory/sealed-tamper.stderr"; then
    report sealed_manifest_detects_tamper rejected
else
    report sealed_manifest_detects_tamper accepted
fi

# llama.cpp accepts short aliases, normalizes underscores to hyphens, and
# applies repeated arguments in order. The sealed verifier therefore rejects
# an argv that retains the expected long option but appends effective overrides.
argv_override=$work_directory/resealed-argv-override
cp -a -- "$success_output" "$argv_override"
python3 - "$argv_override/arms/01-forward-qwen35-08b/server-process.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["argv"].extend(["-dev", "none", "--ctx_size", "1", "-c", "1"])
path.write_text(json.dumps(document, separators=(",", ":")) + "\n", encoding="utf-8")
PY
report_resealed_rejection rejects_effective_argv_alias_override \
    "$argv_override" 'server-process argv differs from the canonical launch'

# A self-declared accepted state cannot override contradictory observed bytes,
# and the reconciliation denominator cannot shrink after the campaign seals.
identity_contradiction=$work_directory/resealed-identity-contradiction
cp -a -- "$success_output" "$identity_contradiction"
awk -F '\t' 'BEGIN { OFS = FS }
    NR == 2 { $6 = "0000000000000000000000000000000000000000000000000000000000000000" }
    { print }
' "$identity_contradiction/identity-check.tsv" \
    >"$work_directory/identity-check.contradictory.tsv"
mv -- "$work_directory/identity-check.contradictory.tsv" \
    "$identity_contradiction/identity-check.tsv"
report_resealed_rejection rejects_identity_check_contradiction \
    "$identity_contradiction" 'identity-check.tsv differs from identity-before.tsv'

identity_omission=$work_directory/resealed-identity-omission
cp -a -- "$success_output" "$identity_omission"
sed '$d' "$identity_omission/identity-check.tsv" \
    >"$work_directory/identity-check.omitted.tsv"
mv -- "$work_directory/identity-check.omitted.tsv" \
    "$identity_omission/identity-check.tsv"
report_resealed_rejection rejects_identity_check_omission \
    "$identity_omission" 'identity-check.tsv differs from identity-before.tsv'

# The v2 input schema is closed: both a substituted version and an undeclared
# key invalidate a newly hashed bundle.
schema_drift=$work_directory/resealed-campaign-schema-drift
cp -a -- "$success_output" "$schema_drift"
sed 's/^schema\tfixed64-served-campaign-v2$/schema\tfixed64-served-campaign-v999/' \
    "$schema_drift/campaign-inputs.tsv" >"$work_directory/campaign-inputs.drift.tsv"
printf 'undeclared_key\tundeclared-value\n' \
    >>"$work_directory/campaign-inputs.drift.tsv"
mv -- "$work_directory/campaign-inputs.drift.tsv" \
    "$schema_drift/campaign-inputs.tsv"
report_resealed_rejection rejects_campaign_input_schema_drift \
    "$schema_drift" 'campaign-inputs.tsv keys differ'

# The ICD pathname participates in the byte-identity reconciliation rather
# than acting as descriptive metadata that can be replaced and re-sealed.
icd_drift=$work_directory/resealed-radv-icd-drift
cp -a -- "$success_output" "$icd_drift"
awk -F '\t' 'BEGIN { OFS = FS }
    $1 == "radv_icd" { $2 = "/tmp/replacement-radv-icd.json" }
    { print }
' "$icd_drift/campaign-inputs.tsv" >"$work_directory/campaign-inputs.icd.tsv"
mv -- "$work_directory/campaign-inputs.icd.tsv" "$icd_drift/campaign-inputs.tsv"
report_resealed_rejection rejects_radv_icd_identity_drift \
    "$icd_drift" 'radv_icd differs from identity-before.tsv'

# Existing output paths remain byte-identical and execute no additional arm.
success_manifest_before=$(sha256sum "$success_output/SHA256SUMS" | awk '{ print $1 }')
success_invocations_before=$(invocation_count "$success_output")
set +e
run_campaign "$success_output" \
    >"$work_directory/reuse.stdout" 2>"$work_directory/reuse.stderr"
reuse_status=$?
set -e
reuse_state=accepted
[ "$reuse_status" -eq 2 ] || reuse_state="status-$reuse_status"
[ "$success_manifest_before" = \
    "$(sha256sum "$success_output/SHA256SUMS" | awk '{ print $1 }')" ] || \
    reuse_state='manifest-changed'
[ "$success_invocations_before" -eq "$(invocation_count "$success_output")" ] || \
    reuse_state='runner-reentered'
grep -F 'output path must be absent for one immutable campaign' \
    "$work_directory/reuse.stderr" >/dev/null || reuse_state='refusal-text'
report immutable_output_refusal "$reuse_state"

# One child failure stops the sequence and retains the failed arm diagnostics.
failure_output=$work_directory/runner-failure
write_control "$failure_output" fail-slot 05
set +e
run_campaign "$failure_output" >"$work_directory/failure.stdout" \
    2>"$work_directory/failure.stderr"
failure_status=$?
set -e
failure_state=accepted
[ "$failure_status" -eq 1 ] || failure_state="status-$failure_status"
[ "$(invocation_count "$failure_output")" -eq 5 ] || \
    failure_state='not-fail-fast'
[ -s "$failure_output/arms/05-forward-qwen38-2b-distill/campaign-runner.stderr" ] || \
    failure_state='diagnostic-absent'
[ ! -e "$failure_output/SHA256SUMS" ] || failure_state='failure-manifest'
awk -F '\t' 'NR == 2 && $1 == "failed" && $4 == 1 { found = 1 }
    END { exit found ? 0 : 1 }
' "$failure_output/terminal-state.tsv" || failure_state='terminal-state'
report fail_fast_retains_diagnostics "$failure_state"

# Teardown failure is a terminal child failure even after a valid response.
teardown_output=$work_directory/teardown-failure
write_control "$teardown_output" teardown-fail-slot 03
set +e
run_campaign "$teardown_output" \
    >"$work_directory/teardown.stdout" 2>"$work_directory/teardown.stderr"
teardown_status=$?
set -e
teardown_state=accepted
[ "$teardown_status" -eq 1 ] || teardown_state="status-$teardown_status"
[ "$(invocation_count "$teardown_output")" -eq 3 ] || \
    teardown_state='later-arm-started'
grep -F 'fake teardown failure at slot 03' \
    "$teardown_output/arms/03-forward-qwen38-4b-distill/campaign-runner.stderr" \
    >/dev/null || teardown_state='teardown-diagnostic-absent'
[ ! -e "$teardown_output/SHA256SUMS" ] || teardown_state='failure-manifest'
report teardown_failure_is_terminal "$teardown_state"
if [ "$teardown_state" != accepted ]; then
    printf 'teardown_status=%s invocations=%s\n' "$teardown_status" \
        "$(invocation_count "$teardown_output")" >&2
    find "$teardown_output" -maxdepth 3 -type f -print 2>/dev/null | \
        LC_ALL=C sort >&2 || true
    sed -n '1,120p' "$work_directory/teardown.stderr" >&2
fi

# A nominally successful child cannot move a 63-token response into the corpus.
short_output=$work_directory/short-response
write_control "$short_output" short-slot 05
set +e
run_campaign "$short_output" >"$work_directory/short.stdout" \
    2>"$work_directory/short.stderr"
short_status=$?
set -e
short_state=accepted
[ "$short_status" -eq 1 ] || short_state="status-$short_status"
[ "$(invocation_count "$short_output")" -eq 12 ] || short_state='arm-count'
[ ! -e "$short_output/summary.tsv" ] || short_state='invalid-summary-published'
[ ! -e "$short_output/SHA256SUMS" ] || short_state='invalid-manifest-published'
find "$short_output" -name '*.new' | grep . >/dev/null && \
    short_state='summary-temporary-left' || true
report rejects_non64_response "$short_state"

# Every retained telemetry and hazard log participates in the arm denominator;
# a successful child exit cannot substitute for one absent required artifact.
missing_log_output=$work_directory/missing-required-log
write_control "$missing_log_output" missing-log-slot 05
set +e
run_campaign "$missing_log_output" \
    >"$work_directory/missing-log.stdout" 2>"$work_directory/missing-log.stderr"
missing_log_status=$?
set -e
missing_log_state=accepted
[ "$missing_log_status" -eq 1 ] || \
    missing_log_state="status-$missing_log_status"
[ "$(invocation_count "$missing_log_output")" -eq 12 ] || \
    missing_log_state='arm-count'
[ ! -e "$missing_log_output/summary.tsv" ] || \
    missing_log_state='summary-published'
[ ! -e "$missing_log_output/SHA256SUMS" ] || \
    missing_log_state='manifest-published'
grep -F 'required arm artifact is absent or linked:' \
    "$missing_log_output/summary-execution.txt" >/dev/null || \
    missing_log_state='reason-absent'
grep -F '/arms/05-forward-qwen38-2b-distill/kernel-hazards.log' \
    "$missing_log_output/summary-execution.txt" >/dev/null || \
    missing_log_state='artifact-path-absent'
report rejects_missing_required_arm_log "$missing_log_state"

# The reported server rate must agree with the fixed-64 post-first-token elapsed
# time. The target decision uses the recomputed rate rather than trusted JSON.
divergent_rate_output=$work_directory/divergent-reported-rate
write_control "$divergent_rate_output" divergent-rate-slot 06
set +e
run_campaign "$divergent_rate_output" \
    >"$work_directory/divergent-rate.stdout" \
    2>"$work_directory/divergent-rate.stderr"
divergent_rate_status=$?
set -e
divergent_rate_state=accepted
[ "$divergent_rate_status" -eq 1 ] || \
    divergent_rate_state="status-$divergent_rate_status"
[ "$(invocation_count "$divergent_rate_output")" -eq 12 ] || \
    divergent_rate_state='arm-count'
[ ! -e "$divergent_rate_output/summary.tsv" ] || \
    divergent_rate_state='summary-published'
[ ! -e "$divergent_rate_output/SHA256SUMS" ] || \
    divergent_rate_state='manifest-published'
grep -F 'rate differs from post-first elapsed time:' \
    "$divergent_rate_output/summary-execution.txt" >/dev/null || \
    divergent_rate_state='reason-absent'
grep -F '99 versus 5.25' \
    "$divergent_rate_output/summary-execution.txt" >/dev/null || \
    divergent_rate_state='rate-evidence-absent'
report rejects_reported_recomputed_rate_divergence "$divergent_rate_state"

# A tracked helper reached transitively through qwen-launch.sh remains part of
# the measured source boundary even though the campaign executes its archived
# snapshot. A local shared-object clone isolates the mutation from this
# worktree while preserving a real Git index, HEAD, and tracked-status surface.
transitive_repository=$work_directory/transitive-repository
git clone --quiet --shared "$repository_root" "$transitive_repository"
transitive_campaign=$transitive_repository/remote/run-fixed64-served-campaign.sh
cp -- "$campaign" "$transitive_campaign"
cp -- "$script_directory/verify-external-vulkan-lease.py" \
    "$transitive_repository/remote/verify-external-vulkan-lease.py"
cp -- "$script_directory/signal-process-group.py" \
    "$transitive_repository/remote/signal-process-group.py"
cp -- "$script_directory/open-verified-lock-descriptor.py" \
    "$transitive_repository/remote/open-verified-lock-descriptor.py"
chmod 0755 "$transitive_campaign" \
    "$transitive_repository/remote/verify-external-vulkan-lease.py" \
    "$transitive_repository/remote/signal-process-group.py" \
    "$transitive_repository/remote/open-verified-lock-descriptor.py"
transitive_source=$transitive_repository/remote/select-projector.sh
transitive_drift_output=$work_directory/transitive-runtime-source-drift
write_control "$transitive_drift_output" mutate-slot 12
write_control "$transitive_drift_output" mutate-path "$transitive_source"
primary_campaign=$campaign
campaign=$transitive_campaign
set +e
run_campaign "$transitive_drift_output" \
    >"$work_directory/transitive-drift.stdout" \
    2>"$work_directory/transitive-drift.stderr"
transitive_drift_status=$?
set -e
campaign=$primary_campaign
transitive_drift_state=accepted
[ "$transitive_drift_status" -eq 1 ] || \
    transitive_drift_state="status-$transitive_drift_status"
[ "$(invocation_count "$transitive_drift_output")" -eq 12 ] || \
    transitive_drift_state='arm-count'
cmp -s "$transitive_drift_output/source-status-before.txt" \
    "$transitive_drift_output/source-status-after.txt" && \
    transitive_drift_state='source-witness-unchanged' || true
awk -F '\t' 'NR == 2 && $1 == "failed" && $3 == 12 &&
    $6 == "source-drift" { found = 1 }
    END { exit found ? 0 : 1 }
' "$transitive_drift_output/terminal-state.tsv" || \
    transitive_drift_state='terminal-state'
[ ! -e "$transitive_drift_output/summary.tsv" ] || \
    transitive_drift_state='summary-published'
[ ! -e "$transitive_drift_output/SHA256SUMS" ] || \
    transitive_drift_state='manifest-published'
grep -F 'fixed64_campaign=failed reason=source-drift' \
    "$work_directory/transitive-drift.stderr" >/dev/null || \
    transitive_drift_state='reason-absent'
report rejects_transitive_runtime_source_drift "$transitive_drift_state"

# A valid complete run with one below-target model seals evidence but returns
# failure and withholds a target-met claim.
miss_output=$work_directory/target-miss
write_control "$miss_output" target-miss 1
set +e
run_campaign "$miss_output" >"$work_directory/miss.stdout" \
    2>"$work_directory/miss.stderr"
miss_status=$?
set -e
miss_state=accepted
[ "$miss_status" -eq 1 ] || miss_state="status-$miss_status"
[ -f "$miss_output/SHA256SUMS" ] || miss_state='manifest-absent'
if ! awk -F '\t' '$1 == "qwen38-4b-distill" && $5 == 0 && $11 == "unmet" { found = 1 }
    END { exit found ? 0 : 1 }
' "$miss_output/model-summary.tsv"; then
    miss_state='target-claim'
    cat "$miss_output/model-summary.tsv" >&2
fi
awk -F '\t' 'NR == 2 && $1 == "completed-target-unmet" &&
    $5 == "unmet" && $6 == "none" { found = 1 }
    END { exit found ? 0 : 1 }
' "$miss_output/terminal-state.tsv" || miss_state='terminal-state'
report seals_below_target_evidence "$miss_state"

# Model or source drift after the last arm invalidates the before/after join.
drift_model=$models_directory/Qwen3.8-4B-Distill-GGUF/Qwen3.8-4B-Q4_K_M.gguf
cp -- "$drift_model" "$work_directory/4b-model.original"
drift_output=$work_directory/identity-drift
write_control "$drift_output" mutate-slot 12
write_control "$drift_output" mutate-path "$drift_model"
set +e
run_campaign "$drift_output" \
    >"$work_directory/drift.stdout" 2>"$work_directory/drift.stderr"
drift_status=$?
set -e
cp -- "$work_directory/4b-model.original" "$drift_model"
drift_state=accepted
[ "$drift_status" -eq 1 ] || drift_state="status-$drift_status"
awk -F '\t' '$1 == "model:qwen38-4b-distill" && $7 == "rejected" { found = 1 }
    END { exit found ? 0 : 1 }
' "$drift_output/identity-check.tsv" || drift_state='drift-unreported'
[ ! -e "$drift_output/SHA256SUMS" ] || drift_state='drift-manifest'
report rejects_postrun_identity_drift "$drift_state"

# The same identity join binds executable runner bytes, not only model bytes.
cp -- "$fake_runner" "$work_directory/fake-runner.original"
runner_drift_output=$work_directory/runner-identity-drift
write_control "$runner_drift_output" mutate-slot 12
write_control "$runner_drift_output" mutate-path "$fake_runner"
set +e
run_campaign "$runner_drift_output" \
    >"$work_directory/runner-drift.stdout" \
    2>"$work_directory/runner-drift.stderr"
runner_drift_status=$?
set -e
cp -- "$work_directory/fake-runner.original" "$fake_runner"
chmod 0755 "$fake_runner"
runner_drift_state=accepted
[ "$runner_drift_status" -eq 1 ] || \
    runner_drift_state="status-$runner_drift_status"
awk -F '\t' '$1 == "child_runner" && $7 == "rejected" { found = 1 }
    END { exit found ? 0 : 1 }
' "$runner_drift_output/identity-check.tsv" || \
    runner_drift_state='runner-drift-unreported'
[ ! -e "$runner_drift_output/SHA256SUMS" ] || \
    runner_drift_state='runner-drift-manifest'
report rejects_postrun_runner_drift "$runner_drift_state"

# Request-byte mutation remains distinct from response or timing validation.
request_output=$work_directory/request-drift
write_control "$request_output" mutate-request-slot 04
set +e
run_campaign "$request_output" \
    >"$work_directory/request.stdout" 2>"$work_directory/request.stderr"
request_status=$?
set -e
request_state=accepted
[ "$request_status" -eq 1 ] || request_state="status-$request_status"
[ ! -e "$request_output/summary.tsv" ] || request_state='summary-published'
grep -F 'differs from the retained canonical request' \
    "$request_output/summary-execution.txt" >/dev/null || request_state='reason-absent'
report rejects_request_identity_drift "$request_state"

# Summary generation publishes neither summary pathname when validation aborts.
summary_output=$work_directory/summary-failure
set +e
run_campaign "$summary_output" \
    QWEN_SERVED_CAMPAIGN_SUMMARIZER="$failing_summarizer" \
    >"$work_directory/summary-failure.stdout" \
    2>"$work_directory/summary-failure.stderr"
summary_status=$?
set -e
summary_state=accepted
[ "$summary_status" -eq 1 ] || summary_state="status-$summary_status"
[ ! -e "$summary_output/summary.tsv" ] || summary_state='summary-published'
[ ! -e "$summary_output/model-summary.tsv" ] || summary_state='model-summary-published'
find "$summary_output" -name '*.new' | grep . >/dev/null && \
    summary_state='summary-temporary-left' || true
report atomic_summary_failure "$summary_state"

# The manifest command fails only for relative campaign artifacts. Identity
# capture succeeds first; manifest publication then leaves no final pathname.
fake_bin=$work_directory/fake-bin
mkdir "$fake_bin"
real_sha256sum=$(command -v sha256sum)
cat >"$fake_bin/sha256sum" <<EOF
#!/bin/sh
case \${1:-} in
    ./*) exit 41 ;;
esac
exec "$real_sha256sum" "\$@"
EOF
chmod 0755 "$fake_bin/sha256sum"
manifest_output=$work_directory/manifest-failure
set +e
PATH="$fake_bin:$PATH" run_campaign "$manifest_output" \
    >"$work_directory/manifest-failure.stdout" \
    2>"$work_directory/manifest-failure.stderr"
manifest_status=$?
set -e
manifest_state=accepted
[ "$manifest_status" -eq 1 ] || manifest_state="status-$manifest_status"
[ ! -e "$manifest_output/SHA256SUMS" ] || manifest_state='manifest-published'
[ ! -e "$manifest_output/.SHA256SUMS.new" ] || manifest_state='manifest-temporary-left'
awk -F '\t' 'NR == 2 && $1 == "failed" && $6 == "manifest-generation" { found = 1 }
    END { exit found ? 0 : 1 }
' "$manifest_output/terminal-state.tsv" || manifest_state='terminal-state'
report atomic_manifest_failure "$manifest_state"

# Semantic verification runs against the complete staged manifest before its
# atomic rename. A verifier refusal preserves summaries and terminal evidence
# while removing every publishable or temporary manifest pathname.
staged_verifier_output=$work_directory/staged-verifier-failure
set +e
run_campaign "$staged_verifier_output" \
    QWEN_SERVED_CAMPAIGN_SUMMARIZER="$staged_verifier_summarizer" \
    QWEN_TEST_FIXED64_REAL_SUMMARIZER="$summarizer" \
    >"$work_directory/staged-verifier.stdout" \
    2>"$work_directory/staged-verifier.stderr"
staged_verifier_status=$?
set -e
staged_verifier_state=accepted
[ "$staged_verifier_status" -eq 1 ] || \
    staged_verifier_state="status-$staged_verifier_status"
[ "$(invocation_count "$staged_verifier_output")" -eq 12 ] || \
    staged_verifier_state='arm-count'
[ -s "$staged_verifier_output/summary.tsv" ] || \
    staged_verifier_state='summary-absent'
[ -s "$staged_verifier_output/model-summary.tsv" ] || \
    staged_verifier_state='model-summary-absent'
[ ! -e "$staged_verifier_output/SHA256SUMS" ] || \
    staged_verifier_state='manifest-published'
[ ! -e "$staged_verifier_output/.SHA256SUMS.new" ] || \
    staged_verifier_state='manifest-temporary-left'
awk -F '\t' 'NR == 2 && $1 == "failed" && $3 == 12 &&
    $6 == "sealed-manifest-verification" { found = 1 }
    END { exit found ? 0 : 1 }
' "$staged_verifier_output/terminal-state.tsv" || \
    staged_verifier_state='terminal-state'
grep -F 'fake staged semantic verifier failure' \
    "$work_directory/staged-verifier.stderr" >/dev/null || \
    staged_verifier_state='verifier-diagnostic-absent'
report atomic_staged_semantic_verifier_failure "$staged_verifier_state"

# A pre-existing hardware lease refuses the campaign before it can claim an
# evidence directory or execute the first served-decode arm.
preheld_lease_marker=$work_directory/preheld-vulkan-lease.ready
flock "$workload_lock" sh -c \
    'printf "held\n" >"$1"; sleep 2' sh "$preheld_lease_marker" &
preheld_lease_pid=$!
preheld_lease_wait=0
while [ ! -s "$preheld_lease_marker" ] && \
      [ "$preheld_lease_wait" -lt 100 ]; do
    sleep 0.02
    preheld_lease_wait=$((preheld_lease_wait + 1))
done
preheld_lease_output=$work_directory/preheld-vulkan-lease
set +e
run_campaign "$preheld_lease_output" \
    >"$work_directory/preheld-vulkan-lease.stdout" \
    2>"$work_directory/preheld-vulkan-lease.stderr"
preheld_lease_status=$?
set -e
wait "$preheld_lease_pid"
preheld_lease_state=accepted
[ -s "$preheld_lease_marker" ] || preheld_lease_state='holder-not-ready'
[ "$preheld_lease_status" -eq 2 ] || \
    preheld_lease_state="status-$preheld_lease_status"
[ ! -e "$preheld_lease_output" ] || preheld_lease_state='output-claimed'
[ "$(invocation_count "$preheld_lease_output")" -eq 0 ] || \
    preheld_lease_state='runner-entered'
grep -F 'another Vulkan workload holds the shared lease' \
    "$work_directory/preheld-vulkan-lease.stderr" >/dev/null || \
    preheld_lease_state='refusal-absent'
report refuses_preheld_vulkan_lease_before_output "$preheld_lease_state"

# The narrower campaign-control lease carries a separate refusal contract once
# the campaign itself owns the host-wide Vulkan execution lease.
preheld_control_marker=$work_directory/preheld-control-lease.ready
flock "$campaign_lock" sh -c \
    'printf "held\n" >"$1"; sleep 2' sh "$preheld_control_marker" &
preheld_control_pid=$!
preheld_control_wait=0
while [ ! -s "$preheld_control_marker" ] && \
      [ "$preheld_control_wait" -lt 100 ]; do
    sleep 0.02
    preheld_control_wait=$((preheld_control_wait + 1))
done
preheld_control_output=$work_directory/preheld-control-lease
set +e
run_campaign "$preheld_control_output" \
    >"$work_directory/preheld-control-lease.stdout" \
    2>"$work_directory/preheld-control-lease.stderr"
preheld_control_status=$?
set -e
wait "$preheld_control_pid"
preheld_control_state=accepted
[ -s "$preheld_control_marker" ] || preheld_control_state='holder-not-ready'
[ "$preheld_control_status" -eq 2 ] || \
    preheld_control_state="status-$preheld_control_status"
[ ! -e "$preheld_control_output" ] || preheld_control_state='output-claimed'
[ "$(invocation_count "$preheld_control_output")" -eq 0 ] || \
    preheld_control_state='runner-entered'
grep -F 'another fixed-64 served campaign holds the control lease' \
    "$work_directory/preheld-control-lease.stderr" >/dev/null || \
    preheld_control_state='refusal-absent'
report refuses_preheld_campaign_control_lease "$preheld_control_state"

# A newly acquired host-wide lease removes a same-UID regular proof whose PID
# is dead before it publishes the current holder proof into the campaign.
stale_proof_pid=999999999
stale_proof=$state_directory/.fixed64-vulkan-external-lease.$stale_proof_pid.tsv
[ ! -e "/proc/$stale_proof_pid" ]
printf 'key\tvalue\nschema\tfixed64-vulkan-external-lease-v1\nlock_path\t%s\nholder_pid\t%s\nholder_start_time_ticks\t1\nholder_fd\t8\nsource_revision\t%s\n' \
    "$workload_lock" "$stale_proof_pid" "$(git rev-parse HEAD)" \
    >"$stale_proof"
chmod 0600 "$stale_proof"
stale_proof_output=$work_directory/stale-external-lease-proof
write_control "$stale_proof_output" delay-slot 01
write_control "$stale_proof_output" delay-seconds 2
(
    set +e
    run_campaign "$stale_proof_output" \
        >"$work_directory/stale-proof.stdout" \
        2>"$work_directory/stale-proof.stderr"
    printf '%s\n' "$?" >"$work_directory/stale-proof.status"
) &
stale_proof_job_pid=$!
stale_proof_wait=0
while [ ! -s "$stale_proof_output/external-vulkan-lease.tsv" ] && \
      [ "$stale_proof_wait" -lt 250 ]; do
    sleep 0.02
    stale_proof_wait=$((stale_proof_wait + 1))
done
stale_proof_state=accepted
if [ ! -s "$stale_proof_output/external-vulkan-lease.tsv" ]; then
    stale_proof_state='current-proof-not-published'
else
    stale_proof_holder=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
        "$stale_proof_output/external-vulkan-lease.tsv")
    current_state_proof=$state_directory/.fixed64-vulkan-external-lease.$stale_proof_holder.tsv
    [ ! -e "$stale_proof" ] || stale_proof_state='stale-proof-survived'
    [ -f "$current_state_proof" ] || stale_proof_state='current-state-proof-absent'
    cmp -s "$current_state_proof" \
        "$stale_proof_output/external-vulkan-lease.tsv" || \
        stale_proof_state='current-proof-differs'
    live_proof_count=$(find "$state_directory" -maxdepth 1 -type f \
        -name '.fixed64-vulkan-external-lease.*.tsv' -print | wc -l)
    [ "$live_proof_count" -eq 1 ] || \
        stale_proof_state="live-proof-count-$live_proof_count"
fi
wait "$stale_proof_job_pid"
stale_proof_status=$(cat "$work_directory/stale-proof.status")
[ "$stale_proof_status" -eq 0 ] || \
    stale_proof_state="status-$stale_proof_status"
[ "$(invocation_count "$stale_proof_output")" -eq 12 ] || \
    stale_proof_state='arm-count'
[ -s "$stale_proof_output/SHA256SUMS" ] || \
    stale_proof_state='manifest-absent'
remaining_proof_count=$(find "$state_directory" -maxdepth 1 -type f \
    -name '.fixed64-vulkan-external-lease.*.tsv' -print | wc -l)
[ "$remaining_proof_count" -eq 0 ] || \
    stale_proof_state="proof-residue-count-$remaining_proof_count"
report removes_stale_external_lease_proof_on_acquisition "$stale_proof_state"

# TERM reaches the active campaign process, which forwards TERM to the
# runner's dedicated process group. The fixture suppresses the runner's EXIT
# cleanup and leaves one descriptor-free workload in another session. The
# outer holder must retain descriptor 8 and complete emergency teardown before
# it removes the private lease proof or exits with the signal status.
term_output=$work_directory/term-failed-runner-teardown
write_control "$term_output" runner-sigkill-slot 01
write_control "$term_output" signal-teardown-fail-slot 01
(
    set +e
    run_campaign "$term_output" \
        >"$work_directory/term.stdout" 2>"$work_directory/term.stderr"
    printf '%s\n' "$?" >"$work_directory/term.status"
) &
term_job_pid=$!
term_control=$(control_directory "$term_output")
term_wait=0
while { [ ! -s "$term_control/runner-sigkill-runner-01.tsv" ] || \
        [ ! -s "$term_control/detached-workload-01.tsv" ] || \
        [ ! -s "$term_control/runner-sigkill-ready-01" ] || \
        [ ! -s "$term_output/external-vulkan-lease.tsv" ]; } && \
      [ "$term_wait" -lt 250 ]; do
    sleep 0.02
    term_wait=$((term_wait + 1))
done
term_state=accepted
if [ ! -s "$term_control/runner-sigkill-runner-01.tsv" ] || \
   [ ! -s "$term_control/detached-workload-01.tsv" ] || \
   [ ! -s "$term_control/runner-sigkill-ready-01" ] || \
   [ ! -s "$term_output/external-vulkan-lease.tsv" ]; then
    term_state='runner-not-ready'
else
    term_runner_pid=$(awk -F '\t' 'NR == 2 { print $1 }' \
        "$term_control/runner-sigkill-runner-01.tsv")
    term_workload_pid=$(awk -F '\t' 'NR == 2 { print $1 }' \
        "$term_control/detached-workload-01.tsv")
    term_workload_start=$(awk -F '\t' 'NR == 2 { print $2 }' \
        "$term_control/detached-workload-01.tsv")
    runner_sigkill_cleanup_pid=$term_workload_pid
    runner_sigkill_cleanup_start=$term_workload_start
    term_campaign_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
        "$term_output/external-vulkan-lease.tsv")
    term_runner_pgid=$(ps -o pgid= -p "$term_runner_pid" | tr -d ' ')
    [ "$term_runner_pgid" = "$term_runner_pid" ] || \
        term_state='runner-not-process-group-leader'
    kill -TERM "$term_campaign_pid"
fi
term_teardown_wait=0
while [ ! -s "$term_control/emergency-teardown-entered-01.tsv" ] && \
      [ "$term_teardown_wait" -lt 250 ]; do
    sleep 0.02
    term_teardown_wait=$((term_teardown_wait + 1))
done
if [ ! -s "$term_control/emergency-teardown-entered-01.tsv" ]; then
    term_state='emergency-teardown-not-entered'
    cleanup_runner_sigkill_workload
else
    if ! process_is_running "${term_workload_pid:-0}"; then
        term_state='workload-died-before-emergency-teardown'
    fi
    set +e
    flock -n -E 75 "$workload_lock" true
    term_recovery_probe=$?
    set -e
    [ "$term_recovery_probe" -eq 75 ] || \
        term_state="recovery-lease-status-$term_recovery_probe"
    printf 'release\n' >"$term_control/emergency-teardown-release-01"
fi
wait "$term_job_pid"
term_status=$(cat "$work_directory/term.status")
[ "$term_status" -eq 143 ] || term_state="status-$term_status"
if [ -n "${term_runner_pid:-}" ] && [ -e "/proc/$term_runner_pid" ]; then
    term_state='runner-survived'
fi
if process_is_running "${term_workload_pid:-0}"; then
    term_state='workload-survived'
else
    runner_sigkill_cleanup_pid=''
    runner_sigkill_cleanup_start=''
fi
[ -s "$term_output/arms/01-forward-qwen35-08b/teardown.txt" ] || \
    term_state='teardown-marker-absent'
[ ! -e "$term_control/teardown-01" ] || term_state='ordinary-teardown-ran'
[ -s "$term_control/emergency-teardown-completed-01.tsv" ] || \
    term_state='emergency-teardown-completion-absent'
awk -F '\t' 'NR == 2 && $1 == "interrupted" && $3 == 0 && $4 == 1 &&
    $5 == "pending" && $6 == "signal-TERM" { found = 1 }
    END { exit found ? 0 : 1 }
' "$term_output/terminal-state.tsv" || term_state='terminal-state'
[ ! -e "$term_output/SHA256SUMS" ] || term_state='manifest-published'
report term_recovers_failed_runner_teardown "$term_state"

# SIGKILL bypasses the runner's EXIT trap after its detached workload crosses
# the launch boundary with descriptors 8 and 9 closed. The campaign must retain
# the Vulkan lease, run one emergency teardown, and prove absence before exit.
runner_kill_output=$work_directory/runner-sigkill-emergency-teardown
write_control "$runner_kill_output" runner-sigkill-slot 01
write_control "$runner_kill_output" emergency-teardown-failures-01 1
printf '02\n' >"$(control_directory "$runner_kill_output")/emergency-teardown-invocations.tsv"
(
    set +e
    run_campaign "$runner_kill_output" \
        >"$work_directory/runner-sigkill.stdout" \
        2>"$work_directory/runner-sigkill.stderr"
    printf '%s\n' "$?" >"$work_directory/runner-sigkill.status"
) &
runner_kill_job_pid=$!
runner_kill_control=$(control_directory "$runner_kill_output")
runner_kill_arm=$runner_kill_output/arms/01-forward-qwen35-08b
runner_kill_ready_wait=0
while { [ ! -s "$runner_kill_control/runner-sigkill-runner-01.tsv" ] || \
        [ ! -s "$runner_kill_control/detached-workload-01.tsv" ] || \
        [ ! -s "$runner_kill_control/runner-sigkill-ready-01" ] || \
        [ ! -s "$runner_kill_output/external-vulkan-lease.tsv" ]; } && \
      [ "$runner_kill_ready_wait" -lt 250 ]; do
    sleep 0.02
    runner_kill_ready_wait=$((runner_kill_ready_wait + 1))
done
runner_kill_state=accepted
if [ ! -s "$runner_kill_control/runner-sigkill-runner-01.tsv" ] || \
   [ ! -s "$runner_kill_control/detached-workload-01.tsv" ] || \
   [ ! -s "$runner_kill_control/runner-sigkill-ready-01" ] || \
   [ ! -s "$runner_kill_output/external-vulkan-lease.tsv" ]; then
    runner_kill_state='runner-not-ready'
    if [ -s "$runner_kill_output/external-vulkan-lease.tsv" ]; then
        runner_kill_campaign_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
            "$runner_kill_output/external-vulkan-lease.tsv")
        kill -TERM "$runner_kill_campaign_pid" 2>/dev/null || true
    fi
else
    runner_kill_runner_row=$(awk -F '\t' 'NR == 2 { print }' \
        "$runner_kill_control/runner-sigkill-runner-01.tsv")
    IFS=$(printf '\t') read -r runner_kill_runner_pid \
        runner_kill_runner_start runner_kill_runner_pgid runner_kill_runner_sid <<EOF
$runner_kill_runner_row
EOF
    runner_kill_workload_row=$(awk -F '\t' 'NR == 2 { print }' \
        "$runner_kill_control/detached-workload-01.tsv")
    IFS=$(printf '\t') read -r runner_kill_workload_pid \
        runner_kill_workload_start runner_kill_workload_parent \
        runner_kill_workload_pgid runner_kill_workload_sid \
        runner_kill_workload_fd8 runner_kill_workload_fd9 <<EOF
$runner_kill_workload_row
EOF
    runner_sigkill_cleanup_pid=$runner_kill_workload_pid
    runner_sigkill_cleanup_start=$runner_kill_workload_start
    [ "$runner_kill_runner_pgid" = "$runner_kill_runner_pid" ] || \
        runner_kill_state='runner-not-process-group-leader'
    [ "$runner_kill_runner_sid" = "$runner_kill_runner_pid" ] || \
        runner_kill_state='runner-not-session-leader'
    [ "$runner_kill_workload_parent" = "$runner_kill_runner_pid" ] || \
        runner_kill_state='workload-parent-differs'
    [ "$runner_kill_workload_pgid" = "$runner_kill_workload_pid" ] || \
        runner_kill_state='workload-not-process-group-leader'
    [ "$runner_kill_workload_sid" = "$runner_kill_workload_pid" ] || \
        runner_kill_state='workload-not-session-leader'
    [ "$runner_kill_workload_fd8" = closed ] || \
        runner_kill_state='workload-inherited-fd8'
    [ "$runner_kill_workload_fd9" = closed ] || \
        runner_kill_state='workload-inherited-fd9'
    [ "$(process_start_time_ticks "$runner_kill_runner_pid")" = \
        "$runner_kill_runner_start" ] || runner_kill_state='runner-identity-drift'
    [ "$(process_start_time_ticks "$runner_kill_workload_pid")" = \
        "$runner_kill_workload_start" ] || \
        runner_kill_state='workload-identity-drift'
    set +e
    flock -n -E 75 "$workload_lock" true
    runner_kill_initial_probe=$?
    set -e
    [ "$runner_kill_initial_probe" -eq 75 ] || \
        runner_kill_state="initial-lease-status-$runner_kill_initial_probe"
    kill -KILL "$runner_kill_runner_pid"
fi

runner_kill_retry_wait=0
runner_kill_attempt_count=0
while [ "$runner_kill_attempt_count" -lt 1 ] && \
      [ "$runner_kill_retry_wait" -lt 250 ]; do
    sleep 0.02
    runner_kill_retry_wait=$((runner_kill_retry_wait + 1))
    if [ -r "$runner_kill_control/emergency-teardown-invocations.tsv" ]; then
        runner_kill_attempt_count=$(awk '$1 == "01" { attempts++ } \
            END { print attempts + 0 }' \
            "$runner_kill_control/emergency-teardown-invocations.tsv")
    fi
done
if [ "$runner_kill_retry_wait" -ge 250 ]; then
    runner_kill_state='first-emergency-attempt-absent'
else
    runner_kill_campaign_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
        "$runner_kill_output/external-vulkan-lease.tsv")
    kill -TERM "$runner_kill_campaign_pid"
    sleep 0.1
    set +e
    flock -n -E 75 "$workload_lock" true
    runner_kill_retry_probe=$?
    set -e
    [ "$runner_kill_retry_probe" -eq 75 ] || \
        runner_kill_state="retry-lease-status-$runner_kill_retry_probe"
fi

runner_kill_teardown_wait=0
while [ ! -s "$runner_kill_control/emergency-teardown-entered-01.tsv" ] && \
      [ "$runner_kill_teardown_wait" -lt 500 ]; do
    sleep 0.02
    runner_kill_teardown_wait=$((runner_kill_teardown_wait + 1))
done
if [ ! -s "$runner_kill_control/emergency-teardown-entered-01.tsv" ]; then
    runner_kill_state='emergency-teardown-not-entered'
    cleanup_runner_sigkill_workload
else
    if process_is_running "${runner_kill_runner_pid:-0}"; then
        runner_kill_state='runner-survived-sigkill'
    fi
    if ! process_is_running "${runner_kill_workload_pid:-0}"; then
        runner_kill_state='workload-died-before-teardown'
    fi
    set +e
    flock -n -E 75 "$workload_lock" true
    runner_kill_recovery_probe=$?
    set -e
    [ "$runner_kill_recovery_probe" -eq 75 ] || \
        runner_kill_state="recovery-lease-status-$runner_kill_recovery_probe"
    printf 'release\n' \
        >"$runner_kill_control/emergency-teardown-release-01"
fi

set +e
wait "$runner_kill_job_pid"
runner_kill_job_status=$?
set -e
[ "$runner_kill_job_status" -eq 0 ] || \
    runner_kill_state="job-status-$runner_kill_job_status"
if [ -r "$work_directory/runner-sigkill.status" ]; then
    runner_kill_campaign_status=$(cat "$work_directory/runner-sigkill.status")
    [ "$runner_kill_campaign_status" -eq 1 ] || \
        runner_kill_state="campaign-status-$runner_kill_campaign_status"
else
    runner_kill_state='campaign-status-absent'
fi
if process_is_running "${runner_kill_workload_pid:-0}"; then
    runner_kill_state='workload-survived-emergency-teardown'
else
    runner_sigkill_cleanup_pid=''
    runner_sigkill_cleanup_start=''
fi
[ "$(invocation_count "$runner_kill_output")" -eq 1 ] || \
    runner_kill_state='arm-count'
[ "$(awk '$1 == "01" { attempts++ } END { print attempts + 0 }' \
    "$runner_kill_control/emergency-teardown-invocations.tsv")" -eq 2 ] && \
[ "$(awk '$1 == "02" { attempts++ } END { print attempts + 0 }' \
    "$runner_kill_control/emergency-teardown-invocations.tsv")" -eq 1 ] || \
    runner_kill_state='emergency-teardown-count'
[ ! -e "$runner_kill_control/teardown-01" ] || \
    runner_kill_state='ordinary-teardown-ran'
[ -s "$runner_kill_control/detached-workload-term-01.tsv" ] || \
    runner_kill_state='workload-term-witness-absent'
[ -s "$runner_kill_control/emergency-teardown-completed-01.tsv" ] || \
    runner_kill_state='teardown-completion-witness-absent'
[ -s "$runner_kill_arm/teardown.txt" ] || \
    runner_kill_state='arm-teardown-evidence-absent'
awk -F '\t' 'NR == 2 && $1 == 1 && $3 == 137 && $4 == "failed" {
    accepted = 1 }
    END { exit accepted ? 0 : 1 }
' "$runner_kill_output/arm-status.tsv" || runner_kill_state='arm-status'
awk -F '\t' 'NR == 2 && $1 == "failed" && $3 == 0 && $4 == 1 &&
    $5 == "pending" && $6 == "arm" { accepted = 1 }
    END { exit accepted ? 0 : 1 }
' "$runner_kill_output/terminal-state.tsv" || runner_kill_state='terminal-state'
awk -F '\t' -v runner_pid="${runner_kill_runner_pid:-0}" \
    -v runner_start="${runner_kill_runner_start:-0}" '
    NR == 1 && $0 == "slot\trunner_pid\trunner_start_time_ticks\trunner_status" {
        header = 1 }
    NR == 2 && $1 == 1 && $2 == runner_pid && $3 == runner_start && $4 == 137 {
        row = 1 }
    END { exit header && row && NR == 2 ? 0 : 1 }
' "$runner_kill_arm/emergency-runner.tsv" || \
    runner_kill_state='emergency-runner-evidence'
awk -F '\t' '
    NR == 1 && $0 == "point\tstatus\texpected_status" { header = 1 }
    NR == 2 && $1 == "before-teardown" && $2 == 75 && $3 == 75 { before = 1 }
    NR == 3 && $1 == "after-teardown" && $2 == 75 && $3 == 75 { after = 1 }
    END { exit header && before && after && NR == 3 ? 0 : 1 }
' "$runner_kill_arm/emergency-lock-probes.tsv" || \
    runner_kill_state='emergency-lock-probe-evidence'
[ -s "$runner_kill_arm/emergency-teardown.stdout" ] || \
    runner_kill_state='emergency-teardown-stdout-absent'
[ -f "$runner_kill_arm/emergency-teardown.stderr" ] || \
    runner_kill_state='emergency-teardown-stderr-absent'
awk -F '\t' '
    NR == 1 && $0 == "slot\trunner_status\tteardown_status\tstate" { header = 1 }
    NR == 2 && $1 == 1 && $2 == 137 && $3 == 0 && $4 == "accepted" { row = 1 }
    END { exit header && row && NR == 2 ? 0 : 1 }
' "$runner_kill_arm/emergency-teardown-status.tsv" || \
    runner_kill_state='emergency-teardown-status-evidence'
awk -F '\t' '
    NR == 1 && $0 == "attempt\tteardown_status" { header = 1 }
    NR == 2 && $1 == 1 && $2 == 47 { first = 1 }
    NR == 3 && $1 == 2 && $2 == 0 { second = 1 }
    END { exit header && first && second && NR == 3 ? 0 : 1 }
' "$runner_kill_arm/emergency-teardown-attempts.tsv" || \
    runner_kill_state='emergency-teardown-retry-evidence'
[ ! -e "$runner_kill_output/SHA256SUMS" ] || \
    runner_kill_state='manifest-published'
set +e
flock -n -E 75 "$workload_lock" true
runner_kill_final_probe=$?
set -e
[ "$runner_kill_final_probe" -eq 0 ] || \
    runner_kill_state="final-lease-status-$runner_kill_final_probe"
report runner_sigkill_runs_emergency_teardown "$runner_kill_state"
if [ "$runner_kill_state" != accepted ]; then
    printf 'runner_sigkill_state=%s\n' "$runner_kill_state" >&2
    find "$runner_kill_output" "$runner_kill_control" -maxdepth 2 \
        -type f -print 2>/dev/null | LC_ALL=C sort >&2 || true
    sed -n '1,160p' "$work_directory/runner-sigkill.stderr" >&2
fi

# SIGKILL cannot run the outer holder's traps. Descriptor 8 therefore crosses
# into the detached arm runner so that holder death cannot expose the GPU lease
# while the runner or its descendant still executes.
sigkill_output=$work_directory/sigkill-holder-lease-continuity
write_control "$sigkill_output" delay-slot 01
write_control "$sigkill_output" delay-seconds 5
(
    set +e
    run_campaign "$sigkill_output" \
        >"$work_directory/sigkill.stdout" 2>"$work_directory/sigkill.stderr"
    printf '%s\n' "$?" >"$work_directory/sigkill.status"
) &
sigkill_job_pid=$!
sigkill_control=$(control_directory "$sigkill_output")
sigkill_wait=0
while { [ ! -s "$sigkill_control/runner.pid" ] || \
        [ ! -s "$sigkill_control/descendant.pid" ] || \
        [ ! -s "$sigkill_output/external-vulkan-lease.tsv" ]; } && \
      [ "$sigkill_wait" -lt 250 ]; do
    sleep 0.02
    sigkill_wait=$((sigkill_wait + 1))
done
sigkill_state=accepted
if [ ! -s "$sigkill_control/runner.pid" ] || \
   [ ! -s "$sigkill_control/descendant.pid" ] || \
   [ ! -s "$sigkill_output/external-vulkan-lease.tsv" ]; then
    sigkill_state='runner-not-ready'
    if [ -s "$sigkill_output/external-vulkan-lease.tsv" ]; then
        sigkill_campaign_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
            "$sigkill_output/external-vulkan-lease.tsv")
        kill -TERM "$sigkill_campaign_pid" 2>/dev/null || true
    fi
else
    sigkill_runner_pid=$(cat "$sigkill_control/runner.pid")
    sigkill_descendant_pid=$(cat "$sigkill_control/descendant.pid")
    sigkill_campaign_pid=$(awk -F '\t' '$1 == "holder_pid" { print $2 }' \
        "$sigkill_output/external-vulkan-lease.tsv")
    sigkill_runner_start=$(process_start_time_ticks "$sigkill_runner_pid")
    sigkill_descendant_start=$(process_start_time_ticks "$sigkill_descendant_pid")
    kill -KILL "$sigkill_campaign_pid"
fi
set +e
wait "$sigkill_job_pid"
sigkill_job_status=$?
set -e
[ "$sigkill_job_status" -eq 0 ] || sigkill_state="job-status-$sigkill_job_status"
if [ -r "$work_directory/sigkill.status" ]; then
    sigkill_campaign_status=$(cat "$work_directory/sigkill.status")
    [ "$sigkill_campaign_status" -eq 137 ] || \
        sigkill_state="campaign-status-$sigkill_campaign_status"
else
    sigkill_state='campaign-status-absent'
fi
if [ -n "${sigkill_runner_pid:-}" ] && \
   ! process_is_running "$sigkill_runner_pid"; then
    sigkill_state='runner-did-not-survive-holder'
fi
if [ -n "${sigkill_descendant_pid:-}" ] && \
   ! process_is_running "$sigkill_descendant_pid"; then
    sigkill_state='descendant-did-not-survive-holder'
fi
set +e
flock -n -E 75 "$workload_lock" true
sigkill_held_probe_status=$?
set -e
[ "$sigkill_held_probe_status" -eq 75 ] || \
    sigkill_state="lease-exposed-status-$sigkill_held_probe_status"

sigkill_exit_wait=0
while { process_is_running "${sigkill_runner_pid:-0}" || \
        process_is_running "${sigkill_descendant_pid:-0}"; } && \
      [ "$sigkill_exit_wait" -lt 400 ]; do
    sleep 0.02
    sigkill_exit_wait=$((sigkill_exit_wait + 1))
done
if process_is_running "${sigkill_runner_pid:-0}" || \
   process_is_running "${sigkill_descendant_pid:-0}"; then
    sigkill_state='detached-process-timeout'
    if [ -n "${sigkill_runner_pid:-}" ] && \
       [ "$(process_start_time_ticks "$sigkill_runner_pid" 2>/dev/null || true)" = \
           "${sigkill_runner_start:-absent}" ]; then
        kill -TERM "$sigkill_runner_pid" 2>/dev/null || true
    fi
    if [ -n "${sigkill_descendant_pid:-}" ] && \
       [ "$(process_start_time_ticks "$sigkill_descendant_pid" 2>/dev/null || true)" = \
           "${sigkill_descendant_start:-absent}" ]; then
        kill -TERM "$sigkill_descendant_pid" 2>/dev/null || true
    fi
fi
[ -s "$sigkill_control/teardown-01" ] || sigkill_state='teardown-marker-absent'
[ -s "$sigkill_output/arms/01-forward-qwen35-08b/teardown.txt" ] || \
    sigkill_state='arm-teardown-evidence-absent'
[ ! -e "$sigkill_output/SHA256SUMS" ] || sigkill_state='manifest-published'
set +e
flock -n -E 75 "$workload_lock" true
sigkill_released_probe_status=$?
set -e
[ "$sigkill_released_probe_status" -eq 0 ] || \
    sigkill_state="lease-not-released-status-$sigkill_released_probe_status"
report sigkill_holder_preserves_runner_lease "$sigkill_state"

# The host-wide Vulkan lease prevents a second GPU workload from claiming an
# output path while the first campaign owns the hardware execution window.
lease_first_output=$work_directory/lease-first
write_control "$lease_first_output" delay-slot 01
write_control "$lease_first_output" delay-seconds 2
(
    set +e
    run_campaign "$lease_first_output" \
        >"$work_directory/lease-first.stdout" \
        2>"$work_directory/lease-first.stderr"
    printf '%s\n' "$?" >"$work_directory/lease-first.status"
) &
lease_first_pid=$!
lease_wait=0
lease_first_control=$(control_directory "$lease_first_output")
while [ ! -s "$lease_first_control/invocations.tsv" ] && \
      [ "$lease_wait" -lt 100 ]; do
    sleep 0.02
    lease_wait=$((lease_wait + 1))
done
lease_second_output=$work_directory/lease-second
set +e
run_campaign "$lease_second_output" \
    >"$work_directory/lease-second.stdout" \
    2>"$work_directory/lease-second.stderr"
lease_second_status=$?
set -e
wait "$lease_first_pid"
lease_state=accepted
lease_first_status=$(cat "$work_directory/lease-first.status")
[ "$lease_first_status" -eq 0 ] || \
    lease_state='first-campaign-failed'
[ "$lease_second_status" -eq 2 ] || lease_state="second-status-$lease_second_status"
[ ! -e "$lease_second_output" ] || lease_state='second-output-claimed'
grep -F 'another Vulkan workload holds the shared lease' \
    "$work_directory/lease-second.stderr" >/dev/null || lease_state='refusal-absent'
report serializes_hostwide_vulkan_workloads "$lease_state"
if [ "$lease_state" != accepted ]; then
    printf 'lease_first_status=%s lease_second_status=%s\n' \
        "$lease_first_status" "$lease_second_status" >&2
    printf '%s\n' 'lease-first stderr:' >&2
    cat "$work_directory/lease-first.stderr" >&2
    printf '%s\n' 'lease-second stderr:' >&2
    cat "$work_directory/lease-second.stderr" >&2
fi

if [ "$checks_run" -ne 90 ]; then
    printf 'test_run_fixed64_served_campaign=failed expected_checks=90 observed_checks=%s\n' \
        "$checks_run" >&2
    exit 1
fi
if [ "$failures" -ne 0 ]; then
    printf 'test_run_fixed64_served_campaign=failed checks=%s\n' "$failures" >&2
    exit 1
fi
printf 'test_run_fixed64_served_campaign=passed\n'
