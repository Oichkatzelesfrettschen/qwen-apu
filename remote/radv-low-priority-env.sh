#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    printf 'usage: %s COMMAND [ARG ...]\n' "$0" >&2
    exit 2
fi

renice -n 19 -p $$ >/dev/null
# Inference holds one core and the desktop keeps the other. Which core is
# measurable rather than obvious: /proc/interrupts puts the keyboard, touchpad,
# and GPIO controller entirely on CPU0, and amdgpu's own completion interrupts
# three-to-one on CPU1. Input latency and GPU-completion latency therefore pull
# in opposite directions, and QWEN_INFERENCE_CPU lets the probe decide.
inference_cpu=${QWEN_INFERENCE_CPU:-0}
taskset -pc "$inference_cpu" $$ >/dev/null
ionice -c 3 -p $$

radv_icd=${QWEN_RADV_ICD:-/usr/share/vulkan/icd.d/radeon_icd.x86_64.json}
if [ ! -r "$radv_icd" ]; then
    printf 'RADV ICD is not readable: %s\n' "$radv_icd" >&2
    exit 1
fi

# The unset block below scrubs the ambient environment so a named profile
# always means one thing. Two profiles read a caller-supplied value past that
# scrub and these copies are what survive it for them: `custom` varies the
# submission settings one at a time, and `diagnostic` carries the instrument
# inputs a serving profile refuses. The four serving profiles read none of
# them.
requested_max_nodes_per_submit=${GGML_VK_MAX_NODES_PER_SUBMIT:-}
requested_serialize_submissions=${GGML_VK_SERIALIZE_SUBMISSIONS:-}
requested_allow_graphics_queue=${GGML_VK_ALLOW_GRAPHICS_QUEUE:-}
requested_submit_trace=${GGML_VK_SUBMIT_TRACE:-}
# The int24 candidate's admission variable survives the scrub for the
# diagnostic profile, which is the one profile that restores it.
requested_force_integer_dot=${GGML_VK_FORCE_INTEGER_DOT:-}
# The scrub leaves QWEN_ names alone, so this copy carries the diagnostic
# profile's frequency input in the same form as the GGML_VK_ copies beside it;
# the value reaches the profile case either way.
requested_qwen_perf_logger=${QWEN_PERF_LOGGER:-}

unset DISPLAY
unset WAYLAND_DISPLAY
unset QWEN_ONE_CORE_ACTIVE
unset QWEN_GUARD_CPU_ACTIVE
unset AMD_PRIORITY
unset AMD_DEBUG
unset DRI_PRIME
unset MESA_VK_DEVICE_SELECT
unset RADV_DEBUG
unset RADV_PERFTEST
unset VK_ADD_LAYER_PATH
unset VK_INSTANCE_LAYERS
unset VK_LAYER_PATH
unset VK_LOADER_LAYERS_ENABLE
unset GGML_VK_ALLOW_GRAPHICS_QUEUE
unset GGML_VK_ALLOW_SYSMEM_FALLBACK
unset GGML_VK_ASYNC_USE_TRANSFER_QUEUE
unset GGML_VK_DEBUG_MARKERS
unset GGML_VK_DISABLE_ASYNC
unset GGML_VK_DISABLE_BFLOAT16
unset GGML_VK_DISABLE_COOPMAT
unset GGML_VK_DISABLE_COOPMAT2
unset GGML_VK_DISABLE_COOPMAT2_DECODE_VECTOR
unset GGML_VK_DISABLE_DOT2
unset GGML_VK_DISABLE_F16
unset GGML_VK_DISABLE_FUSION
unset GGML_VK_DISABLE_GRAPH_OPTIMIZE
unset GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM
unset GGML_VK_DISABLE_INTEGER_DOT_PRODUCT
unset GGML_VK_DISABLE_MMVQ
unset GGML_VK_DISABLE_MULTI_ADD
unset GGML_VK_DISABLE_OCP_FP4
unset GGML_VK_DUTY_CYCLE_PERCENT
unset GGML_VK_ENABLE_MEMORY_PRIORITY
unset GGML_VK_FORCE_INTEGER_DOT
unset GGML_VK_FORCE_MAX_ALLOCATION_SIZE
unset GGML_VK_FORCE_MAX_BUFFER_SIZE
unset GGML_VK_FORCE_MMVQ
unset GGML_VK_MEMORY_LOGGER
unset GGML_VK_SERIALIZE_SUBMISSIONS
unset GGML_VK_MAX_NODES_PER_SUBMIT
unset GGML_VK_PERF_LOGGER
unset GGML_VK_PERF_LOGGER_CONCURRENT
unset GGML_VK_PERF_LOGGER_FREQUENCY
unset GGML_VK_PIPELINE_STATS
unset GGML_VK_PIPELINE_CENSUS
# The census patch reads GGML_VK_PIPELINE_CENSUS_DUMP as the directory it
# writes module bytes into, so an ambient value redirects the census build's
# own output and the name belongs in the scrub beside the toggle it
# accompanies. The pinned commit reads neither name.
unset GGML_VK_PIPELINE_CENSUS_DUMP
unset GGML_VK_PREFER_HOST_MEMORY
# The Q4_K activation sideplane candidate gates its feature and its reuse log
# on getenv() returning a pointer rather than on the value, so an ambient
# GGML_VK_Q4K_SIDEPLANE=0 enables the pre-pass a control arm is defined by
# leaving off. Both names belong in the scrub for that reason; the pinned
# commit reads neither.
unset GGML_VK_Q4K_SIDEPLANE
unset GGML_VK_Q4K_SIDEPLANE_LOG
# The Q4_K variant-select candidate reads GGML_VK_Q4K_VARIANT at pipeline
# creation and ends the load on a value outside its admitted set, so an ambient
# name decides which mat-vec a launch serves or refuses the launch outright.
# QWEN_Q4K_VARIANT below is the one route past this scrub.
unset GGML_VK_Q4K_VARIANT
unset GGML_VK_SUBALLOCATION_BLOCK_SIZE
unset GGML_VK_SUBMIT_TRACE
unset GGML_VK_SYNC_LOGGER
unset GGML_VK_VISIBLE_DEVICES

