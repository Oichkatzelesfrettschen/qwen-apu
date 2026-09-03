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
# The runtime tree's head is a git revision, and the campaign signs its Vulkan
# lease proof with it, so the fixture spells it in the 40-hex form
# verify-external-vulkan-lease.py validates.
runtime_git_head=0123456789abcdef0123456789abcdef01234567
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
    "$runtime_git_head" "$foreign_sha256" "$registry_sha256" >"$runtime_tree_manifest"
runtime_remote_unmanifested=$temporary_directory/unmanifested/remote
mkdir -p "$runtime_remote_unmanifested"
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    cp -- "$runtime_remote/$runtime_script" "$runtime_remote_unmanifested/$runtime_script"
done

home_directory=$temporary_directory/home
models_directory=$temporary_directory/models
mkdir -p "$home_directory"
# The campaign holds its state directory's own Vulkan lease from before the
# clock write to its exit, so the fixture home carries that directory.
workload_lease_directory=$home_directory/qwen-webui-state
mkdir -p "$workload_lease_directory"
workload_lease=$workload_lease_directory/vulkan-workload.lock
model_file=$("$registry_reader" id "$model_id" model_file)
mkdir -p "$models_directory/$(dirname -- "$model_file")"
# The checkpoint carries bytes so a replacement can hold its byte count and
# move its digest alone, which leaves the arm's own descriptor record as the
# only reading that separates the two.
printf 'fixture-model-a\n' >"$models_directory/$model_file"

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
# The source record build-telemetry-broker.sh writes beside an executable it
# compiled. The stub was compiled from nothing, so the record is written here
# to state the source the preflight holds it to; a case that omits it is a
# stale broker and the preflight rebuilds over it.
printf '%s\n' "$broker_source_sha256" >"$broker_stub.source-sha256"
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

# A canary requests eight tokens, so its acquisition contract states the
# workload its seven decode graphs came out of rather than the calibration's
# sixty-four.
active_fixture=canary_contract_generate
canary_contract_output=$(env -i \
    PATH="$execution_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$drm_empty" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_MODE=canary \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$runner" "$model_id" "$temporary_directory/out-contract-canary")
if ! printf '%s\n' "$canary_contract_output" | grep -q '^generate_tokens	8$'; then
    printf 'the canary acquisition contract states another token count\n' >&2
    printf '%s\n' "$canary_contract_output" | grep '^generate_tokens' >&2
    exit 1
fi
printf 'canary_contract_generate=accepted generate_tokens=8\n'

# A broker standing beside a source record naming another telemetry-broker.c is
# rebuilt rather than sampled with. The appliance ran a whole calibration
# against a binary that predated the delivered-frequency column because the
# preflight built only where the executable was absent; here the record states
# a digest no source has, the compiler is a stub that copies the broker stub
# into place and logs the output it was asked for, and the contract carries the
# tree's own source digest afterwards.
active_fixture=broker_rebuild_stale_source
rebuild_directory=$temporary_directory/broker-rebuild
mkdir -p "$rebuild_directory"
rebuild_broker=$rebuild_directory/telemetry-broker
cp -- "$broker_stub" "$rebuild_broker"
printf '%s\n' \
    '0000000000000000000000000000000000000000000000000000000000000000' \
    >"$rebuild_broker.source-sha256"
rebuild_cc=$temporary_directory/stub-cc
cat >"$rebuild_cc" <<'STUB_CC'
#!/bin/sh
set -eu
compiler_output=''
compiler_previous=''
for compiler_argument in "$@"; do
    if [ "$compiler_previous" = -o ]; then
        compiler_output=$compiler_argument
    fi
    compiler_previous=$compiler_argument
done
printf '%s\n' "$compiler_output" >>"$QWEN_TEST_CC_LOG"
cp -- "$QWEN_TEST_CC_PAYLOAD" "$compiler_output"
chmod +x "$compiler_output"
STUB_CC
chmod +x "$rebuild_cc"
rebuild_cc_log=$temporary_directory/stub-cc.log
: >"$rebuild_cc_log"
print_rebuild_contract() {
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$drm_empty" \
        QWEN_CENSUS_BROKER="$rebuild_broker" \
        QWEN_TEST_CC_LOG="$rebuild_cc_log" \
        QWEN_TEST_CC_PAYLOAD="$broker_stub" \
        CC="$rebuild_cc" \
        QWEN_CENSUS_PRINT_CONTRACT=1 \
        "$runner" "$model_id" "$temporary_directory/out-rebuild-$1" \
        2>"$temporary_directory/rebuild-stderr-$1.txt"
}
rebuild_contract_output=$(print_rebuild_contract 1)
if ! grep -q '^telemetry_broker=rebuilt reason=stale ' \
    "$temporary_directory/rebuild-stderr-1.txt"; then
    printf 'a broker recording another source was not rebuilt\n' >&2
    exit 1
fi
if [ "$(wc -l <"$rebuild_cc_log")" -ne 1 ]; then
    printf 'the rebuild invoked the compiler %s times\n' \
        "$(wc -l <"$rebuild_cc_log")" >&2
    exit 1
fi
[ "$(cat "$rebuild_cc_log")" = "$rebuild_broker" ]
if ! printf '%s\n' "$rebuild_contract_output" \
    | grep -q "^sidecar_source_sha256	$broker_source_sha256\$"; then
    printf 'the rebuilt broker contract carries another source digest\n' >&2
    exit 1
fi
[ "$(cat "$rebuild_broker.source-sha256")" = "$broker_source_sha256" ]
# The record the build wrote is what makes the next run cheap: the same
# invocation reads it, finds the tree's own source, and runs no compiler.
print_rebuild_contract 2 >/dev/null
if [ "$(wc -l <"$rebuild_cc_log")" -ne 1 ]; then
    printf 'a broker recording its own source was rebuilt again\n' >&2
    exit 1
fi
if grep -q '^telemetry_broker=rebuilt ' "$temporary_directory/rebuild-stderr-2.txt"; then
    printf 'the second run reported a rebuild\n' >&2
    exit 1
fi
# An executable standing beside no record at all is the state the appliance
# is in wherever a past build predates the record, so it takes the same
# rebuild rather than the benefit of the doubt.
rm -f -- "$rebuild_broker.source-sha256"
print_rebuild_contract 3 >/dev/null
if ! grep -q '^telemetry_broker=rebuilt reason=stale ' \
    "$temporary_directory/rebuild-stderr-3.txt"; then
    printf 'a broker standing beside no source record was not rebuilt\n' >&2
    exit 1
fi
if [ "$(wc -l <"$rebuild_cc_log")" -ne 2 ]; then
    printf 'the record-absent rebuild invoked the compiler %s times of 2\n' \
        "$(wc -l <"$rebuild_cc_log")" >&2
    exit 1
fi
[ "$(cat "$rebuild_broker.source-sha256")" = "$broker_source_sha256" ]
printf 'broker_rebuild_stale_source=accepted source=%s\n' "$broker_source_sha256"

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

# The quiescence deadline decides the campaign, so a value await-quiescence.sh
# would refuse as a usage error is refused here instead: a poller ending at
# exit 2 prints no verdict, and the arm loop would end the run on that.
run_runner cooldown_deadline_zero 'QWEN_CENSUS_COOLDOWN_S is a positive second count' \
    QWEN_CENSUS_COOLDOWN_S=0

run_runner cooldown_deadline_text 'QWEN_CENSUS_COOLDOWN_S is a positive second count' \
    QWEN_CENSUS_COOLDOWN_S=thirty

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

# An arm list of whitespace alone is a supplied value that runs no arm, which
# leaves the summarizer a header and the attribution zero accepted controls to
# require, so the list is refused ahead of the preflight it would pass.
run_runner attribution_whitespace_arms 'names at least one arm' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_receipt" \
    QWEN_CENSUS_ARMS='   '

# Each bound, band, and tolerance reaches its reader as a float, where `inf`
# and `nan` name no value a record or an interval can miss, so the runner holds
# each to a canonical decimal and the band and the lost share to their own
# range.
run_runner sidecar_bound_infinite 'a census control bound is a nonnegative decimal' \
    QWEN_CENSUS_SIDECAR_BOUND=inf
run_runner compile_bound_not_a_number 'a census control bound is a nonnegative decimal' \
    QWEN_CENSUS_COMPILE_BOUND=nan
run_runner collect_bound_negative 'a census control bound is a nonnegative decimal' \
    QWEN_CENSUS_COLLECT_BOUND=-0.02
run_runner sclk_band_infinite 'QWEN_CENSUS_SCLK_BAND is a nonnegative decimal' \
    QWEN_CENSUS_SCLK_BAND=inf
run_runner sclk_band_above_one 'QWEN_CENSUS_SCLK_BAND is a relative distance' \
    QWEN_CENSUS_SCLK_BAND=1.5
run_runner sidecar_tolerance_infinite 'a census sampler tolerance is a nonnegative decimal' \
    QWEN_CENSUS_SIDECAR_TOLERANCE=inf
run_runner sidecar_max_lost_infinite 'a census sampler tolerance is a nonnegative decimal' \
    QWEN_CENSUS_SIDECAR_MAX_LOST=inf
run_runner sidecar_max_lost_above_one 'QWEN_CENSUS_SIDECAR_MAX_LOST is a share of the window' \
    QWEN_CENSUS_SIDECAR_MAX_LOST=1

# A retained calibration state carrying a matching row beside a contradicting
# one states no verdict, so the attribution counts each field rather than
# setting a bit from whichever row matched.
calibration_duplicate=$temporary_directory/calibration-duplicate
mkdir -p "$calibration_duplicate"
write_terminal_state "$calibration_duplicate/terminal-state.tsv" 3
printf 'census=failed\n' >>"$calibration_duplicate/terminal-state.tsv"
write_calibration_inputs "$calibration_duplicate/inputs.tsv" "$production_sha256"
run_runner calibration_state_contradicted \
    'is not an accepted calibration with three accepted controls' \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$calibration_duplicate" \
    QWEN_CENSUS_ARMS=I1

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

# The root binds each receipt to the campaign that wrote it, so a directory
# holding a ledger and an agreeing contract and no root offers receipts nothing
# stands behind.
reuse_no_root=$temporary_directory/reuse-no-root
mkdir -p "$reuse_no_root"
write_calibration_inputs "$reuse_no_root/inputs.tsv" "$production_sha256"
printf 'slot\tarm\ttok_s\tstatus\n' >"$reuse_no_root/arms.tsv"
run_runner reuse_root_absent 'carries no readable calibration-root\.tsv' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_no_root"

reuse_no_status=$temporary_directory/reuse-no-status
mkdir -p "$reuse_no_status"
write_calibration_inputs "$reuse_no_status/inputs.tsv" "$production_sha256"
printf 'acquisition_contract_sha256\t%s\n' "$contract_sha256" \
    >"$reuse_no_status/calibration-root.tsv"
printf 'slot\tarm\ttok_s\tstate\n' >"$reuse_no_status/arms.tsv"
run_runner reuse_ledger_without_status 'names no status column' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_no_status"

# A root that names another acquisition contract than the directory's own
# inputs states two campaigns, and the receipts it binds belong to neither.
reuse_foreign_root=$temporary_directory/reuse-foreign-root
mkdir -p "$reuse_foreign_root"
write_calibration_inputs "$reuse_foreign_root/inputs.tsv" "$production_sha256"
printf 'acquisition_contract_sha256\t%s\n' "$foreign_sha256" \
    >"$reuse_foreign_root/calibration-root.tsv"
printf 'slot\tarm\ttok_s\tstatus\n' >"$reuse_foreign_root/arms.tsv"
run_runner reuse_root_foreign_contract 'the brick reuse root records acquisition contract' \
    QWEN_CENSUS_REUSE_BRICKS="$reuse_foreign_root"

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
    verify-external-vulkan-lease.py \
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

# The privileged writer a forced engine clock policy goes through. The stub
# answers `sudo -n true` and `sudo -n tee NODE`, records every write, and keeps
# the fixture DRM directory consistent with what it was told: a policy other
# than auto stars the highest step pp_dpm_sclk lists, which is what the campaign
# confirms after its write, and auto stars the lowest, which is the governor
# state the restore returns the fixture to. QWEN_TEST_SUDO_REFUSE stands for an
# expired credential.
cat >"$signal_bin/sudo" <<'SUDO_STUB'
#!/bin/sh
set -eu
if [ "${QWEN_TEST_SUDO_REFUSE:-0}" = 1 ]; then
    printf 'sudo: a password is required\n' >&2
    exit 1
fi
[ "$1" = -n ] || exit 1
shift
case $1 in
    true) exit 0 ;;
    tee) ;;
    *) exit 1 ;;
