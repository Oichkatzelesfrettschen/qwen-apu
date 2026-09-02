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
#
# The executing cases at the end supply both, and the stub validator's clock
# table is what drives the regime precondition without a device.
# regime_settles_at_three admits four warmups and settles on the third, which
# is the one that agrees with its predecessor inside the band, and requires the
# fourth to stay unrun; regime_unreached steps the four apart, withholds one
# clock_state line, and pins one at a share of 0.62, so the precondition spends
# its cap, records no regime, and leaves every named arm without a distance to
# one while the warmups stay out of every pair, receipt, and numbered slot;
# regime_share_window runs the 20260902T1417Z shape three ways -- two warmups
# agreeing at 1100 MHz at boost shares settle nothing, the same agreement at
# 0.13 settles at once, and raising the ceiling past the boost share settles
# the pair the default refused -- so the ceiling rather than the band is what
# separates the regimes; truncated_reply cuts one reply mid-object and requires
# the arm to record the unknown triple rather than the campaign to end inside
# it.

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
runtime_remote=$temporary_directory/remote
mkdir -p "$runtime_remote"
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    printf '#!/bin/sh\nexit 1\n' >"$runtime_remote/$runtime_script"
    chmod +x "$runtime_remote/$runtime_script"
done
# The sync writes runtime-tree-manifest.tsv beside remote/, and the runner
# binds its head and payload digests into the contract; a tree without one
# is refused.
runtime_tree_manifest=$temporary_directory/runtime-tree-manifest.tsv
printf 'git_head\t%s\nremote_payload_tree_sha256\t%s\npatches_payload_tree_sha256\t%s\n' \
    "$patch_series_sha256" "$foreign_sha256" "$registry_sha256" >"$runtime_tree_manifest"
runtime_remote_unmanifested=$temporary_directory/unmanifested/remote
mkdir -p "$runtime_remote_unmanifested"
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    cp -- "$runtime_remote/$runtime_script" "$runtime_remote_unmanifested/$runtime_script"
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

# The sampler the broker path launches per arm. telemetry-broker opens its
# surfaces, prints one readiness line on stderr, samples until SIGTERM, and
# formats the record at drain; the stub reproduces the launch contract the
# runner depends on -- the readiness line and the answer to TERM -- and leaves
# the device out. QWEN_TEST_BROKER_SILENT withholds the line, which is the
# state the runner reads as a sampler that never started, and the stub is one
# file under both settings so its digest holds the acquisition contract
# constant across the cases that reuse a brick.
broker_stub=$temporary_directory/telemetry-broker
cat >"$broker_stub" <<'BROKER_STUB'
#!/bin/sh
set -eu
if [ "${QWEN_TEST_BROKER_SILENT:-0}" != 1 ]; then
    printf 'telemetry_broker=ready pid=%s period_ns=10000000 nice=19 cpu_affinity=0 ring_samples=1 ring_bytes=40\n' \
        "$$" >&2
fi
trap 'exit 0' TERM
broker_iterations=0
while [ "$broker_iterations" -lt 600 ]; do
    sleep 0.2
    broker_iterations=$((broker_iterations + 1))
done
BROKER_STUB
chmod +x "$broker_stub"
broker_stub_sha256=$(server_digest "$broker_stub")
broker_source_sha256=$(server_digest "$script_directory/telemetry-broker.c")
broker_absent=$temporary_directory/telemetry-broker-absent

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
        printf 'server_io_class\tidle\nbackend_sampling\t0\nlatency_mode\tobserve\nweb_broker\t0\nimage_service\t0\n'
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

# A scoreboard that ran with backend sampling on states a denominator the
# arms here do not reproduce, so a receipt whose inputs omit or contradict
# that row is refused the way a wrong profile is.
scoreboard_no_backend_sampling=$temporary_directory/scoreboard-no-backend-sampling
cp -R -- "$scoreboard_receipt" "$scoreboard_no_backend_sampling"
grep -v '^backend_sampling' "$scoreboard_receipt/campaign-inputs.tsv" \
    >"$scoreboard_no_backend_sampling/campaign-inputs.tsv"
# A second vulkan_profile row naming another profile leaves the expected row
# in place, so a presence check would admit a receipt that states two
# profiles; the count-per-key rule refuses it.
scoreboard_duplicate_row=$temporary_directory/scoreboard-duplicate-row
cp -R -- "$scoreboard_receipt" "$scoreboard_duplicate_row"
printf 'vulkan_profile\tlow-serialized\n' \
    >>"$scoreboard_duplicate_row/campaign-inputs.tsv"
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
        printf 'control_unresolved=0\n'
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
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$runner" "$model_id" "$temporary_directory/out-contract")
printf '%s\n' "$contract_output" | grep -q '^contract	pipeline-census-calibration-v1$'
printf '%s\n' "$contract_output" | grep -q '^contract	pipeline-census-analysis-v1$'
contract_sha256=$(printf '%s\n' "$contract_output" | awk -F'\t' '$1 == "calibration_contract_sha256" { print $2 }')
[ -n "$contract_sha256" ]
# The two contracts are separate values and the alias is the acquisition
# digest under its former name, so the print states three digests and two of
# them are equal.
acquisition_sha256=$(printf '%s\n' "$contract_output" | awk -F'\t' '$1 == "acquisition_contract_sha256" { print $2 }')
analysis_sha256=$(printf '%s\n' "$contract_output" | awk -F'\t' '$1 == "analysis_contract_sha256" { print $2 }')
[ -n "$acquisition_sha256" ] && [ -n "$analysis_sha256" ]
if [ "$acquisition_sha256" != "$contract_sha256" ]; then
    printf 'calibration_contract_sha256 %s is no alias of acquisition %s\n' \
        "$contract_sha256" "$acquisition_sha256" >&2
    exit 1
fi
if [ "$analysis_sha256" = "$acquisition_sha256" ]; then
    printf 'the analysis contract digest equals the acquisition digest\n' >&2
    exit 1
fi
# The analysis contract names the four readers in fixed order, so the digest
# of the last one is the digest of summarize-census-controls.py.
if ! printf '%s\n' "$contract_output" | grep -q "^summarize-census-controls.py	$(sha256sum "$script_directory/summarize-census-controls.py" | cut -d ' ' -f 1)$"; then
    printf 'the analysis contract does not carry the controls summarizer digest\n' >&2
    exit 1
fi
printf 'contract_print=accepted acquisition=%s analysis=%s\n' \
    "$acquisition_sha256" "$analysis_sha256"

# The sampler is an acquisition input rather than a reader, so the contract
# names the program that produced a record beside the digests of the
# executable and the source it was built from. An invocation naming no sampler
# takes the broker.
active_fixture=sampler_default_broker
if ! printf '%s\n' "$contract_output" | grep -q '^sidecar_implementation	telemetry-broker$'; then
    printf 'the default sampler is not the telemetry broker\n' >&2
    exit 1
fi
if ! printf '%s\n' "$contract_output" | grep -q "^sidecar_binary_sha256	$broker_stub_sha256\$"; then
    printf 'the contract carries no broker executable digest\n' >&2
    exit 1
fi
if ! printf '%s\n' "$contract_output" | grep -q "^sidecar_source_sha256	$broker_source_sha256\$"; then
    printf 'the contract carries no telemetry-broker.c digest\n' >&2
    exit 1
fi
printf 'sampler_default_broker=accepted binary=%s\n' "$broker_stub_sha256"

