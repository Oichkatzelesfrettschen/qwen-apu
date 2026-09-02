#!/bin/sh
set -eu

# The pipeline census runner: one model, one ordered list of arms, each arm a
# fixed-64 served decode through measure-served-decode.sh under the model's
# registered tuple. Five execution states are admitted by name. P is the
# promoted production server under the low-async serving profile with the
# clock sidecar sampling beside it; P-nosidecar is the same server with the
# sidecar off; I0 is the census build with collection off; I1 is the census
# build with GGML_VK_PIPELINE_CENSUS naming the arm's output file; S is the
# census build under the diagnostic profile with the pinned vk_perf_logger
# armed at frequency 1, which is the identity control: every node behind a
# barrier, every graph ending in a host wait, op names and call counts per
# graph retained from the logger's own print over the bytes server.log
# gained inside the request window. Every arm, S included, runs through the
# served harness, so the workload lease, the process identity capture, the
# kernel-hazard watch, the graphics-latency record, and the teardown proof
# hold for each.
#
# QWEN_CENSUS_MODE names the campaign contract. A calibration runs the exact
# thirteen-arm sequence and terminates accepted only where all three
# registered controls accept and no quadruple is unclassified, so a reordered
# arm list or a fourth quadruple fails the run rather than passing beside the
# three. An attribution runs any registered arm list, I1 alone included, and
# requires QWEN_CENSUS_CALIBRATION_RECEIPT to name the output directory of an
# accepted calibration whose production and instrumented servers are the two
# this run binds, since the bounds a calibration accepted belong to those two
# binaries. Three quadruples carry a registered bound and
# summarize-census-controls.py assigns a verdict to those alone:
# P-nosidecar P P P-nosidecar measures the sampler's own cost, P I0 I0 P the
# instrument compiled in, and I0 I1 I1 I0 collection under the sampler.
#
# P is bound to the scoreboard it stands for rather than to a path: its
# artifact manifest must describe exactly that executable, name no
# instrumentation, declare serving_eligible yes or nothing, and the fixed-64
# identity receipt QWEN_CENSUS_PRODUCTION_RECEIPT names must carry one
# server row whose expected and observed digest and byte count are P's. The
# denominator is the tuple beside the binary: the models-resolved.tsv in the
# receipt's directory must resolve this model to the context, submission
# geometry, cache triple, Flash Attention state, checkpoint count and step,
# and artifact digest the registry and ledger resolve it to now, and the
# campaign-inputs.tsv there must state the profile, token count, sampling,
# priority, and inference placement every arm here runs under, so a registry
# edit between the scoreboard and the census refuses the run rather than
# changing the experiment behind a byte-identical P.
# The instrumented server is bound to a manifest declaring exactly one
# instrumentation pipeline-census-v3 row and one serving_eligible no row.
# Both manifests must carry one checkpoint_semantics row reading
# natural-boundary-v1 wherever the registry row runs a positive checkpoint
# count, since a positive count against the forced-tail partition changes the
# decode shape the instrument measures.
#
# An arm completes only where everything it retained is evidence: the served
# runner exited 0 with a consistent rate, the sidecar exited 0 and its record
# passes validate-clock-sidecar.py, an I1 census passes the summarizer over
# the retained request window with predicted_n - 1 decode graphs, and an S
# slice holds at least that many logger blocks. A refuted registered control
# ends the campaign as refuted with exit 3; a failed arm ends it as failed
# with exit 1; accepted alone exits 0.
#
# usage: run-raven2-vulkan-kernel-census.sh MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_PRODUCTION_SERVER    path of P (required where an arm names P or P-nosidecar)
#   QWEN_CENSUS_PRODUCTION_RECEIPT   identity-check.tsv of the fixed-64 scoreboard sweep
#                                    (required beside the production server)
#   QWEN_CENSUS_INSTRUMENTED_SERVER  path of I0/I1/S (required where an arm names one)
#   QWEN_CENSUS_MODE                 calibration (default) or attribution
#   QWEN_CENSUS_CALIBRATION_RECEIPT  output directory of an accepted calibration
#                                    (required under attribution)
#   QWEN_CENSUS_ARMS                 space-separated arm names under attribution;
#                                    a calibration runs exactly
#                                    "P-nosidecar P P P-nosidecar P I0 I0 P I0 I1 I1 I0 S"
#   QWEN_CENSUS_COOLDOWN_S           idle seconds between arms, default 30
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms
#   QWEN_CENSUS_RUNTIME_REMOTE       synced runtime tree the arms launch through,
#                                    default ~/qwen-laptop-setup/remote
#   QWEN_CENSUS_SIDECAR_BOUND        admitted |delta| for a P-nosidecar/P pair, default 0.0065
#   QWEN_CENSUS_COMPILE_BOUND        admitted |delta| for a P/I0 pair, default 0.0065
#   QWEN_CENSUS_COLLECT_BOUND        admitted |delta| for an I0/I1 pair, default 0.02
#   QWEN_CENSUS_OVERLAP_THRESHOLD    mean bracket overlap fraction above which the
#                                    I1 ledger reads inconclusive, default 0.05
#   QWEN_CENSUS_SIDECAR_PERIOD_MS    clock sidecar period, default 5
#   QWEN_CENSUS_SIDECAR_TOLERANCE    admitted achieved-period deviation, default 0.25
#   QWEN_CENSUS_SIDECAR_COST_NS      admitted mean sample cost, default 1000000
#   QWEN_CENSUS_SIDECAR_MAX_GAP_MS   hard maximum adjacent sample gap inside the
#                                    request window, default 10
#   QWEN_CENSUS_SIDECAR_CPU          the core the sampler is pinned to, default 1
#   QWEN_CENSUS_SIDECAR_NICE         the sampler's niceness, default 10

if [ "$#" -ne 2 ]; then
    printf 'usage: %s MODEL_ID OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

