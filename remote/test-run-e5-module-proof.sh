#!/bin/sh
set -eu

# remote/run-e5-module-proof.sh against a fake collector, so every verdict and
# every refusal is driven with no device, no isolated driver, and no server. The
# ISA recounter is the tree's own, because the fixture listings state exactly the
# mnemonic counts the E5 receipts state and a second counter here would test this
# file rather than the reader the verdict rests on.
#
# The three exit classes are what the test separates. A missing or malformed
# input exits 2 and writes no terminal state, since filing a setup error as a
# completed negative would retire the rung on a mistake. A refuted identity exits
# 3 with terminal-state.tsv naming the field that moved. An accepted arm exits 0
# and records the lowering it observed rather than gating on it.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
subject=$script_directory/run-e5-module-proof.sh

work_root=$(mktemp -d)
trap 'rm -rf -- "$work_root"' EXIT HUP INT TERM

failures=0
report() {
    if [ "$1" -eq 0 ]; then
        printf 'ok %s\n' "$2"
    else
        printf 'FAIL %s\n' "$2"
        failures=$((failures + 1))
    fi
}

module_sha256=2659f04ce6642572a017369606825384e267aaa709b222ef83b95624303ef2a1
module_bytes=36940
module_name=mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem
pipeline_name=mul_mat_vec_q4_k_q8_1_f32_subgroup_no_shmem

pack=$work_root/shader-pack
mkdir -p "$pack"
{
    printf 'module_name\tsource\tsource_sha256\tdefines\ttarget_env\tcommand\tspirv_bytes\tspirv_sha256\tvalidation\n'
    printf '%s\tmul_mat_vecq.comp\tdeadbeef\tDATA_A_Q4_K=1\tvulkan1.2\tglslc\t%s\t%s\tvalid\n' \
        "$module_name" "$module_bytes" "$module_sha256"
} >"$pack/shader-pack.tsv"
{
    printf 'key\tvalue\n'
    printf 'schema\tspirv-shader-pack-v1\n'
    printf 'declaration_sha256\t1e34e837\n'
    printf 'glslc_version\tshaderc v2026.3\n'
} >"$pack/pack-inputs.tsv"
{
    printf 'key\tvalue\n'
    printf 'module_sha256\t%s\n' "$module_sha256"
    printf 'opsdot_packed_4x8\t32\n'
    printf 'spirv_dis\tSPIRV-Tools v2026.3\n'
} >"$pack/dot-instruction-proof.tsv"

census_fixture=$work_root/instruction-census.tsv
{
    printf 'isa_path\tisa_sha256\tv_mul_lo_u32\tv_mul_i32_i24\tv_add3_u32\n'
    printf 'evidence/e5/E5-S0/isa-arch-toolchain/isa.s\ta4d5f709\t0\t224\t98\n'
    printf 'evidence/e5/E5-S1/isa-post-2115/isa.s\tb9f5b4e6\t0\t224\t140\n'
} >"$census_fixture"

# The isolated driver prefix: a build receipt, the environment fragment that
# names the ICD, and an ICD whose library_path sits inside the prefix.
make_prefix() {
    prefix=$work_root/$1
    library=${2:-$prefix/libvulkan_radeon.so}
    mkdir -p "$prefix"
    printf 'radv fake driver\n' >"$prefix/libvulkan_radeon.so"
    {
        printf 'key\tvalue\n'
        printf 'schema\t%s\n' "${3:-isolated-radv-v1}"
        printf 'revision\t9a1c2f30\n'
        printf 'lowering_merge\tf1078c57e5f02b611f2c69af9ac7e0f5aa82a0bb\n'
    } >"$prefix/radv-build.tsv"
    printf '{"ICD":{"library_path":"%s","api_version":"1.4.0"}}\n' "$library" \
        >"$prefix/radeon_devenv_icd.x86_64.json"
    {
        printf '#!/bin/sh\n'
        printf 'QWEN_RADV_ICD=%s\n' "$prefix/radeon_devenv_icd.x86_64.json"
        printf 'QWEN_AMDGPU_DRM_SHIM=%s/libamdgpu_noop_drm_shim.so\n' "$prefix"
        # shellcheck disable=SC2016  # the fragment's braces reach it as text
        printf 'LD_LIBRARY_PATH=%s${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\n' "$prefix"
        printf 'export QWEN_RADV_ICD QWEN_AMDGPU_DRM_SHIM LD_LIBRARY_PATH\n'
    } >"$prefix/radv-experiment-env.sh"
    printf '%s' "$prefix"
}