esac
shift
sudo_node=$1
# A DPM table answers a write by moving its star and keeps its listing, the way
# the kernel attribute does, so the value read from stdin reaches the file only
# where the file is the performance level itself.
sudo_value=$(cat)
printf '%s\t%s\n' "$sudo_node" "$sudo_value" >>"${QWEN_TEST_SUDO_LOG:-/dev/null}"
sudo_directory=$(dirname -- "$sudo_node")
sudo_leaf=$(basename -- "$sudo_node")
# The device answers a write by moving the star. A performance level other than
# auto or manual raises the graphics table to its highest step and leaves the
# fabric table where it was, which is the SMU10 behavior the manual policy
# exists for; a level index written to a DPM table stars that level, and
# QWEN_TEST_SUDO_MCLK_IGNORE reproduces the firmware that takes the fabric write
# and keeps its own selection.
sudo_star() {
    awk -v want="$2" '{
            line = $0
            sub(/ \*$/, "", line)
            index_field = line
            sub(/:.*$/, "", index_field)
            if (index_field == want) print line " *"
            else print line
        }' "$1" >"$1.tmp"
    mv -- "$1.tmp" "$1"
}
case $sudo_leaf in
    power_dpm_force_performance_level)
        printf '%s\n' "$sudo_value" >"$sudo_node"
        if [ -f "$sudo_directory/pp_dpm_sclk" ]; then
            if [ "$sudo_value" = auto ] || [ "${QWEN_TEST_SUDO_STAR_LOWEST:-0}" = 1 ]; then
                sudo_star "$sudo_directory/pp_dpm_sclk" 0
            elif [ "$sudo_value" != manual ]; then
                sudo_star "$sudo_directory/pp_dpm_sclk" 1
            fi
        fi
        ;;
    pp_dpm_mclk)
        [ "${QWEN_TEST_SUDO_MCLK_IGNORE:-0}" = 1 ] || sudo_star "$sudo_node" "$sudo_value"
        ;;
    pp_dpm_sclk)
        if [ "${QWEN_TEST_SUDO_STAR_LOWEST:-0}" = 1 ]; then
            sudo_star "$sudo_node" 0
        else
            sudo_star "$sudo_node" "$sudo_value"
        fi
        ;;
