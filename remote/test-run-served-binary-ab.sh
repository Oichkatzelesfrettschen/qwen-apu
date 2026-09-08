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
# The runtime tree's head is a git revision, and the campaign signs its Vulkan
# lease proof with it, so the fixture spells it in the 40-hex form
# verify-external-vulkan-lease.py validates.
runtime_git_head=0123456789abcdef0123456789abcdef01234567
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
    "$runtime_git_head" "$foreign_sha256" "$registry_sha256" \
    >"$temporary_directory/runtime-tree-manifest.tsv"

home_directory=$temporary_directory/home
models_directory=$temporary_directory/models
mkdir -p "$home_directory"
# The campaign holds its state directory's own lease and refuses any other
# path, so the fixture home carries that directory.
workload_lease_directory=$temporary_directory/.runtime/state
mkdir -p "$workload_lease_directory"
workload_lease=$workload_lease_directory/vulkan-workload.lock
model_file=$("$registry_reader" id "$model_id" model_file)
mkdir -p "$models_directory/$(dirname -- "$model_file")"
# The checkpoint carries bytes so a replacement can hold its byte count and
# move its digest alone, which is what leaves the arm's own descriptor record
# as the only reading that separates the two.
printf 'fixture-model-a\n' >"$models_directory/$model_file"

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
# The digest build-llama-preset.sh records beside a candidate series:
# verify-llama-patch-series.sh concatenates each member's own SHA-256 in ledger
# order and hashes the concatenation, so a patch edited after the build moves
# the value the manifest carries.
candidate_series_digest() {
    series_identity=''
    for series_member in $(printf '%s\n' "$1" | tr ',' ' '); do
        series_identity=$series_identity$(
            sha256sum "$script_directory/../patches/$series_member" | cut -d ' ' -f 1)
    done
    printf '%s' "$series_identity" | sha256sum | cut -d ' ' -f 1
}

write_manifest() {
    manifest_path=$1
    manifest_bytes=$2
    manifest_digest=$3
    manifest_series=$4
    manifest_tree=$5
    manifest_cmake=$6
    manifest_compiler=$7
    # The eighth names the series digest the manifest records, which a case
    # moves to stand for a candidate built before its patch changed.
    manifest_series_digest=${8:-}
    # The ninth names the Q4_K arms the build admits. A build carrying the
    # variant-select member declares all nine keys; every other build declares
    # none, which is the `-` the manifest writer emits for it.
    manifest_q4k_variants=${9:--}
    if [ -z "$manifest_series_digest" ]; then
        if [ "$manifest_series" = - ]; then
            manifest_series_digest=-
        else
            manifest_series_digest=$(candidate_series_digest "$manifest_series")
        fi
    fi
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
        printf 'q4k_variants\t%s\n' "$manifest_q4k_variants"
        printf 'candidate_series\t%s\n' "$manifest_series"
        printf 'candidate_series_sha256\t%s\n' "$manifest_series_digest"
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
# The source record build-telemetry-broker.sh writes beside an executable it
# compiled. The stub was compiled from nothing, so the record states the source
# the preflight holds it to and no case rebuilds over the stub.
sha256sum "$script_directory/telemetry-broker.c" | cut -d ' ' -f 1 \
    >"$broker_stub.source-sha256"

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

# The fabric floor is the condition every window sample is held to, so zero
# holds the window to nothing and a leading zero writes a second spelling of
# one count; both are refused ahead of the first arm.
# The band decides which pairs the rate and the bracket are read over, and it
# reaches three readers as a float, so a value outside [0, 1) is refused before
# an arm rather than admitting every pair.
run_harness sclk_band_infinite 'QWEN_CENSUS_SCLK_BAND is a nonnegative decimal' \
    QWEN_CENSUS_SCLK_BAND=inf
run_harness sclk_band_above_one 'QWEN_CENSUS_SCLK_BAND is a relative distance' \
    QWEN_CENSUS_SCLK_BAND=1

run_harness mclk_floor_zero 'QWEN_CENSUS_MCLK_FLOOR_MHZ is a positive megahertz count' \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_CENSUS_MCLK_FLOOR_MHZ=0
run_harness mclk_floor_leading_zero \
    'QWEN_CENSUS_MCLK_FLOOR_MHZ is a positive megahertz count' \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual QWEN_CENSUS_MCLK_FLOOR_MHZ=0933

run_candidate candidate_without_e4_member \
    "must name candidate_series $candidate_patch alone" "$candidate_no_member"
run_candidate candidate_two_members \
    "must name candidate_series $candidate_patch alone" "$candidate_two_members"
run_candidate candidate_profile_preset 'descend from different base builds' \
    "$candidate_profile_preset"
run_candidate candidate_instrumented \
    'the candidate manifest names instrumentation' "$candidate_instrumented"

# A candidate whose manifest names the E4 member and records another series
# digest: the binary was built before the patch in this checkout changed, which
# the filename comparison admits and the recomputed digest refuses.
candidate_stale_series=$temporary_directory/candidate-stale-series
mkdir -p "$candidate_stale_series/bin"
cp -- "$candidate_server" "$candidate_stale_series/bin/llama-server"
chmod +x "$candidate_stale_series/bin/llama-server"
write_manifest "$candidate_stale_series/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$candidate_patch" verified-candidate \
    "$serving_cmake" "$serving_compiler" "$foreign_sha256"
run_candidate candidate_stale_series_digest \
    'records candidate_series_sha256' "$candidate_stale_series"

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

# The witness directory names a separate campaign's output, and the summary
# reports its token identity and margin contract beside the paired bound. A
# directory carrying no margin summary is refused before any arm runs rather
# than reported as unavailable after one, since a caller who named a witness
# asked for those two rows.
active_fixture=witness_directory_unreadable
run_index=$((run_index + 1))
set +e
env -i PATH="$execution_path" HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_AB_WITNESS_DIRECTORY="$temporary_directory/no-such-witness" \
    "$harness" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$temporary_directory/witness-stderr.txt"
witness_status=$?
set -e
[ "$witness_status" -eq 2 ]
grep -q 'QWEN_AB_WITNESS_DIRECTORY names a run-kernel-delta-witness.sh output directory' \
    "$temporary_directory/witness-stderr.txt"
printf 'witness_directory_unreadable=accepted\n'

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
for linked_member in model-registry.sh qwen-home.sh models.tsv ctx-checkpoints.tsv \
    validated-tuples.tsv quarantine.tsv draft-pairs.tsv census-arm-lib.sh llama-patch-series.tsv \
    summarize-census-controls.py summarize-bracket-ab.py sample-clock-sidecar.py \
    verify-external-vulkan-lease.py \
    telemetry-broker.c build-telemetry-broker.sh; do
    ln -s -- "$script_directory/$linked_member" "$run_directory/$linked_member"
done
# The candidate series is bound by the patch bytes and the harness resolves them
# beside its own directory, so the executing copy carries the same patch files
# the checked-in tree holds.
mkdir -p "$temporary_directory/patches"
cp -- "$script_directory/../patches/$candidate_patch" \
    "$script_directory/../patches/llama-vulkan-pipeline-census.patch" \
    "$temporary_directory/patches/"

# The served runner an arm reaches. It reads the rate its arm is to answer with
# from the case's own table, writes the timings the harness derives tok_s from,
# and writes the request window the sidecar validator is bounded by. A rate of
# `fail` leaves no response at all, which is the arm failure a case reads, and
# a rate of `truncate` leaves a reply cut mid-object, which is what a runner
# killed while writing leaves behind.
# The arm runs under the closed environment census_arm_exec applies, so the
# stub reads its per-case controls from a file whose path is written into it
# here rather than from variables the arm no longer inherits, and it appends
# its own environment so a case reads what the arm was handed.
arm_controls=$temporary_directory/arm-controls.tsv
arm_environment=$temporary_directory/arm-environment.txt
: >"$arm_controls"
: >"$arm_environment"
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'arm_controls=%s\n' "$arm_controls"
    printf 'arm_environment=%s\n' "$arm_environment"
    cat <<'FAKE_SERVED_RUNNER'
arm_control() {
    awk -F'\t' -v key="$1" '$1 == key { value = $2; found = 1 }
        END { if (found) print value }' "$arm_controls"
}
env >>"$arm_environment"
arm_label=$1
model_launch_path=$2
# A case that signals the campaign mid-arm names a release file here, so the
# arm stays in flight until the case has read the state it is about to change
# rather than finishing inside the poll interval the case reads at.
arm_hold_file=$(arm_control hold)
if [ -n "$arm_hold_file" ]; then
    while [ ! -e "$arm_hold_file" ]; do
        sleep 0.05
    done
fi
served_rate=$(awk -F'\t' -v label="$arm_label" '$1 == label { print $2 }' \
    "$(arm_control rates)")
# The identities the launch chain is handed reach the ledger the case reads, so
# a case asserts which tree and which checkpoint an arm was pinned to rather
# than inferring it from the arm's own outcome.
arm_env_ledger=$(arm_control arm_env)
if [ -n "$arm_env_ledger" ]; then
    printf '%s\t%s\t%s\n' "$arm_label" "${QWEN_INTENDED_GIT_HEAD:--}" \
        "${QWEN_INTENDED_PAYLOAD_SHA256:--}" >>"$arm_env_ledger"
fi
# The checkpoint a case replaces under the campaign, ahead of the record this
# arm writes: the arm then pins the replacement and re-establishes publisher
# identity against whichever ledger row followed it, which is the swap the
# preflight digest rather than the arm's own check refuses.
if [ "$(arm_control replace_model)" = "$arm_label" ]; then
    printf 'fixture-model-b\n' >"$model_launch_path"
fi
# The runner records the checkpoint it pinned, which is what an arm's model
# identity is compared against.
python3 - "$model_launch_path" "$QWEN_RESULT_DIRECTORY/runtime-inputs.json" <<'RUNTIME_INPUTS'
import hashlib, json, pathlib, sys
model = pathlib.Path(sys.argv[1]).read_bytes()
json.dump({"schema": "served-runtime-inputs-v1",
           "model": {"path": sys.argv[1], "bytes": len(model),
                     "sha256": hashlib.sha256(model).hexdigest()}},
          open(sys.argv[2], "w"))
RUNTIME_INPUTS
if [ "$(arm_control replace_tree)" = "$arm_label" ]; then
    # A tree regenerated from dirty remote/ or patches/ bytes keeps its
    # recorded head and moves both payload digests, which is the resync the
    # head alone cannot see.
    tree_manifest=$(arm_control tree_manifest)
    tree_head=$(awk -F'\t' '$1 == "git_head" { print $2 }' "$tree_manifest")
    printf 'git_head\t%s\nremote_payload_tree_sha256\tresynced\npatches_payload_tree_sha256\tresynced\n' \
        "$tree_head" >"$tree_manifest"
fi
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
# The reply each arm retains. The content is the arm's own entry in the reply
# table where one names it, so a case stands a candidate that answers
# differently up against a control that answered the registered text.
served_reply=the-answer
arm_reply_table=$(arm_control replies)
if [ -n "$arm_reply_table" ] && [ -f "$arm_reply_table" ]; then
    table_reply=$(awk -F'\t' -v label="$arm_label" '$1 == label { print $2 }' \
        "$arm_reply_table")
    [ -z "$table_reply" ] || served_reply=$table_reply
fi
python3 - "$served_rate" "$served_reply" >"$QWEN_RESULT_DIRECTORY/response.json" <<'PY'
import json, sys
rate = float(sys.argv[1])
json.dump({"choices": [{"message": {"content": sys.argv[2]}}],
           "timings": {"predicted_n": 65, "predicted_ms": 64000.0 / rate}},
          sys.stdout)
PY
FAKE_SERVED_RUNNER
} >"$run_directory/measure-served-decode.sh"
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

