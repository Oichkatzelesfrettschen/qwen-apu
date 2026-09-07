#!/bin/sh
set -eu

# Drive run-checkpoint-baseline.sh and summarize-checkpoint-baseline.py over
# scratch fixtures with no device, no build, and no launch chain.
#
# The harness resolves the launcher, the teardown, the sidecar, the sidecar
# validator, the lease verifier, the quiescence poller, the registry reader, and
# the summarizer through its own directory, so the whole run executes from a
# scratch tree carrying stubs for the four device-owning links -- the launch
# chain, the clock sampler, the clock validator, and the Vulkan lease verifier
# -- beside the tree's own readers. remote/test-fixtures/fake-llama-server.sh is
# the served process: it answers /health, one streamed /completion whose first
# content delta the time-to-first-token record is stamped at, and one
# non-streamed /completion carrying the token array and the timings object every
# repeat is read from.
#
# Token divergence is exercised against the summarizer rather than the fake
# server, because the fake server answers one token array for the life of one
# process and every repeat of an arm runs inside one launch. The summarizer is
# where identity is computed and reported, so the case that matters is a
# retained arm whose two repeats carry different arrays.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$(basename "$0")" >&2
    printf 'Drives the checkpoint baseline runner over scratch fixtures.\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
harness=$script_directory/run-checkpoint-baseline.sh
summarizer=$script_directory/summarize-checkpoint-baseline.py
port_lease=$script_directory/test-port-lease.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
model_id=qwen38-2b-distill
series_sha256=1111111111111111111111111111111111111111111111111111111111111111

