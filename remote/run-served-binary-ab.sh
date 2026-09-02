#!/bin/sh
set -eu

# Rung 7 of the E4 ladder: two llama-server binaries answering the same
# fixed-64 served request on one checkpoint, arm by arm, and one paired verdict
# over the candidate's rate against the control's. The control is the promoted
# serving build the fixed-64 scoreboard measured its denominator with; the
# candidate is that same base build carrying exactly one candidate patch. The
# ladder's earlier rungs read the compiler -- SPIR-V, ISA, register pressure,
# occupancy -- and a shader that issues fewer instructions still has to move a
# served rate before the tree keeps it.
#
# Arms are mirrored quadruples `C K K C`: two paired deltas per quadruple whose
# second reverses the first's queue position, repeated until the run holds
# QWEN_AB_REPLICATES of them. Warmup arms W open the list on the control server
# with the sampler on, at slots 0a through 0p ahead of slot 1. They absorb the
# cold load -- the first server after a build loads cold and the opening pair
# would otherwise take its outer rate from a cold load and its inner from a
# warm one -- and they carry the regime precondition below. Each is recorded
# and enters no pair.
#
# The precondition runs the warmups until two consecutive arms hold modal
# selected graphics clocks inside QWEN_CENSUS_SCLK_BAND of each other and each
# holds a modal share inside [QWEN_CENSUS_REGIME_MIN_SHARE,
# QWEN_CENSUS_REGIME_MAX_SHARE], then records their mean as regime_sclk_mhz in
# inputs.tsv beside regime_arms and prints census_regime=reached. Two appliance
# calibrations in a row held 1100 MHz over the first nine slots and then settled
# between 762 and 857 MHz for the rest of the campaign, decode falling from
# about 9.5 to about 7.2 tok/s with it, and the served appliance lives in that
# sustained regime; a comparison that crosses into it partway through prices the
# governor beside the binary. The share ceiling is what keeps the precondition
# out of boost: 20260902T1417Z measures the pinned 1100 MHz at a modal share of
# 0.5518 to 0.6803 against the sustained regime's 0.1206 to 0.1615, so two boost
# warmups agree at 1100 on their second arm and only the window declines them.
# QWEN_CENSUS_REGIME_MAX_ARMS caps the spend, and a cap reached prints
# census_regime=unreached and runs the named arms against their own pair
# comparability alone.
#
# QWEN_CENSUS_ENGINE_CLOCK_POLICY retires that precondition by removing what it
# waits for. `manual` writes the graphics level QWEN_CENSUS_SCLK_LEVEL names --
# the highest the table lists where the caller names none -- and, where
# QWEN_CENSUS_MCLK_LEVEL names one, the fabric level beside it; `high` and
# `profile_peak` write those levels instead. Each goes to
# power_dpm_force_performance_level through sudo -n ahead of the first arm, is
# proven by reading the attribute back, and is restored under the cleanup trap
# with a dpm_restore= readback. The campaign then runs one priming warmup,
# which absorbs the cold load alone, and holds every arm to the clock invariant
# validate-clock-sidecar.py states over its request window: the delivered
# graphics frequency at the required step and the fabric clock at or above
# QWEN_CENSUS_MCLK_FLOOR_MHZ, default 933. An arm that misses either fails with
# reason clock_invariant, and summarize-census-controls.py drops its pair as
# clock-violated. `manual` is the measured policy: it decoded 9.58, 8.91, and
# 9.23 tok/s against interleaved `auto` arms at 8.22 and 7.94, where `high` and
# `profile_peak` pinned 1100 MHz and decoded 6.3 to 7.0 by leaving the fabric
# clock at 400 MHz. The nuisance the policy removes is 67% of a decode rate
# where the candidate effect under test is about 4%.
#
# summarize-census-controls.py is the verdict, over the `C K K C` shape it
# registers as `served-ab`. Its bound is one-sided about +QWEN_AB_BOUND,
# because a promotion asks whether the candidate is faster by more than the
# bound and admits no band below it: `promoted` where the whole nominal 95%
# interval sits above the bound, `refuted` where the whole interval sits below
# it, `unresolved` where the interval spans it. A pair whose two modes lie
# further apart than the band measures the governor step rather than the
# binary, so it leaves the mean and the interval, and a control left with fewer
# than two comparable pairs reads `state-changed`. This machine carries about
# 4% of uncontrolled spread on a repeated depth-0 rate, so a 5% bound sits near
# that floor and the mean delta is the quantity a reader takes from a
# refutation.
#
# Both binaries are bound rather than named. The control must be the one
# accepted server row of the fixed-64 scoreboard receipt, whose
# models-resolved.tsv resolves this model to the tuple the registry and ledger
# resolve it to now and whose campaign-inputs.tsv states every setting these
# arms rerun under. Both manifests must yield the same base build identity --
# commit, production patch series, checkpoint patch and source digests,
# compiler flags, CMake flags, and the compiler each executable's .comment
# section names -- so a candidate built at another optimization level, another
# target, or another commit refuses rather than being compared. The candidate
# then differs by exactly one thing: its candidate_series names
# QWEN_AB_CANDIDATE_PATCH alone, where the control's names none. Both are
# serving-shaped, so the candidate manifest names no instrumentation row and
# declares serving_eligible yes; the E4 patch is a shader change with no
# diagnostic surface, and a build carrying one would price the instrument
# instead.
#
# usage: run-served-binary-ab.sh CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIRECTORY
#   QWEN_CENSUS_PRODUCTION_RECEIPT   identity-check.tsv of the fixed-64 scoreboard
#                                    sweep, whose one server row is the control
#   QWEN_AB_REPLICATES               paired deltas, default 4, even, 2 through 8
#   QWEN_AB_BOUND                    one-sided promotion bound, default 0.05
#   QWEN_AB_CANDIDATE_PATCH          the one candidate series member the candidate
#                                    carries, default
#                                    llama-vulkan-q4k-activation-group-sums.patch
#   QWEN_AB_COOLDOWN_S               quiescence deadline between arms, default 30
#   QWEN_CENSUS_ENGINE_CLOCK_POLICY  auto (default), high, profile_peak, or manual; a
#                                    forced policy pins power_dpm_force_performance_level
#                                    for the campaign, runs one priming warmup in place of
#                                    the regime precondition, and holds every arm to the
#                                    clock invariant
#   QWEN_CENSUS_SCLK_LEVEL           graphics level manual selects, default the highest
#                                    level pp_dpm_sclk lists
#   QWEN_CENSUS_MCLK_LEVEL           fabric level manual writes, default `-`, none; the
#                                    write is recorded and its selection is not required
#   QWEN_CENSUS_MCLK_FLOOR_MHZ       fabric floor the clock invariant holds every window
#                                    sample to, default 933
#   QWEN_CENSUS_SCLK_BAND            relative distance within which two selected
#                                    graphics clocks are one regime, default 0.06
#   QWEN_CENSUS_REGIME_MIN_SHARE     modal share floor a warmup window must hold for
#                                    the precondition to read its mode, default 0.05
#   QWEN_CENSUS_REGIME_MAX_SHARE     modal share ceiling above which a window reports a
#                                    pinned clock rather than the hovering sustained
#                                    regime, default 0.30
#   QWEN_CENSUS_REGIME_MAX_ARMS      warmup arms the precondition may spend, 2 through
#                                    16, default 16
#   QWEN_CENSUS_RUNTIME_REMOTE       synced runtime tree the arms launch through,
#                                    default ~/qwen-laptop-setup/remote
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms
#   QWEN_CENSUS_SAMPLER              broker (default) or python
#   QWEN_CENSUS_BROKER               telemetry-broker executable under the broker
#                                    sampler, default ../build/telemetry-broker
#   QWEN_CENSUS_SIDECAR_*            the sampler geometry, period, tolerance, cost,
#                                    gap, lost fraction, and CPU list the census
#                                    calibrated; these arms sample the same way
#   QWEN_AB_PRINT_PLAN               1 prints the arm list and the bindings, then exits

