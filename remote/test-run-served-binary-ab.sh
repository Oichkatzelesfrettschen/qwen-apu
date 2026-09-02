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
# `fail` leaves no response at all, which is the arm failure a case reads.
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
state = "1100"
table = os.environ.get("QWEN_TEST_AB_CLOCKS", "")
if table and os.path.exists(table):
    for line in open(table):
        name, _, value = line.rstrip("\n").partition("\t")
        if name == label:
            state = value
print(f"record_readable=accepted path={sys.argv[1]}")
print(f"clock_state=measured window_samples=700 sclk_mode_mhz={state}"
      " sclk_share=0.9235 mclk_mode_mhz=1067"
      " temp_mean_c=71.6 temp_max_c=74.0 busy_mean=94.88")
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
run_path=$run_bin:$execution_path
run_ssh_connection='127.0.0.1 40000 127.0.0.1 22'

# One rate table per verdict. A slot answers the rate its arm name and position
# are given here, and the mirrored quadruple gives each replicate its reverse.
write_rates() {
    rates_path=$1
    control_rate=$2
    first_candidate_rate=$3
    second_candidate_rate=$4
    {
        printf '00-W\t%s\n' "$control_rate"
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
    active_fixture=$ab_case
    run_index=$((run_index + 1))
    ab_output=$temporary_directory/out-$run_index
    diagnostic_file=$temporary_directory/$ab_case-stderr.txt
    set +e
    env -i \
        PATH="$run_path" \
        HOME="$home_directory" \
        SSH_CONNECTION="$run_ssh_connection" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_CENSUS_RUNTIME_REMOTE="$runtime_remote" \
        QWEN_CENSUS_PRODUCTION_RECEIPT="$scoreboard_receipt/identity-check.tsv" \
        QWEN_DRM_DEVICE="$fixture_drm" \
        QWEN_HWMON_ROOT="$fixture_hwmon" \
        QWEN_CENSUS_BROKER="$broker_stub" \
        QWEN_CENSUS_SIDECAR_CPU=0 \
        QWEN_AB_COOLDOWN_S=0 \
        QWEN_VULKAN_WORKLOAD_LOCK="$temporary_directory/vulkan-workload.lock" \
        QWEN_TEST_AB_RATES="$ab_rates" \
        QWEN_TEST_AB_CLOCKS="$ab_clocks" \
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

# Every arm holds one graphics clock, so every pair is comparable and the
# verdict is the interval's own.
one_clock=$temporary_directory/clocks-one-state
: >"$one_clock"

# A candidate 10% faster on every replicate: the interval is degenerate at
# +0.1000, wholly above the 5% bound, and the run promotes.
promoted_rates=$temporary_directory/rates-promoted
write_rates "$promoted_rates" 10.000 11.000 11.000
run_ab verdict_promoted 0 promoted "$promoted_rates" "$one_clock"
active_fixture=arms_ledger_columns
[ "$(head -n 1 "$ab_last_output/arms.tsv")" = "$(printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\tsclk_mode_mhz\tsclk_share')" ]
awk -F'\t' 'NF != 12 { exit 1 }' "$ab_last_output/arms.tsv"
[ "$(awk 'END { print NR }' "$ab_last_output/arms.tsv")" = 10 ]
# The warmup opens the ledger at slot 0 with the sampler off and enters no
# pair; the summarizer's own filter is what keeps it out.
[ "$(awk -F'\t' 'NR == 2 { print $1, $2, $8, $11 }' "$ab_last_output/arms.tsv")" = '0 W off -' ]
[ "$(awk -F'\t' 'NR == 3 { print $2, $8, $11, $12 }' "$ab_last_output/arms.tsv")" = 'C on 1100 0.9235' ]
[ "$(awk -F'\t' 'NR == 3 { print $7, $9 }' "$ab_last_output/arms.tsv")" = '- -' ]
printf 'arms_ledger_columns=accepted\n'
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
    printf '02-K\t800\n03-K\t800\n06-K\t800\n07-K\t800\n'
} >"$stepped_clocks"
run_ab verdict_state_changed 4 state-changed "$promoted_rates" "$stepped_clocks"

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

active_fixture=complete
printf 'run_served_binary_ab=accepted cases=%s\n' "$run_index"