esac
printf '%s\n' "$sudo_value"
SUDO_STUB
chmod +x "$signal_bin/sudo"
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
# The attribute a forced engine clock policy writes, holding the appliance's
# own default so a restore has a level to return to. The forced cases run
# against their own copy, whose path is one acquisition-contract row and is
# therefore one path across all of them.
printf 'auto\n' >"$signal_drm/power_dpm_force_performance_level"
forced_drm=$temporary_directory/drm-forced
cp -R -- "$signal_drm" "$forced_drm"
signal_hwmon=$temporary_directory/hwmon-signal
mkdir -p "$signal_hwmon/hwmon0"
printf 'amdgpu\n' >"$signal_hwmon/hwmon0/name"
printf '61000\n' >"$signal_hwmon/hwmon0/temp1_input"
# The delivered graphics frequency telemetry-broker.c reads beside the DPM
# steps, in the hertz the amdgpu hwmon path reports.
printf '1100000000\n' >"$signal_hwmon/hwmon0/freq1_input"

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
    QWEN_CENSUS_COOLDOWN_S=1 \
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
    verify-external-vulkan-lease.py \
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
label = os.path.basename(os.path.dirname(sys.argv[1]))
# The invariant the campaign requests under a forced clock policy.
# QWEN_TEST_CLOCK_VIOLATED names the arms whose window carried a step below the
# required one, which is the reading that costs an arm its completion.
required = None
if "--required-sclk-mhz" in sys.argv:
    required = sys.argv[sys.argv.index("--required-sclk-mhz") + 1]
required_mclk = "-"
if "--required-mclk-mhz" in sys.argv:
    required_mclk = sys.argv[sys.argv.index("--required-mclk-mhz") + 1]
violated = label in os.environ.get("QWEN_TEST_CLOCK_VIOLATED", "").split()
# QWEN_TEST_CLOCK_REFUSED names the arms whose record the validator refuses on
# its own coverage while still printing the window's clock state, which is the
# reading a refused warmup leaves in front of the regime precondition.
refused = label in os.environ.get("QWEN_TEST_CLOCK_REFUSED", "").split()
# The column the invariant was counted over. A campaign under a forced policy
# is answered by the delivered frequency alone, so the default states the
# column telemetry-broker.c writes and a case naming the DPM column stands for
# a broker built before that column existed.
source = os.environ.get("QWEN_TEST_CLOCK_SOURCE", "") or "sclk_actual_mhz"
if table and os.path.exists(table):
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
    if required is None:
        print("clock_invariant=not_requested")
    elif violated:
        print("clock_invariant=violated samples_at_required=600"
              " samples_below_required=100 below_required_fraction=0.1429"
              f" sclk_source={source} required={required}")
        print("clock_sidecar=refused failures=clock_invariant")
        raise SystemExit(1)
    else:
        print("clock_invariant=held samples_at_required=700"
              " samples_below_required=0 below_required_fraction=0.0000"
              f" sclk_source={source}"
              f" required={required} required_mclk={required_mclk}")
    if refused:
        print("clock_sidecar=refused failures=gaps")
        raise SystemExit(1)
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
# arm's reader answers the unknown triple rather than ending the campaign. One
# label named in QWEN_TEST_CENSUS_COMPLETE answers with a whole reply instead,
# which is what a case reading a verdict past the served runner needs.
# The arm runs under the closed environment census_arm_exec applies, so the
# stub reads its per-case controls from a file whose path is written into it
# here rather than from variables the arm no longer inherits, and it appends
# its own environment so a case reads what the arm was handed.
brick_arm_controls=$temporary_directory/brick-arm-controls.tsv
brick_arm_environment=$temporary_directory/brick-arm-environment.txt
: >"$brick_arm_controls"
: >"$brick_arm_environment"
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'arm_controls=%s\n' "$brick_arm_controls"
    printf 'arm_environment=%s\n' "$brick_arm_environment"
    cat <<'FAKE_SERVED_RUNNER'
arm_control() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; found = 1 }
        END { if (found) print value }' "$arm_controls"
}
env >>"$arm_environment"
# The checkpoint a case replaces under the campaign, ahead of the record this
# arm writes: the arm pins the replacement and re-establishes publisher
# identity against whichever ledger row followed it, and its byte count holds,
# so the arm's own descriptor record against the preflight digest is what
# refuses it.
if [ "$(arm_control replace_model)" = "$1" ]; then
    printf 'fixture-model-b\n' >"$2"
fi
python3 - "$2" "$QWEN_RESULT_DIRECTORY/runtime-inputs.json" <<'RUNTIME_INPUTS'
import hashlib, json, pathlib, sys
model = pathlib.Path(sys.argv[1]).read_bytes()
json.dump({"schema": "served-runtime-inputs-v1",
           "model": {"path": sys.argv[1], "bytes": len(model),
                     "sha256": hashlib.sha256(model).hexdigest()}},
          open(sys.argv[2], "w"))
RUNTIME_INPUTS
# The complete-reply set is a list, since a case reading a verdict past the
# served runner needs every arm it executes to answer.
case " $(arm_control complete) " in
    *" $1 "*)
        printf 'begin_ns\t1000000000\nend_ns\t2000000000\n' \
            >"$QWEN_RESULT_DIRECTORY/request-window.tsv"
        printf '{"timings": {"predicted_n": 65, "predicted_ms": 6400.0}}' \
            >"$QWEN_RESULT_DIRECTORY/response.json"
        # The identity arm reads the perf logger slice the served runner cut at
        # the request window, one block per decode graph, so a complete reply
        # carries the 64 blocks its own predicted_n states.
        slice_block=0
        : >"$QWEN_RESULT_DIRECTORY/server-log-request.slice"
        while [ "$slice_block" -lt 64 ]; do
            {
                printf 'Vulkan Timings:\n'
                printf 'MUL_MAT q4_K m=2048 n=1 k=2048: 1 x 100.000 us = 100.000 us\n'
                printf 'Total time: 100.000 us\n'
            } >>"$QWEN_RESULT_DIRECTORY/server-log-request.slice"
            slice_block=$((slice_block + 1))
        done
        exit 0
        ;;
esac
if [ "$(arm_control truncate)" = "$1" ]; then
    printf 'begin_ns\t1000000000\nend_ns\t2000000000\n' \
        >"$QWEN_RESULT_DIRECTORY/request-window.tsv"
    printf '{"timings": {"predicted_n": 65, "predi' \
        >"$QWEN_RESULT_DIRECTORY/response.json"
    exit 0
fi
exit 1
FAKE_SERVED_RUNNER
} >"$brick_directory/measure-served-decode.sh"
chmod +x "$brick_directory/measure-served-decode.sh"
cat >"$brick_directory/await-quiescence.sh" <<'FAKE_QUIESCENCE'
#!/bin/sh
set -eu
# The stub records its own argv, so a case reads which cooldown flags the
# campaign passed. A stub that printed a verdict alone would leave
# --sclk-forced unobservable, and that flag is what keeps a cooldown under a
# forced clock policy from running to its deadline.
if [ -n "${QWEN_TEST_QUIESCENCE_ARGV:-}" ]; then
    printf '%s\n' "$*" >>"$QWEN_TEST_QUIESCENCE_ARGV"
fi
# The converged boundary is the default, since every case reading an arm past
# the first needs the campaign to reach one. QWEN_TEST_QUIESCENCE_VERDICT names
# the other two outcomes: `timeout` prints the poller's deadline line and its
# failing predicate list on stderr, and `unreported` prints a line carrying no
# verdict at all, which is what a poller ending on a usage error leaves behind.
case ${QWEN_TEST_QUIESCENCE_VERDICT:-reached} in
    timeout)
        printf 'quiescence=timeout elapsed_ms=1234 llama_server=absent gpu_busy=0\n'
        printf 'quiescence_timeout_predicates=temp_rate,mem\n' >&2
        exit 1
        ;;
    unreported)
        printf 'await-quiescence stub printed no verdict line\n'
        exit 2
        ;;
    *)
        printf 'quiescence=reached elapsed_ms=800 llama_server=absent gpu_busy=0\n'
        exit 0
        ;;
