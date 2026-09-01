#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
policy=$script_directory/qwen-capacity-policy.sh
fixture_server=$script_directory/test-fixtures/fake-llama-server.sh
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

# qwen-build-exec-guard.sh reads the artifact manifest beside the selected
# server and compares that server's own byte count and digest against the
# manifest's executable row, so a fixture standing in for a promoted build is a
# copy beside a manifest rather than the tracked script in place. The generator
# takes the declaration as its argument, which is what lets one helper produce
# the accepted arm and each refused one.
write_fixture_build() {
    fixture_directory=$1
    fixture_semantics=$2
    mkdir -p "$fixture_directory"
    cp "$fixture_server" "$fixture_directory/llama-server"
    chmod 755 "$fixture_directory/llama-server"
    {
        printf 'preset\tfixture\n'
        if [ "$fixture_semantics" != absent ]; then
            printf 'checkpoint_semantics\t%s\n' "$fixture_semantics"
        fi
        printf 'executable\tllama-server\t%s\t%s\n' \
            "$(stat -c %s "$fixture_directory/llama-server")" \
            "$(sha256sum "$fixture_directory/llama-server" | cut -d ' ' -f 1)"
    } >"$fixture_directory/artifact-manifest.tsv"
    printf '%s/llama-server' "$fixture_directory"
}

fake_server=$(write_fixture_build "$temporary_directory/fixture-build" \
    natural-boundary-v1)
QWEN_WEBUI_STATE_DIRECTORY=$temporary_directory/state
export QWEN_WEBUI_STATE_DIRECTORY

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
--parallel
1
--threads
1
--threads-batch
1
--cache-ram
0
--no-context-shift
--offline
--ctx-checkpoints
0
--ctx-size
24576
--batch-size
128
--ubatch-size
32
--flash-attn
on
--cache-type-k
q8_0
--cache-type-v
q4_0'

actual_arguments=$(sed -n 's/^argument=//p' "$output_path")
if [ "$actual_arguments" != "$expected_arguments" ]; then
    printf 'fixed policy arguments differ from the expected sequence\n' >&2
    # Both sides carry argument values alone. Diffing the expected list against
    # the raw capture reports the profile block as a difference and buries the
    # one argument that moved.
    printf '%s\n' "$expected_arguments" >"$temporary_directory/expected.txt"
    printf '%s\n' "$actual_arguments" >"$temporary_directory/actual.txt"
    diff -u "$temporary_directory/expected.txt" \
        "$temporary_directory/actual.txt" >&2 || true
    exit 1
fi

# The KV cache triple comes from the registry row the model path resolves to,
# and the three environment variables override it, so a cache factorial runs
# through the served path. A value outside what llama-server accepts is refused
# before the server sees it.
cache_output=$temporary_directory/cache-policy.out
if QWEN_CACHE_TYPE_K=f16 QWEN_CACHE_TYPE_V=f16 QWEN_FLASH_ATTN=off \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/cache-ceiling.stdout" \
    2>"$temporary_directory/cache-ceiling.stderr"; then
    printf 'policy reused the registered ceiling for an overridden cache tuple\n' >&2
    exit 1
fi
grep -F 'cache-policy overrides require a positive QWEN_CACHE_OVERRIDE_CONTEXT_CEILING' \
    "$temporary_directory/cache-ceiling.stderr" >/dev/null

QWEN_CACHE_TYPE_K=f16 QWEN_CACHE_TYPE_V=f16 QWEN_FLASH_ATTN=off \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=4096 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4096 18080
cache_arguments=$(sed -n 's/^argument=//p' "$cache_output" | tr '\n' ' ')
case $cache_arguments in
    *'--flash-attn off '*'--cache-type-k f16 --cache-type-v f16 '*) ;;
    *)
        printf 'cache overrides did not reach the argument list: %s\n' \
            "$cache_arguments" >&2
        exit 1
        ;;
esac

if QWEN_CACHE_TYPE_K=f16 QWEN_CACHE_TYPE_V=f16 QWEN_FLASH_ATTN=off \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=24577 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/cache-high.stdout" \
    2>"$temporary_directory/cache-high.stderr"; then
    printf 'policy accepted an override ceiling above the registered ceiling\n' >&2
    exit 1
fi
grep -F 'cache override ceiling must not exceed the registered ceiling: 24577 > 24576' \
    "$temporary_directory/cache-high.stderr" >/dev/null

if QWEN_CACHE_TYPE_K=f16 QWEN_CACHE_TYPE_V=f16 QWEN_FLASH_ATTN=off \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=4096 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4097 18080 \
    >"$temporary_directory/cache-context.stdout" \
    2>"$temporary_directory/cache-context.stderr"; then
    printf 'policy accepted a context above the cache override ceiling\n' >&2
    exit 1
fi
grep -F 'context size exceeds the admitted ceiling for this cache policy: 4097 > 4096' \
    "$temporary_directory/cache-context.stderr" >/dev/null

# A fabricated registry carries a triple the fallback never produces, so this
# check separates the registry read from the built-in default.
fabricated_registry=$temporary_directory/models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated research fabricated.gguf download-qwen38-4b-distill-q4km.sh \
    4096 8192 8192 q5_1 iq4_nl auto none - - - untested candidate 256 64 4096 - \
    unmeasured refused \
    >"$fabricated_registry"
registry_model=$temporary_directory/fabricated.gguf
: >"$registry_model"
router_model_root=$temporary_directory
# The draft-pair ledger joins against the model registry, so the fabricated
# registry names its own ledger. An empty one admits no pairing, which is what
# every check below the pair block measures against; the pair checks name a
# populated ledger on their own command lines.
fabricated_draft_pairs=$temporary_directory/draft-pairs.tsv
printf '# the fabricated registry admits no draft pairing\n' \
    >"$fabricated_draft_pairs"
QWEN_DRAFT_PAIRS=$fabricated_draft_pairs
export QWEN_DRAFT_PAIRS
# The context checkpoint ledger joins against the model registry the same way,
# so the fabricated registry names an empty ledger and every section below
# carries the count 0 that an absent row admits; the ledger-driven default is
# measured on its own below with a populated ledger.
fabricated_ctx_checkpoints=$temporary_directory/ctx-checkpoints.tsv
printf '# the fabricated registry admits no checkpoint count\n' \
    >"$fabricated_ctx_checkpoints"
QWEN_CTX_CHECKPOINT_LEDGER=$fabricated_ctx_checkpoints
export QWEN_CTX_CHECKPOINT_LEDGER
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_RADV_ICD=$fake_icd \
    QWEN_MODEL_ROOT=$router_model_root \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$registry_model" 4096 18080
cache_arguments=$(sed -n 's/^argument=//p' "$cache_output" | tr '\n' ' ')
case $cache_arguments in
    *'--batch-size 256 --ubatch-size 64 '*'--flash-attn auto '*'--cache-type-k q5_1 --cache-type-v iq4_nl '*) ;;
    *)
        printf 'registry cache row did not reach the argument list: %s\n' \
            "$cache_arguments" >&2
        exit 1
        ;;
esac

if QWEN_CACHE_TYPE_K=q3_k QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/cache-type.stdout" \
    2>"$temporary_directory/cache-type.stderr"; then
    printf 'policy accepted a cache type llama-server rejects\n' >&2
    exit 1
fi
grep -F 'cache type is outside the set llama-server accepts' \
    "$temporary_directory/cache-type.stderr" >/dev/null

if QWEN_FLASH_ATTN=1 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/flash.stdout" \
    2>"$temporary_directory/flash.stderr"; then
    printf 'policy accepted a flash attention value outside on, off, auto\n' >&2
    exit 1
fi
grep -F 'flash attention must be on, off, or auto' \
    "$temporary_directory/flash.stderr" >/dev/null

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

# A static path alone serves the page without authentication, which the policy
# admits because the key authenticates callers rather than granting the model a
# capability it otherwise withholds. The reverse pairing stays refused: a key
# with nothing to serve names a caller mistake.
if ! QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 "$static_path" \
    >"$temporary_directory/unpaired-static.stdout" \
    2>"$temporary_directory/unpaired-static.stderr"; then
    printf 'policy refused a static path served without an API key\n' >&2
    cat "$temporary_directory/unpaired-static.stderr" >&2
    exit 1
fi
if sed -n 's/^argument=//p' "$output_path" | grep -Fqx -- --api-key-file; then
    printf 'policy passed --api-key-file with no key file supplied\n' >&2
    exit 1
fi

if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$output_path \
    "$policy" "$fake_server" "$model_path" 4096 18080 '' \
    "$temporary_directory/api.key" \
    >"$temporary_directory/unpaired-key.stdout" \
    2>"$temporary_directory/unpaired-key.stderr"; then
    printf 'policy accepted an API key file with no static path\n' >&2
    exit 1
fi
grep -F 'an API key file requires a static path' \
    "$temporary_directory/unpaired-key.stderr" >/dev/null

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
    printf 'policy accepted a context above the registered ceiling\n' >&2
    exit 1
fi
grep -F 'context size exceeds the admitted ceiling for this cache policy: 24577 > 24576' \
    "$temporary_directory/context.stderr" >/dev/null