# QWEN_CENSUS_SAMPLER=python restores the invocation the runner carried
# before the broker: the row shape holds and both digests read `-`, since a
# Python sampler is the reader the analysis contract already names.
active_fixture=sampler_python_contract
python_contract_output=$(env -i \
    PATH="$execution_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$drm_empty" \
    QWEN_CENSUS_BROKER="$broker_absent" \
    QWEN_CENSUS_SAMPLER=python \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$runner" "$model_id" "$temporary_directory/out-contract-python")
if ! printf '%s\n' "$python_contract_output" \
    | grep -q '^sidecar_implementation	sample-clock-sidecar.py$'; then
    printf 'QWEN_CENSUS_SAMPLER=python names another implementation\n' >&2
    exit 1
fi
if ! printf '%s\n' "$python_contract_output" | grep -q '^sidecar_binary_sha256	-$'; then
    printf 'the Python sampler contract carries a binary digest\n' >&2
    exit 1
fi
if ! printf '%s\n' "$python_contract_output" | grep -q '^sidecar_source_sha256	-$'; then
    printf 'the Python sampler contract carries a source digest\n' >&2
    exit 1
fi
python_contract_sha256=$(printf '%s\n' "$python_contract_output" \
    | awk -F'\t' '$1 == "acquisition_contract_sha256" { print $2 }')
if [ "$python_contract_sha256" = "$acquisition_sha256" ]; then
    printf 'the two samplers share one acquisition contract digest\n' >&2
    exit 1
fi
printf 'sampler_python_contract=accepted acquisition=%s\n' "$python_contract_sha256"

# The calibration arm list is generated from the replicate count rather than
# written down, so the contract print states the list a run would execute and
# the wall clock it would cost. Two replicates must generate the thirteen arms
# the retained runs recorded, or every replay of their summaries changes shape.
active_fixture=replicate_arm_list
print_contract_at_replicates() {
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$drm_empty" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_REPLICATES="$1" \
        QWEN_CENSUS_PRINT_CONTRACT=1 \
        "$runner" "$model_id" "$temporary_directory/out-contract-r$1"
}
contract_field() {
    printf '%s\n' "$1" | awk -F'\t' -v key="$2" '$1 == key { print $2 }'
}

two_replicate_contract=$(print_contract_at_replicates 2)
two_replicate_arms=$(contract_field "$two_replicate_contract" census_arms)
if [ "$two_replicate_arms" != "P-nosidecar P P P-nosidecar P I0 I0 P I0 I1 I1 I0 S" ]; then
    printf 'two replicates generate "%s" rather than the thirteen arms\n' \
        "$two_replicate_arms" >&2
    exit 1
fi
# The count carries the precondition's cap rather than one warmup, since the
# run may spend up to that many before it reaches slot 1.
if [ "$(contract_field "$two_replicate_contract" census_arm_count)" != 29 ]; then
    printf 'the thirteen arms and the sixteen warmups count %s\n' \
        "$(contract_field "$two_replicate_contract" census_arm_count)" >&2
    exit 1
fi

four_replicate_contract=$(print_contract_at_replicates 4)
expected_four_replicate_arms='P-nosidecar P P P-nosidecar P-nosidecar P P P-nosidecar P I0 I0 P P I0 I0 P I0 I1 I1 I0 I0 I1 I1 I0 S'
four_replicate_arms=$(contract_field "$four_replicate_contract" census_arms)
if [ "$four_replicate_arms" != "$expected_four_replicate_arms" ]; then
    printf 'four replicates generate "%s" rather than "%s"\n' \
        "$four_replicate_arms" "$expected_four_replicate_arms" >&2
    exit 1
fi
if [ "$(contract_field "$four_replicate_contract" census_arm_count)" != 41 ]; then
    printf 'the four-replicate list and the sixteen warmups count %s\n' \
        "$(contract_field "$four_replicate_contract" census_arm_count)" >&2
    exit 1
fi
if [ "$(contract_field "$four_replicate_contract" census_replicates)" != 4 ]; then
    printf 'the contract print states another replicate count\n' >&2
    exit 1
fi
# Four replicates are the default, so an invocation naming none prints the
# same list.
if [ "$(contract_field "$contract_output" census_arms)" != "$expected_four_replicate_arms" ]; then
    printf 'the default replicate count generates another arm list\n' >&2
    exit 1
fi
# The arm list is campaign shape rather than an acquisition setting: an
# attribution runs I1 alone against the calibration's own contract digest, so
# a replicate count that moved that digest would refuse every attribution.
if [ "$(contract_field "$two_replicate_contract" acquisition_contract_sha256)" \
    != "$acquisition_sha256" ]; then
    printf 'the replicate count moved the acquisition contract digest\n' >&2
    exit 1
fi
# The wall clock is bounded from the per-arm ceiling plus the quiescence
# deadline: 19 seconds of launch, request, and teardown against the default
# 30-second cooldown over every arm the run executes.
if [ "$(contract_field "$four_replicate_contract" predicted_arm_duration_s)" != 49 ]; then
    printf 'the predicted arm duration is not 19 seconds plus the cooldown\n' >&2
    exit 1
fi
if [ "$(contract_field "$two_replicate_contract" predicted_campaign_duration_s)" != 1421 ]; then
    printf 'the two-replicate campaign is predicted at %s seconds of 1421\n' \
        "$(contract_field "$two_replicate_contract" predicted_campaign_duration_s)" >&2
    exit 1
fi
if [ "$(contract_field "$four_replicate_contract" predicted_campaign_duration_s)" != 2009 ]; then
    printf 'the four-replicate campaign is predicted at %s seconds of 2009\n' \
        "$(contract_field "$four_replicate_contract" predicted_campaign_duration_s)" >&2
    exit 1
fi
# The brick partition is the index the campaign runs on, so it follows the
# generated list rather than the thirteen slots the first calibrations used:
# each control brick holds twice the replicate count in slots and the identity
# arm takes the one after the third.
brick_partition_row() {
    printf '%s\n' "$1" | awk -F'\t' -v brick="$2" \
        '$1 == "census_brick" && $2 == brick { print $3 "\t" $4 "\t" $5 }'
}
for replicate_expectation in "2 4 13" "4 8 25"; do
    # shellcheck disable=SC2086
    set -- $replicate_expectation
    replicate_count=$1
    brick_slot_width=$2
    identity_slot=$3
    replicate_contract=$(print_contract_at_replicates "$replicate_count")
    if [ "$(brick_partition_row "$replicate_contract" C0)" \
        != "$(printf 'sidecar\t1\t%s' "$brick_slot_width")" ]; then
        printf 'C0 is not the sidecar control at slot 1 over %s slots: %s\n' \
            "$brick_slot_width" "$(brick_partition_row "$replicate_contract" C0)" >&2
        exit 1
    fi
    if [ "$(brick_partition_row "$replicate_contract" C1)" \
        != "$(printf 'compile\t%s\t%s' "$((brick_slot_width + 1))" "$brick_slot_width")" ]; then
        printf 'C1 does not follow C0 over %s slots: %s\n' \
            "$brick_slot_width" "$(brick_partition_row "$replicate_contract" C1)" >&2
        exit 1
    fi
    if [ "$(brick_partition_row "$replicate_contract" C2)" \
        != "$(printf 'collect\t%s\t%s' "$((2 * brick_slot_width + 1))" "$brick_slot_width")" ]; then
        printf 'C2 does not follow C1 over %s slots: %s\n' \
            "$brick_slot_width" "$(brick_partition_row "$replicate_contract" C2)" >&2
        exit 1
    fi
    if [ "$(brick_partition_row "$replicate_contract" C3)" \
        != "$(printf 'identity\t%s\t1' "$identity_slot")" ]; then
        printf 'C3 is not the identity arm at slot %s: %s\n' \
            "$identity_slot" "$(brick_partition_row "$replicate_contract" C3)" >&2
        exit 1
    fi
    # The three control bricks and the identity arm cover the generated list
    # exactly, so the partition and the arm count are one statement.
    replicate_arm_count=$(contract_field "$replicate_contract" census_arm_count)
    if [ "$((3 * brick_slot_width + 1))" -ne "$((replicate_arm_count - 16))" ]; then
        printf 'the partition covers %s slots against an arm list of %s\n' \
            "$((3 * brick_slot_width + 1))" "$replicate_arm_count" >&2
        exit 1
    fi
done
printf 'replicate_arm_list=accepted two=29 four=41 predicted_s=2009\n'
printf 'replicate_brick_partition=accepted identity_slot_two=13 identity_slot_four=25\n'

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
        QWEN_CENSUS_BROKER="$broker_stub" \
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

run_runner mode_name 'QWEN_CENSUS_MODE must be calibration, attribution, or canary' \
    QWEN_CENSUS_MODE=bogus

run_runner sampler_name 'QWEN_CENSUS_SAMPLER must be broker or python' \
    QWEN_CENSUS_SAMPLER=bogus

# An absent broker is built rather than refused, so the refusal belongs to the
# build: CC names no compiler, build-telemetry-broker.sh ends on its own
# command -v test, and the preflight reports the executable it still lacks.
run_runner broker_build_failure \
    'the telemetry broker is absent and its build failed' \
    QWEN_CENSUS_BROKER="$broker_absent" \
    CC=/nonexistent/cc

run_runner calibration_arm_list 'a calibration runs exactly' \
    QWEN_CENSUS_ARMS=I1

# A replicate count is even and runs from 2 through 8, since every two
# replicates are one mirrored quadruple.
run_runner replicate_count_odd 'QWEN_CENSUS_REPLICATES is an even count from 2 through 8' \
    QWEN_CENSUS_REPLICATES=3
run_runner replicate_count_high 'QWEN_CENSUS_REPLICATES is an even count from 2 through 8' \
    QWEN_CENSUS_REPLICATES=10
run_runner replicate_count_one 'QWEN_CENSUS_REPLICATES is an even count from 2 through 8' \
    QWEN_CENSUS_REPLICATES=1

# A canary is its own mode rather than a short calibration: it fixes its own
# four-arm list and refuses another.
run_runner canary_default "$reached_preflight_end" \
    QWEN_CENSUS_MODE=canary

run_runner canary_arm_list 'a canary runs exactly' \
    QWEN_CENSUS_MODE=canary \
    QWEN_CENSUS_ARMS=I1

# The bricks partition a calibration's thirteen arms, so no other mode holds
# one to reuse.
run_runner reuse_outside_calibration 'QWEN_CENSUS_REUSE_BRICKS belongs to a calibration' \
    QWEN_CENSUS_MODE=canary \
    QWEN_CENSUS_REUSE_BRICKS="$temporary_directory/calibration"

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

# A reuse directory is read whole: the ledger its bricks were echoed from
# must be there, and its acquisition contract must be this run's, since a
# brick measured under another contract measures another campaign.
reuse_no_ledger=$temporary_directory/reuse-no-ledger
mkdir -p "$reuse_no_ledger"
write_calibration_inputs "$reuse_no_ledger/inputs.tsv" "$production_sha256"
run_runner reuse_ledger_absent 'carries no readable arms\.tsv' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_no_ledger"

reuse_foreign_contract=$temporary_directory/reuse-foreign-contract
mkdir -p "$reuse_foreign_contract"
write_calibration_inputs "$reuse_foreign_contract/inputs.tsv" "$production_sha256" \
    "$foreign_sha256"
: >"$reuse_foreign_contract/arms.tsv"
run_runner reuse_foreign_contract 'ran under acquisition contract' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_foreign_contract"

reuse_no_status=$temporary_directory/reuse-no-status
mkdir -p "$reuse_no_status"
write_calibration_inputs "$reuse_no_status/inputs.tsv" "$production_sha256"
printf 'slot\tarm\ttok_s\tstate\n' >"$reuse_no_status/arms.tsv"
run_runner reuse_ledger_without_status 'names no status column' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_no_status"

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

run_runner runtime_tree_unmanifested 'carries no readable runtime-tree-manifest.tsv' \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote_unmanifested"

run_runner scoreboard_backend_sampling 'campaign inputs state a profile' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_no_backend_sampling/identity-check.tsv"

run_runner scoreboard_duplicate_row 'state one of them more than once' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_duplicate_row/identity-check.tsv"

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
# The section runs the Python sampler, whose evidence is a record growing on
# disk while the arm is live; telemetry-broker formats its record at drain, so
# the same poll would read an absent file. The broker's own launch, readiness,
# and stop are covered by the sampler cases below.
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
    validated-tuples.tsv quarantine.tsv draft-pairs.tsv census-arm-lib.sh \
    summarize-kernel-census.py summarize-census-controls.py \
    sample-clock-sidecar.py validate-clock-sidecar.py \
    telemetry-broker.c build-telemetry-broker.sh \
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

# Every arm holds a sampler now that the regime precondition reads the warmup
# arms' own clock state, so the attribution's first warmup at slot 0a is where
# this case interrupts: it launches the production server under the Python
# sampler and hangs in the fake served runner, which is the pair the trap must
# reach. Its receipt must carry the
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
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_SAMPLER=python \
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
signal_arm_directory=$signal_output/arms/0a-W
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
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_SAMPLER=python \
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

# A brick is the unit reuse acts on, so a calibration whose four bricks all
# carry this run's input-closure digest runs no arm and still writes a root.
# The prior directory is synthesized here rather than measured: a run that
# executes an arm is exactly what these two cases prove absent, and the
# closure digest is recomputed by the same recipe the runner uses, so a drift
# between the two stops the reuse and the executed arm fails the case.
active_fixture=brick_reuse
brick_directory=$temporary_directory/brick
mkdir -p "$brick_directory"
cp -- "$runner" "$brick_directory/run-raven2-vulkan-kernel-census.sh"
chmod +x "$brick_directory/run-raven2-vulkan-kernel-census.sh"
brick_runner=$brick_directory/run-raven2-vulkan-kernel-census.sh
cp -- "$artifact_ledger" "$brick_directory/model-artifacts.tsv"
for linked_member in model-registry.sh models.tsv ctx-checkpoints.tsv \
    validated-tuples.tsv quarantine.tsv draft-pairs.tsv census-arm-lib.sh \
    summarize-kernel-census.py summarize-census-controls.py \
    sample-clock-sidecar.py \
    telemetry-broker.c build-telemetry-broker.sh \
    summarize-perf-logger-slice.py; do
    ln -s -- "$script_directory/$linked_member" "$brick_directory/$linked_member"
done
# The sidecar validator stands in for itself: it runs the tree's own reader on
# every case, and under QWEN_TEST_CLOCK_STATE it answers with one accepted
# record naming a chosen selected graphics clock, which is what puts a
# clock_state line in front of the runner where no device sampled one. The
# delegating default keeps the refusal the silent-broker case reads.
cat >"$brick_directory/validate-clock-sidecar.py" <<VALIDATOR_STUB
#!/usr/bin/env python3
import os
import runpy
import sys

state = os.environ.get("QWEN_TEST_CLOCK_STATE", "")
share = os.environ.get("QWEN_TEST_CLOCK_SHARE", "0.1400")
# A per-arm table overrides the run-wide state, keyed by the arm directory's
# own label, and each entry is a mode or a mode and its modal share separated
# by a colon. The word none stands for a window the validator read no clock
# state out of, which is the reading that resets the precondition's pair.
table = os.environ.get("QWEN_TEST_CLOCK_TABLE", "")
if table and os.path.exists(table):
    label = os.path.basename(os.path.dirname(sys.argv[1]))
    for line in open(table):
        name, _, value = line.rstrip("\n").partition("\t")
        if name == label:
            state, _, entry_share = value.partition(":")
            if entry_share:
                share = entry_share
if state:
    print(f"record_readable=accepted path={sys.argv[1]}")
    if state != "none":
        print(f"clock_state=measured window_samples=700 sclk_mode_mhz={state}"
              f" sclk_share={share} mclk_mode_mhz=1067"
              " temp_mean_c=71.6 temp_max_c=74.0 busy_mean=94.88")
    print("clock_sidecar=accepted failures=-")
    raise SystemExit(0)
sys.argv[0] = "$script_directory/validate-clock-sidecar.py"
runpy.run_path(sys.argv[0], run_name="__main__")
VALIDATOR_STUB
chmod +x "$brick_directory/validate-clock-sidecar.py"
# The served runner an executed arm reaches: it refuses at once, so the arm
# fails on its own runner and the cooldown that follows is what the case
# reads. The quiescence poller is stubbed because it samples a device, and
# the runner reads its printed line rather than its own clock.
# The served runner an executed arm reaches refuses at once, so the arm fails
# on its own runner and the cooldown that follows is what a case reads. One
# label named in QWEN_TEST_CENSUS_TRUNCATE instead leaves a reply cut
# mid-object, which is what a runner killed while writing leaves behind: the
# arm's reader answers the unknown triple rather than ending the campaign.
cat >"$brick_directory/measure-served-decode.sh" <<'FAKE_SERVED_RUNNER'
#!/bin/sh
set -eu
if [ "${QWEN_TEST_CENSUS_TRUNCATE:-}" = "$1" ]; then
    printf 'begin_ns\t1000000000\nend_ns\t2000000000\n' \
        >"$QWEN_RESULT_DIRECTORY/request-window.tsv"
    printf '{"timings": {"predicted_n": 65, "predi' \
        >"$QWEN_RESULT_DIRECTORY/response.json"
    exit 0
fi
exit 1
FAKE_SERVED_RUNNER
chmod +x "$brick_directory/measure-served-decode.sh"
cat >"$brick_directory/await-quiescence.sh" <<'FAKE_QUIESCENCE'
#!/bin/sh
set -eu
printf 'quiescence=timeout elapsed_ms=1234 llama_server=absent gpu_busy=0\n'
exit 1
FAKE_QUIESCENCE
chmod +x "$brick_directory/await-quiescence.sh"

brick_contract_sha256=$(env -i \
    PATH="$signal_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$signal_drm" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_CENSUS_REPLICATES=2 \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$brick_runner" "$model_id" "$temporary_directory/out-brick-contract" \
    | awk -F'\t' '$1 == "acquisition_contract_sha256" { print $2 }')
[ -n "$brick_contract_sha256" ]

brick_closure_sha256() {
    {
        printf 'acquisition_contract_sha256\t%s\n' "$brick_contract_sha256"
        printf 'brick\t%s\n' "$1"
        printf 'arms\t%s\n' "$2"
        case $1 in
            C2 | C3) printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256" ;;
        esac
    } | sha256sum | cut -d ' ' -f 1
}

write_prior_receipt() {
    prior_root=$1
    prior_brick=$2
    prior_slots=$3
    prior_arms=$4
    prior_rates=$5
    mkdir -p "$prior_root/bricks"
    {
        printf 'brick_id\t%s\n' "$prior_brick"
        printf 'arm_slots\t%s\n' "$prior_slots"
        printf 'arms\t%s\n' "$prior_arms"
        printf 'verdict\taccepted\n'
        printf 'arm_rates\t%s\n' "$prior_rates"
        printf 'input_closure_sha256\t%s\n' "$(brick_closure_sha256 "$prior_brick" "$prior_arms")"
    } >"$prior_root/bricks/$prior_brick.receipt.tsv"
}

# The rates are the ones the controls test pairs: the two replicates of each
# control carry the same delta, which is what makes a two-replicate interval
# degenerate at that delta and therefore acceptable inside its own bound, so a
# run that reuses all four bricks accepts on rows it never measured itself.
# Two replicates that differ at all open the interval past a 0.65% bound, so
# these are a fixture rather than a plausible pair of arms.
prior_arm_rows="1	P-nosidecar	10.000
2	P	9.980
3	P	9.980
4	P-nosidecar	10.000
5	P	10.000
6	I0	9.950
7	I0	9.950
8	P	10.000
9	I0	10.000
10	I1	9.850
11	I1	9.850
12	I0	10.000
13	S	3.000"

# The runner rejoins a receipt's arm_rates to the prior ledger slot by slot,
# so the receipt reads its rates out of the same rows rather than restating
# them; a case that changes the rates changes both at once.
prior_rate_range() {
    printf '%s\n' "$prior_arm_rows" | awk -F'\t' -v low="$1" -v high="$2" \
        '$1 >= low && $1 <= high { list = list (list == "" ? "" : " ") $3 } END { print list }'
}

write_prior_calibration() {
    prior_root=$1
    mkdir -p "$prior_root"
    printf 'acquisition_contract_sha256\t%s\n' "$brick_contract_sha256" \
        >"$prior_root/inputs.tsv"
    {
        printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\n'
        printf '%s\n' "$prior_arm_rows" | while IFS="$(printf '\t')" read -r prior_slot prior_arm prior_rate; do
            printf '%s\t%s\t%s\t64\t6000.000\t%s\t-\ton\t-\tcompleted\n' \
                "$prior_slot" "$prior_arm" "$production_sha256" "$prior_rate"
        done
    } >"$prior_root/arms.tsv"
    write_prior_receipt "$prior_root" C0 '1 2 3 4' 'P-nosidecar P P P-nosidecar' \
        "$(prior_rate_range 1 4)"
    write_prior_receipt "$prior_root" C1 '5 6 7 8' 'P I0 I0 P' "$(prior_rate_range 5 8)"
    write_prior_receipt "$prior_root" C2 '9 10 11 12' 'I0 I1 I1 I0' \
        "$(prior_rate_range 9 12)"
}

run_brick_calibration() {
    brick_case=$1
    brick_prior=$2
    brick_output=$3
    # The fourth argument withholds the broker's readiness line, which is one
    # setting of the same executable, so the acquisition contract the reused
    # bricks were closed over holds across both arms.
    brick_broker_silent=${4:-0}
    # The fifth argument names the selected graphics clock the stub validator
    # reports, which is what puts a clock state in arms.tsv without a device.
    brick_clock_state=${5:-}
    # The sixth caps the regime precondition. Two is what these cases run at,
    # so a warmup phase costs two arms rather than eight and each case's own
    # failure and cooldown counts stay readable.
    brick_regime_max_arms=${6:-2}
    # The seventh names a per-arm clock table the stub validator reads, and the
    # eighth an arm label whose served runner leaves a truncated reply.
    brick_clock_table=${7:-}
    brick_truncate_label=${8:-}
    # The ninth and tenth are the modal share window. The sustained regime
    # measures 0.12 to 0.16 there and boost 0.55 to 0.68, so a case moving
    # either bound names it rather than inheriting the shipped defaults.
    brick_regime_min_share=${9:-0.05}
    brick_regime_max_share=${10:-0.30}
    active_fixture=$brick_case
    diagnostic_file=$temporary_directory/$brick_case-stderr.txt
    set +e
    env -i \
        QWEN_TEST_BROKER_SILENT="$brick_broker_silent" \
        QWEN_TEST_CLOCK_STATE="$brick_clock_state" \
        QWEN_TEST_CLOCK_TABLE="$brick_clock_table" \
        QWEN_TEST_CENSUS_TRUNCATE="$brick_truncate_label" \
        PATH="$signal_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$signal_drm" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_HWMON_ROOT="$signal_hwmon" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_CENSUS_COOLDOWN_S=0 \
        QWEN_CENSUS_REPLICATES=2 \
        QWEN_CENSUS_REGIME_MAX_ARMS="$brick_regime_max_arms" \
        QWEN_CENSUS_REGIME_MIN_SHARE="$brick_regime_min_share" \
        QWEN_CENSUS_REGIME_MAX_SHARE="$brick_regime_max_share" \
        QWEN_CENSUS_REUSE_BRICKS="$brick_prior" \
        SSH_CONNECTION="$signal_ssh_connection" \
        "$brick_runner" "$model_id" "$brick_output" \
        >"$temporary_directory/$brick_case-stdout.txt" \
        2>"$temporary_directory/$brick_case-stderr.txt"
    brick_status=$?
    set -e
    printf '%s\n' "$brick_status"
}

prior_calibration=$temporary_directory/prior-calibration
write_prior_calibration "$prior_calibration"
write_prior_receipt "$prior_calibration" C3 13 S 3.000

brick_output=$temporary_directory/out-brick-reuse
brick_status=$(run_brick_calibration brick_reuse_zero_arms "$prior_calibration" "$brick_output")
if [ "$brick_status" -ne 0 ]; then
    printf 'a calibration reusing four bricks exited %s where it accepts\n' "$brick_status" >&2
    exit 1
fi
brick_reused_rows=$(awk -F'\t' 'NR > 1 && $10 == "reused"' "$brick_output/arms.tsv" | wc -l)
if [ "$brick_reused_rows" -ne 13 ]; then
    printf 'the reusing calibration echoed %s reused rows of 13\n' "$brick_reused_rows" >&2
    exit 1
fi
if [ -n "$(find "$brick_output/arms" -mindepth 1 -print -quit)" ]; then
    printf 'the reusing calibration created an arm directory\n' >&2
    exit 1
fi
# A warmup warms the arms that follow it, so a calibration with nothing to
# run skips slot 0 outright rather than launching a server for no arm.
if ! grep -q 'census_arm=skipped slot=0 arm=W reason=every_brick_reused' \
    "$temporary_directory/brick_reuse_zero_arms-stdout.txt"; then
    printf 'the reusing calibration ran the warmup arm\n' >&2
    exit 1
fi
if awk -F'\t' 'NR > 1 && $2 == "W"' "$brick_output/arms.tsv" | grep -q .; then
    printf 'the reusing calibration recorded a warmup row\n' >&2
    exit 1
fi
brick_root_sha256=$(awk -F'\t' '$1 == "calibration_root_sha256" { print $2 }' \
    "$brick_output/calibration-root.tsv")
[ -n "$brick_root_sha256" ]
if ! grep -q "^calibration_root_sha256=$brick_root_sha256$" "$brick_output/terminal-state.tsv"; then
    printf 'terminal-state.tsv carries no calibration root\n' >&2
    exit 1
fi
grep -q '^census=accepted$' "$brick_output/terminal-state.tsv"
grep -q '^cooldown_timeouts=0$' "$brick_output/terminal-state.tsv"
for brick_member in C0 C1 C2 C3; do
    grep -q "^reused_from	$prior_calibration$" \
        "$brick_output/bricks/$brick_member.receipt.tsv"
    # A brick reused out of a directory that recorded no terminal state says
    # so, since the root names the receipt and the receipt names its campaign.
    grep -q '^reused_from_census	unrecorded$' \
        "$brick_output/bricks/$brick_member.receipt.tsv"
done
# A run that executed nothing prices nothing but itself, so the wall-clock
# ledger holds its header and the one campaign row.
brick_wall_rows=$(awk 'NR > 1' "$brick_output/wall-clock.tsv" | wc -l)
if [ "$brick_wall_rows" -ne 1 ]; then
    printf 'the reusing calibration wrote %s wall-clock rows of 1\n' "$brick_wall_rows" >&2
    exit 1
fi
diagnostic_file=
printf 'brick_reuse_zero_arms=accepted root=%s\n' "$brick_root_sha256"

# inputs.tsv is the run's own record of what it ran under, so it names the
# sampler and both digests beside the geometry the contract carries.
active_fixture=sampler_broker_inputs
for sampler_row in "sidecar_implementation	telemetry-broker" \
    "sidecar_binary_sha256	$broker_stub_sha256" \
    "sidecar_source_sha256	$broker_source_sha256"; do
    if ! grep -qxF -- "$sampler_row" "$brick_output/inputs.tsv"; then
        printf 'inputs.tsv carries no row %s\n' "$sampler_row" >&2
        exit 1
    fi
done
diagnostic_file=
printf 'sampler_broker_inputs=accepted\n'

# Three bricks reused and C3 executed: the arm fails on its own served runner
# and the quiescence poller reports a deadline, which the cooldown row records
# and the terminal state counts rather than charging to the arm.
prior_three_bricks=$temporary_directory/prior-three-bricks
write_prior_calibration "$prior_three_bricks"
printf 'census=refuted\n' >"$prior_three_bricks/terminal-state.tsv"
brick_cooldown_output=$temporary_directory/out-quiescence-cooldown
brick_status=$(run_brick_calibration quiescence_cooldown "$prior_three_bricks" \
    "$brick_cooldown_output")
if [ "$brick_status" -ne 1 ]; then
    printf 'the executed-arm calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
if ! awk -F'\t' '$1 == "13" && $3 == "cooldown" && $6 == "quiescence=timeout elapsed_ms=1234" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_cooldown_output/wall-clock.tsv"; then
    printf 'the cooldown row carries no quiescence verdict and elapsed time\n' >&2
    sed -n '1,10p' "$brick_cooldown_output/wall-clock.tsv" >&2
    exit 1
fi
# The warmups open the calibration at the lettered slots whenever any arm
# executes, take the production server under the sampler, and enter no pair:
# the sidecar quadruple is reused here, so the summary still carries its three
# controls while arms.tsv carries the warmup rows beside them. This case runs
# the delegating validator, which refuses the stub broker's record and leaves
# no clock state, so the precondition spends its whole cap and settles nothing.
for brick_warmup_slot in 0a 0b; do
    if ! awk -F'\t' -v slot="$brick_warmup_slot" \
        '$1 == slot && $2 == "W" { found = 1 } END { exit found ? 0 : 1 }' \
        "$brick_cooldown_output/arms.tsv"; then
        printf 'the executed-arm calibration recorded no warmup row at slot %s\n' \
            "$brick_warmup_slot" >&2
        exit 1
    fi
done
if awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["outer"]) == "W" || $(column["inner"]) == "W" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_cooldown_output/summary.tsv"; then
    printf 'a warmup arm entered a control pair\n' >&2
    exit 1
