#!/bin/sh
set -eu

# The projector depth probe decides whether a vision row may claim a numeric
# validated_filled_depth, so its failure modes are silent ones: an arm that
# never reaches its depth recorded as validated, a tuple row naming
# projector_state none, a launch that omits --mmproj and measures the text
# tuple under a vision label, or a run that starts while another process holds
# the device. These checks drive the harness against the served fixture, where
# one whitespace-separated word stands for one token and each image part
# contributes a fixed lump.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
probe=$script_directory/probe-depth-projector.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
tuple_checker=$script_directory/check-validated-tuples.sh
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
failures=0
tab=$(printf '\t')

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

registry=$temporary_directory/models.tsv
{
    printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tprojector_fetch_script\tdecode_tok_s\tprefill_tok_s\tquality\ttier\tbatch\tubatch\tvalidated_filled_depth\tvalidation_evidence\traw_tool_selection\tguarded_tool_execution\n'
    printf 'fake-vision\tvision\tFake-Vision-GGUF/fake-vision.gguf\tdownload-fake-vision.sh\t8192\t8192\t32768\tq8_0\tq4_0\ton\trequired\tdownload-fake-vision-mmproj.sh\t1.00\t1.00\t1/55\tcandidate\t128\t32\t-\t-\t1/10\trefused\n'
    printf 'fake-text\tfast-text\tFake-Text-GGUF/fake-text.gguf\tdownload-fake-text.sh\t8192\t8192\t32768\tq8_0\tq4_0\ton\tnone\t-\t1.00\t1.00\t1/55\tcandidate\t128\t32\t-\t-\t1/10\trefused\n'
} >"$registry"

model_root=$temporary_directory/models
mkdir -p "$model_root/Fake-Vision-GGUF" "$model_root/Fake-Text-GGUF"
printf 'fake vision weights\n' >"$model_root/Fake-Vision-GGUF/fake-vision.gguf"
printf 'fake projector\n' >"$model_root/Fake-Vision-GGUF/mmproj-F16.gguf"
printf 'fake text weights\n' >"$model_root/Fake-Text-GGUF/fake-text.gguf"

image_directory=$temporary_directory/images
mkdir -p "$image_directory"
cp "$script_directory/quality-images/bars.png" "$image_directory/bars.png"

fake_icd=$temporary_directory/radeon_icd.json
printf '{}\n' >"$fake_icd"
vulkan_wrapper=$temporary_directory/vulkan-wrapper.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    ': "${QWEN_VULKAN_PROFILE:?}"' \
    'export GGML_VK_LOW_PRIORITY=1' \
    'export GGML_VK_SERIALIZE_SUBMISSIONS=1' \
    'export GGML_VK_MAX_NODES_PER_SUBMIT=32' \
    'exec "$@"' >"$vulkan_wrapper"
chmod +x "$vulkan_wrapper"

# A dmesg that follows an empty buffer, so the reset and fault accounting runs
# on a host whose own kernel log is restricted to root.
dmesg_stub=$temporary_directory/dmesg-stub.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'if [ "${1:-}" = --follow-new ]; then sleep 3600; fi' 'exit 0' \
    >"$dmesg_stub"
chmod +x "$dmesg_stub"

run_probe() {
    env QWEN_MODEL_REGISTRY="$registry" \
        QWEN_MODEL_REGISTRY_READER="$script_directory/model-registry.sh" \
        QWEN_PROJECTOR_SELECTOR="$script_directory/select-projector.sh" \
        QWEN_MODEL_ROOT="$model_root" \
        QWEN_LLAMA_SERVER="${QWEN_LLAMA_SERVER:-$fake_server}" \
        QWEN_QUALITY_IMAGE_DIRECTORY="$image_directory" \
        QWEN_CLOCK_SAMPLER="$temporary_directory/absent-sampler.sh" \
        QWEN_DMESG_COMMAND="$dmesg_stub" \
        QWEN_POLICY_TEST_OUTPUT="$temporary_directory/launch-argv.txt" \
        QWEN_POLICY_TEST_HTTP_PORT="${QWEN_POLICY_TEST_HTTP_PORT:-18091}" \
        QWEN_PROJECTOR_PROBE_PORT="${QWEN_PROJECTOR_PROBE_PORT:-18091}" \
        QWEN_PROJECTOR_READY_TIMEOUT_S="${QWEN_PROJECTOR_READY_TIMEOUT_S:-30}" \
        QWEN_PROJECTOR_ARM_TIMEOUT_S="${QWEN_PROJECTOR_ARM_TIMEOUT_S:-30}" \
        QWEN_PROJECTOR_KILL_AFTER_S=3 \
        QWEN_RADV_ICD="$fake_icd" \
        QWEN_PROJECTOR_PRIORITY_WRAPPER="$script_directory/qwen-exec-idle-priority.sh" \
        QWEN_PROJECTOR_VULKAN_WRAPPER="$vulkan_wrapper" \
        "$@"
}