model_id=$1
output_directory=$2
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_reader=$script_directory/model-registry.sh
runner=$script_directory/measure-served-decode.sh
summarizer=$script_directory/summarize-kernel-census.py
controls_summarizer=$script_directory/summarize-census-controls.py
sidecar=$script_directory/sample-clock-sidecar.py
sidecar_validator=$script_directory/validate-clock-sidecar.py
slice_summarizer=$script_directory/summarize-perf-logger-slice.py
calibration_arms="P-nosidecar P P P-nosidecar P I0 I0 P I0 I1 I1 I0 S"
census_mode=${QWEN_CENSUS_MODE:-calibration}
calibration_receipt=${QWEN_CENSUS_CALIBRATION_RECEIPT:-}
case $census_mode in
    calibration)
        arms=${QWEN_CENSUS_ARMS:-$calibration_arms}
        if [ "$arms" != "$calibration_arms" ]; then
            printf 'a calibration runs exactly "%s"; QWEN_CENSUS_ARMS names "%s"\n' \
                "$calibration_arms" "$arms" >&2
            exit 2
        fi
        ;;
    attribution)
        arms=${QWEN_CENSUS_ARMS:-I1}
        if [ -z "$calibration_receipt" ]; then
            printf 'an attribution requires QWEN_CENSUS_CALIBRATION_RECEIPT naming an accepted calibration\n' >&2
            exit 2
        fi
        ;;
    *)
        printf 'QWEN_CENSUS_MODE must be calibration or attribution: %s\n' "$census_mode" >&2
        exit 2
        ;;
esac
cooldown_s=${QWEN_CENSUS_COOLDOWN_S:-30}
production_server=${QWEN_CENSUS_PRODUCTION_SERVER:-}
production_receipt=${QWEN_CENSUS_PRODUCTION_RECEIPT:-}
instrumented_server=${QWEN_CENSUS_INSTRUMENTED_SERVER:-}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
sidecar_bound=${QWEN_CENSUS_SIDECAR_BOUND:-0.0065}
compile_bound=${QWEN_CENSUS_COMPILE_BOUND:-0.0065}
collect_bound=${QWEN_CENSUS_COLLECT_BOUND:-0.02}
overlap_threshold=${QWEN_CENSUS_OVERLAP_THRESHOLD:-0.05}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-5}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-10}
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))
sidecar_cpu=${QWEN_CENSUS_SIDECAR_CPU:-1}
sidecar_nice=${QWEN_CENSUS_SIDECAR_NICE:-10}
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
# The SMU10 kernel path exposes pp_dpm_fclk as an empty file and reports the
# fabric clock through pp_dpm_mclk, so a column the kernel leaves empty at
# campaign start is allowed to read unavailable and every other column is
# required on every sample; the allowance is recorded beside the arms. The
# emptiness is decided by reading the attribute, since sysfs reports every
# attribute at one page in stat and a size test reads an empty file as full,
# and only a readable attribute whose read succeeds and returns nothing
# earns it: an absent attribute, an unreadable one, or a read that fails
# is a different telemetry state and refuses the run.
sidecar_allowed_unavailable=''
fclk_path=$drm_device/pp_dpm_fclk
if [ ! -e "$fclk_path" ]; then
    printf 'pp_dpm_fclk is absent: %s\n' "$fclk_path" >&2
    exit 2
fi
if [ ! -r "$fclk_path" ]; then
    printf 'pp_dpm_fclk is unreadable: %s\n' "$fclk_path" >&2
    exit 2
fi
set +e
fclk_contents=$(cat "$fclk_path")
fclk_status=$?
set -e
if [ "$fclk_status" -ne 0 ]; then
    printf 'pp_dpm_fclk read failed with status %s: %s\n' "$fclk_status" "$fclk_path" >&2
    exit 2
fi
if [ -z "$fclk_contents" ]; then
    sidecar_allowed_unavailable=pp_dpm_fclk_surface_mhz
fi
# The launch chain runs from the synced runtime tree alone, and a git
# worktree is refused at launch, so the arms launch and tear down through
# that tree while this runner and its readers come from wherever the
# operator checked out.
runtime_remote=${QWEN_CENSUS_RUNTIME_REMOTE:-"${HOME:?}/qwen-laptop-setup/remote"}
# measure-served-decode.sh pins the model through a descriptor, and the
# launch admits a descriptor-backed path only with the approved identity the
# served runner derives from the artifact ledger, so the ledger travels with
# every arm; a run without it refuses at launch on every served arm.
artifact_ledger=${QWEN_MODEL_ARTIFACTS:-"$script_directory/model-artifacts.tsv"}
if [ ! -r "$artifact_ledger" ] || [ -L "$artifact_ledger" ]; then
    printf 'model artifact ledger is unreadable or linked: %s\n' "$artifact_ledger" >&2
    exit 2
fi
for runtime_script in qwen-launch.sh qwen-teardown.sh radv-low-priority-env.sh; do
    if [ ! -x "$runtime_remote/$runtime_script" ]; then
        printf 'runtime tree script is not executable: %s\n' \
            "$runtime_remote/$runtime_script" >&2
        exit 2
    fi
done
for reader in "$summarizer" "$controls_summarizer" "$sidecar" "$sidecar_validator" "$slice_summarizer"; do
    if [ ! -r "$reader" ]; then
        printf 'census reader is absent: %s\n' "$reader" >&2
        exit 2
    fi
done

if [ -e "$output_directory" ]; then
    printf 'output directory exists and a census never appends to one: %s\n' \
        "$output_directory" >&2
    exit 2
fi
case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac

needs_production=0
needs_instrumented=0
for arm in $arms; do
    case $arm in
        P | P-nosidecar) needs_production=1 ;;
        I0 | I1 | S) needs_instrumented=1 ;;
        *)
            printf 'arm name must be P, P-nosidecar, I0, I1, or S: %s\n' "$arm" >&2
            exit 2
            ;;
    esac
done

# The tuple is the registry's own, read through the same reader the
# scoreboard campaign used. The checkpoint count decides which
# checkpoint_semantics declaration both servers must carry.
"$registry_reader" id "$model_id" >/dev/null
model_file=$("$registry_reader" id "$model_id" model_file)
model_path=$models_directory/$model_file
context=$("$registry_reader" id "$model_id" context_default)
batch=$("$registry_reader" id "$model_id" batch)
ubatch=$("$registry_reader" id "$model_id" ubatch)
cache_k=$("$registry_reader" id "$model_id" cache_type_k)
cache_v=$("$registry_reader" id "$model_id" cache_type_v)
flash=$("$registry_reader" id "$model_id" flash_attention)
ctx_checkpoints=$("$registry_reader" ctx-checkpoint "$model_id")
checkpoint_min_step=8192
if [ ! -r "$model_path" ]; then
    printf 'model file is unreadable: %s\n' "$model_path" >&2
    exit 2
