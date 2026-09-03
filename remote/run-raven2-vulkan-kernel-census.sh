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
# A pair is taken over one execution state. Two appliance calibrations in a row
# held 1100 MHz over the first nine slots and then settled between 762 and
# 857 MHz for the rest of the campaign, with die temperature falling and decode
# falling from about 9.5 to about 7.2 tok/s with it, so a pair whose two arms
# straddle that fall measures the governor step. The validator states each
# arm's modal selected clock over its request window on a clock_state line,
# arms.tsv carries it as sclk_mode_mhz beside sclk_share, and the summarizer
# judges a control over the pairs whose two modes lie within
# QWEN_CENSUS_SCLK_BAND of each other, relative to the larger. The band rather
# than equality is the rule because the sustained regime hovers across 775,
# 787, 800, 812, 825, 837, and 857 MHz rather than holding a table step: an
# exact comparison read every collect pair of 20260902T1302Z as state-changed
# although all eight arms ran in one regime, and its widest pair sits 3.18%
# apart where 1100 against 800 sits 27.27% apart. A control left with fewer
# than two comparable pairs reads state-changed, which terminal-state.tsv
# counts as control_state_changed and which ends the campaign unresolved with
# exit 4 the way an interval spanning its bound does.
#
# The served appliance lives in the sustained regime, so that regime is the one
# a calibration measures, and the campaign reaches it before its first named
# arm rather than crossing into it partway through. Warmup arms W run the
# production server with the sampler on at slots 0a through 0p, ahead of slot 1
# and outside every pair and census record, until two consecutive warmups hold
# modes inside the band and each holds a modal share inside
# [QWEN_CENSUS_REGIME_MIN_SHARE, QWEN_CENSUS_REGIME_MAX_SHARE]. The share window
# is what separates the regimes rather than the clock alone: 20260902T1417Z
# measures boost pinning 1100 MHz at 0.5518 to 0.6803 and the sustained regime
# hovering at 0.1206 to 0.1615, so two boost warmups agree at 1100 on the second
# arm and a ceiling of 0.30 declines to build the campaign's regime on a pinned
# clock. Their mean is regime_sclk_mhz in inputs.tsv
# beside regime_arms, and the run prints census_regime=reached. The cap
# QWEN_CENSUS_REGIME_MAX_ARMS ends the precondition without one, which prints
# census_regime=unreached and continues with regime_sclk_mhz `-`, since the
# pairs still carry their own comparability. Every named arm records its own
# distance from the regime as regime_delta on the same denominator the band
# uses, and the summarizer counts the arms outside the band per control as
# off_regime_arms: a pair of arms that agree with each other and both sit off
# the regime is comparable and still reports a campaign that drifted.
#
# QWEN_CENSUS_ENGINE_CLOCK_POLICY retires that precondition by removing what it
# waits for. The kernel's power_dpm_force_performance_level takes `high` for the
# highest power state, `profile_peak` for peak clocks with gating disabled, and
# `manual` for the level indices written to pp_dpm_sclk and pp_dpm_mclk, and the
# appliance default `auto` is the governor the regime taxonomy was built around:
# a calibration read 1100 MHz for nine arms, then 750 to 857, then 658 after a
# CPU build, with decode following the clock linearly. `manual` is the measured
# policy, since the delivered graphics clock is not the whole operating point:
# under `high` and `profile_peak` freq1_input read 1100 MHz throughout and
# decode fell to 6.3 to 7.0 tok/s against `auto`'s 6.8 to 8.2, because both
# levels left the starred fabric state at 400 MHz, where `manual` at the highest
# graphics level decoded 9.58, 8.91, and 9.23 against interleaved `auto` arms at
# 8.22 and 7.94. QWEN_CENSUS_SCLK_LEVEL names the graphics level and defaults to
# the highest the table lists; QWEN_CENSUS_MCLK_LEVEL names a fabric level and
# defaults to none, since the write is accepted and the starred level does not
# move, so its readback is recorded rather than required. Every write goes
# through sudo -n ahead of the first arm, is proven by reading the attribute
# back, and is restored under the cleanup trap with a dpm_restore= readback. The
# campaign then runs one priming warmup, which absorbs the cold load alone, and
# holds every arm to the clock invariant validate-clock-sidecar.py states over
# its request window: the delivered graphics frequency at the required step and
# the fabric clock at or above QWEN_CENSUS_MCLK_FLOOR_MHZ, default 933. An arm
# that misses either fails with reason clock_invariant, and
# summarize-census-controls.py drops its pair as clock-violated. The clock
# nuisance is 67% of a decode rate where the effects these controls bound are
# under 2%.
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
# The warmup arms carry a second job beside the regime. The first server after
# a build loads cold: the appliance measured slot 1 at 6.783 tok/s against
# 9.561 at slot 4 and 9.428 to 9.472 across the P arms, and the preceding chain
# read the same opener at 8.166, so the sidecar pair would take its first outer
# rate from a cold load and compare it against a warm one. W absorbs that load
# whether the precondition settles in two arms or eight. Each executed warmup
# gets its own arms.tsv row, its own wall-clock rows, and its own sidecar
# verdict; its rate enters no pair and no census record, the slot lettering
# leaves the registered arms at 1 upward, and QWEN_CENSUS_ARMS still names
# exactly the generated list.
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
# The boundary between two arms is a campaign condition rather than a counter.
# await-quiescence.sh reports `reached` only where its process, GPU occupancy,
# graphics step, step stability, absolute temperature, thermal derivative,
# available memory, swap-in, lease, and latency predicates all held together
# across the hold window, so any other verdict leaves the next arm a machine
# state the arm before it chose. The campaign ends at that boundary, before the
# next arm starts, as `quiescence_unconverged` with exit 5: arms.tsv carries a
# boundary row whose status reads `quiescence_timeout` or
# `quiescence_unreported`, the wall-clock cooldown row and terminal-state.tsv
# name the predicates the poller reported false, and neither the controls
# summary nor a brick receipt nor a calibration root is written, since a root
# over half a campaign is what a later run's brick reuse would copy forward.
#
# The runtime identity is bound once at preflight and re-established by every
# arm. Each arm writes arms/LABEL/runtime-identity.tsv carrying the preflight's
# value and its own reading of the checkpoint's bytes and digest, the served
# binary's bytes and digest, the runtime tree's git head and both payload
# digests beside one check-runtime-tree.sh recompute over its files, the
# artifact ledger digest, the served runner's own digest, and the request body
# the arms send, which the campaign binds from the first arm that sent one. A
# field that moved is an incident rather than one arm's failure -- every later
# arm would measure a different experiment under one receipt -- so the campaign
# ends as `identity_incident` with exit 6, naming the field in terminal_detail
# and printing the expected and observed values on a census_incident line.
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
#   QWEN_CENSUS_COOLDOWN_S           positive deadline in seconds the inter-arm
#                                    quiescence poller runs under, default 30; a
#                                    boundary the poller does not report reached
#                                    inside it ends the campaign
#   QWEN_CENSUS_LATENCY_PROBE        graphics latency probe the runner arms
#   QWEN_CENSUS_RUNTIME_REMOTE       synced runtime tree the arms launch through,
#                                    default ~/qwen-laptop-setup/remote
#   QWEN_CENSUS_SIDECAR_BOUND        admitted |delta| for a P-nosidecar/P pair, default 0.0065
#   QWEN_CENSUS_COMPILE_BOUND        admitted |delta| for a P/I0 pair, default 0.0065
#   QWEN_CENSUS_COLLECT_BOUND        admitted |delta| for an I0/I1 pair, default 0.02
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
#   QWEN_CENSUS_OVERLAP_THRESHOLD    mean bracket overlap fraction above which the
#                                    I1 ledger reads inconclusive, default 0.05
#   QWEN_CENSUS_SIDECAR_PERIOD_MS    clock sidecar period, default 10
#   QWEN_CENSUS_SIDECAR_TOLERANCE    admitted achieved-period deviation, default 0.25
#   QWEN_CENSUS_SIDECAR_COST_NS      admitted mean sample cost, default 1000000
#   QWEN_CENSUS_SIDECAR_MAX_GAP_MS   adjacent sample gap inside the request window
#                                    that reads as a stall, default 100
#   QWEN_CENSUS_SIDECAR_MAX_LOST     admitted window_lost_fraction, default 0.03
#   QWEN_CENSUS_SIDECAR_CPU          the CPU list the sampler is confined to, default 0,1
#   QWEN_CENSUS_SAMPLER              broker (default) or python, the two programs
#                                    that emit the clock record
#   QWEN_CENSUS_BROKER               telemetry-broker executable under the broker
#                                    sampler, default ../build/telemetry-broker,
#                                    built by build-telemetry-broker.sh where it is
#                                    absent or records another source
#   QWEN_CENSUS_MCLK_BELOW_FRACTION  admitted share of window samples below the
#                                    fabric floor under a forced policy, default 0.01
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
# The manifest binding, the base-build identity, and the scoreboard receipt
# rule are shared with run-served-binary-ab.sh, which binds two serving builds
# the way this runner binds P against I.
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"
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
    # A warmup slot is lettered rather than numbered, so it is answered ahead
    # of the arithmetic comparisons that would abort on it.
    case $1 in
        *[!0-9]*) printf -- '-\n'; return 0 ;;
    esac
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
        # An attribution names its own arms, so the list is normalized before
        # it is read: whitespace alone is a supplied value the arm loop
        # iterates zero times over, which leaves the controls summarizer a
        # header, the terminal decision zero accepted controls to require, and
        # a receipt no measurement stands behind.
        arms=$(printf '%s\n' "${QWEN_CENSUS_ARMS:-I1}" \
            | tr '\t' ' ' | tr -s ' ' | sed 's/^ //; s/ $//')
        if [ -z "$arms" ]; then
            printf 'an attribution names at least one arm; QWEN_CENSUS_ARMS is empty\n' >&2
            exit 2
        fi
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
# The deadline decides the campaign, so it is held to await-quiescence.sh's own
# rule here rather than reaching the poller as a usage error. A zero or
# non-numeric deadline exits that poller 2 with no verdict line, which the arm
# loop reads as `unreported` and ends the campaign on: a caller's typo would
# otherwise terminate the run under a state name that describes the machine.
case $cooldown_s in
    '' | *[!0-9]*)
        printf 'QWEN_CENSUS_COOLDOWN_S is a positive second count: %s\n' \
            "$cooldown_s" >&2
        exit 2
        ;;