# An argument count outside two is a usage error, and the harness says so
# before it reads a registry or touches the device.
usage_accepted=accepted
for usage_case in 0 1 3; do
    set +e
    case $usage_case in
        0) run_probe "$probe" >/dev/null 2>&1 ;;
        1) run_probe "$probe" fake-vision >/dev/null 2>&1 ;;
        3) run_probe "$probe" fake-vision "$temporary_directory/u" extra \
               >/dev/null 2>&1 ;;
    esac
    usage_status=$?
    set -e
    [ "$usage_status" -eq 2 ] || usage_accepted="argc-$usage_case-status-$usage_status"
done
report usage_error_exit_two "$usage_accepted"

# The ledger's runtime_mode column admits standalone and router-child, so a
# third spelling is refused from either the flag or the environment before a
# registry read or a device touch.
mode_accepted=accepted
set +e
run_probe "$probe" --runtime-mode router fake-vision \
    "$temporary_directory/mode-flag" >/dev/null 2>&1
flag_mode_status=$?
set -e
[ "$flag_mode_status" -eq 2 ] || mode_accepted="flag-status-$flag_mode_status"
set +e
QWEN_PROBE_RUNTIME_MODE=router-server run_probe "$probe" fake-vision \
    "$temporary_directory/mode-env" >/dev/null 2>&1
env_mode_status=$?
set -e
[ "$env_mode_status" -eq 2 ] || mode_accepted="env-status-$env_mode_status"
[ ! -e "$temporary_directory/mode-env" ] ||
    mode_accepted='unknown-mode-created-an-output-directory'
report unknown_runtime_mode_refused "$mode_accepted"

# A registry id with no row stops the run rather than probing a guessed path.
set +e
run_probe "$probe" absent-row "$temporary_directory/absent" >/dev/null 2>&1
absent_status=$?
set -e
if [ "$absent_status" -ne 0 ]; then
    report unknown_model_id_refused accepted
else
    report unknown_model_id_refused "status-$absent_status"
fi

# A row whose projector field reads `none` has no loaded-projector tuple to
# measure, so the harness refuses it instead of launching a text arm under a
# vision label.
set +e
run_probe "$probe" fake-text "$temporary_directory/text" >/dev/null 2>&1
text_status=$?
set -e
[ "$text_status" -eq 2 ] &&
    report text_only_row_refused accepted ||
    report text_only_row_refused "status-$text_status"

# The fill margin has to fit inside the 2% shortfall an arm accepts, or every
# arm reports a prompt short of its own window.
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_PROJECTOR_FILL_MARGIN=1024 \
    run_probe "$probe" fake-vision "$temporary_directory/margin" \
    >/dev/null 2>&1
margin_status=$?
set -e
[ "$margin_status" -eq 2 ] &&
    report oversized_margin_refused accepted ||
    report oversized_margin_refused "status-$margin_status"

# Another llama process on the device makes every measurement a contended one,
# so the harness refuses to start rather than recording it.
busy_path=$temporary_directory/busy-bin
mkdir -p "$busy_path"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$busy_path/pgrep"
chmod +x "$busy_path/pgrep"
set +e
PATH="$busy_path:$PATH" run_probe "$probe" fake-vision \
    "$temporary_directory/busy" >/dev/null 2>&1
busy_status=$?
set -e
[ "$busy_status" -eq 2 ] &&
    report running_server_refused accepted ||
    report running_server_refused "status-$busy_status"

# One complete arm against the served fixture.
arm_directory=$temporary_directory/arm
arm_log=$temporary_directory/arm.log
set +e
QWEN_WEDGE_DEPTHS=8192 run_probe "$probe" fake-vision "$arm_directory" \
    >"$arm_log" 2>&1
arm_status=$?
set -e
if [ "$arm_status" -eq 0 ]; then
    report arm_completed accepted
else
    report arm_completed "status-$arm_status"
    sed -n '1,40p' "$arm_log" >&2
fi

summary=$arm_directory/projector-summary.tsv
summary_row=$(awk -F'\t' 'NR == 2 { print }' "$summary" 2>/dev/null || true)
summary_field_count=$(printf '%s' "$summary_row" | awk -F'\t' '{ print NF }')
[ "$summary_field_count" = 23 ] &&
    report summary_row_field_count accepted ||
    report summary_row_field_count "fields-$summary_field_count"