esac
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

# The root a calibration writes over its own receipts: the acquisition contract
# it ran under and one digest per brick receipt. Reuse reads it ahead of the
# closure and the rates, so a receipt edited after its campaign no longer
# matches the row that names it.
write_prior_root() {
    root_directory=$1
    {
        printf 'calibration_root_sha256\t%s\n' \
            0000000000000000000000000000000000000000000000000000000000000000
        printf 'acquisition_contract_sha256\t%s\n' "$brick_contract_sha256"
        printf 'analysis_contract_sha256\t-\nreused_bricks\t-\n'
        for root_brick in C0 C1 C2 C3; do
            root_receipt=$root_directory/bricks/$root_brick.receipt.tsv
            [ -r "$root_receipt" ] || continue
            printf 'brick\t%s\t%s\n' "$root_brick" \
                "$(sha256sum "$root_receipt" | cut -d ' ' -f 1)"
        done
    } >"$root_directory/calibration-root.tsv"
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
    # The root follows every receipt it names, so a directory built one brick
    # at a time carries a root over the set it actually holds.
    write_prior_root "$prior_root"
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
    # The eleventh names the engine clock policy, the twelfth the arms whose
    # invariant the stub validator reports violated, the thirteenth an arm
    # label whose served runner answers a whole reply, and the fourteenth
    # stands for an expired sudo credential. A forced policy runs against its
    # own DRM fixture, since the stub sudo rewrites pp_dpm_sclk on every write
    # and a case is read after the run.
    brick_engine_clock_policy=${11:-auto}
    brick_violated_arms=${12:-}
    brick_complete_label=${13:-}
    brick_sudo_refuse=${14:-0}
    # The fifteenth names the fabric level manual writes and the sixteenth
    # stands for the firmware that takes that write and keeps its own
    # selection.
    brick_mclk_level=${15:--}
    brick_mclk_ignore=${16:-0}
    # The seventeenth names the column the stub validator reports the invariant
    # was counted over. A case leaving it unset reads the delivered frequency
    # telemetry-broker.c writes, and one naming the DPM column stands for a
    # broker built before that column existed.
    brick_clock_source=${17:-}
    # The eighteenth names the arms whose record the stub validator refuses
    # while still printing their clock state, which is the reading a refused
    # warmup leaves in front of the precondition, and the nineteenth the arm
    # after which the checkpoint is replaced under the campaign.
    brick_refused_arms=${18:-}
    brick_replace_model=${19:-}
    # The twentieth names the verdict the quiescence stub reports. A converged
    # boundary is the default, since a campaign ends at the first that is not
    # one, and `timeout` and `unreported` are the two states that end it.
    brick_quiescence_verdict=${20:-reached}
    brick_drm=$signal_drm
    brick_sudo_log=$temporary_directory/sudo-$brick_case.log
    brick_quiescence_argv=$temporary_directory/quiescence-argv-$brick_case.log
    if [ "$brick_engine_clock_policy" != auto ]; then
        # One directory serves every forced case, because its path is an
        # acquisition-contract row and a per-case copy would give each case its
        # own digest and reuse nothing. It is reset to the governor state each
        # run starts from.
        brick_drm=$forced_drm
        printf 'auto\n' >"$brick_drm/power_dpm_force_performance_level"
        printf '0: 200Mhz *\n1: 1100Mhz\n' >"$brick_drm/pp_dpm_sclk"
    fi
    active_fixture=$brick_case
    diagnostic_file=$temporary_directory/$brick_case-stderr.txt
    # The arm's own controls travel in a file rather than in the environment,
    # since census_arm_exec hands each arm a closed set.
    {
        printf 'replace_model\t%s\n' "$brick_replace_model"
        printf 'truncate\t%s\n' "$brick_truncate_label"
        printf 'complete\t%s\n' "$brick_complete_label"
    } >"$brick_arm_controls"
    set +e
    env -i \
        GGML_VK_Q4K_SIDEPLANE=0 \
        QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=65536 \
        QWEN_TEST_BROKER_SILENT="$brick_broker_silent" \
        QWEN_TEST_CLOCK_STATE="$brick_clock_state" \
        QWEN_TEST_CLOCK_TABLE="$brick_clock_table" \
        QWEN_TEST_CLOCK_VIOLATED="$brick_violated_arms" \
        QWEN_TEST_CLOCK_SOURCE="$brick_clock_source" \
        QWEN_TEST_CLOCK_REFUSED="$brick_refused_arms" \
        QWEN_TEST_SUDO_REFUSE="$brick_sudo_refuse" \
        QWEN_TEST_SUDO_LOG="$brick_sudo_log" \
        QWEN_TEST_QUIESCENCE_ARGV="$brick_quiescence_argv" \
        QWEN_TEST_QUIESCENCE_VERDICT="$brick_quiescence_verdict" \
        QWEN_CENSUS_ENGINE_CLOCK_POLICY="$brick_engine_clock_policy" \
        QWEN_CENSUS_MCLK_LEVEL="$brick_mclk_level" \
        QWEN_TEST_SUDO_MCLK_IGNORE="$brick_mclk_ignore" \
        PATH="$signal_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$brick_drm" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_HWMON_ROOT="$signal_hwmon" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_CENSUS_COOLDOWN_S=1 \
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
# and every boundary converges, so the campaign runs its whole list and ends on
# the arm failures alone.
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
if ! awk -F'\t' '$1 == "13" && $3 == "cooldown" && $6 == "quiescence=reached elapsed_ms=800 sclk_forced=0 predicates=-" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_cooldown_output/wall-clock.tsv"; then
    printf 'the cooldown row carries no quiescence verdict, elapsed time, forced-clock state, and predicate list\n' >&2
    sed -n '1,10p' "$brick_cooldown_output/wall-clock.tsv" >&2
    exit 1
fi
# The governor policy releases the graphics step on its own, so the position
# predicate still describes idle and the campaign passes no --sclk-forced.
brick_cooldown_argv=$temporary_directory/quiescence-argv-quiescence_cooldown.log
if [ ! -s "$brick_cooldown_argv" ]; then
    printf 'the auto-policy calibration invoked no cooldown poller\n' >&2
    exit 1
fi
if grep -q -- '--sclk-forced' "$brick_cooldown_argv"; then
    printf 'the auto-policy calibration passed --sclk-forced to the cooldown poller\n' >&2
    cat "$brick_cooldown_argv" >&2
    exit 1
fi
printf 'quiescence_cooldown_auto=accepted invocations=%s\n' \
    "$(wc -l <"$brick_cooldown_argv" | tr -d ' ')"
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
grep -q '^cooldown_timeouts=0$' "$brick_cooldown_output/terminal-state.tsv"
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

# The same three bricks reused with every executed arm answering, and one
# boundary that never converges: the campaign would otherwise accept on its
# three reused controls, so the boundary alone decides it. The first executed
# arm is the opening warmup, so the run ends after slot 0a: arms.tsv carries the
# boundary row naming the state, terminal-state.tsv names the slot, the arm, and
# the predicates the poller reported false, no later arm ran, and neither the
# controls summary nor a brick receipt nor a calibration root was written.
active_fixture=cooldown_blocks_acceptance
prior_settled=$temporary_directory/prior-settled
write_prior_calibration "$prior_settled"
brick_settled_output=$temporary_directory/out-cooldown-acceptance
brick_status=$(run_brick_calibration cooldown_blocks_acceptance "$prior_settled" \
    "$brick_settled_output" '' 800 2 '' '' '' '' auto '' '0a-W 0b-W 13-S' 0 - 0 '' '' '' \
    timeout)
if [ "$brick_status" -ne 5 ]; then
    printf 'a calibration whose boundary never converged exited %s where it ends at 5\n' \
        "$brick_status" >&2
    sed -n '1,20p' "$temporary_directory/cooldown_blocks_acceptance-stdout.txt" >&2
    exit 1
fi
for settled_row in arm_failures=0 census=quiescence_unconverged cooldown_timeouts=1 \
    control_accepted=- calibration_root_sha256=- terminal_slot=0a terminal_arm=W \
    terminal_detail=temp_rate,mem; do
    if ! grep -qx "$settled_row" "$brick_settled_output/terminal-state.tsv"; then
        printf 'the terminated calibration terminal state carries no %s\n' "$settled_row" >&2
        cat "$brick_settled_output/terminal-state.tsv" >&2
        grep '^census_arm=' "$temporary_directory/cooldown_blocks_acceptance-stdout.txt" >&2
        exit 1
    fi
done
if ! awk -F'\t' '$1 == "0a" && $2 == "cooldown" && $10 == "quiescence_timeout" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_settled_output/arms.tsv"; then
    printf 'arms.tsv carries no boundary row naming the terminal state\n' >&2
    cat "$brick_settled_output/arms.tsv" >&2
    exit 1
fi
# Every row of arms.tsv is rectangular under one header, the boundary row
# included, so a reader that splits on tabs reads the same arity everywhere.
if ! awk -F'\t' 'NR == 1 { want = NF; next } NF != want { exit 1 }' \
    "$brick_settled_output/arms.tsv"; then
    printf 'the boundary row broke the arms ledger arity\n' >&2
    exit 1
fi
if awk -F'\t' 'NR > 1 && $1 == "0b"' "$brick_settled_output/arms.tsv" | grep -q .; then
    printf 'an arm ran past the boundary that ended the campaign\n' >&2
    exit 1
fi
for withheld_member in summary.tsv calibration-root.tsv bricks; do
    if [ -e "$brick_settled_output/$withheld_member" ]; then
        printf 'the terminated calibration wrote %s over a truncated ledger\n' \
            "$withheld_member" >&2
        exit 1
    fi
done
grep -q '^census_cooldown=terminal slot=0a arm=W verdict=timeout predicates=temp_rate,mem$' \
    "$temporary_directory/cooldown_blocks_acceptance-stdout.txt"
diagnostic_file=
printf 'cooldown_blocks_acceptance=accepted\n'

# A poller that printed no parseable verdict is the third boundary state, and
# it ends the campaign the same way a deadline does under its own name.
active_fixture=quiescence_unreported_terminal
prior_unreported=$temporary_directory/prior-unreported
write_prior_calibration "$prior_unreported"
brick_unreported_output=$temporary_directory/out-quiescence-unreported
brick_status=$(run_brick_calibration quiescence_unreported_terminal "$prior_unreported" \
    "$brick_unreported_output" '' 800 2 '' '' '' '' auto '' '0a-W 0b-W 13-S' 0 - 0 '' '' '' \
    unreported)
if [ "$brick_status" -ne 5 ]; then
    printf 'an unreported boundary exited %s where it ends at 5\n' "$brick_status" >&2
    exit 1
fi
grep -qx 'census=quiescence_unconverged' "$brick_unreported_output/terminal-state.tsv"
grep -qx 'terminal_detail=-' "$brick_unreported_output/terminal-state.tsv"
if ! awk -F'\t' '$1 == "0a" && $2 == "cooldown" && $10 == "quiescence_unreported" { found = 1 }
    END { exit found ? 0 : 1 }' "$brick_unreported_output/arms.tsv"; then
    printf 'arms.tsv carries no boundary row for an unreported verdict\n' >&2
    cat "$brick_unreported_output/arms.tsv" >&2
    exit 1
fi
diagnostic_file=
printf 'quiescence_unreported_terminal=accepted\n'

# A receipt edited after its campaign still agrees with a ledger edited beside
# it, so the root's own digest for that brick is what refuses the reuse and
# sends its four slots back to the device.
active_fixture=brick_receipt_unbound
prior_tampered=$temporary_directory/prior-tampered
write_prior_calibration "$prior_tampered"
write_prior_receipt "$prior_tampered" C3 13 S 3.000
printf 'tampered\ttampered\n' >>"$prior_tampered/bricks/C2.receipt.tsv"
brick_tampered_output=$temporary_directory/out-brick-tampered
brick_status=$(run_brick_calibration brick_receipt_unbound "$prior_tampered" \
    "$brick_tampered_output")
if [ "$brick_status" -eq 0 ]; then
    printf 'a calibration reusing a tampered receipt accepted\n' >&2
    exit 1
fi
if ! grep -q '^census_brick_reuse=receipt_unbound brick=C2 ' \
    "$temporary_directory/brick_receipt_unbound-stdout.txt"; then
    printf 'the tampered receipt was reused without a refusal line\n' >&2
    grep '^census_brick_reuse' "$temporary_directory/brick_receipt_unbound-stdout.txt" >&2
    exit 1
fi
if grep -q '^census_brick_reuse=preflight .*C2' \
    "$temporary_directory/brick_receipt_unbound-stdout.txt"; then
    printf 'the tampered brick entered the reused set\n' >&2
    exit 1
fi
diagnostic_file=
printf 'brick_receipt_unbound=accepted\n'

# A record the validator refused states no clock for the precondition to read,
# however confidently its clock_state line names a mode: two refused warmups at
# one mode leave the regime unreached rather than settling the campaign on
# telemetry nothing accepted.
active_fixture=regime_refused_records
prior_refused=$temporary_directory/prior-refused
write_prior_calibration "$prior_refused"
brick_refused_output=$temporary_directory/out-regime-refused
brick_status=$(run_brick_calibration regime_refused_records "$prior_refused" \
    "$brick_refused_output" '' 800 2 '' '' '' '' auto '' '' 0 - 0 '' '0a-W 0b-W')
grep -q '^census_regime=record_refused slot=0a arm=W$' \
    "$temporary_directory/regime_refused_records-stdout.txt"
grep -q '^census_regime=unreached sclk_mhz=- arms=2$' \
    "$temporary_directory/regime_refused_records-stdout.txt"
diagnostic_file=
printf 'regime_refused_records=accepted status=%s\n' "$brick_status"

# A checkpoint replaced under the campaign passes the arm's own publisher check
# against the ledger row that followed it, so the preflight digest is what
# fails the arm that served it.
active_fixture=census_model_replaced
prior_model=$temporary_directory/prior-model
write_prior_calibration "$prior_model"
brick_model_output=$temporary_directory/out-model-replaced
brick_status=$(run_brick_calibration census_model_replaced "$prior_model" \
    "$brick_model_output" '' 800 2 '' '' '' '' auto '' '0a-W 0b-W 13-S' 0 - 0 '' '' 0a-W)
if [ "$brick_status" -eq 0 ]; then
    printf 'a calibration whose checkpoint was replaced accepted\n' >&2
    exit 1
fi
grep -q '^census_arm=model_replaced slot=0a arm=W ' \
    "$temporary_directory/census_model_replaced-stdout.txt"
diagnostic_file=
printf 'census_model_replaced=accepted\n'

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
grep -q '^predicted_arm_duration_s	20$' "$brick_unresolved_output/inputs.tsv"
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
    | grep -q "	status	sclk_mode_mhz	sclk_share	regime_delta	clock_invariant	below_required_fraction\$"; then
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
# A warmup slot is lettered, so the two fields that name slots and arms are
# read by key rather than the whole receipt by pattern: a digest opening `0a`
# through `0f` is hexadecimal rather than a slot, and every digest here moves
# with the scratch directory the contract names.
for unsettled_brick in C0 C1 C2; do
    if awk -F'\t' '$1 == "arm_slots" || $1 == "arms" {
            if ($2 ~ /(^| )0[a-p]( |$)/) found = 1 }
        END { exit found ? 0 : 1 }' \
        "$unsettled_output/bricks/$unsettled_brick.receipt.tsv"; then
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

