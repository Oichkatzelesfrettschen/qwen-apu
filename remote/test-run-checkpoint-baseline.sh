#!/bin/sh
set -eu

# Match the served-baseline orchestration priority before launching fixtures.
renice --priority 0 --pid "$$" >/dev/null

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
model_id=qwen35-08b
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
acquisitions=$runtime_root/results
mkdir -p "$acquisitions"
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
summarizer=$scratch/summarize-checkpoint-baseline.py
chmod +x "$scratch/run-checkpoint-baseline.sh" "$scratch/summarize-checkpoint-baseline.py"

registry_field() {
    "$script_directory/model-registry.sh" id "$model_id" "$1"
}
model_file=$(registry_field model_file)
# The 8192-context subject differs from the launcher's 24576 default, so the
# fixture requires the runner to forward the registered context explicitly.
tuple_context=$(registry_field context_default)
tuple_batch=$(registry_field batch)
tuple_ubatch=$(registry_field ubatch)
tuple_cache_k=$(registry_field cache_type_k)
tuple_cache_v=$(registry_field cache_type_v)
tuple_flash=$(registry_field flash_attention)
tuple_checkpoints=$("$script_directory/model-registry.sh" ctx-checkpoint "$model_id")
tuple_variant=$(registry_field q4k_variant)
[ "$tuple_variant" != - ] || tuple_variant=production/4
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
    printf 'const char *role = "%s";\n\n' "$1" \
        >"$server_root/server.c"
    cat >>"$server_root/server.c" <<'SERVER'
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
static volatile sig_atomic_t child;
static void stop_child(int signal_number) { if (child > 0) kill(child, signal_number); }
int main(void) {
    fprintf(stderr, "ggml_vulkan: q4k_variant=%s q4k_rows=4\n", getenv("GGML_VK_Q4K_VARIANT"));
    signal(SIGTERM, stop_child);
    child = fork();
    if (child == 0) { execl(getenv("BASELINE_FAKE_SERVER"), "fake-server", (char *)0); _exit(127); }
    if (child < 0) return 2;
    int status;
    while (waitpid(child, &status, 0) < 0) { if (errno != EINTR) return 2; }
    return 0;
}
SERVER
    cc -Wall -Wextra -Werror -o "$server_root/bin/llama-server" "$server_root/server.c"
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
# The compiled fixture owns its Python listener and forwards termination.
# Its process exposes the bound executable and the serving tuple through procfs.
QWEN_FAKE_SERVER_PORT=$serving_port \\
QWEN_FAKE_SERVER_STATE_DIRECTORY="\$state/fake-server" \\
QWEN_FAKE_SERVER_TOKENS="\${QWEN_FIXTURE_TOKENS:-10 11 12 13 14 15 16 17}" \\
GGML_VK_Q4K_VARIANT=$tuple_variant \\
BASELINE_FAKE_SERVER=$fake_server \\
QWEN_FAKE_SERVER_DECODE_TOK_S=1000000 \\
QWEN_FAKE_SERVER_FIRST_TOKEN_DELAY_S=0.05 \\
    nice -n 19 "\$QWEN_LLAMA_SERVER" \\
    --model "$model_path" --threads 1 --threads-batch 1 --device Vulkan0 \\
    --n-gpu-layers all --parallel 1 --port $serving_port --ctx-size \${QWEN_FIXTURE_CONTEXT:-\${QWEN_CONTEXT_SIZE:-24576}} \\
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
#!/usr/bin/env python3
import os
import signal
import sys
import time
from pathlib import Path
running = True
def stop(signum, frame):
    global running
    running = False
signal.signal(signal.SIGTERM, stop)
if os.environ.get("QWEN_FIXTURE_SIDECAR_SILENT"):
    time.sleep(30)
    raise SystemExit(0)
with Path(sys.argv[1]).open("w") as output:
    output.write("monotonic_ns\tsclk_mhz\tmclk_mhz\tedge_c\n")
    while running:
        output.write(f"{time.monotonic_ns()}\t1100\t933\t70\n")
        output.flush()
        print("telemetry_broker=sampled monotonic_ns=1", file=sys.stderr, flush=True)
        time.sleep(0.02)
