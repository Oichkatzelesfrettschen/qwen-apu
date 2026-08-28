#!/bin/sh
set -eu

# Separate the compute-ring wedge at 16384 tokens into depth and submission
# geometry, and record what each arm did to the device.
#
# llama-bench prefills a depth rung with its own batch defaults. The guarded
# server runs `--batch-size 128 --ubatch-size 32`, which breaks the same prefill
# into submissions two orders of magnitude smaller, and that pacing is the
# reason those settings exist. Both wedges this tree has recorded were found
# under llama-bench at its defaults, so depth and submission size are confounded
# and neither has been separated from the other.
#
# Three geometries per depth resolve the direction. The harness default
# establishes that the wedge reproduces. The served geometry decides whether the
# shipped configuration is exposed. A geometry below the served one decides
# which way to move if it is: a pass there attributes the wedge to submission
# size and leaves depth viable, while a wedge there indicts the graph at that
# depth under every practical geometry and the admitted ceiling comes down.
#
# A configured context allocation is not a validated depth. A server that loads
# a 24576-token allocation has proven it can reserve the memory; it has not
# proven a near-full cache executes. What this probe measures is the filled and
# decoded depth, which is the capability the registry ceiling claims.
#
# Each arm ends with a shallow control at the served geometry. A ring reset that
# recovers leaves the control passing, and the wedge is one rejected graph; a
# control that fails establishes persistent device corruption instead, and the
# probe stops rather than measuring a broken device.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s MODEL_PATH [OUTPUT_DIRECTORY]\n' "$0" >&2
    printf 'depths from QWEN_WEDGE_DEPTHS, default "8192 16384"\n' >&2
    printf 'geometries from QWEN_WEDGE_GEOMETRIES as batch:ubatch pairs,\n' >&2
    printf 'default "2048:512 128:32 32:8"\n' >&2
    printf 'QWEN_WEDGE_ARM_TIMEOUT_S overrides the per-invocation SIGTERM\n' >&2
    printf 'limit, default 120 + depth/4 seconds; QWEN_WEDGE_ARM_KILL_AFTER_S\n' >&2
    printf 'overrides the SIGKILL grace period after it, default 30\n' >&2
    exit 2
fi

model_path=$1
output_directory=${2:-"${HOME:?}/qwen-depth-wedge"}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bench=${QWEN_LLAMA_BENCH:-"${HOME:?}/src/llama.cpp-qwen-apu/build-qwen-vulkan/bin/llama-bench"}
clock_sampler=${QWEN_CLOCK_SAMPLER:-"$script_directory/sample-gpu-clocks.sh"}
depths=${QWEN_WEDGE_DEPTHS:-"8192 16384"}
geometries=${QWEN_WEDGE_GEOMETRIES:-"2048:512 128:32 32:8"}
cache_type_k=${QWEN_CACHE_TYPE_K:-q8_0}
cache_type_v=${QWEN_CACHE_TYPE_V:-q4_0}
flash_attention=${QWEN_FLASH_ATTN:-on}
control_tokens=${QWEN_WEDGE_CONTROL_TOKENS:-16}
# A depth listed here stops after its geometries have all passed with healthy
# controls, leaving the remaining ones unrun. At 8192 the harness-default and
# served geometries bracket the deployed configuration, so a third arm below
# them validates a depth already validated and discriminates none of the 16384
# failure mechanisms. A depth absent from this list runs every geometry, which
# is what the 16384 matrix requires of its reduced-geometry arm.
conditional_depths=${QWEN_WEDGE_CONDITIONAL_DEPTHS:-8192}
# A wedge parks llama-bench in the driver rather than returning an error, so
# nothing but an external timeout ends it. QWEN_WEDGE_ARM_TIMEOUT_S overrides
# the per-invocation limit; its default scales with the prefill depth passed
# to that invocation, 120 seconds plus one second per four depth tokens, which
# covers this device's measured prefill and the fixed-length decode with
# margin while still bounding a hang. QWEN_WEDGE_ARM_KILL_AFTER_S is the grace
# period between the SIGTERM `timeout` sends at the limit and the SIGKILL it
# escalates to if the process ignores it; `timeout` reports its own exit
# status (124 on a plain timeout, 128+signal after a kill-after escalation),
# so a timed-out arm reads as a failure distinguishable from a bench failure
# by that status alone.
arm_timeout_kill_after_s=${QWEN_WEDGE_ARM_KILL_AFTER_S:-30}