fi
grep -q '^census_regime=unreached sclk_mhz=- arms=2$' \
    "$temporary_directory/quiescence_cooldown-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t-')" "$brick_cooldown_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t2')" "$brick_cooldown_output/inputs.tsv"
grep -q '^cooldown_timeouts=3$' "$brick_cooldown_output/terminal-state.tsv"
grep -q '^arm_failures=3$' "$brick_cooldown_output/terminal-state.tsv"
grep -q 'census_arm=failed slot=13 arm=S .* reason=served_runner' \
    "$temporary_directory/quiescence_cooldown-stdout.txt"
grep -q 'census_arm=failed slot=0a arm=W .* reason=served_runner' \
    "$temporary_directory/quiescence_cooldown-stdout.txt"
grep -q '^verdict	failed$' "$brick_cooldown_output/bricks/C3.receipt.tsv"
for brick_member in C0 C1 C2; do
    grep -q "^reused_from	$prior_three_bricks$" \
        "$brick_cooldown_output/bricks/$brick_member.receipt.tsv"
    # A brick whose arms completed inside a refuted campaign is reused and
    # names that campaign rather than hiding behind the new run's state.
    grep -q '^reused_from_census	refuted$' \
        "$brick_cooldown_output/bricks/$brick_member.receipt.tsv"