# The engine clock as a control. A forced policy is validated by name, written
# through sudo, proven by the device's own selection, and restored on every
# exit; it replaces the regime precondition with one priming warmup and holds
# every arm to the invariant the validator states over its request window.
run_runner engine_clock_policy_name \
    'QWEN_CENSUS_ENGINE_CLOCK_POLICY is auto, high, profile_peak, or manual: peak' \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=peak

# The three clock rows enter the acquisition contract only where a policy is
# forced. Every retained calibration ran under the governor, and an attribution
# is refused unless its digest equals its receipt's, so an unconditional row
# would retire every receipt in the tree.
active_fixture=engine_clock_contract_rows
print_forced_contract() {
    env -i \
        PATH="$signal_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
        QWEN_DRM_DEVICE="$forced_drm" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_CENSUS_REPLICATES=2 \
        QWEN_CENSUS_ENGINE_CLOCK_POLICY="$1" \
        QWEN_CENSUS_MCLK_LEVEL=- \
        QWEN_CENSUS_PRINT_CONTRACT=1 \
        "$brick_runner" "$model_id" "$temporary_directory/out-forced-contract-$1"
}
forced_contract_output=$(print_forced_contract manual)
for forced_row in "engine_clock_policy	manual" "engine_clock_sclk_level	1" \
    "engine_clock_mclk_level	-" "engine_clock_required_sclk_mhz	1100" \
    "engine_clock_required_mclk_mhz	933" "clock_below_required_fraction	0" \
    "clock_below_mclk_floor_fraction	0.01"; do
    if ! printf '%s\n' "$forced_contract_output" | grep -qxF -- "$forced_row"; then
        printf 'the forced contract carries no row %s\n' "$forced_row" >&2
        exit 1
    fi
