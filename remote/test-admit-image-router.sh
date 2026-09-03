#!/bin/sh
set -eu

# Runs remote/admit-image-router.sh whole on a machine with no Raven2, so the
# admission's own logic is exercised where the tree is edited rather than only
# where it is deployed.
#
# Four device-owning links are the only ones replaced, each by a stub named
# after what it stands in for: model-memory-preflight.sh, which requires a RADV
# RAVEN2 physical device and reports headroom; the graphics latency probe, the
# kernel-hazard watcher, and the runtime monitor, which read amdgpu state. The
# router is remote/test-fixtures/fake-router-server.py and the image runtime is
# remote/test-fixtures/fake-image-runtime.sh. Everything between them is the
# tree's own: qwen-image-launch.sh, qwen-web-launch.sh, the tmux session, the
# capacity policy, the exec guard, the approval broker, image-service.py with
# its Vulkan workload lease, the image MCP child, the served page, and the
# teardown. The harness runs from a directory of symbolic links into remote/,
# because every script there resolves its siblings from its own $0.
#
# QWEN_ADMISSION_RESTORE is 0: the workstation runs no ordinary appliance for
# the harness to put back, and the restoration path is what
# remote/test-admit-web-router-fake.sh measures.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
for tool in python3 curl jq flock tmux ss; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'test-admit-image-router: %s is required\n' "$tool" >&2
        exit 2
    fi
done