# Router mode replaces the single model with a preset file and a resident-model
# limit, and drops the fixed alias because the preset supplies one per
# checkpoint. Every guard flag stays, because llama-server cascades this argv
# onto each child it spawns.
append_complete_router_section() {
    router_section_file=$1
    {
        printf '[fabricated]\n'
        printf 'LLAMA_ARG_MODEL = %s\n' "$registry_model"
        printf 'LLAMA_ARG_CTX_SIZE = 4096\n'
        printf 'LLAMA_ARG_CACHE_TYPE_K = q5_1\n'
        printf 'LLAMA_ARG_CACHE_TYPE_V = iq4_nl\n'
        printf 'LLAMA_ARG_FLASH_ATTN = auto\n'
        printf 'LLAMA_ARG_BATCH = 256\n'
        printf 'LLAMA_ARG_UBATCH = 64\n'
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
    } >>"$router_section_file"
}
router_presets=$temporary_directory/router-presets.ini
: >"$router_presets"
append_complete_router_section "$router_presets"
router_output=$temporary_directory/router.out
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$model_path" 4096 18080
router_arguments=$(sed -n 's/^argument=//p' "$router_output" | tr '\n' ' ')
case $router_arguments in
    *"--models-preset $router_presets --models-max 1 "*) ;;
    *)
        printf 'router preset arguments did not reach the argument list: %s\n' \
            "$router_arguments" >&2
        exit 1
        ;;
esac

# Preset validation consumes the same router-child quarantine authority as
# generation. A persisted section can match models.tsv exactly and still lose
# admission when a later model- or profile-scope quarantine row arrives.
router_model_quarantine=$temporary_directory/router-model-quarantine.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated-model model fabricated no-validated-safe-tuple - - - - - - \
    evidence/x.md evidence/y.md evidence/z.md router-child \
    >"$router_model_quarantine"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_model_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/router-model-quarantine.stdout" \
    2>"$temporary_directory/router-model-quarantine.stderr"; then
    printf 'router accepted a stale preset under model quarantine\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated is excluded by model quarantine' \
    "$temporary_directory/router-model-quarantine.stderr" >/dev/null

router_profile_quarantine=$temporary_directory/router-profile-quarantine.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated-profile profile fabricated ring-timeout-only 4096 256 64 \
    q5_1 iq4_nl auto evidence/x.md evidence/y.md evidence/z.md any \
    >"$router_profile_quarantine"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/router-profile-quarantine.stdout" \
    2>"$temporary_directory/router-profile-quarantine.stderr"; then
    printf 'router accepted a stale preset under profile quarantine\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated is excluded by profile quarantine' \
    "$temporary_directory/router-profile-quarantine.stderr" >/dev/null

# An ambient research override cannot bless a preset that records no override.
# The persisted marker governs both section admission and later loopback policy.
marker_zero_router_presets=$temporary_directory/marker-zero-router-presets.ini
printf '%s\n' '# qwen_router_include_quarantine=0' \
    >"$marker_zero_router_presets"
append_complete_router_section "$marker_zero_router_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_ROUTER_INCLUDE_QUARANTINE=1 \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$marker_zero_router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/marker-zero-router.stdout" \
    2>"$temporary_directory/marker-zero-router.stderr"; then
    printf 'ambient override admitted a marker-zero stale preset\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated is excluded by profile quarantine' \
    "$temporary_directory/marker-zero-router.stderr" >/dev/null

# Profile authority is tuple-exact. A quarantine at a neighbouring depth leaves
# the persisted 4096-token section admitted.
router_neighbour_quarantine=$temporary_directory/router-neighbour-quarantine.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated-neighbour profile fabricated ring-timeout-only 8192 256 64 \
    q5_1 iq4_nl auto evidence/x.md evidence/y.md evidence/z.md any \
    >"$router_neighbour_quarantine"
QWEN_MODEL_REGISTRY=$fabricated_registry \
QWEN_QUARANTINE_REGISTRY=$router_neighbour_quarantine \
QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080
grep -Fx "argument=$router_presets" "$router_output" >/dev/null

# Missing or malformed authority stops router launch before a stale preset can
# be interpreted as admitted.
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$temporary_directory/absent-router-quarantine.tsv \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/absent-router-quarantine.stdout" \
    2>"$temporary_directory/absent-router-quarantine.stderr"; then
    printf 'router accepted missing quarantine authority\n' >&2
    exit 1
fi
grep -F 'router quarantine authority is unavailable' \
    "$temporary_directory/absent-router-quarantine.stderr" >/dev/null

malformed_router_quarantine=$temporary_directory/malformed-router-quarantine.tsv
printf 'malformed\trow\n' >"$malformed_router_quarantine"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$malformed_router_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/malformed-router-quarantine.stdout" \
    2>"$temporary_directory/malformed-router-quarantine.stderr"; then
    printf 'router accepted malformed quarantine authority\n' >&2
    exit 1
fi
grep -F 'router quarantine authority is unavailable' \
    "$temporary_directory/malformed-router-quarantine.stderr" >/dev/null

semantic_malformed_router_quarantine=$temporary_directory/semantic-malformed-router-quarantine.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    malformed-profile profile fabricated ring-timeout-only not-a-depth 256 64 \
    q5_1 iq4_nl auto evidence/x.md evidence/y.md evidence/z.md router-child \
    >"$semantic_malformed_router_quarantine"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$semantic_malformed_router_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/semantic-malformed-router-quarantine.stdout" \
    2>"$temporary_directory/semantic-malformed-router-quarantine.stderr"; then
    printf 'router accepted semantically malformed quarantine authority\n' >&2
    exit 1
fi
grep -F 'router quarantine authority is unavailable' \
    "$temporary_directory/semantic-malformed-router-quarantine.stderr" >/dev/null

# The router preflight subject sizes installed weights only. Its standalone
# context ceiling does not constrain other preset sections, and the listener
# carries none of the six per-checkpoint tuple flags.
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
QWEN_ROUTER_PRESETS=$router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080
router_candidate_arguments=$(sed -n 's/^argument=//p' "$router_output" |
    tr '\n' ' ')
case " $router_candidate_arguments " in
    *' --models-preset '* ) ;;
    *)
        printf 'candidate-only router did not reach the argument list: %s\n' \
            "$router_candidate_arguments" >&2
        exit 1
        ;;
esac
for overridden_flag in --ctx-size --batch-size --ubatch-size --flash-attn \
    --cache-type-k --cache-type-v --ctx-checkpoints; do
    case " $router_candidate_arguments " in
        *" $overridden_flag "*)
            printf 'candidate-only router carries tuple flag %s: %s\n' \
                "$overridden_flag" "$router_candidate_arguments" >&2
            exit 1
            ;;
    esac
done

incomplete_router_presets=$temporary_directory/incomplete-router-presets.ini
sed '/^LLAMA_ARG_UBATCH =/d' "$router_presets" >"$incomplete_router_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$incomplete_router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/incomplete-router.stdout" \
    2>"$temporary_directory/incomplete-router.stderr"; then
    printf 'router accepted a preset section with an incomplete tuple\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated requires exactly one LLAMA_ARG_UBATCH, found 0' \
    "$temporary_directory/incomplete-router.stderr" >/dev/null
grep -F 'router presets do not carry complete admitted tuples:' \
    "$temporary_directory/incomplete-router.stderr" >/dev/null

# The checkpoint count is the seventh required key: absent, repeated, and
# differing from the ledger each refuse, since an absent key falls to the
# pinned build's default of 32 host copies of the recurrent state.
absent_checkpoint_presets=$temporary_directory/absent-checkpoint-router-presets.ini
sed '/^LLAMA_ARG_CTX_CHECKPOINTS =/d' "$router_presets" >"$absent_checkpoint_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$absent_checkpoint_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/absent-checkpoint-router.stdout" \
    2>"$temporary_directory/absent-checkpoint-router.stderr"; then
    printf 'router accepted a preset section without a checkpoint count\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated requires exactly one LLAMA_ARG_CTX_CHECKPOINTS, found 0' \
    "$temporary_directory/absent-checkpoint-router.stderr" >/dev/null