done
diagnostic_file=
printf 'quiescence_cooldown=accepted\n'

# A broker that announces no readiness ends the arm ahead of the request. The
# same three bricks are reused, so S at slot 13 is the one sampled arm, and it
# reports sidecar_start rather than the served-runner reason the ready sampler
# produces above; the arm still enters arms.tsv, since the control summarizer
# walks quadruple positions and a missing row would shift every later pair.
prior_silent_bricks=$temporary_directory/prior-silent-bricks
write_prior_calibration "$prior_silent_bricks"
printf 'census=refuted\n' >"$prior_silent_bricks/terminal-state.tsv"
brick_silent_output=$temporary_directory/out-sidecar-start
brick_status=$(run_brick_calibration sidecar_start_failure "$prior_silent_bricks" \
    "$brick_silent_output" 1)
if [ "$brick_status" -ne 1 ]; then
    printf 'the silent-broker calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
grep -q 'census_sidecar=start_refused slot=13 arm=S sampler=telemetry-broker' \
    "$temporary_directory/sidecar_start_failure-stdout.txt"
grep -q 'census_arm=failed slot=13 arm=S .* reason=sidecar_start' \
    "$temporary_directory/sidecar_start_failure-stdout.txt"
if ! awk -F'\t' '$1 == "13" && $8 == "refused" && $10 == "failed" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_silent_output/arms.tsv"; then
    printf 'arms.tsv carries no refused sampler row at slot 13\n' >&2
    sed -n '1,20p' "$brick_silent_output/arms.tsv" >&2
    exit 1
