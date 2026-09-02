#!/bin/sh
set -eu

# Drive run-served-binary-ab.sh over scratch fixtures, refusal by refusal and
# then arm by arm. The refusal cases run under env -i with SSH_CONNECTION
# absent, so a fixture whose preflight passes reaches the host or session
# refusal and a fixture whose preflight refuses names its own reason; both exit
# 2 and this test reads the message to tell them apart.
#
# The executing cases run the harness from a scratch directory, because it
# resolves measure-served-decode.sh, the registry reader, the sidecar
# validator, and the quiescence poller through its own directory: the stubs
# placed there are what let a whole arm list run with no device, no server, and
# no launch chain. Each executing case supplies a hostname earlier on PATH than
# the system's own and a structurally valid SSH_CONNECTION, which is the pair
# the harness reads before its first arm.
#
# The rates the stub served runner answers with are what produce each verdict,
# and they are fixtures rather than plausible arm pairs: replicates that agree
# exactly leave a degenerate interval at their own delta, which is the only way
# a four-replicate control lands wholly on one side of a 5% bound.
#
# The clock table the stub validator reads is what drives the regime
# precondition here, and its default entry is the sustained regime the
# appliance serves in: 800 MHz at a modal share of 0.1400. `regime_reached`
# settles on the second warmup out of that table; `regime_unreached` steps the
# warmups apart, withholds one clock_state line, and pins one at a share of
# 0.62, so the precondition spends its cap and the named arms pair on their own
# comparability; `regime_boost_refused` and `regime_hovering_settles` are the
# 20260902T1417Z shape and its counterpart -- two warmups agreeing at 1100 MHz
# at a boost share of 0.60 and 0.66 settle nothing, and the same agreement at
# 0.13 settles at once, so the share ceiling is what separates the regimes;
# `off_regime_arms` reads the count a stepped run reports beside the pairs it
# lost. `truncated_reply` cuts one reply mid-object and requires the campaign
# to record a failed arm and run to its end.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$(basename "$0")" >&2
    printf 'Drives the served binary A/B harness over scratch fixtures.\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
harness=$script_directory/run-served-binary-ab.sh
registry_reader=$script_directory/model-registry.sh
artifact_ledger=$script_directory/model-artifacts.tsv
model_id=qwen38-2b-distill
candidate_patch=llama-vulkan-q4k-activation-group-sums.patch
execution_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
patch_series_sha256=1111111111111111111111111111111111111111111111111111111111111111
foreign_sha256=2222222222222222222222222222222222222222222222222222222222222222
registry_sha256=3333333333333333333333333333333333333333333333333333333333333333
ledger_row_sha256=4444444444444444444444444444444444444444444444444444444444444444
reached_preflight_end='runs on the measured host|structurally valid inherited SSH session'

temporary_directory=$(mktemp -d)
active_fixture=initialization
diagnostic_file=
run_index=0
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'served binary A/B fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            sed -n '1,40p' "$diagnostic_file" >&2
        fi
    fi
    rm -r -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

# The runtime tree the arms would launch through, and the manifest the sync
# writes beside it. Neither script runs: the stub served runner stands in for
# the whole launch chain.
runtime_remote=$temporary_directory/remote
mkdir -p "$runtime_remote"
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    printf '#!/bin/sh\nexit 1\n' >"$runtime_remote/$runtime_script"
    chmod +x "$runtime_remote/$runtime_script"
done
printf 'git_head\t%s\nremote_payload_tree_sha256\t%s\npatches_payload_tree_sha256\t%s\n' \
    "$patch_series_sha256" "$foreign_sha256" "$registry_sha256" \
    >"$temporary_directory/runtime-tree-manifest.tsv"

home_directory=$temporary_directory/home
models_directory=$temporary_directory/models
mkdir -p "$home_directory"
model_file=$("$registry_reader" id "$model_id" model_file)
mkdir -p "$models_directory/$(dirname -- "$model_file")"
: >"$models_directory/$model_file"

# The tuple the scoreboard receipt restates comes from the same readers the
# harness uses, so a registry edit moves fixture and harness together.
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

# A server is an executable bound to its manifest by byte count and digest, and
# the harness reads the compiler identity from the ELF .comment section, so each
# stub is compiled rather than written as a shell script.
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

control_root=$temporary_directory/control
candidate_root=$temporary_directory/candidate
write_server "$control_root" control
write_server "$candidate_root" candidate
control_server=$control_root/bin/llama-server
candidate_server=$candidate_root/bin/llama-server
control_sha256=$(server_digest "$control_server")
control_bytes=$(server_byte_count "$control_server")
candidate_sha256=$(server_digest "$candidate_server")
candidate_bytes=$(server_byte_count "$candidate_server")

# The two manifests differ in candidate_series and checkpoint_series_tree
# alone, which is the shape build-llama-preset.sh writes for the production
# preset with and without QWEN_LLAMA_CANDIDATE_SELECT. Every row the base build
# identity reads is equal, so the identity comparison passes and the candidate
# series comparison is what each case moves.
write_manifest() {
    manifest_path=$1
    manifest_bytes=$2
    manifest_digest=$3
    manifest_series=$4
    manifest_tree=$5
    manifest_cmake=$6
    manifest_compiler=$7
    {
        printf 'executable\tllama-server\t%s\t%s\n' "$manifest_bytes" "$manifest_digest"
        printf 'checkpoint_semantics\tnatural-boundary-v1\n'
        printf 'checkpoint_patch_series_sha256\t%s\n' "$patch_series_sha256"
        printf 'serving_eligible\tyes\n'
        printf 'commit\tf280b26983ad0fdb705a0d9ebf0503e76f2899b0\n'
        printf 'checkpoint_patch_sha256\t%s\n' "$patch_series_sha256"
        printf 'checkpoint_source_sha256\t%s\n' "$patch_series_sha256"
        printf 'compiler_flags\t%s\n' "$manifest_compiler"
        printf 'cmake_flags\t%s\n' "$manifest_cmake"
        printf 'checkpoint_series_tree\t%s\n' "$manifest_tree"
        printf 'candidate_series\t%s\n' "$manifest_series"
    } >"$manifest_path"
}

serving_cmake='-DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DLLAMA_SUBPROCESS=ON'
serving_compiler='-march=znver1 -mtune=znver1'
write_manifest "$control_root/artifact-manifest.tsv" "$control_bytes" "$control_sha256" \
    - verified "$serving_cmake" "$serving_compiler"
write_manifest "$candidate_root/artifact-manifest.tsv" "$candidate_bytes" "$candidate_sha256" \
    "$candidate_patch" verified-candidate "$serving_cmake" "$serving_compiler"

# A candidate whose manifest names the empty selection: the E4 member is
# absent, so nothing separates it from the control but its bytes.
candidate_no_member=$temporary_directory/candidate-no-member
mkdir -p "$candidate_no_member/bin"
cp -- "$candidate_server" "$candidate_no_member/bin/llama-server"
chmod +x "$candidate_no_member/bin/llama-server"
write_manifest "$candidate_no_member/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" - verified "$serving_cmake" "$serving_compiler"