summary_field() {
    printf '%s' "$summary_row" | awk -F'\t' -v index_number="$1" \
        '{ print $index_number }'
}
[ "$(summary_field 1)" = d8192-b128-ub32-proj ] &&
    report summary_arm_label accepted ||
    report summary_arm_label "label-$(summary_field 1)"
[ "$(summary_field 9)" = loaded ] &&
    report summary_projector_state accepted ||
    report summary_projector_state "state-$(summary_field 9)"
[ "$(summary_field 23)" = standalone ] &&
    report summary_runtime_mode accepted ||
    report summary_runtime_mode "mode-$(summary_field 23)"
[ "$(summary_field 10)" = ok ] && [ "$(summary_field 18)" = ok ] &&
    [ "$(summary_field 20)" = healthy ] &&
    report summary_status_control_health accepted ||
    report summary_status_control_health "status-$(summary_field 10)-control-$(summary_field 18)-health-$(summary_field 20)"

# The recorded prompt has to sit inside the arm's own acceptance window, since
# the window is what separates a filled cache from an allocated one.
recorded_prompt_n=$(summary_field 11)
case $recorded_prompt_n in
    '' | *[!0-9]*) report prompt_n_inside_window "value-$recorded_prompt_n" ;;
    *)
        if [ "$recorded_prompt_n" -ge $((8192 - 8192 * 2 / 100)) ] &&
           [ "$recorded_prompt_n" -le $((8192 - 32)) ]; then
            report prompt_n_inside_window accepted
        else
            report prompt_n_inside_window "prompt_n-$recorded_prompt_n"
        fi
        ;;
esac

# The launch argv carries the projector and the registry's own served tuple; a
# missing --mmproj would measure the text tuple, and an absent geometry key
# falls through to the llama.cpp defaults of batch 2048 and ubatch 512.
launch_argv=$temporary_directory/launch-argv.txt
argv_accepted=accepted
for required_argument in \
    "argument=--mmproj" \
    "argument=$model_root/Fake-Vision-GGUF/mmproj-F16.gguf" \
    "argument=--ctx-size" "argument=8192" \
    "argument=--batch-size" "argument=128" \
    "argument=--ubatch-size" "argument=32" \
    "argument=--cache-type-k" "argument=q8_0" \
    "argument=--cache-type-v" "argument=q4_0" \
    "argument=--flash-attn" "argument=on" \
    "argument=--parallel" "argument=1" \
    "argument=--host" "argument=127.0.0.1" \
    "argument=--override-tensor" "argument=.*=Vulkan0"; do
    grep -qxF "$required_argument" "$launch_argv" 2>/dev/null ||
        argv_accepted="missing-$required_argument"
done
for required_profile_field in 'nice=19' 'low=1' 'serialized=1' \
    'max_nodes=32' 'profile=low-serialized'; do
    grep -qxF "$required_profile_field" "$launch_argv" 2>/dev/null ||
        argv_accepted="missing-$required_profile_field"
done
grep -qxF 'strict=1' "$launch_argv" 2>/dev/null ||
    argv_accepted=missing-strict-placement
report launch_argv_carries_tuple "$argv_accepted"

# The emitted ledger line is the deliverable: one row per healthy arm, naming
# the loaded projector and the standalone runtime mode.
emitted=$arm_directory/validated-tuples-rows.tsv
emitted_row=$(sed -n '1p' "$emitted" 2>/dev/null || true)
emitted_field() {
    printf '%s' "$emitted_row" | awk -F'\t' -v index_number="$1" \
        '{ print $index_number }'
}
emitted_field_count=$(printf '%s' "$emitted_row" | awk -F'\t' '{ print NF }')
[ "$emitted_field_count" = 21 ] &&
    report emitted_row_field_count accepted ||
    report emitted_row_field_count "fields-$emitted_field_count"
emitted_accepted=accepted
[ "$(emitted_field 1)" = fake-vision-d8192-b128-ub32-proj ] ||
    emitted_accepted="tuple_id-$(emitted_field 1)"
[ "$(emitted_field 3)" = standalone ] ||
    emitted_accepted="runtime_mode-$(emitted_field 3)"
[ "$(emitted_field 4)" = 8192 ] || emitted_accepted="context-$(emitted_field 4)"
[ "$(emitted_field 12)" = loaded ] ||
    emitted_accepted="projector_state-$(emitted_field 12)"
[ "$(emitted_field 13)" = vulkan ] ||
    emitted_accepted="backend-$(emitted_field 13)"