fi
# The request never ran, so the served runner wrote none of its own output.
if [ -e "$brick_silent_output/arms/13-S/runner.stdout" ]; then
    printf 'the served runner ran under a sampler that never started\n' >&2
    exit 1
fi
diagnostic_file=
printf 'sidecar_start_failure=accepted\n'

# A control whose interval spans its bound resolves nothing, which is a
# campaign state of its own between accepted and refuted. These are the rates
# the appliance calibration of 20260902T0819Z measured: fourteen arms, every
# sidecar accepted, and two replicates per control that disagree in sign on
# the sidecar and compile pairs. All four bricks reuse, so no arm executes and
# the terminal state reports the three unresolved controls alone.
prior_unresolved=$temporary_directory/prior-unresolved
prior_accepted_arm_rows=$prior_arm_rows
prior_arm_rows="1	P-nosidecar	9.590
2	P	9.475
3	P	9.604
4	P-nosidecar	9.513
5	P	9.402
6	I0	9.628
7	I0	9.427
8	P	9.522
9	I0	9.530
10	I1	9.351
11	I1	9.498
12	I0	9.549
13	S	3.000"
write_prior_calibration "$prior_unresolved"
write_prior_receipt "$prior_unresolved" C3 13 S 3.000
prior_arm_rows=$prior_accepted_arm_rows
brick_unresolved_output=$temporary_directory/out-unresolved
brick_status=$(run_brick_calibration control_unresolved "$prior_unresolved" \
    "$brick_unresolved_output")
