#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
wrapper=$script_directory/radv-low-priority-env.sh

capture_environment() {
    profile=$1
    # The nested shell expands its own runtime environment after the wrapper runs.
    # shellcheck disable=SC2016
    QWEN_VULKAN_PROFILE=$profile AMD_PRIORITY=1023 \
        QWEN_ONE_CORE_ACTIVE=1 QWEN_GUARD_CPU_ACTIVE=1 \
        GGML_VK_ENABLE_MEMORY_PRIORITY=1 GGML_VK_ALLOW_GRAPHICS_QUEUE=1 \
        RADV_PERFTEST=nogttspill \
        GGML_VK_DUTY_CYCLE_PERCENT=99 \
        GGML_VK_SERIALIZE_SUBMISSIONS=unexpected \
        GGML_VK_MAX_NODES_PER_SUBMIT=999 \
        "$wrapper" sh -c '
        printf "affinity=%s\n" "$(awk "/Cpus_allowed_list/ { print \$2 }" /proc/self/status)"
        printf "nice=%s\n" "$(ps -o ni= -p $$ | tr -d " ")"
        printf "io=%s\n" "$(ionice -p $$)"
        printf "profile=%s low=%s duty=%s serialized=%s max_nodes=%s strict=%s\n" \
            "$QWEN_VULKAN_PROFILE" "$GGML_VK_LOW_PRIORITY" \
            "${GGML_VK_DUTY_CYCLE_PERCENT-unset}" \
            "${GGML_VK_SERIALIZE_SUBMISSIONS-unset}" \
            "${GGML_VK_MAX_NODES_PER_SUBMIT-unset}" "$LLAMA_NO_CPU_FALLBACK"
        printf "driver=%s compatibility_driver=%s\n" "$VK_DRIVER_FILES" "$VK_ICD_FILENAMES"
        printf "display=%s wayland=%s sysmem_fallback=%s amd_priority=%s memory_priority=%s allow_graphics=%s radv_perftest=%s\n" \
            "${DISPLAY-unset}" "${WAYLAND_DISPLAY-unset}" \
            "${GGML_VK_ALLOW_SYSMEM_FALLBACK-unset}" "${AMD_PRIORITY-unset}" \
            "${GGML_VK_ENABLE_MEMORY_PRIORITY-unset}" \
            "${GGML_VK_ALLOW_GRAPHICS_QUEUE-unset}" "${RADV_PERFTEST-unset}"
        printf "model_cpu_sentinel=%s guard_cpu_sentinel=%s\n" \
            "${QWEN_ONE_CORE_ACTIVE-unset}" "${QWEN_GUARD_CPU_ACTIVE-unset}"
    '
}

environment_output=$(capture_environment paced-60)

printf '%s\n' "$environment_output"
printf '%s\n' "$environment_output" | grep -F 'affinity=0' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'nice=19' >/dev/null
printf '%s\n' "$environment_output" | grep -F 'io=idle' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'profile=paced-60 low=1 duty=60 serialized=1 max_nodes=32 strict=1' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'display=unset wayland=unset sysmem_fallback=unset amd_priority=unset memory_priority=unset allow_graphics=unset radv_perftest=unset' >/dev/null
printf '%s\n' "$environment_output" | grep -F \
    'model_cpu_sentinel=unset guard_cpu_sentinel=unset' >/dev/null

environment_output=$(capture_environment low-serialized)
printf '%s\n' "$environment_output" | grep -F \
    'profile=low-serialized low=1 duty=unset serialized=1 max_nodes=32 strict=1' >/dev/null

# The diagnostic profile states its whole environment from the profile name
# and QWEN_PERF_LOGGER, so the child's GGML_VK_ set is compared whole against
# the wrapper-wide low-priority flag and the profile's own four exports. The
# ambient logger, statistics, submit-trace, and RADV_DEBUG requests around it
# reach nothing. A serving profile carries the census toggle across the scrub
# under its QWEN_ name and nothing else, so that name is set here to prove the
# diagnostic branch leaves it to the block outside the profile case.
diagnostic_environment=$(GGML_VK_PERF_LOGGER=ambient GGML_VK_PIPELINE_STATS=mul_mat \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 GGML_VK_PERF_LOGGER_FREQUENCY=999 \
    GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 RADV_DEBUG=nohiz \
    QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    GGML_VK_SERIALIZE_SUBMISSIONS=unexpected GGML_VK_MAX_NODES_PER_SUBMIT=999 \
    "$wrapper" sh -c 'env | grep "^GGML_VK_" | sort')