if [ "$#" -ne 4 ]; then
    printf 'usage: %s CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

control_server=$1
candidate_server=$2
model_id=$3
output_directory=$4
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry_reader=$script_directory/model-registry.sh
runner=$script_directory/measure-served-decode.sh
controls_summarizer=$script_directory/summarize-census-controls.py
sidecar=$script_directory/sample-clock-sidecar.py
sidecar_validator=$script_directory/validate-clock-sidecar.py
# The manifest binding, the base-build identity, and the scoreboard receipt
# rule are the census runner's, and both campaigns hold the two binaries to
# them the same way.
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"

# A replicate is one paired delta and a quadruple carries two, so the count is
# even; the summarizer's t table covers 2 through 8.
ab_replicates=${QWEN_AB_REPLICATES:-4}
case $ab_replicates in
    2 | 4 | 6 | 8) ;;
    *)
        printf 'QWEN_AB_REPLICATES is an even count from 2 through 8: %s\n' \
            "$ab_replicates" >&2
        exit 2
        ;;
esac
ab_quadruples=$((ab_replicates / 2))
generate_ab_arms() {
    generated_arms=''
    generated_index=0
    while [ "$generated_index" -lt "$ab_quadruples" ]; do
        generated_arms="$generated_arms C K K C"
        generated_index=$((generated_index + 1))
    done
    printf '%s\n' "${generated_arms# }"
}
arms=$(generate_ab_arms)

ab_bound=${QWEN_AB_BOUND:-0.05}
case $ab_bound in
    '' | . | *[!0-9.]* | *.*.*)
        printf 'QWEN_AB_BOUND is a positive decimal fraction: %s\n' "$ab_bound" >&2
        exit 2
        ;;
esac
# The bound is the promotion rule rather than a tolerance around it, so zero
# would promote any interval whose low end clears zero and turn a paired gain
# of a tenth of a percent into a promotion.
if ! python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > 0 else 1)' "$ab_bound"; then
    printf 'QWEN_AB_BOUND must exceed zero: %s\n' "$ab_bound" >&2
    exit 2
fi
candidate_patch=${QWEN_AB_CANDIDATE_PATCH:-llama-vulkan-q4k-activation-group-sums.patch}
cooldown_s=${QWEN_AB_COOLDOWN_S:-30}
# The band, the share window, and the cap are the census campaign's own, read
# under the same names, since both campaigns face one governor on one machine
# and a rule tightened for either belongs to both.
sclk_band=${QWEN_CENSUS_SCLK_BAND:-0.06}
regime_min_share=${QWEN_CENSUS_REGIME_MIN_SHARE:-0.05}
regime_max_share=${QWEN_CENSUS_REGIME_MAX_SHARE:-0.30}
regime_max_arms=${QWEN_CENSUS_REGIME_MAX_ARMS:-16}
case $regime_max_arms in
    2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16) ;;
    *)
        printf 'QWEN_CENSUS_REGIME_MAX_ARMS is a count from 2 through 16: %s\n' \
            "$regime_max_arms" >&2
        exit 2
        ;;
esac
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-20}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-100}
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))
sidecar_max_lost_fraction=${QWEN_CENSUS_SIDECAR_MAX_LOST:-0.02}
sidecar_cpu=${QWEN_CENSUS_SIDECAR_CPU:-0,1}
# Every measurement process on this machine runs at nice 19, the server
# included, so the sampler takes that priority as an absolute; a hole the
# scheduler opens at it is reported by the gap validator rather than hidden by
# a higher priority.
sidecar_nice=19
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
# The graphics clock is a control under a forced policy and an observed regime
# under `auto`. `high` selects the highest power state and `profile_peak` peak
# clocks with gating disabled; both pin the step every arm decodes at, which
# retires the regime precondition in favour of one priming warmup and the
# per-arm invariant the sidecar validator states. The required step is the
# highest pp_dpm_sclk lists, read here rather than after the write, so the
# value reaches the ledger before the device is touched and the assertion that
# the policy actually selected it stays where the write is.
engine_clock_policy=${QWEN_CENSUS_ENGINE_CLOCK_POLICY:-auto}
case $engine_clock_policy in
    auto | high | profile_peak | manual) ;;
    *)
        printf 'QWEN_CENSUS_ENGINE_CLOCK_POLICY is auto, high, profile_peak, or manual: %s\n' \
            "$engine_clock_policy" >&2
        exit 2
        ;;
esac
engine_clock_sclk_level=-
engine_clock_mclk_level=-
engine_clock_required_sclk_mhz=-
engine_clock_required_mclk_mhz=-
engine_clock_below_required_fraction=-
engine_clock_required_flag=''
engine_clock_mclk_flag=''
if [ "$engine_clock_policy" != auto ]; then
    engine_clock_sclk_path=$drm_device/pp_dpm_sclk
    if [ ! -r "$engine_clock_sclk_path" ]; then
        printf 'a forced engine clock policy reads pp_dpm_sclk: %s\n' \
            "$engine_clock_sclk_path" >&2
        exit 2
    fi
    if [ "$engine_clock_policy" = manual ]; then
        # The level is derived rather than constant: the highest the table
        # lists is the one the appliance measured its manual arms at, and a
        # device listing another count answers for itself.
        engine_clock_sclk_level=${QWEN_CENSUS_SCLK_LEVEL:-}
        if [ -z "$engine_clock_sclk_level" ]; then
            engine_clock_sclk_level=$(census_engine_clock_highest_level \
                "$engine_clock_sclk_path") || {
                printf 'pp_dpm_sclk lists no graphics clock level: %s\n' \
                    "$engine_clock_sclk_path" >&2
                exit 2
            }
        fi
        engine_clock_required_sclk_mhz=$(census_engine_clock_level_mhz \
            "$engine_clock_sclk_path" "$engine_clock_sclk_level") || {
            printf 'pp_dpm_sclk lists no level %s: %s\n' \
                "$engine_clock_sclk_level" "$engine_clock_sclk_path" >&2
            exit 2
        }
        # The fabric level is written where one is named and left alone
        # otherwise, since the appliance measured the write accepted and the
        # starred level unchanged; the floor below is what the invariant holds.
        engine_clock_mclk_level=${QWEN_CENSUS_MCLK_LEVEL:--}
        if [ "$engine_clock_mclk_level" != - ]; then
            engine_clock_mclk_path=$drm_device/pp_dpm_mclk
            if ! census_engine_clock_level_mhz "$engine_clock_mclk_path" \
                "$engine_clock_mclk_level" >/dev/null 2>&1; then
                printf 'pp_dpm_mclk lists no level %s: %s\n' \
                    "$engine_clock_mclk_level" "$engine_clock_mclk_path" >&2
                exit 2
            fi
        fi
    else
        engine_clock_required_sclk_mhz=$(census_engine_clock_highest_mhz \
            "$engine_clock_sclk_path") || {
            printf 'pp_dpm_sclk lists no graphics clock step: %s\n' \
                "$engine_clock_sclk_path" >&2
            exit 2
        }
    fi
    # The fabric floor the invariant holds every window sample to. 933 MHz is
    # where the appliance's own manual arms ran, and the selection that would
    # raise it is accepted by the write and ignored by the firmware.
    engine_clock_required_mclk_mhz=${QWEN_CENSUS_MCLK_FLOOR_MHZ:-933}
    case $engine_clock_required_mclk_mhz in
        '' | *[!0-9]*)
            printf 'QWEN_CENSUS_MCLK_FLOOR_MHZ is a positive megahertz count: %s\n' \
                "$engine_clock_required_mclk_mhz" >&2
            exit 2
            ;;
    esac
    # The admitted share of window samples below the required step is zero: a
    # pinned clock that moved is the nuisance the policy exists to remove.
    engine_clock_below_required_fraction=0
    engine_clock_required_flag=$engine_clock_required_sclk_mhz
    engine_clock_mclk_flag=$engine_clock_required_mclk_mhz
