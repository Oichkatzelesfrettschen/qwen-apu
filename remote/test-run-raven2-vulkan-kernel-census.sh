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
# digest, the rule bind_server applies, so the embedded role string decides
# both; the runner reads the compiler identity from the ELF .comment section,
# so each stub is compiled rather than written as a shell script.
write_server() {
    server_root=$1
    server_body=$2
    mkdir -p "$server_root/bin"
    printf 'const char *role = "%s";\nint main(void) { return 1; }\n' "$server_body" \
        >"$server_root/llama-server.c"
    "${CC:-cc}" -o "$server_root/bin/llama-server" "$server_root/llama-server.c"
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
    printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
    printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
    printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
    printf 'compiler_flags\t-march=znver1 -mtune=znver1\n'
    printf 'cmake_flags\t-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON\n'
} >"$production_root/artifact-manifest.tsv"
{
    printf 'executable\tllama-server\t%s\t%s\n' "$instrumented_bytes" "$instrumented_sha256"
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
    printf 'instrumentation\tpipeline-census-v3\n'
    printf 'serving_eligible\tno\n'
    printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
    printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
    printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
    printf 'compiler_flags\t-march=znver1 -mtune=znver1\n'
    printf 'cmake_flags\t-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DGGML_VULKAN_PIPELINE_CENSUS=ON\n'
    printf 'candidate_series\tllama-vulkan-pipeline-census.patch\n'
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
    printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
    printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
    printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
    printf 'compiler_flags\t-march=znver1 -mtune=znver1\n'
    printf 'cmake_flags\t-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON\n'
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
    printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
    printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
    printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
    printf 'compiler_flags\t-march=znver1 -mtune=znver1\n'
    printf 'cmake_flags\t-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DGGML_VULKAN_PIPELINE_CENSUS=ON\n'
    printf 'candidate_series\tllama-vulkan-pipeline-census.patch\n'
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
    printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
    printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
    printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
    printf 'compiler_flags\t-march=znver1 -mtune=znver1\n'
    printf 'cmake_flags\t-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DGGML_VULKAN_PIPELINE_CENSUS=ON\n'
    printf 'candidate_series\tllama-vulkan-pipeline-census.patch\n'
} >"$instrumented_forced_tail_root/artifact-manifest.tsv"

# The FCLK telemetry states: sysfs reports every attribute at one page in
# stat, so the runner reads the attribute, and only a readable attribute
# whose read returns nothing earns the SMU10 allowance.
drm_empty=$temporary_directory/drm-empty
mkdir -p "$drm_empty"
: >"$drm_empty/pp_dpm_fclk"
drm_absent=$temporary_directory/drm-absent
mkdir -p "$drm_absent"
drm_unreadable=$temporary_directory/drm-unreadable
mkdir -p "$drm_unreadable"
printf '0: 933Mhz\n' >"$drm_unreadable/pp_dpm_fclk"
chmod 000 "$drm_unreadable/pp_dpm_fclk"
# A read that fails after the readability test passes: a directory is
# readable by mode and cat refuses it, on every UID.
drm_read_failure=$temporary_directory/drm-read-failure
mkdir -p "$drm_read_failure/pp_dpm_fclk"
drm_populated=$temporary_directory/drm-populated
mkdir -p "$drm_populated"
printf '0: 933Mhz *\n1: 1067Mhz\n' >"$drm_populated/pp_dpm_fclk"

# An instrumented tree built from another llama.cpp commit, one whose CMake
# delta carries a second flag, one without the census flag, and a production
# manifest whose eligibility
# value carries a trailing word, which word splitting once read as yes.
instrumented_foreign_commit_root=$temporary_directory/inst-foreign-commit
mkdir -p "$instrumented_foreign_commit_root/bin"
cp -- "$instrumented_server" "$instrumented_foreign_commit_root/bin/llama-server"
chmod +x "$instrumented_foreign_commit_root/bin/llama-server"
sed -e 's/^commit\t.*/commit\t0000000000000000000000000000000000000000/' \
    "$instrumented_root/artifact-manifest.tsv" >"$instrumented_foreign_commit_root/artifact-manifest.tsv"