if [ ! -x "$bench" ] || [ ! -f "$model_path" ]; then
    printf 'llama-bench and the model must both exist\n' >&2
    exit 2
fi
if pgrep -x llama-server >/dev/null 2>&1 ||
   pgrep -x llama-bench >/dev/null 2>&1; then
    printf 'another llama process holds the device\n' >&2
    exit 2
fi

mkdir -p "$output_directory"
summary=$output_directory/wedge-summary.tsv
# health carries the promotion signal a downstream consumer reads instead of
# recomputing arm_status, control_status, ring_resets, and gpu_faults itself.
# `healthy` is a clean arm with a passing control and a kernel delta that
# confirms zero resets and zero faults; `unhealthy` is a failed status, a
# failed control, or a confirmed reset or fault; `unverified` is every other
# case, where dmesg was unavailable or unreadable so the arm's reset and fault
# counts are `unavailable` and a clean run cannot be told apart from a
# recovery this probe did not see. A promotion rule that treats `unverified`
# as `healthy` promotes an arm this probe never confirmed clean.
summary_header='arm	depth	batch	ubatch	cache_k	cache_v	flash_attn	status	ring_resets	gpu_faults	wall_s	decode_tok_s	vram_peak_mib	gtt_peak_mib	control_status	control_tok_s	mclk_modal	temp_c_max	health'
summary_has_arms=0
if [ -s "$summary" ]; then
    if [ "$(sed -n '1p' "$summary")" != "$summary_header" ]; then
        printf 'wedge summary header is incompatible with this harness: %s\n' \
            "$summary" >&2
        exit 2
    fi
    malformed_line=$(awk -F'\t' '
        NR > 1 && (NF != 19 || $1 != "d" $2 "-b" $3 "-ub" $4) {
            print NR
            exit
        }' "$summary")
    if [ -n "$malformed_line" ]; then
        printf 'wedge summary carries a malformed arm row at line %s: %s\n' \
            "$malformed_line" "$summary" >&2
        exit 2
    fi
    duplicate_arm=$(awk -F'\t' 'NR > 1 && seen[$1]++ { print $1; exit }' \
        "$summary")
    if [ -n "$duplicate_arm" ]; then
        printf 'wedge summary carries duplicate arm identity: %s\n' \
            "$duplicate_arm" >&2
        exit 2
    fi
    if ! awk -F'\t' -v cache_k="$cache_type_k" \
        -v cache_v="$cache_type_v" -v flash="$flash_attention" '
        NR > 1 && ($5 != cache_k || $6 != cache_v || $7 != flash) {
            printf "recorded arm %s belongs to cache policy %s/%s/%s, not %s/%s/%s; use a new output directory\n", \
                $1, $5, $6, $7, cache_k, cache_v, flash > "/dev/stderr"
            mismatch = 1
            exit
        }
        END { exit mismatch }
    ' "$summary"; then
        exit 2
    fi
    if awk 'NR > 1 { found = 1; exit } END { exit !found }' "$summary"; then
        summary_has_arms=1
    fi
else
    printf '%s\n' "$summary_header" >"$summary"
fi

# A matching arm label is not a matching measurement when the GGUF or recovery
# control changes. The digest is computed once per invocation, which is small
# beside a filled-depth arm and binds every resumed row to immutable input
# bytes rather than to a reusable path.
metadata=$output_directory/wedge-metadata.tsv
metadata_header='model_sha256	model_bytes	control_tokens'
model_sha256=$(nice -n 19 sha256sum "$model_path")
model_sha256=${model_sha256%% *}
model_bytes=$(stat -c %s -- "$model_path")
metadata_row="$model_sha256	$model_bytes	$control_tokens"
if [ -s "$metadata" ]; then
    if [ "$(sed -n '1p' "$metadata")" != "$metadata_header" ] ||
       [ "$(sed -n '2p' "$metadata")" != "$metadata_row" ] ||
       [ -n "$(sed -n '3p' "$metadata")" ]; then
        printf 'wedge metadata does not match the model or recovery control: %s\n' \
            "$metadata" >&2
        exit 2
    fi
elif [ "$summary_has_arms" -eq 1 ]; then
    printf 'wedge summary has arms but no model identity metadata: %s\n' \
        "$metadata" >&2
    exit 2
else
    printf '%s\n%s\n' "$metadata_header" "$metadata_row" >"$metadata"
fi

# A killed run leaves its sampler writing once a second into a file the next run
# recreates, which contaminates that run and hides the orphan behind a plausible
# name. The trap ends the sampler with the script that started it.
sampler_pid=''
active_arm_label=''
stop_sampler() {
    [ -n "$sampler_pid" ] || return 0
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
    sampler_pid=''
}
interrupt_run() {
    signal_status=$1
    stop_sampler
    if [ -n "$active_arm_label" ]; then
        printf 'arm_abort_utc=%s label=%s status=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$active_arm_label" \
            "$signal_status" >&2
    fi
    printf 'depth_wedge=interrupted status=%s output_directory=%s\n' \
        "$signal_status" "$output_directory" >&2
    exit "$signal_status"
}
trap 'stop_sampler' EXIT
trap 'interrupt_run 129' HUP
trap 'interrupt_run 130' INT
trap 'interrupt_run 143' TERM

kernel_line_count() {
    if dmesg >/dev/null 2>&1; then
        dmesg | wc -l
    else
        printf 'unavailable\n'
    fi
}

# The lines the kernel emitted during one arm, retained verbatim. The ring
# reset count and the fault count are grepped from these rather than from the
# whole buffer, so a reset that predates the probe stays out of the delta.
kernel_delta_lines() {
    delta_before=$1
    delta_file=$2
    rm -f -- "$delta_file"
    [ "$delta_before" != unavailable ] || return 0
    dmesg | tail -n "+$((delta_before + 1))" >"$delta_file" 2>/dev/null || true
}

parse_decode_rate() {
    awk -F'|' '$0 ~ /\| *tg[0-9]+( @ d[0-9]+)? *\|/ {
                   split($(NF - 1), parts, /[^0-9.]+/)
                   for (i = 1; i <= 3; i++) {
                       if (parts[i] != "") { rate = parts[i]; break }
                   }
               }
               END { print (rate == "" ? "n/a" : rate) }' "$1"
}

