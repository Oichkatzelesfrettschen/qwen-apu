#!/bin/sh
set -eu

# The prefill half of the served comparison, measured on its own. The decode
# campaigns hold the appliance's submission profile at low-async and read tok/s
# over a fixed generation; this ladder holds the same machine state and reads
# what a prompt costs before the first token appears, at 512, 4096, 16384, and
# 32768 tokens, with one production thread.
#
# Each depth carries two mirrored quadruples. `C K K C` is the control server
# against the candidate server at the same one thread, which is the binary
# comparison. `C T T C` is the control server at one thread against the control
# server at the registry row's own thread count, which states the CPU-side share
# of a prefill at that depth: the two quadruples differ by exactly one thing
# each, so a difference the first reports is the binary and a difference the
# second reports is the thread count. The mirrored order puts each pair's two
# arms adjacent in the queue, and summarize-prefill-ladder.py pairs the subject
# arm's first replicate with the control's first and the second with the second.
#
# The prompt is built rather than assumed. A deterministic filler word is
# repeated and the count adjusted against `POST /tokenize` on the served path
# until that route returns exactly the requested depth, so the ladder's rungs
# are token counts rather than character counts. Each arm re-tokenizes the same
# prompt bytes and refuses where the count moved, and the served request's own
# `timings.prompt_n` is required to sit within QWEN_PREFILL_LADDER_PROMPT_N_SLACK
# of it, since `/completion` prepends the beginning-of-sequence token that
# `/tokenize` leaves out.
#
# Time to first token is the wall time from the instant the request leaves to
# the first streamed chunk carrying content, so it holds the HTTP round trip and
# the first sampling pass beside the prefill. `timings.prompt_ms` and
# `timings.prompt_per_second` are the server's own instrument over the same
# fill, and both reach the ledger: a ratio that moves on time to first token
# while `prompt_tok_s` holds reports transport rather than prefill.
#
# Every timing is required. A reply whose `timings` object omits a field the
# ledger states fails its arm with reason `missing_timings` rather than filling
# a zero, because a rate of nothing pairs as a measurement.
#
# The device is held the way the served campaigns hold it. The shared Vulkan
# lease is taken before the first DPM write, the graphics and fabric levels are
# written under `manual` through census-arm-lib.sh's own functions with the
# restore trap armed ahead of the write, and each arm's clock record is
# validated by validate-clock-sidecar.py, so an arm that ran off the pinned step
# reaches the ledger as `clock_invariant=violated` and its pair leaves the
# interval. The operating point names the confirmed graphics and fabric
# selections under `manual`, and the appliance's own governor under `auto`.
#
# The servers are started directly, the way run-kernel-delta-witness.sh starts
# its arms, with the registry tuple, every buffer required on Vulkan0, the
# closed environment census_arm_exec applies, the production `low-async`
# submission profile `radv-low-priority-env.sh` selects for a served rate, and
# the nice 19 policy every measurement process on this machine runs under, and
# never while the appliance serves. The allocation is one context size for the
# whole ladder, so a depth changes the prompt and leaves the KV allocation
# alone.
#
# A depth above the row's `validated_filled_depth` is skipped with its reason
# rather than measured, since no run has proven the allocation fills and decodes
# that deep at all. A depth that would leave fewer than the generation length,
# QWEN_PREFILL_LADDER_TAIL_RESERVE, and QWEN_PREFILL_LADDER_PROMPT_N_SLACK
# tokens of the allocation clamps to the deepest count that leaves exactly that
# much room instead, and the arm carries the clamped count rather than the
# requested one, since a prompt filling its own allocation evicts rather than
# decodes and a "32768" label on a 32719-token prompt misstates what ran. Two
# requested depths that would clamp to the same
# count refuse the whole invocation before any server starts, since the ledger
# keys one row set per depth. A depth left with no positive room to clamp into
# is skipped rather than measured at a zero or negative count. A skipped depth
# leaves the exit status at 0; an admitted depth with any failed arm makes it
# non-zero.
#
# usage: run-prefill-ladder.sh CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIR
#   QWEN_PREFILL_LADDER_DEPTHS         prompt depths, default "512 4096 16384 32768"
#   QWEN_PREFILL_LADDER_GENERATE       tail tokens each arm decodes, default 16
#   QWEN_PREFILL_LADDER_THREADS        threads the prefill arms run at, default 1
#   QWEN_PREFILL_LADDER_THREAD_ARMS    1 (default) runs the `C T T C` quadruple
#   QWEN_PREFILL_LADDER_TAIL_RESERVE   allocation tokens held back beyond the
#                                      generation length, default 32
#   QWEN_PREFILL_LADDER_PROMPT_N_SLACK admitted excess of timings.prompt_n over
#                                      the tokenized count, default 1
#   QWEN_PREFILL_LADDER_ATTEMPTS       prompt-length adjustments per depth, default 24
#   QWEN_PREFILL_LADDER_FILLER         the repeated filler word, default `token`
#   QWEN_PREFILL_LADDER_SAMPLER        python (default) or off
#   QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY  manual (default) or auto
#   QWEN_CENSUS_SCLK_LEVEL             graphics level manual selects, default the
#                                      highest level pp_dpm_sclk lists
#   QWEN_CENSUS_MCLK_LEVEL             fabric level manual writes, default the
#                                      highest level pp_dpm_mclk lists
#   QWEN_CENSUS_MCLK_FLOOR_MHZ         fabric floor the invariant holds every
#                                      window sample to, default 933
#   QWEN_CENSUS_SIDECAR_*              sampler geometry, the census campaign's own
#   QWEN_PREFILL_LADDER_PRINT_PLAN     1 prints the plan and the bindings, then exits

if [ "$#" -ne 4 ]; then
    printf 'usage: %s CONTROL_SERVER CANDIDATE_SERVER MODEL_ID OUTPUT_DIR\n' "$0" >&2
    exit 2
