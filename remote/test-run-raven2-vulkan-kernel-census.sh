#!/bin/sh
set -eu

# Exercise the preflight of run-raven2-vulkan-kernel-census.sh from a clone
# alone. The runner validates its mode, arm list, servers, manifests,
# scoreboard receipt, and calibration receipt before it reads the host name
# and the inherited SSH session, so a fixture whose preflight passes reaches
# the host or session refusal and a fixture whose preflight refuses names its
# own reason; both exit 2, and this test reads the message to tell them apart.
#
# Every invocation runs under env -i with the campaign's own execution path,
# HOME inside the scratch directory, and SSH_CONNECTION absent, so the SSH
# check refuses on the measured host and the host check refuses everywhere
# else. That absence is what keeps the test from launching thirteen served
# arms on the appliance.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$(basename "$0")" >&2
    printf 'Drives the census runner preflight over scratch fixtures.\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
runner=$script_directory/run-raven2-vulkan-kernel-census.sh
registry_reader=$script_directory/model-registry.sh
artifact_ledger=$script_directory/model-artifacts.tsv
model_id=qwen38-2b-distill
# The path the fixed-64 scoreboard campaign recorded as its own; hostname and
# python3 resolve through it, and a bare assignment from a failing command
# substitution would end the runner under set -eu with no message.
execution_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
patch_series_sha256=1111111111111111111111111111111111111111111111111111111111111111
foreign_sha256=2222222222222222222222222222222222222222222222222222222222222222
registry_sha256=3333333333333333333333333333333333333333333333333333333333333333
ledger_row_sha256=4444444444444444444444444444444444444444444444444444444444444444
reached_preflight_end='the census runs on the measured host|structurally valid inherited SSH session'

temporary_directory=$(mktemp -d)
active_fixture=initialization
diagnostic_file=
run_index=0
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'census preflight fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            sed -n '1,40p' "$diagnostic_file" >&2
        fi
    fi
    rm -r -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

# The runtime tree the arms would launch through: the three scripts the runner
# requires executable, each a stub that never runs because the preflight ends
# ahead of the first arm.
runtime_remote=$temporary_directory/runtime-remote
mkdir -p "$runtime_remote"
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    printf '#!/bin/sh\nexit 1\n' >"$runtime_remote/$runtime_script"
    chmod +x "$runtime_remote/$runtime_script"
done

home_directory=$temporary_directory/home
models_directory=$temporary_directory/models
mkdir -p "$home_directory"
model_file=$("$registry_reader" id "$model_id" model_file)
mkdir -p "$models_directory/$(dirname -- "$model_file")"
: >"$models_directory/$model_file"

# The tuple the scoreboard receipt must restate comes from the same readers
# the runner uses, so a registry edit moves fixture and runner together.
context=$("$registry_reader" id "$model_id" context_default)
batch=$("$registry_reader" id "$model_id" batch)
ubatch=$("$registry_reader" id "$model_id" ubatch)
cache_k=$("$registry_reader" id "$model_id" cache_type_k)
cache_v=$("$registry_reader" id "$model_id" cache_type_v)
flash=$("$registry_reader" id "$model_id" flash_attention)
ctx_checkpoints=$("$registry_reader" ctx-checkpoint "$model_id")
checkpoint_min_step=8192
model_bytes=$(awk -F'\t' -v id="$model_id" '$1 == id { print $3 }' "$artifact_ledger")
model_sha256=$(awk -F'\t' -v id="$model_id" '$1 == id { print $4 }' "$artifact_ledger")
source_repository=$(awk -F'\t' -v id="$model_id" '$1 == id { print $5 }' "$artifact_ledger")
source_revision=$(awk -F'\t' -v id="$model_id" '$1 == id { print $6 }' "$artifact_ledger")

# A server is an executable file bound to its manifest by byte count and
# digest, the rule bind_server applies, so the stub text decides both.
write_server() {
    server_root=$1
    server_body=$2
    mkdir -p "$server_root/bin"
    printf '#!/bin/sh\n# %s\nexit 1\n' "$server_body" >"$server_root/bin/llama-server"
    chmod +x "$server_root/bin/llama-server"
}