fi
# A forced policy replaces the precondition with one priming warmup, which
# still absorbs the cold load the first server after a build pays. The cap the
# ledger records reads `-` there, since no precondition spent it.
warmup_arm_budget=$regime_max_arms
regime_max_arms_recorded=$regime_max_arms
if [ "$engine_clock_policy" != auto ]; then
    warmup_arm_budget=1
    regime_max_arms_recorded=-
fi
hwmon_root=${QWEN_HWMON_ROOT:-/sys/class/hwmon}
ab_generate=64
production_receipt=${QWEN_CENSUS_PRODUCTION_RECEIPT:-}

# telemetry-broker takes the hwmon directory as an argument where
# sample-clock-sidecar.py resolves it inside itself, so this applies
# find_hwmon's own rule -- the first entry under QWEN_HWMON_ROOT whose name
# attribute reads amdgpu -- once at campaign start and hands the broker what it
# finds.
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
# campaign start is allowed to read unavailable. sysfs reports every attribute
# at one page in stat, so the emptiness is decided by reading the attribute:
# an absent one, an unreadable one, or a read that fails is a different
# telemetry state and refuses the run.
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

# The launch chain runs from the synced runtime tree alone, so the arms launch
# and tear down through that tree while this runner and its readers come from
# wherever the operator checked out.
runtime_remote=${QWEN_CENSUS_RUNTIME_REMOTE:-"${HOME:?}/qwen-laptop-setup/remote"}
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
runtime_tree_manifest=$runtime_remote/../runtime-tree-manifest.tsv
if [ ! -r "$runtime_tree_manifest" ]; then
    printf 'the runtime tree carries no readable runtime-tree-manifest.tsv beside remote/: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 2
fi
runtime_tree_git_head=$(awk -F'\t' '$1 == "git_head" { count++; value = $2 }
    END { if (count != 1) exit 1; print value }' "$runtime_tree_manifest") || {
    printf 'the runtime tree manifest must name git_head exactly once: %s\n' \
        "$runtime_tree_manifest" >&2
    exit 2
}
for reader in "$controls_summarizer" "$sidecar" "$sidecar_validator"; do
    if [ ! -r "$reader" ]; then
        printf 'reader is absent: %s\n' "$reader" >&2
        exit 2
    fi
done

# The sampler is a selection between two programs that emit one record.
# telemetry-broker.c opens every surface once, samples into a preallocated
# ring, and formats the whole record after SIGTERM, where
# sample-clock-sidecar.py opens, parses, and writes inside every sample;
# validate-clock-sidecar.py reads both, so the choice moves the sampler's own
# cost rather than the evidence shape.
ab_sampler=${QWEN_CENSUS_SAMPLER:-broker}
sidecar_binary_sha256=-
sidecar_source_sha256=-
broker=''
case $ab_sampler in
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
                printf 'the telemetry broker is absent and its build failed: %s\n' "$broker" >&2
                exit 2
            fi
        fi
        if [ ! -x "$broker" ]; then
            printf 'the telemetry broker is not executable after its build: %s\n' "$broker" >&2
            exit 2
        fi
        sidecar_binary_sha256=$(sha256sum "$broker" | cut -d ' ' -f 1)
        sidecar_source_sha256=$(sha256sum "$broker_source" | cut -d ' ' -f 1)
        ;;
    python)
        sidecar_implementation=sample-clock-sidecar.py
        ;;
    *)
        printf 'QWEN_CENSUS_SAMPLER must be broker or python: %s\n' "$ab_sampler" >&2
        exit 2
        ;;
esac

if [ -e "$output_directory" ]; then
    printf 'output directory exists and a served comparison never appends to one: %s\n' \
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

# The tuple is the registry's own, read through the same reader the scoreboard
# campaign used. The checkpoint count decides which checkpoint_semantics
# declaration both servers must carry.
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

control_manifest=$(census_manifest_beside "$control_server" control)
set +e
control_binding=$(census_bind_server control "$control_server" "$control_manifest" \
    "$ctx_checkpoints")
binding_status=$?
set -e
[ "$binding_status" -eq 0 ] || exit "$binding_status"
census_require_binding_fields control "$control_binding"
IFS="$(printf '\t')" read -r control_sha256 control_bytes control_manifest_sha256 \
    control_semantics control_series <<EOF
$control_binding
EOF
candidate_manifest=$(census_manifest_beside "$candidate_server" candidate)
set +e
candidate_binding=$(census_bind_server candidate "$candidate_server" "$candidate_manifest" \
    "$ctx_checkpoints")
binding_status=$?
set -e
[ "$binding_status" -eq 0 ] || exit "$binding_status"
census_require_binding_fields candidate "$candidate_binding"
IFS="$(printf '\t')" read -r candidate_sha256 candidate_bytes candidate_manifest_sha256 \
    candidate_semantics candidate_series <<EOF
$candidate_binding
EOF
if [ "$control_sha256" = "$candidate_sha256" ]; then
    printf 'the control and the candidate are one executable: %s\n' "$control_sha256" >&2
    exit 2
fi

# Both roles are serving builds. Cardinality and the exact value are decided
# inside awk over the whole tab-delimited field, so a manifest naming
# eligibility twice is refused rather than read by its first row and a value
# carrying a space is compared as the literal it is.
for eligibility_role in control candidate; do
    case $eligibility_role in
        control) eligibility_manifest=$control_manifest ;;
        *) eligibility_manifest=$candidate_manifest ;;
    esac
    if ! awk -F'\t' '$1 == "instrumentation" { instrumentation++ }
        END { exit instrumentation == 0 ? 0 : 1 }' "$eligibility_manifest"; then
        printf 'the %s manifest names instrumentation; a served comparison runs two serving builds\n' \
            "$eligibility_role" >&2
        exit 2
    fi
    if ! awk -F'\t' '$1 == "serving_eligible" { eligible++; value = $2 }
        END { if (eligible == 0) exit 0; exit (eligible == 1 && value == "yes") ? 0 : 1 }' \
        "$eligibility_manifest"; then
        printf 'the %s manifest declares serving_eligible other than exactly yes in exactly one row or none: %s\n' \
            "$eligibility_role" \
            "$(awk -F'\t' '$1 == "serving_eligible" { printf "[%s] ", $2 }' "$eligibility_manifest")" >&2
        exit 2
    fi