raise SystemExit(int(os.environ.get("QWEN_FIXTURE_SIDECAR_EXIT", "0")))
SIDECAR
cat >"$scratch/validate-clock-sidecar.py" <<'VALIDATOR'
#!/bin/sh
set -eu
record=$1
[ -s "$record" ] || exit 1
shift
while [ "$#" -gt 0 ]; do
    if [ "$1" = --sidecar-status ] && [ "$2" != 0 ]; then
        printf 'clock_sidecar=refused failures=sidecar_exit\n'
        exit 1
    fi
    shift
done
printf 'clock_invariant=held sclk_source=sclk_actual_mhz\nclock_sidecar=accepted failures=-\n'
VALIDATOR
cat >"$scratch/check-runtime-tree.sh" <<'RUNTIME'
#!/bin/sh
printf 'runtime_tree=verified\n'
RUNTIME
chmod +x "$scratch/check-runtime-tree.sh"
printf 'git_head\tfixture\n' >"$tree_root/runtime-tree-manifest.tsv"
cp "$script_directory/telemetry-broker.c" "$scratch/telemetry-broker.c"
sha256sum "$scratch/telemetry-broker.c" | cut -d ' ' -f 1 >"$scratch/sample-clock-sidecar.py.source-sha256"
cp "$script_directory/compute-state-lease.sh" "$scratch/compute-state-lease.sh"
printf 'key\tvalue\nprofile\tserve-baseline-fixed\nsnapshot_ksm_run\t1\napplied_ksm_run\t1\n' >"$temporary_directory/compute-state.tsv"
export QWEN_COMPUTE_STATE_PROFILE=serve-baseline-fixed
export QWEN_COMPUTE_STATE_RECORD=$temporary_directory/compute-state.tsv
export QWEN_CENSUS_BROKER=$scratch/sample-clock-sidecar.py
cat >"$scratch/verify-external-vulkan-lease.py" <<'LEASE'
#!/bin/sh
exit 0
LEASE
cat >"$scratch/await-quiescence.sh" <<'QUIESCE'
#!/bin/sh
[ "$#" -eq 5 ] && [ "$1" = --sclk-forced ] && [ "$2" = --max-seconds ] && [ "$4" = --drm-device ] || exit 2
[ "${QWEN_FIXTURE_QUIESCENCE_EXIT:-0}" -eq 0 ] || exit 1
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
        QWEN_BASELINE_COOLDOWN_S=1 \
        QWEN_BASELINE_READY_DEADLINE_S=30 \
        QWEN_BENCH_GENERATE=8 \
        QWEN_BASELINE_REPEATS=4 \
        QWEN_LLAMA_SERVER="$control_server" \
        sh -c 'exec "$0" "$@" 8<>"'"$lease_lock"'"' \
        "$scratch/run-checkpoint-baseline.sh" "$model_id" "$run_output" \
        >"$temporary_directory/run.log" 2>&1
    run_status=$?
    set -e
    return "$run_status"
}

# The graphics clock table the invariant reads its required step from.
mkdir -p "$temporary_directory/drm/hwmon/amdgpu"
printf 'amdgpu\n' >"$temporary_directory/drm/hwmon/amdgpu/name"
printf '1100000000\n' >"$temporary_directory/drm/hwmon/amdgpu/freq1_input"
printf '70000\n' >"$temporary_directory/drm/hwmon/amdgpu/temp1_input"
printf '2: 933Mhz *\n' >"$temporary_directory/drm/pp_dpm_mclk"
printf '50\n' >"$temporary_directory/drm/gpu_busy_percent"
printf '0: 200Mhz\n1: 400Mhz\n2: 1100Mhz *\n' >"$temporary_directory/drm/pp_dpm_sclk"

active_fixture=completed_single_arm
if ! run_harness "$acquisitions/single"; then
    printf 'the single-checkpoint form failed on a healthy fixture\n' >&2
    exit 1
fi
summary=$acquisitions/single/summary.tsv
for required_row in 'schema	checkpoint-baseline-summary-v2' 'within_binary_repeatability	held' \
    'arms	1'; do
    if ! grep -qx "$required_row" "$summary"; then
        printf 'the summary omits the row %s\n' "$required_row" >&2
        cat "$summary" >&2
        exit 1
    fi