fi

# The manifest sits beside a bundled server or one directory above a build
# tree's bin/, and the executable is bound to it by byte count and digest:
# the manifest names llama-server in exactly one executable row and that row
# describes this file, the rule the bundle verifier and the exec guard apply,
# so a manifest carrying one matching row beside a conflicting one is
# ambiguous here as it is there.
manifest_beside() {
    manifest_candidate=$(dirname -- "$1")/artifact-manifest.tsv
    if [ ! -r "$manifest_candidate" ]; then
        manifest_candidate=$(dirname -- "$1")/../artifact-manifest.tsv
    fi
    if [ ! -r "$manifest_candidate" ]; then
        printf 'the %s server carries no artifact manifest beside it or above its bin/: %s\n' \
            "$2" "$1" >&2
        exit 2
    fi
    printf '%s\n' "$manifest_candidate"
}

# Prints sha256, bytes, manifest sha256, checkpoint_semantics, and
# checkpoint_patch_series_sha256 for one server, refusing a manifest that
# does not describe it or that names checkpoint semantics the checkpoint
# count cannot run under.
bind_server() {
    bound_role=$1
    bound_server=$2
    bound_manifest=$3
    if [ ! -x "$bound_server" ]; then
        printf 'the %s server must be an executable: %s\n' "$bound_role" "${bound_server:--}" >&2
        exit 2
    fi
    bound_sha256=$(sha256sum "$bound_server" | cut -d ' ' -f 1)
    bound_bytes=$(wc -c <"$bound_server" | tr -d ' ')
    if ! awk -F'\t' -v bytes="$bound_bytes" -v digest="$bound_sha256" '
        $1 == "executable" && $2 == "llama-server" { named++
            if (NF == 4 && $3 == bytes && $4 == digest) found++ }
        END { exit (named == 1 && found == 1) ? 0 : 1 }' "$bound_manifest"; then
        printf 'the %s server is not the one executable llama-server row its manifest carries: %s\n' \
            "$bound_role" "$bound_server" >&2
        exit 2
    fi
    bound_semantics=$(awk -F'\t' '$1 == "checkpoint_semantics" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$bound_manifest") || {
        printf 'the %s manifest holds other than one checkpoint_semantics row\n' "$bound_role" >&2
        exit 2
    }
    if [ "$ctx_checkpoints" -gt 0 ] && [ "$bound_semantics" != natural-boundary-v1 ]; then
        printf 'the %s server declares checkpoint semantics %s and the registry row runs %s checkpoints; natural-boundary-v1 is required\n' \
            "$bound_role" "$bound_semantics" "$ctx_checkpoints" >&2
        exit 2
    fi
    bound_series=$(awk -F'\t' '$1 == "checkpoint_patch_series_sha256" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$bound_manifest") || {
        printf 'the %s manifest holds other than one checkpoint_patch_series_sha256 row\n' "$bound_role" >&2
        exit 2
    }
    printf '%s\t%s\t%s\t%s\t%s\n' "$bound_sha256" "$bound_bytes" \
        "$(sha256sum "$bound_manifest" | cut -d ' ' -f 1)" "$bound_semantics" "$bound_series"
}

# The binding runs in a command substitution, so its status is captured
# explicitly at the call site and every field is required nonempty before
# the caller reads it: a refusal inside a here-document substitution ends
# only the subshell and leaves read filling every field empty, which is how
# a mismatched instrumented manifest once entered the arm loop.
require_binding_fields() {
    if ! printf '%s\n' "$2" | awk -F'\t' 'NF != 5 { exit 1 }
        { for (i = 1; i <= NF; i++) if ($i == "") exit 1 }'; then
        printf 'the %s binding printed other than five nonempty fields\n' "$1" >&2
        exit 2
    fi
}

production_sha256=-
production_bytes=-
production_manifest=-
production_manifest_sha256=-
production_semantics=-
production_series=-
production_receipt_sha256=-
scoreboard_models_sha256=-
scoreboard_inputs_sha256=-
scoreboard_registry_sha256=-
scoreboard_ledger_sha256=-
if [ "$needs_production" = 1 ]; then
    production_manifest=$(manifest_beside "$production_server" production)
    set +e
    production_binding=$(bind_server production "$production_server" "$production_manifest")
    binding_status=$?
    set -e
    [ "$binding_status" -eq 0 ] || exit "$binding_status"
    require_binding_fields production "$production_binding"
    IFS="$(printf '\t')" read -r production_sha256 production_bytes production_manifest_sha256 \
        production_semantics production_series <<EOF