# The stub records its own argv beside the verdict it prints, so a case reads
# which priority and affinity the harness declared to the validator; a
# printed verdict alone would leave --expected-nice and --expected-cpu-affinity
# unobservable, and those two are what close the P2 gap where a configured
# sampler priority never reached the validator invocation at all.
argv_log = os.environ.get("QWEN_TEST_VALIDATOR_ARGV")
if argv_log:
    with open(argv_log, "a") as handle:
        handle.write(" ".join(sys.argv[1:]) + "\n")

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
# The column the invariant was counted over. The delivered frequency is what a
# forced policy is answered by, so the default names it and a case naming the
# DPM column stands for a broker built before telemetry-broker.c wrote it.
source = os.environ.get("QWEN_TEST_AB_CLOCK_SOURCE", "") or "sclk_actual_mhz"
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
          f" below_required_fraction=0.1429 sclk_source={source} required={required}")
    print("clock_sidecar=refused failures=clock_invariant")
    raise SystemExit(1)
else:
    print(f"clock_invariant=held samples_at_required=700 samples_below_required=0"
          f" below_required_fraction=0.0000 sclk_source={source} required={required}"
          f" required_mclk={required_mclk}")
print("clock_sidecar=accepted failures=-")
VALIDATOR_STUB
chmod +x "$run_directory/validate-clock-sidecar.py"

# The quiescence poller samples a device, so it is stubbed; the harness reads
# its printed line rather than its own clock.
cat >"$run_directory/await-quiescence.sh" <<'FAKE_QUIESCENCE'
#!/bin/sh
set -eu
# The stub records its own argv, so a case reads which cooldown flags the
# campaign passed. A stub that printed a verdict alone would leave
# --sclk-forced unobservable, and that flag is what keeps a cooldown under a
# forced clock policy from running to its deadline.
if [ -n "${QWEN_TEST_QUIESCENCE_ARGV:-}" ]; then
    printf '%s\n' "$*" >>"$QWEN_TEST_QUIESCENCE_ARGV"
fi
# A case naming timeout stands for a poller that spent its deadline with a
# predicate still unsettled, which is the state the arm after it would inherit.
if [ "${QWEN_TEST_QUIESCENCE_VERDICT:-reached}" = timeout ]; then
    printf 'quiescence=timeout elapsed_ms=30000 llama_server=absent gpu_busy=41\n'
    exit 1
fi
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