server=$work_root/llama-server
printf '#!/bin/sh\nexit 0\n' >"$server"
chmod 0755 "$server"
model=$work_root/model.gguf
printf 'GGUF fixture\n' >"$model"

# The fake collector writes what the real one leaves behind: the census file
# QWEN_PIPELINE_CENSUS names, and one ISA listing per compiled shader under
# OUTPUT/isa.
collector=$work_root/fake-collector.sh
cat >"$collector" <<'COLLECTOR'
#!/bin/sh
set -eu
output_directory=$1
mkdir -p "$output_directory/isa"
if [ "${FAKE_COLLECTOR_STATUS:-0}" -ne 0 ]; then
    exit "$FAKE_COLLECTOR_STATUS"
fi
{
    printf 'census_open\t1\n'
    if [ -n "${FAKE_DECOY_PIPELINE:-}" ]; then
        printf 'census_pipeline\t9\t%s\tmain\tcccc\t99\tdddd\t99\t-\n' \
            "$FAKE_DECOY_PIPELINE"
    fi
    if [ -n "${FAKE_PIPELINE:-}" ]; then
        printf 'census_pipeline\t0\t%s\tmain\t%s\t%s\t%s\t%s\t-\n' \
            "$FAKE_PIPELINE" "$FAKE_MODULE_SHA256" "$FAKE_MODULE_BYTES" \
            "${FAKE_EXECUTED_SHA256:-ffffffff}" "$FAKE_MODULE_BYTES"
    fi
    printf 'census_pipeline\t1\tmul_mat_vec_q6_k_f16\tmain\taaaa\t128\tbbbb\t128\t-\n'
} >"$GGML_VK_PIPELINE_CENSUS_FIXTURE"
# One unrelated shader, then the subject expansion the recount selects by shape.
{
    printf 'v_cvt_f32_f16_e32 v0, v1\n'
    printf 'v_mad_mix_f32 v0, v1, v2, v3\n'
} >"$output_directory/isa/001.s"
: >"$output_directory/isa/002.s"
count=0
while [ "$count" -lt "${FAKE_MUL24:-224}" ]; do
    printf 'v_mul_i32_i24_sdwa v0, v1, v2 src0_sel:BYTE_0 src1_sel:BYTE_0\n' \
        >>"$output_directory/isa/002.s"
    count=$((count + 1))
done
count=0
while [ "$count" -lt "${FAKE_ADD3:-140}" ]; do
    printf 'v_add3_u32 v0, v1, v2\n' >>"$output_directory/isa/002.s"
    count=$((count + 1))
done
count=0
while [ "$count" -lt "${FAKE_MUL_LO:-0}" ]; do
    printf 'v_mul_lo_u32 v0, v1, v2\n' >>"$output_directory/isa/002.s"
    count=$((count + 1))
done
COLLECTOR
chmod 0755 "$collector"

prefix=$(make_prefix radv-prefix)