$production_binding
EOF
    # Cardinality and the exact value are decided inside awk over the whole
    # tab-delimited field, so a value carrying a space is compared as the
    # literal it is rather than word-split into a passing first token.
    if ! awk -F'\t' '$1 == "instrumentation" { instrumentation++ }
        END { exit instrumentation == 0 ? 0 : 1 }' "$production_manifest"; then
        printf 'the production manifest names instrumentation; P is the promoted serving build alone\n' >&2
        exit 2
    fi
    if ! awk -F'\t' '$1 == "serving_eligible" { eligible++; value = $2 }
        END { if (eligible == 0) exit 0; exit (eligible == 1 && value == "yes") ? 0 : 1 }' \
        "$production_manifest"; then
        printf 'the production manifest declares serving_eligible other than exactly yes in exactly one row or none: %s\n' \
            "$(awk -F'\t' '$1 == "serving_eligible" { printf "[%s] ", $2 }' "$production_manifest")" >&2
        exit 2
    fi
    # The receipt is the identity-check.tsv of the fixed-64 scoreboard sweep
    # whose denominator P stands for; its one server row must carry P's
    # digest and byte count as both expected and observed, accepted.
    if [ ! -r "$production_receipt" ]; then
        printf 'QWEN_CENSUS_PRODUCTION_RECEIPT must name the readable identity-check.tsv of the scoreboard sweep: %s\n' \
            "${production_receipt:--}" >&2
        exit 2
    fi
    if ! awk -F'\t' -v bytes="$production_bytes" -v digest="$production_sha256" '
        NR == 1 && $0 != "subject\tpath\texpected_bytes\tobserved_bytes\texpected_sha256\tobserved_sha256\tstate" { exit 1 }
        $1 == "server" { rows++; if ($3 == bytes && $4 == bytes && $5 == digest && $6 == digest && $7 == "accepted") matched++ }
        END { exit (rows == 1 && matched == 1) ? 0 : 1 }' "$production_receipt"; then
        printf 'the scoreboard receipt does not carry one accepted server row with the production digest %s and %s bytes: %s\n' \
            "$production_sha256" "$production_bytes" "$production_receipt" >&2
        exit 2
    fi
    production_receipt_sha256=$(sha256sum "$production_receipt" | cut -d ' ' -f 1)
    # The receipt directory carries the tuple the scoreboard resolved and the
    # campaign inputs it ran under; both must equal what this run resolves.
    receipt_directory=$(dirname -- "$production_receipt")
    scoreboard_models=$receipt_directory/models-resolved.tsv
    scoreboard_inputs=$receipt_directory/campaign-inputs.tsv
    for scoreboard_file in "$scoreboard_models" "$scoreboard_inputs"; do
        if [ ! -r "$scoreboard_file" ]; then
            printf 'the scoreboard receipt directory carries no readable %s\n' \
                "$(basename -- "$scoreboard_file")" >&2
            exit 2
        fi
    done
    ledger_sha256=$(awk -F'\t' -v id="$model_id" '$1 == id { print $4 }' "$artifact_ledger")
    ledger_bytes=$(awk -F'\t' -v id="$model_id" '$1 == id { print $3 }' "$artifact_ledger")
    if [ -z "$ledger_sha256" ] || [ -z "$ledger_bytes" ]; then
        printf 'the model artifact ledger resolves no identity for %s\n' "$model_id" >&2
        exit 2
    fi
    if ! awk -F'\t' -v id="$model_id" -v context="$context" -v batch="$batch" -v ubatch="$ubatch" \
        -v cache_k="$cache_k" -v cache_v="$cache_v" -v flash="$flash" \
        -v checkpoints="$ctx_checkpoints" -v min_step="$checkpoint_min_step" \
        -v bytes="$ledger_bytes" -v digest="$ledger_sha256" '
        NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
        $(column["model_id"]) == id { rows++
            if ($(column["context"]) == context && $(column["batch"]) == batch \
                && $(column["ubatch"]) == ubatch && $(column["cache_k"]) == cache_k \
                && $(column["cache_v"]) == cache_v && $(column["flash_attention"]) == flash \
                && $(column["ctx_checkpoints"]) == checkpoints \
                && $(column["checkpoint_min_step"]) == min_step \
                && $(column["model_bytes"]) == bytes && $(column["model_sha256"]) == digest \
                && $(column["publisher_sha256"]) == digest) matched++ }
        END { exit (rows == 1 && matched == 1) ? 0 : 1 }' "$scoreboard_models"; then
        printf 'the scoreboard resolved %s to a tuple other than the one the registry and ledger resolve now: %s\n' \
            "$model_id" "$scoreboard_models" >&2
        exit 2
    fi
    if ! awk -F'\t' '
        $1 == "vulkan_profile" && $2 == "low-async" { seen["profile"] = 1 }
        $1 == "generate_tokens" && $2 == "64" { seen["generate"] = 1 }
        $1 == "sampling" && $2 == "temperature=0 top_k=1 seed=1 ignore_eos=true thinking=false" { seen["sampling"] = 1 }
        $1 == "server_nice" && $2 == "19" { seen["nice"] = 1 }
        $1 == "inference_cpu" && $2 == "0" { seen["placement"] = 1 }
        $1 == "speculation" && $2 == "off" { seen["speculation"] = 1 }
        $1 == "router" && $2 == "0" { seen["router"] = 1 }
        END { exit length(seen) == 7 ? 0 : 1 }' "$scoreboard_inputs"; then
        printf 'the scoreboard campaign inputs state a profile, token count, sampling, priority, placement, speculation, or router setting other than the one every arm here runs under: %s\n' \
            "$scoreboard_inputs" >&2
        exit 2
    fi
    scoreboard_models_sha256=$(sha256sum "$scoreboard_models" | cut -d ' ' -f 1)
    scoreboard_inputs_sha256=$(sha256sum "$scoreboard_inputs" | cut -d ' ' -f 1)
    scoreboard_registry_sha256=$(awk -F'\t' '$1 == "model_registry" { print $6 }' "$production_receipt")
    scoreboard_ledger_sha256=$(awk -F'\t' '$1 == "artifact_ledger" { print $6 }' "$production_receipt")
fi

instrumented_sha256=-
instrumented_bytes=-
instrumented_manifest=-
instrumented_manifest_sha256=-
instrumented_semantics=-
instrumented_series=-
if [ "$needs_instrumented" = 1 ]; then
    instrumented_manifest=$(manifest_beside "$instrumented_server" instrumented)
    set +e
    instrumented_binding=$(bind_server instrumented "$instrumented_server" "$instrumented_manifest")
    binding_status=$?
    set -e
    [ "$binding_status" -eq 0 ] || exit "$binding_status"
    require_binding_fields instrumented "$instrumented_binding"
    IFS="$(printf '\t')" read -r instrumented_sha256 instrumented_bytes instrumented_manifest_sha256 \
        instrumented_semantics instrumented_series <<EOF
$instrumented_binding
EOF
    # Exactly one row of each declaration at its exact value, decided inside
    # awk over the whole field: a manifest naming eligibility twice is
    # refused rather than read by its first row, and a value carrying a
    # space is the literal it is rather than its first word.
    if ! awk -F'\t' '
        $1 == "instrumentation" { instrumentation++; declared_instrumentation = $2 }
        $1 == "serving_eligible" { eligible++; declared_eligibility = $2 }
        END { exit (instrumentation == 1 && eligible == 1 \
            && declared_instrumentation == "pipeline-census-v3" && declared_eligibility == "no") ? 0 : 1 }' \
        "$instrumented_manifest"; then
        printf 'the instrumented manifest must declare instrumentation pipeline-census-v3 and serving_eligible no, each in exactly one row: instrumentation %s serving_eligible %s\n' \
            "$(awk -F'\t' '$1 == "instrumentation" { printf "[%s] ", $2 }' "$instrumented_manifest")" \
            "$(awk -F'\t' '$1 == "serving_eligible" { printf "[%s] ", $2 }' "$instrumented_manifest")" >&2
        exit 2
    fi
fi

