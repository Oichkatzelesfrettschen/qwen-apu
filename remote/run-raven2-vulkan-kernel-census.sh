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
# arm sequence QWEN_CENSUS_REPLICATES generates and terminates accepted only
# where all three registered controls accept and no quadruple is unclassified,
# so a reordered arm list or a fourth quadruple fails the run rather than
# passing beside the three. An attribution runs any registered arm list, I1
# alone included, and
# requires QWEN_CENSUS_CALIBRATION_RECEIPT to name the output directory of an
# accepted calibration whose production and instrumented servers are the two
# this run binds, since the bounds a calibration accepted belong to those two
# binaries. A canary runs P I0 I1 S once each at eight generated tokens and
# judges the chain's structure rather than any rate. Three quadruple shapes
# carry a registered bound and summarize-census-controls.py assigns a verdict
# to those alone: P-nosidecar P P P-nosidecar measures the sampler's own cost,
# P I0 I0 P the instrument compiled in, and I0 I1 I1 I0 collection under the
# sampler.
#
# A verdict is over every replicate of its control rather than over one pair.
# The appliance calibration of 20260902T0819Z completed all fourteen arms and
# read the sidecar quadruple at -1.20% and +0.96% and the compile quadruple at
# +2.40% and -1.00%: two replicates disagreeing in sign report the arm-to-arm
# scatter this tree measures at about 4% on a repeated depth-0 rate, so a
# 0.65% bound tested against each replicate separately reports queue position.
# The summarizer therefore takes the mean paired delta, its sample standard
# deviation, and a nominal 95% t interval, and a control is accepted where the
# whole interval sits inside its bound, refuted where the whole interval sits
# outside it on one side, and unresolved where the interval spans it.
# QWEN_CENSUS_REPLICATES sets how many paired deltas each control carries:
# every two replicates are one mirrored quadruple, so the count is even and
# runs from 2 to 8, and 2 generates the thirteen arms the retained runs used.
# An unresolved control ends the campaign as unresolved with exit 4, which is
# a reportable result rather than a defect: at four replicates the interval
# half-width is 1.591 standard deviations, so a 0.65% bound accepts only where
# the replicates agree to about 0.4%.
#
# The campaign states its inputs in two contracts, because acquisition and
# analysis fail differently. acquisition-contract.tsv carries every setting
# that changes an observed byte -- the model tuple, both server digests, the
# request shape, the profile, the sidecar geometry, the bounds, the probe, and
# the runtime tree -- and an attribution requires its digest to equal the
# calibration's. analysis-contract.tsv carries the SHA-256 of the four readers
# that interpret the retained records, in fixed order, and a differing analysis
# digest is recorded rather than refused, since a reader fix reinterprets bytes
# a run already acquired. calibration-contract.tsv and
# calibration_contract_sha256 remain as aliases of the acquisition contract and
# its digest for one release, so a receipt written before the split still
# answers the attribution comparison.
#
# A calibration opens on a warmup arm W, the production server under the
# serving profile with the sampler off, at slot 0 ahead of the registered
# thirteen. The first server after a build loads cold: the appliance measured
# slot 1 at 6.783 tok/s against 9.561 at slot 4 and 9.428 to 9.472 across the
# P arms, and the preceding chain read the same opener at 8.166, so the
# sidecar pair would take its first outer rate from a cold load and compare it
# against a warm one. W absorbs that load. Its result is recorded in arms.tsv
# and its rate enters no pair and no census record, the slot numbering leaves
# the registered arms at 1 upward, and QWEN_CENSUS_ARMS still names exactly
# the generated list.
#
# The registered arms are four control bricks -- C0 the sidecar quadruples, C1
# the compile quadruples, C2 the collect quadruples, and C3 the identity arm --
# and each writes bricks/CN.receipt.tsv carrying its slots, verdict, arm rates,
# input-closure digest, and the digest of every artifact it retained.
# calibration-root.tsv hashes the acquisition digest together with the four
# receipt digests, so one value names the whole calibration.
# QWEN_CENSUS_REUSE_BRICKS names a prior calibration output directory whose
# acquisition digest equals this run's: every brick there whose input-closure
# digest equals this run's is reused, its arms are echoed into arms.tsv at
# their own slots with status reused and their recorded rates, and its receipt
# is copied forward carrying reused_from. A calibration whose four bricks all
# reuse runs no arm and still writes a root.
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
# slice holds exactly that many decode blocks once each complete block is
# classified by its token column. A refuted registered control
# ends the campaign as refuted with exit 3; an unresolved control with no
# refutation ends it as unresolved with exit 4; a failed arm ends it as failed
# with exit 1; accepted alone exits 0.
#
# usage: run-raven2-vulkan-kernel-census.sh MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_PRODUCTION_SERVER    path of P (required where an arm names P or P-nosidecar)
#   QWEN_CENSUS_PRODUCTION_RECEIPT   identity-check.tsv of the fixed-64 scoreboard sweep
#                                    (required beside the production server)
#   QWEN_CENSUS_INSTRUMENTED_SERVER  path of I0/I1/S (required where an arm names one)
#   QWEN_CENSUS_MODE                 calibration (default), attribution, or canary
#   QWEN_CENSUS_CALIBRATION_RECEIPT  output directory of an accepted calibration
#                                    (required under attribution)
#   QWEN_CENSUS_ARMS                 space-separated arm names under attribution; a list
#                                    naming more than four quadruples of one registered
#                                    control exceeds the summarizer's t table and refuses;
#                                    a calibration runs exactly the list
#                                    QWEN_CENSUS_REPLICATES generates and a canary
#                                    exactly "P I0 I1 S"
#   QWEN_CENSUS_REPLICATES           paired deltas per control, default 4, even,
#                                    2 through 8; 2 generates
#                                    "P-nosidecar P P P-nosidecar P I0 I0 P I0 I1 I1 I0 S"
#   QWEN_CENSUS_REUSE_BRICKS         output directory of a prior calibration whose
#                                    unchanged bricks this calibration reuses
#   QWEN_CENSUS_COOLDOWN_S           idle seconds between arms, default 30
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms
#   QWEN_CENSUS_RUNTIME_REMOTE       synced runtime tree the arms launch through,
#                                    default ~/qwen-laptop-setup/remote
#   QWEN_CENSUS_SIDECAR_BOUND        admitted |delta| for a P-nosidecar/P pair, default 0.0065
#   QWEN_CENSUS_COMPILE_BOUND        admitted |delta| for a P/I0 pair, default 0.0065
#   QWEN_CENSUS_COLLECT_BOUND        admitted |delta| for an I0/I1 pair, default 0.02
#   QWEN_CENSUS_OVERLAP_THRESHOLD    mean bracket overlap fraction above which the
#                                    I1 ledger reads inconclusive, default 0.05
#   QWEN_CENSUS_SIDECAR_PERIOD_MS    clock sidecar period, default 10
#   QWEN_CENSUS_SIDECAR_TOLERANCE    admitted achieved-period deviation, default 0.25
#   QWEN_CENSUS_SIDECAR_COST_NS      admitted mean sample cost, default 1000000
#   QWEN_CENSUS_SIDECAR_MAX_GAP_MS   adjacent sample gap inside the request window
#                                    that reads as a stall, default 100
#   QWEN_CENSUS_SIDECAR_MAX_LOST     admitted window_lost_fraction, default 0.02
#   QWEN_CENSUS_SIDECAR_CPU          the CPU list the sampler is confined to, default 0,1
#   QWEN_CENSUS_SAMPLER              broker (default) or python, the two programs
#                                    that emit the clock record
#   QWEN_CENSUS_BROKER               telemetry-broker executable under the broker
#                                    sampler, default ../build/telemetry-broker,
#                                    built by build-telemetry-broker.sh when absent
#   QWEN_CENSUS_PRINT_CONTRACT       1 prints the calibration contract and its digest, then exits

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
# A control's replicates are mirrored quadruples: `outer inner inner outer`
# gives two paired deltas whose second reverses the first's queue position, so
# the replicate count is even and each control repeats its own quadruple
# count/2 times. The t table the summarizer carries covers 2 through 8.
census_replicates=${QWEN_CENSUS_REPLICATES:-4}
case $census_replicates in
    2 | 4 | 6 | 8) ;;
    *)
        printf 'QWEN_CENSUS_REPLICATES is an even count from 2 through 8: %s\n' \
            "$census_replicates" >&2
        exit 2
        ;;