server_digest() {
    sha256sum "$1" | cut -d ' ' -f 1
}

server_byte_count() {
    wc -c <"$1" | tr -d ' '
}

production_root=$temporary_directory/prod
instrumented_root=$temporary_directory/inst
write_server "$production_root" production
write_server "$instrumented_root" instrumented
production_server=$production_root/bin/llama-server
instrumented_server=$instrumented_root/bin/llama-server
production_sha256=$(server_digest "$production_server")
production_bytes=$(server_byte_count "$production_server")
instrumented_sha256=$(server_digest "$instrumented_server")
instrumented_bytes=$(server_byte_count "$instrumented_server")

{
    printf 'executable\tllama-server\t%s\t%s\n' "$production_bytes" "$production_sha256"
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'serving_eligible\tyes\n'
} >"$production_root/artifact-manifest.tsv"
{
    printf 'executable\tllama-server\t%s\t%s\n' "$instrumented_bytes" "$instrumented_sha256"
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'instrumentation\tpipeline-census-v3\n'
    printf 'serving_eligible\tno\n'
} >"$instrumented_root/artifact-manifest.tsv"

# A production tree whose manifest names llama-server twice: the executable
# row count decides, so the second row refuses the binding.
duplicate_root=$temporary_directory/prod-duplicate
mkdir -p "$duplicate_root/bin"
cp -- "$production_server" "$duplicate_root/bin/llama-server"
chmod +x "$duplicate_root/bin/llama-server"
{
    printf 'executable\tllama-server\t%s\t%s\n' "$production_bytes" "$production_sha256"
    printf 'executable\tllama-server\t%s\t%s\n' "$((production_bytes + 1))" "$foreign_sha256"
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'serving_eligible\tyes\n'
} >"$duplicate_root/artifact-manifest.tsv"

# An instrumented tree whose executable row names other bytes, and one whose
# checkpoint semantics read forced-tail against the registry's positive
# checkpoint count. Nothing downstream of the binding reads the instrumented
# digest in calibration mode, so these two refusals hold only where the
# binding's exit status reaches the caller.
instrumented_mismatch_root=$temporary_directory/inst-mismatch
mkdir -p "$instrumented_mismatch_root/bin"
cp -- "$instrumented_server" "$instrumented_mismatch_root/bin/llama-server"
chmod +x "$instrumented_mismatch_root/bin/llama-server"
{
    printf 'executable\tllama-server\t%s\t%s\n' "$((instrumented_bytes + 1))" "$foreign_sha256"
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'instrumentation\tpipeline-census-v3\n'
    printf 'serving_eligible\tno\n'
} >"$instrumented_mismatch_root/artifact-manifest.tsv"
instrumented_forced_tail_root=$temporary_directory/inst-forced-tail
mkdir -p "$instrumented_forced_tail_root/bin"
cp -- "$instrumented_server" "$instrumented_forced_tail_root/bin/llama-server"
chmod +x "$instrumented_forced_tail_root/bin/llama-server"
{
    printf 'executable\tllama-server\t%s\t%s\n' "$instrumented_bytes" "$instrumented_sha256"
    printf 'checkpoint_semantics\tforced-tail-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'instrumentation\tpipeline-census-v3\n'
    printf 'serving_eligible\tno\n'
} >"$instrumented_forced_tail_root/artifact-manifest.tsv"

# The scoreboard receipt: an identity check binding the production server,
# the tuple that campaign resolved, and the inputs every census arm reruns
# under. The header of identity-check.tsv is compared literally, so it is
# written once here and copied into every variant.
write_identity_check() {
    identity_path=$1
    identity_digest=$2
    {
        printf 'subject\tpath\texpected_bytes\tobserved_bytes\texpected_sha256\tobserved_sha256\tstate\n'
        printf 'server\t%s\t%s\t%s\t%s\t%s\taccepted\n' \
            "$production_server" "$production_bytes" "$production_bytes" \
            "$identity_digest" "$identity_digest"
        printf 'model_registry\t%s\t0\t0\t%s\t%s\taccepted\n' \
            "$script_directory/models.tsv" "$registry_sha256" "$registry_sha256"
        printf 'artifact_ledger\t%s\t0\t0\t%s\t%s\taccepted\n' \
            "$artifact_ledger" "$ledger_row_sha256" "$ledger_row_sha256"
    } >"$identity_path"
}