esac
if [ "$cooldown_s" -le 0 ]; then
    printf 'QWEN_CENSUS_COOLDOWN_S is a positive second count: %s\n' \
        "$cooldown_s" >&2
    exit 2
fi
production_server=${QWEN_CENSUS_PRODUCTION_SERVER:-}
production_receipt=${QWEN_CENSUS_PRODUCTION_RECEIPT:-}
instrumented_server=${QWEN_CENSUS_INSTRUMENTED_SERVER:-}
models_directory=${QWEN_MODELS_DIRECTORY:-"${HOME:?}/models"}
sidecar_bound=${QWEN_CENSUS_SIDECAR_BOUND:-0.0065}
compile_bound=${QWEN_CENSUS_COMPILE_BOUND:-0.0065}
collect_bound=${QWEN_CENSUS_COLLECT_BOUND:-0.02}
# Each bound is the falsifier its control is judged against, and
# summarize-census-controls.py takes it through argparse's float, which reads
# `inf` and `nan` as numbers no interval lies outside of. A canonical
# nonnegative decimal is what a control can be refuted against, so the value is
# held to that shape here, ahead of the contract that records it.
for census_control_bound in "$sidecar_bound" "$compile_bound" "$collect_bound"; do
    case $census_control_bound in
        '' | . | *[!0-9.]* | *.*.*)
            printf 'a census control bound is a nonnegative decimal: %s\n' \
                "$census_control_bound" >&2
            exit 2
            ;;
    esac
done
# Two selected graphics clocks are one execution state where they lie within
# this relative band of each other. The appliance's sustained regime hovers
# across 775 to 857 MHz, whose widest pair sits 3.18% apart, and its boost
# regime's 1100 MHz sits 27.27% above 800, so 0.06 holds one regime together
# and keeps the two apart.
sclk_band=${QWEN_CENSUS_SCLK_BAND:-0.06}
# The band is a relative distance over the larger of two clocks, so a value at
# or above one holds every pair of clocks in one state and states nothing, and
# `inf` reaches census_regime_step and summarize-census-controls.py as a float
# no pair lies outside of. Both are refused here, ahead of the contract that
# records the band and the precondition that reads it.
case $sclk_band in
    '' | . | *[!0-9.]* | *.*.*)
        printf 'QWEN_CENSUS_SCLK_BAND is a nonnegative decimal: %s\n' "$sclk_band" >&2
        exit 2
        ;;
esac
if ! awk -v band="$sclk_band" 'BEGIN { exit (band + 0 < 1) ? 0 : 1 }'; then
    printf 'QWEN_CENSUS_SCLK_BAND is a relative distance in [0, 1): %s\n' "$sclk_band" >&2
    exit 2
fi
# The regime precondition's own three settings. The modal share separates the
# two regimes this device runs in as sharply as the clock does: 20260902T1417Z
# measures the boost regime pinning 1100 MHz at a modal share of 0.5518 to
# 0.6803 and the sustained regime hovering across seven values at 0.1206 to
# 0.1615, so a share above the ceiling reports the pinned boost clock and
# hovering is the signature the window admits. The floor is a sanity bound
# under a window whose samples name no mode at all.
regime_min_share=${QWEN_CENSUS_REGIME_MIN_SHARE:-0.05}
regime_max_share=${QWEN_CENSUS_REGIME_MAX_SHARE:-0.30}
# Boost held for about nine arms in both retained calibrations and a warmup
# costs about 23 s with the converged cooldown, so the cap admits the fall and
# the pair that has to follow it.
regime_max_arms=${QWEN_CENSUS_REGIME_MAX_ARMS:-16}
case $regime_max_arms in
    2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16) ;;
    *)
        printf 'QWEN_CENSUS_REGIME_MAX_ARMS is a count from 2 through 16: %s\n' \
            "$regime_max_arms" >&2
        exit 2
        ;;
esac
# The graphics clock is a control under a forced policy and an observed regime
# under `auto`. The policy is validated here, ahead of the campaign shape it
# changes; the device read that resolves the required step follows the DRM
# device below.
engine_clock_policy=${QWEN_CENSUS_ENGINE_CLOCK_POLICY:-auto}
case $engine_clock_policy in
    auto | high | profile_peak | manual) ;;
    *)
        printf 'QWEN_CENSUS_ENGINE_CLOCK_POLICY is auto, high, profile_peak, or manual: %s\n' \
            "$engine_clock_policy" >&2
        exit 2
        ;;
esac
# A forced policy replaces the precondition with one priming warmup, which
# still absorbs the cold load the first server after a build pays.
warmup_arm_budget=$regime_max_arms
if [ "$engine_clock_policy" != auto ]; then
    warmup_arm_budget=1
fi
# The campaign's wall clock is bounded rather than measured ahead of the run:
# the fixed-64 scoreboard arms reach /health in about 9 seconds, answer the
# request in about 9, and tear down in about 1, and await-quiescence.sh takes
# QWEN_CENSUS_COOLDOWN_S as its deadline, so an arm costs at most 19 seconds
# plus that deadline. A calibration and an attribution each open on the regime
# precondition, whose warmup arms pay the same ceiling; the prediction takes
# the cap, since the precondition settles somewhere between two arms and it.
# shellcheck disable=SC2086
predicted_arm_count=$(printf '%s\n' $arms | wc -l | tr -d ' ')
predicted_warmup_arms=0
if [ "$census_mode" != canary ]; then
    predicted_warmup_arms=$warmup_arm_budget
fi
predicted_arm_count=$((predicted_arm_count + predicted_warmup_arms))
# The cap the ledger records is the precondition's own spend, which a forced
# policy retires rather than lowers, so it reads `-` there.
engine_clock_regime_cap_recorded=$predicted_warmup_arms
if [ "$engine_clock_policy" != auto ]; then
    engine_clock_regime_cap_recorded=-
fi
predicted_arm_duration_s=$((19 + cooldown_s))
predicted_campaign_duration_s=$((predicted_arm_count * predicted_arm_duration_s))
overlap_threshold=${QWEN_CENSUS_OVERLAP_THRESHOLD:-0.05}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-20}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
# Coverage rather than the widest gap is what a sidecar record owes an arm.
# A nice-19 sampler sharing two cores with a nice-19 server is held off for
# scheduler slices: the appliance measured 3 to 5 gaps over 20 ms per window
# with a 60 to 119 ms maximum and a lost fraction of 0.0122 to 0.0147, and
# the preceding sample cost 0.2 to 1.0 ms at almost every one, so a slow
# sysfs read does not order them. The lost fraction is therefore the
# criterion and the gap bound refuses a stall alone, at ten sampling periods.
# The fraction is a coverage criterion for a clock-state record rather than a
# safety ceiling: at the 20 ms period 0.03 is under 15 samples of a 400-sample
# window and the clock invariant still counts every sample taken. Arm 06-P of
# the 20260902T2011Z calibration held both clocks and lost 0.0214, which is a
# record answering its question under a bound set below what CFS costs it.
# The stall bound follows the clock policy. Under auto the governor may step
# inside an unobserved interval, so a stall of ten periods is refused on its
# own. Under a forced policy the firmware holds the hard minimum and soft
# maximum at one level, so a step inside a gap has no path and the samples at
# both edges of the gap bracket it; the stall bound then stands at 250 ms and
# coverage alone decides. Arm 08-C of the 20260902T2139Z served A/B held
# 1100/933 on all 365 samples and lost 0.0208, and was refused on one 113 ms
# gap, which is the refusal this split removes.
case $engine_clock_policy in
    auto) sidecar_max_gap_default_ms=100 ;;
    *) sidecar_max_gap_default_ms=250 ;;
