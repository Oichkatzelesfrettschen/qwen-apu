#!/bin/sh
set -eu

# The temporal-amortization harness drives four servers per draft length and
# derives its speculation counters from two surfaces the server publishes.
# Every check below runs against remote/test-fixtures/fake-mtp-server.sh, which
# answers /health, /completion, and /metrics and reads its own argv for the
# speculation flags, so a control arm and a mechanism arm differ here by the
# flag the real server differs by.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
work=$(mktemp -d "$repository_root/.test-measure-mtp-arm.XXXXXX")
port_lease_holder_pid=''
release_port_lease() {
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
}
trap 'release_port_lease; rm -rf "$work"' EXIT INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

# A check whose evidence is an equality rather than a state word reports
# through this, so every report call carries the same two values.
equal() {
    if [ "$1" = "$2" ]; then
        printf 'accepted\n'
    else
        printf 'rejected(%s)\n' "$1"
    fi
}

# The harness binds its parser and registry to sibling programs, so the fixture
# copies that complete tool set under the same Git worktree and program
# ownership and source-revision recording stay production-identical.
tool_directory=$work/tools
mkdir -p "$tool_directory"
cp -- "$script_directory/measure-mtp-arm.sh" "$script_directory/qwen-home.sh" \
    "$script_directory/summarize-speculation-breakeven.py" \
    "$script_directory/model-registry.sh" "$tool_directory/"
chmod 0755 "$tool_directory/measure-mtp-arm.sh" \
    "$tool_directory/model-registry.sh"
harness=$tool_directory/measure-mtp-arm.sh

registry=$work/models.tsv
registry_row() {
    printf '%s\tresearch\t%s\tfetch.sh\t4096\t8192\t8192\tq8_0\tq4_0\ton\tnone\t-\t-\t-\tuntested\t%s\t128\t32\t4096\t-\tunmeasured\trefused\n' \
        "$1" "$2" "$3"
}
{
    registry_row fake-target Target/target.gguf production
    registry_row fake-draft Draft/draft.gguf candidate
    registry_row stopped-target Stopped/stopped.gguf quarantine
} >"$registry"
quarantine=$work/quarantine.tsv
: >"$quarantine"
model_root=$work/models
mkdir -p "$model_root/Target" "$model_root/Draft" "$model_root/Stopped"
printf 'target' >"$model_root/Target/target.gguf"
printf 'draft' >"$model_root/Draft/draft.gguf"
printf 'stopped' >"$model_root/Stopped/stopped.gguf"

pairs=$work/draft-pairs.tsv
{
    printf '%s\t%s\t%s\t%s\t2\t0.00\t0.700\t4096\tq8_0\tq4_0\t-\t%s\n' \
        fake-pair fake-target fake-draft candidate 'target plus draft'
    printf '%s\t%s\t%s\t%s\t2\t0.00\t0.700\t4096\tq8_0\tq4_0\t-\t%s\n' \
        stopped-pair fake-target fake-draft quarantine 'retired pairing'
} >"$pairs"

build_directory=$work/build
mkdir -p "$build_directory/bin"
cp "$script_directory/test-fixtures/fake-mtp-server.sh" \
    "$build_directory/bin/llama-server"
chmod 0755 "$build_directory/bin/llama-server"

# The production harness carries every arm through the absolute-priority and
# Vulkan-profile wrappers. These stand-ins preserve the exec chain and keep the
# test independent of the workstation's CPU numbering and kernel priority
# permissions.
wrapper_directory=$work/wrappers
mkdir -p "$wrapper_directory"
priority_wrapper=$wrapper_directory/priority-wrapper.sh
vulkan_wrapper=$wrapper_directory/vulkan-wrapper.sh
cat >"$priority_wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
printf 'priority command=%s\n' "$1" >>"${QWEN_MTP_TEST_WRAPPER_LOG:?}"
exec "$@"
WRAPPER
cat >"$vulkan_wrapper" <<'WRAPPER'
#!/bin/sh
set -eu
printf 'vulkan command=%s profile=%s strict=%s\n' "$1" \
    "${QWEN_VULKAN_PROFILE:-unset}" "${LLAMA_NO_CPU_FALLBACK:-unset}" \
    >>"${QWEN_MTP_TEST_WRAPPER_LOG:?}"