duplicate_checkpoint_presets=$temporary_directory/duplicate-checkpoint-router-presets.ini
{ cat "$router_presets"; printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'; } \
    >"$duplicate_checkpoint_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$duplicate_checkpoint_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/duplicate-checkpoint-router.stdout" \
    2>"$temporary_directory/duplicate-checkpoint-router.stderr"; then
    printf 'router accepted a preset section with two checkpoint counts\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated requires exactly one LLAMA_ARG_CTX_CHECKPOINTS, found 2' \
    "$temporary_directory/duplicate-checkpoint-router.stderr" >/dev/null
mismatched_checkpoint_presets=$temporary_directory/mismatched-checkpoint-router-presets.ini
sed 's/^LLAMA_ARG_CTX_CHECKPOINTS = 0$/LLAMA_ARG_CTX_CHECKPOINTS = 3/' \
    "$router_presets" >"$mismatched_checkpoint_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$mismatched_checkpoint_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/mismatched-checkpoint-router.stdout" \
    2>"$temporary_directory/mismatched-checkpoint-router.stderr"; then
    printf 'router accepted a checkpoint count the ledger refuses\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries LLAMA_ARG_CTX_CHECKPOINTS 3, the context checkpoint ledger admits 0' \
    "$temporary_directory/mismatched-checkpoint-router.stderr" >/dev/null
noninteger_checkpoint_presets=$temporary_directory/noninteger-checkpoint-router-presets.ini
sed 's/^LLAMA_ARG_CTX_CHECKPOINTS = 0$/LLAMA_ARG_CTX_CHECKPOINTS = 02/' \
    "$router_presets" >"$noninteger_checkpoint_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$noninteger_checkpoint_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/noninteger-checkpoint-router.stdout" \
    2>"$temporary_directory/noninteger-checkpoint-router.stderr"; then
    printf 'router accepted a non-canonical checkpoint count\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries invalid LLAMA_ARG_CTX_CHECKPOINTS: 02' \
    "$temporary_directory/noninteger-checkpoint-router.stderr" >/dev/null

unsafe_geometry_presets=$temporary_directory/unsafe-geometry-router-presets.ini
sed -e 's/^LLAMA_ARG_BATCH = 256$/LLAMA_ARG_BATCH = 2048/' \
    -e 's/^LLAMA_ARG_UBATCH = 64$/LLAMA_ARG_UBATCH = 512/' \
    "$router_presets" >"$unsafe_geometry_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$unsafe_geometry_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/unsafe-geometry-router.stdout" \
    2>"$temporary_directory/unsafe-geometry-router.stderr"; then
    printf 'router accepted a positive but unadmitted submission geometry\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries LLAMA_ARG_BATCH 2048, registry admits 256' \
    "$temporary_directory/unsafe-geometry-router.stderr" >/dev/null

unknown_cache_presets=$temporary_directory/unknown-cache-router-presets.ini
sed 's/^LLAMA_ARG_CACHE_TYPE_K = q5_1$/LLAMA_ARG_CACHE_TYPE_K = q3_unknown/' \
    "$router_presets" >"$unknown_cache_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$unknown_cache_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/unknown-cache-router.stdout" \
    2>"$temporary_directory/unknown-cache-router.stderr"; then
    printf 'router accepted a preset with an unknown cache encoding\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries invalid LLAMA_ARG_CACHE_TYPE_K: q3_unknown' \
    "$temporary_directory/unknown-cache-router.stderr" >/dev/null

supported_cache_presets=$temporary_directory/supported-cache-router-presets.ini
sed 's/^LLAMA_ARG_CACHE_TYPE_K = q5_1$/LLAMA_ARG_CACHE_TYPE_K = f16/' \
    "$router_presets" >"$supported_cache_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$supported_cache_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/supported-cache-router.stdout" \
    2>"$temporary_directory/supported-cache-router.stderr"; then
    printf 'router accepted a supported but unadmitted cache encoding\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries LLAMA_ARG_CACHE_TYPE_K f16, registry admits q5_1' \
    "$temporary_directory/supported-cache-router.stderr" >/dev/null

unregistered_router_presets=$temporary_directory/unregistered-router-presets.ini
sed 's/^\[fabricated\]$/[unregistered]/' \
    "$router_presets" >"$unregistered_router_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$unregistered_router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/unregistered-router.stdout" \
    2>"$temporary_directory/unregistered-router.stderr"; then
    printf 'router accepted a preset section absent from the registry\n' >&2
    exit 1
fi
grep -F 'router preset section unregistered resolves to 0 registry rows' \
    "$temporary_directory/unregistered-router.stderr" >/dev/null

repointed_router_presets=$temporary_directory/repointed-router-presets.ini
alternate_model_root=$temporary_directory/alternate-model-root
alternate_model_path=$alternate_model_root/fabricated.gguf
mkdir -p "$alternate_model_root"
: >"$alternate_model_path"
sed "s|^LLAMA_ARG_MODEL = .*|LLAMA_ARG_MODEL = $alternate_model_path|" \
    "$router_presets" >"$repointed_router_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$repointed_router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$registry_model" 24576 18080 \
    >"$temporary_directory/repointed-router.stdout" \
    2>"$temporary_directory/repointed-router.stderr"; then
    printf 'router accepted a section pointed at another model file\n' >&2
    exit 1
fi
grep -F "router preset section fabricated carries LLAMA_ARG_MODEL $alternate_model_path, registry admits $router_model_root/fabricated.gguf" \
    "$temporary_directory/repointed-router.stderr" >/dev/null

# Registry tier changes invalidate persisted sections even when every runtime
# tuple field still matches. Archive and rejected rows never reach a generated
# router preset.
archived_registry=$temporary_directory/archived-models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated research fabricated.gguf download-qwen38-4b-distill-q4km.sh \
    4096 8192 8192 q5_1 iq4_nl auto none - - - untested archive 256 64 4096 - unmeasured refused \
    >"$archived_registry"
if QWEN_MODEL_REGISTRY=$archived_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/archived-router.stdout" \
    2>"$temporary_directory/archived-router.stderr"; then
    printf 'router accepted a persisted section after archival\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated has non-servable registry tier archive' \
    "$temporary_directory/archived-router.stderr" >/dev/null

# A quarantine tier requires both the durable override and model-scope
# router-child authority. The marker alone cannot manufacture that authority.
quarantine_tier_registry=$temporary_directory/quarantine-tier-models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    fabricated research fabricated.gguf download-qwen38-4b-distill-q4km.sh \
    4096 8192 8192 q5_1 iq4_nl auto none - - - untested quarantine 256 64 4096 - unmeasured refused \
    >"$quarantine_tier_registry"
unowned_quarantine_preset=$temporary_directory/unowned-quarantine-tier.ini
printf '%s\n' '# qwen_router_include_quarantine=1' \
    >"$unowned_quarantine_preset"
append_complete_router_section "$unowned_quarantine_preset"
if QWEN_MODEL_REGISTRY=$quarantine_tier_registry \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$unowned_quarantine_preset \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/unowned-quarantine-tier.stdout" \
    2>"$temporary_directory/unowned-quarantine-tier.stderr"; then
    printf 'router accepted a quarantine tier without model authority\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated lacks an admitted model quarantine override' \
    "$temporary_directory/unowned-quarantine-tier.stderr" >/dev/null

case $router_arguments in
    *'--model '*)
        printf 'router mode still passed a single model: %s\n' \
            "$router_arguments" >&2
        exit 1
        ;;
esac
case $router_arguments in
    *'--device Vulkan0 '*'--override-tensor .*=Vulkan0 '*'--no-context-shift'*) ;;
    *)
        printf 'router mode dropped a guard flag: %s\n' "$router_arguments" >&2
        exit 1
        ;;
esac

# The pinned llama-ui declares exec_shell_command, write_file, and edit_file as
# ToolSource.SERVER, so llama-server executes them and the UI merely offers
# them. The server grants them through --tools, and the appliance binds 0.0.0.0,
# so the flag reaching either argv would put shell execution and file writing on
# the LAN behind a prompt-injectable model.
for tool_argv in "$actual_arguments" "$router_arguments"; do
    case " $tool_argv " in
        *' --tools '* | *' --tool '*)
            printf 'a tool grant reached the server argument list: %s\n' \
                "$tool_argv" >&2
            exit 1
            ;;
    esac
done

# server-models.cpp overlays the router's own CLI arguments on top of every
# model preset with common_preset::merge, which overwrites, so any of these six
# on the router argv silently replaces the same key in every section. Router
# mode leaves them to the preset file for that reason.
for overridden_flag in --ctx-size --batch-size --ubatch-size --flash-attn \
    --cache-type-k --cache-type-v --ctx-checkpoints; do
    case " $router_arguments " in
        *" $overridden_flag "*)
            printf 'router argv carries %s, which overwrites every model preset: %s\n' \
                "$overridden_flag" "$router_arguments" >&2
            exit 1
            ;;
    esac
done

# An unreadable preset file is refused rather than starting a router with no
# models, which would serve a picker listing nothing.
if QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$temporary_directory/absent.ini \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/router.stdout" \
    2>"$temporary_directory/router.stderr"; then
    printf 'policy accepted router mode with an unreadable preset file\n' >&2
    exit 1
fi
grep -F 'router presets are unreadable' "$temporary_directory/router.stderr" >/dev/null

# A launcher-bound snapshot carries the digest measured before memory preflight.
# Any mutation before the server exec boundary invalidates the launch.
wrong_router_preset_sha256=0000000000000000000000000000000000000000000000000000000000000000
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets \
    QWEN_ROUTER_PRESET_SHA256=$wrong_router_preset_sha256 \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/router-identity.stdout" \
    2>"$temporary_directory/router-identity.stderr"; then
    printf 'policy accepted a router preset with the wrong identity\n' >&2
    exit 1
fi
grep -F 'router preset identity changed:' \
    "$temporary_directory/router-identity.stderr" >/dev/null

identity_bin=$temporary_directory/identity-bin
identity_count=$temporary_directory/identity-count
mkdir -p "$identity_bin"
cat >"$identity_bin/sha256sum" <<'SHA256SUM'
#!/bin/sh
if [ "$1" != "$QWEN_ROUTER_PRESETS" ]; then
    exec "$QWEN_TEST_REAL_SHA256SUM" "$@"
fi
count=0
if [ -r "$QWEN_TEST_IDENTITY_COUNT" ]; then
    count=$(sed -n '1p' "$QWEN_TEST_IDENTITY_COUNT")
fi
count=$((count + 1))
printf '%s\n' "$count" >"$QWEN_TEST_IDENTITY_COUNT"
if [ "$count" -eq 1 ]; then
    exec "$QWEN_TEST_REAL_SHA256SUM" "$@"
fi
printf '%s  %s\n' \
    0000000000000000000000000000000000000000000000000000000000000000 "$1"
SHA256SUM
chmod +x "$identity_bin/sha256sum"
router_preset_identity=$(sha256sum "$router_presets")
router_preset_sha256=${router_preset_identity%% *}
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets \
    QWEN_ROUTER_PRESET_SHA256=$router_preset_sha256 \
    QWEN_TEST_IDENTITY_COUNT=$identity_count \
    QWEN_TEST_REAL_SHA256SUM=$(command -v sha256sum) \
    PATH="$identity_bin:$PATH" \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/router-identity-race.stdout" \
    2>"$temporary_directory/router-identity-race.stderr"; then
    printf 'policy accepted a router preset mutated after validation\n' >&2
    exit 1
fi
grep -Fx 2 "$identity_count" >/dev/null
grep -F 'router preset identity changed:' \
    "$temporary_directory/router-identity-race.stderr" >/dev/null