# What a case moves for its own run: the cooldown verdict the stub poller
# reports, the reply table the stub served runner answers from, and the arm
# after which the checkpoint or the runtime tree is replaced under the
# campaign. Each reads its default here and run_ab restores it.
case_quiescence=reached
case_replies=
case_replace_model=
case_replace_tree=
case_control_key=
case_candidate_key=
case_control_server=
case_candidate_server=
case_witness=

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
    # The eleventh names the column the stub validator reports the invariant
    # was counted over. A case leaving it unset reads the delivered frequency
    # telemetry-broker.c writes, and one naming the DPM column stands for a
    # broker built before that column existed.
    ab_clock_source=${11:-}
    active_fixture=$ab_case
    run_index=$((run_index + 1))
    ab_output=$temporary_directory/out-$run_index
    # A case sets these before it calls and the call clears them, so one case's
    # replacement, reply table, or cooldown verdict reaches its own run alone.
    ab_quiescence_verdict=${case_quiescence:-reached}
    ab_replies=${case_replies:-}
    ab_replace_model=${case_replace_model:-}
    ab_replace_tree=${case_replace_tree:-}
    # The integer-dot admission is a per-role campaign input, so a case names
    # what each role runs under and the call clears both the way it clears the
    # reply table.
    ab_control_force_dot=${case_control_force_integer_dot:-}
    ab_candidate_force_dot=${case_candidate_force_integer_dot:-}
    ab_arm_env=$temporary_directory/arm-env-$ab_case.tsv
    ab_drm=$fixture_drm
    ab_sudo_log=$temporary_directory/sudo-$ab_case.log
    ab_quiescence_argv=$temporary_directory/quiescence-argv-$ab_case.log
    ab_validator_argv=$temporary_directory/validator-argv-$ab_case.log
    : >"$ab_validator_argv"
    if [ "$ab_engine_clock_policy" != auto ]; then
        ab_drm=$temporary_directory/drm-$ab_case
        cp -R -- "$fixture_drm" "$ab_drm"
        printf 'auto\n' >"$ab_drm/power_dpm_force_performance_level"
    fi
    diagnostic_file=$temporary_directory/$ab_case-stderr.txt
    # The arm's own controls travel in a file rather than in the environment,
    # since census_arm_exec hands each arm a closed set.
    {
        printf 'rates\t%s\n' "$ab_rates"
        printf 'replies\t%s\n' "$ab_replies"
        printf 'replace_model\t%s\n' "$ab_replace_model"
        printf 'replace_tree\t%s\n' "$ab_replace_tree"
        printf 'tree_manifest\t%s\n' "$temporary_directory/runtime-tree-manifest.tsv"
        printf 'arm_env\t%s\n' "$ab_arm_env"
    } >"$arm_controls"
    : >"$arm_environment"
    set +e
    env -i \
        PATH="$run_path" \
        HOME="$home_directory" \
        SSH_CONNECTION="$run_ssh_connection" \
        GGML_VK_Q4K_SIDEPLANE=0 \
        QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=65536 \
        GGML_VK_Q4K_VARIANT=e4/8 \
        QWEN_AB_WITNESS_DIRECTORY="${case_witness:-}" \
        QWEN_AB_CONTROL_EXPERIMENT_KEY="${case_control_key:-}" \
        QWEN_AB_CANDIDATE_EXPERIMENT_KEY="${case_candidate_key:-}" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$ab_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_AB_COOLDOWN_S=0 \
        QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease" \
        QWEN_TEST_AB_CLOCKS="$ab_clocks" \
        QWEN_TEST_AB_VIOLATED="$ab_violated_arms" \
        QWEN_TEST_AB_CLOCK_SOURCE="$ab_clock_source" \
        QWEN_TEST_SUDO_LOG="$ab_sudo_log" \
        QWEN_TEST_QUIESCENCE_ARGV="$ab_quiescence_argv" \
        QWEN_TEST_VALIDATOR_ARGV="$ab_validator_argv" \
        QWEN_TEST_QUIESCENCE_VERDICT="$ab_quiescence_verdict" \
        QWEN_CENSUS_ENGINE_CLOCK_POLICY="$ab_engine_clock_policy" \
        QWEN_CENSUS_MCLK_LEVEL="$ab_mclk_level" \
        QWEN_TEST_SUDO_MCLK_IGNORE="$ab_mclk_ignore" \
        QWEN_CENSUS_REGIME_MAX_ARMS="$ab_regime_max_arms" \
        QWEN_AB_CONTROL_FORCE_INTEGER_DOT="$ab_control_force_dot" \
        QWEN_AB_CANDIDATE_FORCE_INTEGER_DOT="$ab_candidate_force_dot" \
        "$run_harness_path" "${case_control_server:-$control_server}" \
        "${case_candidate_server:-$candidate_server}" "$model_id" \
        "$ab_output" \
        >"$temporary_directory/$ab_case-stdout.txt" 2>"$diagnostic_file"
    ab_status=$?
    set -e
    case_quiescence=reached
    case_replies=
    case_replace_model=
    case_replace_tree=
    case_control_key=
    case_candidate_key=
    case_control_server=
    case_candidate_server=
    case_witness=
    case_control_force_integer_dot=
    case_candidate_force_integer_dot=
    if [ "$ab_status" -ne "$ab_expected_status" ]; then
        printf 'expected exit %s, observed %s\n' "$ab_expected_status" "$ab_status" >&2
        sed -n '1,20p' "$temporary_directory/$ab_case-stdout.txt" >&2
        sed -n '1,20p' "$diagnostic_file" >&2
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
    ab_last_validator_argv=$ab_validator_argv
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
# The harness pins the sampler to nice 19 and to the CPU set
# QWEN_CENSUS_SIDECAR_CPU names, so every validator invocation carries
# --expected-nice and --expected-cpu-affinity; a campaign that configured a
# priority and never named it to the validator would read that check
# not_run rather than proving the sampler held it.
if [ ! -s "$ab_last_validator_argv" ]; then
    printf 'the validator stub recorded no invocation\n' >&2
    exit 1
fi
if ! awk '/--expected-nice 19( |$)/ { found = 1 } END { exit !found }' \
        "$ab_last_validator_argv"; then
    printf 'no validator invocation carried --expected-nice 19\n' >&2
    cat "$ab_last_validator_argv" >&2
    exit 1
fi
if ! awk '/--expected-cpu-affinity 0( |$)/ { found = 1 } END { exit !found }' \
        "$ab_last_validator_argv"; then
    printf 'no validator invocation carried --expected-cpu-affinity 0\n' >&2
    cat "$ab_last_validator_argv" >&2
    exit 1