if [ "$brick_status" -ne 4 ]; then
    printf 'an unresolved calibration exited %s where it exits 4\n' "$brick_status" >&2
    exit 1
fi
grep -q '^census=unresolved$' "$brick_unresolved_output/terminal-state.tsv"
grep -q '^control_unresolved=3$' "$brick_unresolved_output/terminal-state.tsv"
grep -q '^control_refutations=0$' "$brick_unresolved_output/terminal-state.tsv"
grep -q '^control_accepted=0$' "$brick_unresolved_output/terminal-state.tsv"
if ! awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["verdict"]) == "unresolved" && $(column["detail"]) ~ /^spans bound=/ { found++ }
    END { exit found == 3 ? 0 : 1 }' "$brick_unresolved_output/summary.tsv"; then
    printf 'summary.tsv carries no three unresolved controls naming their bound\n' >&2
    sed -n '1,5p' "$brick_unresolved_output/summary.tsv" >&2
    exit 1
fi
# The aggregate columns travel beside the first replicate's own pair, so a
# reader compares one arm pair against the set that judged it.
if ! awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "sidecar" && $(column["replicates"]) == "2" \
        && $(column["first_delta"]) == "-0.0120" \
        && $(column["second_delta"]) == "+0.0096" \
        && $(column["deltas"]) == "-0.0120 +0.0096" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_unresolved_output/summary.tsv"; then
    printf 'the sidecar row carries no replicate columns beside its deltas\n' >&2
    sed -n '1,5p' "$brick_unresolved_output/summary.tsv" >&2
    exit 1
fi
# inputs.tsv is the run's own record of the shape it ran, so the replicate
# count and the generated list live there rather than in the contract digest.
grep -q '^census_replicates	2$' "$brick_unresolved_output/inputs.tsv"
grep -q '^census_arm_count	15$' "$brick_unresolved_output/inputs.tsv"
grep -q '^predicted_arm_duration_s	19$' "$brick_unresolved_output/inputs.tsv"
grep -q '^regime_max_arms	2$' "$brick_unresolved_output/inputs.tsv"
# Four reused bricks leave nothing to warm and nothing to settle, so the
# precondition runs no arm and says so rather than leaving the rows absent.
grep -q '^census_regime=unreached sclk_mhz=- arms=0$' \
    "$temporary_directory/control_unresolved-stdout.txt"
grep -qxF "$(printf 'regime_arms\t0')" "$brick_unresolved_output/inputs.tsv"
diagnostic_file=
printf 'control_unresolved=accepted exit=4\n'

