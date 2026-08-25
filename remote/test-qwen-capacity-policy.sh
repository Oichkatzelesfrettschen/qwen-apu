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

QWEN_VULKAN_PROFILE=low-serialized QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 24576 8080

grep -Fx 'affinity=0' "$output_path" >/dev/null
grep -Fx 'nice=19' "$output_path" >/dev/null
grep -Fx 'io=idle' "$output_path" >/dev/null
grep -Fx 'low=1' "$output_path" >/dev/null
grep -Fx 'duty=unset' "$output_path" >/dev/null
grep -Fx 'serialized=1' "$output_path" >/dev/null
grep -Fx 'max_nodes=32' "$output_path" >/dev/null
grep -Fx 'profile=low-serialized' "$output_path" >/dev/null
grep -Fx 'amd_priority=unset' "$output_path" >/dev/null
grep -Fx 'memory_priority=unset' "$output_path" >/dev/null
grep -Fx 'allow_graphics=unset' "$output_path" >/dev/null
grep -Fx 'radv_perftest=unset' "$output_path" >/dev/null
grep -Fx 'strict=1' "$output_path" >/dev/null
grep -Fx 'display=unset' "$output_path" >/dev/null
grep -Fx 'wayland=unset' "$output_path" >/dev/null

expected_arguments='--model
'"$model_path"'
--host
127.0.0.1
--port
8080
--alias
qwen-apu
--cors-origins
localhost
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
128
--ubatch-size
32
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

profile_output=$temporary_directory/profile-policy.out
QWEN_VULKAN_PROFILE=paced-60 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$profile_output \
    "$policy" "$fake_server" "$model_path" 4096 18081
grep -Fx 'duty=60' "$profile_output" >/dev/null
grep -Fx 'serialized=1' "$profile_output" >/dev/null
grep -Fx 'max_nodes=32' "$profile_output" >/dev/null
grep -Fx 'profile=paced-60' "$profile_output" >/dev/null

QWEN_VULKAN_PROFILE=low-async QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$profile_output \
    "$policy" "$fake_server" "$model_path" 4096 18082
grep -Fx 'duty=unset' "$profile_output" >/dev/null
grep -Fx 'serialized=unset' "$profile_output" >/dev/null
grep -Fx 'max_nodes=16' "$profile_output" >/dev/null
grep -Fx 'profile=low-async' "$profile_output" >/dev/null

if QWEN_VULKAN_PROFILE=unknown QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$profile_output \
    "$policy" "$fake_server" "$model_path" 4096 18083 \
    >"$temporary_directory/profile.stdout" \
    2>"$temporary_directory/profile.stderr"; then
    printf 'policy accepted an unknown Vulkan profile\n' >&2
    exit 1
fi
grep -F 'unknown Vulkan profile' "$temporary_directory/profile.stderr" >/dev/null

static_path=$temporary_directory/webui
static_output_path=$temporary_directory/static-policy.out
api_key_file=$temporary_directory/api.key
mkdir -p "$static_path"
: > "$static_path/index.html"
printf 'synthetic-test-key\n' >"$api_key_file"
chmod 600 "$api_key_file"
QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$static_output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 "$static_path" \
    "$api_key_file"
grep -Fx 'argument=--path' "$static_output_path" >/dev/null
grep -Fx "argument=$static_path" "$static_output_path" >/dev/null
grep -Fx 'argument=--ui' "$static_output_path" >/dev/null
grep -Fx 'argument=--api-key-file' "$static_output_path" >/dev/null
grep -Fx "argument=$api_key_file" "$static_output_path" >/dev/null
if grep -Fx 'argument=--no-ui' "$static_output_path" >/dev/null; then
    printf 'static policy disabled the Web UI\n' >&2
    exit 1
fi

if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    "$temporary_directory/missing-webui" "$api_key_file" \
    >"$temporary_directory/static-path.stdout" \
    2>"$temporary_directory/static-path.stderr"; then
    printf 'policy accepted a static path without index.html\n' >&2
    exit 1
fi
grep -F 'static path must contain index.html' \
    "$temporary_directory/static-path.stderr" >/dev/null

empty_key_file=$temporary_directory/empty-api.key
: >"$empty_key_file"
if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 "$static_path" \
    "$empty_key_file" >"$temporary_directory/api-key.stdout" \
    2>"$temporary_directory/api-key.stderr"; then
    printf 'policy accepted an empty API key file\n' >&2
    exit 1
fi
grep -F 'API key file must be a non-empty regular file' \
    "$temporary_directory/api-key.stderr" >/dev/null

if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 "$static_path" \
    >"$temporary_directory/unpaired-static.stdout" \
    2>"$temporary_directory/unpaired-static.stderr"; then
    printf 'policy accepted a static path without an API key\n' >&2
    exit 1
fi
grep -F 'static path and API key file must be supplied together' \
    "$temporary_directory/unpaired-static.stderr" >/dev/null

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