exec "$@"
WRAPPER
chmod 0755 "$priority_wrapper" "$vulkan_wrapper"
wrapper_log=$work/wrapper-chain.log
workload_lock=$work/vulkan-workload.lock

# Cooperating fake-network tests hold one host-wide lease before selecting
# released loopback ports, so concurrent repository gates cannot impersonate one
# another between allocation and listener startup.
network_fixture_lock=${TMPDIR:-/tmp}/qwen-apu-test-measure-mtp-arm-network.lock
exec 7>"$network_fixture_lock"
flock 7

# Two leased loopback ports carry the measurement listener and the alternate
# appliance listener. Binding port zero and closing the socket reported numbers
# this fixture owned for an instant and released before the fake servers bound
# them; the lease is an exclusive flock a holder process keeps for this
# script's whole run, and the fake servers bind the ports themselves, so the
# lease rather than an inherited socket is what reserves them.
port_lease_ports_file=$work/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 2 \
    "$port_lease_ports_file")
measurement_port=$(sed -n 1p "$port_lease_ports_file")
appliance_port=$(sed -n 2p "$port_lease_ports_file")

prompts=$work/prompts.tsv
printf 'code\twrite a function\nprose\texplain a limit\n' >"$prompts"

state_directory=$work/fake-state
run_harness() {
    run_output_directory=$1
    run_mechanism=$2
    run_subject=$3
    shift 3
    env QWEN_MODEL_REGISTRY="$registry" \
        QWEN_DRAFT_PAIRS="$pairs" \
        QWEN_QUARANTINE_REGISTRY="$quarantine" \
        QWEN_MODELS_DIRECTORY="$model_root" \
        QWEN_PRODUCTION_BUILD_DIR="$build_directory" \
        QWEN_VULKAN_WORKLOAD_LOCK="$workload_lock" \
        QWEN_MTP_ARM_PRIORITY_WRAPPER="$priority_wrapper" \
        QWEN_MTP_ARM_VULKAN_WRAPPER="$vulkan_wrapper" \
        QWEN_MTP_ARM_PORT="$measurement_port" \
        QWEN_SERVER_PORT="$appliance_port" \
        QWEN_MTP_ARM_PROMPTS="$prompts" \
        QWEN_MTP_ARM_PREDICT=64 \
        QWEN_MTP_ARM_READY_SECONDS=20 \
        QWEN_MTP_TEST_WRAPPER_LOG="$wrapper_log" \
        QWEN_FAKE_MTP_PORT="$measurement_port" \
        QWEN_FAKE_MTP_STATE_DIRECTORY="$state_directory" \
        "$@" \
        "$harness" "$run_mechanism" "$run_subject" "$run_output_directory"
}

summary_field() {
    sed -n "s/^$2=//p" "$1/summary.txt"
}

# A three-depth sweep of the embedded head. Every depth's speculative arms are
# faster than its controls and every acceptance clears the break-even, so the
# run completes and each gate accepts.
healthy=$work/healthy
if run_harness "$healthy" draft-mtp fake-target \
    QWEN_MTP_ARM_N_MAX='1 2 3' \
    QWEN_FAKE_MTP_DECODE_TOK_S=3.10 \
    QWEN_FAKE_MTP_SPEC_TOK_S_N1=3.60 \
    QWEN_FAKE_MTP_SPEC_TOK_S_N2=3.40 \
    QWEN_FAKE_MTP_SPEC_TOK_S_N3=3.20 \
    QWEN_FAKE_MTP_ACCEPTANCE_N1=0.90 \
    QWEN_FAKE_MTP_ACCEPTANCE_N2=0.88 \
    QWEN_FAKE_MTP_ACCEPTANCE_N3=0.86 \
    >"$work/healthy.log" 2>&1; then
    report healthy_exit accepted
else
    report healthy_exit rejected
    cat "$work/healthy.log" >&2
fi
report healthy_state "$(equal "$(summary_field "$healthy" state)" completed)"
report healthy_determinism "$(summary_field "$healthy" control_determinism_gate)"
report healthy_token_identity "$(summary_field "$healthy" token_identity_gate)"
report healthy_performance "$(summary_field "$healthy" performance_gate)"
report healthy_acceptance "$(summary_field "$healthy" acceptance_gate)"
report healthy_target_unmet \
    "$([ "$(summary_field "$healthy" target_gate)" = rejected ] &&
        printf 'accepted\n' || printf 'rejected\n')"