[ "$(emitted_field 14)" = validated ] ||
    emitted_accepted="status-$(emitted_field 14)"
case $(emitted_field 15) in
    evidence/depth-validation-32k-projector/fake-vision/) ;;
    *) emitted_accepted="evidence-$(emitted_field 15)" ;;
esac
report emitted_row_fields "$emitted_accepted"

# The gap the harness exists to close: models.tsv claiming that depth with
# projector `required` finds its validated row in a ledger the emitted line
# builds.
promoted_registry=$temporary_directory/promoted-models.tsv
awk -F'\t' -v OFS='\t' '
    /^#/ { print; next }
    $1 == "fake-vision" { $19 = "8192"; $20 = "evidence/depth-validation-32k-projector/fake-vision/" }
    { print }' "$registry" >"$promoted_registry"
promoted_ledger=$temporary_directory/promoted-tuples.tsv
printf '# tuple_id%smodel_id\n' "$tab" >"$promoted_ledger"
cat "$emitted" >>"$promoted_ledger"

# The reviewer claim is read from the image ledger, so each check names one.
# A row whose review_model reads `-` states no reviewer and leaves the tuple
# check to the registry claim alone.
write_image_profiles() {
    printf 'fake-image\tfake-sd\tA\t512\t512\t1\teuler\t1.0\t4\t512\t300\t%s\t-\t%s\n' \
        "$2" "$3" >"$1"
}
image_profiles_none=$temporary_directory/image-profiles-none.tsv
image_profiles_gated=$temporary_directory/image-profiles-gated.tsv
image_profiles_refused=$temporary_directory/image-profiles-refused.tsv
write_image_profiles "$image_profiles_none" refused -
write_image_profiles "$image_profiles_gated" validator-gated fake-vision
write_image_profiles "$image_profiles_refused" refused fake-vision

set +e
QWEN_MODEL_REGISTRY="$promoted_registry" QWEN_VALIDATED_TUPLES="$promoted_ledger" \
    QWEN_IMAGE_PROFILES="$image_profiles_none" \
    "$tuple_checker" >"$temporary_directory/tuple-check.txt" 2>&1
tuple_check_status=$?
set -e
[ "$tuple_check_status" -eq 0 ] &&
    report emitted_row_closes_registry_gap accepted ||
    report emitted_row_closes_registry_gap "status-$tuple_check_status"

# The router arm measures the same geometry through the mode build-web-presets.sh
# requires of a review-only vision section. The tuple leaves the argv and enters
# one generated preset section, so the checks read both surfaces: the section
# carries the six keys plus the checkpoint count and the projector, and the
# router argv states none of them.
router_directory=$temporary_directory/router
router_log=$temporary_directory/router.log
router_requests=$temporary_directory/router-requests
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_FAKE_SERVER_REQUEST_DIRECTORY="$router_requests" \
    run_probe "$probe" --runtime-mode router-child fake-vision \
    "$router_directory" >"$router_log" 2>&1
router_status=$?
set -e
if [ "$router_status" -eq 0 ]; then
    report router_arm_completed accepted
else
    report router_arm_completed "status-$router_status"
    sed -n '1,40p' "$router_log" >&2
fi

router_summary_row=$(awk -F'\t' 'NR == 2 { print }' \
    "$router_directory/projector-summary.tsv" 2>/dev/null || true)
router_summary_field() {
    printf '%s' "$router_summary_row" | awk -F'\t' -v index_number="$1" \
        '{ print $index_number }'
}
router_summary_accepted=accepted
[ "$(router_summary_field 1)" = d8192-b128-ub32-proj ] ||
    router_summary_accepted="label-$(router_summary_field 1)"
[ "$(router_summary_field 23)" = router-child ] ||
    router_summary_accepted="runtime_mode-$(router_summary_field 23)"
[ "$(router_summary_field 9)" = loaded ] ||
    router_summary_accepted="projector_state-$(router_summary_field 9)"
[ "$(router_summary_field 10)" = ok ] ||
    router_summary_accepted="status-$(router_summary_field 10)"
[ "$(router_summary_field 18)" = ok ] ||
    router_summary_accepted="control-$(router_summary_field 18)"
[ "$(router_summary_field 20)" = healthy ] ||
    router_summary_accepted="health-$(router_summary_field 20)"
report router_summary_records_mode "$router_summary_accepted"

# The emitted row is the one build-web-presets.sh joins a review_model against:
# runtime_mode router-child at the registry tuple with the projector loaded, its
# tuple_id distinct from the standalone row it otherwise equals.
router_emitted_row=$(sed -n '1p' \
    "$router_directory/validated-tuples-rows.tsv" 2>/dev/null || true)