write_models_resolved() {
    models_path=$1
    models_batch=$2
    {
        printf 'model_id\trole\tmodel_file\tmodel_path\tcontext\tbatch\tubatch\t'
        printf 'cache_k\tcache_v\tflash_attention\tctx_checkpoints\tcheckpoint_min_step\t'
        printf 'target_tok_s\tpublisher_bytes\tpublisher_sha256\tsource_repository\t'
        printf 'source_revision\tmodel_bytes\tmodel_sha256\n'
        printf '%s\tfast-text\t%s\t%s\t%s\t%s\t%s\t' \
            "$model_id" "$model_file" "$models_directory/$model_file" \
            "$context" "$models_batch" "$ubatch"
        printf '%s\t%s\t%s\t%s\t%s\t' \
            "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
        printf '10\t%s\t%s\t%s\t' "$model_bytes" "$model_sha256" "$source_repository"
        printf '%s\t%s\t%s\n' "$source_revision" "$model_bytes" "$model_sha256"
    } >"$models_path"
}

write_campaign_inputs() {
    inputs_path=$1
    inputs_profile=$2
    {
        printf 'key\tvalue\n'
        printf 'vulkan_profile\t%s\n' "$inputs_profile"
        printf 'generate_tokens\t64\n'
        printf 'sampling\ttemperature=0 top_k=1 seed=1 ignore_eos=true thinking=false\n'
        printf 'server_nice\t19\n'
        printf 'inference_cpu\t0\n'
        printf 'speculation\toff\n'
        printf 'router\t0\n'
    } >"$inputs_path"
}

scoreboard_receipt=$temporary_directory/scoreboard
mkdir -p "$scoreboard_receipt"
write_identity_check "$scoreboard_receipt/identity-check.tsv" "$production_sha256"
write_models_resolved "$scoreboard_receipt/models-resolved.tsv" "$batch"
write_campaign_inputs "$scoreboard_receipt/campaign-inputs.tsv" low-async

scoreboard_batch=$temporary_directory/scoreboard-batch
cp -R -- "$scoreboard_receipt" "$scoreboard_batch"
write_models_resolved "$scoreboard_batch/models-resolved.tsv" "$((batch + 1))"

scoreboard_profile=$temporary_directory/scoreboard-profile
cp -R -- "$scoreboard_receipt" "$scoreboard_profile"
write_campaign_inputs "$scoreboard_profile/campaign-inputs.tsv" low-serialized

scoreboard_no_models=$temporary_directory/scoreboard-no-models
cp -R -- "$scoreboard_receipt" "$scoreboard_no_models"
rm -- "$scoreboard_no_models/models-resolved.tsv"

scoreboard_foreign=$temporary_directory/scoreboard-foreign
cp -R -- "$scoreboard_receipt" "$scoreboard_foreign"
write_identity_check "$scoreboard_foreign/identity-check.tsv" "$foreign_sha256"

# The calibration receipt an attribution rests on: terminal-state.tsv reads
# accepted with three accepted controls and is '=' separated, while inputs.tsv
# binds the two server digests and is tab separated.
write_terminal_state() {
    terminal_path=$1
    accepted_controls=$2
    {
        printf 'census=accepted\n'
        printf 'census_mode=calibration\n'
        printf 'arm_failures=0\n'
        printf 'control_incomplete=0\n'
        printf 'control_refutations=0\n'
        printf 'control_unclassified=0\n'
        printf 'control_accepted=%s\n' "$accepted_controls"
        printf 'control_required=3\n'
    } >"$terminal_path"
}

write_calibration_inputs() {
    calibration_inputs_path=$1
    bound_production=$2
    {
        printf 'census_mode\tcalibration\n'
        printf 'production_server_sha256\t%s\n' "$bound_production"
        printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256"
    } >"$calibration_inputs_path"
}

calibration_receipt=$temporary_directory/calibration
mkdir -p "$calibration_receipt"
write_terminal_state "$calibration_receipt/terminal-state.tsv" 3
write_calibration_inputs "$calibration_receipt/inputs.tsv" "$production_sha256"