done
forced_contract_sha256=$(printf '%s\n' "$forced_contract_output" \
    | awk -F'\t' '$1 == "acquisition_contract_sha256" { print $2 }')
[ -n "$forced_contract_sha256" ]
auto_contract_output=$(print_forced_contract auto)
if printf '%s\n' "$auto_contract_output" | grep -q '^engine_clock_'; then
    printf 'the governor contract carries an engine clock row\n' >&2
    exit 1
fi
auto_contract_sha256=$(printf '%s\n' "$auto_contract_output" \
    | awk -F'\t' '$1 == "acquisition_contract_sha256" { print $2 }')
if [ "$auto_contract_sha256" = "$forced_contract_sha256" ]; then
    printf 'the forced and governor contracts carry one digest\n' >&2
    exit 1
fi
# The priming warmup replaces the precondition rather than lowering its cap, so
# the print states one warmup arm against the ledger's own `-`.
forced_warmup_arms=$(printf '%s\n' "$forced_contract_output" \
    | awk -F'\t' '$1 == "census_arm_count" { print $2 }')
[ "$forced_warmup_arms" = 14 ] || {
    printf 'a forced calibration at two replicates predicts %s arms of 14\n' \
        "$forced_warmup_arms" >&2
    exit 1
}
printf 'engine_clock_contract_rows=accepted forced=%s governor=%s\n' \
    "$forced_contract_sha256" "$auto_contract_sha256"

# A campaign under a forced policy. Its reused bricks are written against the
# forced contract, since the three rows move the digest a brick is closed over.
forced_prior_contract=$brick_contract_sha256
brick_contract_sha256=$forced_contract_sha256
prior_forced=$temporary_directory/prior-forced
write_prior_calibration "$prior_forced"
printf 'census=refuted\n' >"$prior_forced/terminal-state.tsv"
brick_contract_sha256=$forced_prior_contract

active_fixture=engine_clock_forced_manual
forced_output=$temporary_directory/out-engine-clock-forced
forced_status=$(run_brick_calibration engine_clock_forced_manual "$prior_forced" \
    "$forced_output" 0 800 2 '' '' 0.05 0.30 manual)
if [ "$forced_status" -ne 1 ]; then
    printf 'the manual-clock calibration exited %s where its failed arm exits 1\n' \
        "$forced_status" >&2
    sed -n '1,20p' "$temporary_directory/engine_clock_forced_manual-stderr.txt" >&2
    exit 1
fi
grep -q '^engine_clock=applied policy=manual sclk_level=1 required_sclk_mhz=1100 mclk_level=- mclk_readback_mhz=- mclk_floor_mhz=933 snapshot=auto 0 0$' \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
grep -q '^census_regime=retired policy=manual required_sclk_mhz=1100 mclk_floor_mhz=933 arms=1$' \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
grep -q "^dpm_restore=restored level=auto requested=auto sclk_level=0 mclk_level=0 node=$forced_drm/power_dpm_force_performance_level\$" \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
for forced_input_row in "engine_clock_policy	manual" "engine_clock_sclk_level	1" \
    "engine_clock_mclk_level	-" "engine_clock_required_sclk_mhz	1100" \
    "engine_clock_required_mclk_mhz	933" "clock_below_required_fraction	0" \
    "clock_below_mclk_floor_fraction	0.01" \
    "mclk_floor_mhz	933" "engine_clock_sclk_readback_mhz	1100" \
    "engine_clock_mclk_readback_mhz	-" "engine_clock_snapshot	auto 0 0" \
    "regime_max_arms	-" "regime_sclk_mhz	-" "regime_arms	1"; do
    if ! grep -qxF -- "$forced_input_row" "$forced_output/inputs.tsv"; then
        printf 'inputs.tsv carries no row %s\n' "$forced_input_row" >&2
        exit 1
    fi
done
# One priming warmup opens the ledger at slot 0a and the named arms keep the
# integer slots every brick and receipt is stated in.
[ "$(awk -F'\t' 'NR > 1 && $2 == "W" { print $1 }' "$forced_output/arms.tsv" | tr '\n' ' ')" \
    = '0a ' ]
if [ -e "$forced_output/arms/0b-W" ]; then
    printf 'the priming warmup ran a second arm\n' >&2
    exit 1
fi
[ "$(awk -F'\t' '$1 == "0a" { print $14, $15 }' "$forced_output/arms.tsv")" = 'held 0.0000' ]
# The write and the restore are the two sudo writes the campaign makes, in that
# order, and the fixture is left where the campaign found it.
[ "$(awk -F'\t' '{ print $2 }' "$temporary_directory/sudo-engine_clock_forced_manual.log" \
    | tr '\n' ' ')" = 'manual 1 auto ' ]
[ "$(cat "$forced_drm/power_dpm_force_performance_level")" = auto ]
diagnostic_file=
# The validator was handed both halves of the operating point, which the arm's
# own verdict file is what proves: a campaign requesting the graphics step
# alone would leave the fabric clock unbounded and every case above unchanged.
grep -q '^clock_invariant=held .* required=1100 required_mclk=933$' \
    "$forced_output/arms/0a-W/clock-sidecar-verdict.txt"