router_emitted_field() {
    printf '%s' "$router_emitted_row" | awk -F'\t' -v index_number="$1" \
        '{ print $index_number }'
}
router_emitted_accepted=accepted
[ "$(printf '%s' "$router_emitted_row" | awk -F'\t' '{ print NF }')" = 21 ] ||
    router_emitted_accepted='field-count'
[ "$(router_emitted_field 1)" = fake-vision-d8192-b128-ub32-proj-router ] ||
    router_emitted_accepted="tuple_id-$(router_emitted_field 1)"
[ "$(router_emitted_field 3)" = router-child ] ||
    router_emitted_accepted="runtime_mode-$(router_emitted_field 3)"
[ "$(router_emitted_field 12)" = loaded ] ||
    router_emitted_accepted="projector_state-$(router_emitted_field 12)"
[ "$(router_emitted_field 14)" = validated ] ||
    router_emitted_accepted="status-$(router_emitted_field 14)"
# Every field but the identity and the mode equals the standalone line, since
# the two rows state one geometry measured through two serving paths.
router_field_index=4
while [ "$router_field_index" -le 21 ]; do
    if [ "$(router_emitted_field "$router_field_index")" != \
         "$(emitted_field "$router_field_index")" ]; then
        router_emitted_accepted="field-$router_field_index-differs"
    fi
    router_field_index=$((router_field_index + 1))
done
report router_emitted_row_fields "$router_emitted_accepted"

router_preset=$router_directory/d8192-b128-ub32-proj.router-preset.ini
router_preset_accepted=accepted
for required_preset_line in \
    '[fake-vision]' \
    'LLAMA_ARG_CTX_SIZE = 8192' \
    'LLAMA_ARG_BATCH = 128' \
    'LLAMA_ARG_UBATCH = 32' \
    'LLAMA_ARG_CACHE_TYPE_K = q8_0' \
    'LLAMA_ARG_CACHE_TYPE_V = q4_0' \
    'LLAMA_ARG_FLASH_ATTN = on' \
    'LLAMA_ARG_CTX_CHECKPOINTS = 0'; do
    grep -qxF "$required_preset_line" "$router_preset" 2>/dev/null ||
        router_preset_accepted="missing-$required_preset_line"
done
grep -q '^LLAMA_ARG_MMPROJ = .*mmproj-F16.gguf$' "$router_preset" 2>/dev/null ||
    router_preset_accepted=missing-projector
[ "$(grep -c '^\[' "$router_preset" 2>/dev/null)" = 1 ] ||
    router_preset_accepted=section-count
report router_preset_carries_tuple "$router_preset_accepted"

# common_preset::merge overwrites a section key with the router argv's value of
# the same name, so the tuple reaching the child is the section's exactly where
# the argv states none of it.
router_argv_accepted=accepted
grep -qxF 'argument=--models-preset' "$launch_argv" 2>/dev/null ||
    router_argv_accepted=missing-models-preset
grep -qxF "argument=$router_preset" "$launch_argv" 2>/dev/null ||
    router_argv_accepted=missing-preset-path
grep -qxF 'argument=--models-max' "$launch_argv" 2>/dev/null ||
    router_argv_accepted=missing-models-max
for refused_argument in --ctx-size --batch-size --ubatch-size --flash-attn \
    --cache-type-k --cache-type-v --ctx-checkpoints --mmproj --model --alias; do
    ! grep -qxF "argument=$refused_argument" "$launch_argv" 2>/dev/null ||
        router_argv_accepted="argv-carries-$refused_argument"
done
report router_argv_leaves_tuple_to_section "$router_argv_accepted"

# The router resolves each request to a section by the body's own model key.
router_routing_accepted=accepted
grep -rlF '"model": "fake-vision"' "$router_requests" >/dev/null 2>&1 ||
    router_routing_accepted=request-carries-no-model-key
report router_requests_name_the_section "$router_routing_accepted"

# The gate the router arm exists to close. A validator-gated image row naming a
# reviewer whose ledger holds standalone rows alone fails and prints the probe
# command that measures the missing arm; the same ledger with the router row
# appended passes, and a refused row reports the absence as a warning because it
# emits no section under any setting.
router_ledger=$temporary_directory/router-tuples.tsv
printf '# tuple_id%smodel_id\n' "$tab" >"$router_ledger"
cat "$emitted" >>"$router_ledger"
cat "$router_directory/validated-tuples-rows.tsv" >>"$router_ledger"