run_bench() {
    bench_log=$1
    bench_depth=$2
    bench_batch=$3
    bench_ubatch=$4
    bench_tokens=$5
    bench_timeout_s=${QWEN_WEDGE_ARM_TIMEOUT_S:-$((120 + bench_depth / 4))}
    # errexit is the caller's to manage. Restoring it here re-arms it before the
    # return, and a non-zero return then kills the caller on the very failure
    # this probe exists to record: the wedge at 16384 aborted llama-bench, the
    # function returned 134, and the script died without writing the row.
    if [ "$bench_depth" -eq 0 ]; then
        nice -n 19 ionice -c 3 timeout \
            --kill-after="${arm_timeout_kill_after_s}s" "${bench_timeout_s}s" \
            "$bench" -m "$model_path" \
            -ngl 99 -t 2 -r 1 -p 0 -n "$bench_tokens" \
            -b "$bench_batch" -ub "$bench_ubatch" \
            -ctk "$cache_type_k" -ctv "$cache_type_v" -fa "$flash_attention" \
            -o md >"$bench_log" 2>&1
    else
        nice -n 19 ionice -c 3 timeout \
            --kill-after="${arm_timeout_kill_after_s}s" "${bench_timeout_s}s" \
            "$bench" -m "$model_path" \
            -ngl 99 -t 2 -r 1 -p 0 -n "$bench_tokens" -d "$bench_depth" \
            -b "$bench_batch" -ub "$bench_ubatch" \
            -ctk "$cache_type_k" -ctv "$cache_type_v" -fa "$flash_attention" \
            -o md >"$bench_log" 2>&1
    fi
}

device_corrupt=0

