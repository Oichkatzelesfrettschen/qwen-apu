#!/bin/sh
set -eu

# run-kernel-delta-witness.sh loads a model four times on the Vulkan device, so
# what a workstation checks is the argument contract it applies before the first
# server start. Every case below is refused ahead of the executable test at the
# top of the script, and the closing case proves the defaults still reach that
# test rather than being caught by a validation pattern of their own.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
witness=$script_directory/run-kernel-delta-witness.sh
temporary_directory=$(mktemp -d)
port_lease_holder_pid=''
cleanup() {
    cleanup_status=$?
    if [ -n "$port_lease_holder_pid" ]; then
        "$script_directory/test-port-lease.sh" release \
            "$port_lease_holder_pid" || true
        port_lease_holder_pid=''
    fi
    rm -rf -- "$temporary_directory"
    exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

# The witness and the served fixture each bind a loopback port of their own.
# The fixed 18098 and 18099 this test once named are numbers another
# repository's gate cell on this workstation can already hold, so both come
# from a lease a holder process keeps for this script's whole run.
port_lease_ports_file=$temporary_directory/leased-ports
port_lease_holder_pid=$("$script_directory/test-port-lease.sh" claim 2 \
    "$port_lease_ports_file")
witness_port=$(sed -n 1p "$port_lease_ports_file")
witness_server_port=$(sed -n 2p "$port_lease_ports_file")

failures=0
report() {
    if [ "$1" = 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

absent_server=$temporary_directory/absent-server
output_directory=$temporary_directory/out

# Each case names the variable, the value, and the phrase the refusal carries.
refuses() {
    case_name=$1
    expected_phrase=$2
    shift 2
    case_log=$temporary_directory/$case_name.log
    case_status=0
    env "$@" "$witness" "$absent_server" "$absent_server" model-id "$output_directory" \
        >"$case_log" 2>&1 || case_status=$?
    if [ "$case_status" -eq 2 ] && grep -q "$expected_phrase" "$case_log" &&
        [ ! -e "$output_directory" ]; then
        report 0 "$case_name"
    else
        report 1 "$case_name"
        printf 'status=%s log:\n' "$case_status" >&2
        cat "$case_log" >&2
    fi
}

# A run count the while loop never enters leaves every arm without a sample and
# still exits 0 through the analyzer, so zero and every non-integer spelling is
# refused where the count is read. An empty value takes the default through
# `${QWEN_WITNESS_RUNS:-2}`, so the pattern answers a written value alone.
refuses runs_zero 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=0
refuses runs_negative 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=-2
refuses runs_word 'QWEN_WITNESS_RUNS is a positive integer' QWEN_WITNESS_RUNS=two

# float() reads inf and nan, and the verdict rests on `delta <= bound`: inf
# admits every difference and nan refuses every one.
refuses bound_infinite 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=inf
refuses bound_not_a_number 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=nan
refuses bound_negative 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=-0.001
refuses bound_double_point 'QWEN_WITNESS_LOGPROB_BOUND is a nonnegative decimal number' \
    QWEN_WITNESS_LOGPROB_BOUND=0.0.1

# The defaults and a plain decimal reach the executable test, which is the
# refusal that follows both validation blocks.
refuses defaults_reach_the_executable_test 'server is not executable'
refuses decimal_bound_reaches_the_executable_test 'server is not executable' \
    QWEN_WITNESS_RUNS=3 QWEN_WITNESS_LOGPROB_BOUND=0.5

# The first arm's environment, read from both sides. The witness starts
# llama-server itself, so an ambient GGML_VK_Q4K_SIDEPLANE reaches the arm
# through no scrub at all -- radv-low-priority-env.sh runs on the served path
# and not on this one -- and QWEN_CACHE_OVERRIDE_CONTEXT_CEILING is a QWEN_
# name every scrub in the tree leaves alone. This case sets both in the
# invoking shell, runs the witness far enough to start one server, and reads
# the record the arm kept beside the environment the server observed.
#
# The fake server exits at once, so the readiness loop reports it and the
# witness ends non-zero with the record already written: what is under test is
# the environment an arm is handed rather than a completed comparison.
arm_root=$temporary_directory/arm
mkdir -p "$arm_root/models/fixture"
printf 'fixture model\n' >"$arm_root/models/fixture/model.gguf"
printf '{}\n' >"$arm_root/radeon_icd.x86_64.json"
server_environment=$arm_root/server-environment.txt
{
    printf '#!/bin/sh\nset -eu\n'
    printf 'env >>%s\n' "$server_environment"
    printf 'exit 0\n'
} >"$arm_root/llama-server"
chmod +x "$arm_root/llama-server"
cat >"$arm_root/model-registry.sh" <<'REGISTRY_STUB'
#!/bin/sh
set -eu
case $3 in
    model_file) printf 'fixture/model.gguf\n' ;;
    context_default) printf '4096\n' ;;
    batch) printf '128\n' ;;
    ubatch) printf '32\n' ;;
    cache_type_k | cache_type_v) printf 'f16\n' ;;
    flash_attention) printf 'on\n' ;;
    *) exit 1 ;;