# A candidate carrying the E4 member beside a second one. The series is a
# comma-joined list, so the second member leaves a comma in the field and the
# comparison isolates one patch by refusing it.
candidate_two_members=$temporary_directory/candidate-two-members
mkdir -p "$candidate_two_members/bin"
cp -- "$candidate_server" "$candidate_two_members/bin/llama-server"
chmod +x "$candidate_two_members/bin/llama-server"
write_manifest "$candidate_two_members/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "llama-vulkan-pipeline-census.patch,$candidate_patch" \
    verified-candidate "$serving_cmake" "$serving_compiler"

# A candidate built at another optimization level. The base build identity
# carries the CMake string, so the two servers no longer descend from one base
# build and the comparison refuses ahead of any arm.
candidate_profile_preset=$temporary_directory/candidate-profile-preset
mkdir -p "$candidate_profile_preset/bin"
cp -- "$candidate_server" "$candidate_profile_preset/bin/llama-server"
chmod +x "$candidate_profile_preset/bin/llama-server"
write_manifest "$candidate_profile_preset/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$candidate_patch" verified-candidate \
    '-DCMAKE_BUILD_TYPE=RelWithDebInfo -DGGML_VULKAN=ON -DLLAMA_SUBPROCESS=ON' \
    "$serving_compiler -fno-omit-frame-pointer"

# A candidate whose manifest names the census instrumentation. The E4 build is
# diagnostic-free, so an instrumented candidate would price the instrument
# beside the shader.
candidate_instrumented=$temporary_directory/candidate-instrumented
mkdir -p "$candidate_instrumented/bin"
cp -- "$candidate_server" "$candidate_instrumented/bin/llama-server"
chmod +x "$candidate_instrumented/bin/llama-server"
write_manifest "$candidate_instrumented/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$candidate_patch" verified-candidate \
    "$serving_cmake" "$serving_compiler"
printf 'instrumentation\tpipeline-census-v3\n' \
    >>"$candidate_instrumented/artifact-manifest.tsv"

# A control whose manifest carries no candidate_series row at all: the shape a
# promoted production manifest holds, the way it holds no instrumentation row.
# The absent row reads as the empty selection and the run reaches the same
# host or session refusal the written-through control does.
control_series_absent=$temporary_directory/control-series-absent
mkdir -p "$control_series_absent/bin"
cp -- "$control_server" "$control_series_absent/bin/llama-server"
chmod +x "$control_series_absent/bin/llama-server"
write_manifest "$control_series_absent/artifact-manifest.tsv" "$control_bytes" \
    "$control_sha256" - verified "$serving_cmake" "$serving_compiler"
grep -v '^candidate_series	' "$control_series_absent/artifact-manifest.tsv" \
    >"$control_series_absent/artifact-manifest.tsv.tmp"
mv -- "$control_series_absent/artifact-manifest.tsv.tmp" \
    "$control_series_absent/artifact-manifest.tsv"

# A control whose manifest carries the row twice. Two rows are ambiguous the
# way two executable rows are, and the refusal names the count.
control_series_duplicated=$temporary_directory/control-series-duplicated
mkdir -p "$control_series_duplicated/bin"
cp -- "$control_server" "$control_series_duplicated/bin/llama-server"
chmod +x "$control_series_duplicated/bin/llama-server"
write_manifest "$control_series_duplicated/artifact-manifest.tsv" "$control_bytes" \
    "$control_sha256" - verified "$serving_cmake" "$serving_compiler"
printf 'candidate_series\t-\n' >>"$control_series_duplicated/artifact-manifest.tsv"