check_reviewer_gate() {
    set +e
    QWEN_MODEL_REGISTRY="$promoted_registry" QWEN_VALIDATED_TUPLES="$1" \
        QWEN_IMAGE_PROFILES="$2" "$tuple_checker" \
        >"$temporary_directory/reviewer-check.txt" 2>&1
    reviewer_check_status=$?
    set -e
}

reviewer_accepted=accepted
check_reviewer_gate "$promoted_ledger" "$image_profiles_gated"
[ "$reviewer_check_status" -eq 1 ] ||
    reviewer_accepted="gated-status-$reviewer_check_status"
grep -qxF \
    'QWEN_WEDGE_DEPTHS=8192 remote/probe-depth-projector.sh --runtime-mode router-child fake-vision OUTPUT_DIRECTORY' \
    "$temporary_directory/reviewer-check.txt" ||
    reviewer_accepted='gated-report-omits-the-probe-command'
check_reviewer_gate "$router_ledger" "$image_profiles_gated"
[ "$reviewer_check_status" -eq 0 ] ||
    reviewer_accepted="router-row-status-$reviewer_check_status"
check_reviewer_gate "$promoted_ledger" "$image_profiles_refused"
[ "$reviewer_check_status" -eq 0 ] ||
    reviewer_accepted="refused-status-$reviewer_check_status"
grep -q 'check_validated_tuples_warning=reviewer_tuple_absent' \
    "$temporary_directory/reviewer-check.txt" ||
    reviewer_accepted='refused-row-reports-no-warning'
report reviewer_tuple_gate "$reviewer_accepted"

# A directory is bound to one runtime mode, so the standalone metadata refuses
# the router invocation over the same output directory and the reverse.
set +e
QWEN_WEDGE_DEPTHS=8192 run_probe "$probe" --runtime-mode router-child \
    fake-vision "$arm_directory" >/dev/null 2>&1
crossed_mode_status=$?
set -e
[ "$crossed_mode_status" -eq 2 ] &&
    report crossed_runtime_mode_refuses_resume accepted ||
    report crossed_runtime_mode_refuses_resume "status-$crossed_mode_status"

# A control whose answer misses the content the fixture declares establishes
# that the projector stopped encoding into the language model's embedding
# space, so the arm records a failure, halts the chain, and emits no ledger
# row.
control_directory=$temporary_directory/control-failure
control_log=$temporary_directory/control-failure.log
set +e
QWEN_WEDGE_DEPTHS='8192 16384' QWEN_POLICY_TEST_REPLY=MAY \
    run_probe "$probe" fake-vision "$control_directory" \
    >"$control_log" 2>&1
control_failure_status=$?
set -e
control_failure_accepted=accepted
[ "$control_failure_status" -eq 1 ] ||
    control_failure_accepted="status-$control_failure_status"
control_arm_count=$(awk 'NR > 1' \
    "$control_directory/projector-summary.tsv" 2>/dev/null | wc -l)
[ "$control_arm_count" -eq 1 ] ||
    control_failure_accepted="arms-$control_arm_count"
[ ! -s "$control_directory/validated-tuples-rows.tsv" ] ||
    control_failure_accepted='emitted-a-row-for-a-failed-control'
report failed_control_halts_chain "$control_failure_accepted"

# A label embedded in prose is not the fixture's declared label-alone answer.
for foreign_reply in 'NOT JUN' 'JUN is tallest'; do
    exact_suffix=$(printf '%s' "$foreign_reply" | tr ' ' -)
    exact_directory=$temporary_directory/exact-$exact_suffix
    set +e
    QWEN_WEDGE_DEPTHS=8192 QWEN_POLICY_TEST_REPLY="$foreign_reply" \
        run_probe "$probe" fake-vision "$exact_directory" >/dev/null 2>&1
    exact_status=$?
    set -e
    exact_name=$(printf '%s' "$foreign_reply" | tr ' ' '_')
    [ "$exact_status" -eq 1 ] &&
        report "control_exact_$exact_name" accepted ||
        report "control_exact_$exact_name" "status-$exact_status"
done

# A healthy foreign HTTP listener cannot stand in for the process this harness
# launched. The preflight refuses the occupied endpoint before an arm starts.
python3 -m http.server 18092 --bind 127.0.0.1 \
    >"$temporary_directory/foreign-listener.log" 2>&1 &
foreign_listener_pid=$!
sleep 1
set +e
QWEN_PROJECTOR_PROBE_PORT=18092 run_probe "$probe" fake-vision \
    "$temporary_directory/foreign-listener" >/dev/null 2>&1