# P and I differ by the census instrumentation alone, and that is proven
# rather than named. Each manifest yields a base-build identity from the
# rows both carry: the llama.cpp commit, the production patch series
# digest, the checkpoint patch and source digests, the compiler flags, and
# the CMake flags with the one census flag removed; the compiler identity
# is read from each executable's own .comment section, since the manifest
# records flags rather than the toolchain. The two identities must be
# equal, and I's CMake delta must be exactly -DGGML_VULKAN_PIPELINE_CENSUS=ON
# with one candidate_series row naming llama-vulkan-pipeline-census.patch.
census_cmake_flag=-DGGML_VULKAN_PIPELINE_CENSUS=ON
# Prints the one value of a manifest key; other than one row is a refusal
# the caller carries out explicitly, since this runs in a substitution.
manifest_value() {
    awk -F'\t' -v key="$2" '$1 == key { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$1" || {
        printf 'the %s manifest holds other than one %s row\n' "$3" "$2" >&2
        return 2
    }
}
# Writes the base-build identity of one manifest and server to $4.
base_build_identity() {
    identity_manifest=$1
    identity_server=$2
    identity_role=$3
    identity_output=$4
    identity_commit=$(manifest_value "$identity_manifest" commit "$identity_role") || exit 2
    identity_series=$(manifest_value "$identity_manifest" checkpoint_patch_series_sha256 "$identity_role") || exit 2
    identity_patch=$(manifest_value "$identity_manifest" checkpoint_patch_sha256 "$identity_role") || exit 2
    identity_source=$(manifest_value "$identity_manifest" checkpoint_source_sha256 "$identity_role") || exit 2
    identity_compiler_flags=$(manifest_value "$identity_manifest" compiler_flags "$identity_role") || exit 2
    identity_cmake=$(manifest_value "$identity_manifest" cmake_flags "$identity_role") || exit 2
    identity_cmake=$(printf '%s\n' "$identity_cmake" | tr ' ' '\n' | grep -vx -- "$census_cmake_flag" \
        | tr '\n' ' ' | sed 's/ *$//') || true
    identity_compiler=$(readelf -p .comment "$identity_server" 2>/dev/null \
        | sed -n 's/^ *\[ *[0-9]*\] *//p' | sort | tr '\n' ';')
    {
        printf 'commit\t%s\n' "$identity_commit"
        printf 'checkpoint_patch_series_sha256\t%s\n' "$identity_series"
        printf 'checkpoint_patch_sha256\t%s\n' "$identity_patch"
        printf 'checkpoint_source_sha256\t%s\n' "$identity_source"
        printf 'compiler_flags\t%s\n' "$identity_compiler_flags"
        printf 'cmake_flags_common\t%s\n' "$identity_cmake"
        printf 'compiler_identity\t%s\n' "$identity_compiler"
    } >"$identity_output"
}
production_base_identity_sha256=-
instrumented_base_identity_sha256=-
shader_compiler_identity=unrecorded
if [ "$needs_production" = 1 ] && [ "$needs_instrumented" = 1 ]; then
    identity_scratch=$(mktemp -d)
    base_build_identity "$production_manifest" "$production_server" production "$identity_scratch/production"
    base_build_identity "$instrumented_manifest" "$instrumented_server" instrumented "$identity_scratch/instrumented"
    if ! cmp -s "$identity_scratch/production" "$identity_scratch/instrumented"; then
        printf 'the production and instrumented servers descend from different base builds:\n' >&2
        diff -- "$identity_scratch/production" "$identity_scratch/instrumented" >&2 || true
        rm -r -- "$identity_scratch"
        exit 2
    fi
    production_base_identity_sha256=$(sha256sum "$identity_scratch/production" | cut -d ' ' -f 1)
    instrumented_base_identity_sha256=$(sha256sum "$identity_scratch/instrumented" | cut -d ' ' -f 1)
    rm -r -- "$identity_scratch"
    instrumented_cmake=$(manifest_value "$instrumented_manifest" cmake_flags instrumented) || exit 2
    production_cmake=$(manifest_value "$production_manifest" cmake_flags production) || exit 2
    instrumented_delta=$(printf '%s\n' "$instrumented_cmake" | tr ' ' '\n' \
        | grep -vxF -- "$(printf '%s\n' "$production_cmake" | tr ' ' '\n')" | tr '\n' ' ') || true
    if [ "$instrumented_delta" != "$census_cmake_flag " ]; then
        printf 'the instrumented CMake delta against production must be exactly %s: [%s]\n' \
            "$census_cmake_flag" "$instrumented_delta" >&2
        exit 2
    fi
    candidate_series=$(manifest_value "$instrumented_manifest" candidate_series instrumented) || exit 2
    if [ "$candidate_series" != llama-vulkan-pipeline-census.patch ]; then
        printf 'the instrumented manifest must name candidate_series llama-vulkan-pipeline-census.patch: %s\n' \
            "$candidate_series" >&2
        exit 2
    fi
fi

# An attribution rests on a calibration: the receipt directory's
# terminal-state.tsv reads accepted with three accepted controls and none
# unclassified, and its inputs.tsv binds the same two server digests, so
# the bounds that calibration accepted cover the binaries this run drives.
calibration_receipt_sha256=-
if [ "$census_mode" = attribution ]; then
    for receipt_member in terminal-state.tsv inputs.tsv; do
        if [ ! -r "$calibration_receipt/$receipt_member" ]; then
            printf 'the calibration receipt directory carries no readable %s: %s\n' \
                "$receipt_member" "$calibration_receipt" >&2
            exit 2
        fi
    done
    if ! awk -F'=' '
        $1 == "census" && $2 == "accepted" { seen["census"] = 1 }
        $1 == "control_accepted" && $2 == "3" { seen["accepted"] = 1 }
        $1 == "control_unclassified" && $2 == "0" { seen["unclassified"] = 1 }
        $1 == "control_refutations" && $2 == "0" { seen["refuted"] = 1 }
        $1 == "control_incomplete" && $2 == "0" { seen["incomplete"] = 1 }
        $1 == "arm_failures" && $2 == "0" { seen["failures"] = 1 }
        END { exit length(seen) == 6 ? 0 : 1 }' "$calibration_receipt/terminal-state.tsv"; then
        printf 'the calibration receipt is not an accepted calibration with three accepted controls: %s\n' \
            "$calibration_receipt/terminal-state.tsv" >&2
        exit 2
    fi
    if ! awk -F'\t' -v mode="$census_mode" -v production="$production_sha256" \
        -v instrumented="$instrumented_sha256" '
        $1 == "census_mode" && $2 == "calibration" { seen["mode"] = 1 }
        $1 == "production_server_sha256" && (production == "-" || $2 == production) { seen["production"] = 1 }
        $1 == "instrumented_server_sha256" && (instrumented == "-" || $2 == instrumented) { seen["instrumented"] = 1 }
        END { exit length(seen) == 3 ? 0 : 1 }' "$calibration_receipt/inputs.tsv"; then
        printf 'the calibration receipt was run in another mode or bound other servers than %s and %s: %s\n' \
            "$production_sha256" "$instrumented_sha256" "$calibration_receipt/inputs.tsv" >&2
        exit 2
    fi
    calibration_receipt_sha256=$(sha256sum "$calibration_receipt/terminal-state.tsv" | cut -d ' ' -f 1)