export VK_DRIVER_FILES="$radv_icd"
export VK_ICD_FILENAMES="$radv_icd"
export GGML_VK_LOW_PRIORITY=1
export LLAMA_NO_CPU_FALLBACK=1

vulkan_profile=${QWEN_VULKAN_PROFILE:-low-serialized}
# A serving profile measures a rate the appliance actually serves, and the perf
# logger puts a host wait behind every graph, so the two are separate arms. The
# check names the four serving profiles rather than negating diagnostic, which
# leaves an unrecognized name to the `unknown Vulkan profile` refusal below.
case $vulkan_profile in
    paced-60 | low-serialized | low-async | custom)
        if [ -n "$requested_qwen_perf_logger" ]; then
            printf 'QWEN_PERF_LOGGER belongs to the diagnostic profile alone\n' >&2
            exit 2
        fi
        ;;
esac
case $vulkan_profile in
    paced-60)
        export GGML_VK_DUTY_CYCLE_PERCENT=60
        export GGML_VK_SERIALIZE_SUBMISSIONS=1
        export GGML_VK_MAX_NODES_PER_SUBMIT=32
        ;;
    low-serialized)
        export GGML_VK_SERIALIZE_SUBMISSIONS=1
        export GGML_VK_MAX_NODES_PER_SUBMIT=32
        ;;
    low-async)
        export GGML_VK_MAX_NODES_PER_SUBMIT=16
        ;;
    diagnostic)
        # The serialized attribution arm of the pipeline census: every node
        # runs behind a barrier and every graph ends in a host wait, which is
        # the shape the pinned perf logger imposes, so the profile fixes
        # serialization and states its whole diagnostic environment here.
        # QWEN_PERF_LOGGER carries the logger's frequency as one positive
        # integer and is the profile's required input, so the arm's environment
        # follows from the profile name and that one number. The five unsets
        # below repeat names the scrub already removed, which keeps the
        # profile readable as one closed declaration rather than as a
        # difference against the scrub list. It serves nothing on the LAN:
        # qwen-webui-control.sh admits it behind an explicit QWEN_LLAMA_SERVER
        # and a loopback listener, and the census runner is its other caller.
        case $requested_qwen_perf_logger in
            *[!0-9]* | '' | 0*)
                printf 'the diagnostic profile requires QWEN_PERF_LOGGER as a positive decimal frequency: %s\n' \
                    "$requested_qwen_perf_logger" >&2
                exit 2
                ;;
        esac
        export GGML_VK_SERIALIZE_SUBMISSIONS=1
        export GGML_VK_MAX_NODES_PER_SUBMIT=32
        export GGML_VK_PERF_LOGGER=1
        export GGML_VK_PERF_LOGGER_FREQUENCY=$requested_qwen_perf_logger
        unset GGML_VK_PERF_LOGGER_CONCURRENT
        unset GGML_VK_PIPELINE_STATS
        unset GGML_VK_MEMORY_LOGGER
        unset GGML_VK_SUBMIT_TRACE
        unset RADV_DEBUG
        # The int24 candidate build compiles the q8_1 mat-vec pipelines and
        # admits them only under GGML_VK_FORCE_INTEGER_DOT, so one binary
        # carries the arm and its control and this restore is what separates
        # them. The diagnostic profile is the one profile that carries it: the
        # four serving profiles leave it scrubbed beside the sideplane names,
        # which keeps a promoted build on the FP16 mat-vec whatever the ambient
        # environment holds, and an arm is asked for by naming this profile.
        # ggml_vk_force_integer_dot() compares the value against "1", so a
        # third value would run the control while the caller named the arm, and
        # the profile refuses it the way it refuses a malformed frequency.
        case $requested_force_integer_dot in
            '')
                ;;
            1)
                export GGML_VK_FORCE_INTEGER_DOT=$requested_force_integer_dot
                ;;
            *)
                printf 'GGML_VK_FORCE_INTEGER_DOT admits 1 or an unset value: %s\n' \
                    "$requested_force_integer_dot" >&2
                exit 2
                ;;
        esac
        ;;
    custom)
        # The named profiles fix both submission settings together, which makes
        # them useless for measuring either one alone. `custom` restores only
        # what the caller asked for, so a sweep can vary node count and
        # serialization independently and attribute the result.
        if [ -n "$requested_max_nodes_per_submit" ]; then
            export GGML_VK_MAX_NODES_PER_SUBMIT=$requested_max_nodes_per_submit
        fi
        if [ -n "$requested_serialize_submissions" ]; then
            export GGML_VK_SERIALIZE_SUBMISSIONS=$requested_serialize_submissions
        fi
        if [ -n "$requested_allow_graphics_queue" ]; then
            export GGML_VK_ALLOW_GRAPHICS_QUEUE=$requested_allow_graphics_queue
        fi
        if [ -n "$requested_submit_trace" ]; then
            export GGML_VK_SUBMIT_TRACE=$requested_submit_trace
        fi
        ;;
    *)
        printf 'unknown Vulkan profile: %s\n' "$vulkan_profile" >&2
        exit 2
        ;;