fi
[ "$(head -n 1 "$ab_last_output/arms.tsv")" = "$(printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\tsclk_mode_mhz\tsclk_share\tmclk_mode_mhz\tregime_delta\tclock_invariant\tbelow_required_fraction')" ]
awk -F'\t' 'NF != 16 { exit 1 }' "$ab_last_output/arms.tsv"
# The clock columns trail the ledger and read the unknown value under the
# appliance's own governor, where the validator requests no invariant.
[ "$(awk -F'\t' 'NR > 1 && ($15 != "-" || $16 != "-")' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
# The pp_dpm_mclk selection comes off the same clock_state line as the graphics
# mode and is reported rather than compared, so every sampled arm carries the
# value the validator printed and a warmup carries it too.
[ "$(awk -F'\t' 'NR > 1 && $13 != "1067"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
# Every arm of the one-clock table holds 800 MHz at a share of 0.1400, inside
# the sustained regime's own window, so the precondition settles on the second
# warmup and the ledger carries the header, two warmups, and the eight paired
# arms.
[ "$(awk 'END { print NR }' "$ab_last_output/arms.tsv")" = 11 ]
# The warmups open the ledger at the lettered slots with the sampler on,
# because their clock state is what the precondition reads, and enter no pair;
# the summarizer's own filter is what keeps them out.
[ "$(awk -F'\t' 'NR == 2 { print $1, $2, $8, $11, $14 }' "$ab_last_output/arms.tsv")" = '0a W on 800 -' ]
[ "$(awk -F'\t' 'NR == 3 { print $1, $2, $8, $11, $14 }' "$ab_last_output/arms.tsv")" = '0b W on 800 -' ]
[ "$(awk -F'\t' 'NR == 4 { print $1, $2, $8, $11, $12 }' "$ab_last_output/arms.tsv")" = '1 C on 800 0.1400' ]
[ "$(awk -F'\t' 'NR == 4 { print $7, $9, $14 }' "$ab_last_output/arms.tsv")" = '- - +0.0000' ]
# The governor policy releases the graphics step on its own, so the position
# predicate still describes idle, the campaign passes no --sclk-forced, and
# every cooldown row records the state it ran under.
if [ ! -s "$ab_quiescence_argv" ]; then
    printf 'the governor campaign invoked no cooldown poller\n' >&2
    exit 1
fi
if grep -q -- '--sclk-forced' "$ab_quiescence_argv"; then
    printf 'the governor campaign passed --sclk-forced to the cooldown poller\n' >&2
    cat "$ab_quiescence_argv" >&2
    exit 1
fi
if ! awk -F'\t' '$3 == "cooldown" && $6 ~ /sclk_forced=0$/ { found = 1 }
    END { exit found ? 0 : 1 }' "$ab_last_output/wall-clock.tsv"; then
    printf 'no governor cooldown row records sclk_forced=0\n' >&2
    sed -n '1,10p' "$ab_last_output/wall-clock.tsv" >&2
    exit 1
fi
printf 'arms_ledger_columns=accepted cooldown_invocations=%s\n' \
    "$(wc -l <"$ab_quiescence_argv" | tr -d ' ')"

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

# The campaign records what it bound each arm to and hands the arm the same
# values. The payload digest is the one check-runtime-tree.sh composes from the
# manifest's two payload rows, and the model digest is the checkpoint's own
# bytes rather than the ledger row an arm re-reads.
active_fixture=bound_identities_recorded
expected_payload_sha256=$(printf 'remote_payload_tree_sha256=%s\npatches_payload_tree_sha256=%s\n' \
    "$foreign_sha256" "$registry_sha256" | sha256sum | cut -d ' ' -f 1)
expected_model_sha256=$(sha256sum "$models_directory/$model_file" | cut -d ' ' -f 1)
grep -qxF "$(printf 'runtime_tree_payload_sha256\t%s' "$expected_payload_sha256")" \
    "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'model_file_sha256\t%s' "$expected_model_sha256")" \
    "$ab_last_output/inputs.tsv"
# Every arm, warmup included, launched under those two identities.
if [ "$(awk -F'\t' -v head="$runtime_git_head" -v payload="$expected_payload_sha256" \
    '$2 != head || $3 != payload { count++ } END { print count + 0 }' \
    "$temporary_directory/arm-env-verdict_promoted.tsv")" != 0 ]; then
    printf 'an arm launched under other than the preflight tree identity\n' >&2
    cat "$temporary_directory/arm-env-verdict_promoted.tsv" >&2
    exit 1
fi
[ "$(awk 'END { print NR }' "$temporary_directory/arm-env-verdict_promoted.tsv")" = 10 ]
printf 'bound_identities_recorded=accepted\n'

# The default campaign admits no q8_1 pipeline on either role, so every arm
# record carries the name with an empty value and the receipt states `-` twice.
# The name is required rather than merely admitted, since an arm that inherited
# the admission instead of being handed it would leave the record silent about
# which path it measured.
active_fixture=force_integer_dot_absent
for arm_record in "$ab_last_output"/arms/*/arm-environment.tsv; do
    [ -r "$arm_record" ] || continue
    if ! cut -f1 "$arm_record" | grep -qx QWEN_FORCE_INTEGER_DOT; then
        printf 'arm environment record omits QWEN_FORCE_INTEGER_DOT: %s\n' \
            "$arm_record" >&2
        exit 1
    fi
    recorded_force_dot=$(awk -F'\t' '$1 == "QWEN_FORCE_INTEGER_DOT" { print $2 }' \
        "$arm_record")
    if [ -n "$recorded_force_dot" ]; then
        printf 'an unarmed campaign handed an arm QWEN_FORCE_INTEGER_DOT=%s: %s\n' \
            "$recorded_force_dot" "$arm_record" >&2
        exit 1
    fi
done
grep -qxF "$(printf 'control_force_integer_dot\t-')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'candidate_force_integer_dot\t-')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'candidate_force_integer_dot\t-')" \
    "$ab_last_output/campaign-inputs.tsv"
printf 'force_integer_dot_absent=accepted\n'

# One binary carries the E5 arm and its control, so the admission is what
# separates them: the K arms run with it and every C arm and warmup runs
# without. The profile stays low-async on both sides, which is the field the
# scoreboard receipt requires, so the pair differs by the admission alone.
active_fixture=force_integer_dot_per_arm
case_candidate_force_integer_dot=1
run_ab force_integer_dot_per_arm 0 promoted "$promoted_rates" "$one_clock"
grep -q '^served_ab_arm=start slot=2 arm=K .* force_integer_dot=1$' \
    "$temporary_directory/force_integer_dot_per_arm-stdout.txt"
grep -q '^served_ab_arm=start slot=1 arm=C .* force_integer_dot=-$' \
    "$temporary_directory/force_integer_dot_per_arm-stdout.txt"
grep -qxF "$(printf 'control_force_integer_dot\t-')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'candidate_force_integer_dot\t1')" "$ab_last_output/inputs.tsv"
grep -qxF "$(printf 'candidate_force_integer_dot\t1')" \
    "$ab_last_output/campaign-inputs.tsv"
grep -qxF "$(printf 'vulkan_profile\tlow-async')" \
    "$ab_last_output/campaign-inputs.tsv"
force_integer_dot_failures=0
for arm_record in "$ab_last_output"/arms/*/arm-environment.tsv; do
    [ -r "$arm_record" ] || continue
    recorded_force_dot=$(awk -F'\t' '$1 == "QWEN_FORCE_INTEGER_DOT" { print $2 }' \
        "$arm_record")
    case ${arm_record%/arm-environment.tsv} in
        *-K)
            [ "$recorded_force_dot" = 1 ] || force_integer_dot_failures=1
            ;;
        *)
            [ -z "$recorded_force_dot" ] || force_integer_dot_failures=1
            ;;
    esac
done
if [ "$force_integer_dot_failures" -ne 0 ]; then
    printf 'an arm carried an admission its role never asked for\n' >&2
    exit 1
fi
printf 'force_integer_dot_per_arm=accepted\n'

# ggml_vk_force_integer_dot() compares the value against "1", so a third value
# would run the control while the receipt named the arm, and the campaign
# refuses it ahead of the first server.
active_fixture=force_integer_dot_value
run_index=$((run_index + 1))
set +e
env -i PATH="$execution_path" HOME="$home_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_AB_CANDIDATE_FORCE_INTEGER_DOT=0 \
    "$harness" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$temporary_directory/force-integer-dot-stderr.txt"
force_integer_dot_status=$?
set -e
[ "$force_integer_dot_status" -eq 2 ]
grep -q 'QWEN_AB_CONTROL_FORCE_INTEGER_DOT and QWEN_AB_CANDIDATE_FORCE_INTEGER_DOT admit 1 or an unset value: 0' \
    "$temporary_directory/force-integer-dot-stderr.txt"
printf 'force_integer_dot_value=accepted\n'

# The reply is what makes a rate a comparison. A candidate that answers
# differently while decoding 10% faster carries the promoted interval and is
# refused on the reply row rather than promoted.
active_fixture=response_identity_differs
differing_replies=$temporary_directory/replies-differing
printf '02-K\tanother-answer\n' >"$differing_replies"
case_replies=$differing_replies
run_ab response_identity_differs 1 failed "$promoted_rates" "$one_clock"
grep -q '^served_ab_response_identity=differs pairs=' \
    "$temporary_directory/response_identity_differs-stdout.txt"
grep -qxF "$(printf 'response_identity\tdiffers')" "$ab_last_output/terminal-state.tsv"
printf 'response_identity_differs=accepted\n'

# A cooldown that spent its deadline left the arm after it a machine state the
# arm before it chose, so the counter decides the campaign rather than being
# reported beside a promotion.
active_fixture=cooldown_timeout
case_quiescence=timeout
run_ab cooldown_timeout 1 failed "$promoted_rates" "$one_clock"
[ "$(awk -F'=' '$1 == "cooldown_timeouts" { print $2 }' \
    "$ab_last_output/terminal-state.tsv")" = 10 ]
printf 'cooldown_timeout=accepted\n'

# A checkpoint replaced under the campaign is a different subject however
# consistently its ledger row follows it, so the arm that served it fails on
# the preflight digest.
active_fixture=model_replaced_mid_campaign
case_replace_model=02-K
run_ab model_replaced 1 failed "$promoted_rates" "$one_clock"
grep -q '^served_ab_arm=model_replaced slot=2 arm=K ' \
    "$temporary_directory/model_replaced-stdout.txt"
printf 'model_replaced=accepted\n'

