#!/bin/sh
set -eu

# run-prefill-ladder.sh loads a model once per arm on the Vulkan device, so what
# a workstation checks is the ledger the runner writes around those loads. The
# fake llama-server answers /health, /tokenize, and a streamed /completion with
# timings, which is every route the ladder reads, and its variables drive the
# refusals the ladder exists to make: a tokenize multiplier that leaves the
# prompt-length loop oscillating, a prompt_n skew that separates the served
# count from the tokenized one, an omitted timings object, a predicted_n skew
# that reports a decoded count other than the one requested, a
# prompt_per_second override for a rate the counts cannot back, and the
# first-chunk delay a time to first token measures. It also records its own
# launch environment and /proc-read nice value, which is what proves the
# ladder applied the production submission profile and priority to the arm
# rather than only claiming to.
#
# Each run below is a whole ladder over one admitted depth and two inadmissible
# ones, so the skip path and the failure path are read from the same ledger and
# a later edit that conflates them fails here.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ladder=$script_directory/run-prefill-ladder.sh
fixture_server=$script_directory/test-fixtures/fake-llama-server.sh
temporary_directory=$(mktemp -d)
cleanup() {
    cleanup_status=$?
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

root=$temporary_directory/root
mkdir -p "$root/models/fixture" "$root/stubs" "$root/state"
printf 'fixture model\n' >"$root/models/fixture/model.gguf"
printf '{}\n' >"$root/radeon_icd.x86_64.json"
# The device gate reads the process table, where another session's llama-server
# would refuse this fixture before any arm starts.
printf '#!/bin/sh\nexit 1\n' >"$root/stubs/pgrep"
chmod +x "$root/stubs/pgrep"

# The registry stub answers the two selectors the ladder reads: one model row
# and the validated tuple ledger the thread quadruple takes its thread count
# from. The tuple row states threads 2 against the ladder's own one thread.
cat >"$root/model-registry.sh" <<'REGISTRY_STUB'
#!/bin/sh
set -eu
if [ "$1" = tuples ]; then
    printf 'fixture-d128-b128-ub32\tmodel-id\tstandalone\t128\t128\t32\tq8_0\tq4_0\ton\t2\t1\tnone\tvulkan\tvalidated\tevidence/fixture/\t-\t-\t-\t-\t-\t2026-09-01\n'
    exit 0
fi
[ "$#" -eq 3 ] || exit 0
case $3 in
    model_file) printf 'fixture/model.gguf\n' ;;
    batch) printf '128\n' ;;
    ubatch) printf '32\n' ;;
    cache_type_k) printf 'q8_0\n' ;;
    cache_type_v) printf 'q4_0\n' ;;
    flash_attention) printf 'on\n' ;;
    context_ceiling) printf '256\n' ;;
    validated_filled_depth) printf '128\n' ;;
    *) exit 1 ;;
esac
REGISTRY_STUB
chmod +x "$root/model-registry.sh"

# The runner hands each arm a closed environment, so the fixture's own settings
# reach it through a wrapper that states them rather than through the invoking
# shell. The port comes off the argv the runner built, which is the same value
# the readiness poll uses.
write_server() {
    write_server_path=$1
    write_server_label=$2
    shift 2
    {
        printf '#!/bin/sh\nset -eu\n'
        printf '# fixture server %s\n' "$write_server_label"
        printf 'server_port=\nwhile [ "$#" -gt 0 ]; do\n'
        printf '    if [ "$1" = --port ]; then server_port=$2; fi\n'
        printf '    shift\ndone\n'
        printf 'export QWEN_FAKE_SERVER_PORT=$server_port\n'
        printf 'export QWEN_FAKE_SERVER_STATE_DIRECTORY=%s\n' "$root/argv"
        for write_server_assignment in "$@"; do
            printf 'export %s\n' "$write_server_assignment"
        done
        printf 'exec %s "$@"\n' "$fixture_server"
    } >"$write_server_path"
    chmod +x "$write_server_path"
}