run_subject() {
    out=$work_root/$1
    shift
    rm -rf -- "$out"
    status=0
    QWEN_E5_ISA_COLLECTOR=$collector \
    QWEN_E5_SHADER_PACK=$pack \
    QWEN_E5_INSTRUCTION_CENSUS=$census_fixture \
    GGML_VK_PIPELINE_CENSUS_FIXTURE=$out/pipeline-census.tsv \
    FAKE_PIPELINE=${FAKE_PIPELINE-$pipeline_name} \
    FAKE_MODULE_SHA256=${FAKE_MODULE_SHA256:-$module_sha256} \
    FAKE_MODULE_BYTES=${FAKE_MODULE_BYTES:-$module_bytes} \
    FAKE_MUL24=${FAKE_MUL24:-224} \
    FAKE_ADD3=${FAKE_ADD3:-140} \
    FAKE_MUL_LO=${FAKE_MUL_LO:-0} \
    FAKE_DECOY_PIPELINE=${FAKE_DECOY_PIPELINE:-} \
        "$subject" "$out" "$server" "$model" "${1:-$prefix}" \
        >"$work_root/out.log" 2>&1 || status=$?
    printf '%s' "$status"
}

# The collector writes the census where QWEN_PIPELINE_CENSUS points, and the
# fixture reads that path from its own name so the fake needs no parser.
collector_wrapper=$work_root/collector-wrapper.sh
cat >"$collector_wrapper" <<'WRAP'
#!/bin/sh
set -eu
GGML_VK_PIPELINE_CENSUS_FIXTURE=$QWEN_PIPELINE_CENSUS
export GGML_VK_PIPELINE_CENSUS_FIXTURE
exec "$FAKE_COLLECTOR" "$@"
WRAP
chmod 0755 "$collector_wrapper"
FAKE_COLLECTOR=$collector
export FAKE_COLLECTOR
collector=$collector_wrapper

status=0
"$subject" >/dev/null 2>&1 || status=$?
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'no argument exits 2'

status=$(run_subject out-accepted)
report "$([ -d "$work_root/out-accepted" ] && echo 0 || echo 1)" \
    'the accepted arm creates its output directory'
report "$status" 'a matching module and the 2115 lowering exit 0'
report "$(grep -q 'module_identity=proven aco_lowering=mr2115' "$work_root/out.log" && echo 0 || echo 1)" \
    'the verdict line names the proven module and the 2115 lowering'
report "$(grep -qx 'state	accepted' "$work_root/out-accepted/terminal-state.tsv" && echo 0 || echo 1)" \
    'the accepted arm records accepted terminal state'
report "$(grep -qx "module_sha256	$module_sha256" "$work_root/out-accepted/verdict.tsv" && echo 0 || echo 1)" \
    'the verdict record carries the module digest'
report "$(grep -q "^radv_library_sha256	" "$work_root/out-accepted/inputs.tsv" && echo 0 || echo 1)" \
    'inputs.tsv binds the driver library digest'
report "$(grep -q "^pack_glslc_version	shaderc v2026.3" "$work_root/out-accepted/inputs.tsv" && echo 0 || echo 1)" \
    'inputs.tsv binds the producer version'

report "$(grep -qx 'aco_v_mul_lo_u32	0' "$work_root/out-accepted/verdict.tsv" && echo 0 || echo 1)" \
    'the verdict record carries the quarter-rate multiply count as its own field'

# A variant of the same family created ahead of the declared module must not
# refute the rung: the pack declares one module and the family creates several.
status=$(FAKE_DECOY_PIPELINE=mul_mat_vec_q4_k_q8_1_f32_acc run_subject out-decoy)
report "$status" 'a foreign family variant created first still exits 0'
report "$(grep -qx 'family_pipeline_count	2' "$work_root/out-decoy/verdict.tsv" && echo 0 || echo 1)" \
    'the verdict record counts every family pipeline'
report "$(grep -qx "pipeline_name	$pipeline_name" "$work_root/out-decoy/verdict.tsv" && echo 0 || echo 1)" \
    'the matched pipeline is the declared module rather than the first row'

# falsifier 1's second clause reads as itself rather than as a missing expansion.
status=$(FAKE_MUL_LO=8 run_subject out-quarter-rate)
report "$status" 'a quarter-rate multiply beside the expansion still exits 0'
report "$(grep -q 'v_mul_lo_u32=8' "$work_root/out.log" && echo 0 || echo 1)" \
    'the verdict line reports the quarter-rate multiply count'