printf '%s\n' "$diagnostic_environment"
diagnostic_expected='GGML_VK_LOW_PRIORITY=1
GGML_VK_MAX_NODES_PER_SUBMIT=32
GGML_VK_PERF_LOGGER=1
GGML_VK_PERF_LOGGER_FREQUENCY=4
GGML_VK_SERIALIZE_SUBMISSIONS=1'
if [ "$diagnostic_environment" != "$diagnostic_expected" ]; then
    printf 'the diagnostic profile exported an environment beyond its declaration\n' >&2
    exit 1
fi
diagnostic_output=$(GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 RADV_DEBUG=nohiz \
    QWEN_PIPELINE_CENSUS=1 QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "profile=%s memory=%s trace=%s concurrent=%s radv=%s census=%s\n" \
        "$QWEN_VULKAN_PROFILE" "${GGML_VK_MEMORY_LOGGER-unset}" \
        "${GGML_VK_SUBMIT_TRACE-unset}" "${GGML_VK_PERF_LOGGER_CONCURRENT-unset}" \
        "${RADV_DEBUG-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$diagnostic_output"
printf '%s\n' "$diagnostic_output" | grep -Fx \
    'profile=diagnostic memory=unset trace=unset concurrent=unset radv=unset census=1' >/dev/null

# The same ambient diagnostic request reaches nothing under a serving profile,
# where the scrub alone answers for it.
serving_ambient_output=$(GGML_VK_MEMORY_LOGGER=1 GGML_VK_SUBMIT_TRACE=1 \
    GGML_VK_PERF_LOGGER_CONCURRENT=1 GGML_VK_PIPELINE_STATS=mul_mat \
    RADV_DEBUG=nohiz QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "memory=%s trace=%s concurrent=%s stats=%s radv=%s\n" \
        "${GGML_VK_MEMORY_LOGGER-unset}" "${GGML_VK_SUBMIT_TRACE-unset}" \
        "${GGML_VK_PERF_LOGGER_CONCURRENT-unset}" "${GGML_VK_PIPELINE_STATS-unset}" \
        "${RADV_DEBUG-unset}"')
printf '%s\n' "$serving_ambient_output" | grep -Fx \
    'memory=unset trace=unset concurrent=unset stats=unset radv=unset' >/dev/null

# The sideplane candidate reads its two names through getenv() != NULL, so the
# value 0 enables the feature and its log where the scrub is what keeps a
# control arm a control. The request carries 0 for that reason.
sideplane_ambient_output=$(GGML_VK_Q4K_SIDEPLANE=0 GGML_VK_Q4K_SIDEPLANE_LOG=0 \
    QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "sideplane=%s sideplane_log=%s\n" \
        "${GGML_VK_Q4K_SIDEPLANE-unset}" "${GGML_VK_Q4K_SIDEPLANE_LOG-unset}"')
printf '%s\n' "$sideplane_ambient_output" | grep -Fx \
    'sideplane=unset sideplane_log=unset' >/dev/null

# QWEN_PERF_LOGGER states the logger's frequency as one positive integer, which
# the diagnostic branch turns into the enable flag and the frequency together.
perf_logger_output=$(QWEN_PERF_LOGGER=1 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "perf=%s frequency=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PERF_LOGGER_FREQUENCY-unset}"')
printf '%s\n' "$perf_logger_output" | grep -Fx 'perf=1 frequency=1' >/dev/null
perf_logger_output=$(QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "perf=%s frequency=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PERF_LOGGER_FREQUENCY-unset}"')
printf '%s\n' "$perf_logger_output" | grep -Fx 'perf=1 frequency=4' >/dev/null
diagnostic_perf_logger_status=0
QWEN_PERF_LOGGER=x QWEN_VULKAN_PROFILE=diagnostic "$wrapper" true \
    >/dev/null 2>/dev/null || diagnostic_perf_logger_status=$?
if [ "$diagnostic_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted a non-integer QWEN_PERF_LOGGER\n' >&2
    exit 1
fi
# The frequency is the profile's only input, so an absent one leaves the arm's
# environment underdetermined and the profile refuses rather than serving a
# logger-free run under the diagnostic name.
absent_perf_logger_status=0
QWEN_VULKAN_PROFILE=diagnostic "$wrapper" true \
    >/dev/null 2>/dev/null || absent_perf_logger_status=$?
if [ "$absent_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted a diagnostic profile without QWEN_PERF_LOGGER\n' >&2
    exit 1
fi
# A serving profile measures a rate the appliance serves, so it refuses the
# logger rather than exporting it.
serving_perf_logger_status=0
serving_perf_logger_error=$(QWEN_PERF_LOGGER=1 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" true 2>&1 >/dev/null) || serving_perf_logger_status=$?
if [ "$serving_perf_logger_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted QWEN_PERF_LOGGER under low-async\n' >&2
    exit 1
fi
printf '%s\n' "$serving_perf_logger_error" | grep -Fx \
    'QWEN_PERF_LOGGER belongs to the diagnostic profile alone' >/dev/null

serving_census_output=$(GGML_VK_PERF_LOGGER=1 GGML_VK_PIPELINE_CENSUS=stale QWEN_PIPELINE_CENSUS=1 \
    QWEN_VULKAN_PROFILE=low-async "$wrapper" sh -c 'printf "perf=%s census=%s\n" \
        "${GGML_VK_PERF_LOGGER-unset}" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_census_output" | grep -Fx 'perf=unset census=1' >/dev/null
serving_plain_output=$(GGML_VK_PIPELINE_CENSUS=stale QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "census=%s\n" "${GGML_VK_PIPELINE_CENSUS-unset}"')
printf '%s\n' "$serving_plain_output" | grep -Fx 'census=unset' >/dev/null

# The Q4_K variant key reaches a serving profile, since the arm and its control
# are two pipelines of one executable and the comparison is read at the profile
# the appliance serves under. An ambient GGML_VK_Q4K_VARIANT is scrubbed on
# every profile and QWEN_Q4K_VARIANT is the one route past that scrub, so a
# stale name cannot decide which mat-vec a launch creates.
for serving_profile in paced-60 low-serialized low-async custom; do
    # The nested shell expands its own runtime environment after the wrapper runs.
    # shellcheck disable=SC2016
    variant_output=$(GGML_VK_Q4K_VARIANT=e4/4 QWEN_Q4K_VARIANT=e4-scale/8 \
        QWEN_VULKAN_PROFILE=$serving_profile \
        "$wrapper" sh -c 'printf "variant=%s\n" "${GGML_VK_Q4K_VARIANT-unset}"')
    if ! printf '%s\n' "$variant_output" | grep -Fx 'variant=e4-scale/8' >/dev/null; then
        printf 'the %s profile did not carry QWEN_Q4K_VARIANT: %s\n' \
            "$serving_profile" "$variant_output" >&2
        exit 1
    fi
done
# shellcheck disable=SC2016
variant_ambient_output=$(GGML_VK_Q4K_VARIANT=e4/4 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "variant=%s\n" "${GGML_VK_Q4K_VARIANT-unset}"')
printf '%s\n' "$variant_ambient_output" | grep -Fx 'variant=unset' >/dev/null
# A value outside the admitted set names an arm the build cannot create, and the
# wrapper refuses it while the argv is still readable rather than letting the
# server end the load at pipeline creation.
variant_status=0
variant_error=$(QWEN_Q4K_VARIANT=e5-scale/4 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" true 2>&1 >/dev/null) || variant_status=$?
if [ "$variant_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted QWEN_Q4K_VARIANT=e5-scale/4\n' >&2
    exit 1
fi
printf '%s\n' "$variant_error" | grep -Fx \
    'QWEN_Q4K_VARIANT is production/4, or e4, e4-scale, or e4-scale-licm over /2, /4, or /8: e5-scale/4' >/dev/null
# production/4 names the production module through the multiplexer, so a control
# arm of a variant-select build reaches the wrapper under a key rather than
# under an absent one.
# shellcheck disable=SC2016
variant_production_output=$(QWEN_Q4K_VARIANT=production/4 \
    QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "variant=%s\n" "${GGML_VK_Q4K_VARIANT-unset}"')
printf '%s\n' "$variant_production_output" | grep -Fx 'variant=production/4' >/dev/null
variant_status=0
QWEN_Q4K_VARIANT=e4-scale-licm/16 QWEN_VULKAN_PROFILE=low-async "$wrapper" true \
    >/dev/null 2>/dev/null || variant_status=$?
if [ "$variant_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted QWEN_Q4K_VARIANT=e4-scale-licm/16\n' >&2
    exit 1
fi
# The key states the whole tuple, so an algorithm without a row count leaves the
# shape at whatever the AMD_GCN branch selected under a name claiming an arm.
variant_status=0
QWEN_Q4K_VARIANT=e4-scale-licm QWEN_VULKAN_PROFILE=low-async "$wrapper" true \
    >/dev/null 2>/dev/null || variant_status=$?
if [ "$variant_status" -ne 2 ]; then
    printf 'RADV environment wrapper accepted a row-less QWEN_Q4K_VARIANT\n' >&2
    exit 1
fi

# The int24 candidate admits its q8_1 mat-vec pipelines under
# GGML_VK_FORCE_INTEGER_DOT, so every serving profile scrubs it the way it
# scrubs the sideplane names and the diagnostic profile alone restores what the
# caller asked for. The scrub is what keeps the arm and its control apart on one
# binary, and `custom` is a serving profile: it varies the submission settings,
# which leaves a rate it measures comparable with a rate the appliance serves.
for serving_profile in paced-60 low-serialized low-async custom; do
    # The nested shell expands its own runtime environment after the wrapper runs.
    # shellcheck disable=SC2016
    serving_force_dot_output=$(GGML_VK_FORCE_INTEGER_DOT=1 \
        QWEN_VULKAN_PROFILE=$serving_profile \
        "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
    if ! printf '%s\n' "$serving_force_dot_output" | grep -Fx \
        'force_integer_dot=unset' >/dev/null; then
        printf 'the %s profile carried GGML_VK_FORCE_INTEGER_DOT: %s\n' \
            "$serving_profile" "$serving_force_dot_output" >&2
        exit 1
    fi
done
diagnostic_force_dot_output=$(GGML_VK_FORCE_INTEGER_DOT=1 QWEN_PERF_LOGGER=4 \
    QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$diagnostic_force_dot_output" | grep -Fx 'force_integer_dot=1' >/dev/null
# The control arm of the ISA receipt names the same profile and supplies no
# value, so the restore is what separates the two rather than the profile name.
diagnostic_control_output=$(QWEN_PERF_LOGGER=4 QWEN_VULKAN_PROFILE=diagnostic \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$diagnostic_control_output" | grep -Fx 'force_integer_dot=unset' >/dev/null
# ggml_vk_force_integer_dot() compares the value against "1", so a third value
# runs the control under a name that claims the arm and the profile refuses it.
diagnostic_force_dot_status=0
diagnostic_force_dot_error=$(GGML_VK_FORCE_INTEGER_DOT=0 QWEN_PERF_LOGGER=4 \
    QWEN_VULKAN_PROFILE=diagnostic "$wrapper" true 2>&1 >/dev/null) ||
    diagnostic_force_dot_status=$?
if [ "$diagnostic_force_dot_status" -ne 2 ]; then
    printf 'the diagnostic profile accepted GGML_VK_FORCE_INTEGER_DOT=0\n' >&2
    exit 1
fi
printf '%s\n' "$diagnostic_force_dot_error" | grep -Fx \
    'GGML_VK_FORCE_INTEGER_DOT admits 1 or an unset value: 0' >/dev/null

# remote/dump-radv-shader-isa.sh runs a serving profile and reaches the arm by
# forwarding the caller's value past the scrub on its own `env`, so the two arms
# of the receipt differ in that assignment. A collector that dropped the forward
# would collect the control under the arm's name.
collector=$script_directory/dump-radv-shader-isa.sh
if ! grep -q 'GGML_VK_FORCE_INTEGER_DOT="\$requested_force_integer_dot"' \
    "$collector"; then
    printf 'the ISA collector no longer forwards the force flag past the scrub\n' >&2
    exit 1
fi
# The collector names its arm from the same comparison the backend makes, and
# it refuses a third value ahead of the measured-host check, so this arm runs
# on any host.
collector_force_dot_status=0
collector_force_dot_error=$(GGML_VK_FORCE_INTEGER_DOT=0 "$collector" \
    /nonexistent/output /nonexistent/server /nonexistent/model 2>&1 >/dev/null) ||
    collector_force_dot_status=$?
if [ "$collector_force_dot_status" -ne 2 ]; then
    printf 'the ISA collector accepted GGML_VK_FORCE_INTEGER_DOT=0\n' >&2
    exit 1
fi
printf '%s\n' "$collector_force_dot_error" | grep -Fx \
    'GGML_VK_FORCE_INTEGER_DOT admits 1 or an unset value: 0' >/dev/null

# A served A/B arm reaches the same admission under its serving profile, since
# run-served-binary-ab.sh runs every arm under low-async and a profile of its
# own would put a second string into the field the scoreboard receipt requires
# to read low-async. QWEN_FORCE_INTEGER_DOT crosses the scrub under its own name
# the way the census toggle does, and the profile's own exports stay what they
# are: low-async keeps max_nodes 16 and leaves serialization absent.
for serving_profile in paced-60 low-serialized low-async custom; do
    # The nested shell expands its own runtime environment after the wrapper runs.
    # shellcheck disable=SC2016
    crossing_output=$(GGML_VK_FORCE_INTEGER_DOT=stale \
        QWEN_FORCE_INTEGER_DOT=1 QWEN_VULKAN_PROFILE=$serving_profile \
        "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
    if ! printf '%s\n' "$crossing_output" | grep -Fx \
        'force_integer_dot=1' >/dev/null; then
        printf 'the %s profile dropped QWEN_FORCE_INTEGER_DOT: %s\n' \
            "$serving_profile" "$crossing_output" >&2
        exit 1
    fi
done
# The crossing carries the admission and nothing else, so low-async's whole
# GGML_VK_ set is the wrapper-wide flag, its own node count, and that one name.
crossing_environment=$(QWEN_FORCE_INTEGER_DOT=1 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'env | grep "^GGML_VK_" | sort')
crossing_expected='GGML_VK_FORCE_INTEGER_DOT=1
GGML_VK_LOW_PRIORITY=1
GGML_VK_MAX_NODES_PER_SUBMIT=16'
if [ "$crossing_environment" != "$crossing_expected" ]; then
    printf 'the low-async crossing exported an environment beyond its declaration: %s\n' \
        "$crossing_environment" >&2
    exit 1
fi
# An absent request leaves the scrub answering, which is what makes the control
# arm of a served pair a control.
crossing_absent_output=$(GGML_VK_FORCE_INTEGER_DOT=1 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" sh -c 'printf "force_integer_dot=%s\n" "${GGML_VK_FORCE_INTEGER_DOT-unset}"')
printf '%s\n' "$crossing_absent_output" | grep -Fx 'force_integer_dot=unset' >/dev/null
# ggml_vk_force_integer_dot() compares against "1", so the crossing refuses a
# third value rather than running the control under the arm's name.
crossing_status=0
crossing_error=$(QWEN_FORCE_INTEGER_DOT=0 QWEN_VULKAN_PROFILE=low-async \
    "$wrapper" true 2>&1 >/dev/null) || crossing_status=$?
if [ "$crossing_status" -ne 2 ]; then
    printf 'the serving crossing accepted QWEN_FORCE_INTEGER_DOT=0\n' >&2
    exit 1
fi
printf '%s\n' "$crossing_error" | grep -Fx \
    'QWEN_FORCE_INTEGER_DOT admits 1 or an unset value: 0' >/dev/null
# The value crosses the tmux boundary only where qwen-webui-control.sh forwards
# it, so a launch that dropped the name would serve the control under the arm's
# own receipt.
if ! grep -q 'QWEN_FORCE_INTEGER_DOT' "$script_directory/qwen-webui-control.sh"; then
    printf 'the session control no longer forwards QWEN_FORCE_INTEGER_DOT\n' >&2
    exit 1
fi

environment_output=$(capture_environment low-async)
printf '%s\n' "$environment_output" | grep -F \
    'profile=low-async low=1 duty=unset serialized=unset max_nodes=16 strict=1' >/dev/null

if QWEN_VULKAN_PROFILE=unknown "$wrapper" true \
    > /dev/null 2> /dev/null; then
    printf 'RADV environment wrapper accepted an unknown profile\n' >&2
    exit 1
fi

device_output=$(QWEN_VULKAN_PROFILE=low-serialized \
    "$wrapper" vulkaninfo --summary 2>&1)
printf '%s\n' "$device_output" | grep -F 'AMD Radeon Graphics (RADV RAVEN2)' >/dev/null
printf 'radv_environment=accepted\n'
