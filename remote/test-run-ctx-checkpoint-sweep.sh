#!/bin/sh
set -eu

# Drive run-ctx-checkpoint-sweep.sh against a fake server whose prefill cost
# depends on the checkpoint count each launch received. The fixtures prove the
# mirrored arm order, the environment the launch stub was handed, a positive
# prefill saving on every arm above zero and none at zero, the token-identity
# check reporting the first divergent index and failing the run, and the
# refusal while a llama-server process exists.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
harness=$script_directory/run-ctx-checkpoint-sweep.sh
fake_server=$script_directory/test-fixtures/fake-ctx-checkpoint-server.py
temporary_directory=$(mktemp -d)
active_fixture=initialization
diagnostic_file=
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'ctx checkpoint fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            sed -n '1,80p' "$diagnostic_file" >&2
        fi
    fi
    if [ -s "$temporary_directory/state/fake-server.pid" ]; then
        kill "$(cat "$temporary_directory/state/fake-server.pid")" 2>/dev/null || true
    fi
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

if command -v pgrep >/dev/null 2>&1 && pgrep -x llama-server >/dev/null 2>&1; then
    printf 'ctx_checkpoint_sweep_test=not_run reason=llama-server-running\n' >&2
    exit 1
fi

fake_port=18123
models_directory=$temporary_directory/models
registry=$temporary_directory/models.tsv
mkdir -p "$models_directory/Fake-GGUF"
: >"$models_directory/Fake-GGUF/fake.gguf"
# A registry with one row whose ceiling admits the test depth.
{
    sed -n '/^#/p' "$script_directory/models.tsv"
    printf 'fake-2b\tfast-text\tFake-GGUF/fake.gguf\tnone.sh\t24576\t32768\t131072\tq8_0\tq4_0\ton\tnone\t-\t-\t-\t-\tcandidate\t128\t32\t32768\t-\t-\trefused\n'
} >"$registry"

state_directory=$temporary_directory/state
mkdir -p "$state_directory"
launch_log=$temporary_directory/launch-env.log

# The launch stub records the environment the chain would forward, starts the
# fake server with the checkpoint count as its cost model, and writes the
# session status and log files the harness copies.
fake_launch=$temporary_directory/fake-launch.sh
cat >"$fake_launch" <<EOF
#!/bin/sh
set -eu
printf 'ctx_checkpoints=%s model=%s profile=%s\\n' "\${QWEN_CTX_CHECKPOINTS:-unset}" "\${QWEN_MODEL_PATH:-unset}" "\$1" >>"$launch_log"
printf 'launch ctx_checkpoints=%s\\n' "\${QWEN_CTX_CHECKPOINTS:-unset}" >"$state_directory/server.log"
printf 'state=running server_pid=0\\n' >"$state_directory/session.status"
printf 'fake-key\\n' >"$state_directory/api.key"
QWEN_FAKE_CTX_CHECKPOINTS=\${QWEN_CTX_CHECKPOINTS:-0} \\
    python3 "$fake_server" $fake_port >/dev/null 2>&1 &
printf '%s\\n' "\$!" >"$state_directory/fake-server.pid"
attempt=0
while ! curl --silent --fail --max-time 1 http://127.0.0.1:$fake_port/health >/dev/null 2>&1; do
    attempt=\$((attempt + 1))
    [ "\$attempt" -lt 100 ] || exit 1
    sleep 0.05
done
EOF
chmod +x "$fake_launch"
fake_teardown=$temporary_directory/fake-teardown.sh
cat >"$fake_teardown" <<EOF
#!/bin/sh
set -eu
kill "\$(cat "$state_directory/fake-server.pid")" 2>/dev/null || true
wait 2>/dev/null || true
attempt=0
while curl --silent --fail --max-time 1 http://127.0.0.1:$fake_port/health >/dev/null 2>&1; do
    attempt=\$((attempt + 1))
    [ "\$attempt" -lt 100 ] || exit 1
    sleep 0.05
done
printf 'torn down\\n' >>"$temporary_directory/teardown.log"
EOF
chmod +x "$fake_teardown"

run_harness() {
    QWEN_LAUNCH_SCRIPT=$fake_launch QWEN_TEARDOWN_SCRIPT=$fake_teardown \
        QWEN_STATE_DIRECTORY=$state_directory QWEN_SERVER_PORT=$fake_port \
        QWEN_MODEL_REGISTRY=$registry QWEN_MODELS_DIRECTORY=$models_directory \
        QWEN_CTX_TARGET_DEPTH=2000 QWEN_CTX_PREDICT=8 \
        "$harness" "$@"
}

active_fixture=mirrored-sweep
diagnostic_file=$temporary_directory/sweep.stderr
sweep_output=$temporary_directory/sweep
run_harness fixture fake-2b "$sweep_output" \
    >"$temporary_directory/sweep.stdout" 2>"$temporary_directory/sweep.stderr"
grep -F 'ctx_checkpoint_sweep=completed' "$temporary_directory/sweep.stdout" >/dev/null

# The launch stub met the eight arms in mirrored order with the count in its
# environment and the registry model path beside it.
launched_order=$(sed -n 's/^ctx_checkpoints=\([0-9]*\) .*/\1/p' "$launch_log" | tr '\n' ' ')
if [ "$launched_order" != '0 2 4 8 8 4 2 0 ' ]; then
    printf 'arm order reached the launch as: %s\n' "$launched_order" >&2
    exit 1
fi
grep -F "model=$models_directory/Fake-GGUF/fake.gguf profile=low-async" \
    "$launch_log" >/dev/null
if [ "$(wc -l <"$temporary_directory/teardown.log")" -ne 8 ]; then
    printf 'each arm did not end in a teardown\n' >&2
    exit 1