fi
control_server=$1
candidate_server=$2
model_id=$3
output_directory=$4
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
# The lease, the clock transition, and the sealed arm environment are the census
# campaigns' own, so a rule tightened for either reaches this ladder.
# shellcheck source=census-arm-lib.sh
. "$script_directory/census-arm-lib.sh"
registry_script=${QWEN_MODEL_REGISTRY_SCRIPT:-"$script_directory/model-registry.sh"}
summarizer=${QWEN_PREFILL_LADDER_SUMMARIZER:-"$script_directory/summarize-prefill-ladder.py"}
sidecar=$script_directory/sample-clock-sidecar.py
sidecar_validator=$script_directory/validate-clock-sidecar.py
models_directory=${QWEN_MODELS_DIRECTORY:-"$qwen_home_models"}
radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
# The production submission profile `radv-low-priority-env.sh` names
# `low-async`: it exports `GGML_VK_MAX_NODES_PER_SUBMIT=16` alone, leaving
# `GGML_VK_SERIALIZE_SUBMISSIONS` absent rather than zero, and it carries the
# same `GGML_VK_LOW_PRIORITY=1` global-priority opt-in every named profile
# exports there. A ladder arm launches its server directly rather than through
# that script, so the three names are stated here instead of inherited.
vulkan_profile=low-async
vulkan_low_priority=1
vulkan_max_nodes_per_submit=16
# Every measurement process on this machine runs at nice 19; the ladder's
# server is no exception, and the value is applied to the backgrounded pid and
# read back from /proc rather than assumed from the caller's own priority.
server_nice_policy=19
server_port=${QWEN_PREFILL_LADDER_PORT:-8098}
appliance_port=${QWEN_SERVER_PORT:-8080}
readiness_seconds=${QWEN_PREFILL_LADDER_READY_SECONDS:-180}
request_seconds=${QWEN_PREFILL_LADDER_REQUEST_SECONDS:-1800}
cooldown_seconds=${QWEN_PREFILL_LADDER_COOLDOWN_S:-15}
depths=${QWEN_PREFILL_LADDER_DEPTHS:-512 4096 16384 32768}
generate_tokens=${QWEN_PREFILL_LADDER_GENERATE:-16}
prefill_threads=${QWEN_PREFILL_LADDER_THREADS:-1}
thread_arms=${QWEN_PREFILL_LADDER_THREAD_ARMS:-1}
tail_reserve=${QWEN_PREFILL_LADDER_TAIL_RESERVE:-32}
prompt_n_slack=${QWEN_PREFILL_LADDER_PROMPT_N_SLACK:-1}
tokenize_attempts=${QWEN_PREFILL_LADDER_ATTEMPTS:-24}
filler_word=${QWEN_PREFILL_LADDER_FILLER:-token}
sampler=${QWEN_PREFILL_LADDER_SAMPLER:-python}
engine_clock_policy=${QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY:-manual}
drm_device=${QWEN_DRM_DEVICE:-/sys/class/drm/card1/device}
sclk_band=${QWEN_CENSUS_SCLK_BAND:-0.06}
sidecar_period_ms=${QWEN_CENSUS_SIDECAR_PERIOD_MS:-20}
sidecar_tolerance=${QWEN_CENSUS_SIDECAR_TOLERANCE:-0.25}
sidecar_cost_ns=${QWEN_CENSUS_SIDECAR_COST_NS:-1000000}
sidecar_max_lost_fraction=${QWEN_CENSUS_SIDECAR_MAX_LOST:-0.03}
sidecar_cpu=${QWEN_CENSUS_SIDECAR_CPU:-0,1}
# Every measurement process on this machine runs at nice 19, the server
# included, so the sampler takes that priority as an absolute.
sidecar_nice=19

positive_integer() {
    case $2 in
        '' | *[!0-9]* | 0 | 0*)
            printf '%s is a canonical positive integer: %s\n' "$1" "$2" >&2
            exit 2
            ;;
    esac
}
nonnegative_integer() {
    case $2 in
        0) return 0 ;;
        '' | *[!0-9]* | 0*)
            printf '%s is a canonical nonnegative integer: %s\n' "$1" "$2" >&2
            exit 2
            ;;
    esac
}
positive_integer QWEN_PREFILL_LADDER_GENERATE "$generate_tokens"
positive_integer QWEN_PREFILL_LADDER_THREADS "$prefill_threads"
positive_integer QWEN_PREFILL_LADDER_ATTEMPTS "$tokenize_attempts"
positive_integer QWEN_PREFILL_LADDER_PORT "$server_port"
nonnegative_integer QWEN_PREFILL_LADDER_TAIL_RESERVE "$tail_reserve"
nonnegative_integer QWEN_PREFILL_LADDER_PROMPT_N_SLACK "$prompt_n_slack"
case $thread_arms in
    0 | 1) ;;
    *)
        printf 'QWEN_PREFILL_LADDER_THREAD_ARMS is 0 or 1: %s\n' "$thread_arms" >&2
        exit 2
        ;;
esac
case $sampler in
    python | off) ;;
    *)
        printf 'QWEN_PREFILL_LADDER_SAMPLER is python or off: %s\n' "$sampler" >&2
        exit 2
        ;;
esac
case $engine_clock_policy in
    manual | auto) ;;
    *)
        printf 'QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY is manual or auto: %s\n' \
            "$engine_clock_policy" >&2
        exit 2
        ;;
esac
# The filler is repeated into every prompt the ladder builds, so it stays one
# whitespace-free word: a value carrying a space changes how many words a
# requested count produces and leaves the length loop adjusting the wrong unit.
case $filler_word in
    '' | *[!A-Za-z0-9_-]*)
        printf 'QWEN_PREFILL_LADDER_FILLER is one word of letters, digits, underscore, or dash: %s\n' \
            "$filler_word" >&2
        exit 2
        ;;
esac
for depth in $depths; do
    positive_integer QWEN_PREFILL_LADDER_DEPTHS "$depth"
done
if [ -z "$depths" ]; then
    printf 'QWEN_PREFILL_LADDER_DEPTHS names at least one depth\n' >&2
    exit 2
fi
# The band reaches the summarizer as a float, so a value at or above one holds
# every pair of clocks in one state and retires the comparison it names.
if ! awk -v band="$sclk_band" 'BEGIN {
    exit (band ~ /^[0-9]+(\.[0-9]+)?$/ && band + 0 < 1) ? 0 : 1 }'; then
    printf 'QWEN_CENSUS_SCLK_BAND is a relative distance in [0, 1): %s\n' \
        "$sclk_band" >&2
    exit 2
fi

for server in "$control_server" "$candidate_server"; do
    if [ ! -x "$server" ]; then
        printf 'server is not executable: %s\n' "$server" >&2
        exit 2
    fi
done
for reader in "$summarizer" "$sidecar" "$sidecar_validator"; do
    if [ ! -r "$reader" ]; then
        printf 'reader is absent: %s\n' "$reader" >&2
        exit 2
    fi
done
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1; then
    printf 'llama-server is running; run %s after qwen-teardown.sh\n' "$0" >&2
    exit 2
fi
for port in "$appliance_port" "$server_port"; do
    if curl --silent --fail --max-time 2 "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
        printf 'a server answers /health on port %s\n' "$port" >&2
        exit 2
    fi