done
arm_directory=$acquisitions/single/arms/01-subject
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
identity=$acquisitions/single/identity.tsv
ttft_digest=$(awk -F'\t' '$1 == "ttft_request_sha256" { print $2 }' "$identity")
decode_digest=$(awk -F'\t' '$1 == "decode_request_sha256" { print $2 }' "$identity")
if [ -z "$ttft_digest" ] || [ "$ttft_digest" = "$decode_digest" ]; then
    printf 'the two request bodies did not bind two digests: %s %s\n' \
        "${ttft_digest:--}" "${decode_digest:--}" >&2
    exit 1
fi

active_fixture=summary_recomputation
if ! "$summarizer" "$acquisitions/single" >/dev/null; then
    printf 'the retained summary differs from its own recomputation\n' >&2
    exit 1
fi

active_fixture=summary_refuses_absent_response
mutated=$temporary_directory/mutated
cp -r -- "$acquisitions/single" "$mutated"
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
cp -r -- "$acquisitions/single" "$mutated_clock"
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
cp -r -- "$acquisitions/single" "$diverged"
diverged_arm=$diverged/arms/01-subject
python3 - "$diverged_arm/repeats/02" <<'TOKENS'
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
response = json.loads((root / "response.json").read_text())
response["tokens"] = list(range(900, 908))
(root / "response.json").write_text(json.dumps(response))
(root / "tokens.txt").write_text("".join(f"{token}\n" for token in response["tokens"]))
TOKENS
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
if ! grep -qx 'within_binary_repeatability	diverged' "$diverged/summary.tsv"; then
    printf 'the summary did not report the token divergence\n' >&2
    cat "$diverged/summary.tsv" >&2
    exit 1
fi

active_fixture=summary_refuses_a_row_its_tokens_disagree_with
tampered=$temporary_directory/tampered
cp -r -- "$acquisitions/single" "$tampered"
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
if QWEN_FIXTURE_SIDECAR_SILENT=1 run_harness "$acquisitions/no-sidecar" \
    QWEN_FIXTURE_SIDECAR_SILENT=1; then
    printf 'the runner completed an arm whose sidecar retained no record\n' >&2
    exit 1
fi
if ! grep -q 'clock_invariant' "$acquisitions/no-sidecar/arms.tsv"; then
    printf 'the arm ledger named another reason for an unsampled arm\n' >&2
    cat "$acquisitions/no-sidecar/arms.tsv" >&2
    exit 1
fi

active_fixture=a_served_tuple_that_left_the_registry_row_fails_the_arm
if QWEN_FIXTURE_CONTEXT=16384 run_harness "$acquisitions/tuple-moved" \
    QWEN_FIXTURE_CONTEXT=16384; then
    printf 'the runner measured a server whose depth left the registry row\n' >&2
    exit 1
fi
if ! grep -q 'tuple_mismatch' "$acquisitions/tuple-moved/arms.tsv"; then
    printf 'the arm ledger named another reason for a moved tuple\n' >&2
    cat "$acquisitions/tuple-moved/arms.tsv" >&2
    exit 1
fi

active_fixture=identity_binding_refuses_a_moved_model
printf 'fixture checkpoint bytes replaced under the ledger\n' >"$model_path"
if run_harness "$acquisitions/moved"; then
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
    QWEN_BASELINE_COOLDOWN_S=1 QWEN_BASELINE_READY_DEADLINE_S=30 \
    QWEN_BENCH_GENERATE=8 QWEN_BASELINE_REPEATS=4 \
    sh -c 'exec "$0" "$@" 8<>"'"$lease_lock"'"' \
    "$scratch/run-checkpoint-baseline.sh" --bracket "$control_server" \
    "$candidate_server" "$model_id" "$acquisitions/bracket" \
    >"$temporary_directory/bracket.log" 2>&1
bracket_status=$?
set -e
if [ "$bracket_status" -ne 0 ]; then
    printf 'the bracket form failed on a healthy fixture\n' >&2
    exit 1