foreign_listener_status=$?
set -e
kill "$foreign_listener_pid" 2>/dev/null || true
wait "$foreign_listener_pid" 2>/dev/null || true
[ "$foreign_listener_status" -eq 2 ] &&
    report foreign_listener_refused accepted ||
    report foreign_listener_refused "status-$foreign_listener_status"

# An unready server still receives the request artifact the resume contract
# requires, so a later invocation can validate and skip the failed arm.
unready_server=$temporary_directory/unready-server.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'if [ "${1:-}" = --version ]; then printf "build: 0000000 with fake\\n"; exit 0; fi' \
    'sleep 60' >"$unready_server"
chmod +x "$unready_server"
unready_directory=$temporary_directory/unready
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_LLAMA_SERVER="$unready_server" \
    QWEN_PROJECTOR_READY_TIMEOUT_S=1 run_probe "$probe" fake-vision \
    "$unready_directory" >/dev/null 2>&1
unready_status=$?
set -e
unready_request=$unready_directory/d8192-b128-ub32-proj.requests.txt
if [ "$unready_status" -eq 1 ] &&
   grep -qxF 'failure=server-unready' "$unready_request"; then
    report server_unready_retains_request_artifact accepted
else
    report server_unready_retains_request_artifact "status-$unready_status"
fi

# The request budget belongs to the whole arm. Delaying every endpoint cannot
# multiply the timeout across probe, tokenization, fill, and control.
deadline_directory=$temporary_directory/deadline
deadline_start=$(date +%s)
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_PROJECTOR_ARM_TIMEOUT_S=1 \
    QWEN_POLICY_TEST_POST_DELAY_S=0.45 run_probe "$probe" fake-vision \
    "$deadline_directory" >/dev/null 2>&1
deadline_status=$?
set -e
deadline_elapsed=$(($(date +%s) - deadline_start))
deadline_request=$deadline_directory/d8192-b128-ub32-proj.requests.txt
# The three-second termination grace is part of the outer elapsed time after
# the one-second request budget expires; one second of scheduler granularity
# leaves a five-second bound for the complete failed arm.
if [ "$deadline_status" -eq 1 ] && [ "$deadline_elapsed" -le 5 ] &&
   grep -q 'TimeoutError' "$deadline_request"; then
    report one_monotonic_request_deadline accepted
else
    report one_monotonic_request_deadline \
        "status-$deadline_status-elapsed-$deadline_elapsed"
fi

# A server-side device-loss report is itself a health hazard even when the
# synthetic kernel stream records zero resets and faults.
device_loss_server=$temporary_directory/device-loss-server.sh
printf '%s\n' '#!/bin/sh' 'set -eu' \
    'if [ "${1:-}" != --version ]; then printf "VK_ERROR_DEVICE_LOST\\n" >&2; fi' \
    "exec '$fake_server' \"\$@\"" >"$device_loss_server"
chmod +x "$device_loss_server"
device_loss_directory=$temporary_directory/device-loss
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_LLAMA_SERVER="$device_loss_server" \
    run_probe "$probe" fake-vision "$device_loss_directory" >/dev/null 2>&1
device_loss_status=$?
set -e
device_loss_row=$(sed -n '2p' "$device_loss_directory/projector-summary.tsv")
device_loss_health=$(printf '%s' "$device_loss_row" | cut -f20)
device_loss_hazard=$(printf '%s' "$device_loss_row" | cut -f21)
if [ "$device_loss_status" -eq 1 ] && [ "$device_loss_health" = unhealthy ] &&
   printf '%s' "$device_loss_hazard" | grep -q 'device-lost' &&
   [ ! -s "$device_loss_directory/validated-tuples-rows.tsv" ]; then
    report log_only_device_loss_blocks_emission accepted
else
    report log_only_device_loss_blocks_emission \
        "status-$device_loss_status-health-$device_loss_health-hazard-$device_loss_hazard"
fi

# A decode shorter than the requested length fails the fill while the control
# still answers, which is the halt the resume path has to restore from the
# ledger: a recorded failure stops the chain on the second invocation exactly
# as it stopped it on the first.
short_directory=$temporary_directory/short-decode
short_log=$temporary_directory/short-decode.log
set +e
QWEN_WEDGE_DEPTHS='8192 16384' QWEN_POLICY_TEST_PREDICTED_CAP=16 \
    run_probe "$probe" fake-vision "$short_directory" >"$short_log" 2>&1
short_status=$?
set -e
short_row=$(awk -F'\t' 'NR == 2 { print }' \
    "$short_directory/projector-summary.tsv" 2>/dev/null || true)