# arms.tsv states the clock state each sampled arm ran under, so a later reader
# knows which pairs met one governor step. Three bricks reuse and slot 13
# executes with the stub validator reporting 800 MHz: the sampled row carries
# that mode and its share, the warmup at slot 0 runs with the sampler off and
# carries neither, and every echoed row is padded to the header's own arity so
# the ledger stays rectangular under one header.
active_fixture=arms_clock_state
prior_clock_state=$temporary_directory/prior-clock-state
write_prior_calibration "$prior_clock_state"
printf 'census=refuted\n' >"$prior_clock_state/terminal-state.tsv"
clock_state_output=$temporary_directory/out-clock-state
brick_status=$(run_brick_calibration arms_clock_state "$prior_clock_state" \
    "$clock_state_output" 0 800)
if [ "$brick_status" -ne 1 ]; then
    printf 'the clock-state calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
if ! head -n 1 "$clock_state_output/arms.tsv" \
    | grep -q "	status	sclk_mode_mhz	sclk_share	regime_delta\$"; then
    printf 'arms.tsv names no clock-state columns after status\n' >&2
    head -n 1 "$clock_state_output/arms.tsv" >&2
    exit 1
fi
if ! awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $1 == "13" && $(column["sclk_mode_mhz"]) == "800" \
        && $(column["sclk_share"]) == "0.1400" { found = 1 }
    END { exit found ? 0 : 1 }' "$clock_state_output/arms.tsv"; then
    printf 'the sampled arm carries no clock state at slot 13\n' >&2
    sed -n '1,20p' "$clock_state_output/arms.tsv" >&2
    exit 1
fi
# The warmups sample too, so both report the same 800 MHz the stub validator
# states, the precondition settles on the second, and the run records their
# mean as the regime every named arm is measured against.
for brick_warmup_slot in 0a 0b; do
    if ! awk -F'\t' -v slot="$brick_warmup_slot" \
        'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        $1 == slot && $2 == "W" && $(column["sidecar"]) == "on" \
            && $(column["sclk_mode_mhz"]) == "800" \
            && $(column["regime_delta"]) == "-" { found = 1 }
        END { exit found ? 0 : 1 }' "$clock_state_output/arms.tsv"; then
        printf 'the warmup at slot %s carries no sampled clock state\n' \
            "$brick_warmup_slot" >&2
        sed -n '1,20p' "$clock_state_output/arms.tsv" >&2
        exit 1
    fi
done
grep -q '^census_regime=reached sclk_mhz=800.0 arms=2$' \
    "$temporary_directory/arms_clock_state-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t800.0')" "$clock_state_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t2')" "$clock_state_output/inputs.tsv"
# The named arm ran at the regime's own mode, so its distance from it is zero
# rather than unknown.
if ! awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $1 == "13" && $(column["regime_delta"]) == "+0.0000" { found = 1 }
    END { exit found ? 0 : 1 }' "$clock_state_output/arms.tsv"; then
    printf 'the sampled arm carries no distance from the regime at slot 13\n' >&2
    sed -n '1,20p' "$clock_state_output/arms.tsv" >&2
    exit 1
fi
if ! awk -F'\t' 'NR == 1 { want = NF; next } NF != want { ragged = 1 }
    END { exit ragged ? 1 : 0 }' "$clock_state_output/arms.tsv"; then
    printf 'arms.tsv holds a row whose arity misses the header\n' >&2
    exit 1
fi
grep -q '^control_state_changed=0$' "$clock_state_output/terminal-state.tsv"
diagnostic_file=
printf 'arms_clock_state=accepted mode=800\n'

# The precondition spends as many warmups as it needs and stops at the pair
# that settles. Four are admitted here and the third is what agrees with the
# second, so the run settles at three arms, records their mean, and leaves the
# fourth unrun.
active_fixture=regime_settles_at_three
prior_regime=$temporary_directory/prior-regime
write_prior_calibration "$prior_regime"
printf 'census=refuted\n' >"$prior_regime/terminal-state.tsv"
regime_clock_table=$temporary_directory/clocks-regime
printf '0a-W\t1100\n0b-W\t800\n0c-W\t812\n0d-W\t1100\n13-S\t825\n' >"$regime_clock_table"
regime_output=$temporary_directory/out-regime-settles
brick_status=$(run_brick_calibration regime_settles_at_three "$prior_regime" \
    "$regime_output" 0 800 4 "$regime_clock_table")
if [ "$brick_status" -ne 1 ]; then
    printf 'the regime calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
grep -q '^census_regime=reached sclk_mhz=806.0 arms=3$' \
    "$temporary_directory/regime_settles_at_three-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t806.0')" "$regime_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t3')" "$regime_output/inputs.tsv"
[ "$(awk -F'\t' 'NR > 1 && $2 == "W" { print $1 }' "$regime_output/arms.tsv" | tr '\n' ' ')" \
    = '0a 0b 0c ' ]
if [ -e "$regime_output/arms/0d-W" ]; then
    printf 'the settled precondition ran its fourth warmup\n' >&2
    exit 1
fi
# The identity arm ran 2.30% off that regime, inside the band, and states the
# distance rather than a verdict: the pair comparability is what the summary
# carries, and this column is what a reader takes a drifting campaign from.
if ! awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $1 == "13" && $(column["sclk_mode_mhz"]) == "825" \
        && $(column["regime_delta"]) == "+0.0230" { found = 1 }
    END { exit found ? 0 : 1 }' "$regime_output/arms.tsv"; then
    printf 'the identity arm carries no distance from the settled regime\n' >&2
    sed -n '1,20p' "$regime_output/arms.tsv" >&2
    exit 1
fi
diagnostic_file=
printf 'regime_settles_at_three=accepted arms=3 regime=806.0\n'

# No two consecutive warmups both agree and sit inside the share window, so the
# precondition spends its cap and settles nothing: a window the validator read
# no clock state out of resets the pair, and so does a window whose mode is
# pinned at a share of 0.62 even though its clock agrees with its predecessor's.
# The campaign continues with an unrecorded regime and no distance on any named
# arm.
active_fixture=regime_unreached
prior_unsettled=$temporary_directory/prior-unsettled
write_prior_calibration "$prior_unsettled"
printf 'census=refuted\n' >"$prior_unsettled/terminal-state.tsv"
unsettled_clock_table=$temporary_directory/clocks-unsettled
printf '0a-W\t1100\n0b-W\tnone\n0c-W\t800\n0d-W\t800:0.62\n13-S\t825\n' \
    >"$unsettled_clock_table"
unsettled_output=$temporary_directory/out-regime-unsettled
brick_status=$(run_brick_calibration regime_unreached "$prior_unsettled" \
    "$unsettled_output" 0 800 4 "$unsettled_clock_table")
if [ "$brick_status" -ne 1 ]; then
    printf 'the unsettled calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
grep -q '^census_regime=unreached sclk_mhz=- arms=4$' \
    "$temporary_directory/regime_unreached-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t-')" "$unsettled_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t4')" "$unsettled_output/inputs.tsv"
[ "$(awk -F'\t' 'NR > 1 && $2 == "W" { print $1 }' "$unsettled_output/arms.tsv" | tr '\n' ' ')" \
    = '0a 0b 0c 0d ' ]
[ "$(awk -F'\t' '$1 == "0b" { print $11, $12 }' "$unsettled_output/arms.tsv")" = '- -' ]
[ "$(awk -F'\t' '$1 == "0d" { print $11, $12 }' "$unsettled_output/arms.tsv")" = '800 0.62' ]
# An unreached regime leaves every named arm without a distance to it, and the
# named arms still hold the integer slots every brick and receipt is stated in.
if awk -F'\t' 'NR > 1 && $2 != "W" && $13 != "-"' "$unsettled_output/arms.tsv" | grep -q .; then
    printf 'a named arm carries a distance from an unreached regime\n' >&2
    exit 1