report healthy_depths \
    "$([ "$(summary_field "$healthy" performance_depths)" = '1,2,3' ] &&
        printf 'accepted\n' || printf 'rejected\n')"

# Four arms at each of three draft lengths is twelve servers, and each records
# its own argv.
launch_count=$(find "$state_directory" -name 'argv-*.txt' | wc -l | tr -d '[:space:]')
report healthy_launch_count \
    "$([ "$launch_count" = 12 ] && printf 'accepted\n' || printf 'rejected\n')"
control_argv=$(grep -l '^spec_type=none$' "$state_directory"/argv-*.txt | wc -l |
    tr -d '[:space:]')
report healthy_control_launches \
    "$([ "$control_argv" = 6 ] && printf 'accepted\n' || printf 'rejected\n')"
for expected_depth in 1 2 3; do
    depth_launches=$(grep -l "^draft_n_max=$expected_depth\$" \
        "$state_directory"/argv-*.txt | wc -l | tr -d '[:space:]')
    report "healthy_depth_${expected_depth}_launches" \
        "$([ "$depth_launches" = 2 ] && printf 'accepted\n' || printf 'rejected\n')"
done
report healthy_metrics_flag \
    "$([ "$(grep -c '^argument=--metrics$' "$state_directory"/argv-*.txt |
        awk -F: '{ total += $2 } END { print total }')" = 12 ] &&
        printf 'accepted\n' || printf 'rejected\n')"
# The lease descriptor is closed inside a child shell and the variable reaches
# the server empty, so a server the harness launches holds neither.
report healthy_lease_withheld \
    "$(grep -h '^lease=$' "$state_directory"/argv-*.txt | wc -l |
        awk '{ print ($1 == 12) ? "accepted" : "rejected" }')"
report healthy_wrapper_chain \
    "$([ "$(grep -c '^vulkan command=' "$wrapper_log")" = 12 ] &&
        printf 'accepted\n' || printf 'rejected\n')"
report healthy_breakeven_rows \
    "$([ "$(wc -l <"$healthy/breakeven.tsv" | tr -d '[:space:]')" = 4 ] &&
        printf 'accepted\n' || printf 'rejected\n')"
report healthy_execution_check \
    "$(awk -F'\t' 'NR == 2 { print $6 }' "$healthy/summarizer-execution-check.tsv")"
report healthy_identity_check \
    "$(awk -F'\t' 'NR > 1 && $7 != "accepted" { bad = 1 }
        END { print bad ? "rejected" : "accepted" }' "$healthy/identity-check.tsv")"

# The standalone pairing runs the same quadruple with a second checkpoint and
# reaches the pair ledger for its draft path, cache triple, and floor.
rm -rf "$state_directory"
paired=$work/paired
if run_harness "$paired" draft-simple fake-pair \
    QWEN_MTP_ARM_N_MAX='2' \
    QWEN_FAKE_MTP_DECODE_TOK_S=3.10 \
    QWEN_FAKE_MTP_SPEC_TOK_S_N2=3.40 \
    QWEN_FAKE_MTP_ACCEPTANCE_N2=0.88 \
    >"$work/paired.log" 2>&1; then
    report paired_exit accepted
else
    report paired_exit rejected
    cat "$work/paired.log" >&2
fi
report paired_state "$(equal "$(summary_field "$paired" state)" completed)"
report paired_draft_model \
    "$(grep -c "^argument=$model_root/Draft/draft.gguf\$" \
        "$state_directory"/argv-*.txt | awk -F: '{ total += $2 }
        END { print (total == 2) ? "accepted" : "rejected" }')"
report paired_acceptance_floor \
    "$([ "$(summary_field "$paired" acceptance_floor)" = 0.700 ] &&
        printf 'accepted\n' || printf 'rejected\n')"

# An acceptance below break-even leaves the summary completed with the
# performance and acceptance gates rejected, so the rate columns stay readable.
rm -rf "$state_directory"
slow=$work/slow
run_harness "$slow" draft-mtp fake-target \
    QWEN_MTP_ARM_N_MAX='1' \
    QWEN_FAKE_MTP_DECODE_TOK_S=3.10 \
    QWEN_FAKE_MTP_SPEC_TOK_S_N1=2.80 \
    QWEN_FAKE_MTP_ACCEPTANCE_N1=0.30 \
    >"$work/slow.log" 2>&1 || true