esac
census_quadruples=$((census_replicates / 2))
generate_calibration_arms() {
    generated_arms=''
    for generated_control in 'P-nosidecar P P P-nosidecar' 'P I0 I0 P' 'I0 I1 I1 I0'; do
        generated_index=0
        while [ "$generated_index" -lt "$census_quadruples" ]; do
            generated_arms="$generated_arms $generated_control"
            generated_index=$((generated_index + 1))
        done
    done
    printf '%s S\n' "${generated_arms# }"
}
calibration_arms=$(generate_calibration_arms)

# The registered arms partition into four control bricks, and the partition is
# stated once here: one brick per control carrying every quadruple of that
# control in slot order, and the identity arm last. A brick is the unit a
# verdict belongs to and the unit reuse acts on, so the slot list, the arm
# list, and the summary control name travel together, and each follows the
# generated arm list rather than a fixed thirteen.
brick_ids="C0 C1 C2 C3"
# Slots per control brick: two arms per replicate.
brick_width=$((census_replicates * 2))
brick_first_slot() {
    case $1 in
        C0) printf '1\n' ;;
        C1) printf '%s\n' $((brick_width + 1)) ;;
        C2) printf '%s\n' $((2 * brick_width + 1)) ;;
        C3) printf '%s\n' $((3 * brick_width + 1)) ;;
    esac
}
brick_slots() {
    brick_slot_first=$(brick_first_slot "$1")
    if [ "$1" = C3 ]; then
        printf '%s\n' "$brick_slot_first"
        return 0
    fi
    brick_slot_list=''
    brick_slot_index=0
    while [ "$brick_slot_index" -lt "$brick_width" ]; do
        brick_slot_list="$brick_slot_list $((brick_slot_first + brick_slot_index))"
        brick_slot_index=$((brick_slot_index + 1))
    done
    printf '%s\n' "${brick_slot_list# }"
}
brick_arms() {
    case $1 in
        C3) printf 'S\n'; return 0 ;;
        C0) brick_quadruple='P-nosidecar P P P-nosidecar' ;;
        C1) brick_quadruple='P I0 I0 P' ;;
        C2) brick_quadruple='I0 I1 I1 I0' ;;
    esac
    brick_arm_list=''
    brick_arm_index=0
    while [ "$brick_arm_index" -lt "$census_quadruples" ]; do
        brick_arm_list="$brick_arm_list $brick_quadruple"
        brick_arm_index=$((brick_arm_index + 1))
    done
    printf '%s\n' "${brick_arm_list# }"
}
brick_control() {
    case $1 in
        C0) printf 'sidecar\n' ;;
        C1) printf 'compile\n' ;;
        C2) printf 'collect\n' ;;
        C3) printf 'identity\n' ;;
    esac
}
brick_of_slot() {
    if [ "$1" -lt 1 ]; then
        printf -- '-\n'
    elif [ "$1" -le "$brick_width" ]; then
        printf 'C0\n'
    elif [ "$1" -le $((2 * brick_width)) ]; then
        printf 'C1\n'
    elif [ "$1" -le $((3 * brick_width)) ]; then
        printf 'C2\n'
    elif [ "$1" -eq $((3 * brick_width + 1)) ]; then
        printf 'C3\n'
    else
        printf -- '-\n'
    fi
}
canary_arms="P I0 I1 S"
census_mode=${QWEN_CENSUS_MODE:-calibration}
calibration_receipt=${QWEN_CENSUS_CALIBRATION_RECEIPT:-}
reuse_directory=${QWEN_CENSUS_REUSE_BRICKS:-}
# The token count is a campaign input rather than a constant, because the
# canary judges the chain's structure and pays four arms for it. Eight tokens
# leave seven decode graphs, which is what the census summarizer and the
# perf-logger parser are each asked for, so the readers run their real
# cardinality check on a short reply.
census_generate=64
# The scoreboard receipt states the denominator every rate arm reproduces, and
# the canary produces no rate, so its generate_tokens equality is the one
# receipt row a canary leaves out.
require_scoreboard_generate=1
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
    canary)
        arms=${QWEN_CENSUS_ARMS:-$canary_arms}
        if [ "$arms" != "$canary_arms" ]; then
            printf 'a canary runs exactly "%s"; QWEN_CENSUS_ARMS names "%s"\n' \
                "$canary_arms" "$arms" >&2
            exit 2
        fi
        census_generate=8
        require_scoreboard_generate=0
        ;;
    *)
        printf 'QWEN_CENSUS_MODE must be calibration, attribution, or canary: %s\n' "$census_mode" >&2
        exit 2
        ;;
esac
# The bricks are a calibration's own partition of the thirteen arms, so an
# attribution and a canary hold none and reuse has nothing to compare.
if [ -n "$reuse_directory" ] && [ "$census_mode" != calibration ]; then
    printf 'QWEN_CENSUS_REUSE_BRICKS belongs to a calibration; the mode is %s\n' \
        "$census_mode" >&2
    exit 2
fi
# The wall-clock ledger stamps CLOCK_REALTIME through date +%s%N, a GNU
# extension the appliance's coreutils supplies; a date without it prints the
# literal %N and the ledger refuses at its first stamp.
campaign_begin_ns=$(date +%s%N)
case $campaign_begin_ns in
    *[!0-9]* | '')
        printf 'date +%%s%%N printed no nanosecond stamp: %s\n' "$campaign_begin_ns" >&2
        exit 2
        ;;
esac
cooldown_s=${QWEN_CENSUS_COOLDOWN_S:-30}
# The campaign's wall clock is bounded rather than measured ahead of the run:
# the fixed-64 scoreboard arms reach /health in about 9 seconds, answer the
# request in about 9, and tear down in about 1, and await-quiescence.sh takes
# QWEN_CENSUS_COOLDOWN_S as its deadline, so an arm costs at most 19 seconds
# plus that deadline. A calibration opens on W, which pays the same ceiling.
# shellcheck disable=SC2086
predicted_arm_count=$(printf '%s\n' $arms | wc -l | tr -d ' ')
if [ "$census_mode" = calibration ]; then
    predicted_arm_count=$((predicted_arm_count + 1))