# The final exec guard retains the identities validated by the policy across
# Vulkan environment setup. A quarantine replacement inside that wrapper
# therefore rejects the assembled command before the fake server records it.
authority_race_tools=$temporary_directory/authority-race-tools
authority_race_quarantine=$temporary_directory/authority-race-quarantine.tsv
authority_race_output=$temporary_directory/authority-race.out
mkdir -p "$authority_race_tools"
cp "$policy" "$authority_race_tools/qwen-capacity-policy.sh"
cp "$script_directory/qwen-router-exec-guard.sh" \
    "$authority_race_tools/qwen-router-exec-guard.sh"
# The build guard precedes the router guard on the exec chain, so the copied
# tools directory carries it or the chain breaks before the authority recheck
# this arm measures.
cp "$script_directory/qwen-build-exec-guard.sh" \
    "$authority_race_tools/qwen-build-exec-guard.sh"
: >"$authority_race_quarantine"
cat >"$authority_race_tools/model-registry.sh" <<'REGISTRY'
#!/bin/sh
exec "$QWEN_TEST_REAL_MODEL_REGISTRY" "$@"
REGISTRY
cat >"$authority_race_tools/radv-low-priority-env.sh" <<'RADV'
#!/bin/sh
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    authority-race profile fabricated ring-timeout-only \
    4096 256 64 q5_1 iq4_nl auto \
    evidence/x.md evidence/y.md evidence/z.md router-child \
    >"$QWEN_QUARANTINE_REGISTRY"