# A forced policy pins the graphics step at the highest one pp_dpm_sclk lists
# and holds it through idle, so the campaign passes --sclk-forced on every
# cooldown and the wall-clock note carries the state that produced the
# poller's own verdict.
forced_quiescence_argv=$temporary_directory/quiescence-argv-engine_clock_forced_manual.log
if [ ! -s "$forced_quiescence_argv" ]; then
    printf 'the manual-clock calibration invoked no cooldown poller\n' >&2
    exit 1
fi
if grep -qv -- '--sclk-forced' "$forced_quiescence_argv"; then
    printf 'a manual-clock cooldown reached the poller without --sclk-forced\n' >&2
    cat "$forced_quiescence_argv" >&2
    exit 1
fi
if ! awk -F'\t' '$3 == "cooldown" && $6 ~ /sclk_forced=1 / { found = 1 }
    END { exit found ? 0 : 1 }' "$forced_output/wall-clock.tsv"; then
    printf 'no manual-clock cooldown row records sclk_forced=1\n' >&2
    sed -n '1,10p' "$forced_output/wall-clock.tsv" >&2
    exit 1
fi
printf 'engine_clock_forced_manual=accepted sclk_level=1 required_sclk_mhz=1100\n'

# The fabric write is recorded rather than required. The appliance took the
# write and left its own selection starred, so the campaign reports the readback
# and holds the arms to the floor instead.
active_fixture=engine_clock_manual_fabric_write
fabric_output=$temporary_directory/out-engine-clock-fabric
# The fabric level is a contract row, so this run's digest is its own and it
# reuses no brick written against the graphics level alone.
fabric_status=$(run_brick_calibration engine_clock_manual_fabric_write '' \
    "$fabric_output" 0 800 2 '' '' 0.05 0.30 manual '' '' 0 1 1)
if [ "$fabric_status" -ne 1 ]; then
    printf 'the fabric-write calibration exited %s where its failed arm exits 1\n' \
        "$fabric_status" >&2
    sed -n '1,20p' "$temporary_directory/engine_clock_manual_fabric_write-stderr.txt" >&2
    exit 1
fi
grep -q '^engine_clock=applied policy=manual sclk_level=1 required_sclk_mhz=1100 mclk_level=1 mclk_readback_mhz=933 mclk_floor_mhz=933 snapshot=auto 0 0$' \
    "$temporary_directory/engine_clock_manual_fabric_write-stdout.txt"
for fabric_input_row in "engine_clock_mclk_level	1" "engine_clock_mclk_readback_mhz	933"; do
    if ! grep -qxF -- "$fabric_input_row" "$fabric_output/inputs.tsv"; then
        printf 'inputs.tsv carries no row %s\n' "$fabric_input_row" >&2
        exit 1
    fi
done
# The performance level, the graphics level, the fabric level, and the restore
# are the four sudo writes the campaign makes, in that order.
[ "$(awk -F'\t' '{ print $2 }' \
    "$temporary_directory/sudo-engine_clock_manual_fabric_write.log" \
    | tr '\n' ' ')" = 'manual 1 1 auto ' ]
diagnostic_file=
printf 'engine_clock_manual_fabric_write=accepted readback_mhz=933\n'

# One arm whose window carried a step below the pinned one. The served runner
# answers a whole reply, so the arm reaches the invariant and fails on it rather
# than on its own rate, and the ledger names the fraction the validator counted.
active_fixture=engine_clock_invariant_violated
violated_output=$temporary_directory/out-engine-clock-violated
violated_status=$(run_brick_calibration engine_clock_invariant_violated "$prior_forced" \
    "$violated_output" 0 800 2 '' '' 0.05 0.30 manual 13-S 13-S)
if [ "$violated_status" -ne 1 ]; then
    printf 'the violated-invariant calibration exited %s where its failed arm exits 1\n' \
        "$violated_status" >&2
    exit 1
fi
grep -q 'census_arm=failed slot=13 arm=S .* clock_invariant=violated reason=clock_invariant' \
    "$temporary_directory/engine_clock_invariant_violated-stdout.txt"
[ "$(awk -F'\t' '$1 == "13" { print $14, $15 }' "$violated_output/arms.tsv")" \
    = 'violated 0.1429' ]
diagnostic_file=
printf 'engine_clock_invariant_violated=accepted\n'

# One arm whose invariant was counted over the DPM column. Under a forced
# policy that column repeats the selection the campaign itself wrote, so an
# arm reading it held has agreed with the campaign rather than measured the
# device, and the runner refuses it on its instrument.
active_fixture=engine_clock_dpm_source
dpm_source_output=$temporary_directory/out-engine-clock-dpm-source
dpm_source_status=$(run_brick_calibration engine_clock_dpm_source "$prior_forced" \
    "$dpm_source_output" 0 800 2 '' '' 0.05 0.30 manual '' 13-S 0 - 0 \
    pp_dpm_sclk_selected_mhz)
if [ "$dpm_source_status" -ne 1 ]; then
    printf 'the DPM-source calibration exited %s where its failed arm exits 1\n' \
        "$dpm_source_status" >&2
    sed -n '1,20p' "$temporary_directory/engine_clock_dpm_source-stderr.txt" >&2
    exit 1
fi
grep -q '^census_clock_source=refused slot=13 arm=S source=pp_dpm_sclk_selected_mhz$' \
    "$temporary_directory/engine_clock_dpm_source-stdout.txt"
grep -q 'census_arm=failed slot=13 arm=S .* reason=clock_source' \
    "$temporary_directory/engine_clock_dpm_source-stdout.txt"
# The record itself was accepted and its invariant read held, which is what
# makes the refusal a statement about the instrument rather than the clock.
[ "$(awk -F'\t' '$1 == "13" { print $14, $15 }' "$dpm_source_output/arms.tsv")" \
    = 'held 0.0000' ]
diagnostic_file=
printf 'engine_clock_dpm_source=accepted\n'

# An expired sudo credential is refused ahead of the first arm and names the
# command that renews it, since a campaign cannot answer a password prompt.
active_fixture=engine_clock_sudo_refused
refused_output=$temporary_directory/out-engine-clock-refused
refused_status=$(run_brick_calibration engine_clock_sudo_refused "$prior_forced" \
    "$refused_output" 0 800 2 '' '' 0.05 0.30 manual '' '' 1)
if [ "$refused_status" -ne 2 ]; then
    printf 'the refused-credential calibration exited %s where it refuses with 2\n' \
        "$refused_status" >&2
    exit 1
fi
grep -q 'run sudo -v and start the campaign again' \
    "$temporary_directory/engine_clock_sudo_refused-stderr.txt"
[ "$(cat "$forced_drm/power_dpm_force_performance_level")" = auto ]
diagnostic_file=
printf 'engine_clock_sudo_refused=accepted\n'

# A terminating signal restores the level as it tears the children down. The
# campaign is signalled once it has printed the line its write produced, so the
# case reads a restore that ran from the handler rather than from a run that
# had already finished. It runs the signal fixtures, whose served runner hangs
# and whose sampler grows a record on disk.
active_fixture=engine_clock_restore_on_term
term_drm=$temporary_directory/drm-term
cp -R -- "$signal_drm" "$term_drm"
printf 'auto\n' >"$term_drm/power_dpm_force_performance_level"
term_contract_sha256=$(env -i \
    PATH="$signal_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$term_drm" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_SAMPLER=python \
    QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    QWEN_CENSUS_PRINT_CONTRACT=1 \
    "$signal_runner" "$model_id" "$temporary_directory/out-term-contract" \
    | awk -F'\t' '$1 == "calibration_contract_sha256" { print $2 }')