fi
predicted_arm_duration_s=$((19 + cooldown_s))
predicted_campaign_duration_s=$((predicted_arm_count * predicted_arm_duration_s))
production_server=${QWEN_CENSUS_PRODUCTION_SERVER:-}
production_receipt=${QWEN_CENSUS_PRODUCTION_RECEIPT:-}
instrumented_server=${QWEN_CENSUS_INSTRUMENTED_SERVER:-}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
sidecar_bound=${QWEN_CENSUS_SIDECAR_BOUND:-0.0065}
compile_bound=${QWEN_CENSUS_COMPILE_BOUND:-0.0065}
collect_bound=${QWEN_CENSUS_COLLECT_BOUND:-0.02}
overlap_threshold=${QWEN_CENSUS_OVERLAP_THRESHOLD:-0.05}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-10}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
# Coverage rather than the widest gap is what a sidecar record owes an arm.
# A nice-19 sampler sharing two cores with a nice-19 server is held off for
# scheduler slices: the appliance measured 3 to 5 gaps over 20 ms per window
# with a 60 to 119 ms maximum and a lost fraction of 0.0122 to 0.0147, and
# the preceding sample cost 0.2 to 1.0 ms at almost every one, so a slow
# sysfs read does not order them. The lost fraction is therefore the
# criterion and the gap bound refuses a stall alone, at ten sampling periods.
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-100}
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))
sidecar_max_lost_fraction=${QWEN_CENSUS_SIDECAR_MAX_LOST:-0.02}
# The guards run on core 1 at nice 0 and the server on core 0 at nice 19,
# so a nice-19 sampler pinned to core 1 loses about 40 ms once a second
# to a guard's sample; confined to both cores it moves to whichever is
# free, and the sidecar control still prices what it takes from the server.
sidecar_cpu=${QWEN_CENSUS_SIDECAR_CPU:-0,1}
# The appliance runs every measurement process at nice 19, the server
# included, so the sampler takes that priority as an absolute rather than
# an option; a hole the scheduler opens at that priority is reported by the
# gap validator rather than hidden by a higher priority.
sidecar_nice=19
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
# telemetry-broker takes the hwmon directory as an argument where
# sample-clock-sidecar.py resolves it inside itself, so the runner applies
# find_hwmon's own rule -- the first entry under QWEN_HWMON_ROOT whose name
# attribute reads amdgpu -- and hands the broker what it finds. A root that
# resolves nothing leaves --hwmon off, which reads temp1_millidegrees
# unavailable on every sample and refuses the record at the validator, so the
# resolution is a campaign-start reading rather than a per-arm one.
hwmon_root=${QWEN_HWMON_ROOT:-/sys/class/hwmon}
sidecar_hwmon=''
for hwmon_entry in "$hwmon_root"/*; do
    [ -d "$hwmon_entry" ] || continue
    [ -r "$hwmon_entry/name" ] || continue
    if [ "$(cat "$hwmon_entry/name")" = amdgpu ]; then
        sidecar_hwmon=$hwmon_entry
        break
    fi
done
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
# The arms launch through the synced runtime tree, so its identity is part
# of what a calibration measured: the manifest the sync writes beside it
# names the git head and the two payload digests, and the contract carries
# all three, so a resync between calibration and attribution refuses the
# attribution rather than launching both through trees that each pass
# their own self-consistency check.
runtime_tree_manifest=$runtime_remote/../runtime-tree-manifest.tsv
if [ ! -r "$runtime_tree_manifest" ]; then
    printf 'the runtime tree carries no readable runtime-tree-manifest.tsv beside remote/: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 2
fi
runtime_tree_identity=$(awk -F'\t' '
    $1 == "git_head" || $1 == "remote_payload_tree_sha256" || $1 == "patches_payload_tree_sha256" { seen[$1] = $2; count++ }
    END { if (count != 3) exit 1
        printf "%s\t%s\t%s\n", seen["git_head"], seen["remote_payload_tree_sha256"], seen["patches_payload_tree_sha256"] }' \
    "$runtime_tree_manifest") || {
    printf 'the runtime tree manifest must name git_head, remote_payload_tree_sha256, and patches_payload_tree_sha256 once each: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 2
}
IFS="$(printf '\t')" read -r runtime_tree_git_head runtime_tree_remote_payload runtime_tree_patches_payload <<RUNTIME_TREE
$runtime_tree_identity
RUNTIME_TREE
for reader in "$summarizer" "$controls_summarizer" "$sidecar" "$sidecar_validator" "$slice_summarizer"; do
    if [ ! -r "$reader" ]; then
        printf 'census reader is absent: %s\n' "$reader" >&2
        exit 2
    fi
done

# The sampler is a selection between two programs that emit one record.
# telemetry-broker.c opens every surface once, samples into a preallocated
# ring, and formats the whole record after SIGTERM, where
# sample-clock-sidecar.py opens, parses, and writes inside every sample;
# validate-clock-sidecar.py reads both, so the choice moves the sampler's own
# cost rather than the evidence shape. The contract carries which one ran
# beside the digests of the broker executable and the source it was built
# from, so a record is attributed to the sampler that produced it.
census_sampler=${QWEN_CENSUS_SAMPLER:-broker}
sidecar_binary_sha256=-
sidecar_source_sha256=-
broker=''
case $census_sampler in
    broker)
        sidecar_implementation=telemetry-broker
        broker_source=$script_directory/telemetry-broker.c
        broker_builder=$script_directory/build-telemetry-broker.sh
        broker=${QWEN_CENSUS_BROKER:-"$script_directory/../build/telemetry-broker"}
        if [ ! -r "$broker_source" ]; then
            printf 'the telemetry broker source is absent: %s\n' "$broker_source" >&2
            exit 2
        fi
        if [ ! -x "$broker" ]; then
            if [ ! -x "$broker_builder" ]; then
                printf 'the telemetry broker is absent and its builder is not executable: %s\n' \
                    "$broker_builder" >&2
                exit 2
            fi
            broker_build_log=$(mktemp)
            if "$broker_builder" "$broker" >"$broker_build_log" 2>&1; then
                rm -f -- "$broker_build_log"
            else
                sed -n '1,20p' "$broker_build_log" >&2
                rm -f -- "$broker_build_log"
                printf 'the telemetry broker is absent and its build failed: %s\n' \
                    "$broker" >&2
                exit 2
            fi
        fi
        if [ ! -x "$broker" ]; then
            printf 'the telemetry broker is not executable after its build: %s\n' \
                "$broker" >&2
            exit 2
        fi
        sidecar_binary_sha256=$(sha256sum "$broker" | cut -d ' ' -f 1)
        sidecar_source_sha256=$(sha256sum "$broker_source" | cut -d ' ' -f 1)
        ;;
    python)
        sidecar_implementation=sample-clock-sidecar.py
        ;;
    *)
        printf 'QWEN_CENSUS_SAMPLER must be broker or python: %s\n' "$census_sampler" >&2
        exit 2
        ;;
esac

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
# An attribution binds both servers whatever its arms run, since its
# contract digest must equal the calibration's and that digest carries
# both binaries.
if [ "$census_mode" = attribution ]; then
    needs_production=1
    needs_instrumented=1
fi

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
    # Every setting the arms run under is stated exactly once with the
    # expected value: a key that repeats, whatever its second value, is a
    # conflicting record rather than a stronger statement, so the count per
    # key is required to be one rather than its presence alone.
    if ! awk -F'\t' -v require_generate="$require_scoreboard_generate" '
        BEGIN {
            expected["vulkan_profile"] = "low-async"
            expected["sampling"] = "temperature=0 top_k=1 seed=1 ignore_eos=true thinking=false"
            expected["server_nice"] = "19"
            expected["inference_cpu"] = "0"
            expected["speculation"] = "off"
            expected["router"] = "0"
            expected["server_io_class"] = "idle"
            expected["backend_sampling"] = "0"
            expected["latency_mode"] = "observe"
            expected["web_broker"] = "0"
            expected["image_service"] = "0"
            if (require_generate == "1") expected["generate_tokens"] = "64"
        }
        ($1 in expected) { count[$1]++; if ($2 != expected[$1]) mismatched++ }
        END {
            for (key in expected) if (count[key] != 1) exit 1
            exit mismatched ? 1 : 0
        }' "$scoreboard_inputs"; then
        printf 'the scoreboard campaign inputs state a profile, token count, sampling, priority, placement, speculation, router, I/O class, backend sampling, latency mode, broker, or image service setting other than the one every arm here runs under, or state one of them more than once: %s\n' \
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
    # Two empty compiler strings compare equal and prove nothing, so an
    # executable whose .comment section names no compiler refuses.
    if [ -z "$identity_compiler" ]; then
        printf 'the %s server carries no compiler identity in its .comment section: %s\n' \
            "$identity_role" "$identity_server" >&2
        exit 2
    fi
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

# The acquisition contract is one canonical file rather than a list of
# field comparisons: every setting under which the three controls were
# accepted, from the model tuple and both server digests through the sidecar
# geometry, the bounds, and the latency probe, in fixed row order. Every row
# of it changes an observed byte. Its digest is recorded by the calibration
# and required equal by every attribution, so a sidecar period or a bound
# changed between the two refuses the attribution by one comparison. The
# probe is bound by digest where one is armed.
latency_probe=${QWEN_CENSUS_LATENCY_PROBE:-}
latency_probe_sha256=-
if [ -n "$latency_probe" ]; then
    if [ ! -r "$latency_probe" ]; then
        printf 'QWEN_CENSUS_LATENCY_PROBE is unreadable: %s\n' "$latency_probe" >&2
        exit 2
    fi
    latency_probe_sha256=$(sha256sum "$latency_probe" | cut -d ' ' -f 1)
fi
write_acquisition_contract() {
    {
        printf 'contract\tpipeline-census-calibration-v1\n'
        printf 'model_id\t%s\nmodel_sha256\t%s\nmodel_bytes\t%s\n' "$model_id" "$ledger_sha256" "$ledger_bytes"
        printf 'context\t%s\nbatch\t%s\nubatch\t%s\ncache_k\t%s\ncache_v\t%s\nflash_attention\t%s\n' \
            "$context" "$batch" "$ubatch" "$cache_k" "$cache_v" "$flash"
        printf 'ctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' "$ctx_checkpoints" "$checkpoint_min_step"
        printf 'production_server_sha256\t%s\ninstrumented_server_sha256\t%s\n' "$production_sha256" "$instrumented_sha256"
        printf 'base_build_identity_sha256\t%s\n' "$production_base_identity_sha256"
        printf 'generate_tokens\t64\nsampling\ttemperature=0 top_k=1 seed=1 ignore_eos=true thinking=false\n'
        printf 'profile\tlow-async\nserialized_profile\tdiagnostic\nserver_nice\t19\nserver_io_class\tidle\n'
        printf 'sidecar_period_ms\t%s\nsidecar_tolerance\t%s\nsidecar_cost_ns\t%s\nsidecar_max_gap_ns\t%s\n' \
            "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_max_gap_ns"
        printf 'sidecar_cpu\t%s\nsidecar_nice\t%s\nsidecar_drm_device\t%s\nsidecar_allowed_unavailable\t%s\n' \
            "$sidecar_cpu" "$sidecar_nice" "$drm_device" "${sidecar_allowed_unavailable:--}"
        printf 'sidecar_max_lost_fraction\t%s\n' "$sidecar_max_lost_fraction"
        printf 'sidecar_implementation\t%s\nsidecar_binary_sha256\t%s\nsidecar_source_sha256\t%s\n' \
            "$sidecar_implementation" "$sidecar_binary_sha256" "$sidecar_source_sha256"
        printf 'sidecar_bound\t%s\ncompile_bound\t%s\ncollect_bound\t%s\noverlap_threshold\t%s\n' \
            "$sidecar_bound" "$compile_bound" "$collect_bound" "$overlap_threshold"
        # The warmup arm runs the production server cold and enters no pair
        # and no census record, so the contract states its exclusion rather
        # than leaving a reader to infer it from the slot numbering.
        printf 'warmup_arm\tW\nwarmup_excluded_from_pairs\tyes\nwarmup_excluded_from_census\tyes\n'
        printf 'latency_probe_sha256\t%s\n' "$latency_probe_sha256"
        printf 'runtime_tree_git_head\t%s\nruntime_tree_remote_payload_sha256\t%s\nruntime_tree_patches_payload_sha256\t%s\n' \
            "$runtime_tree_git_head" "$runtime_tree_remote_payload" "$runtime_tree_patches_payload"
    } >"$1"
}
# The analysis contract names the four readers that interpret the retained
# records, in fixed order, so a reader fix moves this digest and leaves the
# acquisition digest where it stands. A run is bound to the head that
# acquired it, and the analysis digest states which head read it.
write_analysis_contract() {
    {
        printf 'contract\tpipeline-census-analysis-v1\n'
        for analysis_reader in "$summarizer" "$sidecar_validator" "$slice_summarizer" \
            "$controls_summarizer"; do
            printf '%s\t%s\n' "$(basename -- "$analysis_reader")" \
                "$(sha256sum "$analysis_reader" | cut -d ' ' -f 1)"
        done
    } >"$1"
}
contract_scratch=$(mktemp)
write_acquisition_contract "$contract_scratch"
acquisition_contract_sha256=$(sha256sum "$contract_scratch" | cut -d ' ' -f 1)
analysis_scratch=$(mktemp)
write_analysis_contract "$analysis_scratch"
analysis_contract_sha256=$(sha256sum "$analysis_scratch" | cut -d ' ' -f 1)
# calibration_contract_sha256 is the acquisition digest under its former name,
# retained for one release so a receipt written before the split still answers
# the attribution comparison below.
calibration_contract_sha256=$acquisition_contract_sha256
# QWEN_CENSUS_PRINT_CONTRACT=1 prints the contracts this invocation would
# run under and ends ahead of the host check, so an operator or a test reads
# the digest an attribution will be held to without touching the device.
if [ "${QWEN_CENSUS_PRINT_CONTRACT:-0}" = 1 ]; then
    cat -- "$contract_scratch"
    cat -- "$analysis_scratch"
    printf 'acquisition_contract_sha256\t%s\n' "$acquisition_contract_sha256"
    printf 'analysis_contract_sha256\t%s\n' "$analysis_contract_sha256"
    printf 'calibration_contract_sha256\t%s\n' "$calibration_contract_sha256"
    # The arm list, its replicate count, and the predicted wall clock are
    # campaign shape rather than acquisition settings: an attribution runs its
    # own list against the same contract, so these are printed here and
    # recorded in inputs.tsv instead of entering the digest a receipt is held
    # to. The prediction bounds the campaign from the per-arm ceiling the
    # scoreboard measured -- about 9 s of launch to readiness, 9 s of request,
    # and 1 s of teardown -- plus the quiescence deadline QWEN_CENSUS_COOLDOWN_S
    # sets, over every arm the run executes, W included.
    printf 'census_replicates\t%s\ncensus_arms\t%s\ncensus_arm_count\t%s\n' \
        "$census_replicates" "$arms" "$predicted_arm_count"
    printf 'predicted_campaign_duration_s\t%s\npredicted_arm_duration_s\t%s\n' \
        "$predicted_campaign_duration_s" "$predicted_arm_duration_s"
    # The brick partition follows the same replicate count, so the print
    # states which slots each brick owns from the functions the run indexes
    # with rather than from a second recipe.
    if [ "$census_mode" = calibration ]; then
        for print_brick in $brick_ids; do
            printf 'census_brick\t%s\t%s\t%s\t%s\n' "$print_brick" \
                "$(brick_control "$print_brick")" "$(brick_first_slot "$print_brick")" \
                "$(brick_slots "$print_brick" | wc -w | tr -d ' ')"
        done
    fi
    rm -f -- "$contract_scratch" "$analysis_scratch"
    exit 0
fi
receipt_analysis_contract_sha256=-
analysis_contract_match=not_run
if [ "$census_mode" = attribution ]; then
    receipt_contract_sha256=$(awk -F'\t' '$1 == "calibration_contract_sha256" { count++; value = $2 }
        END { if (count != 1) exit 1; print value }' "$calibration_receipt/inputs.tsv") || {
        printf 'the calibration receipt records other than one calibration_contract_sha256: %s\n' \
            "$calibration_receipt/inputs.tsv" >&2
        rm -f -- "$contract_scratch" "$analysis_scratch"
        exit 2
    }
    if [ "$receipt_contract_sha256" != "$acquisition_contract_sha256" ]; then
        printf 'the calibration contract differs from the receipt: this run %s, receipt %s\n' \
            "$acquisition_contract_sha256" "$receipt_contract_sha256" >&2
        if [ -r "$calibration_receipt/acquisition-contract.tsv" ]; then
            diff -- "$calibration_receipt/acquisition-contract.tsv" "$contract_scratch" >&2 || true
        elif [ -r "$calibration_receipt/calibration-contract.tsv" ]; then
            diff -- "$calibration_receipt/calibration-contract.tsv" "$contract_scratch" >&2 || true
        fi
        rm -f -- "$contract_scratch" "$analysis_scratch"
        exit 2
    fi
    # The reader that interprets a record is not the machine that acquired it,
    # so a receipt read by another reader generation is recorded here and
    # launched; a receipt written before the split records no analysis digest
    # and reads unrecorded rather than refusing.
    receipt_analysis_contract_sha256=$(awk -F'\t' '$1 == "analysis_contract_sha256" { count++; value = $2 }
        END { if (count == 1) print value; else print "-" }' "$calibration_receipt/inputs.tsv")
    case $receipt_analysis_contract_sha256 in
        -) analysis_contract_match=unrecorded ;;
        "$analysis_contract_sha256") analysis_contract_match=yes ;;
        *)
            analysis_contract_match=no
            printf 'census_analysis_contract=differs receipt=%s run=%s\n' \
                "$receipt_analysis_contract_sha256" "$analysis_contract_sha256"
            ;;
    esac
fi
rm -f -- "$contract_scratch" "$analysis_scratch"

# The input closure of a brick is what its arms consumed: the acquisition
# contract every arm runs under, the brick's own identity and arm list, and,
# for the two bricks that execute the census build, that binary's digest. It
# is knowable before the arms run, which is what makes it the value reuse
# compares. C3 also retains the diagnostic profile's env set from its own
# server-effective-env.tsv; that set exists only after the arm, so the receipt
# records it beside the closure rather than inside it and a reused C3 carries
# the digest of the env set its original arm actually ran under.
brick_input_closure_sha256() {
    {
        printf 'acquisition_contract_sha256\t%s\n' "$acquisition_contract_sha256"
        printf 'brick\t%s\n' "$1"
        printf 'arms\t%s\n' "$(brick_arms "$1")"
        case $1 in
            C2 | C3) printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256" ;;
        esac
    } | sha256sum | cut -d ' ' -f 1
}
# The slots whose arms this run skips, as a space-delimited list read by the
# arm loop; a slot outside it executes.
reused_slots=' '
reused_bricks=''
reused_brick_count=0
if [ -n "$reuse_directory" ]; then
    for reuse_member in inputs.tsv arms.tsv; do
        if [ ! -r "$reuse_directory/$reuse_member" ]; then
            printf 'the brick reuse directory carries no readable %s: %s\n' \
                "$reuse_member" "$reuse_directory" >&2
            exit 2
        fi
    done
    # A brick is a measurement under one acquisition contract, so a prior run
    # under another contract offers nothing to reuse and the whole directory
    # is refused rather than filtered brick by brick.
    reuse_acquisition_sha256=$(awk -F'\t' '$1 == "acquisition_contract_sha256" { count++; value = $2 }
        $1 == "calibration_contract_sha256" && count == 0 { alias_count++; alias = $2 }
        END { if (count == 1) print value; else if (alias_count == 1) print alias; else print "-" }' \
        "$reuse_directory/inputs.tsv")
    if [ "$reuse_acquisition_sha256" != "$acquisition_contract_sha256" ]; then
        printf 'the brick reuse directory ran under acquisition contract %s and this run runs under %s: %s\n' \
            "$reuse_acquisition_sha256" "$acquisition_contract_sha256" "$reuse_directory" >&2
        exit 2
    fi
    # The echo rewrites one field of a retained row and the pair parser reads
    # that field by name, so the column is resolved from the prior ledger's own
    # header rather than from a position this runner's own printf happens to
    # hold; a ledger naming no status column is refused rather than echoed with
    # a rewritten neighbour.
    reuse_status_column=$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "status") { print i; exit } }' \
        "$reuse_directory/arms.tsv")
    if [ -z "$reuse_status_column" ]; then
        printf 'the brick reuse ledger names no status column: %s\n' \
            "$reuse_directory/arms.tsv" >&2
        exit 2
    fi
    # A brick whose arms completed inside a refuted campaign is a legitimate
    # reuse target -- the arms ran, the closure holds, the rates stand -- so
    # the prior terminal state is carried onto the copied receipt rather than
    # gating the reuse, and a reader of the root sees which campaign each
    # reused brick came out of.
    reuse_census_state=unrecorded
    if [ -r "$reuse_directory/terminal-state.tsv" ]; then
        reuse_census_state=$(awk -F'=' '$1 == "census" { count++; value = $2 }
            END { if (count == 1) print value; else print "unrecorded" }' \
            "$reuse_directory/terminal-state.tsv")
    fi
    for brick_id in $brick_ids; do
        reuse_receipt=$reuse_directory/bricks/$brick_id.receipt.tsv
        [ -r "$reuse_receipt" ] || continue
        reuse_closure=$(awk -F'\t' '$1 == "input_closure_sha256" { count++; value = $2 }
            END { if (count == 1) print value; else print "-" }' "$reuse_receipt")
        [ "$reuse_closure" = "$(brick_input_closure_sha256 "$brick_id")" ] || continue
        # A receipt states rates the echoed ledger rows must carry, so the
        # prior arms.tsv is rejoined to it slot by slot: a directory whose
        # ledger and receipt disagree is not reused rather than reused on
        # whichever of the two is read second.
        reuse_rates=$(awk -F'\t' '$1 == "arm_rates" { count++; value = $2 }
            END { if (count == 1) print value; else print "-" }' "$reuse_receipt")
        reuse_ledger_rates=''
        reuse_rejoined=1
        for reuse_slot in $(brick_slots "$brick_id"); do
            reuse_row=$(awk -F'\t' -v slot="$reuse_slot" '$1 == slot { count++; value = $0 }
                END { if (count == 1) print value }' "$reuse_directory/arms.tsv")
            if [ -z "$reuse_row" ]; then
                reuse_rejoined=0
                break
            fi
            reuse_row_status=$(printf '%s\n' "$reuse_row" | cut -f 10)
            case $reuse_row_status in
                completed | reused) ;;
                *) reuse_rejoined=0; break ;;
            esac
            reuse_ledger_rates="$reuse_ledger_rates $(printf '%s\n' "$reuse_row" | cut -f 6)"
        done
        [ "$reuse_rejoined" = 1 ] || continue
        [ "${reuse_ledger_rates# }" = "$reuse_rates" ] || continue
        reused_bricks="$reused_bricks $brick_id"
        reused_brick_count=$((reused_brick_count + 1))
        for reuse_slot in $(brick_slots "$brick_id"); do
            reused_slots="$reused_slots$reuse_slot "
        done
    done
    reused_bricks=${reused_bricks# }
    printf 'census_brick_reuse=preflight directory=%s bricks=%s\n' \
        "$reuse_directory" "${reused_bricks:--}"
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
    printf 'inference_cpu\t0\nlatency_mode\tobserve\nrouter\t0\nspeculation\toff\n'
    printf 'backend_sampling\t0\nweb_broker\t0\nimage_service\t0\n'
    printf 'runtime_tree_git_head\t%s\n' "$runtime_tree_git_head"
    printf 'model_id\t%s\n' "$model_id"
    printf 'census_mode\t%s\n' "$census_mode"
    printf 'arms\t%s\n' "$arms"
    printf 'production_server\t%s\n' "${production_server:--}"
    printf 'production_server_sha256\t%s\n' "$production_sha256"
    printf 'instrumented_server\t%s\n' "${instrumented_server:--}"
    printf 'instrumented_server_sha256\t%s\n' "$instrumented_sha256"
    printf 'generate_tokens\t%s\n' "$census_generate"
} >"$execution_proof"
execution_proof_sha256=$(sha256sum "$execution_proof" | cut -d ' ' -f 1)
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\n' >"$arms_ledger"
{
    printf 'model_id\t%s\nmodel_path\t%s\ncontext\t%s\nbatch\t%s\nubatch\t%s\n' \
        "$model_id" "$model_path" "$context" "$batch" "$ubatch"
    printf 'cache_k\t%s\ncache_v\t%s\nflash_attention\t%s\nctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' \
        "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
    printf 'arms\t%s\nprofile\tlow-async\nserialized_profile\tdiagnostic\ngenerate\t%s\n' \
        "$arms" "$census_generate"
    printf 'sidecar_bound\t%s\ncompile_bound\t%s\ncollect_bound\t%s\noverlap_threshold\t%s\n' \
        "$sidecar_bound" "$compile_bound" "$collect_bound" "$overlap_threshold"
    printf 'sidecar_period_ms\t%s\nsidecar_tolerance\t%s\nsidecar_cost_ns\t%s\nsidecar_cpu\t%s\nsidecar_nice\t%s\n' \
        "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_cpu" "$sidecar_nice"
    printf 'sidecar_max_gap_ns\t%s\nsidecar_max_lost_fraction\t%s\n' \
        "$sidecar_max_gap_ns" "$sidecar_max_lost_fraction"
    printf 'sidecar_drm_device\t%s\nsidecar_allowed_unavailable\t%s\n' \
        "$drm_device" "${sidecar_allowed_unavailable:--}"
    printf 'sidecar_implementation\t%s\nsidecar_binary_sha256\t%s\nsidecar_source_sha256\t%s\n' \
        "$sidecar_implementation" "$sidecar_binary_sha256" "$sidecar_source_sha256"
    printf 'sidecar_hwmon\t%s\n' "${sidecar_hwmon:--}"
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
    printf 'acquisition_contract_sha256\t%s\nanalysis_contract_sha256\t%s\n' \
        "$acquisition_contract_sha256" "$analysis_contract_sha256"
    printf 'receipt_analysis_contract_sha256\t%s\nanalysis_contract_match\t%s\n' \
        "$receipt_analysis_contract_sha256" "$analysis_contract_match"
    printf 'calibration_contract_sha256\t%s\nlatency_probe\t%s\nlatency_probe_sha256\t%s\n' \
        "$calibration_contract_sha256" "${latency_probe:--}" "$latency_probe_sha256"
    printf 'census_replicates\t%s\ncensus_arms\t%s\ncensus_arm_count\t%s\n' \
        "$census_replicates" "$arms" "$predicted_arm_count"
    printf 'predicted_campaign_duration_s\t%s\npredicted_arm_duration_s\t%s\n' \
        "$predicted_campaign_duration_s" "$predicted_arm_duration_s"
    printf 'brick_reuse_directory\t%s\nreused_bricks\t%s\nreused_brick_count\t%s\n' \
        "${reuse_directory:--}" "${reused_bricks:--}" "$reused_brick_count"
    printf 'runtime_tree_manifest\t%s\nruntime_tree_git_head\t%s\nruntime_tree_remote_payload_sha256\t%s\nruntime_tree_patches_payload_sha256\t%s\n' \
        "$runtime_tree_manifest" "$runtime_tree_git_head" "$runtime_tree_remote_payload" "$runtime_tree_patches_payload"
    printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output_directory/inputs.tsv"

# A terminating signal ends the served runner and the sidecar together:
# the sampler is a background child that the normal path kills and waits
# for after the arm, so a runner ended mid-arm would otherwise leave it
# sampling into the arm directory. The pids are cleared after each normal
# wait so the exit trap acts once.
sidecar_pid=''
served_pid=''
cleanup_children() {
    if [ -n "$served_pid" ]; then
        kill -TERM "$served_pid" 2>/dev/null || true
        wait "$served_pid" 2>/dev/null || true
        served_pid=''
    fi
    if [ -n "$sidecar_pid" ]; then
        kill -TERM "$sidecar_pid" 2>/dev/null || true
        wait "$sidecar_pid" 2>/dev/null || true
        sidecar_pid=''
    fi
}
trap cleanup_children EXIT
trap 'cleanup_children; trap - EXIT; exit 143' TERM
trap 'cleanup_children; trap - EXIT; exit 130' INT
trap 'cleanup_children; trap - EXIT; exit 129' HUP
write_acquisition_contract "$output_directory/acquisition-contract.tsv"
write_analysis_contract "$output_directory/analysis-contract.tsv"
# The alias file carries the acquisition contract under its former name for
# one release, so a reader written against calibration-contract.tsv still
# finds the rows it expects.
cp -- "$output_directory/acquisition-contract.tsv" \
    "$output_directory/calibration-contract.tsv"
# The wall-clock ledger prices the campaign phase by phase on CLOCK_REALTIME.
# The request endpoints come from the served runner's own CLOCK_MONOTONIC
# window, translated through one paired reading of both clocks taken after
# each arm rather than once for the campaign, so a clock step mid-campaign
# moves one arm's translation rather than smearing every later row. The launch
# phase ends at that window's begin, since the launch chain writes launch.txt
# without stamping the instant the server answered /health, and a reused
# brick's arms cost nothing and enter no row.
wall_clock_ledger=$output_directory/wall-clock.tsv
printf 'slot\tarm\tphase\tbegin_ns\tend_ns\tnote\n' >"$wall_clock_ledger"

# W takes slot 0, so the registered thirteen keep the slot numbers every
# brick, receipt, and pair is stated in.
execution_arms=$arms
slot=0
if [ "$census_mode" = calibration ]; then
    execution_arms="W $arms"
    slot=-1
fi
arm_failures=0
cooldown_timeouts=0
canary_structure_failures=0
canary_structure_ledger=$output_directory/canary-structure.tsv
if [ "$census_mode" = canary ]; then
    printf 'slot\tarm\tcheck\tstate\n' >"$canary_structure_ledger"
fi
for arm in $execution_arms; do
    slot=$((slot + 1))
    arm_label=$(printf '%02d-%s' "$slot" "$arm")
    # A warmup warms the arms that follow it, so a calibration whose four
    # bricks all reuse has nothing to warm and runs no server at all.
    if [ "$arm" = W ] && [ "$reused_brick_count" -eq 4 ]; then
        printf 'census_arm=skipped slot=%s arm=W reason=every_brick_reused\n' "$slot"
        continue
    fi
    # A reused brick's arms are echoed at their own slots, so the ledger keeps
    # thirteen rows in campaign order and the pair parser, which walks
    # positions rather than slot numbers, reads the same quadruples it would
    # have read from a run that executed every arm.
    case $reused_slots in
        *" $slot "*)
            reuse_row=$(awk -F'\t' -v slot="$slot" '$1 == slot { print $0 }' \
                "$reuse_directory/arms.tsv")
            printf '%s\n' "$reuse_row" \
                | awk -F'\t' -v OFS='\t' -v column="$reuse_status_column" \
                    '{ $column = "reused"; print }' >>"$arms_ledger"
            printf 'census_arm=reused slot=%s arm=%s brick=%s from=%s\n' \
                "$slot" "$arm" "$(brick_of_slot "$slot")" "$reuse_directory"
            continue
            ;;
    esac
    arm_begin_ns=$(date +%s%N)
    arm_directory=$output_directory/arms/$arm_label
    profile=low-async
    perf_logger=''
    sidecar_state=on
    case $arm in
        P) server=$production_server ;;
        P-nosidecar | W) server=$production_server; sidecar_state=off ;;
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
    sidecar_start_failed=0
    if [ "$sidecar_state" = on ] && [ "$census_sampler" = broker ]; then
        # nice 19 is the broker's own constant, so the launch names the
        # period, the cores, and the surfaces alone.
        # shellcheck disable=SC2086
        "$broker" "$arm_directory/clock-sidecar.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" \
            --drm-device "$drm_device" \
            ${sidecar_hwmon:+--hwmon "$sidecar_hwmon"} \
            2>"$arm_directory/clock-sidecar.stderr" &
        sidecar_pid=$!
        # The record is formatted at drain, so the file proves nothing while
        # the arm runs and readiness is the line the broker prints once every
        # surface is open and the termination handler is installed. The
        # request starts after that line or the arm fails on its absence,
        # since a sampler still opening surfaces measures the wrong span.
        sidecar_ready=0
        sidecar_attempt=0
        while [ "$sidecar_attempt" -lt 100 ]; do
            if grep -q '^telemetry_broker=ready ' \
                "$arm_directory/clock-sidecar.stderr" 2>/dev/null; then
                sidecar_ready=1
                break
            fi
            sidecar_attempt=$((sidecar_attempt + 1))
            sleep 0.05
        done
        if [ "$sidecar_ready" -eq 0 ]; then
            kill -TERM "$sidecar_pid" 2>/dev/null || true
            wait "$sidecar_pid" 2>/dev/null || true
            sidecar_pid=''
            sidecar_state=refused
            sidecar_start_failed=1
            printf 'census_sidecar=start_refused slot=%s arm=%s sampler=%s\n' \
                "$slot" "$arm" "$sidecar_implementation"
        fi
    elif [ "$sidecar_state" = on ]; then
        python3 "$sidecar" "$arm_directory/clock-sidecar.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" --nice "$sidecar_nice" \
            --drm-device "$drm_device" 2>"$arm_directory/clock-sidecar.stderr" &
        sidecar_pid=$!
    fi
    # The served runner runs as a background job under wait, which a trap
    # interrupts, so a terminating signal reaches the runner and the sidecar
    # at once rather than after the arm completes. A sampler that never
    # reached readiness leaves the request unrun, so the arm carries its own
    # reason rather than a served-runner one.
    set +e
    runner_status=1
    if [ "$sidecar_start_failed" -eq 0 ]; then
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
            QWEN_BENCH_GENERATE="$census_generate" \
            "$runner" "$arm_label" "$model_path" "$profile" \
            >"$arm_directory/runner.stdout" 2>"$arm_directory/runner.stderr" &
        served_pid=$!
        wait "$served_pid"
        runner_status=$?
        served_pid=''
    fi
    sidecar_status=-
    if [ -n "$sidecar_pid" ]; then
        kill -TERM "$sidecar_pid" 2>/dev/null
        wait "$sidecar_pid"
        sidecar_status=$?
        sidecar_pid=''
    fi
    set -e
    served_exit_ns=$(date +%s%N)
    # One paired reading of both clocks turns the served runner's monotonic
    # request window into the ledger's wall clock; the offset is read here, on
    # the arm that produced the window, rather than once for the campaign.
    clock_offset_ns=$(python3 -c 'import time; print(time.time_ns() - time.monotonic_ns())')
    # The arm's server is hashed after the arm and compared with the digest
    # the preflight bound to its role, so a binary replaced mid-campaign
    # fails the arm it served rather than being recorded as that role.
    server_sha256=$(sha256sum "$server" | cut -d ' ' -f 1)
    case $arm in
        P | P-nosidecar | W) bound_role_sha256=$production_sha256 ;;
        *) bound_role_sha256=$instrumented_sha256 ;;
    esac
    server_identity=bound
    if [ "$server_sha256" != "$bound_role_sha256" ]; then
        server_identity=replaced
    fi
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
    if [ "$server_identity" != bound ]; then
        status=failed
        reason=server_identity
        printf 'census_arm=server_replaced slot=%s arm=%s bound=%s observed=%s\n' \
            "$slot" "$arm" "$bound_role_sha256" "$server_sha256"
    fi
    # A sampler that announced no readiness is its own reason: the request
    # never ran, so the served-runner verdict above states the consequence
    # where this one states the cause.
    if [ "$sidecar_start_failed" -eq 1 ]; then
        status=failed
        reason=sidecar_start
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
                --max-lost-fraction "$sidecar_max_lost_fraction" \
                --window-begin-ns "$window_begin" --window-end-ns "$window_end" \
                ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
                >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
        else
            python3 "$sidecar_validator" "$arm_directory/clock-sidecar.tsv" \
                --sidecar-status "$sidecar_status" --period-ms "$sidecar_period_ms" \
                --period-tolerance "$sidecar_tolerance" --cost-bound-ns "$sidecar_cost_ns" \
                --max-gap-ns "$sidecar_max_gap_ns" \
                --max-lost-fraction "$sidecar_max_lost_fraction" \
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
                --expected-decode-blocks "$((predicted_n - 1))" \
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
    analysis_end_ns=$(date +%s%N)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" "$server_sha256" \
        "$predicted_n" "$predicted_ms" "$tok_s" "$census_rows" "$sidecar_state" "$ownership" "$status" >>"$arms_ledger"
    printf 'census_arm=%s slot=%s arm=%s tok_s=%s census_rows=%s sidecar=%s ownership=%s reason=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$census_rows" "$sidecar_state" "$ownership" "${reason:--}"
    # A canary judges the chain rather than the rate: the arm completed, which
    # carries the launch, the identity comparison, the sidecar validator, the
    # census summarizer at its own decode count, and the S parser at its own
    # block count; the served runner retained a teardown record; and this
    # runner holds neither child after its waits.
    if [ "$census_mode" = canary ]; then
        canary_arm_state=accepted
        [ "$status" = completed ] || canary_arm_state=failed
        printf '%s\t%s\tarm_completed\t%s\n' "$slot" "$arm" "$canary_arm_state" \
            >>"$canary_structure_ledger"
        [ "$canary_arm_state" = accepted ] || canary_structure_failures=$((canary_structure_failures + 1))
        canary_teardown_state=accepted
        [ -r "$arm_directory/teardown.txt" ] || canary_teardown_state=failed
        printf '%s\t%s\tteardown_record\t%s\n' "$slot" "$arm" "$canary_teardown_state" \
            >>"$canary_structure_ledger"
        [ "$canary_teardown_state" = accepted ] || canary_structure_failures=$((canary_structure_failures + 1))
        canary_orphan_state=accepted
        if [ -n "$served_pid" ] || [ -n "$sidecar_pid" ]; then
            canary_orphan_state=failed
        fi
        printf '%s\t%s\torphan_pid\t%s\n' "$slot" "$arm" "$canary_orphan_state" \
            >>"$canary_structure_ledger"
        [ "$canary_orphan_state" = accepted ] || canary_structure_failures=$((canary_structure_failures + 1))
    fi
    cooldown_begin_ns=$(date +%s%N)
    # The boundary between arms is convergence rather than a constant. An arm
    # leaves Vulkan submission, clock boost, thermal drift, and page reclaim
    # behind at different rates, so await-quiescence.sh polls each predicate
    # and reports the instant they have all held together; QWEN_CENSUS_COOLDOWN_S
    # becomes its deadline. A deadline reached without convergence is recorded
    # on this arm's cooldown row and counted, because the arm that already ran
    # is complete and the state it left belongs to the arm that follows.
    set +e
    quiescence_line=$("$script_directory/await-quiescence.sh" \
        --max-seconds "$cooldown_s" \
        --lease "${QWEN_VULKAN_WORKLOAD_LOCK:-${HOME:?}/qwen-webui-state/vulkan-workload.lock}" \
        2>"$arm_directory/await-quiescence.stderr")
    quiescence_status=$?
    set -e
    cooldown_end_ns=$(date +%s%N)
    quiescence_verdict=$(printf '%s\n' "$quiescence_line" \
        | sed -n 's/^quiescence=\([a-z][a-z]*\).*/\1/p')
    quiescence_elapsed_ms=$(printf '%s\n' "$quiescence_line" \
        | sed -n 's/.*elapsed_ms=\([0-9][0-9]*\).*/\1/p')
    # A poller that printed no parseable line is a third state beside reached
    # and timeout, and it is named rather than folded into either.
    [ -n "$quiescence_verdict" ] || quiescence_verdict=unreported
    [ -n "$quiescence_elapsed_ms" ] || quiescence_elapsed_ms=-
    [ "$quiescence_verdict" = reached ] || cooldown_timeouts=$((cooldown_timeouts + 1))
    printf 'census_cooldown=%s slot=%s arm=%s elapsed_ms=%s status=%s\n' \
        "$quiescence_verdict" "$slot" "$arm" "$quiescence_elapsed_ms" "$quiescence_status"
    # An endpoint the run never observed reads `-` rather than borrowing a
    # neighbouring stamp, so a failed arm reports a missing boundary instead
    # of a mislabeled one.
    request_begin_wall_ns=-
    request_end_wall_ns=-
    if [ -n "$window_begin" ] && [ -n "$window_end" ]; then
        request_begin_wall_ns=$((window_begin + clock_offset_ns))
        request_end_wall_ns=$((window_end + clock_offset_ns))
    fi
    {
        printf '%s\t%s\tlaunch\t%s\t%s\t-\n' "$slot" "$arm" "$arm_begin_ns" "$request_begin_wall_ns"
        printf '%s\t%s\trequest\t%s\t%s\t-\n' "$slot" "$arm" "$request_begin_wall_ns" "$request_end_wall_ns"
        printf '%s\t%s\tteardown\t%s\t%s\t-\n' "$slot" "$arm" "$request_end_wall_ns" "$served_exit_ns"
        printf '%s\t%s\tanalysis\t%s\t%s\t-\n' "$slot" "$arm" "$served_exit_ns" "$analysis_end_ns"
        printf '%s\t%s\tcooldown\t%s\t%s\tquiescence=%s elapsed_ms=%s\n' \
            "$slot" "$arm" "$cooldown_begin_ns" "$cooldown_end_ns" \
            "$quiescence_verdict" "$quiescence_elapsed_ms"
    } >>"$wall_clock_ledger"