# The scoreboard receipt: an identity check binding the control server, the
# tuple that campaign resolved, and the inputs every arm here reruns under. The
# header of identity-check.tsv is compared literally, so it is written once and
# copied into every variant.
write_identity_check() {
    identity_path=$1
    identity_digest=$2
    {
        printf 'subject\tpath\texpected_bytes\tobserved_bytes\texpected_sha256\tobserved_sha256\tstate\n'
        printf 'server\t%s\t%s\t%s\t%s\t%s\taccepted\n' \
            "$control_server" "$control_bytes" "$control_bytes" \
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
write_identity_check "$scoreboard_receipt/identity-check.tsv" "$control_sha256"
write_models_resolved "$scoreboard_receipt/models-resolved.tsv" "$batch"
write_campaign_inputs "$scoreboard_receipt/campaign-inputs.tsv" low-async

# A receipt whose one server row names another digest: the control is not the
# server the scoreboard measured its denominator with.
scoreboard_foreign=$temporary_directory/scoreboard-foreign
cp -R -- "$scoreboard_receipt" "$scoreboard_foreign"
write_identity_check "$scoreboard_foreign/identity-check.tsv" "$foreign_sha256"

# A receipt whose resolved tuple no longer equals the registry's.
scoreboard_batch=$temporary_directory/scoreboard-batch
cp -R -- "$scoreboard_receipt" "$scoreboard_batch"
write_models_resolved "$scoreboard_batch/models-resolved.tsv" "$((batch + 1))"

# A receipt whose campaign ran under another submission profile.
scoreboard_profile=$temporary_directory/scoreboard-profile
cp -R -- "$scoreboard_receipt" "$scoreboard_profile"
write_campaign_inputs "$scoreboard_profile/campaign-inputs.tsv" low-serialized

# The sampler the broker path launches per arm: telemetry-broker opens its
# surfaces, prints one readiness line on stderr, samples until SIGTERM, and
# formats the record at drain. The stub reproduces the launch contract the
# harness depends on and leaves the device out.
broker_stub=$temporary_directory/telemetry-broker
cat >"$broker_stub" <<'BROKER_STUB'
#!/bin/sh
set -eu
printf 'telemetry_broker=ready pid=%s period_ns=10000000 nice=19 cpu_affinity=0 ring_samples=1 ring_bytes=40\n' \
    "$$" >&2
printf 'sample\n' >"$1"
trap 'exit 0' TERM
broker_iterations=0
while [ "$broker_iterations" -lt 600 ]; do
    sleep 0.2
    broker_iterations=$((broker_iterations + 1))
done
BROKER_STUB
chmod +x "$broker_stub"

# The DRM surfaces the harness reads at campaign start. pp_dpm_fclk stays
# empty, which is the SMU10 state the unavailable-column allowance covers.
fixture_drm=$temporary_directory/drm
mkdir -p "$fixture_drm"
printf '0: 200Mhz\n1: 1100Mhz *\n' >"$fixture_drm/pp_dpm_sclk"
printf '0: 933Mhz *\n1: 1067Mhz\n' >"$fixture_drm/pp_dpm_mclk"
: >"$fixture_drm/pp_dpm_fclk"
printf '37\n' >"$fixture_drm/gpu_busy_percent"
fixture_hwmon=$temporary_directory/hwmon
mkdir -p "$fixture_hwmon/hwmon0"
printf 'amdgpu\n' >"$fixture_hwmon/hwmon0/name"
printf '61000\n' >"$fixture_hwmon/hwmon0/temp1_input"
# The delivered graphics frequency telemetry-broker.c reads beside the DPM
# steps, in the hertz the amdgpu hwmon path reports.
printf '1100000000\n' >"$fixture_hwmon/hwmon0/freq1_input"

run_harness() {
    harness_case=$1
    harness_expectation=$2
    shift 2
    active_fixture=$harness_case
    run_index=$((run_index + 1))
    diagnostic_file=$temporary_directory/$harness_case-stderr.txt
    set +e
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        "$@" \
        "$harness" "$control_server" "$candidate_server" "$model_id" \
        "$temporary_directory/out-$run_index" \
        >"$temporary_directory/$harness_case-stdout.txt" 2>"$diagnostic_file"
    harness_status=$?
    set -e
    if [ "$harness_status" -ne 2 ]; then
        printf 'expected exit 2, observed %s\n' "$harness_status" >&2
        return 1
    fi
    if ! grep -Eq "$harness_expectation" "$diagnostic_file"; then
        printf 'expected a message matching %s\n' "$harness_expectation" >&2
        return 1
    fi
    printf '%s=accepted\n' "$harness_case"
    diagnostic_file=
}

# The argument count is the first gate, and it names the four positional
# arguments rather than the environment.
active_fixture=usage
set +e
"$harness" "$control_server" "$candidate_server" "$model_id" \
    >"$temporary_directory/usage-stdout.txt" 2>"$temporary_directory/usage-stderr.txt"
usage_status=$?
set -e
[ "$usage_status" -eq 2 ]
grep -q '^usage: .*CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIRECTORY$' \
    "$temporary_directory/usage-stderr.txt"
printf 'usage=accepted\n'

# The whole preflight passes with the fixtures as written, so the run ends at
# the host name or the inherited session; every case below moves one input and
# reads its own refusal instead.
run_harness preflight_complete "$reached_preflight_end"

run_harness control_digest_mismatch 'does not carry one accepted server row' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_foreign/identity-check.tsv"
run_harness scoreboard_tuple \
    'a tuple other than the one the registry and ledger resolve now' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_batch/identity-check.tsv"
run_harness scoreboard_profile 'campaign inputs state a profile' \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_profile/identity-check.tsv"

run_candidate() {
    candidate_case=$1
    candidate_expectation=$2
    candidate_root_path=$3
    active_fixture=$candidate_case
    run_index=$((run_index + 1))
    diagnostic_file=$temporary_directory/$candidate_case-stderr.txt
    set +e
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        "$harness" "$control_server" "$candidate_root_path/bin/llama-server" \
        "$model_id" "$temporary_directory/out-$run_index" \
        >"$temporary_directory/$candidate_case-stdout.txt" 2>"$diagnostic_file"
    candidate_status=$?
    set -e
    [ "$candidate_status" -eq 2 ]
    grep -Eq "$candidate_expectation" "$diagnostic_file"
    printf '%s=accepted\n' "$candidate_case"
    diagnostic_file=
}

run_candidate candidate_without_e4_member \
    "must name candidate_series $candidate_patch alone" "$candidate_no_member"
run_candidate candidate_two_members \
    "must name candidate_series $candidate_patch alone" "$candidate_two_members"
run_candidate candidate_profile_preset 'descend from different base builds' \
    "$candidate_profile_preset"
run_candidate candidate_instrumented \
    'the candidate manifest names instrumentation' "$candidate_instrumented"

run_control() {
    control_case=$1
    control_expectation=$2
    control_root_path=$3
    active_fixture=$control_case
    run_index=$((run_index + 1))
    diagnostic_file=$temporary_directory/$control_case-stderr.txt
    set +e
    env -i \
        PATH="$execution_path" \
        HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        "$harness" "$control_root_path/bin/llama-server" "$candidate_server" \
        "$model_id" "$temporary_directory/out-$run_index" \
        >"$temporary_directory/$control_case-stdout.txt" 2>"$diagnostic_file"
    control_status=$?
    set -e
    [ "$control_status" -eq 2 ]
    grep -Eq "$control_expectation" "$diagnostic_file"
    printf '%s=accepted\n' "$control_case"
    diagnostic_file=
}

# An absent candidate_series row on the control reads as the empty selection,
# the way it reads on a promoted production manifest, so preflight passes and
# the run reaches the host name or session refusal like the written-through
# control does.
run_control control_series_absent "$reached_preflight_end" "$control_series_absent"
# Two rows are ambiguous the way two executable rows are, and the refusal
# names the count the manifest carries.
run_control control_series_duplicated \
    'the control manifest holds 2 candidate_series rows where one or none is admitted' \
    "$control_series_duplicated"

active_fixture=replicate_count
run_index=$((run_index + 1))
set +e
env -i PATH="$execution_path" HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_AB_REPLICATES=3 \
    "$harness" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$temporary_directory/replicate-stderr.txt"
replicate_status=$?
set -e
[ "$replicate_status" -eq 2 ]
grep -q 'QWEN_AB_REPLICATES is an even count from 2 through 8' \
    "$temporary_directory/replicate-stderr.txt"
printf 'replicate_count=accepted\n'

# The bound is the promotion rule rather than a tolerance around it, so a zero
# bound would promote any interval whose low end clears zero.
active_fixture=zero_bound
run_index=$((run_index + 1))
set +e
env -i PATH="$execution_path" HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_AB_BOUND=0 \
    "$harness" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$temporary_directory/zero-bound-stderr.txt"
zero_bound_status=$?
set -e
[ "$zero_bound_status" -eq 2 ]
grep -q 'QWEN_AB_BOUND must exceed zero' "$temporary_directory/zero-bound-stderr.txt"
printf 'zero_bound=accepted\n'

# The arm list is generated from the replicate count rather than written down,
# so the plan print states what a run would execute: one mirrored quadruple per
# two replicates, opened by the warmup arm.
print_plan() {
    plan_replicates=$1
    run_index=$((run_index + 1))
    env -i PATH="$execution_path" HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_AB_REPLICATES="$plan_replicates" QWEN_AB_PRINT_PLAN=1 \
        "$harness" "$control_server" "$candidate_server" "$model_id" \
        "$temporary_directory/out-$run_index"
}
active_fixture=arm_list_two
plan_two=$(print_plan 2 | awk -F'\t' '$1 == "served_ab_arms" { print $2 }')
[ "$plan_two" = 'W C K K C' ] || {
    printf 'two replicates generated [%s]\n' "$plan_two" >&2
    exit 1
}
printf 'arm_list_two=accepted\n'
active_fixture=arm_list_four
plan_four=$(print_plan 4 | awk -F'\t' '$1 == "served_ab_arms" { print $2 }')
[ "$plan_four" = 'W C K K C C K K C' ] || {
    printf 'four replicates generated [%s]\n' "$plan_four" >&2
    exit 1
}
printf 'arm_list_four=accepted\n'
# The plan names one W as the shape the list opens on and states the cap the
# precondition may spend beside it, so a reader knows the run may pay sixteen
# warmups where the arm list shows one.
active_fixture=arm_list_warmup_cap
plan_warmups=$(print_plan 4 | awk -F'\t' '$1 == "served_ab_warmup_arms" { print $2 }')
[ "$plan_warmups" = 16 ] || {
    printf 'the plan states a warmup cap of [%s]\n' "$plan_warmups" >&2
    exit 1
}
printf 'arm_list_warmup_cap=accepted cap=16\n'

# The executing tree. The harness resolves its served runner, its readers, and
# its quiescence poller through its own directory, so the stubs live beside a
# copy of it. The registry reader and its ledgers are linked from the tree and
# the artifact ledger is copied, because the harness refuses a linked ledger by
# its own -L test.
run_directory=$temporary_directory/run
mkdir -p "$run_directory"
run_harness_path=$run_directory/run-served-binary-ab.sh
cp -- "$harness" "$run_harness_path"
chmod +x "$run_harness_path"
cp -- "$artifact_ledger" "$run_directory/model-artifacts.tsv"
for linked_member in model-registry.sh models.tsv ctx-checkpoints.tsv \
    validated-tuples.tsv quarantine.tsv draft-pairs.tsv census-arm-lib.sh \
    summarize-census-controls.py sample-clock-sidecar.py \
    telemetry-broker.c build-telemetry-broker.sh; do
    ln -s -- "$script_directory/$linked_member" "$run_directory/$linked_member"
done

# The served runner an arm reaches. It reads the rate its arm is to answer with
# from the case's own table, writes the timings the harness derives tok_s from,
# and writes the request window the sidecar validator is bounded by. A rate of
# `fail` leaves no response at all, which is the arm failure a case reads, and
# a rate of `truncate` leaves a reply cut mid-object, which is what a runner
# killed while writing leaves behind.
cat >"$run_directory/measure-served-decode.sh" <<'FAKE_SERVED_RUNNER'
#!/bin/sh
set -eu
arm_label=$1
served_rate=$(awk -F'\t' -v label="$arm_label" '$1 == label { print $2 }' \
    "$QWEN_TEST_AB_RATES")
printf 'begin_ns\t1000000000\nend_ns\t2000000000\n' \
    >"$QWEN_RESULT_DIRECTORY/request-window.tsv"
if [ "$served_rate" = fail ]; then
    exit 1
fi
if [ "$served_rate" = truncate ]; then
    printf '{"timings": {"predicted_n": 65, "predi' \
        >"$QWEN_RESULT_DIRECTORY/response.json"
    exit 0
fi
python3 - "$served_rate" >"$QWEN_RESULT_DIRECTORY/response.json" <<'PY'
import json, sys
rate = float(sys.argv[1])
json.dump({"timings": {"predicted_n": 65, "predicted_ms": 64000.0 / rate}},
          sys.stdout)
PY
FAKE_SERVED_RUNNER
chmod +x "$run_directory/measure-served-decode.sh"

# The sidecar validator stands in for itself: it accepts the stub broker's
# record and states the selected graphics clock the case's own table names for
# that arm, which is what puts a clock state in arms.tsv where no device
# sampled one.
cat >"$run_directory/validate-clock-sidecar.py" <<'VALIDATOR_STUB'
#!/usr/bin/env python3
import os
import pathlib
import sys

label = pathlib.Path(sys.argv[1]).parent.name
# The invariant the campaign requests under a forced clock policy. The table
# QWEN_TEST_AB_VIOLATED names the arms whose window carried a step below the
# required one, which is the reading that costs an arm its completion.
required = None
if "--required-sclk-mhz" in sys.argv:
    required = sys.argv[sys.argv.index("--required-sclk-mhz") + 1]
required_mclk = "-"
if "--required-mclk-mhz" in sys.argv:
    required_mclk = sys.argv[sys.argv.index("--required-mclk-mhz") + 1]
violated = label in os.environ.get("QWEN_TEST_AB_VIOLATED", "").split()
# A table entry is a mode, a mode and its modal share separated by a colon, or
# the word `none`, which stands for a window the validator read no clock state
# out of -- the shape a warmup whose request never ran produces on the
# appliance, and the one that resets the precondition's pair.
state = "800"
share = "0.1400"
table = os.environ.get("QWEN_TEST_AB_CLOCKS", "")
if table and os.path.exists(table):
    for line in open(table):
        name, _, value = line.rstrip("\n").partition("\t")
        if name == label:
            state, _, entry_share = value.partition(":")
            if entry_share:
                share = entry_share
print(f"record_readable=accepted path={sys.argv[1]}")
if state != "none":
    print(f"clock_state=measured window_samples=700 sclk_mode_mhz={state}"
          f" sclk_share={share} mclk_mode_mhz=1067"
          " temp_mean_c=71.6 temp_max_c=74.0 busy_mean=94.88")
if required is None:
    print("clock_invariant=not_requested")
elif violated:
    print(f"clock_invariant=violated samples_at_required=600 samples_below_required=100"
          f" below_required_fraction=0.1429 required={required}")
    print("clock_sidecar=refused failures=clock_invariant")
    raise SystemExit(1)
else:
    print(f"clock_invariant=held samples_at_required=700 samples_below_required=0"
          f" below_required_fraction=0.0000 required={required}"
          f" required_mclk={required_mclk}")
print("clock_sidecar=accepted failures=-")
VALIDATOR_STUB
chmod +x "$run_directory/validate-clock-sidecar.py"

# The quiescence poller samples a device, so it is stubbed; the harness reads
# its printed line rather than its own clock.
cat >"$run_directory/await-quiescence.sh" <<'FAKE_QUIESCENCE'
#!/bin/sh
set -eu
printf 'quiescence=reached elapsed_ms=12 llama_server=absent gpu_busy=0\n'
FAKE_QUIESCENCE
chmod +x "$run_directory/await-quiescence.sh"

# The hostname the harness reads before its first arm, earlier on PATH than the
# system's own, beside a structurally valid inherited session.
run_bin=$temporary_directory/run-bin
mkdir -p "$run_bin"
printf '#!/bin/sh\nprintf %s\n' "'hp14-dk1xxx\\n'" >"$run_bin/hostname"
chmod +x "$run_bin/hostname"

# The privileged writer the forced clock policy goes through. The stub answers
# `sudo -n true` and `sudo -n tee NODE`, records every write, and keeps the
# fixture DRM directory consistent with what it was told: a policy other than
# auto stars the highest step pp_dpm_sclk lists, which is what the campaign
# confirms after its write, and auto stars the lowest, which is the governor
# state the restore returns the fixture to. QWEN_TEST_SUDO_REFUSE stands for an
# expired credential, and QWEN_TEST_SUDO_STAR_LOWEST for a forced policy the
# device declined to follow.
cat >"$run_bin/sudo" <<'SUDO_STUB'
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
chmod +x "$run_bin/sudo"
run_path=$run_bin:$execution_path
run_ssh_connection='127.0.0.1 40000 127.0.0.1 22'

# One rate table per verdict. A slot answers the rate its arm name and position
# are given here, and the mirrored quadruple gives each replicate its reverse.
# The warmup arms occupy the lettered slots 0a through 0p, so the table names
# every one the precondition's own cap admits: a case that settles in two
# leaves the rest unread, and a case that reaches the cap finds a rate at each.
write_rates() {
    rates_path=$1
    control_rate=$2
    first_candidate_rate=$3
    second_candidate_rate=$4
    {
        for rates_letter in a b c d e f g h i j k l m n o p; do
            printf '0%s-W\t%s\n' "$rates_letter" "$control_rate"
        done
        printf '01-C\t%s\n02-K\t%s\n03-K\t%s\n04-C\t%s\n' \
            "$control_rate" "$first_candidate_rate" "$second_candidate_rate" "$control_rate"
        printf '05-C\t%s\n06-K\t%s\n07-K\t%s\n08-C\t%s\n' \
            "$control_rate" "$first_candidate_rate" "$second_candidate_rate" "$control_rate"
    } >"$rates_path"
}

run_ab() {
    ab_case=$1
    ab_expected_status=$2
    ab_expected_verdict=$3
    ab_rates=$4
    ab_clocks=$5
    # The sixth caps the regime precondition, so a case that settles nothing
    # pays four warmups rather than the shipped sixteen.
    ab_regime_max_arms=${6:-16}
    # The seventh names the engine clock policy, the eighth the arms whose
    # invariant the stub validator reports violated. A forced policy runs
    # against its own copy of the DRM fixture, since the stub sudo rewrites
    # pp_dpm_sclk on every write and a case is read after the run.
    ab_engine_clock_policy=${7:-auto}
    ab_violated_arms=${8:-}
    # The ninth names the fabric level manual writes and the tenth stands for
    # the firmware that takes that write and keeps its own selection.
    ab_mclk_level=${9:--}
    ab_mclk_ignore=${10:-0}
    active_fixture=$ab_case
    run_index=$((run_index + 1))
    ab_output=$temporary_directory/out-$run_index
    ab_drm=$fixture_drm
    ab_sudo_log=$temporary_directory/sudo-$ab_case.log
    if [ "$ab_engine_clock_policy" != auto ]; then
        ab_drm=$temporary_directory/drm-$ab_case
        cp -R -- "$fixture_drm" "$ab_drm"
        printf 'auto\n' >"$ab_drm/power_dpm_force_performance_level"
    fi
    diagnostic_file=$temporary_directory/$ab_case-stderr.txt
    set +e
    env -i \
        PATH="$run_path" \
        HOME="$home_directory" \
        SSH_CONNECTION="$run_ssh_connection" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$ab_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_AB_COOLDOWN_S=0 \
        QWEN_VULKAN_WORKLOAD_LOCK="$temporary_directory/vulkan-workload.lock" \
        QWEN_TEST_AB_RATES="$ab_rates" \
        QWEN_TEST_AB_CLOCKS="$ab_clocks" \
        QWEN_TEST_AB_VIOLATED="$ab_violated_arms" \
        QWEN_TEST_SUDO_LOG="$ab_sudo_log" \
        QWEN_CENSUS_ENGINE_CLOCK_POLICY="$ab_engine_clock_policy" \
        QWEN_CENSUS_MCLK_LEVEL="$ab_mclk_level" \
        QWEN_TEST_SUDO_MCLK_IGNORE="$ab_mclk_ignore" \
        QWEN_CENSUS_REGIME_MAX_ARMS="$ab_regime_max_arms" \
        "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
        "$ab_output" \
        >"$temporary_directory/$ab_case-stdout.txt" 2>"$diagnostic_file"
    ab_status=$?
    set -e
    if [ "$ab_status" -ne "$ab_expected_status" ]; then
        printf 'expected exit %s, observed %s\n' "$ab_expected_status" "$ab_status" >&2
        sed -n '1,20p' "$temporary_directory/$ab_case-stdout.txt" >&2
        return 1
    fi
    ab_observed_verdict=$(awk -F'=' '$1 == "served_ab" { print $2 }' \
        "$ab_output/terminal-state.tsv")
    if [ "$ab_observed_verdict" != "$ab_expected_verdict" ]; then
        printf 'expected verdict %s, observed %s\n' \
            "$ab_expected_verdict" "$ab_observed_verdict" >&2
        return 1
    fi
    if ! grep -q "^served_ab=$ab_expected_verdict mean_delta=.* ci=\[.*,.*\] comparable_pairs=" \
        "$temporary_directory/$ab_case-stdout.txt"; then
        printf 'the terminal line does not carry the verdict, the mean, the interval, and the pair count\n' >&2
        sed -n '1,40p' "$temporary_directory/$ab_case-stdout.txt" >&2
        return 1
    fi
    printf '%s=accepted exit=%s\n' "$ab_case" "$ab_status"
    diagnostic_file=
    ab_last_output=$ab_output
}

# Every arm holds the sustained regime's own clock at its own modal share --
# 800 MHz at 0.1400, the stub validator's defaults -- so the precondition
# settles on the second warmup, every pair is comparable, and the verdict is
# the interval's own.
one_clock=$temporary_directory/clocks-one-state
: >"$one_clock"

# A candidate 10% faster on every replicate: the interval is degenerate at
# +0.1000, wholly above the 5% bound, and the run promotes.
promoted_rates=$temporary_directory/rates-promoted
write_rates "$promoted_rates" 10.000 11.000 11.000
run_ab verdict_promoted 0 promoted "$promoted_rates" "$one_clock"
active_fixture=arms_ledger_columns
[ "$(head -n 1 "$ab_last_output/arms.tsv")" = "$(printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\tsclk_mode_mhz\tsclk_share\tregime_delta\tclock_invariant\tbelow_required_fraction')" ]
awk -F'\t' 'NF != 15 { exit 1 }' "$ab_last_output/arms.tsv"
# The clock columns trail the ledger and read the unknown value under the
# appliance's own governor, where the validator requests no invariant.
[ "$(awk -F'\t' 'NR > 1 && ($14 != "-" || $15 != "-")' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
# Every arm of the one-clock table holds 800 MHz at a share of 0.1400, inside
# the sustained regime's own window, so the precondition settles on the second
# warmup and the ledger carries the header, two warmups, and the eight paired
# arms.
[ "$(awk 'END { print NR }' "$ab_last_output/arms.tsv")" = 11 ]
# The warmups open the ledger at the lettered slots with the sampler on,
# because their clock state is what the precondition reads, and enter no pair;
# the summarizer's own filter is what keeps them out.
[ "$(awk -F'\t' 'NR == 2 { print $1, $2, $8, $11, $13 }' "$ab_last_output/arms.tsv")" = '0a W on 800 -' ]
[ "$(awk -F'\t' 'NR == 3 { print $1, $2, $8, $11, $13 }' "$ab_last_output/arms.tsv")" = '0b W on 800 -' ]
[ "$(awk -F'\t' 'NR == 4 { print $1, $2, $8, $11, $12 }' "$ab_last_output/arms.tsv")" = '1 C on 800 0.1400' ]
[ "$(awk -F'\t' 'NR == 4 { print $7, $9, $13 }' "$ab_last_output/arms.tsv")" = '- - +0.0000' ]
printf 'arms_ledger_columns=accepted\n'

# The precondition is what the campaign opens on, and its outcome is recorded
# in inputs.tsv rather than derived from the arm list a reader is left to
# count. Two consecutive warmups at one mode inside the band settle it.
active_fixture=regime_reached
grep -q '^census_regime=reached sclk_mhz=800.0 arms=2$' \
    "$temporary_directory/verdict_promoted-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t800.0')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t2')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'sclk_band\t0.06')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'regime_min_share\t0.05')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'regime_max_share\t0.30')" "$ab_last_output/inputs.tsv"
# The named arms sat on the regime, so no arm of the served-ab control is
# counted outside the band.
[ "$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" { print $(column["off_regime_arms"]) }' \
    "$ab_last_output/summary.tsv")" = 0 ]
printf 'regime_reached=accepted arms=2\n'
active_fixture=promoted_interval
promoted_summary=$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" { print $(column["replicates"]), $(column["mean_delta"]), $(column["ci_low"]), $(column["bound"]) }' \
    "$ab_last_output/summary.tsv")
[ "$promoted_summary" = '4 +0.1000 +0.1000 0.05' ] || {
    printf 'promoted summary reads [%s]\n' "$promoted_summary" >&2
    exit 1
}
printf 'promoted_interval=accepted\n'

# A candidate that measures the control's own rate: the interval is degenerate
# at zero, wholly below the bound, and a candidate merely no faster than the
# control is refuted the way a slower one is.
refuted_rates=$temporary_directory/rates-refuted
write_rates "$refuted_rates" 10.000 10.000 10.000
run_ab verdict_refuted 3 refuted "$refuted_rates" "$one_clock"

# Replicates at +2% and +8%: the mean sits on the bound and the interval spans
# it, which resolves neither direction.
unresolved_rates=$temporary_directory/rates-unresolved
write_rates "$unresolved_rates" 10.000 10.200 10.800
run_ab verdict_unresolved 4 unresolved "$unresolved_rates" "$one_clock"

# The governor stepped between the control and candidate arms of every pair, so
# each measures the step rather than the binary and the control is left with
# fewer than two comparable pairs.
stepped_clocks=$temporary_directory/clocks-stepped
{
    printf '02-K\t1100\n03-K\t1100\n06-K\t1100\n07-K\t1100\n'
} >"$stepped_clocks"
run_ab verdict_state_changed 4 state-changed "$promoted_rates" "$stepped_clocks"
# The warmups settled on 800 and every candidate arm ran at the boost clock, so
# each candidate arm sits 27.27% off the regime and the control says so beside
# the pairs it lost to the same step.
active_fixture=off_regime_arms
[ "$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" { print $(column["off_regime_arms"]) }' \
    "$ab_last_output/summary.tsv")" = 4 ]
[ "$(awk -F'\t' '$1 == "2" { print $13 }' "$ab_last_output/arms.tsv")" = '+0.2727' ]
[ "$(awk -F'\t' '$1 == "1" { print $13 }' "$ab_last_output/arms.tsv")" = '+0.0000' ]
printf 'off_regime_arms=accepted count=4\n'

# The precondition spends the cap and settles nothing where no two consecutive
# warmups both agree and sit inside the share window. Two modes step apart by
# more than the band, one warmup reports a window the validator read no clock
# state out of, and one holds a clock that agrees with its predecessor's at a
# modal share of 0.62 -- the pinned boost signature -- so the pair resets at
# each and the run reaches slot 1 with regime_sclk_mhz unrecorded. The named
# arms still pair on their own comparability, so the verdict is the promotion
# the rates carry.
unsettled_clocks=$temporary_directory/clocks-unsettled
{
    printf '0a-W\t1100\n0b-W\tnone\n0c-W\t800\n0d-W\t812:0.62\n'
} >"$unsettled_clocks"
run_ab regime_unreached 0 promoted "$promoted_rates" "$unsettled_clocks" 4
active_fixture=regime_unreached_ledger
grep -q '^census_regime=unreached sclk_mhz=- arms=4$' \
    "$temporary_directory/regime_unreached-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t-')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'regime_arms\t4')" "$ab_last_output/inputs.tsv"
# Four warmups, eight paired arms, and the header.
[ "$(awk 'END { print NR }' "$ab_last_output/arms.tsv")" = 13 ]
[ "$(awk -F'\t' 'NR > 1 && $2 == "W"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 4 ]
# The warmup whose validator printed no clock state carries the unknown mode
# and shares the fate of an unusable reading rather than pairing across it.
[ "$(awk -F'\t' '$1 == "0b" { print $11, $12 }' "$ab_last_output/arms.tsv")" = '- -' ]
[ "$(awk -F'\t' '$1 == "0d" { print $11, $12 }' "$ab_last_output/arms.tsv")" = '812 0.62' ]
# An unreached regime leaves every named arm without a distance to it, and the
# control counts no arm outside a band it has no centre for.
[ "$(awk -F'\t' 'NR > 1 && $2 != "W" && $13 != "-"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
[ "$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" { print $(column["off_regime_arms"]) }' \
    "$ab_last_output/summary.tsv")" = 0 ]
# The warmups enter no pair and no slot a quadruple is stated in, whatever
# their count: the named arms still run 1 through 8.
if awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["outer"]) == "W" || $(column["inner"]) == "W" { found = 1 }
    END { exit found ? 0 : 1 }' "$ab_last_output/summary.tsv"; then
    printf 'a warmup arm entered a control pair\n' >&2
    exit 1
fi
[ "$(awk -F'\t' 'NR > 1 && $2 != "W" { print $1 }' "$ab_last_output/arms.tsv" | tr '\n' ' ')" \
    = '1 2 3 4 5 6 7 8 ' ]
if [ -e "$ab_last_output/arms/00-W" ]; then
    printf 'a warmup claimed a numbered slot directory\n' >&2
    exit 1
fi
printf 'regime_unreached=accepted arms=4\n'

# The 20260902T1417Z shape: two warmups pinned at 1100 MHz, agreeing inside any
# band, at the modal share boost holds. The share ceiling is the only rule that
# declines them, and declining them is the whole point of the precondition,
# since the served appliance runs in the sustained regime alone.
boost_clocks=$temporary_directory/clocks-boost
{
    printf '0a-W\t1100:0.60\n0b-W\t1100:0.66\n'
    printf '0c-W\t1100:0.55\n0d-W\t1100:0.68\n'
} >"$boost_clocks"
run_ab regime_boost_refused 0 promoted "$promoted_rates" "$boost_clocks" 4
active_fixture=regime_boost_refused_ledger
grep -q '^census_regime=unreached sclk_mhz=- arms=4$' \
    "$temporary_directory/regime_boost_refused-stdout.txt"
[ "$(awk -F'\t' '$1 == "0a" { print $11, $12 }' "$ab_last_output/arms.tsv")" = '1100 0.60' ]
[ "$(awk -F'\t' '$1 == "0b" { print $11, $12 }' "$ab_last_output/arms.tsv")" = '1100 0.66' ]
# The same two clocks at the sustained regime's own share settle on the second
# arm, so the ceiling rather than the band or the arm count refused the pair.
hovering_clocks=$temporary_directory/clocks-hovering
printf '0a-W\t800:0.13\n0b-W\t812:0.13\n' >"$hovering_clocks"
run_ab regime_hovering_settles 0 promoted "$promoted_rates" "$hovering_clocks" 4
active_fixture=regime_hovering_ledger
grep -q '^census_regime=reached sclk_mhz=806.0 arms=2$' \
    "$temporary_directory/regime_hovering_settles-stdout.txt"
grep -qxF "$(printf 'regime_sclk_mhz\t806.0')" "$ab_last_output/inputs.tsv"
printf 'regime_share_window=accepted boost=unreached hovering=806.0\n'

# A reply the served runner never finished writing is unreadable rather than
# absent: the arm answers the unknown triple, fails on its missing rate, and
# the campaign records that rather than ending mid-arm on the reader's own
# failure.
truncated_rates=$temporary_directory/rates-truncated
sed 's/^02-K\t.*/02-K\ttruncate/' "$promoted_rates" >"$truncated_rates"
active_fixture=truncated_reply
run_index=$((run_index + 1))
truncated_output=$temporary_directory/out-$run_index
set +e
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$temporary_directory/vulkan-workload.lock" \
    QWEN_TEST_AB_RATES="$truncated_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$truncated_output" \
    >"$temporary_directory/truncated-reply-stdout.txt" \
    2>"$temporary_directory/truncated-reply-stderr.txt"
truncated_status=$?
set -e
[ "$truncated_status" -eq 1 ]
grep -q '^served_ab_arm=failed slot=2 arm=K tok_s=- .* reason=served_runner$' \
    "$temporary_directory/truncated-reply-stdout.txt"
# The campaign ran to its end rather than stopping at the unreadable reply.
[ "$(awk -F'\t' 'NR > 1 && $2 != "W" { print $1 }' "$truncated_output/arms.tsv" | tr '\n' ' ')" \
    = '1 2 3 4 5 6 7 8 ' ]
[ "$(awk -F'=' '$1 == "arm_failures" { print $2 }' "$truncated_output/terminal-state.tsv")" = 1 ]
[ "$(awk -F'\t' '$1 == "2" { print $4, $5, $6 }' "$truncated_output/arms.tsv")" = '- - -' ]
printf 'truncated_reply=accepted\n'

# One arm whose served runner refuses: the control cannot report a rate verdict
# over a set an arm is missing from, so the run fails ahead of the verdict
# branches.
failed_rates=$temporary_directory/rates-failed
sed 's/^06-K\t.*/06-K\tfail/' "$promoted_rates" >"$failed_rates"
active_fixture=verdict_failed
run_index=$((run_index + 1))
failed_output=$temporary_directory/out-$run_index
set +e
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$temporary_directory/vulkan-workload.lock" \
    QWEN_TEST_AB_RATES="$failed_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$failed_output" \
    >"$temporary_directory/verdict-failed-stdout.txt" \
    2>"$temporary_directory/verdict-failed-stderr.txt"
failed_status=$?
set -e
[ "$failed_status" -eq 1 ]
[ "$(awk -F'=' '$1 == "served_ab" { print $2 }' "$failed_output/terminal-state.tsv")" = failed ]
[ "$(awk -F'=' '$1 == "arm_failures" { print $2 }' "$failed_output/terminal-state.tsv")" = 1 ]
printf 'verdict_failed=accepted exit=%s\n' "$failed_status"

# An output directory a run already claimed is never appended to.
active_fixture=output_directory_exists
set +e
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_TEST_AB_RATES="$promoted_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$failed_output" \
    >/dev/null 2>"$temporary_directory/exists-stderr.txt"
exists_status=$?
set -e
[ "$exists_status" -eq 2 ]
grep -q 'never appends to one' "$temporary_directory/exists-stderr.txt"
printf 'output_directory_exists=accepted\n'

# The engine clock as a control. A forced policy is validated by name, written
# through sudo, proven by the device's own selection, and restored on every
# exit; it replaces the regime precondition with one priming warmup and holds
# every arm to the invariant the validator states.
active_fixture=engine_clock_policy_name
run_index=$((run_index + 1))
set +e
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=peak \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$temporary_directory/engine-clock-name-stderr.txt"
engine_clock_name_status=$?
set -e
[ "$engine_clock_name_status" -eq 2 ]
grep -q 'QWEN_CENSUS_ENGINE_CLOCK_POLICY is auto, high, profile_peak, or manual: peak' \
    "$temporary_directory/engine-clock-name-stderr.txt"
printf 'engine_clock_policy_name=accepted\n'

# A campaign under the measured policy. `manual` selects the highest graphics
# level the table lists, which is what decoded 9.58, 8.91, and 9.23 tok/s on the
# appliance against interleaved governor arms at 8.22 and 7.94, and the run
# states the priming warmup, the ledger rows, the invariant held on every arm,
# and the restore proven by readback on the ordinary exit.
run_ab engine_clock_forced_manual 0 promoted "$promoted_rates" "$one_clock" 16 manual
active_fixture=engine_clock_forced_manual_ledger
grep -q '^engine_clock=applied policy=manual sclk_level=1 required_sclk_mhz=1100 mclk_level=- mclk_readback_mhz=- mclk_floor_mhz=933 snapshot=auto 1 0$' \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
grep -q '^census_regime=retired policy=manual required_sclk_mhz=1100 mclk_floor_mhz=933 arms=1$' \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
grep -q "^dpm_restore=restored level=auto requested=auto sclk_level=1 mclk_level=0 node=$ab_drm/power_dpm_force_performance_level\$" \
    "$temporary_directory/engine_clock_forced_manual-stdout.txt"
for engine_clock_row in "engine_clock_policy	manual" "engine_clock_sclk_level	1" \
    "engine_clock_mclk_level	-" "engine_clock_required_sclk_mhz	1100" \
    "engine_clock_required_mclk_mhz	933" "clock_below_required_fraction	0" \
    "mclk_floor_mhz	933" "engine_clock_mclk_readback_mhz	-" \
    "regime_max_arms	-"; do
    grep -qxF -- "$(printf '%s' "$engine_clock_row")" "$ab_last_output/inputs.tsv"
done
# One priming warmup opens the ledger, the named arms keep their own slots, and
# every arm carries the invariant the forced policy asked for.
[ "$(awk -F'\t' 'NR > 1 && $2 == "W"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 1 ]
[ "$(awk -F'\t' 'NR == 2 { print $1, $2, $14, $15 }' "$ab_last_output/arms.tsv")" \
    = '0a W held 0.0000' ]
[ "$(awk -F'\t' 'NR > 1 && $14 != "held"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
# The performance level, the graphics level, and the restore are the three sudo
# writes the campaign makes, in that order, and the fixture is left where the
# campaign found it.
[ "$(awk -F'\t' '{ print $2 }' "$ab_sudo_log" | tr '\n' ' ')" = 'manual 1 auto ' ]
[ "$(cat "$ab_drm/power_dpm_force_performance_level")" = auto ]
# The validator was handed both halves of the operating point, which the arm's
# own verdict file is what proves: a campaign requesting the graphics step
# alone would leave the fabric clock unbounded and every case above unchanged.
grep -q '^clock_invariant=held .* required=1100 required_mclk=933$' \
    "$ab_last_output/arms/0a-W/clock-sidecar-verdict.txt"
printf 'engine_clock_forced_manual=accepted sclk_level=1 required_sclk_mhz=1100\n'

# The fabric write is recorded rather than required. The appliance took the
# write and left its own selection starred, so the campaign reports the
# readback and holds the arms to the floor instead.
run_ab engine_clock_manual_fabric_write 0 promoted "$promoted_rates" "$one_clock" 16 manual '' 1 1
active_fixture=engine_clock_manual_fabric_ledger
grep -q '^engine_clock=applied policy=manual sclk_level=1 required_sclk_mhz=1100 mclk_level=1 mclk_readback_mhz=933 mclk_floor_mhz=933 snapshot=auto 1 0$' \
    "$temporary_directory/engine_clock_manual_fabric_write-stdout.txt"
for engine_clock_row in "engine_clock_mclk_level	1" "engine_clock_mclk_readback_mhz	933"; do
    grep -qxF -- "$(printf '%s' "$engine_clock_row")" "$ab_last_output/inputs.tsv"
done
[ "$(awk -F'\t' '{ print $2 }' "$ab_sudo_log" | tr '\n' ' ')" = 'manual 1 1 auto ' ]
printf 'engine_clock_manual_fabric_write=accepted readback_mhz=933\n'

# A performance level rather than a level selection: `high` raises the graphics
# table to its highest step, which the campaign requires and holds the arms to.
run_ab engine_clock_forced_high 0 promoted "$promoted_rates" "$one_clock" 16 high
active_fixture=engine_clock_forced_high_ledger
grep -q '^engine_clock=applied policy=high sclk_level=- required_sclk_mhz=1100 mclk_level=- mclk_readback_mhz=- mclk_floor_mhz=933 snapshot=auto 1 0$' \
    "$temporary_directory/engine_clock_forced_high-stdout.txt"
grep -qxF -- "$(printf 'engine_clock_policy\thigh')" "$ab_last_output/inputs.tsv"
grep -qxF -- "$(printf 'engine_clock_sclk_level\t-')" "$ab_last_output/inputs.tsv"
[ "$(awk -F'\t' '{ print $2 }' "$ab_sudo_log" | tr '\n' ' ')" = 'high auto ' ]
printf 'engine_clock_forced_high=accepted required_sclk_mhz=1100\n'

# One arm whose window carried a step below the pinned one: the arm fails on
# the invariant rather than on the record, and its pair leaves the interval as
# clock-violated rather than as a governor step.
run_ab engine_clock_invariant_violated 1 failed "$promoted_rates" "$one_clock" 16 manual 02-K
active_fixture=engine_clock_invariant_ledger
grep -q '^served_ab_arm=failed slot=2 arm=K .* clock_invariant=violated reason=clock_invariant$' \
    "$temporary_directory/engine_clock_invariant_violated-stdout.txt"
[ "$(awk -F'\t' '$1 == "2" { print $14, $15 }' "$ab_last_output/arms.tsv")" = 'violated 0.1429' ]
[ "$(awk -F'=' '$1 == "arm_failures" { print $2 }' "$ab_last_output/terminal-state.tsv")" = 1 ]
printf 'engine_clock_invariant_violated=accepted\n'

# An expired sudo credential is refused ahead of the first arm and names the
# command that renews it, since a campaign cannot answer a password prompt.
active_fixture=engine_clock_sudo_refused
run_index=$((run_index + 1))
engine_clock_refuse_drm=$temporary_directory/drm-sudo-refused
cp -R -- "$fixture_drm" "$engine_clock_refuse_drm"
printf 'auto\n' >"$engine_clock_refuse_drm/power_dpm_force_performance_level"
set +e
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_refuse_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_TEST_AB_RATES="$promoted_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_TEST_SUDO_REFUSE=1 \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >"$temporary_directory/engine-clock-sudo-stdout.txt" \
    2>"$temporary_directory/engine-clock-sudo-stderr.txt"
engine_clock_sudo_status=$?
set -e
[ "$engine_clock_sudo_status" -eq 2 ]
grep -q 'run sudo -v and start the campaign again' \
    "$temporary_directory/engine-clock-sudo-stderr.txt"
[ "$(cat "$engine_clock_refuse_drm/power_dpm_force_performance_level")" = auto ]
if [ -e "$temporary_directory/out-$run_index" ]; then
    printf 'the refused credential still opened an output directory\n' >&2
    exit 1
fi
printf 'engine_clock_sudo_refused=accepted\n'

# A device that took the policy and stayed on a lower step describes something
# other than the pinned clock the arms would be read against.
active_fixture=engine_clock_below_peak
run_index=$((run_index + 1))
engine_clock_low_drm=$temporary_directory/drm-below-peak
cp -R -- "$fixture_drm" "$engine_clock_low_drm"
printf 'auto\n' >"$engine_clock_low_drm/power_dpm_force_performance_level"
set +e
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_low_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_TEST_AB_RATES="$promoted_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_TEST_SUDO_STAR_LOWEST=1 \
    QWEN_TEST_SUDO_LOG="$temporary_directory/sudo-below-peak.log" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >"$temporary_directory/engine-clock-low-stdout.txt" \
    2>"$temporary_directory/engine-clock-low-stderr.txt"
engine_clock_low_status=$?
set -e
[ "$engine_clock_low_status" -eq 2 ]
grep -q 'pp_dpm_sclk selected level 0 where the campaign wrote 1' \
    "$temporary_directory/engine-clock-low-stderr.txt"
# The refusal unwinds through the same restore, so the device is left on the
# level the campaign found rather than on the one it could not confirm.
grep -q '^dpm_restore=restored level=auto requested=auto ' \
    "$temporary_directory/engine-clock-low-stdout.txt"
[ "$(cat "$engine_clock_low_drm/power_dpm_force_performance_level")" = auto ]
printf 'engine_clock_below_peak=accepted\n'

# A terminating signal restores the level as it tears the children down. The
# campaign is signalled once it has printed the line its write produced, so the
# case reads a restore that ran from the handler rather than from a run that
# had already finished.
active_fixture=engine_clock_restore_on_term
run_index=$((run_index + 1))
engine_clock_term_drm=$temporary_directory/drm-term
cp -R -- "$fixture_drm" "$engine_clock_term_drm"
printf 'auto\n' >"$engine_clock_term_drm/power_dpm_force_performance_level"
engine_clock_term_stdout=$temporary_directory/engine-clock-term-stdout.txt
: >"$engine_clock_term_stdout"
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_term_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$temporary_directory/vulkan-workload.lock" \
    QWEN_TEST_AB_RATES="$promoted_rates" QWEN_TEST_AB_CLOCKS="$one_clock" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    QWEN_TEST_SUDO_LOG="$temporary_directory/sudo-term.log" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >"$engine_clock_term_stdout" 2>"$temporary_directory/engine-clock-term-stderr.txt" &
engine_clock_term_pid=$!
engine_clock_term_poll=0
while [ "$engine_clock_term_poll" -lt 100 ]; do
    if grep -q '^engine_clock=applied ' "$engine_clock_term_stdout"; then
        break
    fi
    sleep 0.2
    engine_clock_term_poll=$((engine_clock_term_poll + 1))
done
if [ "$engine_clock_term_poll" -ge 100 ]; then
    kill -TERM "$engine_clock_term_pid" 2>/dev/null || true
    wait "$engine_clock_term_pid" 2>/dev/null || true
    printf 'the signalled campaign never applied its clock policy\n' >&2
    exit 1
fi
[ "$(cat "$engine_clock_term_drm/power_dpm_force_performance_level")" = manual ]
kill -TERM "$engine_clock_term_pid"
set +e
wait "$engine_clock_term_pid"
engine_clock_term_status=$?
set -e
if [ "$engine_clock_term_status" -ne 143 ]; then
    printf 'the signalled campaign exited %s where its TERM trap exits 143\n' \
        "$engine_clock_term_status" >&2
    exit 1
fi
grep -q '^dpm_restore=restored level=auto requested=auto ' "$engine_clock_term_stdout"
[ "$(cat "$engine_clock_term_drm/power_dpm_force_performance_level")" = auto ]
printf 'engine_clock_restore_on_term=accepted\n'

active_fixture=complete
printf 'run_served_binary_ab=accepted cases=%s\n' "$run_index"