work=$(mktemp -d "${TMPDIR:-/tmp}/qwen-image-admission.XXXXXX")
harness=$work/remote
state_directory=$work/state
output_directory=$work/output
keep_on_failure=0
cleanup() {
    if [ -x "$harness/qwen-teardown.sh" ]; then
        QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
            "$harness/qwen-teardown.sh" >/dev/null 2>&1 || true
    fi
    # A failed run leaves its logs where a reader can open them; the admission
    # writes the session status, the broker log, and the image service log into
    # this tree and a removal would take the evidence with the failure.
    if [ "$keep_on_failure" = 1 ]; then
        printf 'test-admit-image-router: retained %s\n' "$work" >&2
        return 0
    fi
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$harness" "$state_directory" "$output_directory"
# image-registry.sh and the admission both resolve a retained evidence path
# against the parent of the directory they run from, so the harness mirrors the
# tree at that one point.
ln -s "$script_directory/../evidence" "$work/evidence"
# qwen-image-launch.sh reads webui/index.html's own IMAGE_GENERATION_TIMEOUT_MS
# beside its directory, and qwen-web-launch.sh serves that page, so the tree is
# mirrored there too.
ln -s "$script_directory/../webui" "$work/webui"

# The harness mirrors remote/ by reference, so every script under test is the
# checked-in one and only the named stubs differ.
for entry in "$script_directory"/*; do
    ln -s "$entry" "$harness/$(basename -- "$entry")"
done
for stubbed in model-memory-preflight.sh watch-qwen-kernel-hazards.sh \
    monitor-qwen-runtime.sh; do
    rm -f "$harness/$stubbed"
done

cat >"$harness/model-memory-preflight.sh" <<'EOF'
#!/bin/sh
set -eu
# Stands in for the RADV RAVEN2 memory budget probe. The real script reports
# host and Vulkan headroom and admits every launch, so the stub reports the
# same shape and admits this one.
printf 'model_bytes=%s\n' "$(wc -c <"$1")"
printf 'host_headroom=ample\n'
printf 'vulkan_budget_headroom=ample surplus_bytes=0\n'
EOF
cat >"$harness/watch-qwen-kernel-hazards.sh" <<'EOF'
#!/bin/sh
set -eu
# Stands in for the amdgpu ring-reset and VM-fault watcher. The session waits
# for the ready marker and then supervises the process, so the stub writes the
# marker and lives as long as the session does.
printf 'watch_ready_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$2"
while kill -0 "$1" 2>/dev/null; do
    sleep 1
done
EOF
cat >"$harness/monitor-qwen-runtime.sh" <<'EOF'
#!/bin/sh
set -eu
# Stands in for the telemetry monitor, which samples amdgpu counters. The
# session supervises this pid, so the stub outlives the server it watches.
server_pid=$1
while kill -0 "$server_pid" 2>/dev/null; do
    sleep 1
done
EOF
latency_probe=$work/fake-latency-probe.sh
cat >"$latency_probe" <<'EOF'
#!/bin/sh
set -eu
# Stands in for build/vulkan-graphics-service-probe. The session waits for the
# probe_start line in the log the probe names and then supervises the process.
log=''
watch_pid=''
while [ "$#" -gt 0 ]; do
    case $1 in
        --log) log=$2; shift 2 ;;
        --watch-pid) watch_pid=$2; shift 2 ;;
        *) shift ;;
    esac
done
printf 'probe_start utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$log"
while kill -0 "$watch_pid" 2>/dev/null; do
    sleep 1
done
EOF
chmod 0755 "$harness/model-memory-preflight.sh" \
    "$harness/watch-qwen-kernel-hazards.sh" "$harness/monitor-qwen-runtime.sh" \
    "$latency_probe"

# One fabricated registry row and one empty artifact beside it: the generator
# skips a row whose weights are absent, and the fixture router loads nothing.
model_registry=$work/models.tsv
{
    printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tprojector_fetch_script\tdecode_tok_s\tprefill_tok_s\tquality\ttier\tbatch\tubatch\tvalidated_filled_depth\tvalidation_evidence\traw_tool_selection\tguarded_tool_execution\n'
    printf 'image-admission-fixture\tfixture-role\tFixture-GGUF/fixture.gguf\tdownload-fixture.sh\t4096\t8192\t8192\tq8_0\tq4_0\ton\tnone\t-\t1.00\t1.00\tuntested\tcandidate\t128\t32\t4096\tevidence/image-appliance/design.md\t9/10\trefused\n'
    printf 'image-review-fixture\tfixture-role\tFixture-Vision-GGUF/vision.gguf\tdownload-fixture.sh\t4096\t8192\t8192\tq8_0\tq4_0\ton\trequired\tdownload-fixture-mmproj.sh\t1.00\t1.00\tuntested\tcandidate\t128\t32\t4096\tevidence/image-appliance/design.md\t8/10\trefused\n'
} >"$model_registry"
# The context checkpoint ledger joins against the model registry, so the
# fixture registry names an empty ledger and both emitted sections carry the
# 0 an absent row admits; the harness inherits it through the environment the
# way it inherits the registry.
QWEN_CTX_CHECKPOINT_LEDGER=$work/ctx-checkpoints.tsv
printf '# the fixture registry admits no checkpoint count\n' \
    >"$QWEN_CTX_CHECKPOINT_LEDGER"
export QWEN_CTX_CHECKPOINT_LEDGER
model_root=$work/model-root
mkdir -p "$model_root/Fixture-GGUF"
: >"$model_root/Fixture-GGUF/fixture.gguf"
# select-projector.sh searches the model file's own directory, so the vision
# row sits in its own and a projector beside a text checkpoint pairs with
# nothing.
mkdir -p "$model_root/Fixture-Vision-GGUF"
: >"$model_root/Fixture-Vision-GGUF/vision.gguf"
: >"$model_root/Fixture-Vision-GGUF/mmproj-F16.gguf"

# The review section serves the vision row's registry default tuple, and the
# generator requires remote/validated-tuples.tsv to carry that arm with the
# projector loaded.
validated_tuples=$work/validated-tuples.tsv
{
    printf '# tuple_id\tmodel_id\truntime_mode\tcontext\tbatch\tubatch\tcache_k\tcache_v\tflash_attention\tthreads\tparallel\tprojector_state\tbackend\tstatus\tevidence\tllama_commit\trunner_sha256\tkernel\tmesa\tamdgpu\tmeasured_at\n'
    printf 'image-review-fixture-d4096-b128-ub32-proj\timage-review-fixture\trouter-child\t4096\t128\t32\tq8_0\tq4_0\ton\t1\t1\tloaded\tvulkan\tvalidated\tevidence/image-appliance/design.md\t-\t-\t-\t-\t-\t2026-08-29\n'
} >"$validated_tuples"

# The fixture runtime writes a PNG of the requested dimensions from the seed
# alone, so the artifact digest the service reports is a function of the seed
# this run chose and the run needs no device.
image_model_directory=$work/image-model
mkdir -p "$image_model_directory"

# image-service.py pins VK_DRIVER_FILES and VK_ICD_FILENAMES for every runtime
# it spawns and refuses to start when the ICD it derives them from is
# unreadable. The workstation carries no RADV ICD, so the run names a fixture
# file: the fake runtime records both variables and reaches no driver, and the
# pinning path is exercised rather than skipped.
fixture_icd=$work/fixture-radv-icd.json
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"/nonexistent","api_version":"1.3.0"}}\n' \
    >"$fixture_icd"

set +e
env -u QWEN_IMAGE_PROFILES -u QWEN_IMAGE_PROFILE \
    QWEN_WEBUI_STATE_DIRECTORY="$state_directory" \
    QWEN_MODEL_REGISTRY="$model_registry" \
    QWEN_MODEL_ROOT="$model_root" \
    QWEN_ADMISSION_MODEL_ID=image-admission-fixture \
    QWEN_ADMISSION_CONTEXT=4096 \
    QWEN_ADMISSION_RESTORE=0 \
    QWEN_LLAMA_SERVER="$script_directory/test-fixtures/fake-router-server.py" \
    QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
    QWEN_IMAGE_RUNTIME="$script_directory/test-fixtures/fake-image-runtime.sh" \
    QWEN_IMAGE_RUNTIME_TEMPLATE=fixture \
    QWEN_IMAGE_MODEL_PATH="$image_model_directory" \
    QWEN_RADV_ICD="$fixture_icd" \
    QWEN_SERVER_PORT="${QWEN_SERVER_PORT:-18080}" \
    QWEN_WEB_BROKER_PORT="${QWEN_WEB_BROKER_PORT:-18571}" \
    "$harness/admit-image-router.sh" "$output_directory" \
    >"$work/admission.stdout" 2>"$work/admission.stderr"
admission_status=$?
set -e

cat "$work/admission.stdout"
if [ "$admission_status" -ne 0 ]; then
    keep_on_failure=1
    printf 'test-admit-image-router: the admission refused\n' >&2
    sed -n '$p' "$work/admission.stderr" >&2
    awk -F'\t' '$2 != "accepted" && $2 != "observed" && $2 != "skipped" { print }' \
        "$output_directory/summary.tsv" >&2 2>/dev/null || true
    tail -c 2000 "$work/admission.stderr" >&2
    exit 1
fi
if ! grep -qx 'admit_image_router=accepted' "$work/admission.stdout"; then
    printf 'test-admit-image-router: the run printed no acceptance line\n' >&2
    exit 1
fi

# The retained HTTP capture holds a request body that carried a grant, so the
# directory and every file in it stay readable by their owner alone.
if [ "$(stat -c %a "$output_directory/http")" != 700 ]; then
    printf 'test-admit-image-router: the HTTP capture directory is not private\n' >&2
    exit 1
fi
for capture_file in "$output_directory"/http/*; do
    if [ "$(stat -c %a "$capture_file")" != 600 ]; then
        printf 'test-admit-image-router: %s is not private\n' "$capture_file" >&2
        exit 1
    fi
done

# The checked-in ledger is the authority the run copies from and never edits.
# The row's `execution_policy` is field 12 and `validated_evidence` is field 13,
# so both are read by column: the shipped row carries the served turn of
# evidence/image-appliance/served-turn-admission/, and a harness run that writes
# its own ledger under OUTPUT_DIR leaves those two fields where they are.
if ! awk -F'	' '$1 == "image-sdxs-512-a" && $12 == "validator-gated" &&
                 $13 == "evidence/image-appliance/served-turn-admission/README.md" { found = 1 }
                 END { exit found ? 0 : 1 }' \
        "$script_directory/image-profiles.tsv"; then
    printf 'test-admit-image-router: the harness edited the checked-in image ledger\n' >&2
    exit 1
fi

# The LAN exposure runs the whole admission again against the exposed lane.
# 127.0.0.2 is a non-loopback literal by the listeners' own LOOPBACK_HOSTS
# definition and is reachable on Linux without a second network, so the router,
# the broker, the artifact listener, and the served page all answer over an
# address the loopback default refuses. The arm reads three claims off the
# summary: each listener bound the exposed address, the router and the broker
# refuse a request carrying no bearer, and one page turn completed an approved
# generation with every request on the exposed origins.
lan_output=$work/output-lan
mkdir -p "$lan_output"
lan_state=$work/state-lan
mkdir -p "$lan_state"
set +e
env -u QWEN_IMAGE_PROFILES -u QWEN_IMAGE_PROFILE \
    QWEN_WEBUI_STATE_DIRECTORY="$lan_state" \
    QWEN_MODEL_REGISTRY="$model_registry" \
    QWEN_MODEL_ROOT="$model_root" \
    QWEN_ADMISSION_MODEL_ID=image-admission-fixture \
    QWEN_ADMISSION_CONTEXT=4096 \
    QWEN_ADMISSION_RESTORE=0 \
    QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=127.0.0.2 \
    QWEN_WEB_LAN_OPEN=0 \
    QWEN_WEB_LAN_NAME='' \
    QWEN_LLAMA_SERVER="$script_directory/test-fixtures/fake-router-server.py" \
    QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
    QWEN_IMAGE_RUNTIME="$script_directory/test-fixtures/fake-image-runtime.sh" \
    QWEN_IMAGE_RUNTIME_TEMPLATE=fixture \
    QWEN_IMAGE_MODEL_PATH="$image_model_directory" \
    QWEN_RADV_ICD="$fixture_icd" \
    QWEN_SERVER_PORT=18082 \
    QWEN_WEB_BROKER_PORT=18573 \
    "$harness/admit-image-router.sh" "$lan_output" \
    >"$work/lan.stdout" 2>"$work/lan.stderr"
lan_status=$?
set -e
cat "$work/lan.stdout"
if [ "$lan_status" -ne 0 ]; then
    keep_on_failure=1
    printf 'test-admit-image-router: the LAN exposure admission refused\n' >&2
    awk -F'\t' '$2 != "accepted" && $2 != "observed" && $2 != "skipped" { print }' \
        "$lan_output/summary.tsv" >&2 2>/dev/null || true
    tail -c 2000 "$work/lan.stderr" >&2
    exit 1
fi
for lan_check in router_listener_bound artifact_listener_bound \
    session_records_lan_exposure exposed_router_requires_the_bearer \
    exposed_grant_requires_the_bearer artifact_without_credential_refused \
    browser_page_origin browser_grant_posted_once browser_generation_via_router \
    browser_requests_stay_on_known_origins browser_artifact_fetched; do
    if ! awk -F'\t' -v name="$lan_check" \
        '$1 == name && $2 == "accepted" { found = 1 } END { exit found ? 0 : 1 }' \
        "$lan_output/summary.tsv"; then
        keep_on_failure=1
        printf 'test-admit-image-router: %s was not accepted in the LAN run\n' \
            "$lan_check" >&2
        grep "^$lan_check	" "$lan_output/summary.tsv" >&2 || true
        exit 1
    fi
done
# The page turn ran against the exposed origin rather than the loopback one, so
# the addresses the summary names are what distinguishes this arm from the
# default run above.
if ! grep -q '^browser_page_origin	accepted	origin=http://127.0.0.2:18082' \
    "$lan_output/summary.tsv"; then
    keep_on_failure=1
    printf 'test-admit-image-router: the LAN page turn ran from another origin\n' >&2
    grep '^browser_page_origin	' "$lan_output/summary.tsv" >&2 || true
    exit 1
fi
if grep -q 'http://127.0.0.1:' "$lan_output/summary.tsv"; then
    keep_on_failure=1
    printf 'test-admit-image-router: the LAN run names a loopback origin\n' >&2
    grep 'http://127.0.0.1:' "$lan_output/summary.tsv" >&2 || true
    exit 1
fi

# QWEN_WEB_LAN_OPEN=1 runs the same exposed lane with the bearer removed, which
# is what an operator serving their own network without a key step launches. The
# arm reads the three rows that change: the router answers a keyless read, the
# artifact route answers one too, and the signing route still refuses a request
# whose session secret this launch never wrote. Every other claim -- the bound
# listeners, the single grant, the page origins, the fetched artifact -- holds
# unchanged, which is what makes the open decision a credential change rather
# than a gate removal.
open_output=$work/output-lan-open
mkdir -p "$open_output"
open_state=$work/state-lan-open
mkdir -p "$open_state"
set +e
env -u QWEN_IMAGE_PROFILES -u QWEN_IMAGE_PROFILE \
    QWEN_WEBUI_STATE_DIRECTORY="$open_state" \
    QWEN_MODEL_REGISTRY="$model_registry" \
    QWEN_MODEL_ROOT="$model_root" \
    QWEN_ADMISSION_MODEL_ID=image-admission-fixture \
    QWEN_ADMISSION_CONTEXT=4096 \
    QWEN_ADMISSION_RESTORE=0 \
    QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=127.0.0.2 \
    QWEN_WEB_LAN_OPEN=1 \
    QWEN_WEB_LAN_NAME='' \
    QWEN_LLAMA_SERVER="$script_directory/test-fixtures/fake-router-server.py" \
    QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
    QWEN_IMAGE_RUNTIME="$script_directory/test-fixtures/fake-image-runtime.sh" \
    QWEN_IMAGE_RUNTIME_TEMPLATE=fixture \
    QWEN_IMAGE_MODEL_PATH="$image_model_directory" \
    QWEN_RADV_ICD="$fixture_icd" \
    QWEN_SERVER_PORT=18084 \
    QWEN_WEB_BROKER_PORT=18575 \
    "$harness/admit-image-router.sh" "$open_output" \
    >"$work/lan-open.stdout" 2>"$work/lan-open.stderr"
open_status=$?
set -e
cat "$work/lan-open.stdout"
if [ "$open_status" -ne 0 ]; then
    keep_on_failure=1
    printf 'test-admit-image-router: the open LAN admission refused\n' >&2
    awk -F'\t' '$2 != "accepted" && $2 != "observed" && $2 != "skipped" { print }' \
        "$open_output/summary.tsv" >&2 2>/dev/null || true
    tail -c 2000 "$work/lan-open.stderr" >&2
    exit 1
fi
for open_check in router_listener_bound artifact_listener_bound \
    session_records_lan_exposure open_router_serves_without_the_bearer \
    open_grant_requires_the_session_secret artifact_without_credential_refused \
    browser_page_origin browser_grant_posted_once browser_generation_via_router \
    browser_requests_stay_on_known_origins browser_artifact_fetched; do
    if ! awk -F'\t' -v name="$open_check" \
        '$1 == name && $2 == "accepted" { found = 1 } END { exit found ? 0 : 1 }' \
        "$open_output/summary.tsv"; then
        keep_on_failure=1
        printf 'test-admit-image-router: %s was not accepted in the open LAN run\n' \
            "$open_check" >&2
        grep "^$open_check	" "$open_output/summary.tsv" >&2 || true
        exit 1
    fi
done
if ! grep -q '^artifact_without_credential_refused	accepted	status=200 open=1' \
    "$open_output/summary.tsv"; then
    keep_on_failure=1
    printf 'test-admit-image-router: the open artifact route did not answer a keyless read\n' >&2
    grep '^artifact_without_credential_refused	' "$open_output/summary.tsv" >&2 || true
    exit 1
fi

# The review pairing runs the whole admission again with the image row naming a
# vision checkpoint. Two sections serve, the page's Review button appears
# because `GET /props` reports a vision modality for the second row, and the
# rendered checklist is what the arm reads.
review_output=$work/output-review
mkdir -p "$review_output"
set +e
env -u QWEN_IMAGE_PROFILES -u QWEN_IMAGE_PROFILE \
    QWEN_WEBUI_STATE_DIRECTORY="$state_directory" \
    QWEN_MODEL_REGISTRY="$model_registry" \
    QWEN_VALIDATED_TUPLES="$validated_tuples" \
    QWEN_MODEL_ROOT="$model_root" \
    QWEN_ADMISSION_MODEL_ID=image-admission-fixture \
    QWEN_ADMISSION_REVIEW_MODEL=image-review-fixture \
    QWEN_ADMISSION_CONTEXT=4096 \
    QWEN_ADMISSION_RESTORE=0 \
    QWEN_LLAMA_SERVER="$script_directory/test-fixtures/fake-router-server.py" \
    QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
    QWEN_IMAGE_RUNTIME="$script_directory/test-fixtures/fake-image-runtime.sh" \
    QWEN_IMAGE_RUNTIME_TEMPLATE=fixture \
    QWEN_IMAGE_MODEL_PATH="$image_model_directory" \
    QWEN_RADV_ICD="$fixture_icd" \
    QWEN_SERVER_PORT="${QWEN_SERVER_PORT:-18080}" \
    QWEN_WEB_BROKER_PORT="${QWEN_WEB_BROKER_PORT:-18571}" \
    "$harness/admit-image-router.sh" "$review_output" \
    >"$work/review.stdout" 2>"$work/review.stderr"
review_status=$?
set -e
cat "$work/review.stdout"
if [ "$review_status" -ne 0 ]; then
    keep_on_failure=1
    printf 'test-admit-image-router: the review admission refused\n' >&2
    awk -F'\t' '$2 != "accepted" && $2 != "observed" && $2 != "skipped" { print }' \
        "$review_output/summary.tsv" >&2 2>/dev/null || true
    tail -c 2000 "$work/review.stderr" >&2
    exit 1
fi
for review_check in router_roster review_row_reports_vision \
    review_row_offers_no_tools browser_review_rendered \
    browser_review_stays_out_of_history browser_review_offers_no_tools; do
    if ! awk -F'\t' -v name="$review_check" \
        '$1 == name && $2 == "accepted" { found = 1 } END { exit found ? 0 : 1 }' \
        "$review_output/summary.tsv"; then
        keep_on_failure=1
        printf 'test-admit-image-router: %s was not accepted in the review run\n' \
            "$review_check" >&2
        grep "^$review_check	" "$review_output/summary.tsv" >&2 || true
        exit 1
    fi
done
# The preset the review run generated names one language section and one
# review-only vision section, and the review section holds no execution grant.
if [ "$(grep -c '^\[' "$review_output/web-presets.ini")" -ne 2 ] ||
   [ "$(grep -c '^LLAMA_ARG_MCP_SERVERS_CONFIG' "$review_output/web-presets.ini")" -ne 1 ] ||
   ! grep -qx 'LLAMA_ARG_TAGS = vision-review,review-only' \
       "$review_output/web-presets.ini"; then
    keep_on_failure=1
    printf 'test-admit-image-router: the review preset is not one language and one review section\n' >&2
    grep '^\[\|^LLAMA_ARG_TAGS\|^LLAMA_ARG_MCP_SERVERS_CONFIG' \
        "$review_output/web-presets.ini" >&2
    exit 1
fi

# The browser step retries a turn whose opening completion answers prose, the
# way the appliance recorded on the same explicit prompt across separate
# launches. QWEN_FAKE_ROUTER_PROSE_FIRST_COMPLETIONS answers the first opening
# completion with prose and the next with the proposal, so this arm names one
# forced prose reply and the default two-attempt budget covers it: attempt 1
# times out waiting for a dialog that never opens and attempt 2 completes. The
# env var travels inside a wrapper's own exec rather than across the tmux
# boundary, because a variable exported only in the calling shell stops there.
prose_first_router=$work/fake-router-server-prose-first.sh
cat >"$prose_first_router" <<EOF
#!/bin/sh
exec env QWEN_FAKE_ROUTER_PROSE_FIRST_COMPLETIONS=1 \\
    python3 "$script_directory/test-fixtures/fake-router-server.py" "\$@"
EOF
chmod 0755 "$prose_first_router"
retry_output=$work/output-retry
mkdir -p "$retry_output"
set +e
env -u QWEN_IMAGE_PROFILES -u QWEN_IMAGE_PROFILE \
    QWEN_WEBUI_STATE_DIRECTORY="$state_directory" \
    QWEN_MODEL_REGISTRY="$model_registry" \
    QWEN_MODEL_ROOT="$model_root" \
    QWEN_ADMISSION_MODEL_ID=image-admission-fixture \
    QWEN_ADMISSION_CONTEXT=4096 \
    QWEN_ADMISSION_RESTORE=0 \
    QWEN_LLAMA_SERVER="$prose_first_router" \
    QWEN_VULKAN_LATENCY_PROBE="$latency_probe" \
    QWEN_IMAGE_RUNTIME="$script_directory/test-fixtures/fake-image-runtime.sh" \
    QWEN_IMAGE_RUNTIME_TEMPLATE=fixture \
    QWEN_IMAGE_MODEL_PATH="$image_model_directory" \
    QWEN_RADV_ICD="$fixture_icd" \
    QWEN_SERVER_PORT="${QWEN_SERVER_PORT:-18080}" \
    QWEN_WEB_BROKER_PORT="${QWEN_WEB_BROKER_PORT:-18571}" \
    QWEN_ADMISSION_BROWSER_ATTEMPTS=2 \
    QWEN_ADMISSION_BROWSER_DIALOG_TIMEOUT=5 \
    QWEN_ADMISSION_BROWSER_PROMPT='Call the image tool now.' \
    "$harness/admit-image-router.sh" "$retry_output" \
    >"$work/retry.stdout" 2>"$work/retry.stderr"
retry_status=$?
set -e
cat "$work/retry.stdout"
if [ "$retry_status" -ne 0 ]; then
    keep_on_failure=1
    printf 'test-admit-image-router: the retry admission refused\n' >&2
    awk -F'\t' '$2 != "accepted" && $2 != "observed" && $2 != "skipped" { print }' \
        "$retry_output/summary.tsv" >&2 2>/dev/null || true
    tail -c 2000 "$work/retry.stderr" >&2
    exit 1
fi
if ! awk -F'\t' \
    '$1 == "browser_attempt_1_result" && $2 == "observed" && $3 ~ /completed=no/ && $3 ~ /tool_call_proposed=no/ { a = 1 }
     $1 == "browser_attempt_2_result" && $2 == "observed" && $3 ~ /completed=yes/ && $3 ~ /tool_call_proposed=yes/ { b = 1 }
     END { exit (a && b) ? 0 : 1 }' \
    "$retry_output/summary.tsv"; then
    keep_on_failure=1
    printf 'test-admit-image-router: attempt 1 did not read prose and attempt 2 did not complete\n' >&2
    grep '^browser_attempt_' "$retry_output/summary.tsv" >&2 || true
    exit 1
fi
for retry_transcript in browser-turn-1.json browser-turn-2.json; do
    if [ ! -s "$retry_output/$retry_transcript" ]; then
        keep_on_failure=1
        printf 'test-admit-image-router: %s was not retained\n' "$retry_transcript" >&2
        exit 1
    fi
done
if ! jq -e '[.history[] | select(.role == "assistant") | (.tool_calls // [])[]] | length > 0' \
        "$retry_output/browser-turn-2.json" >/dev/null 2>&1; then
    keep_on_failure=1
    printf 'test-admit-image-router: browser-turn-2.json carries no proposed tool call\n' >&2
    exit 1
fi

# A second run refuses while another process holds the admission lock, and runs
# once the holder has gone, because the kernel releases the lock with it.
lock_file=$state_directory/image-admission.lock
flock --close "$lock_file" sleep 60 &
holder_pid=$!
sleep 0.5
set +e
env QWEN_WEBUI_STATE_DIRECTORY="$state_directory" \
    QWEN_MODEL_REGISTRY="$model_registry" QWEN_ADMISSION_RESTORE=0 \
    "$harness/admit-image-router.sh" "$work/locked-output" \
    >"$work/locked.stdout" 2>"$work/locked.stderr"
locked_status=$?
set -e
# flock(1) forks the command, so the sleep is its child and outlives a signal
# to the parent unless it is signalled too.
pkill -P "$holder_pid" 2>/dev/null || true
kill "$holder_pid" 2>/dev/null || true
wait "$holder_pid" 2>/dev/null || true
if [ "$locked_status" -eq 0 ] || \
   ! grep -q 'another admission run holds' "$work/locked.stderr"; then
    printf 'test-admit-image-router: a live lock holder did not refuse the second run\n' >&2
    cat "$work/locked.stderr" >&2
    exit 1
fi

printf 'test-admit-image-router: all checks passed\n'