temporary_directory=$(mktemp -d)
port_holder=''
active_fixture=initialization
diagnostic_file=
cleanup() {
    cleanup_status=$?
    if [ "$cleanup_status" -ne 0 ]; then
        printf 'checkpoint baseline fixture failed: %s (status %s)\n' \
            "$active_fixture" "$cleanup_status" >&2
        if [ -n "$diagnostic_file" ] && [ -f "$diagnostic_file" ]; then
            sed -n '1,60p' "$diagnostic_file" >&2
        fi
    fi
    [ -z "$port_holder" ] || "$port_lease" release "$port_holder" || :
    rm -r -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

"$port_lease" claim 1 "$temporary_directory/ports" >"$temporary_directory/holder"
port_holder=$(cat "$temporary_directory/holder")
serving_port=$(sed -n '1p' "$temporary_directory/ports")

# The scratch tree the harness runs from. qwen-home.sh derives the runtime root
# as .runtime beside the tree holding remote/, so the fixture copies that
# resolver and lays the root out itself rather than exporting QWEN_HOME, which
# would replace the derivation for every script at once.
tree_root=$temporary_directory/tree
scratch=$tree_root/remote
runtime_root=$tree_root/.runtime
state_directory=$runtime_root/state
models_directory=$runtime_root/models
mkdir -p "$scratch" "$state_directory" "$models_directory"
for carried in qwen-home.sh census-arm-lib.sh checkpoint-baseline-lib.sh \
    model-registry.sh models.tsv ctx-checkpoints.tsv quarantine.tsv \
    validated-tuples.tsv draft-pairs.tsv model-artifacts.tsv; do
    [ -e "$script_directory/$carried" ] || continue
    cp -- "$script_directory/$carried" "$scratch/$carried"
done
cp -- "$harness" "$scratch/run-checkpoint-baseline.sh"
cp -- "$summarizer" "$scratch/summarize-checkpoint-baseline.py"
chmod +x "$scratch/run-checkpoint-baseline.sh" "$scratch/summarize-checkpoint-baseline.py"

registry_field() {
    "$script_directory/model-registry.sh" id "$model_id" "$1"
}
model_file=$(registry_field model_file)
# The stub launcher writes the registry row's own tuple into the served argv,
# since the arm compares the two and a fixture stating unrelated numbers would
# exercise the projection while leaving the comparison unreached.
tuple_context=$(registry_field context_default)
tuple_batch=$(registry_field batch)
tuple_ubatch=$(registry_field ubatch)
tuple_cache_k=$(registry_field cache_type_k)
tuple_cache_v=$(registry_field cache_type_v)
tuple_flash=$(registry_field flash_attention)
tuple_checkpoints=$("$script_directory/model-registry.sh" ctx-checkpoint "$model_id")
model_path=$models_directory/$model_file
mkdir -p "$(dirname -- "$model_path")"
printf 'fixture checkpoint bytes\n' >"$model_path"
model_bytes=$(wc -c <"$model_path" | tr -d ' ')
model_sha256=$(sha256sum "$model_path" | cut -d ' ' -f 1)

# The artifact ledger is the publisher-identity authority the preflight compares
# the resolved file against, so the fixture states the row its own bytes satisfy
# and the moved-model case rewrites the file underneath it.
artifact_ledger=$scratch/model-artifacts.tsv
printf '%s\t%s\t%s\t%s\t-\t-\n' "$model_id" "$model_file" "$model_bytes" \
    "$model_sha256" >"$artifact_ledger"

# Two servers, each with the manifest census_bind_server binds it to. The bytes
# differ so the bracket's two roles are two executables, and each is compiled
# rather than written as a script because census_base_build_identity reads the
# compiler string out of the executable's own .comment section and refuses an
# image carrying none.
build_server() {
    server_root=$temporary_directory/$1
    mkdir -p "$server_root/bin"
    printf 'const char *role = "%s";\nint main(void) { return 0; }\n' "$1" \
        >"$server_root/server.c"
    cc -o "$server_root/bin/llama-server" "$server_root/server.c"
    server_bytes=$(wc -c <"$server_root/bin/llama-server" | tr -d ' ')
    server_sha256=$(sha256sum "$server_root/bin/llama-server" | cut -d ' ' -f 1)
    {
        printf 'executable\tllama-server\t%s\t%s\n' "$server_bytes" "$server_sha256"
        printf 'checkpoint_semantics\tnatural-boundary-v1\n'
        printf 'checkpoint_patch_series_sha256\t%s\n' "$series_sha256"
        printf 'commit\tf280b269\n'
        printf 'checkpoint_patch_sha256\tc9d40105c9d40105c9d40105c9d40105c9d40105c9d40105c9d40105c9d40105\n'
        printf 'checkpoint_source_sha256\t3744317b3744317b3744317b3744317b3744317b3744317b3744317b3744317b\n'
        printf 'compiler_flags\t-O3\n'
        printf 'cmake_flags\t-DGGML_VULKAN=ON\n'
    } >"$server_root/artifact-manifest.tsv"
    printf '%s\n' "$server_root/bin/llama-server"
}
control_server=$(build_server control-build)
candidate_server=$(build_server candidate-build)

# The launch chain stands in for itself: the stub starts the fake server on the
# leased port, writes the session status the served-tuple reader takes the pid
# from, and lays down the three runtime logs the arm retains. The argv it writes
# into the status carries the tuple flags a real capacity policy would have
# built, so the reader is exercised on the shape it reads in production.
cat >"$scratch/qwen-launch.sh" <<LAUNCH
#!/bin/sh
set -eu
state=$state_directory
# The fake server replaces itself with its own python listener, so the argv the
# served-tuple reader projects the tuple out of lives in the shell that spawned
# it: the trailing exit keeps that shell from being exec-optimized away, and its
# /proc entry carries the flags a capacity policy would have built.
QWEN_FAKE_SERVER_PORT=$serving_port \\
QWEN_FAKE_SERVER_STATE_DIRECTORY="\$state/fake-server" \\
QWEN_FAKE_SERVER_TOKENS="\${QWEN_FIXTURE_TOKENS:-10 11 12 13 14 15 16 17}" \\
QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S=0.05 \\
    sh -c '"\$0" "\$@"; exit \$?' $fake_server \\
    --port $serving_port --ctx-size \${QWEN_FIXTURE_CONTEXT:-$tuple_context} \\
    --batch-size $tuple_batch --ubatch-size $tuple_ubatch \\
    --cache-type-k $tuple_cache_k --cache-type-v $tuple_cache_v \\
    --flash-attn $tuple_flash --ctx-checkpoints $tuple_checkpoints \\
    >"\$state/server.log" 2>&1 &
server_pid=\$!
printf '%s\n' "\$server_pid" >"\$state/server.pid"
printf 'state=running server_pid=%s\n' "\$server_pid" >"\$state/session.status"
printf 'probe_utc=fixture p90_ms=1.0\n' >"\$state/graphics-latency.log"
printf 'hazard_pattern=fixture\nwatch_stop_utc=fixture reason=server_exited\n' \\
    >"\$state/kernel-hazards.log"
deadline=0
while [ "\$deadline" -lt 100 ]; do
    if curl --silent --fail --max-time 2 http://127.0.0.1:$serving_port/health \\
        >/dev/null 2>&1; then
        exit 0
    fi
    deadline=\$((deadline + 1))
    sleep 0.1
done
exit 1
LAUNCH
cat >"$scratch/qwen-teardown.sh" <<TEARDOWN
#!/bin/sh
set -eu
state=$state_directory
if [ -s "\$state/server.pid" ]; then
    kill "\$(cat "\$state/server.pid")" 2>/dev/null || :
    rm -f -- "\$state/server.pid"
fi
exit 0
TEARDOWN

# The clock sampler and its validator are the campaign's two device readers. The
# sampler stub writes the record shape the summarizer counts rows of; the
# validator stub accepts unless the case asks it to refuse. Both are what the
# absent-sidecar case removes.
cat >"$scratch/sample-clock-sidecar.py" <<'SIDECAR'
#!/bin/sh
set -eu
output=$1
if [ -n "${QWEN_FIXTURE_SIDECAR_SILENT:-}" ]; then
    sleep 30
    exit 0
fi
{
    printf 'monotonic_ns\tsclk_mhz\tmclk_mhz\tedge_c\n'
    printf '1000\t1100\t933\t70\n'
    printf '2000\t1100\t933\t71\n'
} >"$output"
sleep 30
SIDECAR
cat >"$scratch/validate-clock-sidecar.py" <<'VALIDATOR'
#!/bin/sh
set -eu
record=$1
if [ ! -s "$record" ]; then
    printf 'clock record is absent or empty: %s\n' "$record" >&2
    exit 1
fi
printf 'clock_invariant=held\n'
VALIDATOR
cat >"$scratch/verify-external-vulkan-lease.py" <<'LEASE'
#!/bin/sh
exit 0
LEASE
cat >"$scratch/await-quiescence.sh" <<'QUIESCE'
#!/bin/sh
printf 'quiescence=reached\n'
QUIESCE
chmod +x "$scratch/qwen-launch.sh" "$scratch/qwen-teardown.sh" \
    "$scratch/sample-clock-sidecar.py" "$scratch/validate-clock-sidecar.py" \
    "$scratch/verify-external-vulkan-lease.py" "$scratch/await-quiescence.sh"

# The lease this campaign runs under belongs to compute-state-lease.sh, so the
# fixture reproduces the hand-down: descriptor 8 open on the state directory's
# own lock leaf and the proof path forwarded beside it.
lease_lock=$state_directory/vulkan-workload.lock
: >"$lease_lock"
lease_proof=$state_directory/lease-proof.tsv
printf 'key\tvalue\nschema\tfixed64-vulkan-external-lease-v1\n' >"$lease_proof"

run_harness() {
    run_output=$1
    shift
    diagnostic_file=$temporary_directory/run.log
    set +e
    env "$@" \
        QWEN_STATE_DIRECTORY="$state_directory" \
        QWEN_MODELS_DIRECTORY="$models_directory" \
        QWEN_SERVER_PORT="$serving_port" \
        QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
        QWEN_DRM_DEVICE="$temporary_directory/drm" \
        QWEN_BASELINE_COOLDOWN_S=0 \
        QWEN_BASELINE_READY_DEADLINE_S=30 \
        QWEN_BENCH_GENERATE=8 \
        QWEN_BASELINE_REPEATS=2 \
        QWEN_LLAMA_SERVER="$control_server" \
        sh -c 'exec "$0" "$@" 8<>"'"$lease_lock"'"' \
        "$scratch/run-checkpoint-baseline.sh" "$model_id" "$run_output" \
        >"$temporary_directory/run.log" 2>&1
    run_status=$?
    set -e
    return "$run_status"
}

# The graphics clock table the invariant reads its required step from.
mkdir -p "$temporary_directory/drm"
printf '0: 200Mhz\n1: 400Mhz\n2: 1100Mhz *\n' >"$temporary_directory/drm/pp_dpm_sclk"

active_fixture=completed_single_arm
if ! run_harness "$temporary_directory/single"; then
    printf 'the single-checkpoint form failed on a healthy fixture\n' >&2
    exit 1
fi
summary=$temporary_directory/single/summary.tsv
for required_row in 'schema	checkpoint-baseline-summary-v1' 'token_identity	held' \
    'arms	1'; do
    if ! grep -qx "$required_row" "$summary"; then
        printf 'the summary omits the row %s\n' "$required_row" >&2
        cat "$summary" >&2
        exit 1
    fi
done
arm_directory=$temporary_directory/single/arms/01-subject
for required_artifact in load.tsv ttft.tsv decode-rows.tsv served-tuple.tsv \
    clock-samples.tsv repeats/01/tokens.txt repeats/02/response.json \
    graphics-latency.log kernel-hazards.log; do
    if [ ! -s "$arm_directory/$required_artifact" ]; then
        printf 'the arm retained no %s\n' "$required_artifact" >&2
        exit 1
    fi
done
# The tuple the summary rests on is the one the launched process ran under
# rather than the registry row the policy read, so it is compared against the
# argv the stub launcher gave the served process.
if ! grep -qx "context	$tuple_context" "$arm_directory/served-tuple.tsv" || \
    ! grep -qx "batch	$tuple_batch" "$arm_directory/served-tuple.tsv" || \
    ! grep -qx "ctx_checkpoints	$tuple_checkpoints" "$arm_directory/served-tuple.tsv"; then
    printf 'the served tuple was not projected out of the process argv\n' >&2
    cat "$arm_directory/served-tuple.tsv" >&2
    exit 1
fi
if ! grep -q '^ttft_ms	' "$arm_directory/ttft.tsv"; then
    printf 'the arm recorded no time to first token\n' >&2
    exit 1
fi
# The two request bodies are two digests, since the streamed request and the
# decode request differ in shape and a run carrying one would leave the other
# unstated.
identity=$temporary_directory/single/identity.tsv
ttft_digest=$(awk -F'\t' '$1 == "ttft_request_sha256" { print $2 }' "$identity")
decode_digest=$(awk -F'\t' '$1 == "decode_request_sha256" { print $2 }' "$identity")
if [ -z "$ttft_digest" ] || [ "$ttft_digest" = "$decode_digest" ]; then
    printf 'the two request bodies did not bind two digests: %s %s\n' \
        "${ttft_digest:--}" "${decode_digest:--}" >&2
    exit 1
fi

active_fixture=summary_recomputation
if ! "$summarizer" "$temporary_directory/single" >/dev/null; then
    printf 'the retained summary differs from its own recomputation\n' >&2
    exit 1
fi

active_fixture=summary_refuses_absent_response
mutated=$temporary_directory/mutated
cp -r -- "$temporary_directory/single" "$mutated"
rm -- "$mutated/arms/01-subject/repeats/02/response.json"
if "$summarizer" "$mutated" >/dev/null 2>"$temporary_directory/absent.log"; then
    printf 'the summarizer accepted an arm whose repeat retained no response\n' >&2
    exit 1
fi
if ! grep -q 'retained no response' "$temporary_directory/absent.log"; then
    printf 'the summarizer named another reason for an absent response\n' >&2
    cat "$temporary_directory/absent.log" >&2
    exit 1
fi

active_fixture=summary_refuses_absent_clock_record
mutated_clock=$temporary_directory/mutated-clock
cp -r -- "$temporary_directory/single" "$mutated_clock"
rm -- "$mutated_clock/arms/01-subject/clock-samples.tsv"
if "$summarizer" "$mutated_clock" >/dev/null 2>"$temporary_directory/clock.log"; then
    printf 'the summarizer accepted an arm carrying no clock record\n' >&2
    exit 1
fi
if ! grep -q 'clock sidecar record is absent' "$temporary_directory/clock.log"; then
    printf 'the summarizer named another reason for an absent clock record\n' >&2
    cat "$temporary_directory/clock.log" >&2
    exit 1
fi

active_fixture=token_identity_mismatch_is_reported
diverged=$temporary_directory/diverged
cp -r -- "$temporary_directory/single" "$diverged"
diverged_arm=$diverged/arms/01-subject
printf '900\n901\n' >"$diverged_arm/repeats/02/tokens.txt"
diverged_digest=$(sha256sum "$diverged_arm/repeats/02/tokens.txt" | cut -d ' ' -f 1)
awk -F'\t' -v OFS='\t' -v digest="$diverged_digest" \
    'NR == 1 || $1 != "02" { print; next } { $6 = digest; print }' \
    "$diverged_arm/decode-rows.tsv" >"$diverged_arm/decode-rows.tsv.new"
mv -- "$diverged_arm/decode-rows.tsv.new" "$diverged_arm/decode-rows.tsv"
rm -f -- "$diverged/summary.tsv"
if ! "$summarizer" "$diverged" --write >/dev/null; then
    printf 'the summarizer refused an arm whose repeats diverged\n' >&2
    exit 1
fi
if ! grep -qx 'token_identity	diverged' "$diverged/summary.tsv"; then
    printf 'the summary did not report the token divergence\n' >&2
    cat "$diverged/summary.tsv" >&2
    exit 1
fi

active_fixture=summary_refuses_a_row_its_tokens_disagree_with
tampered=$temporary_directory/tampered
cp -r -- "$temporary_directory/single" "$tampered"
printf '900\n901\n' >"$tampered/arms/01-subject/repeats/02/tokens.txt"
if "$summarizer" "$tampered" >/dev/null 2>"$temporary_directory/tamper.log"; then
    printf 'the summarizer accepted a token file its retained digest denies\n' >&2
    exit 1
fi
if ! grep -q 'token digest differs' "$temporary_directory/tamper.log"; then
    printf 'the summarizer named another reason for a tampered token file\n' >&2
    cat "$temporary_directory/tamper.log" >&2
    exit 1
fi

active_fixture=absent_clock_sidecar_fails_the_arm
if QWEN_FIXTURE_SIDECAR_SILENT=1 run_harness "$temporary_directory/no-sidecar" \
    QWEN_FIXTURE_SIDECAR_SILENT=1; then
    printf 'the runner completed an arm whose sidecar retained no record\n' >&2
    exit 1
fi
if ! grep -q 'clock_invariant' "$temporary_directory/no-sidecar/arms.tsv"; then
    printf 'the arm ledger named another reason for an unsampled arm\n' >&2
    cat "$temporary_directory/no-sidecar/arms.tsv" >&2
    exit 1
fi

active_fixture=a_served_tuple_that_left_the_registry_row_fails_the_arm
if QWEN_FIXTURE_CONTEXT=8192 run_harness "$temporary_directory/tuple-moved" \
    QWEN_FIXTURE_CONTEXT=8192; then
    printf 'the runner measured a server whose depth left the registry row\n' >&2
    exit 1
fi
if ! grep -q 'tuple_mismatch' "$temporary_directory/tuple-moved/arms.tsv"; then
    printf 'the arm ledger named another reason for a moved tuple\n' >&2
    cat "$temporary_directory/tuple-moved/arms.tsv" >&2
    exit 1
fi

active_fixture=identity_binding_refuses_a_moved_model
printf 'fixture checkpoint bytes replaced under the ledger\n' >"$model_path"
if run_harness "$temporary_directory/moved"; then
    printf 'the runner measured a checkpoint whose bytes the ledger denies\n' >&2
    exit 1
fi
if ! grep -q 'publisher identity' "$temporary_directory/run.log"; then
    printf 'the runner named another reason for a moved model\n' >&2
    cat "$temporary_directory/run.log" >&2
    exit 1
fi
printf 'fixture checkpoint bytes\n' >"$model_path"

active_fixture=bracket_runs_the_mirrored_quadruple
diagnostic_file=$temporary_directory/bracket.log
set +e
env QWEN_STATE_DIRECTORY="$state_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_SERVER_PORT="$serving_port" \
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
    QWEN_DRM_DEVICE="$temporary_directory/drm" \
    QWEN_BASELINE_COOLDOWN_S=0 QWEN_BASELINE_READY_DEADLINE_S=30 \
    QWEN_BENCH_GENERATE=8 QWEN_BASELINE_REPEATS=2 \
    sh -c 'exec "$0" "$@" 8<>"'"$lease_lock"'"' \
    "$scratch/run-checkpoint-baseline.sh" --bracket "$control_server" \
    "$candidate_server" "$model_id" "$temporary_directory/bracket" \
    >"$temporary_directory/bracket.log" 2>&1
bracket_status=$?
set -e
if [ "$bracket_status" -ne 0 ]; then
    printf 'the bracket form failed on a healthy fixture\n' >&2
    exit 1
fi
for expected_arm in 01-control 02-candidate 03-candidate 04-control; do
    if [ ! -d "$temporary_directory/bracket/arms/$expected_arm" ]; then
        printf 'the bracket did not run the arm %s\n' "$expected_arm" >&2
        ls "$temporary_directory/bracket/arms" >&2
        exit 1
    fi
done
if ! grep -q '^candidate_over_control	[0-9]' \
    "$temporary_directory/bracket/summary.tsv"; then
    printf 'the bracket summary reports no role ratio\n' >&2
    cat "$temporary_directory/bracket/summary.tsv" >&2
    exit 1
fi

active_fixture=bracket_refuses_one_executable_twice
set +e
env QWEN_STATE_DIRECTORY="$state_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_SERVER_PORT="$serving_port" \
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF="$lease_proof" \
    QWEN_DRM_DEVICE="$temporary_directory/drm" \
    sh -c 'exec "$0" "$@" 8<>"'"$lease_lock"'"' \
    "$scratch/run-checkpoint-baseline.sh" --bracket "$control_server" \
    "$control_server" "$model_id" "$temporary_directory/one-binary" \
    >"$temporary_directory/one-binary.log" 2>&1
one_binary_status=$?
set -e
if [ "$one_binary_status" -eq 0 ]; then
    printf 'the bracket compared one executable against itself\n' >&2
    exit 1
fi
if ! grep -q 'one executable' "$temporary_directory/one-binary.log"; then
    printf 'the bracket named another reason for one executable twice\n' >&2
    cat "$temporary_directory/one-binary.log" >&2
    exit 1
fi

active_fixture=lease_inheritance_is_required
set +e
env QWEN_STATE_DIRECTORY="$state_directory" \
    QWEN_MODELS_DIRECTORY="$models_directory" \
    QWEN_SERVER_PORT="$serving_port" \
    QWEN_DRM_DEVICE="$temporary_directory/drm" \
    QWEN_LLAMA_SERVER="$control_server" \
    "$scratch/run-checkpoint-baseline.sh" "$model_id" \
    "$temporary_directory/no-lease" >"$temporary_directory/no-lease.log" 2>&1
lease_status=$?
set -e
if [ "$lease_status" -eq 0 ]; then
    printf 'the runner ran outside a compute-state lease transaction\n' >&2
    exit 1
fi
if ! grep -q 'compute-state-lease.sh' "$temporary_directory/no-lease.log"; then
    printf 'the runner named another reason for an absent lease\n' >&2
    cat "$temporary_directory/no-lease.log" >&2
    exit 1
fi

diagnostic_file=
printf 'checkpoint baseline fixtures passed\n'