calibration_two_controls=$temporary_directory/calibration-two-controls
cp -R -- "$calibration_receipt" "$calibration_two_controls"
write_terminal_state "$calibration_two_controls/terminal-state.tsv" 2

calibration_foreign_server=$temporary_directory/calibration-foreign-server
cp -R -- "$calibration_receipt" "$calibration_foreign_server"
write_calibration_inputs "$calibration_foreign_server/inputs.tsv" "$foreign_sha256"

# One invocation: a scrubbed environment carrying the fixture paths, a fresh
# absolute output directory the runner refuses to reuse, and the message the
# case is named for. Every admitted outcome is exit 2, so the status separates
# a designed refusal from a death under set -eu and the message separates the
# refusals from each other.
run_runner() {
    case_name=$1
    expected_needle=$2
    shift 2
    run_index=$((run_index + 1))
    active_fixture=$case_name
    case_stderr=$temporary_directory/stderr-$run_index.txt
    diagnostic_file=$case_stderr
    set +e
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        "$@" \
        "$runner" "$model_id" "$temporary_directory/out-$run_index" \
        >"$temporary_directory/stdout-$run_index.txt" 2>"$case_stderr"
    runner_status=$?
    set -e
    if [ "$runner_status" -ne 2 ]; then
        printf 'case %s exited %s where the preflight exits 2\n' \
            "$case_name" "$runner_status" >&2
        return 1
    fi
    # The runner creates its output tree one line past the SSH check, so an
    # existing directory here reports a preflight that ran further than the
    # message claims and arms that reached the device.
    if [ -e "$temporary_directory/out-$run_index" ]; then
        printf 'case %s wrote an output directory the preflight never reaches\n' \
            "$case_name" >&2
        return 1
    fi
    if ! grep -Eq -- "$expected_needle" "$case_stderr"; then
        printf 'case %s stderr carries no match for %s\n' \
            "$case_name" "$expected_needle" >&2
        return 1
    fi
    diagnostic_file=
    printf '%s=accepted\n' "$case_name"
}

run_runner calibration_default "$reached_preflight_end"

run_runner attribution_receipt "$reached_preflight_end" \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_receipt" \
    QWEN_CENSUS_ARMS=I1

run_runner mode_name 'QWEN_CENSUS_MODE must be calibration or attribution' \
    QWEN_CENSUS_MODE=bogus

run_runner calibration_arm_list 'a calibration runs exactly' \
    QWEN_CENSUS_ARMS=I1

run_runner attribution_without_receipt \
    'an attribution requires QWEN_CENSUS_CALIBRATION_RECEIPT' \
    QWEN_CENSUS_MODE=attribution

run_runner calibration_control_count \
    'not an accepted calibration with three accepted controls' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_two_controls" \
    QWEN_CENSUS_ARMS=I1

# The production digest reaches the calibration comparison only where an arm
# binds P, so this case names an arm list carrying both servers.
run_runner calibration_bound_servers 'bound other servers' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_foreign_server" \
    QWEN_CENSUS_ARMS='P I0 I0 P'

run_runner duplicate_executable_row 'not the one executable llama-server row' \
    QWEN_CENSUS_PRODUCTION_SERVER="$duplicate_root/bin/llama-server"

run_runner instrumented_executable_row 'the instrumented server is not the one executable llama-server row' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_mismatch_root/bin/llama-server"

run_runner instrumented_forced_tail 'natural-boundary-v1 is required' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_forced_tail_root/bin/llama-server"

run_runner scoreboard_tuple \
    'a tuple other than the one the registry and ledger resolve now' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_batch/identity-check.tsv"

run_runner scoreboard_profile 'campaign inputs state a profile' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_profile/identity-check.tsv"

run_runner scoreboard_models_absent 'carries no readable models-resolved\.tsv' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_no_models/identity-check.tsv"

run_runner scoreboard_server_row 'does not carry one accepted server row' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_foreign/identity-check.tsv"

active_fixture=completion
printf 'run_raven2_vulkan_kernel_census_preflight=accepted cases=%s\n' "$run_index"