run_ladder() {
    run_ladder_output=$1
    shift
    run_ladder_status=0
    env PATH="$root/stubs:$PATH" \
        QWEN_MODEL_REGISTRY_SCRIPT="$root/model-registry.sh" \
        QWEN_MODELS_DIRECTORY="$root/models" \
        QWEN_RADV_ICD="$root/radeon_icd.x86_64.json" \
        QWEN_WEBUI_STATE_DIRECTORY="$root/state" \
        QWEN_PREFILL_LADDER_PORT=18097 QWEN_SERVER_PORT=18096 \
        QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY=auto \
        QWEN_PREFILL_LADDER_SAMPLER=off \
        QWEN_PREFILL_LADDER_DEPTHS='8 124 200' \
        QWEN_PREFILL_LADDER_GENERATE=2 \
        QWEN_PREFILL_LADDER_TAIL_RESERVE=4 \
        QWEN_PREFILL_LADDER_READY_SECONDS=30 \
        QWEN_PREFILL_LADDER_COOLDOWN_S=0 \
        QWEN_PREFILL_LADDER_PROMPT_N_SLACK=0 \
        "$@" \
        "$ladder" "$root/control-server" "$root/candidate-server" model-id \
        "$run_ladder_output" >"$run_ladder_output.log" 2>&1 || run_ladder_status=$?
    printf '%s\n' "$run_ladder_status"
}

ledger_field() {
    awk -F'\t' -v depth="$2" -v quadruple="$3" -v slot="$4" -v column="$5" '
        NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
        $index_of["depth"] == depth && $index_of["quadruple"] == quadruple {
            seen++
            if (seen == slot) { print $index_of[column]; exit } }' "$1"
}

# The healthy ladder. One depth is admitted unclamped, one requested depth
# clamps to the allocation's own headroom limit, and one is refused for sitting
# above the row's deepest measured fill. The registry stub names
# validated_filled_depth 128 and context_ceiling 256, so the allocation is 128;
# at QWEN_PREFILL_LADDER_GENERATE=2, QWEN_PREFILL_LADDER_TAIL_RESERVE=4, and the
# prompt-count slack pinned to 0 above (the dedicated
# prompt_ceiling_subtracts_prompt_n_slack case below covers a nonzero slack),
# the ceiling a prompt may reach is 128 - 2 - 4 - 0 = 122, which is below the
# requested depth 124 and above the requested depth 8.
write_server "$root/control-server" control QWEN_FAKE_SERVER_PROMPT_TOK_S=20.00
write_server "$root/candidate-server" candidate QWEN_FAKE_SERVER_PROMPT_TOK_S=25.00 \
    QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S=0.05
healthy_output=$root/healthy
healthy_status=$(run_ladder "$healthy_output")
healthy_arms=$healthy_output/arms.tsv
if [ "$healthy_status" -eq 0 ] && [ -s "$healthy_arms" ]; then
    report 0 healthy_ladder_exits_zero
else
    report 1 healthy_ladder_exits_zero
    sed -n '1,40p' "$healthy_output.log" >&2
fi

# A depth above validated_filled_depth is skipped with its reason rather than
# measured, and a skipped depth leaves the exit status at zero.
skip_state=0
if ! awk -F'\t' -v depth=200 -v reason=above_validated_filled_depth '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["depth"] == depth {
        rows++
        if ($index_of["status"] == "skipped" && $index_of["reason"] == reason) matched++ }
    END { exit (rows > 0 && rows == matched) ? 0 : 1 }' "$healthy_arms"; then
    skip_state=1
    printf 'depth 200 is not recorded skipped with reason above_validated_filled_depth\n' >&2
fi
report "$skip_state" depth_above_validated_depth_is_skipped_with_reason

# The requested depth 124 leaves the allocation no room for its own tail, so it
# clamps to 122 rather than being skipped or submitted at 124: the ledger keys
# every one of its rows on the clamped count, and inputs.tsv states the
# requested-to-actual mapping so a reader knows 124 became 122 rather than
# vanishing. A prompt at or above the 128-token allocation is never constructed:
# tokenize_n and prompt_n stay "-" on every skipped row, since no prompt was
# ever built or sent for it, so a completed or failed row is what the headroom
# rule binds, and none of those reaches the allocation.
clamp_state=0
if ! awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["depth"] == 122 { rows++
        if ($index_of["status"] == "completed") completed++ }
    END { exit (rows > 0 && rows == completed) ? 0 : 1 }' "$healthy_arms"; then
    clamp_state=1
    printf 'depth 122 (the clamp of requested depth 124) carries no completed row\n' >&2