done

# The control is the scoreboard's own server and the denominator is the tuple
# beside it, so a registry edit between the scoreboard and this run refuses
# rather than changing the experiment behind a byte-identical control.
if [ ! -r "$production_receipt" ]; then
    printf 'QWEN_CENSUS_PRODUCTION_RECEIPT must name the readable identity-check.tsv of the scoreboard sweep: %s\n' \
        "${production_receipt:--}" >&2
    exit 2
fi
ledger_sha256=$(awk -F'\t' -v id="$model_id" '$1 == id { print $4 }' "$artifact_ledger")
ledger_bytes=$(awk -F'\t' -v id="$model_id" '$1 == id { print $3 }' "$artifact_ledger")
if [ -z "$ledger_sha256" ] || [ -z "$ledger_bytes" ]; then
    printf 'the model artifact ledger resolves no identity for %s\n' "$model_id" >&2
    exit 2
fi
scoreboard_tuple=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$context" "$batch" "$ubatch" "$cache_k" "$cache_v" "$flash" \
    "$ctx_checkpoints" "$checkpoint_min_step" "$ledger_bytes" "$ledger_sha256")
set +e
scoreboard_digests=$(census_verify_scoreboard_receipt "$production_receipt" \
    "$control_sha256" "$control_bytes" 1 "$model_id" "$scoreboard_tuple")
scoreboard_status=$?
set -e
[ "$scoreboard_status" -eq 0 ] || exit "$scoreboard_status"
IFS="$(printf '\t')" read -r scoreboard_models_sha256 scoreboard_inputs_sha256 <<EOF
$scoreboard_digests
EOF
if [ -z "$scoreboard_models_sha256" ] || [ -z "$scoreboard_inputs_sha256" ]; then
    printf 'the scoreboard receipt binding printed other than two nonempty digests\n' >&2
    exit 2
fi
production_receipt_sha256=$(sha256sum "$production_receipt" | cut -d ' ' -f 1)

# The two servers differ by one candidate patch and that is proven rather than
# named. Each manifest yields a base build identity from the rows both carry,
# and nothing is stripped from either CMake string, since both are the
# serving preset's own flags: a candidate configured at another optimization
# level or another target writes a different file and refuses here.
identity_scratch=$(mktemp -d)
census_base_build_identity "$control_manifest" "$control_server" control \
    "$identity_scratch/control" ''
census_base_build_identity "$candidate_manifest" "$candidate_server" candidate \
    "$identity_scratch/candidate" ''
if ! cmp -s "$identity_scratch/control" "$identity_scratch/candidate"; then
    printf 'the control and candidate servers descend from different base builds:\n' >&2
    diff -- "$identity_scratch/control" "$identity_scratch/candidate" >&2 || true
    rm -r -- "$identity_scratch"
    exit 2
fi
base_build_identity_sha256=$(sha256sum "$identity_scratch/control" | cut -d ' ' -f 1)
rm -r -- "$identity_scratch"
# A promoted production manifest carries no candidate_series row at all, the
# way it carries no instrumentation row, so an absent row is the empty
# selection; a row present is read exactly once, and two rows are refused.
control_candidate_rows=$(awk -F'\t' '$1 == "candidate_series" { count++ } END { print count + 0 }' \
    "$control_manifest")
case $control_candidate_rows in
    0) control_candidate_series=- ;;
    1) control_candidate_series=$(census_manifest_value "$control_manifest" candidate_series control) \
        || exit 2 ;;
    *)
        printf 'the control manifest holds %s candidate_series rows where one or none is admitted\n' \
            "$control_candidate_rows" >&2
        exit 2
        ;;
esac
candidate_candidate_series=$(census_manifest_value "$candidate_manifest" candidate_series candidate) \
    || exit 2
# build-llama-preset.sh writes the selected candidates as a comma-joined list
# and `-` where none was selected, so the control's row is the empty selection
# and the candidate's is exactly one name; a second member leaves a comma in
# the field and is refused here, which is what makes the comparison isolate
# one patch.
if [ "$control_candidate_series" != - ]; then
    printf 'the control manifest must name candidate_series -, the empty selection: %s\n' \
        "$control_candidate_series" >&2
    exit 2
fi
if [ "$candidate_candidate_series" != "$candidate_patch" ]; then
    printf 'the candidate manifest must name candidate_series %s alone: %s\n' \
        "$candidate_patch" "$candidate_candidate_series" >&2
    exit 2
fi
candidate_series_tree=$(census_manifest_value "$candidate_manifest" checkpoint_series_tree candidate) \
    || exit 2
if [ "$candidate_series_tree" != verified-candidate ]; then
    printf 'the candidate manifest must read checkpoint_series_tree verified-candidate: %s\n' \
        "$candidate_series_tree" >&2
    exit 2
fi

latency_probe=${QWEN_CENSUS_LATENCY_PROBE:-}
latency_probe_sha256=-
if [ -n "$latency_probe" ]; then
    if [ ! -r "$latency_probe" ]; then
        printf 'QWEN_CENSUS_LATENCY_PROBE is unreadable: %s\n' "$latency_probe" >&2
        exit 2
    fi
    latency_probe_sha256=$(sha256sum "$latency_probe" | cut -d ' ' -f 1)
fi

if [ "${QWEN_AB_PRINT_PLAN:-0}" = 1 ]; then
    printf 'served_ab_arms\tW %s\n' "$arms"
    printf 'served_ab_replicates\t%s\nserved_ab_bound\t%s\n' "$ab_replicates" "$ab_bound"
    # The plan names one W as the shape the list opens on; the precondition
    # spends between two of them and this cap, which is set by the nine arms
    # boost held for in both retained calibrations.
    printf 'served_ab_warmup_arms\t%s\nserved_ab_sclk_band\t%s\n' \
        "$warmup_arm_budget" "$sclk_band"
    printf 'served_ab_engine_clock_policy\t%s\nserved_ab_engine_clock_sclk_level\t%s\n' \
        "$engine_clock_policy" "$engine_clock_sclk_level"
    printf 'served_ab_engine_clock_required_sclk_mhz\t%s\nserved_ab_engine_clock_required_mclk_mhz\t%s\n' \
        "$engine_clock_required_sclk_mhz" "$engine_clock_required_mclk_mhz"
    printf 'control_server_sha256\t%s\ncandidate_server_sha256\t%s\n' \
        "$control_sha256" "$candidate_sha256"
    printf 'base_build_identity_sha256\t%s\ncandidate_series\t%s\n' \
        "$base_build_identity_sha256" "$candidate_candidate_series"
    exit 0
fi