fi
for expected_arm in 01-control 02-candidate 03-candidate 04-control; do
    if [ ! -d "$acquisitions/bracket/arms/$expected_arm" ]; then
        printf 'the bracket did not run the arm %s\n' "$expected_arm" >&2
        ls "$acquisitions/bracket/arms" >&2
        exit 1
    fi
done
if ! grep -q '^candidate_over_control	[0-9]' \
    "$acquisitions/bracket/summary.tsv"; then
    printf 'the bracket summary reports no role ratio\n' >&2
    cat "$acquisitions/bracket/summary.tsv" >&2
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
    "$control_server" "$model_id" "$acquisitions/one-binary" \
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
    "$acquisitions/no-lease" >"$temporary_directory/no-lease.log" 2>&1
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

active_fixture=warmup_deadline_prevents_repeats
if run_harness "$acquisitions/warmup-timeout" QWEN_BASELINE_REQUEST_DEADLINE_S=1 \
    QWEN_FAKE_SERVER_STREAM_TOKEN_DELAY_S=0.3; then
    printf 'slow streamed warmup escaped its elapsed deadline\n' >&2
    exit 1
fi
[ ! -d "$acquisitions/warmup-timeout/arms/01-subject/repeats" ]
grep -q first_token "$acquisitions/warmup-timeout/arms.tsv"

active_fixture=incomplete_warmup_prevents_repeats
if run_harness "$acquisitions/warmup-truncated" QWEN_FAKE_SERVER_STREAM_TRUNCATED=1; then
    printf 'incomplete warmup admitted repeats\n' >&2
    exit 1
fi
[ ! -d "$acquisitions/warmup-truncated/arms/01-subject/repeats" ]

active_fixture=launch_elapsed_deadline
mkdir -p "$temporary_directory/launch-deadline"
printf '#!/bin/sh\nexec sleep 30\n' >"$temporary_directory/slow-launch.sh"
chmod +x "$temporary_directory/slow-launch.sh"
python3 - "$scratch/checkpoint-baseline-lib.sh" "$temporary_directory" <<'DEADLINE'
import subprocess
import sys
import time
library, root = sys.argv[1:]
begin = time.monotonic()
result = subprocess.run(["sh", "-c", '. "$1"; baseline_launch "$2/launch-deadline" "$2/slow-launch.sh" low-async http://127.0.0.1:1 1',
                         "deadline", library, root], capture_output=True, text=True, timeout=4)
if result.returncode == 0 or time.monotonic() - begin > 3:
    raise SystemExit(f"launch deadline failed: {result.stderr}")
DEADLINE

active_fixture=raw_reader_regressions
python3 - "$summarizer" "$acquisitions/single" "$acquisitions/bracket" "$temporary_directory" <<'PY'
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

reader, single, bracket, scratch = map(Path, sys.argv[1:])

def check_case(name, mutate, source=single, accepted=False, required=()):
    root = scratch / f"regression-{name}"
    shutil.copytree(source, root)
    mutate(root)
    result = subprocess.run([str(reader), str(root), "--write"], capture_output=True, text=True)
    if (result.returncode == 0) != accepted:
        raise SystemExit(f"{name}: unexpected status {result.returncode}: {result.stdout} {result.stderr}")
    for text in required:
        if text not in result.stdout:
            raise SystemExit(f"{name}: absent {text}: {result.stdout}")
    print(f"baseline_regression={name} expected={'accepted' if accepted else 'refused'}")

arm = Path('arms/01-subject')
response = arm / 'repeats/01/response.json'
rows = arm / 'decode-rows.tsv'

def raw_change(root, key, value):
    path = root / response
    document = json.loads(path.read_text())
    document['timings'][key] = value
    path.write_text(json.dumps(document))

def derived_change(root):
    path = root / rows
    lines = path.read_text().splitlines()
    fields = lines[1].split('\t')
    fields[1] = '99'
    lines[1] = '\t'.join(fields)
    path.write_text('\n'.join(lines) + '\n')