esac
export QWEN_VULKAN_PROFILE=$vulkan_profile
# The asynchronous census arm runs under a serving profile's own submission
# shape, so the collection toggle crosses the scrub under a QWEN_ name and
# reaches the server as GGML_VK_PIPELINE_CENSUS. Only the census build reads
# it; the promoted build carries no reader, and that build is never bundled.
if [ -n "${QWEN_PIPELINE_CENSUS:-}" ]; then
    export GGML_VK_PIPELINE_CENSUS=$QWEN_PIPELINE_CENSUS
fi
# The Q4_K variant arm runs under the serving profile the comparison is read at,
# since the whole point of one executable carrying every formulation is that the
# arm changes the pipeline and nothing else; the key therefore crosses the scrub
# under a QWEN_ name the way the census toggle does rather than belonging to one
# profile. The admitted set is stated here as well as at pipeline creation
# because a value the server refuses is a launch that reaches the device and
# ends there, where this refusal names the input while the argv is still
# readable. Only the variant-select candidate build reads the exported name; a
# promoted build carries no reader and is never bundled with one.
if [ -n "${QWEN_Q4K_VARIANT:-}" ]; then
    case $QWEN_Q4K_VARIANT in
        e4/2 | e4/4 | e4/8 | e4-scale/2 | e4-scale/4 | e4-scale/8 | \
        e4-scale-licm/2 | e4-scale-licm/4 | e4-scale-licm/8)
            export GGML_VK_Q4K_VARIANT=$QWEN_Q4K_VARIANT
            ;;
        *)
            printf 'QWEN_Q4K_VARIANT is e4, e4-scale, or e4-scale-licm over /2, /4, or /8: %s\n' \
                "$QWEN_Q4K_VARIANT" >&2
            exit 2
            ;;
    esac
fi

exec "$@"