# measure-served-decode.sh admits an arm only under the served execution
# contract the scoreboard campaign established: the measured host, a
# structurally valid inherited SSH session, and a proof file at the output root
# digested into the arm environment. Both are read here so a run that cannot
# measure refuses before the first launch rather than after it.
host_shortname=$(hostname -s 2>/dev/null | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
if [ "$host_shortname" != hp14-dk1xxx ]; then
    printf 'the served comparison runs on the measured host hp14-dk1xxx: observed=%s\n' \
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
    printf 'the served comparison requires a structurally valid inherited SSH session\n' >&2
    exit 2
fi

# The device transition runs after the host and session checks, so a run that
# could never measure leaves the governor where it found it. The snapshot is
# taken and the restore armed before the write, and the traps below are
# replaced by cleanup_children, which restores the same way.
engine_clock_snapshot=-
engine_clock_sclk_readback=-
engine_clock_mclk_readback=-
if [ "$engine_clock_policy" != auto ]; then
    census_engine_clock_require_sudo
    engine_clock_snapshot=$(census_engine_clock_snapshot "$drm_device") || exit 2
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"' EXIT
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; trap - EXIT; exit 143' TERM
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; trap - EXIT; exit 130' INT
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; trap - EXIT; exit 129' HUP
    census_engine_clock_write_level "$engine_clock_policy" "$drm_device"
    if [ "$engine_clock_policy" = manual ]; then
        # The selection is captured rather than redirected: a refusal inside
        # the function exits this shell, and a redirection still in force when
        # the EXIT trap runs would send the restore's own readback to it.
        engine_clock_sclk_readback=$(census_engine_clock_select pp_dpm_sclk \
            "$drm_device" "$engine_clock_sclk_level" 1) || exit 2
        engine_clock_sclk_readback=${engine_clock_sclk_readback#* }
        if [ "$engine_clock_mclk_level" != - ]; then
            # The fabric selection is recorded rather than required: the
            # appliance took the write and left the starred level where the
            # firmware had it, so the readback is the observation and the floor
            # is the condition.
            engine_clock_mclk_readback=$(census_engine_clock_select pp_dpm_mclk \
                "$drm_device" "$engine_clock_mclk_level" 0) || exit 2
            engine_clock_mclk_readback=${engine_clock_mclk_readback#* }
        fi
    fi
    census_engine_clock_confirm "$drm_device" "$engine_clock_required_sclk_mhz"
    printf 'engine_clock=applied policy=%s sclk_level=%s required_sclk_mhz=%s mclk_level=%s mclk_readback_mhz=%s mclk_floor_mhz=%s snapshot=%s\n' \
        "$engine_clock_policy" "$engine_clock_sclk_level" \
        "$engine_clock_required_sclk_mhz" "$engine_clock_mclk_level" \
        "$engine_clock_mclk_readback" "$engine_clock_required_mclk_mhz" \
        "$engine_clock_snapshot"
fi

campaign_begin_ns=$(date +%s%N)
case $campaign_begin_ns in
    *[!0-9]* | '')
        printf 'date +%%s%%N printed no nanosecond stamp: %s\n' "$campaign_begin_ns" >&2
        exit 2
        ;;
esac

mkdir -p "$output_directory/arms"
arms_ledger=$output_directory/arms.tsv
execution_proof=$output_directory/campaign-inputs.tsv
{
    printf 'key\tvalue\n'
    printf 'schema\tfixed64-served-campaign-v2\n'
    printf 'campaign_kind\tserved-binary-ab\n'
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
    printf 'arms\tW %s\n' "$arms"
    printf 'control_server\t%s\n' "$control_server"
    printf 'control_server_sha256\t%s\n' "$control_sha256"
    printf 'candidate_server\t%s\n' "$candidate_server"
    printf 'candidate_server_sha256\t%s\n' "$candidate_sha256"
    printf 'generate_tokens\t%s\n' "$ab_generate"
} >"$execution_proof"
execution_proof_sha256=$(sha256sum "$execution_proof" | cut -d ' ' -f 1)
# The ledger carries the census's own twelve columns, so summarize-census-controls.py
# reads it unchanged and a reader of one campaign reads the other.
# census_rows and ownership belong to the instrumented arms alone and read `-`
# here; sclk_mode_mhz and sclk_share come off the sidecar validator's own
# clock_state line and are what makes a pair comparable, and regime_delta is
# the named arm's own distance from the regime the warmups settled on.
# clock_invariant and below_required_fraction trail them, carrying the sidecar
# validator's verdict on a forced clock policy; both read `-` under `auto` and
# on an unsampled arm.
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\tsclk_mode_mhz\tsclk_share\tregime_delta\tclock_invariant\tbelow_required_fraction\n' \
    >"$arms_ledger"
{
    printf 'model_id\t%s\nmodel_path\t%s\ncontext\t%s\nbatch\t%s\nubatch\t%s\n' \
        "$model_id" "$model_path" "$context" "$batch" "$ubatch"
    printf 'cache_k\t%s\ncache_v\t%s\nflash_attention\t%s\nctx_checkpoints\t%s\ncheckpoint_min_step\t%s\n' \
        "$cache_k" "$cache_v" "$flash" "$ctx_checkpoints" "$checkpoint_min_step"
    printf 'arms\tW %s\nprofile\tlow-async\ngenerate\t%s\n' "$arms" "$ab_generate"
    printf 'served_ab_replicates\t%s\nserved_ab_bound\t%s\n' "$ab_replicates" "$ab_bound"
    printf 'warmup_arm\tW\nwarmup_sampler\ton\nwarmup_excluded_from_pairs\tyes\n'
    printf 'sclk_band\t%s\nregime_min_share\t%s\nregime_max_share\t%s\n' \
        "$sclk_band" "$regime_min_share" "$regime_max_share"
    printf 'regime_max_arms\t%s\n' "$regime_max_arms_recorded"
    # The clock control and what it is held to. A forced policy states the step
    # every arm must hold and admits no sample below it; `auto` states the
    # governor the regime precondition waits out and leaves both unknown.
    printf 'engine_clock_policy\t%s\nengine_clock_sclk_level\t%s\nengine_clock_mclk_level\t%s\n' \
        "$engine_clock_policy" "$engine_clock_sclk_level" "$engine_clock_mclk_level"
    printf 'engine_clock_required_sclk_mhz\t%s\nengine_clock_required_mclk_mhz\t%s\nclock_below_required_fraction\t%s\n' \
        "$engine_clock_required_sclk_mhz" "$engine_clock_required_mclk_mhz" \
        "$engine_clock_below_required_fraction"
    # The floor names what the fabric requirement is, since the graphics
    # requirement is an equality and the two sit in one contract.
    printf 'mclk_floor_mhz\t%s\nengine_clock_sclk_readback_mhz\t%s\n' \
        "$engine_clock_required_mclk_mhz" "$engine_clock_sclk_readback"
    printf 'engine_clock_mclk_readback_mhz\t%s\nengine_clock_snapshot\t%s\n' \
        "$engine_clock_mclk_readback" "$engine_clock_snapshot"
    printf 'control_server\t%s\ncontrol_server_sha256\t%s\ncontrol_server_bytes\t%s\n' \
        "$control_server" "$control_sha256" "$control_bytes"
    printf 'control_artifact_manifest\t%s\ncontrol_artifact_manifest_sha256\t%s\n' \
        "$control_manifest" "$control_manifest_sha256"
    printf 'control_checkpoint_semantics\t%s\ncontrol_patch_series_sha256\t%s\n' \
        "$control_semantics" "$control_series"
    printf 'candidate_server\t%s\ncandidate_server_sha256\t%s\ncandidate_server_bytes\t%s\n' \
        "$candidate_server" "$candidate_sha256" "$candidate_bytes"
    printf 'candidate_artifact_manifest\t%s\ncandidate_artifact_manifest_sha256\t%s\n' \
        "$candidate_manifest" "$candidate_manifest_sha256"
    printf 'candidate_checkpoint_semantics\t%s\ncandidate_patch_series_sha256\t%s\n' \
        "$candidate_semantics" "$candidate_series"
    printf 'candidate_series\t%s\ncandidate_patch\t%s\n' \
        "$candidate_candidate_series" "$candidate_patch"
    printf 'base_build_identity_sha256\t%s\n' "$base_build_identity_sha256"
    printf 'production_receipt\t%s\nproduction_receipt_sha256\t%s\n' \
        "$production_receipt" "$production_receipt_sha256"
    printf 'scoreboard_models_resolved_sha256\t%s\nscoreboard_campaign_inputs_sha256\t%s\n' \
        "$scoreboard_models_sha256" "$scoreboard_inputs_sha256"
    printf 'model_registry_sha256\t%s\n' \
        "$(sha256sum "$script_directory/models.tsv" | cut -d ' ' -f 1)"
    printf 'model_artifacts\t%s\nmodel_artifacts_sha256\t%s\n' \
        "$artifact_ledger" "$(sha256sum "$artifact_ledger" | cut -d ' ' -f 1)"
    printf 'sidecar_implementation\t%s\nsidecar_binary_sha256\t%s\nsidecar_source_sha256\t%s\n' \
        "$sidecar_implementation" "$sidecar_binary_sha256" "$sidecar_source_sha256"
    printf 'sidecar_period_ms\t%s\nsidecar_tolerance\t%s\nsidecar_cost_ns\t%s\nsidecar_cpu\t%s\nsidecar_nice\t%s\n' \
        "$sidecar_period_ms" "$sidecar_tolerance" "$sidecar_cost_ns" "$sidecar_cpu" "$sidecar_nice"
    printf 'sidecar_max_gap_ns\t%s\nsidecar_max_lost_fraction\t%s\n' \
        "$sidecar_max_gap_ns" "$sidecar_max_lost_fraction"
    printf 'sidecar_drm_device\t%s\nsidecar_allowed_unavailable\t%s\nsidecar_hwmon\t%s\n' \
        "$drm_device" "${sidecar_allowed_unavailable:--}" "${sidecar_hwmon:--}"
    printf 'summarize_census_controls_sha256\t%s\n' \
        "$(sha256sum "$controls_summarizer" | cut -d ' ' -f 1)"
    printf 'runtime_tree_manifest\t%s\nruntime_tree_git_head\t%s\n' \
        "$runtime_tree_manifest" "$runtime_tree_git_head"
    printf 'latency_probe\t%s\nlatency_probe_sha256\t%s\n' \
        "${latency_probe:--}" "$latency_probe_sha256"
    printf 'started_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output_directory/inputs.tsv"

# A terminating signal ends the served runner and the sidecar together: the
# sampler is a background child the normal path kills and waits for after the
# arm, so a runner ended mid-arm would otherwise leave it sampling into the arm
# directory. The pids are cleared after each normal wait so the exit trap acts
# once.
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
    # The forced clock is the campaign's own transition, so it unwinds with the
    # children rather than in a trap of its own; the restore acts once and
    # leaves the exit status where it found it.
    if [ "$engine_clock_policy" != auto ]; then
        census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"
    fi
}
trap cleanup_children EXIT
trap 'cleanup_children; trap - EXIT; exit 143' TERM
trap 'cleanup_children; trap - EXIT; exit 130' INT
trap 'cleanup_children; trap - EXIT; exit 129' HUP

wall_clock_ledger=$output_directory/wall-clock.tsv
printf 'slot\tarm\tphase\tbegin_ns\tend_ns\tnote\n' >"$wall_clock_ledger"

# The warmups take slots 0a through 0p, so the paired arms keep the integer
# slot numbers a quadruple is stated in. The list carries the cap's worth of
# them and the loop stops executing them the instant the regime is reached,
# which is what lets one loop own both phases.
warmup_arms=''
warmup_index=0
while [ "$warmup_index" -lt "$warmup_arm_budget" ]; do
    warmup_arms="$warmup_arms W"
    warmup_index=$((warmup_index + 1))
done
execution_arms="${warmup_arms# } $arms"
named_slot=0
warmup_index=0
regime_previous_mode=-
regime_previous_share=-
regime_sclk_mhz=-
regime_arms=0
regime_reached=0
regime_reported=0
# The regime rows join inputs.tsv the moment the precondition settles, which is
# ahead of the first named arm in either outcome, so a reader of a run
# interrupted mid-campaign still finds what its arms were measured against.
record_regime() {
    printf 'regime_sclk_mhz\t%s\nregime_arms\t%s\n' \
        "$regime_sclk_mhz" "$regime_arms" >>"$output_directory/inputs.tsv"
    if [ "$engine_clock_policy" != auto ]; then
        # A pinned clock is a control the campaign holds rather than a state it
        # waits for, so the taxonomy is retired and the priming warmup is what
        # the line reports.
        printf 'census_regime=retired policy=%s required_sclk_mhz=%s mclk_floor_mhz=%s arms=%s\n' \
            "$engine_clock_policy" "$engine_clock_required_sclk_mhz" \
            "$engine_clock_required_mclk_mhz" "$regime_arms"
    elif [ "$regime_reached" -eq 1 ]; then
        printf 'census_regime=reached sclk_mhz=%s arms=%s\n' \
            "$regime_sclk_mhz" "$regime_arms"
    else
        printf 'census_regime=unreached sclk_mhz=%s arms=%s\n' \
            "$regime_sclk_mhz" "$regime_arms"
    fi
    regime_reported=1
}
arm_failures=0
cooldown_timeouts=0
for arm in $execution_arms; do
    if [ "$arm" = W ]; then
        [ "$regime_reached" -eq 0 ] || continue
        warmup_index=$((warmup_index + 1))
        slot=$(census_warmup_slot "$warmup_index")
        arm_label=$slot-W
    else
        # The precondition ends at the first named arm however it ended, so a
        # capped run states its outcome ahead of the arms it could not bind.
        [ "$regime_reported" -eq 1 ] || record_regime
        named_slot=$((named_slot + 1))
        slot=$named_slot
        arm_label=$(printf '%02d-%s' "$slot" "$arm")
    fi
    arm_begin_ns=$(date +%s%N)
    arm_directory=$output_directory/arms/$arm_label
    sidecar_state=on
    # A warmup's clock state is what the regime precondition reads, so it runs
    # the control server under the sampler the named arms run under.
    case $arm in
        K) server=$candidate_server ;;
        *) server=$control_server ;;
    esac
    mkdir -p "$arm_directory"
    printf 'served_ab_arm=start slot=%s arm=%s server=%s sidecar=%s\n' \
        "$slot" "$arm" "$server" "$sidecar_state"
    sidecar_pid=''
    sidecar_start_failed=0
    if [ "$sidecar_state" = on ] && [ "$ab_sampler" = broker ]; then
        # nice 19 is the broker's own constant, so the launch names the period,
        # the cores, and the surfaces alone.
        # shellcheck disable=SC2086
        "$broker" "$arm_directory/clock-sidecar.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" \
            --drm-device "$drm_device" \
            ${sidecar_hwmon:+--hwmon "$sidecar_hwmon"} \
            2>"$arm_directory/clock-sidecar.stderr" &
        sidecar_pid=$!
        # The record is formatted at drain, so the file proves nothing while
        # the arm runs and readiness is the line the broker prints once every
        # surface is open and the termination handler is installed.
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
            printf 'served_ab_sidecar=start_refused slot=%s arm=%s sampler=%s\n' \
                "$slot" "$arm" "$sidecar_implementation"
        fi
    elif [ "$sidecar_state" = on ]; then
        python3 "$sidecar" "$arm_directory/clock-sidecar.tsv" \
            --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" --nice "$sidecar_nice" \
            --drm-device "$drm_device" 2>"$arm_directory/clock-sidecar.stderr" &
        sidecar_pid=$!
    fi
    # The served runner runs as a background job under wait, which a trap
    # interrupts, so a terminating signal reaches the runner and the sidecar at
    # once rather than after the arm completes. A sampler that never reached
    # readiness leaves the request unrun, so the arm carries its own reason.
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
            QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
            QWEN_EXECUTION_SURFACE=hp14-ssh \
            QWEN_HOST_SHORTNAME="$host_shortname" \
            QWEN_SSH_SESSION=present \
            QWEN_EXECUTION_PROOF="$execution_proof" \
            QWEN_EXECUTION_PROOF_SHA256="$execution_proof_sha256" \
            QWEN_BENCH_GENERATE="$ab_generate" \
            "$runner" "$arm_label" "$model_path" low-async \
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
    # request window into the ledger's wall clock; the offset is read on the arm
    # that produced the window rather than once for the campaign.
    clock_offset_ns=$(python3 -c 'import time; print(time.time_ns() - time.monotonic_ns())')
    # The arm's server is hashed after the arm and compared with the digest the
    # preflight bound to its role, so a binary replaced mid-campaign fails the
    # arm it served rather than being recorded as that role.
    server_sha256=$(sha256sum "$server" | cut -d ' ' -f 1)
    case $arm in
        K) bound_role_sha256=$candidate_sha256 ;;
        *) bound_role_sha256=$control_sha256 ;;
    esac
    server_identity=bound
    if [ "$server_sha256" != "$bound_role_sha256" ]; then
        server_identity=replaced
    fi
    predicted_n=-
    predicted_ms=-
    tok_s=-
    if [ -r "$arm_directory/response.json" ]; then
        # A reply the runner never finished writing is unreadable rather than
        # absent, so the reader's own failure is answered with the unknown
        # triple: the arm fails on its missing rate, and the shell stays in the
        # loop to record that rather than ending the campaign mid-arm.
        arm_timings=$(python3 - "$arm_directory/response.json" <<'ARM_TIMINGS' 2>/dev/null || true
import json, sys
timings = json.load(open(sys.argv[1])).get("timings", {})
n = timings.get("predicted_n")
ms = timings.get("predicted_ms")
if n is None or ms is None or n < 2 or ms <= 0:
    print("- - -")
else:
    print(n, f"{ms:.3f}", f"{1000.0 * (n - 1) / ms:.3f}")
ARM_TIMINGS
)
        read -r predicted_n predicted_ms tok_s <<EOF || true