esac
REGISTRY_STUB
chmod +x "$arm_root/model-registry.sh"
# The device gate reads the workstation's own process table, where another
# session's llama-server would refuse this fixture before any arm starts.
mkdir -p "$arm_root/stubs"
printf '#!/bin/sh\nexit 1\n' >"$arm_root/stubs/pgrep"
chmod +x "$arm_root/stubs/pgrep"
arm_output=$arm_root/out
arm_status=0
env PATH="$arm_root/stubs:$PATH" \
    GGML_VK_Q4K_SIDEPLANE=0 QWEN_CACHE_OVERRIDE_CONTEXT_CEILING=65536 \
    QWEN_MODEL_REGISTRY_SCRIPT="$arm_root/model-registry.sh" \
    QWEN_MODELS_DIRECTORY="$arm_root/models" \
    QWEN_RADV_ICD="$arm_root/radeon_icd.x86_64.json" \
    QWEN_WITNESS_PORT="$witness_port" QWEN_SERVER_PORT="$witness_server_port" \
    QWEN_WITNESS_READY_SECONDS=2 \
    "$witness" "$arm_root/llama-server" "$arm_root/llama-server" model-id \
    "$arm_output" >"$temporary_directory/arm.log" 2>&1 || arm_status=$?
arm_record=$arm_output/arms/1-C/arm-environment.tsv
arm_isolated=0
if [ "$arm_status" -eq 0 ]; then
    arm_isolated=1
    printf 'the fixture witness completed where the fake server exits at once\n' >&2
fi
if [ ! -s "$arm_record" ]; then
    arm_isolated=1
    printf 'arm environment record is absent: %s\n' "$arm_record" >&2
else
    for arm_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
        if cut -f1 "$arm_record" | grep -qx "$arm_name"; then
            arm_isolated=1
            printf 'ambient %s reached the arm record: %s\n' "$arm_name" \
                "$arm_record" >&2
        fi
    done
    for arm_required in PATH HOME VK_DRIVER_FILES LLAMA_NO_CPU_FALLBACK; do
        if ! cut -f1 "$arm_record" | grep -qx "$arm_required"; then
            arm_isolated=1
            printf 'arm environment record omits %s: %s\n' "$arm_required" \
                "$arm_record" >&2
        fi
    done
fi
if [ ! -s "$server_environment" ]; then
    arm_isolated=1
    printf 'the fake server recorded no environment of its own\n' >&2
else
    for arm_name in GGML_VK_Q4K_SIDEPLANE QWEN_CACHE_OVERRIDE_CONTEXT_CEILING; do
        if grep -q "^$arm_name=" "$server_environment"; then
            arm_isolated=1
            printf 'ambient %s reached the server environment\n' "$arm_name" >&2
        fi
    done
fi
if [ "$arm_isolated" -ne 0 ]; then
    sed -n '1,20p' "$temporary_directory/arm.log" >&2
fi
report "$arm_isolated" arm_environment_excludes_ambient_settings

if [ "$failures" -ne 0 ]; then
    printf 'run_kernel_delta_witness_tests=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'run_kernel_delta_witness_tests=passed\n'