esac
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-$sidecar_max_gap_default_ms}
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))
sidecar_max_lost_fraction=${QWEN_CENSUS_SIDECAR_MAX_LOST:-0.03}
# The sampler tolerances reach validate-clock-sidecar.py as floats, where `inf`
# and `nan` name no bound a record can miss, so both are held to the same
# canonical nonnegative decimal the control bounds are. The lost fraction is a
# share of the window, which bounds it above by one.
for census_sampler_fraction in "$sidecar_tolerance" "$sidecar_max_lost_fraction"; do
    case $census_sampler_fraction in
        '' | . | *[!0-9.]* | *.*.*)
            printf 'a census sampler tolerance is a nonnegative decimal: %s\n' \
                "$census_sampler_fraction" >&2
            exit 2
            ;;
    esac
done
if ! awk -v fraction="$sidecar_max_lost_fraction" 'BEGIN { exit (fraction + 0 < 1) ? 0 : 1 }'; then
    printf 'QWEN_CENSUS_SIDECAR_MAX_LOST is a share of the window in [0, 1): %s\n' \
        "$sidecar_max_lost_fraction" >&2
    exit 2
fi
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
# The step a forced policy must select is the highest pp_dpm_sclk lists, read
# here rather than after the write, so the value reaches the contract and the
# ledger before the device is touched and QWEN_CENSUS_PRINT_CONTRACT states it
# without writing anything. The assertion that the policy actually selected it
# stays where the write is.
engine_clock_sclk_level=-
engine_clock_mclk_level=-
engine_clock_required_sclk_mhz=-
engine_clock_required_mclk_mhz=-
engine_clock_below_required_fraction=-
engine_clock_below_mclk_floor_fraction=-
engine_clock_required_flag=''
engine_clock_mclk_flag=''
engine_clock_mclk_fraction_flag=''
# A forced policy commands the highest graphics step and holds it through
# idle, so await-quiescence.sh's "step below the highest listed step"
# predicate reports the policy rather than the machine and every cooldown
# would run to its deadline. --sclk-forced drops that half and leaves the
# busy floor and the step's own stability across the hold window carrying
# idle, which is what the cooldown between arms measures.
cooldown_sclk_forced_flag=''
cooldown_sclk_forced=0
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
    # The fabric floor admits a share where the graphics equality admits none,
    # because the two clocks answer differently under one policy: arm 03-P of
    # the 20260902T2011Z calibration read the pinned 1100 MHz on all 358 window
    # samples while the fabric hovered, reaching 1067 above its selection and
    # falling below it on 2. The tolerance prices that hover and leaves a
    # fabric that left its floor for a tenth of a window refused.
    engine_clock_below_mclk_floor_fraction=${QWEN_CENSUS_MCLK_BELOW_FRACTION:-0.01}
    if ! awk -v fraction="$engine_clock_below_mclk_floor_fraction" 'BEGIN {
        exit (fraction + 0 >= 0 && fraction + 0 < 1 && fraction ~ /^[0-9]+(\.[0-9]+)?$/) ? 0 : 1 }'; then
        printf 'QWEN_CENSUS_MCLK_BELOW_FRACTION is a fraction in [0, 1): %s\n' \
            "$engine_clock_below_mclk_floor_fraction" >&2
        exit 2
    fi
    engine_clock_required_flag=$engine_clock_required_sclk_mhz
    engine_clock_mclk_flag=$engine_clock_required_mclk_mhz
    engine_clock_mclk_fraction_flag=$engine_clock_below_mclk_floor_fraction
    cooldown_sclk_forced_flag=--sclk-forced
    cooldown_sclk_forced=1
fi
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
# The ledger every arm launches under is one of the identities the preflight
# binds, so its digest is taken once here and every later reference reads this
# value rather than hashing the file again.
artifact_ledger_sha256=$(sha256sum "$artifact_ledger" | cut -d ' ' -f 1)
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
# check-runtime-tree.sh composes one payload identity from the two rows and
# QWEN_INTENDED_PAYLOAD_SHA256 is what it holds a launch to, so the value is
# composed here the same way and handed to every arm.
runtime_tree_payload=$(printf 'remote_payload_tree_sha256=%s\npatches_payload_tree_sha256=%s\n' \
    "$runtime_tree_remote_payload" "$runtime_tree_patches_payload" \
    | sha256sum | cut -d ' ' -f 1)
# The tree the manifest identifies, and the reader that recomputes it. Every
# arm reruns check-runtime-tree.sh over this root against the head and payload
# the preflight bound, which is the same recompute qwen-launch.sh runs inside
# the arm rather than a second digest of the same bytes; the manifest rows are
# re-read beside it so a drift names the field that moved.
runtime_tree_root=$(CDPATH='' cd -- "$runtime_remote/.." && pwd)
runtime_tree_checker=$script_directory/check-runtime-tree.sh
if [ ! -r "$runtime_tree_checker" ]; then
    printf 'the runtime tree checker is absent: %s\n' "$runtime_tree_checker" >&2
    exit 2
fi
# The served runner composes the request body and drives the launch, so its own
# bytes are part of what every arm ran under.
if [ ! -r "$runner" ]; then
    printf 'the served runner is absent: %s\n' "$runner" >&2
    exit 2