short_field() {
    printf '%s' "$short_row" | awk -F'\t' -v index_number="$1" \
        '{ print $index_number }'
}
short_accepted=accepted
[ "$short_status" -eq 1 ] || short_accepted="status-$short_status"
case $(short_field 10) in
    decode-length-mismatch:16) ;;
    *) short_accepted="arm_status-$(short_field 10)" ;;
esac
[ "$(short_field 18)" = ok ] || short_accepted="control-$(short_field 18)"
[ ! -s "$short_directory/validated-tuples-rows.tsv" ] ||
    short_accepted='emitted-a-row-for-a-failed-fill'
report failed_fill_halts_chain "$short_accepted"

short_resume_log=$temporary_directory/short-decode-resume.log
set +e
QWEN_WEDGE_DEPTHS='8192 16384' QWEN_POLICY_TEST_PREDICTED_CAP=16 \
    run_probe "$probe" fake-vision "$short_directory" \
    >"$short_resume_log" 2>&1
short_resume_status=$?
set -e
short_resume_arms=$(awk 'NR > 1' \
    "$short_directory/projector-summary.tsv" 2>/dev/null | wc -l)
short_resume_accepted=accepted
[ "$short_resume_status" -eq 1 ] ||
    short_resume_accepted="status-$short_resume_status"
[ "$short_resume_arms" -eq 1 ] ||
    short_resume_accepted="arms-$short_resume_arms"
grep -q 'arm_resume_skip label=d8192-b128-ub32-proj' "$short_resume_log" ||
    short_resume_accepted='resumed-arm-unreported'
report failed_fill_halts_on_resume "$short_resume_accepted"

# A second invocation over the same directory resumes the recorded arm rather
# than re-running it, and a metadata file bound to other weights refuses.
resume_log=$temporary_directory/resume.log
set +e
QWEN_WEDGE_DEPTHS=8192 run_probe "$probe" fake-vision "$arm_directory" \
    >"$resume_log" 2>&1
resume_status=$?
set -e
if [ "$resume_status" -eq 0 ] &&
   grep -q 'arm_resume_skip label=d8192-b128-ub32-proj' "$resume_log"; then
    report recorded_arm_resumes accepted
else
    report recorded_arm_resumes "status-$resume_status"
fi

# The summary label alone cannot authorize resume after the runner identity
# changes. A byte-distinct copy must fail against the retained arm sidecar.
changed_probe=$temporary_directory/probe-depth-projector-changed.sh
cp "$probe" "$changed_probe"
cp "$script_directory/qwen-home.sh" "$temporary_directory/qwen-home.sh"
printf '\n# identity mutation fixture\n' >>"$changed_probe"
chmod +x "$changed_probe"
set +e
QWEN_WEDGE_DEPTHS=8192 run_probe "$changed_probe" fake-vision "$arm_directory" \
    >/dev/null 2>&1
changed_probe_status=$?
set -e
[ "$changed_probe_status" -eq 2 ] &&
    report changed_runner_refuses_resume accepted ||
    report changed_runner_refuses_resume "status-$changed_probe_status"

# The prompt text is part of the metadata authority even when its expected
# answer and fixture name stay fixed.
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_PROJECTOR_CONTROL_PROMPT='Name the tallest bar.' \
    run_probe "$probe" fake-vision "$arm_directory" >/dev/null 2>&1
changed_prompt_status=$?
set -e
[ "$changed_prompt_status" -eq 2 ] &&
    report changed_control_prompt_refuses_resume accepted ||
    report changed_control_prompt_refuses_resume "status-$changed_prompt_status"

# The decode length sets the ceiling of the acceptance window, so a resume at
# another length would admit a row measured against a different window.
set +e
QWEN_WEDGE_DEPTHS=8192 QWEN_PROJECTOR_DECODE_TOKENS=64 \
    run_probe "$probe" fake-vision "$arm_directory" >/dev/null 2>&1
window_status=$?
set -e
[ "$window_status" -eq 2 ] &&
    report changed_decode_length_refuses_resume accepted ||
    report changed_decode_length_refuses_resume "status-$window_status"

printf 'fake vision weights, revised\n' >"$model_root/Fake-Vision-GGUF/fake-vision.gguf"
set +e
QWEN_WEDGE_DEPTHS=8192 run_probe "$probe" fake-vision "$arm_directory" \
    >/dev/null 2>&1
rebound_status=$?
set -e
[ "$rebound_status" -eq 2 ] &&
    report changed_weights_refuse_resume accepted ||
    report changed_weights_refuse_resume "status-$rebound_status"

if [ "$failures" -ne 0 ]; then
    printf 'probe_depth_projector_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'probe_depth_projector_tests=passed\n'