fi
if ! awk -F'\t' '$1 == "depths_admitted_requested_actual" && index($2, "124=122") {
    matched = 1 } END { exit matched ? 0 : 1 }' "$healthy_output/inputs.tsv"; then
    clamp_state=1
    printf 'inputs.tsv does not carry the requested-to-actual mapping 124=122\n' >&2
fi
if ! awk -F'\t' -v ceiling=128 '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["status"] == "skipped" { next }
    { for (n in index_of) {
          name = n
          if (name != "tokenize_n" && name != "prompt_n") continue
          value = $index_of[name]
          if (value == "-") continue
          if (value + 0 >= ceiling) { print "column=" name " value=" value; bad++ } } }
    END { exit (bad == 0) ? 0 : 1 }' "$healthy_arms"; then
    clamp_state=1
    printf 'a constructed prompt reaches or exceeds the 128-token allocation\n' >&2
fi
report "$clamp_state" requested_depth_beyond_headroom_clamps_and_never_reaches_the_allocation

# The mirrored order is what makes the first subject replicate pair with the
# first control replicate, so the ledger states it arm by arm.
order_state=0
binary_order=$(awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["depth"] == 8 && $index_of["quadruple"] == "binary" {
        printf "%s ", $index_of["arm"] }' "$healthy_arms")
threads_order=$(awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["depth"] == 8 && $index_of["quadruple"] == "threads" {
        printf "%s ", $index_of["arm"] }' "$healthy_arms")
[ "$binary_order" = 'C K K C ' ] || {
    order_state=1
    printf 'binary quadruple order reads [%s]\n' "$binary_order" >&2
}
[ "$threads_order" = 'C T T C ' ] || {
    order_state=1
    printf 'thread quadruple order reads [%s]\n' "$threads_order" >&2
}
report "$order_state" abba_order_recorded

# The thread quadruple runs the control server at the registry row's own thread
# count against the ladder's one thread, which is the difference it states.
thread_state=0
[ "$(ledger_field "$healthy_arms" 8 threads 1 threads)" = 1 ] || thread_state=1
[ "$(ledger_field "$healthy_arms" 8 threads 2 threads)" = 2 ] || thread_state=1
report "$thread_state" thread_quadruple_states_the_registry_row_threads

# Both binaries are recorded by digest, in the inputs and on every arm.
digest_state=0
control_digest=$(sha256sum "$root/control-server" | cut -d ' ' -f 1)
candidate_digest=$(sha256sum "$root/candidate-server" | cut -d ' ' -f 1)
[ "$control_digest" != "$candidate_digest" ] || digest_state=1
for digest_pair in "control_server_sha256 $control_digest" \
    "candidate_server_sha256 $candidate_digest"; do
    digest_key=${digest_pair%% *}
    digest_value=${digest_pair#* }
    if ! awk -F'\t' -v key="$digest_key" -v value="$digest_value" \
        '$1 == key { count++; if ($2 == value) matched++ }
        END { exit (count == 1 && matched == 1) ? 0 : 1 }' "$healthy_output/inputs.tsv"; then
        digest_state=1
        printf 'inputs.tsv does not carry %s as %s\n' "$digest_key" "$digest_value" >&2
    fi
done
if ! awk -F'\t' -v control="$control_digest" -v candidate="$candidate_digest" '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["status"] == "completed" {
        if ($index_of["server_sha256"] == control) seen_control++
        if ($index_of["server_sha256"] == candidate) seen_candidate++ }
    END { exit (seen_control > 0 && seen_candidate > 0) ? 0 : 1 }' "$healthy_arms"; then
    digest_state=1
    printf 'arms.tsv carries no completed arm under each server digest\n' >&2
fi
report "$digest_state" both_server_digests_recorded

# The production low-async submission profile radv-low-priority-env.sh selects
# for a served rate, and nice 19, reach every arm's server directly: the ladder
# starts each server itself rather than through that script, so the ladder's
# own census_arm_exec assignments and its own renice are what have to carry
# them. The fixture's own record_launch reads these straight from its
# environment and from /proc/$$/stat, independently of the ladder's own
# readback into arms.tsv, so the two are two readers of the same state.
profile_state=0
argv_files=$(find "$root/argv" -maxdepth 1 -name 'argv-*.txt')
if [ -z "$argv_files" ]; then
    profile_state=1
    printf 'no server launch recorded its argv under %s\n' "$root/argv" >&2
fi
for argv_file in $argv_files; do
    for expected in 'low=1' 'max_nodes=16' 'profile=low-async' 'nice=19' 'strict=1'; do
        if ! grep -qF "$expected" "$argv_file"; then
            profile_state=1
            printf '%s does not carry %s\n' "$argv_file" "$expected" >&2
        fi
    done
done
if ! awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["status"] == "completed" {
        total++
        if ($index_of["server_nice"] == 19) matched++ }
    END { exit (total > 0 && total == matched) ? 0 : 1 }' "$healthy_arms"; then
    profile_state=1
    printf 'arms.tsv does not record server_nice=19 on every completed arm\n' >&2
fi
report "$profile_state" every_arm_runs_under_low_async_and_nice_19

# prompt_ceiling subtracts the prompt-count slack, so an admitted depth still
# leaves room for the served BOS overshoot /completion may add above the
# tokenized count. The registry stub's 128-token allocation, generate 2, tail
# reserve 4, and a slack of 6 put the ceiling at 128 - 2 - 4 - 6 = 116; the lone
# requested depth 124 sits above it and clamps there rather than to 122, the
# value a slack-blind ceiling would still report.
slack_output=$root/slack
slack_status=$(run_ladder "$slack_output" \
    QWEN_PREFILL_LADDER_DEPTHS=124 QWEN_PREFILL_LADDER_PROMPT_N_SLACK=6)
slack_state=0
if [ "$slack_status" -ne 0 ]; then
    slack_state=1
    printf 'the slack ladder exited %s\n' "$slack_status" >&2
fi
if ! awk -F'\t' '$1 == "prompt_ceiling" && $2 == 116 { matched = 1 }
    END { exit matched ? 0 : 1 }' "$slack_output/inputs.tsv"; then
    slack_state=1
    printf 'inputs.tsv does not carry prompt_ceiling 116\n' >&2
fi
if ! awk -F'\t' '$1 == "depths_admitted_requested_actual" && index($2, "124=116") {
    matched = 1 } END { exit matched ? 0 : 1 }' "$slack_output/inputs.tsv"; then
    slack_state=1
    printf 'inputs.tsv does not carry the requested-to-actual mapping 124=116\n' >&2
fi
report "$slack_state" prompt_ceiling_subtracts_prompt_n_slack

# The manual engine clock policy's operating point is derived from the
# confirmed sclk/mclk selections at run time; a workstation harness has no
# sysfs to pin those selections against, so this guards the source against the
# literal string regressing rather than driving the manual branch itself.
operating_point_state=0
if grep -q 'manual-gfx1100-fclk933' "$ladder"; then
    operating_point_state=1
    printf '%s still names the literal operating point manual-gfx1100-fclk933\n' \
        "$ladder" >&2
fi
report "$operating_point_state" operating_point_derived_from_selected_clocks_not_hard_coded

# The summary reads a ratio per depth, quadruple, and metric, over the pairs the
# mirrored order produced.
summary_state=0
summary=$healthy_output/summary.tsv
for summary_case in 'binary ttft_ms' 'binary prompt_tok_s' 'threads prompt_tok_s'; do
    summary_quadruple=${summary_case%% *}
    summary_metric=${summary_case#* }
    if ! awk -F'\t' -v quadruple="$summary_quadruple" -v metric="$summary_metric" '
        NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
        $index_of["depth"] == 8 && $index_of["quadruple"] == quadruple \
            && $index_of["metric"] == metric {
            rows++
            if ($index_of["mean_ratio"] + 0 > 0 && $index_of["replicates"] == 2) matched++ }
        END { exit (rows == 1 && matched == 1) ? 0 : 1 }' "$summary"; then
        summary_state=1
        printf 'summary carries no measured %s ratio for the %s quadruple\n' \
            "$summary_metric" "$summary_quadruple" >&2
    fi
done
if ! awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["depth"] == 200 && $index_of["verdict"] == "skipped" { matched++ }
    END { exit matched > 0 ? 0 : 1 }' "$summary"; then
    summary_state=1
    printf 'summary does not carry the skipped depth\n' >&2
fi
report "$summary_state" summary_reports_ratio_per_depth_and_metric

# A tokenizer that never lands on the requested count leaves the prompt-length
# loop oscillating, which is refused rather than measured at some other length.
write_server "$root/control-server" control QWEN_FAKE_SERVER_TOKENIZE_MULTIPLIER=2
write_server "$root/candidate-server" candidate QWEN_FAKE_SERVER_TOKENIZE_MULTIPLIER=2
unconverged_output=$root/unconverged
unconverged_status=$(run_ladder "$unconverged_output" QWEN_PREFILL_LADDER_ATTEMPTS=4)
if [ "$unconverged_status" -ne 0 ] && awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["reason"] == "prompt_length_unconverged" { matched++ }
    END { exit matched > 0 ? 0 : 1 }' "$unconverged_output/arms.tsv"; then
    report 0 prompt_length_unconverged_refuses_the_arm
else
    report 1 prompt_length_unconverged_refuses_the_arm
    sed -n '1,40p' "$unconverged_output.log" >&2
fi

# A served prompt count away from the tokenized one is the mismatch the
# verification exists to catch.
write_server "$root/control-server" control QWEN_FAKE_SERVER_PROMPT_N_SKEW=5
write_server "$root/candidate-server" candidate QWEN_FAKE_SERVER_PROMPT_N_SKEW=5
mismatch_output=$root/mismatch
mismatch_status=$(run_ladder "$mismatch_output")
if [ "$mismatch_status" -ne 0 ] && awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["reason"] == "prompt_n_mismatch" { matched++ }
    END { exit matched > 0 ? 0 : 1 }' "$mismatch_output/arms.tsv"; then
    report 0 prompt_count_verified_against_tokenize
else
    report 1 prompt_count_verified_against_tokenize
    sed -n '1,40p' "$mismatch_output.log" >&2
fi

# A reply whose timings object omits a field fails its arm and leaves every rate
# column unknown, since a rate of nothing pairs as a measurement.
write_server "$root/control-server" control QWEN_FAKE_SERVER_OMIT_TIMINGS=1
write_server "$root/candidate-server" candidate QWEN_FAKE_SERVER_OMIT_TIMINGS=1
timings_output=$root/timings
timings_status=$(run_ladder "$timings_output")
if [ "$timings_status" -ne 0 ] && awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["reason"] == "missing_timings" {
        matched++
        if ($index_of["prompt_tok_s"] != "-" || $index_of["ttft_ms"] != "-" \
            || $index_of["prompt_ms"] != "-") filled++ }
    END { exit (matched > 0 && filled == 0) ? 0 : 1 }' "$timings_output/arms.tsv"; then
    report 0 missing_timings_fails_the_arm_rather_than_filling_zeros
else
    report 1 missing_timings_fails_the_arm_rather_than_filling_zeros
    sed -n '1,40p' "$timings_output.log" >&2
fi

# A server that decoded a different count than the one requested answered a
# different request than the one the ladder posted, so predicted_n away from
# generate_tokens fails the arm rather than pairing two unlike completions
# under one label.
write_server "$root/control-server" control QWEN_FAKE_SERVER_PREDICTED_N_SKEW=1
write_server "$root/candidate-server" candidate QWEN_FAKE_SERVER_PREDICTED_N_SKEW=1
predicted_n_output=$root/predicted-n
predicted_n_status=$(run_ladder "$predicted_n_output")
if [ "$predicted_n_status" -ne 0 ] && awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["reason"] == "predicted_n_mismatch" { matched++ }
    END { exit matched > 0 ? 0 : 1 }' "$predicted_n_output/arms.tsv"; then
    report 0 predicted_n_verified_against_the_requested_generate_tokens
else
    report 1 predicted_n_verified_against_the_requested_generate_tokens
    sed -n '1,40p' "$predicted_n_output.log" >&2
fi

# A zero prompt_per_second reaches the summarizer as a real ratio of zero
# rather than a rate no request measured, so a nonpositive timing fails the arm
# the way a missing one does.
write_server "$root/control-server" control \
    QWEN_FAKE_SERVER_PROMPT_PER_SECOND_OVERRIDE=0
write_server "$root/candidate-server" candidate \
    QWEN_FAKE_SERVER_PROMPT_PER_SECOND_OVERRIDE=0
nonpositive_output=$root/nonpositive
nonpositive_status=$(run_ladder "$nonpositive_output")
if [ "$nonpositive_status" -ne 0 ] && awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
    $index_of["reason"] == "timings_nonpositive" {
        matched++
        if ($index_of["prompt_tok_s"] != "-") filled++ }
    END { exit (matched > 0 && filled == 0) ? 0 : 1 }' "$nonpositive_output/arms.tsv"; then
    report 0 nonpositive_timing_fails_the_arm_rather_than_pairing_a_zero_rate
else
    report 1 nonpositive_timing_fails_the_arm_rather_than_pairing_a_zero_rate
    sed -n '1,40p' "$nonpositive_output.log" >&2
fi

# The argument contract, refused ahead of any server start.
refuses() {
    refuses_name=$1
    refuses_phrase=$2
    shift 2
    refuses_log=$temporary_directory/$refuses_name.log
    refuses_status=0
    env PATH="$root/stubs:$PATH" \
        QWEN_MODEL_REGISTRY_SCRIPT="$root/model-registry.sh" \
        QWEN_MODELS_DIRECTORY="$root/models" \
        QWEN_RADV_ICD="$root/radeon_icd.x86_64.json" \
        QWEN_WEBUI_STATE_DIRECTORY="$root/state" \
        QWEN_PREFILL_LADDER_PORT=18097 QWEN_SERVER_PORT=18096 \
        QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY=auto \
        QWEN_PREFILL_LADDER_SAMPLER=off \
        "$@" \
        "$ladder" "$root/control-server" "$root/candidate-server" model-id \
        "$root/refused-$refuses_name" >"$refuses_log" 2>&1 || refuses_status=$?
    if [ "$refuses_status" -eq 2 ] && grep -q "$refuses_phrase" "$refuses_log" &&
        [ ! -e "$root/refused-$refuses_name" ]; then
        report 0 "$refuses_name"
    else
        report 1 "$refuses_name"
        printf 'status=%s log:\n' "$refuses_status" >&2
        sed -n '1,20p' "$refuses_log" >&2
    fi
}
refuses generate_zero 'QWEN_PREFILL_LADDER_GENERATE is a canonical positive integer' \
    QWEN_PREFILL_LADDER_GENERATE=0
refuses sampler_word 'QWEN_PREFILL_LADDER_SAMPLER is python or off' \
    QWEN_PREFILL_LADDER_SAMPLER=broker
refuses filler_with_space \
    'QWEN_PREFILL_LADDER_FILLER is one word' \
    'QWEN_PREFILL_LADDER_FILLER=two words'
refuses thread_arms_equal_prefill_threads \
    'the thread quadruple compares two thread counts' \
    QWEN_PREFILL_LADDER_THREADS=2

# Two requested depths that would clamp to the same count share one ledger
# identity, so the whole invocation refuses ahead of any server start rather
# than merging their rows. At the ladder's own defaults (generate 16, tail
# reserve 32, prompt-count slack 1) against this registry stub's 128-token
# allocation, the ceiling a prompt may reach is 128 - 16 - 32 - 1 = 79; 100 and
# 120 both sit above that ceiling and at or below the 128-token
# validated_filled_depth, so both clamp to 79 rather than one of them being
# skipped for sitting beyond the row's deepest measured fill.
refuses clamped_depth_collision \
    'which a shallower requested depth already admitted' \
    QWEN_PREFILL_LADDER_DEPTHS='100 120'

# The python sampler configures the sidecar at nice 19 and at sidecar_cpu, and
# the validator invocation is where that configuration either reaches the
# check or silently drops it. A copy of the ladder stands beside stub
# sample-clock-sidecar.py and validate-clock-sidecar.py scripts, since both
# names resolve against the ladder's own directory rather than through an
# overridable variable; the stub sampler holds until terminated so
# sidecar_status differs from `-`, and the stub validator records its own argv
# ahead of printing an acceptance the ladder reads nothing else from.
sampler_run=$root/sampler-run
mkdir -p "$sampler_run"
cp -- "$ladder" "$sampler_run/run-prefill-ladder.sh"
cp -- "$script_directory/qwen-home.sh" "$sampler_run/qwen-home.sh"
chmod +x "$sampler_run/run-prefill-ladder.sh"
ln -s -- "$script_directory/census-arm-lib.sh" "$sampler_run/census-arm-lib.sh"
ln -s -- "$script_directory/summarize-prefill-ladder.py" \
    "$sampler_run/summarize-prefill-ladder.py"
validator_argv_log=$root/validator-argv.log
: >"$validator_argv_log"
cat >"$sampler_run/sample-clock-sidecar.py" <<'SAMPLER_STUB'
#!/usr/bin/env python3
# A stub standing in for the real sampler: it opens the record path the
# ladder names and holds until SIGTERM, the same shutdown the ladder drives
# every arm's real sampler through, so sidecar_status reads a real exit
# status rather than the sentinel a sampler that never started leaves.
import signal
import sys
import time

open(sys.argv[1], "w").close()
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
while True:
    time.sleep(3600)
SAMPLER_STUB
chmod +x "$sampler_run/sample-clock-sidecar.py"
cat >"$sampler_run/validate-clock-sidecar.py" <<'VALIDATOR_STUB'
#!/usr/bin/env python3
# The stub records its own argv ahead of the verdict it prints, so a case
# reads whether the harness's own configured priority and CPU set reached
# this invocation rather than being read back from a header it never wrote.
import os
import sys

argv_log = os.environ.get("QWEN_TEST_VALIDATOR_ARGV")
if argv_log:
    with open(argv_log, "a") as handle:
        handle.write(" ".join(sys.argv[1:]) + "\n")
print("clock_sidecar=accepted failures=-")
VALIDATOR_STUB
chmod +x "$sampler_run/validate-clock-sidecar.py"
sampler_output=$root/sampler-output
sampler_status=0
env PATH="$root/stubs:$PATH" \
    QWEN_MODEL_REGISTRY_SCRIPT="$root/model-registry.sh" \
    QWEN_MODELS_DIRECTORY="$root/models" \
    QWEN_RADV_ICD="$root/radeon_icd.x86_64.json" \
    QWEN_WEBUI_STATE_DIRECTORY="$root/state" \
    QWEN_PREFILL_LADDER_PORT=18097 QWEN_SERVER_PORT=18096 \
    QWEN_PREFILL_LADDER_ENGINE_CLOCK_POLICY=auto \
    QWEN_PREFILL_LADDER_SAMPLER=python \
    QWEN_PREFILL_LADDER_DEPTHS=8 \
    QWEN_PREFILL_LADDER_GENERATE=2 \
    QWEN_PREFILL_LADDER_TAIL_RESERVE=4 \
    QWEN_PREFILL_LADDER_READY_SECONDS=30 \
    QWEN_PREFILL_LADDER_COOLDOWN_S=0 \
    QWEN_PREFILL_LADDER_PROMPT_N_SLACK=0 \
    QWEN_TEST_VALIDATOR_ARGV="$validator_argv_log" \
    "$sampler_run/run-prefill-ladder.sh" "$root/control-server" "$root/candidate-server" \
    model-id "$sampler_output" >"$sampler_output.log" 2>&1 || sampler_status=$?
sampler_state=0
if [ ! -s "$validator_argv_log" ]; then
    sampler_state=1
    printf 'the validator stub recorded no invocation (ladder status %s)\n' \
        "$sampler_status" >&2
    sed -n '1,40p' "$sampler_output.log" >&2
fi
if ! grep -qE -- '--expected-nice 19( |$)' "$validator_argv_log" 2>/dev/null; then
    sampler_state=1
    printf 'no validator invocation carried --expected-nice 19\n' >&2
    cat "$validator_argv_log" >&2
fi
if ! grep -qE -- '--expected-cpu-affinity 0,1( |$)' "$validator_argv_log" 2>/dev/null; then
    sampler_state=1
    printf 'no validator invocation carried --expected-cpu-affinity 0,1\n' >&2
    cat "$validator_argv_log" >&2
fi
report "$sampler_state" python_sampler_declares_nice_and_affinity_to_the_validator

if [ "$failures" -ne 0 ]; then
    printf 'run_prefill_ladder_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'run_prefill_ladder_tests=passed\n'