fi
served_runner_sha256=$(sha256sum "$runner" | cut -d ' ' -f 1)
# The request body is composed by the served runner rather than here, so the
# campaign binds the first body an arm actually sent and holds every later arm
# to it; the bound value joins inputs.tsv the way the regime rows do.
request_sha256=-
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
        census_prepare_broker "$broker" "$broker_source" "$broker_builder"
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
# The checkpoint every arm decodes is bound by its own bytes here. An arm
# re-establishes publisher identity against whichever ledger row it reads, so a
# model and its row replaced together between the production and instrumented
# arms pass that check and leave the two roles measured on different weights;
# the digest taken once at preflight is what each arm is compared against.
model_file_bytes=$(wc -c <"$model_path" | tr -d ' ')
model_file_sha256=$(sha256sum "$model_path" | cut -d ' ' -f 1)

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
    production_manifest=$(census_manifest_beside "$production_server" production)
    set +e
    production_binding=$(census_bind_server production "$production_server" "$production_manifest" "$ctx_checkpoints")
    binding_status=$?
    set -e
    [ "$binding_status" -eq 0 ] || exit "$binding_status"
    census_require_binding_fields production "$production_binding"
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
    production_receipt_sha256=$(sha256sum "$production_receipt" | cut -d ' ' -f 1)
    ledger_sha256=$(awk -F'\t' -v id="$model_id" '$1 == id { print $4 }' "$artifact_ledger")
    ledger_bytes=$(awk -F'\t' -v id="$model_id" '$1 == id { print $3 }' "$artifact_ledger")
    if [ -z "$ledger_sha256" ] || [ -z "$ledger_bytes" ]; then
        printf 'the model artifact ledger resolves no identity for %s\n' "$model_id" >&2
        exit 2
    fi
    # The receipt directory carries the tuple the scoreboard resolved and the
    # campaign inputs it ran under; both must equal what this run resolves.
    scoreboard_tuple=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
        "$context" "$batch" "$ubatch" "$cache_k" "$cache_v" "$flash" \
        "$ctx_checkpoints" "$checkpoint_min_step" "$ledger_bytes" "$ledger_sha256")
    set +e
    scoreboard_digests=$(census_verify_scoreboard_receipt "$production_receipt" \
        "$production_sha256" "$production_bytes" "$require_scoreboard_generate" \
        "$model_id" "$scoreboard_tuple")
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
    instrumented_manifest=$(census_manifest_beside "$instrumented_server" instrumented)
    set +e
    instrumented_binding=$(census_bind_server instrumented "$instrumented_server" "$instrumented_manifest" "$ctx_checkpoints")
    binding_status=$?
    set -e
    [ "$binding_status" -eq 0 ] || exit "$binding_status"
    census_require_binding_fields instrumented "$instrumented_binding"
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
production_base_identity_sha256=-
instrumented_base_identity_sha256=-
shader_compiler_identity=unrecorded
if [ "$needs_production" = 1 ] && [ "$needs_instrumented" = 1 ]; then
    identity_scratch=$(mktemp -d)
    census_base_build_identity "$production_manifest" "$production_server" production \
        "$identity_scratch/production" "$census_cmake_flag"
    census_base_build_identity "$instrumented_manifest" "$instrumented_server" instrumented \
        "$identity_scratch/instrumented" "$census_cmake_flag"
    if ! cmp -s "$identity_scratch/production" "$identity_scratch/instrumented"; then
        printf 'the production and instrumented servers descend from different base builds:\n' >&2
        diff -- "$identity_scratch/production" "$identity_scratch/instrumented" >&2 || true
        rm -r -- "$identity_scratch"
        exit 2
    fi
    production_base_identity_sha256=$(sha256sum "$identity_scratch/production" | cut -d ' ' -f 1)
    instrumented_base_identity_sha256=$(sha256sum "$identity_scratch/instrumented" | cut -d ' ' -f 1)
    rm -r -- "$identity_scratch"
    instrumented_cmake=$(census_manifest_value "$instrumented_manifest" cmake_flags instrumented) || exit 2
    production_cmake=$(census_manifest_value "$production_manifest" cmake_flags production) || exit 2
    instrumented_delta=$(printf '%s\n' "$instrumented_cmake" | tr ' ' '\n' \
        | grep -vxF -- "$(printf '%s\n' "$production_cmake" | tr ' ' '\n')" | tr '\n' ' ') || true
    if [ "$instrumented_delta" != "$census_cmake_flag " ]; then
        printf 'the instrumented CMake delta against production must be exactly %s: [%s]\n' \
            "$census_cmake_flag" "$instrumented_delta" >&2
        exit 2
    fi
    candidate_series=$(census_manifest_value "$instrumented_manifest" candidate_series instrumented) || exit 2
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
    # Each field is counted rather than seen, the shape the contract-digest
    # reader uses: a retained state carrying `census=accepted` beside
    # `census=failed`, or two control counts, states no verdict at all, and a
    # bit set from whichever row matched would read the accepted one and ignore
    # its contradiction.
    if ! awk -F'=' '
        $1 == "census" { census_rows++; if ($2 == "accepted") census_match++ }
        $1 == "control_accepted" { accepted_rows++; if ($2 == "3") accepted_match++ }
        $1 == "control_unclassified" { unclassified_rows++; if ($2 == "0") unclassified_match++ }
        $1 == "control_refutations" { refuted_rows++; if ($2 == "0") refuted_match++ }
        $1 == "control_incomplete" { incomplete_rows++; if ($2 == "0") incomplete_match++ }
        $1 == "arm_failures" { failure_rows++; if ($2 == "0") failure_match++ }
        END {
            exit (census_rows == 1 && census_match == 1 &&
                accepted_rows == 1 && accepted_match == 1 &&
                unclassified_rows == 1 && unclassified_match == 1 &&
                refuted_rows == 1 && refuted_match == 1 &&
                incomplete_rows == 1 && incomplete_match == 1 &&
                failure_rows == 1 && failure_match == 1) ? 0 : 1
        }' "$calibration_receipt/terminal-state.tsv"; then
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
        # The token count is the mode's own: a canary requests eight and its
        # contract states the workload its seven decode graphs came out of.
        printf 'generate_tokens\t%s\nsampling\ttemperature=0 top_k=1 seed=1 ignore_eos=true thinking=false\n' \
            "$census_generate"
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
        # The band and the share threshold decide which pairs a control is
        # judged over and when the campaign declares its regime, so they sit
        # beside the bounds they act with. The regime value the precondition
        # measures stays out: an attribution runs its own arms and settles its
        # own regime, and a value in the contract would refuse it against the
        # calibration that measured another.
        printf 'sclk_band\t%s\nregime_min_share\t%s\nregime_max_share\t%s\n' \
            "$sclk_band" "$regime_min_share" "$regime_max_share"
        # The clock control enters the contract only where one is forced. Every
        # retained calibration ran under `auto` and an attribution is refused
        # unless its contract digest equals that receipt's, so an unconditional
        # row would retire every receipt in the tree to state a default. A
        # forced contract separates itself from those by carrying six rows
        # they lack: the policy, the two level selections it writes, the
        # graphics step every arm is held to, the fabric floor it may not fall
        # below, and the share of window samples under either the campaign
        # admits, which is none. A row the policy leaves unused reads `-`.
        if [ "$engine_clock_policy" != auto ]; then
            printf 'engine_clock_policy\t%s\nengine_clock_sclk_level\t%s\nengine_clock_mclk_level\t%s\n' \
                "$engine_clock_policy" "$engine_clock_sclk_level" \
                "$engine_clock_mclk_level"
            printf 'engine_clock_required_sclk_mhz\t%s\nengine_clock_required_mclk_mhz\t%s\nclock_below_required_fraction\t%s\n' \
                "$engine_clock_required_sclk_mhz" "$engine_clock_required_mclk_mhz" \
                "$engine_clock_below_required_fraction"
            # The two clocks carry two admitted shares, since the graphics
            # requirement is an equality a pinned step meets on every sample
            # and the fabric requirement is a floor a hovering clock crosses.
            printf 'clock_below_mclk_floor_fraction\t%s\n' \
                "$engine_clock_below_mclk_floor_fraction"
        fi
        # The warmup arms run the production server under the sampler ahead of
        # the registered list, so the contract states what they are for and
        # what they stay out of rather than leaving a reader to infer either
        # from the slot lettering.
        printf 'warmup_arm\tW\nwarmup_sampler\ton\nwarmup_precondition\tregime\n'
        printf 'warmup_excluded_from_pairs\tyes\nwarmup_excluded_from_census\tyes\n'
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
    # The root is what binds a receipt to the campaign that wrote it. A receipt
    # and the ledger it is rejoined to can be edited together and still agree,
    # so the closure and the rate comparison below prove consistency rather
    # than provenance; the root's own acquisition digest and its per-brick
    # receipt digests are the provenance, and they are read ahead of both.
    if [ ! -r "$reuse_directory/calibration-root.tsv" ]; then
        printf 'the brick reuse directory carries no readable calibration-root.tsv: %s\n' \
            "$reuse_directory" >&2
        exit 2
    fi
    reuse_root_acquisition_sha256=$(awk -F'\t' '$1 == "acquisition_contract_sha256" { count++; value = $2 }
        END { if (count == 1) print value; else print "-" }' \
        "$reuse_directory/calibration-root.tsv")
    if [ "$reuse_root_acquisition_sha256" != "$acquisition_contract_sha256" ]; then
        printf 'the brick reuse root records acquisition contract %s and this run runs under %s: %s\n' \
            "$reuse_root_acquisition_sha256" "$acquisition_contract_sha256" \
            "$reuse_directory/calibration-root.tsv" >&2
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
        # The receipt's own bytes against the digest the root recorded for this
        # brick. A receipt the root names no row for, or one whose bytes moved
        # since the root was written, is measured again rather than reused.
        reuse_root_receipt_sha256=$(awk -F'\t' -v brick="$brick_id" \
            '$1 == "brick" && $2 == brick { count++; value = $3 }
            END { if (count == 1) print value; else print "-" }' \
            "$reuse_directory/calibration-root.tsv")
        if [ "$reuse_root_receipt_sha256" != "$(sha256sum "$reuse_receipt" | cut -d ' ' -f 1)" ]; then
            printf 'census_brick_reuse=receipt_unbound brick=%s root=%s\n' \
                "$brick_id" "$reuse_root_receipt_sha256"
            continue
        fi
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

# The campaign owns the device from here, and the shared Vulkan lease is what
# says so. A forced policy writes the clock every workload on this machine runs
# at, so the lease is taken ahead of the first write rather than at the first
# arm: an image generation or a served request admitted between the preflight's
# process reading and that write would run inside the rate a receipt claims.
# The lease is held across every arm and released when this shell exits.
#
# The arms reach it through a proof rather than through the lock. llama-server
# takes the same lock in `update_slots` and blocks on it, so an arm launched
# under a campaign holding it exclusively would wedge its first decode pass;
# qwen-capacity-policy.sh answers a verified QWEN_VULKAN_EXTERNAL_LEASE_PROOF
# by unsetting QWEN_VULKAN_WORKLOAD_LOCK for the server it assembles, and
# measure-served-decode.sh republishes the proof for its own inherited
# descriptor 8 after comparing that descriptor against its own
# QWEN_STATE_DIRECTORY's lock. The two sides therefore read one directory: the
# arm list carries this campaign's own as QWEN_STATE_DIRECTORY, and a caller
# naming a QWEN_VULKAN_WORKLOAD_LOCK outside it is refused here rather than
# handing the arms a proof they cannot verify.
workload_lease_state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
expected_workload_lease=$workload_lease_state_directory/vulkan-workload.lock
workload_lease=${QWEN_VULKAN_WORKLOAD_LOCK:-$expected_workload_lease}
if [ "$workload_lease" != "$expected_workload_lease" ]; then
    printf 'the census holds the state directory lease alone: %s != %s\n' \
        "$workload_lease" "$expected_workload_lease" >&2
    exit 2
fi
census_workload_lease_take "$workload_lease"
workload_lease_proof=$workload_lease_state_directory/.census-vulkan-external-lease.$$.tsv
census_workload_lease_publish "$workload_lease" "$workload_lease_proof" \
    "$runtime_tree_git_head" "$script_directory/verify-external-vulkan-lease.py"
printf 'census_lease=held path=%s proof=%s\n' "$workload_lease" \
    "$workload_lease_proof"
# The proof names this pid and this descriptor, so it outlives nothing. Every
# unwind path removes it: the trap armed here, the forced-clock traps that
# replace it, and cleanup_children, which replaces those.
remove_workload_lease_proof() {
    if [ -n "${workload_lease_proof:-}" ]; then
        rm -f -- "$workload_lease_proof"
        workload_lease_proof=''
    fi
}
trap remove_workload_lease_proof EXIT
trap 'remove_workload_lease_proof; trap - EXIT; exit 143' TERM
trap 'remove_workload_lease_proof; trap - EXIT; exit 130' INT
trap 'remove_workload_lease_proof; trap - EXIT; exit 129' HUP

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
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; remove_workload_lease_proof' EXIT
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; remove_workload_lease_proof; trap - EXIT; exit 143' TERM
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; remove_workload_lease_proof; trap - EXIT; exit 130' INT
    trap 'census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"; remove_workload_lease_proof; trap - EXIT; exit 129' HUP
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
# The clock-state columns trail the ledger's own so every positional read of
# an existing field keeps its index. sclk_mode_mhz is the modal selected
# graphics clock of the arm's request window and sclk_share the fraction of
# window samples holding it, both read off the sidecar validator's own
# clock_state line; an arm running with the sampler off reports neither.
# regime_delta trails them for the same reason: it is the arm's own distance
# from the regime the warmup precondition settled on, `-` where the arm ran
# unsampled, where the precondition reached its cap, or on a warmup arm, whose
# own state is what produced the regime.
# clock_invariant and below_required_fraction trail those for the same reason:
# they carry the sidecar validator's verdict on a forced clock policy, and both
# read `-` under `auto`, on an unsampled arm, and on a ledger predating them.
arms_ledger_columns=15
printf 'slot\tarm\tserver_sha256\tpredicted_n\tpredicted_ms\ttok_s\tcensus_rows\tsidecar\townership\tstatus\tsclk_mode_mhz\tsclk_share\tregime_delta\tclock_invariant\tbelow_required_fraction\n' >"$arms_ledger"
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
        "$artifact_ledger" "$artifact_ledger_sha256"
    printf 'served_runner\t%s\nserved_runner_sha256\t%s\n' \
        "$runner" "$served_runner_sha256"
    printf 'runtime_tree_root\t%s\n' "$runtime_tree_root"
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
    # The cap is campaign shape the way the replicate count is: it bounds what
    # the run may spend on the precondition and changes no acquired byte, so it
    # is recorded here rather than in the digest an attribution is held to. The
    # band and the share threshold are echoed beside it because a reader of one
    # run's inputs should not have to open its contract to read them.
    printf 'sclk_band\t%s\nregime_min_share\t%s\nregime_max_share\t%s\n' \
        "$sclk_band" "$regime_min_share" "$regime_max_share"
    printf 'regime_max_arms\t%s\n' "$engine_clock_regime_cap_recorded"
    # The clock control and what it is held to, stated in every run's own
    # record whether or not it entered the digest an attribution is bound to.
    printf 'engine_clock_policy\t%s\nengine_clock_sclk_level\t%s\nengine_clock_mclk_level\t%s\n' \
        "$engine_clock_policy" "$engine_clock_sclk_level" "$engine_clock_mclk_level"
    printf 'engine_clock_required_sclk_mhz\t%s\nengine_clock_required_mclk_mhz\t%s\nclock_below_required_fraction\t%s\n' \
        "$engine_clock_required_sclk_mhz" "$engine_clock_required_mclk_mhz" \
        "$engine_clock_below_required_fraction"
    printf 'clock_below_mclk_floor_fraction\t%s\n' \
        "$engine_clock_below_mclk_floor_fraction"
    # The floor names what the fabric requirement is, since the graphics
    # requirement is an equality and the two sit in one contract.
    printf 'mclk_floor_mhz\t%s\nengine_clock_sclk_readback_mhz\t%s\n' \
        "$engine_clock_required_mclk_mhz" "$engine_clock_sclk_readback"
    printf 'engine_clock_mclk_readback_mhz\t%s\nengine_clock_snapshot\t%s\n' \
        "$engine_clock_mclk_readback" "$engine_clock_snapshot"
    printf 'brick_reuse_directory\t%s\nreused_bricks\t%s\nreused_brick_count\t%s\n' \
        "${reuse_directory:--}" "${reused_bricks:--}" "$reused_brick_count"
    printf 'runtime_tree_manifest\t%s\nruntime_tree_git_head\t%s\nruntime_tree_remote_payload_sha256\t%s\nruntime_tree_patches_payload_sha256\t%s\n' \
        "$runtime_tree_manifest" "$runtime_tree_git_head" "$runtime_tree_remote_payload" "$runtime_tree_patches_payload"
    # The composed payload identity every arm launches under, beside the
    # checkpoint bytes every arm is compared against.
    printf 'runtime_tree_payload_sha256\t%s\n' "$runtime_tree_payload"
    printf 'model_file_bytes\t%s\nmodel_file_sha256\t%s\n' \
        "$model_file_bytes" "$model_file_sha256"
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
    # The forced clock is the campaign's own transition, so it unwinds with the
    # children rather than in a trap of its own; the restore acts once and
    # leaves the exit status where it found it.
    if [ "$engine_clock_policy" != auto ]; then
        census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"
    fi
    remove_workload_lease_proof
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

# The regime precondition opens the campaign. Warmup arms run the production
# server with the sampler on at slots 0a through 0p, so the registered arms
# keep the integer slots every brick, receipt, and pair is stated in, and the
# run reads each warmup's own clock state until two consecutive arms hold modes
# inside the band and each holds a modal share inside the window
# [regime_min_share, regime_max_share], which the pinned boost clock sits
# above and the hovering sustained regime inside. That pair's
# mean is the regime, recorded in inputs.tsv and compared against every named
# arm; the cap ends the precondition without one, and the pairs still carry
# their own comparability. A canary judges chain structure at eight tokens and
# asserts no rate, so it runs no warmup.
#
# The list carries the cap's worth of W entries and the loop stops executing
# them the instant the regime is reached, which is what lets one loop own both
# phases.
execution_arms=$arms
warmup_arms=''
if [ "$census_mode" != canary ] && \
    { [ "$census_mode" != calibration ] || [ "$reused_brick_count" -ne 4 ]; }; then
    warmup_index=0
    while [ "$warmup_index" -lt "$warmup_arm_budget" ]; do
        warmup_arms="$warmup_arms W"
        warmup_index=$((warmup_index + 1))
    done
    execution_arms="${warmup_arms# } $arms"
elif [ "$census_mode" = calibration ]; then
    # A warmup warms the arms that follow it and the precondition states the
    # regime they run in, so a calibration whose four bricks all reuse has
    # neither to do and runs no server at all.
    printf 'census_arm=skipped slot=0 arm=W reason=every_brick_reused\n'
fi
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
# One arm's reading of an identity the preflight bound. The record carries both
# sides of every field whatever it decides, so an arm that held is as readable
# as one that moved, and the first field to differ is the one the campaign
# reports: a sync that moved the tree moves three fields at once and the run
# names the head rather than whichever digest a later comparison reached.
identity_record=''
identity_drift_field=''
identity_drift_expected=-
identity_drift_observed=-
record_arm_identity() {
    # $1 = field, $2 = the preflight's value, $3 = this arm's reading. A `-`
    # reading is one the arm never produced -- a reply it did not reach, a
    # record it did not write -- rather than a value that moved, so it records
    # as unobserved and decides nothing; an absent file reads `absent`, which
    # differs from every bound value and is drift.
    arm_identity_state=bound
    if [ "$3" = - ]; then
        arm_identity_state=unobserved
    elif [ "$2" != "$3" ]; then
        arm_identity_state=drifted
        if [ -z "$identity_drift_field" ]; then
            identity_drift_field=$1
            identity_drift_expected=$2
            identity_drift_observed=$3
        fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$arm_identity_state" \
        >>"$identity_record"
}
arm_failures=0
cooldown_timeouts=0
# A campaign that ends inside the arm loop names the state it ended in, the
# slot and arm it ended after, and the detail that decided it. An empty name
# is a run that reached its own last arm.
campaign_terminal=''
terminal_slot=-
terminal_arm=-
terminal_detail=-
canary_structure_failures=0
canary_structure_ledger=$output_directory/canary-structure.tsv
if [ "$census_mode" = canary ]; then
    printf 'slot\tarm\tcheck\tstate\n' >"$canary_structure_ledger"
fi
for arm in $execution_arms; do
    if [ "$arm" = W ]; then
        # The list holds the cap's worth of warmups and the precondition needs
        # as many as it needs, so a settled regime leaves the remainder unrun.
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
    # A reused brick's arms are echoed at their own slots, so the ledger keeps
    # thirteen rows in campaign order and the pair parser, which walks
    # positions rather than slot numbers, reads the same quadruples it would
    # have read from a run that executed every arm.
    case $reused_slots in
        *" $slot "*)
            reuse_row=$(awk -F'\t' -v slot="$slot" '$1 == slot { print $0 }' \
                "$reuse_directory/arms.tsv")
            # A retained ledger written before a column existed carries fewer
            # fields than this run's header names, so the echo pads the row to
            # the header's arity with the unknown value and arms.tsv stays
            # rectangular under one header.
            printf '%s\n' "$reuse_row" \
                | awk -F'\t' -v OFS='\t' -v column="$reuse_status_column" \
                    -v want="$arms_ledger_columns" \
                    '{ $column = "reused"; while (NF < want) { $(NF + 1) = "-" } print }' \
                    >>"$arms_ledger"
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
        # A warmup's clock state is what the regime precondition reads, so W
        # samples where P-nosidecar is the arm that prices the sampler's
        # absence.
        P | W) server=$production_server ;;
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
        census_arm_exec "$arm_directory/arm-environment.tsv" \
            QWEN_LLAMA_SERVER="$server" \
            QWEN_LAUNCH_SCRIPT="$runtime_remote/qwen-launch.sh" \
            QWEN_TEARDOWN_SCRIPT="$runtime_remote/qwen-teardown.sh" \
            QWEN_INTENDED_GIT_HEAD="$runtime_tree_git_head" \
            QWEN_INTENDED_PAYLOAD_SHA256="$runtime_tree_payload" \
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
            QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$workload_lease_proof" \
            QWEN_STATE_DIRECTORY="$workload_lease_state_directory" \
            -- \
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
    # Every arm re-establishes the whole runtime identity the preflight bound
    # and retains both sides of each field, so a runtime sync, a checkpoint
    # replacement, or an executable replacement between two arms is named at
    # the arm that first read it rather than left for a reader to infer from
    # two rates measured under different inputs. The record covers the
    # checkpoint's bytes and digest, the served binary's bytes and digest, the
    # runtime tree's head and both payload digests beside one recompute over
    # its files, the artifact ledger, the served runner itself, and the request
    # body the arms send.
    identity_record=$arm_directory/runtime-identity.tsv
    identity_drift_field=''
    identity_drift_expected=-
    identity_drift_observed=-
    printf 'field\texpected\tobserved\tstate\n' >"$identity_record"
    # The arm's server is hashed after the arm and compared with the byte count
    # and digest the preflight bound to its role, so a binary replaced
    # mid-campaign is named rather than recorded as that role.
    server_sha256=$(sha256sum "$server" | cut -d ' ' -f 1)
    server_bytes=$(wc -c <"$server" | tr -d ' ')
    case $arm in
        P | P-nosidecar | W)
            bound_role_sha256=$production_sha256
            bound_role_bytes=$production_bytes
            ;;
        *)
            bound_role_sha256=$instrumented_sha256
            bound_role_bytes=$instrumented_bytes
            ;;
    esac
    record_arm_identity server_sha256 "$bound_role_sha256" "$server_sha256"
    record_arm_identity server_bytes "$bound_role_bytes" "$server_bytes"
    # The checkpoint is re-read after the arm the way the server is. A model
    # replaced consistently with its ledger row passes the arm's own publisher
    # check and leaves the production and instrumented rates measured on
    # different weights, so the preflight digest decides it here.
    # The served runner hashes the descriptor it pinned and writes both figures
    # into runtime-inputs.json, so that record is the arm's own reading of the
    # checkpoint and the comparison costs no second pass over the file. The
    # file's byte count is read beside it, which catches a replacement that
    # left no record at all.
    arm_model_bytes=absent
    arm_model_sha256=-
    if [ -r "$model_path" ]; then
        arm_model_bytes=$(wc -c <"$model_path" | tr -d ' ')
    fi
    if [ -r "$arm_directory/runtime-inputs.json" ]; then
        arm_model_sha256=$(python3 - "$arm_directory/runtime-inputs.json" <<'ARM_MODEL_IDENTITY' || true
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("model", {}).get("sha256") or "-")
except (OSError, ValueError):
    print("-")