# A runtime tree regenerated from dirty bytes keeps its recorded head and moves
# its payload digest, so the head alone admits it and the payload refuses it.
active_fixture=runtime_tree_resynced
case_replace_tree=02-K
run_ab runtime_tree_resynced 1 failed "$promoted_rates" "$one_clock"
grep -q '^served_ab_arm=runtime_tree_replaced slot=2 arm=K ' \
    "$temporary_directory/runtime_tree_resynced-stdout.txt"
printf 'git_head\t%s\nremote_payload_tree_sha256\t%s\npatches_payload_tree_sha256\t%s\n' \
    "$runtime_git_head" "$foreign_sha256" "$registry_sha256" \
    >"$temporary_directory/runtime-tree-manifest.tsv"
printf 'runtime_tree_resynced=accepted\n'

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
[ "$(awk -F'\t' '$1 == "2" { print $14 }' "$ab_last_output/arms.tsv")" = '+0.2727' ]
[ "$(awk -F'\t' '$1 == "1" { print $14 }' "$ab_last_output/arms.tsv")" = '+0.0000' ]
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
[ "$(awk -F'\t' 'NR > 1 && $2 != "W" && $14 != "-"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
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
printf 'rates\t%s\n' "$truncated_rates" >"$arm_controls"
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease" \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
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
printf 'rates\t%s\n' "$failed_rates" >"$arm_controls"
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease" \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
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
printf 'rates\t%s\n' "$promoted_rates" >"$arm_controls"
env -i \
    PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
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
    "clock_below_mclk_floor_fraction	0.01" \
    "mclk_floor_mhz	933" "engine_clock_mclk_readback_mhz	-" \
    "regime_max_arms	-"; do
    grep -qxF -- "$(printf '%s' "$engine_clock_row")" "$ab_last_output/inputs.tsv"
done
# One priming warmup opens the ledger, the named arms keep their own slots, and
# every arm carries the invariant the forced policy asked for.
[ "$(awk -F'\t' 'NR > 1 && $2 == "W"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 1 ]
[ "$(awk -F'\t' 'NR == 2 { print $1, $2, $15, $16 }' "$ab_last_output/arms.tsv")" \
    = '0a W held 0.0000' ]
[ "$(awk -F'\t' 'NR > 1 && $15 != "held"' "$ab_last_output/arms.tsv" | wc -l | tr -d ' ')" = 0 ]
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
# A forced policy pins the graphics step at the highest one pp_dpm_sclk lists
# and holds it through idle, so the campaign passes --sclk-forced on every
# cooldown and the wall-clock note carries the state that produced the
# poller's own verdict.
if [ ! -s "$ab_quiescence_argv" ]; then
    printf 'the manual-clock campaign invoked no cooldown poller\n' >&2
    exit 1
fi
if grep -qv -- '--sclk-forced' "$ab_quiescence_argv"; then
    printf 'a manual-clock cooldown reached the poller without --sclk-forced\n' >&2
    cat "$ab_quiescence_argv" >&2
    exit 1
fi
if ! awk -F'\t' '$3 == "cooldown" && $6 ~ /sclk_forced=1$/ { found = 1 }
    END { exit found ? 0 : 1 }' "$ab_last_output/wall-clock.tsv"; then
    printf 'no manual-clock cooldown row records sclk_forced=1\n' >&2
    sed -n '1,10p' "$ab_last_output/wall-clock.tsv" >&2
    exit 1
fi
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
[ "$(awk -F'\t' '$1 == "2" { print $15, $16 }' "$ab_last_output/arms.tsv")" = 'violated 0.1429' ]
[ "$(awk -F'=' '$1 == "arm_failures" { print $2 }' "$ab_last_output/terminal-state.tsv")" = 1 ]
printf 'engine_clock_invariant_violated=accepted\n'

# One arm whose invariant was counted over the DPM column. That column repeats
# the selection the campaign wrote, so an arm reading it held agreed with the
# campaign rather than measured the device, and the harness refuses it on its
# instrument while the record itself stays accepted.
run_ab engine_clock_dpm_source 1 failed "$promoted_rates" "$one_clock" 16 manual '' \
    - 0 pp_dpm_sclk_selected_mhz
active_fixture=engine_clock_dpm_source_ledger
grep -q '^served_ab_clock_source=refused slot=1 arm=C source=pp_dpm_sclk_selected_mhz$' \
    "$temporary_directory/engine_clock_dpm_source-stdout.txt"
grep -q '^served_ab_arm=failed slot=1 arm=C .* reason=clock_source$' \
    "$temporary_directory/engine_clock_dpm_source-stdout.txt"
[ "$(awk -F'\t' '$1 == "1" { print $15, $16 }' "$ab_last_output/arms.tsv")" = 'held 0.0000' ]
printf 'engine_clock_dpm_source=accepted\n'

# An expired sudo credential is refused ahead of the first arm and names the
# command that renews it, since a campaign cannot answer a password prompt.
active_fixture=engine_clock_sudo_refused
run_index=$((run_index + 1))
engine_clock_refuse_drm=$temporary_directory/drm-sudo-refused
cp -R -- "$fixture_drm" "$engine_clock_refuse_drm"
printf 'auto\n' >"$engine_clock_refuse_drm/power_dpm_force_performance_level"
set +e
printf 'rates\t%s\n' "$promoted_rates" >"$arm_controls"
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_refuse_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
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
printf 'rates\t%s\n' "$promoted_rates" >"$arm_controls"
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_low_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
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
diagnostic_file=$engine_clock_term_stdout
# The priming arm holds until the signal has been sent, so the campaign is
# provably at the applied clock when TERM arrives; a fake arm otherwise
# completes the whole campaign inside one poll interval and exits 0 on its
# own, which is the race this case measured one run in three.
engine_clock_term_release=$temporary_directory/engine-clock-term-release
rm -f "$engine_clock_term_release"
printf 'rates\t%s\nhold\t%s\n' "$promoted_rates" "$engine_clock_term_release" >"$arm_controls"
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$engine_clock_term_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_AB_COOLDOWN_S=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease" \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    QWEN_TEST_SUDO_LOG="$temporary_directory/sudo-term.log" \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >"$engine_clock_term_stdout" 2>"$temporary_directory/engine-clock-term-stderr.txt" &
engine_clock_term_pid=$!
diagnostic_file=$temporary_directory/engine-clock-term-stderr.txt
# The signal is sent once the campaign has written the level, which its
# applied line proves. The wait is bounded by the campaign's own life rather
# than by a fixed budget: the digests and registry reads ahead of the write
# take seconds on an idle host and far longer under a parallel gate, and a
# campaign that exits before applying is reported with its own diagnostics.
engine_clock_term_poll=0
while ! grep -q '^engine_clock=applied ' "$engine_clock_term_stdout"; do
    if ! kill -0 "$engine_clock_term_pid" 2>/dev/null; then
        wait "$engine_clock_term_pid" 2>/dev/null || true
        printf 'the signalled campaign exited before applying its clock policy:\n' >&2
        cat "$temporary_directory/engine-clock-term-stderr.txt" >&2
        exit 1
    fi
    if [ "$engine_clock_term_poll" -ge 3000 ]; then
        kill -TERM "$engine_clock_term_pid" 2>/dev/null || true
        wait "$engine_clock_term_pid" 2>/dev/null || true
        printf 'the signalled campaign never applied its clock policy within 600 s\n' >&2
        exit 1
    fi
    sleep 0.2
    engine_clock_term_poll=$((engine_clock_term_poll + 1))
done
[ "$(cat "$engine_clock_term_drm/power_dpm_force_performance_level")" = manual ]
kill -TERM "$engine_clock_term_pid"
# The trap runs once the held arm returns, so the release follows the signal.
: >"$engine_clock_term_release"
set +e
wait "$engine_clock_term_pid"
engine_clock_term_status=$?
set -e
# The readback belongs on the campaign's stdout alone: a signal that lands
# while an arm's ledger append holds the redirection once put it into
# inputs.tsv, which is the corruption the descriptor-9 traps remove.
if grep -rq 'dpm_restore=' "$temporary_directory/out-$run_index"; then
    printf 'the restore readback reached a campaign ledger:\n' >&2
    grep -r 'dpm_restore=' "$temporary_directory/out-$run_index" >&2
    exit 1
fi
if [ "$engine_clock_term_status" -ne 143 ]; then
    printf 'the signalled campaign exited %s where its TERM trap exits 143:\n' \
        "$engine_clock_term_status" >&2
    cat "$temporary_directory/engine-clock-term-stderr.txt" >&2
    exit 1
fi
grep -q '^dpm_restore=restored level=auto requested=auto ' "$engine_clock_term_stdout"
[ "$(cat "$engine_clock_term_drm/power_dpm_force_performance_level")" = auto ]
printf 'engine_clock_restore_on_term=accepted\n'

# kernel-delta compares two census-instrumented builds whose series differ by
# the candidate patch alone. The mode name is validated ahead of every
# manifest read, a serving control is refused for carrying no instrument, an
# instrumented control beside the E4-only instrumented candidate is refused on
# the candidate's series, and the admitted pair reaches the same host or
# session refusal a served pair reaches.
run_pair() {
    pair_case=$1
    pair_expectation=$2
    pair_control=$3
    pair_candidate=$4
    shift 4
    active_fixture=$pair_case
    run_index=$((run_index + 1))
    diagnostic_file=$temporary_directory/$pair_case-stderr.txt
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
        "$harness" "$pair_control/bin/llama-server" "$pair_candidate/bin/llama-server" \
        "$model_id" "$temporary_directory/out-$run_index" \
        >"$temporary_directory/$pair_case-stdout.txt" 2>"$diagnostic_file"
    pair_status=$?
    set -e
    if [ "$pair_status" -ne 2 ]; then
        printf 'expected exit 2, observed %s\n' "$pair_status" >&2
        return 1
    fi
    if ! grep -Eq "$pair_expectation" "$diagnostic_file"; then
        printf 'expected a message matching %s\n' "$pair_expectation" >&2
        return 1
    fi
}
shared_patch=llama-vulkan-q4k-row-select.patch
shared_control=$temporary_directory/shared-control
shared_candidate=$temporary_directory/shared-candidate
mkdir -p "$shared_control/bin" "$shared_candidate/bin"
cp -- "$control_server" "$shared_control/bin/llama-server"
cp -- "$candidate_server" "$shared_candidate/bin/llama-server"
write_manifest "$shared_control/artifact-manifest.tsv" "$control_bytes" \
    "$control_sha256" "$shared_patch" verified-candidate "$serving_cmake" "$serving_compiler"
write_manifest "$shared_candidate/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$candidate_patch,$shared_patch" verified-candidate "$serving_cmake" "$serving_compiler"
run_pair shared_series_registered "$reached_preflight_end" \
    "$shared_control" "$shared_candidate" QWEN_AB_SHARED_CANDIDATE_SERIES="$shared_patch"
run_pair shared_series_unregistered 'must name candidate_series - alone' \
    "$shared_control" "$shared_candidate"
write_manifest "$shared_control/artifact-manifest.tsv" "$control_bytes" \
    "$control_sha256" "$shared_patch" verified-candidate "$serving_cmake" "$serving_compiler" \
    1111111111111111111111111111111111111111111111111111111111111111
run_pair shared_control_digest_stale 'control shared candidate series digest differs' \
    "$shared_control" "$shared_candidate" QWEN_AB_SHARED_CANDIDATE_SERIES="$shared_patch"
printf 'shared_series_preflight=accepted\n'

census_patch=llama-vulkan-pipeline-census.patch
control_instrumented=$temporary_directory/control-instrumented
mkdir -p "$control_instrumented/bin"
cp -- "$control_server" "$control_instrumented/bin/llama-server"
chmod +x "$control_instrumented/bin/llama-server"
write_manifest "$control_instrumented/artifact-manifest.tsv" "$control_bytes" \
    "$control_sha256" "$census_patch" verified-candidate "$serving_cmake" "$serving_compiler"
printf 'instrumentation\tpipeline-census-v3\n' >>"$control_instrumented/artifact-manifest.tsv"
candidate_census_e4=$temporary_directory/candidate-census-e4
mkdir -p "$candidate_census_e4/bin"
cp -- "$candidate_server" "$candidate_census_e4/bin/llama-server"
chmod +x "$candidate_census_e4/bin/llama-server"
write_manifest "$candidate_census_e4/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$census_patch,$candidate_patch" verified-candidate \
    "$serving_cmake" "$serving_compiler"
printf 'instrumentation\tpipeline-census-v3\n' >>"$candidate_census_e4/artifact-manifest.tsv"
candidate_other_instrument=$temporary_directory/candidate-other-instrument
mkdir -p "$candidate_other_instrument/bin"
cp -- "$candidate_server" "$candidate_other_instrument/bin/llama-server"
chmod +x "$candidate_other_instrument/bin/llama-server"
write_manifest "$candidate_other_instrument/artifact-manifest.tsv" "$candidate_bytes" \
    "$candidate_sha256" "$census_patch,$candidate_patch" verified-candidate \
    "$serving_cmake" "$serving_compiler"
printf 'instrumentation\tpipeline-census-v2\n' >>"$candidate_other_instrument/artifact-manifest.tsv"
run_pair kernel_delta_mode_name 'QWEN_CENSUS_AB_MODE is served or kernel-delta' \
    "$control_root" "$candidate_root" QWEN_CENSUS_AB_MODE=bracket
run_pair kernel_delta_serving_control \
    'the control manifest must name instrumentation exactly once under kernel-delta' \
    "$control_root" "$candidate_census_e4" QWEN_CENSUS_AB_MODE=kernel-delta
run_pair kernel_delta_two_instruments 'kernel-delta compares one instrument' \
    "$control_instrumented" "$candidate_other_instrument" QWEN_CENSUS_AB_MODE=kernel-delta
run_pair kernel_delta_candidate_series \
    "must name candidate_series $census_patch,$candidate_patch alone under kernel-delta" \
    "$control_instrumented" "$candidate_instrumented" QWEN_CENSUS_AB_MODE=kernel-delta \
    QWEN_CENSUS_PRODUCTION_SERVER="$control_server"
run_pair kernel_delta_instrumented_control_under_served \
    'the control manifest names instrumentation' \
    "$control_instrumented" "$candidate_root"
run_pair kernel_delta_denominator_absent \
    'kernel-delta requires QWEN_CENSUS_PRODUCTION_SERVER' \
    "$control_instrumented" "$candidate_census_e4" QWEN_CENSUS_AB_MODE=kernel-delta
run_pair kernel_delta_denominator_mismatch 'does not carry one accepted server row' \
    "$control_instrumented" "$candidate_census_e4" QWEN_CENSUS_AB_MODE=kernel-delta \
    QWEN_CENSUS_PRODUCTION_SERVER="$candidate_server"
run_pair kernel_delta_admitted "$reached_preflight_end" \
    "$control_instrumented" "$candidate_census_e4" QWEN_CENSUS_AB_MODE=kernel-delta \
    QWEN_CENSUS_PRODUCTION_SERVER="$control_server"
printf 'kernel_delta_refusals=accepted\n'

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
if [ ! -s "$arm_environment" ]; then
    printf 'the served runner recorded no environment of its own\n' >&2
    arm_environment_failures=1
fi
for arm_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
    if grep -q "^$arm_name=" "$arm_environment"; then
        printf 'ambient %s reached the served runner environment\n' "$arm_name" >&2
        arm_environment_failures=1
    fi
done
[ "$arm_environment_failures" -eq 0 ]
printf 'arm_environment_closed=accepted records=%s\n' \
    "$(printf '%s\n' "$arm_records" | grep -c .)"

# The sealed key binds the arm into its own receipt. Two arms of one executable
# differ by the algorithm and the row count alone, so each arm's record carries
# the key its role was asked for and the ambient GGML_VK_Q4K_VARIANT reaches
# neither; the run's inputs state the pair.
# The keyed build: one executable both roles name, whose manifest declares the
# nine keys. A keyed comparison isolates its arm through the pipeline the device
# creates, so the series rule the two-binary comparison applies is replaced by
# equal digests and a key the manifest admits.
keyed_variants=e4/2,e4/4,e4/8,e4-scale/2,e4-scale/4,e4-scale/8,e4-scale-licm/2,e4-scale-licm/4,e4-scale-licm/8
keyed_root=$temporary_directory/keyed-build
mkdir -p "$keyed_root/bin"
cp -- "$control_server" "$keyed_root/bin/llama-server"
chmod +x "$keyed_root/bin/llama-server"
keyed_server=$keyed_root/bin/llama-server
keyed_bytes=$(wc -c <"$keyed_server" | tr -d ' ')
keyed_sha256=$(sha256sum "$keyed_server" | cut -d ' ' -f 1)
# A keyed build is a candidate tree: it carries the variant-select member, so
# its manifest reads verified-candidate and names the member the way any other
# candidate manifest does. What the keyed comparison drops is the series
# equality between the two roles, since both roles are this one build.
write_manifest "$keyed_root/artifact-manifest.tsv" "$keyed_bytes" "$keyed_sha256" \
    "$candidate_patch" verified-candidate "$serving_cmake" "$serving_compiler" '' \
    "$keyed_variants"

experiment_rates=$temporary_directory/rates-experiment
write_rates "$experiment_rates" 10.000 11.000 11.000
case_control_key=e4/4
case_candidate_key=e4-scale-licm/4
case_control_server=$keyed_server
case_candidate_server=$keyed_server
run_ab experiment_key_bound 0 promoted "$experiment_rates" "$one_clock"
active_fixture=experiment_key_bound
[ "$(awk -F'\t' '$1 == "control_experiment_key" { print $2 }' "$ab_last_output/inputs.tsv")" = 'e4/4' ]
[ "$(awk -F'\t' '$1 == "candidate_experiment_key" { print $2 }' "$ab_last_output/inputs.tsv")" \
    = 'e4-scale-licm/4' ]
experiment_key_failures=0
for arm_record in "$ab_last_output"/arms/*/arm-environment.tsv; do
    [ -f "$arm_record" ] || continue
    arm_role=$(basename "$(dirname "$arm_record")")
    arm_key=$(awk -F'\t' '$1 == "QWEN_Q4K_VARIANT" { print $2 }' "$arm_record")
    case $arm_role in
        *-K) arm_expected=e4-scale-licm/4 ;;
        *) arm_expected=e4/4 ;;
    esac
    if [ "$arm_key" != "$arm_expected" ]; then
        printf 'arm %s carries experiment key %s where %s was asked for\n' \
            "$arm_role" "${arm_key:--}" "$arm_expected" >&2
        experiment_key_failures=1
    fi
done
[ "$experiment_key_failures" -eq 0 ]
printf 'experiment_key_bound=accepted\n'

# A key naming no buildable arm, and a pair naming one arm twice, are each
# refused before an arm runs.
run_refusal_servers() {
    refusal_case=$1
    refusal_message=$2
    refusal_control=$3
    refusal_candidate=$4
    shift 4
    run_index=$((run_index + 1))
    active_fixture=$refusal_case
    set +e
    env -i PATH="$execution_path" HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" "$@" \
        "$harness" "$refusal_control" "$refusal_candidate" "$model_id" \
        "$temporary_directory/out-$run_index" \
        >/dev/null 2>"$temporary_directory/$refusal_case-stderr.txt"
    refusal_status=$?
    set -e
    [ "$refusal_status" -eq 2 ]
    grep -q "$refusal_message" "$temporary_directory/$refusal_case-stderr.txt"
    printf '%s=accepted\n' "$refusal_case"
}

run_refusal() {
    refusal_case=$1
    refusal_message=$2
    shift 2
    run_index=$((run_index + 1))
    active_fixture=$refusal_case
    diagnostic_file=$temporary_directory/$refusal_case-stderr.txt
    set +e
    env -i PATH="$execution_path" HOME="$home_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" "$@" \
        "$harness" "$control_server" "$candidate_server" "$model_id" \
        "$temporary_directory/out-$run_index" \
        >/dev/null 2>"$temporary_directory/$refusal_case-stderr.txt"
    refusal_status=$?
    set -e
    [ "$refusal_status" -eq 2 ]
    grep -q "$refusal_message" "$temporary_directory/$refusal_case-stderr.txt"
    printf '%s=accepted\n' "$refusal_case"
}
run_refusal experiment_key_unknown \
    'an experiment key is production/4, or e4, e4-scale, or e4-scale-licm over /2, /4, or /8' \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e5-scale/4
run_refusal experiment_key_rowless \
    'an experiment key is production/4, or e4, e4-scale, or e4-scale-licm over /2, /4, or /8' \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm
run_refusal experiment_key_identical \
    'the two experiment keys name one arm' \
    QWEN_AB_CONTROL_EXPERIMENT_KEY=e4/4 QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4/4
# A half-keyed run would leave the unkeyed role at the build's own default while
# its receipt named an arm.
run_refusal experiment_key_half \
    'a keyed comparison names an experiment key for both roles' \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4
# Two binaries under a keyed comparison measure the build beside the arm.
run_refusal experiment_key_two_binaries \
    'a keyed comparison names one executable twice' \
    QWEN_AB_CONTROL_EXPERIMENT_KEY=e4/4 \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4
# A build whose manifest declares no q4k_variants ignores the key and runs its
# default shader, so the receipt would name an arm the device never created.
run_refusal_servers experiment_key_undeclared \
    'the manifest declares no q4k_variants' \
    "$control_server" "$control_server" \
    QWEN_AB_CONTROL_EXPERIMENT_KEY=e4/4 \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4
# A key the shape rule admits and the build does not names an arm this
# executable cannot create, which a build declaring one key stands for.
narrow_root=$temporary_directory/keyed-build-narrow
mkdir -p "$narrow_root/bin"
cp -- "$keyed_server" "$narrow_root/bin/llama-server"
chmod +x "$narrow_root/bin/llama-server"
write_manifest "$narrow_root/artifact-manifest.tsv" "$keyed_bytes" "$keyed_sha256" \
    "$candidate_patch" verified-candidate "$serving_cmake" "$serving_compiler" '' e4/4
run_refusal_servers experiment_key_unadmitted \
    'the manifest does not admit experiment key e4-scale-licm/4' \
    "$narrow_root/bin/llama-server" "$narrow_root/bin/llama-server" \
    QWEN_AB_CONTROL_EXPERIMENT_KEY=e4/4 \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4

# A row that releases a formulation is the case a control key exists for.
# qwen-capacity-policy.sh resolves an empty QWEN_Q4K_VARIANT to the registry
# row, so an unkeyed comparison on such a row serves the release on both roles
# and a control naming production/4 is what selects the pinned commit's own
# module through the multiplexer instead. The registry the executing tree reads
# is a symlink into the checked-in one, so the case replaces it with a copy
# carrying the release and restores the link after.
released_registry=$temporary_directory/models-released.tsv
awk -F'\t' -v OFS='\t' -v id="$model_id" \
    '$1 == id && NF >= 23 { $23 = "e4-scale-licm/4" } { print }' \
    "$script_directory/models.tsv" >"$released_registry"
[ "$("$registry_reader" id "$model_id" q4k_variant)" = - ]
rm -- "$run_directory/models.tsv"
cp -- "$released_registry" "$run_directory/models.tsv"
released_variants=production/4,$keyed_variants
released_root=$temporary_directory/keyed-build-released
mkdir -p "$released_root/bin"
cp -- "$keyed_server" "$released_root/bin/llama-server"
chmod +x "$released_root/bin/llama-server"
write_manifest "$released_root/artifact-manifest.tsv" "$keyed_bytes" "$keyed_sha256" \
    "$candidate_patch" verified-candidate "$serving_cmake" "$serving_compiler" '' \
    "$released_variants"
case_control_key=production/4
case_candidate_key=e4-scale-licm/4
case_control_server=$released_root/bin/llama-server
case_candidate_server=$released_root/bin/llama-server
run_ab released_row_control 0 promoted "$experiment_rates" "$one_clock"
active_fixture=released_row_control
[ "$(awk -F'\t' '$1 == "control_experiment_key" { print $2 }' "$ab_last_output/inputs.tsv")" \
    = 'production/4' ]
released_key_failures=0
released_control_arms=0
for arm_record in "$ab_last_output"/arms/*/arm-environment.tsv; do
    [ -f "$arm_record" ] || continue
    arm_role=$(basename "$(dirname "$arm_record")")
    arm_key=$(awk -F'\t' '$1 == "QWEN_Q4K_VARIANT" { print $2 }' "$arm_record")
    case $arm_role in
        *-K) arm_expected=e4-scale-licm/4 ;;
        *) arm_expected=production/4; released_control_arms=$((released_control_arms + 1)) ;;
    esac
    if [ "$arm_key" != "$arm_expected" ]; then
        printf 'arm %s carries experiment key %s where %s was asked for\n' \
            "$arm_role" "${arm_key:--}" "$arm_expected" >&2
        released_key_failures=1
    fi