done

# Paired controls, one row per registered control over all its replicates;
# the verdict column decides the campaign state, so a refuted control ends
# the run as refuted and an unresolved one ends it as unresolved even where
# every arm completed. A calibration accepts on exactly three accepted
# controls; an unclassified quadruple in either mode is an arm list the parser
# read as a comparison the registry never bound, which fails the run.
calibration_root_sha256=-
if [ "$census_mode" = canary ]; then
    # A canary assigns no control verdict, so the run ends on its structure
    # ledger alone and never reports a refutation.
    if [ "$arm_failures" -eq 0 ] && [ "$canary_structure_failures" -eq 0 ]; then
        campaign=canary_accepted
        campaign_exit=0
    else
        campaign=canary_failed
        campaign_exit=1
    fi
    printf 'census=%s\ncensus_mode=%s\narm_failures=%s\ncontrol_incomplete=-\ncontrol_refutations=-\ncontrol_unresolved=-\ncontrol_unclassified=-\ncontrol_accepted=-\ncontrol_required=-\ncanary_structure_failures=%s\ncooldown_timeouts=%s\ncalibration_root_sha256=%s\n' \
        "$campaign" "$census_mode" "$arm_failures" "$canary_structure_failures" \
        "$cooldown_timeouts" "$calibration_root_sha256" >"$output_directory/terminal-state.tsv"
    printf 'census_wall_clock=campaign begin_ns=%s end_ns=%s\n' \
        "$campaign_begin_ns" "$(date +%s%N)"
    printf -- '-\t-\tcampaign\t%s\t%s\t-\n' "$campaign_begin_ns" "$(date +%s%N)" \
        >>"$wall_clock_ledger"
    printf 'census=%s mode=%s model=%s arms=%s arm_failures=%s canary_structure_failures=%s output=%s\n' \
        "$campaign" "$census_mode" "$model_id" "$slot" "$arm_failures" \
        "$canary_structure_failures" "$output_directory"
    exit "$campaign_exit"
