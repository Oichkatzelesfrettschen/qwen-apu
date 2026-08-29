#!/bin/sh
set -eu

# remote/run-image-standalone.sh against remote/test-fixtures/fake-image-runtime.sh,
# which stands in for sd-cli, so the harness's device-selection refusal,
# device-listing rejection, resident-process precondition, and per-arm
# telemetry paths are all exercised without the appliance.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
runner=$script_directory/run-image-standalone.sh
fake_runtime=$script_directory/test-fixtures/fake-image-runtime.sh
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

fake_model=$temporary_directory/fake-model.safetensors
printf 'not a real checkpoint\n' >"$fake_model"

is_valid_png() {
    [ -f "$1" ] && head -c 8 "$1" | od -An -tx1 | tr -d ' \n' | grep -qi '^89504e470d0a1a0a$'
}

# T1: the happy path. Two arms complete, each writes a distinct PNG the fake
# runtime built, and the summary carries one row per arm with the fields the
# harness derives from the runtime's own log lines.
t1_directory=$temporary_directory/t1
if QWEN_IMAGE_RUNTIME=$fake_runtime QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 \
    QWEN_VULKANINFO_COMMAND=/bin/false \
    "$runner" "$t1_directory" "$fake_model" >"$temporary_directory/t1.out" 2>&1
then
    t1_status=accepted
    [ -f "$t1_directory/summary.tsv" ] || t1_status=refused
    [ "$(awk -F'\t' 'NR > 1 { count++ } END { print count + 0 }' "$t1_directory/summary.tsv")" = 2 ] ||
        t1_status=refused
    is_valid_png "$t1_directory/cold.png" || t1_status=refused
    is_valid_png "$t1_directory/warm.png" || t1_status=refused
    grep -q 'device_refusal_control=accepted' "$temporary_directory/t1.out" || t1_status=refused
    cold_status=$(awk -F'\t' 'NR == 2 { print $2 }' "$t1_directory/summary.tsv")
    [ "$cold_status" = completed ] || t1_status=refused
else
    t1_status=refused
fi
report happy_path_two_arms_completed "$t1_status"

# T2: the harness's own safety net. A runtime that accepts an unresolvable
# device name on the refusal-control arm must stop the whole run rather than
# report a generation result as strictly placed.
t2_directory=$temporary_directory/t2
if QWEN_IMAGE_RUNTIME=$fake_runtime QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 \
    QWEN_VULKANINFO_COMMAND=/bin/false \
    QWEN_FAKE_IMAGE_FORCE_MODE=ok \
    "$runner" "$t2_directory" "$fake_model" >"$temporary_directory/t2.out" 2>&1
then
    t2_status=refused
else
    # The header is written before the refusal control runs, so its presence
    # alone proves nothing; zero data rows is what proves no arm ran.
    t2_status=accepted
    if [ -f "$t2_directory/summary.tsv" ]; then
        t2_rows=$(awk -F'\t' 'NR > 1 { count++ } END { print count + 0 }' "$t2_directory/summary.tsv")
        [ "$t2_rows" = 0 ] || t2_status=refused
    fi
    [ ! -e "$t2_directory/cold.png" ] || t2_status=refused
fi
report refusal_control_safety_net_stops_the_run "$t2_status"

# T3: a software or non-RADV device name in --list-devices refuses before any
# arm runs.
t3_directory=$temporary_directory/t3
if QWEN_IMAGE_RUNTIME=$fake_runtime QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 \
    QWEN_VULKANINFO_COMMAND=/bin/false \
    QWEN_FAKE_IMAGE_DEVICE_DESCRIPTION='llvmpipe (LLVM 17.0.0, 256 bits)' \
    "$runner" "$t3_directory" "$fake_model" >"$temporary_directory/t3.out" 2>&1
then
    t3_status=refused
else
    t3_status=accepted
    [ ! -f "$t3_directory/summary.tsv" ] || t3_status=refused
fi
report llvmpipe_device_listing_refused "$t3_status"

# T4: a resident llama-server process refuses the run unless the caller opts
# out, proving the order-of-proof precondition rather than assuming it.
fake_bin_directory=$temporary_directory/fake-bin
mkdir -p "$fake_bin_directory"
cat >"$fake_bin_directory/pgrep" <<'FAKE_PGREP'
#!/bin/sh
# Every invocation reports a match, standing in for a resident llama-server.
exit 0
FAKE_PGREP
chmod +x "$fake_bin_directory/pgrep"
t4_directory=$temporary_directory/t4
if PATH=$fake_bin_directory:$PATH QWEN_IMAGE_RUNTIME=$fake_runtime \
    QWEN_VULKANINFO_COMMAND=/bin/false \
    "$runner" "$t4_directory" "$fake_model" >"$temporary_directory/t4.out" 2>&1
then
    t4_status=refused
else
    t4_status=accepted
    [ ! -d "$t4_directory" ] || [ ! -f "$t4_directory/summary.tsv" ] || t4_status=refused
fi
report resident_llama_process_refused "$t4_status"

# T5: a generation failure is recorded rather than silently dropped. The
# harness itself still exits zero, the way a multi-arm probe records a failed
# arm without aborting the ones that have not run yet.
t5_directory=$temporary_directory/t5
if QWEN_IMAGE_RUNTIME=$fake_runtime QWEN_IMAGE_ALLOW_LLAMA_RESIDENT=1 \
    QWEN_VULKANINFO_COMMAND=/bin/false \
    QWEN_FAKE_IMAGE_MODE=fail \
    "$runner" "$t5_directory" "$fake_model" >"$temporary_directory/t5.out" 2>&1
then
    t5_status=accepted
    cold_status=$(awk -F'\t' 'NR == 2 { print $2 }' "$t5_directory/summary.tsv")
    cold_exit=$(awk -F'\t' 'NR == 2 { print $3 }' "$t5_directory/summary.tsv")
    [ "$cold_status" = failed ] || t5_status=refused
    [ "$cold_exit" = 3 ] || t5_status=refused
    [ ! -e "$t5_directory/cold.png" ] || t5_status=refused
else
    t5_status=refused
fi
report generation_failure_recorded_not_dropped "$t5_status"

if [ "$failures" -eq 0 ]; then
    printf 'test-run-image-standalone=accepted\n'
    exit 0
fi
printf 'test-run-image-standalone=refused failures=%s\n' "$failures" >&2
exit 1