exec "$@"
RADV
chmod +x "$authority_race_tools"/*.sh
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$authority_race_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$authority_race_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$router_presets \
    QWEN_TEST_REAL_MODEL_REGISTRY=$script_directory/model-registry.sh \
    "$authority_race_tools/qwen-capacity-policy.sh" \
        "$fake_server" "$registry_model" 4096 18080 \
        >"$temporary_directory/authority-race.stdout" \
        2>"$temporary_directory/authority-race.stderr"; then
    printf 'policy accepted quarantine authority replaced before exec\n' >&2
    exit 1
fi
grep -F 'router quarantine registry identity changed:' \
    "$temporary_directory/authority-race.stderr" >/dev/null
if [ -e "$authority_race_output" ]; then
    printf 'fake server ran after exec-boundary authority rejection\n' >&2
    exit 1
fi

# The final guard verifies the complete web-ledger identity as a fourth
# authority pair. A replacement after policy validation stops before the
# command records execution.
exec_guard=$script_directory/qwen-router-exec-guard.sh
guard_web_profiles=$temporary_directory/guard-web-profiles.tsv
guard_command=$temporary_directory/guard-command.sh
guard_command_output=$temporary_directory/guard-command.out
printf 'web-fixture\tfixture\tvalidator-gated\t4096\t4096\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\n' \
    >"$guard_web_profiles"
cat >"$guard_command" <<'GUARD_COMMAND'
#!/bin/sh
printf 'executed\n' >"$QWEN_TEST_GUARD_COMMAND_OUTPUT"
GUARD_COMMAND
chmod +x "$guard_command"
guard_preset_sha256=$(sha256sum "$router_presets" | cut -d' ' -f1)
guard_model_sha256=$(sha256sum "$fabricated_registry" | cut -d' ' -f1)
guard_quarantine_sha256=$(sha256sum "$authority_race_quarantine" | cut -d' ' -f1)
guard_web_profiles_sha256=$(sha256sum "$guard_web_profiles" | cut -d' ' -f1)
guard_ctx_ledger=$temporary_directory/guard-ctx-checkpoints.tsv
printf 'guard-fixture\t2\t-\n' >"$guard_ctx_ledger"
guard_ctx_ledger_sha256=$(sha256sum "$guard_ctx_ledger" | cut -d' ' -f1)
printf 'changed\n' >>"$guard_web_profiles"
if QWEN_TEST_GUARD_COMMAND_OUTPUT=$guard_command_output \
    "$exec_guard" "$router_presets" "$guard_preset_sha256" \
    "$fabricated_registry" "$guard_model_sha256" \
    "$authority_race_quarantine" "$guard_quarantine_sha256" \
    - - \
    "$guard_web_profiles" "$guard_web_profiles_sha256" \
    "$guard_ctx_ledger" "$guard_ctx_ledger_sha256" "$guard_command" \
    >"$temporary_directory/web-ledger-guard.stdout" \
    2>"$temporary_directory/web-ledger-guard.stderr"; then
    printf 'exec guard accepted a replaced web profile ledger\n' >&2
    exit 1
fi
grep -F 'router web profile ledger identity changed:' \
    "$temporary_directory/web-ledger-guard.stderr" >/dev/null
if [ -e "$guard_command_output" ]; then
    printf 'guarded command ran after web-ledger identity rejection\n' >&2
    exit 1
fi

# The context checkpoint ledger is the sixth authority pair and it is required
# rather than optional, because every router and web preset section carries
# LLAMA_ARG_CTX_CHECKPOINTS. An unchanged ledger reaches the command; a
# replacement, a removal, and a wrong digest each stop before it runs.
guard_web_profiles_unchanged=$temporary_directory/guard-web-profiles-unchanged.tsv
printf 'web-fixture\tfixture\tvalidator-gated\t4096\t4096\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\n' \
    >"$guard_web_profiles_unchanged"
guard_web_unchanged_sha256=$(sha256sum "$guard_web_profiles_unchanged" | cut -d' ' -f1)
run_ctx_ledger_guard() {
    ctx_guard_label=$1
    ctx_guard_path=$2
    ctx_guard_sha256=$3
    rm -f "$guard_command_output"
    QWEN_TEST_GUARD_COMMAND_OUTPUT=$guard_command_output \
        "$exec_guard" "$router_presets" "$guard_preset_sha256" \
        "$fabricated_registry" "$guard_model_sha256" \
        "$authority_race_quarantine" "$guard_quarantine_sha256" \
        - - \
        "$guard_web_profiles_unchanged" "$guard_web_unchanged_sha256" \
        "$ctx_guard_path" "$ctx_guard_sha256" "$guard_command" \
        >"$temporary_directory/ctx-guard-$ctx_guard_label.stdout" \
        2>"$temporary_directory/ctx-guard-$ctx_guard_label.stderr"
}
if ! run_ctx_ledger_guard accepted "$guard_ctx_ledger" \
    "$guard_ctx_ledger_sha256"; then
    printf 'exec guard refused an unchanged context checkpoint ledger\n' >&2
    exit 1
fi
grep -Fx executed "$guard_command_output" >/dev/null
printf 'guard-fixture\t0\t-\n' >"$guard_ctx_ledger"
if run_ctx_ledger_guard changed "$guard_ctx_ledger" \
    "$guard_ctx_ledger_sha256"; then
    printf 'exec guard accepted a replaced context checkpoint ledger\n' >&2
    exit 1
fi
grep -F 'router context checkpoint ledger identity changed:' \
    "$temporary_directory/ctx-guard-changed.stderr" >/dev/null
if [ -e "$guard_command_output" ]; then
    printf 'guarded command ran after checkpoint ledger identity rejection\n' >&2
    exit 1
fi
rm -f "$guard_ctx_ledger"
if run_ctx_ledger_guard removed "$guard_ctx_ledger" \
    "$guard_ctx_ledger_sha256"; then
    printf 'exec guard accepted a removed context checkpoint ledger\n' >&2
    exit 1
fi
grep -F 'router context checkpoint ledger identity cannot be measured:' \
    "$temporary_directory/ctx-guard-removed.stderr" >/dev/null
if [ -e "$guard_command_output" ]; then
    printf 'guarded command ran after checkpoint ledger removal\n' >&2
    exit 1
fi
printf 'guard-fixture\t2\t-\n' >"$guard_ctx_ledger"
if run_ctx_ledger_guard digest "$guard_ctx_ledger" \
    0000000000000000000000000000000000000000000000000000000000000000; then
    printf 'exec guard accepted a wrong checkpoint ledger digest\n' >&2
    exit 1
fi
grep -F 'router context checkpoint ledger identity changed:' \
    "$temporary_directory/ctx-guard-digest.stderr" >/dev/null
if run_ctx_ledger_guard malformed "$guard_ctx_ledger" not-a-digest; then
    printf 'exec guard accepted a malformed checkpoint ledger digest\n' >&2
    exit 1
fi
grep -F 'router context checkpoint ledger SHA-256 must hold 64 lowercase hexadecimal characters' \
    "$temporary_directory/ctx-guard-malformed.stderr" >/dev/null
if [ -e "$guard_command_output" ]; then
    printf 'guarded command ran after checkpoint digest rejection\n' >&2
    exit 1
fi

# The ledger path reaches the guard as one argument, so a directory holding a
# space stays one authority rather than splitting into two.
guard_spaced_directory="$temporary_directory/guard ctx directory"
mkdir -p "$guard_spaced_directory"
guard_spaced_ledger="$guard_spaced_directory/ctx-checkpoints.tsv"
cp "$guard_ctx_ledger" "$guard_spaced_ledger"
guard_spaced_sha256=$(sha256sum "$guard_spaced_ledger" | cut -d' ' -f1)
if ! run_ctx_ledger_guard spaced "$guard_spaced_ledger" \
    "$guard_spaced_sha256"; then
    printf 'exec guard lost a checkpoint ledger path holding a space\n' >&2
    exit 1
fi
grep -Fx executed "$guard_command_output" >/dev/null

# A successful launch alone proves nothing about what the policy handed the
# guard, so a recorder in place of the guard reads the assembled argv. The
# checkpoint pair occupies positions 11 and 12 and carries the ledger this
# launch validated, beside the `-` pair a router preset leaves for the web
# ledger.
carrier_tools=$temporary_directory/identity-carrier-tools
carrier_record=$temporary_directory/identity-carrier.argv
carrier_quarantine=$temporary_directory/identity-carrier-quarantine.tsv
carrier_output=$temporary_directory/identity-carrier.out
mkdir -p "$carrier_tools"
: >"$carrier_quarantine"
cp "$policy" "$carrier_tools/qwen-capacity-policy.sh"
cp "$script_directory/qwen-build-exec-guard.sh" \
    "$carrier_tools/qwen-build-exec-guard.sh"
cat >"$carrier_tools/model-registry.sh" <<'REGISTRY'
#!/bin/sh
exec "$QWEN_TEST_REAL_MODEL_REGISTRY" "$@"
REGISTRY
cat >"$carrier_tools/radv-low-priority-env.sh" <<'RADV'
#!/bin/sh
exec "$@"
RADV
cat >"$carrier_tools/qwen-router-exec-guard.sh" <<'RECORDER'
#!/bin/sh
: >"$QWEN_TEST_GUARD_ARGV"
for guard_argument in "$@"; do
    printf '%s\n' "$guard_argument" >>"$QWEN_TEST_GUARD_ARGV"
done
RECORDER
chmod +x "$carrier_tools"/*.sh
run_identity_carrier() {
    rm -f "$carrier_record" "$carrier_output"
    QWEN_MODEL_REGISTRY=$fabricated_registry \
        QWEN_QUARANTINE_REGISTRY=$carrier_quarantine \
        QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
        QWEN_POLICY_TEST_OUTPUT=$carrier_output \
        QWEN_TEST_GUARD_ARGV=$carrier_record \
        QWEN_TEST_REAL_MODEL_REGISTRY=$script_directory/model-registry.sh \
        "$@"
}
carrier_ctx_sha256=$(sha256sum "$fabricated_ctx_checkpoints" | cut -d' ' -f1)
if ! run_identity_carrier env QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS="$router_presets" QWEN_ROUTER_MAX=1 \
    "$carrier_tools/qwen-capacity-policy.sh" \
    "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/identity-carrier.stdout" \
    2>"$temporary_directory/identity-carrier.stderr"; then
    printf 'policy refused the router launch the identity recorder observes\n' >&2
    cat "$temporary_directory/identity-carrier.stderr" >&2
    exit 1
fi
carrier_web_path=$(sed -n '9p' "$carrier_record")
carrier_web_sha256=$(sed -n '10p' "$carrier_record")
carrier_ctx_path=$(sed -n '11p' "$carrier_record")
carrier_ctx_carried_sha256=$(sed -n '12p' "$carrier_record")
if [ "$carrier_web_path" != - ] || [ "$carrier_web_sha256" != - ]; then
    printf 'router preset carried a web profile ledger pair: %s %s\n' \
        "$carrier_web_path" "$carrier_web_sha256" >&2
    exit 1
fi
if [ "$carrier_ctx_path" != "$fabricated_ctx_checkpoints" ]; then
    printf 'exec chain carried checkpoint ledger %s where the launch read %s\n' \
        "$carrier_ctx_path" "$fabricated_ctx_checkpoints" >&2
    exit 1
fi
if [ "$carrier_ctx_carried_sha256" != "$carrier_ctx_sha256" ]; then
    printf 'exec chain carried checkpoint ledger digest %s where the file measures %s\n' \
        "$carrier_ctx_carried_sha256" "$carrier_ctx_sha256" >&2
    exit 1
fi

# The standalone path leaves the guard out of the chain entirely, since it
# assembles the tuple from the row it launches rather than from a preset that
# persists. The recorder therefore stays untouched while the server still runs.
if ! run_identity_carrier "$carrier_tools/qwen-capacity-policy.sh" \
    "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/identity-standalone.stdout" \
    2>"$temporary_directory/identity-standalone.stderr"; then
    printf 'policy refused the standalone launch the identity recorder observes\n' >&2
    cat "$temporary_directory/identity-standalone.stderr" >&2
    exit 1
fi
if [ -e "$carrier_record" ]; then
    printf 'standalone launch reached the router exec guard\n' >&2
    exit 1
fi
grep -Fx "argument=--ctx-checkpoints" "$carrier_output" >/dev/null

# The count override reaches neither the router argv nor a preset section, so a
# router launch carrying it would serve the ledger's count while its name says
# otherwise. Router mode refuses it and the single-model path applies it.
count_override_output=$temporary_directory/count-override.out
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$count_override_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets QWEN_ROUTER_MAX=1 \
    QWEN_CTX_CHECKPOINTS=2 \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/count-override.stdout" \
    2>"$temporary_directory/count-override.stderr"; then
    printf 'policy accepted a checkpoint count override in router mode\n' >&2
    exit 1
fi
grep -F 'QWEN_CTX_CHECKPOINTS is refused in router mode:' \
    "$temporary_directory/count-override.stderr" >/dev/null
if [ -e "$count_override_output" ]; then
    printf 'server ran after the router-mode count refusal\n' >&2
    exit 1
fi
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$count_override_output \
    QWEN_CTX_CHECKPOINTS=2 \
    "$policy" "$fake_server" "$registry_model" 4096 18080 >/dev/null
count_override_arguments=$(sed -n 's/^argument=//p' "$count_override_output" |
    tr '\n' ' ')
case $count_override_arguments in
    *'--ctx-checkpoints 2 '*) ;;
    *)
        printf 'standalone launch lost the checkpoint count override: %s\n' \
            "$count_override_arguments" >&2
        exit 1
        ;;
esac

# The checkpoint spacing reaches the router's own argv, where
# common_preset::merge would place every child's checkpoints from one value
# while each section still matched the ledger's count. The ledger states a count
# and no authority states a spacing, so router mode refuses the override and the
# single-model path takes it.
spacing_output=$temporary_directory/spacing.out
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$spacing_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets QWEN_ROUTER_MAX=1 \
    QWEN_CHECKPOINT_MIN_STEP=4096 \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/spacing-router.stdout" \
    2>"$temporary_directory/spacing-router.stderr"; then
    printf 'policy accepted a checkpoint spacing override in router mode\n' >&2
    exit 1
fi
grep -F 'QWEN_CHECKPOINT_MIN_STEP is refused in router mode:' \
    "$temporary_directory/spacing-router.stderr" >/dev/null
if [ -e "$spacing_output" ]; then
    printf 'server ran after the router-mode spacing refusal\n' >&2
    exit 1
fi
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$spacing_output \
    QWEN_CHECKPOINT_MIN_STEP=4096 \
    "$policy" "$fake_server" "$registry_model" 4096 18080 >/dev/null
spacing_arguments=$(sed -n 's/^argument=//p' "$spacing_output" | tr '\n' ' ')
case $spacing_arguments in
    *'--checkpoint-min-step 4096 '*) ;;
    *)
        printf 'standalone launch lost the checkpoint spacing: %s\n' \
            "$spacing_arguments" >&2
        exit 1
        ;;
esac

# The guard digest is measured once and the checkpoint ledger is validated
# twice, so a file holding the admitted rows at each validation and revoked rows
# at the measurement would hand the guard a digest naming content no validation
# read. The launch remeasures the ledger after the final validation and requires
# the two to agree, so the recorder stays untouched.
ledger_window_bin=$temporary_directory/ledger-window-bin
mkdir -p "$ledger_window_bin"
cat >"$ledger_window_bin/sha256sum" <<'SHA256SUM'
#!/bin/sh
if [ "${1:-}" != "$QWEN_TEST_LEDGER_PATH" ]; then
    exec "$QWEN_TEST_REAL_SHA256SUM" "$@"
fi
ledger_window_count=0
if [ -r "$QWEN_TEST_LEDGER_COUNT" ]; then
    ledger_window_count=$(cat "$QWEN_TEST_LEDGER_COUNT")
fi
ledger_window_count=$((ledger_window_count + 1))
printf '%s\n' "$ledger_window_count" >"$QWEN_TEST_LEDGER_COUNT"
if [ "$ledger_window_count" -eq 1 ]; then
    exec "$QWEN_TEST_REAL_SHA256SUM" "$@"
fi
printf '%s  %s\n' \
    0000000000000000000000000000000000000000000000000000000000000000 "$1"
SHA256SUM
chmod +x "$ledger_window_bin/sha256sum"
if run_identity_carrier env QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS="$router_presets" QWEN_ROUTER_MAX=1 \
    QWEN_TEST_LEDGER_PATH="$fabricated_ctx_checkpoints" \
    QWEN_TEST_LEDGER_COUNT="$temporary_directory/ledger-window.count" \
    QWEN_TEST_REAL_SHA256SUM="$(command -v sha256sum)" \
    PATH="$ledger_window_bin:$PATH" \
    "$carrier_tools/qwen-capacity-policy.sh" \
    "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/ledger-window.stdout" \
    2>"$temporary_directory/ledger-window.stderr"; then
    printf 'policy accepted a checkpoint ledger measured outside its validation\n' >&2
    exit 1
fi
grep -F 'context checkpoint ledger identity changed during validation:' \
    "$temporary_directory/ledger-window.stderr" >/dev/null
if [ -e "$carrier_record" ]; then
    printf 'exec chain ran after the checkpoint ledger validation window opened\n' >&2
    exit 1
fi

# A web preset leaves the draft-pair pair at `-` because build-web-presets.sh
# emits no draft key, and it carries the checkpoint pair for the same reason a
# router preset does: every section names a count the ledger admits. That
# asymmetry is what makes the checkpoint authority required rather than
# optional.
carrier_web_profiles=$temporary_directory/identity-carrier-web-profiles.tsv
{
    printf '# profile_id\tmodel_id\tweb_mode\tcontext\tvalidated_filled_depth\tmax_results\tmax_fetches\tmax_chars_per_fetch\tmulti_source\tvision_allowed\ttool_selection\texecution_policy\tprovider\tprimary_category\tfallback_category\tminimum_results\tsearxng_url\n'
    printf 'web-carrier\tfabricated\tui-mediated\t4096\t4096\t5\t2\t12000\tyes\tno\t9/10\tui-mediated\texa\t-\t-\t-\t-\n'
} >"$carrier_web_profiles"
carrier_web_presets=$temporary_directory/identity-carrier-web-presets.ini
{
    printf '# Generated by remote/build-web-presets.sh from remote/web-profiles.tsv.\n'
    printf '# qwen_web_presets=1\n'
    printf '# qwen_web_profiles_path=%s\n' "$carrier_web_profiles"
    printf '# qwen_web_profiles_sha256=%s\n' \
        "$(sha256sum "$carrier_web_profiles" | cut -d' ' -f1)"
    printf '\n'
    printf '[web-carrier]\n'
    printf 'LLAMA_ARG_MODEL = %s\n' "$registry_model"
    printf 'LLAMA_ARG_ALIAS = web-carrier\n'
    printf 'LLAMA_ARG_CTX_SIZE = 4096\n'
    printf 'LLAMA_ARG_CACHE_TYPE_K = q5_1\n'
    printf 'LLAMA_ARG_CACHE_TYPE_V = iq4_nl\n'
    printf 'LLAMA_ARG_FLASH_ATTN = auto\n'
    printf 'LLAMA_ARG_BATCH = 256\n'
    printf 'LLAMA_ARG_UBATCH = 64\n'
    printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
    printf 'LLAMA_ARG_TAGS = web-research,ui-mediated\n'
} >"$carrier_web_presets"
if ! run_identity_carrier env QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS="$carrier_web_presets" QWEN_ROUTER_MAX=1 \
    QWEN_BIND_HOST=127.0.0.1 \
    "$carrier_tools/qwen-capacity-policy.sh" \
    "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/identity-web-carrier.stdout" \
    2>"$temporary_directory/identity-web-carrier.stderr"; then
    printf 'policy refused the web launch the identity recorder observes\n' >&2
    cat "$temporary_directory/identity-web-carrier.stderr" >&2
    exit 1
fi
carrier_web_draft_path=$(sed -n '7p' "$carrier_record")
carrier_web_draft_sha256=$(sed -n '8p' "$carrier_record")
carrier_web_ctx_path=$(sed -n '11p' "$carrier_record")
carrier_web_ctx_sha256=$(sed -n '12p' "$carrier_record")
if [ "$carrier_web_draft_path" != - ] || [ "$carrier_web_draft_sha256" != - ]; then
    printf 'web preset carried a draft-pair ledger pair: %s %s\n' \
        "$carrier_web_draft_path" "$carrier_web_draft_sha256" >&2
    exit 1
fi
if [ "$carrier_web_ctx_path" != "$fabricated_ctx_checkpoints" ] ||
    [ "$carrier_web_ctx_sha256" != "$carrier_ctx_sha256" ]; then
    printf 'web preset lost the checkpoint ledger identity: %s %s\n' \
        "$carrier_web_ctx_path" "$carrier_web_ctx_sha256" >&2
    exit 1
fi

# A generated preset carries its quarantine override after the generation
# environment is gone. The launch derives loopback isolation from that durable
# file rather than from an ambient variable that can disappear on a later run.
quarantine_router_presets=$temporary_directory/quarantine-router-presets.ini
printf '%s\n' \
    '# Generated by remote/build-router-presets.sh from the model registry.' \
    '# qwen_router_include_quarantine=1' \
    >"$quarantine_router_presets"
append_complete_router_section "$quarantine_router_presets"
printf 'LLAMA_ARG_TAGS = quarantine,research\n' \
    >>"$quarantine_router_presets"
QWEN_MODEL_REGISTRY=$fabricated_registry \
QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
QWEN_ROUTER_PRESETS=$quarantine_router_presets QWEN_BIND_HOST=0.0.0.0 \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    2>"$temporary_directory/quarantine-router.stderr"
quarantine_router_arguments=$(sed -n 's/^argument=//p' "$router_output" |
    tr '\n' ' ')
case " $quarantine_router_arguments " in
    *' --host 127.0.0.1 '*) ;;
    *)
        printf 'preset-carried quarantine override did not force loopback: %s\n' \
            "$quarantine_router_arguments" >&2
        exit 1
        ;;
esac
grep -F 'quarantine override forces the listener to loopback' \
    "$temporary_directory/quarantine-router.stderr" >/dev/null

missing_quarantine_tag=$temporary_directory/missing-quarantine-tag.ini
sed 's/^LLAMA_ARG_TAGS = quarantine,research$/LLAMA_ARG_TAGS = research/' \
    "$quarantine_router_presets" >"$missing_quarantine_tag"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$missing_quarantine_tag \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/missing-quarantine-tag.stdout" \
    2>"$temporary_directory/missing-quarantine-tag.stderr"; then
    printf 'policy accepted a research override without its quarantine tag\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries unsafe quarantine tags:' \
    "$temporary_directory/missing-quarantine-tag.stderr" >/dev/null

default_quarantine_tag=$temporary_directory/default-quarantine-tag.ini
sed 's/^LLAMA_ARG_TAGS = quarantine,research$/LLAMA_ARG_TAGS = quarantine,research,default/' \
    "$quarantine_router_presets" >"$default_quarantine_tag"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$default_quarantine_tag \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/default-quarantine-tag.stdout" \
    2>"$temporary_directory/default-quarantine-tag.stderr"; then
    printf 'policy accepted a default tag on a quarantined override section\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries unsafe quarantine tags:' \
    "$temporary_directory/default-quarantine-tag.stderr" >/dev/null

candidate_quarantine_tag=$temporary_directory/candidate-quarantine-tag.ini
sed 's/^LLAMA_ARG_TAGS = quarantine,research$/LLAMA_ARG_TAGS = candidate,quarantine,research/' \
    "$quarantine_router_presets" >"$candidate_quarantine_tag"
if QWEN_MODEL_REGISTRY=$fabricated_registry \
    QWEN_QUARANTINE_REGISTRY=$router_profile_quarantine \
    QWEN_MODEL_ROOT=$router_model_root QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$candidate_quarantine_tag \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/candidate-quarantine-tag.stdout" \
    2>"$temporary_directory/candidate-quarantine-tag.stderr"; then
    printf 'policy accepted contradictory candidate and quarantine tags\n' >&2
    exit 1
fi
grep -F 'router preset section fabricated carries unsafe quarantine tags:' \
    "$temporary_directory/candidate-quarantine-tag.stderr" >/dev/null

# A generated file from before the provenance field existed is not assumed
# clean. Regeneration is required before a potentially persistent preset runs.
legacy_router_presets=$temporary_directory/legacy-router-presets.ini
printf '%s\n' \
    '# Generated by remote/build-router-presets.sh from the model registry.' \
    >"$legacy_router_presets"
append_complete_router_section "$legacy_router_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$legacy_router_presets \
    "$policy" "$fake_server" "$model_path" 4096 18080 \
    >"$temporary_directory/legacy-router.stdout" \
    2>"$temporary_directory/legacy-router.stderr"; then
    printf 'policy accepted a generated preset without quarantine provenance\n' >&2
    exit 1
fi
grep -F 'generated router presets omit quarantine provenance' \
    "$temporary_directory/legacy-router.stderr" >/dev/null

# A quarantined profile names one tuple of an otherwise servable checkpoint, so
# the policy refuses that tuple and serves every neighbour of it. Reproducing
# the quarantined geometry resets the amdgpu compute ring on a live desktop,
# which is why this is a refusal rather than a warning.
quarantine_registry=$temporary_directory/quarantine-models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    quarantined research quarantined.gguf download-qwen38-4b-distill-q4km.sh \
    4096 16384 16384 q8_0 q4_0 on none - - - untested production 2048 512 4096 - \
    unmeasured refused \
    >"$quarantine_registry"
quarantine_table=$temporary_directory/quarantine.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    quarantined-tuple profile quarantined ring-timeout-only 16384 2048 512 \
    q8_0 q4_0 on evidence/x.md evidence/y.md evidence/z.md any \
    >"$quarantine_table"
quarantine_model=$temporary_directory/quarantined.gguf
: >"$quarantine_model"

# The standalone policy consumes the quarantine query as a required safety
# input. A missing registry stops tuple construction before an unknown profile
# can reach the server.
if QWEN_MODEL_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REGISTRY=$temporary_directory/absent-quarantine.tsv \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$quarantine_model" 16384 18080 \
    >"$temporary_directory/absent-quarantine.stdout" \
    2>"$temporary_directory/absent-quarantine.stderr"; then
    printf 'policy accepted an unreadable quarantine registry\n' >&2
    exit 1
fi
grep -F 'quarantine registry is unreadable' \
    "$temporary_directory/absent-quarantine.stderr" >/dev/null

if QWEN_MODEL_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine_table QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$quarantine_model" 16384 18080 \
    2>"$temporary_directory/quarantine.stderr"; then
    printf 'the policy built the quarantined tuple\n' >&2
    exit 1
fi
grep -F 'this tuple is quarantined' "$temporary_directory/quarantine.stderr" \
    >/dev/null

# The neighbouring depth under the same geometry is not quarantined and serves.
QWEN_MODEL_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine_table QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$quarantine_model" 8192 18080
quarantine_neighbour=$(sed -n 's/^argument=//p' "$cache_output" | tr '\n' ' ')
case $quarantine_neighbour in
    *'--ctx-size 8192 '*'--batch-size 2048 --ubatch-size 512 '*) ;;
    *)
        printf 'the neighbouring depth did not build: %s\n' \
            "$quarantine_neighbour" >&2
        exit 1
        ;;
esac

# The same depth at the served geometry is a different tuple and serves.
QWEN_MODEL_REGISTRY=$quarantine_registry \
    QWEN_QUARANTINE_REGISTRY=$quarantine_table QWEN_RADV_ICD=$fake_icd \
    QWEN_BATCH_SIZE=128 QWEN_UBATCH_SIZE=32 \
    QWEN_POLICY_TEST_OUTPUT=$cache_output \
    "$policy" "$fake_server" "$quarantine_model" 16384 18080
quarantine_geometry=$(sed -n 's/^argument=//p' "$cache_output" | tr '\n' ' ')
case $quarantine_geometry in
    *'--ctx-size 16384 '*'--batch-size 128 --ubatch-size 32 '*) ;;
    *)
        printf 'the served geometry at the quarantined depth did not build: %s\n' \
            "$quarantine_geometry" >&2
        exit 1
        ;;
esac

# A draft-pair section names a pair_id rather than a registry id, so the policy
# resolves it through remote/draft-pairs.tsv to the target row and compares the
# six tuple keys against that row and the nine draft keys against the pair row.
# A preset persists across a ledger edit, so a draft key that no longer matches
# the ledger refuses the launch rather than serving a draft nobody admitted.
pair_registry=$temporary_directory/pair-models.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    pair-target research pair-target.gguf download-qwen38-4b-distill-q4km.sh \
    4096 8192 8192 q5_1 iq4_nl auto none - - - untested candidate 256 64 4096 - \
    unmeasured refused \
    >"$pair_registry"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    pair-draft research pair-draft.gguf download-qwen35-08b-q80.sh \
    4096 8192 8192 q5_1 iq4_nl auto none - - - untested candidate 256 64 4096 - \
    unmeasured refused \
    >>"$pair_registry"
: >"$temporary_directory/pair-target.gguf"
: >"$temporary_directory/pair-draft.gguf"
populated_draft_pairs=$temporary_directory/populated-draft-pairs.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    pair-target+pair-draft pair-target pair-draft candidate 2 0.00 0.896 4096 \
    q8_0 q4_0 - 'target plus draft' \
    >"$populated_draft_pairs"
write_pair_section() {
    pair_section_file=$1
    pair_section_n_max=$2
    {
        printf '[pair-target+pair-draft]\n'
        printf 'LLAMA_ARG_MODEL = %s/pair-target.gguf\n' "$router_model_root"
        printf 'LLAMA_ARG_CTX_SIZE = 4096\n'
        printf 'LLAMA_ARG_CACHE_TYPE_K = q5_1\n'
        printf 'LLAMA_ARG_CACHE_TYPE_V = iq4_nl\n'
        printf 'LLAMA_ARG_FLASH_ATTN = auto\n'
        printf 'LLAMA_ARG_BATCH = 256\n'
        printf 'LLAMA_ARG_UBATCH = 64\n'
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
        printf 'LLAMA_ARG_SPEC_TYPE = draft-simple\n'
        printf 'LLAMA_ARG_SPEC_DRAFT_MODEL = %s/pair-draft.gguf\n' \
            "$router_model_root"
        printf 'LLAMA_ARG_SPEC_DRAFT_N_MAX = %s\n' "$pair_section_n_max"
        printf 'LLAMA_ARG_SPEC_DRAFT_P_MIN = 0.00\n'
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K = q8_0\n'
        printf 'LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V = q4_0\n'
        printf 'LLAMA_ARG_N_GPU_LAYERS_DRAFT = all\n'
        printf 'spec-draft-device = Vulkan0\n'
        printf 'spec-draft-override-tensor = .*=Vulkan0\n'
    } >"$pair_section_file"
}
pair_presets=$temporary_directory/pair-presets.ini
write_pair_section "$pair_presets" 2
QWEN_MODEL_REGISTRY=$pair_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_DRAFT_PAIRS=$populated_draft_pairs QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$pair_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$fake_server" "$temporary_directory/pair-target.gguf" 4096 18080

pair_mismatch_presets=$temporary_directory/pair-mismatch.ini
write_pair_section "$pair_mismatch_presets" 5
if QWEN_MODEL_REGISTRY=$pair_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_DRAFT_PAIRS=$populated_draft_pairs QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$pair_mismatch_presets \
    "$policy" "$fake_server" "$temporary_directory/pair-target.gguf" 4096 18080 \
    >"$temporary_directory/pair-mismatch.stdout" \
    2>"$temporary_directory/pair-mismatch.stderr"; then
    printf 'router accepted a draft length the pair ledger refuses\n' >&2
    exit 1
fi
grep -F 'carries LLAMA_ARG_SPEC_DRAFT_N_MAX 5, the draft pair ledger admits 2' \
    "$temporary_directory/pair-mismatch.stderr" >/dev/null

# An ordinary section that gained a draft key loads a second checkpoint no
# resident-set arithmetic counted, so the policy refuses it by the key alone.
pair_stray_presets=$temporary_directory/pair-stray.ini
: >"$pair_stray_presets"
append_complete_router_section "$pair_stray_presets"
printf 'LLAMA_ARG_SPEC_DRAFT_MODEL = %s/pair-draft.gguf\n' \
    "$router_model_root" >>"$pair_stray_presets"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$router_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$pair_stray_presets \
    "$policy" "$fake_server" "$registry_model" 4096 18080 \
    >"$temporary_directory/pair-stray.stdout" \
    2>"$temporary_directory/pair-stray.stderr"; then
    printf 'router accepted a draft key outside the pair ledger\n' >&2
    exit 1
fi
grep -F 'carries LLAMA_ARG_SPEC_DRAFT_MODEL without a draft pair row' \
    "$temporary_directory/pair-stray.stderr" >/dev/null

# The context checkpoint count comes from the ledger row of the registry
# row the model path resolves to, and a path outside the registry serves at
# 0, which the fixed argv above already proves. An integer override replaces
# the row's count verbatim, an explicit 0 included, the minimum step follows
# it only when named, and a non-integer in either is refused before the server
# sees it.
checkpoint_output=$temporary_directory/checkpoint-policy.out
ledger_ctx_checkpoints=$temporary_directory/ledger-ctx-checkpoints.tsv
printf 'fabricated\t2\tevidence/depth-versus-submission-geometry.md\n' \
    >"$ledger_ctx_checkpoints"
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_CTX_CHECKPOINT_LEDGER=$ledger_ctx_checkpoints \
    QWEN_CACHE_TYPE_K=q5_1 QWEN_CACHE_TYPE_V=iq4_nl QWEN_FLASH_ATTN=auto \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=4096 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$fake_server" "$registry_model" 4096 8080
checkpoint_arguments=$(sed -n 's/^argument=//p' "$checkpoint_output" | tr '\n' ' ')
case $checkpoint_arguments in
    *'--offline --ctx-checkpoints 2 --ctx-size 4096 '*) ;;
    *)
        printf 'the ledger count did not reach the argv: %s\n' \
            "$checkpoint_arguments" >&2
        exit 1
        ;;
esac
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_CTX_CHECKPOINT_LEDGER=$ledger_ctx_checkpoints QWEN_CTX_CHECKPOINTS=0 \
    QWEN_CACHE_TYPE_K=q5_1 QWEN_CACHE_TYPE_V=iq4_nl QWEN_FLASH_ATTN=auto \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=4096 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$fake_server" "$registry_model" 4096 8080
checkpoint_arguments=$(sed -n 's/^argument=//p' "$checkpoint_output" | tr '\n' ' ')
case $checkpoint_arguments in
    *'--offline --ctx-checkpoints 0 --ctx-size 4096 '*) ;;
    *)
        printf 'the explicit zero override did not replace the ledger count: %s\n' \
            "$checkpoint_arguments" >&2
        exit 1
        ;;
esac
malformed_ledger_ctx_checkpoints=$temporary_directory/malformed-ctx-checkpoints.tsv
printf 'fabricated\t02\t-\n' >"$malformed_ledger_ctx_checkpoints"
if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_CTX_CHECKPOINT_LEDGER=$malformed_ledger_ctx_checkpoints \
    QWEN_CACHE_TYPE_K=q5_1 QWEN_CACHE_TYPE_V=iq4_nl QWEN_FLASH_ATTN=auto \
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=4096 \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$fake_server" "$registry_model" 4096 8080 \
    2>"$temporary_directory/malformed-ledger.stderr"; then
    printf 'the policy launched over a malformed checkpoint ledger\n' >&2
    exit 1
fi
grep -F 'context checkpoint authority is unavailable' \
    "$temporary_directory/malformed-ledger.stderr" >/dev/null
QWEN_CTX_CHECKPOINTS=4 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$fake_server" "$model_path" 24576 8080
checkpoint_arguments=$(sed -n 's/^argument=//p' "$checkpoint_output" | tr '\n' ' ')
case $checkpoint_arguments in
    *'--no-context-shift --offline --ctx-checkpoints 4 --ctx-size '*) ;;
    *)
        printf 'the checkpoint override did not reach the argv: %s\n' \
            "$checkpoint_arguments" >&2
        exit 1
        ;;
esac
case $checkpoint_arguments in
    *'--checkpoint-min-step'*)
        printf 'an unset minimum step reached the argv: %s\n' \
            "$checkpoint_arguments" >&2
        exit 1
        ;;
esac
QWEN_CTX_CHECKPOINTS=8 QWEN_CHECKPOINT_MIN_STEP=4096 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$fake_server" "$model_path" 24576 8080
checkpoint_arguments=$(sed -n 's/^argument=//p' "$checkpoint_output" | tr '\n' ' ')
case $checkpoint_arguments in
    *'--offline --checkpoint-min-step 4096 --ctx-checkpoints 8 --ctx-size '*) ;;
    *)
        printf 'the minimum step override did not reach the argv: %s\n' \
            "$checkpoint_arguments" >&2
        exit 1
        ;;
esac
for refused_pair in 'QWEN_CTX_CHECKPOINTS=two' 'QWEN_CTX_CHECKPOINTS=-1' \
    'QWEN_CHECKPOINT_MIN_STEP=8k'; do
    if env "$refused_pair" QWEN_RADV_ICD=$fake_icd \
        QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
        "$policy" "$fake_server" "$model_path" 24576 8080 \
        2>"$temporary_directory/checkpoint.stderr"; then
        printf 'the policy accepted a non-integer checkpoint setting: %s\n' \
            "$refused_pair" >&2
        exit 1
    fi
    grep -F 'must be a non-negative integer' \
        "$temporary_directory/checkpoint.stderr" >/dev/null
done

# The capability binding, exercised across the states a serving path can reach.
# A positive count is executable only by a build whose manifest declares the
# measured checkpoint semantics, and every other combination refuses at the
# policy or at the exec boundary rather than serving.
semantics_root=$temporary_directory/checkpoint-semantics
natural_server=$(write_fixture_build "$semantics_root/natural" natural-boundary-v1)
forced_server=$(write_fixture_build "$semantics_root/forced" forced-tail-v1)
unknown_server=$(write_fixture_build "$semantics_root/unknown" unknown)
absent_server=$(write_fixture_build "$semantics_root/absent" absent)

run_semantics_arm() {
    arm_name=$1
    arm_server=$2
    arm_count=$3
    QWEN_CTX_CHECKPOINTS=$arm_count QWEN_RADV_ICD=$fake_icd \
        QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
        "$policy" "$arm_server" "$model_path" 24576 8080 \
        >"$temporary_directory/semantics-$arm_name.stdout" \
        2>"$temporary_directory/semantics-$arm_name.stderr"
}

expect_semantics_refusal() {
    arm_name=$1
    arm_server=$2
    arm_count=$3
    expected_reason=$4
    if run_semantics_arm "$arm_name" "$arm_server" "$arm_count"; then
        printf 'the %s arm was admitted\n' "$arm_name" >&2
        exit 1
    fi
    if ! grep -F "$expected_reason" \
        "$temporary_directory/semantics-$arm_name.stderr" >/dev/null; then
        printf 'the %s refusal names the wrong reason:\n' "$arm_name" >&2
        cat "$temporary_directory/semantics-$arm_name.stderr" >&2
        exit 1
    fi
}

expect_semantics_argv() {
    arm_name=$1
    arm_server=$2
    arm_count=$3
    run_semantics_arm "$arm_name" "$arm_server" "$arm_count"
    semantics_arguments=$(sed -n 's/^argument=//p' "$checkpoint_output" | tr '\n' ' ')
    case $semantics_arguments in
        *"--ctx-checkpoints $arm_count "*) ;;
        *)
            printf 'the %s arm produced the wrong argv: %s\n' \
                "$arm_name" "$semantics_arguments" >&2
            exit 1
            ;;
    esac
    # The pinned build defaults an omitted count to 32, so an explicit value
    # must reach the argv exactly once: an omission would serve the default
    # under a policy that computed zero, and a second occurrence would leave
    # the served count to argument-parser precedence rather than the policy.
    semantics_flag_count=$(grep -c '^argument=--ctx-checkpoints$' \
        "$checkpoint_output" || true)
    if [ "$semantics_flag_count" != 1 ]; then
        printf 'the %s arm emitted --ctx-checkpoints %s times, expected once\n' \
            "$arm_name" "$semantics_flag_count" >&2
        exit 1
    fi
}

# A build predating the declaration still serves a count of zero, so the
# requirement follows the count rather than the binary.
expect_semantics_argv absent-zero "$absent_server" 0
expect_semantics_argv forced-zero "$forced_server" 0
expect_semantics_argv unknown-zero "$unknown_server" 0
expect_semantics_argv natural-two "$natural_server" 2

expect_semantics_refusal absent-two "$absent_server" 2 \
    'a positive context checkpoint count requires natural-boundary-v1'
expect_semantics_refusal forced-two "$forced_server" 2 \
    'a positive context checkpoint count requires natural-boundary-v1'
# A source the build recognized as neither the pinned partition nor the repair
# is refused on the same rule under its own name, so an unproven implementation
# stays distinguishable from the one this tree measured.
expect_semantics_refusal unknown-two "$unknown_server" 2 \
    'declares checkpoint_semantics=unknown'

# A server replaced under a manifest that still declares the repaired semantics
# is refused on its own digest, which is the drift a policy-time read alone
# would miss.
tampered_server=$(write_fixture_build "$semantics_root/tampered" natural-boundary-v1)
printf '\n# replaced after the manifest was written\n' >>"$tampered_server"
if QWEN_CTX_CHECKPOINTS=2 QWEN_RADV_ICD=$fake_icd \
    QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    "$policy" "$tampered_server" "$model_path" 24576 8080 \
    >"$temporary_directory/semantics-tampered.stdout" \
    2>"$temporary_directory/semantics-tampered.stderr"; then
    printf 'a server replaced under its manifest was admitted\n' >&2
    exit 1
fi
grep -F 'does not match its manifest row' \
    "$temporary_directory/semantics-tampered.stderr" >/dev/null

# A manifest rewritten between policy assembly and exec is what the recorded
# digest closes, and only the guard can be placed at that boundary, so it is
# driven directly with a digest the manifest no longer matches.
guard=$script_directory/qwen-build-exec-guard.sh
if "$guard" "$natural_server" \
    0000000000000000000000000000000000000000000000000000000000000000 \
    natural-boundary-v1 /bin/true \
    2>"$temporary_directory/guard-manifest.stderr"; then
    printf 'the guard accepted a manifest whose identity changed\n' >&2
    exit 1
fi
grep -F 'artifact manifest identity changed' \
    "$temporary_directory/guard-manifest.stderr" >/dev/null

# Two declarations leave the manifest stating nothing, so the guard refuses
# rather than reading whichever row comes first.
duplicate_server=$(write_fixture_build "$semantics_root/duplicate" natural-boundary-v1)
printf 'checkpoint_semantics\tforced-tail-v1\n' \
    >>"$semantics_root/duplicate/artifact-manifest.tsv"
if "$guard" "$duplicate_server" - natural-boundary-v1 /bin/true \
    2>"$temporary_directory/guard-duplicate.stderr"; then
    printf 'the guard accepted two checkpoint_semantics rows\n' >&2
    exit 1
fi
grep -F 'requires exactly one' \
    "$temporary_directory/guard-duplicate.stderr" >/dev/null

# The policy counts the same rows, so a duplicated declaration refuses beside
# the argv it would have produced rather than reaching the exec boundary.
expect_semantics_refusal duplicate "$duplicate_server" 2 \
    'declares checkpoint_semantics=unknown'

# Router mode carries the count per section, so the requirement follows the
# sections a launch would actually serve rather than any positive row in the
# ledger. A preset whose sections all read zero launches an older build; one
# positive section makes the declaration mandatory.
semantics_router_presets=$temporary_directory/semantics-router-presets.ini
: >"$semantics_router_presets"
append_complete_router_section "$semantics_router_presets"
sed -i 's/^LLAMA_ARG_CTX_CHECKPOINTS = 0$/LLAMA_ARG_CTX_CHECKPOINTS = 2/' \
    "$semantics_router_presets"
semantics_router_ledger=$temporary_directory/semantics-router-ctx-checkpoints.tsv
printf 'fabricated\t2\tevidence/depth-versus-submission-geometry.md\n' \
    >"$semantics_router_ledger"

if QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_CTX_CHECKPOINT_LEDGER=$semantics_router_ledger \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$semantics_router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$forced_server" "$model_path" 4096 18080 \
    >"$temporary_directory/semantics-router-forced.stdout" \
    2>"$temporary_directory/semantics-router-forced.stderr"; then
    printf 'a router preset carrying a positive count launched a forced-tail build\n' >&2
    exit 1
fi
grep -F 'a positive context checkpoint count requires natural-boundary-v1' \
    "$temporary_directory/semantics-router-forced.stderr" >/dev/null

QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_CTX_CHECKPOINT_LEDGER=$semantics_router_ledger \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$semantics_router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$natural_server" "$model_path" 4096 18080 \
    >"$temporary_directory/semantics-router-natural.stdout" 2>&1
grep -F 'checkpoint_binding semantics=natural-boundary-v1 requirement=natural-boundary-v1' \
    "$temporary_directory/semantics-router-natural.stdout" >/dev/null

# An all-zero router preset states no requirement, so a build predating the
# declaration serves it.
QWEN_MODEL_REGISTRY=$fabricated_registry QWEN_MODEL_ROOT=$router_model_root \
    QWEN_RADV_ICD=$fake_icd QWEN_POLICY_TEST_OUTPUT=$checkpoint_output \
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$router_presets QWEN_ROUTER_MAX=1 \
    "$policy" "$absent_server" "$model_path" 4096 18080 \
    >"$temporary_directory/semantics-router-zero.stdout" 2>&1
grep -F 'checkpoint_binding semantics=unknown requirement=-' \
    "$temporary_directory/semantics-router-zero.stdout" >/dev/null

printf 'qwen_capacity_policy=accepted\n'