fi

python3 "$controls_summarizer" "$arms_ledger" --sidecar-bound "$sidecar_bound" \
    --compile-bound "$compile_bound" --collect-bound "$collect_bound" \
    >"$output_directory/summary.tsv"
# The verdict is read by column name rather than by position, since a
# refuted pair trails its own detail column and a positional read would count
# that text instead.
control_counts=$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "verdict") column = i; next }
    column {
        if ($column == "refuted") refuted++
        else if ($column == "incomplete") incomplete++
        else if ($column == "unclassified") unclassified++
        else if ($column == "unresolved") unresolved++
        else if ($column == "accepted") accepted++
    }
    END { print refuted + 0, incomplete + 0, unclassified + 0, accepted + 0, unresolved + 0 }' \
    "$output_directory/summary.tsv")
set -- $control_counts
control_refutations=$1
control_incomplete=$2
control_unclassified=$3
control_accepted=$4
control_unresolved=$5
required_accepted=0
if [ "$census_mode" = calibration ]; then
    required_accepted=3
fi

# The four bricks are receipted individually and the root hashes them
# together, so a later calibration compares one value per brick and reuses
# the ones whose inputs are unchanged. A reused brick's receipt is copied
# forward carrying reused_from, since the arms it stands for ran there and
# its artifacts live under that directory.
if [ "$census_mode" = calibration ]; then
    mkdir -p "$output_directory/bricks"
    root_scratch=$output_directory/bricks/.calibration-root.input
    printf 'acquisition_contract_sha256\t%s\n' "$acquisition_contract_sha256" >"$root_scratch"
    for brick_id in $brick_ids; do
        brick_receipt=$output_directory/bricks/$brick_id.receipt.tsv
        case " $reused_bricks " in
            *" $brick_id "*)
                grep -Ev '^reused_from(_census)?	' \
                    "$reuse_directory/bricks/$brick_id.receipt.tsv" >"$brick_receipt"
                printf 'reused_from\t%s\n' "$reuse_directory" >>"$brick_receipt"
                printf 'reused_from_census\t%s\n' "$reuse_census_state" >>"$brick_receipt"
                ;;
            *)
                brick_control_name=$(brick_control "$brick_id")
                brick_rates=''
                brick_verdict=incomplete
                for brick_slot in $(brick_slots "$brick_id"); do
                    brick_row_rate=$(awk -F'\t' -v slot="$brick_slot" '$1 == slot { print $6 }' \
                        "$arms_ledger")
                    brick_rates="$brick_rates ${brick_row_rate:--}"
                done
                brick_rates=${brick_rates# }
                if [ "$brick_id" = C3 ]; then
                    # The identity arm carries no paired bound, so its verdict
                    # is the arm's own state.
                    brick_status=$(awk -F'\t' -v slot="$(brick_slots C3)" '$1 == slot { print $10 }' \
                        "$arms_ledger")
                    case $brick_status in
                        completed | reused) brick_verdict=completed ;;
                        *) brick_verdict=failed ;;
                    esac
                else
                    brick_verdict=$(awk -F'\t' -v control="$brick_control_name" \
                        'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "verdict") column = i; next }
                        column && $2 == control { count++; value = $column }
                        END { if (count == 1) print value; else print "incomplete" }' \
                        "$output_directory/summary.tsv")
                fi
                {
                    printf 'brick_id\t%s\n' "$brick_id"
                    printf 'control\t%s\n' "$brick_control_name"
                    printf 'arm_slots\t%s\n' "$(brick_slots "$brick_id")"
                    printf 'arms\t%s\n' "$(brick_arms "$brick_id")"
                    printf 'verdict\t%s\n' "$brick_verdict"
                    printf 'arm_rates\t%s\n' "$brick_rates"
                    printf 'input_closure_sha256\t%s\n' "$(brick_input_closure_sha256 "$brick_id")"
                    printf 'acquisition_contract_sha256\t%s\n' "$acquisition_contract_sha256"
                    printf 'analysis_contract_sha256\t%s\n' "$analysis_contract_sha256"
                    if [ "$brick_id" = C3 ]; then
                        # The diagnostic profile's env set exists only once the
                        # arm has run, so it is recorded here rather than
                        # folded into the closure the preflight compares.
                        brick_env_file=$output_directory/arms/$(printf '%02d-S' \
                            "$(brick_first_slot C3)")/server-effective-env.tsv
                        brick_env_sha256=-
                        if [ -r "$brick_env_file" ]; then
                            brick_env_sha256=$(sha256sum "$brick_env_file" | cut -d ' ' -f 1)
                        fi
                        printf 'observed_env_set_sha256\t%s\n' "$brick_env_sha256"
                    fi
                    for brick_slot in $(brick_slots "$brick_id"); do
                        brick_arm_directory=$(find "$output_directory/arms" -maxdepth 1 -type d \
                            -name "$(printf '%02d-*' "$brick_slot")" | sort | head -n 1)
                        [ -n "$brick_arm_directory" ] || continue
                        find "$brick_arm_directory" -type f | sort | while read -r brick_artifact; do
                            printf 'artifact\t%s\t%s\n' \
                                "${brick_artifact#"$output_directory"/}" \
                                "$(sha256sum "$brick_artifact" | cut -d ' ' -f 1)"
                        done
                    done
                } >"$brick_receipt"
                ;;
        esac
        printf '%s\t%s\n' "$brick_id" "$(sha256sum "$brick_receipt" | cut -d ' ' -f 1)" \
            >>"$root_scratch"
    done
    calibration_root_sha256=$(sha256sum "$root_scratch" | cut -d ' ' -f 1)
    {
        printf 'calibration_root_sha256\t%s\n' "$calibration_root_sha256"
        printf 'acquisition_contract_sha256\t%s\n' "$acquisition_contract_sha256"
        printf 'analysis_contract_sha256\t%s\n' "$analysis_contract_sha256"
        printf 'reused_bricks\t%s\n' "${reused_bricks:--}"
        awk -F'\t' 'NR > 1 { printf "brick\t%s\t%s\n", $1, $2 }' "$root_scratch"
    } >"$output_directory/calibration-root.tsv"
    rm -f -- "$root_scratch"
fi
if [ "$arm_failures" -ne 0 ] || [ "$control_incomplete" -ne 0 ] \
    || [ "$control_unclassified" -ne 0 ]; then
    campaign=failed
    campaign_exit=1
elif [ "$control_refutations" -ne 0 ]; then
    campaign=refuted
    campaign_exit=3
elif [ "$control_unresolved" -ne 0 ]; then
    # A control whose interval spans its bound measured neither a cost inside
    # the bound nor one beyond it, so the campaign resolves nothing and says
    # so under its own status rather than borrowing accepted or refuted. The
    # branch precedes the accepted-count test, since an unresolved control
    # leaves that count short and would otherwise read as a failure.
    campaign=unresolved
    campaign_exit=4
elif [ "$control_accepted" -lt "$required_accepted" ]; then
    campaign=failed
    campaign_exit=1
else
    campaign=accepted
    campaign_exit=0
fi
printf 'census=%s\ncensus_mode=%s\narm_failures=%s\ncontrol_incomplete=%s\ncontrol_refutations=%s\ncontrol_unresolved=%s\ncontrol_unclassified=%s\ncontrol_accepted=%s\ncontrol_required=%s\ncooldown_timeouts=%s\ncalibration_root_sha256=%s\n' \
    "$campaign" "$census_mode" "$arm_failures" "$control_incomplete" "$control_refutations" \
    "$control_unresolved" "$control_unclassified" "$control_accepted" "$required_accepted" \
    "$cooldown_timeouts" "$calibration_root_sha256" >"$output_directory/terminal-state.tsv"
printf -- '-\t-\tcampaign\t%s\t%s\t-\n' "$campaign_begin_ns" "$(date +%s%N)" >>"$wall_clock_ledger"
printf 'census=%s mode=%s model=%s arms=%s reused_bricks=%s arm_failures=%s control_incomplete=%s control_refutations=%s control_unresolved=%s control_unclassified=%s control_accepted=%s control_required=%s calibration_root=%s output=%s\n' \
    "$campaign" "$census_mode" "$model_id" "$slot" "${reused_bricks:--}" "$arm_failures" \
    "$control_incomplete" "$control_refutations" "$control_unresolved" "$control_unclassified" \
    "$control_accepted" "$required_accepted" "$calibration_root_sha256" "$output_directory"
exit "$campaign_exit"