${arm_timings:-- - -}
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
        printf 'served_ab_arm=server_replaced slot=%s arm=%s bound=%s observed=%s\n' \
            "$slot" "$arm" "$bound_role_sha256" "$server_sha256"
    fi
    if [ "$sidecar_start_failed" -eq 1 ]; then
        status=failed
        reason=sidecar_start
    fi
    # The sidecar record is evidence only where the validator accepts it: exit
    # status, sample count, one footer, the achieved period, the mean cost,
    # every sensor present, and the request window covered.
    sclk_mode_mhz=-
    sclk_share=-
    clock_invariant_state=-
    below_required_fraction=-
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
                ${engine_clock_required_flag:+--required-sclk-mhz "$engine_clock_required_flag"} \
                ${engine_clock_mclk_flag:+--required-mclk-mhz "$engine_clock_mclk_flag"} \
                >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
        else
            python3 "$sidecar_validator" "$arm_directory/clock-sidecar.tsv" \
                --sidecar-status "$sidecar_status" --period-ms "$sidecar_period_ms" \
                --period-tolerance "$sidecar_tolerance" --cost-bound-ns "$sidecar_cost_ns" \
                --max-gap-ns "$sidecar_max_gap_ns" \
                --max-lost-fraction "$sidecar_max_lost_fraction" \
                ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
                ${engine_clock_required_flag:+--required-sclk-mhz "$engine_clock_required_flag"} \
                ${engine_clock_mclk_flag:+--required-mclk-mhz "$engine_clock_mclk_flag"} \
                >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
        fi
        sidecar_verdict=$?
        set -e
        # The invariant line states whether the pinned step held over the
        # request window. It is read ahead of the exit status because a
        # violation names its own repair -- a governor that moved under a
        # policy that states it cannot -- where clock_sidecar names the record.
        clock_invariant_line=$(awk '/^clock_invariant=/ { print; exit }' \
            "$arm_directory/clock-sidecar-verdict.txt")
        if [ -n "$clock_invariant_line" ]; then
            clock_invariant_state=$(printf '%s\n' "$clock_invariant_line" \
                | awk '{ sub(/^clock_invariant=/, "", $1); print $1 }')
            below_required_fraction=$(printf '%s\n' "$clock_invariant_line" \
                | awk '{ for (i = 1; i <= NF; i++) if (index($i, "below_required_fraction=") == 1) print substr($i, 25) }')
        fi
        case $clock_invariant_state in
            held | violated) ;;
            *) clock_invariant_state=- ;;
        esac
        [ -n "$below_required_fraction" ] || below_required_fraction=-
        [ "$clock_invariant_state" != - ] || below_required_fraction=-
        # The validator states the window's own clock state on one line; the
        # ledger carries the modal graphics clock and its share so the
        # summarizer compares the state two arms of a pair ran under.
        clock_state_line=$(awk '/^clock_state=measured / { print; exit }' \
            "$arm_directory/clock-sidecar-verdict.txt")
        if [ -n "$clock_state_line" ]; then
            sclk_mode_mhz=$(printf '%s\n' "$clock_state_line" \
                | awk '{ for (i = 1; i <= NF; i++) if (index($i, "sclk_mode_mhz=") == 1) print substr($i, 15) }')
            sclk_share=$(printf '%s\n' "$clock_state_line" \
                | awk '{ for (i = 1; i <= NF; i++) if (index($i, "sclk_share=") == 1) print substr($i, 12) }')
            [ -n "$sclk_mode_mhz" ] || sclk_mode_mhz=-
            [ -n "$sclk_share" ] || sclk_share=-
        fi
        if [ "$sidecar_verdict" -ne 0 ]; then
            sidecar_state=refused
            # A warmup measures the machine's state rather than the binaries,
            # so a record the validator refuses costs the precondition that
            # arm's reading and leaves the campaign standing; the cap is what
            # bounds a sampler that refuses every warmup.
            if [ "$status" = completed ] && [ "$arm" != W ]; then
                status=failed
                reason=clock_sidecar
                [ "$clock_invariant_state" != violated ] || reason=clock_invariant
            fi
        fi
    fi
    regime_delta=-
    if [ "$arm" = W ]; then
        regime_arms=$warmup_index
        if [ "$engine_clock_policy" != auto ]; then
            # The priming warmup is the whole precondition under a pinned
            # clock: it absorbs the cold load and settles nothing, since the
            # policy rather than a measured mode states the execution state.
            regime_reached=1
        else
            regime_step=$(census_regime_step "$regime_previous_mode" "$regime_previous_share" \
                "$sclk_mode_mhz" "$sclk_share" "$sclk_band" "$regime_min_share" \
                "$regime_max_share")
            case $regime_step in
                reached\ *)
                    regime_reached=1
                    regime_sclk_mhz=${regime_step#reached }
                    ;;
                *)
                    regime_previous_mode=$(printf '%s\n' "$regime_step" | cut -d ' ' -f 2)
                    regime_previous_share=$(printf '%s\n' "$regime_step" | cut -d ' ' -f 3)
                    ;;
            esac
        fi
    else
        regime_delta=$(census_regime_delta "$sclk_mode_mhz" "$regime_sclk_mhz")
    fi
    [ "$status" = completed ] || arm_failures=$((arm_failures + 1))
    analysis_end_ns=$(date +%s%N)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t-\t%s\t-\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" \
        "$server_sha256" "$predicted_n" "$predicted_ms" "$tok_s" "$sidecar_state" "$status" \
        "$sclk_mode_mhz" "$sclk_share" "$regime_delta" "$clock_invariant_state" \
        "$below_required_fraction" >>"$arms_ledger"
    printf 'served_ab_arm=%s slot=%s arm=%s tok_s=%s sidecar=%s sclk_mode_mhz=%s regime_delta=%s clock_invariant=%s reason=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$sidecar_state" "$sclk_mode_mhz" \
        "$regime_delta" "$clock_invariant_state" "${reason:--}"
    cooldown_begin_ns=$(date +%s%N)
    # The boundary between arms is convergence rather than a constant. An arm
    # leaves Vulkan submission, clock boost, thermal drift, and page reclaim
    # behind at different rates, so await-quiescence.sh polls each predicate and
    # reports the instant they have all held together; QWEN_AB_COOLDOWN_S is its
    # deadline. A deadline reached without convergence is recorded on this arm's
    # cooldown row and counted, because the arm that already ran is complete and
    # the state it left belongs to the arm that follows.
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
    printf 'served_ab_cooldown=%s slot=%s arm=%s elapsed_ms=%s status=%s\n' \
        "$quiescence_verdict" "$slot" "$arm" "$quiescence_elapsed_ms" "$quiescence_status"
    # An endpoint the run never observed reads `-` rather than borrowing a
    # neighbouring stamp, so a failed arm reports a missing boundary instead of
    # a mislabeled one.
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
# A run whose named arms all failed to start still states what it opened
# against, so the rows join inputs.tsv whether or not a named arm reported them.
[ "$regime_reported" -eq 1 ] || record_regime