fi

# measure-served-decode.sh admits an arm only under the served execution
# contract the scoreboard campaign established: the measured host is
# hp14-dk1xxx, a structurally valid SSH session is inherited, and a proof
# file at the output root, digested into the arm environment, restates the
# surface, host, session, priority, and I/O class beside the census inputs.
host_shortname=$(hostname -s 2>/dev/null | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'the census runs on the measured host hp14-dk1xxx: observed=%s\n' \
        "${host_shortname:--}" >&2
    exit 2
fi
if ! python3 - "${SSH_CONNECTION:-}" <<'PY'
import ipaddress
import sys

fields = sys.argv[1].split()
if len(fields) != 4:
    raise SystemExit(1)
for address in (fields[0], fields[2]):
    ipaddress.ip_address(address)
for port in (fields[1], fields[3]):
    if not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise SystemExit(1)
PY
then
    printf 'the census requires a structurally valid inherited SSH session\n' >&2
    exit 2
fi

mkdir -p "$output_directory/arms"
arms_ledger=$output_directory/arms.tsv
execution_proof=$output_directory/campaign-inputs.tsv
{
    printf 'key\tvalue\n'
    printf 'schema\tfixed64-served-campaign-v2\n'
    printf 'campaign_kind\tpipeline-census\n'
    printf 'execution_surface\thp14-ssh\n'
    printf 'host_shortname\t%s\n' "$host_shortname"
    printf 'ssh_session\tpresent\n'
    printf 'server_nice\t19\n'
    printf 'server_io_class\tidle\n'
    printf 'vulkan_profile\tlow-async\n'
    printf 'model_id\t%s\n' "$model_id"
    printf 'census_mode\t%s\n' "$census_mode"
    printf 'arms\t%s\n' "$arms"
    printf 'production_server\t%s\n' "${production_server:--}"
    printf 'production_server_sha256\t%s\n' "$production_sha256"
    printf 'instrumented_server\t%s\n' "${instrumented_server:--}"
    printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256"
    printf 'generate_tokens\t64\n'
} >"$execution_proof"
execution_proof_sha256=$(sha256sum "$execution_proof" | cut -d ' ' -f 1)
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\n' >"$arms_ledger"
{
    printf 'model_id\t%s\nmodel_path\t%s\ncontext\t%s\nbatch\t%s\nubatch\t%s\n' \
        "$model_id" "$model_path" "$context" "$batch" "$ubatch"
    printf 'cache_k\t%s\ncache_v\t%s\nflash_attention\t%s\nctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' \
        "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
    printf 'arms\t%s\nprofile\tlow-async\nserialized_profile\tdiagnostic\ngenerate\t64\n' "$arms"
    printf 'sidecar_bound\t%s\ncompile_bound\t%s\ncollect_bound\t%s\noverlap_threshold\t%s\n' \
        "$sidecar_bound" "$compile_bound" "$collect_bound" "$overlap_threshold"
    printf 'sidecar_period_ms\t%s\nsidecar_tolerance\t%s\nsidecar_cost_ns\t%s\nsidecar_cpu\t%s\nsidecar_nice\t%s\n' \
        "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_cpu" "$sidecar_nice"
    printf 'sidecar_max_gap_ns\t%s\n' "$sidecar_max_gap_ns"
    printf 'sidecar_drm_device\t%s\nsidecar_allowed_unavailable\t%s\n' \
        "$drm_device" "${sidecar_allowed_unavailable:--}"
    printf 'production_server\t%s\nproduction_server_sha256\t%s\nproduction_server_bytes\t%s\n' \
        "${production_server:--}" "$production_sha256" "$production_bytes"
    printf 'production_artifact_manifest\t%s\nproduction_artifact_manifest_sha256\t%s\n' \
        "$production_manifest" "$production_manifest_sha256"
    printf 'production_checkpoint_semantics\t%s\nproduction_patch_series_sha256\t%s\n' \
        "$production_semantics" "$production_series"
    printf 'production_receipt\t%s\nproduction_receipt_sha256\t%s\n' \
        "${production_receipt:--}" "$production_receipt_sha256"
    printf 'scoreboard_models_resolved_sha256\t%s\nscoreboard_campaign_inputs_sha256\t%s\n' \
        "$scoreboard_models_sha256" "$scoreboard_inputs_sha256"
    printf 'scoreboard_model_registry_sha256\t%s\nmodel_registry_sha256\t%s\n' \
        "$scoreboard_registry_sha256" "$(sha256sum "$script_directory/models.tsv" | cut -d ' ' -f 1)"
    printf 'scoreboard_artifact_ledger_sha256\t%s\n' "$scoreboard_ledger_sha256"
    printf 'census_mode\t%s\ncalibration_receipt\t%s\ncalibration_receipt_sha256\t%s\n' \
        "$census_mode" "${calibration_receipt:--}" "$calibration_receipt_sha256"
    printf 'instrumented_server\t%s\ninstrumented_server_sha256\t%s\ninstrumented_server_bytes\t%s\n' \
        "${instrumented_server:--}" "$instrumented_sha256" "$instrumented_bytes"
    printf 'instrumented_artifact_manifest\t%s\ninstrumented_artifact_manifest_sha256\t%s\n' \
        "$instrumented_manifest" "$instrumented_manifest_sha256"
    printf 'instrumented_checkpoint_semantics\t%s\ninstrumented_patch_series_sha256\t%s\n' \
        "$instrumented_semantics" "$instrumented_series"
    printf 'production_base_build_identity_sha256\t%s\ninstrumented_base_build_identity_sha256\t%s\n' \
        "$production_base_identity_sha256" "$instrumented_base_identity_sha256"
    printf 'instrumented_cmake_delta\t%s\nshader_compiler_identity\t%s\n' \
        "$census_cmake_flag" "$shader_compiler_identity"
    printf 'timestamp_period_ns\t40\ninterval_endpoint_equality\texact_on_this_device\n'
    printf 'model_artifacts\t%s\nmodel_artifacts_sha256\t%s\n' \
        "$artifact_ledger" "$(sha256sum "$artifact_ledger" | cut -d ' ' -f 1)"
    printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output_directory/inputs.tsv"

slot=0
arm_failures=0
for arm in $arms; do
    slot=$((slot + 1))
    arm_label=$(printf '%02d-%s' "$slot" "$arm")
    arm_directory=$output_directory/arms/$arm_label
    profile=low-async
    perf_logger=''
    sidecar_state=on
    case $arm in
        P) server=$production_server ;;
        P-nosidecar) server=$production_server; sidecar_state=off ;;
        S) server=$instrumented_server; profile=diagnostic; perf_logger=1 ;;
        *) server=$instrumented_server ;;
    esac
    census_file=''
    if [ "$arm" = I1 ]; then
        census_file=$arm_directory/pipeline-census.tsv
    fi
    mkdir -p "$arm_directory"
    printf 'census_arm=start slot=%s arm=%s server=%s sidecar=%s\n' "$slot" "$arm" "$server" "$sidecar_state"
    sidecar_pid=''
    if [ "$sidecar_state" = on ]; then
        python3 "$sidecar" "$arm_directory/clock-sidecar.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" --nice "$sidecar_nice" \
            --drm-device "$drm_device" 2>"$arm_directory/clock-sidecar.stderr" &
        sidecar_pid=$!
    fi
    set +e
    env \
        QWEN_LLAMA_SERVER="$server" \
        QWEN_LAUNCH_SCRIPT="$runtime_remote/qwen-launch.sh" \
        QWEN_TEARDOWN_SCRIPT="$runtime_remote/qwen-teardown.sh" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_MODEL_ARTIFACTS="$artifact_ledger" \
        QWEN_RESULT_DIRECTORY="$arm_directory" \
        QWEN_CONTEXT_SIZE="$context" \
        QWEN_BATCH_SIZE="$batch" \
        QWEN_UBATCH_SIZE="$ubatch" \
        QWEN_CACHE_TYPE_K="$cache_k" \
        QWEN_CACHE_TYPE_V="$cache_v" \
        QWEN_FLASH_ATTN="$flash" \
        QWEN_CTX_CHECKPOINTS="$ctx_checkpoints" \
        QWEN_CHECKPOINT_MIN_STEP="$checkpoint_min_step" \
        QWEN_SPEC_TYPE=off \
        QWEN_BACKEND_SAMPLING=0 QWEN_SPEC_BACKEND_SAMPLING=0 \
        QWEN_ROUTER=0 QWEN_INFERENCE_CPU=0 \
        QWEN_BIND_HOST=127.0.0.1 \
        QWEN_LATENCY_MODE=observe QWEN_REQUIRE_API_KEY=0 \
        QWEN_WEB_BROKER=0 QWEN_IMAGE_SERVICE=0 \
        QWEN_VULKAN_LATENCY_PROBE="${QWEN_CENSUS_LATENCY_PROBE:-}" \
        QWEN_PIPELINE_CENSUS="$census_file" \
        QWEN_PERF_LOGGER="$perf_logger" \
        QWEN_EXECUTION_SURFACE=hp14-ssh \
        QWEN_HOST_SHORTNAME="$host_shortname" \
        QWEN_SSH_SESSION=present \
        QWEN_EXECUTION_PROOF="$execution_proof" \
        QWEN_EXECUTION_PROOF_SHA256="$execution_proof_sha256" \
        QWEN_BENCH_GENERATE=64 \
        "$runner" "$arm_label" "$model_path" "$profile" \
        >"$arm_directory/runner.stdout" 2>"$arm_directory/runner.stderr"
    runner_status=$?
    sidecar_status=-
    if [ -n "$sidecar_pid" ]; then
        kill -TERM "$sidecar_pid" 2>/dev/null
        wait "$sidecar_pid"
        sidecar_status=$?
    fi
    set -e
    server_sha256=$(sha256sum "$server" | cut -d ' ' -f 1)
    predicted_n=-
    predicted_ms=-
    tok_s=-
    if [ -r "$arm_directory/response.json" ]; then
        read -r predicted_n predicted_ms tok_s <<EOF