check_case('malformed-raw', lambda root: (root / response).write_text('{invalid'))
check_case('derived-rate', derived_change)
check_case('clock-refusal', lambda root: (root / arm / 'clock-validation.txt').write_text('clock_sidecar=refused failures=clock_invariant\n'))
check_case('one-repeat', lambda root: (root / rows).write_text('\n'.join((root / rows).read_text().splitlines()[:2])+'\n'))
check_case('duplicate-repeat', lambda root: (root / rows).write_text((root / rows).read_text().splitlines()[0]+'\n'+((root / rows).read_text().splitlines()[1]+'\n')*4))
for value in (float('inf'), float('nan'), -1, 0, True):
    check_case(f'raw-rate-{value}', lambda root, value=value: raw_change(root, 'predicted_per_second', value))
check_case('raw-count-bool', lambda root: raw_change(root, 'predicted_n', True))
check_case('elapsed-conflict', lambda root: raw_change(root, 'predicted_ms', 9000))
check_case('stale-token-digest', lambda root: (root / arm / 'repeats/01/tokens.txt').write_text('900\n901\n'))
check_case('sampler-exit', lambda root: (root / arm / 'terminal.tsv').write_text((root / arm / 'terminal.tsv').read_text().replace('sidecar_status\t0', 'sidecar_status\t9')))
check_case('incomplete-bracket', lambda root: shutil.rmtree(root / 'arms/04-control'), source=bracket)
check_case('wrong-arm-order', lambda root: (root / 'arms.tsv').write_text((root / 'arms.tsv').read_text().replace('02\tK', '02\tC')), source=bracket)
check_case('process-thread-mismatch', lambda root: (root / arm / 'process-identity.tsv').write_text((root / arm / 'process-identity.tsv').read_text().replace('threads\t1', 'threads\t2')))
check_case('truncated-warmup', lambda root: (root / arm / 'warmup.sse').write_text((root / arm / 'warmup.sse').read_text().splitlines()[0]+'\n'))

def stable_candidate_difference(root):
    for name in ('02-candidate', '03-candidate'):
        directory = root / 'arms' / name
        lines = (directory / 'decode-rows.tsv').read_text().splitlines()
        for index in range(1, len(lines)):
            fields = lines[index].split('\t')
            repeat = directory / 'repeats' / fields[0]
            document = json.loads((repeat / 'response.json').read_text())
            document['tokens'] = [token+100 for token in document['tokens']]
            text = ''.join(f'{token}\n' for token in document['tokens'])
            (repeat / 'response.json').write_text(json.dumps(document))
            (repeat / 'tokens.txt').write_text(text)
            fields[5] = hashlib.sha256(text.encode()).hexdigest()
            lines[index] = '\t'.join(fields)
        (directory / 'decode-rows.tsv').write_text('\n'.join(lines)+'\n')

check_case('within-versus-cross-binary', stable_candidate_difference, source=bracket, accepted=True,
           required=('within_binary_repeatability\theld', 'cross_binary_token_comparison\tdiverged',
                     'acquisition_completeness\tcompleted', 'instrument_admission\taccepted',
                     'performance_result\twithheld_correctness'))
PY

for refusal in sampler quiescence; do
    active_fixture="${refusal}_failure_is_terminal"
    case $refusal in
        sampler) refusal_environment=QWEN_FIXTURE_SIDECAR_EXIT=7; reason=clock_invariant ;;
        *) refusal_environment=QWEN_FIXTURE_QUIESCENCE_EXIT=1; reason=quiescence ;;
    esac
    if run_harness "$acquisitions/$refusal-failure" "$refusal_environment"; then
        printf 'runner admitted %s failure\n' "$refusal" >&2
        exit 1
    fi
    grep -q "$reason" "$acquisitions/$refusal-failure/arms.tsv"
    if [ "$refusal" = sampler ]; then
        awk -F'\t' '$1 == "sidecar_status" { exit $2 != 7 }' "$acquisitions/$refusal-failure/arms/01-subject/terminal.tsv"
    fi
    awk -F'\t' '$1 == "status" && ($2 == "incomplete" || $2 == "failed") { found=1 } END { exit !found }' "$acquisitions/$refusal-failure/arms/01-subject/terminal.tsv"
done