fi
[ "$(awk -F'\t' 'NR > 1 && $2 != "W" { print $1 }' "$unsettled_output/arms.tsv" | tr '\n' ' ')" \
    = '1 2 3 4 5 6 7 8 9 10 11 12 13 ' ]
# The warmups enter no pair and no census record: the summary carries the three
# reused controls and names W in neither position of any of them.
if awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["outer"]) == "W" || $(column["inner"]) == "W" { found = 1 }
    END { exit found ? 0 : 1 }' "$unsettled_output/summary.tsv"; then
    printf 'a warmup arm entered a control pair\n' >&2
    exit 1
fi
for unsettled_brick in C0 C1 C2; do
    if grep -q '	0[a-h]' "$unsettled_output/bricks/$unsettled_brick.receipt.tsv"; then
        printf 'a brick receipt claims a warmup slot\n' >&2
        exit 1
    fi
done
diagnostic_file=
printf 'regime_unreached=accepted arms=4\n'

# A reply the served runner never finished writing is unreadable rather than
# absent. The reader's own failure answers the unknown triple, the arm fails on
# its missing rate, and the ledger stays rectangular under one header rather
# than carrying a completed row with empty fields.
active_fixture=truncated_reply
prior_truncated=$temporary_directory/prior-truncated
write_prior_calibration "$prior_truncated"
printf 'census=refuted\n' >"$prior_truncated/terminal-state.tsv"
truncated_output=$temporary_directory/out-truncated-reply
brick_status=$(run_brick_calibration truncated_reply "$prior_truncated" \
    "$truncated_output" 0 800 2 '' 13-S)
if [ "$brick_status" -ne 1 ]; then
    printf 'the truncated-reply calibration exited %s where its failed arm exits 1\n' \
        "$brick_status" >&2
    exit 1
fi
grep -q 'census_arm=failed slot=13 arm=S tok_s=- .* reason=served_runner' \
    "$temporary_directory/truncated_reply-stdout.txt"
if ! awk -F'\t' '$1 == "13" && $4 == "-" && $5 == "-" && $6 == "-" && $10 == "failed" { found = 1 }
    END { exit found ? 0 : 1 }' "$truncated_output/arms.tsv"; then
    printf 'the truncated arm carries no unknown triple at slot 13\n' >&2
    sed -n '1,20p' "$truncated_output/arms.tsv" >&2
    exit 1
fi
if ! awk -F'\t' 'NR == 1 { want = NF; next } NF != want { ragged = 1 }
    END { exit ragged ? 1 : 0 }' "$truncated_output/arms.tsv"; then
    printf 'arms.tsv holds a row whose arity misses the header\n' >&2
    exit 1
fi
# The campaign wrote its terminal state rather than ending inside the arm.
grep -q '^census=failed$' "$truncated_output/terminal-state.tsv"
grep -q '^arm_failures=3$' "$truncated_output/terminal-state.tsv"
diagnostic_file=
printf 'truncated_reply=accepted\n'

# The sustained regime's modal share is what the threshold has to admit, and
# 20260902T1417Z measures it at 0.12 to 0.16. A threshold below that admits it:
# two consecutive warmups at 0.13 settle the precondition on their own mean, so
# the mechanism holds a low threshold and the shipped 0.5 default is the
# constant that refuses the served regime rather than the comparison.
# The share window is what separates the two regimes, and 20260902T1417Z is the
# shape it is set from: boost pins 1100 MHz at a modal share of 0.5518 to
# 0.6803, and the sustained regime the appliance serves in hovers across seven
# values at 0.1206 to 0.1615. Two boost warmups agree at 1100 within any band,
# so the ceiling is the only rule that declines them.
active_fixture=regime_share_window
prior_share_window=$temporary_directory/prior-share-window
write_prior_calibration "$prior_share_window"
printf 'census=refuted\n' >"$prior_share_window/terminal-state.tsv"
boost_clock_table=$temporary_directory/clocks-boost
printf '0a-W\t1100:0.60\n0b-W\t1100:0.66\n13-S\t1100:0.55\n' >"$boost_clock_table"
boost_output=$temporary_directory/out-regime-boost
boost_status=$(run_brick_calibration regime_boost_refused "$prior_share_window" \
    "$boost_output" 0 800 2 "$boost_clock_table")
if [ "$boost_status" -ne 1 ]; then
    printf 'the boost calibration exited %s where its failed arm exits 1\n' \
        "$boost_status" >&2
    exit 1
fi
grep -q '^census_regime=unreached sclk_mhz=- arms=2$' \
    "$temporary_directory/regime_boost_refused-stdout.txt"
[ "$(awk -F'\t' '$1 == "0a" { print $11, $12 }' "$boost_output/arms.tsv")" = '1100 0.60' ]
[ "$(awk -F'\t' '$1 == "0b" { print $11, $12 }' "$boost_output/arms.tsv")" = '1100 0.66' ]
# The sustained shape settles on the same two arms under the same defaults, so
# the ceiling rather than the band or the arm count is what refused the pair
# above.
sustained_clock_table=$temporary_directory/clocks-sustained
printf '0a-W\t800:0.13\n0b-W\t812:0.13\n13-S\t825:0.14\n' >"$sustained_clock_table"
sustained_output=$temporary_directory/out-regime-sustained
sustained_status=$(run_brick_calibration regime_sustained_settles "$prior_share_window" \
    "$sustained_output" 0 800 2 "$sustained_clock_table")
if [ "$sustained_status" -ne 1 ]; then
    printf 'the sustained calibration exited %s where its failed arm exits 1\n' \
        "$sustained_status" >&2
    exit 1
fi
grep -q '^census_regime=reached sclk_mhz=806.0 arms=2$' \
    "$temporary_directory/regime_sustained_settles-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t806.0')" "$sustained_output/inputs.tsv"
grep -qxF "$(printf 'regime_min_share\t0.05')" "$sustained_output/inputs.tsv"
grep -qxF "$(printf 'regime_max_share\t0.30')" "$sustained_output/inputs.tsv"
# The ceiling is an acquisition-contract row, so a run that raises it past the
# boost share runs under another contract and reuses no brick written against
# the default; that run settles the boost pair the default refused, which is
# what makes the ceiling rather than the comparison the deciding rule.
raised_output=$temporary_directory/out-regime-raised-ceiling
raised_status=$(run_brick_calibration regime_raised_ceiling '' \
    "$raised_output" 0 800 2 "$boost_clock_table" '' 0.05 0.7)
if [ "$raised_status" -ne 1 ]; then
    printf 'the raised-ceiling calibration exited %s where its failed arm exits 1\n' \
        "$raised_status" >&2
    sed -n '1,20p' "$temporary_directory/regime_raised_ceiling-stderr.txt" >&2
    exit 1
fi
grep -q '^census_regime=reached sclk_mhz=1100.0 arms=2$' \
    "$temporary_directory/regime_raised_ceiling-stdout.txt"
grep -qxF "$(printf 'regime_max_share\t0.7')" "$raised_output/inputs.tsv"
diagnostic_file=
printf 'regime_share_window=accepted boost=unreached sustained=806.0\n'

active_fixture=completion
printf 'run_raven2_vulkan_kernel_census_preflight=accepted cases=%s\n' "$run_index"
