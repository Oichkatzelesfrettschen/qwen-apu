#!/bin/sh
set -eu

# run-prefill-ladder.sh loads a model once per arm on the Vulkan device, so what
# a workstation checks is the ledger the runner writes around those loads. The
# fake llama-server answers /health, /tokenize, and a streamed /completion with
# timings, which is every route the ladder reads, and four of its variables
# drive the refusals the ladder exists to make: a tokenize multiplier that
# leaves the prompt-length loop oscillating, a prompt_n skew that separates the
# served count from the tokenized one, an omitted timings object, and the
# first-chunk delay a time to first token measures.
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

# The healthy ladder. One depth is admitted and two are refused, one for sitting
# above the row's deepest measured fill and one for leaving the allocation no
# room to decode its own tail.
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
for skip_case in '200 above_validated_filled_depth' '124 insufficient_generation_headroom'; do
    skip_depth=${skip_case%% *}
    skip_reason=${skip_case#* }
    if ! awk -F'\t' -v depth="$skip_depth" -v reason="$skip_reason" '
        NR == 1 { for (i = 1; i <= NF; i++) index_of[$i] = i; next }
        $index_of["depth"] == depth {
            rows++
            if ($index_of["status"] == "skipped" && $index_of["reason"] == reason) matched++ }
        END { exit (rows > 0 && rows == matched) ? 0 : 1 }' "$healthy_arms"; then
        skip_state=1
        printf 'depth %s is not recorded skipped with reason %s\n' "$skip_depth" \
            "$skip_reason" >&2
    fi
done
report "$skip_state" depth_above_validated_depth_is_skipped_with_reason

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

if [ "$failures" -ne 0 ]; then
    printf 'run_prefill_ladder_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'run_prefill_ladder_tests=passed\n'