fi

# summary.tsv carries the header, sixteen rows in arm order, prompt_n inside
# 2% of the target on every turn 1, a saving at or below zero at zero
# checkpoints because turn 2 re-prefills the longer prompt whole, a saving
# above zero elsewhere, and a decode rate computed from the timings.
summary=$sweep_output/summary.tsv
if [ "$(sed -n '1p' "$summary")" != \
'arm	ctx_checkpoints	turn	prompt_n	prompt_ms	predicted_n	predicted_ms	prompt_tok_s	decode_tok_s	prefill_saved_ms' ]; then
    printf 'summary header differs\n' >&2
    exit 1
fi
if [ "$(wc -l <"$summary")" -ne 17 ]; then
    printf 'summary row count differs from sixteen\n' >&2
    cat "$summary" >&2
    exit 1
fi
awk -F'\t' 'NR > 1 && $3 == 1 && ($4 + 0 < 1960 || $4 + 0 > 2040) { bad = 1 }
            NR > 1 && $3 == 2 && $2 == 0 && $10 + 0 > 0 { bad = 1 }
            NR > 1 && $3 == 2 && $2 > 0 && $10 + 0 <= 0 { bad = 1 }
            NR > 1 && $3 == 2 && $2 > 0 && $5 + 0 >= 100 { bad = 1 }
            NR > 1 && $6 != 8 { bad = 1 }
            NR > 1 && $9 != "100.000" { bad = 1 }
            END { exit bad }' "$summary" || {
    printf 'summary rows carry the wrong saving, depth, or rate\n' >&2
    cat "$summary" >&2
    exit 1
}
grep -F 'divergence=none' "$sweep_output/divergence.txt" >/dev/null
test -s "$sweep_output/arm-4-c8/server.log"
grep -F 'launch ctx_checkpoints=8' "$sweep_output/arm-4-c8/server.log" >/dev/null
test -s "$sweep_output/arm-1-c0/turn2.tokens"
test -s "$sweep_output/prompt-depth.txt"

# A shifted token sequence on one count fails the run and names the index.
active_fixture=token-divergence
diagnostic_file=$temporary_directory/diverge.stderr
: >"$launch_log"
diverge_output=$temporary_directory/diverge
if QWEN_FAKE_DIVERGE_AT=4 QWEN_CTX_CHECKPOINT_ARMS='0 4 0' \
    run_harness diverge fake-2b "$diverge_output" \
    >"$temporary_directory/diverge.stdout" 2>"$temporary_directory/diverge.stderr"; then
    printf 'the sweep accepted a token divergence\n' >&2
    exit 1
fi
grep -F 'ctx_checkpoint_sweep=failed' "$temporary_directory/diverge.stderr" >/dev/null
grep -F 'turn=2 arm=2 ctx_checkpoints=4 divergence=0 against=arm 1' \
    "$diverge_output/divergence.txt" >/dev/null
grep -F 'turn=2 arm=3 ctx_checkpoints=0 divergence=none' \
    "$diverge_output/divergence.txt" >/dev/null

# A non-integer arm and a depth at the ceiling are argument errors.
active_fixture=argument-errors
if run_harness bad fake-2b "$temporary_directory/bad" 2>/dev/null \
    QWEN_CTX_CHECKPOINT_ARMS=two; then
    printf 'a fourth argument was accepted\n' >&2
    exit 1
fi
if QWEN_CTX_CHECKPOINT_ARMS='0 two' run_harness bad fake-2b \
    "$temporary_directory/bad" 2>"$temporary_directory/bad.stderr"; then
    printf 'a non-integer arm was accepted\n' >&2
    exit 1
fi
grep -F 'checkpoint arms must be non-negative integers' \
    "$temporary_directory/bad.stderr" >/dev/null
if QWEN_LAUNCH_SCRIPT=$fake_launch QWEN_TEARDOWN_SCRIPT=$fake_teardown \
    QWEN_STATE_DIRECTORY=$state_directory QWEN_MODEL_REGISTRY=$registry \
    QWEN_MODELS_DIRECTORY=$models_directory QWEN_CTX_TARGET_DEPTH=32768 \
    "$harness" bad fake-2b "$temporary_directory/bad" \
    2>"$temporary_directory/bad.stderr"; then
    printf 'a depth at the ceiling was accepted\n' >&2
    exit 1
fi
grep -F 'reaches the registry ceiling' "$temporary_directory/bad.stderr" >/dev/null

# A llama-server process refuses the run before any launch.
active_fixture=process-contention
contender_directory=$temporary_directory/contender
mkdir -p "$contender_directory"
ln -s /bin/sleep "$contender_directory/llama-server"
"$contender_directory/llama-server" 30 &
contender_pid=$!
contender_attempt=0
while ! pgrep -x llama-server >/dev/null 2>&1 && [ "$contender_attempt" -lt 20 ]; do
    contender_attempt=$((contender_attempt + 1))
    sleep 0.05
done
: >"$launch_log"
if run_harness contended fake-2b "$temporary_directory/contended" \
    2>"$temporary_directory/contended.stderr"; then
    kill "$contender_pid" 2>/dev/null || true
    printf 'the sweep ran beside a llama-server process\n' >&2
    exit 1
fi
kill "$contender_pid" 2>/dev/null || true
wait "$contender_pid" 2>/dev/null || true
grep -F 'llama-server is running' "$temporary_directory/contended.stderr" >/dev/null
if [ -s "$launch_log" ]; then
    printf 'the contended run reached the launch\n' >&2
    exit 1
fi

printf 'ctx_checkpoint_sweep_test=accepted\n'