done
case $output_directory in
    /*) ;;
    *)
        printf 'output directory must be absolute: %s\n' "$output_directory" >&2
        exit 2
        ;;
esac
if [ -e "$output_directory" ]; then
    printf 'output directory must be absent; a ladder never appends to one: %s\n' \
        "$output_directory" >&2
    exit 2
fi

registry_field() {
    "$registry_script" id "$1" "$2"
}
"$registry_script" id "$model_id" >/dev/null
model_file=$(registry_field "$model_id" model_file)
model_path=$models_directory/$model_file
model_batch=$(registry_field "$model_id" batch)
model_ubatch=$(registry_field "$model_id" ubatch)
model_cache_k=$(registry_field "$model_id" cache_type_k)
model_cache_v=$(registry_field "$model_id" cache_type_v)
model_flash_attention=$(registry_field "$model_id" flash_attention)
model_context_ceiling=$(registry_field "$model_id" context_ceiling)
model_validated_depth=$(registry_field "$model_id" validated_filled_depth)
if [ ! -r "$model_path" ]; then
    printf 'model is unreadable: %s\n' "$model_path" >&2
    exit 2
fi
# A row whose deepest measured fill is `-` states that no depth has been filled
# and decoded on it, so every rung of the ladder would be a depth no run has
# proven the allocation executes at.
positive_integer validated_filled_depth "$model_validated_depth"
positive_integer context_ceiling "$model_context_ceiling"
# The allocation is one size for the whole ladder, so a rung changes the prompt
# and leaves the KV reservation alone. The deepest measured fill bounds it,
# because the ceiling alone states an allocation the policy admits rather than
# one a run has filled and decoded.
model_context=$model_validated_depth
if [ "$model_context" -gt "$model_context_ceiling" ]; then
    model_context=$model_context_ceiling
fi

# `threads` belongs to the measured arm rather than to the checkpoint, so it is
# read from remote/validated-tuples.tsv at this row's own depth, submission
# geometry, and cache triple. Exactly one validated row states it; zero leaves
# the thread quadruple with no registry value to compare against and two state
# two, so each refuses ahead of the first server start.
row_threads=-
if [ "$thread_arms" = 1 ]; then
    tuple_rows=$("$registry_script" tuples "$model_id") || {
        printf 'the validated tuple ledger names no row for %s; the thread quadruple reads its thread count there\n' \
            "$model_id" >&2
        exit 2
    }
    row_threads=$(printf '%s\n' "$tuple_rows" | awk -F'\t' \
        -v depth="$model_validated_depth" -v batch="$model_batch" \
        -v ubatch="$model_ubatch" -v cache_k="$model_cache_k" \
        -v cache_v="$model_cache_v" -v flash="$model_flash_attention" '
        $4 == depth && $5 == batch && $6 == ubatch && $7 == cache_k \
            && $8 == cache_v && $9 == flash && $14 == "validated" {
            count++; value = $10 }
        END { if (count != 1) exit 1; print value }') || {
        printf 'the validated tuple ledger holds other than one validated row for %s at depth %s geometry %s/%s cache %s/%s flash %s\n' \
            "$model_id" "$model_validated_depth" "$model_batch" "$model_ubatch" \
            "$model_cache_k" "$model_cache_v" "$model_flash_attention" >&2
        exit 2
    }
    positive_integer 'the validated tuple row threads' "$row_threads"
    if [ "$row_threads" = "$prefill_threads" ]; then
        printf 'the thread quadruple compares two thread counts and the registry row names %s, which is the prefill count\n' \
            "$row_threads" >&2
        exit 2
    fi
fi

# Every rung is admitted, clamped, or refused before any server starts, so the
# plan the ledger records is the plan that ran.
admitted_depths=''
admitted_sources=''
skipped_depths=''
skip_reasons=''
# The BOS token /completion prepends is the served prompt-count overshoot
# QWEN_PREFILL_LADDER_PROMPT_N_SLACK admits above the tokenized count, so a
# depth admitted at the ceiling before this term still had room for that
# overshoot; subtracting it here is what keeps prompt_n + generate_tokens
# inside model_context even at the slack's own worst case.
prompt_ceiling=$((model_context - generate_tokens - tail_reserve - prompt_n_slack))
for depth in $depths; do
    if [ "$depth" -gt "$model_validated_depth" ]; then
        skipped_depths="$skipped_depths $depth"
        skip_reasons="$skip_reasons $depth=above_validated_filled_depth"
        continue
    fi
    admitted_depth=$depth
    if [ "$depth" -gt "$prompt_ceiling" ]; then
        # A prompt filling its own allocation evicts rather than decodes, so a
        # requested depth beyond the allocation's own headroom clamps to the
        # deepest prompt the allocation can still decode from, and the arm
        # carries that count as its own identity rather than the requested
        # label. A ceiling with no positive room at all leaves nothing to
        # clamp into.
        if [ "$prompt_ceiling" -lt 1 ]; then
            skipped_depths="$skipped_depths $depth"
            skip_reasons="$skip_reasons $depth=insufficient_generation_headroom"
            continue
        fi
        admitted_depth=$prompt_ceiling
    fi
    # Two requested depths that clamp to the same count would share one ledger
    # identity and collapse into one row set, so the collision is refused ahead
    # of the first server start rather than silently merging two rungs.
    for existing_admitted_depth in $admitted_depths; do
        if [ "$existing_admitted_depth" = "$admitted_depth" ]; then
            printf 'requested depth %s clamps to %s, which a shallower requested depth already admitted; QWEN_PREFILL_LADDER_DEPTHS names two rungs that would share one identity\n' \
                "$depth" "$admitted_depth" >&2
            exit 2
        fi
    done
    admitted_depths="$admitted_depths $admitted_depth"
    admitted_sources="$admitted_sources $depth=$admitted_depth"
done
admitted_depths=${admitted_depths# }
admitted_sources=${admitted_sources# }
skipped_depths=${skipped_depths# }
skip_reasons=${skip_reasons# }

arm_order='C K K C'
[ "$thread_arms" = 0 ] || arm_order='C K K C / C T T C'

control_server_sha256=$(sha256sum "$control_server" | cut -d ' ' -f 1)
candidate_server_sha256=$(sha256sum "$candidate_server" | cut -d ' ' -f 1)
model_sha256=$(sha256sum "$model_path" | cut -d ' ' -f 1)
model_bytes=$(wc -c <"$model_path" | tr -d ' ')

if [ "${QWEN_PREFILL_LADDER_PRINT_PLAN:-0}" = 1 ]; then
    printf 'prefill_ladder_depths_requested\t%s\n' "$depths"
    printf 'prefill_ladder_depths_admitted\t%s\n' "${admitted_depths:--}"
    printf 'prefill_ladder_depths_admitted_requested_actual\t%s\n' "${admitted_sources:--}"
    printf 'prefill_ladder_depths_skipped\t%s\n' "${skipped_depths:--}"
    printf 'prefill_ladder_skip_reasons\t%s\n' "${skip_reasons:--}"
    printf 'prefill_ladder_prompt_ceiling\t%s\n' "$prompt_ceiling"
    printf 'prefill_ladder_arm_order\t%s\n' "$arm_order"
    printf 'prefill_ladder_context\t%s\n' "$model_context"
    printf 'prefill_ladder_threads\t%s\n' "$prefill_threads"
    printf 'prefill_ladder_row_threads\t%s\n' "$row_threads"
    printf 'control_server_sha256\t%s\n' "$control_server_sha256"
    printf 'candidate_server_sha256\t%s\n' "$candidate_server_sha256"
    printf 'model_sha256\t%s\n' "$model_sha256"
    exit 0
fi

# The campaign owns the device from here. The lease is taken ahead of the first
# DPM write rather than at the first arm, because the write moves the clock
# every workload on this machine runs at and a request admitted between a
# process reading and that write would land inside the rate this ledger claims.
# The arms launch directly rather than through qwen-capacity-policy.sh, so no
# child reads the lock and no external-lease proof is published. This is also
# the first of the still-refusable preflights, and the output directory is not
# created until the last of them succeeds -- see the comment at that mkdir.
workload_lease_state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
workload_lease=$workload_lease_state_directory/vulkan-workload.lock
census_workload_lease_take "$workload_lease"
printf 'prefill_ladder_lease=held path=%s\n' "$workload_lease"

server_pid=''
sidecar_pid=''
stop_server() {
    [ -n "$server_pid" ] || return 0
    kill "$server_pid" 2>/dev/null || true
    stop_iteration=0
    while [ "$stop_iteration" -lt 60 ] && kill -0 "$server_pid" 2>/dev/null; do
        stop_iteration=$((stop_iteration + 1))
        sleep 1
    done
    kill -9 "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=''
}
stop_sidecar() {
    [ -n "$sidecar_pid" ] || return 0
    kill -TERM "$sidecar_pid" 2>/dev/null || true
    # wait's own exit status carries the reaped job's signal-terminated status,
    # which || true already absorbs; the explicit set +e/-e bracket matches the
    # per-arm reap below and removes any doubt that a later shell reinterprets
    # a guarded wait under set -e differently mid-trap.
    set +e
    wait "$sidecar_pid" 2>/dev/null
    set -e
    sidecar_pid=''
}

# The device transition runs last among the preflights, so a run that could
# never measure leaves the governor where it found it. The snapshot is taken and
# the restore armed before the write, and cleanup_children replaces those traps
# rather than adding a second restore path.
engine_clock_snapshot=-
engine_clock_sclk_level=-
engine_clock_mclk_level=-
engine_clock_required_sclk_mhz=-
engine_clock_required_mclk_mhz=-
engine_clock_required_flag=''
engine_clock_mclk_flag=''
engine_clock_mclk_fraction_flag=''
engine_clock_below_mclk_floor_fraction=-
# The appliance's own governor under `auto`; the manual branch below overwrites
# this with the confirmed sclk/mclk selections once it has them, so the value
# never names a state this run did not measure.
operating_point=governor
sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-100}
cleanup_children() {
    stop_sidecar
    stop_server
    if [ "$engine_clock_policy" != auto ] && [ "$engine_clock_snapshot" != - ]; then
        census_engine_clock_restore "$drm_device" "$engine_clock_snapshot"
    fi
}
trap cleanup_children EXIT
trap 'cleanup_children; trap - EXIT; exit 143' TERM
trap 'cleanup_children; trap - EXIT; exit 130' INT
trap 'cleanup_children; trap - EXIT; exit 129' HUP

if [ "$engine_clock_policy" != auto ]; then
    # The stall bound follows the policy: 250 ms under a forced level, where the
    # firmware holds one state and the samples at both edges bracket the gap, so
    # coverage alone decides.
    sidecar_max_gap_ms=${QWEN_CENSUS_SIDECAR_MAX_GAP_MS:-250}
    engine_clock_sclk_path=$drm_device/pp_dpm_sclk
    engine_clock_mclk_path=$drm_device/pp_dpm_mclk
    for engine_clock_table in "$engine_clock_sclk_path" "$engine_clock_mclk_path"; do
        if [ ! -r "$engine_clock_table" ]; then
            printf 'the manual engine clock policy reads %s\n' "$engine_clock_table" >&2
            exit 2
        fi
    done
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
        printf 'pp_dpm_sclk lists no level %s: %s\n' "$engine_clock_sclk_level" \
            "$engine_clock_sclk_path" >&2
        exit 2
    }
    # The fabric selection is written and read back rather than required: the
    # firmware answers a 1067 MHz hard minimum with 933 on this device, so the
    # floor below is what the invariant holds and the write is an observation.
    engine_clock_mclk_level=${QWEN_CENSUS_MCLK_LEVEL:-}
    if [ -z "$engine_clock_mclk_level" ]; then
        engine_clock_mclk_level=$(census_engine_clock_highest_level \
            "$engine_clock_mclk_path") || {
            printf 'pp_dpm_mclk lists no fabric clock level: %s\n' \
                "$engine_clock_mclk_path" >&2
            exit 2
        }
    fi
    engine_clock_required_mclk_mhz=${QWEN_CENSUS_MCLK_FLOOR_MHZ:-933}
    positive_integer QWEN_CENSUS_MCLK_FLOOR_MHZ "$engine_clock_required_mclk_mhz"
    engine_clock_below_mclk_floor_fraction=${QWEN_CENSUS_MCLK_BELOW_FRACTION:-0.01}
    engine_clock_required_flag=$engine_clock_required_sclk_mhz
    engine_clock_mclk_flag=$engine_clock_required_mclk_mhz
    engine_clock_mclk_fraction_flag=$engine_clock_below_mclk_floor_fraction
    census_engine_clock_require_sudo
    engine_clock_snapshot=$(census_engine_clock_snapshot "$drm_device") || exit 2
    census_engine_clock_write_level manual "$drm_device"
    engine_clock_sclk_readback=$(census_engine_clock_select pp_dpm_sclk "$drm_device" \
        "$engine_clock_sclk_level" 1)
    engine_clock_mclk_readback=$(census_engine_clock_select pp_dpm_mclk "$drm_device" \
        "$engine_clock_mclk_level" 0)
    census_engine_clock_confirm "$drm_device" "$engine_clock_required_sclk_mhz"
    # census_engine_clock_select prints exactly one `INDEX MHZ` line, so the
    # field after the space is the confirmed megahertz value the device
    # actually selected, not the level index or the requested target; a
    # hard-coded label would keep naming 1100/933 even where a different
    # level, a different device, or a moved firmware minimum selected
    # something else.
    engine_clock_sclk_readback_mhz=${engine_clock_sclk_readback#* }
    engine_clock_mclk_readback_mhz=${engine_clock_mclk_readback#* }
    operating_point="manual-sclk${engine_clock_sclk_readback_mhz}-mclk${engine_clock_mclk_readback_mhz}"
    printf 'prefill_ladder_clock=pinned operating_point=%s sclk=%s mclk=%s\n' \
        "$operating_point" "$engine_clock_sclk_readback" "$engine_clock_mclk_readback"
fi
sidecar_max_gap_ns=$((sidecar_max_gap_ms * 1000000))

# The SMU10 kernel path reports the fabric clock through pp_dpm_mclk and leaves
# pp_dpm_fclk empty, so a column the kernel empties at campaign start is allowed
# to read unavailable and an absent or unreadable attribute is a different
# telemetry state.
sidecar_allowed_unavailable=''
if [ "$sampler" = python ]; then
    fclk_path=$drm_device/pp_dpm_fclk
    if [ -r "$fclk_path" ] && [ ! -s "$fclk_path" ]; then
        sidecar_allowed_unavailable=pp_dpm_fclk_surface_mhz
    fi
fi

# The directory is created only once every preflight that can still refuse --
# the lease, and under `manual` the DPM reads, the sudo cache, and the
# selected-level confirmation -- has succeeded, since any of those exits the
# whole script before an arm ever runs and an empty directory left behind
# would fail the "must be absent" check above on a corrected replay against
# the same requested path.
umask 077
mkdir -p "$output_directory"
output_directory=$(CDPATH='' cd -- "$output_directory" && pwd)

prompt_builder=$output_directory/build-prompt.py
cat >"$prompt_builder" <<'PYTHON'
"""Build a prompt of exactly the requested token count against the served route.

The filler word is repeated and the count adjusted by the difference `/tokenize`
reports, which converges in one step wherever the tokenizer maps the filler onto
a fixed number of tokens and is bounded by an attempt count otherwise: a
tokenizer that merges across the space boundary oscillates rather than settling,
and an exhausted budget is `prompt_length_unconverged` rather than a prompt of
some other length.
"""
import json
import sys
import urllib.request

origin, filler, target, attempts, destination = sys.argv[1:6]
target, attempts = int(target), int(attempts)


def tokenize(text):
    body = json.dumps({"content": text}).encode()
    request = urllib.request.Request(
        f"{origin}/tokenize", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=600) as response:
        payload = json.loads(response.read().decode())
    tokens = payload.get("tokens")
    if not isinstance(tokens, list):
        sys.stderr.write("tokenize_reply_without_tokens\n")
        raise SystemExit(1)
    return len(tokens)


words = target
seen = set()
for attempt in range(1, attempts + 1):
    if words < 1:
        words = 1
    text = " ".join([filler] * words)
    count = tokenize(text)
    if count == target:
        with open(destination, "w", encoding="utf-8") as handle:
            handle.write(text)
        print(f"tokenize_n={count}")
        print(f"words={words}")
        print(f"attempts={attempt}")
        raise SystemExit(0)
    if words in seen:
        break
    seen.add(words)
    words += target - count
sys.stderr.write("prompt_length_unconverged\n")
raise SystemExit(1)
PYTHON

request_client=$output_directory/request-arm.py
cat >"$request_client" <<'PYTHON'
"""Post one streamed completion and report its first-token latency and timings.

Time to first token is the wall time from the instant the request leaves this
process to the first streamed chunk carrying non-empty content, measured on
CLOCK_MONOTONIC. It holds the HTTP round trip and the first sampling pass beside
the prefill, which is what a client observes; `timings.prompt_ms` beside it is
the server's own instrument over the same fill.

Every timing the ledger states is required. A reply whose `timings` object omits
one, or states it as something other than a finite number, ends this reader with
`missing_timings` rather than a zero, since a rate of nothing pairs as a
measurement.

A finite value is not by itself a measurement: `prompt_n` and `predicted_n` are
counts, so a non-integer value is `timings_noninteger`, and every count and rate
is required positive, so a zero or negative one is `timings_nonpositive` --
`prompt_per_second: 0` and a negative `prompt_ms` are what this rejects. A
decode spanning more than one token is required to have taken measurable time,
so `predicted_ms` is nonpositive there too. `predicted_n` is further required to
equal the `n_predict` this request asked for, as `predicted_n_mismatch`, since a
server that decoded a different count answered a different request than the one
the ladder posted.
"""
import json
import math
import sys
import time
import urllib.request

origin, prompt_path, predict, deadline_s, destination = sys.argv[1:6]
with open(prompt_path, encoding="utf-8") as handle:
    prompt_text = handle.read()
body = json.dumps({
    "prompt": prompt_text,
    "n_predict": int(predict),
    "temperature": 0,
    "top_k": 1,
    "seed": 1,
    "ignore_eos": True,
    "cache_prompt": False,
    "stream": True,
}).encode()
request = urllib.request.Request(
    f"{origin}/completion", data=body,
    headers={"Content-Type": "application/json"})

first_token_ns = None
final = None
started_ns = time.monotonic_ns()
with urllib.request.urlopen(request, timeout=float(deadline_s)) as response:
    for raw in response:
        line = raw.decode("utf-8", "replace").strip()
        if not line.startswith("data:"):
            continue
        payload = line[len("data:"):].strip()
        if payload == "[DONE]":
            continue
        chunk = json.loads(payload)
        if first_token_ns is None and chunk.get("content"):
            first_token_ns = time.monotonic_ns()
        if chunk.get("stop"):
            final = chunk
completed_ns = time.monotonic_ns()
if first_token_ns is None:
    sys.stderr.write("no_content_delta\n")
    raise SystemExit(1)
if final is None:
    sys.stderr.write("no_final_chunk\n")
    raise SystemExit(1)
timings = final.get("timings")
if not isinstance(timings, dict):
    sys.stderr.write("missing_timings\n")
    raise SystemExit(1)
required = ("prompt_n", "prompt_ms", "prompt_per_second",
            "predicted_n", "predicted_ms", "predicted_per_second")
count_fields = ("prompt_n", "predicted_n")
positive_fields = ("prompt_n", "prompt_ms", "prompt_per_second",
                   "predicted_n", "predicted_per_second")
values = {}
for name in required:
    value = timings.get(name)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        sys.stderr.write(f"missing_timings field={name}\n")
        raise SystemExit(1)
    value = float(value)
    if not math.isfinite(value):
        sys.stderr.write(f"missing_timings field={name}\n")
        raise SystemExit(1)
    if name in positive_fields and value <= 0:
        sys.stderr.write(f"timings_nonpositive field={name} value={value:.6g}\n")
        raise SystemExit(1)
    if name in count_fields and not value.is_integer():
        sys.stderr.write(f"timings_noninteger field={name} value={value:.6g}\n")
        raise SystemExit(1)
    values[name] = value
if values["predicted_n"] > 1 and values["predicted_ms"] <= 0:
    sys.stderr.write(
        f"timings_nonpositive field=predicted_ms value={values['predicted_ms']:.6g}\n")
    raise SystemExit(1)
requested_predict = int(predict)
if int(values["predicted_n"]) != requested_predict:
    sys.stderr.write(
        f"predicted_n_mismatch requested={requested_predict}"
        f" reported={int(values['predicted_n'])}\n")
    raise SystemExit(1)
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(final, handle)
print(f"ttft_ms={(first_token_ns - started_ns) / 1e6:.3f}")
print(f"wall_ms={(completed_ns - started_ns) / 1e6:.3f}")
print(f"window_begin_ns={started_ns}")
print(f"window_end_ns={completed_ns}")
for name in required:
    print(f"{name}={values[name]:.6g}")
PYTHON

tokenize_client=$output_directory/tokenize-prompt.py
cat >"$tokenize_client" <<'PYTHON'
"""Report how many tokens the served route makes of one prompt file."""
import json
import sys
import urllib.request

origin, prompt_path = sys.argv[1:3]
with open(prompt_path, encoding="utf-8") as handle:
    text = handle.read()
request = urllib.request.Request(
    f"{origin}/tokenize", data=json.dumps({"content": text}).encode(),
    headers={"Content-Type": "application/json"})
with urllib.request.urlopen(request, timeout=600) as response:
    payload = json.loads(response.read().decode())
tokens = payload.get("tokens")
if not isinstance(tokens, list):
    sys.stderr.write("tokenize_reply_without_tokens\n")
    raise SystemExit(1)
print(len(tokens))
PYTHON

# One measured field of the reader's own `name=value` record.
measurement_field() {
    awk -F= -v key="$2" '$1 == key { print $2; exit }' "$1"
}

arms_ledger=$output_directory/arms.tsv
printf 'slot\tdepth\tquadruple\tarm\treplicate\tserver_role\tserver_sha256\tthreads\tbatch\tubatch\tserver_nice\tprompt_target\ttokenize_n\tprompt_n\tttft_ms\tprompt_ms\tprompt_tok_s\tpredicted_n\tdecode_tok_s\tsclk_mode_mhz\tclock_invariant\tstatus\treason\n' \
    >"$arms_ledger"

{
    printf 'control_server\t%s\ncontrol_server_sha256\t%s\n' "$control_server" \
        "$control_server_sha256"
    printf 'candidate_server\t%s\ncandidate_server_sha256\t%s\n' "$candidate_server" \
        "$candidate_server_sha256"
    printf 'model_id\t%s\nmodel_path\t%s\nmodel_sha256\t%s\nmodel_bytes\t%s\n' \
        "$model_id" "$model_path" "$model_sha256" "$model_bytes"
    printf 'context\t%s\nbatch\t%s\nubatch\t%s\ncache_k\t%s\ncache_v\t%s\nflash_attention\t%s\n' \
        "$model_context" "$model_batch" "$model_ubatch" "$model_cache_k" \
        "$model_cache_v" "$model_flash_attention"
    printf 'context_ceiling\t%s\nvalidated_filled_depth\t%s\nprompt_ceiling\t%s\n' \
        "$model_context_ceiling" "$model_validated_depth" "$prompt_ceiling"
    printf 'depths_requested\t%s\ndepths_admitted\t%s\ndepths_skipped\t%s\nskip_reasons\t%s\n' \
        "$depths" "${admitted_depths:--}" "${skipped_depths:--}" "${skip_reasons:--}"
    printf 'depths_admitted_requested_actual\t%s\n' "${admitted_sources:--}"
    printf 'arm_order\t%s\ngenerate_tokens\t%s\nprefill_threads\t%s\nrow_threads\t%s\n' \
        "$arm_order" "$generate_tokens" "$prefill_threads" "$row_threads"
    printf 'tail_reserve\t%s\nprompt_n_slack\t%s\ntokenize_attempts\t%s\nfiller_word\t%s\n' \
        "$tail_reserve" "$prompt_n_slack" "$tokenize_attempts" "$filler_word"
    printf 'engine_clock_policy\t%s\noperating_point\t%s\n' "$engine_clock_policy" \
        "$operating_point"
    printf 'engine_clock_sclk_level\t%s\nengine_clock_mclk_level\t%s\n' \
        "$engine_clock_sclk_level" "$engine_clock_mclk_level"
    printf 'engine_clock_required_sclk_mhz\t%s\nengine_clock_required_mclk_mhz\t%s\n' \
        "$engine_clock_required_sclk_mhz" "$engine_clock_required_mclk_mhz"
    printf 'engine_clock_below_mclk_floor_fraction\t%s\n' \
        "$engine_clock_below_mclk_floor_fraction"
    printf 'sampler\t%s\nsidecar_period_ms\t%s\nsidecar_cpu\t%s\nsidecar_nice\t%s\n' \
        "$sampler" "$sidecar_period_ms" "$sidecar_cpu" "$sidecar_nice"
    printf 'sidecar_max_gap_ns\t%s\nsidecar_max_lost_fraction\t%s\nsclk_band\t%s\n' \
        "$sidecar_max_gap_ns" "$sidecar_max_lost_fraction" "$sclk_band"
    printf 'workload_lease\t%s\narm_environment_record\tarms/SLOT/arm-environment.tsv\n' \
        "$workload_lease"
    printf 'radv_icd\t%s\nserver_port\t%s\n' "$radv_icd" "$server_port"
    printf 'vulkan_profile\t%s\nvulkan_low_priority\t%s\nvulkan_max_nodes_per_submit\t%s\n' \
        "$vulkan_profile" "$vulkan_low_priority" "$vulkan_max_nodes_per_submit"
    printf 'server_nice_policy\t%s\n' "$server_nice_policy"
} >"$output_directory/inputs.tsv"

start_server() {
    start_server_path=$1
    start_server_log=$2
    start_server_expected_sha256=$3
    start_server_threads=$4
    start_server_environment=$5
    # Reset on every call, since a caller reads this after the function returns
    # and a path that returns ahead of the exec below must not carry a prior
    # arm's applied nice forward as this one's own.
    start_server_nice=-
    # The ladder spans many model loads and both server paths stay writable
    # throughout, so the digest inputs.tsv records is re-read against the file
    # about to be executed rather than assumed to still describe it.
    start_server_observed=$(sha256sum "$start_server_path" | cut -d ' ' -f 1)
    if [ "$start_server_observed" != "$start_server_expected_sha256" ]; then
        printf 'server changed under %s: recorded=%s observed=%s\n' \
            "$start_server_path" "$start_server_expected_sha256" \
            "$start_server_observed" >&2
        return 1
    fi
    # Linux niceness is per thread, assigned at clone() time from the creating
    # thread's own value, so a renice applied to the backgrounded pid from this
    # shell races every thread the server spawns before that renice call
    # actually runs: a thread created in that window keeps the caller's
    # ordinary priority regardless of what the pid's own value becomes a
    # moment later. The exec chain is where the fix belongs instead: the
    # sealed command is a small self-renicing shell rather than the server
    # binary directly, so the pid carries nice 19 -- set absolutely by
    # `renice -n 19 -p $$` on itself, the way radv-low-priority-env.sh renices
    # itself before its own exec -- before any of the exec calls below even
    # begin, and therefore before the server has run one instruction of its
    # own or spawned a single thread.
    census_arm_exec "$start_server_environment" \
        VK_DRIVER_FILES="$radv_icd" VK_ICD_FILENAMES="$radv_icd" \
        LLAMA_NO_CPU_FALLBACK=1 \
        GGML_VK_LOW_PRIORITY="$vulkan_low_priority" \
        GGML_VK_MAX_NODES_PER_SUBMIT="$vulkan_max_nodes_per_submit" \
        QWEN_VULKAN_PROFILE="$vulkan_profile" \
        -- \
        sh -c 'nice_level=$1; shift
            if ! renice -n "$nice_level" -p $$ >/dev/null 2>&1; then
                printf "nice %s was refused for pid %s\n" "$nice_level" "$$" >&2
                exit 97
            fi
            exec "$@"' sh "$server_nice_policy" \
        "$start_server_path" \
        --model "$model_path" \
        --host 127.0.0.1 \
        --port "$server_port" \
        --ctx-size "$model_context" \
        --batch-size "$model_batch" \
        --ubatch-size "$model_ubatch" \
        --cache-type-k "$model_cache_k" \
        --cache-type-v "$model_cache_v" \
        --flash-attn "$model_flash_attention" \
        --device Vulkan0 \
        --split-mode none \
        --override-tensor '.*=Vulkan0' \
        --fit off \
        --n-gpu-layers all \
        --parallel 1 \
        --threads "$start_server_threads" \
        --threads-batch "$start_server_threads" \
        --no-context-shift \
        --offline \
        --log-verbosity 4 \
        >"$start_server_log" 2>&1 &
    server_pid=$!
    start_server_iteration=0
    while [ "$start_server_iteration" -lt "$readiness_seconds" ]; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            printf 'llama-server exited before readiness; see %s\n' "$start_server_log" >&2
            return 1
        fi
        if curl --silent --fail --max-time 2 "http://127.0.0.1:$server_port/health" \
            >/dev/null 2>&1; then
            # The self-renice above ran within the process's first instructions,
            # long before health ever answers, so a mismatch here is the policy
            # failing rather than a race with it: the read-back is what turns
            # "applied" into "proven" ahead of recording the arm.
            start_server_nice=$(sed 's/^.*) //' "/proc/$server_pid/stat" 2>/dev/null \
                | awk '{ print $17 }') || start_server_nice=
            if [ "$start_server_nice" != "$server_nice_policy" ]; then
                printf 'nice read back from /proc/%s/stat is %s where the policy requires %s\n' \
                    "$server_pid" "${start_server_nice:-absent}" "$server_nice_policy" >&2
                start_server_nice=-
                return 1
            fi
            for placement_line in 'Vulkan0 model buffer size' 'Vulkan0 KV buffer size' \
                'Vulkan0 compute buffer size'; do
                if ! grep -qE "$placement_line" "$start_server_log"; then
                    printf 'placement=rejected missing=%s log=%s\n' "$placement_line" \
                        "$start_server_log" >&2
                    return 1
                fi
            done
            return 0
        fi
        start_server_iteration=$((start_server_iteration + 1))
        sleep 1
    done
    printf 'llama-server stayed unready for %s seconds; see %s\n' "$readiness_seconds" \
        "$start_server_log" >&2
    return 1
}

# slot depth quadruple arm replicate server_role server_sha256 threads batch
# ubatch server_nice prompt_target tokenize_n prompt_n ttft_ms prompt_ms
# prompt_tok_s predicted_n decode_tok_s sclk_mode_mhz clock_invariant status
# reason
#
# batch and ubatch are the registry row's own values, one pair for the whole
# ladder rather than one pair per depth: the allocation is one context size
# for the whole run, so a rung changes the prompt and leaves the submission
# geometry alone the way it leaves the KV reservation alone. Carrying the pair
# on every row, rather than in inputs.tsv alone, is what lets
# summarize-prefill-ladder.py's --batch-ubatch-table read one self-contained
# row per depth without a second file.
record_arm() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" \
        "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" "${19}" "${20}" "${21}" \
        "${22}" "${23}" \
        >>"$arms_ledger"
}

slot=0
arm_failures=0
for depth in $skipped_depths; do
    skip_reason=$(printf '%s\n' "$skip_reasons" | tr ' ' '\n' \
        | awk -F= -v depth="$depth" '$1 == depth { print $2; exit }')
    for quadruple in binary threads; do
        [ "$quadruple" != threads ] || [ "$thread_arms" = 1 ] || continue
        slot=$((slot + 1))
        record_arm "$slot" "$depth" "$quadruple" - - - - - "$model_batch" \
            "$model_ubatch" - "$depth" - - - - - - - - - skipped "$skip_reason"
    done
    printf 'prefill_ladder_depth=skipped depth=%s reason=%s\n' "$depth" "$skip_reason"
done

for depth in $admitted_depths; do
    depth_directory=$output_directory/depths/$depth
    mkdir -p "$depth_directory"
    prompt_path=$depth_directory/prompt.txt
    depth_tokenize_n=-
    for quadruple in binary threads; do
        [ "$quadruple" != threads ] || [ "$thread_arms" = 1 ] || continue
        case $quadruple in
            binary) quadruple_arms='C K K C' ;;
            *) quadruple_arms='C T T C' ;;
        esac
        control_replicate=0
        subject_replicate=0
        for arm in $quadruple_arms; do
            slot=$((slot + 1))
            case $arm in
                C)
                    control_replicate=$((control_replicate + 1))
                    replicate=$control_replicate
                    arm_server=$control_server
                    arm_server_sha256=$control_server_sha256
                    arm_role=control
                    arm_threads=$prefill_threads
                    ;;
                K)
                    subject_replicate=$((subject_replicate + 1))
                    replicate=$subject_replicate
                    arm_server=$candidate_server
                    arm_server_sha256=$candidate_server_sha256
                    arm_role=candidate
                    arm_threads=$prefill_threads
                    ;;
                *)
                    subject_replicate=$((subject_replicate + 1))
                    replicate=$subject_replicate
                    arm_server=$control_server
                    arm_server_sha256=$control_server_sha256
                    arm_role=control
                    arm_threads=$row_threads
                    ;;
            esac
            arm_directory=$output_directory/arms/$slot-$depth-$quadruple-$arm
            mkdir -p "$arm_directory"
            status=completed
            reason=-
            tokenize_n=-
            prompt_n=-
            ttft_ms=-
            prompt_ms=-
            prompt_tok_s=-
            predicted_n=-
            decode_tok_s=-
            sclk_mode_mhz=-
            clock_invariant=-
            arm_server_nice=-
            window_begin=''
            window_end=''
            printf 'prefill_ladder_arm=start slot=%s depth=%s quadruple=%s arm=%s threads=%s\n' \
                "$slot" "$depth" "$quadruple" "$arm" "$arm_threads"
            if ! start_server "$arm_server" "$arm_directory/server.log" \
                "$arm_server_sha256" "$arm_threads" \
                "$arm_directory/arm-environment.tsv"; then
                status=failed
                reason=server_start
            fi
            arm_server_nice=$start_server_nice
            if [ "$status" = completed ] && [ "$sampler" = python ]; then
                python3 "$sidecar" "$arm_directory/clock-sidecar.tsv" \
                    --period-ms "$sidecar_period_ms" --cpu "$sidecar_cpu" \
                    --nice "$sidecar_nice" --drm-device "$drm_device" \
                    2>"$arm_directory/clock-sidecar.stderr" &
                sidecar_pid=$!
            fi
            if [ "$status" = completed ] && [ ! -s "$prompt_path" ]; then
                # The prompt is built once per depth against the first server
                # that answers there and reused by every later arm, so each arm
                # of a pair fills the same bytes and the tokenized count is a
                # property of the depth rather than of the arm.
                set +e
                prompt_build=$(python3 "$prompt_builder" \
                    "http://127.0.0.1:$server_port" "$filler_word" "$depth" \
                    "$tokenize_attempts" "$prompt_path" \
                    2>"$arm_directory/build-prompt.stderr")
                prompt_build_status=$?
                set -e
                if [ "$prompt_build_status" -ne 0 ]; then
                    status=failed
                    reason=$(awk 'NR == 1 { print $1 }' \
                        "$arm_directory/build-prompt.stderr")
                    [ -n "$reason" ] || reason=prompt_build
                    rm -f -- "$prompt_path"
                else
                    printf '%s\n' "$prompt_build" >"$depth_directory/prompt-build.txt"
                    depth_tokenize_n=$(measurement_field \
                        "$depth_directory/prompt-build.txt" tokenize_n)
                    sha256sum "$prompt_path" | cut -d ' ' -f 1 \
                        >"$depth_directory/prompt.sha256"
                fi
            fi
            if [ "$status" = completed ]; then
                # Every arm re-tokenizes the same prompt bytes on its own
                # server, so a tokenizer that answers this depth differently
                # between two binaries refuses the arm rather than pairing two
                # prompt lengths under one label.
                set +e
                arm_tokenize=$(python3 "$tokenize_client" \
                    "http://127.0.0.1:$server_port" "$prompt_path" \
                    2>"$arm_directory/tokenize.stderr")
                arm_tokenize_status=$?
                set -e
                if [ "$arm_tokenize_status" -ne 0 ]; then
                    status=failed
                    reason=tokenize_failed
                elif [ "$arm_tokenize" != "$depth_tokenize_n" ] \
                    || [ "$arm_tokenize" != "$depth" ]; then
                    status=failed
                    reason=tokenize_mismatch
                    tokenize_n=$arm_tokenize
                else
                    tokenize_n=$arm_tokenize
                fi
            fi
            if [ "$status" = completed ]; then
                set +e
                arm_reply=$(python3 "$request_client" \
                    "http://127.0.0.1:$server_port" "$prompt_path" \
                    "$generate_tokens" "$request_seconds" \
                    "$arm_directory/final-chunk.json" \
                    2>"$arm_directory/request.stderr")
                arm_reply_status=$?
                set -e
                if [ "$arm_reply_status" -ne 0 ]; then
                    status=failed
                    reason=$(awk 'NR == 1 { print $1 }' "$arm_directory/request.stderr")
                    [ -n "$reason" ] || reason=request_failed
                else
                    arm_measurement=$arm_directory/measurement.txt
                    printf '%s\n' "$arm_reply" >"$arm_measurement"
                    ttft_ms=$(measurement_field "$arm_measurement" ttft_ms)
                    prompt_n=$(measurement_field "$arm_measurement" prompt_n)
                    prompt_ms=$(measurement_field "$arm_measurement" prompt_ms)
                    prompt_tok_s=$(measurement_field "$arm_measurement" prompt_per_second)
                    predicted_n=$(measurement_field "$arm_measurement" predicted_n)
                    decode_tok_s=$(measurement_field "$arm_measurement" predicted_per_second)
                    window_begin=$(measurement_field "$arm_measurement" window_begin_ns)
                    window_end=$(measurement_field "$arm_measurement" window_end_ns)
                    # `/tokenize` reports the text alone where a completion
                    # request prepends the beginning-of-sequence token, so the
                    # served count is required to sit within the declared slack
                    # above the tokenized count and never below it.
                    if ! awk -v served="$prompt_n" -v tokenized="$tokenize_n" \
                        -v slack="$prompt_n_slack" 'BEGIN {
                        exit (served + 0 >= tokenized + 0 \
                            && served + 0 <= tokenized + slack) ? 0 : 1 }'; then
                        status=failed
                        reason=prompt_n_mismatch
                    fi
                fi
            fi
            sidecar_status=-
            if [ -n "$sidecar_pid" ]; then
                kill -TERM "$sidecar_pid" 2>/dev/null || true
                set +e
                wait "$sidecar_pid"
                sidecar_status=$?
                set -e
                sidecar_pid=''
            fi
            stop_server
            if [ "$sidecar_status" != - ]; then
                # The clock record is evidence only where the validator accepts
                # it: exit status, sample count, achieved period, sensors
                # present, and the request window covered.
                set +e
                python3 "$sidecar_validator" "$arm_directory/clock-sidecar.tsv" \
                    --sidecar-status "$sidecar_status" \
                    --period-ms "$sidecar_period_ms" \
                    --period-tolerance "$sidecar_tolerance" \
                    --cost-bound-ns "$sidecar_cost_ns" \
                    --max-gap-ns "$sidecar_max_gap_ns" \
                    --max-lost-fraction "$sidecar_max_lost_fraction" \
                    ${window_begin:+--window-begin-ns "$window_begin"} \
                    ${window_end:+--window-end-ns "$window_end"} \
                    ${sidecar_allowed_unavailable:+--allow-unavailable "$sidecar_allowed_unavailable"} \
                    ${engine_clock_required_flag:+--required-sclk-mhz "$engine_clock_required_flag"} \
                    ${engine_clock_mclk_flag:+--required-mclk-mhz "$engine_clock_mclk_flag"} \
                    ${engine_clock_mclk_fraction_flag:+--max-below-mclk-floor-fraction "$engine_clock_mclk_fraction_flag"} \
                    --expected-nice "$sidecar_nice" --expected-cpu-affinity "$sidecar_cpu" \
                    >"$arm_directory/clock-sidecar-verdict.txt" 2>&1
                sidecar_verdict=$?
                set -e
                clock_invariant=$(awk '/^clock_invariant=/ {
                    sub(/^clock_invariant=/, "", $1); print $1; exit }' \
                    "$arm_directory/clock-sidecar-verdict.txt")
                case $clock_invariant in
                    held | violated) ;;
                    *) clock_invariant=- ;;
                esac
                sclk_mode_mhz=$(awk '/^clock_state=measured / {
                    for (i = 1; i <= NF; i++)
                        if (index($i, "sclk_mode_mhz=") == 1) print substr($i, 15)
                    exit }' "$arm_directory/clock-sidecar-verdict.txt")
                [ -n "$sclk_mode_mhz" ] || sclk_mode_mhz=-
                if [ "$sidecar_verdict" -ne 0 ] && [ "$status" = completed ]; then
                    status=failed
                    reason=clock_sidecar
                    [ "$clock_invariant" != violated ] || reason=clock_invariant
                fi
            fi
            [ "$status" = completed ] || arm_failures=$((arm_failures + 1))
            record_arm "$slot" "$depth" "$quadruple" "$arm" "$replicate" "$arm_role" \
                "$arm_server_sha256" "$arm_threads" "$model_batch" "$model_ubatch" \
                "$arm_server_nice" "$depth" \
                "$tokenize_n" "$prompt_n" "$ttft_ms" "$prompt_ms" "$prompt_tok_s" \
                "$predicted_n" "$decode_tok_s" "$sclk_mode_mhz" "$clock_invariant" \
                "$status" "$reason"
            printf 'prefill_ladder_arm=%s slot=%s depth=%s quadruple=%s arm=%s ttft_ms=%s prompt_tok_s=%s clock_invariant=%s reason=%s\n' \
                "$status" "$slot" "$depth" "$quadruple" "$arm" "$ttft_ms" \
                "$prompt_tok_s" "$clock_invariant" "$reason"
            [ "$cooldown_seconds" -le 0 ] || sleep "$cooldown_seconds"
        done
    done
done

python3 "$summarizer" "$arms_ledger" --sclk-band "$sclk_band" \
    --batch-ubatch-table "$output_directory/batch-ubatch-recommendation.tsv" \
    >"$output_directory/summary.tsv"
count_words() {
    set -- $1
    printf '%s\n' "$#"
}
admitted_count=$(count_words "$admitted_depths")
skipped_count=$(count_words "$skipped_depths")
ladder_state=completed
[ "$arm_failures" -eq 0 ] || ladder_state=failed
printf 'prefill_ladder=%s admitted_depths=%s skipped_depths=%s failed_arms=%s output=%s\n' \
    "$ladder_state" "$admitted_count" "$skipped_count" "$arm_failures" \
    "$output_directory"
# A skipped depth is inadmissible rather than failed, so it leaves the status at
# zero; an admitted depth whose arm did not complete is what makes the ladder
# non-zero.
[ "$arm_failures" -eq 0 ]