instrumented_wide_delta_root=$temporary_directory/inst-wide-delta
mkdir -p "$instrumented_wide_delta_root/bin"
cp -- "$instrumented_server" "$instrumented_wide_delta_root/bin/llama-server"
chmod +x "$instrumented_wide_delta_root/bin/llama-server"
sed -e 's/-DGGML_VULKAN_PIPELINE_CENSUS=ON/-DGGML_VULKAN_PIPELINE_CENSUS=ON -DGGML_LTO=ON/' \
    "$instrumented_root/artifact-manifest.tsv" >"$instrumented_wide_delta_root/artifact-manifest.tsv"
instrumented_no_census_flag_root=$temporary_directory/inst-no-census-flag
mkdir -p "$instrumented_no_census_flag_root/bin"
cp -- "$instrumented_server" "$instrumented_no_census_flag_root/bin/llama-server"
chmod +x "$instrumented_no_census_flag_root/bin/llama-server"
sed -e 's/ -DGGML_VULKAN_PIPELINE_CENSUS=ON//' \
    "$instrumented_root/artifact-manifest.tsv" >"$instrumented_no_census_flag_root/artifact-manifest.tsv"
production_word_split_root=$temporary_directory/prod-word-split
mkdir -p "$production_word_split_root/bin"
cp -- "$production_server" "$production_word_split_root/bin/llama-server"
chmod +x "$production_word_split_root/bin/llama-server"
sed -e 's/^serving_eligible\tyes$/serving_eligible\tyes extra/' \
    "$production_root/artifact-manifest.tsv" >"$production_word_split_root/artifact-manifest.tsv"

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