done
[ "$released_key_failures" -eq 0 ]
[ "$released_control_arms" -gt 0 ]
printf 'released_row_control=accepted control_arms=%s\n' "$released_control_arms"
# The same registry, unkeyed, would run both roles under the release, so the
# comparison is refused while the model id is the only thing it has spent.
active_fixture=released_row_unkeyed
run_index=$((run_index + 1))
released_unkeyed_stderr=$temporary_directory/released-row-unkeyed-stderr.txt
diagnostic_file=$released_unkeyed_stderr
set +e
env -i PATH="$run_path" HOME="$home_directory" \
    SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$fixture_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" \
    "$run_harness_path" "$released_root/bin/llama-server" \
    "$released_root/bin/llama-server" "$model_id" \
    "$temporary_directory/out-$run_index" \
    >/dev/null 2>"$released_unkeyed_stderr"
released_unkeyed_status=$?
set -e
[ "$released_unkeyed_status" -eq 2 ]
grep -q 'the registry row releases q4k_variant e4-scale-licm/4' "$released_unkeyed_stderr"
diagnostic_file=
printf 'released_row_unkeyed=accepted\n'
rm -- "$run_directory/models.tsv"
ln -s -- "$script_directory/models.tsv" "$run_directory/models.tsv"
case_control_key=
case_candidate_key=
case_control_server=$control_server
case_candidate_server=$candidate_server