ARM_MODEL_IDENTITY
)
        [ -n "$arm_model_sha256" ] || arm_model_sha256=-
    fi
    record_arm_identity model_bytes "$model_file_bytes" "$arm_model_bytes"
    record_arm_identity model_sha256 "$model_file_sha256" "$arm_model_sha256"
    # The manifest the sync wrote beside the runtime tree is re-read for the
    # three rows that name what travelled, so a resync between arms names the
    # head or the payload half that moved; check-runtime-tree.sh then recomputes
    # every file digest and mode class against the head and payload the
    # preflight bound, which is the reader qwen-launch.sh already runs inside
    # the arm rather than a second hasher over the same bytes.
    arm_runtime_git_head=absent
    arm_runtime_remote_payload=absent
    arm_runtime_patches_payload=absent
    if arm_runtime_identity=$(awk -F'\t' '
        $1 == "git_head" || $1 == "remote_payload_tree_sha256" || $1 == "patches_payload_tree_sha256" { seen[$1] = $2; count++ }
        END { if (count != 3) exit 1
            printf "%s\t%s\t%s\n", seen["git_head"], seen["remote_payload_tree_sha256"], seen["patches_payload_tree_sha256"] }' \
        "$runtime_tree_manifest" 2>/dev/null); then
        IFS="$(printf '\t')" read -r arm_runtime_git_head arm_runtime_remote_payload \
            arm_runtime_patches_payload <<ARM_RUNTIME_TREE
$arm_runtime_identity
ARM_RUNTIME_TREE
    fi
    record_arm_identity runtime_tree_git_head "$runtime_tree_git_head" "$arm_runtime_git_head"
    record_arm_identity runtime_tree_remote_payload_sha256 \
        "$runtime_tree_remote_payload" "$arm_runtime_remote_payload"
    record_arm_identity runtime_tree_patches_payload_sha256 \
        "$runtime_tree_patches_payload" "$arm_runtime_patches_payload"
    set +e
    "$runtime_tree_checker" "$runtime_tree_root" "$runtime_tree_git_head" \
        "$runtime_tree_payload" >"$arm_directory/runtime-tree.txt" 2>&1
    runtime_tree_status=$?
    set -e
    arm_runtime_tree_state=divergent
    [ "$runtime_tree_status" -ne 0 ] || arm_runtime_tree_state=verified
    record_arm_identity runtime_tree_verified verified "$arm_runtime_tree_state"
    arm_artifact_ledger_sha256=absent
    if [ -r "$artifact_ledger" ]; then
        arm_artifact_ledger_sha256=$(sha256sum "$artifact_ledger" | cut -d ' ' -f 1)
    fi
    record_arm_identity artifact_ledger_sha256 "$artifact_ledger_sha256" \
        "$arm_artifact_ledger_sha256"
    arm_served_runner_sha256=absent
    if [ -r "$runner" ]; then
        arm_served_runner_sha256=$(sha256sum "$runner" | cut -d ' ' -f 1)
    fi
    record_arm_identity served_runner_sha256 "$served_runner_sha256" \
        "$arm_served_runner_sha256"
    # The request body is composed by the served runner rather than by this
    # runner, so the campaign binds the first body an arm actually sent and
    # holds every later arm to it: two arms whose requests differ measured two
    # workloads whatever else about them agreed. The bound value joins
    # inputs.tsv the moment it exists, the way the regime rows do.
    arm_request_sha256=-
    if [ -r "$arm_directory/request.json" ]; then
        arm_request_sha256=$(sha256sum "$arm_directory/request.json" | cut -d ' ' -f 1)
    fi
    if [ "$request_sha256" = - ] && [ "$arm_request_sha256" != - ]; then
        request_sha256=$arm_request_sha256
        printf 'request_sha256\t%s\n' "$request_sha256" >>"$output_directory/inputs.tsv"
        printf 'census_request=bound slot=%s arm=%s request_sha256=%s\n' \
            "$slot" "$arm" "$request_sha256"
    fi
    record_arm_identity request_sha256 "$request_sha256" "$arm_request_sha256"
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
    # A field that moved is an incident rather than one arm's failure: the
    # campaign's inputs changed under it, so every arm after this one would
    # measure a different experiment under the same receipt. The run ends here
    # naming the field, and the reason outranks the served-runner verdict
    # because a replaced binary or checkpoint is what that verdict is about.
    if [ -n "$identity_drift_field" ]; then
        status=failed
        reason=identity_incident
        campaign_terminal=identity_incident
        terminal_slot=$slot
        terminal_arm=$arm
        terminal_detail=$identity_drift_field
        printf 'census_incident=identity slot=%s arm=%s field=%s expected=%s observed=%s\n' \
            "$slot" "$arm" "$identity_drift_field" "$identity_drift_expected" \
            "$identity_drift_observed"
    fi
    # A sampler that announced no readiness is its own reason: the request
    # never ran, so the served-runner verdict above states the consequence
    # where this one states the cause. A warmup that never reached its request
    # fails the same way, since the precondition reads a clock state the arm
    # never produced; the validator's own refusal is the one a warmup carries
    # without failing.
    if [ "$sidecar_start_failed" -eq 1 ]; then
        status=failed
        reason=sidecar_start
    fi
    # The sidecar record is evidence only where the validator accepts it:
    # exit status, sample count, one footer, the achieved period, the mean
    # cost, every sensor present, and the request window covered.
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
                ${engine_clock_mclk_fraction_flag:+--max-below-mclk-floor-fraction "$engine_clock_mclk_fraction_flag"} \
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
                ${engine_clock_mclk_fraction_flag:+--max-below-mclk-floor-fraction "$engine_clock_mclk_fraction_flag"} \
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
        clock_invariant_source=-
        if [ -n "$clock_invariant_line" ]; then
            clock_invariant_state=$(printf '%s\n' "$clock_invariant_line" \
                | awk '{ sub(/^clock_invariant=/, "", $1); print $1 }')
            below_required_fraction=$(printf '%s\n' "$clock_invariant_line" \
                | awk '{ for (i = 1; i <= NF; i++) if (index($i, "below_required_fraction=") == 1) print substr($i, 25) }')
            clock_invariant_source=$(printf '%s\n' "$clock_invariant_line" \
                | awk '{ for (i = 1; i <= NF; i++) if (index($i, "sclk_source=") == 1) print substr($i, 13) }')
            [ -n "$clock_invariant_source" ] || clock_invariant_source=-
        fi
        case $clock_invariant_state in
            held | violated) ;;
            *) clock_invariant_state=- ;;
        esac
        [ -n "$below_required_fraction" ] || below_required_fraction=-
        [ "$clock_invariant_state" != - ] || below_required_fraction=-
        # The validator states the window's own clock state on one line; the
        # ledger carries the modal graphics clock and its share so the controls
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
            # A warmup measures the machine's state rather than a control, so a
            # record the validator refuses costs the precondition that arm's
            # reading and leaves the campaign standing; the cap is what bounds
            # a sampler that refuses every warmup.
            if [ "$status" = completed ] && [ "$arm" != W ]; then
                status=failed
                reason=clock_sidecar
                [ "$clock_invariant_state" != violated ] || reason=clock_invariant
            fi
        fi
        # A forced policy is answered by the delivered frequency alone. Where
        # the validator counted the DPM column instead, the invariant restates
        # the selection this campaign wrote and holds nothing, so the arm is
        # refused on its instrument rather than credited for agreeing with
        # itself: the 20260902T2011Z calibration sampled with a broker built
        # before telemetry-broker.c grew `sclk_actual_mhz` and read every arm
        # held.
        if [ -n "$engine_clock_required_flag" ] \
            && [ "$clock_invariant_state" != - ] \
            && [ "$clock_invariant_source" != sclk_actual_mhz ] \
            && [ "$arm" != W ]; then
            printf 'census_clock_source=refused slot=%s arm=%s source=%s\n' \
                "$slot" "$arm" "$clock_invariant_source"
            # The reason outranks the two verdicts over the same disqualified
            # reading and leaves a run-level failure alone: a server replaced
            # under the campaign is what that arm reports.
            case $reason in
                '' | clock_sidecar | clock_invariant)
                    status=failed
                    reason=clock_source
                    ;;
            esac
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
        elif [ "$sidecar_state" != on ]; then
            # The validator prints its clock_state line whatever it decides
            # about the record, so a refused warmup carries a mode the run has
            # no telemetry for. The precondition spends the arm and keeps the
            # last accepted reading rather than settling on a refused one.
            printf 'census_regime=record_refused slot=%s arm=%s\n' "$slot" "$arm"
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
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$slot" "$arm" \
        "$server_sha256" "$predicted_n" "$predicted_ms" "$tok_s" "$census_rows" \
        "$sidecar_state" "$ownership" "$status" "$sclk_mode_mhz" "$sclk_share" \
        "$regime_delta" "$clock_invariant_state" "$below_required_fraction" >>"$arms_ledger"
    printf 'census_arm=%s slot=%s arm=%s tok_s=%s census_rows=%s sidecar=%s ownership=%s sclk_mode_mhz=%s regime_delta=%s clock_invariant=%s reason=%s\n' \
        "$status" "$slot" "$arm" "$tok_s" "$census_rows" "$sidecar_state" "$ownership" \
        "$sclk_mode_mhz" "$regime_delta" "$clock_invariant_state" "${reason:--}"
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
    quiescence_verdict=skipped
    quiescence_elapsed_ms=0
    quiescence_status=-
    quiescence_predicates=-
    # The boundary between arms is convergence rather than a constant. An arm
    # leaves Vulkan submission, clock boost, thermal drift, and page reclaim
    # behind at different rates, so await-quiescence.sh polls each predicate
    # and reports the instant they have all held together; QWEN_CENSUS_COOLDOWN_S
    # becomes its deadline. A campaign already ending on this arm waits for no
    # boundary, since the arm it would prepare never runs, and its cooldown row
    # says so rather than spending the deadline to report a state nothing reads.
    if [ -z "$campaign_terminal" ]; then
        set +e
        # The lease predicate is left off. await-quiescence.sh polls it with
        # `flock -n -x`, and the campaign holds that lock exclusively from
        # before the clock write to its own exit, so the poll would read the
        # campaign's own exclusion as a foreign workload and spend every
        # cooldown deadline. Holding the lease exclusively is the strictly
        # stronger form of the predicate the flag polls -- a lock this shell
        # owns admits no other workload at all -- and the cooldown row states
        # that rather than leaving a reader of the ledger to infer why the
        # predicate stopped being polled. The latency predicate is left off for
        # a different reason: it reads a `baseline_p90_us=` field the graphics
        # probe log names on no line, so the poller reports it not_applicable
        # and spends one summarize-probe.sh pass per 100 ms tick to do it. The
        # criterion is live for a caller whose log grows that field.
        quiescence_line=$("$script_directory/await-quiescence.sh" \
            --max-seconds "$cooldown_s" \
            ${cooldown_sclk_forced_flag:+--sclk-forced} \
            2>"$arm_directory/await-quiescence.stderr")
        quiescence_status=$?
        set -e
        quiescence_verdict=$(printf '%s\n' "$quiescence_line" \
            | sed -n 's/^quiescence=\([a-z][a-z]*\).*/\1/p')
        quiescence_elapsed_ms=$(printf '%s\n' "$quiescence_line" \
            | sed -n 's/.*elapsed_ms=\([0-9][0-9]*\).*/\1/p')
        # A poller that printed no parseable line is a third state beside
        # reached and timeout, and it is named rather than folded into either.
        [ -n "$quiescence_verdict" ] || quiescence_verdict=unreported
        [ -n "$quiescence_elapsed_ms" ] || quiescence_elapsed_ms=-
        # The poller names every predicate that read false on its final tick,
        # so a boundary that never converged states which of process, GPU
        # occupancy, graphics step, step stability, absolute temperature,
        # thermal derivative, available memory, swap-in, lease, or latency held
        # it open.
        quiescence_predicates=$(sed -n 's/^quiescence_timeout_predicates=//p' \
            "$arm_directory/await-quiescence.stderr" | tail -n 1)
        [ -n "$quiescence_predicates" ] || quiescence_predicates=-
        [ "$quiescence_verdict" = reached ] || cooldown_timeouts=$((cooldown_timeouts + 1))
    fi
    cooldown_end_ns=$(date +%s%N)
    printf 'census_cooldown=%s slot=%s arm=%s elapsed_ms=%s status=%s sclk_forced=%s predicates=%s lease=held-by-campaign\n' \
        "$quiescence_verdict" "$slot" "$arm" "$quiescence_elapsed_ms" \
        "$quiescence_status" "$cooldown_sclk_forced" "$quiescence_predicates"
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
        printf '%s\t%s\tcooldown\t%s\t%s\tquiescence=%s elapsed_ms=%s sclk_forced=%s predicates=%s\n' \
            "$slot" "$arm" "$cooldown_begin_ns" "$cooldown_end_ns" \
            "$quiescence_verdict" "$quiescence_elapsed_ms" "$cooldown_sclk_forced" \
            "$quiescence_predicates"
    } >>"$wall_clock_ledger"
    # The boundary decides the campaign rather than a counter read after it.
    # await-quiescence.sh reports `reached` only where the process, occupancy,
    # graphics step and its stability, both temperature conditions, memory,
    # swap-in, lease, and latency predicates held together across the whole
    # hold window, so any other verdict leaves the next arm a machine state
    # this arm chose. The campaign ends here, ahead of that arm, and arms.tsv
    # carries the boundary row that names the state; --sclk-forced drops the
    # step's position under a commanded clock and licenses none of the rest.
    if [ -z "$campaign_terminal" ] && [ "$quiescence_verdict" != reached ]; then
        campaign_terminal=quiescence_unconverged
        terminal_slot=$slot
        terminal_arm=$arm
        terminal_detail=$quiescence_predicates
        printf '%s\tcooldown\t-\t-\t-\t-\t-\t-\t-\tquiescence_%s\t-\t-\t-\t-\t-\n' \
            "$slot" "$quiescence_verdict" >>"$arms_ledger"
        printf 'census_cooldown=terminal slot=%s arm=%s verdict=%s predicates=%s\n' \
            "$slot" "$arm" "$quiescence_verdict" "$quiescence_predicates"
    fi
    # A campaign state set anywhere inside this arm ends the loop after the
    # arm's own rows have landed, so the ledger and the wall clock hold the arm
    # that ended the run rather than stopping one row short of it.
    [ -z "$campaign_terminal" ] || break