# The three census bounds reach the summarizer because it requires them, and no
# arm here forms a sidecar, compile, or collect quadruple, so they bind nothing.
python3 "$controls_summarizer" "$arms_ledger" \
    --sidecar-bound 0.0065 --compile-bound 0.0065 --collect-bound 0.02 \
    --served-ab-bound "$ab_bound" --sclk-band "$sclk_band" \
    >"$output_directory/summary.tsv"
# Every column is read by name, since a row gains statistics between the
# per-replicate columns and the bound and a positional read would follow the
# wrong field.
served_ab_row=$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["control"]) == "served-ab" { rows++
        printf "%s\t%s\t%s\t%s\t%s\n", $(column["verdict"]), $(column["mean_delta"]),
            $(column["ci_low"]), $(column["ci_high"]), $(column["deltas"]) }
    END { if (rows != 1) exit 1 }' "$output_directory/summary.tsv") || served_ab_row=''
verdict=incomplete
mean_delta=-
ci_low=-
ci_high=-
comparable_pairs=0
if [ -n "$served_ab_row" ]; then
    IFS="$(printf '\t')" read -r verdict mean_delta ci_low ci_high listed_deltas <<EOF
$served_ab_row
EOF
    # A pair whose two arms selected different graphics clocks is listed as
    # state-changed in the deltas column and enters neither the mean nor the
    # interval, so the comparable count is the deltas that carry a number.
    comparable_pairs=$(printf '%s\n' "$listed_deltas" | tr ' ' '\n' \
        | grep -c '^[-+][0-9]' || true)