# The witness reports another run's ids, so it is admitted only where that run
# was this comparison: its own inputs name the model and both server digests.
witness_foreign=$temporary_directory/witness-foreign
mkdir -p "$witness_foreign"
: >"$witness_foreign/margin-summary.tsv"
{
    printf 'model_id\tsome-other-model\n'
    printf 'control_server_sha256\t%s\n' "$control_sha256"
    printf 'candidate_server_sha256\t%s\n' "$candidate_sha256"
    printf 'control_experiment_key\t-\ncandidate_experiment_key\t-\n'
} >"$witness_foreign/inputs.tsv"
run_refusal witness_foreign_model \
    'the witness names model_id some-other-model where this campaign runs' \
    QWEN_AB_WITNESS_DIRECTORY="$witness_foreign"
witness_stale=$temporary_directory/witness-stale
mkdir -p "$witness_stale"
: >"$witness_stale/margin-summary.tsv"
{
    printf 'model_id\t%s\n' "$model_id"
    printf 'control_server_sha256\t%s\n' "$control_sha256"
    printf 'candidate_server_sha256\tstaledigest\n'
    printf 'control_experiment_key\t-\ncandidate_experiment_key\t-\n'
} >"$witness_stale/inputs.tsv"
run_refusal witness_stale_candidate \
    'the witness names candidate_server_sha256 staledigest where this campaign runs' \
    QWEN_AB_WITNESS_DIRECTORY="$witness_stale"