[ -n "$term_contract_sha256" ]
term_calibration=$temporary_directory/calibration-term
mkdir -p "$term_calibration"
write_terminal_state "$term_calibration/terminal-state.tsv" 3
write_calibration_inputs "$term_calibration/inputs.tsv" "$production_sha256" \
    "$term_contract_sha256"
term_output=$temporary_directory/out-engine-clock-term
term_stdout=$temporary_directory/engine-clock-term-stdout.txt
: >"$term_stdout"
diagnostic_file=$temporary_directory/engine-clock-term-stderr.txt
env -i \
    PATH="$signal_path" \
    HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$term_drm" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_SAMPLER=python \
    QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_HWMON_ROOT="$signal_hwmon" \
    QWEN_CENSUS_MODE=attribution \
    QWEN_CENSUS_CALIBRATION_RECEIPT="$term_calibration" \
    QWEN_CENSUS_ARMS=I0 \
    QWEN_CENSUS_COOLDOWN_S=1 \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    QWEN_TEST_SUDO_LOG="$temporary_directory/sudo-engine-clock-term.log" \
    SSH_CONNECTION="$signal_ssh_connection" \
    "$signal_runner" "$model_id" "$term_output" \
    >"$term_stdout" 2>"$diagnostic_file" &
term_runner_pid=$!
term_poll=0
while [ "$term_poll" -lt 100 ]; do
    if grep -q '^engine_clock=applied ' "$term_stdout"; then
        break
    fi
    sleep 0.2
    term_poll=$((term_poll + 1))
done
if [ "$term_poll" -ge 100 ]; then
    kill -TERM "$term_runner_pid" 2>/dev/null || true
    wait "$term_runner_pid" 2>/dev/null || true
    printf 'the signalled campaign never applied its clock policy\n' >&2
    exit 1
fi
[ "$(cat "$term_drm/power_dpm_force_performance_level")" = manual ]
kill -TERM "$term_runner_pid"
set +e
wait "$term_runner_pid"
term_status=$?
set -e
if [ "$term_status" -ne 143 ]; then
    printf 'the signalled campaign exited %s where its TERM trap exits 143\n' \
        "$term_status" >&2
    exit 1
fi
grep -q '^dpm_restore=restored level=auto requested=auto ' "$term_stdout"
[ "$(cat "$term_drm/power_dpm_force_performance_level")" = auto ]
diagnostic_file=
printf 'engine_clock_restore_on_term=accepted\n'

# The closed arm environment, read from both sides. Every executed case ran
# with GGML_VK_Q4K_SIDEPLANE and QWEN_CACHE_OVERRIDE_CONTEXT_CEILING set in the
# invoking shell: the first gates its pre-pass on getenv returning a pointer
# rather than on the value, so a 0 enables the feature a control arm is defined
# by leaving off, and the second is a QWEN_ name radv-low-priority-env.sh
# leaves alone and qwen-capacity-policy.sh reads. Neither reaches an arm's
# record, and neither reaches the served runner's own environment, which is
# what a record alone could not prove.
active_fixture=arm_environment_closed
arm_environment_failures=0
arm_records=$(find "$temporary_directory" -type f -name arm-environment.tsv | sort)
if [ -z "$arm_records" ]; then
    printf 'no arm wrote an environment record\n' >&2
    arm_environment_failures=1
fi
for arm_record in $arm_records; do
    for arm_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
        if cut -f1 "$arm_record" | grep -qx "$arm_name"; then
            printf 'ambient %s reached the arm record: %s\n' "$arm_name" \
                "$arm_record" >&2
            arm_environment_failures=1
        fi
    done
    for arm_required in PATH HOME QWEN_LLAMA_SERVER QWEN_RESULT_DIRECTORY \
        QWEN_VULKAN_EXTERNAL_LEASE_PROOF QWEN_STATE_DIRECTORY; do
        if ! cut -f1 "$arm_record" | grep -qx "$arm_required"; then
            printf 'arm environment record omits %s: %s\n' "$arm_required" \
                "$arm_record" >&2
            arm_environment_failures=1
        fi
    done
    # measure-served-decode.sh compares its inherited descriptor 8 against its
    # own QWEN_STATE_DIRECTORY's lock, so the directory the campaign locked and
    # the directory the arm resolves that lock in are one value.
    arm_state_directory=$(awk -F'\t' '$1 == "QWEN_STATE_DIRECTORY" { print $2 }' \
        "$arm_record")
    if [ "$arm_state_directory" != "$workload_lease_directory" ]; then
        printf 'arm resolves the lease in %s where the campaign locked %s: %s\n' \
            "${arm_state_directory:--}" "$workload_lease_directory" \
            "$arm_record" >&2
        arm_environment_failures=1
    fi
done
if [ ! -s "$brick_arm_environment" ]; then
    printf 'the served runner recorded no environment of its own\n' >&2
    arm_environment_failures=1
fi
for arm_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
    if grep -q "^$arm_name=" "$brick_arm_environment"; then
        printf 'ambient %s reached the served runner environment\n' "$arm_name" >&2
        arm_environment_failures=1
    fi
done
[ "$arm_environment_failures" -eq 0 ]
printf 'arm_environment_closed=accepted records=%s\n' \
    "$(printf '%s\n' "$arm_records" | grep -c .)"

# The lease as the clock's own authority. A campaign forces a DPM level every
# workload on the machine then runs at, so it takes the shared Vulkan lease
# ahead of the first write; another holder therefore refuses the campaign with
# the fixture level untouched.
active_fixture=workload_lease_held
run_index=$((run_index + 1))
lease_drm=$temporary_directory/drm-lease-held
cp -R -- "$signal_drm" "$lease_drm"
printf 'auto\n' >"$lease_drm/power_dpm_force_performance_level"
printf '0: 200Mhz *\n1: 1100Mhz\n' >"$lease_drm/pp_dpm_sclk"
# The holder ends on a flag file rather than on a signal, because a signalled
# `flock FILE COMMAND` leaves the command holding the inherited descriptor and
# the lease outlives the process the test killed.
lease_flag=$temporary_directory/lease-held
: >"$lease_flag"
(
    exec 8<>"$workload_lease"
    flock 8
    while [ -e "$lease_flag" ]; do
        sleep 0.05
    done
) &
lease_holder_pid=$!
lease_held() {
    lease_probe_status=0
    flock -n -E 75 "$workload_lease" true || lease_probe_status=$?
    [ "$lease_probe_status" -eq 75 ]
}
lease_attempt=0
while [ "$lease_attempt" -lt 200 ] && ! lease_held; do
    lease_attempt=$((lease_attempt + 1))
    sleep 0.05
done
set +e
env -i PATH="$signal_path" HOME="$home_directory" \
    SSH_CONNECTION="$signal_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_SERVER="$production_server" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_CENSUS_INSTRUMENTED_SERVER="$instrumented_server" \
    QWEN_DRM_DEVICE="$lease_drm" QWEN_HWMON_ROOT="$signal_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    "$brick_runner" "$model_id" "$temporary_directory/out-$run_index" \
    >"$temporary_directory/lease-held-stdout.txt" \
    2>"$temporary_directory/lease-held-stderr.txt"
lease_status=$?
set -e
rm -f -- "$lease_flag"
wait "$lease_holder_pid" 2>/dev/null || true
[ "$lease_status" -eq 2 ]
grep -q 'another Vulkan workload holds the shared lease' \
    "$temporary_directory/lease-held-stderr.txt"
[ "$(cat "$lease_drm/power_dpm_force_performance_level")" = auto ]
printf 'workload_lease_held=accepted\n'

active_fixture=completion
printf 'run_raven2_vulkan_kernel_census_preflight=accepted cases=%s\n' "$run_index"