done
# A calibration whose four bricks all reuse executes no arm at all, so the
# precondition never met a named arm to report itself ahead of; the rows still
# join inputs.tsv, since a reader of any run asks what its arms were measured
# against and reads the unreached answer there.
if [ "$census_mode" != canary ] && [ "$regime_reported" -eq 0 ]; then
    record_regime
fi

# A campaign that ended inside the arm loop reports the state that ended it and
# stops. The controls summarizer is left unrun, since a truncated ledger holds
# quadruples the registry never bound and a verdict over them would price the
# arms that did run against pairs that never did; the brick receipts and the
# calibration root are left unwritten for the stronger reason that a root over
# half a campaign is exactly what a later run's reuse would copy forward.
# terminal-state.tsv carries the row names the completed path writes, so the
# attribution receipt reader counts them by name and refuses this run on its
# census row rather than on a malformed record.
if [ -n "$campaign_terminal" ]; then
    case $campaign_terminal in
        quiescence_unconverged) campaign_exit=5 ;;
        identity_incident) campaign_exit=6 ;;
        *) campaign_exit=1 ;;
    esac
    {
        printf 'census=%s\ncensus_mode=%s\narm_failures=%s\n' \
            "$campaign_terminal" "$census_mode" "$arm_failures"
        printf 'control_incomplete=-\ncontrol_refutations=-\ncontrol_unresolved=-\n'
        printf 'control_state_changed=-\ncontrol_unclassified=-\ncontrol_accepted=-\n'
        printf 'control_required=-\ncooldown_timeouts=%s\ncalibration_root_sha256=-\n' \
            "$cooldown_timeouts"
        printf 'terminal_slot=%s\nterminal_arm=%s\nterminal_detail=%s\n' \
            "$terminal_slot" "$terminal_arm" "$terminal_detail"
    } >"$output_directory/terminal-state.tsv"
    printf -- '-\t-\tcampaign\t%s\t%s\t-\n' "$campaign_begin_ns" "$(date +%s%N)" \
        >>"$wall_clock_ledger"
    printf 'census=%s mode=%s model=%s terminal_slot=%s terminal_arm=%s terminal_detail=%s arm_failures=%s cooldown_timeouts=%s output=%s\n' \
        "$campaign_terminal" "$census_mode" "$model_id" "$terminal_slot" \
        "$terminal_arm" "$terminal_detail" "$arm_failures" "$cooldown_timeouts" \
        "$output_directory"
    exit "$campaign_exit"