# The contract digest an attribution is held to comes from the runner's own
# print mode over the same fixtures, so the receipt states the digest the
# runner computes rather than a transcription of its rows.
contract_output=$(env -i \
    PATH="$execution_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$drm_empty" \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$runner" "$model_id" "$temporary_directory/out-contract")
printf '%s\n' "$contract_output" | grep -q '^contract	pipeline-census-calibration-v1$'
contract_sha256=$(printf '%s\n' "$contract_output" | awk -F'\t' '$1 == "calibration_contract_sha256" { print $2 }')
[ -n "$contract_sha256" ]
printf 'contract_print=accepted sha256=%s\n' "$contract_sha256"

write_calibration_inputs() {
    calibration_inputs_path=$1
    bound_production=$2
    bound_contract=${3:-$contract_sha256}
    {
        printf 'census_mode\tcalibration\n'
        printf 'production_server_sha256\t%s\n' "$bound_production"
        printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256"
        printf 'calibration_contract_sha256\t%s\n' "$bound_contract"
    } >"$calibration_inputs_path"
}

calibration_receipt=$temporary_directory/calibration
mkdir -p "$calibration_receipt"
write_terminal_state "$calibration_receipt/terminal-state.tsv" 3
write_calibration_inputs "$calibration_receipt/inputs.tsv" "$production_sha256"

calibration_foreign_contract=$temporary_directory/calibration-foreign-contract
cp -R -- "$calibration_receipt" "$calibration_foreign_contract"
write_calibration_inputs "$calibration_foreign_contract/inputs.tsv" "$production_sha256" "$foreign_sha256"

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
    # QWEN_TEST_PRIVILEGE_DROP, when given as an override, names a command
    # prefix that drops to an unprivileged identity ahead of the runner.
    privilege_drop=''
    for override in "$@"; do
        case $override in
            QWEN_TEST_PRIVILEGE_DROP=*) privilege_drop=${override#QWEN_TEST_PRIVILEGE_DROP=} ;;
        esac
    done
    # shellcheck disable=SC2086
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$drm_empty" \
        "$@" \
        $privilege_drop \
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

# The same servers under another sidecar period yield another contract, and
# a receipt carrying another digest is refused by the one comparison.
run_runner calibration_contract_differs 'calibration contract differs from the receipt' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_foreign_contract" \
    QWEN_CENSUS_ARMS=I1

run_runner calibration_contract_period 'calibration contract differs from the receipt' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_receipt" \
    QWEN_CENSUS_ARMS=I1 \
    QWEN_CENSUS_SIDECAR_PERIOD_MS=5

run_runner duplicate_executable_row 'not the one executable llama-server row' \
    QWEN_CENSUS_PRODUCTION_SERVER="$duplicate_root/bin/llama-server"

run_runner instrumented_executable_row 'the instrumented server is not the one executable llama-server row' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_mismatch_root/bin/llama-server"

run_runner instrumented_forced_tail 'natural-boundary-v1 is required' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_forced_tail_root/bin/llama-server"

run_runner fclk_absent 'pp_dpm_fclk is absent' \
    QWEN_DRM_DEVICE="$drm_absent"

# Mode 000 refuses nothing to UID 0, so a gate running as root drops to an
# unprivileged identity for this one case where setpriv exists and reports
# the case not run otherwise; the runtime contract stays as it is.
if [ "$(id -u)" -ne 0 ]; then
    run_runner fclk_unreadable 'pp_dpm_fclk is unreadable' \
        QWEN_DRM_DEVICE="$drm_unreadable"
elif command -v setpriv >/dev/null 2>&1; then
    chmod 755 "$temporary_directory" "$drm_unreadable"
    run_runner fclk_unreadable 'pp_dpm_fclk is unreadable' \
        QWEN_DRM_DEVICE="$drm_unreadable" \
        QWEN_TEST_PRIVILEGE_DROP='setpriv --reuid=65534 --regid=65534 --clear-groups'
else
    printf 'fclk_unreadable=not_run reason=uid_0_without_setpriv\n'
fi

run_runner fclk_read_failure 'pp_dpm_fclk read failed' \
    QWEN_DRM_DEVICE="$drm_read_failure"

run_runner fclk_populated "$reached_preflight_end" \
    QWEN_DRM_DEVICE="$drm_populated"

run_runner base_build_commit 'descend from different base builds' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_foreign_commit_root/bin/llama-server"

run_runner cmake_wide_delta 'descend from different base builds' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_wide_delta_root/bin/llama-server"

run_runner cmake_missing_census_flag 'CMake delta against production must be exactly' \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_no_census_flag_root/bin/llama-server"

run_runner eligibility_word_split 'serving_eligible other than exactly yes' \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_word_split_root/bin/llama-server"

run_runner scoreboard_tuple \
    'a tuple other than the one the registry and ledger resolve now' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_batch/identity-check.tsv"

run_runner scoreboard_profile 'campaign inputs state a profile' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_profile/identity-check.tsv"

run_runner scoreboard_models_absent 'carries no readable models-resolved\.tsv' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_no_models/identity-check.tsv"

run_runner scoreboard_server_row 'does not carry one accepted server row' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_foreign/identity-check.tsv"

# A terminating signal ends the arm rather than the sampler alone. The runner
# installs cleanup_children on TERM ahead of the arm loop and runs the served
# runner as a background job under wait, so a TERM delivered mid-arm reaches
# both children at once. This section drives one arm far enough to hold a
# sampling sidecar beside a live served child, signals the runner, and reads
# the two pids and the clock record afterwards.
#
# The runner is copied into a scratch directory because it resolves
# measure-served-decode.sh, the registry reader, and the census readers
# through its own directory: the fake served runner placed there is what
# makes an arm last long enough to signal. The registry reader and its
# ledgers are linked from the tree, and the artifact ledger is copied,
# because the runner refuses a linked ledger by its own -L test.
active_fixture=signal_cleanup
signal_directory=$temporary_directory/signal
mkdir -p "$signal_directory"
signal_runner=$signal_directory/run-raven2-vulkan-kernel-census.sh
cp -- "$runner" "$signal_runner"
chmod +x "$signal_runner"
cp -- "$artifact_ledger" "$signal_directory/model-artifacts.tsv"
for linked_member in model-registry.sh models.tsv ctx-checkpoints.tsv \
    validated-tuples.tsv quarantine.tsv draft-pairs.tsv \
    summarize-kernel-census.py summarize-census-controls.py \
    sample-clock-sidecar.py validate-clock-sidecar.py \
    summarize-perf-logger-slice.py; do
    ln -s -- "$script_directory/$linked_member" "$signal_directory/$linked_member"
done

# The served runner the arm launches: it records its own pid inside the arm
# directory, answers TERM with 143, and sleeps in fifth-of-a-second steps, so
# the trap runs at the signal where a single foreground sleep of two minutes
# would defer it and hold cleanup_children in its own wait.
cat >"$signal_directory/measure-served-decode.sh" <<'FAKE_SERVED_RUNNER'
#!/bin/sh
set -eu
printf '%s\n' "$$" >"$QWEN_RESULT_DIRECTORY/fake.pid"
trap 'exit 143' TERM
served_iterations=0
while [ "$served_iterations" -lt 600 ]; do
    sleep 0.2
    served_iterations=$((served_iterations + 1))
done
FAKE_SERVED_RUNNER
chmod +x "$signal_directory/measure-served-decode.sh"

# The preflight ends at the host name and the inherited session, so this one
# case supplies both: a hostname earlier on PATH than the system's own and a
# structurally valid SSH_CONNECTION.
signal_bin=$temporary_directory/signal-bin
mkdir -p "$signal_bin"
cat >"$signal_bin/hostname" <<'FAKE_HOSTNAME'
#!/bin/sh
printf 'hp14-dk1xxx\n'
FAKE_HOSTNAME
chmod +x "$signal_bin/hostname"
signal_path=$signal_bin:$execution_path
signal_ssh_connection='127.0.0.1 40000 127.0.0.1 22'

# sample-clock-sidecar.py reads a starred DPM line for each clock,
# gpu_busy_percent beside them, and temp1_input under the hwmon whose name
# reads amdgpu, so each is present with plausible content. pp_dpm_fclk stays
# empty, which is the SMU10 state the runner's unavailable-column allowance
# covers and the state the calibration contract records.
signal_drm=$temporary_directory/drm-signal
mkdir -p "$signal_drm"
printf '0: 200Mhz\n1: 1100Mhz *\n' >"$signal_drm/pp_dpm_sclk"
printf '0: 933Mhz *\n1: 1067Mhz\n' >"$signal_drm/pp_dpm_mclk"
: >"$signal_drm/pp_dpm_fclk"
printf '37\n' >"$signal_drm/gpu_busy_percent"
signal_hwmon=$temporary_directory/hwmon-signal
mkdir -p "$signal_hwmon/hwmon0"
printf 'amdgpu\n' >"$signal_hwmon/hwmon0/name"
printf '61000\n' >"$signal_hwmon/hwmon0/temp1_input"

# The first calibration arm runs with its sidecar off, so the arm that holds
# a sampler comes from an attribution naming I0. Its receipt must carry the
# digest of the contract this environment computes, and the DRM device and
# the sampler's core are both contract rows, so the print invocation carries
# exactly the QWEN_DRM_DEVICE and QWEN_CENSUS_SIDECAR_CPU values the signal
# run does. The core is 0 because a workstation reaching this test is the
# only machine that runs it and CPU 1 is the appliance's own choice.
signal_contract_sha256=$(env -i \
    PATH="$signal_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$signal_drm" \
    QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$signal_runner" "$model_id" "$temporary_directory/out-signal-contract" \
    | awk -F'\t' '$1 == "calibration_contract_sha256" { print $2 }')
[ -n "$signal_contract_sha256" ]
signal_calibration=$temporary_directory/calibration-signal
mkdir -p "$signal_calibration"
write_terminal_state "$signal_calibration/terminal-state.tsv" 3
write_calibration_inputs "$signal_calibration/inputs.tsv" "$production_sha256" \
    "$signal_contract_sha256"

signal_output=$temporary_directory/out-signal
signal_arm_directory=$signal_output/arms/01-I0
signal_record=$signal_arm_directory/clock-sidecar.tsv
signal_served_pid_file=$signal_arm_directory/fake.pid
signal_stderr=$temporary_directory/signal-stderr.txt
diagnostic_file=$signal_stderr
env -i \
    PATH="$signal_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$signal_drm" \
    QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_HWMON_ROOT="$signal_hwmon" \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$signal_calibration" \
    QWEN_CENSUS_ARMS=I0 \
    QWEN_CENSUS_COOLDOWN_S=0 \
    SSH_CONNECTION="$signal_ssh_connection" \
    "$signal_runner" "$model_id" "$signal_output" \
    >"$temporary_directory/signal-stdout.txt" 2>"$signal_stderr" &
signal_runner_pid=$!

# The arm holds once the served child has recorded its pid and the sampler
# has flushed data rows; the sampler flushes on its own buffer at about a
# second, so the wait is bounded rather than instantaneous.
signal_poll=0
signal_arm_poll_bound=100
while [ "$signal_poll" -lt "$signal_arm_poll_bound" ]; do
    if [ -r "$signal_served_pid_file" ] && [ -r "$signal_record" ] \
        && [ "$(grep -c '^[0-9]' "$signal_record" || true)" -ge 3 ]; then
        break
    fi
    sleep 0.2
    signal_poll=$((signal_poll + 1))
done
if [ "$signal_poll" -ge "$signal_arm_poll_bound" ]; then
    kill -TERM "$signal_runner_pid" 2>/dev/null || true
    wait "$signal_runner_pid" 2>/dev/null || true
    printf 'the signal case reached no sampling arm inside %s seconds\n' \
        "$((signal_arm_poll_bound / 5))" >&2
    if [ -r "$signal_arm_directory/clock-sidecar.stderr" ]; then
        sed -n '1,20p' "$signal_arm_directory/clock-sidecar.stderr" >&2
    fi
    exit 1
fi

signal_sampler_pid=$(sed -n 's/^# sampler_pid=\([0-9][0-9]*\) .*/\1/p' "$signal_record")
[ -n "$signal_sampler_pid" ]
signal_served_pid=$(cat -- "$signal_served_pid_file")
[ -n "$signal_served_pid" ]
kill -TERM "$signal_runner_pid"
set +e
wait "$signal_runner_pid"
signal_status=$?
set -e
if [ "$signal_status" -ne 143 ]; then
    printf 'the signalled runner exited %s where its TERM trap exits 143\n' \
        "$signal_status" >&2
    exit 1
fi

# Status 143 is what an untrapped TERM reports as well, so the claim rests on
# the two children: the sampler leaves and its record stops growing, and the
# served child leaves rather than sleeping out its two minutes.
signal_poll=0
signal_exit_poll_bound=25
while [ "$signal_poll" -lt "$signal_exit_poll_bound" ] \
    && kill -0 "$signal_sampler_pid" 2>/dev/null; do
    sleep 0.2
    signal_poll=$((signal_poll + 1))
done
if kill -0 "$signal_sampler_pid" 2>/dev/null; then
    printf 'the clock sidecar %s survives the signalled runner\n' \
        "$signal_sampler_pid" >&2
    kill -TERM "$signal_sampler_pid" 2>/dev/null || true
    exit 1
fi
if kill -0 "$signal_served_pid" 2>/dev/null; then
    printf 'the served runner child %s survives the signalled runner\n' \
        "$signal_served_pid" >&2
    kill -TERM "$signal_served_pid" 2>/dev/null || true
    exit 1
fi
signal_record_bytes=$(wc -c <"$signal_record" | tr -d ' ')
sleep 1
signal_record_bytes_after=$(wc -c <"$signal_record" | tr -d ' ')
if [ "$signal_record_bytes_after" != "$signal_record_bytes" ]; then
    printf 'the clock record grew from %s to %s bytes after the runner exited\n' \
        "$signal_record_bytes" "$signal_record_bytes_after" >&2
    exit 1
fi
diagnostic_file=
printf 'signal_cleanup=accepted sampler_pid=%s served_pid=%s record_bytes=%s\n' \
    "$signal_sampler_pid" "$signal_served_pid" "$signal_record_bytes"

active_fixture=completion
printf 'run_raven2_vulkan_kernel_census_preflight=accepted cases=%s\n' "$run_index"