run_arm() {
    arm_depth=$1
    arm_batch=$2
    arm_ubatch=$3
    arm_label=d$arm_depth-b$arm_batch-ub$arm_ubatch
    arm_log=$output_directory/$arm_label.log
    arm_samples=$output_directory/$arm_label.clocks.tsv
    arm_kernel=$output_directory/$arm_label.dmesg.txt
    control_log=$output_directory/$arm_label.control.log

    recorded_count=$(awk -F'\t' -v label="$arm_label" \
        'NR > 1 && $1 == label { count++ } END { print count + 0 }' "$summary")
    if [ "$recorded_count" -eq 1 ]; then
        for retained_artifact in "$arm_log" "$arm_samples" "$control_log"; do
            if [ ! -f "$retained_artifact" ]; then
                printf 'recorded arm %s is missing retained artifact: %s\n' \
                    "$arm_label" "$retained_artifact" >&2
                exit 2
            fi
        done
        recorded_status=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $8; exit }' "$summary")
        recorded_resets=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $9; exit }' "$summary")
        recorded_faults=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $10; exit }' "$summary")
        recorded_control_status=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $15; exit }' "$summary")
        recorded_health=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $19; exit }' "$summary")
        recorded_cache_type_k=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $5; exit }' "$summary")
        recorded_cache_type_v=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $6; exit }' "$summary")
        recorded_flash_attention=$(awk -F'\t' -v label="$arm_label" \
            '$1 == label { print $7; exit }' "$summary")
        if [ "$recorded_cache_type_k" != "$cache_type_k" ] ||
           [ "$recorded_cache_type_v" != "$cache_type_v" ] ||
           [ "$recorded_flash_attention" != "$flash_attention" ]; then
            printf 'recorded arm %s belongs to cache policy %s/%s/%s, not %s/%s/%s; use a new output directory\n' \
                "$arm_label" "$recorded_cache_type_k" "$recorded_cache_type_v" \
                "$recorded_flash_attention" "$cache_type_k" "$cache_type_v" \
                "$flash_attention" >&2
            exit 2
        fi
        case $recorded_status in '' | *[!0-9]*)
            printf 'recorded arm %s carries invalid status: %s\n' \
                "$arm_label" "$recorded_status" >&2
            exit 2
            ;;
        esac
        case $recorded_control_status in '' | *[!0-9]*)
            printf 'recorded arm %s carries invalid control status: %s\n' \
                "$arm_label" "$recorded_control_status" >&2
            exit 2
            ;;
        esac
        case $recorded_resets in unavailable | *[!0-9]* | '')
            [ "$recorded_resets" = unavailable ] || {
                printf 'recorded arm %s carries invalid reset count: %s\n' \
                    "$arm_label" "$recorded_resets" >&2
                exit 2
            }
            ;;
        esac
        case $recorded_faults in unavailable | *[!0-9]* | '')
            [ "$recorded_faults" = unavailable ] || {
                printf 'recorded arm %s carries invalid fault count: %s\n' \
                    "$arm_label" "$recorded_faults" >&2
                exit 2
            }
            ;;
        esac
        if [ "$recorded_resets" = unavailable ] ||
           [ "$recorded_faults" = unavailable ]; then
            if [ "$recorded_resets" != unavailable ] ||
               [ "$recorded_faults" != unavailable ] ||
               [ -e "$arm_kernel" ]; then
                printf 'recorded arm %s carries inconsistent kernel-delta evidence\n' \
                    "$arm_label" >&2
                exit 2
            fi
        elif [ ! -f "$arm_kernel" ]; then
            printf 'recorded arm %s is missing retained artifact: %s\n' \
                "$arm_label" "$arm_kernel" >&2
            exit 2
        fi
        case $recorded_health in
            healthy | unhealthy | unverified) ;;
            *)
                printf 'recorded arm %s carries invalid health: %s\n' \
                    "$arm_label" "$recorded_health" >&2
                exit 2
                ;;
        esac
        expected_health=unhealthy
        if [ "$recorded_status" -eq 0 ] && [ "$recorded_control_status" -eq 0 ]; then
            if [ "$recorded_resets" = unavailable ] ||
               [ "$recorded_faults" = unavailable ]; then
                expected_health=unverified
            elif [ "$recorded_resets" -eq 0 ] && [ "$recorded_faults" -eq 0 ]; then
                expected_health=healthy
            fi
        fi
        if [ "$recorded_health" != "$expected_health" ]; then
            printf 'recorded arm %s carries health %s inconsistent with its status, control, resets, and faults (expected %s)\n' \
                "$arm_label" "$recorded_health" "$expected_health" >&2
            exit 2
        fi
        arm_healthy=0
        [ "$recorded_health" != healthy ] || arm_healthy=1
        if [ "$recorded_control_status" -ne 0 ]; then
            device_corrupt=1
        fi
        printf 'arm_resume_skip label=%s status=%s resets=%s control=%s health=%s\n' \
            "$arm_label" "$recorded_status" "$recorded_resets" \
            "$recorded_control_status" "$recorded_health"
        return 0
    fi
    for incomplete_artifact in "$arm_log" "$arm_samples" "$control_log"; do
        if [ -e "$incomplete_artifact" ]; then
            printf 'unrecorded arm %s has incomplete artifact; use a new output directory: %s\n' \
                "$arm_label" "$incomplete_artifact" >&2
            exit 2
        fi
    done

    active_arm_label=$arm_label
    kernel_before=$(kernel_line_count)
    arm_started=$(date +%s)

    printf 'arm_start_utc=%s label=%s cache=%s/%s fa=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$cache_type_k" \
        "$cache_type_v" "$flash_attention"
    "$clock_sampler" "$arm_samples" &
    sampler_pid=$!
    set +e
    run_bench "$arm_log" "$arm_depth" "$arm_batch" "$arm_ubatch" 32
    arm_status=$?
    set -e
    stop_sampler
    arm_wall=$(($(date +%s) - arm_started))
    kernel_delta_lines "$kernel_before" "$arm_kernel"

    resets=unavailable
    faults=unavailable
    if [ -f "$arm_kernel" ]; then
        resets=$(grep -c 'ring reset\|Ring .* reset\|device wedged\|GPU reset' \
            "$arm_kernel" || true)
        faults=$(grep -c 'page fault\|VM_L2_PROTECTION_FAULT\|PROTECTION_FAULT' \
            "$arm_kernel" || true)
    fi

    decode=n/a
    [ "$arm_status" -ne 0 ] || decode=$(parse_decode_rate "$arm_log")
    if [ "$arm_status" -eq 0 ] && [ "$decode" = n/a ]; then
        arm_status=65
    fi

    # The memory the arm actually held, read from amdgpu's accounting during the
    # arm rather than parsed from the log: llama-bench prints no buffer sizes at
    # default verbosity, and an arm that wedges prints nothing at all. The peak
    # of each is reported because the KV cache grows through the prefill.
    # The sampler is killed as soon as the arm ends, so an arm that completes
    # before the sampler writes its first row leaves no file at all and awk
    # exits fatal under set -e. This probe reports `unavailable` for every other
    # absent device reading, and an absent sampler file is the same fact: it
    # exists to find a wedge rather than to compare rates, so a missing covariate
    # names itself instead of ending the sweep.
    arm_samples_present=1
    [ -s "$arm_samples" ] || arm_samples_present=0

    if [ "$arm_samples_present" -eq 0 ]; then
        memory_report=$(printf 'unavailable\tunavailable')
    else
    memory_report=$(awk -F'\t' '
        $5 ~ /^[0-9]+$/ {
          if ($5 + 0 > vram_peak) { vram_peak = $5 + 0 }
          vram_samples++
        }
        $6 ~ /^[0-9]+$/ {
          if ($6 + 0 > gtt_peak) { gtt_peak = $6 + 0 }
          gtt_samples++
        }
        END {
            printf "%s\t%s",
                (vram_samples ? sprintf("%.0f", vram_peak / 1048576) : "unavailable"),
                (gtt_samples ? sprintf("%.0f", gtt_peak / 1048576) : "unavailable")
        }' "$arm_samples")
    fi

    # A ring reset needs the device quiet to finish recovering; the control
    # starting into a recovering device measures the recovery rather than the
    # device.
    if [ "$resets" != unavailable ] && [ "$resets" -gt 0 ]; then
        printf 'recovery_pause_utc=%s seconds=60 resets=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$resets"
        sleep 60
    fi

    set +e
    run_bench "$control_log" 0 128 32 "$control_tokens"
    control_status=$?
    set -e
    control_decode=n/a
    [ "$control_status" -ne 0 ] || control_decode=$(parse_decode_rate "$control_log")
    if [ "$control_status" -eq 0 ] && [ "$control_decode" = n/a ]; then
        control_status=65
    fi

    if [ "$arm_samples_present" -eq 0 ]; then
        clock_report=$(printf 'unavailable\tunavailable')
    else
        clock_report=$(awk -F'\t' '
            $1 ~ /^[0-9]+([.][0-9]+)?$/ { count[$1]++; clock_samples++ }
            $3 ~ /^[0-9]+([.][0-9]+)?$/ {
              if ($3 + 0 > temp_max) { temp_max = $3 + 0 }
              temperature_samples++
            }
            END {
                for (step in count) {
                    if (count[step] > best) { best = count[step]; modal = step }
                }
                printf "%s\t%s", (clock_samples ? modal : "unavailable"),
                    (temperature_samples ? sprintf("%.1f", temp_max / 1000) : "unavailable")
            }' "$arm_samples")
    fi

    # health carries the promotion signal. A fault or reset line without
    # recovery leaves the arm unhealthy regardless of dmesg availability. A
    # clean status and control with dmesg unavailable or unreadable cannot be
    # told apart from a hazard this probe did not see, so it reads
    # `unverified` rather than `healthy`: kernel telemetry unavailable keeps
    # the arm's decode and control results as an exploratory measurement
    # without certifying it clean, and a promotion rule that treats
    # `unverified` as `healthy` promotes an arm this probe never confirmed.
    health=unhealthy
    if [ "$arm_status" -eq 0 ] && [ "$control_status" -eq 0 ]; then
        if [ "$resets" = unavailable ] || [ "$faults" = unavailable ]; then
            health=unverified
        elif [ "$resets" -eq 0 ] && [ "$faults" -eq 0 ]; then
            health=healthy
        fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm_label" "$arm_depth" "$arm_batch" "$arm_ubatch" "$cache_type_k" \
        "$cache_type_v" "$flash_attention" "$arm_status" "$resets" "$faults" \
        "$arm_wall" "$decode" "$memory_report" "$control_status" \
        "$control_decode" "$clock_report" "$health" >>"$summary"
    printf 'arm_stop_utc=%s label=%s status=%s decode=%s resets=%s faults=%s wall_s=%s peak_vram_gtt_mib=%s control=%s control_tok_s=%s health=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$arm_label" "$arm_status" "$decode" \
        "$resets" "$faults" "$arm_wall" \
        "$(printf '%s' "$memory_report" | tr '\t' '/')" "$control_status" \
        "$control_decode" "$health"
    active_arm_label=''

    if [ "$control_status" -ne 0 ]; then
        printf 'control_failed label=%s: the device did not recover, so the remaining arms would measure a corrupt device\n' \
            "$arm_label" >&2
        device_corrupt=1
    fi

    # arm_healthy gates the conditional-depth rescue skip below, and only
    # `healthy` promotes it: `unverified` runs every remaining geometry at
    # this depth exactly as `unhealthy` does, because a confirmed-clean depth
    # is what the rescue skip requires.
    arm_healthy=0
    [ "$health" != healthy ] || arm_healthy=1
}

for depth in $depths; do
    depth_conditional=0
    case " $conditional_depths " in
        *" $depth "*) depth_conditional=1 ;;
    esac
    depth_clean=1
    for geometry in $geometries; do
        [ "$device_corrupt" -eq 0 ] || break
        if [ "$depth_conditional" -eq 1 ] && [ "$depth_clean" -eq 1 ] &&
            [ "$geometry" != "${geometries%% *}" ] &&
            [ "$geometry" = "${geometries##* }" ]; then
            printf 'arm_skipped label=d%s-b%s-ub%s reason=preceding geometries at this depth passed with healthy controls\n' \
                "$depth" "${geometry%%:*}" "${geometry##*:}"
            continue
        fi
        run_arm "$depth" "${geometry%%:*}" "${geometry##*:}"
        [ "$arm_healthy" -eq 1 ] || depth_clean=0
    done
    [ "$device_corrupt" -eq 0 ] || break
done

if [ "$device_corrupt" -ne 0 ]; then
    printf 'depth_wedge=halted output_directory=%s\n' "$output_directory"
    cat "$summary"
    exit 1
fi

printf 'depth_wedge=completed output_directory=%s\n' "$output_directory"
cat "$summary"