fi

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
    printf 'census=%s\ncensus_mode=%s\narm_failures=%s\ncontrol_incomplete=-\ncontrol_refutations=-\ncontrol_unresolved=-\ncontrol_state_changed=-\ncontrol_unclassified=-\ncontrol_accepted=-\ncontrol_required=-\ncanary_structure_failures=%s\ncooldown_timeouts=%s\ncalibration_root_sha256=%s\n' \
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
    --sclk-band "$sclk_band" \
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
        else if ($column == "state-changed") state_changed++
        else if ($column == "accepted") accepted++
    }
    END { print refuted + 0, incomplete + 0, unclassified + 0, accepted + 0, unresolved + 0, state_changed + 0 }' \
    "$output_directory/summary.tsv")
set -- $control_counts
control_refutations=$1
control_incomplete=$2
control_unclassified=$3
control_accepted=$4
control_unresolved=$5
control_state_changed=$6
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
# The boundary ends the campaign where it fails, so a run reaching this line
# converged after every arm and the count stands as the assertion that says so.
if [ "$arm_failures" -ne 0 ] || [ "$control_incomplete" -ne 0 ] \
    || [ "$control_unclassified" -ne 0 ] || [ "$cooldown_timeouts" -ne 0 ]; then
    campaign=failed
    campaign_exit=1