$(python3 - "$arm_directory/response.json" <<'PY'
import json, sys
timings = json.load(open(sys.argv[1])).get("timings", {})
n = timings.get("predicted_n")
ms = timings.get("predicted_ms")
if n is None or ms is None or n < 2 or ms <= 0:
    print("- - -")
else:
    print(n, f"{ms:.3f}", f"{1000.0 * (n - 1) / ms:.3f}")
PY
)
EOF
    fi
    window_begin=''
    window_end=''
    if [ -r "$arm_directory/request-window.tsv" ]; then
        window_begin=$(awk -F'\t' '$1 == "begin_ns" { print $2 }' "$arm_directory/request-window.tsv")
        window_end=$(awk -F'\t' '$1 == "end_ns" { print $2 }' "$arm_directory/request-window.tsv")
    fi
    status=completed
    reason=''
    if [ "$runner_status" -ne 0 ] || [ "$tok_s" = - ]; then
        status=failed
        reason=served_runner
    fi
    # The sidecar record is evidence only where the validator accepts it:
    # exit status, sample count, one footer, the achieved period, the mean
    # cost, every sensor present, and the request window covered.
    if [ "$sidecar_state" = on ]; then
        set +e
        if [ -n "$window_begin" ] && [ -n "$window_end" ]; then
            python3 "$sidecar_validator" "$arm_directory/clock-sidecar.tsv" \
                --sidecar-status "$sidecar_status" --period-ms "$sidecar_period_ms" \
                --period-tolerance "$sidecar_tolerance" --cost-bound-ns "$sidecar_cost_ns" \
                --max-gap-ns "$sidecar_max_gap_ns" \
                --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
                ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
                >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
        else
            python3 "$sidecar_validator" "$arm_directory/clock-sidecar.tsv" \
                --sidecar-status "$sidecar_status" --period-ms "$sidecar_period_ms" \
                --period-tolerance "$sidecar_tolerance" --cost-bound-ns "$sidecar_cost_ns" \
                --max-gap-ns "$sidecar_max_gap_ns" \
                ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
                >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
        fi
        sidecar_verdict=$?
        set -e
        if [ "$sidecar_verdict" -ne 0 ]; then
            sidecar_state=refused
            if [ "$status" = completed ]; then
                status=failed
                reason=clock_sidecar
            fi
        fi
    fi
    census_rows=-
    ownership=-
    if [ -n "$census_file" ]; then
        census_rows=0
        if [ -r "$census_file" ]; then
            census_rows=$(grep -c '^census_dispatch' "$census_file" || true)
        fi
        # The summarizer is the authority on an I1 arm: it selects the graphs
        # by the retained request window, validates every graph inside it,
        # requires predicted_n - 1 decode graphs, and refuses every defect,
        # so its exit status decides the arm.
        if [ "$status" = completed ]; then
            set +e
            python3 "$summarizer" "$census_file" \
                --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
                --expected-decode-graphs "$((predicted_n - 1))" --phase decode \
                --overlap-threshold "$overlap_threshold" \
                >"$arm_directory/pipeline-ledger-decode.tsv" 2>"$arm_directory/summarize.stderr"
            summary_status=$?
            set -e
            if [ "$summary_status" -ne 0 ]; then
                status=failed
                reason=census_summary
                printf 'census_summary=refused slot=%s reason=%s\n' "$slot" \
                    "$(sed -n '1p' "$arm_directory/summarize.stderr")"
            else
                ownership=$(awk -F'\t' '$1 == "graphs" {
                    for (i = 1; i <= NF; i++) if ($i ~ /^ownership=/) { sub(/^ownership=/, "", $i); print $i } }' \
                    "$arm_directory/pipeline-ledger-decode.tsv")
                [ -n "$ownership" ] || ownership=-
                python3 "$summarizer" "$census_file" \
                    --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
                    --expected-decode-graphs "$((predicted_n - 1))" --phase prefill \
                    --overlap-threshold "$overlap_threshold" \
                    >"$arm_directory/pipeline-ledger-prefill.tsv" 2>>"$arm_directory/summarize.stderr" || true
            fi
        fi
    elif [ "$arm" = S ]; then
        # The identity arm's evidence is the server.log slice the served
        # runner cut at the request window; blocks appended outside the
        # window stay out, and the slice must hold at least the decode count.
        census_rows=0
        if [ -r "$arm_directory/server-log-request.slice" ]; then
            census_rows=$(grep -c '^Vulkan Timings:' "$arm_directory/server-log-request.slice" || true)
        fi
        if [ "$status" = completed ]; then
            set +e
            python3 "$slice_summarizer" "$arm_directory/server-log-request.slice" \
                --expected-min-blocks "$((predicted_n - 1))" \
                >"$arm_directory/perf-logger-inventory.tsv" 2>"$arm_directory/perf-logger.stderr"
            slice_status=$?
            set -e
            if [ "$slice_status" -ne 0 ]; then
                status=failed
                reason=perf_logger_slice
            fi
        fi
    fi
    [ "$status" = completed ] || arm_failures=$((arm_failures + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" "$server_sha256" \
        "$predicted_n" "$predicted_ms" "$tok_s" "$census_rows" "$sidecar_state" "$ownership" "$status" >>"$arms_ledger"
    printf 'census_arm=%s slot=%s arm=%s tok_s=%s census_rows=%s sidecar=%s ownership=%s reason=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$census_rows" "$sidecar_state" "$ownership" "${reason:--}"
    sleep "$cooldown_s"
done

# Paired controls, each pair on its own, registered shapes alone; the
# verdict column decides the campaign state, so a refuted control ends the
# run as refuted even where every arm completed. A calibration accepts on
# exactly three accepted controls; an unclassified quadruple in either mode
# is an arm list the parser read as a comparison the registry never bound,
# which fails the run.
python3 "$controls_summarizer" "$arms_ledger" --sidecar-bound "$sidecar_bound" \
    --compile-bound "$compile_bound" --collect-bound "$collect_bound" \
    >"$output_directory/summary.tsv"
control_counts=$(awk -F'\t' 'NR > 1 {
        if ($NF == "refuted") refuted++
        else if ($NF == "incomplete") incomplete++
        else if ($NF == "unclassified") unclassified++
        else if ($NF == "accepted") accepted++
    }
    END { print refuted + 0, incomplete + 0, unclassified + 0, accepted + 0 }' "$output_directory/summary.tsv")
set -- $control_counts
control_refutations=$1
control_incomplete=$2
control_unclassified=$3
control_accepted=$4
required_accepted=0
if [ "$census_mode" = calibration ]; then
    required_accepted=3
fi
if [ "$arm_failures" -ne 0 ] || [ "$control_incomplete" -ne 0 ] \
    || [ "$control_unclassified" -ne 0 ]; then
    campaign=failed
    campaign_exit=1
elif [ "$control_refutations" -ne 0 ]; then
    campaign=refuted
    campaign_exit=3
elif [ "$control_accepted" -lt "$required_accepted" ]; then
    campaign=failed
    campaign_exit=1
else
    campaign=accepted
    campaign_exit=0
fi
printf 'census=%s\ncensus_mode=%s\narm_failures=%s\ncontrol_incomplete=%s\ncontrol_refutations=%s\ncontrol_unclassified=%s\ncontrol_accepted=%s\ncontrol_required=%s\n' \
    "$campaign" "$census_mode" "$arm_failures" "$control_incomplete" "$control_refutations" \
    "$control_unclassified" "$control_accepted" "$required_accepted" >"$output_directory/terminal-state.tsv"
printf 'census=%s mode=%s model=%s arms=%s arm_failures=%s control_incomplete=%s control_refutations=%s control_unclassified=%s control_accepted=%s control_required=%s output=%s\n' \
    "$campaign" "$census_mode" "$model_id" "$slot" "$arm_failures" "$control_incomplete" \
    "$control_refutations" "$control_unclassified" "$control_accepted" "$required_accepted" "$output_directory"
exit "$campaign_exit"