witness_matching=$temporary_directory/witness-matching
mkdir -p "$witness_matching"
: >"$witness_matching/margin-summary.tsv"
{
    printf 'model_id\t%s\n' "$model_id"
    printf 'control_server_sha256\t%s\n' "$control_sha256"
    printf 'candidate_server_sha256\t%s\n' "$candidate_sha256"
    printf 'control_experiment_key\t-\ncandidate_experiment_key\t-\n'
} >"$witness_matching/inputs.tsv"
witness_keyed=$temporary_directory/witness-keyed
mkdir -p "$witness_keyed"
: >"$witness_keyed/margin-summary.tsv"
{
    printf 'model_id\t%s\n' "$model_id"
    printf 'control_server_sha256\t%s\n' "$keyed_sha256"
    printf 'candidate_server_sha256\t%s\n' "$keyed_sha256"
    printf 'control_experiment_key\te4/2\n'
    printf 'candidate_experiment_key\te4-scale-licm/2\n'
} >"$witness_keyed/inputs.tsv"
# One executable serves every keyed arm, so the digests match whatever pair the
# witness ran; the keys are the only field that separates them.
run_refusal_servers witness_other_arm_pair \
    'the witness names control_experiment_key e4/2 where this campaign runs e4/4' \
    "$keyed_server" "$keyed_server" \
    QWEN_AB_CONTROL_EXPERIMENT_KEY=e4/4 \
    QWEN_AB_CANDIDATE_EXPERIMENT_KEY=e4-scale-licm/4 \
    QWEN_AB_WITNESS_DIRECTORY="$witness_keyed"

witness_rates=$temporary_directory/rates-witness
write_rates "$witness_rates" 10.000 11.000 11.000
case_witness=$witness_matching
run_ab witness_bound 0 promoted "$witness_rates" "$one_clock"
active_fixture=witness_bound
[ "$(awk -F'\t' '$1 == "witness_directory" { print $2 }' \
    "$ab_last_output/terminal-state.tsv")" = "$witness_matching" ]

# The lease as the clock's own authority. A campaign forces a DPM level every
# workload on the machine then runs at, so it takes the shared Vulkan lease
# ahead of the first write; another holder therefore refuses the campaign with
# the fixture level untouched.
active_fixture=workload_lease_held
run_index=$((run_index + 1))
lease_drm=$temporary_directory/drm-lease-held
cp -R -- "$fixture_drm" "$lease_drm"
printf 'auto\n' >"$lease_drm/power_dpm_force_performance_level"
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
printf 'rates\t%s\n' "$promoted_rates" >"$arm_controls"
env -i PATH="$run_path" HOME="$home_directory" SSH_CONNECTION="$run_ssh_connection" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
    QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
    QWEN_DRM_DEVICE="$lease_drm" QWEN_HWMON_ROOT="$fixture_hwmon" \
    QWEN_CENSUS_BROKER="$broker_stub" QWEN_CENSUS_SIDECAR_CPU=0 \
    QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease" \
    QWEN_TEST_AB_CLOCKS="$one_clock" \
    QWEN_CENSUS_ENGINE_CLOCK_POLICY=manual \
    "$run_harness_path" "$control_server" "$candidate_server" "$model_id" \
    "$temporary_directory/out-$run_index" \
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

active_fixture=complete
printf 'run_served_binary_ab=accepted cases=%s\n' "$run_index"
