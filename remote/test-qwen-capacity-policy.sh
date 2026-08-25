#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
policy=$script_directory/qwen-capacity-policy.sh
fake_server=$script_directory/test-fixtures/fake-llama-server.sh
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

model_path=$temporary_directory/model.gguf
output_path=$temporary_directory/policy.out
fake_icd=$temporary_directory/radeon_icd.x86_64.json
: > "$model_path"
: > "$fake_icd"

QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 24576 8080

grep -Fx 'affinity=0' "$output_path" >/dev/null
grep -Fx 'nice=19' "$output_path" >/dev/null
grep -Fx 'io=idle' "$output_path" >/dev/null
grep -Fx 'low=1' "$output_path" >/dev/null
grep -Fx 'strict=1' "$output_path" >/dev/null
grep -Fx 'display=unset' "$output_path" >/dev/null
grep -Fx 'wayland=unset' "$output_path" >/dev/null

expected_arguments='--model
'"$model_path"'
--host
127.0.0.1
--port
8080
--no-ui
--log-verbosity
4
--device
Vulkan0
--split-mode
none
--n-gpu-layers
all
--override-tensor
.*=Vulkan0
--fit
off
--ctx-size
24576
--parallel
1
--threads
1
--threads-batch
1
--batch-size
512
--ubatch-size
128
--flash-attn
on
--cache-type-k
q8_0
--cache-type-v
q4_0
--ctx-checkpoints
0
--cache-ram
0
--no-context-shift'

actual_arguments=$(sed -n 's/^argument=//p' "$output_path")
if [ "$actual_arguments" != "$expected_arguments" ]; then
    printf 'fixed policy arguments differ from the expected sequence\n' >&2
    diff -u - "$output_path" <<EOF >&2 || true
$expected_arguments
EOF
    exit 1
fi

if LLAMA_ARG_N_PARALLEL=2 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 24576 8080 \
    >"$temporary_directory/override.stdout" \
    2>"$temporary_directory/override.stderr"; then
    printf 'policy accepted a LLAMA_ARG_* override\n' >&2
    exit 1
fi
grep -F 'environment overrides are forbidden' \
    "$temporary_directory/override.stderr" >/dev/null

if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 24576 80 \
    >"$temporary_directory/port.stdout" \
    2>"$temporary_directory/port.stderr"; then
    printf 'policy accepted a privileged port\n' >&2
    exit 1
fi
grep -F 'port must be an integer from 1024 through 65535' \
    "$temporary_directory/port.stderr" >/dev/null

if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 24577 8080 \
    >"$temporary_directory/context.stdout" \
    2>"$temporary_directory/context.stderr"; then
    printf 'policy accepted a context above 24K\n' >&2
    exit 1
fi
grep -F 'context size exceeds operational maximum: 24577 > 24576' \
    "$temporary_directory/context.stderr" >/dev/null

printf 'qwen_capacity_policy=accepted\n'