report slow_state "$(equal "$(summary_field "$slow" state)" completed)"
report slow_performance \
    "$([ "$(summary_field "$slow" performance_gate)" = rejected ] &&
        printf 'accepted\n' || printf 'rejected\n')"

# The /metrics read is unordered against the response write, so a counter that
# moves further than the response reports is named on the steps_agreement line
# and leaves every rate and gate intact.
rm -rf "$state_directory"
skewed=$work/skewed
if run_harness "$skewed" draft-mtp fake-target \
    QWEN_MTP_ARM_N_MAX='1' \
    QWEN_FAKE_MTP_SPEC_TOK_S_N1=3.60 \
    QWEN_FAKE_MTP_ACCEPTANCE_N1=0.90 \
    QWEN_FAKE_MTP_STEP_SKEW=2 \
    >"$work/skewed.log" 2>&1; then
    report skewed_exit accepted
else
    report skewed_exit rejected
    cat "$work/skewed.log" >&2
fi
report skewed_state "$(equal "$(summary_field "$skewed" state)" completed)"
report skewed_agreement \
    "$(equal "$(summary_field "$skewed" steps_agreement)" disagree)"
report skewed_performance \
    "$(equal "$(summary_field "$skewed" performance_gate)" accepted)"

# A server holding no /metrics route leaves the same columns readable, since
# the step count the tokens imply needs nothing from that route.
rm -rf "$state_directory"
unmetered=$work/unmetered
if run_harness "$unmetered" draft-mtp fake-target \
    QWEN_MTP_ARM_N_MAX='1' \
    QWEN_FAKE_MTP_SPEC_TOK_S_N1=3.60 \
    QWEN_FAKE_MTP_ACCEPTANCE_N1=0.90 \
    QWEN_FAKE_MTP_OMIT_METRICS=1 \
    >"$work/unmetered.log" 2>&1; then
    report unmetered_exit accepted
else
    report unmetered_exit rejected
    cat "$work/unmetered.log" >&2
fi
report unmetered_state "$(equal "$(summary_field "$unmetered" state)" completed)"
report unmetered_agreement \
    "$(equal "$(summary_field "$unmetered" steps_agreement)" absent)"

# Argument and ledger refusals, each before any server starts.
rm -rf "$state_directory"
refusal() {
    refusal_name=$1
    refusal_status=$2
    shift 2
    set +e
    "$@" >"$work/$refusal_name.log" 2>&1
    observed_status=$?
    set -e
    report "$refusal_name" \
        "$([ "$observed_status" = "$refusal_status" ] &&
            printf 'accepted\n' || printf 'rejected\n')"
}
refusal refuse_unknown_mechanism 2 \
    run_harness "$work/unknown" draft-eagle3 fake-target
refusal refuse_zero_draft_length 2 \
    run_harness "$work/zero" draft-mtp fake-target QWEN_MTP_ARM_N_MAX='0'
refusal refuse_draft_length_past_step 2 \
    run_harness "$work/deep" draft-mtp fake-target QWEN_MTP_ARM_N_MAX='1 4'
refusal refuse_repeated_draft_length 2 \
    run_harness "$work/repeat" draft-mtp fake-target QWEN_MTP_ARM_N_MAX='1 1'
refusal refuse_existing_output 2 \
    run_harness "$healthy" draft-mtp fake-target QWEN_MTP_ARM_N_MAX='1'
refusal refuse_quarantined_pair 1 \
    run_harness "$work/stopped-pair" draft-simple stopped-pair
refusal refuse_quarantined_model 1 \
    run_harness "$work/stopped-model" draft-mtp stopped-target
report refuse_started_no_server \
    "$([ ! -d "$state_directory" ] && printf 'accepted\n' || printf 'rejected\n')"

# A held lease refuses the run rather than overlapping another Vulkan workload.
held=$work/held
(
    exec 8>"$workload_lock"
    flock -n 8
    set +e
    run_harness "$held" draft-mtp fake-target QWEN_MTP_ARM_N_MAX='1' \
        >"$work/held.log" 2>&1
    lease_status=$?
    set -e
    exit "$lease_status"
) && lease_result=0 || lease_result=$?
report refuse_held_lease \
    "$([ "$lease_result" = 2 ] && printf 'accepted\n' || printf 'rejected\n')"
report refuse_held_lease_claims_nothing \
    "$([ ! -d "$held" ] && printf 'accepted\n' || printf 'rejected\n')"

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