# A relative output directory is refused, since the census refuses one too.
status=0
QWEN_E5_ISA_COLLECTOR=$collector QWEN_E5_SHADER_PACK=$pack \
QWEN_E5_INSTRUCTION_CENSUS=$census_fixture \
    "$subject" relative-out "$server" "$model" "$prefix" \
    >"$work_root/out.log" 2>&1 || status=$?
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'a relative output directory exits 2'

# The generic expansion is a result rather than a refusal.
status=$(FAKE_ADD3=98 run_subject out-generic)
report "$status" 'the generic lowering exits 0'
report "$(grep -q 'aco_lowering=generic' "$work_root/out.log" && echo 0 || echo 1)" \
    'the generic lowering is named rather than refuted'

# An absent q8_1 pipeline ends the rung as a completed negative.
status=$(FAKE_PIPELINE='' run_subject out-no-pipeline)
report "$([ "$status" -eq 3 ] && echo 0 || echo 1)" 'an absent pipeline exits 3'
report "$(grep -qx 'field	pipeline_created' "$work_root/out-no-pipeline/terminal-state.tsv" && echo 0 || echo 1)" \
    'the absent pipeline names its field'
report "$(grep -qx 'state	completed-negative' "$work_root/out-no-pipeline/terminal-state.tsv" && echo 0 || echo 1)" \
    'the absent pipeline is a completed negative'

# A module the pack never wrote ends the rung too.
status=$(FAKE_MODULE_SHA256=0000000000000000000000000000000000000000000000000000000000000000 \
    run_subject out-wrong-module)
report "$([ "$status" -eq 3 ] && echo 0 || echo 1)" 'a foreign module exits 3'
report "$(grep -qx 'field	module_sha256' "$work_root/out-wrong-module/terminal-state.tsv" && echo 0 || echo 1)" \
    'the foreign module names its field'

# A lowering carrying no 24-bit expansion at all refutes the arm.
status=$(FAKE_MUL24=12 run_subject out-no-expansion)
report "$([ "$status" -eq 3 ] && echo 0 || echo 1)" 'an absent 24-bit expansion exits 3'
report "$(grep -qx 'field	aco_dot_expansion' "$work_root/out-no-expansion/terminal-state.tsv" && echo 0 || echo 1)" \
    'the absent expansion names its field'

# A driver library outside the named prefix is a setup error, not a negative.
foreign=$work_root/foreign-library.so
printf 'system radv\n' >"$foreign"
foreign_prefix=$(make_prefix radv-foreign "$foreign")
status=$(run_subject out-foreign-driver "$foreign_prefix")
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'an ICD outside the prefix exits 2'
report "$([ ! -e "$work_root/out-foreign-driver/terminal-state.tsv" ] && echo 0 || echo 1)" \
    'a setup error writes no terminal state'

# A prefix whose receipt declares another schema is refused the same way.
other_schema=$(make_prefix radv-other '' isolated-radv-v9)
status=$(run_subject out-other-schema "$other_schema")
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'a foreign receipt schema exits 2'

# An existing output directory is never written over.
mkdir -p "$work_root/out-existing"
status=0
QWEN_E5_ISA_COLLECTOR=$collector QWEN_E5_SHADER_PACK=$pack \
QWEN_E5_INSTRUCTION_CENSUS=$census_fixture \
    "$subject" "$work_root/out-existing" "$server" "$model" "$prefix" \
    >"$work_root/out.log" 2>&1 || status=$?
report "$([ "$status" -eq 2 ] && echo 0 || echo 1)" 'an existing output directory exits 2'

if [ "$failures" -ne 0 ]; then
    printf 'run-e5-module-proof checks failed: %s\n' "$failures" >&2
    exit 1
fi
printf 'run-e5-module-proof checks passed\n'