active_fixture=real_broker_receives_hwmon
real_broker=$temporary_directory/telemetry-broker
cc -O2 -Wall -Wextra -Werror -std=c11 "$scratch/telemetry-broker.c" -o "$real_broker"
sha256sum "$scratch/telemetry-broker.c" | cut -d ' ' -f 1 >"$real_broker.source-sha256"
mkdir -p "$temporary_directory/global-hwmon"
ln -s "$temporary_directory/drm/hwmon/amdgpu" "$temporary_directory/global-hwmon/hwmon0"
run_harness "$acquisitions/real-broker" "QWEN_CENSUS_BROKER=$real_broker" \
    "QWEN_HWMON_ROOT=$temporary_directory/global-hwmon"
grep -q 'telemetry_broker=sampled' "$acquisitions/real-broker/arms/01-subject/sidecar.stderr"
python3 - "$acquisitions/real-broker/arms/01-subject/clock-samples.tsv" <<'PYBROKER'
import csv
import sys
with open(sys.argv[1]) as source:
    rows = list(csv.DictReader((line for line in source if not line.startswith("#")), delimiter="\t"))
assert rows
assert all(row["sclk_actual_mhz"] == "1100" and row["temp1_millidegrees"] == "70000" for row in rows), rows
PYBROKER
active_fixture=missing_hwmon_refuses_before_launch
mkdir -p "$temporary_directory/empty-hwmon"
if run_harness "$acquisitions/missing-hwmon" "QWEN_HWMON_ROOT=$temporary_directory/empty-hwmon"; then
    printf 'baseline admitted an absent delivered-clock sensor\n' >&2
    exit 1
fi
[ ! -e "$acquisitions/missing-hwmon" ]
grep -q 'baseline requires readable amdgpu hwmon' "$temporary_directory/run.log"

active_fixture=ambiguous_hwmon_refuses_before_launch
mkdir -p "$temporary_directory/ambiguous-hwmon/first" "$temporary_directory/ambiguous-hwmon/second"
printf 'amdgpu\n' >"$temporary_directory/ambiguous-hwmon/first/name"
printf 'amdgpu\n' >"$temporary_directory/ambiguous-hwmon/second/name"
if run_harness "$acquisitions/ambiguous-hwmon" "QWEN_HWMON_ROOT=$temporary_directory/ambiguous-hwmon"; then
    printf 'baseline admitted ambiguous amdgpu sensors\n' >&2
    exit 1
fi
[ ! -e "$acquisitions/ambiguous-hwmon" ]
grep -q 'baseline requires one amdgpu hwmon sensor directory' "$temporary_directory/run.log"

active_fixture=missing_temperature_refuses_before_launch
mkdir -p "$temporary_directory/missing-temperature/amdgpu"
printf 'amdgpu\n' >"$temporary_directory/missing-temperature/amdgpu/name"
printf '1100000000\n' >"$temporary_directory/missing-temperature/amdgpu/freq1_input"
if run_harness "$acquisitions/missing-temperature" "QWEN_HWMON_ROOT=$temporary_directory/missing-temperature"; then
    printf 'baseline admitted an absent required temperature sensor\n' >&2
    exit 1
fi
[ ! -e "$acquisitions/missing-temperature" ]
grep -q 'baseline requires readable amdgpu hwmon' "$temporary_directory/run.log"

active_fixture=foreign_hwmon_refuses_before_launch
mkdir -p "$temporary_directory/foreign-hwmon/amdgpu"
cp "$temporary_directory/drm/hwmon/amdgpu/name" \
    "$temporary_directory/drm/hwmon/amdgpu/freq1_input" \
    "$temporary_directory/drm/hwmon/amdgpu/temp1_input" \
    "$temporary_directory/foreign-hwmon/amdgpu/"
if run_harness "$acquisitions/foreign-hwmon" "QWEN_HWMON_ROOT=$temporary_directory/foreign-hwmon"; then
    printf 'baseline admitted sensors from another DRM device\n' >&2
    exit 1
fi
[ ! -e "$acquisitions/foreign-hwmon" ]
grep -q 'baseline hwmon sensors must belong to the selected DRM device' "$temporary_directory/run.log"

diagnostic_file=
printf 'checkpoint baseline fixtures passed\n'