fi
unclassified=$(awk -F'\t' 'NR == 1 { for (i = 1; i <= NF; i++) column[$i] = i; next }
    $(column["verdict"]) == "unclassified" { count++ }
    END { print count + 0 }' "$output_directory/summary.tsv")

if [ "$arm_failures" -ne 0 ] || [ "$verdict" = incomplete ] || [ "$unclassified" -ne 0 ]; then
    campaign=failed
    campaign_exit=1
elif [ "$verdict" = refuted ]; then
    campaign=refuted
    campaign_exit=3
elif [ "$verdict" = unresolved ] || [ "$verdict" = state-changed ]; then
    # An interval spanning the bound measured neither a gain the bound admits
    # nor its absence, and a control left with fewer than two pairs that held
    # one clock state measured the governor instead. Both resolve nothing and
    # exit 4; the two are reported apart because they name different repairs --
    # more replicates against a fixed governor step for the first, a run whose
    # arms hold one clock state for the second.
    campaign=$verdict
    campaign_exit=4
elif [ "$verdict" = promoted ]; then
    campaign=promoted
    campaign_exit=0
else
    campaign=failed
    campaign_exit=1
fi
printf 'served_ab=%s\nmodel_id=%s\nreplicates=%s\nbound=%s\nmean_delta=%s\nci_low=%s\nci_high=%s\ncomparable_pairs=%s\narm_failures=%s\nunclassified=%s\ncooldown_timeouts=%s\ncontrol_server_sha256=%s\ncandidate_server_sha256=%s\n' \
    "$campaign" "$model_id" "$ab_replicates" "$ab_bound" "$mean_delta" "$ci_low" "$ci_high" \
    "$comparable_pairs" "$arm_failures" "$unclassified" "$cooldown_timeouts" \
    "$control_sha256" "$candidate_sha256" >"$output_directory/terminal-state.tsv"
printf -- '-\t-\tcampaign\t%s\t%s\t-\n' "$campaign_begin_ns" "$(date +%s%N)" >>"$wall_clock_ledger"
printf 'served_ab=%s mean_delta=%s ci=[%s,%s] comparable_pairs=%s replicates=%s bound=%s arm_failures=%s output=%s\n' \
    "$campaign" "$mean_delta" "$ci_low" "$ci_high" "$comparable_pairs" "$ab_replicates" \
    "$ab_bound" "$arm_failures" "$output_directory"
exit "$campaign_exit"