elif [ "$control_refutations" -ne 0 ]; then
    campaign=refuted
    campaign_exit=3
elif [ "$control_unresolved" -ne 0 ] || [ "$control_state_changed" -ne 0 ]; then
    # A control whose interval spans its bound measured neither a cost inside
    # the bound nor one beyond it, and a control left with fewer than two pairs
    # that held one clock state measured the governor instead, so both resolve
    # nothing and the campaign says so under one status rather than borrowing
    # accepted or refuted. The branch precedes the accepted-count test, since
    # either leaves that count short and would otherwise read as a failure.
    campaign=unresolved
    campaign_exit=4
elif [ "$control_accepted" -lt "$required_accepted" ]; then
    campaign=failed
    campaign_exit=1
else
    campaign=accepted
    campaign_exit=0
fi
printf 'census=%s\ncensus_mode=%s\narm_failures=%s\ncontrol_incomplete=%s\ncontrol_refutations=%s\ncontrol_unresolved=%s\ncontrol_state_changed=%s\ncontrol_unclassified=%s\ncontrol_accepted=%s\ncontrol_required=%s\ncooldown_timeouts=%s\ncalibration_root_sha256=%s\n' \
    "$campaign" "$census_mode" "$arm_failures" "$control_incomplete" "$control_refutations" \
    "$control_unresolved" "$control_state_changed" "$control_unclassified" \
    "$control_accepted" "$required_accepted" \
    "$cooldown_timeouts" "$calibration_root_sha256" >"$output_directory/terminal-state.tsv"
printf -- '-\t-\tcampaign\t%s\t%s\t-\n' "$campaign_begin_ns" "$(date +%s%N)" >>"$wall_clock_ledger"
printf 'census=%s mode=%s model=%s arms=%s reused_bricks=%s arm_failures=%s control_incomplete=%s control_refutations=%s control_unresolved=%s control_state_changed=%s control_unclassified=%s control_accepted=%s control_required=%s calibration_root=%s output=%s\n' \
    "$campaign" "$census_mode" "$model_id" "$slot" "${reused_bricks:--}" "$arm_failures" \
    "$control_incomplete" "$control_refutations" "$control_unresolved" \
    "$control_state_changed" "$control_unclassified" \
    "$control_accepted" "$required_accepted" "$calibration_root_sha256" "$output_directory"
exit "$campaign_exit"
